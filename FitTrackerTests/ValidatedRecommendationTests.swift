// FitTrackerTests/ValidatedRecommendationTests.swift
// TEST-010: ValidatedRecommendation validation logic.
//
// Covers:
//   - ConfidenceLevel banding from raw score (high / medium / low boundaries)
//   - Data completeness fraction per segment (0, partial, full)
//   - Source freshness banding by adapter age
//   - Combined confidence weighting (recommendation × 0.5 + completeness × 0.3 + freshness × 0.2)
//   - Evidence chain only includes adapters with non-nil lastUpdated
//   - Unknown segment string falls back to .training
//
// No mocks beyond a minimal AIInputAdapter test double — production code is
// pure data, no I/O.

import XCTest
@testable import FitTracker

// MARK: - Test double for AIInputAdapter

private struct TestAdapter: AIInputAdapter {
    let sourceID: String
    let lastUpdated: Date?

    func contribute(to snapshot: inout LocalUserSnapshot) {
        // No-op — completeness is computed from snapshot directly,
        // not via adapters in ValidatedRecommendation.validate.
    }
}

// MARK: - Helpers

private func recommendation(
    segment: AISegment,
    confidence: Double = 0.7,
    signals: [String] = ["test_signal"]
) -> AIRecommendation {
    AIRecommendation(
        segment: segment.rawValue,
        signals: signals,
        confidence: confidence,
        escalateToLLM: false,
        supportingData: [:]
    )
}

private func fullTrainingSnapshot() -> LocalUserSnapshot {
    var s = LocalUserSnapshot()
    s.ageYears = 30
    s.genderIdentity = "male"
    s.bmiValue = 23.0
    s.activeWeeks = 6
    s.programPhase = "build"
    s.trainingDaysPerWeek = 4
    s.avgSessionMinutes = 50
    s.primaryGoal = "muscle_gain"
    return s
}

private func fullNutritionSnapshot() -> LocalUserSnapshot {
    var s = LocalUserSnapshot()
    s.caloricBalanceDelta = -300
    s.dailyProteinGrams = 140
    s.proteinTargetGrams = 150
    s.mealsPerDay = 3
    s.dietPattern = "standard"
    return s
}

// MARK: - Tests

final class ValidatedRecommendationTests: XCTestCase {

    // ── ConfidenceLevel banding ──────────────────────────

    func testConfidenceLevel_highAtAndAbove070() {
        XCTAssertEqual(ConfidenceLevel(score: 0.7), .high)
        XCTAssertEqual(ConfidenceLevel(score: 0.85), .high)
        XCTAssertEqual(ConfidenceLevel(score: 1.0), .high)
    }

    func testConfidenceLevel_mediumBetween040And070() {
        XCTAssertEqual(ConfidenceLevel(score: 0.4), .medium)
        XCTAssertEqual(ConfidenceLevel(score: 0.55), .medium)
        XCTAssertEqual(ConfidenceLevel(score: 0.69999), .medium)
    }

    func testConfidenceLevel_lowBelow040() {
        XCTAssertEqual(ConfidenceLevel(score: 0.0), .low)
        XCTAssertEqual(ConfidenceLevel(score: 0.39999), .low)
        XCTAssertEqual(ConfidenceLevel(score: -1.0), .low)
    }

    // ── Completeness ─────────────────────────────────────

    func testValidate_emptySnapshotForTraining_completenessZero() {
        let result = ValidatedRecommendation.validate(
            recommendation: recommendation(segment: .training, confidence: 0.0),
            snapshot: LocalUserSnapshot(),
            adapters: [],
            goalProfile: .fatLoss
        )
        XCTAssertEqual(result.dataCompleteness, 0.0,
                       "Empty snapshot must yield 0/8 completeness for training segment")
    }

    func testValidate_fullTrainingSnapshot_completenessOne() {
        let result = ValidatedRecommendation.validate(
            recommendation: recommendation(segment: .training),
            snapshot: fullTrainingSnapshot(),
            adapters: [],
            goalProfile: .muscleGain
        )
        XCTAssertEqual(result.dataCompleteness, 1.0, accuracy: 0.001,
                       "Fully populated training snapshot must yield 8/8 completeness")
    }

