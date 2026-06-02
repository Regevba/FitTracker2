// AI/AcceptanceTrendDetector.swift
// D1 (adaptive-intelligence-next-pass) — pure helper.
// Encapsulates the D1.a time-decay + 7d acceptance-trend logic that lets the
// reinforcement loop unsuppress a previously-suppressed signal when the user
// has started accepting recommendations involving it again.
//
// 100% on-device, dependency-free. PRD-frozen constants live here as a single
// source of truth so the orchestrator + tests + future telemetry stay aligned.

import Foundation

enum AcceptanceTrendDetector {

    // MARK: - PRD-frozen constants

    /// Time-decay rate (per day). Half-life ≈ 30 days.
    /// λ = ln(2)/30 ≈ 0.0231.
    static let timeDecayLambda: Double = 0.0231

    /// Recency window for trend detection — last 7 days of outcomes.
    static let trendDetectionWindowSeconds: TimeInterval = 7 * 24 * 60 * 60

    /// Acceptance-rate floor for trend-unsuppression to fire (0..1).
    static let trendUnsuppressionAcceptanceFloor: Double = 0.50

    /// Minimum number of non-ignored outcomes in the 7d window before
    /// the trend signal is considered. Stops 1-in-1 noise.
    static let trendMinOutcomes: Int = 3

    // MARK: - Trend criterion

    /// Returns true when, in the last 7 days for `signal+segment`, the user
    /// has produced enough non-ignored outcomes (n ≥ 3) and the acceptance
    /// rate within that window meets or exceeds the 50% floor.
    ///
    /// This is the gate the orchestrator consults BEFORE applying a C5
    /// suppression downgrade — if the trend criterion fires for a touched
    /// signal, the downgrade is skipped and a 14d manual-unsuppression is
    /// auto-recorded with `viaTrend: true`.
    static func shouldUnsuppressByTrend(
        signal: String,
        segment: AISegment,
        outcomes: [RecommendationOutcome],
        now: Date = Date()
    ) -> Bool {
        let relevant = outcomes.filter {
            $0.segment == segment.rawValue
            && $0.signals.contains(signal)
            && $0.action != .ignored
            && now.timeIntervalSince($0.timestamp) <= trendDetectionWindowSeconds
            && now.timeIntervalSince($0.timestamp) >= 0
        }
        guard relevant.count >= trendMinOutcomes else { return false }
        let accepted = relevant.filter { $0.action == .accepted }.count
        let rate = Double(accepted) / Double(relevant.count)
        return rate >= trendUnsuppressionAcceptanceFloor
    }

    // MARK: - Decay-weighted acceptance rate

    /// Time-decay-weighted acceptance rate for `segment`, optionally restricted
    /// to outcomes whose `signals` contain `signal`. Older outcomes carry less
    /// weight (exponential decay with `timeDecayLambda`, capped at 1.0 for now).
    /// Returns nil when there are no qualifying outcomes (caller treats that as
    /// "no signal" rather than 0.0).
    static func decayWeightedAcceptanceRate(
        for segment: AISegment,
        signal: String? = nil,
        outcomes: [RecommendationOutcome],
        now: Date = Date()
    ) -> Double? {
        let segmentOutcomes = outcomes.filter {
            $0.segment == segment.rawValue
            && $0.action != .ignored
            && (signal == nil || $0.signals.contains(signal!))
        }
        guard !segmentOutcomes.isEmpty else { return nil }
        var weightedAccepted = 0.0
        var weightedTotal = 0.0
        for outcome in segmentOutcomes {
            let ageDays = max(0, now.timeIntervalSince(outcome.timestamp) / 86_400.0)
            let weight = exp(-timeDecayLambda * ageDays)
            weightedTotal += weight
            if outcome.action == .accepted { weightedAccepted += weight }
        }
        guard weightedTotal > 0 else { return nil }
        return weightedAccepted / weightedTotal
    }

    // MARK: - Audit helpers (analytics params)

    /// Total prior dismissals (lifetime) for `signal+segment`. Reported via the
    /// `prior_dismissal_count` analytics param when a trend-unsuppress fires.
    static func priorDismissalCount(
        signal: String,
        segment: AISegment,
        outcomes: [RecommendationOutcome]
    ) -> Int {
        outcomes.filter {
            $0.segment == segment.rawValue
            && $0.signals.contains(signal)
            && $0.action == .dismissed
        }.count
    }

    /// Days since the most recent dismissal for `signal+segment`. Returns
    /// `Int.max` when no dismissal has ever been recorded (caller can treat
    /// as "never dismissed").
    static func daysSinceLastDismiss(
        signal: String,
        segment: AISegment,
        outcomes: [RecommendationOutcome],
        now: Date = Date()
    ) -> Int {
        let mostRecent = outcomes
            .filter { $0.segment == segment.rawValue
                && $0.signals.contains(signal)
                && $0.action == .dismissed }
            .map(\.timestamp)
            .max()
        guard let mostRecent else { return Int.max }
        let days = now.timeIntervalSince(mostRecent) / 86_400.0
        return Int(max(0, days))
    }
}
