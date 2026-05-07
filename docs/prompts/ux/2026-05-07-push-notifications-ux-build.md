# UX Build Prompt — Push Notifications v2

**Feature:** push-notifications (v2 platform-layer rebuild)
**Work subtype:** new_feature
**Target agent:** SwiftUI implementation agent (Phase 4) + Figma MCP agent (paired with `/design build`)
**Date:** 2026-05-07
**Linear:** FIT-23
**Paired with:** `docs/prompts/ui/2026-05-07-push-notifications-design-build.md`

---

## Context

FitMe has multiple notification consumers (smart-reminders, auth password-reset, future training-plan / marketing-APNs / GDPR exports) and no shared platform infrastructure. Today's failures: v1's priming view was never reachable (UI-016 partial-ship); smart-reminders broadcasts deep links via `.fitMeReminderTapped` but no SwiftUI consumer observes the broadcast — taps land on whatever tab was last selected.

v2 builds the **notification platform layer**: single auth wrapper, single permission-priming surface, single dispatch surface, unified deep-link router. Smart-reminders becomes the first consumer; future consumers plug into the same gateway.

Primary user value: notification opt-in rate ≥ 40%, deep-link routing success rate ≥ 99%, DAU lift +8% WAU.

---

## What to Build (UX surfaces)

### A. NotificationPermissionPrimingView (sheet)
- **Purpose:** App-branded explanation before iOS dialog. Step 1 of 3-step priming pattern (`ux-foundations.md` §5.2).
- **Entry points:** post-first-workout-completed (primary, sheet from `SessionCompletionSheet` dismiss) + Settings → Notifications row (secondary).
- **Primary CTA:** "Enable Notifications" → triggers OS dialog.
- **Secondary CTA:** "Not now" → dismisses without OS dialog (preserves the one-shot privilege).
- **Detents:** medium + large (iOS 16+).

### B. SettingsDeepLinkBanner (in-Home, post-denial)
- **Purpose:** One-time recovery surface for users who declined at OS dialog.
- **Visibility:** `!authorized && !UserDefaults.notificationBannerDismissed`
- **Primary CTA:** "Open Settings" → `UIApplication.openSettingsURLString`
- **Dismissal:** "X" button → `UserDefaults.notificationBannerDismissed = true` permanently.

