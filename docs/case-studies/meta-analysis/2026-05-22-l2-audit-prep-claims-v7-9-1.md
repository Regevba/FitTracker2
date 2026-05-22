# L2 — Audit-Prep Claim Ledger (File A, auditor-facing)

> Generated from L0 extraction bundle SHA256: `6d106b47f3dd5bf48954f36499bd9634a17f615a04cdd820cc16d7f21ec03599`
> Companion internal sidecar: see [`2026-05-22-l2-internal-sidecar.md`](2026-05-22-l2-internal-sidecar.md) (NOT staged to external auditor)

~~~yaml
- id: C-001
  audit_profile_section: "v7.9 gate promotion"
  claim_text: "BRANCH_ISOLATION_VIOLATION Mode B and Mode C were promoted from advisory to enforced via PR #417 on 2026-05-21 by flipping BRANCH_ISOLATION_ADVISORY_MODE from True to False at scripts/check-state-schema.py line 132."
  evidence_paths:
    - scripts/check-state-schema.py
    - docs/case-studies/framework-v7-9-promotion-case-study.md
    - .claude/logs/gate-coverage.jsonl

- id: C-002
  audit_profile_section: "v7.9 gate promotion"
  claim_text: "FEATURE_CLOSURE_COMPLETENESS write-time gate was promoted from advisory to enforced in the same PR #417 commit on 2026-05-21, controlled by the same BRANCH_ISOLATION_ADVISORY_MODE flag in scripts/check-state-schema.py."
  evidence_paths:
    - scripts/check-state-schema.py
    - docs/case-studies/framework-v7-9-promotion-case-study.md
    - .claude/logs/gate-coverage.jsonl

- id: C-003
  audit_profile_section: "v7.9 promotion criteria"
  claim_text: "Mechanism A telemetry for the three promoted gates covered a 14-day window from 2026-05-07 to 2026-05-21, with BRANCH_ISOLATION_VIOLATION Mode B emitting 18 rows, Mode C emitting 13 rows, and FEATURE_CLOSURE_COMPLETENESS emitting 13 rows in .claude/logs/gate-coverage.jsonl."
  evidence_paths:
    - .claude/logs/gate-coverage.jsonl
    - docs/case-studies/framework-v7-9-promotion-case-study.md
    - docs/case-studies/framework-honesty-ledger.md

- id: C-004
  audit_profile_section: "v7.9 promotion criteria"
  claim_text: "The four v7.9 promotion criteria per infra master plan §2.2 are: (1) coverage emitted for ≥7 days, verified at 14 days; (2) zero false positives across all 44 telemetry rows; (3) all skip_reasons map to documented cases (not_infra_commit_level, not_complete_transition, opt_out_false_or_absent); (4) reversibility via single-line revert in under 5 minutes."
  evidence_paths:
    - docs/master-plan/infra-master-plan-2026-05-12.md
    - docs/case-studies/framework-v7-9-promotion-case-study.md

- id: C-005
  audit_profile_section: "framework gate inventory"
  claim_text: "As of 2026-05-22, the write-time gate inventory in scripts/check-state-schema.py includes SCHEMA_DRIFT, PR_NUMBER_UNRESOLVED, PHASE_TRANSITION_NO_LOG, PHASE_TRANSITION_NO_TIMING, BROKEN_PR_CITATION, CASE_STUDY_MISSING_TIER_TAGS, ISOLATION_OPT_OUT_REASON_MISSING, BRANCH_ISOLATION_VIOLATION (enforced at v7.9), FEATURE_CLOSURE_COMPLETENESS (enforced at v7.9), STATE_OWNER_MISSING, STATE_OWNER_INVALID, STATE_OWNER_LOCATION_MISMATCH, CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT, CU_V2_INVALID, STATE_NO_CASE_STUDY_LINK, and CASE_STUDY_MISSING_FIELDS."
  evidence_paths:
    - scripts/check-state-schema.py
    - CLAUDE.md

