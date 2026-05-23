# Integration Spec — framework-f14-f15-dispatch-test-coverage

> **Phase 3 deliverable (integration branch — `has_ui=false`).** Technical contracts for the fixture-sharing + per-gate monkey-patching pattern across 3 distinct dispatcher surfaces.
>
> Authoritative parent: [`prd.md`](./prd.md) §5 (solution overview) + §6 (test requirements). This spec drills into the contract granularity that Phase 4 implementation depends on.

## 1. Three dispatcher surfaces (canonical inventory)

The 9 in-scope gates fire from **3 different `main()` entry points** with different monkey-patch surfaces. Confirmed via codebase inspection on 2026-05-22:

| Surface | Script | Line | Gates dispatched | Tests landed in |
|---|---|---|---|---|
| **S1** | [`scripts/check-state-schema.py`](../../../scripts/check-state-schema.py) | `main()` line 1475 | 6 of 9 (F14×4 + phase-transitions×2) | `scripts/tests/test_check_state_schema.py` (extension) |
| **S2** | [`scripts/integrity-check.py`](../../../scripts/integrity-check.py) | `main()` line 1038 | 2 of 9 (`BRANCH_ISOLATION_HISTORICAL` + `LAUNCHD_DRIFT`) | `scripts/tests/test_integrity_check_dispatch.py` (new) |
| **S3** | [`scripts/ensure-pr-cache-fresh.py`](../../../scripts/ensure-pr-cache-fresh.py) | `main()` line 112 | 1 of 9 (`PR_CACHE_STALE`) | `scripts/tests/test_ensure_pr_cache_fresh.py` (new) |

## 2. Monkey-patch targets per surface

### 2.1 Surface S1 — `check-state-schema.py::main()`

**Module attributes to patch (canonical):**

| Attribute | Type | Purpose | Confirmed line |
|---|---|---|---|
| `collect_staged_state_files` | callable → `list[Path]` | Yields state.json files from `git diff --staged` | 921 |
| `collect_all_state_files` | callable → `list[Path]` | Yields ALL state.json files on disk (for cross-file gates) | 941 |
| `collect_all_staged_files` | callable → `list[str]` | Yields ALL staged paths (file-extension dispatch lookup) | 947 |
| `GATE_COVERAGE_LEDGER` | `Path` | Mechanism A telemetry sink | 61 |

**Environment variable opt-outs:**

- `GATE_COVERAGE_LEDGER_DISABLED=1` — skips telemetry write entirely. Tests MUST NOT set this; they must monkey-patch the path instead so the row is captured + asserted on.

**`sys.argv` shape:**

```python
sys.argv = ["check-state-schema.py", *[str(p) for p in state_files]]
```

**Exit code contract:**

- `0` — all gates passed (or all were skipped for legitimate reasons)
- `non-zero` — at least one gate fired with a rejection

Tests assert `rc != 0` on the rejection path AND assert ≥1 matching candidate row in the ledger.

### 2.2 Surface S2 — `integrity-check.py::main()`

**Module attributes to patch (canonical):**

| Attribute | Type | Purpose |
|---|---|---|
| `FEATURES_DIR` | `Path` | Source of all `state.json` files (line 48) |
| `CASE_STUDIES_DIR` | `Path` | Source of all `*.md` case studies (line 49) |
| `REPO_ROOT` | `Path` | Anchors the scan; some checks (LAUNCHD_DRIFT) compute paths from it |
| `check_branch_isolation_historical` | callable | Direct check function (line 542) |
| `check_branch_isolation_launchd_drift` | callable | Direct check function (line 663) |

**`sys.argv` shape:**

```python
sys.argv = ["integrity-check.py"]  # no positional args; scans on-disk state
```

**Exit code contract:**

- Cycle-time gates are **advisory** — `integrity-check.py` exits 0 even on advisory findings (findings list is non-empty but not blocking).
- Test assertion shape: instead of asserting `rc != 0`, assert the **findings list** returned by the check function or printed to stdout contains a row with the expected gate code.

### 2.3 Surface S3 — `ensure-pr-cache-fresh.py::main()`

**Module attributes to patch (canonical):**

