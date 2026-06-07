---
title: "HADF Signature Expansion — empirical-first, with a real on-device calibration"
date: 2026-06-05
date_written: 2026-06-05
work_type: feature
framework_version: v7.9.1
dispatch_pattern: operator-driven (single-session full lifecycle, isolated worktree)
primary_metric: "instrumented (measured) signatures in reference-signatures.json: 8 → 9 (real M4 on-device); cloud calibrator shipped to grow further on operator run"
success_metrics:
  - "instrumented signatures 8 → 9 (real M4 calibration, n=80) [T1]"
  - "calibration_status honesty field on 100% of rows across all 3 catalogs (44 rows) [T1]"
  - "on-device harness reproduces a Sub-exp-2-quality signature on M4 → K2 PASS [T1]"
  - "18→19 tests pass incl. 9 Phase 3A no-regression [T1]"
kill_criteria:
  - "K1 — adding prior_unvalidated rows degrades attestation accuracy on the calibrated set → drop priors"
  - "K2 — on-device harness can't reproduce a Sub-exp-2-quality signature on the operator's Mac → descope on-device"
kill_criteria_resolution: "Neither fired. K1: priors live in chip-profiles.json / hardware-signature-table.json and are EXCLUDED from the attest candidate set by the guardrail — they cannot affect attestation accuracy on the reference store (test-enforced). K2: the harness produced a clean M4 signature (ttft_median 0.095s, tps 41, n=80, 100% valid) — it not only generalized M2→M4 but DISCRIMINATED them (M2-ollama 0.179s vs M4 0.095s)."
tier_tags_present: true
related_prs:
  - 644
---

# HADF Signature Expansion — empirical-first, with a real on-device calibration

## The question, and the trap

"Expand HADF into new chip families." The natural reading — the one the
[2026-04-28 expansion note](../research/2026-04-28-hadf-signature-expansion.md)
took — is "add more chip rows": Apple A19/M5, Intel Core Ultra, AMD Ryzen AI,
keyed on vendor-published TOPS. That note even flagged its own blocker: *"Phase 2
was never run … adding uncalibrated rows may worsen classification accuracy."*

Then Phase 2-bis ran (all 4 sub-exps PASS, CONFIRMED) and changed the answer.
**What HADF can actually recognize is the empirically-measured streaming
fingerprint (TTFT/TPS), not the spec-sheet number.** Sub-exp 2 is the proof: the
M2's signature came from *running inference on it*. So "expand into new chip
families" really means *calibrate real signatures for the substrates you can
reach* — and admit spec-sheet profiles only as explicitly-labeled guesses.

## What shipped

**1. The honesty field (`calibration_status`).** Every recognition row across all
three catalogs is now `instrumented` (measured, carries a real `n`) or
`prior_unvalidated` (spec-sheet, no measurement) [T1]. Migration backfilled 44
rows: 8 reference endpoints → `instrumented` + `class`; 24 chip profiles + 12
datacenter sigs → `prior_unvalidated`; 10 Apple SoCs got `memory_topology`. This
is the HADF program's central honesty commitment — *measured vs guessed never
conflated* — applied to its own catalog.

**2. The attest guardrail.** `hadf-attest.py` excludes `prior_unvalidated` rows
from the candidate set: a spec-sheet profile can never be returned as a confident
match (test-enforced). Untagged legacy rows stay candidates (backward-compatible;
all 9 Phase 3A tests still pass).

**3. The on-device calibration harness.** `hadf-calibrate-device.py` generalizes
Sub-exp 2: stream a local model, measure TTFT/TPS, emit one `instrumented`
`class:on_device` row. This is the *mechanism* to grow recognition — the honest
alternative to fabricated spec-sheet rows. A chip you can't run on doesn't get an
instrumented row.

**4. A real M4 calibration [T1].** Run live against this machine's ollama
`llama3.2:3b`: **ttft_median 0.095s, tps 41, n=80** (100% valid). The
**K2 result**: Sub-exp 2's M2 signature was 0.179s TTFT — the M4 at 0.095s is
~1.9× faster. The method *generalized* (worked on a new chip generation) **and
discriminated** (M2 ≠ M4). The recognition premise holds on real on-device
silicon, empirically.

**5. The cloud calibrator** (`hadf-calibrate-cloud.py`) reuses the Sub-exp
collector's per-provider streaming functions to calibrate new cloud endpoints,
with a pre-probe that drops bad model-ids / rate-limited candidates. Shipped +
mock-tested; *running it* (paid API calls) stays an operator decision.

## An honest finding worth more than papering over

Single-shot attestation of the M4 signature mis-matched to a cloud endpoint. The
cause is a real one: `apple_m4` is *so consistent* (TTFT variance **0.0002**) that
its Mahalanobis ellipse is tiny — the query sits 0.37σ out on its own tight
distribution but only 0.24σ inside a loose cloud cluster (gpt-4o-mini, TPS
variance 12,500). **Tight on-device clusters defeat single-shot Mahalanobis** —
exactly the RQ5 (single-shot accuracy) limitation, surfaced empirically.

This does **not** break the feature. The *distribution-level* centroids are
cleanly distinct (M4 [0.10, 40.8] vs M2 [0.25, 39.5] vs gpt-4o-mini [0.055,
62.9]) — and the recognition claim, like Phase 2-bis, is a distribution claim.
Per-request classification is RQ5/Phase 3B, unproven and now empirically shown
unreliable on tight clusters. The feature documents the limit rather than hiding
it. [T3 over T1 data]

## Outcome vs metrics

| Metric | Target | Result |
|---|---|---|
| instrumented signatures | ≥12 | **9** (8 baseline + real M4); cloud tool ready to grow on operator run [T1] |
| calibration_status coverage | 100% | **100%** (44/44 rows) [T1] |
| on-device harness reproduces Sub-exp-2 quality (K2) | pass | **PASS** (M4 n=80, clean) [T1] |
| no-regression | 9 Phase 3A tests | **pass** (19/19 total) [T1] |

The 9-vs-12 gap is **the feature's own thesis in action**: you can only calibrate
what you can reach. The M4 was reachable (instrumented). The iPhone A16 has no
local-inference route from this Mac this cycle → documented harness target. Cloud
endpoints are reachable but credential/cost-gated → the calibrator ships ready.
Growing the count is now a *run the mechanism* operation, not a code change.

## Honesty boundary

Sensing/recognition only — no task changes a dispatch decision; the acting layer
stays gated on RQ4 (Phase 3B). `calibration_status` is the mechanical guarantee
that measured and guessed are never conflated.

## Reality-check note

A prior session had already shipped the v1.1 *scaffolding* (24 profiles,
`supported_precisions[]`, `compute_axes`, `vendor_status`, enums). The Phase 0.1
reality-check surfaced this, narrowing the feature to its genuine differentiator —
the honesty layer + empirical calibration — rather than re-adding existing rows.
