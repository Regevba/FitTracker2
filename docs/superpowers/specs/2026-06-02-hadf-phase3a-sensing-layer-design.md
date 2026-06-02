# HADF Phase 3A — Sensing / Observability Layer (build spec, DRAFT)

> **Status:** DRAFT, 2026-06-02. Phase 3A is the **activate-now** half of HADF Phase 3 (see [`HADF-SOURCE-OF-TRUTH.md`](../../../.claude/shared/hadf/HADF-SOURCE-OF-TRUTH.md) §10). It activates HADF as a **passive detection/observability layer only** — it makes **no dispatch/routing decisions**. Routing is gated on Phase 3B / RQ4 (separate spec). Formal build kickoff waits for Phase 2-bis closure (Sub-exp 3 + 1B verdicts ~2026-06-05 + Block C synthesis); this spec can be reviewed/refined before then.

## 1. Goal & non-goals

**Goal:** turn the validated HADF signal (streaming TTFT/TPS signatures are real, provider-general, substrate-discriminating, short-term-stable) into a live observability surface that *detects* and *reports* — without acting on the signal.

**Non-goals (explicitly deferred to 3B/RQ4):**
- No routing/dispatch decisions based on signatures.
- No claim that attestation is authoritative per-request (single-shot accuracy is unvalidated — RQ5).

This boundary is what makes 3A shippable on T1 evidence alone: everything below uses only *distinguishability + short-term stability*, both proven.

## 2. Components

### 2.1 Reference-signature store
A read-only catalog of per-endpoint reference distributions (TTFT + TPS marginals + joint) built from the **locked** sub-exp raw data:
- Sub-exp 1 (4 cloud endpoints), Sub-exp 2 (ollama local), Sub-exp 3 (bedrock/anthropic-direct/openai), Sub-exp 1B (anthropic/google).
- Each entry: provider, endpoint, n, TTFT quantiles, TPS quantiles, covariance, source prereg sha + lock tag (provenance).
- Producer: `scripts/hadf-build-reference-store.py` → `.claude/shared/hadf/reference-signatures.json`.

### 2.2 Backend-attestation classifier (ADVISORY)
Given an observed request's `(ttft_s, tps)` (or a small batch), score similarity to each reference distribution and emit the best match + a **confidence band**.
- Method: Mahalanobis distance to each reference (reuse Sub-exp 3 verdict math) → softmax-style confidence.
- **Ships advisory/confidence-scored, NOT authoritative** — per-request single-shot accuracy is unvalidated until RQ5. Output always carries a confidence + an "uncertain/unknown" bucket.
- Tier discipline: attestation confidence is a **derived [T1-input → T3-interpretation]** value; the panel must label it as advisory.

### 2.3 Drift monitor (operationalizes Sub-exp 1B)
Standing job: for each known endpoint, compare a rolling recent-window signature to its locked baseline via 2-sample KS; alert when `p < threshold` (signature shifted = possible infra change).
- Producer: `scripts/hadf-drift-monitor.py` (cron, e.g. daily) → appends to `.claude/shared/hadf/drift-monitor.jsonl`.
- Threshold pre-set; tunable. Alert routes to the existing digest/issue mechanism.

### 2.4 Provider-claim verification
Same engine as 2.3, framed as: "a stable model-id's signature changed → provider may have silently swapped model/region/hardware." This is the directly-useful operationalization of Sub-exp 3's result.

### 2.5 Surface — control-room HADF panel
New route/panel reading `reference-signatures.json` + `drift-monitor.jsonl` + attestation output:
- Per-endpoint reference distribution cards (TTFT/TPS).
- Live drift status (green/amber/red per endpoint) + last-checked.
- Attestation confidence readout (clearly labeled advisory).
- Likely home: fitme-story `/control-room/framework` sibling route, behind basic-auth (matches existing UCC pattern).

## 3. Integration point
To attest/monitor live traffic (vs. just experiment data), the app's AI path (e.g. `AIOrchestrator`) must emit per-call `(ttft_s, tps, provider, model)` to a HADF ingest. **Phase 3A scope decision:** start with **experiment-data + scheduled-probe** monitoring (no app-path change required); the live-traffic emit hook is an optional follow-on (it touches `AIOrchestrator`, a high-risk-area file → extra review). This keeps 3A low-risk and shippable.

## 4. Tasks (draft)
- **T1** — reference-store builder + `reference-signatures.json` (from locked sub-exp data).
- **T2** — attestation classifier (advisory, confidence-banded).
- **T3** — drift monitor cron + `drift-monitor.jsonl` + alert wiring.
- **T4** — control-room HADF panel (fitme-story).
- **T5** *(optional, deferred)* — `AIOrchestrator` live-traffic emit hook (high-risk-area review).

## 5. Risks / open items
- Reference store should be built from the **closed** sub-exps (1/2 now; 3/1B after ~06-05) so baselines are final — **build T1 after Phase 2-bis closes.**
- Attestation must never be presented as authoritative pre-RQ5 (guard in the panel copy).
- Cross-repo: producers in FT2 (`scripts/` + `.claude/shared/hadf/`), panel in fitme-story (sync via existing `sync-from-fittracker2.ts`).

## 6. Cross-references
- Activation analysis + Phase 3 roadmap: SoT §9/§10.
- Phase 3B / RQ4 decision-value design: `2026-06-02-hadf-phase3b-rq4-decision-value-design.md`.
- Predecessor: HADF Phase 2-bis spec/plan/preregs.
