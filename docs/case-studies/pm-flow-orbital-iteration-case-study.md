---
title: "PM-flow LifecycleLoop — orbital design iteration + rollback point"
date_written: 2026-05-24
date: 2026-04-24
dispatch_pattern: single_session_design_iteration
success_metrics:
  - iterations_explored: 3
  - locked_design_lifetime_days: 30
  - hover_reveal_density_mitigation: applied
primary_metric: design_locked_on_alt_b_with_hover_reveal
kill_criteria:
  - user_rejects_final_design_post_lock: "1 instance"
  - hover_reveal_a11y_regression: ">0 WCAG findings"
kill_criteria_resolution: not_fired
kill_criteria_resolution_note: "Alt-B with hover-reveal was locked 2026-04-24 (commit b6fcd75) and has remained in production for 30+ days as of this case study (2026-05-24). No design rejection; no a11y regressions surfaced by `make ui-audit` or fitme-story lint-CI."
framework_version: v7.5
work_type: enhancement
work_subtype: ux_iteration_log
tier_tags_present: true
case_study_type: design_iteration_record
related_prs:
  - "fitme-story#e206f24"
  - "fitme-story#b6fcd75"
pr_citation_exempt:
  - pr_number: "e206f24"
    reason: "Commit SHA, not a PR — fitme-story Alt-A predecessor commit (single-arrow orbital) kept as the rollback target. Cited inline in this case study; included in related_prs for traceability."
  - pr_number: "b6fcd75"
    reason: "Commit SHA, not a PR — fitme-story Alt-B + hover-reveal lock commit. Cited inline; included in related_prs for traceability."
parent_feature: framework-story-site
external_audit_status: not_applicable
---

# PM-flow LifecycleLoop — orbital design iteration + rollback point

