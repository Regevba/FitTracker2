# Design Build Prompt — case-study-thread-visualization

> **Generated:** 2026-05-16 by /pm-workflow Phase 3 (auto-handoff prompt)
> **Companion UX prompt:** [`docs/prompts/ux/2026-05-16-case-study-thread-visualization-ux-build.md`](../ux/2026-05-16-case-study-thread-visualization-ux-build.md)
> **Source spec:** [`.claude/features/case-study-thread-visualization/ux-spec.md`](../../../.claude/features/case-study-thread-visualization/ux-spec.md)
> **Figma file:** `fsjHfFLAHELACZHku8Rfcl` — FitMe Story Web — Design System
> **Figma build mode:** `deferred_to_prompt` — push happens post-Phase-4 via `code-connect-automation` workflow

---

## What you're designing

A horizontal **timeline component** for fitme-story (web) — two variants. Visual goal: communicate chronological multi-part progression at a glance without sacrificing density.

## How it looks

```
Listing variant:

  Unified Control Center · v4.3 → v7.8.1 · 6 parts
  ┌────────────────────────────────────────────────────────────────┐
  │                                                                │
  │   ●─────────●─────────●─────────●─────────●─────────●          │
  │                                                                │
  │  v4.3      v4.3      v7.6      v7.8      v7.8.1    v7.8.1     │
  │  cleanup   align'mt  UCC mig.  UCC pub.  passkey   passkey-2  │
  │                                                                │
  └────────────────────────────────────────────────────────────────┘

Detail variant (reader is on "UCC public showcase"):

  ┌────────────────────────────────────────────────────────────────┐
  │   ●─────────●─────────●────────((●))─────────●─────────●      │
  │                                  ^^                            │
  │                              you are here                      │
  │                                                                │
  │  v4.3      v4.3      v7.6     v7.8         v7.8.1   v7.8.1   │
  │  cleanup   align'mt  UCC mig. UCC pub.    passkey   passkey-2 │
  │                              (font-semi)                        │
  └────────────────────────────────────────────────────────────────┘
```

## Tokens (cite REAL fitme-story DS — verified in ux-preflight)

| Element | Light | Dark | CSS token |
|---|---|---|---|
| Page bg | `#FAFAF9` | `#1C1917` | `--color-neutral-50` / `--color-neutral-900` |
| Connector line | `#E7E5E4` | `#44403C` | `--color-neutral-200` / `--color-neutral-700` |
| Node default | `#D6D3D1` | `#5C5754` | `--color-neutral-300` / `--color-neutral-500` |
| Node hover/focus/current | `#4F46E5` | `#818CF8` | `--color-brand-indigo` |
| "You are here" outline ring (4px) | indigo at 30% opacity | same | `--color-brand-indigo` rgba(.., 0.3) |
| Label text default | `#44403C` | `#D6D3D1` | `--color-neutral-700` / `--color-neutral-300` dark |
| Label text current | `#1C1917` | `#FAFAF9` (semibold) | `--color-neutral-900` / `--color-neutral-50` dark |
| Series header title | (display-md gradient or solid) | same | `--text-display-md` |
| Series header meta | `#5C5754` | `#A8A29E` | `--color-neutral-500` |
| Version tag | inherits `<Tag tone="subtle">` defaults | same | `Tag` component |

## Sizing

| Element | Value |
|---|---|
| Node default diameter | 12px |
| Node current diameter | 16px (1.33× scale) |
| Outline ring width | 4px (on current node only) |
| Outline ring offset | 2px from node fill |
| Connector line thickness | 1.5px |
| Node-to-node minimum gap | 32px (Tailwind `gap-8`) |
| Node-to-version-tag vertical gap | 8px (Tailwind `mt-2`) |
| Version-tag-to-label gap | 4px (Tailwind `mt-1`) |
| Listing section vertical margin | 48px (Tailwind `my-12`) |
| Detail variant top margin | 24px (Tailwind `mt-6`) |
| Focus ring outline (Tab focus) | 2px solid indigo at 2px offset |
| Min effective tap target | 44×44 CSS px (mobile; achieved via padded `<a>`) |

## Typography

