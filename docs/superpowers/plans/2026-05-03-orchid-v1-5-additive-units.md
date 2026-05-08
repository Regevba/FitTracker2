# Orchid v1.5 — Additive Units Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land the v1.5 additive units (U8 Patrol Scrubber, U9 Validation Bus, tier propagation, U3 PMU exposure, `assertion_mode`, forward-compat CSR scaffolding) without disturbing the v1 Phase 2–5 progression.

**Architecture:** Two parallel tracks. **Track L** (Layer A behavioral models, Python) is independent and can run on the existing Orchid sim repo without blocking RTL work. **Track R** (Layer B RTL Phases 6–9) builds on Phase 5 SoC integration; each Phase is a separate Chisel module + verif suite. **Track D** (DSE re-run) extends the existing trace generator and runs the 26K-run sweep with tier-aware inputs.

**Tech Stack:** Layer A — Python 3.11+, pytest, JSON Lines (matching v1 conventions). Layer B — Chisel 5.x, scalatest, Verilator for sim. DSE — the existing `orchid/results/` infrastructure.

**Spec:** [`docs/superpowers/specs/2026-05-03-orchid-v1-5-design.md`](../specs/2026-05-03-orchid-v1-5-design.md) (Sections 1–16, Appendices A–E)

**Predecessor plans (unchanged):**
- [`docs/superpowers/plans/2026-04-16-orchid-layer-a-phase1.md`](2026-04-16-orchid-layer-a-phase1.md) — Phase 1 shipped
- [`docs/superpowers/plans/2026-04-16-orchid-layer-b-phase2.md`](2026-04-16-orchid-layer-b-phase2.md) — Phase 2 (U1+U2 Chisel)
- [`docs/superpowers/plans/2026-04-16-orchid-layer-b-phase3.md`](2026-04-16-orchid-layer-b-phase3.md) — Phase 3 (U3+U4+U5 Chisel)
- [`docs/superpowers/plans/2026-04-16-orchid-layer-b-phase4.md`](2026-04-16-orchid-layer-b-phase4.md) — Phase 4 (U6 + interconnect)
- [`docs/superpowers/plans/2026-04-16-orchid-layer-c-phase5.md`](2026-04-16-orchid-layer-c-phase5.md) — Phase 5 (Chipyard SoC)

**v1.5 plans (this doc + downstream):** Phase 6–9 RTL. Layer A additions. DSE re-run. Total estimated ~11 weeks calendar-time, parallelizable to ~6 weeks if Layer A and DSE run alongside RTL.

**Out of scope (deferred to v2.0 per spec §14):** U1 pre-commit fast-path, U9 256-entry log buffer, multi-Orchid NoC, TL-C cache coherence, DRAM patrol, way-partitioned scratchpad, HADF Layer 4 affinity-map writer rewrite.

---

## File Map

### Track L — Layer A behavioral models (Python additions to `orchid/layer-a/`)

| File | Responsibility |
|---|---|
| `orchid/layer-a/units/patrol_scrubber.py` | U8: walk FSM + period counter + per-target invariant probes (LUT parity, scratchpad metadata, FIFO invariant, MESI invariant) |
| `orchid/layer-a/units/validation_bus.py` | U9: event queue + mandatory-channel arbiter + advisory-channel counter matrix + (P1) log buffer |
| `orchid/layer-a/units/tier_propagator.py` | Cross-cutting: tag every value with `tier ∈ {T1,T2,T3}`; enforce worst-case-on-output for U7 |
| `orchid/layer-a/units/types.py` | (modified) — add `Tier` enum, `ValidationEvent` dataclass, `AssertionMode` enum |
| `orchid/layer-a/orchestrator.py` | (modified) — wire U8 + U9 in; thread tier through pipeline |
| `orchid/layer-a/trace_replayer.py` | (modified) — read tier column from traces |
| `orchid/layer-a/synthetic_gen.py` | (modified) — emit tier per row (configurable distribution per scenario) |
| `orchid/layer-a/metrics.py` | (modified) — collect U9 event counters into composite-score sub-metrics |
| `orchid/layer-a/tests/test_patrol_scrubber.py` | U8 unit tests (period jitter, invariant probes, fault injection) |
| `orchid/layer-a/tests/test_validation_bus.py` | U9 unit tests (mandatory trap, advisory counting, arbiter starvation) |
| `orchid/layer-a/tests/test_tier_propagator.py` | tier propagation tests (mixed inputs, worst-case-on-output) |

