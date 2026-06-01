// Services/Reminders/TrendAlertTrigger.swift
//
// C4 feature: trend-alerts-hrv.
//
// Pure-function decision engine. Given the user's recent HRV samples +
// the resolved baseline + floor, return a TrendAlertContext if the
// sustained-trend pattern is present, or nil. Stateless — no Date.now()
// calls, no UserDefaults reads, no side effects.
//
// Decision rules (ordered, first-non-match short-circuits to nil):
//
//   1. samples.count == sustainedDaysRequired (default 3)
//   2. samples are all finite (no NaN or Inf)
//   3. samples.allSatisfy { $0 <= floor }
//
// If all three hold, return a context. Otherwise nil.
//
// Mirrors C2's ReadinessAwareTrainingTrigger pattern: stateless +
// fully-input-determined output for trivial unit testing.

import Foundation

@MainActor
enum TrendAlertTrigger {

    /// Default sustained-days requirement (3 per PRD).
    static let defaultSustainedDaysRequired = 3

    /// Hard floor for cold-start users (~10th percentile across population).
    static let hardFloor: Double = 25.0

    /// Evaluate the sustained-trend pattern. Returns nil if any of the
    /// required conditions fails (count mismatch, non-finite sample,
    /// at-or-above-floor sample present).
    static func evaluate(
        hrvSamples: [Double],
        baseline: Double,
        floor: Double,
        sustainedDaysRequired: Int = defaultSustainedDaysRequired,
        kind: TrendAlertKind = .hrvSustainedLow,
        generatedAt: Date
    ) -> TrendAlertContext? {

        guard hrvSamples.count == sustainedDaysRequired else { return nil }
        guard hrvSamples.allSatisfy({ $0.isFinite }) else { return nil }
        guard hrvSamples.allSatisfy({ $0 <= floor }) else { return nil }

        return TrendAlertContext(
            kind: kind,
            samples: hrvSamples,
            baseline: baseline,
            floor: floor,
            sustainedDays: sustainedDaysRequired,
            generatedAt: generatedAt
        )
    }

    /// Resolve the floor to use for a user given their personal baseline
    /// (median) + standard deviation. Returns max(baseline - 1σ, hardFloor)
    /// for Layer ≥1 users; hardFloor alone for cold-start users.
    static func resolvedFloor(baseline: Double?, oneStdDev: Double?) -> Double {
        guard let baseline, let oneStdDev, baseline.isFinite, oneStdDev.isFinite else {
            return hardFloor
        }
        return max(baseline - oneStdDev, hardFloor)
    }

    // MARK: - Baseline computation (median + population stddev)

    /// Median of a sample window. Returns nil when window is empty.
    /// Used as the user's personal HRV baseline over the lookback window.
    /// Choice of median (not mean) follows PRD §"Why personal-baseline":
    /// median resists single-day outliers (one bad night doesn't shift
    /// the baseline meaningfully).
    static func median(_ values: [Double]) -> Double? {
        let finite = values.filter { $0.isFinite }
        guard !finite.isEmpty else { return nil }
        let sorted = finite.sorted()
        let mid = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[mid - 1] + sorted[mid]) / 2.0
        }
        return sorted[mid]
    }

    /// Population standard deviation over a sample window. Returns nil
    /// when window is empty. Returns 0.0 for windows with a single
    /// sample (degenerate but well-defined). Used to compute the
    /// adaptive floor (baseline − 1σ).
    static func populationStdDev(_ values: [Double]) -> Double? {
        let finite = values.filter { $0.isFinite }
        guard !finite.isEmpty else { return nil }
        let n = Double(finite.count)
        let mean = finite.reduce(0.0, +) / n
        let variance = finite.reduce(0.0) { acc, v in acc + (v - mean) * (v - mean) } / n
        return variance.squareRoot()
    }
}
