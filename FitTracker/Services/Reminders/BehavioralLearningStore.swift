// FitTracker/Services/Reminders/BehavioralLearningStore.swift
//
// Per-user posterior over 24 hour-of-day buckets per personalisable
// ReminderType. The Bayesian numerator/denominator state lives in
// UserDefaults under stable string keys so it survives relaunch and is
// scopeable for GDPR wipe.
//
// Storage schema:
//
//   ft.reminder.posterior.<type>.h<00..23>   Int — taps observed in that hour
//   ft.reminder.obsCount.<type>              Int — total observations for type
//   ft.reminder.lastObservation              [String: Any] — recovery slot for
//                                                            tap-after-show idempotence
//
// Recording flow:
//
//   1. willPresent fires:    recordObservation(type:, hour:, tapped: false)
//                            → obsCount++; if tapped→ taps[hour]++; cache last obs
//   2. didReceive fires:     upgradeLastObservation(type:, tapped: true)
//                            → if last obs matches and was not yet tapped,
//                              promote to a tap (taps[hour]++); idempotent
//
// Posterior:
//
//   posterior(type:) returns [hour: probability]; sums to 1.0 if obs>0,
//   uniform 1/24 if obs=0. Each bucket = taps[hour] / obsCount.
//
// GDPR Article 17 — `deleteAllUserData()` wipes every key this store
// owns. Called by EncryptedDataStore.deleteAllUserData() (Task 11).
//
// Thread isolation: @MainActor — read/write UserDefaults from the main
// actor so we don't race with notification delegate callbacks.

import Foundation

@MainActor
final class BehavioralLearningStore {

    // MARK: - Stored key prefixes

    private let storeKeyPrefix = "ft.reminder.posterior."
    private let countKeyPrefix = "ft.reminder.obsCount."
    private let lastObsKey     = "ft.reminder.lastObservation"

    // MARK: - Lifecycle

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Posterior accessor

    /// Per-hour probability distribution for `type`. Sums to 1.0.
    /// When zero observations have been recorded for the type, returns a
    /// uniform 1/24 distribution.
    ///
    /// This is the numerator-only component of the Bayesian posterior:
    /// the cohort prior + observation-count weighting are applied by the
    /// caller (`SmartTimingResolver`, PR 2).
    func posterior(type: ReminderType) -> [Int: Double] {
        let count = observationCount(type: type)
        guard count > 0 else {
            var uniform: [Int: Double] = [:]
            for h in 0..<24 { uniform[h] = 1.0 / 24.0 }
            return uniform
        }
        var dist: [Int: Double] = [:]
        for h in 0..<24 {
            let taps = defaults.integer(forKey: tapsKey(type: type, hour: h))
            dist[h] = Double(taps) / Double(count)
        }
        return dist
    }

    /// Total observations recorded for a `type`.
    func observationCount(type: ReminderType) -> Int {
        defaults.integer(forKey: "\(countKeyPrefix)\(type.rawValue)")
    }

    // MARK: - Observation recording

    /// Records a `shown` event (denominator). The first call for a given
    /// (type, hour) increments `obsCount` and — if `tapped` is true —
    /// also increments `taps[hour]` immediately.
    ///
    /// Caller pattern (from `ReminderNotificationDelegate`, Task 9):
    ///
    ///   • `willPresent` → `recordObservation(type:, hour:, tapped: false)`
    ///   • `didReceive`  → `upgradeLastObservation(type:, tapped: true)`
    ///
    /// Returns a synthetic id for the observation. Caller does not need
    /// the id today; it is provided for future per-observation tracking.
    @discardableResult
    func recordObservation(type: ReminderType, hour: Int, tapped: Bool) -> String {
        precondition((0..<24).contains(hour), "hour must be in 0..<24")
        let countKey = "\(countKeyPrefix)\(type.rawValue)"
        defaults.set(defaults.integer(forKey: countKey) + 1, forKey: countKey)
        if tapped {
            let key = tapsKey(type: type, hour: hour)
            defaults.set(defaults.integer(forKey: key) + 1, forKey: key)
        }
        defaults.set(
            ["type": type.rawValue, "hour": hour, "tapped": tapped],
            forKey: lastObsKey
        )
        return "\(type.rawValue):\(hour):\(Date().timeIntervalSince1970)"
    }

    /// Promotes the most recently recorded observation for `type` from
    /// "shown only" to "shown + tapped". Idempotent: calling twice for
    /// the same observation does NOT double-count.
    ///
    /// Returns silently when:
    ///   • `tapped` is false (this method only handles tap promotion).
    ///   • No prior observation exists in the recovery slot.
    ///   • The recovery slot's `type` does not match the requested type.
    ///   • The recovery slot is already marked tapped (idempotence guard).
    func upgradeLastObservation(type: ReminderType, tapped: Bool) {
        guard tapped else { return }
        guard let last = defaults.dictionary(forKey: lastObsKey) else { return }
        guard
            let recordedTypeRaw = last["type"] as? String,
            let recordedType    = ReminderType(rawValue: recordedTypeRaw),
            recordedType == type,
            let hour            = last["hour"] as? Int
        else { return }
        let alreadyTapped = (last["tapped"] as? Bool) ?? false
        guard !alreadyTapped else { return }

        // Promote: only the taps[hour] bucket; obsCount was already incremented
        // by the matching recordObservation call.
        let key = tapsKey(type: type, hour: hour)
        defaults.set(defaults.integer(forKey: key) + 1, forKey: key)
        defaults.set(
            ["type": type.rawValue, "hour": hour, "tapped": true],
            forKey: lastObsKey
        )
    }

    // MARK: - GDPR Article 17 — right to erasure

    /// Wipes every key this store owns. Called by
    /// `EncryptedDataStore.deleteAllUserData()` (Task 11).
    ///
    /// After this call:
    ///   • `observationCount(type:)` returns 0 for every type
    ///   • `posterior(type:)` returns the uniform 1/24 distribution
    func deleteAllUserData() {
        for type in ReminderType.allCases {
            defaults.removeObject(forKey: "\(countKeyPrefix)\(type.rawValue)")
            for h in 0..<24 {
                defaults.removeObject(forKey: tapsKey(type: type, hour: h))
            }
        }
        defaults.removeObject(forKey: lastObsKey)
    }

    // MARK: - Internal

    private func tapsKey(type: ReminderType, hour: Int) -> String {
        let suffix = String(format: "%02d", hour)
        return "\(storeKeyPrefix)\(type.rawValue).h\(suffix)"
    }
}
