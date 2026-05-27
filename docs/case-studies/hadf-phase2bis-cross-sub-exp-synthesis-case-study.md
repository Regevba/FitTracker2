---
title: HADF Phase 2-bis — Cross-Sub-Exp Synthesis (3 Sub-Experiments)
slug: hadf-phase2bis-cross-sub-exp-synthesis
date_written: TBD — populated at Block C closure (~2026-06-04)
date: TBD
work_type: Feature
work_subtype: measurement_study_synthesis
dispatch_pattern: subagent-driven (Block A) + operator-driven (Block B/C)
framework_version: v7.8.3
state_owner: ft2
case_study_type: measurement_study_synthesis
primary_metric: "HADF dispatch claim status across 3 sub-experiments: confirmed / refuted / inconclusive (binary verdict per spec §1 RQ3)"
success_metrics:
  primary: "Sub-exp 3 routing test signature_delta_ratio > 2.0 between Bedrock haiku-4-5 and Anthropic-direct haiku-4-5 — confirms HADF dispatch premise"
  secondary:
    - "Sub-exp 1 silhouette ≥ 0.5 with cluster_count ≥ 3 across cloud endpoints (cloud generalization replicates Phase 2 baseline of 0.5566 at k=5)"
    - "Sub-exp 2 Ollama-vs-cloud KS-distinguishability p < 0.01 (local-vs-cloud separability)"
    - "Sub-exp 1 anchor signatures (openai/gpt-4o-mini + anthropic/claude-haiku-4-5) reproduce in Sub-exp 3 within 2σ drift threshold (no cross-window infrastructure drift)"
kill_criteria:
  - "Any sub-exp tripped per-sub-exp kill criteria (n_valid floor, rate-limit cascade, mid-collection protocol change, wrapper preflight failures) — see per-sub-exp prereg JSONs"
  - "Sub-exp 3 anchor drift > 2σ from Sub-exp 1 — invalidates routing-test comparison (halt + investigate before drawing routing conclusions)"
  - "Sub-exp 3 signature_delta_ratio < 1.0 — HADF dispatch premise REFUTED on this metric (operator decides claim revision)"
kill_criteria_resolution: TBD — populated when all 3 sub-exps close + anchor-drift check runs (~2026-06-04)
tier_tags_present: true
status: draft
external_audit_status: pending  # External Audit #2 scheduled 2026-06-12 covers this case study + verdict scripts
related_prs: [306, 313, 316, 506, 507]  # extended at Block C closure with verdict-run PRs (B14, B15) + case study merge PR
predecessor_case_studies:
  - docs/case-studies/hadf-phase2-cloud-fingerprinting-case-study.md
spec_path: docs/superpowers/specs/2026-05-11-hadf-phase2bis-replication-design.md
plan_path: docs/superpowers/plans/2026-05-12-hadf-phase2bis-replication.md
preregistration_paths:
  subexp1: .claude/shared/hadf/preregistration-phase2bis-subexp1.json
  subexp2: .claude/shared/hadf/preregistration-phase2bis-subexp2.json
  subexp3: .claude/shared/hadf/preregistration-phase2bis-subexp3.json
case_study_showcase: fitme-story/content/04-case-studies/30-hadf-phase2bis-cross-sub-exp-synthesis.mdx
external_audit_schedule:
  - audit-1-v7-9-promotion: 2026-05-22 (scope: Sub-exp 1 prereg + smoke-fire data quality)
  - audit-2-v7-9-1-ship: 2026-06-12 (scope: Sub-exps 1-3 raw data integrity + verdict scripts + THIS case study)
  - audit-3-v8-0-ship: 2026-08-05 (scope: Block C synthesis case study + ORCHID v2 design stub)
---

# HADF Phase 2-bis — Cross-Sub-Exp Synthesis Case Study

