# M-3 — Design System Completion + Dark Mode

> **Audit findings**: DS-004 (token pipeline ~60% coverage) + DS-009 (no dark-mode adaptive colors) + DS-010 (Chart/Selection/appWarmTint missing from pipeline)
> **Type**: Multi-session feature — case study tracking ON from start
> **Predecessor**: `docs/superpowers/plans/2026-04-19-audit-completion-plan.md` (M-3 row)
> **Date**: 2026-04-19

## Goal

Bring the design-token pipeline from ~60% to 100% AppTheme coverage and add dark-mode adaptive variants for every color token. After M-3 completes, the `make tokens-check` CI gate catches drift across **every** semantic token — not just the color/spacing/typography subset.

## Phases

### Phase M-3a — Non-Color Token Categories (this PR)

Add the missing non-color categories to `design-tokens/tokens.json`:

| Category | What | Source-of-truth in code today |
|---|---|---|
| **motion** | Animation curves + durations | `AppMotion` (6 named animations), `AppEasing` (referenced in some files) |
| **opacity** | Disabled / subtle / hover | `AppOpacity` (3 values) |
| **size** | Fixed-dimension UI sizes (CTA height, touch target, etc.) | `AppSize` (6 values) |
| **layout** | Component sizing (chart height, chip widths, dot size) | `AppLayout` (6 values) |
| **radius** | Corner radii | `AppRadius` (10 values) — currently in `borderRadius` partially |

**Risk**: low — additive only, no codegen rewiring required for this phase. The values in tokens.json mirror what's in AppTheme.swift, establishing the pipeline as the source of truth for the next phase.

**Out of Phase M-3a**: chart colors, selection colors, appWarmTint — these need investigation in Phase M-3b before adding (need to identify the canonical values).

### Phase M-3b — Color Token Completion (next PR)

- Find and add: chart colors (10), selection colors (2), appWarmTint
- Investigate any remaining color drift between AppColor enum and tokens.json
- Single PR

### Phase M-3c — Dark Mode (DS-009, biggest commit)

For every color token, add a dark-mode variant:
- Update `tokens.json` with `value.light` / `value.dark` per color
- Style Dictionary build emits `Color("name")` with both modes
- Asset catalogs get the dark variants
- Visual QA pass on every screen
- Settings toggle for system/light/dark already exists (verify wiring)

This is the biggest commit — touches every screen for visual verification. Likely 2-3 PRs (token additions, asset catalog, visual QA fixes).

### Phase M-3d — Case Study + Docs

- Write `docs/case-studies/m-3-design-system-completion-case-study.md`
- Update `case-study-monitoring.json` with the M-3 entry
- Update `docs/design-system/design-system.json` shared status
- Capture "what we learned" notes

## Out of scope

- Re-codegenerating Swift from tokens.json (existing Style Dictionary config already does this for the categories it covers; expanding the codegen to motion/opacity/size/layout is a separate Style Dictionary config sprint, deferred)
- Android token sync (`config-android.json` exists but the iOS app is the only consumer right now)
- Animation curve standardization beyond what AppMotion already provides

## Success criteria

- After Phase M-3a: tokens.json contains 5 new categories matching AppTheme values
- After Phase M-3b: tokens.json contains all chart/selection/warmTint values
- After Phase M-3c: every color token has light + dark variants; visual QA passes on Home, Stats, Nutrition, Training, Profile, Settings, MealEntrySheet
- After Phase M-3d: case study + monitoring entry shipped per the rule

## Estimated effort

| Phase | Effort | Risk |
|---|---|---|
| M-3a (this PR) | 30-45 min | low |
| M-3b | 30-45 min | low |
| M-3c | 4-6 hours | medium (visual QA breadth) |
| M-3d | 60-90 min | low |
| **Total** | **~6-8 hours** | |
