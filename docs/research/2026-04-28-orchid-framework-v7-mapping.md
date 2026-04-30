# ORCHID v2 — Mapping Framework v6.0 → v7.7 Capabilities Back to Hardware

> **Status:** RESEARCH (2026-04-28). Companion note to [HADF signature expansion](2026-04-28-hadf-signature-expansion.md).
>
> **Premise:** ORCHID's initial design (Phase 1 Layer A complete, 26K+ runs, 7 functional units U1–U7, case study published in `github.com/Regevba/orchid` and PR #83) was anchored to framework v5.0–v5.2 and v6.0. Since then the framework advanced through v7.1 (integrity cycle), v7.5 (cooperating defenses), v7.6 (mechanical enforcement), and v7.7 (validity closure + advisory gates). Each of those releases shipped software primitives that did not exist when ORCHID's spec was written.
>
> **Question this note answers:** for each new v7.x capability, is there a silicon-layer analogue that should land in an ORCHID v2 spec? If yes, what unit hosts it, and what does it cost in area / cycles?
>
> **Out of scope:** RTL changes, Chisel code, Layer B/C plan rewrites. This note proposes the v2 mapping; spec writing is downstream.

---

## 1. ORCHID v1 baseline (recap)

7 functional units, mapped from v5.0–v5.2 + v6.0:

| Unit | Name | Framework origin | Silicon analogue |
|---|---|---|---|
| U1 | Dispatch Scorer | v5.2 dispatch-intelligence.json | Combinational, stateless |
| U2 | Skill Router | skill-routing.json phase_skills | ROM LUT + decoder |
| U3 | Cache Controller | v5.0 cache compression | Scratchpad SRAM + compression |
| U4 | Batch Scheduler | v5.1 batch dispatch | FIFO + round-robin arbiter |
| U5 | Speculative Prefetcher | v5.1 speculative preload | Prediction table (BTB-style) |
| U6 | Coherence Unit | v5.2 parallel write safety | MESI-like FSM |
| U7 | Systolic Array | v5.1 systolic chains | Gemmini |

Interconnect: TileLink. Host: Rocket (RISC-V) + RoCC.

OrchidConfig key knobs (post-v6.0 calibration): `scoreBits=7`, `inputBusWidth=13` (CU v2), `maxSkills=16`, `cacheEntries=15`, `scratchpadKB=48`, `prefetchStagingKB=16`, `contextBitsPerEntry=4`, `maxConcurrentTasks=8`, `predictionTableEntries=64` (recommended drop to 16 per design space exploration), `maxWriters=8`, `meshRows/Cols=8`, `dataWidth=16`.

Design space exploration findings (26K runs, [research_orchid_design_space_findings.md](../../../.claude/projects/-Volumes-DevSSD-FitTracker2/memory/research_orchid_design_space_findings.md)):
- `prefetch_ahead=0` often wins on diverse workloads.
- `cache_entries < 10` thrashes catastrophically; 10–15 is the safe band.
- `max_concurrent`, `prediction_table_size`, `mesh_rows/cols` showed zero impact on synthetic traces — design space was under-stressed.

---

## 2. What landed between v6.0 and v7.7 (software side)

This is the universe of new framework primitives ORCHID v2 must consider:

### v7.1 — 72h Integrity Cycle (shipped 2026-04-21)
First framework capability triggered by **wall-clock elapsed time**, not by user/agent action. Runs `scripts/integrity-check.py` against all `state.json` and case studies every 72h via GitHub Actions. 13 cycle-time check codes.

### v7.5 — Data Integrity Framework / cooperating defenses (shipped 2026-04-24)
Eight cooperating defenses across three timing classes:
- **Write-time gates** (fire on `git commit`): `SCHEMA_DRIFT`, `PR_NUMBER_UNRESOLVED`, etc.
- **Cycle-time gates** (every 72h): the v7.1 integrity-check codes.
- **Readout-time dashboards** (any time): `make documentation-debt`, `make measurement-adoption`, `make runtime-smoke`.

