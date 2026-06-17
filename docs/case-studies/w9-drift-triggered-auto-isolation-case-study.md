---
slug: w9-drift-triggered-auto-isolation
title: "W9 Drift-Triggered Auto-Isolation — from reactive alert to proactive trigger"
date_written: 2026-06-06
framework_version: v7.9.1
work_type: Feature
work_subtype: framework_feature
case_study_type: shipped
tier_tags_present: true
status: shipped
case_study: docs/case-studies/w9-drift-triggered-auto-isolation-case-study.md
case_study_showcase: ""
related_prs:
  - 646
  - 648
  - 649
dispatch_pattern: serial
success_metrics:
  - name: manual_drift_recoveries_per_parallel_session_day
    baseline: 3
    target: 0
    significance: blocking
    review_at: 2026-06-13
    tier: T1
    note: "(T1) Baseline instrumented from this session's git reflog/history: 3+ manual branch-drift recoveries on 2026-06-05/06 (the #645 CI-fix commit landed on a sibling branch; HEAD flipped to main twice). Target 0 once the trigger is active. Reviewed at Phase 1 T+7d."
  - name: auto_isolation_false_trigger_rate
    baseline: null
    target: 0.10
    significance: high
    review_at: 2026-06-20
    tier: T2
    note: "(T2) Declared target: <=10% of w9.auto_isolate fires with no real drift/concurrency. Measured from gate-coverage.jsonl w9.auto_isolate rows once the advisory window accumulates data."
  - name: test_coverage
    baseline: 0
    target: 19
    significance: blocking
    review_at: 2026-06-06
    tier: T1
    note: "(T1) 19/19 unit tests pass (11 Phase 1 + 8 Phase 2), including the full happy-path isolation and no-data-loss assertions on every failure path. Verified locally + in CI on #648/#649."
kill_criteria: "KC1: drift incidents do not drop toward 0 in a 14-day window after the trigger ships (wrong axis -> revert to advisory). KC2: false-trigger rate >25% over the calibration window OR kill-switch used >=2x (narrow the predicate, hold advisory). KC3: any uncommitted-work loss during the stash->worktree->apply->verify->drop step (immediate revert; hard safety stop)."
kill_criteria_resolution: "Not yet triggered. Phase 1 ships advisory-first (acts only on CLAUDE_W9_AUTO_ISOLATE=1); Phase 2 ships advisory (acts only on CLAUDE_W9_AUTO_ISOLATE=1 AND CLAUDE_W9_CONCURRENCY_ENFORCE=1). KC3 (data loss) is structurally prevented and tested: the stash is never dropped until the worktree apply is digest-verified, and preconditions are validated before any tree mutation; the no-data-loss invariant is asserted on every failure path in the 19-test suite. KC1/KC2 are evaluated at the Phase 1 T+7d and Phase 2 T+14d calibration reviews (see calibration.md). Revert for any criterion is a single env/flag flip (<5 min)."
---

# W9 Drift-Triggered Auto-Isolation

## Problem

Branch isolation in the framework triggered on two signals only: **file path**
(`BRANCH_ISOLATION_VIOLATION` Mode B/C, enforced v7.9) and **reactive detection**
(W9 alert, which only *warned* after HEAD had already flipped). Neither was keyed
on **concurrency** or on **drift-as-a-trigger**, and **non-infra work**
(features/enhancements/tasks/chores) had no proactive isolation at all.

In the operator's dominant workflow — multiple concurrent Claude sessions sharing
one SSD checkout at `/Volumes/DevSSD/FitTracker2` — a sibling session's
`git checkout` flips the shared HEAD, so an unprotected session's commits land on
the wrong branch. **(T1)** This struck **3+ times on 2026-06-05/06** in a single
session: the #645 CI-fix commit landed on `feature/3d-universe-phase-4c-act1-threshold`;
HEAD flipped to `main` twice. Each recovery was manual (move the commit, restore
the sibling branch, restore HEAD).

## First-principles reframe

The load-bearing belief was *"isolation must be triggered by file-path risk."*
Its only support was convention (the gate was built path-first). The real
invariant is *"a session's commits must land on its intended branch"* — which is
violated by **concurrency**, independent of path. So the path-only trigger is the
wrong axis for a parallel-agent workflow. That validated reframing the trigger
around drift and concurrency.

## Solution (phased)

Operator picked a phased rollout at the Phase 0 gate, from a three-option
trade-off matrix (drift-reactive / concurrency-proactive / always-isolate):

- **Phase 1 — drift-reactive (#648).** When `check-branch-drift.py` detects HEAD
  flipped **and** the tree is dirty, it offers (default) or auto-dispatches
  (`CLAUDE_W9_AUTO_ISOLATE=1`) isolation of the work into the feature's own
  worktree via the new `scripts/w9_auto_isolate.py` primitive.
- **Phase 2 — concurrency-proactive (#649, ADVISORY).** A `PostToolUse:Edit|Write`
  hook checks `agent-leases.json` for another live session and surfaces a
  concurrency advisory before drift can occur — acting only behind a second
  opt-in (`CLAUDE_W9_CONCURRENCY_ENFORCE=1`).

**(T1)** The data-loss-safe primitive is the heart of it:
`stash -u → create/adopt worktree → stash apply → verify tree digest → drop stash`.
The stash is **never** dropped until the apply is digest-verified, preconditions
are validated before any mutation, and a lock prevents two isolations racing.
This is the KC3 hard-stop, asserted on every failure path in the test suite.

## Outcome

- **(T1)** 19/19 unit tests pass (11 Phase 1 + 8 Phase 2), incl. full happy-path
  isolation + no-data-loss on every failure path.
- Both PRs green through the full CI suite; existing W9 detect behavior
  regression-verified intact.
- **(T3)** The whole feature was built in an isolated worktree —
  dogfooding the very pattern — so the build session was itself drift-proof
  across ~10 phase transitions and 3 PRs (#646 docket, #648 Phase 1, #649 Phase 2).
- Ships advisory; Phase 1 promotes to default-act at T+7d, Phase 2 at T+14d via
  the v7.9-style 4-criteria calibration (`calibration.md`).

## Provenance

- Docket: PR #646 (`F-W9-DRIFT-TRIGGERED-AUTO-ISOLATION` in `v7-9-1-candidates.md`).
- Phase 1: PR #648 (drift-reactive, T1–T5,T12).
- Phase 2: PR #649 (concurrency-proactive advisory, T6–T10).
- Spec chain: `.claude/features/w9-drift-triggered-auto-isolation/` (research + prd
  + tasks + integration-spec + calibration).
- Observed-patterns: W9 entry extended with the auto-isolation upgrade (v7.8.5 rule).