### Track R — Layer B Chisel RTL (each phase is its own subdir under `orchid/layer-b/`)

| Path | Phase |
|---|---|
| `orchid/layer-b/phase6-u8-patrol-scrubber/` | U8 Chisel + verif |
| `orchid/layer-b/phase7-u9-validation-bus/` | U9 Chisel + verif (P0 only) |
| `orchid/layer-b/phase8-tier-propagation/` | TileLink widening + U3 metadata + U7 worst-case logic |
| `orchid/layer-b/phase9-csr-scaffolding/` | assertion_mode + version/capabilities CSRs + reserved-range trap |

### Track D — DSE re-run

| File | Responsibility |
|---|---|
| `orchid/traces/synthetic_gen_tier_aware.py` | Tier-aware trace generator (extends Phase 1 generator) |
| `orchid/results/dse-tier-aware-2026-05-XX/` | DSE output directory (CSV + analysis notebook) |
| `orchid/layer-a/dse_runner.py` | (modified) — accept tier-aware traces |

### Documentation

| File | Responsibility |
|---|---|
| `docs/case-studies/orchid-v1-5-additive-units-case-study.md` | Companion case study, populated as phases ship |

---

## Tasks

Tasks are numbered by track + sequence. Track L is independent of Track R. Tasks within a track are ordered by dependency.

### Track L — Layer A behavioral models

#### L1. Add `Tier` enum + `ValidationEvent` dataclass + `AssertionMode` enum to `types.py`

- [ ] Add `Tier` enum: `T1`, `T2`, `T3` with explicit 2-bit encoding values matching spec §3.
- [ ] Add `ValidationEvent` dataclass: `unit_id`, `error_code`, `severity`, `is_advisory`, `payload` matching spec §2.2.
- [ ] Add `AssertionMode` enum: `OFF`, `LOG`, `LOG_FATAL`, `LOG_STICKY` matching spec §5.
- [ ] Add unit test asserting wire-level encodings round-trip.

**Acceptance:** `from orchid.layer_a.units.types import Tier, ValidationEvent, AssertionMode` works; unit test green.

#### L2. Build `patrol_scrubber.py` (U8)

- [ ] `class PatrolScrubber` with `__init__(period_cycles, jitter_pct=10)`.
- [ ] Walk FSM: `IDLE → WALK_U2 → WALK_U3 → WALK_U4 → WALK_U6 → IDLE`.
- [ ] Per-target invariant probes (callable injectables — real targets passed in):
    - `_check_u2_lut_parity(lut)` → list of violations
    - `_check_u3_metadata_consistency(scratchpad, pmu_snapshot)` → list of violations
    - `_check_u4_fifo_invariant(fifo)` → list of violations
    - `_check_u6_mesi_invariant(state_vector)` → list of violations
- [ ] `step(cycle: int) -> List[ValidationEvent]` — advances FSM, returns events.
- [ ] Period jitter — required, mandatory error if jitter_pct=0 (mirrors spec §8 hardening).
- [ ] Counters: `violations_total`, `last_violation`.

**Acceptance:** Unit tests in `test_patrol_scrubber.py` pass: clean state produces zero events; injected invariant break produces correct event; period jitter violates → constructor raises.

#### L3. Build `validation_bus.py` (U9)

- [ ] `class ValidationBus` with `__init__(num_sources=8, log_buffer_entries=0)`.
- [ ] Mandatory channel: round-robin arbiter, per-source counter, `_trap_callback` hook.
- [ ] Advisory channel: shared, `is_advisory=1` tag, per-(unit, error) counter matrix.
- [ ] `submit(event: ValidationEvent)` API.
- [ ] `get_mandatory_count(unit_id)`, `get_advisory_count(unit_id, error_code)` query API.
- [ ] (P1, future) `log_buffer` — circular 256-entry buffer, head/tail pointers.

**Acceptance:** Unit tests pass: mandatory event triggers callback; advisory event increments counter only; arbitration is starvation-free under saturation; log-buffer disabled-by-default.

#### L4. Build `tier_propagator.py`

