# Framework Facts — Canonical Current-State Reference

> **Single source of truth for "what is the framework right now."** Machine-derived; cite this from any *living* doc instead of hand-copying counts (which drift). Historical docs (case studies, dated specs/plans, audit runs, per-feature PRDs) are **point-in-time records** and intentionally keep the numbers/version of the era they were written — do **not** bump them to match this file.

**Last reconciled:** 2026-07-10 (derived from `.claude/shared/gate-last-fired.json` F17 index + `.claude/features/*/state.json` + `scripts/check-state-schema.py` + `scripts/integrity-check.py`). **2026-07-05 → 07-09 ships:** `SCHEMA_DIFF` (T12/FIT-160) advisory gate — 34th live gate (#862); F4 `FRAMEWORK_VERSION_STALE` promoted advisory→**enforced** 2026-07-08 (#858); FIT-210 scheduler v2 wiring (#863); UCC auth-lockout surfaced in weekly digest (#859); internal-storage declared canonical, SSD → build drive (#856). Feature/instrumented-gate counts unchanged (130 / 32); live-gate count 33 → 34. **2026-07-03 → 07-04 test-coverage batch (7 bucket-A items):** feature count **121 → 130** — 3 flipped to complete (`t16-gate-test-tier-annotation`, `precommit-hook-latency-profiling`, `weekly-digest-silent-gate-enrichment`) + 6 new test-coverage-plan items (`t8-web-webauthn-route-handler-tests`, `t7-web-critical-route-smoke-tests`, `t15-orphan-test-weekly-cron`, `t4-ios-snapshot-testing`, `r17-state-sync-health-endpoint`, `t9-backend-chaos-tests`). **0 new gates** (**32 unchanged** — all shipped items are tests / CI-observability, not enforcement gates). CI workflows **→ 25** (added `orphan-tests-weekly.yml` + `ios-snapshot-record.yml`). `t4-ios-snapshot-testing` + `t9-backend-chaos-tests` ship as **foundation slices** (state at `implement`, follow-up tasks tracked). Linear FIT-164/181/185/156/155/163/152/183/157. **Prior — 2026-06-29 session:** +3 feature dirs (`an-1b1-csv-taxonomy-drift`, `an-1b2-ga4-mcp-disconnected`, `de-r14-integrity-parallel`) → 121 features; **+2 write-time gates** (`CSV_TAXONOMY_DRIFT` advisory + `GA4_MCP_DISCONNECTED` advisory-only) → 32 gates; new cross-layer **naming convention** (`FIT-200`: slug + `state.json.linear_id` + scheme-prefixed codes, `make crosswalk` → `item-registry.json`); new `state.json.schema_version` field + `make migrate-state-schema` (DE-R18); integrity-check **parallelized** 9.4s→1.84s (DE-R14); observed-patterns **W40**. (cross-layer-item-naming-convention + de-r18 ship via PR + Linear FIT-200/FIT-184 — no feature dir, tracked via Linear.) Prior reconcile 2026-06-26: +1 feature (`f18-mutation-testing`, F18, PR #809); +1 feature (`funnel-analysis-dashboards`, F22, PR #799); F4 `FRAMEWORK_VERSION_STALE` emitting. 2026-06-22: +1 (`contract-fixture-consumer-adoption`, E-15).

## Current state

| Fact | Value | Source of truth |
|---|---|---|
| **Framework version** | **v7.10** (shipped 2026-06-10) | CLAUDE.md "v7.10" section |
| **Features tracked** | **130** (125 complete · 5 in-flight: `3d-interactive-framework-flow-diagram`, `app-store-assets`, `orchid-v1-5`, `t4-ios-snapshot-testing`, `t9-backend-chaos-tests` — the last 2 are test-coverage **foundation slices** at `implement`, follow-up tasks tracked in their state.json) | `.claude/features/*/state.json` |
| **Instrumented gates (F17 index)** | **32** total — **20 write-time emitting + 9 cycle-time + 2 W9 hooks + 1 standalone (`FIGMA_MIRROR_STALENESS`)** (added 2026-06-29: `CSV_TAXONOMY_DRIFT` AN-1B.1 advisory + `GA4_MCP_DISCONNECTED` AN-1B.2 advisory-only) | `.claude/shared/gate-last-fired.json` |
| **Gates actively firing** | **28 of 32** (the 4 non-firing are healthy-zero — have candidates, 0 violations: `STATE_OWNER_MISSING`, `w9.auto_isolate`, `w9.concurrency`, `CSV_TAXONOMY_DRIFT` [awaits an AnalyticsProvider.swift commit to exercise its fire path]) | F17 index `total_firings > 0` |
| **Integrity status** | **0 findings, 0 real regressions** | `make integrity-check` / `make integrity-multi-anchor` |
| **Open PRs** | 0 (FT2) · 0 (fitme-story) — all this-session PRs merged | `gh pr list` |

### Write-time gates (20, fire on `git commit` via `scripts/check-state-schema.py`)
`BRANCH_ISOLATION_VIOLATION` (Mode B) · `BRANCH_ISOLATION_VIOLATION_MODE_C` · `CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT` · `CSV_TAXONOMY_DRIFT` (AN-1B.1, **enforced 2026-07-13**, cadence B16; fires when `AnalyticsProvider.swift` is staged + an `AnalyticsEvent` value has no taxonomy CSV row) · `CU_V2_INVALID` · `FEATURE_CLOSURE_COMPLETENESS` · `FRAMEWORK_VERSION_FORMAT` · `FRAMEWORK_VERSION_STALE` (**enforced 2026-07-08**, PR #858) · `GA4_MCP_DISCONNECTED` (AN-1B.2, advisory-ONLY by design — never blocks; fires when analytics-affecting code is staged + GA4 env unreachable) · `ISOLATION_OPT_OUT_REASON_MISSING` · `PHASE_TRANSITION_NO_LOG` · `PHASE_TRANSITION_NO_TIMING` · `PLATFORMS_TESTED` (**enforced 2026-06-21**, PR #781) · `PR_NUMBER_UNRESOLVED` · `SCHEMA_DRIFT_LEGACY_CREATED` · `SCHEMA_DRIFT_LEGACY_PHASE` · `STATE_NO_CASE_STUDY_LINK` · `STATE_OWNER_INVALID` · `STATE_OWNER_LOCATION_MISMATCH` · `STATE_OWNER_MISSING`

### Cycle-time checks (9 instrumented, fire every 72h via `scripts/integrity-check.py`)
`BROKEN_PR_CITATION` · `CASE_STUDY_MISSING_TIER_TAGS` · `PATTERN_SKILL_UNMAPPED` · `TIER_TAG_LIKELY_INCORRECT` (advisory) · `PHASE_LIE` · `CACHE_HITS_AUTO_INSTRUMENTATION_INACTIVE` (advisory) · `BRANCH_ISOLATION_HISTORICAL` (advisory) · `STATE_TASKS_FILESYSTEM_DRIFT` (f1, advisory-permanent, shipped 2026-06-17 #752) · `DEPENDENCY_GRAPH_CYCLE` (f3, advisory-permanent, shipped 2026-06-17 #753). Additional cycle-time codes exist in code but have not yet emitted Mechanism A coverage (e.g. `GATE_COVERAGE_ZERO`, `TASK_LIE`, `PR_CACHE_REFRESH_FAILED`).

**Standalone advisory (not via `integrity-check.py`):** `FIGMA_MIRROR_STALENESS` — `make figma-mirror-staleness` (`scripts/figma-mirror-staleness.py`), shipped 2026-06-18 (`figma-design-architecture`, Gap D). Advisory-permanent; emits `mode=cycle` Mechanism A coverage; checks code-token (`tokens.json`) ↔ Figma-mirror-snapshot drift. Counted separately from the 9 integrity-check cycle-time codes because it runs on its own target.

### W9 real-time hooks (2)
`w9.auto_isolate` · `w9.concurrency` (PostToolUse drift detection). **Calibration RESOLVED 2026-06-28: HOLD at advisory** — `CLAUDE_W9_CONCURRENCY_ENFORCE` stays default-off (criterion 2 vacuous: 0 `concurrency_offer` events in the window). Re-eval now event-gated (first real offer).

### Gate catalog (T16 / TC-T16, machine-derived)

[`.claude/shared/gate-catalog.json`](../.claude/shared/gate-catalog.json) (`make gate-catalog`, producer `scripts/gate-catalog.py`) is the machine-derived enumeration of **all 34 live gates** (added 2026-07-09: `SCHEMA_DIFF` T12/FIT-160 advisory) — each annotated with an authored `stage` (write-time | cycle-time | hook | standalone) + `source`, and a **derived** test `tier` (try-repo > dispatch > unit > none) computed by scanning `tests/fixtures/` + `scripts/tests/` live. `make gate-catalog-check` validates it in CI (fails on drift or an orphan try-repo fixture).

**Live (34) vs instrumented (32):** the catalog counts every gate that fires; the F17 index above counts every gate that emits Mechanism A coverage. The 2-gate delta is **`CASE_STUDY_MISSING_FIELDS`** (hosted in `scripts/check-case-study-preflight.py`, emits no coverage) and **`SCHEMA_DIFF`** (T12/FIT-160, shipped 2026-07-09 advisory; emits Mechanism A coverage but only enters the F17 index once its first real firing stages a migration/SupabaseSyncService change). The `CASE_STUDY_MISSING_FIELDS` — a live, enforced write-time gate hosted in `scripts/check-case-study-preflight.py` (the *second* pre-commit gate host, distinct from `check-state-schema.py`) that emits no Mechanism A coverage, so it is invisible to both the F17 index and `GATE_COVERAGE_ZERO`. Follow-up candidate: instrument it.

**T1 precursor:** `summary.write_time_without_try_repo` lists the 4 write-time gates lacking a try-repo fixture (`CSV_TAXONOMY_DRIFT`, `GA4_MCP_DISCONNECTED`, `PLATFORMS_TESTED`, `PR_NUMBER_UNRESOLVED`) — the machine signal the planned **T1 `GATE_TEST_MISSING`** meta-gate consumes.

### New infra (2026-06-29 session)

- **Cross-layer naming convention** (FIT-200) — every item carries slug (canonical) + `state.json.linear_id` (FIT-NNN) + scheme-prefixed code (`FW-`/`TC-`/`DE-`/`HADF-`/`AN-`/`PROD-`). `make crosswalk` → `.claude/shared/item-registry.json`. Spec: `docs/process/cross-layer-item-naming-convention.md`.
- **`state.json.schema_version`** (DE-R18, current = 1) — all 121 backfilled; `make migrate-state-schema` runs an ordered migration registry.
- **integrity-check parallelized** (DE-R14) — `--jobs` flag (default min(8,cpu)); 9.4s → 1.84s via memoized + ThreadPool `first_commit_date`.

### Test-coverage batch (2026-07-03 → 07-04) — test-coverage-master-plan §4

No new gates; all test/observability. Per-item live status: `.claude/shared/item-registry.json`.

- **T8** (FIT-156) — 28 WebAuthn route-handler tests for all 6 fitme-story `/api/auth/*` handlers (in-memory Redis via `__setRedisForTests` + `next/headers` module-mock). fitme-story PR #256.
- **T7** (FIT-155) — 5-route Playwright smoke (`e2e/routes/critical-routes.smoke.spec.ts`) + `DASHBOARD_PUBLIC` webServer bypass. fitme-story PR #257.
- **T15** (FIT-163) — `scripts/scan-orphan-tests.py` orphan-test + untested-symbol scanner (advisory) + `orphan-tests-weekly.yml` cron + `make orphan-tests` + 11 unit tests. FT2 PR #842.
- **R17** (FIT-183) — cross-repo state-sync health endpoint: fitme-story `GET /api/control-room/state-sync-health` (`computeSyncHealth`, 200 fresh/503 stale) + FT2 `daily-integrity-checkpoint.py` N4 probe. fitme-story #258 + FT2 #844.
- **T4** (FIT-152, *foundation*) — `pointfreeco/swift-snapshot-testing` SPM dep + `SNAPSHOT_MODE` harness (skip-by-default) + `ios-snapshot-record.yml` record-in-CI. Baselines record in CI (local iOS 26 ≠ CI iOS 18). FT2 PR #843. Follow-ups T2/T3.
- **T9** (FIT-157, *foundation*) — 3 `EncryptionService` session-context chaos tests (concurrency / large-payload / no-cross-contamination). Biometric-gated `rotateKeys` untestable on CI sim → deferred. FT2 PR #846. Follow-ups T2/T3.

## Calibration ladder (date-gated)
- ~~**2026-06-18** — F16 try-repo harness advisory→enforced flip~~ ✅ **ENFORCED 2026-06-17** (1 day early; `try-repo-harness` added to main required status checks. K2 false-positive rate 0% over 13d/60 runs. Reversible via `gh api` required-checks edit)
- ~~**2026-06-21** — `PLATFORMS_TESTED` (T14) advisory→enforced review (B15)~~ ✅ **ENFORCED 2026-06-21** (PR #781, `6ac372b`; all four §2.2 criteria GREEN — 0 false positives across 16 real complete-transition checks, ≥7d coverage, 1470 legit skips, single-flag reversible)
- ~~**2026-06-28** — W9 drift-auto-isolation calibration~~ ✅ **RESOLVED 2026-06-28: HOLD at advisory** (criterion 2 vacuous; re-eval now event-gated)
- ~~**~2026-06-30** — F4 `FRAMEWORK_VERSION_STALE` advisory→enforced review (14-day window from 2026-06-16 ship)~~ ✅ **ENFORCED 2026-07-08** (cadence F4, PR #858; 8 emission days / 40 fires / 0 false positives / canonical v7.10)
- **2026-07-04** — R9 Track-B 30-day coverage read → feeds `GATE_TEST_MISSING`
- ~~**~2026-07-13** — `CSV_TAXONOMY_DRIFT` (AN-1B.1) advisory→enforced review (B16)~~ ✅ **ENFORCED 2026-07-13** (cadence B16; all 4 §8.2 criteria GREEN — 8 emission days 06-29→07-11, baseline drift 27→0 + live drift 0, 0 false positives, single-flag reversible). `GA4_MCP_DISCONNECTED` (AN-1B.2) stays advisory-only by design — no flip.
- **2026-08-12** — Data Freshness Audit #1 (uses F17 index)

## Note on historical counts
Earlier versions reported different totals because the gate set grew over time and because some docs counted *mechanisms* (gates + CI workflows + hooks ≈ "37") while others counted *gate codes* (≈ "26") or *write-time-only* (≈ "16-17"). When a doc says "25 gates + 1 advisory" or "37 mechanical gates," check its date — it is almost certainly an accurate record of an earlier era, not current state. This file is the only place that tracks *current*.
