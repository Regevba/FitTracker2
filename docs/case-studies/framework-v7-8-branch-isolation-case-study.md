---
title: "Framework v7.8 Branch Isolation + Feature-Closure Completeness — two cooperating gates from one full PM cycle"
type: feature_case_study
case_study_type: feature_complete
feature: framework-v7-8-branch-isolation
framework_version: "v7.8"
date_written: "2026-05-07"
dispatch_pattern: "serial (single-session, single-developer; agent-paced through 9 phase gates)"
work_type: "Feature"
work_subtype: "framework_feature"
shipped_window: "2026-05-07 (single-day full PM cycle)"
primary_metric: "Effective coverage on the 3 new write-time gates per Mechanism A telemetry"
primary_metric_status: "T1 Instrumented at ship; T+7d telemetry review on 2026-05-14"
success_metrics:
  - "BRANCH_ISOLATION_VIOLATION + FEATURE_CLOSURE_COMPLETENESS + ISOLATION_OPT_OUT_REASON_MISSING write-time gates: gate-coverage.jsonl emits {candidates, checked, skipped} per commit"
  - "Pre-commit hook total runtime stays under 10s (no dev-velocity regression)"
  - "Cycle-time mirrors (BRANCH_ISOLATION_HISTORICAL + LAUNCHD_DRIFT + FEATURE_CLOSURE_COMPLETENESS) emit advisory findings without false-positive blocks"
  - "T+7d window (2026-05-14) supports v7.8 → v7.9 promotion decision"
tier_tags_present: true
external_audit_status: "internal"
kill_criteria:
  - "BRANCH_ISOLATION_VIOLATION blocks > 20% of legitimate-on-main commits in week 1 → revert + redesign exemption logic"
  - "FEATURE_CLOSURE_COMPLETENESS blocks completes the user explicitly authorized → revert + add per-feature opt-out"
  - "Pre-commit hook total runtime exceeds 10s → revert (degrades dev velocity)"
  - "Mechanism A coverage ledger shows new gates at checked=0 for 7 consecutive days → revert (silent-pass class repeat)"
kill_criteria_resolution: "Pending T+7d (2026-05-14) measurement window. Gates ship in ADVISORY MODE in v7.8 — they emit telemetry to gate-coverage.jsonl but do NOT block any commits. The 4 kill criteria above evaluate at the v7.8 → v7.9 promotion decision point. v7.9 enforcement only proceeds if all 4 thresholds are met cleanly."
pr_citation_exempt: []
related_prs:
  - "FT2 #243 (GitHub Issue tracking)"
  - "FT2 #244 (squash-merge of 14 commits across Phase 0-6)"
spec_path: ".claude/features/framework-v7-8-branch-isolation/prd.md"
plan_path: ".claude/features/framework-v7-8-branch-isolation/tasks.md"
research_path: ".claude/features/framework-v7-8-branch-isolation/research.md"
predecessor_features:
  - "framework-v7-7-validity-closure"
  - "data-integrity-framework-v7-6"
  - "data-integrity-framework-v7-5"
  - "framework-v7-8-bridge"
  - "hadf-infrastructure"
status: live
---

# Framework v7.8 Branch Isolation + Feature-Closure Completeness

## TL;DR

Two cooperating pre-commit gates [T1] shipped as one feature in advisory mode on 2026-05-07. **`BRANCH_ISOLATION_VIOLATION`** prevents agents from mutating feature state from the wrong branch/worktree (Mode B fires on every commit when staged files match infra-path globs; Mode C fires on `current_phase` mutations from a non-feature branch). **`FEATURE_CLOSURE_COMPLETENESS`** fires on `current_phase=complete` transitions and validates 7 required case-study frontmatter fields + bidirectional PR-list parity + `kill_criteria_resolution` when `kill_criteria` is set.

**Single-day full PM cycle** [T2 declared]: 9 phase transitions, **14 commits** on the feature branch, **28/28 implementation tasks** done, **130/130 unit tests pass**, **19/19 pipeline assertions pass**, **0 high-risk iOS files touched** [T1].

The v7.7 silent-pass lesson — `CACHE_HITS_EMPTY_POST_V6` shipped at 0/46 effective coverage because the gate read `created_at` while 43/46 features used legacy `created` — defined the v7.8 design principle: **don't trust a gate until its Mechanism A coverage ledger says it's actually firing**. Both new gates ship in advisory mode; v7.9 promotion (earliest 2026-05-21, T+14d) waits on 7+ days of telemetry showing `checked > 0` continuously + false-positive rate < 5%.

