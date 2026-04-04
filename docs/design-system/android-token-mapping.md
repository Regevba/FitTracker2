# FitMe — iOS to Android (MD3) Design Token Mapping

> Maps all 92 FitMe iOS design tokens to Material Design 3 equivalents for Jetpack Compose.
> Source of truth: `design-tokens/tokens.json`
> Last updated: 2026-04-04

---

## Overview

| Category | iOS Tokens | MD3 Mapped | Custom (no MD3 equivalent) |
|----------|-----------|------------|---------------------------|
| Colors | 46 | 30 | 16 (domain-specific) |
| Typography | 22 | 15 | 7 (metric/mono variants) |
| Spacing | 9 | 9 | 0 (1:1 mapping) |
| Radius/Shape | 9 | 6 | 3 (custom) |
| Shadow/Elevation | 4 | 2 | 2 (custom) |
| Motion | 14 | 10 | 4 (spring presets) |
| **Total** | **104** | **72** | **32** |

---

## 1. Color Tokens (46 iOS → MD3)

### Brand Colors → MD3 Key Colors

| iOS Token | Hex | MD3 Role | Compose Property |
|-----------|-----|----------|-----------------|
| `Brand.primary` | #FA8F40 | Primary | `colorScheme.primary` |
| `Brand.secondary` | #8AC7FF | Secondary | `colorScheme.secondary` |
| `Brand.warmSoft` | #FFE3BA | Primary Container | `colorScheme.primaryContainer` |
| `Brand.warm` | #FFC78A | — | Custom `brandWarm` |
| `Brand.coolSoft` | #DFF3FF | Secondary Container | `colorScheme.secondaryContainer` |
| `Brand.cool` | #BAE3FF | — | Custom `brandCool` |

### Background → MD3 Surface

| iOS Token | Value | MD3 Role | Compose Property |
|-----------|-------|----------|-----------------|
| `Background.appPrimary` | #DFF3FF | Background | `colorScheme.background` |
| `Background.appSecondary` | #F0FAFF | Surface | `colorScheme.surface` |
| `Background.appTint` | #BAE3FF | Surface Variant | `colorScheme.surfaceVariant` |
| `Background.appWarmTint` | — | — | Custom `backgroundWarmTint` |
| `Background.authTop` | #0A140F | — | Custom `authGradientTop` |
| `Background.authMiddle` | #102419 | — | Custom `authGradientMiddle` |
| `Background.authBottom` | #05100A | — | Custom `authGradientBottom` |

### Text → MD3 Content Colors

| iOS Token | Value | MD3 Role | Compose Property |
|-----------|-------|----------|-----------------|
| `Text.primary` | rgba(0,0,0,0.84) | On Surface | `colorScheme.onSurface` |
| `Text.secondary` | rgba(0,0,0,0.62) | On Surface Variant | `colorScheme.onSurfaceVariant` |
| `Text.tertiary` | rgba(0,0,0,0.55) | Outline | `colorScheme.outline` |
| `Text.inversePrimary` | rgba(255,255,255,0.94) | Inverse On Surface | `colorScheme.inverseOnSurface` |
| `Text.inverseSecondary` | rgba(255,255,255,0.76) | — | Custom `inverseSecondary` |
| `Text.inverseTertiary` | rgba(255,255,255,0.54) | — | Custom `inverseTertiary` |

### Surface → MD3 Surface Containers

| iOS Token | Value | MD3 Role | Compose Property |
|-----------|-------|----------|-----------------|
| `Surface.primary` | rgba(255,255,255,0.72) | Surface Container Lowest | `colorScheme.surfaceContainerLowest` |
| `Surface.secondary` | rgba(255,255,255,0.58) | Surface Container Low | `colorScheme.surfaceContainerLow` |
| `Surface.tertiary` | rgba(255,255,255,0.38) | Surface Container | `colorScheme.surfaceContainer` |
| `Surface.elevated` | rgba(255,255,255,0.92) | Surface Container High | `colorScheme.surfaceContainerHigh` |
| `Surface.materialLight` | rgba(255,255,255,0.22) | — | Custom `materialLight` |
| `Surface.materialStrong` | rgba(255,255,255,0.34) | — | Custom `materialStrong` |
| `Surface.inverse` | rgba(0,0,0,0.82) | Inverse Surface | `colorScheme.inverseSurface` |

