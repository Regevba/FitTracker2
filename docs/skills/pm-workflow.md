# `/pm-workflow` — The Hub

> **Role in the ecosystem:** The orchestration layer. Every other skill is a spoke; `/pm-workflow` is the hub that reads feature state, decides which spoke to dispatch, and waits for user approval before advancing.

**Agent-facing prompt:** [`.claude/skills/pm-workflow/SKILL.md`](../../.claude/skills/pm-workflow/SKILL.md)

---

## What it does

Orchestrates a feature (or any work item) through a 10-phase lifecycle:

```
0. Research   → 1. PRD → 2. Tasks → 3. UX/Integration → 4. Implement
            → 5. Test → 6. Review → 7. Merge → 8. Docs → 9. Learn
```

Each phase has gates (user approval, CI green, analytics regression passing) and produces artifacts (research.md, prd.md, tasks.md, ux-spec.md, commit hashes, test results, CHANGELOG entry). The hub never writes code or runs tests directly — it dispatches the right spoke skill for each concern.

## Why it exists

Before the ecosystem, `/pm-workflow` was a single monolithic skill that did everything inline: research, PRDs, UX specs, code review, testing, docs. It worked at small scale but:

- Adding a new domain meant bloating one already-large file
- You couldn't use a design audit or analytics validation without running the full PM cycle
- Cross-domain information (e.g. CX signals informing UX decisions) stayed trapped in one workflow's context
- Every phase was sequential — no parallelization of independent work

The v2.0 ecosystem extracted 10 domain skills from the monolith, and `/pm-workflow` became the lightweight orchestrator that reads state and dispatches.

## Sub-commands

Single invocation: `/pm-workflow {feature-name}`. The hub's behavior depends on `state.json` for that feature:

| State | Behavior |
|---|---|
| No `state.json` | Creates one and starts Phase 0 |
| `current_phase: research` | Dispatches `/research` or `/ux audit` (for v2 refactors) |
| `current_phase: prd` | Walks the PRD template, dispatches `/analytics spec` if `requires_analytics` |
| `current_phase: tasks` | Breaks the PRD into subtasks, assigns each a `skill` |
| `current_phase: ux` or `integration` | Dispatches `/ux research` → `/ux spec` → `/ux validate` → `/design audit` |
| `current_phase: implement` | Creates `feature/{name}` branch, dispatches tasks in parallel by skill |
| `current_phase: testing` | Dispatches `/qa plan` → `/qa run` → `/analytics validate` → `/ux validate` |
| `current_phase: review` | Dispatches `/dev review` + `/design audit` + `/ux validate` in parallel |
| `current_phase: merge` | Dispatches `/release checklist`, runs `/analytics regression`, merges PR |
| `current_phase: docs` | Updates CHANGELOG, backlog, feature-memory, dispatches `/marketing launch` |
| `current_phase: complete` | Monitors metrics review cadence, dispatches `/cx analyze` post-launch |

The user can override at any time: `Move to {phase}` or `Roll back to {phase}` — logged with `approved_by: "user-manual"`.

## Work item types

Not every work item walks all 10 phases. The hub supports four types:

| Type | Phases | When to use |
|---|---|---|
| **Feature** | All 9 + metrics (10) | New capability, requires research + PRD + design |
| **Enhancement** | Tasks → Implement → Test → Merge | Improvement to a shipped feature that has a PRD |
| **Fix** | Implement → Test → Review → Merge | Bug fix, security patch |
| **Chore** | Implement → Review → Merge | Docs, config, refactoring |

Skipped phases get `status: "skipped"` with `reason: "work_type:{type}"` in the audit trail. **Review + Merge gates are non-negotiable for every type that changes code.**

### V2 refactor subtype

Introduced 2026-04-08 for UI refactor passes against `ux-foundations.md`. `state.json.work_subtype: "v2_refactor"` triggers:

- Phase 0 dispatches `/ux audit` (not `/research`)
- Phase 3 starts with `v2-audit-report.md` as the gap analysis
- Phase 4 creates a new file at `{originalDir}/v2/{SameFileName}.swift` instead of patching v1 in place
- project.pbxproj removes v1 from Sources build phase, adds v2
- Must walk through `docs/design-system/v2-refactor-checklist.md` before Phase 5

Full rule: `CLAUDE.md` → "UI Refactoring & V2 Rule".

## Shared Data

**Reads:**
- `context.json` — product identity and guardrails
- `feature-registry.json` — all features' status
- `metric-status.json` — instrumentation health for Phase 1 gates
- `health-status.json` — CI status for Phase 6 and Phase 7 gates
- `change-log.json` — history of shipped work for broadcast events

**Writes:**
- `feature-registry.json` — updates feature status on phase transitions
- `change-log.json` — appends an event for every work-item completion
- `.claude/features/{name}/state.json` — the canonical phase tracker
- `task-queue.json` — rebuilds the cross-feature priority queue after task changes

## Upstream / Downstream

**Upstream (who feeds `/pm-workflow`):**
- **User** — invokes with a feature name, approves every phase
- **`/cx analyze`** — post-launch CX signals can create new work items (fixes or enhancements) that auto-land in the queue
- **`/ops incident`** — incidents can spawn urgent Fix work items

**Downstream (who `/pm-workflow` dispatches):**
- All 10 spoke skills at the appropriate phase. See the Phase dispatch table above.

## Phase gate rules (non-negotiable)

1. No phase is skipped without a work-type reason or explicit user override
2. No PRD without success metrics (primary + 2 secondary + guardrails + kill criteria)
3. No merge without CI green on BOTH feature branch and main
4. Post-launch metrics review is mandatory at the cadence the PRD defines
5. Phase transitions auto-sync to GitHub Issue labels — the dashboard updates automatically
6. Conflicts between `state.json` and GitHub Issue labels are resolved by asking the user

## Standalone usage

`/pm-workflow` is rarely invoked standalone outside of a feature context — it's the hub. The closest standalone usage is `/pm-workflow {feature-name}` with a non-existent feature to bootstrap the state file and walk Phase 0 immediately.

## Where in the architecture

```
USER → /pm-workflow (HUB) → dispatches spokes → reads/writes shared/*.json
              ▲                      │
              └──── feedback loop ◀──┘
                 (/cx, /ops)
```

It's the only skill the user normally types directly. Everything else is reachable through it (via phase dispatch) OR standalone (direct invocation).

## Related documents

- [README.md](README.md) — ecosystem overview
- [ux.md](ux.md), [design.md](design.md), [dev.md](dev.md) — the three skills dispatched most during Phase 3-4
- [`CLAUDE.md`](../../CLAUDE.md) — project-wide rules
- [`.claude/skills/pm-workflow/SKILL.md`](../../.claude/skills/pm-workflow/SKILL.md) — the agent-facing prompt
