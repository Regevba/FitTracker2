# FitTracker App Icon And App Store Assets

## Current repo state

- The project currently has no `Assets.xcassets` catalog checked in.
- There is no `AppIcon.appiconset` in the repository yet.
- App icon and App Store submission assets should therefore be treated as required new deliverables, not existing assets to refine.

## Required App Store marketing icon

- `1024 x 1024 px` PNG
- This is the App Store marketing icon.

Apple’s asset catalog reference lists `1024x1024` as the App Store icon size.
Source: [Asset Catalog Format Reference: App Icon Type](https://developer.apple.com/library/archive/documentation/Xcode/Reference/xcode_ref-Asset_Catalog_Format/AppIconType.html)

## Recommended generated iPhone app icon targets

- `20pt @2x, @3x` → `40`, `60`
- `29pt @2x, @3x` → `58`, `87`
- `40pt @2x, @3x` → `80`, `120`
- `60pt @2x, @3x` → `120`, `180`

## Recommended generated iPad app icon targets

- `20pt @1x, @2x` → `20`, `40`
- `29pt @1x, @2x` → `29`, `58`
- `40pt @1x, @2x` → `40`, `80`
- `76pt @1x, @2x` → `76`, `152`
- `83.5pt @2x` → `167`

## Primary App Store screenshot targets

These are the main sizes to plan around for App Store Connect upload:

- iPhone `6.9"` accepted portrait sizes:
  - `1320 x 2868`
  - `1290 x 2796`
  - `1260 x 2736`
- iPad `13"` accepted portrait size:
  - `1200 x 1600`
- iPad `11"` accepted portrait size:
  - `1200 x 1600`

Source: [Screenshot specifications - App Store Connect Help](https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications)

## Recommended production checklist

1. Create a master app icon source at `1024 x 1024`.
2. Derive all Xcode app icon targets from that master source.
3. Create App Store screenshot templates for:
   - iPhone `6.9"`
   - iPad `13"`
4. Create fallback validation templates for:
   - iPad `11"`
5. Add a checked-in `Assets.xcassets/AppIcon.appiconset`.
6. Store final marketing exports in a shared design-system or marketing-assets location.

## FitTracker-specific next step

The design-system file now includes a dedicated `App Icon + App Store` page in Figma. The next concrete asset phase should produce:

- app icon concept options
- final app icon master
- export-ready app icon matrix
- App Store screenshot templates for iPhone and iPad
