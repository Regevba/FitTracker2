# Case Study Normalization Framework

> **Purpose:** Ensure all PM workflow case studies are comparable regardless of feature complexity. Raw metrics (wall time, files, tasks) are meaningless without normalization because a 22-task UI refactor with auth is fundamentally different from a 4-task backend enhancement.
>
> **Updated:** 2026-04-15
> **Applies to:** All past and future case studies retroactively.

---

## 1. Complexity Score Formula

Every feature receives a **Complexity Unit (CU)** score:

```
CU = Tasks × Work_Type_Weight × (1 + sum(Complexity_Factors))
```

### Work Type Weights

| Work Type | Weight | Rationale |
|---|---|---|
| Feature | 1.0 | Full 10-phase lifecycle, maximum ceremony |
| Enhancement | 0.8 | 4-phase lifecycle, parent PRD exists |
| Fix | 0.5 | 2-phase lifecycle, minimal planning |
| Chore | 0.3 | 1-phase, docs/config only |
| Refactor (v2) | 0.9 | Like feature but v1 exists as reference |

### Complexity Factors (additive)

| Factor | Weight | Condition |
|---|---|---|
| Has UI | +0.3 | Feature creates or modifies user-facing views |
| Has Auth/External Service | +0.5 | Feature depends on external service integration (Supabase, Google, Apple) |
| Runtime Testing Required | +0.4 | Feature requires manual testing with real credentials (not just compile-verify) |
| New Model/Service | +0.2 | Feature introduces a new data model, service class, or protocol |
| Cross-Feature Dependencies | +0.2 | Feature modifies shared infrastructure used by other features |
| Design Iterations | +0.15 per round | Each post-merge design iteration adds complexity |

---

## 2. Primary Normalized Metric: Minutes Per Complexity Unit (min/CU)

```
Velocity = Wall_Time_Minutes / CU
```

Lower is better. This is the single metric that enables cross-version comparison.

---

## 3. Retroactive Normalization — All Features

### Raw Data

| # | Feature | FW Ver. | Type | Wall Time (min) | Tasks | Files | Events | Has UI | Auth | Runtime | New Model | Cross-Feat | Design Iter |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Onboarding v2 | v2.0 | refactor | 390 | 22 | 20 | 5 | Y | N | N | N | N | 0 |
| 2 | Home v2 | v3.0 | refactor | 2160 | 17 | 5 | 4 | Y | N | N | N | Y | 0 |
| 3 | Training v2 | v4.0 | refactor | 300 | 16 | 7 | 12 | Y | N | N | N | N | 0 |
| 4 | Nutrition v2 | v4.1 | refactor | 120 | 14 | 5 | 5 | Y | N | N | N | N | 0 |
| 5 | Stats v2 | v4.1 | refactor | 90 | 10 | 4 | 4 | Y | N | N | N | N | 0 |
| 6 | Settings v2 | v4.1 | refactor | 60 | 6 | 3 | 3 | Y | N | N | N | N | 0 |
| 7 | Readiness v2 | v4.2 | enhancement | 150 | 7 | 7 | 9 | Y | N | N | Y | N | 0 |
| 8 | AI Engine v2 | v4.2 | enhancement | 30 | 4 | 4 | 0 | N | N | N | N | Y | 0 |
| 9 | AI Rec UI | v4.2 | feature | 42 | 6 | 7 | 6 | Y | N | N | N | N | 0 |
| 10 | Profile | v4.4 | feature | 120 | 13 | 12 | 6 | Y | N | N | N | N | 0 |
| 11 | AI Engine Arch | v5.1 | enhancement | 90 | 13 | 17 | 2 | Y | N | N | Y | Y | 0 |
| 12 | Onboarding Auth | v5.1 | feature | 100 | 18 | 15 | 5 | Y | Y | Y | N | N | 3 |

### Complexity Calculations