Plus the **T1/T2/T3 data quality tier** convention — every quantitative metric must carry a tag indicating whether it is Instrumented (T1), Declared (T2), or Narrative (T3).

### v7.6 — Mechanical Enforcement (shipped 2026-04-25)
Promoted four silent agent-attention checks to pre-commit failures:
- `PHASE_TRANSITION_NO_LOG` — phase change without a feature log entry within 15 min
- `PHASE_TRANSITION_NO_TIMING` — phase change without timing.phases entries
- `BROKEN_PR_CITATION` — case-study PR# that doesn't resolve in cached `gh pr list`
- `CASE_STUDY_MISSING_TIER_TAGS` — scoped case-study commits without T1/T2/T3 tags

Plus two recurring CI defenses:
- Per-PR review bot ([`.github/workflows/pr-integrity-check.yml`](../../.github/workflows/pr-integrity-check.yml))
- Weekly framework-status cron ([`.github/workflows/framework-status-weekly.yml`](../../.github/workflows/framework-status-weekly.yml))

### v7.7 — Validity Closure (in progress, 2026-04-27 freeze)
Closes A1–A5 + B1–B2 + C1 from the post-v7.6 gap inventory:
- 4 new write-time pre-commit hooks (`CACHE_HITS_EMPTY_POST_V6`, `CU_V2_INVALID`, `STATE_NO_CASE_STUDY_LINK`, `CASE_STUDY_MISSING_FIELDS`)
- 1 new cycle-time check code (`CU_V2_INVALID`)
- 1 cycle-time **advisory** (`TIER_TAG_LIKELY_INCORRECT`) — ships permanent advisory because kill criterion 2 fired at baseline
- Bulk backfill of 32 case-study frontmatters
- Framework-health dashboard (`/control-room/framework`) surfacing 19 mechanical gates + 1 advisory

**Total framework gates:** 18 (12 cycle + 6 write-time) → **25 gates + 1 advisory**.

### Plus: known mechanical limits
Five gaps remain mechanically unclosable per [`docs/case-studies/meta-analysis/unclosable-gaps.md`](../case-studies/meta-analysis/unclosable-gaps.md):
1. `cache_hits[]` writer-path adoption
2. `cu_v2` factor *correctness* (judgment-based)
3. T1/T2/T3 tag *correctness*
4. Tier 2.1 real-provider auth checklist (human required)
5. Tier 3.3 external replication (external operator required)

---

## 3. Per-capability mapping audit

For each v7.x capability, three questions:
1. **Does it have a silicon-layer analogue?**
2. **If yes, which ORCHID unit hosts it?**
3. **What's the rough cost (area, cycles, new unit)?**

### 3.1 v7.1 — 72h Integrity Cycle
**Silicon analogue:** YES — **periodic hardware self-audit / built-in self-test (BIST) primitive.**
Real chips do this: ECC scrubbers walk DRAM looking for bit flips on a cadence; CPU LBIST runs at boot and during low-utilization windows; storage controllers run periodic patrol reads. The v7.1 trigger model (wall-clock elapsed → walk all state) maps exactly to a hardware patrol scrubber.

**ORCHID host:** New unit **U8 — Patrol Scrubber.**
- Walks U3's scratchpad and U6's coherence directory on a programmable cadence.
- Detects stale entries (timestamp > threshold), corrupt CRCs, orphaned cache lines.
- Raises an interrupt to the Rocket host on detection (the silicon analogue of opening a `framework-status` GitHub issue).

**Cost:** ~0.5% area overhead (a small FSM + counter + cadence register). One new RoCC instruction `orchid.scrub.start`. Estimated 1 cycle to start, runs in background.

**Why this matters:** ORCHID v1 has no notion of *time-elapsed* as a trigger — it only acts on dispatch. A Patrol Scrubber gives the chip the same self-audit posture the framework has on the software side.

