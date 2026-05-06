# UX Build Prompt: Home Today Screen v2

> **Generated:** 2026-04-09
> **Feature:** home-today-screen v2 UX alignment
> **Source:** `.claude/features/home-today-screen/ux-spec.md`
> **Branch:** `feature/home-today-screen-v2`

---

## What to build

Rewrite `MainScreenView.swift` as `FitTracker/Views/Main/v2/MainScreenView.swift`. Same Swift type name, new file in `v2/` subdirectory. Build bottom-up from the design system — do NOT patch v1.

## Why

v1 is a 1029-line monolith with 27 UX Foundations violations (9 P0, 13 P1). Key issues: root GeometryReader anti-pattern, no scroll, 12 raw font sizes, 4 a11y labels for 30+ elements, no empty/loading/error states, readiness principle violated, no "Log meal" CTA.

## Stack order (top to bottom, scrollable)

1. **Toolbar** — profile + edit actions (≥44pt tap targets)
2. **Greeting** — `LiveInfoStrip` (static, no rotation). Format: `"Good morning, {name} · {streak}🔥"`. Priority: greeting+streak > greeting > streak.
3. **ReadinessCard** — existing component, promoted to hero. Tap = cycle pages.
4. **Training & Nutrition** — single inline context line (`"Lower Body · 45m · On plan"`), then side-by-side equal CTAs: Start Workout | Log Meal (8pt gap).
5. **Status** — two `AppMetricColumn` instances (weight, body fat). Temporary separate card.
6. **Goal** — `AppProgressRing` + on-track summary. Temporary separate card.
7. **Metrics** — 4x `AppMetricTile` (HRV, RHR, Sleep, Steps). Read-only, chart-color tinted.

## Key behaviors

- `ScrollView` with `.scrollBounceBehavior(.basedOnSize)` — no GeometryReader
- 5 states: default, loading (skeleton), empty (HomeEmptyStateView), error (banner + retry), success (celebration, transient)
- Empty state: "Connect Health" + "Log manually" buttons. HealthKit denied → Settings deep-link.
- Empty metric tiles: tappable "Log" CTA instead of `—` dash
- `HomeRecommendationProvider` feeds recommendation display (encouraging tone, never guilt)
- All animations: `AppSpring.snappy` / `AppEasing.short` + reduce-motion wrapped
- Haptics from v1 preserved verbatim

## Token requirements

- Fonts: all `AppText.*` — no raw `.font(.system(size:))`. New tokens if `metricHero`/`metricDisplay` don't fit: `metricL` (~28pt), `metricM` (~25pt), `iconXL` (~32pt)
- Spacing: all `AppSpacing.*`
- Sizes: all `AppSize.*` or `@ScaledMetric`; new `AppSize.indicatorDot` (8pt)
- Colors: `AppColor.Chart.weight/hrv/heartRate/activity` (new)
- Cards: `AppCard` from `AppComponents.swift` (not custom `BlendedSectionStyle`)

## Accessibility (non-negotiable)

- Every interactive element: `.accessibilityLabel` + `.accessibilityHint` where applicable
- Every metric: `.accessibilityValue` with units
- Every section title: `.accessibilityAddTraits(.isHeader)`
- All tap targets ≥ 44pt
- All fonts scale with Dynamic Type (test at AX5)
- VoiceOver reading order matches visual stack

## Analytics

- `.analyticsScreen(.home)` in view body (remove from RootTabView)
- `home_action_tap` on CTA taps (params: action_type, day_type, has_recommendation)
- `home_action_completed` on action completion (params: action_type, duration_seconds, source)
- `home_empty_state_shown` on empty state (params: empty_reason, cta_shown)
- All events consent-gated

## Files to create/modify

| Action | File |
|--------|------|
| **Create** | `FitTracker/Views/Main/v2/MainScreenView.swift` |
| **Create** | `FitTracker/Services/HomeRecommendationProvider.swift` |
| **Modify** | `FitTracker/Views/Shared/LiveInfoStrip.swift` (static behavior) |
| **Modify** | `FitTracker/Services/AppTheme.swift` (8 new tokens) |
| **Modify** | `FitTracker/DesignSystem/AppComponents.swift` (2 component promotions) |
| **Modify** | `FitTracker/Services/Analytics/AnalyticsProvider.swift` (3 events + params) |
| **Modify** | `FitTracker/Services/Analytics/AnalyticsService.swift` (convenience methods) |
| **Modify** | `FitTracker.xcodeproj/project.pbxproj` (v2 group + Sources swap) |
| **Modify** | `RootTabView.swift` (remove .analyticsScreen for Home) |
| **Mark HISTORICAL** | `FitTracker/Views/Main/MainScreenView.swift` |
