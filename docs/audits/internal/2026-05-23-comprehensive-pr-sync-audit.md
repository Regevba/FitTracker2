---
date: 2026-05-23
type: internal-audit
scope: full project (FT2 PRs #1-#456 + fitme-story PRs #1-#140)
status: complete
auditors: 5 parallel research agents (Explore + general-purpose)
synthesizer: Opus 4.7 (1M context) main session
phase: v7.9 Phase E Day 3 of 14 (2026-05-21 → 2026-06-04)
---

# Comprehensive PR ↔ Docs Sync Audit — 2026-05-23

## 1. Executive summary

**Scope:** All merged PRs across both repos (FT2 #1-#456; fitme-story #1-#140) cross-referenced against `docs/product/backlog.md`, `.claude/features/*/state.json`, `docs/master-plan/*.md`, `docs/superpowers/specs/*.md`, `docs/superpowers/plans/*.md`, `docs/case-studies/*.md`, and fitme-story `content/04-case-studies/*.mdx`.

**Method:** 5 parallel agents — 3 PR windows on FT2 + all of fitme-story + master-plan inventory + backlog-state-casestudy reconciliation.

**Headline:** 60+ drifts surfaced, none blocking. Most are bidirectional-parity gaps (state.json missing PR refs that backlog/case-studies have) or schema-key drifts (`case_study_link` vs canonical `case_study`). The project's discipline tightened dramatically post-v7.5 (2026-04-24); pre-v7.5 work is mostly grandfathered.

**Drift breakdown:**

| Category | Count | Severity |
|---|---|---|
| D-AUDIT (PR ↔ doc mapping) | 18 | mixed; ~6 high-impact |
| D-PLAN (master/sub-plan staleness) | 10 | mostly informational |
| D-RECON (state.json ↔ case-study schema) | 13 | mostly cosmetic / forward-only |
| Cross-repo issues | 6 | 2 actionable |
| Status disagreements (state vs backlog) | 6 | 0 blocking; 4 calendar-gated |
| Orphan case studies | ~22 | low priority; pre-PM-workflow archive |
| **Total** | **~75 items** | **~12 worth fixing today** |

## 2. Window mapping — FT2 PRs #1-#200 (Mar 13 → ~May 4 2026)

**Total merged:** 142 PRs. **Backlog-linked:** ~58. **Feature-linked (state.json):** ~38.

[See Appendix A for full mapping table.]

### D-AUDIT drifts in window 1

- **D-AUDIT-1** — PRs #1-#7 + #20 (pre-PM-workflow, Mar 13 → Apr 2): no backlog row, no feature dir, no doc anchor. Recommend a single retroactive backlog row "Pre-PM-workflow seed PRs #1-#7 + #20".
- **D-AUDIT-2** — PRs #10/#12/#13/#17: backlog cites but `.claude/features/{authentication,ai-cohort-intelligence,data-sync,design-system-v2}/state.json` lacks `pr_number`/`related_prs` reverse-links (bidirectional Q6 spirit not honored on pre-v7.8.1 features).
- **D-AUDIT-3** — PRs #75/#77/#80: state.json files have explicit `pr_number: null` despite backlog rows 36/38/54 citing them. 6-week stale.
- **D-AUDIT-4** — PR #83 (ORCHID Layer A): no backlog row, no `.claude/features/orchid*/` dir.
- **D-AUDIT-5** — PRs #134-#137 (Apr 20 housekeeping batch): no backlog rows. Should group into a single retroactive row.
- **D-AUDIT-6** — PR #141 (v7.6 fixes): `data-integrity-framework-v7-6/state.json` lacks PR ref.
- **D-AUDIT-7** — PR #145 (v7.7 dashboard unbreak hotfix): no backlog row, no state.json link.
- **D-AUDIT-8** — PRs #170/#171/#172 (HADF + v7.8 bridge spec): no backlog rows; `hadf-phase2` feature dir doesn't exist.
- **D-AUDIT-9** — PRs #179/#180/#182/#183/#184 (ORCHID v1.5 5-PR arc): no `.claude/features/orchid-v1-5/` despite multi-day arc.
- **D-AUDIT-10** — PR #197 (v7.9 measurement-window snapshot tool): no anchor; should link to `framework-v7-9-promotion` predecessor_chain.
- **D-AUDIT-11** — PR #198 (smart-reminders backend): state.json has unsubstituted `"PR-TBD"` placeholder.

## 3. Window mapping — FT2 PRs #200-#400 (May 4 → May 18 2026)

**Total merged:** 184 PRs. **Feature-linked:** 79 (43%). **Backlog-referenced:** 25 direct citations. **Plan-referenced:** 41 PRs across 20 plan/spec docs.

[See Appendix B for full mapping table.]

### D-AUDIT drifts in window 2

- **D-AUDIT-12** — `framework-v7-7-validity-closure/state.json` missing PRs #201 + #364 in `related_prs`. State cites #144 only. Both are post-launch follow-ups.
- **D-AUDIT-13** — Cross-cutting doc-debt PRs #202, #203 lack state.json owner. Should chain to `framework-v7-7-validity-closure/related_prs`.
- **D-AUDIT-14** — PR #206 (`framework_meta_retroactive` exempt type) has no feature container. Should cite in `framework-v7-8-branch-isolation/related_prs`.
- **D-AUDIT-15** — `ucc-passkey-auth/state.json` cites ONLY PR #248; missing #249, #250, #251, #262, #380, #387. **Largest single feature-PR gap in window.**
- **D-AUDIT-16** — `3d-interactive-framework-flow-diagram/state.json` cites #324 but not #329 (the PRD draft merge).
- **D-AUDIT-17** — `analytics-observability/state.json` cites ZERO FT2 PRs despite 13 merged in window (#332, #334-#339, #342, #345, #349, #351, #354, #358, #362, #376, #388). **Structural drift** — no provenance trail at all.
- **D-AUDIT-18** — `framework-v7-9-promotion/state.json` lacks pre-decision PRs #326, #392, #393 (the calibration-window justification PRs).

## 4. Window mapping — FT2 PRs #400-#456 + fitme-story PRs #1-#140

**FT2 window 3:** 51 PRs merged 2026-05-18 → 05-23. Dominated by v7.9 promotion lifecycle (#400-#404 pre-decision, #417 the flip, #419 close-out), Phase E dev-env hardening (R1-R23 #423-#434), UCC passkey hardening (#410-#413, #442, #453), Dependabot bumps, and post-v7.9 doc/cadence sweeps.

**fitme-story:** 138 merged PRs spanning 2026-04-21 → 2026-05-23. 7 major arcs from foundation (#1-#19) through UCC port (#20-#41), public-site polish (#42-#67), cross-repo bridge (#72-#92), DS P2 cleanup (#81-#99), v7.8.4-v7.8.6 doc-sync (#100-#119), UCC passkey hardening (#120-#140).

[See Appendix C for full mapping table.]

### Drifts in window 3 + fitme-story

- **D-AUDIT-19** — `framework-v7-9-promotion/state.json` has `case_study_showcase: null` despite slot 34 MDX (`34-framework-v7-9-promotion.mdx`) being live. Will trigger `STATE_NO_CASE_STUDY_LINK` advisory next cycle.
- **D-AUDIT-20** — `ucc-sign-in-figma-mapping` `current_phase=implementation` despite fitme-story PR #125 closing T2-T8 + FT2 PR #415 reconcile saying "8/11 actually shipped". Remaining 3 tasks need itemization + phase advance.
- **D-AUDIT-21** — `ucc-passkey-auth-audit-log-redis-fix` state.json `current_phase=implementation` despite production fix shipped at fitme-story PR #122 (2026-05-17). Should advance to `test` or `complete`.
- **D-AUDIT-22** — MEMORY.md "Next-inline" lists items already shipped: C9 + C10 via fitme-story PR #120 (2026-05-17), T13 via fitme-story PR #134 (2026-05-21). Stale.
- **D-AUDIT-23** — Slot 34 (v7.9 promotion showcase) `external_audit_status: pending` should flip to `corrected` after audit-1 corrections PR #448 post-publishes.

### Cross-repo issues

- **CR-1** — FT2 `ucc-sign-in-figma-mapping` ↔ fitme-story PR #125: itemize 3 remaining tasks + phase-advance.
- **CR-2** — FT2 `ucc-passkey-auth-audit-log-redis-fix` ↔ fitme-story PR #122: advance FT2 state.json to `test` with case_study link.
- **CR-3** — FT2 `framework-v7-9-promotion` ↔ slot 34: populate `case_study_showcase` field.
- **CR-4** — FT2 `ucc-passkey-auth-security-hardening` blocked on B12 calendar gate (2026-05-27); not drift.
- **CR-5** — MEMORY.md out-of-date on shipped Dependabot disposition (some merged, others held).
- **CR-6** — PR cite parity HEALTHY OVERALL — no `BROKEN_PR_CITATION` findings in the 189-PR audit set.

## 5. Master plans + sub-plans inventory

**Master plans (~13 files):** All current-status plans (`infra-master-plan-2026-05-12.md`, `master-plan-2026-04-15.md`, `analytics-master-plan-2026-05-13.md`, `data-integrity-and-rollback-2026-05-14.md`, `test-coverage-master-plan-2026-05-13.md`, `v8-0-docket-ranking-2026-05-13.md`, etc.) are healthy.

**Specs directory (31 files, 2026-03-14 → 2026-05-22):** All active.

**Plans directory (40+ files, 2026-03-30 → 2026-05-22):** All active except Apr-16 layer-phase plans (Phase 1-5 completed, archive).

### D-PLAN drifts

- **D-PLAN-1** — `backlog.md` missing ~30 entries since 2026-04-09 (6-week drift per both infra-master-plan §0 + post-v7-9-candidate-plan §0).
- **D-PLAN-2** — `post-v7-9-candidate-plan-2026-05-20.md` flags D1 drift (MEMORY.md says PR #411 OPEN; actually MERGED).
- **D-PLAN-3** — `fitme-story-discoverability-plan-2026-05-20.md` is orphan (no parent master plan references it).
- **D-PLAN-4** — `analytics-master-plan` Phase 3 ships 2026-05-21 → 06-04 parallel to v7.9 Phase E (documented; not blocking).
- **D-PLAN-5** — `test-coverage-master-plan` §2.1 claims F14+F15 shipped via PR pending (claim now resolved by PR #451 + #452 + #455).
- **D-PLAN-6** — `v8-0-docket-ranking-2026-05-13.md` decision gate fired 2026-05-21 but file still labeled RANKING not DECIDED.
- **D-PLAN-7** — `3d-framework-universe-prd-review-notes-2026-05-13.md` PARKED at R1 per operator decision; no further action.
- **D-PLAN-8** — `fitme-story-discoverability-plan-2026-05-20.md` Phase 4 measure window overlaps but doesn't conflict with Phase E end.
- **D-PLAN-9** — `master-plan-reconciled-2026-04-05.md` SUPERSEDED 38+ days ago; could move to archive/.
- **D-PLAN-10** — `master-backlog-roadmap.md` shipped section missing recent framework-version PRs (#244, #298-#304, #314, #328, #341, #363, #365).

### Open F/T/V candidates not on backlog

All F1-F20, T1-T11, V8-I1-V8-I7 are in master plans but `docs/product/backlog.md` has no "v8 candidates" section. Backlog is 6 weeks behind plan candidate inventory.

## 6. Backlog ↔ state.json ↔ case-studies reconciliation

**Stats:** 77 features in state.json · 100 backlog Done rows · 78 case studies on disk · 51 showcase MDX files.

### D-RECON drifts

- **D-RECON-1** — `3d-interactive-framework-flow-diagram` declares `case_study_link` (non-canonical key) pointing at missing file. OK while paused.
- **D-RECON-2** — `analytics-observability` declares `case_study_link` (non-canonical) pointing at missing file. OK while in implementation.
- **D-RECON-3** — `framework-v7-9-promotion` `case_study_showcase: null` despite slot 34 MDX existing. (Duplicate of D-AUDIT-19.)
- **D-RECON-4** — `framework-v7-9-promotion` `current_phase=docs` while backlog says SHIPPED; intentionally gated on B2 baseline 2026-05-28.
- **D-RECON-5** — `import-training-plan` `case_study_showcase` missing `fitme-story/content/` prefix.
- **D-RECON-6** — `ai-engine-v2`, `ai-recommendation-ui`, `readiness-score-v2`, `home-status-goal-card`, `metric-tile-deep-linking` use `parent_case_study_showcase: "04-case-studies/...md"` (wrong extension + missing prefix).
- **D-RECON-7** — `framework-story-site` uses non-canonical `current_phase: closed` (not in lifecycle enum); 3 case studies on disk unpointed.
- **D-RECON-8** — `unified-control-center` case_study path stored in `spec` field, not `case_study`.
- **D-RECON-9** — `auth-polish-v2` has `case_study_required: true` but NO `case_study` field. File exists; pointer missing.
- **D-RECON-10** — `ucc-passkey-auth` case_study at `phases.documentation.case_study_path`, not top-level `case_study`.
- **D-RECON-11** — `case-study-comparison-table` `case_study_path` is a sentence not path.
- **D-RECON-12** — `roadmap-stress-test-2026-05-07` case study exists; no showcase MDX in fitme-story.
- **D-RECON-13** — `fitme-story-design-system-p2-cleanup` no `case_study_showcase` field (subsumed under slot 30/32).

### Orphans

**O-CS-1 — 22 case study files with no state.json `case_study` pointer** (mostly pre-PM-workflow meta/lesson studies: `audit-remediation-*`, `audit-v2-g{1..6}-*`, `eval-layer-v4.4`, `original-readme-redesign`, `pm-workflow-evolution-v1-to-v4`, `m-3-design-system-completion`, `m-4-xcuitest-infrastructure`, `orchid-ai-accelerator`, `orchid-v1-5-additive-units`, `hadf-phase2-cloud-fingerprinting`, `v5.1-parallel-stress-test`, `framework-v7-8-pr1-advisory-calibration-2026-05-09`).

**O-CS-2 — ~12 backlog Done rows with no per-feature state.json** (mostly pre-PM bundles, audit-remediation program, M-1..M-4 sprints).

**O-ST-1 — 6 state.json features with no backlog Done row** (`ucc-passkey-auth-audit-log-redis-fix`, `ucc-sign-in-figma-mapping`, `audit-1-corrections`, `meta-analysis-refresh-phase-1`, `framework-f14-f15-dispatch-test-coverage`, `framework-story-site` partial).

**O-MDX-1 — ~8 showcase MDX slots with no state.json pointer** (slots 02, 03, 05, 08, 14, 15, 16, 17, 18, 20 + sub-letter variants).

### Status disagreements

- **S-RECON-1** — `framework-v7-9-promotion` shipped per backlog but state.json says `docs`; intentional, gated on B2 2026-05-28.
- **S-RECON-2** — `fitme-story-public-enhancements` "24/24 done; ready for closure" per backlog; state.json `implementation`. Blocked by FEATURE_CLOSURE_COMPLETENESS gate. Flagged for next sweep.
- **S-RECON-3** — `app-store-assets` paused; consistent.
- **S-RECON-4** — `ucc-passkey-auth-security-hardening` documentation; consistent (B12 gate).
- **S-RECON-5** — `hadf-phase2bis-replication` tasks_phase; consistent.
- **S-RECON-6** — `framework-story-site` `current_phase: closed` (non-canonical phase enum). Should be `complete`.

## 7. Drift-close priority list

### 🔴 High-impact actionable (~12 drifts — recommended for today's drift-close PR)

| # | Drift | Action |
|---|---|---|
| 1 | D-AUDIT-17: `analytics-observability/state.json` cites 0 FT2 PRs despite 13 merged | Add `tasks[].pr_number` or top-level `related_prs` with all 13 PRs |
| 2 | D-AUDIT-15: `ucc-passkey-auth/state.json` cites only #248 (missing 6 follow-ups) | Add `related_prs: [248, 249, 250, 251, 262, 380, 387]` |
| 3 | D-AUDIT-18: `framework-v7-9-promotion` missing #326, #392, #393 pre-decision PRs | Add to `phases.research.related_prs` or `phases.pre_decision.pr_numbers` |
| 4 | D-RECON-3 / D-AUDIT-19: `framework-v7-9-promotion` `case_study_showcase: null` | Set to `fitme-story/content/04-case-studies/34-framework-v7-9-promotion.mdx` |
| 5 | D-RECON-9: `auth-polish-v2` missing top-level `case_study` field | Add `case_study: docs/case-studies/auth-polish-v2-case-study.md` |
| 6 | D-RECON-1 + D-RECON-2: `case_study_link` → `case_study` schema-key normalize on `3d-feature` + `analytics-observability` | Rename key |
| 7 | D-AUDIT-22: MEMORY.md "Next-inline" lists shipped items (C9/C10/T13) | Strike entries; move to recently-shipped |
| 8 | D-PLAN-9: `master-plan-reconciled-2026-04-05.md` SUPERSEDED still in main dir | Add prominent strike-through header (already self-declared, but ambiguous) |
| 9 | D-AUDIT-11: `smart-reminders-behavioral-learning` has unsubstituted `"PR-TBD"` | Replace with `PR #198` |
| 10 | D-AUDIT-12 + D-AUDIT-13: `framework-v7-7-validity-closure` missing #201, #364, #202, #203 | Add to `related_prs` |
| 11 | D-RECON-7 / S-RECON-6: `framework-story-site` non-canonical `current_phase: closed` | Change to `complete` + add 3 case studies to state.json |
| 12 | D-AUDIT-20: `ucc-sign-in-figma-mapping` 3 remaining tasks unitemized | Itemize + decide phase advance vs hold |

### 🟡 Medium-impact (~10 drifts — could fix today or defer)

- D-RECON-5 / D-RECON-6: path-prefix + `.md`/`.mdx` extension drift on 5 `case_study_showcase` fields
- D-AUDIT-21: `ucc-passkey-auth-audit-log-redis-fix` advance state.json to `test`
- D-AUDIT-23: slot 34 `external_audit_status: pending` → `corrected`
- D-RECON-8: `unified-control-center` `spec` → `case_study` field rename
- D-RECON-10: `ucc-passkey-auth` nested `case_study_path` → top-level
- D-RECON-11: `case-study-comparison-table` sentence path → real path
- D-RECON-12: roadmap-stress-test missing showcase MDX
- D-PLAN-3: orphan `fitme-story-discoverability-plan` → cross-ref in master plan
- D-PLAN-6: `v8-0-docket-ranking` RANKING → DECIDED status flip
- D-PLAN-10: `master-backlog-roadmap.md` shipped section missing recent framework PRs

### 🟢 Low-priority / informational (~50+ items)

- Pre-PM-workflow archive drifts (D-AUDIT-1, D-AUDIT-4 ORCHID, D-AUDIT-9 ORCHID v1.5)
- 22 orphan case study files (mostly pre-PM-workflow meta-studies — would require creating archive feature)
- 12 backlog Done rows without state.json (pre-PM bundles)
- 8 showcase MDX slots without state.json pointer (meta/lesson slots)
- D-PLAN-1: backlog backfill of ~30 missing entries (large chore; separate PR)
- D-PLAN-4 / D-PLAN-7 / D-PLAN-8: documented as intentional/parked

## 8. Recommendations + next steps

1. **Open a drift-close PR** today with the 12 high-impact fixes above (this PR's companion).
2. **Schedule a backlog-backfill mini-feature** for D-PLAN-1 (~30 missing entries since 2026-04-09) — too large to bundle here.
3. **At Phase E exit (~2026-06-04)**: revisit `framework-v7-9-promotion` closure (D-RECON-4 unblocks at B2 baseline 2026-05-28).
4. **Pre-PM-workflow archive cleanup** could be a separate retroactive feature (`pre-pm-workflow-archive`) that adopts the 22 orphan case studies + creates the missing feature dirs (ORCHID, HADF Phase 2, etc.).
5. **MEMORY.md hygiene** — strike shipped items; trim to under 24KB; per the C11 staleness check enforced today, the file is currently 28.1KB.

## 9. Appendices

### Appendix A — Full FT2 #1-#200 mapping table

[See Agent 1 output preserved at `tools/audit-2026-05-23/agent-1-output.txt` — 142-row table.]

### Appendix B — Full FT2 #200-#400 mapping table

[See Agent 2 output preserved at `tools/audit-2026-05-23/agent-2-output.txt` — 184-row table.]

### Appendix C — Full FT2 #400-#456 + fitme-story #1-#140 mapping tables

[See Agent 3 output preserved at `tools/audit-2026-05-23/agent-3-output.txt`.]

### Appendix D — Plans inventory (15 master plans + sub-plans)

[See Agent 4 output preserved at `tools/audit-2026-05-23/agent-4-output.txt`.]

### Appendix E — Backlog ↔ state.json ↔ case-studies full reconciliation

[See Agent 5 output preserved at `tools/audit-2026-05-23/agent-5-output.txt`.]

---

**Auditors session ID:** `b6b53bff-7145-4f09-ab18-6d14c06d3c56`
**Synthesis turn:** 2026-05-23T~12:00Z
**Total agent compute:** ~25 minutes (5 parallel)
**Total drifts surfaced:** ~75
**Drifts recommended for today's fix:** 12
