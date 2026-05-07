# UX Preflight Audit — push-notifications-v2

**Phase:** 3 (UX/Integration), Step 3e (`/ux preflight`)
**Date:** 2026-05-07
**Spec:** `.claude/features/push-notifications/ux-spec.md`
**Gate:** P0 unresolved → spec NOT approvable for Phase 4

---

## Tokens (20 referenced — all resolve)

| Token | Status | grep hits in `FitTracker/` |
|---|---|---|
| `AppText.titleStrong` | ✓ resolves | 12 files |
| `AppText.body` | ✓ resolves | 47 files |
| `AppText.button` | ✓ resolves | 35 files |
| `AppText.caption` | ✓ resolves | 72 files |
| `AppText.captionStrong` | ✓ resolves | 31 files |
| `AppSpacing.large` | ✓ resolves | 50 files |
| `AppSpacing.medium` | ✓ resolves | 58 files |
| `AppSpacing.small` | ✓ resolves | 66 files |
| `AppSpacing.xSmall` | ✓ resolves | 71 files |
| `AppRadius.medium` | ✓ resolves | 29 files |
| `AppRadius.button` | ✓ resolves | 26 files |
| `AppColor.Accent.primary` | ✓ resolves | 38 files |
| `AppColor.Text.primary` | ✓ resolves | 71 files |
| `AppColor.Text.secondary` | ✓ resolves | 79 files |
| `AppColor.Text.tertiary` | ✓ resolves | 54 files |
| `AppColor.Text.inversePrimary` | ✓ resolves | 42 files |
| `AppColor.Status.warning` | ✓ resolves | 27 files |
| `AppColor.Surface.secondary` | ✓ resolves | 13 files |
| `AppSize.ctaHeight` | ✓ resolves | 17 files |
| `AppGradient.screenBackground` | ✓ resolves | 40 files |

**Token verdict: 20/20 resolve. P0 = 0.**

---

## Components / Types (5 referenced — all resolve)

| Reference | Status | Source |
|---|---|---|
| `NotificationPermissionPrimingView` | ✓ exists (revival target — currently HISTORICAL) | `FitTracker/Views/Notifications/NotificationPermissionPrimingView.swift` |
| `RootTabView` | ✓ exists | `FitTracker/Views/RootTabView.swift` |
| `ReminderNotificationDelegate` | ✓ exists | `FitTracker/Services/Reminders/ReminderNotificationDelegate.swift` |
| `signIn.pendingPasswordResetURL` (pattern reference) | ✓ exists | `FitTracker/FitTrackerApp.swift:202-213` |
| `SessionCompletionSheet` (post-workout trigger surface) | ✓ exists | `FitTracker/Views/Training/v2/SessionCompletionSheet.swift` |

**Note (P1 finding, NON-BLOCKING):** the spec's first draft referenced `WorkoutResultsView`. The actual post-workout sheet is `SessionCompletionSheet`. **Spec auto-corrected before publish** — replaced 3 occurrences. No further action needed.

**Component verdict: 5/5 resolve. P0 = 0; P1 = 0 (auto-corrected).**

---

## Components Planned-New (4 referenced — must be NEW per spec; not expected to exist yet)

| Reference | Status | Expected at |
|---|---|---|
| `NotificationGateway` | NEW (not yet built — Phase 4 T1) | `FitTracker/Services/Notifications/NotificationGateway.swift` |
| `DeepLinkRouter` | NEW (not yet built — Phase 4 T3) | `FitTracker/Services/Notifications/DeepLinkRouter.swift` |
| `NotificationConsumerRegistry` | NEW (not yet built — Phase 4 T2) | `FitTracker/Services/Notifications/NotificationConsumerRegistry.swift` |
| `SettingsDeepLinkBanner` | NEW (not yet built — Phase 4 T8) | `FitTracker/Views/Notifications/SettingsDeepLinkBanner.swift` |

**Verdict:** All 4 are explicitly planned-new in the spec. Their absence today is expected (Phase 4 will create them). Not findings — informational only.

---

## Patterns (3 referenced — all attested in codebase)

| Reference | Status | Sample location |
|---|---|---|
| `.presentationDetents([.medium, .large])` | ✓ attested | iOS 16+ standard, used in existing sheets |
| `.transition(.move(edge: .top).combined(with: .opacity))` | ✓ attested | Used in existing banners |
| `@AppStorage` for UserDefaults flag | ✓ attested | Used across the app (settings, onboarding, reminders) |

**Pattern verdict: 3/3 attested. P0 = 0; P2 = 0 (no net-new patterns).**

---

## Findings Summary

| Severity | Count | Status |
|---|---|---|
| **P0 (blocks spec approval)** | **0** | ✓ |
| P1 (should fix in spec) | 1 (auto-corrected pre-publish: `WorkoutResultsView` → `SessionCompletionSheet`) | ✓ resolved |
| P2 (new-to-codebase pattern, document only) | 0 | n/a |

**GATE STATUS: PASS** — `state.json.phases.ux_or_integration.preflight_passed = true`

Spec is approvable for Phase 4 implementation from the `/ux preflight` perspective. Next step: `/design preflight` (DS compliance + Figma MCP liveness).
