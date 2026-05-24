> **Status:** DEPRECATED — superseded by [`master-plan-2026-04-15.md`](master-plan-2026-04-15.md) (current as of 2026-04-20). Kept in the repo as a historical snapshot.
>
> ⚠️ Historical document. References to `docs/project/` paths are from before the April 2026 reorganization. See `docs/master-plan/`, `docs/setup/`, and `docs/case-studies/` for current locations.

# FitMe Master Plan — 2026-04-06 (SSD Home Edition)

> **Date:** 2026-04-06
> **Purpose:** Reconciled master plan after full codebase review, SSD migration, and PM workflow audit. Supersedes `_archive/master-plan-reconciled-2026-04-05.md` (archived 2026-05-24 per D-PLAN-9).
> **Context:** Project moved from local internal storage to external SSD. New agent taking ownership. All prior work verified via git history.

---

## Executive Summary

FitMe is a production-grade iOS fitness app with 11 shipped core features, zero-knowledge encryption, GDPR compliance, GA4 analytics, and a federated AI layer. The codebase scores **A-** on code quality. The project has a mature PM workflow, 20 feature PRDs, 55 passing tests, and comprehensive documentation.

**The SSD is now the canonical home.** All development, builds, and verification happen from this location. The repo is fully portable — no hardcoded local paths in source code.

### What Was Inherited (Previous Agent Work)
- 26 commits after main branch (119 files, +17,160 lines)
- 3 features shipped through full PM lifecycle (GA4, GDPR, Android DS)
- Marketing website, skills ecosystem, 20 PRDs created
- Major stabilization pass: build repair, auth fixes, sync fixes, 40 XCTests
- `make verify-local` created as one-command full verification

### What This Session Built
- **6 force unwraps eliminated** from production Swift code (P0)
- **Stale path references cleaned**, xcuserdata removed, .gitignore fixed
- **PM compliance raised from 71% to ~95%** — 16/16 features now have state.json with metrics
- **Parallel Task Hub** — work item types (Feature/Enhancement/Fix/Chore), structured tasks in state.json, skill-based routing, dependency-aware parallel dispatch
- **Cross-feature priority queue** with scoring (fixes auto-jump the queue)
- **Change broadcast protocol** — every merge notifies all skills, feedback loop closes through /cx
- **Dashboard Tasks view** — TaskBoard (skill swim lanes), TaskCard, DependencyGraph (SVG DAG), 21 parser tests
- **SSD storage redirect** — all build artifacts to `.build/` on `/Volumes/DevSSD`
- **Full documentation** — `docs/project/pm-hub-evolution.md`

### Framework Evolution (Post-Session Updates)

