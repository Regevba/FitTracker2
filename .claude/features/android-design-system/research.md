# Research: Android Design System Investigation

> Feature: android-design-system | Phase 0 | RICE: 4.8
> Date: 2026-04-04

---

## 1. What is this solution?

Map FitMe's 92 iOS semantic design tokens (46 color, 22 text, 8 spacing, 6 radius, 6 elevation/shadow, 4 motion) to Material Design 3 (MD3) equivalents for Jetpack Compose. This creates the foundation for an Android version of FitMe that feels native on Android while maintaining visual consistency with the iOS app.

**Output:** A comprehensive token mapping document + Style Dictionary configuration that generates both iOS (Swift) and Android (Kotlin/Compose) tokens from a single `tokens.json` source file.

---

## 2. Why this approach?

**Problem:** FitMe is iOS-only. 72% of global smartphone users are on Android. Without an Android design system, building an Android app would require redesigning every screen from scratch.

**What this enables:**
- Android app development starts with tokens + components already mapped
- Style Dictionary pipeline generates both platforms from one source
- Brand consistency across platforms without pixel-perfect matching
- Developers can reference the mapping doc for any component

---

## 3. Why this over alternatives?

| Approach | Pros | Cons | Effort | Chosen? |
|----------|------|------|--------|---------|
| **Token-by-token MD3 mapping + Style Dictionary** | Platform-native, single source, scalable, respects platform conventions | Requires upfront mapping research, not all tokens have 1:1 equivalents | 2 weeks | **Yes** |
| **Cross-platform framework (Flutter/KMM)** | Share UI code, one codebase | Non-native feel, Flutter has own design system, poor platform integration | 4+ weeks | No |
| **Pixel-perfect port (same design on both)** | Visual consistency | Users expect platform-native patterns (MD3 on Android, HIG on iOS) | 3 weeks | No |
| **Separate Android design from scratch** | Fully native | No brand consistency, duplicate effort, harder to maintain | 6+ weeks | No |

**Decision:** Semantic mapping — same brand, platform-native UX. Strava, Nike Run Club, and Peloton all follow this approach.

---

## 4. External Sources

