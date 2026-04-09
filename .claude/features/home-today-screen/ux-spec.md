# Home Today Screen v2 — UX Spec

> **Phase:** 3c (UX Spec)
> **Input:** ux-research.md, v2-audit-report.md, prd.md, Decisions Log
> **Checklist reference:** `docs/design-system/v2-refactor-checklist.md` Sections A-K
> **Target file:** `FitTracker/Views/Main/v2/MainScreenView.swift`

---

## 1. Screen List

Home v2 is a single screen (`MainScreenView`) composed of 7 sections in a scrollable stack.

| # | Section | Component | Source |
|---|---------|-----------|--------|
| 1 | Toolbar | Navigation bar with profile + edit actions | v1 carry-over, tokens updated |
| 2 | Greeting line | `LiveInfoStrip` (modified: static) | T9 — no auto-rotation |
| 3 | Readiness hero | `ReadinessCard` (existing shared component) | Promoted from unused (F9) |
| 4 | Training & Nutrition | New card: context row + 2 CTAs | New in v2 (F12, OQ-1/2/15/16) |
| 5 | Status card | Weight + body fat display | v1 carry-over, tokens updated |
| 6 | Goal card | Circular progress + on-track summary | v1 carry-over, tokens updated |
| 7 | Metrics row | 4x `AppMetricTile` (HRV, RHR, Sleep, Steps) | Component promotion (F26) |

---

## 2. Layout Architecture

```
NavigationView {
  ScrollView(.vertical, showsIndicators: false) {
    VStack(spacing: AppSpacing.medium) {
      // 1. Toolbar (via .toolbar modifier)
      // 2. Greeting
      LiveInfoStrip(...)
        .padding(.horizontal, AppSpacing.medium)

      // 3. Readiness hero
      ReadinessCard(...)
        .padding(.horizontal, AppSpacing.medium)

      // 4. Training & Nutrition
      TrainingNutritionCard(...)
        .padding(.horizontal, AppSpacing.medium)

      // 5. Status
      StatusCard(...)
        .padding(.horizontal, AppSpacing.medium)

      // 6. Goal
      GoalCard(...)
        .padding(.horizontal, AppSpacing.medium)

      // 7. Metrics
      MetricsRow(...)
        .padding(.horizontal, AppSpacing.medium)
    }
    .padding(.vertical, AppSpacing.small)
  }
  .scrollBounceBehavior(.basedOnSize)
  .analyticsScreen(AnalyticsScreen.home)
}
```

**Key architectural decisions:**
- No `GeometryReader` at root (F1)
- No `compact`/`tight` parameters (F3)
- `@Environment(\.horizontalSizeClass)` for device class if needed
- Dynamic Type handles all sizing via `AppText.*` tokens

---

## 3. Component Inventory

### Existing components reused

| Component | Location | Usage |
|-----------|----------|-------|
| `ReadinessCard` | `Views/Shared/ReadinessCard.swift` | Section 3 — hero card |
| `LiveInfoStrip` | `Views/Shared/LiveInfoStrip.swift` | Section 2 — modified to static |
| `AppCard` | `DesignSystem/AppComponents.swift` or `Views/Shared/` | Wraps sections 4-7 |
| `AppProgressRing` | `DesignSystem/AppComponents.swift` | Goal card circular indicator |

### New components (promoted in this feature)

| Component | Target location | Description |
|-----------|----------------|-------------|
| `AppMetricColumn` | `DesignSystem/AppComponents.swift` | Weight/BF column: icon + title, value + unit, target, empty-state |
| `AppMetricTile` | `DesignSystem/AppComponents.swift` | Generic metric: icon + value + label, chart color tint, empty-state |

### New service

| Service | Target location | Description |
|---------|----------------|-------------|
| `HomeRecommendationProvider` | `Services/HomeRecommendationProvider.swift` | Readiness → recommendation struct (tone, title, subtitle, accent) |

### Private sub-views (within v2 MainScreenView)

| Sub-view | Description |
|----------|-------------|
| `TrainingNutritionCard` | Context row + side-by-side Start Workout / Log Meal CTAs |
| `StatusCard` | Weight + body fat `AppMetricColumn` pair (temporary — merged sub-feature later) |
| `GoalCard` | Circular progress ring + on-track summary (temporary) |
| `MetricsRow` | HStack of 4 `AppMetricTile` instances |
| `HomeEmptyStateView` | "Connect Health" + "Log manually" buttons |

---

## 4. Token Map

### Typography

