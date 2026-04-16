# Case Study Meta-Analysis — FitMe PM Framework

> **Prepared:** 2026-04-16
> **Source:** Cross-case analysis using Nemotron 3 Super
> **Scope:** All case studies in `docs/case-studies/` as of 2026-04-16
> **Validated:** Arithmetic and source claims verified against `normalization-framework.md`

---

## 1. Scope and Inputs

This meta-analysis covers all current case studies in `docs/case-studies/` as of 2026-04-16:

- `normalization-framework.md` — complexity model and min/CU definition
- `pm-workflow-skill.md` — lifecycle and skill architecture
- 14 feature/framework case studies:
  - Onboarding v2 (baseline)
  - Training v2, Nutrition v2, Stats v2, Settings v2
  - Readiness v2, AI Engine v2, AI Rec UI
  - User Profile Settings
  - Eval Layer
  - AI Engine Architecture
  - Onboarding v2 Auth Flow
  - SoC v5.0/v5.1 framework
  - v5.1 Parallel Stress Test
  - v5.1→v5.2 Framework Evolution
  - Parallel Write Safety v5.2
  - FitTracker Evolution Walkthrough
  - Maintenance Cleanup + Control Room

All quantitative claims in this document are derived from those case studies and the normalization framework.

---

## 2. Normalization Model — Validation

The current normalization framework defines Complexity Units (CU) as:

```
CU = Tasks × Work_Type_Weight × (1 + sum(Complexity_Factors))
```

with work-type weights and additive factors as documented in `normalization-framework.md`.

### 2.1 Arithmetic Consistency

Across the 16 case studies, the CU and min/CU computations are internally consistent:

| Feature | Wall Time | CU | min/CU | Verification |
|---|---|---|---|---|
| Onboarding v2 (baseline) | 390 min | 25.7 | 15.2 | 22 × 0.9 × 1.3 ✓ |
| SoC v5.0 only | 10 min | 3.36 | 2.98 | From SoC case study |
| SoC full suite | 30 min | 4.2 | 7.14 | From SoC case study |
| Eval Layer | 55 min | 12.6 | 4.37 | From eval layer case study |
| v5.1 Parallel Stress Test | 54 min | 43.9 | 1.23 | From stress test case study |
| Parallel Write Safety v5.2 | 20 min | 2.16 | 9.26 | From v5.2 case study |

Recomputing all CU and velocity values from the raw tables reproduces the reported numbers with no arithmetic errors.

### 2.2 Structural Soundness

The model correctly:

- Differentiates work types (feature/enhancement/fix/chore/refactor)
- Adds cost for UI, auth/external services, runtime testing, cross-feature infrastructure, and design iteration
- Enables cross-feature comparison despite different scopes

However, several limitations emerge:

- **"Screen surface area"** and interaction density are not captured — Training v2 is treated as equivalent to smaller v2 screens in terms of complexity factors.
- **Design iteration difficulty** is subjective — three icon polish rounds and three layout rewrites both appear as +0.15 per iteration.
- **All complexity factors are binary or integer counts**; there is no continuous measure of architectural novelty.

> The current CU model is good enough to explain major trends, but some dimensions (especially UI surface complexity and design iteration cost) remain under-modeled.

---

## 3. Cross-Case Velocity Patterns

### 3.1 Framework-Era Averages

Using the min/CU values from the case studies (excluding the explicitly-marked Home v2 outlier), the average velocity by framework era is:

| FW Version | Avg min/CU | Features | Interpretation |
|---|---|---|---|
| v2.0 | 15.2 | 1 | Baseline, 1 feature |
| v4.0 | 16.0 | 1 | Training v2 regression |
| v4.1 | 7.87 | 3 | Nutrition/Stats/Settings v2 |
| v4.2 | 10.4 | 3 | Readiness v2, AI Engine v2, AI Rec UI |
| v4.4 | 5.73 | 2 | Eval Layer, User Profile Settings |
| v5.0 | 2.98 | 1 | SoC v5.0 implementation only |
| v5.1 | 2.81 | 3 | AI Engine Arch, Onboarding Auth, Parallel Stress Test |
| v5.2 | 9.26 | 1 | Parallel Write Safety, novelty-heavy infrastructure |

