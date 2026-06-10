---
title: "Second What-If Meta-Analysis — the v7.10 framework tested against itself, all layers"
date_written: 2026-06-10
date: 2026-06-10
analysis_type: what-if-self-test
framework_version: v7.10
predecessor: docs/case-studies/meta-analysis/what-if-v6-from-day-one-2026-04-16.md
---

# Second What-If Meta-Analysis — Framework vs Itself, All Layers

**Counterfactual:** *what if we point the current (v7.10) framework's entire
verification machinery at every layer of the system at once — framework, iOS/Swift,
AI engine, backend, web — and let it grade itself?*

**Method:** isolated branch `audit/self-test-meta-analysis-2026-06-10` off `main`
(HEAD `d20ce24`) + a 544-file / 171-state-checksummed platform snapshot first
(`~/Documents/FitTracker2-backups/2026-06-10-pre-self-audit-platform-snapshot`)
so nothing could break. Every layer's real test/verify suite was run.

## Verdict

**The system is sound — nothing is broken.** Every layer's *code* is healthy. The
audit's value is in the **meta-layer**: the framework that gates everything has a
blind spot in its own *local* self-verification, plus a test-taxonomy gap.

## Layer results (all T1 — instrumented, run live 2026-06-10)

| Layer | Result | Notes |
|---|---|---|
| Framework (v7.10) | **0 findings + 1 advisory** | `GATE_COVERAGE_ZERO` (the v7.10 meta-check) passes on itself; isolation 101/101; completeness 0 blocking |
| iOS / Swift | **BUILD SUCCEEDED · 672 unit tests pass** | ui-audit P0=0 (+2 P1 drift); 18 "fails" = parallel-clone simctl env-flake (documented M-4), 0 logic failures |
| AI engine | **34/34 pass** | (first run's 34 fails were a venv missing `pytest-asyncio` — not code) |
| Web (fitme-story) | **286/289 pass** | 3 fails = `zod` declared (`4.3.6`) but not in local node_modules |
| Backend | **0 dedicated test files** | only `README` + `supabase/`; backend logic is tested via the ai-engine FastAPI suite |

## Headline finding — local self-verification is not self-contained, and is inconsistent

Running `make verify-local` against itself revealed the framework gates everything
*except its own ability to run locally*, and it handles missing dependencies **two
different ways**:

- **Hard-fail, cryptic:** `tokens-check` → *"style-dictionary: No such file"*;
  `verify-web` → *"Cannot find module 'zod'"*; `verify-ai` →
  *"async def not supported"*. None say "run npm install / pip install".
- **Skip cleanly, helpful:** `lint-ios` / `lint-py` / `lint-md` / `coverage-*` →
  *"X not installed; skipping (install via …)"*.

A fresh checkout (or a cloud agent) running `make verify-local` dies at
`tokens-check` with an error that reads like a **code break**, not a setup gap —
the same silent-mis-diagnosis class the observed-patterns catalog warns about
(#3 / #7), but inside the **local dev gate itself**.

**Fix shipped in this PR:** `tokens-check`, `verify-web`, `verify-ai` now skip
cleanly with a loud `⚠ … SKIPPING locally — CI enforces this gate.` message when
their deps/venv are absent, matching the lint-target convention already in the
same Makefile. CI installs deps, so the gates still enforce there — only local
runs without setup degrade gracefully instead of crashing cryptically.

## Other findings

| # | Finding | Severity | Action |
|---|---|---|---|
| 1 | `3d-interactive-framework-flow-diagram` committed direct-to-main (BRANCH_ISOLATION_HISTORICAL) | Advisory | **This PR:** set `isolation_opt_out: true` + reason (the documented silence path) |
| 2 | `backend` platform-test taxonomy has no backing suite (5 features claim `backend:true`; `backend/` has 0 tests) | Low | **Follow-up:** document the "backend tested via ai-engine FastAPI" mapping OR add a backend smoke suite |
| 3 | `token-budget.json` 54 days stale (`verify-framework` warns) | Hygiene | **This PR:** regenerate |
| 4 | 2 P1 ui-audit drifts — `HRVTrendChart.swift`, `AIFeedbackSettingsScreen.swift` use `.font(.caption)` raw shorthand | Low | **Follow-up:** fix-as-you-touch (app code, separate PR) |
| 5 | Dep-install fragility reproduced 3× (FT2 npm, ai-engine `.[dev]`, fitme-story `zod`) | — | Root cause behind the headline; addressed by the headline fix |

## What this confirms

iOS builds + 672 tests pass · ai-engine 34/34 · web 286/289 · framework 0 findings ·
the v7.10 `GATE_COVERAGE_ZERO` validates *itself*. The system isn't breaking. The
framework's biggest self-blind-spot is its own local-setup ergonomics — now closed
for the three offending gates — plus the `backend` test-taxonomy gap left as a
documented follow-up.