- id: C-006
  audit_profile_section: "framework gate inventory"
  claim_text: "As of v7.8 through v7.9, the cycle-time integrity check in scripts/integrity-check.py enforces 16 check codes: 13 baseline codes plus 3 v7.8 additions (BRANCH_ISOLATION_HISTORICAL, BRANCH_ISOLATION_LAUNCHD_DRIFT, and FEATURE_CLOSURE_COMPLETENESS cycle-time mirror), plus 1 permanent advisory (CACHE_HITS_AUTO_INSTRUMENTATION_INACTIVE, the 15th check code)."
  evidence_paths:
    - scripts/integrity-check.py
    - CLAUDE.md

- id: C-007
  audit_profile_section: "framework gate inventory"
  claim_text: "CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT (previously named CACHE_HITS_EMPTY_POST_V6) was promoted from advisory to enforced at v7.8.3 Phase 0 on 2026-05-11 via PR #298."
  evidence_paths:
    - CLAUDE.md
    - docs/case-studies/meta-analysis/unclosable-gaps.md

- id: C-008
  audit_profile_section: "framework gate inventory"
  claim_text: "Mechanism E custom git merge driver was extended at v7.8.3 Phase 0 via PR #298 to cover .claude/logs/<feature>.log.json in addition to its original scope of measurement-adoption-history.json and documentation-debt.json."
  evidence_paths:
    - CLAUDE.md
    - scripts/merge-driver-dedup.py

- id: C-009
  audit_profile_section: "framework gate inventory"
  claim_text: "Four mechanically unclosable gaps remain in the framework as documented in docs/case-studies/meta-analysis/unclosable-gaps.md: (1) cache_hits[] correctness is judgment-based; (2) cu_v2 factor correctness checks presence, not magnitude; (3) T1/T2/T3 tag correctness checks presence, not accuracy; (4) Tier 2.1 real-provider auth checklist requires a human at a simulator."
  evidence_paths:
    - docs/case-studies/meta-analysis/unclosable-gaps.md
    - CLAUDE.md

- id: C-010
  audit_profile_section: "framework gate inventory"
  claim_text: "Three cycle-time advisories remain advisory by design per CLAUDE.md v7.9 section: BRANCH_ISOLATION_HISTORICAL (T17, forward-only audit), BRANCH_ISOLATION_LAUNCHD_DRIFT (T18, macOS-only plist scan), and FEATURE_CLOSURE_COMPLETENESS cycle-time mirror (T19, --no-verify bypass catcher). TIER_TAG_LIKELY_INCORRECT is a fourth permanent advisory (kill criterion 2 fired at baseline during v7.7 ship)."
  evidence_paths:
    - CLAUDE.md
    - scripts/integrity-check.py

- id: C-011
  audit_profile_section: "HADF Phase 2 outcome"
  claim_text: "HADF Phase 2 closed with a positive verdict on 2026-05-01, with silhouette score 0.5566 at best_k=5 clusters against a pre-registered threshold of >0.5."
  evidence_paths:
    - .claude/shared/hadf/phase2-fingerprint-summary.json
    - docs/case-studies/hadf-phase2-cloud-fingerprinting-case-study.md

- id: C-012
  audit_profile_section: "HADF Phase 2-bis state"
  claim_text: "HADF Phase 2-bis Block A shipped on 2026-05-12 with 13 tasks (A0 through A12) on branch feat/hadf-phase2bis-impl; Block B Sub-experiment 1 is gated on 2026-05-23 pending a 6-item safety-verification ceremony."
  evidence_paths:
    - .claude/features/hadf-phase2bis-replication/state.json

- id: C-013
  audit_profile_section: "HADF Phase 2-bis state"
  claim_text: "HADF Phase 2-bis Block B Sub-experiment 1 launch is scheduled for 2026-05-23, gated on a 6-item safety-verification ceremony; as of 2026-05-22 (the extraction date), the launch has not yet occurred."
  evidence_paths:
    - .claude/features/hadf-phase2bis-replication/state.json

