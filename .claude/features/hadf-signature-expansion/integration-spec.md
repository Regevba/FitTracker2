# Integration Spec — HADF Signature Expansion (schema + reader + harness contracts)

> **Phase 3b (Integration).** `has_ui=false`. Defines the exact data/code contracts
> before implementation. **Reality-check finding (2026-06-05):** a prior session
> already shipped most of the v1.1 *scaffolding* — this spec narrows the feature to
> the genuinely-missing piece (the `calibration_status` honesty distinction + the
> empirical calibration), per the Phase 0.1 anti-drift discipline.

## 1. Current state (what already exists — do NOT re-add)

| Element | Status | Evidence |
|---|---|---|
| `chip-profiles.json` profile count | **24** (was 17 baseline) | a prior session already added profiles |
| `supported_precisions[]` (array) + 14-value enum | ✅ shipped | `schema_v1_1_notes.supported_precisions_enum` |
| `compute_axes` (on hybrid SoCs) | ✅ shipped | present on multi-axis profiles |
| `vendor_status` | ✅ shipped | on all profiles + signatures |
| `tops_source` + `built_in_networking` enums | ✅ defined | `schema_v1_1_notes` |
| `memory_topology` **enum defined but NOT applied** | ⚠️ partial | enum in notes; 0 profiles use the field |
| **per-row `calibration_status`** | ❌ **absent everywhere** | not on profiles, per-sig, or reference endpoints |
| `reference-signatures.json` `class` (cloud/on_device) | ❌ absent | endpoint keys lack it |
| `hardware-signature-table.json` | table-level `calibration_status:"uncalibrated"`, no per-sig | all 7 sigs are static/uncalibrated |

**Consequence:** the "add static profiles" bulk of the 2026-04-28 note is largely
already done. The feature's real, remaining value is the **honesty layer** (which
rows are *measured* vs *guessed*) + the **empirical calibration** (harness + M4 +
cloud) that produces genuinely `instrumented` rows.

## 2. The real delta (this feature's scope)

1. Add per-row **`calibration_status`** ∈ `{instrumented, prior_unvalidated}` to all three catalogs + backfill existing rows (§6).
2. Add **`class`** ∈ `{cloud, on_device}` to `reference-signatures.json` endpoints.
3. Apply **`memory_topology`** to profiles where known (enum already defined).
4. **Reader/attester** (`hadf-build-reference-store.py`, `hadf-attest.py`) honor `calibration_status` (§4).
5. **On-device calibration harness** producing real `instrumented` rows (§5).
6. New `instrumented` rows: M4 (via harness) + ≥4 cloud endpoints (via builder).

## 3. Schema contract

### 3.1 `calibration_status` (the load-bearing field — all 3 files, per row)

```
calibration_status: "instrumented" | "prior_unvalidated"
```

- **`instrumented`** — the row's TTFT/TPS (or signature) was produced by *measuring
  inference on that substrate*. MUST carry a real sample count `n` (≥ a floor, default 250) + `provenance` (source files / sub-exp / harness run). The Phase 3A reference store's 8 existing endpoints are `instrumented`.
- **`prior_unvalidated`** — a spec-sheet / published-TOPS profile with no measured
  inference. MUST NOT carry a measured `n`. The 24 static `chip-profiles.json` rows + the 7 `hardware-signature-table.json` sigs are `prior_unvalidated` until calibrated.
- **Default on read:** a row missing `calibration_status` is treated as
  `prior_unvalidated` (fail-safe — never assume measured). Writers MUST set it
  explicitly going forward.

### 3.2 `reference-signatures.json` endpoint additions

```jsonc
{
  "provider": "...", "endpoint": "...", "n": 2239,
  "ttft_s": {...}, "tps": {...}, "mean": [...], "cov": [...],
  "provenance": {...},
  "calibration_status": "instrumented",   // NEW — builder always stamps this
  "class": "cloud" | "on_device"          // NEW — on_device for harness rows
}
```

The builder (`hadf-build-reference-store.py`) stamps `calibration_status:"instrumented"`
+ `class` (default `cloud`; `on_device` when the source rows are harness-tagged).