- [ ] `class TierPropagator` with `propagate(inputs: List[Tier]) -> Tier` returning `min(inputs)` per worst-case rule.
- [ ] Helpers: `should_dispatch(input_tier, min_tier_required)`, `evict_priority(entry_tier)`.
- [ ] Wrap U7 systolic array op so output gets worst-case input tier.

**Acceptance:** Unit tests verify worst-case rule, dispatch threshold, eviction priority.

#### L5. Wire U8 + U9 + tier into `orchestrator.py`

- [ ] U8 instance + period from config; advance U8 each cycle.
- [ ] U9 instance with 8 sources (U1–U8); collect events.
- [ ] Tier threading through `process_event(...)` call chain.
- [ ] Surface event counts via `metrics.py`.

**Acceptance:** End-to-end trace replay produces non-zero U9 advisory counts on a synthetic fault-injection trace; produces zero on a clean trace.

#### L6. Extend `synthetic_gen.py` for tier-aware traces

- [ ] Add `tier_distribution` config (defaults: 60% T1, 30% T2, 10% T3).
- [ ] Emit `tier` column in JSON Lines output.
- [ ] Backward-compat: missing `tier` defaults to T2 in replayer.

**Acceptance:** Generated trace files include `tier` field; existing v1 traces still replay (with T2 default).

#### L7. Update `trace_replayer.py` to consume tier column

- [ ] Parse `tier` from each trace row.
- [ ] Pass through orchestrator API.
- [ ] Fallback: missing field → T2.

**Acceptance:** Both v1 and v1.5-tier-aware traces replay; tier shows up in `metrics.py` outputs.

#### L8. Layer A test suite — full pass

- [ ] Run `pytest orchid/layer-a/tests/` after L1–L7.
- [ ] Coverage report — new modules ≥80%.

**Acceptance:** All Layer A tests green; coverage threshold met.

---

### Track D — DSE re-run

Independent from Track R. Can fire as a remote-agent routine the day after this plan is approved.

#### D1. Build `synthetic_gen_tier_aware.py`

- [ ] Copy `synthetic_gen.py` with tier-distribution support (per L6).
- [ ] Generate 5 scenario files matching the original DSE inputs (real_traces, sensitivity, ablation, parallel, stress) but each with explicit tier distributions.

**Acceptance:** 5 `.jsonl` files at `orchid/traces/tier-aware-2026-05-XX/` with tier columns.

#### D2. Extend `dse_runner.py` to consume tier-aware traces

- [ ] Accept `--tier-aware` flag.
- [ ] Pass through to replayer.
- [ ] Output goes to `orchid/results/dse-tier-aware-2026-05-XX/`.

**Acceptance:** `python dse_runner.py --tier-aware --output results/dse-tier-aware-2026-05-XX/` produces a CSV identical-shape to the v1 DSE output, plus 4 new columns (`t1_count`, `t2_count`, `t3_count`, `worst_case_propagation_count`).

#### D3. Run the 26K-run sweep

- [ ] Trigger DSE with tier-aware inputs.
- [ ] Wall-clock estimate: ~2 days.
- [ ] Output: `orchid/results/dse-tier-aware-2026-05-XX.csv`.

**Acceptance:** Sweep completes; CSV row count = 26K; no crashes; cu_v2 inputs validate against schema.

#### D4. Analyze + publish results

- [ ] Notebook `orchid/results/dse-tier-aware-2026-05-XX-analysis.ipynb` reading CSV + producing 4 plots:
    1. Composite score distribution by tier dispatch threshold (`u1_min_tier ∈ {T1,T2,T3}`).
    2. Cache hit rate by tier mix (validate U3 tier-aware eviction).
    3. U9 event count vs trace size (validate observability cost).
    4. Tier-flow Sankey (T1/T2/T3 input → output distribution per scenario).
- [ ] Append findings to `docs/case-studies/orchid-v1-5-additive-units-case-study.md` Section 4 (DSE re-run).

**Acceptance:** Notebook checked in; case study has Section 4 populated with key findings.

---

### Track R — Layer B RTL (Chisel)

Track R **must wait** for Phase 5 (v1 SoC integration) to land green. Phases 6–9 are sequential within Track R.

#### Phase 6 — U8 Patrol Scrubber Chisel + verif

