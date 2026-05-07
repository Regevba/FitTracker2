# UX Pre-Merge Review — push-notifications-v2

**Phase:** 6 (Review), Step 6b (`/ux pre-merge-review`)
**Date:** 2026-05-07
**Spec:** `.claude/features/push-notifications/ux-spec.md` (approved 2026-05-07)
**Branch:** `feature/push-notifications-v2`
**Paired with:** `design-pre-merge-review-2026-05-07.md`

---

## Spec-vs-Code Matrix

| Spec section | Spec deliverable | Code touchpoint | Status |
|---|---|---|---|
| §1.1 Primary flow (post-workout → priming → grant → tap) | 5-step flow from SessionCompletionSheet dismiss to navigation | `TrainingPlanView v2:113` (FirstWorkoutTrigger.mark) → `FitTrackerApp.swift:.onReceive(.fitMeFirstWorkoutCompleted)` → `.sheet($showNotificationPriming)` → `NotificationPermissionPrimingView` → `NotificationGateway.requestAuthorization()` | ✓ Matches |
| §1.2 Skip flow (Not now → no OS dialog) | "Not now" button preserves OS one-shot privilege | `NotificationPermissionPrimingView.swift:117–122` (`logNotificationPrimingSkipped` + dismiss without calling requestAuthorization) | ✓ Matches |
| §1.3 Denial flow (Don't Allow → SettingsDeepLinkBanner) | One-time banner on Home post-denial | `SettingsDeepLinkBanner.swift` with `@AppStorage("ft.notification.banner.dismissed")` flag | ✓ Matches |
| §1.4 Edge: already-granted-via-Settings | Auto-dismiss with brief success | `NotificationPermissionPrimingView.swift:125–131` (refreshAuthorizationStatus on appear → dismiss if isAuthorized) | ✓ Matches |
| §1.4 Edge: dual-source race | Idempotent within 200ms | `DeepLinkRouter.swift:91–98` (lastHandled tuple + dedupeWindow) + `testRapidDuplicateHandleIsNoOp` test | ✓ Matches |
| §1.4 Edge: cold-start from notification | DeepLinkRouter holds pendingDeepLink until subscriber | `DeepLinkRouter.swift:74` (`@Published var pendingDeepLink`) — observable by RootTabView's `.onChange(of:)` | ✓ Matches |
| §2.1 PrimingView sheet | bell icon → title → body → 3-category list → primary CTA → "Not now" | `NotificationPermissionPrimingView.swift` lines 53-122 | ✓ Matches; medium+large detents per `.presentationDetents` line in FitTrackerApp |
| §2.2 SettingsDeepLinkBanner | warning triangle + text stack + Open Settings + dismiss X | `SettingsDeepLinkBanner.swift` lines 29-65 | ✓ Matches; reduce-motion gate present (line 71) |
| §2.3 Settings → Notifications row (3 states) | Enable / Open Settings / Enabled ✓ | `NotificationPermissionRow.swift` `subtitle` + `iconName` + `iconTint` switches on (isAuthorized × permissionRequested) | ✓ Matches |
| §2.4 Notification content matrix | readinessAlert high+low copy | `ReadinessAlertObserver.swift:131–147` (buildContent fn) | ✓ Matches PRD copy verbatim |
| §3 Full-screen composite | All elements assembled | Visual fidelity verified during /design build (Figma node `937:6`) — Phase 3.j artifact | ✓ Matches |
| §4 State matrix (5 states/surface) | Default/Granted/Denied for PrimingView; visible/hidden for Banner; 3 states for Settings row | All states reachable via PrimingState enum + AppStorage flag + computed subtitle | ✓ Matches |
| §5 Interaction patterns | sheet/banner/row navigation; haptic on grant; transition gates | `Haptics.notification(.success)` on grant; banner `.transition(.move(edge: .top).combined(with: .opacity))` reduce-motion-gated | ✓ Matches |
| §6 Accessibility | VoiceOver labels, Dynamic Type, ≥44pt tap targets, reduce-motion | All 6 interactive elements have `.accessibilityLabel` + `.accessibilityHint` (PrimingView CTA, "Not now", banner Open Settings/X, settings row); CTA height = `AppSize.ctaHeight` (52pt); all text uses scaling tokens | ✓ Matches |
| §7 Principle Application Table | 8 of 13 principles applied | All applied principles verified inline (Jakob's, Progressive Disclosure, Recognition over Recall, Feedback, Error Prevention, Privacy by Default, Progressive Profiling, Celebration not Guilt) | ✓ Matches |
| §8 Component Inventory | 1 revived + 4 new components | `NotificationPermissionPrimingView` (revived) + `SettingsDeepLinkBanner` + `NotificationPermissionRow` + `CategoryListView` (private) + `DenialHintRow` (private) | ✓ Matches |
| §9 Token References | 20 tokens, no new tokens needed | All 20 verified via `/ux preflight`; spec used `AppSize.iconBadge` post-publish to fix Settings row icon affordance (P1 ui-audit fix-as-you-touch) | ✓ Matches with one minor adjustment |

---

## Heuristic Re-Check (13 ux-foundations principles)

All 8 applicable principles still hold against shipped code. Scores match validate report (Nielsen 38/40, 11/11 applicable principles) — no implementation drift detected.

## Spec-Spot-Checked File:Line Touchpoints

- `FitTrackerApp.swift:.onOpenURL` → routes through `DeepLinkRouter.shared.handle(url:source:.url)` ✓ (line 224 area)
- `RootTabView.swift:.onChange(of: deepLinkRouter.pendingDeepLink)` → drives `selectedTab` ✓ (line 65 area)
- `ReminderNotificationDelegate` post path — UNCHANGED in v2 (smart-reminders consumer-side adaptation is the paired backlog enhancement, not v2's scope)

## Drift Findings

**None.** Implementation matches spec contract exactly with one minor improvement (`AppSize.iconBadge` token usage on the Settings row icon — fix-as-you-touch P1 cleanup, not a drift).

## Verdict

**PASSED** — `state.json.pre_merge_review.ux = "passed"`.

Phase 7 (Merge) approvable from /ux gate.
