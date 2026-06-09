# Design Spec — fitme-story Dual-Audience Redesign

**Date:** 2026-06-09
**Feature:** `fitme-story-dual-audience-redesign`
**Status:** Phase 0 design — approved in brainstorm, pending written-spec review
**Repos:** implementation in `fitme-story`; `state.json` + this spec in `FitTracker2` (`state_owner: ft2`)
**Companion:** `.claude/features/fitme-story-dual-audience-redesign/research.md`

---

## 1. Problem

From the home page it is not clear (a) which audience the site addresses, (b) what the project
is and what it does / measures / shows. The site currently targets four audiences (HR, PM, Dev,
Academic) and opens with story-framing that delays the who/what answer. The 68-study case-study
list is a single long scroll, so recent work is hard to reach. The framework timeline is missing
its latest version (v7.9.1).

## 2. Goals

1. Reorient the entire site around **two audiences: developers and product managers**.
2. Make the audience choice explicit, persistent, and switchable — and let it define the
   **narrative spine** of every page (which content leads vs supports).
3. Rebuild the home page to answer who / what / how-it-started / how-it-grew compactly, with a
   lens choice early.
4. Move the deep narrative to a lens-aware `/story` page.
5. Reorganize case studies into an era-grouped collapsible layout so recent work is instantly
   reachable.
6. Add the missing **v7.9.1** entry to the framework timeline.

**Non-goals:** the gated `/control-room/*` operator surface; the iOS app; authoring any NEW
case-study content (this is re-presentation + the v7.9.1 factual add). `/about` is retained
alongside `/story`.

## 3. The Lens system (core architecture)

### 3.1 Concept
A single persistent value `lens ∈ {dev, pm}` governs the whole site. The lens is **spine-defining**:

- **PM lens spine:** product/process leads — `/pm-flow`, lifecycle, design system, outcomes/metrics
  are first-class chapters. Engineering (architecture, gates, schema, Code Connect) appears as
  supporting depth (collapsed/secondary sections, "go deeper" affordances).
- **Dev lens spine:** engineering leads — framework architecture, gate codes + hooks, `state.json`
  schema, dev-guide, Code Connect. Product/process becomes the motivating context.

### 3.2 Mechanism
- **Storage:** cookie `fitme_lens` (so it is readable during SSR). Mirrored to `localStorage`
  only as a convenience; the cookie is the source of truth for rendering.
- **Server render:** the root layout (server component) reads the cookie and provides `lens`
  down the tree (`LensProvider`). Pages/sections render the correct spine server-side — **no
  flash of wrong content, no hydration mismatch** (lens is never derived client-only).
- **Switching:** a segmented `Dev | PM` control in the site header sets the cookie and calls
  `router.refresh()` so the server re-renders for the new lens. Available on every page.
- **First visit / no cookie:** the **home page** renders neutral with the chooser prominent.
  Any other page deep-linked without a cookie defaults to the **PM lens** and shows a
  dismissible "viewing as PM — switch to Dev" hint.

### 3.3 Implementation units
| Unit | Responsibility | Depends on |
|---|---|---|
| `lens` cookie + `getLens()` server util | Single source of truth; default resolution | `next/headers` cookies |
| `LensProvider` (root layout) | Inject `lens` into the tree for server + client components | `getLens()` |
| `LensToggle` (header) | Render current lens; switch + refresh | cookie write, `useRouter` |
| `useLens()` / `<LensGate lens>` helpers | Let any section declare lens-variant content/ordering | `LensProvider` |
| Per-page spine config | Each lens-aware page declares which sections lead vs support per lens | `useLens()` |

No page is duplicated; lens-aware pages reorder / relabel / show-hide sections.

## 4. Information architecture (page by page)

