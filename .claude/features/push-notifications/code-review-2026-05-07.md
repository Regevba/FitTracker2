# Code Review (Step 6a) — push-notifications-v2

**Phase:** 6 (Review), Step 6a (generic diff + risk surface)
**Date:** 2026-05-07
**Branch:** `feature/push-notifications-v2`

---

## 1. Diff Surface (vs main)

**Files added (13):**

Platform services (Notifications/):
- `NotificationGateway.swift` — auth + dispatch + cap audit
- `NotificationConsumerRegistry.swift` — per-consumer registration
- `DeepLinkRouter.swift` — single URL → action surface
- `ReadinessAlertObserver.swift` — readinessAlert consumer
- `FirstWorkoutTrigger.swift` — first-workout-completed trigger

Platform views (Notifications/):
- `NotificationPermissionPrimingView.swift` (revived from v1; HISTORICAL banner removed)
- `SettingsDeepLinkBanner.swift`
- `NotificationPermissionRow.swift`

Tests:
- `NotificationGatewayTests.swift`
- `DeepLinkRouterTests.swift`
- `NotificationConsumerRegistryTests.swift`
- `ReadinessAlertTriggerTests.swift`
- `PushNotificationsReachabilityTests.swift`

**Files edited (7):**
- `FitTracker/FitTrackerApp.swift` — platform init + onOpenURL routing + first-workout listener + priming sheet (~30 LOC additive)
- `FitTracker/Views/RootTabView.swift` — `.onChange(of: deepLinkRouter.pendingDeepLink)` → tab switch (~12 LOC additive)
- `FitTracker/Views/Training/v2/TrainingPlanView.swift` — `FirstWorkoutTrigger.mark()` in `onDone` (5 LOC)
- `FitTracker/Views/Settings/v2/SettingsView.swift` — `NotificationPermissionRow` insertion (3 LOC)
- `FitTracker/Services/Analytics/AnalyticsProvider.swift` — drop 5 unused v1 events; add 2 new + 5 params (+11 net)
- `FitTracker/Services/Analytics/AnalyticsService.swift` — drop 2 unused log methods; add 4 new (+27 net)
- `docs/product/analytics-taxonomy.csv` — 7 new rows for notification platform events

**Files marked HISTORICAL (5):**
- `FitTracker/Services/Notifications/NotificationService.swift`
- `FitTracker/Services/Notifications/NotificationPreferencesStore.swift`
- `FitTracker/Services/Notifications/NotificationContentBuilder.swift`
- `FitTrackerTests/NotificationTests.swift`
- `FitTrackerTests/NotificationServiceTests.swift`

**Files deleted (1):**
- `FitTracker/Services/Notifications/DeepLinkHandler.swift` (dead code, zero callers)

**pbxproj edits:**
- 7 new app source files added to FitTracker target Sources phase
- 5 new test files added to FitTrackerTests target Sources phase
- 1 file removed from Sources (DeepLinkHandler)
- 5 files removed from Sources but kept as PBXFileReference (HISTORICAL)

---

## 2. High-Risk Surfaces (per CLAUDE.md)

| File | Touched? |
|---|---|
| `DomainModels.swift` | No |
| `EncryptionService.swift` | No |
| `SupabaseSyncService.swift` | No |
| `CloudKitSyncService.swift` | No |
| `SignInService.swift` | **No direct edit** — referenced via `DeepLinkRouter.authHandler` closure that calls `signIn.handleIncomingURL(url)`. Auth-polish-v2 password-reset flow preserved exactly: same call site, same handler, same fullScreenCover binding. |
| `AuthManager.swift` | No |
| `AIOrchestrator.swift` | No |

**Risk verdict: LOW.** No high-risk surface mutated. Only one indirect reference (auth handler closure) which preserves the existing behavior verbatim.

---

## 3. CI Status

- Local `verify-ios` (build + test): **PASSED**
- Push-notifications-v2 isolated test run: **PASSED** (36/36)
- main branch: presumed green (last merge was PR #238 cross-reference sync 2026-05-06; no commits since)
- Feature branch: not yet pushed; CI run pending push

---

## 4. Bug Caught + Fixed During Review

**`ReadinessAlertObserver.swift`** — referenced `result.score` instead of `result.overallScore`. Build failed at first attempt; one-line fix landed; build re-ran clean. Demonstrates the build-verify gate works as intended.

---

## 5. Verdict

**APPROVED** for merge from the generic-review perspective.

Paired UI gates:
- `/ux pre-merge-review` — **PASSED**
- `/design pre-merge-review` — **PASSED**

Phase 7 (Merge) approvable.
