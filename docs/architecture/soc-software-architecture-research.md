# SoC-on-Software Architecture Research

> **Status:** Items 1+2 IMPLEMENTED (2026-04-14). Framework bumped to v5.0.
> **Context:** PM hub v4.2 → v5.0 acceleration path.
> **Impact:** ~54K tokens reclaimable (27% of context window) with low effort.

## Problem Statement

The PM hub v4.2 framework costs ~96K tokens to fully load (~48% of 200K practical context). To continue the efficiency trend (6.5h → 1h across v2.0 → v4.2), the next leap requires architectural innovation — not just process refinement.

## Framework Context Budget (measured)

| Layer | Tokens | % of Total |
|---|---|---|
| 11 SKILL.md files | 38,537 | 40% |
| Cache (L1/L2/L3) | 32,010 | 33% |
| Integration adapters | 16,999 | 18% |
| Shared data layer | 8,649 | 9% |
| **Total** | **96,195** | **~48% of 200K** |

## Commit Count Trend (dispatch overhead proxy)

| Screen | Commits |
|---|---|
| Onboarding | 13 |
| Home | 13 |
| Training | 6 |
| Nutrition | 6 |
| Stats | 2 |
| Settings | 2 |

## 7 Hardware Principles → Software Optimizations

### 1. Apple LoRA Adapter Hot-Swap → Skill-on-Demand Loading

Apple loads ~10MB LoRA adapters dynamically per task over one base model. Hub equivalent: load only the 1-2 relevant SKILL.md files per invocation instead of all 11.

- **Saves:** ~30K tokens/session
- **Effort:** Low (routing logic in hub)
- **Mechanism:** `skill-routing.json` already knows which skills each phase needs. Add a `load_skills` field per phase; hub loads only those.

### 2. Apple Palettization (3.7-bit avg) → Cache Compression

Apple compresses 3B params to 3.7 bits/weight via K-means palettization. Hub equivalent: add `compressed_view` field to each cache entry (~200 word summary). Load compressed view in Phase 1; expand only if deeper investigation needed.

- **Saves:** ~24K tokens
- **Effort:** Low (add field to cache schema)
- **Mechanism:** Each L1/L2/L3 cache entry gets a `compressed_view` (≤200 words). Hub loads compressed views by default. `expand_cache: true` flag loads full entries when needed.

### 3. TPU Weight-Stationary Dataflow → Template-Stationary Batch Audits

TPU loads weights once, streams unlimited data through. Hub equivalent: load audit pattern set once, process N screens as data stream. 5x fewer dispatches for N-screen tasks.

- **Saves:** 5x fewer dispatches for batch operations
- **Effort:** Medium
- **Mechanism:** New `batch_audit` command in hub. Load template once → iterate screens as data.

### 4. M-series UMA Zero-Copy → Result Forwarding

UMA eliminates CPU/GPU memory copy. Hub equivalent: pass skill output inline (in context) to next skill instead of write-to-JSON-read-back cycle.

- **Saves:** Eliminates serialization overhead
- **Effort:** Medium
- **Mechanism:** Skill chain protocol where output stays in context window. Shared layer becomes write-back target only (like a register file).

### 5. ANE Mixed Precision → Model Tiering

ANE uses FP16 for bulk, FP32 for accuracy-critical. Hub equivalent: sonnet for mechanical tasks, opus for judgment tasks.

- **Saves:** Cost + latency on mechanical work
- **Effort:** Low (already partially doing this)
- **Mechanism:** Add `model_tier` field to `skill-routing.json`. Mechanical phases (token checks, file generation) use sonnet; judgment phases (architecture, review) use opus.

### 6. Branch Prediction → Speculative Cache Pre-loading

When `/ux` runs, pre-load `/design` cache because design always follows UX. Validated by arxiv paper 2510.04371 ("Speculative Actions").

- **Saves:** 30-40% latency reduction on skill chains
- **Effort:** Medium
- **Misprediction cost:** ~3K tokens (1.5% of budget)
- **Mechanism:** `speculative_preload` map in `skill-routing.json` — each skill declares likely successors.

### 7. TPU Systolic Array → Skill Chain Pipeline Protocol

Each skill receives only upstream output + own L1 cache. No global reads mid-execution. Shared layer becomes write-back target only.

- **Saves:** Eliminates Amdahl's Law bottleneck on sequential chains
- **Effort:** High (protocol redesign)
- **Mechanism:** Full pipeline protocol where skills are isolated execution units.

## Prioritized Implementation Order

| # | Optimization | Tokens Saved | Effort | Status |
|---|---|---|---|---|
| 1 | Skill-on-demand loading | ~30K/session | Low | **Ready** |
| 2 | Cache compression (compressed_view) | ~24K/session | Low | **Ready** |
| 3 | Batch skill invocation | 5x fewer dispatches | Medium | Planned |
| 4 | Result forwarding | Eliminates write-read cycle | Medium | Planned |
| 5 | Model tiering | Cost savings | Low | Partially active |
| 6 | Speculative pre-loading | 30-40% latency | Medium | Planned |
| 7 | Systolic chain protocol | Eliminate global reads | High | Future |

**Items 1+2 reclaim ~54K tokens (27% of context window) with minimal effort.**

## Academic References

- Speculative Actions for LLM Agents (arxiv 2510.04371, Oct 2025)
- Pattern-Aware Speculative Tool Execution (arxiv 2603.18897, Mar 2026)
- Multi-Agent Collaboration via Evolving Orchestration (arxiv 2505.19591)
- Apple Foundation Models Tech Report (machinelearning.apple.com, 2025)
- Apple Foundation Models 2024 (arxiv 2407.21075v1)
- Google TPU Architecture (cloud.google.com/tpu/docs)
- Neural Engine internals (github.com/hollance/neural-engine)

## Next Steps

1. Implement item 1 (skill-on-demand) — add `load_skills` to `skill-routing.json` phases
2. Implement item 2 (cache compression) — add `compressed_view` to cache entry schema
3. Measure actual token savings after items 1+2
4. Plan items 3+4 based on measured results
