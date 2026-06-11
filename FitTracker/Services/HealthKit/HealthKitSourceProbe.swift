// Services/HealthKit/HealthKitSourceProbe.swift
// Tier-1 source attribution: determines which readiness signals a given wearable
// (Garmin, Fitbit, …) currently relays into Apple Health, by inspecting the
// HKSource of each sample type. Read-only; rides the existing HealthKit grant
// (no new permission). HealthKitService does NOT surface HKSource, so this probe
// is the dedicated attribution layer.
//
// Testability: the probe depends on an injectable `SignalSourceQuery` closure so
// unit tests can supply deterministic, device-free fixtures. `.live` provides the
// real HealthKit-backed implementation.

import Foundation
import HealthKit

struct HealthKitSourceProbe {
    /// For a given readiness signal, return the set of Apple-Health source bundle
    /// identifiers that have samples, plus the newest sample date seen (if any).
    typealias SignalSourceQuery = (ReadinessSignal) async -> (bundleIDs: Set<String>, newest: Date?)

    private let query: SignalSourceQuery

    init(query: @escaping SignalSourceQuery) {
        self.query = query
    }

    /// Probe Apple Health for which of `source`'s known bundle IDs are present across
    /// the readiness signals, and the newest matching sample date.
    func presence(for source: DataSource) async -> SourcePresence {
        var present: Set<ReadinessSignal> = []
        var newest: Date?

        for signal in ReadinessSignal.allCases {
            let (bundleIDs, date) = await query(signal)
            guard !bundleIDs.isDisjoint(with: source.bundleIdentifiers) else { continue }
            present.insert(signal)
            if let date, newest == nil || date > newest! {
                newest = date
            }
        }

        return SourcePresence(source: source, signalsPresent: present, lastSample: newest)
    }

    /// Probe every known source in one pass.
    func presenceForAllSources() async -> [SourcePresence] {
        var results: [SourcePresence] = []
        for source in DataSource.allCases {
            results.append(await presence(for: source))
        }
        return results
    }
}

// MARK: - Live HealthKit-backed query

extension HealthKitSourceProbe {
    /// The real probe: runs an `HKSampleQuery` per signal and collects
    /// `sourceRevision.source.bundleIdentifier` + the newest start date.
    static func live(store: HKHealthStore = HKHealthStore()) -> HealthKitSourceProbe {
        HealthKitSourceProbe { signal in
            guard let sampleType = Self.sampleType(for: signal) else {
                return ([], nil)
            }
            return await withCheckedContinuation { continuation in
                let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
                // A modest limit is enough to learn *which sources* are present + the newest date.
                let q = HKSampleQuery(sampleType: sampleType,
                                      predicate: nil,
                                      limit: 50,
                                      sortDescriptors: [sort]) { _, samples, _ in
                    let samples = samples ?? []
                    let bundleIDs = Set(samples.map { $0.sourceRevision.source.bundleIdentifier })
                    let newest = samples.first?.startDate
                    continuation.resume(returning: (bundleIDs, newest))
                }
                store.execute(q)
            }
        }
    }

    /// Maps a readiness signal to its HealthKit sample type.
    static func sampleType(for signal: ReadinessSignal) -> HKSampleType? {
        switch signal {
        case .hrv:       return HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)
        case .restingHR: return HKObjectType.quantityType(forIdentifier: .restingHeartRate)
        case .vo2Max:    return HKObjectType.quantityType(forIdentifier: .vo2Max)
        case .steps:     return HKObjectType.quantityType(forIdentifier: .stepCount)
        case .sleep:     return HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
        }
    }
}