    func testValidate_partialNutritionSnapshot_completenessFraction() {
        // 3/5 fields populated for nutrition
        var s = LocalUserSnapshot()
        s.caloricBalanceDelta = -200
        s.dailyProteinGrams = 100
        s.mealsPerDay = 3

        let result = ValidatedRecommendation.validate(
            recommendation: recommendation(segment: .nutrition),
            snapshot: s,
            adapters: [],
            goalProfile: .fatLoss
        )
        XCTAssertEqual(result.dataCompleteness, 3.0 / 5.0, accuracy: 0.001,
                       "3/5 nutrition fields → completeness 0.6")
    }

    func testValidate_fullRecoverySnapshot_completenessOne() {
        var s = LocalUserSnapshot()
        s.avgSleepHours = 7.5
        s.sleepQuality = "good"
        s.restingHeartRate = 60
        s.stressLevel = "low"

        let result = ValidatedRecommendation.validate(
            recommendation: recommendation(segment: .recovery),
            snapshot: s,
            adapters: [],
            goalProfile: .maintenance
        )
        XCTAssertEqual(result.dataCompleteness, 1.0, accuracy: 0.001)
    }

    func testValidate_fullStatsSnapshot_completenessOne() {
        var s = LocalUserSnapshot()
        s.weeklySessionCount = 4
        s.weeklyActiveMinutes = 240
        s.avgDailySteps = 9000
        s.workoutConsistency = "high"

        let result = ValidatedRecommendation.validate(
            recommendation: recommendation(segment: .stats),
            snapshot: s,
            adapters: [],
            goalProfile: .maintenance
        )
        XCTAssertEqual(result.dataCompleteness, 1.0, accuracy: 0.001)
    }

    // ── Freshness ────────────────────────────────────────

    func testValidate_noAdapters_freshnessZero() {
        let result = ValidatedRecommendation.validate(
            recommendation: recommendation(segment: .training),
            snapshot: fullTrainingSnapshot(),
            adapters: [],
            goalProfile: .muscleGain
        )
        XCTAssertEqual(result.sourceFreshness, 0.0, "No adapters → freshness 0")
    }

    func testValidate_freshAdapter_freshnessOne() {
        let recent = TestAdapter(sourceID: "test", lastUpdated: Date())
        let result = ValidatedRecommendation.validate(
            recommendation: recommendation(segment: .training),
            snapshot: fullTrainingSnapshot(),
            adapters: [recent],
            goalProfile: .muscleGain
        )
        XCTAssertEqual(result.sourceFreshness, 1.0, "Just-now adapter → freshness 1.0")
    }

    func testValidate_oldAdapter_freshnessReduced() {
        // 12 hours old → 0.7 band (< 24h)
        let twelveHoursAgo = Date().addingTimeInterval(-12 * 3600)
        let adapter = TestAdapter(sourceID: "test", lastUpdated: twelveHoursAgo)
        let result = ValidatedRecommendation.validate(
            recommendation: recommendation(segment: .training),
            snapshot: fullTrainingSnapshot(),
            adapters: [adapter],
            goalProfile: .muscleGain
        )
        XCTAssertEqual(result.sourceFreshness, 0.7, "12h-old adapter → freshness 0.7 band")
    }

    func testValidate_staleAdapter_freshnessFloor() {
        // 200 hours old → 0.1 (stale band: > 72h)
        let stale = TestAdapter(sourceID: "test", lastUpdated: Date().addingTimeInterval(-200 * 3600))
        let result = ValidatedRecommendation.validate(
            recommendation: recommendation(segment: .training),
            snapshot: fullTrainingSnapshot(),
            adapters: [stale],
            goalProfile: .muscleGain
        )
        XCTAssertEqual(result.sourceFreshness, 0.1, "200h-old adapter → stale floor 0.1")
    }

    func testValidate_picksNewestAdapterForFreshness() {
        // Mix of stale + fresh — must use the newest
        let stale = TestAdapter(sourceID: "old", lastUpdated: Date().addingTimeInterval(-200 * 3600))
        let fresh = TestAdapter(sourceID: "new", lastUpdated: Date())

        let result = ValidatedRecommendation.validate(
            recommendation: recommendation(segment: .training),
            snapshot: fullTrainingSnapshot(),
            adapters: [stale, fresh],
            goalProfile: .muscleGain
        )
        XCTAssertEqual(result.sourceFreshness, 1.0,
                       "Freshness must use the newest adapter, not the average or oldest")
    }

