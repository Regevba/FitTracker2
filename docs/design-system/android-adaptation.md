# Android and Pixel Adaptation Notes

## Generated token layer (AND-1, shipped 2026-06-17)

The token half of this strategy is **live and generated**, not aspirational. `design-tokens/tokens.json`
(the same iOS source of truth) builds three committed, drift-gated Android artifacts via
[`sd.config.android.mjs`](../../sd.config.android.mjs):

- [`android/FitMeDesignTokens.kt`](../../android/FitMeDesignTokens.kt) — Jetpack Compose objects
  (`FitMeColors`, `FitMeSpacing`, `FitMeRadius`, `FitMeSize`, `FitMeLayout`, `FitMeElevation`,
  `FitMeOpacity`, `FitMeMotion`).
- [`android/res/values/colors.xml`](../../android/res/values/colors.xml) + `dimens.xml` — Android resources.

Build with `make tokens-android`; the `tokens:android:check` gate fails if the artifacts drift from
`tokens.json`. The MD3 *role* mapping below is the design intent; the generated `.kt`/`.xml` are the
literal values. **No Android app code exists** — these artifacts are the consumable token layer for
when one is built (`android-app-implementation` remains deferred indefinitely; re-eval 2027-05-26).

## Strategy

Android is a second platform layer built on the same FitTracker semantics, not a second independent system.

The order is:

1. Define FitTracker semantic roles
2. Validate them on Apple platforms
3. Map them into Material 3 roles and Android-native interaction patterns

## Token mapping

| FitTracker semantic role | Android / Material 3 direction |
| --- | --- |
| `AppColor.Brand.primary` | primary / primary container depending on emphasis |
| `AppColor.Brand.secondary` | secondary / secondary container |
| `AppColor.Surface.*` | surface, surface container, surface container high |
| `AppColor.Text.*` | on-surface, on-surface variant |
| `AppColor.Status.*` | success/warning/error app roles mapped into Material-compatible status tokens |
| `AppColor.Selection.*` | focused / selected emphasis token (was `Focus.ring`, removed in audit DS-015) |
| `AppRadius.*` | shape scale for small, medium, and large components |

## Component translation

### Direct semantic equivalents

- button hierarchy
- card surfaces
- badges
- metric summaries
- empty states
- settings rows

### Platform-distinct implementations

- Apple tab/sidebar navigation vs Android top app bar + navigation bar / rail
- Apple sheet presentation vs Android bottom sheets and dialogs
- Apple toolbar idioms vs Android app bar actions

## Pixel-ready UX priorities

- edge-to-edge layout with safe insets handled intentionally
- adaptive layouts using window size classes
- compact and large-screen behavior specified separately
- Material motion, not copied iOS motion
- Android-native settings, forms, and navigation affordances

## Wear note

If FitTracker later expands to Wear OS, use Material 3 Expressive guidance for round-screen hierarchy and motion. Do not mirror Apple Watch visual patterns directly.