### Border → MD3 Outline

| iOS Token | Value | MD3 Role | Compose Property |
|-----------|-------|----------|-----------------|
| `Border.strong` | rgba(255,255,255,0.54) | Outline | `colorScheme.outline` |
| `Border.subtle` | rgba(255,255,255,0.30) | Outline Variant | `colorScheme.outlineVariant` |
| `Border.hairline` | rgba(0,0,0,0.08) | — | Custom `hairline` |

### Status → MD3 Error + Custom

| iOS Token | Hex | MD3 Role | Compose Property |
|-----------|-----|----------|-----------------|
| `Status.success` | #34C759 | — | Custom `success` (MD3 has no success role) |
| `Status.warning` | #FF9500 | — | Custom `warning` (MD3 has no warning role) |
| `Status.error` | #FF3B30 | Error | `colorScheme.error` |

### Accent → MD3 Tertiary + Custom

| iOS Token | Hex | MD3 Role | Compose Property |
|-----------|-----|----------|-----------------|
| `Accent.primary` | (= Brand.primary) | Primary | `colorScheme.primary` |
| `Accent.secondary` | (= Brand.secondary) | Secondary | `colorScheme.secondary` |
| `Accent.recovery` | #5AC8FA | Tertiary | `colorScheme.tertiary` |
| `Accent.sleep` | #BF5AF2 | — | Custom `accentSleep` |
| `Accent.achievement` | #FFD60A | — | Custom `accentAchievement` |

---

## 2. Typography Tokens (22 iOS → MD3)

### Mapping Table

| iOS Token | iOS Style | MD3 Token | MD3 Category | Size (sp) | Weight |
|-----------|----------|-----------|--------------|-----------|--------|
| `hero` | largeTitle bold | `displayLarge` | Display | 57 | Bold |
| `pageTitle` | title2 bold | `headlineLarge` | Headline | 32 | Bold |
| `titleStrong` | title3 bold | `headlineMedium` | Headline | 28 | Bold |
| `titleMedium` | title3 semibold | `titleLarge` | Title | 22 | SemiBold |
| `sectionTitle` | headline semibold | `titleMedium` | Title | 16 | SemiBold |
| `body` | body medium | `bodyLarge` | Body | 16 | Medium |
| `bodyRegular` | body regular | `bodyMedium` | Body | 14 | Regular |
| `callout` | callout medium | `bodyLarge` | Body | 16 | Medium |
| `subheading` | subheadline regular | `bodySmall` | Body | 12 | Regular |
| `caption` | caption regular | `labelMedium` | Label | 12 | Regular |
| `captionStrong` | caption semibold | `labelLarge` | Label | 14 | SemiBold |
| `eyebrow` | caption bold | `labelSmall` | Label | 11 | Bold |
| `chip` | footnote semibold | `labelMedium` | Label | 12 | SemiBold |
| `button` | body semibold | `labelLarge` | Label | 14 | SemiBold |
| `metric` | title bold | `displayMedium` | Display | 45 | Bold |
| `metricCompact` | title2 bold | `displaySmall` | Display | 36 | Bold |
| `metricHero` | largeTitle bold | `displayLarge` | Display | 57 | Bold |
| `metricDisplay` | largeTitle bold | `displayLarge` | Display | 57 | Bold |
| `metricDisplayMono` | title bold mono | `displayMedium` | Display | 45 | Bold (Mono) |
| `monoMetric` | title3 bold mono | `headlineMedium` | Headline | 28 | Bold (Mono) |
| `monoLabel` | caption2 semibold mono | `labelSmall` | Label | 11 | SemiBold (Mono) |
| `footnote` | footnote regular | `labelSmall` | Label | 11 | Regular |

### Font Family Mapping

| iOS | Android |
|-----|---------|
| SF Pro Rounded | Google Sans (or Roboto) |
| SF Mono | Roboto Mono |

---

## 3. Spacing Tokens (9 iOS → MD3)

Direct 1:1 mapping — both platforms use 4dp/4pt grid.

