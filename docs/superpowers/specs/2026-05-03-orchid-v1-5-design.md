---
title: ORCHID v1.5 — Design Spec Addendum
date: 2026-05-03
type: spec
status: draft_for_review
framework_version: v7.7
predecessor_spec: docs/superpowers/specs/2026-04-16-orchid-ai-accelerator-design.md
predecessor_research:
  - docs/research/2026-04-28-orchid-framework-v7-mapping.md
  - docs/research/2026-05-01-modular-chip-architecture-survey.md
  - docs/research/2026-05-01-chip-security-zero-day-survey.md
  - docs/research/2026-04-28-hadf-signature-expansion.md
implements_recommendation: research/2026-04-28-orchid-framework-v7-mapping.md §8 Option B + §10
v2_decision: deferred until Layer B Phase 2 (U1+U2 Chisel) yields cycle-time data
---

# ORCHID v1.5 — Design Spec Addendum

## 0. One-line summary

**v1.5 is an additive, ABI-stable extension of ORCHID v1 that lands four primitives — U8 Patrol Scrubber, U9 Validation Bus, T1/T2/T3 tier propagation, and a per-unit `assertion_mode` register — plus the forward-compatibility CSR scaffolding (versioned headers, reserved opcode/CSR ranges, capability bitmap) that lets v2.0 grow without breaking v1.5 software. Phases 2–5 of the original Layer B/C plan are unchanged; v1.5 adds Phase 6 (U8), Phase 7 (U9), and Phase 8 (tier propagation) on top.**

## 1. Why v1.5 instead of v2.0

The 2026-04-28 v2 mapping research enumerated two paths (§8):

- **Option A — full v2 rewrite.** Add U8+U9, change `OrchidConfig` schema, write a new spec, write 4 new plans. Estimated 3–4 weeks of doc work before any RTL. Risks abandoning the ready-to-execute Phase 2–5 plans.
- **Option B — v1.5 incremental.** Keep the v1 7-unit core, extend `OrchidConfig` additively, add U8 (P0) and U9 (P0/P1 split), reserve all v2.0 expansion surfaces. Estimated 1 week of spec + 1 plan.

Option B is correct because:

1. Phases 2–5 of the original plan are already written and ready. Forking to v2 stalls Layer B before any RTL exists.
2. The P0 changes in v1.5 (U8, tier propagation, U3 PMU exposure) are **additive** — they don't touch U1–U7's existing CSR or opcode allocation, so Phase 2–5 RTL can proceed in parallel with v1.5 spec writing.
3. The P1 changes deferred to v2.0 (full pre-commit gating fast path, multi-Orchid scaling, TL-C cache coherence) genuinely benefit from real Layer B cycle-time numbers. Guessing their cost without measurement is the failure mode v6.0 measurement infrastructure was built to prevent.

The 2026-05-01 modular chip architecture survey (§9.4) reinforces this with three concrete forward-compatibility patterns that cost nothing in area but are **catastrophically expensive** to retrofit: versioned CSR headers, reserved address ranges, and a capability bitmap. v1.5 lands all three.

## 2. New units

### 2.1 U8 — Patrol Scrubber

**Origin:** v7.1 72h Integrity Cycle. Software equivalent reads every state.json on a wall-clock interval and reports findings. The silicon analogue is a hardware patrol unit that walks on-chip state at a configurable cadence and raises a status event on detected drift.

**Function:** Periodically (configurable interval via `u8_patrol_period` CSR, default = 2^24 cycles ≈ 84 ms at 200 MHz) U8 walks:

- U2 Skill Router LUT entries → verifies parity bit per entry
- U3 Cache Controller scratchpad metadata → verifies tier-bit consistency vs PMU snapshot
- U4 Batch Scheduler FIFO depths → verifies invariant `head ≤ tail ≤ depth`
- U6 Coherence Unit MESI state vector → verifies invariant `(M ⊕ S) ⊃ valid`

For each violation, U8 emits a `validation_event` to U9 (§2.2) with `{unit_id, error_code, observed_value, expected_value}`.

**Architecture:**

```
U8 Patrol Scrubber
├── Period counter (24-bit free-running, configurable)
├── Walk FSM (Idle → WalkU2 → WalkU3 → WalkU4 → WalkU6 → Idle)
├── Per-target invariant check engine (combinational ROM of expected predicates)
├── Validation event emitter (1-cycle handshake to U9)
└── CSRs:
    ├── u8_patrol_period      (RW, 24-bit)  default 0x1000000
    ├── u8_patrol_enabled     (RW, 1-bit)   default 1
    ├── u8_violations_total   (RO, 32-bit)  free-running counter
    ├── u8_last_violation     (RO, 32-bit)  {unit_id[3:0], error_code[7:0], value[19:0]}
    └── u8_assertion_mode     (RW, 4-bit)   see §5
```

