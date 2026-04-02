# PRD: Google Analytics Integration

> Feature: google-analytics | Phase 1 | RICE: 8.0
> Author: Claude (PM Workflow) | Date: 2026-04-02
> Status: Draft

---

## 1. Overview

### 1.1 Problem Statement

FitMe has 11 shipped features and 40 defined metrics but zero analytics instrumentation. Product decisions are based on intuition. We cannot measure:
- How many users are active (DAU/WAU/MAU)
- Whether users return (D1/D7/D30 retention)
- The North Star metric (Cross-feature WAU: train + log meal in same week)
- Where users drop off in key funnels
- Whether new features are adopted or should be killed

### 1.2 Solution

Integrate Google Analytics 4 (GA4) via Firebase Analytics SDK with:
- Protocol-based analytics abstraction (swap providers without code changes)
- GDPR consent manager (ATT + custom consent flow)
- 25 screen events + 15 custom events
- 4 conversion funnels
- Settings opt-out toggle

### 1.3 Target Users

- **Primary:** The developer/PM (us) — to make data-driven product decisions
- **Secondary:** Future team members — standardized analytics layer they can extend

### 1.4 Scope

**In scope:**
- Firebase Analytics SDK integration (SPM)
- AnalyticsService with protocol abstraction
- ConsentManager (ATT + GDPR)
- Screen tracking for all 25+ views
- 15 custom events (workout, nutrition, recovery, AI, auth)
- 4 conversion funnels
- User properties (subscription tier, training level, has_ui preferences)
- Settings → Analytics opt-out toggle
- App Store Privacy Nutrition Label updates

**Out of scope:**
- Firebase Crashlytics (separate feature)
- Firebase Performance Monitoring (conflicts with SwiftUI previews)
- Firebase Remote Config
- Server-side analytics / BigQuery export
- A/B testing infrastructure
- Revenue/purchase analytics (requires StoreKit integration first)

---

## 2. Event Taxonomy

### 2.1 Automatic Events (Firebase built-in)

| Event | Trigger | Notes |
|-------|---------|-------|
| `first_open` | First app launch after install | Automatic |
| `app_open` | App comes to foreground | Automatic |
| `session_start` | New session begins (>30min gap) | Automatic |
| `app_remove` | App uninstalled | Android only |

### 2.2 Screen Views (25 screens)

| Screen | View Name | SwiftUI View |
|--------|-----------|-------------|
| Home / Today | `home` | MainScreenView |
| Training Plan | `training_plan` | TrainingPlanView |
| Active Workout | `active_workout` | ActiveWorkoutView |
| Exercise Detail | `exercise_detail` | ExerciseDetailView |
| Nutrition | `nutrition` | NutritionView |
| Meal Entry | `meal_entry` | MealEntrySheet |
| Supplement Tracker | `supplements` | SupplementView |
| Recovery | `recovery` | RecoveryView |
| Biometrics Entry | `biometrics_entry` | BiometricsEntryView |
| Stats / Progress | `stats` | StatsView |
| Chart Detail | `chart_detail` | ChartDetailView |
| PR Records | `pr_records` | PRRecordsView |
| Settings | `settings` | SettingsView |
| Account Settings | `settings_account` | AccountSettingsView |
| Data Settings | `settings_data` | DataSettingsView |
| Appearance | `settings_appearance` | AppearanceSettingsView |
| Notification Settings | `settings_notifications` | NotificationSettingsView |
| About | `settings_about` | AboutView |
| Sign In | `sign_in` | SignInView |
| Sign Up | `sign_up` | SignUpView |
| Profile | `profile` | ProfileView |
| Onboarding (future) | `onboarding_{step}` | OnboardingView |
| Readiness Card | `readiness` | ReadinessCard |
| AI Insights (future) | `ai_insights` | AIInsightsView |
| Analytics Consent | `consent` | ConsentView |

### 2.3 Custom Events (15 events)

