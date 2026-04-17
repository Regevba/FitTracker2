// FitTrackerTests/RecommendationMemoryTests.swift
// Tests for RecommendationMemory (TEST-008):
// - Record/retrieve outcomes by segment
// - Acceptance rate computation with minimum sample gate
// - Frequently-dismissed signal detection
// - GDPR clearAll
// - LRU eviction (O(n) single-pass)

import XCTest
@testable import FitTracker

final class RecommendationMemoryTests: XCTestCase {

    private let uniqueKey = "fitme.ai.recommendation_memory"

    override func setUp() {
        super.setUp()
        // Clear any existing state before each test
        UserDefaults.standard.removeObject(forKey: uniqueKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: uniqueKey)
        super.tearDown()
    }

    // MARK: - Record / retrieve

    func testRecord_storesOutcomeForSegment() {
        let memory = RecommendationMemory()
        let outcome = RecommendationOutcome(
            segment: AISegment.training.rawValue,
            signals: ["local_sleep_debt"],
            confidenceLevel: "high",
            source: "cloud",
            action: .accepted
        )
        memory.record(outcome: outcome)

        let retrieved = memory.outcomes(for: .training)
        XCTAssertEqual(retrieved.count, 1)
        XCTAssertEqual(retrieved.first?.signals, ["local_sleep_debt"])
    }

    func testOutcomes_filtersBySegment() {
        let memory = RecommendationMemory()
        memory.record(outcome: outcome(segment: .training, action: .accepted))
        memory.record(outcome: outcome(segment: .nutrition, action: .accepted))
        memory.record(outcome: outcome(segment: .training, action: .dismissed))

        XCTAssertEqual(memory.outcomes(for: .training).count, 2)
        XCTAssertEqual(memory.outcomes(for: .nutrition).count, 1)
        XCTAssertEqual(memory.outcomes(for: .recovery).count, 0)
    }

    // MARK: - Acceptance rate

    func testAcceptanceRate_belowThresholdReturnsNil() {
        let memory = RecommendationMemory()
        // Record 4 — below the minimum of 5
        for _ in 0..<4 {
            memory.record(outcome: outcome(segment: .training, action: .accepted))
        }
        XCTAssertNil(memory.acceptanceRate(for: .training),
                     "Acceptance rate below minimum sample gate must return nil")
    }

    func testAcceptanceRate_computesCorrectly() {
        let memory = RecommendationMemory()
        // 3 accepted + 2 dismissed = 60% acceptance
        for _ in 0..<3 { memory.record(outcome: outcome(segment: .training, action: .accepted)) }
        for _ in 0..<2 { memory.record(outcome: outcome(segment: .training, action: .dismissed)) }

        let rate = memory.acceptanceRate(for: .training)
        XCTAssertNotNil(rate)
        XCTAssertEqual(rate ?? 0, 0.6, accuracy: 0.001)
    }

    func testAcceptanceRate_ignoresIgnored() {
        let memory = RecommendationMemory()
        // 5 accepted + 5 ignored — ignored should be excluded from denominator
        for _ in 0..<5 { memory.record(outcome: outcome(segment: .training, action: .accepted)) }
        for _ in 0..<5 { memory.record(outcome: outcome(segment: .training, action: .ignored)) }

        XCTAssertEqual(memory.acceptanceRate(for: .training) ?? 0, 1.0, accuracy: 0.001,
                       "Ignored outcomes must be excluded from acceptance rate denominator")
    }

    // MARK: - Frequently dismissed signals

    func testFrequentlyDismissedSignals_returnsSignalsAboveThreshold() {
        let memory = RecommendationMemory()
        // Dismiss "low_sleep" 3 times, "low_protein" once
        memory.record(outcome: outcome(segment: .nutrition, action: .dismissed, signals: ["low_sleep"]))
        memory.record(outcome: outcome(segment: .nutrition, action: .dismissed, signals: ["low_sleep"]))
        memory.record(outcome: outcome(segment: .nutrition, action: .dismissed, signals: ["low_sleep", "low_protein"]))

        let frequent = memory.frequentlyDismissedSignals(for: .nutrition, threshold: 3)
        XCTAssertTrue(frequent.contains("low_sleep"))
        XCTAssertFalse(frequent.contains("low_protein"))
    }

    // MARK: - GDPR clearAll

    func testClearAll_removesAllOutcomes() {
        let memory = RecommendationMemory()
        memory.record(outcome: outcome(segment: .training, action: .accepted))
        memory.record(outcome: outcome(segment: .nutrition, action: .dismissed))

        XCTAssertEqual(memory.totalCount, 2)
        memory.clearAll()
        XCTAssertEqual(memory.totalCount, 0)
        XCTAssertTrue(memory.outcomes(for: .training).isEmpty)
    }

    // MARK: - LRU eviction

    func testEnforceLimit_evictsOldestWhenExceeded() {
        // Fill one segment past the limit and verify the oldest are evicted
        let memory = RecommendationMemory()
        let limit = 200

        for i in 0..<(limit + 5) {
            let o = RecommendationOutcome(
                segment: AISegment.training.rawValue,
                signals: ["signal_\(i)"],
                confidenceLevel: "high",
                source: "cloud",
                action: .accepted
            )
            memory.record(outcome: o)
        }

        XCTAssertEqual(memory.outcomes(for: .training).count, limit,
                       "Segment count must be capped at maxEntriesPerSegment")
        // The last 5 (most recent) should be retained; signal_0..signal_4 evicted
        let signals = memory.outcomes(for: .training).flatMap(\.signals)
        XCTAssertFalse(signals.contains("signal_0"), "Oldest outcome must be evicted")
        XCTAssertTrue(signals.contains("signal_\(limit + 4)"), "Newest outcome must be retained")
    }

    func testEnforceLimit_isolatesSegments() {
        let memory = RecommendationMemory()
        // Fill training past limit, nutrition untouched
        for i in 0..<210 {
            memory.record(outcome: outcome(segment: .training, action: .accepted, signals: ["t_\(i)"]))
        }
        memory.record(outcome: outcome(segment: .nutrition, action: .accepted, signals: ["n_0"]))

        XCTAssertEqual(memory.outcomes(for: .training).count, 200)
        XCTAssertEqual(memory.outcomes(for: .nutrition).count, 1,
                       "Eviction in one segment must not touch other segments")
    }

    // MARK: - Helpers

    private func outcome(
        segment: AISegment,
        action: UserAction,
        signals: [String] = ["test_signal"]
    ) -> RecommendationOutcome {
        RecommendationOutcome(
            segment: segment.rawValue,
            signals: signals,
            confidenceLevel: "high",
            source: "cloud",
            action: action
        )
    }
}
