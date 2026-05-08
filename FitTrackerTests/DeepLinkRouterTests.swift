// FitTrackerTests/DeepLinkRouterTests.swift
// T13 — push-notifications-v2 unit tests for DeepLinkRouter URL resolver +
// pendingDeepLink emission + idempotency dedup.

import XCTest
@testable import FitTracker

@MainActor
final class DeepLinkRouterTests: XCTestCase {

    override func setUp() {
        super.setUp()
        DeepLinkRouter.shared.consume()
        DeepLinkRouter.shared._resetDedupForTesting()
    }

    override func tearDown() {
        DeepLinkRouter.shared.consume()
        DeepLinkRouter.shared._resetDedupForTesting()
        super.tearDown()
    }

    // MARK: T13/R-1 — URL → Action resolution (pure resolver)

    func testResolvesNavURLToNavigateToTab() {
        let url = URL(string: "fitme://nav/training")!
        XCTAssertEqual(DeepLinkRouter.resolve(url: url), .navigateToTab(.training))
    }

    func testResolvesNavHomeAndNavMainBothToMain() {
        let homeURL = URL(string: "fitme://nav/home")!
        let mainURL = URL(string: "fitme://nav/main")!
        XCTAssertEqual(DeepLinkRouter.resolve(url: homeURL), .navigateToTab(.main))
        XCTAssertEqual(DeepLinkRouter.resolve(url: mainURL), .navigateToTab(.main))
    }

    func testResolvesActionURLToPresentSheet() {
        let url = URL(string: "fitme://action/log-meal")!
        XCTAssertEqual(DeepLinkRouter.resolve(url: url), .presentSheet(.logMeal))
    }

    func testResolvesAuthURLToAuthFlow() {
        let url = URL(string: "fitme://auth/reset-password?token=xyz")!
        guard case .authFlow(let forwarded) = DeepLinkRouter.resolve(url: url) else {
            return XCTFail("Expected .authFlow case")
        }
        XCTAssertEqual(forwarded.absoluteString, "fitme://auth/reset-password?token=xyz")
    }

    func testResolvesSettingsURLToSettingsSection() {
        let url = URL(string: "fitme://settings/health")!
        XCTAssertEqual(DeepLinkRouter.resolve(url: url), .settingsSection(.health))
    }

    func testUnknownPatternResolvesToNil() {
        XCTAssertNil(DeepLinkRouter.resolve(url: URL(string: "fitme://unknown/foo")!))
        XCTAssertNil(DeepLinkRouter.resolve(url: URL(string: "fitme://nav/unknown")!))
        XCTAssertNil(DeepLinkRouter.resolve(url: URL(string: "https://other.com/x")!),
                     "Non-fitme schemes should not resolve")
    }

    // MARK: T13/R-2 — pendingDeepLink emission + consumption

    func testHandleSetsPendingDeepLink() {
        let url = URL(string: "fitme://nav/nutrition")!
        XCTAssertNil(DeepLinkRouter.shared.pendingDeepLink, "Pre-state: nil")

        let outcome = DeepLinkRouter.shared.handle(url: url, source: .url)
        XCTAssertEqual(outcome, .succeeded)
        XCTAssertEqual(DeepLinkRouter.shared.pendingDeepLink, .navigateToTab(.nutrition))
    }

    func testConsumeClearsPendingDeepLink() {
        DeepLinkRouter.shared.handle(url: URL(string: "fitme://nav/stats")!, source: .url)
        XCTAssertNotNil(DeepLinkRouter.shared.pendingDeepLink)

        DeepLinkRouter.shared.consume()
        XCTAssertNil(DeepLinkRouter.shared.pendingDeepLink)
    }

    func testHandleUnknownPatternReportsFailedNoPatternMatch() {
        let outcome = DeepLinkRouter.shared.handle(
            url: URL(string: "fitme://unknown/foo")!,
            source: .url
        )
        XCTAssertEqual(outcome, .failed_no_pattern_match)
        XCTAssertNil(DeepLinkRouter.shared.pendingDeepLink,
                     "Unknown URL must not pollute pendingDeepLink")
    }

