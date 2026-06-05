---
slug: r9-track-b-coverage-aggregator
title: "R9 Track B — code-coverage aggregator (Makefile + CI workflow)"
date_written: 2026-06-04
framework_version: v7.9.1
work_type: Chore
work_subtype: framework_feature
case_study_type: shipped
tier_tags_required: true
status: shipped
case_study: docs/case-studies/r9-track-b-coverage-aggregator-case-study.md
case_study_showcase: ""
related_prs: [626]
dispatch_pattern: serial
success_metrics:
  - name: make_targets_added
    baseline: 0
    target: 3
    significance: descriptive
    review_at: 2026-06-04
    tier: T1
    note: "(T1) coverage-ios + coverage-py + coverage-report. Measured by presence in Makefile + PHONY declaration."
  - name: ci_workflow_added
    baseline: 0
    target: 1
    significance: descriptive
    review_at: 2026-06-04
    tier: T1
    note: "(T1) .github/workflows/coverage.yml with two jobs (coverage-ios on macos-15, coverage-py on ubuntu-latest), both continue-on-error: true. Measured by yaml lint + file presence."
  - name: telemetry_accumulation_days
    baseline: 0
    target: 30
    significance: blocking
    review_at: 2026-07-04
    tier: T2
    note: "(T2) 30 days of CI runs against which the v8.0 GATE_TEST_MISSING meta-gate can calibrate per-module thresholds. Measured at 2026-07-04 by counting completed workflow runs in the GH Actions UI."
kill_criteria:
  - "Coverage workflow flakes on a single iOS test and gates PRs"
  - "Slather aggregation breaks on a future Xcode version"
  - "Coverage output bloats CI logs"
kill_criteria_resolution: "All 3 mitigated by design. (1) continue-on-error: true on every job — a flake produces an annotation but the PR-level check still resolves to success. (2) `command -v slather` guard in the Makefile + ls-of-xcresult guard; missing tool prints skip notice and exits 0. (3) `| tail -30` on pytest output for the summary + coverage.xml uploaded as a 14-day-retention artifact for full data."
primary_metric: "make_targets_added = 3 (T1, present in Makefile at merge time)"
predecessor_case_study: docs/case-studies/framework-v7-9-promotion-case-study.md
spec: "docs/master-plan/dev-env-master-plan-2026-05-24.md §3 R9 Track B"
key_numbers:
  track_a_ship_date: "2026-05-25"
  track_b_ship_date: "2026-06-04"
  make_targets_added: 3
  ci_jobs_added: 2
  surfaces_covered: "iOS (Slather) + Python (pytest-cov)"
  surfaces_out_of_scope: "Web c8 (lives in fitme-story)"
  warn_only_baseline: true
  artifact_retention_days: 14
  calibration_window_target_days: 30
---

## TL;DR (T1 unless tagged)

R9 Track A shipped 2026-05-25 (`.slather.yml` for iOS + `[tool.coverage.*]` for ai-engine). This PR ships R9 Track B — the operator surface that makes those configs useful day-to-day:

- **3 new Makefile targets** — `coverage-ios` (Slather), `coverage-py` (pytest-cov), `coverage-report` (meta-aggregator with per-surface summary)
- **1 new CI workflow** — [`.github/workflows/coverage.yml`](.github/workflows/coverage.yml) with 2 jobs (iOS Slather on macos-15, Python pytest-cov on ubuntu-latest), both `continue-on-error: true`
- **Warn-only baseline** — coverage gaps don't gate PRs; data accumulates against which the v8.0 `GATE_TEST_MISSING` meta-gate (backlog T1) will calibrate per-module thresholds
- **Web c8 deliberately out of scope** — lives in the fitme-story repo per [dev-env-master-plan §3](../master-plan/dev-env-master-plan-2026-05-24.md)

Phase-E-safe (no enforcement gate; advisory metric only).

## What changed

**`Makefile`** — three new targets following the same skip-cleanly-if-absent pattern as the `lint-*` trio that shipped earlier today:

```make
coverage-ios:
  @if ! command -v slather >/dev/null 2>&1; then ...skip...; fi; \
   XCRESULT=$$(ls -1dt .build/coverage-derived/Logs/Test/*.xcresult 2>/dev/null | head -1); \
   if [ -z "$$XCRESULT" ]; then ...skip with hint...; fi; \
   slather coverage --simple-output --scheme FitTracker .

coverage-py:
  @if ! command -v pytest >/dev/null 2>&1; then ...skip...; fi; \
   if ! python3 -c "import pytest_cov" >/dev/null 2>&1; then ...skip...; fi; \
   cd ai-engine && pytest --cov --cov-report=term-missing --cov-report=xml:coverage.xml -q | tail -30

coverage-report: coverage-ios coverage-py
  @echo "=== Coverage summary ==="
  ...prints per-surface line-rate + branch-rate from coverage.xml...
```

