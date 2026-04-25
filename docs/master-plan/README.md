# Master Plan & Handoffs

> The master plan for FitMe's overall direction and the handoff documents that capture state-of-repo checkpoints between sessions. Kept in one folder so anyone resuming work (human or agent) can find the current plan and the most recent handoff without hunting through scattered folders.

> **Framework state at last update:** PM Framework v7.6 (Mechanical Enforcement, shipped 2026-04-25). Canonical entry points:
> - Developer guide (v1.0 → v7.6 technical reference): [`../architecture/dev-guide-v1-to-v7-6.md`](../architecture/dev-guide-v1-to-v7-6.md)
> - v7.6 case study: [`../case-studies/mechanical-enforcement-v7-6-case-study.md`](../case-studies/mechanical-enforcement-v7-6-case-study.md)
> - v7.5 case study: [`../case-studies/data-integrity-framework-v7.5-case-study.md`](../case-studies/data-integrity-framework-v7.5-case-study.md)
> - Class B mechanically-unclosable gaps: [`../case-studies/meta-analysis/unclosable-gaps.md`](../case-studies/meta-analysis/unclosable-gaps.md)
> - Tier 3.3 external-replication invitation: [GitHub issue #142](https://github.com/Regevba/FitTracker2/issues/142) (pinned, the explicit final v7.6 deliverable)
> - Pre-v7.5 Codex SSD audit (foundational input): [`codex-ssd-audit-2026-04-19.md`](codex-ssd-audit-2026-04-19.md)

---

## What goes here

1. **Master plan documents** — the canonical roadmap, the RICE-prioritized backlog, and any strategic planning docs that span multiple features.
2. **Handoff documents** — timestamped snapshots written at end-of-session or before branch transitions. Each handoff captures: what shipped, what's in flight, what's blocked, and what the next session should pick up.
3. **Branch review documents** — pre-merge reviews that compare a feature branch against main, identify risks, and document the merge plan.

## What doesn't go here

- Feature PRDs — those live in `docs/product/prd/`
- Skill documentation — that lives in `docs/skills/`
- Design system docs — `docs/design-system/`
- Build prompts for other agents — `docs/prompts/`
- Setup guides (SSD, Firebase, etc.) — live in `docs/setup/`
- Session summaries that are diary-style — those are handoffs only if they include "next session picks up X" actionables

## Current contents

### Master plan

| File | Date | Purpose |
|---|---|---|
| `master-plan-2026-04-15.md` | 2026-04-15 · updated 2026-04-20 | **CURRENT master plan.** Adds all v4.3 → v7.0 work, M-series decomposition sprints, and the 185-finding audit remediation program. |
| `master-plan-2026-04-06.md` | 2026-04-06 | DEPRECATED — superseded by 2026-04-15. Kept as a historical snapshot. |
| `master-plan-reconciled-2026-04-05.md` | 2026-04-05 | DEPRECATED — superseded by 2026-04-06, then 2026-04-15. |
| `master-backlog-roadmap.md` | living | RICE-prioritized 19-task roadmap. Updated continuously. Referenced by `docs/product/backlog.md`. |

### Handoffs (most recent first)

| File | Date | What it captures |
|---|---|---|
| `work-checkpoint-2026-04-23-staging-auth.md` | 2026-04-23 | Current staging-auth/runtime-verification handoff, including remote baseline vs local-only checkpoint state |
| `work-checkpoint-2026-04-06.md` | 2026-04-06 | Runtime verification checkpoint before SSD move |
| `session-summary-2026-04-06.md` | 2026-04-06 | Session summary covering the branch state at that snapshot |
| `onboarding-v2-merge-timeline.md` | 2026-04-07 | Timeline of the 4-day branch consolidation that shipped PR #59 |
| `stabilization-report-2026-04-05.md` | 2026-04-05 | Build repair + stabilization notes |
| `branch-review-2026-04-05.md` | 2026-04-05 | Pre-merge review of the stabilization branch |
| `ui-integration-pr-draft.md` | (draft) | Pre-PR draft for a UI integration pass |
| `resume-handoff-2026-03-29.md` | 2026-03-29 | Earlier resume-handoff doc from before the current stabilization pass |

## How to use this folder

**If you're resuming work:**
1. Start by reading the most recent handoff (top of the list) to understand current state
2. Cross-reference with the master plan to confirm priorities haven't shifted
3. Check `docs/product/backlog.md` for the current Done table and In Progress items
4. Check `state.json` in `.claude/features/{active-feature}/` for the live phase tracker

**If you're writing a new handoff:**
1. Create `{YYYY-MM-DD}-{purpose}-handoff.md` — timestamp + what the handoff is for
2. Include sections: "What shipped", "What's in flight", "What's blocked", "Next session picks up"
3. Reference the branch + commit SHA at the top so the reader can reconstruct the state
4. Link to the relevant `state.json` and feature folder

**If you're updating the master plan:**
1. Don't overwrite the previous version — create a new dated file
2. Mark the old one as superseded in a header comment
3. Update `docs/product/backlog.md` and `master-backlog-roadmap.md` to reflect the new plan

## Related documents

- [`../product/backlog.md`](../product/backlog.md) — the Done / In Progress / Planned / Backlog tracker (referenced by the master plan)
- [`../product/PRD.md`](../product/PRD.md) — the product requirements doc (referenced by the master plan)
- [`../skills/pm-workflow.md`](../skills/pm-workflow.md) — the PM workflow skill that drives every feature through the plan
- [`../../CLAUDE.md`](../../CLAUDE.md) — project-wide rules
- [`../../CHANGELOG.md`](../../CHANGELOG.md) — the milestone history (chronological)
