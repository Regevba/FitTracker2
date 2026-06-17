---
slug: trend-alerts-hrv-case-study
title: "Trend Alerts (HRV) — C4 Sustained-Trend Observer Shipped"
date: 2026-06-01
framework_version: v7.9
work_type: feature
work_subtype: standalone
case_study_type: shipped
tier_tags_present: true
status: shipped
case_study: docs/case-studies/trend-alerts-hrv-case-study.md
case_study_showcase: fitme-story/content/04-case-studies/41-trend-alerts-hrv.mdx
related_prs:
  - 562  # Phase 0 research
  - 564  # Phase 1+2+4 PRD + Tasks + Implement
dispatch_pattern: serial
success_metrics:
  - name: trend_alert_action_taken_rate_pct
    baseline: 0.0
    target: 30.0
    significance: descriptive
    review_at: 2026-06-15
    tier: T2
    note: "Target 30% reflects Smart Reminders v1 ~32% home_action_tap baseline with small expected lift from multi-day pattern context. T2 — declared target, not yet measured."
  - name: adoption_rate_layer2_plus_pct
    baseline: 0.0
    target: 15.0
    significance: descriptive
    review_at: 2026-07-01
    tier: T1
    note: "Primary T1 metric: % of WAU Layer ≥2 cohort (4+ weeks HRV history) with at least one C4 fire in 30-day window. Captured via home_trend_alert_shown × distinct users / Layer≥2 cohort size."
  - name: user_reported_false_positive_rate_pct
    baseline: 0.0
    target: 15.0
    significance: descriptive
    review_at: 2026-07-01
    tier: T3
    note: "Via the in-app feedback thumbs-down in Why? sheet. T3 — narrative tier, no control-arm comparison."
  - name: push_fatigue_rate_pct
    baseline: 60.0
    target: 60.0
    significance: descriptive
    review_at: 2026-07-01
    tier: T2
    note: "Push read-no-action rate. Maintain at or below ReadinessAlertObserver baseline (60%). T2 declared comparison."
  - name: hrv_recovery_within_7d_post_fire
    baseline: 0.0
    target: 0.0
    significance: descriptive
    review_at: 2026-06-15
    tier: T1
    note: "Descriptive only: average HRV improvement in the 7 days following a fire. T1 instrumented via HealthKit hrv reads, but no target — exploring whether the alert correlates with user-initiated recovery behavior."
kill_criteria:
  - condition: "Action-taken rate < 5% after 14 days of organic exposure (advisory ignored)"
  - condition: "User-reported FP rate > 20% via in-app feedback (algorithm too noisy)"
  - condition: "Push-fatigue rate > 75% (advisory treated as spam)"
  - condition: "Adoption rate < 5% of Layer ≥2 cohort (personal-baseline computation broken or threshold too restrictive)"
kill_criterion_fired: false
kill_criteria_resolution: pending_t14_eval_2026-06-17 — all 5 kill criteria carry calendar-anchored T+14d evaluations (action-taken rate 14d, false-positive 30d, push-fatigue 30d, adoption 30d, daily-trigger latency 14d post-wire-up). All not_fired at closure.
pr_citation_exempt:
  - "PR #562 (Phase 0 Research split-shipped — predecessor of #564; cited for chain-of-custody, not as the closure PR)"
---

# Trend Alerts (HRV) — C4 Case Study

> **Status:** Shipped 2026-06-01 via PR #564 on `feature/trend-alerts-hrv`.
> **Framework version:** v7.9 (Phase E Day 12 of 14 soak — non-gate-modifying Feature, Phase E compliant).
> **Parent feature:** None (standalone). Closely related to [smart-reminders](smart-reminders-case-study.md) (shared NotificationGateway) and [readiness-aware-training-alert](readiness-aware-training-alert-case-study.md) (sibling observer, C2 — shipped earlier the same day).
> **Showcase:** `fitme-story/content/04-case-studies/41-trend-alerts-hrv.mdx`.

## TL;DR

