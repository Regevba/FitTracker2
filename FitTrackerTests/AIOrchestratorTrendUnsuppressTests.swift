// FitTrackerTests/AIOrchestratorTrendUnsuppressTests.swift
// D1 (adaptive-intelligence-next-pass) T8 — orchestrator integration tests
// for the manual / trend / blacklist override paths on the C5 reinforcement loop.
//
// Uses RecommendationMemory directly (in-process UserDefaults) to seed
// realistic outcome histories, then exercises the public API surface added
// by D1 to validate the precedence rules.

import XCTest
@testable import FitTracker

@MainActor
final class AIOrchestratorTrendUnsuppressTests: XCTestCase {

    private var memory: RecommendationMemory!

    override func setUp() async throws {
        try await super.setUp()
        memory = RecommendationMemory()
        memory.clearAll()
    }

    override func tearDown() async throws {
        memory.clearAll()
        memory = nil
        try await super.tearDown()
    }

    private func seed(
        _ action: UserAction,
        signal: String = "protein_below",
        segment: AISegment = .nutrition,
        ageDays: Double,
        now: Date
    ) {
        memory.record(outcome: RecommendationOutcome(
            segment: segment.rawValue,
            signals: [signal],
            confidenceLevel: "high",
            source: "local",
            action: action,
            timestamp: now.addingTimeInterval(-ageDays * 86_400)
        ))
    }

    // MARK: - Manual un-suppression precedence

    func testManualUnsuppressionSuppressesSuppressionWithinWindow() {
        let now = Date()
        // 3 dismissals in 30d → frequentlyDismissedSignals will list the signal
        seed(.dismissed, ageDays: 1, now: now)
        seed(.dismissed, ageDays: 2, now: now)
        seed(.dismissed, ageDays: 3, now: now)

        memory.recordManualUnsuppression(
            signal: "protein_below", in: .nutrition, viaTrend: false, timestamp: now)

        XCTAssertTrue(memory.isManuallyUnsuppressed(
            signal: "protein_below", in: .nutrition, now: now))
    }

    // MARK: - Blacklist precedence

    func testBlacklistOverridesAnyManualUnsuppression() {
        memory.recordManualUnsuppression(
            signal: "x", in: .nutrition, viaTrend: false)
        memory.recordBlacklist(
            signal: "x", in: .nutrition, dismissalCount: 3)
        XCTAssertTrue(memory.isBlacklisted(signal: "x", in: .nutrition))
    }

    // MARK: - Trend criterion (integration via AcceptanceTrendDetector)

    func testTrendUnsuppressionWiringFiresWhenCriterionMet() {
        let now = Date()
        // 3 acceptances within 7d window — should satisfy the criterion
        seed(.accepted, ageDays: 1, now: now)
        seed(.accepted, ageDays: 3, now: now)
        seed(.accepted, ageDays: 5, now: now)

        let segmentOutcomes = memory.outcomes(for: .nutrition)
        XCTAssertTrue(AcceptanceTrendDetector.shouldUnsuppressByTrend(
            signal: "protein_below",
            segment: .nutrition,
            outcomes: segmentOutcomes,
            now: now))
    }

    func testTrendUnsuppressionDoesNotFireWhenCriterionMissed() {
        let now = Date()
        // 1 dismissal, no acceptances → criterion fails
        seed(.dismissed, ageDays: 1, now: now)

        let segmentOutcomes = memory.outcomes(for: .nutrition)
        XCTAssertFalse(AcceptanceTrendDetector.shouldUnsuppressByTrend(
            signal: "protein_below",
            segment: .nutrition,
            outcomes: segmentOutcomes,
            now: now))
    }

    // MARK: - clearAll round-trip

    func testClearAllRevokesBlacklist() {
        memory.recordBlacklist(signal: "y", in: .training, dismissalCount: 4)
        XCTAssertTrue(memory.isBlacklisted(signal: "y", in: .training))
        memory.clearAll()
        XCTAssertFalse(memory.isBlacklisted(signal: "y", in: .training))
    }
}
