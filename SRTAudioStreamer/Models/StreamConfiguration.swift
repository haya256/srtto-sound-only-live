//
//  StreamConfiguration.swift
//  SRTAudioStreamer
//
//  Created by Claude Code
//

import Foundation

/// Configuration settings for SRT streaming
struct StreamConfiguration {
    /// SRT server URL (e.g., srt://192.168.1.10:9710?mode=caller)
    var srtURL: String = ""

    /// SRT latency in milliseconds (default: 120ms)
    var latency: Int32 = 120

    /// Audio bitrate in bits per second (default: 64000 = 64 kbps)
    var bitrate: Int = 64000

    /// Audio sample rate in Hz (default: 44100 Hz)
    var sampleRate: Double = 44100

    /// Available bitrate presets (in kbps)
    static let bitratePresets: [Int] = [32, 64, 96, 128]

    /// Validates the configuration
    var isValid: Bool {
        return !srtURL.isEmpty &&
               srtURL.hasPrefix("srt://") &&
               bitrate > 0 &&
               sampleRate > 0
    }

    /// Error message if configuration is invalid
    var validationError: String? {
        if srtURL.isEmpty {
            return "SRT URLを入力してください"
        }
        if !srtURL.hasPrefix("srt://") {
            return "無効なSRT URLです"
        }
        if bitrate <= 0 {
            return "ビットレートが無効です"
        }
        if sampleRate <= 0 {
            return "サンプルレートが無効です"
        }
        return nil
    }
}
