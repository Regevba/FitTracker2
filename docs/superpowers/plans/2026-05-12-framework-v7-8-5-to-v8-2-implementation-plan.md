# Framework Implementation Plan: v7.8.5 → v8.2

**Status:** input plan · not yet a PRD per version (each version's PRD spawned at its build start)
**Created:** 2026-05-12
**Scope:** task/sub-task/test/telemetry-checkpoint breakdown for all 6 upcoming framework versions
**Predecessor:** [`docs/master-plan/infra-master-plan-2026-05-12.md`](../../master-plan/infra-master-plan-2026-05-12.md) §3.5 (Calibration Protocol) + §3.6 (Forward Plan high-level)
**Source candidates spec:** [`docs/superpowers/specs/2026-05-08-framework-v7-9-candidates.md`](../specs/2026-05-08-framework-v7-9-candidates.md) (F1–F18)
**Source icebox spec:** [`docs/superpowers/specs/2026-05-07-branch-isolation-out-of-scope.md`](../specs/2026-05-07-branch-isolation-out-of-scope.md) (V8-I1–V8-I7)
**Audience:** framework operator + agents executing the build steps

---

## §1 Overview

23 open candidates mapped to 6 version slots over 11 months (2026-05-13 → 2027-05-12). Each task walks the 5-phase Calibration Protocol from [infra plan §3.5](../../master-plan/infra-master-plan-2026-05-12.md#35-calibration-protocol-for-new-layers); no new layer ships on top of a non-Phase-E layer.

| Version | Window | Items | Status |
|---|---|---|---|
| **v7.8.5** | 2026-05-12 → 13 | 1 task (cache_hits fix) | ✅ SHIPPED PR #320 |
| **v7.9** | 2026-05-18 → 21 | 5 enforcement flips | Calibration window OPEN |
| **v7.9.1** | 2026-06-04 → 11 | 4 items (F16, F17, F2, F6) | Pending v7.9 Phase E |
| **v8.0** | 2026-06-18 → 07-31 | 6 items (top-per-theme docket) | Pending 2026-05-21 ranking |
| **v8.1** | 2026-08 → 09 | 5–7 deferred F-items + early V8-I triggers | Pending v8.0 Phase E |
| **v8.2+** | 2026-12+ | Long-tail V8-I icebox per triggers | Pending re-eval |

**Critical date:** 2026-05-21 is the v7.9 promotion decision + the T29 v8.0 docket ranking pass at `framework-v7-8-branch-isolation` Phase 9 closure.

---

## §2 Calibration Framework (operational reference)

Every new layer walks Phases A → E:

| Phase | Min duration | Required artifacts | Exit criteria |
|---|---|---|---|
| **A — Specify** | Pre-code | Gate spec + 1 positive fixture + 1 negative fixture + dispatch regression test | All 4 artifacts exist before merge |
| **B — Ship advisory + measure** | 7 days | Emission to `gate-coverage.jsonl` with `{candidates, checked, skipped, skip_reasons}`; advisory mode (logs, doesn't block); operator T+3d checkpoint | ≥7 days elapsed AND ≥1 real fire OR ≥3 legitimate skips |
| **C — Calibration gate** | 7 days | ≥N gate fires (N=5 default, N=10 for novel mechanisms). Zero false positives. All skips match documented reasons. | All quantitative + qualitative checks pass |
| **D — Promotion decision** | 1 day | Decision in case study + honesty ledger + CLAUDE.md update. Reversibility rehearsed. | Flipped enforced OR stays advisory with documented reason |
| **E — Post-promotion validation** | 7 days | Continuous monitoring; 0 false-positive incidents | Layer is "stable"; new layers may build on top |

**Layer stacking rule:** no new layer may BUILD on top of a layer that hasn't reached Phase E.

**Data Freshness Audit (recurring quarterly):** 2026-08-12 · 2026-11-12 · 2027-02-12 · 2027-05-12. Asserts emission key ↔ function name ↔ test name parity; flags zero-coverage gates over 30 days; catches the cache_hits-class rename drift.

**Reversibility contract:** advisory rollback <2min; enforced rollback <5min; mechanism rollback <30min. Rehearsed at Phase D.

---

## §3 v7.8.5 — Pre-Promotion Patch (SHIPPED 2026-05-12 via PR #320)

### Goal

Verify the 2026-05-21 v7.9 promotion decision input data is keyed correctly. Resolve PR #318 §"Pre-promotion remediation" concern about cache_hits keying drift.

### T7.8.5.1 — cache_hits gate-coverage test fixture rot

#### Sub-tasks

- [x] **T7.8.5.1.1 Diagnose** which of 3 cases applies: (a) rename incomplete, (b) fixture rot, (c) coverage deleted. Read `scripts/check-state-schema.py:281-350` for gate function. Count entries by gate name in `gate-coverage.jsonl` last 7 days.
- [x] **T7.8.5.1.2 Confirm case (2) fixture rot.** Gate function emits canonical `CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT` (verified line 308 + line 343). 5 entries in ledger last 7 days under canonical key. 175 entries under legacy key are historical (pre-rename, append-only ledger).
- [x] **T7.8.5.1.3 Write regression test** `test_cache_hits_gate_emits_canonical_key` — asserts canonical key IS in `cov.gates`, legacy key is NOT. Locks invariant against future rename drift.
- [x] **T7.8.5.1.4 Fix 4 fixtures** — extract `CACHE_HITS_GATE_KEY` module constant, update 4 test functions to use it.
- [x] **T7.8.5.1.5 Verify** all 15 `test_gate_coverage.py` tests pass (was 11/15) + `pre-commit-self-test.py` passes + no new failures in broader suite.

#### New tests (1)

- `test_cache_hits_gate_emits_canonical_key` (regression).

#### Telemetry checkpoint

- ≥1 canonical-key emission per `make integrity-check` invocation. **Verified 2026-05-12T14:23:37Z** (post-PR #317) — first canonical emission after the bug fix. Pre-PR #320 already had 5 entries in last 7 days.

#### Calibration gate

N/A. This is a fix, not a new layer. No Phase B–E walk needed.

#### Status

**SHIPPED 2026-05-12 via PR #320** (commit `0af007d`).

---

## §4 v7.9 — Promotion Release (SHIPPED 2026-05-21 via PR #417 `ea53ff4`)

> **Outcome:** 3 advisory gates promoted (not 5 — see notes below) via single-flag flip at [`scripts/check-state-schema.py:132`](../../../scripts/check-state-schema.py). Mechanism A + Mechanism C were already enforced at v7.8 / v7.8.3 ship dates, so v7.9 only flipped the remaining 3: `BRANCH_ISOLATION_VIOLATION` Mode B + Mode C + `FEATURE_CLOSURE_COMPLETENESS`. Phase E validation soak 2026-05-21 → 2026-06-04; case study at [`docs/case-studies/framework-v7-9-promotion-case-study.md`](../../case-studies/framework-v7-9-promotion-case-study.md). v7.9.1 build window opens ~2026-06-04 (F16 + F17 + F2 + F6 + D-2 + D-4 first wave per [infra-plan §3.6.3](../../master-plan/infra-master-plan-2026-05-12.md)).

### Goal

Flip 5 currently-advisory gates to enforced based on 7+ days of clean `gate-coverage.jsonl` telemetry. **Actual:** only 3 needed flipping (Mechanism A + C already enforced earlier).

### Pre-decision state (as of 2026-05-12)

| Gate | Advisory ship | Required N fires | Current N fires |
|---|---|---|---|
| `BRANCH_ISOLATION_VIOLATION` Mode B | v7.8.1 (2026-05-07) | ≥5 | TBD (count at 2026-05-20) |
| `BRANCH_ISOLATION_VIOLATION` Mode C | v7.8.1 (2026-05-07) | ≥5 | TBD |
| `FEATURE_CLOSURE_COMPLETENESS` | v7.8.1 (2026-05-07) | ≥3 | TBD |
| Mechanism A coverage gates | v7.8 (2026-05-04) | ≥7d data | MET (8d elapsed) |
| Mechanism C session-attribution | v7.8 (2026-05-04) | ≥7d data | MET (8d elapsed) |

### T7.9.0 — Pre-decision data review (2026-05-18 → 2026-05-20)

#### Sub-tasks

- [ ] **T7.9.0.1** Refresh PR cache via `scripts/refresh-pr-cache.py` to ensure BROKEN_PR_CITATION calibration data is current.
- [ ] **T7.9.0.2** Run `make integrity-check` from clean canonical and capture baseline finding count.
- [ ] **T7.9.0.3** Count `gate-coverage.jsonl` entries per gate over 2026-05-14 → 2026-05-20 window. Per-gate `{candidates, checked, skipped}` aggregates.
- [ ] **T7.9.0.4** Manual review of EVERY `failure` row across the window (expected to be 0 — advisory gates don't emit failures, just record candidates). Confirm 0 false positives.
- [ ] **T7.9.0.5** Manual review of every `skipped` row — confirm reasons match documented expected reasons in [`docs/case-studies/framework-v7-8-bridge-case-study.md`](../../case-studies/framework-v7-8-bridge-case-study.md).
- [ ] **T7.9.0.6** Rehearse rollback path: single-commit revert + hook header bump from "enforced" → "advisory" tested in throwaway worktree, time <5min.

#### Telemetry checkpoint

- ≥7 days data per gate (2026-05-14 → 2026-05-20 inclusive)
- Zero false positives across all advisory gates
- Skip reasons all documented

### T7.9.1 — Per-gate promotion (2026-05-21)

Decision matrix:

| Sub-task | Gate | Action |
|---|---|---|
| **T7.9.1.1** | `BRANCH_ISOLATION_VIOLATION` Mode B | Flip enforced if T7.9.0 criteria met |
| **T7.9.1.2** | `BRANCH_ISOLATION_VIOLATION` Mode C | Flip enforced if T7.9.0 criteria met |
| **T7.9.1.3** | `FEATURE_CLOSURE_COMPLETENESS` | Flip enforced if T7.9.0 criteria met |
| **T7.9.1.4** | Mechanism A coverage gates | Flip enforced (data already sufficient) |
| **T7.9.1.5** | Mechanism C session-attribution | Flip enforced (data already sufficient) |
| **T7.9.1.6** | `BRANCH_ISOLATION_HISTORICAL` cycle-time | **Stays advisory** (forward-only audit by design) |
| **T7.9.1.7** | `BRANCH_ISOLATION_LAUNCHD_DRIFT` cycle-time | **Stays advisory** (macOS-only) |
| **T7.9.1.8** | `FEATURE_CLOSURE_COMPLETENESS` cycle-time mirror | **Stays advisory** (catches `--no-verify` bypass) |

Implementation: per gate, edit the advisory flag in `scripts/check-state-schema.py` AND `.githooks/pre-commit` header. Single commit per gate enables granular rollback.

### T7.9.2 — Side-effect updates

#### Sub-tasks

- [ ] **T7.9.2.1** Update `CLAUDE.md` Known Mechanical Limits — drop 5 advisory bullets, add 5 enforced gate IDs to the appropriate sections.
- [ ] **T7.9.2.2** Create `.claude/entrypoints/framework-v7-9.md` cold-start entrypoint mirroring `framework-v7-8-3.md` shape.
- [ ] **T7.9.2.3** Update [`docs/architecture/dev-guide-v1-to-v7-7.md`](../../architecture/dev-guide-v1-to-v7-7.md) §2.4 — add "promoted" sub-section under v7.8 bridge.
- [ ] **T7.9.2.4** Append new entry FT2-FH-002 to honesty ledger documenting any deferred-promotion rationale.
- [ ] **T7.9.2.5** Create Linear epic FIT-72 `v7.9-promotion` with sub-issues per flipped gate.
- [ ] **T7.9.2.6** Update `.claude/shared/framework-manifest.json` — v7.8.4 → v7.9.

### T7.9.3 — Closure case study

- [ ] **T7.9.3.1** Write `docs/case-studies/framework-v7-9-promotion-case-study.md` — Section 99 captures the per-gate decision rationale + T29 v8.0 docket ranking output.
- [ ] **T7.9.3.2** Write `fitme-story/content/04-case-studies/31-framework-v7-9-promotion.mdx` (showcase MDX slot 31).
- [ ] **T7.9.3.3** Update CLAUDE.md "Data Integrity Framework" section header to include v7.9.

### T7.9.4 — Post-promotion validation (Phase E, 2026-05-21 → 06-04)

- [ ] **T7.9.4.1** Monitor `gate-coverage.jsonl` daily for unexpected `failure` rows.
- [ ] **T7.9.4.2** Manual operator review of every pre-commit hook rejection in first 7 days post-flip.
- [ ] **T7.9.4.3** If false positive → invoke rollback (single-commit revert). Document in honesty ledger as FT2-FH-003.
- [ ] **T7.9.4.4** At T+7d (~2026-05-28): publish T7.9.4 validation report at `docs/case-studies/meta-analysis/v7-9-post-promotion-validation-2026-05-28.md`.

### New tests (0)

v7.9 ships no new tests — enforcement-only release. Existing test coverage from v7.8.1 + v7.8.3 covers the flipped gates.

### Telemetry checkpoint for advancing to v7.9.1

- v7.9 in Phase E (post-promotion validation complete, 0 false-positive incidents)
- Earliest v7.9.1 build start: 2026-06-04

---

## §5 v7.9.1 — Test Discipline Foundation + Low-Effort Wins (2026-06-04 → 06-11)

### Goal

Ship the foundation layer for Theme G test discipline (F16) + telemetry materialization (F17) + low-effort workflow improvements (F2, F6). No new gates ship — all items are non-gate-additive or read-only.

### T7.9.1.1 — F16: pre-commit try-repo end-to-end harness (foundation; HIGHEST-LEVERAGE)

#### Files

- New: `tests/integration/test_precommit_endtoend.py`
- New: `tests/fixtures/gate-fixtures/<gate-id>/{positive,negative}/` directory tree (~14 gates × 2 = 28 fixture sets)
- New: `tests/integration/harness/precommit_runner.py` — helper for spawning throwaway git repos

#### Sub-tasks

- [ ] **T7.9.1.1.1 Design harness API** — function signature `run_precommit_against_fixture(gate_id, fixture_set) → (exit_code, stdout, stderr, ledger_entries)`.
- [ ] **T7.9.1.1.2 Implement `spawn_throwaway_repo(base_state=None)`** — uses `tempfile.mkdtemp()` + `git init` + `cp` of `.githooks/pre-commit` + `cp` of relevant scripts. Returns repo path.
- [ ] **T7.9.1.1.3 Author fixture pairs** for each of 14 currently-implemented gates. Each gate gets:
  - `positive/staged-files/*` — files that should trigger the gate
  - `positive/expected-output.txt` — expected gate fire output
  - `negative/staged-files/*` — files that should NOT trigger the gate
  - `negative/expected-output.txt` — expected silent skip
- [ ] **T7.9.1.1.4 Implement subprocess invocation** — stages fixtures via `git add`, runs `.githooks/pre-commit` via subprocess, captures stdout/stderr/exit-code/ledger.
- [ ] **T7.9.1.1.5 Add to CI nightly** — new `.github/workflows/precommit-endtoend-nightly.yml`. Cron 03:00 UTC. Fails on any unexpected fire/skip mismatch.
- [ ] **T7.9.1.1.6 Calibrate Phase B** — ship in advisory mode (logs results but doesn't fail CI). 7 days observation.
- [ ] **T7.9.1.1.7 Promote Phase C → D → E** — flip to enforced after 7-day clean run.

#### New tests

- 14 gate × 2 fixture sets = ~28 integration test cases via `pytest.mark.parametrize`.
- 5 helper-level unit tests (spawn_throwaway_repo, fixture loader, output parser, etc.).

#### Telemetry checkpoint

- Phase B: nightly run completes in <60s OR is scoped further. ≥5 clean runs out of 7 nights.
- Phase E exit (target ~2026-06-11): 0 unexpected fixture-mismatches in 7d.

#### Calibration gate (Phase D)

- 14/14 gate-fixture pairs produce expected outcomes
- Nightly job p95 runtime <60s
- Reversibility rehearsed: `mv .github/workflows/precommit-endtoend-nightly.yml{,.disabled}` rollback path

### T7.9.1.2 — F17: per-gate `last_fired_at` materialized index

#### Files

- New: `scripts/refresh-gate-last-fired.py`
- New: `.claude/shared/gate-last-fired.json` (generated, gitignored or committed-snapshot — TBD)
- New: `tests/framework/test_refresh_gate_last_fired.py`
- New: `.github/workflows/refresh-gate-last-fired-nightly.yml`

#### Sub-tasks

- [ ] **T7.9.1.2.1 Design index schema:**

  ```json
  {
    "generated_at": "ISO 8601",
    "source_ledger_sha256": "...",
    "gates": {
      "GATE_NAME": {
        "last_fired_at": "ISO 8601 or null",
        "last_skipped_at": "ISO 8601 or null",
        "fire_count_30d": 0,
        "skip_count_30d": 0,
        "last_skip_reason": "..."
      }
    }
  }
  ```

- [ ] **T7.9.1.2.2 Implement** `scripts/refresh-gate-last-fired.py` — read full `gate-coverage.jsonl`, fold into per-gate dict, write derived index.
- [ ] **T7.9.1.2.3 Add unit tests** (5 tests): correct aggregation, handles empty ledger, handles malformed lines, 30d window filter, idempotent re-run.
- [ ] **T7.9.1.2.4 Add nightly cron workflow** — generates fresh index every 24h.
- [ ] **T7.9.1.2.5 Document downstream consumer** — the planned `GATE_COVERAGE_ZERO` meta-check (v8.0 candidate per F17 spec) reads from this index, not from raw `gate-coverage.jsonl`.

#### New tests

- 5 unit tests in `test_refresh_gate_last_fired.py`.

#### Telemetry checkpoint

- Index regenerates correctly nightly (verifiable via timestamp + sha256 of source).
- For every gate in CLAUDE.md inventory, `last_fired_at OR last_skipped_at` is non-null. (Any all-null gate is a silent-pass suspect.)

#### Calibration gate (Phase D)

- Index correctly identifies the 4 gates that have never emitted in the last 30 days (if any) — those are the candidates for v8.0 `GATE_COVERAGE_ZERO` enforcement.
- Read-only derived artifact — Phase D risk is low. Reversibility: delete index file + disable cron workflow.

### T7.9.1.3 — F2: Phase 0 reality-check sub-step

#### Files

- Modified: `.claude/skills/pm-workflow/SKILL.md` — add sub-step under Phase 0 (Research).
- Modified: `.claude/skills/pm-workflow/SUBSKILL-phase-0-reality-check.md` — new sub-skill content.

#### Sub-tasks

- [ ] **T7.9.1.3.1 Author sub-skill** — checklist: for every sub-feature referenced in research input, verify (a) state.json says `current_phase: complete` OR (b) PR shipped that matches the sub-feature OR (c) filesystem evidence (e.g., `FitTracker/Views/<Screen>.swift` exists for a view-claim).
- [ ] **T7.9.1.3.2 Add invocation point** in pm-workflow Phase 0 prompt.
- [ ] **T7.9.1.3.3 Test on a real Phase 0 invocation** — run against a meta-feature with 5+ sub-features.

#### New tests

None (workflow-only change; tested via dogfood).

#### Telemetry

Not gate-instrumented. Dogfood validates.

### T7.9.1.4 — F6: B_medium tier doc

#### Files

- Modified: `CLAUDE.md` — "Work Item Types" section.

#### Sub-tasks

- [ ] **T7.9.1.4.1 Add B_medium tier definition** — "For features where research.md adequately covers PRD/tasks/UX scope, the corresponding state.json phases may be marked `status: skipped` with `reason: 'B_medium: research-only scope'`. Documents the existing latitude formally."
- [ ] **T7.9.1.4.2 Verify** existing skipped features (e.g., chores, fixes) match the documented vocabulary.

#### New tests

- New regression test in `scripts/tests/test_check_state_schema.py`: `test_b_medium_skipped_phase_accepts_documented_reason`.

#### Telemetry

Not gate-instrumented.

### T7.9.1.5 — Investigate v7.8.6 fixture-rot follow-up

#### Sub-tasks

- [ ] **T7.9.1.5.1** Triage the 3 `test_check_state_schema.py::test_*` failures (STATE_OWNER_MISSING fixture-rot from v7.8.3 ship) + 1 `test_validate_tier_tags.py::test_t1_claim_without_ledger_evidence_warns` (intentional v7.8.4 behavior change).
- [ ] **T7.9.1.5.2** Decision: bundle into v7.9.1 OR defer to v8.0 OR ship as separate v7.8.6 patch?
- [ ] **T7.9.1.5.3** Fix per decision.

### v7.9.1 ship checklist (entry to Phase E)

- [ ] F16 in Phase E (post-promotion validation 7d clean)
- [ ] F17 in Phase E
- [ ] F2 dogfooded on ≥1 real Phase 0 invocation
- [ ] F6 documented + 1 regression test passes
- [ ] v7.8.6 fixture-rot remediated (or formally deferred)

### Telemetry checkpoint for advancing to v8.0

- F16 + F17 in Phase E → unblocks F14 + F18 + GATE_COVERAGE_ZERO meta-check in v8.0.
- Earliest v8.0 build start: 2026-06-18.

---

## §6 v8.0 — Top-Per-Theme Docket (2026-06-18 → 07-31)

### Goal

Build top items per theme as selected by 2026-05-21 ranking pass. Provisional v8.0 docket (decided 2026-05-21):

| Theme | Item | RICE | Effort |
|---|---|---|---|
| A — Roadmap | F1 `STATE_TASKS_FILESYSTEM_DRIFT` | 19.2 | 0.5w |
| C — Schema | F4 `framework_version` auto-update | 32.0 | 0.5w |
| C — Schema | F10 `experiment_outcome` enum | 32.0 | 0.3w |
| F — v7.8.3 cutover | F11 `BRANCH_ISOLATION_HISTORICAL` allowlist | 40.0 | 0.3w |
| G — Test discipline | F14 per-gate dispatch tests | 48.0 | 0.5w |
| G — Test discipline | F15 zero-coverage gate unit tests | 40.0 | 0.5w |

Each walks full Phase A → E.

### T8.0.1 — F1: STATE_TASKS_FILESYSTEM_DRIFT cycle-time advisory

#### Files

- Modified: `scripts/integrity-check.py` — add `check_state_tasks_filesystem_drift` predicate.
- New: `scripts/tests/test_state_tasks_filesystem_drift.py` (~8 tests).
- New: `tests/fixtures/gate-fixtures/STATE_TASKS_FILESYSTEM_DRIFT/{positive,negative}/`.

#### Sub-tasks

- [ ] **T8.0.1.1 Specify Phase A** — gate function `check_state_tasks_filesystem_drift(state, repo_root)`. Emission key `STATE_TASKS_FILESYSTEM_DRIFT`. Skip reasons: `tasks_present`, `no_filesystem_evidence_check_available`, `pre_v7_6_grandfathered`.
- [ ] **T8.0.1.2 Implement** the predicate:
  - For features with `state.json::tasks: []` AND `current_phase: complete`, scan filesystem for evidence of tasks (e.g., `tasks.md` line items vs filesystem artifacts).
  - For each "feature class" (UI feature → views; framework feature → scripts; doc feature → markdown), use per-class probe logic.
- [ ] **T8.0.1.3 Author fixtures**:
  - Positive: state.json claiming `tasks: []` + complete phase + actual filesystem artifacts → fires advisory.
  - Negative: state.json with populated tasks → silent skip with `tasks_present`.
  - Pre-v7.6 feature: should grandfather skip with `pre_v7_6_grandfathered`.
- [ ] **T8.0.1.4 Wire into F16 try-repo harness** — add `STATE_TASKS_FILESYSTEM_DRIFT/{positive,negative}/` fixture sets.
- [ ] **T8.0.1.5 Wire into F14 per-gate dispatch test** — add `test_main_dispatch_state_tasks_filesystem_drift`.
- [ ] **T8.0.1.6 Phase B advisory ship** — 7 days observation.
- [ ] **T8.0.1.7 Phase C calibration** — 5+ fires across ≥3 real features, 0 false positives.
- [ ] **T8.0.1.8 Phase D promotion decision** — advisory in v8.0, planned enforced in v8.0.1 patch after additional calibration.
- [ ] **T8.0.1.9 Phase E validation** — 7d post-promotion clean.

#### New tests

- 8 unit tests in `test_state_tasks_filesystem_drift.py` (per skip reason + per feature class)
- 1 F14 dispatch test
- 2 F16 fixture pairs

#### Telemetry checkpoint

- Phase B: ≥3 features flagged advisory (the 5 pre-v7.6 features known to have drift)
- Phase C: 0 false positives on already-shipped features

#### Calibration gate (Phase D)

- All 5 known-drift features flagged (recall = 100%)
- Zero false positives across remaining 64 features (precision = 100%)

### T8.0.2 — F4: framework_version auto-update

#### Files

- Modified: `scripts/check-state-schema.py` — add `check_framework_version_stale` write-time gate.
- New: `scripts/migrate-framework-version.py` — one-shot batch migrate script.
- New: `scripts/tests/test_framework_version_stale.py` (~6 tests).

#### Sub-tasks

- [ ] **T8.0.2.1 Specify Phase A** — gate function. Skip reasons: `version_current`, `pre_v7_6_grandfathered`.
- [ ] **T8.0.2.2 Implement** — gate fires when any state.json mutation occurs on a state.json with `framework_version` older than the project's current `framework-manifest.json::current_version`.
- [ ] **T8.0.2.3 Implement migration script** — `scripts/migrate-framework-version.py --bulk` runs once to backfill all 9 pre-v7.6 features.
- [ ] **T8.0.2.4 Author 6 tests** (positive, negative, edge cases).
- [ ] **T8.0.2.5 Author F14 dispatch test** + F16 fixture pairs.
- [ ] **T8.0.2.6 Phase B–E walk.**

#### New tests

- 6 unit + 1 F14 dispatch + 2 F16 fixtures + 1 migration-script test.

#### Telemetry checkpoint

- Phase B: gate fires on 9 known pre-v7.6 features (post-migration: 0 fires, all current).
- Phase C: 0 false-positive fires on current-version features.

### T8.0.3 — F10: experiment_outcome enum on tasks[]

#### Files

- Modified: `scripts/check-state-schema.py` — extend `check_task_lie` to accept `experiment_outcome: cancelled_hypothesis_refuted` etc. as satisfying the gate.
- Modified: schema docs in CLAUDE.md.
- New: `scripts/tests/test_experiment_outcome_satisfies_task_lie.py` (~5 tests).

#### Sub-tasks

- [ ] **T8.0.3.1 Specify Phase A** — enum values: `shipped`, `deferred_session_capacity`, `deferred_external_blocker`, `cancelled_hypothesis_refuted`, `cancelled_scope_change`, `superseded`.
- [ ] **T8.0.3.2 Implement** — `check_task_lie` accepts `experiment_outcome` as proof that a task didn't ship but isn't a lie.
- [ ] **T8.0.3.3 5 tests** per enum value × positive/negative.
- [ ] **T8.0.3.4 F14 dispatch test** + F16 fixtures.
- [ ] **T8.0.3.5 Phase B–E walk.**

#### New tests

- 5 unit + 1 F14 dispatch + 2 F16 fixtures.

#### Telemetry checkpoint

- ≥1 feature uses each enum value in real PR flow (dogfood).

### T8.0.4 — F11: BRANCH_ISOLATION_HISTORICAL allowlist

#### Files

- Modified: `scripts/integrity-check.py` — extend `BRANCH_ISOLATION_HISTORICAL` regex allowlist.

#### Sub-tasks

- [ ] **T8.0.4.1 Add `reverse-sync/*` to allowlist** — branches starting with `reverse-sync/from-fitme-story/` are legitimate D-1 sync mirrors.
- [ ] **T8.0.4.2 Alternative consideration:** morph to read `state_owner_sync_origin` field instead of relying on branch-name pattern. Evaluate which is more robust.
- [ ] **T8.0.4.3 Author 4 tests** — `reverse-sync/*` exempts, `feature/*` exempts, `chore/*` exempts, direct-on-main still fires.
- [ ] **T8.0.4.4 Phase B–E walk** (cycle-time gate; Phase B = next 72h cycle run).

#### New tests

- 4 unit tests.

#### Telemetry checkpoint

- Phase B: the 3 known false-positive advisories (3d-interactive-framework-flow-diagram + cross-repo-state-sync-impl + hadf-phase2bis-replication) clear next cycle.

### T8.0.5 — F14: per-gate dispatch tests (depends on F16 in Phase E)

#### Files

- Modified: `scripts/tests/test_check_state_schema.py` — 4 new `test_main_dispatch_*` tests.
- Modified: `scripts/tests/test_check_case_study_preflight.py` — 1 new `test_main_dispatch_*` test.
- Modified: `scripts/pre-commit-self-test.py` — extend to assert every declared gate has a corresponding dispatch test.

#### Sub-tasks

- [ ] **T8.0.5.1 Author dispatch tests** for the 4 Class A gates:
  - `test_main_dispatch_cache_hits_auto_instrumentation_drift`
  - `test_main_dispatch_cu_v2_invalid`
  - `test_main_dispatch_state_no_case_study_link`
  - `test_main_dispatch_case_study_missing_fields` (in test_check_case_study_preflight.py)
- [ ] **T8.0.5.2 Each test pattern:** monkeypatch `collect_staged_state_files`, `collect_all_staged_files`, `GATE_COVERAGE_LEDGER`, `sys.argv` → invoke `main()` → assert gate fires OR records candidate→skip.
- [ ] **T8.0.5.3 Extend pre-commit-self-test.py** — fail if `scripts/check-state-schema.py` defines a gate without a sibling `test_main_dispatch_<gate_id>` test.
- [ ] **T8.0.5.4 Audit other gates** for missing dispatch tests; add as needed (estimate: ~6 additional tests across STATE_OWNER_*, PR_NUMBER_UNRESOLVED, etc.).
- [ ] **T8.0.5.5 Phase B–E walk** (test-infrastructure, mostly observational).

#### New tests

- 4–10 dispatch tests (4 minimum for Class A; rest as audit reveals).
- Extension to pre-commit-self-test.py mechanism.

#### Telemetry checkpoint

- Phase B: pre-commit-self-test.py emits passing self-audit. Zero gates flagged as missing dispatch tests after T8.0.5.4.

### T8.0.6 — F15: zero-coverage gate unit tests

#### Files

- Modified: `scripts/tests/test_check_state_schema.py` — add tests for PHASE_TRANSITION_NO_LOG, PHASE_TRANSITION_NO_TIMING, PR_CACHE_STALE.
- Modified: `scripts/tests/test_integrity_check.py` (NEW file) — add tests for BRANCH_ISOLATION_HISTORICAL, BRANCH_ISOLATION_LAUNCHD_DRIFT.

#### Sub-tasks

- [ ] **T8.0.6.1 PHASE_TRANSITION_NO_LOG** (3 tests): valid transition with log, invalid transition without log, edge case (log entry older than 15min window).
- [ ] **T8.0.6.2 PHASE_TRANSITION_NO_TIMING** (3 tests): valid transition with timing, invalid without `ended_at`, invalid without new `started_at`.
- [ ] **T8.0.6.3 PR_CACHE_STALE** (2 tests): stale cache triggers auto-refresh, fresh cache no-op.
- [ ] **T8.0.6.4 BRANCH_ISOLATION_HISTORICAL** (3 tests): direct-on-main fires, `feature/*` exempts, `reverse-sync/*` exempts (post F11).
- [ ] **T8.0.6.5 BRANCH_ISOLATION_LAUNCHD_DRIFT** (2 tests): macOS-only conditional, plist-mismatch detection.

#### New tests

- 13 unit tests across the 5 previously-zero-coverage gates.

#### Telemetry checkpoint

- All 5 previously-zero-coverage gates emit to Mechanism A on their next invocation (verifiable via gate-coverage.jsonl post-test-run).

### v8.0 ship checklist

- [ ] F1 + F4 + F10 + F11 + F14 + F15 all in Phase E
- [ ] F16 has been in Phase E for ≥21 days (F14 + F18 dependencies cleared)
- [ ] Case study `docs/case-studies/framework-v8-0-case-study.md` written
- [ ] Showcase MDX slot 32 in fitme-story
- [ ] CLAUDE.md updated with v8.0 mechanism inventory
- [ ] Cold-start entrypoint `.claude/entrypoints/framework-v8-0.md`
- [ ] Linear epic FIT-73 closed

### Telemetry checkpoint for advancing to v8.1

- v8.0 in Phase E (~2026-08-21)
- Mechanism A `last_fired_at` index shows all v8.0 gates emitting cleanly
- Earliest v8.1 build start: 2026-08-31

---

## §7 v8.1 — Deferred F-items + First V8-I Triggers (2026-08 → 09)

### Goal

Ship the F-items deferred from v8.0 + any V8-I icebox item whose re-eval trigger fired.

### Deferred F-items eligible for v8.1

- **F3** — Phase 2 dependency-graph cycle/mismatch check
- **F5** — `scope_change` event in Tier 2.2 vocabulary
- **F9** — `make complete-feature` pre-flight OR gate-batch mode
- **F12** — actionlint pre-commit gate
- **F13** — workflow_dispatch source_commit input
- **F18** — mutation testing nightly (depends on F14 + F16 in Phase E)

### V8-I triggers expected by 2026-08-31

#### Likely to fire

- **V8-I1** Agent Smartlog UI — trigger ≥5 concurrent active features for 7+ days. Phase 2-bis + Track 6 + v8.0 builds may push count to threshold.
- **V8-I2** Op-log Replay — trigger ≥3 manual-cleanup incidents in 90d OR `git stash list` >5 for 30d.

#### Likely NOT to fire

- V8-I3, V8-I4, V8-I5, V8-I6, V8-I7 — defer to v8.2+.

### T8.1.X — Per-item tasks

Each F/V8-I item follows the same task structure pattern as v8.0:

1. **Phase A: Specify** — gate spec + fixtures + dispatch test (5 sub-tasks each).
2. **Implement** the predicate (1–3 sub-tasks).
3. **Author unit tests** (3–8 tests per item).
4. **Phase B: Ship advisory** + measure 7d.
5. **Phase C: Calibration gate** (5+ fires, 0 false positives).
6. **Phase D: Promotion decision** (advisory → enforced flip OR stay advisory).
7. **Phase E: Validation** (7d post-promotion).

### v8.1 ship checklist

- [ ] 5–7 items in Phase E (count depends on which deferred F-items + V8-I triggers fire)
- [ ] Case study `docs/case-studies/framework-v8-1-case-study.md`
- [ ] Showcase MDX slot 33

### Telemetry checkpoint for advancing to v8.2

- v8.1 in Phase E (~2026-10-15)
- All v8.1 gates emitting cleanly via `last_fired_at` index
- Earliest v8.2 build start: 2026-12

---

## §8 v8.2+ — Long Tail (2026-12+)

### Goal

Ship the V8-I icebox items whose re-eval triggers haven't fired yet but have accumulated dogfood evidence.

### Likely scope

- **V8-I3** Vercel Sandbox / Firecracker — if untrusted-code use case emerges (Q4 2026 unlikely)
- **V8-I4** Kernel-Level Isolation — if regulatory mandate (Q4 2026 unlikely)
- **V8-I5** Path Watcher Daemon — if ≥2 concurrent-write incidents
- **V8-I6** Cross-Feature Dependency Graph — when `path-reducers.json` ≥20 entries
- **V8-I7** Auto-Rollback on Kill-Criteria — when T+7d telemetry of clean firing accumulates

### Note

v8.2 docket is intentionally NOT pre-committed. Per the Calibration Protocol (§3.5 of infra plan), each release writes its own docket only after the previous release stabilizes.

---

## §9 Test Inventory by Version (cumulative)

| Version | Tests added | Test files touched | Cumulative |
|---|---|---|---|
| v7.8.4 (baseline) | — | — | ~131 in `scripts/tests/` |
| v7.8.5 | 1 (regression) | 1 (test_gate_coverage.py) | ~132 |
| v7.9 | 0 (enforcement only) | 0 | ~132 |
| v7.9.1 | F16: ~28 + F17: 5 + F6: 1 = **34** | 4 (test_precommit_endtoend, test_refresh_gate_last_fired, harness, check_state_schema regression) | ~166 |
| v8.0 | F1: 8 + F4: 7 + F10: 6 + F11: 4 + F14: ~10 + F15: 13 = **48** | 6+ | ~214 |
| v8.1 | F3: ~6 + F5: 3 + F9: 5 + F12: 4 + F13: 5 + F18: ~10 + V8-Is: ~15 = **~48** | 8+ | ~262 |
| v8.2 | TBD per scope | TBD | ~300+ |

**Test growth pattern:** roughly doubles between v7.8.4 (131) and v8.1 (262) over 4 months — driven primarily by F16's fixture corpus (~28) and v8.0's 6 new gates (~48).

---

## §10 Telemetry & Calibration Gates Per Version

### Per-version data collection requirements

| Version | Required data | Source | Decision gate |
|---|---|---|---|
| **v7.8.5** | 5 canonical-key emissions in last 7d | `gate-coverage.jsonl` | Verified 2026-05-12 (SHIPPED PR #320) |
| **v7.9** | 7d × 5 advisory gates · 0 false positives · skip reasons documented | `gate-coverage.jsonl` 2026-05-14 → 20 | 2026-05-21 promotion decision per gate |
| **v7.9.1** | F16 14 gates × 2 fixtures clean nightly · F17 index regenerates · F2 dogfood validates · F6 1 regression test | F16 CI workflow + F17 index file | Per-item Phase D (each walks own gate) |
| **v8.0** | Per-gate 7d advisory · 5+ fires · 0 FPs · F14 dispatch coverage 100% | `gate-coverage.jsonl` + F17 index | Per-gate Phase D |
| **v8.1** | Same per-gate pattern · V8-I triggers verified | Same | Same |
| **v8.2** | TBD per items shipped | TBD | TBD |

### Quarterly Data Freshness Audit checkpoints

Independent of version cadence:

- **2026-08-12** — Audit #1 — assert v7.9 + v7.9.1 gates' emission keys ↔ function names ↔ test names parity
- **2026-11-12** — Audit #2 — v8.0 added
- **2027-02-12** — Audit #3 — v8.1 added
- **2027-05-12** — Audit #4 — full year retrospective

Each audit produces `docs/case-studies/meta-analysis/data-freshness-audit-<date>.md`.

---

## §11 Cross-Cutting Risks (per version)

| Risk | Affects | Mitigation |
|---|---|---|
| Phase A artifact rot (spec/fixture/test out of sync) | All versions | Open Q7 in infra plan §8: mechanical gate `GATE_SPEC_INCOMPLETE` OR PR-review checklist. Decide 2026-06-04. |
| Calibration window slippage (telemetry doesn't accumulate fast enough) | v7.9, v7.9.1, v8.0 | Phase B minimum is 7 days; can extend if data sparse. Stay advisory rather than rush promotion. |
| Mutation testing CI cost overrun (F18) | v8.1+ | Phase B calibration measures wall-time. If >15min/run, scope further or defer. |
| F16 fixture rot (gates added without paired fixtures) | v8.0+ | T8.0.5.3 extends `pre-commit-self-test.py` to assert fixture-pair existence. |
| Layer-stacking-rule violation (new layer built on non-Phase-E layer) | All versions | §3.5.2 of infra plan codifies the rule. Project-wide review at each Phase D. |
| DevSSD hardware fail during a calibration window | v7.9, 2026-05-21 specifically | Pre-window backup + `pmset disksleep 0`; documented in [SanDisk remediation memory](~/.claude/projects/-Volumes-DevSSD-FitTracker2/memory/project_devssd_disconnect_remediation_2026_05_02.md). |
| HADF Phase 2-bis runs during v7.9 promotion window | 2026-05-23 → 06-04 | HADF Sub-exp 1 is operator-driven (no agent dispatch interference). |
| Cross-repo asymmetry surfaces a new edge case | v8.0+ | F7/F8 documented exemption (annual re-eval 2027-05-08). |

---

## §12 Rollback Playbook (per version)

### v7.8.5 (test-fixture fix)

- **Trigger:** new test failure introduced unexpectedly
- **Action:** `git revert <commit-sha>` of PR #320 squash commit
- **Time:** <2 min

### v7.9 (gate enforcement flips)

- **Trigger:** false-positive incident on a flipped gate within first 7d
- **Action:** per-gate single-line edit (advisory flag flip back + hook header `enforced` → `advisory`). Each gate has its own commit during T7.9.1.* so per-gate rollback is granular.
- **Time:** <5 min per gate

### v7.9.1 (test infrastructure)

- **F16 rollback:** `mv .github/workflows/precommit-endtoend-nightly.yml{,.disabled}` + revert test file
- **F17 rollback:** disable nightly cron + delete index file
- **F2 rollback:** revert SKILL.md edit
- **F6 rollback:** revert CLAUDE.md edit
- **Time:** <2 min for F2/F6; <10 min for F16/F17

### v8.0 (new gates)

- **Per-gate rollback:** revert the PR that added the gate. Mechanism A coverage data for that gate from advisory window remains in `gate-coverage.jsonl` (append-only).
- **Time:** <10 min

### v8.1 (mixed)

Same pattern as v8.0 per-item.

---

## §13 References

### Source documents

- [Infra master plan](../../master-plan/infra-master-plan-2026-05-12.md) — §3.5 Calibration Protocol + §3.6 Forward Plan (high-level)
- [v7.9 candidates spec](../specs/2026-05-08-framework-v7-9-candidates.md) — F1–F18 detail
- [Branch-isolation out-of-scope](../specs/2026-05-07-branch-isolation-out-of-scope.md) — V8-I1–V8-I7 detail
- [Cross-repo gate asymmetry](../specs/2026-05-08-cross-repo-gate-asymmetry.md) — F7/F8 RESOLVED status

### Live state

- [`.claude/logs/gate-coverage.jsonl`](../../../.claude/logs/gate-coverage.jsonl) — Mechanism A telemetry
- [`.claude/shared/measurement-adoption-history.json`](../../../.claude/shared/measurement-adoption-history.json) — Tier 1.1
- [`.claude/shared/documentation-debt.json`](../../../.claude/shared/documentation-debt.json) — Tier 3.2
- [`scripts/check-state-schema.py`](../../../scripts/check-state-schema.py) — write-time gates
- [`scripts/integrity-check.py`](../../../scripts/integrity-check.py) — cycle-time gates
- [`.githooks/pre-commit`](../../../.githooks/pre-commit) — hook dispatcher

### Companion PRs shipped 2026-05-12

- [PR #316](https://github.com/Regevba/FitTracker2/pull/316) — HADF Phase 2-bis Block A (MERGED)
- [PR #317](https://github.com/Regevba/FitTracker2/pull/317) — `BRANCH_ISOLATION_VIOLATION` Mode B silent-pass fix (MERGED)
- [PR #318](https://github.com/Regevba/FitTracker2/pull/318) — v7.9 candidates F14–F18 added (OPEN)
- [PR #319](https://github.com/Regevba/FitTracker2/pull/319) — Infra master plan §3.5 + §3.6 consolidation (OPEN)
- [PR #320](https://github.com/Regevba/FitTracker2/pull/320) — v7.8.5 cache_hits fixture fix (OPEN)

---

## §15 Product-Framework Concurrency Layer

**Core principle:** framework gates need to calibrate against **real product commits**, not just synthetic fixtures. Each version's calibration window must coincide with concurrent iOS + web product work that exercises the gates under realistic load. Each version closes with an **independent external audit** that validates the calibration data was real, not contrived.

### §15.0 Why this matters

The PR #317 silent-pass bug went undetected for 5+ days because the only "fires" of `BRANCH_ISOLATION_VIOLATION` Mode B came from synthetic test runs — there were no real product commits during the bug's window that would have surfaced the failure organically. The Calibration Protocol (§2) closes this with the layer-stacking rule, but the rule only works if real product work passes through the gates between Phases B and E.

**Without product concurrency, calibration data is theoretical.** With it, every gate sees the actual mix of staged-file patterns, branch states, and case-study formats that production commits produce.

### §15.1 Cross-version product work map (iOS + web)

#### iOS work in flight or queued per [backlog.md](../../product/backlog.md)

| Item | Status | Likely concurrent version | Gates exercised |
|---|---|---|---|
| HADF Phase 2-bis Block A | SHIPPED 2026-05-12 (PR #316) | v7.8.4 → v7.8.5 | BRANCH_ISOLATION_VIOLATION, FEATURE_CLOSURE_COMPLETENESS, CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT, STATE_OWNER_* (× 15 commits) |
| HADF Phase 2-bis Sub-exp 1 | gated 2026-05-23 | v7.9 calibration window | All v7.6+ write-time gates on Sub-exp closure commits |
| HADF Phase 2-bis Sub-exp 2 + 3 | sequenced through ~2026-06-03 | v7.9 → v7.9.1 transition | Same; plus Mechanism C session attribution |
| HADF Phase 2-bis closure case study | ~2026-06-07 | v7.9.1 calibration window | FEATURE_CLOSURE_COMPLETENESS (Q6 PR parity + Q7 kill_criteria_resolution) + BROKEN_PR_CITATION |
| UCC passkey cutover (flip `UCC_AUTH_MODE` basic → passkey) | operator-gated | v7.9 OR v7.9.1 | None directly (operator env var flip) — no commits |
| Sentry Error Tracking Integration | high priority, no MCP wired yet | v7.9.1 OR v8.0 | FEATURE_CLOSURE_COMPLETENESS on closure commit; CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT throughout |
| App icon + App Store assets (app-store-assets) | paused at Phase 5 | v7.9.1 (resume window) | All write-time gates on resume commit cluster |
| Readiness-Aware Training Alert (Smart Reminders v2 layer) | queued enhancement | v8.0 | All write-time gates × ~10 commits over a feature lifecycle |
| Smart Reminders ↔ Push v2 deep-link | queued enhancement | v8.0 | Same |
| Funnel Analysis Dashboards | queued | v8.0 | Light gate exercise (mostly dashboard config) |
| iOS UI test coverage expansion | deferred to env-flake resolution | v8.1+ | None directly until UI test infra unblocks |

#### Web work (fitme-story) in flight or queued

| Item | Status | Likely concurrent version | Gates exercised |
|---|---|---|---|
| 3d-interactive-framework-flow-diagram | research phase | v7.9 → v7.9.1 | Cross-repo state.json sync gates (STATE_OWNER_LOCATION_MISMATCH); reverse-sync workflow exercise |
| Site-wide search on fitme-story (Pagefind) | queued Feature | v7.9.1 OR v8.0 | None directly (fitme-story-side only — F7/F8 exemption per v7.8.2); cross-repo F11 BRANCH_ISOLATION_HISTORICAL allowlist if it lands |
| DS P2 deferred items completion | partial, 12 of 16 remaining | v7.9.1 → v8.0 | Light exercise via fitme-story state.json mutations |
| Apply web DS to /control-room/* | not priority | v8.1+ | Same |
| Complete Figma + architecture for both surfaces | queued Feature | v8.0+ | All write-time gates on closure commits |
| HADF Phase 2 external audit prep (replication pack) | queued Chore | v8.0+ | Light |

### §15.2 Per-version concurrency profile

Each version's table answers: **what real product commits exercise the framework gates during this version's calibration window, and at what volume?**

#### §15.2.1 v7.8.5 (SHIPPED 2026-05-12)

- **iOS work:** HADF Phase 2-bis Block A (15 commits ~5h window) provided the empirical evidence — A3–A11 commits hit infra-paths without state.json, exposing the PR #317 silent-pass that v7.8.5 fixed.
- **Web work:** None during this 2-hour patch window.
- **Calibration data sourced:** 5 canonical-key emissions in last 7d to `gate-coverage.jsonl`. Sufficient for the test-fixture verification.
- **Real-product gate exercise count:** 9 commits on `feat/hadf-phase2bis-impl` exercised the (post-fix) Mode B path. 0 false positives.

#### §15.2.2 v7.9 (decision 2026-05-21, calibration window 2026-05-14 → 20)

- **iOS concurrent work (high-volume):**
  - HADF Phase 2-bis Sub-exp 1 launch sequence (2026-05-22 → 26) — ~6–10 closure commits in the window. **Each Sub-exp closure exercises FEATURE_CLOSURE_COMPLETENESS Q6 (PR parity) + Q7 (kill_criteria_resolution required).** This is the highest-density real-world data for the 2026-05-21 decision.
  - UCC passkey cutover (operator-driven, no commits).
  - Possible: Sentry SDK wire-up if MCP becomes available — would land 1–3 commits with state.json transitions.
- **Web concurrent work (low-volume):**
  - 3d-interactive-framework-flow-diagram research progress — 1–3 commits via reverse-sync. **Exercises STATE_OWNER_LOCATION_MISMATCH + the F11 BRANCH_ISOLATION_HISTORICAL allowlist gap (still advisory in v7.9, becomes a gating concern in v8.0).**
- **Calibration data target:**
  - `BRANCH_ISOLATION_VIOLATION` Mode B: ≥5 fires (HADF closure commits + any infra work on framework-v7-9 branch)
  - `BRANCH_ISOLATION_VIOLATION` Mode C: ≥3 fires (phase transitions on HADF Phase 2-bis)
  - `FEATURE_CLOSURE_COMPLETENESS`: ≥3 fires (HADF closure attempts)
  - Mechanism A coverage gates: ≥5 emissions per gate (already MET as of 2026-05-12)
  - Mechanism C session-attribution: continuous (every Read tool invocation in any feature session)
- **External audit (see §15.3):** Audit #1 — **2026-05-22** (day after promotion decision)
- **Risk:** if HADF Phase 2-bis Sub-exp 1 is delayed past 2026-05-23, the calibration window loses its highest-density data source. Mitigation: Phase B can extend 7d → 14d if data sparse (still ships by 2026-06-04 next promotion window).

#### §15.2.3 v7.9.1 (2026-06-04 → 06-11)

- **iOS concurrent work:**
  - HADF Phase 2-bis Sub-exp 3 verdict + anchor-drift trip-wire (~2026-06-03) — closure commit cluster (3–5 commits).
  - HADF Phase 2-bis cross-sub-exp synthesis case study (~2026-06-07) — 1–2 commits including the synthesis MDX in fitme-story (cross-repo flow).
  - Sentry MCP integration if it unblocked — ~5–10 commits.
  - App Store assets resume if 2026-06 lands the App Store launch decision — ~10–20 commits over 1–2 weeks.
- **Web concurrent work:**
  - 3d-interactive-framework-flow-diagram implementation (likely Phase 4 by then) — 5–15 commits.
  - Site-wide search Pagefind start — 3–8 commits.
- **Calibration data sourced for v7.9.1 items:**
  - **F16 try-repo harness:** runs nightly; 7 nights × 14 gates × 2 fixtures = 196 test runs in the calibration window. Plus real-product commit exercises during the day.
  - **F17 last_fired_at index:** populated by every prior gate fire; the synthesis commit + cross-repo sync exercises validate the index's freshness logic.
  - **F2 reality-check sub-step:** dogfooded against any new Phase 0 invocation during the window (likely 2–3 invocations: a new app-store-assets resume + a new Sentry integration spec).
- **External audit:** Audit #2 — **2026-06-12** (post v7.9.1 Phase E exit)

#### §15.2.4 v8.0 (2026-06-18 → 07-31, 6 weeks)

- **iOS concurrent work (high-volume — likely the busiest period of the year):**
  - Readiness-Aware Training Alert enhancement (full lifecycle, ~15 commits over 1 week)
  - Smart Reminders ↔ Push v2 deep-link enhancement (~10 commits)
  - Sentry full wire-up + alert routing (~10 commits)
  - App Store launch sequence if approved (~30–50 commits including marketing assets)
  - Funnel Analysis Dashboards (~5–10 commits)
  - Possible iOS UI test re-expansion if env-flake unblocks (~10–20 commits)
- **Web concurrent work:**
  - fitme-story site-wide search Pagefind ship (~15–25 commits)
  - DS P2 deferred items completion (12 remaining; ~12–20 commits)
  - 3d-interactive-framework-flow-diagram closure (~5 commits)
- **Total expected commit volume during v8.0 window:** ~100–200 commits across both repos. **This is the highest-density real-world calibration data window of the year.**
- **Calibration data for v8.0 items:**
  - **F1 STATE_TASKS_FILESYSTEM_DRIFT:** advisory fire on app-store-assets resume + Sentry integration features that complete during the window
  - **F4 framework_version auto-update:** fires on every state.json mutation during the window; expect ≥50 fires
  - **F10 experiment_outcome enum:** dogfooded by any Sub-exp closure or research-track feature that closes during v8.0
  - **F11 BRANCH_ISOLATION_HISTORICAL allowlist:** verified by every reverse-sync workflow run (1–3 per week × 6 weeks = 6–18 reverse-sync events)
  - **F14 per-gate dispatch tests:** runs on every PR via pre-commit-self-test.py extension; expect 100% coverage assertion to pass on ≥100 PR builds
  - **F15 zero-coverage gate unit tests:** tested on every push to a feature branch
- **External audit:** Audit #3 — **2026-08-05** (post v8.0 Phase E exit)

#### §15.2.5 v8.1 (2026-08-31 → 09-30)

- **iOS concurrent work:** TBD; likely product feature work continues post App Store launch (post-launch metrics review features, CX feedback loops).
- **Web concurrent work:** /control-room UI enhancements; potentially apply web DS to /control-room/* if that surfaces priority.
- **Calibration data sourced:**
  - Deferred F-items (F3, F5, F9, F12, F13, F18) each exercise via real PR flow
  - V8-I items (Smartlog UI + Op-log Replay if triggers fired) get their first real exercises
- **External audit:** Audit #4 — **2026-10-08** (post v8.1 Phase E exit)

#### §15.2.6 v8.2+ (2026-12+)

- **Concurrent work:** Q4 2026 product roadmap TBD at v8.1 close.
- **Calibration data:** long-tail V8-I items get exercised by whatever Q4/Q1 product work generates.
- **External audit:** Audit #5 — TBD per v8.2 ship

### §15.3 External Audit Schedule + Format

#### §15.3.1 Audit cadence

| Audit # | Date | Reviews | Format |
|---|---|---|---|
| Audit #0 (baseline) | 2026-04-21 | Gemini 2.5 Pro — established the precedent | Full corpus review |
| **Audit #1** | **2026-05-22** | v7.9 promotion decision + 7d data window | Focused on promoted gates |
| **Audit #2** | **2026-06-12** | v7.9.1 ship — F16 + F17 + F2 + F6 calibration data | Focused on test-discipline track |
| **Audit #3** | **2026-08-05** | v8.0 ship — 6 new gates + all v8.0 product concurrency | Full v8.0 docket review |
| **Audit #4** | **2026-10-08** | v8.1 ship | Same pattern as #3 |
| Audit #5 | TBD | v8.2+ ship | Same |
| Quarterly Data Freshness Audits | 2026-08-12 / 11-12 / 2027-02-12 / 05-12 | Independent of version cadence; emission-key parity audit per §3.5.3 of infra plan | Automated + human review |

#### §15.3.2 What each external audit reviews

Audit invitation goes to an external operator (per Tier 3.3 [GitHub issue #142](https://github.com/Regevba/FitTracker2/issues/142)) OR an independent agent run with a different model (e.g., Gemini 2.5 Pro, GPT-5, etc.) to ensure independent review. The audit reviews:

1. **Calibration data honesty** — were the gate fires that informed the version's promotion decision actually triggered by real product commits, or were they synthetic (e.g., test runs of `make integrity-check` against the same corpus over and over)? Audit reads `gate-coverage.jsonl` and cross-references entries against `git log` for the calibration window — every `checked: 1` entry should correlate with a real commit's pre-commit hook run.
2. **False positive review** — independent walk of every `failure` row in the calibration window. Auditor flags any `failure` that lacks a corresponding legitimate violation in the staged diff.
3. **Skip reason audit** — every `skipped` row's reason should match a documented expected reason. Audit catches new "silent skip" reasons that snuck in.
4. **Meta-check coverage** — did `GATE_COVERAGE_ZERO` (post v8.0) correctly flag any gate with zero fires? Audit forces a known-broken gate (test-only) into the corpus and verifies the meta-check catches it within 24h.
5. **Case-study tier-tag accuracy** — every T1 claim in case studies shipped during the version must have ledger evidence. T1 numbers without `cache_hits[]` or `measurement-adoption.json` references get flagged.
6. **Cross-repo asymmetry** — verify F7/F8 RESOLVED status holds (no new gate work landed in fitme-story without a documented exemption update).
7. **Layer stacking rule compliance** — verify no v(N+1) item shipped before v(N) reached Phase E.
8. **Reversibility rehearsal validity** — Audit asks for the rehearsal log (when, who, time-to-rollback). Any rehearsal log marked "skipped" or "too risky to actually test" fails this criterion.

#### §15.3.3 Audit deliverable format

Each audit produces:

```
docs/case-studies/meta-analysis/audit-v<version>-<date>-<auditor>.md
```

With required sections:

1. **Auditor identity + independence claim** — model + run config OR human auditor + relationship to project
2. **Calibration data sample** — N commits sampled, telemetry vs git log cross-reference table
3. **Findings** — per criterion above; severity P0/P1/P2/P3
4. **Recommendations** — bullet list with concrete remediation
5. **Sign-off** — "audit passes for v<version>" OR "audit blocks v<version>" with reason

If an audit blocks a version, the project rolls back the promotion decision and re-enters Phase B for the failed criteria. This is the analog of v7.5's response to the Gemini audit (which spawned the entire Data Integrity Framework).

#### §15.3.4 Audit invitation channels

- **External operators** invited via [GitHub issue #142 Tier 3.3 invitation thread](https://github.com/Regevba/FitTracker2/issues/142) — open standing invitation
- **Independent agent runs:** project operator dispatches an audit agent with a different model (Gemini, GPT-5, Claude with different system prompt) and explicit instructions to be adversarial
- **Annual external partner review:** if a security-research partner wants to formally review, the replication-pack from HADF Phase 2 external audit prep (queued in [backlog.md](../../product/backlog.md)) becomes the model

### §15.4 Data Sourcing Contract Per Layer

Each new framework layer's calibration window must source ≥X% of its `checked` count from **distinct real product commits**, not from repeated test runs:

| Layer type | Minimum real-product checked fraction | Rationale |
|---|---|---|
| Write-time gate (pre-commit) | ≥80% | Pre-commit gates fire on every commit; synthetic runs should be a minority |
| Cycle-time gate (integrity-check) | ≥50% | Cycle-time gates run on the full corpus; the cron itself provides synthetic-equivalent runs |
| Mechanism (A/C/D/E/F) | ≥70% | Mechanisms are infrastructure; real exercise expected |
| Test infrastructure (F16, F18) | ≥90% | The whole point is real-product exercise |
| Telemetry materialization (F17, GATE_COVERAGE_ZERO) | ≥50% | Read-only derived; can be validated with any data |
| Workflow gate (F2, F3) | 100% real product flow | These only exist when triggered by Phase 0 / Phase 2 |
| Doc/vocabulary change (F5, F6) | N/A | No telemetry, dogfood only |

**Enforcement:** at each version's Phase D decision gate, the operator reviews `gate-coverage.jsonl` cross-referenced against `git log` to verify the fraction. If under threshold, Phase B extends until the threshold is met.

### §15.5 Integration with the Calibration Protocol

The product-concurrency layer adds a sixth phase **A.5 — Production Exposure Planning** between A and B:

```
Phase A    — Specify
Phase A.5  — Production Exposure Planning (NEW)
Phase B    — Ship advisory + measure
Phase C    — Calibration gate
Phase D    — Promotion decision
Phase E    — Post-promotion validation
```

#### Phase A.5 — Production Exposure Planning

Before Phase B, the operator answers:

- "Which queued product features will be in flight during the next 7-day Phase B window?"
- "Will those features generate ≥X% real-product gate fires?" (X from §15.4 table)
- "If not, can we extend Phase B by 7 days to capture more product work?"
- "If still insufficient, is this gate a candidate for synthetic-only calibration with an explicit honesty-ledger entry stating that limitation?"

Phase A.5 takes ~30min. Output: a brief written planning note appended to the gate spec.

### §15.6 Worked example: v7.9 Phase A.5 (retrospective)

Applied retroactively to the 5 v7.9 promotion candidates:

| Gate | Phase B window | Expected product source | Minimum fraction | Status as of 2026-05-12 |
|---|---|---|---|---|
| `BRANCH_ISOLATION_VIOLATION` Mode B | 2026-05-14 → 20 | HADF Phase 2-bis Block B Sub-exp 1 closure (2026-05-22 → 26) + Sub-exp 1 prereg lock | ≥80% | Window aligned; HADF expected to provide ~6 closure commits |
| `BRANCH_ISOLATION_VIOLATION` Mode C | 2026-05-14 → 20 | Same + any phase transitions on framework-v7-8-branch-isolation | ≥80% | Aligned |
| `FEATURE_CLOSURE_COMPLETENESS` | 2026-05-14 → 20 | HADF Sub-exp 1 closure case study + ucc-passkey-auth state.json post-cutover update | ≥80% | Aligned |
| Mechanism A coverage gates | already met | Continuous from all pre-commit runs | ≥70% | Met as of 2026-05-12 |
| Mechanism C session-attribution | already met | Continuous (every Read in any feature session) | ≥70% | Met as of 2026-05-12 |

**Conclusion:** v7.9 calibration data should be ≥80% real-product per the Sub-exp 1 alignment. The 2026-05-21 promotion decision can be made with confidence — the data isn't synthetic-heavy.

### §15.7 Per-version external audit budget

| Audit | Estimated effort | Form |
|---|---|---|
| **Audit #1 (v7.9)** | 2–4h human OR 1 independent-agent run | Focused — 5 gates × 4 criteria |
| **Audit #2 (v7.9.1)** | 4–8h | Test-discipline track is more complex; F16 fixture audit is deep |
| **Audit #3 (v8.0)** | 1–2 days | 6 new gates × extensive product concurrency |
| **Audit #4 (v8.1)** | 1 day | Smaller scope; deferred items |
| **Audit #5 (v8.2+)** | TBD | Per scope |

If a human auditor isn't available, project operator dispatches an independent-agent run with explicit "be adversarial, find any inconsistency" instructions.

---

## §14 What This Plan Is NOT

- **Not a PRD per version.** Each version spawns its own PRD at build start (PRDs require success metrics + kill criteria; this plan is task-level decomposition only).
- **Not a Linear epic specification.** Linear epics get created at version build start, not pre-committed here.
- **Not exhaustive.** New candidates may surface from dogfood between versions; the plan accommodates additions in v8.1+ via the deferred-item pattern.
- **Not date-rigid.** Dates are targets; calibration windows take precedence (no version ships before Phase E exit).
- **Not a CLAUDE.md replacement.** CLAUDE.md remains the source of truth for current shipped state; this plan is forward-looking only.
