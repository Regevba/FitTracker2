# Framework Facts — Canonical Current-State Reference

> **Single source of truth for "what is the framework right now."** Machine-derived; cite this from any *living* doc instead of hand-copying counts (which drift). Historical docs (case studies, dated specs/plans, audit runs, per-feature PRDs) are **point-in-time records** and intentionally keep the numbers/version of the era they were written — do **not** bump them to match this file.

**Last reconciled:** 2026-06-26 (derived from `.claude/shared/gate-last-fired.json` F17 index + `.claude/features/*/state.json` + `scripts/check-state-schema.py` + `scripts/integrity-check.py`). 2026-06-26 (later): +1 feature (`f18-mutation-testing`, F18 — warn-only mutation testing on the gate dispatchers, PR #809; no new state.json gate — a weekly CI lint + `make mutation-test`). Earlier 2026-06-26: +1 feature (`funnel-analysis-dashboards`, F22 — live GA4 funnel analysis, PR #799; no new state.json gate); F4 `FRAMEWORK_VERSION_STALE` now emitting Mechanism A coverage (31 fires). Prior reconcile 2026-06-22: +1 feature (`contract-fixture-consumer-adoption`, E-15 — no new gates; the consumer `contract:check` is a warn-only CI lint, not a state.json gate).

## Current state

| Fact | Value | Source of truth |
|---|---|---|
| **Framework version** | **v7.10** (shipped 2026-06-10) | CLAUDE.md "v7.10" section |
| **Features tracked** | **118** (115 complete · 3 in-flight: `3d-interactive-framework-flow-diagram`, `app-store-assets`, `orchid-v1-5`) | `.claude/features/*/state.json` |
| **Instrumented gates (F17 index)** | **30** total — **18 write-time emitting + 9 cycle-time + 2 W9 hooks + 1 standalone (`FIGMA_MIRROR_STALENESS`, runs via `make figma-mirror-staleness`)** (f1 `STATE_TASKS_FILESYSTEM_DRIFT` + f3 `DEPENDENCY_GRAPH_CYCLE` advisories added 2026-06-17 #752/#753; F4 `FRAMEWORK_VERSION_STALE` now emitting since ~2026-06-21, 31 fires) | `.claude/shared/gate-last-fired.json` |
| **Gates actively firing** | **27 of 30** (the 3 non-firing are healthy-zero — have candidates, 0 violations: `STATE_OWNER_MISSING`, `w9.auto_isolate`, `w9.concurrency`) | F17 index `total_firings > 0` |
| **Integrity status** | **0 findings, 0 real regressions** | `make integrity-check` / `make integrity-multi-anchor` |
| **Open PRs** | 4 (FT2 — all bot/cron or held: #805/#806 cron snapshots, #803 cleanup chore, #798 astro deps **HELD** per W29) · 0 (fitme-story) | `gh pr list` |

### Write-time gates (18, fire on `git commit` via `scripts/check-state-schema.py`)
`BRANCH_ISOLATION_VIOLATION` (Mode B) · `BRANCH_ISOLATION_VIOLATION_MODE_C` · `CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT` · `CU_V2_INVALID` · `FEATURE_CLOSURE_COMPLETENESS` · `FRAMEWORK_VERSION_FORMAT` · `FRAMEWORK_VERSION_STALE` (advisory until ~2026-06-30) · `ISOLATION_OPT_OUT_REASON_MISSING` · `PHASE_TRANSITION_NO_LOG` · `PHASE_TRANSITION_NO_TIMING` · `PLATFORMS_TESTED` (**enforced 2026-06-21**, PR #781) · `PR_NUMBER_UNRESOLVED` · `SCHEMA_DRIFT_LEGACY_CREATED` · `SCHEMA_DRIFT_LEGACY_PHASE` · `STATE_NO_CASE_STUDY_LINK` · `STATE_OWNER_INVALID` · `STATE_OWNER_LOCATION_MISMATCH` · `STATE_OWNER_MISSING`

### Cycle-time checks (9 instrumented, fire every 72h via `scripts/integrity-check.py`)
`BROKEN_PR_CITATION` · `CASE_STUDY_MISSING_TIER_TAGS` · `PATTERN_SKILL_UNMAPPED` · `TIER_TAG_LIKELY_INCORRECT` (advisory) · `PHASE_LIE` · `CACHE_HITS_AUTO_INSTRUMENTATION_INACTIVE` (advisory) · `BRANCH_ISOLATION_HISTORICAL` (advisory) · `STATE_TASKS_FILESYSTEM_DRIFT` (f1, advisory-permanent, shipped 2026-06-17 #752) · `DEPENDENCY_GRAPH_CYCLE` (f3, advisory-permanent, shipped 2026-06-17 #753). Additional cycle-time codes exist in code but have not yet emitted Mechanism A coverage (e.g. `GATE_COVERAGE_ZERO`, `TASK_LIE`, `PR_CACHE_REFRESH_FAILED`).

**Standalone advisory (not via `integrity-check.py`):** `FIGMA_MIRROR_STALENESS` — `make figma-mirror-staleness` (`scripts/figma-mirror-staleness.py`), shipped 2026-06-18 (`figma-design-architecture`, Gap D). Advisory-permanent; emits `mode=cycle` Mechanism A coverage; checks code-token (`tokens.json`) ↔ Figma-mirror-snapshot drift. Counted separately from the 9 integrity-check cycle-time codes because it runs on its own target.

### W9 real-time hooks (2)
`w9.auto_isolate` · `w9.concurrency` (PostToolUse drift detection; calibration re-eval ~2026-06-28).

## Calibration ladder (date-gated)
- ~~**2026-06-18** — F16 try-repo harness advisory→enforced flip~~ ✅ **ENFORCED 2026-06-17** (1 day early; `try-repo-harness` added to main required status checks. K2 false-positive rate 0% over 13d/60 runs. Reversible via `gh api` required-checks edit)
- ~~**2026-06-21** — `PLATFORMS_TESTED` (T14) advisory→enforced review (B15)~~ ✅ **ENFORCED 2026-06-21** (PR #781, `6ac372b`; all four §2.2 criteria GREEN — 0 false positives across 16 real complete-transition checks, ≥7d coverage, 1470 legit skips, single-flag reversible)
- **2026-06-28** — W9 drift-auto-isolation calibration (reset from 06-20 by the 2026-06-14 session-id-keying fix; clock restarts on the `w9.concurrency` key)
- **~2026-06-30** — F4 `FRAMEWORK_VERSION_STALE` advisory→enforced review (14-day window from 2026-06-16 ship)
- **2026-07-04** — R9 Track-B 30-day coverage read → feeds `GATE_TEST_MISSING`
- **2026-08-12** — Data Freshness Audit #1 (uses F17 index)

## Note on historical counts
Earlier versions reported different totals because the gate set grew over time and because some docs counted *mechanisms* (gates + CI workflows + hooks ≈ "37") while others counted *gate codes* (≈ "26") or *write-time-only* (≈ "16-17"). When a doc says "25 gates + 1 advisory" or "37 mechanical gates," check its date — it is almost certainly an accurate record of an earlier era, not current state. This file is the only place that tracks *current*.
