# Case Study: Eval Layer + Framework v4.4 — Eval-Driven Development

**Date written:** 2026-04-15

> **Core question:** Can a formal eval layer — golden I/O tests and heuristic quality checks — be added to the PM framework without disrupting the existing skill lifecycle, and does it measurably improve AI output quality visibility?

## 1. Summary Card

| Field | Value |
|---|---|
| Feature | Eval Layer (3 → 4 test files, 20 → 29 eval cases) |
| Framework version | v4.3 → v4.4 |
| Work type | Feature |
| Complexity | Cross-feature infrastructure + new model schema |
| Wall time | ~45 min (spec 15 min + implementation 25 min + framework docs 5 min) |
| Tests added | 29 eval tests across 4 files |
| Analytics events | 0 (infrastructure, not user-facing) |
| Cache hit rate | N/A (first-of-kind, no prior cache) |
| Eval pass rate | 100% (29/29 green) |
| Headline | Introduced a 6-phase skill lifecycle (adding Phase 5: Eval) and 29 eval cases that gate AI output quality for readiness scoring, recommendation copy, tier behavior, and user profile integrity |

## 2. Experiment Design

**Independent variable:** Framework version (v4.3 without eval layer → v4.4 with eval layer).

| Dependent variable | Measurement |
|---|---|
| Eval coverage | Number of AI behaviors under eval (segments × scenarios) |
| Quality signal visibility | Whether ai_quality_metrics schema captures eval results per case study |
| Framework phase count | 5-phase → 6-phase lifecycle |
| Test density | Eval tests per AI-touching feature |
| Defect escape rate | AI quality bugs caught by evals vs discovered in production |

**Complexity proxy:** 4 test files × 29 eval cases × 3 AI subsystems (readiness, recommendations, tier behavior) + 1 new schema (ai_quality_metrics) + framework doc updates.

**Controls:** Existing XCTest infrastructure, unchanged AIOrchestrator code, stable ReadinessEngine formula.

**Confounders:** ProfileEvals.swift (9 tests) was added during the User Profile Settings feature, not during the original eval layer session. The planned scope was 20 evals across 3 files; the final count is 29 across 4 files.

## 3. Raw Data

### Phase Timing

| Phase | Start | End | Duration | Notes |
|---|---|---|---|---|
| Research | — | — | 0 min | No research phase — eval patterns derived from AI engine v2 case study findings |
| PRD | — | — | 0 min | Spec served as lightweight PRD |
| Spec | 2026-04-13 18:00 | 2026-04-13 18:15 | ~15 min | `2026-04-13-eval-layer-design.md` — 20 eval cases defined, 3 files, 2-layer design |
| Implementation | 2026-04-13 18:15 | 2026-04-13 18:40 | ~25 min | 3 eval files written (ReadinessFormula, AIOutputQuality, AITierBehavior) |
| Framework docs | 2026-04-13 18:40 | 2026-04-13 18:45 | ~5 min | evolution.md §21, manifest bump, lifecycle update |
| ProfileEvals (later) | 2026-04-14 | 2026-04-14 | ~10 min | Added during User Profile Settings feature work |

### Task Completion

| Task | Type | Status | Cache Hit? |
|---|---|---|---|
| Write eval layer spec | Spec | Done | No |
| ReadinessFormulaEvals.swift (7 golden I/O) | Test | Done | No |
| AIOutputQualityEvals.swift (7 heuristic) | Test | Done | No |
| AITierBehaviorEvals.swift (6 tier behavior) | Test | Done | No |
| Add ai_quality_metrics schema to monitoring | Schema | Done | No |
| Update evolution.md with v4.4 section | Docs | Done | No |
| Bump framework-manifest.json to v4.4 | Config | Done | No |
| Update project.pbxproj for EvalTests group | Build | Done | No |
| ProfileEvals.swift (9 profile quality) | Test | Done | Partial (reused eval patterns from L1) |

### Eval Results (All Passing)

| File | Count | Category | Key Assertions |
|---|---|---|---|
| ReadinessFormulaEvals | 7 | Golden I/O | Score ranges, band assignments, goal-aware shifts, cold start, contradictory signals |
| AIOutputQualityEvals | 7 | Heuristic | Signal coverage, no raw keys in UI, copy length bounds, tone matching, confidence badges |
| AITierBehaviorEvals | 6 | Tier behavior | Local fallback, confidence gate boundary (0.4), empty snapshot graceful, stale snapshot handling |
| ProfileEvals | 9 | Golden I/O + heuristic | Minimal/full profile, goal mutation, enum completeness, analytics prefix, backward compat |

## 4. Analysis

### 4.1 Micro (Per-Skill)

