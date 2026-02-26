//
//  ContentView.swift
//  SRTAudioStreamer
//
//  Created by Claude Code
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = StreamViewModel()
    @State private var showingBrowser = false
    @State private var browserURL: URL?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Status display
                    StreamStatusView(
                        state: viewModel.currentState,
                        bitrate: viewModel.currentBitrate,
                        audioLevel: viewModel.currentAudioLevel,
                        errorMessage: viewModel.errorMessage
                    )

                    // Control panel
                    StreamControlView(
                        viewModel: viewModel,
                        showingBrowser: $showingBrowser,
                        browserURL: $browserURL
                    )

                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text("さぁっとサウンドオンリーライブ")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Text("SRT Audio Streamer")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .overlay {
            if showingBrowser, let url = browserURL {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture { showingBrowser = false }

                    SafariBrowserView(url: url, isPresented: $showingBrowser)
                        .frame(maxWidth: .infinity)
                        .frame(height: UIScreen.main.bounds.height * 0.5)
                        .cornerRadius(12)
                        .clipped()
                        .padding(.horizontal, 16)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
