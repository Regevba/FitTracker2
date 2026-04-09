# home-status-goal-card — Task Breakdown

> **Phase:** 2 (Tasks)
> **Source:** `.claude/features/home-status-goal-card/prd.md`

---

## Dependency graph

```
T1 (analytics enums) ─────────────┐
T2 (BodyCompositionCard view) ────┤
T3 (BodyCompositionDetailView) ───┤──→ T5 (wire into MainScreenView) ──→ T7 (a11y pass)
T4 (macro strip sub-view) ────────┘                                        │
                                                                           ├──→ T8 (tests)
T6 (remove old statusCard + goalCard) ── depends on T5                     │
                                                                           └──→ T9 (checklist)
```

---

## Tasks

### T1 — Add analytics enums + taxonomy rows
- **Type:** analytics | **Skill:** analytics | **Priority:** high | **Effort:** 0.25d
- **Depends on:** —
- Add to `AnalyticsEvent`: `homeBodyCompTap`, `homeBodyCompPeriodChanged`, `homeBodyCompLogTap`
- Add to `AnalyticsParam`: `hasWeight`, `hasBodyFat`, `progressPercent`, `period`
- Add to `AnalyticsScreen`: `bodyCompDetail`
- Add 3 convenience methods to `AnalyticsService.swift`
- Update `analytics-taxonomy.csv` with 3 event rows + 1 screen row

### T2 — Create BodyCompositionCard view
- **Type:** ui | **Skill:** dev | **Priority:** critical | **Effort:** 1d
- **Depends on:** —
- New file: `FitTracker/Views/Main/BodyCompositionCard.swift`
- Layout per PRD wireframe: eyebrow + chevron, hero weight/BF values, target ranges, linear progress bar, macro strip slot, recommendation line
- Use `AppMetricColumn` for weight/BF (or adapt for inline horizontal layout)
- Linear progress bar using existing `progressLine` pattern or new `AppProgressBar`
- Empty state: "Log your first metrics" CTA
- `onTap` callback for drill-down
- All design system tokens, zero raw literals

### T3 — Create BodyCompositionDetailView
- **Type:** ui | **Skill:** dev | **Priority:** critical | **Effort:** 1.5d
- **Depends on:** —
- New file: `FitTracker/Views/Main/BodyCompositionDetailView.swift`
- Sheet with `.medium`/`.large` detents
- Weight trend chart (SwiftUI Charts) with goal line overlay
- Body fat trend chart with goal line overlay
- Time range picker: segmented control (7d / 30d / 90d / all)
- Per-metric progress bars (weight + BF separately)
- "Log Metrics" CTA → opens manual biometric entry
- `.analyticsScreen(.bodyCompDetail)`
- Fire `home_body_comp_period_changed` on segment switch
- Fire `home_body_comp_log_tap` on Log CTA

### T4 — Compact macro strip sub-view (P1)
- **Type:** ui | **Skill:** dev | **Priority:** medium | **Effort:** 0.25d
- **Depends on:** —
- Inline row: icon + "142g / 180g protein" with progress bar
- Data from `todayLog?.nutritionLog` (protein consumed vs target)
- Use `AppText.caption` + `AppColor.Chart.nutritionFat`
- Can be omitted from T2 initially and added after

### T5 — Wire BodyCompositionCard into MainScreenView
- **Type:** ui | **Skill:** dev | **Priority:** critical | **Effort:** 0.25d
- **Depends on:** T2, T3
- Replace `statusCard` + `goalCard` sections in v2 MainScreenView with single `BodyCompositionCard`
- Wire `onTap` to present `BodyCompositionDetailView` sheet
- Fire `home_body_comp_tap` on tap
- Add `@State private var showBodyCompDetail = false`

### T6 — Remove old statusCard + goalCard code
- **Type:** ui | **Skill:** dev | **Priority:** high | **Effort:** 0.15d
- **Depends on:** T5
- Delete `statusCard()` and `goalCard()` private functions from v2 MainScreenView
- Delete `progressLine()` helper if no longer used
- Clean up unused computed properties if any

### T7 — Accessibility pass
- **Type:** ui | **Skill:** dev | **Priority:** critical | **Effort:** 0.25d
- **Depends on:** T5
- Card: `.accessibilityLabel` summarizing weight + BF + progress
- Card: `.accessibilityHint("Tap for details")`
- Detail view: chart text summaries via `.accessibilityValue`
- All tap targets ≥ 44pt
- Dynamic Type verified on both views

### T8 — Tests
- **Type:** test | **Skill:** qa | **Priority:** high | **Effort:** 0.5d
- **Depends on:** T1, T5
- Analytics tests: 3 events fire correctly with params, consent-gated
- Build verification: `xcodebuild build`
- Test suite: `xcodebuild test` green

### T9 — Build + CI verification
- **Type:** test | **Skill:** dev | **Priority:** critical | **Effort:** 0.25d
- **Depends on:** T5, T6, T7, T8
- Full build green
- All existing tests pass (no regressions)
- Diff review against main

---

## Summary

| Category | Tasks | Effort |
|---|---|---|
| Foundation (parallel) | T1, T2, T3, T4 | 3d |
| Assembly | T5, T6 | 0.4d |
| Verification | T7, T8, T9 | 1d |
| **Total** | **9 tasks** | **~4.4 days** |

**Critical path:** T2+T3 (parallel, 1.5d) → T5 (0.25d) → T6+T7 (parallel, 0.25d) → T8+T9 (0.5d) = **~2.5 days effective**
