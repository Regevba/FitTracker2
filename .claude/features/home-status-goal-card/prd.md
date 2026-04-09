# PRD: Home — Status+Goal Merged Card (Body Composition Card)

> **Owner:** Regev
> **Date:** 2026-04-09
> **Phase:** Phase 1 — PRD
> **Status:** Draft for approval
> **Parent feature:** home-today-screen v2 (PR #61)
> **Tracking:** [regevba/fittracker2#64](https://github.com/Regevba/FitTracker2/issues/64)
> **Branch:** `feature/home-status-goal-card`
> **Deferred from:** F11 (goal drill-down), F13 (macro strip), OQ-3, OQ-4, OQ-7-folded

---

## Purpose

Replace the separate Status card and Goal card on Home v2 with a single unified **Body Composition Card** that shows current metrics, progress toward goals, and an optional macro strip — with a tappable drill-down to a detailed trend view. Reduces vertical fragmentation (~250pt → ~180pt) while adding more meaningful context.

## Business Objective

The Home screen is the first thing users see. Two adjacent cards showing related body-composition data (weight/BF + goal progress) fragment the story. A unified card answers "where am I vs where I want to be" in one glance, and the drill-down enables data exploration that was previously impossible (no goal detail view exists).

## Target Persona(s)

| Persona | Relevance |
|---|---|
| The Consistent Lifter | Tracks weight/BF against strength goals; wants quick visual of progress |
| Health-Conscious Professional | Monitors body composition trends; values the trend chart drill-down |
| Data-Driven Optimizer | Wants all metrics in context; drill-down feeds their need for detail |

## Has UI?

Yes — 1 new card component + 1 new detail sheet view.

## Functional Requirements

| # | Requirement | Priority | Details |
|---|---|---|---|
| 1 | Unified body-composition card on Home | P0 | Replaces both statusCard and goalCard in v2 MainScreenView |
| 2 | Hero values: weight + body fat | P0 | Large `AppText.metric` values with unit + target range below each |
| 3 | Overall progress bar | P0 | Linear progress bar showing combined goal progress (replaces `AppProgressRing`) |
| 4 | Recommendation line | P0 | `HomeRecommendationProvider` output — encouraging copy |
| 5 | Drill-down on tap | P0 | Card tap → `BodyCompositionDetailView` sheet |
| 6 | Drill-down: trend charts | P0 | Weight + BF trend lines over 7d / 30d / 90d / all with goal line overlay |
| 7 | Drill-down: per-metric progress bars | P1 | Weight progress + BF progress separately |
| 8 | Drill-down: "Log" CTA | P0 | Opens manual biometric entry from the detail view |
| 9 | Compact macro strip | P1 | Protein progress inside the card (`142g / 180g protein`) |
| 10 | Empty state | P0 | When no weight/BF data — "Log your metrics" CTA (reuses existing `onLogTap` pattern) |
| 11 | Drill-down chevron affordance | P1 | Visible `▸` indicator that the card is tappable |
| 12 | Card EYEBROW header | P0 | "BODY COMPOSITION" with `.isHeader` accessibility trait |

## Card layout

```
┌─────────────────────────────────────────────────┐
│  BODY COMPOSITION                          ▸    │
│                                                  │
│  67.2 kg        14.8%                           │
│  Weight          Body Fat                        │
│  Target: 65-68   Target: 13-15%                 │
│                                                  │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 72%  │
│                                                  │
│  🥩 142g / 180g protein                         │
│                                                  │
│  You're on track — keep going! 💪               │
└─────────────────────────────────────────────────┘
```

## Drill-down view (BodyCompositionDetailView)

```
┌──────────────────────────────────────────────────┐
│  Body Composition                        Done    │
│                                                   │
│  ┌─────────────────────────────────────────────┐ │
│  │  Weight trend chart (7d/30d/90d/all)        │ │
│  │  Current: 67.2 kg  Goal: 65-68 kg           │ │
│  │  ──────────────────── goal line ───────────  │ │
│  │  ╱╲  ╱╲                                      │ │
│  │ ╱  ╲╱  ╲───                                  │ │
│  └─────────────────────────────────────────────┘ │
│                                                   │
│  ┌─────────────────────────────────────────────┐ │
│  │  Body Fat trend chart                        │ │
│  │  Current: 14.8%  Goal: 13-15%               │ │
│  └─────────────────────────────────────────────┘ │
│                                                   │
│  Weight progress  ━━━━━━━━━━━━━━━━━━━━━━━ 85%  │
│  Body Fat progress ━━━━━━━━━━━━━━━━━━━━━━ 60%  │
│                                                   │
│  ┌────────────────────────────────────┐          │
│  │         📊 Log Metrics             │          │
│  └────────────────────────────────────┘          │
└──────────────────────────────────────────────────┘
```

## User Flows

### Primary: View body composition on Home
1. User opens app → Home shows Body Composition Card
2. Sees weight 67.2 kg, body fat 14.8%, progress 72%, encouraging message
3. Glances at macro strip (142g / 180g protein)

### Primary: Drill down for trends
1. User taps the Body Composition Card (or `▸` chevron)
2. → `home_body_comp_tap` analytics event fires
3. `BodyCompositionDetailView` sheet opens
4. User sees weight + BF trend charts with goal lines
5. Switches between time ranges (7d / 30d / 90d / all)
6. Taps "Log Metrics" → manual biometric entry sheet

### Empty state
1. No weight/BF data logged
2. Card shows "Log your first metrics" CTA instead of values
3. Tapping opens manual biometric entry

---

## Analytics Spec

### New events

| Event Name | GA4 Type | Screen/Trigger | Conversion? | Notes |
|---|---|---|---|---|
| `home_body_comp_tap` | Custom | User taps Body Composition Card | No | Drill-down engagement |
| `home_body_comp_period_changed` | Custom | User switches time range in detail view | No | Engagement depth |
| `home_body_comp_log_tap` | Custom | User taps "Log Metrics" in detail view | No | Logging intent from drill-down |

### Event parameters

#### `home_body_comp_tap`

| Parameter | Type | Allowed Values | Notes |
|---|---|---|---|
| `has_weight` | string | `true`, `false` | Whether weight data exists |
| `has_body_fat` | string | `true`, `false` | Whether BF data exists |
| `progress_percent` | int | 0-100 | Current overall goal progress |

#### `home_body_comp_period_changed`

| Parameter | Type | Allowed Values | Notes |
|---|---|---|---|
| `period` | string | `7d`, `30d`, `90d`, `all` | Selected time range |

#### `home_body_comp_log_tap`

| Parameter | Type | Allowed Values | Notes |
|---|---|---|---|
| `source` | string | `body_comp_detail` | Always from the detail view |

### New screen

| Screen Name | View Name | SwiftUI View | Category |
|---|---|---|---|
| Body Composition Detail | `body_comp_detail` | `BodyCompositionDetailView` | core |

### Naming validation checklist

- [x] All event names: snake_case, <40 chars, `home_` prefixed
- [x] All parameter names: snake_case, <40 chars
- [x] No reserved prefixes (`ga_`, `firebase_`, `google_`)
- [x] No duplicate names (checked against existing 27 events + 26 params)
- [x] No PII
- [x] ≤25 parameters per event (max 3)
- [x] Parameter values max 100 chars
- [x] Conversion events: none (drill-down is engagement, not conversion)

### Files to update

- [ ] `AnalyticsProvider.swift` — 3 events + 3 params + 1 screen
- [ ] `AnalyticsService.swift` — 3 convenience methods
- [ ] `analytics-taxonomy.csv` — 3 event rows + 1 screen row

---

## Success Metrics

### Primary metric

| Metric | Baseline | Target | Instrumentation |
|---|---|---|---|
| Body comp drill-down rate | N/A (new) | >20% of sessions include `home_body_comp_tap` | GA4 custom event |

### Secondary metrics

| Metric | Baseline | Target | Instrumentation |
|---|---|---|---|
| Biometric logging frequency | Current manual log rate | +15% increase from drill-down CTA | GA4 `biometric_log` with `source: body_comp_detail` |
| Time range exploration | N/A | >30% of drill-downs switch period | GA4 `home_body_comp_period_changed` |
| Home scroll depth | Current (unknown) | Card higher in stack → more visible | Implicit from card position |

### Guardrail metrics

| Metric | Current | Acceptable Range |
|---|---|---|
| Crash-free rate | >99.5% | Must stay >99.5% |
| Cold start time | <2s | Must stay <2s |
| Existing home_action_tap rate | Current (from Home v2) | Must not degrade |

### Leading indicators
- >20% of sessions include a body comp drill-down within 7 days
- "Log Metrics" tap rate from detail view > 10% of drill-downs

### Lagging indicators
- Biometric logging frequency increases 15%+ within 30 days
- Cross-feature WAU stable or improving

---

## Acceptance Criteria

### Card
- [ ] Unified Body Composition Card replaces both statusCard and goalCard in v2 MainScreenView
- [ ] Hero weight + body fat values with `AppText.metric` + unit + target range
- [ ] Linear progress bar showing overall goal % (replaces `AppProgressRing`)
- [ ] Compact macro strip showing protein progress (P1)
- [ ] Recommendation line from `HomeRecommendationProvider`
- [ ] `▸` chevron indicating tappability
- [ ] "BODY COMPOSITION" eyebrow with `.isHeader` trait
- [ ] Empty state: "Log your first metrics" CTA when no data
- [ ] All design system tokens — zero raw literals
- [ ] Card tappable → opens `BodyCompositionDetailView`

### Drill-down
- [ ] `BodyCompositionDetailView` opens as `.medium`/`.large` detent sheet
- [ ] Weight trend chart with goal line overlay
- [ ] Body fat trend chart with goal line overlay
- [ ] Time range picker (7d / 30d / 90d / all)
- [ ] Per-metric progress bars (weight + BF separately)
- [ ] "Log Metrics" CTA → opens manual biometric entry
- [ ] "Done" toolbar button to dismiss

### Analytics
- [ ] `home_body_comp_tap` fires on card tap
- [ ] `home_body_comp_period_changed` fires on time range switch
- [ ] `home_body_comp_log_tap` fires on Log CTA in detail view
- [ ] `.analyticsScreen(.bodyCompDetail)` on detail view
- [ ] All events consent-gated
- [ ] `analytics-taxonomy.csv` updated

### Accessibility
- [ ] Card: `.accessibilityLabel` with weight + BF + progress summary
- [ ] Card: `.accessibilityHint("Tap for details")`
- [ ] Detail view: chart has `.accessibilityValue` text summary
- [ ] All tap targets ≥ 44pt
- [ ] Dynamic Type scaling

---

## Kill Criteria

School project, loose thresholds:
- If drill-down causes crash-free rate < 99.5% → hotfix
- If card causes cold start regression > 200ms → investigate
- Otherwise: iterate, don't kill

## Review Cadence

1 week post-merge. School project — relax to 30-day if no signal.

---

## Key Files

| File | Action |
|---|---|
| `FitTracker/Views/Main/v2/MainScreenView.swift` | **Modify** — replace statusCard + goalCard with BodyCompositionCard |
| `FitTracker/Views/Main/BodyCompositionCard.swift` | **New** — unified card component |
| `FitTracker/Views/Main/BodyCompositionDetailView.swift` | **New** — drill-down sheet |
| `FitTracker/Services/Analytics/AnalyticsProvider.swift` | **Modify** — 3 events + 3 params + 1 screen |
| `FitTracker/Services/Analytics/AnalyticsService.swift` | **Modify** — 3 convenience methods |
| `docs/product/analytics-taxonomy.csv` | **Modify** — 3 event rows + 1 screen |

## Estimated Effort

| Phase | Effort |
|---|---|
| PRD (this) | 0.5 day |
| Tasks | 0.25 day |
| UX Spec | 0.5 day |
| Implementation | 3 days |
| Testing | 0.5 day |
| Review + Merge + Docs | 0.5 day |
| **Total** | **~5 days** |

---

## Dependencies & Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Trend chart needs historical data | Medium | Use existing `dataStore` biometric history; fallback to "Not enough data" message |
| Macro strip adds density | Low | P1 — can defer if card feels too dense |
| `AppProgressRing` removal may break expectations | Low | Ring was already temporary per Home v2 decisions; linear bar is more compact |
| Detail view chart rendering perf | Low | Use SwiftUI Charts (iOS 16+); lazy rendering |
