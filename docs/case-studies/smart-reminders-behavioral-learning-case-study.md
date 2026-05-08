---
slug: smart-reminders-behavioral-learning-case-study
title: "Smart Reminders Behavioral Learning — PR-1 Shipped Across iOS + Backend"
date: 2026-05-04
framework_version: v7.8
work_type: enhancement
work_subtype: sub_feature
case_study_type: shipped
tier_tags_required: true
status: shipped
case_study: docs/case-studies/smart-reminders-behavioral-learning-case-study.md
case_study_showcase: fitme-story/content/04-case-studies/23-smart-reminders-behavioral.mdx
parent_case_study: docs/case-studies/smart-reminders-system-case-study.md
parent_feature: smart-reminders
related_specs:
  - docs/superpowers/specs/2026-05-01-smart-reminders-behavioral-learning-design.md
related_plans:
  - docs/superpowers/plans/smart-reminders-behavioral-learning-pr-1.md
  - docs/superpowers/plans/smart-reminders-behavioral-learning-pr-2.md
related_prs:
  - 190  # iOS half (squash 516eef0)
  - 198  # backend half (squash 04eeac6)
  - 199  # PR-2 plan
dispatch_pattern: serial
success_metrics:
  - name: aggregate_tap_through_lift_pp
    baseline: 0.0
    target: 5.0
    significance: p < 0.05
    review_at: 2026-05-23
    tier: T1
    note: "Cannot evaluate until PR-2 ships + 14 ± 4 day per-user window completes"
kill_criteria:
  - condition: "Aggregate tap-through lift < +0 pp at end of per-user readout AND post-population aggregate also fails"
  - condition: "Any single personalised type regresses by >= -3 pp vs static baseline → per-type rollback"
  - condition: "Disable rate +>= 3 pp OR dismiss rate >= +5 pp from baseline (advisory composite)"
kill_criterion_fired: false
---

# Smart Reminders Behavioral Learning — PR-1 Case Study

> **Status:** PR-1 shipped 2026-05-04 in two halves: FT2 PR #190 (iOS data layer + Settings toggle, squash `516eef0`) and FT2 PR #198 (backend AI-engine endpoints + retention migration `000009`, squash `04eeac6`).
> **Framework version:** v7.8 (Bridge Mechanisms A–F advisory).
> **Parent feature:** smart-reminders (showcase slot 08a).
> **Showcase:** `fitme-story/content/04-case-studies/23-smart-reminders-behavioral.mdx`.

This is a **scaffold case study**. The substantive narrative lives in the showcase MDX above and accumulates as PR-2 and PR-3 ship. PR-1's footprint is intentionally narrow — it's the data-collection layer with the user-facing toggle defaulting OFF. The "did personalisation work?" question is PR-2 territory.

---

## 1. Summary card

