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

    /// User logs a meal (mark as conversion in GA4) — legacy name, aliased
    static let mealLog           = "meal_log"
    /// User checks off supplements — legacy name, aliased
    static let supplementLog     = "supplement_log"

    // ── Nutrition v2 Events (screen-prefixed per CLAUDE.md rule) ───
    /// User logs a meal — screen-prefixed replacement for meal_log
    static let nutritionMealLogged       = "nutrition_meal_logged"
    /// User toggles supplement status — screen-prefixed replacement for supplement_log
    static let nutritionSupplementLogged = "nutrition_supplement_logged"
    /// User adds water to hydration tracker
    static let nutritionHydrationUpdated = "nutrition_hydration_updated"
    /// User navigates to a different date
    static let nutritionDateChanged      = "nutrition_date_changed"
    /// Empty state shown (no meals, supplements, or hydration)
    static let nutritionEmptyStateShown  = "nutrition_empty_state_shown"

    // ── Stats v2 Events (screen-prefixed) ────────────────────
    /// User changes the time period filter
    static let statsPeriodChanged      = "stats_period_changed"
    /// User selects a metric in the carousel
    static let statsMetricSelected     = "stats_metric_selected"
    /// User interacts with a chart (drag to scrub)
    static let statsChartInteraction   = "stats_chart_interaction"
    /// Empty state shown for a metric
    static let statsEmptyStateShown    = "stats_empty_state_shown"

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

    // ── GDPR Events (custom) ────────────────────────────────

    /// User requests account deletion
    static let accountDeleteRequested = "account_delete_requested"
    /// Account deletion completed across all stores
    static let accountDeleteCompleted = "account_delete_completed"
    /// User cancels pending account deletion
    static let accountDeleteCancelled = "account_delete_cancelled"
    /// User requests data export
    static let dataExportRequested = "data_export_requested"
    /// Data export generated successfully
    static let dataExportCompleted = "data_export_completed"

    // ── Onboarding Events (custom) ─────────────────────────

    /// User views an onboarding step
    static let onboardingStepViewed    = "onboarding_step_viewed"
    /// User completes an onboarding step
    static let onboardingStepCompleted = "onboarding_step_completed"
    /// User skips onboarding
    static let onboardingSkipped       = "onboarding_skipped"
    /// User selects a goal during onboarding
    static let onboardingGoalSelected  = "onboarding_goal_selected"
    /// System or user permission result (HealthKit, notifications, etc.)
    static let permissionResult        = "permission_result"

    // ── Settings Events (custom) ────────────────────────────

    /// User changes a setting
    static let settingsChanged   = "settings_changed"

    // ── Settings v2 Events (screen-prefixed) ───────────────
    /// User triggers a sync action
    static let settingsSyncTriggered    = "settings_sync_triggered"
    /// User updates consent/privacy preference
    static let settingsConsentUpdated   = "settings_consent_updated"
    /// User initiates destructive data action
    static let settingsDataDeleted      = "settings_data_deleted"

    // ── Training Events (custom) ─────────────────────────────

    /// User views the active training session screen
    static let trainingSessionViewed     = "training_session_viewed"
    /// User starts an exercise within a training session
    static let trainingExerciseStarted   = "training_exercise_started"
    /// User completes all sets for an exercise
    static let trainingExerciseCompleted = "training_exercise_completed"
    /// User logs a single set
    static let trainingSetLogged         = "training_set_logged"
    /// User copies previous set data
    static let trainingSetCopied         = "training_set_copied"
    /// User changes weight for a set
    static let trainingWeightChanged     = "training_weight_changed"
    /// User starts the rest timer between sets
    static let trainingRestTimerStarted  = "training_rest_timer_started"
    /// User skips the rest timer
    static let trainingRestTimerSkipped  = "training_rest_timer_skipped"
    /// User switches between activities (e.g. exercise ↔ cardio)
    static let trainingActivitySwitched  = "training_activity_switched"
    /// User completes the full training session (mark as conversion in GA4)
    static let trainingSessionCompleted  = "training_session_completed"
    /// User enters focus mode during training
    static let trainingFocusModeEntered  = "training_focus_mode_entered"
    /// User opens camera for form check during training
    static let trainingCameraOpened      = "training_camera_opened"

    // ── Home Events (custom) ───────────────────────────────

    /// User taps an action on the Home screen (start workout, log meal, etc.)
    static let homeActionTap     = "home_action_tap"
    /// User completes a home-initiated action (mark as conversion in GA4)
    static let homeActionCompleted = "home_action_completed"
    /// Home screen shows an empty state (no data available)
    static let homeEmptyStateShown = "home_empty_state_shown"
    /// User taps the body composition card on the Home screen
    static let homeBodyCompTap = "home_body_comp_tap"
    /// User changes the period on the body composition card
    static let homeBodyCompPeriodChanged = "home_body_comp_period_changed"
    /// User taps the log CTA on the body composition card
    static let homeBodyCompLogTap = "home_body_comp_log_tap"
    /// User taps a metric tile on the Home screen to deep-link into Stats
    static let homeMetricTileTap = "home_metric_tile_tap"

    // ── Readiness Events (screen-prefixed) ─────────────────
    /// Readiness score computed on home screen load
    static let homeReadinessScoreComputed      = "home_readiness_score_computed"
    /// User taps a readiness component mini-bar
    static let homeReadinessComponentTap       = "home_readiness_component_tap"
    /// Training recommendation shown to user
    static let homeReadinessRecommendationShown = "home_readiness_recommendation_shown"

    // ── AI Recommendation Events (screen-prefixed: home_) ──
    /// AI insight card shown on home screen
    static let homeAiInsightShown              = "home_ai_insight_shown"
    /// User taps AI insight card to expand
    static let homeAiInsightTap                = "home_ai_insight_tap"
    /// AI intelligence sheet opened from home screen
    static let aiSheetOpened                   = "home_ai_sheet_opened"
    /// User views a recommendation in the AI sheet
    static let aiRecommendationViewed          = "home_ai_recommendation_viewed"
    /// User submits feedback on a recommendation
    static let aiFeedbackSubmitted             = "home_ai_feedback_submitted"
    /// AI avatar animation state changes
    static let aiAvatarStateChanged            = "home_ai_avatar_state_changed"
    /// User accepts (thumbs-up) an AI recommendation
    static let aiRecommendationAccepted        = "ai_recommendation_accepted"
    /// User dismisses (thumbs-down) an AI recommendation
    static let aiRecommendationDismissed       = "ai_recommendation_dismissed"

    // ── Profile Events (screen-prefixed) ───────────────────
    /// User views the Profile tab
    static let profileTabViewed              = "profile_tab_viewed"
    /// User changes a profile goal or preference
    static let profileGoalChanged            = "profile_goal_changed"
    /// User opens a settings section within Profile
    static let profileSettingsSectionOpened   = "profile_settings_section_opened"
    /// User taps readiness snapshot in Profile
    static let profileReadinessTap           = "profile_readiness_tap"
    /// User taps body composition card in Profile
    static let profileBodyCompTap            = "profile_body_comp_tap"
    /// User taps their avatar in Profile
    static let profileAvatarTap              = "profile_avatar_tap"
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
    static let timeOfDay         = "time_of_day"      // morning/evening
    static let count             = "count"
    static let calories          = "calories"         // int — kcal
    static let supplementCount   = "supplement_count" // int — number of supplements toggled
    static let waterMl           = "water_ml"         // int — milliliters added
    static let targetMl          = "target_ml"        // int — daily hydration target
    static let direction         = "direction"        // forward/backward — date navigation
    static let section           = "section"          // meals/supplements/hydration — empty state context

    // Settings parameters (consentType already defined in Consent params)
    static let syncType          = "sync_type"        // push/fetch
    static let deleteScope       = "delete_scope"     // local/all

    // Stats parameters (period already defined in body composition params)
    static let metricName        = "metric_name"      // weight/bodyFat/readiness/etc
    static let category          = "category"         // body/recovery/training/nutrition
    static let interactionType   = "interaction_type" // drag/tap

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

    // GDPR parameters
    static let storesDeleted     = "stores_deleted"   // comma-sep: device,keychain,cloudkit,supabase,etc
    static let daysRemaining     = "days_remaining"   // 0-30 (grace period)
    static let sizeBytes         = "size_bytes"       // export file size
    static let recordCount       = "record_count"     // total records exported

    // Home parameters
    static let actionType         = "action_type"      // start_workout/log_meal
    static let hasRecommendation  = "has_recommendation" // true/false
    static let emptyReason        = "empty_reason"     // no_healthkit/no_data/first_launch
    static let ctaShown           = "cta_shown"        // connect_health/log_manually/both

    static let hasValue           = "has_value"           // true/false — metric tile has data

    // Body composition parameters
    static let hasWeight          = "has_weight"         // true/false
    static let hasBodyFat         = "has_body_fat"       // true/false
    static let progressPercent    = "progress_percent"   // 0-100
    static let period             = "period"             // week/month/quarter/year

    // Training parameters
    static let setIndex              = "set_index"
    static let activityType          = "activity_type"
    static let restDurationSeconds   = "rest_duration_seconds"
    static let sessionDurationSeconds = "session_duration_seconds"
    static let totalSets             = "total_sets"

    // Onboarding parameters
    static let stepIndex          = "step_index"       // 0-4
    static let stepName           = "step_name"        // welcome/goals/profile/healthkit/first_action
    static let goalValue          = "goal_value"       // build_muscle/lose_fat/maintain/general
    static let permissionType     = "permission_type"  // healthkit
    static let permissionGranted  = "permission_granted" // true/false

    // Readiness parameters
    static let score             = "score"              // int 0-100
    static let confidence        = "confidence"         // low/medium/high
    static let layer             = "layer"              // int 0-3
    static let goalMode          = "goal_mode"          // fatLoss/maintain/gain
    static let componentCount    = "component_count"    // int — how many components scored
    static let component         = "component"          // hrv/sleep/training/rhr/bodycomp
    static let recommendation    = "recommendation"     // restDay/lightOnly/moderate/fullIntensity/pushHard

    // AI parameters
    static let segment           = "segment"            // training/nutrition/recovery/stats
    static let sourceTier        = "source_tier"        // local/cloud/foundation
    static let entryPoint        = "entry_point"        // insight_card/readiness_tap/more_button
    static let rating            = "rating"             // positive/negative
    static let fromState         = "from_state"         // breathe/rotate/pulse/shimmer
    static let toState           = "to_state"           // breathe/rotate/pulse/shimmer
    static let confidenceLevel   = "confidence_level"   // high/medium/low — recommendation confidence
    // source already defined above — reuse for cloud/local/personalised pipeline source
    static let reason            = "reason"             // not_relevant/already_know/disagree/other — dismiss reason

    // Profile parameters
    static let field             = "field"
    static let oldValue          = "old_value"
    static let newValue          = "new_value"
}

// MARK: - Screen Constants

enum AnalyticsScreen {
    static let home              = "home"
    static let trainingPlan      = "training_plan"
    static let activeWorkout     = "active_workout"
    static let trainingSession   = "training_session"
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
    static let onboardingWelcome    = "onboarding_welcome"
    static let onboardingGoals      = "onboarding_goals"
    static let onboardingProfile    = "onboarding_profile"
    static let onboardingHealthkit  = "onboarding_healthkit"
    static let onboardingFirstAction = "onboarding_first_action"
    static let deleteAccount     = "delete_account"
    static let exportData        = "export_data"
    static let bodyCompDetail    = "body_comp_detail"
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
    static let onboardingCompleted = "onboarding_completed" // true/false
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
        AnalyticsEvent.accountDeleteCompleted,
        AnalyticsEvent.homeActionCompleted,
        AnalyticsEvent.trainingSessionCompleted,
    ]
}
