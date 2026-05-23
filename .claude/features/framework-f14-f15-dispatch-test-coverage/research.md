# Research — framework-f14-f15-dispatch-test-coverage

> **Phase 0 deliverable.** Scope, alternatives considered, success-metric draft.
> Authoritative spec already exists: [`docs/superpowers/specs/2026-05-08-framework-v7-9-candidates.md`](../../../docs/superpowers/specs/2026-05-08-framework-v7-9-candidates.md) §§F14 + F15 (rows in the candidate table). This research.md is the lightweight discovery layer that frames the PRD; it does not re-derive what the spec already establishes.

## 1. What is this solution?

Add per-gate `test_main_dispatch_<gate_id>()` unit tests for **9 framework gates** that today have either (a) thorough internal-function tests but ZERO test exercising `scripts/check-state-schema.py::main()` end-to-end, or (b) zero unit-test coverage of any shape. Each test invokes `main()` with monkey-patched `collect_staged_state_files`, `collect_all_staged_files`, `GATE_COVERAGE_LEDGER`, and `sys.argv` — asserting the gate either fires (rejection path) OR records a `candidates→checked/skipped` row in `.claude/logs/gate-coverage.jsonl`.

The pattern is established: PR #317 (commit `97af469`, `fix/branch-isolation-mode-b-early-return`) added the prototype dispatch tests for `BRANCH_ISOLATION_VIOLATION` Mode B as the fix for a silent-pass bug where `main()` early-returned before the gate dispatch site. This feature **generalizes that pattern** to the remaining 9 gates.

## 2. Why this approach?

**Problem class:** internal-function unit tests cannot, by construction, catch dispatcher-level bugs. Witness:
- **2026-05-12 incident** — `BRANCH_ISOLATION_VIOLATION` Mode B never ran on infra-only commits because `main()` returned at `if not files: return 0` BEFORE reaching the gate dispatch. Internal-function tests for the gate's check logic passed cleanly throughout. Only PR #317's two new `main()`-level regression tests caught it.
- **2026-04-30 silent-pass on `CACHE_HITS_EMPTY_POST_V6`** (per `docs/case-studies/framework-honesty-ledger.md` FT2-FH-001) — gate read `created_at` while 43/46 state.json files used the legacy `created` key. Internal-function tests passed; the keying-drift was undetectable until weeks later when audit caught it. Dispatch tests with realistic fixtures would have caught the asymmetry at first run.

