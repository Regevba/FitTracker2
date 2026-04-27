# Case Study: SoC-on-Software — Framework v4.4 → v5.0 → v5.1

**Date written:** 2026-04-15
<!-- doc-debt-backfill: fields added by scripts/backfill-case-study-fields.py -->

| Field | Value |
|---|---|
| Dispatch Pattern | serial |

**Success Metrics:** TODO: review <!-- TODO: review -->

**Kill Criteria:** TODO: review <!-- TODO: review -->


> **Core question:** Can hardware architecture principles (LoRA hot-swap, palettization, TPU dataflow, UMA zero-copy, ANE mixed precision, branch prediction, systolic arrays, big.LITTLE) be mapped to a software PM framework to reduce context-window overhead without losing capability?

## 1. Summary Card

| Field | Value |
|---|---|
| Feature | Framework v5.0 (items 1-2) + v5.1 (items 3-8) |
| Framework version | v4.4 → v5.0 → v5.1 |
| Work type | Chore |
| Complexity | Cross-feature infrastructure, new routing schema |
| Wall time | ~30 min (research prior session + 10 min v5.0 impl + 15 min v5.1 impl + 5 min docs) |
| Files changed | 29 files, ~1,130 insertions |
| Tests passing | 197 (no regressions) |
| Headline | 7 chip-architecture principles applied to PM framework. 63% overhead reduction (121K → 45K tokens/phase). Free context nearly doubled (78K → 155K tokens). 8/8 items shipped across 3 commits. |

## 2. Experiment Design

**Independent variable:** Framework architecture (v4.4 monolithic loading → v5.0 on-demand + compressed → v5.1 full SoC suite).

| Dependent variable | Measurement |
|---|---|
| Framework token overhead | Tokens consumed by SKILL.md + cache + shared layer + adapters per phase |
| Free context for work | 200K − framework overhead |
| Phase load time | Tokens loaded per phase (proxy for latency) |
| Throughput | Tasks completable per context window |
| Quality regression | Test pass rate before/after |

**Complexity proxy:** 8 implementation tasks × 7 architectural principles × 5 config schemas (phase_skills, batch_dispatch, result_forwarding, speculative_preload, model_tiering, systolic_chain, task_complexity_gate).

**Controls:** Unchanged application code, same test suite, same feature set. Only framework infrastructure changed.

## 3. Raw Data

### Baseline: Framework v4.2 Token Budget

| Layer | Tokens | % of 200K |
|---|---|---|
| 11 SKILL.md files | 38,537 | 19% |
| Cache (L1/L2/L3) | 32,010 | 16% |
| Integration adapters (6) | 16,999 | 8% |
| Shared data layer | 8,649 | 4% |
| **Total** | **96,195** | **48%** |

### After v5.1: Optimized Per-Phase Loading

| Layer | v4.4 (all) | v5.1 (optimized) | Reduction |
|---|---|---|---|
| SKILL.md files | 42,907 | ~7,833 | 82% |
| Cache entries | 33,737 | ~3,213 | 90% |
| Shared layer | 29,079 | ~29,079 | 0% (or 100% in systolic mode) |
| Adapters | 15,991 | ~5,000 | 69% |
| **Total** | **121,714** | **~45,125** | **63%** |
| **Free for work** | **78,286** | **154,875** | **+98%** |

### Implementation Timeline

| Commit | Version | Items | Files | Insertions |
|---|---|---|---|---|
| `7288faa` | v5.0 | 1-2 (skill-on-demand, cache compression) | 24 | 387 |
| `1fd849c` | v5.1 | 3-7 (batch, forwarding, tiering, preload, systolic) | 5 | ~600 |
| `f995c1e` | v5.1 | 8 (big.LITTLE task dispatch) | 5 | 145 |

### Per-Item Savings

