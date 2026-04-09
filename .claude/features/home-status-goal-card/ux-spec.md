# home-status-goal-card — UX Spec

> **Phase:** 3 (UX)
> **Input:** research.md, prd.md, Home v2 ux-spec.md
> **Parent:** Inherits all UX foundations compliance from home-today-screen v2

---

## 1. Components

### BodyCompositionCard (new)

**Location:** `FitTracker/Views/Main/BodyCompositionCard.swift`

```
┌─────────────────────────────────────────────────┐
│  BODY COMPOSITION                          ▸    │  ← AppText.eyebrow + SF Symbol chevron.right
│                                                  │
│  67.2 kg        14.8%                           │  ← AppText.metric + AppText.footnote (unit)
│  Weight          Body Fat                        │  ← AppText.caption, AppColor.Text.secondary
│  Target: 65-68   Target: 13-15%                 │  ← AppText.footnote, AppColor.Text.tertiary
│                                                  │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 72%  │  ← Progress bar: AppColor.Accent.primary fill
│                                                  │     AppColor.Surface.tertiary track
│  🥩 142g / 180g protein                         │  ← AppText.caption + compact bar (P1)
│                                                  │
│  You're on track — keep going! 💪               │  ← AppText.callout, HomeRecommendationProvider
└─────────────────────────────────────────────────┘
```

**Parameters:**
- `currentWeight: Double?`
- `currentBF: Double?`
- `weightTarget: ClosedRange<Double>?`
- `bfTarget: ClosedRange<Double>?`
- `overallProgress: Double` (0-1)
- `proteinConsumed: Double?`, `proteinTarget: Double?` (P1 macro strip)
- `recommendation: HomeRecommendation`
- `onTap: () -> Void`
- `onLogTap: () -> Void` (empty state)

**Card container:** `AppCard` (Tone=Elevated) or manual `surfaceElevated` + `radiusMedium` + `elevationCard` (matching Home v2 pattern).

### BodyCompositionDetailView (new)

**Location:** `FitTracker/Views/Main/BodyCompositionDetailView.swift`

**Presentation:** `.sheet` with `.presentationDetents([.medium, .large])`

**Layout:**
```
NavigationStack {
  ScrollView {
    VStack(spacing: AppSpacing.medium) {
      // Weight chart section
      VStack(alignment: .leading) {
        SectionHeader("Weight")
        Chart { ... }  // SwiftUI Charts: LineMark for data + RuleMark for goal
        // Current: 67.2 kg | Goal: 65-68 kg
      }

      // Body Fat chart section
      VStack(alignment: .leading) {
        SectionHeader("Body Fat")
        Chart { ... }
        // Current: 14.8% | Goal: 13-15%
      }

      // Time range picker
      AppSegmentedControl(options: ["7d", "30d", "90d", "All"])

      // Per-metric progress
      progressBar("Weight", progress: weightProgress)
      progressBar("Body Fat", progress: bfProgress)

      // Log CTA
      AppButton("Log Metrics", hierarchy: .primary, onTap: logAction)
    }
  }
  .navigationTitle("Body Composition")
  .navigationBarTitleDisplayMode(.inline)
  .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
  .analyticsScreen(.bodyCompDetail)
}
```

---

## 2. Token Map

