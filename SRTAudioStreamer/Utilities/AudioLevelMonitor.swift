//
//  AudioLevelMonitor.swift
//  SRTAudioStreamer
//
//  Created by Claude Code
//

import AVFoundation
import os.log

/// Monitors audio input levels
class AudioLevelMonitor {
    private let logger = Logger(subsystem: "com.example.SRTAudioStreamer", category: "AudioLevel")

    private var audioRecorder: AVAudioRecorder?
    private var levelTimer: Timer?

    var onLevelUpdate: ((Float) -> Void)?

    /// Starts monitoring audio levels
    func startMonitoring() {
        let audioSession = AVAudioSession.sharedInstance()

        do {
            // Set up a dummy audio recorder just for metering
            let url = URL(fileURLWithPath: "/dev/null")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatAppleLossless),
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.min.rawValue
            ]

            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()

            // Start timer to update levels
            levelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.updateLevel()
            }

            logger.info("Audio level monitoring started")
        } catch {
            logger.error("Failed to start audio level monitoring: \(error.localizedDescription)")
        }
    }

    /// Stops monitoring audio levels
    func stopMonitoring() {
        levelTimer?.invalidate()
        levelTimer = nil

        audioRecorder?.stop()
        audioRecorder = nil

        logger.info("Audio level monitoring stopped")
    }

    private func updateLevel() {
        guard let recorder = audioRecorder else { return }

        recorder.updateMeters()

        // Get average power in dB (-160 to 0)
        let averagePower = recorder.averagePower(forChannel: 0)

        // Convert to normalized value (0.0 to 1.0)
        // -160 dB is silence, 0 dB is max
        let normalized = pow(10, averagePower / 20)

        // Convert to 0-100 scale
        let level = min(100, max(0, normalized * 100))

        onLevelUpdate?(level)
    }

    deinit {
        stopMonitoring()
    }
}
