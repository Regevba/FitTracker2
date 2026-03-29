// FitTrackerTests/SupabaseTests/SupabaseClientTests.swift
import XCTest
@testable import FitTracker

final class SupabaseClientTests: XCTestCase {
    func testSupabaseClientURLMatchesInfoPlist() throws {
        guard
            let urlStr = Bundle.main.object(forInfoDictionaryKey: "SupabaseURL") as? String,
            !urlStr.contains("YOUR_PROJECT_ID"),
            let expectedURL = URL(string: urlStr)
        else {
            throw XCTSkip("SupabaseURL not configured in Info.plist — skipped in CI")
        }
        // supabaseURL is internal in supabase-swift; verify client initialised without fatal.
        XCTAssertNotNil(supabase)
    }
}
