# Design Pre-Merge Review — push-notifications-v2

**Phase:** 6 (Review), Step 6c (`/design pre-merge-review`)
**Date:** 2026-05-07
**Branch:** `feature/push-notifications-v2`
**Paired with:** `ux-pre-merge-review-2026-05-07.md`

---

## 1. `make ui-audit` — P0/P1 status

| Surface | P0 | P1 | Status |
|---|---|---|---|
| `FitTracker/Views/Notifications/NotificationPermissionPrimingView.swift` | 0 | 0 | ✓ Clean |
| `FitTracker/Views/Notifications/SettingsDeepLinkBanner.swift` | 0 | 0 | ✓ Clean |
| `FitTracker/Views/Notifications/NotificationPermissionRow.swift` | 0 | 0 | ✓ Clean (after `AppSize.iconBadge` fix-as-you-touch) |

**Verdict: P0=0 across all v2 view files. CLAUDE.md `ui-audit` hard-gate within `verify-local` PASSES.**

Token compliance: all v2 surfaces use semantic tokens (`AppText.*`, `AppSpacing.*`, `AppColor.*`, `AppRadius.*`, `AppSize.*`, `AppGradient.*`). No raw color literals, no magic dimensions, no raw font sizes outside the SF Symbol font-size pattern.

WCAG AA contrast: pre-validated via the existing semantic token system (no new color combinations introduced).

Motion: only `SettingsDeepLinkBanner` uses an explicit transition (`.move(edge: .top).combined(with: .opacity)`), reduce-motion-gated via `@Environment(\.accessibilityReduceMotion)`. All other surfaces use default UIKit motion (sheet, NavigationStack, system transitions).

## 2. Figma Node IDs Presence Check

| Surface | Figma node | state.json.figma_node_ids | Status |
|---|---|---|---|
| Push Notifications v2 page | `936:2` | ✓ recorded | Present |
| Section frame | `936:3` | ✓ recorded | Present |
| PrimingView sheet | `937:6` | ✓ recorded | Present |
| Settings → Notifications row (3 states) | `937:46` | ✓ recorded | Present |
| SettingsDeepLinkBanner | `938:2` | ✓ recorded | Present |
| readinessAlert banners (high + low) | `938:50` | ✓ recorded | Present |

**Verdict: 6/6 Figma node IDs recorded in `state.json.figma_node_ids`.**

PR description requirement (per CLAUDE.md "Synced" definition): not yet applicable — no PR opened. Will be enforced at PR creation; the IDs are ready to copy into the description.

## 3. Token Compliance Delta

Net change to `AppTheme.swift`: **zero new tokens added, zero tokens removed.** All v2 surfaces compose from existing tokens. The `AppSize.iconBadge` (26pt) used by `NotificationPermissionRow` already existed (line 195 of AppTheme.swift, "Icon badge / inset element"). Semantic match.

## 4. Build + Test Verification

- `xcodebuild build` (iOS Simulator, no code signing) → **`** BUILD SUCCEEDED **`**
- `xcodebuild test` (FitTrackerCoreTests + SyncMergeTests) → **`** TEST SUCCEEDED **`** — no regressions
- `xcodebuild test` (push-notifications-v2 isolated, all 5 test classes) → **`** TEST SUCCEEDED **`** — 36/36 pass

## 5. Screenshot Diff (Manual)

Optional per skill spec. Deferred — Figma frames built 2026-05-07 by `/design build`; runtime screenshots will be captured during T16 manual sim run. The visual idiom matches Smart Reminders page `907:2` (verified during build via `get_screenshot 936:3`).

## 6. Verdict

**PASSED** — `state.json.pre_merge_review.design = "passed"`.

Phase 7 (Merge) approvable from /design gate.
