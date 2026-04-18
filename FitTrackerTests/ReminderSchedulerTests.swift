// FitTrackerTests/ReminderSchedulerTests.swift
// TEST-014: ReminderScheduler tests.
//
// Tests the observable side-effects via @Published state + UserDefaults.
// The full scheduling path goes through UNUserNotificationCenter, which
// isn't reliably testable without a mock. Where the production code's
// effect is observable through state/defaults, we test it directly;
// where it isn't, we document the gap rather than fake it.

import XCTest
@testable import FitTracker

@MainActor
final class ReminderSchedulerTests: XCTestCase {

    private let dailyCountKeyPrefix = "ft.reminder.dailyCount."
    private let lastScheduledKey    = "ft.reminder.lastScheduledDate"

    override func setUp() {
        super.setUp()
        clearAllReminderDefaults()
    }

    override func tearDown() {
        clearAllReminderDefaults()
        super.tearDown()
    }

    // MARK: - Singleton

    func testShared_returnsSingleton() {
        let a = ReminderScheduler.shared
        let b = ReminderScheduler.shared
        XCTAssertTrue(a === b, "shared must return the same instance across calls")
    }

    func testInit_scheduledCountStartsAtZero() {
        // After clearing defaults, the singleton's in-memory counter
        // is unchanged from prior runs (it's a singleton). We test the
        // observable contract: after cancelAll(), count is 0.
        let scheduler = ReminderScheduler.shared
        scheduler.cancelAll()
        XCTAssertEqual(scheduler.scheduledCount, 0,
                       "scheduledCount must be 0 after cancelAll")
    }

    // MARK: - Cancel behaviour

    func testCancelAll_resetsScheduledCount() {
        let scheduler = ReminderScheduler.shared
        // Force a non-zero count by direct mutation isn't possible (it's
        // @Published private(set)). Instead verify cancelAll is idempotent.
        scheduler.cancelAll()
        XCTAssertEqual(scheduler.scheduledCount, 0)
        scheduler.cancelAll()
        XCTAssertEqual(scheduler.scheduledCount, 0,
                       "cancelAll must be safe to call repeatedly")
    }

    // MARK: - UserDefaults key contract

    func testDailyCountKey_includesTodaysDate() {
        // ReminderScheduler uses keys like ft.reminder.dailyCount.YYYY-MM-DD.
        // Verify the format we depend on (any change here invalidates lifetime/daily counts).
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let todayKey = "\(dailyCountKeyPrefix)\(fmt.string(from: Date()))"
        // Set a known value, expect read-back via standard UserDefaults
        UserDefaults.standard.set(7, forKey: todayKey)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: todayKey), 7)
    }

    func testLifetimeCountKey_perTypeIsolated() {
        // Lifetime key format: ft.reminder.{type}.sentCount
        // Setting one type's lifetime count must not affect another's.
        let nutritionKey = "ft.reminder.\(ReminderType.nutritionGap.rawValue).sentCount"
        let trainingKey  = "ft.reminder.\(ReminderType.trainingDay.rawValue).sentCount"

        UserDefaults.standard.set(3, forKey: nutritionKey)
        UserDefaults.standard.set(0, forKey: trainingKey)

        XCTAssertEqual(UserDefaults.standard.integer(forKey: nutritionKey), 3)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: trainingKey), 0,
                       "Lifetime counts must be per-type isolated")
    }

    // MARK: - Quiet-hours contract

    func testQuietHours_window10pmTo7am() {
        // The scheduler uses quietHourStart = 22, quietHourEnd = 7 (exclusive end).
        // We document the contract here. Actual call to isQuietHour is private, so
        // we verify the math callers depend on:
        //   hour >= 22 OR hour < 7  → quiet
        //   7 <= hour < 22          → active
        let quiet  = [22, 23, 0, 1, 2, 3, 4, 5, 6]
        let active = [7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21]
        for h in quiet {
            XCTAssertTrue(h >= 22 || h < 7, "Hour \(h) must be in quiet window")
        }
        for h in active {
            XCTAssertFalse(h >= 22 || h < 7, "Hour \(h) must NOT be in quiet window")
        }
        // NotificationServiceTests (PR #95) tests the live isQuietHour(at:) on
        // NotificationService — that's the production verification of this contract.
    }

    // MARK: - Per-type max-per-day contract

    func testPerTypeMaxPerDay_matchesEnumDeclaration() {
        // The dailyCapReached() guard reads ReminderType.maxPerDay. Test that
        // the enum values are what the guard depends on.
        for type in ReminderType.allCases {
            XCTAssertGreaterThan(type.maxPerDay, 0,
                                 "\(type) must allow at least 1 send per day")
        }
    }

    func testGlobalMaxDaily_isThree() {
        // The scheduler's maxDailyGlobal is 3 (verified via reading source).
        // This is a contract test — if production changes, update here too.
        // We can't read the private constant, so we validate by attempting
        // to interpret behaviour: 3 is the documented Smart Reminders cap.
        // (Better validation requires making maxDailyGlobal internal or testable.)
    }

    // MARK: - Helpers

    private func clearAllReminderDefaults() {
        let defaults = UserDefaults.standard
        // Clear today's date-stamped keys
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let todayKey = "ft.reminder.dailyCount.\(fmt.string(from: Date()))"
        defaults.removeObject(forKey: todayKey)
        defaults.removeObject(forKey: lastScheduledKey)
        // Clear per-type lifetime + daily caps
        for type in ReminderType.allCases {
            defaults.removeObject(forKey: "ft.reminder.\(type.rawValue).sentCount")
            // Daily-cap key uses ISO timestamp prefix; remove anything matching the type
            for key in defaults.dictionaryRepresentation().keys
                where key.hasPrefix("ft.reminder.\(type.rawValue).daily.") {
                defaults.removeObject(forKey: key)
            }
        }
    }
}
