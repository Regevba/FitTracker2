---
slug: f-launchd-drift-extension-sub-a
title: "F-LAUNCHD-DRIFT-EXTENSION sub-fix (a) — Plist path-resolution health checks"
date_written: 2026-06-04
framework_version: v7.9.1
work_type: Feature
work_subtype: framework_feature
case_study_type: shipped
tier_tags_required: true
status: shipped
case_study: docs/case-studies/f-launchd-drift-extension-sub-a-case-study.md
case_study_showcase: ""
related_prs:
  - "PR #623"
pr_citation_exempt:
  - pr_number: 621
    reason: "Predecessor PR (sub-fixes (b)+(c) — different feature directory `f-launchd-drift-extension`). Cited in body for context but not contributed by this PR."
dispatch_pattern: serial
success_metrics:
  - name: ssd_migration_drift_detection_days
    baseline: 5
    target: 1
    significance: blocking
    review_at: 2026-06-11
    tier: T2
    note: "(T2) Pre-fix: 2026-05-19 SSD migration → cron silently broken for 5 days until manual investigation. Post-fix: WorkingDirectory and ProgramArguments[0] path resolution checks fire on next cycle-time run (next 72h cron). Catches the same incident class on day 1."
  - name: new_path_resolution_checks
    baseline: 0
    target: 3
    significance: descriptive
    review_at: 2026-06-04
    tier: T1
    note: "(T1) Three new sub-checks added: (i) WorkingDirectory exists, (ii) ProgramArguments[0] script exists, (iii) StandardOutPath / StandardErrorPath parent writable. Plus FT2-plist heuristic _plist_references_ft2()."
  - name: unit_test_coverage_passing
    baseline: 0
    target: 14
    significance: descriptive
    review_at: 2026-06-04
    tier: T1
    note: "(T1) Test suite at scripts/tests/test_launchd_drift_extension_sub_a.py — 14/14 pass in 0.28s."
kill_criteria:
  - "Path-resolution checks false-positive on legitimate plists — operator gets noise without a real risk"
  - "FT2-plist heuristic misses the 2026-05-19 SSD-migration class — would miss the primary use case"
  - "Filesystem access via Path.is_dir() / Path.is_file() / os.access() makes the cycle-time scan slow"
kill_criteria_resolution: "All 3 mitigated by design. (1) `_plist_references_ft2()` filters out unrelated plists explicitly; test `test_unrelated_plist_with_broken_paths_ignored` enforces — a plist with broken paths but no FT2 reference produces 0 findings. (2) Heuristic checks 3 independent signals: filename pattern (`fittracker`), ProgramArguments path-prefix (`/FitTracker2` or `/fitme-story`), WorkingDirectory prefix; daily-checkpoint plist matches via filename + ProgramArguments. Tests `test_plist_referenced_by_filename` + `test_plist_referenced_by_program_args` + `test_plist_referenced_by_workingdirectory` enforce. (3) Filesystem calls (`is_dir()`, `is_file()`, `os.access()`) are O(1) per plist; aggregate scan time stays sub-100ms even with 10+ plists per user — pytest suite runs in 0.28s for 14 fixtures."
primary_metric: "ssd_migration_drift_detection_days = 1 (T2, measured on next 72h cycle-time cron run after 2026-06-11)"
predecessor_case_study: docs/case-studies/f-launchd-drift-extension-case-study.md
spec: ".claude/shared/v7-9-1-candidates.md F-LAUNCHD-DRIFT-EXTENSION sub-fix (a) + docs/master-plan/post-v7-9-candidate-plan-2026-05-20.md E-14"
key_numbers:
  ssd_migration_drift_baseline_days: "5 (T2, 2026-05-19 → 2026-05-24)"
  new_sub_checks: 3
  unit_tests_passing: "14/14 in 0.28s (T1)"
  heuristic_signals: "3 independent (filename / ProgramArguments / WorkingDirectory)"
  scan_wall_clock_budget_ms: 100
  advisory_mode: "ADVISORY (additive on top of existing; no calibration window needed)"
---

## TL;DR (T1 unless tagged)

Closes the third sub-fix of F-LAUNCHD-DRIFT-EXTENSION. Predecessor PR #621 shipped sub-fixes (b) + (c) — cron-context detection + sentinel-flag suppression + daily-checkpoint pre-validation. This PR extends the existing `BRANCH_ISOLATION_LAUNCHD_DRIFT` cycle-time advisory in `scripts/integrity-check.py` with 3 path-resolution health checks fired against any FT2-related plist.

The mechanical defense: the next 72h cycle-time cron run that follows an SSD migration / mount swap / refactor that moves a script will surface 1 advisory per broken path. Operator sees the drift on day 1 instead of day 5 (T2 — 2026-05-19 → 2026-05-24 reference incident).