## Two trigger incidents, one bundled feature

The feature emerged from two empirically-witnessed silent-pass failure modes that share the same pre-commit infrastructure:

**Incident 1 — HADF Phase 2 (2026-04-30):** a long-running launchd-driven fingerprint-collection job was anchored to the canonical repo path instead of an isolated `feature/` worktree. The wrapper's relative writes resolved against launchd's `WorkingDirectory`; canonical `.jsonl` data landed in the wrong tree; the campaign required mid-flight isolation + restart + remerge. Surfaced 4 distinct isolation failure modes the existing worktree pattern doesn't address (read-shared/write-isolated, awareness-without-blocking, conflict-detection-at-write-time, recoverable-state).

**Incident 2 — 2026-05-07 reconcile session (the day of this ship):** a documentation-debt readout pass surfaced **5 silently-missing case-study frontmatter fields** across 4 already-shipped features (UCC + import-training-plan + framework-story-site + push-notifications-v2). Manual reconcile took ~30 minutes — cost would be 0 if a write-time gate had blocked the closure commit. The 5 fields: `date_written`, `dispatch_pattern`, `success_metrics`, `kill_criteria`, plus a `case_study_showcase` typo on framework-story-site.

Bundled because both gates: (a) extend the same pre-commit infrastructure (`scripts/check-state-schema.py` + `scripts/check-case-study-preflight.py`); (b) share v7.8 Mechanism A coverage telemetry; (c) emerged from the same root cause class — silent gaps in cross-references the existing gate stack doesn't see.

## 9 phase transitions in one session

The PM workflow ran end-to-end for the first time on a v7.8-protocol feature (active-feature lockfile, Mechanism C session attribution, isolated worktree from Phase 1 onward):

| Phase | Trigger | Output | Wall-time bucket |
|-------|---------|--------|-------------------|
| 0 Research | Feature opened 2026-04-30; synthesis 2026-05-07 | `research.md` (289 lines, 10 sections) — synthesis from 3 prior research notes + 7 locked decisions | ~0d (artifact already drafted; just synthesis) |
| 1 PRD | Synthesis approved | `prd.md` (629 lines, 15 sections) — gate predicates as Python pseudocode + schema additions + acceptance criteria | ~3-4h |
| 2 Tasks | PRD approved + out-of-scope companion + 7 backlog entries seeded | `tasks.md` — 28 tasks in 8 blocks (A-H) with v5.1 task-complexity classification + T29 Phase 9 prioritization deliverable | ~30min |
| 3 Integration | Tasks approved | `integration-spec.md` (450 lines, 9 sections) — skill API contracts + backward compat + migration plan | ~30min |
| 4 Implementation | Integration spec approved | All 8 blocks shipped: schema, both gates, advisories, skill extensions, make targets, tests, docs | ~2-3h |
| 5 Test | Block H landed | 4 new pipeline assertions added; 130 pytest + 19 pipeline assertions all pass | ~15min |
| 6 Review | Tests green | Pre-merge-reviews N/A (has_ui:false); risk surface low; 0 high-risk iOS files | ~10min |
| 7 Merge | Review approved | PR #244 squash-merged at `6d1a53f` | ~5min |
| 8 Documentation | Merge complete | This case study + showcase MDX + state.json closure | (this section) |

**Total commits:** 14 on feature branch + 1 squash on main + N/A in this Phase 8.
**Estimated wall-clock:** ~6-8 hours full session.

## What the gates check

### `BRANCH_ISOLATION_VIOLATION` (Block B, T6/T7)

Two-mode predicate per the locked Q1 decision [T1]:

- **Mode B (every commit, infra paths)** — fires when ANY staged file matches the 8-glob list (`.githooks/*`, `.github/workflows/*`, `scripts/*`, `.claude/skills/*`, `.claude/shared/*`, `CLAUDE.md`, `docs/architecture/*`, `Makefile`) OR the modified state.json's `work_subtype: framework_feature` or `work_type: chore`. Per-feature `isolation_opt_out: true` is **ignored** for Mode B (Q3 infra override — the framework cannot opt itself out of its own enforcement).
- **Mode C (per-state.json, current_phase mutations)** — fires only when staged state.json mutates `current_phase` AND current branch != `state.json::branch`. Honors per-feature `isolation_opt_out: true`.