### 3.2 v7.5 — Cooperating defenses (write-time / cycle-time / readout-time)
**Silicon analogue:** YES — **multi-stage validation pipeline.**
This is exactly how silicon validates itself today. Hardware bugs are caught at three stages: (a) at design write time (lint, formal verification), (b) periodically post-tapeout (BIST, in-field telemetry), (c) on demand (debug interface, scan chains).

**ORCHID host:** Distributed across units, plus one new unit **U9 — Validation Bus.**
- Write-time check → U1 Dispatch Scorer rejects ill-formed dispatch packets at the input stage (1-cycle FSM in input pipeline).
- Cycle-time check → U8 Patrol Scrubber (above).
- Readout-time → U9 Validation Bus exposes a memory-mapped register file (status, counters, last-error) accessible from Rocket.

**Cost:** U9 is small (a register file + arbiter), maybe 0.2% area. The big cost is wiring — every functional unit needs a `valid` and `error_code` output line into U9. Estimated +5% wire density. No cycle penalty on the dispatch fast path.

**Why this matters:** v7.5's three-tier defense model is essentially a hardware design pattern that hasn't been explicitly named in ORCHID v1. Adding U9 makes the chip's validation surface as queryable as the framework's.

### 3.3 v7.5 — T1/T2/T3 data quality tier convention
**Silicon analogue:** YES — **confidence/provenance bits on data flowing through the pipeline.**
Hardware floating-point already has this primitive (signaling NaN, denormal flags, IEEE-754 status bits). The conceptual move is: every value carries a tier tag, propagated through computation, raising an interrupt or routing differently when a low-tier value enters a high-trust path.

**ORCHID host:** **OrchidConfig schema change** — add `tierBits=2` per data entry across U3 (cache), U4 (scheduler), U7 (systolic array result tags). Plus a new dispatch_hint in U1: `min_tier_required` per workload class.

**Cost:** 2 bits per cache entry × 15 entries = 30 bits. 2 bits per scheduler slot × 8 slots = 16 bits. Trivial area. The cost is in the wires: every dataflow path in the chip widens by 2 bits. Estimated +2% wire density. No cycle penalty.

**Why this matters:** ORCHID's composite score (latency × throughput × energy) currently treats every data point as equal. Adding tier propagation lets the dispatcher de-rate paths that operate on T3 (narrative) data — analogous to how the framework refuses to declare "kill criterion fired" on a T3 metric.

### 3.4 v7.6 — Mechanical enforcement (Class B → Class A promotion)
**Silicon analogue:** YES — **soft-assertion → hard-assertion promotion in synthesizable RTL.**
Verilog has both `assert` (compile-time) and `assume` (runtime) plus `expect`/`cover` for verification — and the equivalent of v7.6 promotion is moving an assertion from `simulation_only` to `synthesizable_with_trap`. Real chips do this: AArch64 has watchpoint registers that escalate from log-only → trap-on-write based on a config bit.

**ORCHID host:** **U1 Dispatch Scorer** + new `assertion_mode` register per unit.
- Each unit gets an `assert_mode` field: `OFF | LOG | TRAP`.
- LOG mode = current ORCHID v1 behavior (counter increments on violation, dispatch continues).
- TRAP mode = new behavior — violation raises an interrupt to Rocket and stalls the offending unit.

**Cost:** 2-bit register per unit × 7 units = 14 bits. The trap path needs a wire to Rocket's interrupt controller. Maybe 0.1% area. The harder cost is the *verification effort* to certify each assertion is truly trap-safe (the silicon analogue of writing pre-commit hooks).

**Why this matters:** v7.6's Class B → Class A promotion is the canonical example of "moving from advisory to mandatory." ORCHID v1 has no notion of advisory vs mandatory for any unit. v2 should bake it in from day one.

