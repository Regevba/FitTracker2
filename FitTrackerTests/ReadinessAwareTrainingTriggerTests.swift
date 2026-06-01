// FitTrackerTests/ReadinessAwareTrainingTriggerTests.swift
// C2 feature: readiness-aware-training-alert (parent: smart-reminders).
//
// Pure-function decision-rule coverage. No mocks, no UserDefaults, no
// async — every test inputs a fully-specified ReadinessResult + DayType
// pair and asserts the output ReadinessAlertContext shape.

import XCTest
@testable import FitTracker

@MainActor
final class ReadinessAwareTrainingTriggerTests: XCTestCase {

    private let referenceTime = Date(timeIntervalSince1970: 1_780_000_000) // 2026-06-04 ~ 20:26 UTC

    // MARK: - Rule 1: rest-day suppression

    func test_restDay_returnsNil() {
        let result = makeResult(score: 50, confidence: .medium, flags: [])
        let context = ReadinessAwareTrainingTrigger.evaluate(
            readinessResult: result,
            scheduledDayType: .restDay,
            suggestedRestSwapTarget: nil,
            scheduledTrainingTime: referenceTime,
            generatedAt: referenceTime
        )
        XCTAssertNil(context, "Rest day should never produce an advisory alert")
    }

    // MARK: - Rule 2: continueAsPlanned (high score + non-low confidence)

    func test_highScoreMediumConfidence_returnsContinue() {
        let result = makeResult(score: 80, confidence: .medium, flags: [])
        let context = ReadinessAwareTrainingTrigger.evaluate(
            readinessResult: result,
            scheduledDayType: .upperPush,
            suggestedRestSwapTarget: .restDay,
            scheduledTrainingTime: referenceTime,
            generatedAt: referenceTime
        )
        XCTAssertEqual(context?.recommendation, .continueAsPlanned)
        XCTAssertEqual(context?.scheduledDayType, .upperPush)
        XCTAssertNil(context?.suggestedSwapDayType, "continueAsPlanned should not carry a swap target")
    }

    func test_highScoreHighConfidence_returnsContinue() {
        let result = makeResult(score: 75, confidence: .high, flags: [])
        let context = ReadinessAwareTrainingTrigger.evaluate(
            readinessResult: result,
            scheduledDayType: .lowerBody,
            suggestedRestSwapTarget: nil,
            scheduledTrainingTime: referenceTime,
            generatedAt: referenceTime
        )
        XCTAssertEqual(context?.recommendation, .continueAsPlanned)
    }

    // MARK: - Rule 3: restDaySwap (very low score + adverse flag)

    func test_lowScoreWithFlag_returnsRestSwap() {
        let result = makeResult(score: 30, confidence: .medium, flags: [.hydrationWarning])
        let context = ReadinessAwareTrainingTrigger.evaluate(
            readinessResult: result,
            scheduledDayType: .upperPush,
            suggestedRestSwapTarget: .restDay,
            scheduledTrainingTime: referenceTime,
            generatedAt: referenceTime
        )
        XCTAssertEqual(context?.recommendation, .restDaySwap)
        XCTAssertEqual(context?.suggestedSwapDayType, .restDay)
    }

    func test_lowScoreNoFlag_returnsAdaptNotSwap() {
        // Score ≤ adaptThreshold without adverse flag → adaptEasierLoad
        let result = makeResult(score: 30, confidence: .medium, flags: [])
        let context = ReadinessAwareTrainingTrigger.evaluate(
            readinessResult: result,
            scheduledDayType: .upperPush,
            suggestedRestSwapTarget: .restDay,
            scheduledTrainingTime: referenceTime,
            generatedAt: referenceTime
        )
        XCTAssertEqual(context?.recommendation, .adaptEasierLoad,
                       "Low score without adverse flag should adapt, not swap")
    }

    // MARK: - Rule 4: adaptEasierLoad

    func test_borderlineScore_returnsAdapt() {
        let result = makeResult(score: 48, confidence: .medium, flags: [])
        let context = ReadinessAwareTrainingTrigger.evaluate(
            readinessResult: result,
            scheduledDayType: .fullBody,
            suggestedRestSwapTarget: nil,
            scheduledTrainingTime: referenceTime,
            generatedAt: referenceTime
        )
        XCTAssertEqual(context?.recommendation, .adaptEasierLoad)
    }

    func test_anyFlag_pushesIntoAdapt() {
        // High score (70) but presence of visceralTrend flag still triggers adapt
        let result = makeResult(score: 70, confidence: .high, flags: [.visceralTrend])
        let context = ReadinessAwareTrainingTrigger.evaluate(
            readinessResult: result,
            scheduledDayType: .cardioOnly,
            suggestedRestSwapTarget: nil,
            scheduledTrainingTime: referenceTime,
            generatedAt: referenceTime
        )
        XCTAssertEqual(context?.recommendation, .adaptEasierLoad)
    }

