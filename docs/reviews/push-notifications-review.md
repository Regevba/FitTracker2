# Push Notifications — Code Review

## Summary
The Push Notifications subsystem is well-structured and follows established project patterns cleanly. There are no critical bugs blocking merge, but two meaningful gaps exist: the frequency cap (`maxDailyNotifications`) is stored as a preference but never enforced at scheduling time, and `NotificationPermissionPrimingView` bypasses `NotificationService.shared` to call `UNUserNotificationCenter` directly, creating a split authority problem.

## Files Reviewed

| File | Lines |
|------|-------|
| `FitTracker/Services/Notifications/NotificationService.swift` | 121 |
| `FitTracker/Services/Notifications/NotificationPreferencesStore.swift` | 89 |
| `FitTracker/Services/Notifications/NotificationContentBuilder.swift` | 51 |
| `FitTracker/Services/Notifications/DeepLinkHandler.swift` | 14 |
| `FitTracker/Views/Notifications/NotificationPermissionPrimingView.swift` | 101 |
| `FitTrackerTests/NotificationTests.swift` | 149 |
| **Total** | **525** |

## Findings

### Critical (must fix before merge)

**C1 — Frequency cap is never enforced**
`NotificationPreferencesStore.maxDailyNotifications` is stored and surfaced as a preference (default: 2), and the header comment of `NotificationService.swift` explicitly advertises "daily frequency cap" enforcement. However, `scheduleNotification()` never reads `maxDailyNotifications` and never consults a daily sent-count. The cap is completely inert. Compare with `ReminderScheduler.swift` which correctly tracks a `ft.reminder.dailyCount.{date}` key in UserDefaults. Either implement the cap in `scheduleNotification()` (check count, increment on success, reset at midnight) or remove the preference and update the comment to remove the false claim.

**C2 — `NotificationPreferencesStore.isEnabled(for:)` is never consulted before scheduling**
`scheduleNotification()` checks `isAuthorized` and `isQuietHour()` but never calls `preferencesStore.isEnabled(for: type)`. A type the user disabled in Settings will still be scheduled. The preferences store is an orphaned object with no wire-up to the service.

### Important (should fix)

**I1 — `NotificationPermissionPrimingView` calls `UNUserNotificationCenter` directly**
The view makes its own `requestAuthorization` call on lines 87-98, completely bypassing `NotificationService.shared`. This means `NotificationService.isAuthorized` is never updated after the priming view grants permission — the singleton stays stale until the next cold start (when `refreshAuthorizationStatus()` is called from `init`). Fix: inject or reference `NotificationService.shared` from the view and call `await NotificationService.shared.requestAuthorization()` instead. The view's local `permissionGranted`/`permissionDenied` state can still drive the UI based on `NotificationService.shared.isAuthorized`.

**I2 — `cancelByType` spawns an unstructured `Task` in a `@MainActor` class**
`cancelByType(_:)` creates a detached-style `Task { }` inside a `@MainActor final class`. This means the cancellation races with any concurrent scheduling on that type and is not awaitable by callers. The method should be `async` (caller uses `await`) or, since `UNUserNotificationCenter.pendingNotificationRequests()` is already async, the function should at least document that the cancellation is best-effort and non-immediate.

**I3 — T10-1 test isolation is broken**
`testPreferencesDefaults()` creates an isolated `UserDefaults(suiteName:)` suite and clears it, but then constructs `NotificationPreferencesStore()` which reads from `UserDefaults.standard` — not from the isolated suite. The isolation is therefore a no-op; the test can be polluted by values left by T10-8/T10-9 in `standard`. Either inject a `UserDefaults` instance into `NotificationPreferencesStore` or make the test explicitly clear the relevant keys from `UserDefaults.standard` before constructing the store.

**I4 — T10-9 mutates `UserDefaults.standard` and may pollute other tests**
`testMasterKillSwitchDisablesAll` sets `store.masterEnabled = false` and restores it in the same test, but if an assertion fails the restore line is never reached, leaving `masterEnabled = false` in `UserDefaults.standard` for subsequent tests. Use `addTeardownBlock` or restructure the test to guarantee cleanup.

### Suggestions (nice to have)

**S1 — `NotificationService` has no `shared` singleton in practice**
`static let shared` is declared but no call site in the codebase uses `NotificationService.shared` (grep returns only the declaration). The service comment says it "delegates to `NotificationPreferencesStore`" but no `preferencesStore` property exists on the class. Either make it a proper singleton with injected preferences store, or drop the `shared` and document that it is instantiated by the feature coordinator.

**S2 — `scheduleNotification` silently swallows errors with no logging**
The `catch` block on line 89 discards the error with only a comment. For a production service, at minimum `os_log` (or the project's analytics layer) should record the failure type and identifier so scheduling regressions are observable.

**S3 — `readinessAlert` score is not range-clamped**
`NotificationContentBuilder.readinessAlert(score:)` accepts any `Int`. A caller passing a negative or >100 value produces a nonsensical body like `Score: -5/100`. A `precondition(0...100 ~= score)` in debug builds (or a simple clamp) would catch bad inputs early.

**S4 — `DeepLinkHandler` has no test for path components**
The current `targetTab(from:)` only inspects `url.host` and ignores `url.path`. Deep links like `fitme://training/session/123` will route correctly, but `fitme://home/settings` will also resolve to `.main` even though it would be more precise to verify the path is empty or `/`. No hard bug given current deep-link set, but worth documenting the intentional behavior in a code comment.

**S5 — T10-10 quiet-hour test does not exercise `NotificationService.isQuietHour()` directly**
The test replicates the boundary logic inline (`h >= 22 || h < 7`) rather than calling `isQuietHour()`. This validates the logic in the test file but not the actual implementation. Consider extracting the pure hour-check to a testable static function `isQuietHour(hour:)` so the test can call `NotificationService.isQuietHour(hour: h)` and truly exercise the production code.

## Verdict

**REQUEST_CHANGES**

C1 and C2 are the blockers: the feature advertises preference-gated, frequency-capped notifications but enforces neither. The priming view's direct authorization path (I1) also means the service's published state is stale after the first permission grant. Fix these three and the feature is mergeable.