### 3.5 v7.6 — Per-PR review bot + weekly cron
**Silicon analogue:** PARTIAL — **per-transaction validation (per-PR analogue) + periodic full-system check (cron analogue).**
The PR bot equivalent is a "per-dispatch validation" that runs *before* the result commits; the cron equivalent is the U8 Patrol Scrubber from §3.1. So PR-bot is a new pattern.

**ORCHID host:** U1 Dispatch Scorer gets a **pre-commit phase** — score is computed, but the result is held in a staging register until U9 Validation Bus signals OK.

**Cost:** One staging register per dispatch slot. +1 cycle pipeline depth on dispatch (was combinational, now has a pre-commit phase). This is a real cycle-time hit. Needs evaluation.

**Why this matters:** It's the difference between catching a bad dispatch *before it routes* vs *after it executes*. The framework moved this needle in v7.6. ORCHID's v1 dispatch was purely speculative (combinational, single-cycle); v2 should consider a 2-cycle dispatch with a validation gate.

### 3.6 v7.7 — Validity closure (5 new gates + 1 advisory)
**Silicon analogue:** YES — **soft-fail vs hard-fail assertion modes with one always-soft channel.**
The advisory gate (`TIER_TAG_LIKELY_INCORRECT`, ships permanent advisory because kill criterion 2 fired at baseline) is genuinely interesting from a hardware perspective: it's an assertion that *cannot* be promoted to hard-fail because the underlying signal is judgment-based. Hardware analogue: thermal sensors and aging counters — they always log, never trap, because false-positive rates are too high.

**ORCHID host:** **U9 Validation Bus** gets two channels:
- `mandatory_channel` — feeds the trap path to Rocket.
- `advisory_channel` — feeds a separate counter file, never traps.

**Cost:** Doubles the wire count out of each unit but at very narrow widths (4-bit error codes). Still small.

**Why this matters:** Hardware design has long suffered from "every error is fatal" or "every error is silent." The v7.7 advisory model is a third way: log-with-priority. Worth encoding in the chip from the start.

### 3.7 v7.7 — `cache_hits[]` mechanical limit
**Silicon analogue:** YES — **observability primitive (performance counters).**
The framework's struggle to make `cache_hits[]` write-path-mandatory mirrors the chip-level struggle to make every event counter-tracked. Modern chips solve this with PMU (Performance Monitoring Unit) registers — every cache miss / branch mispredict / TLB walk is counted automatically by hardware.

**ORCHID host:** **U3 Cache Controller** already has a hit/miss counter (per [research_orchid_design_space_findings.md](../../../.claude/projects/-Volumes-DevSSD-FitTracker2/memory/research_orchid_design_space_findings.md)). v2 should expose it as a memory-mapped PMU register accessible from Rocket — the silicon equivalent of write-time-mandatory `cache_hits[]`.

**Cost:** Already implemented. Just needs to be wired to U9 Validation Bus and exposed via memory map. Trivial.

**Why this matters:** It closes the only Class B mechanical gap that v7.7 couldn't promote (per the framework's own mechanical-limits doc). Hardware can do this trivially because it has dedicated counter silicon. The framework cannot because the writer-path is human/agent.

### 3.8 v7.x — `cu_v2` continuous factors
**Silicon analogue:** YES — **dynamic dispatch input vector.**
ORCHID v1 already encodes CU v2 as `inputBusWidth=13` per the post-v6.0 calibration. So this is already in the spec. The v7.x novelty is `CU_V2_INVALID` as a write-time gate — schema validation. The silicon analogue is **input-bus protocol checking**: every dispatch packet entering U1 Dispatch Scorer is validated against the protocol before scoring begins.

**ORCHID host:** **U1 Dispatch Scorer** input pipeline gets a 1-cycle protocol-check FSM. If the input vector is malformed (wrong bit count, out-of-range factor), the scorer rejects the packet and signals U9.

