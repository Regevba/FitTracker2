# `kill_criteria_resolution` Backfill Decision — 2026-05-18 (FIT-69)

> **Generated:** 2026-05-18 (T-3 days before the v7.9 promotion decision 2026-05-21)
> **Framework version at publication:** v7.8.6
> **Decision tracker:** [FIT-69](https://linear.app/fitme-project/issue/FIT-69) (Linear)
> **Companion advisory:** v7.8.1 `FEATURE_CLOSURE_COMPLETENESS` Q7 (advisory, forward-only)
> **Source backlog row:** [`docs/product/backlog.md`](../../product/backlog.md) §"High Priority (Architecture & Framework)"
> **Open debt count at decision time:** 61 case studies missing `kill_criteria_resolution` per [`.claude/shared/documentation-debt.json`](../../../.claude/shared/documentation-debt.json) (2026-05-18T04:49Z snapshot)

## TL;DR

We are NOT backfilling `kill_criteria_resolution` on the 61 grandfathered case studies. They stay grandfathered. The advisory itself was designed forward-only; backfilling now would contaminate the 2026-05-15 → 2026-05-21 v7.9 calibration window; and the de-facto resolution for all 61 is the same trivial value (`not_fired` — they all shipped without revert). This document is the explicit decision record so the grandfather status is visible rather than buried.

## Why this decision is being made now

`FEATURE_CLOSURE_COMPLETENESS` Q7 (shipped v7.8.1 advisory, 2026-05-07) requires `kill_criteria_resolution` whenever `kill_criteria` is set on a case study. The advisory explicitly grandfathered existing case studies:

> ADVISORY (v7.8 forward-only): if you author a NEW case study post-2026-05-07 with `kill_criteria`, also set `kill_criteria_resolution`. Existing case studies are grandfathered until v7.9 promotion may opt to backfill.

The v7.9 promotion decision (2026-05-21) is the moment at which "may opt to backfill" must be resolved one way or the other. This document closes that loop.

## The numbers

From `.claude/shared/documentation-debt.json` 2026-05-18T04:49Z (the freshest snapshot before the decision):

- 76 case studies scanned
- 15 carry `kill_criteria_resolution` (19.7%)
- **61 missing `kill_criteria_resolution`** — every other doc-debt field is at 100% coverage; this is the *only* open debt item across the entire framework
- All 61 were authored before 2026-05-07 (when the advisory shipped) and therefore explicitly grandfathered by the advisory wording above

## Three options considered

| Option | Cost | Effect on v7.9 calibration window | Effect on doc-debt |
|---|---|---|---|
| **(a) Backfill all 61 individually** | 3-5h judgment per case study | Writes 61+ new closure_completeness candidate rows into `gate-coverage.jsonl` between 2026-05-15 → 2026-05-21 → breaks criterion #2 ("no false positives baseline") | Closes debt to 0 |
| **(b) Selective top-20% backfill** | ~1h | Same contamination risk, scaled down | Closes debt to ~48 |
| **(c) Explicit grandfather record (THIS DOCUMENT)** | 5 min | Zero contamination — pure doc artifact, no per-case-study writes | Closes debt logically; the open count stays 61 but with an explicit decision record pointing here |

## Why we picked (c)

### 1. The advisory itself is forward-only by design

The v7.8.1 ship text uses the explicit word "grandfathered." Backfilling retroactively would erase the design choice. The advisory exists to enforce the rule on *new* closures — not to retrofit historical ones. If we wanted retrofit, the v7.8.1 spec would have shipped a backfill migration alongside the gate. It deliberately did not.

### 2. Backfilling NOW would contaminate the v7.9 calibration window

The 2026-05-21 v7.9 promotion decision evaluates `gate-coverage.jsonl` over the prior 7-day window (2026-05-14 → 2026-05-21) against the criterion "no false positives." Editing 61 case studies during that window would write 61 new `FEATURE_CLOSURE_COMPLETENESS` candidate rows into the ledger — not because those features are *changing*, but because the schema is. Those rows would be indistinguishable from real closure events in the ledger and would distort the false-positive baseline that criterion #2 evaluates.

This is the same contamination class identified for the C1 F14/F15 dispatch-test push, which was *also* deferred to 2026-05-22 specifically to protect the calibration window (see [`.claude/shared/must-have-cadence-followups.md`](../../../.claude/shared/must-have-cadence-followups.md) §C1).

The protection is the same here: any large-scale schema retrofit during 2026-05-15 → 2026-05-21 must defer to 2026-05-22 at earliest. The question then is whether the retrofit is worth doing on 2026-05-22 at all, given §3 below.

### 3. The implicit resolution for all 61 is identical: `not_fired`

Every one of the 61 case studies describes a feature that shipped without revert. None of them triggered their stated `kill_criteria`. The frontmatter `kill_criteria_resolution` field, if backfilled, would receive the same value 61 times: `"not_fired"` (or some near-synonym like `"kill_criteria_did_not_fire"`).

That is not new information. It is the absence of an incident. Documenting an absence once, in a meta-analysis, is more honest than fabricating per-feature resolution prose 61 times. A reader looking at any one of the 61 case studies can:

1. Note the absence of `kill_criteria_resolution` in the frontmatter
2. Note the case study describes a successful ship (it would not be a case study otherwise)
3. Cross-reference this document for the framework-wide policy

That readout is fully equivalent to a 61× backfill of the same value. The information content is preserved.

### 4. v7.9 promotes forward-only enforcement — no backfill is structurally required

The v7.9 promotion (2026-05-21) flips `FEATURE_CLOSURE_COMPLETENESS` from advisory → enforced *for new closures*. The gate, when enforced, will block any future `current_phase=complete` transition without a populated `kill_criteria_resolution`. It will not retroactively block historical closures because they are already in `complete` phase and the gate fires only at the transition point.

This means the 61 grandfathered case studies are *structurally* invisible to the enforced gate. The gate's effective coverage is `forward-only-from-2026-05-21`. Backfilling them would not improve the framework's mechanical guarantees — only its cosmetic completeness.

## What this document IS NOT

- It is not a one-time amnesty. New case studies must continue to populate `kill_criteria_resolution`. The advisory's forward-only rule stays load-bearing.
- It is not a precedent for skipping other backfills. The reasoning here is specific to (a) the field's de-facto value being trivial across all 61, (b) the v7.8.1 advisory's explicit grandfather wording, and (c) the timing collision with the v7.9 calibration window. Future backfill questions need their own justification.
- It is not a substitute for the case studies themselves. Each of the 61 case studies remains the authoritative record of its feature; this document only covers the missing field.

## What happens after 2026-05-21

The doc-debt JSON will continue to show "61 missing" for `kill_criteria_resolution`. This is correct — the field IS missing — but the count is annotated by this decision record. A future operator reading `make documentation-debt` should:

1. See the 61 count
2. Cross-reference this file
3. Treat the 61 as a *known and accepted* grandfather class, not as undone work

If at some later point a per-case-study revisit is justified (e.g., one of the 61 turns out to have had a kill criterion that *did* fire but went undocumented), the right path is a meta-analysis correction for that *specific* case study — escalated as a documentation incident — not a bulk retrofit.

## Open question deferred to v7.10 or later

Should the doc-debt scanner gain a "grandfathered" annotation column so the 61 count reads as `61 (grandfathered, see kill-criteria-resolution-backfill-decision-2026-05-18.md)` rather than just `61`? That is a v8.x tooling improvement, not a v7.9 promotion question. Tracked informally here; if it surfaces enough operator confusion, file as a backlog item.

## Cross-references

- [`docs/product/backlog.md`](../../product/backlog.md) — FIT-69 row
- [Linear FIT-69](https://linear.app/fitme-project/issue/FIT-69)
- [`.claude/shared/documentation-debt.json`](../../../.claude/shared/documentation-debt.json) — open debt source
- [`.claude/shared/must-have-cadence-followups.md`](../../../.claude/shared/must-have-cadence-followups.md) §C1 — same calibration-window protection argument applied to F14/F15
- [`docs/master-plan/infra-master-plan-2026-05-12.md`](../../master-plan/infra-master-plan-2026-05-12.md) §4.1 — v7.9 promotion docket
- [`docs/case-studies/framework-v7-8-branch-isolation-case-study.md`](../framework-v7-8-branch-isolation-case-study.md) — v7.8.1 origin of the `FEATURE_CLOSURE_COMPLETENESS` Q7 advisory
- [`feedback_publish_verbatim_then_remediate.md`](../../../.claude/feedback/) — policy precedent: gaps stay visible; we do not collapse them silently

## Decision record

| Date | Action | Author |
|---|---|---|
| 2026-05-18 | Decision (c) — grandfather, no backfill — documented | Operator (Regev) + Claude Opus 4.7 |
| 2026-05-21 | v7.9 promotion decision (whether `FEATURE_CLOSURE_COMPLETENESS` flips advisory → enforced) — does NOT alter this decision | TBD |
| 2026-05-22+ | If decision changes (e.g., operator wants partial backfill after all), file new entry | TBD |
