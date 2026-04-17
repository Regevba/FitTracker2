# Orchid Layer A Research Program — Design Spec

> **Date:** 2026-04-17
> **Status:** Approved (Sections 1-4)
> **Type:** Research (theoretical experiment)
> **Repo:** github.com/Regevba/orchid (code), FitTracker2 (spec + case study)
> **Builds on:** Orchid Phase 1 (46 tests, 7 units), design space exploration (90 runs)

---

## Section 1: What We're Building

A comprehensive Python-level research program producing 6 experiments and 2 case study documents, positioning Orchid as the natural evolution of the FitMe PM framework's SoC-on-Software research thread.

### Deliverables

1. **Real trace dataset** — convert all v6.0+ feature state.json files into Orchid traces
2. **Parameter sensitivity analysis** — quantified parameter importance with interaction effects
3. **Architectural ablation study** — remove each unit, measure composite score impact
4. **Multi-feature parallel traces** — stress U4 batch scheduling (gap from initial findings)
5. **Property-based stress testing** — 25,000 runs across randomized configs + traces
6. **Software vs hardware latency comparison** — theoretical speedup table

### Case Study Documents

- **Full:** FitTracker2 `docs/case-studies/orchid-ai-accelerator-case-study.md` — standard template, 10 sections, academic rigor + framework narrative
- **Condensed:** Orchid repo `docs/case-study.md` — standalone research summary linking back to full version

### Audience

Both academic/portfolio and framework evolution narrative. The case study stands alone for academic purposes but also slots into the FitMe story as the endpoint of SoC-on-Software → HADF → Orchid.

---

## Section 2: Research Program — 6 Experiments

### Experiment 1: Real Trace Dataset

**Goal:** Convert every v6.0+ feature's `state.json` + `cache-hits.json` into Orchid `.jsonl` traces and replay through the pipeline.

**Sources:** `.claude/features/*/state.json` (features with `timing` data from v6.0 instrumentation). Expected 5-15 real traces from completed features (framework-measurement-v6, meta-analysis-audit, smart-reminders, dispatch-intelligence, parallel-write-safety, etc.).

**Method:** Run `trace_converter.py` on each feature directory, feed output through `trace_replayer.py`, save results.

**Deliverable:** Real-world benchmark dataset. These are ground truth — synthetic traces validate architecture, real traces validate relevance.

### Experiment 2: Parameter Sensitivity Analysis

**Goal:** Quantify which OrchidConfig parameter matters most, including interaction effects.

**Method:** Latin hypercube sampling across the full parameter space:
- `cache_entries`: [3, 5, 8, 10, 15, 20, 30]
- `max_concurrent`: [1, 2, 4, 8, 16]
- `prefetch_ahead`: [0, 1, 2, 3, 4]
- `prediction_table_size`: [8, 16, 32, 64, 128]
- `queue_depth`: [8, 16, 32, 64]

200 random configurations sampled from this space. Each config runs against all synthetic + real traces. Measure composite score variance attributable to each parameter (one-at-a-time sensitivity index) and pairwise interaction effects.

**Deliverable:** Ranked parameter importance table — e.g. "cache_entries explains 47% of score variance, prefetch_ahead explains 31%, everything else < 5%." Pairwise interaction heatmap.

### Experiment 3: Architectural Ablation Study

**Goal:** Prove which units are load-bearing vs nice-to-have by removing them one at a time.

**Ablations:**

| Ablation | What It Tests |
|---|---|
| Remove U3 (cache) | Pipeline with no caching — every lookup is a miss |
| Remove U4 (batch) | No grouping — tasks dispatch in arrival order |
| Remove U5 (prefetch) | No speculation — cache only warms from direct hits |
| Remove U6 (coherence) | No write coordination — measure corruption risk |
| Remove U3+U5 | No memory hierarchy — pure compute pipeline |
| Baseline (all units) | Full Orchid pipeline |

**Method:** Create `AblatedOrchestrator` variants that skip specific units. Run each against all traces. Measure composite score delta vs baseline.

