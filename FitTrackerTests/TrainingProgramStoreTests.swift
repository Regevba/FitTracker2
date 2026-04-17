// FitTrackerTests/TrainingProgramStoreTests.swift
// TEST-016: TrainingProgramStore — weekday → DayType mapping + exercise retrieval.

import XCTest
@testable import FitTracker

@MainActor
final class TrainingProgramStoreTests: XCTestCase {

    // MARK: - Static weekday mapping

    func testDayType_forEachWeekday() {
        // Calendar weekday: 1=Sunday, 2=Monday, ..., 7=Saturday
        let mapping: [(weekday: Int, expected: DayType)] = [
            (1, .restDay),       // Sunday
            (2, .upperPush),     // Monday
            (3, .lowerBody),     // Tuesday
            (4, .restDay),       // Wednesday
            (5, .upperPull),     // Thursday
            (6, .fullBody),      // Friday
            (7, .cardioOnly),    // Saturday
        ]
        for (weekday, expected) in mapping {
            XCTAssertEqual(
                TrainingProgramStore.dayType(forWeekday: weekday),
                expected,
                "Weekday \(weekday) should map to \(expected)"
            )
        }
    }

    func testDayType_unknownWeekdayDefaultsToRestDay() {
        // Weekday 0 and 8 are invalid — must not crash, must fall back to rest
        XCTAssertEqual(TrainingProgramStore.dayType(forWeekday: 0), .restDay)
        XCTAssertEqual(TrainingProgramStore.dayType(forWeekday: 8), .restDay)
        XCTAssertEqual(TrainingProgramStore.dayType(forWeekday: -1), .restDay)
    }

    func testRestWeekdays_areSundayAndWednesday() {
        XCTAssertEqual(TrainingProgramStore.restWeekdays, [1, 4])
    }

    // MARK: - Init + detectToday

    func testInit_setsTodayDayTypeFromCalendar() {
        let store = TrainingProgramStore()
        let expectedWeekday = Calendar.current.component(.weekday, from: Date())
        let expected = TrainingProgramStore.dayType(forWeekday: expectedWeekday)
        XCTAssertEqual(store.todayDayType, expected)
    }

    // MARK: - exercises(for:)

    func testExercises_trainingDayReturnsNonEmpty() {
        let store = TrainingProgramStore()
        for day in [DayType.upperPush, .lowerBody, .upperPull, .fullBody] {
            XCTAssertFalse(
                store.exercises(for: day).isEmpty,
                "\(day) should have at least one exercise in the program"
            )
        }
    }

    func testExercises_restDayReturnsEmptyOrMinimal() {
        let store = TrainingProgramStore()
        // Rest day may or may not have exercises defined — at minimum it shouldn't crash
        _ = store.exercises(for: .restDay)
    }
}
