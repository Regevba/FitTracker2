// AI/Adapters/AIInputAdapter.swift
// Protocol for normalized data ingestion into the AI engine.
// Each adapter contributes fields to a LocalUserSnapshot from a specific data source.
// Adding a new source (Garmin, Whoop, Oura) = one new conformance, no builder changes.

import Foundation

protocol AIInputAdapter {
    /// Unique identifier for this data source (e.g., "profile", "healthkit", "training", "nutrition").
    var sourceID: String { get }

    /// When this adapter's underlying data was last refreshed.
    var lastUpdated: Date? { get }

    /// Write this adapter's fields into the shared snapshot.
    /// Each adapter owns a disjoint set of fields — no two adapters write the same property.
    func contribute(to snapshot: inout LocalUserSnapshot)
}