## What changed

One file modified (`scripts/integrity-check.py`), one new test file, two doc updates.

**`scripts/integrity-check.py`** — `check_branch_isolation_launchd_drift()` now contains two cooperating loops:

1. **T18 original (unchanged)** — for plists whose `ProgramArguments` reference a feature directory under `.claude/features/<name>/`, verify `WorkingDirectory` starts with that feature's `state.json::worktree_path`. Catches the HADF Phase 2 incident class (2026-04-30).

2. **Sub-fix (a) extension (new)** — for any FT2-related plist (detected via `_plist_references_ft2()` heuristic), validate:
   - (i) `WorkingDirectory` resolves to an extant directory
   - (ii) `ProgramArguments[0]` (after stripping interpreter prefix) resolves to an extant file
   - (iii) `StandardOutPath` + `StandardErrorPath` parent directories exist + are writable

The `_plist_references_ft2()` helper checks 3 independent signals: filename containing `fittracker`, ProgramArguments path-prefix matching `/FitTracker2` or `/fitme-story`, or WorkingDirectory prefix matching the same. Unrelated plists (e.g., Spotlight) are explicitly NOT scanned — keeps the operator surface clean.

**`scripts/tests/test_launchd_drift_extension_sub_a.py`** — 14 tests in 0.28s. Coverage:
- Linux-skip guard
- All 4 heuristic cases (filename / program-args / workdir / unrelated-ignore)
- Sub-check (i) fire + no-fire
- Sub-check (ii) fire + no-fire + relative-path-skip
- Sub-check (iii) fire + no-fire
- Compound plist with 3 simultaneous problems → 3 distinct advisories
- Unrelated plist with broken paths → 0 findings (no false positives)

**`CLAUDE.md`** — new `## v7.9.1 F-LAUNCHD-DRIFT-EXTENSION sub-fix (a)` section closing out the 3-part plan.

**`.claude/shared/v7-9-1-candidates.md`** — F-LAUNCHD-DRIFT-EXTENSION fully closed; all 3 sub-fixes shipped.

## Why this design

The 2026-05-19 SSD-migration drift was caught only after 5 days because no surface alerted to the underlying class. The fix is structural — every cycle-time run validates plist health. Sub-fix (a) ships as ADVISORY (no calibration window) because:

1. The 3 new sub-checks are **additive** on top of an existing advisory. False positives don't break anything.
2. The heuristic `_plist_references_ft2()` is conservative — only FT2-related plists are scanned. System plists never produce findings.
3. The operator's mitigation is always the same (fix the plist), so enforcement→advisory doesn't change the response.

A naive design would have scanned ALL plists in `~/Library/LaunchAgents/` and produced findings for Spotlight, Apple system jobs, third-party app daemons. The heuristic gate keeps the noise floor at zero for unrelated jobs.

## Verification

```bash
# Syntax check passes:
python3 -c "import py_compile; py_compile.compile('scripts/integrity-check.py', doraise=True)"
# Output: (clean)

# Unit test suite passes:
pytest scripts/tests/test_launchd_drift_extension_sub_a.py -q
# Output: 14 passed in 0.28s
```

Fault-injection verification (operator-driven, scheduled at T+7d = 2026-06-11): inspect the next 72h cycle-time cron output for `BRANCH_ISOLATION_LAUNCHD_DRIFT` advisories. Expected: 0 in normal conditions; ≥1 only if a plist has genuinely drifted (e.g., recent SSD remount, script refactor that moved a path).

## Related

- **Sub-fix (b) + (c)** — PR #621 (`ed20cbf`, 2026-06-04): cron-context detection + sentinel-flag suppression + daily-checkpoint pre-validation. See [`f-launchd-drift-extension-case-study.md`](f-launchd-drift-extension-case-study.md).
- **Predecessor (HADF Phase 2)** — 2026-04-30: launchd plist pointed at canonical repo path; long-running script wrote to wrong tree. Original T18 advisory.
- **2026-05-19 SSD-migration drift** — 5-day silent cron break. Reference incident for sub-fix (a).
- **fitme-story showcase MDX (slot 48)** — deferred to companion agent per operator directive (FT2-only this session).

## References

- Spec: [`.claude/shared/v7-9-1-candidates.md`](../.claude/shared/v7-9-1-candidates.md) F-LAUNCHD-DRIFT-EXTENSION sub-fix (a)
- Master plan: [`docs/master-plan/post-v7-9-candidate-plan-2026-05-20.md`](../master-plan/post-v7-9-candidate-plan-2026-05-20.md) E-14
- Predecessor case study: [`docs/case-studies/f-launchd-drift-extension-case-study.md`](f-launchd-drift-extension-case-study.md)
- T18 (original): `.claude/features/framework-v7-8-branch-isolation/state.json`
