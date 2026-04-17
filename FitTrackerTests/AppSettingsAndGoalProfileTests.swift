// FitTrackerTests/AppSettingsAndGoalProfileTests.swift
// TEST-015: AppSettings defaults + UserDefaults round-trip
// TEST-017: GoalProfile.forGoal returns the correct profile for each mode

import XCTest
@testable import FitTracker

@MainActor
final class AppSettingsTests: XCTestCase {

    private let unitKey = "ft.unitSystem"
    private let appearanceKey = "ft.appearance"
    private let biometricKey = "ft.requireBiometricUnlockOnReopen"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: unitKey)
        UserDefaults.standard.removeObject(forKey: appearanceKey)
        UserDefaults.standard.removeObject(forKey: biometricKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: unitKey)
        UserDefaults.standard.removeObject(forKey: appearanceKey)
        UserDefaults.standard.removeObject(forKey: biometricKey)
        super.tearDown()
    }

    func testDefaults_freshLaunchHasExpectedValues() {
        let settings = AppSettings()
        XCTAssertEqual(settings.unitSystem, .metric, "Default unit system should be metric")
        XCTAssertEqual(settings.appearance, .system, "Default appearance should be system")
        XCTAssertFalse(settings.requireBiometricUnlockOnReopen, "Biometric unlock should be off by default")
    }

    func testUnitSystem_roundTripsThroughUserDefaults() {
        let settings = AppSettings()
        settings.unitSystem = .imperial

        // Create a fresh instance — must pick up the persisted value
        let restored = AppSettings()
        XCTAssertEqual(restored.unitSystem, .imperial)
    }

    func testAppearance_roundTripsThroughUserDefaults() {
        let settings = AppSettings()
        settings.appearance = .dark

        let restored = AppSettings()
        XCTAssertEqual(restored.appearance, .dark)
    }

    func testBiometricFlag_roundTripsThroughUserDefaults() {
        let settings = AppSettings()
        settings.requireBiometricUnlockOnReopen = true

        let restored = AppSettings()
        XCTAssertTrue(restored.requireBiometricUnlockOnReopen)
    }
}

final class GoalProfileTests: XCTestCase {

    func testForGoal_fatLossMapsToFatLossProfile() {
        let profile = GoalProfile.forGoal(.fatLoss)
        XCTAssertEqual(profile.goal, .fatLoss)
        XCTAssertFalse(profile.primaryDrivers.isEmpty)
        XCTAssertFalse(profile.secondaryDrivers.isEmpty)
    }

    func testForGoal_gainMapsToMuscleGainProfile() {
        let profile = GoalProfile.forGoal(.gain)
        XCTAssertEqual(profile.goal, .gain)
    }

    func testForGoal_maintainMapsToMaintenanceProfile() {
        let profile = GoalProfile.forGoal(.maintain)
        XCTAssertEqual(profile.goal, .maintain)
    }

    func testFatLossProfile_hasCaloricDeficitAsPrimaryDriver() {
        let profile = GoalProfile.forGoal(.fatLoss)
        let primary = profile.primaryDrivers.first { $0.metric == "caloric_balance" }
        XCTAssertNotNil(primary, "Fat loss profile must have caloric_balance as a primary driver")
        XCTAssertEqual(primary?.direction, .lower, "Fat loss caloric direction must be lower")
    }

    func testAllProfiles_haveMessagingForAllSegments() {
        // Every goal profile should have messaging for training, nutrition, recovery
        for mode in NutritionGoalMode.allCases {
            let profile = GoalProfile.forGoal(mode)
            XCTAssertNotNil(profile.messagingEmphasis[.training], "\(mode) missing training messaging")
            XCTAssertNotNil(profile.messagingEmphasis[.nutrition], "\(mode) missing nutrition messaging")
            XCTAssertNotNil(profile.messagingEmphasis[.recovery], "\(mode) missing recovery messaging")
        }
    }
}