**Cost estimate:** ~1500 flip-flops + ~500 LUTs of combinational invariant logic. Estimated <1.5% of total v1 area. Single-cycle handshake to U9; no impact on dispatch fast path.

**Open question (carried from v2 mapping research §9.1):** Should U8 walk DRAM-backed state? Recommendation: **no, on-chip only for v1.5**. DRAM walking at the same cadence would add measurable bus pressure. Revisit in v2.0 if observation justifies the cost.

### 2.2 U9 — Validation Bus

**Origin:** v7.5 Data Integrity Framework "8 cooperating defenses" + v7.7 advisory/mandatory split. Software equivalent is a multi-defender system where each defender reports findings into a central audit log. The silicon analogue is a dedicated bus carrying validation events from every unit, with two channels: **mandatory** (raises a trap on receipt) and **advisory** (counts and logs; no trap).

**Function:** Receives `validation_event` messages from U1–U8. Each event carries:

- `unit_id` (4-bit) — emitter
- `error_code` (8-bit) — see Appendix A
- `severity` (2-bit) — `00` advisory only, `01` log+counter, `10` log+trap, `11` reserved
- `is_advisory` (1-bit) — channel selector (overrides `severity` for testing)
- `payload` (32-bit) — error-specific (observed value, expected, etc.)

**Architecture:**

```
U9 Validation Bus
├── Mandatory channel (parallel wires, P0)
│   ├── 8 source endpoints (one per unit U1–U8)
│   ├── Round-robin arbiter (1-cycle window)
│   ├── Trap injector → CSR mtval mirror + interrupt to RoCC
│   └── Per-source counter (RO CSR per unit)
├── Advisory channel (shared bus + 1-bit tag, P0)
│   ├── Same 8 source endpoints (multiplexed)
│   ├── Tagged with is_advisory=1
│   ├── Counter increment only; no trap
│   └── Per-source/per-error counters (RO CSR matrix)
├── Validation log buffer (P1, 256-entry circular, optional)
│   └── Enables capture mode for software replay
└── CSRs:
    ├── u9_mandatory_count_uN     (RO, 16-bit)  per-unit mandatory event count
    ├── u9_advisory_count_uN_eN   (RO, 16-bit)  per-unit-per-error advisory count
    ├── u9_log_buffer_head        (RW, 8-bit)   buffer write pointer (P1)
    ├── u9_log_buffer_tail        (RW, 8-bit)   buffer read pointer (P1)
    ├── u9_capture_enabled        (RW, 1-bit)   default 0 (P1)
    └── u9_assertion_mode         (RW, 4-bit)   see §5 — applies to ALL channels
```

**P0 vs P1 split:** v1.5 P0 ships mandatory + advisory channels and per-source counters. The 256-entry log buffer (P1) is reserved in spec but deferred to a v1.5.1 RTL revision once Phase 7 RTL gives a real area number for the buffer. v1.5.0 software can feature-detect via the capability bitmap (§6).

**Cost estimate:** ~2000 flip-flops for P0 channels and counters. ~3000 additional flip-flops for the P1 log buffer. Total <2.5% of v1 area at full P1 build.

**Tradeoff with v2 mapping research §9 question 3:** The research asked whether advisory channel deserves separate physical wires. v1.5 answer: **shared bus with `is_advisory` tag** — saves ~600 routing tracks; profiling on Phase 7 RTL determines whether v1.5.1 splits them.

## 3. Tier propagation (T1/T2/T3)

**Origin:** v7.5 T1/T2/T3 data quality tiers. Every quantitative metric in the framework now carries a tier tag. The silicon analogue is widening the result-forwarding bus to carry the tier of each in-flight value.

**Wire-level change:** TileLink `user[1:0]` is allocated to tier:

| `user[1:0]` | Tier | Meaning |
|---|---|---|
| `00` | (reserved — must-be-zero on transmit, ignore on receive) |
| `01` | T1 | Instrumented (high confidence) |
| `10` | T2 | Declared (medium confidence) |
| `11` | T3 | Narrative (low confidence) |

**Per-unit semantics:**

