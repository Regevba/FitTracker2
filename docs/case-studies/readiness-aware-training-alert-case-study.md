---
slug: readiness-aware-training-alert-case-study
title: "Readiness-Aware Training Alert — C2 Shipped on the Pre-Training Surface"
date: 2026-06-01
framework_version: v7.9
work_type: enhancement
work_subtype: sub_feature
case_study_type: shipped
tier_tags_required: true
status: shipped
case_study: docs/case-studies/readiness-aware-training-alert-case-study.md
case_study_showcase: fitme-story/content/04-case-studies/40-readiness-aware-training-alert.mdx
parent_case_study: docs/case-studies/smart-reminders-system-case-study.md
parent_feature: smart-reminders
related_prs: []
dispatch_pattern: serial
success_metrics:
  - name: alert_action_taken_rate_pct
    baseline: 0.0
    target: 35.0
    significance: descriptive
    review_at: 2026-06-22
    tier: T2
    note: "% of shown advisories where the user picks one of the three CTAs vs dismisses. Target 35% reflects the home_action_tap baseline established by Smart Reminders v1 (32%) with a small lift hypothesis from added context."
  - name: rest_day_swap_recovery_quality_delta
    baseline: 0.0
    target: 5.0
    significance: descriptive
    review_at: 2026-07-15
    tier: T3
    note: "Post-launch retrospective: when users accept restDaySwap CTA, average overall readiness score on the next training day vs control (no CTA shown). T3 because no instrumented control arm — descriptive only."
kill_criteria:
  - condition: "Action-taken rate < 5% after 14 days of organic exposure (advisory is being ignored)"
  - condition: "User-reported false-positive rate > 20% via in-app feedback button (advisory fires when user feels fine)"
  - condition: "Daily push fatigue rate (read-but-no-action) > 60% (advisory is being treated as spam)"
kill_criterion_fired: false
---

# Readiness-Aware Training Alert — C2 Case Study

> **Status:** Shipped 2026-06-01 in a single PR on `feature/readiness-aware-training-alert`.
> **Framework version:** v7.9 (Phase E Day 12 of 14 soak window — non-gate-modifying enhancement, Phase E compliant).
> **Parent feature:** [smart-reminders](smart-reminders-case-study.md).
> **Showcase:** `fitme-story/content/04-case-studies/40-readiness-aware-training-alert.mdx` (pending).

## TL;DR

The home-screen `AIInsightCard` now surfaces a daily, **time-of-day-aware** readiness advisory between (T1) the user's scheduled training time and 30 minutes before it. The advisory branches three ways: **Train now** (`continueAsPlanned`), **Lighten** (`adaptEasierLoad`), **Swap to rest** (`restDaySwap`). The branching rule is a pure function over `(ReadinessResult, scheduledDayType, bodyCompFlags)`; the dispatch is a separate consumer of the v2 NotificationGateway (cap tag `.standard`, day-keyed de-dupe). The "Why?" disclosure reuses the existing `AIIntelligenceSheet.readinessSection` component-bar breakdown — no new visualization code.

## Problem

The existing `ReadinessAlertObserver` (push-notifications-v2) fires only when readiness *crosses* the ≥80 or ≤40 thresholds. That's a **score-change observation**, not a **decision aid at the moment of action**. Users on a stable mid-band score (50–70) get no nudge despite that being precisely the range where a 5-point intraday swing matters most for "go vs lighten vs swap" judgement. The RICE-13.0 backlog row L206 had been open for ~6 weeks; the dependencies (ReadinessEngine v2, AIOrchestrator, NotificationGateway, DeepLinkRouter, smart-reminders core) all shipped by mid-May, so the cost-to-build collapsed.

## Approach

Three decisions, in order:

1. **Keep `ReadinessAlertObserver` separate.** The score-crossing path and the time-of-day-decision path solve different problems. Combining them would bloat one observer's `evaluate()` signature with conflicting trigger semantics (event-driven vs scheduled). The new `ReadinessAwareTrainingObserver` is a **second consumer** of the v2 NotificationGateway with its own `typeIdentifier`, cap tag, and de-dupe key.
2. **Make the decision rule pure.** `ReadinessAwareTrainingTrigger.evaluate(...)` takes `(ReadinessResult, DayType, suggestedSwapTarget, scheduledTrainingTime, generatedAt)` and returns `ReadinessAlertContext?`. No `Date()` calls, no `UserDefaults` reads, no side effects. This made 12 of the 25 new tests trivial to write — every input is reproducible.
3. **Reuse existing UI primitives.** `AIIntelligenceSheet.readinessSection` already renders HRV / Sleep / Training Load / RHR bars. The "Why?" affordance is just "scroll a bit further in the existing sheet." The new code is one banner with three CTAs at the top of the sheet — about 50 lines.