- id: C-014
  audit_profile_section: "HADF Phase 2 outcome"
  claim_text: "HADF Phase 2 case study showcase MDX was filed at slot 22b in the fitme-story content/04-case-studies/ directory; this file resides in the fitme-story repository, not in FitTracker2."
  evidence_paths:
    - docs/case-studies/hadf-phase2-cloud-fingerprinting-case-study.md

- id: C-015
  audit_profile_section: "HADF Phase 2 outcome"
  claim_text: "HADF Path B (cloud-provider-class dispatch) was green-lit as a result of the Phase 2 positive verdict; the path_b_recommendation field in .claude/shared/hadf/phase2-fingerprint-summary.json records this as 'green-lit'."
  evidence_paths:
    - .claude/shared/hadf/phase2-fingerprint-summary.json
    - .claude/shared/hadf/phase2-preregistration.json

- id: C-016
  audit_profile_section: "HADF Phase 2 outcome"
  claim_text: "HADF Phase 2 primary dataset comprised 700 valid records (350 OpenAI endpoint + 350 Anthropic endpoint); a second-pass dataset of 200 contaminated records was collected and segregated. Both pre-registered floors (600 valid total, 150 per endpoint) were met."
  evidence_paths:
    - .claude/shared/hadf/phase2-fingerprint-summary.json
    - docs/case-studies/hadf-phase2-cloud-fingerprinting-case-study.md

- id: C-017
  audit_profile_section: "HADF Phase 2 outcome"
  claim_text: "HADF Phase 2 measurement plan was approved on 2026-04-21 with Path A (cloud fingerprinting) as the sole planned path; Path B was green-lit as a derived outcome of Phase 2's positive verdict on 2026-05-01."
  evidence_paths:
    - .claude/shared/hadf/phase2-preregistration.json
    - docs/case-studies/hadf-phase2-cloud-fingerprinting-case-study.md

- id: C-018
  audit_profile_section: "framework gate inventory"
  claim_text: "Concurrent dispatch hygiene blockers F6 through F9 are documented as still active in docs/framework-bugs/concurrent-dispatch-blockers.md as of the extraction date; serial dispatch is the working pattern per CLAUDE.md."
  evidence_paths:
    - docs/framework-bugs/concurrent-dispatch-blockers.md
    - CLAUDE.md

- id: C-019
  audit_profile_section: "UCC passkey-auth shipping"
  claim_text: "UCC passkey-auth shipped on 2026-05-07 via four PRs: fitme-story PR #55 (squash 5362f8f), fitme-story PR #56, FT2 PR #248 (squash e5a7c45), and FT2 PR #249; 28 of 28 tasks completed and 19 of 19 tests passed."
  evidence_paths:
    - .claude/features/ucc-passkey-auth/state.json
    - docs/case-studies/ucc-passkey-auth-case-study.md

- id: C-020
  audit_profile_section: "UCC passkey-auth shipping"
  claim_text: "UCC passkey cutover to UCC_AUTH_MODE=both completed on 2026-05-16 via FT2 PR #380 and fitme-story PR #120, placing the system in a transition state where both passkey and legacy basic-auth are accepted."
  evidence_paths:
    - .claude/features/ucc-passkey-auth/state.json

- id: C-021
  audit_profile_section: "UCC hardening"
  claim_text: "UCC passkey-auth security hardening shipped on 2026-05-20 via fitme-story PR #127 and FT2 PRs #410, #411, and #412; kill_criteria_resolution is empty at extraction time, pending B12 evaluation on 2026-05-27."
  evidence_paths:
    - docs/case-studies/ucc-passkey-auth-security-hardening-case-study.md
    - .claude/features/ucc-passkey-auth-security-hardening/state.json

