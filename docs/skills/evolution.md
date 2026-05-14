# PM Hub Evolution — Architecture & Skills Documentation

> **Date:** 2026-05-07 (v7.8.1 update)
> **Status:** v7.8.1 — **Branch Isolation + Feature-Closure Completeness (advisory mode)**, shipped 2026-05-07 via PR #244 (squash `6d1a53f`) + #245 (Phase 8 closure). Extends v7.8 with 3 new write-time gates + 3 new cycle-time advisories + auto-isolation flow + 2 new make targets + `/ux + /design pre-merge-review` sub-step 6f. **First feature shipped via the v7.8 protocol** — 9 phase transitions in one session, 28/28 implementation tasks, 130/130 unit tests, 19/19 pipeline assertions. v7.9 promotion candidate decision: **2026-05-21** (T+14d). See `docs/case-studies/framework-v7-8-branch-isolation-case-study.md`.
>
> **Date:** 2026-05-04 (v7.8 update)
> **Status:** v7.8 — **Bridge (advisory mode)**, fully shipped 2026-05-02 → 2026-05-04 across 9 PRs (#173 + #185–189 + #193–195). Six new mechanisms A–F all in advisory mode; v7.9 promotes to enforced after the +7d measurement window (opens **2026-05-11**). **Mechanism A**: coverage-asserting gates → `.claude/logs/gate-coverage.jsonl`. **Mechanism B**: schema field-rename detection + dual-read for `created` ∪ `created_at`. **Mechanism C**: `PostToolUse:Read` hook auto-captures cache observations + new advisory `CACHE_HITS_AUTO_INSTRUMENTATION_INACTIVE`. **Mechanism D**: pre-commit hook header self-audit. **Mechanism E**: custom git merge driver auto-resolving append-only-ledger conflicts via union-dedup-by-key. **Mechanism F**: membrane-status advisory readout. Schema bridges populated on 47/47 features. Cold-start entrypoint + honesty ledger FT2-FH-001 published.
> **2026-04-27 status (v7.7):** Validity Closure — 5 new check codes (4 gating: `CACHE_HITS_EMPTY_POST_V6`, `CU_V2_INVALID`, `STATE_NO_CASE_STUDY_LINK`, `CASE_STUDY_MISSING_FIELDS`; 1 advisory permanent: `TIER_TAG_LIKELY_INCORRECT`). 25 gates + 1 advisory total. Linkage 95.5% → 100% (gated). v7.7 silent-pass on `CACHE_HITS_EMPTY_POST_V6` (gate had 0% effective coverage because 43/46 state.json used legacy `created` key) was caught 2026-04-30 + closed 2026-05-01 via PR #169 (43 files migrated `created` → `created_at`). Extends v7.6 (Mechanical Enforcement), v7.5 (Data Integrity Framework, 8 cooperating defenses), v7.1 (72h integrity cycle), v7.0 (HADF).
> **2026-04-23 note:** Gemini follow-up hardening corrected the workflow's regression detection path, tightened trend-readiness rules to count only scheduled cycle snapshots, and kept Tier 2.1/Tier 2.2/Tier 3.2 framed as groundwork or pilot work rather than fully complete.
> **2026-04-24 note:** v7.5 shipped. 7 of Gemini's 9 Tier 1/2/3 items fully or effectively shipped; 2 partial/pilot with measured known deltas; 1 external-blocked. Integrity baseline at ship: 0 findings across 40 features + 46 case studies. See `docs/case-studies/data-integrity-framework-v7.5-case-study.md` for the full narrative.
> **2026-04-25 note:** v7.6 shipped. 7 Class B → Class A promotions (4 write-time pre-commit, 1 per-PR status check, 1 weekly regression watcher, 1 append-only history). 5 Class B gaps remain documented in [`docs/case-studies/meta-analysis/unclosable-gaps.md`](../case-studies/meta-analysis/unclosable-gaps.md). See `docs/case-studies/mechanical-enforcement-v7-6-case-study.md` for full Dev-style narrative including comprehensive CU + workload analysis (with explicit outlier caveat for retroactive v6.0 dogfooding).
> **2026-04-27 note:** v7.7 shipped. 5 new check codes (4 gating + 1 advisory permanent). cache_hits writer-path gap closed in spec via `CACHE_HITS_EMPTY_POST_V6`. 4 Class B gaps remain. See `docs/case-studies/framework-v7-7-validity-closure-case-study.md`.
> **2026-05-01 note:** v7.7 silent-pass closed via PR #169 (`framework-honesty-fixes`). 43/46 state.json migrated `created` → `created_at`; gate now actually fires. See `docs/case-studies/framework-honesty-fixes-2026-05-01-case-study.md`.
> **2026-05-02 → 2026-05-04 note:** v7.8 Bridge fully shipped across 9 PRs (#173 + #185–189 + #193–195). Six advisory mechanisms A–F. Schema bridges populated 47/47. v7.9 measurement window opens 2026-05-11. See `docs/case-studies/framework-v7-8-bridge-case-study.md` for the live append-only journal.
> **2026-05-07 note:** v7.8.1 shipped. 3 new write-time gates (`BRANCH_ISOLATION_VIOLATION` Mode B/C, `FEATURE_CLOSURE_COMPLETENESS` 7-field + Q7 + Q6, `ISOLATION_OPT_OUT_REASON_MISSING`) + 3 new cycle-time advisories. First feature to ship via the v7.8 protocol (Mechanism C session attribution + isolated worktree from Phase 1 + Tier 2.2 logging on every phase transition + Mechanism A coverage telemetry verification on its own gates). 14 commits across 9 phase transitions in one session. v7.9 promotion candidate decision 2026-05-21. See `docs/case-studies/framework-v7-8-branch-isolation-case-study.md`.
> **Supersedes:** Original serial pipeline from `/pm-workflow` v1.0

---

## 1. Why This Evolution

The original PM workflow was a **single-track serial pipeline** where every work item — from a typo fix to a major feature — went through the same 9-phase funnel:

```
Research → PRD → Tasks → UX → Implement → Test → Review → Merge → Docs
```

**Problems identified:**
1. Bug fixes blocked behind PRD and UX gates they didn't need
2. No task-level visibility — dashboard only showed feature-level cards
3. Skills (`/dev`, `/qa`, `/design`, etc.) existed but weren't wired as parallel workers
4. No cross-feature prioritization — couldn't compare urgency across features
5. No feedback loop — shipped code wasn't monitored for impact
6. All builds wrote to internal storage instead of the SSD

---

## 2. Architecture Overview (After Evolution)

```
                        ┌──────────────────────────────────────┐
                        │         PM WORKFLOW HUB               │
                        │  /pm-workflow {name}                  │
                        │                                      │
                        │  Work Types:                         ���
                        │  Feature → 10 phases (0-9 full loop) │
                        │  Enhancement → 4 phases              │
                        │  Fix → 2 phases (fast-track)         │
                        │  Chore ��� 1 phase (minimal)           │
                        └──────────┬───────────────────────────┘
                                   │
                    ┌──────────────┼──────────────┐
                    │              │              │
              ┌─────┴─────┐ ┌─────┴─────┐ ┌─────┴─────┐
              │  TASKS    │ │  TASKS    │ │  TASKS    │
              │  Feature A│ │  Fix B    ��� │  Enh C    │
              └─────┬─────┘ └─────┬─────┘ └─────┬─────┘
                    │              │              │
         ┌──────── PRIORITY QUEUE (task-queue.json) ────────┐
         │  Score: fix+3, critical+10, high+7, med+4, low+1 │
         └──────────────────────┬────────────────────────────┘
                                │
         ┌──────────────────────┼──────────────────────┐
         │                      │                      │
    ┌────┴────┐           ┌────┴────┐           ┌────┴────┐
    │ /dev    │           │ /design │           │ /qa     │
    │ T1,T2,T3│           │ T9      │           │ T10    │
    │ (ready) │           │ (ready) │           │(blocked)│
    └────┬────┘           └────┬────┘           └────┬────┘
         │                      │                      │
         └──────────┬───────────┘                      │
                    ▼                                   │
              Test + Review ◄───────────────────────────┘
              (NON-NEGOTIABLE)
                    │
                    ▼
              MERGE ──→ Change Broadcast ──→ ALL SKILLS NOTIFIED
                │              │                    │
                │         ┌────┴────┐          ┌────┴────┐
                │         │ /cx     │          │ /qa     │
                │         │ monitor │          │ regress │
                │         └────┬────┘          └────┬────┘
                │              │                    │
                │         (issue found?) ◄──────────┘
                │              │
                └──────────────┘ ← creates new Fix/Enhancement
                     FEEDBACK LOOP CLOSES
```

---

## 3. Work Item Types

| Type | Phases | Gates | When to Use |
|------|--------|-------|-------------|
| **Feature** | Research → PRD → Tasks → UX → Implement → Test → Review → Merge → Docs | Research, PRD, Tasks, UX, Test, Review | New capabilities, new screens, new services |
| **Enhancement** | Tasks → Implement → Test → Review → Merge | Tasks, Test, Review | Improvements to shipped features with existing PRDs |
| **Fix** | Implement → Test → Review → Merge | Test, Review | Bug fixes, error handling, security patches |
| **Chore** | Implement → Review → Merge | Review | Docs, config, refactoring, dependency updates |

**Key rule:** ALL code-changing work types require Test + Review before merge. Fast-tracking reduces _planning_ overhead, not _quality_ gates.

**Lifecycle definitions:** `.claude/shared/skill-routing.json` → `lifecycles` object

---

## 4. Task-Level State Tracking

Tasks are now first-class citizens in `state.json`:

```json
{
  "feature": "onboarding",
  "work_type": "feature",
  "current_phase": "implement",
  "tasks": [
    {
      "id": "T1",
      "title": "OnboardingContainerView with page controller",
      "type": "ui",
      "skill": "dev",
      "status": "ready",
      "priority": "high",
      "effort_days": 0.5,
      "depends_on": [],
      "completed_at": null
    }
  ]
}
```

**Status lifecycle:** `pending` → `ready` (all deps done) → `in_progress` → `done` | `blocked`

**Backwards compatible:** State files without `tasks` array work as before.

---

## 5. Skill Routing

Each task type maps to a primary skill + optional secondary skills:

| Task Type | Primary Skill | Secondary |
|-----------|--------------|-----------|
| `ui` | `/dev` | `/design` |
| `backend` | `/dev` | `/ops` |
| `analytics` | `/analytics` | `/qa` |
| `test` | `/qa` | `/dev` |
| `design` | `/design` | `/research` |
| `infra` | `/ops` | `/dev` |
| `security` | `/qa` | `/ops`, `/dev` |
| `docs` | `/release` | `/marketing` |

**Source:** `.claude/shared/skill-routing.json`

---

## 6. Parallel Task Dispatch

During Phase 4 (Implement), the PM workflow:

1. **Computes ready set** — tasks where all `depends_on` are "done"
2. **Groups by skill** — organizes ready tasks by their assigned skill
3. **Presents parallel options** to user
4. **Executes concurrently** across skills
5. **Recomputes** after each completion (may unblock dependent tasks)
6. **Rebuilds priority queue** in `task-queue.json`

---

## 7. Cross-Feature Priority Queue

**File:** `.claude/shared/task-queue.json`

**Scoring formula:** `priority_score = base[priority] + work_type_boost[work_type]`

| Priority | Base Score | + Fix Boost | + Enhancement Boost |
|----------|-----------|-------------|---------------------|
| Critical | 10 | 13 | 11 |
| High | 7 | 10 | 8 |
| Medium | 4 | 7 | 5 |
| Low | 1 | 4 | 2 |

**Result:** Fixes automatically jump the queue. Critical fixes score 13 (highest possible).

---

## 8. Change Broadcast Protocol

When ANY work item merges to main:

1. **Update** `.claude/shared/feature-registry.json` with what changed
2. **Notify downstream skills** based on change type:
   - Code change → `/qa`, `/cx`, `/ops`, `/analytics`
   - UI change → above + `/design`
   - Analytics change → `/qa`, `/cx`, `/analytics`
   - Infra change → `/qa`, `/ops`, `/dev`
   - Docs change → `/cx`, `/marketing`
3. **Write event** to `.claude/shared/change-log.json`

**Source:** `.claude/shared/change-log.json` → `notification_rules`

---

## 9. Upstream Feedback Loop

When `/cx analyze` or `/qa regression` detects a post-merge issue:

1. **Classify signal:**
   - Customer confusion → `/marketing` + `/design`
   - Regression → `/dev` + `/qa`
   - Performance degradation → `/ops` + `/dev`
   - Expectation mismatch → `/pm-workflow` (re-scope)
2. **Create new work item** (Fix or Enhancement) linked to original change
3. **Inherit context** from the original — no information lost
4. **Monitor resolution** via `/cx` re-analysis after fix ships

---

## 10. Dashboard Visualization

### New "Tasks" Tab (3rd view alongside Board and Table)

**TaskBoard** — Swim lanes organized by skill:
```
/dev:       [T1 ✓] [T2 ●] [T3 ○]
/design:    [T9 ○]
/analytics: [T8 ◌ blocked]
/qa:        [T10 ◌ blocked]
```

**TaskCard** — Compact card per task: ID badge, title, skill tag, status dot, effort estimate

**DependencyGraph** — SVG DAG: nodes = tasks, edges = dependencies, critical path highlighted in red

**Priority Queue Sidebar** — Top 10 ready tasks ranked by priority score across all features

**FeatureCard Enhancement** — Work type badge + task progress bar (e.g., "3/10 tasks done")

### Test Coverage
- `dashboard/tests/tasks.test.js` — 21 tests covering: ready set, blocked set, critical path, priority queue, full parser

---

## 11. SSD Storage Architecture

All build artifacts stay on the SSD alongside the project:

| Variable | Path | Purpose |
|----------|------|---------|
| `BUILD_DIR` | `$(PROJECT_ROOT).build` | Root for all artifacts |
| `AI_VENV` | `.build/ai-venv` | Python virtual environment |
| `SPM_CACHE` | `.build/spm-cache` | Swift Package Manager cache |
| `CLANG_MODULE_CACHE_PATH` | `.build/clang-cache` | Clang module cache |
| `DERIVED_DATA` | `.build/DerivedData` | Xcode build products |
| `TEST_DERIVED_DATA` | `.build/TestDerivedData` | Test products |
| `npm cache` | `.build/npm-cache` | npm package cache |

**Mac setup:** `defaults write com.apple.dt.Xcode IDECustomDerivedDataLocation "/Volumes/DevSSD/FitTracker2/.build/DerivedData"`

Note: `verify-ios` no longer overrides `HOME` / `CFFIXED_USER_HOME` into `.build/xcode-home` because Xcode asset catalogs and SwiftUI preview linking require the real CoreSimulator device set under the user home directory.

---

## 12. File Inventory

### New Files Created
| File | Purpose |
|------|---------|
| `.claude/shared/task-queue.json` | Cross-feature priority queue |
| `.claude/shared/change-log.json` | Change broadcast audit log |
| `.claude/shared/skill-routing.json` | Task→skill routing + lifecycle definitions |
| `.npmrc` | npm cache → SSD |
| `dashboard/src/components/TaskBoard.jsx` | Skill swim lanes |
| `dashboard/src/components/TaskCard.jsx` | Task card component |
| `dashboard/src/components/DependencyGraph.jsx` | SVG DAG visualization |
| `dashboard/src/scripts/parsers/tasks.js` | Task parser (6 exports) |
| `dashboard/tests/tasks.test.js` | 21 parser tests |
| `docs/skills/evolution.md` | This document |

### Modified Files
| File | Changes |
|------|---------|
| `.claude/skills/pm-workflow/SKILL.md` | Work types, structured tasks, parallel dispatch, review gates, change broadcast, feedback loop |
| `CLAUDE.md` | Work item types section |
| `Makefile` | SSD-local `.build/` directory for all artifacts |
| `.gitignore` | `.build/` exclusion |
| `README.md` | SSD setup instructions |
| `dashboard/src/components/Dashboard.jsx` | Tasks tab |
| `dashboard/src/components/FeatureCard.jsx` | Work type badge + task progress bar |
| `dashboard/src/scripts/parsers/unified.js` | Task summaries on feature objects |
| `dashboard/src/scripts/reconcile.js` | Stale task + skill overload alerts |

---

## 13. Dependency Map

```
CLAUDE.md (rules)
  └─→ SKILL.md (pm-workflow, enforces rules)
        ├─→ state.json (lifecycle state + tasks[])
        ├─→ skill-routing.json (task assignments + lifecycle defs)
        ├─→ task-queue.json (priority queue, rebuilt on changes)
        └─→ change-log.json (post-merge broadcast)
              └─→ All skills notified (qa, cx, ops, analytics, design)
                    └─→ /cx analyze → finds issue → creates Fix/Enhancement
                          └─→ Back to SKILL.md (new work item) ← LOOP CLOSES

Dashboard reads:
  state.json → unified.js → Board/Table views (feature-level)
  state.json → tasks.js → TaskBoard/TaskCard/DependencyGraph (task-level)
  reconcile.js → AlertsBanner (stale tasks, skill overload, conflicts)
```

---

## 14. UX Foundation Layer (Added 2026-04-06)

### Why This Exists

The PM workflow defined 8 UX principles as bullet points in Phase 3, but only 2 of 16 features had ever completed a formal UX spec. Zero `ux-research.md` files existed. The 11 core shipped features were built pre-PM-workflow with no UX framework.

### What Was Added

**New Skill: `/ux`** (`.claude/skills/ux/SKILL.md`)

A dedicated UX planning and validation skill with 5 sub-commands:

| Command | Purpose | Output |
|---------|---------|--------|
| `/ux research {feature}` | UX research against 13 principles + HIG + competitors | `ux-research.md` |
| `/ux spec {feature}` | Full UX specification with flows, states, accessibility | `ux-spec.md` |
| `/ux validate {feature}` | Heuristic evaluation + principle compliance check | Validation report |
| `/ux audit` | App-wide UX audit (missing states, a11y, navigation depth) | Audit report |
| `/ux patterns` | Quick reference to the UX pattern library | Pattern summary |

**Boundary with `/design`:**
- `/ux` owns the **what and why** — user flows, behavior, heuristics, accessibility-as-usability
- `/design` owns the **how it looks** — tokens, components, Figma, compliance gateway

**New Document: `docs/design-system/ux-foundations.md`**

A comprehensive 10-part UX reference document grounding all future UI decisions:

1. Design Philosophy & Principles (8 core + 5 FitMe-specific)
2. Information Architecture (navigation model, content hierarchy, data flow)
3. Interaction Patterns (navigation, input, feedback, gesture)
4. Data Visualization Patterns (charts, metrics, color semantics)
5. Permission & Trust Patterns (HealthKit, notifications, ATT, GDPR)
6. State Patterns (empty, loading, error, success)
7. Accessibility Standards (visual, motor, cognitive, screen reader)
8. Micro-Interactions & Motion (animation principles, haptic patterns)
9. Content Strategy (terminology, number formatting, health sensitivity)
10. Platform-Specific Patterns (iPhone, iPad, Apple Watch)

**13 UX Principles** (expanded from 8):

| # | Principle | Category |
|---|-----------|----------|
| 1-8 | Fitts's, Hick's, Jakob's, Progressive Disclosure, Recognition over Recall, Consistency, Feedback, Error Prevention | Core (universal) |
| 9 | Readiness-First | FitMe-specific |
| 10 | Zero-Friction Logging | FitMe-specific |
| 11 | Privacy by Default | FitMe-specific |
| 12 | Progressive Profiling | FitMe-specific |
| 13 | Celebration Not Guilt | FitMe-specific |

**PM Workflow Integration:**

| Phase | /ux Command | When |
|-------|-------------|------|
| Phase 0 | `/ux research` | After research, before PRD |
| Phase 3 | `/ux spec` → `/ux validate` | Before design compliance |
| Phase 5 | `/ux validate` | Post-implementation check |
| Post-Launch | `/ux audit` | When CX signals indicate issues |

### Updated Dependency Map

```
CLAUDE.md (rules)
  └─→ SKILL.md (pm-workflow)
        ├─→ /ux research → ux-research.md (Phase 0/3)
        ├─→ /ux spec → ux-spec.md (Phase 3)
        ├─→ /ux validate → validation report (Phase 3/5)
        ├─→ /design audit → compliance check (Phase 3)
        ├─→ state.json (lifecycle + tasks[])
        ├─→ skill-routing.json (task assignments)
        ├─→ task-queue.json (priority queue)
        └─→ change-log.json (post-merge broadcast)
              └─→ All skills notified
                    └─→ /cx analyze → /ux audit → Fix/Enhancement
```

---

## 15. v3.0 — External Integrations, Screen Audits & Multi-Screen V2 (2026-04-09)

### What Changed

The ecosystem crossed two thresholds in a single session: **external tool integration** (Notion MCP, Figma MCP) and **scaled v2 refactoring** validated across multiple screens within one feature.

### Session Accomplishments

- **5 features shipped via PM workflow** — Home Today Screen v2 (#61), Onboarding retro (#63), Body Composition card (#65), Metric Deep Link (#67), Training Plan v2 (#74).
- **First end-to-end Figma MCP integration** — design builds executed directly from Figma file references via MCP, closing the gap between design artifacts and implementation.
- **New sub-commands** — `/ux wireframe` (ASCII wireframes at 3 fidelity levels) and `/design build` (Figma MCP design-to-code with SwiftUI fallback).
- **Screen audit research mode** — a new Phase 0 variant that scopes a v2 refactor by auditing an existing screen against UX Foundations before any code is written. Produces a `v2-audit-report.md` with numbered findings and a decisions log.
- **Sub-feature queue pattern** — parent audit (Home v2) spawned 4 child features, each tracked independently with `parent_feature` links in `state.json`.
- **Parallel subagent execution across skills** — multiple skills dispatched simultaneously during implementation phases, with independent tasks running in parallel subagents and converging at review gates.

### New Capabilities

| Capability | Description |
|---|---|
| **Auto-sync to Notion/GitHub on phase transitions** | Phase advances in `state.json` trigger status updates to the Notion project board and GitHub Issue labels simultaneously. No manual dashboard sync needed. |
| **Research-only audit mode** | `/ux audit` can now run in a scoping-only mode for screen refactors — produces findings and a decisions log without requiring a full UX spec upfront. Used for the Home v2 27-finding audit. |
| **BodyCompositionDetailView drill-down pattern** | Established the reusable pattern for metric tile tap → detail view navigation with deep linking support. Available as a reference pattern for future metric screens. |
| **v2/ subdirectory convention validated at scale** | The `v2/` split (introduced in CLAUDE.md for the Home screen) was validated across multiple views within one feature, confirming the convention scales beyond single-file refactors. |
| **`/ux wireframe` sub-command** | Generates ASCII wireframes at three fidelity levels (low, medium, high) for a feature. Used during Home v2 and Training v2 Phase 3 specs. |
| **`/design build` sub-command** | Executes a Figma MCP design-to-code build with SwiftUI fallback. Reads Figma context via `get_design_context`, adapts to project tokens. |
| **Sub-feature queue** | Parent audit spawns child features with `parent_feature` links. Validated with Home v2 → 4 sub-features. |

### Integration Expansion

| Integration | Protocol | Direction | Purpose |
|---|---|---|---|
| **Notion MCP** | MCP (Model Context Protocol) | Bidirectional | Project status board updates on phase transitions, feature cards synced from `state.json` |
| **Figma MCP** | MCP (Model Context Protocol) | Read + Write | Design context retrieval (`get_design_context`), screenshot capture, code connect mapping for design-to-code builds |
| **GitHub** | `gh` CLI | Bidirectional | Issue labels, PR management, CI status, milestone tracking |
| **Vercel** | Deploy preview | Read | Preview URLs attached to PRs for visual review |

### Updated Dependency Map

```text
CLAUDE.md (rules)
  └─→ SKILL.md (pm-workflow)
        ├─→ /ux research → ux-research.md (Phase 0/3)
        ├─→ /ux audit (screen scope) → v2-audit-report.md (Phase 0 v2)
        ├─→ /ux spec → ux-spec.md (Phase 3)
        ├─→ /ux wireframe → ASCII wireframes (Phase 3)
        ├─→ /ux validate → validation report (Phase 3/5)
        ├─→ /design audit → compliance check (Phase 3)
        ├─→ /design build → Figma MCP → SwiftUI (Phase 4)
        ├─→ state.json (lifecycle + tasks[])
        ├─→ skill-routing.json (task assignments)
        ├─→ task-queue.json (priority queue)
        ├─→ change-log.json (post-merge broadcast)
        │     └─→ All skills notified
        │           └─→ /cx analyze → /ux audit → Fix/Enhancement
        │
        ├─→ Notion MCP ← phase transition sync
        ├─→ Figma MCP ← design context + code connect
        ├─→ GitHub ← labels, PRs, CI
        └─→ Vercel ← deploy previews
```

---

## 16. Migration Notes

- **Backwards compatible:** State.json files without `tasks[]` or `work_type` fields work as `type: "feature"` with feature-level tracking only
- **New features should use `work_type`** — selected during `/pm-workflow` initialization
- **Existing features can be upgraded** by adding a `tasks[]` array to their state.json
- **Dashboard auto-detects** — shows task views only for features with structured tasks

---

## 17. v4.0 — Reactive Data Mesh + Learning Cache (2026-04-10)

### What Changed: v3.0 → v4.0

| Aspect | v3.0 | v4.0 |
|--------|------|------|
| **Data origin** | Manual (conversation only) | Manual + external (MCPs, APIs) |
| **Data entry** | Only during active phases | Any time, any entry point |
| **Validation** | None (trust what skills write) | Automatic gate (GREEN/ORANGE/RED) |
| **Repeated work** | Full re-derivation every time | Learning cache (L1/L2/L3) accelerates |
| **External services** | 4 (GitHub, Notion, Figma, Vercel) | 10+ (+ GA4, Sentry, ASC, Firecrawl, Axe, Security Audit) |
| **Skill contract** | Read shared → work → write shared | Read shared + cache → work → write shared + cache |

### New Architectural Layers

**1. Integration Adapter Layer** (`.claude/integrations/{service}/`)
- Each external service gets: `adapter.md` (how to call), `schema.json` (response shape), `mapping.json` (field normalization)
- Isolates MCP format changes from skills — update one mapping, not every consumer
- 6 adapters shipped: ga4, app-store-connect, sentry, firecrawl, axe, security-audit

**2. Automatic Validation Gate**
- All incoming data cross-referenced against existing shared layer state
- Score = consistent fields / total comparable fields
- GREEN (>= 95%): write + notify. ORANGE (90-95%): write + advisory. RED (< 90%): block + alert.
- Two parties always notified: receiving skill + /pm-workflow
- Validation is automatic. Resolution is always manual.

**3. Learning Cache** (`.claude/cache/`)
- L1 (per-skill): patterns from prior executions. Hot.
- L2 (cross-skill, `_shared/`): patterns shared by 2+ skills. Warm.
- L3 (project-wide, `_project/`): architectural conventions. Cold.
- Cache entries: task_signature, learned_patterns, anti_patterns, speedup_instructions
- Staleness via SHA256 hashes of source files
- Demonstrated ~65% speedup by 4th similar task

### Core Principle: Reactive Data Mesh

> "Any entry point, any time, data flows."

- MCPs are open ports — data flows the moment they connect
- Any single skill invocation can trigger system-wide enrichment
- Data enriches retroactively — existing features get smarter
- Hub orchestrates but doesn't gatekeep data flow

### File Tree (new in v4.0)

```text
.claude/
├── cache/                    ← NEW: Learning cache
│   ├── _index.json           ← master schema + lifecycle
│   ├── {skill}/              ← L1: per-skill caches (11 dirs)
│   │   ├── _index.json       ← skill-level index
│   │   └── {pattern}.json    ← cached patterns
│   ├── _shared/              ← L2: cross-skill (2+ skills)
│   └── _project/             ← L3: project-wide (5+ skills)
├── integrations/             ← NEW: Adapter layer
│   ├── _template/            ← boilerplate for new adapters
│   ├── ga4/                  ← GA4 Analytics MCP
│   ├── app-store-connect/    ← App Store Connect MCP
│   ├── sentry/               ← Sentry Error Tracking MCP
│   ├── firecrawl/            ← Web Scraping MCP
│   ├── axe/                  ← Accessibility Audit MCP
│   └── security-audit/       ← Dependency Security MCP
├── shared/                   ← UPDATED: +validation_gate config
│   ├── change-log.json       ← v2.0: +validation_log, +validation_entry_schema
│   └── skill-routing.json    ← v2.0: +integration_sources, +validation_gate
└── skills/                   ← UPDATED: each SKILL.md gets 4 new sections
    └── {skill}/SKILL.md      ← +External Data Sources, +Validation Gate, +Research Scope, +Cache Protocol
```

---

## 18. v4.1 — Skill Internal Lifecycle (2026-04-10)

### What Changed: v4.0 → v4.1

v4.0 gave skills external data sources and a cache. v4.1 formalizes how skills USE them internally — every skill now mirrors the hub's structure with a 4-phase internal lifecycle.

### The 4-Phase Skill Internal Lifecycle

```text
┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
│ 1. CACHE │───▶│2. RESEARCH│───▶│3. EXECUTE│───▶│ 4. LEARN │
│  CHECK   │    │ (if miss)│    │          │    │          │
└──────────┘    └──────────┘    └──────────┘    └──────────┘
```

1. **Phase 1 — Cache Check:** Read L1/L2/L3 caches for matching task signature. If hit → skip to Phase 3 with cached patterns.
2. **Phase 2 — Research (if needed):** When cache misses, investigate tools, APIs, MCPs, methods, patterns. Each skill has a domain-specific research scope (5 dimensions + source priority).
3. **Phase 3 — Execute:** Do the work using cached + researched knowledge.
4. **Phase 4 — Learn:** Extract patterns + anti-patterns, write to L1 cache, flag cross-skill patterns for L2 promotion.

### Why This Matters

Without the lifecycle, skills are stateless — they produce the same output but never get faster. With it:
- 1st invocation: full research, cold cache (slow)
- 2nd similar invocation: cache hit, skip research (faster)
- Nth similar invocation: hot cache + anti-patterns, only novel work needed

### SKILL.md Contract Update

Every SKILL.md now has 4 sections (was 3 in v4.0):
1. **External Data Sources** — adapters + validation gate
2. **Research Scope (Phase 2)** — 5 domain-specific research dimensions + source priority
3. **Cache Protocol** — Phase 1 (Cache Check) + Phase 4 (Learn) behavior
4. **Cross-Skill Cache Promotion** — when to promote to L2 (hub only)

---

## 19. v4.2 — Self-Healing Hub with Integrity Verification (2026-04-10)

### What Changed: v4.1 → v4.2

v4.1 gave skills a 4-phase internal lifecycle (Cache → Research → Execute → Learn). v4.2 adds **Phase 0 (Health Check)** — making the lifecycle 5 phases and introducing self-verification into the hub itself.

| Aspect | v4.1 | v4.2 |
| --- | --- | --- |
| **Skill lifecycle phases** | 4 (Cache → Research → Execute → Learn) | 5 (Health → Cache → Research → Execute → Learn) |
| **Self-monitoring** | None — trust that cache and shared layer are correct | Probabilistic integrity verification (25% trigger, 2h cooldown) |
| **Cache accuracy tracking** | hit_count only | hit_count + correction_count (feeds back to health score) |
| **Alert system** | Validation gate for external data only | Validation gate + internal health check with 3-tier alerts |
| **Rollback protocol** | Manual | Structured (fix / rollback cache / rollback all) |

### The 5-Phase Skill Internal Lifecycle (v4.2)

```text
┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
│ 0. HEALTH│───▶│ 1. CACHE │───▶│2. RESEARCH│───▶│3. EXECUTE│───▶│ 4. LEARN │
│  CHECK   │    │  CHECK   │    │ (if miss) │    │          │    │          │
└──────────┘    └──────────┘    └──────────┘    └──────────┘    └──────────┘
```

0. **Phase 0 — Health Check (random trigger):** On ~25% of skill invocations (with 2h cooldown), run 5 weighted integrity checks. If score < 90%, STOP and alert.
1. **Phase 1 — Cache Check:** (unchanged from v4.1)
2. **Phase 2 — Research:** (unchanged)
3. **Phase 3 — Execute:** (unchanged)
4. **Phase 4 — Learn:** (unchanged) + now also updates `correction_count` if a cached pattern was overridden during execution.

### The 5 Health Checks

| Check | Weight | What It Verifies |
| --- | --- | --- |
| Cache Staleness | 0.25 | SHA256 hashes of invalidated_by source files match. Stale entry = cache is lying. |
| Cache Hit Accuracy | 0.25 | hit_count vs correction_count ratio. Low accuracy = cache patterns are wrong. |
| Shared Layer Consistency | 0.20 | Cross-references between shared JSON files (feature status, metric instrumentation, token counts). |
| Skill Routing Integrity | 0.15 | Task types in skill-routing.json map to existing SKILL.md files and cache dirs. |
| Adapter Availability | 0.15 | Each adapter dir has adapter.md + schema.json + mapping.json. |

### Alert Levels

| Level | Score | Action |
| --- | --- | --- |
| Healthy | >= 0.95 | Silent. Log only. |
| Warning | 0.90 - 0.95 | Log + advisory to user. Continue execution. |
| Critical | < 0.90 | Log + STOP. Alert with failing checks. User chooses: fix, rollback cache, or rollback all. |

### Why Self-Healing Matters

Without self-verification, a corrupted cache or inconsistent shared layer silently degrades every skill invocation. The health check catches drift before it compounds — the same principle as CI catching code drift, applied to the framework's own data layer.

### New Files

- `.claude/shared/framework-health.json` — health check config, scoring weights, history log

### Updated Files

- `.claude/cache/_index.json` — lifecycle now 5 phases (Phase 0 added)
- `.claude/shared/skill-routing.json` — validation_gate section added
- All 11 SKILL.md files — Health Check (Phase 0) section added to Cache Protocol

### SKILL.md Contract Update (v4.2)

Every SKILL.md now has 5 sections (was 4 in v4.1):

1. **Cache Protocol** — Phase 0 (Health Check) + Phase 1 (Cache Check) + Phase 4 (Learn) behavior
2. **External Data Sources** — adapters + validation gate
3. **Research Scope (Phase 2)** — 5 domain-specific research dimensions + source priority
4. **Cross-Skill Cache Promotion** — when to promote to L2 (hub only)

### Cache Seeding (shipped with v4.2)

5 L1 cache entries seeded from 6 completed v2 refactors:

- `/ux` — v2-screen-audit-playbook (audit methodology, severity calibration, anti-patterns)
- `/design` — token-compliance-checker (violation categories, DS evolution, compound reuse)
- `/analytics` — screen-prefix-convention (naming rule, event templates, test density)
- `/dev` — v2-implementation-recipe (v2/ directory convention, extracted views, commit strategy)
- `/qa` — analytics-test-patterns (right-sized density 1.3-2.7x, test templates)

5 L2/L3 entries updated with data from all 6 refactors (hit_count = 6).

---

## 20. v4.3 — Operations Control Room + Case-Study Monitoring (2026-04-11)

### What Changed: v4.2 → v4.3

v4.2 made the framework self-healing. v4.3 adds the operational layer around that core: a control room surface, case-study monitoring as shared infrastructure, and maintenance cleanup programs as first-class framework work.

| Aspect | v4.2 | v4.3 |
| --- | --- | --- |
| **Framework focus** | Internal integrity and self-healing | Integrity + operational visibility + showcase-ready monitoring |
| **Primary operator surface** | Shared files and docs | Shared files + dashboard control room |
| **Maintenance programs** | Possible but informal | Explicitly framed as framework-native work |
| **Case-study capture** | Narrative after the fact | Structured monitoring during execution |
| **Cross-system truth repair** | Manual audit exercise | Measured, repeatable operational loop |

### New Capabilities

- `dashboard/src/components/ControlRoom.jsx` gives the framework an operator cockpit for source health, delivery, UX and design review, and product intelligence.
- `.claude/shared/case-study-monitoring.json` is now first-class shared infrastructure for monitoring showcase-worthy work while it is happening.
- Maintenance cleanup programs are now treated as valid framework runs, not off-framework exceptions.
- The framework can now tell the story of a cycle as it unfolds, not only after release retrospectives.

### Updated Files

- `dashboard/src/components/ControlRoom.jsx`
- `dashboard/src/data/caseStudies.json`
- `.claude/shared/case-study-monitoring.json`
- `docs/case-studies/cleanup-control-room-case-study.md`
- `docs/skills/README.md`
- `docs/skills/architecture.md`

### Why v4.3 Matters

The hub is no longer only a planning and dispatch system. With v4.3, the framework also operates as its own observability and storytelling layer: it can repair truth drift, monitor maintenance progress, and accumulate evidence that later becomes a credible case study.

---

## 21. v4.4 — Eval-Driven Development (2026-04-13)

### What Changed: v4.3 → v4.4

v4.3 gave the framework operational visibility. v4.4 closes the quality loop: AI output quality is now testable, not just code correctness. The Skill Internal Lifecycle gains Phase 5 (Eval) — making every skill execution verifiable against deterministic golden cases, quality heuristics, and tier behavior expectations.

| Aspect | v4.3 | v4.4 |
| --- | --- | --- |
| **Lifecycle phases** | 5 (Health → Cache → Research → Execute → Learn) | 6 (Health → Cache → Research → Execute → Learn → Eval) |
| **Output quality testing** | None — correctness only (unit tests, CI) | Deterministic evals: golden I/O, heuristics, tier behavior |
| **Case study data** | Narrative + delivery metrics | Narrative + delivery metrics + eval pass/fail + quality scores |
| **Eval definitions** | Not a framework concept | Defined in Phase 2 (Tasks), run in Phase 5 (Test), analyzed in Phase 9 (Learn) |
| **Framework self-improvement** | Anti-patterns from Learn phase only | Anti-patterns from Learn + failed evals promoted to L1 anti-pattern cache |

### The 6-Phase Skill Internal Lifecycle

```text
Phase 0 Health → 1 Cache → 2 Research → 3 Execute → 4 Learn → 5 Eval
```

### Phase 5 — Eval

Runs after Phase 4 (Learn) when eval definitions exist for the current task. Checks golden input/output pairs, quality heuristics, and tier behavior expectations. Records pass/fail counts and quality scores in `case-study-monitoring.json`. Failed evals become anti-patterns and are promoted to the L1 cache, feeding back into Phase 4 on future executions. If no eval definitions exist for the task, Phase 5 is skipped silently.

### Eval Categories

| Category | Count | What It Checks |
| --- | --- | --- |
| **ReadinessFormulaEvals** | 7 golden I/O | Deterministic formula outputs for known input combinations (HRV, sleep, soreness, stress levels). Each case has a fixed expected readiness score and tier. |
| **AIOutputQualityEvals** | 7 heuristic | Output quality properties: recommendation specificity, personalization signal use, explanation clarity, goal alignment, avoidance of generic advice, sensitivity to recovery context, actionability. |
| **AITierBehaviorEvals** | 6 tier behavior | Correct tier assignment and tier-appropriate response behavior: green tier pushes, yellow tier modifies, red tier blocks, each with appropriate explanation and confidence bounds. |

### New Schema: ai_quality_metrics in case-study-monitoring.json

```json
"ai_quality_metrics": {
  "eval_run_id": "string — ISO 8601 timestamp of eval run",
  "total_evals": "number",
  "passed": "number",
  "failed": "number",
  "categories": {
    "formula_golden_io": { "passed": "number", "failed": "number" },
    "output_quality_heuristics": { "passed": "number", "failed": "number" },
    "tier_behavior": { "passed": "number", "failed": "number" }
  },
  "failed_eval_ids": ["array of eval IDs promoted to anti-pattern cache"],
  "quality_score": "number — passed / total (0.0–1.0)"
}
```

### PM Workflow Integration

| Phase | Eval Activity |
| --- | --- |
| **Phase 2 (Tasks)** | Define eval cases: golden I/O pairs, quality heuristics, tier behavior expectations. Store in `.claude/features/{name}/evals.json`. |
| **Phase 5 (Test)** | Run evals alongside unit tests. Record results in `case-study-monitoring.json` under `ai_quality_metrics`. Failed evals block phase advancement (same as failing unit tests). |
| **Phase 9 (Learn)** | Analyze eval results. Identify patterns in failures. Promote failed eval signatures to L1 anti-pattern cache. Update eval definitions if feature scope changed. |

---

## 22. v5.0 — SoC-on-Software: Skill-on-Demand + Cache Compression (2026-04-14)

### What Changed: v4.4 → v5.0

v4.4 closed the quality loop with evals. v5.0 tackles the **context budget bottleneck** — the hub was loading ~96K tokens per session (~48% of the 200K practical context window). By applying chip architecture principles from Apple's LoRA adapters and palettization, v5.0 reclaims ~54K tokens (27% of context) without any structural rebuild.

| Aspect | v4.4 | v5.0 |
| --- | --- | --- |
| **Skill loading** | All 11 SKILL.md files loaded every session (~38K tokens) | On-demand: only 1-2 phase-relevant skills loaded (~4-8K tokens) |
| **Cache loading** | Full cache entries loaded (~32K tokens) | Compressed views (~200 words each) loaded by default; full expansion on demand |
| **Context budget** | ~96K tokens (48% of 200K) | ~42K tokens (21% of 200K) — ~54K reclaimed |
| **Config** | `skill-routing.json` v2.0 | `skill-routing.json` v3.0 with `phase_skills` map and `load_mode: on_demand` |

### SoC Principles Applied

| # | Chip Principle | Software Implementation | Impact |
| --- | --- | --- | --- |
| 1 | Apple LoRA Hot-Swap | `phase_skills` map → load only listed skills | ~30K tokens saved |
| 2 | Apple Palettization (3.7-bit) | `compressed_view` field on all cache entries | ~24K tokens saved |

### How It Works

**Skill-on-Demand Loading:**
1. Hub reads `skill-routing.json` → `phase_skills[current_phase]`
2. Gets skill list (e.g. `["ux", "design"]` for UX phase)
3. Loads ONLY those SKILL.md files — others stay unloaded
4. Fallback: if `load_mode` is not `on_demand`, loads all skills (v4.4 behavior)

**Cache Compression:**
1. Every L1/L2/L3 cache entry has a `compressed_view` field (~200 words)
2. Hub loads compressed views by default
3. Full cache entries expanded only when deeper investigation is needed
4. `compression_version: "1.0"` tracks the compression schema

### Phase-to-Skills Map

```json
{
  "research": ["research", "cx"],
  "prd": ["pm-workflow", "analytics"],
  "tasks": ["pm-workflow"],
  "ux_or_integration": ["ux", "design"],
  "implementation": ["dev", "design"],
  "testing": ["qa", "analytics"],
  "review": ["dev", "qa"],
  "merge": ["release", "dev"],
  "documentation": ["marketing", "cx"],
  "learn": ["cx", "analytics", "ops"]
}
```

### Research Foundation

This optimization is backed by academic research and industry practice:
- Speculative Actions for LLM Agents (arxiv 2510.04371)
- Pattern-Aware Speculative Tool Execution (arxiv 2603.18897)
- Apple Foundation Models Tech Report (2025)
- Google TPU Architecture documentation

Full research: `docs/architecture/soc-software-architecture-research.md`

### Completed Items (v5.x roadmap)

| # | Optimization | Effort | Expected Impact | Status |
| --- | --- | --- | --- | --- |
| 3 | Batch skill invocation (TPU weight-stationary) | Medium | 5x fewer dispatches | **v5.1** |
| 4 | Result forwarding (UMA zero-copy) | Medium | Eliminate write-read cycles | **v5.1** |
| 5 | Model tiering (ANE mixed precision) | Low | Cost savings | **v5.1** |
| 6 | Speculative pre-loading (branch prediction) | Medium | 30-40% latency reduction | **v5.1** |
| 7 | Systolic chain protocol (TPU systolic array) | High | Eliminate global reads | **v5.1** |
| 8 | Hybrid task dispatch (ARM big.LITTLE) | Medium | Parallel lightweight + serial heavyweight | **v5.1** |

---

## 23. v5.1 — SoC-on-Software: Batch Dispatch, Result Forwarding, Model Tiering, Speculative Preloading, Systolic Chains (2026-04-14)

### What Changed: v5.0 → v5.1

v5.0 reclaimed ~54K tokens via skill-on-demand loading and cache compression. v5.1 completes the SoC-on-Software optimization suite with five additional hardware-inspired optimizations targeting dispatch overhead, serialization waste, cost efficiency, latency, and pipeline bottlenecks.

| Aspect | v5.0 | v5.1 |
| --- | --- | --- |
| **SoC items implemented** | 2 of 7 | 7 of 7 |
| **Dispatch model** | Individual per-skill per-target | Batch dispatch for multi-target operations |
| **Inter-skill data flow** | Write-to-disk-read-back | Inline forwarding (disk for audit trail only) |
| **Model selection** | User choice | Advisory tier per phase (sonnet/opus) |
| **Cache loading** | On-demand, on skill start | Speculative pre-load of likely-next-skill cache |
| **Pipeline protocol** | Per-skill with global reads | Systolic chains with full/partial isolation |

### Item 5: Model Tiering (ANE Mixed Precision)

Sonnet for mechanical phases (tasks, implementation, testing, merge, documentation, learn). Opus for judgment phases (research, prd, ux_or_integration, review). Advisory recommendation — user can always override.

- Config: `skill-routing.json` → `model_tiering` + `phase_skills` objects with `.model_tier`
- Hub protocol: SKILL.md "Model Tiering Protocol" section
- Backward compat: if `phase_skills` value is an array, treat as v5.0 (no tier)

### Item 3: Batch Skill Invocation (TPU Weight-Stationary)

Load a skill template once, iterate N targets as data. Reduces dispatch overhead by N-1 for N-target operations.

- Config: `skill-routing.json` → `batch_dispatch` with `supported_operations` (audit, design_compliance, analytics_taxonomy_sync)
- Hub protocol: SKILL.md "Batch Dispatch Protocol" section
- Example: Audit 6 screens = 1 template load + 6 screen reads (7 ops vs 12 without batch)

### Item 4: Result Forwarding (UMA Zero-Copy)

Pass skill output inline in context to next skill instead of write-to-disk-read-back. Disk artifacts still written for audit trail.

- Config: `skill-routing.json` → `result_forwarding` with `eligible_chains` (ux→design, research→prd, audit→spec, spec→prompt, tasks→implement)
- Hub protocol: SKILL.md "Result Forwarding Protocol" section with optimized Phase 3 dispatch chain table
- Context flag: `_forwarded_from` signals receiving skill to skip disk read

### Item 6: Speculative Cache Pre-loading (Branch Prediction)

Pre-load likely-next-skill cache (compressed_view only) when current skill starts. Misprediction cost bounded at ~3K tokens (1.5%).

- Config: `skill-routing.json` → `speculative_preload` with `successor_map` (10 entries, confidence 0.85-0.98)
- Hub protocol: SKILL.md "Speculative Cache Pre-loading" section
- Metrics: prediction hit rate tracked in `change-log.json`, target 0.85

### Item 7: Systolic Chain Protocol (TPU Systolic Array)

Each skill in a defined chain receives ONLY upstream output + own L1 cache. No global shared-layer reads mid-execution. Hybrid isolation model:

- **Full isolation**: UX/design pipelines (`v2_refactor_pipeline`, `new_feature_ux_pipeline`). Shared layer is write-back only. Batch write-back after all stages complete.
- **Partial isolation**: Implementation pipeline. Dev/QA may read globals (`reads_global: true`). Per-stage write-back.

Config: `skill-routing.json` → `systolic_chains` with `defined_chains` (3 chains, 2-5 stages each). Hub protocol: SKILL.md "Systolic Chain Protocol" section.

### Item 8: Hybrid Task Dispatch (ARM big.LITTLE)

ARM big.LITTLE uses heterogeneous cores: P-cores for heavy threads, E-cores for light threads. OS scheduler classifies each thread and routes accordingly.

Hub equivalent: before dispatching ready tasks, a **task complexity classifier** scores each task against heavyweight indicators (files>5, new model/service, high token budget, cross-feature deps, requires judgment). Weighted scoring — threshold >= 4 → P-core (serial), < 4 → E-core (parallel).

- Config: `skill-routing.json` → `task_complexity_gate` with `classification` (weighted indicators), `lanes` (parallel/serial), `execution_order: "parallel_first_then_serial"`
- Hub protocol: SKILL.md "Task Complexity Classifier" section runs BEFORE "Parallel Task Dispatch"
- E-core lane: lightweight tasks batched, concurrent (max 5), model tier sonnet
- P-core lane: heavyweight tasks one-at-a-time, full context, model tier opus
- Composes with: model tiering (item 5), batch dispatch (item 3), result forwarding (item 4), systolic chains (item 7)

### Updated Dependency Map

```
CLAUDE.md (rules)
  └─→ SKILL.md (pm-workflow)
        ├─→ Model Tiering: phase → sonnet/opus recommendation
        ├─→ Batch Dispatch: multi-target → single template load
        ├─→ Result Forwarding: skill output → inline to next skill
        ├─→ Speculative Preload: current skill → pre-load next skill's cache
        ├─→ Systolic Chains: multi-skill pipeline → isolated execution
        ├─→ Task Complexity Gate: ready tasks → classify → E-core/P-core lanes
        ├─→ /ux, /design, /dev, /qa (spoke skills)
        ├─→ state.json, skill-routing.json, task-queue.json
        └─→ change-log.json → all skills notified
```

### Config Changes Summary

| File | Version | Key additions |
| --- | --- | --- |
| `skill-routing.json` | 3.0 → 4.1 | `model_tiering`, `batch_dispatch`, `result_forwarding`, `speculative_preload`, `systolic_chains`, `task_complexity_gate` |
| `framework-manifest.json` | 1.1 → 1.2 | 6 capability flags, 6 optimization entries |
| `pm-workflow/SKILL.md` | v5.0 → v5.1 | 6 new protocol sections (~200 lines) |

---

## 24. v5.2 — Dispatch Intelligence + Parallel Write Safety (2026-04-16)

### What Changed: v5.1 → v5.2

v5.1 completed the SoC-on-Software optimization suite. v5.2 adds the **dispatch safety layer** — making parallel agent coordination deterministic rather than luck-dependent. Two sub-projects shipped:

| Aspect | v5.1 | v5.2 |
| --- | --- | --- |
| **Agent dispatch model** | Direct dispatch, no pre-assessment | 3-stage pipeline: score complexity → probe capability → dispatch with budget |
| **Tool use control** | Unconstrained (3-68 tool uses, 23x variance) | Budgeted: haiku=10, sonnet=25, opus=50 (3.7x variance, -84%) |
| **Permission routing** | Discover failures at runtime | Permission table + hybrid probe (table lookup + micro-probe) |
| **Parallel write safety** | Luck-dependent (0 conflicts in v5.1 stress test) | Deterministic: snapshot/rollback + 3-tier mirror extraction + progressive markers |
| **Complexity assessment** | None | Static scoring (lightweight/standard/heavyweight) with validation flag |

### Sub-Project A: Dispatch Intelligence

3-stage pipeline that scores task complexity, probes agent capability, and dispatches with model routing + tool budgets.

- **Config:** `.claude/shared/dispatch-intelligence.json` — permission_table, model_routing (3 tiers), probe config, validation flags, budget_tuning
- **Protocol:** SKILL.md "Dispatch Intelligence Protocol" section (score → probe → dispatch)
- **Validation:** 5 dispatches, 80% complexity prediction accuracy, 48% avg tool reduction, 84% variance reduction
- **Key discovery:** settings.json permissions are controller-scoped only — subagents can't write to `.claude/` regardless of config. Reframed from "config fix" to "architectural constraint."

### Sub-Project B: Parallel Write Safety

2-layer safety system: snapshot/rollback + code region mirror pattern with progressive marker learning.

- **Config:** `.claude/shared/dispatch-intelligence.json` → `mirror_pattern` section (enabled, snapshot_dir, marker_prefix, 3-tier detection, auto_add_markers)
- **Protocol:** SKILL.md "Mirror Pattern" section (snapshot → extract → dispatch → reconstruct → rollback)
- **3-Tier Region Detection:**
  - Tier 1: `// BEGIN:agent-region:{name}` markers (fastest, deterministic)
  - Tier 2: `// MARK: - {Section}` conventions (fast, convention-based)
  - Tier 3: Full file (slow, first-time penalty — triggers marker addition)
- **Progressive learning:** Each Tier 3 dispatch that succeeds adds markers. Next dispatch uses Tier 1 automatically.

### New Files

| File | Purpose |
| --- | --- |
| `.claude/shared/dispatch-intelligence.json` | Central config for 3-stage dispatch pipeline + mirror pattern |

### Updated Files

| File | Changes |
| --- | --- |
| `.claude/shared/skill-routing.json` | v4.1 → v5.0, added dispatch_intelligence reference |
| `.claude/shared/framework-manifest.json` | v1.2 → v1.3, added dispatch_intelligence capability |
| `.claude/skills/pm-workflow/SKILL.md` | Added Dispatch Intelligence Protocol + Mirror Pattern protocol |
| `docs/architecture/subagent-preflight-probe-research.md` | Marked as implemented in v5.2 |
| `docs/architecture/parallel-code-write-safety-research.md` | Marked as implemented in v5.2B |

### Updated Dependency Map

```
CLAUDE.md (rules)
  └─→ SKILL.md (pm-workflow)
        ├─→ Dispatch Intelligence: score → probe → dispatch with budget
        │     ├─→ Permission table (known_writable, known_readonly)
        │     ├─→ Model routing (haiku/sonnet/opus per complexity tier)
        │     └─→ Tool budgets (10/25/50 per tier)
        ├─→ Mirror Pattern: snapshot → extract → dispatch → reconstruct → rollback
        │     ├─→ 3-tier region detection (markers → MARKs → full file)
        │     ├─→ Progressive marker learning (auto-add after Tier 3)
        │     └─→ Snapshot dir (.build/snapshots/)
        ├─→ Model Tiering, Batch Dispatch, Result Forwarding (v5.1)
        ├─→ Speculative Preload, Systolic Chains, Task Complexity Gate (v5.1)
        ├─→ /ux, /design, /dev, /qa (spoke skills)
        ├─→ state.json, skill-routing.json, task-queue.json
        └─→ change-log.json → all skills notified
```

### Config Changes Summary

| File | Version | Key additions |
| --- | --- | --- |
| `dispatch-intelligence.json` | 1.0 (NEW) | permission_table, model_routing, probe, validation, budget_tuning, mirror_pattern |
| `skill-routing.json` | 4.1 → 5.0 | dispatch_intelligence reference |
| `framework-manifest.json` | 1.2 → 1.3 | dispatch_intelligence capability flag |
| `pm-workflow/SKILL.md` | v5.1 → v5.2 | 2 new protocol sections (~50 lines) |

---

## 25. v7.1 — Integrity Cycle (2026-04-21)

**Problem:** the 2026-04-20 open-items audit surfaced a systemic "shipped but state.json unreconciled" drift pattern. Seven features (HADF, home-today-screen, nutrition-v2, onboarding-v2-auth-flow, settings-v2, user-profile-settings, parallel-write-safety-v5.2, ai-engine-architecture-adaptation) had their code shipped to main weeks before state.json caught up — in one case (HADF) 3-4 days, in another (home-today-screen) 11 days. The drift was invisible until an explicit audit ran because nothing in the framework pulled on that thread automatically.

**Solution:** a 72-hour recurring audit that checks every `.claude/features/*/state.json` for 7 known failure modes, produces a snapshot JSON, diffs vs the previous snapshot, and opens a GitHub issue on any regression.

**Seven failure-mode detectors:**

| Code | Trigger | Example |
|---|---|---|
| `PHASE_LIE` | Top-level `current_phase: complete` but sub-phases have `pending`/`in_progress`/`skipped` statuses | HADF 2026-04-16 → 2026-04-20 |
| `TASK_LIE` | Top-level terminal but tasks still `pending`/`in_progress` | home-today-screen T1-T17 all pending |
| `NO_CS_LINK` | Terminal phase but no `case_study`, `parent_case_study`, or `case_study_type` field | 9 pre-2026-04-13 backfill features |
| `V2_FILE_MISSING` | State declares `v2_file_path` but the file doesn't exist on disk | Any v2 refactor that rolled back |
| `PARTIAL_SHIP_TERMINAL` | `partial_ship: true` with a terminal phase | UI-015, UI-016 before remediation |
| `NO_STATE` / `INVALID_JSON` | Feature directory without parseable state.json | — |
| `NO_PHASE` | state.json missing `current_phase` / `phase` field entirely | — |

**Bypass markers** suppress false positives:

- `case_study_type: "pre_pm_workflow_backfill"` — legacy phase vocabulary (pre-PM-workflow, backfilled, shipped) is valid, not a lie
- `case_study_type: "roundup"` — feature is covered by a consolidation case study; sub-phase granularity not meaningful

**Infrastructure:**

| File | Role |
|---|---|
| `scripts/integrity-check.py` | 356-line audit script; produces snapshot JSON + diff |
| `.github/workflows/integrity-cycle.yml` | Cron `0 4 */3 * *` (every 3 days at 04:00 UTC) + `workflow_dispatch` |
| `.claude/integrity/snapshots/` | Historical ledger (one file per cycle, committed to main) |
| `.claude/integrity/README.md` | Design + schema + false-positive guide |
| Makefile: `integrity-check`, `integrity-snapshot` | Local invocation |

**Snapshot contents:**

Each snapshot records (1) feature summaries — phase, case-study link, task completion counts, SHA-256 of state.json — (2) case study inventory — path, size, first-commit date — and (3) all findings by severity. Cross-cycle diff computes added/removed/changed features, added/removed case studies, and the set delta on findings.

**Regression gates** that trigger an auto-opened issue:

- A feature present in the previous snapshot is absent now
- A case study present before is absent now
- A new finding (feature, code) pair appears that wasn't in the previous snapshot

**Empirical cadence rationale:** the 2026-04-20 audit caught 7 drifted features that had been in the lying state for 3-14 days. A 72-hour rhythm would have flagged most of them the morning after they shipped. A tighter cycle (24h) would spam the ledger with noise; a sparser cycle (weekly) would let the drift pile accumulate past the point where incremental fix is easy.

**Initial baseline (2026-04-20):** 40 features, 44 case studies, **0 findings** — snapshot at `.claude/integrity/snapshots/2026-04-20T20-45-00Z.json` after the Category A + B + C remediation batch landed.

**What v7.1 does NOT do:**

- Does not prevent drift from being introduced — it detects it after the fact
- Does not enforce state.json hygiene on feature creation — Phase 0 still owns that responsibility
- Does not verify correctness of *what* a feature claims to have shipped — only *consistency* of the state.json self-report

The integrity cycle is a **smoke detector**, not a fire-prevention system. It trades off false negatives (detects drift only 72h after it happens) for low false-positive rate (bypass markers keep the signal-to-noise ratio manageable).

**Why it earned a version bump:** v7.1 adds a recurring automated background process that wasn't in any prior version. This is structurally different from a one-time audit script; it changes the framework's steady-state from "drift until audit catches up" to "drift for at most 72h before detection." That's a capability change, not a point improvement on v7.0.

---

## 26. v4.X (Skill Layer) — UX/Design Preflight + Auto Figma Build + Pre-Merge UI Review (2026-05-06)

**Note on numbering:** This is a _skill layer_ upgrade (changes how `/ux` and `/design` participate in the PM workflow chain), not a _framework layer_ upgrade (which would be v7.X). The skill layer was last touched at v4.4; this resumes that line. Framework layer is independently at v7.8.

**Trigger.** During the import-training-plan resume (2026-05-06), a user-ordered pre-Phase-4 audit caught 4 P0 spec errors that would have hit "no such symbol" at compile time:

- `AppRadius.pill` — referenced by spec, doesn't exist (real pattern is `Capsule()` shape)
- `AppMotion.standardEase` — referenced by spec, doesn't exist (real container is `AppEasing`)
- `SettingsActionLabel` with custom badge slot — component is fixed-trailing, can't host inline badges
- Toast/snackbar component — referenced by spec, doesn't exist in the codebase

The audit cost ~20 minutes; the implied Phase 4 rework would have cost 2-4 hours. The user's request: "promote this audit pattern to a mechanical gate, AND combine it with a Figma MCP liveness check, AND add a pre-merge UI review pass."

The same session also surfaced that **Figma sync was being skipped on every UI feature**: Smart Reminders (2026-04-29) shipped code-first with Figma deferred manually for weeks; Push Notifications still pending; Import-Training-Plan was missed entirely until user flagged it post-Phase-5. `/design build` existed as a sub-command but was never auto-dispatched.

**What changed.**

### New sub-commands

- **`/ux preflight {feature}`** — pre-Phase-4 P0 gate. Verifies every token, component, and pattern named in `ux-spec.md` exists in the codebase. Writes audit + cache record. Spec NOT approvable with unresolved P0.
- **`/ux pre-merge-review {feature}`** — Phase 6 gate. Heuristic re-check of shipped code vs approved spec. Verdict PASS / PASS_WITH_NOTES / BLOCK. Sets `state.json.pre_merge_review.ux`.
- **`/design preflight {feature}`** — pre-Phase-4 P0 gate. Combines token/component/pattern existence + Figma MCP liveness (`whoami`) + Figma library accessibility (`get_metadata` on `0Ai7s3fCFqR5JXDW8JvgmD`) + Figma library node availability check + delegated `/design audit`. Writes `figma-bridge-status.json`.
- **`/design pre-merge-review {feature}`** — Phase 6 gate. `make ui-audit` P0=0 + `state.json.figma_node_ids` populated + PR description references node IDs + optional screenshot diff via Figma MCP. Sets `state.json.pre_merge_review.design`. BLOCK halts Phase 7.

### Changed sub-commands

- **`/design build {feature}`** — now auto-dispatched by `/pm-workflow` Phase 3.j. Writes captured Figma node IDs back to `state.json.figma_node_ids` AND adds row to `docs/design-system/figma-code-sync-status.md`. Falls back to prompt-only with `state.json.figma_build_status = "deferred_to_prompt"` when MCP unavailable.
- **`/ux prompt {feature}`** — output path moved from flat `docs/prompts/` → `docs/prompts/ux/`.
- **`/design prompt {feature}`** — output path moved from flat `docs/prompts/` → `docs/prompts/ui/`.

### Deprecated sub-commands

- **`/design ux-spec`** — `/ux spec` is canonical (kept as forwarder).
- **`/design figma`** — `/design build` is canonical (kept as forwarder).

### Folder reorganization

`docs/prompts/` split into:

- `docs/prompts/ux/` — auto-generated UX-build prompts (what-and-why)
- `docs/prompts/ui/` — auto-generated design-build prompts (how-it-looks)
- `docs/prompts/_legacy/` — hand-authored prompts pre-dating the auto-generation contract

### state.json schema additions

- `phases.ux_or_integration.preflight_passed` — set by `/ux preflight` + `/design preflight` aggregate
- `figma_node_ids` — `{ "screen_name": "node_id" }`, populated by `/design build`
- `figma_build_status` — `"completed"` | `"deferred_to_prompt"` | `null`
- `pre_merge_review.ux` — `"passed"` | `"passed_with_notes"` | `"blocked"` | `null`
- `pre_merge_review.design` — same shape

### Hub chain expansions

- **Phase 3 dispatch chain**: 7 steps → 11 steps (added 3e preflight, 3f preflight, 3j auto-build)
- **Phase 6 dispatch chain**: 4 steps → 5 steps (added 6b ux pre-merge, 6c design pre-merge); Phase 7 BLOCKED unless both pre-merge reviews pass

**Why it earned a version bump.** Previous skill-layer versions (v4.0-v4.4) were about HOW skills work internally (cache, learning lifecycle, eval coverage). v4.X is about what skills GATE — the difference between "the skill exists" and "the skill is mechanically required to pass before merge." It promotes 4 audit patterns from manual-on-request to mechanical gates, with state.json fields and dispatch-chain wiring to enforce them. That changes the framework's steady-state from "spec drift until someone notices" to "spec drift caught at Phase 3 entry, Figma drift caught at Phase 3 exit, code drift caught at Phase 6 entry."

**Tested on:** import-training-plan resume (2026-05-06). Phase 1 ship spans 6 commits + 1 PR; v4.X gates fired during the resume on Phase 3 (audit found 4 P0s), are scheduled to fire on Phase 6 once PR #234 reaches merge gate, and `/design build` is the next dispatch (Figma Option C build for the 3 new surfaces).

**Case study:** to be written post-merge as part of the import-training-plan Phase 8 closure narrative.

---

## 27. v4.X+CC — Cross-Repo Figma Code Connect Bridge (2026-05-09 → 2026-05-10)

**Trigger.** During the 2026-05-09 fitme-story public-enhancement rollup, T20 (Code Connect integration) shipped — but exposed a one-directional gap: `/design build` pushes screens INTO Figma, but the OTHER direction (Figma library frame → "show me the actual React/SwiftUI code") was unmapped. Same gap on the iOS side: 16+ shipped iOS features had captured `figma_node_ids` in their state.json but no `.figma.swift` mappings to render their code in Figma Dev Mode.

### Foundation layer

- **Web:** fitme-story PR #75 — `@figma/code-connect@1.4.4` devDep + `figma.config.json` + 4 new primitive components (`Button`, `Tag`, `CaseStudyCard`, `FrameworkVersionCard`) + 12 `.figma.tsx` mapping files covering 17 component node IDs against file `fsjHfFLAHELACZHku8Rfcl`. PR #80 followed up with parser fixes after first dry-run surfaced 3 issues: template-literal URLs rejected (must be string literal), `include` glob too narrow (didn't catch component sources), `figma.string()` props rejected for components without named text properties.
- **iOS:** FT2 PR #277 (chore feature `ios-code-connect` T1+T2+T3+T5) — `Figma.toml` at repo root + 5 `.figma.swift` mapping files covering 6 screen-level node IDs against file `0Ai7s3fCFqR5JXDW8JvgmD`. All node IDs sourced from existing shipped features' `state.json::figma_node_ids` blocks (no placeholders). Build-safety wrapper `#if canImport(Figma)` keeps Xcode green without the Swift package installed.

### 3-layer automation (chore feature `code-connect-automation`)

- **Layer A — scaffold scripts** (PRs #279 + fitme-story #77): `scripts/scaffold-figma-mapping.py` (FT2) + `scripts/scaffold-figma-mapping.mjs` (fitme-story) auto-generate `.figma.{swift,tsx}` template files from any feature's `state.json::figma_node_ids` block. Coalesces multi-state variants of the same View/component into one mapping file. `code_mapping` override block for keys that don't match the snake_case → PascalCase heuristic.
- **Layer B — `/design build` skill extension** (PR #280): after `figma_node_ids` is populated, the skill auto-invokes the scaffold script for the active repo. Closes the "manual mapping author per new UI feature" gap.
- **Layer C — CI publish workflows** (PRs #281 + #283 fix + fitme-story #79): `.github/workflows/figma-code-connect-publish.yml` in BOTH repos auto-runs `figma connect publish` on push to main when `*.figma.{swift,tsx}` or config changes. Web: ubuntu runner + npm CLI directly. iOS: macos-15 runner + SPM cache + npm CLI with `figma.config.json::swiftPackagePath` pointing at `.figma-cc-tools/Package.swift` SPM wrapper subdir (the npm CLI calls `swift run --package-path .figma-cc-tools figma-swift` as a subprocess to parse Swift files, since the npm parser doesn't natively support Swift). Gated on `FIGMA_ACCESS_TOKEN` repo secret; skips with clear log if missing. PR #281's first version used npm CLI ubuntu-only and fell back to html parser on Swift files (catastrophic 14817-file glob runaway when run against FT2); PR #283 replaced with the SPM wrapper approach.

### Two new mechanical gates (added 2026-05-10, PR #280)

- **`/design preflight` Step 3.5 — Code Connect write-access gate.** Verifies the publish path will work end-to-end. Token presence check (local env + `gh api` for repo secret in BOTH repos) + publish dry-run probe (catches missing `Code Connect Write` scope or `file_dev_resources:write`). Records to `figma-bridge-status.json::code_connect_access`. Auth-failure → P1 advisory; token absent everywhere → P2 advisory.
- **`/design pre-merge-review` Step 3.5 — Spec ↔ build parity check.** Verifies what was actually built matches what the spec said. Enumerates spec surfaces (parses `ux-spec.md` / `integration-spec.md`) and build surfaces (`state.json::figma_node_ids` + `.figma.{swift,tsx}` files), then cross-matches each spec surface (`complete` / `figma_only` / `mapping_only` / `missing`). BLOCK on `missing` or `mapping_only` (build incomplete). Records to `state.json.pre_merge_review.design_parity`.

### Hub chain expansions (over v4.X)

- **Phase 3 dispatch chain (`/design build` step):** appends auto-scaffold sub-bullet that invokes `scripts/scaffold-figma-mapping.{py,mjs}` after `figma_node_ids` capture
- **Phase 6 dispatch chain (`/design pre-merge-review`):** Step 3 (Figma node ID presence) extends with Step 3.5 (Spec ↔ build parity)
- **Phase 3 preflight (`/design preflight`):** Step 3 (library access) extends with Step 3.5 (Code Connect write-access gate)
- **Out-of-band:** CI publish workflows fire on merge-to-main without dispatch chain involvement

### Critical implementation discovery — Swift parser IPC

The `@figma/code-connect@1.4.4` npm package only ships React, HTML, and Storybook parsers natively. Swift parsing is delegated to a separate `figma-swift` binary built from the same GitHub repo via SPM. The npm CLI's `getSwiftParserDir` reads `swiftPackagePath` from `figma.config.json`, then invokes `swift run --package-path <dir> figma-swift` as a subprocess. The `figma-swift` binary itself is NOT a standalone CLI — it reads JSON requests from stdin and writes JSON responses to stdout. This split lets the npm CLI orchestrate auth + Figma API calls while delegating language-specific parsing to platform-native tooling.

This was discovered during the 2026-05-10 iOS dry-run when running `npx figma connect publish` from FT2 root fell back to the html parser (no `figma.config.json` existed at the time, only `Figma.toml` which is a different format the Swift CLI uses standalone). The fix in PR #283 was to:

1. Add `figma.config.json` at FT2 root with `parser: "swift"` + `swiftPackagePath: ".figma-cc-tools/Package.swift"`
2. Create `.figma-cc-tools/Package.swift` (SPM wrapper subdirectory) depending on `@figma/code-connect` Swift package
3. Add a placeholder `Sources/FigmaCodeConnectTools/Empty.swift` to satisfy SPM's "needs at least one target" rule

The subdirectory isolation matters because putting Package.swift at FT2 repo root would tempt SPM to scan FT2's Xcode app sources (which depend on Xcode-only modules) and fail to compile.

**Why it earned a sub-version bump (CC suffix).** v4.X (2026-05-06) closed the spec → code → Figma chain forward. v4.X+CC closes it BACKWARD: from Figma library back to source code. The combined chain now means: every spec'd surface is enforced into Figma at Phase 3 (`/design build` + node ID write-back), every Figma frame is enforced as a code mapping at Phase 3 (Layer B auto-scaffold), and every shipped UI feature has its mappings auto-published to Dev Mode at Phase 7 (Layer C CI). Manual steps per new UI feature: 2 → 0 once operator setup completes.

**Operator setup (one-time, both repos):** generate Figma Personal Access Token at <https://www.figma.com/settings> → Security → Personal access tokens. Required scopes: `file_content:read` + `file_dev_resources:read` + `file_dev_resources:write` (Code Connect mappings ARE dev resources in Figma's data model). `library_content:read` recommended for team-library design systems. Add as `FIGMA_ACCESS_TOKEN` repo secret in BOTH `Regevba/FitTracker2` and `Regevba/fitme-story`. Until set, both publish workflows skip cleanly. **Operator setup completed 2026-05-10T06:38–06:39Z.**

**Companion docs:**

- iOS operator runbook: [`docs/design-system/ios-code-connect-workflow.md`](../design-system/ios-code-connect-workflow.md)
- Web architecture: [`docs/design-system/fitme-story-design-architecture.md`](../design-system/fitme-story-design-architecture.md)
- Figma↔code matrix + Code Connect verification contract: [`docs/design-system/figma-code-sync-status.md`](../design-system/figma-code-sync-status.md)
- Public showcase: fitme-story `/pm-flow` page §`#code-connect` (PR #78)

**Case study:** to be written post-merge as part of the `code-connect-automation` Phase 8 closure (T5 = end-to-end test on next real new UI feature).

---

## Consolidated Timeline with Case Studies

Every version was tested through real feature work. The case study column links to the evidence.

| Version | Date | Key Innovation | Tested On | Case Study |
|---|---|---|---|---|
| v1.0 | 2026-04-02 | PM Skill created — 10-phase lifecycle | PM workflow itself | — |
| v1.2 | 2026-04-04 | Analytics instrumentation gate added | Google Analytics integration | — |
| v2.0 | 2026-04-07 | Hub-and-spoke: 11 skills, shared data layer, Phase 9 | Onboarding v2 (6 screens, PR #59) | [Onboarding showcase](../case-studies/pm-workflow-showcase-onboarding.md) |
| v3.0 | 2026-04-09 | External sync, parallel dispatch, v2 pipeline | Home v2 (723-line rewrite, PR #61) | [PM evolution v1→v4](../case-studies/pm-workflow-evolution-v1-to-v4.md) |
| v4.0 | 2026-04-10 | Reactive data mesh, adapters, validation gate, L1/L2/L3 cache | Training v2 (40% cache hit, PR #74) | [PM evolution v1→v4](../case-studies/pm-workflow-evolution-v1-to-v4.md) |
| v4.1 | 2026-04-10 | Skill Internal Lifecycle (Cache→Research→Execute→Learn) | Nutrition v2 (55%), Stats v2 (65%), Settings v2 (70%) | [PM evolution v1→v4](../case-studies/pm-workflow-evolution-v1-to-v4.md) |
| v4.2 | 2026-04-10 | Self-healing hub, Phase 0 health checks | Readiness v2, AI Engine v2, AI Rec UI | [PM evolution v1→v4](../case-studies/pm-workflow-evolution-v1-to-v4.md) |
| v4.3 | 2026-04-11 | Control room, case-study monitoring, maintenance programs | Cleanup program, dashboard | — |
| v4.4 | 2026-04-13 | Eval-driven development | Profile settings (9 evals) | — |
| v5.0 | 2026-04-14 | SoC: skill-on-demand + cache compression (54K tokens saved) | Framework itself | [SoC savings report](../architecture/soc-savings-report-v5.1.md) |
| v5.1 | 2026-04-14 | 8 SoC items: batch, tiering, forwarding, preload, systolic, complexity gate | AI Engine Architecture (13 tasks, PR #79) | [AI Engine case study](../case-studies/ai-engine-architecture-v5.1-case-study.md) |
| v5.2 | 2026-04-16 | Dispatch Intelligence + Parallel Write Safety: 3-stage dispatch pipeline, tool budgets, 3-tier mirror extraction, progressive markers | 4-feature continuation stress test | [v5.1→v5.2 evolution](../case-studies/v5.1-v5.2-framework-evolution-case-study.md), [Parallel Write Safety](../case-studies/parallel-write-safety-v5.2-case-study.md) |
| v6.0 | 2026-04-16 | Framework Measurement: deterministic phase timing, L1/L2/L3 cache hit tracking, eval coverage gates, monitoring auto-sync, token counting (79K tokens measured), CU v2 continuous factors, rolling baselines, serial/parallel velocity decomposition | — | [Framework Measurement v6.0](../case-studies/framework-measurement-v6-case-study.md) |
| v7.0 | 2026-04-16 | HADF Hardware-Aware Dispatch: 5-layer architecture (device detection → static profiles → cloud fingerprinting → dynamic adaptation → evolutionary learning), 17 chip profiles (6 vendors), 7 cloud hardware signatures, hardware_context in dispatch-intelligence.json, zero-regression confidence gate (0.4/0.7), composite optimizer (latency/cost/quality), reference implementations (Swift/Kotlin/Python) | — | [HADF case study](../case-studies/hadf-hardware-aware-dispatch-case-study.md) |
| v7.1 | 2026-04-21 | Integrity Cycle: 72-hour recurring audit of every `.claude/features/*/state.json` via GitHub Actions cron (`0 4 */3 * *`). 7 failure-mode detectors (PHASE_LIE, TASK_LIE, NO_CS_LINK, V2_FILE_MISSING, PARTIAL_SHIP_TERMINAL, NO_STATE, INVALID_JSON, NO_PHASE). Snapshot ledger at `.claude/integrity/snapshots/` committed per cycle. Diff vs previous snapshot emits regressions as auto-opened issues. Bypass markers suppress false positives for pre-PM-workflow backfills and roundup-consolidated features. | 2026-04-20 audit baseline: 40 features, 44 case studies, 0 findings after remediation of 7 "shipped but unreconciled" features. | [Integrity Cycle v7.1](../case-studies/integrity-cycle-v7.1-case-study.md) |
| v7.5 | 2026-04-24 | Data Integrity Framework: 8 cooperating defenses across write-time / cycle-time / readout-time. Write-time pre-commit hooks (`SCHEMA_DRIFT`, `PR_NUMBER_UNRESOLVED`). Cycle-time check codes extended (10 → 11). Runtime smoke gates (5 profiles incl. `sign_in_surface`). Contemporaneous logging pilot (5 active feature logs). Data-quality tiers convention (T1 Instrumented / T2 Declared / T3 Narrative). Documentation-debt + measurement-adoption ledgers. | 7/9 Gemini Tier items shipped; 2 partial/pilot; 1 external-blocked. Integrity baseline at ship: 0 findings across 40 features + 46 case studies. | [v7.5 case study](../case-studies/data-integrity-framework-v7.5-case-study.md) |
| v7.6 | 2026-04-25 | Mechanical Enforcement: 4 new write-time pre-commit check codes (`PHASE_TRANSITION_NO_LOG`, `PHASE_TRANSITION_NO_TIMING`, `BROKEN_PR_CITATION` write-time, `CASE_STUDY_MISSING_TIER_TAGS`); per-PR review bot (`pm-framework/pr-integrity` status check); weekly framework-status cron with regression watcher; append-only measurement-adoption history (dedup by date). Explicit Class B inventory documenting 5 mechanically unclosable gaps. | 7 Class B → Class A promotions; 5 Class B gaps remaining and individually justified. Pipeline regression test 8 → 15 assertions. v7.6 own session instrumented end-to-end with v6.0 protocol. | [v7.6 case study](../case-studies/mechanical-enforcement-v7-6-case-study.md), [unclosable-gaps](../case-studies/meta-analysis/unclosable-gaps.md) |
| v7.7 | 2026-04-27 | Validity Closure: 5 new check codes (4 gating: `CACHE_HITS_EMPTY_POST_V6`, `CU_V2_INVALID`, `STATE_NO_CASE_STUDY_LINK`, `CASE_STUDY_MISSING_FIELDS`; 1 advisory permanent: `TIER_TAG_LIKELY_INCORRECT` — kill criterion 2 fired at baseline FP rate 100% n=1); cycle-time codes 12 → 13; 25 gates + 1 advisory total; linkage 95.5% → 100% (gated); doc-debt 4–61% → 95.7–100% (gated forward); framework-health dashboard at `/control-room/framework`; cache_hits writer-path gap closed (Class B → Class A). | 1 Class B → Class A promotion (cache_hits writer-path); 4 Class B gaps remaining. Bulk-backfill of 32 case-study frontmatters; timing.phases backfill on 3 paused features. TIER_TAG_LIKELY_INCORRECT ships advisory permanent (kill-2 fired at baseline). | [v7.7 case study](../case-studies/framework-v7-7-validity-closure-case-study.md) |
| v7.8.5+S | 2026-05-14 | **Skills Review Execution.** Comprehensive skills sweep per [`skills-review-2026-05-13.md`](../skills/skills-review-2026-05-13.md). 14 of 17 review items shipped across 5 PRs (#350 / #352 / #353 / #355 / current). Skill count 11 → **12** (added `/brainstorm-pm` modeled on Anthropic `product-brainstorming` — 4 modes + 4 frameworks). Every SKILL.md now has trigger-rich description, frontmatter (last_updated / framework_version / status / adapters_used), observed-patterns preflight, anti-patterns. New `make skills-audit` mechanical gate (6 checks: E1–E4 + W1–W5). New `/pm-workflow roadmap` sub-cmd via Anthropic `references/` pattern (POC for deferred P1.0a pm-workflow split). New `/dev skills` (audit / trace / freshness). New `make preflight-fixture-test` regression harness for `/ux preflight` + `/design preflight` spec-side checks. 6 adapter.md gained reverse `consumed_by:` frontmatter for W5 bidirectional integrity. 5 ghost adapter refs removed. | Per-PR audit baseline at every step: 12/12 PASS, 0/0. Forced-failure smoke tests on W5 confirmed both directions fire. `make integrity-check` baseline maintained at 0 findings post-sweep. P1.0a (split pm-workflow 1688 → <500) deferred to v8.x. P1.2 (UCC panel) deferred to fitme-story; all data sources prepared. | [Skills review](../skills/skills-review-2026-05-13.md), [Skills CHANGELOG](../skills/CHANGELOG.md), [UCC data-flow contract](../skills/ucc-data-flow.md) |

### Cumulative Metrics Across Versions

| Feature | Version | Wall Time | Tasks | Files | Cache% | Improvement vs Prior |
|---|---|---|---|---|---|---|
| Onboarding v2 | v2.0 | 6.5h | 22 | 20 | 0% | Baseline |
| Home v2 | v3.0 | 36h* | 17 | 5 | 0% | Outlier (invented v2 convention) |
| Training v2 | v4.0 | 5h | 16 | 7 | 40% | Cache hit: +40pp |
| Nutrition v2 | v4.1 | 2h | 14 | 5 | 55% | 3.25x faster than Onboarding |
| Stats v2 | v4.1 | 1.5h | 10 | 4 | 65% | 4.3x faster |
| Settings v2 | v4.1 | 1h | 6 | 3 | 70% | 6.5x faster |
| Readiness v2 | v4.2 | 2.5h | 7 | 7 | 35% | — (different work type) |
| AI Engine v2 | v4.2 | 0.5h | 4 | 4 | 50% | — |
| AI Rec UI | v4.2 | 0.7h | 6 | 7 | 40% | — |
| **AI Engine Arch** | **v5.1** | **1.5h** | **13** | **17** | **45%** | **11.3 files/hr (best)** |
| **v5.1→v5.2 (parallel)** | **v5.2** | **~20 min** | **6** | **4** | **N/A** | **Dispatch intelligence + mirror pattern deployed** |
| **HADF Infrastructure** | **v7.0** | **~120 min** | **9** | **11** | **0%** | **First hardware-aware dispatch, zero-regression gate** |
