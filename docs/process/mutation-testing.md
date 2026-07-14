# Mutation Testing on the Gate Dispatchers (F18)

> **Status:** shipped 2026-06-26 (v8.0 docket F18, RICE 13.7). Posture: **warn-only** baseline.
> **Feature:** [`f18-mutation-testing`](../../.claude/features/f18-mutation-testing/state.json) (chore / `framework_feature`).
> **Unblocked by:** F16 try-repo harness (enforced 2026-06-17) + F14 dispatch tests (shipped).

## What this is

Mutation testing injects small deliberate faults ("mutants") into source code and
checks whether the existing test suite **fails** in response. A mutant the suite
**kills** proves a test exercises that line meaningfully; a mutant that **survives**
is a line of logic no test actually catches — a test-quality gap that line
coverage cannot see.

F18 applies this to the two **gate-dispatcher files** the whole framework rests on:

- [`scripts/check-state-schema.py`](../../scripts/check-state-schema.py) — write-time gate dispatcher (21 gates fire here on `git commit`)
- [`scripts/integrity-check.py`](../../scripts/integrity-check.py) — cycle-time dispatcher (9 checks fire every 72h)

It validates the quality of the F14 (dispatch) + F15 (unit) + F16 (try-repo) suites,
and the survivor list feeds the planned **T1 `GATE_TEST_MISSING`** meta-gate and the
**R9 Track-B** coverage read.

## Configuration

| Knob | Value | Where |
|---|---|---|
| Tool | `mutmut==2.5.1` | [`setup.cfg`](../../setup.cfg) `[mutmut]` |
| Scope | C — both dispatcher files, whole | `paths_to_mutate` |
| Runner | `python3 -m pytest -x -q scripts/tests/` | `runner` (use `python3`, **not** bare `python` — not always on PATH) |
| Posture | warn-only (surviving mutants never fail the build) | Makefile `||` + CI `continue-on-error` |
| CI cadence | **weekly** (Mon 07:00 UTC) + `workflow_dispatch` | [`.github/workflows/mutation-test.yml`](../../.github/workflows/mutation-test.yml) |

**Why weekly, not per-PR:** scope C yields **1,857 mutants** across the two 80 KB
dispatchers; each mutant re-runs the suite. A full pass is minutes-to-hours — too
slow to gate every PR. `--use-coverage` scopes mutants to covered lines to keep it
tractable. The result is informational (job summary + artifact), never blocking.

## Baseline (as of 2026-06-26)

- **Total mutants: 1,857** (2 source files) — the structural baseline.
- **Full mutation-score baseline is produced by the first weekly CI run** and
  uploaded as the `mutation-results` artifact (`.mutmut-cache` + `mutation-baseline.json`).
  It is intentionally **not** committed (a partial local pass would be misleading;
  see no-silent-caps discipline). A bounded local pass during development killed 2 /
  survived 1 of the first 3 mutants resolved — enough to prove the harness end-to-end.

## Running it locally

```bash
# Python 3.13 — NOT 3.14. mutmut 2.5.1 + parso hit an AST deep-copy bug on 3.14;
# CI pins 3.13.
python3.13 -m venv .venv && source .venv/bin/activate
pip install mutmut==2.5.1 pytest pytest-cov

# Optional but recommended — scope mutants to covered lines (much faster):
python3 -m pytest -q --cov=scripts --cov-report= scripts/tests/

make mutation-test ARGS=--use-coverage     # run + print summary
make mutation-summary                       # re-print summary from the cache anytime
```

`make mutation-test` skips cleanly with a loud message if `mutmut` is absent
(same convention as `make actionlint` / `make lint`).

## Reading results — why `mutmut results` is not used

mutmut 2.5.1's own `mutmut results` and `mutmut junitxml` readers **crash on recent
peewee** (`TypeError: 'QueryResultIterator' object is not iterable`). The *run* writes
results correctly to the `.mutmut-cache` sqlite db regardless. So the summary comes
from [`scripts/mutation-summary.py`](../../scripts/mutation-summary.py) — a stdlib-only
sqlite3 reader of that cache, immune to mutmut/peewee version drift. It reports
killed / survived / suspicious / skipped / untested + the mutation score
(`killed / tested`) and writes JSON.

Status → bucket mapping: `ok_killed`,`bad_timeout` → killed · `bad_survived` →
survived (the test gaps to fix) · `ok_suspicious`/`skipped`/`untested` → not scored.

## Future: enforced threshold (feeds T1)

`scripts/mutation-summary.py --fail-under N` exits 1 when the score drops below `N`.
It is unused at v1 (warn-only). Once a full-run baseline score exists and stabilizes,
a calibration step (per infra master plan §3.5) can wire `--fail-under` into CI as
the enforced **`GATE_TEST_MISSING`**-adjacent quality bar. Until then: survivors are
surfaced, triaged, and closed by adding tests to `scripts/tests/`.
