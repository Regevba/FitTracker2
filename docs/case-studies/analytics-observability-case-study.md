---
title: "Analytics Observability — closing the measurement-debt loop (taxonomy cleanup + live GA4 path)"
feature: analytics-observability
date_written: 2026-06-09
date: 2026-06-09
framework_version: v7.8.5
work_type: Feature
dispatch_pattern: incremental-phased
primary_metric: "Analytics taxonomy drift (CSV-missing-rows count): baseline 56 → target 0 → achieved 0 (T2, declared with baseline/target/current in state.json::phases.metrics)"
success_metrics:
  - "Taxonomy drift: 56 missing CSV rows → 0; CSV ↔ AnalyticsEvent enum ↔ code in sync (T2)"
  - "iOS event test coverage: 81% → 100% (112/112 events) via 19 new XCTest methods (T2)"
  - "Declared-but-unfired iOS events: 4 → 0 (T2)"
  - "GA4 MCP connectivity: disconnected → connected (env-var + access-binding fixes) + analytics-watch CLI + SSE mirror + debug-sink adapter operational (T2)"
kill_criteria:
  - "If the Phase 1.B taxonomy/connectivity gates (CSV_TAXONOMY_DRIFT + GA4_MCP_DISCONNECTED) produce >5% false-positive rate in their calibration window, defer gate enforcement to v7.10 and ship the hygiene-only outcome (taxonomy cleanup + instrumentation fixes are retained regardless)."
kill_criteria_resolution: "Not triggered. The Phase 1.B enforcement gates were folded into the v8.0 docket (F19/F20) rather than shipped in-feature, so the >5%-false-positive condition has no active gate to fire against; the hygiene + observability outcome shipped as planned. The one open item — D-2 (configure GA4 conversions: workout_complete + nutrition_meal_logged in the GA4 dashboard) — is operator-only (GA4 console config, no code), deferred to App Store launch because pre-launch TestFlight traffic is 100% same-day new-users (vanity numbers, not measurement). Tracked in the Operator Action Register. D-2 does not gate the shipped instrumentation/tooling deliverables."
tier_tags_present: true
state_owner: ft2
related_prs: [332, 334, 335, 336, 337, 338, 339, 342, 345, 349, 351, 354, 358, 362, 376, 388]
---

# Analytics Observability

> **One-line:** the project had shipped extensive analytics instrumentation but had no clean taxonomy and no live way to *observe* events landing; this feature closed the measurement-debt loop — CSV ↔ enum ↔ code drift to zero, plus a live GA4 observability path (MCP poll + SSE mirror + debug sink + watch CLI).

## Problem

Before this feature: the analytics taxonomy CSV was missing ~56 rows, several declared events never fired, the GA4 MCP was disconnected, and iOS analytics events were silently not firing because the analytics plist lacked correct target membership. There was no live feedback loop to confirm events actually reached GA4 — instrumentation was write-and-hope. **(T2, declared from the feature's PR roster + 2026-05-13 session notes.)**

## What shipped (16 PRs, #332 → #388)

Phased across instrumentation correctness, observability tooling, and live-connection fixes:

- **Taxonomy + instrumentation correctness:** CSV taxonomy backfill (PR #334), delete the unfired `ai_recommendation` event (#335), forward-declared-events convention (#336), spec extensions (#337), iOS analytics tests (#338), external sync status (#339), and the iOS analytics plist target-membership fix that made events fire on device (#388).
- **Observability tooling:** local SSE mirror (#342), `analytics-watch` CLI (#345), debug-sink adapter (#349), and live GA4 polling via the GA4 MCP (#351).
- **Live-connection fixes:** GA4 MCP env-var fix (#362) + GA4 access-binding guide (#376).
- **Phase scaffolding + reconcile:** Phase 1 PRD (#332), Phase 3A spec scaffold (#354), Phase 3A reconcile-complete (#358).

## Outcome

The taxonomy is in sync and the observability path is live — analytics is no longer write-and-hope. **(T2, declared.)** This case study is a **retroactive closure**: the feature shipped its substance across 16 merged PRs and sat in `testing` because the only remaining task is operator-gated.

- **D-2 (deferred, operator-only):** configure GA4 conversions (`workout_complete` + `nutrition_meal_logged`) in the GA4 dashboard. No code; deferred to the operator per the Operator Action Register. The feature is closed accepting D-2 as a deferred operator action.
- No formal PRD-defined primary metric was recorded in `state.json` at the time; metrics here are honestly tiered **T2 (declared)** rather than presented as instrumented outcomes. **(T2/T3.)**

## Follow-up

- **D-2** — operator GA4 dashboard conversion config (Operator Action Register).
- Showcase MDX (`fitme-story/content/04-case-studies/`) ships as a separate fitme-story PR per the chronological-order rule.
