# Android and Pixel Adaptation Notes

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
| `AppColor.Focus.ring` | focused / selected emphasis token |
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
