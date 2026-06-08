---
title: "Analytics Observability Platform"
feature: analytics-observability
date_written: 2026-06-08
framework_version: v7.8.5
work_type: Feature
dispatch_pattern: "serial / incremental phase-by-phase (single-agent, no parallel dispatch)"
primary_metric: "Analytics instrumentation integrity — every declared analytics event is actually fired AND test-covered (no declared-but-unfired events, no untested events)."
success_metrics:
  - "0 declared-but-unfired analytics events (baseline: several — ai_recommendation_*, fitme-story design_system_*)"
  - "100% iOS analytics-event test coverage (baseline 81%) [T1]"
  - "Live local observability: SSE mirror + /analytics watch/poll CLI + iOS DebugSink + web mirror"
  - "GA4 MCP connected for direct dashboard queries"
kill_criteria: "Local-mirror observability adds measurable production overhead, OR analytics events regress (declared-but-unfired count > 0 after ship)."
kill_criteria_resolution: "Not fired. 0 declared-but-unfired events post-ship; the local mirror is DEBUG-only (gated behind DEBUG_ANALYTICS_SINK / NEXT_PUBLIC_* env), so it carries zero production overhead by construction."
tier_tags_present: true
related_prs: [336, 337, 338, 339, 342, 345, 349, 351, 354, 358, 362, 477, 489, 493, 570]
state_owner: ft2
case_study_type: standard
---

# Analytics Observability Platform — Case Study

> **Retroactive-metrics note:** this feature shipped incrementally from 2026-05-13
> across three phases and many sessions without a formally-completed PRD, so the
> metrics above are **declared retroactively at closure (T2)** except the iOS test
> coverage figure, which is instrumented (T1). They reflect what the work
> actually targeted, not a pre-registered contract.

## Problem

The app emitted analytics, but we could not *trust* or *observe* them:
- The taxonomy declared **49 events + 7 screens + 1 user property**, but several
  were **declared-but-never-fired** (`ai_recommendation_*` on iOS, `design_system_*`
  on the fitme-story web side).
- iOS analytics-event **test coverage was 81%** — a fifth of events had no test
  asserting they fire with the right params.
- There was **no live way to watch events** during development — you shipped, then
  waited for GA4's processing lag to see whether anything arrived.
- GA4 itself was queryable only through the web UI (no programmatic/MCP access).

## What shipped (3 phases)

**Phase 1 — Taxonomy integrity (PRs #336–#339):**
- CSV taxonomy backfill: 49 events + 7 screens + 1 user property reconciled to the
  canonical `analytics-taxonomy.csv` [T2].
- Resolved every declared-but-unfired event (`ai_recommendation_*`, `design_system_*`).
- **+19 iOS analytics tests → coverage 81% → 100% [T1]** (#338).
- Refreshed `external-sync-status.json` analytics block (#339).

**Phase 2 — Local observability mirror (PRs #342, #345, #349, #351, #362):**
- Local analytics **SSE mirror server** — tees events to a live local sink (#342).
- `/analytics watch` + `/analytics poll` **CLI sub-commands** (#345, #351).
- iOS **`DebugSinkAdapter`** — tees events to the local SSE sink under DEBUG (#349).
- fitme-story **web mirror function** — tees gtag emits when `NEXT_PUBLIC_*` is set.
- **GA4 MCP connected** for direct dashboard queries (#351 runbook + #362 env fix).

**Phase 3 — Dashboard scaffold (PRs #354, #358):**
- Phase 3 spec scaffold (master plan §7.5/§7.6 + metric definitions) (#354).
- fitme-story **`/control-room/analytics`** route scaffold (#358).

**Wiring + reconciliation (PRs #477, #489, #493, #570):**
- `D-3` — wire `AnalyticsScreenModifier` to the main tabs / Settings (#489).
- `D-4` — delete the stale `com.regevba.FitTracker` Firebase iOS app entry.
- `B1–B4` — GA4 funnels + conversion-events operator runbook (#570).

## Outcome

| Dimension | Before | After |
|---|---|---|
| Declared-but-unfired events | several | **0** [T2] |
| iOS analytics-event test coverage | 81% | **100%** [T1] |
| Live event observability | none (GA4 lag only) | SSE mirror + CLI watch/poll + iOS DebugSink + web mirror |
| GA4 programmatic access | web UI only | GA4 **MCP** connected |
| Operator funnel/conversion runbook | none | shipped (#570) |

## Deferred (operator-gated)

**D-2 — Configure GA4 conversions** (`workout_complete` + `nutrition_meal_logged`).
This is a **GA4 Admin dashboard action**, not code — it cannot be done from the
repo. The events fire correctly and are validated; marking them as *conversions*
in GA4 is an operator step. Deferred at closure with this reason; the feature is
otherwise complete. See the closure instructions in the merge PR for the exact
GA4 Admin steps.

## Platforms tested

`{ios: true, web: true, backend: false, ai: false}` — iOS via the 19 analytics
XCTest assertions (coverage 81%→100%); web via the fitme-story mirror + the
`/control-room/analytics` scaffold; no product-backend (sync/Supabase) or
ai-engine surface in scope.

## Lessons

1. **Observability before scale.** The local SSE mirror turned analytics from a
   "ship and wait for GA4" loop into a live, same-session feedback loop — the
   single highest-leverage piece.
2. **Declared ≠ fired.** A taxonomy is a contract; without a test asserting each
   event actually fires, "declared" events silently rot. The +19 tests (81%→100%)
   closed that gap mechanically.
3. **Some closure items are genuinely external.** D-2 (GA4 conversion marking) is
   a dashboard action — the right move is to ship the code, validate the events,
   and defer the dashboard config with a clear operator runbook, not to block the
   whole feature on it.