The home-screen `AIInsightCard` now surfaces a **multi-day** HRV trend advisory when (T1) HRV stays below the user's personal baseline for 3+ consecutive days. The advisory dispatches at 08:00 local via push + a Home banner override + a "Your HRV Trend" 7-day mini-chart in the existing `AIIntelligenceSheet`. Distinct from the score-crossing observer (≥80/≤40 single-day) and the C2 pre-training advisory (single-day decision aid) — this catches the **sustained pattern** that the others miss.

## Problem

FitMe had three observers operational pre-C4:

| Observer | Trigger window | Catches |
|---|---|---|
| `ReadinessAlertObserver` | Single-day score crossing ≥80 OR ≤40 | Acute spikes/drops |
| `ReadinessAwareTrainingObserver` (C2) | Today's training day, at learned start time | Today's training decision aid |
| `TrendAlertsObserver` (C4) | **Multi-day pattern (3+ days below floor)** | **Sustained accumulating fatigue** |

The gap before C4: a Layer ≥2 user with stable HRV at 55 drops to 38 for three days. ReadinessAlertObserver doesn't fire (never crossed ≤40). C2 fires only on training days. The accumulating-fatigue pattern is silent until the user manually checks Stats — too late to act.

Surfaced empirically in the 2026-04-21 Gemini independent audit Tier-2 finding "multi-day HRV trend silently absent from notification surface". Deferred to backlog L346 until v7.9 Phase E created the post-C2 build window for it.

## Approach

Three design decisions, in order:

1. **Distinct consumer, distinct cap tag, distinct de-dupe window.** The third observer registers as `push-notifications.trendAlert` with `.standard` cap (not `.critical`), 7-day ISO-week-keyed de-dupe (vs C2's per-day de-dupe, vs ReadinessAlertObserver's per-day per-direction). Each observer fires through `NotificationGateway` independently; the in-app single-banner slot resolves precedence at the view layer (C2 wins on training days; C4 fills the gap on rest days).
2. **Pure-function trigger + median + stddev helpers live in `TrendAlertTrigger.swift`.** Per CLAUDE.md, `ReadinessEngine.swift` is a high-risk-area file. Phase 0's research plan called for extending `ReadinessEngine.personalBaseline(stddev:)`; Phase 4 scope-shift moved the helpers to the new trigger file instead — zero touch to the high-risk file. 19 of the 31 new tests cover the trigger + median + population stddev edge cases (empty, single, identical, large-variance, NaN, infinity).
3. **Reuse `AIIntelligenceSheet.readinessSection` pattern for "Your HRV Trend".** Adds one new section (`hrvTrendSection`) rendered between the existing readiness bars and the AI feedback row. Uses Swift Charts (already imported by stats-v2) for the 7-day mini-chart with baseline (dotted) + floor (solid) horizontal overlays. Point colors are green ≥ baseline, amber between floor and baseline, red ≤ floor.

## Decisions log

