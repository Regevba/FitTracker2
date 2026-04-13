import XCTest
@testable import FitTracker

// MARK: - Profile Screen Analytics Tests (T10)
// Tests for: profile_tab_viewed, profile_goal_changed, profile_settings_section_opened,
//            profile_readiness_tap, profile_body_comp_tap, profile_avatar_tap
// Validates event firing, parameter correctness, and consent gating.

final class ProfileAnalyticsTests: XCTestCase {

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
    func testProfileTabViewed() {
        analyticsService.logProfileTabViewed(source: "tab_bar")

        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        let event = mockAdapter.capturedEvents[0]
        XCTAssertEqual(event.name, "profile_tab_viewed")
        XCTAssertEqual(event.parameters?[AnalyticsParam.source] as? String, "tab_bar")
    }

    @MainActor
    func testProfileGoalChanged() {
        analyticsService.logProfileGoalChanged(
            field: "fitness_goal",
            oldValue: "lose_fat",
            newValue: "build_muscle"
        )

        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        let event = mockAdapter.capturedEvents[0]
        XCTAssertEqual(event.name, "profile_goal_changed")
        XCTAssertEqual(event.parameters?[AnalyticsParam.field] as? String, "fitness_goal")
        XCTAssertEqual(event.parameters?[AnalyticsParam.oldValue] as? String, "lose_fat")
        XCTAssertEqual(event.parameters?[AnalyticsParam.newValue] as? String, "build_muscle")
    }

    @MainActor
    func testProfileSettingsSectionOpened() {
        analyticsService.logProfileSettingsSectionOpened(section: "goals")

        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        let event = mockAdapter.capturedEvents[0]
        XCTAssertEqual(event.name, "profile_settings_section_opened")
        XCTAssertEqual(event.parameters?[AnalyticsParam.section] as? String, "goals")
    }

    @MainActor
    func testProfileReadinessTap() {
        analyticsService.logProfileReadinessTap()

        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        let event = mockAdapter.capturedEvents[0]
        XCTAssertEqual(event.name, "profile_readiness_tap")
        XCTAssertNil(event.parameters)
    }

    @MainActor
    func testProfileBodyCompTap() {
        analyticsService.logProfileBodyCompTap()

        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        let event = mockAdapter.capturedEvents[0]
        XCTAssertEqual(event.name, "profile_body_comp_tap")
    }

    @MainActor
    func testProfileAvatarTap() {
        analyticsService.logProfileAvatarTap()

        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        let event = mockAdapter.capturedEvents[0]
        XCTAssertEqual(event.name, "profile_avatar_tap")
    }

    // MARK: - Consent Gating Tests

    @MainActor
    func testProfileEventsBlockedWithoutConsent() {
        consentManager.denyConsent()
        analyticsService.syncConsentToProvider()

        analyticsService.logProfileTabViewed(source: "tab_bar")
        analyticsService.logProfileGoalChanged(field: "fitness_goal", oldValue: "lose_fat", newValue: "build_muscle")
        analyticsService.logProfileSettingsSectionOpened(section: "goals")
        analyticsService.logProfileReadinessTap()
        analyticsService.logProfileBodyCompTap()
        analyticsService.logProfileAvatarTap()

        XCTAssertEqual(mockAdapter.capturedEvents.count, 0, "Profile events should not fire when consent is denied")
    }
}