- **U1 Dispatch Scorer** consumes `min_tier_required` from its CSR (`u1_min_tier`). Inputs with tier below the threshold raise a `LOW_TIER_INPUT` advisory event on U9.
- **U3 Cache Controller** stores `tier` per scratchpad entry. Tier-3 entries are evicted first when capacity pressure hits. Tier propagation goes from input → scratchpad → output via a 2-bit metadata field per entry.
- **U4 Batch Scheduler** can prioritize T1 batches via `u4_tier_priority` CSR (P1 — disabled by default in v1.5).
- **U7 Systolic Array** preserves the tier of the lowest-tier input on output (worst-case propagation). Mixed-tier inputs produce T3 output.

**Reserved bits:** `user[7:2]` are reserved-zero in v1.5. v2.0 may allocate these for additional metadata (provenance signatures, security domains, etc.) without renegotiating with v1.5 software.

**ABI guarantee:** v1.5 software writing `user[1:0]` correctly will continue to interoperate with v2.0+ Orchid. v2.0 software writing `user[7:2]` runs on v1.5 hardware as if those bits were zero (per the must-be-zero-on-transmit-ignore-on-receive rule documented in modular survey §9.1).

## 4. U3 PMU exposure

**Origin:** v7.7 `cache_hits[]` writer-path observable + v7.8 PR-1 Mechanism C auto-instrumentation. Software equivalent is the `.claude/logs/_session-*.events.jsonl` ledger written by `scripts/observe-cache-hit.py`. The silicon analogue is exposing U3's pre-existing performance counters as software-readable CSRs.

**New CSRs in U3:**

| CSR | Width | Type | Meaning |
|---|---|---|---|
| `u3_pmu_cache_hits_total` | 32 | RO | Cumulative L1 scratchpad hits since reset |
| `u3_pmu_cache_misses_total` | 32 | RO | Cumulative L1 scratchpad misses |
| `u3_pmu_evictions_total` | 32 | RO | Cumulative scratchpad evictions |
| `u3_pmu_tier_distribution` | 32 | RO | `{T1_count[10:0], T2_count[10:0], T3_count[9:0]}` |
| `u3_pmu_compression_ratio` | 16 | RO | Fixed-point Q4.12 average compression ratio |
| `u3_pmu_select` | 4 | RW | PMU event selector — see Appendix B |
| `u3_pmu_count` | 32 | RO | Selected event count |
| `u3_pmu_overflow` | 1 | RO | Sticky overflow flag for selected counter |
| `u3_pmu_reset` | 1 | WO | Write-1-to-clear all U3 PMU counters |

The `u3_pmu_select` register lets software cycle through 16 events without dedicating separate CSRs to each. The five "fast" CSRs (cache_hits, misses, evictions, tier_dist, compression) are always exposed because they correspond to the framework's gated metrics.

**Reserved range:** the v1.5 PMU CSRs occupy CSR addresses `0xBC0`–`0xBCF` (16 entries). Addresses `0xBD0`–`0xBFF` (48 entries) are reserved for v2.0 PMU additions per modular survey §9.2.

**Cost estimate:** ~200 flip-flops (most counters already existed in v1; v1.5 just exposes them via CSR mux). <0.1% area.

## 5. `assertion_mode` register convention

**Origin:** v7.6 Class B → Class A promotion + v7.7 advisory permanent (TIER_TAG_LIKELY_INCORRECT). Software equivalent is the `mode` field on each pre-commit gate that lets a check ship in advisory before flipping to enforced. The silicon analogue is a per-unit register that lets ops promote silent counters to traps without RTL change.

**Convention:** every unit U1–U9 exposes a 4-bit `uN_assertion_mode` CSR with the encoding:

| Bits | Mode | Behavior on validation event |
|---|---|---|
| `0000` | OFF | No-op. Counter doesn't increment. (Test/burn-in only) |
| `0001` | LOG | Counter increments. No trap. |
| `0010` | LOG_FATAL | Counter increments. Raises trap on receipt. |
| `0011` | LOG_STICKY | Counter increments + sticky bit set. No trap, but software can poll. |
| `0100`–`1111` | reserved | v1.5 must read zero. v2.0 may allocate. |

**Default:** `LOG` (0b0001) on reset. Software can promote to `LOG_FATAL` (0b0010) once the unit's advisory data shows the rule is calibrated — exactly mirrors the framework's v7.6 advisory→enforced flip pattern.

**ABI promise:** the encoding `0000`–`0011` is locked from v1.5 onward. Future modes use bits `0100` and above. Software reading bit positions `[1:0]` always gets a meaningful answer (in particular, "is this mode advisory?" = `mode != LOG_FATAL`).

## 6. Version + capabilities CSR header (forward-compat)

**Origin:** modular survey §9.3 (three-tier versioning) + §9.4 Change 1 (versioned CSR header) + Change 3 (orchid_capabilities discovery register).

**Per-unit CSR header (4 CSRs, mandatory on every unit):**

