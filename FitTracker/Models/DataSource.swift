// Models/DataSource.swift
// Tier-1 wearable data-source model for the Data Sources screen.
// A "data source" (Garmin, Fitbit, …) relays recovery signals into FitMe through
// Apple Health. v1 detects which signals are present per source via HKSource
// attribution — it does NOT fetch from any vendor API (that is the deferred Tier 2).
// See .claude/features/garmin-health-connection/ for the spec + scope decision.

import Foundation

/// The recovery signals FitMe's readiness engine consumes. A source is "active"
/// when at least one of these has source-attributed samples in Apple Health.
enum ReadinessSignal: String, CaseIterable, Sendable {
    case hrv
    case restingHR
    case sleep
    case vo2Max
    case steps

    /// Short label for the signal chips on a source row.
    var shortLabel: String {
        switch self {
        case .hrv:       return "HRV"
        case .restingHR: return "RHR"
        case .sleep:     return "Sleep"
        case .vo2Max:    return "VO₂"
        case .steps:     return "Steps"
        }
    }
}

/// A connectable wearable data source. Adding Whoop/Oura/Samsung later = one new case.
enum DataSource: String, CaseIterable, Identifiable, Sendable {
    case garmin
    case fitbit

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .garmin: return "Garmin"
        case .fitbit: return "Fitbit"
        }
    }

    /// SF Symbol shown in the source row's leading icon.
    var iconSystemName: String {
        switch self {
        case .garmin: return "applewatch.side.right"
        case .fitbit: return "figure.walk.motion"
        }
    }

    /// Name of the companion iOS app the user enables Apple Health sync in.
    var companionAppName: String {
        switch self {
        case .garmin: return "Garmin Connect"
        case .fitbit: return "Fitbit"
        }
    }

    /// Known Apple-Health source bundle identifiers for this vendor's app. Matched
    /// against `HKSource.bundleIdentifier`. A set (not a single string) so app-version
    /// or rebrand variants can be added without code churn.
    var bundleIdentifiers: Set<String> {
        switch self {
        case .garmin: return ["com.garmin.connect.mobile"]
        case .fitbit: return ["com.fitbit.FitbitMobile", "com.fitbit.FitbitiOS"]
        }
    }
}

/// The Tier-1 detection result for one source: which readiness signals it currently
/// relays through Apple Health, and when the newest such sample landed.
struct SourcePresence: Equatable, Sendable {
    let source: DataSource
    let signalsPresent: Set<ReadinessSignal>
    let lastSample: Date?

    /// At least one readiness signal is flowing → the source is contributing to readiness.
    var isActive: Bool { !signalsPresent.isEmpty }

    static func empty(_ source: DataSource) -> SourcePresence {
        SourcePresence(source: source, signalsPresent: [], lastSample: nil)
    }
}
