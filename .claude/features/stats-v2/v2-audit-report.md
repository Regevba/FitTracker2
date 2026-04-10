# Stats v2 — UX Foundations Audit Report

> **Date:** 2026-04-10
> **File:** `FitTracker/Views/Stats/StatsView.swift` (890 lines)
> **Severity:** 2 P0, 3 P1, 4 P2 (9 total)

## Compliance Scorecard

| Dimension | Score | Notes |
|-----------|-------|-------|
| Font tokens | 100% | Fully compliant |
| Spacing tokens | 100% | Fully compliant |
| Color tokens | 100% | Fully compliant |
| Radius tokens | 100% | Fully compliant |
| Motion tokens | 0% | 1 raw animation |
| Accessibility | 27% | 4/15 — worst ratio of all screens |
| State coverage | 100% | Loading, empty, error all present |

## P0 Findings (2)

### F1. Raw animation
- **Line:** 459
- **Violation:** `.easeInOut(duration: 0.2)` instead of AppMotion token
- **Fix:** `AppMotion.quickInteraction`

### F2. Chart has zero VoiceOver support
- **Lines:** 524-626
- **Violation:** Chart body renders drag-gesture interactive chart with no accessibility. Data invisible to assistive tech.
- **Fix:** Add `.accessibilityLabel` + `.accessibilityValue` with chart summary. Wrap with `AXChartDescriptorRepresentable` for full support.

## P1 Findings (3)

### F3. Hardcoded chart/empty heights (128, 158)
- **Lines:** 444, 571
- **Fix:** Create `AppLayout.chartHeight` and `AppLayout.emptyStateMinHeight`

### F4. Hardcoded chip widths (128/144/168)
- **Line:** 495
- **Fix:** Extract to AppLayout constants or MetricChipView component

### F5. Hardcoded dot frame (8x8)
- **Line:** 472
- **Fix:** Use `AppSpacing.xxSmall` (8pt)

## P2 Findings (4)

### F6. Period picker — no a11y labels
- **Lines:** 363-379
- **Fix:** Add `.accessibilityLabel(option.periodLabel)` ("Today", "Last 7 days", etc.)

### F7. ChartCard — no container a11y
- **Lines:** 427-451
- **Fix:** Add `.accessibilityElement(children: .contain).accessibilityLabel("\(metric.title) statistics")`

### F8. GeometryReader in chart overlay
- **Lines:** 580-603
- **Fix:** Document or replace with `.chartGesture` (iOS 17+)

### F9. Nested types (StatsPeriod, StatsFocusMetric, MetricSeriesPoint)
- **Lines:** 6-246
- **Fix:** Extract to `Models/Stats/` files

## Decisions Required

| # | Finding | Question | Decision |
|---|---------|----------|----------|
| Q1 | F3 | Chart/empty height tokens | Create `AppLayout` enum |
| Q2 | F4 | Chip sizing approach | Extract to AppLayout constants |
| Q3 | F8 | GeometryReader replacement | Document inline (keep for iOS 16 compat) |

## Analytics Gap
No `stats_` prefixed events exist. Need: `stats_period_changed`, `stats_metric_selected`, `stats_chart_interaction`, `stats_empty_state_shown`.