| # | Feature | Tasks | Type Wt | Factors Sum | CU | Calculation |
|---|---|---|---|---|---|---|
| 1 | Onboarding v2 | 22 | 0.9 | +0.3 (UI) = 0.3 | 25.7 | 22 × 0.9 × 1.3 |
| 2 | Home v2 | 17 | 0.9 | +0.3 (UI) +0.2 (cross) = 0.5 | 23.0 | 17 × 0.9 × 1.5 |
| 3 | Training v2 | 16 | 0.9 | +0.3 (UI) = 0.3 | 18.7 | 16 × 0.9 × 1.3 |
| 4 | Nutrition v2 | 14 | 0.9 | +0.3 (UI) = 0.3 | 16.4 | 14 × 0.9 × 1.3 |
| 5 | Stats v2 | 10 | 0.9 | +0.3 (UI) = 0.3 | 11.7 | 10 × 0.9 × 1.3 |
| 6 | Settings v2 | 6 | 0.9 | +0.3 (UI) = 0.3 | 7.0 | 6 × 0.9 × 1.3 |
| 7 | Readiness v2 | 7 | 0.8 | +0.3 (UI) +0.2 (model) = 0.5 | 8.4 | 7 × 0.8 × 1.5 |
| 8 | AI Engine v2 | 4 | 0.8 | +0.2 (cross) = 0.2 | 3.8 | 4 × 0.8 × 1.2 |
| 9 | AI Rec UI | 6 | 1.0 | +0.3 (UI) = 0.3 | 7.8 | 6 × 1.0 × 1.3 |
| 10 | Profile | 13 | 1.0 | +0.3 (UI) = 0.3 | 16.9 | 13 × 1.0 × 1.3 |
| 11 | AI Engine Arch | 13 | 0.8 | +0.3 (UI) +0.2 (model) +0.2 (cross) = 0.7 | 17.7 | 13 × 0.8 × 1.7 |
| 12 | Onboarding Auth | 18 | 1.0 | +0.3 (UI) +0.5 (auth) +0.4 (runtime) +0.45 (3 design iter) = 1.65 | 47.7 | 18 × 1.0 × 2.65 |

### Normalized Velocity (min/CU)

| # | Feature | FW Ver. | Wall Time | CU | min/CU | Rank | vs Baseline |
|---|---|---|---|---|---|---|---|
| 2 | Home v2 | v3.0 | 2160 | 23.0 | **93.9** | 12 (worst) | Outlier* |
| 1 | Onboarding v2 | v2.0 | 390 | 25.7 | **15.2** | 11 | Baseline |
| 3 | Training v2 | v4.0 | 300 | 18.7 | **16.0** | 10 | -5% (worse) |
| 7 | Readiness v2 | v4.2 | 150 | 8.4 | **17.9** | 9 | -18% (worse) |
| 8 | AI Engine v2 | v4.2 | 30 | 3.8 | **7.9** | 6 | +48% faster |
| 5 | Stats v2 | v4.1 | 90 | 11.7 | **7.7** | 5 | +49% faster |
| 4 | Nutrition v2 | v4.1 | 120 | 16.4 | **7.3** | 4 | +52% faster |
| 10 | Profile | v4.4 | 120 | 16.9 | **7.1** | 3 | +53% faster |
| 6 | Settings v2 | v4.1 | 60 | 7.0 | **8.6** | 7 | +43% faster |
| 9 | AI Rec UI | v4.2 | 42 | 7.8 | **5.4** | 2 | +64% faster |
| 11 | AI Engine Arch | v5.1 | 90 | 17.7 | **5.1** | 1 | +66% faster |
| 12 | Onboarding Auth | v5.1 | 100 | 47.7 | **2.1** | **Best** | **+86% faster** |

*Home v2 excluded from trend analysis — outlier that invented the v2 convention.

---

## 4. Trend Analysis

### By Framework Version (averaged, excluding Home v2 outlier)

| FW Version | Features | Avg min/CU | vs Baseline | Interpretation |
|---|---|---|---|---|
| v2.0 | 1 | 15.2 | Baseline | No cache, no skills, monolithic PM |
| v4.0 | 1 | 16.0 | -5% | Learning cost of cache system — expected regression |
| v4.1 | 3 | 7.9 | +48% | Cache acceleration kicks in (40-70% hit rates) |
| v4.2 | 3 | 10.4 | +32% | Mixed — includes Readiness (new model type) |
| v4.4 | 1 | 7.1 | +53% | Eval-driven dev — overhead paid back in quality |
| v5.1 | 2 | 3.6 | **+76%** | SoC optimizations + deep pattern reuse |

### Power Law Fit

```
Velocity(N) = 15.2 × N^(-0.68)

Where N = feature sequence number (1-12, excluding Home v2)
R² = 0.82 (strong fit)
```

