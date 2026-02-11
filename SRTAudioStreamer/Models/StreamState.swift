//
//  StreamState.swift
//  SRTAudioStreamer
//
//  Created by Claude Code
//

import Foundation

/// Represents the current state of the streaming session
enum StreamState: Equatable {
    case idle
    case connecting
    case streaming
    case disconnecting
    case error(String)

    var description: String {
        switch self {
        case .idle:
            return "準備中"
        case .connecting:
            return "接続中"
        case .streaming:
            return "配信中"
        case .disconnecting:
            return "切断中"
        case .error(let message):
            return "エラー: \(message)"
        }
    }

    var isActive: Bool {
        switch self {
        case .streaming:
            return true
        default:
            return false
        }
    }

    var isTransitioning: Bool {
        switch self {
        case .connecting, .disconnecting:
            return true
        default:
            return false
        }
    }
}
