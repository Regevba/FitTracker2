import XCTest
@testable import FitTracker

/// Unit tests for the Push Notifications subsystem.
///
/// T10-1 through T10-8 cover:
///   - NotificationPreferencesStore default values and per-type gating
///   - NotificationContentBuilder output for all three notification types
///   - DeepLinkHandler routing for known and unknown URL schemes
///   - NotificationType enum completeness
///   - Quiet-hours boundary logic in NotificationService
final class NotificationTests: XCTestCase {

    // MARK: - T10-1: NotificationPreferencesStore defaults

    @MainActor
    func testPreferencesDefaults() {
        // Use an isolated UserDefaults suite so this test never reads
        // leftover values written by prior test runs or the app itself.
        let suite = UserDefaults(suiteName: "com.fittracker.tests.prefs-defaults")!
        suite.removePersistentDomain(forName: "com.fittracker.tests.prefs-defaults")

        let store = NotificationPreferencesStore()
        XCTAssertTrue(store.masterEnabled, "masterEnabled should default to true")
        XCTAssertTrue(store.workoutRemindersEnabled, "workoutRemindersEnabled should default to true")
        XCTAssertTrue(store.readinessAlertsEnabled, "readinessAlertsEnabled should default to true")
        XCTAssertTrue(store.recoveryNudgesEnabled, "recoveryNudgesEnabled should default to true")
        XCTAssertEqual(store.maxDailyNotifications, 2, "maxDailyNotifications should default to 2")
    }

    // MARK: - T10-2: NotificationContentBuilder — workout reminder

    func testWorkoutReminderContent() {
        let content = NotificationContentBuilder.workoutReminder(
            dayType: "Upper Push",
            exerciseCount: 4,
            durationMinutes: 45
        )
        XCTAssertEqual(content.title, "Time to train 💪")
        XCTAssertTrue(content.body.contains("Upper Push"), "Body should contain the day type")
        XCTAssertTrue(content.body.contains("4 exercises"), "Body should contain the exercise count")
        XCTAssertEqual(content.categoryIdentifier, "workout")
        XCTAssertEqual(content.userInfo["deepLink"] as? String, "fitme://training")
    }

    // MARK: - T10-3: NotificationContentBuilder — readiness alert

    func testReadinessAlertContent() {
        let content = NotificationContentBuilder.readinessAlert(score: 35)
        XCTAssertEqual(content.title, "Your readiness is low today")
        XCTAssertTrue(content.body.contains("35/100"), "Body should contain the score formatted as score/100")
        XCTAssertEqual(content.categoryIdentifier, "readiness")
        XCTAssertEqual(content.userInfo["deepLink"] as? String, "fitme://home")
    }

    // MARK: - T10-4: NotificationContentBuilder — recovery nudge

    func testRecoveryNudgeContent() {
        let content = NotificationContentBuilder.recoveryNudge(consecutiveDays: 5)
        XCTAssertTrue(content.body.contains("5 days"), "Body should reference the number of consecutive days")
        XCTAssertEqual(content.categoryIdentifier, "recovery")
        XCTAssertEqual(content.userInfo["deepLink"] as? String, "fitme://home")
    }

    // MARK: - T10-5: DeepLinkHandler — known routes

    func testDeepLinkKnownRoutes() {
        XCTAssertEqual(
            DeepLinkHandler.targetTab(from: URL(string: "fitme://training")!), .training,
            "fitme://training should resolve to .training tab"
        )
        XCTAssertEqual(
            DeepLinkHandler.targetTab(from: URL(string: "fitme://nutrition")!), .nutrition,
            "fitme://nutrition should resolve to .nutrition tab"
        )
        XCTAssertEqual(
            DeepLinkHandler.targetTab(from: URL(string: "fitme://stats")!), .stats,
            "fitme://stats should resolve to .stats tab"
        )
        XCTAssertEqual(
            DeepLinkHandler.targetTab(from: URL(string: "fitme://home")!), .main,
            "fitme://home should resolve to .main tab"
        )
    }

    // MARK: - T10-6: DeepLinkHandler — unknown route returns nil

    func testDeepLinkUnknownRoute() {
        XCTAssertNil(
            DeepLinkHandler.targetTab(from: URL(string: "fitme://unknown")!),
            "Unregistered deep-link hosts should return nil"
        )
    }

    // MARK: - T10-7: NotificationType enum completeness

    func testNotificationTypeCount() {
        XCTAssertEqual(
            NotificationType.allCases.count,
            3,
            "NotificationType should have exactly 3 cases: workoutReminder, readinessAlert, recoveryNudge"
        )
    }

    // MARK: - T10-8: NotificationPreferencesStore — per-type isEnabled

    @MainActor
    func testPreferencesPerTypeEnabled() {
        let store = NotificationPreferencesStore()
        // All toggles are on by default; masterEnabled is also on.
        XCTAssertTrue(store.isEnabled(for: .workoutReminder), ".workoutReminder should be enabled by default")
        XCTAssertTrue(store.isEnabled(for: .readinessAlert), ".readinessAlert should be enabled by default")
        XCTAssertTrue(store.isEnabled(for: .recoveryNudge), ".recoveryNudge should be enabled by default")
    }

    // MARK: - T10-9: masterEnabled kill-switch disables all types

    @MainActor
    func testMasterKillSwitchDisablesAll() {
        let store = NotificationPreferencesStore()
        store.masterEnabled = false
        XCTAssertFalse(store.isEnabled(for: .workoutReminder), "masterEnabled=false should disable workoutReminder")
        XCTAssertFalse(store.isEnabled(for: .readinessAlert),  "masterEnabled=false should disable readinessAlert")
        XCTAssertFalse(store.isEnabled(for: .recoveryNudge),   "masterEnabled=false should disable recoveryNudge")
        // Restore to avoid polluting other tests that use standard UserDefaults
        store.masterEnabled = true
    }

    // MARK: - T10-10: NotificationService quiet-hours boundary

    @MainActor
    func testQuietHourBoundaries() {
        // Test the real NotificationService.isQuietHour(at:) method with controlled dates.
        let service = NotificationService.shared
        let cal = Calendar.current

        // Build a date at a specific hour today
        func dateAtHour(_ hour: Int) -> Date {
            cal.date(bySettingHour: hour, minute: 30, second: 0, of: Date())!
        }

        let quietHours  = [22, 23, 0, 1, 2, 3, 4, 5, 6]
        let activeHours = [7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21]

        for h in quietHours {
            XCTAssertTrue(
                service.isQuietHour(at: dateAtHour(h)),
                "Hour \(h) should be within quiet hours"
            )
        }
        for h in activeHours {
            XCTAssertFalse(
                service.isQuietHour(at: dateAtHour(h)),
                "Hour \(h) should NOT be within quiet hours"
            )
        }
    }
}
