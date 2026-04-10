// Services/Analytics/AnalyticsService.swift
// Main analytics orchestrator. Owns the provider and consent manager.
// Injected as @EnvironmentObject throughout the app.
// All public methods gate on consent before forwarding to the provider.
//
// GA4 compliance:
// - Uses recommended events (login, sign_up, share, select_content, tutorial_*)
// - All parameters use AnalyticsParam constants (snake_case, max 40 chars)
// - SI units for measurements (seconds, kg)
// - No PII in any parameter

import Foundation
import SwiftUI

enum AnalyticsRuntimeConfiguration {
    static var isRunningTests: Bool {
        let env = ProcessInfo.processInfo.environment
        return env["XCTestBundlePath"] != nil
            || env["XCTestConfigurationFilePath"] != nil
            || env["XCTestSessionIdentifier"] != nil
    }

    static var hasFirebaseConfiguration: Bool {
        Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil
    }

    static var canUseFirebase: Bool {
        !isRunningTests && hasFirebaseConfiguration
    }
}

@MainActor
final class AnalyticsService: ObservableObject {

    // MARK: - Dependencies

    private let provider: AnalyticsProvider
    let consent: ConsentManager

    // MARK: - Init

    init(provider: AnalyticsProvider, consent: ConsentManager) {
        self.provider = provider
        self.consent = consent
        provider.configure()
        syncConsentToProvider()
    }

    static func makeDefault() -> AnalyticsService {
        let consent = ConsentManager()
        let provider: AnalyticsProvider = AnalyticsRuntimeConfiguration.canUseFirebase
            ? FirebaseAnalyticsAdapter()
            : MockAnalyticsAdapter()
        return AnalyticsService(provider: provider, consent: consent)
    }

    // MARK: - Consent Sync

    func syncConsentToProvider() {
        let allowed = consent.isAnalyticsAllowed
        provider.setConsent(analyticsStorage: allowed, adStorage: false)
        provider.setUserProperty(
            consent.gdprConsent.rawValue,
            forName: AnalyticsUserProperty.consentStatus
        )
    }

    // MARK: - Screen Tracking

    func logScreenView(_ screenName: String) {
        guard consent.isAnalyticsAllowed else { return }
        provider.logScreenView(screenName, screenClass: nil)
    }

    /// Overload — accepts the SwiftUI view class name for richer GA4 reporting.
    func logScreenView(_ screenName: String, screenClass: String?) {
        guard consent.isAnalyticsAllowed else { return }
        provider.logScreenView(screenName, screenClass: screenClass)
    }

    // MARK: - GA4 Recommended Events

    /// GA4 recommended: "login"
    func logLogin(method: String) {
        logEvent(AnalyticsEvent.login, parameters: [
            AnalyticsParam.method: method,
        ])
    }

    /// GA4 recommended: "sign_up"
    func logSignUp(method: String) {
        logEvent(AnalyticsEvent.signUp, parameters: [
            AnalyticsParam.method: method,
        ])
    }

    /// GA4 recommended: "share"
    func logShare(contentType: String, itemId: String) {
        logEvent(AnalyticsEvent.share, parameters: [
            AnalyticsParam.contentType: contentType,
            AnalyticsParam.itemId: itemId,
        ])
    }

    /// GA4 recommended: "select_content"
    func logSelectContent(contentType: String, itemId: String) {
        logEvent(AnalyticsEvent.selectContent, parameters: [
            AnalyticsParam.contentType: contentType,
            AnalyticsParam.itemId: itemId,
        ])
    }

    /// GA4 recommended: "tutorial_begin"
    func logTutorialBegin() {
        logEvent(AnalyticsEvent.tutorialBegin, parameters: nil)
    }

    /// GA4 recommended: "tutorial_complete"
    func logTutorialComplete() {
        logEvent(AnalyticsEvent.tutorialComplete, parameters: nil)
    }

    // MARK: - Onboarding Events

    /// User views an onboarding step
    func logOnboardingStepViewed(stepIndex: Int, stepName: String) {
        logEvent(AnalyticsEvent.onboardingStepViewed, parameters: [
            AnalyticsParam.stepIndex: stepIndex,
            AnalyticsParam.stepName: stepName,
        ])
    }

