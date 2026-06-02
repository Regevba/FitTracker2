// FitTrackerTests/AnalyticsTrainingCustomProgramEventsTests.swift
// C6 training-program-customization T14.E — confirms all 8 new training_custom_program_*
// + training_day_* + training_exercise_slot_* events fire with correct param shape.

import XCTest
@testable import FitTracker

@MainActor
final class AnalyticsTrainingCustomProgramEventsTests: XCTestCase {

    private var mock: MockAnalyticsAdapter!
    private var service: AnalyticsService!

    override func setUp() {
        super.setUp()
        mock = MockAnalyticsAdapter()
        let consent = ConsentManager()
        consent.grantConsent()
        service = AnalyticsService(provider: mock, consent: consent)
    }

    override func tearDown() {
        mock = nil
        service = nil
        super.tearDown()
    }

    func testAllEightEventsFireWithCorrectParamShape() {
        service.logTrainingCustomProgramListOpened(count: 3)
        service.logTrainingCustomProgramTemplateSelected(templateId: "ppl_6day")
        service.logTrainingCustomProgramSaved(programId: "prog-123", dayCount: 5, totalExerciseCount: 22)
        service.logTrainingCustomProgramActivated(programId: "prog-123")
        service.logTrainingCustomProgramDeleted(programId: "prog-123", dayCount: 5)
        service.logTrainingDayEdited(dayId: "day-456", field: "name")
        service.logTrainingExerciseSlotAdded(exerciseId: "chest_press_m", dayId: "day-456", overrideCount: 2)
        service.logTrainingExerciseSlotRemoved(exerciseId: "chest_press_m", dayId: "day-456")

        XCTAssertEqual(mock.capturedEvents.count, 8)

        XCTAssertEqual(mock.capturedEvents[0].name, "training_custom_program_list_opened")
        XCTAssertEqual(mock.capturedEvents[0].parameters?["count"] as? Int, 3)

        XCTAssertEqual(mock.capturedEvents[1].name, "training_custom_program_template_selected")
        XCTAssertEqual(mock.capturedEvents[1].parameters?["template_id"] as? String, "ppl_6day")

        XCTAssertEqual(mock.capturedEvents[2].name, "training_custom_program_saved")
        XCTAssertEqual(mock.capturedEvents[2].parameters?["program_id"] as? String, "prog-123")
        XCTAssertEqual(mock.capturedEvents[2].parameters?["day_count"] as? Int, 5)
        XCTAssertEqual(mock.capturedEvents[2].parameters?["total_exercise_count"] as? Int, 22)

        XCTAssertEqual(mock.capturedEvents[3].name, "training_custom_program_activated")
        XCTAssertEqual(mock.capturedEvents[3].parameters?["program_id"] as? String, "prog-123")

        XCTAssertEqual(mock.capturedEvents[4].name, "training_custom_program_deleted")
        XCTAssertEqual(mock.capturedEvents[4].parameters?["program_id"] as? String, "prog-123")
        XCTAssertEqual(mock.capturedEvents[4].parameters?["day_count"] as? Int, 5)

        XCTAssertEqual(mock.capturedEvents[5].name, "training_day_edited")
        XCTAssertEqual(mock.capturedEvents[5].parameters?["day_id"] as? String, "day-456")
        XCTAssertEqual(mock.capturedEvents[5].parameters?["field"] as? String, "name")

        XCTAssertEqual(mock.capturedEvents[6].name, "training_exercise_slot_added")
        XCTAssertEqual(mock.capturedEvents[6].parameters?["exercise_id"] as? String, "chest_press_m")
        XCTAssertEqual(mock.capturedEvents[6].parameters?["day_id"] as? String, "day-456")
        XCTAssertEqual(mock.capturedEvents[6].parameters?["override_count"] as? Int, 2)

        XCTAssertEqual(mock.capturedEvents[7].name, "training_exercise_slot_removed")
        XCTAssertEqual(mock.capturedEvents[7].parameters?["exercise_id"] as? String, "chest_press_m")
        XCTAssertEqual(mock.capturedEvents[7].parameters?["day_id"] as? String, "day-456")
    }
}
