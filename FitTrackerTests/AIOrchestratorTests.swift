// FitTrackerTests/AIOrchestratorTests.swift
// TEST-007: AIOrchestrator cloud-tier and adaptation paths.
//
// Pre-existing coverage (FitTrackerCoreTests.swift) only exercises the local
// fallback path with an empty snapshot (engine never called). This file
// extends coverage to:
//   - Cloud call when bands are complete + valid JWT
//   - Cloud-error fallbacks (rate limit, unauthorized, generic network error)
//   - Foundation Model adaptation above/below the 0.4 personalisation threshold
//   - Adaptation throwing → keeps base recommendation, no error propagation
//   - processAll() iterating every AISegment
//   - clearRecommendations() resets state
//   - JWT shape guard (looksLikeJWT) gates the cloud call
//
// Strategy: protocol-based mocks for AIEngineClient and FoundationModel — no
// network or iOS 26 SDK required. Mocks live inside this file (file-private)
// to avoid colliding with the existing CountingAIEngineClient in FitTrackerCoreTests.

import XCTest
@testable import FitTracker

// MARK: - Test doubles

/// Returns a cloud-shaped recommendation and tracks how many times it was called.
private actor StubAIEngineClient: AIEngineClientProtocol {
    enum Behavior {
        case success(AIRecommendation)
        case throwError(Error)
    }

    private var behavior: Behavior
    private(set) var callCount = 0
    private(set) var lastJWT: String?
    private(set) var lastSegment: AISegment?
    private(set) var lastPayload: [String: String]?

    init(behavior: Behavior = .success(
        AIRecommendation(
            segment: AISegment.training.rawValue,
            signals: ["cloud_cohort_signal"],
            confidence: 0.9,
            escalateToLLM: false,
            supportingData: [:]
        )
    )) {
        self.behavior = behavior
    }

    func setBehavior(_ behavior: Behavior) {
        self.behavior = behavior
    }

    func fetchInsight(
        segment: AISegment,
        payload: [String: String],
        jwt: String
    ) async throws -> AIRecommendation {
        callCount += 1
        lastSegment = segment
        lastJWT = jwt
        lastPayload = payload
        switch behavior {
        case .success(let rec): return rec
        case .throwError(let err): throw err
        }
    }
}

/// Foundation Model mock with configurable confidence + optional throw.
private struct ConfigurableFoundationModel: FoundationModelProtocol {
    let isAvailable: Bool
    let confidence: Double
    let shouldThrow: Bool
    let signalsToAppend: [String]

    init(
        isAvailable: Bool = true,
        confidence: Double = 0.8,
        shouldThrow: Bool = false,
        signalsToAppend: [String] = ["adapted_local_signal"]
    ) {
        self.isAvailable = isAvailable
        self.confidence = confidence
        self.shouldThrow = shouldThrow
        self.signalsToAppend = signalsToAppend
    }

    func adapt(
        recommendation: AIRecommendation,
        snapshot: LocalUserSnapshot
    ) async throws -> (recommendation: AIRecommendation, confidence: Double) {
        if shouldThrow {
            struct AdaptationFailure: Error {}
            throw AdaptationFailure()
        }
        let adapted = AIRecommendation(
            segment: recommendation.segment,
            signals: recommendation.signals + signalsToAppend,
            confidence: recommendation.confidence,
            escalateToLLM: recommendation.escalateToLLM,
            supportingData: recommendation.supportingData
        )
        return (adapted, confidence)
    }
}

// MARK: - Snapshot factory

private func completeTrainingSnapshot() -> LocalUserSnapshot {
    var s = LocalUserSnapshot()
    // Required fields for trainingBands() to succeed
    s.ageYears = 32
    s.bmiValue = 23.5
    s.activeWeeks = 8
    s.programPhase = "build"
    s.trainingDaysPerWeek = 4
    s.avgSessionMinutes = 45
    s.primaryGoal = "muscle_gain"
    s.genderIdentity = "male"
    return s
}

// MARK: - Tests

@MainActor
final class AIOrchestratorTests: XCTestCase {

    // ── JWT / band gating ────────────────────────────────

    func testProcess_withValidJWTAndCompleteBands_callsCloud() async {
        let engine = StubAIEngineClient()
        let orchestrator = AIOrchestrator(
            engineClient: engine,
            foundationModel: ConfigurableFoundationModel(),
            snapshot: { completeTrainingSnapshot() },
            goalMode: { .gain }
        )

        await orchestrator.process(
            segment: .training,
            jwt: "header.payload.signature",
            overrideSnapshot: completeTrainingSnapshot()
        )

        let count = await engine.callCount
        XCTAssertEqual(count, 1, "Cloud must be called once when JWT is shaped & bands complete")
        XCTAssertNil(orchestrator.lastError, "Successful cloud call should leave lastError nil")
    }

