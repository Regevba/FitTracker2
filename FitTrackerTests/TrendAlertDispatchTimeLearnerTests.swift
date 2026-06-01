// FitTrackerTests/TrendAlertDispatchTimeLearnerTests.swift
// C4 feature: trend-alerts-hrv.
//
// v1 stub returns fixed 08:00. Tests verify the constant + the combine
// helper. Future C4.c follow-on will add learn-from-history tests.

import XCTest
@testable import FitTracker

@MainActor
final class TrendAlertDispatchTimeLearnerTests: XCTestCase {

    func test_dispatchTime_returns0800() {
        let dc = TrendAlertDispatchTimeLearner.dispatchTime()
        XCTAssertEqual(dc.hour, 8)
        XCTAssertEqual(dc.minute, 0)
    }

    func test_combined_appliesWallClockTo0800OnTargetDate() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Los_Angeles") ?? .gmt

        let targetDay = cal.date(from: DateComponents(year: 2026, month: 7, day: 1))!
        let combined = TrendAlertDispatchTimeLearner.combined(on: targetDay, calendar: cal)
        let parts = cal.dateComponents([.year, .month, .day, .hour, .minute], from: combined)

        XCTAssertEqual(parts.year, 2026)
        XCTAssertEqual(parts.month, 7)
        XCTAssertEqual(parts.day, 1)
        XCTAssertEqual(parts.hour, 8)
        XCTAssertEqual(parts.minute, 0)
    }
}
