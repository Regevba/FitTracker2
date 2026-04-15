# PRD: Smart Reminders

> **ID:** smart-reminders | **Status:** Approved | **Priority:** HIGH
> **Last Updated:** 2026-04-15 | **Branch:** feature/smart-reminders (pending)

---

## Purpose

Deliver a proactive, AI-powered notification layer that surfaces timely, state-aware nudges — nutrition gap alerts, training day reminders, HealthKit onboarding prompts, guest registration CTAs, and re-engagement messages — without becoming noise. Backed by `NotificationScheduler`, personalized via `AIOrchestrator`, and gated by strict frequency caps.

## Problem Statement

FitMe is passive. It only provides value when opened. This creates three distinct failure modes:

- **Nutrition gaps:** Users miss afternoon protein windows. Without a prompt at 4 PM, they finish the day below target and never know.
- **Training consistency:** Users skip planned training days because the app never prompts. There is no external trigger to close the intention-action gap.
- **Guest non-conversion:** Users who skipped account creation during onboarding have no reason to return and no incentive to convert. The app cannot reach them at all.

Competitor analysis confirms the right model: Whoop and Oura succeed because reminders are **state-aware, not schedule-based**. MyFitnessPal over-notifies (3-4/day) and drives disable rates. FitMe will follow the Whoop/Oura pattern — low volume, high relevance, data-driven triggers.

## Business Objective

Transform FitMe from a reactive dashboard into a proactive coach. The app's AI engine already produces readiness scores, nutrition progress, and training plans — Smart Reminders surfaces those insights at the moment they are actionable, not only when the user remembers to open the app.

---

## Success Metrics

| Metric | Baseline | Target | Kill Criteria |
|---|---|---|---|
| Reminder engagement rate (tap-through) | 0% | ≥ 25% across all types | < 5% after 30 days → reduce to 1 type only |
| Nutrition gap reduction | 0 | 15% more protein logged on reminder days vs. non-reminder days | < 5% lift after 60 days |
| Guest conversion rate | 0% | 10% of reminded guests create account within 7 days | < 2% after 45 days |
| Notification disable rate | unknown | ≤ 10%/month post opt-in | > 25%/month → immediate review + type pruning |
| DAU lift (reminder-attributed sessions) | 0 | +6% WAU | no measurable lift at 60 days |

**North Star:** reminder tap-through rate trending up or flat, disable rate trending flat or down, guest conversion rate > 5% sustained.

**Post-launch review cadence:** 2 weeks after first engagement data is available, then monthly for 3 months.

---

## Requirements

### P0 — Must Ship

| ID | Requirement | Notes |
|---|---|---|
| SR-1 | `NotificationScheduler` service: evaluates all 5 reminder types on app launch and on significant state changes | Singleton; wraps `UNUserNotificationCenter` |
| SR-2 | Global frequency cap: max 3 reminders/day across all types | Hard cap; enforced by `NotificationScheduler` before any schedule call |
| SR-3 | Type 3 — Goal-Gap Nutrition reminder: fire at 4 PM when `currentProtein < targetProtein * 0.5` | Max 1/day, 5/week |
| SR-4 | Type 4 — Training/Rest Day reminder: fire at 10 AM on training days if no workout logged; fire anytime on rest days when readiness < 40 | Max 1/day |
| SR-5 | Per-type frequency caps enforced before scheduling (see Reminder Types section for caps) | Caps stored in `NotificationPreferencesStore` |
| SR-6 | `AIOrchestrator` integration: read readiness score, confidence gate before firing Type 4 | Suppress if score is stale (> 12 hours old) |
| SR-7 | Read from `EncryptedDataStore` for nutrition progress and workout logs; read from `GoalProfile` for targets | No PII in notification content |
| SR-8 | Analytics instrumentation for every reminder event (see Analytics section) | Consent-gated via `ConsentManager` |
| SR-9 | Permission handling delegates to Push Notifications feature (`NotificationService`) | Smart Reminders does not re-request permission |

### P1 — Target Sprint

