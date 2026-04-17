// FitTrackerTests/SessionTokenTypeTests.swift
// DEEP-AUTH-004: SessionTokenType enum tests + AppColor.Overlay.scrim contract.

import XCTest
import SwiftUI
@testable import FitTracker

final class SessionTokenTypeTests: XCTestCase {

    // MARK: - Enum coverage

    func testSessionTokenType_allCasesHaveStableRawValues() {
        // Raw values are persisted via Codable on UserSession — must never change
        // without an explicit migration. This test guards against accidental rename.
        XCTAssertEqual(SessionTokenType.supabaseJWT.rawValue, "supabaseJWT")
        XCTAssertEqual(SessionTokenType.passkeySignature.rawValue, "passkeySignature")
        XCTAssertEqual(SessionTokenType.appleUserID.rawValue, "appleUserID")
        XCTAssertEqual(SessionTokenType.debugSimulator.rawValue, "debugSimulator")
        XCTAssertEqual(SessionTokenType.reviewMode.rawValue, "reviewMode")
    }

    // MARK: - UserSession Codable round-trip with tokenType

    func testUserSession_withTokenType_codableRoundTrip() throws {
        let session = UserSession(
            provider: .apple,
            userID: "abc123",
            displayName: "Test",
            sessionToken: "jwt.payload.sig",
            tokenType: .supabaseJWT
        )

        let data = try JSONEncoder().encode(session)
        let decoded = try JSONDecoder().decode(UserSession.self, from: data)

        XCTAssertEqual(decoded.tokenType, .supabaseJWT)
        XCTAssertEqual(decoded.userID, "abc123")
    }

    func testUserSession_legacyJSON_withoutTokenType_decodes() throws {
        // Backward compat: legacy sessions written before Sprint D have no tokenType.
        // Decoding them must succeed with tokenType = nil (no migration crash).
        let legacy = """
        {
            "provider": "Apple",
            "userID": "legacy-user-1",
            "displayName": "Legacy User",
            "sessionToken": "old-token",
            "signedInAt": 760000000.0
        }
        """
        let data = legacy.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(UserSession.self, from: data)

        XCTAssertEqual(decoded.userID, "legacy-user-1")
        XCTAssertNil(decoded.tokenType,
                     "Legacy JSON without tokenType must decode with tokenType = nil, not crash")
    }

    // MARK: - AppColor.Overlay.scrim (DS-013)

    func testOverlayScrim_isBlackAt40PercentAlpha() {
        // Verify the scrim resolves to black with alpha 0.4
        #if canImport(UIKit)
        let uiColor = UIColor(AppColor.Overlay.scrim)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        XCTAssertEqual(red, 0, accuracy: 0.01)
        XCTAssertEqual(green, 0, accuracy: 0.01)
        XCTAssertEqual(blue, 0, accuracy: 0.01)
        XCTAssertEqual(alpha, 0.4, accuracy: 0.01,
                       "Scrim alpha must be 0.4 for the standard modal backdrop")
        #endif
    }
}
