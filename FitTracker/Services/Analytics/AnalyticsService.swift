// Services/Analytics/AnalyticsService.swift
// Main analytics orchestrator. Owns the provider and consent manager.
// Injected as @EnvironmentObject throughout the app.
// All public methods gate on consent before forwarding to the provider.

import Foundation
import SwiftUI

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

    /// Convenience initializer for production (Firebase) or debug (Mock)
    static func makeDefault() -> AnalyticsService {
        let consent = ConsentManager()
        #if DEBUG
        let provider = MockAnalyticsAdapter()
        #else
        let provider = FirebaseAnalyticsAdapter()
        #endif
        return AnalyticsService(provider: provider, consent: consent)
    }

    // MARK: - Consent Sync

    /// Sync consent state to the analytics provider
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

    // MARK: - Workout Events

    func logWorkoutStarted(workoutType: String, dayNumber: Int) {
        logEvent(AnalyticsEvent.startWorkout, parameters: [
            "workout_type": workoutType,
            "day_number": dayNumber,
        ])
    }

    func logWorkoutCompleted(durationMins: Int, exercisesCount: Int, setsCount: Int) {
        logEvent(AnalyticsEvent.completeWorkout, parameters: [
            "duration_mins": durationMins,
            "exercises_count": exercisesCount,
            "sets_count": setsCount,
        ])
    }

    func logExerciseLogged(name: String, muscleGroup: String, sets: Int, reps: Int, weightKg: Double) {
        logEvent(AnalyticsEvent.logExercise, parameters: [
            "exercise_name": name,
            "muscle_group": muscleGroup,
            "sets": sets,
            "reps": reps,
            "weight_kg": weightKg,
        ])
    }

    func logPRRecorded(exerciseName: String, prType: String) {
        logEvent(AnalyticsEvent.recordPR, parameters: [
            "exercise_name": exerciseName,
            "pr_type": prType,
        ])
    }

    // MARK: - Nutrition Events

    func logMealLogged(mealType: String, entryMethod: String) {
        logEvent(AnalyticsEvent.logMeal, parameters: [
            "meal_type": mealType,
            "entry_method": entryMethod,
        ])
    }

    func logSupplementLogged(timeOfDay: String, count: Int) {
        logEvent(AnalyticsEvent.logSupplement, parameters: [
            "time_of_day": timeOfDay,
            "count": count,
        ])
    }

    // MARK: - Recovery Events

    func logBiometricLogged(metricType: String, source: String) {
        logEvent(AnalyticsEvent.logBiometric, parameters: [
            "metric_type": metricType,
            "source": source,
        ])
    }

    // MARK: - Engagement Events

    func logStatsViewed(statType: String, timePeriod: String) {
        logEvent(AnalyticsEvent.viewStats, parameters: [
            "stat_type": statType,
            "time_period": timePeriod,
        ])
    }

    func logWorkoutShared(method: String) {
        logEvent(AnalyticsEvent.shareWorkout, parameters: [
            "share_method": method,
        ])
    }

    func logCrossFeatureAction(featuresUsed: [String]) {
        logEvent(AnalyticsEvent.crossFeatureAction, parameters: [
            "features_used": featuresUsed.joined(separator: ","),
        ])
    }

    // MARK: - Auth Events

    func logSignIn(method: String) {
        logEvent(AnalyticsEvent.signIn, parameters: ["method": method])
    }

    func logSignUp(method: String) {
        logEvent(AnalyticsEvent.signUp, parameters: ["method": method])
    }

    // MARK: - Consent Events (always logged, even before consent, for consent rate tracking)

    func logConsentGranted(type: String) {
        provider.logEvent(AnalyticsEvent.consentGranted, parameters: ["consent_type": type])
    }

    func logConsentDenied(type: String) {
        provider.logEvent(AnalyticsEvent.consentDenied, parameters: ["consent_type": type])
    }

    // MARK: - Settings Events

    func logSettingsChanged(settingName: String, newValue: String) {
        logEvent(AnalyticsEvent.settingsChanged, parameters: [
            "setting_name": settingName,
            "new_value": newValue,
        ])
    }

    // MARK: - User Properties

    func setUserID(_ id: String?) {
        guard consent.isAnalyticsAllowed else { return }
        provider.setUserID(id)
    }

    func updateUserProperties(trainingLevel: String? = nil, hasHealthKit: Bool? = nil) {
        guard consent.isAnalyticsAllowed else { return }
        if let level = trainingLevel {
            provider.setUserProperty(level, forName: AnalyticsUserProperty.trainingLevel)
        }
        if let hk = hasHealthKit {
            provider.setUserProperty(hk ? "true" : "false", forName: AnalyticsUserProperty.hasHealthKit)
        }
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            provider.setUserProperty(version, forName: AnalyticsUserProperty.appVersion)
        }
    }

    // MARK: - Private

    private func logEvent(_ name: String, parameters: [String: Any]?) {
        guard consent.isAnalyticsAllowed else { return }
        provider.logEvent(name, parameters: parameters)
    }
}