**Spec quality:** The 2-layer design (Layer 1: XCTest evals, Layer 2: monitoring schema) kept the scope contained. The spec predicted 20 evals across 3 files; implementation landed 20 in the original session, with 9 more added organically during the next feature. The spec's file structure and naming convention were followed exactly.

**Eval pattern reuse:** Each eval file follows the same `testEval_` prefix convention, uses `XCTAssert` with descriptive messages, and tests a clear behavioral contract (input → expected range/property). This pattern was reusable enough that ProfileEvals.swift was written in ~10 min by following the established structure.

### 4.2 Meso (Cross-Skill)

**Framework integration:** The 5-phase → 6-phase lifecycle change (adding Phase 5: Eval between Implementation and Review) was clean because the existing phases didn't depend on a fixed count. The `ai_quality_metrics` schema in `case-study-monitoring.json` gives every future case study a structured place to record eval results, tier distribution, and confidence distribution — data that was previously untracked.

**PM workflow impact:** Eval definitions now happen at Phase 2 (Tasks), execution at Phase 5 (Test), and analysis at Phase 9 (Learn). This creates a closed loop: define what good looks like → build → verify against definition → learn from results.

### 4.3 Macro (Framework)

**Quality gate value:** Before v4.4, AI output quality was verified by "build passes, tests pass" — but those tests checked code correctness, not output quality. The eval layer adds behavioral assertions: "does the readiness score fall in a sane range for this input?" and "does the recommendation copy use push language when readiness is high?" These are the kinds of bugs that escape unit tests but frustrate users.

**Coverage gap:** The eval layer covers readiness (7), AI output (7), tier behavior (6), and profile (9) — but nutrition recommendations, training plan suggestions, and cohort intelligence outputs have zero eval coverage. These are the next candidates.

## 5. Normalized Velocity

**CU calculation:**

```
Tasks = 9 (8 original + 1 ProfileEvals)
Work_Type_Weight = 1.0 (feature)
Complexity_Factors = New Model (+0.2) + Cross-Feature (+0.2) = 0.4
CU = 9 × 1.0 × (1 + 0.4) = 12.6
```

**Wall time:** ~55 min (45 min original + 10 min ProfileEvals)

**Velocity:** 55 / 12.6 = **4.37 min/CU**

| Version | Feature | min/CU | Δ vs baseline |
|---|---|---|---|
| v2.0 | Onboarding v2 (baseline) | 15.2 | — |
| v4.3 → v4.4 | **Eval Layer** | **4.37** | **+71%** |
| v5.1 | AI Engine Architecture | 5.1 | +66% |
| v5.1 | Onboarding Auth (best) | 2.1 | +86% |

## 6. Success & Failure Cases

### Success

1. **Eval patterns are reusable across features.** ProfileEvals.swift was written in ~10 min by copying the established `testEval_` convention. The pattern scales.
2. **The ai_quality_metrics schema captures data no prior schema could.** Tier distribution, confidence distribution, eval pass rate, and cache hit rate are now first-class fields in case study monitoring.
3. **29 evals catch behavioral regressions that unit tests miss.** The confidence gate boundary test (`0.39 fails, 0.41 passes, exact 0.4 passes`) is the kind of edge case that would otherwise ship broken.

### Failure

1. **Case study monitoring entry was never updated post-implementation.** The process_metrics still show all zeros. The snapshot was never captured. This case study doc is the retroactive fix.
2. **Framework doc updates lagged.** The v4.4 section in evolution.md exists, but the manifest was quickly superseded by v5.0 and v5.1, making v4.4 a brief waypoint rather than a stable version.

## 7. Framework Improvement Signals

- **Eval template needed.** Each eval file was written from scratch. A `testEval_` template or generator would reduce per-file setup time from ~8 min to ~3 min.
- **Auto-capture monitoring snapshots.** The monitoring entry should be auto-updated when eval tests pass in CI, not manually. The fact that process_metrics stayed at zero for days proves manual tracking doesn't scale.
- **Coverage radar.** A per-subsystem eval coverage map (readiness: 7, recommendations: 7, tiers: 6, profile: 9, nutrition: 0, training: 0, cohort: 0) would make gaps visible in the dashboard.

## 8. Methodology Notes

- Wall time is estimated from commit timestamps and spec creation time. No stopwatch was used.
- ProfileEvals.swift is attributed to this case study because it follows the eval layer pattern, even though it was written during the User Profile Settings session.
- The CU formula uses Feature weight (1.0) because the eval layer introduces new test infrastructure and a new schema, even though it doesn't add user-facing functionality.
- The monitoring entry status should be updated from `in_progress` to `complete` alongside this doc.
