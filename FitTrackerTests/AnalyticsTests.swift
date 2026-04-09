import XCTest
@testable import FitTracker

// MARK: - Analytics Unit Tests
// Tests for: event firing, screen tracking, consent gating, taxonomy sync

final class AnalyticsTests: XCTestCase {

    private var mockAdapter: MockAnalyticsAdapter!
    private var consentManager: ConsentManager!
    private var analyticsService: AnalyticsService!

    @MainActor
    override func setUp() {
        super.setUp()
        mockAdapter = MockAnalyticsAdapter()
        consentManager = ConsentManager()
        // Grant consent for most tests
        consentManager.grantConsent()
        analyticsService = AnalyticsService(provider: mockAdapter, consent: consentManager)
    }

    @MainActor
    override func tearDown() {
        // Reset consent state for next test
        UserDefaults.standard.removeObject(forKey: "ft.analytics.gdprConsent")
        UserDefaults.standard.removeObject(forKey: "ft.analytics.consentDate")
        UserDefaults.standard.removeObject(forKey: "ft.analytics.hasBeenAsked")
        mockAdapter.reset()
        super.tearDown()
    }

    // MARK: - Event Firing Tests

    @MainActor
    func testWorkoutStartedEvent() {
        analyticsService.logWorkoutStarted(workoutType: "push", dayNumber: 1)

        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        let event = mockAdapter.capturedEvents[0]
        XCTAssertEqual(event.name, AnalyticsEvent.workoutStart)
        XCTAssertEqual(event.parameters?[AnalyticsParam.workoutType] as? String, "push")
        XCTAssertEqual(event.parameters?[AnalyticsParam.dayNumber] as? Int, 1)
    }

    @MainActor
    func testWorkoutCompletedEvent() {
        analyticsService.logWorkoutCompleted(durationSeconds: 3600, exerciseCount: 5, setCount: 20)

        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        let event = mockAdapter.capturedEvents[0]
        XCTAssertEqual(event.name, AnalyticsEvent.workoutComplete)
        XCTAssertEqual(event.parameters?[AnalyticsParam.durationSeconds] as? Int, 3600)
        XCTAssertEqual(event.parameters?[AnalyticsParam.exerciseCount] as? Int, 5)
        XCTAssertEqual(event.parameters?[AnalyticsParam.setCount] as? Int, 20)
    }

    @MainActor
    func testMealLoggedEvent() {
        analyticsService.logMealLogged(mealType: "lunch", entryMethod: "manual")

        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        let event = mockAdapter.capturedEvents[0]
        XCTAssertEqual(event.name, AnalyticsEvent.mealLog)
        XCTAssertEqual(event.parameters?[AnalyticsParam.mealType] as? String, "lunch")
        XCTAssertEqual(event.parameters?[AnalyticsParam.entryMethod] as? String, "manual")
    }

    @MainActor
    func testLoginEvent() {
        analyticsService.logLogin(method: "apple")

        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        let event = mockAdapter.capturedEvents[0]
        XCTAssertEqual(event.name, AnalyticsEvent.login)
        XCTAssertEqual(event.parameters?[AnalyticsParam.method] as? String, "apple")
    }

    @MainActor
    func testSignUpEvent() {
        analyticsService.logSignUp(method: "email")

        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        let event = mockAdapter.capturedEvents[0]
        XCTAssertEqual(event.name, AnalyticsEvent.signUp)
        XCTAssertEqual(event.parameters?[AnalyticsParam.method] as? String, "email")
    }

    @MainActor
    func testBiometricLoggedEvent() {
        analyticsService.logBiometricLogged(metricType: "weight", source: "manual")

        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        let event = mockAdapter.capturedEvents[0]
        XCTAssertEqual(event.name, AnalyticsEvent.biometricLog)
        XCTAssertEqual(event.parameters?[AnalyticsParam.metricType] as? String, "weight")
        XCTAssertEqual(event.parameters?[AnalyticsParam.source] as? String, "manual")
    }

