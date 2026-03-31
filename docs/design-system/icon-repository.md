# FitTracker Icon Repository

## Current state

- The current app language is primarily SF Symbols based.
- The repository currently has no `.xcassets` catalog or dedicated custom icon source files.
- Static code scan found a broad shared symbol set across auth, shell, metrics, nutrition, stats, settings, and training.
- Additional symbol roles come from enum-backed icon mappings in:
  - `FitTracker/Views/RootTabView.swift`
  - `FitTracker/Views/Stats/StatsView.swift`
  - `FitTracker/Models/DomainModels.swift`
  - `FitTracker/Services/AppSettings.swift`
  - `FitTracker/Views/Shared/RecoverySupport.swift`
  - `FitTracker/Services/AuthManager.swift`

## Repository categories

### Navigation and shell

- `house.fill`
- `figure.strengthtraining.traditional`
- `leaf.fill`
- `chart.bar.fill`
- `line.3.horizontal`
- `ellipsis`

### Auth and security

- `apple.logo`
- `key.fill`
- `envelope.fill`
- `lock.shield.fill`
- `lock.open.fill`
- `lock.fill`
- `faceid`
- `touchid`
- `person.badge.key.fill`
- `rectangle.portrait.and.arrow.right`

### Health and metrics

- `scalemass.fill`
- `waveform.path.ecg`
- `heart.fill`
- `heart.circle.fill`
- `moon.fill`
- `bed.double.fill`
- `flame.fill`
- `flame.circle.fill`
- `lungs.fill`
- `drop.fill`
- `drop.circle.fill`
- `sparkles`
- `dot.scope`

### Training and recovery

- `timer`
- `repeat`
- `number.square`
- `figure.walk`
- `bolt.fill`
- `arrow.up.circle.fill`
- `arrow.down.circle.fill`
- `plus.circle.fill`
- `plus.circle`
- `checkmark.seal.fill`
- `figure.cooldown`
- `figure.yoga`
- `note.text`
- `camera.fill`
- `camera`
- `camera.viewfinder`
- `photo`
- `photo.fill`

### Nutrition and logging

- `barcode.viewfinder`
- `pills.fill`
- `pill.fill`
- `fork.knife`
- `clock`
- `clock.arrow.circlepath`
- `bolt.heart.fill`
- `doc.text`
- `magnifyingglass`

### Status and utility

- `checkmark.circle.fill`
- `checkmark`
- `circle`
- `circle.lefthalf.filled`
- `exclamationmark.triangle.fill`
- `xmark.circle.fill`
- `xmark`
- `chevron.right`
- `chevron.left`
- `chevron.up`
- `chevron.down`
- `arrow.counterclockwise`
- `info.circle`
- `paintpalette`
- `paintpalette.fill`
- `ruler`

## Notes for system work

- Prefer reusing the current symbol language before introducing custom icons.
- When a new feature proposes a new icon, it should document:
  - purpose
  - semantic meaning
  - whether an existing SF Symbol can cover it
  - whether it must become a custom asset later
- If FitTracker moves toward a stronger custom brand expression, the first likely custom-icon candidates are:
  - app icon
  - onboarding/brand marks
  - key navigation illustrations
  - marketing/App Store artwork

## Source references

- [RootTabView.swift](/Users/regevbarak/Downloads/FitTracker2/FitTracker/Views/RootTabView.swift)
- [StatsView.swift](/Users/regevbarak/Downloads/FitTracker2/FitTracker/Views/Stats/StatsView.swift)
- [DomainModels.swift](/Users/regevbarak/Downloads/FitTracker2/FitTracker/Models/DomainModels.swift)
- [AppSettings.swift](/Users/regevbarak/Downloads/FitTracker2/FitTracker/Services/AppSettings.swift)
- [RecoverySupport.swift](/Users/regevbarak/Downloads/FitTracker2/FitTracker/Views/Shared/RecoverySupport.swift)
- [AuthManager.swift](/Users/regevbarak/Downloads/FitTracker2/FitTracker/Services/AuthManager.swift)
