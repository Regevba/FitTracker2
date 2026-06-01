# Trend Alerts (HRV Threshold) — Tasks

**Work type:** Feature (9-phase: Research → PRD → Tasks → UX/Integration → Implement → Test → Review → Merge → Docs)
**PRD:** [`docs/product/prd/trend-alerts-hrv.md`](../../../docs/product/prd/trend-alerts-hrv.md) (approved 2026-06-01 in PR #564)
**RICE:** 10.5 (second on the 2026-05-31 refreshed Planned ranking)
**Effort estimate:** 3-4 days (0.5 person-weeks per state.json)
**Branch:** `feature/trend-alerts-hrv`

## Scope summary

Build the third notification observer (after `ReadinessAlertObserver` score-crossing + C2 `ReadinessAwareTrainingObserver` pre-training advisory) — fires daily at 08:00 local when HRV stays below the user's personal baseline for 3+ consecutive days. Surfaces via Home `AIInsightCard` banner + push notification + `AIIntelligenceSheet` "Your HRV Trend" section with 7-day mini-chart.

All algorithm constants and surface specs frozen in the PRD. This document breaks the implementation into 14 discrete, independently testable units.

## Tasks

### Phase 4 (Implement) — source files

**T1 — Data model**

Files: `FitTracker/Models/TrendAlertContext.swift` (new)

Define: `enum TrendAlertKind: String, Codable, Equatable, Sendable, CaseIterable { case hrvSustainedLow }` (future-proofed for `sleepSustainedLow`, `rhrSustainedHigh`) + `struct TrendAlertContext: Equatable, Codable, Sendable { kind, samples: [Double], baseline: Double, floor: Double, sustainedDays: Int, generatedAt: Date }`.

Acceptance: unit test verifies enum exhaustiveness + Equatable + Codable round-trip.

**T2 — Trigger logic (pure-function)**

Files: `FitTracker/Services/Reminders/TrendAlertTrigger.swift` (new)

Pure function `evaluate(hrvSamples: [Double], baseline: Double, floor: Double, sustainedDaysRequired: Int, generatedAt: Date) -> TrendAlertContext?`. Returns context when all samples ≤ floor AND samples.count == sustainedDaysRequired; nil otherwise. No `Date()` calls, no `UserDefaults` reads.

Acceptance: 12 unit tests covering: all-below-floor + correct count → fires; one-above-floor → nil; count mismatch (2/3 or 4/3) → nil; empty samples → nil; degenerate samples (NaN, Inf) → nil; cold-start case (floor=hardFloor=25) → fires correctly.

**T3 — Time learner**

Files: `FitTracker/Services/Reminders/TrendAlertDispatchTimeLearner.swift` (new — minimal v1)

For v1 PRD, returns fixed `DateComponents(hour: 8, minute: 0)`. Stub for future C4.c (learn from app-open patterns). Pure function for parity with C2's `TrainingStartTimeLearner` test pattern.

Acceptance: 2 trivial unit tests verifying constant return + DateComponents shape.

**T4 — Observer wired to NotificationGateway**

Files: `FitTracker/Services/Reminders/TrendAlertObserver.swift` (new)

`@MainActor final class TrendAlertObserver` with:
- Static consumer registration: `id = "push-notifications.trendAlert"`, primaryCapTag = `.standard`, urlPatterns = `["fitme://nav/home"]`
- `evaluate(hrvSamples:, baseline:, floor:, now:) async -> NotificationDispatchResult?` — calls trigger, checks 7-day de-dupe via UserDefaults, dispatches if all gates pass, marks fired-this-week stamp
- `isFeatureEnabled: () -> Bool` closure with default reading `ReminderPreferencesStore.trendAlertsEnabled` via UserDefaults
- DEBUG seam `_resetForTesting(date:)`

Acceptance: 6 unit tests covering opt-out gate, week-keyed de-dupe (today fired vs 8 days ago not fired), consumer registration shape (id, primaryCapTag, urlPatterns).

**T5 — UI observable store**

Files: `FitTracker/Services/Reminders/TrendAlertStore.swift` (new)

`@MainActor final class TrendAlertStore: ObservableObject` with `@Published private(set) var latest: TrendAlertContext?` + `update(_:)` + `clear()` + `current(at:calendar:) -> TrendAlertContext?` (returns nil if context is > 1 day stale).

Mirrors C2's `ReadinessAwareAlertStore` exactly. Both stores coexist as `@EnvironmentObject`s in the view hierarchy.

Acceptance: 4 unit tests covering update + clear + same-day current + cross-day staleness.

**T6 — HRV trend chart view**

Files: `FitTracker/Views/AI/HRVTrendChart.swift` (new)

SwiftUI `Chart` rendering 7-day HRV daily reads as a `LineMark` + `PointMark`. Horizontal `RuleMark` overlays at `baseline` (dotted) and `floor` (solid). Per-day annotations: green tick if ≥ baseline, amber if between floor and baseline, red if ≤ floor. Caption at bottom. Reuses AppTheme tokens (`AppColor.Chart.hrv`, `AppText.caption`, `AppSpacing.small`).

Acceptance: 2 snapshot-like tests verifying chart accepts the 7-sample input + renders without crash via ViewInspector pattern (or skipped if ViewInspector unavailable, fall back to compile-only).

### Phase 4 (Implement) — algorithm extension

**T7 — ReadinessEngine.personalBaseline stddev: extension**

Files: `FitTracker/Services/ReadinessEngine.swift` (modify)

Extend existing `personalBaseline(window:percentile:)` with new overload `personalBaseline(window:stddev:) -> Double?`. When `stddev: true`, returns the population std-dev of the same window. Reuses existing HRV history fetch; only the aggregation differs.

Acceptance: 10 unit tests on the extension alone — 0 reads → nil, 1 read → 0.0, 2 identical reads → 0.0, 3 identical reads → 0.0, normal-distribution sample → expected stddev within ε, edge case all-zeros → 0.0, large variance → expected stddev within ε.

### Phase 4 (Implement) — UI integration

**T8 — AIInsightCard banner override**

Files: `FitTracker/Views/AI/AIInsightCard.swift` (modify)

Add `@EnvironmentObject private var trendAlert: TrendAlertStore`. Banner precedence: check `readinessAware.current()` FIRST (C2 wins on training days); if nil, check `trendAlert.current()`; if non-nil, override `insightTitle` + `insightSubtitle` + `avatarMode` and call `analytics.logHomeTrendAlertShown(...)` on appear. Tap behavior: `analytics.logHomeTrendAlertTap(...)`, then open AIIntelligenceSheet (which scrolls to "Your HRV Trend" section).

Acceptance: 3 unit tests covering: C2-context-only → C2 wins; C4-context-only → C4 wins; both-set → C2 wins (training-day precedence).

**T9 — AIIntelligenceSheet "Your HRV Trend" section**

Files: `FitTracker/Views/AI/AIIntelligenceSheet.swift` (modify)

Add `@EnvironmentObject private var trendAlert: TrendAlertStore`. New `@ViewBuilder hrvTrendSection` between `readinessSection` and `AIFeedbackView`. When `trendAlert.current() != nil`, renders the new `HRVTrendChart` from T6 + thumbs-up/thumbs-down feedback affordance that fires `analytics.logHomeTrendAlertActionTaken(kind:, rating:)`.

Acceptance: covered by T8 banner tests + 1 sheet-integration test (TrendAlertStore mock + verify section renders).

**T10 — Settings toggle**

Files: `FitTracker/Services/Notifications/ReminderPreferencesStore.swift` + `FitTracker/Views/Settings/v2/Screens/NotificationsSettingsScreen.swift` (modify)

`ReminderPreferencesStore`: add `trendAlertsEnabled: Bool = true { didSet { UserDefaults.standard.set(...) } }` + init re-hydration + `Keys.trendAlerts = "ft.reminder.trendAlerts"`.

`NotificationsSettingsScreen`: add new `reminderToggle` row immediately after C2's "Readiness-Aware Advisory" with title "Trend Alerts" + detail "Heads-up when HRV trends below your baseline for 3+ days."

Acceptance: 3 unit tests covering default-true, persistence round-trip, opt-out short-circuit in TrendAlertObserver.

**T11 — Analytics events**

Files: `FitTracker/Services/Analytics/AnalyticsProvider.swift` + `FitTracker/Services/Analytics/AnalyticsService.swift` (modify)

`AnalyticsProvider`: add 4 event names (`homeTrendAlertShown`, `homeTrendAlertTap`, `homeTrendAlertActionTaken`, `homeTrendAlertDismissed`) + 2 params (`sustainedDays`, `kind` — reuse existing `baseline`, `score`, `rating`).

`AnalyticsService`: add 4 `logHomeTrendAlert*(...)` methods matching the param schema in PRD §"Analytics Events".

Acceptance: 1 analytics-naming test ensuring all 4 events have `home_` prefix (existing AnalyticsEventNamingTests will catch automatically).

**T12 — Consumer registration at app init**

Files: `FitTracker/FitTrackerApp.swift` (modify)

Add `NotificationConsumerRegistry.shared.register(TrendAlertObserver.consumerRegistration)` alongside C2's existing registration call.

Acceptance: 1 integration test in `NotificationConsumerRegistryTests` verifying both consumers register without urlPattern collision (both claim `fitme://nav/home` but the registry resolves to the first registered; PRD OQ-4 documents the C2-wins precedence — verify via the C2-registered-first guarantee in FitTrackerApp init order).

### Phase 5 (Test) — coverage targets

**T13 — Test suite + coverage gate**

Files: 4 new test files
- `FitTrackerTests/TrendAlertTriggerTests.swift` (12 tests)
- `FitTrackerTests/TrendAlertDispatchTimeLearnerTests.swift` (2 tests)
- `FitTrackerTests/TrendAlertObserverTests.swift` (6 tests covering opt-out + week-keyed de-dupe + consumer registration shape)
- `FitTrackerTests/TrendAlertStoreTests.swift` (4 tests)

Total: 24 new tests. Plus T7's 10 tests inline in `ReadinessEngineTests`; T8's 3 tests in `AIInsightCardTests`; T10's 3 tests in `ReminderPreferencesStoreTests`; T12's 1 test in `NotificationConsumerRegistryTests`. **Grand total: ~41 new tests.**

Acceptance: `xcodebuild test` passes locally + on CI; coverage on `TrendAlertTrigger.swift` + `TrendAlertObserver.swift` + `TrendAlertStore.swift` ≥ 90%.

### Phase 6-8 (Review → Merge → Docs)

**T14 — Docs + Case study + Backlog strike**

Files: new
- `docs/case-studies/trend-alerts-hrv-case-study.md` — full case study with T1/T2/T3 tier tags + 5 success metrics + 4 kill criteria + cross-references to C2 case study
- `fitme-story/content/04-case-studies/41-trend-alerts-hrv.mdx` — showcase MDX (slot 41, after C2's slot 40)

Update:
- `docs/product/backlog.md` — strike through L346 "Trend alerts" row with `[x]` + shipped date + PR link
- `state.json` — populate `case_study_showcase` field

Acceptance: `make integrity-check` clean post-merge; case study has all 7 required frontmatter fields; `FEATURE_CLOSURE_COMPLETENESS` write-time gate passes on `current_phase=complete` transition.

---

## Phase transition criteria

| From | To | Criterion |
|---|---|---|
| prd | tasks | Operator approves this tasks.md (the PRD was already approved in PR #564) |
| tasks | implement | All 14 tasks defined + operator approval to begin Phase 4 |
| implement | test | T1-T12 complete; swiftc -parse exit 0 on all new files; CI ci.yml green |
| test | review | T13 passes (~41 tests); coverage ≥ 90% on new files |
| review | merge | `/ux pre-merge-review` + `/design pre-merge-review` both pass |
| merge | complete | PR merged; T14 deliverables shipped; L346 struck through; FEATURE_CLOSURE_COMPLETENESS gate passes |

## Dependencies confirmed (all shipped at v7.9)

All dependencies enumerated in PRD §"Dependencies" + state.json `dependencies_met`. No new infrastructure needed.

## Cross-references

- PRD: [`docs/product/prd/trend-alerts-hrv.md`](../../../docs/product/prd/trend-alerts-hrv.md)
- Phase 0 research: [`research.md`](research.md)
- State: [`state.json`](state.json)
- Tier 2.2 log: [`../../logs/trend-alerts-hrv.log.json`](../../logs/trend-alerts-hrv.log.json)
- C2 sibling pattern (just shipped): [`docs/case-studies/readiness-aware-training-alert-case-study.md`](../../../docs/case-studies/readiness-aware-training-alert-case-study.md)
- Backlog row: `docs/product/backlog.md` L346 (line 374)
