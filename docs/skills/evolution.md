# PM Hub Evolution — Architecture & Skills Documentation

> **Date:** 2026-04-10 (v4.1 update)
> **Status:** v4.1 — reactive data mesh + learning cache + integration adapters + skill internal lifecycle
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
                        │  Feature → 9 phases (full funnel)    │
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
| `BUILD_HOME` | `.build/xcode-home` | Xcode HOME override |
| `CLANG_MODULE_CACHE_PATH` | `.build/clang-cache` | Clang module cache |
| `DERIVED_DATA` | `.build/DerivedData` | Xcode build products |
| `TEST_DERIVED_DATA` | `.build/TestDerivedData` | Test products |
| `npm cache` | `.build/npm-cache` | npm package cache |

**Mac setup:** `defaults write com.apple.dt.Xcode IDECustomDerivedDataLocation "/Volumes/DevSSD/FitTracker2/.build/DerivedData"`

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
| `docs/project/pm-hub-evolution.md` | This document |

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
