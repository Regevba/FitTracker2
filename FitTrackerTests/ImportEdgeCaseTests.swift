// FitTrackerTests/ImportEdgeCaseTests.swift
// TEST-024: CSV import edge cases — malformed input, non-numeric values,
// unknown columns, short rows, empty input.

import XCTest
@testable import FitTracker

final class ImportEdgeCaseTests: XCTestCase {

    // MARK: - canParse

    func testCanParse_requiresExerciseKeyword() {
        let parser = CSVImportParser()
        // Valid CSV: has "exercise" in header + comma + >=2 lines
        XCTAssertTrue(parser.canParse("exercise,sets,reps\nBench,3,8"))
        // Missing exercise keyword
        XCTAssertFalse(parser.canParse("name,sets,reps\nBench,3,8"))
        // Only one line
        XCTAssertFalse(parser.canParse("exercise,sets,reps"))
        // Empty input
        XCTAssertFalse(parser.canParse(""))
    }

    func testCanParse_isCaseInsensitive() {
        let parser = CSVImportParser()
        XCTAssertTrue(parser.canParse("EXERCISE,SETS,REPS\nBench,3,8"))
        XCTAssertTrue(parser.canParse("Exercise,Sets,Reps\nBench,3,8"))
    }

    // MARK: - parse — happy path

    func testParse_basicCSV_returnsPlanWithOneDay() throws {
        let parser = CSVImportParser()
        let csv = """
        exercise,sets,reps,rest
        Bench Press,4,8,90
        Squat,3,6,120
        """
        let plan = try parser.parse(csv)
        XCTAssertEqual(plan.days.count, 1)
        XCTAssertEqual(plan.days.first?.exercises.count, 2)
        XCTAssertEqual(plan.days.first?.exercises[0].rawName, "Bench Press")
        XCTAssertEqual(plan.days.first?.exercises[0].sets, 4)
        XCTAssertEqual(plan.days.first?.exercises[0].restSeconds, 90)
    }

    // MARK: - parse — edge cases

    func testParse_nonNumericSets_fallsBackToDefault() throws {
        let parser = CSVImportParser()
        let csv = """
        exercise,sets,reps
        Bench,invalid,8
        """
        let plan = try parser.parse(csv)
        // Non-numeric "invalid" must not crash — falls back to default (3)
        XCTAssertEqual(plan.days.first?.exercises.first?.sets, 3)
    }

    func testParse_missingRepsColumn_usesDefault() throws {
        let parser = CSVImportParser()
        let csv = """
        exercise,sets
        Bench,3
        """
        let plan = try parser.parse(csv)
        XCTAssertEqual(plan.days.first?.exercises.first?.reps, "8",
                       "Missing reps column should default to \"8\"")
    }

    func testParse_missingRestColumn_restIsNil() throws {
        let parser = CSVImportParser()
        let csv = """
        exercise,sets,reps
        Bench,3,8
        """
        let plan = try parser.parse(csv)
        XCTAssertNil(plan.days.first?.exercises.first?.restSeconds)
    }

    func testParse_shortRowIsSkipped() throws {
        let parser = CSVImportParser()
        let csv = """
        exercise,sets,reps
        TooShort
        Bench,3,8
        """
        let plan = try parser.parse(csv)
        // The single-column "TooShort" row should be silently skipped
        XCTAssertEqual(plan.days.first?.exercises.count, 1)
        XCTAssertEqual(plan.days.first?.exercises.first?.rawName, "Bench")
    }

    func testParse_unknownExtraColumn_isIgnored() throws {
        let parser = CSVImportParser()
        let csv = """
        exercise,sets,reps,rest,unknown_col
        Bench,3,8,90,ignored_value
        """
        let plan = try parser.parse(csv)
        // Should parse successfully, ignoring the extra column
        XCTAssertEqual(plan.days.first?.exercises.count, 1)
    }

    // MARK: - Error cases

    func testParse_emptyInput_throwsEmptyInputError() {
        let parser = CSVImportParser()
        XCTAssertThrowsError(try parser.parse("")) { error in
            if case ImportError.emptyInput = error { /* OK */ } else {
                XCTFail("Expected .emptyInput, got \(error)")
            }
        }
    }

    func testParse_singleHeaderLine_throwsEmptyInput() {
        let parser = CSVImportParser()
        XCTAssertThrowsError(try parser.parse("exercise,sets,reps")) { error in
            if case ImportError.emptyInput = error { /* OK */ } else {
                XCTFail("Expected .emptyInput, got \(error)")
            }
        }
    }
}
