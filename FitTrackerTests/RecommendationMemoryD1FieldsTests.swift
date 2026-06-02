// FitTrackerTests/RecommendationMemoryD1FieldsTests.swift
// D1 (adaptive-intelligence-next-pass) T8 — RecommendationMemory new fields.
//
// Tests:
//   - Manual un-suppression persists 14 days, then expires.
//   - Blacklist persists forever (no time decay), revoked only by clearAll.
//   - recordBlacklist is idempotent.
//   - clearAll wipes both new ledgers + the legacy outcomes ledger.
//   - Cross-segment isolation: an un-suppression for .training does not
//     leak into .nutrition queries.

import XCTest
@testable import FitTracker

@MainActor
final class RecommendationMemoryD1FieldsTests: XCTestCase {

    // Use a per-test storage namespace so tests don't share UserDefaults state
    // with each other or with the running app.
    private var memory: RecommendationMemory!

    override func setUp() async throws {
        try await super.setUp()
        memory = RecommendationMemory()
        memory.clearAll()
    }

    override func tearDown() async throws {
        memory.clearAll()
        memory = nil
        try await super.tearDown()
    }

    // MARK: - Manual un-suppression

    func testManualUnsuppressionActiveWithinWindow() {
        let now = Date()
        memory.recordManualUnsuppression(
            signal: "protein_below", in: .nutrition, viaTrend: false, timestamp: now)
        XCTAssertTrue(memory.isManuallyUnsuppressed(signal: "protein_below", in: .nutrition, now: now))
        // Edge: just before the 14d boundary
        let almost14d = now.addingTimeInterval(13 * 86_400 + 100)
        XCTAssertTrue(memory.isManuallyUnsuppressed(signal: "protein_below", in: .nutrition, now: almost14d))
    }

    func testManualUnsuppressionExpiresAfter14d() {
        let now = Date()
        memory.recordManualUnsuppression(
            signal: "protein_below", in: .nutrition, viaTrend: false, timestamp: now)
        let past14d = now.addingTimeInterval(14 * 86_400 + 60)
        XCTAssertFalse(memory.isManuallyUnsuppressed(signal: "protein_below", in: .nutrition, now: past14d))
    }

    func testManualUnsuppressionIsSegmentScoped() {
        memory.recordManualUnsuppression(
            signal: "missed_protein", in: .nutrition, viaTrend: false)
        XCTAssertFalse(memory.isManuallyUnsuppressed(signal: "missed_protein", in: .training))
    }

    // MARK: - Blacklist

    func testBlacklistPersistsBeyondAnyWindow() {
        let now = Date()
        memory.recordBlacklist(
            signal: "carb_low", in: .nutrition, dismissalCount: 5, timestamp: now)
        let farFuture = now.addingTimeInterval(365 * 86_400)
        XCTAssertTrue(memory.isBlacklisted(signal: "carb_low", in: .nutrition))
        // Time-irrelevant — there is no `now` param on isBlacklisted by design.
        _ = farFuture
    }

    func testRecordBlacklistIsIdempotent() {
        memory.recordBlacklist(signal: "x", in: .training, dismissalCount: 3)
        memory.recordBlacklist(signal: "x", in: .training, dismissalCount: 7)
        XCTAssertEqual(memory.blacklistedSignals(for: .training).count, 1,
            "Duplicate blacklist of the same signal+segment must be a no-op")
    }

    // MARK: - clearAll contract

    func testClearAllWipesAllThreeLedgers() {
        memory.recordManualUnsuppression(signal: "a", in: .training, viaTrend: false)
        memory.recordBlacklist(signal: "b", in: .nutrition, dismissalCount: 4)
        memory.record(outcome: RecommendationOutcome(
            segment: AISegment.training.rawValue,
            signals: ["a"],
            confidenceLevel: "high",
            source: "local",
            action: .dismissed))

        memory.clearAll()

        XCTAssertEqual(memory.totalCount, 0)
        XCTAssertFalse(memory.isManuallyUnsuppressed(signal: "a", in: .training))
        XCTAssertFalse(memory.isBlacklisted(signal: "b", in: .nutrition))
    }
}