Auto-isolation flow: gate fires → prints remediation message pointing at `scripts/create-isolated-worktree.py` (T20 — the local CLI equivalent of `superpowers:using-git-worktrees`). The script is idempotent: if the worktree already exists at the expected path with the right branch, it ADOPTS it (links state.json + registers the lease) instead of failing.

### `FEATURE_CLOSURE_COMPLETENESS` (Block C, T11-T14)

Fires on `current_phase=complete` transitions. Validates four sub-checks [T1]:

1. **7 required case-study frontmatter fields** with synonym resolution: `date_written` (or `date`), `dispatch_pattern`, `success_metrics` (or `primary_metric`), `kill_criteria`, `framework_version`, `work_type`, `tier_tags_present` (boolean OR body T1/T2/T3 tag fallback).
2. **Q7 `kill_criteria_resolution`** required when `kill_criteria` is non-empty. Heuristic substantive check: must mention a kill threshold OR contain acceptance keywords (`not tripped`, `deferred`, `superseded`, `passed`).
3. **Q6 bidirectional PR-list parity** between state.json (`tasks[].pr_number`, `phases.merge.pr_number`, `tasks[].related_prs`) and case study (regex `PR #N` / `pull/N` matches in body + `related_prs` frontmatter). Override via `pr_citation_exempt: [{pr_number, reason}]` frontmatter array.
4. **Cycle-time mirror** in `integrity-check.py` catches `--no-verify` bypasses (T19, forward-only).

## v7.8 advisory protocol — the discipline of unfired gates

Both gates ship in **advisory mode**: they emit Mechanism A coverage telemetry to `.claude/logs/gate-coverage.jsonl` on every script run but **do NOT block any commits**. The pre-commit hook prints `[ADVISORY]` warnings to stderr; the exit code stays 0 unless OTHER (existing) gates fail.

This is the explicit lesson from v7.7's `CACHE_HITS_EMPTY_POST_V6` silent-pass [T1]: the gate shipped at 0/46 effective coverage because 43/46 features used the legacy `created` key while the gate read `created_at`. The gate "ran" 53 times per script invocation but `checked=0` every time — a textbook silent pass. v7.8's design principle: **measure the gate's effective coverage before promoting to enforced**.

The promotion path:

| Phase | Trigger | Behavior |
|-------|---------|----------|
| **v7.8 advisory** (this ship) | 2026-05-07 | Gates emit telemetry; print warnings; do NOT block |
| **v7.8 grace** (T+7d, 2026-05-14) | Telemetry review | Verify `checked > 0` continuously for 7 days + FP rate < 5% from any `manual_bypass` events |
| **v7.9 enforced** (T+14d earliest, 2026-05-21) | Decision point | Single config-flag flip in `.claude/shared/framework-manifest.json::gates.{name}.enforcement` from `advisory` → `enforced`. Gates start blocking. |

If kill criteria fire at T+7d, revert procedure: `git revert {merge_commit} -m 1` + open hot-fix PR + restore previous `.githooks/pre-commit` content + open root-cause case study within 48h. v7.5 pipeline test verified the rollback works.

## Verification matrix at ship

| Check | Result |
|-------|--------|
| `pytest scripts/tests/` | **130/130 pass** [T1] |
| `scripts/test-v7-5-pipeline.sh` | **19/19 pass** (15 baseline + 4 new) [T1] |
| `make schema-check` | **53/53 pass** (no regression) [T1] |
| `make integrity-check` | 0 findings + 9 advisory (non-gating) [T1] |
| `make verify-isolation` | **53/53 features clean** [T1] |
| `make feature-completeness-audit` | 0 blocking + 1 advisory (forward-only working — historical features grandfathered) [T1] |
| `make pre-commit-self-test` (Mechanism D) | 16 declared = 14 implemented + 2 inline; **clean** [T1] |
| Mechanism A telemetry on 3 new gates | All emit `gate-coverage.jsonl` entries with `candidates`, `checked`, `skipped` counts [T1] |

## What the diff contained

- **25 files changed** [T1], **+4548 insertions / -38 deletions** [T1]
- **0 high-risk iOS files touched** [T1] (DomainModels.swift, EncryptionService, SupabaseSyncService, CloudKitSyncService, SignInService, AuthManager, AIOrchestrator all unchanged)
- 14 feature-branch commits + 1 squash-merge commit on main