    // MARK: - Rule 5: nil for borderline + low confidence (avoid noise)

    func test_borderlineScoreLowConfidence_returnsNil() {
        let result = makeResult(score: 58, confidence: .low, flags: [])
        let context = ReadinessAwareTrainingTrigger.evaluate(
            readinessResult: result,
            scheduledDayType: .upperPush,
            suggestedRestSwapTarget: nil,
            scheduledTrainingTime: referenceTime,
            generatedAt: referenceTime
        )
        XCTAssertNil(context, "Borderline score with low confidence should not surface")
    }

    func test_highScoreLowConfidence_returnsNil() {
        let result = makeResult(score: 80, confidence: .low, flags: [])
        let context = ReadinessAwareTrainingTrigger.evaluate(
            readinessResult: result,
            scheduledDayType: .upperPush,
            suggestedRestSwapTarget: nil,
            scheduledTrainingTime: referenceTime,
            generatedAt: referenceTime
        )
        XCTAssertNil(context, "Low confidence suppresses even a high score")
    }

    // MARK: - Driving component

    func test_drivingComponent_lowestComponentSurfaces() {
        // HRV is by far the lowest of the four → surfaced as driver
        let result = makeResult(
            score: 45,
            confidence: .medium,
            flags: [],
            hrv: 20, sleep: 70, rhr: 75, training: 80
        )
        let context = ReadinessAwareTrainingTrigger.evaluate(
            readinessResult: result,
            scheduledDayType: .upperPush,
            suggestedRestSwapTarget: nil,
            scheduledTrainingTime: referenceTime,
            generatedAt: referenceTime
        )
        XCTAssertEqual(context?.drivingComponent, .hrv)
    }

    func test_drivingComponent_evenSpreadReturnsComposite() {
        // All four within ~15-point spread → composite
        let result = makeResult(
            score: 45,
            confidence: .medium,
            flags: [],
            hrv: 50, sleep: 55, rhr: 52, training: 48
        )
        let context = ReadinessAwareTrainingTrigger.evaluate(
            readinessResult: result,
            scheduledDayType: .upperPush,
            suggestedRestSwapTarget: nil,
            scheduledTrainingTime: referenceTime,
            generatedAt: referenceTime
        )
        XCTAssertEqual(context?.drivingComponent, .composite)
    }

    // MARK: - Component breakdown preservation

    func test_breakdownPopulatedFromResult() {
        let result = makeResult(
            score: 40,
            confidence: .medium,
            flags: [.hydrationWarning],
            hrv: 35, sleep: 50, rhr: 60, training: 65
        )
        let context = ReadinessAwareTrainingTrigger.evaluate(
            readinessResult: result,
            scheduledDayType: .upperPush,
            suggestedRestSwapTarget: nil,
            scheduledTrainingTime: referenceTime,
            generatedAt: referenceTime
        )
        XCTAssertEqual(context?.componentBreakdown.hrvScore,          35)
        XCTAssertEqual(context?.componentBreakdown.sleepScore,        50)
        XCTAssertEqual(context?.componentBreakdown.restingHRScore,    60)
        XCTAssertEqual(context?.componentBreakdown.trainingLoadScore, 65)
        XCTAssertEqual(context?.componentBreakdown.bodyCompFlagCount, 1)
    }

    func test_recommendationEnumExhaustiveness() {
        // Compile-time guard against silently adding a new case
        for recommendation in ReadinessAlertRecommendation.allCases {
            switch recommendation {
            case .continueAsPlanned: XCTAssertEqual(recommendation.primaryCTA, "Train now")
            case .adaptEasierLoad:   XCTAssertEqual(recommendation.primaryCTA, "Lighten")
            case .restDaySwap:       XCTAssertEqual(recommendation.primaryCTA, "Swap to rest")
            }
        }
    }

    // MARK: - Helpers

    private func makeResult(
        score: Int,
        confidence: ReadinessConfidence,
        flags: [BodyCompFlag],
        hrv: Double = 70,
        sleep: Double = 70,
        rhr: Double = 70,
        training: Double = 70
    ) -> ReadinessResult {
        ReadinessResult(
            overallScore: score,
            hrvScore: hrv,
            sleepScore: sleep,
            trainingLoadScore: training,
            rhrScore: rhr,
            bodyCompFlags: flags,
            confidence: confidence,
            personalizationLayer: 2,
            goalMode: .maintain,
            appliedWeights: [:],
            warnings: [],
            recommendation: .moderate
        )
    }
}
