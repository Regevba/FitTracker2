# PRD — HADF Signature Expansion (empirical-first)

- **Feature:** `hadf-signature-expansion`
- **Work type:** Feature (abbreviated — `work_subtype: b_medium` for the additive workstreams; the schema change carries an A_high sub-scope, see §8)
- **Framework version:** v7.9.1
- **has_ui:** false · **requires_analytics:** false
- **Predecessor research:** [`docs/research/2026-04-28-hadf-signature-expansion.md`](../../../docs/research/2026-04-28-hadf-signature-expansion.md) + [Phase 0 research](research.md)
- **Informed by:** HADF Phase 2-bis (all 4 sub-exps PASS, CONFIRMED) + Phase 3A sensing layer.

## 1. Problem

HADF's recognition catalogs are the v1.0 baseline (17 static on-device chip
profiles + 7 cloud signatures, PR #82). Both predate any experiment. The
2026-04-28 note proposed ~30 more **static published-TOPS** profiles — but
Phase 2-bis proved the validated discriminator is the **empirically-measured
streaming fingerprint** (TTFT/TPS), not the spec-sheet number. Expanding with
uncalibrated static rows would (per the note's own §6) risk *degrading*
attestation accuracy. We need an expansion that grows what HADF can actually
recognize, honestly separating *measured* signatures from *guessed* priors.

## 2. Goal

Grow the recognition catalog **empirically-first**: add real calibrated
signatures for every substrate we can run on, ship a reusable on-device
calibration harness for the rest, and admit static spec-sheet profiles only as
explicitly-tagged unvalidated priors — all on a schema that can hold both.

## 3. Scope

### In scope
1. **Schema v1.1** — extend `chip-profiles.json` + `hardware-signature-table.json` (and align `reference-signatures.json`) with: `calibration_status` enum (`instrumented` | `prior_unvalidated`), `supported_precisions[]` (replaces narrow `preferred_precision`), `compute_axes` (npu/gpu/cpu/platform TOPS + memory bandwidth), `memory_topology` enum, `vendor_status`. (§5 of the note.)
2. **Cloud/datacenter calibration (primary, validated)** — calibrate ≥ N new cloud/API endpoints into `reference-signatures.json` via the proven `hadf-build-reference-store.py` collect→aggregate method (the Sub-exp 1/3 workflow), each with real TTFT/TPS quantiles + n + provenance.
3. **On-device calibration harness** — generalize the Sub-exp 2 protocol (ollama-on-M2) into a reusable per-chip runner (`scripts/hadf-calibrate-device.*`) that produces a real signature for any chip the operator physically has. Calibrate the operator's **M-series Mac(s)** (now) and define the **iPhone A-series** on-device path (best-effort this cycle; harness target if the inference path needs setup).
4. **Tagged priors** — add the high-value genuinely-new static rows from the note (Apple A19/M5, Intel Core Ultra, AMD Ryzen AI) as `calibration_status: prior_unvalidated`, never surfaced to dispatch as measured.
5. **Attestation/reference-store alignment** — `hadf-build-reference-store.py` + `hadf-attest.py` (Phase 3A) read the new `calibration_status`; attestation never matches against `prior_unvalidated` rows (or flags them distinctly).

### Out of scope (RQ-gated / deferred)
- Richer signature probes from the note's §6 (`precision_class`, `bandwidth_probe_ratio`, container-vs-bare-metal variance). Phase 2-bis validated the **(TTFT, TPS) 2-tuple**, which already discriminates substrate+provider+routing-layer; richer probes are unproven extra signal → a Phase 3B/RQ calibration experiment, not this additive expansion.
- Any **dispatch/acting** change. This is a **sensing/recognition** expansion only; routing on signatures stays gated on RQ4.
- Physical chips the operator doesn't own (Snapdragon/Intel/AMD devices) — harness + priors only; signatures populate when hardware is available.

## 4. Deliverables

| # | Deliverable | Type |
|---|---|---|
| D1 | Schema v1.1 (`calibration_status` + `supported_precisions[]` + `compute_axes` + `memory_topology` + `vendor_status`) + migration of existing rows | data/schema |
| D2 | Cloud/API endpoint calibration runs → ≥N new `instrumented` rows in `reference-signatures.json` | data |
| D3 | `scripts/hadf-calibrate-device.*` on-device calibration harness + tests (generalizes Sub-exp 2) | backend |
| D4 | M-series Mac calibrated signature (real) via D3 | data |
| D5 | iPhone A-series on-device path (calibrated if reachable; else documented harness target) | backend/data |
| D6 | Tagged `prior_unvalidated` rows (A19/M5, Intel Core Ultra, AMD Ryzen AI) | data |
| D7 | `hadf-build-reference-store.py` + `hadf-attest.py` honor `calibration_status` + tests | backend |

## 5. Success metrics (NON-NEGOTIABLE)

- **Primary [T1]:** count of **`instrumented`** (real, measured) signatures in `reference-signatures.json` grows **8 → ≥ 12** (target firmed against reachable substrates: cloud endpoints + ≥1 M-series Mac). *Only empirically-measured rows count; priors never do.*
- **Secondary [T1]:**
  1. On-device harness (D3) produces a valid signature on ≥1 operator-owned chip (re-validates the Sub-exp 2 method generalizes beyond ollama) — pass/fail.
  2. Schema holds both statuses with **0 mislabeled rows** (every row has a `calibration_status`; no `prior_unvalidated` row carries a measured `n`).
- **Guardrail [T1]:**
  1. Attestation (`hadf-attest.py`) never returns a `prior_unvalidated` row as a confident match — verified by test.
  2. The Phase 3A reference-store builder still passes its existing 9 tests + new `calibration_status` tests (no regression on the validated 8-endpoint baseline; attestation discrimination on the calibrated set unchanged).
- **Leading indicator (≤1 week):** D1 schema + D3 harness + D7 reader land with tests green; ≥1 new cloud endpoint calibrated.
- **Lagging indicator (30/60/90d):** as the operator acquires hardware, `instrumented` count keeps rising via the harness with no schema change (the mechanism, not a one-off, is the win).
- **Instrumentation:** the reference store + per-row `n`/provenance + `calibration_status` ARE the instrumentation; `make hadf-reference-store` + the test suite are the measurement.
- **Review cadence:** at feature close + a +30d check that the harness produced ≥1 additional calibrated row (or documented why hardware wasn't available).

## 6. Kill criteria

- **K1:** adding `prior_unvalidated` rows measurably degrades attestation accuracy on the **calibrated** set (the 8-endpoint Phase 3A baseline) → drop priors, ship calibratable-only.
- **K2:** the on-device harness (D3) cannot reproduce a Sub-exp-2-quality signature on the operator's M-series Mac (i.e., the on-device method doesn't generalize beyond ollama-on-M2) → descope D4/D5, ship cloud-calibration + schema only, and log the negative result.
- **kill_criteria_resolution:** *(filled at close — records which criteria fired and the disposition.)*

## 7. Honesty boundary (load-bearing)

Like Phase 3A, this is **detection/recognition only** — it adds and labels
signatures; it makes **no dispatch decision**. The acting layer stays gated on
RQ4 (Phase 3B). `instrumented` vs `prior_unvalidated` is the mechanical guarantee
that *measured* and *guessed* are never conflated — the central honesty
commitment of the whole HADF program applied to its own catalog.

## 8. Impact tier split

- **A_high sub-scope:** D1 schema change (`calibration_status` is a catalog
  contract addition consumed by the Phase 3A reader/attester). Gets the careful
  treatment — migration of existing rows + reader tests + no-regression proof on
  the validated baseline.
- **B_medium:** D2/D3/D4/D6/D7 additive signatures + harness + priors (state.json
  + this PRD + case study suffice; UX phase skipped — no user-visible surface).

## 9. Open questions (resolve in Tasks/Impl)

- Exact set + count of cloud endpoints to calibrate first (firms the `≥12` primary target).
- iPhone A-series on-device inference path: is there a reachable local-inference route this cycle, or is it a documented harness target?
- Where calibrated on-device signatures live: `reference-signatures.json` (unified) vs `chip-profiles.json` (keep on-device separate) — likely unify under the reference store with a `class: cloud|on_device` tag.
