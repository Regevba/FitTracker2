# Tasks — framework-f14-f15-dispatch-test-coverage

> **Phase 2 deliverable.** Implementable task breakdown derived from [`prd.md`](./prd.md) §5 + §6 + §9.

## Task graph (visual)

```
T1 conftest.py           (foundation; blocks all dispatch tests)
  │
  ├─→ T2 test_main_dispatch_state_no_case_study_link        (F14 #3 — simplest gate, validates pattern)
  │
  ├─→ T3 test_main_dispatch_case_study_missing_fields       (F14 #4)
  ├─→ T4 test_main_dispatch_cu_v2_invalid                   (F14 #2)
  ├─→ T5 test_main_dispatch_cache_hits_auto_drift           (F14 #1)
  ├─→ T6 test_main_dispatch_phase_transition_no_log         (F15 #5 — highest-risk gate)
  ├─→ T7 test_main_dispatch_phase_transition_no_timing      (F15 #6 — pairs with T6)
  │     [T3-T7 all land in test_check_state_schema.py; parallel-safe]
  │
  ├─→ T8 test_main_dispatch_branch_isolation_historical     (F15 #7 — cycle-time, new file)
  ├─→ T9 test_main_dispatch_branch_isolation_launchd_drift  (F15 #8 — cycle-time, same new file)
  │     [T8-T9 in scripts/tests/test_integrity_check_dispatch.py]
  │
  └─→ T10 test_main_dispatch_pr_cache_stale                 (F15 #9 — own file)
        [T10 in scripts/tests/test_ensure_pr_cache_fresh.py]

T11 Phase 5 verification (after T1-T10 done)
T12 Phase 8 docs + cadence-followups C1 closure + open T1 backlog ticket
```

**12 tasks total.** T1 is the foundation; T2 is the pattern-validation pilot; T3-T10 run in parallel (E-core lane per v5.1 protocol — all lightweight); T11 + T12 are serial post-implementation.

## Task table

| ID | Title | Type | Skill | Effort | Lane | Depends on | Status |
|---|---|---|---|---|---|---|---|
| **T1** | Write `scripts/tests/conftest.py` with shared fixtures: `tmp_gate_coverage_ledger`, `make_valid_state_json`, `make_invalid_state_json` (9 violation recipes), `tmp_pr_cache_file` | infra | dev | 1.0h | P-core (foundation) | — | pending |
| **T2** | `test_main_dispatch_state_no_case_study_link` — F14 pilot test, validates monkey-patch pattern end-to-end | test | dev | 0.5h | P-core (pattern validator) | T1 | pending |
| **T3** | `test_main_dispatch_case_study_missing_fields` — F14 | test | dev | 0.3h | E-core | T1, T2 | pending |
| **T4** | `test_main_dispatch_cu_v2_invalid` — F14 | test | dev | 0.3h | E-core | T1, T2 | pending |
| **T5** | `test_main_dispatch_cache_hits_auto_instrumentation_drift` — F14 (renamed v7.8.3) | test | dev | 0.3h | E-core | T1, T2 | pending |
| **T6** | `test_main_dispatch_phase_transition_no_log` — F15 highest-risk; guards most-frequent state mutation | test | dev | 0.4h | E-core | T1, T2 | pending |
| **T7** | `test_main_dispatch_phase_transition_no_timing` — F15 pairs with T6 | test | dev | 0.4h | E-core | T1, T2 | pending |
| **T8** | New file `scripts/tests/test_integrity_check_dispatch.py` + `test_main_dispatch_branch_isolation_historical` (cycle-time gate via `integrity-check.py::main()`) | test | dev | 0.5h | P-core (different dispatch surface) | T1, T2 | pending |
| **T9** | `test_main_dispatch_branch_isolation_launchd_drift` — F15 cycle-time, same file as T8 | test | dev | 0.4h | E-core | T1, T8 | pending |
| **T10** | New file `scripts/tests/test_ensure_pr_cache_fresh.py` + `test_main_dispatch_pr_cache_stale` (separate script, `os.utime`-based age simulation) | test | dev | 0.5h | P-core (different dispatch surface) | T1, T2 | pending |
| **T11** | Phase 5 verification: `make test-framework-python` green; 9/9 tests emit candidate row; runtime ceiling met (≤ 5s for 9 tests; ≤ 55s total suite); pre-commit hook still green | test | qa | 0.5h | serial | T2, T3, T4, T5, T6, T7, T8, T9, T10 | pending |
| **T12** | Phase 8 docs: case-study draft + cadence-followups §C1 strikethrough + open `framework-gate-test-missing-meta-gate` backlog item (T1, RICE 53.3) + update `docs/master-plan/test-coverage-master-plan-2026-05-13.md` §2.1 baseline numbers | docs | dev | 1.0h | serial | T11 | pending |

**Total effort:** 6.1h (matches PRD §9 estimate of 7-8h within tolerance; difference is review + merge buffer).

## Task details

### T1 — conftest.py + 9 violation recipes

**File created:** `scripts/tests/conftest.py`

