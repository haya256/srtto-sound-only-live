//
//  AudioSessionManager.swift
//  SRTAudioStreamer
//
//  Created by Claude Code
//

import AVFoundation
import os.log

/// Manages AVAudioSession setup and microphone permissions
class AudioSessionManager {
    private let logger = Logger(subsystem: "com.example.SRTAudioStreamer", category: "AudioSession")

    /// Sets up the audio session for recording and playback
    func setupAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()

        do {
            // Configure for playback and record to enable microphone input
            try audioSession.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetooth]
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

    var errorDescription: String? {
        switch self {
        case .setupFailed(let reason):
            return "オーディオセッションの設定に失敗しました: \(reason)"
        case .permissionDenied:
            return "マイクへのアクセスが許可されていません"
        }
    }
}
