//
//  SafariBrowserView.swift
//  SRTAudioStreamer
//

import SwiftUI
import UIKit
import WebKit

struct SafariBrowserView: UIViewRepresentable {
    let url: URL
    @Binding var isPresented: Bool
    @Binding var currentURL: URL?

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented, currentURL: $currentURL)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var isPresented: Bool
        @Binding var currentURL: URL?

        init(isPresented: Binding<Bool>, currentURL: Binding<URL?>) {
            _isPresented = isPresented
            _currentURL = currentURL
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            currentURL = webView.url
        }
    }
}
