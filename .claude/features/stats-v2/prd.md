# Stats v2 — PRD (UX Foundations Alignment)

> **Type:** Feature (v2_refactor) | **Phase:** 1

## Problem
StatsView has the best token compliance (100% font/color/spacing/radius) but the worst accessibility (27% — 4/15 elements). The interactive chart is completely invisible to VoiceOver. No analytics events track user behavior on this screen.

## Solution
- Fix 9 audit findings (2 P0, 3 P1, 4 P2)
- Create `AppLayout` enum for chart/component sizing tokens
- Add chart accessibility with summary descriptions
- Extract 3 nested types to separate files
- Add 4 analytics events with `stats_` prefix
- Achieve 90%+ accessibility coverage (from 27%)

## Success Metrics
- **Primary:** VoiceOver element coverage 27% → 90%+
- **Kill criteria:** Coverage drops below 70%
- **Secondary:** Motion compliance 0% → 100%, chart accessible
- **Guardrails:** Crash-free > 99.5%, cold start < 2s

## Analytics Spec

| Event | Params | Conversion |
|-------|--------|-----------|
| stats_period_changed | period (day/week/month/quarter/year/all) | No |
| stats_metric_selected | metric_name, category | No |
| stats_chart_interaction | metric_name, interaction_type (drag/tap) | No |
| stats_empty_state_shown | metric_name | No |

### Naming Validation
- [x] snake_case, lowercase, ≤40 chars
- [x] `stats_` prefix per CLAUDE.md rule
- [x] No PII, no reserved prefixes, no duplicates

## DS Evolution
| Token | Value | Purpose |
|-------|-------|---------|
| `AppLayout.chartHeight` | 158 | Standard chart canvas height |
| `AppLayout.emptyStateMinHeight` | 128 | Empty state container minimum |
| `AppLayout.chipMinWidth` | 128 | Metric chip minimum width |
| `AppLayout.dotSize` | 8 | Selection indicator dot |

## Scope
**In:** 9 findings, 4 analytics events, AppLayout enum, type extraction, a11y pass
**Out:** Chart library migration, new chart types, data model changes