| Element | v1 (raw) | v2 (token) | Notes |
|---------|----------|------------|-------|
| Greeting date | `.system(size: 16.5, .medium, .rounded)` | `AppText.subheading` | Existing token |
| Day count | `.system(size: 13, .bold, .rounded)` | `AppText.captionStrong` | Existing token |
| Phase badge | `.system(size: 12, .semibold, .rounded)` | `AppText.eyebrow` | Existing token |
| Goal percentage | `.system(size: 28, .bold, .rounded)` | `AppText.metricHero` or new `metricL` | Verify if `metricHero` fits; else add `metricL` (~28pt, `relativeTo: .largeTitle`) |
| Primary action icon | `.system(size: 32, .bold)` | New `AppText.iconXL` or existing `iconHero` | Verify; ~32pt medium |
| Primary action title | `.system(size: 19.5, .bold, .rounded)` | `AppText.titleMedium` | Existing token |
| Day type menu | `.system(size: 15.5, .medium, .rounded)` | `AppText.callout` | Existing token |
| Status value | `.system(size: 25, .bold, .rounded)` | `AppText.metricDisplay` or new `metricM` | Verify if `metricDisplay` fits; else add `metricM` (~25pt, `relativeTo: .title`) |
| Progress title/% | `.system(size: 16, .medium, .rounded)` | `AppText.body` | Existing token |
| Metric tile icon | `.system(size: 18, .semibold)` | `AppText.iconMedium` | Existing token |
| Metric tile value | `.system(size: 19, .bold, .rounded)` | `AppText.metricCompact` | Existing token |

### Spacing

| Element | v1 (raw) | v2 (token) |
|---------|----------|------------|
| Card internal padding | `tight ? 9 : 11` | `AppSpacing.small` (10pt) |
| Card gap | `tight ? 5 : 6` | `AppSpacing.xxSmall` (6pt) |
| Metric tile vertical padding | `compact ? 7 : 9` | `AppSpacing.xSmall` (8pt) |
| Screen edge padding | `width <= 390 ? 18 : 20` | `AppSpacing.medium` (16pt) |
| CTA gap (Start Workout / Log Meal) | — | `AppSpacing.xSmall` (8pt) |

### Sizes

| Element | v1 (raw) | v2 (token) |
|---------|----------|------------|
| Goal progress ring | Dynamic based on `compact` | `@ScaledMetric` based, ~120pt default |
| Primary action button | Dynamic based on `compact` | `@ScaledMetric` based, ~56pt default |
| Status indicator dot | hardcoded | New `AppSize.indicatorDot` (8pt) |
| Tap targets | Some 34pt | All ≥ `AppSize.touchTargetLarge` (44pt) |

### Colors

| Element | v1 (raw) | v2 (token) |
|---------|----------|------------|
| Weight metric | `Color.blue` | New `AppColor.Chart.weight` |
| HRV metric | `Color.purple` | New `AppColor.Chart.hrv` |
| Resting HR metric | `Color.brown` | New `AppColor.Chart.heartRate` |
| Steps metric | `Color.gray` | New `AppColor.Chart.activity` |

### Motion

| Animation | v1 (raw) | v2 (token) | Reduce-motion fallback |
|-----------|----------|------------|----------------------|
| Card appear | `.spring(response: 0.32, ...)` | `AppSpring.snappy` | Opacity fade only |
| Status pulse | `.easeOut(duration: 0.22)` | `AppEasing.short` | No animation |
| Milestone modal | `.spring(...)` | `AppSpring.bouncy` | Opacity fade only |
| LiveInfoStrip cycle | 5s timer auto-rotate | **Removed** — static | N/A |

---

## 5. State Matrix

| State | Trigger | Visual | CTA | Analytics |
|-------|---------|--------|-----|-----------|
| **Default** | Data loaded, readiness + metrics available | Full stack rendered | Start Workout, Log Meal | — |
| **Loading** | App launch, data fetching | Skeleton placeholders in card areas | Disabled | — |
| **Empty** | No HealthKit data AND no manual entries | `HomeEmptyStateView`: message + "Connect Health" + "Log manually" | Connect Health, Log manually | `home_empty_state_shown` |
| **Error** | Network/sync failure | Error banner with retry | Retry | — |
| **Success** | Action completed (transient, 2s) | Celebration animation (haptic + visual) | — | `home_action_completed` |

### Per-section empty states

| Section | Empty behavior | Affordance |
|---------|---------------|------------|
| ReadinessCard | Shows "No readiness data" with connect prompt | Existing component handles this |
| Status (weight/BF) | `AppMetricColumn` empty variant: "Log" CTA instead of `—` | Tappable → biometrics entry |
| Goal | Shows 0% with encouraging copy | "Set your goals" CTA |
| Metric tiles | `AppMetricTile` empty variant: "Log" CTA instead of `—` | Tappable → relevant entry screen |

---

## 6. Interaction Flows

### Primary flow: Start Workout from Home
1. User sees Home with ReadinessCard showing recovery status
2. Scrolls to Training & Nutrition card
3. Reads context: `"Lower Body · 45m · On plan"`
4. Taps "Start Workout"
5. → `home_action_tap` fires with `action_type: start_workout`
6. Navigates to Active Workout screen
7. On completion → `home_action_completed` fires

