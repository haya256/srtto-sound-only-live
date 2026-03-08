//
//  SRTStreamingService.swift
//  SRTAudioStreamer
//
//  Created by Claude Code
//

import Foundation
import AVFoundation
import HaishinKit
import SRTHaishinKit
import os.log

/// Service responsible for managing SRT streaming
class SRTStreamingService {
    private let logger = Logger(subsystem: "com.example.SRTAudioStreamer", category: "SRTStreaming")

    private static let gracePeriodSeconds: TimeInterval = 5.0
    private static let maxReconnectAttempts = 3
    private static let reconnectDelaySeconds: TimeInterval = 2.0

    private var connection: SRTConnection?
    private var stream: SRTStream?
    private var mixer: MediaMixer?
    private var audioSessionManager: AudioSessionManager
    private var audioLevelMonitor: AudioLevelMonitor?
    private var monitoringTask: Task<Void, Never>?
    private var lastURL: URL?
    private var lastConfiguration: StreamConfiguration?
    private var isUserInitiatedStop = false
    private var reconnectCycleCount = 0
    private var lastReconnectDate: Date?
    /// 再接続サイクルのカウントをリセットするまでの安定接続時間
    private static let reconnectCountResetInterval: TimeInterval = 60.0

    // Callbacks
    var onStateChange: ((StreamState) -> Void)?
    var onBitrateUpdate: ((Double) -> Void)?
    var onAudioLevelUpdate: ((Float) -> Void)?

    // Bitrate monitoring timer
    private var bitrateTimer: Timer?

    init(audioSessionManager: AudioSessionManager = AudioSessionManager()) {
        self.audioSessionManager = audioSessionManager
    }

    /// Starts the streaming session with the given configuration
    func startStreaming(configuration: StreamConfiguration) throws {
        logger.info("Starting streaming to \(configuration.srtURL)")

        // Validate configuration
        guard configuration.isValid else {
            if let error = configuration.validationError {
                throw StreamingError.invalidConfiguration(error)
            }
            throw StreamingError.invalidConfiguration("設定が無効です")
        }

        // Check microphone permission
        guard audioSessionManager.isMicrophonePermissionGranted else {
            throw StreamingError.permissionDenied
        }

        // Setup audio session
        do {
            try audioSessionManager.setupAudioSession()
        } catch {
            throw StreamingError.audioSessionFailed(error.localizedDescription)
        }

        // Build URL with latency parameter
        var urlString = configuration.srtURL
        if !urlString.contains("latency=") {
            let separator = urlString.contains("?") ? "&" : "?"
            urlString += "\(separator)latency=\(configuration.latency)"
        }

        logger.info("Generated SRT URL: \(urlString)")

        guard let url = URL(string: urlString) else {
            logger.error("Invalid URL: \(urlString)")
            throw StreamingError.invalidURL
        }

        // Update state to connecting
        onStateChange?(.connecting)
        isUserInitiatedStop = false
        reconnectCycleCount = 0
        lastReconnectDate = nil
        lastURL = url
        lastConfiguration = configuration

        // Start async streaming setup
        Task {
            do {
                try await performStartStreaming(url: url, configuration: configuration)
            } catch {
                logger.error("Failed to start streaming: \(error.localizedDescription)")
                logger.error("Error details: \(String(describing: error))")
                await MainActor.run {
                    self.onStateChange?(.error("配信開始に失敗しました: \(error.localizedDescription)"))
                }
            }
        }
    }

