# HADF Activation Readiness × ORCHID Architecture Validation — Comparative Analysis

**Date:** 2026-05-29
**Author:** session synthesis (FT2 `chore/freshness-reconcile-2026-05-29`)
**Type:** Research anchor / comparative analysis (research base)
**Framework version at authorship:** v7.9 (Phase E soak, 2026-05-21 → ~2026-06-04)
**Status:** **LIVING ANCHOR — not for publication yet.** Sub-exp 2 + Sub-exp 3 PENDING; conclusions scoped accordingly. This document is the single convergence point where the full HADF activation + ORCHID validation picture is assembled. It is completed (and only then considered for case-study publication) once Sub-exps 2 and 3 close and the Phase 2-bis synthesis verdict resolves.

## Completion plan (what lands here when the pending sub-exps close)

- **On Sub-exp 2 close (~2026-05-30+):** fill §1.3 device_modifier readiness with the KS p-value verdict; fill §2.2 U7/U3 rows with the compute-bound-vs-I/O-bound finding.
- **On Sub-exp 3 close (~2026-05-31+):** fill §1.3 routing-layer readiness with the delta_ratio verdict (confirm / inconclusive / refute); resolve §2.2 U2/U6 rows — including the negative case if delta_ratio < 1.0.
- **On Phase 2-bis synthesis verdict:** replace the "PARTIALLY SUPPORTED" disposition with the final synthesis result; recompute the recommended activation posture against the full modifier set.
- **Then, and only then:** consider promoting to a published fitme-story case study (slot ~37, `version: '7.9'`, `upstream_path` → this file). Until that point this anchor stays unpublished per operator decision 2026-05-29.

## Cross-references

- HADF Phase 2 case study: [`docs/case-studies/hadf-phase2-cloud-fingerprinting-case-study.md`](../case-studies/hadf-phase2-cloud-fingerprinting-case-study.md)
- HADF Phase 2-bis synthesis case study: [`docs/case-studies/hadf-phase2bis-cross-sub-exp-synthesis-case-study.md`](../case-studies/hadf-phase2bis-cross-sub-exp-synthesis-case-study.md)
- HADF v7.0 framework integration case study: [`docs/case-studies/hadf-hardware-aware-dispatch-case-study.md`](../case-studies/hadf-hardware-aware-dispatch-case-study.md)
- HADF↔ORCHID integration contract: [`docs/research/2026-05-12-hadf-phase2bis-orchid-integration.md`](2026-05-12-hadf-phase2bis-orchid-integration.md)
- ORCHID framework-v7 silicon mapping: [`docs/research/2026-04-28-orchid-framework-v7-mapping.md`](2026-04-28-orchid-framework-v7-mapping.md)
- ORCHID v1.5 spec: [`docs/superpowers/specs/2026-05-03-orchid-v1-5-design.md`](../superpowers/specs/2026-05-03-orchid-v1-5-design.md)
- Dispatch-intelligence integration point: [`.claude/shared/dispatch-intelligence.json`](../../.claude/shared/dispatch-intelligence.json)
- **Staged (dormant) capstone publication** built from this anchor: `fitme-story/content/04-case-studies/37-orchid-research-arc.mdx.draft` — NOT published (the `.mdx.draft` extension keeps it invisible to the site content loader). Prep spec: [`docs/superpowers/specs/2026-05-30-orchid-research-capstone-design.md`](../superpowers/specs/2026-05-30-orchid-research-capstone-design.md); publication-readiness plan: [`docs/superpowers/plans/2026-05-30-orchid-research-capstone-publication-readiness.md`](../superpowers/plans/2026-05-30-orchid-research-capstone-publication-readiness.md).

## Honesty preamble (project impartiality rule)

Only **Sub-exp 1** of HADF Phase 2-bis has closed (verdict: **PASS**). **Sub-exp 2** (cloud-vs-local separability) and **Sub-exp 3** (routing-layer falsification) are **PENDING**. The overall HADF dispatch claim therefore stands at **PARTIALLY SUPPORTED — cloud generalization only**, not "confirmed." Every conclusion below is annotated where it is load-bearing on data that does not yet exist. The Phase 2-bis synthesis verdict cell remains `PENDING` and this anchor must not be read as closing it.

Tier tags follow `docs/case-studies/data-quality-tiers.md`: **T1** instrumented, **T2** declared, **T3** narrative.

---

## Part 1 — Comparative analysis: HADF results vs. full framework activation

### 1.1 The two closed measurements