| ID | Requirement | Notes |
|---|---|---|
| SR-10 | Type 1 — HealthKit Connect reminder: fire on days 2, 5, 10 post-onboarding when HealthKit not authorized | Max 3 total, then permanent stop |
| SR-11 | Type 2 — Account Registration reminder: fire on days 3, 7, 14 post-onboarding when no stored session | Max 3 total, then permanent stop |
| SR-12 | Type 5 — Engagement reminder: fire on days 3, 5, 7 of inactivity; body copy escalates per day | Max 3 per lapse period; reset counter on app open |
| SR-13 | Locked Feature Overlays: when guest users tap AI coaching, sync, or export surfaces, show an overlay with "Create Account" CTA | Semi-transparent backdrop, card with icon + benefit + CTA + "Maybe later" |
| SR-14 | Notification preferences UI in Settings tab: per-type enable/disable toggles | Reads/writes `NotificationPreferencesStore` |
| SR-15 | Deep links in all notification payloads: tap routes to the relevant surface | `fitme://nutrition`, `fitme://training`, `fitme://readiness`, `fitme://signin`, `fitme://healthkit` |
| SR-16 | Unit tests: `NotificationScheduler` cap enforcement, trigger condition evaluation, frequency state persistence | Mock `UNUserNotificationCenter` |

### P2 — Later / Stretch

| ID | Requirement | Notes |
|---|---|---|
| SR-17 | Behavioral learning: track which reminder types drive app opens vs. dismissals per user; surface in `AIOrchestrator` | Requires ≥ 30 days of data to be meaningful |
| SR-18 | Smart timing optimization: shift reminder fire times based on observed user-open patterns | e.g., if user consistently opens at 5 PM, shift nutrition reminder from 4 PM to 4:30 PM |
| SR-19 | A/B test framework for notification copy variants | Blocked by A/B framework feature (backlog) |
| SR-20 | Remote push fallback for lapsed users (app not launched in 7+ days) | Requires APNs backend; Phase 2 of Push Notifications |

---

## Reminder Types — Detail

### Type 1: HealthKit Connect

- **Trigger:** `!healthService.isAuthorized && daysSinceOnboarding >= 2`
- **Schedule:** Day 2, Day 5, Day 10 post-onboarding
- **Frequency cap:** 3 total, then permanent stop (never re-trigger)
- **Body:** "FitMe works better with Apple Health. Connect now to see your readiness score and recovery data."
- **Deep link:** `fitme://healthkit`
- **Degradation:** If user authorizes HealthKit at any point, cancel all pending Type 1 notifications immediately
- **Analytics:** `reminder_healthkit_shown`, `reminder_healthkit_tapped`

### Type 2: Account Registration

- **Trigger:** `!signIn.hasStoredSession && daysSinceOnboarding >= 3`
- **Schedule:** Day 3, Day 7, Day 14 post-onboarding
- **Frequency cap:** 3 total, then permanent stop
- **Body:** "Create your FitMe account to sync data across devices and unlock AI coaching."
- **Deep link:** `fitme://signin`
- **Degradation:** If user creates account at any point, cancel all pending Type 2 notifications immediately
- **Analytics:** `reminder_registration_shown`, `reminder_registration_tapped`

### Type 3: Goal-Gap Nutrition