| Event | Parameters | Trigger |
|-------|-----------|---------|
| `start_workout` | `workout_type`, `day_number` | User taps "Start Workout" |
| `complete_workout` | `duration_mins`, `exercises_count`, `sets_count` | Workout saved |
| `log_exercise` | `exercise_name`, `muscle_group`, `sets`, `reps`, `weight_kg` | Set logged |
| `record_pr` | `exercise_name`, `pr_type` (weight/reps/volume) | New PR detected |
| `log_meal` | `meal_type` (breakfast/lunch/dinner/snack), `entry_method` (manual/template/photo/barcode) | Meal saved |
| `log_supplement` | `time_of_day` (am/pm), `count` | Supplements checked off |
| `log_biometric` | `metric_type` (weight/hrv/rhr/sleep/bf), `source` (manual/healthkit) | Biometric saved |
| `view_stats` | `stat_type`, `time_period` | Stats tab viewed with filter |
| `share_workout` | `share_method` | Workout shared |
| `sign_in` | `method` (apple/email/passkey/biometric) | Successful sign-in |
| `sign_up` | `method` | Account created |
| `consent_granted` | `consent_type` (analytics/att) | User accepts consent |
| `consent_denied` | `consent_type` | User declines consent |
| `settings_changed` | `setting_name`, `new_value` | Settings toggle changed |
| `cross_feature_action` | `features_used` (array) | Train + meal in same day |

### 2.4 Conversion Funnels

| Funnel | Steps | Purpose |
|--------|-------|---------|
| **Onboarding** | first_open → sign_up → consent_granted → first screen_view | Activation rate |
| **First Workout** | home → training_plan → start_workout → complete_workout | Training adoption |
| **First Meal** | home → nutrition → meal_entry → log_meal | Nutrition adoption |
| **Weekly Engagement** | app_open (7 days) → complete_workout (≥3) → log_meal (≥5) → cross_feature_action | North Star proxy |

### 2.5 User Properties

| Property | Type | Description |
|----------|------|-------------|
| `training_level` | string | beginner/intermediate/advanced |
| `has_healthkit` | boolean | HealthKit authorized |
| `consent_status` | string | granted/denied/pending |
| `app_version` | string | Semantic version |
| `subscription_tier` | string | free/premium (future) |

---

## 3. Technical Architecture

### 3.1 Analytics Protocol

```swift
protocol AnalyticsProvider {
    func configure()
    func logEvent(_ name: String, parameters: [String: Any]?)
    func logScreenView(_ screenName: String, screenClass: String?)
    func setUserProperty(_ value: String?, forName name: String)
    func setUserID(_ id: String?)
    func setConsent(analyticsStorage: Bool, adStorage: Bool)
}
```

### 3.2 Service Layer

```
AnalyticsService (ObservableObject, @EnvironmentObject)
    ├── provider: AnalyticsProvider (injected)
    ├── consentManager: ConsentManager
    ├── isEnabled: Bool (computed from consent)
    └── convenience methods: logWorkout(), logMeal(), logScreen(), etc.

ConsentManager (ObservableObject)
    ├── attStatus: ATTrackingManager.AuthorizationStatus
    ├── gdprConsent: Bool (UserDefaults + Supabase sync)
    ├── requestATT() → async
    ├── requestGDPRConsent() → async
    └── revokeConsent()

FirebaseAnalyticsAdapter: AnalyticsProvider
    └── wraps Firebase.Analytics calls

MockAnalyticsAdapter: AnalyticsProvider
    └── logs to console (DEBUG builds + SwiftUI previews)
```

### 3.3 Consent Flow

```
App Launch
    │
    ├── First launch?
    │   └── Show ConsentView (GDPR)
    │       ├── Accept → requestATT() → enable analytics
    │       └── Decline → disable analytics, no ATT dialog
    │
    ├── Returning user (consent granted)?
    │   └── Analytics enabled, check ATT status
    │
    └── Returning user (consent denied)?
        └── Analytics disabled (can re-enable in Settings)
```

### 3.4 Files to Create/Modify

