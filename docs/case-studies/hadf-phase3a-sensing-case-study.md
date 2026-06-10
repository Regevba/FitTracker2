---
title: "HADF Phase 3A — The Sensing Layer (detection-only observability over a validated dispatch signal)"
slug: hadf-phase3a-sensing
date_written: 2026-06-10
date: 2026-06-10
work_type: Feature
work_subtype: b_medium
dispatch_pattern: "operator-driven (post-Phase-2-bis activation build)"
framework_version: v7.9.1
state_owner: ft2
case_study_type: feature
primary_metric: "Sensing-layer coverage: per-endpoint reference distributions materialized + drift monitor operational over every closed Phase 2-bis endpoint — detection only, zero routing decisions."
success_metrics:
  primary: "reference-signatures.json built from the closed Sub-exp 1/2/3/1B raw collections — ≥8 endpoints, every endpoint at n ≥ min_n (achieved: 8 endpoints, 7197 valid records, min_n=50)"
  secondary:
    - "Attestation correctly maps each endpoint's own centroid back to that endpoint at the aggregate (distribution) level"
    - "Drift monitor distinguishes a stable window from a >3σ-shifted window against the locked baseline"
    - "Every attestation output carries advisory:true + a 'do NOT route' caveat (RQ5 honesty-boundary invariant)"
kill_criteria:
  - "Attestation presented as authoritative per-request (violates the RQ5 honesty boundary) → revert T2 to advisory-only or pull it."
  - "Any T1–T3 producer makes a dispatch/routing decision (violates the Phase 3A non-goal; acting is gated on RQ4 / Phase 3B)."
kill_criteria_resolution: "Neither kill criterion fired. T1–T3 ship advisory/detection-only by construction: every `hadf-attest.py` output carries `advisory: true` and an explicit 'do NOT route' caveat, and same-model endpoints (anthropic vs aws-bedrock claude-haiku-4-5) attest 'weak' by design — the conservative posture demanded by RQ5. No T1–T3 producer reads or writes a dispatch decision; the AIOrchestrator T5a hook emits an honest `ai_inference_completed` observation only (duration_ms + source_tier) and routes nothing. The acting layer (RQ4 / Phase 3B) remains unbuilt and explicitly gated. T5b (server-side real streaming ttft_s/tps) was deferred — it needs an AIEngineClient streaming rewrite + Railway change — and is tracked as a follow-on, not a closure blocker."
tier_tags_present: true
related_prs:
  - "FT2 #635"
  - "FT2 #644"
  - "fitme-story #207"
pr_citation_exempt:
  - pr_number: 207
    reason: "fitme-story PR (T4 control-room HADF panel) — cross-repo cite, resolved via the unified PR cite cache REPO_MAP."
  - pr_number: 644
    reason: "Follow-on hardening PR (signature-expansion / calibration_status honesty layer), cited for context — not the closure PR (#635). Tracked in state.json related_prs."
---

# HADF Phase 3A — The Sensing Layer

