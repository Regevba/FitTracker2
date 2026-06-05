---
slug: f-phase-e-adoption-freeze-discipline
title: "F-PHASE-E-ADOPTION-FREEZE-DISCIPLINE — Soak-window adoption-metric discipline"
date_written: 2026-06-04
framework_version: v7.9.1
work_type: Feature
work_subtype: framework_feature
case_study_type: shipped
tier_tags_required: true
status: shipped
case_study: docs/case-studies/f-phase-e-adoption-freeze-discipline-case-study.md
case_study_showcase: ""
related_prs: [625]
pr_citation_exempt:
  - pr_number: 624
    reason: "Cross-reference to F-LAUNCHD-DRIFT-EXTENSION (b)+(c) closure PR — historical context for the same-session W30 surfacing, not this feature's own PR"
dispatch_pattern: serial
success_metrics:
  - name: rule_codified_in_claude_md
    baseline: 0
    target: 1
    significance: descriptive
    review_at: 2026-06-04
    tier: T1
    note: "(T1) CLAUDE.md gains a 'Soak-window discipline (v7.9.1+)' subsection between F-LAUNCHD-DRIFT-EXTENSION and Known Mechanical Limits. Measured by section presence at merge time."
  - name: backlog_cross_reference
    baseline: 0
    target: 1
    significance: descriptive
    review_at: 2026-06-04
    tier: T1
    note: "(T1) docs/product/backlog.md gains a new 'Framework hygiene' subsection with 2 entries (this rule + the W30 parser durable-fix). Measured by section presence at merge time."
  - name: soak_window_regression_documented_pp
    baseline: 0
    target: 11.7
    significance: descriptive
    review_at: 2026-06-04
    tier: T2
    note: "(T2) v7.9 Phase E observed regressions documented in the rule's rationale: -1.6 pp (adoption) + -9.4 pp (timing_wall_time) + -1.7 pp (cache_hits) = 11.7 pp aggregated dilution from 9 features added during the soak window with no adoption-metric backfill."
kill_criteria:
  - "Documentation gets stale and operators ignore it — no enforcement teeth at v7.9.1 ship; depends on operator attention"
  - "Future framework versions adopt a different soak-window model (continuous vs phased) — the rule must reference 'soak-window' generically, not 'Phase E' specifically"
kill_criteria_resolution: "Both mitigated by the spec's design. (1) The promotion clause built into the rule ('enforce if 2 consecutive soak windows show >5 pp regression on any post-v6 percentage metric') gives the advisory rule a concrete trigger for upgrading to a write-time gate (`SOAK_WINDOW_FREEZE_OR_BACKFILL`). The 2026-05-28 v7.9 baseline + the next post-soak baseline (v7.10) will be the first 2 data points. (2) The rule uses 'soak window' as the generic concept and 'Phase E for v7.X' as a specific instance — see CLAUDE.md section header. Promotion test recognizes any soak-window-style validation period, not just Phase E by name."
primary_metric: "rule_codified_in_claude_md = 1 (T1, present at merge time)"
predecessor_case_study: docs/case-studies/framework-v7-9-promotion-case-study.md
spec: ".claude/shared/v7-9-1-candidates.md F-PHASE-E-ADOPTION-FREEZE-DISCIPLINE + docs/case-studies/framework-v7-9-promotion-case-study.md §99.4 lesson 2"
key_numbers:
  v7_9_phase_e_dates: "2026-05-21 → 2026-05-28 (Days 1-7)"
  features_added_during_soak: 9
  adoption_pct_regression_pp: 1.6
  timing_wall_time_pct_regression_pp: 9.4
  cache_hits_pct_regression_pp: 1.7
  aggregated_regression_pp: 11.7
  promotion_threshold_pp: "5 (per consecutive soak window)"
  ship_class: "ADVISORY (doc-only; no gate)"
---

## TL;DR (T1 unless tagged)

v7.9 Phase E (2026-05-21 → 2026-05-28) added **9** new features to `.claude/features/*/` without backfilling their adoption metrics. `make integrity-diff` against the 2026-05-14 anchor consequently surfaced **3 measured percentage regressions** that triggered weekly trend-scan alerts:

| Metric | 2026-05-14 | 2026-05-28 | Δ |
|---|---|---|---|
| `adoption_pct_post_v6` | 8.3% | 6.7% | −1.6 pp |
| `timing_wall_time_pct_post_v6` | 47.2% | 37.8% | **−9.4 pp** |
| `cache_hits_pct_post_v6` | 52.8% | 51.1% | −1.7 pp |

These were **process regressions** — added features moved into the percentage denominator while the numerator stayed empty (no adoption-metric backfill in the same PR). They were NOT v7.9 kill criteria (false positives + rollbacks — both `not_fired`), so v7.9 promoted regardless. But the trend-scan noise was real, the operator paid attention cost to triage it, and the same pattern would recur for every future soak window absent a codified rule.

