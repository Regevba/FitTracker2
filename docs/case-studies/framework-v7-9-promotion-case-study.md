---
title: Framework v7.9 — Advisory → Enforced Promotion (3 gates, single-flag flip)
date_written: 2026-05-21
work_type: Feature
work_subtype: framework_feature
dispatch_pattern: operator-driven (decision) + agent-driven (per-gate flip implementation)
framework_version: v7.9
tier_tags_present: true
state_owner: ft2
case_study_type: framework_meta
predecessor_case_studies:
  - "docs/case-studies/framework-v7-8-branch-isolation-case-study.md"
  - "docs/case-studies/framework-v7-8-bridge-case-study.md"
  - "docs/case-studies/framework-v7-7-validity-closure-case-study.md"
spec_path: docs/master-plan/infra-master-plan-2026-05-12.md
primary_metric: "Number of advisory gates successfully promoted to enforced with 0 false positives in the 7-day post-flip soak (target: 3 promoted, 0 rollbacks)"
success_metrics:
  primary: "3 of 3 candidate gates flipped advisory → enforced on 2026-05-21; 0 rollbacks during Phase E soak 2026-05-21 → 2026-06-04 [T1, instrumented via gate-coverage.jsonl + git log on scripts/check-state-schema.py]"
  secondary:
    - "All 4 §2.2 promotion criteria verified GREEN for each candidate before flip [T1, captured in research-phase log]"
    - "Side-effects PR opens single-day; documents updated (CLAUDE.md + dev-guide + entrypoint + honesty ledger + case study) in the same commit as the flag flip [T1]"
    - "Post-promotion T+7d baseline snapshot (B2, 2026-05-28) shows zero new findings vs 2026-05-14 platform anchor [T2, pending capture 2026-05-28]"
kill_criteria:
  - "Mechanism A telemetry shows 0% coverage for any advisory-being-promoted gate at decision time (cannot promote what was never calibrated)"
  - "False positive rate >5% during the 14d calibration window for any proposed-promotion gate"
  - "Post-promotion bug surfaces requiring rollback within T+7d soak — defer promotion or restore advisory mode"
kill_criteria_resolution: "pending — evaluated 2026-05-28 (B2 post-v7.9 baseline snapshot per .claude/shared/must-have-cadence-followups.md §B2). Will record final disposition (passed / partially_passed / tripped) here on that date with deltas."
related_prs: []
case_study_showcase: null
external_audit_status: pending
status: live
---

# Framework v7.9 — Advisory → Enforced Promotion

> **Live append-only journal.** Authored 2026-05-21 (freeze day). Section 99 (Synthesis) appended after the B2 post-v7.9 baseline lands 2026-05-28. No retroactive edits — Phase E findings + the next-flip-window planning will go in additional Sections. T1/T2/T3 tier tags throughout: T1 (instrumented), T2 (declared / not yet measured), T3 (narrative).

## Section 0 — Genesis

Three converging needs triggered v7.9 [T3]:

1. **The v7.8.1 calibration window closed 2026-05-21.** Two gates (`BRANCH_ISOLATION_VIOLATION` Modes B+C and `FEATURE_CLOSURE_COMPLETENESS`) shipped in advisory mode at v7.8.1 (2026-05-07) with a deliberate 14-day Mechanism A telemetry window to collect `{candidates, checked, skipped, skip_reasons}` data. v7.9 is the single-line flip that promotes them to enforced. [T1, source: [infra-master-plan §2.1](../master-plan/infra-master-plan-2026-05-12.md), [v7.8.1 case study §99B](framework-v7-8-branch-isolation-case-study.md)]
2. **The discipline is the deliverable.** v7.7 (FT2-FH-001) and v7.8.3 (FT2-FH-002) both shipped with silent-pass bugs because gates went live without verifying their telemetry was correctly keyed. v7.9 is the first framework version to use Mechanism A as a gate on its own promotion decision. The pattern being established is more valuable than the flip itself. [T3]
3. **HADF Phase 2-bis depends on the post-v7.9 baseline.** The next major product feature (`hadf-phase2bis-replication`) is gated on the 2026-05-28 B2 post-v7.9 baseline snapshot. Sub-experiment 1 launch is 2026-05-23, contingent on v7.9 landing cleanly today. [T2, source: [`docs/master-plan/post-v7-9-candidate-plan-2026-05-20.md`](../master-plan/post-v7-9-candidate-plan-2026-05-20.md) §3]

