# `/pm-workflow` — The Hub (v3.0)

> **Role in the ecosystem:** The orchestration layer. Every other skill is a spoke; `/pm-workflow` is the hub that reads feature state, decides which spoke to dispatch, syncs external tools (GitHub, Notion, Figma, Vercel), and waits for user approval before advancing.

**Agent-facing prompt:** [`.claude/skills/pm-workflow/SKILL.md`](../../.claude/skills/pm-workflow/SKILL.md)

---

## What it does

Orchestrates a feature (or any work item) through a 9-phase lifecycle with external tool sync:

```
0. Research   → 1. PRD → 2. Tasks → 3. UX/Integration → 4. Implement
            → 5. Test → 6. Review → 7. Merge → 8. Docs → 9. Learn
                                    ↕               ↕
                              Notion MCP        GitHub Labels
                              Figma MCP         Vercel Deploy
```

Each phase has gates (user approval, CI green, analytics regression passing) and produces artifacts (research.md, prd.md, tasks.md, ux-spec.md, commit hashes, test results, CHANGELOG entry). The hub never writes code or runs tests directly — it dispatches the right spoke skill for each concern.

## Why it exists

Before the ecosystem, `/pm-workflow` was a single monolithic skill that did everything inline: research, PRDs, UX specs, code review, testing, docs. It worked at small scale but:

- Adding a new domain meant bloating one already-large file
- You couldn't use a design audit or analytics validation without running the full PM cycle
- Cross-domain information (e.g. CX signals informing UX decisions) stayed trapped in one workflow's context
- Every phase was sequential — no parallelization of independent work

The v2.0 ecosystem extracted 10 domain skills from the monolith. v3.0 added external tool sync (Notion MCP, Figma MCP), screen audit research mode, parallel subagent execution, and sub-feature queue management.

## Sub-commands

Single invocation: `/pm-workflow {feature-name}`. The hub's behavior depends on `state.json` for that feature:

| State | Behavior |
|---|---|
| No `state.json` | Creates one and starts Phase 0 |
| `current_phase: research` | Dispatches `/research` or `/ux audit` (for v2 refactors) |
| `current_phase: prd` | Walks the PRD template, dispatches `/analytics spec` if `requires_analytics` |
| `current_phase: tasks` | Breaks the PRD into subtasks, assigns each a `skill` |
| `current_phase: ux` or `integration` | Dispatches `/ux research` → `/ux spec` → `/ux wireframe` → `/ux validate` → `/design audit` |
| `current_phase: implement` | Creates `feature/{name}` branch, dispatches tasks in parallel by skill |
| `current_phase: testing` | Dispatches `/qa plan` → `/qa run` → `/analytics validate` → `/ux validate` |
| `current_phase: review` | Dispatches `/dev review` + `/design audit` + `/ux validate` in parallel |
| `current_phase: merge` | Dispatches `/release checklist`, runs `/analytics regression`, merges PR |
| `current_phase: docs` | Updates CHANGELOG, backlog, feature-memory, dispatches `/marketing launch` |
| `current_phase: complete` | Monitors metrics review cadence, dispatches `/cx analyze` post-launch |

The user can override at any time: `Move to {phase}` or `Roll back to {phase}` — logged with `approved_by: "user-manual"`.

## Work item types

Not every work item walks all 10 phases. The hub supports four types:

| Type | Phases (count) | When to use |
|---|---|---|
| **Feature** | All 9 + metrics (10) | New capability, requires research + PRD + design |
| **Enhancement** | Tasks → Implement → Test → Merge (4) | Improvement to a shipped feature that has a PRD |
| **Fix** | Implement → Test (2) | Bug fix, security patch |
| **Chore** | Implement only (1) | Docs, config, refactoring |

Skipped phases get `status: "skipped"` with `reason: "work_type:{type}"` in the audit trail. **Review + Merge gates are non-negotiable for every type that changes code.**

### V2 refactor subtype

Introduced 2026-04-08 for UI refactor passes against `ux-foundations.md`. `state.json.work_subtype: "v2_refactor"` triggers:

- Phase 0 dispatches `/ux audit` (not `/research`) — screen audit research mode
- Phase 3 starts with `v2-audit-report.md` as the gap analysis
- Phase 4 creates a new file at `{originalDir}/v2/{SameFileName}.swift` instead of patching v1 in place
- project.pbxproj removes v1 from Sources build phase, adds v2
- Must walk through `docs/design-system/v2-refactor-checklist.md` before Phase 5

Full rule: `CLAUDE.md` → "UI Refactoring & V2 Rule".

### Sub-feature queue pattern

Validated with Home v2, which spawned 4 sub-features from the parent audit:

1. Parent feature (Home v2, #61) runs Phase 0 audit → produces findings
2. Findings that warrant their own lifecycle become sub-features with `parent_feature` links
3. Sub-features inherit the parent's branch and PRD context
4. Each sub-feature tracks independently in `state.json` but rolls up to the parent GitHub Issue

Example: Home v2 (#61) → Body Composition (#65), Metric Deep Link (#67), Training v2 (#74), Onboarding retro (#63).

## Phase transition procedure (6 steps)

Every phase advance follows this exact sequence:

1. **Verify gate** — all phase-specific gates are met (CI, tests, user approval)
2. **Update `state.json`** — set `current_phase`, timestamp, approval record
3. **Sync GitHub Issue** — update `phase:*` label via `gh` CLI
4. **Sync Notion** — update the feature's Notion page status via `notion-update-page` MCP
5. **Broadcast change** — write event to `change-log.json`, notify downstream skills
6. **Announce** — tell the user what phase they're entering and what happens next

## Dashboard sync automation

Phase transitions auto-sync to three external systems:

| System | Sync method | What updates |
|---|---|---|
| **GitHub Issues** | `gh` CLI | `phase:*` label, assignee, milestone |
| **Notion** | `notion-update-page` MCP | Feature page status, phase field, last-updated timestamp |
| **Vercel** | Deploy preview on PR | Preview URL attached to the GitHub Issue |

Conflicts between `state.json` and GitHub Issue labels are resolved by asking the user.

## Change broadcast protocol

When ANY work item merges to main:

1. Update `feature-registry.json` with what changed
2. Notify downstream skills based on change type (code → `/qa`, `/cx`, `/ops`, `/analytics`; UI → add `/design`; analytics → `/qa`, `/cx`, `/analytics`)
3. Sync Notion page to `phase:done`
4. Write event to `change-log.json`

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
- All 11 spoke skills at the appropriate phase. See the Phase dispatch table above.
- **Notion MCP** — phase status sync on every transition
- **Figma MCP** — design context retrieval during Phase 3-4
- **GitHub** — label sync, PR management during Phase 6-7

## Phase gate rules (non-negotiable)

1. No phase is skipped without a work-type reason or explicit user override
2. No PRD without success metrics (primary + 2 secondary + guardrails + kill criteria)
3. No merge without CI green on BOTH feature branch and main
4. Post-launch metrics review is mandatory at the cadence the PRD defines
5. Phase transitions auto-sync to GitHub Issue labels and Notion — the dashboard updates automatically
6. Conflicts between `state.json` and GitHub Issue labels are resolved by asking the user

## Features shipped through the hub

| Feature | GitHub Issue | Work type | Key milestone |
| --- | --- | --- | --- |
| Home Today Screen v2 | #61 | Feature (v2_refactor) | 27-finding UX audit, v2/ convention validated |
| Onboarding retro | #63 | Enhancement | Retroactive v2 alignment of pilot feature |
| Body Composition card | #65 | Enhancement | Reusable metric tile drill-down pattern |
| Metric Deep Link | #67 | Enhancement | Home tile → detail view navigation |
| Training Plan v2 | #74 | Feature (v2_refactor) | Second full v2 refactor through the pipeline |

## Standalone usage

`/pm-workflow` is rarely invoked standalone outside of a feature context — it's the hub. The closest standalone usage is `/pm-workflow {feature-name}` with a non-existent feature to bootstrap the state file and walk Phase 0 immediately.

## Where in the architecture

```
USER → /pm-workflow (HUB) → dispatches spokes → reads/writes shared/*.json
              ▲                      │                    │
              │                      │              ┌─────┴─────┐
              └──── feedback loop ◀──┘              │ External  │
                 (/cx, /ops)                        │ GitHub    │
                                                    │ Notion    │
                                                    │ Figma     │
                                                    │ Vercel    │
                                                    └───────────┘
```

It's the only skill the user normally types directly. Everything else is reachable through it (via phase dispatch) OR standalone (direct invocation).

## Related documents

- [README.md](README.md) — ecosystem overview
- [architecture.md](architecture.md) — full ecosystem deep-dive
- [ux.md](ux.md), [design.md](design.md), [dev.md](dev.md) — the three skills dispatched most during Phase 3-4
- [`CLAUDE.md`](../../CLAUDE.md) — project-wide rules
- [`.claude/skills/pm-workflow/SKILL.md`](../../.claude/skills/pm-workflow/SKILL.md) — the agent-facing prompt

---

## v4.0 — External Data + Learning Cache

### Integration Adapters

| Adapter | Type | What It Provides |
| --- | --- | --- |
| linear | MCP (official) | Issue tracking, sprint management, cycle progress, team velocity |
| notion | MCP (already connected) | Feature page status sync, phase field updates, documentation workspace |

**Adapter config:** `.claude/integrations/linear/` and `.claude/integrations/notion/`

All incoming data passes through the **automatic validation gate**:

- GREEN (>= 95%): clean, auto-written
- ORANGE (90-95%): minor discrepancies, written with advisory
- RED (< 90%): blocked, user must resolve

Validation is automatic. Resolution is always manual.

**Special:** The hub receives ALL validation gate notifications from every spoke skill. Gate failures from any skill (analytics, QA, design compliance) are surfaced to the user via pm-workflow before phase advance is permitted.

### Learning Cache

**Location:** `.claude/cache/pm-workflow/`

Caches: orchestration patterns (phase transition sequences that succeeded/failed per work type), phase transition decisions (user overrides, skip reasons, rollback triggers).

On start: check cache for matching task signature, load learned patterns.
On complete: extract new patterns, write to L1 cache. Flag cross-skill patterns for L2 promotion.
