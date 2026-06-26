# F18 — Mutation Testing on Dispatcher Files — Phase 0 Research

**Feature:** `f18-mutation-testing` · **Work type:** Chore (`framework_feature`) · **Framework:** v7.10 · **Date:** 2026-06-26
**Docket:** infra-master-plan §3.0 (F18, RICE 13.7) — gated on F16 Phase E (enforced 2026-06-17 ✓) + F14 (shipped ✓) → **now unblocked**.

## 1. What is this?

Mutation testing introduces small deliberate faults ("mutants") into the gate-dispatch source code and checks whether the existing test suite **fails** in response. A surviving mutant = a line of gate logic that no test actually exercises. It measures **test quality** (do our tests catch real breakage?), complementing coverage (which only measures lines executed).

## 2. Why now / why this matters

The framework's enforcement rests on two "dispatcher" files:
- [`scripts/check-state-schema.py`](../../../scripts/check-state-schema.py) (81 KB) — the **write-time** gate dispatcher (18 gates fire here on `git commit`)
- [`scripts/integrity-check.py`](../../../scripts/integrity-check.py) (80 KB) — the **cycle-time** dispatcher (9 checks fire here every 72h)

F14 (dispatch tests), F15 (zero-coverage unit tests), and F16 (try-repo harness) built a 3-layer test suite for these gates. But **a green test suite can still be a weak one** — a test that asserts the wrong thing, or never reaches the mutated branch, passes regardless. Mutation testing is the empirical proof that those tests have teeth. It also produces the survivor list that feeds the planned **T1 `GATE_TEST_MISSING`** meta-gate (gated 2026-08-22) and **R9 Track-B** coverage read (2026-07-04).

## 3. Tool comparison (Python mutation testing)

| Tool | Pros | Cons | Effort | Chosen? |
|------|------|------|--------|---------|
| **mutmut** | De-facto standard; simple `setup.cfg`/`pyproject` config; `paths_to_mutate` + `tests_dir`; caches results; fast incremental re-runs; actively maintained | Single-process by default (slower on huge files) | Low | **Recommended** |
| cosmic-ray | Distributed/parallel workers; fine-grained operator config | Heavy config (TOML sessions + sqlite db); overkill for 2 files; steeper CI wiring | Med-High | No |
| mutatest | Stdlib-only AST; no extra runner | Less active; weaker reporting; no incremental cache | Low | No |

**Recommendation: mutmut** — matches the warn-only, low-config posture of F12 (actionlint) / R18 (shellcheck); pip-installable; skips cleanly when absent (same convention as `make lint`).

## 4. Scope decision (target surface)

The dispatcher files are 80 KB+ each → mutating *everything* is slow (minutes-to-hours) and noisy. Three scoping options:

| Option | Surface | Runtime | Trade-off |
|---|---|---|---|
| **A — targeted (recommended)** | The gate-check functions only (the load-bearing `def *_check`/predicate fns in both files), via `mutmut` regex/path filters | ~minutes | Best signal-to-noise; mutants land on actual gate logic |
| B — `check-state-schema.py` whole-file first | One dispatcher, all lines | ~10-20 min | Comprehensive on the write-time path; defer cycle-time |
| C — both files whole | Everything | slow | Maximal coverage, poor iteration speed |

## 5. CI / threshold posture

- **Posture:** warn-only first (mirrors F12/R18) — `make mutation-test` locally + an optional warn-only CI job (`continue-on-error: true`). No hard mutation-score gate at ship.
- **Threshold:** **capture a baseline first** (record surviving-mutant count), no kill-criterion threshold in v1. A hard `MUTATION_SCORE < N` gate is a future calibration step (would feed T1).
- **Discipline (CLAUDE.md F16 rule):** any new gate ships with a try-repo fixture pair — F18 doesn't change that; it audits the *quality* of those fixtures + unit tests.

## 6. Proposed deliverables (Phase 4)

1. `mutmut` config (in `pyproject.toml` or `setup.cfg`) — `paths_to_mutate` scoped per the decision in §4
2. `make mutation-test` target — runs mutmut, prints survivor summary, skips cleanly if mutmut absent (loud `⚠ … CI enforces` message)
3. Baseline survivor report committed under `.claude/shared/` or `docs/` (the as-of-today mutation score)
4. (optional) warn-only `.github/workflows/mutation-test.yml`
5. Case study (`framework_meta_retroactive` exempt) + state.json closure

## 7. Open decisions for operator (Phase 0 gate)

1. **Tool** — confirm mutmut (recommended) vs cosmic-ray.
2. **Scope** — Option A targeted / B one-file / C both-whole.
3. **CI** — ship a warn-only CI job now, or local-only `make mutation-test` for v1.

## 8. Decision

**Recommended:** mutmut + Option A (targeted gate-check functions) + local-only `make mutation-test` for v1 (warn-only CI as a fast-follow). Baseline-capture, no hard threshold. Pending operator confirmation at the Phase 0 gate.
