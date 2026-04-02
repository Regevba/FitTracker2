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
        #if DEBUG
        let provider = MockAnalyticsAdapter()
        #else
        let provider = FirebaseAnalyticsAdapter()
        #endif
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
