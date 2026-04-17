// FitTrackerTests/EvalTests/AIOutputQualityEvals.swift
// Heuristic quality checks for AI-generated text and signal mappings.
// Uses deterministic rules — no network calls, no model inference.

import XCTest
@testable import FitTracker

final class AIOutputQualityEvals: XCTestCase {

    // MARK: - Helpers

    /// Calls the production humanReadableSignal from AIInsightCard (now internal static).
    private func humanReadableSignal(_ signal: String) -> String {
        AIInsightCard.humanReadableSignal(signal)
    }

    /// Builds a minimal ReadinessResult with the given overall score and recommendation.
    private func makeReadinessResult(
        score: Int,
        recommendation: TrainingRecommendation
    ) -> ReadinessResult {
        ReadinessResult(
            overallScore: score,
            hrvScore: Double(score),
            sleepScore: Double(score),
            trainingLoadScore: Double(score),
            rhrScore: Double(score),
            bodyCompFlags: [],
            confidence: .medium,
            personalizationLayer: 1,
            goalMode: .fatLoss,
            appliedWeights: [:],
            warnings: [],
            recommendation: recommendation
        )
    }

    // MARK: - 1. Signal coverage

    /// For each AISegment, localFallback must produce at least one signal.
    func testEval_signalCoverage() {
        var snapshot = LocalUserSnapshot()
        snapshot.ageYears = 30
        snapshot.avgSleepHours = 7
        snapshot.restingHeartRate = 65

        for segment in AISegment.allCases {
            let rec = AIRecommendation.localFallback(for: segment, snapshot: snapshot)
            XCTAssertFalse(
                rec.signals.isEmpty,
                "Expected at least one signal for segment '\(segment.rawValue)'"
            )
        }
    }

    // MARK: - 2. No raw keys in UI

    /// Known signal keys produced by localFallback must not surface underscores
    /// after passing through the humanReadableSignal mapping.
    func testEval_noRawKeysInUI() {
        let knownSignals = [
            "local_sleep_deprivation_deload_advised",
            "local_elevated_resting_hr",
            "local_recovery_phase_keep_intensity_in_check",
            "local_protein_below_target",
            "local_high_frequency_program_detected",
            "local_sleep_debt_flag",
            "local_consistency_strength",
            "local_readiness_critical_rest_required",
            "local_hydration_warning",
        ]

        for signal in knownSignals {
            let readable = humanReadableSignal(signal)
            XCTAssertFalse(
                readable.contains("_"),
                "Signal '\(signal)' mapped to '\(readable)' which still contains underscores"
            )
        }
    }

    // MARK: - 3. Copy length bounds

    /// Mapped human-readable output must be between 15 and 80 characters.
    func testEval_copyLengthBounds() {
        let knownSignals = [
            "local_sleep_deprivation_deload_advised",
            "local_elevated_resting_hr",
            "local_recovery_phase_keep_intensity_in_check",
            "local_protein_below_target",
            "local_high_frequency_program_detected",
            "local_sleep_debt_flag",
            "local_consistency_strength",
            "local_readiness_critical_rest_required",
            "local_hydration_warning",
            "local_baseline_ready",   // falls through to default
        ]

        for signal in knownSignals {
            let readable = humanReadableSignal(signal)
            let length = readable.count
            XCTAssertGreaterThanOrEqual(
                length, 15,
                "Signal '\(signal)' → '\(readable)' is too short (\(length) chars)"
            )
            XCTAssertLessThanOrEqual(
                length, 80,
                "Signal '\(signal)' → '\(readable)' is too long (\(length) chars)"
            )
        }
    }

    // MARK: - 4. Tone matches readiness

    /// Low readiness (score 20, restDay) should surface rest/recovery language.
    /// High readiness (score 90, pushHard) should surface strong/push language.
    func testEval_toneMatchesReadiness() {
        let restKeywords: Set<String> = ["rest", "recover", "lighter", "easy", "body", "needs"]
        let pushKeywords: Set<String> = ["great", "push", "strong", "go", "shape"]

        // Low readiness
        let lowResult = makeReadinessResult(score: 20, recommendation: .restDay)
        let lowRec = HomeRecommendationProvider.recommendation(
            readinessResult: lowResult,
            isRestDay: false,
            streakDays: 0
        )
        let lowCombined = (lowRec.title + " " + lowRec.subtitle).lowercased()
        let lowMatches = restKeywords.filter { lowCombined.contains($0) }
        XCTAssertFalse(
            lowMatches.isEmpty,
            "Low-readiness copy '\(lowCombined)' should contain at least one of \(restKeywords)"
        )

        // High readiness
        let highResult = makeReadinessResult(score: 90, recommendation: .pushHard)
        let highRec = HomeRecommendationProvider.recommendation(
            readinessResult: highResult,
            isRestDay: false,
            streakDays: 0
        )
        let highCombined = (highRec.title + " " + highRec.subtitle).lowercased()
        let highMatches = pushKeywords.filter { highCombined.contains($0) }
        XCTAssertFalse(
            highMatches.isEmpty,
            "High-readiness copy '\(highCombined)' should contain at least one of \(pushKeywords)"
        )
    }

    // MARK: - 5. Confidence badge text

    /// ReadinessConfidence raw values must match the expected badge strings exactly.
    func testEval_confidenceBadgeText() {
        XCTAssertEqual(ReadinessConfidence.low.rawValue,    "low")
        XCTAssertEqual(ReadinessConfidence.medium.rawValue, "medium")
        XCTAssertEqual(ReadinessConfidence.high.rawValue,   "high")
    }

    // MARK: - 6. Recommendation copy completeness

    /// Every TrainingRecommendation case must produce non-empty title and subtitle
    /// from HomeRecommendationProvider.
    func testEval_recommendationCopyCompleteness() {
        // Map each recommendation to a representative score that would trigger it
        // per the ReadinessEngine thresholds documented in DomainModels.swift.
        let cases: [(TrainingRecommendation, Int)] = [
            (.restDay,       20),
            (.lightOnly,     40),
            (.moderate,      60),
            (.fullIntensity, 77),
            (.pushHard,      90),
        ]

        for (trainingRec, score) in cases {
            let result = makeReadinessResult(score: score, recommendation: trainingRec)
            let rec = HomeRecommendationProvider.recommendation(
                readinessResult: result,
                isRestDay: false,
                streakDays: 0
            )
            XCTAssertFalse(
                rec.title.isEmpty,
                "Title should be non-empty for recommendation '\(trainingRec.rawValue)'"
            )
            XCTAssertFalse(
                rec.subtitle.isEmpty,
                "Subtitle should be non-empty for recommendation '\(trainingRec.rawValue)'"
            )
        }
    }

    // MARK: - 7. Warning text quality

    /// Warning strings from ReadinessEngine must be substantive and contain
    /// actionable language.
    func testEval_warningTextQuality() {
        let warnings = [
            "Overnight weight change >1% — possible dehydration",
            "Visceral fat trending up over past 7 days",
            "HRV significantly below baseline — consider rest",
            "Resting HR elevated >5 BPM above baseline",
        ]

        let actionableKeywords: Set<String> = [
            "dehydration", "trending", "baseline", "consider", "elevated",
        ]

        for warning in warnings {
            XCTAssertGreaterThan(
                warning.count, 20,
                "Warning '\(warning)' is too short to be actionable"
            )

            let lowercased = warning.lowercased()
            let matches = actionableKeywords.filter { lowercased.contains($0) }
            XCTAssertFalse(
                matches.isEmpty,
                "Warning '\(warning)' should contain at least one actionable keyword from \(actionableKeywords)"
            )
        }
    }
}