Files that grew most: `scripts/check-state-schema.py` (+654), `scripts/integrity-check.py` (+248), `scripts/create-isolated-worktree.py` (+214 NEW), `scripts/feature-completeness-audit.py` (+192 NEW), `scripts/tests/test_branch_isolation_and_closure_completeness.py` (+174 NEW), `scripts/verify-isolation.py` (+153 NEW). Documentation propagated to CLAUDE.md + `.claude/integrity/README.md`.

## What the framework caught about itself

Three meta-observations from running the v7.8 protocol on a v7.8-protocol feature:

1. **Mechanism C session attribution worked end-to-end** [T1]. The `.claude/active-feature` lockfile written at `/pm-workflow` invocation captured every Read tool call into `.claude/logs/_session-<id>.events.jsonl` with the correct `active_feature` tag throughout the session. No drift across worktree creation, branch switches, or phase transitions.

2. **The PHASE_TRANSITION_NO_LOG gate fired correctly on every phase mutation** [T1]. Tier 2.2 events were appended to `<feature>.log.json` BEFORE state.json mutations on all 9 phase transitions. Order matters: log-first, state-second, commit-third. Initial near-miss when the feature's log was being written to the wrong worktree (main's filesystem instead of the feature worktree's filesystem) was caught immediately because the worktree's log had the older state and pre-commit's freshness check would have flagged it. Recovered by appending events directly to the worktree's log file via Python (bypassing the script's static `REPO_ROOT`).

3. **The `make documentation-debt` readout informed Block C's predicate design** [T2 declared]. The 5 doc-debt items found in the 2026-05-07 reconcile session became the EXACT list of fields enforced by `FEATURE_CLOSURE_COMPLETENESS` Q12. The readout-time detection logic in `documentation-debt-report.py` was promoted to the write-time gate predicate — single source of truth, zero duplicate field-list maintenance.

## Out-of-scope deliverables (queued for v8 prioritization at Phase 9)

7 items were explicitly de-scoped during Phase 0 research [T1]: Sapling-smartlog UI, jj op-log replay, Vercel Sandbox, Landlock/App Sandbox, path-watcher daemon, cross-feature dependency graph, auto-rollback on kill criteria. Each got a backlog entry + companion spec at `docs/superpowers/specs/2026-05-07-branch-isolation-out-of-scope.md` with re-evaluation triggers. Phase 9 prioritization pass on 2026-05-21 (T+14d) will produce the ranked v8 roadmap based on 7-day telemetry signals.

## What's next: T+7d telemetry review (2026-05-14)

Pull `gate-coverage.jsonl` entries for the 3 new gates. Verify:
- `BRANCH_ISOLATION_VIOLATION` Mode B fires on infra-path commits (≥ 1 fire expected per ~5 commits)
- `FEATURE_CLOSURE_COMPLETENESS` fires when any feature transitions to complete (count = number of complete-transitions in the 7-day window)
- `ISOLATION_OPT_OUT_REASON_MISSING` evaluates on every state.json file (53 candidates per --all run)
- False-positive rate < 5% across all three (count `manual_bypass` events vs total fires)

If clean → schedule v7.9 promotion (single config-flag flip). If kill criteria fire → revert + redesign.

## References

- PRD: [`.claude/features/framework-v7-8-branch-isolation/prd.md`](../../.claude/features/framework-v7-8-branch-isolation/prd.md)
- Tasks: [`.claude/features/framework-v7-8-branch-isolation/tasks.md`](../../.claude/features/framework-v7-8-branch-isolation/tasks.md)
- Research synthesis: [`.claude/features/framework-v7-8-branch-isolation/research.md`](../../.claude/features/framework-v7-8-branch-isolation/research.md)
- Integration spec: [`.claude/features/framework-v7-8-branch-isolation/integration-spec.md`](../../.claude/features/framework-v7-8-branch-isolation/integration-spec.md)
- Out-of-scope companion: [`docs/superpowers/specs/2026-05-07-branch-isolation-out-of-scope.md`](../superpowers/specs/2026-05-07-branch-isolation-out-of-scope.md)
- v7.8 bridge case study (predecessor): [`framework-v7-8-bridge-case-study.md`](framework-v7-8-bridge-case-study.md)
- v7.7 validity closure case study (predecessor): [`framework-v7-7-validity-closure-case-study.md`](framework-v7-7-validity-closure-case-study.md)
- Lifecycle event catalog (companion to dev-guide): [`docs/architecture/feature-lifecycle-event-catalog.md`](../architecture/feature-lifecycle-event-catalog.md)
