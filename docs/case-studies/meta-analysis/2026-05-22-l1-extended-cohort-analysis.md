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

## 14. Summary of findings (pure restatement of data above)

§3: n=83 case studies, 1,311,368 total bytes, median lines 212, median age not measured (corpus spans 2026-02 to 2026-05, T3). §4: work_type distribution top-3 is feature 49 (65.3%), enhancement 15 (20.0%), chore 9 (12.0%). §5: dispatch_pattern is `(missing)` on 66 of 75 features (88.0%); the remaining 9 are split across `serial` (3), `subagent-driven serial (20 tasks)` (1), and 5 other single-entry variants. §6: phase-documentation coverage ranges from 0.0% (`metrics`, `tasks_phase`, `pre_merge_review`) to 72.7% (`test`); the `metrics` phase is present in 34 features with 0 notes recorded. §7: the anchor §7 audit-v2-gN stub anomaly is resolved (0 stubs remain); no new structural anomalies detected across all 75 state.json files. §8: success_metrics non-empty 10.7% (8/75), kill_criteria non-empty 10.7% (8/75), kill_criteria_resolution 12.5% of features with kill_criteria set (1/8), cache_hits[] non-empty (post-v6) 48.7% (19/39), cu_v2 schema-valid 14.7% (11/75). §9: PR citation count FT2 289, fitme-story 94; resolution 100% for both (T2, declared via gate enforcement). §10: case_study link present 72.0% (54/75), of those 96.3% resolve or carry valid exemption (52/54); current_phase 100% (75/75). §11: framework_version distribution top-3 is v7.8-v7.9 25 (33.3%), v5.x 20 (26.7%), pre-v5.0 16 (21.3%); 0 features carry missing or parse_error values. §12: 0 features have a `failed` phase status (0.0%), 0 features have `pivot_reason` set (0.0%) — this is a schema coverage gap (fields unused), not a product health claim. §13: case study link + state.json reconciliation aligns with §10 (72.0% / 96.3%); chronological_order_violations not measured (T3).

This summary is a restatement of measured data only. No editorializing.

## 15. Comparison against prior meta-analyses