| CSR offset | Width | Type | Meaning |
|---|---|---|---|
| `+0` | 8 | RO | `unit_id` (1=U1, 2=U2, …, 9=U9; high 8 bits reserved) |
| `+1` | 8 | RO | `iface_major` (= 1 in v1.5) |
| `+2` | 8 | RO | `iface_minor` (= 5 in v1.5; later = 6 for v1.6, etc.) |
| `+3` | 64 | RO | `unit_capabilities` bitmap (per-unit feature flags — see Appendix C) |

Software walks every unit, queries the header, and builds a feature map without firmware changes when a v2.0 unit (U10, U11) is added.

**Top-level Orchid CSRs (in addition to per-unit headers):**

| CSR | Width | Type | Meaning |
|---|---|---|---|
| `orchid_iface_major` | 8 | RO | Breaking-version (= 1 in v1.x) |
| `orchid_iface_minor` | 8 | RO | Additive-version (= 5 in v1.5) |
| `orchid_impl_rev` | 16 | RO | Implementation rev — micro-arch revisions |
| `orchid_capabilities` | 64 | RO | Top-level feature bitmap (Appendix C) |

These are the Orchid equivalent of RISC-V's `mvendorid` / `marchid` / `mimpid` / `misa` quartet.

**Cost:** 4 CSRs/unit × 9 units = 36 CSRs (~1000 flip-flops total) + 4 top-level CSRs (~96 flip-flops). Total <0.5% area.

## 7. Reserved opcode and CSR address ranges

Per modular survey §9.4 Change 2, v1.5 reserves expansion surfaces in spec but does not use them.

### 7.1 RoCC opcode allocation

| RoCC `custom-N` | Status in v1.5 |
|---|---|
| `custom-0` `funct7[6:4]` = `000`–`011` | **Used by v1.5** (8 v1 dispatch opcodes) |
| `custom-0` `funct7[6:4]` = `100`–`111` | **Reserved for v1.6+** (must read as illegal-instruction in v1.5) |
| `custom-1` | **Reserved for v2.0** unit families |
| `custom-2` | **Reserved for v2.0** unit families |
| `custom-3` | **Reserved for v2.0** unit families |

### 7.2 CSR address space

| Range | Status in v1.5 |
|---|---|
| `0xBC0`–`0xBCF` | U3 PMU CSRs (this spec, §4) |
| `0xBD0`–`0xBDF` | Per-unit assertion_mode CSRs (this spec, §5) |
| `0xBE0`–`0xBEF` | U8/U9 control + status CSRs (§2) |
| `0xBF0`–`0xBFF` | Top-level Orchid CSRs (orchid_iface_major/minor/impl_rev/capabilities, §6) |
| `0xC00`–`0xCFF` | **Reserved for v2.0** — must read as zero in v1.5 |
| `0xD00`–`0xDFF` | **Reserved for v2.0+** PMU additions |

### 7.3 TileLink `user` field

| Bits | Status in v1.5 |
|---|---|
| `user[1:0]` | Tier propagation (§3) |
| `user[7:2]` | **Reserved-zero** in v1.5; v2.0 may allocate (provenance, security domain, etc.) |

**Rule:** v1.5 hardware MUST reject (raise illegal-CSR / illegal-instruction trap) any access to a reserved range. This prevents v2.0-targeting software from running silently on v1.5 hardware and getting wrong answers — it gets a trap, queries the capability bitmap, and falls back gracefully.

## 8. Per-unit security hardening

The 2026-05-01 chip-level zero-day attack survey (Part B) enumerated per-unit attack surfaces and hardening recommendations. v1.5 lands the **P0** items (high-severity / low-cost). P1 items are noted as v2.0 candidates.

### U1 — Dispatch Scorer
- **P0:** Constant-time scoring path — eliminate data-dependent timing on the critical-path comparator (zero-day survey §A.1 — Spectre-style transient execution leakage).
- **P0:** `LOW_TIER_INPUT` validation event already in §3 doubles as a tier-spoofing detector.
- **P1 (v2.0):** Pre-commit phase with cu_v2 protocol verification (deferred per v2 mapping research §8 P1 list).

### U2 — Skill Router
- **P0:** Parity bit per LUT entry — protects against bit-flip injection (zero-day survey §A.5 Rowhammer family). U8 patrol checks parity (§2.1).
- **P0:** All LUT reads constant-cycle; no early-exit on miss.

