// FitTrackerTests/CustomProgramMigrationTests.swift
// C6 training-program-customization T14.D — resolver paths (nil / custom / invalid).

import XCTest
@testable import FitTracker

final class CustomProgramMigrationTests: XCTestCase {

    // MARK: - Fixture catalog (small, deterministic)

    private let catalog: [ExerciseDefinition] = [
        ExerciseDefinition(
            id: "fix_chest", name: "Fixture Chest Press",
            category: .machine, equipment: .machine,
            muscleGroups: [.chest], targetSets: 3, targetReps: "8-12",
            restSeconds: 90, coachingCue: "test", dayType: .upperPush, order: 1
        ),
        ExerciseDefinition(
            id: "fix_squat", name: "Fixture Squat",
            category: .freeWeight, equipment: .barbell,
            muscleGroups: [.quads], targetSets: 4, targetReps: "5",
            restSeconds: 120, coachingCue: "test", dayType: .lowerBody, order: 1
        ),
    ]

    // MARK: - Active program nil → fixed PPL fallback

    func testNilActiveProgramIDReturnsFixedPPLFallback() {
        var preferences = UserPreferences()
        preferences.activeProgramID = nil
        preferences.customPrograms = []

        let result = CustomProgramMigration.currentProgramDays(for: preferences, catalog: catalog)

        // Fixed PPL has 7 days
        XCTAssertEqual(result.count, 7)
        // The fallback uses the real catalog when injected catalog doesn't
        // match the fixed PPL exerciseIDs; in that case slots are empty.
        // (Test fixture catalog doesn't contain the canonical PPL exercise
        // IDs; the resolver silently drops missing IDs.)
    }

    func testInvalidActiveProgramIDFallsBackSafely() {
        var preferences = UserPreferences()
        preferences.activeProgramID = UUID()  // random ID — no matching program
        preferences.customPrograms = []

        let result = CustomProgramMigration.currentProgramDays(for: preferences, catalog: catalog)

        // Should fall back to fixed PPL safely; 7 days
        XCTAssertEqual(result.count, 7)
    }

    // MARK: - Custom program resolution

    func testCustomProgramResolvesToCustomDays() {
        let customDay = CustomDay(
            name: "Test Push",
            dayType: .upperPush,
            weekdayIndex: 1,
            slots: [
                ExerciseSlot(exerciseID: "fix_chest", order: 0),
            ]
        )
        let program = CustomProgram(name: "Test Program", days: [customDay])

        var preferences = UserPreferences()
        preferences.customPrograms = [program]
        preferences.activeProgramID = program.id

        let result = CustomProgramMigration.currentProgramDays(for: preferences, catalog: catalog)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.name, "Test Push")
        XCTAssertEqual(result.first?.exercises.count, 1)
        XCTAssertEqual(result.first?.exercises.first?.id, "fix_chest")
    }

    // MARK: - Override application

    func testOverridesAppliedToCustomSlot() {
        let customDay = CustomDay(
            name: "Test Push",
            dayType: .upperPush,
            weekdayIndex: 1,
            slots: [
                ExerciseSlot(
                    exerciseID: "fix_chest",
                    targetSetsOverride: 5,
                    targetRepsOverride: "12-15",
                    restSecondsOverride: 60,
                    order: 0
                ),
            ]
        )
        let program = CustomProgram(name: "Override Program", days: [customDay])

        var preferences = UserPreferences()
        preferences.customPrograms = [program]
        preferences.activeProgramID = program.id

        let result = CustomProgramMigration.currentProgramDays(for: preferences, catalog: catalog)
        let exercise = result.first?.exercises.first

        XCTAssertEqual(exercise?.targetSets, 5)          // overridden
        XCTAssertEqual(exercise?.targetReps, "12-15")    // overridden
        XCTAssertEqual(exercise?.restSeconds, 60)        // overridden
        XCTAssertEqual(exercise?.id, "fix_chest")        // catalog identity preserved
    }

    // MARK: - Convenience methods

    func testHasActiveCustomProgramReturnsTrueOnlyForValidActive() {
        let program = CustomProgram(name: "X", days: [])

        var withActive = UserPreferences()
        withActive.customPrograms = [program]
        withActive.activeProgramID = program.id
        XCTAssertTrue(CustomProgramMigration.hasActiveCustomProgram(withActive))

        var noActive = UserPreferences()
        noActive.customPrograms = [program]
        noActive.activeProgramID = nil
        XCTAssertFalse(CustomProgramMigration.hasActiveCustomProgram(noActive))

        var invalidActive = UserPreferences()
        invalidActive.customPrograms = [program]
        invalidActive.activeProgramID = UUID()  // doesn't match
        XCTAssertFalse(CustomProgramMigration.hasActiveCustomProgram(invalidActive))
    }

    func testActiveProgramDisplayNameFallsBackToFixedPPLLabel() {
        var noActive = UserPreferences()
        noActive.customPrograms = []
        noActive.activeProgramID = nil

        XCTAssertEqual(CustomProgramMigration.activeProgramDisplayName(noActive), "Fixed PPL")

        let program = CustomProgram(name: "My Custom", days: [])
        var withActive = UserPreferences()
        withActive.customPrograms = [program]
        withActive.activeProgramID = program.id

        XCTAssertEqual(CustomProgramMigration.activeProgramDisplayName(withActive), "My Custom")
    }
}
