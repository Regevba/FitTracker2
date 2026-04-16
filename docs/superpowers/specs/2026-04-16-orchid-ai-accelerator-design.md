# Orchid — AI Agent Orchestration Accelerator

> Design Spec — 2026-04-16
> Status: Approved (Sections 1-10)
> Type: Theoretical research experiment

---

## Section 1: What It Is

**Orchid** (Orchestration Intelligence Device) is an open-source, RISC-V-based AI agent orchestration accelerator. It is purpose-built to accelerate the dispatch-intelligence patterns discovered in the FitMe PM framework (v5.0-v5.2) — complexity scoring, skill routing, cache management, batch scheduling, and parallel write coordination.

It exists entirely as a digital design — RTL code simulated on cloud infrastructure, never fabricated into physical silicon. The design follows a progressive verification ladder:

- **Layer A (Python)** — behavioral models that validate architecture and replay real framework traces
- **Layer B (Chisel + Verilator)** — cycle-accurate synthesizable RTL, co-simulated against Layer A
- **Layer C (Chipyard + FireSim)** — full SoC integration on cloud FPGAs

Each of Orchid's 7 functional units starts at Layer A and graduates upward independently. At any point, some units may be at Layer B while others are still at Layer A.

**Success metric:** Composite score (latency per dispatch + throughput in decisions/sec + energy per decision), measured by replaying real framework traces and synthetic stress benchmarks through the chip model.

**Novel contribution:** No existing open-source chip targets AI agent orchestration. Systolic arrays for inference exist (Gemmini). General-purpose RISC-V cores exist (Rocket, BOOM). Orchid is the first design that accelerates the *orchestration layer* — the decision-making that sits above inference.

---

## Section 2: Architecture — The 7 Functional Units

```
+-------------------------------------------------------------+
|                      ORCHID SoC                              |
|                                                              |
|  +----------+    +--------------------------------------+    |
|  | RISC-V   |    |  Orchestration Accelerator Complex   |    |
|  | Core     |    |                                      |    |
|  | (Rocket) +----+  U1: Dispatch Scorer (combinational) |    |
|  |          |RoCC|  U2: Skill Router (LUT + decoder)    |    |
|  |          +----+  U3: Cache Controller (scratchpad)   |    |
|  |          |    |  U4: Batch Scheduler (FIFO+arbiter)  |    |
|  +----+-----+    |  U5: Speculative Prefetcher          |    |
|       |          |  U6: Coherence Unit (MESI-like)      |    |
|       |          +----------------+---------------------+    |
|       |                           |                          |
|  +----+---------------------------+---------------------+    |
|  |              TileLink Interconnect                   |    |
|  |         (result forwarding bus)                      |    |
|  +----+-------------------------------+----------------|    |
|       |                               |                      |
|  +----+---------+            +--------+----------+           |
|  | U7: Systolic |            |  Memory Subsystem |           |
|  | Array        |            |  L1 Scratchpad    |           |
|  | (Gemmini)    |            |  L2 Compressed    |           |
|  |              |            |  DRAM Controller   |           |
|  +--------------+            +-------------------+           |
+-------------------------------------------------------------+
```

**U1 — Dispatch Scorer.** Pure combinational logic. Input: task descriptor (type, file count, model count, dependency flags). Output: complexity score (0-100) + recommended model tier (haiku/sonnet/opus). Maps directly to v5.2 `dispatch-intelligence.json` scoring rules. No state, no memory. Executes in a single clock cycle.

**U2 — Skill Router.** ROM-based lookup table + priority decoder. Input: complexity score + current phase. Output: skill IDs to load + tool budget. Maps directly to `skill-routing.json` phase_skills. Stateless. 1-2 cycles.

**U3 — Cache Controller.** Scratchpad SRAM with compression engine. Stores compressed_view entries (Layer 1 cache). Decompresses on demand when full expansion needed. Maps to the v5.0 cache compression optimization. Stateful — manages 15 cache entries with LRU eviction.