| iOS Token | pt | Android dp | Compose |
|-----------|-----|-----------|---------|
| `micro` | 2 | 2.dp | `FitMeSpacing.Micro` |
| `xxxSmall` | 4 | 4.dp | `FitMeSpacing.XXXSmall` |
| `xxSmall` | 8 | 8.dp | `FitMeSpacing.XXSmall` |
| `xSmall` | 12 | 12.dp | `FitMeSpacing.XSmall` |
| `small` | 16 | 16.dp | `FitMeSpacing.Small` |
| `medium` | 20 | 20.dp | `FitMeSpacing.Medium` |
| `large` | 24 | 24.dp | `FitMeSpacing.Large` |
| `xLarge` | 32 | 32.dp | `FitMeSpacing.XLarge` |
| `xxLarge` | 40 | 40.dp | `FitMeSpacing.XXLarge` |

---

## 4. Shape/Radius Tokens (9 iOS → MD3)

| iOS Token | pt | MD3 Shape | dp | Compose |
|-----------|-----|-----------|-----|---------|
| `micro` | 4 | ExtraSmall | 4 | `Shapes.extraSmall` |
| `xSmall` | 8 | Small | 8 | `Shapes.small` |
| `small` | 12 | Medium | 12 | `Shapes.medium` |
| `medium` | 16 | Large | 16 | `Shapes.large` |
| `button` | 20 | — | 20 | Custom `ShapeButton` |
| `large` | 24 | ExtraLarge | 28 | `Shapes.extraLarge` |
| `xLarge` | 28 | — | 28 | Custom `ShapeXLarge` |
| `sheet` | 32 | ExtraLarge (top) | 28 | `BottomSheetDefaults.SheetShape` |
| `authSheet` | 36 | — | 36 | Custom `ShapeAuthSheet` |

---

## 5. Shadow/Elevation (iOS Shadows → MD3 Tonal Elevation)

MD3 uses **tonal elevation** (surface color shifts up toward primary) instead of drop shadows.

| iOS Token | iOS Implementation | MD3 Equivalent | Compose |
|-----------|-------------------|----------------|---------|
| Card shadow | 8% black, 10pt blur, 4pt offset | Elevation Level 1 (1.dp) | `tonalElevation = 1.dp` |
| CTA shadow | 28% primary, 12pt blur, 4pt offset | Elevation Level 3 (6.dp) | `tonalElevation = 6.dp` |

For Android, replace iOS drop shadows with MD3 tonal elevation. The surface color automatically shifts.

---

## 6. Motion Tokens

### Duration Mapping

| iOS Token | iOS ms | MD3 Token | MD3 ms | Compose |
|-----------|--------|-----------|--------|---------|
| `instant` | 100 | Short1 | 50 | `MotionTokens.DurationShort1` |
| `micro` | 150 | Short2 | 100 | `MotionTokens.DurationShort2` |
| `short` | 200 | Short4 | 200 | `MotionTokens.DurationShort4` |
| `standard` | 300 | Medium2 | 300 | `MotionTokens.DurationMedium2` |
| `long` | 450 | Medium4 | 400 | `MotionTokens.DurationMedium4` |
| `xLong` | 600 | Long2 | 500 | `MotionTokens.DurationLong2` |

### Easing Mapping

| iOS Token | iOS Curve | MD3 Curve | Compose |
|-----------|----------|-----------|---------|
| `standard` | easeInOut | Standard | `MotionTokens.EasingStandard` |
| `short` | easeInOut | Standard | `MotionTokens.EasingStandard` |
| `instant` | easeOut | StandardDecelerate | `MotionTokens.EasingStandardDecelerate` |

### Spring → Android Equivalents

iOS spring animations don't have direct MD3 equivalents. Use:

| iOS Spring | Response/Damping | Android Equivalent |
|-----------|-----------------|-------------------|
| `snappy` | 0.30 / 0.72 | `spring(dampingRatio = 0.72f, stiffness = Spring.StiffnessMediumLow)` |
| `bouncy` | 0.45 / 0.60 | `spring(dampingRatio = 0.6f, stiffness = Spring.StiffnessLow)` |
| `smooth` | 0.40 / 0.85 | `spring(dampingRatio = 0.85f, stiffness = Spring.StiffnessLow)` |
| `stiff` | 0.25 / 0.90 | `spring(dampingRatio = 0.9f, stiffness = Spring.StiffnessMedium)` |

---

## 7. Component Parity Audit (13 iOS → MD3)

