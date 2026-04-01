# FitTracker Color Usage Guidelines

## Purpose

This document defines what each major FitTracker color means, when it should be used, and what should be avoided. The source of truth is still `AppTheme.swift`; this file explains how to use those tokens well.

## Token format

- Use the semantic token name first.
- Use the exact token value second.
- Hex is the canonical format for solid colors.
- RGBA is the canonical format for translucent surface, text, border, and selection roles.
- When a role is an alias, keep the alias in usage docs and the underlying value in implementation notes.

## Main colors

### `AppColor.Brand.primary`

- Hex: `#FA8F40`
- Meaning: strongest brand action and warm momentum
- Use for:
  - primary CTA
  - strongest foreground action in a view
  - deliberate emphasis on commitment or progress
- Avoid for:
  - generic decoration
  - passive information
  - warning/error semantics

### `AppColor.Brand.secondary`

- Hex: `#8AC7FF`
- Meaning: calm product identity and active selection
- Use for:
  - selected states
  - progress emphasis
  - shell tinting and cool accents
- Avoid for:
  - urgent or destructive meaning
  - replacing the primary CTA color

## Canonical token inventory

### Solid colors

| Token | Value | Family | Meaning | Primary use | Avoid |
| --- | --- | --- | --- | --- | --- |
| `AppColor.Brand.primary` | `#FA8F40` | Brand | strongest brand action and warm momentum | primary CTA, strongest action, commitment moments | generic decoration, warning/error semantics |
| `AppColor.Brand.secondary` | `#8AC7FF` | Brand | calm product identity and active selection | selected state, progress emphasis, shell tint | urgent, destructive, or warning states |
| `AppColor.Brand.warmSoft` | `#FFE3BA` | Brand support | soft warm support tone | warm shell tint, supportive highlights, subtle body-composition context | primary CTA fill, warning state |
| `AppColor.Brand.warm` | `#FFC78A` | Brand support | warm progress tone | warm charts, supportive emphasis, secondary action warmth | generic screen background |
| `AppColor.Brand.coolSoft` | `#DFF3FF` | Brand support | core cool atmosphere | default app background base, cool shell foundation | high-emphasis CTA |
| `AppColor.Brand.cool` | `#BAE3FF` | Brand support | stronger cool shell accent | shell gradients, selected surfaces, soft cards | status or destructive meaning |
| `AppColor.Background.appPrimary` | `#DFF3FF` | Background | default Apple-first shell base | most approved screen backgrounds | isolated pill/button fills |
| `AppColor.Background.appSecondary` | `#F0FAFF` | Background | top gradient softness | top shell blending, safe-area atmosphere | strong contrast surfaces |
| `AppColor.Background.appTint` | `#BAE3FF` | Background | cool tint layer | gradient mids, selected shell sections | warning/error status |
| `AppColor.Background.appWarmTint` | `#FFE3BA` | Background | warm supporting tint | subtle warm balancing, branded support zones | full-page default background |
| `AppColor.Background.authTop` | `#0A140F` | Legacy auth | dark auth gradient top | legacy / restricted auth-only use | new light product surfaces |
| `AppColor.Background.authMiddle` | `#102419` | Legacy auth | dark auth gradient middle | legacy / restricted auth-only use | new light product surfaces |
| `AppColor.Background.authBottom` | `#05100A` | Legacy auth | dark auth gradient bottom | legacy / restricted auth-only use | new light product surfaces |
| `AppColor.Accent.recovery` | `#5AC8FA` | Accent | recovery, hydration, cardio emphasis | recovery indicators, cardio, hydration prompts | generic CTA or navigation |
| `AppColor.Accent.sleep` | `#BF5AF2` | Accent | sleep and restorative emphasis | sleep metrics, restorative signals | generic selection state |
| `AppColor.Accent.achievement` | `#FFD60A` | Accent | achievement and milestone emphasis | celebration, achievements, streak wins | warning or generic highlight |
| `AppColor.Status.success` | `#34C759` | Status | successful or healthy outcome | success banners, confirmed states, healthy signal | brand decoration |
| `AppColor.Status.warning` | `#FF9500` | Status | caution or incomplete work | warnings, caution labels, incomplete requirement | primary CTA |
| `AppColor.Status.error` | `#FF3B30` | Status | failure or destructive consequence | destructive states, blocking errors | non-error emphasis |
| `AppColor.Chart.body` | `#FFC78A` | Chart | body-composition data | body-fat/body-composition charting | navigation or CTA fill |
| `AppColor.Chart.cardio` | `#5AC8FA` | Chart | cardio / recovery data | cardio data series | general-purpose surface tint |
| `AppColor.Chart.sleep` | `#BF5AF2` | Chart | sleep data | sleep data series | generic chips |
| `AppColor.Chart.achievement` | `#FFD60A` | Chart | milestone data | achievement or milestone series | warning replacement |
| `AppColor.Chart.progress` | `#8AC7FF` | Chart | progress data | progress bars and goal charts | destructive or error meaning |
| `AppColor.Chart.nutritionFat` | `#995926` | Chart | nutrition fat data | fat macro charting and dietary balance | generic accent use |
| `AppColor.Focus.ring` | `#8AC7FF` | Focus | active focus indicator | focused elements, accessibility ring | status meaning |

