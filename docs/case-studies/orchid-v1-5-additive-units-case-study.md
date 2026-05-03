---
slug: orchid-v1-5-additive-units-case-study
title: "Orchid v1.5 — Additive Units (U8 Patrol Scrubber, U9 Validation Bus, Tier Propagation)"
date: 2026-05-03
framework_version: v7.7
work_type: feature
work_subtype: research
dispatch_pattern: serial
status: draft_for_review
case_study_type: live_pm_workflow
tier_tags_required: true
case_study: docs/case-studies/orchid-v1-5-additive-units-case-study.md
predecessor_case_studies:
  - docs/case-studies/orchid-ai-accelerator-case-study.md
related_specs:
  - docs/superpowers/specs/2026-04-16-orchid-ai-accelerator-design.md
  - docs/superpowers/specs/2026-05-03-orchid-v1-5-design.md
related_research:
  - docs/research/2026-04-28-orchid-framework-v7-mapping.md
  - docs/research/2026-05-01-modular-chip-architecture-survey.md
  - docs/research/2026-05-01-chip-security-zero-day-survey.md
related_plans:
  - docs/superpowers/plans/2026-05-03-orchid-v1-5-additive-units.md
related_prs:
  - 179  # spec
  - 180  # plan
  - 181  # toolchain guide + case study scaffold
  - 182  # Track L (Layer A behavioral models)
  - 183  # Track D (tier-aware DSE)
success_metrics:
  primary: "Tier-aware DSE answers v2 mapping research §9 Q4 (does dispatcher de-rate T3?) with quantitative data [T1]"
  secondary:
    - "U8 + U9 area cost stays within ±20% of spec §2.1/§2.2 estimates [T2]"
    - "Track L Layer A tests reach ≥80% line coverage on new modules [T1]"
    - "Phase 6-9 RTL passes Level 1-4 verification per spec §12 [T1]"
kill_criteria:
  - "U8 patrol-scrubber observability cost > 5% of dispatch path cycles → revisit cadence"
  - "U9 mandatory channel arbiter starvation observed in 26K-run DSE → redesign before Phase 7 RTL"
  - "Tier propagation widens TileLink critical path > 2 cycles → revert to side-band metadata"
visual_aid: "<KeyNumbersChart />"
---

# Orchid v1.5 — Additive Units Case Study

> **Status:** scaffold. Sections 1-3 populated as Track L + Track D ship.
> Sections 4-5 fill as DSE results land + Track R RTL completes.
> Final synthesis (Section 99) populates after all phases close.

## 1. Summary card

What v1.5 ships, in three lines:

- **U8 Patrol Scrubber** — silicon analogue of v7.1 72h integrity cycle. Walks U2/U3/U4/U6 state on a configurable cadence; emits validation events on detected drift.
- **U9 Validation Bus** — silicon analogue of v7.5 cooperating defenses + v7.7 advisory/mandatory split. Per-source mandatory FIFOs feed RR arbiter; advisory channel uses per-(unit, error) counter matrix.
- **Tier propagation + assertion_mode + forward-compat scaffolding** — TileLink `user[1:0]` carries T1/T2/T3 across the system; per-unit `assertion_mode` register flips advisory→fatal without RTL change; versioned CSR headers + reserved opcode/CSR ranges keep v2.0 expansion painless.

Why now: the post-v7.6 mapping research (2026-04-28) identified these as the **silicon-relevant** v7.x capabilities. The post-HADF-Phase-2 follow-up tracks queued v1.5 spec work as Track 3. v1.5 lands the additive surface; v2.0 (if/when) reconsiders breaking changes.

## 2. The research arc

(populated as work progresses)

### 2.1 Predecessor: Orchid v1 baseline

7 functional units (U1-U7), 26K+ design-space-exploration runs, case study published 2026-04-17 at [`docs/case-studies/orchid-ai-accelerator-case-study.md`](orchid-ai-accelerator-case-study.md). Anchored to framework v5.0-v6.0.

### 2.2 What landed in framework v7.x that mapped to silicon

Per [v2 mapping research §3](../research/2026-04-28-orchid-framework-v7-mapping.md):

- v7.1 72h integrity cycle → U8 Patrol Scrubber
- v7.5 cooperating defenses → U9 Validation Bus
- v7.5 T1/T2/T3 data tiers → tier propagation across TileLink
- v7.6 Class B → A flip pattern → `assertion_mode` CSR
- v7.7 cache_hits[] observability → U3 PMU exposure
- v7.7 advisory/mandatory split → U9 dual-channel

### 2.3 Decision: Option B (v1.5 incremental) over Option A (v2.0 full rewrite)

Per [v2 mapping research §8](../research/2026-04-28-orchid-framework-v7-mapping.md): Option B preserves Phase 2-5 readiness, lands P0 changes additively, and lets P1 changes (full pre-commit gating, multi-Orchid scaling, TL-C coherence) gather real Layer B cycle-time data before being committed to silicon.

### 2.4 Forward-compatibility scaffolding from the modular survey

Per [modular chip architecture survey §9.4](../research/2026-05-01-modular-chip-architecture-survey.md): three concrete patterns that cost nothing in area but are catastrophic to retrofit. v1.5 lands all three.

### 2.5 Per-unit security hardening from the zero-day survey

Per [chip-level zero-day survey Part B](../research/2026-05-01-chip-security-zero-day-survey.md): P0 items per unit. v1.5 lands them; P1 items deferred.

## 3. Phase-by-phase build log

### 3.1 Track L — Layer A behavioral models (PR #182, merged 2026-05-03)

