# Phase 0 Research — `case-study-comparison-table`

**Stress-test sub-feature ID:** S3-G2

## Why this feature

S3 in the roadmap was "Refine case-study presentation/readability". Reality-check showed Goals 1 (SummaryCard) + 4 (KillCriterionBanner + DeferredItemsList) shipped 2026-04-28 via PR #146. Goal 2 (cross-case-study comparison table) is the cleanest open subgoal — single new component + page route, no backwards-compat concerns.

## What exists today

| Surface | Path | Purpose |
|---|---|---|
| `/case-studies` index page | `src/app/case-studies/page.tsx` | Curated milestone-card view (6 framework inflection points + era-bucketed secondary studies). NOT a comparison table. |
| `/case-studies/[slug]` detail page | `src/app/case-studies/[slug]/page.tsx` | Per-case-study render via FlagshipTemplate / StandardTemplate / LightTemplate. |
| Loader | `src/lib/content.ts` `getAllCaseStudies()` | Returns frontmatter + body for every MDX in `content/04-case-studies/`. |
| Schema | `src/lib/content-schema.ts` | Zod-validated frontmatter shape. |

## Available frontmatter fields per case study

From `FrontmatterShape` (Zod schema):

- `title`, `slug`, `tier`, `date` (optional), `tldr`, `key_numbers[]` (label/value/tier), `kill_criteria[]` (string array), `kill_criterion_fired` (bool), `work_type` (in many but not all studies), `timeline_position.{version,order}` (optional), `framework_version` (some studies).

## Comparison table — what to surface

| Column | Source | Width hint |
|---|---|---|
| Version | `timeline_position.version` (fallback `framework_version`) | narrow (badge) |
| Title | `title` | flex |
| Date | `date` | narrow |
| Work type | `work_type` (default "—") | narrow (pill) |
| Tier | `tier` | narrow (pill, color-coded) |
| TL;DR | `tldr` (truncated to ~120 chars) | flex (largest) |
| Headline number | `key_numbers[0].value` (the lead T1 metric) | narrow |
| Outcome | derived: `kill_criterion_fired ? 'Killed' : 'Active'` | narrow |
| Link | `/case-studies/{slug}` | icon |

## UX shape

- **Sortable** by Version (default), Date, Tier, Work type
- **Filterable** by Tier (flagship/standard/light/appendix; checkbox group) + Framework version range (slider or dropdown)
- **Search** by title + TL;DR substring (client-side)
- **Empty state**: "No case studies match. Adjust filters."
- **Sticky header row** with column labels + sort indicators
- **Responsive**: at < 768 px collapse columns to "Version · Title · Date" with TL;DR + headline number in an expandable row drawer

## Route placement

- New route: `src/app/case-studies/compare/page.tsx`
- Linked from existing index `/case-studies` via small "Compare all 26+ studies →" link near the page header
- Server component for the data fetch (`getAllCaseStudies()`); client component for the interactive sort/filter

## Tokens + components reused

- `<Panel>` chrome from `src/components/control-room/primitives.tsx`
- Tailwind `slate-*` for table chrome, `var(--color-brand-indigo)` for sort indicators
- `lucide-react` icons (ArrowUpDown, Filter, ExternalLink, Search)

## Cross-references

- Existing index: [`src/app/case-studies/page.tsx`](../../../../fitme-story/src/app/case-studies/page.tsx)
- Schema: [`src/lib/content-schema.ts`](../../../../fitme-story/src/lib/content-schema.ts)
- Loader: [`src/lib/content.ts`](../../../../fitme-story/src/lib/content.ts)
- Backlog parent item (S3 in stress test): [`docs/product/backlog.md`](../../../docs/product/backlog.md) "Refine case-study presentation/readability"

## Decision

Build `<CaseStudyComparisonTable />` client component + new server-rendered route at `/case-studies/compare`. Reuse loader; reuse Panel; no new tokens.
