# Eval Layer + Framework v4.4 — Design Spec

**Date:** 2026-04-13
**Goal:** Add a two-layer eval system that tests AI output quality (not just code correctness) and advances the PM framework to v4.4 with Phase 5 (Eval) in the Skill Internal Lifecycle.

**Architecture:** Layer 1 (deterministic evals in XCTest, CI-runnable) catches formula regressions and copy quality violations. Layer 2 (runtime quality metrics via analytics) feeds case-study-monitoring.json for longitudinal analysis. Together they close the loop: product specs become evals, evals produce data, data improves the framework.

---

## Layer 1: Deterministic Evals (XCTest)

### File 1: `FitTrackerTests/EvalTests/ReadinessFormulaEvals.swift`

Golden input/output test cases that pin expected scores for known biometric profiles. Each eval defines: realistic input, expected score range, expected recommendation, and why.

| # | Eval Name | Input Profile | Expected Score | Expected Rec | What It Validates |
|---|-----------|--------------|---------------|-------------|------------------|
| 1 | Healthy athlete baseline | HRV 55ms, RHR 58, 8h sleep (17.5% deep, 22.5% REM), steady ACWR ~1.0, no flags | 75-85 | .fullIntensity | All components healthy → high score |
| 2 | Sleep deprived | HRV 50, RHR 65, 4h sleep, no deep/REM | 35-50 | .lightOnly | Sleep component drags overall below moderate |
| 3 | Overreaching | HRV 40, RHR 72 (+7 above baseline), ACWR 1.6 | 25-40 | .lightOnly or .restDay | RHR deviation + high ACWR both suppress |
| 4 | Full recovery day | HRV 70 (+40% above baseline), RHR 55, 9h sleep, no training 3 days | 85-100 | .pushHard | All green = top score |
| 5 | Fat loss goal shift | Same as eval 1 but goalMode .fatLoss vs .maintain | Delta 3-8 pts | — | Sleep weight increase is measurable |
| 6 | Layer 0 cold start | Only HRV 45, only sleep 7h, zero logs | 40-70 | Any (not nil) | Doesn't crash, produces actionable output, confidence .low |
| 7 | Contradictory signals | HRV excellent + sleep terrible | 45-65 | .moderate | Balanced output, not extreme either direction |

### File 2: `FitTrackerTests/EvalTests/AIOutputQualityEvals.swift`

Heuristic checks on AI-generated text and signal mapping quality. No LLM judge — pure deterministic rules.

| # | Eval Name | What It Checks | Quality Bar |
|---|-----------|---------------|-------------|
| 1 | Signal coverage 100% | Every signal key returned by `AIRecommendation.localFallback()` for all 4 segments maps to non-default copy in `humanReadableSignal()` | 0 unmapped signals |
| 2 | No raw keys in UI | All `humanReadableSignal()` outputs contain zero underscores | 0 violations |
| 3 | Copy length bounds | Every mapped signal produces 15-80 character copy | 0 violations |
| 4 | Tone matches readiness | Score <30 → at least one of (rest, recover, lighter, easy) in rec copy. Score >85 → at least one of (great, push, strong, go) | Word presence verified |
| 5 | Confidence badge text | .low → "Low", .medium → "Medium", .high → "High" (exact rawValue) | Exact match |
| 6 | Recommendation copy completeness | Every `TrainingRecommendation` case produces non-empty title + subtitle from `HomeRecommendationProvider.recommendation(readinessResult:)` | 0 empty strings |
| 7 | Warning text quality | Every possible warning string in ReadinessEngine is a complete phrase (>20 chars, contains a noun + recommendation) | 0 violations |

### File 3: `FitTrackerTests/EvalTests/AITierBehaviorEvals.swift`

Tests the hybrid AI system's tier routing, confidence gating, and fallback behavior.

| # | Eval Name | What It Checks | Quality Bar |
|---|-----------|---------------|-------------|
| 1 | Local fallback always works | `AIRecommendation.localFallback(for:snapshot:)` returns non-nil for every segment with minimal snapshot | 100% non-nil for all 4 segments |
| 2 | Confidence gate boundary | Foundation model confidence 0.39 → base used. 0.41 → adapted used. | Exact boundary at 0.4 |
| 3 | All segments produce signals | For each of 4 segments, localFallback produces >=1 signal string | 0 empty signal arrays |
| 4 | Empty snapshot graceful | `LocalUserSnapshot()` all nil → still produces fallback for all 4 segments | No crash, fallback present |
| 5 | Readiness feeds snapshot | When ReadinessResult available, `LocalUserSnapshot.readinessScore` populated | Field non-nil |
| 6 | Stale snapshot warning | Empty snapshot closure (C4 scenario) → DEBUG print fires | Warning logged |