    // MARK: T13/R-4 — Analytics event firing (closes Phase 5 analytics gate)

    /// Verifies `deep_link_routed` event fires with the expected params on every
    /// successful URL routing. Strict-reading of the PM workflow Phase 5 analytics
    /// verification gate per CLAUDE.md "no PRD without metrics" + the v2 spec's
    /// kill-criteria that gates on outcome=succeeded rate ≥ 95%.
    func testHandle_firesDeepLinkRoutedAnalyticsEvent_succeededOutcome() {
        let mock = MockAnalyticsAdapter()
        let analytics = AnalyticsService(provider: mock, consent: ConsentManager())
        analytics.consent.grantConsent() // unblock event flow
        analytics.syncConsentToProvider()
        DeepLinkRouter.shared.analytics = analytics
        defer { DeepLinkRouter.shared.analytics = nil }

        DeepLinkRouter.shared.handle(url: URL(string: "fitme://nav/training")!, source: .url)

        let routed = mock.capturedEvents.filter { $0.name == AnalyticsEvent.deepLinkRouted }
        XCTAssertEqual(routed.count, 1, "Exactly one deep_link_routed event must fire per handle()")

        let params = routed.first?.parameters ?? [:]
        XCTAssertEqual(params[AnalyticsParam.deepLinkSource] as? String, "url")
        XCTAssertEqual(params[AnalyticsParam.destination]    as? String, "tab")
        XCTAssertEqual(params[AnalyticsParam.urlPattern]     as? String, "fitme://nav/training")
        XCTAssertEqual(params[AnalyticsParam.outcome]        as? String, "succeeded")
    }

    /// Failed routes also emit deep_link_routed — with outcome=failed_no_pattern_match.
    /// This is the kill-criterion-supporting telemetry: if outcome=succeeded rate
    /// drops below 95%, dashboards alert.
    func testHandle_firesDeepLinkRoutedAnalyticsEvent_failedOutcome() {
        let mock = MockAnalyticsAdapter()
        let analytics = AnalyticsService(provider: mock, consent: ConsentManager())
        analytics.consent.grantConsent()
        analytics.syncConsentToProvider()
        DeepLinkRouter.shared.analytics = analytics
        defer { DeepLinkRouter.shared.analytics = nil }

        DeepLinkRouter.shared.handle(url: URL(string: "fitme://unknown/foo")!, source: .notification)

        let routed = mock.capturedEvents.filter { $0.name == AnalyticsEvent.deepLinkRouted }
        XCTAssertEqual(routed.count, 1)
        let params = routed.first?.parameters ?? [:]
        XCTAssertEqual(params[AnalyticsParam.deepLinkSource] as? String, "notification")
        XCTAssertEqual(params[AnalyticsParam.outcome]        as? String, "failed_no_pattern_match")
    }

    // MARK: T13/R-3 — Idempotency dedup (200ms window)

    func testRapidDuplicateHandleIsNoOp() {
        let url = URL(string: "fitme://nav/training")!
        let first = DeepLinkRouter.shared.handle(url: url, source: .notification)
        XCTAssertEqual(first, .succeeded)
        XCTAssertEqual(DeepLinkRouter.shared.pendingDeepLink, .navigateToTab(.training))

        DeepLinkRouter.shared.consume()

        // Same (url, source) within 200ms — should short-circuit, NOT re-emit
        let second = DeepLinkRouter.shared.handle(url: url, source: .notification)
        XCTAssertEqual(second, .succeeded, "Dedup returns .succeeded but does not re-emit")
        XCTAssertNil(DeepLinkRouter.shared.pendingDeepLink,
                     "Dedup'd call must not re-set pendingDeepLink")
    }
}
