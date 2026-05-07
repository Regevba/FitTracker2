# Tasks — framework-v7-8-branch-isolation

> **Phase:** 2 (Tasks) · authored 2026-05-07 against [`prd.md`](prd.md) §10 acceptance criteria
> **Total tasks:** 28 (T1–T28) + T29 (Phase 9 prioritization pass on §11 out-of-scope items)
> **Effort estimate:** ~5-6 dev days for E-core lane (parallel) + ~3-4 dev days for P-core lane (serial) + ~1 day docs/test = **~9-11 dev days total wall time**
>
> **Lanes (per v5.1 task complexity gate):**
> - **E-core (lightweight, parallel, sonnet):** schema additions, doc updates, test scaffolding, taxonomy seeding
> - **P-core (heavyweight, serial, opus):** gate predicate logic, auto-isolation flow, cycle-time check codes, skill extensions
>
> **Dispatch model:** parallel within lane, serial across lanes per v5.2 dispatch intelligence + Q1 Mode B isolation (every commit on this branch fires Mechanism A coverage telemetry once gates exist; before that we're bootstrapping).

---

## Block A — Schema additions (E-core, parallel)

| ID | Title | Skill | Effort | Depends on | Notes |
|----|-------|-------|--------|------------|-------|
| **T1** | Add `isolation_opt_out` + `isolation_opt_out_reason` + `worktree_path` fields to canonical state.json schema in [`scripts/check-state-schema.py`](../../../scripts/check-state-schema.py) | dev | 0.5d | — | Defaults: opt_out=false, reason="", worktree_path=null. Schema validation: opt_out=true requires non-empty reason. |
| **T2** | Add `kill_criteria_resolution` + `pr_citation_exempt` to case-study frontmatter required-field list in [`scripts/documentation-debt-report.py`](../../../scripts/documentation-debt-report.py) | dev | 0.3d | — | Required-when: `kill_criteria_resolution` mandatory if `kill_criteria` non-empty AND current_phase=complete. `pr_citation_exempt` always optional. |
| **T3** | Create `.claude/shared/branch-isolation-exempt.json` with initial allowlist | dev | 0.2d | — | Schema: `{paths: [glob], reason: string, expires_at: ISO8601 \| null}`. Initial entries: glob patterns for legitimate-on-main work (CLAUDE.md edits during freeze, security patches). |
| **T4** | Extend `.claude/shared/path-reducers.json` with 4 initial entries (PRD §8) | dev | 0.2d | — | measurement-adoption-history (union_dedup by date) + documentation-debt (replace) + gate-coverage.jsonl (append) + _session-*.events.jsonl (append per-session). |

**Block A total:** 1.2 dev-days. Parallel dispatch (sonnet). All write-time gates enabled by these schema additions are gated by Block B.

---

## Block B — `BRANCH_ISOLATION_VIOLATION` gate (P-core, serial)

| ID | Title | Skill | Effort | Depends on | Notes |
|----|-------|-------|--------|------------|-------|
| **T5** | Implement `is_infra_work()` classifier per PRD §4.1 | dev | 0.5d | T1 | Globs: `.githooks/*`, `.github/workflows/*`, `scripts/*`, `.claude/skills/*`, `.claude/shared/*`, `CLAUDE.md`, `docs/architecture/*`, `Makefile`. Plus `work_subtype=framework_feature` OR `work_type=chore`. Unit-tested via T22.j. |
| **T6** | Implement `should_check_branch_isolation()` predicate (Mode B + Mode C) per PRD §4.1 | dev | 0.5d | T1, T5 | Mode B (infra) fires every commit; Mode C (non-infra) fires on `current_phase` mutation. `isolation_opt_out` honored for non-infra; ignored for infra (override). Unit-tested via T22.k. |
| **T7** | Implement `is_branch_isolation_violation()` violation predicate per PRD §4.1 | dev | 0.5d | T1, T6 | Reads `state.json::branch` + `state.json::worktree_path`. Compares against `git rev-parse --abbrev-ref HEAD` + `os.getcwd()`. Returns true on mismatch. Unit-tested via T22.l. |
| **T8** | Wire `BRANCH_ISOLATION_VIOLATION` into [`scripts/check-state-schema.py`](../../../scripts/check-state-schema.py) main flow with Mechanism A coverage emission | dev | 0.5d | T6, T7 | Emits `{candidates, checked, skipped, skip_reasons}` to gate-coverage.jsonl. Format matches §4.1 contract. Advisory mode: print warning + record telemetry, do NOT exit non-zero. |
| **T9** | Implement auto-isolation flow per PRD §4.1: dispatch `superpowers:using-git-worktrees --feature {slug} --create-if-missing` on gate fire | dev | 1.0d | T8, T20 | Print error message matching §4.1 contract verbatim. Loop detection: if `state.json::auto_isolation_attempted: true`, block + ask user. Updates state.json::worktree_path post-create. |
| **T10** | Implement error message contract per §4.1 | dev | 0.2d | T9 | Exact text matching the spec block in PRD §4.1. Tested via T22.l verifying output. |

**Block B total:** 3.2 dev-days. Serial dispatch (opus) — heavyweight gate logic with judgment-bearing edge cases. Critical path.

---

## Block C — `FEATURE_CLOSURE_COMPLETENESS` gate (P-core, serial)

| ID | Title | Skill | Effort | Depends on | Notes |
|----|-------|-------|--------|------------|-------|
| **T11** | Implement `should_check_closure_completeness()` predicate per PRD §4.2 | dev | 0.3d | T2 | Triggers ONLY on staged state.json with `current_phase: complete` post-commit. Unit-tested via T22.a. |
| **T12** | Implement `closure_completeness_violations()` per PRD §4.2: required field presence check | dev | 0.5d | T2, T11 | 7 required fields: date_written (or date), dispatch_pattern, success_metrics (or primary_metric), kill_criteria, framework_version, work_type, tier_tags_present:true. Reuses canonical list from documentation-debt-report.py. |
| **T13** | Add Q7 check: `kill_criteria_resolution` required when `kill_criteria` set | dev | 0.2d | T12 | Empty resolution → block. Tested via T22.f. |
| **T14** | Add Q6 check: bidirectional PR-list parity per PRD §4.2 | dev | 0.7d | T12 | Compute `state_prs` (tasks[].pr_number + phases.merge.pr_number + tasks[].related_prs), `case_prs` (regex `PR #N` + frontmatter related_prs), exempt set (case study `pr_citation_exempt`). Report state_only + case_only deltas. Tested via T22.g + T22.h. |
| **T15** | Wire `FEATURE_CLOSURE_COMPLETENESS` into pre-commit with Mechanism A coverage emission | dev | 0.4d | T11, T12, T13, T14 | Emit `{candidates:1, checked:1, skipped:0}` on complete-transition; `{candidates:1, checked:0, skipped:1, skip_reasons: {not_complete_transition:1}}` otherwise. Format matches §4.2. Advisory mode. |
| **T16** | Implement error message contract per §4.2 | dev | 0.2d | T15 | Exact spec block. Tested via T22.f/g/h verifying output. |

**Block C total:** 2.3 dev-days. Serial dispatch (opus) — heavyweight regex + cross-reference logic with judgment-bearing edge cases (PR-list overlap detection).

---

## Block D — Cycle-time mirrors + advisories (E-core, parallel)

| ID | Title | Skill | Effort | Depends on | Notes |
|----|-------|-------|--------|------------|-------|
| **T17** | Implement `BRANCH_ISOLATION_HISTORICAL` advisory in [`scripts/integrity-check.py`](../../../scripts/integrity-check.py) | dev | 0.5d | T7 | Audits `.claude/features/*/state.json` against `git log --all --oneline -- path/to/feature/`. Forward-only (created_at >= ship_date). Tested via T24.a. |
| **T18** | Implement `BRANCH_ISOLATION_LAUNCHD_DRIFT` advisory (macOS-only, gracefully skipped on Linux/CI) | dev | 0.5d | T17 | Scan `~/Library/LaunchAgents/*.plist` for `ProgramArguments` referencing `.claude/features/`. Verify `WorkingDirectory` matches expected worktree. Skip when `os.uname().sysname != "Darwin"`. Tested via T24.b. |
| **T19** | Implement cycle-time mirror of `FEATURE_CLOSURE_COMPLETENESS` to catch `--no-verify` bypasses | dev | 0.3d | T15 | Re-runs T12-T14 predicates on every feature with current_phase=complete. Findings (gating in v7.9; advisory in v7.8). Tested via T24.c. |

**Block D total:** 1.3 dev-days. Parallel dispatch (sonnet). All add to existing 13-code cycle-time check inventory in integrity-check.py — bumps to 16.

---

## Block E — Skill extensions (P-core, serial)

| ID | Title | Skill | Effort | Depends on | Notes |
|----|-------|-------|--------|------------|-------|
| **T20** | Extend `superpowers:using-git-worktrees` skill: add `--feature X --create-if-missing` args + naming convention by work_type/subtype | dev | 0.5d | T1 | Naming: `FitTracker2-infra-{shortname}` for infra (work_subtype=framework_feature OR work_type=chore); `FitTracker2-{feature}` otherwise. Updates state.json::worktree_path + agent-leases.json. |
| **T21** | Extend `/ux pre-merge-review` and `/design pre-merge-review` skills with sub-step 6f (kill_criteria_resolution check) | dev | 0.4d | T13 | Heuristic: if kill_criteria non-empty, verify resolution non-empty AND mentions ≥ 1 kill threshold OR contains "not tripped" / "deferred" / "superseded" / "passed". Failure → state.json::pre_merge_review.{ux,design}: blocked. Update [`docs/skills/ux.md`](../../../docs/skills/ux.md) + [`docs/skills/design.md`](../../../docs/skills/design.md). |

**Block E total:** 0.9 dev-days. Serial dispatch (opus) — touching skills requires careful prompt engineering.

---

## Block F — `make` targets (E-core, parallel)

| ID | Title | Skill | Effort | Depends on | Notes |
|----|-------|-------|--------|------------|-------|
| **T22** | Create `scripts/verify-isolation.py` and `make verify-isolation` target | dev | 0.4d | T7 | Output format matches PRD §6.1. Runtime budget < 5s for 53 features. Exit 0 if all clean OR all findings have explicit opt-out reasons; 1 otherwise. |
| **T23** | Create `scripts/feature-completeness-audit.py` and `make feature-completeness-audit` target | dev | 0.5d | T11, T12, T13, T14 | Output format matches PRD §6.2. Phase-appropriate field-presence checks (research = schema basics; PRD = cu_v2 + success_metrics; complete = full closure check). Runtime < 10s for 53 features. |

**Block F total:** 0.9 dev-days. Parallel dispatch (sonnet). Both targets join [`Makefile`](../../../Makefile) ≤ implementation, ≤ verify-local, etc.

---

## Block G — Tests (mixed lanes; runs after Block B/C/D/E/F)

| ID | Title | Skill | Effort | Depends on | Notes |
|----|-------|-------|--------|------------|-------|
| **T24** | Unit tests for `BRANCH_ISOLATION_VIOLATION` predicates (extends `scripts/tests/test_check_state_schema.py`) | qa | 0.5d | T6, T7, T9 | 5 cases per PRD §9.1: infra-fires, non-infra-typo-skips, current_phase-fires, opt-out-honors-non-infra, opt-out-overrides-for-infra. |
| **T25** | Unit tests for `FEATURE_CLOSURE_COMPLETENESS` predicates | qa | 0.4d | T13, T14 | 4 cases per PRD §9.1: missing kill_criteria_resolution-blocks, bidirectional-parity, pr_citation_exempt-works, mechanism-A-coverage-emitted. |
| **T26** | Cycle-time tests for advisories (extends `scripts/tests/test_integrity_check.py`) | qa | 0.4d | T17, T18, T19 | Synthetic-violation tests for HISTORICAL + LAUNCHD_DRIFT (macOS-only) + closure-completeness mirror. |
| **T27** | Integration test extension: 4 new assertions in [`scripts/test-v7-5-pipeline.sh`](../../../scripts/test-v7-5-pipeline.sh) | qa | 0.3d | T8, T15, T22, T23 | Per PRD §9.2: BRANCH_ISOLATION fires/skips correctly (2 assertions); FEATURE_CLOSURE_COMPLETENESS fires/honors-exempt (2 assertions). |

**Block G total:** 1.6 dev-days. T24/T25 parallel; T26 follows; T27 last (depends on full integration).

---

## Block H — Documentation + framework version updates (E-core, parallel; runs last)

| ID | Title | Skill | Effort | Depends on | Notes |
|----|-------|-------|--------|------------|-------|
| **T28** | Update doc inventory: [`docs/architecture/feature-lifecycle-event-catalog.md`](../../../docs/architecture/feature-lifecycle-event-catalog.md) §6 (gate stack), [`docs/architecture/dev-guide-v1-to-v7-7.md`](../../../docs/architecture/dev-guide-v1-to-v7-7.md) §10.1 (12→14 write-time + 13→16 cycle-time), [`CLAUDE.md`](../../../CLAUDE.md) Data Integrity Framework section, [`.claude/integrity/README.md`](../../../.claude/integrity/README.md) check codes inventory | docs | 0.6d | All B+C+D | Match existing v7.7 → v7.8 doc-update pattern. Mechanism D self-audit must pass on updated `.githooks/pre-commit` header. |

**Block H total:** 0.6 dev-days. Parallel within doc updates (sonnet). Runs after gates exist + Mechanism A telemetry verified.

---

## T29 — Phase 9 prioritization pass on §11 out-of-scope items

> **NOT a Phase 4 (Implement) task.** This is a Phase 9 (Learn) deliverable noted here for traceability. Tracked separately from the 28 implementation tasks above.

| ID | Title | Skill | Effort | Depends on | Notes |
|----|-------|-------|--------|------------|-------|
| **T29** | At Phase 9 (Learn) close — earliest 2026-05-21 — produce ranked v8 roadmap from [`docs/superpowers/specs/2026-05-07-branch-isolation-out-of-scope.md`](../../../docs/superpowers/specs/2026-05-07-branch-isolation-out-of-scope.md) 7 items | research | 0.5d | All Phase 7 (Merge) complete + ≥ 7 days of `gate-coverage.jsonl` telemetry | Inputs: 7-day Mechanism A telemetry, `make documentation-debt` open count trend, `agent-leases.json` count, `path-reducers.json` count, forensic memory entries for stash/orphan drift. Output: ranked list with re-eval trigger status + cu_v2 re-estimate + recommendation (v8.0 / v8.1 / v8.2 / defer). Lands as case study Phase 9 section + backlog reorganization commit. |

---

## Total summary

| Block | Lane | Tasks | Effort (dev-days) | Critical-path? |
|-------|------|-------|-------------------|----------------|
| A — Schema | E-core | 4 | 1.2 | parallel start |
| B — Branch isolation gate | P-core | 6 | 3.2 | YES |
| C — Closure completeness gate | P-core | 6 | 2.3 | YES |
| D — Cycle-time mirrors | E-core | 3 | 1.3 | follows B+C |
| E — Skill extensions | P-core | 2 | 0.9 | follows B+C |
| F — Make targets | E-core | 2 | 0.9 | follows B+C |
| G — Tests | qa-mixed | 4 | 1.6 | follows all |
| H — Docs | docs (E-core) | 1 | 0.6 | last |
| **Subtotal** | — | **28** | **~12 dev-days** | — |
| T29 — Phase 9 prioritization | research | 1 | 0.5 | post-merge + 7d |

**Critical path:** A → B (3.2d) → C (2.3d) → tests/docs cleanup → ship. With parallel E-core lanes, total wall-clock should be ~7-9 dev days for Phase 4 (Implementation).

---

## Dispatch order

### Round 1 (parallel E-core)
T1, T2, T3, T4 — schema additions (1.2d total, ~4 sonnet dispatches)

### Round 2 (serial P-core)
T5 → T6 → T7 → T8 — branch isolation gate logic (2d)
T11 → T12 → T13 → T14 → T15 → T16 — closure completeness gate logic (2.3d)

(T20 can run in parallel with T15 since it's a separate skill file.)

### Round 3 (parallel E-core; mixed P-core)
T17, T18, T19 — cycle-time advisories (parallel, sonnet)
T20, T21 — skill extensions (serial, opus)
T22, T23 — make targets (parallel, sonnet)
T9 — auto-isolation flow (depends on T8 + T20; opus)
T10 — error message contract (depends on T9; sonnet)

### Round 4 (parallel qa)
T24, T25, T26, T27 — tests (parallel, sonnet)

### Round 5 (parallel docs)
T28 — documentation propagation (sonnet)

### Phase 5 (Test) gate
All 28 tasks complete + integration test passes + Mechanism A telemetry shows new gates firing.

### Phase 9 deliverable
T29 — at branch-isolation feature close, after ≥ 7 days of telemetry.

---

## Phase 2 → Phase 3 (Integration) gate

Tasks approved → advance to Phase 3 (Integration) since `has_ui: false`. Phase 3 (Integration) will produce `integration-spec.md` with:
- Pre-commit hook integration order (extends [`.githooks/pre-commit`](../../../.githooks/pre-commit) — confirms PRD §5)
- API contracts for `superpowers:using-git-worktrees` extension (T20)
- API contracts for `/ux + /design pre-merge-review` extensions (T21)
- Backward compatibility: how existing 12 write-time gates + 13 cycle-time codes remain unaffected
- Error handling: pre-commit gate failure surface + `--no-verify` bypass behavior + `manual_bypass` recording

Then advance to Phase 4 (Implementation) following the dispatch order above.