- [ ] **R6.1:** `orchid/layer-b/phase6-u8-patrol-scrubber/src/main/scala/PatrolScrubber.scala`
    - Period counter (24-bit free-running, configurable via `u8_patrol_period` CSR)
    - Walk FSM matching Layer A `step()` semantics
    - Per-target invariant probe interfaces (TileLink read masters or direct CSR taps)
    - Validation event handshake to U9 (`u9_event_in_valid` / `u9_event_in_ready`)
- [ ] **R6.2:** Period jitter — mandatory; build error if `u8PeriodJitterPercent == 0` in `OrchidConfig`.
- [ ] **R6.3:** CSR plumbing (`u8_patrol_period`, `u8_patrol_enabled`, `u8_violations_total`, `u8_last_violation`, `u8_assertion_mode`).
- [ ] **R6.4:** Versioned CSR header (per spec §6) — `unit_id=8`, `iface_major=1`, `iface_minor=5`, `unit_capabilities`.
- [ ] **R6.5:** `chisel3.tester` directed tests:
    - L4-T1: Inject U2 LUT parity violation → assert `PATROL_VIOLATION` event with `error_code=0x03`.
    - L4-T4: Set `u8_patrol_period` with `jitter=0` → assert build-time error.
    - Period-counter free-runs without overflow under stress.
- [ ] **R6.6:** Verilator sim — boot Chipyard SoC with U8 wired in; run a 1M-cycle sanity trace.

**Acceptance:** R6 module builds, all directed tests green, Verilator sim runs to 1M cycles without crash.

**Estimated cost:** 1 week RTL + 1 week verif = **2 weeks**.

#### Phase 7 — U9 Validation Bus Chisel + verif (P0 only)

- [ ] **R7.1:** `orchid/layer-b/phase7-u9-validation-bus/src/main/scala/ValidationBus.scala`
    - Mandatory channel: 8 source endpoints, round-robin arbiter, trap injector
    - Advisory channel: shared bus + `is_advisory` tag, counter matrix
    - Per-source counter CSRs
- [ ] **R7.2:** RoCC interrupt wiring for mandatory traps.
- [ ] **R7.3:** Versioned CSR header — `unit_id=9`, `iface_major=1`, `iface_minor=5`.
- [ ] **R7.4:** `chisel3.tester` directed tests:
    - L4-T2: Tier-spoofing input on U1 → assert `LOW_TIER_INPUT` advisory event observed at U9.
    - L4-T5: Mandatory-channel saturation from U2 → other sources still get arbitration within RR-window.
    - Advisory-channel counter matrix increments correctly per (unit, error_code).
- [ ] **R7.5:** P1 log buffer **deferred** — capability bit 3 stays 0 in v1.5.0; revisit in v1.5.1.

**Acceptance:** R7 module builds, P0 directed tests green, mandatory trap reaches CPU MTVAL.

**Estimated cost:** 1.5 weeks RTL + 1 week verif = **2.5 weeks**.

#### Phase 8 — Tier propagation across all units

- [ ] **R8.1:** `orchid/layer-b/phase8-tier-propagation/`
    - TileLink master + slave widened to use `user[1:0]` as tier (no protocol break since user bits are designed for this).
    - U3 scratchpad: 2-bit `tier` field per entry; eviction policy `if pressure > threshold: evict T3 first`.
    - U7 systolic-array output combinator: `out_tier = min(in_tier_a, in_tier_b)`.
    - U1 dispatch: `if input_tier > u1_min_tier: emit LOW_TIER_INPUT advisory event`.
- [ ] **R8.2:** Reserved-zero check on `user[7:2]` — `TILELINK_USER_NONZERO` advisory event if non-zero observed (per Appendix A error code 0x0B).
- [ ] **R8.3:** `chisel3.tester` directed tests:
    - Mixed-tier U7 input → assert output carries `min(inputs)`.
    - Cache pressure with all-T3 entries vs mixed → assert T3 evicted first.
    - U1 dispatch threshold flip → assert advisory rate changes accordingly.
- [ ] **R8.4:** End-to-end Verilator sim with tier-aware trace → assert U9 advisory counts non-zero, mandatory zero.

**Acceptance:** R8 modules build, directed tests green, end-to-end sim shows tier propagating end-to-end without dropping bits.

**Estimated cost:** 2 weeks RTL + 1 week verif = **3 weeks**.