**Cost:** 1 cycle on the dispatch fast path (2 cycles total: protocol-check → score). Same cost as §3.5 above; can share the staging register.

**Why this matters:** The whole point of `inputBusWidth=13` is to encode v6.0 CU v2 factors faithfully. Adding protocol-check makes the encoding *enforced*, not just *documented*.

---

## 4. Summary mapping table

| Framework capability | New ORCHID unit / change | Cost | Priority |
|---|---|---|---|
| v7.1 — 72h integrity cycle | **U8 — Patrol Scrubber** | ~0.5% area, +1 RoCC instr | **P0** |
| v7.5 — three-tier defenses | **U9 — Validation Bus** + per-unit error wires | ~0.2% area + 5% wire density | **P0** |
| v7.5 — T1/T2/T3 data tiers | **OrchidConfig: tierBits=2** + U1 min_tier_required hint | ~2% wire density | **P0** |
| v7.6 — Class B → Class A | **assertion_mode** register per unit | ~0.1% area, verification cost is real | **P1** |
| v7.6 — per-PR pre-commit gate | **U1 staging register + pre-commit phase** | +1 cycle dispatch pipeline depth | **P1** (eval first) |
| v7.7 — advisory vs mandatory channels | **U9: mandatory + advisory channels** | minor wire count | **P1** |
| v7.7 — `cache_hits[]` PMU | **U3 PMU register exposure** to U9 + memmap | trivial | **P0** (cheap) |
| v7.x — `cu_v2` protocol check | **U1 input pipeline FSM** | shares staging with v7.6 | **P1** (folds into v7.6 work) |

---

## 5. Proposed ORCHID v2 architecture sketch

```
ORCHID v2 SoC
├── RISC-V Core (Rocket) ──RoCC──► Orchestration Accelerator Complex
│                                   ├── U1: Dispatch Scorer (combinational + pre-commit phase)
│                                   │       └── input pipeline FSM (cu_v2 protocol check)
│                                   ├── U2: Skill Router (LUT + decoder)
│                                   ├── U3: Cache Controller (scratchpad + PMU registers)
│                                   ├── U4: Batch Scheduler (FIFO+arbiter, tier-aware)
│                                   ├── U5: Speculative Prefetcher (BTB-style)
│                                   ├── U6: Coherence Unit (MESI-like)
│                                   ├── U7: Systolic Array (Gemmini)
│                                   ├── U8: Patrol Scrubber (NEW — periodic self-audit)  ← v7.1
│                                   └── U9: Validation Bus (NEW — mandatory + advisory)  ← v7.5/v7.7
├── TileLink Interconnect (result forwarding bus)
│       └── 2-bit tier propagation widening                                              ← v7.5
└── Memory Subsystem (L1 scratchpad with tier tags, L2 compressed, DRAM)
```

Key v2 deltas vs v1:
- Two new functional units (U8, U9) — one for periodic self-audit, one for validation surface.
- Per-unit `assertion_mode` register lets ops promote silent counters to traps without RTL change.
- 2-bit data tier propagation across the interconnect.
- 1-cycle pre-commit phase on U1 dispatch fast path (configurable; can be disabled for raw throughput).

---

## 6. What v7.x does NOT translate to silicon

Three v7.x capabilities have no clean silicon analogue and should stay framework-only:

1. **Bulk backfill of 32 case-study frontmatters (v7.7)** — this is a one-time data migration, not a recurring primitive. Silicon equivalent would be a one-time microcode patch, which is not worth designing for.
2. **Per-PR review bot fetching `origin/main` baseline via git worktree** — git is irrelevant to silicon. The conceptual analogue (compare-against-baseline) is already covered by U8 Patrol Scrubber.
3. **Pre-PRD `success_metrics` / `kill_criteria` / `dispatch_pattern` markers** — these are PRD-stage artifacts. The hardware analogue would be design intent / requirements traceability, which is a different layer (probably a verification IP layer, not a silicon unit).

---

