---
title: "Adaptive Intelligence Next-Pass — On-Device Decay + Trend + Transparency UX on Top of C5 (D1)"
date: 2026-06-02
date_written: 2026-06-02
work_type: feature
dispatch_pattern: serial
framework_version: v7.9
primary_metric: "Trend-unsuppression precision >= 0.70 at T+30d (T1, baseline N/A — feature new)"
success_metrics:
  - "Trend-unsuppression precision: fraction of trend-unsuppress events whose next 3 outcomes for the same signal+segment are >=2 acceptances (T1, target >=0.70 at T+30d)"
  - "Manual-unsuppression survival: % of manual un-suppressions still active at the 14d expiry without being re-dismissed (T1, target >=0.50 at T+30d)"
  - "Detail-screen open rate per suppressed signal shown: % of suppressed-row taps that open the detail screen (T1, target >=0.10 at T+30d)"
  - "Blacklist precision: fraction of blacklisted signals where post-blacklist segment acceptance rate STAYS >=0.50 (T1, target >=0.60 at T+30d — proves user judgment was correct)"
  - "Reinforcement-loop satisfaction proxy: AI Feedback Settings → Clear-feedback-history rate drops vs C5 baseline (T2 — directional, no instrumented baseline yet)"
  - "Zero regression on C5 suppression rate (T1, |delta| <= 5% at T+14d)"
kill_criteria:
  - "Trend-unsuppression precision < 0.40 at T+30d (model worse than coin-flip → ship rollback)"
  - "Detail-screen open rate < 0.02 per suppressed-row tap (UX unused / undiscoverable)"
  - "Manual-unsuppression re-dismissal within 7d > 0.50 (users rejecting their own override → UX confusion)"
  - "p95 trend-detector compute > 5ms on iPhone 17 sim per orchestrator call (degrades AI pipeline)"
  - "Any user-reported privacy / data-leakage report citing the new ledgers (D1 is 100% on-device; one report = ship rollback)"
kill_criteria_resolution: pending_t14_eval_2026-06-16
tier_tags_present: true
related_prs:
  - 576
case_study_type: full
---

# Adaptive Intelligence Next-Pass — D1

## Why

