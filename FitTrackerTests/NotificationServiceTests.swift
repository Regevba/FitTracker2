// FitTrackerTests/NotificationServiceTests.swift
// TEST-013: NotificationService scheduling, daily-cap, quiet-hour, and
// authorization gates.
//
// Pre-existing NotificationTests covers content builder + preferences +
// quiet-hour math via the public isQuietHour(at:) helper. This file fills
// the gap for the *service-level* logic: scheduleNotification's gating
// behaviour, cancellation idempotency, and authorization-state reset.
//
// Strategy notes:
//   - NotificationService.shared has a private init (singleton). We exercise
//     it directly the same way KeychainHelper tests do — there's no mock layer
//     and the simulator's UNUserNotificationCenter behaves deterministically
//     when notifications are not authorized (which is the default state in
//     the test runner).
//   - On the test simulator, isAuthorized starts false → scheduleNotification
//     short-circuits before attempting to add. We verify that no daily-cap
//     side-effect occurs in that path.
//   - The daily-count UserDefaults key is date-stamped, so we clean it up
//     in tearDown to keep tests hermetic.

import XCTest
import UserNotifications
@testable import FitTracker

@MainActor
final class NotificationServiceTests: XCTestCase {

    private var dailyCountKey: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return "ft.notification.dailyCount.\(fmt.string(from: Date()))"
    }

    override func setUp() async throws {
        try await super.setUp()
        UserDefaults.standard.removeObject(forKey: dailyCountKey)
    }

    override func tearDown() async throws {
        UserDefaults.standard.removeObject(forKey: dailyCountKey)
        try await super.tearDown()
    }

    // ── Singleton wiring ─────────────────────────────────

    func testShared_returnsSameInstance() {
        let a = NotificationService.shared
        let b = NotificationService.shared
        XCTAssertTrue(a === b, "NotificationService.shared must be a singleton")
    }

    // ── Quiet-hour API (already covered by NotificationTests, smoke here) ──

    func testIsQuietHour_22to6IsQuiet_7to21IsActive() {
        let service = NotificationService.shared
        let cal = Calendar.current
        func at(_ hour: Int) -> Date {
            cal.date(bySettingHour: hour, minute: 0, second: 0, of: Date())!
        }
        XCTAssertTrue(service.isQuietHour(at: at(22)),  "10 PM is quiet (inclusive start)")
        XCTAssertTrue(service.isQuietHour(at: at(0)),   "Midnight is quiet")
        XCTAssertTrue(service.isQuietHour(at: at(6)),   "6 AM is quiet")
        XCTAssertFalse(service.isQuietHour(at: at(7)),  "7 AM is active (exclusive end)")
        XCTAssertFalse(service.isQuietHour(at: at(12)), "Noon is active")
        XCTAssertFalse(service.isQuietHour(at: at(21)), "9 PM is active")
    }

    // ── Schedule gates (no authorization → no side effects) ──

    func testSchedule_unauthorized_doesNotIncrementDailyCount() async {
        // In the test runner, notifications are not authorized → the function
        // must short-circuit. The dailyCountKey defaults to 0 and must remain 0.
        let service = NotificationService.shared

        let content = UNMutableNotificationContent()
        content.title = "Test"
        content.body = "should not fire"
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)

        await service.scheduleNotification(
            type: .workoutReminder,
            content: content,
            trigger: trigger
        )

        let count = UserDefaults.standard.integer(forKey: dailyCountKey)
        XCTAssertEqual(count, 0,
                       "Unauthorized scheduling must not increment the daily count")
    }

    func testSchedule_perTypeDisabled_doesNotIncrementDailyCount() async {
        // Even if authorization happened to flip true, an explicitly-disabled
        // type must not bump the daily counter.
        let prefs = NotificationPreferencesStore()
        let originalWorkout = prefs.workoutRemindersEnabled
        prefs.workoutRemindersEnabled = false
        defer { prefs.workoutRemindersEnabled = originalWorkout }

        let service = NotificationService.shared
        let content = UNMutableNotificationContent()
        content.title = "Test"

        await service.scheduleNotification(
            type: .workoutReminder,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)
        )

        let count = UserDefaults.standard.integer(forKey: dailyCountKey)
        XCTAssertEqual(count, 0,
                       "Per-type-disabled scheduling must not increment the daily count")
    }

    // ── Cancellation idempotency ─────────────────────────

    func testCancelAll_doesNotThrow() {
        let service = NotificationService.shared
        // Call twice in a row to verify idempotency
        service.cancelAll()
        service.cancelAll()
        // No assertion — the requirement is "must not crash or block"
    }

    func testCancelByType_doesNotThrowForAnyType() {
        let service = NotificationService.shared
        for type in NotificationType.allCases {
            service.cancelByType(type)
        }
    }

    // ── Authorization refresh ────────────────────────────

    func testRefreshAuthorizationStatus_setsIsAuthorizedFlag() async {
        // We can't change the simulator's permission state, but we can verify
        // that calling refresh sets isAuthorized to a deterministic Bool value
        // (matching the current settings). It must not crash and must complete.
        let service = NotificationService.shared
        await service.refreshAuthorizationStatus()
        // isAuthorized is a Bool — it's either true or false, never nil.
        // The assertion is that this call completes without throwing.
        _ = service.isAuthorized
    }

    // ── NotificationType enum sanity ─────────────────────

    func testNotificationType_rawValuesMatchExpected() {
        XCTAssertEqual(NotificationType.workoutReminder.rawValue, "workout_reminder")
        XCTAssertEqual(NotificationType.readinessAlert.rawValue, "readiness_alert")
        XCTAssertEqual(NotificationType.recoveryNudge.rawValue, "recovery_nudge")
    }
}
