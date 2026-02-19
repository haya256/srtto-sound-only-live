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
    @Published var availableInputs: [AudioInputPort] = []
    @Published var selectedInputID: String?
    @Published var urlHistory: [String] = []

    // MARK: - Private Properties

    private static let urlHistoryKey = "srt_url_history"
    private static let maxHistoryCount = 10

    private let streamingService: SRTStreamingService
    private let audioSessionManager: AudioSessionManager

    // MARK: - Initialization

    init(
        streamingService: SRTStreamingService = SRTStreamingService(),
        audioSessionManager: AudioSessionManager = AudioSessionManager()
    ) {
        self.streamingService = streamingService
        self.audioSessionManager = audioSessionManager
        self.urlHistory = UserDefaults.standard.stringArray(forKey: Self.urlHistoryKey) ?? []

        setupCallbacks()
        setupAudioInputs()
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

    /// Selects an audio input by its port ID (nil = system default)
    func selectInput(_ port: AudioInputPort?) {
        do {
            try audioSessionManager.setPreferredInput(port)
            selectedInputID = port?.id
            logger.info("Audio input selected: \(port?.name ?? "Default")")
        } catch {
            logger.error("Failed to select audio input: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    /// Deletes a URL from history at the given index
    func deleteURLFromHistory(at index: Int) {
        guard urlHistory.indices.contains(index) else { return }
        urlHistory.remove(at: index)
        UserDefaults.standard.set(urlHistory, forKey: Self.urlHistoryKey)
    }

    /// Refreshes the list of available audio inputs
    func refreshAvailableInputs() {
        availableInputs = audioSessionManager.availableInputs
        // If the previously selected device is no longer available, reset to default
        if let selectedID = selectedInputID,
           !availableInputs.contains(where: { $0.id == selectedID }) {
            selectedInputID = nil
            logger.info("Previously selected input no longer available, reset to default")
        }
    }

    // MARK: - Private Methods

    private func setupAudioInputs() {
        do {
            try audioSessionManager.setupAudioSession()
        } catch {
            logger.error("Failed to setup audio session for input enumeration: \(error.localizedDescription)")
        }
        refreshAvailableInputs()

        audioSessionManager.onAvailableInputsChanged = { [weak self] in
            Task { @MainActor in
                self?.refreshAvailableInputs()
            }
        }
        audioSessionManager.startRouteChangeObservation()
    }

    private func performStartStreaming() async {
        do {
            try streamingService.startStreaming(configuration: configuration)
            logger.info("Streaming started successfully")
            saveURLToHistory(configuration.srtURL)
        } catch {
            logger.error("Failed to start streaming: \(error.localizedDescription)")
            currentState = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }

    private func saveURLToHistory(_ url: String) {
        guard !url.isEmpty else { return }
        if let existingIndex = urlHistory.firstIndex(of: url) {
            urlHistory.remove(at: existingIndex)
        }
        urlHistory.insert(url, at: 0)
        if urlHistory.count > Self.maxHistoryCount {
            urlHistory = Array(urlHistory.prefix(Self.maxHistoryCount))
        }
        UserDefaults.standard.set(urlHistory, forKey: Self.urlHistoryKey)
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