#### Phase 9 — `assertion_mode` + capabilities CSR plumbing + reserved-range trap

- [ ] **R9.1:** Per-unit `uN_assertion_mode` CSR (4-bit) wired into each unit's event-emit path. Modes per spec §5.
- [ ] **R9.2:** Per-unit versioned CSR header on every unit (U1–U9). `unit_id`, `iface_major=1`, `iface_minor=5`, `unit_capabilities` bitmap per Appendix C.
- [ ] **R9.3:** Top-level CSRs: `orchid_iface_major`, `orchid_iface_minor`, `orchid_impl_rev`, `orchid_capabilities` at `0xBF0`–`0xBF3`.
- [ ] **R9.4:** Reserved-range trap-on-access:
    - RoCC `custom-0` `funct7[6:4] ∈ {100,101,110,111}` → illegal-instruction trap.
    - `custom-1`, `custom-2`, `custom-3` → illegal-instruction trap.
    - CSR `0xC00`–`0xDFF` → illegal-CSR trap.
- [ ] **R9.5:** `chisel3.tester` directed tests:
    - Read each capability CSR → matches `OrchidCapabilities.v1_5_default` bit pattern.
    - Read CSR `0xC00` → traps with illegal-CSR.
    - Execute reserved RoCC opcode → traps with illegal-instruction.
    - `assertion_mode = LOG_FATAL` then inject violation → trap fires; `assertion_mode = LOG` → no trap.

**Acceptance:** R9 module builds, all reserved ranges trap correctly, capability bitmap matches spec Appendix C.

**Estimated cost:** 0.5 week RTL + 0.5 week verif = **1 week**.

---

### Track S — Per-unit security hardening (concurrent with Phase 6+)

These are P0 items from the chip-level zero-day survey Part B (per spec §8). Each is a small RTL/Layer A change that should land alongside the Phase containing the affected unit.

- [ ] **S1:** U1 constant-time scoring path — eliminate data-dependent timing on the critical-path comparator. Lands with R8 (Phase 8) since U1 is touched there for tier dispatch.
- [ ] **S2:** U2 LUT parity bit per entry. Lands with R6 (Phase 6) since U8 reads parity.
- [ ] **S3:** U8 period jitter — already mandatory in R6.2.
- [ ] **S4:** U3 PMU CSRs readable but not writable from U-mode. Lands with R8 (PMU exposure work).
- [ ] **S5:** Level 4 directed tests (5 tests per spec §12) — incorporated in R6.5, R7.4, R8.3, R9.5 above.

**Acceptance:** All P0 hardening items checked off; pen-test pass during Verilator sim.

---

## Order of Execution

```
Track L (Layer A)            Track D (DSE)             Track R (Layer B)
                                                       ─────────────────
L1 types.py             ──┐                           [Phase 5 = v1 SoC must be green first]
L2 patrol_scrubber.py     │                                 │
L3 validation_bus.py      ├─D1 trace gen extension          ▼
L4 tier_propagator.py     │                            R6 (U8 Patrol)
L5 orchestrator wiring    ├─D2 dse_runner extension         │
L6 synthetic_gen tiers    │                                 ▼
L7 trace_replayer tiers   │                            R7 (U9 Validation P0)
L8 test suite full        │                                 │
                          │                                 ▼
                          └─D3 26K-run sweep            R8 (Tier propagation + S1+S4)
                              │                             │
                              ▼                             ▼
                          D4 analysis                   R9 (CSR scaffolding + S5)
```

**Critical path:** Track R end-to-end = Phase 6 → Phase 7 → Phase 8 → Phase 9 = 2 + 2.5 + 3 + 1 = **8.5 weeks** assuming no rework.

**Parallelism:** Track L = ~2 weeks. Track D = ~3 days (D1+D2) + 2 days wall-clock (D3) + 1 day (D4) = **~1 week**. Both tracks can start immediately and run in parallel with R6+.

**Total calendar time:** ~9 weeks if Track R serializes; ~6 weeks if R and L+D fully overlap.

---

## Risks

1. **Layer B Phase 5 (v1 SoC integration) not yet green.** Track R cannot start until Phase 5 lands. Mitigation: start Track L + Track D first; revisit Track R once Phase 5 verified.