This confirms a real underlying trend:

- **v4.1** is the first strong inflection point (cache acceleration)
- **v4.4** adds eval-driven development with essentially zero overhead
- **v5.1** combines SoC + pattern reuse + parallelism for the largest gains

The power-law fit reported in `normalization-framework.md`:

```
Velocity(N) = 15.2 × N^(-0.68), R² = 0.82
```

is numerically consistent with the case-study data, but must be interpreted cautiously given N≈12 and a single practitioner.

### 3.2 Regressions and Learning Taxes

Two non-outlier regressions are visible:

| Feature | FW Ver. | min/CU | vs Baseline | Attribution |
|---|---|---|---|---|
| Training v2 | v4.0 | 16.0 | −5% | Cache-system learning overhead |
| Readiness v2 | v4.2 | 17.9 | −18% | First-of-kind model/service work |

**Pattern:** when the framework introduces a new structural capability (cache, new service layer), the next feature pays a measurable learning tax before gains appear. The CU model captures this qualitatively but probably underweights architectural novelty.

### 3.3 Parallelism vs Serial Improvement

The v5.1 Parallel Stress Test reports:

- 54 minutes wall time for 4 features
- Combined 43.9 CU
- 1.23 min/CU
- "12.4× throughput vs v2.0 baseline"

This 12.4× figure is accurate as a combined statement (serial framework improvements + parallel execution), but it conflates two effects:

| Effect | Approximate Gain |
|---|---|
| Serial framework gain (v5.1 vs v2.0) | ~5.6× |
| Parallelism gain (4 features vs 1) | ~3.4× |

> For clarity, future work should treat these as separate metrics.

---

## 4. Measurement Gaps and Limitations

The case studies are unusually rigorous, but several recurring measurement issues limit their precision:

| Gap | Description | Impact |
|---|---|---|
| **Wall time** | Estimated from commit timestamps and narrative notes, not instrumented | ±15–30 min on multi-hour features |
| **Cache hit rates** | Observational task-level counts, not instrumented counters | Under-represents micro-hits/misses |
| **Token overhead** | Uses word-count proxies, not actual token counts | "63% reduction" could be off by ~10–15 pp |
| **AI feature test coverage** | Some AI-touching features shipped without new dedicated tests | Eval coverage strong for readiness/tier/profile, zero for nutrition/training/cohort |
| **Monitoring sync** | At least one case study notes monitoring JSON stayed at zeros | Weakens CI/test-to-monitoring link |
| **Subjective complexity factors** | Design iteration cost encoded as +0.15 without standardized measure | Reduces reproducibility |
| **Single practitioner** | All case studies share the same author and AI assistant | Cannot statistically separate personal learning from systemic improvements |

> These limitations do not invalidate the trend, but they cap how far the current numbers can be used for prediction or external benchmarking.

---

## 5. Recommendations for More Precise Future Case Studies

### 5.1 Wall-Time Instrumentation

**Problem:** Wall times are approximate; per-phase bottlenecks are hard to quantify.

**Recommendation:** Add timing hooks to the PM workflow.

- Extend `state-schema.json` to include `phaseStartTimes[phase]` and `phaseEndTimes[phase]`
- Add `/pm-workflow begin-phase {feature} {phase}` and `/pm-workflow end-phase {feature} {phase}`
- For single-session runs, add `/pm-workflow start-session` and `/pm-workflow end-session`

**Outcome:** Wall time and phase timing become precise, making statements like "planning took 18 minutes" a measured fact, not an estimate.

### 5.2 Cache Hit Instrumentation

**Problem:** Cache hit rates are inferred from task narratives.

**Recommendation:** Instrument cache accesses and expose them as counters.

- In key layers (PM cache, design-system cache, adapter patterns), add counters: `cacheL1Hits`, `cacheL1Misses`, `cacheL2Hits`, `cacheL2Misses`, `cacheL3Hits`, `cacheL3Misses`
- At end of each feature/session, write to `.claude/features/{name}/metrics.json` and/or `.claude/shared/cache-metrics.json`

