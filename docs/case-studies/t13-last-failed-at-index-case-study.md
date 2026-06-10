---
title: "T13 — Per-gate last_failed_at index (distinguishing 'stopped running' from 'running + catching')"
slug: t13-last-failed-at-index
date_written: 2026-06-10
date: 2026-06-10
work_type: Feature
work_subtype: framework_feature
dispatch_pattern: "operator-driven (T13 from the test-coverage master plan; extends F17)"
framework_version: v7.10
state_owner: ft2
case_study_type: feature
primary_metric: "Per-gate last_failed_at materialized in the F17 index from the integrity-snapshot history, so the meta-layer distinguishes 'gate stopped running' (no coverage) from 'gate running + catching violations' (recent failures)."
success_metrics:
  primary: "gate-last-fired.json schema v2 carries last_failed_at / total_failure_snapshots / last_failure_severity per gate (6 cycle-time gates populated from 14 snapshots); the v7.10 mis-wire detector refined to not flag gates with failure history."
  secondary:
    - "F17 producer stays hermetic in tests (snapshots dir derived from the ledger path, not a module-global)"
    - "Write-time block limitation documented (failure_history_note in the index)"
kill_criteria:
  - "last_failed_at conflated with last_fired_at (a gate that ran but never failed shows a stale last_failed) — would mislead the meta-check."
  - "Snapshot scan slows the index refresh beyond the <1s budget."
kill_criteria_resolution: "Neither fired. last_failed_at is strictly the most-recent snapshot timestamp where the gate code appeared in findings[] (a real violation), distinct from last_fired_at (checked>=1 in coverage). Refresh stays <1s (14 snapshots, ~3.2k coverage rows). The index extension also refined the v7.10 GATE_COVERAGE_ZERO mis-wire detector — a 0-candidate gate WITH failure history is a cycle-time code (running, not mis-wired) — which cleared 4 false advisories the extension would otherwise have produced."
tier_tags_present: true
related_prs: []
---

# T13 — Per-gate `last_failed_at` Index

> **Status:** shipped 2026-06-10. Extends F17 (the `last_fired_at` materialized index) with failure history, completing the meta-layer's ability to reason about each gate's *health*.

## 1. The gap F17 left

F17 (v7.9.1) materialized `last_fired_at` per gate from the append-only `gate-coverage.jsonl` stream — answering "when did this gate last *run*?" in O(1). The v7.10 `GATE_COVERAGE_ZERO` meta-check uses it to flag gates that went silent. But "ran" and "caught something" are different signals, and F17 only had the first. A gate could be firing every cycle and never catching a violation (healthy, or possibly toothless) — F17 couldn't tell.

## 2. The scoping surprise: coverage rows have no failure signal

The obvious move — derive `last_failed_at` from `gate-coverage.jsonl` — doesn't work: coverage rows track `{candidates, checked, skipped}` (did the gate *run*), **not** pass/fail. A gate "failing" means it emitted a *finding*, and findings aren't in the coverage stream.

The clean source turned out to be the **integrity-snapshot history** (`.claude/integrity/snapshots/<ts>.json`): each snapshot carries a `timestamp` + a `findings[]` array of `{code, severity}`. Scanning them gives, per gate code, the most recent snapshot where it appeared.

## 3. What shipped

`refresh-gate-last-fired.py` (schema v1 → **v2**) now overlays, per gate:
- **`last_failed_at`** — most recent snapshot timestamp where the gate code appeared in `findings[]`;
- **`total_failure_snapshots`** — count of distinct snapshots it appeared in (deduped within a snapshot);
- **`last_failure_severity`** — the severity in the most-recent failing snapshot.

Gates that appear *only* in failure history (a cycle-time code with no coverage row) get a minimal index entry, so the index is complete. The snapshots dir is derived **relative to the ledger path** so a tmp-dir ledger in tests resolves to an empty dir (hermetic) while production resolves the real one.

**Live:** 6 cycle-time codes populated from 14 snapshots (`BROKEN_PR_CITATION` last failed 2026-06-04, `TIER_TAG_LIKELY_INCORRECT` 2026-06-07 across 7 snapshots, etc.). Refresh stays well under the <1s budget.

## 4. The interaction that became a refinement

Adding failure-only codes to the index made the **v7.10 GATE_COVERAGE_ZERO mis-wire detector false-fire** on 4 cycle-time codes (`BRANCH_ISOLATION_HISTORICAL`, `CACHE_HITS_AUTO_INSTRUMENTATION_INACTIVE`, `PHASE_LIE`, `TIER_TAG_LIKELY_INCORRECT`): they have `candidates==checked==skipped==0` (no Mechanism A coverage) but DO appear in snapshots. That's not a mis-wire — they're cycle-time advisory codes that legitimately don't emit coverage.

The fix *is* the improvement: the mis-wire detector now also requires `last_failed_at is None` before flagging a 0-candidate gate. **A gate with failure history is demonstrably running** (it caught a recorded violation), so it can't be mis-wired. This makes the detector strictly sharper — it now distinguishes a truly-inert gate (0 coverage AND 0 failures = mis-wired) from a coverage-less cycle-time gate (0 coverage but real failures = fine).

## 5. Documented limitation

Write-time gates **block commits** rather than logging, so their blocks never reach a snapshot — `last_failed_at` is meaningful for cycle-time + advisory codes only. Recorded in the index's `failure_history_note`; a write-time block ledger is a T13.1 follow-up.

## 6. Verification (2026-06-10)

- `test_refresh_gate_last_fired.py` + `test_gate_coverage_zero.py`: **27 pass** (incl. 5 new merge-failure-history tests + 1 mis-wire-vs-failure-history test).
- Full coverage/integrity suite: 22 pass.
- `make integrity-check` → 0 findings (the 4 false GATE_COVERAGE_ZERO advisories cleared).

## 7. Cross-references

- **Spec:** [`docs/master-plan/test-coverage-master-plan-2026-05-13.md`](../master-plan/test-coverage-master-plan-2026-05-13.md) §4 T13.
- **Predecessor:** F17 `last_fired_at` index (v7.9.1); v7.10 `GATE_COVERAGE_ZERO` mis-wire detector (this case study refines it).
