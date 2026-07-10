---
slug: funnel-analysis-dashboards
title: "Funnel Analysis Dashboards — running the canonical funnels against live GA4"
date_written: 2026-06-24
framework_version: v7.10
work_type: Enhancement
parent_feature: analytics-observability
case_study_type: shipped
tier_tags_present: true
status: shipped
case_study: docs/case-studies/funnel-analysis-dashboards-case-study.md
case_study_showcase: fitme-story/content/04-case-studies/59-funnel-analysis-dashboards.mdx
related_prs:
  - 799
dispatch_pattern: serial
primary_metric:
  name: funnels_with_computed_live_drop_off
  baseline: "0 of 5 (definitions were prose-only, never run against data)"
  target: "≥3 of 5"
  current: "3 of 5 (F1 partial, F2 event-level, F5 partial)"
success_metrics:
  - name: funnels_with_computed_live_drop_off
    baseline: "0 of 5"
    target: "≥3 of 5"
    current: "3 of 5 [T1 — GA4 MCP 28d query 2026-06-23]"
  - name: kill_criteria_evaluations_unblocked
    baseline: 0
    target: 2
    current: "1 (onboarding-completion, F2 aggregate) [T1]"
kill_criteria: "If <3 of 5 funnels have any computable live drop-off, defer the analysis report until after the TestFlight ship and reduce scope to the machine-readable defs only."
kill_criteria_resolution: "NOT FIRED — 3 of 5 funnels (F1/F2/F5) have computable live drop-off in the 28d window, meeting the ≥3 threshold. Full scope shipped (analysis report + machine-readable defs + validation test)."
---

# Funnel Analysis Dashboards

## Summary

An Enhancement of `analytics-observability`. The backlog framed this (RICE 6.0) as
"just needs GA4 funnel definitions wired" — but a **Phase 0.1 reality-check** found the
5 canonical funnel definitions had already shipped (2026-06-01,
[`ga4-funnels-and-conversions-runbook.md`](../setup/ga4-funnels-and-conversions-runbook.md)).
The definitions were prose-only and had **never been run against live data**.

So the scope was reframed to the genuinely agent-ownable, net-new work:
1. Run the 5 funnels against **live GA4** (28d via the `ga4` MCP) — first real readout.
2. Extract the prose defs into a **machine-readable data contract**
   ([`docs/product/funnel-definitions.json`](../product/funnel-definitions.json)).
3. Map each funnel to the **kill-criteria** it unblocks; guard the contract with a test.

Operator-only GA4-console / Looker wiring stayed out of scope (already documented in the runbook).

## What the live data showed [T1 — GA4 property G-XE4E1JGWRZ, 2026-05-26→2026-06-22]

| Funnel | Live verdict |
|---|---|
| F1 Activation | **Partial** — strong top (open→view 91.5%); conversion `workout_complete`=0 (TestFlight) |
| F2 Onboarding drop-off | **Event-level** — viewed 379 → completed 193 = **50.9%**; per-step blocked on custom dims |
| F3 Smart Reminders | **Blocked** — all alert events 0 (TestFlight not shipped) |
| F4 Web→App | **Deferred** — no install bridge |
| F5 UCC observability | **Partial** — warning 5 → load 9; conversion event never fired |

**3 of 5 funnels computable; only onboarding-completion (F2) has live kill-criterion signal today.**

## Findings that mattered

- **The highest-leverage unblock is not code — it's GA4 config.** Parameter-filtered funnel
  steps (`step_index`) can't be computed via the Data API until the operator registers those
  params as **custom dimensions** (`runReport` → `INVALID_ARGUMENT`). Surfaced as operator
  action **O1**; it converts F2 from aggregate-only to a real per-step onboarding kill-criterion.
- **The validation test earned its keep on day one.** `test_funnel_definitions.py` cross-checks
  each step event against the taxonomy CSV and caught a real mislabel during development
  (`home_action_completed` is in-taxonomy, not drifted).
- **Taxonomy drift caught as a side effect:** `home_readiness_alert_shown/_tap` +
  `home_trend_alert_shown/_tap` exist in `AnalyticsProvider.swift` but are missing from
  `analytics-taxonomy.csv`. Flagged as operator action **O3** for an `analytics-observability`
  follow-up (out of scope here).

## Operator follow-ups surfaced

| ID | Action | Unblocks |
|---|---|---|
| O1 | Register `step_index` (+`step_name`) as GA4 custom dimensions | Per-step F1/F2 → real onboarding kill-criterion |
| O2 | Ship the next TestFlight build | F1 conversion + F3 entirely |
| O3 | Add taxonomy CSV rows for `home_*_alert_*` | Closes the taxonomy drift |

Recorded in [`docs/setup/operator-actions-pending.md`](../setup/operator-actions-pending.md) §E.

## Verification

- `scripts/tests/test_funnel_definitions.py` — 10/10 pass (schema + taxonomy cross-ref)
- Broader scripts suite 34/34 · `make integrity-check` 0 findings / 0 advisory
- Guardrail held: **no new analytics events** (analysis-only; taxonomy unchanged)

## Tier note

Event-level counts and the drop-off ratios derived from them are **T1 (Instrumented)** — queried
live from GA4. Per-step (`step_index`) ratios are **not yet measurable** (O1) and are reported as
narrative where estimated. Shipped via PR #799.
