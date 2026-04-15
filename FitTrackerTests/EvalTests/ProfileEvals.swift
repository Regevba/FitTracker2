import XCTest
@testable import FitTracker

/// Golden I/O and quality heuristic eval tests for UserProfile, FitnessGoal,
/// ExperienceLevel, AppTab, and profile analytics event naming.
///
/// Golden I/O tests (1-5): verify the model behaves correctly across minimal,
/// full, and mutation+roundtrip scenarios.
///
/// Quality heuristic tests (6-9): verify structural invariants — event naming
/// conventions, enum completeness, human-readable raw values, and backward
/// compatibility with older JSON payloads.
final class ProfileEvals: XCTestCase {

    // MARK: - Helpers

    private func makeMinimalProfile() -> UserProfile {
        var profile = UserProfile()
        profile.name = "Test"
        profile.age = 30
        return profile
    }

    private func makeFullProfile() -> UserProfile {
        var profile = UserProfile()
        profile.name = "Regev"
        profile.age = 28
        profile.heightCm = 175.0
        profile.fitnessGoal = .loseFat
        profile.experienceLevel = .intermediate
        profile.trainingDaysPerWeek = 5
        profile.displayName = "Regev"
        profile.targetWeightMin = 65.0
        profile.targetWeightMax = 68.0
        profile.targetBFMin = 13.0
        profile.targetBFMax = 15.0
        profile.startWeightKg = 72.0
        profile.startBodyFatPct = 19.5
        return profile
    }

    // MARK: - Golden I/O

    /// Test 1 — Minimal UserProfile does not crash and optional fields are nil.
    func testEval_profileRendersWithMinimalData() throws {
        let profile = makeMinimalProfile()

        XCTAssertEqual(profile.name, "Test")
        XCTAssertEqual(profile.age, 30)
        XCTAssertNil(profile.fitnessGoal, "fitnessGoal should be nil for a minimal profile")
        XCTAssertNil(profile.experienceLevel, "experienceLevel should be nil for a minimal profile")
        XCTAssertNil(profile.trainingDaysPerWeek, "trainingDaysPerWeek should be nil for a minimal profile")

        // Codable roundtrip
        let encoder = JSONEncoder()
        let data = try encoder.encode(profile)
        XCTAssertFalse(data.isEmpty, "Encoded data must not be empty")

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(UserProfile.self, from: data)
        XCTAssertEqual(decoded.name, profile.name)
        XCTAssertEqual(decoded.age, profile.age)
        XCTAssertNil(decoded.fitnessGoal)
        XCTAssertNil(decoded.experienceLevel)
        XCTAssertNil(decoded.trainingDaysPerWeek)
    }

    /// Test 2 — Full UserProfile with every field populated is accessible and correct.
    func testEval_profileRendersWithFullData() {
        let profile = makeFullProfile()

        XCTAssertEqual(profile.name, "Regev")
        XCTAssertEqual(profile.age, 28)
        XCTAssertEqual(profile.heightCm, 175.0)
        XCTAssertEqual(profile.fitnessGoal, .loseFat)
        XCTAssertEqual(profile.experienceLevel, .intermediate)
        XCTAssertEqual(profile.trainingDaysPerWeek, 5)
        XCTAssertEqual(profile.displayName, "Regev")
        XCTAssertEqual(profile.targetWeightMin, 65.0)
        XCTAssertEqual(profile.targetWeightMax, 68.0)
        XCTAssertEqual(profile.targetBFMin, 13.0)
        XCTAssertEqual(profile.targetBFMax, 15.0)
        XCTAssertEqual(profile.startWeightKg, 72.0)
        XCTAssertEqual(profile.startBodyFatPct, 19.5)
    }

    /// Test 3 — Goal mutation persists through a JSON encode/decode roundtrip.
    func testEval_goalEditPersistsCorrectly() throws {
        var profile = UserProfile()
        profile.fitnessGoal = .loseFat

        // Mutate
        profile.fitnessGoal = .buildMuscle
        XCTAssertEqual(profile.fitnessGoal, .buildMuscle, "In-memory mutation should update immediately")

        // Roundtrip
        let encoder = JSONEncoder()
        let data = try encoder.encode(profile)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(UserProfile.self, from: data)

        XCTAssertEqual(decoded.fitnessGoal, .buildMuscle,
                       "fitnessGoal must survive a JSON encode/decode roundtrip")
    }

    /// Test 4 — FitnessGoal has exactly 4 cases with the correct human-readable raw values.
    func testEval_allFitnessGoalCasesExist() {
        let cases = FitnessGoal.allCases
        XCTAssertEqual(cases.count, 4, "FitnessGoal must have exactly 4 cases")

        for goal in cases {
            XCTAssertFalse(goal.rawValue.isEmpty, "rawValue must not be empty for \(goal)")
        }

        let rawValues = Set(cases.map(\.rawValue))
        XCTAssertTrue(rawValues.contains("Build Muscle"), "Expected rawValue 'Build Muscle'")
        XCTAssertTrue(rawValues.contains("Lose Fat"),     "Expected rawValue 'Lose Fat'")
        XCTAssertTrue(rawValues.contains("Maintain"),     "Expected rawValue 'Maintain'")
        XCTAssertTrue(rawValues.contains("General Fitness"), "Expected rawValue 'General Fitness'")
    }

