// FitTrackerTests/BehavioralLearningStoreTests.swift
//
// Behavioural learning store — per-user posterior + GDPR wipe.
//
// Test inventory (per plan §Task 3):
//   1. testPosteriorWithZeroObservations_isUniform
//   2. testRecordObservation_incrementsCountForType
//   3. testUpgradeLastObservation_promotesShowToTap_andIsIdempotent
//   4. testDeleteAllUserData_wipesAllStoreKeys
//
// Each test uses a clean UserDefaults snapshot via setUp/tearDown
// removing every key the store owns. Tests are @MainActor because the
// production type is @MainActor.

import XCTest
@testable import FitTracker

@MainActor
final class BehavioralLearningStoreTests: XCTestCase {

    private let storeKeyPrefix = "ft.reminder.posterior."
    private let countKeyPrefix = "ft.reminder.obsCount."
    private let lastObsKey     = "ft.reminder.lastObservation"

    override func setUp() {
        super.setUp()
        clearAllStoreDefaults()
    }

    override func tearDown() {
        clearAllStoreDefaults()
        super.tearDown()
    }

    // MARK: - 1) zero-obs posterior is uniform

    func testPosteriorWithZeroObservations_isUniform() {
        let store = BehavioralLearningStore()
        let posterior = store.posterior(type: .nutritionGap)

        XCTAssertEqual(posterior.count, 24, "Posterior must cover all 24 hours")
        for h in 0..<24 {
            XCTAssertEqual(
                posterior[h] ?? 0,
                1.0 / 24.0,
                accuracy: 0.0001,
                "Hour \(h) must be uniform 1/24 when zero observations recorded"
            )
        }
        XCTAssertEqual(store.observationCount(type: .nutritionGap), 0)
    }

    // MARK: - 2) recordObservation increments count for the right type

    func testRecordObservation_incrementsCountForType() {
        let store = BehavioralLearningStore()

        store.recordObservation(type: .nutritionGap, hour: 16, tapped: false)
        XCTAssertEqual(store.observationCount(type: .nutritionGap), 1)

        XCTAssertEqual(
            store.observationCount(type: .trainingDay),
            0,
            "Per-type isolation: nutritionGap obs must not count toward trainingDay"
        )
    }

    // MARK: - 3) upgradeLastObservation promotes show→tap, idempotently

    func testUpgradeLastObservation_promotesShowToTap_andIsIdempotent() {
        let store = BehavioralLearningStore()

        store.recordObservation(type: .nutritionGap, hour: 16, tapped: false)
        XCTAssertEqual(store.observationCount(type: .nutritionGap), 1)

        store.upgradeLastObservation(type: .nutritionGap, tapped: true)
        let posterior1 = store.posterior(type: .nutritionGap)
        XCTAssertEqual(
            posterior1[16] ?? 0,
            1.0,
            accuracy: 0.0001,
            "Single observation upgraded to tap: bucket 16 must hold 100% of mass"
        )

        // Calling upgrade twice for the SAME observation must not double-count
        store.upgradeLastObservation(type: .nutritionGap, tapped: true)
        let posterior2 = store.posterior(type: .nutritionGap)
        XCTAssertEqual(
            posterior1,
            posterior2,
            "Idempotent upgrade — second call must not change posterior"
        )
        XCTAssertEqual(
            store.observationCount(type: .nutritionGap),
            1,
            "obsCount must remain 1; upgrade does not increment denominator"
        )
    }

    // MARK: - 4) deleteAllUserData wipes everything (GDPR Article 17)

    func testDeleteAllUserData_wipesAllStoreKeys() {
        let store = BehavioralLearningStore()

        store.recordObservation(type: .nutritionGap, hour: 16, tapped: true)
        store.upgradeLastObservation(type: .nutritionGap, tapped: true)
        XCTAssertEqual(store.observationCount(type: .nutritionGap), 1)

        store.deleteAllUserData()

        XCTAssertEqual(store.observationCount(type: .nutritionGap), 0)

        let posterior = store.posterior(type: .nutritionGap)
        for h in 0..<24 {
            XCTAssertEqual(
                posterior[h] ?? 0,
                1.0 / 24.0,
                accuracy: 0.0001,
                "After wipe, posterior must be uniform 1/24 again at hour \(h)"
            )
        }
    }

    // MARK: - 5) EncryptedDataStore.deletePersistedData wipes behavioral-learning state (Task 11)

    func testEncryptedDataStore_deletePersistedData_wipesBehavioralLearning() throws {
        // Seed observation data on the standalone store.
        let store = BehavioralLearningStore()
        store.recordObservation(type: .nutritionGap, hour: 16, tapped: true)
        XCTAssertEqual(store.observationCount(type: .nutritionGap), 1)

        // Trigger the GDPR Article 17 path through EncryptedDataStore.
        // deletePersistedData() now also wipes BehavioralLearningStore +
        // CohortPriorCache (smart-reminders-behavioral-learning Task 11).
        let dataStore = EncryptedDataStore()
        try dataStore.deletePersistedData()

        XCTAssertEqual(
            store.observationCount(type: .nutritionGap),
            0,
            "GDPR Article 17 — deletePersistedData() must wipe BehavioralLearningStore"
        )
    }

    // MARK: - Helpers

    private func clearAllStoreDefaults() {
        let defaults = UserDefaults.standard
        for type in ReminderType.allCases {
            defaults.removeObject(forKey: "\(countKeyPrefix)\(type.rawValue)")
            for h in 0..<24 {
                let suffix = String(format: "%02d", h)
                defaults.removeObject(forKey: "\(storeKeyPrefix)\(type.rawValue).h\(suffix)")
            }
        }
        defaults.removeObject(forKey: lastObsKey)
    }
}
