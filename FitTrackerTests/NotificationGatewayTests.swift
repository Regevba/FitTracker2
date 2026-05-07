// FitTrackerTests/NotificationGatewayTests.swift
// T13 — push-notifications-v2 unit tests. NotificationGateway is the platform's
// auth + dispatch + cap-audit core. Tests cover the cap state machine + quiet
// hours; the actual UNUserNotificationCenter dispatch path requires the
// requestAuthorization round-trip and isn't reliably testable without a system
// mock, so we cover what's observable through state + UserDefaults.

import XCTest
@testable import FitTracker

@MainActor
final class NotificationGatewayTests: XCTestCase {

    private let standardKeyPrefix = "ft.notification.gateway.standardCount."
    private let criticalKeyPrefix = "ft.notification.gateway.criticalCount."

    override func setUp() {
        super.setUp()
        clearAllGatewayDefaults()
        NotificationGateway.shared._resetCountsForTesting()
    }

    override func tearDown() {
        clearAllGatewayDefaults()
        NotificationGateway.shared._resetCountsForTesting()
        super.tearDown()
    }

    // MARK: T13/G-1 — Quiet-hours boundary

    /// 22:00 inclusive — quiet hour begins
    func testQuietHourAt22Inclusive() {
        let date = makeDate(hour: 22)
        XCTAssertTrue(NotificationGateway.shared.isQuietHour(at: date),
                      "22:00 must be a quiet hour (inclusive lower bound)")
    }

    /// 07:00 exclusive — quiet hour ends
    func testQuietHourAt07Exclusive() {
        let date = makeDate(hour: 7)
        XCTAssertFalse(NotificationGateway.shared.isQuietHour(at: date),
                       "07:00 must NOT be a quiet hour (exclusive upper bound)")
    }

    /// 12:00 — clearly outside quiet hours
    func testNoonIsNotQuietHour() {
        let date = makeDate(hour: 12)
        XCTAssertFalse(NotificationGateway.shared.isQuietHour(at: date))
    }

    /// 03:00 — clearly inside quiet hours
    func test3amIsQuietHour() {
        let date = makeDate(hour: 3)
        XCTAssertTrue(NotificationGateway.shared.isQuietHour(at: date))
    }

    // MARK: T13/G-2 — Cap counters

    /// Standard count starts at 0 and reads from today's UserDefaults key
    func testStandardCountDefaultsToZero() {
        XCTAssertEqual(NotificationGateway.shared.standardCount(), 0,
                       "Fresh setUp should leave standard count at 0")
    }

    /// Critical count is independent of standard count (separate bucket)
    func testCriticalCountIndependentOfStandard() {
        // Manually bump standard count via UserDefaults
        let key = standardKeyPrefix + todayString()
        UserDefaults.standard.set(3, forKey: key)
        XCTAssertEqual(NotificationGateway.shared.standardCount(), 3)
        XCTAssertEqual(NotificationGateway.shared.criticalCount(), 0,
                       "Critical bucket is independent")
    }

    /// Counts are day-keyed — different dates have different counts
    func testCountsAreDayKeyed() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        UserDefaults.standard.set(99, forKey: standardKeyPrefix + dateString(yesterday))
        XCTAssertEqual(NotificationGateway.shared.standardCount(at: yesterday), 99)
        XCTAssertEqual(NotificationGateway.shared.standardCount(), 0,
                       "Today's count is independent of yesterday's")
    }

    // MARK: T13/G-3 — Helpers

    private func makeDate(hour: Int) -> Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = hour
        comps.minute = 0
        return Calendar.current.date(from: comps)!
    }

    private func todayString(date: Date = Date()) -> String {
        dateString(date)
    }

    private func dateString(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: date)
    }

    private func clearAllGatewayDefaults() {
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys
        where key.hasPrefix(standardKeyPrefix) || key.hasPrefix(criticalKeyPrefix) {
            defaults.removeObject(forKey: key)
        }
    }
}