| Dimension | Phase 2 (Cloud Fingerprinting) | Phase 2-bis Sub-exp 1 (Cloud Generalization) | Δ |
|---|---|---|---|
| Silhouette @ best_k | **0.5566** [T1] | **0.7003** [T1] | **+0.144 / +25.8%** |
| best_k | 5 | 5 | stable |
| Endpoints | 1 (openai/gpt-4o-mini) | 4 (2 OpenAI + 2 Anthropic) | 4× |
| Providers | 1 usable | 2 | 2× |
| n_valid | 700 [T1] | 2,600 [T1] | 3.7× |
| Pre-reg floor | silhouette > 0.5 / n ≥ 600 | silhouette ≥ 0.5 / n ≥ 600 / clusters ≥ 3 | tighter |
| Valid rate | n/a (200 contaminated, excluded) | 92.86% (2,600 / 2,800) [T1] | clean |
| Cost | ~$5 nominal | **$0.324 actual** [T1] | ≈10× under 9-endpoint nominal |
| Kill criteria fired | none [T1] | none — all floors clear 8.7×–∞ [T1] | — |

**Per-endpoint medians (Sub-exp 1) [T1]:** openai/gpt-4o-mini TTFT 0.0296s / TPS 49.64; openai/gpt-4o TTFT 0.0163s / TPS 99.54; anthropic/claude-haiku-4-5 TTFT 0.9181s / TPS 152.93; anthropic/claude-sonnet-4-6 TTFT 1.3800s / TPS 67.98.

**Headline comparative finding [T3 over T1 data]:** the latency-fingerprint signal *strengthened* under endpoint diversity (0.5566 → 0.7003) while n grew 3.7× and provider count doubled, with the k=5 cluster structure preserved. The signature is **not openai-specific** — scoped to the 4-endpoint matrix; the full 9-endpoint matrix (Sub-exp 1B) remains queued.

### 1.2 What "full activation inside the framework" requires

HADF v7.0 shipped inert (`enabled: false`) as a `hardware_context` *input* to the v5.2/v6.0 dispatch engine (Extension-not-Replacement: the existing engine stays the decision-maker). A three-band confidence gate governs effect:

- **< 0.4** → HADF ignored; dispatch bit-for-bit identical to v5.2 (zero regression).
- **0.4–0.7** → advisory only (logged, no routing effect).
- **> 0.7** → hardware scores multiply routing weights (`device × cloud × network × battery`, each `[0.1–1.5]`).

"Full activation" = sustained operation in the **> 0.7 band with live modifiers**. The comparative question: do the measured silhouettes license that band, and across what scope?

### 1.3 Activation readiness

**Licensed by closed data (Sub-exp 1 PASS):**

- **Cloud-to-cloud routing discrimination.** Silhouette 0.7003 @ k=5 across 4 endpoints / 2 providers is strong separability — defensibly inside the >0.7 "trust the classifier" regime for the **cloud_modifier**.
- **Cost is a non-blocker.** $0.324 / 2,600 records removes the recalibration-cost objection to keeping the fingerprint table fresh.

**NOT yet licensed (gated on pending sub-exps):**

- **device_modifier / on-device branch** — gated on **Sub-exp 2** (Ollama llama3.2:3b on M2 vs cloud anchors; pre-reg KS p < 0.01). PENDING (~2026-05-30 launch). Activating the on-device branch first would be activation ahead of evidence.
- **routing-layer-aware dispatch** — gated on **Sub-exp 3** (Bedrock-haiku vs Anthropic-direct-haiku, model id held constant; pre-reg delta_ratio > 2.0 confirms, **< 1.0 REFUTES** HADF on the routing axis). PENDING (~2026-05-31+). A refutation contraindicates this activation regardless of Sub-exp 1.

**Recommended posture:** **scoped partial activation** — flip the cloud-provider discrimination modifier into >0.7; hold device/local and routing-layer modifiers ≤0.7 (advisory) until Sub-exps 2 & 3 close. The zero-regression gate guarantees the staged flip carries no risk to the system-wide guardrails (crash-free >99.5%, dispatch unchanged below threshold).

### 1.4 Why the activation decision is trustworthy

1. **Pre-registration with falsification floors** — thresholds + kill criteria locked before data (`phase2-preregistration.json`, `preregistration-phase2bis-subexp1.json`); Sub-exp 3 pre-registers a *refutation* floor. The activation decision can't be retrofitted to the result.
2. **Contamination segregated, not silently dropped** — Phase 2's 200 environment-failure records excluded via `ok=true` filter and disclosed; 0.5566 is on clean data.
3. **External audit chain** — Audit #2 (2026-06-12) covers raw `.jsonl` integrity + verdict scripts + anchor-drift before any v7.9.1 ship.

---

## Part 2 — How the results validate and strengthen ORCHID

ORCHID (Orchestration Intelligence Device) is the RISC-V accelerator turning the framework's dispatch-intelligence patterns into silicon analogues (units U1–U9). HADF and ORCHID are formally coupled: per the integration contract, **"HADF generates the empirical evidence ORCHID v2 needs for design decisions on units U1–U9."** Each HADF sub-exp closure is contracted to emit an ORCHID analysis report (§99). This discharges specific ORCHID design risks.

### 2.1 Validation that has landed (Sub-exp 1)

