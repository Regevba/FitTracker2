// FitTrackerTests/AnalyticsTrainingExerciseEventsTests.swift
// C3 exercise-search-filter T9.A — confirms all 4 new training_exercise_*
// events fire with the correct param shape via MockAnalyticsAdapter.

import XCTest
@testable import FitTracker

@MainActor
final class AnalyticsTrainingExerciseEventsTests: XCTestCase {

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

    func testAllFourEventsFireWithCorrectParamShape() {
        service.logTrainingExerciseLibraryOpened(source: "training_toolbar")
        service.logTrainingExerciseSearchQuery(queryLength: 5)
        service.logTrainingExerciseFilterTapped(dimension: "muscle", value: "Chest")
        service.logTrainingExerciseDetailOpened(exerciseId: "fix_chest_machine", viaSearch: true, viaFilter: false)

        XCTAssertEqual(mock.capturedEvents.count, 4)

        // Event 1 — library opened
        XCTAssertEqual(mock.capturedEvents[0].name, "training_exercise_library_opened")
        XCTAssertEqual(mock.capturedEvents[0].parameters?["source"] as? String, "training_toolbar")

        // Event 2 — search query
        XCTAssertEqual(mock.capturedEvents[1].name, "training_exercise_search_query")
        XCTAssertEqual(mock.capturedEvents[1].parameters?["query_length"] as? Int, 5)

        // Event 3 — filter tapped
        XCTAssertEqual(mock.capturedEvents[2].name, "training_exercise_filter_tapped")
        XCTAssertEqual(mock.capturedEvents[2].parameters?["dimension"] as? String, "muscle")
        XCTAssertEqual(mock.capturedEvents[2].parameters?["value"] as? String, "Chest")

        // Event 4 — detail opened
        XCTAssertEqual(mock.capturedEvents[3].name, "training_exercise_detail_opened")
        XCTAssertEqual(mock.capturedEvents[3].parameters?["exercise_id"] as? String, "fix_chest_machine")
        XCTAssertEqual(mock.capturedEvents[3].parameters?["via_search"] as? Bool, true)
        XCTAssertEqual(mock.capturedEvents[3].parameters?["via_filter"] as? Bool, false)
    }
}
