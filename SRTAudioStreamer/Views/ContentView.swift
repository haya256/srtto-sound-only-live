//
//  ContentView.swift
//  SRTAudioStreamer
//
//  Created by Claude Code
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = StreamViewModel()

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
                    StreamControlView(viewModel: viewModel)

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
    }
}

#Preview {
    ContentView()
}