| Field | Value | Tier |
|---|---|---|
| Sub-feature of | smart-reminders | — |
| Framework version | v7.8 | T1 |
| Work type | Enhancement (sub-feature of shipped parent) | T1 |
| PR-1 tasks: planned / complete | 15 / 15 | T1 |
| XCTests / pytests passing | 23 / 19 | T1 |
| Personalisable reminder types | 3 of 6 (Nutrition Gap, Training Day, Rest Day) | T1 |
| PRs shipped (PR-1) | 2 (#190 iOS · #198 backend) | T1 |
| Cache hits logged | 2 (L1 PRD-Phase-3 frame + L2 cohort_stats discovery) | T1 |
| cu_v2 total / tier_class | 2.15 / B_medium | T1 |
| Migration shipped | `000009` (no-op acknowledgement; segment-agnostic retention already in `000004`) | T1 |
| Headline | "Bayesian per-user posterior + Supabase server-cohort prior. Toggle ships OFF; PR-2 flips it ON after data warms." | T3 |

---

## 2. Why this exists as a sub-feature

The parent **smart-reminders** feature shipped 2026-04-16 (case study at `docs/case-studies/smart-reminders-system-case-study.md`, showcase 08a). The 6 reminder types (Nutrition Gap, Training Day, Rest Day, HealthKit Connect, Account Registration, Engagement) all fired at static defaults — uniform times tuned by the original PRD, not personalised.

Behavioral Learning is the personalisation layer: a Bayesian per-user posterior on tap-through-by-hour mixed with a Supabase-derived server cohort prior. PR-1 ships the data collection + storage + toggle. PR-2 ships the consumer (`SmartTimingResolver`) + A/B test arm + flips the default to ON. PR-3 ships the per-type "Why this time?" affordance.

This case study scaffolds PR-1 only and grows as the later PRs land.

---

## 3. PR-1 phase ledger

| Phase | Status | Anchor |
|---|---|---|
| Brainstorm | done 2026-04-30 | OQ-1..OQ-5 locked |
| Spec | done 2026-05-01 | `docs/superpowers/specs/2026-05-01-smart-reminders-behavioral-learning-design.md` |
| PRD | skipped (sub-feature; parent has PRD; brainstorm+spec is the right granularity) | state.json `phases.prd.skipped_reason` |
| Tasks | 15 PR-1 tasks declared | `docs/superpowers/plans/smart-reminders-behavioral-learning-pr-1.md` |
| UX | minimal — single Settings toggle row using v2 design-system tokens | `BehavioralLearningSettingsView` |
| Implementation | 2 PRs landed 2026-05-04 | #190 (iOS, `516eef0`) + #198 (backend, `04eeac6`) |
| Test | 23 XCTests + 19 pytests pass | reported by `xcodebuild test` + pytest CI |
| Review | both PRs green on `pm-framework/pr-integrity` | per-PR review bot |
| Merge | done 2026-05-04 | squash merges |
| Documentation | this case study + showcase MDX 23 | scaffolds; populates as PR-2/PR-3 ship |

---

## 4. What PR-1 actually shipped

**iOS half (PR #190 / `516eef0`):**
- `BehavioralLearningStore` (per-user posterior — alpha/beta over 24 hourly bins)
- `BehavioralLearningSettingsView` (single toggle row, defaults OFF)
- 3 personalisable reminder types wired to log tap/dismiss events
- 23 XCTests covering store math, decay, edge cases, settings flow

**Backend half (PR #198 / `04eeac6`):**
- AI-engine endpoint surface for cohort prior reads
- Retention migration `000009` (versioned no-op — segment-agnostic retention already in `000004`)
- 19 pytests covering endpoints, cohort aggregation queries, edge cases

PR-1 success = "data layer collects, toggle works, no regression in static-default behavior". The aggregate tap-through lift metric **cannot be measured yet** — it requires PR-2 to ship + the 14 ± 4 day per-user readout window.

---

## 5. Honest disclosures

> All entries below are also surfaced in the showcase MDX `honest_disclosures` array.

- **No new UX beyond a single toggle.** Per-type "Why this time?" affordance is PR-3, not PR-1.
- **Migration 000009 is intentionally no-op.** Documents that retention `000004` already covers the new segment values; introduces no new table.
- **PRD phase skipped.** Brainstorm + design spec is the right granularity for a sub-feature whose parent already has a PRD. State.json `phases.prd.skipped_reason` records the rationale.
- **3 of 6 types personalised.** HealthKit Connect / Account Registration / Engagement keep static defaults — their lifetime caps (≤ 3 fires) make personalised timing not meaningfully move the metric.
- **PR-2 cannot start before 2026-05-09.** Needs ~5-7 days of cohort_stats accumulation before per-segment baselines are stable enough for the A/B comparison.
- **Toggle defaults OFF.** PR-1 ships data collection only; PR-2 flips the default to ON when the consumer + A/B test arm land.

---

## 6. Deferred items (not failures — sequencing)

| Item | Owner | Earliest | Anchor |
|---|---|---|---|
| PR-2 SmartTimingResolver + A/B test + toggle default ON | this sub-feature | 2026-05-09 | `docs/superpowers/plans/smart-reminders-behavioral-learning-pr-2.md` (PR #199) |
| PR-3 "Why this time?" per-type affordance | this sub-feature | after PR-2 settles | state.json `phases.ux_or_integration.skipped_reason` |
| Aggregate tap-through readout | primary success metric | after PR-2 + 14 ± 4 day window | state.json `success_metrics[0]` |

---

## 7. Framework cross-references

- **v7.8 Mechanism C** (PostToolUse:Read auto-instrumentation) captured the 2 cache hits logged here — first sub-feature to benefit from automatic cache-hit instrumentation.
- **v7.8 Mechanism A** (coverage-asserting gates) emitted gate-coverage events on every PR-1 commit — visible in `.claude/logs/gate-coverage.jsonl`.
- **`STATE_NO_CASE_STUDY_LINK`** (v7.7 write-time gate): this file closes that linkage. State.json `case_study` field now resolves to a real path.

---

## 8. What this case study will become

This file is intentionally a **scaffold**. As PR-2 and PR-3 ship, the substantive content (A/B test results, per-type movement vs baseline, kill-criterion firings if any, the actual aggregate tap-through lift) accumulates here. The showcase MDX evolves in parallel.

PR-1 is "the data layer ships and the toggle works". The case study ships at that scope and grows as the personalisation surface matures.
