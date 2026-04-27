---
title: Framework v7.7 — Validity Closure
date_written: 2026-04-27
work_type: Feature
dispatch_pattern: serial
success_metrics:
  primary: "post-v6 fully-adopted ratio: baseline 2/9 = 22.2% → target ≥8/11 = 72.7%"
  secondary:
    - "cache_hits writer-path: 33% → 100% (gated)"
    - "cu_v2 schema validity: unchecked → 100% (gated)"
    - "state↔case-study linkage: 95.5% → 100% (gated)"
    - "doc-debt fields populated: 4-61% → 100% on case studies dated ≥ 2026-04-28 (gated)"
kill_criteria:
  - "Cache-hits writer-path proves un-instrumentable (>5 distinct call sites with no shared loader)"
  - "Tier-tag checker false-positive rate stays >25% after 2 weeks"
  - "PR-1 instrumentation introduces >100ms latency to skill loading"
  - "Pre-commit hook FP rate >10% on legitimate commits in week-1 dogfooding"
  - "Framework-health dashboard reveals contradictions in ledgers"
predecessor_case_studies:
  - "docs/case-studies/data-integrity-framework-v7.5-case-study.md"
  - "trust/audits/2026-04-21-gemini/remediation-plan-2026-04-23.md"
  - "docs/case-studies/meta-analysis-full-system-audit-v7.0-case-study.md"
spec_path: docs/superpowers/specs/2026-04-27-framework-v7-7-validity-closure-design.md
plan_path: docs/superpowers/plans/2026-04-27-framework-v7-7-validity-closure.md
status: live
---

# Framework v7.7 — Validity Closure

> **Live append-only journal.** Each PR merge and each cycle snapshot appends an entry. No retroactive edits. Final synthesis (Section 99) at v7.7 merge.

## Section 0 — Genesis

The 2026-04-21 Gemini independent audit drove v7.5 (Data Integrity Framework, shipped 2026-04-24). v7.6 (Mechanical Enforcement, shipped 2026-04-25) closed seven Class B → Class A gaps but explicitly documented five remaining "Known Mechanical Limits" in CLAUDE.md.

On 2026-04-27, a session-driven audit pulled live ledger state and surfaced the closable subset of those limits. User declared full-priority freeze on all 8 in-flight features (6 hard-paused, 2 continuing naturally) to land v7.7 — the validity-closure pass — as the next framework version.

v7.7 closes A1–A5 + B1–B2 + C1 from the gap inventory. D1 (real-provider auth playbook) and D2 (external replication) deferred to a post-v7.7 follow-on track surfaced as a human-action checklist at v7.7 merge.

**T1 origin tags applied throughout this case study** in line with the 2026-04-21 tier-tag convention. Numbers traced to ledgers carry T1; predicted post-merge values carry T2; observational/narrative claims carry T3.

## Section 1 — Pre-state Baseline (frozen 2026-04-27 14:00 UTC)

**Tier 1.1 measurement adoption (post-v6 features) [T1]:**

| Dimension | Overall | Post-v6 |
|---|---|---|
| `timing.total_wall_time_minutes` | 5/44 (11.4%) | 5/9 (55.6%) |
| Per-phase timing | 7/44 (15.9%) | 6/9 (66.7%) |
| `cache_hits[]` | 3/44 (6.8%) | 3/9 (33.3%) ⚠ #140 |
| `cu_v2` factors | 6/44 (13.6%) | 6/9 (66.7%) |

Fully adopted post-v6: **2/9** (data-integrity-framework-v7-6, meta-analysis-audit) [T1].

**Tier 3.2 documentation debt [T1]:** 7 open items; trend mode locked (0/3 cycle snapshots). State↔case-study linkage 42/44 (95.5%).

**5 unclosable gaps** carried forward from CLAUDE.md "Known Mechanical Limits" [T2]: cache_hits writer-path adoption (closes via M1), cu_v2 magnitude judgment, T1/T2/T3 correctness on novel claims, real-provider auth simulator runs (D1, deferred), external replication (D2, deferred).

## Section 2 — Live Journal (append-only)

