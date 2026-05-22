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

## 6. Phase-documentation coverage

Per `state.json::phases.<phase>.note` presence across the 75-feature corpus (T1):

| Phase | features w/ note | features w/ phase present | coverage |
|---|---:|---:|---:|
| `implementation` | 16 | 68 | 23.5% |
| `merge` | 9 | 68 | 13.2% |
| `review` | 16 | 67 | 23.9% |
| `research` | 14 | 66 | 21.2% |
| `prd` | 12 | 66 | 18.2% |
| `tasks` | 13 | 66 | 19.7% |
| `ux_or_integration` | 9 | 64 | 14.1% |
| `documentation` | 11 | 63 | 17.5% |
| `testing` | 19 | 56 | 33.9% |
| `metrics` | 0 | 34 | 0.0% |
| `test` | 8 | 11 | 72.7% |
| `complete` | 5 | 7 | 71.4% |
| `implement` | 1 | 4 | 25.0% |
| `docs` | 1 | 4 | 25.0% |
| `learn` | 1 | 3 | 33.3% |
| `tasks_phase` | 0 | 2 | 0.0% |
| `pre_merge_review` | 0 | 1 | 0.0% |

## 7. Structural anomalies

Anchor §7 audit-v2-gN stub group: resolved (0 features remain). No `audit-v2-gN` stubs exist in `.claude/features/`.

No new structural anomalies detected. All 75 state.json files are ≥500 bytes; no thin-state stubs found.

## 8. Metrics sections coverage

Per top-level state.json fields across 75 features (T1):

| Field | features w/ value | denominator | coverage |
|---|---:|---:|---:|
| `success_metrics` non-empty | 8 | 75 | 10.7% |
| `kill_criteria` non-empty | 8 | 75 | 10.7% |
| `kill_criteria_resolution` (when `kill_criteria` set) | 1 | 8 | 12.5% |
| `cache_hits[]` non-empty (post-v6 only) | 19 | 39 | 48.7% |
| `cu_v2` schema-valid | 11 | 75 | 14.7% |

## 9. PR citation verification

| Repo | Total PR citations in case studies | Resolution rate (T2, declared) |
|---|---:|---|
| FT2 | 289 | 100% (gated by `BROKEN_PR_CITATION` since v7.5) |
| fitme-story | 94 | 100% (cross-repo `BROKEN_PR_CITATION` since v7.8.3 Phase 1) |

Note: T2 (declared) tier — actual verification happens at commit time by the pre-commit gate. Direct re-verification at meta-analysis time would require live `gh pr list` queries (deferred to Phase 3 cross-anchor reconciliation).

## 10. state.json reconciliation

Per state.json↔case-study link integrity (T1):

| Check | passing | denominator | coverage |
|---|---:|---:|---:|
| `case_study` link present (path or exemption marker) | 54 | 75 | 72.0% |
| `case_study` link resolves OR is valid exemption | 52 | 54 | 96.3% |
| `current_phase` field set | 75 | 75 | 100.0% |

## 11. Framework-version citation distribution

Per `state.json::framework_version` across the 75-feature corpus (T1). The `pre-v5.0` bucket covers 16 features whose `framework_version` field is the literal string `"pre-v5.0"` — these predate the canonical `vX.Y` versioning introduced at v5.0:

| Bucket | n | % |
|---|---:|---:|
| pre-v5.0 | 16 | 21.3% |
| v5.x | 20 | 26.7% |
| v6.x | 4 | 5.3% |
| v7.0-v7.4 | 2 | 2.7% |
| v7.5-v7.7 | 8 | 10.7% |
| v7.8-v7.9 | 25 | 33.3% |
| **Total** | **75** | **100.0%** |

No features carry `(missing)` or `(parse_error)` framework_version values — the v7.8 `framework_version` backfill (PRs #185+#186, 2026-05-03) populated all 46 features that existed at that time, and all features created since have carried the canonical `vX.Y` form. The `pre-v5.0` string is intentional and machine-readable. v7.8-v7.9 now represents the plurality bucket at 33.3%, overtaking v5.x (26.7%), reflecting the accelerating framework build rate in 2026-Q2.

## 12. Failure / pivot density

Features with at least one phase marked `failed` (per `state.json::phases.<phase>.status == "failed"`) or with a `pivot_reason` set (T1):

| Phase | failed | pivoted |
|---|---:|---:|
| (no phases with failed status or pivot_reason found) | 0 | 0 |

Summary: 0 features have ≥1 failed phase (0.0%). 0 features have ≥1 pivot_reason (0.0%). (T1)

The zero counts are a data-quality observation, not a product health claim. The `failed` status and `pivot_reason` fields were introduced in the v7.x schema but have not been retroactively populated for pre-v7.5 features that did encounter pivots (the HADF Phase 2 mid-flight isolation event of 2026-04-30, documented in the case study, would qualify as a pivot but is recorded in the case study narrative rather than as a structured field). This is a known schema coverage gap, not evidence that no feature ever pivoted.

## 13. Showcase ↔ main-repo mapping (Corpus B vs A)

Per spec §5.2 mirror of anchor §13. Comparison of case-study presence across the two corpora (T1 except where noted):

| Status | count |
|---|---:|
| Case study EXISTS in `docs/case-studies/` + state.json `case_study` field path-resolves | 52 |
| State.json declares `case_study_type` exemption (4 valid values per CLAUDE.md) | 13 |
| Neither path nor exemption (data debt) | 9 |
| Published showcase MDX in fitme-story `content/04-case-studies/` | 25 (T1, per L0 §1) |
| chronological_order_violations | not checked (T3 — requires manual review of timeline_position.order vs framework_version per CLAUDE.md publication rule) |

One additional feature (`hadf-phase2bis-replication`) has a `case_study` path declared in state.json but the referenced file does not exist on disk — the case study is in-flight. This accounts for the `cs_path_in_state = 53` vs `cs_exists = 52` delta.

The 9 data-debt features (neither path nor valid exemption) represent 12.0% of the corpus. These are candidates for the next doc-debt sweep. The 52 path-resolving features (69.3%) plus 13 exempt (17.3%) together account for 65/75 (86.7%) of the corpus with a valid closure disposition.
