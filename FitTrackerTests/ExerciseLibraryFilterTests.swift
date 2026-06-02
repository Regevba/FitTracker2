// FitTrackerTests/ExerciseLibraryFilterTests.swift
// C3 exercise-search-filter T9.B — pure-function filter behavior.

import XCTest
@testable import FitTracker

final class ExerciseLibraryFilterTests: XCTestCase {

    // Small deterministic fixture catalog covering each enum case used in
    // the tests. Mirrors the shape of TrainingProgramData.allExercises but
    // keeps the test independent of catalog churn.
    private let fixtures: [ExerciseDefinition] = [
        ExerciseDefinition(
            id: "fix_chest_machine", name: "Chest Press Machine",
            category: .machine, equipment: .machine,
            muscleGroups: [.chest], targetSets: 3, targetReps: "8-12",
            restSeconds: 90, coachingCue: "test", dayType: .upperPush, order: 1
        ),
        ExerciseDefinition(
            id: "fix_back_db", name: "Single-Arm DB Row",
            category: .freeWeight, equipment: .dumbbell,
            muscleGroups: [.back], targetSets: 3, targetReps: "10",
            restSeconds: 60, coachingCue: "test", dayType: .upperPull, order: 1
        ),
        ExerciseDefinition(
            id: "fix_legs_bb", name: "Romanian Deadlift",
            category: .freeWeight, equipment: .barbell,
            muscleGroups: [.hamstrings, .glutes], targetSets: 4, targetReps: "10-12",
            restSeconds: 90, coachingCue: "test", dayType: .lowerBody, order: 1
        ),
        ExerciseDefinition(
            id: "fix_cardio_ell", name: "Elliptical Zone 2",
            category: .cardio, equipment: .elliptical,
            muscleGroups: [.cardiovascular], targetSets: 1, targetReps: "25 min",
            restSeconds: 0, coachingCue: "test", dayType: .cardioOnly, order: 1
        ),
        ExerciseDefinition(
            id: "fix_core_bw", name: "Plank",
            category: .core, equipment: .bodyweight,
            muscleGroups: [.core], targetSets: 3, targetReps: "45s",
            restSeconds: 0, coachingCue: "test", dayType: .fullBody, order: 1
        ),
    ]

    // MARK: - Empty filter returns all

    func testEmptyQueryNoChipsReturnsEverything() {
        let result = ExerciseLibraryFilter.filteredExercises(
            query: "", muscle: nil, equipment: nil, category: nil, catalog: fixtures
        )
        XCTAssertEqual(result.count, fixtures.count)
    }

    // MARK: - Query matches name

    func testQueryMatchesExerciseName() {
        let result = ExerciseLibraryFilter.filteredExercises(
            query: "chest", muscle: nil, equipment: nil, category: nil, catalog: fixtures
        )
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.id, "fix_chest_machine")
    }

    // MARK: - Muscle chip alone

    func testMuscleFilterAloneReturnsOnlyThatMuscle() {
        let result = ExerciseLibraryFilter.filteredExercises(
            query: "", muscle: .back, equipment: nil, category: nil, catalog: fixtures
        )
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.id, "fix_back_db")
    }

    // MARK: - Equipment chip alone

    func testEquipmentFilterAloneReturnsOnlyThatEquipment() {
        let result = ExerciseLibraryFilter.filteredExercises(
            query: "", muscle: nil, equipment: .barbell, category: nil, catalog: fixtures
        )
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.id, "fix_legs_bb")
    }

    // MARK: - Strength rollup expands

    func testStrengthCategoryRollupIncludesMachineAndFreeWeightAndCalisthenics() {
        let result = ExerciseLibraryFilter.filteredExercises(
            query: "", muscle: nil, equipment: nil, category: .machine, catalog: fixtures
        )
        // Strength rollup includes the chest machine + back DB + legs barbell
        let ids = Set(result.map(\.id))
        XCTAssertEqual(ids, ["fix_chest_machine", "fix_back_db", "fix_legs_bb"])
    }

    // MARK: - Combined query + chips AND-gated

    func testCombinedQueryAndMuscleChipANDGated() {
        // Query "row" should match the back DB Row only — adding a muscle
        // chip for legs filters that out.
        let resultBack = ExerciseLibraryFilter.filteredExercises(
            query: "row", muscle: .back, equipment: nil, category: nil, catalog: fixtures
        )
        XCTAssertEqual(resultBack.count, 1)
        XCTAssertEqual(resultBack.first?.id, "fix_back_db")

        let resultLegs = ExerciseLibraryFilter.filteredExercises(
            query: "row", muscle: .hamstrings, equipment: nil, category: nil, catalog: fixtures
        )
        XCTAssertTrue(resultLegs.isEmpty)
    }
}
