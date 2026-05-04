# Framework page — v7 floor update

**Date:** 2026-05-04
**Surface:** `fitme-story` site, route `/framework`
**Type:** content refresh (no new functionality)

## Why

The `/framework` page is stuck at v6.0. The interactive blueprint maxes out at Floor 6 = "v6.0 Measurement" and the prose terminates the framework story there ("Floor 6 observes everything else via the v6.0 measurement overlay"). Since 2026-04-21 the framework has shipped v7.1 → v7.7, which together convert observation into mechanical enforcement — 25 gates + 1 advisory across write-time pre-commit hooks, a 72h integrity cycle, a per-PR review bot, a weekly framework-status cron, and Tier 1/2/3 readout dashboards. v7.8 is currently in progress on a bridge branch.

The dev-guide companion page already reflects v7.7. The blueprint and prose on `/framework` itself do not. This spec closes that gap.

## What changes

Two files. No new components, no new routes, no new data sources.

### 1. `src/components/bespoke/blueprint-data.ts`

Append one new entry to the `FLOORS` array:

```ts
{
  level: 7,
  name: 'v7.7 Validity Closure',
  sub: 'Mechanical enforcement',
  components: [
    'pre-commit gates',
    '72h integrity cycle',
    'per-PR review bot',
    'weekly framework-status cron',
    'Tier 1/2/3 dashboards',
  ],
  accent: '#0EA5E9',
},
```

Naming convention follows the existing floors (each names a single minor version, not a multi-version arc). Accent color is sky-500 — cool tone after the existing warm progression (red → pink → purple).

The `BlueprintOverlay` component renders `FLOORS` in reverse order (`flex-col-reverse`), so adding `level: 7` automatically appears at the top with no component change needed.

### 2. `src/app/framework/page.tsx`

**Header subtitle (line 17):** "Six floors. Hover to explore how each layer contributes." → "Seven floors. Hover to explore how each layer contributes."

**Prose paragraph (lines 23–25):** rewrite to include Floor 7 and a v7.8 mention. Final text:

> The framework is organized as seven floors stacked on a shared slab. Floor 1 holds the source-of-truth state. Floor 2 is the hub-and-spoke of skills and their cache tiers. Floors 3–5 add successive SoC-inspired primitives — skill-on-demand loading, batch dispatch, dispatch intelligence. Floor 6 observes the lower floors via the v6.0 measurement overlay. Floor 7 promotes that observation into mechanical enforcement: 25 gates + 1 advisory split across write-time pre-commit hooks, the 72h integrity cycle, a per-PR review bot, a weekly framework-status cron, and the Tier 1/2/3 readout dashboards. v7.8 is in progress on a bridge branch (schema validation + concurrent-dispatch defenses).

The second paragraph (link to the SoC-v5.0 case study) is unchanged.

The dev-guide card (lines 49–66) is unchanged — its "v1.0 → v7.7" version anchor and "13 integrity check codes + 1 advisory" cycle-time count are both still accurate.

## What does NOT change

- `BlueprintOverlay.tsx` — no logic change; it iterates `FLOORS` generically.
- `src/app/framework/dispatch/page.tsx` — out of scope; covers dispatch model only.
- `src/app/framework/dev-guide/page.tsx` — already current.
- Any case study, MDX, or content under `content/`.

## Verification

- Visual check: `/framework` renders 7 floors top-down, Floor 7 first, accent strip is sky-blue.
- Hover Floor 7 reveals the 5 component chips listed above.
- Subtitle reads "Seven floors".
- Prose includes the Floor 7 sentence and v7.8 mention.
- `next build` passes (no type changes — `Floor` interface is unchanged).
