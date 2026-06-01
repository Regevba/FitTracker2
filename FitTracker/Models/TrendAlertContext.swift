// Models/TrendAlertContext.swift
// All platform targets: iOS, iPadOS, macOS
//
// C4 feature: trend-alerts-hrv (no parent — standalone Feature).
//
// Carries the data the in-app banner + AIIntelligenceSheet "Your HRV
// Trend" section + push notification all need to render the sustained-
// trend advisory. Distinct from C2's ReadinessAlertContext (single-day
// pre-training advisory) — this one carries a window of HRV samples
// rather than a single-day readiness score.
//
// kind is future-proofed: v1 ships only .hrvSustainedLow; C4.b follow-on
// can add .sleepSustainedLow / .rhrSustainedHigh without re-Phase-1.

import Foundation

enum TrendAlertKind: String, Codable, Equatable, Sendable, CaseIterable {
    case hrvSustainedLow

    var headline: String {
        switch self {
        case .hrvSustainedLow: return "HRV trend: 3 days below baseline"
        }
    }

    var pushTitle: String {
        switch self {
        case .hrvSustainedLow: return "Your HRV trend"
        }
    }
}

struct TrendAlertContext: Equatable, Codable, Sendable {
    let kind: TrendAlertKind
    let samples: [Double]
    let baseline: Double
    let floor: Double
    let sustainedDays: Int
    let generatedAt: Date

    /// True when all three required-history conditions hold:
    ///   (1) samples.count == sustainedDays
    ///   (2) every sample ≤ floor
    ///   (3) samples is non-empty (defensive — covered by 1)
    var isValid: Bool {
        guard samples.count == sustainedDays, sustainedDays > 0 else { return false }
        return samples.allSatisfy { $0 <= floor }
    }
}
