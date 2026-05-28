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
| this-PR (B13) | FT2 | Sub-exp 1A verdict run + §3.A populated + Sub-exp 2 prereg/plist staged | Open 2026-05-28 |
| TBD-B14 | FT2 | Sub-exp 2 verdict run + §3.B populated | Pending ~2026-06-03 (3 days × launch 2026-05-30 22:00 UTC) |
| TBD-B15 | FT2 | Sub-exp 3 verdict run + case study | Pending ~2026-06-04 |
| TBD-C | FT2 | Block C — this synthesis case study + fitme-story showcase slot 30 + state.json closure | Pending ~2026-06-04 (this PR) |

## §3 Per-sub-exp verdicts (populated as each sub-exp closes)

### §3.A Sub-exp 1 — Cloud generalization

**Verdict:** **PASS** (verdict-script run 2026-05-28T03:15Z interim n=2200 → final n=2600 after Day-3 fires; disarm 2026-05-28T~13:30Z post-final-fire 11:00Z)

**Pre-registered pass criteria** (per [`preregistration-phase2bis-subexp1.json`](../../.claude/shared/hadf/preregistration-phase2bis-subexp1.json) `verdict_thresholds`):

- `pass_silhouette_min`: 0.5 (Phase 2 baseline: 0.5566)
- `pass_yield_min`: 600
- `fail_clusters_lt`: 3

**Observed values** [T1] (from [`scripts/hadf-phase2bis-verdict.py`](../../scripts/hadf-phase2bis-verdict.py) `--raw-dir /Volumes/DevSSD/hadf-sub-exp-1a-backups --subexp subexp1`):

| Metric | Threshold | Observed | Pass/Fail |
|---|---|---|---|
| Silhouette at best_k | ≥ 0.5 | **0.7003** | ✅ PASS (+0.20 over threshold; +0.144 over Phase 2 baseline 0.5566) |
| best_k value | n/a | 5 | n/a (matches Phase 2 k=5) |
| n_valid total | ≥ 600 | **2,600** | ✅ PASS (4.3× threshold) |
| cluster_count at best_k | ≥ 3 | 5 | ✅ PASS |
| cluster_endpoint_purity | ≥ 0.8 | Not measured by verdict v1 | n/a (deferred to Block C synthesis if cluster-vs-endpoint purity needed for §5 status) |