    private func performStartStreaming(url: URL, configuration: StreamConfiguration) async throws {
        logger.info("performStartStreaming called with URL: \(url.absoluteString)")

        // Create MediaMixer for audio capture
        let mediaMixer = MediaMixer()
        logger.info("MediaMixer created")

        // Attach audio device (microphone)
        guard let audioDevice = AVCaptureDevice.default(for: .audio) else {
            logger.error("No audio device found")
            throw StreamingError.audioDeviceNotFound
        }
        logger.info("Audio device found: \(audioDevice.localizedName)")

        try await mediaMixer.attachAudio(audioDevice, track: 0)
        logger.info("Audio device attached to mixer")

        // Create SRT connection and stream
        let srtConnection = SRTConnection()
        let srtStream = SRTStream(connection: srtConnection)
        logger.info("SRT connection and stream created")

        // Configure audio settings
        var audioSettings = await srtStream.audioSettings
        audioSettings.bitRate = configuration.bitrate
        try await srtStream.setAudioSettings(audioSettings)
        logger.info("Audio settings configured: bitrate=\(configuration.bitrate)")

        // Set expected media to audio only
        await srtStream.setExpectedMedias([.audio])
        logger.info("Expected media set to audio only")

        // Add stream as output to mixer
        await mediaMixer.addOutput(srtStream)
        logger.info("Stream added to mixer output")

        // Start mixer
        await mediaMixer.startRunning()
        logger.info("Mixer started")

        // Connect to SRT server (latency is already in URL)
        logger.info("Attempting to connect to SRT server: \(url.absoluteString)")
        try await srtConnection.connect(url)
        logger.info("SRT connection established")

        // Check if connected
        let isConnected = await srtConnection.connected
        if !isConnected {
            throw StreamingError.connectionFailed("接続に失敗しました")
        }

        // Start publishing
        await srtStream.publish()

        // Store references
        self.connection = srtConnection
        self.stream = srtStream
        self.mixer = mediaMixer

        // Update state to streaming
        await MainActor.run {
            self.onStateChange?(.streaming)
            self.logger.info("Streaming started successfully")
        }

        // Start monitoring connection state
        startMonitoring(connection: srtConnection)

        // Start bitrate monitoring
        await MainActor.run {
            self.startBitrateMonitoring(bitrate: configuration.bitrate)
        }

        // Start audio level monitoring
        await MainActor.run {
            self.startAudioLevelMonitoring()
        }
    }

    /// Stops the streaming session
    func stopStreaming() {
        logger.info("Stopping streaming")
        isUserInitiatedStop = true

        onStateChange?(.disconnecting)

        // Stop bitrate monitoring
        stopBitrateMonitoring()

        // Stop audio level monitoring
        stopAudioLevelMonitoring()

        // Cancel monitoring task
        monitoringTask?.cancel()
        monitoringTask = nil

        // Stop async cleanup
        Task {
            await performStopStreaming()
        }
    }

    /// リソース解放（audioSession deactivateや状態通知は行わない）
    private func cleanupCurrentResources() async {
        // Close stream
        if let stream = stream {
            await stream.close()
        }

        // Stop and cleanup mixer
        if let mixer = mixer {
            await mixer.stopRunning()
            try? await mixer.attachAudio(nil)
            if let stream = stream {
                await mixer.removeOutput(stream)
            }
        }

        // Clear references
        stream = nil
        connection = nil
        mixer = nil
    }

    private func performStopStreaming() async {
        await cleanupCurrentResources()

        // Deactivate audio session
        audioSessionManager.deactivateAudioSession()

        await MainActor.run {
            self.onStateChange?(.idle)
            self.logger.info("Streaming stopped")
        }
    }

    // MARK: - Private Methods

    private func startMonitoring(connection: SRTConnection) {
        monitoringTask = Task { [weak self] in
            guard let self else { return }
            var hasSeenConnected = false
            for await connected in await connection.$connected.values {
                if Task.isCancelled { break }
                if connected {
                    hasSeenConnected = true
                    continue
                }

                // 初期値の false を無視（接続確立前の値）
                guard hasSeenConnected else {
                    self.logger.info("Ignoring initial false from $connected (not yet seen connected=true)")
                    continue
                }

                // ユーザー操作による停止なら再接続しない
                if self.isUserInitiatedStop { break }

                self.logger.info("Connection lost, entering grace period (\(Self.gracePeriodSeconds)s)")

                // グレースピリオド: 一時的な途絶からの自動復旧を待つ
                let recovered = await self.waitForRecovery(connection: connection, timeout: Self.gracePeriodSeconds)
                if Task.isCancelled { break }

                if recovered {
                    self.logger.info("Connection recovered during grace period")
                    // 新しいモニタリングループを開始
                    self.startMonitoring(connection: connection)
                    return
                }

                // 再接続サイクルの上限チェック
                // 前回の再接続から十分時間が経っていればカウンタをリセット
                if let lastDate = self.lastReconnectDate,
                   Date().timeIntervalSince(lastDate) > Self.reconnectCountResetInterval {
                    self.reconnectCycleCount = 0
                }

                if self.reconnectCycleCount >= Self.maxReconnectAttempts {
                    self.logger.error("Max reconnection cycles reached (\(self.reconnectCycleCount)), giving up")
                    self.stopBitrateMonitoring()
                    self.stopAudioLevelMonitoring()
                    await self.cleanupCurrentResources()
                    await MainActor.run {
                        self.onStateChange?(.error("接続が切断されました（再接続上限）"))
                    }
                    self.audioSessionManager.deactivateAudioSession()
                    return
                }

                // グレースピリオド超過 → 再接続を試みる
                self.reconnectCycleCount += 1
                self.lastReconnectDate = Date()
                self.logger.info("Grace period expired, attempting reconnection (cycle \(self.reconnectCycleCount)/\(Self.maxReconnectAttempts))")
                self.stopBitrateMonitoring()
                self.stopAudioLevelMonitoring()
                await self.cleanupCurrentResources()

                if Task.isCancelled { break }

                let reconnected = await self.attemptReconnection()
                if !reconnected {
                    // 全リトライ失敗
                    await MainActor.run {
                        self.onStateChange?(.error("接続が切断されました"))
                    }
                    self.audioSessionManager.deactivateAudioSession()
                }
                return
            }
        }
    }