This PR codifies the **freeze-or-backfill** discipline:

1. **Freeze** — mark `state.json::soak_window_freeze: <version>` (e.g., `"v7.9"`); the weekly trend-scan + `make integrity-diff` skip the feature when computing percentage metrics.
2. **Backfill** — populate `cache_hits[]` + `cu_v2.{factors,total,tier_class}` + `timing.phases.<phase>.{started_at,ended_at}` + `timing.wall_time_seconds` in the same PR that introduces the feature's `state.json`. Numerator stays paired with denominator; percentage stays stable.

Documentation-only; no gate; no telemetry impact; **Phase-E-safe** by construction. The rule ships **advisory** at v7.9.1 with a built-in promotion clause: enforce as the `SOAK_WINDOW_FREEZE_OR_BACKFILL` write-time gate after 2 consecutive soak windows show >5 pp regression on any post-v6 percentage metric.

## What changed

Three doc edits, no code.

**`CLAUDE.md`** — new `## Soak-window discipline (v7.9.1+)` section between the F-LAUNCHD-DRIFT-EXTENSION wrap-up and Known Mechanical Limits. Contains: (a) the rule, (b) the 3-row regression table from the v7.9 baseline that triggered the rule, (c) two compliance paths (freeze or backfill) with schema-field-level specificity, (d) the advisory→enforced promotion criterion, (e) cross-references to the predecessor case study + this case study.

**`docs/product/backlog.md`** — new `### Framework hygiene` subsection inside `## Backlog (Unscheduled — from gap reviews and PRD)`. Two entries:
- The freeze-or-backfill rule itself (this case study)
- The W30 durable-fix candidate (parser patch for `_parse_case_study_frontmatter()` integer fallback — surfaced same session via PR #624)

**`docs/case-studies/f-phase-e-adoption-freeze-discipline-case-study.md`** — this file.

## Why this design

The candidate originally proposed a third compliance path: "freeze BOTH numerator AND denominator if the feature isn't measurable yet." That would have required a schema change. Dropped at scoping for two reasons:

1. **Denominator-only freeze** (this design's `soak_window_freeze` flag) is sufficient — the metric is a ratio of "features with adoption data populated" / "features in the post-v6 cohort." Excluding a feature from the cohort while it's soaking is the same arithmetic outcome as freezing both sides, and requires only an additive schema field instead of restructuring the trend-scan logic.
2. **Backfill** (the second path) is already supported — every existing percentage metric reads from existing schema fields. No new infrastructure needed.

The rule's advisory→enforced promotion clause is built into the spec specifically because the rule's effectiveness can only be measured at the NEXT soak window. v7.9.1 ships the documentation; v7.10 Phase E will provide the first observational data point.

## Verification

Documentation-only; no test suite. Verification is structural:

```bash
grep -c "^## Soak-window discipline" CLAUDE.md
# Expected: 1

grep -c "^### Framework hygiene" docs/product/backlog.md
# Expected: 1
```

Both grep counts are 1 at merge time.

## Open follow-ups

- **v7.10 Phase E observational** — first opportunity to measure rule effectiveness. Expected behavior: features added during the v7.10 soak EITHER carry `soak_window_freeze: "v7.10"` OR have populated adoption fields in the same PR. Trend-scan emits 0 dilution-driven regressions.
- **Promotion gate `SOAK_WINDOW_FREEZE_OR_BACKFILL`** — if v7.10 + v7.11 (or whichever consecutive pair) both show >5 pp regression on any post-v6 percentage metric, this rule promotes to a write-time gate that rejects new features without one of the two compliance markers. Filed as an Enhancement in the Framework hygiene backlog subsection.
- **W30 durable fix** — parser patch for `_parse_case_study_frontmatter()` integer fallback. Surfaced THIS session (PR #624 — 4 commit retries to satisfy Q6 PR-list parity). Filed in the same backlog subsection.

## References

- **Spec:** [`.claude/shared/v7-9-1-candidates.md`](../.claude/shared/v7-9-1-candidates.md) F-PHASE-E-ADOPTION-FREEZE-DISCIPLINE
- **Predecessor case study:** [`framework-v7-9-promotion-case-study.md`](framework-v7-9-promotion-case-study.md) §99.4 lesson 2
- **2026-05-14 measurement anchor:** `~/Documents/FitTracker2-backups/2026-05-14-analytics-observability-platform-integrity-baseline-2026-05-14/`
- **W30 sibling pattern:** [`observed-patterns.md` W30](../../.claude/integrity/observed-patterns.md) — Q6 parity gate's YAML parser quirk (same parser file, different surface)

---

**Shipped via PR #625** (`feature/f-phase-e-adoption-freeze-discipline` → `main`).
