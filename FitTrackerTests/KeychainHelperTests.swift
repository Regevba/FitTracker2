// FitTrackerTests/KeychainHelperTests.swift
// BE-020: KeychainHelper.save() + delete() return status check.
// Verifies the @discardableResult Bool returns reflect actual SecItem outcomes.

import XCTest
@testable import FitTracker

final class KeychainHelperTests: XCTestCase {

    private let testKey = "ft.tests.keychain.\(UUID().uuidString)"

    override func tearDown() {
        // Clean up any leftover keychain entries from each test
        KeychainHelper.delete(key: testKey)
        super.tearDown()
    }

    // MARK: - Save

    func testSave_succeedsAndReturnsTrue() {
        let data = "secret".data(using: .utf8)!
        let result = KeychainHelper.save(key: testKey, data: data)
        XCTAssertTrue(result, "Save to a fresh key must return true")
    }

    func testSave_overwritesExisting_returnsTrue() {
        let first = "first".data(using: .utf8)!
        let second = "second".data(using: .utf8)!

        XCTAssertTrue(KeychainHelper.save(key: testKey, data: first))
        // Overwriting should also succeed (delete-then-add pattern)
        XCTAssertTrue(KeychainHelper.save(key: testKey, data: second))
    }

    // MARK: - Load round-trip

    func testSave_thenLoad_returnsExactBytes() {
        let original = Data([0xDE, 0xAD, 0xBE, 0xEF])
        XCTAssertTrue(KeychainHelper.save(key: testKey, data: original))

        let loaded = KeychainHelper.load(key: testKey)
        XCTAssertEqual(loaded, original, "Load must return the exact bytes that were saved")
    }

    // MARK: - Delete

    func testDelete_existingKey_returnsTrue() {
        XCTAssertTrue(KeychainHelper.save(key: testKey, data: Data([0x01])))
        XCTAssertTrue(KeychainHelper.delete(key: testKey),
                      "Delete of existing key must return true")
        XCTAssertNil(KeychainHelper.load(key: testKey),
                     "Load after delete must return nil")
    }

    func testDelete_missingKey_returnsTrue() {
        // errSecItemNotFound is treated as success (already absent)
        let unusedKey = "ft.tests.never.saved.\(UUID().uuidString)"
        XCTAssertTrue(KeychainHelper.delete(key: unusedKey),
                      "Delete of missing key must return true (already absent)")
    }

    // MARK: - Load missing key

    func testLoad_missingKey_returnsNil() {
        let unusedKey = "ft.tests.never.saved.\(UUID().uuidString)"
        XCTAssertNil(KeychainHelper.load(key: unusedKey))
    }

    // MARK: - AppMotion tokens (DS-007)

    func testAppMotion_allTokensExist() {
        // Smoke test that all motion tokens are accessible (compilation guard)
        _ = AppMotion.stepTransition
        _ = AppMotion.quickInteraction
        _ = AppMotion.pressFeedback
        _ = AppMotion.selectionChange
        _ = AppMotion.pageTransition
        _ = AppMotion.progressFill
    }
}
