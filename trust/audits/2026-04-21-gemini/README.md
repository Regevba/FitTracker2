# Trust Audit Bundle — Gemini — 2026-04-21

This directory is an access-friendly index for the 2026-04-21 Gemini
independent audit and the follow-up implementation work.

## Entry points

- Project audit entrypoint: [project_gemini_audit_2026_04_21.md](/Volumes/DevSSD/FitTracker2/project_gemini_audit_2026_04_21.md)
- Framework v7.1 entrypoint: [project_framework_v7_1_integrity_cycle.md](/Volumes/DevSSD/FitTracker2/project_framework_v7_1_integrity_cycle.md)
- Canonical independent audit: [docs/case-studies/meta-analysis/independent-audit-2026-04-21-gemini.md](/Volumes/DevSSD/FitTracker2/docs/case-studies/meta-analysis/independent-audit-2026-04-21-gemini.md)
- Canonical v7.1 case study: [docs/case-studies/integrity-cycle-v7.1-case-study.md](/Volumes/DevSSD/FitTracker2/docs/case-studies/integrity-cycle-v7.1-case-study.md)
- **Canonical v7.5 case study**: [docs/case-studies/data-integrity-framework-v7.5-case-study.md](/Volumes/DevSSD/FitTracker2/docs/case-studies/data-integrity-framework-v7.5-case-study.md)
- **Canonical v7.6 case study**: [docs/case-studies/mechanical-enforcement-v7-6-case-study.md](/Volumes/DevSSD/FitTracker2/docs/case-studies/mechanical-enforcement-v7-6-case-study.md)
- **Class B unclosable-gaps inventory (v7.6)**: [docs/case-studies/meta-analysis/unclosable-gaps.md](/Volumes/DevSSD/FitTracker2/docs/case-studies/meta-analysis/unclosable-gaps.md)
- **Developer guide (v1.0 → v7.6 technical reference)**: [docs/architecture/dev-guide-v1-to-v7-6.md](/Volumes/DevSSD/FitTracker2/docs/architecture/dev-guide-v1-to-v7-6.md)
- **Tier 3.3 public invitation issue (Phase 3c, filed 2026-04-25, pinned)**: [GitHub issue #142](https://github.com/Regevba/FitTracker2/issues/142)
- Meta-analysis audited by Gemini: [docs/case-studies/meta-analysis/meta-analysis-2026-04-21.md](/Volumes/DevSSD/FitTracker2/docs/case-studies/meta-analysis/meta-analysis-2026-04-21.md)
- v7.5 advancement report (T1/T2/T3 tagged before/after deltas): [docs/case-studies/meta-analysis/v7-5-advancement-report.md](/Volumes/DevSSD/FitTracker2/docs/case-studies/meta-analysis/v7-5-advancement-report.md)
- Remediation plan and status reset: [remediation-plan-2026-04-23.md](/Volumes/DevSSD/FitTracker2/trust/audits/2026-04-21-gemini/remediation-plan-2026-04-23.md)
- v7.6 unified completion plan (cross-walk of original plan + Codex pending-fixes + in-session additions): [docs/superpowers/plans/2026-04-25-v7-6-unified-completion-plan.md](/Volumes/DevSSD/FitTracker2/docs/superpowers/plans/2026-04-25-v7-6-unified-completion-plan.md)

## Recommendation status snapshot (updated 2026-04-25 at v7.6 ship)

| Tier | Status | Notes |
|---|---|---|
| Tier 1.1 | Partial, measured | 4 of 7 post-v6 features have `cu_v2`; 2 of 7 have `cache_hits`. Writer-path **shipped** via `--cache-hit` flag in `append-feature-log.py` (issue #140 closed at writer-path; **adoption stays Class B Gap 1**). Trend mode unlocks after 3 weekly cron snapshots. |
| Tier 1.2 | ✓ shipped, hardened by v7.6 | On-write via pre-commit (`PR_NUMBER_UNRESOLVED`) + 72h cycle. v7.6 Phase 1c added `BROKEN_PR_CITATION` at write-time with narrow regex (`PR\s*#?` or `pull/N`). |
| Tier 1.3 | ✓ shipped, hardened by v7.6 | v7.5 shipped `SCHEMA_DRIFT`. v7.6 Phase 1a/1b added `PHASE_TRANSITION_NO_LOG` + `PHASE_TRANSITION_NO_TIMING` write-time pre-commit. |
| Tier 2.1 | Groundwork shipped, **manual playbook** is Class B Gap 4 | Staging `app_launch` + `sign_in_surface` smokes green. The 7-step real-provider checklist requires a human at a simulator and is documented as Gap 4 in `unclosable-gaps.md` — physical necessity. |
| Tier 2.2 | ✓ used end-to-end during v7.6 own session | `data-integrity-framework-v7-6/log.json` recorded 9+ events from `phase_started` through `phase_transition`. Cache-hits writer-path exercised (3 hits logged). |
| Tier 2.3 | ✓ shipped, hardened by v7.6 | Data quality tiers convention + CLAUDE.md rule. v7.6 Phase 1d added `CASE_STUDY_MISSING_TIER_TAGS` write-time check (forward-only ≥ 2026-04-21). Tag *correctness* is Class B Gap 3. |
| Tier 3.1 | ✓ shipped, hardened by v7.6 | 72h Auditor Agent extended to 12 cycle-time check codes. v7.6 Phase 2a adds the per-PR review bot (`pm-framework/pr-integrity` status check) — fails on findings delta OR command-error exits. |
| Tier 3.2 | Baseline shipped, observational | Dashboard at `.claude/shared/documentation-debt.json`; weekly cron (v7.6 Phase 2c) appends history snapshots; trend mode unlocks after 3 cycle snapshots. |
| Tier 3.3 | **Filed as issue #142** (pinned) | Public GitHub external-replication invitation; Phase 3c of v7.6, the explicit final deliverable. Documented as Class B Gap 5 — closes when an external case study lands in `docs/case-studies/external/`. |

**Aggregate at v7.6 ship: 7 Class B → Class A promotions on top of v7.5; 5 mechanically unclosable Class B gaps individually documented and tracked.**

## Deferred-item constraints (after v7.6 reframe as Class B gaps)

The five items below are now formalized as Class B gaps in
[`docs/case-studies/meta-analysis/unclosable-gaps.md`](/Volumes/DevSSD/FitTracker2/docs/case-studies/meta-analysis/unclosable-gaps.md).
v7.6 explicitly enumerated them rather than continuing to treat them as
"deferred work".

- **Gap 1 — Tier 1.1 `cache_hits[]` adoption.** Writer-path is shipped
  (`--cache-hit` flag in `append-feature-log.py`); deciding what counts as a
  cache hit is the agent-attention judgment we cannot mechanize. Tracked at
  [issue #140](https://github.com/Regevba/FitTracker2/issues/140).
- **Gap 2 — Tier 2.3 `cu_v2` factor magnitude correctness.** v6.0 schema is
  shipped; whether `novelty: 0.2` is the right number for a feature is a
  judgment call that the framework cannot mechanize without ground truth.
- **Gap 3 — Tier 2.3 T1/T2/T3 tag correctness.** v7.6 preflight enforces tag
  *presence* (`CASE_STUDY_MISSING_TIER_TAGS`); whether the tag is the *right*
  tag requires reading prose in context.
- **Gap 4 — Tier 2.1 manual real-provider auth.** Apple/Google sign-in on a
  real device cannot be driven by an automated test runner without crossing
  into the mocking pattern v7.5 was built to avoid.
- **Gap 5 — Tier 3.3 external replication.** No pre-commit hook can simulate
  "an external operator on an unrelated product succeeded with the framework."
  Filed as the public invitation [issue #142](https://github.com/Regevba/FitTracker2/issues/142)
  on 2026-04-25; closes when at least one external case study lands in
  `docs/case-studies/external/`.

## Tier 3.2 trend-mode prerequisite

The Tier 3.2 documentation-debt dashboard ships a baseline ledger now and
unlocks trend mode after **3 scheduled cycle snapshots accumulate** in
`.claude/integrity/snapshots/`. The v7.6 weekly framework-status cron
(`.github/workflows/framework-status-weekly.yml`) accelerates this by also
snapshotting `measurement-adoption-history.json` once per week.

This folder intentionally indexes the source-of-truth documents rather than
duplicating them.
