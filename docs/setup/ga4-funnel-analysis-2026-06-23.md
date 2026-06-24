# GA4 Funnel Analysis — Live Readout (2026-06-23)

> **Feature:** `funnel-analysis-dashboards` (Enhancement of `analytics-observability`).
> **What this is:** the first time the 5 canonical funnels defined in
> [`ga4-funnels-and-conversions-runbook.md`](ga4-funnels-and-conversions-runbook.md) (2026-06-01)
> are run against **live GA4 data**. The runbook defines the funnels; this doc reports what the
> data actually shows + which PRD kill-criteria are evaluable today.
> **Machine-readable companion:** [`docs/product/funnel-definitions.json`](../product/funnel-definitions.json).

## Method + provenance

- **Source:** GA4 property `G-XE4E1JGWRZ` via the `ga4` MCP (`getEvents`), pulled **2026-06-23**.
- **Window:** 2026-05-26 → 2026-06-22 (rolling 28 days).
- **Tier:** **T1 (Instrumented)** for event-level counts (queried live from GA4). Drop-off ratios computed from those counts are **T1**. Step-level (`step_index`) ratios are **not yet measurable** (see Limitation 1) and are reported as T3/narrative where estimated.
- **Distinct events observed in window:** 29.

### Limitations (carry into every conclusion below)

1. **Parameter-filtered steps are not computable via the Data API.** Funnels whose steps differ only by an event parameter (e.g. `onboarding_step_completed` with `step_index=1..4`) collapse to the event total, because `customEvent:step_index` is **not registered as a GA4 custom dimension** (`runReport` returns `INVALID_ARGUMENT`). Counts here are **event-level totals summed across all parameter values**. → **New operator action O1 below.**
2. **iOS post-onboarding events show 0 hits** (`workout_complete`, `home_action_tap`, `home_action_completed`, all `home_*_alert_*`). Cause: the TestFlight build carrying them has not shipped to testers. Not a regression — an expected coverage gap (runbook B2).
3. **Taxonomy drift:** the alert events `home_readiness_alert_shown` / `home_readiness_alert_tap` / `home_trend_alert_shown` / `home_trend_alert_tap` exist in `AnalyticsProvider.swift` but are **missing from `analytics-taxonomy.csv`** (`home_action_tap` / `home_action_completed` ARE in the CSV). Flagged for an `analytics-observability` follow-up; out of scope here.

## Per-funnel readout

### F1 — Onboarding → first workout (Activation) — **PARTIAL**

| Step | Event | Live 28d | Conv. vs S1 |
|---|---|--:|--:|
| 1 | `first_open` | 414 | 100% |
| 2 | `onboarding_step_viewed` | 379 | 91.5% |
| 3 | `onboarding_step_completed` | 193 | 46.6% |
| 4 | `tutorial_complete` | 1 | 0.2% |
| 5 | `home_action_tap` | 0 | 0% |
| 6 | `workout_complete` ⟵ conversion | **0** | 0% |

**Read:** strong top-of-funnel (91.5% open→view). The cliff at `tutorial_complete` (1) and the 0 conversion are **Limitation 2** (TestFlight) — the activation conversion is **not evaluable** until core-logging ships. `tutorial_complete=1` vs `onboarding_step_completed=193` also hints `tutorial_complete` may be under-wired relative to step completion (worth a code check during the next iOS pass).

### F2 — Onboarding drop-off — **EVALUABLE (event level)**

| Step | Event | Live 28d |
|---|---|--:|
| 1 | `onboarding_step_viewed` | 379 |
| 2-5 | `onboarding_step_completed` (all step_index) | 193 |
| 6 | `tutorial_complete` ⟵ conversion | 1 |
| — | `onboarding_goal_selected` (context) | 85 |
| — | `onboarding_skipped` (context) | 13 |