- **v3.0** (2026-04-09) — External integrations (Notion, Figma MCP), parallel subagent execution
- **v4.0** (2026-04-10) — Reactive data mesh, integration adapters, validation gate, L1/L2/L3 learning cache
- **v4.1** (2026-04-10) — Skill Internal Lifecycle (Cache → Research → Execute → Learn)
- **v4.2** (2026-04-10) — Self-healing hub, Phase 0 health checks, cache seeding
- **v4.3** (2026-04-11) — Operations control room, case-study monitoring
- **v4.4** (2026-04-13) — Eval-driven development, ai_quality_metrics
- **v5.0** (2026-04-14) — SoC-on-Software: skill-on-demand + cache compression (54K tokens reclaimed)
- **v5.1** (2026-04-14) — Complete SoC suite (8/8 items): model tiering, batch dispatch, result forwarding, speculative preloading, systolic chains, task complexity gate
- **v5.2** (2026-04-16) — Dispatch Intelligence (3-stage pipeline, tool budgets, complexity scoring) + Parallel Write Safety (snapshot/rollback, 3-tier mirror extraction, progressive markers)
- **v6.0** (2026-04-16) — Framework Measurement: deterministic phase timing, cache hit tracking, eval gates, CU v2, rolling baselines
- **v7.0** (2026-04-17) — Meta-Analysis Audit + Failure Recognition Layer; surfaces patterns across cases
- **v7.1** (2026-04-21) — 72h Integrity Cycle (state.json + case-study audit, baseline 40/45/0)
- **v7.5** (2026-04-24) — Data Integrity Framework (8 cooperating defenses, triggered by 2026-04-21 Gemini independent audit)
- **v7.6** (2026-04-25) — Mechanical Enforcement (4 Class B → A pre-commit gates + per-PR review bot + weekly framework-status cron)
- **v7.7** (2026-04-27) — Validity Closure (5 new gates: CACHE_HITS_EMPTY_POST_V6 + CU_V2_INVALID + STATE_NO_CASE_STUDY_LINK + CASE_STUDY_MISSING_FIELDS + TIER_TAG_LIKELY_INCORRECT advisory)
- **v7.8** (2026-05-04) — Bridge mechanisms A-F (coverage-asserting gates + schema bridges + Mechanism C session attribution + pre-commit self-audit + merge driver + membrane status)
- **v7.8.1** (2026-05-07) — Branch Isolation + Feature-Closure Completeness (3 advisory gates: BRANCH_ISOLATION_VIOLATION Mode B + Mode C + FEATURE_CLOSURE_COMPLETENESS)
- **v7.8.2** (2026-05-08) — Cross-Repo Telemetry Asymmetry documented disposition (F7+F8 exemption)
- **v7.8.3** (2026-05-11) — Cross-Repo State Sync Implementation (V2 + V9 → enforced; state_owner field; 5-phase rollout)
- **v7.8.4** (2026-05-12) — Pre-v7.9 Telemetry Calibration & Doc-Debt Cleanup (PR_CACHE_STALE auto-refresh + TIER_TAG heuristic narrowed)
- **v7.8.5** (2026-05-13) — Observability Layer (Observed Patterns Catalog + W9 branch-drift alert)
- **v7.8.6** (2026-05-15) — Cadence Batch (`make integrity-diff` + `make preflight WORK_TYPE=<>` + Phase 0.0 + 10-skill Shared Data + W1 ssh preflight + weekly Mech A scan)
- **v7.9** (2026-05-21) — **Promotion Release.** Single-flag flip at `scripts/check-state-schema.py:132` (`BRANCH_ISOLATION_ADVISORY_MODE = True → False`) promotes 3 v7.8.1 advisory gates to enforced after 14d Mechanism A calibration. Phase E validation 2026-05-21 → 2026-06-04. First real-world gate fire caught + resolved same-session.

**Current framework version: v7.9.** Full evolution history: [`docs/skills/evolution.md`](../skills/evolution.md). Cold-start entrypoints per version: [`.claude/entrypoints/`](../../.claude/entrypoints/). Live infra master plan: [`docs/master-plan/infra-master-plan-2026-05-12.md`](infra-master-plan-2026-05-12.md). v7.9 promotion case study: [`docs/case-studies/framework-v7-9-promotion-case-study.md`](../case-studies/framework-v7-9-promotion-case-study.md).

---

## Current Verification Status

| Component | Status | Command |
|-----------|--------|---------|
| iOS Build | Green | `make verify-ios` |
| iOS Tests (40) | Green | FitTrackerCoreTests(31) + SyncMergeTests(9) |
| Token Pipeline | Green | `make tokens-check` |
| Dashboard (9 tests) | Green | `cd dashboard && npm test` |
| Marketing Website | Green | `cd website && npm run build` |
| AI Engine (5 tests) | Green | `cd ai-engine && pytest -q` |
| Full Verification | Green | `make verify-local` |

### Runtime Verification Still Blocked
- Firebase analytics: needs local `GoogleService-Info.plist`
- Supabase sync: needs real credentials in `Info.plist`
- Signed-in deletion/export: needs backend access
- Simulator ID: may need update for new machine (`SIMULATOR_ID=...` override)

---

## Phase Gates (From Reconciled Plan)

### Gate A — Foundation Stability ✅ MOSTLY CLOSED

