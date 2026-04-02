// Services/Analytics/AnalyticsProvider.swift
// Protocol abstraction for analytics providers (GA4, TelemetryDeck, Mock, etc.)
// Swap implementations without changing call sites.
//
// Naming conventions (GA4 2025):
// - Events: snake_case, max 40 chars, no ga_/firebase_/google_ prefix
// - Parameters: snake_case, max 40 chars, values max 100 chars, max 25 per event
// - User properties: max 25 custom, no PII, no high-cardinality fields
// - Use GA4 recommended events where available (login, sign_up, share, select_content)
// - Register all custom parameters as custom dimensions/metrics in GA4 UI

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
// Uses GA4 recommended events where available, custom events where not.
// Reference: https://developers.google.com/analytics/devguides/collection/ga4/reference/events

enum AnalyticsEvent {

    // ── GA4 Recommended Events ──────────────────────────────

    /// User logs in (GA4 recommended: "login")
    static let login             = "login"
    /// User creates account (GA4 recommended: "sign_up")
    static let signUp            = "sign_up"
    /// User shares content (GA4 recommended: "share")
    static let share             = "share"
    /// User views/selects content (GA4 recommended: "select_content")
    static let selectContent     = "select_content"
    /// User begins onboarding (GA4 recommended: "tutorial_begin")
    static let tutorialBegin     = "tutorial_begin"
    /// User completes onboarding (GA4 recommended: "tutorial_complete")
    static let tutorialComplete  = "tutorial_complete"

    // ── Workout Events (custom) ─────────────────────────────

    /// User starts a workout session
    static let workoutStart      = "workout_start"
    /// User completes a workout session (mark as conversion in GA4)
    static let workoutComplete   = "workout_complete"
    /// User logs an exercise set
    static let exerciseLog       = "exercise_log"
    /// System detects a new personal record
    static let prAchieved        = "pr_achieved"

    // ── Nutrition Events (custom) ───────────────────────────

    /// User logs a meal (mark as conversion in GA4)
    static let mealLog           = "meal_log"
    /// User checks off supplements
    static let supplementLog     = "supplement_log"

    // ── Recovery Events (custom) ────────────────────────────

    /// User logs a biometric entry
    static let biometricLog      = "biometric_log"

    // ── Engagement Events (custom) ──────────────────────────

    /// User views stats/progress screen with filters
    static let statsView         = "stats_view"
    /// User maintains a streak (daily/weekly)
    static let streakMaintained  = "streak_maintained"
    /// User reaches a defined goal
    static let goalReached       = "goal_reached"
    /// User performs cross-feature action (train + meal in same day)
    static let crossFeatureEngagement = "cross_feature_engagement"

    // ── Consent Events (custom) ─────────────────────────────
    // These are always logged (even pre-consent) for consent rate measurement.

    /// User grants analytics consent
    static let consentGranted    = "consent_granted"
    /// User denies analytics consent
    static let consentDenied     = "consent_denied"

    // ── Settings Events (custom) ────────────────────────────

    /// User changes a setting
    static let settingsChanged   = "settings_changed"
}

// MARK: - Parameter Constants
// GA4 recommended parameter names where available.
// Reference: https://developers.google.com/analytics/devguides/collection/ga4/reference/events

enum AnalyticsParam {
    // GA4 recommended parameters
    static let method            = "method"           // login, sign_up
    static let contentType       = "content_type"     // share, select_content
    static let itemId            = "item_id"          // select_content

    // Workout parameters
    static let workoutType       = "workout_type"     // push/pull/legs/cardio/rest
    static let dayNumber         = "day_number"       // program day (1-6)
    static let durationSeconds   = "duration_seconds"  // int, SI unit (not minutes)
    static let exerciseCount     = "exercise_count"
    static let setCount          = "set_count"

    // Exercise parameters
    static let exerciseName      = "exercise_name"
    static let muscleGroup       = "muscle_group"
    static let sets              = "sets"
    static let reps              = "reps"
    static let weight            = "weight"           // always kg (SI), no unit suffix
    static let prType            = "pr_type"          // weight/reps/volume

    // Nutrition parameters
    static let mealType          = "meal_type"        // breakfast/lunch/dinner/snack
    static let entryMethod       = "entry_method"     // manual/template/photo/barcode
    static let timeOfDay         = "time_of_day"      // am/pm
    static let count             = "count"

    // Recovery parameters
    static let metricType        = "metric_type"      // weight/hrv/rhr/sleep/body_fat
    static let source            = "source"           // manual/healthkit

    // Engagement parameters
    static let statType          = "stat_type"
    static let timePeriod        = "time_period"      // week/month/quarter/year/all
    static let streakLength      = "streak_length"    // days
    static let goalType          = "goal_type"        // weight/strength/nutrition
    static let featuresUsed      = "features_used"    // comma-separated list

    // Settings parameters
    static let settingName       = "setting_name"
    static let settingValue      = "setting_value"

    // Consent parameters
    static let consentType       = "consent_type"     // gdpr/att
}

// MARK: - Screen Constants

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
    static let signIn            = "sign_in"
    static let signUpScreen      = "sign_up"
    static let profile           = "profile"
    static let readiness         = "readiness"
    static let consent           = "consent"
    static let onboarding        = "onboarding"
}

// MARK: - User Property Constants
// Max 25 custom user properties. Avoid auto-collected ones (app_version, device_model, os_version).
// Reference: https://support.google.com/analytics/answer/9268042

enum AnalyticsUserProperty {
    static let trainingLevel     = "training_level"     // beginner/intermediate/advanced
    static let hasHealthKit      = "has_healthkit"       // true/false
    static let consentStatus     = "consent_status"      // granted/denied/pending
    static let goalType          = "goal_type"           // weight_loss/strength/endurance/general
    static let workoutFrequency  = "workout_frequency"   // 1-7 (days per week)
    static let subscriptionStatus = "subscription_status" // free/premium/trial (future)
}

// MARK: - Conversion Events
// These events should be marked as conversions in GA4 UI for funnel analysis.

enum AnalyticsConversion {
    static let events: [String] = [
        AnalyticsEvent.signUp,
        AnalyticsEvent.workoutComplete,
        AnalyticsEvent.mealLog,
        AnalyticsEvent.tutorialComplete,
        AnalyticsEvent.crossFeatureEngagement,
    ]
}