**Deliverable:** Ablation table with per-unit contribution. Column: ablation name, composite score, delta vs baseline, % degradation, cache hit rate, corruption count.

### Experiment 4: Multi-Feature Parallel Traces

**Goal:** Stress U4 batch scheduling with realistic parallel workloads (gap from initial findings where `max_concurrent` had zero impact).

**Traces to generate:**

| Trace | Description |
|---|---|
| `parallel_2_features.jsonl` | 2 features interleaved, realistic phase sequences |
| `parallel_4_features.jsonl` | 4 features (v5.1 stress test scenario) |
| `parallel_8_features.jsonl` | 8 features (saturation at max_concurrent=8) |

Each feature follows a realistic phase sequence (research→prd→tasks→implement→test→review→merge) offset in time, with events interleaved by timestamp.

**Deliverable:** Proves whether U4's tier grouping provides measurable throughput improvement. Expected: parallel_8 should show batch scheduling benefit when tasks from different features arrive simultaneously.

### Experiment 5: Property-Based Stress Testing

**Goal:** Prove architectural robustness across the entire parameter + trace space.

**Method:** Generate 500 random OrchidConfig configurations and 50 random trace sequences. Run every config against every trace (25,000 runs). Assert invariants:

| Invariant | Unit | Assertion |
|---|---|---|
| Score range | U1 | `0 <= score <= 100` for all inputs |
| Routing completeness | U2 | `len(skills) >= 1` for all phases |
| Cache monotonicity | U3 | Hit rate non-decreasing in steady state |
| No corruption | U6 | `corruption_count == 0` under random access |
| Positive score | Metrics | `composite_score > 0` for non-empty traces |

**Deliverable:** 25,000 test runs. Any invariant violation = bug to fix. Zero violations = architecture is robust for RTL.

### Experiment 6: Software vs Hardware Latency Comparison

**Goal:** Quantify the theoretical speedup of Orchid over the software framework.

**Method:**
1. From real traces (Exp 1), extract `latency_ms` (actual PM framework dispatch time from v6.0 timing)
2. From Orchid pipeline, extract `total_cycles` for the same decisions
3. Assume 1 GHz clock → `orchid_latency_ns = total_cycles`
4. Speedup = `software_latency_ms * 1e6 / orchid_latency_ns`

**Caveats (documented in case study):**
- This is a theoretical upper bound, not a measured RTL speed
- Python cycle counts model the architecture, not the actual hardware timing
- Real speedup requires Verilator validation (Phase 2+)
- The comparison is dispatch overhead only, not end-to-end AI inference

**Deliverable:** Speedup table per feature with confidence interval. Expected: orders of magnitude (software dispatches in milliseconds, hardware in nanoseconds).

---

## Section 3: Case Study Structure

### Full Case Study (FitTracker2)

Path: `docs/case-studies/orchid-ai-accelerator-case-study.md`

```
1. Summary Card
   - Feature: Orchid AI Orchestration Accelerator
   - Type: Research (theoretical experiment)
   - Framework version: v6.0 → v6.1
   - CU: N/A (research, not a shipped feature)
   - Wall time: measured via v6.0 timing
   - Key metric: 6 experiments, N real traces, 25,000 stress runs

2. The Research Arc
   - SoC-on-Software (v5.0): chip → software, 7 principles, 54K tokens reclaimed
   - HADF (v6.0): hardware-aware dispatch, detect real chip, adapt routing
   - Orchid: software → chip, close the loop
   - Timeline: v1.0 → v5.2 → Orchid (framework recapitulates CPU architecture)

3. Methodology
   - Layer A behavioral models (Python)
   - 7 functional units mapped from framework components
   - Progressive verification ladder (A → B → C)
   - v6.0/v6.1 integration as data source

4. Experiment Results (6 sub-sections)
   4.1 Real trace dataset — N features, baseline scores
   4.2 Parameter sensitivity — ranked importance, interaction heatmap
   4.3 Ablation study — per-unit contribution table
   4.4 Parallel traces — batch scheduler validation
   4.5 Stress testing — 25,000 runs, invariant results
   4.6 Software vs hardware — speedup table

5. Design Space Findings
   - Original 90-run sweep (from prior session)
   - Updated recommendations (prefetch_ahead, pred_table_size)
   - Combined with sensitivity analysis for final config guidance

6. Architecture Validation
   - Load-bearing units (from ablation)
   - Critical parameters (from sensitivity)
   - Robustness certification (from stress testing)

7. The Framework Evolution Parallel
   - v1.0 = single-issue in-order → Orchid U1
   - v3.0 = superscalar → Orchid U4
   - v5.0 = cache hierarchy → Orchid U3
   - v5.2 = coherence → Orchid U6
   - Mapping table: framework version ↔ CPU era ↔ Orchid unit

8. What We Learned
   - Insights from experiments
   - Surprises
   - Data-driven Phase 2-5 readiness assessment

9. Measured vs Claimed
   - Validation taxonomy distribution
   - Self-referential bias acknowledgment
   - What requires RTL to confirm

10. Next Steps
    - Phase 2-5 execution requirements
    - Separate repo strategy
    - Connection to showcase repo
```