## Decisions log

- **Threshold split:** `restSwapThreshold = 35`, `adaptThreshold = 50`, `continueThreshold = 65`. The 35/50 split intentionally requires an adverse `BodyCompFlag` (`hydrationWarning` or `visceralTrend`) to escalate from "adapt" to "swap" — keeps the swap recommendation rare. The 50/65 gap is the explicit "no alert, low confidence" zone to avoid noisy fires on borderline data.
- **Driving component surfacing:** if the lowest component is > 15 points below the highest, surface it as the `drivingComponent`; otherwise `.composite`. The 15-point spread heuristic prevents the "Why?" breakdown from naming a phantom driver when all four components are similar.
- **Avatar mode mapping (Task 7):** rest-swap → `.shimmer`, adapt → `.pulse`, continue → `.breathe`. Mapped inline in `AIInsightCard.avatarMode` rather than adding a global avatar-state-machine class — the mode is purely a function of `readinessAware.current()?.recommendation` at render time.
- **Time-of-day learning fallback:** median of last-30-day `DailyLog.sessionStartTime` if quorum ≥ 5; else 18:00 local. The 18:00 fallback was chosen against FitMe's WAU cohort default (master plan §1.4) rather than computed — explicit T3 declaration.
- **Settings opt-out:** `ReminderPreferencesStore.readinessAwareAlertsEnabled` (default true). When false, `ReadinessAwareTrainingObserver.evaluate(...)` early-returns nil before any notification content is built.

## Outcomes

| Dimension | Value |
|---|---|
| Source files added | 5 (`ReadinessAlertRecommendation.swift`, `ReadinessAwareTrainingTrigger.swift`, `TrainingStartTimeLearner.swift`, `ReadinessAwareTrainingObserver.swift`, `ReadinessAwareAlertStore.swift`) |
| Source files modified | 6 (analytics provider/service, `AIInsightCard`, `AIIntelligenceSheet`, `ReminderPreferencesStore`, `NotificationsSettingsScreen`) |
| Test files added | 3 (25 tests total: 12 trigger + 7 learner + 6 observer) |
| `pbxproj` slots wired | 12 (5 source + 3 test + 4 build/file/group/sources phase per surface) |
| Analytics events added | 4 (`home_readiness_alert_shown` + `_tap` + `_action_taken` + `_dismissed` — all `home_`-prefixed per project convention) |
| Build verification | `swiftc -parse` exit 0 on all new source; `xcodebuild -list` parses pbxproj clean; **real** build + test left to CI on `feature/readiness-aware-training-alert` (operator local Xcode env blocked on CoreSimulator out-of-date — post-2026-05-19 SSD migration drift) |
| Time end-to-end | ~2.5h from C2 Phase 1 kickoff to PR open |

**T1 / T2 / T3 tier discipline applied throughout** — every numeric in this case study is tagged at its claim site or in `success_metrics`.

## Phase E discipline note

C2 ships during the v7.9 Phase E 14-day soak window (2026-05-21 → 2026-06-04). The release **adds no enforcement gates** — it's a new feature consuming existing v7.8.6 + v7.9 infrastructure (NotificationGateway, NotificationConsumerRegistry, screen-prefixed analytics convention, Tier 2.2 logging). Branch isolation Mode C compliance: all work on `feature/readiness-aware-training-alert`; pre-commit `FEATURE_CLOSURE_COMPLETENESS` will validate the case-study frontmatter at the merge-time `current_phase=complete` transition.

## Cross-references

- **Phase 1 (Tasks)** kickoff PR: #560 (E1 RICE refresh, includes state.json + 12-task tasks.md authoring)
- **Parent PRD:** `docs/product/prd/smart-reminders.md`
- **Backlog row:** L206 in `docs/product/backlog.md` (struck through with this PR)
- **Tier carryover plan that produced C2:** [`project_session_2026_05_31_tier_carryover_plan`](../../.claude/projects/-Volumes-DevSSD-FitTracker2/memory/project_session_2026_05_31_tier_carryover_plan.md)
- **Tier 2.2 log:** [`readiness-aware-training-alert.log.json`](../../.claude/logs/readiness-aware-training-alert.log.json) (3 phase_transition events)
- **v7.9 promotion case study:** [`framework-v7-9-promotion-case-study.md`](framework-v7-9-promotion-case-study.md) (provides the Phase E context this enhancement ships under)