---

## Layer 2: Runtime Quality Metrics

### New block in `case-study-monitoring.json` schema

Added to each case study entry alongside existing `process_metrics` and `quality_metrics`:

```json
"ai_quality_metrics": {
  "tier_distribution": {
    "local_fallback_pct": 0,
    "cloud_cohort_pct": 0,
    "foundation_model_pct": 0
  },
  "cache_hit_rate_pct": 0,
  "signal_coverage_pct": 0,
  "recommendation_adherence_rate": 0,
  "readiness_score_distribution": {
    "push_hard_pct": 0,
    "full_intensity_pct": 0,
    "moderate_pct": 0,
    "light_only_pct": 0,
    "rest_day_pct": 0
  },
  "confidence_distribution": {
    "high_pct": 0,
    "medium_pct": 0,
    "low_pct": 0
  },
  "eval_pass_rate": 0,
  "eval_total": 0,
  "eval_failed": []
}
```

Populated from existing analytics events:
- `home_readiness_score_computed` → score distribution, confidence distribution, layer/component count
- `home_ai_insight_shown` → tier distribution (source_tier param)
- `home_ai_feedback_submitted` → adherence signal (positive = followed, negative = overrode)

---

## Framework v4.4: Eval-Driven Development

### What Changes: v4.3 → v4.4

| Aspect | v4.3 | v4.4 |
|--------|------|------|
| Skill lifecycle phases | 5 (Health → Cache → Research → Execute → Learn) | 6 (+ Eval after Learn) |
| Output quality testing | None — only code correctness | Deterministic evals (CI) + runtime quality metrics |
| Case study data | process_metrics + quality_metrics | + ai_quality_metrics (tier, coverage, adherence, score distribution) |
| Eval definitions | Not part of the workflow | Created during Phase 2 (Tasks), run during Phase 5 (Test), analyzed during Phase 9 (Learn) |
| Framework self-improvement | Cache learns patterns | Cache learns patterns + evals detect quality degradation |

### The 6-Phase Skill Internal Lifecycle (v4.4)

```
┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐
│ 0.HEALTH │─▶│ 1. CACHE │─▶│2.RESEARCH│─▶│3.EXECUTE │─▶│ 4. LEARN │─▶│ 5. EVAL  │
│  CHECK   │  │  CHECK   │  │(if miss) │  │          │  │          │  │(if defs) │
└──────────┘  └──────────┘  └──────────┘  └──────────┘  └──────────┘  └──────────┘
```

Phase 5 (Eval) — runs after Phase 4 (Learn) when eval definitions exist:
1. Check if the feature/task has eval definitions (golden cases, quality heuristics)
2. Run deterministic evals against the output just produced
3. Record pass/fail counts + quality scores in case-study-monitoring.json
4. If any eval fails, add to case study's `failure_cases` with evidence
5. Failed evals become anti-patterns in L1 cache (feeds back to Phase 4)

### PM Workflow Integration

| PM Phase | Eval Role |
|----------|-----------|
| Phase 2 (Tasks) | Define eval cases as part of task breakdown — "what does good output look like?" |
| Phase 5 (Test) | Run deterministic evals alongside unit tests. Eval pass rate recorded. |
| Phase 6 (Review) | Eval results included in review — reviewer sees quality scores, not just code diff |
| Phase 9 (Learn) | Analyze eval trends across features. What quality bars are consistently met/missed? |

---

## Files to Create

| File | Purpose |
|------|---------|
| `FitTrackerTests/EvalTests/ReadinessFormulaEvals.swift` | 7 golden input/output test cases |
| `FitTrackerTests/EvalTests/AIOutputQualityEvals.swift` | 7 heuristic quality checks |
| `FitTrackerTests/EvalTests/AITierBehaviorEvals.swift` | 6 hybrid system behavior tests |

## Files to Modify

| File | Change |
|------|--------|
| `docs/skills/evolution.md` | Add §21: v4.4 Eval-Driven Development |
| `docs/skills/README.md` | v4.4 evolution bullet, rule 12 (eval phase) |
| `.claude/cache/_index.json` | Phase 5 in lifecycle |
| `.claude/shared/framework-manifest.json` | `framework_version: "4.4"` |
| `.claude/shared/framework-health.json` | Version reference |
| `.claude/shared/case-study-monitoring.json` | `ai_quality_metrics` in schema + existing cases |
| `FitTracker.xcodeproj/project.pbxproj` | EvalTests directory + 3 test files in test target |

## Out of Scope

- LLM-as-judge (future — periodic audit, not CI)
- Runtime eval execution in the iOS app (evals run in test target only)
- Automated eval case generation from PRDs
- Dashboard visualization of eval results (future control room enhancement)
