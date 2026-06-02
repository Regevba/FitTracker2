// FitTrackerTests/AIOrchestratorReinforcementHelpersTests.swift
// C5 ai-user-feedback-loop T12.D — pure-helper tier mutation behavior.
//
// Tests the static downgradeConfidence(_:) + upgradeConfidence(_:) helpers
// that AIOrchestrator's applyReinforcementLoop uses for confidence-tier-only
// adjustment per PRD frozen constants.
//
// Tier thresholds (mirror ValidatedRecommendation.ConfidenceLevel):
//   high   ≥ 0.7
//   medium 0.4..<0.7
//   low    <0.4

import XCTest
@testable import FitTracker

@MainActor
final class AIOrchestratorReinforcementHelpersTests: XCTestCase {

    // MARK: - downgradeConfidence

    func testHighConfidenceDowngradesToMedium() {
        let result = AIOrchestrator.downgradeConfidence(0.85)
        XCTAssertEqual(ConfidenceLevel(score: result), .medium)
    }

    func testMediumConfidenceDowngradesToLow() {
        let result = AIOrchestrator.downgradeConfidence(0.55)
        XCTAssertEqual(ConfidenceLevel(score: result), .low)
    }

    func testLowConfidenceStaysOrFurtherSuppressed() {
        let result = AIOrchestrator.downgradeConfidence(0.20)
        XCTAssertGreaterThanOrEqual(result, 0.0, "Confidence must not go negative")
        XCTAssertLessThan(result, 0.4, "Low stays in low band after downgrade")
    }

    // MARK: - upgradeConfidence

    func testLowConfidenceUpgradesToMedium() {
        let result = AIOrchestrator.upgradeConfidence(0.20)
        XCTAssertEqual(ConfidenceLevel(score: result), .medium)
    }

    func testMediumConfidenceUpgradesToHigh() {
        let result = AIOrchestrator.upgradeConfidence(0.55)
        XCTAssertEqual(ConfidenceLevel(score: result), .high)
    }

    func testHighConfidenceStaysHigh() {
        let result = AIOrchestrator.upgradeConfidence(0.85)
        XCTAssertEqual(ConfidenceLevel(score: result), .high)
    }

    // MARK: - Idempotency on boundary values

    func testDowngradeIsIdempotentAcrossSingleApplication() {
        // PRD: confidence-tier-only adjustment. Once we drop to mid-band, the result is in that band.
        let lowMidpoint = AIOrchestrator.downgradeConfidence(0.70) // boundary high→medium
        XCTAssertEqual(ConfidenceLevel(score: lowMidpoint), .medium)
        XCTAssertGreaterThanOrEqual(lowMidpoint, 0.4)
        XCTAssertLessThan(lowMidpoint, 0.7)
    }
}
