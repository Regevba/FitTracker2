# Onboarding — Phase 2: Task Breakdown

> **Date:** 2026-04-05
> **Feature:** onboarding
> **PRD:** `.claude/features/onboarding/prd.md`

---

## Task List

### T1: Create OnboardingView container + flow navigation
- **Type:** ui
- **Effort:** 0.5 day
- **Dependencies:** None
- **Description:** Create `FitTracker/Views/Onboarding/OnboardingView.swift` — a TabView/PageView container that manages the 5-step flow. Includes:
  - `@State var currentStep: Int` (0-4)
  - Segmented progress bar component at top (5 segments)
  - Forward/back navigation
  - `UserDefaults.hasCompletedOnboarding` guard
  - Skip button logic (visible on steps 1-3)

### T2: Welcome screen (Step 0)
- **Type:** ui
- **Effort:** 0.5 day
- **Dependencies:** T1
- **Description:** Create `OnboardingWelcomeView.swift`:
  - FitMe app icon (locked design: 4 intertwined circles + gradient FitMe text)
  - Animated using FitMeLogoLoader (`.breathe` mode)
  - Tagline: "Your fitness command center"
  - "Get Started" CTA button (AppButton primary)
  - No skip on this screen

### T3: Goals screen (Step 1)
- **Type:** ui
- **Effort:** 0.5 day
- **Dependencies:** T1
- **Description:** Create `OnboardingGoalsView.swift`:
  - 4 large tappable cards: Build Muscle / Lose Fat / Maintain / General Fitness
  - Single selection (highlight selected card)
  - "Continue" button + "Skip" option
  - Persist selection to UserProfile.goal
  - Fire `onboarding_goal_selected` GA4 event with `goal_value` param

### T4: Profile screen (Step 2)
- **Type:** ui
- **Effort:** 0.5 day
- **Dependencies:** T1
- **Description:** Create `OnboardingProfileView.swift`:
  - Training experience picker: Beginner / Intermediate / Advanced (3 cards or segmented control)
  - Weekly frequency picker: 2-6 days (stepper or horizontal selector)
  - "Continue" button + "Skip" option
  - Persist to UserProfile.experienceLevel + UserProfile.weeklyFrequency
  - Default if skipped: Intermediate, 3 days

### T5: HealthKit permission screen (Step 3)
- **Type:** ui
- **Effort:** 0.5 day
- **Dependencies:** T1, HealthKitService
- **Description:** Create `OnboardingHealthKitView.swift`:
  - Contextual explanation with icon/illustration: "Sync your Apple Watch to track recovery"
  - List of what FitMe will access: Heart Rate, HRV, Steps, Sleep
  - "Connect Health" CTA → triggers `HealthKitService.requestAuthorization()`
  - "Skip" option (can connect later in Settings)
  - Fire `permission_result` GA4 event with `permission_type: healthkit`, `granted: true/false`
  - Handle iPad gracefully (HealthKit not available)

### T6: First Action screen (Step 4)
- **Type:** ui
- **Effort:** 0.5 day
- **Dependencies:** T1, T3
- **Description:** Create `OnboardingFirstActionView.swift`:
  - Personalized message based on selected goal (e.g., "Ready to build muscle?")
  - Two CTA options: "Start Your First Workout" / "Log Your First Meal"
  - Sets `UserDefaults.hasCompletedOnboarding = true`
  - Navigates to Home screen with selected tab
  - No skip on this screen
  - Fire `tutorial_complete` GA4 event

### T7: Wire onboarding into app launch flow
- **Type:** infra
- **Effort:** 0.5 day
- **Dependencies:** T1
- **Description:** Modify `FitTrackerApp.swift`:
  - Add `@AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding = false`
  - If `!hasCompletedOnboarding` → show OnboardingView before auth/home
  - After onboarding completes → proceed to normal auth flow
  - Returning users bypass entirely
  - **High-risk file** — minimal change only

### T8: GA4 analytics instrumentation
- **Type:** infra
- **Effort:** 0.5 day
- **Dependencies:** T1
- **Description:** Update analytics infrastructure:
  - `AnalyticsProvider.swift`: Add 5 events, 5 params, 5 screens, 1 user property
  - `AnalyticsService.swift`: Add typed convenience methods
  - `analytics-taxonomy.csv`: Add rows
  - Wire `.analyticsScreen()` modifier on all 5 onboarding views
  - Fire `tutorial_begin` on Welcome screen appear
  - Fire `onboarding_step_viewed` / `onboarding_step_completed` / `onboarding_skipped` per step

### T9: Progress bar component
- **Type:** ui
- **Effort:** 0.25 day
- **Dependencies:** None
- **Description:** Create `OnboardingProgressBar.swift`:
  - 5-segment horizontal bar
  - Active segment uses brand gradient (orange→blue)
  - Completed segments filled, upcoming segments gray
  - Uses AppColor and AppSpacing tokens
  - Animated transitions between steps

### T10: Unit tests + analytics tests
- **Type:** test
- **Effort:** 0.5 day
- **Dependencies:** T1-T8
- **Description:**
  - Test onboarding flow navigation (forward, skip, complete)
  - Test UserDefaults guard (shows only once)
  - Test goal/profile persistence to UserProfile
  - Analytics tests in `AnalyticsTests.swift`:
    - All 5 new events fire correctly
    - Step params are correct
    - Consent gating works
    - Screen tracking for 5 onboarding screens

---

## Summary

| # | Task | Type | Effort | Dependencies |
|---|------|------|--------|-------------|
| T1 | OnboardingView container + navigation | ui | 0.5d | — |
| T2 | Welcome screen | ui | 0.5d | T1 |
| T3 | Goals screen | ui | 0.5d | T1 |
| T4 | Profile screen | ui | 0.5d | T1 |
| T5 | HealthKit permission screen | ui | 0.5d | T1 |
| T6 | First Action screen | ui | 0.5d | T1, T3 |
| T7 | Wire into app launch flow | infra | 0.5d | T1 |
| T8 | GA4 analytics instrumentation | infra | 0.5d | T1 |
| T9 | Progress bar component | ui | 0.25d | — |
| T10 | Unit tests + analytics tests | test | 0.5d | T1-T8 |

**Total effort:** ~4.75 days
**Parallelism:** T1 + T9 can run first, then T2-T6 in parallel, T7-T8 alongside, T10 last.

---

## Execution Order

```
Day 1:  T1 (container) + T9 (progress bar)
Day 2:  T2 (welcome) + T3 (goals) + T8 (analytics)
Day 3:  T4 (profile) + T5 (healthkit)
Day 4:  T6 (first action) + T7 (app launch wiring)
Day 5:  T10 (tests) + polish
```