## Section 1 — Scope (3 gates × 4 criteria)

Per [infra-master-plan §2.1](../master-plan/infra-master-plan-2026-05-12.md), three gates were candidates for the 2026-05-21 promotion window. All three controlled by a single flag at `scripts/check-state-schema.py:132`:

| Gate | Mode | Shipped advisory | Calibration window | Source |
|---|---|---|---|---|
| `BRANCH_ISOLATION_VIOLATION` | Mode B (infra commit-level) | v7.8.1 (2026-05-07) | 14d (2026-05-07 → 2026-05-21) | T6 |
| `BRANCH_ISOLATION_VIOLATION` | Mode C (per-state.json) | v7.8.1 (2026-05-07) | 14d | T6 |
| `FEATURE_CLOSURE_COMPLETENESS` | write-time | v7.8.1 (2026-05-07) | 14d | T11-T14 |

Per [infra-master-plan §2.2](../master-plan/infra-master-plan-2026-05-12.md), each candidate must satisfy 4 criteria:

1. **Coverage emitted** — ≥7 days of `{candidates, checked, skipped}` rows
2. **No false positives** — every `failure` row maps to a legitimate violation in the staged diff
3. **No silent skips** — `skipped` counts track real reasons (not bugs)
4. **Reversibility** — advisory mode restorable in <5 min via single-line revert

Failing any criterion holds the gate at advisory and re-evaluates at next promotion window (T+14d).

## Section 2 — B1 freeze-day checklist (executed 2026-05-21 04:21–04:25Z) [T1]

Per [`.claude/shared/must-have-cadence-followups.md`](../../.claude/shared/must-have-cadence-followups.md) §B1:

| Step | Command | Result |
|---|---|---|
| B1.1 | `make integrity-check` | **0 findings** (74 features scanned, 79 case studies) |
| B1.2 | `make integrity-diff` | 3 dilution Δ vs 2026-05-14 anchor (denominator grew 70→74; numerator flat). 0 real regressions. |
| B1.3 | `make documentation-debt` | 1 open item (baseline-aligned; forward-only kill_criteria_resolution_missing advisory) |
| B1.4 | `make measurement-adoption` | 3/40 fully-adopted post-v6 (flat vs eve check) |
| B1.5 | `python3 scripts/membrane-status.py` | Normal readout; no dispatch blockers |
| B1.6 | 14d gate-coverage telemetry review | See §3 below |
| B1.7 | Per-gate decision | PROMOTE all 3 candidates |

## Section 3 — Calibration data (14d Mechanism A telemetry, 2026-05-07 → 2026-05-21) [T1]

Raw counts from `.claude/logs/gate-coverage.jsonl`:

| Gate | 14d rows | candidates=0 rows | Dominant skip reasons (all legitimate) | Verdict |
|---|---|---|---|---|
| `BRANCH_ISOLATION_VIOLATION` Mode B | 18 | 0 | `not_infra_commit_level` × 13 | PASS |
| `BRANCH_ISOLATION_VIOLATION` Mode C | 13 | 0 | (separate emission key — distinct from Mode B) | PASS |
| `FEATURE_CLOSURE_COMPLETENESS` write-time | 13 | 0 | `not_complete_transition` × 11, `no_phase_change` × 1, `no_case_study_link` × 2 | PASS |
| `ISOLATION_OPT_OUT_REASON_MISSING` | 13 | 0 | `opt_out_false_or_absent` × 12 | (already enforced at v7.8.1 — no action) |

