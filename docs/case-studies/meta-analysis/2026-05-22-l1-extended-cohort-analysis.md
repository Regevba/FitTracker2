# L1 — Extended Cohort Analysis (n=83)

> **Date:** 2026-05-22
> **Phase:** 1 of 3 (meta-analysis refresh)
> **Anchor:** [`meta-analysis-2026-04-21.md`](meta-analysis-2026-04-21.md) (n=41)
> **Spec:** [`docs/superpowers/specs/2026-05-22-meta-analysis-refresh-phase-1-design.md`](../../superpowers/specs/2026-05-22-meta-analysis-refresh-phase-1-design.md) §5.2
> **Extraction bundle SHA256:** `6d106b47f3dd5bf48954f36499bd9634a17f615a04cdd820cc16d7f21ec03599`
> **Convention:** Every quantitative claim T1/T2/T3 tagged per [`data-quality-tiers.md`](../data-quality-tiers.md).

## 1. Scope

Corpus at extraction time (bundle SHA `6d106b47…`):

- 83 case studies in `docs/case-studies/*.md` (T1)
- 11 meta-analysis sub-docs in `docs/case-studies/meta-analysis/` (T1)
- 75 features in `.claude/features/*/` (T1)
- 25 published showcase MDX in fitme-story `content/04-case-studies/` (T2)

## 2. Extraction method

Reused [`scripts/audit/build_bundle.py`](../../../scripts/audit/build_bundle.py) with profile [`meta-analysis-2026-05-22`](../../../scripts/audit/profiles/meta-analysis-2026-05-22.json) (committed in Task 1, `d7920c1`). The profile inherits from `base.json` and adds state.json + integrity ledgers + gate-coverage logs. Bundle SHA256 is deterministic — rerunning produces an identical hash unless the corpus changes.

Per-cohort counts in §3-§5 below are extracted by:
1. `ls -1 .claude/features/` → enumerate 75 features
2. `python3 -c "import json; ..."` over each `state.json` to extract typed fields
3. Tally by category (work_type, dispatch_pattern, etc.)

Methodology mirrors the 2026-04-21 anchor §2 to preserve year-over-year comparability.

## 3. Corpus aggregates

| Metric | Value | Tier |
|---|---:|---|
| Total case studies | 83 | T1 |
| Total bytes (sum) | 1,311,368 | T1 |
| Median lines per case study | 212 | T1 |
| Median age (days since `date_written`) | not measured — corpus spans 2026-02 to 2026-05 | T3 |

## 4. Work-type distribution

Per `state.json::work_type` across 75 features, normalized to lowercase to resolve `feature` / `Feature` capitalization inconsistency present in 10 of 49 feature entries (T1):

| work_type | n | % |
|---|---:|---:|
| feature | 49 | 65.3% |
| enhancement | 15 | 20.0% |
| chore | 9 | 12.0% |
| framework | 2 | 2.7% |
| **Total** | **75** | **100.0%** |

## 5. Dispatch-pattern distribution

Per `state.json::dispatch_pattern` across 75 features (T1). 88.0% of features have no `dispatch_pattern` set — the field was introduced post-v6.0 and has not been backfilled for pre-v6 features:

| dispatch_pattern | n | % |
|---|---:|---:|
| (missing) | 66 | 88.0% |
| serial | 3 | 4.0% |
| subagent-driven serial (20 tasks) | 1 | 1.3% |
| subagent-driven-tdd-sequential-phased | 1 | 1.3% |
| serial_per_sub_task | 1 | 1.3% |
| operator-driven (decision) + agent-driven (per-gate flip implementation) | 1 | 1.3% |
| subagent-driven (Block A) + operator-driven (Block B/C) | 1 | 1.3% |
| TODO: defined in Phase 1 Research → Phase 2 PRD | 1 | 1.3% |
| **Total** | **75** | **100.0%** |
