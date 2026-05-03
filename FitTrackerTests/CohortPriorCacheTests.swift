// FitTrackerTests/CohortPriorCacheTests.swift
//
// CohortPriorCache — TTL + JSON round-trip + graceful failure recovery.
//
// Test inventory (per plan §Task 5):
//   1. testColdCache_isStale
//   2. testPersistThenLoad_roundTrip       — across simulated relaunch
//   3. testStaleAfter7Days                 — 8-days-ago timestamp → stale
//   4. testMalformedJSON_recoversToCold    — invalid bytes → no crash
//
// Plus one extra:
//   5. testDeleteAllUserData_clearsCache  — GDPR Article 17

import XCTest
@testable import FitTracker

@MainActor
final class CohortPriorCacheTests: XCTestCase {

    private let cacheKey = "ft.reminder.cohortPrior.json"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: cacheKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
        super.tearDown()
    }

    // MARK: - 1) Cold cache reports stale + nil priors

    func testColdCache_isStale() {
        let cache = CohortPriorCache()
        XCTAssertTrue(cache.isStale, "Cold cache must report stale (forces fetch)")
        XCTAssertNil(cache.priors)
    }

    // MARK: - 2) Persist→load round-trip across simulated relaunch

    func testPersistThenLoad_roundTrip() {
        let cache = CohortPriorCache()
        let response = CohortPriorResponse(
            priors: ["nutrition_gap": ["16": 0.42]],
            killFlags: ["engagement"]
        )
        cache.persist(response)

        // Construct a fresh instance — simulates app relaunch reading the
        // same UserDefaults key.
        let cache2 = CohortPriorCache()
        XCTAssertFalse(cache2.isStale, "Just-persisted cache must not be stale")
        XCTAssertEqual(cache2.priors?.priors["nutrition_gap"]?["16"], 0.42)
        XCTAssertEqual(cache2.priors?.killFlags, ["engagement"])
    }

    // MARK: - 3) Envelope older than 7d is stale

    func testStaleAfter7Days() {
        let cache = CohortPriorCache()
        let response = CohortPriorResponse(priors: [:], killFlags: [])
        let eightDaysAgo = Date().addingTimeInterval(-8 * 24 * 60 * 60)
        cache.persist(response, fetchedAt: eightDaysAgo)

        let cache2 = CohortPriorCache()
        XCTAssertTrue(cache2.isStale, "Cache older than 7 days must be stale")
    }

    // MARK: - 4) Malformed JSON resolves to cold cache (no crash)

    func testMalformedJSON_recoversToCold() {
        UserDefaults.standard.set(
            "not valid json".data(using: .utf8),
            forKey: cacheKey
        )
        let cache = CohortPriorCache()
        XCTAssertTrue(cache.isStale)
        XCTAssertNil(
            cache.priors,
            "Malformed JSON must result in cold cache, not crash"
        )
    }

    // MARK: - 5) deleteAllUserData clears the cache (GDPR Article 17)

    func testDeleteAllUserData_clearsCache() {
        let cache = CohortPriorCache()
        cache.persist(CohortPriorResponse(priors: ["x": ["1": 0.5]], killFlags: []))
        XCTAssertFalse(cache.isStale)
        XCTAssertNotNil(cache.priors)

        cache.deleteAllUserData()
        XCTAssertTrue(cache.isStale)
        XCTAssertNil(cache.priors)

        // And UserDefaults entry must be gone
        XCTAssertNil(UserDefaults.standard.data(forKey: cacheKey))
    }
}
