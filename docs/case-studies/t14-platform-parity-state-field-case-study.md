---
slug: t14-platform-parity-state-field
title: "T14 platforms_tested — platform-test parity as a queryable state field"
date_written: 2026-06-07
framework_version: v7.9.1
work_type: Feature
work_subtype: framework_feature
case_study_type: shipped
tier_tags_present: true
status: complete
case_study: docs/case-studies/t14-platform-parity-state-field-case-study.md
case_study_showcase: content/04-case-studies/48-t14-platform-parity.mdx
related_prs:
  - 662
  - 781
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
pr_citation_exempt:
  - pr_number: 631
    reason: "Cross-reference to the W34 PR-truncation fix in another reader (PR #631), cited as prior art — not a t14 deliverable PR."
kill_criteria_resolution: "B15 calibration evaluated 2026-06-21 (advisory window 2026-06-07 PR #662 → 2026-06-21). VERDICT: PROMOTE — all 3 kill criteria not_fired. K1 (FP >5%): not_fired [T1 — 0 failure rows across 16 real complete-transition checks on the isolated PLATFORMS_TESTED coverage key; all 1470 skips legitimate]. K2 (operator burden >20% empty): not_fired [T1 — 0 platforms_tested_empty findings on real transitions; backfill populated all pre-T14 complete features]. K3 (semantics unclear >3 asks/30d): not_fired [T2 — no operator clarification requests logged]. `PLATFORMS_TESTED_ADVISORY_MODE` flipped True→False (enforced) via PR #781 (6ac372b). Reversible single-flag revert."
---

# T14 `platforms_tested` — Case Study (complete)

> **T1** = instrumented · **T2** = declared · **T3** = narrative. Status: **complete** — advisory gate shipped 2026-06-07 (PR #662); promoted advisory→enforced 2026-06-21 (PR #781, `6ac372b`) after the 14-day B15 calibration window with all four §2.2 criteria GREEN.

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

## Task ledger (all done)

- **T5** dev-guide §5.4 + gate catalog — ✅ done.
- **T6** CLAUDE.md "Platform-test parity" section — ✅ done (refreshed to enforced 2026-06-21).
- **T7** fitme-story dev-guide mirror + glossary entry — ✅ done (cross-repo).
- **T8** showcase MDX — ✅ done ([`content/04-case-studies/48-t14-platform-parity.mdx`](https://github.com/Regevba/fitme-story/blob/main/content/04-case-studies/48-t14-platform-parity.mdx)); this source case study is the FT2 half.
- **T9** advisory→enforced calibration — ✅ **DONE 2026-06-21** (PR #781). Verdict PROMOTE; `PLATFORMS_TESTED_ADVISORY_MODE = False`.

## Promotion (cadence B15, 2026-06-21)

The 14-day advisory window (2026-06-07 → 2026-06-21) closed clean. All four §2.2 promotion criteria held against the isolated `PLATFORMS_TESTED` Mechanism A coverage key:

1. **Coverage emitted** — 9 emission days across a 12-day span (≥7d required). **[T1]**
2. **No false positives** — 0 failure rows across 16 real `complete`-transition checks; the Q2 framework-meta exemption removed the FP class up front. **[T1]**
3. **No silent skips** — all 1470 skips legitimate (`no_phase_change` / `not_complete_transition` / `not_staged_mode` + 22 Q2-exempt). **[T1]**
4. **Reversible** — single-flag revert (`PLATFORMS_TESTED_ADVISORY_MODE = True` on `chore/t14-rollback`) restores advisory in <5 min. **[T2]**

`PLATFORMS_TESTED` findings now route to `errors[]` and block the commit on a `complete` transition with no platform key `true`. Existing complete features do not re-transition, so none fail retroactively — `make integrity-check` reports 0 findings post-flip. The feature reaches `complete` honestly: the gate it ships is now load-bearing.
