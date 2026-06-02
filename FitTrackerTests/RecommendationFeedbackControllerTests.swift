// FitTrackerTests/RecommendationFeedbackControllerTests.swift
// C5 ai-user-feedback-loop T12.B — controller facade behavior.

import XCTest
@testable import FitTracker

@MainActor
final class RecommendationFeedbackControllerTests: XCTestCase {

    private let storageKey = "fitme.ai.recommendation_memory"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: storageKey)
        super.tearDown()
    }

    /// Fresh controller reads totalCount from its memory at init.
    func testInitReadsTotalCount() {
        let memory = RecommendationMemory()
        memory.record(outcome: RecommendationOutcome(
            segment: AISegment.training.rawValue,
            signals: ["x"],
            confidenceLevel: "high",
            source: "cloud",
            action: .accepted
        ))
        let controller = RecommendationFeedbackController(memory: memory)
        XCTAssertEqual(controller.totalCount, 1)
    }

    /// record(outcome:) bumps the published totalCount.
    func testRecordIncrementsPublishedCount() {
        let controller = RecommendationFeedbackController()
        XCTAssertEqual(controller.totalCount, 0)
        controller.record(outcome: RecommendationOutcome(
            segment: AISegment.recovery.rawValue,
            signals: ["sleep_deprivation"],
            confidenceLevel: "medium",
            source: "local",
            action: .dismissed,
            dismissReason: "already_aware"
        ))
        XCTAssertEqual(controller.totalCount, 1)
        controller.record(outcome: RecommendationOutcome(
            segment: AISegment.recovery.rawValue,
            signals: ["elevated_resting_hr"],
            confidenceLevel: "low",
            source: "local",
            action: .ignored
        ))
        XCTAssertEqual(controller.totalCount, 2)
    }

    /// clearAll resets totalCount + drops all outcomes from underlying memory.
    func testClearAllResetsCount() {
        let controller = RecommendationFeedbackController()
        for i in 0..<4 {
            controller.record(outcome: RecommendationOutcome(
                segment: AISegment.nutrition.rawValue,
                signals: ["protein_below_\(i)"],
                confidenceLevel: "medium",
                source: "local",
                action: .dismissed
            ))
        }
        XCTAssertEqual(controller.totalCount, 4)
        controller.clearAll()
        XCTAssertEqual(controller.totalCount, 0)
        XCTAssertTrue(controller.outcomes(for: .nutrition).isEmpty)
    }

    /// Per-segment queries pass through to RecommendationMemory.
    func testPerSegmentQueriesPassThrough() {
        let controller = RecommendationFeedbackController()
        for _ in 0..<5 {
            controller.record(outcome: RecommendationOutcome(
                segment: AISegment.training.rawValue,
                signals: ["s"],
                confidenceLevel: "high",
                source: "cloud",
                action: .accepted
            ))
        }
        // acceptanceRate returns 1.0 (5/5 accepted, all in training)
        XCTAssertEqual(controller.acceptanceRate(for: .training), 1.0)
        XCTAssertEqual(controller.outcomes(for: .training).count, 5)
        // Other segment is empty
        XCTAssertNil(controller.acceptanceRate(for: .recovery))
        XCTAssertTrue(controller.outcomes(for: .recovery).isEmpty)
    }
}
