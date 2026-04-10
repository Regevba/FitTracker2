import XCTest
@testable import FitTracker

// MARK: - AI + Readiness Analytics Tests
// Tests for all 9 new events: readiness (3) + AI recommendation (6).
// Validates event names, parameter values, and consent gating.

final class AIAnalyticsTests: XCTestCase {

    private var mockAdapter: MockAnalyticsAdapter!
    private var consentManager: ConsentManager!
    private var analyticsService: AnalyticsService!

    @MainActor
    override func setUp() {
        super.setUp()
        mockAdapter = MockAnalyticsAdapter()
        consentManager = ConsentManager()
        consentManager.grantConsent()
        analyticsService = AnalyticsService(provider: mockAdapter, consent: consentManager)
    }

    @MainActor
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "ft.analytics.gdprConsent")
        UserDefaults.standard.removeObject(forKey: "ft.analytics.consentDate")
        UserDefaults.standard.removeObject(forKey: "ft.analytics.hasBeenAsked")
        mockAdapter.reset()
        super.tearDown()
    }

    // MARK: - Readiness Events

    @MainActor
    func testReadinessScoreComputed() {
        analyticsService.logReadinessScoreComputed(score: 82, confidence: "high", layer: 2, goalMode: "fatLoss", componentCount: 5)
        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        let event = mockAdapter.capturedEvents[0]
        XCTAssertEqual(event.name, AnalyticsEvent.homeReadinessScoreComputed)
        XCTAssertEqual(event.name, "home_readiness_score_computed")
        XCTAssertEqual(event.parameters?[AnalyticsParam.score] as? Int, 82)
        XCTAssertEqual(event.parameters?[AnalyticsParam.confidence] as? String, "high")
        XCTAssertEqual(event.parameters?[AnalyticsParam.layer] as? Int, 2)
        XCTAssertEqual(event.parameters?[AnalyticsParam.goalMode] as? String, "fatLoss")
        XCTAssertEqual(event.parameters?[AnalyticsParam.componentCount] as? Int, 5)
    }

    @MainActor
    func testReadinessComponentTap() {
        analyticsService.logReadinessComponentTap(component: "hrv")
        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        let event = mockAdapter.capturedEvents[0]
        XCTAssertEqual(event.name, AnalyticsEvent.homeReadinessComponentTap)
        XCTAssertEqual(event.name, "home_readiness_component_tap")
        XCTAssertEqual(event.parameters?[AnalyticsParam.component] as? String, "hrv")
    }

    @MainActor
    func testReadinessRecommendationShown() {
        analyticsService.logReadinessRecommendationShown(recommendation: "fullIntensity")
        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        let event = mockAdapter.capturedEvents[0]
        XCTAssertEqual(event.name, AnalyticsEvent.homeReadinessRecommendationShown)
        XCTAssertEqual(event.name, "home_readiness_recommendation_shown")
        XCTAssertEqual(event.parameters?[AnalyticsParam.recommendation] as? String, "fullIntensity")
    }

    // MARK: - AI Recommendation Events

    @MainActor
    func testAiInsightShown() {
        analyticsService.logAiInsightShown(segment: "training", confidence: "high", sourceTier: "cloud")
        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        let event = mockAdapter.capturedEvents[0]
        XCTAssertEqual(event.name, AnalyticsEvent.homeAiInsightShown)
        XCTAssertEqual(event.name, "home_ai_insight_shown")
        XCTAssertEqual(event.parameters?[AnalyticsParam.segment] as? String, "training")
        XCTAssertEqual(event.parameters?[AnalyticsParam.confidence] as? String, "high")
        XCTAssertEqual(event.parameters?[AnalyticsParam.sourceTier] as? String, "cloud")
    }

    @MainActor
    func testAiInsightTap() {
        analyticsService.logAiInsightTap(segment: "recovery")
        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        let event = mockAdapter.capturedEvents[0]
        XCTAssertEqual(event.name, AnalyticsEvent.homeAiInsightTap)
        XCTAssertEqual(event.name, "home_ai_insight_tap")
        XCTAssertEqual(event.parameters?[AnalyticsParam.segment] as? String, "recovery")
    }

    @MainActor
    func testAiSheetOpened() {
        analyticsService.logAiSheetOpened(entryPoint: "insight_card")
        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        let event = mockAdapter.capturedEvents[0]
        XCTAssertEqual(event.name, AnalyticsEvent.aiSheetOpened)
        XCTAssertEqual(event.name, "ai_sheet_opened")
        XCTAssertEqual(event.parameters?[AnalyticsParam.entryPoint] as? String, "insight_card")
    }

    @MainActor
    func testAiRecommendationViewed() {
        analyticsService.logAiRecommendationViewed(segment: "nutrition", confidence: "medium")
        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        let event = mockAdapter.capturedEvents[0]
        XCTAssertEqual(event.name, AnalyticsEvent.aiRecommendationViewed)
        XCTAssertEqual(event.name, "ai_recommendation_viewed")
        XCTAssertEqual(event.parameters?[AnalyticsParam.segment] as? String, "nutrition")
        XCTAssertEqual(event.parameters?[AnalyticsParam.confidence] as? String, "medium")
    }

    @MainActor
    func testAiFeedbackSubmitted() {
        analyticsService.logAiFeedbackSubmitted(segment: "training", rating: "positive")
        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        let event = mockAdapter.capturedEvents[0]
        XCTAssertEqual(event.name, AnalyticsEvent.aiFeedbackSubmitted)
        XCTAssertEqual(event.name, "ai_feedback_submitted")
        XCTAssertEqual(event.parameters?[AnalyticsParam.segment] as? String, "training")
        XCTAssertEqual(event.parameters?[AnalyticsParam.rating] as? String, "positive")
    }

    @MainActor
    func testAiAvatarStateChanged() {
        analyticsService.logAiAvatarStateChanged(fromState: "breathe", toState: "pulse")
        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        let event = mockAdapter.capturedEvents[0]
        XCTAssertEqual(event.name, AnalyticsEvent.aiAvatarStateChanged)
        XCTAssertEqual(event.name, "ai_avatar_state_changed")
        XCTAssertEqual(event.parameters?[AnalyticsParam.fromState] as? String, "breathe")
        XCTAssertEqual(event.parameters?[AnalyticsParam.toState] as? String, "pulse")
    }

    // MARK: - Enum Existence Tests

    func testReadinessEventsExistInEnum() {
        XCTAssertEqual(AnalyticsEvent.homeReadinessScoreComputed, "home_readiness_score_computed")
        XCTAssertEqual(AnalyticsEvent.homeReadinessComponentTap, "home_readiness_component_tap")
        XCTAssertEqual(AnalyticsEvent.homeReadinessRecommendationShown, "home_readiness_recommendation_shown")
    }

    func testAiEventsExistInEnum() {
        XCTAssertEqual(AnalyticsEvent.homeAiInsightShown, "home_ai_insight_shown")
        XCTAssertEqual(AnalyticsEvent.homeAiInsightTap, "home_ai_insight_tap")
        XCTAssertEqual(AnalyticsEvent.aiSheetOpened, "ai_sheet_opened")
        XCTAssertEqual(AnalyticsEvent.aiRecommendationViewed, "ai_recommendation_viewed")
        XCTAssertEqual(AnalyticsEvent.aiFeedbackSubmitted, "ai_feedback_submitted")
        XCTAssertEqual(AnalyticsEvent.aiAvatarStateChanged, "ai_avatar_state_changed")
    }

    func testReadinessParamsExistInEnum() {
        XCTAssertEqual(AnalyticsParam.score, "score")
        XCTAssertEqual(AnalyticsParam.confidence, "confidence")
        XCTAssertEqual(AnalyticsParam.layer, "layer")
        XCTAssertEqual(AnalyticsParam.goalMode, "goal_mode")
        XCTAssertEqual(AnalyticsParam.componentCount, "component_count")
        XCTAssertEqual(AnalyticsParam.component, "component")
        XCTAssertEqual(AnalyticsParam.recommendation, "recommendation")
    }

    func testAiParamsExistInEnum() {
        XCTAssertEqual(AnalyticsParam.segment, "segment")
        XCTAssertEqual(AnalyticsParam.sourceTier, "source_tier")
        XCTAssertEqual(AnalyticsParam.entryPoint, "entry_point")
        XCTAssertEqual(AnalyticsParam.rating, "rating")
        XCTAssertEqual(AnalyticsParam.fromState, "from_state")
        XCTAssertEqual(AnalyticsParam.toState, "to_state")
    }

    // MARK: - Naming Convention Tests

    func testReadinessEventsFollowScreenPrefixConvention() {
        let readinessEvents = [
            AnalyticsEvent.homeReadinessScoreComputed,
            AnalyticsEvent.homeReadinessComponentTap,
            AnalyticsEvent.homeReadinessRecommendationShown,
        ]
        for event in readinessEvents {
            XCTAssertTrue(event.hasPrefix("home_"), "Event '\(event)' missing home_ prefix")
            XCTAssertTrue(event.count <= 40, "Event '\(event)' exceeds 40 chars")
            XCTAssertEqual(event, event.lowercased(), "Event '\(event)' is not lowercase")
            XCTAssertFalse(event.contains(" "), "Event '\(event)' contains spaces")
        }
    }

    func testHomeAiEventsFollowScreenPrefixConvention() {
        let homeAiEvents = [
            AnalyticsEvent.homeAiInsightShown,
            AnalyticsEvent.homeAiInsightTap,
        ]
        for event in homeAiEvents {
            XCTAssertTrue(event.hasPrefix("home_"), "Event '\(event)' missing home_ prefix")
            XCTAssertTrue(event.count <= 40, "Event '\(event)' exceeds 40 chars")
            XCTAssertEqual(event, event.lowercased(), "Event '\(event)' is not lowercase")
            XCTAssertFalse(event.contains(" "), "Event '\(event)' contains spaces")
        }
    }

    // MARK: - Consent Gating Tests

    @MainActor
    func testAiEventsBlockedWhenConsentDenied() {
        consentManager.denyConsent()
        analyticsService.syncConsentToProvider()

        analyticsService.logReadinessScoreComputed(score: 75, confidence: "medium", layer: 1, goalMode: "maintain", componentCount: 4)
        analyticsService.logReadinessComponentTap(component: "sleep")
        analyticsService.logReadinessRecommendationShown(recommendation: "moderate")
        analyticsService.logAiInsightShown(segment: "training", confidence: "high", sourceTier: "local")
        analyticsService.logAiInsightTap(segment: "training")
        analyticsService.logAiSheetOpened(entryPoint: "more_button")
        analyticsService.logAiRecommendationViewed(segment: "recovery", confidence: "low")
        analyticsService.logAiFeedbackSubmitted(segment: "nutrition", rating: "negative")
        analyticsService.logAiAvatarStateChanged(fromState: "rotate", toState: "shimmer")

        XCTAssertEqual(mockAdapter.capturedEvents.count, 0, "AI/Readiness events should not fire when consent is denied")
    }
}