<!-- Each entry follows the schema in spec §4.2.
     Append after every PR merge AND every cycle snapshot. Never edit prior entries. -->

### 2026-04-27 14:00 UTC — Genesis & spec approval
- **Trigger:** brainstorming + spec approved by user (commit `1057144`); plan committed (commit `360e9dd`)
- **What changed:** spec written; case study journal created (this file); plan written; 6 paused-feature memories saved; v7.7 priority memory + MEMORY.md index updated
- **Ledger delta:** none yet (M0 in progress)
- **Surprises / discoveries:** Pre-commit hooks didn't refuse the empty `cache_hits: []` array on auth-polish-v2 — confirms the v7.6 hook checks presence of the key, not non-empty content. This is the exact gap M1 closes [T3].
- **Tier tags applied:** Section 1 baseline numbers all T1 (instrumented from `make measurement-adoption` + `make documentation-debt` ledger output, frozen 2026-04-27). 5-unclosable-gaps assertion is T2 (predicted before M1/M3 measurement).

### 2026-04-27 14:42 UTC — M0 complete
- **Trigger:** T0a–T0g all closed; 5 v7.7 commits on `feature/framework-v7-7-validity-closure` (`f867525` T0a, `971a5e9` T0b, `c4e2c3a` T0c, `b7a98e1` T0d, `9ceed6c` T0e); 2 MCP propagations (T0f Linear, T0g Notion).
- **What changed:**
  - v7.7 feature directory created at `.claude/features/framework-v7-7-validity-closure/`
  - 6 features paused atomically with snapshot fields: app-store-assets, auth-polish-v2, import-training-plan, onboarding-v2-retroactive, push-notifications, stats-v2
  - UCC state.json annotated with `tasks_migrated_to` for T43–T54 → v7.7 M4
  - CLAUDE.md banner: "v7.5 → v7.6 → v7.7-IN-PROGRESS" + stub section
  - Master plan banner updated; RICE roadmap freeze note added
  - Linear: epic **FIT-49** + 8 sub-issues **FIT-50…FIT-57** (status `In Progress`, parent set, all assigned to Regev)
  - Notion: new v7.7 sub-page under "FitMe — Product Hub" (`34f0e7a0eace812e87b8e0fc9892e318`); v7.5+v7.6 page got forward-link footer; "Project Context & Status" page updated in 3 places (callout + In Progress + Framework sections)
- **Ledger delta [T1]:**
  - `features_total`: 44 → 45 (v7.7 itself)
  - `fully_adopted_post_v6`: 2 → 2 (unchanged; v7.7 NOT counted because `cache_hits: []` is empty — exactly the gap M1 closes)
  - `cache_hits post_v6`: 33.3% (3/9) — unchanged; counter is fractionally diluted (3/9 → 3/9 since v7.7 doesn't count toward numerator OR denominator post_v6 group rules unchanged)
  - All other dimensions unchanged
- **Surprises / discoveries:**
  - The `append-feature-log.py` script expects `{"events": []}` not `[]` — initial bootstrap with `[]` errored. Fixed by writing `{"events": []}` then re-running. **[T3 — narrative observation worth carrying into M1 design]**
  - The v7.6 pre-commit hooks accepted v7.7's state.json on initial creation despite empty `cache_hits[]` — confirms again that the v7.6 hook is presence-check only. This is the gap M1's `CACHE_HITS_EMPTY_POST_V6` hook closes.
  - Master-plan path inconsistency: CLAUDE.md still references the deprecated 2026-04-06 plan as "current", but the actual current plan is 2026-04-15. T32 (CLAUDE.md final v7.7 section) will fix this. **[T3]**
  - Linear's `labels` parameter expected label IDs not names — labels didn't apply on epic/sub-issue creation. Non-blocking; can backfill later if needed. **[T3]**
- **Tier tags applied:** ledger numbers T1; design observations T3; predicted M1 closure T2.

## Section 99 — Synthesis (written at v7.7 merge)

<!-- Populate at M5. See plan §M5 / T31. -->

## Section 100 — 90-day Retrospective (written +90 days post-merge)

<!-- Populate via /schedule agent at +90 days. See plan §M5 / T35.7. -->