### Translucent semantic roles

| Token | Value | Family | Meaning | Primary use | Notes |
| --- | --- | --- | --- | --- | --- |
| `AppColor.Surface.primary` | `rgba(255,255,255,0.72)` | Surface | default glass card | cards, grouped containers, shells | default surface on blue backgrounds |
| `AppColor.Surface.secondary` | `rgba(255,255,255,0.58)` | Surface | softer glass layer | secondary cards, neutral pills, supporting containers | use below primary surface emphasis |
| `AppColor.Surface.tertiary` | `rgba(255,255,255,0.38)` | Surface | light shell suggestion | subtle pills, passive surfaces, lightweight overlays | avoid for large readable cards |
| `AppColor.Surface.elevated` | `rgba(255,255,255,0.92)` | Surface | highest light surface contrast | inputs, sheets, elevated panels | use sparingly so elevation remains meaningful |
| `AppColor.Surface.materialLight` | `rgba(255,255,255,0.22)` | Surface | soft material wash | atmospheric material overlays | too weak for primary content blocks |
| `AppColor.Surface.materialStrong` | `rgba(255,255,255,0.34)` | Surface | stronger material wash | glassy shells, floating overlays | still not strong enough for dense text areas |
| `AppColor.Surface.inverse` | `rgba(0,0,0,0.82)` | Surface | inverse dark surface | dark pills, inverse buttons, dark overlays | pair only with inverse text roles |
| `AppColor.Text.primary` | `rgba(0,0,0,0.84)` | Text | strongest readable text | main body, titles, key labels | dark surfaces |
| `AppColor.Text.secondary` | `rgba(0,0,0,0.62)` | Text | supporting text | helper copy, metadata, subtitles | main CTA labels |
| `AppColor.Text.tertiary` | `rgba(0,0,0,0.42)` | Text | quiet metadata | placeholders, low-priority support | critical information |
| `AppColor.Text.inversePrimary` | `rgba(255,255,255,0.94)` | Text | strongest inverse text | text on dark/inverse surfaces | light surfaces |
| `AppColor.Text.inverseSecondary` | `rgba(255,255,255,0.76)` | Text | supporting inverse text | helper text on dark/inverse surfaces | light surfaces |
| `AppColor.Text.inverseTertiary` | `rgba(255,255,255,0.54)` | Text | quiet inverse metadata | passive dark-surface metadata | light surfaces |
| `AppColor.Border.strong` | `rgba(255,255,255,0.54)` | Border | visible light separator | strong strokes, pill outlines, selected outline | dense grid separators on light content |
| `AppColor.Border.subtle` | `rgba(255,255,255,0.30)` | Border | soft light separator | soft outlines, grouping, shells | strong focus or selected state |
| `AppColor.Border.hairline` | `rgba(0,0,0,0.08)` | Border | faint dark separator | hairlines inside light surfaces | heavy emphasis or focus |
| `AppColor.Selection.active` | `rgba(255,255,255,0.84)` | Selection | active item highlight | active tab shell, selected pills | status indication |
| `AppColor.Selection.inactive` | `rgba(255,255,255,0.42)` | Selection | inactive shell state | unselected shell controls | text or body content |

## Supporting color families

### Warm family

- `warmSoft`, `warm`
- Use for:
  - body-composition progress
  - supportive warmth
  - subtle complementary brand tone

### Cool family

- `coolSoft`, `cool`
- Use for:
  - app backgrounds
  - shell gradients
  - calm surfaces and layout atmosphere

## Semantic roles

### Background

- `Background.appPrimary`, `Background.appSecondary`, `Background.appTint`
- Use for screen-level shells and large atmospheric surfaces

### Surface

- `Surface.primary`, `secondary`, `tertiary`, `elevated`
- Use for cards, pills, panels, input shells, grouped surfaces
- `Surface.primary` is the default glass card role
- `Surface.elevated` is reserved for inputs, sheets, and the strongest raised surface

### Text

- `Text.primary`, `secondary`, `tertiary`
- Default readable text stack on light surfaces
- `inverse*` roles are only for dark or intentionally inverse surfaces
- On light blue shells, default to `Text.primary` unless there is a specific hierarchy reason not to

### Border

- `Border.strong`, `subtle`, `hairline`
- Use to separate surfaces and define shape edges without overloading color
- Use `hairline` for internal separators on elevated light surfaces
- Use `strong` only when the edge needs to read as part of the component shape

### Accent