| File | Action | Description |
|------|--------|-------------|
| `FitTracker/Services/Analytics/AnalyticsProvider.swift` | Create | Protocol definition |
| `FitTracker/Services/Analytics/AnalyticsService.swift` | Create | Main service (ObservableObject) |
| `FitTracker/Services/Analytics/FirebaseAnalyticsAdapter.swift` | Create | GA4 adapter |
| `FitTracker/Services/Analytics/MockAnalyticsAdapter.swift` | Create | Debug/preview adapter |
| `FitTracker/Services/Analytics/ConsentManager.swift` | Create | ATT + GDPR consent |
| `FitTracker/Views/ConsentView.swift` | Create | GDPR consent screen |
| `FitTracker/FitTrackerApp.swift` | Modify | Init AnalyticsService |
| `FitTracker/Views/SettingsView.swift` | Modify | Add analytics toggle |
| `GoogleService-Info.plist` | Create | Firebase config |
| `Package.swift` or Xcode project | Modify | Add Firebase SPM dependency |
| `Info.plist` | Modify | ATT usage description |

---

## 4. GDPR & Privacy Compliance

### 4.1 Requirements

- **GDPR consent** before any analytics data is sent
- **ATT dialog** before IDFA access (iOS 14.5+)
- **Privacy Nutrition Label** in App Store Connect — declare: Analytics (linked to user identity: no; used for tracking: no)
- **Data retention:** 14 months (GA4 default), configurable
- **Right to erasure:** ConsentManager.revokeConsent() deletes GA4 user data via API
- **No health data in analytics:** Never log PHI (Protected Health Information) as event parameters

### 4.2 What We Track vs Don't Track

| Track | Don't Track |
|-------|-------------|
| Screen views (screen name only) | Actual health data values |
| Event names (workout_started) | Specific exercises or weights |
| Session duration | Location data |
| Device model/OS version | Personal health metrics |
| Consent status | Authentication credentials |
| Feature usage patterns | Message content |

---

## 5. Success Metrics

### 5.1 Primary Metric

| Metric | Baseline | Target | Measurement |
|--------|----------|--------|-------------|
| **Analytics event delivery rate** | 0% (no analytics) | >99% of user actions logged | Firebase DebugView + GA4 Realtime |

### 5.2 Secondary Metrics

| Metric | Baseline | Target | Measurement |
|--------|----------|--------|-------------|
| DAU measurability | Not measurable | Reportable within 24h of deploy | GA4 dashboard |
| Event taxonomy coverage | 0/40 metrics | 14/40 (35%) instrumented | Manual audit |
| Consent acceptance rate | N/A | >70% of users accept | consent_granted / (granted + denied) |

### 5.3 Guardrail Metrics (must not degrade)

| Guardrail | Current | Threshold |
|-----------|---------|-----------|
| Cold start time | <2s | Must not increase >200ms |
| Crash-free rate | >99.5% | Must stay >99.5% |
| App binary size | ~50MB | Must not increase >10MB |
| CI pass rate | >95% | Must stay >95% |

### 5.4 Leading Indicators (within 1 week)

- Firebase DebugView shows real-time events
- GA4 Realtime dashboard shows active users
- Consent acceptance rate measurable

### 5.5 Lagging Indicators (30/60/90 days)

- D1/D7/D30 retention visible in GA4
- Cross-feature WAU baseline established
- Conversion funnels show drop-off points

### 5.6 Instrumentation Plan

All events logged via `AnalyticsService` convenience methods. Consent gates all calls. Firebase DebugView for pre-launch validation.

### 5.7 Review Cadence

- **Week 1:** Verify events flowing, consent rate, no crashes
- **Week 4:** First retention data, funnel analysis
- **Week 8:** Full metrics review, adjust event taxonomy if needed

### 5.8 Kill Criteria

Kill this integration if:
- Consent acceptance rate <30% (analytics data too sparse to be useful)
- Cold start time increases >500ms (performance degradation unacceptable)
- Firebase SDK introduces >2 crash-causing bugs within 30 days

---

## 6. Effort Estimate

