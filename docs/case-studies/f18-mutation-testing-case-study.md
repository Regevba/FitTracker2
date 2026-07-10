---
title: "F18 — Mutation Testing on the Gate Dispatchers"
date: 2026-06-26
date_written: 2026-06-26
work_type: chore
framework_version: v7.10
dispatch_pattern: solo
primary_metric: "Mutation harness operational on both dispatchers; 1,857 mutants enumerated; version-proof summary reader green"
success_metrics:
  - "mutmut runs end-to-end on the 2 gate dispatchers (1,857 mutants) [T1]"
  - "full scripts/tests/ suite green under the harness: 574 passed / 3 skipped [T1]"
  - "summary reader + dispatcher regression: 5 + 27 tests green [T1]"
kill_criteria: "n/a — warn-only test-infra chore; no kill trigger at v1 (a future --fail-under score threshold is a separate calibration step)"
kill_criteria_resolution: "n/a — warn-only posture; there is no kill criterion to resolve. Enforced-threshold decision deferred to the T1 GATE_TEST_MISSING calibration."
tier_tags_present: true
related_prs: [809]
case_study_type: framework_feature
case_study_showcase: fitme-story/content/04-case-studies/60-f18-mutation-testing.mdx
---

# F18 — Mutation Testing on the Gate Dispatchers

**Feature:** `f18-mutation-testing` · chore / `framework_feature` · v7.10 · 2026-06-26
**Shipped via PR #809.** **Docket:** infra-master-plan §3.0 F18 (RICE 13.7) — the top open ready-now infra item, unblocked by F16 enforce (2026-06-17) + F14.

## Problem

The framework's enforcement rests on two ~80 KB dispatcher files —
`scripts/check-state-schema.py` (write-time, 18 gates) and
`scripts/integrity-check.py` (cycle-time, 9 checks). F14/F15/F16 built a 3-layer
test suite for them, but **a green suite can still be a weak one**: a test that
asserts the wrong thing or never reaches a branch passes regardless. Line coverage
cannot tell the difference. Mutation testing can — it injects faults and checks the
suite *fails*.

## What shipped

| Piece | Detail |
|---|---|
| Config | `setup.cfg [mutmut]` — `mutmut==2.5.1`, scope C (both dispatchers whole), runner `python3 -m pytest` |
| Local | `make mutation-test ARGS=--use-coverage` + `make mutation-summary`; skip-clean when mutmut absent |
| CI | `.github/workflows/mutation-test.yml` — warn-only, weekly cron + `workflow_dispatch` |
| Reader | `scripts/mutation-summary.py` — stdlib sqlite reader of `.mutmut-cache` (+ 5 unit tests) |
| Doc | `docs/process/mutation-testing.md` |

## Measurements

- **1,857 mutants [T1]** enumerated across the two dispatchers — the structural baseline.
- Full `scripts/tests/` suite under the harness: **574 passed / 3 skipped [T1]**.
- New reader tests + dispatcher regression: **5 + 27 green [T1]**.
- Full mutation-**score** baseline is produced by the first weekly CI run (uploaded as an artifact); a partial local pass would be misleading, so it is not committed [T2].

## Three caveats discovered (and handled)

1. **bare `python` not on PATH** — mutmut's runner shelled to `python`; fixed to `python3` (caught by verification, not CI) [T1].
2. **Python 3.14 incompatibility** — mutmut 2.5.1 + parso break on 3.14 (AST deep-copy). CI pins 3.13; documented for local runs [T1].
3. **mutmut's own readers crash on recent peewee** — `results`/`junitxml` raise `QueryResultIterator object is not iterable`, though the run + sqlite cache are fine. Bypassed with a version-proof stdlib reader [T1].

## Posture & next step

Warn-only at v1 — surviving mutants never block. `scripts/mutation-summary.py
--fail-under N` exists for a future enforced calibration step (per infra master
plan §3.5) feeding the planned **T1 `GATE_TEST_MISSING`** meta-gate. Until then,
survivors from the weekly run are triaged and closed by adding tests to
`scripts/tests/`.

> **Showcase MDX:** published 2026-07-10 at [`fitme-story/content/04-case-studies/60-f18-mutation-testing.mdx`](https://github.com/Regevba/fitme-story/blob/main/content/04-case-studies/60-f18-mutation-testing.mdx) (slot 60 / order 73, v7.10) during the cross-repo doc-freshness reconcile.
