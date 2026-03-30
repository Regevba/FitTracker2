// FitTrackerTests/SupabaseTests/UserSessionMappingTests.swift
import XCTest
import Auth  // Supabase Auth module
@testable import FitTracker

final class UserSessionMappingTests: XCTestCase {

    // MARK: - Tests

    func testMapsUserID() {
        let userID = UUID()
        let session = makeSession(user: makeUser(id: userID), accessToken: "header.payload.sig")
        let mapped = UserSession(from: session, displayName: "Test User")
        XCTAssertEqual(mapped.userID, userID.uuidString)
    }

    func testMapsAccessTokenNotUserID() {
        let jwt = "header.payload.signature"
        let session = makeSession(user: makeUser(), accessToken: jwt)
        let mapped = UserSession(from: session)
        XCTAssertEqual(mapped.sessionToken, jwt)
        XCTAssertTrue(mapped.sessionToken.contains("."), "sessionToken must be a JWT, not a plain userID")
    }

    func testFallsBackToEmailWhenDisplayNameEmpty() {
        let session = makeSession(user: makeUser(email: "hello@test.com"), accessToken: "tok")
        let mapped = UserSession(from: session, displayName: "")
        XCTAssertEqual(mapped.displayName, "hello@test.com")
    }

    func testUsesDisplayNameWhenProvided() {
        let session = makeSession(user: makeUser(email: "hello@test.com"), accessToken: "tok")
        let mapped = UserSession(from: session, displayName: "Regev Barak")
        XCTAssertEqual(mapped.displayName, "Regev Barak")
    }

    func testMapsEmail() {
        let session = makeSession(user: makeUser(email: "me@test.com"), accessToken: "tok")
        let mapped = UserSession(from: session)
        XCTAssertEqual(mapped.email, "me@test.com")
    }

    func testDefaultProviderIsApple() {
        let session = makeSession(user: makeUser(), accessToken: "tok")
        let mapped = UserSession(from: session)
        // Caller sets correct provider after construction; default is .apple
        XCTAssertEqual(mapped.provider, .apple)
    }

    // MARK: - Helpers

    private func makeUser(id: UUID = UUID(), email: String = "test@example.com") -> User {
        User(
            id: id,
            appMetadata: [:],
            userMetadata: [:],
            aud: "authenticated",
            email: email,
            phone: "+1555000000",
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    private func makeSession(user: User, accessToken: String) -> Session {
        Session(
            accessToken: accessToken,
            tokenType: "bearer",
            expiresIn: 3600,
            expiresAt: Date().timeIntervalSince1970 + 3600,
            refreshToken: "refresh",
            user: user
        )
    }
}