    /// グレースピリオド中に接続が復旧するか待つ
    private func waitForRecovery(connection: SRTConnection, timeout: TimeInterval) async -> Bool {
        let startTime = Date()
        let pollInterval: UInt64 = 250_000_000 // 250ms in nanoseconds

        while Date().timeIntervalSince(startTime) < timeout {
            if Task.isCancelled { return false }
            try? await Task.sleep(nanoseconds: pollInterval)
            let isConnected = await connection.connected
            if isConnected { return true }
        }
        return false
    }

    /// 最大maxReconnectAttempts回まで再接続を試みる
    private func attemptReconnection() async -> Bool {
        guard let url = lastURL, let configuration = lastConfiguration else {
            logger.error("No saved URL/configuration for reconnection")
            return false
        }

        for attempt in 1...Self.maxReconnectAttempts {
            if Task.isCancelled || isUserInitiatedStop { return false }

            logger.info("Reconnection attempt \(attempt)/\(Self.maxReconnectAttempts)")
            await MainActor.run {
                self.onStateChange?(.reconnecting(attempt: attempt, maxAttempts: Self.maxReconnectAttempts))
            }

            // 再接続間隔を待つ（初回は即試行）
            if attempt > 1 {
                try? await Task.sleep(nanoseconds: UInt64(Self.reconnectDelaySeconds * 1_000_000_000))
            }

            if Task.isCancelled || isUserInitiatedStop { return false }

            do {
                try await performStartStreaming(url: url, configuration: configuration)
                logger.info("Reconnection succeeded on attempt \(attempt)")
                return true
            } catch {
                logger.error("Reconnection attempt \(attempt) failed: \(error.localizedDescription)")
            }
        }

        return false
    }

    /// リソースを強制的に解放してidleへ戻す（ViewModel経由で呼び出す）
    func forceStop() {
        logger.info("Force stop requested")
        isUserInitiatedStop = true
        stopBitrateMonitoring()
        stopAudioLevelMonitoring()
        monitoringTask?.cancel()
        monitoringTask = nil
        Task {
            await performStopStreaming()
        }
    }

    private func startBitrateMonitoring(bitrate: Int) {
        let bitrateKbps = Double(bitrate) / 1000.0

        bitrateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            // Report configured bitrate
            self.onBitrateUpdate?(bitrateKbps)
        }
    }

    private func stopBitrateMonitoring() {
        bitrateTimer?.invalidate()
        bitrateTimer = nil
    }

    private func startAudioLevelMonitoring() {
        let monitor = AudioLevelMonitor()
        monitor.onLevelUpdate = { [weak self] level in
            self?.onAudioLevelUpdate?(level)
        }
        monitor.startMonitoring()
        audioLevelMonitor = monitor
        logger.info("Audio level monitoring started")
    }

    private func stopAudioLevelMonitoring() {
        audioLevelMonitor?.stopMonitoring()
        audioLevelMonitor = nil
        logger.info("Audio level monitoring stopped")
    }

    deinit {
        stopBitrateMonitoring()
        stopAudioLevelMonitoring()
        monitoringTask?.cancel()
    }
}

// MARK: - Streaming Errors

enum StreamingError: LocalizedError {
    case invalidConfiguration(String)
    case permissionDenied
    case audioSessionFailed(String)
    case audioDeviceNotFound
    case invalidURL
    case connectionFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration(let reason):
            return reason
        case .permissionDenied:
            return "マイクへのアクセスが許可されていません"
        case .audioSessionFailed(let reason):
            return "オーディオセッションの設定に失敗しました: \(reason)"
        case .audioDeviceNotFound:
            return "オーディオデバイスが見つかりません"
        case .invalidURL:
            return "無効なSRT URLです"
        case .connectionFailed(let reason):
            return "接続に失敗しました: \(reason)"
        }
    }
}
