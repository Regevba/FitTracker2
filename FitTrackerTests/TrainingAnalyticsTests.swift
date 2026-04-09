import XCTest
@testable import FitTracker

// MARK: - Training Screen Analytics Tests
// Tests for the 12 training_* analytics events.
// Validates event firing, parameter correctness, screen-prefix convention,
// conversion event registration, and consent gating.

final class TrainingAnalyticsTests: XCTestCase {

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
    func testTrainingSessionViewed() {
        analyticsService.logTrainingSessionViewed(workoutType: "push")

        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        let event = mockAdapter.capturedEvents[0]
        XCTAssertEqual(event.name, AnalyticsEvent.trainingSessionViewed)
        XCTAssertEqual(event.name, "training_session_viewed")
        XCTAssertEqual(event.parameters?[AnalyticsParam.workoutType] as? String, "push")
    }

    @MainActor
    func testTrainingExerciseStarted() {
        analyticsService.logTrainingExerciseStarted(exerciseName: "Bench Press", muscleGroup: "chest")

        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        let event = mockAdapter.capturedEvents[0]
        XCTAssertEqual(event.name, AnalyticsEvent.trainingExerciseStarted)
        XCTAssertEqual(event.name, "training_exercise_started")
        XCTAssertEqual(event.parameters?[AnalyticsParam.exerciseName] as? String, "Bench Press")
        XCTAssertEqual(event.parameters?[AnalyticsParam.muscleGroup] as? String, "chest")
    }

    @MainActor
    func testTrainingExerciseCompleted() {
        analyticsService.logTrainingExerciseCompleted(exerciseName: "Squat", sets: 4)

        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        let event = mockAdapter.capturedEvents[0]
        XCTAssertEqual(event.name, AnalyticsEvent.trainingExerciseCompleted)
        XCTAssertEqual(event.name, "training_exercise_completed")
        XCTAssertEqual(event.parameters?[AnalyticsParam.exerciseName] as? String, "Squat")
        XCTAssertEqual(event.parameters?[AnalyticsParam.sets] as? Int, 4)
    }

    @MainActor
    func testTrainingSetLogged() {
        analyticsService.logTrainingSetLogged(exerciseName: "Deadlift", setIndex: 2, reps: 8, weightKg: 100.0)

        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        let event = mockAdapter.capturedEvents[0]
        XCTAssertEqual(event.name, AnalyticsEvent.trainingSetLogged)
        XCTAssertEqual(event.name, "training_set_logged")
        XCTAssertEqual(event.parameters?[AnalyticsParam.exerciseName] as? String, "Deadlift")
        XCTAssertEqual(event.parameters?[AnalyticsParam.setIndex] as? Int, 2)
        XCTAssertEqual(event.parameters?[AnalyticsParam.reps] as? Int, 8)
        XCTAssertEqual(event.parameters?[AnalyticsParam.weight] as? Double, 100.0)
    }

    @MainActor
    func testTrainingSetCopied() {
        analyticsService.logTrainingSetCopied(exerciseName: "Overhead Press", setIndex: 3)

        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        let event = mockAdapter.capturedEvents[0]
        XCTAssertEqual(event.name, AnalyticsEvent.trainingSetCopied)
        XCTAssertEqual(event.name, "training_set_copied")
        XCTAssertEqual(event.parameters?[AnalyticsParam.exerciseName] as? String, "Overhead Press")
        XCTAssertEqual(event.parameters?[AnalyticsParam.setIndex] as? Int, 3)
    }

    @MainActor
    func testTrainingWeightChanged() {
        analyticsService.logTrainingWeightChanged(exerciseName: "Barbell Row", weightKg: 72.5)

        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        let event = mockAdapter.capturedEvents[0]
        XCTAssertEqual(event.name, AnalyticsEvent.trainingWeightChanged)
        XCTAssertEqual(event.name, "training_weight_changed")
        XCTAssertEqual(event.parameters?[AnalyticsParam.exerciseName] as? String, "Barbell Row")
        XCTAssertEqual(event.parameters?[AnalyticsParam.weight] as? Double, 72.5)
    }

    @MainActor
    func testTrainingRestTimerStarted() {
        analyticsService.logTrainingRestTimerStarted(restDurationSeconds: 90)

        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        let event = mockAdapter.capturedEvents[0]
        XCTAssertEqual(event.name, AnalyticsEvent.trainingRestTimerStarted)
        XCTAssertEqual(event.name, "training_rest_timer_started")
        XCTAssertEqual(event.parameters?[AnalyticsParam.restDurationSeconds] as? Int, 90)
    }

    @MainActor
    func testTrainingRestTimerSkipped() {
        analyticsService.logTrainingRestTimerSkipped(restDurationSeconds: 60)

        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        let event = mockAdapter.capturedEvents[0]
        XCTAssertEqual(event.name, AnalyticsEvent.trainingRestTimerSkipped)
        XCTAssertEqual(event.name, "training_rest_timer_skipped")
        XCTAssertEqual(event.parameters?[AnalyticsParam.restDurationSeconds] as? Int, 60)
    }

    @MainActor
    func testTrainingActivitySwitched() {
        analyticsService.logTrainingActivitySwitched(activityType: "cardio")

        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        let event = mockAdapter.capturedEvents[0]
        XCTAssertEqual(event.name, AnalyticsEvent.trainingActivitySwitched)
        XCTAssertEqual(event.name, "training_activity_switched")
        XCTAssertEqual(event.parameters?[AnalyticsParam.activityType] as? String, "cardio")
    }