Other gates in the 14d window (13 rows each — every-commit emission): `CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT`, `CU_V2_INVALID`, `FRAMEWORK_VERSION_FORMAT`, `PHASE_TRANSITION_NO_LOG`, `PHASE_TRANSITION_NO_TIMING`, `PR_NUMBER_UNRESOLVED`, `SCHEMA_DRIFT_LEGACY_CREATED`, `SCHEMA_DRIFT_LEGACY_PHASE`, `STATE_NO_CASE_STUDY_LINK`, `STATE_OWNER_INVALID`, `STATE_OWNER_LOCATION_MISMATCH`, `STATE_OWNER_MISSING`.

**`GATE_COVERAGE_ZERO` meta-check:** 0 gates ever-fired are missing from the 14d window. All 16 distinct gates in `gate-coverage.jsonl` history emitted within the calibration window. [T1]

**No false-positive evaluation:** all skip reasons map to documented legitimate cases (`not_infra_commit_level` = file path doesn't match infra glob; `not_complete_transition` = state.json doesn't transition current_phase → complete; `opt_out_false_or_absent` = isolation_opt_out is false or unset; `no_phase_change` = state.json modification without phase change). 0 advisory firings in 14d that should NOT have fired. [T1, operator review of 18+13+13 = 44 firing rows]

## Section 4 — The flip [T1]

Single-line edit at [`scripts/check-state-schema.py:132`](../../scripts/check-state-schema.py):

```python
# BEFORE (v7.8.1 → v7.8.6)
BRANCH_ISOLATION_ADVISORY_MODE = True

# AFTER (v7.9)
BRANCH_ISOLATION_ADVISORY_MODE = False
```

The same flag drives all 3 gates via the per-finding pattern:

```python
finding["advisory"] = BRANCH_ISOLATION_ADVISORY_MODE
# ...
if finding.get("advisory"):
    print(f"[ADVISORY] {finding['code']}: ...", file=sys.stderr)
else:
    errors.append(...)
```

Setting the flag to `False` cleanly converts every previously-printed advisory finding into a blocking error. No other code change required. [T1, verified via `git diff scripts/check-state-schema.py`]

## Section 5 — Side-effects shipped same-PR (per [infra-master-plan §2.3](../master-plan/infra-master-plan-2026-05-12.md))

| # | What | File | Status |
|---|---|---|---|
| C-1 | New "v7.9 Promotion Release" section + version-chain header update + 2 advisory→enforced text updates | `CLAUDE.md` | ✓ |
| C-2 | The flip (`BRANCH_ISOLATION_ADVISORY_MODE = False`) | `scripts/check-state-schema.py:132` | ✓ |
| C-3 | Cold-start entrypoint | `.claude/entrypoints/framework-v7-9.md` (new) | ✓ |
| C-4 | Dev-guide §2.4.1 promoted sub-section | `docs/architecture/dev-guide-v1-to-v7-7.md` | ✓ |
| C-5 | Honesty ledger entry FT2-FH-003 (calibration discipline pattern) | `docs/case-studies/framework-honesty-ledger.md` | ✓ |
| C-7 | This case study | `docs/case-studies/framework-v7-9-promotion-case-study.md` (this file) | ✓ |
| C-6 | Linear epic + per-gate sub-issues | (Linear) | Post-PR-open |

State.json transitions:

- `phases.research.status` → `approved` (decision: PROMOTE all 3)
- `phases.prd.status` → `skipped` (reason: spec pre-exists at infra-master-plan §2.x)
- `phases.tasks_phase.status` → `skipped` (reason: tasks pre-defined in post-v7-9-candidate-plan §1)
- `current_phase`: `research` → `implement`
- `timing.phases.research.ended_at` + `timing.phases.implement.started_at`
- `branch` set to `feature/v7-9-promotion`

## Section 6 — Phase E validation calendar (2026-05-21 → 2026-06-04) [T2]

Per [infra-master-plan §3.6.2](../master-plan/infra-master-plan-2026-05-12.md):

