---
title: "AI User Feedback Loop — closing UI-024 with a reinforcement cycle"
date: 2026-06-01
date_written: 2026-06-01
work_type: feature
dispatch_pattern: serial
framework_version: v7.9
primary_metric: "home_ai_feedback_submitted events per WAU ≥ 0.10 at T+30d (T1)"
success_metrics:
  - "home_ai_feedback_submitted events per WAU (T1, baseline 0.03 → target ≥0.10 at T+30d)"
  - "acceptance rate ≥0.6 in ≥2 segments (T1, baseline nil → target met at T+30d)"
  - "recommendation fatigue rate declining trend (T2, declining over 14d window)"
  - "Settings → AI Feedback opt-out rate ≤20% (T2, kill criterion guard)"
  - "suppression accuracy operator-observation (T3, ≥1 positive observation)"
kill_criteria:
  - "Acceptance rate at T+14d < pre-C5 baseline"
  - "home_ai_feedback_submitted event volume declines"
  - "Settings → AI Feedback opt-out rate > 20%"
  - "User-reported wrong-suppression via dismiss-reason `disagree` count > 20% of total dismissals"
kill_criteria_resolution: pending_t14_eval_2026-06-15
tier_tags_present: true
related_prs:
  - 572
case_study_type: full
---

# AI User Feedback Loop — closing UI-024 with a reinforcement cycle

## Tier tags (T1 / T2 / T3)

This case study uses the project-wide tier convention from `docs/case-studies/data-quality-tiers.md`. Every quantitative metric below carries a T1 (Instrumented), T2 (Declared), or T3 (Narrative) label.

## Summary