    func testProcess_withMalformedJWT_skipsCloud() async {
        let engine = StubAIEngineClient()
        let orchestrator = AIOrchestrator(
            engineClient: engine,
            foundationModel: ConfigurableFoundationModel(),
            snapshot: { completeTrainingSnapshot() },
            goalMode: { .gain }
        )

        // "not-a-jwt" lacks the 3-part dot-separated shape
        await orchestrator.process(
            segment: .training,
            jwt: "not-a-jwt",
            overrideSnapshot: completeTrainingSnapshot()
        )

        let count = await engine.callCount
        XCTAssertEqual(count, 0, "Malformed JWT must not trigger cloud call")
    }

    func testProcess_withNilJWT_skipsCloudUsesLocalBaseline() async {
        let engine = StubAIEngineClient()
        let orchestrator = AIOrchestrator(
            engineClient: engine,
            foundationModel: ConfigurableFoundationModel(),
            snapshot: { completeTrainingSnapshot() },
            goalMode: { .gain }
        )

        await orchestrator.process(
            segment: .training,
            jwt: nil,
            overrideSnapshot: completeTrainingSnapshot()
        )

        let count = await engine.callCount
        XCTAssertEqual(count, 0)
        XCTAssertNotNil(orchestrator.latestRecommendations[.training],
                        "Local baseline must always populate latestRecommendations")
    }

    func testProcess_withIncompleteBands_setsInsufficientData() async {
        let engine = StubAIEngineClient()
        let orchestrator = AIOrchestrator(
            engineClient: engine,
            foundationModel: ConfigurableFoundationModel(),
            snapshot: { LocalUserSnapshot() },
            goalMode: { .fatLoss }
        )

        await orchestrator.process(
            segment: .training,
            jwt: "header.payload.signature",
            overrideSnapshot: LocalUserSnapshot()
        )

        let count = await engine.callCount
        XCTAssertEqual(count, 0)
        if case .insufficientData = orchestrator.lastError {
            // Expected
        } else {
            XCTFail("Empty snapshot must surface .insufficientData, got \(String(describing: orchestrator.lastError))")
        }
    }

    // ── Cloud error fallbacks ───────────────────────────

    func testProcess_cloudRateLimited_setsRateLimitedErrorAndUsesLocalBaseline() async {
        let engine = StubAIEngineClient(behavior: .throwError(AIEngineError.rateLimited))
        let orchestrator = AIOrchestrator(
            engineClient: engine,
            foundationModel: ConfigurableFoundationModel(),
            snapshot: { completeTrainingSnapshot() },
            goalMode: { .gain }
        )

        await orchestrator.process(
            segment: .training,
            jwt: "header.payload.signature",
            overrideSnapshot: completeTrainingSnapshot()
        )

        if case .rateLimited = orchestrator.lastError {
            // Expected
        } else {
            XCTFail("rateLimited engine error must map to AIError.rateLimited")
        }
        XCTAssertNotNil(orchestrator.latestRecommendations[.training],
                        "Even after rate-limit, local fallback must surface a recommendation")
    }

    func testProcess_cloudUnauthorised_setsUnauthenticatedError() async {
        let engine = StubAIEngineClient(behavior: .throwError(AIEngineError.unauthorised))
        let orchestrator = AIOrchestrator(
            engineClient: engine,
            foundationModel: ConfigurableFoundationModel(),
            snapshot: { completeTrainingSnapshot() },
            goalMode: { .gain }
        )

        await orchestrator.process(
            segment: .training,
            jwt: "header.payload.signature",
            overrideSnapshot: completeTrainingSnapshot()
        )

        if case .unauthenticated = orchestrator.lastError {
            // Expected
        } else {
            XCTFail("unauthorised engine error must map to AIError.unauthenticated")
        }
    }

    func testProcess_cloudGenericError_setsNetworkError() async {
        struct DummyError: Error {}
        let engine = StubAIEngineClient(behavior: .throwError(DummyError()))
        let orchestrator = AIOrchestrator(
            engineClient: engine,
            foundationModel: ConfigurableFoundationModel(),
            snapshot: { completeTrainingSnapshot() },
            goalMode: { .gain }
        )

        await orchestrator.process(
            segment: .training,
            jwt: "header.payload.signature",
            overrideSnapshot: completeTrainingSnapshot()
        )

        if case .networkError = orchestrator.lastError {
            // Expected
        } else {
            XCTFail("Unknown engine error must map to AIError.networkError")
        }
    }

    // ── Foundation Model adaptation ─────────────────────

    func testProcess_adaptationAboveThreshold_usesAdaptedRecommendation() async {
        // confidence 0.8 > 0.4 threshold → adapted recommendation kept
        let engine = StubAIEngineClient()
        let orchestrator = AIOrchestrator(
            engineClient: engine,
            foundationModel: ConfigurableFoundationModel(
                confidence: 0.8,
                signalsToAppend: ["adapted_marker"]
            ),
            snapshot: { completeTrainingSnapshot() },
            goalMode: { .gain }
        )

        await orchestrator.process(
            segment: .training,
            jwt: "header.payload.signature",
            overrideSnapshot: completeTrainingSnapshot()
        )

        let signals = orchestrator.latestRecommendations[.training]?.signals ?? []
        XCTAssertTrue(signals.contains("adapted_marker"),
                      "Confidence 0.8 must replace base with adapted recommendation. Got: \(signals)")
    }

