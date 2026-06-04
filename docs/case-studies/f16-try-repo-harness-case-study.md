---
slug: f16-try-repo-harness
title: "F16 try-repo pre-commit harness — the 3rd gate-test layer"
date_written: 2026-06-04
framework_version: v7.9.1
work_type: Feature
work_subtype: framework_feature
case_study_type: shipped
tier_tags_required: true
status: shipped
case_study: docs/case-studies/f16-try-repo-harness-case-study.md
case_study_showcase: fitme-story/content/04-case-studies/44-f16-try-repo-harness.mdx
related_prs:
  - 606  # F6 docs + T14 stub + FIT-71 drift (predecessor)
  - 607  # Phase 0 + 1 + 2 scoping (Research + PRD + Tasks)
  - 608  # T2 + T3 (baseline + builder + harness scaffold)
  - 610  # T4a fixtures + Q6 finding
  - 611  # REPO_ROOT_OVERRIDE fix
  - 612  # T4a unblock + T4b + T4c + T4d + T6 + T7 + T8-T10
dispatch_pattern: serial
success_metrics:
  - name: try_repo_test_coverage_pct_of_write_time_gates
    baseline: 0
    target: 100
    significance: descriptive
    review_at: 2026-06-04
    tier: T1
    note: "15 of 16 write-time gates covered end-to-end via subprocess pre-commit invocation. 1 documented skip (STATE_OWNER_LOCATION_MISMATCH — path-neutral throwaway repo). 93.75% real, 100% if you count the documented skip as 'covered by deferral'."
  - name: try_repo_harness_wall_clock_seconds
    baseline: 60
    target: 60
    significance: descriptive
    review_at: 2026-06-04
    tier: T1
    note: "PRD §4 budget <60s. Empirical: 15.36s for 59 tests + 1 skip. Well under budget."
  - name: try_repo_false_positive_rate_pct
    baseline: 0
    target: 5
    significance: descriptive
    review_at: 2026-06-25
    tier: T1
    note: "T+14d soak window. Calibration starts at v7.9.1 ship."
  - name: regressions_caught_that_f14_missed
    baseline: 0
    target: 1
    significance: descriptive
    review_at: 2026-09-04
    tier: T1
    note: "Already met by construction during T4 development — Q5 (GATE_COVERAGE_LEDGER as module constant) and Q6 (REPO_ROOT hardcoded) were caught BY F16's own tests on first end-to-end run. T7 deliberate-regression test (scripts/tests/test_try_repo_regression_proof.py) is the permanent proof artifact."
kill_criteria:
  - condition: "Harness wall-clock >5 min in CI on 3 consecutive runs → operators will skip locally; defer to F16.1 with sharding"
  - condition: "False-positive rate >5% during the 14-day advisory calibration window"
  - condition: "Maintenance burden >2h per new gate's fixture pair → discipline becomes a barrier; relax to '≥1 of (try-repo, dispatch) test required' instead of mandatory try-repo"
kill_criterion_fired: false
kill_criteria_resolution: pending_t14_eval_2026-06-18 — T+14d soak window for false-positive evaluation closes 2026-06-18. K1 (wall-clock) and K3 (maintenance) are continuous-monitoring criteria with no fire to date at ship time. K2 (false-positive rate) requires 14 days of CI runs to evaluate.
pr_citation_exempt:
  - "PR #606 (F6 docs + T14 stub — predecessor that shipped on same day; cited for chain-of-custody, not as the F16 implementation PR)"
  - "PR #317 (F14 monkey-patch pattern reference — predecessor case study chain; not part of F16 implementation)"
  - "PR #607 (Phase 0 + 1 + 2 scoping — F16 sub-PR cited in body; state.json tracks via top-level related_prs not per-phase pr_number)"
  - "PR #608 (T2 + T3 baseline + harness scaffold — same exemption rationale as #607)"
  - "PR #610 (T4a fixtures + Q6 finding — same exemption rationale)"
  - "PR #611 (REPO_ROOT_OVERRIDE fix — same exemption rationale)"
  - "PR #612 (this PR — T6 + T7 + T8-T10 closure; merge_pr_number will populate phases.merge.pr_number when this PR merges)"
---

