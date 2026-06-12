// AI/Adapters/GarminAdapter.swift
// Tier-1 Garmin source adapter. Conforms to AIInputAdapter to establish the
// source-attribution seam in the AI engine. In v1 this is a PRESENCE/ATTRIBUTION
// layer only — the actual biometric data already flows into the snapshot via
// HealthKitAdapter (Garmin → Apple Health → HealthKit). `contribute(to:)` is a
// deliberate no-op pass-through; the seam exists so a future Tier-2 direct
// Garmin Connect Health API integration can populate Garmin-proprietary fields
// (Body Battery, stress, training load) without restructuring the adapter chain.
//
// Scope decision: .claude/features/garmin-health-connection/ (Tier 1 only, v1).

import Foundation

struct GarminAdapter: AIInputAdapter {
    let sourceID = "garmin"

    private let presence: SourcePresence?

    /// Newest Garmin-attributed sample seen in Apple Health, if any.
    var lastUpdated: Date? { presence?.lastSample }

    /// Whether Garmin is currently relaying at least one readiness signal.
    var isActive: Bool { presence?.isActive ?? false }

    init(presence: SourcePresence?) {
        self.presence = presence
    }

    func contribute(to snapshot: inout LocalUserSnapshot) {
        // Tier 1: intentionally no-op. Garmin's biometric data reaches the snapshot
        // through HealthKitAdapter (it is already in Apple Health). This adapter's
        // job in v1 is source presence/attribution for the Data Sources UI, not data
        // contribution. The Tier-2 seam: when a direct Garmin API lands, populate
        // Garmin-only fields here (guarded on `presence`/freshness).
    }
}