**U4 — Batch Scheduler.** FIFO queue + round-robin arbiter. Receives N tasks, groups by model tier, dispatches in waves. Maps to v5.1 batch dispatch. Manages up to 8 concurrent task slots (matching the framework's parallel agent limit).

**U5 — Speculative Prefetcher.** Prediction table (like a branch target buffer). When a skill begins execution, prefetches the next likely skill's cache entry based on historical phase transitions. Maps to v5.1 speculative preload. Misprediction cost: flush one cache line (~3K tokens equivalent).

**U6 — Coherence Unit.** MESI-like protocol FSM. Coordinates when multiple units (or multiple Orchid chips in a cluster) write to the same cache line. Maps to v5.2 parallel write safety — snapshot/rollback becomes hardware-enforced atomic transactions.

**U7 — Systolic Array.** Not custom — uses Gemmini with our parameterization. Handles the actual ML inference workload that the orchestration layer dispatches to. 8x8 or 16x16 configurable PE array. Weight-stationary dataflow matching our v5.1 batch dispatch pattern.

**Interconnect — TileLink bus.** Standard Chipyard interconnect. Serves as the result forwarding bus — U1's output routes directly to U2, U2 to U3, etc. without write-read serialization. Maps to v5.1 UMA zero-copy result forwarding.

---

## Section 3: Progressive Build Order — Layer A Through C

Each unit follows the same promotion lifecycle:

```
Layer A                    Layer B                     Layer C
(Python behavioral)   ->  (Chisel RTL + Verilator)  -> (Chipyard + FireSim)
                      ^                              ^
                 co-simulation                  same Chisel code
                 validates match                drops into SoC
```

### Phase 1 — Foundation (Layer A, all units)

| Step | Unit | Deliverable | Validates |
|---|---|---|---|
| 1.1 | U1: Dispatch Scorer | Python function: `score(task) -> (score, tier)` | Scoring rules match v5.2 config |
| 1.2 | U2: Skill Router | Python dict: `route(score, phase) -> skills[]` | Routing matches skill-routing.json |
| 1.3 | U3: Cache Controller | Python class with get/put/compress/expand | Hit rates match real framework traces |
| 1.4 | U4: Batch Scheduler | Python queue simulator | Grouping + wave dispatch timing |
| 1.5 | U5: Speculative Prefetcher | Python prediction table | Prediction accuracy vs. real traces |
| 1.6 | U6: Coherence Unit | Python MESI state machine | Conflict resolution correctness |
| 1.7 | Trace Replayer | Python harness that feeds real + synthetic traces through U1-U6 | End-to-end composite score baseline |

### Phase 2 — First RTL (Layer B, units U1-U2)

Start with the two stateless units — they're pure combinational logic, simplest to express in Chisel.

| Step | Unit | Deliverable | Validates |
|---|---|---|---|
| 2.1 | U1: Dispatch Scorer | Chisel module, Verilator testbench | Cycle count = 1, output matches Layer A |
| 2.2 | U2: Skill Router | Chisel module, Verilator testbench | Cycle count = 1-2, output matches Layer A |
| 2.3 | Co-simulation harness | cocotb bridge: Python traces -> RTL inputs -> compare outputs | Layer A/B produce identical results |

### Phase 3 — Stateful Units (Layer B, units U3-U5)

| Step | Unit | Deliverable | Validates |
|---|---|---|---|
| 3.1 | U3: Cache Controller | Chisel scratchpad + LZ4 decompressor | Hit rates, compression ratio, latency |
| 3.2 | U4: Batch Scheduler | Chisel FIFO + arbiter | Throughput under load |
| 3.3 | U5: Speculative Prefetcher | Chisel prediction table + prefetch FSM | Prediction accuracy, misprediction cost |

### Phase 4 — Complex Units (Layer B, unit U6 + interconnect)

| Step | Unit | Deliverable | Validates |
|---|---|---|---|
| 4.1 | U6: Coherence Unit | Chisel MESI FSM | Protocol correctness under contention |
| 4.2 | TileLink interconnect | Wire U1-U6 together via TileLink | Result forwarding latency |
| 4.3 | Full orchestration pipeline | U1->U2->U3->U4 connected end-to-end | Pipeline throughput vs. Layer A baseline |

### Phase 5 — SoC Integration (Layer C)

| Step | Component | Deliverable | Validates |
|---|---|---|---|
| 5.1 | Rocket core + U1-U2 as RoCC | Chipyard config, Verilator SoC sim | Software can invoke dispatch scorer via custom instructions |
| 5.2 | Add U3-U6 to SoC | Full orchestration complex on TileLink | All units communicate through bus |
| 5.3 | Add Gemmini (U7) | Parameterized systolic array in same SoC | Dispatch pipeline feeds inference engine |
| 5.4 | FireSim deployment | AWS F1 FPGA image | Near-real-time full system simulation |
| 5.5 | Trace replay on full SoC | Real framework traces through complete Orchid | Final composite score: latency + throughput + energy |

---

## Section 4: Trace Infrastructure

### Real traces — captured from live pm-workflow runs

```json
{
  "timestamp_ns": 1713264000000000,
  "event": "dispatch_decision",
  "task": {
    "type": "implement",
    "files_changed": 3,
    "new_models": false,
    "phase": "implement",
    "complexity_hint": "medium"
  },
  "decision": {
    "score": 42,
    "tier": "sonnet",
    "skills_loaded": ["pm-workflow", "dev"],
    "tool_budget": 25,
    "cache_hits": ["dev_L1", "shared_L2"],
    "latency_ms": 1240
  }
}
```

Instrumentation point: add a lightweight logger to `pm-workflow/SKILL.md` execution path that emits one trace line per dispatch decision. No performance impact — append-only log file.

### Synthetic traces — generated for stress testing

| Scenario | Purpose |
|---|---|
| 100 haiku-tier tasks in burst | Batch scheduler saturation |
| 50 opus-tier tasks, all touching same file | Coherence unit contention |
| Alternating UX->Design->Implement chains | Speculative prefetcher accuracy |
| Random uniform distribution | Baseline throughput |
| Cache cold start -> warm steady state | Cache controller warming curve |

### Composite score formula

```
Orchid Score = w1 * (1 / latency_ns) + w2 * throughput_decisions_per_sec + w3 * (1 / energy_pJ)

where w1 = 0.4, w2 = 0.35, w3 = 0.25
(latency-biased — dispatch speed is the primary bottleneck)
```

Baseline: software framework running same traces on host CPU. Orchid's score is compared as a speedup ratio.

---

## Section 5: Toolchain & Repository Structure

### Language choices per layer

| Layer | Language | Why |
|---|---|---|
| A (Behavioral) | Python 3.11+ | Fastest iteration, cocotb compatibility, trace processing |
| B (RTL) | Chisel 3 (Scala) | Same language as Rocket, Gemmini, Chipyard — zero integration friction |
| C (SoC) | Chisel + Chipyard configs | Chipyard is Chisel-native, configs are Scala case classes |
| Testbenches | cocotb (Python) | Bridge between Layer A models and Layer B RTL — same test runs against both |
| Traces | Python + JSON Lines | Lightweight, streamable, greppable |

### Repository structure

```
orchid/
|-- README.md
|-- docs/
|   +-- design-spec.md                  # This spec
|
|-- layer-a/                            # Python behavioral models
|   |-- units/
|   |   |-- dispatch_scorer.py          # U1
|   |   |-- skill_router.py             # U2
|   |   |-- cache_controller.py         # U3
|   |   |-- batch_scheduler.py          # U4
|   |   |-- speculative_prefetcher.py   # U5
|   |   |-- coherence_unit.py           # U6
|   |   +-- systolic_array.py           # U7 (simplified model)
|   |-- orchestrator.py                 # Wires U1-U7 together
|   |-- trace_replayer.py               # Feeds traces through pipeline
|   |-- metrics.py                      # Composite score calculator
|   +-- tests/
|       |-- test_units.py               # Per-unit validation
|       +-- test_end_to_end.py          # Full pipeline with traces
|
|-- layer-b/                            # Chisel RTL
|   |-- src/main/scala/orchid/
|   |   |-- DispatchScorer.scala        # U1
|   |   |-- SkillRouter.scala           # U2
|   |   |-- CacheController.scala       # U3
|   |   |-- BatchScheduler.scala        # U4
|   |   |-- SpeculativePrefetcher.scala # U5
|   |   |-- CoherenceUnit.scala         # U6
|   |   |-- OrchidAccelerator.scala     # Top-level RoCC accelerator
|   |   +-- OrchidConfig.scala          # Parameterization
|   |-- src/test/scala/orchid/          # Chisel unit tests
|   +-- build.sbt
|
|-- layer-c/                            # Chipyard SoC integration
|   |-- OrchidChipConfig.scala          # Rocket + Orchid + Gemmini composition
|   |-- firesim/                        # FireSim target configs
|   +-- README.md                       # Layer C setup instructions
|
|-- cosim/                              # Co-simulation bridge
|   |-- cocotb_tests/                   # Same tests run against Layer A and B
|   |   |-- test_dispatch_scorer.py
|   |   |-- test_skill_router.py
|   |   +-- test_pipeline.py
|   +-- compare.py                      # A vs B output diff checker
|
|-- traces/
|   |-- real/                           # Captured from live pm-workflow
|   |   +-- .gitkeep
|   |-- synthetic/
|   |   |-- burst_haiku.jsonl
|   |   |-- contention_opus.jsonl
|   |   |-- alternating_chains.jsonl
|   |   |-- random_uniform.jsonl
|   |   +-- cold_to_warm.jsonl
|   +-- schema.json                     # Trace format definition
|
+-- results/                            # Benchmark outputs
    |-- layer_a/
    |-- layer_b/
    +-- comparison/                     # A vs B vs C scorecards
```

**Key design principle:** the `cosim/` directory is the glue. Every test in `cocotb_tests/` runs against both the Python model (Layer A) and the Chisel RTL (Layer B). If outputs diverge, the promotion is invalid. This is the co-simulation contract — Layer B must be behaviorally identical to Layer A before a unit graduates.

---

## Section 6: Parameterization — What's Configurable

Orchid is a **generator**, not a fixed design. Like Gemmini generates different systolic arrays from parameters, Orchid generates different orchestration accelerators.

```scala
// OrchidConfig.scala — the knobs
case class OrchidConfig(
  // U1: Dispatch Scorer
  scoreBits: Int = 7,              // 0-100 score range -> 7 bits
  tierCount: Int = 3,              // haiku/sonnet/opus

  // U2: Skill Router
  maxSkills: Int = 16,             // ROM depth (how many skills exist)
  maxPhases: Int = 10,             // Number of PM phases
  maxLoadPerPhase: Int = 3,        // Max skills loaded per phase

  // U3: Cache Controller
  cacheEntries: Int = 15,          // Matches framework's 15 cache entries
  compressedViewBytes: Int = 512,  // ~200 words compressed
  fullEntryBytes: Int = 4096,      // Full cache entry
  scratchpadKB: Int = 64,          // On-chip SRAM

  // U4: Batch Scheduler
  maxConcurrentTasks: Int = 8,     // Parallel agent slots
  queueDepth: Int = 32,            // Pending task buffer

  // U5: Speculative Prefetcher
  predictionTableEntries: Int = 64,// Phase transition history
  prefetchAhead: Int = 2,          // How many skills to prefetch

  // U6: Coherence Unit
  maxWriters: Int = 8,             // Max concurrent writers
  snapshotSlots: Int = 4,          // Rollback buffer depth

  // U7: Systolic Array (passed to Gemmini)
  meshRows: Int = 8,
  meshCols: Int = 8,
  dataWidth: Int = 16              // FP16 for inference
)
```

**Design space exploration:** Want to know if doubling the cache scratchpad improves hit rates more than doubling the prediction table? Change two numbers, re-run traces, compare composite scores. Architecture research at the speed of configuration.

---

## Section 7: Validation Strategy — Proving Orchid Works

### Level 1 — Unit Correctness (per unit, Layer A<->B)

| Unit | Correctness Test | Pass Criteria |
|---|---|---|
| U1: Dispatch Scorer | Feed 1000 task descriptors, compare output to v5.2 `dispatch-intelligence.json` rules | 100% match — scoring is deterministic |
| U2: Skill Router | Feed all (score, phase) pairs, compare to `skill-routing.json` | 100% match — routing is a lookup |
| U3: Cache Controller | Replay real cache access patterns, compare hit/miss sequence | Hit rate within 1% of Python model |
| U4: Batch Scheduler | Feed N tasks with mixed tiers, verify grouping and wave timing | Identical grouping, wave order may differ (valid reordering) |
| U5: Prefetcher | Replay 500 phase transitions, measure prediction accuracy | >=70% accuracy (framework measured ~75-80% phase predictability) |
| U6: Coherence | Simulate 8 concurrent writers to same entry, verify no data corruption | Zero corruption across 10,000 random conflict scenarios |

### Level 2 — Pipeline Integration (Layer B, units wired together)

| Test | What It Proves | Pass Criteria |
|---|---|---|
| U1->U2 forwarding | Score flows to router in 1 cycle via TileLink, no serialization | Total latency = U1 cycles + U2 cycles (no overhead) |
| U1->U2->U3->U4 chain | Full dispatch pipeline end-to-end | Composite latency < sum of individual latencies (pipelining works) |
| U5 prefetch + U3 hit | Prefetcher loads cache entry before U3 needs it | Cache hit rate increase >=15% over no-prefetch baseline |
| U6 under contention | 4 writers + coherence unit active during pipeline execution | Pipeline throughput degrades <=20% under max contention |

### Level 3 — System Validation (Layer C, full SoC)

| Test | What It Proves | Pass Criteria |
|---|---|---|
| Real trace replay | Orchid SoC processes actual pm-workflow dispatch history | Composite score > 1.0x baseline (any speedup = success) |
| Synthetic burst | 100 haiku tasks in 1us burst | All dispatched within 10us (throughput validation) |
| Cold->warm transition | Empty cache -> steady state workload | Warm steady-state composite score >=5x cold start score |
| Gemmini integration | Dispatch pipeline feeds inference to systolic array | End-to-end latency: dispatch + inference < inference-only + software dispatch |

**The ultimate validation question:** Given a real trace of 100 dispatch decisions that took the software framework ~2 minutes of LLM inference time, how fast does Orchid produce the same 100 decisions? The target isn't "faster than an LLM" (trivially true for hardware logic) — it's "fast enough that orchestration overhead becomes negligible compared to the actual AI work."

---

## Section 8: What Orchid Is NOT

| Orchid IS | Orchid IS NOT |
|---|---|
| An orchestration accelerator — speeds up dispatch decisions | A general-purpose AI chip — doesn't replace GPUs for training |
| A research vehicle — validates framework->hardware mapping | A product — no intention to fabricate or sell |
| Cloud-emulated — runs on standard infrastructure | Physical silicon — no tapeout, no foundry |
| RISC-V + open source — fully reproducible | Proprietary — no locked IP, no NDAs |
| A framework companion — makes the PM workflow faster | A framework replacement — the workflow stays in software |
| Parameterizable — explores design space via config | Fixed — every parameter is a knob to turn |

**Relationship to HADF:** Orchid and HADF are complementary research threads. HADF asks "how should the framework adapt to whatever hardware it runs on?" Orchid asks "what if we designed hardware specifically for the framework?" If both succeed, the convergence point is an Orchid chip that is HADF-aware — hardware that adapts its own parameters based on runtime telemetry. That's a v2 ambition, not a v1 goal.

---

## Section 9: The Origin Story — Why Orchid Exists

**The timeline:**

```
v1.0 (Apr 2)    Serial PM workflow              = single-issue in-order CPU
     |
v2.0 (Apr 7)    Hub-and-spoke, 11 skills        = pipelined processor
     |
v3.0 (Apr 9)    Parallel dispatch, v2 audit      = superscalar execution
     |
v4.0-4.4        Reactive mesh, adapters, eval    = out-of-order + branch prediction
     |
v5.0 (Apr 14)   SoC-on-Software: chip->software = "what if software learned from chips?"
     |                                             7 principles, 54K tokens reclaimed
v5.1 (Apr 14)   All 8 SoC items shipped          = heterogeneous multi-core
     |
v5.2 (Apr 16)   Dispatch intelligence + safety   = hardware scheduler + coherence
     |
HADF (Apr 16)   Hardware-aware dispatch           = self-aware adaptive hardware
     |
     v
ORCHID           software->chip: close the loop   = "what if we built the chip
                                                     the software is already emulating?"
```

**The insight that makes Orchid non-obvious:** Most AI accelerators start from the workload (matrix multiply, attention, convolution) and design hardware to speed up those operations. Orchid starts from the *orchestration layer* — the decision-making that determines which workload runs where, when, and how. No one has built hardware for this because, until multi-agent AI frameworks matured, the orchestration layer was trivial (a scheduler, a queue). Our framework proved it's not trivial — it has its own complexity scoring, speculative execution, cache hierarchy, and coherence protocol. Those are hardware concepts running in software. Orchid gives them back to hardware.

---

## Open-Source Building Blocks

| Component | Project | License | Role in Orchid |
|---|---|---|---|
| Host core | Rocket Chip | Apache 2.0 | RISC-V core running framework software |
| Accelerator interface | RoCC | Apache 2.0 | Attaches U1-U6 to Rocket pipeline |
| Systolic array (U7) | Gemmini | Apache 2.0 | ML inference engine |
| SoC framework | Chipyard | Apache 2.0 | Composes all units into single chip |
| Cloud FPGA sim | FireSim | BSD 3-Clause | Layer C near-real-time validation |
| RTL simulation | Verilator | LGPL | Layer B cycle-accurate simulation |
| Co-simulation | cocotb | BSD 2-Clause | Python<->RTL test bridge |
| Bus protocol | TileLink | Apache 2.0 | On-chip interconnect / result forwarding |

## Framework-to-Hardware Mapping (Complete)

| Framework (v5.0-v5.2) | Hardware Principle (v5.0 origin) | Orchid Unit |
|---|---|---|
| Skill-on-demand loading | LoRA hot-swap | U2 (Skill Router) |
| Cache compression (compressed_view) | 3.7-bit palettization | U3 (Cache Controller) |
| Batch dispatch | TPU weight-stationary dataflow | U4 (Batch Scheduler) |
| Result forwarding | UMA zero-copy | TileLink interconnect |
| Model tiering (haiku/sonnet/opus) | ANE mixed-precision | U1 (Dispatch Scorer) tier output |
| Speculative preload | Branch prediction | U5 (Speculative Prefetcher) |
| Systolic chain protocol | TPU systolic array | U7 (Gemmini) |
| Task complexity gate | big.LITTLE dispatch | U1 (Dispatch Scorer) + U4 routing |
| Dispatch intelligence (v5.2) | CPU scheduler / decode | U1 + U2 pipeline |
| Parallel write safety (v5.2) | Cache coherence (MESI) | U6 (Coherence Unit) |

---

## Section 10: v6.0/v6.1 Integration — Framework Measurement as Hardware Data Source

> Added 2026-04-16 after v6.0 (measurement instrumentation) and v6.1 (meta-analysis audit) shipped.

### 10.1 The Key Insight

v6.0 solved Orchid's data problem before Orchid was designed. The deterministic instrumentation (phase timing, cache L1/L2/L3 counters, CU v2 continuous factors, serial/parallel decomposition) produces exactly the trace data Orchid needs for validation — no separate logging infrastructure required.

### 10.2 Trace Format Unification

v6.0's `state.json` timing and `cache-hits.json` already capture Orchid-compatible events. A thin converter produces the `.jsonl` trace format:

```
v6.0 Source                              Orchid Trace Field
-----------                              ------------------
timing.phases[phase].started_at     ->   timestamp_ns
timing.phases[phase].duration_min   ->   decision.latency_ms
timing.parallel_context             ->   concurrent feature count
timing.sessions[]                   ->   multi-session replay
cache-hits.json hits[]              ->   cache access sequence
cache-hits.json misses[].reason     ->   miss classification
complexity.view_count               ->   task.view_count
complexity.new_types_count          ->   task.new_types
complexity.is_first_of_kind         ->   task.novelty_flag
```

Every feature run from v6.0 onward automatically produces an Orchid benchmark trace.

### 10.3 U1 Input Bus — CU v2 Continuous Factors

v6.0 replaced binary CU flags with continuous signals. These define U1's input wires:

```
CU v2 Factor                  U1 Input Wire          Bit Width
----------------------------  ---------------------  ---------
view_count (0-10+)            task.view_count        4 bits
new_types_count (0-10+)       task.new_types         4 bits
design_iteration_scope        task.scope_tier         2 bits (4 tiers: text/layout/interaction/full)
is_first_of_kind              task.novelty_flag       1 bit
work_type                     task.work_type          2 bits (feature/enhancement/fix/chore)
```

U1 implements the CU v2 formula in combinational hardware. Total input bus width: 13 bits. Output: 7-bit score + 2-bit tier.

### 10.4 U3 Scratchpad Recalibration

v6.0 measured actual framework token overhead at 79,138 tokens (7.91% of 1M context). The original SoC research estimated 96K.

- Original `scratchpadKB: 64` was sized for 96K
- Actual need: ~79K tokens -> 49KB sufficient at 1 byte/token
- Updated design: **48KB scratchpad + 16KB prefetch staging area** (U5 staging)
- OrchidConfig default changes: `scratchpadKB: 48`, new field `prefetchStagingKB: 16`

### 10.5 U4 Validation — Serial Velocity Plateau

v6.0 discovered that serial velocity plateaus at ~4-5 min/CU. Parallelism is the only path to further improvement. This validates U4's architectural importance:

- U4 baseline test: single-task serial throughput must match measured ~4-5 min/CU equivalent
- U4 target: with batch scheduling, break through the plateau via concurrent dispatch
- v6.0's `parallel_speedup_factor` is the exact metric U4 must reproduce

### 10.6 U5 Training — Real Cache Access Patterns

v6.0's `cache-hits.json` provides real L1/L2/L3 access sequences with miss reasons:

| Miss Reason | Prefetcher Action | Hardware Implication |
|---|---|---|
| `no_entry` | Cannot prefetch what doesn't exist | Prefetcher skips, no penalty |
| `stale` (SHA256 mismatch) | Prefetch but mark for revalidation | Prefetch + dirty flag |
| `wrong_context` | Context-aware prefetch needed | Extended prediction table with context bits |

This data trains U5's prediction table with real-world accuracy — not synthetic estimates.

### 10.7 Validation Taxonomy — v6.1 Trust Tags

Orchid adopts v6.1's 5-tier validation taxonomy for all test results:

| Tag | Orchid Application | Trust Level |
|---|---|---|
| `external-automated` | Verilator cycle count, FireSim measurement | Highest |
| `external-manual` | Manual trace comparison | High |
| `external-git` | Git-timestamp-verified traces | High |
| `cross-referenced` | Layer A/B co-simulation match | Medium |
| `framework-only` | Python model self-test | Lowest |

Every Orchid validation result is tagged. The final case study reports the distribution so readers calibrate trust.

### 10.8 Future Extension — Audit Accelerator Mode

v6.1's 4-layer audit architecture (Surface Sweep -> Deep Dive -> Cross-Reference -> External Validation) maps to a second operating mode for Orchid:

```
Finding arrives -> U1 scores (severity x effort x bias_risk)
               -> U2 routes to agent type (UI/backend/AI/design/test/framework)
               -> U4 batches by severity tier (critical first)
               -> U6 prevents duplicate-finding conflicts
               -> U7 runs AI-powered deep analysis on flagged code
```

This is a v2 ambition — Orchid v1 focuses on dispatch acceleration. But the v6.1 finding schema (`severity`, `effort`, `bias_risk`, `confidence`) fits U1's scoring interface so naturally that the extension is architecturally free.

### 10.9 Updated OrchidConfig Defaults

```scala
case class OrchidConfig(
  // U1: Dispatch Scorer — updated for CU v2
  scoreBits: Int = 7,
  tierCount: Int = 3,
  inputBusWidth: Int = 13,          // NEW: CU v2 factors (was implicit)
  workTypes: Int = 4,               // NEW: feature/enhancement/fix/chore

  // U3: Cache Controller — recalibrated by v6.0 measurement
  cacheEntries: Int = 15,
  compressedViewBytes: Int = 512,
  fullEntryBytes: Int = 4096,
  scratchpadKB: Int = 48,           // CHANGED: was 64, calibrated by 79K token measurement
  prefetchStagingKB: Int = 16,      // NEW: U5 staging area from scratchpad surplus

  // U5: Speculative Prefetcher — enhanced by cache-hits.json
  predictionTableEntries: Int = 64,
  prefetchAhead: Int = 2,
  contextBitsPerEntry: Int = 4,     // NEW: context-aware prefetch (miss_reason: wrong_context)

  // ... remaining parameters unchanged
)
```

### 10.10 Framework Version Coverage

| Framework Version | Orchid Data Source | Quality |
|---|---|---|
| v2.0-v4.4 | Case study narratives only | Low — estimated, no counters |
| v5.0-v5.2 | Case studies + config files | Medium — structured but not instrumented |
| v6.0+ | state.json timing + cache-hits.json + CU v2 | High — deterministic, counter-based |
| v6.1+ | Above + audit findings + validation tags | Highest — externally validated |

Orchid's primary validation uses v6.0+ traces. Pre-v6.0 data serves as historical context only.
