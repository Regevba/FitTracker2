# Case Study: AI Engine Architecture Adaptation — v5.1

**Date written:** 2026-04-15

> **Core question:** How did framework v5.1 affect development speed and quality for a cross-cutting architectural enhancement?

---

## 1. Summary Card

| Field | Value |
|-------|-------|
| **Feature** | AI Engine Architecture Adaptation |
| **Framework Version** | v5.1 |
| **Work Type** | Enhancement (parent: adaptive-intelligence) |
| **Complexity** | Files created: 8, Files modified: 9, Tasks: 13 |
| **Wall Time** | ~1.5h (single session, research through merge) |
| **Tests** | 197 (all pass, 0 regressions) |
| **Analytics Events** | 2 new + 3 new params |
| **Cache Hit Rate** | ~45% (GoalProfile patterns, adapter contract from PM-flow L2 cache) |
| **Eval Pass Rate** | N/A (no feature-specific evals — reuses existing AI tier evals) |
| **Headline** | "1.5h at v5.1 for 13-task architectural enhancement — 4 phases shipped in single session" |

---

## 2. Experiment Design

### Independent Variable
- **Framework version** v5.1 (model tiering, batch dispatch, result forwarding, systolic chains, task complexity gate)

### Dependent Variables
| DV | Unit | How Measured |
|----|------|-------------|
| Wall time | hours | Session timing |
| Planning velocity | phases/hour | 4 phases (research→PRD→tasks→implement) in ~1.5h = 2.67 phases/hour |
| Implementation velocity | files/hour | 17 files changed in ~0.75h = 22.7 files/hour |
| Task completion rate | tasks/hour | 13 tasks in ~0.75h = 17.3 tasks/hour |
| Cache hit rate | % | ~45% — adapter patterns, validation gate, goal-mapping from prior work |
| Defect escape rate | count | 3 (NutritionPlan naming, access control, duplicate param) — all caught in build |
| Test density | tests/event | 197 tests / 2 events = 98.5 (inherited test suite) |

### Complexity Proxy
- 8 new files + 9 modified = 17 total files touched
- Enhancement work type (4-phase lifecycle)
- Has UI: yes (confidence badge + feedback buttons)
- Cross-cutting: touches AI engine, UI, analytics, persistence

### Controls
- Same PM workflow (10-phase lifecycle, Enhancement track)
- Same developer (Regev + Claude Code)
- Same codebase (FitMe iOS app)
- Same design system (AppTheme tokens)

### Confounders
- Feature builds heavily on PM-flow patterns (adapters, validation gate, cache) — high pattern reuse reduces novelty overhead
- Single-session execution with full context — no context reload penalty
- Goal-aware intelligence added mid-PRD (user-driven scope expansion)

---

## 3. Raw Data

### Phase Timing

| Phase | Start | End | Duration | Notes |
|-------|-------|-----|----------|-------|
| 0. Research | Session start | +15min | 15min | Advanced existing thin research.md to 5-layer architecture proposal with Swift code sketches |
| 1. PRD | +15min | +30min | 15min | Full PRD with 10 requirements, metrics, kill criteria. Goal-aware intelligence added by user. |
| 2. Tasks | +30min | +40min | 10min | 13 tasks with dependency graph, parallel opportunities identified |
| 3. UX/Design | — | — | Skipped | Enhancement work type — UI scoped within tasks |
| 4. Implement | +40min | +75min | 35min | All 13 tasks, 17 files, 986 insertions. 3 build errors caught and fixed. |
| 5. Test | +75min | +85min | 10min | 197 tests pass, 1 test needed goalMode param fix |
| 6. Review | — | +85min | Included | PR #79 created |
| 7. Merge | +85min | +90min | 5min | Merged to main, pushed |
| **Total** | | | **~90min** | Single session, research through merge |

### Task Completion

| Task | Type | Complexity | Status | Cache Hit? |
|------|------|-----------|--------|------------|
| T1: AIInputAdapter protocol | dev | lightweight | done | Yes — adapter pattern from PM-flow integrations |
| T2: ProfileAdapter | dev | lightweight | done | Partial — extracted from existing code |
| T3: HealthKitAdapter | dev | lightweight | done | Partial — extracted from existing code |
| T4: TrainingAdapter | dev | lightweight | done | Partial — extracted from existing code |
| T5: NutritionAdapter | dev | lightweight | done | Partial — extracted from existing code |
| T6: Refactor AISnapshotBuilder | dev | heavyweight | done | Yes — registry pattern from skill-routing.json |
| T7: GoalProfile + MetricDriver | dev | lightweight | done | Yes — weight pattern from ReadinessEngine |
| T8: ValidatedRecommendation | dev | heavyweight | done | Yes — validation gate from PM-flow |
| T9: Goal-aware localFallback | dev | heavyweight | done | Partial — existing fallback logic as base |
| T10: Confidence badge UI | dev+design | heavyweight | done | Yes — badge pattern from design system |
| T11: FoundationModel prompt | dev | lightweight | done | No — novel prompt engineering |
| T12: RecommendationMemory | dev | heavyweight | done | Partial — UserDefaults encryption pattern exists |
| T13: Feedback UI + analytics | dev+analytics | heavyweight | done | Yes — analytics event pattern well-cached |

