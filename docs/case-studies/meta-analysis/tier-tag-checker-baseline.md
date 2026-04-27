---
date_written: 2026-04-27
work_type: Documentation
dispatch_pattern: serial
success_metrics:
  primary: "FP rate <10% on random sample for promotion to gate"
kill_criteria:
  - "FP rate >25% after 2 weeks → ship advisory permanently, no promotion"
status: baseline
---

# Tier-Tag Checker Baseline (v7.7 M3 T19)

> Captured 2026-04-27 by v7.7 M3 T19. Measures false-positive rate on a
> random sample to decide whether `TIER_TAG_LIKELY_INCORRECT` graduates
> from cycle-time advisory to cycle-time gate at +7 days (T20 review).

## Total findings (baseline)

`1` finding across `1` case study. Generated via `make validate-tier-tags`.

The low finding count reflects that very few post-2026-04-21 case studies
contain T1-tagged claims in the `**T1**: <number><unit>` syntax that the
regex targets. Most T1 tags in the corpus appear in table-column format
(`| value | T1 |`) which the current regex does not match.

## Random sample classification

All 1 finding classified (< 10 total, so full population is sampled):

| # | File | Claim (T1) | Verdict | Reason |
|---|---|---|---|---|
| 1 | `framework-v7-7-validity-closure-case-study.md:55` | `3.2d` | FP | Regex matched `3` from `Tier 3.2` (section identifier) + `d` from `documentation` (next word, misread as "days"). Not a quantitative claim. |

## FP rate

`1 / 1 = 100%`

## Decision criteria (pre-registered)

- `< 10%` → schedule promotion to gate at +7 days (T20)
- `10-25%` → iterate on heuristic before promoting
- `> 25%` → kill criterion 2 fires; ship advisory permanently

**Outcome: kill criterion 2 fires at baseline scan.**

FP rate of 100% on the full population (n=1) exceeds the >25% threshold.
`TIER_TAG_LIKELY_INCORRECT` ships permanently as advisory-only. No promotion
to gating in v7.7 or a follow-up PR.

Note: the sample is very small (n=1) because the regex only targets the
`**T1**: <number><unit>` prefix pattern, which appears in very few post-cutoff
case studies. The single finding is unambiguously a false positive. With n=1
the FP rate is either 0% or 100% — there is no uncertainty here; the classification
is clear-cut.

## Common false-positive patterns observed

**Pattern 1: Section identifier misread as numeric claim.** The text
`Tier 3.2 documentation debt [T1]:` triggers the regex because `3.2` looks
like a number, the subsequent word `documentation` starts with `d` (a valid
time unit in the regex), and `[T1]` is nearby. The fix would be to require
the T1 tag to appear *before* the number in the same clause, or to exclude
numbers that are part of `Tier X.Y` section references. This pattern will
recur in any case study that references the Tier framework by section number
inline with a T1 tag.

**Pattern 2: Table column format not detected.** The corpus predominantly
uses `| value | T1 |` table format for tier tags. The current regex does not
match this format at all — meaning it both under-detects real T1 claims
(producing no true positives) and over-detects in the `**T1**: text` prefix
format where section numbers appear. Fixing this would require a second
regex pass for table rows.

**Pattern 3: Proximity overmatch.** The regex matches a T-tag and the nearest
number + unit within the same line, even when the number is not the *claim*
being tagged. In the observed FP, the T1 tag annotates "7 open items" (a
count, not a measurement with a unit) but the regex picked up `3.2` + `d`
from the surrounding context instead.

## Common true-positive patterns observed

No true positives were observed in the baseline scan. The regex's T1
detection works correctly when claims are written in the `**T1**: <value><unit>`
prefix style (as validated by the unit tests), but this pattern is rare
in the live corpus. The actual T1-tagged measurements that exist in the
corpus use table format and are not reachable by the current heuristic.

## Promotion plan

**Kill criterion 2 fired at baseline.** `TIER_TAG_LIKELY_INCORRECT` stays
advisory permanently. No +7d promotion review needed for this version.

To revisit in a future version (v7.8+):
1. Extend the regex to cover the `| value | T1 |` table column format,
   which is how tier tags actually appear in the live corpus.
2. Add an exclusion for `Tier X.Y` section references (e.g., require that
   the number not be preceded by the word "Tier").
3. Re-run a baseline scan on all post-2026-04-21 case studies.
4. Re-evaluate FP rate on a sample of ≥10 findings before promoting.

The v7.7 heuristic is left in place as advisory infrastructure — it provides
zero false gating risk and will surface genuine mismatches if case studies
begin using the `**T1**: value%` prefix style for quantitative claims.
