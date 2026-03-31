# iPhone Runtime Layout Spec

Date: 2026-03-29
Phase: Integrated iPhone UI polish
Primary validation device: iPhone 14 Pro

## Purpose

This spec defines the approved spacing, sizing, icon, and resolution rules that must be used when refining any locked iPhone screen in FitTracker. It exists to keep Figma and SwiftUI aligned and to prevent ad hoc visual changes that only work on one screen size.

All measurements below are in logical points unless marked as physical pixels.

## Device baselines

| Device class | Logical viewport | Physical export reference | Use |
| --- | --- | --- | --- |
| Compact iPhone | `375 x 812 pt` | device-specific @3x | Minimum supported compact width check |
| Baseline iPhone 14 Pro | `393 x 852 pt` | `1179 x 2556 px` @3x | Primary design and QA baseline |
| Large iPhone | `430 x 932 pt` | device-specific @3x | Large-width validation |

## Global layout rules

- Horizontal page padding:
  - `20–24 pt` on compact widths
  - `24–28 pt` on the `393 pt` baseline
  - `28–32 pt` on large widths
- Top content should begin `24 pt` below the visible status/nav cluster unless the screen intentionally uses a larger hero.
- Vertical section rhythm should default to `20–24 pt`.
- Internal card padding should be:
  - `16 pt` minimum
  - `20 pt` preferred
  - `24 pt` for hero, settings-category, or large summary surfaces

## Safe area and shell rules

- Respect Dynamic Island and home indicator clearance on every screen.
- Floating bottom tab shell must sit `16 pt` above the bottom safe area.
- Bottom shell internal padding should stay within:
  - `14–16 pt` vertical
  - `20–24 pt` horizontal
- Never place primary controls below home-indicator clearance.

## Screen spacing rules

| Area | Rule | Notes |
| --- | --- | --- |
| Header stack | `16 pt` between eyebrow, title, subtitle | Increase to `20 pt` for auth/settings hero states |
| Section to section | `24 pt` default | Do not go below `20 pt` unless the screen is a dense utility surface |
| Card gap | `10–12 pt` | Tile grids may use `8 pt` only if readability is preserved |
| Form field gap | `12 pt` between label and input; `14–16 pt` between fields | Helper text must clear the next CTA by at least `12 pt` |
| Primary CTA group | `20 pt` above, `16 pt` below | Keep CTA visually isolated from passive notes |
| Bottom pills/badges | `8 pt` vertical gap, centered, `24 pt` bottom clearance | Used on auth and future trust/status stacks |

## Approved element sizes

| Element | Baseline size | Scale rule |
| --- | --- | --- |
| Primary CTA button | `48 pt` height | May shrink to `44 pt` on compact widths; may grow to `52 pt` for hero CTA only |
| Secondary / utility button | `40 pt` height | Minimum tap target remains `44 pt` with outer hit slop |
| Input field | `44 pt` height | Use `48 pt` when suffix/prefix icons or chips are present |
| Segmented / tab switcher | `38 pt` shell, `30 pt` active pill | Keep `4 pt` outer inset and `8 pt` between options |
| Small trust/status pill | `24 pt` height | Use `20–24 pt` horizontal padding based on label length |
| Section card | `96–160 pt` height | Internal padding `18–24 pt` |
| Floating tab shell | `64–68 pt` height | Never compress below `60 pt` |
| Menu/avatar circle | `46–56 pt` | Inner icon stays `20–24 pt` |
| Metric icon | `16–20 pt` | Keep at least `8 pt` from label baseline |
| Tab bar icon | `20–22 pt` | Pair with `11–13 pt` label |

## Icon size rules

| Icon family | Approved sizes | Usage |
| --- | --- | --- |
| Navigation icons | `20`, `22`, `24 pt` | Tab bar, toolbar, account/menu affordances |
| Inline status icons | `12`, `14`, `16 pt` | Badges, chips, helper rows |
| Hero/start action icons | `24`, `28`, `32 pt` | Workout CTA, recovery CTA, key stat circle |
| Eye/reveal icons | `16 pt` | Form suffix only |
| Settings chevrons | `16 pt` | Category cards and preference rows |

## Resolution and export rules

- Build screen layouts in logical points.
- Export iPhone 14 Pro runtime references at `@3x`.
- Never convert icon sizes into code from raw pixel exports alone.
- Example:
  - Figma source size: `24 pt`
  - Review export on iPhone 14 Pro: `72 px` at `@3x`

## Scalability rule

Every approved screen must be reviewed in:

- compact iPhone width
- baseline iPhone width
- large iPhone width

If a layout only works at `393 pt` and fails at `375 pt` or `430 pt`, it is not approved.

## Completion gate for this phase

This integration-polish phase is only complete when all of the following are true:

1. The unified branch runtime matches the approved screen direction across Auth, Home, Training, Nutrition, Stats, and Settings.
2. Each approved screen has a corresponding editable integrated runtime board in Figma.
3. The Figma board is layered and editable, not a flat screenshot placeholder.
4. The screen has been checked against compact, baseline, and large iPhone width rules.
5. Any runtime divergence discovered during unified-shell testing has been reflected back into the Figma live asset board.
