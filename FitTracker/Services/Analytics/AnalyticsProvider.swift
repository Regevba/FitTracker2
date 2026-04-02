// Services/Analytics/AnalyticsProvider.swift
// Protocol abstraction for analytics providers (GA4, TelemetryDeck, Mock, etc.)
// Swap implementations without changing call sites.

import Foundation

protocol AnalyticsProvider {
    func configure()
    func logEvent(_ name: String, parameters: [String: Any]?)
    func logScreenView(_ screenName: String, screenClass: String?)
    func setUserProperty(_ value: String?, forName name: String)
    func setUserID(_ id: String?)
    func setConsent(analyticsStorage: Bool, adStorage: Bool)
}

// MARK: - Event Constants

enum AnalyticsEvent {
    // Workout
    static let startWorkout      = "start_workout"
    static let completeWorkout   = "complete_workout"
    static let logExercise       = "log_exercise"
    static let recordPR          = "record_pr"

    // Nutrition
    static let logMeal           = "log_meal"
    static let logSupplement     = "log_supplement"

    // Recovery
    static let logBiometric      = "log_biometric"

    // Engagement
    static let viewStats         = "view_stats"
    static let shareWorkout      = "share_workout"
    static let crossFeatureAction = "cross_feature_action"

    // Auth
    static let signIn            = "sign_in"
    static let signUp            = "sign_up"

    // Consent
    static let consentGranted    = "consent_granted"
    static let consentDenied     = "consent_denied"

    // Settings
    static let settingsChanged   = "settings_changed"
}

enum AnalyticsScreen {
    static let home              = "home"
    static let trainingPlan      = "training_plan"
    static let activeWorkout     = "active_workout"
    static let exerciseDetail    = "exercise_detail"
    static let nutrition         = "nutrition"
    static let mealEntry         = "meal_entry"
    static let supplements       = "supplements"
    static let recovery          = "recovery"
    static let biometricsEntry   = "biometrics_entry"
    static let stats             = "stats"
    static let chartDetail       = "chart_detail"
    static let prRecords         = "pr_records"
    static let settings          = "settings"
    static let settingsAccount   = "settings_account"
    static let settingsData      = "settings_data"
    static let settingsAppearance = "settings_appearance"
    static let settingsNotifications = "settings_notifications"
    static let settingsAbout     = "settings_about"
    static let signInScreen      = "sign_in"
    static let signUpScreen      = "sign_up"
    static let profile           = "profile"
    static let readiness         = "readiness"
    static let consent           = "consent"
}

enum AnalyticsUserProperty {
    static let trainingLevel     = "training_level"
    static let hasHealthKit      = "has_healthkit"
    static let consentStatus     = "consent_status"
    static let appVersion        = "app_version"
}