| Attribute | Type | Purpose | Confirmed line |
|---|---|---|---|
| `CACHE_PATH` | `Path` | Location of `.cache/gh-pr-cache.json` | 33 |
| `cache_age_seconds` | callable → `float \| None` | Reads mtime of CACHE_PATH | 42 |
| `cache_is_empty` | callable → `bool` | Reads CACHE_PATH content | 64 |
| `cache_missing_expected_repos` | callable → `(bool, list[str])` | Cross-checks repo whitelist | 84 |

**`sys.argv` shape:**

```python
sys.argv = ["ensure-pr-cache-fresh.py", "--max-age-hours", "24", "--quiet"]
```

**Age simulation strategy:**

Test fixture writes a valid-but-aged cache file to `tmp_pr_cache_file`, then `os.utime(tmp_pr_cache_file, (older_ts, older_ts))` where `older_ts = time.time() - 25*3600` (25h = stale by 1h). Monkey-patch `CACHE_PATH` to `tmp_pr_cache_file`.

**Exit code contract:**

- `0` — cache fresh OR refresh succeeded
- `non-zero` — cache stale + refresh failed

Test asserts the gate emits a `PR_CACHE_STALE` row when age > 24h, regardless of refresh success (the ROW emission is the gate signal; refresh outcome is operational).

## 3. Fixture contracts (`scripts/tests/conftest.py`)

### 3.1 `tmp_gate_coverage_ledger`

```python
@pytest.fixture
def tmp_gate_coverage_ledger(tmp_path, monkeypatch) -> Path:
    """Provides an isolated JSONL ledger path for Mechanism A telemetry writes.

    Contract:
      - Returns a tmp Path; tests MUST monkey-patch GATE_COVERAGE_LEDGER to this value.
      - Records the canonical ledger's mtime at setup; asserts at teardown that
        the canonical ledger's mtime did NOT change during the test.
      - Failure of the teardown assertion = K3 trigger (calibration baseline contamination).

    Returns:
      Path to a tmp .jsonl file that does not exist initially. Tests' main() calls
      will create + append to it.
    """
```

**Teardown assertion (the K3 guard):**

```python
@pytest.fixture
def tmp_gate_coverage_ledger(tmp_path):
    canonical = REPO_ROOT / ".claude" / "logs" / "gate-coverage.jsonl"
    canonical_mtime_at_setup = canonical.stat().st_mtime if canonical.exists() else None
    tmp = tmp_path / "gate-coverage.jsonl"
    yield tmp
    if canonical_mtime_at_setup is not None:
        canonical_mtime_at_teardown = canonical.stat().st_mtime
        assert canonical_mtime_at_teardown == canonical_mtime_at_setup, (
            f"K3 VIOLATION: canonical {canonical} was modified during the test. "
            f"This would contaminate the v7.9.1 calibration baseline. Revert immediately."
        )
```

### 3.2 `make_valid_state_json(**overrides) -> State`

**Schema baseline (v7.9, minimum-required fields):**

```python
DEFAULT_VALID_STATE = {
    "feature_name": "test-feature",
    "display_name": "Test fixture feature",
    "current_phase": "research",
    "created_at": "2026-05-22T00:00:00Z",
    "updated": "2026-05-22T00:00:00Z",
    "framework_version": "v7.9",
    "work_type": "feature",
    "work_subtype": "framework_feature",
    "state_owner": "ft2",
    "dispatch_pattern": "serial",
    "has_ui": False,
    "requires_analytics": False,
    "isolation_opt_out": False,
    "branch": "feature/test-feature",
    "case_study_type": "feature_case_study",
    "phases": { "research": { "status": "in_progress" } },
    "tasks": [],
    "cache_hits": [{"timestamp": "2026-05-22T00:00:00Z", "cache_level": "L1", "skill": "test"}],
    "transitions": [],
    "timing": {
        "phases": { "research": { "started_at": "2026-05-22T00:00:00Z" } }
    }
}
```

**Return type:** `dataclass State` with `path: Path`, `content: dict`. Tests modify `content` then call `state.write()` to flush.

**Schema validation at fixture setup:**

```python
def _factory(**overrides):
    content = {**DEFAULT_VALID_STATE, **overrides}
    # Run the live schema check to catch fixture drift
    from check_state_schema import validate_schema  # OR equivalent
    errs = validate_schema(content)
    if errs:
        raise ValueError(f"FIXTURE DRIFT: DEFAULT_VALID_STATE no longer schema-valid: {errs}")
    path = tmp_path / "state.json"
    path.write_text(json.dumps(content, indent=2))
    return State(path=path, content=content)
return _factory
```

