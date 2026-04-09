import XCTest
@testable import FitTracker

// MARK: - Home Screen Analytics Tests (T17)
// Tests for: home_action_tap, home_action_completed, home_empty_state_shown
// Validates event firing, parameter correctness, and enum raw values.

final class HomeAnalyticsTests: XCTestCase {

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

    // MARK: - Event Firing Tests

    @MainActor
    func testHomeActionTap_startWorkout() {
        analyticsService.logHomeActionTap(
            actionType: "start_workout",
            dayType: "push",
            hasRecommendation: true
        )

        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        let event = mockAdapter.capturedEvents[0]
        XCTAssertEqual(event.name, AnalyticsEvent.homeActionTap)
        XCTAssertEqual(event.name, "home_action_tap")
        XCTAssertEqual(event.parameters?[AnalyticsParam.actionType] as? String, "start_workout")
        XCTAssertEqual(event.parameters?[AnalyticsParam.workoutType] as? String, "push")
        XCTAssertEqual(event.parameters?[AnalyticsParam.hasRecommendation] as? String, "true")
    }

    @MainActor
    func testHomeActionTap_logMeal() {
        analyticsService.logHomeActionTap(
            actionType: "log_meal",
            dayType: "rest",
            hasRecommendation: false
        )

        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        let event = mockAdapter.capturedEvents[0]
        XCTAssertEqual(event.name, AnalyticsEvent.homeActionTap)
        XCTAssertEqual(event.parameters?[AnalyticsParam.actionType] as? String, "log_meal")
        XCTAssertEqual(event.parameters?[AnalyticsParam.workoutType] as? String, "rest")
        XCTAssertEqual(event.parameters?[AnalyticsParam.hasRecommendation] as? String, "false")
    }

    @MainActor
    func testHomeActionCompleted() {
        analyticsService.logHomeActionCompleted(
            actionType: "start_workout",
            durationSeconds: 300
        )

        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        let event = mockAdapter.capturedEvents[0]
        XCTAssertEqual(event.name, AnalyticsEvent.homeActionCompleted)
        XCTAssertEqual(event.name, "home_action_completed")
        XCTAssertEqual(event.parameters?[AnalyticsParam.actionType] as? String, "start_workout")
        XCTAssertEqual(event.parameters?[AnalyticsParam.durationSeconds] as? Int, 300)
        XCTAssertEqual(event.parameters?[AnalyticsParam.source] as? String, "home")
    }

    @MainActor
    func testHomeEmptyStateShown() {
        analyticsService.logHomeEmptyStateShown(
            emptyReason: "no_healthkit",
            ctaShown: "both"
        )

        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        let event = mockAdapter.capturedEvents[0]
        XCTAssertEqual(event.name, AnalyticsEvent.homeEmptyStateShown)
        XCTAssertEqual(event.name, "home_empty_state_shown")
        XCTAssertEqual(event.parameters?[AnalyticsParam.emptyReason] as? String, "no_healthkit")
        XCTAssertEqual(event.parameters?[AnalyticsParam.ctaShown] as? String, "both")
    }

    // MARK: - Enum Existence Tests

    func testHomeEventsExistInEnum() {
        // Verify raw values match the screen-prefixed naming convention
        XCTAssertEqual(AnalyticsEvent.homeActionTap, "home_action_tap")
        XCTAssertEqual(AnalyticsEvent.homeActionCompleted, "home_action_completed")
        XCTAssertEqual(AnalyticsEvent.homeEmptyStateShown, "home_empty_state_shown")
    }

    func testHomeParamsExistInEnum() {
        XCTAssertEqual(AnalyticsParam.actionType, "action_type")
        XCTAssertEqual(AnalyticsParam.hasRecommendation, "has_recommendation")
        XCTAssertEqual(AnalyticsParam.emptyReason, "empty_reason")
        XCTAssertEqual(AnalyticsParam.ctaShown, "cta_shown")
    }

    // MARK: - Home Event Naming Convention Tests

    func testHomeEventsFollowScreenPrefixConvention() {
        // All home events must start with "home_" per analytics naming convention
        let homeEvents = [
            AnalyticsEvent.homeActionTap,
            AnalyticsEvent.homeActionCompleted,
            AnalyticsEvent.homeEmptyStateShown,
        ]

        for event in homeEvents {
            XCTAssertTrue(event.hasPrefix("home_"), "Event '\(event)' missing home_ prefix")
            XCTAssertTrue(event.count <= 40, "Event '\(event)' exceeds 40 chars")
            XCTAssertEqual(event, event.lowercased(), "Event '\(event)' is not lowercase")
            XCTAssertFalse(event.contains(" "), "Event '\(event)' contains spaces")
            XCTAssertFalse(event.hasPrefix("ga_"), "Event '\(event)' uses reserved prefix")
            XCTAssertFalse(event.hasPrefix("firebase_"), "Event '\(event)' uses reserved prefix")
        }
    }

    func testHomeActionCompletedIsConversionEvent() {
        // home_action_completed must be registered as a conversion event
        XCTAssertTrue(
            AnalyticsConversion.events.contains(AnalyticsEvent.homeActionCompleted),
            "home_action_completed should be in AnalyticsConversion.events"
        )
    }

    // MARK: - Consent Gating Tests

    @MainActor
    func testHomeEventsBlockedWhenConsentDenied() {
        consentManager.denyConsent()
        analyticsService.syncConsentToProvider()

        analyticsService.logHomeActionTap(actionType: "start_workout", dayType: "push", hasRecommendation: true)
        analyticsService.logHomeActionCompleted(actionType: "start_workout", durationSeconds: 300)
        analyticsService.logHomeEmptyStateShown(emptyReason: "no_healthkit", ctaShown: "both")

        XCTAssertEqual(mockAdapter.capturedEvents.count, 0, "Home events should not fire when consent is denied")
    }

    @MainActor
    func testHomeEventsFlowAfterConsentGranted() {
        // Start denied
        consentManager.denyConsent()
        analyticsService.syncConsentToProvider()
        analyticsService.logHomeActionTap(actionType: "start_workout", dayType: "push", hasRecommendation: true)
        XCTAssertEqual(mockAdapter.capturedEvents.count, 0)

        // Grant consent and retry
        consentManager.regrantConsent()
        analyticsService.syncConsentToProvider()
        analyticsService.logHomeActionTap(actionType: "log_meal", dayType: "rest", hasRecommendation: false)
        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        XCTAssertEqual(mockAdapter.capturedEvents[0].name, AnalyticsEvent.homeActionTap)
    }

    // MARK: - Parameter Validation Tests

    func testHomeParameterNameConventions() {
        let homeParams = [
            AnalyticsParam.actionType,
            AnalyticsParam.hasRecommendation,
            AnalyticsParam.emptyReason,
            AnalyticsParam.ctaShown,
        ]

        for param in homeParams {
            XCTAssertTrue(param.count <= 40, "Param '\(param)' exceeds 40 chars")
            XCTAssertEqual(param, param.lowercased(), "Param '\(param)' is not lowercase")
            XCTAssertFalse(param.contains(" "), "Param '\(param)' contains spaces")
        }
    }
}