### 3.3 `memory_topology` (apply where known)

`"discrete" | "soc_unified" | "in_package_unified" | "rack_scale_pooled"` — add to
profiles where determinable (e.g. Apple SoCs → `soc_unified`; MI300A → `in_package_unified`). Optional; absence = unknown.

## 4. Reader / attester behavior contract

### 4.1 `hadf-build-reference-store.py`
- Every emitted endpoint gets `calibration_status:"instrumented"` + `class`.
- New flag `--class {cloud,on_device}` (default `cloud`) — harness output uses `on_device`.
- Existing 9 tests MUST still pass (no behavior change on the cloud baseline beyond the two new always-present fields).

### 4.2 `hadf-attest.py` (the guardrail)
- Attestation reads the reference store. It **only matches against `instrumented` rows.**
- `prior_unvalidated` rows (if ever loaded into a store) are **excluded from the candidate set** — never returned as a `strong`/`weak` match. If the closest match is a prior, disposition is `uncertain` with a note `"nearest reference is an unvalidated prior — not a measured match"`.
- This is test-enforced (guardrail metric): a fixture store containing a prior must never produce a confident attestation against it.

## 5. On-device calibration harness contract (`scripts/hadf-calibrate-device.py`)

**Purpose:** generalize Sub-exp 2 (ollama-on-M2) into a reusable per-chip runner.

```
hadf-calibrate-device.py --model <ollama-model> --device-label <e.g. "apple_m4"> \
    --n 250 [--out .claude/shared/hadf/reference-signatures.json] [--as-of YYYY-MM-DD]
```

- **Collect:** stream `--n` completions from a local inference endpoint (ollama), recording per-request `ttft_s` + `tps` (same fields as the sub-exp collectors).
- **Aggregate:** reuse the reference-store quantile/mean/cov math; emit ONE endpoint row with `provider="on-device"`, `endpoint=<device-label>`, `class="on_device"`, `calibration_status="instrumented"`, real `n` + `provenance:{method:"hadf-calibrate-device", host:<device-label>, model:<model>}`.
- **Idempotent:** re-running for the same device-label replaces that row.
- **Output:** appends/updates the row in `reference-signatures.json` (the unified store) — resolving §9 OQ in the PRD toward a unified store with a `class` tag, NOT a separate file.
- **Tests:** stdlib `http.server`-backed harness (no real ollama needed in CI), mirroring `test_probe_deployed_url.py` style — assert the emitted row shape + class + calibration_status + that a planted-latency stream produces the expected quantiles.

## 6. Migration (backfill existing rows)

| File | Rows | Backfill to |
|---|---|---|
| `reference-signatures.json` | 8 existing endpoints | `calibration_status:"instrumented"`, `class:"cloud"` |
| `chip-profiles.json` | 24 static profiles | `calibration_status:"prior_unvalidated"` (compute_budget stays; it's a published prior) |
| `hardware-signature-table.json` | 7 static sigs | per-sig `calibration_status:"prior_unvalidated"` (table-level field retained for back-compat) |

Migration is a mechanical one-pass script + committed in T1. The migration test (T8)
asserts: every row in all three files has a `calibration_status`; no `prior_unvalidated`
row carries a measured `n`; the 8 reference endpoints are `instrumented`.

## 7. Backward compatibility + error handling

- **Back-compat:** readers that don't know `calibration_status` ignore the extra field (additive). The `hardware-signature-table.json` table-level `calibration_status` stays so nothing that reads it breaks.
- **Fail-safe default:** missing `calibration_status` ⇒ treated as `prior_unvalidated` (never assume measured).
- **Malformed rows:** a row with `calibration_status:"instrumented"` but no `n` (or `n=0`) is a schema error → migration/builder test fails loudly.
- **No regression:** the 8-endpoint Phase 3A baseline + its 9 tests are the regression guard; attestation discrimination on the calibrated set must be unchanged.

## 8. Honesty boundary

Sensing/recognition only. No task changes a dispatch decision. `calibration_status`
is the mechanical guarantee that *measured* and *guessed* are never conflated — the
HADF program's central honesty commitment, applied to its own catalog.
