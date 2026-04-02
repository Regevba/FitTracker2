# Task Breakdown: Google Analytics Integration

> **Feature:** google-analytics
> **Total effort:** 10 working days (~2 weeks)
> **Total subtasks:** 12

---

## Dependency Graph

```
[T1 Firebase setup] ──→ [T2 AnalyticsProvider protocol]
                              │
                    ┌─────────┼──────────┐
                    ▼         ▼          ▼
              [T3 Firebase  [T4 Mock   [T5 Consent
               Adapter]      Adapter]   Manager]
                    │                    │
                    └────────┬───────────┘
                             ▼
                      [T6 AnalyticsService]
                             │
               ┌─────────────┼─────────────┐
               ▼             ▼             ▼
        [T7 Screen      [T8 Custom    [T9 Consent
         Tracking]       Events]       View UI]
               │             │             │
               └─────────────┼─────────────┘
                             ▼
                      [T10 Settings toggle]
                             │
                      [T11 Testing + CI]
                             │
                      [T12 Privacy Label + Docs]
```

---

## Tasks

### T1: Firebase Project Setup + SPM Dependency
- **Type:** infra
- **Description:** Create Firebase project in Firebase Console, download GoogleService-Info.plist, add Firebase Analytics SPM package to Xcode project. Add `-ObjC` linker flag. Configure `FirebaseApp.configure()` in app entry point.
- **Effort:** 0.5 days
- **Dependencies:** None
- **Files:** `Package.swift` or `.xcodeproj`, `GoogleService-Info.plist`, `Info.plist`
- **Note:** Requires manual Firebase Console setup (cannot be automated)

### T2: AnalyticsProvider Protocol
- **Type:** backend
- **Description:** Define the analytics abstraction protocol with methods: `configure()`, `logEvent()`, `logScreenView()`, `setUserProperty()`, `setUserID()`, `setConsent()`. This is the contract all adapters implement.
- **Effort:** 0.5 days
- **Dependencies:** None
- **Files:** `FitTracker/Services/Analytics/AnalyticsProvider.swift`

### T3: FirebaseAnalyticsAdapter
- **Type:** backend
- **Description:** Implement `AnalyticsProvider` wrapping Firebase.Analytics SDK calls. Map protocol methods to `Analytics.logEvent()`, `Analytics.setScreenName()`, etc. Handle Firebase-specific configuration (disable auto screen tracking via Info.plist `FirebaseAutomaticScreenReportingEnabled = NO`).
- **Effort:** 1 day
- **Dependencies:** T1, T2
- **Files:** `FitTracker/Services/Analytics/FirebaseAnalyticsAdapter.swift`

### T4: MockAnalyticsAdapter
- **Type:** backend
- **Description:** Implement `AnalyticsProvider` that logs events to console (`os_log`) in DEBUG builds and SwiftUI previews. Useful for development and testing.
- **Effort:** 0.25 days
- **Dependencies:** T2
- **Files:** `FitTracker/Services/Analytics/MockAnalyticsAdapter.swift`

### T5: ConsentManager
- **Type:** backend
- **Description:** Manage GDPR consent state and ATT authorization. Store consent in UserDefaults (synced via existing Supabase). Expose `@Published` properties: `gdprConsent: Bool`, `attStatus: ATTrackingManager.AuthorizationStatus`. Methods: `requestATT()`, `grantConsent()`, `revokeConsent()`. Gate all analytics on consent status.
- **Effort:** 1.5 days
- **Dependencies:** T2
- **Files:** `FitTracker/Services/Analytics/ConsentManager.swift`, `Info.plist` (ATT usage description)

### T6: AnalyticsService (Main Orchestrator)
- **Type:** backend
- **Description:** `@MainActor ObservableObject` that owns the `AnalyticsProvider` and `ConsentManager`. Injected as `@EnvironmentObject` in `FitTrackerApp.swift`. Convenience methods: `logWorkoutStarted()`, `logMealLogged()`, `logScreenView()`, etc. All methods check consent before calling provider.
- **Effort:** 1 day
- **Dependencies:** T2, T3, T4, T5
- **Files:** `FitTracker/Services/Analytics/AnalyticsService.swift`, `FitTracker/FitTrackerApp.swift` (modify)