Pattern is established by external practice:
- [Semgrep rule fixture-pairing](https://semgrep.dev/docs/writing-rules/testing-rules) — every `rule.yml` requires a paired `rule.test.yml` driving the dispatcher.
- [pre-commit framework `try-repo`](https://pre-commit.com/) — recommended pattern: end-to-end harness against a throwaway git repo.
- [ESLint `RuleTester`](https://eslint.org/docs/latest/developer-guide/unit-tests) — every rule needs `valid` + `invalid` cases driving the linter end-to-end, not just the rule's check function.

## 3. Why this over alternatives?

| Approach | Pros | Cons | Effort | Chosen? |
|---|---|---|---|---|
| **A. Per-gate `test_main_dispatch_*` (this proposal)** | Closes the exact PR #317 bug class; small change shape (9 × ~5-line tests + 1 enforcement gate); matches existing PR #317 prototype | 9 tests = ~45 lines + 1 `GATE_TEST_MISSING` meta-gate; need realistic fixtures per gate | **0.4-0.6w** | ✅ **Yes** |
| **B. End-to-end `try-repo` harness only (F16 alone)** | Catches more bugs (full git+hook flow); single foundation for F14/F18 | Higher startup cost (~0.5w just for harness); doesn't FORCE per-gate dispatch tests, so silent-pass class can recur | 0.5w | ❌ Sequenced AFTER, not instead — F16 is its own v7.9.1 candidate |
| **C. Mutation testing (F18 alone)** | Strongest evidence-of-coverage; catches surviving silent-pass mutants automatically | Requires F14 + F16 as prerequisites (need tests to mutate); mutation budget large (~2-4× test runtime per CI cycle) | 0.7w | ❌ Layer 3 of the stack — depends on this feature |
| **D. Property-based testing (Hypothesis `RuleBasedStateMachine`)** | Generates state-mutation sequences mechanically; finds long-chain bugs | High setup cost; results harder to interpret; framework gates aren't ideal PBT targets (most are file-level checks, not state machines) | 1.0w+ | ❌ Out of scope; tracked as future v8.x candidate |
| **E. Status quo (no new tests)** | Zero effort | Recurrence of PR #317-class bugs is statistical certainty given current asymmetry | 0w | ❌ Already rejected at 2026-05-12 candidate prioritization |

**Decision:** A. Per-gate dispatch tests are the minimum viable closure of the PR #317 bug class. F16 + F18 stack on top in subsequent releases (F16 = v7.9.1, F18 = v8.0).

## 4. External sources

- **PR #317 prototype** — [FT2 PR #317 commit `97af469`](https://github.com/Regevba/FitTracker2/pull/317) — 2 regression tests for `BRANCH_ISOLATION_VIOLATION` Mode B that drive `main()` end-to-end with monkey-patched git helpers. This is the model.
- **F-candidates spec §F14 + §F15** — [`docs/superpowers/specs/2026-05-08-framework-v7-9-candidates.md`](../../../docs/superpowers/specs/2026-05-08-framework-v7-9-candidates.md) — the authoritative scope + per-gate breakdown.
- **Test-coverage master plan §2.1** — [`docs/master-plan/test-coverage-master-plan-2026-05-13.md`](../../../docs/master-plan/test-coverage-master-plan-2026-05-13.md) — the per-layer inventory showing the 9-gate gap.
- **Honesty ledger FT2-FH-001** — [`docs/case-studies/framework-honesty-ledger.md`](../../../docs/case-studies/framework-honesty-ledger.md) — the `cache_hits` keying-drift silent-pass that motivated Mechanism A coverage telemetry and surfaces the dispatch-coverage gap that THIS feature closes.
- **Semgrep fixture-pairing convention** — [semgrep.dev/docs/writing-rules/testing-rules](https://semgrep.dev/docs/writing-rules/testing-rules) — model for the future `GATE_TEST_MISSING` enforcement gate (deferred to T1 in test-coverage plan §3.2).

## 5. The 9 gates in scope

**F14 — gates with internal-function tests but NO `main()` dispatch test (4):**

| # | Gate | File | Existing test | Status |
|---|---|---|---|---|
| 1 | `CACHE_HITS_EMPTY_POST_V6` / `CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT` (renamed v7.8.3) | `scripts/check-state-schema.py` | `scripts/tests/test_check_state_schema.py::test_cache_hits_*` | Internal-only |
| 2 | `CU_V2_INVALID` | `scripts/check-state-schema.py` + `scripts/validate-cu-v2.py` | `scripts/tests/test_validate_cu_v2.py::test_*` | Internal-only |
| 3 | `STATE_NO_CASE_STUDY_LINK` | `scripts/check-state-schema.py` | `scripts/tests/test_check_state_schema.py::test_state_no_case_study_link_*` | Internal-only |
| 4 | `CASE_STUDY_MISSING_FIELDS` | `scripts/check-state-schema.py` | `scripts/tests/test_check_state_schema.py::test_case_study_missing_*` | Internal-only |

**F15 — gates with ZERO unit-test coverage of any shape (5):**

| # | Gate | File | Existing test | Status | Risk tier |
|---|---|---|---|---|---|
| 5 | `PHASE_TRANSITION_NO_LOG` (v7.6 enforced) | `scripts/check-state-schema.py` | — | **ZERO** | **HIGHEST** — guards most-frequent state mutation |
| 6 | `PHASE_TRANSITION_NO_TIMING` (v7.6 enforced) | `scripts/check-state-schema.py` | — | **ZERO** | **HIGHEST** — pairs with #5 |
| 7 | `BRANCH_ISOLATION_HISTORICAL` (v7.8.1 advisory) | `scripts/integrity-check.py` (cycle-time) | — | **ZERO** | Medium — forward-only audit |
| 8 | `BRANCH_ISOLATION_LAUNCHD_DRIFT` (v7.8.1 advisory) | `scripts/integrity-check.py` (cycle-time) | — | **ZERO** | Medium — macOS-only |
| 9 | `PR_CACHE_STALE` (v7.8.4) | `scripts/ensure-pr-cache-fresh.py` | — | **ZERO** | Medium — operability gate |

## 6. Demand signals

- **Calendar trigger** — cadence-followups C1 lists this as a MUST-have for 2026-05-22, deferred from 2026-05-15. Originally a v7.9 promotion criterion ([master plan §2.2](../../../docs/master-plan/infra-master-plan-2026-05-12.md) criterion #1: "Mechanism A coverage validated for all gates"). v7.9 shipped 2026-05-21 WITHOUT this validation on these 9 gates per the deferral note's trade-off documented in [`.claude/shared/must-have-cadence-followups.md`](../../../.claude/shared/must-have-cadence-followups.md) §C1.
- **Empirical pull** — 2 silent-pass incidents this quarter (`cache_hits` keying drift 2026-04-30 + `BRANCH_ISOLATION_VIOLATION` Mode B 2026-05-12) both rooted in dispatch-coverage gaps. Rate ~1 per 3 weeks if uncorrected.
- **Validation post-v7.9** — the 3 promoted gates at v7.9 (`BRANCH_ISOLATION_VIOLATION` B+C + `FEATURE_CLOSURE_COMPLETENESS`) all have dispatch tests via PR #317 + the closure-completeness test file. The 9 gates in THIS feature do NOT. The v7.9.1 cycle (~2026-06-04 → 2026-06-11) will re-evaluate whether those 9 gates should re-flip if regressions surface during Phase E.

## 7. Technical feasibility

**Risks:**
- **Test brittleness** — monkey-patching 4 module globals per test (`collect_staged_state_files`, `collect_all_staged_files`, `GATE_COVERAGE_LEDGER`, `sys.argv`) can break if `main()` refactors change those names. Mitigation: use `unittest.mock.patch` with the canonical module-attribute path; group tests under a shared fixture; document in a test-pattern doc.
- **Gate-coverage ledger pollution during tests** — calling `main()` writes to `.claude/logs/gate-coverage.jsonl`. Mitigation: monkey-patch `GATE_COVERAGE_LEDGER` to a tmp path per test (already established in PR #317).
- **Fixture drift** — each gate's positive/negative state.json fixture must remain valid against the live schema; if state.json schema evolves, fixtures can silently age out. Mitigation: factor fixtures into shared helpers that build minimal-valid state.json from a single template; schema-validate at test setup.
- **Cycle-time gate coverage (#7, #8)** — `BRANCH_ISOLATION_HISTORICAL` + `BRANCH_ISOLATION_LAUNCHD_DRIFT` are cycle-time gates in `scripts/integrity-check.py`, not write-time gates. Their dispatch shape is `integrity-check.py::main()`, not `check-state-schema.py::main()`. Two slightly different harnesses; possibly merge into one parametrized fixture.

**Unknowns:**
- **#9 `PR_CACHE_STALE` location** — lives in `scripts/ensure-pr-cache-fresh.py`, not check-state-schema or integrity-check. Need to decide: dispatch test follows its own pattern, OR refactor PR_CACHE_STALE emission into a shared gate-dispatch harness so all 9 are testable uniformly. PRD will resolve.

## 8. Proposed success metrics (DRAFT — finalize in PRD)

**Primary (T1 — Instrumented):**
- `framework_gate_dispatch_test_coverage_pct` — count of write-time gates with ≥1 `test_main_dispatch_<gate>` test ÷ total declared write-time gates. **Baseline:** 1/16 ≈ 6% (only `BRANCH_ISOLATION_VIOLATION` Mode B from PR #317). **Target:** 5/16 = 31% post-feature (this feature's 4 F14 gates + the 1 existing). For cycle-time gates: 0/3 → 2/3 (advisory BRANCH_ISOLATION_HISTORICAL + LAUNCHD_DRIFT).

**Secondary:**
- `silent_pass_incidents_per_quarter` — observed incidents where a gate's `main()` dispatch fails silently while internal function passes. **Baseline:** 2 in Q2 2026 (cache_hits keying + Mode B early-return). **Target:** ≤ 0.5/quarter (1 per year max) after this feature lands.
- `test_main_dispatch_test_runtime_seconds` — sum runtime of the 9 new tests. **Target:** ≤ 5s total (~500ms per test ceiling; bulk under 200ms).
- `gate_coverage_ledger_emission_per_test` — every new dispatch test must emit ≥1 `candidates` row to `.claude/logs/gate-coverage.jsonl` during its run. **Target:** 9/9 tests emit (validates Mechanism A pairing).

**Guardrails (must NOT degrade):**
- CI pipeline runtime — current `make test-framework-python` ≤45s. Target: ≤55s after additions.
- Mechanism A coverage telemetry — adding 9 dispatch tests writes ~9 candidate rows per CI run. **Must NOT contaminate** the v7.9 calibration baseline; tests run against tmp ledgers, never the canonical `.claude/logs/gate-coverage.jsonl`.

**Leading indicator (1 week):**
- All 9 tests landed + CI green on feature branch + `pre-commit-self-test.py` extended with `GATE_TEST_MISSING` meta-check passing (deferred until v7.9.1 OR scoped in this PRD).

**Lagging indicator (90 days, by 2026-08-22):**
- Zero PR #317-class silent-pass incidents on the 9 covered gates between ship date and 2026-08-22.

**Kill criteria:**
- If any of the 9 new tests proves to be flaky in CI (≥1 false failure per 50 runs over 2 weeks) → revert that single test + reopen its gate's dispatch coverage gap.
- If total CI runtime increase exceeds 30s → re-architect to share fixtures more aggressively or skip the heaviest tests.

**Instrumentation plan:**
- Track new tests landing in `.claude/features/framework-f14-f15-dispatch-test-coverage/state.json::phases.testing.tests_added`.
- `make test-framework-python` already emits per-test pass/fail; CI workflow `pm-framework/pr-integrity` already gates on green.
- Mechanism A `gate-coverage.jsonl` already records all gate emissions; no NEW instrumentation needed.

**Review cadence:**
- T+7d (2026-06-04ish, depends on ship date) — verify no flaky tests + CI runtime within target.
- T+30d — confirm no silent-pass incidents on the 9 covered gates.

## 9. Decision

**Recommended approach:** ✅ **Approach A — Per-gate `test_main_dispatch_<gate>()` for all 9 gates.** Pattern proven by PR #317; effort budget 0.4–0.6w fits within v7.9.1 cycle window (~2026-06-04 → 2026-06-11). Foundation for the larger Theme G test-discipline stack (F16 + F18 + T1).

**Open questions for PRD phase:**
1. **Cycle-time gates (#7, #8) — same test file or separate?** `BRANCH_ISOLATION_HISTORICAL` + `BRANCH_ISOLATION_LAUNCHD_DRIFT` live in `integrity-check.py`. Add `scripts/tests/test_integrity_check_dispatch.py` OR park them in `test_branch_isolation_and_closure_completeness.py` alongside the v7.9 promoted gates? **Tentative answer:** separate file — clearer mental model.
2. **`PR_CACHE_STALE` (#9) — refactor or inline?** Lives in its own script. Either (a) add a one-off `test_ensure_pr_cache_fresh.py` for its dispatch path, OR (b) refactor `ensure-pr-cache-fresh.py` to emit gate-coverage rows via the shared `dispatch.py` helper for uniformity. **Tentative answer:** (a) — refactor blocks shipping the rest of the tests.
3. **`GATE_TEST_MISSING` meta-gate — scope in this PRD or defer to T1?** Test-coverage plan §3.2 has it as T1 with RICE 53.3. If we ship the 9 tests WITHOUT the meta-gate, the next new gate can still ship without a test. **Tentative answer:** defer the meta-gate to T1 (PRD §6); this feature focuses on the closure of the 9-gate gap.
4. **Fixture sharing strategy — `conftest.py` vs per-file helpers?** PR #317's 2 tests live inline in `test_branch_isolation_and_closure_completeness.py`. Scaling to 9 tests across 2–3 files makes a `conftest.py` shared-fixtures pattern more attractive. **Tentative answer:** introduce `scripts/tests/conftest.py` with `make_valid_state_json()` + `make_invalid_state_json()` + `tmp_gate_coverage_ledger()` fixtures.

These 4 open questions get locked in Phase 1 (PRD).

## 10. Estimated effort

| Phase | Effort | Notes |
|---|---|---|
| Phase 0 (Research) | **DONE** — this doc | ~30 min |
| Phase 1 (PRD) | 1.5h | Resolve 4 open questions + finalize success metrics + lock kill criteria |
| Phase 2 (Tasks) | 30 min | 9 test tasks + 1 fixture-factor task + 1 doc task |
| Phase 3 (UX) | **SKIP** — no UI; jump to integration-spec | 15 min for integration-spec.md |
| Phase 4 (Implement) | 3-4h | 9 × ~5-line tests + shared fixtures + 1 conftest.py |
| Phase 5 (Test) | 30 min | Verify CI green + runtime budget + Mechanism A emission |
| Phase 6 (Review) | 30 min | Pre-merge code review |
| Phase 7 (Merge) | 15 min | Squash + delete branch |
| Phase 8+9 (Docs + Learn) | 1h | Case study + backlog update + cadence-followups C1 closure marker |
| **Total** | **~7-9h** | Fits ≤1 working day |

Target ship: 2026-05-23 → 2026-05-25 (one day of focused work + 1-2 days for review/CI/iteration).

---

**Status at Phase 0 close:** Research complete. Ready for user approval to advance to Phase 1 (PRD).
