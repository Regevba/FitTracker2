# R9 Track-B — 30-Day Coverage Read (2026-07-04)

**Scheduled item:** calibration-ladder `2026-07-04 — R9 Track-B 30-day coverage read -> GATE_TEST_MISSING calibration`
(source: `scripts/integrity-data-lake.py` forward-decision digest; `docs/master-plan/test-coverage-master-plan-2026-05-13.md` T1).

**Purpose:** accumulate the 30-day coverage/telemetry baseline that the v8.0 `GATE_TEST_MISSING`
meta-gate (T1, RICE 53.3) calibrates against. `GATE_TEST_MISSING` itself is **gated on F14 Phase E
exit = 2026-08-22** — this read is the data-gathering step, not the gate ship.

---

## Headline finding: the durable 30-day dataset does not exist

The R9 Track-B `coverage.yml` workflow ran **40 times in the trailing 30 days** (all `success`, but the
jobs are `continue-on-error: true` warn-only, so `success` is unconditional). It persists **no durable,
machine-readable coverage numbers**:

| Surface | Where the number goes | Readable at T+30d? |
|---|---|---|
| iOS (Slather `--simple-output`) | CI job stdout only | NO — logs expire / unqueryable via `gh` |
| Python (`pytest --cov`) | `coverage.xml` uploaded as artifact, **14-day** retention | NO — not emitted on recent runs; window < 30d anyway |
| Either | git-committed ledger | NO — nothing committed |
| Either | `.claude/logs/gate-coverage.jsonl` (Mechanism A) | NO — 0 rows; R9 coverage is outside the telemetry stream |

**Consequence:** the "30 days of telemetry against which GATE_TEST_MISSING can calibrate concrete
per-module thresholds" (coverage.yml header comment) was never actually accumulated. The read had to be
reconstructed by running coverage locally at HEAD (below). **This is the actionable gap to close before
2026-08-22** — see Follow-ups.

---

## Current-state baseline (measured locally at HEAD `chore/w40-reconcile-2026-07-01`, 2026-07-04)

### Python — ai-engine (`pytest --cov`)
- **60 passed / 1 skipped** (matches CI expectation).
- **TOTAL: 84%** — 390 stmts, 59 miss, 70 branch, 4 brpart.
- Per-module low spots (the per-module-threshold calibration targets):

  | Module | Cover | Note |
  |---|---|---|
  | `app/auth/jwt_validator.py` | **35%** | auth path (high-risk area); 27/45 stmts uncovered (L29-44, 61-83) |
  | `app/services/cohort_service.py` | **30%** | 29/43 uncovered (L39-53, 73-90, 101-128) |
  | `app/config.py` | 92% | — |
  | `app/middleware/rate_limiter.py` | 87% | — |
  | `app/services/insight_service.py` | **100%** | deterministic rule engine (AI core) — golden-set covered |
  | all routers + models | 98-100% | — |

### iOS — Slather
- Not re-measured this read (requires a full `xcodebuild test -enableCodeCoverage YES` simulator run, ~30 min).
- CI Slather output is the only source and it is ephemeral. **No iOS baseline number is recoverable for the
  30-day window.**

### Framework scripts (dispatch + try-repo suites)
- **611 passed / 3 skipped / 2 failed** (`scripts/tests/`). Both failures are environmental network-timeout
  flakes, not real: `test_pre_commit_self_test::test_main_passes_on_real_repo` (socket timeout) and
  `test_funnel_definitions::test_drift_events_really_absent_from_csv`.

---

## GATE_TEST_MISSING pairing baseline (the readable calibration input)

`GATE_TEST_MISSING`'s primary contract is **per-gate dispatch-test pairing** (a new gate function must ship
with a paired `test_*` dispatch test). That baseline **is** readable from the repo today:

- **Layer 2 (dispatch tests): complete** — every write-time gate has a paired dispatch test, including the
  3 gates that shipped after F16: `CSV_TAXONOMY_DRIFT` (`test_csv_taxonomy_drift.py`),
  `GA4_MCP_DISCONNECTED` (`test_ga4_mcp_disconnected.py`), `PLATFORMS_TESTED` (`test_platforms_tested.py`, 17 test defs).
- **Layer 3 (try-repo fixtures, F16):** 17 gate fixture dirs under `tests/fixtures/`. The **3 post-F16 gates
  lack try-repo fixtures** (`CSV_TAXONOMY_DRIFT`, `GA4_MCP_DISCONNECTED`, `PLATFORMS_TESTED`). This is the
  concrete Layer-3 backlog to clear before `GATE_TEST_MISSING` enforces end-to-end coverage.

---

## Follow-ups (before 2026-08-22 GATE_TEST_MISSING calibration)

1. **Close the coverage-persistence gap (load-bearing).** Extend `coverage.yml` to append a numeric row
   (`{date, surface, line_rate, branch_rate, per_module[]}`) to a git-committed append-only ledger
   (e.g. `.claude/shared/coverage-telemetry.jsonl`) on push-to-main, so a real 30-day window accumulates
   before the calibration. Without this, the 2026-08-22 calibration reruns today's manual reconstruction.
   *Infra-path change (`.github/workflows/*`) -> BRANCH_ISOLATION_VIOLATION Mode B; ship on an isolated branch.*
2. **Add try-repo fixtures** for `CSV_TAXONOMY_DRIFT`, `GA4_MCP_DISCONNECTED`, `PLATFORMS_TESTED` (Layer-3 parity).
3. **Raise `jwt_validator.py` coverage (35%)** — auth is a declared high-risk area; lowest-covered module in the AI layer.

*Read performed by the 2026-07-04 data-integrity + telemetry sweep. Local measurement env: throwaway venv,
Python 3.12, `pip install -e . pytest pytest-cov pytest-asyncio`.*