- [Material Design 3 — Color Roles](https://m3.material.io/styles/color/roles)
- [Material Design 3 — Typography](https://m3.material.io/styles/typography/applying-type)
- [Material Design 3 — Shape](https://m3.material.io/styles/shape/corner-radius-scale)
- [Material Design 3 — Motion](https://m3.material.io/styles/motion/easing-and-duration/tokens-specs)
- [Jetpack Compose Material 3 — Android Developers](https://developer.android.com/develop/ui/compose/designsystems/material3)
- [Style Dictionary — Cross-Platform Tokens](https://styledictionary.com/)
- [Theming in Compose Codelab](https://codelabs.developers.google.com/jetpack-compose-theming)

---

## 5. Market Examples

| App | Strategy | What Works | What Doesn't |
|-----|----------|------------|--------------|
| **Strava** | Same brand, platform-native patterns | Bottom nav on Android, tab bar on iOS. Same orange/dark theme. | Some inconsistencies in card layouts |
| **Nike Run Club** | Platform-native, shared design tokens | Consistent brand feel. MD3 components on Android. | Typography feels slightly different |
| **Peloton** | Custom design system on both | Very consistent look across platforms | Can feel non-native on Android |
| **MyFitnessPal** | Mostly shared, some platform deviations | Feature parity is strong | Android app feels slightly iOS-ported |

**Key learning:** Best apps use platform-native components (MD3 on Android, HIG on iOS) with shared brand colors and typography scale. They do NOT try to make Android look like iOS.

---

## 6. Complete Token Mapping: iOS → MD3

### Color Tokens (46 iOS → MD3)

| iOS Token | iOS Value | MD3 Equivalent | MD3 Role | Notes |
|-----------|----------|----------------|----------|-------|
| **Brand.primary** | #FA8F40 | `colorScheme.primary` | Primary | Key brand color |
| **Brand.secondary** | #8AC7FF | `colorScheme.secondary` | Secondary | |
| **Brand.warmSoft** | #FFE3BA | `colorScheme.primaryContainer` | Primary Container | Light variant |
| **Brand.warm** | #FFC78A | `colorScheme.primary` (tone 80) | — | Mid-tone |
| **Brand.coolSoft** | #DFF3FF | `colorScheme.secondaryContainer` | Secondary Container | Light variant |
| **Brand.cool** | #BAE3FF | `colorScheme.secondary` (tone 80) | — | Mid-tone |
| **Background.appPrimary** | #DFF3FF | `colorScheme.background` | Background | |
| **Background.appSecondary** | #F0FAFF | `colorScheme.surface` | Surface | |
| **Text.primary** | rgba(0,0,0,0.84) | `colorScheme.onSurface` | On Surface | |
| **Text.secondary** | rgba(0,0,0,0.62) | `colorScheme.onSurfaceVariant` | On Surface Variant | |
| **Text.tertiary** | rgba(0,0,0,0.55) | `colorScheme.outline` | Outline | Slightly differs in semantic meaning |
| **Text.inversePrimary** | rgba(255,255,255,0.94) | `colorScheme.inverseOnSurface` | Inverse On Surface | |
| **Surface.primary** | rgba(255,255,255,0.72) | `colorScheme.surfaceContainerLowest` | Surface Container Lowest | |
| **Surface.secondary** | rgba(255,255,255,0.58) | `colorScheme.surfaceContainerLow` | Surface Container Low | |
| **Surface.elevated** | rgba(255,255,255,0.92) | `colorScheme.surfaceContainerHigh` | Surface Container High | |
| **Status.success** | #34C759 | Custom `success` | — | MD3 doesn't have success; use custom |
| **Status.warning** | #FF9500 | Custom `warning` | — | MD3 doesn't have warning; use custom |
| **Status.error** | #FF3B30 | `colorScheme.error` | Error | MD3 has built-in error |
| **Accent.recovery** | #5AC8FA | `colorScheme.tertiary` | Tertiary | Map to tertiary role |
| **Accent.sleep** | #BF5AF2 | Custom extended color | — | Domain-specific |
| **Accent.achievement** | #FFD60A | Custom extended color | — | Domain-specific |

### Typography Tokens (22 iOS → MD3)

| iOS Token | iOS Style | MD3 Equivalent | MD3 Category |
|-----------|----------|----------------|--------------|
| **hero** | largeTitle bold | `displayLarge` | Display |
| **pageTitle** | title2 bold | `headlineLarge` | Headline |
| **titleStrong** | title3 bold | `headlineMedium` | Headline |
| **titleMedium** | title3 semibold | `titleLarge` | Title |
| **sectionTitle** | headline semibold | `titleMedium` | Title |
| **body** | body medium | `bodyLarge` | Body |
| **bodyRegular** | body regular | `bodyMedium` | Body |
| **callout** | callout medium | `bodyLarge` (medium) | Body |
| **subheading** | subheadline regular | `bodySmall` | Body |
| **caption** | caption regular | `labelMedium` | Label |
| **captionStrong** | caption semibold | `labelLarge` | Label |
| **eyebrow** | caption bold | `labelSmall` (bold) | Label |
| **chip** | footnote semibold | `labelMedium` | Label |
| **button** | body semibold | `labelLarge` | Label |
| **metric** | title bold | `displayMedium` | Display |
| **metricHero** | largeTitle bold | `displayLarge` | Display |
| **monoMetric** | title3 bold mono | `displaySmall` (mono) | Display |

### Spacing Tokens (8 iOS → MD3)

| iOS Token | iOS Value | MD3 Equivalent | MD3 dp |
|-----------|----------|----------------|--------|
| **micro** | 2pt | — | 2dp (custom) |
| **xxxSmall** | 4pt | 4dp | 4dp |
| **xxSmall** | 8pt | 8dp | 8dp |
| **xSmall** | 12pt | 12dp | 12dp |
| **small** | 16pt | 16dp | 16dp |
| **medium** | 20pt | 20dp | 20dp |
| **large** | 24pt | 24dp | 24dp |
| **xLarge** | 32pt | 32dp | 32dp |
| **xxLarge** | 40pt | 40dp | 40dp |

Direct 1:1 mapping — both use 4dp/4pt grid.

### Radius Tokens (6+ iOS → MD3)

| iOS Token | iOS Value | MD3 Shape | MD3 dp |
|-----------|----------|-----------|--------|
| **micro** | 4pt | ExtraSmall | 4dp |
| **xSmall** | 8pt | Small | 8dp |
| **small** | 12pt | Medium | 12dp |
| **medium** | 16pt | Large | 16dp |
| **button** | 20pt | — (custom) | 20dp |
| **large** | 24pt | ExtraLarge | 28dp |
| **sheet** | 32pt | ExtraLarge (top only) | 28dp |

### Motion Tokens (iOS → MD3)

| iOS Token | iOS Value | MD3 Equivalent | MD3 Spec |
|-----------|----------|----------------|----------|
| **instant** | 100ms easeOut | Duration.Short1 | 50ms |
| **micro** | 150ms | Duration.Short2 | 100ms |
| **short** | 200ms easeInOut | Duration.Short3 | 150ms |
| **standard** | 300ms easeInOut | Duration.Medium1 | 250ms |
| **long** | 450ms | Duration.Medium3 | 350ms |
| **xLong** | 600ms | Duration.Long2 | 500ms |

MD3 durations are slightly shorter — adjust for Android feel.

---

## 7. Technical Feasibility

**Style Dictionary pipeline:**
- Existing: `design-tokens/tokens.json` → Style Dictionary → `DesignTokens.swift` (iOS)
- New: Same `tokens.json` → Style Dictionary → `DesignTokens.kt` (Android/Compose)
- Both outputs from one source of truth
- CI gate (`make tokens-check`) already validates iOS; extend for Android

**Compose implementation:**
```kotlin
val FitMeColorScheme = lightColorScheme(
    primary = Color(0xFFFA8F40),
    secondary = Color(0xFF8AC7FF),
    // ... mapped from tokens.json
)

MaterialTheme(
    colorScheme = FitMeColorScheme,
    typography = FitMeTypography,
    shapes = FitMeShapes,
)
```

---

## 8. Proposed Success Metrics

**Primary:** Token mapping coverage — % of 92 iOS tokens with documented MD3 equivalents (target: 100%)

**Secondary:**
- Style Dictionary dual output — generates both .swift and .kt from tokens.json
- Component parity audit — % of 13 iOS components with MD3 equivalents documented

**has_ui = false** (this is a research/documentation deliverable, no app UI)
**requires_analytics = false** (no user-facing interactions)

---

## 9. Decision

**Recommended:** Produce a comprehensive mapping document + Style Dictionary Android config. This is a documentation deliverable — no code ships to users. The output enables any future Android development to start with tokens already mapped.

**Effort:** 1 week (5 working days) — research-heavy, documentation output.