This guards against the **schema-drift risk** identified in research.md §7.

### 3.3 `make_invalid_state_json(violates: str) -> State`

**9 violation recipes (one per gate):**

| `violates=` | Mutation applied to baseline |
|---|---|
| `STATE_NO_CASE_STUDY_LINK` | `current_phase="complete"` without setting `case_study_link` field |
| `CASE_STUDY_MISSING_FIELDS` | Set `current_phase="complete"` + `case_study_link="docs/case-studies/fake.md"` (case study won't exist with 7 required frontmatter fields) |
| `CU_V2_INVALID` | Set `cu_v2 = {"factors": "not_a_list"}` (wrong type) |
| `CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT` | Set `created_at="2026-05-15T00:00:00Z"` (post-Mechanism-C) + `cache_hits=[]` but have a session-event ledger showing Reads happened |
| `PHASE_TRANSITION_NO_LOG` | Set `current_phase="prd"` (mutation from default "research") but provide no Tier 2.2 log within 15 min |
| `PHASE_TRANSITION_NO_TIMING` | Set `current_phase="prd"` without `timing.phases.prd.started_at` |
| `BRANCH_ISOLATION_HISTORICAL` | Create state.json with `created_at >= 2026-05-21` (post-cutoff) + `work_subtype="framework_feature"` + no `worktree_path` |
| `BRANCH_ISOLATION_LAUNCHD_DRIFT` | Create a synthetic plist file under `Library/LaunchAgents/` pointing at a wrong tree (mock filesystem) |
| `PR_CACHE_STALE` | Write a CACHE_PATH file with `os.utime` set to 25h ago |

Each recipe is implemented as a private helper `_violate_<gate>()` returning the mutation dict; the public `make_invalid_state_json` dispatches.

### 3.4 `tmp_pr_cache_file`

```python
@pytest.fixture
def tmp_pr_cache_file(tmp_path):
    """Returns a tmp .cache/gh-pr-cache.json path with helpers:
      - .write_valid(): writes a valid cache structure
      - .age(hours): os.utime to N hours ago"""
```

## 4. Schema validation strategy

**Fixture drift is the highest residual risk** (research.md §7). Mitigation:

1. **Build-time validation** — `DEFAULT_VALID_STATE` runs through the live `check_state_schema.validate_schema()` at conftest import. If the schema evolves, conftest fails LOUD before any test runs.
2. **No hardcoded copies of schema** — fixtures derive from `DEFAULT_VALID_STATE` + per-recipe overrides; recipes mutate ONLY the field needed to trigger their gate.
3. **Mark schema-bound recipes** — each recipe carries a comment `# v7.9 schema; update if SCHEMA_DRIFT` so future updates are easy to spot.
4. **CI dependency** — `make test-framework-python` runs after `make integrity-check` in `verify-local`; a schema regression that breaks both surfaces fails fast.

## 5. Error-handling contracts

### 5.1 Fixture failures

| Failure | Action |
|---|---|
| `DEFAULT_VALID_STATE` no longer schema-valid (schema evolved) | conftest import fails LOUD; all tests in the suite skip with reason `schema-drift`; CI red |
| `make_invalid_state_json(violates="X")` returns a state.json that the gate does NOT actually reject | Test fails with `KeyError`-like message: "fixture for X did not trigger the gate; recipe out of date" |
| `tmp_gate_coverage_ledger` teardown finds canonical ledger mtime changed | RAISES at teardown — K3 violation; CI red; rollback signal |
| `tmp_pr_cache_file` age control fails (filesystem doesn't support utime) | Skip test with reason `os.utime not supported on this fs` |

### 5.2 Test failures

| Pattern | Resolution |
|---|---|
| Test fails on `assert rc != 0` (gate didn't fire) | Either the recipe is wrong (fix in conftest) OR the gate has regressed (real failure, do not suppress) |
| Test fails on `assert len(matching) >= 1` (no candidate row emitted) | Mechanism A wiring for that gate is broken; surface as honesty-ledger entry |
| Test passes locally, fails in CI | Likely K1 (flake) — quarantine via `pytest.mark.flaky` for 1 cycle while investigating, escalate if persists |

## 6. Test execution contracts

### 6.1 Runtime budget

- **Per test ceiling:** ≤500ms (asserted via `pytest-timeout` if available)
- **Total for 9 new tests:** ≤5s
- **Full `make test-framework-python`:** ≤55s (was ~45s)

If the runtime ceiling is breached, K2 fires.

### 6.2 Test isolation

- Each test uses its own `tmp_path` → no inter-test contamination
- Each test patches `GATE_COVERAGE_LEDGER` → no canonical ledger writes
- Each test uses `monkeypatch` (pytest's auto-rollback) → no global state leaks
- `pytest-randomly` (if available) — tests must pass in any order

### 6.3 Parallel execution safety

The 9 tests run safely in parallel (`pytest -n auto` or `pytest-xdist`):

- All use isolated tmp paths
- No shared module-level state mutated permanently (all via `monkeypatch`)
- Tests in `test_check_state_schema.py` share monkey-patch targets but never simultaneously (pytest function isolation)

### 6.4 CI integration

- Tests run as part of existing `pm-framework/pr-integrity` workflow via `make test-framework-python`
- No new CI workflow file needed
- Test results visible in PR sticky comment (existing `<!-- pm-framework-pr-integrity-bot -->` marker)

## 7. Backward compatibility

**None required.** This feature ADDS test files; it does not modify any production code. Existing tests in `scripts/tests/` continue to work; `conftest.py` is new and only auto-loaded by pytest in this directory.

**One pre-existing test file extended (`test_check_state_schema.py`):** new functions added; no existing functions modified.

**Verification at PR review:** `git diff main...feature/...` must show ONLY additions in `scripts/tests/` + 1 conftest + (in Phase 8) the case-study doc + 4 doc updates. Zero changes to `scripts/check-state-schema.py`, `scripts/integrity-check.py`, `scripts/ensure-pr-cache-fresh.py`, `.githooks/pre-commit`, or any other production-path file.

## 8. Service dependencies

- **pytest** (already in CI via `make test-framework-python`)
- **pytest-timeout** (optional; if missing, runtime ceiling is enforced as advisory)
- **pytest-randomly** (optional; if missing, ordering invariance is asserted only by code review)
- No new external dependencies; no new pip installs in CI

## 9. Cross-cutting concerns (mirrored from PRD §8 for self-containedness)

- **Branch isolation:** development happens ONLY in the worktree at `/Volumes/DevSSD/FitTracker2-infra-dispatch-test-coverage`
- **No code-on-main:** all commits on `feature/framework-f14-f15-dispatch-test-coverage`
- **`work_subtype: framework_feature`** triggers Mode B on every commit; the worktree resolves this
- **No new gates added** — `BRANCH_ISOLATION_ADVISORY_MODE` flag at `scripts/check-state-schema.py:132` unchanged

## 10. Open contract questions (resolved)

All 4 OQs from research.md §9 + PRD §4 are locked. No open questions remain at integration-spec close.

**Implicit contract questions resolved during this spec:**

| Question | Resolution |
|---|---|
| Where does conftest.py validate schema (at import or at fixture call)? | **At import.** Fail-fast on schema drift; ensures developers see the failure immediately, not deep inside a test. |
| Should tests assert ledger isolation (mtime unchanged) at every teardown? | **Yes, via `tmp_gate_coverage_ledger` fixture teardown.** Composes K3 guard with normal pytest cleanup. |
| What's the policy on tests-of-the-tests (does conftest itself need tests)? | **Out of scope.** Conftest is exercised by every dispatch test; if a fixture breaks, every test fails — strong implicit coverage. |
| Should there be a meta-test that asserts "every declared gate has ≥1 dispatch test"? | **Deferred to T1 (`GATE_TEST_MISSING` meta-gate, RICE 53.3).** Backlog ticket opened in Phase 8 by this feature. |

## 11. Approval

Phase 3 (Integration spec) ready for operator review. Standard PM-workflow approval gate before Phase 4 (Implementation).

**Next phase (Phase 4) will:**

1. T1 — write conftest.py + 9 violation recipes + 4 fixtures (~1h)
2. T2 — write pilot test (`STATE_NO_CASE_STUDY_LINK`) (~30min); validates the monkey-patch pattern
3. T3–T10 — implement remaining 8 tests (~3h, E-core + P-core lanes per task graph)
4. T11 — Phase 5 verification handoff

Approve to advance.

---

> **State.json update on approval:** `phases.ux_or_integration.status = "approved"`, `current_phase = "implementation"`, transitions[] += entry; Tier 2.2 `phase_approved ux_or_integration` + `phase_started implementation` events.