    /// User completes an onboarding step
    func logOnboardingStepCompleted(stepIndex: Int, stepName: String) {
        logEvent(AnalyticsEvent.onboardingStepCompleted, parameters: [
            AnalyticsParam.stepIndex: stepIndex,
            AnalyticsParam.stepName: stepName,
        ])
    }

    /// User skips onboarding from a given step
    func logOnboardingSkipped(stepIndex: Int, stepName: String) {
        logEvent(AnalyticsEvent.onboardingSkipped, parameters: [
            AnalyticsParam.stepIndex: stepIndex,
            AnalyticsParam.stepName: stepName,
        ])
    }

    /// User selects a goal during onboarding
    func logOnboardingGoalSelected(goalValue: String) {
        logEvent(AnalyticsEvent.onboardingGoalSelected, parameters: [
            AnalyticsParam.goalValue: goalValue,
        ])
    }

    /// System permission result (HealthKit, notifications, etc.)
    func logPermissionResult(type: String, granted: Bool) {
        logEvent(AnalyticsEvent.permissionResult, parameters: [
            AnalyticsParam.permissionType: type,
            AnalyticsParam.permissionGranted: granted ? "true" : "false",
        ])
    }

    /// Sets the onboarding_completed user property
    func setOnboardingCompleted(_ completed: Bool) {
        guard consent.isAnalyticsAllowed else { return }
        provider.setUserProperty(
            completed ? "true" : "false",
            forName: AnalyticsUserProperty.onboardingCompleted
        )
    }

    // MARK: - Workout Events

    func logWorkoutStarted(workoutType: String, dayNumber: Int) {
        logEvent(AnalyticsEvent.workoutStart, parameters: [
            AnalyticsParam.workoutType: workoutType,
            AnalyticsParam.dayNumber: dayNumber,
        ])
    }

    func logWorkoutCompleted(durationSeconds: Int, exerciseCount: Int, setCount: Int) {
        logEvent(AnalyticsEvent.workoutComplete, parameters: [
            AnalyticsParam.durationSeconds: durationSeconds,
            AnalyticsParam.exerciseCount: exerciseCount,
            AnalyticsParam.setCount: setCount,
        ])
    }

    func logExerciseLogged(name: String, muscleGroup: String, sets: Int, reps: Int, weightKg: Double) {
        logEvent(AnalyticsEvent.exerciseLog, parameters: [
            AnalyticsParam.exerciseName: name,
            AnalyticsParam.muscleGroup: muscleGroup,
            AnalyticsParam.sets: sets,
            AnalyticsParam.reps: reps,
            AnalyticsParam.weight: weightKg,
        ])
    }

    func logPRAchieved(exerciseName: String, prType: String) {
        logEvent(AnalyticsEvent.prAchieved, parameters: [
            AnalyticsParam.exerciseName: exerciseName,
            AnalyticsParam.prType: prType,
        ])
    }

    // MARK: - Nutrition Events

    func logMealLogged(mealType: String, entryMethod: String) {
        logEvent(AnalyticsEvent.mealLog, parameters: [
            AnalyticsParam.mealType: mealType,
            AnalyticsParam.entryMethod: entryMethod,
        ])
    }

    func logSupplementLogged(timeOfDay: String, count: Int) {
        logEvent(AnalyticsEvent.supplementLog, parameters: [
            AnalyticsParam.timeOfDay: timeOfDay,
            AnalyticsParam.count: count,
        ])
    }

    // MARK: - Nutrition v2 Events (screen-prefixed)

    func logNutritionMealLogged(mealType: String, entryMethod: String, calories: Int) {
        logEvent(AnalyticsEvent.nutritionMealLogged, parameters: [
            AnalyticsParam.mealType: mealType,
            AnalyticsParam.entryMethod: entryMethod,
            AnalyticsParam.calories: calories,
        ])
    }