- **Trigger:** `currentProtein < targetProtein * 0.5 && hour >= 16`
- **Schedule:** Evaluated at 4 PM daily; fire if condition met
- **Frequency cap:** 1/day, 5/week
- **Body:** "You're at {current}g / {target}g protein today. A quick meal could close the gap."
- **Deep link:** `fitme://nutrition`
- **Data source:** `EncryptedDataStore` (today's nutrition log), `GoalProfile` (protein target)
- **Degradation:** If nutrition data unavailable, suppress (do not fire with zero or stale values)
- **Analytics:** `reminder_nutrition_gap_shown`, `reminder_nutrition_gap_tapped`

### Type 4: Training / Rest Day

- **Trigger (training day):** `isTrainingDay && !hasLoggedWorkout && hour >= 10`
- **Trigger (rest day alert):** `isRestDay && readinessScore < 40`
- **Schedule:** 10 AM for training reminder; anytime (score-triggered) for rest day alert
- **Frequency cap:** 1/day (training + rest share the daily slot)
- **Body (training):** "Today's plan: {dayType}. {exerciseCount} exercises, ~{duration}m."
- **Body (rest):** "Your readiness is {score}. Take it easy — rest is part of progress."
- **Deep link:** `fitme://training` (training day), `fitme://readiness` (rest day)
- **Confidence gate:** For rest day alert, suppress if readiness score is older than 12 hours or confidence < 2 contributing HealthKit signals
- **Data source:** `AIOrchestrator` (readiness score + confidence), `EncryptedDataStore` (workout log), training plan
- **Analytics:** `reminder_training_shown`, `reminder_training_tapped`, `reminder_rest_day_shown`, `reminder_rest_day_tapped`

### Type 5: Engagement (Re-activation)

- **Trigger:** `daysSinceLastOpen >= 3`
- **Schedule:** Day 3, Day 5, Day 7 of inactivity
- **Frequency cap:** 3 per lapse period; counter resets on any app open
- **Body (day 3):** "Haven't seen you in a bit. Your streak is waiting."
- **Body (day 5):** "Your body composition goals need consistency. Quick check-in?"
- **Body (day 7):** "It's been a week. Even 2 minutes of logging keeps your trends accurate."
- **Deep link:** `fitme://home`
- **Degradation:** After 3 attempts in a lapse period, stop permanently until next app open resets the counter
- **Analytics:** `reminder_engagement_shown`, `reminder_engagement_tapped`

---

## Locked Feature Overlays

When a guest user (no stored session) taps a surface that requires an account — AI coaching, cross-device sync, data export — display an in-app overlay:

- **Backdrop:** semi-transparent, dismissible via tap outside
- **Card contents:**
  - Feature icon (from design system)
  - "Unlock {feature name}" — AppText.heading
  - One-sentence benefit description — AppText.body
  - "Create Account" primary CTA → deep link to onboarding auth flow
  - "Maybe later" secondary link → dismiss, track `locked_feature_dismissed`
- **Analytics:** `locked_feature_shown` (`feature_name` param), `locked_feature_cta_tapped` (`feature_name` param), `locked_feature_dismissed` (`feature_name` param)
- **Surfaces:** AI coaching tab, sync settings, export settings (Phase 1); any future gated feature uses the same component

---

## Technical Approach

### Architecture

```
NotificationScheduler (singleton)
  ├── evaluateAll() → called on app launch + significant state change
  ├── evaluateHealthKitReminder() → Type 1
  ├── evaluateRegistrationReminder() → Type 2
  ├── evaluateNutritionGapReminder() → Type 3
  ├── evaluateTrainingRestReminder() → Type 4
  ├── evaluateEngagementReminder() → Type 5
  ├── canFire(type:) → Bool  // checks per-type + global caps
  └── recordFired(type:date:) → persists to NotificationPreferencesStore

NotificationPreferencesStore (UserDefaults-backed, extends Push Notifications store)
  ├── reminderTypeEnabled: [ReminderType: Bool]
  ├── firedLog: [ReminderType: [Date]]  // rolling 7-day window
  ├── permanentStopFlags: [ReminderType: Bool]  // Types 1+2 exhaustion
  └── lastLapseCounterReset: Date  // Type 5 lapse tracking

LockedFeatureOverlay (SwiftUI view)
  ├── featureName: String
  ├── benefitDescription: String
  ├── onCreateAccount: () -> Void
  └── onDismiss: () -> Void
```

### Key Data Sources

| Data | Source | Used By |
|---|---|---|
| Readiness score + confidence | `AIOrchestrator` / `ReadinessEngine` | Type 4 trigger + confidence gate |
| Nutrition progress (today) | `EncryptedDataStore` | Type 3 trigger |
| Protein target | `GoalProfile` | Type 3 body copy |
| Workout log (today) | `EncryptedDataStore` | Type 4 training trigger |
| Training plan (day type, exercises) | Training plan store | Type 4 body copy |
| HealthKit authorization status | `HealthService` | Type 1 trigger + cancellation |
| Auth session | `AuthManager` / `SignInService` | Type 2 trigger + cancellation |
| Days since onboarding | `OnboardingStateStore` | Types 1, 2 schedule |
| Days since last open | `AppLifecycleStore` | Type 5 trigger |

### Permission Handling

Smart Reminders does not own permission requests. The Push Notifications feature (`NotificationService`) handles the 3-step priming pattern (prime → context → OS request). `NotificationScheduler` checks `currentAuthorizationStatus()` before scheduling and silently no-ops if permission is not granted.

### Frequency Cap Enforcement

Before any `UNUserNotificationCenter` schedule call:
1. Check per-type cap (e.g., Type 3: max 1/day, 5/week)
2. Check permanent stop flag (Types 1, 2)
3. Check global daily cap (max 3 across all types)
4. If any check fails, suppress and log `reminder_suppressed` analytics event

### Key Files (to be created)

| File | Purpose |
|---|---|
| `FitTracker/Services/Notifications/NotificationScheduler.swift` | Core orchestrator: evaluates all 5 types, enforces caps |
| `FitTracker/Services/Notifications/ReminderType.swift` | Enum + metadata for all 5 types |
| `FitTracker/Views/Components/LockedFeatureOverlay.swift` | Reusable guest-locked feature card |
| `FitTracker/Tests/NotificationSchedulerTests.swift` | Unit tests for cap logic + trigger conditions |

---

## Analytics Events

All reminder events use the `reminder_` prefix per the project analytics naming convention. Locked feature overlay events use the `locked_feature_` prefix (screen-agnostic component).

### Core Reminder Events

| Event | Trigger | Key Parameters |
|---|---|---|
| `reminder_scheduled` | A reminder is queued with `UNUserNotificationCenter` | `type` (healthkit / registration / nutrition_gap / training / rest_day / engagement), `trigger_condition` |
| `reminder_shown` | Notification is delivered (foreground delegate) | `type`, `day_offset` (for Types 1, 2, 5) |
| `reminder_tapped` | User taps a delivered notification | `type`, `deep_link` |
| `reminder_dismissed` | User swipes away notification (best-effort via foreground delegate) | `type` |
| `reminder_disabled` | User toggles a type off in preferences UI | `type` |
| `reminder_suppressed` | Scheduler evaluated but did not fire | `type`, `reason` (cap_global / cap_type / cap_permanent / stale_data / low_confidence / already_sent_today) |

### Per-Type Events

| Event | Type |
|---|---|
| `reminder_healthkit_shown` | Type 1 |
| `reminder_healthkit_tapped` | Type 1 |
| `reminder_registration_shown` | Type 2 |
| `reminder_registration_tapped` | Type 2 |
| `reminder_nutrition_gap_shown` | Type 3 |
| `reminder_nutrition_gap_tapped` | Type 3 |
| `reminder_training_shown` | Type 4 |
| `reminder_training_tapped` | Type 4 |
| `reminder_rest_day_shown` | Type 4 |
| `reminder_rest_day_tapped` | Type 4 |
| `reminder_engagement_shown` | Type 5 |
| `reminder_engagement_tapped` | Type 5 |

### Locked Feature Overlay Events

| Event | Trigger | Key Parameters |
|---|---|---|
| `locked_feature_shown` | Overlay appears | `feature_name` (ai_coaching / sync / export) |
| `locked_feature_cta_tapped` | "Create Account" tapped | `feature_name` |
| `locked_feature_dismissed` | "Maybe later" tapped or backdrop tap | `feature_name` |

> Primary engagement signal: `reminder_tapped`. Tap-through rate = `reminder_tapped` / `reminder_shown` per type per week. Guest conversion funnel: `locked_feature_cta_tapped` → `auth_signin_completed` (within 7-day window).

---

## Phased Rollout

### Phase 1 — Core Value (nutrition + training)

Ship Types 3 and 4. These have the highest immediate user value and all required data (nutrition logs, workout logs, readiness score) is already available. No auth-state dependency.

- SR-1, SR-2, SR-3, SR-4, SR-5, SR-6, SR-7, SR-8, SR-9
- Core analytics events (`reminder_scheduled`, `reminder_shown`, `reminder_tapped`, `reminder_dismissed`, `reminder_suppressed`)
- Per-type analytics for Types 3 and 4

### Phase 2 — Conversion (HealthKit + registration)

Add Types 1 and 2. Requires reading onboarding state and auth session status.

- SR-10, SR-11 (Types 1 + 2)
- SR-13 (Locked Feature Overlays)
- SR-14 (preferences UI in Settings)
- SR-15 (deep links for all types)
- Per-type analytics for Types 1 and 2
- Locked feature overlay analytics

### Phase 3 — Retention (engagement + behavioral learning)

Add Type 5 (engagement re-activation) and P2 behavioral learning foundation.

- SR-12 (Type 5)
- SR-17 (behavioral learning — data collection only, no UI)
- Per-type analytics for Type 5
- Begin collecting data for SR-18 smart timing optimization (no automation yet)

---

## Dependencies

| Dependency | Status | Notes |
|---|---|---|
| Push Notifications feature (`NotificationService`) | Planned | Must ship first; owns permission flow |
| `UNUserNotificationCenter` (iOS 10+) | Available | No third-party SDK needed |
| `AIOrchestrator` / `ReadinessEngine` | Shipped | Readiness score + confidence already available |
| `EncryptedDataStore` | Shipped | Nutrition progress + workout logs |
| `GoalProfile` | Shipped | Protein and macro targets |
| `AuthManager` / `SignInService` | Shipped | Guest detection for Types 2 and overlays |
| `HealthService` | Shipped | HealthKit authorization status for Type 1 |
| `AnalyticsService` | Shipped | `ConsentManager` gates all events |
| `AppTheme` design tokens | Shipped | Overlay and preferences UI use semantic tokens |
| Onboarding auth flow | Shipped | Deep link target for Type 2 and locked overlays |
| A/B framework | Backlog | Required for SR-19 copy variants |
| APNs backend | Not started | Required for SR-20 remote push |

---

## GDPR / Privacy

- All trigger evaluation and scheduling is fully local — no data leaves the device
- Notification body copy never contains raw PII (uses display values like "{current}g protein", not email or name)
- `reminder_*` and `locked_feature_*` analytics events are consent-gated via `ConsentManager`
- Frequency logs and cap state stored in `UserDefaults` (on-device only)
- Permanent stop flags for Types 1 and 2 persist through app reinstall via `EncryptedDataStore` (prevents re-harassment)

---

## Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Notification fatigue → high disable rate | Medium | High | Hard global cap of 3/day; kill criteria triggers type pruning at < 5% tap-through |
| Type 3 fires with irrelevant data (no HealthKit) | Medium | Medium | Type 3 (nutrition) works without HealthKit — uses only `EncryptedDataStore` logs |
| Type 4 fires with stale readiness score | Low | Medium | 12-hour confidence gate; suppress if score is stale |
| Guest users ignore registration nudges → wasted slots | Medium | Low | Max 3 attempts, then permanent stop; global cap protects other types |
| Privacy perception (feels surveillance-like) | Low | High | All computation local; body copy uses aggregated values only; clear opt-out in settings |

---

## Open Questions

| # | Question | Owner | Resolution |
|---|---|---|---|
| OQ-1 | Should the 5/week cap on Type 3 (nutrition) be configurable by the user in Phase 1? | PM | Defer; use hardcoded defaults. Surface in preferences UI Phase 2 |
| OQ-2 | Should locked feature overlays also appear for logged-in users who lack a specific entitlement (e.g., free tier)? | PM | Out of scope for this feature; tracked in backlog for monetization feature |
| OQ-3 | Type 5 body copy escalates across 3 days of inactivity — should day 7 copy be more urgent or maintain the same tone? | Design | Decision deferred to UX phase; flag for A/B test in Phase 3 |
| OQ-4 | Should `reminder_suppressed` events fire if the user has disabled that type in preferences (to distinguish user intent from cap suppression)? | Analytics | Yes — use `reason: user_disabled` to distinguish from automatic suppression |
