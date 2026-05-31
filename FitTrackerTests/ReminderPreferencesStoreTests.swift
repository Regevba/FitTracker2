// FitTrackerTests/ReminderPreferencesStoreTests.swift
// Tests for the v2 reminder-preferences UserDefaults store + isEnabled gating.

import XCTest
@testable import FitTracker

@MainActor
final class ReminderPreferencesStoreTests: XCTestCase {

    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        // Use the standard defaults but clear our keys before each test.
        defaults = UserDefaults.standard
        for key in [
            "ft.reminder.masterEnabled",
            "ft.reminder.dailyCap",
            "ft.reminder.healthKitConnect",
            "ft.reminder.accountRegistration",
            "ft.reminder.nutritionGap",
            "ft.reminder.trainingDay",
            "ft.reminder.restDay",
            "ft.reminder.engagement",
        ] {
            defaults.removeObject(forKey: key)
        }
    }

    override func tearDown() {
        for key in [
            "ft.reminder.masterEnabled",
            "ft.reminder.dailyCap",
            "ft.reminder.healthKitConnect",
            "ft.reminder.accountRegistration",
            "ft.reminder.nutritionGap",
            "ft.reminder.trainingDay",
            "ft.reminder.restDay",
            "ft.reminder.engagement",
        ] {
            defaults.removeObject(forKey: key)
        }
        super.tearDown()
    }

    // MARK: - Defaults

    func test_defaults_areOnWithCap2() {
        let store = ReminderPreferencesStore()
        XCTAssertTrue(store.masterEnabled)
        XCTAssertEqual(store.dailyCap, 2)
        XCTAssertTrue(store.healthKitConnectEnabled)
        XCTAssertTrue(store.accountRegistrationEnabled)
        XCTAssertTrue(store.nutritionGapEnabled)
        XCTAssertTrue(store.trainingDayEnabled)
        XCTAssertTrue(store.restDayEnabled)
        XCTAssertTrue(store.engagementEnabled)
    }

    // MARK: - Persistence

    func test_setting_persistsToUserDefaults() {
        let store = ReminderPreferencesStore()
        store.trainingDayEnabled = false
        XCTAssertFalse(defaults.bool(forKey: "ft.reminder.trainingDay"))
    }

    func test_capChange_persistsToUserDefaults() {
        let store = ReminderPreferencesStore()
        store.dailyCap = 4
        XCTAssertEqual(defaults.integer(forKey: "ft.reminder.dailyCap"), 4)
    }

    func test_secondInstance_picksUpPersistedValue() {
        let first = ReminderPreferencesStore()
        first.nutritionGapEnabled = false
        first.dailyCap = 3

        let second = ReminderPreferencesStore()
        XCTAssertFalse(second.nutritionGapEnabled)
        XCTAssertEqual(second.dailyCap, 3)
    }

    // MARK: - isEnabled gating

    func test_isEnabled_returnsFalseWhenMasterOff() {
        let store = ReminderPreferencesStore()
        store.masterEnabled = false
        XCTAssertFalse(store.isEnabled(for: .trainingDay))
        XCTAssertFalse(store.isEnabled(for: .healthKitConnect))
        XCTAssertFalse(store.isEnabled(for: .engagement))
    }

    func test_isEnabled_returnsPerTypeWhenMasterOn() {
        let store = ReminderPreferencesStore()
        store.masterEnabled = true
        store.trainingDayEnabled = false
        store.restDayEnabled = true
        XCTAssertFalse(store.isEnabled(for: .trainingDay))
        XCTAssertTrue(store.isEnabled(for: .restDay))
    }

    func test_isEnabled_coversEveryReminderType() {
        let store = ReminderPreferencesStore()
        for type in ReminderType.allCases {
            // Default state: everything on. isEnabled should match.
            XCTAssertTrue(store.isEnabled(for: type), "Default ON failed for type \(type.rawValue)")
        }
    }
}
