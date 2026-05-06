# Design Build Prompt: Home Today Screen v2

> **Generated:** 2026-04-09
> **Feature:** home-today-screen v2 UX alignment
> **Source:** `.claude/features/home-today-screen/ux-spec.md`
> **Companion:** `2026-04-09-home-today-screen-ux-build.md` (the what-and-why)

---

## Visual specification

### Overall layout

- Full-width scrollable card stack
- Background: app standard (appBlue1 → appBlue2 gradient already landed on hardening branch)
- Card containers: `AppCard` with standard radius + shadow
- Card spacing: `AppSpacing.medium` (16pt) horizontal padding, `AppSpacing.medium` vertical gaps
- Content insets: `AppSpacing.small` (10pt) top/bottom padding within scroll

### Section 1: Toolbar
- Standard `NavigationView` toolbar
- Leading: profile icon (44pt touch target)
- Trailing: edit icon (44pt touch target — was 34pt in v1, must fix)

### Section 2: Greeting line (LiveInfoStrip)
- Single static text line, no animation/rotation
- Font: `AppText.subheading`
- Format: `"Good morning, {name} · {streak}🔥"` when both apply
- Truncation: `.lineLimit(1)` with graceful tail truncation on small devices

### Section 3: ReadinessCard (hero)
- Existing component, unchanged visually
- Positioned as first card below greeting
- Tap → cycle through 6 pages (existing behavior)

### Section 4: Training & Nutrition card
```
┌──────────────────────────────────────────────────┐
│ Lower Body · 45m · On plan                        │  ← AppText.callout, single line
│                                                    │
│  ┌──────────────────┐  ┌──────────────────┐      │
│  │  🏋️ Start Workout │  │  🍽️ Log Meal     │      │  ← Equal-width, AppSpacing.xSmall gap
│  └──────────────────┘  └──────────────────┘      │
└──────────────────────────────────────────────────┘
```
- Context row: `AppText.callout`, secondary text color
- CTAs: equal width, `AppSize.ctaHeight` (48pt), filled style, primary accent
- Gap between CTAs: `AppSpacing.xSmall` (8pt)
- Recommendation tone feeds from `HomeRecommendationProvider`

### Section 5: Status card (temporary)
- Two `AppMetricColumn` side by side
- Left: Weight (icon + current + target + trend)
- Right: Body Fat (icon + current + target + trend)
- Empty variant: "Log" CTA button instead of value
- Color tints: `AppColor.Chart.weight`, `AppColor.Chart.body`

### Section 6: Goal card (temporary)
- `AppProgressRing` centered, ~120pt default diameter (`@ScaledMetric`)
- Percentage label inside ring: `AppText.metricHero` (or new `metricL`)
- Summary text below: on-track / behind / ahead
- Encouraging copy, never guilt-adjacent

### Section 7: Metrics row
- HStack of 4 `AppMetricTile` instances with equal width
- Each tile: icon (tinted) + value + label
- Tints: `AppColor.Chart.hrv`, `Chart.heartRate`, `Chart.sleep`, `Chart.activity`
- Empty variant: "—" replaced with small "Log" text CTA
- Read-only (no tap handler in v2)

### Empty state (full screen replacement)
- Shown when no data at all (no HealthKit + no manual entries)
- Centered vertically in scroll area
- Illustration or icon (subtle, not hero-sized)
- Message: encouraging, explaining value of connecting health data
- Two buttons stacked vertically:
  - "Connect Health" (primary style)
  - "Log manually" (secondary/outline style)

### Motion

| Animation | Token | Duration | Reduce-motion fallback |
|-----------|-------|----------|----------------------|
| Card entrance | `AppSpring.snappy` | ~0.32s | Opacity fade 0→1 |
| Status pulse | `AppEasing.short` | ~0.22s | No animation |
| CTA press | Scale 0.97 + haptic | instant | Haptic only |
| Success celebration | `AppSpring.bouncy` | ~0.4s | Opacity fade |

### Design system evolution (new primitives)

**New tokens to add to `AppTheme.swift`:**
- `AppText.metricL` — 28pt SF Pro Rounded bold, `relativeTo: .largeTitle`
- `AppText.metricM` — 25pt SF Pro Rounded bold, `relativeTo: .title`
- `AppText.iconXL` — 32pt SF Pro medium
- `AppSize.indicatorDot` — 8pt CGFloat
- `AppColor.Chart.weight` — semantic color for weight data
- `AppColor.Chart.hrv` — semantic color for HRV data
- `AppColor.Chart.heartRate` — semantic color for heart rate data
- `AppColor.Chart.activity` — semantic color for activity/steps data
- `AppSpring.snappy` — spring with response ~0.32, damping ~0.82
- `AppEasing.short` — easeOut with duration ~0.22
- `motionSafe` ViewModifier — wraps animation in reduce-motion check

**New components to add to `AppComponents.swift`:**
- `AppMetricColumn` — icon + title, value + unit, target line, empty-state CTA
- `AppMetricTile` — icon + value + label, chart color tint, empty-state CTA
