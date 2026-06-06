# Tasks — HADF Signature Expansion (empirical-first)

Derived from [prd.md](prd.md). Ordered by dependency. Hardware locked: current
machine **M4**; iPhone **14 Pro → A16 Bionic**. Total est. ≈ 4.25 days.

| ID | Title | Type | Skill | Effort | Depends on | PRD deliverable |
|---|---|---|---|---|---|---|
| **T1** | Schema v1.1 — add `calibration_status` (`instrumented`\|`prior_unvalidated`) + `supported_precisions[]` + `compute_axes` + `memory_topology` + `vendor_status`; migrate existing rows in `chip-profiles.json` + `hardware-signature-table.json`; align `reference-signatures.json` builder output (add `calibration_status:instrumented` + `class:cloud\|on_device`) | data/schema | dev | 0.5 | — | D1 |
| **T2** | `hadf-build-reference-store.py` + `hadf-attest.py` honor `calibration_status`: builder stamps `instrumented`; attest **never returns a `prior_unvalidated` row as a confident match** (filter or distinct bucket) | backend | dev | 0.5 | T1 | D7 |
| **T3** | On-device calibration harness `scripts/hadf-calibrate-device.py` — generalize Sub-exp 2 (local ollama streaming → TTFT/TPS collection → emit a real `instrumented` `class:on_device` row); `--model`, `--n`, `--out` flags; idempotent append | backend | dev | 0.75 | T1 | D3 |
| **T4** | Calibrate **M4** (current machine) via T3 → real `instrumented` signature. Doubles as the **K2 generalization check** (Sub-exp 2 was M2 → does the method hold on M4?) | data | ops | 0.25 | T3 | D4 |
| **T5** | iPhone **A16 (14 Pro)** on-device path: if a reachable local-inference route exists this cycle, calibrate; else document the concrete harness target (path + blocker) in the README | backend/data | dev | 0.5 | T3 | D5 |
| **T6** | Cloud/API endpoint calibration → ≥4 new `instrumented` rows (additional Anthropic/OpenAI/Google/Bedrock models the operator can reach) via the proven collect→`hadf-build-reference-store.py` flow | data | ops | 0.5 | T1, T2 | D2 |
| **T7** | Tagged `prior_unvalidated` rows: Apple A19/M5, Intel Core Ultra, AMD Ryzen AI (the note's Tier-1 genuinely-new vendors) — with `compute_axes` + `supported_precisions[]` + `vendor_status`, never a measured `n` | data | dev | 0.25 | T1 | D6 |
| **T8** | Tests + no-regression proof: existing 9 Phase 3A tests pass + new `calibration_status` tests + guardrail test (attest never confident on a prior) + builder migration test | test | qa | 0.5 | T2, T3 | metrics/guardrail |
| **T9** | Docs: case study + update `SENSING-LAYER-README.md` + `HADF-SOURCE-OF-TRUTH.md` (§ recognition catalogs) + close the `2026-04-28-hadf-signature-expansion.md` note (this feature is its execution) | docs | dev | 0.5 | T1–T8 | — |

## Dependency graph

```
T1 ──┬──> T2 ──┬──> T6
     │         └──> T8 ──> T9
     ├──> T3 ──┬──> T4
     │         ├──> T5
     │         └──> T8
     └──> T7 ─────────────> T9
```

## Notes

- **T1 is the A_high foundation** — the `calibration_status` contract is what every
  downstream task depends on; do it first, carefully, with the migration test (T8).
- **T4 is the cheapest highest-signal task** — calibrating M4 both adds an
  `instrumented` row (primary metric) and tests K2 (method generalizes M2→M4).
- **T5 may resolve to "documented harness target"** if there's no reachable
  on-device inference route for A16 this cycle — that's an acceptable PRD outcome
  (D5 explicitly allows it), not a miss.
- Sensing-only throughout — no task touches a dispatch decision (RQ4 gate intact).
