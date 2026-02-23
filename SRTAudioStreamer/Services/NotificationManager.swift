//
//  NotificationManager.swift
//  SRTAudioStreamer
//
//  Created by Claude Code
//

import UserNotifications
import os.log

/// Manages local notifications for streaming alerts
class NotificationManager: NSObject {
    static let shared = NotificationManager()

    private let logger = Logger(subsystem: "com.example.SRTAudioStreamer", category: "Notifications")

    // MARK: - Permission

    /// Requests notification permission from the user
    func requestPermission() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            logger.info("Notification permission granted: \(granted)")
        } catch {
            logger.error("Failed to request notification permission: \(error.localizedDescription)")
        }
    }

    // MARK: - Notification Senders

    /// Notifies that a streaming error occurred
    func notifyStreamingError(_ message: String) {
        send(
            identifier: "streaming-error",
            title: "配信エラー",
            body: message
        )
    }

    /// Notifies that streaming stopped unexpectedly
    func notifyUnexpectedStop() {
        send(
            identifier: "streaming-stopped",
            title: "配信が停止しました",
            body: "接続が切れました。再接続してください。"
        )
    }

    /// Notifies that 1 minute of silence has been detected during streaming
    func notifySilenceDetected() {
        send(
            identifier: "silence-detected",
            title: "1分間無音を配信中",
            body: "マイクを確認してください。音声が届いていない可能性があります。"
        )
    }

    // MARK: - Private

    private func send(identifier: String, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        // Remove any pending notification with the same identifier before adding new one
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if let error = error {
                self?.logger.error("Failed to send notification '\(identifier)': \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    /// Shows notifications even when the app is in the foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
