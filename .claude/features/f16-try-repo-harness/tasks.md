# F16 — Try-repo pre-commit harness | Phase 2 Tasks

> Locked task list per Phase 1 PRD acceptance criteria. Each task is a single self-contained commit with a passing local test suite.

## Task layout

| ID | Title | Effort | Acceptance |
|---|---|---|---|
| T2 | Fixture dir layout + canonical baseline | 0.2d | `tests/fixtures/_baseline/state.json` round-trips through `make_state_json()` builder |
| T3 | Harness scaffold + helpers | 0.3d | `scripts/tests/test_try_repo_harness.py` skeleton + `make_throwaway_repo()` + `run_precommit()` |
| T4a | Fixtures: schema gates (5) | 0.2d | 5 gates × 2 fixtures each = 10 fixture pairs |
| T4b | Fixtures: closure gates (4) | 0.2d | 4 gates × 2 fixtures each = 8 fixture pairs |
| T4c | Fixtures: telemetry gates (4) | 0.2d | 4 gates × 2 fixtures each = 8 fixture pairs |
| T4d | Fixtures: isolation gates (3) | 0.1d | 3 gates × 2 fixtures each = 6 fixture pairs |
| T5 | 32 test functions parametrized | 0.5d | `pytest -k try_repo --collect-only` shows 32 |
| T5a | Mechanism A canonical ledger untouched assertion | (within T5) | Pre/post diff test asserts contamination prevented |
| T6 | CI workflow extension | 0.2d | `.github/workflows/ci.yml` runs try-repo job in <60s |
| T7 | Deliberate-regression verification test | 0.3d | Patch one gate to no-op; try-repo catches; F14 dispatch tests do NOT |
| T8 | CLAUDE.md note | 0.1d | "Data Integrity Framework" section gains try-repo discipline + new-gate fixture rule |
| T9 | dev-guide §4 column | 0.2d | Gate catalog gets "try-repo coverage" column |
| T10 | Case study + showcase MDX | 0.4d | Source case study + fitme-story slot per chronology rule |
| T11 | Advisory→enforced flip (calendar) | n/a | 14d post-ship; opens at ~2026-06-18 if T2-T10 ship 2026-06-04 |

**Total code work: ~2.5 days.** Plus 0.4d docs + case study = ~3 days from PRD lock to ship.

## Gate inventory (informs T4a-T4d fixture grouping)

Reading `scripts/check-state-schema.py` + `scripts/check-case-study-preflight.py` at current main, the 16 enforced write-time gates are:

### Schema gates (T4a)
1. `SCHEMA_DRIFT_LEGACY_PHASE`
2. `SCHEMA_DRIFT_LEGACY_CREATED`
3. `FRAMEWORK_VERSION_FORMAT`
4. `STATE_OWNER_MISSING`
5. `STATE_OWNER_INVALID`

### Closure gates (T4b)
6. `STATE_OWNER_LOCATION_MISMATCH`
7. `FEATURE_CLOSURE_COMPLETENESS`
8. `STATE_NO_CASE_STUDY_LINK`
9. `CASE_STUDY_MISSING_FIELDS`

### Telemetry gates (T4c)
10. `PHASE_TRANSITION_NO_LOG`
11. `PHASE_TRANSITION_NO_TIMING`
12. `CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT`
13. `CU_V2_INVALID`

### Isolation gates (T4d)
14. `ISOLATION_OPT_OUT_REASON_MISSING`
15. `BRANCH_ISOLATION_VIOLATION` (Mode B commit-level)
16. `BRANCH_ISOLATION_VIOLATION` (Mode C per-file)

Plus 2 case-study-side gates from `check-case-study-preflight.py`:
- `BROKEN_PR_CITATION` (covered by T4a as a schema-adjacent gate — fits in the schema bucket)
- `CASE_STUDY_MISSING_TIER_TAGS` (covered by T4b — closure-side)

→ **16 fixture-pair targets confirmed.**

## Per-fixture design pattern

Each fixture pair under `tests/fixtures/<gate-id>/` is:

```
tests/fixtures/<gate-id>/
├── positive/                  # Should fire — gate must reject
│   ├── state.json.yaml       # Partial-record YAML merged with _baseline
│   ├── case-study.md          # Optional, gate-dependent
│   └── README.md              # 1-paragraph "what this fixture demonstrates"
└── negative/                  # Should pass — gate must NOT fire
    ├── state.json.yaml
    ├── case-study.md           # Optional
    └── README.md
```

## Per-test pattern