### Condensed Case Study (Orchid repo)

Path: `docs/case-study.md`

Sections 1 (Summary), 3 (Methodology), 4 (Results — numbers only), 5 (Design Space), 7 (Evolution Parallel), 10 (Next Steps). Links to full version for methodology details.

---

## Section 4: Monitoring & Data Pipeline

### Experiment Tracker

File: `orchid/results/experiment-tracker.json`

```json
{
  "experiments": {
    "real_traces": { "status": "pending", "traces_collected": 0, "target": 10 },
    "sensitivity": { "status": "pending", "configs_run": 0, "target": 200 },
    "ablation": { "status": "pending", "ablations_run": 0, "target": 6 },
    "parallel_traces": { "status": "pending", "traces_generated": 0, "target": 3 },
    "stress_test": { "status": "pending", "runs_completed": 0, "target": 25000 },
    "latency_comparison": { "status": "pending", "features_compared": 0, "target": 10 }
  },
  "totals": {
    "total_benchmark_runs": 0,
    "invariant_violations": 0,
    "wall_time_minutes": 0
  }
}
```

Updated automatically after each experiment completes.

### Results Directory

```
orchid/results/
├── layer_a/
│   ├── design_space_sweep.json          # existing (90 runs)
│   ├── *_results.json                   # existing (5 benchmarks)
│   ├── real_traces/                     # Exp 1
│   │   └── {feature}_results.json
│   ├── sensitivity/                     # Exp 2
│   │   └── sensitivity_analysis.json
│   ├── ablation/                        # Exp 3
│   │   └── ablation_study.json
│   ├── parallel/                        # Exp 4
│   │   └── parallel_results.json
│   ├── stress/                          # Exp 5
│   │   └── stress_test_report.json
│   └── latency/                         # Exp 6
│       └── latency_comparison.json
├── experiment-tracker.json
└── case-study-data.json                 # aggregated for case study
```

### Data Aggregation

After all 6 experiments, `aggregate_results.py` collects all outputs into `case-study-data.json`. Every number in the case study comes from this file — no manual data entry.

---

## Files Changed Summary

| File | Location | Type |
|---|---|---|
| `layer-a/experiments/exp1_real_traces.py` | Orchid repo | New |
| `layer-a/experiments/exp2_sensitivity.py` | Orchid repo | New |
| `layer-a/experiments/exp3_ablation.py` | Orchid repo | New |
| `layer-a/experiments/exp4_parallel_traces.py` | Orchid repo | New |
| `layer-a/experiments/exp5_stress_test.py` | Orchid repo | New |
| `layer-a/experiments/exp6_latency_comparison.py` | Orchid repo | New |
| `layer-a/experiments/aggregate_results.py` | Orchid repo | New |
| `results/experiment-tracker.json` | Orchid repo | New |
| `docs/case-study.md` | Orchid repo | New |
| `docs/case-studies/orchid-ai-accelerator-case-study.md` | FitTracker2 | New |
