# L2 — Audit-Prep Claim Ledger (File B, internal sidecar)

> Generated: 2026-05-22
> Phase: 1 of 3 (meta-analysis refresh)
> Companion auditor-facing file: [`2026-05-22-l2-audit-prep-claims-v7-9-1.md`](2026-05-22-l2-audit-prep-claims-v7-9-1.md)
> Per spec §5.3: This file is **INTERNAL-ONLY**. NEVER staged into `docs/audits/external/*/claude-bundle/`. Contains working notes (confidence + predicted findings + caveats) that pair with each `claim_id` in File A.

```yaml
- id: C-001
  internal_confidence: high
  expected_auditor_finding: "Likely confirms; gate-coverage.jsonl rows + PR #417 merge commit + FT2-FH-003 honesty ledger entry all corroborate"
  notes: "BRANCH_ISOLATION_VIOLATION (Mode B + Mode C) promoted from advisory to enforced via single-flag flip at scripts/check-state-schema.py:132 on 2026-05-21. Both modes controlled by BRANCH_ISOLATION_ADVISORY_MODE = True → False. Claim is verifiable from git log on that file."

- id: C-002
  internal_confidence: high
  expected_auditor_finding: "Likely confirms; same single-flag flip covers FEATURE_CLOSURE_COMPLETENESS simultaneously"
  notes: "FEATURE_CLOSURE_COMPLETENESS write-time gate promoted the same commit (PR #417). Mechanism A telemetry shows 13 rows over 14 days, 0 false positives. CLAUDE.md v7.9 section and v7.9 promotion case study are the canonical sources."

- id: C-003
  internal_confidence: high
  expected_auditor_finding: "Likely confirms; .claude/logs/gate-coverage.jsonl is in the bundle and row counts are deterministic"
  notes: "14-day window 2026-05-07 to 2026-05-21. Mechanism A emission counts: BRANCH_ISOLATION_VIOLATION Mode B = 18 rows, Mode C = 13 rows, FEATURE_CLOSURE_COMPLETENESS = 13 rows. Source: framework-v7-9-promotion-case-study.md §3 + FT2-FH-003. Auditor could recount rows from gate-coverage.jsonl directly."

- id: C-004
  internal_confidence: high
  expected_auditor_finding: "Likely confirms all four criteria; auditor may flag criterion 4 (reversibility) as not independently verifiable from bundle alone"
  notes: "Four v7.9 promotion criteria per infra-master-plan §2.2: (1) coverage emitted ≥7d — 14d observed; (2) no false positives — 0 across all 44 rows; (3) no silent skips — all skip_reasons map to documented cases; (4) reversibility — single-line revert <5 min. Criteria 1-3 are bundle-verifiable; criterion 4 is declared (T2). v7.9 promotion case study Section 2 B1 freeze checklist is the source."

- id: C-005
  internal_confidence: medium
  expected_auditor_finding: "Could flag count discrepancy if auditor enumerates scripts/check-state-schema.py gate list vs CLAUDE.md; the exact count of 8 requires careful line-by-line enumeration"
  notes: "Per CLAUDE.md Data Integrity Framework: SCHEMA_DRIFT, PR_NUMBER_UNRESOLVED, PHASE_TRANSITION_NO_LOG, PHASE_TRANSITION_NO_TIMING, BROKEN_PR_CITATION, CASE_STUDY_MISSING_TIER_TAGS, ISOLATION_OPT_OUT_REASON_MISSING, BRANCH_ISOLATION_VIOLATION (enforced v7.9), FEATURE_CLOSURE_COMPLETENESS (enforced v7.9), plus STATE_OWNER_MISSING, STATE_OWNER_INVALID, STATE_OWNER_LOCATION_MISMATCH (v7.8.3), CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT, CU_V2_INVALID, STATE_NO_CASE_STUDY_LINK, CASE_STUDY_MISSING_FIELDS. The exact count depends on how you group modes and whether you count advisory vs enforced. The L0 §3 table says 8 write-time gates at 2026-05-22; auditor should verify against scripts/check-state-schema.py gate list."

- id: C-006
  internal_confidence: high
  expected_auditor_finding: "Likely confirms; 16 is stated verbatim in CLAUDE.md 'Cycle-time gates' paragraph"
  notes: "16 cycle-time check codes per CLAUDE.md: 13 baseline + 3 v7.8 additions (BRANCH_ISOLATION_HISTORICAL, BRANCH_ISOLATION_LAUNCHD_DRIFT, FEATURE_CLOSURE_COMPLETENESS mirror). L0 §3 table corroborates. Plus 1 advisory (CACHE_HITS_AUTO_INSTRUMENTATION_INACTIVE, 15th check code). Auditor can verify from scripts/integrity-check.py check-code list."

- id: C-007
  internal_confidence: high
  expected_auditor_finding: "Likely confirms; PR #298 is cited as the ship vehicle in CLAUDE.md v7.8.3 Phase 0 paragraph"
  notes: "CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT (renamed from CACHE_HITS_EMPTY_POST_V6) promoted from advisory to enforced at v7.8.3 Phase 0 ship on 2026-05-11 via PR #298. V2 plan-of-record decision. unclosable-gaps.md confirms the promotion detail with explicit 'ENFORCED' status."

- id: C-008
  internal_confidence: high
  expected_auditor_finding: "Likely confirms; PR #298 and CLAUDE.md v7.8.3 Phase 0 paragraph state this explicitly"
  notes: "Mechanism E custom git merge driver (V9 plan-of-record item) extended to .claude/logs/<feature>.log.json at v7.8.3 Phase 0. Per CLAUDE.md: 'V9 — Mechanism E custom git merge driver extends to .claude/logs/<feature>.log.json'. Original Mechanism E (PR #189) only covered measurement-adoption-history.json and documentation-debt.json."

- id: C-009
  internal_confidence: high
  expected_auditor_finding: "Likely confirms; unclosable-gaps.md is in the bundle and lists exactly 4 remaining gaps after Gap 1 closure"
  notes: "Per unclosable-gaps.md (updated 2026-05-11): 4 mechanically unclosable gaps remain: (1) cache_hits[] correctness — judgment call, auto-collected but not validated; (2) cu_v2 factor correctness — presence checked, not magnitude; (3) T1/T2/T3 tag correctness — presence checked, not accuracy; (4) Tier 2.1 real-provider auth checklist — requires human at simulator. CLAUDE.md 'Known Mechanical Limits' lists 5 gaps but gap 1 is struck through as closed, leaving 4 active. The numbered list in CLAUDE.md still shows 5 items (including the struck-through one), so auditor may count 4 or 5 depending on reading."

- id: C-010
  internal_confidence: high
  expected_auditor_finding: "Likely confirms; CLAUDE.md explicitly lists which cycle-time advisories stay advisory by design"
  notes: "3 cycle-time advisories stay advisory by design per CLAUDE.md v7.9 section: BRANCH_ISOLATION_HISTORICAL (T17 forward-only audit), BRANCH_ISOLATION_LAUNCHD_DRIFT (T18 macOS-only plist scan), FEATURE_CLOSURE_COMPLETENESS cycle-time mirror (T19 —no-verify bypass catcher). Plus TIER_TAG_LIKELY_INCORRECT (permanent advisory since v7.7 — kill criterion 2 fired at baseline). Total of 4 advisories staying advisory. Claim in File A should specify the count carefully."

- id: C-011
  internal_confidence: high
  expected_auditor_finding: "Likely confirms; hadf-phase2-cloud-fingerprinting-case-study.md cites silhouette 0.5566 at best_k=5 as T1 from summary artifact"
  notes: "HADF Phase 2 closed POSITIVE 2026-05-01. Silhouette score 0.5566 at best_k=5; threshold was >0.5 pre-registered. clusters_found=true, path_b_recommendation=green-lit. Valid records: 700 (350 openai + 350 anthropic). Contaminated records: 200 (segregated). All quantitative claims trace to .claude/shared/hadf/phase2-fingerprint-summary.json (squash commit a4b357f on main). Auditor should verify summary artifact is in bundle and hash-consistent."

- id: C-012
  internal_confidence: medium
  expected_auditor_finding: "Likely confirms task count; auditor may flag that Block A ship date (2026-05-12) vs Block B 2026-05-23 gating creates unresolved open state"
  notes: "HADF Phase 2-bis Block A shipped 2026-05-12 (13 tasks A0-A12) on branch feat/hadf-phase2bis-impl. Per MEMORY.md: '13 tasks A0-A12 on feat/hadf-phase2bis-impl; Block B Sub-exp 1 gated 2026-05-23'. State.json at .claude/features/hadf-phase2bis-replication/ should confirm. Feature is in-progress at extraction time — case study not yet in docs/case-studies/ (state.json declares cs path but file does not exist per L1 §13)."

- id: C-013
  internal_confidence: medium
  expected_auditor_finding: "Likely confirms the 2026-05-23 date; auditor may flag that we cannot confirm whether the launch actually occurred (this document is generated on 2026-05-22, the day before)"
  notes: "Sub-experiment 1 launch gated 2026-05-23 on 6-item safety-verification ceremony per MEMORY.md project_hadf_phase2bis_block_a_shipped_2026_05_12.md. The 6-item list is in docs/master-plan/post-v7-9-candidate-plan-2026-05-20.md or similar. Claim in File A should be future-tense as of its generation date (2026-05-22). This is a forward-looking claim about a scheduled event, not a completed one."

- id: C-014
  internal_confidence: medium
  expected_auditor_finding: "Likely confirms MDX existence at fitme-story slot 22b; auditor may flag that 'showcase' claim requires verifying fitme-story content directory"
  notes: "HADF Phase 2 case study showcase MDX filed at fitme-story content/04-case-studies/. Per MEMORY.md project_hadf_phase2_in_progress.md: 'showcase MDX 22b'. The MDX file is in fitme-story repo, not FT2 — may not be in the FT2 audit bundle. Claim in File A should note this cross-repo dependency."

- id: C-015
  internal_confidence: high
  expected_auditor_finding: "Likely confirms; path_b_recommendation=green-lit is recorded in the summary artifact"
  notes: "HADF Path B (cloud-provider-class dispatch) green-lit by Phase 2 positive verdict. The green-lit status is a binary field in .claude/shared/hadf/phase2-fingerprint-summary.json. Pre-registration at .claude/shared/hadf/phase2-preregistration.json declares 'clusters_found=true → Path B green-lit' as the success criterion, so this is a mechanically derived conclusion from the threshold test, not a narrative judgment."

- id: C-016
  internal_confidence: high
  expected_auditor_finding: "Likely confirms n=700 primary + n=200 second-pass contaminated; case study and summary artifact agree"
  notes: "HADF Phase 2: 700 valid records (350 openai + 350 anthropic) in primary dataset; 200 contaminated/segregated second-pass records. 2 endpoints included (local excluded). 2 calendar days of collection (early closure). Pre-registered floor was 600 valid + 150 per endpoint — both met. The '700+200' framing in MEMORY.md matches the case study figures."

- id: C-017
  internal_confidence: high
  expected_auditor_finding: "Likely confirms; MEMORY.md and case study both cite 2026-04-21 approval date"
  notes: "HADF Phase 2 measurement plan approved 2026-04-21 per MEMORY.md project_hadf_phase2_measurement_plan.md. Original plan was Path A only (cloud fingerprinting, ~$5, ~3 days). Path B was green-lit as a result of Phase 2 positive verdict (2026-05-01). The approval date is a calendar fact easily verifiable from git log on the preregistration file."

- id: C-018
  internal_confidence: high
  expected_auditor_finding: "Likely confirms; docs/framework-bugs/concurrent-dispatch-blockers.md is in the bundle"
  notes: "Concurrent dispatch hygiene blockers F6-F9 documented as still active per CLAUDE.md 'Concurrent Dispatch Hygiene' section. F6-F9 prevent parallel subagent dispatch; serial dispatch is the working pattern. Re-validation gate is specified as requiring proof-of-fix-tests.md run before resuming parallel work. No claim that these are fixed — the claim is that they remain open."

- id: C-019
  internal_confidence: high
  expected_auditor_finding: "Likely confirms; 4 PR numbers and squash SHAs are recorded in ucc-passkey-auth-case-study.md frontmatter"
  notes: "UCC passkey-auth shipped 2026-05-07 via: fitme-story PR #55 (squash 5362f8f) + fitme-story PR #56 (second PR in the 4-PR set) + FT2 PR #248 (squash e5a7c45) + FT2 PR #249. Per case study frontmatter related_prs array. MEMORY.md project_ucc_passkey_auth_shipped.md confirms 4 PRs. 28/28 tasks done; 19/19 tests pass."

- id: C-020
  internal_confidence: medium
  expected_auditor_finding: "Likely confirms; MEMORY.md UCC passkey cutover entry cites UCC_AUTH_MODE=both as the cutover state"
  notes: "UCC cutover to UCC_AUTH_MODE=both completed 2026-05-16 via MEMORY.md project_ucc_passkey_cutover_2026_05_16.md: 'FT2 #380 + fitme-story #120 MERGED'. The 'both' mode means both passkey and legacy basic-auth are accepted during transition. The specific PR numbers (#380, #120) and merged status are from MEMORY.md. Auditor would need to verify PR status via gh pr view — not bundle-verifiable."

- id: C-021
  internal_confidence: high
  expected_auditor_finding: "Likely confirms; ucc-passkey-auth-security-hardening-case-study.md frontmatter lists all 4 PRs"
  notes: "UCC hardening shipped 2026-05-20 via fitme-story PR #127 (MERGED per MEMORY.md) + FT2 #410, #411, #412 (MERGED). Source: ucc-passkey-auth-security-hardening-case-study.md frontmatter related_prs field. Status is in_progress in case study (kill_criteria_resolution is empty, pending T+7d evaluation 2026-05-27)."

- id: C-022
  internal_confidence: medium
  expected_auditor_finding: "Likely confirms the date from must-have-cadence-followups.md; auditor may flag as a forward-looking claim that cannot be verified from bundle"
  notes: "B11 calibration check scheduled 2026-05-22 per CLAUDE.md v7.9 section post-promotion calendar and MEMORY.md must-have-cadence-followups. This is today's date (2026-05-22) — the check is either in progress or just completed. File A should state 'B11 check date is 2026-05-22' as a declared calendar fact (T2), not as a completed-event claim."

- id: C-023
  internal_confidence: high
  expected_auditor_finding: "Likely confirms; 2026-05-27 date is both in CLAUDE.md post-promotion calendar and in the hardening case study kill_criteria"
  notes: "UCC B12 T+7d kill-criteria evaluation gated 2026-05-27 per CLAUDE.md 'Post-promotion calendar' entry and ucc-passkey-auth-security-hardening-case-study.md kill_criteria (3 metrics evaluated at T+7d). kill_criteria_resolution is empty at extraction time — this is an open evaluation item, not a completed one."

- id: C-024
  internal_confidence: medium
  expected_auditor_finding: "Likely confirms the 2026-05-28 gating; auditor may note this is a forward-looking gate not yet met"
  notes: "UCC Part 8 (passkey-only flip, dropping legacy basic-auth) is gated 2026-05-28+ on preconditions per MEMORY.md project_ucc_passkey_cutover_2026_05_16.md: 'Part 7 break-glass DEFERRED before 05-28; Part 8 gated 05-28+'. The specific preconditions are in the UCC passkey auth setup guide. At extraction time (2026-05-22), Part 8 has not shipped."

- id: C-025
  internal_confidence: high
  expected_auditor_finding: "Likely confirms; PR #298 is in the cross-repo-state-sync-impl-case-study.md related_prs frontmatter"
  notes: "v7.8.3 Phase 0 shipped 2026-05-11 via PR #298: CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT promoted to enforced (V2) + Mechanism E extended to .claude/logs/<feature>.log.json (V9) + make snapshot-phase Makefile target + scripts/snapshot-phase-completion.sh. CLAUDE.md and cross-repo state sync case study both confirm."

- id: C-026
  internal_confidence: high
  expected_auditor_finding: "Likely confirms 100% state_owner coverage; auditor may note it was a bulk backfill not organic adoption"
  notes: "state_owner field mandated at v7.8.3. Per L1 §17.2: state_owner adoption rate is 100.0% (25/25) on the v7.8-v7.9 cohort. Per L1 §18.1: ft2 cohort = 74, fitme-story = 1, total 75. The cross-repo state sync case study mentions '62 features backfilled' at Phase 2 ship — this was prior to extraction; total features at extraction is 75, all with state_owner set. L1 §18.1 notes the backfill is the cause of 100% rate, not organic adoption."

- id: C-027
  internal_confidence: high
  expected_auditor_finding: "Likely confirms; CLAUDE.md v7.8.3 Phase 0 paragraph states this explicitly"
  notes: "Mechanism E custom merge driver extended from its original scope (measurement-adoption-history.json + documentation-debt.json) to also cover .claude/logs/<feature>.log.json at v7.8.3 Phase 0. This is V9 from the v7.9 candidates docket. Source: CLAUDE.md 'Phase 0 promotes' + unclosable-gaps.md V9 entry."

- id: C-028
  internal_confidence: high
  expected_auditor_finding: "Likely confirms; cross-repo-state-sync-impl-case-study.md cites 63/63 and PR #299"
  notes: "D-3 unified cross-repo PR cite cache shipped 2026-05-11 via PR #299. Per CLAUDE.md v7.8.3 Phase 1 paragraph: 'closes BROKEN_PR_CITATION silent-skip on [fitme-story#N] cites + URL-form mis-routing; 63/63 retroactive cite validation'. The 63-feature count at Phase 1 ship vs 75 at extraction is explained by growth between Phase 1 (2026-05-11) and extraction (2026-05-22). Cross-repo state sync case study TL;DR corroborates '62 features' backfill in Phase 2 (state_owner), so Phase 1 cite validation likely covered 63 features at that point."

- id: C-029
  internal_confidence: high
  expected_auditor_finding: "Likely confirms; FT2-FH-001 is in the honesty ledger with full closure detail"
  notes: "FT2-FH-001 documents the v7.7 silent-pass on CACHE_HITS_EMPTY_POST_V6: gate had 0% effective coverage (43/46 state.json used 'created' not 'created_at'). Status: CLOSED in v7.8 via PRs #169/#173/#185-189/#192/#193. The ledger entry is immutable and append-only. Filed and closed at v7.8 bridge era."

- id: C-030
  internal_confidence: high
  expected_auditor_finding: "Likely confirms; FT2-FH-002 is in the honesty ledger with full closure detail"
  notes: "FT2-FH-002 documents the v7.8.3 PR-cache-staleness silent-pass: make integrity-check reported 35 findings (32x BROKEN_PR_CITATION + 2x PR_NUMBER_UNRESOLVED + 1x PHASE_LIE) — 100% false positives from empty .cache/gh-pr-cache.json. Status: CLOSED in v7.8.4 via scripts/ensure-pr-cache-fresh.py. Root cause: cache-layer assumed populated but had no non-empty guard. Filed and closed 2026-05-12."

- id: C-031
  internal_confidence: high
  expected_auditor_finding: "Likely confirms; FT2-FH-003 is in the honesty ledger — notable that it is a positive discipline entry, not a correction"
  notes: "FT2-FH-003 documents the v7.9 promotion as the first framework-version flip to use Mechanism A as a gate on its own promotion decision. This is NOT a correction entry — it records the discipline being codified. The 4-criterion checklist (coverage emitted, no false positives, no silent skips, reversibility) is recorded as the forward protocol. Filed 2026-05-21 at v7.9 ship."

- id: C-032
  internal_confidence: high
  expected_auditor_finding: "Likely confirms; ledger is append-only with monotonic FT2-FH-NNN numbering"
  notes: "The honesty ledger (docs/case-studies/framework-honesty-ledger.md) is the canonical record for known framework gaps + remediations. Pattern from curl monthly reports + Postgres release notes + Tailscale 'we got this wrong' sections. At extraction time, 3 entries exist (FT2-FH-001 through FT2-FH-003). The append-only + never-silently-edited property is verifiable from git log on that file."

- id: C-033
  internal_confidence: high
  expected_auditor_finding: "Likely confirms 52% on the v7.8-v7.9 cohort; auditor may flag that no cohort reaches 100%"
  notes: "Per L1 §17.2: cache_hits[] non-empty on v7.8-v7.9 cohort = 52.0% (13/25). This is the mandatory-from cohort (v6.0+). No post-v6 cohort reaches 100%. The v7.0-v7.4 cohort (n=2) is 0.0%. The v7.5-v7.7 cohort (n=8) is 62.5%. Data from state.json field scan at extraction. Note: the gate (CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT) is now ENFORCED — future completions should trend toward 100% on new features."

- id: C-034
  internal_confidence: high
  expected_auditor_finding: "Likely confirms 16.7% (1/6) on the v7.8-v7.9 cohort with KC set; auditor may flag 5 unresolved features with KC as a data-debt signal"
  notes: "Per L1 §17.2: kill_criteria_resolution is 16.7% (1/6) on v7.8-v7.9 cohort. The 5 features with kill_criteria set but no resolution are: ucc-passkey-auth-security-hardening (evaluation 2026-05-27), framework-v7-9-promotion (evaluation 2026-05-28), and 3 others. kill_criteria_resolution is only mandatory when current_phase=complete per FEATURE_CLOSURE_COMPLETENESS gate (enforced v7.9) — most of these features are in-progress, so the 16.7% rate reflects lifecycle stage, not systemic neglect. File A should note this caveat."

- id: C-035
  internal_confidence: high
  expected_auditor_finding: "Likely confirms the regression; auditor may investigate root cause (smaller denominator on v7.8-v7.9 vs v7.5-v7.7 might be part of the picture, but 16% vs 50% is a real regression)"
  notes: "Per L1 §17.2: cu_v2 schema-valid rates are v7.5-v7.7 = 50.0% (4/8) and v7.8-v7.9 = 16.0% (4/25). This is a genuine regression — the later cohort has a lower rate despite the gate existing. Absolute counts are equal (4 features each) but the denominator jumped from 8 to 25. The cu_v2 schema validation (CU_V2_INVALID gate) is a cycle-time check, not a write-time block on phase transitions — it flags but does not prevent advancement. CLAUDE.md 'Known Mechanical Limits' lists cu_v2 correctness as an unclosable gap (judgment-based)."

- id: C-036
  internal_confidence: high
  expected_auditor_finding: "Likely confirms 88%; auditor may note this reflects field introduction date, not systemic neglect"
  notes: "Per L1 §5: dispatch_pattern is missing on 66 of 75 features (88.0%). The field was introduced post-v6.0 and has not been backfilled for pre-v6 features. The 9 features with dispatch_pattern set span serial (3), subagent-driven serial (1), and 5 other single-entry variants. This is a structural data-coverage issue, not a product health signal. The claim in File A should include the caveat that the field's introduction date makes pre-v6 features 'missing by design.'"

- id: C-037
  internal_confidence: high
  expected_auditor_finding: "Likely confirms n=1 for fitme-story; auditor should flag that cross-repo analysis is statistically meaningless at n=1"
  notes: "Per L1 §18.1: fitme-story cohort = 1 feature (3d-interactive-framework-flow-diagram at prd phase). FT2 cohort = 74. The cross-repo comparison in L1 §18 is technically valid but carries near-zero statistical weight. The single fitme-story feature is at prd phase (no case study yet) — its low field-presence rates reflect lifecycle stage, not the repo's systematic quality. L1 §18.4 explicitly notes the re-evaluation threshold is ≥5 fitme-story features."

- id: C-038
  internal_confidence: medium
  expected_auditor_finding: "Likely confirms the 33.3% as plurality bucket; auditor may want to verify the v7.8-v7.9 bucket boundary definition"
  notes: "Per L1 §11: v7.8-v7.9 is the plurality framework_version bucket at 33.3% (25/75 features), overtaking v5.x at 26.7% (20/75). This reflects the accelerating framework build rate in 2026-Q2. The bucket boundary is author-chosen (L1 limitation L8). 'v7.8-v7.9' spans v7.8, v7.8.1 through v7.8.6, and v7.9 — a 5-month window collapsed into one bucket."
```
