# Push Notifications v2 — Task Breakdown

**PRD:** `docs/product/prd/push-notifications.md`
**Estimated effort:** ~6.75 days end-to-end (Phase 4 implementation only); ~5–6 calendar days through Phase 7 (Merge)
**Critical path:** T1 → T3 → T6 → T14 → T15 → T16 (≈ 3.75 days sequential)
**Parallel lanes available:** T2/T4/T5/T7/T8/T9/T10/T11/T12 fan out after their respective dependencies clear

## Tasks

| ID | Title | Type | Skill | Effort | Lane | Depends On | Status |
|---|---|---|---|---|---|---|---|
| T1 | `NotificationGateway` core: auth wrapper + dispatch surface + cap audit (global + critical bucket + pre-emption) | service | dev | 1.0d | P-core | — | pending |
| T2 | `NotificationConsumerRegistry`: per-consumer types + URL patterns + cap contributions (registration mechanism) | service | dev | 0.5d | P-core | — | pending |
| T3 | `DeepLinkRouter`: nested verb-noun URL grammar resolver, `@Published` nav state, `DeepLinkAction` enum, dual-source `handle(url:source:)` | service | dev | 1.0d | P-core | T2 | pending |
| T4 | Revive `NotificationPermissionPrimingView` — remove HISTORICAL banner, wire to `NotificationGateway.shared.requestAuthorization()` | ui | dev | 0.25d | E-core | T1 | pending |
| T5 | `ReadinessAlertObserver` — Combine subscription to `ReadinessEngine.latestScore`, threshold gate (≥80 / ≤40), confidence gate (≥2 HK signals in last 6h), de-dupe per direction per day, dispatch via `NotificationGateway` | service | dev | 0.5d | P-core | T1 | pending |
| T6 | `FitTrackerApp` wiring: platform init at app launch, first-workout-completed trigger → present priming, `.onOpenURL { url in DeepLinkRouter.shared.handle(url:.system) }`, observe `DeepLinkRouter.pendingDeepLink` and present/navigate via existing AppTab + sheet patterns | ui | dev | 0.5d | P-core | T1, T2, T3, T4, T5 | pending |
| T7 | Settings entry point: row in Settings tab → presents `NotificationPermissionPrimingView` (or routes to iOS Settings if permission already denied) | ui | dev | 0.25d | E-core | T4 | pending |
| T8 | One-time `notification_settings_deeplink_shown` banner after permission denial — debounced via UserDefaults flag, dismissible, opens iOS Settings on tap | ui | dev | 0.25d | E-core | T4 | pending |
| T9 | Mark v1 as HISTORICAL (banner header on 4 files: `NotificationService.swift`, `NotificationPreferencesStore.swift`, `NotificationContentBuilder.swift`, and any `NotificationDeepLinkHandler.swift` if present) | docs | dev | 0.1d | E-core | T1 | pending |
| T10 | Delete dead `FitTracker/Services/Notifications/DeepLinkHandler.swift` (the 14-LOC `targetTab` one) | docs | dev | 0.05d | E-core | T3 | pending |
| T11 | Drop unused v1 `AnalyticsEvent` declarations: `notificationScheduled`, `notificationDelivered`, `notificationTapped`, `notificationDismissed`, `notificationDisabled` + remove rows from `analytics-taxonomy.csv` | analytics | analytics | 0.25d | E-core | — | pending |
| T12 | Add `deep_link_routed` event to `AnalyticsEvent` + `AnalyticsParam` (source / destination / url_pattern / outcome) + new row in `analytics-taxonomy.csv` (screen_scope=global) | analytics | analytics | 0.1d | E-core | — | pending |
| T13 | Unit tests: `NotificationGatewayTests` (≥5), `DeepLinkRouterTests` (≥5), `NotificationConsumerRegistryTests` (≥5), `ReadinessAlertTriggerTests` (≥5) — minimum 20 cases total | test | qa | 1.0d | P-core | T1, T2, T3, T5 | pending |
| T14 | Reachability gate (P0 — non-skippable, codifies v1 UI-016 lesson): 3 XCTest cases — (a) priming reachable from workout-completed event in SwiftUI root harness, (b) every registered URL pattern resolves to expected `DeepLinkAction` and the SwiftUI subscriber observes it, (c) `UNNotificationResponse` simulation routes end-to-end through `DeepLinkRouter` to expected destination | test | qa | 0.5d | P-core | T6 | pending |
| T15 | Build verification: `make tokens-check && xcodebuild build && xcodebuild test && make ui-audit` all green; `project.pbxproj` updated for new files (5 added: NotificationGateway, DeepLinkRouter, NotificationConsumerRegistry, ReadinessAlertObserver, plus the 4 new test files) and 1 deleted (DeepLinkHandler.swift removed from Sources) | test | dev | 0.25d | E-core | T1, T2, T3, T5, T6, T13, T14 | pending |
| T16 | Runtime smoke profile `notification_platform_v2`: `make runtime-smoke PROFILE=notification_platform_v2 MODE=local` — install + complete workout → priming → grant → schedule readinessAlert via debug menu → tap → assert lands on Home | test | qa | 0.25d | E-core | T15 | pending |