2. **Chisel toolchain absent on the canonical machine.** v1 Phase 1 was Python-only. Layer B needs Chisel 5.x + sbt + Scala 2.13 + Verilator. Mitigation: `docs/setup/orchid-toolchain-setup.md` (write before R6.1). One-time install, ~30 min.

3. **DSE re-run wall-clock contention.** 2 days uninterrupted compute on the canonical machine while regular dev continues. Mitigation: schedule via remote-agent routine on a low-utilization weekend.

4. **U8 + U9 cost estimates pre-RTL.** Spec §2.1 / §2.2 guess at flip-flop counts; real numbers come from synthesis. Mitigation: post-R6 / post-R7, append actual area numbers to spec as Implementation Notes section. If overrun >20%, revisit P1/P0 split.

5. **Tier propagation invasiveness.** R8 touches every unit (TileLink + U3 + U7 + U1). Highest blast-radius phase. Mitigation: feature-flag tier propagation via `OrchidConfig.tierBits` (default 2; setting 0 disables). Lets Phase 8 land disabled-by-default if integration issues surface.

6. **Reserved-range trap interfering with Linux boot.** R9.4 makes reserved ranges trap. If Linux boot probes those ranges (it shouldn't), boot fails. Mitigation: Verilator sim covers the boot path before tagging R9 done.

7. **`assertion_mode` default.** Spec §5 says default `LOG`. If a downstream consumer expects silent counters by default, this is a behavior change. Mitigation: document in spec §13 "ABI promise" — already done.

---

## Pre-flight checklist (before starting any task)

- [ ] Spec §1–§16 read end-to-end.
- [ ] Spec §13 (ABI promise) understood — bit-position decisions are immutable.
- [ ] Predecessor research notes scanned (research §10 cross-references this plan).
- [ ] Layer B Phase 5 status verified (does v1 SoC integrate cleanly today?).
- [ ] Chisel toolchain installed on canonical machine.
- [ ] Decision: which track starts first (L, R, D)?

---

## Acceptance Criteria for Plan Completion

Plan is "done" when:

1. **All Track L tasks complete** — Layer A behavioral models for U8, U9, tier propagator. `pytest` green. Coverage ≥80%.
2. **All Track D tasks complete** — Tier-aware DSE results published; case study Section 4 populated.
3. **All Track R tasks complete (Phases 6–9)** — Chisel modules build, directed tests green, Verilator end-to-end sim clean, capability bitmap matches Appendix C.
4. **Per-unit security hardening (Track S) all P0 items checked.**
5. **Capability bitmap reflected in `OrchidConfig.capabilitiesBitmap`** matches spec Appendix C.
6. **Reserved ranges trap on access** verified in Verilator boot.
7. **ABI promise (spec §13) preserved** — no v1 software regression on v1.5 hardware.
8. **Companion case study at `docs/case-studies/orchid-v1-5-additive-units-case-study.md`** has Section 1 (Summary), Section 2 (DSE results), Section 3 (Phase-by-phase build log), Section 4 (Validation results), Section 5 (Lessons learned).

---

## Next Steps After Plan Approval

1. **Decide track sequencing** — Track L + Track D first (no Phase 5 dependency) is the recommended start. This unlocks the tier-aware DSE results in ~1 week, which will inform Phase 8 RTL parameter choices.

2. **Write the orchid-toolchain-setup guide** — `docs/setup/orchid-toolchain-setup.md`. Chisel 5.x + sbt + Scala 2.13 + Verilator install. ~30 min on canonical machine. Required before R6.1.

3. **Stand up `feature/orchid-v1-5-track-l` branch** — Track L tasks land here. Each task is its own commit. PR opens after L8 (full test suite green).

4. **Schedule DSE re-run** — Track D wall-clock is ~3 days (D1+D2 build, D3 run, D4 analyze). Suitable for a remote-agent routine.

5. **Layer B Phase 5 status check** — confirm v1 SoC integration is green before opening Track R. If Phase 5 surfaces issues, those fix-up commits land first.

6. **Companion case study scaffold** — create `docs/case-studies/orchid-v1-5-additive-units-case-study.md` with empty Section 1–5 headers; populate as phases ship (mirroring the v1 case study template).

---

**Status:** draft for review. Plan execution begins after approval.

**Estimated total effort:** 9 weeks calendar-time (serial Track R) / 6 weeks (parallelized).
