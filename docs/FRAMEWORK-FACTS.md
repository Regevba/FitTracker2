# Framework Facts — Canonical Current-State Reference

> **Single source of truth for "what is the framework right now."** Machine-derived; cite this from any *living* doc instead of hand-copying counts (which drift). Historical docs (case studies, dated specs/plans, audit runs, per-feature PRDs) are **point-in-time records** and intentionally keep the numbers/version of the era they were written — do **not** bump them to match this file.

**Last reconciled:** 2026-06-15 (derived from `.claude/shared/gate-last-fired.json` F17 index + `.claude/features/*/state.json` + `scripts/check-state-schema.py` + `scripts/integrity-check.py`).

## Current state

| Fact | Value | Source of truth |
|---|---|---|
| **Framework version** | **v7.10** (shipped 2026-06-10) | CLAUDE.md "v7.10" section |
| **Features tracked** | **106** | `.claude/features/*/state.json` |
| **Instrumented gates (F17 index)** | **26** total — **17 write-time + 7 cycle-time + 2 W9 hooks** | `.claude/shared/gate-last-fired.json` |
| **Gates actively firing** | **19 of 26** (rest are healthy-zero or in calibration) | F17 index `total_firings > 0` |
| **Integrity status** | **0 findings, 0 real regressions** | `make integrity-check` / `make integrity-multi-anchor` |
| **Open PRs** | 0 (FT2) · 0 (fitme-story) | `gh pr list` |

### Write-time gates (17, fire on `git commit` via `scripts/check-state-schema.py`)
`BRANCH_ISOLATION_VIOLATION` (Mode B) · `BRANCH_ISOLATION_VIOLATION_MODE_C` · `CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT` · `CU_V2_INVALID` · `FEATURE_CLOSURE_COMPLETENESS` · `FRAMEWORK_VERSION_FORMAT` · `ISOLATION_OPT_OUT_REASON_MISSING` · `PHASE_TRANSITION_NO_LOG` · `PHASE_TRANSITION_NO_TIMING` · `PLATFORMS_TESTED` (advisory until 2026-06-21) · `PR_NUMBER_UNRESOLVED` · `SCHEMA_DRIFT_LEGACY_CREATED` · `SCHEMA_DRIFT_LEGACY_PHASE` · `STATE_NO_CASE_STUDY_LINK` · `STATE_OWNER_INVALID` · `STATE_OWNER_LOCATION_MISMATCH` · `STATE_OWNER_MISSING`

### Cycle-time checks (7 instrumented, fire every 72h via `scripts/integrity-check.py`)
`BROKEN_PR_CITATION` · `CASE_STUDY_MISSING_TIER_TAGS` · `PATTERN_SKILL_UNMAPPED` · `TIER_TAG_LIKELY_INCORRECT` (advisory) · `PHASE_LIE` · `CACHE_HITS_AUTO_INSTRUMENTATION_INACTIVE` (advisory) · `BRANCH_ISOLATION_HISTORICAL` (advisory). Additional cycle-time codes exist in code but have not yet emitted Mechanism A coverage (e.g. `GATE_COVERAGE_ZERO`, `TASK_LIE`, `PR_CACHE_REFRESH_FAILED`).

### W9 real-time hooks (2)
`w9.auto_isolate` · `w9.concurrency` (PostToolUse drift detection; calibration re-eval ~2026-06-28).

## Calibration ladder (date-gated)
- **2026-06-18** — F16 try-repo harness advisory→enforced flip
- **2026-06-20** — W9 drift-auto-isolation calibration
- **2026-06-21** — `PLATFORMS_TESTED` (T14) advisory→enforced review (B15)
- **2026-07-04** — R9 Track-B 30-day coverage read → feeds `GATE_TEST_MISSING`
- **2026-08-12** — Data Freshness Audit #1 (uses F17 index)

## Note on historical counts
Earlier versions reported different totals because the gate set grew over time and because some docs counted *mechanisms* (gates + CI workflows + hooks ≈ "37") while others counted *gate codes* (≈ "26") or *write-time-only* (≈ "16-17"). When a doc says "25 gates + 1 advisory" or "37 mechanical gates," check its date — it is almost certainly an accurate record of an earlier era, not current state. This file is the only place that tracks *current*.