| Metric | 2026-04-16 (Nemotron) | 2026-04-16 (what-if-v6) | 2026-04-21 (anchor) | 2026-05-22 (this doc) |
|---|---|---|---|---|
| n (case studies) | ~30 (T2) | 24 (T2) | 41 (T1) | 83 (T1) |
| Cohort dimensions analyzed | 0 (validation focus) | 1 (work-type via CU recalc) | 5 (work-type, dispatch, version, framework_version, showcase mapping) | 7 (anchor 5 + framework-version cohort §17 + cross-repo split §18) |
| External validation? | partial (Nvidia) | no | no (Gemini followed 5 days later 2026-04-21) | pending (External Audit #2 in 21 days, 2026-06-12) |
| Key new finding | normalization model validation | CU v2 recalc + ROI 2.2x | structural anomaly: audit-v2-gN stub group | per §3-§13, dispatch_pattern field has 88.0% missing data coverage; v7.8-v7.9 is now the plurality framework_version bucket at 33.3%, overtaking v5.x at 26.7% |

## 16. Limitations

Per anchor §16, with status updates and additional Phase 1-specific limitations:

Anchor §16 limitations status:
- **L1 (sample size n=41):** CLOSED at n=83 (current corpus).
- **L2 (no framework-version cohort comparison):** CLOSED — see NEW §17 (Task 10).
- **L3 (no cross-repo split):** CLOSED — see NEW §18 (Task 11).
- **L4 (Gemini audit then-pending):** CLOSED — Gemini audit (2026-04-21) is the v7.0→v7.5 inflection now folded into §17.
- **L5 (self-referential bias — same author):** OPEN. Closure path: External Audit #2 (2026-06-12) provides impartial cross-check; Phase 3 reconciliation finalizes this.
- **L6 (no statistical significance testing):** OPEN. Per-cohort n typically <15, insufficient for meaningful p-values. Will close at corpus n≈200+.
- **L7 (no reader-comprehension validation):** OPEN. No operator has read every case study and rated quality. Out of Phase 1 scope; could be added in Phase 2.

New L1-specific limitations:
- **L8: §17 framework-version cohort boundaries are author-chosen.** Five buckets used (pre-v5.0 / v5.x / v6.x / v7.0-v7.4 / v7.5-v7.7 / v7.8-v7.9). Different groupings would yield different rates.
- **L9: §18 cross-repo split treats fitme-story as a single repo.** But fitme-story has multiple sub-areas (control-room, case-studies, framework pages, public site) that could have different hygiene levels. Aggregate cross-repo claims may mask sub-area variance.
- **L10: §11 framework_version count assumes the field is correctly populated.** That field was bulk-backfilled in PRs #185+#186 (v7.8 era). Pre-backfill values are recovered from PR commit dates + state.json `created_at`, not original ground truth.
- **L11: §5 dispatch_pattern field has 88.0% missing coverage.** Findings about dispatch patterns are based on the 12.0% of features where the field is set — non-representative sample.
- **L12: §12 failure/pivot density reports 0 because the `failed` status and `pivot_reason` fields are not in active use across the corpus.** Real failures + pivots are reported in case-study prose; the field-presence count is a schema-adoption signal, not a project-health signal.

## 17. NEW — Framework-version cohort analysis

Per spec §5.2, this dimension partitions the 75-feature corpus into 5 non-overlapping ship-version buckets and measures adoption rates of 5 framework fields per cohort. Surfaces whether each new field actually got adopted by the cohort that shipped after it became mandatory. **Closes anchor §16 L2.**

### 17.1 Cohort definitions and population

| Cohort | Ship-version range | n |
|---|---|---:|
| pre-v6 | v1.x–v5.x (includes `pre-v5.0` tag) | 36 |
| v6.0-v6.x | v6.0, v6.1, … | 4 |
| v7.0-v7.4 | v7.0–v7.4 | 2 |
| v7.5-v7.7 | v7.5, v7.6, v7.7 | 8 |
| v7.8-v7.9 | v7.8, v7.8.1–v7.8.6, v7.9 | 25 |
| (unbucketable) | missing or parse_error | 0 |
| **Total** | | **75** |

(T1 — extracted from `framework_version` field across all 75 `state.json` files at extraction time)

### 17.2 Adoption rates per cohort

Each field becomes mandatory at a specific framework version. Cohorts that shipped BEFORE the mandatory version are shown as `n/a` (the field did not exist as a requirement when they shipped).

| Field | mandatory from | pre-v6 (n=36) | v6.0-v6.x (n=4) | v7.0-v7.4 (n=2) | v7.5-v7.7 (n=8) | v7.8-v7.9 (n=25) |
|---|---|---:|---:|---:|---:|---:|
| `cache_hits[]` non-empty | v6.0 | n/a | 25.0% (1/4) | 0.0% (0/2) | 62.5% (5/8) | 52.0% (13/25) |
| `kill_criteria_resolution` when `kill_criteria` set | v7.8.1 | n/a | n/a | n/a | n/a | 16.7% (1/6) |
| `state_owner` present | v7.8.3 | n/a | n/a | n/a | n/a | 100.0% (25/25) |
| `cu_v2` schema-valid | v7.7 | n/a | n/a | n/a | 50.0% (4/8) | 16.0% (4/25) |
| Tier-tag in case study body | 2026-04-21 | 71.4% (15/21) | 25.0% (1/4) | 100.0% (2/2) | 100.0% (7/7) | 94.4% (17/18) |

Notes:
- `state_owner` was backfilled to all 75 features via a single mechanical commit at v7.8.3 ship (PRs #185+#186); the 100.0% rate on the v7.8-v7.9 cohort reflects that backfill, not organic adoption at commit time. Pre-v6 through v7.5-v7.7 cohorts show n/a because the field was not a requirement when they shipped.
- Tier-tag denominator is the count of features in each cohort that have a `case_study` field pointing at an existing `.md` file (case-study-present subset), not the full cohort n. The pre-v6 cohort has 21 case-study files present out of 36 features.
- `cu_v2` denominator is the full cohort n. The `complexity.cu_version == 2` check requires the nested `complexity` object to exist and carry `cu_version: 2`.

(T1 — all rates measured from `state.json` field scans + case-study file content scans at extraction time)

### 17.3 Observations (pure restatement of data)

**`cache_hits[]` (mandatory from v6.0):** The v6.0-v6.x cohort shows 25.0% (1/4) adoption; the v7.0-v7.4 cohort shows 0.0% (0/2); the v7.5-v7.7 cohort shows 62.5% (5/8); the v7.8-v7.9 cohort shows 52.0% (13/25). The largest non-adoption gap in a mandatory cohort is the v7.0-v7.4 cohort at 0.0% (0/2 features). No cohort that is post-v6 reaches 100%.

**`kill_criteria_resolution` (mandatory from v7.8.1):** The only measured cohort is v7.8-v7.9, where 16.7% (1/6) of features that have `kill_criteria` set also have `kill_criteria_resolution` populated. The 5 remaining features in that cohort have `kill_criteria` set but no `kill_criteria_resolution`.

**`state_owner` (mandatory from v7.8.3):** The v7.8-v7.9 cohort shows 100.0% (25/25). This rate reflects the bulk backfill applied to all features at v7.8.3 ship, not organic field adoption across individual commits.

**`cu_v2` schema (mandatory from v7.7):** The v7.5-v7.7 cohort shows 50.0% (4/8); the v7.8-v7.9 cohort shows 16.0% (4/25). The v7.8-v7.9 cohort has a lower rate than the v7.5-v7.7 cohort despite being the later cohort.

**Tier-tag in case study body (mandatory from 2026-04-21, cuts across all buckets):** Among features with a case-study file present, tier-tag presence rates are: pre-v6 71.4% (15/21), v6.0-v6.x 25.0% (1/4), v7.0-v7.4 100.0% (2/2), v7.5-v7.7 100.0% (7/7), v7.8-v7.9 94.4% (17/18). The v6.0-v6.x cohort has the lowest rate at 25.0% (1/4 case-study files contain a tier tag). The 6 pre-v6 case-study files without tier tags account for the 71.4% rate on that cohort.

## 18. NEW — Cross-repo split (FT2 vs fitme-story)

Per spec §5.2, partition the 75-feature corpus by `state.json::state_owner`. Compare doc-debt field-presence rates per repo. Quantifies the v7.8.2 documented-disposition decision empirically. **Closes anchor §16 L3.**

### 18.1 Cohort split

| state_owner | n | Note |
|---|---:|---|
| `ft2` (explicit) | 74 | Set by v7.8.3 bulk backfill (PR #185+#186) on all pre-existing features + every post-v7.8.3 feature; no features have `state_owner` absent |
| `ft2 (default — legacy)` | 0 | Zero: the bulk backfill populated `state_owner: "ft2"` on all 74 FT2 features; the legacy-default bucket is empty |
| `fitme-story` | 1 | `3d-interactive-framework-flow-diagram` — first cross-repo feature; `current_phase: prd` at extraction time |
| **Total** | **75** | |

### 18.2 Doc-debt field-presence per repo

| Field | ft2 (n=74) | fitme-story (n=1) | Δ (ft2 − fitme-story, percentage points) |
|---|---:|---:|---:|
| `success_metrics` non-empty | 10.8% (8/74) | 0.0% (0/1) | +10.8 |
| `kill_criteria` non-empty | 10.8% (8/74) | 0.0% (0/1) | +10.8 |
| `kill_criteria_resolution` when KC set | 12.5% (1/8) | n/a (0 features have KC set) | — |
| `cache_hits[]` (post-v6) | 50.0% (19/38) | n/a (Mechanism A is FT2-only per v7.8.2 spec) | — |
| `cu_v2` schema-valid | 14.9% (11/74) | 0.0% (0/1) | +14.9 |
| Tier-tags in case study body | 80.8% (42/52) | n/a (0 case-study files present for fitme-story features) | — |

(T1 — measured at extraction time from state.json + case-study scans)

### 18.3 Per-rule asymmetry call-outs

For fields in §18.2 where `Δ` is a numeric value (not `—`): `success_metrics` gap is +10.8 pp, `kill_criteria` gap is +10.8 pp, and `cu_v2` gap is +14.9 pp. No comparable field exceeds the 20 pp threshold. No significant asymmetry on any comparable field.

For fields where the fitme-story denominator is zero or the measurement is FT2-only (`kill_criteria_resolution`, `cache_hits[]`, `tier-tags`): these fields cannot produce a valid cross-repo gap at n=1 without a case study, so no call-out is warranted.

### 18.4 v7.8.2 disposition validation

The v7.8.2 cross-repo gate asymmetry spec (2026-05-08) documented Mechanism A's FT2-only scope as a deliberate exemption. The §18.2 data shows whether the asymmetry caused measurable harm in OTHER fields — fields expected to be populated in both repos.

Observed pattern: `success_metrics`, `kill_criteria`, and `cu_v2` show gaps of +10.8 pp, +10.8 pp, and +14.9 pp respectively. All three gaps are below 20 pp. `cache_hits[]` and `tier-tags` are not comparable (FT2-only scope or zero case-study denominator). The fitme-story cohort consists of a single feature at `prd` phase with no case study present — low field-presence rates on that feature reflect its early lifecycle stage, not a systematic adoption deficit attributable to the Mechanism A exemption.

v7.8.2 disposition expected: Mechanism A telemetry asymmetry is acceptable; other field-adoption rates should be comparable across repos. Phase 1 measurement: PASS on all three comparable fields (`success_metrics` +10.8 pp: PASS; `kill_criteria` +10.8 pp: PASS; `cu_v2` +14.9 pp: PASS — all below 20 pp threshold). The single-feature fitme-story cohort limits the statistical weight of this conclusion; re-evaluation is scheduled annually per v7.8.2 spec §5 or when the fitme-story cohort reaches ≥5 features.
