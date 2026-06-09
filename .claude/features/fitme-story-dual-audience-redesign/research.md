# Research — fitme-story-dual-audience-redesign

**Phase:** 0 (Research & Discovery)
**Date:** 2026-06-09
**Work type:** Feature (full lifecycle) · `has_ui: true` · `requires_analytics: true`
**Repos:** code → `fitme-story`; canonical `state.json` + spec → `FitTracker2` (`state_owner: ft2`)

---

## 1. What is this solution?

The fitme-story public site currently speaks to four audiences at once (HR, PM, Dev,
Academic) and opens with a story-framing hero that doesn't quickly answer **"who is this,
what is this project, and what is it for?"** Operator feedback: from the home page it is
not clear which audience the site addresses, nor what the project is / does / measures / shows.

This feature reorients the entire site around **two audiences — developers and product
managers** — via a persistent **audience lens** (`dev | pm`) that the visitor chooses early
and can switch anytime from the header. The lens is not cosmetic: it defines the **narrative
spine** of the whole site.

- **PM lens:** the product/process story leads — `/pm-flow`, the lifecycle, the design
  system, and outcomes are first-class chapters. Engineering (architecture, gates, schema)
  is present as *supporting depth*, not the headline.
- **Dev lens:** the spine flips — framework architecture, gates, `state.json` schema, the
  dev-guide, and Code Connect lead; the product/process becomes the context that motivated them.

Alongside the lens, the home page is rebuilt to answer who/what/origin/growth compactly, a
new lens-aware `/story` page carries the deep narrative, the 68-study case-study list is
reorganized into an era-grouped collapsible layout (so recent work is reachable without
endless scroll), and the framework timeline gets its missing **v7.9.1** entry.

## 2. Why this approach? (problem → pain points)

| Pain point (operator feedback) | How this addresses it |
|---|---|
| "Not clear which audience the site speaks to" | Explicit Dev/PM lens chosen up front; every page declares a spine for the active audience |
| "Not clear what the project is / does / measures / shows" | Rebuilt compact home answers who/what/origin/growth; deep `/story` narrative per lens |
| Case-study scroll is too long to reach recent work | Era-grouped accordion; newest era expanded, older eras collapsed; sticky era jump-nav |
| Four diluted personas | Narrowed to the two that matter — Dev + PM |
| v7.9.1 missing from the framework timeline | Factual gap closed |

## 3. Why this over alternatives?

### 3a. Audience-POV mechanism (the load-bearing decision)

| Approach | Pros | Cons | Effort | Chosen? |
|---|---|---|---|---|
| **Persistent lens switch** (cookie-backed, server-rendered, header toggle; every page reorders/relabels/reprioritizes for the lens) | Honors "view the *whole* site from a POV"; single content tree; switchable anytime; SSR avoids content-flash | Each lens-aware page needs variant logic; must define a spine per page | Medium | **✓ Yes** |
| Onboarding routing only (home choice picks a starting door; pages are shared afterward) | Simplest | Doesn't deliver a site-wide POV; "review the whole site as a dev/PM" unmet | Low | No |
| Two parallel page trees (`/dev/*`, `/pm/*`) | Maximum tailoring | ~2× pages to build + keep in sync; duplicated case-study/framework content | High | No |

**Decision:** persistent lens switch. Confirmed with operator. Refinement: the lens governs
the *narrative spine* (which content leads vs supports), not just per-section reordering.

### 3b. Persona scope

| Approach | Chosen? |
|---|---|
| **Dev + PM only** (drop HR + Academic entry points) | **✓ Yes** (operator-confirmed) |
| Dev + PM primary, HR/Academic as a footer link | No |
| Keep all 4, lead with Dev + PM | No |

### 3c. Case-study grouping

| Approach | Pros | Cons | Chosen? |
|---|---|---|---|
| **Era/version, collapsible** (newest expanded; subject sub-group inside) | Solves long-scroll directly; recent work instant; preserves chronological narrative | Needs era/category data on each study | **✓ Yes** |
| Subject/area first, era secondary | Good for "all design-system work" | Buries chronology; recent work still scattered | No |
| Filterable grid + featured | Most flexible | Least linear-narrative; weaker story | No |

### 3d. Home depth

| Approach | Chosen? |
|---|---|
| **Compact home + early lens choice** (deep narrative offloaded to `/story`) | **✓ Yes** |
| Long-scroll narrative home (story IS the home) | No |

## 4. External sources & market examples (dual-audience docs/showcase patterns)

How comparable products serve two distinct audiences from one surface:

- **Stripe** — separate but linked "for developers" (API docs) and "for businesses"
  (product/outcomes) framings; a persistent product-vs-docs distinction. Lesson: make the
  audience switch explicit and always-available, not a one-time fork.
- **Vercel** — marketing (outcomes, for decision-makers) vs docs (mechanisms, for builders),
  with consistent shell + nav. Lesson: shared design shell, different content spine.
- **Linear** — "Method" (process/PM narrative) sits alongside "Docs" (builder reference);
  a changelog that groups by release era. Lesson: era-grouping for long changelogs;
  process-narrative as a first-class artifact (validates the PM-lens spine).
- **Notion** — persona landing pages (engineering / product / design) that reframe the same
  capabilities. Lesson: the same artifacts can be re-narrated per audience without duplicating them.

**Pattern takeaways adopted:** (1) explicit + persistent audience switch; (2) shared design
shell, different narrative spine; (3) era-grouped collapsible lists for long histories;
(4) re-narrate shared artifacts per lens rather than duplicating pages.

## 5. UI / design direction (Phase 3 will formalize)

- **Lens toggle:** a segmented `Dev | PM` control in the site header (and echoed in the
  home chooser). Must be reachable on every page; reflects the active lens; persists.
- **Home:** hero (who + what) → one-paragraph origin hook → prominent lens chooser →
  numbers strip → 3 featured case studies → "Read the full story → /story".
- **/story:** sectioned narrative (who → what → how it started → how it grew → today),
  lens-tailored emphasis.
- **/case-studies:** accordion of eras with count badges, "expand all", sticky era jump-nav,
  existing search/filter retained; cards emphasize per-lens fields (existing
  `persona_emphasis` frontmatter drives ordering within an era).
- Reuse the existing fitme-story design system / control-room component vocabulary; the lens
  toggle + accordion are the main new components.

## 6. Data & demand signals

- Direct operator feedback (this session): home page fails the "who/what/for-whom" test.
- 68 case studies in one list → reaching recent work requires long scroll (structural).
- Site already instruments GA4 (home Hero, Timeline modes, ThreeWaysIn personas), so
  lens-selection and case-study-reach metrics are measurable from day one.

## 7. Technical feasibility

- **Stack:** Next.js 16 App Router (fitme-story). Lens fits the framework cleanly:
  cookie read in the root layout (server component) → render correct spine, no flash.
  Header toggle sets cookie + `router.refresh()`.
- **Lens engine:** `LensProvider` + lens-aware section components; pages declare a spine per
  lens. No page duplication.
- **Case-study grouping:** promote subject/era from fragile slug-regex to explicit
  `category` + `era` frontmatter on the 68 MDX files (bounded mechanical backfill), then
  group data-driven.
- **Cross-repo bookkeeping:** `state.json` + design spec live in FitTracker2 (`state_owner:
  ft2`); implementation branch `feature/fitme-story-dual-audience-redesign` in fitme-story.
- **Risks/unknowns:** (1) SSR cookie read must avoid hydration mismatch — resolved by
  reading the cookie server-side and passing the lens down, never deriving it client-only;
  (2) default lens for no-cookie deep-links → PM, with a dismissible "switch to Dev" hint;
  (3) frontmatter backfill accuracy — mitigate by deriving from existing slug-pattern map
  then spot-checking; (4) lighthouse-ci budget on the new home/story/case-study routes.

## 8. Proposed success metrics (Phase 1 PRD will baseline from GA4)

- **Primary:** % of home-page visitors who select a lens (engagement with the new core
  wayfinding mechanism).
- **Secondary:** home bounce-rate reduction; case-study reach depth (sessions opening
  studies beyond the newest era); `/story` completion (scroll depth).
- **Guardrails:** overall site nav depth must not drop; lighthouse perf on changed routes
  must not regress; no increase in single-page bounce on key pages.
- **Kill criteria:** lens-selection below floor AND home bounce worsens after 30 days →
  revert to neutral home; lens switching causing measurable confusion → simplify.

## 9. Decision

Proceed with the **persistent lens** design (spine-defining, not cosmetic), **Dev + PM only**,
**era-grouped collapsible case studies** backed by new frontmatter, a **compact home** with the
deep narrative on a lens-aware **/story** (keeping `/about` alongside), and close the **v7.9.1**
timeline gap. Full design captured in
`docs/superpowers/specs/2026-06-09-fitme-story-dual-audience-redesign-design.md`.
Next: Phase 1 PRD with GA4-baselined metrics + Analytics Spec gate (lens events).