> **Status:** DRAFT skeleton authored 2026-05-27 (Phase E Day 6) as Block C task C16 pre-work. Sections are pre-structured with TBD markers; the operator populates each as the sub-exp verdicts land. **The pre-ceremony skeleton exists to ensure the synthesis is mechanical-not-creative at Block C closure** — every section's analytical structure is fixed before the data lands, eliminating after-the-fact narrative drift.
>
> **Authoritative spec:** [`docs/superpowers/specs/2026-05-11-hadf-phase2bis-replication-design.md`](../superpowers/specs/2026-05-11-hadf-phase2bis-replication-design.md) — full requirements, threat model, acceptance criteria, and per-sub-exp design live there.
>
> **Predecessor:** [HADF Phase 2 — Cloud Fingerprinting Measurement](./hadf-phase2-cloud-fingerprinting-case-study.md) (shipped 2026-05-01, silhouette 0.5566 at k=5, n=700 across 2 endpoints).

## §1 What's measured (3 sub-experiments + 1 synthesis)

Per spec §1, three sub-experiments answer three orthogonal research questions about the HADF dispatch premise:

| Sub-exp | Research question | Endpoints | Schedule | Primary metric |
|---|---|---|---|---|
| Sub-exp 1 | Does the silhouette signature reproduce on cloud endpoints beyond OpenAI direct? | 9 cloud (6 providers) | 5 fires/day × 3 days × 9 endpoints × 50 calls = 6,750 nominal | Silhouette score at k=5 ≥ 0.5 |
| Sub-exp 2 | Can we distinguish Ollama-on-M2 from cloud endpoints by signature alone? | 1 (Ollama llama3.2:3b) | 5 × 3 × 1 × 50 = 750 nominal | KS-distinguishability p < 0.01 |
| Sub-exp 3 | Does AWS Bedrock haiku-4-5 fingerprint differently from Anthropic-direct haiku-4-5? | 3 (2 anchors + 1 Bedrock target) | 5 × 3 × 3 × 50 = 2,250 nominal | Signature delta ratio > 2.0 |
| Synthesis (this case study) | Overall HADF dispatch claim status across the 3 verdicts | n/a | n/a | confirmed / refuted / inconclusive |

**Total nominal records across all 3 sub-exps:** 9,750. **Total expected valid:** ~5,600. **Total cost:** ~$5 expected, $20 ceiling. **Total wall-clock:** ~15 days (9 collection + ~6 buffer).

### Sub-exp 1A vs 1B note (per Sub-exp 1 locked prereg's `launch_matrix_narrowing`)

Sub-exp 1 launched 2026-05-25 with a **narrowed 4-endpoint matrix** (openai gpt-4o-mini + gpt-4o + anthropic claude-haiku-4-5 + claude-sonnet-4-6) instead of the originally-specified 9 endpoints. Operator decision 2026-05-25: 3 endpoints excluded (gemini-2.5-flash/pro for reasoning-model TTFT distortion; vercel-ai-gateway/mistral/xai for placeholder API keys not yet minted). Sub-exp 1B is queued as a successor run after key acquisition + reasoning-model investigation to exercise the full 9-endpoint matrix.

**Implication for this synthesis:** Sub-exp 1 verdict in §3.A reflects 1A's 4-endpoint data; Sub-exp 1B (if it runs before Block C closure) is treated as an additional data point per §3.A.1 below.

## §2 PR chain of custody

| PR | Repo | Role | Status |
|---|---|---|---|
| #306 | FT2 | Phase 2-bis research note | Merged |
| #313 | FT2 | Implementation plan PR | Merged |
| #316 | FT2 | Block A — soak window scaffolding (state.json + harness + preflight + verdict scripts + launchd plist templates + 6 unit test suites + go/no-go ceremony runbook) | Merged 2026-05-12 |
| #506 | FT2 | chore — Sub-exp 2 prereg pre-ceremony fill-in (B14.2 prep) | Merged 2026-05-27 |
| #507 | FT2 | chore — Sub-exp 3 prereg pre-ceremony fill-in (B15.2 prep) | Merged 2026-05-27 |
| TBD-B13 | FT2 | Sub-exp 1 verdict run + case study | Pending ~2026-05-28 |
| TBD-B14 | FT2 | Sub-exp 2 verdict run + case study | Pending ~2026-05-31 |
| TBD-B15 | FT2 | Sub-exp 3 verdict run + case study | Pending ~2026-06-04 |
| TBD-C | FT2 | Block C — this synthesis case study + fitme-story showcase slot 30 + state.json closure | Pending ~2026-06-04 (this PR) |

## §3 Per-sub-exp verdicts (populated as each sub-exp closes)

