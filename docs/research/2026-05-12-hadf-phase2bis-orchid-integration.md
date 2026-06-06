# HADF Phase 2-bis ↔ ORCHID Integration + Framework-Plan Alignment

> **UPDATE 2026-06-05 — forks RESOLVED.** This is the 2026-05-12 *planning* note; the per-sub-exp "most-likely-touched units" / "expected delta" forks below are now resolved by the closed verdicts (all 4 sub-exps PASS): Sub-exp 2 SEPARABLE → **U7 8×8 compute-bound** + **U3 local-fits-RAM**; Sub-exp 3 SURVIVED (delta_ratio 2.89) → **BUILD U2 routing-class field + U6 multi-routing coherence**. Authoritative resolution: [`2026-05-29-hadf-activation-orchid-validation-analysis.md`](2026-05-29-hadf-activation-orchid-validation-analysis.md) (CONFIRMED overlay) + [`HADF-SOURCE-OF-TRUTH.md` §-1](../../.claude/shared/hadf/HADF-SOURCE-OF-TRUTH.md). Capstone: fitme-story `37-orchid-research-arc.mdx`.

**Status:** consolidation note · supplementary to the v7.8.5 → v8.2 implementation plan
**Created:** 2026-05-12 (evening, post-PR #316/#317/#318/#319/#320/#321)
**Purpose:** (1) align the HADF Phase 2-bis project with the [Calibration Protocol](../master-plan/infra-master-plan-2026-05-12.md#35-calibration-protocol-for-new-layers) + external audit cadence introduced 2026-05-12; (2) add a per-phase **ORCHID analysis report** template so HADF's empirical hardware-fingerprinting evidence feeds ORCHID v2 design decisions phase-by-phase, not just at the synthesis stage; (3) document current hardware constraints (Chisel toolchain not installed → RTL blocked) and the research-advancement strategy that works within them.
**Predecessor docs:**
- [HADF Phase 2-bis spec](../superpowers/specs/2026-05-11-hadf-phase2bis-replication-design.md) (2,919 words)
- [HADF Phase 2-bis plan](../superpowers/plans/2026-05-12-hadf-phase2bis-replication.md) (2,422 lines, Block A SHIPPED PR #316)
- [ORCHID framework v7 mapping](2026-04-28-orchid-framework-v7-mapping.md) (research note)
- [ORCHID v1.5 additive units case study](../case-studies/orchid-v1-5-additive-units-case-study.md)
- [v7.8.5 → v8.2 implementation plan](../superpowers/plans/2026-05-12-framework-v7-8-5-to-v8-2-implementation-plan.md)
- [Orchid toolchain setup](../setup/orchid-toolchain-setup.md)

---

## §1 Why consolidate now

The HADF Phase 2-bis spec was drafted 2026-05-11. The Calibration Protocol + per-version external audit cadence landed 2026-05-12 (PR #319 + #321). Three gaps surfaced:

1. **HADF Phase 2-bis predates the Calibration Protocol** — sub-experiments don't reference Phase A → E walks or external audit checkpoints. They were designed with their own pre-registration + kill-criteria + verdict protocol but not the project-wide layer-stacking discipline.
2. **HADF data wasn't mapped to ORCHID phase-by-phase** — per the [ORCHID framework v7 mapping](2026-04-28-orchid-framework-v7-mapping.md), HADF generates the empirical evidence ORCHID v2 needs for design decisions on units U1–U9 (especially U1 Dispatch Scorer, U4 Batch Scheduler, U5 Speculative Prefetcher, and U7 Systolic Array — all of which have cloud-LLM-dispatch analogues). But the HADF plan §C16 cross-synthesis case study only mentions ORCHID in passing. Each sub-experiment should produce an ORCHID analysis report inline, not deferred to synthesis.
3. **Hardware constraints aren't documented** — the Chisel toolchain isn't installed on canonical (per [memory project_orchid_v1_5_paused_at_track_l_d.md](~/.claude/projects/-Volumes-DevSSD-FitTracker2/memory/project_orchid_v1_5_paused_at_track_l_d.md)). ORCHID Track R is blocked. But Layer A behavioral models, DSE runs, framework mapping research, and design notes can advance. The plan should explicitly say which research streams move forward and which stay parked.

---

## §2 Alignment Layer: HADF Phase 2-bis → Calibration Protocol

### §2.1 Phase mapping (HADF blocks ↔ Calibration Protocol phases)

| HADF block | Description | Maps to Calibration Phase | Cross-framework alignment |
|---|---|---|---|
| **Block A** (Tasks A0–A12, SHIPPED 2026-05-12) | Soak-window scaffolding — wrapper + heartbeat ledger + cost cron + smoke-fire + prereg lock + verdict script + plists + go/no-go runbook | **Phase A — Specify** (for HADF as a framework-instrumentation layer) | The wrapper + ledgers are themselves new framework infrastructure being calibrated. State.json `current_phase: tasks_phase`. |
| **Block A.5 — Production Exposure Planning** (NEW per §15.5 of v7.8.5→v8.2 plan) | Document which gates Sub-exp 1 commits will exercise + at what volume | **Phase A.5** | Inserted between A and B. Output: see §4.1 of this doc. |
| **Block B Sub-exp 1** (2026-05-23 → ~05-26) | Cloud generalization (9 endpoints, 6 providers, ~$3-4) | **Phase B — Ship advisory + measure** for the wrapper itself; primary data collection for HADF | First real-product gate-coverage data window for HADF infrastructure. |
| **Sub-exp 1 verdict + kill-criteria check** | PASS/FAIL/INCONCLUSIVE per spec §7 | **Phase C — Calibration gate** | If PASS, advances Sub-exp 2; if FAIL → halt + partial synthesis. |
| **Block B Sub-exp 2** (~2026-05-27 → 05-30) | Cloud-vs-local separability (Ollama on M2, $0) | **Phase B continued** | Validates the wrapper holds across endpoint-class diversity. |
| **Sub-exp 2 verdict** | Per spec §7 | **Phase C continued** | |
| **Block B Sub-exp 3** (~2026-05-31 → 06-03) | Decisive routing test (Bedrock haiku vs Anthropic-direct haiku, ~$1) | **Phase B continued + anchor-drift trip-wire** | The decisive routing claim test. |
| **Sub-exp 3 verdict + anchor-drift** | Per spec §7 | **Phase C continued** | |
| **Block C Synthesis case study** (~2026-06-04 → 06-07) | Cross-sub-exp synthesis answering 5 research questions per spec §6 | **Phase D — Promotion decision** for HADF (does v2 dispatch claim hold or refute?) | Decision: promote HADF Track 6 gate activation (out-of-scope of P2-bis but unblock-eligible post-synthesis), or halt. |
| **NEW: 7d post-synthesis validation** (~2026-06-07 → 06-14) | Continuous monitoring of any downstream consumers (Track 6 if it starts) | **Phase E — Post-promotion validation** | Standard layer-stacking rule: no new HADF-derived layer until E completes. |

### §2.2 Layer stacking rule applied to HADF Phase 2-bis

**Track 6 — HADF gate activation** (currently `Q3 = OUT` of Phase 2-bis scope per spec §1) becomes eligible **only after** Phase 2-bis reaches Phase E (~2026-06-14). This codifies what was already implicit in the plan — HADF Phase 2-bis must reach Phase E before Track 6 can build on its evidence.

Concretely: Track 6 spec writing can BEGIN during Block C synthesis (~2026-06-04 → 06-07) since spec writing isn't load-bearing. Track 6 IMPLEMENTATION cannot begin until 2026-06-14 (Phase E exit).

### §2.3 External audit alignment

Per [v7.8.5→v8.2 plan §15.3](../superpowers/plans/2026-05-12-framework-v7-8-5-to-v8-2-implementation-plan.md#1531-audit-cadence), three external audits cover the HADF Phase 2-bis window:

| Audit | Date | What it reviews for HADF |
|---|---|---|
| **Audit #1 — v7.9 promotion** | 2026-05-22 | Sub-exp 1 prereg + smoke-fire data quality before launch |
| **Audit #2 — v7.9.1 ship** | 2026-06-12 | Sub-exp 1 + 2 + 3 raw data integrity; verdict scripts; anchor-drift detection |
| **Audit #3 — v8.0 ship** | 2026-08-05 | Phase 2-bis synthesis case study integrity; ORCHID analysis reports (see §3) |

Each audit reviews the HADF evidence with the same 8 criteria from the framework's audit format (calibration data honesty, false positives, skip reasons, meta-check coverage, tier-tag accuracy, cross-repo asymmetry, layer-stacking compliance, reversibility rehearsal). For HADF specifically, criterion #1 (calibration data honesty) means: every `n_valid` claim in a sub-exp verdict must correspond to actual `.jsonl` rows in the raw dataset, not synthetic.

### §2.4 Framework concurrency contribution

HADF Phase 2-bis Sub-exp 1 commits during 2026-05-23 → 05-26 provide the **highest-density real-product calibration data** for v7.9 promotion (BRANCH_ISOLATION_VIOLATION + FEATURE_CLOSURE_COMPLETENESS). Per [v7.8.5→v8.2 plan §15.6](../superpowers/plans/2026-05-12-framework-v7-8-5-to-v8-2-implementation-plan.md#156-worked-example-v79-phase-a5-retrospective), HADF closure commits drive the ≥80% real-product fraction for these gates.

This is bidirectional: the framework calibrates against HADF commits, AND HADF benefits from the strengthened framework. Each sub-exp closure commit exercises FEATURE_CLOSURE_COMPLETENESS Q6 (PR parity) + Q7 (kill_criteria_resolution); if those gates surface a real defect during Sub-exp 1 closure, that defect would have shipped silently otherwise.

---

## §3 ORCHID Analysis Report Template (per phase)

### §3.1 Why per-phase ORCHID analysis matters

ORCHID v2 design decisions (per the [ORCHID framework v7 mapping](2026-04-28-orchid-framework-v7-mapping.md)) hinge on empirical hardware-diversity evidence:

- **U1 Dispatch Scorer:** how much variance in TTFT + TPS exists across cloud endpoints? Does the scorer need a 7-bit width or wider?
- **U4 Batch Scheduler:** how unstable are per-endpoint latencies? Does the FIFO + round-robin arbiter need a priority queue?
- **U5 Speculative Prefetcher:** how predictable is per-endpoint behavior across fires? Is `prefetch_ahead=0` still the right default at cloud scale?
- **U7 Systolic Array:** when latency spikes, is the bottleneck I/O (cloud) or compute (local Ollama)? Mesh sizing.
- **NEW v7.8 questions:** how does cloud-vs-local routing (Sub-exp 3) inform new units that would handle the cross-repo state-sync analogue at silicon?

Deferring all ORCHID analysis to Block C synthesis (~2026-06-07) loses the per-sub-exp insight that each experiment carries its own design implications. A per-phase report captures the insight while the data is fresh.

### §3.2 ORCHID Analysis Report — template structure

Each Sub-exp closure case study (`docs/case-studies/hadf-phase2bis-subexp{1,2,3}-case-study.md`) gets a final section:

```markdown
## §99 ORCHID Analysis Report

### §99.1 ORCHID units affected by this sub-experiment's data

For each of U1–U9, mark:
- **Touched:** Sub-exp data informs a design decision for this unit (yes/no)
- **Magnitude:** how much the data changes the v1.5 baseline (none / minor / major / paradigm shift)
- **Specific change implied:** one-line description (e.g., "U1 dispatch scorer needs wider input bus width: 13 → 16 bits to handle observed TTFT variance")

| Unit | Baseline | Touched | Magnitude | Specific change implied |
|---|---|---|---|---|
| U1 | scoreBits=7, inputBusWidth=13 | | | |
| U2 | maxSkills=16 | | | |
| U3 | cacheEntries=15, scratchpadKB=48 | | | |
| U4 | maxConcurrentTasks=8 | | | |
| U5 | predictionTableEntries=64 (rec 16) | | | |
| U6 | maxWriters=8 | | | |
| U7 | meshRows/Cols=8, dataWidth=16 | | | |
| U8 | patrol-scrubber cadence | | | |
| U9 | validation-bus arbiter | | | |

### §99.2 Quantitative summary (T1 claims with ledger evidence)

- Per-endpoint TTFT mean ± stddev (T1, derived from raw .jsonl)
- Per-endpoint TPS mean ± stddev (T1)
- Cross-endpoint silhouette score at k=5 (T1, this sub-exp's primary metric)
- Anchor-drift KS p-value (Sub-exp 3 only, T1)

### §99.3 Design-space-exploration implications

Per the 26K-run DSE findings in v1.5, certain ORCHID knobs showed zero impact on synthetic traces:
- `max_concurrent`
- `prediction_table_size`
- `mesh_rows/cols`

**Question per sub-exp:** does this sub-exp's data still suggest these knobs are no-op, or did real cloud diversity surface new sensitivity?

### §99.4 What this sub-exp does NOT inform

Explicit non-claims to prevent over-interpretation:
- e.g., "Sub-exp 1 does not inform U6 Coherence Unit since cloud endpoints don't share state."
- e.g., "Sub-exp 2 does not inform U7 Systolic Array since Ollama on M2 uses Metal compute, not a systolic array analogue."

### §99.5 Open questions for next sub-exp / Block C synthesis

Bullet list of questions raised but not answered. Feeds into the next sub-exp's prereg OR the cross-synthesis report.

### §99.6 Hardware-constraint reality check

Acknowledge what part of the ORCHID v2 work this data enables vs blocks:
- **Enabled:** behavioral-model parameter sweeps in Layer A (no Chisel needed)
- **Enabled:** DSE additional run targeting newly-surfaced design knobs
- **Enabled:** framework mapping research updates (this doc + v7-mapping note)
- **Blocked:** RTL implementation in Track R (Chisel toolchain not installed; see §5 below)
```

### §3.3 Per-sub-exp ORCHID analysis specifics

#### Sub-exp 1 (9 cloud endpoints, 6 providers) — ORCHID analysis focus

**Most-likely-touched units:** U1 (Dispatch Scorer — input variance), U4 (Batch Scheduler — per-endpoint latency stability), U5 (Speculative Prefetcher — predictability across fires).

**Specific question this sub-exp answers:** "Across 9 distinct cloud endpoints with 6 providers, how much TTFT variance exists, and does that variance justify a wider `inputBusWidth` than the v1.5 baseline of 13 bits?"

**Expected delta vs v1.5 baseline:** if silhouette ≥ 0.5 (success), endpoints fingerprint distinguishably → U1 must have enough bits to discriminate → likely recommendation `inputBusWidth=16` for v2.

#### Sub-exp 2 (Ollama on M2, 1 endpoint) — ORCHID analysis focus

**Most-likely-touched units:** U7 (Systolic Array — compute-bound on local vs I/O-bound on cloud), U3 (Cache Controller — local model fits in M2 RAM, cloud doesn't).

**Specific question this sub-exp answers:** "Is on-device Ollama distribution KS-distinguishable from any cloud endpoint? If yes, does that imply a new unit (or unit variant) for handling the routing decision in silicon?"

**Expected delta vs v1.5 baseline:** if Ollama distinguishable (p < 0.01), ORCHID v2 should consider a **routing-class indicator** (1-bit field) that flows alongside the dispatch decision. This isn't a new unit per se — it's a metadata field carried by U1's output to inform downstream units.

#### Sub-exp 3 (Bedrock haiku vs Anthropic-direct haiku, 3 endpoints) — ORCHID analysis focus

**Most-likely-touched units:** U2 (Skill Router — routing layer effects), U6 (Coherence Unit — does multi-routing-layer cache coherence behave differently?), U8 (Patrol Scrubber — does routing-layer drift surface as scrub work?).

**Specific question this sub-exp answers:** "Does the routing layer (Bedrock) introduce a distinguishable signature vs direct provider access (Anthropic API), implying that ORCHID v2 needs to model routing-layer overhead?"

**Expected delta vs v1.5 baseline:** if signature delta > within-provider variance (success), routing layers are a first-class hardware concern → U2 Skill Router design space gets a new dimension (routing-layer-aware vs direct-passthrough modes).

### §3.4 Block C synthesis ORCHID report

The cross-sub-exp synthesis case study (`docs/case-studies/hadf-phase2bis-cross-sub-exp-synthesis-case-study.md`) gets an expanded §99 ORCHID Analysis Report that:

1. **Consolidates** the per-sub-exp §99 sections into a unified change matrix
2. **Produces a v2 mapping update PR** — appends to `docs/research/2026-04-28-orchid-framework-v7-mapping.md` with the empirical evidence each sub-exp provided
3. **Outputs an ORCHID v2 spec stub** at `docs/superpowers/specs/2026-06-07-orchid-v2-design.md` listing the priority changes for the next ORCHID release (gated on Chisel toolchain availability for actual implementation)
4. **Decides Track 6 readiness** — does the synthesis evidence support HADF gate activation as a v8.0 feature? Or do specific kill criteria fire?

---

## §4 Hardware-Constraint Reality + Research-Advancement Strategy

### §4.1 Current constraints (2026-05-12)

| Constraint | What it blocks | What it doesn't block |
|---|---|---|
| **Chisel toolchain not installed** | ORCHID Track R RTL implementation; Phase 7+ RTL verification per [orchid-v1-5-additive-units case study](../case-studies/orchid-v1-5-additive-units-case-study.md) §12 | Behavioral models (Track L Layer A); design-space exploration (Track D additional runs); framework mapping research (this doc + 2026-04-28 note); ORCHID v2 spec writing |
| **No AWS Bedrock credentials** | Sub-exp 3 launch (until acquired) | Sub-exp 1 + Sub-exp 2 (no Bedrock dependency) |
| **DevSSD SanDisk Extreme disconnect issue** (≥4/day) | Long-running launchd campaigns at risk of mid-campaign hardware drop | Single-fire experiments + short collection windows; off-SSD backups still preserve data |
| **iOS UI test env-flake** (parallel-clone simulator hang, partially resolved PR #225) | Some hadf-relevant iOS-side UI verification | Code-side HADF dispatch logic (no UI tests needed) |
| **Single-operator team** | Parallel dogfood from multiple users | Sequential dogfood + external-replicator invitation |

### §4.2 Research streams that can advance NOW (no constraint)

These advance during the HADF Phase 2-bis window (2026-05-13 → 06-07) regardless of any hardware blocker:

1. **ORCHID v2 spec writing** — author `docs/superpowers/specs/2026-06-07-orchid-v2-design.md` (draft) at the same time as the HADF cross-synthesis case study. Both ship together.
2. **ORCHID v1.5 case study completion** — Sections 4-5 of [orchid-v1-5-additive-units-case-study.md](../case-studies/orchid-v1-5-additive-units-case-study.md) fill as DSE results land + Track R RTL completes. Today: complete the Section 4 DSE result narrative even though Track R is blocked; flag Section 5 as "pending Chisel toolchain availability."
3. **DSE additional runs** — Track D shipped a 26K-run sweep (per [orchid-v1-5 case study](../case-studies/orchid-v1-5-additive-units-case-study.md)). Additional runs targeting the v1.5 findings ("max_concurrent, prediction_table_size, mesh_rows/cols showed zero impact on synthetic traces") can run today. The DSE infrastructure is in the orchid repo, not gated on Chisel.
4. **Framework mapping research updates** — append to [2026-04-28-orchid-framework-v7-mapping.md](2026-04-28-orchid-framework-v7-mapping.md) as v7.8 / v7.8.1 / v7.8.3 land. Each new framework version asks: "is there a silicon analogue?"
5. **HADF data analysis tooling** — Block A shipped verdict + anchor-drift scripts. Additional analysis (per-endpoint variance characterization, cross-provider correlation analysis) can be authored as additional Python scripts that feed the ORCHID analysis reports.
6. **HADF Phase 2 external audit prep** — replication-pack tarball (queued in backlog) can be assembled today.
7. **Track 6 HADF gate activation spec** — can be drafted during Block C (~2026-06-04 onward) using HADF Phase 2-bis synthesis evidence. Implementation gates on Phase E (2026-06-14).

### §4.3 Research streams that can advance INCREMENTALLY (partial constraint)

These advance with caveats; full completion gated on constraint resolution:

1. **AWS Bedcrock credential acquisition** — separate operator task; once unblocked, Sub-exp 3 launches per the calendar. Decoupled from any code/research work.
2. **Chisel toolchain install** — per [orchid-toolchain-setup.md](../setup/orchid-toolchain-setup.md), this is a documented one-time setup. Could happen any time before ORCHID Track R Phase 6 (RTL). NOT on the critical path for v8.0; ORCHID v2 spec writing (advances NOW) is the upstream artifact.
3. **HADF on-device telemetry** — Sub-exp 2's Ollama on M2 run requires the operator's M2 to be available during the 3-day collection window. Hardware constraint is operator availability, not silicon.

### §4.4 What stays parked

These do NOT advance until specific blocker resolves:

1. **ORCHID Track R Phase 6+ RTL** — strictly blocked on Chisel toolchain.
2. **ORCHID Track R Level 1-4 RTL verification** — same.
3. **External replication of ORCHID** — gated on an external operator (Tier 3.3, GitHub issue #142).

### §4.5 Research-advancement sequence (2026-05-13 → 06-07)

Recommended sequence, leveraging the 25 days of HADF Phase 2-bis runtime:

| Window | HADF activity | ORCHID parallel research |
|---|---|---|
| 2026-05-13 → 22 (HADF pre-launch) | Sub-exp 1 prereg lock + smoke-fire prep | Author DSE additional runs targeting v1.5 zero-impact knobs (max_concurrent, prediction_table_size). Run on local DSE infra. |
| 2026-05-23 → 26 (Sub-exp 1 collection) | Operator monitors campaign; daily heartbeat audit | Begin Sub-exp 1 ORCHID analysis report draft (Sections 99.1, 99.2 populate as data lands). Append to framework-v7-mapping note any new v7.8 → silicon questions. |
| 2026-05-26 (Sub-exp 1 closure) | Verdict + case study + ORCHID §99 report | Finalize Sub-exp 1 §99; cross-link from v1.5 case study Section 4. |
| 2026-05-27 → 30 (Sub-exp 2 collection) | Ollama M2 campaign + audit | Sub-exp 2 ORCHID analysis report draft (cloud-vs-local routing implications for U2 + U7). |
| 2026-05-31 → 06-03 (Sub-exp 3 collection) | Bedrock vs Anthropic-direct + anchor-drift | Sub-exp 3 ORCHID analysis report draft (routing-layer fingerprint implications). |
| 2026-06-04 → 07 (Block C synthesis) | Cross-sub-exp synthesis case study | Author ORCHID v2 design spec at `docs/superpowers/specs/2026-06-07-orchid-v2-design.md` — folds all 3 sub-exp §99 reports into a coherent design proposal. Update framework-v7-mapping note v7-mapping → v8-mapping (renaming + extending to include v7.8.x). |
| 2026-06-07 → 14 (Phase E validation) | HADF closure monitoring | Begin Track 6 HADF gate activation spec draft (gated on synthesis verdict). DSE knob sensitivity from new runs feeds v2 spec. |

### §4.6 Constraint-removal triggers

When each constraint resolves, the corresponding stream advances to the next phase:

| Constraint | Resolution trigger | Next stream |
|---|---|---|
| Chisel toolchain | One-time `orchid-toolchain-setup.md` walk | ORCHID Track R Phase 6 RTL implementation begins; ORCHID v2 spec moves from "draft" to "plan" |
| AWS Bedrock credentials | Operator acquires + adds to `.env.local` | Sub-exp 3 launches per calendar |
| External replicator | Volunteer responds to GitHub #142 OR partner-engagement materializes | HADF Phase 2 external audit (still pending from 2026-05-01 ship) closes; HADF Phase 2-bis can request same |
| iOS UI test env-flake | Already resolved PR #225 (2026-05-05) | UI test re-expansion eligible v8.1+ per [backlog](../product/backlog.md) |
| DevSSD hardware | Drive replacement OR firmware update | Long-running campaigns become safe |

---

## §5 State.json updates required

The HADF Phase 2-bis state.json should add three fields to surface the consolidation:

```json
{
  "companion_research": [
    "docs/research/2026-05-12-hadf-phase2bis-orchid-integration.md"
  ],
  "calibration_protocol_phase": "B_pending",
  "external_audit_schedule": [
    {"audit_id": "audit-1-v7-9-promotion", "scheduled_date": "2026-05-22"},
    {"audit_id": "audit-2-v7-9-1-ship", "scheduled_date": "2026-06-12"},
    {"audit_id": "audit-3-v8-0-ship", "scheduled_date": "2026-08-05"}
  ]
}
```

**`companion_research`** — array of related research notes. Cross-referenced by integrity-check.py's pending file-existence checks (no new gate needed; existing `STATE_NO_CASE_STUDY_LINK` covers the primary `case_study` field; this is purely informational).

**`calibration_protocol_phase`** — enum: `A_specified` | `A5_exposure_planned` | `B_pending` | `B_running` | `C_calibrating` | `D_decided` | `E_validating` | `complete`. Maps the project's progress through the 6 calibration phases.

**`external_audit_schedule`** — array of audit checkpoints with scheduled dates. Each gets a deliverable at `docs/case-studies/meta-analysis/audit-<id>-<date>.md`.

These fields are additive; do NOT change existing gates. They're schema bridges that may become enforced in v8.0+ when the Calibration Protocol gets full Mechanism-A coverage.

---

## §6 Updates to HADF Phase 2-bis plan §B13–B15 + §C16

The existing plan ([2026-05-12-hadf-phase2bis-replication.md](../superpowers/plans/2026-05-12-hadf-phase2bis-replication.md)) has §B13/B14/B15 for the three sub-experiments and §C16 for the synthesis. Each gets new sub-tasks:

### §6.1 Sub-exp 1 (B13) — add sub-tasks

- **B13.13a — Author Sub-exp 1 ORCHID analysis report §99** per §3.3 of this doc. Append to `docs/case-studies/hadf-phase2bis-subexp1-case-study.md`. Cross-link from v1.5 case study Section 4 (cite explicit findings re: U1 inputBusWidth implication).
- **B13.13b — Append framework mapping update** to `docs/research/2026-04-28-orchid-framework-v7-mapping.md` capturing any v7.8-era questions surfaced by the Sub-exp 1 data.

### §6.2 Sub-exp 2 (B14) — add sub-tasks

- **B14.9a — Author Sub-exp 2 ORCHID analysis report §99** per §3.3. Focus on U7 (Systolic Array — cloud vs local compute bottleneck) + U2 (Skill Router — routing-class indicator field).
- **B14.9b — Cross-reference Sub-exp 1 findings** — does Sub-exp 2's data confirm or refute Sub-exp 1's hardware implications? Document.

### §6.3 Sub-exp 3 (B15) — add sub-tasks

- **B15.22a — Author Sub-exp 3 ORCHID analysis report §99** per §3.3. Focus on U2 (Skill Router — routing-layer-aware mode) + U6 (Coherence Unit — multi-routing-layer cache coherence).
- **B15.22b — Anchor-drift implications** — if drift detected (per the existing anchor-drift trip-wire B15.20–B15.21), append to §99 a hardware-side interpretation: does the drift imply a non-stationary fingerprint that needs runtime adaptation in U5 (Speculative Prefetcher)?

### §6.4 Block C synthesis (C16) — add sub-tasks

- **C16.6 — Author ORCHID v2 design spec stub** at `docs/superpowers/specs/2026-06-07-orchid-v2-design.md`. Draft only — implementation gated on Chisel toolchain availability. Sections: (1) what HADF Phase 2-bis proved about hardware diversity, (2) per-unit change matrix (U1–U9), (3) design-space implications, (4) deferred items pending Chisel.
- **C16.7 — Update framework mapping note** — rename `docs/research/2026-04-28-orchid-framework-v7-mapping.md` → keep at same path for ref-stability; extend content to cover v7.8 / v7.8.1 / v7.8.3 / v7.8.4 / v7.8.5 / v7.9 / v7.9.1. Each new framework version gets a row in the "v7.x capability → silicon analogue?" table.
- **C16.8 — Track 6 HADF gate activation spec** — draft only at `docs/superpowers/specs/2026-06-07-track-6-hadf-gate-activation-design.md`. Implementation gated on Phase 2-bis Phase E exit (~2026-06-14).

---

## §7 Cross-references + integration with other open work

### §7.1 Linkage to PR #321 (v7.8.5 → v8.2 implementation plan)

Per [v7.8.5→v8.2 plan §15.2.3](../superpowers/plans/2026-05-12-framework-v7-8-5-to-v8-2-implementation-plan.md#1523-v791-2026-06-04--06-11): "HADF Phase 2-bis cross-sub-exp synthesis case study (~2026-06-07) — 1–2 commits including the synthesis MDX in fitme-story (cross-repo flow)."

This consolidation note ADDS to that one or two commits:
- 1 commit for the ORCHID v2 design spec stub (`docs/superpowers/specs/2026-06-07-orchid-v2-design.md`)
- 1 commit for the framework mapping note extension
- 1 commit for the Track 6 spec draft
- Subtotal: 3 additional commits in the synthesis window

Total expected Phase 2-bis closure commits: 4–5 across both repos (was 1–2). Updates the v7.9.1 calibration data estimate upward.

### §7.2 Linkage to PR #319 (infra master plan §3.6 forward plan)

Per [infra master plan §3.6.4](../master-plan/infra-master-plan-2026-05-12.md): "**Track 6 HADF gate activation Feature becomes eligible** — Phase 2-bis closure (~2026-06-07)."

This consolidation note formalizes the Phase E exit date (~2026-06-14) as the actual unblock for Track 6 implementation. Spec drafting (C16.8) starts during Block C synthesis but isn't load-bearing — it's the implementation that gates on Phase E exit.

### §7.3 Linkage to ORCHID v1.5 case study

[`orchid-v1-5-additive-units-case-study.md`](../case-studies/orchid-v1-5-additive-units-case-study.md) Section 4 is currently labeled "fills as DSE results land + Track R RTL completes." This consolidation note adds: **Section 4 also fills with Sub-exp 1 ORCHID analysis §99 findings on U1 + U4 + U5** as those land (~2026-05-26).

The case study's `kill_criteria_resolution` field (per [v7.8.1 FEATURE_CLOSURE_COMPLETENESS gate](../../CLAUDE.md)) populates only after Track R RTL completes. The current `kill_criteria_resolution: pending` status is honest given the Chisel constraint.

### §7.4 Linkage to HADF Phase 2 (predecessor)

[HADF Phase 2 case study](../case-studies/hadf-phase2-cloud-fingerprinting-case-study.md) carries `external_audit_status: pending` (per [backlog item](../product/backlog.md) "HADF Phase 2 external audit"). HADF Phase 2-bis Sub-exp 1 effectively replicates Phase 2's cloud-fingerprinting experiment under tighter pre-registration + 4 architectural fixes. Sub-exp 1's verdict either confirms or refutes Phase 2's `silhouette=0.5566 at k=5` finding. **External audit of Phase 2-bis** (Audits #2 + #3 from §2.3 above) effectively also audits Phase 2 indirectly — if Sub-exp 1 doesn't replicate, Phase 2's published claim moves from `external_audit_status: pending` → `external_audit_status: refuted`.

---

## §8 What this doc is NOT

- **Not a new PRD for HADF Phase 2-bis.** The existing spec is authoritative; this doc adds the framework alignment + ORCHID per-phase analysis template on top.
- **Not a Chisel install plan.** [`orchid-toolchain-setup.md`](../setup/orchid-toolchain-setup.md) is authoritative for that.
- **Not a Track 6 PRD.** Track 6 spec drafting in C16.8 is a deliverable; the PRD spawns at Track 6 build start (~2026-06-14).
- **Not a state.json schema bridge enforced today.** §5 proposes new fields; they're additive and informational. Enforcement (if any) gates on v8.0+ Calibration Protocol Mechanism-A coverage.

---

## §9 Decisions captured by this doc

1. **Per-sub-exp ORCHID analysis reports** are required (not deferred to synthesis). Adds 3 sub-tasks per sub-exp closure.
2. **ORCHID v2 design spec stub** is a Block C deliverable, not gated on Chisel.
3. **Framework mapping note** extends with each v7.x release (rolling research artifact).
4. **Track 6 HADF gate activation** implementation gates on Phase 2-bis Phase E exit (~2026-06-14). Spec drafting can begin Block C (~2026-06-04).
5. **External audit schedule** for HADF Phase 2-bis aligns with framework audit cadence (Audits #1 / #2 / #3 cover the Phase 2-bis window).
6. **DSE additional runs** advance NOW (no Chisel dependency).
7. **HADF Phase 2 external audit** prep advances in parallel; replication-pack tarball assembly can begin any time.

---

## §10 Open questions raised by this consolidation

1. **Does Sub-exp 1's verdict need to clear `kill_criteria_resolution` per FEATURE_CLOSURE_COMPLETENESS Q7?** Sub-exp 1's case study sets `kill_criteria` per spec §7. If Sub-exp 1 PASSES, `kill_criteria_resolution = "no kill criteria fired"` is honest. If FAILS, the resolution narrates which criteria fired + what evidence supports the resolution. Either way, the Q7 gate fires on the closure commit per the v7.8.1 advisory.
2. **Should the ORCHID v2 spec stub use `case_study_type: "research_only"` or follow the standard 9-phase Feature workflow?** ORCHID v1.5 set the precedent at `case_study_type: "live_pm_workflow"` + `work_subtype: "research"`. v2 likely follows the same pattern.
3. **Should this consolidation note become a "v7.x → ORCHID v2 → Track 6" master rollup?** Today this doc is single-purpose. If Track 6 spec drafting reveals additional ORCHID-side decisions, the rollup may grow.
4. **Does the framework-mapping note rename from "v7-mapping" → "v7-8-mapping" → "v8-mapping" maintain ref-stability?** Per the `dev-guide-v1-to-v7-7.md` precedent (filename retained even though content covers v7.8+), the answer is: keep `2026-04-28-orchid-framework-v7-mapping.md` at the same path; extend content. Decision: **keep stable filename**.

---

## §11 Sign-off

This consolidation aligns HADF Phase 2-bis with the v7.8.5 → v8.2 framework plan + the Calibration Protocol introduced 2026-05-12 + the per-version external audit cadence. ORCHID per-phase analysis reports surface design insights every 3–7 days instead of every 25 days. Hardware constraints documented honestly with the advancement strategy that works within them.

Ship target: this note + state.json updates land via PR before HADF Phase 2-bis Sub-exp 1 launch (2026-05-23).
