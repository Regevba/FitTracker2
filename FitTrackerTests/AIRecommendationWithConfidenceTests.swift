// FitTrackerTests/AIRecommendationWithConfidenceTests.swift
// C5 ai-user-feedback-loop T12 — withConfidence extension purity.

import XCTest
@testable import FitTracker

final class AIRecommendationWithConfidenceTests: XCTestCase {

    func testWithConfidenceReturnsNewInstanceWithUpdatedValue() {
        let original = AIRecommendation(
            segment: AISegment.training.rawValue,
            signals: ["a", "b"],
            confidence: 0.9,
            escalateToLLM: false,
            supportingData: [:]
        )
        let modified = original.withConfidence(0.5)
        XCTAssertEqual(modified.confidence, 0.5)
        // Other fields preserved
        XCTAssertEqual(modified.segment, original.segment)
        XCTAssertEqual(modified.signals, original.signals)
        XCTAssertEqual(modified.escalateToLLM, original.escalateToLLM)
        // Source untouched (struct semantics)
        XCTAssertEqual(original.confidence, 0.9)
    }
}