| Page | Change | Lens behavior |
|---|---|---|
| `/` Home | **Rebuilt, compact.** Hero (who + what) → 1-paragraph origin hook → **lens chooser** high up → numbers strip → 3 featured case studies → "Read the full story → /story". Remove the 4-persona `ThreeWaysIn`; keep only Dev + PM (expressed as the chooser). | Neutral until chosen; after choice, featured studies + copy emphasis follow the lens. |
| `/story` | **New page.** Deep narrative: who → what → how it started (the `/pm-flow` seed) → how it grew (timeline) → today. | PM: outcomes/process/lifecycle emphasis. Dev: mechanisms/architecture emphasis. |
| `/about` | **Kept as-is** (operator decision — alongside `/story`, no redirect for now). | Light lens tint only. |
| `/framework` | Lens-aware ordering. **+ add v7.9.1 to the timeline.** | PM: why → outcomes → lifecycle, architecture collapsed. Dev: architecture → gates/hooks → schema lead. |
| `/case-studies` | **Rebuilt** to era-grouped collapsible layout (§5). | Card emphasis + within-era ordering via existing `persona_emphasis` frontmatter. |
| `/pm-flow` | First-class **PM-lens chapter**; surfaced prominently in PM-lens nav. Dev lens keeps it as supporting reference. | Spine member (PM), supporting (Dev). |
| `/design-system` | First-class **PM-lens chapter** ("why a design system, what it guarantees") AND Dev reference (tokens/components/Code Connect). | PM: rationale/guarantees lead. Dev: implementation detail leads. |
| `/research`, `/glossary`, `/trust` | Shared content; lens-tinted intro line only. | Minimal. |
| Nav | Reorders per lens. PM order leads with PM Flow / Case Studies / Framework / Design System. Dev order leads with Framework / Dev Guide / Design System / Case Studies. | Per-lens ordering + labels. |
| `/control-room/*` | **Untouched** (out of scope). | n/a |

## 5. Case studies — era-grouped, collapsible

- **Primary axis: era** derived from `timeline_position.version`:
  `v7.x` (newest, **expanded by default**) → `v6.0` → `v5.x` → `v4.x` → `v2.0` (collapsed).
- **Secondary axis inside each era: subject** — Framework / Design System / Product Features /
  Meta & Methodology / Dev deep-dives.
- **Within a subject:** order by `persona_emphasis` for the active lens, then date desc.
- **UX:** accordion with per-era count badges, "expand all", sticky era jump-nav, existing
  search/filter retained. Featured/milestone studies may pin to the top of the newest era.
- **Data backfill:** add explicit `category` and `era` frontmatter fields to the 68 MDX files
  (today subject is inferred by slug-regex). Backfill is derived from the current slug-pattern
  map, then spot-checked. Grouping then reads frontmatter, not regex.

## 6. v7.9.1 timeline fix

`fitme-story/src/lib/timeline.ts` `BRIDGE_TIMELINE` currently ends at **v7.9 (2026-05-21)**.
Add **v7.9.1 (2026-06-04)** — build-window release; 8 ships / 14 PRs; 0 new enforcement gates
(observability surfaces, dev-env lint, F16 try-repo harness, F17 last_fired_at index, F2 Phase 0
reality-check, launchd-drift extension, deployed-URL probe). Ensure the framework page renders it.

## 7. Analytics (requires_analytics = true)

New GA4 events (screen-prefixed per the taxonomy convention; finalized in the PRD Analytics Spec):
- `home_lens_select` (param: `lens`) — first/explicit lens choice on home.
- `nav_lens_switch` (params: `from_lens`, `to_lens`) — header toggle use (global, so `nav_`/global scope).
- `story_scroll_depth` (param: `section`) — `/story` engagement.
- `case_study_era_expand` (params: `era`, `expanded`) — era accordion interaction.
- `case_study_open` already/likely exists — verify + reuse, add `era` + `lens` params if missing.

Primary metric instrumentation = `home_lens_select` / home `page_view`.

## 8. Success metrics & kill criteria (baselined in PRD)

- **Primary:** lens-selection rate among home visitors. **Secondary:** home bounce reduction;
  case-study reach depth; `/story` scroll completion.
- **Guardrails:** site nav depth not down; lighthouse perf on changed routes not regressed.
- **Kill criteria:** lens-selection below floor AND home bounce worsens after 30 days → revert
  to a neutral home; lens switching causing measurable confusion → simplify.

## 9. Rollout / sequencing

Lens engine first (cookie + `getLens` + `LensProvider` + `LensToggle`), then home rebuild,
then `/story`, then case-study era-grouping + frontmatter backfill, then per-page spines + nav,
then the v7.9.1 timeline entry. Each ships behind the normal CI gates (build, lint,
lighthouse-ci on changed routes, analytics verification).

## 10. Open questions (carried into PRD/UX)

1. Exact lens-selection floor + bounce target — set from GA4 baseline in Phase 1.
2. Whether `/pm-flow` and `/design-system` get a dedicated PM-lens "chapter" wrapper vs.
   in-place re-narration — decide in Phase 3 UX.
3. Whether to pin a small set of milestone studies above the newest era, or rely purely on
   era grouping — decide in Phase 3 UX.