```python
@pytest.mark.try_repo
@pytest.mark.parametrize("fixture_dir", [
    "tests/fixtures/SCHEMA_DRIFT_LEGACY_PHASE/positive",
    "tests/fixtures/SCHEMA_DRIFT_LEGACY_CREATED/positive",
    # ... 14 more
])
def test_try_repo_positive_fixture_fires(fixture_dir, throwaway_repo, tmp_gate_coverage_ledger):
    """Positive fixture must cause the gate to fire (pre-commit exit ≠ 0)."""
    files = stage_fixture(fixture_dir, throwaway_repo)
    rc, stdout, stderr = run_precommit(throwaway_repo, env={
        "GATE_COVERAGE_LEDGER": str(tmp_gate_coverage_ledger),
        **scrub_home_env(),
    })
    gate_id = fixture_dir.split("/")[-2]
    assert rc != 0, f"{gate_id} positive fixture: pre-commit should have rejected (got rc={rc})"
    # Assert the specific gate name is mentioned in stderr (sanity check)
    assert gate_id in stderr or gate_id.replace("_", " ") in stderr.lower()


@pytest.mark.try_repo
@pytest.mark.parametrize("fixture_dir", [
    "tests/fixtures/SCHEMA_DRIFT_LEGACY_PHASE/negative",
    # ... 15 more
])
def test_try_repo_negative_fixture_passes(fixture_dir, throwaway_repo, tmp_gate_coverage_ledger):
    """Negative fixture must NOT cause the gate to fire (pre-commit exit == 0)."""
    files = stage_fixture(fixture_dir, throwaway_repo)
    rc, stdout, stderr = run_precommit(throwaway_repo, env={
        "GATE_COVERAGE_LEDGER": str(tmp_gate_coverage_ledger),
        **scrub_home_env(),
    })
    assert rc == 0, f"Negative fixture rejected unexpectedly: stderr={stderr}"


@pytest.mark.try_repo
def test_canonical_gate_coverage_ledger_untouched(tmp_path, throwaway_repo, monkeypatch):
    """Q5 enforcement — running try-repo MUST NOT write to .claude/logs/gate-coverage.jsonl."""
    canonical_path = Path(".claude/logs/gate-coverage.jsonl").resolve()
    before_mtime = canonical_path.stat().st_mtime if canonical_path.exists() else None
    before_size = canonical_path.stat().st_size if canonical_path.exists() else 0
    
    # Run any try-repo fixture
    files = stage_fixture("tests/fixtures/SCHEMA_DRIFT_LEGACY_PHASE/positive", throwaway_repo)
    run_precommit(throwaway_repo, env={
        "GATE_COVERAGE_LEDGER": str(tmp_path / "gate-coverage.jsonl"),
    })
    
    after_mtime = canonical_path.stat().st_mtime if canonical_path.exists() else None
    after_size = canonical_path.stat().st_size if canonical_path.exists() else 0
    
    assert before_mtime == after_mtime, "Canonical Mechanism A ledger mtime changed — Q5 env-var override is silently broken!"
    assert before_size == after_size, "Canonical Mechanism A ledger grew — Q5 env-var override is silently broken!"
```

## Deliberate-regression test (T7)

Phase 5 acceptance criterion #5 requires proving F16 catches what F14 misses. The test:

1. Identify a gate that has BOTH F14 dispatch test AND F16 try-repo test (e.g., `CU_V2_INVALID`).
2. Apply a monkey-patch that makes the gate's `check_cu_v2_schema()` function **silently return success** even on invalid input (the patch could be a 1-line `return True` at function start).
3. Run F14 dispatch test → still passes (because the dispatch test asserts *Mechanism A row emission*, not the gate's logical outcome — `return True` still emits the row).
4. Run F16 try-repo test → FAILS (because the positive fixture has invalid `cu_v2` and the gate's silent-success means pre-commit returns 0 instead of non-zero — the integration assertion catches it).
5. Revert the monkey-patch. F14 + F16 both pass.

This proves the value claim: F16 catches a regression class that F14 architecturally cannot.

## Commit-sized step breakdown

| Step | Commit | Lines |
|---|---|---|
| 1 | T2 baseline + builder | ~100 |
| 2 | T3 harness scaffold + helpers | ~150 |
| 3 | T4a schema fixtures (5 gates) | ~200 |
| 4 | T4b closure fixtures (4 gates) | ~200 |
| 5 | T4c telemetry fixtures (4 gates) | ~200 |
| 6 | T4d isolation fixtures (3 gates) | ~150 |
| 7 | T5 32 parametrized tests + Q5 canonical-untouched assertion | ~300 |
| 8 | T6 CI workflow extension | ~30 |
| 9 | T7 deliberate-regression test | ~80 |
| 10 | T8 CLAUDE.md note | ~30 |
| 11 | T9 dev-guide §4 column | ~30 |
| 12 | T10 case study + showcase | ~250 |

**Total: 12 commits, ~1,720 lines of new code/docs.**

## Out-of-band decisions deferred from PRD §11

- **Test file naming:** DECIDED — single file `scripts/tests/test_try_repo_harness.py` with parametrized cases. Per-gate file would proliferate to 16 files for one cohesive surface.
- **Fixture YAML schema:** DECIDED — defined inline in T2 as the `_baseline/state.json` overlay structure. No separate JSON Schema file needed initially.
- **CI job ordering:** DECIDED — parallel to F14 dispatch tests. Independent test surfaces; no data dependency between them.

## Cross-references

- PRD: `.claude/features/f16-try-repo-harness/prd.md`
- Research: `.claude/features/f16-try-repo-harness/research.md`
- Spec: `docs/master-plan/infra-master-plan-2026-05-12.md` §3.4 Theme G F16
- Predecessor pattern: F14 monkey-patch tests (PR #317)
- Linear: FIT-88