### U3 — Cache Controller
- **P0:** Tier propagation across scratchpad (§3) — partial mitigation for tier confusion.
- **P0:** PMU counters readable but not writable from U-mode (S/M-mode only) — closes the side-channel from §A.2 (cache side-channels) being used as a covert oracle.
- **P1 (v2.0):** Way-partitioned scratchpad to mitigate cross-process side channels. Deferred — single-process Orchid v1.5 doesn't need it.

### U4 — Batch Scheduler
- **P0:** FIFO depth invariant (`head ≤ tail ≤ depth`) checked by U8 (§2.1).
- **P1 (v2.0):** Tier-priority arbitration to prevent T3-flooding starvation. Disabled by default in v1.5 to keep arbitration simple.

### U5 — Speculative Prefetcher
- **P0:** Prediction table flushed on `assertion_mode` change to LOG_FATAL — prevents speculation-residue leakage post-mode-change (zero-day survey §A.3 branch predictor attacks).
- **P0:** Misprediction rate exposed via U3 PMU (`u3_pmu_select = MISPREDICT_RATE`) — observability against poisoned predictions.

### U6 — Coherence Unit
- **P0:** MESI invariant `(M ⊕ S) ⊃ valid` checked by U8 (§2.1).
- **P0:** TileLink endpoint locked at TL-UH (uncached + atomics) — defers TL-C cache-coherence complexity to v2.0 (where multi-Orchid scaling justifies it).

### U7 — Systolic Array
- **P0:** Worst-case tier propagation (§3) — output tier = min(input tiers).
- **P0:** Idle-cycle randomization disabled by default; hooks reserved for v2.0 timing-side-channel mitigation.

### U8 — Patrol Scrubber (new)
- **P0:** Period jitter (±10% on `u8_patrol_period`) to prevent timing oracles. Required, not optional.
- **P0:** Walk-FSM state observable via PMU but not externally controllable.

### U9 — Validation Bus (new)
- **P0:** Validation event payload size capped at 32 bits — prevents amplification DoS via large payloads.
- **P0:** Mandatory-channel arbiter starvation-free (round-robin) — prevents one unit from blocking others' urgent events.

## 9. Updated `OrchidConfig` schema

v1.5 additions are **purely additive**. v1 code that ignores the new keys still works.

```scala
case class OrchidConfig(
  // === v1.0 keys (unchanged, listed for reference) ===
  scoreBits: Int = 7,
  inputBusWidth: Int = 13,           // CU v2: 8-base + 5-factors
  maxSkills: Int = 16,
  cacheEntries: Int = 15,
  scratchpadKB: Int = 48,
  prefetchStagingKB: Int = 16,
  contextBitsPerEntry: Int = 4,
  maxConcurrentTasks: Int = 8,
  predictionTableEntries: Int = 64,  // recommended drop to 16 per DSE
  maxWriters: Int = 8,
  meshRows: Int = 8,
  meshCols: Int = 8,
  dataWidth: Int = 16,

  // === v1.5 additions ===
  // Tier propagation (§3)
  tierBits: Int = 2,                                   // fixed at 2 for T1/T2/T3
  u1MinTierRequired: TierLevel = TierLevel.T3,         // dispatch threshold
  u4TierPriorityEnabled: Boolean = false,              // P1 — disabled in v1.5

  // U8 Patrol Scrubber (§2.1)
  u8PatrolPeriodCycles: Long = 0x1000000L,             // ~84ms at 200MHz
  u8PatrolEnabled: Boolean = true,
  u8PeriodJitterPercent: Int = 10,                     // §8 hardening — required

  // U9 Validation Bus (§2.2)
  u9LogBufferEntries: Int = 0,                         // 0 = P0 (no buffer); 256 = P1
  u9CaptureEnabled: Boolean = false,                   // P1 only

  // Assertion modes (§5) — per-unit defaults
  assertionModes: Map[UnitId, AssertionMode] = Map(
    U1 -> AssertionMode.LOG, U2 -> AssertionMode.LOG, U3 -> AssertionMode.LOG,
    U4 -> AssertionMode.LOG, U5 -> AssertionMode.LOG, U6 -> AssertionMode.LOG,
    U7 -> AssertionMode.LOG, U8 -> AssertionMode.LOG, U9 -> AssertionMode.LOG
  ),

  // Capabilities bitmap (§6) — derived, not user-set
  capabilitiesBitmap: BigInt = OrchidCapabilities.v1_5_default
)
```

`OrchidCapabilities.v1_5_default` is a constant defined in Appendix C.

## 10. Layer A behavioral model additions

The Python-based Layer A simulator (`orchid/layer-a/`) needs three new behavioral modules:

1. **`u8_patrol_scrubber.py`** — period counter + walk FSM + invariant ROM. Generates synthetic violation events for fault-injection tests.
2. **`u9_validation_bus.py`** — event queue + arbiter + counter matrix. Mandatory and advisory channels.
3. **`tier_propagator.py`** — tags every value flowing through the simulator with its tier; enforces worst-case-on-output rule.

Plus a tier-aware trace generator extension to `traces/`:

- Add `tier` column to every trace row (T1/T2/T3 distribution per benchmark).
- Re-run the original 26K-run DSE with tier-aware inputs to validate U1 actually de-rates T3 paths (per v2 mapping research §9 question 4).

**DSE re-run scope:** ~1 day to extend the trace generator + ~2 days of wall-clock for the sweep. Outputs go to `orchid/results/dse-tier-aware-2026-05-XX.csv`.

## 11. Layer B implementation plan delta

The original Phase 2–5 plans are **unchanged**. v1.5 adds:

| Phase | Deliverable | Scope | Estimated cost |
|---|---|---|---|
| **Phase 6** (NEW) | U8 Patrol Scrubber Chisel RTL + verif | Per-unit invariant probes + walk FSM + period counter + handshake to U9 | 1 week RTL + 1 week verif |
| **Phase 7** (NEW) | U9 Validation Bus Chisel RTL + verif (P0 only) | Mandatory + advisory channels + per-source counters; log buffer deferred | 1.5 weeks RTL + 1 week verif |
| **Phase 8** (NEW) | Tier propagation across all units | Widen TileLink, add tier metadata to U3 scratchpad, U7 propagation logic | 2 weeks RTL + 1 week verif |
| **Phase 9** (NEW) | assertion_mode + capabilities CSR plumbing | Mostly mux + flop additions; capability bitmap synthesis | 0.5 week RTL + 0.5 week verif |

Phase 6–9 land *after* Phase 5 (v1.0 SoC integration) is green. If Phase 5 surfaces integration issues that require RTL changes to U1–U7, those changes happen first; Phase 6+ rebases.

## 12. Validation strategy

### Existing levels (carry over from v1)
- **Level 1** — per-unit RTL correctness against Layer A reference (each new unit gets this)
- **Level 2** — pipeline integration (multi-unit dataflow correctness)
- **Level 3** — full SoC validation (Verilator + boot Linux + run pm-workflow trace)

### New: Level 4 — Security validation (v1.5)

Per the chip-level zero-day survey (Part B), each P0 hardening item gets a directed test:

- **L4-T1:** Fault injection at U2 LUT entries → assert U8 `parity_violation` event
- **L4-T2:** Tier-spoofing input on U1 → assert `LOW_TIER_INPUT` advisory on U9
- **L4-T3:** U-mode read of U3 PMU in M-only mode → assert privilege-trap
- **L4-T4:** `u8_patrol_period` set to constant (no jitter) → assert build-time error (period jitter is mandatory)
- **L4-T5:** U9 mandatory-channel saturation from one source → assert other sources still get arbitration

Pass criterion: 100% of L4 directed tests must pass before v1.5 RTL is taggable.

## 13. ABI promise: v1 → v1.5 → v2.0

This section is the **contract** that v1.5 vs v2.0 versioning depends on.

### Immutable from v1.5 onward (any change is a v2.0 *major* bump)

1. RoCC opcode bits `funct7[6:4]` = `000`–`011` continue to mean what they mean in v1.5.
2. CSR addresses `0xBC0`–`0xBFF` continue to mean what they mean in v1.5.
3. TileLink `user[1:0]` is the tier field. Forever.
4. Per-unit CSR header layout (`unit_id`, `iface_major`, `iface_minor`, `unit_capabilities`).
5. `assertion_mode` encoding bits `[1:0]` cover OFF / LOG / LOG_FATAL / LOG_STICKY.
6. U9 mandatory and advisory channel framing (event header + payload format).
7. Capability bitmap bit assignments (Appendix C bits 0..15 for v1.5; bits 16+ are v2.0 land).

### What v2.0 may do
- Allocate `custom-1`, `custom-2`, `custom-3` opcodes.
- Allocate CSR addresses `0xC00`–`0xDFF`.
- Allocate `user[7:2]` TileLink bits.
- Define `assertion_mode` bits `[3:2]` (new modes).
- Define capability bitmap bits `16..63`.
- Add new units U10, U11, etc.
- Re-define implementation-only behavior (micro-arch optimization, pipeline tweaks).

### What v2.0 may NOT do
- Repack any v1.5 bit field.
- Change the meaning of any v1.5 capability bit.
- Reduce the precision of any v1.5 CSR.
- Remove a v1.5 unit from the hardware.

## 14. v2.0 deferred items