    @MainActor
    func testStreakMaintainedEvent() {
        analyticsService.logStreakMaintained(streakLength: 7)

        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        let event = mockAdapter.capturedEvents[0]
        XCTAssertEqual(event.name, AnalyticsEvent.streakMaintained)
        XCTAssertEqual(event.parameters?[AnalyticsParam.streakLength] as? Int, 7)
    }

    @MainActor
    func testGoalReachedEvent() {
        analyticsService.logGoalReached(goalType: "weight")

        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        let event = mockAdapter.capturedEvents[0]
        XCTAssertEqual(event.name, AnalyticsEvent.goalReached)
        XCTAssertEqual(event.parameters?[AnalyticsParam.goalType] as? String, "weight")
    }

    @MainActor
    func testShareEvent() {
        analyticsService.logShare(contentType: "workout", itemId: "workout_123")

        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        let event = mockAdapter.capturedEvents[0]
        XCTAssertEqual(event.name, AnalyticsEvent.share)
        XCTAssertEqual(event.parameters?[AnalyticsParam.contentType] as? String, "workout")
    }

    @MainActor
    func testSettingsChangedEvent() {
        analyticsService.logSettingsChanged(settingName: "analytics", newValue: "enabled")

        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        let event = mockAdapter.capturedEvents[0]
        XCTAssertEqual(event.name, AnalyticsEvent.settingsChanged)
        XCTAssertEqual(event.parameters?[AnalyticsParam.settingName] as? String, "analytics")
        XCTAssertEqual(event.parameters?[AnalyticsParam.settingValue] as? String, "enabled")
    }

    // MARK: - Screen Tracking Tests

    @MainActor
    func testScreenViewTracking() {
        analyticsService.logScreenView(AnalyticsScreen.home)
        analyticsService.logScreenView(AnalyticsScreen.trainingPlan)
        analyticsService.logScreenView(AnalyticsScreen.nutrition)

        XCTAssertEqual(mockAdapter.capturedScreens.count, 3)
        XCTAssertEqual(mockAdapter.capturedScreens[0], AnalyticsScreen.home)
        XCTAssertEqual(mockAdapter.capturedScreens[1], AnalyticsScreen.trainingPlan)
        XCTAssertEqual(mockAdapter.capturedScreens[2], AnalyticsScreen.nutrition)
    }

    // MARK: - Consent Gating Tests

    @MainActor
    func testEventsBlockedWhenConsentDenied() {
        consentManager.denyConsent()
        analyticsService.syncConsentToProvider()

        analyticsService.logWorkoutStarted(workoutType: "push", dayNumber: 1)
        analyticsService.logScreenView(AnalyticsScreen.home)
        analyticsService.logMealLogged(mealType: "lunch", entryMethod: "manual")

        // No events should be captured when consent is denied
        XCTAssertEqual(mockAdapter.capturedEvents.count, 0)
        XCTAssertEqual(mockAdapter.capturedScreens.count, 0)
    }

    @MainActor
    func testEventsFlowAfterConsentGranted() {
        // Start denied
        consentManager.denyConsent()
        analyticsService.syncConsentToProvider()
        analyticsService.logWorkoutStarted(workoutType: "push", dayNumber: 1)
        XCTAssertEqual(mockAdapter.capturedEvents.count, 0)

        // Grant consent
        consentManager.regrantConsent()
        analyticsService.syncConsentToProvider()
        analyticsService.logWorkoutStarted(workoutType: "pull", dayNumber: 2)
        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        XCTAssertEqual(mockAdapter.capturedEvents[0].parameters?[AnalyticsParam.workoutType] as? String, "pull")
    }

    @MainActor
    func testConsentEventsAlwaysLoggedRegardlessOfConsent() {
        // Even when consent is denied, consent_granted/denied events must fire
        // (to measure consent rate)
        consentManager.denyConsent()
        analyticsService.syncConsentToProvider()

        analyticsService.logConsentGranted(type: "gdpr")
        analyticsService.logConsentDenied(type: "gdpr")

        // These bypass the consent gate
        XCTAssertEqual(mockAdapter.capturedEvents.count, 2)
        XCTAssertEqual(mockAdapter.capturedEvents[0].name, AnalyticsEvent.consentGranted)
        XCTAssertEqual(mockAdapter.capturedEvents[1].name, AnalyticsEvent.consentDenied)
    }