**Total tasks:** 16
**Total effort:** 6.75 days (≈ 1 calendar week given dependency depth + lane parallelism)

## Architecture Notes

- **`NotificationGateway`**: singleton `@MainActor`, owns `UNUserNotificationCenter`. `dispatch(content:trigger:tag:)` is the single entry point. Cap audit checks (a) global daily cap (3/day, inherited from smart-reminders' window), (b) critical bucket (1/day for `readinessAlert`-tagged dispatches, can pre-empt global cap), (c) quiet hours (22:00–07:00). Returns `DispatchResult` enum (`.dispatched | .suppressed(reason:) | .denied_unauthorized | .preempted`).
- **`NotificationConsumerRegistry`**: dict-backed `[ConsumerID: ConsumerEntry]`. `ConsumerEntry` carries `types: [TypeID]`, `urlPatterns: [String]`, `capContribution: CapContributionPolicy`. Registration at app-init time in `FitTrackerApp.swift`.
- **`DeepLinkRouter`**: `@MainActor`, `@Published var pendingDeepLink: DeepLinkAction?`. Source enum (`.notification | .system | .programmatic`). `handle(url:source:)` matches URL → registered pattern → emits `DeepLinkAction`. SwiftUI root observes via `.onChange(of:)` and presents/navigates. Same pattern as existing `signIn.pendingPasswordResetURL` (`FitTrackerApp.swift:202-213`).
- **`ReadinessAlertObserver`**: `@MainActor`, observes `ReadinessEngine.latestScore` via Combine `.sink`. On threshold cross + confidence gate pass + de-dupe pass, builds `UNMutableNotificationContent` with deep-link `fitme://nav/home`, calls `NotificationGateway.shared.dispatch(...)`. Owned by `FitTrackerApp` (held strongly during app lifetime).

## Skill Routing (v5.1 model tiering)

- **P-core (opus, serial):** T1, T2, T3, T5, T6, T13, T14 — service architecture + integration glue + test infrastructure (judgment-heavy)
- **E-core (sonnet, parallel):** T4, T7, T8, T9, T10, T11, T12, T15, T16 — mechanical edits, taxonomy updates, CI verification (low-judgment)

## Branching

- Branch: `feature/push-notifications-v2`
- Touches > 5 files (≈ 12 new + 5 edited + 4 HISTORICAL banners + 1 deleted) AND adds new services → must use feature branch per CLAUDE.md branching rules
- Smart-reminders consumer-integration enhancement ships in same release window (paired backlog item, separate PR or combined squash-merge — TBD at Phase 7)

## Test Strategy

- **Unit tests (T13):** ≥ 20 XCTest cases covering platform layer in isolation. Hermetic — no simulator parallelism, no network.
- **Reachability gate (T14):** SwiftUI view harness (XCTest, not XCUITest, to avoid the parallel-clone simulator hang env-flake per `docs/case-studies/m-4-xcuitest-infrastructure-case-study.md`). Asserts the user-facing path actually fires, not just substrate-callable.
- **Runtime smoke (T16):** `notification_platform_v2` profile per `docs/process/runtime-smoke-gates.md`. Manual-on-simulator verification before merge; no CI dependency.

## Cross-References

- **PRD:** `docs/product/prd/push-notifications.md`
- **Research:** `.claude/features/push-notifications/research.md`
- **State:** `.claude/features/push-notifications/state.json`
- **Smart-reminders consumer integration (paired enhancement):** `docs/product/backlog.md` → "Smart Reminders ↔ Push Notifications v2 deep-link integration"
- **v1 archive:** `.claude/features/push-notifications/_v1/`
- **Linear:** FIT-23