> **Status:** Alt-B + hover-reveal LOCKED 2026-04-24. Production commit `b6fcd75` on fitme-story `main`. Rollback target: `e206f24` (Alt-A orbital single-arrow predecessor).
>
> **Companion showcase:** [`fitme-story/content/04-case-studies/17-lego-pmflow.mdx`](https://github.com/Regevba/fitme-story/blob/main/content/04-case-studies/17-lego-pmflow.mdx) is the public-facing design rationale of the PM-flow page as a whole. This case study is the FT2-side iteration log that captures the orbital design exploration specifically — the 3 alternatives evaluated, which one shipped, and the explicit rollback target if a future redesign needs to revert.

## Context

The PM-flow page (`fitme-story.vercel.app/pm-flow`) needed a visual representation of the 10-phase lifecycle that:

- Reads in <10s on first view (HR-glance test from the broader 17-lego-pmflow context)
- Shows the loop nature of the lifecycle (Research → Docs → Learn → back to Research) without using arrows that feel mechanical
- Stays legible at the same level of detail across 4 audiences (HR / PM / dev / academic)
- Renders cleanly in light + dark mode + respects `prefers-reduced-motion`

Three alternatives were explored over a single 2026-04-24 session.

## Iterations

### Alt-A — orbital single-arrow (predecessor; rollback target)

A concentric SVG: inner ring of 10 phase pips, outer ring of skill arcs, a single return arrow from the last phase back to the first. Production at commit `e206f24` (`fix(trust): move chart legend outside SVG to prevent collision with Onboarding label`).

**Strengths:** simple. Single visual element to parse. Loop is implicit in the concentric layout.

**Weaknesses:** the single arrow doesn't capture the BIDIRECTIONAL feedback flow in the framework (some phases feed back to earlier phases beyond the end-to-start loop — e.g., Test → Implement on bug fix; Review → Tasks on plan revision). User wanted to express this.

### Alt-B — release fan-out + return

Extended Alt-A with explicit fan-out arrows representing the bidirectional feedback paths between selected phases. All arrows visible at all times.

**Strengths:** captures the full feedback topology.

**Weaknesses:** visually dense. Read time exceeded the 10s HR-glance target. Casual reader sees a tangle of arrows and bounces.

### Alt-C — horizontal mainline

Different metaphor entirely: 10 phases as a horizontal flow (left → right) with feedback paths as curved arrows above the mainline.

**Strengths:** familiar (timeline-shaped). Phases are individually scannable.

**Weaknesses:** loses the orbital metaphor. Doesn't match the surrounding page's concentric Lego-wall aesthetic. Felt like a different page bolted on.

## What locked

**Alt-B + hover-reveal mode** shipped via commit `b6fcd75` and was confirmed by the user the same session. Locking pass extended the change across 9 follow-up files (skill ecosystem TS, phase-timing chart label, multiple framework MDX docs, case studies that referenced the old phase count) to consolidate the 9 → 10 phase model (Release added at position 9; Learn at position 10).

**Why this combination won:**

1. The orbital metaphor stays (consistent with the surrounding page)
2. The fan-out arrows ARE there (Alt-B's strength — captures bidirectional flow)
3. But the fan-out + return arrows are HIDDEN BY DEFAULT, revealed only on hover/focus of the LifecycleLoop component (mitigates Alt-B's density problem; preserves the <10s HR-glance read)
4. Casual reader sees a clean orbital; engaged reader sees the full topology when they look closer
5. Pairs naturally with `tldr → key_numbers → honest_disclosures` reading staircase the case-study tier system already uses

## Production state at lock

- **Repo:** [`/Volumes/DevSSD/fitme-story`](https://github.com/Regevba/fitme-story)
- **Branch:** `main`
- **Commit:** `b6fcd75` (Alt-B + hover-reveal lock)
- **Predecessor / rollback target:** `e206f24` (Alt-A orbital single-arrow)
- **Live URL:** `fitme-story.vercel.app/pm-flow`

### Locking-pass file inventory (post-b6fcd75)

| File | What changed |
|---|---|
| `src/lib/skill-ecosystem.ts` | cx phaseOwnership P0/P9 (was P0/P8/P9); marketing P0 (was P0/P8); release P7+P8 (was just P7); three purpose strings rewritten |
| `src/components/bespoke/PhaseTimingChart.tsx` | Phase 9 label `Docs` → `Release`; color updated to skill-release emerald |
| `content/02-process-framework/framework-evolution.mdx` | Pipeline text `Merge → Docs` → `Merge → Release` |
| `content/02-process-framework/pm-lifecycle.mdx` | Lifecycle text block + Push Notifications worked example renumbered 9 → 10 phases (Release at 9, Learn at 10) |
| `content/02-process-framework/skills-architecture.mdx` | Phase 8 label → `Release`; routing list updated |
| `content/02-process-framework/project-governance.mdx` | Feature lifecycle row updated |
| `content/04-case-studies/01-onboarding-pilot.mdx` | `(Review, Merge, Docs)` → `(Review, Merge, Release)` |
| `content/04-case-studies/17-lego-pmflow.mdx` | Old description of the diagram (P0 Plan → P9 Docs, feedback arc outside both rings) rewritten to match current Alt-B + hover-reveal implementation |
| `src/app/pm-flow/page.tsx` | Intro paragraph updated; new "Docs vs Release" footnote added under the LifecycleLoop describing the structural-vs-external distinction |

## Rollback procedure (if a future redesign needs to revert)

```bash
cd /Volumes/DevSSD/fitme-story
git checkout main
git reset --hard e206f24      # OR: revert b6fcd75 + later Alt-B follow-ups
git push --force-with-lease    # only if needed; otherwise revert PRs
```

Rolling back also reverts the 9 → 10 phase rename across the 9 locking-pass files above. Decision before reverting: do you want the orbital simplification only (revert just the LifecycleLoop component) OR the entire phase-model change (revert all 9 files)?

## Status check 2026-05-24 (30 days after lock)

- ✓ Alt-B + hover-reveal still in production at `fitme-story.vercel.app/pm-flow`
- ✓ Zero user-reported design issues
- ✓ Zero `make ui-audit` findings introduced (gate stays at 0 P0; P1 drift unchanged on this surface)
- ✓ Lighthouse score on `/pm-flow` maintained 95+ per fitme-story production checks
- ✓ Kill criteria did not fire over the 30-day post-lock window

**Decision retained.** No action needed.

## Why this case study exists

Documents that were previously memory-only (`project_pm_flow_orbital_rollback_point.md`) decay when memory rotates. This case study lifts the iteration history + rollback target to a durable surface so any future designer (operator or agent) considering a redesign of the LifecycleLoop can:

1. Read what was tried before
2. Understand what locked and why
3. Roll back cleanly if needed without re-discovering the rollback commit

Surfaced as UX-R4 from the [ui-ux master plan](../master-plan/ui-ux-master-plan-2026-05-24.md) §3.5 Drift / reconciliation items during the 2026-05-24 codification session.

## Cross-references

- Public showcase: [fitme-story `17-lego-pmflow.mdx`](https://github.com/Regevba/fitme-story/blob/main/content/04-case-studies/17-lego-pmflow.mdx)
- Source memory: `project_pm_flow_orbital_rollback_point.md` (originSessionId: `bc546645-69a8-4f03-a3d2-57d345db934c`)
- Parent feature: `framework-story-site` (state.json `current_phase: closed`)
- Tracked in: [`docs/master-plan/ui-ux-master-plan-2026-05-24.md`](../master-plan/ui-ux-master-plan-2026-05-24.md) §3.5
- Production: `fitme-story.vercel.app/pm-flow`
