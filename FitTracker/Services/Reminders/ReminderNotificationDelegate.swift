// Services/Reminders/ReminderNotificationDelegate.swift
// UNUserNotificationCenterDelegate that bridges smart-reminder lifecycle
// (shown / tapped / dismissed) into AnalyticsService and emits a
// `.fitMeReminderTapped` notification so the SwiftUI root view can deep-link.
//
// Wired by FitTrackerApp at init (set as UNUserNotificationCenter.current().delegate).
//
// Smart-reminders behavioral-learning PR 1 (Task 9):
// In addition to logging analytics, the delegate now records observations
// on a BehavioralLearningStore (per-user posterior) and fires a fire-and-
// forget POST on a CohortPriorClient (population prior). Both are weakly
// held — the delegate participates in the recording path but does NOT own
// the lifecycle of either store/client; FitTrackerApp does (Task 10).
//
// Recording semantics (per spec §6 + plan §Task 9):
//   willPresent  →  store.recordObservation(type, hour, tapped:false)   denominator
//                   client.recordEvent(type, hour, tapped:false)        cohort signal
//   didReceive   →  if tap:    store.upgradeLastObservation(type, tapped:true)  numerator
//                              client.recordEvent(type, hour, tapped:true)
//                   if dismiss: leave observation as tapped:false (correct —
//                              denominator without numerator)
//
// Isolation: the class itself is non-isolated so it can satisfy
// UNUserNotificationCenterDelegate without Swift-6 actor warnings; calls
// into AnalyticsService + BehavioralLearningStore (both @MainActor) hop to
// the main actor explicitly.

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

    /// Optional reference to BehavioralLearningStore. Records the per-user
    /// posterior observations (denominator on willPresent, numerator on tap).
    /// Owned by FitTrackerApp; held weakly here.
    @MainActor weak var store: BehavioralLearningStore?

    /// Optional reference to CohortPriorClient. Fires a fire-and-forget POST
    /// to the AI engine on every show/tap so the population prior accumulates.
    /// Owned by FitTrackerApp; held weakly here.
    weak var cohortClient: CohortPriorClient?

    override init() {
        super.init()
    }

    /// Convenience init for tests + FitTrackerApp wiring (Task 10).
    /// All parameters are optional — passing nil leaves that surface
    /// disconnected (the existing PR #158 behavior).
    @MainActor
    init(
        analytics: AnalyticsService? = nil,
        store: BehavioralLearningStore? = nil,
        cohortClient: CohortPriorClient? = nil
    ) {
        self.analytics = analytics
        self.store = store
        self.cohortClient = cohortClient
        super.init()
    }

    @MainActor
    func setAnalytics(_ service: AnalyticsService?) {
        self.analytics = service
    }

    @MainActor
    func setStore(_ behavioralStore: BehavioralLearningStore?) {
        self.store = behavioralStore
    }

    func setCohortClient(_ client: CohortPriorClient?) {
        self.cohortClient = client
    }

    // MARK: - Test seams (also called from willPresent / didReceive)

    /// Test-only seam: directly drive the willPresent recording path
    /// without constructing a UNNotification (which has private inits).
    /// Records the denominator (`tapped: false`) on the store and
    /// fires-and-forgets a cohort event with the same payload.
    ///
    /// `@MainActor` because the store property itself is main-actor isolated.
    /// Callers that aren't on the main actor wrap their call in
    /// `Task { @MainActor in ... }` (this is what willPresent + didReceive
    /// already do).
    @MainActor
    func recordObservationFromNotification(type: ReminderType, hour: Int) {
        store?.recordObservation(type: type, hour: hour, tapped: false)
        let client = cohortClient
        Task { [client] in
            try? await client?.recordEvent(type: type, hour: hour, tapped: false)
        }
    }

    /// Test-only seam: directly drive the didReceive(tap) path.
    /// Promotes the most recent observation to a tap (numerator) on the
    /// store and emits a tapped:true cohort event.
    @MainActor
    func upgradeObservationFromTap(type: ReminderType, hour: Int) {
        store?.upgradeLastObservation(type: type, tapped: true)
        let client = cohortClient
        Task { [client] in
            try? await client?.recordEvent(type: type, hour: hour, tapped: true)
        }
    }

    // MARK: - Foreground presentation

    /// Called when a notification arrives while the app is in the foreground.
    /// We let iOS show the banner + sound (so the reminder is still visible),
    /// log a `reminder_shown` analytics event, AND record the denominator on
    /// the behavioral-learning store.
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
                let hour = Calendar.current.component(.hour, from: Date())
                recordObservationFromNotification(type: type, hour: hour)
            }
        }
        completionHandler([.banner, .sound, .list])
    }

    // MARK: - User response (tap or dismiss)

    /// Called when the user taps OR explicitly dismisses a notification.
    /// `actionIdentifier` distinguishes the two cases.
    /// On tap, we additionally upgrade the most recent observation to a tap
    /// (numerator) on the behavioral-learning store.
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
            let hour = Calendar.current.component(.hour, from: Date())
            switch actionIdentifier {
            case UNNotificationDismissActionIdentifier:
                analytics?.logReminderDismissed(type: type.rawValue)
                // No upgrade — observation stays tapped:false (denominator only)
            case UNNotificationDefaultActionIdentifier:
                analytics?.logReminderTapped(type: type.rawValue)
                upgradeObservationFromTap(type: type, hour: hour)
                Self.postDeepLinkNotification(type: type, userInfo: userInfo)
            default:
                analytics?.logReminderTapped(type: type.rawValue)
                upgradeObservationFromTap(type: type, hour: hour)
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
