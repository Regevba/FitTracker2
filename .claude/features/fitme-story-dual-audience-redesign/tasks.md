# Tasks — fitme-story Dual-Audience Redesign

**Phase:** 2 (Task Breakdown) · Derived from [prd.md](./prd.md) + [design spec](../../../docs/superpowers/specs/2026-06-09-fitme-story-dual-audience-redesign-design.md)
**Repo for implementation:** `fitme-story` (Next.js 16 App Router)

Total: **16 tasks** across 7 groups. Estimated effort ≈ **8.5 dev-days** (excludes Phase 3 UX spec time).

## Group A — Lens engine (foundation, blocks most UI work)

| ID | Title | Type | Skill | Effort (d) | Depends on |
|---|---|---|---|---|---|
| T1 | `getLens()` server util + `fitme_lens` cookie contract + default resolution (`dev`\|`pm`\|`null`; PM default for no-cookie deep links) | backend | dev | 0.5 | — |
| T2 | `LensProvider` in root layout — SSR cookie read → context for server+client, no hydration mismatch | ui | dev | 0.5 | T1 |
| T3 | `LensToggle` segmented `Dev\|PM` control in `SiteHeader` + `MobileNav` — sets cookie + `router.refresh()`, reachable everywhere | ui | dev | 0.5 | T2 |
| T4 | `useLens()` + `<LensGate lens>` helpers + per-page spine-config pattern | ui | dev | 0.5 | T2 |

## Group B — Home rebuild

| ID | Title | Type | Skill | Effort (d) | Depends on |
|---|---|---|---|---|---|
| T5 | Rebuild home `page.tsx`: compact hero (who+what) → origin hook → **lens chooser** → numbers strip → 3 featured studies → "Read the full story → /story". Remove `ThreeWaysIn`. | ui | dev | 1.0 | T4 |

## Group C — /story

| ID | Title | Type | Skill | Effort (d) | Depends on |
|---|---|---|---|---|---|
| T6 | New `/story` route — lens-aware narrative (who → what → started → grew → today); PM=outcomes/process, Dev=mechanisms/architecture | ui | dev | 1.0 | T4 |

## Group D — Case studies

| ID | Title | Type | Skill | Effort (d) | Depends on |
|---|---|---|---|---|---|
| T7 | Backfill `category` + `era` frontmatter on 68 MDX (derive from current slug map; spot-check) | data | dev | 0.5 | — |
| T8 | Rebuild `/case-studies` index: era-grouped collapsible accordion (newest expanded), subject sub-groups, per-era count badges, "expand all", sticky era jump-nav, lens-aware within-era ordering, retain search/filter | ui | dev | 1.5 | T4, T7 |

## Group E — Framework + v7.9.1

| ID | Title | Type | Skill | Effort (d) | Depends on |
|---|---|---|---|---|---|
| T9 | Add **v7.9.1 (2026-06-04)** entry to `src/lib/timeline.ts` `BRIDGE_TIMELINE`; verify framework page renders it | data | dev | 0.25 | — |
| T10 | Lens-aware section ordering on `/framework` (PM: why→outcomes→lifecycle; Dev: architecture→gates→schema) | ui | dev | 0.75 | T4 |

## Group F — Per-page spines + nav

| ID | Title | Type | Skill | Effort (d) | Depends on |
|---|---|---|---|---|---|
| T11 | Nav reorder per lens (`nav.ts` + `SiteHeader` + `MobileNav`) + add `/story` link | ui | dev | 0.5 | T4 |
| T12 | `/pm-flow` + `/design-system` lens spine treatment (PM first-class chapter vs Dev supporting reference) | ui | dev | 0.75 | T4 |

## Group G — Analytics + tests

| ID | Title | Type | Skill | Effort (d) | Depends on |
|---|---|---|---|---|---|
| T13 | Wire GA4 events (`home_lens_select`, `nav_lens_switch`, `story_scroll_depth`, `case_study_era_expand`, `case_study_open`) + update site analytics taxonomy doc | analytics | analytics | 0.75 | T5, T6, T8, T3 |
| T14 | Lens-engine tests — cookie resolution, SSR default (PM for no-cookie), toggle round-trip, no hydration mismatch | test | qa | 0.5 | T1–T4 |
| T15 | Analytics verification — each event fires with correct params + consent-gated per site model | test | qa | 0.5 | T13 |
| T16 | lighthouse-ci on changed routes (`/`, `/story`, `/case-studies`, `/framework`) + a11y pass on `LensToggle` + accordion (keyboard, ARIA, 44px targets, reduce-motion) | test | qa | 0.5 | T5, T6, T8 |

## Dependency graph (critical path)

```
T1 → T2 → {T3, T4}
T4 → {T5, T6, T8, T10, T11, T12}
T7 → T8
{T5,T6,T8,T3} → T13 → T15
{T1..T4} → T14
{T5,T6,T8} → T16
T9 (independent — can land first)
```

**Parallelizable early:** T1 (engine start), T7 (frontmatter backfill), T9 (v7.9.1) have no blockers.
**Heaviest:** T8 (case-study accordion, 1.5d), T5 + T6 (home + story, 1.0d each).

## Phase 3 (UX) note

T2, T3, T5, T6, T8, T10 are UI surfaces — their visual/interaction specs are produced in Phase 3
(ux-spec for the `LensToggle`, the home chooser, the era accordion, the `/story` layout) before
implementation. T1, T4, T7, T9 are non-visual / data and can begin against the spec directly.