| Phase | Effort |
|-------|--------|
| Firebase project setup + SPM | 0.5 days |
| AnalyticsProvider protocol + adapters | 1 day |
| ConsentManager (ATT + GDPR) | 1.5 days |
| ConsentView UI | 1 day |
| Screen tracking (25 views) | 1.5 days |
| Custom events (15 events) | 1.5 days |
| User properties + funnels | 0.5 days |
| Settings toggle | 0.5 days |
| Testing + CI | 1 day |
| Privacy Nutrition Label + docs | 0.5 days |
| **Total** | **10 days (~2 weeks)** |

---

## 7. Dependencies

- Firebase Console project (manual setup required)
- GoogleService-Info.plist (downloaded from Firebase Console)
- App Store Connect access (Privacy Nutrition Label)
- No dependency on other planned features

---

## 8. Future Scope — GA4 Data Features & Infrastructure

These items are **out of scope for v1** but planned as follow-on tasks building on the GA4 foundation:

### 8.1 Additional GA4 Infrastructure Tasks

| Task | Description | Depends On |
|------|-------------|------------|
| **Firebase Crashlytics** | Crash reporting with stack traces, breadcrumbs, non-fatal error tracking. Shares Firebase SDK. | GA4 v1 (T1 Firebase setup) |
| **Firebase Remote Config** | Feature flags, A/B test variants, gradual rollouts without App Store updates. | GA4 v1 |
| **BigQuery Export** | Raw GA4 event data exported to BigQuery for custom SQL queries, ML models, and advanced cohort analysis. | GA4 v1 + GCP project |
| **Server-Side Analytics** | Track backend events (sync failures, AI engine latency, API errors) alongside client events. | GA4 v1 + Railway backend |
| **Custom GA4 Dashboard** | Looker Studio dashboard with FitMe-specific KPIs, funnels, and alerts. | GA4 v1 + BigQuery |
| **A/B Testing Infrastructure** | Firebase A/B Testing or custom experiment framework. Test UI variants, feature gates, onboarding flows. | GA4 v1 + Remote Config |

### 8.2 Additional Data Features

| Feature | Description | Depends On |
|---------|-------------|------------|
| **Revenue Analytics** | StoreKit 2 purchase events, subscription tracking, LTV calculation, conversion attribution. | GA4 v1 + StoreKit integration |
| **Push Notification Analytics** | Track notification open rates, engagement lift, opt-in rates. | GA4 v1 + Push Notifications feature |
| **Deep Link Attribution** | Track user acquisition channels, campaign performance, app install attribution. | GA4 v1 + Marketing Website |
| **User Segmentation Dashboard** | In-app or admin dashboard showing user segments (power users, at-risk, churned) based on GA4 data. | GA4 v1 + BigQuery |
| **Automated Alerts** | Slack/email alerts when metrics cross thresholds (crash rate spike, retention drop, funnel blockage). | GA4 v1 + BigQuery + Cloud Functions |
| **Cohort Analysis Reports** | Weekly/monthly automated reports comparing user cohorts by acquisition date, feature adoption, retention curves. | GA4 v1 + BigQuery |
| **Privacy Dashboard** | User-facing screen showing what data has been collected, with export and delete options (GDPR Articles 15, 17, 20). | GA4 v1 + ConsentManager |
| **Offline Event Queuing** | Queue analytics events when device is offline, flush when connectivity returns. Firebase does this partially but custom events may need explicit handling. | GA4 v1 |

### 8.3 Subtasks for Current Feature (Deferred to v1.1)

| Subtask | Description | Why Deferred |
|---------|-------------|-------------|
| **Granular consent toggles** | Let users choose: analytics only, crash reports only, both, neither. | v1 uses binary accept/decline for simplicity |
| **Consent version tracking** | Track which version of the consent text the user agreed to. Required if consent text changes. | v1 consent text is stable |
| **Debug event viewer** | In-app screen (DEBUG builds only) showing real-time event log. More useful than Firebase DebugView for SwiftUI. | Nice-to-have, not blocking |
| **Event parameter validation** | Runtime checks that event parameters match the taxonomy schema. Catches typos before they reach GA4. | Can add post-v1 |
| **Analytics onboarding tooltip** | Brief tooltip during onboarding explaining what data helps improve the app. Increases consent rate. | Requires Onboarding feature first |
