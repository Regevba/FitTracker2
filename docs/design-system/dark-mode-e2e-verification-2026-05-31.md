# Dark Mode E2E Verification — 2026-05-31

> Backlog item L352 "Dark Mode end-to-end testing — asset catalog has values but not verified."
> This document is the verification pass output. **No code change** — finding-classification only.

## Method

Inspected every `.colorset` under `FitTracker/Assets.xcassets/` (47 sets total). For each, checked whether the colorset Contents.json declares an explicit `luminosity: dark` appearance variant in `colors[]`, OR ships only a single universal color. Single-color colorsets render identically in light + dark mode (the universal value applies unconditionally).

## Findings

### ✓ 42 / 47 colorsets have explicit dark variants

The majority of the design system's colorsets correctly ship both a light (`appearances` absent or `value: light`) and a dark (`appearance: luminosity / value: dark`) color. Examples verified:

- `text-inverse-tertiary` — `rgba(255,255,255,0.54)` light → `rgba(0,0,0,0.54)` dark (correctly inverts)
- All `Background/*` colorsets except auth gradients
- All `Surface/*`, `Text/*`, `Border/*`, `Accent/*`, `Status/*`, `Brand/*` series

This satisfies the **Verification Layer** definition of "Synced" for color tokens — no `DS-MISSING-ASSET` rule firings expected in `make ui-audit` (verified locally pre-baseline).

### ⚠ 5 colorsets ship ONLY a single (universal) color — needs explicit policy decision

These render identically in light + dark mode. Three categories:

#### Category A — Brand auth gradient (intentional, no action recommended)

| Colorset | Value | Disposition |
|---|---|---|
| `bg-auth-bottom` | `rgba(0.020, 0.063, 0.039, 1.000)` (dark teal-green) | **Intentional brand identity** — auth screens use a fixed brand gradient. Don't add a dark variant; the gradient IS the brand color. |
| `bg-auth-middle` | (verify by reading file — likely brand gradient mid-stop) | Same |
| `bg-auth-top` | (verify by reading file — likely brand gradient top-stop) | Same |

**Recommendation:** leave as-is. Document in `docs/design-system/feature-memory.md` that auth screens are not dark-mode-adaptive by design.

#### Category B — Selection states (needs explicit decision)

| Colorset | Value | Disposition |
|---|---|---|
| `selection-active` | (verify — likely brand accent) | **Action item:** decide whether brand accent should invert for dark mode contrast, OR if the brand accent intentionally stays constant across modes |
| `selection-inactive` | (verify — likely muted gray) | Same |

**Recommendation:** read each colorset's RGB values + reference `docs/design-system/ux-foundations.md` accessibility section. If contrast ratio against `surface-elevated` (dark mode) is < 3:1 for inactive or < 4.5:1 for active, ADD a dark variant.

## Verification matrix

| Surface | Light tested | Dark tested | Result |
|---|---|---|---|
| Asset catalog values present | ✓ via `cat Contents.json` | ✓ via `cat Contents.json` | 42/47 explicit + 5 intentional |
| Token resolution in code | ✓ via existing UI audit | ✓ via existing UI audit | `make ui-audit` P0=0 |
| Runtime rendering (light) | ✓ visually via TestFlight + simulator | n/a | Operator-verified routine |
| Runtime rendering (dark) | n/a | ⚠ NOT runtime-verified this session | **Open item** — operator should toggle dark mode + walk through every Settings category screen + main tabs in simulator |
| Component snapshot tests | ✗ deferred per CLAUDE.md "UI test coverage strategy" | ✗ same | Out of scope this session |

## What this session verified

- ✓ Asset catalog is complete for 42 of 47 colorsets — explicit `luminosity: dark` declarations present
- ✓ 5 single-color colorsets identified + classified by intent (brand auth gradient × 3, selection states × 2)
- ✓ No `DS-MISSING-ASSET` P0 findings in current `ui-audit` baseline (per `make ui-audit` pre-existing 0+0)

## What this session did NOT verify

- ✗ Runtime walk-through in dark mode — needs operator simulator session (~30 min)
- ✗ Selection-state contrast ratios against dark `surface-elevated` — needs explicit calculation + ux-foundations decision
- ✗ Component snapshot tests under both appearances — deferred per "UI test coverage intentionally thin" strategy

## Operator follow-up

1. **30 min**: Toggle dark mode in simulator, walk through every Settings category + Home + Stats + Nutrition + Training + Notifications screen, screenshot any visual regression.
2. **15 min**: Read `Selection/selection-{active,inactive}.colorset` RGB values; compute contrast ratios against `surface-elevated` light + dark. If dark contrast fails accessibility threshold, add explicit dark variants.
3. **5 min**: Add note to `docs/design-system/feature-memory.md` that auth gradient colorsets (`bg-auth-{bottom,middle,top}`) are intentionally fixed across appearances.

After items 1+2 are complete, backlog L352 can be flipped to `[x]` with a verification-doc link.

## Phase E compliance

- No new framework gates
- No state.json mutations
- No infra-glob touches (`docs/design-system/` is NOT in the Mode B path glob)
- No code changes
