//
//  StreamConfiguration.swift
//  SRTAudioStreamer
//
//  Created by Claude Code
//

import Foundation

/// A named SRT address entry saved in history
struct SRTEntry: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var url: String

    /// Display text: "名称　srt://host:port…lastparam" format
    var displayText: String {
        let truncated = SRTEntry.truncatedURL(url)
        return name.isEmpty ? truncated : "\(name)　\(truncated)"
    }

    static func truncatedURL(_ url: String) -> String {
        guard let components = URLComponents(string: url),
              let queryItems = components.queryItems, !queryItems.isEmpty else {
            return url
        }
        let scheme = components.scheme ?? "srt"
        let host = components.host ?? ""
        let port = components.port.map { ":\($0)" } ?? ""
        let base = "\(scheme)://\(host)\(port)"
        let last = queryItems.last!
        let lastParam = last.value.map { "\(last.name)=\($0)" } ?? last.name
        return queryItems.count == 1 ? "\(base)?\(lastParam)" : "\(base)…\(lastParam)"
    }
}

/// Configuration settings for SRT streaming
struct StreamConfiguration {
    /// SRT server URL (e.g., srt://192.168.1.10:9710?mode=caller)
    var srtURL: String = ""

    /// Name label for this SRT address
    var srtName: String = ""

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