**Tasks shipped:**

| Task | Module | Lines (code + test) | Smoke assertions |
|---|---|---|---|
| L1 | `units/types.py` extension | 275 | 11 |
| L2 | `units/patrol_scrubber.py` | 414 | 13 |
| L3 | `units/validation_bus.py` | 458 | 22 |
| L4 | `units/tier_propagator.py` | 293 | 20 |
| L5 | `orchestrator.py` rewrite | 414 | 10 |
| L6+L7 | `synthetic_gen.py` + `trace_replayer.py` | 136 | 9 |

**Total:** 1,990 LoC, 71 test functions, **39 stdlib smoke assertions pass** [T1].

**Acceptance criteria met:**

- Clean trace produces zero U9 events [T1]
- Injected fault produces non-zero U9 events [T1]
- v1 backward compat: existing tests import cleanly (7/7) [T1]
- End-to-end: 100-event trace replays through orchestrator with U8 + U9 wired in [T1]

**Pending:** pytest formal pass (toolchain gated per plan §"Risks" item 2 — `.venv` deleted in 2026-05-01 HADF Phase 2 incident, restoration is separate task).

### 3.2 Track D — Tier-aware DSE D1+D2 (PR #183, in flight)

**Tasks shipped:**

- **D1** Tier-aware trace generator (already done in L6 since synthetic_gen accepts a configurable distribution).
- **D2** `--tier-aware` flag on `design_space_explorer.py`. ConfigurableOrchestrator now wires v1.5 units; SweepResult has U9/U8 counter columns.

**End-to-end validation on 50-row mini-sweep [T1]:**

| Scenario | LOW_TIER_INPUT events |
|---|---|
| all-T3 distribution + u1_min=T2 | 907 (every task trips threshold ✓) |
| all-T1 distribution + u1_min=T2 | 0 (every task admits ✓) |
| 60/30/10 default + u1_min=T1 (strict) | 360 |
| 60/30/10 default + u1_min=T3 (permissive) | 0 |

**Pending:**

- **D3** Full 26K-run sweep — ~2 days wall-clock; defer to scheduled remote-agent OR low-utilization window.
- **D4** Analysis notebook + Section 4 fill — gated on D3 outputs existing.

### 3.3 Track R — Layer B Chisel RTL (Phases 6-9)

**Status: blocked.** Per plan §"Risks" item 1, Track R requires Phase 5 (v1 SoC integration) to be green. Phase 5 doesn't exist yet — needs the toolchain (per [`docs/setup/orchid-toolchain-setup.md`](../setup/orchid-toolchain-setup.md)) and the v1 Phase 2-5 plans to execute first.

This is **expected** per the v1.5 plan. The whole point of Option B (v1.5 incremental) was that Track R doesn't block on the v1.5 spec/Layer A work.

When Track R does start:

- **Phase 6** (U8) — 2 weeks RTL + verif
- **Phase 7** (U9 P0) — 2.5 weeks RTL + verif
- **Phase 8** (Tier propagation) — 3 weeks RTL + verif
- **Phase 9** (CSR scaffolding) — 1 week RTL + verif
- Total 8.5 weeks calendar-time serial.

## 4. DSE re-run results

(to be filled in after Track D D3 completes the 26K-run sweep)

Expected sections:

### 4.1 Composite score by `u1_min_tier`

Does the dispatch threshold actually de-rate T3 paths in the composite-score metric? **Mini-sweep evidence (50 rows):** yes — observable LOW_TIER advisory rate diverges by 360 events between strictest (T1) and permissive (T3) thresholds. **Full-sweep number TBD.**

### 4.2 Cache hit rate by tier mix

Per spec §3, U3 evicts T3 entries first under capacity pressure. Validate by comparing 60/30/10 vs 30/30/40 distributions at fixed cache_entries.

### 4.3 U9 observability cost vs trace size

Events emitted per N tasks. If > 5% overhead, kill criterion 1 fires.

### 4.4 Tier flow Sankey diagram (T1/T2/T3 input → output per scenario)

Visual confirmation that the worst-case-on-output rule actually narrows T1+T2 mixed inputs to T2 outputs, T1+T3 to T3, etc.

## 5. Architecture validation

(to be filled in after Track R Phases 6-9 land)

### 5.1 Phase 6 area numbers vs spec §2.1 estimate

### 5.2 Phase 7 area numbers vs spec §2.2 estimate

### 5.3 Tier propagation impact on critical path (Phase 8)

### 5.4 Reserved-range trap behavior under Linux boot (Phase 9)

## 6. What we learned

(populates as phases close)

## 7. Cross-coordination with HADF expansion

Per [HADF signature expansion research](../research/2026-04-28-hadf-signature-expansion.md) + v2 mapping research §7:

- Tier propagation interfaces with HADF dispatch hints — once HADF adds T1/T2/T3 to its hint table, ORCHID's `user[1:0]` becomes the silicon-side enforcement.
- U3 PMU exposure becomes the canonical source of cache_hits data on Orchid-equipped systems; HADF Layer 4 affinity-map writer needs a hardware-source mode (deferred per v2 mapping research §9 Q5).
- Multi-Orchid scaling deliberately deferred to v2.0; HADF's networking-primitive analogues (Gaudi 3 + Jaguar Shores) inform the v2.0 scope.

## 99. Synthesis (post-completion)

(to be filled in after all phases close — the live append-only journal collapses into a single retrospective here)

---

**Last updated:** 2026-05-03. Next update: after Track D D3 lands DSE results (~2 days wall-clock).
