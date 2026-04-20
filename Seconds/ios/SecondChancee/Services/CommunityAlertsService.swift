import Foundation
import UserNotifications

struct CommunityReplyNotificationPayload: Sendable {
    let id: String
    let username: String
    let preview: String
    let createdAt: Date?
}

enum CommunityAlertsService {
    /// Call when the user enables community alerts in Settings.
    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// Delivers a local notification for the newest unseen community reply (when alerts are enabled and permission granted).
    static func notifyIfNeeded(
        communityAlertsEnabled: Bool,
        lastSeenAt: Date?,
        replies: [CommunityReplyNotificationPayload]
    ) async {
        guard communityAlertsEnabled else { return }
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

        let unseen = replies.filter { item in
            guard let created = item.createdAt else { return false }
            guard let lastSeen = lastSeenAt else { return true }
            return created > lastSeen
        }
        guard let first = unseen.first else { return }

        let content = UNMutableNotificationContent()
        content.title = "New reply on your post"
        content.body = "\(first.username) replied: \(first.preview)"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        let request = UNNotificationRequest(
            identifier: "community-reply-\(first.id)",
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }
}
