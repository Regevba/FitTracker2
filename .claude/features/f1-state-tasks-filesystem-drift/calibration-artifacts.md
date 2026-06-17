# F1 — STATE_TASKS_FILESYSTEM_DRIFT — Phase A Calibration Artifacts

> Authored BEFORE code per infra-master-plan §3.5 Calibration Protocol.
> Cycle-time advisory → uses the unit + dispatch test layers (no try-repo
> fixture pair; that discipline applies to write-time gates only).

## 1. Identity

| Field | Value |
|---|---|
| Gate code | `STATE_TASKS_FILESYSTEM_DRIFT` |
| Mechanism A emission key | `STATE_TASKS_FILESYSTEM_DRIFT` |
| Function | `check_state_tasks_filesystem_drift(coverage=None)` |
| Location | `scripts/integrity-check.py` |
| Dispatch site | `build_snapshot()` → `advisory_findings` tuple, `coverage=cycle_coverage` |
| Severity | ADVISORY (never affects `finding_count` or exit code) |
| Coverage mode | `cycle` |
| RICE / Theme | 19.2 / Theme A (roadmap realism) |

## 2. What it detects

The task ledger (`state.json::tasks[]`) drifting from the work that
actually shipped. Empirically surfaced when 5-of-10 roadmap-stress-test
sub-features were `complete` with an empty `tasks[]` despite shipped work
(the post-squash-merge drift class F2 catches at Phase 0; F1 is the
standing cycle-time mirror).

## 3. Candidate domain

Every feature with `current_phase == "complete"` **and** an empty or
missing `tasks[]`. (Features with a populated ledger are not candidates.)

## 4. Fire predicate

A candidate fires (ADVISORY finding) iff ALL hold:

1. **Post-task-discipline** — `created_at[:10] >= "2026-04-25"` (v7.6 ship,
   when task-ledger discipline began).
2. **Not framework-meta** — see exemptions below.
3. **Shipped artifact present** — at least one of: a case study at
   `docs/case-studies/<feature>-case-study.md`; non-empty `related_prs`;
   or `phases.merge.pr_number`. This is the "filesystem" half of the name:
   the filesystem shows shipped artifacts but the ledger is empty.

## 5. Skip reasons (legitimate — tracked, not bugs)

| Reason | Meaning |
|---|---|
| `pre_task_discipline` | `created_at < 2026-04-25` — predates task discipline; bounded backfill-debt, not active drift. (~30 features at ship.) |
| `exempt_framework_meta` | name starts with `framework-v`, OR `work_type == "framework"`, OR `work_subtype` starts with `framework`, OR `case_study_type` ∈ {pre_pm_workflow_backfill, roundup, no_case_study_required, framework_meta_retroactive}, OR `platforms_tested_provenance` starts with `exempt:`. These ship no task-decomposable product work. (~5 at ship.) |
| `no_shipped_artifact` | complete + empty tasks but no case study / related_prs / merge PR → not "drift despite shipped work." (~1 at ship.) |

Graceful degradation: missing `FEATURES_DIR`, unreadable/invalid JSON →
skip silently (no finding, no crash), consistent with sibling cycle checks.

## 6. Expected baseline at ship (snapshot — 2026-06-17)

5 fires: `case-study-presentation`, `ios-ui-audit-p1-burndown`,
`trend-alerts-hrv`, `fitme-story-design-system-p2-cleanup`,
`smart-reminders-behavioral-learning`.
Skips: `pre_task_discipline` ×30, `exempt_framework_meta` ×5,
`no_shipped_artifact` ×1.

## 7. Calibration walk

- **Phase A** — this doc (pre-code). ✓
- **Phase B** — advisory + measure ≥7d Mechanism A coverage.
- **Phase C** — calibration review ~2026-07-01 → -08; confirm 0 false positives.
- **Posture** — advisory-permanent by default (a backlog-surfacing advisory,
  like `TIER_TAG_LIKELY_INCORRECT`). Promotion to enforced is NOT the goal;
  this surfaces task-ledger debt for backfill, it does not block commits.

## 8. Reversibility

Single-line removal from the `advisory_findings` tuple in `build_snapshot()`
(< 2 min). The function is pure/read-only; no schema or data migration.