### §3.A Sub-exp 1 — Cloud generalization

**Verdict:** TBD (populate after B13.5 verdict-script run)

**Pre-registered pass criteria** (per [`preregistration-phase2bis-subexp1.json`](../../.claude/shared/hadf/preregistration-phase2bis-subexp1.json) `verdict_thresholds`):

- `pass_silhouette_min`: 0.5 (Phase 2 baseline: 0.5566)
- `pass_yield_min`: 600
- `fail_clusters_lt`: 3

**Observed values** (populate from verdict-script output):

| Metric | Threshold | Observed | Pass/Fail |
|---|---|---|---|
| Silhouette at best_k | ≥ 0.5 | TBD | TBD |
| best_k value | n/a | TBD | n/a |
| n_valid total | ≥ 600 | TBD | TBD |
| cluster_count at best_k | ≥ 3 | TBD | TBD |
| cluster_endpoint_purity | ≥ 0.8 | TBD | TBD |

**Per-endpoint summary** (4 endpoints in 1A):

| Provider | Endpoint | n_valid | Median TTFT | Median TPS | Cluster assignment |
|---|---|---|---|---|---|
| OpenAI | gpt-4o-mini | TBD | TBD | TBD | TBD |
| OpenAI | gpt-4o | TBD | TBD | TBD | TBD |
| Anthropic | claude-haiku-4-5 | TBD | TBD | TBD | TBD |
| Anthropic | claude-sonnet-4-6 | TBD | TBD | TBD | TBD |

**Interpretation:** TBD — populated at verdict time. Expected narrative:
- If silhouette ≥ 0.5 + cluster_count ≥ 3: the Phase 2 single-endpoint signature reproduces across multiple providers → cloud generalization confirmed → Sub-exp 2 may launch.
- If silhouette < 0.5: signature is openai-specific or 9→4 narrowing dropped a cluster-defining provider → operator decides Sub-exp 1B path (full 9-endpoint follow-up) vs. revising the HADF claim.

#### §3.A.1 Sub-exp 1B (if shipped before Block C closure)

TBD — Sub-exp 1B exercises the full 9-endpoint matrix (per spec §2). If it runs before this case study lands, append a row to the per-endpoint table above + note any verdict-direction changes vs 1A.

### §3.B Sub-exp 2 — Cloud-vs-local separability

**Verdict:** TBD (populate after B14.5 verdict-script run)

**Pre-registered pass criteria** (per [`preregistration-phase2bis-subexp2.json`](../../.claude/shared/hadf/preregistration-phase2bis-subexp2.json) `verdict_thresholds` — operator finalizes at B14 ceremony):

- `pass_ks_p_max`: TBD (suggested 0.01 per spec §1 RQ2)
- `pass_yield_min`: TBD (suggested 150)
- `fail_if_ks_p_greater_than`: TBD (suggested 0.05)

**Observed values:**

| Metric | Threshold | Observed | Pass/Fail |
|---|---|---|---|
| KS p-value vs openai/gpt-4o-mini | ≤ pass_ks_p_max | TBD | TBD |
| KS p-value vs anthropic/claude-haiku-4-5 | ≤ pass_ks_p_max | TBD | TBD |
| n_valid Ollama | ≥ pass_yield_min | TBD | TBD |
| Ollama median TTFT | n/a | TBD | n/a |
| Ollama median TPS | n/a | TBD | n/a |

**Interpretation:** TBD. Expected narrative:
- If KS p < pass_ks_p_max vs both cloud anchors: local execution produces a signature distinguishable from cloud → cloud-vs-local separability confirmed → Sub-exp 3 may launch.
- If KS p > 0.05 vs ALL cloud anchors: Ollama-on-M2-3b is indistinguishable from cloud on this metric → operator decides whether to weaken Sub-exp 2's hypothesis or queue follow-up (different local model, different metric, different M2 thermal regime).

### §3.C Sub-exp 3 — Routing test (the central HADF claim)

**Verdict:** TBD (populate after B15.5 verdict-script run)

**This is the FALSIFICATION test for the central HADF dispatch claim.** Same model id (`anthropic.claude-haiku-4-5`) served by 2 providers (Anthropic-direct + AWS Bedrock); if signatures differ enough to clear within-provider noise floor → HADF dispatch premise holds; if indistinguishable → HADF refuted on this metric.