    func logNutritionSupplementLogged(timeOfDay: String, supplementCount: Int) {
        logEvent(AnalyticsEvent.nutritionSupplementLogged, parameters: [
            AnalyticsParam.timeOfDay: timeOfDay,
            AnalyticsParam.supplementCount: supplementCount,
        ])
    }

    func logNutritionHydrationUpdated(waterMl: Int, targetMl: Int) {
        logEvent(AnalyticsEvent.nutritionHydrationUpdated, parameters: [
            AnalyticsParam.waterMl: waterMl,
            AnalyticsParam.targetMl: targetMl,
        ])
    }

    func logNutritionDateChanged(direction: String) {
        logEvent(AnalyticsEvent.nutritionDateChanged, parameters: [
            AnalyticsParam.direction: direction,
        ])
    }

    func logNutritionEmptyStateShown(section: String) {
        logEvent(AnalyticsEvent.nutritionEmptyStateShown, parameters: [
            AnalyticsParam.section: section,
        ])
    }

    // MARK: - Stats v2 Events (screen-prefixed)

    func logStatsPeriodChanged(period: String) {
        logEvent(AnalyticsEvent.statsPeriodChanged, parameters: [
            AnalyticsParam.period: period,
        ])
    }

    func logStatsMetricSelected(metricName: String, category: String) {
        logEvent(AnalyticsEvent.statsMetricSelected, parameters: [
            AnalyticsParam.metricName: metricName,
            AnalyticsParam.category: category,
        ])
    }

    func logStatsChartInteraction(metricName: String, interactionType: String) {
        logEvent(AnalyticsEvent.statsChartInteraction, parameters: [
            AnalyticsParam.metricName: metricName,
            AnalyticsParam.interactionType: interactionType,
        ])
    }

    func logStatsEmptyStateShown(metricName: String) {
        logEvent(AnalyticsEvent.statsEmptyStateShown, parameters: [
            AnalyticsParam.metricName: metricName,
        ])
    }

    // MARK: - Recovery Events

    func logBiometricLogged(metricType: String, source: String) {
        logEvent(AnalyticsEvent.biometricLog, parameters: [
            AnalyticsParam.metricType: metricType,
            AnalyticsParam.source: source,
        ])
    }

    // MARK: - Engagement Events

    func logStatsViewed(statType: String, timePeriod: String) {
        logEvent(AnalyticsEvent.statsView, parameters: [
            AnalyticsParam.statType: statType,
            AnalyticsParam.timePeriod: timePeriod,
        ])
    }

    func logStreakMaintained(streakLength: Int) {
        logEvent(AnalyticsEvent.streakMaintained, parameters: [
            AnalyticsParam.streakLength: streakLength,
        ])
    }

    func logGoalReached(goalType: String) {
        logEvent(AnalyticsEvent.goalReached, parameters: [
            AnalyticsParam.goalType: goalType,
        ])
    }

    func logCrossFeatureEngagement(featuresUsed: [String]) {
        logEvent(AnalyticsEvent.crossFeatureEngagement, parameters: [
            AnalyticsParam.featuresUsed: featuresUsed.joined(separator: ","),
        ])
    }

    // MARK: - Consent Events (always logged, bypass consent gate)

    func logConsentGranted(type: String) {
        provider.logEvent(AnalyticsEvent.consentGranted, parameters: [
            AnalyticsParam.consentType: type,
        ])
    }

    func logConsentDenied(type: String) {
        provider.logEvent(AnalyticsEvent.consentDenied, parameters: [
            AnalyticsParam.consentType: type,
        ])
    }

    // MARK: - GDPR Events

    func logAccountDeleteRequested(method: String) {
        logEvent(AnalyticsEvent.accountDeleteRequested, parameters: [
            AnalyticsParam.method: method,
        ])
    }

    func logAccountDeleteCompleted(storesDeleted: [String]) {
        logEvent(AnalyticsEvent.accountDeleteCompleted, parameters: [
            AnalyticsParam.storesDeleted: storesDeleted.joined(separator: ","),
        ])
    }

    func logAccountDeleteCancelled(daysRemaining: Int) {
        logEvent(AnalyticsEvent.accountDeleteCancelled, parameters: [
            AnalyticsParam.daysRemaining: daysRemaining,
        ])
    }

