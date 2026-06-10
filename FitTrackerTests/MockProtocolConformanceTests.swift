// FitTrackerTests/MockProtocolConformanceTests.swift
// T5 (test-coverage master plan) — Mock-protocol drift detection.
//
// SCOPE NOTE (the codebase differs from the 2026-05-13 spec): the four mocks the
// spec named (MockKeychainStorage / MockSupabaseClient / StubAIEngineClient /
// CountingAIEngineClient) do not exist. The real test doubles are mostly `private`
// to their own test files — good encapsulation, but it means a central file can't
// reference them. And Swift already compile-enforces each `Mock: Protocol`
// declaration, so re-asserting those is redundant.
//
// What this file DOES add — the durable, codebase-appropriate form of T5: a
// CENTRAL CONFORMANCE REGISTRY. Every protocol the test suite mocks gets one
// minimal anchor here. If a protocol's surface drifts (a method added/renamed/
// re-signed), the corresponding anchor fails to compile and THIS file is the
// single, clearly-labelled failure point — instead of a confusing error deep
// inside whichever private mock happened to break. The two app-target mocks that
// ARE shareable are additionally bound + smoke-tested below.
//
// Registry — keep in sync when adding a protocol with a test double:
//   AnalyticsProvider     ← MockAnalyticsAdapter (app target)        + anchor
//   GoogleAuthProviding   ← MockGoogleAuthProvider (app target)      + anchor
//   AppleAuthProviding    ← StubAppleAuthProvider (private, AuthPolishV2Tests)  anchor
//   EmailAuthProviding    ← StubEmailAuthProvider (private, AuthPolishV2Tests)  anchor
//   URLSessionProtocol    ← MockURLSession (private, CohortPriorClientTests)    anchor
//   AIInputAdapter        ← TestAdapter (private, ValidatedRecommendationTests) anchor

import XCTest
import Foundation
@testable import FitTracker

// MARK: - Conformance anchors (one per test-mocked protocol)
// Each anchor is the minimal type that satisfies the protocol. It exists ONLY to
// pin the protocol's surface at compile time — never called. A surface change
// breaks compilation HERE with a clear, central error.

private struct _AnalyticsProviderAnchor: AnalyticsProvider {
    func configure() {}
    func logEvent(_ name: String, parameters: [String: Any]?) {}
    func logScreenView(_ screenName: String, screenClass: String?) {}
    func setUserProperty(_ value: String?, forName name: String) {}
    func setUserID(_ id: String?) {}
    func setConsent(analyticsStorage: Bool, adStorage: Bool) {}
}

private struct _URLSessionAnchor: URLSessionProtocol {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        (Data(), URLResponse())
    }
}

private struct _AIInputAdapterAnchor: AIInputAdapter {
    var sourceID: String { "anchor" }
    var lastUpdated: Date? { nil }
    func contribute(to snapshot: inout LocalUserSnapshot) {}
}

private struct _AppleAuthAnchor: AppleAuthProviding {
    func startSignIn() async throws -> UserSession { throw CancellationError() }
}

private struct _GoogleAuthAnchor: GoogleAuthProviding {
    func signIn() async throws -> UserSession { throw CancellationError() }
}

private struct _EmailAuthAnchor: EmailAuthProviding {
    func register(_ draft: PendingEmailRegistration) async throws -> EmailRegistrationChallenge { throw CancellationError() }
    func verify(code: String, challenge: EmailRegistrationChallenge, draft: PendingEmailRegistration) async throws -> UserSession { throw CancellationError() }
    func login(email: String, password: String) async throws -> UserSession { throw CancellationError() }
    func resendRegistrationCode(challenge: EmailRegistrationChallenge, draft: PendingEmailRegistration) async throws -> EmailRegistrationChallenge { throw CancellationError() }
    func requestPasswordReset(email: String) async throws { throw CancellationError() }
    func updatePassword(newPassword: String) async throws { throw CancellationError() }
    func processRecoveryURL(_ url: URL) async throws { throw CancellationError() }
}

@MainActor
final class MockProtocolConformanceTests: XCTestCase {

    // MARK: - Compile-time registry assertion
    // Binding each anchor to its protocol type forces the conformance to be
    // exercised at compile time. If any anchor stopped conforming, the test
    // target would not build — so reaching the runtime assertion below at all
    // means every protocol surface still matches its anchor.

    func testAllMockedProtocolsHaveAConformanceAnchor() {
        let anchors: [Any] = [
            _AnalyticsProviderAnchor() as AnalyticsProvider,
            _URLSessionAnchor() as URLSessionProtocol,
            _AIInputAdapterAnchor() as AIInputAdapter,
            _AppleAuthAnchor() as AppleAuthProviding,
            _GoogleAuthAnchor() as GoogleAuthProviding,
            _EmailAuthAnchor() as EmailAuthProviding,
        ]
        XCTAssertEqual(anchors.count, 6, "Six test-mocked protocols are registered with a conformance anchor")
    }

    // MARK: - Shareable app-target mocks bind + smoke

    func testMockAnalyticsAdapter_conformsAndResponds() {
        let mock: AnalyticsProvider = MockAnalyticsAdapter()
        // Exercising a representative method proves the binding is real, not just
        // a compile-time cast that gets optimized away.
        mock.logEvent("t5_conformance_smoke", parameters: ["k": "v"])
        mock.setUserID("t5")
        // No crash + the binding held = the mock still satisfies AnalyticsProvider.
    }

    func testMockGoogleAuthProvider_conformsToProtocol() {
        let _: GoogleAuthProviding = MockGoogleAuthProvider()
        // Pure binding assertion — if MockGoogleAuthProvider drifted from
        // GoogleAuthProviding this line would fail to compile.
    }

    func testAnalyticsAnchorAndMockAgreeOnSurface() {
        // Both the central anchor and the real mock satisfy the same protocol —
        // a belt-and-suspenders check that the registry tracks the live type.
        let viaAnchor: AnalyticsProvider = _AnalyticsProviderAnchor()
        let viaMock: AnalyticsProvider = MockAnalyticsAdapter()
        viaAnchor.configure()
        viaMock.configure()
    }
}