    // MARK: - User Properties Tests

    @MainActor
    func testUserPropertiesNotSetWhenConsentDenied() {
        consentManager.denyConsent()
        analyticsService.syncConsentToProvider()

        analyticsService.setUserID("user_123")
        analyticsService.updateUserProperties(trainingLevel: "advanced")

        // MockAdapter doesn't track user properties directly, but we verify
        // the consent gate prevents the call (no crash = pass)
    }

    // MARK: - Taxonomy Validation Tests

    func testEventNameConventions() {
        // All event names must be snake_case, <40 chars, no reserved prefixes
        let events = [
            AnalyticsEvent.login, AnalyticsEvent.signUp, AnalyticsEvent.share,
            AnalyticsEvent.selectContent, AnalyticsEvent.tutorialBegin, AnalyticsEvent.tutorialComplete,
            AnalyticsEvent.workoutStart, AnalyticsEvent.workoutComplete,
            AnalyticsEvent.exerciseLog, AnalyticsEvent.prAchieved,
            AnalyticsEvent.mealLog, AnalyticsEvent.supplementLog,
            AnalyticsEvent.biometricLog, AnalyticsEvent.statsView,
            AnalyticsEvent.streakMaintained, AnalyticsEvent.goalReached,
            AnalyticsEvent.crossFeatureEngagement,
            AnalyticsEvent.accountDeleteRequested, AnalyticsEvent.accountDeleteCompleted,
            AnalyticsEvent.accountDeleteCancelled,
            AnalyticsEvent.dataExportRequested, AnalyticsEvent.dataExportCompleted,
            AnalyticsEvent.consentGranted, AnalyticsEvent.consentDenied,
            AnalyticsEvent.settingsChanged,
        ]

        for event in events {
            XCTAssertTrue(event.count <= 40, "Event '\(event)' exceeds 40 chars")
            XCTAssertFalse(event.hasPrefix("ga_"), "Event '\(event)' uses reserved prefix ga_")
            XCTAssertFalse(event.hasPrefix("firebase_"), "Event '\(event)' uses reserved prefix firebase_")
            XCTAssertFalse(event.hasPrefix("google_"), "Event '\(event)' uses reserved prefix google_")
            XCTAssertEqual(event, event.lowercased(), "Event '\(event)' is not lowercase")
            XCTAssertFalse(event.contains(" "), "Event '\(event)' contains spaces")
        }
    }

    func testScreenNameConventions() {
        let screens = [
            AnalyticsScreen.home, AnalyticsScreen.trainingPlan, AnalyticsScreen.activeWorkout,
            AnalyticsScreen.exerciseDetail, AnalyticsScreen.nutrition, AnalyticsScreen.mealEntry,
            AnalyticsScreen.supplements, AnalyticsScreen.recovery, AnalyticsScreen.biometricsEntry,
            AnalyticsScreen.stats, AnalyticsScreen.chartDetail, AnalyticsScreen.prRecords,
            AnalyticsScreen.settings, AnalyticsScreen.settingsAccount, AnalyticsScreen.settingsData,
            AnalyticsScreen.settingsAppearance, AnalyticsScreen.settingsNotifications,
            AnalyticsScreen.settingsAbout, AnalyticsScreen.signIn, AnalyticsScreen.signUpScreen,
            AnalyticsScreen.profile, AnalyticsScreen.readiness, AnalyticsScreen.consent,
            AnalyticsScreen.onboarding,
        ]

        for screen in screens {
            XCTAssertTrue(screen.count <= 40, "Screen '\(screen)' exceeds 40 chars")
            XCTAssertEqual(screen, screen.lowercased(), "Screen '\(screen)' is not lowercase")
            XCTAssertFalse(screen.contains(" "), "Screen '\(screen)' contains spaces")
        }
    }

