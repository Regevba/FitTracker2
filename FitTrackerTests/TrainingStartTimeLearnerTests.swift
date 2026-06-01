// FitTrackerTests/TrainingStartTimeLearnerTests.swift
// C2 feature: readiness-aware-training-alert (parent: smart-reminders).
//
// Pure tests on median-from-history learning + fallback behavior. All
// dates synthesized via a fixed Calendar (timeZone = America/Los_Angeles)
// to make wall-clock time comparisons deterministic across CI environments.

import XCTest
@testable import FitTracker

@MainActor
final class TrainingStartTimeLearnerTests: XCTestCase {

    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles") ?? .gmt
        return c
    }()

    // MARK: - Fallback path

    func test_emptyHistory_returnsFallback18Sharp() {
        let result = TrainingStartTimeLearner.learn(history: [], calendar: calendar)
        XCTAssertEqual(result.hour, 18)
        XCTAssertEqual(result.minute, 0)
    }

    func test_belowQuorum_returnsFallback() {
        // Only 4 entries — below quorum of 5
        let history = (0..<4).map { makeLog(hour: 7, minute: 30, dayOffset: $0) }
        let result = TrainingStartTimeLearner.learn(history: history, calendar: calendar)
        XCTAssertEqual(result.hour, 18, "Below-quorum history should fall back to 18:00")
        XCTAssertEqual(result.minute, 0)
    }

    // MARK: - Learn path

    func test_quorumOf5Identical_returnsThatTime() {
        let history = (0..<5).map { makeLog(hour: 7, minute: 30, dayOffset: $0) }
        let result = TrainingStartTimeLearner.learn(history: history, calendar: calendar)
        XCTAssertEqual(result.hour, 7)
        XCTAssertEqual(result.minute, 30)
    }

    func test_medianRobustToOutlier() {
        // 6 entries — 5 at 18:00 and 1 outlier at 09:00. Median = 18:00 still.
        var history = (0..<5).map { makeLog(hour: 18, minute: 0, dayOffset: $0) }
        history.append(makeLog(hour: 9, minute: 0, dayOffset: 5))
        let result = TrainingStartTimeLearner.learn(history: history, calendar: calendar)
        XCTAssertEqual(result.hour, 18, "Median should resist single 9am outlier")
        XCTAssertEqual(result.minute, 0)
    }

    func test_evenSpread_medianIsMiddleValue() {
        // 5 entries: 16:00, 17:00, 18:00, 19:00, 20:00 → median 18:00
        let times: [(Int, Int)] = [(16, 0), (17, 0), (18, 0), (19, 0), (20, 0)]
        let history = times.enumerated().map { idx, t in
            makeLog(hour: t.0, minute: t.1, dayOffset: idx)
        }
        let result = TrainingStartTimeLearner.learn(history: history, calendar: calendar)
        XCTAssertEqual(result.hour, 18)
    }

    // MARK: - combined(timeOfDay:on:)

    func test_combined_appliesWallClockToTargetDate() {
        let targetDay = calendar.date(from: DateComponents(year: 2026, month: 7, day: 1))!
        let timeOfDay = DateComponents(hour: 19, minute: 15)
        let combined = TrainingStartTimeLearner.combined(
            timeOfDay: timeOfDay,
            on: targetDay,
            calendar: calendar
        )
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: combined)
        XCTAssertEqual(parts.year, 2026)
        XCTAssertEqual(parts.month, 7)
        XCTAssertEqual(parts.day, 1)
        XCTAssertEqual(parts.hour, 19)
        XCTAssertEqual(parts.minute, 15)
    }

    // MARK: - Logs missing sessionStartTime are skipped

    func test_missingSessionStartTimesSkipped() {
        // Mix of 3 valid + 3 missing — below quorum after compaction
        var history = (0..<3).map { makeLog(hour: 7, minute: 30, dayOffset: $0) }
        history.append(contentsOf: (3..<6).map { makeLogMissing(dayOffset: $0) })
        let result = TrainingStartTimeLearner.learn(history: history, calendar: calendar)
        XCTAssertEqual(result.hour, 18, "Should fall back when valid entries don't meet quorum")
    }

    // MARK: - Helpers

    private func makeLog(hour: Int, minute: Int, dayOffset: Int) -> DailyLog {
        let date = calendar.date(from: DateComponents(year: 2026, month: 6, day: 1 + dayOffset))!
        let time = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date)!
        return DailyLog(
            date: date,
            phase: .stage1,
            dayType: .upperPush,
            recoveryDay: dayOffset,
            sessionStartTime: time
        )
    }

    private func makeLogMissing(dayOffset: Int) -> DailyLog {
        let date = calendar.date(from: DateComponents(year: 2026, month: 6, day: 1 + dayOffset))!
        return DailyLog(
            date: date,
            phase: .stage1,
            dayType: .upperPush,
            recoveryDay: dayOffset,
            sessionStartTime: nil
        )
    }
}
