# PRD: Push Notifications (v2 — Platform Layer)

> **ID:** push-notifications | **Status:** Draft (Phase 1 in flight) | **Priority:** HIGH (RICE 7.5) | **Linear:** FIT-23
> **Last Updated:** 2026-05-07 | **Branch:** `feature/push-notifications-v2` | **Framework:** v7.8
> **Supersedes v1 PRD** (archived intent at `.claude/features/push-notifications/_v1/`). v1 case study at `docs/case-studies/push-notifications-case-study.md` documents what shipped, what didn't (UI-016 partial-ship), and why this rebuild exists.
> **Phase 0 Research:** `.claude/features/push-notifications/research.md` (approved 2026-05-07)

---

## Purpose

Build a notification **platform layer** for FitMe. Today, the app has multiple notification consumers in different states of completion (smart-reminders, auth password-reset, the dead v1 substrate, future training-plan/marketing/GDPR consumers) and no shared infrastructure. This PRD scopes the platform: a single authorization wrapper, a single permission-priming surface, a single dispatch surface, and a unified deep-link router that turns `fitme://...` URLs into navigation regardless of source (notification tap, system URL handler, in-app programmatic call).

A new notification type (`readinessAlert`, the only v1 type that doesn't duplicate a smart-reminders type) is registered through the platform.

## Problem Statement

Three concrete failures exist today:

1. **No platform layer.** Smart-reminders calls `UNUserNotificationCenter` directly. v1 push-notifications had its own (dead) wrapper. Future consumers would either reinvent the wrapper or refactor smart-reminders. Each new consumer is a fresh integration debt.
2. **No reachable permission surface.** v1 shipped `NotificationPermissionPrimingView` but never wired it (UI-016 partial-ship). Smart-reminders has no priming UI at all. The first reminder either hits authorization=denied silently or — if the user happens to have granted notifications via a separate iOS prompt — fires correctly. The opt-in path is, today, accidental.
3. **No deep-link routing.** Smart-reminders broadcasts `.fitMeReminderTapped` on every reminder tap with the deep-link payload, but no SwiftUI observer consumes it (`grep` confirms zero `addObserver` / `onReceive` consumer 2026-05-07). v1's `DeepLinkHandler.targetTab(...)` is dead code with zero callers. Auth's `fitme://reset-password` works only because it has its own dedicated `.onOpenURL` handler. Reminder taps today open the app to whatever tab was last selected; the deep-link payload is dropped.

## Business Objective

Surface the AI engine's daily insights at the right moment via a notification platform that scales to any consumer without integration debt. v2 ships the platform + the `readinessAlert` type + the priming surface; smart-reminders adapts to consume the platform (covered by a paired backlog enhancement).

The success bar is not notification volume — it's the right signal at the right moment AND the deep-link landing on the intended destination.

---

## Success Metrics

| Metric | Baseline | Target | Kill Criteria |
|---|---|---|---|
| **Primary: Notification opt-in rate** | 0% (no priming surface today) | ≥ 40% | < 20% after 30 days post-launch |
| Workout reminder tap-through rate | 0% (deep links don't route) | ≥ 25% | < 10% after 30 days |
| Readiness alert acknowledgement rate | 0% | ≥ 20% | < 8% after 30 days |
| **Deep-link routing success rate** *(new in v2)* | 0% (deep links broadcast but never consumed) | ≥ 99% (% of reminder taps that navigate to the intended destination) | < 95% after 7 days post-launch |
| Notification disable rate (post opt-in) | unknown | ≤ 10%/month | > 25%/month |
| DAU lift (notification-attributed sessions) | 0 | +8% WAU | no measurable lift at 60 days |

**Guardrail metrics (must not degrade for any reason):**
- Crash-free rate > 99.5% (system-wide guardrail)
- Cold start < 2s — adding `NotificationGateway` + `DeepLinkRouter` initialization at app-init must not push cold start past this
- Authorization request response time < 500ms p50

**North Star:** notification-attributed sessions trending up, deep-link routing success rate ≥ 99%, disable rate trending flat or down.

**Leading indicators (week 1):** opt-in rate, deep-link routing success rate, time-to-first-priming-shown post-install.
**Lagging indicators (30/60/90 day):** tap-through, ack rate, DAU lift, disable rate.

**Instrumentation:** all events fire through `AnalyticsService` (consent-gated via `ConsentManager`). Deep-link routing success rate computed as `deep_link_routed_succeeded / deep_link_routed_attempted` per day.

**Post-launch review cadence:** week 1 — leading-indicator snapshot. Week 4 — primary metric review against kill criteria. Then monthly until 90 days, then quarterly.

**Tier (per CLAUDE.md data quality tiers convention):** all metrics will ship as T1 (Instrumented) once `deep_link_routed` and `notification_permission_*` events fire in production. Pre-launch state is T1-instrumented-but-zero-data.

---

## Requirements

### P0 — Must Ship

| ID | Requirement | Notes |
|---|---|---|
| PN-1 | `NotificationGateway` singleton owns `UNUserNotificationCenter` access, authorization state (`@Published isAuthorized`), and a `dispatch(content:trigger:tag:)` API that any consumer can call | Replaces v1's `NotificationService.shared` directly; smart-reminders' `ReminderScheduler` routes through it (paired enhancement) |
| PN-2 | `NotificationConsumerRegistry` lets consumers register their types + URL patterns at app-init time in `FitTrackerApp.swift` | OQ-8 resolved → init-time, not lazy |
| PN-3 | `NotificationPermissionPrimingView` (revived from v1, HISTORICAL banner removed) presents the 3-step priming pattern (benefit framing, category list, OS prompt trigger) | Stays at `FitTracker/Views/Notifications/` (no v2/ subdir) per OQ-4; v1 file is structurally a fresh feature, not a refactor |
| PN-4 | Priming view triggers on **first-workout-completed** | OQ-1 resolved → first-workout-completed (higher intent than first-app-open) |
| PN-5 | Priming view also reachable from Settings | Secondary entry point; lets users who declined initially come back |
| PN-6 | `DeepLinkRouter` is the single entry point for all `fitme://...` URLs (custom scheme) and architecturally accepts `https://fitme.app/...` Universal Links (deferred to follow-on enhancement) | OQ-7 resolved → out of scope, architecturally accommodated |
| PN-7 | URL grammar: **nested verb-noun** — `fitme://nav/{tab}`, `fitme://action/{action}`, `fitme://auth/{flow}`, `fitme://settings/{section}` | OQ-6 resolved → nested. One-time migration of ~10 call sites in smart-reminders + 1 auth path |
| PN-8 | `DeepLinkRouter` consumes `.fitMeReminderTapped` broadcast from `ReminderNotificationDelegate` AND handles direct calls from `FitTrackerApp.onOpenURL` | One router, multiple sources |
| PN-9 | `readinessAlert` notification type — fires when `ReadinessEngine.latestScore` crosses thresholds (≥ 80 high, ≤ 40 low) | Threshold-gated, confidence-gated (≥ 2 HealthKit signals within last 6h) |
| PN-10 | `readinessAlert` lives in a separate critical bucket (1/day max), can pre-empt the smart-reminders 3/day global cap when readiness < 40 AND a workout is scheduled today | OQ-2 resolved → separate critical bucket. Pre-emption is platform-aware (NotificationGateway checks both buckets before dispatch) |
| PN-11 | All notifications respect iOS Do Not Disturb (system default) AND the smart-reminders quiet-hours window (22:00–07:00) | Quiet-hours moves from `ReminderScheduler` to `NotificationGateway` (consumer-shared) |
| PN-12 | Analytics: `notification_permission_*` events fire from the platform; `deep_link_routed` event fires from `DeepLinkRouter` on every routed URL | See Analytics Spec section |
| PN-13 | Graceful degradation: if permission denied, no repeated prompts; one-time Settings deep-link banner offered | Same as v1; no regression |
| PN-14 | **Reachability gate at Phase 5** — at least 3 tests asserting that (a) priming view is reachable from a real navigation path, (b) every registered URL routes to its intended destination via DeepLinkRouter, (c) DeepLinkRouter's `@Published` state emits AND a SwiftUI root subscriber observes it | Codifies the v1 lesson |

### P1 — Target Sprint

| ID | Requirement | Notes |
|---|---|---|
| PN-15 | v1 demolition: 4 files marked HISTORICAL with header banner, kept in repo | OQ-3 resolved → HISTORICAL banner. Files: `NotificationService.swift`, `NotificationPreferencesStore.swift`, `NotificationContentBuilder.swift`, `NotificationDeepLinkHandler.swift` (separate from `Services/Notifications/DeepLinkHandler.swift`'s `targetTab(...)` which deletes outright) |
| PN-16 | Drop unused v1 `AnalyticsEvent` declarations | `notificationScheduled`, `notificationDelivered`, `notificationTapped`, `notificationDismissed`, `notificationDisabled` — never fired, no GA4 history to preserve |
| PN-17 | `DeepLinkRouter` registration table: smart-reminders' 6 types + auth + readinessAlert + (forward-compatible) training-plan + marketing | Smart-reminders migration is paired-enhancement scope, not v2; v2 ships the registration mechanism |
| PN-18 | Unit tests: `NotificationGatewayTests`, `DeepLinkRouterTests`, `NotificationConsumerRegistryTests`, `ReadinessAlertTriggerTests` | Each ≥ 5 cases |

### P2 — Later / Stretch

| ID | Requirement | Notes |
|---|---|---|
| PN-19 | Notification preferences UI in Settings tab | Aggregated UI for both platform-level types AND smart-reminders types; separate enhancement post-v2 |
| PN-20 | Universal Links (`https://fitme.app/...`) — Associated Domains entitlement + AASA file at `fitme-story/public/.well-known/apple-app-site-association` | Follow-on enhancement, ~1 day. Required for App Store launch (FIT-17) but not v2 |
| PN-21 | APNs / remote push backend | Phase 2; backend infra dependency |
| PN-22 | Rich notifications with media attachments | Phase 2 |

---

## Notification Types — Detail

Only one new type is added by v2. The other types listed in v1 PRD (`workoutReminder`, `recoveryNudge`) are duplicates of smart-reminders' `trainingDay` / `restDay` and are **dropped** — smart-reminders owns them.

### `readinessAlert` (v2 — new)

- **Trigger:** `ReadinessEngine.latestScore` emits a new score crossing a threshold (≥ 80 high direction, ≤ 40 low direction)
- **Body (high):** "You're ready — readiness {X}/100. Good conditions for a hard session today."
- **Body (low):** "Readiness is low today ({X}/100). Consider a light session or rest."
- **Confidence gate:** suppress if `< 2` HealthKit signals contributed to the score within the last 6 hours
- **De-dupe:** suppress if a `readinessAlert` for the same direction has fired today
- **Frequency:** separate critical bucket — 1/day max, can pre-empt smart-reminders' 3/day global cap when readiness < 40 AND a workout is scheduled today
- **Deep link:** `fitme://nav/home` (lands on Home where the readiness score is the primary surface)
- **Owner:** registered with `NotificationConsumerRegistry` from a new `ReadinessAlertObserver` module (`FitTracker/Services/Notifications/ReadinessAlertObserver.swift`) that observes `ReadinessEngine.latestScore` via Combine

---

## Technical Approach

### Three-layer architecture

```
Consumer layer (multiple)
  smart-reminders    training-plan    marketing/APNs    GDPR exports    ReadinessAlertObserver
  (existing,            (future)        (future)         (future)         (new in v2)
   adapts via
   paired backlog
   enhancement)
                                    │
                                    ▼
Platform layer (push-notifications-v2)
  ┌────────────────────────┐  ┌────────────────────────────────────┐
  │ NotificationGateway    │  │ NotificationPermissionPrimingView  │
  │ - auth wrapper         │  │ - 3-step priming UX                │
  │ - dispatch surface     │  │ - first-workout + Settings entries │
  │ - cap audit (global +  │  │                                    │
  │   critical bucket)     │  │                                    │
  └──────────┬─────────────┘  └────────────────────────────────────┘
             │
             ▼
  ┌────────────────────────┐  ┌────────────────────────────────────┐
  │ DeepLinkRouter         │  │ NotificationConsumerRegistry       │
  │ - URL → action         │  │ - per-consumer types               │
  │ - foreground + back-   │  │ - per-consumer URL patterns        │
  │   ground sources       │  │ - per-consumer cap contributions   │
  │ - @Published nav state │  │                                    │
  └──────────┬─────────────┘  └────────────────────────────────────┘
                                    │
                                    ▼
iOS surfaces
  UNUserNotificationCenter    .onOpenURL    Universal Links (architecturally accommodated)
```

### Key files

| File | Purpose | Status |
|---|---|---|
| `FitTracker/Services/Notifications/NotificationGateway.swift` | Auth + dispatch + cap audit | New |
| `FitTracker/Services/Notifications/DeepLinkRouter.swift` | Single URL → action surface; `@Published` nav state | New (replaces dead `DeepLinkHandler.swift`) |
| `FitTracker/Services/Notifications/NotificationConsumerRegistry.swift` | Per-consumer registration | New |
| `FitTracker/Services/Notifications/ReadinessAlertObserver.swift` | Observes ReadinessEngine; dispatches `readinessAlert` | New |
| `FitTracker/Views/Notifications/NotificationPermissionPrimingView.swift` | 3-step priming modal | Revived (HISTORICAL banner removed) |
| `FitTracker/FitTrackerApp.swift` | Platform init + first-workout-completed trigger wiring + `.onOpenURL` → `DeepLinkRouter.handle(...)` + observe `DeepLinkRouter.publishedNav` | Edited |
| `FitTracker/Services/Notifications/NotificationService.swift` | v1 service | HISTORICAL banner added, kept in repo |
| `FitTracker/Services/Notifications/NotificationPreferencesStore.swift` | v1 preferences store | HISTORICAL banner added |
| `FitTracker/Services/Notifications/NotificationContentBuilder.swift` | v1 content builder | HISTORICAL banner added |
| `FitTracker/Services/Notifications/NotificationDeepLinkHandler.swift` | v1 deep-link handler (if exists) | HISTORICAL banner added |
| `FitTracker/Services/Notifications/DeepLinkHandler.swift` (the 14-LOC `targetTab` one) | Dead code | Deleted (zero callers; preserved in git history) |

### Smart-reminders consumer integration (paired enhancement, separate scope)

Tracked separately at `docs/product/backlog.md` → "Smart Reminders ↔ Push Notifications v2 deep-link integration". Ships paired with v2 (combined PR or paired PRs in same release window). Touchpoints on the smart-reminders side:

- `ReminderScheduler.scheduleIfAllowed(...)` internals route through `NotificationGateway.dispatch(...)`. Public API unchanged.
- `FitTrackerApp` registers smart-reminders' 6 types with `NotificationConsumerRegistry` at app init.
- `ReminderType.deepLink` inline strings migrate to `DeepLinkRouter` registration entries.
- `ReminderNotificationDelegate.didReceive` keeps the `.fitMeReminderTapped` broadcast; `DeepLinkRouter` consumes it.

### Permission Priming Pattern (UX Foundations)

1. **Prime:** value-framing card appears after first completed workout. No OS prompt yet.
2. **Context:** modal explains the registered notification categories (workout reminders + readiness alerts + recovery nudges + future) and shows example messages.
3. **Request:** user taps "Enable Notifications" → OS permission dialog fires.

If denied at OS level: display a one-time Settings deep-link banner. No re-prompt.

### Deep-Link Routing Detail

`DeepLinkRouter` exposes `@Published var pendingDeepLink: DeepLinkAction?` (similar to `signIn.pendingPasswordResetURL` pattern that already works in `FitTrackerApp.swift:202-213`). The SwiftUI root observes this via `.onChange(of:)` and presents/navigates based on the action variant:

```swift
enum DeepLinkAction {
    case navigateToTab(AppTab)            // fitme://nav/training, fitme://nav/nutrition, ...
    case presentSheet(SheetIdentifier)    // fitme://action/log-meal, ...
    case authFlow(URL)                    // fitme://auth/reset-password?token=... (forwarded to SignInService)
    case settingsSection(SettingsSection) // fitme://settings/health, fitme://settings/data-export
}
```

`DeepLinkRouter.handle(url:source:)` resolves URL → action via `NotificationConsumerRegistry`, sets `pendingDeepLink`, the SwiftUI subscriber observes and navigates. Test seam: assertions are made on `pendingDeepLink` state changes, not on private routing methods.

---

## Analytics Spec (GA4 Event Definitions)

### New events

| Event | Trigger | Key Parameters | Conversion? |
|---|---|---|---|
| `notification_priming_shown` | User sees the priming modal (Step 1) | `trigger_context` (post_workout / settings) | No |
| `notification_priming_skipped` | User dismisses priming via "Not now" | `trigger_context` | No |
| `notification_permission_requested` | OS dialog triggered (Step 3) | — | No |
| `notification_permission_granted` | User taps Allow in OS dialog | — | **Yes** (opt-in conversion) |
| `notification_permission_denied` | User taps Don't Allow in OS dialog | — | No |
| `notification_settings_deeplink_shown` | One-time re-engagement banner shown after denial | — | No |
| `deep_link_routed` | `DeepLinkRouter` resolves a URL to an action AND navigation succeeds | `source` (notification \| url \| programmatic), `destination` (tab/sheet/settings/auth), `url_pattern` (e.g. `fitme://nav/training`), `outcome` (succeeded \| failed_no_pattern_match \| failed_navigation) | No (debug visibility) |

Note: `notification_priming_shown` and `notification_permission_requested` already exist in `AnalyticsEvent` enum (lines 275, 283 of `AnalyticsProvider.swift`) — declared but unused. v2 starts firing them.

### Events deleted (declared but never used in v1)

`notificationScheduled`, `notificationDelivered`, `notificationTapped`, `notificationDismissed`, `notificationDisabled` — duplicates of the live `reminder_*` events. No GA4 history exists. Removed cleanly from `AnalyticsEvent` enum and from `analytics-taxonomy.csv`.

### Analytics naming validation checklist

- [x] All events use snake_case, lowercase only
- [x] All event names ≤ 40 characters
- [x] No reserved prefixes (`ga_`, `firebase_`, `google_`)
- [x] No collisions with existing enum cases (`notification_priming_shown` + `notification_permission_*` already declared; `deep_link_routed` is new)
- [x] No PII in any parameter (no emails, names, phone numbers, user IDs)
- [x] All parameter values ≤ 100 characters
- [x] ≤ 25 parameters per event (max here is 4 on `deep_link_routed`)
- [x] Total custom user properties unchanged (no new user properties added)
- [x] Notification platform events stay unprefixed (cross-screen lifecycle, like `app_open` / `sign_in` per CLAUDE.md analytics naming convention)
- [x] No GA4 recommended events misused

### Taxonomy CSV updates

`docs/product/analytics-taxonomy.csv` — add row for `deep_link_routed` with `screen_scope=global`. Confirm `notification_*` rows still match enum (5 events firing in v2; 5 events removed).

---

## Dependencies

| Dependency | Status | Notes |
|---|---|---|
| `UNUserNotificationCenter` (iOS 10+) | Available | No third-party SDK needed |
| `ReadinessEngine` (latest score + confidence) | Shipped | Combine-observable; v2 wires `ReadinessAlertObserver` to it |
| `AnalyticsService` + `ConsentManager` | Shipped | All events consent-gated |
| `AppTheme` design tokens | Shipped | Priming view uses existing semantic tokens (already token-compliant per v1) |
| Smart-reminders `ReminderScheduler` + `ReminderType` | Shipped | Paired enhancement adapts to v2 platform; doesn't depend on v2 shipping first (v2 ships the platform; the adaptation merges in the same window) |
| iOS Associated Domains entitlement (Universal Links) | Not needed for v2 | Architecturally accommodated; deferred to P2/follow-on |
| APNs backend | Not needed for v2 | Phase 2 / FIT-17 |

---

## GDPR / Privacy

- Local notifications do not transmit data to any server. v2 ships local-only.
- All `notification_*` and `deep_link_routed` analytics events are consent-gated via `ConsentManager` (same as all other events).
- Notification preferences storage moves from v1's `NotificationPreferencesStore` (UserDefaults, on-device only) to consumer-owned per-type preferences (also on-device, also UserDefaults). No regression.
- No notification content (titles, bodies, deep-link URLs) is logged in analytics — only event names + structural parameters (type, outcome, destination category).
- Per CLAUDE.md GDPR section: no Article 17 or Article 20 surface added (no PII collected by v2).

---

## Test & Eval Requirements

### Unit tests (P1 — target sprint)

- `NotificationGatewayTests` — auth state, dispatch path, cap audit (global + critical bucket), pre-emption logic, quiet-hours guard
- `DeepLinkRouterTests` — URL resolution for every registered pattern, fallback for unknown URLs, `@Published` state emission, dual-source handling (notification vs system URL)
- `NotificationConsumerRegistryTests` — registration, lookup, duplicate-pattern rejection
- `ReadinessAlertTriggerTests` — threshold crossing, confidence gate, de-dupe, pre-emption logic vs smart-reminders cap

### Reachability gate (P0 — non-skippable, codifies v1 lesson)

Phase 5 cannot be approved without these tests:

1. **Priming reachability test** — XCTest harness instantiates the SwiftUI root, dispatches a workout-completed event, asserts that `NotificationPermissionPrimingView` is presented (not just instantiable in isolation).
2. **Deep-link routing test** — for each pattern in `NotificationConsumerRegistry`, simulate `DeepLinkRouter.handle(url:source:)`, assert (a) `pendingDeepLink` emits the expected `DeepLinkAction`, (b) the SwiftUI subscriber observes it.
3. **Notification-tap end-to-end test** — simulate `UNNotificationResponse` with each consumer's deep-link payload via `ReminderNotificationDelegate.recordObservationFromNotification(...)` test seams; assert deep-link routes through `DeepLinkRouter` to the expected destination.

### AI behavior coverage

v2 does not add new AI behaviors. `ReadinessAlertObserver` consumes existing `ReadinessEngine` output (no new model logic). Eval gate auto-passes per `min_eval_coverage_met = true` rule for non-AI-touching features.

### Runtime smoke (Tier 2.1)

Phase 7 (Merge) checklist includes a runtime smoke profile: install on simulator → complete a workout → assert priming surface appears → grant permission → schedule a `readinessAlert` via debug menu → tap notification → assert app navigates to Home. Profile name: `notification_platform_v2`. Captured at `make runtime-smoke PROFILE=notification_platform_v2 MODE=local`.

---

## Open Questions — Resolved at Phase 1

| # | Question | Resolution | Source |
|---|---|---|---|
| OQ-1 | Priming view trigger | First-workout-completed | User 2026-05-07 |
| OQ-2 | `readinessAlert` cap bucket | Separate critical bucket; pre-empts global cap when readiness < 40 + workout scheduled today | User 2026-05-07 |
| OQ-3 | v1 demolition | Mark HISTORICAL with header banner, leave files in repo | User 2026-05-07 |
| OQ-4 | Priming view path | Keep `FitTracker/Views/Notifications/`, no v2/ subdir | User 2026-05-07 |
| OQ-5 | Case study slot | New slot post-23 (chronological order rule) | User 2026-05-07 |
| OQ-6 | URL grammar | Nested verb-noun (`fitme://nav/{tab}`, `fitme://action/{action}`, `fitme://auth/{flow}`, `fitme://settings/{section}`) | User 2026-05-07 |
| OQ-7 | Universal Links | Out of scope for v2; architecturally accommodated; deferred follow-on | User 2026-05-07 |
| OQ-8 | Registry registration timing | App-init time in `FitTrackerApp.swift` | User 2026-05-07 |

---

## Cross-References

- **Research (Phase 0):** `.claude/features/push-notifications/research.md`
- **v1 case study:** `docs/case-studies/push-notifications-case-study.md` (kept; new v2 case study will reference)
- **Smart-reminders parent PRD:** `docs/product/prd/smart-reminders.md`
- **Smart-reminders consumer integration (paired enhancement):** `docs/product/backlog.md` → "Smart Reminders ↔ Push Notifications v2 deep-link integration"
- **Linear:** FIT-23
- **State:** `.claude/features/push-notifications/state.json`
- **Log:** `.claude/logs/push-notifications.log.json`
