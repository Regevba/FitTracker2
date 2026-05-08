# Push Notifications v2 — UX Research

**Phase:** 3 (UX/Integration), Step 3b (`/ux research`)
**Started:** 2026-05-07
**Inputs:** PRD `docs/product/prd/push-notifications.md`, Phase 0 research, `ux-foundations.md` Part 5, smart-reminders implementation
**Output:** This document → next step `ux-spec.md`

This research is intentionally narrow. v1's PRD already exhausted the competitive scan (Whoop / Oura / Hevy / MyFitnessPal). The new UX scope for v2 is:
1. The permission-priming surface (carries v1's design but adds two NEW entry points)
2. **Deep-link routing UX as a trust contract** (entirely new in v2 — v1's deep links never routed)
3. The `readinessAlert` content + delivery moment (new notification type)
4. The post-denial recovery surface (one-time banner, then quiet)

---

## 1. Applicable Principles (8 of 13 apply)

| # | Principle | Applies | How |
|---|---|---|---|
| 3 | **Jakob's Law** | ✓ Strong | Users expect the 3-step priming pattern from iOS HealthKit + every other notification-using app. v2 follows the established pattern verbatim — no innovation. |
| 4 | **Progressive Disclosure** | ✓ Strong | Priming screen shows benefit headline + 3-category summary. "Tap for examples" expands to actual notification body previews. Don't dump all 9 example notifications upfront. |
| 5 | **Recognition over Recall** | ✓ Strong | List the 3 notification categories on the priming screen with concrete examples (not "you'll get reminders" — show "Time to train, your readiness is 82"). Reduces opt-in friction by setting expectations. |
| 7 | **Feedback** | ✓ Critical (v2-specific) | Every notification tap MUST route to the expected destination, every time. The 99% deep-link routing success target codifies this principle as a contract. v1 + smart-reminders both broke this principle silently. |
| 8 | **Error Prevention** | ✓ Strong | Single OS dialog (one-shot per Apple). One-time post-denial banner. No repeated prompts. Settings row always reachable. |
| 11 | **Privacy by Default** | ✓ Strong | Local notifications only — no APNs, no server transmission. Notification *content* (titles, bodies, deep-link URLs) is never logged in analytics — only structural parameters (type, outcome, destination category). |
| 12 | **Progressive Profiling** | ✓ Critical | The trigger choice is post-first-workout-completed, not first-app-open. The user has invested ≥30 minutes of training before being asked. Inverts the typical "ask everything upfront" anti-pattern. |
| 13 | **Celebration Not Guilt** | ✓ Strong | Low-readiness alert says "Consider a light session or rest" — supportive, not "you're not ready". No "you missed yesterday's workout" framing in any notification. |

**Not applicable:** #1 Fitts (priming view sizing already specified by HIG), #2 Hick (no choice fan-out — single primary CTA), #6 Consistency (handled in spec via component reuse), #9 Readiness-First (UI not on Home), #10 Zero-Friction Logging (no logging surface).

---

## 2. Apple HIG — Notifications & Deep-Link Reference

### Authorization

Per Apple HIG "Notifications":
- Request at moment of relevance, not in onboarding ✓ (matches PRD's post-workout-completed trigger)
- Use **provisional authorization** for first-time experimental users? **DEFER.** Provisional authorization sends notifications quietly (no banner, only Notification Center). For a fitness app where the workout-reminder use case is BANNER-relevant ("Time to train at 07:00"), provisional reduces the value enough that the trade-off doesn't favor it. Spec calls for full alert+sound+badge, same as v1.
- Authorization options: `alert + sound + badge`. Same as v1. No critical alert entitlement (only for medical/safety apps).

### Deep linking + Universal Links

Per Apple HIG "Custom URL Schemes" + "Universal Links":
- Custom schemes (`fitme://...`) are accepted but warn: any other app can register the same scheme. This is fine for v2 (deferred Universal Links per OQ-7) but is the reason Universal Links matter at App Store launch.
- iOS handles `.onOpenURL` for both schemes once registered. `DeepLinkRouter` is grammar-agnostic at the routing layer — it doesn't matter whether the URL came from `fitme://` or `https://fitme.app/...`.
- Background → notification tap is the primary path for v2; the `UNUserNotificationCenterDelegate.didReceive` callback gives us the userInfo dictionary with the deep-link string.

### Foreground notifications

Per Apple HIG "Notifications":
- When the app is in the foreground, iOS does NOT show the banner by default. The delegate's `willPresent(_:withCompletionHandler:)` decides what to show.
- Smart-reminders' `ReminderNotificationDelegate.userNotificationCenter(_:willPresent:...)` already returns `[.banner, .sound, .list]` (line 140 of `ReminderNotificationDelegate.swift`) — banner shown even in foreground. v2 inherits this behavior; readinessAlert ALSO shows in foreground (it's pre-workout, the user may have the app open).

---

## 3. Competitive UX — Deep-Link Routing Specifically

| App | What works | What's frustrating |
|---|---|---|
| **Strava** | Notification tap reliably opens the activity detail. URL grammar is nested (`strava://activities/{id}`). | Sometimes opens cold-start to the wrong tab (Home instead of activity) — appears to be a state-restoration bug rather than a routing bug. Lesson: deep-link routing must work cold-start. |
| **MyFitnessPal** | Tap a streak reminder → opens diary at today. Reliable. | Notification stack is noisy by default — opt-out of streak reminders is buried. Lesson: don't default-on chatty notifications. |
| **Hevy** | Workout reminder → opens workout templates picker (good — one tap from notification to start). | None observed for routing. | 
| **Oura** | Daily readiness summary notification → opens Readiness tab with today's score. Reliable. | Sometimes the deep link lands on Readiness tab but score is loading; UX flicker. Lesson: handle stale/loading state gracefully when deep link races data load. |

**Net pattern:** the bar competitors set is "deep links must work cold-start AND warm-start, AND must handle the case where the destination is loading data when the user lands." v2 DeepLinkRouter must address both.

---

## 4. CX Signals Check

`grep -i "notif\|reminder\|alert\|deep.link\|priming\|permission" .claude/shared/cx-signals.json` returned zero entries (file likely absent or notification-quiet — no user-reported confusion in this surface area). v1 never went live with reachable notifications, so there are no in-the-wild CX signals to consume. Smart-reminders has been live for ~3 weeks but its deep links don't route, so user complaints would manifest as "I tapped the reminder and nothing happened" — none surfaced in the cx-signals corpus. The absence of complaint isn't validation; it's silence.

---

## 5. User Flow Mapping

### 5.1 Primary flow (post-workout priming → grant → first notification → tap)

```
1. User completes first workout (training session ends, ResultsView dismisses)
2. After ResultsView dismiss, NotificationPermissionPrimingView presents (sheet, not full-screen)
3. User taps "Enable Notifications" → OS permission dialog
4. User taps "Allow" → NotificationGateway.isAuthorized = true
5. Priming sheet dismisses; user lands back at Home
6. Tomorrow morning: scheduled workout reminder fires (banner in Notification Center)
7. User taps banner → ReminderNotificationDelegate.didReceive → DeepLinkRouter.handle(.notification, "fitme://nav/training")
8. App opens on Training tab; if cold-start, show loading skeleton until data resolves
```

### 5.2 Skip flow (user not ready)

```
1-2. Same as primary
3. User taps "Not now" (secondary CTA on priming sheet)
4. Sheet dismisses; no OS dialog fired (preserves the one-shot privilege)
5. User can re-enter priming via Settings → Notifications row at any time
```

### 5.3 Denial flow (user explicitly declines)

```
1-3. Same as primary
4. User taps "Don't Allow" in OS dialog → isAuthorized = false
5. Priming sheet dismisses; user lands back at Home
6. On next Home appear: one-time `notification_settings_deeplink_shown` banner appears at top
7. Banner copy: "Notifications are off. Enable in Settings to get reminders."
8. CTA: "Open Settings" → opens iOS Settings deep link via UIApplication.shared.open(...)
9. Banner dismissed once → never shown again (UserDefaults flag: `notification.banner.shown = true`)
10. Settings → Notifications row stays available; permanent re-entry point
```

### 5.4 Edge cases

- **Permission already granted (via iOS Settings) before priming reaches user:** rare; happens if user toggled notifications on for FitMe in iOS Settings without going through priming. Priming view's `requestAuthorization()` short-circuits — system reports authorizationStatus = .authorized → priming dismisses without showing OS dialog, brief success state shown ("Notifications already enabled — you're all set.")
- **Permission revoked in iOS Settings after granted:** detected on next app foreground via `NotificationGateway.refreshAuthorizationStatus()`. Banner reappears once (UserDefaults flag reset on revocation).
- **Cold-start from notification tap:** app launches → UNUserNotificationCenterDelegate's `didReceive` fires before main content renders → DeepLinkRouter holds `pendingDeepLink` until SwiftUI root subscribes → on subscribe, action emits, navigation lands. **This is the test case T14 case 3 will cover.**
- **Dual-source race (notification tap AND `.onOpenURL` near-simultaneously):** `DeepLinkRouter.handle(...)` is idempotent per (URL, source, timestamp) tuple. Second call within 200ms with same URL is a no-op. Prevents double-navigation.
- **Notification tap while in Settings/Onboarding/Lock:** `pendingDeepLink` queued but suppressed until user reaches an interactive Home/tab state. This matches `signIn.pendingPasswordResetURL` pattern that already works.

---

## 6. Recommended Interaction Patterns

### 6.1 Priming view as a sheet, not full-screen

v1 used `.fullScreenCover`-style modal. v2 should use `.sheet` (medium detent on iOS 16+, fallback to default). Reason:
- Sheet preserves visual context — user sees their workout summary peek behind the sheet, reinforcing the "you just completed this, want reminders for next time?" framing
- Sheet dismissal via swipe-down is a natural "Not now" gesture (and actually does dismiss without firing OS dialog — defensive)
- Full-screen modal feels heavier; lower opt-in rate per Hevy/Strong pattern observation

### 6.2 Settings row uses dynamic CTA

Settings → Notifications row label changes based on `NotificationGateway.isAuthorized`:
- `false` + never asked: "Enable Notifications" (taps → priming sheet)
- `false` + previously asked + denied: "Open iOS Settings" (taps → UIApplication.shared.open)
- `true`: "Notifications enabled" (taps → expanded preferences sub-screen, P2 deferred)

Recognition-over-recall (#5) — user always sees the current state.

### 6.3 Deep-link routing visibility (debug-only)

Add a hidden `deep_link_routed` analytics event with `outcome` parameter so the team can monitor routing health post-launch. Not user-visible. Surfaces silently to fitme-story dashboard. If routing success rate drops below 99% kill criterion, dashboard alerts before users notice.

### 6.4 readinessAlert content matrix

| Direction | Score range | Body copy | Tone | Deep link |
|---|---|---|---|---|
| High | ≥ 80 | "You're ready — readiness {X}/100. Good conditions for a hard session today." | Affirming, energetic | `fitme://nav/home` |
| Low | ≤ 40 | "Readiness is low today ({X}/100). Consider a light session or rest." | Supportive, non-judgmental | `fitme://nav/home` |
| Low + workout scheduled today (pre-emption) | ≤ 40 | Same body, but pre-empts global cap so this one fires even if 3 reminders already today | Supportive, time-critical | `fitme://nav/home` |

Both directions land on Home, NOT Stats — Home shows the readiness score breakdown via the existing `MetricTile` deep-link surface (already shipped). Lands on the right place by construction.

---

## 7. Open UX Questions (resolved at PRD)

All 8 OQs from PRD §"Open Questions — Resolved at Phase 1" carry forward as input. None are reopened by this research.

**One additional UX question surfaces:** should the priming sheet use medium detent (iOS 16+) or fixed full-height? **Resolution recommendation in spec:** medium detent on iOS 16+, full-height fallback for iOS 15. The detent size is itself a form of progressive disclosure (#4) — partial occlusion of the underlying view tells the user "you can dismiss this and come back later."

---

## 8. v2-Refactor-Checklist (`/ux` ownership)

This is a `new_feature` subtype, not a v2_refactor — checklist Sections A/E/F/G/H still apply but as forward-looking validation, not gap analysis. The spec (next step) carries the actual checklist completion. Tracked in `state.json.phases.implementation.checklist_completed` once Phase 4 ships.

---

## 9. Next Step

→ `/ux spec push-notifications` produces `ux-spec.md` with screen inventory, ASCII wireframes (low-fi + hi-fi + composite), state matrix, principle application table, and accessibility specification.

Then → `/ux validate` → `/ux preflight` (P0 gate) → `/design preflight` (P0 gate) → `/design audit` → `/ux prompt` + `/design prompt` → `/design build` (Figma frames or saved prompt fallback).
