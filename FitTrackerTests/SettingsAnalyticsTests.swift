import XCTest
@testable import FitTracker

final class SettingsAnalyticsTests: XCTestCase {

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
    func testSettingsSyncTriggeredEvent() {
        analyticsService.logSettingsSyncTriggered(syncType: "push")

        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        let event = mockAdapter.capturedEvents[0]
        XCTAssertEqual(event.name, AnalyticsEvent.settingsSyncTriggered)
        XCTAssertEqual(event.parameters?[AnalyticsParam.syncType] as? String, "push")
    }

    @MainActor
    func testSettingsConsentUpdatedEvent() {
        analyticsService.logSettingsConsentUpdated(consentType: "gdpr", granted: true)

        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        let event = mockAdapter.capturedEvents[0]
        XCTAssertEqual(event.name, AnalyticsEvent.settingsConsentUpdated)
        XCTAssertEqual(event.parameters?[AnalyticsParam.consentType] as? String, "gdpr")
    }

    @MainActor
    func testSettingsDataDeletedEvent() {
        analyticsService.logSettingsDataDeleted(deleteScope: "local")

        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        let event = mockAdapter.capturedEvents[0]
        XCTAssertEqual(event.name, AnalyticsEvent.settingsDataDeleted)
        XCTAssertEqual(event.parameters?[AnalyticsParam.deleteScope] as? String, "local")
    }

    @MainActor
    func testSettingsEventsBlockedWithoutConsent() {
        consentManager.denyConsent()

        analyticsService.logSettingsSyncTriggered(syncType: "fetch")
        analyticsService.logSettingsDataDeleted(deleteScope: "local")

        XCTAssertEqual(mockAdapter.capturedEvents.count, 0)
    }

    @MainActor
    func testAllSettingsV2EventsHaveScreenPrefix() {
        let events = [
            AnalyticsEvent.settingsSyncTriggered,
            AnalyticsEvent.settingsConsentUpdated,
            AnalyticsEvent.settingsDataDeleted,
        ]

        for event in events {
            XCTAssertTrue(event.hasPrefix("settings_"), "Event '\(event)' must start with 'settings_'")
        }
    }
}