# F16 Try-repo Pre-commit Harness — Case Study

> **Status:** Shipped 2026-06-04 via PR #612 (Phase 4 completion).
> **Framework version:** v7.9.1 (first substantive v7.9.1 work post-Phase-E).
> **Showcase:** `fitme-story/content/04-case-studies/44-f16-try-repo-harness.mdx`.

## TL;DR

The framework gained a **3rd layer of gate testing**: try-repo. Where unit tests catch wrong-regex bugs and F14 dispatch tests catch wrong-main()-flow bugs, F16 catches the **integration-surface** bugs neither could see — wrong shell-fork behavior, env-var inheritance issues, real `git status` interaction edge cases, HOME pollution. Coverage at ship: 15 of 16 write-time gates exercised end-to-end. Empirical wall-clock: 15.36s for 59 tests + 1 documented skip. The deliberate-regression test (T7) PROVES the value claim by construction.

## Problem

By v7.8.x, the framework had two layers of gate testing:

| Layer | What it tests | Catches | Architectural blind spot |
|---|---|---|---|
| **Unit** | Individual gate function inputs → outputs | Wrong field-name logic, wrong regex | Hook composition, shell-fork, env-var inheritance, real-filesystem state |
| **Dispatch (F14, PR #317)** | `main()` end-to-end via `monkeypatch.setattr(_mod, ...)` | Wrong gate registration, wrong skip semantics, wrong Mechanism A row emission | The `.githooks/pre-commit` Bash script itself — its env-var passing, its exit-code handling, its interaction with real `git status --porcelain` |

The blind spot was structural: F14's monkey-patches replace the IO helpers (`collect_staged_state_files` etc.) with synthetic returns. They never exercise the **real shell hook → Python subprocess → git subprocess** chain. A class of bugs lived in that chain unseen.

T1 [T1, infra-master-plan §3.4 Theme G note]: external research synthesis labeled F16 "highest-leverage single change" pre-build.

## Approach

Three locking decisions in Phase 1 PRD (PR #607):

1. **Subprocess invocation, not in-process.** The whole point is to test the shell script. In-process invocation defeats it. Cost: ~50-100ms per test. Budget OK for 32 fixtures.
2. **Hybrid fixture format.** Canonical baseline `tests/fixtures/_baseline/state.json` (one file) + per-gate partial-record JSON overrides. Schema additions update the baseline only; fixtures don't re-touch.
3. **`pytest tmp_path` for cleanup.** Function-scope fixtures auto-clean; no special discipline needed.

Two more constants pivoted DURING T4 development:

- **Q5 (locked during T3):** the PRD originally specified a `GATE_COVERAGE_LEDGER` env-var path-override. The Q5 enforcement test caught reality: gates use it as a module-level constant. F14 monkey-patch works in-process but not across subprocess. Real opt-out is `GATE_COVERAGE_LEDGER_DISABLED=1`. Tests rely on stderr + exit code, which is strictly stronger evidence anyway.
- **Q6 (discovered during T4a):** `scripts/check-state-schema.py:58` hardcoded `REPO_ROOT = Path(__file__).resolve().parent.parent`. Combined with `p = REPO_ROOT / line; if p.exists()`, this silently dropped throwaway-repo state.json files. Fixed via PR #611 — `REPO_ROOT_OVERRIDE` env-var support in both gate dispatchers.

Both pivots were caught BY THE HARNESS, not by review. The 2nd one was caught on its **first end-to-end run with real fixtures**. F16's value claim was empirically validated before shipping.

## Decisions log

- **Test file naming:** single file per bucket (`test_try_repo_schema_gates.py`, `_closure_gates.py`, `_telemetry_gates.py`, `_isolation_gates.py`) with `pytest.mark.parametrize` over the gate set. Alternative (one file per gate) would have created 16 small files; rejected for proliferation.
- **STATE_OWNER_LOCATION_MISMATCH:** the gate skips with `path_neutral` when the staged file path is not under `/FitTracker2[-/]` or `/fitme-story/`. The throwaway repo lives at `/private/tmp/pytest-of-*/` which matches neither. Testing this gate via the try-repo harness would require bind-mount or symlink hacks. **Documented skip with placeholder fixtures + reason; deferred to F16.1.** Cost-benefit: 1 gate vs significant harness complexity. Accept the skip.
- **`_write_fresh_baseline_log` dynamic generation:** `PHASE_TRANSITION_NO_LOG` requires a log event ≤15 minutes old. Static fixtures cannot satisfy this. The harness generates the log at stage-time using the current process clock, pointed at the merged state's `current_phase`. Test-only construction — production logs are written by `append-feature-log.py`.
- **Fixture `_comment` keys stripped before merge:** fixtures use `_comment` keys to document themselves. The gate dispatchers never see them. `stage_fixture` strips all keys starting with `_comment` recursively.

## Outcomes

| Dimension | Value |
|---|---|
| Test files added | 6 (`_try_repo_fixtures.py`, `_try_repo_harness.py`, `test_try_repo_baseline.py`, `test_try_repo_harness.py`, `test_try_repo_*_gates.py` × 4, `test_try_repo_regression_proof.py`) |
| Test count | 59 pass + 1 documented skip |
| Wall-clock budget | 15.36s (PRD budget <60s) — well under |
| Fixture pairs | 16 (15 active + 1 placeholder for the documented skip) |
| Gates covered end-to-end | 15 of 16 write-time gates (93.75%) |
| Real bugs caught during development | 2 (Q5 + Q6) — fixed via PRs #611 + the implementation flow |
| Lines of code added | ~1,720 across all 6 PRs |
| CI integration | New `try-repo-harness` job in `.github/workflows/pr-integrity-check.yml` |
| Discipline encoded | CLAUDE.md "v7.9.1 F16 — Try-repo Pre-commit Harness" section requires fixture+test pair for every new gate |

## T1 / T2 / T3 tiering

Every quantitative metric in this case study is tagged at its claim site. The 59-test count, 15.36s wall-clock, and 2-bugs-caught-during-development are all T1 (instrumented via pytest output + git log). The 100% coverage target is T1 against the gate set (15/16 real + 1 documented). The T+14d false-positive rate is T1-pending (CI runs accumulate).

## Phase E discipline note

F16 was the first substantive work after Phase E exit (2026-06-04). The v7.9 promotion HELD across the 14-day soak; v7.9.1 build window opened. F16 ships in this window, consuming Phase E infrastructure (`make integrity-check`, gate-coverage telemetry, FEATURE_CLOSURE_COMPLETENESS enforcement, BRANCH_ISOLATION enforcement). The harness extension for Mode B testing (`make_throwaway_repo(initial_branch="main")`) exercises the very gates F16 itself triggers when run on a feature branch.

## Cross-references

- **Phase 0 Research:** [`.claude/features/f16-try-repo-harness/research.md`](../../.claude/features/f16-try-repo-harness/research.md) — merged in PR #607
- **Phase 1 PRD:** [`.claude/features/f16-try-repo-harness/prd.md`](../../.claude/features/f16-try-repo-harness/prd.md) — merged in PR #607
- **Phase 2 Tasks:** [`.claude/features/f16-try-repo-harness/tasks.md`](../../.claude/features/f16-try-repo-harness/tasks.md) — merged in PR #607
- **REPO_ROOT_OVERRIDE fix:** PR #611 — fix-tier that unblocked Q6
- **CLAUDE.md discipline:** [`CLAUDE.md`](../../CLAUDE.md) "v7.9.1 F16 — Try-repo Pre-commit Harness" section
- **Dev-guide timeline:** [`docs/architecture/dev-guide-v1-to-v7-7.md`](../architecture/dev-guide-v1-to-v7-7.md) §12 v7.9.1 row
- **Predecessor F14:** [`docs/case-studies/framework-f14-f15-dispatch-test-coverage-case-study.md`](framework-f14-f15-dispatch-test-coverage-case-study.md) (shipped 2026-05-23)
- **Linear:** FIT-88 (F16 epic)
- **Backlog row:** none — F16 was directly in the v7.9.1 docket (`.claude/shared/v7-9-1-candidates.md`) rather than the RICE backlog
- **Tier 2.2 log:** [`.claude/logs/f16-try-repo-harness.log.json`](../../.claude/logs/f16-try-repo-harness.log.json) (8 phase_transition + implementation events)
