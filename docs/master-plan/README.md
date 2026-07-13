# Master Plan & Handoffs

> The master plan for FitMe's overall direction and the handoff documents that capture state-of-repo checkpoints between sessions. Kept in one folder so anyone resuming work (human or agent) can find the current plan and the most recent handoff without hunting through scattered folders.

> **Framework state at last update:** PM Framework **v7.10** (GATE_COVERAGE_ZERO observability + field-rename closure, shipped 2026-06-10). Lineage: v7.9 promotion 2026-05-21 → v7.9.1 build window 2026-06-04 → v7.10 2026-06-10. Current canonical counts: **131 features · 32 instrumented gates (20 write-time + 9 cycle-time + 2 W9 hooks + 1 standalone; 34 live), 28 firing · 0 integrity findings** (reconciled 2026-07-13) — see [`../FRAMEWORK-FACTS.md`](../FRAMEWORK-FACTS.md). Canonical entry points:
> - Developer guide (v1.0 → v7.10 technical reference): [`../architecture/dev-guide-v1-to-v7-7.md`](../architecture/dev-guide-v1-to-v7-7.md) (filename retained for ref-stability; content tracks v7.10)
> - Feature lifecycle event catalog (companion): [`../architecture/feature-lifecycle-event-catalog.md`](../architecture/feature-lifecycle-event-catalog.md) — every event/log/gate fired during a feature's 9-phase lifecycle, with 2 mermaid flow diagrams
> - **v7.10 cold-start entrypoint (current):** [`../../.claude/entrypoints/framework-v7-10.md`](../../.claude/entrypoints/framework-v7-10.md) — GATE_COVERAGE_ZERO observability + field-rename closure
> - v7.8.4 cold-start entrypoint: [`../../.claude/entrypoints/framework-v7-8-4.md`](../../.claude/entrypoints/framework-v7-8-4.md) — pre-v7.9 calibration + PR_CACHE_STALE gate + TIER_TAG heuristic narrowing
> - v7.8.3 cold-start entrypoint: [`../../.claude/entrypoints/framework-v7-8-3.md`](../../.claude/entrypoints/framework-v7-8-3.md) — cross-repo state-sync release umbrella
> - v7.8.1 case study: [`../case-studies/framework-v7-8-branch-isolation-case-study.md`](../case-studies/framework-v7-8-branch-isolation-case-study.md) — 3 new write-time gates + 3 cycle-time advisories, first feature shipped via v7.8 protocol (Mechanism C + isolated worktree)
> - v7.8 Bridge case study: [`../case-studies/framework-v7-8-bridge-case-study.md`](../case-studies/framework-v7-8-bridge-case-study.md)
> - v7.7 case study: [`../case-studies/framework-v7-7-validity-closure-case-study.md`](../case-studies/framework-v7-7-validity-closure-case-study.md) — 5 new check codes, framework-health dashboard, cache_hits writer-path closed
> - v7.6 case study: [`../case-studies/mechanical-enforcement-v7-6-case-study.md`](../case-studies/mechanical-enforcement-v7-6-case-study.md)
> - v7.5 case study: [`../case-studies/data-integrity-framework-v7.5-case-study.md`](../case-studies/data-integrity-framework-v7.5-case-study.md)
> - Honesty ledger (live append-only): [`../case-studies/framework-honesty-ledger.md`](../case-studies/framework-honesty-ledger.md) — FT2-FH-002 added 2026-05-12 (v7.8.3 PR-cache-staleness silent-pass)
> - Class B mechanically-unclosable gaps (4 remain after v7.8.1; Gap 3 heuristic narrowed in v7.8.4): [`../case-studies/meta-analysis/unclosable-gaps.md`](../case-studies/meta-analysis/unclosable-gaps.md)
> - Tier 3.3 external-replication invitation: [GitHub issue #142](https://github.com/Regevba/FitTracker2/issues/142) (pinned)
> - v8 candidates (deferred at v7.8.1 ship): [`../superpowers/specs/2026-05-07-branch-isolation-out-of-scope.md`](../superpowers/specs/2026-05-07-branch-isolation-out-of-scope.md)
> - **Infra roadmap (v7.9 promotion + v8.x docket + HADF Phase 2-bis calendar):** [`infra-master-plan-2026-05-12.md`](infra-master-plan-2026-05-12.md)
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
| `infra-master-plan-2026-05-12.md` | 2026-05-12 · refreshed 2026-06-15 | **CURRENT infra plan.** Forward-looking framework master plan. §3.5 Calibration Protocol + §3.6 Forward Plan v7.9→v8.2 + HADF Phase 2-bis calendar. The v8.x candidate docket was extracted 2026-06-15 → see sub-plan below. |
| `v8-x-build-docket-2026-06-15.md` | 2026-06-15 | **CURRENT v8.x build docket** (sub-plan of infra plan). Reconciled candidate status (shipped/open/icebox), F-series + V8-I tables, T29 decision, theme distribution. |
| `v8-0-ready-now-workplan-2026-06-15.md` | 2026-06-15 | **Ready-now execution plan** — the 8 ungated open v8.x items (F1/F3/F4/F5/F10/F11/F12/F13), sequenced into 3 batches with calibration + isolated-worktree constraints. |
| `v8-0-docket-ranking-2026-05-13.md` | 2026-05-13 · decided 2026-05-21 | Frozen T29 RICE ranking artifact (historical). Superseded for live status by the v8.x build docket sub-plan above. |
| `master-plan-2026-04-15.md` | 2026-04-15 · updated 2026-05-12 | **CURRENT product master plan.** Adds all v4.3 → v7.8.4 work, M-series decomposition sprints, audit remediation, cross-repo state-sync, and pre-v7.9 telemetry calibration patch. |
| `master-plan-2026-04-06.md` | 2026-04-06 | DEPRECATED — superseded by 2026-04-15. Kept as a historical snapshot. |
| `_archive/master-plan-reconciled-2026-04-05.md` | 2026-04-05 | DEPRECATED — superseded by 2026-04-06, then 2026-04-15. **Archived 2026-05-24 to `_archive/` per D-PLAN-9** (38+ days SUPERSEDED). |
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
