---
slug: t14-platform-parity-state-field
title: "T14 platforms_tested — platform-test parity as a queryable state field"
date_written: 2026-06-07
framework_version: v7.9.1
work_type: Feature
work_subtype: framework_feature
case_study_type: in_progress
tier_tags_present: true
status: implementation
case_study: docs/case-studies/t14-platform-parity-state-field-case-study.md
case_study_showcase: ""
related_prs:
  - 662
dispatch_pattern: serial
success_metrics:
  - name: complete_transitions_with_nonempty_platforms_tested
    baseline: 0
    target: 100
    significance: descriptive
    review_at: 2026-06-21
    tier: T2
    note: "Target: 100% of new current_phase=complete transitions carry non-empty platforms_tested (measured via gate-coverage.jsonl). Advisory at ship; measured across the 14-day calibration window."
  - name: existing_complete_features_backfilled
    baseline: 0
    target: 94
    significance: descriptive
    review_at: 2026-06-07
    tier: T1
    note: "94/94 complete features backfilled in one mechanical PR: 25 exempt:framework_meta, 61 heuristic-inferred, 8 low-confidence flagged. Measured by grep over .claude/features/*/state.json."
  - name: false_positives_in_calibration
    baseline: 0
    target: 0
    significance: descriptive
    review_at: 2026-06-21
    tier: T2
    note: "Zero false positives required during the 14-day advisory window before the advisory→enforced flip. Q2 exemption removes the framework-meta FP class up front."
kill_criteria:
  - condition: "False positive rate >5% during the advisory window (gate flags legitimately-platformless features)"
  - condition: "Operator burden — >20% of new complete transitions have an empty array post-backfill, or operators can't determine values"
  - condition: "Field semantics unclear — operators ask >3× in a 30-day window what backend/ai means"
kill_criterion_fired: false
kill_criteria_resolution: "Evaluated at the 14-day advisory-window close (before any advisory→enforced flip); kill_criteria_resolution populated then. K1 mitigated up front by the Q2 framework-meta exemption; K2 by automatic backfill (0 mandatory review); K3 by the locked 4-key semantics table + glossary."
---

# T14 `platforms_tested` — Case Study (live; implementation phase)

> **T1** = instrumented · **T2** = declared · **T3** = narrative. Status: implementation (advisory gate shipped; 14-day calibration pending before the advisory→enforced flip ~v7.10).

## Problem

The framework recorded *that* a feature completed and *that* it had a case study, but **not which platforms its tests actually exercised**. A feature spanning iOS + web + the ai-engine could ship with single-surface coverage and nothing recorded or flagged the asymmetry. Platform-test parity was invisible.

## Approach

Add a structured `platforms_tested: {ios, web, backend, ai}` boolean field, an advisory closure sub-check, and a mechanical backfill. The three open research questions were resolved in [`research.md`](../../.claude/features/t14-platform-parity-state-field/research.md):

- **Q1 (backfill heuristic)** — deterministic offline text-signal heuristic with a `platforms_tested_provenance` flag; **0 mandatory manual review** (low-confidence inferences flagged for optional spot-check). **[T2]**
- **Q2 (framework-meta features)** — **exempt** via the existing `work_type`/`work_subtype` predicate (no meaningless all-`false` records); this removes the false-positive class before it can fire. **[T2]**
- **Q3 (advisory window)** — 14-day advisory→enforced per the v7.9 calibration precedent (T14 extends the *enforced* `FEATURE_CLOSURE_COMPLETENESS` gate → A_high discipline). **[T2]**

### Key design decision — isolated advisory sibling

Rather than entangling a new advisory rule inside the now-*enforced* `FEATURE_CLOSURE_COMPLETENESS` gate, the `PLATFORMS_TESTED` check ships as an **isolated sibling** that fires on the same `complete` transition but carries its **own `PLATFORMS_TESTED_ADVISORY_MODE` flag and its own Mechanism A coverage key**. This keeps the 14-day calibration telemetry clean and makes the advisory→enforced flip a single independent line — it cannot accidentally weaken or entangle the enforced gate beside it.

## What shipped (PR #662)

- **T2+T3** — `platforms_tested` + `platforms_tested_provenance` shape validation + the advisory `PLATFORMS_TESTED` non-empty-at-complete sub-check with the Q2 exemption, in `scripts/check-state-schema.py`. 15 unit tests. **[T1]**
- **T4** — `scripts/backfill-platforms-tested.py` (pure, tested heuristic + provenance tagging + valid-JSON-guaranteed insertion) + 9 unit tests; **backfilled 94 complete features** (25 exempt, 61 inferred, 8 low-confidence). **[T1]**
- **Bonus fix** — found and closed a **second instance of the W34 PR-truncation class**: the gate's live `gh pr list --limit 500` excluded PRs <#163, so touching old features falsely flagged their real merge PRs. Raised to 2000 (matching PR #631's fix for the other reader). **[T1]**
- **48 tests pass** (15 + 9 new + 24 existing schema). **[T1]**

## What it caught on the way

The backfill's required-key assertion surfaced a real schema fact: the state.json **identity field is not invariant** — older features use `feature`, newer use `feature_name`, fitme-story-native reverse-mirrors use `name`. (This same heterogeneity was independently caught by the F-CONTRACT-FIXTURE-SAMPLING aggregator the same day.) Backfill provenance tagging means the 8 low-confidence inferences are honestly recorded, not silently guessed. **[T1]**

## Remaining (the loop, honestly)

- **T5** dev-guide §5.4 + gate catalog — ✅ done (this PR).
- **T6** CLAUDE.md "Platform-test parity" section — ✅ done (this PR).
- **T7** fitme-story dev-guide mirror + glossary entry — cross-repo (fitme-story session).
- **T8** showcase MDX — cross-repo (fitme-story session); this source case study is the FT2 half.
- **T9** advisory→enforced calibration — calendar-anchored (~v7.10, after the 14-day window). Cannot be compressed.

The feature stays at `implementation` until the calibration window closes — that is the honest state; it cannot reach `complete` before T9.