Tracked, not addressed in v1.5:

1. **U1 pre-commit fast-path phase** with full cu_v2 protocol verification (research §8 P1).
2. **U9 256-entry log buffer** (P1 of this spec; ships in v1.5.1 once Phase 7 RTL provides area data).
3. **Multi-Orchid NoC** (modular survey §9.5) — chiplet/SoC scale-out.
4. **TL-C cache coherence** (modular survey §9.5) — relevant only when host-CPU coherence is needed.
5. **DRAM patrol scrubbing** (research §9 Q1) — bandwidth tradeoff TBD.
6. **Way-partitioned scratchpad** (security survey U3 P1) — multi-process Orchid requirement.
7. **Tier-aware DSE re-run** (research §9 Q4) — runs in parallel with v1.5 RTL; results inform v2.0 spec but don't block v1.5 RTL.
8. **HADF Layer 4 affinity-map writer with Orchid-PMU source** (research §9 Q5) — cross-coordination follow-up.

## 15. Cross-coordination with HADF expansion

Per v2 mapping research §7 + 2026-04-28 HADF signature expansion note:

- **Tier propagation** (this spec §3) — when HADF adds T1/T2/T3 to its dispatch hints, ORCHID tier bits become the silicon-side enforcement of those hints.
- **PMU exposure** (this spec §4) — when HADF chip profiles include `cache_hits` as a measured input dimension, U3 PMU is the silicon source.
- **Networking primitive on real chips** — Gaudi 3's 24×200 GbE on-package and Jaguar Shores' silicon photonics (per HADF expansion note) hint at multi-Orchid scale-out as a real target. v1.5 deliberately stays single-die; v2.0 reconsiders.

## 16. Next steps

1. **Approve this spec** (Option B confirmation per v2 mapping research §10).
2. **Write the v1.5 implementation plan** at `docs/superpowers/plans/2026-05-XX-orchid-v1-5-additive-units.md` — covers:
   - Layer A behavioral models (§10) — first deliverable
   - Phase 6 / 7 / 8 / 9 schedule (§11)
   - Tier-aware DSE re-run (§10) — runs in parallel with RTL
3. **Open companion case study** at `docs/case-studies/orchid-v1-5-additive-units-case-study.md` — to be filled in as Phases 6–9 ship.
4. **Cross-link** from:
   - Original Orchid case study `docs/case-studies/orchid-ai-accelerator-case-study.md` (add a "v1.5 successor" section).
   - HADF expansion research note `docs/research/2026-04-28-hadf-signature-expansion.md` (add v1.5 reference).
   - Memory page `project_post_hadf_phase2_followup_tracks.md` (Track 3 references this spec).
5. **Schedule the DSE re-run** — Layer A trace generator extension is roughly 1 day; sweep runs ~2 days wall-clock. Can fire as a remote-agent routine the day after this spec is approved.

---

## Appendix A — U9 error code allocation (5-bit field, 32 codes)

| Code | Mnemonic | Source unit | Meaning |
|---|---|---|---|
| 0x00 | RESERVED | — | (must not be used) |
| 0x01 | LOW_TIER_INPUT | U1 | Input tier below `u1_min_tier` |
| 0x02 | DISPATCH_TIMEOUT | U1 | Score not produced within budget |
| 0x03 | LUT_PARITY | U2 | Skill-router LUT parity violation |
| 0x04 | LUT_MISS | U2 | Skill not found in LUT |
| 0x05 | CACHE_TIER_MISMATCH | U3 | Scratchpad tier metadata inconsistent with input tier |
| 0x06 | PMU_OVERFLOW | U3 | Selected counter overflowed |
| 0x07 | FIFO_INVARIANT | U4 | `head > tail` or `tail > depth` |
| 0x08 | TIER_PRIORITY_STARVE | U4 | T1 batch waited > threshold (P1; advisory only) |
| 0x09 | MISPREDICT_BURST | U5 | Mispredict rate exceeded threshold |
| 0x0A | MESI_INVARIANT | U6 | MESI state vector violates invariant |
| 0x0B | TILELINK_USER_NONZERO | U6 | Reserved `user[7:2]` bits non-zero (v1.5) |
| 0x0C | SYSTOLIC_TIER_DOWNGRADE | U7 | Output tier downgraded due to mixed inputs (informational) |
| 0x0D | PATROL_PERIOD_NO_JITTER | U8 | Period configured without jitter — security violation |
| 0x0E | PATROL_VIOLATION | U8 | Patrol scrubber detected invariant break |
| 0x0F | ARBITER_STARVATION | U9 | Mandatory-channel source starved > threshold |
| 0x10–0x1F | RESERVED | — | v2.0+ |