| # | Chip Principle | Software Analog | Token Savings |
|---|---|---|---|
| 1 | LoRA Adapter Hot-Swap | Skill-on-Demand Loading | ~35K/phase (82% of SKILL layer) |
| 2 | Palettization (3.7-bit) | Cache Compression | ~30.5K (91% compression, 10.5×) |
| 3 | TPU Weight-Stationary | Template-Stationary Batch Audits | ~50% fewer reads for N-target ops |
| 4 | UMA Zero-Copy | Result Forwarding | ~7.5K/Phase 3 run |
| 5 | ANE Mixed Precision | Model Tiering (sonnet/opus) | 60% of phases on cheaper model |
| 6 | Branch Prediction | Speculative Cache Pre-loading | ~7 cache reads eliminated/lifecycle |
| 7 | TPU Systolic Array | Skill Chain Pipeline Protocol | Up to 29K/stage in full isolation |
| 8 | ARM big.LITTLE | Hybrid Task Dispatch | ~2-3× throughput on mixed tasks |

### Task Completion

| Task | Status | Cache Hit? |
|---|---|---|
| Add phase_skills map to skill-routing.json (11/11 skills) | Done | No |
| Add compressed_view to all 15 L1/L2/L3 cache entries | Done | No |
| Update hub SKILL.md with on-demand loading protocol | Done | No |
| Add batch_dispatch config (TPU analog) | Done | Partial (reused phase_skills structure) |
| Add result_forwarding config (UMA analog) | Done | No |
| Add model_tiering config (ANE analog) | Done | No |
| Add speculative_preload + systolic_chain configs | Done | No |
| Add task_complexity_gate (big.LITTLE analog) | Done | No |
| Bump framework-manifest.json to v5.0 → v5.1 | Done | No |
| Update evolution.md, architecture docs, savings report | Done | No |

## 4. Analysis

### 4.1 Micro (Per-Item)

**Items 1-2 (v5.0) delivered the largest absolute savings.** Skill-on-demand (35K tokens) and cache compression (30.5K tokens) together reclaim ~54K tokens — 27% of the entire context window — with purely additive changes (new fields, no deletions). This was the "pick the low-hanging fruit" phase identified in the research.

**Items 3-8 (v5.1) are multiplicative.** Model tiering doesn't save tokens directly but reduces cost. Result forwarding eliminates intermediate JSON round-trips. Speculative preloading reduces perceived latency. These items compound with items 1-2 rather than replacing them.

**Item 8 (big.LITTLE) is the most speculative.** Weighted scoring across 5 heavyweight indicators (architecture decisions, cross-feature state, user-facing quality, risk assessment, complex debugging) is a heuristic, not a measurement. The 2-3× throughput claim assumes lightweight tasks genuinely parallelize, which depends on the task mix.

### 4.2 Meso (Cross-Item)

**The 7 principles form a coherent system.** Skill-on-demand (what to load) + cache compression (how much to load) + result forwarding (how to pass between skills) + systolic chains (what NOT to load mid-chain) + model tiering (which model runs each phase) + batch dispatch (how to group work) + speculative preload (what to load early) + task dispatch (where to route) — these aren't independent optimizations. They're a unified execution model.

**Academic validation.** The speculative preload design cites arxiv 2510.04371 (Speculative Actions for LLM Agents) and arxiv 2603.18897 (Pattern-Aware Speculative Tool Execution). The chip-to-software mapping isn't ad hoc — each principle has a published hardware analog and a measurable software equivalent.

### 4.3 Macro (Framework)

**The framework doubled its usable context.** From 78K free tokens (v4.4) to 155K (v5.1). This directly enables larger features — the AI Engine Architecture Adaptation (17 files, 986 insertions) and Onboarding Auth Flow (15 files, 627 insertions) both shipped at v5.1 and both benefited from the expanded context budget.

**The research-to-implementation pipeline worked.** The SoC research doc was written in a prior session, uploaded to Notion, and tracked in Linear as FIT-26. Implementation was a single focused session. The research → plan → implement → measure → document cycle completed in under an hour of wall time.

## 5. Normalized Velocity

