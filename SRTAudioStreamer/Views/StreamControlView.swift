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

    @State private var chatURL: String = ""
    @State private var showingBrowser = false
    @State private var browserURL: URL?

    var body: some View {
        VStack(spacing: 24) {
            // SRT URL input
            VStack(alignment: .leading, spacing: 8) {
                Text("SRT URL")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                TextField("srt://live.listen.style:8890?...", text: $viewModel.configuration.srtURL)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .disabled(viewModel.isStreaming)
                    .keyboardType(.URL)

                // Display entered URL with word wrapping
                /*
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
                */
                 
                // URL history
                if !viewModel.urlHistory.isEmpty && !viewModel.isStreaming {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("履歴")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        ForEach(Array(viewModel.urlHistory.enumerated()), id: \.offset) { index, url in
                            HStack {
                                Button {
                                    viewModel.configuration.srtURL = url
                                } label: {
                                    Text(url)
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }

                                Button {
                                    viewModel.deleteURLFromHistory(at: index)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray6))
                            .cornerRadius(6)
                        }
                    }
                }
            }

            // Chat viewer
            VStack(alignment: .leading, spacing: 8) {
                Text("チャット確認")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack {
                    TextField("https://...", text: $chatURL)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)

                    Button("開く") {
                        if let url = URL(string: chatURL), url.scheme != nil {
                            browserURL = url
                            showingBrowser = true
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(chatURL.isEmpty)
                }
            }
            .sheet(isPresented: $showingBrowser) {
                if let url = browserURL {
                    SafariBrowserView(url: url)
                        .ignoresSafeArea()
                        .presentationDetents([.fraction(0.5)])
                }
            }

            // Microphone input selection
            VStack(alignment: .leading, spacing: 8) {
                Text("マイク入力")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Picker("マイク入力", selection: Binding(
                    get: { viewModel.selectedInputID ?? "" },
                    set: { newValue in
                        if newValue.isEmpty {
                            viewModel.selectInput(nil)
                        } else if let port = viewModel.availableInputs.first(where: { $0.id == newValue }) {
                            viewModel.selectInput(port)
                        }
                    }
                )) {
                    Text("デフォルト").tag("")
                    ForEach(viewModel.availableInputs) { port in
                        Text(port.name).tag(port.id)
                    }
                }
                .pickerStyle(.menu)
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

            // 強制リセットボタン（エラー時またはスタック時に表示）
            if viewModel.errorMessage != nil || isStuck {
                Button(action: {
                    viewModel.forceReset()
                }) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                            .font(.title2)
                        Text("強制リセット")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(12)
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

            // App version
            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
               let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                Text("v\(version) (\(build))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
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

    /// 操作不能なスタック状態（配信中でも待機中でも遷移中でもない）
    private var isStuck: Bool {
        !viewModel.isStreaming
            && !viewModel.canStartStreaming
            && !viewModel.currentState.isTransitioning
    }
}

#Preview {
    StreamControlView(viewModel: StreamViewModel())
}
