# PM Hub Evolution — Architecture & Skills Documentation

> **Date:** 2026-04-06
> **Status:** Implemented and pushed to `claude/review-code-changes-E7RH7`
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

## 15. Migration Notes

- **Backwards compatible:** State.json files without `tasks[]` or `work_type` fields work as `type: "feature"` with feature-level tracking only
- **New features should use `work_type`** — selected during `/pm-workflow` initialization
- **Existing features can be upgraded** by adding a `tasks[]` array to their state.json
- **Dashboard auto-detects** — shows task views only for features with structured tasks