    func logDataExportRequested() {
        logEvent(AnalyticsEvent.dataExportRequested, parameters: nil)
    }

    func logDataExportCompleted(sizeBytes: Int, recordCount: Int) {
        logEvent(AnalyticsEvent.dataExportCompleted, parameters: [
            AnalyticsParam.sizeBytes: sizeBytes,
            AnalyticsParam.recordCount: recordCount,
        ])
    }

    // MARK: - Training Events

    /// User views the active training session screen
    func logTrainingSessionViewed(workoutType: String) {
        logEvent(AnalyticsEvent.trainingSessionViewed, parameters: [
            AnalyticsParam.workoutType: workoutType,
        ])
    }

    /// User starts an exercise within a training session
    func logTrainingExerciseStarted(exerciseName: String, muscleGroup: String) {
        logEvent(AnalyticsEvent.trainingExerciseStarted, parameters: [
            AnalyticsParam.exerciseName: exerciseName,
            AnalyticsParam.muscleGroup: muscleGroup,
        ])
    }

    /// User completes all sets for an exercise
    func logTrainingExerciseCompleted(exerciseName: String, sets: Int) {
        logEvent(AnalyticsEvent.trainingExerciseCompleted, parameters: [
            AnalyticsParam.exerciseName: exerciseName,
            AnalyticsParam.sets: sets,
        ])
    }

    /// User logs a single set
    func logTrainingSetLogged(exerciseName: String, setIndex: Int, reps: Int, weightKg: Double) {
        logEvent(AnalyticsEvent.trainingSetLogged, parameters: [
            AnalyticsParam.exerciseName: exerciseName,
            AnalyticsParam.setIndex: setIndex,
            AnalyticsParam.reps: reps,
            AnalyticsParam.weight: weightKg,
        ])
    }

    /// User copies previous set data
    func logTrainingSetCopied(exerciseName: String, setIndex: Int) {
        logEvent(AnalyticsEvent.trainingSetCopied, parameters: [
            AnalyticsParam.exerciseName: exerciseName,
            AnalyticsParam.setIndex: setIndex,
        ])
    }

    /// User changes weight for a set
    func logTrainingWeightChanged(exerciseName: String, weightKg: Double) {
        logEvent(AnalyticsEvent.trainingWeightChanged, parameters: [
            AnalyticsParam.exerciseName: exerciseName,
            AnalyticsParam.weight: weightKg,
        ])
    }

    /// User starts the rest timer between sets
    func logTrainingRestTimerStarted(restDurationSeconds: Int) {
        logEvent(AnalyticsEvent.trainingRestTimerStarted, parameters: [
            AnalyticsParam.restDurationSeconds: restDurationSeconds,
        ])
    }

    /// User skips the rest timer
    func logTrainingRestTimerSkipped(restDurationSeconds: Int) {
        logEvent(AnalyticsEvent.trainingRestTimerSkipped, parameters: [
            AnalyticsParam.restDurationSeconds: restDurationSeconds,
        ])
    }

    /// User switches between activities (e.g. exercise to cardio)
    func logTrainingActivitySwitched(activityType: String) {
        logEvent(AnalyticsEvent.trainingActivitySwitched, parameters: [
            AnalyticsParam.activityType: activityType,
        ])
    }

    /// User completes the full training session (conversion event)
    func logTrainingSessionCompleted(sessionDurationSeconds: Int, totalSets: Int, exerciseCount: Int) {
        logEvent(AnalyticsEvent.trainingSessionCompleted, parameters: [
            AnalyticsParam.sessionDurationSeconds: sessionDurationSeconds,
            AnalyticsParam.totalSets: totalSets,
            AnalyticsParam.exerciseCount: exerciseCount,
        ])
    }

    /// User enters focus mode during training
    func logTrainingFocusModeEntered() {
        logEvent(AnalyticsEvent.trainingFocusModeEntered, parameters: nil)
    }