    func testProcess_adaptationBelowThreshold_keepsBaseRecommendation() async {
        // confidence 0.2 < 0.4 threshold → keep base, drop adapted
        let engine = StubAIEngineClient()
        let orchestrator = AIOrchestrator(
            engineClient: engine,
            foundationModel: ConfigurableFoundationModel(
                confidence: 0.2,
                signalsToAppend: ["adapted_marker"]
            ),
            snapshot: { completeTrainingSnapshot() },
            goalMode: { .gain }
        )

        await orchestrator.process(
            segment: .training,
            jwt: "header.payload.signature",
            overrideSnapshot: completeTrainingSnapshot()
        )

        let signals = orchestrator.latestRecommendations[.training]?.signals ?? []
        XCTAssertFalse(signals.contains("adapted_marker"),
                       "Confidence 0.2 must NOT replace base — adapted signals dropped. Got: \(signals)")
        XCTAssertTrue(signals.contains("cloud_cohort_signal"),
                      "Base cloud signals must remain when adaptation rejected")
    }

    func testProcess_adaptationAtThreshold_usesAdapted() async {
        // confidence == 0.4 boundary → adapted (>= threshold)
        let engine = StubAIEngineClient()
        let orchestrator = AIOrchestrator(
            engineClient: engine,
            foundationModel: ConfigurableFoundationModel(
                confidence: 0.4,
                signalsToAppend: ["boundary_marker"]
            ),
            snapshot: { completeTrainingSnapshot() },
            goalMode: { .gain }
        )

        await orchestrator.process(
            segment: .training,
            jwt: "header.payload.signature",
            overrideSnapshot: completeTrainingSnapshot()
        )

        let signals = orchestrator.latestRecommendations[.training]?.signals ?? []
        XCTAssertTrue(signals.contains("boundary_marker"),
                      "0.4 threshold is inclusive — adapted should be used")
    }

    func testProcess_adaptationThrows_keepsBaseAndDoesNotPropagate() async {
        let engine = StubAIEngineClient()
        let orchestrator = AIOrchestrator(
            engineClient: engine,
            foundationModel: ConfigurableFoundationModel(shouldThrow: true),
            snapshot: { completeTrainingSnapshot() },
            goalMode: { .gain }
        )

        await orchestrator.process(
            segment: .training,
            jwt: "header.payload.signature",
            overrideSnapshot: completeTrainingSnapshot()
        )

        let rec = orchestrator.latestRecommendations[.training]
        XCTAssertNotNil(rec, "Adaptation throwing must not block the base recommendation")
        XCTAssertEqual(rec?.signals.first, "cloud_cohort_signal",
                       "Throwing adapter must fall back to base recommendation")
    }

    // ── Lifecycle ───────────────────────────────────────

    func testIsProcessing_resetsAfterCompletion() async {
        let engine = StubAIEngineClient()
        let orchestrator = AIOrchestrator(
            engineClient: engine,
            foundationModel: ConfigurableFoundationModel(),
            snapshot: { completeTrainingSnapshot() },
            goalMode: { .gain }
        )

        await orchestrator.process(
            segment: .training,
            jwt: "header.payload.signature",
            overrideSnapshot: completeTrainingSnapshot()
        )

        XCTAssertFalse(orchestrator.isProcessing,
                       "isProcessing must reset to false after process() completes")
    }

    func testProcessAll_iteratesEverySegment() async {
        let engine = StubAIEngineClient()
        let orchestrator = AIOrchestrator(
            engineClient: engine,
            foundationModel: ConfigurableFoundationModel(),
            snapshot: { LocalUserSnapshot() },
            goalMode: { .fatLoss }
        )

        await orchestrator.processAll(jwt: nil, snapshot: LocalUserSnapshot())

        // All segments populated with local baselines
        for segment in AISegment.allCases {
            XCTAssertNotNil(
                orchestrator.latestRecommendations[segment],
                "processAll must populate \(segment.rawValue)"
            )
        }
    }

    func testClearRecommendations_resetsState() async {
        let engine = StubAIEngineClient()
        let orchestrator = AIOrchestrator(
            engineClient: engine,
            foundationModel: ConfigurableFoundationModel(),
            snapshot: { completeTrainingSnapshot() },
            goalMode: { .gain }
        )

        await orchestrator.process(
            segment: .training,
            jwt: "header.payload.signature",
            overrideSnapshot: completeTrainingSnapshot()
        )
        XCTAssertNotNil(orchestrator.latestRecommendations[.training])

        orchestrator.clearRecommendations()

        XCTAssertTrue(orchestrator.latestRecommendations.isEmpty,
                      "clearRecommendations must wipe latestRecommendations (sign-out path)")
        XCTAssertNil(orchestrator.lastError)
    }
}