### Primary flow: Log Meal from Home
1. User sees Training & Nutrition card
2. Taps "Log Meal"
3. → `home_action_tap` fires with `action_type: log_meal`
4. Navigates to Meal Entry sheet
5. On save → `home_action_completed` fires

### Empty state flow
1. New user opens app (no HealthKit, no manual data)
2. Home shows `HomeEmptyStateView`
3. → `home_empty_state_shown` fires with `empty_reason: first_launch`
4. User taps "Connect Health" → Settings deep-link (if denied) or HealthKit prompt
5. OR user taps "Log manually" → Biometrics entry

### ReadinessCard interaction
1. User taps ReadinessCard
2. Card cycles to next page (existing 6-page behavior)
3. No new view, no sheet (OQ-12)

---

## 7. Accessibility Contract

### Labels (minimum set — ~30+ elements)

| Element | Label | Hint | Value | Traits |
|---------|-------|------|-------|--------|
| Greeting line | `"{greeting text}"` | — | — | `.isStaticText` |
| ReadinessCard | `"Readiness: {score}"` | `"Tap to see more details"` | `"{score} out of 100"` | — |
| Start Workout CTA | `"Start workout"` | `"Begins {day_type} training session"` | — | `.isButton` |
| Log Meal CTA | `"Log meal"` | `"Opens meal entry"` | — | `.isButton` |
| Status: Weight | `"Current weight"` | `"Tap to log weight"` (if empty) | `"{value} {unit}"` | — |
| Status: Body Fat | `"Body fat percentage"` | `"Tap to log body fat"` (if empty) | `"{value} percent"` | — |
| Goal ring | `"Goal progress"` | — | `"{percent} percent complete"` | — |
| Metric tile (each) | `"{metric_name}"` | — | `"{value} {unit}"` | — |
| Edit button | `"Edit"` | `"Edit home screen"` | — | `.isButton` |
| Section titles | `"{title}"` | — | — | `.isHeader` |
| Empty state message | `"{message}"` | — | — | `.isStaticText` |
| Connect Health button | `"Connect Health"` | `"Opens Health settings"` | — | `.isButton` |
| Log manually button | `"Log manually"` | `"Opens manual entry"` | — | `.isButton` |

### Dynamic Type scaling

All fonts use `AppText.*` tokens built on `Font.custom(relativeTo:)`. New tokens (`metricL`, `metricM`, `iconXL`) use `.largeTitle` or `.title` as relative targets.

**Testing requirement:** Render at AX5 (largest accessibility size) in Phase 5. All content must remain readable and tappable.

### Tap targets

Every interactive element: ≥ 44x44pt via frame expansion + `.contentShape(Rectangle())` where the visual element is smaller.

### VoiceOver reading order

Top-to-bottom matches visual stack:
1. Toolbar (profile, edit)
2. Greeting
3. ReadinessCard (grouped as single element with value)
4. Training & Nutrition (context line, then CTAs left-to-right)
5. Status (weight column, then body fat column)
6. Goal (ring value, then summary)
7. Metrics (4 tiles left-to-right)

---

## 8. Analytics Mapping

| Interaction | Event | Params | Finding |
|-------------|-------|--------|---------|
| Screen appears | `.analyticsScreen(.home)` | — | F24 |
| Tap Start Workout | `home_action_tap` | `action_type: start_workout, day_type, has_recommendation` | F25 |
| Tap Log Meal | `home_action_tap` | `action_type: log_meal, day_type, has_recommendation` | F25 |
| Action completed | `home_action_completed` | `action_type, duration_seconds, source: home` | F25 |
| Empty state shown | `home_empty_state_shown` | `empty_reason, cta_shown` | F15/F25 |

---

## 9. V2 Refactor Checklist Cross-Reference

| Checklist Section | Addressed by |
|-------------------|-------------|
| A — Audit & spec | v2-audit-report.md (Phase 0), this ux-spec.md (Phase 3) |
| B — File convention | T12 (pbxproj swap), T13 (HISTORICAL header) |
| C — Token compliance | Token Map (§4 above), tasks T1/T2/T3 |
| D — Component reuse | Component Inventory (§3 above), tasks T4/T5 |
| E — UX principles | ux-research.md maps all 13 principles |
| F — State coverage | State Matrix (§5 above), task T10 |
| G — Accessibility | Accessibility Contract (§7 above), task T11 |
| H — Motion | Motion tokens in §4, task T2 |
| I — Analytics | Analytics Mapping (§8 above), tasks T7/T17 |
| J — Build & test | Tasks T14/T15/T16/T17 |
| K — Documentation | Phase 8 deliverables |