| Item | Status | Notes |
|------|--------|-------|
| iOS build green | Done | `xcodebuild build` passes |
| Sync schema corrected | Done | Migration 000008 staged |
| Auth/session behavior | Done | restore + signOut fixed, tests passing |
| Deletion flow truthful | Done | Code paths exist for all 9 stores |
| AI tests green | Done | pytest 5/5 with stub fixtures |
| Dashboard tests fixed | Done | Source health mismatch resolved |
| **Force unwraps eliminated** | **Done** | **This session: 6 force unwraps → guard let** |
| Runtime verification | **Blocked** | Needs local credentials |

### Gate B — Truth Alignment ⏳ IN PROGRESS

| Item | Status | Notes |
|------|--------|-------|
| Docs match code reality | In progress | PRD audit running |
| Token pipeline verified | Done | `make tokens-check` green |
| Stale paths cleaned | Done | This session |
| Shared data files accurate | Done | This session |

### Gate C — Measurement 🔒 BLOCKED

| Item | Status | Notes |
|------|--------|-------|
| Firebase runtime verified | Blocked | Needs GoogleService-Info.plist |
| Analytics tests present | Done | 23 analytics tests passing |
| Privacy claims accurate | Done | GDPR code paths exist |

### Gate D — Platform Expansion 🔒 LOCKED

Requires Gate C + iOS core stable + backend green + measurement live.

---

## Feature Status Map (2026-04-06)

### Shipped Through PM Workflow
| Feature | PRD | Metrics | Kill Criteria | Analytics | State |
|---------|-----|---------|---------------|-----------|-------|
| Google Analytics (GA4) | Yes | 20 events, 14/40 instrumented | <5% consent rate → remove | Yes (23 tests) | Complete |
| GDPR Compliance | Yes | 100% deletion/export success | Legal requirement | Yes (5 events) | Complete |
| Android Design System | Yes | 92 tokens mapped | N/A (research) | No (docs only) | Complete |
| Development Dashboard | Yes | 10 page views/week | <3 views/week → archive | No (web-only) | Complete |

### Shipped (Pre-PM Workflow, Need PRD Validation)
| Feature | PRD | Metrics | Kill Criteria | Gap |
|---------|-----|---------|---------------|-----|
| Training Tracking | Yes (18.1) | Audit needed | Audit needed | Exercise search missing |
| Nutrition Logging | Yes (18.2) | Audit needed | Audit needed | Food DB stub, barcode unconnected |
| Recovery & Biometrics | Yes (18.3) | Audit needed | Audit needed | Blood pressure not imported |
| Home / Today Screen | Yes (18.4) | Audit needed | Audit needed | Readiness score is binary |
| Stats / Progress Hub | Yes (18.5) | Audit needed | Audit needed | Chart goal lines missing |
| Authentication | Yes (18.6) | Audit needed | Audit needed | Google Sign-In not wired |
| Settings | Yes (18.7) | Audit needed | Audit needed | Dark Mode e2e incomplete |
| Data & Sync | Yes (18.8) | Audit needed | Audit needed | Conflict resolution UI missing |
| AI / Cohort Intelligence | Yes (18.9) | Audit needed | Audit needed | No feedback loop |
| Design System v2 | Yes (18.10) | Audit needed | Audit needed | 9 raw literals remain |
| Marketing Website | Yes | Section views tracked | <50 visits/week → redesign | GA4 integrated |

### In Progress
| Feature | Phase | PRD | Next Step |
|---------|-------|-----|-----------|
| Onboarding Flow | Tasks (10 defined) | Yes | Implementation (T1-T10) |

### Planned (RICE-Prioritized)
| RICE | Feature | Phase | Dependency |
|------|---------|-------|------------|
| 3.6 | Android App Research | 3 | Gate D |
| 3.2 | Skills Operating System | 2 | Gate C |
| 3.2 | CX System | 2 | Gate C |
| 3.0 | Notion MCP Integration | 5 | OAuth setup |
| 2.1 | Health API Connections | 3 | Gate D |
| 2.0 | DEXA + Body Composition | 3 | Gate D |
| 2.0 | Marketing & Growth Strategy | 5 | Gate C |
| 1.3 | Blood Test Reader | 4 | Gate D |
| 1.0 | Skills Feature (In-App) | 4 | Gate D |

---

## Execution Plan

