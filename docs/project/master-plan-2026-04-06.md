# FitMe Master Plan — 2026-04-06 (SSD Home Edition)

> **Date:** 2026-04-06
> **Purpose:** Reconciled master plan after full codebase review, SSD migration, and PM workflow audit. Supersedes `master-plan-reconciled-2026-04-05.md`.
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

### What This Session Fixed
- **6 force unwraps eliminated** from production Swift code (P0)
- **Stale path reference** `/Users/regevbarak/Desktop/...` replaced with repo URL
- **xcuserdata** removed from git tracking (already in .gitignore)
- **.gitignore** fixed to properly track `.claude/features/`
- **3 shared data files** updated to match codebase reality (test-coverage, design-system, health-status)

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

### Sprint 1 — Close Gates A+B (Current)
1. ~~Fix force unwraps (P0)~~ Done
2. ~~Clean stale paths~~ Done
3. ~~Update shared data files~~ Done
4. ~~Remove xcuserdata from tracking~~ Done
5. Complete PRD audit — verify all 11 pre-PM features have metrics + kill criteria
6. Update any PRDs missing required fields

### Sprint 2 — Onboarding Feature
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

The project is fully portable. Key paths are all overridable:

```makefile
DEVELOPER_DIR ?= /Applications/Xcode.app/Contents/Developer
SIMULATOR_ID  ?= <override-with-new-machine-sim-id>
AI_VENV       ?= /tmp/FitTracker2-ai-venv
SPM_CACHE     ?= /tmp/FitTrackerDerivedData-review/SourcePackages
```

After SSD clone/move, run:
```bash
npm install                    # Root (token pipeline)
cd dashboard && npm install    # Dashboard
cd website && npm install      # Marketing site
cd ai-engine && python3.12 -m venv /tmp/FitTracker2-ai-venv && source /tmp/FitTracker2-ai-venv/bin/activate && pip install -e '.[dev]'
make verify-local              # Full verification
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
