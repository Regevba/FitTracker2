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
        let baseProvider: AnalyticsProvider = AnalyticsRuntimeConfiguration.canUseFirebase
            ? FirebaseAnalyticsAdapter()
            : MockAnalyticsAdapter()
        // Wrap with DebugSinkAdapter — transparent passthrough unless the
        // DEBUG_ANALYTICS=1 env var is set. Phase 2.A.3 of analytics-observability
        // per docs/master-plan/analytics-master-plan-2026-05-13.md §6.1.
        let provider = DebugSinkAdapter(wrapping: baseProvider)
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

    // MARK: - Settings v2 Events (screen-prefixed)

    func logSettingsSyncTriggered(syncType: String) {
        logEvent(AnalyticsEvent.settingsSyncTriggered, parameters: [
            AnalyticsParam.syncType: syncType,
        ])
    }

    func logSettingsConsentUpdated(consentType: String, granted: Bool) {
        logEvent(AnalyticsEvent.settingsConsentUpdated, parameters: [
            AnalyticsParam.consentType: consentType,
            AnalyticsParam.settingValue: granted ? "granted" : "denied",
        ])
    }

    func logSettingsDataDeleted(deleteScope: String) {
        logEvent(AnalyticsEvent.settingsDataDeleted, parameters: [
            AnalyticsParam.deleteScope: deleteScope,
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

    // MARK: - Readiness Events

    /// Readiness score computed on home load
    func logReadinessScoreComputed(score: Int, confidence: String, layer: Int, goalMode: String, componentCount: Int) {
        logEvent(AnalyticsEvent.homeReadinessScoreComputed, parameters: [
            AnalyticsParam.score: score,
            AnalyticsParam.confidence: confidence,
            AnalyticsParam.layer: layer,
            AnalyticsParam.goalMode: goalMode,
            AnalyticsParam.componentCount: componentCount,
        ])
    }

    /// User taps a readiness component mini-bar
    func logReadinessComponentTap(component: String) {
        logEvent(AnalyticsEvent.homeReadinessComponentTap, parameters: [
            AnalyticsParam.component: component,
        ])
    }

    /// Training recommendation shown
    func logReadinessRecommendationShown(recommendation: String) {
        logEvent(AnalyticsEvent.homeReadinessRecommendationShown, parameters: [
            AnalyticsParam.recommendation: recommendation,
        ])
    }

    // MARK: - AI Recommendation Events

    /// AI insight shown on home screen
    func logAiInsightShown(segment: String, confidence: String, sourceTier: String) {
        logEvent(AnalyticsEvent.homeAiInsightShown, parameters: [
            AnalyticsParam.segment: segment,
            AnalyticsParam.confidence: confidence,
            AnalyticsParam.sourceTier: sourceTier,
        ])
    }

    /// User taps AI insight card
    func logAiInsightTap(segment: String) {
        logEvent(AnalyticsEvent.homeAiInsightTap, parameters: [
            AnalyticsParam.segment: segment,
        ])
    }

    /// AI sheet opened
    func logAiSheetOpened(entryPoint: String) {
        logEvent(AnalyticsEvent.aiSheetOpened, parameters: [
            AnalyticsParam.entryPoint: entryPoint,
        ])
    }

    /// User views a recommendation
    func logAiRecommendationViewed(segment: String, confidence: String) {
        logEvent(AnalyticsEvent.aiRecommendationViewed, parameters: [
            AnalyticsParam.segment: segment,
            AnalyticsParam.confidence: confidence,
        ])
    }

    /// User submits feedback
    func logAiFeedbackSubmitted(segment: String, rating: String) {
        logEvent(AnalyticsEvent.aiFeedbackSubmitted, parameters: [
            AnalyticsParam.segment: segment,
            AnalyticsParam.rating: rating,
        ])
    }

    /// AI avatar state changes
    func logAiAvatarStateChanged(fromState: String, toState: String) {
        logEvent(AnalyticsEvent.aiAvatarStateChanged, parameters: [
            AnalyticsParam.fromState: fromState,
            AnalyticsParam.toState: toState,
        ])
    }

    // MARK: - C2 Readiness-Aware Training Alert Events

    /// Readiness-aware advisory shown on home insight card
    func logHomeReadinessAlertShown(recommendation: String, score: Int, drivingComponent: String) {
        logEvent(AnalyticsEvent.homeReadinessAlertShown, parameters: [
            AnalyticsParam.recommendation: recommendation,
            AnalyticsParam.score: score,
            AnalyticsParam.drivingComponent: drivingComponent,
        ])
    }

    /// User taps the readiness-aware insight card
    func logHomeReadinessAlertTap(recommendation: String) {
        logEvent(AnalyticsEvent.homeReadinessAlertTap, parameters: [
            AnalyticsParam.recommendation: recommendation,
        ])
    }

    /// User picks a CTA in the readiness-aware sheet banner
    func logHomeReadinessAlertActionTaken(recommendation: String, chosen: String) {
        logEvent(AnalyticsEvent.homeReadinessAlertActionTaken, parameters: [
            AnalyticsParam.recommendation: recommendation,
            AnalyticsParam.chosen: chosen,
        ])
    }

    /// Readiness-aware advisory dismissed without CTA pick (sheet closed)
    func logHomeReadinessAlertDismissed(recommendation: String) {
        logEvent(AnalyticsEvent.homeReadinessAlertDismissed, parameters: [
            AnalyticsParam.recommendation: recommendation,
        ])
    }

    // MARK: - C4 Sustained-Trend HRV Alert Events

    /// Sustained-trend advisory shown on home insight card
    func logHomeTrendAlertShown(kind: String, sustainedDays: Int, baseline: Int, floor: Int) {
        logEvent(AnalyticsEvent.homeTrendAlertShown, parameters: [
            AnalyticsParam.kind: kind,
            AnalyticsParam.sustainedDays: sustainedDays,
            AnalyticsParam.baseline: baseline,
            AnalyticsParam.floor: floor,
        ])
    }

    /// User taps the sustained-trend insight card
    func logHomeTrendAlertTap(kind: String) {
        logEvent(AnalyticsEvent.homeTrendAlertTap, parameters: [
            AnalyticsParam.kind: kind,
        ])
    }

    /// User picks thumbs-up / thumbs-down feedback in the "Your HRV Trend" sheet
    func logHomeTrendAlertActionTaken(kind: String, rating: String) {
        logEvent(AnalyticsEvent.homeTrendAlertActionTaken, parameters: [
            AnalyticsParam.kind: kind,
            AnalyticsParam.rating: rating,
        ])
    }

    /// Sustained-trend advisory dismissed without feedback pick
    func logHomeTrendAlertDismissed(kind: String) {
        logEvent(AnalyticsEvent.homeTrendAlertDismissed, parameters: [
            AnalyticsParam.kind: kind,
        ])
    }

    // MARK: - C5 AI User Feedback Loop Events

    /// AIOrchestrator reinforcement-loop block suppressed a signal (user dismissed it >=3 times within 30 days)
    func logHomeAiFeedbackSignalSuppressed(segment: String, signal: String, dismissalCount: Int) {
        logEvent(AnalyticsEvent.homeAiFeedbackSignalSuppressed, parameters: [
            AnalyticsParam.segment: segment,
            AnalyticsParam.signal: signal,
            AnalyticsParam.dismissalCount: dismissalCount,
        ])
    }

    /// AIOrchestrator reinforcement-loop block boosted a segment's confidence (acceptanceRate > 0.70 with >=5 outcomes)
    func logHomeAiFeedbackSegmentBoosted(segment: String, acceptanceRate: Int, outcomeCount: Int) {
        logEvent(AnalyticsEvent.homeAiFeedbackSegmentBoosted, parameters: [
            AnalyticsParam.segment: segment,
            AnalyticsParam.acceptanceRate: acceptanceRate,
            AnalyticsParam.outcomeCount: outcomeCount,
        ])
    }

    /// User taps "Clear feedback history" in Settings → AI Feedback
    func logHomeAiFeedbackHistoryCleared(totalOutcomesCleared: Int) {
        logEvent(AnalyticsEvent.homeAiFeedbackHistoryCleared, parameters: [
            AnalyticsParam.totalOutcomesCleared: totalOutcomesCleared,
        ])
    }

    // MARK: - C3 Exercise Library Events

    /// User opens the Exercise Library sheet (Training tab toolbar or Settings row)
    func logTrainingExerciseLibraryOpened(source: String) {
        logEvent(AnalyticsEvent.trainingExerciseLibraryOpened, parameters: [
            AnalyticsParam.source: source,
        ])
    }

    /// User commits a search query (>= 2 chars; not per-keypress)
    func logTrainingExerciseSearchQuery(queryLength: Int) {
        logEvent(AnalyticsEvent.trainingExerciseSearchQuery, parameters: [
            AnalyticsParam.queryLength: queryLength,
        ])
    }

    /// User taps a filter chip — dimension is one of "muscle"/"equipment"/"category"
    func logTrainingExerciseFilterTapped(dimension: String, value: String) {
        logEvent(AnalyticsEvent.trainingExerciseFilterTapped, parameters: [
            AnalyticsParam.dimension: dimension,
            AnalyticsParam.chipValue: value,
        ])
    }

    /// User taps a result row → detail view pushes (read-only) OR picker fires (picker mode)
    func logTrainingExerciseDetailOpened(exerciseId: String, viaSearch: Bool, viaFilter: Bool) {
        logEvent(AnalyticsEvent.trainingExerciseDetailOpened, parameters: [
            AnalyticsParam.exerciseId: exerciseId,
            AnalyticsParam.viaSearch: viaSearch,
            AnalyticsParam.viaFilter: viaFilter,
        ])
    }

    // MARK: - C6 Custom Training Programs Events

    /// User opens the program list (Settings → Customize Program)
    func logTrainingCustomProgramListOpened(count: Int) {
        logEvent(AnalyticsEvent.trainingCustomProgramListOpened, parameters: [
            AnalyticsParam.count: count,
        ])
    }

    /// User picks a template tile in NewProgramSheet
    func logTrainingCustomProgramTemplateSelected(templateId: String) {
        logEvent(AnalyticsEvent.trainingCustomProgramTemplateSelected, parameters: [
            AnalyticsParam.templateId: templateId,
        ])
    }

    /// User saves a program in the editor (or initial template-pick)
    func logTrainingCustomProgramSaved(programId: String, dayCount: Int, totalExerciseCount: Int) {
        logEvent(AnalyticsEvent.trainingCustomProgramSaved, parameters: [
            AnalyticsParam.programId: programId,
            AnalyticsParam.dayCount: dayCount,
            AnalyticsParam.totalExerciseCount: totalExerciseCount,
        ])
    }

    /// User activates a saved program
    func logTrainingCustomProgramActivated(programId: String) {
        logEvent(AnalyticsEvent.trainingCustomProgramActivated, parameters: [
            AnalyticsParam.programId: programId,
        ])
    }

    /// User confirms swipe-to-delete on a program
    func logTrainingCustomProgramDeleted(programId: String, dayCount: Int) {
        logEvent(AnalyticsEvent.trainingCustomProgramDeleted, parameters: [
            AnalyticsParam.programId: programId,
            AnalyticsParam.dayCount: dayCount,
        ])
    }

    /// User edits a day's name / DayType / weekday — fires once per field changed
    func logTrainingDayEdited(dayId: String, field: String) {
        logEvent(AnalyticsEvent.trainingDayEdited, parameters: [
            AnalyticsParam.dayId: dayId,
            AnalyticsParam.field: field,
        ])
    }

    /// User adds an exercise slot to a day (via C3 picker callback)
    func logTrainingExerciseSlotAdded(exerciseId: String, dayId: String, overrideCount: Int) {
        logEvent(AnalyticsEvent.trainingExerciseSlotAdded, parameters: [
            AnalyticsParam.exerciseId: exerciseId,
            AnalyticsParam.dayId: dayId,
            AnalyticsParam.overrideCount: overrideCount,
        ])
    }

    /// User removes an exercise slot from a day
    func logTrainingExerciseSlotRemoved(exerciseId: String, dayId: String) {
        logEvent(AnalyticsEvent.trainingExerciseSlotRemoved, parameters: [
            AnalyticsParam.exerciseId: exerciseId,
            AnalyticsParam.dayId: dayId,
        ])
    }

    // MARK: - Onboarding Auth Events

    func logOnboardingAuthMethodSelected(method: String) {
        logEvent(AnalyticsEvent.onboardingAuthMethodSelected, parameters: [
            AnalyticsParam.method: method,
        ])
    }

    func logOnboardingAuthCompleted(method: String, isNewAccount: Bool) {
        logEvent(AnalyticsEvent.onboardingAuthCompleted, parameters: [
            AnalyticsParam.method: method,
            AnalyticsParam.isNewAccount: isNewAccount ? "true" : "false",
        ])
    }

    func logOnboardingAuthFailed(method: String, errorType: String) {
        logEvent(AnalyticsEvent.onboardingAuthFailed, parameters: [
            AnalyticsParam.method: method,
            AnalyticsParam.errorType: errorType,
        ])
    }

    func logOnboardingSuccessShown() {
        logEvent(AnalyticsEvent.onboardingSuccessShown, parameters: [:])
    }

    func logSessionRestoreResult(result: String, timeMs: Int) {
        logEvent(AnalyticsEvent.sessionRestoreResult, parameters: [
            AnalyticsParam.result: result,
            AnalyticsParam.restoreTimeMs: "\(timeMs)",
        ])
    }

    // MARK: - Settings Events

    func logSettingsChanged(settingName: String, newValue: String) {
        logEvent(AnalyticsEvent.settingsChanged, parameters: [
            AnalyticsParam.settingName: settingName,
            AnalyticsParam.settingValue: newValue,
        ])
    }

    // MARK: - Import Analytics

    /// Entry point for `import_started` (per PRD v2 Analytics Spec).
    enum ImportEntryPoint: String {
        case settingsData  = "settings_data"
        case trainingTab   = "training_tab"
        case onboarding    = "onboarding"
    }

    /// User initiates the import flow. `entryPoint` is now required per PRD v2.
    func logImportStarted(entryPoint: ImportEntryPoint) {
        logEvent(AnalyticsEvent.importStarted, parameters: [
            "entry_point": entryPoint.rawValue,
        ])
    }

    /// User selects an import source (e.g. "csv", "json", "markdown_paste", "pdf")
    func logImportSourceSelected(source: String) {
        logEvent(AnalyticsEvent.importSourceSelected, parameters: [AnalyticsParam.itemCategory: source])
    }

    /// Parser successfully produced a structured plan.
    func logImportParsed(source: String, exerciseCount: Int, dayCount: Int, parseDurationMs: Int) {
        logEvent(AnalyticsEvent.importParsed, parameters: [
            AnalyticsParam.itemCategory: source,
            AnalyticsParam.quantity: exerciseCount,
            "day_count": dayCount,
            "parse_duration_ms": parseDurationMs,
        ])
    }

    /// Parser threw or returned empty result. Distinct from `import_failed`
    /// (the user-cancelled / unrecoverable umbrella).
    func logImportParseFailed(source: String, reason: String) {
        logEvent(AnalyticsEvent.importParseFailed, parameters: [
            AnalyticsParam.itemCategory: source,
            "error_reason": reason,
        ])
    }

    /// User confirmed the mapping on the preview screen.
    func logImportMappingConfirmed(autoMatched: Int, manualConfirmed: Int, skipped: Int, unresolved: Int) {
        logEvent(AnalyticsEvent.importMappingConfirmed, parameters: [
            "auto_matched_count": autoMatched,
            "manual_confirmed_count": manualConfirmed,
            "skipped_count": skipped,
            "unresolved_count": unresolved,
        ])
    }

    /// Plan persisted to EncryptedDataStore. Fires after `persistToDisk()` returns success.
    func logImportCompleted(source: String, totalExercises: Int, skippedExercises: Int, timeToCompleteMs: Int) {
        logEvent(AnalyticsEvent.importCompleted, parameters: [
            AnalyticsParam.itemCategory: source,
            AnalyticsParam.quantity: totalExercises,
            "skipped_exercises": skippedExercises,
            "time_to_complete_ms": timeToCompleteMs,
        ])
    }

    /// Import aborted (cancelled or unrecoverable). `step`: parse / mapping / save.
    func logImportFailed(source: String, step: String, reason: String) {
        logEvent(AnalyticsEvent.importFailed, parameters: [
            AnalyticsParam.itemCategory: source,
            "step": step,
            "error_reason": reason,
        ])
    }

    /// User opened an imported plan from the Imported Plans list. `daysSinceImport`
    /// is computed at call time; `< 7` is the adoption-window for plan adoption rate.
    func logImportPlanOpened(daysSinceImport: Int, source: String) {
        logEvent(AnalyticsEvent.importPlanOpened, parameters: [
            "days_since_import": daysSinceImport,
            AnalyticsParam.itemCategory: source,
        ])
    }

    /// User flipped an imported plan to isActive=true. PRIMARY conversion signal.
    /// `wasFirstActivation` distinguishes first-ever activate from re-activate.
    func logImportPlanActivated(source: String, daysSinceImport: Int, wasFirstActivation: Bool) {
        logEvent(AnalyticsEvent.importPlanActivated, parameters: [
            AnalyticsParam.itemCategory: source,
            "days_since_import": daysSinceImport,
            "was_first_activation": wasFirstActivation,
        ])
    }

    // MARK: - Profile Events

    /// Profile tab viewed
    func logProfileTabViewed(source: String) {
        logEvent(AnalyticsEvent.profileTabViewed, parameters: [
            AnalyticsParam.source: source,
        ])
    }

    /// Profile goal or preference changed
    func logProfileGoalChanged(field: String, oldValue: String, newValue: String) {
        logEvent(AnalyticsEvent.profileGoalChanged, parameters: [
            AnalyticsParam.field: field,
            AnalyticsParam.oldValue: oldValue,
            AnalyticsParam.newValue: newValue,
        ])
    }

    /// Settings section opened within Profile
    func logProfileSettingsSectionOpened(section: String) {
        logEvent(AnalyticsEvent.profileSettingsSectionOpened, parameters: [
            AnalyticsParam.section: section,
        ])
    }

    /// Readiness snapshot tapped in Profile
    func logProfileReadinessTap() {
        logEvent(AnalyticsEvent.profileReadinessTap, parameters: nil)
    }

    /// Body composition card tapped in Profile
    func logProfileBodyCompTap() {
        logEvent(AnalyticsEvent.profileBodyCompTap, parameters: nil)
    }

    /// Avatar tapped in Profile
    func logProfileAvatarTap() {
        logEvent(AnalyticsEvent.profileAvatarTap, parameters: nil)
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

    // MARK: - Notification Analytics

    func logNotificationPermissionRequested() {
        logEvent(AnalyticsEvent.notificationPermissionRequested, parameters: nil)
    }

    func logNotificationPermissionResult(granted: Bool) {
        logEvent(granted ? AnalyticsEvent.notificationPermissionGranted : AnalyticsEvent.notificationPermissionDenied, parameters: nil)
    }

    // Removed 2026-05-07 (push-notifications-v2 T11): logNotificationScheduled,
    // logNotificationTapped — duplicates of the live logReminderScheduled /
    // logReminderTapped. Smart-reminders owns scheduling lifecycle; the
    // push-notifications-v2 platform layer owns priming + permission + deep-link.
    // Zero callers outside this file before deletion (verified by grep).

    /// Priming sheet view event (push-notifications-v2 PN-12).
    /// `triggerContext` is "post_workout" or "settings" — matches PrimingView.TriggerContext.
    func logNotificationPrimingShown(triggerContext: String) {
        logEvent(AnalyticsEvent.notificationPrimingShown, parameters: [
            AnalyticsParam.triggerContext: triggerContext,
        ])
    }

    /// User taps "Not now" or swipes-down to dismiss the priming sheet (no OS dialog fired).
    func logNotificationPrimingSkipped(triggerContext: String) {
        logEvent(AnalyticsEvent.notificationPrimingSkipped, parameters: [
            AnalyticsParam.triggerContext: triggerContext,
        ])
    }

    /// SettingsDeepLinkBanner appeared at top of Home (one-time per device lifetime).
    func logNotificationSettingsDeeplinkShown() {
        logEvent(AnalyticsEvent.notificationSettingsDeeplinkShown, parameters: nil)
    }

    /// DeepLinkRouter resolved a URL — fires on every routing attempt regardless of
    /// outcome. The kill criterion is `outcome=succeeded` rate < 95% over 7 days.
    /// `source` is "notification"|"url"|"programmatic"; `destination` is
    /// "tab"|"sheet"|"auth"|"settings"; `outcome` is "succeeded"|"failed_no_pattern_match"|"failed_navigation".
    func logDeepLinkRouted(source: String, destination: String, urlPattern: String, outcome: String) {
        logEvent(AnalyticsEvent.deepLinkRouted, parameters: [
            AnalyticsParam.deepLinkSource: source,
            AnalyticsParam.destination: destination,
            AnalyticsParam.urlPattern: urlPattern,
            AnalyticsParam.outcome: outcome,
        ])
    }

    // MARK: - Reminder Analytics

    /// Smart reminder notification was scheduled by ReminderScheduler
    func logReminderScheduled(type: String) {
        logEvent(AnalyticsEvent.reminderScheduled, parameters: [AnalyticsParam.itemCategory: type])
    }

    /// User tapped a smart reminder notification (deep-link fired)
    func logReminderTapped(type: String) {
        logEvent(AnalyticsEvent.reminderTapped, parameters: [AnalyticsParam.itemCategory: type])
    }

    /// Smart reminder was suppressed by a frequency/quiet-hour guard
    func logReminderSuppressed(type: String, reason: String) {
        logEvent(AnalyticsEvent.reminderSuppressed, parameters: [
            AnalyticsParam.itemCategory: type,
            "reason": reason,
        ])
    }

    // MARK: - Auth Password Reset Events (auth-polish-v2 A5)

    /// Fired when the user successfully submits the "Send reset link" form on
    /// `forgot_password`. Drives the funnel denominator for password recovery.
    func logAuthPasswordResetRequested(emailProvided: Bool) {
        logEvent(AnalyticsEvent.authPasswordResetRequested, parameters: [
            AnalyticsParam.emailProvided: emailProvided,
        ])
    }

    /// Fired when the user successfully updates their password on
    /// `set_new_password`. Conversion event — funnel numerator.
    func logAuthPasswordResetCompleted(timeToCompleteSeconds: Int) {
        logEvent(AnalyticsEvent.authPasswordResetCompleted, parameters: [
            AnalyticsParam.timeToCompleteSeconds: timeToCompleteSeconds,
        ])
    }

    /// Fired when the user taps Resend on `email_sent_confirmation` after the
    /// 60s cooldown elapsed. `attemptNumber` is 2 for the first resend, 3 for
    /// the second, etc.
    func logAuthPasswordResetResend(attemptNumber: Int) {
        logEvent(AnalyticsEvent.authPasswordResetResend, parameters: [
            AnalyticsParam.attemptNumber: attemptNumber,
        ])
    }

    /// Fired when the user taps Resend on `email_sent_confirmation` while the
    /// cooldown is still active. PRD guardrail metric: rate < 5%.
    func logAuthPasswordResetResendBlocked(cooldownRemainingSeconds: Int) {
        logEvent(AnalyticsEvent.authPasswordResetResendBlocked, parameters: [
            AnalyticsParam.cooldownRemainingSeconds: cooldownRemainingSeconds,
        ])
    }

    // MARK: - Auth Biometric Events (auth-polish-v2 B4)

    /// Fired when BiometricActivationSheet appears on first sign-in.
    func logAuthBiometricActivationOffered(biometricType: String) {
        logEvent(AnalyticsEvent.authBiometricActivationOffered, parameters: [
            AnalyticsParam.biometricType: biometricType,
        ])
    }

    /// Fired when the user successfully completes the activation scan.
    /// Conversion event — primary metric numerator.
    func logAuthBiometricActivated(biometricType: String, provider: String) {
        logEvent(AnalyticsEvent.authBiometricActivated, parameters: [
            AnalyticsParam.biometricType: biometricType,
            AnalyticsParam.provider: provider,
        ])
    }

    /// Fired when the user taps "Not now" or cancels the activation scan.
    func logAuthBiometricActivationDeclined(biometricType: String) {
        logEvent(AnalyticsEvent.authBiometricActivationDeclined, parameters: [
            AnalyticsParam.biometricType: biometricType,
        ])
    }

    /// Fired when BiometricUnlockView completes an unlock scan successfully.
    /// `durationMs` measured from scan start to result, drives PRD §guardrail
    /// "P95 < 1500ms".
    func logAuthBiometricUnlockCompleted(biometricType: String, durationMs: Int) {
        logEvent(AnalyticsEvent.authBiometricUnlockCompleted, parameters: [
            AnalyticsParam.biometricType: biometricType,
            AnalyticsParam.durationMs: durationMs,
        ])
    }

    /// Fired when BiometricUnlockView's scan fails. `reason` enum:
    /// "user_cancel" | "biometry_failed" | "system_cancel" | "passcode_not_set" | "other".
    func logAuthBiometricUnlockFailed(biometricType: String, reason: String) {
        logEvent(AnalyticsEvent.authBiometricUnlockFailed, parameters: [
            AnalyticsParam.biometricType: biometricType,
            AnalyticsParam.reason: reason,
        ])
    }

    // MARK: - Smart Reminder Events (smart-reminders)

    /// Smart reminder banner was presented (foreground or lock-screen)
    func logReminderShown(type: String) {
        logEvent(AnalyticsEvent.reminderShown, parameters: [AnalyticsParam.itemCategory: type])
    }

    /// User dismissed a smart reminder without tapping into the app
    func logReminderDismissed(type: String) {
        logEvent(AnalyticsEvent.reminderDismissed, parameters: [AnalyticsParam.itemCategory: type])
    }

    /// A reminder type was disabled (user cancelled the type, or scheduler
    /// hit a permanent-stop / lifetime cap and removed pending requests)
    func logReminderDisabled(type: String, reason: String) {
        logEvent(AnalyticsEvent.reminderDisabled, parameters: [
            AnalyticsParam.itemCategory: type,
            "reason": reason,
        ])
    }

    // MARK: - Private

    private func logEvent(_ name: String, parameters: [String: Any]?) {
        guard consent.isAnalyticsAllowed else { return }
        provider.logEvent(name, parameters: parameters)
    }
}