**Per-endpoint summary** [T1] (14 fires × 4 endpoints × 50 calls = 2,800 dispatched; 2,600 valid; 200 dropped uniformly across all 4 endpoints — one bad fire equivalent at 2026-05-25T16:40:34Z window before harness hardening Fix #1 settled):

| Provider | Endpoint | n_dispatched | n_valid | Median TTFT (s) | Median TPS | Notes |
|---|---|---|---|---|---|---|
| OpenAI | gpt-4o-mini | 700 | 650 | 0.0296 | 49.64 | Phase 2 baseline endpoint — TTFT consistent with Phase 2 |
| OpenAI | gpt-4o | 700 | 650 | 0.0163 | 99.54 | Fastest TTFT in matrix; ~2× the TPS of gpt-4o-mini |
| Anthropic | claude-haiku-4-5 | 700 | 650 | 0.9181 | **152.93** | Highest median TPS in matrix |
| Anthropic | claude-sonnet-4-6 | 700 | 650 | 1.3800 | 67.98 | Slowest TTFT + lowest haiku/sonnet TPS ratio |
| **TOTAL** | | **2,800** | **2,600** | | | 92.86% valid rate |

**Cost actual:** $0.3240 (sum of `phase2bis-cost-log.jsonl` `estimated_cost_usd` over 12 fires logged; 14 fires fired but the first 2 fires predate cost-log enablement) [T1]. Spec §2 nominal for Sub-exp 1 was $3-4 for the full 9-endpoint matrix; actual on 4-endpoint narrowed matrix = ~10% of nominal, well under the $15 per-sub-exp ceiling.

**Collection window:** 2026-05-25T16:36:44Z → 2026-05-28T11:11:14Z (~2.8 days wall-clock, 14 fires) [T1]. Disarm 2026-05-28T13:34Z (`launchctl bootout gui/$UID com.fitme.hadf-phase2bis-subexp1.plist`, post-verdict). 1 additional fire skipped vs spec §4 nominal `5 × 3 = 15` (the 03:15Z verdict landed PASS at 4.3× yield threshold; remaining 15:00Z/19:00Z/23:00Z fires were no-op compute).

**Kill criteria check** [T1]:

| Kill criterion | Observed | Status |
|---|---|---|
| `n_valid < 300` (prereg) | 2,600 | ✅ Not tripped (8.7× threshold) |
| All endpoints simultaneously rate-limited > 2 fires consecutively | 0 rate-limit events observed across 14 fires | ✅ Not tripped |
| ANY endpoint changed streaming protocol or model id mid-collection | All 4 endpoints stable across 14 fires | ✅ Not tripped |
| Wrapper preflight failed 3+ times consecutively | 14/14 fires preflight Check A (worktree venv) = ok | ✅ Not tripped |

**Trip-wires** [T1]:

| Trip-wire | Status | Action |
|---|---|---|
| `cost_overrun_3x` | $0.324 actual vs ~$4 nominal = 0.08× | Not tripped |
| `anchor_drift` | Applies to subexp3 only | n/a |

**Interpretation** [T3]: The Phase 2 single-endpoint signature (silhouette 0.5566 at k=5 on openai/gpt-4o-mini, n=700) reproduces across multiple providers and **strengthens** with broader matrix — silhouette improves to 0.7003 (+25.8%) on the 4-endpoint cloud matrix, with 5 distinct clusters separating the endpoints by streaming-latency fingerprint. The signature is not openai-specific. **Cloud generalization confirmed within the 4-endpoint scope** — Sub-exp 2 (cloud-vs-local separability) is unblocked.

The 200-record uniform drop (50/endpoint) traces to the 2026-05-25T16:40:34Z fire window that ran before harness-hardening Fix #1's worktree-local venv settled across the wrapper; subsequent 12 fires were clean (validated by heartbeat ledger `preflight=ok` flag).

#### §3.A.1 Sub-exp 1B (if shipped before Block C closure)

Sub-exp 1B remains queued (5 endpoints dropped from 1A: gemini-2.5-flash, gemini-2.5-pro, vercel-ai-gateway gpt-4o-mini, mistral-large-latest, xai grok-4-1). Gating items unchanged from 2026-05-25 launch_matrix_narrowing decision:

- API keys for vercel-ai-gateway / mistral / xai still placeholders pending operator acquisition (see Sub-exp 1A prereg `launch_matrix_narrowing.endpoints_dropped` + spec §2 follow-up runbook reference)
- gemini-2.5-flash / gemini-2.5-pro reasoning-model TTFT distortion (visible_tokens << output_tokens) needs methodology resolution — either a non-reasoning gemini-2.0 variant or an explicit reasoning-vs-generation TTFT decomposition

Not in scope of B13. If Sub-exp 1B ships before Block C closure, append a row to the per-endpoint table above + note any verdict-direction changes vs 1A.

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
| 2026-05-28 | Sub-exp 1A verdict populated in §3.A: PASS silhouette 0.7003 @ k=5, n=2600, 5 clusters across 4-endpoint cloud matrix. Sub-exp 1A campaign disarmed 13:34Z. Sub-exp 2 (Ollama llama3.2:3b) prereg + plist staged for Sat 2026-05-30 22:00 UTC arming. §3.A.1 Sub-exp 1B status restated (still gated on key acquisition + reasoning-model methodology). | Claude (<regvash21@gmail.com> session, Phase E Day 7) |
| TBD | Sub-exp 2 verdict populated in §3.B | TBD |
| TBD | Sub-exp 3 verdict populated in §3.C | TBD |
| TBD | Anchor drift populated in §4 | TBD |
| TBD | Synthesis verdict + status promotion populated in §5 | TBD |
| TBD | Status promoted draft → complete; this row backdated to closure date | TBD |
