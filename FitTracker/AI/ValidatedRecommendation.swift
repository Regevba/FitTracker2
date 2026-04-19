// AI/ValidatedRecommendation.swift
// Wraps an AIRecommendation with confidence scoring and goal context.
// The UI renders differently based on confidence level.

import Foundation

// MARK: - ConfidenceLevel

enum ConfidenceLevel: String, Sendable {
    case high       // ≥ 0.7 — full card, confident styling
    case medium     // 0.4 ..< 0.7 — card with "based on limited data" badge
    case low        // < 0.4 — subtle suggestion row, or suppressed

    init(score: Double) {
        switch score {
        case 0.7...: self = .high
        case 0.4..<0.7: self = .medium
        default: self = .low
        }
    }
}

// MARK: - ValidatedRecommendation

struct ValidatedRecommendation: Sendable {
    let recommendation: AIRecommendation
    let goalProfile: GoalProfile
    let dataCompleteness: Double        // 0-1: fraction of bands that were non-nil
    let sourceFreshness: Double         // 0-1: how recent the underlying data is
    let overallConfidence: ConfidenceLevel
    let evidenceChain: [String]         // source IDs of adapters that contributed

    /// Build a validated recommendation from a raw recommendation and adapter metadata.
    static func validate(
        recommendation: AIRecommendation,
        snapshot: LocalUserSnapshot,
        adapters: [any AIInputAdapter],
        goalProfile: GoalProfile
    ) -> ValidatedRecommendation {
        let segment = AISegment(rawValue: recommendation.segment) ?? .training

        // Data completeness: how many bands were available for this segment?
        let completeness = Self.computeCompleteness(segment: segment, snapshot: snapshot)

        // Source freshness: how recent is the newest adapter's data?
        let freshness = Self.computeFreshness(adapters: adapters)

        // Combined confidence: weight recommendation.confidence (0.5), completeness (0.3), freshness (0.2)
        let combinedScore = recommendation.confidence * 0.5
            + completeness * 0.3
            + freshness * 0.2

        let contributing = adapters
            .filter { $0.lastUpdated != nil }
            .map(\.sourceID)

        return ValidatedRecommendation(
            recommendation: recommendation,
            goalProfile: goalProfile,
            dataCompleteness: completeness,
            sourceFreshness: freshness,
            overallConfidence: ConfidenceLevel(score: combinedScore),
            evidenceChain: contributing
        )
    }

    // MARK: - Completeness

    private static func computeCompleteness(segment: AISegment, snapshot: LocalUserSnapshot) -> Double {
        // Use explicit Bool checks instead of fragile Any?/string-interpolation approach
        let checks: [Bool]
        switch segment {
        case .training:
            checks = [
                snapshot.ageYears != nil,
                snapshot.genderIdentity != nil,
                snapshot.bmiValue != nil,
                snapshot.activeWeeks != nil,
                snapshot.programPhase != nil,
                snapshot.trainingDaysPerWeek != nil,
                snapshot.avgSessionMinutes != nil,
                snapshot.primaryGoal != nil
            ]
        case .nutrition:
            checks = [
                snapshot.caloricBalanceDelta != nil,
                snapshot.dailyProteinGrams != nil,
                snapshot.proteinTargetGrams != nil,
                snapshot.mealsPerDay != nil,
                snapshot.dietPattern != nil
            ]
        case .recovery:
            checks = [
                snapshot.avgSleepHours != nil,
                snapshot.sleepQuality != nil,
                snapshot.restingHeartRate != nil,
                snapshot.stressLevel != nil
            ]
        case .stats:
            checks = [
                snapshot.weeklySessionCount != nil,
                snapshot.weeklyActiveMinutes != nil,
                snapshot.avgDailySteps != nil,
                snapshot.workoutConsistency != nil
            ]
        }
        let filled = checks.filter { $0 }.count
        return checks.isEmpty ? 0 : Double(filled) / Double(checks.count)
    }

    // MARK: - Freshness

    /// Audit DEEP-AI-011: average each adapter's freshness score instead of
    /// computing a single score from the newest adapter date. Previously one
    /// fresh adapter (e.g., a synced ProfileAdapter) masked stale others
    /// (e.g., a HealthKitAdapter that hadn't fetched in 48h). Now: each
    /// adapter contributes its own freshness score, and the result is the
    /// mean. Adapters with no `lastUpdated` (always-fresh sources like
    /// ProfileAdapter) are excluded so they don't pull the mean up.
    private static func computeFreshness(adapters: [any AIInputAdapter]) -> Double {
        let scores = adapters.compactMap { adapter -> Double? in
            guard let lastUpdated = adapter.lastUpdated else { return nil }
            return scoreFor(date: lastUpdated)
        }
        guard !scores.isEmpty else { return 0 }
        return scores.reduce(0, +) / Double(scores.count)
    }

    /// Bucketed freshness score (0.0 – 1.0) for a single adapter's
    /// `lastUpdated` timestamp. Same buckets as the previous implementation
    /// to preserve the absolute scale; the change is per-adapter scoring
    /// rather than per-fleet-newest scoring.
    private static func scoreFor(date: Date) -> Double {
        let ageHours = Date().timeIntervalSince(date) / 3600
        switch ageHours {
        case ..<1:   return 1.0
        case ..<6:   return 0.9
        case ..<24:  return 0.7
        case ..<72:  return 0.4
        default:     return 0.1
        }
    }
}