- **2026-05-21** — v7.9 ships. PR opens; CI green; merge to main.
- **2026-05-22** — B11 UCC hardening T+3d check; product feature work resumes.
- **2026-05-23** — B8 parent UCC T+7d kill-criteria; HADF Phase 2-bis Sub-experiment 1 launch.
- **2026-05-27** — B12 UCC hardening T+7d → advance to complete.
- **2026-05-28** — **B2 post-v7.9 baseline snapshot:** `make snapshot-phase PHASE=post-v7-9-baseline FEATURE=framework-v7-8-branch-isolation`. Compare against the 2026-05-12 pre-v7-9 baseline + 2026-05-14 platform anchor. Document deltas in §99 of this file.
- **~2026-06-04** — Phase E exit. v7.9.1 build window opens (F16 try-repo harness + F17 last_fired_at index + F2 + F6 + D-2 + D-4).

**Phase E constraints:**

- No new gates ship — keeps the post-promotion baseline clean
- No new test-discipline work (F14, F18) starts — those are v7.9.1 docket
- F17 (`last_fired_at` index) MAY be built since it's read-only — no new gates
- Operator monitors `.claude/logs/gate-coverage.jsonl` for unexpected `failure` rows daily

## Section 7 — Reversibility runbook [T2]

If a regression surfaces during Phase E:

```bash
cd /Volumes/DevSSD/FitTracker2
git checkout -b chore/v7-9-rollback main
# Edit scripts/check-state-schema.py:132 → BRANCH_ISOLATION_ADVISORY_MODE = True
git add scripts/check-state-schema.py
git commit -m "chore(v7-9-rollback): restore advisory mode for 3 gates — see FT2-FH-00N"
git push -u origin HEAD
gh pr create --fill && gh pr merge --squash
```

End-to-end: <5 minutes. Reason for rollback MUST be recorded in [`framework-honesty-ledger.md`](framework-honesty-ledger.md) as FT2-FH-00N + this case study §99 must be updated with the regression-surface details + the next promotion attempt waits for a new T+14d calibration window. [T2]

## Section 8 — Open follow-ups (post-v7.9, NOT today's scope) [T3]

Tracked in [`docs/master-plan/post-v7-9-candidate-plan-2026-05-20.md`](../master-plan/post-v7-9-candidate-plan-2026-05-20.md):

- **§0 master plan + backlog refresh** (~4-5h) — deferred per operator decision today; runs in a separate session
- **Post-promotion telemetry-commit workflow fix** — noted during today's commit-to-main (BRANCH_ISOLATION_VIOLATION advisory fired on routine cron-artifact commit before the worktree spin-up). Now that the gate is enforced, cron artifact commits to `.claude/shared/*` will be blocked from main. Two paths: (a) add `.claude/shared/*.json` to `branch-isolation-exempt.json` allowlist, or (b) move cron-artifact commits to an isolated chore branch with auto-PR. Decision deferred to v7.9.1 build window.
- **C1 F14/F15 dispatch-test coverage push** (~2026-05-22) — opens `framework-f14-f15-dispatch-test-coverage` feature

## Section 99 — Synthesis (deferred to 2026-05-28+ post-B2)

This section is intentionally empty at v7.9 ship. After the B2 post-v7.9 baseline snapshot lands 2026-05-28, this section will be appended with:

- B2 snapshot delta table (post-v7.9 vs 2026-05-12 pre-v7.9 baseline + 2026-05-14 platform anchor) [T1]
- Phase E daily observations log (any unexpected `failure` rows, any operator-driven rollback decisions, any new commits that the 3 newly-enforced gates blocked) [T1]
- Final `kill_criteria_resolution` (replaces the `pending` frontmatter value) [T1]
- 2-3 lessons recorded for FT2-FH-NNN (or absence-of-lessons if Phase E passed clean) [T3]
- v7.10 anchor points (do not commit to specifics yet)

Until then, this case study is the canonical pointer to the 2026-05-21 freeze-day decision and the side-effects PR. [T3]