| Element | Token |
|---|---|
| Series title | `--text-display-md` (clamp(1.5rem, 3vw, 2.25rem)) |
| Series meta | `--text-body` (1.0625rem line-height 1.7), color `--color-neutral-500` |
| Version tag | `<Tag>` component default |
| Label desktop | `text-sm` (~14px) |
| Label mobile | `text-xs` (~12px) |
| Current node label | `text-sm font-semibold` |

## Motion

| Interaction | Duration | Easing |
|---|---|---|
| Hover translateY(-2px) | `--motion-duration-fast` (120ms) | `--motion-easing-standard` |
| Color fill change on hover/focus | `--motion-duration-fast` | `--motion-easing-standard` |
| Mount fade-in (detail variant "you are here") | `--motion-duration-standard` (200ms) | `--motion-easing-decelerate` |

**Reduced motion:** global `@media (prefers-reduced-motion: reduce)` rule already disables all transitions — no component-level work needed.

## Responsive breakpoints

| Viewport | Layout |
|---|---|
| `< 640px` (sm-) | Vertical stack — each node on its own row; connector becomes left-side vertical line `border-l-2 border-neutral-200` |
| `640-1023px` (sm-lg) | Horizontal scroll + `snap-x snap-mandatory`; each node-wrap `snap-center`; show 4-5 nodes per viewport |
| `≥ 1024px` (lg+) | Full horizontal; ALL nodes visible. For ≥8-node series, compress labels to version-tag-only + full title in `aria-describedby` |

## Figma push decision

**DEFERRED TO PHASE 4 CLOSE** — pushing a wireframe-level Figma frame before the React component code exists creates spec/build divergence risk. The `code-connect-automation` feature (PRs #277-#283) auto-scaffolds `.figma.tsx` mappings AFTER component implementation; the `figma-code-connect-publish.yml` workflow auto-runs on push to main.

**Manual Figma fallback** (if Code Connect automation skips due to missing `FIGMA_ACCESS_TOKEN`):

1. Open Figma file `fsjHfFLAHELACZHku8Rfcl` (FitMe Story Web — Design System)
2. Navigate to / create a "Case Study" components page
3. Create a Component `SeriesTimeline` with two variants: `listing` and `detail`
4. Use the token names above; respect dark/light mode variants
5. Capture node IDs; populate `state.json.figma_node_ids`:
   ```json
   {
     "series_timeline_listing": "<node_id_1>",
     "series_timeline_detail_current_node_index_3": "<node_id_2>",
     "series_timeline_mobile_stack": "<node_id_3>"
   }
   ```
6. Update `docs/design-system/figma-code-sync-status.md` with a new row

## Design system compliance

**This is a compose-primitives build** — no new tokens, no new component variants. Reuses:

- `<Tag tone="subtle">` for version markers
- Button focus-ring pattern (`focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand-indigo`)
- All existing `--color-neutral-*`, `--color-brand-indigo`, `--text-*`, `--motion-*` tokens
- Tailwind v4 default scale + breakpoints

If during Phase 4 you find yourself reaching for a custom value, STOP — check [`ux-spec.md` §9 token reuse checklist](../../../.claude/features/case-study-thread-visualization/ux-spec.md) first.

## Code Connect mapping (post-implementation)

After Phase 4 ships `SeriesTimeline.tsx`, run:

```bash
cd /Volumes/DevSSD/fitme-story
node scripts/scaffold-figma-mapping.mjs SeriesTimeline
```

This auto-generates `src/components/case-study/SeriesTimeline.figma.tsx` mapping the React component to the Figma node IDs captured above. The `figma-code-connect-publish.yml` GHA picks it up on push to main and runs `npx figma connect publish`.

**Pre-req:** `FIGMA_ACCESS_TOKEN` repo secret in `Regevba/fitme-story` with scopes `file_content:read` + `file_dev_resources:read` + `file_dev_resources:write`. Per memory: operator setup status unconfirmed as of 2026-05-16; the workflow skips cleanly until the token is set.

---

**Calibration window:** Phase 4 starts 2026-05-22 (post v7.9 promotion decision 2026-05-21). Don't push to Figma or run any of the above before that date.
