//
//  StreamStatusView.swift
//  SRTAudioStreamer
//
//  Created by Claude Code
//

import SwiftUI

/// View displaying the current streaming status
struct StreamStatusView: View {
    let state: StreamState
    let bitrate: Double
    let audioLevel: Float
    let errorMessage: String?
    let eventLog: [StreamViewModel.LogEntry]

    var body: some View {
        VStack(spacing: 16) {
            // Audio level display (only when streaming) - 最上部
            if case .streaming = state {
                HStack(spacing: 12) {
                    Circle()
                        .fill(audioLevel > 5 ? Color.green : Color.gray.opacity(0.3))
                        .frame(width: 12, height: 12)
                        .animation(.easeInOut(duration: 0.2), value: audioLevel)

                    Image(systemName: "mic.fill")
                        .foregroundColor(audioLevel > 5 ? .green : .gray)
                        .font(.caption)

                    Text(String(format: "音量: %.0f", audioLevel))
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Spacer()
                }
            }

            // Reconnecting indicator
            if case .reconnecting = state {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(state.description)
                        .font(.headline)
                        .foregroundColor(.orange)
                }
            }

            // Status indicator
            if case .reconnecting = state {
                // Already shown above
            } else {
                HStack(spacing: 12) {
                    Circle()
                        .fill(stateColor)
                        .frame(width: 16, height: 16)

                    Text(state.description)
                        .font(.headline)
                        .foregroundColor(stateColor)
                }
            }

            // Bitrate display (only when streaming)
            if case .streaming = state {
                HStack {
                    Image(systemName: "waveform")
                        .foregroundColor(.blue)

                    Text(String(format: "%.1f kbps", bitrate))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            // Error message display
            if let errorMessage = errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)

                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.leading)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }

            // Event log
            if !eventLog.isEmpty {
                DisclosureGroup("イベントログ (\(eventLog.count)件)") {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 2) {
                                ForEach(eventLog.reversed()) { entry in
                                    HStack(alignment: .top, spacing: 6) {
                                        Text(entry.timeString)
                                            .font(.system(.caption2, design: .monospaced))
                                            .foregroundColor(.secondary)
                                            .frame(width: 60, alignment: .leading)
                                        Text(entry.message)
                                            .font(.caption2)
                                            .foregroundColor(.primary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .id(entry.id)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .frame(maxHeight: 160)
                    }
                }
                .font(.caption)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var stateColor: Color {
        switch state {
        case .idle:
            return .gray
        case .connecting:
            return .orange
        case .streaming:
            return .green
        case .disconnecting:
            return .orange
        case .reconnecting:
            return .orange
        case .error:
            return .red
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        StreamStatusView(
            state: .idle,
            bitrate: 0,
            audioLevel: 0,
            errorMessage: nil,
            eventLog: []
        )

        StreamStatusView(
            state: .streaming,
            bitrate: 64.0,
            audioLevel: 45.0,
            errorMessage: nil,
            eventLog: [
                .init(date: Date().addingTimeInterval(-30), message: "配信中"),
                .init(date: Date().addingTimeInterval(-90), message: "再接続中 (1/5)"),
                .init(date: Date().addingTimeInterval(-100), message: "エラー: 接続が切断されました"),
            ]
        )

        StreamStatusView(
            state: .error("接続に失敗しました"),
            bitrate: 0,
            audioLevel: 0,
            errorMessage: "サーバーに接続できません",
            eventLog: []
        )
    }
    .padding()
}
