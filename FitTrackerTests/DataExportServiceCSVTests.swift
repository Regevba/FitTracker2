// FitTrackerTests/DataExportServiceCSVTests.swift
// Unit tests for the CSV export path added to DataExportService.

import XCTest
@testable import FitTracker

final class DataExportServiceCSVTests: XCTestCase {

    // MARK: - csvEscape RFC 4180 behavior

    func test_csvEscape_passesPlainStringUnchanged() {
        XCTAssertEqual(DataExportService.csvEscape("hello"), "hello")
        XCTAssertEqual(DataExportService.csvEscape(""), "")
        XCTAssertEqual(DataExportService.csvEscape("123.45"), "123.45")
        XCTAssertEqual(DataExportService.csvEscape("2026-05-31T12:00:00Z"), "2026-05-31T12:00:00Z")
    }

    func test_csvEscape_quotesAndEscapesFieldsWithCommas() {
        XCTAssertEqual(DataExportService.csvEscape("a,b"), "\"a,b\"")
        XCTAssertEqual(DataExportService.csvEscape("first, second, third"), "\"first, second, third\"")
    }

    func test_csvEscape_quotesAndEscapesFieldsWithNewlines() {
        XCTAssertEqual(DataExportService.csvEscape("line1\nline2"), "\"line1\nline2\"")
        XCTAssertEqual(DataExportService.csvEscape("line1\r\nline2"), "\"line1\r\nline2\"")
    }

    func test_csvEscape_doublesInternalDoubleQuotes() {
        XCTAssertEqual(DataExportService.csvEscape("she said \"hi\""), "\"she said \"\"hi\"\"\"")
        XCTAssertEqual(DataExportService.csvEscape("\""), "\"\"\"\"")
    }

    func test_csvEscape_handlesCombinedSpecialCharacters() {
        XCTAssertEqual(
            DataExportService.csvEscape("notes: \"set 1, 2x10\"\nset 2: 3x8"),
            "\"notes: \"\"set 1, 2x10\"\"\nset 2: 3x8\""
        )
    }
}
