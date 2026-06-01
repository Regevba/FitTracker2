# PRD: Trend Alerts (HRV Threshold)

> **ID:** trend-alerts-hrv | **Status:** Phase 1 (PRD) — in flight | **Priority:** MEDIUM
> **Framework version:** v7.9 | **Branch:** `feature/trend-alerts-hrv`
> **Backlog source:** [`docs/product/backlog.md` L346 line 374](../backlog.md)
> **Phase 0 (Research):** [`.claude/features/trend-alerts-hrv/research.md`](../../.claude/features/trend-alerts-hrv/research.md) — shipped in PR #562 (`8121294`)
> **Parent PRD:** None (standalone Feature). Closely related to [smart-reminders](smart-reminders.md) (shared NotificationGateway consumer), [readiness-score-v2](recovery-biometrics.md) (HealthKit HRV reads), [push-notifications-v2](push-notifications.md) (dispatch + cap routing).

---

## Purpose

Surface a multi-day sustained-trend HRV alert that catches the gap between two existing observers: `ReadinessAlertObserver` (single-day score crossing) and `ReadinessAwareTrainingObserver` (daily pre-training advisory). When a user's HRV stays below their personal baseline for 3+ consecutive days, fire one advisory per 7-day window — surfaced via Home `AIInsightCard` banner + push notification + a "Why?" affordance opening `AIIntelligenceSheet` with the 7-day HRV mini-chart + baseline overlay.

## Problem Statement

FitMe has three notification observers operational as of 2026-06-01 (post-C2 merge):

| Observer | Trigger | Window | Catches |
|---|---|---|---|
| `ReadinessAlertObserver` | Score crosses ≥80 OR ≤40 | Single-day event | Acute readiness spikes/drops |
| `ReadinessAwareTrainingObserver` (C2) | Readiness + scheduled training day | Today only, at learned start time | "Should I train today?" decision aid |
| `TrendAlertsObserver` (C4 — this PRD) | HRV ≤ personal baseline for ≥3 days | Rolling 3-day window | **Sustained patterns the others miss** |

The gap: a power user with HRV stable at 55 (their normal) drops to 38 for three days running. ReadinessAlertObserver doesn't fire (never crossed ≤40). ReadinessAwareTrainingObserver fires only on training days. The sustained pattern is invisible until the user opens the app and notices the trend on the Stats screen — too late to act.

**Empirical evidence:** during the 2026-04-21 Gemini independent audit, the team self-identified "multi-day HRV trend silently absent from notification surface" as a Tier-2 finding. The audit was the trigger for the v7.5 Data Integrity Framework but the user-facing notification gap was deferred to backlog L346 (now C4).

## Business Objective

Surface the sustained-pattern signal that the existing single-day observers miss, so power users with stable HRV history can act on accumulating fatigue / infection onset / chronic sleep deficit BEFORE the pattern produces a single-day crash that ReadinessAlertObserver would catch. Targets the WAU Layer ≥ 2 cohort (~28% of WAU per 2026-05-04 master plan §1.4) — users with 4+ weeks of HealthKit data where the personal baseline is reliable.

---

## Success Metrics

Per the 2026-04-21 Gemini Tier 2.3 convention, all metrics carry T1/T2/T3 tier labels.

| Metric | Tier | Baseline | Target | Window | Notes |
|---|---|---|---|---|---|
| Trend-alert action-taken rate | T2 | 0% | ≥ 30% (alert tap → AIIntelligenceSheet open) | 14d post-launch | T2 declared baseline from analogous Smart Reminders v1 ~32% home_action_tap rate |
| User-reported false-positive rate | T3 | 0% | < 15% | 30d | Via in-app feedback button (Why? sheet "Was this useful?" thumbs-down) |
| HRV recovery within 7 days of fire | T1 | — | descriptive only | 14d | Captured via `home_readiness_alert_action_taken` event + healthkit_hrv weekly aggregate |
| Push-fatigue rate (dismissals / shown) | T2 | 60% | ≤ 60% | 30d | ReadinessAlertObserver baseline used as comparison |
| Adoption rate (eligible users with ≥1 fire) | T1 | 0% | ≥ 15% of Layer-≥2 cohort | 30d | Eligible = 4+ weeks of HealthKit data |

## Kill Criteria