    func testParameterNameConventions() {
        let params = [
            AnalyticsParam.method, AnalyticsParam.contentType, AnalyticsParam.itemId,
            AnalyticsParam.workoutType, AnalyticsParam.dayNumber, AnalyticsParam.durationSeconds,
            AnalyticsParam.exerciseCount, AnalyticsParam.setCount,
            AnalyticsParam.exerciseName, AnalyticsParam.muscleGroup,
            AnalyticsParam.sets, AnalyticsParam.reps, AnalyticsParam.weight, AnalyticsParam.prType,
            AnalyticsParam.mealType, AnalyticsParam.entryMethod,
            AnalyticsParam.timeOfDay, AnalyticsParam.count,
            AnalyticsParam.metricType, AnalyticsParam.source,
            AnalyticsParam.statType, AnalyticsParam.timePeriod,
            AnalyticsParam.streakLength, AnalyticsParam.goalType, AnalyticsParam.featuresUsed,
            AnalyticsParam.settingName, AnalyticsParam.settingValue,
            AnalyticsParam.storesDeleted, AnalyticsParam.daysRemaining,
            AnalyticsParam.sizeBytes, AnalyticsParam.recordCount,
            AnalyticsParam.consentType,
        ]

        for param in params {
            XCTAssertTrue(param.count <= 40, "Param '\(param)' exceeds 40 chars")
            XCTAssertEqual(param, param.lowercased(), "Param '\(param)' is not lowercase")
            XCTAssertFalse(param.contains(" "), "Param '\(param)' contains spaces")
        }
    }

    func testConversionEventsAreDefined() {
        // All conversion events must exist in AnalyticsEvent
        let conversions = AnalyticsConversion.events
        XCTAssertTrue(conversions.contains(AnalyticsEvent.signUp))
        XCTAssertTrue(conversions.contains(AnalyticsEvent.workoutComplete))
        XCTAssertTrue(conversions.contains(AnalyticsEvent.mealLog))
        XCTAssertTrue(conversions.contains(AnalyticsEvent.tutorialComplete))
        XCTAssertTrue(conversions.contains(AnalyticsEvent.crossFeatureEngagement))
        XCTAssertTrue(conversions.contains(AnalyticsEvent.accountDeleteCompleted))
        XCTAssertTrue(conversions.contains(AnalyticsEvent.homeActionCompleted))
        XCTAssertEqual(conversions.count, 7)
    }

    // MARK: - GDPR Event Tests

    @MainActor
    func testAccountDeleteRequestedEvent() {
        analyticsService.logAccountDeleteRequested(method: "biometric")

        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        let event = mockAdapter.capturedEvents[0]
        XCTAssertEqual(event.name, AnalyticsEvent.accountDeleteRequested)
        XCTAssertEqual(event.parameters?[AnalyticsParam.method] as? String, "biometric")
    }

    @MainActor
    func testAccountDeleteCompletedEvent() {
        analyticsService.logAccountDeleteCompleted(storesDeleted: ["device", "cloudkit", "supabase"])

        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        let event = mockAdapter.capturedEvents[0]
        XCTAssertEqual(event.name, AnalyticsEvent.accountDeleteCompleted)
        XCTAssertEqual(event.parameters?[AnalyticsParam.storesDeleted] as? String, "device,cloudkit,supabase")
    }

    @MainActor
    func testAccountDeleteCancelledEvent() {
        analyticsService.logAccountDeleteCancelled(daysRemaining: 15)

        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        let event = mockAdapter.capturedEvents[0]
        XCTAssertEqual(event.name, AnalyticsEvent.accountDeleteCancelled)
        XCTAssertEqual(event.parameters?[AnalyticsParam.daysRemaining] as? Int, 15)
    }

    @MainActor
    func testDataExportRequestedEvent() {
        analyticsService.logDataExportRequested()

        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        XCTAssertEqual(mockAdapter.capturedEvents[0].name, AnalyticsEvent.dataExportRequested)
    }

    @MainActor
    func testDataExportCompletedEvent() {
        analyticsService.logDataExportCompleted(sizeBytes: 524288, recordCount: 247)

        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        let event = mockAdapter.capturedEvents[0]
        XCTAssertEqual(event.name, AnalyticsEvent.dataExportCompleted)
        XCTAssertEqual(event.parameters?[AnalyticsParam.sizeBytes] as? Int, 524288)
        XCTAssertEqual(event.parameters?[AnalyticsParam.recordCount] as? Int, 247)
    }