- id: C-022
  audit_profile_section: "UCC hardening"
  claim_text: "The B11 UCC hardening T+3d calibration check is scheduled for 2026-05-22 per CLAUDE.md v7.9 post-promotion calendar."
  evidence_paths:
    - CLAUDE.md
    - .claude/shared/must-have-cadence-followups.md

- id: C-023
  audit_profile_section: "UCC hardening"
  claim_text: "The B12 UCC hardening T+7d kill-criteria evaluation is scheduled for 2026-05-27 per CLAUDE.md post-promotion calendar and the kill_criteria field in the ucc-passkey-auth-security-hardening case study."
  evidence_paths:
    - CLAUDE.md
    - docs/case-studies/ucc-passkey-auth-security-hardening-case-study.md

- id: C-024
  audit_profile_section: "UCC passkey-auth shipping"
  claim_text: "UCC Part 8 (passkey-only flip, removing legacy basic-auth) is gated on 2026-05-28 or later; as of the extraction date 2026-05-22, Part 8 has not shipped."
  evidence_paths:
    - docs/setup/ucc-passkey-auth-setup-guide.md
    - .claude/features/ucc-passkey-auth/state.json

- id: C-025
  audit_profile_section: "Cross-repo state sync"
  claim_text: "v7.8.3 Phase 0 shipped on 2026-05-11 via PR #298, delivering promotion of CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT to enforced (V2), extension of Mechanism E to .claude/logs/<feature>.log.json (V9), the make snapshot-phase Makefile target, and scripts/snapshot-phase-completion.sh."
  evidence_paths:
    - CLAUDE.md
    - .claude/features/cross-repo-state-sync-impl/state.json

- id: C-026
  audit_profile_section: "Cross-repo state sync"
  claim_text: "The state_owner field is present on 100% of features in the v7.8-v7.9 cohort (25 of 25) per L1 §17.2; the field was introduced at v7.8.3 Phase 2 and backfilled to all 62 features existing at that time in a single mechanical commit."
  evidence_paths:
    - docs/case-studies/meta-analysis/2026-05-22-l1-extended-cohort-analysis.md
    - .claude/features/cross-repo-state-sync-impl/state.json

- id: C-027
  audit_profile_section: "Cross-repo state sync"
  claim_text: "Mechanism E custom git merge driver was originally scoped to measurement-adoption-history.json and documentation-debt.json (PR #189, 2026-05-03); at v7.8.3 Phase 0 (PR #298, 2026-05-11) the scope was extended to also cover .claude/logs/<feature>.log.json."
  evidence_paths:
    - CLAUDE.md
    - scripts/merge-driver-dedup.py

- id: C-028
  audit_profile_section: "Cross-repo state sync"
  claim_text: "v7.8.3 Phase 1 D-3 shipped on 2026-05-11 via FT2 PR #299, delivering a unified cross-repo PR cite cache with scripts/refresh-pr-cache.py; 63 features were validated retroactively for PR citation correctness at the time of Phase 1 ship."
  evidence_paths:
    - CLAUDE.md
    - .claude/features/cross-repo-state-sync-impl/state.json

- id: C-029
  audit_profile_section: "Framework honesty ledger"
  claim_text: "FT2-FH-001 documents that the CACHE_HITS_EMPTY_POST_V6 gate had 0% effective coverage at v7.7 ship because 43 of 46 state.json files used the legacy 'created' key while the gate read 'created_at'; status is CLOSED, remediated in v7.8 via PRs #169, #173, #185 through #189, #192, and #193."
  evidence_paths:
    - docs/case-studies/framework-honesty-ledger.md

- id: C-030
  audit_profile_section: "Framework honesty ledger"
  claim_text: "FT2-FH-002 documents that make integrity-check reported 35 findings (32 BROKEN_PR_CITATION, 2 PR_NUMBER_UNRESOLVED, 1 PHASE_LIE) on 2026-05-12 that were 100% false positives caused by an empty .cache/gh-pr-cache.json; status is CLOSED, remediated in v7.8.4 via scripts/ensure-pr-cache-fresh.py."
  evidence_paths:
    - docs/case-studies/framework-honesty-ledger.md

