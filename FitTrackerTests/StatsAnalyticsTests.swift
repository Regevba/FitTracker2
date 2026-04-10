import XCTest
@testable import FitTracker

final class StatsAnalyticsTests: XCTestCase {

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

    @MainActor
    func testStatsPeriodChangedEvent() {
        analyticsService.logStatsPeriodChanged(period: "monthly")

        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        let event = mockAdapter.capturedEvents[0]
        XCTAssertEqual(event.name, AnalyticsEvent.statsPeriodChanged)
        XCTAssertEqual(event.parameters?[AnalyticsParam.period] as? String, "monthly")
    }

    @MainActor
    func testStatsMetricSelectedEvent() {
        analyticsService.logStatsMetricSelected(metricName: "weight", category: "body")

        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        let event = mockAdapter.capturedEvents[0]
        XCTAssertEqual(event.name, AnalyticsEvent.statsMetricSelected)
        XCTAssertEqual(event.parameters?[AnalyticsParam.metricName] as? String, "weight")
        XCTAssertEqual(event.parameters?[AnalyticsParam.category] as? String, "body")
    }

    @MainActor
    func testStatsChartInteractionEvent() {
        analyticsService.logStatsChartInteraction(metricName: "hrv", interactionType: "drag")

        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        let event = mockAdapter.capturedEvents[0]
        XCTAssertEqual(event.name, AnalyticsEvent.statsChartInteraction)
        XCTAssertEqual(event.parameters?[AnalyticsParam.metricName] as? String, "hrv")
        XCTAssertEqual(event.parameters?[AnalyticsParam.interactionType] as? String, "drag")
    }

    @MainActor
    func testStatsEmptyStateShownEvent() {
        analyticsService.logStatsEmptyStateShown(metricName: "trainingVolume")

        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        let event = mockAdapter.capturedEvents[0]
        XCTAssertEqual(event.name, AnalyticsEvent.statsEmptyStateShown)
        XCTAssertEqual(event.parameters?[AnalyticsParam.metricName] as? String, "trainingVolume")
    }

    @MainActor
    func testStatsEventsBlockedWithoutConsent() {
        consentManager.denyConsent()

        analyticsService.logStatsPeriodChanged(period: "weekly")
        analyticsService.logStatsMetricSelected(metricName: "sleep", category: "recovery")

        XCTAssertEqual(mockAdapter.capturedEvents.count, 0)
    }

    @MainActor
    func testAllStatsEventsHaveScreenPrefix() {
        let events = [
            AnalyticsEvent.statsPeriodChanged,
            AnalyticsEvent.statsMetricSelected,
            AnalyticsEvent.statsChartInteraction,
            AnalyticsEvent.statsEmptyStateShown,
        ]

        for event in events {
            XCTAssertTrue(event.hasPrefix("stats_"), "Event '\(event)' must start with 'stats_'")
        }
    }
}