- **U1 Dispatch Scorer — input bus width (13 bits).** Open v2 question: does cloud variance force 16 bits? Sub-exp 1's high silhouette with *clean* k=5 separation means endpoints occupy well-separated regions rather than a smeared continuum — distinguishability via **separation, not dynamic range**. This **validates the 13-bit choice** and lets v2 keep the narrower, cheaper bus with empirical backing.
- **U4 Batch Scheduler / U5 Speculative Prefetcher — per-endpoint stability.** Stable, separable per-endpoint TTFT/TPS profiles over 700 dispatches each are exactly the precondition U4's round-robin arbiter and U5's BTB-style predictor assume — strengthening the DSE-reduced **16-entry** prediction table over the original 64.
- **Tier propagation (shared primitive).** ORCHID v1.5 lands T1/T2/T3 as 2-bit `user[1:0]` on TileLink (`user[7:2]` reserved for v2.0). HADF's experiments are themselves rigorously tier-tagged at n=2,600 — demonstrating the 2-bit tier vocabulary survives real measurement at scale, **validating the reserve-don't-spend ABI bet**.

### 2.2 Validation still PENDING (explicit)

| ORCHID v2 fork | Depends on | Status |
|---|---|---|
| **U7 Systolic Array** sizing (8×8 vs 16×16) — compute-bound local vs I/O-bound cloud | Sub-exp 2 | PENDING — if local is memory-bound, revives the DRAM-patrol question deferred in U8 |
| **U3 Cache Controller** model (local fits in RAM, cloud doesn't) | Sub-exp 2 | PENDING |
| **U2 Skill Router** routing-layer-aware mode + routing-class field | Sub-exp 3 | PENDING — **falsifiable** (delta < 1.0 → do NOT build it) |
| **U6 Coherence Unit** multi-routing-layer coherence | Sub-exp 3 | PENDING |

The strengthening here is structural: v2 has pre-committed which unit each verdict touches **including the negative case** — protecting the architecture from confirmation bias.

### 2.3 Meta-validation: the methodology mirrors U8/U9

- **U9 Validation Bus** (mandatory trap channel + advisory counter channel) is the silicon form of HADF's pre-registered pass/fail (mandatory) vs. interpretive narrative (advisory). HADF showing this two-channel discipline yields trustworthy verdicts at n=2,600 is field evidence for U9's split.
- **U8 Patrol Scrubber** (periodic self-audit; detect-and-raise, not mask) is the silicon analogue of the 72h integrity cycle + Phase 2's segregate-and-disclose of 200 contaminated records.

HADF thus field-tests ORCHID's *validation philosophy* (pre-register, tier-tag, segregate, audit) at software speed before it is committed to RTL — relevant because Track R (Layer B Chisel RTL) is currently **BLOCKED** on toolchain install, so the behavioral/empirical case is the only forward motion available.

---

## Net assessment

- **Framework activation:** data licenses a **scoped partial activation now** (cloud-provider modifier → >0.7); device-local and routing-layer modifiers held advisory until Sub-exps 2 & 3 close. Zero-regression gate makes the staged flip safe.
- **ORCHID:** Sub-exp 1 **validates and strengthens** the U1 bus-width, tier-propagation, and U4/U5 scheduling decisions, and field-tests the U8/U9 validation philosophy. U2/U3/U6/U7 forks remain **honestly pending** on the two unfinished sub-exps, one of which (Sub-exp 3) can *refute* a v2 design dimension.

**Two standing caveats:** (1) the strongest interpretive claims are **T3 narrative over T1 data, scoped to 4 endpoints** — Sub-exp 1B (full 9-endpoint matrix) is queued; (2) the Phase 2-bis synthesis verdict is correctly still `PENDING` and must not be phrased as closed.

---

## Capstone fill-in map

This anchor is the single source of truth for the staged (dormant) capstone
publication `fitme-story/content/04-case-studies/37-orchid-research-arc.mdx.draft`.
There are **three** fill-in marker types; each closes from a specific verdict,
populates a specific anchor cell, and lands in a specific capstone section. At
closure, replace each marker with the selected both-outcomes branch — no creative
reframing. (Added 2026-05-30 by the capstone-prep pass; this section is additive —
no PENDING cell above was resolved and no number was changed.)

| Marker (in the draft) | Closes from | Anchor cell it resolves | Capstone section(s) |
|---|---|---|---|
| `FILL ON SUB-EXP 2` | Sub-exp 2 verdict (~2026-05-30; KS p < 0.01) | §1.3 device_modifier readiness; §2.2 U7/U3 rows | §5, §6 |
| `FILL ON SUB-EXP 3` | Sub-exp 3 verdict (~2026-05-31; delta_ratio, **falsifiable** < 1.0) | §1.3 routing-layer readiness; §2.2 U2/U6 rows (incl. negative case) | §5, §6 |
| `FILL ON SYNTHESIS VERDICT` | Phase 2-bis synthesis (~2026-06-04) | replaces the `PARTIALLY SUPPORTED` disposition; recomputes activation posture | §6, §7 |
