# PRD: Android Design System

> **ID:** Task 2 | **Status:** Shipped (Research Complete) | **Priority:** MEDIUM (RICE 4.8)
> **Last Updated:** 2026-04-04

---

## Purpose

Map FitMe's 92 iOS design tokens to Material Design 3 (MD3) equivalents, identify gaps, add Android platform to Style Dictionary, and document the adaptation strategy for a future Kotlin/Compose Android build.

## Business Objective

Android represents ~45% of the global smartphone market. Before committing to an 8-12 week Android build (Task 3), the design system must be mapped to ensure visual consistency without iOS-isms. This research de-risks the Android investment.

## What Was Built

### Token Mapping
- **92 iOS tokens** mapped to MD3 equivalents across all categories
- **Color mapping:** Brand colors → MD3 primary/secondary/tertiary roles; Surface system → MD3 tonal surfaces
- **Typography mapping:** iOS type scale → MD3 type scale (display/headline/title/body/label)
- **Spacing mapping:** iOS spacing scale → MD3 8dp grid system
- **Radius mapping:** iOS corner radii → MD3 shape system (extra small → extra large)
- **Motion mapping:** iOS spring animations → MD3 motion tokens (duration, easing)
- **Shadow mapping:** iOS shadows → MD3 elevation levels

### Style Dictionary Android Config
- Generates Kotlin/Compose tokens (`FitMeTheme`, `FitMeLightColors`, `FitMeExtendedColors`)
- Generates XML resources for legacy Android Views
- Integrated into existing `sd.config.js`

### Component Parity Audit
- 13 iOS components mapped to MD3 composable equivalents
- Gap analysis: what needs new MD3 components vs direct equivalents

### Dark Mode Strategy
- iOS opacity-based dark mode → MD3 tonal elevation mapping
- Documented approach for maintaining brand identity across light/dark

## Key Files
| File | Purpose |
|------|---------|
| `docs/design-system/android-token-mapping.md` | Complete token mapping document |
| `docs/design-system/android-adaptation.md` | Adaptation strategy and gaps |
| `sd.config.js` | Style Dictionary config (iOS + Android platforms) |
| `design-tokens/tokens.json` | Source of truth |

## Deliverables

| Deliverable | Status |
|-------------|--------|
| Token mapping document | Complete |
| Style Dictionary Android output | Complete |
| Component parity audit | Complete |
| Dark mode strategy | Complete |
| Compose code examples | Complete |
| Gap analysis | Complete |

## Next Steps (Task 3)
- Native Kotlin+Compose vs React Native vs KMP decision
- Full architecture mapping
- Supabase Android SDK integration
- Health Connect integration
- Effort estimate: 8-12 weeks
