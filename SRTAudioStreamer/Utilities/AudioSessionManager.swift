//
//  AudioSessionManager.swift
//  SRTAudioStreamer
//
//  Created by Claude Code
//

import AVFoundation
import os.log

/// Identifiable wrapper for AVAudioSessionPortDescription
struct AudioInputPort: Identifiable, Hashable {
    let id: String
    let name: String
    let portType: AVAudioSession.Port

    init(port: AVAudioSessionPortDescription) {
        self.id = port.uid
        self.name = port.portName
        self.portType = port.portType
    }

    static func == (lhs: AudioInputPort, rhs: AudioInputPort) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Manages AVAudioSession setup and microphone permissions
class AudioSessionManager {
    private let logger = Logger(subsystem: "com.example.SRTAudioStreamer", category: "AudioSession")

    /// Callback invoked when available inputs change (route change)
    var onAvailableInputsChanged: (() -> Void)?

    /// Returns the list of available audio input ports
    var availableInputs: [AudioInputPort] {
        let ports = AVAudioSession.sharedInstance().availableInputs ?? []
        return ports.map { AudioInputPort(port: $0) }
    }

    /// Returns the currently active input port
    var currentInput: AudioInputPort? {
        guard let route = AVAudioSession.sharedInstance().currentRoute.inputs.first else { return nil }
        return AudioInputPort(port: route)
    }

    /// Sets the preferred audio input
    func setPreferredInput(_ port: AudioInputPort?) throws {
        let session = AVAudioSession.sharedInstance()
        guard let port = port else {
            try session.setPreferredInput(nil)
            logger.info("Preferred input reset to default")
            return
        }
        guard let match = session.availableInputs?.first(where: { $0.uid == port.id }) else {
            throw AudioSessionError.inputSelectionFailed("選択したデバイスが見つかりません")
        }
        do {
            try session.setPreferredInput(match)
            logger.info("Preferred input set to \(port.name)")
        } catch {
            logger.error("Failed to set preferred input: \(error.localizedDescription)")
            throw AudioSessionError.inputSelectionFailed(error.localizedDescription)
        }
    }

    /// Starts observing audio route changes
    func startRouteChangeObservation() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
        logger.info("Route change observation started")
    }

    /// Stops observing audio route changes
    func stopRouteChangeObservation() {
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.routeChangeNotification, object: nil)
        logger.info("Route change observation stopped")
    }

    @objc private func handleRouteChange(notification: Notification) {
        logger.info("Audio route changed")
        onAvailableInputsChanged?()
    }

    /// Sets up the audio session for recording and playback
    func setupAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()

        do {
            // Configure for playback and record to enable microphone input
            // .duckOthers ensures other apps' audio (like Safari preview) won't interrupt our recording
            try audioSession.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetooth, .duckOthers]
            )

            // Set the sample rate to 44.1 kHz
            try audioSession.setPreferredSampleRate(44100.0)

            // Activate the audio session
            try audioSession.setActive(true)

            logger.info("Audio session configured successfully")
        } catch {
            logger.error("Failed to setup audio session: \(error.localizedDescription)")
            throw AudioSessionError.setupFailed(error.localizedDescription)
        }
    }

    /// Requests microphone permission from the user
    func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        let audioSession = AVAudioSession.sharedInstance()

        switch audioSession.recordPermission {
        case .granted:
            logger.info("Microphone permission already granted")
            completion(true)

        case .denied:
            logger.warning("Microphone permission denied")
            completion(false)

        case .undetermined:
            logger.info("Requesting microphone permission")
            audioSession.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.logger.info("Microphone permission granted")
                    } else {
                        self.logger.warning("Microphone permission denied by user")
                    }
                    completion(granted)
                }
            }

        @unknown default:
            logger.error("Unknown microphone permission state")
            completion(false)
        }
    }

    /// Checks if microphone permission is granted
    var isMicrophonePermissionGranted: Bool {
        return AVAudioSession.sharedInstance().recordPermission == .granted
    }

    /// Deactivates the audio session
    func deactivateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false)
            logger.info("Audio session deactivated")
        } catch {
            logger.error("Failed to deactivate audio session: \(error.localizedDescription)")
        }
    }
}

/// Errors related to audio session management
enum AudioSessionError: LocalizedError {
    case setupFailed(String)
    case permissionDenied
    case inputSelectionFailed(String)

    var errorDescription: String? {
        switch self {
        case .setupFailed(let reason):
            return "オーディオセッションの設定に失敗しました: \(reason)"
        case .permissionDenied:
            return "マイクへのアクセスが許可されていません"
        case .inputSelectionFailed(let reason):
            return "マイク入力の選択に失敗しました: \(reason)"
        }
    }
}
