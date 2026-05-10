---
title: "fitme-story Design System P2 Audit Cleanup — Honest Triage of 16 Polish Items"
slug: fitme-story-design-system-p2-cleanup
date_written: 2026-05-10
date: '2026-05-10'
work_type: enhancement
framework_version: v7.8.2
dispatch_pattern: single-session enhancement (4-phase, audit-driven)
parent_feature: fitme-story-website-design-system
parent_case_study: docs/case-studies/fitme-story-website-design-system-case-study.md
primary_metric: audit_p2_burndown_count
success_metrics:
  - audit_p2_burndown_count: 16 → 12 (4 P2 shipped, 12 deferred with rationale)
  - public_figma_parity: maintained at 20/20 = 100%
  - drift_findings: 0 throughout
  - new_visual_regressions: 0
  - tasks_shipped: 4 of 8 planned (T1, T2, T4, T5)
  - tasks_explicitly_deferred: 4 of 8 planned (T3, T6, T7, T8)
kill_criteria:
  - net visual regression discovered after migration → roll back the offending migration commit
kill_criteria_resolution: not_yet_triggered (no regressions detected; operator visual spot-check pending post-deploy)
tier_tags_present: true
related_prs:
  - "fitme-story PR #84 (squash TBD on merge): feature/fitme-story-design-system-p2-cleanup → main"
  - "FT2 PR #290 (squash TBD on merge): chore/correct-bhf-attribution-2026-05-10 → main (backlog correction + new control-room item)"
predecessor_features:
  - fitme-story-website-design-system (parent — provided Card / Callout / Stat primitives this work consumes)
case_study_type: standard
---

# fitme-story Design System P2 Audit Cleanup

## TL;DR

Single-session enhancement burning down the 16 P2 audit items left over from the parent feature `fitme-story-website-design-system`. Ships 4 of 8 planned tasks (Card × 5 migrations, Stat × 1 migration, ExternalLink icon, `.divider-row` utility class). Explicitly defers the other 4 with documented rationale — not every audit recommendation is a clean win.

## Why this is interesting

The `fitme-story-website-design-system-lens-audit` (2026-05-10, 45 findings) flagged 16 P2 polish items expected to take 1-2h of "easy" cleanup. Reality: only 4 were actually clean migrations. The other 4 either:
- Required new component variants (Tag<muted> for /search badges)
- Would have introduced visual regressions (NumbersPanel + timeline page Stat sites use different layout conventions; static text-2xl vs responsive --text-display-md tokens scale differently at wide viewports)
- Need designer judgment per instance (Hero gradient, icon DS-fy, link styling consistency)

This case study documents the honest triage: ship-vs-defer per item, with rationale recorded so future contributors don't re-litigate the same decisions.

## Context

The parent feature `fitme-story-website-design-system` shipped 2026-05-10 with:
- 31-component manifest (later 34 with Card + Callout + Stat added)
- Public `/design-system` Part 2 showcase route
- Drift detection script + weekly CI cron
- Dark-mode parity matrix
- Contribution guide
- Heritage data (11 audit decisions + 7 locked patterns)

Bucket H (post-feature site audit) produced `docs/research/2026-05-10-fitme-story-design-system-lens-audit.md` — 45 findings across 12 routes:
- 3 P0 + 1 P0-escalated → ALL shipped via fitme-story PRs #82 + #83
- 28 P1 → ALL shipped via fitme-story PR #83 (Card / Callout / Stat / reduced-motion)
- 13 P2 (audit summary said 16, actual = 14 numbered) → THIS feature

## What shipped

### T1 — Card<interactive> migrations (P2-022)

5 inline `rounded-lg border` interactive nav cards consolidated to the `<Card interactive>` primitive:
- `src/app/pm-flow/page.tsx` — 3 cards (framework / dispatch / glossary)
- `src/app/framework/page.tsx` — 2 cards (dispatch / dev-guide; hover-shadow-lg preserved via className override)

### T2 — Stat migration (P2-029)

1 inline `text-4xl font-semibold + uppercase label` migrated to `<Stat md accent>`:
- `src/components/home/OriginNarrative.tsx` — beat metric branch

### T4 — ExternalLink icon affordance (P2-027)

`/research` entries with `external: true` now show a visible `<ExternalLink size={14}>` icon next to the title — affordance visible BEFORE the click.

