# F16 — Try-repo pre-commit harness | Phase 0 Research

> Created 2026-06-04 during Phase E exit batch. v7.9.1 build window open.

## 1. Why this exists

The framework currently has two layers of gate testing:

| Layer | What it tests | Surface | Catches |
|---|---|---|---|
| **Unit** | Individual gate functions | `scripts/tests/test_check_state_schema.py` etc. | Wrong field-name logic, wrong regex, wrong return value |
| **Dispatch (F14, PR #317 pattern)** | `main()` end-to-end with monkey-patched IO | `scripts/tests/test_check_state_schema.py::test_main_dispatch_*` | Wrong gate registration, wrong skip semantics, wrong Mechanism A row emission |
| **Try-repo (F16, THIS)** | The real `.githooks/pre-commit` shell script invoking the real Python gates against a real `git status` output in a real git repo | New `scripts/tests/test_try_repo_harness.py` (or similar) | Hook composition bugs, regex-match edge cases on real git porcelain output, HOME-pollution issues, environment-variable inheritance bugs, shell-fork bugs |

F14's dispatch pattern (PR #317) closed 50% of write-time gates (8/16) by monkey-patching `collect_staged_state_files()` etc. and invoking `main()` directly. It catches the most common regression class. But it explicitly does **not** exercise:

- The Bash `.githooks/pre-commit` script itself — its shell-fork logic, env-var passing to the Python subprocesses, exit-code handling, and any pre-Python gate logic
- The interaction between the gate and `git status --porcelain` real output (e.g., what happens when staged files have unicode names, spaces, deleted-then-recreated state)
- HOME-directory pollution (e.g., a gate that reads `~/.gitconfig` behaves differently in CI vs. operator's machine)
- Cross-platform fork/exec issues (e.g., macOS vs. Linux Bash differences)

External research synthesis (infra-master-plan §3.4 Theme G note): "Highest-leverage single change."

## 2. Design decisions to lock in Phase 1 PRD

### Q1 — Subprocess vs in-process

**Option A: Subprocess.** `subprocess.run([".githooks/pre-commit"], cwd=throwaway_repo, env=clean_env, check=False)`. Treats pre-commit as a black box, captures stdout/stderr/exit code, makes assertions against those.

**Option B: In-process.** Read `.githooks/pre-commit` content, parse out the Python invocations, run each via `runpy.run_path()` or direct import. Faster, but doesn't test the shell script itself.

**Recommendation:** Option A. The whole point of F16 vs F14 is to test the shell script. Subprocess overhead per test is ~50-100ms; 16 gates × 2 fixtures × 2 paths = 64 tests = ~3-6s total. Acceptable.

**Risk if wrong:** if subprocess is too slow at 64 tests we shard; we don't fall back to in-process.

### Q2 — Fixture format

**Option A: Canonical state.json.** Each fixture is a full state.json file under `tests/fixtures/<gate-id>/{positive,negative}/state.json`. Pro: realistic; Con: high maintenance (any schema addition forces 32+ fixture updates).

**Option B: Partial-record YAML + state.json builder.** Fixtures are `pytest`-friendly dataclass instances that merge with a canonical baseline. Pro: low-maintenance, easier to read; Con: drift potential between baseline and real state.json.

**Recommendation:** Option B for fields, Option A for `case_study.md` + `.log.json` (which are content-heavy and varied). Hybrid.

**Risk if wrong:** Option-B drift causes false-positives. Mitigation: a Phase 5 test that round-trips a real production state.json file through the YAML builder and asserts byte-identity. Detect drift early.

### Q3 — CI matrix shape

**Option A: Per-gate job.** Each gate has its own `gha` job. Pro: clear "which gate broke"; Con: 16-32 concurrent jobs, billing impact, GHA matrix limits.

**Option B: Single job with pytest parametrize.** One job runs all try-repo tests via `pytest -k try_repo`. Pro: cheap, simple; Con: full job aborts on first failure (per default).

**Option C: Single job with `--continue-on-error` semantics + JUnit XML.** Same as B but `pytest --continue-on-collection-errors` + `pytest-rerunfailures`. Pro: collects all failures in one pass; Con: slightly more complex setup.

**Recommendation:** Option C. Single job, all tests, JUnit XML → GitHub annotations show which gate(s) failed.

### Q4 — Worktree cleanup discipline

Throwaway repos accumulate in `/tmp` if cleanup fails. `pytest` fixtures with `yield` + finally-block cleanup are the canonical approach.

**Recommendation:** `pytest.fixture(scope="function")` returning a `tmp_path`-based repo; `tmp_path` is auto-cleaned by pytest. No special discipline needed — just don't introduce module-scope fixtures that survive between tests.

### Q5 (new, surfaced during research) — `gate-coverage.jsonl` pollution

If the try-repo harness invokes the real pre-commit which writes to `.claude/logs/gate-coverage.jsonl`, every test run will add ~16 rows to the canonical telemetry stream. This contaminates the Mechanism A telemetry used for advisory→enforced promotion decisions.

**Recommendation:** Override `GATE_COVERAGE_LEDGER` env var (or symlink the path) to a per-test `tmp_path/gate-coverage.jsonl` during try-repo runs. The dispatch tests already do this (`tmp_gate_coverage_ledger` fixture); the try-repo harness should adopt the same pattern.

## 3. Backwards-compatibility analysis

F14 dispatch tests stay. F16 adds a new test category — doesn't replace anything. CI workflow gains a new job (or a new pytest mark `@pytest.mark.try_repo`) that runs in addition to existing tests.

## 4. Effort breakdown

| Task | Days |
|---|---|
| T1 PRD locking decisions Q1-Q5 | 0.3 |
| T2-T3 harness scaffold + fixture dir layout | 0.5 |
| T4 fixtures for 16 gates × 2 fixtures each | 0.7 |
| T5 test functions × 32 | 0.5 |
| T6 CI workflow | 0.2 |
| T7 regression-test verification | 0.3 |
| T8-T10 docs + case study | 0.5 |
| Total | **~3 days** |

Matches the post-v7-9-candidate-plan estimate ("F16 ~3 days").

## 5. Risks + mitigations

| Risk | Probability | Mitigation |
|---|---|---|
| Subprocess overhead pushes wall-clock >60s | LOW (math: 32 tests × 100ms = 3.2s; ample headroom) | If hit, shard tests by gate-id parametrize batch |
| Fixture maintenance burden | MED | Q2 Option-B hybrid reduces it; Phase 5 round-trip test catches drift |
| HOME pollution edge cases caught | MED (this is also the value!) | If a gate IS HOME-polluted, fix the gate — not the harness |
| Gate-coverage telemetry contamination | HIGH if Q5 not addressed | Q5 pattern (env-var override) mandatory in Phase 1 PRD |
| Operators skip running locally | MED | Add to `make verify-local`; CI catches anyway |

## 6. Phase 1 PRD inputs

Phase 1 PRD will lock Q1-Q5 + freeze the constants:
- `THROWAWAY_REPO_INIT_FILES = [".gitignore", "CLAUDE.md", "Makefile"]` (the minimal set needed for `.githooks/pre-commit` shell script to not error on missing files)
- `PRE_COMMIT_TIMEOUT_S = 30` (per-test wall-clock cap)
- `FIXTURE_DIR = "tests/fixtures/<gate-id>/{positive,negative}/"`

## 7. Cross-references

- Predecessor: `framework-f14-f15-dispatch-test-coverage` (case study `docs/case-studies/framework-f14-f15-dispatch-test-coverage-case-study.md`, shipped 2026-05-23) — established the monkey-patch pattern; F16 is the integration-test successor.
- Successor candidates: T1 GATE_TEST_MISSING meta-gate (RICE 53.3) — once F16 exists, can enforce "every new gate must add a try-repo fixture pair" at PR review.
- Linear: FIT-88 (Urgent, parent epic FIT-73 v7.9.1 Test Discipline Foundation).
- Spec: infra-master-plan §3.4 Theme G F16 + this file.