    /// Test 5 — AppTab has exactly 4 items (Profile moved to hamburger menu).
    func testEval_tabBarHasFourItems() {
        let tabs = AppTab.allCases
        XCTAssertEqual(tabs.count, 4, "AppTab must have exactly 4 cases (Home, Training, Nutrition, Stats)")

        let tabNames = Set(tabs.map(\.rawValue))
        XCTAssertTrue(tabNames.contains("Home"), "Home tab must exist")
        XCTAssertTrue(tabNames.contains("Training Plan"), "Training tab must exist")
        XCTAssertTrue(tabNames.contains("Nutrition"), "Nutrition tab must exist")
        XCTAssertTrue(tabNames.contains("Stats"), "Stats tab must exist")
    }

    // MARK: - Quality Heuristics

    /// Test 6 — Every profile event constant in AnalyticsEvent uses the "profile_" prefix.
    func testEval_allProfileEventsUsePrefix() {
        // Collect all profile event string values defined in AnalyticsEvent.
        // These are the constants explicitly scoped to the Profile screen.
        let profileEvents: [String] = [
            AnalyticsEvent.profileTabViewed,
            AnalyticsEvent.profileGoalChanged,
            AnalyticsEvent.profileSettingsSectionOpened,
            AnalyticsEvent.profileReadinessTap,
            AnalyticsEvent.profileBodyCompTap,
            AnalyticsEvent.profileAvatarTap,
        ]

        XCTAssertFalse(profileEvents.isEmpty, "Profile event list must not be empty")

        for event in profileEvents {
            XCTAssertTrue(
                event.hasPrefix("profile_"),
                "Profile event '\(event)' does not start with 'profile_' — violates CLAUDE.md naming convention"
            )
        }
    }

    /// Test 7 — FitnessGoal conforms to CaseIterable, Codable, Sendable and has
    /// human-readable raw values (no underscores, more than 3 characters).
    func testEval_fitnessGoalEnumIsComplete() {
        // Conformance is checked at compile-time; the runtime assertion below
        // proves the value is usable as each protocol requires.

        // CaseIterable
        let cases = FitnessGoal.allCases
        XCTAssertFalse(cases.isEmpty, "FitnessGoal.allCases must not be empty")

        // Codable — encode and decode each case without throwing
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for goal in cases {
            let data = try? encoder.encode(goal)
            XCTAssertNotNil(data, "FitnessGoal.\(goal) must be Encodable")
            if let data {
                let decoded = try? decoder.decode(FitnessGoal.self, from: data)
                XCTAssertEqual(decoded, goal, "FitnessGoal.\(goal) must survive Codable roundtrip")
            }
        }

        // Sendable — assigning across actors is compile-time only; verify rawValues
        for goal in cases {
            let raw = goal.rawValue
            XCTAssertFalse(raw.contains("_"),
                           "FitnessGoal rawValue '\(raw)' must not contain underscores")
            XCTAssertGreaterThan(raw.count, 3,
                                 "FitnessGoal rawValue '\(raw)' must be more than 3 characters")
        }
    }

    /// Test 8 — ExperienceLevel has exactly 3 cases, each with a human-readable raw value
    /// (no underscores, more than 3 characters).
    func testEval_experienceLevelEnumIsComplete() {
        let cases = ExperienceLevel.allCases
        XCTAssertEqual(cases.count, 3, "ExperienceLevel must have exactly 3 cases")

        // CaseIterable + Codable roundtrip for every case
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for level in cases {
            let data = try? encoder.encode(level)
            XCTAssertNotNil(data, "ExperienceLevel.\(level) must be Encodable")
            if let data {
                let decoded = try? decoder.decode(ExperienceLevel.self, from: data)
                XCTAssertEqual(decoded, level, "ExperienceLevel.\(level) must survive Codable roundtrip")
            }
        }

        // Human-readable raw values
        for level in cases {
            let raw = level.rawValue
            XCTAssertFalse(raw.contains("_"),
                           "ExperienceLevel rawValue '\(raw)' must not contain underscores")
            XCTAssertGreaterThan(raw.count, 3,
                                 "ExperienceLevel rawValue '\(raw)' must be more than 3 characters")
        }
    }

    /// Test 9 — A JSON payload that omits the optional profile fields decodes without crashing,
    /// and all optional fields default to nil (backward compatibility).
    func testEval_userProfileBackwardCompatible() throws {
        // Construct a minimal JSON payload that mirrors what an older app version
        // would have written — no fitnessGoal, experienceLevel, trainingDaysPerWeek,
        // or displayName keys present.
        let legacyJSON = """
        {
            "name": "OldUser",
            "age": 35,
            "heightCm": 172.0,
            "recoveryStart": 0,
            "currentPhase": "Recovery",
            "targetWeightMin": 65.0,
            "targetWeightMax": 68.0,
            "targetBFMin": 13.0,
            "targetBFMax": 15.0,
            "startWeightKg": 70.0,
            "startBodyFatPct": 20.0,
            "mealSlotNames": ["Breakfast", "Lunch", "Dinner", "Snacks"]
        }
        """

        guard let data = legacyJSON.data(using: .utf8) else {
            XCTFail("Failed to create Data from legacy JSON string")
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        let profile = try decoder.decode(UserProfile.self, from: data)

        XCTAssertEqual(profile.name, "OldUser")
        XCTAssertEqual(profile.age, 35)
        XCTAssertNil(profile.fitnessGoal,
                     "fitnessGoal must be nil when absent from legacy JSON — backward compatibility")
        XCTAssertNil(profile.experienceLevel,
                     "experienceLevel must be nil when absent from legacy JSON — backward compatibility")
        XCTAssertNil(profile.trainingDaysPerWeek,
                     "trainingDaysPerWeek must be nil when absent from legacy JSON — backward compatibility")
        XCTAssertNil(profile.displayName,
                     "displayName must be nil when absent from legacy JSON — backward compatibility")
    }
}