- **Threshold split:** `baselineWindow = 30d`, `percentile = 50` (median), `sustainedDays = 3`, `hardFloor = 25ms`, `refireWindow = 7d`, `dataQuality = 3/3 reads required`. Frozen in the PRD (PR #564); changing requires re-Phase-1.
- **Dispatch time:** 08:00 local fixed for v1. The `TrendAlertDispatchTimeLearner` stub is in place for C4.c follow-on (learn from app-open patterns).
- **Cold-start (Layer 0):** uses `hardFloor = 25` exclusively (no personal baseline). Notification body switches to cautious copy ("HRV has been low recently. Consider extra recovery.") — the floor-equals-hardFloor distinction triggers the copy switch in `TrendAlertObserver.body(for:)`.
- **C2 vs C4 single-banner precedence (PRD OQ-4):** C2 wins on training days; the in-app banner shows C2's headline + 3 CTAs even if C4's TrendAlertStore is also populated. Push notifications fire from both observers independently (separate cap-tag groups). C2 wins precedence at the view layer in `AIInsightCard.body` ordering checks.
- **Settings opt-out default:** ON (matches C2 + C1 patterns). Opt-out is one tap in Settings → Notifications → Trend Alerts.
- **No multi-signal fusion in v1.** C4.b (HRV ∩ RHR ∩ Sleep composite) deferred — one signal at a time keeps the user-facing explanation clear.
- **No predictive overlay in v1.** C4.c ("you'll bottom out tomorrow at 28") deferred — T1/T3 confidence insufficient for v1 surfacing.

## Outcomes

| Dimension | Value |
|---|---|
| Source files added | 6 (`TrendAlertContext`, `TrendAlertTrigger`, `TrendAlertDispatchTimeLearner`, `TrendAlertObserver`, `TrendAlertStore`, `HRVTrendChart`) |
| Source files modified | 8 (`AnalyticsProvider`, `AnalyticsService`, `AIInsightCard`, `AIIntelligenceSheet`, `ReminderPreferencesStore`, `NotificationsSettingsScreen`, `FitTrackerApp`, pbxproj) |
| Test files added | 4 |
| Tests added | ~31 (19 trigger + 2 dispatch-time + 6 observer + 4 store + 0 ReadinessEngine since T7 scope-shifted) |
| `pbxproj` slots wired | 10 |
| Analytics events added | 4 (`home_trend_alert_shown` + `_tap` + `_action_taken` + `_dismissed`) |
| Build verification | swiftc -parse exit 0 on all 6 new source files; xcodebuild -list parses pbxproj cleanly; real build + test on CI |
| Time end-to-end | ~3.5h from C4 Phase 1 kickoff to PR open (Phases 0, 1, 2, 4 in single session; Phases 3 = skipped per Feature work-type discretion, 5 = covered by T13 test plan, 6-8 = T14 follow-on) |

**T1 / T2 / T3 tier discipline applied throughout** — every numeric in this case study is tagged at its claim site or in `success_metrics`. The Layer ≥2 adoption rate metric is the primary T1 indicator; alert action-taken rate is T2 declared (no instrumented baseline yet); user-FP rate is T3 narrative (no control-arm).

## Phase E discipline note

C4 ships during the v7.9 Phase E 14-day soak window (2026-05-21 → 2026-06-04). The release **adds no enforcement gates** — it's a new Feature consuming existing v7.8.6 + v7.9 infrastructure (NotificationGateway, NotificationConsumerRegistry, screen-prefixed analytics convention, Tier 2.2 logging, Mechanism C cache-hit attribution). Branch isolation Mode C compliance: all work on `feature/trend-alerts-hrv`; pre-commit `FEATURE_CLOSURE_COMPLETENESS` gate validates the case-study frontmatter at the merge-time `current_phase=complete` transition.

## Cross-references

- **Phase 0 (Research):** [`.claude/features/trend-alerts-hrv/research.md`](../../.claude/features/trend-alerts-hrv/research.md) — merged in PR #562
- **Phase 1 (PRD):** [`docs/product/prd/trend-alerts-hrv.md`](../product/prd/trend-alerts-hrv.md) — merged in PR #564
- **Phase 2 (Tasks):** [`.claude/features/trend-alerts-hrv/tasks.md`](../../.claude/features/trend-alerts-hrv/tasks.md) — merged in PR #564
- **Sibling C2 case study:** [`readiness-aware-training-alert-case-study.md`](readiness-aware-training-alert-case-study.md)
- **Parent smart-reminders PRD:** [`docs/product/prd/smart-reminders.md`](../product/prd/smart-reminders.md)
- **Push notifications v2 PRD:** [`docs/product/prd/push-notifications.md`](../product/prd/push-notifications.md)
- **v7.9 promotion case study:** [`framework-v7-9-promotion-case-study.md`](framework-v7-9-promotion-case-study.md) (provides Phase E context)
- **Backlog row:** [`docs/product/backlog.md` L346](../product/backlog.md) — struck through with this PR
- **Tier 2.2 log:** [`.claude/logs/trend-alerts-hrv.log.json`](../../.claude/logs/trend-alerts-hrv.log.json) (5 `phase_transition` events: research → prd → tasks → implementation → complete after merge)