C5 (ai-user-feedback-loop, shipped 2026-06-01 PR #572) gave the AI orchestrator
a single new lever: when a signal had been dismissed 3+ times in the last 30
days, every recommendation containing that signal was confidence-downgraded by
one tier. Effective at the bluntest end of "stop showing me this." Useless at
the nuance level:

1. The signal never recovers — even if the user starts accepting again, the
   30d dismissal window keeps it suppressed.
2. The user can't see *why* a signal was suppressed.
3. The user can't override the suppression except by clearing all feedback
   (nuclear).
4. The user can't make a suppression permanent without continuing to dismiss
   recommendations every couple of weeks.

D1 closes those four gaps with **two on-device sub-features** (D1.a + D1.d).
Three other candidate sub-features (D1.b cohort federation, D1.c LLM-suggested
replacement, D1.e cross-segment trend correlation) stay queued for v8.0+
because they require backend or LLM infra that doesn't exist yet.

## What shipped

**D1.a — On-device decay + 7d trend criterion**

`AcceptanceTrendDetector` (new pure helper) centralizes four PRD-frozen
constants:

```
timeDecayLambda                  = 0.0231   // day⁻¹ (half-life 30d)
trendDetectionWindowSeconds      = 7 * 86400
trendUnsuppressionAcceptanceFloor = 0.50
trendMinOutcomes                 = 3
```

The orchestrator's `applyReinforcementLoop` now partitions each touched
(suppressed) signal into four buckets:

| Bucket               | Behavior                                              |
|----------------------|-------------------------------------------------------|
| blacklisted          | Always downgrade. Revoked only by `clearAll()`.       |
| manuallyUnsuppressed | Skip downgrade. Persists 14d, then expires.           |
| trendUnsuppressed    | Skip downgrade + fire `unsuppressed_by_trend` event + auto-record a 14d manual un-suppression with `viaTrend: true`. |
| stillSuppressible    | Existing C5 downgrade path. Unchanged.                |

Downgrade fires only when `blacklisted ∪ stillSuppressible` is non-empty.

**D1.d — Transparency UX**

Settings → AI Feedback → "Currently Suppressed" rows are now
`NavigationLink`s into `SuppressedSignalDetailScreen`. The screen shows:

- **Why suppressed** — lifetime dismissal count + 5 most-recent timestamps
- **Auto-recovery** — whether the 7d/50% trend criterion currently fires;
  if not, "last dismissal was N days ago — accept 3+ in 7 days to enable
  auto-recovery"
- **Controls** — "Un-suppress for 14 days" (manual override, stays active
  through any new dismissals) and "Blacklist permanently" (no auto-recovery
  ever; revoked only by Clear-history)

## How (architecture deltas)

Five files modified + 2 new + 4 new test files:

```
+ FitTracker/AI/AcceptanceTrendDetector.swift                                (new, 117 LoC)
~ FitTracker/AI/RecommendationMemory.swift                                   (+170 LoC; ManualUnsuppression + BlacklistedSignal + 4 query + 2 mutation + persistence)
~ FitTracker/AI/RecommendationFeedbackController.swift                       (+45 LoC; 7 passthroughs)
~ FitTracker/AI/AIOrchestrator.swift                                         (+48 LoC; partition logic)
~ FitTracker/Services/Analytics/AnalyticsProvider.swift                      (+10 LoC; 4 events + 3 params)
~ FitTracker/Services/Analytics/AnalyticsService.swift                       (+62 LoC; 4 log methods)
+ FitTracker/Views/Settings/v2/Screens/SuppressedSignalDetailScreen.swift    (new, 195 LoC)
~ FitTracker/Views/Settings/v2/Screens/AIFeedbackSettingsScreen.swift        (NavigationLink wrap; SuppressedItem.segmentValue)
~ FitTracker.xcodeproj/project.pbxproj                                        (6 entries × 4 = 24 lines)

+ FitTrackerTests/AnalyticsAdaptiveIntelligenceEventsTests.swift             (2 tests)
+ FitTrackerTests/RecommendationMemoryD1FieldsTests.swift                    (6 tests)
+ FitTrackerTests/AcceptanceTrendDetectorTests.swift                         (8 tests)
+ FitTrackerTests/AIOrchestratorTrendUnsuppressTests.swift                   (5 tests)
```

Storage uses separate UserDefaults keys for the two new arrays, so existing
C5 stores load without migration. `clearAll()` wipes all three keys.

Analytics events stay screen-prefixed per project convention:

```
home_ai_feedback_signal_unsuppressed_by_trend
home_ai_feedback_suppressed_detail_opened
home_ai_feedback_signal_manually_unsuppressed
home_ai_feedback_signal_blacklisted_permanently
```

## How (operational deltas — what to watch)

- **Trend-unsuppression precision** — primary metric. T+30d eval at
  2026-07-02. If <0.40, ship rollback by single-line edit to
  `AcceptanceTrendDetector.shouldUnsuppressByTrend` returning `false`.
- **Manual-unsuppression survival** — proxy for whether 14d is the right
  window. If <0.50 we shorten to 7d.
- **Detail-screen open rate per suppressed row tap** — adoption metric for
  D1.d. If <0.02, the row is undiscoverable and we add a chevron / hint.

## Dispatch pattern

Serial. Single-session full Phase 4 ship (6 commits T1-T9; ~3.5h wall time
matching the C3/C5/C6 cadence baseline). No worktree needed — feature
branch only, no infra-glob hits.

## What did NOT ship

- **D1.b cohort federation** — requires backend k>=20 cohort aggregation
  endpoint. Deferred to v8.0+.
- **D1.c LLM-suggested replacement** — requires LLM gateway + pre-computed
  mapping infra. Deferred to v8.0+.
- **D1.e cross-segment trend correlation** — low-priority; can ride on D1.a's
  decay machinery later.

## Tests

21/21 PASS on iPhone 17 sim (iOS 26.5):

- `AnalyticsAdaptiveIntelligenceEventsTests`         2 PASS
- `RecommendationMemoryD1FieldsTests`                6 PASS
- `AcceptanceTrendDetectorTests`                     8 PASS
- `AIOrchestratorTrendUnsuppressTests`               5 PASS

Total D1 test wall time: 0.91s.

## PR

- [PR #576](https://github.com/Regevba/FitTracker2/pull/576) —
  feat(adaptive-intelligence-next-pass): D1 — on-device adaptive layer
  + transparency UX (T1-T9)

## Cross-references

- C5 — [`ai-user-feedback-loop-case-study.md`](ai-user-feedback-loop-case-study.md)
  (predecessor; provides RecommendationMemory + AIOrchestrator reinforcement-loop
  shape that D1 extends).
- PRD — [`docs/product/prd/adaptive-intelligence-next-pass.md`](../product/prd/adaptive-intelligence-next-pass.md)
- Tasks — [`.claude/features/adaptive-intelligence-next-pass/tasks.md`](../../.claude/features/adaptive-intelligence-next-pass/tasks.md)
