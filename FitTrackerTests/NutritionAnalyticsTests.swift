import XCTest
@testable import FitTracker

// MARK: - Nutrition v2 Analytics Tests
// Tests for: 5 screen-prefixed nutrition events, consent gating, parameter validation

final class NutritionAnalyticsTests: XCTestCase {

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
    func testNutritionMealLoggedEvent() {
        analyticsService.logNutritionMealLogged(mealType: "breakfast", entryMethod: "manual", calories: 520)

        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        let event = mockAdapter.capturedEvents[0]
        XCTAssertEqual(event.name, AnalyticsEvent.nutritionMealLogged)
        XCTAssertEqual(event.parameters?[AnalyticsParam.mealType] as? String, "breakfast")
        XCTAssertEqual(event.parameters?[AnalyticsParam.entryMethod] as? String, "manual")
        XCTAssertEqual(event.parameters?[AnalyticsParam.calories] as? Int, 520)
    }

    @MainActor
    func testNutritionSupplementLoggedEvent() {
        analyticsService.logNutritionSupplementLogged(timeOfDay: "morning", supplementCount: 5)

        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        let event = mockAdapter.capturedEvents[0]
        XCTAssertEqual(event.name, AnalyticsEvent.nutritionSupplementLogged)
        XCTAssertEqual(event.parameters?[AnalyticsParam.timeOfDay] as? String, "morning")
        XCTAssertEqual(event.parameters?[AnalyticsParam.supplementCount] as? Int, 5)
    }

    @MainActor
    func testNutritionHydrationUpdatedEvent() {
        analyticsService.logNutritionHydrationUpdated(waterMl: 1500, targetMl: 2800)

        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        let event = mockAdapter.capturedEvents[0]
        XCTAssertEqual(event.name, AnalyticsEvent.nutritionHydrationUpdated)
        XCTAssertEqual(event.parameters?[AnalyticsParam.waterMl] as? Int, 1500)
        XCTAssertEqual(event.parameters?[AnalyticsParam.targetMl] as? Int, 2800)
    }

    @MainActor
    func testNutritionDateChangedEvent() {
        analyticsService.logNutritionDateChanged(direction: "forward")

        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        let event = mockAdapter.capturedEvents[0]
        XCTAssertEqual(event.name, AnalyticsEvent.nutritionDateChanged)
        XCTAssertEqual(event.parameters?[AnalyticsParam.direction] as? String, "forward")
    }

    @MainActor
    func testNutritionEmptyStateShownEvent() {
        analyticsService.logNutritionEmptyStateShown(section: "meals")

        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        let event = mockAdapter.capturedEvents[0]
        XCTAssertEqual(event.name, AnalyticsEvent.nutritionEmptyStateShown)
        XCTAssertEqual(event.parameters?[AnalyticsParam.section] as? String, "meals")
    }

    // MARK: - Consent Gating

    @MainActor
    func testNutritionEventsBlockedWithoutConsent() {
        consentManager.denyConsent()

        analyticsService.logNutritionMealLogged(mealType: "lunch", entryMethod: "template", calories: 680)
        analyticsService.logNutritionSupplementLogged(timeOfDay: "evening", supplementCount: 3)
        analyticsService.logNutritionHydrationUpdated(waterMl: 500, targetMl: 2800)

        XCTAssertEqual(mockAdapter.capturedEvents.count, 0, "No events should fire when consent is denied")
    }

    // MARK: - Screen-Prefix Naming Convention

    @MainActor
    func testAllNutritionEventsHaveScreenPrefix() {
        let nutritionEvents = [
            AnalyticsEvent.nutritionMealLogged,
            AnalyticsEvent.nutritionSupplementLogged,
            AnalyticsEvent.nutritionHydrationUpdated,
            AnalyticsEvent.nutritionDateChanged,
            AnalyticsEvent.nutritionEmptyStateShown,
        ]

        for event in nutritionEvents {
            XCTAssertTrue(event.hasPrefix("nutrition_"), "Event '\(event)' must start with 'nutrition_' per CLAUDE.md naming convention")
        }
    }
}
