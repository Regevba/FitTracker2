# PRD: Push Notifications

> **ID:** push-notifications | **Status:** Approved | **Priority:** HIGH (RICE 7.5)
> **Last Updated:** 2026-04-15 | **Branch:** feature/push-notifications (pending)

---

## Purpose

Deliver a local notification system that surfaces workout reminders, readiness alerts, and recovery nudges at the right moment — using `UNUserNotificationCenter` with UX-Foundations-compliant permission priming, deferred remote push to Phase 2.

## Problem Statement

FitMe has strong daily intelligence (readiness scoring, HRV analysis, workout tracking, body composition trends) but no proactive surface. The app's value stops at the app boundary:

- Users must remember to open the app at the right time
- Readiness and recovery guidance cannot reach the user before a workout decision
- Habit formation requires prompts; there are none
- Competitor apps (Whoop, Oura, Hevy) all use sparse, high-value notifications to drive daily engagement

The gap is not feature parity — it is that the product's AI engine produces insights that users never see until they manually open the app.

## Business Objective

Increase daily active engagement by surfacing timely, low-volume, high-relevance notifications. The goal is not volume — it is the right signal at the right moment. One acknowledged readiness alert before a planned workout is worth more than ten generic reminders.

---

## Success Metrics

| Metric | Baseline | Target | Kill Criteria |
|---|---|---|---|
| Notification opt-in rate | 0% (no system today) | ≥ 40% | < 20% after 30 days |
| Workout reminder tap-through rate | 0% | ≥ 25% | < 10% after 30 days |
| Readiness alert acknowledgement rate | 0% | ≥ 20% | < 8% after 30 days |
| Notification disable rate (post opt-in) | unknown | ≤ 10%/month | > 25%/month |
| DAU lift (notification-attributed sessions) | 0 | +8% WAU | no measurable lift at 60 days |

**North Star:** notification-attributed sessions trending up, disable rate trending flat or down.

**Post-launch review cadence:** 2 weeks after first opt-in data is available, then monthly.

---

## Requirements

### P0 — Must Ship

| ID | Requirement | Notes |
|---|---|---|
| PN-1 | Request `UNUserNotificationCenter` permission using 3-step priming pattern | Prime → Context → Request. Never front-load the OS prompt |
| PN-2 | Permission priming triggers after first completed workout (primary) or via Settings toggle (secondary) | Do not prompt on first launch |
| PN-3 | Workout reminders: schedule a local notification at a user-defined time (day + time) | Stored in UserDefaults / NotificationPreferencesStore |
| PN-4 | Readiness alerts: fire when readiness score is calculated and falls below or above configurable thresholds | Only fire if confidence is high; suppress if score is stale or inputs are missing |
| PN-5 | Recovery nudges: fire when recovery status indicates the user should rest or modify today's plan | Tied to existing ReadinessEngine output |
| PN-6 | All notifications respect the system "Do Not Disturb" signal (iOS default behavior) | No custom DND logic needed |
| PN-7 | Analytics instrumentation for every permission and engagement event (see Analytics section) | Consent-gated via existing ConsentManager |
| PN-8 | Graceful degradation if permission is denied: no repeated prompts, Settings deep-link offered once | |

### P1 — Target Sprint

| ID | Requirement | Notes |
|---|---|---|
| PN-9 | NotificationService singleton: schedules, cancels, and updates notifications; wraps `UNUserNotificationCenter` | Testable via mock |
| PN-10 | NotificationPermissionPrimingView: 3-step modal (benefit framing, category list, OS prompt trigger) | Follows UX Foundations modal pattern |
| PN-11 | Per-notification-type enable/disable stored in NotificationPreferencesStore | Will surface in Settings when Smart Reminders ships |
| PN-12 | Notification payloads include deep-link URL scheme (`fitme://readiness`, `fitme://training`) | |
| PN-13 | Unit tests: NotificationService scheduling logic, permission state machine, priming trigger conditions | |

### P2 — Later / Stretch

| ID | Requirement | Notes |
|---|---|---|
| PN-14 | Notification preferences UI in Settings tab | Deferred until Smart Reminders ships |
| PN-15 | Remote push via APNs + server-side scheduling | Phase 2; requires backend infra |
| PN-16 | Rich notifications with media attachments | Phase 2 |
| PN-17 | Notification grouping / threading by category | Phase 2 |

---

## Notification Types — Detail

### 1. Workout Reminder
- **Trigger:** scheduled time, recurring (e.g. "Mon/Wed/Fri at 07:00")
- **Body:** "Time to train — your readiness score is [X]. Tap to start today's session."
- **Confidence gate:** always fires (time-based, not data-dependent)
- **Deep link:** `fitme://training`

### 2. Readiness Alert
- **Trigger:** ReadinessEngine produces a score and it crosses a threshold (≥ 80 = high, ≤ 40 = low)
- **Body (high):** "You're ready — readiness [X]/100. Good conditions for a hard session today."
- **Body (low):** "Readiness is low today ([X]/100). Consider a light session or rest."
- **Confidence gate:** only fire if ≥ 2 HealthKit signals contributed to the score within the last 6 hours
- **Deep link:** `fitme://readiness`