Contract:
```python
@pytest.fixture
def tmp_gate_coverage_ledger(tmp_path) -> Path:
    """Returns a tmp path safe for gate-coverage writes; tests MUST monkey-patch
    GATE_COVERAGE_LEDGER to this path. Asserts at fixture teardown that the
    canonical ledger was not touched."""

@pytest.fixture
def make_valid_state_json(tmp_path):
    """Factory: returns a function that builds a minimal-valid state.json
    file conforming to the live v7.9 schema. Accepts **overrides for any field."""

@pytest.fixture
def make_invalid_state_json(make_valid_state_json):
    """Factory: returns a function that takes violates=<GATE_ID> and returns
    a state.json crafted to fail that exact gate. 9 recipes:
      - STATE_NO_CASE_STUDY_LINK
      - CASE_STUDY_MISSING_FIELDS
      - CU_V2_INVALID
      - CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT
      - PHASE_TRANSITION_NO_LOG
      - PHASE_TRANSITION_NO_TIMING
      - BRANCH_ISOLATION_HISTORICAL (cycle-time)
      - BRANCH_ISOLATION_LAUNCHD_DRIFT (cycle-time)
      - PR_CACHE_STALE (file-age-based)"""

@pytest.fixture
def tmp_pr_cache_file(tmp_path):
    """Returns a tmp `.cache/gh-pr-cache.json` path with os.utime control
    for age-based gate testing."""
```

Acceptance: pytest discovers fixtures; no import errors; `pytest --collect-only scripts/tests/` includes the conftest entries.

### T2 — pilot test (`STATE_NO_CASE_STUDY_LINK`)

Chosen as pilot because (a) simplest gate logic (single boolean check), (b) zero external dependencies, (c) deterministic synthetic input.

If T2 passes cleanly: pattern is proven; T3-T10 follow without further pattern-validation.
If T2 reveals a monkey-patch surface issue: BLOCK T3-T10, file an issue, escalate to operator.

### T3-T7 — F14 + phase-transition tests (parallel-safe E-core lane)

All land in existing `scripts/tests/test_check_state_schema.py` (extension). Each test ~5 lines pattern body + ~3 lines violation recipe (already in conftest). No file-collision risk since all are functions, not module-level globals.

### T8-T9 — cycle-time advisory tests (new file)

`scripts/integrity-check.py::main()` has a different monkey-patch surface than `check-state-schema.py::main()`:
- `collect_state_files()` (no "staged" — scans all features)
- `collect_case_studies()` (scans all case studies)
- `GATE_COVERAGE_LEDGER` (same module attribute)
- `sys.argv = ["integrity-check.py"]`

T8 establishes the pattern + file scaffolding; T9 re-uses.

### T10 — PR_CACHE_STALE (separate script)

`scripts/ensure-pr-cache-fresh.py` has its own dispatch shape: takes no args, reads `.cache/gh-pr-cache.json`, checks file mtime, exits non-zero if older than 24h. Test uses `os.utime()` on a `tmp_pr_cache_file` fixture to simulate age. Patch `CACHE_FILE` module attribute, not the canonical path.

### T11 — Phase 5 verification

Concrete pass criteria:
- `pytest scripts/tests/ -v` exits 0
- All 9 new tests visible in output
- Test-suite total wall ≤ 55s (current baseline ~45s)
- No new flaky-test warning (run thrice via `pytest --count=3` if `pytest-repeat` available)
- Pre-commit hook still passes a synthetic commit on the worktree
- Mechanism A canonical `.claude/logs/gate-coverage.jsonl` mtime unchanged after test run (proves test isolation)

### T12 — Phase 8 docs

Three artifacts:
1. **Case study:** `docs/case-studies/framework-f14-f15-dispatch-test-coverage-case-study.md` — 5-7 sections covering problem → approach → 9 tests landed → empirical outcome (T11 results) → kill-criteria status → lessons learned
2. **Cadence-followups:** edit `.claude/shared/must-have-cadence-followups.md` §C1 row + the C1 detail section — strike through with `**Closed YYYY-MM-DD via PR #N**`
3. **Backlog open:** `docs/product/backlog.md` new entry for `framework-gate-test-missing-meta-gate` (T1 from test-coverage-master-plan, RICE 53.3, depends on this feature reaching Phase E)
4. **Test-coverage plan update:** edit `docs/master-plan/test-coverage-master-plan-2026-05-13.md` §2.1 to reflect new baseline (1/19 → 10/19)

## Cross-cutting reminders

- **All commits land on `feature/framework-f14-f15-dispatch-test-coverage` in the worktree** — Mode B gate enforces this for `work_subtype: framework_feature`
- **No edits to main's working tree** — only the worktree's copy of `scripts/tests/` gets modified
- **Per-PR review bot** will run on the feature branch; expect green status
- **Pre-merge:** branch + main both must be CI-green before approval; `make integrity-check` 0 findings + 0 advisory baseline preserved

## Approval

Phase 2 (Tasks) ready for operator review. Standard PM-workflow approval gate before Phase 3 (Integration spec — `integration-spec.md` since `has_ui=false`).