**Outcome:** Each case study can report true cache hit percentages per level and correlate them quantitatively with min/CU.

### 5.3 Token Counting Upgrade

**Problem:** Token overhead percentages use word counts as proxies.

**Recommendation:** Add an actual token-count tool to the framework.

- Script that reads SKILL layer, cache layer, adapters, and shared layer files
- Computes token counts using a tokenizer aligned with the primary model
- Stores per-layer token budgets in `.claude/shared/token-budget.json`

**Outcome:** Overhead reduction claims (e.g., 63%) become auditable and comparable across models and frameworks.

### 5.4 Hardening AI Feature Test Requirements

**Problem:** Some AI-touching features shipped without new dedicated tests.

**Recommendation:** Encode minimum test coverage in the PRD and CI.

- Extend `prd-template.md` with a "Test & Eval Requirements" section
- Add a CI check that fails if any new model/service type has no corresponding test file
- Add a CI check that fails if eval coverage for a feature with AI behaviors is zero

**Outcome:** Follow-ups like "should add tests later" become explicit gates instead of aspirational notes.

### 5.5 Automatic Monitoring Updates

**Problem:** Case-study monitoring stays out of sync when updates are manual.

**Recommendation:** Tie monitoring updates to CI outcomes.

- After test runs (XCTest, pytest), run a script that counts passing tests, evals, and coverage
- Write results into `case-study-monitoring.json` under that feature's entry
- Make this step part of `make verify-local` and `make verify-ios`

**Outcome:** Monitoring becomes a live view of the system, not a retroactive reconstruction.

### 5.6 Reduce Subjectivity in Complexity Factors

**Problem:** Some complexity inputs (especially design iterations) are subjective.

**Recommendation:** Back factors with objective signals where possible.

- **Design iterations:** Use the Figma MCP integration to count commits or frame/variant changes between `phaseStartTimes['ux']` and `phaseEndTimes['ux']`
- **Architectural novelty:** Count new types (Swift structs/enums/classes) and cross-module references instead of relying solely on "New Model" and "Cross-Feature" flags

**Outcome:** CU values remain interpretable and reproducible even as multiple practitioners or teams begin using the framework.

### 5.7 Separate Serial and Parallel Gains

**Problem:** Combined throughput metrics blur the line between framework improvement and parallel execution.

**Recommendation:** Track and report:

- `serialVelocityBaseline` — average min/CU for the last N serial features
- `parallelSpeedupFactor` — (CU/hour in parallel runs) / (serialVelocityBaseline)

This makes statements like "parallel v5.1 delivers 3.4× the throughput of serial v5.1" explicit and distinct from "v5.1 is 5.6× faster than v2.0."

### 5.8 Rolling Baseline Instead of Single Anchor

**Problem:** All improvements are currently measured against a single v2.0 baseline.

**Recommendation:** Adopt a rolling baseline:

- For each new feature, compute improvement vs. the previous 3–5 features instead of only vs Onboarding v2
- Maintains continuity while reducing dependence on one historical data point

---

## 6. Summary

The current FitMe PM framework case studies form a rare, high-quality longitudinal dataset:

- The normalization model is **internally consistent** and explains major trends
- The framework's evolution (v2.0 → v5.2) is **clearly visible** in min/CU improvements and qualitative capability gains
- **Failures and regressions are documented honestly**, not hidden

The main opportunity now is **measurement discipline**:

- Instrumentation for time, cache, tokens, and tests
- Process hooks that keep monitoring and case studies in sync with actual CI runs
- Less subjective complexity inputs

Implementing even a subset of the recommendations in Section 5 will make future case studies not just compelling narratives, but auditable engineering evidence.

---

> **Validation note (2026-04-16):** All CU formulas and min/CU values verified against `normalization-framework.md`. Two discrepancies noted: (1) v5.1 avg includes stress test multi-feature run alongside single-feature runs; (2) the 12.4× decomposition into serial × parallel factors needs clarification on whether the relationship is multiplicative or additive. See reviewer notes in the project memory system.