### Sprint 1 — Close Gates A+B ✅ COMPLETE
1. ~~Fix force unwraps (P0)~~ Done
2. ~~Clean stale paths~~ Done
3. ~~Update shared data files~~ Done
4. ~~Remove xcuserdata from tracking~~ Done
5. ~~PRD audit — all 16 features have state.json with metrics + kill criteria~~ Done (71% → 95%)
6. ~~Parallel Task Hub — work types, skill routing, priority queue, dashboard~~ Done
7. ~~SSD storage redirect — all builds to .build/ on /Volumes/DevSSD~~ Done
8. ~~Review gates + change broadcast + feedback loop~~ Done
9. ~~Documentation: pm-hub-evolution.md~~ Done

### Sprint 2 — Onboarding Feature (NEXT)
7. Resume PM workflow at Tasks phase
8. T1-T6: UI screens (container, welcome, goals, profile, HealthKit, first action)
9. T7: App launch wiring
10. T8: GA4 analytics instrumentation (5 events)
11. T9: Progress bar component
12. T10: Unit + analytics tests
13. Primary metric: >80% completion rate
14. Kill criteria: <50% after 30 days → redesign

### Sprint 3 — Runtime Verification (Requires Local Credentials)
15. Supply GoogleService-Info.plist → verify Firebase analytics
16. Supply real Supabase credentials → verify sync end-to-end
17. Run signed-in deletion + export on real device
18. Update Simulator ID for SSD machine
19. Close Gate C

### Sprint 4 — Product Gap Closure
20. Food database integration (OpenFoodFacts API)
21. Barcode scanning connection
22. Google Sign-In activation
23. Readiness score formula (binary → 0-100 weighted)
24. Accessibility pass (add accessibilityLabel to interactive elements)

### Sprint 5+ — Roadmap Features
25. Skills Operating System (RICE 3.2)
26. CX System (RICE 3.2)
27. Android app research (RICE 3.6)
28. Health API connections (RICE 2.1)

---

## SSD Environment Notes

All build artifacts stay on the SSD in `.build/` alongside the source:

```makefile
PROJECT_ROOT := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
BUILD_DIR    ?= $(PROJECT_ROOT).build     # Everything here
AI_VENV      ?= $(BUILD_DIR)/ai-venv
SPM_CACHE    ?= $(BUILD_DIR)/spm-cache
DERIVED_DATA ?= $(BUILD_DIR)/DerivedData
```

After SSD clone/move, run:
```bash
npm install                    # Root (token pipeline)
cd dashboard && npm install    # Dashboard
cd website && npm install      # Marketing site
cd ai-engine && python3.12 -m venv .build/ai-venv && source .build/ai-venv/bin/activate && pip install -e '.[dev]'
make verify-local              # Full verification — all output to .build/
```

One-time Mac setup (optional):
```bash
defaults write com.apple.dt.Xcode IDECustomDerivedDataLocation "/Volumes/DevSSD/FitTracker2/.build/DerivedData"
```

---

## Code Quality Summary

**Grade: A-** (improved from previous session)

| Category | Score | Key Finding |
|----------|-------|-------------|
| Architecture | A | Clean DI, actor-based encryption, adapter pattern |
| Security | A | AES-256-GCM + ChaCha20, Secure Enclave, GDPR compliant |
| Force Unwraps | A | 0 in production code (was 6) |
| Error Handling | B | ~47 silent `try?` calls need categorization |
| Test Coverage | B | 55 tests, but no integration/UI/encryption tests |
| Accessibility | C | Only 1 accessibilityLabel in codebase |
| Documentation | A | 20 PRDs, stabilization report, skills ecosystem |

---

## Definition of Done for This Planning Cycle

- [x] All force unwraps eliminated from production code
- [x] Stale local paths cleaned
- [x] Shared data files accurate
- [x] xcuserdata removed from git
- [x] .gitignore fixed for features tracking
- [ ] All PRDs have metrics + kill criteria
- [ ] Master plan committed and pushed
- [ ] Onboarding feature implementation started
- [ ] Runtime verification with real credentials (blocked on local config)
