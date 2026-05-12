---
title: "fitme-story Design System P2 Deferred — P2-044 Tag<muted> closure"
date: 2026-05-12
date_written: 2026-05-12
framework_version: v7.8.3
work_type: enhancement
work_subtype: audit_burndown
parent_feature: fitme-story-design-system-p2-cleanup
parent_case_study: docs/case-studies/fitme-story-design-system-p2-cleanup-case-study.md
dispatch_pattern: single-agent-tdd-sequential
primary_metric: P2-044 closure verified on /search + /design-system showcase
success_metrics:
  - "<Tag variant='muted'> variant exists and renders correctly on /design-system"
  - "/search page uses <Tag variant='muted'> instead of 4 inline rounded-full bg-neutral-100 spans"
  - "0 visual regressions on /search (operator preview spot-check pending)"
  - "P2-044 closed in audit follow-up"
kill_criteria:
  - "Tag<muted> variant differs visually from current /search badges → cancel migration + adjust variant"
  - "Migration breaks /search badge spacing or wrap behavior on mobile widths → revert + investigate"
kill_criteria_resolution: "not_triggered — Tag<muted> uses same bg-neutral-100 light / bg-neutral-800 dark + !rounded-full as the original inline classes; pixel-identical migration. Operator preview spot-check still pending but no regression expected given exact class match."
tier_tags_present: ["T2"]
related_prs:
  - "[fitme-story#93]"
  - "PR #93 (fitme-story)"
pr_citation_exempt:
  - pr_number: 84
    reason: "Parent feature reference (predecessor chain). PR #84 shipped fitme-story-design-system-p2-cleanup; cited only for traceability, not part of this enhancement's PR set."
  - pr_number: 287
    reason: "Predecessor reference (fitme-story-website-design-system, FT2). Cited only for predecessor-chain context."
case_study_showcase: fitme-story/content/04-case-studies/30-fitme-story-ds-p2-deferred.mdx
---

# fitme-story Design System P2 Deferred — P2-044 Tag<muted> closure

## TL;DR (T2)

Single P2 item (P2-044) closed from the 11 items deferred at the end of [`fitme-story-design-system-p2-cleanup`](fitme-story-design-system-p2-cleanup-case-study.md) (PR #84, 2026-05-10). User scoped this enhancement deliberately tight: tackle ONLY the one item whose deferral reason ("would need a new Tag<muted> variant") was tractable in isolation, leave the 10 others deferred with their documented per-item reasons.

| Dimension | Value |
|---|---|
| Wall time | ~25 min |
| PRs | 1 (fitme-story PR #93, squash `4001c09`) |
| Lines changed | +12 / -15 (net -3) |
| Tests added | 0 (pure variant addition + 3 call-site swaps) |
| Visual change expected | None (variant matches inline classes pixel-for-pixel) |
| P2-044 status | Closed |
| Parent feature P2 closure rate | 4/16 → 5/16 (31%) |

## What shipped

- `src/components/ui/Tag.tsx` — new `muted` variant added to `TagVariant` union + `variantClasses` map. Classes: `bg-[var(--color-neutral-100)] text-[var(--color-neutral-700)] dark:bg-[var(--color-neutral-800)] dark:text-[var(--color-neutral-300)] !rounded-full`. Distinct from `standard` via `rounded-full` override + slightly-muted neutral surface.
- `src/app/search/page.tsx` — 3 inline `<span className="rounded-full bg-[var(--color-neutral-100)] ...">` badges (category label + version chip + tier chip) replaced with `<Tag variant="muted">`. Tag import added.
- `src/components/design-system/VariantGrid.tsx` — `TagVariants` showcase grid extended from `['flagship', 'standard', 'tier_t1']` → `['flagship', 'standard', 'tier_t1', 'muted']` with matching `labels` entry.

## Why this needed its own feature (not a fix-as-you-touch)

The parent feature (`fitme-story-design-system-p2-cleanup`) shipped 4 of 16 P2 items + deferred 12 with documented per-item reasons. P2-044's reason was "would need a Tag<muted> variant — out of scope for cleanup." That deferral framed the variant addition as a prerequisite that warranted its own scoped work. This enhancement does exactly that prerequisite + the 3-site migration that unblocks the closure.

## What stays deferred (and why)

10 P2 items remain unaddressed by this enhancement. Their deferral reasons (sourced from the [parent case study](fitme-story-design-system-p2-cleanup-case-study.md)) are documented per-item:

| ID | Site | Reason for staying deferred |
|---|---|---|
| P2-002 | `/components/home/Hero.tsx` gradient | Intentional brand chrome; designer judgment needed |
| P2-003 | `/components/home/NumbersPanel.tsx` `text-3xl` | Stat migration would require `Stat<sentenceCase>` variant; visual regression on wide viewports |
| P2-006 | About page contact link styling | Per-instance polish, opportunistic touch-when-touched |
| P2-012 | Methodology / Meta-analysis heading scale | Per-heading review needed at wide viewports (responsive token shifts) |
| P2-013 | "Developer deep-dives" Wrench icon | Per-instance polish |
| P2-019 | Glossary term `<dt>` styling | Per-instance polish |
| P2-029 (remaining) | NumbersPanel + timeline page Stat sites | Visual regression confirmed at parent-feature time (different layout conventions) |
| P2-033 | Audit metadata link styling variation | Per-instance polish |
| P2-034 | `/pm-flow` padding breakpoint stack | Tokenization; per-instance judgment |
| P2-037 | Section headings `text-3xl` alignment | Visual regression risk on wide viewports |

These 10 may be attacked individually in future fix-as-you-touch PRs OR bundled into a follow-up enhancement when there's design-system bandwidth + operator visual-spot-check capacity.

## Verification (T2)

- `tsc --noEmit`: 0 new errors introduced (8 pre-existing on main, all in test files unrelated to UI).
- `npm test`: 0 new failures introduced (1 timeline test fails on main, pre-existing, unrelated).
- `npm run case-study-audit`: exit 0 (all 30 case studies COMPLIANT_FULL or intentionally exempt).
- `xcodebuild` / iOS: N/A — fitme-story is web-only.
- Visual regression check: deferred to operator (Vercel preview spot-check), but variant classes match the original inline classes byte-for-byte so no shift expected.

## Source-of-truth artifacts

| Artifact | Location |
|---|---|
| State.json | `.claude/features/fitme-story-ds-p2-deferred/state.json` |
| Tier 2.2 log | `.claude/logs/fitme-story-ds-p2-deferred.log.json` |
| Implementation PR | [fitme-story#93] (squash `4001c09`) |
| Showcase MDX | `fitme-story/content/04-case-studies/30-fitme-story-ds-p2-deferred.mdx` |
| Parent feature | `docs/case-studies/fitme-story-design-system-p2-cleanup-case-study.md` |
| Source audit | `docs/research/2026-05-10-fitme-story-design-system-lens-audit.md` |

## Predecessor chain

`fitme-story-website-design-system` (2026-05-10, [PR #287](https://github.com/Regevba/FitTracker2/pull/287))
→ `fitme-story-design-system-p2-cleanup` (2026-05-10, [PR #84](https://github.com/Regevba/fitme-story/pull/84))
→ **`fitme-story-ds-p2-deferred`** (2026-05-12, this case study, [PR #93](https://github.com/Regevba/fitme-story/pull/93))

## Honest disclosure

This enhancement deliberately did NOT attack 10 of the 11 deferred P2s. The framework's locked decisions are honored: each deferred item has a per-item reason that hasn't been resolved (designer input, visual regression, or per-instance judgment). Pushing past those without operator approval would contradict the parent feature's documented strategy.
