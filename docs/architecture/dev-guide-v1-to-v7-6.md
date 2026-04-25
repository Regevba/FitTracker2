# PM Framework — Developer Guide (v1.0 → v7.6)

> **Audience:** developers landing in this codebase who need to understand how the PM framework actually works — not the marketing narrative, not the case-study story arc, but the wiring. If you are about to add a new feature, extend a check code, fix a CI workflow, or bump the framework version, start here.
>
> **Last updated:** 2026-04-25 at v7.6 ship.
> **Companion docs:** [`docs/skills/architecture.md`](../skills/architecture.md) (skill-by-skill anatomy), [`docs/skills/evolution.md`](../skills/evolution.md) (full version-by-version history), [`CLAUDE.md`](../../CLAUDE.md) (project rules, fastest reference).
> **Reading order:** §§ 1–3 give you the mental model. §§ 4–8 are the schemas and contracts you'll edit against. §§ 9–11 are the integrity layer (where failures get caught). § 12 is the compressed timeline. §§ 13–15 are operational walkthroughs.

---

## Table of Contents

1. [Audience and how to read](#1-audience-and-how-to-read)
2. [Big picture (current state — v7.6)](#2-big-picture-current-state--v76)
3. [Where the code lives](#3-where-the-code-lives)
4. [The skill ecosystem (hub + 10 spokes)](#4-the-skill-ecosystem-hub--10-spokes)
5. [`state.json` — the canonical per-feature contract](#5-statejson--the-canonical-per-feature-contract)
6. [Phase lifecycle (9 phases × 4 work types)](#6-phase-lifecycle-9-phases--4-work-types)
7. [Dispatch model — how skills get invoked](#7-dispatch-model--how-skills-get-invoked)
8. [Cache architecture (L1 per-skill, L2 shared, L3 project)](#8-cache-architecture-l1-per-skill-l2-shared-l3-project)
9. [Measurement protocol (CU formula, cache_hits, timing)](#9-measurement-protocol-cu-formula-cache_hits-timing)
10. [Integrity layer — write-time + per-PR + cycle-time + weekly](#10-integrity-layer--write-time--per-pr--cycle-time--weekly)
11. [Pre-commit hooks and GitHub Actions](#11-pre-commit-hooks-and-github-actions)
12. [Compressed evolution timeline (v1.0 → v7.6)](#12-compressed-evolution-timeline-v10--v76)
13. [Operational walkthrough — adding a new feature](#13-operational-walkthrough--adding-a-new-feature)
14. [Operational walkthrough — extending an integrity check code](#14-operational-walkthrough--extending-an-integrity-check-code)
15. [Operational walkthrough — bumping the framework version](#15-operational-walkthrough--bumping-the-framework-version)
16. [References](#16-references)

---

## 1. Audience and how to read

This guide is for **developers**. If you are a PM looking for product workflow, read [`docs/skills/pm-workflow.md`](../skills/pm-workflow.md). If you are reading the project as evidence of an AI workflow approach, start with [`docs/case-studies/`](../case-studies/) (start at `01-onboarding-pilot.mdx` on the `fitme-story` showcase).

The framework is not a single library you import. It is a set of conventions implemented across:
- **Markdown documents** that describe each skill (`.claude/skills/<name>/SKILL.md`) and shared state (`.claude/shared/*.json`).
- **Python scripts** that enforce or measure invariants (`scripts/*.py`).
- **GitHub Actions workflows** that run the scripts on schedules and on every PR (`.github/workflows/*.yml`).
- **A pre-commit hook** that runs the same scripts locally before any commit lands (`.githooks/pre-commit`).
- **Per-feature state files** that track each in-flight feature's lifecycle (`.claude/features/<name>/state.json`).

There is **no compiled binary**. The framework is the union of the conventions above, the scripts that enforce them, and the agents (Claude Code, Claude Desktop, Codex, etc.) that follow them.

---

## 2. Big picture (current state — v7.6)

### 2.1 What the framework does, in one sentence

It enforces that every feature passes through a defined lifecycle (Research → PRD → Tasks → UX → Implement → Test → Review → Merge → Docs), records its state and timing in a machine-readable file, and is gated by automated checks at write-time, per-PR, and on a 72h schedule so that drift between code and documentation is caught fast.

### 2.2 The four enforcement layers (v7.6)

```
┌─────────────────────────────────────────────────────────────────────┐
│  Layer 1 — WRITE-TIME (pre-commit hooks, ~3-5s)                     │
│  Fires on every `git commit`. Blocks the commit if it fails.        │
│  Scripts: scripts/check-state-schema.py + check-case-study-preflight │
│  Check codes: SCHEMA_DRIFT, PR_NUMBER_UNRESOLVED,                    │
│               PHASE_TRANSITION_NO_LOG, PHASE_TRANSITION_NO_TIMING,   │
│               BROKEN_PR_CITATION (write-time),                       │
│               CASE_STUDY_MISSING_TIER_TAGS                           │
└─────────────────────────────────────────────────────────────────────┘
              │                                     ▲
              │ commit lands                        │ also runs as
              ▼                                     │ rear-guard
┌─────────────────────────────────────────────────────────────────────┐
│  Layer 2 — PER-PR (GitHub Actions, ~1-3min per push)                │
│  Workflow: .github/workflows/pr-integrity-check.yml                 │
│  Compares PR HEAD findings vs origin/main baseline (worktree).      │
│  Status check: pm-framework/pr-integrity → required for merge.      │
└─────────────────────────────────────────────────────────────────────┘
              │ PR merges to main
              ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Layer 3 — 72h CYCLE (GitHub Actions cron, every 3 days at 04:00Z)  │
│  Workflow: .github/workflows/integrity-cycle.yml                    │
│  Script: scripts/integrity-check.py (12 cycle-time check codes)     │
│  Snapshots ledger to .claude/integrity/snapshots/.                  │
│  Opens issue on regression vs prior snapshot.                       │
└─────────────────────────────────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Layer 4 — WEEKLY (GitHub Actions cron, Mondays 05:00Z)             │
│  Workflow: .github/workflows/framework-status-weekly.yml            │
│  Snapshots measurement-adoption-history.json + documentation-debt.  │
│  Opens issue on adoption regression. OBSERVATIONAL (does not block).│
└─────────────────────────────────────────────────────────────────────┘
```

### 2.3 The 5 mechanically unclosable Class B gaps

The four layers above catch what a deterministic script can catch. Five gaps remain Class B (agent-attention, judgment, or external-dependency). They are documented in [`docs/case-studies/meta-analysis/unclosable-gaps.md`](../case-studies/meta-analysis/unclosable-gaps.md):

1. `cache_hits[]` writer-path adoption — agent must remember to log hits (issue #140).
2. `cu_v2` factor *correctness* — magnitudes are judgment-based.
3. T1/T2/T3 tag *correctness* — preflight checks presence, not whether the tag is right.
4. Tier 2.1 real-provider auth — physical device required.
5. Tier 3.3 external replication — external operator required.

If you are a developer reading this guide, your code rarely needs to reason about Class B gaps directly — they exist as documented exceptions to the "everything is mechanical" framing. But if you are *adding* a check code, ask: "is what I'm checking deterministic, or am I trying to mechanize a judgment?" The latter belongs in the Class B inventory, not in `check-state-schema.py`.

---

## 3. Where the code lives

```
FitTracker2/
├── .claude/
│   ├── features/<feature-name>/state.json   ← per-feature state (1 per feature)
│   ├── logs/<feature-name>.log.json         ← per-feature contemporaneous log
│   ├── shared/                              ← shared cross-feature state
│   │   ├── framework-manifest.json           ← framework version + capabilities
│   │   ├── feature-registry.json             ← list of all features
│   │   ├── change-log.json                   ← cross-feature change events
│   │   ├── measurement-adoption.json         ← v6.0 adoption ledger (current)
│   │   ├── measurement-adoption-history.json ← v6.0 adoption (append-only)
│   │   ├── documentation-debt.json           ← Tier 3.2 debt ledger
│   │   ├── case-study-monitoring.json        ← case-study health
│   │   ├── skill-routing.json                ← skill phase routing config
│   │   └── … (~24 shared state files total)
│   ├── skills/<skill-name>/SKILL.md         ← agent-facing skill prompt (11 skills)
│   ├── integrations/<service>/              ← per-service adapters (ga4, sentry…)
│   ├── cache/                                ← learning cache (L1 + L2 _shared/ + L3 _project/)
│   └── integrity/
│       ├── README.md                         ← integrity layer canonical entry
│       └── snapshots/                        ← 72h cycle snapshots (committed)
├── scripts/
│   ├── check-state-schema.py                 ← write-time + cycle (10+ check codes)
│   ├── check-case-study-preflight.py         ← write-time (case studies)
│   ├── integrity-check.py                    ← cycle-time (12 check codes)
│   ├── measurement-adoption-report.py        ← Tier 1.1 ledger generator
│   ├── append-feature-log.py                 ← contemporaneous log writer
│   ├── documentation-debt-report.py          ← Tier 3.2 ledger generator
│   ├── runtime-smoke-gate.py                 ← Tier 2.1 smoke runner
│   └── test-v7-5-pipeline.sh                 ← 15-assertion regression test
├── .githooks/pre-commit                       ← orchestrates write-time checks
├── .github/workflows/
│   ├── ci.yml                                ← Xcode build + test
│   ├── integrity-cycle.yml                   ← 72h cycle (cron 0 4 */3 * *)
│   ├── pr-integrity-check.yml                ← per-PR (v7.6 Phase 2a)
│   └── framework-status-weekly.yml           ← weekly cron (v7.6 Phase 2c)
├── docs/
│   ├── architecture/
│   │   └── dev-guide-v1-to-v7-6.md          ← THIS FILE
│   ├── skills/
│   │   ├── architecture.md                   ← skill-by-skill anatomy
│   │   ├── evolution.md                      ← full version-by-version history
│   │   └── pm-workflow.md                    ← user-facing PM workflow doc
│   ├── case-studies/                         ← all shipped case studies
│   │   ├── data-integrity-framework-v7.5-case-study.md
│   │   ├── mechanical-enforcement-v7-6-case-study.md
│   │   └── meta-analysis/unclosable-gaps.md
│   ├── process/                              ← process docs (Tier groundwork)
│   ├── product/                              ← PRDs, metrics, backlog
│   └── design-system/                        ← UX foundations + component memory
├── trust/
│   └── audits/2026-04-21-gemini/             ← independent audit + remediation
└── CLAUDE.md                                 ← project rules (fastest reference)
```

**Companion repo (separate git):** `/Volumes/DevSSD/fitme-story` — Next.js showcase site. Trust page (`/trust/audits/2026-04-21-gemini`) and case-studies index live there. The fitme-story repo cross-links to the main repo's case studies via raw GitHub URLs.

---

## 4. The skill ecosystem (hub + 10 spokes)

The framework runs as **11 skills** following a hub-and-spoke pattern:

- **Hub:** `pm-workflow` — owns the lifecycle, dispatches work to spokes, gates phase transitions.
- **Spokes:** `dev`, `qa`, `design`, `ux`, `analytics`, `cx`, `marketing`, `release`, `research`, `ops` — each owns a phase or cross-cutting responsibility.

Each skill has:
- An **agent-facing prompt** at `.claude/skills/<name>/SKILL.md`. The agent reads this when the skill is loaded.
- A **markdown doc** at `docs/skills/<name>.md` for human reference.
- A **routing config entry** in `.claude/shared/skill-routing.json` declaring which phases load this skill on demand (v5.0 skill-on-demand optimization).

### 4.1 Skill loading model (v5.0+)

Before v5.0, all 11 skills loaded into context on every session. After v5.0:
- The `pm-workflow` hub always loads.
- Spokes load **on demand** based on `phase_skills` in `skill-routing.json`.
- Each spoke has a `compressed_view` field in its cache entry (~200 words) loaded by default; full expansion happens when the agent calls the skill.
- Net savings: ~54K tokens per session vs. v4.x.

### 4.2 Adding a new skill

1. Create `.claude/skills/<name>/SKILL.md` with the agent-facing prompt.
2. Create `docs/skills/<name>.md` for human reference.
3. Add an entry to `.claude/shared/skill-routing.json`:
   ```json
   {
     "phase_skills": {
       "<phase>": ["<existing-skills>", "<name>"]
     },
     "compressed_views": {
       "<name>": "≤200-word summary of what the skill does"
     }
   }
   ```
4. Bump `framework-manifest.json.structure.spoke_skills` (currently 10).

---

## 5. `state.json` — the canonical per-feature contract

Every feature has a `.claude/features/<name>/state.json` file. This file is the **single source of truth** for that feature's lifecycle state. The integrity layer reads it; the dashboard reads it; the case study links to it.

### 5.1 Required top-level fields

| Field | Type | Notes |
|---|---|---|
| `name` | string | Feature slug, must match directory name |
| `work_type` | enum | `"feature"`, `"enhancement"`, `"fix"`, `"chore"`, `"framework"`, `"refactor"` |
| `current_phase` | enum | One of: `research`, `prd`, `tasks`, `ux_or_integration`, `implement`, `test`, `review`, `merge`, `docs`, `complete`. **DO NOT use `phase`** — that key is rejected by `SCHEMA_DRIFT` (canonical is `current_phase`). |
| `created` | ISO 8601 timestamp | Used by `measurement-adoption-report.py` to bucket pre/post-v6.0 features |
| `phases` | object | One key per phase entered, with `started_at` (ISO 8601). Phase `M` adds `ended_at` when leaving for phase `N>M`. |
| `tasks` | array | Task list for Phase 3 (`tasks` phase) onward |
| `complexity` | object | v6.0 protocol: `cu_version`, `factors_applied[]`, `view_count`, etc. (see § 9.1) |
| `timing` | object | v6.0 protocol: `session_start`, `total_wall_time_minutes`, per-phase `started_at`/`ended_at` |
| `cache_hits` | array | v6.0 protocol: each entry is `{timestamp, level, key, type, skill, event_type, phase}` |

### 5.2 Phase-specific sub-fields

Each entered phase typically also has:
- `phases.<phase>.completed_at` — when the phase finished (set on transition out)
- `phases.<phase>.gate_passed` — boolean if a hard gate (e.g., review approval) was required
- `phases.merge.pr_number` — set during the merge phase; verified by the `PR_NUMBER_UNRESOLVED` check

### 5.3 Schema enforcement

`scripts/check-state-schema.py` reads each staged `state.json` (or, with `--all`, every state.json in the repo) and emits findings:
- `SCHEMA_DRIFT` — legacy `phase` key present
- `NO_PHASE` — neither `current_phase` nor `phase` present
- `INVALID_JSON` — file does not parse
- `PHASE_TRANSITION_NO_LOG` (v7.6) — phase changed but no log entry within last 15 min
- `PHASE_TRANSITION_NO_TIMING` (v7.6) — phase changed but no `timing.phases.<new>.started_at` and/or old-phase `ended_at` update

The `--staged` flag scopes the check to staged files (used by the pre-commit hook). The `FORCE_TRANSITION_CHECKS=1` env var unscopes for testing.

---

## 6. Phase lifecycle (9 phases × 4 work types)

The PM framework defines a **9-phase pipeline** for full features. Smaller work types skip subsets of phases.

| Phase | Skill driver | Output | Required for |
|---|---|---|---|
| 1. `research` | `research` | `docs/product/research/<name>.md` | Feature |
| 2. `prd` | `pm-workflow` | `docs/product/prd/<name>.md` | Feature, Enhancement |
| 3. `tasks` | `pm-workflow` | `state.json.tasks[]` | Feature, Enhancement |
| 4. `ux_or_integration` | `ux` + `design` | `docs/design-system/<name>-spec.md` | Feature (UI), or skipped + recorded as `work_type:fix` etc. |
| 5. `implement` | `dev` | code | All work types |
| 6. `test` | `qa` | XCTest + CI green | All except `chore` |
| 7. `review` | reviewer + `qa` | Approved PR | Feature, Enhancement |
| 8. `merge` | `release` | Commit on main + `pr_number` set | All |
| 9. `docs` | `pm-workflow` + `cx` | Case study + state.json closed | Feature, Enhancement |

### 6.1 Work types

Defined in `CLAUDE.md` (Work Item Types section):
- **Feature** — full 9-phase. New capabilities. Weight 1.0 in CU formula.
- **Enhancement** — 4-phase (Tasks → Implement → Test → Merge). Improvements to shipped features. Weight 0.8.
- **Fix** — 2-phase (Implement → Test). Bug fixes. Weight 0.5.
- **Chore** — 1-phase (Implement). Docs, config. Weight 0.3.
- **Refactor (v2)** — like Feature but v1 exists as reference. Weight 0.9.
- **Framework** — internal infrastructure (e.g., this dev guide, v7.6 itself). No fixed weight; choose nearest analog.

### 6.2 The "v2/" subdirectory rule

When refactoring a UI screen, the v2 file lives at `<parent>/v2/<ScreenName>.swift`. Same Swift type name; v1 stays in repo as historical artifact (removed from build target via `project.pbxproj`). Full rule: `CLAUDE.md` → "## UI Refactoring & V2 Rule".

---

## 7. Dispatch model — how skills get invoked

The agent (Claude Code, Codex, etc.) interacts with the framework primarily via **slash commands** that invoke skills:

```
/pm-workflow <feature-name>      ← hub: starts/resumes a feature
/dev                              ← spoke: implementation work
/qa                               ← spoke: test work
/design / /ux                     ← spoke: design + UX
/analytics / /cx / /research      ← spoke: cross-cutting
/marketing / /release / /ops      ← spoke: support
```

When the user types a slash command, the runtime looks up the corresponding `SKILL.md` and loads its content into the agent's context. The agent then follows the skill's instructions.

### 7.1 Routing logic (v5.2 Dispatch Intelligence)

`scripts/dispatch-intelligence.py` and `.claude/shared/dispatch-intelligence.json` define a 3-stage dispatch pipeline:
1. **Tool budget check** — does the requested skill fit within the per-session tool budget?
2. **Hardware affinity** (v7.0 HADF) — does the current device profile favor a particular skill variant?
3. **Skill execution** — invoke the skill with appropriate cache pre-load.

For most local Claude Code sessions, the dispatch pipeline is invisible — it just makes routing decisions before the agent picks up the work.

### 7.2 Concurrent dispatch hygiene

Per `CLAUDE.md` "## Concurrent Dispatch Hygiene": parallel subagent dispatch is **currently blocked** at the framework layer (F6–F9 framework bugs). Default to serial. Re-validation gate after upstream patches: `docs/superpowers/plans/f6-f9-reproducer/proof-of-fix-tests.md`.

---

## 8. Cache architecture (L1 per-skill, L2 shared, L3 project)

The framework treats agent reasoning as a cache hierarchy:

| Level | Scope | Location | Lifetime |
|---|---|---|---|
| **L1** | Per-skill | `.claude/cache/<skill>/` | Session-scoped; skill-internal |
| **L2** | Cross-skill (shared) | `.claude/cache/_shared/` | Session-scoped; multiple skills can read |
| **L3** | Project-wide | `.claude/cache/_project/` | Persistent across sessions |

### 8.1 Cache hits — the writer path

When an agent reuses a piece of prior knowledge (a skill output, a doc snippet, a prior plan, a memory entry) instead of re-deriving it, that's a **cache hit**. The agent logs it via:

```bash
python3 scripts/append-feature-log.py \
  --feature <feature-name> \
  --event-type code_change \
  --summary "<what changed>" \
  --artifact "<file>" \
  --cache-hit L2 \
  --cache-key "<a stable key>" \
  --cache-hit-type {adapted,exact,miss} \
  --cache-skill "<source skill or pattern reused>"
```

The script writes the entry to `.claude/logs/<feature>.log.json` AND appends to `state.json.cache_hits[]`. The dual-write is intentional: logs are flat-file event streams, state.json is the canonical roll-up.

### 8.2 What the framework can and cannot mechanize

- **Mechanizable:** the writer path (CLI accepts the flags, schema validates the entry, count rolls up to `measurement-adoption.json`).
- **Not mechanizable:** the *recognition* that something is a cache hit. This is Class B Gap 1. The framework provides the infrastructure; the agent must remember to use it.

---

## 9. Measurement protocol (CU formula, cache_hits, timing)

Shipped at v6.0 (2026-04-16). Hardened across v7.5 → v7.6. Canonical doc: [`docs/case-studies/normalization-framework.md`](../case-studies/normalization-framework.md).

### 9.1 The CU formula (v6.0)

```
CU = Tasks × Work_Type_Weight × (1 + sum(Complexity_Factors))
```

**Work-type weights:**
| Type | Weight |
|---|---|
| Feature | 1.0 |
| Enhancement | 0.8 |
| Fix | 0.5 |
| Chore | 0.3 |
| Refactor (v2) | 0.9 |
| Framework | (choose nearest analog; commonly 0.9) |

**Complexity factors (additive):**

| Factor | Value | Source |
|---|---|---|
| Has UI (1 view) | +0.15 | `state.json.complexity.view_count` |
| Has UI (2-3 views) | +0.30 | same |
| Has UI (4+ views) | +0.45 | same |
| Design Iteration (text) | +0.10 per round | `state.json.complexity.design_iteration_details[]` |
| Design Iteration (layout) | +0.15 per round | same |
| Design Iteration (interaction) | +0.20 per round | same |
| Design Iteration (full redesign) | +0.25 per round | same |
| New Model/Service (1-2 types) | +0.1 | `state.json.complexity.new_types_count` |
| New Model/Service (3-5) | +0.2 | same |
| New Model/Service (6+) | +0.3 | same |
| Auth/External (binary) | +0.5 | binary flag |
| Runtime Testing (binary) | +0.4 | binary flag |
| Cross-Feature (binary) | +0.2 | binary flag |
| Architectural Novelty (binary) | +0.2 | `state.json.complexity.is_first_of_kind` |

The agent **declares** factors in `state.json.complexity.factors_applied[]` with a `reason` string per factor. The script does not auto-derive magnitudes — that's Class B Gap 2.

### 9.2 Velocity reporting

After phase completion, `state.json.timing.total_wall_time_minutes` should be set. Velocity = `total_wall_time_minutes / CU`. The v6.0 protocol requires three baseline comparisons:
- vs Historical (Onboarding v2 = 15.2 min/CU)
- vs Rolling (mean of last 5 features)
- vs Same-Type (mean of last 3 same work_type)

`scripts/measurement-adoption-report.py` reports per-feature adoption status across 4 dimensions: `timing_wall_time`, `per_phase_timing`, `cache_hits`, `cu_v2`. A feature is "fully adopted" only when all 4 dimensions are populated.

### 9.3 Tier tags (T1/T2/T3)

Every quantitative claim in a case study, PRD, or meta-analysis should carry a tier tag:
- **T1 (Instrumented)** — pulled from a JSON file or deterministic command output.
- **T2 (Declared)** — declared by the author from a non-instrumented source (e.g., human-counted from `git log`).
- **T3 (Narrative)** — narrative inference; should be avoided in v7.6+ case studies.

Forward-only: case studies dated `>= 2026-04-21` get file-level tag-presence enforcement at write-time (`CASE_STUDY_MISSING_TIER_TAGS`). The preflight checks that at least one T1/T2/T3 tag exists in the scoped file. Tag exhaustiveness and correctness are Class B Gap 3 — code review still checks whether each metric has the right tag.

---

## 10. Integrity layer — write-time + per-PR + cycle-time + weekly

### 10.1 Check codes (12 in v7.6)

| Code | Layer | Script | What it checks |
|---|---|---|---|
| `SCHEMA_DRIFT` | Write + cycle | `check-state-schema.py` | Legacy `phase` key present (canonical is `current_phase`) |
| `NO_PHASE` | Write + cycle | `check-state-schema.py` | Neither `current_phase` nor `phase` present |
| `INVALID_JSON` | Write + cycle | `check-state-schema.py` | File does not parse |
| `PR_NUMBER_UNRESOLVED` | Write + cycle | `check-state-schema.py` + `integrity-check.py` | `phases.merge.pr_number` does not resolve in the cached `gh pr list` result (skipped gracefully when `gh` is unavailable) |
| `PHASE_TRANSITION_NO_LOG` (v7.6) | Write | `check-state-schema.py` | Staged phase change without log entry within 15 min |
| `PHASE_TRANSITION_NO_TIMING` (v7.6) | Write | `check-state-schema.py` | Staged phase change without `timing.phases.<new>.started_at` and old-phase `ended_at` fields |
| `PHASE_LIE` | Cycle | `integrity-check.py` | `current_phase=complete` but state.json contradicts |
| `TASK_LIE` | Cycle | `integrity-check.py` | Tasks marked complete that contradict commits |
| `NO_CS_LINK` | Cycle | `integrity-check.py` | Shipped feature has no case-study link |
| `V2_FILE_MISSING` | Cycle | `integrity-check.py` | v2/ subdirectory missing for refactored screen |
| `PARTIAL_SHIP_TERMINAL` | Cycle | `integrity-check.py` | Marked shipped but only some sub-tasks done |
| `NO_STATE` | Cycle | `integrity-check.py` | Feature in registry has no state.json |
| `BROKEN_PR_CITATION` (v7.6 write-time, v7.5 cycle) | Write + cycle | `check-case-study-preflight.py` (write) + `integrity-check.py` (cycle) | PR # in case study does not resolve |
| `CASE_STUDY_MISSING_TIER_TAGS` (v7.6) | Write + cycle | `check-case-study-preflight.py` (write) + `integrity-check.py` (cycle) | Scoped case study has no T1/T2/T3 tag at all (forward-only ≥ 2026-04-21); presence only, not exhaustiveness |

### 10.2 The 72h cycle

Defined in `.github/workflows/integrity-cycle.yml`. Cron: `0 4 */3 * *` (every 3 days at 04:00 UTC). Steps:
1. Checkout repo with `fetch-depth: 0`.
2. Run `integrity-check.py --snapshot <new> --compare-to <prev> --snapshot-trigger scheduled_cycle`.
3. Commit the new snapshot to `.claude/integrity/snapshots/`.
4. If a regression is detected, open a `regression`-labeled issue.

### 10.3 The per-PR layer

Defined in `.github/workflows/pr-integrity-check.yml` (v7.6 Phase 2a). Steps:
1. Checkout PR HEAD.
2. Run schema check + integrity check + measurement-adoption against PR HEAD.
3. Capture `origin/main` baseline via `git worktree add /tmp/main-tree origin/main`.
4. Compute `delta = pr_findings - main_findings`.
5. Set `pm-framework/pr-integrity` commit status to `failure` if any required command exits non-zero or if `delta > 0`.
6. Sticky comment with marker `<!-- pm-framework-pr-integrity-bot -->` updates in place and reports command exit codes.

### 10.4 The weekly cycle

Defined in `.github/workflows/framework-status-weekly.yml` (v7.6 Phase 2c). Cron: `0 5 * * 1` (Mondays 05:00 UTC, 1h after the 72h cycle to avoid runner queue contention). Steps:
1. Snapshot measurement-adoption history with `--snapshot-trigger weekly_status`.
2. Compare current vs prior history snapshot.
3. Open issue if `fully_adopted` or `any_adopted` decreased.
4. **Observational only** — never blocks merges.

---

## 11. Pre-commit hooks and GitHub Actions

### 11.1 Installing the pre-commit hook

```bash
make install-hooks   # symlinks .githooks/pre-commit to .git/hooks/pre-commit
```

### 11.2 What the hook runs

```bash
python3 scripts/check-state-schema.py --staged || exit 1
python3 scripts/check-case-study-preflight.py --staged || exit 1
```

Both scripts exit non-zero on findings. Emergency bypass: `git commit --no-verify`. The cycle layer still catches the issue 0–72h later, so bypass is not silent.

### 11.3 GitHub Actions inventory

| Workflow | Trigger | Purpose |
|---|---|---|
| `ci.yml` | push, PR | Xcode build + XCTest |
| `integrity-cycle.yml` | cron `0 4 */3 * *` + workflow_dispatch | 72h state.json + case-study audit |
| `pr-integrity-check.yml` | pull_request (opened, sync, reopen) | Per-PR delta vs main; sets `pm-framework/pr-integrity` status |
| `framework-status-weekly.yml` | cron `0 5 * * 1` + workflow_dispatch | Weekly measurement-adoption + documentation-debt snapshot, regression issue |

### 11.4 Security note for workflow files

All dynamic values used inside `run:` blocks **MUST** be routed through the `env:` block, never via `${{ }}` interpolation directly into shell. This prevents the GitHub Actions injection vector (see [github.blog reference](https://github.blog/security/vulnerability-research/how-to-catch-github-actions-workflow-injections-before-attackers-do/)). The pre-commit hook for workflow files (`security_reminder_hook.py`) blocks writes that violate this. Both v7.6 workflows (`pr-integrity-check.yml`, `framework-status-weekly.yml`) follow this pattern.

---

## 12. Compressed evolution timeline (v1.0 → v7.6)

Full per-version detail: [`docs/skills/evolution.md`](../skills/evolution.md). This section is the compressed dev-only summary — what each version changed structurally.

| Version | Date | Structural change | Why it matters to a dev today |
|---|---|---|---|
| v1.0 | 2026-03-16 | Single-track serial pipeline (Research → ... → Docs). All work types ran the full 9 phases. | The legacy structure; replaced in v2.0. Files predating v2.0 may show signs of "every change passed through PRD." |
| v2.0 | 2026-03-25 | Work-type tiering (Feature / Enhancement / Fix / Chore). Reduced phase counts per type. | Why a `fix` PR doesn't have a PRD — it's not laziness, it's the work-type contract. |
| v3.0 | 2026-04-09 | External integrations (GA4, Sentry, App Store Connect, Firecrawl, Axe), screen audits, multi-screen v2. | The `.claude/integrations/` directory dates from here. |
| v4.0 | 2026-04-10 | Reactive data mesh + learning cache. L1/L2/L3 cache levels introduced. | The `_shared/` and `_project/` cache directories. |
| v4.1 | 2026-04-10 | Skill internal lifecycle (each skill has `init`, `do`, `report`, `learn` stages internally). | Why every SKILL.md has the same outline. |
| v4.2 | 2026-04-10 | Self-healing hub with integrity verification. First seed cache (5 L1 + 5 L2/L3). | The cache verification logic in `scripts/cache-integrity.py`. |
| v4.3 | 2026-04-11 | Operations Control Room + case-study monitoring. `case-study-monitoring.json`. | The dashboard route on fitme-story (`/`) is built on this data. |
| v4.4 | 2026-04-13 | Eval-driven development. Skill `learn` stage now runs evals against historical sessions. | `.claude/cache/_shared/skill-evals/` directory. |
| v5.0 | 2026-04-14 | SoC-on-software part 1: skill-on-demand loading + cache compression. **54K tokens saved per session**. | Why only `pm-workflow` is in context until you call a spoke. |
| v5.1 | 2026-04-14 | SoC-on-software part 2: 8 SoC items (batch dispatch, result forwarding, model tiering, speculative preload, systolic chains, complexity gate, etc.). | The performance gains came from these — see `docs/skills/architecture.md` §3 for inspiration analogs (Apple ANE, TPU, ARM big.LITTLE). |
| v5.2 | 2026-04-16 | Dispatch Intelligence (3-stage dispatch pipeline) + Parallel Write Safety (3-tier mirror extraction). | The `.claude/shared/dispatch-intelligence.json` config + the parallel-write guards in spoke skills. |
| v6.0 | 2026-04-16 | Framework Measurement Protocol. CU formula v2 (continuous factors), L1/L2/L3 cache hit tracking, eval coverage gates, monitoring auto-sync, 79K tokens measured, rolling baselines, serial/parallel velocity decomposition. | This is when `state.json.timing` and `state.json.cache_hits` schemas became canonical. **Most of v7.5/v7.6's "retroactive backfill" was about catching pre-v6.0 features up to this schema.** |
| v7.0 | 2026-04-16 | HADF (Hardware-Aware Dispatch). 5-layer architecture, 17 chip profiles, 7 cloud signatures, hardware_context block in dispatch-intelligence.json, zero-regression gate (0.4/0.7), composite optimizer. | If you see `hardware_context` in dispatch logs, this is why. Layer 4 (chip-affinity-map) is empty by design — it activates when a workload meets thresholds. |
| v7.1 | 2026-04-21 | 72h Integrity Cycle. First framework capability whose trigger is wall-clock elapsed (cron). 7 failure-mode detectors. | The `integrity-cycle.yml` workflow + `.claude/integrity/snapshots/` ledger. |
| v7.5 | 2026-04-24 | Data Integrity Framework (8 cooperating defenses). Pre-commit schema gates, PR-resolution check, runtime smoke gates, contemporaneous logging, T1/T2/T3 data quality tiers, documentation-debt + measurement-adoption ledgers, 3 new Auditor Agent check codes. Triggered by Gemini 2.5 Pro audit. | 7 of Gemini's 9 Tier 1/2/3 items shipped fully or effectively, 2 partial/pilot, 1 deferred to v7.6. The pre-commit hook and the `make` targets (`integrity-check`, `measurement-adoption`, `documentation-debt`, `runtime-smoke`) date from here. |
| v7.6 | 2026-04-25 | Mechanical Enforcement. 4 new write-time check codes (`PHASE_TRANSITION_NO_LOG`, `PHASE_TRANSITION_NO_TIMING`, `BROKEN_PR_CITATION` write-time, `CASE_STUDY_MISSING_TIER_TAGS`). Per-PR review bot with `pm-framework/pr-integrity` status check. Weekly framework-status cron. Append-only adoption history. 5 explicit Class B gaps documented in `unclosable-gaps.md`. | The current state. Writing code today: expect the pre-commit hook to fire, expect the per-PR bot to comment, expect the weekly cron to surface adoption regressions. The 5 Class B gaps are the documented exceptions. |

### 12.1 Version-bump policy

A major-version bump (e.g., v7.5 → v7.6) requires:
1. **A new structural capability** — not just code changes within an existing capability.
2. **A propagated update across surfaces** — manifest, CLAUDE.md, evolution doc, case study, and trust-page integration where relevant.
3. **A measurement that the change is real** — pipeline test, integrity check, or instrumented data.

Minor bumps (e.g., v7.5 hardening commits) extend an existing capability without introducing a new layer.

---

## 13. Operational walkthrough — adding a new feature

You are adding a new feature called `widget-customization`. Here's the full sequence.

### 13.1 Bootstrap

```bash
/pm-workflow widget-customization
```

The hub creates `.claude/features/widget-customization/state.json` with:
```json
{
  "name": "widget-customization",
  "work_type": "feature",
  "current_phase": "research",
  "created": "<now ISO>",
  "phases": {"research": {"started_at": "<now>"}},
  "tasks": [],
  "complexity": {"cu_version": 2, "view_count": 0, "factors_applied": []},
  "timing": {"session_start": "<now>", "phases": {"research": {"started_at": "<now>"}}},
  "cache_hits": []
}
```

It also creates `.claude/logs/widget-customization.log.json` with a `phase_started` event.

### 13.2 Phase progression

For each phase transition (e.g., `research → prd`):
1. Run the phase-specific work (research → write `docs/product/research/widget-customization.md`).
2. Update state.json: set `phases.research.completed_at`, set `current_phase = "prd"`, add `phases.prd.started_at`.
3. Append a `phase_transition` log event via `append-feature-log.py`.
4. Commit. The pre-commit hook will:
   - Verify `current_phase` (not `phase`) — `SCHEMA_DRIFT`.
   - Verify the log entry exists within 15 min — `PHASE_TRANSITION_NO_LOG`.
   - Verify `phases.prd.started_at` is set — `PHASE_TRANSITION_NO_TIMING`.

### 13.3 During implementation

Log cache hits as you go:
```bash
python3 scripts/append-feature-log.py \
  --feature widget-customization \
  --event-type code_change \
  --summary "<what>" \
  --artifact "<file>" \
  --cache-hit L2 \
  --cache-key "<stable key>" \
  --cache-hit-type adapted \
  --cache-skill "<source>"
```

Update `state.json.complexity.factors_applied[]` as factors become known (e.g., when you add a new view, set `view_count`; if you discover a new model is needed, set `new_types_count`).

### 13.4 Merge phase

1. PR opens. The per-PR bot fires automatically.
2. If the bot fails the `pm-framework/pr-integrity` status check, fix the new findings before requesting review.
3. After merge, set `state.json.phases.merge.pr_number` to the merged PR number. The pre-commit verifies it against a cached `gh pr list` result when `gh` is available (`PR_NUMBER_UNRESOLVED`).

### 13.5 Docs phase + close

1. Write `docs/case-studies/widget-customization-case-study.md`.
2. The pre-commit will scan it for:
   - PR citations (`PR #N` or `pull/N`) — `BROKEN_PR_CITATION`.
   - Missing file-level T1/T2/T3 tag in scoped post-2026-04-21 case studies — `CASE_STUDY_MISSING_TIER_TAGS`.
3. Set `current_phase = "complete"`. Set `phases.docs.completed_at`. Set `timing.total_wall_time_minutes` (sum of per-phase elapsed).
4. Add the case study to `feature-registry.json` and to fitme-story `content/04-case-studies/<NN>-<slug>.mdx` if it's showcase-worthy.

---

## 14. Operational walkthrough — extending an integrity check code

You want to add a new check code, e.g., `MISSING_METRIC_BASELINE` (a feature in `complete` phase whose PRD has no baseline number set). Here's the sequence.

### 14.1 Decide the layer

- Should it block at write-time? (Cheap and immediate; agent corrects mid-session.)
- Should it run only on the cycle? (More expensive to surface, but catches cross-session drift.)
- Should it run per-PR? (Catches before merge; status-check enforced.)

**Most checks should be cycle-time first; promote to write-time once the false-positive rate is < 1%.**

### 14.2 Add the cycle-time check

1. Open `scripts/integrity-check.py`.
2. Add a new function:
   ```python
   def check_missing_metric_baseline(state: dict, name: str) -> list[Finding]:
       if state.get("current_phase") != "complete":
           return []
       prd_path = REPO_ROOT / "docs" / "product" / "prd" / f"{name}.md"
       if not prd_path.exists():
           return []
       prd = prd_path.read_text()
       if not re.search(r"baseline:\s*\d", prd, re.IGNORECASE):
           return [Finding("MISSING_METRIC_BASELINE", name, f"PRD has no baseline number")]
       return []
   ```
3. Call it from the main loop alongside other check fns.
4. Add a row to the check-code table in CLAUDE.md "Data Integrity Framework" section.

### 14.3 Add a synthetic-violation test

Open `scripts/test-v7-5-pipeline.sh`. Add a new assertion:
```bash
# Test N: MISSING_METRIC_BASELINE fires on PRD without baseline
echo "test N: MISSING_METRIC_BASELINE fires"
mkdir -p docs/product/prd
echo "# fake PRD without baseline" > docs/product/prd/widget-customization.md
out=$(python3 scripts/integrity-check.py --findings-only)
if echo "$out" | grep -q "MISSING_METRIC_BASELINE"; then
  echo "  ✓ fired"
else
  echo "  ✗ did not fire"; exit 1
fi
rm docs/product/prd/widget-customization.md
```

### 14.4 Promote to write-time later

Once the cycle-time check is stable, copy the check function into `scripts/check-state-schema.py`'s `validate_file()` (with `enforce_transition` semantics if appropriate), add the `--staged` invocation to `.githooks/pre-commit`, and add a write-time test assertion.

---

## 15. Operational walkthrough — bumping the framework version

You shipped a structural capability (criteria in § 12.1). Here's the v7.6-style bump sequence.

### 15.1 Manifest bump

Edit `.claude/shared/framework-manifest.json`:
- Bump `version` (the manifest schema version, currently 1.8).
- Bump `framework_version` (e.g., 7.6 → 7.7).
- Update `description`.
- Add new capability flags to the `capabilities` block.
- Add a new top-level block `v<X>_<name>` mirroring the `v7_6_mechanical_enforcement` shape.

### 15.2 CLAUDE.md update

- Update the "## Data Integrity Framework" header.
- Add new check codes to the Write-time gates list.
- Add new defenses to the appropriate block.
- Update the "## Known Mechanical Limits" section if Class B gaps changed.

### 15.3 Evolution doc update

Open `docs/skills/evolution.md`:
- Update the header `> **Status:** v<X>` line.
- Add a new note dated to the ship.
- Add a new row to the version table at the bottom.

### 15.4 Case study

Write `docs/case-studies/<slug>-v<X>-case-study.md`. Follow the v7.6 case study (`mechanical-enforcement-v7-6-case-study.md`) as the format reference. Required sections include outlier framing if the work is itself an outlier.

### 15.5 Mirrors + memory

- Update repo-root `project_*.md` mirror files where relevant.
- Add a new memory entry under `~/.claude/projects/.../memory/project_<slug>.md`.
- Update `MEMORY.md` index.

### 15.6 Cross-repo

If the new capability is user-visible, add a new MDX case study slot in `fitme-story/content/04-case-studies/`. If it relates to the trust page, append a section to the appropriate trust subroute.

### 15.7 Commit + push

The pre-commit hook will catch any tier-tag gaps in the new case study and any phase-transition discipline failures. Fix and re-commit.

### 15.8 Verify

Run the regression test:
```bash
bash scripts/test-v7-5-pipeline.sh
```

All assertions should pass. If you added a new check code (per § 14), the count is now > 15.

---

## 16. References

### Canonical docs
- [`CLAUDE.md`](../../CLAUDE.md) — project rules (always loaded; fastest reference)
- [`docs/skills/architecture.md`](../skills/architecture.md) — skill-by-skill anatomy
- [`docs/skills/evolution.md`](../skills/evolution.md) — full version-by-version history
- [`docs/skills/pm-workflow.md`](../skills/pm-workflow.md) — user-facing PM workflow
- [`.claude/integrity/README.md`](../../.claude/integrity/README.md) — integrity layer canonical entry

### Case studies (most relevant for this guide)
- [`docs/case-studies/data-integrity-framework-v7.5-case-study.md`](../case-studies/data-integrity-framework-v7.5-case-study.md) — v7.5 narrative
- [`docs/case-studies/mechanical-enforcement-v7-6-case-study.md`](../case-studies/mechanical-enforcement-v7-6-case-study.md) — v7.6 narrative + comprehensive CU + workload analysis
- [`docs/case-studies/meta-analysis/unclosable-gaps.md`](../case-studies/meta-analysis/unclosable-gaps.md) — 5 mechanically unclosable Class B gaps
- [`docs/case-studies/normalization-framework.md`](../case-studies/normalization-framework.md) — CU formula reference
- [`docs/case-studies/data-quality-tiers.md`](../case-studies/data-quality-tiers.md) — T1/T2/T3 convention

### Audit artifacts
- [`docs/case-studies/meta-analysis/independent-audit-2026-04-21-gemini.md`](../case-studies/meta-analysis/independent-audit-2026-04-21-gemini.md) — verbatim Gemini audit
- [`trust/audits/2026-04-21-gemini/remediation-plan-2026-04-23.md`](../../trust/audits/2026-04-21-gemini/remediation-plan-2026-04-23.md) — remediation tracker
- [`docs/master-plan/codex-ssd-audit-2026-04-19.md`](../master-plan/codex-ssd-audit-2026-04-19.md) — Codex SSD audit (pre-v7.5 context)

### Implementation plans
- [`docs/superpowers/plans/2026-04-25-v7-6-mechanical-enforcement-phases-2-4.md`](../superpowers/plans/2026-04-25-v7-6-mechanical-enforcement-phases-2-4.md) — v7.6 plan agent output

### Scripts (alphabetical)
- [`scripts/append-feature-log.py`](../../scripts/append-feature-log.py) — contemporaneous log writer
- [`scripts/check-case-study-preflight.py`](../../scripts/check-case-study-preflight.py) — write-time case study checks
- [`scripts/check-state-schema.py`](../../scripts/check-state-schema.py) — write-time + cycle state.json checks
- [`scripts/documentation-debt-report.py`](../../scripts/documentation-debt-report.py) — Tier 3.2 ledger
- [`scripts/integrity-check.py`](../../scripts/integrity-check.py) — cycle-time integrity check
- [`scripts/measurement-adoption-report.py`](../../scripts/measurement-adoption-report.py) — Tier 1.1 ledger + history
- [`scripts/runtime-smoke-gate.py`](../../scripts/runtime-smoke-gate.py) — Tier 2.1 smoke runner
- [`scripts/test-v7-5-pipeline.sh`](../../scripts/test-v7-5-pipeline.sh) — 15-assertion regression test

### Workflows
- [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml) — Xcode build + test
- [`.github/workflows/integrity-cycle.yml`](../../.github/workflows/integrity-cycle.yml) — 72h cycle (v7.1 → v7.5)
- [`.github/workflows/pr-integrity-check.yml`](../../.github/workflows/pr-integrity-check.yml) — per-PR (v7.6 Phase 2a)
- [`.github/workflows/framework-status-weekly.yml`](../../.github/workflows/framework-status-weekly.yml) — weekly cron (v7.6 Phase 2c)

### External reference
- [GitHub Actions injection guide](https://github.blog/security/vulnerability-research/how-to-catch-github-actions-workflow-injections-before-attackers-do/) — security pattern referenced in workflow files

---

*This guide is updated whenever the framework's structural shape changes. If you find an inaccuracy or a stale reference, file a PR — the pre-commit hook will tell you immediately if the doc is out of sync with the code.*
