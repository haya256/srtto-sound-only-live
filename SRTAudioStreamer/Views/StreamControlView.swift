//
//  StreamControlView.swift
//  SRTAudioStreamer
//
//  Created by Claude Code
//

import SwiftUI

/// View for controlling the streaming session
struct StreamControlView: View {
    @ObservedObject var viewModel: StreamViewModel

    var body: some View {
        VStack(spacing: 24) {
            // SRT URL input
            VStack(alignment: .leading, spacing: 8) {
                Text("SRT URL")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                TextField("srt://192.168.1.10:9710?mode=caller", text: $viewModel.configuration.srtURL)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .disabled(viewModel.isStreaming)
                    .keyboardType(.URL)

                // Display entered URL with word wrapping
                if !viewModel.configuration.srtURL.isEmpty {
                    Text(viewModel.configuration.srtURL)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
            }

            // Bitrate selection
            VStack(alignment: .leading, spacing: 8) {
                Text("ビットレート")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Picker("ビットレート", selection: $viewModel.configuration.bitrate) {
                    ForEach(StreamConfiguration.bitratePresets, id: \.self) { bitrate in
                        Text("\(bitrate) kbps")
                            .tag(bitrate * 1000)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(viewModel.isStreaming)
            }

            // Start/Stop button
            Button(action: {
                if viewModel.isStreaming {
                    viewModel.stopStreaming()
                } else {
                    viewModel.startStreaming()
                }
            }) {
                HStack {
                    Image(systemName: viewModel.isStreaming ? "stop.circle.fill" : "play.circle.fill")
                        .font(.title2)

                    Text(viewModel.isStreaming ? "配信停止" : "配信開始")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(buttonColor)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(!canToggleStreaming)
        }
        .padding()
    }

    private var buttonColor: Color {
        if !canToggleStreaming {
            return .gray
        }
        return viewModel.isStreaming ? .red : .blue
    }

    private var canToggleStreaming: Bool {
        if viewModel.isStreaming {
            return true
        } else {
            return viewModel.canStartStreaming && !viewModel.currentState.isTransitioning
        }
    }
}

#Preview {
    StreamControlView(viewModel: StreamViewModel())
}
