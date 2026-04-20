# Integrity Cycle — 72-Hour Recurring Audit

> Automated ledger of the feature state.json truth over time.
> Catches the "shipped but state.json never reconciled" pattern that we've seen across HADF, home-today-screen, nutrition-v2, and 5+ others.

---

## What it does

Every 72 hours, a GitHub Actions workflow runs `scripts/integrity-check.py` against the repo and:

1. **Audits** every `.claude/features/*/state.json` for known lies:
   - `PHASE_LIE` — top-level terminal phase (complete/completed/closed/etc) but sub-phases are still `pending` / `in_progress`
   - `TASK_LIE` — top-level terminal but tasks still `pending` / `in_progress` / `open` / `blocked`
   - `NO_CS_LINK` — terminal phase but no `case_study`, `parent_case_study`, or `case_study_type` linkage
   - `V2_FILE_MISSING` — state declares a `v2_file_path` that doesn't exist on disk
   - `PARTIAL_SHIP_TERMINAL` — `partial_ship: true` alongside a terminal phase (should be downgraded)
   - `NO_STATE` / `INVALID_JSON` — critical structural failures
   - `NO_PHASE` — missing phase field entirely

2. **Inventories** every case study under `docs/case-studies/` — path, size, first-commit date.

3. **Produces a snapshot JSON** at `.claude/integrity/snapshots/<timestamp>.json` with the full feature + case-study inventory and all findings.

4. **Diffs** the new snapshot against the most recent prior one:
   - Features added, removed, or with phase/case-study/state-hash changes
   - Case studies added or removed
   - Findings newly introduced vs resolved since last cycle

5. **Commits** the new snapshot to `main` (the directory is a historical ledger — each cycle adds one file, nothing is deleted).

6. **Opens an issue** (labels: `integrity-cycle`, `regression`) if the cycle detects:
   - A feature present in the previous snapshot but absent now
   - A case study present before but absent now
   - A NEW finding introduced since the prior cycle

---

## Running on demand

```bash
# Findings-only — prints audit, no file writes
python3 scripts/integrity-check.py --findings-only

# Write a snapshot + compare to the previous one
python3 scripts/integrity-check.py \
  --snapshot .claude/integrity/snapshots/$(date -u +%Y-%m-%dT%H-%M-%SZ).json \
  --compare-to "$(ls -1 .claude/integrity/snapshots/*.json | tail -1)"

# Strict mode — exit 1 on any findings at all (not just regressions)
python3 scripts/integrity-check.py --findings-only --strict
```

Or via the Makefile:

```bash
make integrity-check       # findings-only, non-strict
make integrity-snapshot    # full snapshot + diff + commit (locally)
```

---

## Why 72 hours

Fast enough to catch reconciliation drift within a development week; slow enough to not spam the repo with cosmetic-only snapshots. The cycle can be manually triggered via the workflow's `workflow_dispatch` button.

Empirical case for the cadence: the 2026-04-20 audit found **7 features that had been "shipped but unreconciled" for 3–14 days**. A 72-hour cycle would have flagged most of them the morning after they shipped — not weeks later.

---

## Snapshot schema

Each snapshot is a JSON file with:

```json
{
  "timestamp": "2026-04-20T20-00-00Z",
  "commit_head": "abc1234...",
  "feature_count": 40,
  "case_study_count": 48,
  "finding_count": 3,
  "findings_by_severity": { "CRITICAL": 0, "INCONSISTENT": 2, "MISSING": 1, "WARN": 0 },
  "features": [
    {
      "name": "home-today-screen",
      "phase": "complete",
      "case_study": "docs/case-studies/home-today-screen-v2-case-study.md",
      "case_study_type": null,
      "task_total": 17,
      "task_completed": 17,
      "state_hash": "5f3a...6b2d"
    },
    ...
  ],
  "case_studies": [
    {
      "path": "docs/case-studies/home-today-screen-v2-case-study.md",
      "size_bytes": 12345,
      "first_commit_date": "2026-04-20"
    },
    ...
  ],
  "findings": [
    {
      "feature": "example-feature",
      "severity": "INCONSISTENT",
      "code": "TASK_LIE",
      "message": "top-level complete but 3 tasks not done: T1,T4,T8"
    },
    ...
  ]
}
```

The `state_hash` field is a truncated SHA-256 of the state.json content — detects any change (even whitespace) without requiring a full JSON diff.

---

## Expected false-positives

1. **Pre-PM-workflow backfill features** use legacy phase vocabulary (`pre-pm-workflow`, `backfilled`, `shipped`) that isn't in the post-2026-04-06 schema. These are bypassed via `case_study_type: "pre_pm_workflow_backfill"` — the audit skips phase-lie and no-cs-link checks for them.

2. **Roundup-classified features** bypass the no-cs-link check via `case_study_type: "roundup"` (pointing at a shared roundup case study).

3. **Features with `partial_ship: true`** are flagged via `PARTIAL_SHIP_TERMINAL` if they ALSO have a terminal phase — the policy is either "downgrade phase from complete" or "remove the partial_ship flag", pick one.

---

## Cycle history

The snapshots directory is the ledger. `ls -1 snapshots/ | sort` gives the chronological sequence. Each file is self-contained and readable.

To see the most recent cycle's findings:

```bash
jq '.findings' .claude/integrity/snapshots/$(ls -1 .claude/integrity/snapshots/*.json | tail -1)
```

To see what changed between the last two cycles:

```bash
python3 scripts/integrity-check.py \
  --snapshot /tmp/scratch.json \
  --compare-to "$(ls -1 .claude/integrity/snapshots/*.json | tail -1)"
```

(The `--snapshot` arg is only used as a scratch target; real diff is printed to stdout.)

---

## Related docs

- [`scripts/integrity-check.py`](../../scripts/integrity-check.py) — the audit script
- [`.github/workflows/integrity-cycle.yml`](../../.github/workflows/integrity-cycle.yml) — cron trigger
- [`CLAUDE.md` § Integrity Cycle](../../CLAUDE.md#integrity-cycle) — project-level reference
