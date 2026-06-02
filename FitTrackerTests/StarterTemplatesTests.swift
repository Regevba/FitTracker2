// FitTrackerTests/StarterTemplatesTests.swift
// C6 training-program-customization T14.C — all 4 starter templates materialize correctly.

import XCTest
@testable import FitTracker

final class StarterTemplatesTests: XCTestCase {

    func testAllFourTemplatesMaterializeWithoutCrash() {
        for templateId in TemplateID.allCases {
            let program = TrainingProgramData.template(templateId)
            XCTAssertFalse(program.name.isEmpty, "Template \(templateId.rawValue) has empty name")
            XCTAssertEqual(program.days.count, 7, "Template \(templateId.rawValue) expected 7 days, got \(program.days.count)")
        }
    }

    func testEmptyTemplateHasNoSlots() {
        let empty = TrainingProgramData.template(.empty)
        let totalSlots = empty.days.reduce(0) { $0 + $1.slots.count }
        XCTAssertEqual(totalSlots, 0)
        XCTAssertTrue(empty.days.allSatisfy { $0.dayType == .restDay })
    }

    func testPPLTemplateHasFiveTrainingDays() {
        let ppl = TrainingProgramData.template(.ppl6Day)
        let trainingDays = ppl.days.filter { $0.dayType != .restDay }
        // PPL = Upper Push + Lower + Upper Pull + Full Body + Cardio Only = 5 non-rest days
        XCTAssertEqual(trainingDays.count, 5)
    }

    func testUpperLowerTemplateHasFourTrainingDays() {
        let ul = TrainingProgramData.template(.upperLower4Day)
        let trainingDays = ul.days.filter { $0.dayType != .restDay }
        XCTAssertEqual(trainingDays.count, 4)
    }

    func testFullBody3DayTemplateHasThreeTrainingDays() {
        let fb = TrainingProgramData.template(.fullBody3Day)
        let trainingDays = fb.days.filter { $0.dayType != .restDay }
        XCTAssertEqual(trainingDays.count, 3)
    }

    func testTemplateMaterializesFreshUUIDsPerCall() {
        let first = TrainingProgramData.template(.ppl6Day)
        let second = TrainingProgramData.template(.ppl6Day)
        XCTAssertNotEqual(first.id, second.id, "Each template call should generate a fresh program UUID")
        if let firstDay = first.days.first, let secondDay = second.days.first {
            XCTAssertNotEqual(firstDay.id, secondDay.id, "Day UUIDs should also be fresh per call")
        }
    }
}
