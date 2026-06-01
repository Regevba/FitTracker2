// Services/Reminders/ReadinessAwareTrainingTrigger.swift
//
// C2 feature: readiness-aware-training-alert (parent: smart-reminders).
//
// Pure-function decision engine. Given today's ReadinessResult + scheduled
// DayType + scheduledTrainingTime, return one of three recommendations or
// nil (no alert this session). Stateless — no Foundation Date.now() calls,
// no UserDefaults reads, no side effects. All time-sensitive inputs are
// passed in by the caller (testability + determinism).
//
// Decision rules (ordered, first-match wins):
//
//   1. Scheduled = rest day              → no alert (rest day already adapts)
//   2. Score ≥ 65 and confidence ≥ med   → .continueAsPlanned
//   3. Score ≤ 35 and any HRV/RHR flag   → .restDaySwap (recommend swap to
//                                          adjacent rest day; suggestedSwap
//                                          = nearest non-rest DayType in plan)
//   4. Score ≤ 50 OR overload flag       → .adaptEasierLoad
//   5. otherwise                          → .continueAsPlanned (defensive)
//
// The "driving component" surfaced in Why? is the component with the lowest
// normalized score (most below 70), or .composite if no single component
// dominates.
//
// SCORE THRESHOLDS are intentionally distinct from ReadinessAlertObserver's
// ≥80/≤40 score-crossing thresholds. The score-crossing path is a one-shot
// observation event; this path is a daily decision aid at the user's typical
// training time.

import Foundation

@MainActor
enum ReadinessAwareTrainingTrigger {

    /// Score floor for `.continueAsPlanned` recommendation
    static let continueThreshold = 65

    /// Score ceiling for `.restDaySwap` recommendation (and minimum-condition
    /// for adaptEasierLoad if no flag is present)
    static let restSwapThreshold = 35

    /// Score ceiling for `.adaptEasierLoad` recommendation
    static let adaptThreshold = 50

    /// Body-comp flags that, alone, push a borderline score into the
    /// adapt-or-swap recommendation buckets. BodyCompFlag's full enum is
    /// surfaced through ReadinessEngine; we treat any flag presence as a
    /// trigger here since both extant cases (hydrationWarning, visceralTrend)
    /// indicate adverse trends.
    static let adverseFlags: Set<BodyCompFlag> = [
        .hydrationWarning, .visceralTrend
    ]

    /// Evaluate today's training plan against today's readiness signals.
    /// Returns a context object if an alert should be surfaced, or nil when
    /// the user is on a rest day (no advisory needed) or input data is
    /// insufficient (low confidence with no flags).
    static func evaluate(
        readinessResult: ReadinessResult,
        scheduledDayType: DayType,
        suggestedRestSwapTarget: DayType?,
        scheduledTrainingTime: Date,
        generatedAt: Date
    ) -> ReadinessAlertContext? {

        guard scheduledDayType != .restDay else { return nil }

        let hasAdverseFlag = readinessResult.bodyCompFlags.contains(where: adverseFlags.contains)
        let driving = drivingComponent(from: readinessResult)
        let breakdown = ReadinessAlertContext.ComponentBreakdown(
            hrvScore: readinessResult.hrvScore,
            sleepScore: readinessResult.sleepScore,
            restingHRScore: readinessResult.rhrScore,
            trainingLoadScore: readinessResult.trainingLoadScore,
            bodyCompFlagCount: readinessResult.bodyCompFlags.count
        )

        let recommendation = recommend(
            score: readinessResult.overallScore,
            confidence: readinessResult.confidence,
            hasAdverseFlag: hasAdverseFlag
        )

        guard let recommendation else { return nil }

        return ReadinessAlertContext(
            recommendation: recommendation,
            readinessScore: readinessResult.overallScore,
            scheduledDayType: scheduledDayType,
            suggestedSwapDayType: recommendation == .restDaySwap ? suggestedRestSwapTarget : nil,
            drivingComponent: driving,
            componentBreakdown: breakdown,
            scheduledTrainingTime: scheduledTrainingTime,
            generatedAt: generatedAt
        )
    }

    // MARK: - Internal

    private static func recommend(
        score: Int,
        confidence: ReadinessConfidence,
        hasAdverseFlag: Bool
    ) -> ReadinessAlertRecommendation? {

        if score <= restSwapThreshold, hasAdverseFlag {
            return .restDaySwap
        }
        if score <= adaptThreshold || hasAdverseFlag {
            return .adaptEasierLoad
        }
        if score >= continueThreshold, confidence != .low {
            return .continueAsPlanned
        }
        // Borderline (50 < score < 65) with low confidence → no alert (avoid noise)
        return nil
    }

    private static func drivingComponent(
        from result: ReadinessResult
    ) -> ReadinessAlertContext.DrivingComponent {

        let candidates: [(ReadinessAlertContext.DrivingComponent, Double)] = [
            (.hrv,           result.hrvScore),
            (.sleep,         result.sleepScore),
            (.restingHR,     result.rhrScore),
            (.trainingLoad,  result.trainingLoadScore)
        ]

        let minimum = candidates.min { $0.1 < $1.1 }
        let maximum = candidates.max { $0.1 < $1.1 }

        guard let minimum, let maximum else { return .composite }

        // If the lowest component is meaningfully worse (> 15 points) than
        // the others combined, surface it as the driver. Otherwise the score
        // is composite (no single dominant factor).
        let spread = maximum.1 - minimum.1
        return spread > 15 ? minimum.0 : .composite
    }
}