- id: C-031
  audit_profile_section: "Framework honesty ledger"
  claim_text: "FT2-FH-003 records the v7.9 promotion as the first framework-version flip to use Mechanism A telemetry as a gate on its own promotion decision, documenting the 4-criterion checklist (coverage emitted, no false positives, no silent skips, reversibility) as the forward protocol; this entry is a discipline-codification record, not a correction."
  evidence_paths:
    - docs/case-studies/framework-honesty-ledger.md
    - docs/case-studies/framework-v7-9-promotion-case-study.md

- id: C-032
  audit_profile_section: "Framework honesty ledger"
  claim_text: "The framework honesty ledger at docs/case-studies/framework-honesty-ledger.md contains 3 entries (FT2-FH-001 through FT2-FH-003) as of the extraction date 2026-05-22; the file is append-only and its edit history is verifiable via git log."
  evidence_paths:
    - docs/case-studies/framework-honesty-ledger.md

- id: C-033
  audit_profile_section: "L1 cohort findings"
  claim_text: "Per L1 §17.2, cache_hits[] is non-empty on 13 of 25 features (52.0%) in the v7.8-v7.9 cohort; no post-v6 cohort reaches 100% at the extraction date."
  evidence_paths:
    - docs/case-studies/meta-analysis/2026-05-22-l1-extended-cohort-analysis.md

- id: C-034
  audit_profile_section: "L1 cohort findings"
  claim_text: "Per L1 §17.2, kill_criteria_resolution is populated on 1 of 6 features (16.7%) in the v7.8-v7.9 cohort where kill_criteria is set; the 5 features with kill_criteria set but no resolution are in-progress at extraction time and the FEATURE_CLOSURE_COMPLETENESS gate requires resolution only at current_phase=complete transitions."
  evidence_paths:
    - docs/case-studies/meta-analysis/2026-05-22-l1-extended-cohort-analysis.md

- id: C-035
  audit_profile_section: "L1 cohort findings"
  claim_text: "Per L1 §17.2, cu_v2 schema-valid rates are 50.0% (4 of 8) for the v7.5-v7.7 cohort and 16.0% (4 of 25) for the v7.8-v7.9 cohort; absolute counts are equal at 4 features each while the denominator increased from 8 to 25."
  evidence_paths:
    - docs/case-studies/meta-analysis/2026-05-22-l1-extended-cohort-analysis.md

- id: C-036
  audit_profile_section: "L0 corpus measurement"
  claim_text: "Per L1 §5, dispatch_pattern is absent on 66 of 75 features (88.0%) in the full corpus at extraction; the field was introduced post-v6.0 and has not been backfilled for features that predate it."
  evidence_paths:
    - docs/case-studies/meta-analysis/2026-05-22-l1-extended-cohort-analysis.md

- id: C-037
  audit_profile_section: "L1 cohort findings"
  claim_text: "Per L1 §18.1, the cross-repo corpus split at extraction is 74 features with state_owner=ft2 and 1 feature with state_owner=fitme-story (3d-interactive-framework-flow-diagram, at prd phase); L1 §18.4 notes the re-evaluation threshold for cross-repo comparative analysis is 5 or more fitme-story features."
  evidence_paths:
    - docs/case-studies/meta-analysis/2026-05-22-l1-extended-cohort-analysis.md

- id: C-038
  audit_profile_section: "L0 corpus measurement"
  claim_text: "Per L1 §11, the v7.8-v7.9 framework_version bucket contains 25 of 75 features (33.3%), making it the plurality bucket ahead of the v5.x bucket at 20 of 75 features (26.7%); the v7.8-v7.9 bucket spans framework versions v7.8 through v7.8.6 and v7.9."
  evidence_paths:
    - docs/case-studies/meta-analysis/2026-05-22-l1-extended-cohort-analysis.md
~~~
