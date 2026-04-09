# PRD: Home / Today Screen — v2 UX Alignment

> **Owner:** Regev
> **Date:** 2026-04-09
> **Phase:** Phase 1 — PRD
> **Status:** Draft for approval
> **Parent:** v1 PRD `docs/product/prd/18.4-home-today-screen.md` (shipped pre-PM-workflow, backfilled 2026-04-04)
> **Trigger:** v1 shipped as a 1029-line monolith before PM workflow enforcement. Phase 0 audit (`v2-audit-report.md`) found 27 findings (9 P0, 13 P1, 5 P2) against `docs/design-system/ux-foundations.md`. This PRD scopes the v2 rewrite.
> **Tracking:** [regevba/fittracker2#60](https://github.com/Regevba/FitTracker2/issues/60)
> **Branch:** `feature/home-today-screen-v2`
> **Pilot precedent:** Onboarding v2 (PR #59) — second feature in the sequential UX alignment initiative, first to use the `v2/` subdirectory convention.

---

## v2 Purpose

Rewrite `MainScreenView.swift` from scratch as `FitTracker/Views/Main/v2/MainScreenView.swift`, building bottom-up from `ux-foundations.md` principles. The v1 functional intent (action-first Today screen answering "What should I do today?") is preserved. What changes is *how* it's expressed: layout architecture, token compliance, accessibility, state coverage, motion, and analytics.

v2 also serves as the first feature to follow the `v2/` subdirectory convention defined in CLAUDE.md, validating the pattern before it's applied to Training Plan, Nutrition, and Stats.

## v2 Scope (P0 + P1 findings)

22 findings from the Phase 0 audit are in scope. Each maps to a numbered finding in `v2-audit-report.md`.

### Architecture (3 findings)

| # | Finding | Action | Priority |
|---|---------|--------|----------|
| F1 | `GeometryReader` at root — SwiftUI anti-pattern | Delete; use `@Environment(\.horizontalSizeClass)` + Dynamic Type | P0 |
| F2 | "Above the fold, no scroll" hard constraint | Drop; use `ScrollView` with `scrollBounceBehavior(.basedOnSize)` | P1 |
| F3 | `compact`/`tight` props threaded through every helper | Delete; Dynamic Type + `AppSpacing.*` tokens handle sizing | P1 |

### Token compliance (4 findings)

| # | Finding | Action | Priority |
|---|---------|--------|----------|
| F5 | 12 raw `.font(.system(size: N))` calls | Map 9 to existing `AppText.*` tokens; introduce 3 new tokens (`metricL`, `metricM`, `iconXL`) | P1 |
| F6 | 7 raw numeric paddings | Map all to existing `AppSpacing.*` tokens | P1 |
| F7 | 11 raw numeric `.frame()` calls | Map 9 to tokens; 2 hero sizes use `@ScaledMetric` + new `AppSize.indicatorDot` (8pt) | P1 |
| F8 | Raw `Color.blue/.brown/.purple/.gray` in 4 places | Map to new `AppColor.Chart.*` tokens (weight, hrv, heartRate, activity) | P1 |

### UX principles (6 findings)

| # | Finding | Action | Priority |
|---|---------|--------|----------|
| F9 | Readiness-First principle violated | Promote existing `ReadinessCard` to first card; status demoted | P0 |
| F10 | Hick's Law: ~19+ visual elements competing | Reduce to 10-12 above fold via progressive disclosure | P1 |
| F11 | No drill-down progressive disclosure | Make metric tiles + goal ring read-only in v2 (deep-link deferred) | P1 |
| F12 | "Log meal" quick action missing | Add Log Meal as peer CTA inside renamed "Training & Nutrition" card | P0 |
| F13 | Macro progress invisible on Home | **Deferred** — ships with Status+Goal merged sub-feature | P2 (non-scope) |
| F14 | Guilt-adjacent status copy | Rewrite per Celebration Not Guilt principle (ux-foundations §1.13) | P1 |

### State coverage (2 findings)

| # | Finding | Action | Priority |
|---|---------|--------|----------|
| F15 | No explicit loading/empty/error states | Implement all 5 states: default, loading, empty, error, success | P0 |
| F16 | `—` dashes without affordance | Replace with tappable "Log" CTAs on empty metric tiles | P1 |

### Accessibility (4 findings)

| # | Finding | Action | Priority |
|---|---------|--------|----------|
| F17 | Edit button 34pt < 44pt minimum | Frame to 44pt via `AppButton.iconOnly` or `.contentShape(Rectangle())` | P0 |
| F18 | Only 4 a11y labels for ~30+ interactive elements | Label every interactive element; add hints, values, header traits | P0 |
| F19 | `.font(.system(size: N))` breaks Dynamic Type | New `AppText.metricL/M` + `iconXL` use `Font.custom(relativeTo:)` for scaling | P0 |
| F20 | `LiveInfoStrip` 5s auto-cycle hostile to VoiceOver | Remove auto-rotation entirely; static line with priority resolution | P1 |

### Motion (2 findings)

| # | Finding | Action | Priority |
|---|---------|--------|----------|
| F21 | Raw `.spring()`/`.easeOut()` calls | Map to `AppSpring.snappy` and `AppEasing.short` tokens | P1 |
| F22 | Zero reduce-motion support | Wrap every animation in `@Environment(\.accessibilityReduceMotion)` check | P0 |

### Analytics (1 finding)

| # | Finding | Action | Priority |
|---|---------|--------|----------|
| F24 | No `.analyticsScreen` inside view | Move modifier into v2 view body; remove from `RootTabView.swift` | P1 |

## v2 Non-Scope (deferred to sub-features)

These items are explicitly out of scope for this branch. Each becomes its own PM cycle post-merge.

| Item | Deferred to | Rationale |
|------|-------------|-----------|
| F11 — Goal drill-down (tap ring → detail view) | Status+Goal merged sub-feature (`home-status-goal-card`) | Requires new view + navigation plumbing |
| F13 — Compact macro strip on Home | Status+Goal merged sub-feature | Pending design details; semantically placed |
| F25 partial — `home_metric_tile_tap` event | Metric Tile Deep Linking sub-feature (`metric-tile-deep-linking`) | Event meaningless without tap handler |
| Status+Goal merged card design | Own PM cycle | v2 ships with separate v1-style cards (token + a11y fixes applied) |
| Metric tile deep-linking to Stats | Own PM cycle | Can run in parallel with Status+Goal |

### Sub-feature queue (post-merge execution order)

1. **Onboarding v2 retroactive refactor** — move existing onboarding files into `v2/` subdirectory per V2 Rule
2. **Status+Goal merged card** (`home-status-goal-card`) — includes goal drill-down + macro strip placement
3. **Metric Tile Deep Linking** (`metric-tile-deep-linking`) — can parallel #2 since they touch different files
4. **Training Plan v2** — next per-screen UX alignment

## Changelog — v1 → v2

### Layout

| Dimension | v1 | v2 |
|-----------|----|----|
| Scroll | No scroll, above-the-fold constraint | `ScrollView` with `scrollBounceBehavior(.basedOnSize)` |
| Stack order | Greeting → Status → Goal → Training → Metrics | Toolbar → Greeting → ReadinessCard → Training & Nutrition → Status → Goal → Metrics |
| Hero card | Status Overview (weight/BF) | ReadinessCard (existing component promoted) |
| Primary CTA | "Start Training" (single button) | "Training & Nutrition" (side-by-side Start Workout + Log Meal) |
| CTA context | Day type menu + session estimate + recommendation | Single inline line: `"Lower Body · 45m · On plan"` |
| Root layout | `GeometryReader` with `compact`/`tight` breakpoints | Environment size classes + Dynamic Type tokens |
| Card style | Custom `BlendedSectionStyle` ViewModifier | Existing `AppCard` from `AppComponents.swift` |

### LiveInfoStrip

| Dimension | v1 | v2 |
|-----------|----|----|
| Behavior | Auto-rotates every 5 seconds | Static, no rotation |
| Content | Cycles: greeting, readiness, streak | Priority-resolved single line |
| Format | One signal at a time | Concatenated: `"Good morning, Regev · 3-day streak 🔥"` |
| Streak threshold | `≥3 days` | `≥3 days` (unchanged) |
| VoiceOver | Hostile (auto-cycling) | Accessible (static) |

### Architecture

| Dimension | v1 | v2 |
|-----------|----|----|
| Recommendation logic | Embedded in view (~50 lines) | Extracted to `HomeRecommendationProvider` service |
| Private helpers | `statusValueColumn`, `metricTile` (private) | Promoted to `AppMetricColumn`, `AppMetricTile` in `AppComponents.swift` |
| File | `FitTracker/Views/Main/MainScreenView.swift` | `FitTracker/Views/Main/v2/MainScreenView.swift` |
| v1 fate | Active in build | Removed from Sources build phase; marked HISTORICAL |

### Design system

| Category | v1 (violations) | v2 (compliant) |
|----------|-----------------|----------------|
| Fonts | 12 raw `.system(size: N)` | All mapped to `AppText.*` tokens (9 existing + 3 new) |
| Paddings | 7 raw literals | All mapped to `AppSpacing.*` tokens |
| Frames | 11 raw literals | 9 mapped to tokens; 2 via `@ScaledMetric` |
| Colors | 4 raw `Color.blue/.brown` etc. | All mapped to `AppColor.Chart.*` tokens |
| Motion | Raw `.spring()`/`.easeOut()` | `AppSpring.snappy` / `AppEasing.short` |
| Reduce motion | None | Every animation wrapped in reduce-motion check |
| A11y labels | 4 total | ~30+ (every interactive element) |
| Tap targets | 34pt edit button | All ≥44pt |
| Dynamic Type | Broken (fixed font sizes) | All fonts scale via `relativeTo:` |
| States | Implicit (dashes for missing) | Explicit: default / loading / empty / error / success |

### New tokens (landed with this feature)

| Token | Type | Value | Finding |
|-------|------|-------|---------|
| `AppText.metricL` | Font | ~28pt rounded bold, `relativeTo: .largeTitle` | F5 |
| `AppText.metricM` | Font | ~25pt rounded bold, `relativeTo: .title` | F5 |
| `AppText.iconXL` | Font | ~32pt medium | F5 |
| `AppSize.indicatorDot` | CGFloat | 8pt | F7 |
| `AppColor.Chart.weight` | Color | TBD in Phase 3 | F8 |
| `AppColor.Chart.hrv` | Color | TBD in Phase 3 | F8 |
| `AppColor.Chart.heartRate` | Color | Verify if exists in `AppTheme.swift` | F8 |
| `AppColor.Chart.activity` | Color | TBD in Phase 3 | F8 |

### New components (promoted with this feature)

| Component | Source | Description | Finding |
|-----------|--------|-------------|---------|
| `AppMetricColumn` | `MainScreenView:468-512` | Weight/BF column: icon + title, value + unit, target, missing-state | F26 |
| `AppMetricTile` | `MainScreenView:538-555` | Generic metric: icon + value + label | F26 |

### New service

| Service | Purpose | Finding |
|---------|---------|---------|
| `HomeRecommendationProvider` | Readiness → copy/color/tone mapping. View consumes a single struct. | F27 |

---

## Analytics Spec

### Screen-prefix rule

All events follow the project-wide screen-prefix convention (established 2026-04-08, documented in CLAUDE.md). Every Home screen event starts with `home_`.

### New events

| Event Name | GA4 Type | Screen/Trigger | Conversion? | Notes |
|------------|----------|----------------|-------------|-------|
| `home_action_tap` | Custom | User taps Start Workout or Log Meal CTA | No | Primary engagement signal |
| `home_action_completed` | Custom | User completes the action started from Home | Yes | Measures follow-through |
| `home_empty_state_shown` | Custom | Empty state view appears on Home | No | Monitors data availability |
| `home_metric_tile_tap` | Custom | User taps a metric tile | No | **Deferred** — ships with Metric Tile Deep Linking sub-feature |

### Event parameters

#### `home_action_tap`

| Parameter | Type | Allowed Values | Notes |
|-----------|------|----------------|-------|
| `action_type` | string | `start_workout`, `log_meal` | Which CTA was tapped |
| `day_type` | string | `push`, `pull`, `legs`, `upper`, `lower`, `cardio`, `rest`, `custom` | Current training day context |
| `has_recommendation` | string | `true`, `false` | Whether readiness recommendation was shown |

#### `home_action_completed`

| Parameter | Type | Allowed Values | Notes |
|-----------|------|----------------|-------|
| `action_type` | string | `start_workout`, `log_meal` | Which action was completed |
| `duration_seconds` | int | 0-86400 | Time from tap to completion. SI unit: seconds |
| `source` | string | `home` | Always `home` — distinguishes from other entry points |

#### `home_empty_state_shown`

| Parameter | Type | Allowed Values | Notes |
|-----------|------|----------------|-------|
| `empty_reason` | string | `no_healthkit`, `no_data`, `first_launch` | Why the empty state appeared |
| `cta_shown` | string | `connect_health`, `log_manually`, `both` | Which recovery CTAs were displayed |

#### `home_metric_tile_tap` (deferred)

| Parameter | Type | Allowed Values | Notes |
|-----------|------|----------------|-------|
| `metric_type` | string | `hrv`, `rhr`, `sleep`, `steps` | Which tile was tapped |
| `has_value` | string | `true`, `false` | Whether the tile had data |

### Naming validation checklist

- [x] All event names: snake_case, <40 chars, `home_` prefixed
- [x] All parameter names: snake_case, <40 chars
- [x] No reserved prefixes (`ga_`, `firebase_`, `google_`)
- [x] No duplicate names (checked against `AnalyticsProvider.swift` + `analytics-taxonomy.csv`)
- [x] No PII in any parameter
- [x] ≤25 parameters per event (max 3 per event)
- [x] Parameter values spec'd to max 100 chars
- [x] Conversion events identified: `home_action_completed`

### Files to update during implementation

- [ ] `FitTracker/Services/Analytics/AnalyticsProvider.swift` — add 3 events (4th deferred), params, update screen enum
- [ ] `FitTracker/Services/Analytics/AnalyticsService.swift` — add typed convenience methods
- [ ] `docs/product/analytics-taxonomy.csv` — add rows to events section
- [ ] `RootTabView.swift` — remove `.analyticsScreen` from Home tab (moved into v2 view)

### Baseline + collection

Per OQ-20: analytics events ship together with the v2 layout. Baseline = day Home v2 merges to main. No pre-collection period. School project context — no historical baseline to compare against.

---

## Success Metrics

### Primary metric

| Metric | Baseline | Target | Instrumentation |
|--------|----------|--------|-----------------|
| Sessions per day | No pre-v2 baseline (school project) | 1.5+ | GA4 `session_start` (auto-collected) |

### Secondary metrics

| Metric | Baseline | Target | Instrumentation |
|--------|----------|--------|-----------------|
| Home action tap rate | N/A (new event) | >30% of sessions include ≥1 `home_action_tap` | GA4 `home_action_tap` |
| Home action completion rate | N/A (new event) | >50% of `home_action_tap` lead to `home_action_completed` | GA4 funnel |
| Readiness check-in rate | — | >40% daily (from v1 PRD) | GA4 `screen_view: readiness` |
| Empty state occurrence rate | N/A (new event) | <20% of sessions show `home_empty_state_shown` | GA4 `home_empty_state_shown` |

### Guardrail metrics

| Metric | Current | Acceptable Range | Source |
|--------|---------|------------------|--------|
| Crash-free rate | >99.5% | Must stay >99.5% | Firebase Crashlytics |
| Cold start time | <2s | Must stay <2s | Manual profiling |
| Sync success rate | >99% | Must stay >99% | SupabaseSyncService logs |
| CI pass rate | >95% | Must stay >95% | GitHub Actions |

### Leading indicators

- >30% of sessions include at least one `home_action_tap` within first 7 days
- Empty state shown in <20% of sessions (indicates HealthKit + manual logging are working)
- No crash-free rate regression after merge

### Lagging indicators

- Cross-feature WAU (North Star) trending up or flat post-merge
- Sessions per day ≥1.5 after 30 days

---

## Acceptance Criteria

### Architecture

- [ ] v2 file at `FitTracker/Views/Main/v2/MainScreenView.swift` builds and renders
- [ ] `project.pbxproj` updated: v2 added to Sources build phase, v1 removed from Sources (PBXFileReference retained)
- [ ] v1 file has HISTORICAL header comment per CLAUDE.md template
- [ ] No `GeometryReader` at root level
- [ ] No `compact`/`tight` parameters in any helper
- [ ] `ScrollView` with `scrollBounceBehavior(.basedOnSize)` wraps content
- [ ] `HomeRecommendationProvider` service extracted to separate file

### Layout + UX

- [ ] Stack order: Toolbar → Greeting → ReadinessCard → Training & Nutrition → Status → Goal → Metrics
- [ ] `ReadinessCard` is the first card (hero position)
- [ ] "Training & Nutrition" card has side-by-side equal CTAs (Start Workout + Log Meal)
- [ ] Context row shows single inline line: day type + estimated session + recommendation tone
- [ ] LiveInfoStrip is static (no auto-rotation), concatenates greeting + streak
- [ ] Status and Goal render as separate cards with v2 tokens + a11y fixes
- [ ] Metrics row shows 4 read-only tiles (HRV, RHR, Sleep, Steps)
- [ ] Guilt-adjacent copy replaced with encouraging language

### Token compliance

- [ ] Zero raw `.font(.system(size: N))` calls — all use `AppText.*` tokens
- [ ] Zero raw numeric paddings — all use `AppSpacing.*` tokens
- [ ] Zero raw numeric frames (except `@ScaledMetric` hero sizes) — all use `AppSize.*` tokens
- [ ] Zero raw `Color.*` literals — all use `AppColor.*` tokens
- [ ] New tokens (`metricL`, `metricM`, `iconXL`, `indicatorDot`, `Chart.*`) defined in `AppTheme.swift`
- [ ] `AppMetricColumn` and `AppMetricTile` promoted to `AppComponents.swift`

### Accessibility

- [ ] Every interactive element has `.accessibilityLabel`
- [ ] Every non-trivial action has `.accessibilityHint`
- [ ] Every metric tile has `.accessibilityValue` with units
- [ ] Every section eyebrow has `.accessibilityAddTraits(.isHeader)`
- [ ] All tap targets ≥44pt
- [ ] All fonts scale with Dynamic Type (tested at AX5 in Phase 5)

### State coverage

- [ ] 5 explicit states rendered: default, loading, empty, error, success
- [ ] Empty state shows "Connect Health" + "Log manually" buttons
- [ ] "Connect Health" deep-links to Settings → Privacy → Health → FitMe when HealthKit denied
- [ ] Empty metric tiles show tappable "Log" CTAs (not `—` dashes)

### Motion

- [ ] All animations use `AppSpring.*` / `AppEasing.*` tokens
- [ ] Every animation wrapped in `@Environment(\.accessibilityReduceMotion)` check
- [ ] Scale effects degrade to opacity fades when reduce-motion enabled
- [ ] Haptics preserved from v1 (`performHomeAction()` carries over)

### Analytics

- [ ] `.analyticsScreen(AnalyticsScreen.home)` in v2 view body
- [ ] `.analyticsScreen` removed from `RootTabView.swift` for Home tab
- [ ] `home_action_tap` fires on Start Workout and Log Meal taps
- [ ] `home_action_completed` fires on action completion
- [ ] `home_empty_state_shown` fires when empty state appears
- [ ] All events respect consent gating
- [ ] `analytics-taxonomy.csv` updated with new event rows

### V2 refactor checklist

- [ ] `docs/design-system/v2-refactor-checklist.md` walked through Sections A-K
- [ ] `state.json` `phases.ux_or_integration.checklist_completed = true`

---

## Kill Criteria

**Context:** School project with no production users. Kill criteria exist to practice the rollback mechanics, not protect revenue.

| Condition | Action |
|-----------|--------|
| Crash-free rate drops below 99.5% after merge | Hotfix on v2 file within 24 hours |
| Cold start regresses >200ms after merge | Investigate; hotfix if attributable to v2 |
| Any readiness/biometric flow regresses (manual test) | Hotfix on v2 file |
| Multiple issues compound (≥2 of the above) | Swap `project.pbxproj` back to v1 (one-commit revert per V2 Rule) |

**Rollback procedure:** One commit that reverts the `project.pbxproj` Sources build phase change (re-adds v1, removes v2). v2 file stays in repo for debugging. Per CLAUDE.md V2 Rule.

---

## Review Cadence

- **1 week post-merge:** Check crash-free rate, cold start, analytics events firing. If no signal (school project), can relax to 30-day or skip.
- **Phase-gate reviews:** After each PM workflow phase per `/pm-workflow` skill.

---

## Testing Strategy

| Test type | Target | Coverage |
|-----------|--------|----------|
| Behavior tests | `HomeRecommendationProvider` | Readiness → recommendation mapping (all readiness levels, edge cases) |
| Snapshot tests | v2 `MainScreenView` | 5 states: default, loading, empty, error, success |
| Manual verification | Full flow | Verify stack order, CTAs, LiveInfoStrip, a11y with VoiceOver, Dynamic Type at AX5, reduce-motion |
| CI | Build + test | `make tokens-check` + `xcodebuild build` + `xcodebuild test` all green |

---

## Dependencies & Risks

| Dependency/Risk | Impact | Mitigation |
|----------------|--------|------------|
| `ReadinessCard` component may need adaptation for hero position | Medium | Component already handles loading/empty; test at hero size |
| `AppTheme.swift` changes (8 new tokens) touch high-risk file | Medium | Additive only (new tokens); no existing token changes |
| `AppComponents.swift` changes (2 promotions) touch shared file | Medium | Additive only; existing components untouched |
| `project.pbxproj` surgery (add v2 group, remove v1 from Sources) | High | Single commit; revertible per V2 Rule |
| iOS hardening branch (`claude/fix-ios-signin-compilation-6kxKG`) may conflict | Low | Independent branches, no shared files. Whichever merges first wins (OQ-8) |
| Phase 3 UX spec may surface additional findings | Low | P2 items already identified as deferrable |

---

## Estimated Effort

| Phase | Effort | Notes |
|-------|--------|-------|
| Phase 1 — PRD (this) | 0.5 day | Done |
| Phase 2 — Tasks | 0.25 day | Break P0+P1 into dependency graph |
| Phase 3 — UX Spec | 1 day | `/ux spec`, compliance gateway, Figma |
| Phase 4 — Implementation | 4-5 days | P0 (~4.6d) + P1 (~3.6d) overlap significantly |
| Phase 5 — Testing | 1 day | Behavior + snapshot + manual + CI |
| Phase 6 — Review | 0.5 day | Code review, diff against main |
| Phase 7 — Merge | 0.25 day | PR + CI green on both branches |
| Phase 8 — Docs | 0.25 day | Feature memory, CHANGELOG, showcase |
| **Total** | **~8-9 days** | P0+P1 scope only |

---

## Key Files

| File | Purpose |
|------|---------|
| `FitTracker/Views/Main/MainScreenView.swift` | v1 — becomes HISTORICAL |
| `FitTracker/Views/Main/v2/MainScreenView.swift` | v2 — new file, source of truth |
| `FitTracker/Views/Shared/ReadinessCard.swift` | Promoted to hero position |
| `FitTracker/Views/Shared/LiveInfoStrip.swift` | Modified: static behavior |
| `FitTracker/Services/HomeRecommendationProvider.swift` | New: recommendation logic extraction |
| `FitTracker/Services/AppTheme.swift` | Modified: 8 new tokens |
| `FitTracker/DesignSystem/AppComponents.swift` | Modified: 2 component promotions |
| `FitTracker/Services/Analytics/AnalyticsProvider.swift` | Modified: 3 new events + params |
| `FitTracker/Services/Analytics/AnalyticsService.swift` | Modified: convenience methods |
| `FitTracker.xcodeproj/project.pbxproj` | Modified: v2 group + Sources swap |
| `RootTabView.swift` | Modified: remove `.analyticsScreen` for Home |

---

## Inputs (references)

| File | Role |
|------|------|
| `.claude/features/home-today-screen/v2-audit-report.md` | Phase 0 audit (27 findings + Decisions Log) |
| `docs/design-system/ux-foundations.md` | Compliance target (13 principles) |
| `docs/design-system/v2-refactor-checklist.md` | Phase 3-5 verification |
| `docs/design-system/feature-memory.md` | Pending DS Evolution Queue |
| `docs/product/prd/18.4-home-today-screen.md` | v1 PRD (backfill) |
| `docs/product/analytics-taxonomy.csv` | Event naming source of truth |
| `docs/product/metrics-framework.md` | Metric definitions + targets |
| `FitTracker/Services/AppTheme.swift` | Token source of truth |
| `FitTracker/DesignSystem/AppComponents.swift` | Component source of truth |
| `FitTracker/Views/Main/MainScreenView.swift` | v1 source (1029 lines) |
