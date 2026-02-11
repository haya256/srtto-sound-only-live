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

    private var connection: SRTConnection?
    private var stream: SRTStream?
    private var mixer: MediaMixer?
    private var audioSessionManager: AudioSessionManager
    private var audioLevelMonitor: AudioLevelMonitor?
    private var monitoringTask: Task<Void, Never>?

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

    private func performStopStreaming() async {
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

        // Deactivate audio session
        audioSessionManager.deactivateAudioSession()

        await MainActor.run {
            self.onStateChange?(.idle)
            self.logger.info("Streaming stopped")
        }
    }

    // MARK: - Private Methods

    private func startMonitoring(connection: SRTConnection) {
        monitoringTask = Task {
            for await connected in await connection.$connected.values {
                await MainActor.run {
                    if connected {
                        self.onStateChange?(.streaming)
                    } else {
                        self.onStateChange?(.error("接続が切断されました"))
                    }
                }
            }
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
