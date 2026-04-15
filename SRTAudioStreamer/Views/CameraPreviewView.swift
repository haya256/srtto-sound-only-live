//
//  CameraPreviewView.swift
//  SRTAudioStreamer
//
//  Created by Claude Code
//

import SwiftUI
import HaishinKit

/// A SwiftUI wrapper around MTHKView for displaying camera preview
struct CameraPreviewView: UIViewRepresentable {
    let view: MTHKView

    func makeUIView(context: Context) -> MTHKView {
        view
    }

    func updateUIView(_ uiView: MTHKView, context: Context) {}
}
