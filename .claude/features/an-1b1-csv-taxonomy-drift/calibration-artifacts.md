# AN-1B.1 — `CSV_TAXONOMY_DRIFT` — Phase A Calibration Artifacts

> **Authored alongside code** per the Calibration Protocol for new gates
> (analytics-master-plan §3.5.1 + §8.2/§8.4). v8.x docket item **F19**
> (Theme C — schema/measurement drift). Tracked: Linear **FIT-145**,
> thematic code **AN-1B.1**. Convention: [`docs/process/cross-layer-item-naming-convention.md`](../../../docs/process/cross-layer-item-naming-convention.md).

## Problem (the gap F19/AN-1B.1 closes)

The canonical analytics taxonomy lives at [`docs/product/analytics-taxonomy.csv`](../../../docs/product/analytics-taxonomy.csv);
the events actually emitted live in the `AnalyticsEvent` enum in
[`AnalyticsProvider.swift`](../../../FitTracker/Services/Analytics/AnalyticsProvider.swift).
Nothing mechanically kept them in sync — an event constant could be added in
code and emitted to GA4 without a documented taxonomy row (no screen-scope,
no parameter contract, no conversion flag). The `/analytics validate`
sub-command checks naming convention but is not a write-time gate.

## Gate design (per §8.2)

| Field | Value |
|---|---|
| **Gate id / emission key** | `CSV_TAXONOMY_DRIFT` |
| **Function** | `check_csv_taxonomy_drift(staged_files, *, coverage, repo_root)` |
| **File** | `scripts/check-state-schema.py` |
| **Dispatch site** | `main()` commit-level block (staged mode), after the BRANCH_ISOLATION Mode-B check; advisory findings print to stderr |
| **Mode flag** | `CSV_TAXONOMY_DRIFT_ADVISORY_MODE = True` (independent flip, like `FRAMEWORK_VERSION_STALE_ADVISORY_MODE`) |
| **Class** | Write-time, commit-level, advisory → enforced after calibration |
| **Severity at ship** | advisory (prints to stderr, rc stays 0) |

### Fire condition

Fires when **all** hold (staged mode only):
1. `FitTracker/Services/Analytics/AnalyticsProvider.swift` is in the staged-file set.
2. An `AnalyticsEvent` constant's raw value (`static let X = "value"`) is **not**
   present in the CSV `Event Name` column.
3. The constant is **not** listed in any feature state.json `csv_taxonomy_exempt`.

### Skip reasons (every candidate ends checked or skipped)

| Reason | Meaning |
|---|---|
| `analytics_provider_not_staged` | the commit doesn't touch AnalyticsProvider.swift — nothing to check |

### Exemptions (false-positive guards)

- **`csv_taxonomy_exempt`** — state.json array `[{constant, reason}]`; bypasses a
  named constant (e.g. a constant temporarily defined mid-refactor).
- **`[FORWARD-DECLARED]` rows** — forward-declared CSV rows are still rows in the
  CSV, so an enum constant matching one passes (enum→CSV direction only).

## Baseline drift (measured 2026-06-29 at ship)

First real-repo run found **27 drift items** — `AnalyticsEvent` constants emitted
in code with no taxonomy CSV row (home-readiness/trend-alert, home-ai-feedback,
training-exercise-library/search, training-custom-program, … families). This is
the **calibration baseline drift count** per §333. The gate ships **advisory** so
this baseline is measured, not blocking; the burndown (add the 27 CSV rows with
full parameter contracts) is the calibration-window work (task T6). The gate only
fires on commits that stage AnalyticsProvider.swift, so it never blocks unrelated
work during the window.

## Promotion criteria (advisory → enforced; all four required)

| # | Criterion | How measured |
|---|---|---|
| 1 | **Coverage emitted** — ≥7 days of `{candidates, checked, skipped}` rows | `gate-coverage.jsonl` grep `CSV_TAXONOMY_DRIFT` |
| 2 | **Baseline burned down** — drift count = 0 (27 CSV rows added or exempted) | `_parse_analytics_event_values` ∖ `_parse_csv_event_names` ∖ exemptions |
| 3 | **No false positives** — every fired row maps to a genuinely-undocumented event | manual review at flip |
| 4 | **Reversibility** — advisory restorable in <2 min (set `CSV_TAXONOMY_DRIFT_ADVISORY_MODE = True`) | single-flag flip |

## Kill criteria

- **KC1** — if burndown to 0 proves impractical (events legitimately can't carry a
  taxonomy row), hold at advisory + widen the exemption mechanism.
- **KC2** — false-positive rate >10% at any point in the window → re-scope the
  parser (e.g. nested-enum handling) before any flip.

## Reversibility contract (per §8.2)

- Advisory rollback: <2 min — set `CSV_TAXONOMY_DRIFT_ADVISORY_MODE = True`.
- Enforced rollback: <5 min — flag flip + pre-commit header note.

## Test coverage

[`scripts/tests/test_csv_taxonomy_drift.py`](../../../scripts/tests/test_csv_taxonomy_drift.py) — 7 tests:
enum-block-scoped parse, CSV Event-Name parse, drift detection, no-drift,
exemption suppression, not-staged skip, coverage candidate/skip. Runs in 0.04s.
