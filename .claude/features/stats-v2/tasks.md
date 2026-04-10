# Stats v2 — Task Breakdown

> **Total:** 10 tasks | **Effort:** ~2 days | **Waves:** 4

## Wave 1 (parallel): T1, T2

### T1. Create AppLayout enum in AppTheme.swift
- **Skill:** design | **Priority:** critical | **Effort:** 0.1d
- Add `AppLayout.chartHeight` (158), `AppLayout.emptyStateMinHeight` (128), `AppLayout.chipMinWidth` (128), `AppLayout.chipIdealWidth` (144), `AppLayout.chipMaxWidth` (168), `AppLayout.dotSize` (8)

### T2. Extract nested types to Models/Stats/
- **Skill:** dev | **Priority:** medium | **Effort:** 0.25d
- Extract `StatsPeriod` (L6-52), `StatsFocusMetric` (L54-239), `MetricSeriesPoint` (L241-246)
- Create `FitTracker/Models/Stats/` directory

## Wave 2: T3

### T3. Build v2/StatsView.swift
- **Skill:** dev | **Priority:** critical | **Effort:** 0.5d
- **Depends on:** T1, T2
- Fix F1: raw animation → AppMotion.quickInteraction
- Fix F3-F5: hardcoded frames → AppLayout tokens
- Fix F2: chart accessibility (summary label + value)
- Fix F6: period picker a11y labels
- Fix F7: ChartCard container a11y
- Fix F8: document GeometryReader usage
- Wire extracted types from T2

## Wave 3 (parallel): T4, T5, T6

### T4. Update project.pbxproj (v2 swap)
- **Skill:** dev | **Priority:** critical | **Effort:** 0.1d
- **Depends on:** T3

### T5. Instrument 4 analytics events
- **Skill:** analytics | **Priority:** high | **Effort:** 0.2d
- **Depends on:** T3

### T6. Full accessibility pass
- **Skill:** dev | **Priority:** high | **Effort:** 0.2d
- **Depends on:** T3
- Target: 14/15+ elements labeled

## Wave 4 (parallel): T7, T8, T9, T10

### T7. Analytics tests (5 tests)
- **Skill:** qa | **Priority:** high | **Effort:** 0.2d
- **Depends on:** T5

### T8. V2 refactor checklist
- **Skill:** qa | **Priority:** medium | **Effort:** 0.1d
- **Depends on:** T3, T4, T6

### T9. CI verification
- **Skill:** dev | **Priority:** critical | **Effort:** 0.1d
- **Depends on:** T7

### T10. Mark v1 historical
- **Skill:** dev | **Priority:** low | **Effort:** 0.05d
- **Depends on:** T4