- `Accent.recovery`, `sleep`, `achievement`
- Domain-specific emphasis only
- Do not reuse these for unrelated navigation or generic CTA work

### Status

- `Status.success`, `warning`, `error`
- Reserved for real success, warning, and error meaning
- Always pair with readable text and context

### Chart

- Use chart colors for data categories, not generic UI emphasis

### Focus and selection

- `Focus.ring` uses the same blue family as the product accent and should remain accessibility-driven
- `Selection.active` and `Selection.inactive` are shell-state roles, not generic content fills

## Do and don't

- Do use color to reinforce meaning, hierarchy, or state.
- Do keep the blue shell direction consistent across approved product screens.
- Do pair color-coded meaning with text and layout context.
- Do document both the semantic token and the exact value when handing work to design or code.
- Don’t use orange as a generic decorative highlight.
- Don’t use sleep or recovery accents as general-purpose theme colors.
- Don’t use status colors for branding or for non-status emphasis.
- Don’t use legacy auth greens on new product surfaces unless auth is intentionally redesigned.

## Screen examples

- `Login`: blue shell plus orange primary CTA
- `Home`: cool shell, blue progress, restrained warm support accents
- `Training`: cool shell with blue emphasis and neutral action pills
- `Nutrition`: cool shell with warm fat-related metrics and green quick action
- `Stats`: cool shell with orange logging CTA and neutral empty-state cards

## Token migration mapping

This section documents the canonical substitution rules used during the 2026-03-30 token migration pass (commits `f140230`, `e7f333a`). Use these mappings whenever replacing raw literals with semantic tokens.

### `Color.white.opacity(N)` — fill contexts

| Raw value | Semantic token | Notes |
|---|---|---|
| `0.08–0.10` | `AppColor.Surface.materialLight` | atmospheric fills, light tints |
| `0.14–0.22` | `AppColor.Surface.materialLight` | soft overlays, panel washes |
| `0.23–0.45` | `AppColor.Surface.materialStrong` | chips, floating surfaces, selection tiles |
| `0.72+` | `AppColor.Surface.primary` | glass card default |

### `Color.white.opacity(N)` — stroke/border contexts

| Raw value | Semantic token | Notes |
|---|---|---|
| `0.08` on light surface | `AppColor.Border.hairline` | hairline separator inside elevated surface |
| `0.20–0.32` | `AppColor.Border.subtle` | soft outlines, pill strokes, grouping edges |
| `0.54+` | `AppColor.Border.strong` | prominent outlines, selected-state strokes |

### Text and foreground roles

| Raw value | Semantic token |
|---|---|
| `.foregroundStyle(.secondary)` | `.foregroundStyle(AppColor.Text.secondary)` |
| `.foregroundStyle(.tertiary)` | `.foregroundStyle(AppColor.Text.tertiary)` |
| `.foregroundStyle(.primary)` | `.foregroundStyle(AppColor.Text.primary)` |
| `Color.secondary.opacity(N)` | `AppColor.Text.secondary.opacity(N)` |
| `Color.white.opacity(0.86–0.94)` on dark surface | `AppColor.Text.inversePrimary` |
| `Color.white.opacity(0.70–0.80)` on dark surface | `AppColor.Text.inverseSecondary` |
| `Color.white.opacity(0.44–0.60)` on dark surface | `AppColor.Text.inverseTertiary` |

### Shadow roles

| Raw value | Semantic token |
|---|---|
| `.shadow(color: .black.opacity(0.04–0.10), radius: N, y: N)` (cards) | `AppShadow.cardColor / cardRadius / cardYOffset` |
| `.shadow(color: accentColor.opacity(0.24), radius: N, y: N)` (CTAs) | `AppShadow.ctaColor / ctaRadius / ctaYOffset` |

### Legacy brand aliases

| Legacy | Canonical |
|---|---|
| `Color.appOrange1` | `AppColor.Brand.warmSoft` |
| `Color.appOrange2` | `AppColor.Brand.warm` |
| `Color.appBlue1` | `AppColor.Brand.cool` |
| `Color.blue.opacity(0.85)` | `AppColor.Brand.secondary` |

### FocusModeView exception

`FocusModeView` in `TrainingPlanView.swift` uses a non-adaptive `Color.black.ignoresSafeArea()` background in all color scheme modes. Inverse text tokens (`AppColor.Text.inversePrimary` etc.) are adaptive and resolve to **dark** values in Dark Mode, which would render dark text on a black background. For this view only, raw `Color.white.opacity(N)` is intentionally retained for text foreground colors. Do not replace them with adaptive inverse tokens.

## Implementation notes

- Figma should show both the semantic token name and the exact value for every documented swatch.
- Use hex for solid fills and RGBA for translucent semantic roles.
- When a color is an alias, document the alias that designers should use first and the underlying value second.
- The code source of truth remains [AppTheme.swift](FitTracker/Services/AppTheme.swift).
