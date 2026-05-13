# Mode B Post-Fix Seed + Gate-Coverage Snapshot (2026-05-13)

## Purpose

This commit ships two artifacts that close a gap discovered 2026-05-13 morning while preparing the T7.9.0 v7.9 pre-promotion-decision review:

1. **`mode-b-post-fix-seed-2026-05-13.md`** (this file) — the seed file whose creation triggered a `BRANCH_ISOLATION_VIOLATION` Mode B advisory fire AFTER PR #317 (commit `6c52e92`, 2026-05-12T16:30Z) merged the silent-pass fix.
2. **`gate-coverage-snapshot-2026-05-13.jsonl`** — a snapshot of the local `.claude/logs/gate-coverage.jsonl` (which is .gitignored and not visible to remote agents). This snapshot is the FROZEN baseline that the scheduled T7.9.0 routine `trig_01HX8pmL2Z4FuZtHn7NbncSX` will read on 2026-05-18 to execute its 6 spot-check actions.

## Why both files are needed

Without the snapshot file, the scheduled remote agent on 2026-05-18 would do a fresh `git clone` of FitTracker2 and find that `.claude/logs/gate-coverage.jsonl` does not exist (it's in `.gitignore`). The agent has no way to compute "post-fix Mode B fire rate" or perform any of the 6 spot-check actions without committed telemetry to read.

The snapshot captures the local soak-window state at 2026-05-13T11:56Z:

- **Total entries:** 1,850 (was 1,845 at 2026-05-12 baseline)
- **First entry:** 2026-05-04T06:58:46Z (soak window start)
- **Last entry:** 2026-05-13T06:08:38Z `BRANCH_ISOLATION_VIOLATION` (Mode B post-#317-fix fire, captured during a prior commit attempt)
- **Soak span:** 9.0 days
- **Post-#317-fix Mode B fires:** 1 (the 2026-05-13T06:08:38Z entry — sufficient for Action 6 to verify gate logic emits correctly post-fix)

## Why this file's commit IS the seed

The act of creating + staging this file (path `.claude/shared/*`) on a non-feature branch (`chore/*`) satisfies both Mode B gate conditions:

- Staged file matches infra-path glob (`.claude/shared/*`)
- Branch is non-feature (`chore/seed-mode-b-and-snapshot-gate-coverage-2026-05-13`)

The pre-commit hook should emit a `BRANCH_ISOLATION_VIOLATION` entry to `.claude/logs/gate-coverage.jsonl` at the moment this commit is made. That entry confirms the v7.8 Mode B gate is firing correctly on infra-path commits as expected post-PR-#317.

## Why this matters for T7.9.0

The T7.9.0 routine prompt was originally written assuming the remote agent could read live `gate-coverage.jsonl`. The original assumption was wrong. The remediation:

- Commit a snapshot (this PR) — done
- Update the routine prompt to point at `.claude/shared/gate-coverage-snapshot-2026-05-13.jsonl` instead of `.claude/logs/gate-coverage.jsonl` — done via `RemoteTrigger update` after this commit lands

## Cleanup policy

Both files (this README + the snapshot) are intentional working artifacts for the 2026-05-18 review. After the v7.9 promotion decision lands 2026-05-21, both can be moved to `docs/case-studies/meta-analysis/` for archival, OR deleted if a more durable telemetry-snapshot mechanism replaces them (e.g., a generalized `make snapshot-gate-coverage` Makefile target as a candidate v7.9.1 feature).

## Related references

- **PR #317** (Mode B silent-pass fix): https://github.com/Regevba/FitTracker2/pull/317 (`6c52e92`)
- **T7.9.0 routine:** `trig_01HX8pmL2Z4FuZtHn7NbncSX` (fires 2026-05-18T06:00:00Z)
- **Baseline audit:** `.claude/shared/telemetry-audit-2026-05-12.md` (PR #324)
- **FIT-78** (T7.9.0 issue): https://linear.app/fitme-project/issue/FIT-78
- **FIT-79** (v7.9 Mode B promotion candidate): https://linear.app/fitme-project/issue/FIT-79

## Forward fix (v7.9.1 candidate)

The root cause — `.claude/logs/gate-coverage.jsonl` being .gitignored so it's invisible to remote agents — is a structural gap. A v7.9.1 candidate (`F-snapshot-gate-coverage`) could ship:

- A `make snapshot-gate-coverage DATE=<date>` Makefile target that mechanically copies the file to a tracked snapshot path
- A pre-commit hook that auto-creates the snapshot when remote agents are scheduled
- OR a decision to remove gate-coverage.jsonl from .gitignore and rely on Mechanism E's merge driver for conflict resolution (similar to the existing feature logs treatment)

Until that decision is made (likely in the 2026-05-21 v7.9 promotion meeting), this manual snapshot is the working solution.