| iOS Component | iOS File | MD3 Equivalent | Compose Composable | Adaptation Notes |
|---------------|---------|----------------|-------------------|-----------------|
| **AppButton** (4 styles) | AppComponents.swift | MD3 Button | `Button`, `FilledButton`, `OutlinedButton`, `TextButton` | Destructive → `FilledButton` with error color |
| **AppCard** (4 tones) | AppComponents.swift | MD3 Card | `Card`, `ElevatedCard`, `OutlinedCard` | Map quiet → OutlinedCard, elevated → ElevatedCard |
| **AppMenuRow** | AppComponents.swift | MD3 ListItem | `ListItem` | Chevron → trailing icon |
| **StatusBadge** | AppComponents.swift | — | Custom `StatusChip` | No MD3 equivalent; build custom |
| **EmptyStateView** | AppComponents.swift | — | Custom `EmptyState` | No MD3 equivalent; common pattern |
| **AppSelectionTile** | AppComponents.swift | MD3 SegmentedButton | `SegmentedButton` | Similar concept, different visual |
| **AppInputShell** | AppComponents.swift | MD3 TextField | `OutlinedTextField` | Map to outlined variant |
| **AppFieldLabel** | AppComponents.swift | — | Part of `OutlinedTextField` | MD3 integrates label into TextField |
| **AppQuietButton** | AppComponents.swift | MD3 TextButton | `TextButton` | Direct mapping |
| **AppPickerChip** | AppComponents.swift | MD3 FilterChip | `FilterChip` | Direct mapping with selected state |
| **AppFilterBar** | AppComponents.swift | MD3 ChipGroup | `LazyRow { FilterChip() }` | Horizontal scrollable chips |
| **AppSegmentedControl** | AppComponents.swift | MD3 SegmentedButton | `SingleChoiceSegmentedButtonRow` | Direct mapping |
| **AppProgressRing** | AppComponents.swift | MD3 CircularProgressIndicator | `CircularProgressIndicator` | Add custom text overlay |

---

## 8. Dark Mode Strategy

### iOS Approach (current)
FitMe uses **opacity-based surfaces** over gradient backgrounds. Dark mode is handled via asset catalog color sets with dark variants for all 43 colorsets.

### Android Approach (recommended)
Use MD3's **tonal elevation system**:
- Light theme: use the mapped color scheme above
- Dark theme: generate via `dynamicDarkColorScheme()` or define manually:
  - `surface` → dark gray (#1A1F2E)
  - `onSurface` → light gray (rgba 255,255,255,0.87)
  - `primary` → same #FA8F40 (brand colors stay consistent)
  - `surfaceContainer*` → progressively lighter grays

### Key Differences
| Aspect | iOS | Android |
|--------|-----|---------|
| Surface transparency | Opacity-based overlays | Tonal elevation (color shift) |
| Background | Gradient (blue → white) | Solid surface colors |
| Dark mode | Asset catalog dark variants | `darkColorScheme()` in Compose |
| System adaptive | `.preferredColorScheme()` | `isSystemInDarkTheme()` |

---

## 9. Compose Code Examples

### Theme Setup

```kotlin
@Composable
fun FitMeTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    MaterialTheme(
        colorScheme = if (darkTheme) FitMeDarkColors else FitMeLightColors,
        typography = FitMeTypography,
        shapes = FitMeShapes,
        content = content
    )
}

val FitMeLightColors = lightColorScheme(
    primary = Color(0xFFFA8F40),
    onPrimary = Color.White,
    primaryContainer = Color(0xFFFFE3BA),
    secondary = Color(0xFF8AC7FF),
    onSecondary = Color.White,
    secondaryContainer = Color(0xFFDFF3FF),
    tertiary = Color(0xFF5AC8FA),
    error = Color(0xFFFF3B30),
    background = Color(0xFFDFF3FF),
    surface = Color(0xFFF0FAFF),
    onSurface = Color(0xFF000000).copy(alpha = 0.84f),
    onSurfaceVariant = Color(0xFF000000).copy(alpha = 0.62f),
    outline = Color(0xFF000000).copy(alpha = 0.55f),
)
```

### Custom Extended Colors

```kotlin
data class FitMeExtendedColors(
    val success: Color,
    val warning: Color,
    val accentSleep: Color,
    val accentAchievement: Color,
    val brandWarm: Color,
    val brandCool: Color,
)

val LocalFitMeColors = staticCompositionLocalOf { FitMeExtendedColors(...) }
```
