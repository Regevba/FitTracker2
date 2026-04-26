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

## Success Metrics

> **Status note (2026-04-26):** This PRD is "Research Complete; Implementation Deferred" — Android client work has not started. Metrics below are pre-launch placeholders to satisfy CLAUDE.md rule #2 (no PRD without metrics). Re-tier to T1 (Instrumented) once the Android build ships and Style Dictionary outputs are exercised in a real Android project.

| Metric | Baseline | Target | Instrumentation |
|--------|----------|--------|-----------------|
| iOS tokens mapped to MD3 | 0 (T2 — Declared, 2026-04-26) | 92/92 (T2 — Declared) | docs/design-system/android-token-mapping.md row count |
| Style Dictionary Android targets | 0 (T2 — Declared, 2026-04-26) | Kotlin/Compose + XML resources both generated (T2 — Declared) | sd.config.js platforms |
| Component parity (iOS → MD3) | 0 (T2 — Declared, 2026-04-26) | 13/13 components mapped (T2 — Declared) | docs/design-system/android-adaptation.md |
| Dark mode strategy documented | N/A — pre-launch (T2 — Declared, 2026-04-26) | One-page tonal-elevation strategy (T2 — Declared) | android-adaptation.md |
| Kill criteria | Style Dictionary Android output cannot generate clean Kotlin/Compose tokens without manual edits OR component parity gaps exceed 30% on first Android sprint OR business decision shifts away from Android within 12 months → Android adaptation strategy is considered failed and the mapping doc is archived (research-only artifact) (T2 — Declared, 2026-04-26) | — | sd.config.js build + Android project import test |