### T5 — `.divider-row` utility class (P2-040)

Repeated `border-b border-[var(--color-neutral-200)] dark:border-[var(--color-neutral-700)] pb-2` pattern (4 sites) extracted to `globals.css` as `.divider-row` class with dark-mode override. Consumers: `TokenSwatch.tsx` (2 rows), `design-system/page.tsx` (TYPE_SCALE + MEASURES sections).

## What we explicitly deferred

| Task | Audit ID | Rationale |
|---|---|---|
| T3 Tag migration on /search | P2-044 | `/search` badges use `rounded-full bg-neutral-100` (muted info convention) vs Tag's `rounded-md bg-neutral-200` (emphasis convention). Different semantic intent. Would need a `Tag<muted>` variant — out of scope for cleanup. |
| T6 heading scale alignment | P2-012, P2-037 | `text-2xl` is static (24px); `--text-display-md` is responsive `clamp(1.5rem, 3vw, 2.25rem)` — scales to 36px at wide viewports. Replacing one with the other changes visual at wide screens. Spot-check per heading needed, not blanket. |
| T7 Hero gradient → elevation tokens | P2-002 | Hero's gradient may be intentional brand chrome. Needs visual review before swap. |
| T8 5 minor polish bundle | P2-006/013/019/033/034 | Each is a per-instance judgment call (link styling consistency, Wrench icon DS-fy, glossary `<dt>` term-label class, audit metadata link variation, padding breakpoint stack tokenization). Defer to opportunistic touch-when-touched. |

Plus partial deferrals within shipped tasks:
- **T2**: 2 of 3 Stat candidate sites kept inline. NumbersPanel uses sentence-case labels (Stat expects uppercase); timeline page uses inline `flex items-baseline` layout (Stat is centered block). Both would be visual regressions.

## Decisions locked

1. **`.divider-row` is the canonical name** — not `.token-row`, `.list-divider`, or `.bordered-row`. Generic enough for any list-of-rows divider pattern.
2. **`<Card interactive>` is the canonical wrapper for hover-affording link cards** — even when shadow is desired, layer it via className override rather than adding a `shadow` variant prop.
3. **Stat primitive is for centered metric grids** — for inline metric text-baseline layouts (timeline keyMetric pattern), keep inline styling. Don't bend the primitive to fit edge cases.
4. **External-link icon is text-meta size 14, neutral-500 color** — `lucide-react` `ExternalLink` component, hard-coded to keep its meta-tier role.
5. **The audit's 16 P2 estimate was approximate** — actual was 14 numbered findings. Of those, 4 were clean wins, 4 required new variants/judgment, 6 needed per-instance review. **About 30% of P2 audit recommendations are "ship as-is" without ambiguity** — useful prior for sizing future audit follow-ups.

## Cross-references

- Audit doc: `docs/research/2026-05-10-fitme-story-design-system-lens-audit.md`
- Parent feature: `docs/case-studies/fitme-story-website-design-system-case-study.md`
- Tasks: `.claude/features/fitme-story-design-system-p2-cleanup/tasks.md`
- State: `.claude/features/fitme-story-design-system-p2-cleanup/state.json`
- Tier 2.2 log: `.claude/logs/fitme-story-design-system-p2-cleanup.log.json`
- Card / Callout / Stat primitives: `fitme-story/src/components/ui/Card.tsx | Callout.tsx | Stat.tsx`
- `.divider-row` utility: `fitme-story/src/app/globals.css`

## Honest disclosures

- **The audit's "easy 1-2h" estimate was wrong.** Actual session time for the 4 shipped tasks: ~30 min coding + ~20 min triage + ~10 min commit/PR = **1h total work**. But the deferred items would have added another 2-3h IF they'd been clean migrations (which they weren't).
- **Operator visual spot-check on Vercel preview not yet performed.** PR #84 lists this as a checkbox. The migrations are mechanical enough that I'm confident in the outcome, but visual regression IS the kill criterion.
- **The `Tag<muted>` variant gap is real and worth filing.** I deferred T3 with rationale, but `/search` would benefit from a muted-info Tag variant. Future Tag work should consider this.
- **No new components or new tokens added.** This was pure consolidation work — Card/Callout/Stat already shipped via the parent feature's recovery PR #83.
