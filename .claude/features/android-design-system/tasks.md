# Task Breakdown: Android Design System

> **Feature:** android-design-system
> **Total effort:** 5 working days (1 week)
> **Total subtasks:** 6

---

## Tasks

### T1: Comprehensive Color Mapping Document
- **Type:** docs
- **Description:** Map all 46 iOS color tokens to MD3 color roles. Include: hex values, opacity conversions, dark mode variants, custom extended colors for domain-specific tokens (sleep, recovery, achievement).
- **Effort:** 1 day
- **Files:** `docs/design-system/android-token-mapping.md` (new)

### T2: Typography + Spacing + Radius + Motion Mapping
- **Type:** docs
- **Description:** Map 22 text styles, 8 spacing values, 6+ radius values, and motion presets to MD3 equivalents. Include Compose code snippets.
- **Effort:** 1 day
- **Files:** `docs/design-system/android-token-mapping.md` (extend)

### T3: Component Parity Audit
- **Type:** docs
- **Description:** Map 13 iOS components (AppButton, AppCard, AppMenuRow, etc.) to MD3 equivalents. For each: MD3 component name, Compose composable, key differences, adaptation notes.
- **Effort:** 0.5 days
- **Files:** `docs/design-system/android-token-mapping.md` (extend)

### T4: Style Dictionary Android Config
- **Type:** infra
- **Description:** Create Style Dictionary configuration that generates Kotlin/Compose output from existing tokens.json. Test that both iOS (.swift) and Android (.kt) generate successfully.
- **Effort:** 1 day
- **Files:** `design-tokens/config-android.json` (new), `design-tokens/android/` (new output dir)

### T5: Dark Mode Strategy
- **Type:** docs
- **Description:** Document how FitMe's opacity-based surface system maps to MD3's tonal surface system. Define light + dark color schemes for Android.
- **Effort:** 0.5 days
- **Files:** `docs/design-system/android-token-mapping.md` (extend)

### T6: Review + CI Verification
- **Type:** test
- **Description:** Verify `make tokens-check` still passes. Review mapping document for completeness. Verify Style Dictionary generates both outputs.
- **Effort:** 0.5 days

---

## Execution Order

| Day | Tasks | What |
|-----|-------|------|
| 1 | T1 | Color mapping (46 tokens) |
| 2 | T2 | Typography + spacing + radius + motion |
| 3 | T3, T5 (parallel) | Component audit + dark mode strategy |
| 4 | T4 | Style Dictionary Android config |
| 5 | T6 | Review + CI |