    @MainActor
    func testTrainingSessionCompleted() {
        analyticsService.logTrainingSessionCompleted(
            sessionDurationSeconds: 3600,
            totalSets: 20,
            exerciseCount: 5
        )

        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        let event = mockAdapter.capturedEvents[0]
        XCTAssertEqual(event.name, AnalyticsEvent.trainingSessionCompleted)
        XCTAssertEqual(event.name, "training_session_completed")
        XCTAssertEqual(event.parameters?[AnalyticsParam.sessionDurationSeconds] as? Int, 3600)
        XCTAssertEqual(event.parameters?[AnalyticsParam.totalSets] as? Int, 20)
        XCTAssertEqual(event.parameters?[AnalyticsParam.exerciseCount] as? Int, 5)
    }

    @MainActor
    func testTrainingSessionCompletedIsConversionEvent() {
        XCTAssertTrue(
            AnalyticsConversion.events.contains(AnalyticsEvent.trainingSessionCompleted),
            "training_session_completed should be in AnalyticsConversion.events"
        )
    }

    @MainActor
    func testTrainingFocusModeEntered() {
        analyticsService.logTrainingFocusModeEntered()

        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        let event = mockAdapter.capturedEvents[0]
        XCTAssertEqual(event.name, AnalyticsEvent.trainingFocusModeEntered)
        XCTAssertEqual(event.name, "training_focus_mode_entered")
        XCTAssertNil(event.parameters)
    }

    @MainActor
    func testTrainingCameraOpened() {
        analyticsService.logTrainingCameraOpened(exerciseName: "Squat")

        XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
        let event = mockAdapter.capturedEvents[0]
        XCTAssertEqual(event.name, AnalyticsEvent.trainingCameraOpened)
        XCTAssertEqual(event.name, "training_camera_opened")
        XCTAssertEqual(event.parameters?[AnalyticsParam.exerciseName] as? String, "Squat")
    }

    // MARK: - Screen Prefix Convention Tests

    func testTrainingEventsFollowScreenPrefixConvention() {
        let trainingEvents = [
            AnalyticsEvent.trainingSessionViewed,
            AnalyticsEvent.trainingExerciseStarted,
            AnalyticsEvent.trainingExerciseCompleted,
            AnalyticsEvent.trainingSetLogged,
            AnalyticsEvent.trainingSetCopied,
            AnalyticsEvent.trainingWeightChanged,
            AnalyticsEvent.trainingRestTimerStarted,
            AnalyticsEvent.trainingRestTimerSkipped,
            AnalyticsEvent.trainingActivitySwitched,
            AnalyticsEvent.trainingSessionCompleted,
            AnalyticsEvent.trainingFocusModeEntered,
            AnalyticsEvent.trainingCameraOpened,
        ]

        XCTAssertEqual(trainingEvents.count, 12, "Expected exactly 12 training events")

        for event in trainingEvents {
            XCTAssertTrue(event.hasPrefix("training_"), "Event '\(event)' missing training_ prefix")
            XCTAssertTrue(event.count <= 40, "Event '\(event)' exceeds GA4 40-char limit")
            XCTAssertEqual(event, event.lowercased(), "Event '\(event)' is not lowercase snake_case")
            XCTAssertFalse(event.contains(" "), "Event '\(event)' contains spaces")
            XCTAssertFalse(event.hasPrefix("ga_"), "Event '\(event)' uses reserved ga_ prefix")
            XCTAssertFalse(event.hasPrefix("firebase_"), "Event '\(event)' uses reserved firebase_ prefix")
        }
    }

    // MARK: - Consent Gating Tests

    @MainActor
    func testTrainingEventsBlockedWhenConsentDenied() {
        consentManager.denyConsent()
        analyticsService.syncConsentToProvider()

        analyticsService.logTrainingSessionViewed(workoutType: "push")
        analyticsService.logTrainingExerciseStarted(exerciseName: "Bench Press", muscleGroup: "chest")
        analyticsService.logTrainingExerciseCompleted(exerciseName: "Squat", sets: 4)
        analyticsService.logTrainingSetLogged(exerciseName: "Deadlift", setIndex: 1, reps: 5, weightKg: 140.0)
        analyticsService.logTrainingSetCopied(exerciseName: "OHP", setIndex: 2)
        analyticsService.logTrainingWeightChanged(exerciseName: "Row", weightKg: 80.0)
        analyticsService.logTrainingRestTimerStarted(restDurationSeconds: 120)
        analyticsService.logTrainingRestTimerSkipped(restDurationSeconds: 60)
        analyticsService.logTrainingActivitySwitched(activityType: "cardio")
        analyticsService.logTrainingSessionCompleted(sessionDurationSeconds: 1800, totalSets: 15, exerciseCount: 4)
        analyticsService.logTrainingFocusModeEntered()
        analyticsService.logTrainingCameraOpened(exerciseName: "Squat")

        XCTAssertEqual(mockAdapter.capturedEvents.count, 0, "Training events should not fire when consent is denied")
    }

    // MARK: - Parameter Name Convention Tests

    func testTrainingParameterNameConventions() {
        let trainingParams = [
            AnalyticsParam.setIndex,
            AnalyticsParam.activityType,
            AnalyticsParam.restDurationSeconds,
            AnalyticsParam.sessionDurationSeconds,
            AnalyticsParam.totalSets,
        ]

        for param in trainingParams {
            XCTAssertTrue(param.count <= 40, "Param '\(param)' exceeds GA4 40-char limit")
            XCTAssertEqual(param, param.lowercased(), "Param '\(param)' is not lowercase snake_case")
            XCTAssertFalse(param.contains(" "), "Param '\(param)' contains spaces")
        }
    }
}
