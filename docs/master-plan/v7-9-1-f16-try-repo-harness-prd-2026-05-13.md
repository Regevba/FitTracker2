# F16 — Try-Repo Harness for Gate Fixture Testing — Detailed PRD

**Status:** v7.9.1 candidate — detailed PRD draft
**Parent:** [`docs/superpowers/specs/2026-05-08-framework-v7-9-candidates.md`](../superpowers/specs/2026-05-08-framework-v7-9-candidates.md) (F16 in roster)
**Sibling reference:** [`docs/master-plan/infra-master-plan-2026-05-12.md`](./infra-master-plan-2026-05-12.md) §3.6.3 (v7.9.1 docket) and §3.5 (Calibration Protocol)
**Created:** 2026-05-13
**Earliest build window:** 2026-06-04 (after v7.9 Phase E exit per Layer Stacking Rule §3.5.2)
**Latest ship target:** 2026-06-11 (so F14 + F18 can begin Phase A on top of it)
**Effort estimate:** **0.5 wall-week** (≈ 16–20 focused hours) for the harness itself + per-gate fixture authoring. RICE master-plan estimate is 0.5w; this PRD does not revise that.
**Calibration class:** Test infrastructure (advisory at ship per §3.5; full B→C→D→E walk required because it is new infra). v7.9.1 ships F16 advisory; v8.0 promotes to enforced.

---

## §1 TL;DR

F16 builds a **try-repo end-to-end harness** that spawns a throwaway git repo, copies fixtures (positive = should fire, negative = should skip) from `tests/fixtures/gate-fixtures/<GATE_NAME>/`, stages them, runs the **real** `.githooks/pre-commit` script via subprocess, and asserts that each write-time gate produces the expected fire/skip outcome.

It exists because every current test in [`scripts/tests/`](../../scripts/tests/) stubs at the function or subprocess level — none of them exercise the actual git plumbing that PR #317 broke. **F16 would have caught the `BRANCH_ISOLATION_VIOLATION` Mode B silent-pass on the first run** (#3 in the [Observed Patterns Catalog](../../.claude/integrity/observed-patterns.md)), and it is the documented foundation that F14 (per-gate dispatch tests) and F18 (mutation testing) both stack on per the Layer Stacking Rule.

---

## §2 Problem Statement

### 2.1 The PR #317 incident, in detail

`BRANCH_ISOLATION_VIOLATION` Mode B is a v7.8.1 write-time gate that fires on commits where staged files match infra-path globs (`.githooks/*`, `.github/workflows/*`, `scripts/*`, `.claude/skills/*`, `.claude/shared/*`, `CLAUDE.md`, `docs/architecture/*`, `Makefile`) AND the current branch is non-feature.

Between 2026-05-07 (ship) and 2026-05-12 (fix), the gate **never fired** on infra-only commits because [`scripts/check-state-schema.py:main()`](../../scripts/check-state-schema.py) early-returned at `if not files: return 0` before the gate's dispatch site was reached. Infra-only commits — by definition — staged no `state.json` files, so the early return triggered and the Mode B classifier was unreachable. ~9 HADF Phase 2-bis commits in Block A landed without their Mode B check.

The root cause is a class of bug:

> **A meta-policing gate that silently fails because its dispatch site is unreachable for the common case, while the gate's internal logic is fully unit-tested.**

The audit triggered by PR #317 found 4 other write-time gates with the same vulnerability shape (F14 scope) plus 5 gates with zero unit coverage at all (F15 scope).

### 2.2 Why existing test infrastructure cannot catch this class of bug

[`scripts/tests/`](../../scripts/tests/) has 13 test files (~2,300 LoC) covering ~16 distinct gates. Their coverage shapes:

| Test pattern | What it asserts | What it CANNOT catch |
|---|---|---|
| **Direct function call** (e.g. `test_check_state_schema.py`) | Internal check function (`check_branch_isolation_violation_commit_level`, `check_feature_closure_completeness`, etc.) returns the expected findings for a synthetic input | Whether `main()` ever calls the function on real git state |
| **monkey-patched dispatch** (e.g. `test_gate_coverage.py`) | `coverage.candidate(GATE)` is invoked when the function is called with monkey-patched helpers | Whether the function is called at all from the production `main()` path on a real commit |
| **Pre-commit self-test** (`test_pre_commit_self_test.py`) | The `.githooks/pre-commit` header matches the gate inventory in the script files | Whether the script files' `main()` actually fires those gates when invoked |
| **Synthetic-fixture subprocess call** (e.g. `test_check_case_study_preflight.py`) | Calling the script with explicit file arguments produces expected output | Whether `--staged` mode (the production mode) reaches the same code path |

The common thread: **none of these tests stage real files in a real `git` index and let the actual pre-commit hook run end-to-end.** All of them work by either (a) calling Python check functions directly, (b) invoking the script with explicit file paths (bypassing `--staged`), or (c) asserting header text.

PR #317's bug lived in the seam between `collect_staged_state_files()`, the early-return `if not files: return 0`, and the Mode B dispatch site. **No test in the repo exercised that seam.**

### 2.3 What an end-to-end harness would have caught on the first run

A try-repo harness that:

1. `git init`s a temp directory
2. Copies one positive fixture (an infra-only file change with no state.json) into the temp repo
3. Stages it (`git add`)
4. Invokes `.githooks/pre-commit` directly via subprocess
5. Asserts the gate's expected outcome (Mode B advisory present in stderr)

…would have failed on day one of v7.8.1, because the gate's advisory would never have appeared. The harness is the test-of-the-tests: it asserts production behavior, not function-internal behavior.

This pattern is the externally-validated industry standard for policy-gate testing:

- **[pre-commit `try-repo`](https://pre-commit.com/)** — the framework's own recommendation for testing hooks end-to-end
- **[Semgrep `rule.yml` ↔ `rule.test.yml` enforced pairing](https://semgrep.dev/docs/writing-rules/testing-rules)** — every rule MUST have positive + negative fixtures
- **[OPA `opa test --coverage`](https://www.openpolicyagent.org/docs/policy-testing/)** — policy tests run the actual policy engine on JSON inputs
- **[ESLint `RuleTester`](https://eslint.org/docs/latest/extend/custom-rules#rule-unit-tests)** — every rule has explicit `valid` and `invalid` code samples

FT2 has none of these. F16 adds the equivalent.

### 2.4 What we lose by NOT building F16

| Cost | Manifest |
|---|---|
| Silent-pass debt accumulates | The 4 dispatch-untested gates (F14 scope) + 5 zero-coverage gates (F15 scope) may already have PR-#317-class bugs we don't know about. |
| F14, F18 cannot be built safely | Per §3.5.2 Layer Stacking Rule, F14 (per-gate dispatch tests) and F18 (mutation testing) require F16 in Phase E first. If F16 slips, the whole Theme G stack slips. |
| `Observed Patterns Catalog` cannot be exercised | Each entry in [`.claude/integrity/observed-patterns.md`](../../.claude/integrity/observed-patterns.md) documents a gate-firing pattern, but there is no automated way to assert the pattern still holds. F16's positive/negative fixtures are the executable form of each catalog entry. |
| Future v8.0 gates (e.g., F19 `CSV_TAXONOMY_DRIFT`, F20 `GA4_MCP_DISCONNECTED`) cannot be calibrated cheaply | New gates need Phase A artifacts including a fixture. F16 standardizes where fixtures live and how they are exercised. |

---

## §3 Approach

### 3.1 Core design choice — subprocess against real `.githooks/pre-commit`

The harness invokes `.githooks/pre-commit` as a real subprocess against a real (temp) git repo. **Not** by importing `check-state-schema.py` and calling `main()` in-process.

Rationale:

- The bug class F16 targets is dispatch-level. In-process invocation can be defeated by the same monkey-patching that already exists in `test_gate_coverage.py`.
- Real subprocess invocation includes the bash hook wrapper (line 82 of [`.githooks/pre-commit`](../../.githooks/pre-commit)) which itself can drift (e.g., a future PR replaces `set -euo pipefail` with `set -eo pipefail` and pipe failures become silent).
- Real `git` plumbing is exercised: `git add`, `git diff --cached --name-only`, `git rev-parse`, `git symbolic-ref` are all part of the dispatch path and have all caused bugs in the framework's history.

### 3.2 Fixture-per-gate, positive+negative pairing

Each gate gets a directory at `tests/fixtures/gate-fixtures/<GATE_NAME>/` containing two subdirectories:

```
tests/fixtures/gate-fixtures/
  BRANCH_ISOLATION_VIOLATION_MODE_B/
    positive/                 # commit that should fire the gate
      stage/
        scripts/dummy.py
      manifest.json           # branch, commit message, expected outcome
    negative/                 # commit that should NOT fire the gate (skip path)
      stage/
        FitTracker/Views/Home.swift
      manifest.json
  BRANCH_ISOLATION_VIOLATION_MODE_C/
    positive/
      stage/
        .claude/features/dummy-feat/state.json  # current_phase change
      manifest.json
    negative/
      ...
  FEATURE_CLOSURE_COMPLETENESS/
    positive/
      stage/
        .claude/features/dummy-feat/state.json   # current_phase=complete, missing kill_criteria_resolution
      manifest.json
    negative/
      ...
  ...
```

**Fixture manifest schema** (`manifest.json` per fixture):

```json
{
  "gate": "BRANCH_ISOLATION_VIOLATION_MODE_B",
  "polarity": "positive",                  // positive | negative
  "expected_outcome": {
    "exit_code": 0,                        // hook exit code
    "stderr_contains": ["[ADVISORY] BRANCH_ISOLATION_VIOLATION (Mode B)"],
    "stderr_does_not_contain": [],
    "gate_coverage_emission": {            // expected ledger entry for Mechanism A
      "gate": "BRANCH_ISOLATION_VIOLATION",
      "candidates_min": 1,
      "checked_or_skipped_min": 1
    }
  },
  "git_setup": {
    "branch": "main",                      // branch to set up before staging
    "initial_files": [],                   // files committed BEFORE staging
    "env_overrides": {}                    // any env vars to set
  },
  "stage_files": ["scripts/dummy.py"],     // relative paths under stage/
  "framework_version_tag": "v7.8.1",
  "introduced_by": "PR #244",
  "notes": "Infra-only commit on main; should fire Mode B advisory."
}
```

The manifest is intentionally **declarative** — the harness reads it, sets up the temp repo to match, runs the hook, then asserts the expected outcome. No fixture-specific Python code per gate (avoids the rot pattern documented in [`observed-patterns.md`](../../.claude/integrity/observed-patterns.md) §2 "Test fixture rot").

### 3.3 Test-runner integration

Single pytest test file at `scripts/tests/test_try_repo_harness.py` that:

1. Discovers every directory under `tests/fixtures/gate-fixtures/`
2. Parametrizes over (gate, polarity) tuples → ≥ 32 parametrized tests
3. For each, calls the harness library (`scripts/tests/try_repo_harness.py`)
4. Asserts the manifest's expected outcome

```python
@pytest.mark.parametrize("gate,polarity", _discover_fixtures())
def test_gate_fixture(gate: str, polarity: str, tmp_path: Path):
    fixture = load_fixture(gate, polarity)
    result = run_try_repo(fixture, tmp_path=tmp_path)
    assert_fixture_outcome(result, fixture.manifest)
```

Pytest's built-in `tmp_path` fixture handles cleanup automatically (deletes the temp repo after each test). The harness library is responsible for never writing outside `tmp_path`.

### 3.4 CI integration

Three CI surfaces:

| Surface | Trigger | Action |
|---|---|---|
| **PR builds** | every PR | Run F16 harness as part of `make test-framework`. Failures block the PR. |
| **Nightly cron** | 06:00 UTC | Run F16 harness against `origin/main` HEAD. Failures open `framework-status` issue (mirrors weekly cron pattern). |
| **`verify-local`** | dev `make verify-local` | Run F16 harness silently; surface failures with the same UX as `make integrity-check`. |

### 3.5 Cleanup contract

The harness library MUST:

1. Create the temp repo at `tmp_path / "try-repo"` (pytest-managed; auto-cleanup)
2. Set `GIT_DIR` and `GIT_WORK_TREE` env vars to scope all git commands to the temp repo
3. Set `GATE_COVERAGE_LEDGER_DISABLED=1` so harness runs don't pollute real telemetry
4. Set `FORCE_TRANSITION_CHECKS=1` ONLY when the fixture requests phase-transition enforcement (default off)
5. NEVER `cd` into the temp repo at the process level — use `cwd=` argument on `subprocess.run` exclusively. (Prevents pollution if pytest is run with `-p no:cacheprovider` or similar.)
6. NEVER call `git config --global` (use `-c` flags instead)
7. NEVER write outside `tmp_path` even on test failure

---

## §4 Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  scripts/tests/test_try_repo_harness.py     (pytest entrypoint) │
│  ─ parametrized over (gate, polarity)                           │
│  ─ owns assertion semantics                                     │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│  scripts/tests/try_repo_harness.py          (harness library)   │
│  ─ run_try_repo(fixture, tmp_path) -> HarnessResult             │
│  ─ load_fixture(gate, polarity) -> Fixture                      │
│  ─ _setup_temp_repo, _stage_fixture_files, _invoke_hook         │
│  ─ _read_gate_coverage_emissions (post-run, scoped)             │
└──────────────────────┬──────────────────────────────────────────┘
                       │ subprocess
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│  .githooks/pre-commit                       (real hook)         │
│  ─ runs check-state-schema.py + check-case-study-preflight.py   │
│  ─ scoped to temp repo via GIT_DIR/GIT_WORK_TREE                │
└─────────────────────────────────────────────────────────────────┘
                       ▲
                       │ reads
                       │
┌─────────────────────────────────────────────────────────────────┐
│  tests/fixtures/gate-fixtures/<GATE>/{positive,negative}/       │
│  ─ stage/         (files to be staged in the temp repo)         │
│  ─ manifest.json  (declarative expected-outcome contract)       │
└─────────────────────────────────────────────────────────────────┘
```

### 4.1 Components

| Component | Location | Purpose |
|---|---|---|
| **Harness library** | `scripts/tests/try_repo_harness.py` | Pure-Python; no test logic. Exposes `run_try_repo(fixture, tmp_path)` + helpers. |
| **Test runner** | `scripts/tests/test_try_repo_harness.py` | Pytest discovery + parametrization + assertions. |
| **Fixture root** | `tests/fixtures/gate-fixtures/` | New tree; mirrors gate inventory. |
| **Per-gate fixture dirs** | `tests/fixtures/gate-fixtures/<GATE>/{positive,negative}/` | Self-contained per gate; survives gate renames via the fixture's `manifest.json::gate` field (not directory name) as primary key. |
| **Fixture schema** | `tests/fixtures/gate-fixtures/_schema.json` | JSON Schema for `manifest.json`; validates at test discovery. |
| **CI workflow** | `.github/workflows/try-repo-nightly.yml` | Nightly cron + PR check; mirrors `integrity-cycle.yml` structure. |
| **Makefile target** | `Makefile`: `make try-repo-test` | Local one-shot; runs `pytest scripts/tests/test_try_repo_harness.py -v`. |

### 4.2 Why a library + runner split

Three reasons:

1. **F14 reuses the harness library.** Per-gate dispatch tests (F14) call `run_try_repo` directly with custom manifests, not through the parametrized runner. The library is the public API.
2. **F18 reuses fixtures.** Mutation testing (F18) needs the same fixtures to drive `mutmut`'s "did this mutant survive any test?" check. The fixture directory is the contract.
3. **Future product features can ride on the harness.** F19 (`CSV_TAXONOMY_DRIFT`) and F20 (`GA4_MCP_DISCONNECTED`) are analytics-observability gates that will land in v8.0; both will use F16 fixtures to validate Phase A artifacts before any production gate code lands.

### 4.3 Cross-repo scope

F16 is **FT2-only.** Per v7.8.2's documented cross-repo asymmetry policy ([spec](../superpowers/specs/2026-05-08-cross-repo-gate-asymmetry.md)), fitme-story does not host the pre-commit gate stack and therefore does not need a try-repo harness. If fitme-story later grows its own pre-commit layer (a v8.x feature, not in current plan), it gets its own harness copy then.

---

## §5 Per-Gate Coverage Plan

The harness ships with fixtures for every currently-deployed write-time gate **plus** stubs (positive-only, no negative) for the F19/F20 gates planned for v8.0. Gates emit to `gate-coverage.jsonl` via the `coverage.candidate(GATE)` calls in [`scripts/check-state-schema.py`](../../scripts/check-state-schema.py).

| # | Gate code | Source script | Positive fixture (should fire) | Negative fixture (should skip cleanly) |
|---|---|---|---|---|
| 1 | `SCHEMA_DRIFT_LEGACY_PHASE` | `check-state-schema.py:641` | state.json with legacy `phase` key | state.json with canonical `current_phase` |
| 2 | `SCHEMA_DRIFT_LEGACY_CREATED` | `check-state-schema.py:656` | state.json with legacy `created` key | state.json with canonical `created_at` |
| 3 | `FRAMEWORK_VERSION_FORMAT` | `check-state-schema.py:675` | state.json with `framework_version: "7.5"` (missing `v` prefix) | state.json with `framework_version: "v7.8"` |
| 4 | `ISOLATION_OPT_OUT_REASON_MISSING` | `check-state-schema.py:696` | state.json with `isolation_opt_out: true` + empty reason | state.json with `isolation_opt_out: true` + non-empty reason |
| 5 | `PR_NUMBER_UNRESOLVED` | `check-state-schema.py:713` | state.json with `pr_number: 999999` (never exists) | state.json with a resolvable PR number from cache |
| 6 | `PHASE_TRANSITION_NO_LOG` | `check-state-schema.py:841` | state.json with `current_phase` changed + no fresh log event | state.json with `current_phase` changed + paired log event in window |
| 7 | `PHASE_TRANSITION_NO_TIMING` | `check-state-schema.py:842` | state.json with `current_phase` changed + no `timing.phases.X.started_at` | state.json with timing block populated |
| 8 | `CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT` | `check-state-schema.py:308` | state.json `current_phase=complete`, post-v6, post-Mechanism-C, empty cache_hits[] | state.json `current_phase=complete` with populated cache_hits[] |
| 9 | `STATE_NO_CASE_STUDY_LINK` | `check-state-schema.py:392` | state.json `current_phase=complete` with no case_study link and no exempt tag | state.json with case_study link populated |
| 10 | `CU_V2_INVALID` | `check-state-schema.py:435` | state.json with `cu_v2` block missing `complexity` factor | state.json with full `cu_v2` block |
| 11 | `STATE_OWNER_MISSING` | `check-state-schema.py:475` | state.json with no `state_owner` field | state.json with `state_owner: "ft2"` |
| 12 | `STATE_OWNER_INVALID` | `check-state-schema.py:476` | state.json with `state_owner: "bogus"` | state.json with valid enum value |
| 13 | `STATE_OWNER_LOCATION_MISMATCH` | `check-state-schema.py:535` | state.json at FT2 path with `state_owner: "fitme-story"` | state.json at FT2 path with `state_owner: "ft2"` |
| 14 | `BRANCH_ISOLATION_VIOLATION` Mode B | `check-state-schema.py:1054` | Infra-path commit on `main` (the PR #317 scenario) | Infra-path commit on `feature/x` |
| 15 | `BRANCH_ISOLATION_VIOLATION` Mode C | `check-state-schema.py:1412` | `current_phase` change on `main` without `isolation_opt_out` | `current_phase` change on `feature/x` |
| 16 | `FEATURE_CLOSURE_COMPLETENESS` | `check-state-schema.py:1252` | state.json `current_phase=complete` + missing `kill_criteria_resolution` | state.json with all 7 required frontmatter fields + Q6 parity |
| 17 | `BROKEN_PR_CITATION` | `check-case-study-preflight.py` | Case study citing `PR #999999` not in cache | Case study with resolvable PR cite + `pr_citation_exempt` for known gaps |
| 18 | `CASE_STUDY_MISSING_TIER_TAGS` | `check-case-study-preflight.py` | Scoped case study post-2026-04-21 with no T1/T2/T3 tag | Case study with at least one tier tag present |
| 19 | `CASE_STUDY_MISSING_FIELDS` | `check-case-study-preflight.py` | Case study with no `framework_version` frontmatter | Case study with all required frontmatter fields |
| 20 | `PARTIAL_SHIP_TERMINAL` | `check-state-schema.py` (validate_file) | state.json with `partial_ship: true` + `current_phase=complete` | state.json with `partial_ship: true` + `current_phase=test` |
| **Planned (stub positive only — no production code yet)** | | | | |
| 21 | `CSV_TAXONOMY_DRIFT` (F19, v8.0) | TBD | CSV row with event not in taxonomy | CSV row matching taxonomy |
| 22 | `GA4_MCP_DISCONNECTED` (F20, v8.0) | TBD | Synthetic "MCP unreachable" state | Synthetic "MCP healthy" state |

**Fixture sample-size minimum:** 1 positive + 1 negative per gate. **Stretch goal:** add a `polarity: edge-case` directory for known boundary conditions (e.g., a state.json with the legacy `created` key AND the canonical `created_at` key — the dual-read parser case from v7.8 Mechanism B). Edge-case fixtures land in v8.0 if any.

**Total minimum: 40 fixtures (20 gates × 2 polarities).** With F19/F20 stubs: 42. With stretch edge-cases for the 6 most fire-frequent gates: 48.

**Cross-reference to Observed Patterns Catalog:** Each entry in [`.claude/integrity/observed-patterns.md`](../../.claude/integrity/observed-patterns.md) §1 documents a real-world firing pattern for a specific gate. F16's negative fixture for that gate is the executable form of the "Why expected" + "Silence path" lines. The catalog entry `#3 BRANCH_ISOLATION_VIOLATION Mode B` is directly tied to fixture #14 above.

---

## §6 Phases (per the 22-day Calibration Protocol)

Per [`infra-master-plan-2026-05-12.md`](./infra-master-plan-2026-05-12.md) §3.5, every new framework infrastructure layer walks Phases A → B → C → D → E. F16 is test infrastructure, not a new gate, but it still walks the protocol because it becomes load-bearing for F14 + F18.

### Phase A — Specify (pre-code, 2026-05-13 → 2026-06-04)

**Status:** in progress. This PRD is part of Phase A.

**Required artifacts before any production code lands:**

- [x] This PRD (`docs/master-plan/v7-9-1-f16-try-repo-harness-prd-2026-05-13.md`)
- [ ] Fixture schema (`tests/fixtures/gate-fixtures/_schema.json`)
- [ ] At least one positive + negative fixture authored as proof of concept (recommend: `BRANCH_ISOLATION_VIOLATION_MODE_B` because its bug is the most-documented)
- [ ] One regression test stub (`scripts/tests/test_try_repo_harness.py` skeleton with parametrized discovery, expected to fail until harness ships)

**Exit criteria:** all 4 artifacts exist on a feature branch. PR reviewed but not merged.

### Phase B — Ship advisory + measure (2026-06-04 → 2026-06-11, 7 days)

**Scope:** harness ships in advisory mode. CI workflow runs nightly + on PR but does NOT block merges on failure (issues a sticky comment instead). All 20 gates have positive+negative fixtures landed.

**Required measurements during Phase B:**

- Harness execution wall-time per fixture (target: <500ms; max acceptable: 2s; hosted-runner overhead measured separately)
- Total nightly CI runtime (target: <5min for 40 fixtures)
- Flake rate per fixture (target: 0; flakes investigated and rooted)
- Number of fixtures that **disagree with current production behavior** (this is the silent-pass discovery signal — every disagreement is a candidate PR-#317-class bug)

**Exit criteria:** ≥7 days of nightly runs accumulated; total fixture pass-rate ≥ 95% (failures are either harness bugs or production silent-passes — both must be triaged); no harness-internal flakes.

### Phase C — Calibration gate (2026-06-11 → 2026-06-18, 7 days)

**Scope:** triage every disagreement found in Phase B. Each disagreement resolves as one of:

1. **Harness bug** — fix the harness, no production change
2. **Fixture bug** — fix the fixture's manifest expectations
3. **Production silent-pass** — open a v7.9.1 patch PR fixing the gate (and credit F16 in the case study)

Operator review: every `failure` row in the harness output across the 7-day window.

**Exit criteria:** all disagreements resolved into one of the three buckets above; zero unresolved disagreements remain.

### Phase D — Promotion decision (2026-06-18, 1 day)

**Promotion path:** harness flips from advisory to enforced — PR builds now BLOCK on harness failure (matches `make integrity-check` UX).

**Decision recorded in:**

- Updated CLAUDE.md (under "CI Pipeline" — `make try-repo-test` becomes a required gate within `verify-local`)
- This PRD's revision log (§13)
- Case study at `docs/case-studies/v7-9-1-f16-try-repo-harness-case-study.md` (Tier 2.3 tagged)
- Honesty ledger entry

**Reversibility:** single-line edit to the GitHub Actions workflow flips `continue-on-error: true → false`. Rollback time <2 min.

**Exit criteria:** decision made, reversibility rehearsed, telemetry continues.

### Phase E — Post-promotion validation (2026-06-18 → 2026-06-25, 7 days)

**Scope:** zero false-positive incidents in 7 days. If any false positive: roll back to advisory, file remediation, restart from Phase C.

**Exit criteria:** 7 clean days. F16 is now "stable" per the Layer Stacking Rule — F14 (per-gate dispatch tests) and F18 (mutation testing) can begin Phase A on top of it.

**Failure mode:** if Phase E doesn't exit clean by 2026-06-25, F14 and F18 are deferred to v8.1 (not v8.0) per §3.5.2.

---

## §7 Implementation Tasks

Effort estimates assume the author is familiar with the FT2 framework + pytest + GitHub Actions. Add 30% buffer for cold-start.

| # | Task | Files | Effort | Phase |
|---|---|---|---|---|
| T1 | Author this PRD | `docs/master-plan/v7-9-1-f16-try-repo-harness-prd-2026-05-13.md` | 1h | A (this commit) |
| T2 | Define fixture manifest JSON Schema | `tests/fixtures/gate-fixtures/_schema.json` | 30min | A |
| T3 | Author proof-of-concept fixture (BRANCH_ISOLATION_VIOLATION_MODE_B positive+negative) | `tests/fixtures/gate-fixtures/BRANCH_ISOLATION_VIOLATION_MODE_B/{positive,negative}/...` | 1h | A |
| T4 | Skeleton harness library (signatures + docstrings, no implementation) | `scripts/tests/try_repo_harness.py` | 30min | A |
| T5 | Skeleton parametrized test file | `scripts/tests/test_try_repo_harness.py` | 30min | A |
| T6 | Implement `_setup_temp_repo` helper (git init, initial commit, branch setup) | `scripts/tests/try_repo_harness.py` | 1.5h | B |
| T7 | Implement `_stage_fixture_files` (copy from `stage/` → temp repo, `git add`) | `scripts/tests/try_repo_harness.py` | 1h | B |
| T8 | Implement `_invoke_hook` (subprocess call to `.githooks/pre-commit` with scoped GIT_DIR / GIT_WORK_TREE / env) | `scripts/tests/try_repo_harness.py` | 1.5h | B |
| T9 | Implement `_read_gate_coverage_emissions` (scoped ledger reader; uses TMP-redirected `GATE_COVERAGE_LEDGER`) | `scripts/tests/try_repo_harness.py` | 1h | B |
| T10 | Implement `assert_fixture_outcome` (manifest → assertion logic) | `scripts/tests/test_try_repo_harness.py` | 1.5h | B |
| T11 | Author remaining 19 gate fixture pairs (each ≈ 30–45min including manifest authoring) | `tests/fixtures/gate-fixtures/<GATE>/{positive,negative}/` ×19 | 12h | B |
| T12 | Author F19/F20 stub fixtures (positive only, no production code) | 2 dirs | 1h | B |
| T13 | Add `make try-repo-test` Makefile target | `Makefile` | 15min | B |
| T14 | Add nightly CI workflow | `.github/workflows/try-repo-nightly.yml` | 1.5h | B |
| T15 | Wire into PR CI (`pr-integrity-check.yml`) — advisory only | `.github/workflows/pr-integrity-check.yml` | 30min | B |
| T16 | Phase B measurement: collect 7d of nightly runs; triage disagreements | (logs only) | spread over 7d | B |
| T17 | Phase C: resolve every disagreement (bug fixes + manifest fixes + production silent-pass PRs) | various | spread over 7d | C |
| T18 | Phase D: flip CI to blocking; update CLAUDE.md; write case study | `.github/workflows/*.yml`, `CLAUDE.md`, `docs/case-studies/v7-9-1-f16-try-repo-harness-case-study.md` | 2h | D |
| T19 | Phase E: monitor 7 days; if clean, declare stable | (operator-only) | spread over 7d | E |
| T20 | Extend [`Observed Patterns Catalog`](../../.claude/integrity/observed-patterns.md) cross-reference column linking each pattern entry to its fixture path | `.claude/integrity/observed-patterns.md` | 1h | E |

**Total focused-hour estimate (excluding spread-over-7d Phase B/C/E monitoring):** ≈ 27 hours. Fits within the 0.5 wall-week (≈ 20 working hours) target if monitoring is interleaved with other work, which is the v7.9.1 docket model.

### 7.1 PR sequencing (sub-PRs within F16)

To keep review tractable, F16 splits into **3 PRs**:

| Sub-PR | Scope | Reviewer load |
|---|---|---|
| **F16.A** — Harness skeleton + schema + PoC fixture | T1–T5 (Phase A deliverables) | ~200 LoC; reviewable in 30min |
| **F16.B** — Full harness implementation + 19 fixtures + Makefile + nightly CI | T6–T14 (Phase B deliverables) | ~1,200 LoC; bulk is fixture YAML/JSON; reviewable in 90min |
| **F16.C** — PR-CI wiring (advisory) + Phase B–C monitoring + Phase D flip | T15, T18 | ~50 LoC + CLAUDE.md edit |

T11 (the 19-fixture bulk) is the rate-limiting step. Recommend authoring fixtures in pairs sorted by gate complexity (start with `SCHEMA_DRIFT_LEGACY_*` — trivial — and end with `BRANCH_ISOLATION_VIOLATION_MODE_C` — most complex due to phase-transition state setup).

---

## §8 Test Plan

### 8.1 How to test the harness itself

The harness is itself code — it needs tests. Three layers:

**Layer 1: Unit tests on the harness library.**

`scripts/tests/test_try_repo_harness_internals.py` — tests `_setup_temp_repo`, `_stage_fixture_files`, `_invoke_hook` in isolation with synthetic inputs. Asserts:

- Temp repo gets `git init`'d with the right initial branch
- `git config user.{name,email}` is set (else commits fail)
- Stage files appear in `git diff --cached --name-only`
- Hook invocation respects `GIT_DIR` and `GIT_WORK_TREE` (test by setting them to a known-bogus path; expect graceful subprocess failure, not a real-repo mutation)

**Layer 2: Self-test fixtures.**

Two fixture pairs that test the harness's own behavior (not any production gate):

- `tests/fixtures/gate-fixtures/_meta_harness_smoke/positive/` — a fixture designed to ALWAYS fire (e.g., a state.json with deliberate legacy `phase` key). If this fixture doesn't fire, the harness is broken.
- `tests/fixtures/gate-fixtures/_meta_harness_smoke/negative/` — a fixture designed to NEVER fire (e.g., a state.json with all canonical fields). If this fixture fires, the harness has a false-positive bug.

Both are run as part of the parametrized suite and explicitly named in the case study as the "smoke test" pair.

**Layer 3: Meta-validation — does the harness actually catch PR-#317-class bugs?**

A deliberate regression: in a separate branch, revert PR #317's fix (move the early-return back above the Mode B dispatch site). Run the F16 harness. Assert that the `BRANCH_ISOLATION_VIOLATION_MODE_B/positive` fixture fails.

This is the **founding meta-test** — F16's reason for existing. Document it in the case study; don't commit the regression branch, but link to the GitHub Actions run that demonstrates the catch.

### 8.2 Meta-validation strategy: does F16 reduce silent-pass debt?

Operator-level measurement, not automated. At Phase D + 7 days (≈ 2026-06-25), the operator:

1. Counts F16-discovered silent-passes (i.e., production bugs found by Phase B/C triage)
2. Counts F16 fixture authoring effort (hours)
3. Counts production gate-bug incidents in the 30 days BEFORE F16 ship vs the 30 days AFTER

Recorded as Tier 2 (Declared) metric in the case study. Promoted to Tier 1 (Instrumented) when F17 (`last_fired_at` index) lands — F17 lets us count fire-frequency per gate as the proxy for "is this gate doing its job?"

### 8.3 Calibration data the harness produces

Each Phase B nightly run emits a JSON report at `.claude/logs/try-repo-harness-<date>.jsonl`:

```json
{
  "timestamp": "2026-06-05T06:00:00Z",
  "total_fixtures": 40,
  "passed": 38,
  "failed": 2,
  "disagreements": [
    {
      "gate": "STATE_OWNER_LOCATION_MISMATCH",
      "polarity": "positive",
      "expected_exit_code": 1,
      "actual_exit_code": 0,
      "expected_stderr_contains": ["STATE_OWNER_LOCATION_MISMATCH"],
      "actual_stderr": "",
      "category": "tbd"
    }
  ],
  "wall_time_seconds": 47.2
}
```

Phase C triage updates each disagreement's `category` to `harness_bug` / `fixture_bug` / `production_silent_pass`. Phase D requires zero `tbd` rows in the final 7-day window.

---

## §9 Dependencies

### 9.1 Upstream — what F16 needs

| Dependency | Source | Required by phase |
|---|---|---|
| v7.9 Phase E exit (post-promotion stable) | `infra-master-plan-2026-05-12.md` §3.6.2 | Phase B start (~2026-06-04) |
| `gate-coverage.jsonl` instrumentation in `check-state-schema.py` | Already shipped (v7.8 Mechanism A, PR #187) | Phase B (fixture manifests assert on emissions) |
| `FORCE_TRANSITION_CHECKS=1` env var support in `check-state-schema.py` | Already shipped (line 1487–1490) | Phase B (phase-transition fixtures) |
| `GATE_COVERAGE_LEDGER_DISABLED=1` env var support | Already shipped (line 1538) | Phase B (so harness runs don't pollute real telemetry) |
| PR cache freshness (`.cache/gh-pr-cache.json`) | v7.8.4 (PR #314, `scripts/ensure-pr-cache-fresh.py`) | Phase B (`BROKEN_PR_CITATION` + `PR_NUMBER_UNRESOLVED` fixtures need cache populated) |

All upstream dependencies are **shipped or in-flight on the v7.9 promotion track**. No blockers.

### 9.2 Downstream — what depends on F16

Per §3.5.2 Layer Stacking Rule and §3.6.4 v8.0 docket:

| Downstream | Relationship | Earliest start if F16 ships on schedule |
|---|---|---|
| **F14** — Per-gate `main()` dispatch tests | Hard dependency. F14's test pattern uses `run_try_repo` to invoke `main()` end-to-end on synthetic manifests rather than the in-process monkey-patched pattern that originally missed the PR #317 bug. | Phase A 2026-06-18; Phase B 2026-06-25 |
| **F18** — Mutation testing on dispatcher files | Soft dependency (could ship without F16 but loses meaningful mutation coverage). F18 needs F16 fixtures as the "did the mutant survive any real-world test?" input set. | Phase A 2026-06-25; Phase B 2026-07-02 |
| **F19** — `CSV_TAXONOMY_DRIFT` advisory gate | Ride-on. F19's Phase A artifact (positive+negative fixture) lives in F16's fixture tree. | Phase A 2026-06-04 (parallel with F16 Phase B) per analytics master plan §11 |
| **F20** — `GA4_MCP_DISCONNECTED` advisory gate | Ride-on, same as F19 | Phase A 2026-06-04 (parallel) |

**Total downstream value:** four candidates unblock once F16 reaches Phase E. F16 is the highest-leverage single change in the v8.x docket per the external research synthesis in the parent spec §2.

### 9.3 Sibling — what F16 must coordinate with

| Sibling | Coordination point |
|---|---|
| **F2** (Phase 0 reality-check sub-step) | Ships in v7.9.1 alongside F16 (§3.6.3). No code-level conflict — F2 is a `/pm-workflow` change, F16 is a test-infra change. |
| **F6** (B_medium tier doc) | Ships in v7.9.1 alongside F16. Doc-only; no conflict. |
| **F17** (`last_fired_at` index) | Ships in v7.9.1 alongside F16. F17 reads `gate-coverage.jsonl`; F16 writes `gate-coverage.jsonl` only when not in test mode (`GATE_COVERAGE_LEDGER_DISABLED=1` guard). Compatible by design. |
| **`v7.8.5.1` test fixture rot follow-ups** | Shipped 2026-05-13 via PR #331. F16 should NOT replicate the rot pattern — fixtures are decoupled from gate function names via the manifest's explicit `gate` field. |

---

## §10 Risks

| # | Risk | Severity | Likelihood | Mitigation |
|---|---|---|---|---|
| R1 | **Harness wall-time bloats CI** — 40 fixtures × subprocess overhead × git plumbing setup could push nightly past the soft 5min target | Medium | Medium | Phase B measures actual wall-time. If >5min, parallelize fixtures via `pytest-xdist`; if still >5min, split CI into two workflows (write-time gates vs case-study gates). Reversible. |
| R2 | **Fixture rot** — gates rename (cf. `CACHE_HITS_EMPTY_POST_V6` → `CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT` in v7.8.3) and fixtures don't update; harness silently passes the wrong assertion | Medium | High | (a) Manifest's `gate` field is primary key, not directory name. (b) Phase C triage explicitly looks for `KeyError`-class issues. (c) `pre-commit-self-test.py` extends to cross-check fixture-manifest gate names against gate-code constants in `check-state-schema.py`. |
| R3 | **Temp repo pollution** — bug in harness writes outside `tmp_path` (e.g., a `cd` that escapes pytest's cleanup) | Low | Low | (a) Harness library NEVER `cd`s; always passes `cwd=tmp_path` to subprocess. (b) Harness unit tests (§8.1 Layer 1) explicitly assert no writes outside `tmp_path`. (c) Code review checklist item. |
| R4 | **GitHub Actions hosted-runner git version drift** — local dev uses git 2.45+, hosted may be older; harness assumes a specific `git` CLI surface | Low | Medium | (a) Harness asserts `git --version` >= 2.30 at startup; skips with clear error otherwise. (b) CI workflow pins git via `actions/setup-git@v1` or equivalent. (c) Documented in case study. |
| R5 | **F16 itself has a PR-#317-class bug** — the harness silently passes because of a dispatch-site early-return inside the harness | Medium | Medium | The §8.1 Layer 3 meta-validation (deliberately revert PR #317 and confirm harness catches it) is the single most important test in the suite. Must run before Phase D. If it doesn't catch the regression, harness is unmerged. |

---

## §11 Success Metrics

### 11.1 Primary metric

**Number of production silent-pass bugs discovered by F16 during Phase B+C** (i.e., disagreements categorized as `production_silent_pass` after triage).

- **Baseline:** 1 (the PR #317 incident, retroactively countable since F16's PoC fixture #14 would have caught it)
- **Phase B+C target:** ≥ 2 (i.e., F16 surfaces at least one previously-unknown silent-pass during its calibration window)
- **Phase E target:** 0 new silent-passes in 30 days post-promotion (the system is stable, not noisy)

Tier 2 (Declared) at Phase D. Tier 1 (Instrumented) once F17 ships the `last_fired_at` index.

### 11.2 Secondary metrics

| Metric | Target | Tier |
|---|---|---|
| Harness nightly wall-time | < 5 min total | T1 (logged in nightly JSONL) |
| Fixture-discovery count | 40 minimum | T1 (logged in nightly JSONL) |
| Fixture flake rate (false-fail without code change) | 0% | T1 (logged) |
| Phase B → Phase C disagreement-triage time | ≤ 4 hours / disagreement | T2 (declared in case study) |
| Phase E false-positive count | 0 in 7d window | T1 (logged) |
| Downstream unblock — F14/F18/F19/F20 begin Phase A on time | All 4 begin by 2026-06-25 | T2 (declared) |

### 11.3 Kill criteria

F16 ships **advisory only** in v7.9.1 and gets considered for v8.0 enforcement promotion. Kill the v8.0 promotion if:

- Phase B reveals harness wall-time > 15 min (10× over target) and no parallelization recovers it
- Phase C reveals >5 fixture-bugs vs production-silent-passes (the harness is noisier than the production code)
- Phase E reveals any false-positive that blocks unrelated PRs

If killed: F16 stays advisory permanently (still useful as a dev tool). F14 and F18 then either ship without F16 (degraded test coverage; explicitly accepted) or also stay deferred.

**Resolution recorded in:** `kill_criteria_resolution` field on `state.json` at feature closure (per the v7.8.1 `FEATURE_CLOSURE_COMPLETENESS` gate's Q7 requirement).

---

## §12 Cross-References

### 12.1 Parent + sibling docs

- **Parent spec:** [`docs/superpowers/specs/2026-05-08-framework-v7-9-candidates.md`](../superpowers/specs/2026-05-08-framework-v7-9-candidates.md) — F16 in §2 candidate inventory; §3 Theme G grouping; §5 promotion classes
- **Master plan:** [`docs/master-plan/infra-master-plan-2026-05-12.md`](./infra-master-plan-2026-05-12.md) §3.6.3 (v7.9.1 docket), §3.5 (Calibration Protocol), §3.5.2 (Layer Stacking Rule), §3.6.4 (v8.0 downstream)
- **Analytics master plan (downstream F19/F20):** [`docs/master-plan/analytics-master-plan-2026-05-13.md`](./analytics-master-plan-2026-05-13.md) §11 (F19/F20 ride on F16 harness)

### 12.2 Source incident + supporting docs

- **PR #317** (the bug F16 would have caught) — `fix(framework): BRANCH_ISOLATION_VIOLATION Mode B silent-pass on infra-only commits`, commit `97af469` on `fix/branch-isolation-mode-b-early-return`, merged 2026-05-12 as squash `6c52e92`
- **Observed Patterns Catalog:** [`.claude/integrity/observed-patterns.md`](../../.claude/integrity/observed-patterns.md) — every gate entry has a corresponding F16 fixture
- **v7.5 → v7.8 framework documentation:** `CLAUDE.md` "Data Integrity Framework" section

### 12.3 Code surfaces F16 touches (new + modified)

**New files:**
- `scripts/tests/try_repo_harness.py` (harness library)
- `scripts/tests/test_try_repo_harness.py` (parametrized runner)
- `scripts/tests/test_try_repo_harness_internals.py` (unit tests on the harness itself)
- `tests/fixtures/gate-fixtures/_schema.json` (manifest JSON Schema)
- `tests/fixtures/gate-fixtures/<GATE>/{positive,negative}/{manifest.json,stage/...}` (≈ 40 fixture dirs)
- `.github/workflows/try-repo-nightly.yml` (nightly cron)
- `docs/case-studies/v7-9-1-f16-try-repo-harness-case-study.md` (Phase D deliverable)

**Modified files:**
- `Makefile` — add `make try-repo-test` target
- `CLAUDE.md` — add F16 to "CI Pipeline" section after Phase D promotion
- `.github/workflows/pr-integrity-check.yml` — wire F16 advisory (Phase B) then enforced (Phase D)
- `.gitignore` — add `.claude/logs/try-repo-harness-*.jsonl`
- `scripts/pre-commit-self-test.py` — cross-check fixture-manifest gate names against gate-code constants (R2 mitigation)
- `.claude/integrity/observed-patterns.md` — add a "Fixture path" column to §1 entries (T20)

### 12.4 Externally-referenced patterns (not FT2 code)

- [pre-commit `try-repo`](https://pre-commit.com/) — the pattern F16 names itself after
- [Semgrep rule fixture pairing](https://semgrep.dev/docs/writing-rules/testing-rules) — every rule must have positive + negative tests
- [OPA `opa test --coverage`](https://www.openpolicyagent.org/docs/policy-testing/) — coverage-aware policy testing
- [ESLint `RuleTester`](https://eslint.org/docs/latest/extend/custom-rules#rule-unit-tests) — `valid` vs `invalid` code samples per rule
- [AWS Config `LastSuccessfulInvocationTime`](https://docs.aws.amazon.com/config/latest/APIReference/API_DescribeComplianceByResource.html) — the model for F17's `last_fired_at` index (sibling to F16)

---

## §13 Revision log

| Date | Change | Author |
|---|---|---|
| 2026-05-13 | Initial PRD draft. Doc-only; calibration-window compliant. | general-purpose subagent |
| TBD (post-Phase D) | Mark `kill_criteria_resolution` after promotion decision | TBD |
| TBD (post-Phase E) | Mark stable + link to case study | TBD |

---

**End of detailed PRD.** Next step: at v7.9 Phase E exit (~2026-06-04), invoke `/pm-workflow framework-v7-9-1-f16-try-repo-harness` to kick off Phase A artifact authoring (T2–T5). All prerequisites confirmed available.