### 3. Recovery Nudge
- **Trigger:** recovery status = "rest recommended" or consecutive high-intensity sessions ≥ 3
- **Body:** "Your body is asking for recovery. Tap to see today's recovery plan."
- **Confidence gate:** suppress if readiness data is older than 12 hours
- **Deep link:** `fitme://readiness`

---

## Technical Approach

### Architecture

```
NotificationService (singleton)
  ├── scheduleWorkoutReminder(days:time:) → UNCalendarNotificationTrigger
  ├── scheduleReadinessAlert(score:direction:) → UNTimeIntervalNotificationTrigger
  ├── scheduleRecoveryNudge() → UNTimeIntervalNotificationTrigger
  ├── cancelNotification(id:)
  ├── requestPermission() → async Bool
  └── currentAuthorizationStatus() → async UNAuthorizationStatus

NotificationPermissionPrimingView (SwiftUI modal)
  ├── Step 1: value framing card
  ├── Step 2: category list (what you'll receive)
  └── Step 3: "Enable Notifications" CTA → triggers OS prompt

NotificationPreferencesStore (UserDefaults-backed)
  ├── workoutReminderEnabled: Bool
  ├── workoutReminderDays: [Int] (0=Sun … 6=Sat)
  ├── workoutReminderTime: DateComponents
  ├── readinessAlertsEnabled: Bool
  └── recoveryNudgesEnabled: Bool
```

### Permission Priming Pattern (UX Foundations)

1. **Prime:** value-framing card appears after first completed workout. No OS prompt yet.
2. **Context:** modal explains the three notification types and their benefit, shows example messages.
3. **Request:** user taps "Enable Notifications" → OS permission dialog fires.

If denied at OS level: display a one-time Settings deep-link banner. No re-prompt.

### ReadinessEngine Integration

`NotificationService` observes `ReadinessEngine.latestScore` via Combine. On each new score emission:
- evaluate thresholds
- check confidence gate
- check if a notification for this score direction has already been sent today (de-dupe)
- schedule or suppress

### Key Files (to be created)

| File | Purpose |
|---|---|
| `FitTracker/Services/Notifications/NotificationService.swift` | Core scheduling + permission wrapper |
| `FitTracker/Services/Notifications/NotificationPreferencesStore.swift` | UserDefaults-backed preferences |
| `FitTracker/Views/Notifications/NotificationPermissionPrimingView.swift` | 3-step priming modal |
| `FitTracker/Tests/NotificationServiceTests.swift` | Unit tests |

---

## Analytics Events

All events use the `notification_` prefix per the project analytics naming convention.

| Event | Trigger | Key Parameters |
|---|---|---|
| `notification_permission_primed` | User sees the priming modal (Step 1) | `trigger_context` (post_workout / settings) |
| `notification_permission_requested` | OS dialog triggered (Step 3) | — |
| `notification_permission_granted` | User taps Allow in OS dialog | — |
| `notification_permission_denied` | User taps Don't Allow in OS dialog | — |
| `notification_settings_deeplink_shown` | One-time re-engagement banner shown after denial | — |
| `notification_scheduled` | A notification is scheduled | `type` (workout_reminder / readiness_alert / recovery_nudge), `trigger` (time_based / score_based) |
| `notification_cancelled` | A notification is cancelled | `type`, `reason` (user_disabled / preference_changed) |
| `notification_tapped` | User taps a delivered notification | `type`, `deep_link` |
| `notification_dismissed` | User swipes away a delivered notification (best-effort via foreground delegate) | `type` |
| `notification_suppressed` | A notification was not sent due to confidence gate | `type`, `reason` (stale_data / low_confidence / already_sent_today) |

> Note: `notification_tapped` is the primary engagement signal. Tap-through rate = `notification_tapped` / `notification_scheduled` per type per day.

---

## Dependencies

| Dependency | Status | Notes |
|---|---|---|
| `UNUserNotificationCenter` (iOS 10+) | Available | No third-party SDK needed |
| `ReadinessEngine` | Shipped | Score + confidence output already available |
| `AnalyticsService` | Shipped | ConsentManager gates all events |
| `AppTheme` design tokens | Shipped | Priming modal uses existing semantic tokens |
| Smart Reminders feature | Planned | Full Settings preferences UI deferred until that feature ships |
| APNs / remote push backend | Not started | Phase 2 only |

---

## GDPR / Privacy

- Local notifications do not transmit data to any server
- `notification_*` analytics events are consent-gated via `ConsentManager` (same as all other events)
- Notification preferences stored in `UserDefaults` (on-device only)
- No notification content is logged or sent to analytics

---

## Open Questions

| # | Question | Owner | Resolution |
|---|---|---|---|
| OQ-1 | Should readiness thresholds (≥80 / ≤40) be configurable by the user in Phase 1? | PM | Defer to Phase 1 stretch; use hardcoded defaults |
| OQ-2 | How do we attribute a session to a notification tap if the app was already open? | Analytics | Use `notification_tapped` + session_start proximity window (< 5s) |
| OQ-3 | Should recovery nudges fire on rest days only, or also on training days with a low readiness score? | Design | Fire on both; body copy differs |