If any fires during the 30-day window, the feature flips to opt-out-default-FALSE pending threshold-tuning patch:

- Action-taken rate < 5% after 14d organic exposure → advisory ignored
- User-reported FP rate > 20% via in-app feedback → algorithm too noisy
- Push-fatigue rate > 75% → advisory treated as spam
- Adoption rate < 5% of Layer ≥2 cohort → personal-baseline computation broken or threshold too restrictive

---

## Requirements

### User stories

- **US-1.** As a power user with 4+ weeks of HRV history, I receive a daily morning push if HRV has been below my personal baseline for 3+ consecutive days.
- **US-2.** As any user, the in-app Home card banner reflects the sustained-trend state on app-open (even if push is denied).
- **US-3.** As any user, I can tap the banner / push to open the AIIntelligenceSheet "Your HRV Trend" section showing the 7-day mini-chart with baseline overlay.
- **US-4.** As any user, I can disable trend alerts via Settings → Notifications → Trend Alerts toggle (default ON).
- **US-5.** As any user, the trend alert respects the master notification kill-switch + daily-cap from `ReminderPreferencesStore`.

### Trigger algorithm (FROZEN at this PRD)

```
let baseline       = ReadinessEngine.personalBaseline(window: 30d, percentile: 50)  // user median
let oneStdDev      = ReadinessEngine.personalBaseline(window: 30d, stddev: true)
let hrvFloor       = max(baseline - oneStdDev, hardFloor=25)                        // adaptive cutoff
let recentDays     = HealthKitService.hrvDailyReads(window: last3CompletedDays)
let belowFloor     = recentDays.allSatisfy { $0 <= hrvFloor }
let dataQuality    = recentDays.count == 3                                          // require 3 real reads
let outsideWindow  = !alreadyFiredWithinWindow(days: 7)
let userEnabled    = preferences.trendAlertsEnabled && preferences.masterEnabled

if belowFloor && dataQuality && outsideWindow && userEnabled {
    fire(.trendAlert(.hrvSustainedLow, recommendedAction: .restAndHydrate))
    markFired(date: today)
}
```

**Constants frozen at this PRD:**