C5 closes deferred audit UI-024 by wiring the existing `RecommendationMemory` storage layer (PR #79, 2026-04-10) into the existing `AIInsightCard.recordFeedback` UI tap (PR #79) via a new env-object facade, and adds a reinforcement-loop block in `AIOrchestrator` that suppresses signals with ≥3 dismissals in the last 30 days and boosts segments with acceptance rate > 0.70 (5-outcome quorum).

**Lifecycle:** Research → PRD → Tasks → Implement → Test (5 phases shipped in ~3h on 2026-06-01). Currently in `testing` awaiting operator merge approval on PR #572.

## Problem framing

| Tier | Claim |
|---|---|
| T1 | `AIInsightCard.recordFeedback` fired 47 `home_ai_feedback_submitted` events during the 2026-05-31 → 2026-06-01 GA4 window but `RecommendationMemory.totalCount` on every user's device stayed at 0. The reinforcement-loop infrastructure existed but was inert. |
| T3 | The home screen kept surfacing the same recommendation patterns regardless of user response — `"Your sleep quality could use a boost"` could appear on day 50 even though the user dismissed it 49 times. No mechanical learning. |

The deferred-comment block had carried since PR #79 (2026-04-10):

```swift
// Note (audit UI-024): Local RecommendationMemory recording deferred —
// RecommendationMemory is owned per-AIOrchestrator instance, not a
// shared singleton. Wiring requires either an EnvironmentObject pattern
// or a dedicated DI container.
```

## What C5 shipped

### Three closures

- **Closure A — UI-024 wire.** `RecommendationMemory` promoted from per-`AIOrchestrator`-instance to an app-lifecycle `@StateObject` env-object via new `RecommendationFeedbackController` facade. `AIInsightCard.recordFeedback` now calls `feedbackController.record(outcome:)` directly. Deferred comment removed.
- **Closure B — Reinforcement loop in `AIOrchestrator`.** New `applyReinforcementLoop(recommendation:segment:)` block runs in `process()` between `finalRecommendation` set and the publish to `latestRecommendations[segment]`. Per-signal-per-segment confidence-tier-only adjustment.
- **Closure C — Settings → AI Feedback row.** New `AIFeedbackSettingsScreen` (4 sections: total + per-segment + suppressed + controls). Opt-out toggle default ON. Clear-all + dismiss-reason picker (5-enum + 80-char on-device free-text).

### Frozen algorithm constants (PRD §"FROZEN constants")

| Constant | Value |
|---|---|
| `acceptanceUpgradeThreshold` | 0.70 |
| `dismissalSuppressionThreshold` | 3 dismissals / 30-day window |
| `quorumCount` | 5 outcomes per segment |
| `adjustmentMode` | `confidenceTierOnly` (no signal synthesis) |
| `dismissReasonOptions` | notRelevant / alreadyAware / disagree / repetitive / other |
| `outcomeRetentionPerSegment` | 200 LRU |

### 3 new analytics events (screen-prefixed `home_`)

| Event | Trigger |
|---|---|
| `home_ai_feedback_signal_suppressed` | Reinforcement loop suppresses a signal |
| `home_ai_feedback_segment_boosted` | Reinforcement loop upgrades segment confidence |
| `home_ai_feedback_history_cleared` | User taps "Clear feedback history" |

The existing `home_ai_feedback_submitted` stays unchanged.

## Phase E discipline

C5 ships during the v7.9 Phase E 14-day soak (2026-05-21 → ~2026-06-04). **No new enforcement gates, no new schema fields, no new observability surfaces.** All work consumes the existing v7.8.6 + v7.9 infrastructure. Phase E compliant.

## Lifecycle (single-session ship)

| Phase | Commits | Duration (T2) |
|---|---|---|
| Research | research.md (11 sections, 161 lines) | ~70 min |
| PRD | docs/product/prd/ai-user-feedback-loop.md (349 lines) | ~20 min |
| Tasks | tasks.md (12 tasks, dependency graph, 7-commit Phase 4 plan) | ~10 min |
| Implement | 6 standalone-buildable commits — T1+T3+T11 (6a00984), T2+T4 (be993f8), T5 (571881d), T6 (c476572), T7+T8 (f95e85b), T9+T10 (438e02c) | ~67 min |
| Test | 4 new test files, 14 tests, all pass on iPhone 17 Simulator | ~10 min |

**Total session wall time:** ~3 hours, 7 commits, 670 LoC actual (PRD estimated 870, came in under).

## Verification

| Check | Result |
|---|---|
| `xcodebuild build -scheme FitTracker -destination 'generic/platform=iOS Simulator'` | BUILD SUCCEEDED after every commit (T1) |
| `xcodebuild test -only-testing:…` (4 C5 test classes) | 14/14 PASSED on iPhone 17 Simulator (T1) |
| `make ui-audit` | P0 = 0 maintained; +0 new P1 from C5 (T1) |
| Schema check (`scripts/check-state-schema.py`) | 82/82 state.json pass (T1) |
| Tier 2.2 contemporaneous log | 5 phase_transition entries via `scripts/append-feature-log.py` (T1) |

## Risks & mitigations (T3)

| Risk | Mitigation |
|---|---|
| Suppression over-correction (user dismisses once-by-mistake → suppressed at 3rd dismissal) | 30-day rehabilitation window; Settings surface shows currently-suppressed signals; clear-all resets |
| Acceptance-rate overfit (training boost suppresses recovery) | Per-segment scope (independent); baseline AI engine still available |
| Opt-out cliff (users disable on first frustration) | Default ON + clear opt-out copy; `signal_suppressed` analytics tracks suppression-then-opt-out patterns |
| Test flake from `RecommendationMemory.clearAll()` between tests | Per-test UserDefaults isolation pattern (already proven in T8.A/B test files) |

## What's NOT in C5 (out-of-scope guards)

- C5.b — Time-decay weighting (recent feedback weighted more)
- C5.c — Cross-routing C2 + C4 banner `action_taken` events into RecommendationMemory
- C5.d — Cohort-level aggregation (privacy-impacting → D1)
- C5.e — Suppression-transparency UX (needs user research first)
- Server-side dismiss-reason aggregation (privacy boundary — free text on-device only)

## Companion work shipped alongside

- C2 (readiness-aware-training-alert) PR #560 — established `home_*_alert_action_taken` sibling pattern
- C4 (trend-alerts-hrv) PR #564 — second action_taken pattern
- C5 (this feature) PR #572 — wires UI ↔ memory ↔ orchestrator

## References

- PR: <https://github.com/Regevba/FitTracker2/pull/572>
- Phase 0 Research: [`.claude/features/ai-user-feedback-loop/research.md`](../../.claude/features/ai-user-feedback-loop/research.md)
- Phase 1 PRD: [`docs/product/prd/ai-user-feedback-loop.md`](../product/prd/ai-user-feedback-loop.md)
- Phase 2 Tasks: [`.claude/features/ai-user-feedback-loop/tasks.md`](../../.claude/features/ai-user-feedback-loop/tasks.md)
- State: [`.claude/features/ai-user-feedback-loop/state.json`](../../.claude/features/ai-user-feedback-loop/state.json)
- Sibling C2 case study: [`readiness-aware-training-alert-case-study.md`](readiness-aware-training-alert-case-study.md)
- Sibling C4 case study: [`trend-alerts-hrv-case-study.md`](trend-alerts-hrv-case-study.md)
- Source of UI-024: PR #79 (2026-04-10) — original storage + UI scaffold
- Backlog row: `docs/product/backlog.md` L351 ("User feedback loop for AI") — to be struck on PR #572 merge