> **Status:** shipped 2026-06-05 (T1–T3, PR #635) → hardened 2026-06-05 (calibration honesty layer, PR #644) → closed 2026-06-10.
> **Honesty boundary (load-bearing):** this layer **detects and reports**. It makes **no dispatch or routing decision**. Whether routing on a signature improves outcomes is unproven and pre-registered as **RQ4 (Phase 3B)**. Per-request single-shot attestation accuracy is unvalidated (**RQ5**). Never route on attestation output; never present it as authoritative.

## 1. What this feature is

HADF Phase 2-bis established — across four independent sub-experiments, all PASS (2026-06-05) — that **streaming TTFT/TPS signatures are real, provider-general, substrate-discriminating, and short-term-stable**. That is a *sensing* result: the signal exists and is measurable. It says nothing yet about whether *acting* on the signal (routing a request to a substrate based on its signature) improves any outcome.

Phase 3A turns that validated signal into a **passive observability surface** — and stops there, deliberately. It is the first half of a two-half program whose second half (acting, RQ4) is intentionally not built.

It is a **b_medium Feature**: net-new framework scaffolding on top of an already-validated research result, mechanical enough that the PRD phase was skipped (the spec carries the design), but large enough to warrant the full closure discipline (case study + gate audit + kill-criteria resolution).

## 2. The three producers (T1–T3)

| Component | Producer | Output | Tier |
|---|---|---|---|
| **Reference store** (T1) | `scripts/hadf-build-reference-store.py` | `reference-signatures.json` | T1 (instrumented) |
| **Attestation** (T2) | `scripts/hadf-attest.py` | stdout / JSON | T1 input → **T3 advisory** interpretation |
| **Drift monitor** (T3) | `scripts/hadf-drift-monitor.py` | `drift-monitor.jsonl` (append-only) | T1 (KS / Mahalanobis vs baseline) |

### Reference store

Built from the **closed** Phase 2-bis raw collections (Sub-exps 1/2/3/1B). For each `(provider, endpoint)` it materializes `n`, TTFT/TPS quantiles + mean/std, and a 2-D mean + covariance (for Mahalanobis attestation), plus provenance (which sub-exps contributed). Two filters keep the distributions honest:

- **`n < --min-n` (default 50) → `excluded_low_n`.** This drops the rate-limited v1 partials (mistral n=9, vercel n=5) that would otherwise contribute under-powered centroids.
- **TTFT > `--max-ttft` (default 30s) → dropped as connection-stall / retry artifact, not a streaming-latency sample.** 7 records dropped (the Sub-exp 1B Fire-0 launch-probe stalls of 995s / 886s / 124s + 4 borderline). Their variance would otherwise swallow the per-endpoint covariance and break attestation. The drop count is recorded per endpoint (`provenance.dropped_implausible_ttft`) and globally.

**Current build (T1): 8 endpoints, 7197 valid records, `min_n=50`, `max_ttft_s=30`, as-of 2026-06-05.** [T1, instrumented — counts emitted by the builder.]

### Attestation (advisory)

Scores an observed `(ttft_s, tps)` against every reference endpoint via Mahalanobis distance (the same math as the Sub-exp 3 verdict) and reports the best match + a confidence band:

- **strong** — within 2σ of a centroid AND ≥1σ closer than the runner-up
- **weak** — within 4σ
- **uncertain** — beyond 4σ ⇒ `unknown / unseen substrate`

Every output carries `advisory: true` and the "do NOT route" caveat.

**The honesty boundary made concrete.** `anthropic/claude-haiku-4-5` and `aws-bedrock/.../claude-haiku-4-5` serve the *same model* with overlapping TPS, so the attestation runner-up gap is <1σ → confidence is **weak**, never strong. This is the correct conservative posture and a live demonstration of the RQ5 caveat: the Sub-exp 3 result (these two endpoints ARE distinguishable in aggregate, `signature_delta_ratio` 2.89) holds at the *distribution* level — which is what the drift monitor uses — and does **not** promise per-request separability.

### Drift monitor

Compares a recent window vs each endpoint's locked baseline. Mahalanobis mean-shift in baseline-σ units → `stable` (<1σ) / `minor_drift` (1–3σ) / `significant_drift` (>3σ, re-baseline recommended). A KS divergence on either marginal (p<0.01) raises a `ks_diverged` flag. Windows below 30 samples report `insufficient_window`. Drift is **expected** over time (provider infra changes); flagging it is the point, not a failure.

## 3. The follow-ons (T4, T5, calibration)

- **T4 — control-room HADF panel** (fitme-story PR #207): an advisory observability surface in `/control-room`. Renders the sensing outputs; decides nothing.
- **T5a — AIOrchestrator emit hook** (shipped): emits an honest `ai_inference_completed` event (`duration_ms` + `source_tier`) on live traffic. **Observation only — routes nothing.**
- **T5b — server-side real streaming `ttft_s`/`tps`** (deferred): requires an AIEngineClient streaming rewrite + a Railway change. Tracked as a follow-on; not a closure blocker.
- **Signature-expansion / `calibration_status` honesty layer** (PR #644): every recognition row now carries `calibration_status` (`instrumented` = measured, real `n`; `prior_unvalidated` = spec-sheet, no measurement). The attester **never** returns a `prior_unvalidated` row as a confident match. Includes a real on-device M4 calibration. This is the mechanism that prevents the catalog from silently filling with fabricated spec-sheet numbers.

## 4. Verification

- **`scripts/tests/test_hadf_sensing.py` — 9 tests pass** (builder aggregate + low-n filter + empty-error; attestation centroid-match + unseen-substrate uncertainty + advisory-flag invariant; drift monitor stable / significant / insufficient-window). Requires numpy + scipy + pytest. [T1, instrumented — `9 passed in 20.73s`, 2026-06-10.]
- **Platforms tested:** `ai` (AIOrchestrator T5a hook over the ai-engine cohort) + `backend` (server-side emit path). Not `ios` / `web` — this layer ships no product-UI surface; the fitme-story panel (T4) is an operator dashboard, not a tested product platform.

## 5. Why the sensing/acting split is the whole point

The discipline this feature demonstrates is **refusing to act on a signal you have only validated for sensing.** It would have been easy — and wrong — to wire the attestation output into the dispatcher the moment Phase 2-bis confirmed the signal was real. The signal being *real* (Phase 2-bis) and *per-request actionable* (RQ5, unvalidated) and *outcome-improving when routed on* (RQ4, unbuilt) are three different claims. Phase 3A ships only the first, labels every output `advisory: true`, and leaves a visible, pre-registered gap where the other two belong.

A system that ships the sensing layer and then *stops* — instead of quietly closing the loop into routing — is the honest version of this work.

## 6. Cross-references

- **Spec:** [`docs/superpowers/specs/2026-06-02-hadf-phase3a-sensing-layer-design.md`](../superpowers/specs/2026-06-02-hadf-phase3a-sensing-layer-design.md)
- **Acting layer (RQ4, gated):** [`docs/superpowers/specs/2026-06-02-hadf-phase3b-rq4-decision-value-design.md`](../superpowers/specs/2026-06-02-hadf-phase3b-rq4-decision-value-design.md)
- **Sensing-layer README:** [`.claude/shared/hadf/SENSING-LAYER-README.md`](../../.claude/shared/hadf/SENSING-LAYER-README.md)
- **Phase 2-bis synthesis (the validated signal this layer rests on):** [`hadf-phase2bis-cross-sub-exp-synthesis-case-study.md`](hadf-phase2bis-cross-sub-exp-synthesis-case-study.md)
- **Source of truth:** `.claude/shared/hadf/HADF-SOURCE-OF-TRUTH.md` §10
- **Provenance:** FT2 PR #635 (T1–T3) + FT2 PR #644 (calibration honesty layer) + fitme-story PR #207 (T4 panel).