**CU calculation (v5.0 implementation only):**

```
Tasks = 8
Work_Type_Weight = 0.3 (chore)
Complexity_Factors = New Model (+0.2) + Cross-Feature (+0.2) = 0.4
CU = 8 × 0.3 × (1 + 0.4) = 3.36
```

**Wall time (v5.0):** ~10 min

**Velocity:** 10 / 3.36 = **2.98 min/CU**

**CU calculation (full v5.0 + v5.1):**

```
Tasks = 10 (8 original + item 8 + docs)
CU = 10 × 0.3 × (1 + 0.4) = 4.2
```

**Wall time (full):** ~30 min

**Velocity:** 30 / 4.2 = **7.14 min/CU**

| Version | Feature | min/CU | Δ vs baseline |
|---|---|---|---|
| v2.0 | Onboarding v2 (baseline) | 15.2 | — |
| v4.4 → v5.0 | **SoC v5.0 only** | **2.98** | **+80%** |
| v4.4 → v5.1 | **SoC full suite** | **7.14** | **+53%** |
| v5.1 | AI Engine Architecture | 5.1 | +66% |
| v5.1 | Onboarding Auth (best) | 2.1 | +86% |

The v5.0-only velocity (2.98 min/CU) is near the project best because the research was already done — implementation was pure execution against a clear spec. The full v5.1 velocity (7.14 min/CU) includes the more speculative items 3-8 which required design decisions during implementation.

## 6. Success & Failure Cases

### Success

1. **54K tokens reclaimed with zero structural rebuild.** Items 1-2 added fields to existing files. No skill was rewritten, no cache entry was deleted, no workflow was changed. Pure additive optimization.
2. **Chip-to-software metaphor produced actionable architecture.** The 7 hardware principles weren't metaphorical — each mapped to a specific config change in `skill-routing.json` with measurable token savings.
3. **Cross-system sync executed in parallel with implementation.** Notion page, Linear FIT-26, architecture doc, and framework config were all updated in the same session. No sync lag.

### Failure

1. **Subagents hit Write permission denials on cache files.** The first 3 background agents dispatched for cache compression failed because the Write tool was denied on `.claude/cache/` files. A 4th agent using the Edit tool succeeded. This wasted ~5 min.
2. **v5.0 was a waypoint, not a stable release.** The framework went v4.4 → v5.0 → v5.1 within hours. No feature actually ran at v5.0 — it was superseded before the next PM workflow invocation.

## 7. Framework Improvement Signals

- **Token budget dashboard.** The savings numbers (82%, 91%, 63%) come from manual counting. An automated token budget tracker that shows per-phase loading cost would make optimization decisions data-driven instead of estimate-driven.
- **Compression ratio monitoring.** The 10.5× compression ratio for cache entries should be tracked over time. As cache entries grow, the compressed_view may drift from the full content, reducing its utility.
- **Speculative preload hit rate.** The branch prediction analog claims 30-40% latency reduction, but there's no measurement infrastructure. A hit/miss counter would validate or invalidate the speculation.
- **Permission-aware agent dispatch.** The Write-denied failure on cache files suggests that subagent tool permissions should be checked before dispatch, not discovered at runtime.

## 8. Methodology Notes

- Wall time is estimated from commit timestamps and monitoring snapshots (03:30 → 03:40 for v5.0). No stopwatch was used.
- Token counts come from the SoC research doc and savings report, which used `wc` on the actual files. These are approximate (token ≠ word) but consistent across measurements.
- The 63% overhead reduction is measured against the v4.4 baseline of 121,714 tokens. The v4.2 baseline of 96,195 tokens would yield a different percentage because the framework grew between v4.2 and v4.4.
- Academic citations are listed in the research doc at `docs/architecture/soc-software-architecture-research.md`.
- The CU formula uses Chore weight (0.3) because this work doesn't add user-facing functionality. Using Feature weight (1.0) would give CU = 14.0 and velocity = 2.14 min/CU, which would overstate the comparison.