**Pre-registered pass criteria** (per [`preregistration-phase2bis-subexp3.json`](../../.claude/shared/hadf/preregistration-phase2bis-subexp3.json) `verdict_thresholds` — operator finalizes at B15 ceremony):

- `pass_signature_delta_ratio_min`: TBD (suggested 2.0)
- `fail_if_signature_delta_ratio_lt`: TBD (suggested 1.0)
- `pass_anchor_drift_p_value_min`: TBD (suggested 0.01)
- `pass_yield_min`: TBD (suggested 450)

**Observed values:**

| Metric | Threshold | Observed | Pass/Fail |
|---|---|---|---|
| signature_delta_ratio (Bedrock vs Anthropic-direct haiku-4-5) | ≥ pass_signature_delta_ratio_min | TBD | TBD |
| Bedrock median TTFT | n/a | TBD | n/a |
| Bedrock median TPS | n/a | TBD | n/a |
| Anthropic-direct (this run) median TTFT | n/a | TBD | n/a |
| Anthropic-direct (this run) median TPS | n/a | TBD | n/a |
| Within-Anthropic intra-provider variance (Sub-exp 1 reference) | n/a | TBD | n/a |
| Anchor drift (Sub-exp 1 → Sub-exp 3 anchors) | KS p ≥ pass_anchor_drift_p_value_min | TBD | TBD |
| n_valid total | ≥ pass_yield_min | TBD | TBD |

**Verdict logic** (3 outcomes per Sub-exp 3 prereg `_verdict_logic_note`):

| Delta ratio range | HADF claim status |
|---|---|
| > 2.0 | **Confirmed** — Bedrock haiku clearly outside Anthropic-direct's noise floor → routing produces distinguishable signatures |
| 1.0 ≤ ratio ≤ 2.0 | **Inconclusive** — may need higher-n run or different metric |
| < 1.0 | **Refuted on this metric** — Bedrock + Anthropic-direct indistinguishable within Anthropic's intra-provider noise |

## §4 Anchor drift analysis (Sub-exp 1 → Sub-exp 3)

**KS-test p-value comparing Sub-exp 1's anchor distributions vs Sub-exp 3's anchor distributions:**

- openai/gpt-4o-mini Sub-exp 1 vs Sub-exp 3: TBD
- anthropic/claude-haiku-4-5 Sub-exp 1 vs Sub-exp 3: TBD

**Trip-wire status:** TBD (per Sub-exp 3 prereg `trip_wires.anchor_drift`). If KS p < 0.01 for either anchor, append methodology note here describing the drift magnitude + impact on Sub-exp 3 routing verdict confidence. Do NOT halt — drift is methodology, not invalidation.

**`scripts/hadf-phase2bis-anchor-drift-check.py` output:** TBD — capture verbatim at synthesis time.

## §5 Overall HADF dispatch claim status

**Synthesis verdict:** TBD — populate ONLY after all 3 sub-exp verdicts + anchor-drift check are in.

Decision matrix:

| Sub-exp 1 | Sub-exp 2 | Sub-exp 3 | Synthesis |
|---|---|---|---|
| PASS | PASS | PASS (delta > 2.0) | **HADF dispatch claim CONFIRMED** — cloud generalization + local-vs-cloud separability + routing-distinguishability all met |
| PASS | PASS | INCONCLUSIVE (1.0 ≤ delta ≤ 2.0) | **HADF dispatch claim PARTIALLY SUPPORTED** — cloud + local separable, but same-model-different-provider routing inconclusive; queue follow-up |
| PASS | PASS | REFUTED (delta < 1.0) | **HADF dispatch claim REFUTED on routing axis** — cloud signatures separable BUT same-model-different-provider routing produces no distinguishable signature; revise claim |
| PASS | FAIL | n/a (Sub-exp 3 doesn't launch) | **HADF dispatch claim PARTIALLY SUPPORTED** — cloud generalization confirmed but local-vs-cloud separation not on this metric; document scope limitation |
| FAIL | n/a | n/a (downstream sub-exps don't launch) | **HADF dispatch claim CANNOT be confirmed by this measurement** — cloud signature did not reproduce beyond Phase 2's openai-direct baseline; document scope limitation + Phase 2 result stands alone |

**Observed combination:** TBD

**Synthesis verdict:** TBD

**Implications for ORCHID v2 design stub** (per external-audit-3 scope 2026-08-05): TBD — depends on synthesis verdict. If CONFIRMED, ORCHID v2 can claim routing-tier signature as a dispatch input. If REFUTED, ORCHID v2 dispatch logic on the routing axis must be revised or removed.

## §6 Methodology notes (per-sub-exp deviations + cross-sub-exp observations)

TBD — captured at synthesis time. Include:

- Any trip-wires that fired (didn't abort but flagged): anchor_drift, cost_overrun_3x, ollama_thermal_anomaly, bedrock_haiku_version_drift
- Any prereg field changes between draft (PR #506/#507) and lock (operator ceremony): list each `_TBD_at_ceremony` field's final value + rationale
- Any operator narrowing decisions (like Sub-exp 1A's 9→4 narrowing): document + provide forward-pointer to Sub-exp 1B follow-up runbook
- Cost actuals vs spec §2 nominal (Sub-exp 1 $3-4 + Sub-exp 2 $0 + Sub-exp 3 $1 = $4-5 nominal)
- Wall-clock actuals vs spec §4 (15 days nominal: 9 collection + 6 buffer)

## §7 References

- Predecessor: [HADF Phase 2 case study](./hadf-phase2-cloud-fingerprinting-case-study.md)
- Spec: [`docs/superpowers/specs/2026-05-11-hadf-phase2bis-replication-design.md`](../superpowers/specs/2026-05-11-hadf-phase2bis-replication-design.md)
- Plan: [`docs/superpowers/plans/2026-05-12-hadf-phase2bis-replication.md`](../superpowers/plans/2026-05-12-hadf-phase2bis-replication.md)
- Feature state: [`.claude/features/hadf-phase2bis-replication/`](../../.claude/features/hadf-phase2bis-replication/)
- Sub-exp 1 prereg: [`.claude/shared/hadf/preregistration-phase2bis-subexp1.json`](../../.claude/shared/hadf/preregistration-phase2bis-subexp1.json) (LOCKED in impl repo 2026-05-25)
- Sub-exp 2 prereg: [`.claude/shared/hadf/preregistration-phase2bis-subexp2.json`](../../.claude/shared/hadf/preregistration-phase2bis-subexp2.json) (DRAFT pending B14 ceremony lock)
- Sub-exp 3 prereg: [`.claude/shared/hadf/preregistration-phase2bis-subexp3.json`](../../.claude/shared/hadf/preregistration-phase2bis-subexp3.json) (DRAFT pending B15 ceremony lock)
- Anchor-drift check: [`scripts/hadf-phase2bis-anchor-drift-check.py`](../../scripts/hadf-phase2bis-anchor-drift-check.py)
- Verdict scripts: [`scripts/hadf-phase2bis-verdict.py`](../../scripts/hadf-phase2bis-verdict.py)
- Cadence ledger entries: B12 (UCC, struck 2026-05-27 PR #503); Sub-exp 1 verdict gate ~2026-05-28; Sub-exp 2 launch gate ~2026-05-28+; Sub-exp 3 launch gate ~2026-05-31+; Block C synthesis gate ~2026-06-04+
- Showcase target: `fitme-story/content/04-case-studies/30-hadf-phase2bis-cross-sub-exp-synthesis.mdx` (placeholder TBD)
- External Audit #2 substrate (2026-06-12): scope covers raw .jsonl integrity + verdict scripts + THIS case study + anchor-drift output

## §8 Change log

| Date | Change | Author |
|---|---|---|
| 2026-05-27 | Initial skeleton authored as Block C task C16 pre-work; all sections structured with TBD markers | Claude (regvash21@gmail.com session, Phase E Day 6) |
| TBD | Sub-exp 1 verdict populated in §3.A | TBD |
| TBD | Sub-exp 2 verdict populated in §3.B | TBD |
| TBD | Sub-exp 3 verdict populated in §3.C | TBD |
| TBD | Anchor drift populated in §4 | TBD |
| TBD | Synthesis verdict + status promotion populated in §5 | TBD |
| TBD | Status promoted draft → complete; this row backdated to closure date | TBD |
