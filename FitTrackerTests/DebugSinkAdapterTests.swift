// DebugSinkAdapterTests.swift
// Phase 2.A.3 of analytics-observability per
// docs/master-plan/analytics-master-plan-2026-05-13.md §6.1.
//
// Verifies that DebugSinkAdapter:
//   1. Is a transparent passthrough when DEBUG_ANALYTICS env var is unset
//      (production safety — Firebase/GA4 still receives all events identically)
//   2. Tees logEvent + logScreenView to the sink when DEBUG_ANALYTICS=1
//   3. NEVER tees user-identity APIs (setUserProperty / setUserID / setConsent)
//      because those can carry per-user PII

import XCTest
@testable import FitTracker

final class DebugSinkAdapterTests: XCTestCase {

    // MARK: - Doubles

    /// Records every event sent to the debug sink.
    private final class RecordingSink: AnalyticsDebugEventSink {
        struct Captured {
            let name: String
            let parameters: [String: Any]?
        }
        private(set) var captured: [Captured] = []

        func send(name: String, parameters: [String: Any]?) {
            captured.append(Captured(name: name, parameters: parameters))
        }
    }

    // MARK: - Setup

    private var inner: MockAnalyticsAdapter!
    private var sink: RecordingSink!

    override func setUp() {
        super.setUp()
        inner = MockAnalyticsAdapter()
        sink = RecordingSink()
    }

    override func tearDown() {
        inner = nil
        sink = nil
        super.tearDown()
    }

    // MARK: - Production safety: tee disabled by default

    func testIsTeeingFalseWhenEnvUnset() {
        let adapter = DebugSinkAdapter(wrapping: inner, environment: [:])
        XCTAssertFalse(adapter.isTeeing, "Sink must be nil when DEBUG_ANALYTICS env var is unset")
    }

    func testInnerReceivesEventEvenWithoutSink() {
        let adapter = DebugSinkAdapter(wrapping: inner, environment: [:])
        adapter.logEvent("test_event", parameters: ["a": 1])
        XCTAssertEqual(inner.capturedEvents.count, 1)
        XCTAssertEqual(inner.capturedEvents[0].name, "test_event")
    }

    func testInnerReceivesScreenViewEvenWithoutSink() {
        let adapter = DebugSinkAdapter(wrapping: inner, environment: [:])
        adapter.logScreenView("home", screenClass: "HomeView")
        XCTAssertEqual(inner.capturedScreens.count, 1)
        XCTAssertEqual(inner.capturedScreens[0], "home")
    }

    // MARK: - Tee behavior: env-gated

    func testIsTeeingTrueWhenEnvSetAndExplicitSink() {
        let adapter = DebugSinkAdapter(wrapping: inner, sink: sink, environment: ["DEBUG_ANALYTICS": "1"])
        XCTAssertTrue(adapter.isTeeing)
    }

    func testLogEventTeesToSinkWhenEnabled() {
        let adapter = DebugSinkAdapter(wrapping: inner, sink: sink, environment: ["DEBUG_ANALYTICS": "1"])
        adapter.logEvent("home_action_tap", parameters: ["action_type": "start_workout"])

        // Inner still receives event (passthrough preserved)
        XCTAssertEqual(inner.capturedEvents.count, 1)
        XCTAssertEqual(inner.capturedEvents[0].name, "home_action_tap")
        XCTAssertEqual(inner.capturedEvents[0].parameters?["action_type"] as? String, "start_workout")

        // Sink also receives the same event
        XCTAssertEqual(sink.captured.count, 1)
        XCTAssertEqual(sink.captured[0].name, "home_action_tap")
        XCTAssertEqual(sink.captured[0].parameters?["action_type"] as? String, "start_workout")
    }

    func testLogEventDoesNotTeeWhenSinkNil() {
        let adapter = DebugSinkAdapter(wrapping: inner, environment: [:])
        adapter.logEvent("home_action_tap", parameters: nil)
        XCTAssertEqual(inner.capturedEvents.count, 1)
        // sink is local to this test — we use the explicit-sink path elsewhere;
        // here we just verify production-safe behavior under default env.
    }

