# L0 — Delta vs 2026-04-21 Anchor

> **Date:** 2026-05-22
> **Phase:** 1 of 3 (meta-analysis refresh)
> **Spec:** [`docs/superpowers/specs/2026-05-22-meta-analysis-refresh-phase-1-design.md`](../../superpowers/specs/2026-05-22-meta-analysis-refresh-phase-1-design.md)
> **Anchor:** [`meta-analysis-2026-04-21.md`](meta-analysis-2026-04-21.md)
> **Extraction bundle SHA256:** `6d106b47f3dd5bf48954f36499bd9634a17f615a04cdd820cc16d7f21ec03599`

## 1. Corpus growth

| Metric | 2026-04-21 anchor | 2026-05-22 (today) | Δ |
|---|---:|---:|---:|
| Case studies in `docs/case-studies/*.md` | 41 (T1) | 83 (T1) | +42 |
| Meta-analysis sub-docs in `docs/case-studies/meta-analysis/` | 4 (T1) | 11 (T1) | +7 |
| Features in `.claude/features/*/` | 24 (T1) | 75 (T1) | +51 |
| Published showcase MDX in `fitme-story/content/04-case-studies/` | 24 (T2) | 25 (T1) | +1 |

## 2. Framework version arc since anchor

| Version | Ship date | What shipped (one-liner) | PR |
|---|---|---|---|
| v7.5 | 2026-04-24 | 8 cooperating defenses post-Gemini audit | PR #139 |
| v7.6 | 2026-04-25 | Mechanical enforcement (4 Class B→A) + per-PR + weekly | PR #141 |
| v7.7 | 2026-04-27 | Validity closure (5 new gates + framework-health dashboard) | PR #144 |
| v7.8 (bridge) | 2026-05-04 | Mechanisms A-F (advisory) | PR #173/#185-189/#193-195 |
| v7.8.1 | 2026-05-07 | Branch isolation + feature closure (advisory) | PR #244 |
| v7.8.2 | 2026-05-08 | Cross-repo gate asymmetry documented disposition | PR #258 |
| v7.8.3 | 2026-05-11 | Cross-repo state sync impl Phase 0 (V2+V9 enforced) | PR #298 |
| v7.8.4 | 2026-05-12 | Calibration patch + PR cache freshness gate | PR #314 |
| v7.8.5 | 2026-05-13 | Observed Patterns Catalog + W9 branch drift alert | PR #328+#341 |
| v7.8.6 | 2026-05-15 | Cadence batch (preflight + integrity-diff + weekly Mech A) | PR #363+#365 |
| v7.9 | 2026-05-21 | 3 gates flipped advisory→enforced | PR #417 |

## 3. New gates inventory since anchor

| Gate category | 2026-04-21 | 2026-05-22 | New |
|---|---:|---:|---|
| Write-time pre-commit gates | 4 (T1) | 8 (T1) | BRANCH_ISOLATION_VIOLATION (Mode B+C), FEATURE_CLOSURE_COMPLETENESS, CACHE_HITS_EMPTY_POST_V6, CU_V2_INVALID, STATE_NO_CASE_STUDY_LINK, STATE_OWNER + LOCATION_MISMATCH |
| Cycle-time integrity check codes | 13 (T1) | 16 (T1) | BRANCH_ISOLATION_HISTORICAL, BRANCH_ISOLATION_LAUNCHD_DRIFT, FEATURE_CLOSURE_COMPLETENESS mirror |
| Mechanism A coverage telemetry | 0 (T1) | 1 (T1) | gate-coverage.jsonl emission across all gates |
| Mechanism E append-only merge driver | 0 (T1) | 2 (T1) | measurement-adoption-history.json, documentation-debt.json, gate-coverage.jsonl, .claude/logs/*.log.json |

Totals (per CLAUDE.md "Data Integrity Framework"): 18 → 37+ mechanical gates, 0 → 5 advisories.

## 4. Anchor §16 limitations — status

Per spec §4:

| # | Anchor limitation | Phase 1 response | Status |
|---|---|---|---|
| 1 | Sample size n=41 | n=83 (full corpus) | **CLOSED** |
| 2 | No framework-version cohort comparison | L1 NEW §17 | **CLOSED** |
| 3 | No cross-repo split FT2↔fitme-story | L1 NEW §18 | **CLOSED** |
| 4 | Gemini audit then-pending | Folded into L1 §17 as v7.0→v7.5 inflection | **CLOSED** |
| 5 | Self-referential bias (same author) | Anchor #2 (external auditor) is the closure | OPEN (Phase 3 reconciliation) |
| 6 | No statistical significance testing | n still too small per cohort | OPEN (will close at n=200+) |
| 7 | No reader-comprehension validation | Not in Phase 1 scope | OPEN (deferred) |
