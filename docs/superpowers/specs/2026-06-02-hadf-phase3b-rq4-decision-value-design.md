# HADF Phase 3B — RQ4 Decision-Value Experiment (design DRAFT — NOT a locked pre-registration)

> **Status:** DESIGN DRAFT, 2026-06-02. This is the **next testing phase** of HADF Phase 3 (SoT §10). It is **NOT a pre-registration** — it must not be locked. Several design parameters are **OPERATOR DECISIONS** (marked ⚠️ below); the prereg ceremony (sha + `.lock` + tag) happens only after those are chosen, the design is reviewed, and Phase 2-bis has closed. This draft exists so the design conversation can start now.

## 1. Why RQ4 exists
HADF Phase 2-bis proved the **sensing layer** — streaming signatures are real, provider-general, substrate-discriminating, and short-term-stable. It did **not** prove the **acting layer**: that *routing on* those signatures improves any real outcome. RQ4 is the falsifiable test of the acting layer, and it is the gate for full HADF *dispatch* activation. Distinguishability ≠ actionability — RQ4 closes exactly that gap.

## 2. Research question
**Does signature-aware routing improve a real dispatch outcome vs. a baseline routing policy, by a pre-registered margin?**

**Hypothesis:** routing each request to the endpoint whose live signature predicts the best outcome for that request beats a naive baseline. **Falsification:** if signature-aware routing is ≤ baseline on the primary metric, the *dispatch* premise is refuted (sensing still stands; HADF stays a sensing-only framework).

## 3. Design (controlled comparison)
- **Arms:** A = baseline policy; B = signature-aware routing. Interleaved or randomized assignment over the same workload to control for time-of-day/load.
- **Unit:** one dispatched task/request.
- **Routing-under-test (Arm B):** policy maps request context + current endpoint signatures → endpoint choice. ⚠️ exact policy TBD (e.g. "pick lowest-predicted-TTFT endpoint meeting a quality guardrail").

## 4. ⚠️ OPERATOR DECISIONS required before pre-registration
1. **Primary outcome metric (pick ONE):** p95 end-to-end latency per *successful* task / cost-per-successful-task / task-quality score. (Recommend a **latency or cost** primary with a **quality guardrail**, so B can't win by trading quality away.)
2. **Baseline (Arm A):** round-robin / static-cheapest / static-fastest / current production policy.
3. **Pass margin:** how much must B beat A by to PASS (e.g. ≥10% p95 latency reduction)? **Kill if B ≤ A.**
4. **Quality guardrail:** B must not degrade task quality below a floor (prevents latency/cost wins at quality's expense).
5. **Workload / task set:** which real tasks (orchid dispatch jobs / agent tasks / app AI calls) + endpoint pool.
6. **Sample size / power:** N per arm for the chosen margin + variance (Sub-exp 2 showed huge TPS tails → power calc must use realistic variance).
7. **Duration / schedule:** must span ≥ a full diurnal cycle (latency is time-of-day sensitive); spaced from any other live HADF collector (the 2h-gap discipline from the parallel sub-exps).

## 5. Confounds to control
- Time-of-day / load (→ interleaved assignment, full-diurnal span).
- Model-quality trade (→ quality guardrail, #4).
- Signature drift mid-experiment (→ lock endpoint set; monitor with the 3A drift monitor).
- Cold-start bias (Bedrock cold-start ~1.9s seen in Sub-exp 3 → warm-up or model it).

## 6. Companion: RQ5 + RQ6 (defined, not detailed here)
- **RQ5** — single-shot/few-shot classification accuracy (online, not distribution KS). Needed because Arm B routes from few samples; 3A attestation stays advisory until RQ5 passes.
- **RQ6** — long-horizon drift monitor (weeks/months) → recalibration cadence for production.

## 7. Gating & sequencing
- RQ4 **pre-registration ceremony** (operator-confirmed §4 choices → sha + `.lock` + signed tag) happens **after** Phase 2-bis closes (~06-05) + this design is reviewed.
- Full HADF *dispatch* activation requires **RQ4 PASS**. Until then, only Phase 3A (sensing) ships.
- Mirrors the program's existing discipline: pre-register thresholds + kill criteria, no hedging, falsifiable.

## 8. Cross-references
- SoT §9 (activation extrapolation) + §10 (Phase 3 roadmap).
- Phase 3A sensing build spec: `2026-06-02-hadf-phase3a-sensing-layer-design.md`.
- Method precedent: Sub-exp 3 verdict (`signature_delta_ratio`) + Sub-exp 2 verdict (`--metric ks`).