### C. Settings → Notifications row (dynamic CTA)
- Three states: "Enable Notifications" (not asked) / "Open iOS Settings" (denied) / "Notifications enabled ✓" (authorized).
- Recognition over Recall (#5) — user always sees current state.

### D. Notification content matrix
- New: `readinessAlert` (high + low variants); both deep-link to `fitme://nav/home`.
- Existing (smart-reminders, untouched): `trainingDay`, `restDay`, `nutritionGap`, `healthKitConnect`, `accountRegistration`, `engagement`.
- Tone: affirming for high readiness, supportive for low. Never guilt-trip framing (#13).

---

## UX Principles Applied

| # | Principle | How Applied | Surface |
|---|---|---|---|
| 3 | Jakob's Law | Sheet+CTA matches iOS HealthKit / Strava / Hevy patterns. No new pattern. | PrimingView |
| 4 | Progressive Disclosure | Title + body + 3-category summary; no all-9-example dump | PrimingView CategoryListView |
| 5 | Recognition over Recall | Settings row dynamic label by auth state; category list visible on priming | Settings row + PrimingView |
| 7 | Feedback (CRITICAL for v2) | Every notification tap MUST route via DeepLinkRouter to expected destination. Haptic on grant. Banner on denial. | DeepLinkRouter; PrimingView haptic; SettingsDeepLinkBanner |
| 8 | Error Prevention | One-shot OS dialog protected by client-side state machine. One-time denial banner. No repeated prompts. | PrimingView state machine; SettingsDeepLinkBanner UserDefaults flag |
| 11 | Privacy by Default | All `notification_*` + `deep_link_routed` events consent-gated. Notification *content* never logged. | Analytics layer |
| 12 | Progressive Profiling | Trigger is post-first-workout-completed, not first-app-open. ≥30 min invested before being asked. | FitTrackerApp wiring (T6) |
| 13 | Celebration Not Guilt | readinessAlert low: "Consider a light session or rest". No badge counts. | Notification content matrix |

Not applicable: #9 Readiness-First (wrong surface), #10 Zero-Friction Logging (no logging surface).

---

## State Coverage (per surface)

### NotificationPermissionPrimingView
| State | Trigger | UI |
|---|---|---|
| `.initial` (default) | Sheet opens | Bell icon + title + body + 3 categories + "Enable Notifications" CTA + "Not now" |
| `.granted` (success) | OS dialog → Allow | Auto-dismiss + `.success` haptic |
| `.denied` (error) | OS dialog → Don't Allow | Denial hint row appears; CTA copy → "Open Settings" |
| (no loading state — synchronous; no empty state — categories hardcoded) |

### SettingsDeepLinkBanner
| State | Visibility |
|---|---|
| Visible | `!authorized && !dismissed` |
| Hidden | `authorized || dismissed` |

### Settings → Notifications row
| State | Label | Tap behavior |
|---|---|---|
| `false` + never asked | "Enable Notifications" | Opens priming sheet |
| `false` + denied | "Open iOS Settings" | UIApplication.shared.open |
| `true` (authorized) | "Notifications enabled ✓" | Opens preferences sub-screen (P2 — deferred) |

### Delivered notifications
| State | Behavior |
|---|---|
| Foreground default | Banner + sound + list (per ReminderNotificationDelegate.willPresent line 140) |
| Background tap | DeepLinkRouter routes to expected destination |
| Suppressed (cap/quiet hours/de-dupe) | `reminder_suppressed` analytics event with reason |

---

## Accessibility Requirements

| Surface | VoiceOver | Dynamic Type | Tap Target | Reduce Motion |
|---|---|---|---|---|
| Bell icon | `.accessibilityHidden(true)` | n/a | n/a | n/a |
| Title | Default | Scales (`.title3`) | n/a | n/a |
| Body | Default | Scales (`.body`) | n/a | n/a |
| Category list | `.accessibilityElement(children: .combine)` + label combining 3 categories | Scales | n/a | n/a |
| Primary CTA | `.accessibilityLabel("Enable notifications")` + `.accessibilityHint("Opens the system permission dialog")` | Fixed button height = `AppSize.ctaHeight` (48pt) | 48pt — exceeds 44pt | n/a |
| "Not now" | `.accessibilityLabel("Skip enabling notifications")` | Scales | ≥ 44pt default | n/a |
| Banner Open Settings | `.accessibilityLabel("Open notification settings")` | Scales | ≥ 44pt | Disable slide-in transition; appear/disappear instantly |
| Banner X | `.accessibilityLabel("Dismiss notification banner")` | n/a | 32pt visual + 12pt touch slop = 44pt+ effective | n/a |
| Settings row | Default row VoiceOver | Scales | List row ≥ 44pt | n/a |

**Reduce Motion:** wrap `SettingsDeepLinkBanner` slide-in via `@Environment(\.accessibilityReduceMotion)` to skip the transition. Other surfaces have no animations to gate.

---

## User Flows

### Primary
```
SessionCompletionSheet dismiss → Priming sheet → Enable → OS dialog → Allow
  → isAuthorized=true → sheet dismiss + .success haptic
  → next morning: scheduled trainingDay reminder fires
  → user taps → ReminderNotificationDelegate.didReceive
  → DeepLinkRouter.handle("fitme://nav/training", source: .notification)
  → DeepLinkRouter.pendingDeepLink = .navigateToTab(.training)
  → RootTabView observes → switches to Training tab
```

### Skip
```
Priming sheet → Not now (or swipe-down)
  → no OS dialog fired (preserves one-shot privilege)
  → Settings row remains as permanent re-entry point
```

### Denial
```
Priming sheet → Enable → OS dialog → Don't Allow
  → isAuthorized=false → sheet dismiss
  → on next Home appear: SettingsDeepLinkBanner shows once
  → user taps Open Settings OR dismiss X (UserDefaults flag set permanently)
  → Settings row swaps CTA to "Open iOS Settings"
```

### Edge cases
- Permission already granted via iOS Settings → priming auto-dismiss with brief "already enabled" success state
- Permission revoked in iOS Settings after granted → `NotificationGateway.refreshAuthorizationStatus()` on foreground; banner reappears once
- Cold-start from notification tap → DeepLinkRouter holds `pendingDeepLink` until SwiftUI root subscribes; on subscribe, action emits, navigation lands
- Dual-source race (notification + .onOpenURL near-simultaneously) → idempotent per (URL, source, ≤200ms) tuple

---

## Handoff Checklist (what the receiving agent produces)

For SwiftUI implementation agent (Phase 4):
- [ ] `NotificationGateway.swift` (T1) — auth + dispatch + cap audit
- [ ] `NotificationConsumerRegistry.swift` (T2)
- [ ] `DeepLinkRouter.swift` (T3) with `DeepLinkAction` enum + `@Published pendingDeepLink`
- [ ] `NotificationPermissionPrimingView.swift` (T4) — un-mark HISTORICAL, wire to NotificationGateway
- [ ] `ReadinessAlertObserver.swift` (T5) — Combine subscription to `ReadinessEngine.latestScore`
- [ ] `FitTrackerApp.swift` edits (T6) — platform init + first-workout-completed trigger + `.onOpenURL` → `DeepLinkRouter.handle(...)` + observe `pendingDeepLink`
- [ ] Settings → Notifications row (T7) in `FitTracker/Views/Settings/v2/SettingsView.swift`
- [ ] `SettingsDeepLinkBanner.swift` (T8)
- [ ] v1 demolition (T9, T10) — HISTORICAL banners on 4 files; delete dead `DeepLinkHandler.swift`
- [ ] Analytics (T11, T12) — drop unused v1 events; add `deep_link_routed`
- [ ] Tests (T13) — ≥20 unit cases across 4 test files
- [ ] Reachability gate (T14) — 3 XCTest cases (priming reachable, URL routes, SwiftUI subscriber observes)
- [ ] Build verify + project.pbxproj (T15)
- [ ] Runtime smoke profile (T16)

For Figma MCP agent (paired with `/design build`):
- [ ] Priming sheet frame (medium detent presentation)
- [ ] SettingsDeepLinkBanner frame
- [ ] Settings → Notifications row (3 state variants)
- [ ] readinessAlert banner frames (high + low) — extends Smart Reminders page `907:2`
- [ ] Capture node IDs back to `state.json.figma_node_ids`

---

## References

- **PRD:** `docs/product/prd/push-notifications.md`
- **UX Spec:** `.claude/features/push-notifications/ux-spec.md`
- **UX Research:** `.claude/features/push-notifications/ux-research.md`
- **Tasks:** `.claude/features/push-notifications/tasks.md`
- **State:** `.claude/features/push-notifications/state.json`
- **ux-foundations.md** — §5.2 (priming pattern), §3 (interaction patterns), §1 (principles)
- **CLAUDE.md** — analytics naming convention, branching rules, V2 Rule
- **Paired:** `docs/prompts/ui/2026-05-07-push-notifications-design-build.md`
