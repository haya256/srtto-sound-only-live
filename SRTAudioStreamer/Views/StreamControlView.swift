//
//  StreamControlView.swift
//  SRTAudioStreamer
//
//  Created by Claude Code
//

import SwiftUI
import UIKit

/// View for controlling the streaming session
struct StreamControlView: View {
    @ObservedObject var viewModel: StreamViewModel
    @Binding var showingBrowser: Bool
    @Binding var browserURL: URL?

    @State private var chatURL: String = ""
    @FocusState private var srtURLFocused: Bool
    @FocusState private var chatURLFocused: Bool
    @State private var renamingIndex: Int? = nil
    @State private var renamingText: String = ""
    @FocusState private var renamingFocused: Bool

    var body: some View {
        VStack(spacing: 24) {
            // SRT URL input
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 2) {
                    Text("SRTサーバー(URL)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("*")
                        .font(.caption)
                        .foregroundColor(.red)
                }

                ZStack {
                    TextField("srt://live.listen.style:8890?...", text: $viewModel.configuration.srtURL)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .disabled(viewModel.isStreaming)
                        .keyboardType(.URL)
                        .focused($srtURLFocused)

                    if !srtURLFocused && !viewModel.configuration.srtURL.isEmpty {
                        Text(viewModel.configuration.srtURL)
                            .font(.body)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 7)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(.systemGray4), lineWidth: 0.5)
                            )
                            .onTapGesture {
                                srtURLFocused = true
                            }
                    }
                }

                // URL history
                if !viewModel.urlHistory.isEmpty && !viewModel.isStreaming {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("履歴")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        ForEach(Array(viewModel.urlHistory.enumerated()), id: \.offset) { index, entry in
                            VStack(spacing: 4) {
                                HStack {
                                    Button {
                                        viewModel.configuration.srtName = entry.name
                                        viewModel.configuration.srtURL = entry.url
                                    } label: {
                                        HStack(spacing: 4) {
                                            if !entry.name.isEmpty {
                                                Text(entry.name)
                                                    .font(.caption.bold())
                                                    .foregroundColor(.primary)
                                                    .lineLimit(1)
                                                    .fixedSize(horizontal: true, vertical: false)
                                            }
                                            Text(entry.url)
                                                .font(.caption)
                                                .foregroundColor(entry.name.isEmpty ? .primary : .secondary)
                                                .lineLimit(1)
                                                .truncationMode(.head)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    }
                                    .simultaneousGesture(LongPressGesture().onEnded { _ in
                                        renamingText = entry.name
                                        renamingIndex = index
                                        renamingFocused = true
                                    })

                                    Button {
                                        viewModel.deleteURLFromHistory(at: index)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                            .font(.caption)
                                    }
                                    .buttonStyle(.plain)
                                }

                                if renamingIndex == index {
                                    HStack {
                                        TextField("名前を入力", text: $renamingText)
                                            .textFieldStyle(.roundedBorder)
                                            .font(.caption)
                                            .focused($renamingFocused)
                                            .onSubmit {
                                                viewModel.renameEntry(at: index, name: renamingText)
                                                renamingIndex = nil
                                            }
                                        Button {
                                            viewModel.renameEntry(at: index, name: renamingText)
                                            renamingIndex = nil
                                        } label: {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.blue)
                                        }
                                        .buttonStyle(.plain)
                                        Button {
                                            renamingIndex = nil
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
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
                Text("チャット確認URL")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack {
                    ZStack {
                        TextField("https://...", text: $chatURL)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .focused($chatURLFocused)

                        if !chatURLFocused && !chatURL.isEmpty {
                            Text(chatURL)
                                .font(.body)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .foregroundColor(.primary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 7)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(.systemGray4), lineWidth: 0.5)
                                )
                                .onTapGesture {
                                    chatURLFocused = true
                                }
                        }
                    }

                    Button {
                        if let text = UIPasteboard.general.string {
                            chatURL = text
                        }
                    } label: {
                        Image(systemName: "doc.on.clipboard")
                    }
                    .buttonStyle(.bordered)

                    Button("開く") {
                        let urlString = chatURL.isEmpty ? "https://listen.style/" : chatURL
                        if let url = URL(string: urlString), url.scheme != nil {
                            browserURL = url
                            showingBrowser = true
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            // Start/Stop button
            Button(action: {
                if viewModel.isStreaming {
                    viewModel.stopStreaming()
                } else {
                    viewModel.startStreaming()
                    // 配信開始時にチャットも自動で開く（状態変化の影響を避けるため遅延）
                    let chatURLString = chatURL.isEmpty ? "https://listen.style/" : chatURL
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        if let url = URL(string: chatURLString), url.scheme != nil {
                            browserURL = url
                            showingBrowser = true
                        }
                    }
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

            // Advanced settings
            DisclosureGroup("詳細設定") {
                VStack(spacing: 16) {
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
                }
                .padding(.top, 8)
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
        .onChange(of: showingBrowser) { isShowing in
            if !isShowing, let url = browserURL {
                chatURL = url.absoluteString
            }
        }
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

    /// 操作不能なスタック状態（配信中でも待機中でも遷移中でもない、かつURLが入力済み）
    private var isStuck: Bool {
        !viewModel.isStreaming
            && !viewModel.canStartStreaming
            && !viewModel.currentState.isTransitioning
            && viewModel.configuration.isValid
    }
}

#Preview {
    StreamControlView(viewModel: StreamViewModel(), showingBrowser: .constant(false), browserURL: .constant(nil))
}