    /// User opens camera for form check during training
    func logTrainingCameraOpened(exerciseName: String) {
        logEvent(AnalyticsEvent.trainingCameraOpened, parameters: [
            AnalyticsParam.exerciseName: exerciseName,
        ])
    }

    // MARK: - Home Events

    /// User taps an action on the Home screen
    func logHomeActionTap(actionType: String, dayType: String, hasRecommendation: Bool) {
        logEvent(AnalyticsEvent.homeActionTap, parameters: [
            AnalyticsParam.actionType: actionType,
            AnalyticsParam.workoutType: dayType,
            AnalyticsParam.hasRecommendation: hasRecommendation ? "true" : "false",
        ])
    }

    /// User completes a home-initiated action (conversion event)
    func logHomeActionCompleted(actionType: String, durationSeconds: Int) {
        logEvent(AnalyticsEvent.homeActionCompleted, parameters: [
            AnalyticsParam.actionType: actionType,
            AnalyticsParam.durationSeconds: durationSeconds,
            AnalyticsParam.source: "home",
        ])
    }

    /// Home screen shows an empty state
    func logHomeEmptyStateShown(emptyReason: String, ctaShown: String) {
        logEvent(AnalyticsEvent.homeEmptyStateShown, parameters: [
            AnalyticsParam.emptyReason: emptyReason,
            AnalyticsParam.ctaShown: ctaShown,
        ])
    }

    /// User taps the body composition card on the Home screen
    func logHomeBodyCompTap(hasWeight: Bool, hasBodyFat: Bool, progressPercent: Int) {
        logEvent(AnalyticsEvent.homeBodyCompTap, parameters: [
            AnalyticsParam.hasWeight: hasWeight ? "true" : "false",
            AnalyticsParam.hasBodyFat: hasBodyFat ? "true" : "false",
            AnalyticsParam.progressPercent: progressPercent,
        ])
    }

    /// User changes the period on the body composition card
    func logHomeBodyCompPeriodChanged(period: String) {
        logEvent(AnalyticsEvent.homeBodyCompPeriodChanged, parameters: [
            AnalyticsParam.period: period,
        ])
    }

    /// User taps the log CTA on the body composition card
    func logHomeBodyCompLogTap() {
        logEvent(AnalyticsEvent.homeBodyCompLogTap, parameters: nil)
    }

    /// User taps a metric tile on the Home screen to deep-link into Stats
    func logHomeMetricTileTap(metricType: String, hasValue: Bool) {
        logEvent(AnalyticsEvent.homeMetricTileTap, parameters: [
            AnalyticsParam.metricType: metricType,
            AnalyticsParam.hasValue: hasValue ? "true" : "false",
        ])
    }

    // MARK: - Settings Events

    func logSettingsChanged(settingName: String, newValue: String) {
        logEvent(AnalyticsEvent.settingsChanged, parameters: [
            AnalyticsParam.settingName: settingName,
            AnalyticsParam.settingValue: newValue,
        ])
    }

    // MARK: - User Identity & Properties

    func setUserID(_ id: String?) {
        guard consent.isAnalyticsAllowed else { return }
        provider.setUserID(id)
    }

    func updateUserProperties(
        trainingLevel: String? = nil,
        hasHealthKit: Bool? = nil,
        goalType: String? = nil,
        workoutFrequency: Int? = nil
    ) {
        guard consent.isAnalyticsAllowed else { return }
        if let level = trainingLevel {
            provider.setUserProperty(level, forName: AnalyticsUserProperty.trainingLevel)
        }
        if let hk = hasHealthKit {
            provider.setUserProperty(hk ? "true" : "false", forName: AnalyticsUserProperty.hasHealthKit)
        }
        if let goal = goalType {
            provider.setUserProperty(goal, forName: AnalyticsUserProperty.goalType)
        }
        if let freq = workoutFrequency {
            provider.setUserProperty(String(freq), forName: AnalyticsUserProperty.workoutFrequency)
        }
    }

    // MARK: - Private

    private func logEvent(_ name: String, parameters: [String: Any]?) {
        guard consent.isAnalyticsAllowed else { return }
        provider.logEvent(name, parameters: parameters)
    }
}