## 7. Cross-coordination with HADF expansion

Three of the proposed v2 changes interact with the HADF signature library expansion ([2026-04-28-hadf-signature-expansion.md](2026-04-28-hadf-signature-expansion.md)):

1. **Tier propagation (§3.3)** — if HADF adds T1/T2/T3 to its dispatch hints, ORCHID's `tierBits` can be the silicon-side enforcement.
2. **PMU exposure (§3.7)** — once HADF adds new chip profiles whose dispatch-hint tables include `cache_hits` as a measured input, ORCHID's U3 PMU is the place those metrics land.
3. **Networking primitive on real chips** — Gaudi 3's 24×200 GbE on-package and Jaguar Shores' silicon photonics (per the HADF note) are the upstream hardware analogue of ORCHID's TileLink bus. v2 should consider whether the result-forwarding interconnect should support multi-chip scale-out or stay single-die.

---

## 8. Recommendation: ORCHID v2 vs ORCHID v1.5

Two options for landing this:

### Option A — ORCHID v2 (full spec rev)
Add U8 + U9, change OrchidConfig schema, document advisory/mandatory channels, write a new spec. Net cost: 1 new spec doc + 4 new plans (Phase 6: U8, Phase 7: U9, Phase 8: tier propagation, Phase 9: assertion_mode). Estimated 3–4 weeks of plan-writing before any RTL.

### Option B — ORCHID v1.5 (incremental)
Keep the v1 7-unit architecture, but extend OrchidConfig with `tierBits` and `assertionModes` per unit. Add a single `Patrol Scrubber` unit (P0 only). Defer U9 Validation Bus and pre-commit-gate work to v2. Net cost: 1 spec addendum + 1 plan. ~1 week.

**Recommendation: Option B (v1.5).** Three reasons:
1. Phases 2–5 of the original ORCHID plan are still ready-to-execute (Layer B + Layer C). Forking to v2 risks abandoning that progress.
2. The P0 changes (U8 Patrol Scrubber, tier propagation, U3 PMU exposure) are additive and don't break Phase 2–5 RTL.
3. The P1 changes (U9, pre-commit gate, assertion_mode) genuinely benefit from running ORCHID Layer B/C first to gather real cycle-time data — guessing the cost of "+1 cycle on dispatch fast path" without measurement is exactly the kind of thing v6.0 measurement infrastructure exists to prevent.

---

## 9. Open questions

1. **Should U8 Patrol Scrubber walk DRAM, or only on-chip state?** Walking DRAM at the cadence the framework uses (every 72h equivalent) would be a real bandwidth tax. Recommend: on-chip only for v1.5; revisit DRAM scrubbing in v2.
2. **Does tier propagation belong on TileLink, or as side-band metadata?** Widening TileLink by 2 bits affects every IP block on the bus; side-band keeps the bus stable but adds wiring complexity. Open question for the Layer B Chisel work.
3. **Is the advisory channel worth its own physical wires, or can it share the mandatory channel with a 1-bit "is_advisory" tag?** Tag is cheaper but increases parsing complexity at U9. Recommend: tag in v1.5, separate wires only if profiling shows contention.
4. **Should the 26K-run design space exploration be re-run with new tier-aware traces?** Original DSE used synthetic traces with no tier dimension. Adding T1/T2/T3 to the trace generator would let DSE confirm the dispatcher actually de-rates T3 paths. Estimated cost: 1 day to extend the trace generator + ~2 days of DSE wall-clock.
5. **How does this affect HADF integration?** Currently HADF Layer 4 (evolutionary learning) writes to `chip-affinity-map.json`. If ORCHID v1.5 PMU exposure becomes the canonical source of dispatch-affinity data on Orchid-equipped systems, the affinity map writer needs a hardware-source mode. Open for a follow-up.

---

## 10. Next steps