    // ── Combined confidence ──────────────────────────────

    func testValidate_combinedConfidence_high_whenAllStrong() {
        // recommendation 1.0 * 0.5 = 0.5
        // completeness 1.0 * 0.3 = 0.3
        // freshness 1.0 * 0.2 = 0.2
        // Total = 1.0 → high
        let recent = TestAdapter(sourceID: "fresh", lastUpdated: Date())
        let result = ValidatedRecommendation.validate(
            recommendation: recommendation(segment: .training, confidence: 1.0),
            snapshot: fullTrainingSnapshot(),
            adapters: [recent],
            goalProfile: .muscleGain
        )
        XCTAssertEqual(result.overallConfidence, .high)
    }

    func testValidate_combinedConfidence_low_whenAllWeak() {
        // recommendation 0.0 * 0.5 = 0
        // completeness 0.0 * 0.3 = 0
        // freshness 0.0 * 0.2 = 0
        // Total = 0 → low
        let result = ValidatedRecommendation.validate(
            recommendation: recommendation(segment: .training, confidence: 0.0),
            snapshot: LocalUserSnapshot(),
            adapters: [],
            goalProfile: .fatLoss
        )
        XCTAssertEqual(result.overallConfidence, .low)
    }

    func testValidate_combinedConfidence_medium_partial() {
        // recommendation 0.6 * 0.5 = 0.30
        // completeness 1.0 * 0.3 = 0.30
        // freshness 0.0 * 0.2 = 0.00 (no adapters)
        // Total = 0.60 → medium
        let result = ValidatedRecommendation.validate(
            recommendation: recommendation(segment: .training, confidence: 0.6),
            snapshot: fullTrainingSnapshot(),
            adapters: [],
            goalProfile: .muscleGain
        )
        XCTAssertEqual(result.overallConfidence, .medium)
    }

    // ── Evidence chain ───────────────────────────────────

    func testValidate_evidenceChain_excludesAdaptersWithNilLastUpdated() {
        let live = TestAdapter(sourceID: "healthkit", lastUpdated: Date())
        let inactive = TestAdapter(sourceID: "training", lastUpdated: nil)

        let result = ValidatedRecommendation.validate(
            recommendation: recommendation(segment: .training),
            snapshot: fullTrainingSnapshot(),
            adapters: [live, inactive],
            goalProfile: .muscleGain
        )
        XCTAssertEqual(result.evidenceChain, ["healthkit"],
                       "Adapters with nil lastUpdated must be excluded from evidence chain")
    }

    func testValidate_evidenceChain_preservesOrder() {
        let a = TestAdapter(sourceID: "a", lastUpdated: Date())
        let b = TestAdapter(sourceID: "b", lastUpdated: Date())
        let c = TestAdapter(sourceID: "c", lastUpdated: Date())

        let result = ValidatedRecommendation.validate(
            recommendation: recommendation(segment: .training),
            snapshot: fullTrainingSnapshot(),
            adapters: [a, b, c],
            goalProfile: .muscleGain
        )
        XCTAssertEqual(result.evidenceChain, ["a", "b", "c"])
    }

    // ── Goal profile passthrough ─────────────────────────

    func testValidate_goalProfileAttachedToResult() {
        let result = ValidatedRecommendation.validate(
            recommendation: recommendation(segment: .nutrition),
            snapshot: fullNutritionSnapshot(),
            adapters: [],
            goalProfile: .fatLoss
        )
        XCTAssertEqual(result.goalProfile.goal, .fatLoss,
                       "validate() must attach the supplied goalProfile to the result")
    }

    // ── Unknown segment fallback ─────────────────────────

    func testValidate_unknownSegmentString_fallsBackToTraining() {
        // segment string that doesn't match any AISegment.rawValue
        let bogus = AIRecommendation(
            segment: "invented_segment",
            signals: ["x"],
            confidence: 0.5,
            escalateToLLM: false,
            supportingData: [:]
        )

        // Should compute completeness as if it were .training (fallback)
        let result = ValidatedRecommendation.validate(
            recommendation: bogus,
            snapshot: fullTrainingSnapshot(),
            adapters: [],
            goalProfile: .muscleGain
        )
        XCTAssertEqual(result.dataCompleteness, 1.0, accuracy: 0.001,
                       "Unknown segment string must fall back to .training (8/8 fields)")
    }
}