### T7: Screen Tracking (25 Views)
- **Type:** ui
- **Description:** Add `.onAppear { analyticsService.logScreenView("screen_name") }` to all 25 SwiftUI views listed in the PRD event taxonomy. Use a reusable ViewModifier for consistency.
- **Effort:** 1.5 days
- **Dependencies:** T6
- **Files:** 25 SwiftUI view files + `FitTracker/Views/Modifiers/AnalyticsModifier.swift` (new)

### T8: Custom Events (15 Events)
- **Type:** backend
- **Description:** Add event logging calls at trigger points for all 15 custom events (start_workout, complete_workout, log_exercise, record_pr, log_meal, log_supplement, log_biometric, view_stats, share_workout, sign_in, sign_up, consent_granted, consent_denied, settings_changed, cross_feature_action). Add user properties (training_level, has_healthkit, consent_status, app_version).
- **Effort:** 1.5 days
- **Dependencies:** T6
- **Files:** Multiple view/service files where events trigger

### T9: ConsentView UI
- **Type:** ui
- **Description:** GDPR consent screen shown on first launch. Progressive disclosure: brief explanation of what data is collected and why, clear Accept/Decline buttons, link to privacy policy. No dark patterns. Follows FitMe design system tokens. Triggers ATT dialog on Accept.
- **Effort:** 1 day
- **Dependencies:** T5, T6
- **Files:** `FitTracker/Views/ConsentView.swift`

### T10: Settings Analytics Toggle
- **Type:** ui
- **Description:** Add "Analytics" toggle in Settings → Data section. Shows current consent status. Toggle calls `ConsentManager.revokeConsent()` or presents consent flow again. Shows explanation text below toggle.
- **Effort:** 0.5 days
- **Dependencies:** T5, T6
- **Files:** `FitTracker/Views/SettingsView.swift` (modify) or `DataSettingsView.swift`

### T11: Testing + CI
- **Type:** test
- **Description:** Unit tests for: AnalyticsService (consent gating), ConsentManager (state transitions), MockAnalyticsAdapter (event capture). Verify `make tokens-check`, `xcodebuild build`, `xcodebuild test` all pass. Test consent flow manually.
- **Effort:** 1 day
- **Dependencies:** T1-T10
- **Files:** `FitTrackerTests/Analytics/` (new test files)

### T12: Privacy Nutrition Label + Documentation
- **Type:** docs
- **Description:** Update App Store Connect Privacy Nutrition Label. Document event taxonomy in `docs/`. Update CHANGELOG.md. Update backlog.md (move to Done). Update metrics-framework.md (mark 14 metrics as "Instrumented").
- **Effort:** 0.5 days
- **Dependencies:** T11
- **Files:** `docs/product/metrics-framework.md`, `CHANGELOG.md`, `docs/product/backlog.md`

---

## Effort Summary

| Type | Tasks | Days |
|------|-------|------|
| infra | T1 | 0.5 |
| backend | T2, T3, T4, T5, T6, T8 | 5.75 |
| ui | T7, T9, T10 | 3.0 |
| test | T11 | 1.0 |
| docs | T12 | 0.5 |
| **Total** | **12 tasks** | **10.75 days** |

## Execution Order (optimized for parallelism)

| Day | Tasks | What |
|-----|-------|------|
| 1 | T1, T2 | Firebase setup + protocol definition |
| 2 | T3, T4, T5 (parallel) | Firebase adapter + mock adapter + consent manager |
| 3 | T6 | AnalyticsService orchestrator |
| 4-5 | T7, T8 (parallel) | Screen tracking + custom events |
| 6 | T9 | Consent view UI |
| 7 | T10 | Settings toggle |
| 8-9 | T11 | Testing + CI |
| 10 | T12 | Privacy label + docs |