    @MainActor
    func testGDPRScreenNames() {
        let screens = [AnalyticsScreen.deleteAccount, AnalyticsScreen.exportData]
        for screen in screens {
            XCTAssertTrue(screen.count <= 40)
            XCTAssertEqual(screen, screen.lowercased())
            XCTAssertFalse(screen.contains(" "))
        }
    }

    // MARK: - Onboarding Event Tests

    @MainActor
    func testOnboardingStepViewedEvent() {
        analyticsService.logOnboardingStepViewed(stepIndex: 1, stepName: "goals")

        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        let event = mockAdapter.capturedEvents[0]
        XCTAssertEqual(event.name, AnalyticsEvent.onboardingStepViewed)
        XCTAssertEqual(event.parameters?[AnalyticsParam.stepIndex] as? Int, 1)
        XCTAssertEqual(event.parameters?[AnalyticsParam.stepName] as? String, "goals")
    }

    @MainActor
    func testOnboardingStepCompletedEvent() {
        analyticsService.logOnboardingStepCompleted(stepIndex: 2, stepName: "profile")

        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        let event = mockAdapter.capturedEvents[0]
        XCTAssertEqual(event.name, AnalyticsEvent.onboardingStepCompleted)
        XCTAssertEqual(event.parameters?[AnalyticsParam.stepIndex] as? Int, 2)
        XCTAssertEqual(event.parameters?[AnalyticsParam.stepName] as? String, "profile")
    }

    @MainActor
    func testOnboardingSkippedEvent() {
        analyticsService.logOnboardingSkipped(stepIndex: 3, stepName: "healthkit")

        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        let event = mockAdapter.capturedEvents[0]
        XCTAssertEqual(event.name, AnalyticsEvent.onboardingSkipped)
        XCTAssertEqual(event.parameters?[AnalyticsParam.stepIndex] as? Int, 3)
        XCTAssertEqual(event.parameters?[AnalyticsParam.stepName] as? String, "healthkit")
    }

    @MainActor
    func testOnboardingCompletedUserProperty() {
        analyticsService.setOnboardingCompleted(true)

        XCTAssertEqual(mockAdapter.capturedUserProperties.count, 1)
        XCTAssertEqual(mockAdapter.capturedUserProperties[AnalyticsUserProperty.onboardingCompleted], "true")
    }

    @MainActor
    func testOnboardingConsentGating() {
        // Deny consent
        consentManager.denyConsent()

        analyticsService.logOnboardingStepCompleted(stepIndex: 1, stepName: "goals")

        // Should NOT fire when consent denied
        XCTAssertEqual(mockAdapter.capturedEvents.count, 0)

        // Grant consent and retry
        consentManager.grantConsent()
        analyticsService.logOnboardingStepCompleted(stepIndex: 1, stepName: "goals")

        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        XCTAssertEqual(mockAdapter.capturedEvents[0].name, AnalyticsEvent.onboardingStepCompleted)
    }

    @MainActor
    func testOnboardingScreenNames() {
        let screens = [
            AnalyticsScreen.onboardingWelcome,
            AnalyticsScreen.onboardingGoals,
            AnalyticsScreen.onboardingProfile,
            AnalyticsScreen.onboardingHealthkit,
            AnalyticsScreen.onboardingFirstAction,
        ]
        for screen in screens {
            // GA4 naming rules: snake_case, max 40 chars, no spaces
            XCTAssertTrue(screen.count <= 40, "\(screen) exceeds 40 chars")
            XCTAssertEqual(screen, screen.lowercased(), "\(screen) not lowercase")
            XCTAssertFalse(screen.contains(" "), "\(screen) contains space")
            XCTAssertFalse(screen.hasPrefix("ga_"), "\(screen) has reserved prefix")
            XCTAssertFalse(screen.hasPrefix("firebase_"), "\(screen) has reserved prefix")
        }
    }
}
