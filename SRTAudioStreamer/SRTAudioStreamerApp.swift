//
//  SRTAudioStreamerApp.swift
//  SRTAudioStreamer
//
//  Created by Claude Code
//

import SwiftUI
import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Register notification delegate so alerts appear even when app is in foreground
        UNUserNotificationCenter.current().delegate = NotificationManager.shared
        // Request notification permission at launch
        Task {
            await NotificationManager.shared.requestPermission()
        }
        return true
    }
}

@main
struct SRTAudioStreamerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
