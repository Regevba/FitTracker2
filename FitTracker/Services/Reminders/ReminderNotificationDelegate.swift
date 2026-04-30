// Services/Reminders/ReminderNotificationDelegate.swift
// UNUserNotificationCenterDelegate that bridges smart-reminder lifecycle
// (shown / tapped / dismissed) into AnalyticsService and emits a
// `.fitMeReminderTapped` notification so the SwiftUI root view can deep-link.
//
// Wired by FitTrackerApp at init (set as UNUserNotificationCenter.current().delegate).
//
// Isolation: the class itself is non-isolated so it can satisfy
// UNUserNotificationCenterDelegate without Swift-6 actor warnings; calls
// into AnalyticsService (a @MainActor type) hop to the main actor explicitly.

import Foundation
import UserNotifications

extension Notification.Name {
    /// Posted when the user taps a smart-reminder notification. The userInfo
    /// dictionary carries `type` (ReminderType.rawValue) and `deepLink` (String).
    static let fitMeReminderTapped = Notification.Name("fitme.reminder.tapped")
}

final class ReminderNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    /// Optional reference to AnalyticsService. The delegate logs events when
    /// set; when nil (e.g. test harness with no analytics), it routes
    /// notifications without logging.
    @MainActor weak var analytics: AnalyticsService?

    override init() {
        super.init()
    }

    @MainActor
    func setAnalytics(_ service: AnalyticsService?) {
        self.analytics = service
    }

    // MARK: - Foreground presentation

    /// Called when a notification arrives while the app is in the foreground.
    /// We let iOS show the banner + sound (so the reminder is still visible)
    /// and log a `reminder_shown` analytics event.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping @Sendable (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        let typeRaw = userInfo["type"] as? String

        Task { @MainActor in
            if let raw = typeRaw, let type = ReminderType(rawValue: raw) {
                analytics?.logReminderShown(type: type.rawValue)
            }
        }
        completionHandler([.banner, .sound, .list])
    }

    // MARK: - User response (tap or dismiss)

    /// Called when the user taps OR explicitly dismisses a notification.
    /// `actionIdentifier` distinguishes the two cases.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping @Sendable () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let actionIdentifier = response.actionIdentifier
        let typeRaw = userInfo["type"] as? String

        Task { @MainActor in
            guard let raw = typeRaw, let type = ReminderType(rawValue: raw) else {
                completionHandler()
                return
            }
            switch actionIdentifier {
            case UNNotificationDismissActionIdentifier:
                analytics?.logReminderDismissed(type: type.rawValue)
            case UNNotificationDefaultActionIdentifier:
                analytics?.logReminderTapped(type: type.rawValue)
                Self.postDeepLinkNotification(type: type, userInfo: userInfo)
            default:
                analytics?.logReminderTapped(type: type.rawValue)
                Self.postDeepLinkNotification(type: type, userInfo: userInfo)
            }
            completionHandler()
        }
    }

    // MARK: - Helpers

    /// Post a `.fitMeReminderTapped` Notification so a SwiftUI observer can
    /// switch tabs / present sheets in response to a reminder tap.
    static func postDeepLinkNotification(type: ReminderType, userInfo: [AnyHashable: Any]) {
        var payload: [AnyHashable: Any] = [
            "type": type.rawValue,
            "deepLink": type.deepLink,
        ]
        if let extra = userInfo["payload"] {
            payload["payload"] = extra
        }
        NotificationCenter.default.post(
            name: .fitMeReminderTapped,
            object: nil,
            userInfo: payload
        )
    }
}