All 3 added to `.PHONY`.

**`.github/workflows/coverage.yml`** — two independent jobs:

| Job | Runner | Step | Notes |
|---|---|---|---|
| `coverage-ios` | macos-15 | `gem install slather` → `xcodebuild test -enableCodeCoverage YES` → `make coverage-ios` | continue-on-error on the build + slather steps |
| `coverage-py` | ubuntu-latest | `pip install pytest pytest-cov` → `make coverage-py` → upload `coverage.xml` as artifact (14d retention) | continue-on-error on the test step |

Path filter limits the workflow to PRs touching iOS code / ai-engine code / Makefile / .slather.yml / the workflow itself.

**`.claude/features/r9-track-b-coverage-aggregator/state.json`** — feature contract with 6 tasks (T1-T6).

**`docs/master-plan/dev-env-master-plan-2026-05-24.md`** — R9 row updated from `[~] TRACK A SHIPPED` to `[x] Track A + Track B SHIPPED`.

## Why this design

**Why warn-only.** The v8.0 `GATE_TEST_MISSING` meta-gate (backlog T1) needs concrete calibration data — what's the baseline coverage today, which modules drift hardest, what's the typical PR delta? Gating coverage at v7.9.1 with arbitrary thresholds risks two failure modes: (a) thresholds set too high → PRs gated on legitimate refactors that temporarily drop coverage, (b) thresholds set too low → no signal value. The dev-env-plan explicitly defers gate calibration to "once a 30-day baseline exists" — this PR opens that window.

**Why skip-cleanly-if-absent in Makefile.** Mirrors the lint-* pattern. Developers without slather / pytest-cov installed locally should not see `make verify-local` fail. CI always has the tools; local devs get a "skipping (install via …)" notice and continue.

**Why two independent CI jobs.** A flaky iOS test should not block the Python coverage upload. Separate jobs + separate runners = independent failure modes. Matches the same posture as the [lint.yml workflow](.github/workflows/lint.yml) (3 independent lint jobs).

**Why no web c8.** Out of scope per [dev-env-master-plan §3](../master-plan/dev-env-master-plan-2026-05-24.md): "Web c8 ships via companion fitme-story PR." The FT2 side completes R9; fitme-story side ships separately.

## Verification

```bash
# Smoke-test 1: make coverage-py skips cleanly without pytest-cov
$ make coverage-py
coverage-py: pytest-cov not installed; skipping (install via 'pip install pytest-cov')

# Smoke-test 2: make coverage-ios skips cleanly without slather
$ make coverage-ios
coverage-ios: slather not installed; skipping (install via 'gem install slather')

# Smoke-test 3: workflow YAML parses
$ python3 -c "import yaml; yaml.safe_load(open('.github/workflows/coverage.yml'))"
(silent — YAML valid)
```

All 3 pass locally at commit time.

## Open follow-ups

- **2026-07-04 (T+30d)** — first opportunity to read 30 days of accumulated CI coverage data. The v8.0 `GATE_TEST_MISSING` meta-gate (backlog T1) calibration can begin once the run history is observable in the Actions UI.
- **fitme-story Web c8 companion** — separate PR in the fitme-story repo to ship the web-side coverage surface. Deferred to a fitme-story-focused session (per operator standing "FT2 only" directive for the current session).
- **Codecov / SonarCloud integration** — optional uplift if the operator wants a third-party coverage dashboard. The `coverage.xml` artifact upload already supports it; just add an `actions/upload-artifact@v4` → external upload step.

## References

- **Spec:** [`docs/master-plan/dev-env-master-plan-2026-05-24.md`](../master-plan/dev-env-master-plan-2026-05-24.md) §3 R9 Track B
- **Track A predecessor:** R9 Track A SHIPPED 2026-05-25 — `.slather.yml` + ai-engine `[tool.coverage.*]`
- **Sibling Track B ships today (2026-06-04):** [`framework-v7-9-promotion-case-study.md`](framework-v7-9-promotion-case-study.md) → F16 + F17 + F2 + Dev-env Track B (R7/R8/R12 lint trio) PRs #607-#619
- **Downstream consumer (calibration target):** `docs/product/backlog.md` v8.0 candidates → `GATE_TEST_MISSING` meta-gate T1
- **Out-of-scope (fitme-story):** Web c8 surface — separate PR, separate repo

---

**Shipped via PR #626** (`feature/r9-track-b-coverage-aggregator` → `main`).