| Element | Token |
|---|---|
| Card background | `AppColor.Surface.elevated` |
| Card radius | `AppRadius.medium` (via variable binding) |
| Card shadow | `effect/elevation-card` |
| Card padding | `AppSpacing.small` (16pt) |
| Card item spacing | `AppSpacing.xSmall` (12pt) |
| Eyebrow "BODY COMPOSITION" | `AppText.eyebrow`, `AppColor.Text.secondary` |
| Chevron icon | `AppText.caption`, `AppColor.Text.tertiary` |
| Hero values (67.2 / 14.8) | `AppText.metric` |
| Value units (kg / %) | `AppText.footnote`, `AppColor.Text.secondary` |
| Labels (Weight / Body Fat) | `AppText.caption`, `AppColor.Text.secondary` |
| Target ranges | `AppText.footnote`, `AppColor.Text.tertiary` |
| Progress bar fill | `AppColor.Accent.primary` |
| Progress bar track | `AppColor.Surface.tertiary` |
| Progress bar height | `AppSize.progressBarHeight` (4pt) |
| Progress bar radius | `AppRadius.micro` (4pt) |
| Progress percentage | `AppText.caption`, `AppColor.Text.secondary` |
| Macro strip icon | `AppText.iconSmall` |
| Macro strip text | `AppText.caption` |
| Recommendation line | `AppText.callout`, `AppColor.Text.primary` |
| Detail chart | SwiftUI Charts with `AppColor.Chart.weight`, `AppColor.Chart.body` |
| Detail goal line | `AppColor.Status.warning` (dashed RuleMark) |
| Detail segmented control | `AppSegmentedControl` component |
| Detail CTA | `AppButton` (Hierarchy=Primary) |

---

## 3. State Matrix

| State | Card | Detail |
|---|---|---|
| **Default** | Both values shown + progress + recommendation | Charts with data, goal overlays |
| **Partial** | One value shown, other shows "Log" CTA | One chart, other shows empty message |
| **Empty** | "Log your first metrics" CTA, no values | Not reachable (card tap disabled when empty) |
| **Loading** | Skeleton placeholder | Spinner while data loads |
| **Error** | Falls back to manual data if HealthKit fails | Error message + retry |

---

## 4. Accessibility

| Element | Label | Hint | Value | Traits |
|---|---|---|---|---|
| Card (overall) | "Body composition" | "Tap for details" | "Weight {X} kg, body fat {X} percent, {X} percent toward goal" | — |
| Eyebrow | "Body composition" | — | — | `.isHeader` |
| Progress bar | "Goal progress" | — | "{X} percent" | — |
| Macro strip | "Protein" | — | "{X} of {Y} grams" | — |
| Chevron | hidden (card tap handles it) | — | — | `.isHidden` |
| Detail: chart | "Weight trend" / "Body fat trend" | — | "Current {X}, goal {Y}" | — |
| Detail: segment picker | "Time range" | — | "{selected}" | — |
| Detail: Log CTA | "Log metrics" | "Opens metric entry" | — | `.isButton` |

---

## 5. Motion

| Animation | Token | Trigger | Reduce-motion |
|---|---|---|---|
| Card press | Scale 0.98 + `AppSpring.snappy` | Touch down | Opacity only |
| Progress bar fill | `AppEasing.standard` (0.3s) | Data change | Instant |
| Detail sheet present | System sheet animation | Tap card | System handles |
| Chart line draw | `AppEasing.standard` | Detail appears | Instant |

---

## 6. Compliance Gateway

| Check | Status | Details |
|---|---|---|
| Token compliance | **Pass** | All values from AppText/AppSpacing/AppColor/AppRadius/AppSize |
| Component reuse | **Pass** | Reuses AppButton, AppSegmentedControl, SectionHeader. New card is justified (unique layout) |
| Pattern consistency | **Pass** | Card + drill-down sheet matches Home v2 pattern (ReadinessCard tap → cycle) |
| Accessibility | **Pass** | All elements labeled, 44pt targets, Dynamic Type, VoiceOver |
| Motion | **Pass** | All tokenized, reduce-motion respected |

---

## 7. Analytics Mapping

| Interaction | Event | Params |
|---|---|---|
| Tap card | `home_body_comp_tap` | has_weight, has_body_fat, progress_percent |
| Switch time range | `home_body_comp_period_changed` | period (7d/30d/90d/all) |
| Tap Log CTA in detail | `home_body_comp_log_tap` | source: body_comp_detail |
| Detail screen view | `.analyticsScreen(.bodyCompDetail)` | — |
