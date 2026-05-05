# PRD: Metric Tile Deep Linking

> **ID:** Sub-feature of 18.4 (home-today-screen) | **Status:** Shipped | **Priority:** P1 (deferred from Home v2)
> **Last Updated:** 2026-05-05 (retroactive PRD via iOS audit Tier 2 finding C-1)
> **Branch:** `feature/metric-tile-deep-linking` (merged via PR #67, commit `04464848`)
> **Parent:** [`18.4-home-today-screen.md`](18.4-home-today-screen.md)
> **State:** [`.claude/features/metric-tile-deep-linking/state.json`](../../.claude/features/metric-tile-deep-linking/state.json) (`current_phase: complete`)
> **Case study:** parent_case_study points at [`home-today-screen-v2-case-study.md`](../../case-studies/home-today-screen-v2-case-study.md)

> **Retroactive note (2026-05-05):** This PRD was authored after the feature shipped, as part of the iOS audit Tier 2 finding C-1. The feature itself was an `enhancement` work-type with phases Research / PRD / UX `skipped` per work_type rules — this document formalizes what shipped so the PRD chain is complete going forward. All claims below are sourced from PR #67's body, the linked state.json, the parent home-today-screen case study, and the commit `04464848` diff. Nothing is fabricated.

---

## Purpose

When users see a metric tile on the Home screen (HRV, RHR, Sleep, Steps), tapping it should navigate to the Stats tab pre-filtered to that metric — providing a one-tap drill-down from "summary" to "detail" without requiring users to manually switch tabs and pick a metric.

## Business Objective

Reduce friction in the **summary → detail** loop for biometric metrics. Users glance at the Home Tile to see today's number, then often want to inspect the trend. Pre-Home-v2 they had to: tap Stats tab → wait for chart → manually select metric. Post-deep-linking: one tap.

This pattern was deferred from the Home v2 ship (PR #61, 2026-04-09) per OQ-13 ("metric tile interactivity") and F25-partial ("home_metric_tile_tap event scaffolded but not wired to navigation"). Shipping it as a sub-feature kept Home v2's scope tight.

## Target Persona(s)

- **All personas** — every user sees the metric tiles on Home

## What Shipped (PR #67, merged 2026-04-09T13:13:43Z, commit `04464848`)

### Changes (7 files)

| File | Delta | Purpose |
|---|---|---|
| `FitTracker/DesignSystem/AppComponents.swift` | `AppMetricTile` gained `onTileTap` callback | Optional callback for tap handling; nil default = backward compat |
| `FitTracker/Views/Stats/v2/StatsView.swift` | `initialMetric: StatsFocusMetric?` parameter | Allows pre-selection from external caller |
| `FitTracker/Views/Main/v2/MainScreenView.swift` | Tiles wired with `onTileTap` → publishes pending metric | Source of the deep-link |
| `FitTracker/Views/RootTabView.swift` | `pendingStatsMetric` binding threaded through | Cross-tab state plumbing |
| `FitTracker/Services/Analytics/AnalyticsProvider.swift` | `home_metric_tile_tap` event | Per Home v2 screen-prefixed analytics convention |
| `FitTracker/Models/Stats/StatsFocusMetric.swift` (existing) | (no change) | Used as the typed metric identifier |

### Behavior

1. User on Home taps a metric tile (HRV / RHR / Sleep / Steps)
2. `AppMetricTile.onTileTap(metric)` fires
3. `MainScreenView` publishes `pendingStatsMetric = metric` upward
4. `RootTabView` switches to Stats tab, passes `pendingStatsMetric` as `initialMetric`
5. `StatsView` (v2) initializes with that metric pre-selected; chart shows it immediately
6. `home_metric_tile_tap` analytics event fires with the metric name as a property

### Backward compatibility

- `onTileTap` is optional (nil default). Tiles that don't pass a callback are no-ops on tap.
- `initialMetric` is optional. Stats view without it uses its existing default (whichever metric was last viewed).

## Success Metrics

- **Primary [T2]:** `home_metric_tile_tap` events fire on every tile tap. Ratio target: ≥ 80% of users who view Home tap at least one tile per week (measured via GA4 funnel: `home_view` → `home_metric_tile_tap`).
- **Secondary [T3]:** Time-to-stats-detail (median) drops vs pre-v2 baseline. (No T1 baseline measurement was instrumented; T3 narrative claim only.)

## Kill Criteria

This is an enhancement of an existing screen with zero new code paths or data dependencies. Reverting to the pre-v2 behavior (manual tab switch) would be acceptable if:
- `home_metric_tile_tap` triggers a measurable crash spike (none observed at ship)
- Cross-tab state plumbing breaks under iOS 18 SDK updates (low risk; `Binding<T>` semantics are stable)

No growth-threshold kill criterion. The feature is a UX nicety on top of existing screens; it's removable but not actively harmful.

## Tests

- Existing `StatsView` unit tests cover `initialMetric: nil` (default behavior)
- New `StatsView` tests for `initialMetric: .hrv | .rhr | .sleep | .steps` paths (covered in v2 StatsView tests)
- Analytics tests verify `home_metric_tile_tap` fires with the correct metric property (covered in `HomeAnalyticsTests.swift` — confirmed via grep on 2026-05-05)

CI green at merge per state.json `phases.testing.ci_passed: true`.

## Predecessor / Successor Linkage

- **Parent feature:** `home-today-screen` (PR #61, 2026-04-09). Home v2 introduced the metric tile component but left tap behavior as a no-op.
- **Companion sub-feature:** `home-status-goal-card` (PR #65, 2026-04-09) — sibling enhancement of Home v2 in the same wave.
- **Used by:** Stats tab (`StatsView` v2). The deep-link is one of three entry paths to a pre-filtered Stats view (the others: in-app launch deep-link via custom URL scheme, push-notification tap with metric payload — both future work).

## Why this PRD was retroactive

- Shipped 2026-04-09 as an `enhancement` work_type (Research / PRD / UX phases legitimately skipped per CLAUDE.md "Work Item Types" rule)
- 2026-05-05 iOS audit (finding C-1) flagged the absence of a discoverable PRD for this feature
- Decision: rather than mark `case_study_type: pre_pm_workflow_backfill` (which would exempt it), write a real PRD documenting what shipped — per the user's "formalize older work that must be documented properly" directive

The PRD is forward-looking from the chain-of-custody perspective: future readers can find this feature via:
1. `docs/product/prd/metric-tile-deep-linking.md` (this file)
2. `docs/product/prd/18.4-home-today-screen.md` Children list (cross-reference)
3. `.claude/features/metric-tile-deep-linking/state.json` (existing)
4. `docs/case-studies/home-today-screen-v2-case-study.md` (parent CS, references this sub-feature)

## Cross-references

- **Sibling PRD (also Home v2 child):** [`home-status-goal-card.md`](home-status-goal-card.md) (referenced from 18.4)
- **Parent PRD:** [`18.4-home-today-screen.md`](18.4-home-today-screen.md)
- **State:** `.claude/features/metric-tile-deep-linking/state.json`
- **PR:** #67 (merged 2026-04-09)
- **Commit:** `04464848`