    func testLogScreenViewTeesAsScreenViewEvent() {
        let adapter = DebugSinkAdapter(wrapping: inner, sink: sink, environment: ["DEBUG_ANALYTICS": "1"])
        adapter.logScreenView("training_session", screenClass: "ActiveTrainingSessionView")

        XCTAssertEqual(inner.capturedScreens.count, 1)
        XCTAssertEqual(inner.capturedScreens[0], "training_session")

        XCTAssertEqual(sink.captured.count, 1)
        XCTAssertEqual(sink.captured[0].name, "screen_view")
        XCTAssertEqual(sink.captured[0].parameters?["screen_name"] as? String, "training_session")
        XCTAssertEqual(sink.captured[0].parameters?["screen_class"] as? String, "ActiveTrainingSessionView")
    }

    func testLogScreenViewWithNilClassUsesEmptyString() {
        let adapter = DebugSinkAdapter(wrapping: inner, sink: sink, environment: ["DEBUG_ANALYTICS": "1"])
        adapter.logScreenView("home", screenClass: nil)
        XCTAssertEqual(sink.captured[0].parameters?["screen_class"] as? String, "")
    }

    // MARK: - PII safety: user-identity APIs NEVER tee

    func testSetUserPropertyNeverTees() {
        let adapter = DebugSinkAdapter(wrapping: inner, sink: sink, environment: ["DEBUG_ANALYTICS": "1"])
        adapter.setUserProperty("intermediate", forName: "training_level")

        XCTAssertEqual(sink.captured.count, 0,
                       "setUserProperty must NEVER tee — user properties may carry PII")
    }

    func testSetUserIDNeverTees() {
        let adapter = DebugSinkAdapter(wrapping: inner, sink: sink, environment: ["DEBUG_ANALYTICS": "1"])
        adapter.setUserID("user-12345")

        XCTAssertEqual(sink.captured.count, 0,
                       "setUserID must NEVER tee — user IDs are PII")
    }

    func testSetConsentNeverTees() {
        let adapter = DebugSinkAdapter(wrapping: inner, sink: sink, environment: ["DEBUG_ANALYTICS": "1"])
        adapter.setConsent(analyticsStorage: true, adStorage: false)

        XCTAssertEqual(sink.captured.count, 0,
                       "setConsent must NEVER tee — operator state, not analytics event")
    }

    // MARK: - Env-driven sink resolution

    func testEnvVarUnsetMeansNoSink() {
        let adapter = DebugSinkAdapter(wrapping: inner, environment: ["FOO": "bar"])
        XCTAssertFalse(adapter.isTeeing)
    }

    func testEnvVarValueOtherThan1MeansNoSink() {
        // Only "1" enables — "true", "yes", "0", etc. all disable
        let adapter = DebugSinkAdapter(wrapping: inner, environment: ["DEBUG_ANALYTICS": "true"])
        XCTAssertFalse(adapter.isTeeing,
                       "Only DEBUG_ANALYTICS=1 enables; other truthy strings are conservative-disabled")
    }

    func testEnvVarSetTo1AutoConstructsURLSessionSink() {
        // No explicit sink override → constructor builds URLSessionEventSink
        let adapter = DebugSinkAdapter(wrapping: inner, environment: ["DEBUG_ANALYTICS": "1"])
        XCTAssertTrue(adapter.isTeeing,
                      "DEBUG_ANALYTICS=1 with no explicit sink override should auto-construct URLSessionEventSink")
    }

    func testExplicitSinkOverrideWinsOverEnv() {
        // Even with env unset, an explicit sink turns on teeing — for tests
        let adapter = DebugSinkAdapter(wrapping: inner, sink: sink, environment: [:])
        XCTAssertTrue(adapter.isTeeing)
        adapter.logEvent("forced_tee", parameters: nil)
        XCTAssertEqual(sink.captured.count, 1)
    }
}
