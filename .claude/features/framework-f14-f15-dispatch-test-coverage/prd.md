# PRD — framework-f14-f15-dispatch-test-coverage

| Field | Value |
|---|---|
| **Feature** | framework-f14-f15-dispatch-test-coverage |
| **Display name** | Framework F14/F15 — dispatch-test coverage push |
| **Owner** | regevbarak |
| **Work type** | feature (`work_subtype: framework_feature`) |
| **Framework version** | v7.9 |
| **State owner** | ft2 |
| **Dispatch pattern** | serial |
| **has_ui** | false |
| **requires_analytics** | false |
| **Branch** | `feature/framework-f14-f15-dispatch-test-coverage` |
| **Worktree** | `/Volumes/DevSSD/FitTracker2-infra-dispatch-test-coverage` |
| **Predecessor** | `framework-v7-9-promotion` (shipped 2026-05-21 via PR #417) |
| **Target ship** | 2026-05-25 (3 days) |
| **PRD written** | 2026-05-22 |
| **Research basis** | [`research.md`](./research.md) |
| **Spec basis** | [`docs/superpowers/specs/2026-05-08-framework-v7-9-candidates.md`](../../../docs/superpowers/specs/2026-05-08-framework-v7-9-candidates.md) §§F14 + F15 |
| **Cadence source** | [`.claude/shared/must-have-cadence-followups.md`](../../../.claude/shared/must-have-cadence-followups.md) §C1 |

---

## 1. Problem

The framework's pre-commit hook orchestrator (`scripts/check-state-schema.py::main()`) dispatches 16 write-time gates. Today **only 1 of 16 has a `test_main_dispatch_<gate>()` end-to-end test** — `BRANCH_ISOLATION_VIOLATION` Mode B, added in PR #317 as the fix for a silent-pass bug. The other 15 gates have either thorough internal-function tests (4) or zero tests of any kind (5 write-time + the cycle-time + auxiliary scripts), all of which cannot, by construction, catch dispatcher-level bugs.

Empirical witness (last 4 weeks):
- **2026-04-30** — `CACHE_HITS_EMPTY_POST_V6` had 0% effective coverage because the gate read `created_at` while 43/46 state.json files used legacy `created`. Internal tests passed. Detected only via post-hoc audit weeks later.
- **2026-05-12** — `BRANCH_ISOLATION_VIOLATION` Mode B never ran on infra-only commits because `main()` early-returned at `if not files: return 0` before reaching the gate dispatch site. Caught only because the operator deliberately reproduced the failure. Closed by PR #317's 2 new dispatch tests.

Rate without intervention: ~1 silent-pass incident per 3 weeks. v7.9 already shipped (2026-05-21) WITHOUT this validation on the 9 gates in this feature's scope — a documented deferral trade-off per cadence-followups C1 to preserve the v7.9 calibration baseline.

This feature closes that gap by adding per-gate `test_main_dispatch_<gate>()` for 9 specific gates (4 F14 + 5 F15).

## 2. Scope

### In scope

9 gates × 1 `test_main_dispatch_<gate>()` each:

**F14 (4 gates, internal-only test today):**
1. `CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT` (renamed from `CACHE_HITS_EMPTY_POST_V6` at v7.8.3)
2. `CU_V2_INVALID`
3. `STATE_NO_CASE_STUDY_LINK`
4. `CASE_STUDY_MISSING_FIELDS`

**F15 (5 gates, zero coverage today):**
5. `PHASE_TRANSITION_NO_LOG` (v7.6 enforced)
6. `PHASE_TRANSITION_NO_TIMING` (v7.6 enforced)
7. `BRANCH_ISOLATION_HISTORICAL` (v7.8.1 cycle-time advisory)
8. `BRANCH_ISOLATION_LAUNCHD_DRIFT` (v7.8.1 cycle-time advisory)
9. `PR_CACHE_STALE` (v7.8.4 operability)

Each test must:
- (a) Invoke the corresponding `main()` end-to-end with monkey-patched IO helpers
- (b) Assert the gate either fires (rejection path) OR records a `candidates→checked/skipped` row in a tmp `gate-coverage.jsonl`
- (c) Pass the row schema check (`gate=`, non-zero `candidates`, skip-reason when applicable)

Companion deliverables:
- New shared fixtures helper: `scripts/tests/conftest.py` with `make_valid_state_json()`, `make_invalid_state_json()`, `tmp_gate_coverage_ledger()`
- New test file for cycle-time gates: `scripts/tests/test_integrity_check_dispatch.py` (gates #7, #8)
- New test file for PR cache freshness: `scripts/tests/test_ensure_pr_cache_fresh.py` (gate #9)
- F14 tests land in existing `scripts/tests/test_check_state_schema.py` (gates #1-#4)
- F15 phase-transition tests land in existing `scripts/tests/test_check_state_schema.py` (gates #5, #6)
- Backlog ticket opened for the `GATE_TEST_MISSING` meta-gate (test-coverage-master-plan T1, RICE 53.3)

### Out of scope

- **F16 try-repo end-to-end harness** — separate v7.9.1 candidate, sequenced AFTER this feature
- **F17 `last_fired_at` per-gate index** — separate v7.9.1 candidate
- **F18 mutation testing** — depends on F14 + F16, separate v8.0 candidate
- **T1 `GATE_TEST_MISSING` meta-gate** — separate test-coverage-plan candidate (RICE 53.3); ticket opened by this feature but implementation deferred
- **Refactor of `ensure-pr-cache-fresh.py` to emit gate-coverage via shared `dispatch.py`** — one-off test added in this feature; uniform-dispatch refactor deferred to v8.x
- **Backfill dispatch tests for the other 6 enforced gates** (`SCHEMA_DRIFT`, `PR_NUMBER_UNRESOLVED`, `BROKEN_PR_CITATION`, `CASE_STUDY_MISSING_TIER_TAGS`, `ISOLATION_OPT_OUT_REASON_MISSING`, `FEATURE_CLOSURE_COMPLETENESS`) — out of scope for this PRD; tracked in test-coverage-plan as separate work

## 3. Success metrics

### Primary metric (T1 — Instrumented)

**`framework_gate_dispatch_test_coverage_pct`** — count of declared gates with ≥1 `test_main_dispatch_<gate>` test ÷ total declared gates, split by surface.

| Surface | Baseline (2026-05-22) | Target (post-ship) | Source |
|---|---|---|---|
| Write-time gates (16 total) | **1/16 = 6%** (only `BRANCH_ISOLATION_VIOLATION` Mode B from PR #317) | **8/16 = 50%** (+ 7 from this feature: F14×4 + F15 phase-transitions×2 + PR_CACHE_STALE×1) | `scripts/tests/test_check_state_schema.py` + `scripts/tests/test_ensure_pr_cache_fresh.py` test inventory |
| Cycle-time advisory gates (3 total) | **0/3 = 0%** | **2/3 = 67%** (+ 2 from this feature: BRANCH_ISOLATION_HISTORICAL + LAUNCHD_DRIFT) | `scripts/tests/test_integrity_check_dispatch.py` test inventory |
| **Combined (19 total)** | **1/19 = 5%** | **10/19 = 53%** | both files above |

### Secondary metrics

| Metric | Tier | Baseline | Target |
|---|---|---|---|
| `silent_pass_incidents_per_quarter` | T1 — Instrumented (via honesty-ledger entries) | 2 in Q2 2026 (`cache_hits` keying + Mode B early-return) | ≤ 0.5/quarter rolling avg by Q4 2026 |
| `test_main_dispatch_test_runtime_seconds_p95` | T1 — Instrumented (CI timing) | n/a | ≤ 500ms per test; ≤ 5s total for the 9 |
| `gate_coverage_ledger_emission_per_test` | T1 — Instrumented (test assertion) | n/a | 9/9 tests emit ≥1 candidate row |
| `make test-framework-python` total runtime | T1 — Instrumented (CI timing) | ~45s (baseline 2026-05-22) | ≤ 55s after additions (≤22% slowdown ceiling) |

### Guardrails (must NOT degrade)

- **Mechanism A calibration baseline integrity** — tests MUST write to a tmp gate-coverage ledger; MUST NOT touch `.claude/logs/gate-coverage.jsonl` directly. Violation = revert.
- **Pre-commit hook runtime** — current `.githooks/pre-commit` p95 ≤ 2s. Target: no regression (these tests run in CI, not pre-commit).
- **CI pass rate** — current ≥ 95%. Target: no regression. Any test added that flakes ≥1× per 50 runs over 2 weeks → kill that single test.

### Leading indicators (1 week, by 2026-05-29)

- All 9 tests landed on the feature branch with CI green
- `make test-framework-python` runtime within budget
- 9/9 tests verified to emit ≥1 row to tmp gate-coverage ledger
- PR description references this PRD + test-coverage-master-plan §2.1
- Pre-merge review pass + merge to main

### Lagging indicators (90 days, by 2026-08-22)

- **Zero PR #317-class silent-pass incidents on the 9 covered gates** between ship date and 2026-08-22 (verified via honesty-ledger absence + cycle-time integrity-check absence-of-finding for each gate)
- **Mechanism A coverage telemetry shows `candidates > 0` weekly average for all 9 gates** over the 90-day window (verifies dispatch tests catch real production fires, not just synthetic test fires)
- **One follow-up audit** at 2026-08-22 confirms the F14+F15 promotion criteria (per master plan §2.2) are met retroactively — re-validating that v7.9 promoted these gates without dispatch tests and they DID continue to fire correctly

### Kill criteria

Any of the following at T+7d (2026-06-01) OR T+30d (2026-06-21):

| K | Trigger | Action |
|---|---|---|
| K1 | ≥1 of the 9 new tests flakes ≥1× per 50 runs over 2 weeks | Revert that single test + reopen its gate's coverage gap as a separate issue; do NOT block the rest |
| K2 | Total `make test-framework-python` runtime regresses > 30s vs baseline | Re-architect to share fixtures more aggressively OR mark heaviest tests as `pytest.mark.slow` excluded from default run |
| K3 | Mechanism A `gate-coverage.jsonl` shows contamination from test runs (i.e. tests wrote to the canonical ledger instead of tmp) | IMMEDIATE revert + retroactive scrub of contaminated rows |
| K4 | A new silent-pass incident hits one of the 9 covered gates within 30 days | Indicates the dispatch test's monkey-patching pattern is insufficient — file a meta-issue + delay v7.9.1 promotion of dispatch-test-driven decisions |

### Instrumentation plan

- **Test count + pass rate** → `state.json::phases.testing.tests_added` + CI step output
- **CI runtime** → GitHub Actions `pm-framework/pr-integrity` workflow timing
- **Mechanism A emission per test** → assert inside each test that the tmp ledger has ≥1 row matching `gate=<gate_id>`
- **Gate coverage telemetry post-ship** → existing weekly Mechanism A scan in `framework-status-weekly.yml`; no NEW instrumentation needed

### Review cadence

- **T+7d (2026-06-01)** — verify K1/K2/K3 not fired; CI green; runtime within budget
- **T+30d (2026-06-21)** — verify K4 not fired; Mechanism A weekly shows real fires on all 9 gates
- **T+90d (2026-08-22)** — final lagging-indicator review; close case study

## 4. Locked decisions (4 open questions from research.md §9)

| OQ | Decision | Rationale |
|---|---|---|
| **Q1** Cycle-time gates (#7 + #8) — file location | **New file `scripts/tests/test_integrity_check_dispatch.py`** | Cleaner mental model: dispatch tests follow their gate's source file. `BRANCH_ISOLATION_HISTORICAL` + `LAUNCHD_DRIFT` live in `integrity-check.py`, not `check-state-schema.py`; co-locating their tests with the closure-completeness tests in `test_branch_isolation_and_closure_completeness.py` would conflate write-time + cycle-time dispatch shapes. Separate file keeps each test file's "what is this testing" obvious. |
| **Q2** `PR_CACHE_STALE` (#9) — refactor or one-off | **One-off test file `scripts/tests/test_ensure_pr_cache_fresh.py`** | Refactoring `ensure-pr-cache-fresh.py` to emit gate-coverage rows via a shared `dispatch.py` helper would block this feature on a non-trivial refactor (~1d) AND introduce risk of changing the gate's existing dispatch behavior. One-off test is ~5 lines, lands in a day, leaves the refactor as a future v8.x candidate when there's appetite for a uniform-dispatch sweep. |
| **Q3** `GATE_TEST_MISSING` meta-gate — scope here? | **Defer to T1** (test-coverage-master-plan, RICE 53.3) | T1 explicitly depends on F14 reaching Phase E — that's after this feature ships. Including T1 in this PRD's scope would inflate effort from 7-9h to 2-3 days AND blur the success metric (closing the 9-gate gap vs preventing future gaps). Defer cleanly: file `scripts/tests/conftest.py` declares a `_NEW_GATE_TEST_REQUIRED` marker that T1's meta-gate can read once it exists. |
| **Q4** Fixture sharing strategy | **Introduce `scripts/tests/conftest.py`** with `make_valid_state_json()`, `make_invalid_state_json()`, `tmp_gate_coverage_ledger()` fixtures | PR #317's 2 tests inline their fixtures; scaling to 9 tests across 3 files (`test_check_state_schema.py` + `test_integrity_check_dispatch.py` + `test_ensure_pr_cache_fresh.py`) makes shared fixtures non-optional. conftest.py is pytest's canonical pattern. Bonus: T1's future meta-gate has a single place to read the test inventory. |

## 5. Solution overview

### 5.1 Test pattern (single shape, 9 instances)

```python
# Inside scripts/tests/test_check_state_schema.py (or _dispatch.py / _ensure_pr_cache_fresh.py)
def test_main_dispatch_<gate_id>(tmp_gate_coverage_ledger, monkeypatch):
    """Dispatch test: confirms <gate_id> fires end-to-end via main(),
    not just its internal check function."""
    # 1. Set up a synthetic failing input
    state = make_invalid_state_json(violates="<gate_id>")
    monkeypatch.setattr(check_state_schema, "collect_staged_state_files",
                        lambda *a, **kw: [state])
    monkeypatch.setattr(check_state_schema, "collect_all_staged_files",
                        lambda *a, **kw: [state.path])
    monkeypatch.setattr(check_state_schema, "GATE_COVERAGE_LEDGER",
                        tmp_gate_coverage_ledger)
    monkeypatch.setattr(sys, "argv", ["check-state-schema.py", str(state.path)])

    # 2. Drive main() end-to-end
    rc = check_state_schema.main()

    # 3. Assert gate fired (non-zero rc on the rejection path)
    assert rc != 0, f"<gate_id> failed to fire on invalid input"

    # 4. Assert Mechanism A row emitted
    rows = read_jsonl(tmp_gate_coverage_ledger)
    matching = [r for r in rows if r["gate"] == "<gate_id>"]
    assert len(matching) >= 1, f"<gate_id> did not emit a candidate row"
    assert matching[0]["candidates"] > 0
```

### 5.2 Shared fixtures (`scripts/tests/conftest.py`)

```python
@pytest.fixture
def tmp_gate_coverage_ledger(tmp_path):
    return tmp_path / "gate-coverage.jsonl"

@pytest.fixture
def make_valid_state_json(tmp_path):
    def _factory(**overrides):
        defaults = {
            "feature_name": "test-feature",
            "current_phase": "research",
            "framework_version": "v7.9",
            "state_owner": "ft2",
            "work_type": "feature",
            "branch": "feature/test-feature",
            "created_at": "2026-05-22T00:00:00Z",
            # ... minimal valid set per schema
        }
        defaults.update(overrides)
        path = tmp_path / "state.json"
        path.write_text(json.dumps(defaults, indent=2))
        return State(path=path, content=defaults)
    return _factory

@pytest.fixture
def make_invalid_state_json(make_valid_state_json):
    """Returns a state.json crafted to FAIL a specific gate."""
    def _factory(violates: str):
        if violates == "STATE_NO_CASE_STUDY_LINK":
            # current_phase=complete without case_study_link
            return make_valid_state_json(current_phase="complete",
                                        case_study_link=None)
        elif violates == "PHASE_TRANSITION_NO_TIMING":
            # current_phase change without timing.phases[new].started_at
            return make_valid_state_json(current_phase="prd",
                                        timing={"phases": {}})
        # ... 7 more violation recipes
        raise ValueError(f"No recipe for {violates}")
    return _factory
```

### 5.3 File organization

```
scripts/tests/
├── conftest.py                                    [NEW]
├── test_check_state_schema.py                     [EXTENDED — +6 tests]
│   ├── test_main_dispatch_cache_hits_auto_instrumentation_drift
│   ├── test_main_dispatch_cu_v2_invalid
│   ├── test_main_dispatch_state_no_case_study_link
│   ├── test_main_dispatch_case_study_missing_fields
│   ├── test_main_dispatch_phase_transition_no_log
│   └── test_main_dispatch_phase_transition_no_timing
├── test_integrity_check_dispatch.py               [NEW — 2 tests]
│   ├── test_main_dispatch_branch_isolation_historical
│   └── test_main_dispatch_branch_isolation_launchd_drift
└── test_ensure_pr_cache_fresh.py                  [NEW — 1 test]
    └── test_main_dispatch_pr_cache_stale
```

Total: **3 file touches** (1 extension + 2 new) + 1 conftest.py + **9 dispatch tests**.

## 6. Test & Eval Requirements

This feature IS a test feature, so the standard Test Phase verifies the new tests themselves. Required:

- All 9 new tests pass locally on `make test-framework-python`
- All 9 emit a `candidate` row to a tmp gate-coverage ledger (asserted by the test itself, not by an external check)
- Test runtime ceiling: each test ≤ 500ms; total ≤ 5s
- Existing test suite: no regression (all currently-passing tests still pass)
- CI workflow `pm-framework/pr-integrity` green on the feature branch

No AI eval requirements (this feature does not touch AI behaviors).

## 7. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Monkey-patching pattern breaks when `main()` refactors | All 9 tests fail at once | Document the canonical monkey-patch targets in `conftest.py` docstring; any future `main()` refactor PR must update the pattern in one place |
| Fixture drift as state.json schema evolves | Tests pass against outdated fixtures, miss real bugs | `make_valid_state_json()` builds from the live schema; schema validation runs as part of each test setup |
| Tests pollute `.claude/logs/gate-coverage.jsonl` (calibration baseline contamination) | v7.9.1 promotion decisions corrupted | `tmp_gate_coverage_ledger` fixture; monkey-patch `GATE_COVERAGE_LEDGER` in every test; assert tmp path != canonical path at setup |
| `PR_CACHE_STALE` test requires specific external state (PR cache file age) | Test environment-dependent, flaky | Use `tmp_path` + `os.utime()` to simulate aged file; never touch real `.cache/gh-pr-cache.json` |
| Cycle-time gates (#7, #8) — `integrity-check.py::main()` may have different monkey-patch surface | Higher per-gate setup cost | First test (`HISTORICAL`) drives the pattern; second (`LAUNCHD_DRIFT`) re-uses; if surface diverges, file follow-up issue |

## 8. Cross-cutting concerns

- **Branch isolation:** This is a `work_subtype: framework_feature` — Mode B fires on every commit. Worktree at `/Volumes/DevSSD/FitTracker2-infra-dispatch-test-coverage` is the only place to develop. Already established.
- **No code-on-main:** All file changes commit on `feature/framework-f14-f15-dispatch-test-coverage`.
- **Pre-commit hook on the feature branch:** when committing the new tests, the gates fire as usual. Tests live under `scripts/tests/` which IS infra-glob — but committing them on the feature branch with `work_subtype: framework_feature` passes Mode B (isolated).
- **No new framework gates:** this feature adds TESTS for existing gates. The `BRANCH_ISOLATION_ADVISORY_MODE` flag in `scripts/check-state-schema.py:132` is unchanged.
- **Mechanism A coverage:** the 9 new tests will write `candidate` rows to a tmp ledger — they will NOT appear in `.claude/logs/gate-coverage.jsonl`. Post-ship, real production fires of these 9 gates will continue to write to the canonical ledger as before.

## 9. Effort estimate (refined from research.md §10)

| Phase | Effort | Notes |
|---|---|---|
| Phase 0 (Research) | **DONE** — 65 min wall, 60 min paused | research.md complete |
| Phase 1 (PRD) | **DONE** — ~25 min wall | this doc |
| Phase 2 (Tasks) | 30 min | 9 test tasks + 1 conftest task + 1 integration-spec task + 1 docs task = 12 tasks |
| Phase 3 (Integration spec — no UI) | 20 min | `integration-spec.md` — fixture API contracts + monkey-patch target list + ledger isolation rules |
| Phase 4 (Implement) | 4-5h | conftest.py (~1h) + 9 dispatch tests (~25min avg, varying by gate) + iterate against `pytest -v` |
| Phase 5 (Test) | 30 min | Verify CI green + runtime budget + emission assertions |
| Phase 6 (Review) | 30 min | Pre-merge code review |
| Phase 7 (Merge) | 15 min | Squash + delete branch |
| Phase 8+9 (Docs + Learn) | 1h | Case study + cadence-followups C1 closure + open T1 backlog ticket |
| **Total remaining** | **~7-8h** | Fits within v7.9.1 window (2026-06-04 → 06-11) |

## 10. Approval

Phase 1 (PRD) ready for operator review. **No PRD without metrics rule satisfied** ✓ — primary metric, baseline (1/19 = 5%), target (10/19 = 53%), 4 kill criteria, review cadence.

Open question for operator: any objection to the 4 locked decisions in §4? If yes, raise BEFORE Phase 2 (Task breakdown) begins.

---

> **Pre-Phase-2 verification:** `state.json::phases.prd.status` will be set to `approved` upon user "OK" — and `current_phase` advanced to `tasks`. Tier 2.2 `phase_approved prd` + `phase_started tasks` events will be emitted to `.claude/logs/framework-f14-f15-dispatch-test-coverage.log.json` at the same moment.