| Constant | Value | Rationale |
|---|---|---|
| `baselineWindow` | 30 days | Matches ReadinessEngine Layer 1+ baseline window |
| `baselinePercentile` | 50 (median) | Resistant to single-day outliers |
| `sustainedDays` | 3 | Empirically: 2 days = noise; 4 days = too late. 3 captures pattern before crash. |
| `hardFloor` | 25 ms RMSSD | ~10th percentile across general population — cold-start protection |
| `refireWindow` | 7 days | Avoids spam during multi-week dips; re-fires with stronger copy if pattern persists |
| `requiredDataQuality` | 3/3 reads in window | Skip if any day missing HRV read (don't infer) |

**Cold-start handling (Layer 0 users, <14 days history):** use `hardFloor` exclusively (no personal baseline). Notification copy uses cautious language ("HRV has been low recently — consider extra recovery"). Adoption-rate metric tracks Layer ≥2 cohort only.

### Notification dispatch timing

Fires at **08:00 local** (advisory morning slot). Future enhancement (post-launch): learn from app-open time-of-day patterns. For PRD-1, 08:00 is the fixed dispatch time.

### Three surfaces

#### Surface 1 — Home `AIInsightCard` banner

When `TrendAlertStore.current()` is non-nil AND no C2 ReadinessAwareAlertStore.current() is set (C2 takes precedence on training days), the AIInsightCard overrides default content:

- **Headline:** "HRV trend: {N} days below baseline" (N = sustainedDays, frozen at 3)
- **Subtitle:** "Tap to see your 7-day pattern"
- **Avatar mode:** `.pulse` (advisory; matches C2 adaptEasierLoad pattern — no new mode)
- **Tap behavior:** opens AIIntelligenceSheet, scrolls to "Your HRV Trend" section

#### Surface 2 — Push notification

- **Cap tag:** `.standard` (advisory; never pre-empts global cap)
- **De-dupe:** per 7-day rolling window, UserDefaults-backed, day-keyed
- **Title:** "Your HRV trend"
- **Body (Layer ≥2):** "HRV has been below your baseline for 3 days. Consider extra rest + hydration today."
- **Body (Layer 0 cold-start):** "HRV has been low recently. Consider extra recovery."
- **userInfo:** `{ "type": "trendAlert", "kind": "hrvSustainedLow", "deepLink": "fitme://nav/home" }`
- **Sound:** default

#### Surface 3 — AIIntelligenceSheet "Your HRV Trend" section

NEW section added to the existing sheet (between `readinessSection` and `AIFeedbackView`). Renders:

- Section title: "Your HRV Trend"
- 7-day mini-chart (line + dots) showing daily HRV reads
- Horizontal dotted line overlay at `baseline` (median)
- Horizontal solid line overlay at `hrvFloor` (baseline − 1σ or hardFloor=25)
- Per-day annotation: green tick if ≥ baseline, amber if between floor and baseline, red if ≤ floor
- Caption: "Baseline computed from your last 30 days. Adjust at Settings → Notifications → Trend Alerts."
- **Feedback affordance:** thumbs-up / thumbs-down at the bottom of this section → `home_readiness_alert_action_taken` event

The chart reuses existing FitTracker stats-v2 chart primitives (Swift Charts framework) — no new visualization code beyond the section composition.

### Settings opt-out

In Settings → Notifications, add a new toggle row immediately after C2's "Readiness-Aware Advisory":

- **Title:** "Trend Alerts"
- **Detail:** "Heads-up when HRV trends below your baseline for 3+ days."
- **Default:** ON (default-true)
- **Binding:** `$preferences.trendAlertsEnabled` (new `@Published var` in `ReminderPreferencesStore`)
- **Persistence key:** `"ft.reminder.trendAlerts"`

Disable behavior: when off, the observer `evaluate(...)` early-returns nil before any notification content is built (same pattern as C2's `readinessAwareAlertsEnabled`).

---

## Technical Approach

### New source files

- `FitTracker/Services/Reminders/TrendAlertContext.swift` — value type holding kind (`hrvSustainedLow` + future `sleepSustainedLow` + `rhrSustainedHigh` enum) + 7-day HRV samples + baseline + floor + generatedAt.
- `FitTracker/Services/Reminders/TrendAlertTrigger.swift` — pure-function evaluator: `(hrvDailyReads, baseline, floor, alreadyFiredWindow) -> TrendAlertContext?`. Mirrors C2's pure-function pattern.
- `FitTracker/Services/Reminders/TrendAlertObserver.swift` — wires the trigger to `NotificationGateway.dispatch(...)` with cap tag `.standard` + 7-day de-dupe. Registered as a SECOND consumer alongside C2.
- `FitTracker/Services/Reminders/TrendAlertStore.swift` — `@MainActor ObservableObject` mirroring C2's `ReadinessAwareAlertStore`. Holds latest TrendAlertContext for the in-app card.
- `FitTracker/Views/AI/HRVTrendChart.swift` — the 7-day mini-chart View. Reuses Swift Charts primitives + AppTheme tokens.

### Modified source files (preserved scope to avoid C2-style conflict)

- `FitTracker/Views/AI/AIInsightCard.swift` — extend `avatarMode` + title/subtitle to check `trendAlert.current()` AFTER `readinessAware.current()` (C2 takes priority on training days; this fills the gap).
- `FitTracker/Views/AI/AIIntelligenceSheet.swift` — add `Your HRV Trend` section after `readinessSection`.
- `FitTracker/Services/Notifications/ReminderPreferencesStore.swift` — add `trendAlertsEnabled: Bool = true` field + UserDefaults persistence key + init re-hydration. Add to `isEnabled(for:)` if pattern extends (currently only ReminderType, but trend alerts are a separate type identifier).
- `FitTracker/Views/Settings/v2/Screens/NotificationsSettingsScreen.swift` — add new `reminderToggle` row.
- `FitTracker/Services/Analytics/AnalyticsProvider.swift` — add 4 new event/param constants (see Analytics Events section).
- `FitTracker/Services/Analytics/AnalyticsService.swift` — add 4 new `logTrendAlert*` methods.
- `FitTracker/FitTrackerApp.swift` — register `TrendAlertObserver.consumerRegistration` at app-init alongside C2's.

### Algorithm component dependencies (all shipped)

- `ReadinessEngine.personalBaseline(window:percentile:)` — extend to support `stddev: true` (small surface addition; not new infra)
- `HealthKitService.hrvDailyReads(window:)` — already shipped
- `NotificationGateway.dispatch(...)` — already shipped (PR #239)
- `NotificationConsumerRegistry` — already shipped
- `DeepLinkRouter` `fitme://nav/home` — already routable
- `EncryptedDataStore` (`DailyLog.biometrics.hrv` persistence) — already shipped

### Branch isolation discipline

- All work on `feature/trend-alerts-hrv` (Mode C compliant — feature branch + state.json + log)
- No infra-path edits (no `.github/workflows/*`, no `scripts/*`, no `CLAUDE.md`) — Mode B not triggered

---

## Analytics Events

All four events are screen-prefixed `home_` per the 2026-04-08 project convention.

| Event | Trigger | Params |
|---|---|---|
| `home_trend_alert_shown` | Banner renders in AIInsightCard | `kind`, `sustained_days`, `baseline`, `floor` |
| `home_trend_alert_tap` | User taps banner | `kind` |
| `home_trend_alert_action_taken` | User picks thumbs-up / thumbs-down in Why? sheet | `kind`, `rating` |
| `home_trend_alert_dismissed` | User dismisses banner without tap (swipe / next-app-open replacement) | `kind` |

Param naming follows existing convention:

- `kind`: enum string (`hrv_sustained_low` for v1)
- `sustained_days`: int (always 3 for v1, future-proofed for variable windows)
- `baseline`: int (rounded HRV ms)
- `floor`: int (rounded HRV ms)
- `rating`: `positive` | `negative` (matches existing AI feedback param)

---

## Phased Rollout

Single-PR Feature ship (no phased rollout for this scope). Phase 4 (Implement) lands all 5 new files + 7 modified files + tests. Post-merge:

- T+7d: first metrics readout (action-taken rate, FP-rate baseline)
- T+14d: kill-criteria evaluation
- T+30d: cohort metrics review + decide on C4.b (multi-signal fusion) follow-on

---

## Dependencies

All shipped as of 2026-06-01:

| Dependency | Source | Status |
|---|---|---|
| `HealthKitService.hrvDailyReads(window:)` | PR #74 (training-plan-v2) | ✅ shipped 2026-04-10 |
| `ReadinessEngine.personalBaseline(window:percentile:)` | PR before #79 (readiness-engine-v2) | ✅ shipped 2026-04-10 |
| `NotificationGateway.dispatch(...)` | PR #239 (push-notifications-v2) | ✅ shipped 2026-05-07 |
| `NotificationConsumerRegistry` | PR #239 | ✅ shipped 2026-05-07 |
| `DeepLinkRouter` | PR #239 + #556 (registry) | ✅ shipped 2026-05-07 / 2026-05-31 |
| `AIInsightCard` + `AIIntelligenceSheet` | PR #79 + #560 (C2 banner) | ✅ shipped 2026-04-10 + 2026-06-01 |
| `EncryptedDataStore` (DailyBiometrics.hrv) | PR #79 | ✅ shipped 2026-04-10 |
| `ReminderPreferencesStore` | PR #550 (notification settings UI) | ✅ shipped 2026-05-31 |

**Single new internal API surface:** `ReadinessEngine.personalBaseline(window:stddev:)` — small addition to existing function signature. Not a new dependency, a small extension.

---

## GDPR / Privacy

- HRV history is already persisted in `EncryptedDataStore` under existing GDPR consent. No new data collection.
- Notification copy uses on-device HRV values; no server round-trip.
- Settings opt-out is a single boolean. Opting out triggers no data deletion — user retains all prior HRV history; only the alert observer stops firing.
- Cold-start fallback uses a HARDCODED population threshold (`hardFloor=25`), not a population-level data fetch — no privacy-impacting aggregation.

---

## Risks

| Risk | Impact | Mitigation |
|---|---|---|
| **False-positive over-firing** during user travel / sleep disruption | Push fatigue | 7-day re-fire window + opt-out toggle |
| **Layer 0 over-firing** on small HRV-recording samples | Trust erosion | `requiredDataQuality = 3/3 reads` skips users with sparse data |
| **C2 + C4 simultaneous dispatch** on a training day | UX collision | C2 takes precedence in `AIInsightCard.avatarMode`; in-app banner shows C2 only. Push: both can fire (separate cap-tag groups) — accept this; documented in case study. |
| **HRV baseline drift during training cycle** (athletes peaking) | Trigger fires for HEALTHY training peaks | Baseline window = 30 days median captures cycle averages. Accept some FP for power users in peak block; opt-out for affected users. |
| **`ReadinessEngine.personalBaseline(... stddev:)` extension** introduces math edge case | Math bug | Test coverage: 10 tests on the extension alone (degenerate cases: 0 reads, 1 read, identical reads, large variance) |

---

## Open Questions

| # | Question | Decision criterion |
|---|---|---|
| OQ-1 | Should the 7-day mini-chart show RHR + Sleep overlays (composite trend)? | DEFERRED to C4.b follow-on. v1 ships HRV-only for scope clarity. |
| OQ-2 | Should the trend alert dispatch time be learnable (08:00 default → user-pattern)? | DEFERRED to C4.c follow-on. v1 ships fixed 08:00 local. |
| OQ-3 | Should C4 surface in the upcoming HADF Phase 2-bis launch dashboard? | NO. HADF is orthogonal infra-level work; C4 is product-feature work. No surface overlap. |
| OQ-4 | What if the user has BOTH C2 (readiness-aware) AND C4 (trend) firing on the same morning? | C2 takes precedence in `AIInsightCard` (single banner slot, training-day context wins). Push fires both via separate cap-tag groups. Documented in case study. |
| OQ-5 | Should the Settings toggle default to OFF (opt-in) for risk mitigation? | NO. Default ON matches C2 and C1 patterns. Opt-out remains one-tap if needed. |

OQ-1 / OQ-2 / OQ-3 explicitly out of scope per PRD. OQ-4 / OQ-5 frozen as documented decisions.

---

## Enhancements (future C4.b/c/d/e — out of scope this PRD)

- **C4.b** — Multi-signal trend alerts (HRV ∩ RHR ∩ Sleep composite). Requires UX research on how to explain composite scoring to the user.
- **C4.c** — Predictive trend overlay ("you'll bottom out tomorrow at 28 ms"). T1/T3 confidence — too low for v1 surface.
- **C4.d** — Opt-in early-warning mode (lower threshold + higher cadence). Power-user toggle.
- **C4.e** — Cohort-aware baseline (compare against demographics-matched population, not just personal history). Privacy-impacting aggregation; needs separate GDPR review.

---

## Phase transition criteria

| From → To | Criterion |
|---|---|
| research → prd | Operator approves the PRD (this document) freezing algorithm constants, analytics events, Settings copy, surface specs |
| prd → tasks | Tasks.md authored breaking the implementation into discrete units (estimate: 14 tasks) |
| tasks → implement | All tasks defined + operator approval |
| implement → test | All tasks complete; swiftc -parse exit 0; new files + modified files compile; CI ci.yml green |
| test → review | New tests pass (target: 18 tests across 4 test files); coverage ≥ 90% on new files |
| review → merge | `/ux pre-merge-review` + `/design pre-merge-review` both pass; case study + showcase MDX authored |
| merge → complete | PR merged; backlog L346 row struck through; FEATURE_CLOSURE_COMPLETENESS gate passes; Tier 2.2 log captures merge event |

---

## Cross-references

- Phase 0 research: [`.claude/features/trend-alerts-hrv/research.md`](../../.claude/features/trend-alerts-hrv/research.md) (10-section)
- State file: [`.claude/features/trend-alerts-hrv/state.json`](../../.claude/features/trend-alerts-hrv/state.json)
- Tier 2.2 log: [`.claude/logs/trend-alerts-hrv.log.json`](../../.claude/logs/trend-alerts-hrv.log.json)
- E1 RICE refresh: PR #559 (merged 2026-05-31)
- C2 case study (sibling observer): [`docs/case-studies/readiness-aware-training-alert-case-study.md`](../../case-studies/readiness-aware-training-alert-case-study.md)
- Push notifications v2: [`docs/product/prd/push-notifications.md`](push-notifications.md)
- Smart reminders parent: [`docs/product/prd/smart-reminders.md`](smart-reminders.md)
- Tier carryover plan: `~/.claude/projects/-Volumes-DevSSD-FitTracker2/memory/project_session_2026_05_31_tier_carryover_plan.md`
