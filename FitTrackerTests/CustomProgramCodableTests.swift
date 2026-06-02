// FitTrackerTests/CustomProgramCodableTests.swift
// C6 training-program-customization T14.A — Codable round-trip for the data model.

import XCTest
@testable import FitTracker

final class CustomProgramCodableTests: XCTestCase {

    func testCustomProgramRoundTrip() throws {
        let original = CustomProgram(
            name: "My PPL",
            days: [
                CustomDay(
                    name: "Upper Push",
                    dayType: .upperPush,
                    weekdayIndex: 1,
                    slots: [
                        ExerciseSlot(exerciseID: "chest_press_m", order: 0),
                        ExerciseSlot(
                            exerciseID: "pec_deck",
                            targetSetsOverride: 4,
                            targetRepsOverride: "10",
                            restSecondsOverride: 75,
                            order: 1
                        ),
                    ]
                )
            ]
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CustomProgram.self, from: data)

        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.schemaVersion, CustomProgramSchema.currentVersion)
    }

    func testExerciseSlotOverrideCountCorrectness() {
        let none = ExerciseSlot(exerciseID: "x", order: 0)
        XCTAssertEqual(none.overrideCount, 0)

        let one = ExerciseSlot(exerciseID: "x", targetSetsOverride: 3, order: 0)
        XCTAssertEqual(one.overrideCount, 1)

        let two = ExerciseSlot(
            exerciseID: "x",
            targetSetsOverride: 3,
            targetRepsOverride: "10",
            order: 0
        )
        XCTAssertEqual(two.overrideCount, 2)

        let three = ExerciseSlot(
            exerciseID: "x",
            targetSetsOverride: 3,
            targetRepsOverride: "10",
            restSecondsOverride: 60,
            order: 0
        )
        XCTAssertEqual(three.overrideCount, 3)
    }
}