## Appendix B — U3 PMU event selector (`u3_pmu_select`)

| Selector | Event |
|---|---|
| 0x0 | `cache_hits_total` (mirror of dedicated CSR) |
| 0x1 | `cache_misses_total` |
| 0x2 | `evictions_total` |
| 0x3 | `compression_ratio` (Q4.12) |
| 0x4 | `tier_t1_count` |
| 0x5 | `tier_t2_count` |
| 0x6 | `tier_t3_count` |
| 0x7 | `mispredict_rate` (from U5; routed through U3 PMU) |
| 0x8 | `prefetch_useful` (U5 → U3) |
| 0x9 | `prefetch_wasted` (U5 → U3) |
| 0xA | `batch_depth_avg` (U4 → U3) |
| 0xB | `dispatch_score_min` (U1 → U3) |
| 0xC | `dispatch_score_max` (U1 → U3) |
| 0xD | `dispatch_score_avg` (U1 → U3) |
| 0xE–0xF | RESERVED |

## Appendix C — Capability bitmap allocation

64-bit bitmap. Bits `0..15` are v1.5; `16..63` reserved for v2.0+.

| Bit | Capability | v1.5 value |
|---|---|---|
| 0 | U8 Patrol Scrubber present | 1 |
| 1 | U9 Validation Bus mandatory channel present | 1 |
| 2 | U9 Validation Bus advisory channel present | 1 |
| 3 | U9 256-entry log buffer present (P1) | 0 in v1.5.0; 1 in v1.5.1 |
| 4 | Tier propagation enabled (TileLink `user[1:0]`) | 1 |
| 5 | U3 PMU CSRs exposed | 1 |
| 6 | `assertion_mode` per-unit registers present | 1 |
| 7 | Per-unit versioned CSR headers present | 1 |
| 8 | Top-level `orchid_capabilities` register present | 1 |
| 9 | U4 tier-priority arbitration (P1) | 0 in v1.5; 1 if enabled |
| 10 | U8 patrol period jitter enforcement | 1 |
| 11 | U3 PMU privilege gating (M/S only) | 1 |
| 12 | RoCC `custom-0` `funct7[6:4]`=`100`–`111` reserved | 1 |
| 13 | TileLink `user[7:2]` reserved-zero | 1 |
| 14 | CSR address `0xC00`–`0xDFF` reserved | 1 |
| 15 | Tier-aware DSE re-run results published | 0 in v1.5.0; 1 once §10 sweep completes |
| 16–63 | RESERVED for v2.0+ | 0 |

## Appendix D — Framework version → ORCHID v1.5 location

| Framework version | Capability | ORCHID v1 home | ORCHID v1.5 location |
|---|---|---|---|
| v5.0–v6.0 | (all) | unchanged | unchanged |
| v7.1 | 72h integrity cycle | none | **U8 Patrol Scrubber** (§2.1) |
| v7.5 | Cooperating defenses | none | **U9 Validation Bus** (§2.2) |
| v7.5 | T1/T2/T3 data tiers | none | **Tier propagation** (§3, TileLink `user[1:0]`) |
| v7.5 | Cycle-time integrity-cycle baseline | none | U8 patrol period (§2.1) |
| v7.6 | Class B → A mechanical | none | **`assertion_mode` register** (§5) |
| v7.6 | Per-PR pre-commit gate | none | (deferred to v2.0 — research §8 P1) |
| v7.7 | Advisory vs mandatory | none | **U9 dual-channel** (§2.2) |
| v7.7 | `cache_hits[]` PMU | U3 had counters | **U3 PMU CSR exposure** (§4) |
| v7.7 | Tier tag presence check | none | (framework-only — research §6 #3) |
| v7.8 PR-1 | PostToolUse:Read auto-instrumentation | none | Software-side instrumentation feeds U3 PMU (§4); silicon doesn't observe sw hooks directly |

## Appendix E — Out of scope for v1.5

Explicitly **not** addressed by this spec; tracked for v2.0 or beyond.

- Cache coherence with host CPU (TL-C upgrade)
- Multi-Orchid NoC scaling
- Chiplet boundary disaggregation
- DRAM patrol scrubbing
- Way-partitioned scratchpad (multi-process)
- Software ABI above the dispatch layer (runtime/compiler conversation)
- Self-describing ISA (RISC-V Zifencei-style) for Orchid-specific extensions
- Cryptographic accelerator units (zero-day survey "Unique to Orchid" Recommendation 5 — deferred)

---

**End of spec. Status: draft for review. Approval required before writing the v1.5 implementation plan.**