**Read:** event-level `viewed → completed` = **50.9%** (193/379) [T1]. That is below the runbook's 80% step-to-step kill threshold **at the aggregate level** — but the threshold is defined *per step transition*, which needs the `step_index` custom dimension (Limitation 1) before a kill verdict is valid. **Verdict: kill-criterion is partially evaluable now** (aggregate completion is measurable; per-step is blocked on O1). This is the single highest-value unblock — it is the one PRD kill-criterion with live signal today.

### F3 — Smart Reminders engagement — **BLOCKED**

All 4 step events = 0 (`home_readiness_alert_shown` 0, `home_trend_alert_shown` 0, `home_action_tap` 0, `home_action_completed` 0). **Blocked on TestFlight** (Limitation 2) + taxonomy drift (Limitation 3). Re-run ~14 days after the next TestFlight build carrying C2/C4. C2 (`readiness-aware-training-alert`) + C4 (`trend-alerts-hrv`) kill-criteria are **not evaluable** until then.

### F4 — Web → app conversion — **DEFERRED**

`page_view` 127, `case_study_open` 6, `select_content` 1, attribution-linked `first_open` n/a. Matches runbook status: needs an install CTA on the showcase (`content_type=app_store_link` not wired) + a real install-attribution ecosystem. **Deferred to App Store launch.**

### F5 — Operator UCC observability — **PARTIAL**

| Step | Event | Live 28d |
|---|---|--:|
| 1 | `dashboard_sync_warning_shown` | 5 |
| 2 | `dashboard_load` (entry=alerts_banner) | 9 |
| 3 | `dashboard_blocker_acknowledged` ⟵ conversion | **0** |

**Read:** warnings fire (5) and the dashboard is loaded (9), but the conversion event `dashboard_blocker_acknowledged` shows **0** — either the acknowledge UI isn't wired to emit the event, or no warning required acknowledgement in-window. The UCC TTC SLO (`ack < 1h over 7d`) is **not measurable** until the acknowledge event fires at least once. (`dashboard_view_change` 18 / `dashboard_load` 9 confirm the control-room is actively used.)

## Bottom line

- **3 of 5 funnels have computable live data** (F1 partial, F2 event-level, F5 partial) → meets the enhancement's primary target (≥3); **kill criterion not triggered**.
- **Exactly 1 PRD kill-criterion has live signal today:** onboarding completion (F2, aggregate). Everything else is gated on TestFlight (F1 conversion, F3) or launch (F4) or an unwired conversion event (F5).
- **The single highest-leverage unblock** is operator action O1 (register `step_index` as a GA4 custom dimension) — it converts F2 from aggregate-only to a real per-step kill-criterion evaluation.

## New operator actions surfaced (agent cannot do these)

| ID | Action | Where | Unblocks |
|---|---|---|---|
| **O1** | Register `step_index` (+ `step_name`) as **custom dimensions** in GA4 Admin → Custom definitions | GA4 console (Admin/Editor) | Per-step F1/F2 drop-off → real onboarding kill-criterion evaluation |
| **O2** | Ship the next **TestFlight build** to testers so iOS core-logging + C2/C4 alert events reach GA4 | TestFlight | F1 conversion, F3 entirely |
| **O3** | (analytics-observability follow-up) Add CSV rows for `home_readiness_alert_shown/_tap` + `home_trend_alert_shown/_tap` (taxonomy drift) | `docs/product/analytics-taxonomy.csv` | Removes Limitation 3 / restores taxonomy-drift=0 |

These extend the existing operator register ([`docs/setup/operator-actions-pending.md`](operator-actions-pending.md) A1 GA4 conversions) and the runbook's B3/B4 console-wiring steps. The runbook remains the source of truth for the console-wiring how-to.

## Re-run cadence

Re-run this analysis (a) after O2 (TestFlight ship) + ~14d, and (b) after O1 (custom dims) to add per-step F1/F2 ratios. The query is reproducible: `ga4 MCP getEvents` over the rolling 28d window, cross-referenced against [`funnel-definitions.json`](../product/funnel-definitions.json).
