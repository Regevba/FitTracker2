// FitTracker/Services/Reminders/CohortPriorCache.swift
//
// On-device cache of the most recent `CohortPriorResponse` from the AI
// engine. The cache wraps the response in an `Envelope` carrying a
// `fetchedAt: Date`, persists the envelope as a JSON blob in UserDefaults
// under the stable key `ft.reminder.cohortPrior.json`, and exposes:
//
//   priors    The decoded response, or nil when cold / malformed.
//   isStale   True when no envelope is loaded OR the load is older than
//             `ttl` (7 days). Forces the caller to refetch via
//             `CohortPriorClient.fetchPriors()` (Task 4).
//
// Failure modes that resolve to "cold cache, force fetch":
//   • UserDefaults has no entry for the cache key (first launch).
//   • Stored data is not valid JSON (data corruption or schema change
//     between app versions).
//   • Stored envelope is older than `ttl`.
//
// None of these crash; `loadFromDefaults` swallows decode errors so the
// app can keep running while the next fetch repopulates the cache.

import Foundation

final class CohortPriorCache {

    private let defaults: UserDefaults
    private let cacheKey: String
    private let ttl: TimeInterval

    private struct Envelope: Codable {
        let response: CohortPriorResponse
        let fetchedAt: Date
    }

    private(set) var priors: CohortPriorResponse?
    private var fetchedAt: Date?

    /// - Parameters:
    ///   - defaults: UserDefaults to persist into. Default `.standard`.
    ///   - cacheKey: storage key. Default `ft.reminder.cohortPrior.json`.
    ///   - ttl: how long a stored envelope remains fresh. Default 7 days.
    init(
        defaults: UserDefaults = .standard,
        cacheKey: String = "ft.reminder.cohortPrior.json",
        ttl: TimeInterval = 7 * 24 * 60 * 60
    ) {
        self.defaults = defaults
        self.cacheKey = cacheKey
        self.ttl = ttl
        loadFromDefaults()
    }

    /// True when no envelope is loaded OR the loaded envelope is older
    /// than `ttl`. The caller (PR 2 `SmartTimingResolver`) uses this to
    /// decide whether to fetch from the AI engine before scheduling.
    var isStale: Bool {
        guard let fetched = fetchedAt else { return true }
        return Date().timeIntervalSince(fetched) > ttl
    }

    /// Persist a freshly-fetched response with a synthetic timestamp.
    /// `fetchedAt` defaults to "now"; tests override it to simulate
    /// stale envelopes without time-travel.
    func persist(_ response: CohortPriorResponse, fetchedAt: Date = Date()) {
        let envelope = Envelope(response: response, fetchedAt: fetchedAt)
        guard let data = try? JSONEncoder().encode(envelope) else { return }
        defaults.set(data, forKey: cacheKey)
        self.priors = response
        self.fetchedAt = fetchedAt
    }

    /// GDPR Article 17 — wipe the cached envelope. Called by
    /// `EncryptedDataStore.deleteAllUserData()` (Task 11).
    func deleteAllUserData() {
        defaults.removeObject(forKey: cacheKey)
        priors = nil
        fetchedAt = nil
    }

    // MARK: - Private

    private func loadFromDefaults() {
        guard let data = defaults.data(forKey: cacheKey) else { return }
        guard let envelope = try? JSONDecoder().decode(Envelope.self, from: data) else {
            // Malformed JSON — silently treat as cold cache (priors nil + isStale true).
            return
        }
        priors = envelope.response
        fetchedAt = envelope.fetchedAt
    }
}