1. **Decide Option A vs Option B** (§8) — one approval needed before any spec/plan work begins.
2. **If Option B chosen:**
   - Write a 1-page ORCHID v1.5 spec addendum covering U8 + tier propagation + U3 PMU exposure.
   - Add 1 plan: `2026-04-28-orchid-v1-5-patrol-scrubber.md` (~3 tasks: behavioral model in Layer A, Chisel RTL in Layer B, integration with U3).
   - Re-run the DSE with tier-aware traces (per §9, item 4) to validate that the dispatcher uses the new bits.
3. **If Option A chosen:** the spec rewrite is a real 3–4-week job. Recommend deferring until ORCHID Layer B Phase 2 (U1+U2 Chisel) is complete — that gives real cycle-time data to ground the P1 cost estimates.
4. **Cross-link** this note from [research_cloud_emulated_chip_design.md](../../../.claude/projects/-Volumes-DevSSD-FitTracker2/memory/research_cloud_emulated_chip_design.md), [research_framework_to_hardware_mapping.md](../../../.claude/projects/-Volumes-DevSSD-FitTracker2/memory/research_framework_to_hardware_mapping.md), and the backlog item under "High Priority (Architecture & Framework)" in [`docs/product/backlog.md`](../product/backlog.md).
5. **Coordinate with HADF expansion** ([2026-04-28-hadf-signature-expansion.md](2026-04-28-hadf-signature-expansion.md)) — three changes interact (§7).

---

## Appendix A — Framework version → ORCHID unit cross-reference (full table)

| Framework version | Capability | ORCHID v1 home | ORCHID v2 change |
|---|---|---|---|
| v5.0 | Skill-on-demand loading | U2 Skill Router | unchanged |
| v5.0 | Cache compression | U3 Cache Controller | unchanged |
| v5.1 | Batch dispatch | U4 Batch Scheduler | tier-aware (v7.5) |
| v5.1 | Result forwarding | TileLink interconnect | +2-bit tier widening (v7.5) |
| v5.1 | Model tiering | U1 Dispatch Scorer | min_tier_required hint (v7.5) |
| v5.1 | Speculative preload | U5 Speculative Prefetcher | unchanged |
| v5.1 | Systolic chains | U7 Systolic Array | unchanged |
| v5.1 | Task complexity gate | U1 + U4 dispatch logic | unchanged |
| v5.2 | Dispatch intelligence | U1 Dispatch Scorer | + protocol-check FSM (v7.x cu_v2) |
| v5.2 | Parallel write safety | U6 Coherence Unit | unchanged |
| v6.0 | Deterministic measurement | OrchidConfig (cu_v2 input bus) | already encoded |
| v7.1 | 72h integrity cycle | **none** | **NEW: U8 Patrol Scrubber** |
| v7.5 | Cooperating defenses | **none** | **NEW: U9 Validation Bus** |
| v7.5 | T1/T2/T3 data tiers | **none** | **NEW: tierBits propagation** |
| v7.6 | Class B → A mechanical | **none** | **NEW: assertion_mode register per unit** |
| v7.6 | Per-PR pre-commit gate | **none** | **NEW: U1 staging register + pre-commit phase** |
| v7.7 | Advisory vs mandatory | **none** | **NEW: U9 dual-channel** |
| v7.7 | `cache_hits[]` PMU | U3 has counters | **NEW: PMU register exposure to U9** |

---

## Appendix B — What this note does NOT claim

- It does **not** claim ORCHID v2 will be faster than v1. The new units (U8, U9) are validation/observability, not compute. Composite score may not improve.
- It does **not** claim every v7.x capability is silicon-relevant. Three explicitly are not (§6).
- It does **not** claim hardware costs given here are accurate to within 10%. They are sketches; real numbers come from Layer B Chisel + Verilator runs.
- It does **not** claim Option B (v1.5) is the right call universally. It is the right call **given** the existing Phase 2–5 plans are ready to execute and there is no business reason to fork. If the business reason changes, Option A becomes attractive.