### Cache Hits During Execution

| Cache Entry | Level | What It Provided | Time Saved (est.) |
|-------------|-------|-----------------|-------------------|
| PM-flow adapter pattern | L2 | Protocol + concrete adapter structure, contribute(to:) interface | ~10min |
| Validation gate (GREEN/ORANGE/RED) | L2 | Confidence scoring model, threshold calibration approach | ~8min |
| Analytics event naming convention | L1 | snake_case, screen-prefix rule, param structure | ~5min |
| ReadinessEngine goal-aware weights | L1 | ComponentWeights pattern for NutritionGoalMode | ~5min |
| AIInsightCard existing structure | L1 | HStack layout, FitMeLogoLoader, analytics hooks | ~3min |
| Design system badge pattern | L1 | Capsule badge with AppColor.Surface.secondary | ~2min |

---

## 4. Analysis (3 Levels)

### Level 1 — Micro (Per-Skill Performance)

| Skill | Invocations | Cache Hits | Time | Key Output |
|-------|------------|------------|------|------------|
| /pm-workflow | 4 (research→PRD→tasks→impl) | 2 | 90min total | Full lifecycle orchestration |
| /dev | 1 (implementation) | 3 | 35min | 17 files, 986 insertions |
| /qa | 1 (testing) | 0 | 10min | 197 tests verified, 1 test fixed |
| /analytics | 1 (analytics spec in PRD) | 1 | 5min | 2 events + 3 params defined |
| /design | 0 (inline in T10) | 1 | 5min | Confidence badge + feedback buttons |

### Level 2 — Meso (Cross-Skill Interaction)

| Dimension | This Feature | Comparison |
|-----------|-------------|------------|
| Handoff mechanism | Result forwarding (v5.1) — research findings flowed inline to PRD, PRD to tasks, tasks to implementation | v4.x wrote to disk between phases |
| Parallel execution | T2-T5 could have been parallel (E-core) but ran sequentially due to single-session context | v5.1 task_complexity_gate identified 5 lightweight + 6 heavyweight correctly |
| Data sharing | GoalProfile reads NutritionGoalMode from shared UserPreferences — no new shared layer files needed | Clean integration with existing data |
| Error detection | 3 build errors caught immediately (NutritionPlan→NutritionGoalPlan, access control, duplicate param) | All fixed in <2min each |

### Level 3 — Macro (Framework Performance)

| Metric | This Feature (v5.1) | Best Prior (v4.2) | Worst Prior (v2.0) | Delta vs Best |
|--------|---------------------|-------------------|--------------------| ------|
| Wall time | 1.5h | 0.5h (AI Engine v2) | 36h (Home v2) | +1h (larger scope) |
| Files/hour | 11.3 | 8.0 (AI Rec UI) | 0.6 (Home v2) | +41% |
| Tasks/hour | 8.7 | 8.6 (AI Rec UI) | 3.4 (Onboarding v2) | +1% (comparable) |
| Tests created | 0 (existing suite) | 25 (Readiness v2) | 0 (AI Engine v2) | N/A |
| Cache hit rate | 45% | 70% (Settings v2) | 0% (Home v2) | -25% (architectural novelty) |
| Defect escapes | 0 | 0 | 0 | Same |

---

## 5. Normalized Velocity

> Methodology: `docs/case-studies/normalization-framework.md`
> CU = Tasks × Work_Type_Weight × (1 + sum(Complexity_Factors))

**This Feature:**
- Tasks: 13, Work type: enhancement (0.8)
- Factors: UI (+0.3) + New Model (+0.2) + Cross-Feature (+0.2) = +0.7
- **CU = 13 × 0.8 × 1.7 = 17.7**
- Wall time: 90 min
- **min/CU = 5.1**
- **Rank: 2nd best** (of 11 features at time of writing)
- **vs Baseline (v2.0): +66% faster**

### Cross-Version Comparison (Normalized)

