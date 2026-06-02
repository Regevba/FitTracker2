// FitTrackerTests/AcceptanceTrendDetectorTests.swift
// D1 (adaptive-intelligence-next-pass) T8 — pure-helper trend-criterion tests.

import XCTest
@testable import FitTracker

final class AcceptanceTrendDetectorTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)  // fixed clock

    private func outcome(
        action: UserAction,
        ageDays: Double,
        signals: [String] = ["sig_a"],
        segment: AISegment = .training
    ) -> RecommendationOutcome {
        RecommendationOutcome(
            segment: segment.rawValue,
            signals: signals,
            confidenceLevel: "high",
            source: "local",
            action: action,
            timestamp: now.addingTimeInterval(-ageDays * 86_400)
        )
    }

    // MARK: - shouldUnsuppressByTrend

    func testTrendFiresWhen3OutcomesAtOrAbove50PercentInLast7Days() {
        let outcomes: [RecommendationOutcome] = [
            outcome(action: .accepted,  ageDays: 1),
            outcome(action: .accepted,  ageDays: 3),
            outcome(action: .dismissed, ageDays: 5),  // 2/3 = 67% >= 50%
        ]
        XCTAssertTrue(AcceptanceTrendDetector.shouldUnsuppressByTrend(
            signal: "sig_a", segment: .training, outcomes: outcomes, now: now))
    }

    func testTrendDoesNotFireBelowMinOutcomes() {
        let outcomes: [RecommendationOutcome] = [
            outcome(action: .accepted, ageDays: 1),
            outcome(action: .accepted, ageDays: 2),  // only 2 — below trendMinOutcomes (3)
        ]
        XCTAssertFalse(AcceptanceTrendDetector.shouldUnsuppressByTrend(
            signal: "sig_a", segment: .training, outcomes: outcomes, now: now))
    }

    func testTrendDoesNotFireBelow50PercentAcceptance() {
        let outcomes: [RecommendationOutcome] = [
            outcome(action: .accepted,  ageDays: 1),
            outcome(action: .dismissed, ageDays: 2),
            outcome(action: .dismissed, ageDays: 3),  // 1/3 = 33%
        ]
        XCTAssertFalse(AcceptanceTrendDetector.shouldUnsuppressByTrend(
            signal: "sig_a", segment: .training, outcomes: outcomes, now: now))
    }

    func testTrendIgnoresOutcomesOlderThan7Days() {
        let outcomes: [RecommendationOutcome] = [
            outcome(action: .accepted, ageDays: 8),
            outcome(action: .accepted, ageDays: 9),
            outcome(action: .accepted, ageDays: 10),  // all > 7d
        ]
        XCTAssertFalse(AcceptanceTrendDetector.shouldUnsuppressByTrend(
            signal: "sig_a", segment: .training, outcomes: outcomes, now: now))
    }

    // MARK: - decayWeightedAcceptanceRate

    func testDecayWeightedFavorsRecentOutcomes() {
        let outcomes: [RecommendationOutcome] = [
            outcome(action: .accepted,  ageDays: 1),
            outcome(action: .dismissed, ageDays: 60),  // half-life 30d → ~25% weight
        ]
        let rate = AcceptanceTrendDetector.decayWeightedAcceptanceRate(
            for: .training, outcomes: outcomes, now: now) ?? 0
        XCTAssertGreaterThan(rate, 0.5,
            "Recent acceptance must outweigh old dismissal under 30d half-life")
    }

    func testDecayWeightedNilWhenAllIgnored() {
        let outcomes: [RecommendationOutcome] = [
            outcome(action: .ignored, ageDays: 1),
            outcome(action: .ignored, ageDays: 2),
        ]
        XCTAssertNil(AcceptanceTrendDetector.decayWeightedAcceptanceRate(
            for: .training, outcomes: outcomes, now: now))
    }

    // MARK: - audit helpers

    func testPriorDismissalCount() {
        let outcomes: [RecommendationOutcome] = [
            outcome(action: .dismissed, ageDays: 5),
            outcome(action: .dismissed, ageDays: 15),
            outcome(action: .accepted,  ageDays: 1),
        ]
        XCTAssertEqual(
            AcceptanceTrendDetector.priorDismissalCount(
                signal: "sig_a", segment: .training, outcomes: outcomes),
            2)
    }

    func testDaysSinceLastDismissReturnsIntMaxWhenNeverDismissed() {
        let outcomes: [RecommendationOutcome] = [
            outcome(action: .accepted, ageDays: 1),
        ]
        XCTAssertEqual(
            AcceptanceTrendDetector.daysSinceLastDismiss(
                signal: "sig_a", segment: .training, outcomes: outcomes, now: now),
            Int.max)
    }
}