The **-0.68 exponent** indicates steep improvement that hasn't yet plateaued. For comparison:
- Typical software learning curves: -0.3 to -0.5
- Manufacturing improvement: -0.2 to -0.3
- FitMe PM framework: **-0.68** (accelerated by compounding cache + SoC optimizations)

---

## 5. Confounders & Limitations

| Confounder | Impact | Mitigation |
|---|---|---|
| Single practitioner | Can't separate framework improvement from personal learning | Captured by cache hit rate — high cache% means the framework is doing the learning, not the human |
| Feature complexity varies | Addressed by CU normalization | But some factors (auth complexity, design iteration difficulty) are subjective |
| Framework evolves between measurements | This IS the signal, not noise | Documented which version produced which result |
| Session continuity varies | Single-session features benefit from warm context | Noted in each case study |
| Task count is self-reported | Different features may count tasks at different granularity | Mitigated by consistent task breakdown methodology after v3.0 |

---

## 6. How to Apply in Future Case Studies

Every new case study must include:

1. **Raw data table** with all columns from §3
2. **CU calculation** showing factors and multiplication
3. **min/CU result** compared to historical range (best: 2.1, baseline: 15.2)
4. **Updated trend chart** appended to this document

### Template Addition for Case Study Template

Add to `docs/case-studies/case-study-template.md` Section 5:

```markdown
### Normalized Velocity

| Metric | Value |
|---|---|
| Complexity Units (CU) | {CU} |
| min/CU | {velocity} |
| Rank (of N features) | {rank} / {N} |
| vs Baseline (v2.0) | {+/-}% |
| Complexity factors applied | {list} |
```

---

## 7. v2 Normalization (Framework v6.0+)

> Added 2026-04-16. v1 methodology (Sections 1-6) is preserved unchanged. v2 refines the inputs, not the formula.

### CU Formula (unchanged)

```text
CU = Tasks × Work_Type_Weight × (1 + sum(Weighted_Factors))
```

### Changes from v1 — Complexity Factors

| Factor | v1 (binary/flat) | v2 (continuous) | Signal Source |
| --- | --- | --- | --- |
| Has UI | +0.3 | +0.15 (1 view) / +0.30 (2-3) / +0.45 (4+) | `state.json → complexity.view_count` |
| Design Iterations | +0.15 per round | +0.10 (text) / +0.15 (layout) / +0.20 (interaction) / +0.25 (full redesign) per round | `state.json → complexity.design_iteration_details` |
| New Model/Service | +0.2 | +0.1 (1-2 types) / +0.2 (3-5) / +0.3 (6+) | `state.json → complexity.new_types_count` |
| Auth/External | +0.5 | +0.5 (unchanged) | Same binary flag |
| Runtime Testing | +0.4 | +0.4 (unchanged) | Same binary flag |
| Cross-Feature | +0.2 | +0.2 (unchanged) | Same binary flag |
| **Architectural Novelty** | Not tracked | **+0.2** | `state.json → complexity.is_first_of_kind` (no cache entry for this pattern) |

### New Reporting Requirements

1. **time_source flag**: Every velocity figure must note `(measured)` or `(estimated)`
2. **cu_version field**: `state.json → complexity.cu_version` (1 or 2)
3. **Velocity annotation**: Cache hit rate context (see Cache Tracking Protocol)
4. **Three baselines**:

| Comparison | Formula |
| --- | --- |
| vs Historical Baseline | `15.2 / this_min_cu` (Onboarding v2, always reported) |
| vs Rolling Baseline | `mean(last 5 features min/CU) / this_min_cu` |
| vs Same-Type Baseline | `mean(last 3 same work_type min/CU) / this_min_cu` |

5. **Serial vs Parallel Decomposition** (for multi-feature sessions):

| Metric | Formula |
| --- | --- |
| Serial velocity | This feature's min/CU (CU / active minutes on this feature alone) |
| Serial improvement | `15.2 / serial_velocity` |
| Parallel speedup | `parallel_CU_per_hour / serial_CU_per_hour` |
| Combined improvement | `serial_improvement × parallel_speedup` |

Single-feature runs: `parallel_speedup = 1.0x`, `combined = serial`.

### Backward Compatibility

- v1 CU values are **preserved unchanged**. No retroactive recomputation.
- `cu_version` field distinguishes v1 (binary) from v2 (continuous) calculations.
- Cross-version comparisons must note which formula was used.
- Features without `complexity` object in state.json default to v1 calculation.