| Feature | Version | Type | Wall Time | CU | min/CU | vs Baseline |
|---|---|---|---|---|---|---|
| Onboarding v2 | v2.0 | refactor | 6.5h | 25.7 | 15.2 | Baseline |
| Home v2 | v3.0 | refactor | 36h* | 23.0 | 93.9* | Outlier |
| Training v2 | v4.0 | refactor | 5h | 18.7 | 16.0 | -5% |
| Nutrition v2 | v4.1 | refactor | 2h | 16.4 | 7.3 | +52% |
| Stats v2 | v4.1 | refactor | 1.5h | 11.7 | 7.7 | +49% |
| Settings v2 | v4.1 | refactor | 1h | 7.0 | 8.6 | +43% |
| Readiness v2 | v4.2 | enhancement | 2.5h | 8.4 | 17.9 | -18% |
| AI Engine v2 | v4.2 | enhancement | 0.5h | 3.8 | 7.9 | +48% |
| AI Rec UI | v4.2 | feature | 0.7h | 7.8 | 5.4 | +64% |
| **AI Engine Arch** | **v5.1** | **enhancement** | **1.5h** | **17.7** | **5.1** | **+66%** |

*Home v2 excluded from trend — outlier that invented the v2 convention.

---

## 6. Success & Failure Cases

### What Worked

| # | Success | Evidence |
|---|---------|----------|
| 1 | PM-flow pattern reuse dramatically accelerated architecture design | Adapter protocol, validation gate, learning cache all derived from PM-flow equivalents. Research phase was 15min instead of multi-hour because the patterns were already proven in the framework. |
| 2 | Goal-aware intelligence added mid-PRD without disruption | User proposed goal-aware metric prioritization during PRD review. Added as requirements #7-8 and GoalProfile model within the same session — no rework needed. |
| 3 | Single-session end-to-end execution | Research → PRD → Tasks → Implementation → Test → Merge in ~90min. v5.1 result forwarding kept context flowing without disk round-trips. |
| 4 | Zero test regressions across 197 tests | Adapter refactor was behavior-preserving. Only 1 test needed updating (new init parameter). |
| 5 | 3 build errors caught and fixed in <5min total | NutritionPlan naming mismatch, access control (public vs internal), duplicate analytics param — all trivial fixes. |

### What Broke Down

| # | Failure | Evidence | Impact |
|---|---------|----------|--------|
| 1 | NutritionPlan vs NutritionGoalPlan naming | Used wrong type name in NutritionAdapter — caught on first build | <2min fix, low impact |
| 2 | Access control mismatch | AIOrchestrator is `public` but ValidatedRecommendation is `internal` — common Swift module boundary issue | <2min fix |
| 3 | Duplicate analytics param | `source` already existed in AnalyticsParam — added it again | <1min fix |
| 4 | No new unit tests written | Relied on existing 197-test suite for regression. GoalProfile, ValidatedRecommendation, RecommendationMemory deserve dedicated tests. | Technical debt — should add in follow-up |

---

## 7. Framework Improvement Signals

### Cache Entries to Promote
- **Adapter protocol pattern** — should stay at L2. Used by both PM-flow integrations and now AI engine. Cross-domain applicability confirmed.
- **Validation gate scoring model** — should stay at L2. Applied to both external data (PM-flow) and AI recommendations. Generalized confidence scoring.

### Anti-Patterns Discovered
- **Type naming assumption** — assumed `NutritionPlan` existed when the actual type was `NutritionGoalPlan`. The adapter extraction should have been done by reading the existing type first, not from memory of the research doc.

### Recommended Framework Changes for Next Version
- **Test generation as part of implementation tasks** — Each task that creates a new model or service should include a companion test task. Currently, tests were deferred entirely.

---

## 8. Methodology Notes

### Data Sources
- `state.json` — phase timestamps, task completion
- `git log` — commit counts, file changes, PR #79
- Session timing — single continuous session
- Build output — error detection and resolution timing

### Limitations
- Single practitioner (Regev + Claude Code)
- Single session — no context reload penalty (favorable condition)
- Enhancement work type reuses existing parent feature patterns (favorable condition)
- No new unit tests created — test density metric is inherited, not earned

### Key Finding

**PM-flow pattern reuse is the dominant accelerator for architectural work.** The AI engine adaptation was designed in 15 minutes because every layer (adapters, validation gate, learning cache, feedback loop) had a proven analog in the PM-flow ecosystem. The framework isn't just a development workflow — it's a pattern library that compounds across features.

This is the first case where framework patterns were applied *to the product's own AI system*, not just to the development process. The line between "how we build" and "what we build" blurred — the same architectural principles that make the PM framework self-improving are now making the AI engine self-improving.
