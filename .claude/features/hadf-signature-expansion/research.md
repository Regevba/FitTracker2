# Research — HADF Signature Expansion (data-driven, post-Phase-2-bis)

> **Phase 0 (Research).** Feature `hadf-signature-expansion`. This reconciles the
> pre-experiment [2026-04-28 signature-expansion note](../../../docs/research/2026-04-28-hadf-signature-expansion.md)
> with the now-CONFIRMED HADF Phase 2-bis results, and proposes a scope shaped by
> *what the experiments actually licensed*. Tier tags: T1 (instrumented), T2
> (declared), T3 (narrative).

## 1. What this is

Grow HADF's hardware-recognition catalogs beyond the v1.0 baseline (17 on-device
chip profiles + 7 cloud signatures, PR #82) — but **driven by the empirical
streaming-signature method that Phase 2-bis just validated**, not by the static
published-TOPS profiles the 2026-04-28 note assumed.

## 2. Why now — the experiments changed the answer

The 2026-04-28 note was written **before any HADF experiment ran**. It explicitly
flagged its own blocker (§6): *"Phase 2 (50×5×3 data points) was never run … this
baseline has known weaknesses … Phase 2 calibration should add `(precision_class,
bandwidth_probe_ratio, container_vs_bare_metal_variance)` before any new
generation is added."* It then proposed adding ~30 **static** chip profiles keyed
on vendor-published TOPS.

Phase 2-bis has now run, and the result is decisive [T1]:

| Sub-exp | Finding | What it proves about the *method* |
|---|---|---|
| 1 | cloud silhouette 0.70 @ k=5 | the **empirical (TTFT, TPS) streaming signature** generalizes across providers |
| 2 | local Ollama vs cloud KS p≪0.01 | the same method **separates on-device from cloud** (the M2 was calibrated *by running on it*) |
| 3 | same-model routing delta_ratio 2.89 | the method even **distinguishes serving substrate** behind one model id |
| 1B | drift 0.19σ, silhouette 0.98 | signatures are **short-term stable** → a calibrated baseline is reusable |

**The load-bearing reframing:** what HADF can actually *recognize* is the
**empirically-measured streaming-latency fingerprint**, captured by the Phase 3A
`reference-signatures.json` store (TTFT/TPS quantiles + 2-D mean/cov). It is **not**
the static published-TOPS number. Sub-exp 2 is the proof of method for on-device:
a chip's signature comes from *measuring inference on it*, not from its spec sheet.

This flips the expansion's center of gravity from "add spec-sheet rows" to
"calibrate empirical signatures for the substrates we can actually run on."

## 3. The two recognition surfaces — and their very different feasibility

HADF has two catalogs. The experiments licence them very differently:

| Surface | File | What Phase 2-bis says | Feasibility to expand empirically |
|---|---|---|---|
| **Cloud / datacenter signatures** | `hardware-signature-table.json` + Phase 3A `reference-signatures.json` | **VALIDATED** — Sub-exp 1/3 calibrated cloud endpoints remotely | **HIGH** — only needs API access; reuse `hadf-build-reference-store.py` |
| **On-device chip profiles** | `chip-profiles.json` | method validated *only where the device is on hand* (M2, Sub-exp 2) | **HARDWARE-GATED** — empirical calibration of an A19 / Snapdragon / Intel / AMD profile requires running on that physical chip (the "human at a device" unclosable gap) |

This is the crux the 2026-04-28 note couldn't see: **you cannot empirically
calibrate a chip you don't physically have.** Static published-TOPS profiles can
be *added* as coarse priors, but Phase 2-bis proves they are not the validated
discriminator — so they must be tagged as unvalidated priors, never as measured
signatures.

## 4. Alternatives considered

| Approach | Pros | Cons | Effort | Chosen? |
|---|---|---|---|---|
| **A. Ship the 2026-04-28 note as-is** (≈30 static TOPS profiles + 11 cloud sigs, all `uncalibrated`) | Matches the existing note; broad coverage | Adds ~40 *uncalibrated* rows — §6 of the note itself warns this "may worsen classification accuracy"; contradicts the Phase 2-bis finding that the empirical signature (not TOPS) is the discriminator | M | ✗ |
| **B. Empirical-first: expand the calibratable surface, prior-only the rest** (recommended) | Ships only validated signatures; reuses Phase 3A `reference-signatures.json` + builder; honest about what's measured vs guessed; a reusable on-device calibration harness lets the operator add chips as hardware becomes available | Narrower initial chip coverage (cloud + operator-owned devices first) | M | ✓ |
| **C. Schema-only** (adopt §5 schema gaps: precision array, compute_axes, memory_topology, vendor_status — no new signatures) | Unblocks future generations; low risk | Doesn't actually expand recognition; defers the user's ask | S | ✗ (folded into B as a sub-task) |

## 5. Recommended approach (B) — data-driven scope

Three workstreams, ordered by what the experiments licence:

1. **Cloud/datacenter signature expansion (VALIDATED — primary).** Extend the
   Phase 3A reference store + `hardware-signature-table.json` with new
   *empirically-calibrated* endpoints, using the proven `hadf-build-reference-store.py`
   method (collect → reference-signatures.json). Start with endpoints the operator
   can reach via API (additional Anthropic/OpenAI/Google/Bedrock models, plus any
   new datacenter endpoints with access). Each new entry carries real TTFT/TPS
   quantiles + n, never a spec-sheet guess.

2. **On-device empirical-calibration harness (generalize Sub-exp 2).** Turn the
   ollama-on-M2 protocol into a reusable per-chip calibration runner so any chip
   the operator *physically has* (their M-series Macs today; others as acquired)
   can be calibrated into a real signature. Ships the harness now; signatures
   populate as hardware is available. This is the honest answer to "expand into
   new chip families": the *mechanism* to do it empirically, not fabricated rows.

3. **Static profiles as explicitly-tagged coarse priors + schema gaps (§5).**
   Add the high-value static chip-family rows from the note (Apple A19/M5, Intel
   Core Ultra, AMD Ryzen AI — the genuinely-new vendors) **tagged
   `calibration_status: "prior_unvalidated"`** so dispatch can use them as weak
   priors but never as measured signatures. Adopt the §5 schema extensions the
   data motivates (`supported_precisions[]`, `compute_axes`, `memory_topology`,
   `vendor_status`) so the catalog can hold both priors and calibrated signatures.

**Out of scope for v1 (RQ-gated):** the §6 richer-probe additions
(`precision_class`, `bandwidth_probe_ratio`, container-vs-bare-metal variance).
Phase 2-bis validated the *2-tuple* (TTFT, TPS) and it already discriminates
substrate + provider + routing-layer — the richer probes are unproven extra
signal and belong in a calibration experiment (Phase 3B/RQ-style), not in this
additive expansion. **Honesty boundary:** like Phase 3A, this feature is a
*sensing/recognition* expansion — it does not make or change any dispatch
*decision* (acting layer stays gated on RQ4).

## 6. External + internal sources

- Predecessor proposal: `docs/research/2026-04-28-hadf-signature-expansion.md` (§2 chips, §3 cloud sigs, §5 schema gaps, §6 calibration gaps, §8 prioritization).
- Validated method: `HADF-SOURCE-OF-TRUTH.md` §-1 (all 4 sub-exps PASS) + `scripts/hadf-build-reference-store.py` + `.claude/shared/hadf/reference-signatures.json` (Phase 3A).
- On-device proof of method: Sub-exp 2 (ollama/llama3.2:3b on M2, KS p≪0.01).
- Catalogs to expand: `.claude/shared/chip-profiles.json` (17) + `.claude/shared/hadf/hardware-signature-table.json` (7).
- Unclosable-gap reference (hardware-access limit): `docs/case-studies/meta-analysis/unclosable-gaps.md`.

## 7. Proposed success metrics (draft → firmed in PRD)

- **Primary [T1]:** # of endpoints/chips with a *real calibrated* signature in `reference-signatures.json` grows from 8 → ≥ N (target set in PRD; only counts empirically-measured rows, not priors).
- **Secondary:** schema supports both `calibration_status: instrumented` and `prior_unvalidated` rows (0 mislabeled); on-device calibration harness produces a valid signature on ≥1 operator-owned chip (re-validates the Sub-exp 2 method generalizes beyond ollama).
- **Guardrail:** no `prior_unvalidated` row is ever surfaced to dispatch as if measured; attestation (`hadf-attest.py`) confidence stays advisory.
- **Kill criterion (draft):** if adding `prior_unvalidated` rows measurably degrades attestation accuracy on the *calibrated* set (Phase 3A reference store), drop the priors and ship calibratable-only.

## 8. Decision

**Recommend Approach B (empirical-first).** It is the version of "expand HADF into
new chip families" that the experiments actually licence: grow the *calibratable*
surface with real measured signatures (reusing the Phase 2-bis/3A method), ship a
harness so on-device families can be calibrated as hardware allows, and admit
static spec-sheet profiles only as explicitly-tagged unvalidated priors. This
keeps the expansion honest (measured vs guessed never conflated), reuses shipped
infrastructure, and respects the hardware-access limit the static-profile approach
silently ignored.

**Open question for the operator (firms scope in PRD):**
- Which substrates are actually reachable now? (a) cloud/API endpoints to
  calibrate first; (b) which physical chips the operator owns for the on-device
  harness (M-series Macs? iPhone for A-series? any Snapdragon/Intel/AMD device?).
- Impact tier: the additive signatures + harness read **B_medium**; the `§5`
  schema change (precision array / compute_axes / memory_topology) has an
  **A_high** aspect (catalog contract change). Proposed: split — schema change as
  its own small A_high sub-scope with the calibration-status field as the
  load-bearing addition; the rest B_medium additive.
