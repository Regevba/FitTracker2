# FitTracker Typography Repository

## Canonical semantic roles

The official code-side type system is defined in [AppTheme.swift](FitTracker/Services/AppTheme.swift).

### `AppText`

- `hero`
- `pageTitle`
- `titleStrong`
- `titleMedium`
- `sectionTitle`
- `body`
- `bodyRegular`
- `callout`
- `subheading`
- `caption`
- `captionStrong`
- `eyebrow`
- `chip`
- `footnote`
- `metric`
- `metricCompact`
- `metricHero`
- `metricDisplay`
- `metricDisplayMono`
- `monoMetric`
- `monoLabel`
- `button`

### `AppType` compatibility aliases

- `display`
- `headline`
- `body`
- `subheading`
- `caption`

## Current usage snapshot

This scan reflects current code usage and helps prioritize migration.

### Most-used semantic roles

- `AppText.caption`: 48
- `AppText.captionStrong`: 44
- `AppText.monoLabel`: 26
- `AppText.callout`: 24
- `AppText.body`: 23
- `AppText.subheading`: 19
- `AppText.pageTitle`: 12
- `AppText.sectionTitle`: 10

### Compatibility alias usage

- `AppType.caption`: 29
- `AppType.subheading`: 24
- `AppType.body`: 12
- `AppType.headline`: 4

## Legacy typography debt still in the app

The app is much more systematized than before, but it still has raw font usage that should continue migrating into semantic roles.

### Highest-frequency raw patterns still present

- `.font(.caption.weight(.semibold))`: 28
- `.font(.caption)`: 16
- `.font(.headline)`: 12
- `.font(.caption2.monospaced())`: 9
- `.font(.caption2)`: 6
- `.font(.subheadline.weight(.semibold))`: 4
- `.font(.caption.weight(.bold))`: 4
- `.font(.title3)`: 3
- `.font(.subheadline)`: 3
- `.font(.system(.title3, design: .monospaced, weight: .bold))`: 2
- `.font(.system(.body, design: .monospaced))`: 2

## Interpretation

- The app’s default reading and metadata rhythm is now clearly built around:
  - `caption`
  - `captionStrong`
  - `body`
  - `callout`
  - `subheading`
- Training and dense metric surfaces rely heavily on:
  - `monoLabel`
  - `monoMetric`
  - `metricHero`
- The remaining typography cleanup should focus first on:
  - Nutrition
  - Training
  - legacy helper rows in Main/Auth

## Source references

- [AppTheme.swift](FitTracker/Services/AppTheme.swift)
- [MainScreenView.swift](FitTracker/Views/Main/MainScreenView.swift)
- [TrainingPlanView.swift](FitTracker/Views/Training/TrainingPlanView.swift)
- [NutritionView.swift](FitTracker/Views/Nutrition/NutritionView.swift)
- [AuthHubView.swift](FitTracker/Views/Auth/AuthHubView.swift)
