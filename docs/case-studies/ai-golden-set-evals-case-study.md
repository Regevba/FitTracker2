---
title: "T10 — AI Golden-Set Eval Harness (and why the FitMe AI is deterministic, not generative)"
slug: ai-golden-set-evals
date_written: 2026-06-10
date: 2026-06-10
work_type: Feature
work_subtype: b_medium
dispatch_pattern: "operator-driven (T10 from the test-coverage master plan)"
framework_version: v7.10
state_owner: ft2
case_study_type: feature
primary_metric: "Golden-set behavioral coverage of the deterministic AI insight engine: every InsightService rule + confidence band + escalation threshold pinned by ≥1 golden case, run in the ai-engine pytest suite as a PR gate."
success_metrics:
  primary: "All 4 InsightService segments (training/nutrition/recovery/stats) + confidence scoring + escalate_to_llm threshold covered; ai-engine suite green (60 passed, 1 skipped) — achieved 2026-06-10."
  secondary:
    - "Edge cases pinned: empty user_fields (no div-by-zero), zero/saturated cohort, unknown segment, empty cohort_totals"
    - "Negative control proven: mutating a rule makes a golden case fail (the harness catches AI-logic regressions by construction)"
    - "Live-LLM eval path scaffolded + skips cleanly when LLM_API_KEY unset (matches the framework's dep-skip convention)"
kill_criteria:
  - "Golden harness becomes flaky (non-deterministic) — would violate the 'deterministic AI is gateable' premise; revert to advisory."
  - "Golden set pins implementation detail rather than behavioral contract (brittle to benign refactors)."
kill_criteria_resolution: "Neither fired. The harness asserts BEHAVIORAL contracts (signal presence/absence, confidence bands, escalate boolean) not internal structure, and InsightService is pure-deterministic so flake is structurally impossible (60/60 deterministic passes). The live-LLM path is gated behind an unset LLM_API_KEY (requires a DPA) and skips cleanly, so it adds zero flake. The negative-control experiment (mutate a rule → golden case fails) proves the set catches real regressions rather than rubber-stamping."
tier_tags_present: true
related_prs: []
---

# T10 — AI Golden-Set Eval Harness

> **Status:** shipped 2026-06-10. The first behavioral test coverage of FitMe's AI decision logic — the "biggest layer gap" per the test-coverage master plan.

## 1. The scoping surprise: the AI is deterministic, not generative

T10 was spec'd in the test-coverage master plan as an *"LLM golden-set eval harness — promptfoo-equivalent weekly run."* That framing assumed the AI is generative. **It isn't.**

`ai-engine/app/services/insight_service.py::InsightService.generate()` is a **pure deterministic rule engine**: given a segment + `user_fields` + `cohort_totals`, it emits population-level `signals`, a `confidence` score (`coverage_ratio × 0.6 + cohort_signal × 0.4`), and an `escalate_to_llm` boolean (`confidence < 0.40`). The generative LLM path is **gated behind an unset `LLM_API_KEY`** (requires a Data Processing Agreement) and is not the live behavior. The federated-cohort intelligence + on-device Foundation Models layer do the personalization; the server emits *signals*, not prose.

**This makes a golden set strictly better than a promptfoo run:** the behavior is deterministic, so the eval has **zero flake, needs no API key, and runs as a hard PR gate** in the existing pytest suite — rather than a flaky weekly advisory.

## 2. What shipped

- **`ai-engine/tests/golden/insight_cases.jsonl`** — 24 golden cases [T1, instrumented] covering:
  - all 3 rules in each of the 4 segments (training / nutrition / recovery / stats) + their no-match cases;
  - confidence scoring (full-coverage-large-cohort → ≈1.0; sparse-tiny-cohort → escalates);
  - the `escalate_to_llm` < 0.40 boundary;
  - edge cases: empty `user_fields` (no div-by-zero), empty/saturated `cohort_totals`, unknown segment.
- **`ai-engine/tests/test_golden_insights.py`** — a parametrized harness that runs each case through the real `InsightService` and asserts the behavioral contract (`signals_contains` / `signals_excludes` / `signals_empty`, `confidence_min`/`max`, `escalate_to_llm`, `supporting_total_cohort_size`), plus a coverage assertion (≥20 cases, all 4 segments present) and an explicit escalation-threshold pin.
- **Live-LLM eval scaffold** — `test_llm_eval_golden_subset_when_key_present` skips cleanly when `LLM_API_KEY` is unset (the default), so the weekly promptfoo-equivalent run can land later without changing the harness shape.

## 3. Verification (all 2026-06-10, T1 — instrumented)

- **`pytest tests/test_golden_insights.py` → 26 passed, 1 skipped.**
- **Full ai-engine suite → 60 passed, 1 skipped** (34 pre-existing endpoint tests + the new behavioral coverage; no regression).
- **Negative control (the value proof):** mutating one rule (`cohort_muscle_gain_foundation_common` → a typo) made exactly the corresponding golden case **fail** — the set catches AI-logic regressions by construction, not by rubber-stamp.

## 4. Why this matters

Before T10, the 34 ai-engine tests covered the *transport* (auth, payload validation, fire-and-forget) but **none asserted what the AI actually decides.** A refactor could silently drop the `deload_advised` recovery signal or shift the escalation threshold and every test would still pass. T10 closes that: the AI's decision behavior is now pinned, deterministic, and gated at PR time — the highest-value AI test work, and its only blocker (the Phase 2-bis prompt-set stabilizing) was cleared when all four sub-experiments closed PASS on 2026-06-05.

## 5. Cross-references

- **Spec:** [`docs/master-plan/test-coverage-master-plan-2026-05-13.md`](../master-plan/test-coverage-master-plan-2026-05-13.md) §T10.
- **Target:** `ai-engine/app/services/insight_service.py`.
- **Successor gaps (documented in the test plan):** Supabase Edge Functions remain unaudited (0 tests); the gated LLM escalation path's live eval lands with that feature.
