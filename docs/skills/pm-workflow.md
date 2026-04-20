# `/pm-workflow` — The Hub (v6.1)

> **Role in the ecosystem:** The orchestration layer. Every other skill is a spoke; `/pm-workflow` is the hub that reads feature state, decides which spoke to dispatch, syncs external tools (GitHub, Notion, Figma, Vercel), and waits for user approval before advancing.
>
> **Updated:** 2026-04-16

**Agent-facing prompt:** [`.claude/skills/pm-workflow/SKILL.md`](../../.claude/skills/pm-workflow/SKILL.md)

---

## What it does

Orchestrates a feature (or any work item) through a 10-phase lifecycle (Phase 0 through Phase 9) with external tool sync:

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

The v2.0 ecosystem extracted 10 domain skills from the monolith. v3.0 added external tool sync (Notion MCP, Figma MCP), screen audit research mode, parallel subagent execution, and sub-feature queue management. v4.0 added the adapter layer and L1/L2/L3 cache. v4.1 added the skill-internal lifecycle. v4.2 added self-healing health checks and framework integrity scoring. v4.3 added the operational layer: control room visibility, case-study monitoring, and maintenance-program orchestration. v4.4 added eval-driven development (mandatory evals per feature). v5.0 applied SoC-on-Software principles: skill-on-demand loading and cache compression, reclaiming ~54K tokens. v5.1 completed the SoC suite with 6 additional items: model tiering, batch dispatch, result forwarding, speculative preload, systolic chains, and task complexity gate — achieving ~63% framework overhead reduction. v5.2 added Dispatch Intelligence (3-stage pipeline, tool budgets, permission routing) and Parallel Write Safety (snapshot/rollback, region mirrors, progressive learning). v6.0 added deterministic Framework Measurement: phase timing, cache hit tracking, eval coverage gates, token counting, CU v2 continuous factors, and rolling baselines. v6.1 added HADF — Hardware-Aware Dispatch: 5-layer hardware detection (edge + cloud), 17 chip profiles across 6 vendors, 7 cloud fingerprints, confidence-gated dispatch, and a composite optimizer. See the [evolution timeline](#version-history) below for the full progression.

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
| **Feature** | Full 10-phase lifecycle (0-9) | New capability, requires research + PRD + design |
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
5. If the work is showcase-worthy, append or update the matching entry in `case-study-monitoring.json`

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
- `case-study-monitoring.json` — records measurable evidence for showcase-worthy features, cleanup programs, and major framework runs
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

| Feature | GitHub Issue | Work type | Framework ver. | Key milestone |
| --- | --- | --- | --- | --- |
| Onboarding v2 | #59 | Feature (v2_refactor) | v2.0 | Pilot UX Foundations alignment, 6 screens |
| Home Today Screen v2 | #61 | Feature (v2_refactor) | v3.0 | 27-finding UX audit, v2/ convention validated |
| Onboarding retro | #63 | Enhancement | v3.0 | Retroactive v2 alignment of pilot feature |
| Body Composition card | #65 | Enhancement | v3.0 | Reusable metric tile drill-down pattern |
| Metric Deep Link | #67 | Enhancement | v3.0 | Home tile → detail view navigation |
| Training Plan v2 | #74 | Feature (v2_refactor) | v4.0 | First feature with 40% cache hit rate |
| Nutrition v2 | #75 | Feature (v2_refactor) | v4.1 | 55% cache — 3.25x faster than Onboarding |
| Stats v2 | #76 | Feature (v2_refactor) | v4.1 | 65% cache — 4.3x faster |
| Settings v2 | #77 | Feature (v2_refactor) | v4.1 | 70% cache — 6.5x faster |
| AI Engine Architecture | #79 | Enhancement | v5.1 | 13 tasks, 17 files, 45% cache, 1.5h |

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

### Architecture & evolution
- [Architecture One-Pager](architecture-one-pager.md) — quick-reference system schematics and information flow
- [Architecture Deep-Dive](architecture.md) — full ecosystem guide with per-skill details, shared data layer, v5.0/v5.1 SoC sections
- [Evolution History](evolution.md) — narrative v1.0 → v6.1 with rationale, consolidated timeline, and cumulative metrics
- [SoC Savings Report](../architecture/soc-savings-report-v5.1.md) — token impact analysis for v5.0/v5.1 optimizations

### Spoke skills (dispatched by the hub)
- [/ux](ux.md) — UX planning & validation (What & Why)
- [/design](design.md) — design system, Figma, tokens (How it Looks)
- [/dev](dev.md) — branching, code review, CI, dependencies
- [/qa](qa.md) — test planning, coverage, regression, security
- [/analytics](analytics.md) — event taxonomy, instrumentation, dashboards, funnels
- [/cx](cx.md) — reviews, NPS, sentiment, feedback loops
- [/marketing](marketing.md) — ASO, campaigns, content, launches
- [/ops](ops.md) — infrastructure, incidents, cost, alerts
- [/research](research.md) — cross-industry → same-category → feature-specific
- [/release](release.md) — version bumps, changelogs, App Store submission

### Case studies (evidence of the hub in action)
- [Onboarding v2 Showcase](../case-studies/pm-workflow-showcase-onboarding.md) — pilot v2.0 run
- [PM Evolution v1→v4](../case-studies/pm-workflow-evolution-v1-to-v4.md) — 6-feature comparison, 6.5x speedup
- [AI Engine Architecture](../case-studies/ai-engine-architecture-v5.1-case-study.md) — v5.1 in action (1.5h, 13 tasks)

### Setup & integration
- [Sentry Setup Guide](../setup/sentry-setup-guide.md) — error tracking integration for `/ops health`
- [Firebase Setup Guide](../setup/firebase-setup-guide.md) — GA4 analytics for `/analytics`
- [Funnel Definitions](../product/funnel-definitions.md) — 6 funnels + dashboard templates for `/analytics funnel`

### Project rules
- [`CLAUDE.md`](../../CLAUDE.md) — project-wide rules, branching strategy, v2 refactor convention
- [`.claude/skills/pm-workflow/SKILL.md`](../../.claude/skills/pm-workflow/SKILL.md) — the agent-facing prompt
- [Skill Routing Config](../../.claude/shared/skill-routing.json) — phase→skill mapping, batch dispatch, model tiering, all v5.1 config
- [Framework Manifest](../../.claude/shared/framework-manifest.json) — canonical version, structure, capabilities

---

## v4.0 — External Data + Learning Cache

### Integration Adapters

| Adapter | Type | What It Provides |
| --- | --- | --- |
| linear | MCP (official) | Issue tracking, sprint management, cycle progress, team velocity |
| notion | MCP (already connected) | Feature page status sync, phase field updates, documentation workspace |

**Adapter config:** Linear and Notion are MCP-backed external connectors used by the hub. The local adapter layer under `.claude/integrations/` currently covers `ga4`, `app-store-connect`, `sentry`, `firecrawl`, `axe`, and `security-audit`. The routing schema now distinguishes those local adapters from external connectors so the framework model matches the repo structure.

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

---

## Version history

Every version was tested through real feature work. The case study column links to evidence.

| Version | Date | What Changed | Tested On | Case Study |
|---|---|---|---|---|
| v1.0 | 2026-04-02 | PM Skill created — 10-phase lifecycle | PM workflow itself | — |
| v1.2 | 2026-04-04 | Analytics instrumentation gate | Google Analytics | — |
| v2.0 | 2026-04-07 | Hub-and-spoke: 11 skills, shared data layer, Phase 9 | Onboarding v2 (#59) | [Showcase](../case-studies/pm-workflow-showcase-onboarding.md) |
| v3.0 | 2026-04-09 | External sync, parallel dispatch, v2 pipeline | Home v2 (#61) | [Evolution v1→v4](../case-studies/pm-workflow-evolution-v1-to-v4.md) |
| v4.0 | 2026-04-10 | Reactive data mesh, adapters, validation gate, L1/L2/L3 cache | Training v2 (#74, 40% cache) | [Evolution v1→v4](../case-studies/pm-workflow-evolution-v1-to-v4.md) |
| v4.1 | 2026-04-10 | Skill Internal Lifecycle (Cache→Research→Execute→Learn) | Nutrition (#75, 55%), Stats (#76, 65%), Settings (#77, 70%) | [Evolution v1→v4](../case-studies/pm-workflow-evolution-v1-to-v4.md) |
| v4.2 | 2026-04-10 | Self-healing hub, Phase 0 health checks | Readiness v2, AI Engine v2, AI Rec UI | [Evolution v1→v4](../case-studies/pm-workflow-evolution-v1-to-v4.md) |
| v4.3 | 2026-04-11 | Control room, case-study monitoring, maintenance programs | Cleanup program | [Cleanup Control Room CS](../case-studies/cleanup-control-room-case-study.md), [Control Center IA CS](../case-studies/control-center-alignment-ia-refresh-case-study.md) |
| v4.4 | 2026-04-13 | Eval-driven development — mandatory evals per feature | Profile settings (9 evals) | [Eval Layer CS](../case-studies/eval-layer-v4.4-case-study.md), [User Profile CS](../case-studies/user-profile-v4.4-case-study.md) |
| v5.0 | 2026-04-14 | SoC: skill-on-demand + cache compression (54K tokens) | Framework itself | [SoC v5 CS](../case-studies/soc-v5-framework-case-study.md) |
| v5.1 | 2026-04-14 | 8 SoC items: batch, tiering, forwarding, preload, systolic, complexity gate | AI Engine Arch (#79, 13 tasks, 1.5h) | [AI Engine CS](../case-studies/ai-engine-architecture-v5.1-case-study.md) |
| v5.2 | 2026-04-16 | Dispatch Intelligence (3-stage pipeline, tool budgets, permission routing) + Parallel Write Safety (snapshot/rollback, region mirrors, progressive learning) | Stress test (18 Swift, 35 tests) | [Parallel Write Safety CS](../case-studies/parallel-write-safety-v5.2-case-study.md), [v5.1→v5.2 Evolution CS](../case-studies/v5.1-v5.2-framework-evolution-case-study.md) |
| v6.0 | 2026-04-16 | Framework Measurement: deterministic phase timing, L1/L2/L3 cache hit tracking, eval coverage gates, monitoring auto-sync, token counting (79K tokens measured), CU v2 continuous factors, rolling baselines, serial/parallel velocity decomposition | — | [Framework Measurement CS](../case-studies/framework-measurement-v6-case-study.md) |
| v6.1 | 2026-04-16 | HADF — Hardware-Aware Dispatch: 5-layer hardware detection (edge + cloud), 17 chip profiles across 6 vendors, 7 cloud fingerprints, confidence-gated dispatch, composite optimizer | HADF rollout + full-system meta-analysis audit (185 findings) | [HADF CS](../case-studies/hadf-hardware-aware-dispatch-case-study.md), [Meta-Analysis Audit CS](../case-studies/meta-analysis-full-system-audit-v6.1-case-study.md) |

For the full narrative behind each version, see [evolution.md](evolution.md). For system schematics, see [architecture-one-pager.md](architecture-one-pager.md). For the detailed deep-dive, see [architecture.md](architecture.md).
