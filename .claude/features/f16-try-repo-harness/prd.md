---
feature: f16-try-repo-harness
phase: prd
created: 2026-06-04
framework_version: v7.9.1
work_type: Feature
work_subtype: framework_feature
primary_metric: try_repo_test_coverage_pct_of_write_time_gates
linear: FIT-88
---

# F16 — Try-repo pre-commit harness | Phase 1 PRD

> Locks Q1-Q5 from Phase 0 Research + freezes constants. After this PRD ships, Phase 2 Tasks breaks the work into commit-sized steps; Phase 4 implements.

## 1. Problem statement

The framework has 16 write-time gates enforced via `.githooks/pre-commit` (a Bash shell script) invoking Python gate dispatchers (`scripts/check-state-schema.py`, `scripts/check-case-study-preflight.py`). Today's test coverage:

- **Unit tests:** every gate function has function-level tests asserting its return value given synthetic inputs.
- **Dispatch tests (F14, PR #317 pattern):** 8/16 gates have a `test_main_dispatch_<gate>()` test that invokes `main()` end-to-end via monkey-patched IO helpers (`collect_staged_state_files`, `collect_all_staged_files`, `GATE_COVERAGE_LEDGER`). Catches most regressions in the gate registration + skip semantics + Mechanism A emission paths.

What's NOT tested: the **`.githooks/pre-commit` shell script itself** — its environment-variable passing, subprocess exit-code handling, and interaction with real `git status --porcelain` output. Plus a class of bugs that only surface in a real-filesystem real-git-repo context (HOME pollution, unicode-named files, deleted-then-recreated state, cross-platform Bash differences).

F14 closed Phase B (the monkey-patch surface). F16 closes Phase C (the integration surface).

## 2. Success metrics

| Metric | Tier | Baseline | Target | Review at |
|---|---|---|---|---|
| `try_repo_test_coverage_pct_of_write_time_gates` | T1 | 0% (0/16) | 100% (16/16) at v7.9.1 ship | 2026-06-11 |
| `try_repo_harness_wall_clock_seconds` | T1 | n/a | <60s in CI | nightly post-ship |
| `try_repo_false_positive_rate_pct` | T1 | n/a | <5% during 14d advisory soak | 2026-06-25 |
| `regressions_caught_that_f14_missed_per_90d` | T1 (advisory) | n/a | ≥1 by 2026-09-04 | 2026-09-04 |

## 3. Locked design decisions

### Q1 — LOCKED: Subprocess invocation

`subprocess.run([".githooks/pre-commit"], cwd=throwaway_repo, env=clean_env, check=False)`. Treats pre-commit as a black box. Why: the entire point of F16 vs F14 is to test the shell script's shell-fork behavior, env-var inheritance, exit-code handling. In-process invocation defeats the purpose.

**Override condition:** if wall-clock budget breach (Q3 + Q5 combined) forces parallelism beyond pytest-xdist's reasonable shard count (>16 workers), revisit in Phase 5. Not anticipated.

### Q2 — LOCKED: Hybrid fixture format

- **state.json fixtures:** YAML-based partial-record dataclass + `make_state_json(overrides: dict) -> Path` builder that merges with a canonical baseline at `tests/fixtures/_baseline/state.json`. Reduces maintenance: schema additions update the baseline only; fixture YAML only mentions fields it deliberately mutates.
- **case study + log fixtures:** canonical `.md` + `.log.json` files under `tests/fixtures/<gate-id>/{positive,negative}/`. Content-heavy and varied; YAML abstraction would harm readability.

**Drift mitigation:** Phase 5 includes a round-trip test that loads a real production state.json (latest `git log -1` on a known shipped feature), feeds it through the YAML builder, and asserts byte-identity. If drift detected, fail loud.

### Q3 — LOCKED: Single CI job + pytest parametrize + JUnit XML

One GHA job runs `pytest -k try_repo --junitxml=try-repo.xml`. JUnit XML uploaded as an artifact; GitHub annotations populated via the existing `enricomi/publish-unit-test-result-action` step (already wired for the F14 dispatch tests). All 32 tests run; aggregate failure visibility.

**Why not per-gate matrix:** 16 jobs × ~30s setup cost = 8 wasted minutes/run + GHA matrix limits + billing impact. Single job at <60s is the better trade.

### Q4 — LOCKED: pytest `tmp_path` auto-cleanup

`@pytest.fixture(scope="function")` returning a `tmp_path`-based throwaway repo. `tmp_path` is pytest-managed; no special cleanup discipline needed. Module-scope fixtures (which would survive between tests) are explicitly banned in the test layout.

### Q5 — REVISED 2026-06-04 during T3 development: `GATE_COVERAGE_LEDGER_DISABLED=1` env toggle

**Original spec:** `GATE_COVERAGE_LEDGER` env-var path-override.

**Reality discovered by the Q5 enforcement test:** production code uses `GATE_COVERAGE_LEDGER` as a **module-level constant** (`scripts/check-state-schema.py:61`), not an env var. The real opt-out is `GATE_COVERAGE_LEDGER_DISABLED=1` (line 1544) which skips the ledger write entirely.

**The misunderstanding traced to:** F14 dispatch tests use `monkeypatch.setattr(_mod, "GATE_COVERAGE_LEDGER", ...)` to override the module constant. That works in-process but NOT across subprocess boundary, which is what F16 actually needs.

**Revised mechanism:** try-repo subprocess must include `env["GATE_COVERAGE_LEDGER_DISABLED"] = "1"`. Per-test assertions rely on stderr + exit code rather than ledger row inspection. This is strictly stronger evidence — `rc != 0` proves the gate fired; a ledger row only proves a row was emitted.

**Test:** Phase 4 T3 includes `test_canonical_gate_coverage_ledger_untouched_after_run` which captures the canonical ledger's mtime + size before a try-repo run and asserts both unchanged after. This caught the original misdesign during T3 development (the wrong override silently produced contamination; the new DISABLED toggle PASSED the assertion immediately).

**Follow-up tracked but NOT in scope for v7.9.1:** add a real env-var path-override (`GATE_COVERAGE_LEDGER_OVERRIDE=<path>`) to scripts/check-state-schema.py if a future test wants to ASSERT ledger emission was correct (instead of skipping). That would be a separate small-tier feature.

## 4. Frozen constants

```python
# scripts/tests/test_try_repo_harness.py
THROWAWAY_REPO_INIT_FILES = {
    ".gitignore": ".claude/logs/*\n*.pyc\n",
    "CLAUDE.md": "# F16 try-repo test fixture\n",
    "Makefile": ".PHONY: dummy\ndummy:\n\t@echo F16 test fixture\n",
}
PRE_COMMIT_TIMEOUT_S = 30
FIXTURE_DIR = "tests/fixtures"
PRE_COMMIT_HOOK_PATH = ".githooks/pre-commit"
GATE_COVERAGE_LEDGER_ENV = "GATE_COVERAGE_LEDGER"  # Python gates honor this
```

## 5. Scope (in / out)

### In scope

- 16 write-time gates × 1 positive fixture + 1 negative fixture each = 32 fixture pairs
- `scripts/tests/test_try_repo_harness.py` with 32 parametrized test cases
- `tests/fixtures/<gate-id>/{positive,negative}/` directory layout
- CI workflow extension (single job, `try_repo` pytest mark)
- Deliberately-introduced regression test (Phase 5) — patch one gate to silently no-op, confirm try-repo catches it
- CLAUDE.md note on the try-repo discipline + fixture-creation rule for new gates
- `docs/architecture/dev-guide-v1-to-v7-7.md` §4 gate catalog gets a "try-repo coverage" column
- Source case study + showcase MDX

### Out of scope

- **Cycle-time check coverage** — separate F-candidate (the cycle checks `integrity-check.py` are tested via `test_integrity_check_dispatch.py` already)
- **`make integrity-check` end-to-end test** — covered by the existing dispatch test
- **Bash-only fixtures (i.e., test the hook without Python invocation)** — every gate IS Python; no value in testing Bash-only
- **Cross-platform test matrix (Linux + macOS + Windows)** — CI runs on `macos-15` already; no Windows target for the framework
- **Performance benchmarking** — beyond the <60s wall-clock cap, no per-gate timing reporting

## 6. Acceptance criteria

PR ships if all of:

1. `pytest scripts/tests/test_try_repo_harness.py -v` reports 32 test functions, all passing
2. `pytest -k try_repo --collect-only` shows exactly 16 positive + 16 negative test cases
3. CI workflow runs the try-repo job in <60s wall-clock (3 consecutive runs)
4. Mechanism A canonical `.claude/logs/gate-coverage.jsonl` is NOT touched by any try-repo test run (verified by pre/post diff in a Phase 5 test)
5. Deliberately-introduced regression test (Phase 5 T7) catches a silent-no-op patch to at least one gate (proves F16 catches what F14 monkey-patch misses)
6. `make verify-local` passes with the new test file
7. `make integrity-check` baseline unchanged (0+0)
8. CLAUDE.md + dev-guide updates land in the same PR

## 7. Kill criteria

If any of these fire during the 14-day advisory soak window (~2026-06-04 → 2026-06-18 if shipped on time), revert via single-line opt-out:

- **K1** Harness wall-clock breaches 5 min in CI on 3 consecutive runs → operators will skip locally; defer to F16.1 with sharding
- **K2** False-positive rate >5% during calibration window → fixtures don't survive real-world pre-commit state; redesign fixture-build pipeline
- **K3** Maintenance burden >2h per new gate's fixture pair → discipline becomes a barrier; relax to "≥1 of (try-repo, dispatch test) required" instead of mandatory try-repo

## 8. Rollback plan

Harness is opt-in via pytest mark `@pytest.mark.try_repo` (or `-k try_repo` selector). Removing the CI job step is a 1-line revert in `.github/workflows/ci.yml`. The fixture files + test file can stay on disk (no production code touched) — disabling the test run is a single PR.

## 9. Risk register

| Risk | Probability | Severity | Mitigation |
|---|---|---|---|
| Subprocess timing variance >60s on slow GHA runners | LOW | MED | 30s per-test timeout + retry-on-flake (max 1 retry) via pytest-rerunfailures |
| Fixture maintenance burden | MED | MED | Q2 hybrid format + Phase 5 round-trip test |
| HOME pollution causes test-pass-locally-fail-CI | MED | HIGH | Throwaway repo uses `HOME=tmp_path` override in addition to `cwd` — full env scrub |
| Gate-coverage telemetry contamination | LOW (with Q5) | HIGH | Q5 LOCKED + Phase 4 explicit assertion |
| Operators skip running locally | MED | LOW | Add to `make verify-local`; CI catches anyway |
| New gate added without try-repo fixture | HIGH (without enforcement) | MED | Successor T1 GATE_TEST_MISSING meta-gate enforces this at PR review (separate work item) |

## 10. Phase 2 Tasks preview

(Locked task IDs from state.json — copy to tasks.md in Phase 2):

| Task | Effort |
|---|---|
| T2 fixture dir layout + `tests/fixtures/_baseline/state.json` canonical | 0.2d |
| T3 `try_repo_harness.py` with `make_throwaway_repo()` + `run_precommit(repo, files)` | 0.3d |
| T4 16 gate fixtures (positive + negative each) | 0.7d |
| T5 32 test functions | 0.5d |
| T6 CI workflow extension | 0.2d |
| T7 regression-test deliberate-no-op verification | 0.3d |
| T8 CLAUDE.md note | 0.1d |
| T9 dev-guide §4 column | 0.2d |
| T10 case study + showcase MDX | 0.4d |
| T11 advisory→enforced calibration (14d wait + flip PR) | n/a (calendar) |

**Total ~3 days code work + 14d soak.** Earliest enforced ship: 2026-06-18 (T+14d).

## 11. Out-of-band decisions deferred to Phase 2

- Test file naming: `test_try_repo_harness.py` (single file) vs `test_try_repo_<gate>.py` (one per gate). Phase 2 decides; recommended: single file with parametrize.
- Fixture YAML schema: define in Phase 2 once `_baseline/state.json` exists.
- CI job ordering: parallel-with vs sequential-after F14 dispatch tests. Phase 2 decides; recommended: parallel (independent surfaces).

## 12. Cross-references

- Predecessor: `framework-f14-f15-dispatch-test-coverage` case study (shipped 2026-05-23)
- Phase 0 Research: `.claude/features/f16-try-repo-harness/research.md`
- Spec: `docs/master-plan/infra-master-plan-2026-05-12.md` §3.4 Theme G F16 (RICE 48.0)
- Successor: T1 GATE_TEST_MISSING meta-gate (RICE 53.3, post-F16)
- Linear: FIT-88 (Urgent, parent FIT-73 v7.9.1 Test Discipline Foundation)
- PR (Phase 0 + 1): #607
