// FitTrackerTests/RecommendationMemoryWindowTests.swift
// C5 ai-user-feedback-loop T12.A — 30-day window filter on frequentlyDismissedSignals.

import XCTest
@testable import FitTracker

final class RecommendationMemoryWindowTests: XCTestCase {

    private let storageKey = "fitme.ai.recommendation_memory"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: storageKey)
        super.tearDown()
    }

    /// Dismissals within the 30-day window count toward suppression.
    func testInWindowDismissalsAreCounted() {
        let memory = RecommendationMemory()
        let nowFixed = Date(timeIntervalSince1970: 1_750_000_000)
        let recentDate = nowFixed.addingTimeInterval(-10 * 24 * 60 * 60) // 10d ago
        for _ in 0..<3 {
            memory.record(outcome: RecommendationOutcome(
                segment: AISegment.training.rawValue,
                signals: ["overreaching"],
                confidenceLevel: "high",
                source: "cloud",
                action: .dismissed,
                dismissReason: "repetitive",
                timestamp: recentDate
            ))
        }
        let suppressed = memory.frequentlyDismissedSignals(
            for: .training,
            threshold: 3,
            within: 30 * 24 * 60 * 60,
            now: nowFixed
        )
        XCTAssertEqual(suppressed, ["overreaching"], "3 in-window dismissals should suppress")
    }

    /// Dismissals outside the 30-day window are filtered out.
    func testOutOfWindowDismissalsAreIgnored() {
        let memory = RecommendationMemory()
        let nowFixed = Date(timeIntervalSince1970: 1_750_000_000)
        let oldDate = nowFixed.addingTimeInterval(-60 * 24 * 60 * 60) // 60d ago
        for _ in 0..<5 {
            memory.record(outcome: RecommendationOutcome(
                segment: AISegment.training.rawValue,
                signals: ["overreaching"],
                confidenceLevel: "high",
                source: "cloud",
                action: .dismissed,
                dismissReason: nil,
                timestamp: oldDate
            ))
        }
        let suppressed = memory.frequentlyDismissedSignals(
            for: .training,
            threshold: 3,
            within: 30 * 24 * 60 * 60,
            now: nowFixed
        )
        XCTAssertTrue(suppressed.isEmpty, "60-day-old dismissals should be filtered out of 30d window")
    }
}
