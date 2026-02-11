//
//  StreamViewModel.swift
//  SRTAudioStreamer
//
//  Created by Claude Code
//

import Foundation
import Combine
import os.log

/// ViewModel for managing streaming state and business logic
@MainActor
class StreamViewModel: ObservableObject {
    private let logger = Logger(subsystem: "com.example.SRTAudioStreamer", category: "ViewModel")

    // MARK: - Published Properties

    @Published var configuration = StreamConfiguration()
    @Published var currentState: StreamState = .idle
    @Published var currentBitrate: Double = 0.0
    @Published var currentAudioLevel: Float = 0.0
    @Published var errorMessage: String?

    // MARK: - Private Properties

    private let streamingService: SRTStreamingService
    private let audioSessionManager: AudioSessionManager

    // MARK: - Initialization

    init(
        streamingService: SRTStreamingService = SRTStreamingService(),
        audioSessionManager: AudioSessionManager = AudioSessionManager()
    ) {
        self.streamingService = streamingService
        self.audioSessionManager = audioSessionManager

        setupCallbacks()
    }

    // MARK: - Public Methods

    /// Starts the streaming session
    func startStreaming() {
        logger.info("User requested to start streaming")
        errorMessage = nil

        // Check microphone permission first
        audioSessionManager.requestMicrophonePermission { [weak self] granted in
            guard let self = self else { return }

            Task { @MainActor in
                if granted {
                    await self.performStartStreaming()
                } else {
                    self.currentState = .error("マイクへのアクセスが許可されていません")
                    self.errorMessage = "設定アプリでマイクへのアクセスを許可してください"
                }
            }
        }
    }

    /// Stops the streaming session
    func stopStreaming() {
        logger.info("User requested to stop streaming")
        errorMessage = nil

        streamingService.stopStreaming()
    }

    /// Updates the bitrate in the configuration
    func updateBitrate(_ bitrate: Int) {
        configuration.bitrate = bitrate
        logger.info("Bitrate updated to \(bitrate) bps")
    }

    // MARK: - Private Methods

    private func performStartStreaming() async {
        do {
            try streamingService.startStreaming(configuration: configuration)
            logger.info("Streaming started successfully")
        } catch {
            logger.error("Failed to start streaming: \(error.localizedDescription)")
            currentState = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }

    private func setupCallbacks() {
        // State change callback
        streamingService.onStateChange = { [weak self] state in
            Task { @MainActor in
                guard let self = self else { return }
                self.currentState = state

                // Update error message if in error state
                if case .error(let message) = state {
                    self.errorMessage = message
                } else {
                    self.errorMessage = nil
                }
            }
        }

        // Bitrate update callback
        streamingService.onBitrateUpdate = { [weak self] bitrate in
            Task { @MainActor in
                guard let self = self else { return }
                self.currentBitrate = bitrate
            }
        }

        // Audio level update callback
        streamingService.onAudioLevelUpdate = { [weak self] level in
            Task { @MainActor in
                guard let self = self else { return }
                self.currentAudioLevel = level
            }
        }
    }

    // MARK: - Computed Properties

    var isStreaming: Bool {
        return currentState.isActive
    }

    var canStartStreaming: Bool {
        return currentState == .idle && configuration.isValid
    }

    var canStopStreaming: Bool {
        return currentState.isActive || currentState.isTransitioning
    }

    var stateDescription: String {
        return currentState.description
    }
}
