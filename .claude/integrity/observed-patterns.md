# Observed Patterns Catalog — Data Integrity Framework

> Manifest of gate-firing patterns that operators must recognize before debugging.
> Each entry: trigger, why expected, signal-vs-noise rule, silence path, first observed.
>
> **When any framework gate produces a finding or advisory, CHECK THIS DOC FIRST.**
> If the pattern matches → apply the documented remediation. If no match → investigate,
> then add the new pattern to this catalog as the LAST step of the investigation.
>
> Established 2026-05-13 (PR #327 seeded the first entry; this doc extends to a full catalog).
> Preflight-loaded by `/pm-workflow` and surfaced via `make observed-patterns`.

---

## How to use this catalog

1. **Note the gate code** that fired (e.g., `BRANCH_ISOLATION_HISTORICAL`, `CACHE_HITS_AUTO_INSTRUMENTATION_INACTIVE`)
2. **Search this doc** for that code (Ctrl-F / `grep`)
3. **Match the trigger** to your situation — does the "why expected" line apply?
4. **Apply the remediation** documented in "Silence path" or "Distinguishing real signal"
5. **If no pattern matches** → you've found a new behavior. Investigate, fix or accept, **then document it as a new entry at the bottom of this file** before closing the session.

This catalog is append-only-by-default. Edits to existing entries are fine when the pattern's trigger conditions change post-fix, but the historical entry should stay (so future operators can see the framework's evolution).

---

## Section 1 — Gate-firing patterns (cycle-time + write-time)

Each entry follows the format:

```
### #N <GATE_CODE> — short description
**Trigger:** when this fires
**Why expected:** by-design / cleanup-artifact / silent-pass-then-fixed
**Distinguishing real signal:** how to tell artifact from real issue
**Silence path:** opt-out / exemption / fix
**First observed:** date + PR/incident
**Notes:** version added/fixed, related gates
```

---

### #1 `BRANCH_ISOLATION_HISTORICAL` — squash-merge + branch-cleanup artifact

**Trigger:** Cycle-time advisory fires when the integrity-check's git-log scan finds no `feature/*` or `chore/*` branch commits attributed to a feature's files.

**Why expected:** Squash-merge moves all file changes to a single new commit on `main`; the original branch's commits become unreachable post-deletion. Git history then shows the feature's file changes appearing first on `main`, with no branch attribution.

**Distinguishing real signal:**
- **Cleanup artifact (expected):** feature has `phases.merge.pr_number` in `state.json` that resolves to a squash-merged PR on GitHub with `head_ref` matching `feature/*` / `chore/*`. Audit trail is on GitHub.
- **Real signal (investigate):** feature has no PR linkage, OR PR's `head_ref` is `main` (work committed directly to main, bypassing branch isolation).

**Silence path:** Per-feature `state.json::isolation_opt_out: true` + `isolation_opt_out_reason: "<text>"`. **Do not silence blindly** — confirm cleanup-artifact via PR head_ref check first.

**First observed:** 2026-05-13 cleanup pass (FT2 -29 branches + fitme-story -17 remote branches). Advisory fired on 3 features shipped that week (`3d-interactive-framework-flow-diagram`, `cross-repo-state-sync-impl`, `hadf-phase2bis-replication`). All three confirmed cleanup-artifact.

**Notes:** v7.8.1 advisory. v7.9 may promote to enforced if calibration confirms. PR #327 documented the pattern; this catalog is the long-term home.

---

### #2 `CACHE_HITS_AUTO_INSTRUMENTATION_INACTIVE` — Mechanism C captured, writer-path manual

**Trigger:** Advisory fires when session ledgers attribute Read events to a feature but `state.json::cache_hits[]` is empty/absent.

**Why expected:** v7.8 Mechanism C captures session-level Read events automatically via `PostToolUse:Read` hook → `_session-*.events.jsonl`. The state.json writer-path remained manual (`scripts/log-cache-hit.py`) until v7.9 promotion. So the gap between "captured" and "persisted" is by-design in v7.8.x.

**Distinguishing real signal:**
- **Expected (v7.8.x):** feature is mid-workflow with active session ledger entries; `state.json::cache_hits[]` will only populate when writer-path is enforced (v7.9+).
- **Real signal (v7.9+):** post-promotion, both should populate. If still empty, Mechanism C dual-write failed.

**Silence path:** None needed in v7.8.x — advisory is informational. Post-v7.9 promotion: investigate dual-write failure.

**First observed:** 2026-05-02 (v7.8 PR-1 ship). Advisory wired in v7.8.3.

**Notes:** Will be re-classified once v7.9 ships the writer-path (FIT-83 promotion candidate). Pre-Mechanism-C features (`created_at < 2026-05-02`) are auto-exempt via `MECHANISM_C_SHIP_DATE` constant in `scripts/check-state-schema.py`.

---

### #3 `BRANCH_ISOLATION_VIOLATION` Mode B — silent-pass on infra-only commits (FIXED PR #317)

**Trigger:** Write-time gate fires on commits where staged files match infra-path globs (`.githooks/*`, `.github/workflows/*`, `scripts/*`, `.claude/skills/*`, `.claude/shared/*`, `CLAUDE.md`, `docs/architecture/*`, `Makefile`) AND branch is non-feature.

**Why expected:** v7.8.1 design. Framework infrastructure must NOT opt itself out of its own enforcement — `isolation_opt_out: true` is explicitly ignored for Mode B (infra override per Q3).

**Silent-pass period (pre-fix):** 2026-05-07 → 2026-05-12. Mode B + Mechanism A coverage write happened AFTER the "no state.json staged → early return" check. Infra-only commits triggered the early return → gate never ran → silent-pass. ~9 HADF Phase 2-bis commits affected during the window.

**Distinguishing real signal:**
- **Pre-PR #317 (silent-pass):** infra-only commit landed without Mode B firing — only visible after the fact via missing gate-coverage.jsonl entries.
- **Post-PR #317 (fixed):** Mode B fires on every infra-path commit; gate-coverage.jsonl entry confirms.

**Silence path:** None — Mode B is non-blocking advisory in v7.8 but should always emit telemetry. If staging-mode silent on an infra-only commit post-PR #317, investigate `scripts/check-state-schema.py main()` ordering.

**First observed:** 2026-05-12 (root-cause identified during infra-master-plan session). Fixed PR #317 commit `6c52e92`.

**Notes:** v7.8.5 added 2 regression tests. Lesson: gate execution order matters — coverage instrumentation must happen BEFORE any early-returns.

---

### #4 `BRANCH_ISOLATION_VIOLATION` Mode C — stale state.json branch field

**Trigger:** Write-time gate fires when staged state.json mutates `current_phase` AND current branch != state.json's declared `branch` field.

**Why expected:** Stale state.json branch field after worktree migration, rebase, or branch rename. The actual worktree may be correct.

**Distinguishing real signal:**
- **Artifact:** `state.json::branch` is stale; correct branch is the current HEAD.
- **Real signal:** working on main when a feature/chore branch was required.

**Silence path:** Per-feature `state.json::isolation_opt_out: true` + reason. Examples in repo: `case-study-comparison-table` (nested sub-feature), `code-connect-automation` (cross-repo chore), `fitme-story-public-enhancements` (rollup with per-task branches).

**First observed:** 2026-05-07 (v7.8.1 ship).

**Notes:** Mode C honors per-feature exemption. Mode B does NOT (per Q3).

---

### #5 `ISOLATION_OPT_OUT_REASON_MISSING` — opt-out without justification

**Trigger:** Write-time gate fires when state.json has `isolation_opt_out: true` but `isolation_opt_out_reason` is empty/missing.

**Why expected:** Enforcement gate. Exemptions require written justification (auditability).

**Distinguishing real signal:** Always real — fill in the reason or remove the opt-out.

**Silence path:** Set `isolation_opt_out_reason` to a non-empty string (e.g., "Sub-feature within stress-test rollup", "Cross-repo tooling chore", "Metadata-only updates on main"), OR remove `isolation_opt_out: true`.

**First observed:** 2026-05-07 (v7.8.1 ship).

---

### #6 `FEATURE_CLOSURE_COMPLETENESS` — missing required frontmatter on `current_phase=complete`

**Trigger:** Write-time gate fires on `current_phase=complete` transitions when required case-study frontmatter fields are missing (7 fields: `date_written`/`date`, `dispatch_pattern`, `success_metrics`/`primary_metric`, `kill_criteria`, `framework_version`, `work_type`, `tier_tags_present`), OR `kill_criteria_resolution` is missing when `kill_criteria` is set (Q7), OR bidirectional PR-list parity fails (Q6).

**Why expected:** Enforcement gate — completion-time integrity check. 2026-05-07 reconcile session surfaced 5 silently-missing fields across 4 shipped features (UCC, import-training-plan, framework-story-site, push-notifications-v2).

**Distinguishing real signal:** Always real signal in v7.8.1 advisory mode. v7.9 promotion will enforce.

**Silence path:** Populate the missing fields before staging the completion commit, OR set `case_study_type: "no_case_study_required"` + `case_study_exempt_reason` for legitimate exemptions. Case-study `pr_citation_exempt` frontmatter overrides PR-parity check.

**First observed:** 2026-05-07 (v7.8.1 ship).

**Notes:** Pairs with cycle-time mirror to catch `--no-verify` bypasses.

---

### #7 `CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT` (formerly `CACHE_HITS_EMPTY_POST_V6`) — schema-drift silent-pass (FIXED v7.7 honesty fixes)

**Trigger:** Gate fires when feature `created_at ≥ 2026-04-16` (post-v6 ship) AND `current_phase=complete` AND `cache_hits: []`.

**Why expected:** v7.7 enforcement. Pre-Mechanism-C features (`created_at < 2026-05-02`) auto-exempt.

**Silent-pass period (pre-fix):** 2026-04-27 → 2026-05-01. Gate read `created_at` field but 43/46 state.json files used legacy `created` key → gate had 0/46 effective coverage. Textbook silent-pass: gate "ran" but never found a feature to test.

**Distinguishing real signal:** Post-v7.7 honesty fixes (PR #169, 2026-05-01), gate dual-reads `created` ∪ `created_at` for the migration window. If gate fires on a feature post-2026-05-01, the cache_hits[] really is empty.

**Silence path:** Manually log Reads via `scripts/log-cache-hit.py` until v7.9 enforces auto-dual-write.

**First observed:** 2026-04-27 (v7.7 ship). Silent-pass identified 2026-04-30 audit. Fixed PR #169 (2026-05-01).

**Notes:** FT2-FH-001 ledger entry. Renamed v7.8.3 from `CACHE_HITS_EMPTY_POST_V6` to `CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT`. v7.8 defensive dual-read code lives in `scripts/check-state-schema.py`. **Lesson: before claiming a gate "100% gated," verify gate predicate scans the corpus through the gate's exact read path.**

---

### #8 `TIER_TAG_LIKELY_INCORRECT` — heuristic over-triggers on section headers + units (NARROWED v7.8.4)

**Trigger:** Advisory fires on quantitative claims in case studies when claimed tier tag (T1/T2/T3) appears mismatched via regex.

**Why expected:** Heuristic cannot verify semantic correctness; only catches obvious false-positive shapes. At v7.7 baseline, kill criterion 2 fired at 100% FP rate (n=1) on `Tier 3.2` section header — gate shipped permanent-advisory by pre-registered policy.

**Pre-v7.8.4 FPs:** (a) section headers like `"Tier 3.2 — documentation debt"` parsed as quantitative claims, (b) word-boundary issues (`h` in `hook`, `s` in `schema`), (c) intervening tier markers.

**Distinguishing real signal:** Post-v7.8.4, advisory's signal-to-noise is significantly higher. v7.8.4 narrowings: `is_target_or_kill_claim()` filter, `\b` word boundary on units, `INTERVENING_TIER_RE` skip.

**Silence path:** Case-study annotation `tier_tags_present: false`. OR pin known-correct T1 values in `.claude/shared/case-study-t1-references.json` (v7.8.4 introduced this reference ledger).

**First observed:** 2026-04-27 (v7.7 M3). Narrowed 2026-05-12 (v7.8.4 ship).

**Notes:** Pre-v7.8.4: 4-6 advisories on legitimate claims. Post-v7.8.4: 0 advisories. Semantic-correctness gap remains Class B (not automatable).

---

### #9 `SCHEMA_DRIFT_LEGACY_CREATED` — legacy `created` key (FIXED v7.7 honesty)

**Trigger:** Write-time gate fires when state.json uses legacy `"created"` key instead of canonical `"created_at"`.

**Why expected:** Forward-only enforcement post-v7.7 schema migration. 43/46 features pre-v7.7 used legacy key.

**Distinguishing real signal:** Always real — fix the schema. v7.7 PR #169 migrated all 43 files; new files since 2026-05-01 use canonical key.

**Silence path:** Migrate the state.json (single-line rename). No exemption — schema drift is auditable bug.

**First observed:** 2026-05-01 (PR #169, root cause of `CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT` silent-pass).

**Notes:** Companion gate to `SCHEMA_DRIFT_LEGACY_PHASE` (v7.5 era). **Lesson: schema-renames need write-time gates to prevent re-introduction.**

---

### #10 `FRAMEWORK_VERSION_FORMAT` — unprefixed numeric values

**Trigger:** Write-time gate fires when `framework_version` field is present but doesn't match `^(pre-)?v\d+\.\d+$` (e.g., `"7.5"` instead of `"v7.5"`).

**Why expected:** Format-only enforcement (if set, must be canonical). Presence-required deferred — 39 features still have field absent (grandfathered pre-v6).

**Distinguishing real signal:** Always real format issue. Backfill to canonical `vX.Y` with no transition.

**Silence path:** Update the field to canonical format. Absence is grandfathered — not a violation.

**First observed:** 2026-04-27 (v7.7 M5 front-matter backfill). 6 unprefixed values backfilled at v7.7 PR #169 companion.

**Notes:** Policy decision: format-only enforcement avoids manufacturing history by backfilling absent timeline data without verification.

---

### #11 `STATE_OWNER_*` (MISSING / INVALID / LOCATION_MISMATCH) — cross-repo schema (v7.8.3)

**Trigger:**
- `STATE_OWNER_MISSING` — required field absent
- `STATE_OWNER_INVALID` — value not in `{"ft2", "fitme-story"}`
- `STATE_OWNER_LOCATION_MISMATCH` — file location doesn't match `state_owner` value

**Why expected:** v7.8.3 introduced cross-repo state ownership. All 62 features backfilled with `state_owner: "ft2"` in Phase 2.

**Known false-positive (FIXED inline at v7.8.3 Phase 2 Task 2.4):** Initial regex `re.search(r'/fitme-story\b', abs_path)` matched feature names like `fitme-story-design-system-p2-cleanup` even when path didn't contain `/fitme-story/`. Fixed by requiring full path segment `/fitme-story/`. Gate self-caught the bug on the commit that implemented it.

**Distinguishing real signal:** Post-v7.8.3 Phase 2, regex requires full path segment. False positives extremely rare.

**Silence path:** Set `state_owner` correctly; for reverse-sync mirrors, set `state_owner_sync_origin` ending in `-reverse` to exempt LOCATION_MISMATCH.

**First observed:** 2026-05-11 (v7.8.3 Phase 2 ship + inline regex fix).

**Notes:** **Lesson: test gate predicates on your own code changes first.** Framework infrastructure caught by breaking itself during implementation.

---

### #12 `PR_CACHE_STALE` (v7.8.4) — empty/stale cache → cascading false positives

**Trigger:** Auto-refresh advisory fires when `.cache/gh-pr-cache.json` is empty, missing, or >24h old.

**Why expected:** Cache-dependent gates (`BROKEN_PR_CITATION`, `PR_NUMBER_UNRESOLVED`) need fresh data. Pre-v7.8.4 contract was "cache exists" not "cache is fresh AND populated."

**Incident 2026-05-12 morning:** Empty cache caused **33 false-positive findings** (32× `BROKEN_PR_CITATION` + 2× `PR_NUMBER_UNRESOLVED` + 1× `PHASE_LIE`). Every cited PR was real; cache just wasn't populated.

**Distinguishing real signal:** Post-v7.8.4, auto-refresh via `scripts/ensure-pr-cache-fresh.py` runs before every `make integrity-check`. If `BROKEN_PR_CITATION` finds still appear in volume, check `gh` CLI auth + GitHub API quota.

**Silence path:** Run `make refresh-pr-cache` manually. OR `GATE_COVERAGE_LEDGER_DISABLED=1 make integrity-check` to skip cache-dependent gates entirely.

**First observed:** 2026-05-12 morning (v7.8.4 session start, FT2-FH-002 ledger entry). Fixed PR #314.

**Notes:** **Lesson: cache layers need an `is_cache_usable()` check, not just "cache exists."**

---

### #13 `BROKEN_PR_CITATION` — graceful fallback when `gh` unavailable

**Trigger:** Cycle-time check fires when case study cites PR via `PR #NNN` or `pull/NNN` that doesn't resolve via `gh pr list`. Skipped gracefully if `gh` CLI unavailable.

**Why expected:** GitHub API is external; framework gracefully degrades to "citation unknown" rather than halt.

**Distinguishing real signal:**
- **Skipped (expected if no `gh`):** Mechanism A telemetry shows `skipped: unavailable-cli`. Not a gate failure.
- **Failed (real):** `gh` available + cache fresh + PR really doesn't resolve. Fix the citation OR add to `pr_citation_exempt` frontmatter.

**Silence path:** Case-study `pr_citation_exempt: [{pr_number, reason}]` frontmatter for legitimate citations to deleted/renamed PRs.

**First observed:** 2026-04-24 (v7.5 ship).

**Notes:** Narrow regex by design — avoids conflating issue citations (`issue #NNN`) with PR citations. Files under `docs/case-studies/meta-analysis/` excluded since they discuss citations rather than make them.

---

### #14 `CASE_STUDY_MISSING_TIER_TAGS` — forward-only on case studies dated ≥ 2026-04-21

**Trigger:** Cycle-time check fires when case study dated on or after 2026-04-21 contains no `T1`/`T2`/`T3` tier tags. Severity: WARN.

**Why expected:** Tier 2.3 data-quality-tiers convention shipped 2026-04-21. Forward-only enforcement.

**Distinguishing real signal:** Pre-convention case studies (date < 2026-04-21) auto-exempt per forward-only policy. Files without extractable `**Date written:**` header are also skipped.

**Silence path:** Add at least one T1/T2/T3 tag to the case study. Per convention: every quantitative metric must carry its tier.

**First observed:** 2026-04-24.

---

### #15 `PARTIAL_SHIP_TERMINAL` — decision fork on completion

**Trigger:** Cycle-time check fires when state.json has `partial_ship: true` AND `current_phase=complete`.

**Why expected:** Decision fork (not strict block) — operator must EXPLICITLY pick "downgrade phase" or "remove partial_ship flag" before completion.

**Distinguishing real signal:** Always real — make the choice.

**Silence path:** Either (a) remove `partial_ship: true` (the feature truly completed), OR (b) downgrade `current_phase` to non-terminal AND add `partial_ship_terminal_disposition: "downgrade: vX deferred"`.

**First observed:** 2026-04-25 (v7.6 ship).

**Notes:** Pattern: framework requires explicit commitment statements rather than silent schema mutations. Same philosophy as `kill_criteria_resolution`.

---

### #16 `CASE_STUDY_MISSING_FIELDS` — required frontmatter validation

**Trigger:** Cycle-time + write-time check fires when case study frontmatter is missing required fields.

**Why expected:** v7.7 added 4 frontmatter fields; v7.8.1 added 3 more. Backfill complete for older case studies via `case_study_type: "pre_pm_workflow_backfill"` exemption.

**Distinguishing real signal:** Always real — fill in the fields or apply the appropriate `case_study_type` exemption.

**Silence path:** `case_study_type: "pre_pm_workflow_backfill"` / `"roundup"` / `"no_case_study_required"` / `"framework_meta_retroactive"` per applicability.

**First observed:** 2026-04-27 (v7.7 ship).

---

### #17 `CU_V2_INVALID` — schema-only check (presence, not magnitude)

**Trigger:** Write-time + cycle-time gate fires when `cu_v2` field present but schema-invalid: missing factors (`complexity`, `blast_radius`, `novelty`, `verification_difficulty`), factor outside [0, 1], `total` not within tolerance 0.01 of `sum(factors)`, OR `tier_class` not in `{A_high, B_medium, C_low}`.

**Why expected:** v7.7 M1/T7. Pre-v6 features without `cu_v2` are exempt.

**Distinguishing real signal:** Always real schema violation if cu_v2 set. Note: this check does NOT validate magnitude correctness (judgment-based, Class B gap).

**Silence path:** Fix the schema. Magnitude correctness is permanently unautomatable.

**First observed:** 2026-04-27 (v7.7 ship).

---

### #18 `STATE_NO_CASE_STUDY_LINK` — terminal phase requires case_study or exemption

**Trigger:** Cycle-time + write-time gate fires when `current_phase=complete` AND no `case_study` / `parent_case_study` / `case_study_type` link.

**Why expected:** Enforcement. Audit trail required for every completed feature.

**Distinguishing real signal:** Always real — link the case study or apply the appropriate exemption.

**Silence path:** Add `case_study: "<path>"` OR `parent_case_study: "<path>"` (for sub-features) OR `case_study_type: "no_case_study_required"` + `case_study_exempt_reason`.

**First observed:** 2026-04-27 (v7.7 ship).

---

### #19 `MECHANISM_C_SHIP_DATE` auto-exemption

**Trigger:** Multiple gates respect `created_at < "2026-05-02"` as pre-Mechanism-C auto-exemption.

**Why expected:** Mechanism C (`PostToolUse:Read` hook) shipped 2026-05-02. Features created before that date had no auto-instrumentation infrastructure. Empty `cache_hits[]` is "mechanism unavailable," not adoption failure.

**Distinguishing real signal:** Check `created_at`. If ≥ 2026-05-02, expect Mechanism C to have instrumented the feature. If < 2026-05-02, auto-exempted.

**Silence path:** No operator action — gate predicates auto-exempt via embedded constant.

**First observed:** 2026-05-02 (v7.8 PR-1 design).

**Notes:** **Lesson: reframe adoption-debt findings when the mechanism did not yet exist.** Don't manufacture violations against features that predate the gate's mechanism.

---

### #20 `GATE_COVERAGE_ZERO` — meta-check for silent-pass detection (advisory, v7.9 enforcement)

**Trigger:** Cycle-time advisory fires when any gate's `gate-coverage.jsonl` entry shows `checked: 0` for 7+ consecutive days.

**Why expected:** Silent-pass class detection. Reference: `CACHE_HITS_EMPTY_POST_V6` at v7.7 showed `candidates=47, checked=0, skipped=47` — gate "ran" but predicates never matched.

**Distinguishing real signal:**
- Predicate too strict → fix to match real corpus
- Data schema drifted → dual-read or migrate (like v7.7 schema-drift fix)
- Gate is correctly never-fires by design → document as "advisory permanent"

**Silence path:** Remediation depends on root cause. v7.9 candidate F17: nightly `gate-last-fired.json` materialization for O(1) detection.

**First observed:** 2026-05-03 (v7.8 PR #187, Mechanism A infrastructure).

**Notes:** Mechanism A is the "coverage audit for the gates themselves." Catches silent-pass class.

---

### #21 `case_study_type` exemption tags — bypass scope

| Tag | Bypasses | Applicable to |
|---|---|---|
| `pre_pm_workflow_backfill` | Phase-lie + no-cs-link + sub-phase vocab | Features pre-v7.6 (`authentication`, `data-sync`, `design-system-v2`, etc.) |
| `roundup` | Single-feature no-cs-link | Multi-feature rollups (`six-features-roundup`, etc.) |
| `framework_meta_retroactive` | Phase-lie + no-cs-link + sub-phase vocab | Framework version meta-features (v5.0 SoC, v5.2 Dispatch, v7.0 meta-analysis, v7.1 integrity cycle) |
| `no_case_study_required` | All case-study-related checks | Operator-driven decisions (`ios-code-connect`, `app-store-assets`) |

**Why expected:** Forward-only policy enables retrofitting historical features without manufacturing v7+ measurement standards.

**Silence path:** Apply the appropriate tag in `state.json::case_study_type`. Must pair with `case_study_exempt_reason` field documenting the choice.

**First observed:** 2026-04-25 (v7.6 introduction). `framework_meta_retroactive` added v7.8.

**Notes:** Going forward (v7.9+), framework versions cannot use `framework_meta_retroactive` — full chain-of-custody required.

---

### #22 v7.5 pipeline regression test decay — late-discovered fixture rot

**Trigger:** `scripts/test-v7-5-pipeline.sh` fixtures fail because new gates require fields the fixtures don't have.

**Why expected:** Pre-v7.7, fixtures didn't include v7.7-required gates (`STATE_NO_CASE_STUDY_LINK`, `CASE_STUDY_MISSING_FIELDS`). Test broke silently because pipeline only ran on framework-PR opens, not nightly.

**Distinguishing real signal:** Real maintenance gap. Fix fixtures + ensure pipeline runs nightly.

**Silence path:** Update fixtures: add `case_study_type: "no_case_study_required"` + `case_study_exempt_reason` to `state.json.minimal`. v7.8 candidate F16: add to CI nightly.

**First observed:** 2026-05-01 (v7.7 honesty fixes near-miss #3, root cause pre-v7.7).

**Notes:** **Lesson: regression test fixture rot is a silent-pass class.** CI should fail framework-expansion PRs that leave `test-v7-5-pipeline.sh` failing.

---

### #23 `.gitignore` blocks Mechanism A / Mechanism C remote-agent visibility

**Trigger:** Cloud agent checkouts have no `.claude/logs/gate-coverage.jsonl` or `_session-*.events.jsonl` — both gitignored.

**Why expected:** Per-developer local data. But blocks remote agent's ability to verify ≥7 days of data for v7.9 promotion decision.

**Distinguishing real signal:** Mid-review, you realize the remote agent can't see raw ledgers → invisible to cloud audit.

**Silence path:** Commit periodic snapshots to non-gitignored paths. Example: `.claude/shared/gate-coverage-snapshot-2026-05-13.jsonl` shipped via PR #326 for T7.9.0 routine.

**First observed:** 2026-05-09 (advisory-calibration review). Re-surfaced 2026-05-13 (T7.9.0 routine setup).

**Notes:** **Lesson: gate-coverage and session-ledger data sources MUST have committed summaries if remote agents need to evaluate promotion criteria.** v7.9.1 candidate F-snapshot-gate-coverage proposes Makefile target.

---

### #24 Field-rename silent-pass in a READER/INDEX (measurement layer) — generalization of #7/#9

**Trigger:** A report, index, or meta-check reads a state/ledger field under one name while the producer writes it under a *different* name. No gate fires; the metric silently under- or mis-counts. Distinct from #7/#9 (which were `state.json` write-time gates reading the renamed field) — this is the same bug class in the *measurement/observability* layer, where there is no failing gate to surface it.

**Why expected:** schema-drift. A field is renamed/forked (`created`→`created_at`; top-level `cu_v2` object vs legacy `complexity.cu_version`; coverage rows keyed `timestamp` vs the W9 hook's `ts`) but only one producer/consumer is updated. The two representations co-exist and are often nearly disjoint, so the reader sees ~half the data and reports it as truth.

**Distinguishing real signal:** a coverage/adoption number that "feels low," OR two field shapes in the corpus where `grep -l '"new_field"'` and `grep -l '"old_field"'` return nearly-disjoint sets. Confirm by counting both: if `READ-field` count ≪ `WRITTEN-field` count, the reader is on the wrong field.

**Silence path:** make the reader accept BOTH representations (`d.get("new") or d.get("legacy")`), add a unit test pinning both, and prefer canonical going forward. NOT a per-feature exemption — it's a one-line reader fix.

**First observed:** 2026-06-10 audit — `measurement-adoption-report.py::has_cu_v2` read only legacy `complexity.cu_version` (15 feats) not canonical top-level `cu_v2` (12 feats), halving adoption (fixed PR #687); `refresh-gate-last-fired.py` read only `timestamp`, dropping 30 `w9.auto_isolate` rows keyed `ts` (fixed PR #688). Predecessor incident: `created`/`created_at` `CACHE_HITS_EMPTY_POST_V6` 0%-coverage (#7/#9, 2026-05-01).

**Notes:** v7.10. **Lesson: when you rename or fork a field, grep EVERY reader (`grep -rn '.get("<oldname>"' scripts/`) in the same change.** Related: #7, #9, #20 (the 3-cycle-time-check coverage gap was closed alongside this — `GATE_COVERAGE_ZERO` gained a 0-candidate mis-wire detector + the three cycle-time checks `BROKEN_PR_CITATION` / `CASE_STUDY_MISSING_TIER_TAGS` / `PATTERN_SKILL_UNMAPPED` now emit Mechanism A coverage so reader/writer drift is itself observable).

---

### #25 Derived index rebuilt from a gitignored session-local source regresses when a thin session commits it — overwrite-vs-union

**Trigger:** A *committed* artifact is **derived** from a **gitignored, session-local** source, and the producer **overwrites** it on each run. A fresh clone / isolated worktree has a thin (or empty) copy of the source, so when that session runs the producer and commits, the artifact **shrinks** — dropping entries and resetting counts an earlier, fuller session recorded. No gate fires (the producer "succeeded"); the loss is silent. The measurement-layer sibling of #24 — there a reader read the wrong field; here a producer overwrites accumulated history with a partial view.

**Why expected:** the source-of-truth stream is gitignored to avoid churn (e.g. `.claude/logs/gate-coverage.jsonl`), so the committed *index* (`.claude/shared/gate-last-fired.json`) is the only durable record — yet the producer treats the local stream as authoritative and clobbers the index.

**Distinguishing real signal:** the committed index's entry count drops across commits with no corresponding source removal; the producer's metadata shows a low `source_rows_read` (e.g. 12) right after a commit that previously read thousands. Confirm: `git log -p <index>` shows a sudden shrink authored by a fresh-worktree / CI session.

**Silence path:** the producer **union-merges** with the existing committed artifact instead of overwriting — counters take `max` (high-water mark), `first_seen_at` takes `min`, `last_*_at` take `max`, and entries present only in the committed artifact are **carried over** (never dropped). Provide a `--rebuild` escape hatch for intentional resets. NOT "version the noisy raw stream" — guard the producer.

**First observed:** 2026-06-16 — PR #745 rebuilt the F17 index from a 12-row session log → committed index regressed **25 gates → 8**, dropping all soak/enforced-gate telemetry (`PLATFORMS_TESTED`, `BRANCH_ISOLATION_VIOLATION`, `FEATURE_CLOSURE_COMPLETENESS`). Fixed PR #749 (`refresh-gate-last-fired.py` union-merge default + 5 tests; index restored to 26 gates).

**Notes:** v7.10. Sibling of #24 (reader/source coupling) + #23 (`.gitignore` blocks remote-agent visibility — same root: gitignored telemetry). **Lesson: a committed artifact derived from a gitignored source must merge, never overwrite.**

---

## Section 2 — Workflow / operational patterns

Non-gate patterns: situations where operator action (or inaction) causes confusion.

### W1 — SSH signing requires loaded agent before headless commits

**Pattern:** `git config commit.gpgsign=true` + `gpg.format=ssh` configured BUT `ssh-add -l` shows "no identities" → every commit attempt prompts for SSH key passphrase, fails non-interactively with `exit 128: fatal: failed to write commit object`. `ssh-keygen -Y sign` hangs silently in non-interactive shells.

**Distinguishing real signal:** Always operational — run `ssh-add ~/.ssh/id_ed25519` to cache key in ssh-agent. Verify with `ssh-add -l` showing fingerprint.

**Silence path:** Pre-flight check `ssh-add -l` before any planned Claude commits. Reload when session starts on a fresh terminal.

**First observed:** 2026-05-13 morning (during T7.9.0 seed-commit attempts). Documented in `feedback_ssh_signing_headless_shell.md`.

---

### W2 — Publish verbatim, then remediate

**Pattern:** First-version artifacts (case studies, audit reports, research dossiers) should be published as-written and corrected in subsequent commits/PRs, NOT silently edited.

**Why expected:** Audit-trail integrity. Edit history preserves the "we knew X but then found Y" learning curve.

**Silence path:** Never silently overwrite published artifacts. Always create a corrective addendum or new section ("Correction Note", "§99 Correction").

**First observed:** Documented in `feedback_publish_verbatim_then_remediate.md`.

---

### W3 — Check CI before local-build panic

**Pattern:** When local `xcodebuild` or `make` fails with confusing errors, check CI status FIRST. CI may be green; the issue is local (xcode version, simulator state, SPM cache).

**Silence path:** `gh run list --branch <branch> --limit 1` before deep debugging.

**First observed:** Documented in `feedback_check_ci_before_local_build_panic.md`.

---

### W4 — No auto-merge without explicit approval

**Pattern:** Even when all CI checks pass, do NOT auto-merge a PR unless the user explicitly approves. Squash-merge timing affects integrity-cycle calendars + measurement windows.

**Silence path:** Always confirm before `gh pr merge`. Surface the PR + checks + impact, then wait.

**First observed:** Documented in `feedback_no_auto_merge_without_approval.md`.

---

### W5 — No destructive operations without approval

**Pattern:** Branch deletion, worktree removal, file deletion, force-push — all require explicit user approval. Don't proactively clean.

**Silence path:** List + propose, then wait.

**First observed:** Documented in `feedback_no_deletion_without_approval.md`.

---

### W6 — Measurement case-study impartiality

**Pattern:** When measuring framework adoption metrics, treat all features uniformly. Don't selectively backfill or exempt features that would "look good" for adoption stats.

**Silence path:** All-or-none backfill batches. Document any exemption with explicit reason.

**First observed:** Documented in `feedback_measurement_case_study_impartiality.md`.

---

### W7 — Approval gates are multi-part

**Pattern:** A user "approval" of one step (e.g., "merge this PR") doesn't carry over to subsequent destructive steps (e.g., "delete the branch"). Each is a separate approval.

**Silence path:** Confirm each destructive step independently.

**First observed:** Documented in `feedback_approval_gates_are_multi_part.md`.

---

### W8 — External audit status is a UI marker

**Pattern:** "Audit status: pass" on the framework-health page is a UI signal, not a gate that blocks merges. Don't treat it as enforcement.

**First observed:** Documented in `feedback_external_audit_status_is_ui_marker.md`.

---

### W9 — Branch drift from concurrent-session `git checkout` collision (DETECTED + REAL-TIME ALERTED)

**Pattern:** Your session creates a chore/feature branch and starts work. Between tool calls, ANOTHER concurrent Claude session running in the **same** working directory executes `git checkout <other-branch>`. Git's working tree has a single HEAD, so YOUR session's HEAD flips silently too. Your next `git commit` lands on the wrong branch (the one the other session selected), not the one you intended.

**Symptom signatures (any one is sufficient):**
- `git log --oneline -1` after a commit shows it landed on a branch you don't recognize as yours this session.
- `gh pr create` errors with "head branch \"main\" is the same as base branch \"main\", cannot create a pull request" because gh's default `--head` resolution disagrees with your intended branch.
- The `gh pr merge` output says "Branch: main" but your next `git status` shows you on a `feature/<something-else>` branch.
- You ran `git checkout main` minutes ago, did NOT run another checkout, but `git branch --show-current` now reports a different branch.

**Distinguishing real signal:** Always real. There is no "false positive" interpretation — if HEAD changed and you did NOT run `git checkout` / `git switch` / `git branch -b` in YOUR Bash calls, another process flipped it. The only ambiguity is whether the other process was a concurrent Claude session OR a manual operator `git` command from a different shell.

**Detection — real-time alert (added 2026-05-13, this session):**

Every `PostToolUse:Bash` hook now invokes [`scripts/check-branch-drift.py`](../../scripts/check-branch-drift.py), which:

1. Records the current branch in `.claude/_session-state/<CLAUDE_SESSION_ID>-branch.txt` on first invocation
2. On every subsequent Bash, re-reads current branch + compares to recorded value
3. If they differ → emits a LOUD warning to stderr (surfaced back to the assistant via tool output):

   ```text
   ⚠️  BRANCH DRIFT DETECTED (W9 pattern)  ⚠️
      Expected branch: <previous>
      Current branch:  <new>

      Cause: another concurrent Claude session likely ran `git checkout`
      in this same working directory, flipping HEAD.

      Resolution:
      1. STOP — do not commit unless you intended this branch.
      2. To recover: git checkout <expected>
         If you have uncommitted work: git stash push -u first
         If you have committed on the wrong branch: cherry-pick to <expected>

      Full playbook: .claude/integrity/observed-patterns.md (W9)
   ```

4. The recorded baseline is updated to the NEW branch — so the warning fires ONCE per drift event, not on every subsequent Bash.

**Silence + bypass:**
- Disable temporarily: `CLAUDE_W9_DISABLE_DRIFT_CHECK=1` in env
- After confirming the drift was intentional (e.g., YOU ran `git checkout`): the warning fires once, then quiets down because state file is updated
- Permanently disable: remove the `Bash` matcher block from `.claude/settings.json::hooks.PostToolUse`

**Recovery playbook (when alert fires):**

```bash
# STEP 1 — STOP. Do not commit unless you intended to be on this branch.

# STEP 2 — Inspect the situation:
git status              # what's in the index?
git log --oneline -3    # what's the recent history?

# STEP 3a — If you have UNCOMMITTED work:
git stash push -u -m "wip-recovery-$(date +%Y%m%d-%H%M)"
git checkout <expected>
git stash pop           # OR leave stashed if work belongs on the other branch

# STEP 3b — If you ALREADY committed on the wrong branch:
# Find your commit SHA via: git log --oneline -1
git checkout <expected>
git cherry-pick <wrong-branch-commit-SHA>
# Optionally reset the wrong branch to drop your commit:
git branch -f <wrong-branch> <wrong-branch>~1

# STEP 4 — Push + open PR with explicit --head to bypass any gh default mismatch:
git push -u origin <expected>
gh pr create --head <expected> --base main --title "..." --body "..."
```

**Prevention — strongly recommended for multi-agent operators:**

The ONLY robust prevention is to give each concurrent session its own git worktree. Sharing one working directory across N concurrent Claude sessions is a footgun.

```bash
# Each agent session does this on startup instead of working in the shared tree:
git worktree add ../FitTracker2-<unique-task-slug>
cd ../FitTracker2-<unique-task-slug>
# Now your HEAD is independent of the main tree's HEAD
```

The framework already supports this via `scripts/create-isolated-worktree.py` (used by `BRANCH_ISOLATION_VIOLATION` Mode C auto-isolation). Multi-agent operators should make worktree creation the default for any session that intends to commit.

**Drift-triggered auto-isolation upgrade (2026-06-06, feature `w9-drift-triggered-auto-isolation`, Phase 1):**

W9 is no longer detection-only. When the hook detects drift AND the working tree has uncommitted work, it now **acts** (or offers to act):

- **Default (advisory):** prints the exact pre-filled isolation command + emits a `w9.auto_isolate` Mechanism A `offer` row. No mutation.
- **Opt-in (`CLAUDE_W9_AUTO_ISOLATE=1`):** auto-dispatches [`scripts/w9_auto_isolate.py`](../../scripts/w9_auto_isolate.py), which **atomically** moves the uncommitted work into the active feature's own worktree: `stash -u → create/adopt worktree → stash apply → verify tree digest → drop stash`. The stash is NEVER dropped until the worktree apply is verified, so uncommitted work is recoverable at every step (PRD guardrail GR4 / KC3). A lock at `.claude/_session-state/w9-isolate.lock` prevents two isolations racing (the self-race risk).
- **Honored escape hatches:** `state.json::isolation_opt_out` (warn-only) and the existing `CLAUDE_W9_DISABLE_DRIFT_CHECK=1`.
- **Status readout:** `make w9-isolation-status` summarizes recent drift events, isolations, offers, and the S2 false-trigger rate.

Ships **advisory-first**; promotes to default-act at T+7d once the false-trigger rate calibrates.

**Phase 2 — concurrency-proactive (2026-06-06, ADVISORY):** a `PostToolUse:Edit|Write` hook ([`scripts/w9_concurrency_check.py`](../../scripts/w9_concurrency_check.py)) fires once per session on the first edit and checks [`agent-leases.json`](../shared/agent-leases.json) for another **live** lease (TTL-fresh `last_heartbeat`) via `another_session_live()`. If concurrency is detected and the session isn't already isolated, it surfaces a concurrency advisory + emits a `w9.auto_isolate` `concurrency_offer` row — but does **not** act unless BOTH `CLAUDE_W9_AUTO_ISOLATE=1` and `CLAUDE_W9_CONCURRENCY_ENFORCE=1` are set. Stale leases (heartbeat > TTL) are treated as absent (safety valve against a crashed session's lingering lease). Runs a v7.9-style advisory→enforced calibration before the enforce flag defaults on (T+14d) — see [`calibration.md`](../features/w9-drift-triggered-auto-isolation/calibration.md). Disable: `CLAUDE_W9_DISABLE_CONCURRENCY_CHECK=1`.

Full chain: [`.claude/features/w9-drift-triggered-auto-isolation/`](../features/w9-drift-triggered-auto-isolation/) (research + PRD + integration-spec + calibration).

**First observed:** 2026-05-13 across three separate sessions today (analytics spec completion → spec planning batch → this very session creating W9). Hit the same pattern three times in one day. Detection script + real-time alert hook shipped this session to ensure it never costs investigative time again. **Recurred 3+ times on 2026-06-05/06** (the #645 CI-fix commit landed on a sibling's branch; HEAD flipped to main twice) — that recurrence motivated the drift-triggered auto-isolation upgrade above.

**Files involved:**
- Detection script: [`scripts/check-branch-drift.py`](../../scripts/check-branch-drift.py)
- Hook registration: [`.claude/settings.json`](../../.claude/settings.json) (PostToolUse:Bash matcher)
- Session state (gitignored): `.claude/_session-state/<SESSION_ID>-branch.txt`
- Worktree prevention: [`scripts/create-isolated-worktree.py`](../../scripts/create-isolated-worktree.py)

---

### W10 — Stale `[gone]` branches + orphan worktrees surfaced by daily-checkpoint

**Pattern:** [`scripts/daily-integrity-checkpoint.py`](../../scripts/daily-integrity-checkpoint.py) (shipped 2026-05-15 in PR #365) lists, in its daily output, local branches whose remote-tracking ref is `[gone]` plus any worktrees present in `.claude/worktrees/` that the operator may have forgotten about. Counts accumulate over weeks of normal feature-cycle activity (each squash-merge leaves a `[gone]` shadow) and the warning is informational, not blocking.

**Why expected:** Routine git hygiene gap. Squash-merge on GitHub deletes the remote branch but leaves the local tracking ref + branch + worktree (if any) intact. Cleanup is operator-driven by design — we don't auto-delete because of W5 (no destructive ops without approval) and because branches sometimes contain unmerged WIP the operator hasn't pushed.

**Distinguishing real signal:**

- **Routine drift (expected):** count grows by 1–5/week tracking the project's PR throughput. Branches all match `chore/*`, `feature/*`, `fix/*`, `docs/*` naming. Worktrees match the branch list 1-to-1.
- **Investigate:** count grows by >10/week (someone's mass-merging without cleanup), OR a worktree's branch is **not** in the `[gone]` list (the worktree is on an active branch and was forgotten), OR you see an unfamiliar branch name (potential W9 branch-drift artifact someone else created).

**Operator cleanup procedure:**

```bash
# Option A — invoke the bundled skill (recommended)
# In a Claude session: invoke /commit-commands:clean_gone
#   - lists all [gone] branches + their worktrees
#   - asks for confirmation before deletion (W5 honored)
#   - removes both branch + worktree atomically

# Option B — manual, when you want to inspect first
git fetch --prune                                  # refresh [gone] markers
git branch -vv | grep ': gone\]'                   # list candidates
git worktree list                                  # cross-check worktree usage

# For each branch you've confirmed is fully merged:
git worktree remove <path-if-any>                  # if a worktree exists
git branch -d <branch>                             # safe (refuses if unmerged)
# Use -D ONLY after confirming the branch is squash-merged on GitHub
# (gh pr list --state merged --search "head:<branch>")
```

**Before deletion — quick safety check:**

1. `gh pr list --state merged --search "head:<branch-name>"` → confirm PR exists + merged
2. `git log <branch> --not main` → if non-empty, branch has commits not on main (DO NOT `-D`)
3. If the branch is from another operator's session (unfamiliar name), confirm with them first

**Silence path:** None needed — informational surface by design. If the daily-checkpoint output is consistently noisy (>20 stale branches), run a cleanup pass to drop the count; the surface will then shrink to a manageable steady state.

**First observed:** 2026-05-15 (v7.8.6 nice-to-have batch added the surface via PR #365). The 14 FT2 + 11 fitme-story stale branches at v7.8.4 ship were a deliberately deferred cleanup window (per `[project_v7_8_4_calibration_paused_2026_05_12]` memory).

**Files involved:**

- Daily-checkpoint script: [`scripts/daily-integrity-checkpoint.py`](../../scripts/daily-integrity-checkpoint.py)
- Skill: `commit-commands:clean_gone` (bundled)
- Related: W5 (no destructive ops without approval) — always confirm cleanup before deletion

---

### W11 — Incomplete PR cache (one of two expected repos absent)

**Pattern:** [`scripts/ensure-pr-cache-fresh.py`](../../scripts/ensure-pr-cache-fresh.py) (v7.8.4 `PR_CACHE_STALE` gate) refreshes `.cache/gh-pr-cache.json` when the cache is **missing**, **empty** (zero PRs across all repos), or **stale** (>24h). It does NOT validate that all expected repos are present. If a refresh ever produces a cache with only one of the two expected repos populated (e.g., `Regevba/FitTracker2` present but `Regevba/fitme-story` absent), the freshness check sees a non-empty, recently-rebuilt cache and skips refresh — but every cross-repo `BROKEN_PR_CITATION` lookup fires a false-positive finding.

**Why expected:** Variant of W3-class issues — silent-pass-then-fixed. The v7.8.4 emptiness check uses "any repo has any PRs" semantics. v7.8.3's D-3 unified cross-repo PR cache assumed the canonical repo list (`REPOS = ["Regevba/FitTracker2", "Regevba/fitme-story"]`) would always be fully populated by `scripts/refresh-pr-cache.py`. A partial-write (gh CLI rate-limited mid-refresh, network blip after first repo, manual edit, parallel write race) violates this assumption silently.

**Distinguishing real signal:**

- **Real signal:** every BROKEN_PR_CITATION finding's URL or `pull/N` cite resolves manually with `gh pr view N --repo <owner>/<repo>` AND the case study or state.json was NOT recently introduced with a placeholder PR number. **AND** the cache file is recent (<24h) so the v7.8.4 refresh logic considers it "fresh."
- **W11 artifact (skip):** ALL BROKEN_PR_CITATION findings cite the SAME absent repo (e.g., all cite `Regevba/fitme-story` while `Regevba/FitTracker2` cites resolve fine). Cache inspection (`python3 -c "import json; print(list(json.load(open('.cache/gh-pr-cache.json'))['repos'].keys()))"`) confirms the expected repo is missing from the `repos` dict.

**Silence path:**

```bash
make refresh-pr-cache               # forces a full re-fetch across all REPOS
make integrity-check                # findings should drop to baseline
```

The fix shipped in this PR (`fix/pr-cache-completeness-w3b`) extends `ensure-pr-cache-fresh.py` to validate per-repo completeness: cache is considered stale if ANY expected repo is absent OR has zero PRs in all buckets. After this fix lands, the `PR_CACHE_STALE` gate auto-recovers from this scenario on next invocation (typically next `make integrity-check` or pre-commit hook fire).

**First observed:** 2026-05-16. The autonomous launchd cron rebuilt the cache at 03:04 UTC (06:04 IDT) but produced a single-repo cache. The 06:21 UTC daily-checkpoint then captured 32 BROKEN_PR_CITATION findings as a phantom regression vs baseline. Diagnosed within ~10 minutes via direct cache inspection + `make refresh-pr-cache` recovery. The script-side fix codifies the recovery so future occurrences self-heal.

**Second occurrence (2026-05-24, W11.b — launchd-cron refresh-subprocess silent fail):**

PR #375's per-repo completeness fix DETECTS incompleteness correctly, but recovery requires `scripts/ensure-pr-cache-fresh.py` to successfully invoke `scripts/refresh-pr-cache.py` (which shells out to `gh pr list`). In a launchd-spawned cron context, the `gh` CLI's keychain-based OAuth credentials may not be accessible (launchd sessions don't inherit the user's login keychain by default), so the refresh subprocess can fail silently. The freshness wrapper's `--quiet || true` swallow then masks the refresh failure, the cache stays incomplete, and `integrity-check.py` runs against the incomplete cache → 319 phantom BROKEN_PR_CITATION findings on this day. Manual re-run from an interactive shell (with keychain access) immediately recovered to 0 findings + 2 advisory (true baseline).

This is a NEW failure mode in the same W11 family. Filed as a v7.9.1 candidate addition to `F-LAUNCHD-DRIFT-EXTENSION`:

- Detection: extend `ensure-pr-cache-fresh.py` to capture refresh subprocess exit status + stderr; if refresh fails, mark cache file as stale-failed and exit non-zero (override `--quiet`)
- OR: extend `scripts/daily-integrity-checkpoint.py` to re-validate `gh auth status` before relying on cron-captured integrity-check output; if `gh` auth is degraded in cron context, mark the day's row as "telemetry-degraded" with a sentinel value instead of writing phantom counts to the ledger
- OR: pre-warm the cache from an interactive shell daily (operator routine; lowest engineering cost but adds operator load)

**Notes:**

- Sibling to W3 / W3.b in spirit but tracked as its own W-number (W11) per the sequential-numbering convention used in this catalog.
- Related: `BROKEN_PR_CITATION` (Section 1, #13) — this pattern's surface; `PR_CACHE_STALE` (Section 1, #12) — the cache-freshness gate; v7.8.3 D-3 cross-repo cache spec.
- Lesson: emptiness checks must enforce per-element completeness, not aggregate presence. "Some data present somewhere" ≠ "all expected data present."
- Lesson 2 (W11.b): subprocess `--quiet || true` swallow patterns hide ALL failures, not just the targeted noise. When the swallowed subprocess is recovery logic for a gate, the silent failure becomes a phantom-regression generator under cron contexts that lack interactive-shell credential access.

**Files involved:**

- Cache freshness gate: [`scripts/ensure-pr-cache-fresh.py`](../../scripts/ensure-pr-cache-fresh.py)
- Cache writer: [`scripts/refresh-pr-cache.py`](../../scripts/refresh-pr-cache.py)
- Daily cron entry point: [`scripts/daily-integrity-checkpoint.py`](../../scripts/daily-integrity-checkpoint.py)
- Cache file: `.cache/gh-pr-cache.json`
- Launchd plist: `~/Library/LaunchAgents/com.fittracker.daily-integrity-checkpoint.plist`

---

## Pattern submission template

When you discover a NEW pattern (gate fires + no matching entry above), add it here.

```markdown
### #N <GATE_CODE or "WN" for workflow> — short description

**Trigger:** what condition causes the gate to fire / pattern to appear

**Why expected:** by-design / cleanup-artifact / silent-pass-then-fixed / heuristic-FP / schema-drift

**Distinguishing real signal:** how to tell artifact from real issue (the signal-from-noise rule)

**Silence path:** opt-out tag / exemption / fix command / no-action-needed

**First observed:** YYYY-MM-DD + PR/incident link

**Notes:** version added/fixed, related gates, lessons learned
```

Commit the new entry on a `chore/document-pattern-<slug>` branch + open PR + merge. Link it in any case study that explains the underlying issue (so the pattern + the case-study deep-dive are cross-referenced).

---

## Index — quick gate lookup

| Code | Section | First observed |
|---|---|---|
| `BRANCH_ISOLATION_HISTORICAL` | #1 | 2026-05-13 |
| `CACHE_HITS_AUTO_INSTRUMENTATION_INACTIVE` | #2 | 2026-05-02 |
| `BRANCH_ISOLATION_VIOLATION` Mode B | #3 | 2026-05-07 (silent-pass fixed 2026-05-12) |
| `BRANCH_ISOLATION_VIOLATION` Mode C | #4 | 2026-05-07 |
| `ISOLATION_OPT_OUT_REASON_MISSING` | #5 | 2026-05-07 |
| `FEATURE_CLOSURE_COMPLETENESS` | #6 | 2026-05-07 |
| `CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT` (formerly `CACHE_HITS_EMPTY_POST_V6`) | #7 | 2026-04-27 (silent-pass fixed 2026-05-01) |
| `TIER_TAG_LIKELY_INCORRECT` | #8 | 2026-04-27 (narrowed 2026-05-12) |
| `SCHEMA_DRIFT_LEGACY_CREATED` | #9 | 2026-05-01 |
| `FRAMEWORK_VERSION_FORMAT` | #10 | 2026-04-27 |
| `STATE_OWNER_MISSING/INVALID/LOCATION_MISMATCH` | #11 | 2026-05-11 |
| `PR_CACHE_STALE` | #12 | 2026-05-12 |
| `BROKEN_PR_CITATION` | #13 | 2026-04-24 |
| `CASE_STUDY_MISSING_TIER_TAGS` | #14 | 2026-04-24 |
| `PARTIAL_SHIP_TERMINAL` | #15 | 2026-04-25 |
| `CASE_STUDY_MISSING_FIELDS` | #16 | 2026-04-27 |
| `CU_V2_INVALID` | #17 | 2026-04-27 |
| `STATE_NO_CASE_STUDY_LINK` | #18 | 2026-04-27 |
| `MECHANISM_C_SHIP_DATE` exemption | #19 | 2026-05-02 |
| `GATE_COVERAGE_ZERO` | #20 | 2026-05-03 |
| `case_study_type` exemptions | #21 | 2026-04-25 |
| v7.5 pipeline fixture rot | #22 | 2026-05-01 |
| `.gitignore` blocks remote-agent visibility | #23 | 2026-05-09 |
| Field-rename silent-pass in a READER/INDEX (measurement layer) — generalizes #7/#9 | #24 | 2026-06-10 (PRs #687/#688/#689) |
| Derived index from gitignored session-local source regresses on overwrite — union-merge | #25 | 2026-06-16 (PR #749) |
| W1 SSH signing | W1 | 2026-05-13 |
| W2 Publish verbatim | W2 | — |
| W3 Check CI before local panic | W3 | — |
| W4 No auto-merge without approval | W4 | — |
| W5 No destructive ops without approval | W5 | — |
| W6 Measurement impartiality | W6 | — |
| W7 Approval gates multi-part | W7 | — |
| W8 Audit status is UI marker | W8 | — |
| W9 Branch-drift from concurrent-session collision (DETECTED via PostToolUse:Bash hook) | W9 | 2026-05-13 |
| W10 Stale `[gone]` branches + orphan worktrees | W10 | 2026-05-15 |
| W11 Incomplete PR cache (one of two expected repos absent) | W11 | 2026-05-16 |
| W12 `vercel env pull` returns empty for Sensitive vars | W12 | 2026-05-20 |
| W13 Upstash `KV_*` vs `UPSTASH_REDIS_REST_*` naming asymmetry | W13 | 2026-05-20 |
| W14 Code Connect `figma.connect()` rejects page frames | W14 | 2026-05-20 |
| W15 MDX `<digit` / `<non-letter` breaks page rendering | W15 | 2026-05-21 |
| W16 Contract-boundary tests must sample from canonical producer | W16 | 2026-05-24 (v7.9.1 candidate F-CONTRACT-FIXTURE-SAMPLING) |
| W17 Stale-base branches — PR diff misleads; cherry-pick onto fresh main is ground truth | W17 | 2026-05-25 (v7.9.1 candidate F-STALE-BASE-DETECTION) |
| W18 Default-URL OG image silent-404 | W18 | 2026-05-27 (v7.9.1 candidate F-DEPLOYED-URL-PROBE) |
| W19 Env-var trailing newline corrupts runtime string | W19 | 2026-05-27 (v7.9.1 candidate F-DEPLOYED-URL-PROBE) |
| W20 Stale-session-state inventory drift | W20 | 2026-05-28 |
| W21 Swift `String.contains("\n")` misses CRLF graphemes — scan `unicodeScalars` | W21 | 2026-05-31 |
| W22 Swift type-checker timeout on heterogeneous array literals >20 elements | W22 | 2026-05-31 |
| W23 `AnalyticsService.logEvent` private — callers must use a `log*` method | W23 | 2026-05-31 |
| W24 pbxproj merge conflicts from concurrent PRs at same group/sources position | W24 | 2026-05-31 |
| W25 `@MainActor` propagates to statics — test class must be `@MainActor` | W25 | 2026-05-31 |
| W26 Two workflows sharing `name:` clash in `${{ github.workflow }}` concurrency groups | W26 | 2026-06-01 |
| W27 `make preflight` enhancement_parent false-positive (was mis-numbered W11) | W27 | 2026-05-19 |
| W28 Local `xcodebuild` blocked by CoreSimulator out-of-date (Mac restart required) | W28 | 2026-06-01 |
| W29 Inline `import` in case-study MDX is a no-op under `compileMDX` — register JSX in `useMDXComponents` | W29 | 2026-06-04 |
| W30 Q6 PR-list parity gate's minimal YAML parser silently strips list items lacking `#` | W30 | 2026-06-04 |
| W31 Workflow delivery anomaly: initial `pull_request:opened` fires only dynamic/skip-path workflows — rebase+force-push triggers full set | W31 | 2026-06-04 |
| W32 `scripts/close-feature.py` requires `--force-incomplete` when the merged PR was the only phase | W32 | 2026-06-04 |
| W33 Pattern↔skill preflight overlay (catalog ⇄ skill mapping + `make skill-preflight`; self-doc, map-exempt) | W33 | 2026-06-04 |
| W34 PR cache window truncation past the 500-PR limit (raised to 2000) | W34 | 2026-06-05 |
| W35 Hook session-id keyed on never-set `CLAUDE_SESSION_ID` env → constant `"default"` → cross-session marker suppresses gate forever | W35 | 2026-06-14 |
| W37 Bot-authored (GITHUB_TOKEN) PR + `strict` branch protection → required checks never run / re-block → permanent "expected" merge deadlock | W37 | 2026-06-15 |

---

## Source provenance

- Gate-firing patterns mined from: case studies, framework honesty ledger, master plans, integrity-cycle snapshots, PR descriptions, Mechanism A coverage telemetry
- Workflow patterns mined from: `~/.claude/projects/-Volumes-DevSSD-FitTracker2/memory/feedback_*.md`
- Cross-referenced against: `scripts/check-state-schema.py`, `scripts/integrity-check.py`, `.claude/integrity/README.md`

Last refreshed: 2026-06-11 (Index sync — added `#24` field-rename-reader pattern [2026-06-10 PRs #687/#688/#689] + W30–W34 rows; corrected the stale W29 Index label [the pattern↔skill overlay renumbered to W33 during the 2026-06-04 rebase, but the Index still listed the overlay under W29]; refreshed the W33 body's work-blocking count 55→57 [24 gate + 33 workflow]). Prior (2026-06-04): added W29 — pattern↔skill preflight overlay — documenting the catalog⇄skill mapping layer + `make skill-preflight`; see `docs/skills/pattern-skill-overlay.md`. Prior (2026-06-02): added W28 — local xcodebuild CoreSimulator-out-of-date — to the index; entry body shipped earlier by a parallel session without an index row. Prior (2026-06-01): index synced through W27; resolved the duplicate-W11 collision — the 2026-05-19 `make preflight` enhancement_parent entry renumbered to W27, since W26 was concurrently claimed by the CI-concurrency pattern in PR #561.

---

### W12 — `vercel env pull` returns empty values for Sensitive vars (2026-05-20)

**Trigger:** Running CLI scripts that need a Sensitive production env-var (e.g., `scripts/issue-bootstrap-token.ts` needs `UCC_BOOTSTRAP_ADMIN_TOKEN`). After `vercel env pull .env.local --environment=production --yes`, the script fails with `<VAR> env var not set (or too short)` despite the diff output showing `+ <VAR> (Updated)`.

**Why expected:** Vercel marks certain env vars as "Sensitive" (a UI toggle on the env-var add/edit form). Sensitive vars are stored encrypted on the Vercel side and CANNOT be downloaded by `vercel env pull` — the CLI writes the variable NAME to `.env.local` but with an empty value (no warning emitted). The script's runtime length check (`adminToken.length < 32`) then trips.

**Signal vs noise rule:** Always noise from a SECURITY perspective (Vercel is doing the right thing). The "signal" is that the operator's CLI workflow is blocked from local execution.

**Silence paths (in order of preference):**

1. **Use the Development env variant** — if the same env-var exists in the Development environment AND is NOT marked Sensitive there, `vercel env pull .env.local --environment=development` retrieves the value cleanly. This is the recommended workaround for the UCC bootstrap-token workflow.
2. **Provision a separate non-Sensitive "CLI admin" env-var** for local-dev workflows. E.g., `UCC_BOOTSTRAP_ADMIN_TOKEN_DEV` (no Sensitive flag). The CLI script reads either name. Acceptable trade-off because the CLI is only useful with Redis WRITE access — the token itself doesn't add risk beyond what KV_REST_API_TOKEN already provides locally.
3. **Toggle Sensitive off temporarily** in Vercel dashboard, pull, then re-mark Sensitive. Operationally fragile and racy — not recommended.

**First surfaced by:** UCC passkey security hardening T20 manual verification (2026-05-20). Documented in [`docs/case-studies/ucc-passkey-auth-security-hardening-case-study.md`](../../docs/case-studies/ucc-passkey-auth-security-hardening-case-study.md) §6.2.

---

### W13 — Upstash KV_*  vs UPSTASH_REDIS_REST_* naming asymmetry (2026-05-20)

**Trigger:** Local CLI scripts using `@upstash/redis`'s `Redis.fromEnv()` (or reading `process.env.UPSTASH_REDIS_REST_URL`) fail with "UPSTASH_REDIS_REST_URL + UPSTASH_REDIS_REST_TOKEN env vars must be set" after `vercel env pull .env.local`, even though `KV_REST_API_URL` + `KV_REST_API_TOKEN` ARE present in the pulled file.

**Why expected:** The Upstash Marketplace integration on Vercel typically auto-provisions env vars under both legacy `KV_REST_API_*` (Vercel KV naming) AND modern `UPSTASH_REDIS_REST_*` (Upstash native naming). But in some projects (e.g., fitme-story as of 2026-05-20), only `KV_*` is provisioned to the production environment. Server-side `Redis.fromEnv()` works on Vercel runtime because Vercel injects BOTH names automatically; local pulls only get `KV_*`.

**Signal vs noise rule:** Noise from a production correctness standpoint (production Redis works). Signal that local CLI workflows need either aliasing or a code-level fallback.

**Silence paths:**

1. **Shell aliasing (immediate)** — in the operator's shell before running CLI scripts:
   ```bash
   export UPSTASH_REDIS_REST_URL="$KV_REST_API_URL"
   export UPSTASH_REDIS_REST_TOKEN="$KV_REST_API_TOKEN"
   ```
2. **Durable fix** — update `src/lib/auth/redis-client.ts` (and any other consumer) to read either name:
   ```ts
   const url = process.env.UPSTASH_REDIS_REST_URL ?? process.env.KV_REST_API_URL;
   const token = process.env.UPSTASH_REDIS_REST_TOKEN ?? process.env.KV_REST_API_TOKEN;
   if (url && token) {
     cached = new Redis({ url, token });
   } else {
     cached = Redis.fromEnv(); // falls back to default UPSTASH_* lookup w/ helpful error
   }
   ```
   Queued as a v7.9.1+ candidate.
3. **Add both names in Vercel env-vars** (mechanical mirror) — manual + duplicative.

**First surfaced by:** UCC passkey security hardening T20 manual verification (2026-05-20). Documented in [`docs/case-studies/ucc-passkey-auth-security-hardening-case-study.md`](../../docs/case-studies/ucc-passkey-auth-security-hardening-case-study.md) §6.3.

---

### W14 — Code Connect `figma.connect()` rejects page frames as targets (2026-05-20)

**Trigger:** `figma-code-connect-publish` CI workflow fails with `Validation failed for <Component> (...node-id=N): corresponding node is not a component or component set`.

**Why expected:** The `@figma/code-connect` validator requires the target Figma node to be a **component** or **component-set** — regular frames (page frames, group frames, instance frames) are rejected even though they're valid Figma node types. Operators sometimes author Code Connect mappings against page-level frames intuitively (1 page in code ↔ 1 frame in Figma) without realizing the Code Connect API only supports component-typed targets.

**Signal vs noise rule:** Always signal — the CI failure is correct. The fix is either to convert the page frame into a Figma component-set OR to remove the page-level mapping. Don't ignore.

**Silence paths:**

1. **Convert the page frame to a Figma component-set** — open the file in Figma, select the frame group, "Create Component Set" or "Promote to component-set". Each variant becomes a Properties value (e.g. `state: idle | pending | error`, `device: mobile | desktop`). The page-level `.figma.tsx` mapping then validates because the target is a component-set. Code Connect can also use `figma.enum(...)` to map React props to component-set properties.
2. **Remove the page-level `.figma.tsx`** — accept that page composition isn't a Code Connect concern. Map only the leaf components (form components, atomic UI primitives). The Figma frames remain useful as design references without needing CI validation.
3. **Comment out the `figma.connect()` call** in the `.figma.tsx` file temporarily while waiting for a future Figma session to convert frames to component-sets. Less clean than (2) but preserves the file as a TODO marker.

**Recommended for product pages:** option (1) — page frames typically have inherent variants (idle/loading/error states) that map naturally to a component-set. Option (2) is the right call only if the page genuinely is a one-off composition (no recurring use across the design).

**First surfaced by:** `ucc-sign-in-figma-mapping` enhancement on `ucc-passkey-auth` (2026-05-20). Documented in [`docs/case-studies/ucc-passkey-auth-case-study.md`](../../docs/case-studies/ucc-passkey-auth-case-study.md) §99 (UU4 2026-05-20 entry).

---

### W15 — MDX `<digit` or `<` followed by non-letter character breaks page rendering (2026-05-21)

**Trigger:** A page authored as MDX (e.g. fitme-story `content/framework/dev-guide.md` rendered via `next-mdx-remote`) fails to prerender at `next build` with:

```text
Error occurred prerendering page "/<route>"
[next-mdx-remote] error compiling MDX:
Unexpected character `5` (U+0035) before name, expected a character that can start a name, such as a letter, `$`, or `_`
```

The character cited (`5` here) is whatever character followed an unescaped `<` in the MDX body. The build worker exits with code 1; the whole production deployment fails. Every commit to main since the offending one fails to deploy until the bad string is fixed. Site continues serving the **previous successful deploy** (Vercel's standard fallback), so end-users see stale-but-functional content with no degraded behavior.

**Why expected:** MDX is JSX-flavored Markdown. `<` is reserved as the start of a JSX tag. JSX tag names must begin with a letter, `$`, or `_` (per the JSX grammar). Common gotcha-strings:

- `<5 min` ← shipped 2026-05-21 via fitme-story PR #129, broke `/framework/dev-guide` production deploy until [PR #130 hotfix](https://github.com/Regevba/fitme-story/pull/130) (`f27a780`)
- `<3` (heart emoji), `<10s`, `<0.5%`, `<HEAD~1` — any inequality / comparator string
- `<-->` (Unicode arrow attempt), `<--`, `<==`, `<>` (empty fragment is parsed but `<>` adjacent to non-JSX text can confuse the lexer)
- `< 5` with a space IS safe (JSX requires no whitespace after `<` before the tag name; lexer falls back to text)

**Signal vs noise rule:** Always signal — the build correctly rejects this. The deploy failure is informative, not a flake. **Critical: this kind of failure can land silently** because:

1. Pre-commit hooks don't compile MDX (the SCHEMA_DRIFT + CASE_STUDY checks don't validate render)
2. PR-level CI (`verify` + `gates`) skips MDX render checks for docs-only PRs
3. Vercel **preview** deploy on the PR shows `Vercel: fail` as a check but is **not a required check** in branch protection (so PR can merge anyway)
4. The first sign that production is broken is when the next commit's production deploy also fails

**Silence paths (in order of preference):**

1. **Rewrite to avoid `<`** — `<5 min` → `in under 5 min`, `< 5 min` (space after `<`), `under 5 minutes`, `less than 5 min`, `~5 min`, `≤5 min` (Unicode `≤`). This is what the hotfix used.
2. **HTML-escape** — `&lt;5 min` renders identically in the browser.
3. **Code-span wrap** — `` `<5 min` `` (backticks). Renders as inline code; MDX parser treats code spans as opaque text.
4. **Block-fence wrap** — for multi-line content, fence with ``` ``` blocks.

**Prevention layer (operator action item for next session):** add MDX render to the verify CI workflow for fitme-story, OR require Vercel preview success in branch protection. Both close the silent-pass class for this category of bug.

**First surfaced by:** fitme-story PR #129 (v7.9 dev-guide page bump, 2026-05-21). The bad string `<5 min` was authored as part of the v7.9 docs sweep. Caught + fixed within ~2 hours via hotfix PR #130 (no end-user-visible regression because Vercel served the previous successful deploy). Documented retrospectively here so the next operator authoring MDX content checks for `<digit` / `<non-letter` patterns before merging.

---

### W16 — Contract-boundary tests must use a sample drawn from the canonical producer, not the consumer's expected shape (2026-05-24)

**Trigger:** A server component on the fitme-story `/control-room/framework` page rendered a 200 OK *error boundary* on every visit. Vercel runtime logs (truncated) showed `TypeError: Cannot read prop...`. Full local trace:

```text
TypeError: Cannot read properties of undefined (reading 'localeCompare')
    at gate-coverage-aggregator.ts:36 — all.sort((a, b) => a.ts.localeCompare(b.ts))
    at aggregateGateCoverage
    at loadGateCoverage (page.tsx:46)
    at FrameworkHealthPage (page.tsx:292)
```

Dormant since v7.8.3 Phase 1 C-4 ship (fitme-story PR #86, 2026-05-11) — error required ≥1 synced FT2 event to manifest, then deterministic on every render thereafter. Site continued serving the previous successful deploy of all *other* routes, so the broken `/control-room/framework` page was the only end-user-visible symptom.

**Why expected:** Schema mismatch between producer and consumer, where the tests on both sides agreed with the consumer rather than the producer:

| Side | File | Field emitted / expected |
|---|---|---|
| Producer (canonical) | FT2 `scripts/gate_coverage.py:101` | `{"timestamp": "..."}` |
| Consumer | fitme-story `src/lib/control-room/gate-coverage-aggregator.ts:36` | expected `a.ts` |
| Test fixture | fitme-story `gate-coverage-aggregator.test.ts` | hand-written `{"ts": "..."}` — **same wrong field as the consumer**, so tests stayed green for 13 days |

The test fixtures encoded the wrong field too. They validated the parser against the contract the parser *invented*, not the contract the upstream producer actually emits. Schema mismatch was invisible to:

1. Pre-commit hooks (no static cross-repo schema check)
2. PR-level CI (tests pass with the matching wrong fixture)
3. Vercel preview deploy (`/control-room/framework` is basic-auth gated, so the preview smoke skips it — see W12 family)
4. The next 13 days of production renders (Next.js error boundary returned 200, so uptime monitors stayed green)

**Signal vs noise rule:** Always signal — schema mismatch is exactly the silent-pass class v7.8 Mechanisms A + B were built to eliminate at the *gate* layer. W16 extends the same principle to *cross-repo data contracts that flow through synced ledgers*.

**Silence paths (in order of preference):**

1. **Fixtures sampled from the real producer.** Prefer copying one row of actual production output (`head -1 .claude/logs/gate-coverage.jsonl`) into a `*.fixture.jsonl` file checked into the consumer's tests. The fixture file gets re-sampled on the consumer side whenever the producer schema bumps.
2. **Shared TypeScript / JSON-Schema interface.** Producer side emits to a shape declared in `.claude/shared/schemas/gate-coverage.schema.json`; consumer side validates with `ajv` (or equivalent) at parse time. Mismatch surfaces immediately at the consumer's first run.
3. **Normalize at parse, accept legacy alias.** The W16 hotfix (PR #146) renamed `GateEvent.ts → GateEvent.timestamp` to match the canonical producer field, and made `parseLines` accept both via a `RawGateEvent` shape that normalizes (`raw.timestamp ?? raw.ts ?? ''`). Defensive sort comparator fallback (`?? ''`) makes a malformed row degrade to "render but unsorted" instead of crashing the page. Backward-compat is preserved for any legacy fixtures or stale ledger files still on disk.
4. **Defensive nullish-coalescing on every boundary access.** When the consumer doesn't control the producer schema (third-party data sources, Vercel runtime metadata, etc.), every accessor on a `unknown` JSON field should `?? <safe-default>` before being passed into a method call. Forces the failure mode to be "missing value rendered as empty" rather than "page crash."

**Prevention layer (operator action item — promoted to v7.9.1 candidate F-CONTRACT-FIXTURE-SAMPLING):** add a `make sample-contract-fixtures` target to FT2 that copies one production row per cross-repo data feed (`gate-coverage.jsonl`, `measurement-adoption.json`, `documentation-debt.json`, `integrity-cycle/snapshots/*.json`) into a `tests/fixtures/cross-repo-contracts/` directory checked into both repos. The fitme-story prebuild step then asserts the live data file's keys are a superset of the fixture's keys. Closes the silent-pass class for *all* cross-repo data contracts, not just gate-coverage.

**Stacking with F16 (try-repo harness, v7.9.1 candidate):** F16's positive/negative fixtures are *intra-repo* (FT2 gate fixtures). F-CONTRACT-FIXTURE-SAMPLING is the *cross-repo* sibling. Both stack on the same fixture-as-contract principle; both are runtime executable assertions that the catalog entry still holds.

**First surfaced by:** PR-induced regression analysis 2026-05-24 after operator pushback ("not transient need to check deeper") on intermittent Vercel runtime error log. Root cause + hotfix shipped as fitme-story PR #146. Documented retrospectively here as a v7.9.1 process-pattern candidate so any future cross-repo synced-data feature (current count: 5; expected growth path: every new FT2-generated ledger that the website renders) cannot land with consumer-only-validated fixtures.

---

### W17 — Stale-base unmerged branches: `gh pr view` file list misleads; cherry-pick onto fresh `origin/main` is ground truth (2026-05-25)

**Trigger:** any unmerged branch / draft PR that has sat through one or more merge waves on `main`. `git diff origin/main..<branch>` shows enormous "deletions" (often 1000s of lines, 20+ files) that don't appear in the branch's own commits. `gh pr view --json files` reports only the branch's actually-touched files (e.g. 6); the merge-time effective diff is much larger.

**Why expected:** GitHub computes a draft PR's file list against the branch's *original base SHA*, not against current `origin/main`. When `main` advances via squash-merges of unrelated work, every file added to `main` after the branch forked appears as "DELETED" in the branch's effective merge diff. The branch isn't actively deleting those files — it just doesn't have them — so merging as-is would revert all of them. `mergeStateStatus: BEHIND` is the GitHub-side warning, but the file-list misleads operators who don't drill into the `git diff` against current main.

**Distinguishing real signal:**

- **Stale-base (artifact):** `git diff origin/main..<branch> --shortstat` shows huge negative line counts (>500 deletions) and "files changed" >> the count of files actually touched by `git log origin/main..<branch>` commits. `mergeStateStatus: BEHIND`.
- **Live (real content):** the diff stat matches what the branch's commits actually touch. No files in the diff are recent additions to main.

**Detection commands:**

```bash
# Quick screen — patch-id match against main
git cherry origin/main <branch>
#   - prefix on each commit = ALREADY on main (zombie)
#   + prefix on each commit = appears new
# NOTE: misses squash-merge zombies (patch-ids differ from squashed equivalent).

# Ground truth — cherry-pick onto fresh main, count non-empty results
git worktree add -b _audit /tmp/audit origin/main
cd /tmp/audit
for c in $(git log origin/main..<branch> --reverse --format=%H); do
  git cherry-pick --keep-redundant-commits $c
done
git rev-list --count origin/main..HEAD     # 0 → ZOMBIE; >0 → has real content
```

**Three classes of stale-base outcome:**

1. **Zombie** — every cherry-pick produces an empty commit. All content already on main (typically because main re-shipped the same patch via a different branch). Safe to `git branch -D <branch>` locally + delete remote.
2. **Content-zombie** — cherry-pick conflicts on a file, but inspection shows the branch's version is an OLDER subset of main's (e.g. branch has 27 lines of `ucc-auth-events.jsonl`, main has 43 = branch's 27 + 16 new events). Branch's intent has been fulfilled via different paths (daily-sync PR shipped the events; squash-merge PR shipped the bumps). Safe to delete after intent verification — diff size/direction is the signal.
3. **Live** — cherry-pick produces real new content not on main. Rebase branch onto current main, audit the resulting clean diff, open a fresh PR.

**Silence path:**

For each stale-base branch, run the cherry-pick audit. Zombies + content-zombies get deleted. Live branches get rebased and PR'd fresh. If the work is already covered by other PRs (the content-zombie case), close any draft PR with an explanatory comment ("content shipped via PR #X; this branch's diff is stale-base phantom-revert; closing per W17") rather than merging — per [W4](#w4--no-auto-merge-without-explicit-approval).

**Examples observed 2026-05-25 session:**

- **PRs #484 + #488** (daily-digest + stale-state-sweep drafts) — opened earlier in the day, sat through 5 same-day merges (HADF runbook, oldSSD addendum, R-tracks, UCC hardening case study, integrity snapshots). `gh pr view --json files` showed 2 + 6 files; the actual merge-time diff was 9 + 23 files with phantom reverts of all the day's new docs. Closed with explanation; daily-digest re-generated cleanly off current main as PR #491 (3 files / +149 / -58 vs the original draft's 2 files / +38 / -827). PR #491 merged 17:54 UTC.
- **Local branch GC** — 35 unpushed local branches enumerated at session-close; **33 turned out to be zombies or content-zombies** after the cherry-pick audit. Only 2 were genuinely live: `chore/dev-guide-v7-9-readability-pass-ft2-2026-05-24` (explicitly DEFERRED per memory) and a worktree-pinned in-flight branch (`chore/2026-05-25-cadence-followups-green-items` — 9 commits, several already overlap with PR #483).

**Why this is dangerous if missed:**

Merging a stale-base PR without rebasing reverts every file the branch doesn't know about. The 2026-05-25 draft PR #488 would have reverted: HADF runbook (-183), oldSSD addendum (-208), env template (-54), pre-reg lock, 12 R-track config files, integrity snapshot (-1172), UCC hardening case study modifications, and `scripts/hadf-phase2bis-collect.py` (-280). The `gh pr view --json files` API showed 6 files; the actual revert blast-radius was 23.

**Prevention layer (v7.9.1 candidate F-STALE-BASE-DETECTION):**

A pre-merge gate that compares the PR's "files changed" count (`gh pr view --json files`) against `git diff origin/main..<head> --stat` and raises a P0 advisory when the ratio diverges by >2× — typical signal of phantom-revert. The per-PR review bot already worktree-captures `origin/main baseline`; extending it to surface the stale-base ratio explicitly would close this silent-pass. Stacks with [W11 — Incomplete PR cache](#w11--incomplete-pr-cache-one-of-two-expected-repos-absent) as a "PR-time sanity check" class. Sibling of [W16 — Contract-boundary fixture sampling](#w16--contract-boundary-tests-must-use-a-sample-drawn-from-the-canonical-producer-not-the-consumers-expected-shape-2026-05-24) in that both detect "the diff that ships ≠ the diff the operator reviewed."

**Operator workflow (session close):**

1. `git for-each-ref --format='%(refname:short)' refs/heads/` — enumerate local branches
2. For each branch ahead of `origin/main` (and not checked out in a worktree), run cherry-pick audit
3. Delete zombies + content-zombies (`git branch -D <branch>`)
4. For genuinely-live branches: rebase onto main, push, open fresh PR
5. After 2-3 merge waves, even week-old branches usually become zombies — making this a daily/weekly cleanup, not exceptional

**Related patterns:**

- [W4](#w4--no-auto-merge-without-explicit-approval) — never auto-merge a stale-base PR; always per-PR approval
- [W10](#w10--stale-gone-branches--orphan-worktrees-surfaced-by-daily-checkpoint) — daily checkpoint warns about local branches whose REMOTE is gone; W17 extends to branches whose CONTENT is gone (already shipped via different patch path)
- [W16](#w16--contract-boundary-tests-must-use-a-sample-drawn-from-the-canonical-producer-not-the-consumers-expected-shape-2026-05-24) — sibling pattern; both detect "the artifact you reviewed ≠ the artifact that ships"

**First surfaced by:** 2026-05-25 session — initially as a near-miss on draft PRs #484 + #488 (closed via Path 2 = "close + regenerate fresh on current main"). Pattern then verified at scale via a 35-branch local-state audit yielding 33 deletions: 4 confirmed clean ZOMBIES + 10 MANUAL-conflict content-zombies + 11 pre-bulk-audit zombies + 7 `pr-*` tracking branches of CLOSED PRs + 1 stale `claude/*` session branch. Worktrees cleaned: 2 (123 MB reclaimed). Stashes dropped: 3.

---

### W18 — Default-URL OG image silent-404: metadata helper hardcodes a URL that doesn't exist in `public/` or as an auto-route (2026-05-27)

**Trigger:** Social shares (LinkedIn, Twitter, Hacker News, dev.to) from `fitme-story.vercel.app` produce bare blue links instead of rich previews. End-user-visible only AFTER share is posted; invisible during local dev + during preview-URL inspection in the Vercel dashboard.

**Reproduce:**

```text
$ curl -sI https://fitme-story.vercel.app/og.png
HTTP/2 404                              ← URL referenced in og:image meta tag

$ curl -sI https://fitme-story.vercel.app/opengraph-image
HTTP/2 200                              ← Next.js auto-generates this from
                                          src/app/opengraph-image.tsx
```

The `og:image` meta tag in deployed HTML pointed at `/og.png` (which doesn't exist in `public/`) instead of the Next.js Metadata API auto-route `/opengraph-image` (which the per-page `src/app/opengraph-image.tsx` file emits as a 1200×630 `ImageResponse`). Social platforms fetched the bad URL, got 404, suppressed the rich preview entirely.

Dormant for 6 days from 2026-05-21 (DISCO Phase 1 P1.3 + P1.4 ship) until 2026-05-27 (operator P1.5 incognito-check on Realtime). Detection required either (a) the operator manually visiting the OG URL or (b) running a real social-share preview test. Neither was in the test plan; the silent class persisted.

**Why expected:** the `src/lib/seo.ts::buildMetadata()` helper override is "useful" — it lets per-page metadata declare a custom OG image. But the *default* was hardcoded to `/og.png` instead of pointing at the same auto-route the Next.js convention emits when `opengraph-image.tsx` exists. The defaults disagreed.

| Side | File | URL emitted |
|---|---|---|
| Producer (canonical) | `fitme-story/src/app/opengraph-image.tsx` | `/opengraph-image` (Next.js convention) |
| Default consumer | `fitme-story/src/lib/seo.ts:57` (pre-fix) | `${SITE_BASE}/og.png` ← 404 |
| Per-page override | callers of `buildMetadata({ image: '...' })` | whatever passed |

The override callers worked; the default callers (the homepage + most other routes) all 404'd.

**Silence paths (in order of preference):**

1. **The default URL is the framework convention.** When you adopt Next.js's `opengraph-image.tsx` file-based metadata convention, every default in your codebase must point at the convention's emitted URL (`/opengraph-image`), not a parallel hand-named static asset.
2. **Test that the URL resolves.** Unit-test the helper's output, asserting `og:image` URL exists in `public/` OR matches a known Next.js auto-route. Fixed in PR #156 + 6 regression tests in `src/lib/seo.test.ts` covering the OG + Twitter + JSON-LD branches.
3. **Defensive normalization at the helper boundary.** If a caller might pass a relative path or a 404'd path, normalize/probe at build time. Out of scope for this fix; queued as v7.9.1 candidate **F-DEPLOYED-URL-PROBE** which adds a CI step that curl-HEAD's the OG URL + curl-200's the `gtag/js?id=$NEXT_PUBLIC_GA_ID` URL on every deploy preview.

**Prevention layer (v7.9.1 candidate F-DEPLOYED-URL-PROBE):**

Sibling of [W16](#w16--contract-boundary-tests-must-use-a-sample-drawn-from-the-canonical-producer-not-the-consumers-expected-shape-2026-05-24). W16 closes consumer-fixture-disagrees-with-producer-shape; W18 closes consumer-hardcoded-URL-disagrees-with-deployment. Both belong to the same silent-pass class: "the data the test exercises is not the data production delivers."

**Related patterns:**

- [W12](#w12--vercel-env-pull-returns-empty-values-for-sensitive-vars-2026-05-20) — Vercel-deploy-time vs runtime divergence; shared substrate ("how the deploy renders ≠ how the source reads")
- W13 (Upstash `KV_*` vs `UPSTASH_REDIS_REST_*` naming asymmetry) — same "two valid names; helper picks the wrong one" pattern (Upstash Redis env var aliasing)
- [W16](#w16--contract-boundary-tests-must-use-a-sample-drawn-from-the-canonical-producer-not-the-consumers-expected-shape-2026-05-24) — closest sibling; both flag "consumer-side tests validated the wrong shape"

**First surfaced by:** 2026-05-27 DISCO Phase 1 P1.5 operator-verification follow-up. Operator confirmed GA Realtime saw web sessions only AFTER both #156 (this URL fix) + #157 (W19 below — env-var trailing-newline corruption) were live. Closed via fitme-story PR #156 + 6 new regression tests.

---

### W19 — Environment-variable trailing newline silently corrupts runtime string (2026-05-27)

**Trigger:** `NEXT_PUBLIC_GA_ID` (or any string env var) injected at runtime via `process.env.X` carries trailing whitespace from the original env-var paste. Downstream consumers that URL-encode the value (e.g. `${url}?id=${process.env.X}`) silently produce malformed URLs (`?id=G-XE4E1JGWRZ%0A`) that the receiving service rejects.

**Reproduce in deployed HTML:**

```text
$ curl -s https://fitme-story.vercel.app | grep -oE '.{20}G-XE4E1JGWRZ.{5}'
..."gaId":"G-XE4E1JGWRZ\n"...           ← \n in the JSON-stringified gaId

$ curl -sI 'https://www.googletagmanager.com/gtag/js?id=G-XE4E1JGWRZ%0A'
HTTP/2 200                              ← Google serves the file, BUT every
                                          subsequent measurement-protocol POST
                                          tagged with the malformed ID is
                                          silently rejected at GA4 ingestion.
```

Result: GA4 Realtime showed `iOS = 30 sessions` and `web = 0 sessions` for 6 days post-DISCO-Phase-1-ship (2026-05-21 → 2026-05-27), even though `gtag/js` was being loaded successfully by every web visitor. The protocol-level rejection produced no client-side error, no console warning, no Realtime debug-view entry — only zero events in dashboards.

**Why expected:** the operator ran `vercel env add NEXT_PUBLIC_GA_ID production` and pasted `G-XE4E1JGWRZ` followed by Enter. The trailing newline became part of the stored value. `process.env.NEXT_PUBLIC_GA_ID` returned `G-XE4E1JGWRZ\n` verbatim. The Next.js Script component injected the string into the gtag URL as-is.

Most consumers of `process.env.X` are forgiving — they pass the string to other consumers who also tolerate whitespace. But URL builders + query-string serializers + JSON consumers don't tolerate whitespace; they percent-encode it (`\n → %0A`) and pass the bad URL forward. The transformation makes the corruption invisible at every layer except the final receiving server.

**Silence paths (in order of preference):**

1. **Trim every string env var at the boundary.** `const X = process.env.X?.trim()`. One token. Defends against every future paste regardless of how the env var was set.
2. **Helper module for env reads.** Centralize all `process.env.*` reads in a `src/lib/env.ts` that returns trimmed values + emits a warning on unexpected whitespace. Out of scope for hotfix; queued as a v8.x candidate.
3. **CI assertion at deploy boundary.** After deploy, curl the deployed HTML + assert no `\n` appears in the JSON-serialized config payload. Subsumes by v7.9.1 candidate **F-DEPLOYED-URL-PROBE** which builds the curl assertions.

**Prevention layer (v7.9.1 candidate F-DEPLOYED-URL-PROBE):**

Same candidate as W18; W19 motivates a sibling probe: after deploy, the CI step asserts `curl 'https://www.googletagmanager.com/gtag/js?id=$NEXT_PUBLIC_GA_ID' -I` returns 200 + the URL contains no `%0A`. Catches both the W18 (wrong URL) + W19 (corrupted ID) silent-pass classes in one gate.

**Related patterns:**

- [W12](#w12--vercel-env-pull-returns-empty-values-for-sensitive-vars-2026-05-20) — Vercel env-var quirks family; W12 (Sensitive vars empty) + W13 (alias mismatch) + W19 (trailing whitespace) are three faces of the same "Vercel env-store has hidden semantics" class
- [W18](#w18--default-url-og-image-silent-404-metadata-helper-hardcodes-a-url-that-doesnt-exist-in-public-or-as-an-auto-route-2026-05-27) — sibling discovered same day; both 6-day silent-pass classes invisible to local dev + preview deploys

**First surfaced by:** 2026-05-27 DISCO Phase 1 P1.5 operator-verification. Initial diagnosis assumed GA wiring was missing entirely (Realtime showed 0 web sessions); deeper curl inspection of the deployed HTML revealed the `\n` literal in the JSON payload. The `\n` made it through Vercel's env-var-store + Next.js's environment injection + the Script component's URL builder, only being rejected at the GA4 Measurement Protocol gate. Closed via fitme-story PR #157 with one-line `?.trim()` fix.

**Operator runbook (general env-var hygiene):**

When pasting any string env var, prefer `printf '%s' 'value'` (no trailing newline) over a direct interactive paste OR check the value post-write:

```bash
# Verify no trailing whitespace post-set:
vercel env pull .env.local --environment=production --yes
grep -E '\s+$' .env.local && echo "WARN: trailing whitespace detected" || echo "clean"
```

Or set the value through the Vercel REST API with explicit JSON payload (which forbids embedded newlines by construction):

```bash
curl -X POST "https://api.vercel.com/v10/projects/<project_id>/env" \
  -H "Authorization: Bearer $VERCEL_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"key":"NEXT_PUBLIC_GA_ID","value":"G-XXXXXXX","type":"plain","target":["production"]}'
```

---

### W20 — Stale-session-state inventory drift (2026-05-28)

**Symptom:** Session produces an operator-gate inventory, status survey, or "what's open" list that contains items the operator already shipped. Worse: agent proceeds to "prep" or "fix" those items on a stale worktree, overwriting the operator's better-quality work.

**Detection:** `make freshness-check` (`scripts/cross-layer-freshness.py`) — 4-layer scan covering: recent merged PRs (both repos, default 7d), worktree-vs-main divergence, memory ↔ feature-state drift, optional Linear sync. Auto-chained by `make preflight` from 2026-05-28+.

**Failure mode (2026-05-28 root incident):**

The session opened with `make membrane-status` + `make integrity-check` clean. Agent produced a multi-section operator-gate inventory referencing "HADF Sub-exp 2 + 3 preregs need filling" + "Block C slot 22c collision needs fixing." Agent then `Edit`ed the prereg JSONs on a 26-commits-behind worktree + `git mv`'d the MDX. **Reality:** FT2 PRs #506 + #507 had already filled the preregs ~16h earlier (with better rationale + `_status_at_2026_05_27` provenance + correctly-tuned yield_thresholds); fitme-story PR #155 had deliberately placed the MDX at slot 22c (overriding the chronological heuristic). The agent's edits diverged from the operator's intent. Recovery: revert the prereg edits + undo the rename + apologize for the duplicated work.

**Sibling patterns:**

- [W9 — Branch drift](#w9--branch-drift-from-concurrent-session-git-checkout-collision-detected--real-time-alerted) — concurrent-session HEAD flip; **different mechanism** (W9 = mid-session checkout, W20 = stale baseline at session start)
- [W17 — Stale-base unmerged branches](#w17--stale-base-unmerged-branches-gh-pr-view-file-list-misleads-cherry-pick-onto-fresh-origin-main-is-ground-truth-2026-05-25) — PR review surface lies about what will actually merge; **sibling** in the "your view of state is stale" family
- [W16 — Contract-boundary fixture sampling](#w16--contract-boundary-tests-must-use-a-sample-drawn-from-the-canonical-producer-not-the-consumers-expected-shape-2026-05-24) — your test fixture lies about producer reality; same epistemological class

**Why the existing preflight didn't catch it:**

`make preflight` (v7.8.6) reads the local snapshot (state.json, integrity findings, doc-debt). All of those were clean at session-open because the operator's recent PRs had already merged — main was in good shape. The gap: nothing in preflight compared MY session's mental model (built from MEMORY.md + assumptions) against `origin/main`'s actual recent history. Local state was correct; my model was 16h stale.

**Remediation (mandatory operator workflow):**

Run `make freshness-check` (or accept the auto-chain via `make preflight`) at any of:

1. Session start (auto-surfaced via SessionStart hook)
2. Before producing any inventory ≥3 items deep that claims items are "open" / "pending" / "in flight"
3. Before `Edit`ing a file the operator may have shipped recently (preregs, case studies, runbooks, state.json, cadence ledgers)
4. After `git fetch` but before `git checkout` — the divergence-per-worktree layer surfaces which worktrees are now stale

**Mandatory rule (operator obligation):**

The agent obligation is codified in [`feedback_cross_layer_freshness_check.md`](../../memory/feedback_cross_layer_freshness_check.md) (auto-memory). The pattern is mechanically enforced via the auto-chain from `make preflight` (v7.8.6+) and surfaced via SessionStart hook (when wired).

**First surfaced by:** 2026-05-28 session — HADF Sub-exp 2/3 prereg duplication incident. Cost: ~30 min of duplicated work + an operator correction round-trip. Recovery: revert prereg edits + undo MDX rename. Net session deliverable salvaged: collector code (ollama + aws-bedrock branches) + requirements + operator runbook — all genuinely new and useful.

### W21 — Swift `String.contains("\n")` misses CRLF graphemes; scan unicodeScalars instead (2026-05-31)

**Surfaced by:** `feat/data-export-csv-2026-05-31` PR #549 — CSV `csvEscape("line1\r\nline2")` returned the raw input instead of the quoted form, because the function gated its escape branch on `field.contains("\n") || field.contains("\r")`. CI test `test_csvEscape_quotesAndEscapesFieldsWithNewlines` failed with the wrapped-form expected but raw form actual.

**Root cause:** Swift's `String` is a sequence of extended grapheme clusters, not scalars. The bytes `\r\n` (U+000D + U+000A) form a single CRLF cluster. `String.contains("\n")` looks for a `\n` cluster on its own — the CRLF cluster does not match `\n` alone, and does not match `\r` alone. The escape branch never fired, raw input returned.

**Fix:**

```swift
let needsEscape = field.unicodeScalars.contains(where: { scalar in
    scalar == "," || scalar == "\n" || scalar == "\r" || scalar == "\""
})
```

Scalar-level scan detects CR + LF whether they appear standalone or inside any cluster.

**Generalizable rule:** when checking for ASCII control characters in arbitrary Swift `String` input, scan `unicodeScalars` not graphemes. The grapheme abstraction is correct for user-facing text length, sorting, slicing — wrong for byte-level format compliance (CSV, NDJSON, HTTP framing, etc.).

**Sibling patterns:** None in current catalog; first Swift-language-behavior W-code.

### W22 — Swift type-checker timeout on heterogeneous array literals >20 elements with `Optional.map(String.init)` (2026-05-31)

**Surfaced by:** `feat/data-export-csv-2026-05-31` PR #549 first CI failure — `DataExportService.swift:129: error: the compiler is unable to type-check this expression in reasonable time; try breaking up the expression into distinct sub-expressions`.

**Root cause:** the failing line assembled a 23-element `[String]` literal mixing:

- direct strings (`log.phase.rawValue`)
- `String(_:)` calls on Ints (`String(log.completionPct)`)
- `Optional<Double>.map(String.init) ?? ""` chains (`bio.weightKg.map(String.init) ?? ""`)
- `Optional<Double>.map(String.init) ?? ""` for several nutrition fields
- `reduce`/`compactMap`/`filter` accumulations wrapped in `String(_:)`

Swift's `String.init(_:)` has many overloads (Int, Double, Float, CustomStringConvertible, …); each `Optional.map(String.init)` site is independently ambiguous. Combined with array-literal type inference, the constraint solver hits its budget cap and gives up.

**Fix (two layers):**

1. Extract each cell as a plain `String` local before the literal:
   ```swift
   let weightKg = bio.weightKg.map { String($0) } ?? ""
   // ... 22 more locals
   let fields: [String] = [dateStr, log.phase.rawValue, ..., weightKg, ...]
   ```
2. Use closure form `.map { String($0) }` (not unbound `.map(String.init)`) — the closure-parameter type is inferred from the optional's `Wrapped`, picking exactly one `String.init(_:)` overload.

**Generalizable rule:** when assembling a homogeneous array from heterogeneous expressions, pre-compute each cell. When mapping `Optional<T>` through `String.init`, prefer the closure form.

**Sibling patterns:** None directly; closest is [W21](#w21--swift-stringcontainsn-misses-crlf-graphemes-scan-unicodescalars-instead-2026-05-31) — both are Swift-language-behavior W-codes from the same PR.

### W23 — `AnalyticsService.logEvent` is private; callers must use a `log*`-named public method (2026-05-31)

**Surfaced by:** `feat/smart-reminders-consumer-registry-2026-05-31` PR #551 first CI failure — `FitTrackerApp.swift:148: error: 'logEvent' is inaccessible due to 'private' protection level`.

**Root cause:** `AnalyticsService` exposes ~30 `func log<EventName>(...)` methods (`logLogin`, `logShare`, `logWorkoutStarted`, …) and channels them all through a single `private func logEvent(_ name: String, parameters: [String: Any]?)`. The funnel is intentionally private — every event must come from a named, documented call site. Free-form callers cannot bypass the taxonomy.

**Fix:** for edge-case-that-shouldn't-happen events with no matching `log*` method, surface via `#if DEBUG print()` instead of inventing a new method. Adding a `log*` method specifically for a path that should never fire violates the taxonomy discipline.

```swift
let registered = SmartRemindersConsumerRegistration.registerAtAppInit()
#if DEBUG
if !registered {
    print("[SmartReminders] WARNING: consumer registration failed — urlPatterns collision.")
}
#else
_ = registered
#endif
```

**Generalizable rule:** if your call site needs a `logEvent` for a real product surface, add a named `log*` method to the public API. If it's a defensive can't-happen path, use a debug print, not a new method.

**Sibling patterns:** None directly; analytics-taxonomy hygiene is enforced in the [analytics naming convention](../../CLAUDE.md#analytics-naming-convention) but not as a W-code until now.

### W24 — pbxproj merge conflicts when concurrent PRs add files in the same group/sources position (2026-05-31)

**Surfaced by:** PRs #549 + #550 — both branched from the same `main` SHA, each added entries to `FitTrackerTests` group and Sources phase at the position immediately after `ReminderAnalyticsTests.swift`. When #551 (Smart Reminders consumer registry, the third concurrent PR) merged first, the other two branches went `DIRTY` with conflict markers in two `project.pbxproj` regions per PR.

**Root cause:** Xcode's pbxproj is line-ordered; new entries by convention land at the same neighborhood relative to a stable anchor (e.g. "after ReminderAnalyticsTests"). When N concurrent PRs target that anchor, only the first merger lands cleanly; the rest see CONTENT conflicts in the same span.

**Fix:** resolve by keeping ALL branches' entries side-by-side — the entries themselves never overlap semantically (distinct PBXBuildFile IDs + distinct PBXFileReference IDs + distinct paths). Manual merge keeping `<<<<<<<` content + `=======` content + dropping the markers + the `>>>>>>>` line is mechanically safe.

**Generalizable rule:** when N concurrent PRs add files to the same Xcode target, expect pbxproj merge conflicts; resolution is purely additive. No code-semantic risk — but at scale (>3 concurrent PRs) consider sequencing or splitting the target.

**Sibling patterns:**

- [W17 — Stale-base unmerged branches](#w17--stale-base-unmerged-branches-gh-pr-view-file-list-misleads-cherry-pick-onto-fresh-origin-main-is-ground-truth-2026-05-25) — same "concurrent branches diverge against main" class, different surface (PR-review preview lies vs pbxproj conflict)

### W25 — `@MainActor` propagates to static methods; main-actor-bound statics must be called from `@MainActor` test classes (2026-05-31)

**Surfaced by:** `feat/data-export-csv-2026-05-31` PR #549 second CI failure — `DataExportServiceCSVTests.swift:12: error: call to main actor-isolated static method 'csvEscape' in a synchronous nonisolated context`.

**Root cause:** `DataExportService` is declared `@MainActor final class …` because it's an `ObservableObject` driving SwiftUI updates. The annotation propagates to all members, including `static func csvEscape(_:)`. Synchronous test methods in a non-isolated `XCTestCase` subclass cannot call main-actor statics without an `await MainActor.run { … }` wrapper.

**Fix:** mark the test class `@MainActor`:

```swift
@MainActor
final class DataExportServiceCSVTests: XCTestCase {
    func test_csvEscape_passesPlainStringUnchanged() {
        XCTAssertEqual(DataExportService.csvEscape("hello"), "hello")  // OK
    }
}
```

This matches the pattern already used in [`ReminderPreferencesStoreTests`](../../FitTrackerTests/ReminderPreferencesStoreTests.swift) + [`SmartRemindersConsumerRegistrationTests`](../../FitTrackerTests/SmartRemindersConsumerRegistrationTests.swift) — three sibling test files in the same merge window.

**Generalizable rule:** when adding a unit-test file for a `@MainActor` type's static or instance methods, annotate the test class `@MainActor`. If most tests in the codebase target `@MainActor` types (SwiftUI app), `@MainActor` on the class becomes the default; non-actor tests are the exception.

**Sibling patterns:** None directly; closest is the design-system test discipline that XCTest's main-actor handling enables — not yet codified as a W-code.

### W26 — Two workflows sharing `name:` clash in `${{ github.workflow }}` concurrency groups → cross-workflow cancellation blocks merges (2026-06-01)

**Surfaced by:** PR #560 (C2 readiness-aware-training-alert, mixed iOS code + docs/.claude). The PR's required `Build and Test` status check appeared TWICE in the rollup — one CANCELLED, one SUCCESS — blocking the green-status criterion even though no real failure occurred.

**Root cause:** both `.github/workflows/ci.yml` (heavy macos-15 iOS pipeline) and `.github/workflows/ci-docs-skip.yml` (cheap ubuntu-latest fast-path) declare `name: CI`. The `${{ github.workflow }}` expression resolves to the workflow NAME (not file), so both files computed identical concurrency groups (`ci-CI-refs/pull/N/merge`). With `cancel-in-progress: true`, whichever workflow entered the group second cancelled the first — typically the fast docs-skip job cancelled the heavy iOS job. The CANCELLED status persisted in the PR rollup and blocked merge even with `--admin` until rerun-superseded.

Compounding cause: the `paths:` vs `paths-ignore:` filters in the two files are not mutually exclusive on mixed PRs. A PR touching BOTH `FitTracker/**` files AND `docs/**` files trips ci.yml's `paths:` (at least one match) AND ci-docs-skip.yml's `paths-ignore:` (at least one non-match) — so both fire and immediately race for the shared concurrency group.

**Fix (PR pending):** give each workflow its own hardcoded concurrency-group prefix instead of `${{ github.workflow }}`:

```yaml
# ci.yml
concurrency:
  group: ci-yml-${{ github.ref }}
  cancel-in-progress: true

# ci-docs-skip.yml
concurrency:
  group: ci-docs-skip-${{ github.ref }}
  cancel-in-progress: true
```

Both workflows then run independently. On a mixed PR you get TWO passing `Build and Test` status checks (one from each file) — branch protection accepts the rollup because both are SUCCESS.

**Generalizable rule:** when two workflow files share the same `name:` (intentional, to satisfy branch protection by status-check-name matching), DO NOT use `${{ github.workflow }}` in their `concurrency.group` expressions. Use file-specific hardcoded prefixes. Anywhere two workflows share a status-check name, audit their concurrency groups for collision.

**Sibling patterns:** the original W26 placeholder note in [`project_session_2026_05_31_tier_carryover_plan.md`](../../.claude/projects/-Volumes-DevSSD-FitTracker2/memory/project_session_2026_05_31_tier_carryover_plan.md) captured the Catch-22 symptom (cancelled status blocking merge) but mis-attributed the cause to `cancel-in-progress: true` alone. The actual root cause is the cross-workflow group sharing — `cancel-in-progress: true` per workflow is correct and desirable; only the cross-workflow collision is wrong.

### W27 — `make preflight` enhancement_parent false-positive (2026-05-19)

> **Numbering note:** this pattern was originally documented as a second `W11` (colliding with the canonical W11 "Incomplete PR cache"). The de-duplication was scheduled to renumber it to W26, but W26 was concurrently claimed by the CI-concurrency pattern above (PR #561). Renumbered to W27 on 2026-06-01. Chronologically it sits between W11 (2026-05-16) and W12 (2026-05-20); the W-number is later because the collision was only caught during the 2026-06-01 index sync.

**Trigger:** Running `make preflight WORK_TYPE=enhancement FEATURE=<name>` blocks with `enhancement_parent: parent='<feature>' phase=tasks, prd.md present=False` even when the actual parent feature (referenced by `state.json::parent_feature`) IS complete with a PRD.

**Why expected:** `scripts/preflight.py::enhancement_parent_state()` checks the ENHANCEMENT FEATURE'S own `prd.md` and `current_phase`, instead of resolving `state.json::parent_feature` and checking THAT feature. Pure heuristic bug — the check is mis-aimed.

**Signal vs noise rule:** Always noise when the enhancement is legitimately scoped (state.json has `parent_feature` set + parent is `complete`). Signal only if no `parent_feature` field exists in state.json (real misconfiguration).

**Silence path (Option A, workaround):** Write a thin "delta PRD" stub at `.claude/features/<enhancement>/prd.md` listing primary/secondary/guardrail metrics + kill criteria. Re-run preflight; the `prd.md present=True` check passes (but `phase=tasks` still trips the blocker — accept this as known-noise OR run preflight with `FEATURE=<parent>` for verification only).

**Silence path (Option B, durable fix):** Patch `scripts/preflight.py::enhancement_parent_state()` to read `state.json::parent_feature` and resolve the check against THAT feature. Queue as a v7.9.1 candidate; tracked in [`docs/master-plan/ucc-hardening-infra-overlay-2026-05-19.md`](../../docs/master-plan/ucc-hardening-infra-overlay-2026-05-19.md) R7.

**First surfaced by:** `ucc-passkey-auth-security-hardening` enhancement work, 2026-05-19. The work proceeded with Option A.

### W28 — Local `xcodebuild` blocked by CoreSimulator + iOS platform out-of-date (Mac restart required) (2026-06-01)

**Surfaced by:** every local Swift build attempt during the 2026-06-01 C2 + C4 + W26 session. Surfaced 10+ times across the session — each `xcodebuild` invocation produced the same pair of errors:

```text
DVTErrorPresenter: Unable to load simulator devices.
CoreSimulator is out of date. Current version (1051.50.0) is older than build version (1051.54.0).
…
xcodebuild: error: Unable to find a destination matching the provided destination specifier:
  { generic:1, platform:iOS }
  Ineligible destinations for the "FitTracker" scheme:
    { platform:iOS, … error:iOS 26.5 is not installed. Please download and install the platform from Xcode > Settings > Components. }
```

**Root cause:** the macOS-side `CoreSimulator.framework` daemon binary on the operator's Mac (currently `1051.50.0`) was loaded into memory before an Xcode update bumped the on-disk version to `1051.54.0`. The mismatch persists across `xcodebuild` invocations because the daemon is loaded once at boot. Until the Mac restarts, every `xcodebuild build`/`test`/`-showdestinations` rejects the run with "simulator device support disabled" + the secondary "platform not installed" error (Xcode treats the iOS 26.5 platform files as unreachable while the simulator runtime is out of date).

This is **operator-side only** — the GitHub Actions hosted runners boot fresh CoreSimulator on every job, so CI is unaffected. Local builds + local UI test runs are blocked until the Mac restarts.

**Workaround used during this session:**

- `swiftc -parse <files>` directly against the iphoneos26.5 SDK: returns exit 0 and validates Swift syntax + type lookups on new source files. Enough to confirm a commit will pass compile-time checks on CI.
- `xcodebuild -list`: parses `project.pbxproj` integrity (target list + scheme list + SPM resolution) without needing a destination. Catches malformed pbxproj edits.
- All real build + test validation delegated to the per-PR CI run on the feature branch. The CI run reliably catches what `swiftc -parse` misses (linker errors, test compile errors, runtime XCTest failures).

**Operator-side fix:** **Full Mac restart.** After restart, `CoreSimulator.framework` loads the on-disk `1051.54.0` binary and `xcodebuild` regains access to the simulator runtimes. The iOS 26.5 platform also becomes resolvable for `generic/platform=iOS` destinations.

**Why the restart is gated:** the restart cannot be performed while HADF Sub-exp 2 is LIVE on the same Mac (~400 records vs 250 kill at this checkpoint per `project_session_2026_05_30_31_hadf_subexp_lifecycle.md`). The Sub-exp 2 dispatch process owns long-running state that does not survive a reboot. The restart window opens **after Sub-exp 2 closes** — at which point the operator can reboot, and the next session's `xcodebuild` invocations will work locally again.

**Generalizable rule:** when `xcodebuild` reports `CoreSimulator is out of date` paired with "iOS X.Y is not installed", trust the diagnostic — do NOT try to install the platform via `xcodebuild -downloadPlatform iOS` (the platform IS installed; CoreSimulator just can't load it). Fall back to `swiftc -parse` for syntax validation, `xcodebuild -list` for pbxproj validation, and defer the real build to CI. Schedule the Mac restart for whenever the next long-running local process (HADF Sub-exp 2 in this case) finishes.

**Sibling patterns:**

- [W17 — Stale-base unmerged branches](#w17--stale-base-unmerged-branches-gh-pr-view-file-list-misleads-cherry-pick-onto-fresh-origin-main-is-ground-truth-2026-05-25) — same "trust the explicit error, don't paper over with workarounds" class.
- HADF launchd setup checklist (memory `feedback-hadf-launchd-setup-checklist`) — adjacent class of "operator-side macOS daemon issues require restart or careful sequence". Both this W28 and the HADF launchd patterns reinforce that fresh-boot daemon state is the reliable recovery path on macOS.

---

### W29 — Inline `import` in a case-study MDX is a no-op under `compileMDX`; JSX components must be registered in `useMDXComponents` (2026-06-04)

**Surfaced by:** fitme-story PR #172 (slot 44, F16 try-repo harness showcase MDX). The squash-merge to `main` broke the production deploy; **6 consecutive deploys failed** (including production `main` at commit `4609aad`) until the fix shipped in [fitme-story PR #175](https://github.com/Regevba/fitme-story/pull/175) (`21da6cf`). The last green production deploy before the break was PR #171.

**Trigger:** A case-study MDX file (`content/04-case-studies/*.mdx`, rendered by `src/app/case-studies/[slug]/page.tsx` via `compileMDX` from `next-mdx-remote/rsc`) references a JSX component and "imports" it inline in the MDX body:

```mdx
import { Callout } from "@/components/mdx/Callout";
...
<Callout type="info">…</Callout>
```

`next build` then fails at static prerender:

```text
Error occurred prerendering page "/case-studies/<slug>".
Error: Expected component `Callout` to be defined: you likely forgot to import, pass, or provide it.
Export encountered an error on /case-studies/[slug]/page → exiting the build.
```

**Why expected:** `compileMDX` compiles only the MDX *body* against the components map the caller passes (here `useMDXComponents({})` from `src/mdx-components.tsx`). It does **not** execute `import` statements written inside MDX content — those lines are inert. A component used in the body must therefore be present in the `useMDXComponents` map, irrespective of any inline import. Two independent faults compounded here:

1. The import path `@/components/mdx/Callout` did not even exist (the real component is `@/components/ui/Callout`) — but this is moot, since the inline import is never run.
2. `Callout` was absent from the `useMDXComponents` map → undefined at render → prerender abort.

Plus a prop mismatch: the MDX passed `type="info"` while `ui/Callout`'s prop is `variant` (which defaults to `'info'`, so it's harmless once the component is registered).

**Silence paths (in order of preference):**

1. **Register the component** in `src/mdx-components.tsx`'s `useMDXComponents` return map (and import it at the top of that file). This is the fix that shipped.
2. **Use an already-registered component** instead — the case-study callout family (`HonestDisclosure`, `TriggerIncident`, `MemoryRef`, `PredecessorChain`, `KillCriterionResolution`). `ui/Callout`'s own docstring directs MDX bodies to prefer these.
3. **Delete the dead inline import** and match the component's real prop names (`variant`, not `type`).

**Same silent-pass class as W15:** PR-level CI (`mdx-render`, `gates`, `unit-tests`, `audit`) all pass — only the (non-required) Vercel preview check fails — so the bug merges to `main` and the first loud signal is the production deploy failing. Same prevention action item as W15: make the Vercel preview a required check in branch protection, or add a real `next build`/prerender step to fitme-story CI. (`mdx-render` alone is insufficient — it compiles MDX but does not prerender against the live components map, so it did NOT catch this.)

**Sibling patterns:**

- [W15 — MDX `<digit` breaks page rendering](#w15--mdx-digit-or--followed-by-non-letter-character-breaks-page-rendering-2026-05-21) — same surface (case-study/doc MDX fails only at the Vercel prerender step while every other CI job passes), different cause (JSX lexer reject vs missing component in the map). Both are "MDX content faults that only the production build catches."
- [W9 — Branch drift from concurrent-session `git checkout` collision](#w9--branch-drift-from-concurrent-session-git-checkout-collision-detected--real-time-alerted) — surfaced again *during* this fix: a concurrent Claude session sharing the fitme-story working tree ran `git checkout` mid-edit and reverted the working-tree changes (the local build had already passed with the edits live, so the empty `git diff` was the tell). The fix was completed in an isolated `git worktree` to escape the shared-tree race.


---

### W30 — Q6 PR-list parity gate's minimal YAML parser silently strips list items lacking `#` (2026-06-04)

**Surfaced by:** FT2 PR #624 (closure of `f-launchd-drift-extension-sub-a`). Spent **4 commit retries** (~15 min wall) trying to satisfy `FEATURE_CLOSURE_COMPLETENESS` Q6 bidirectional PR-list parity before reading the parser source.

**Trigger:** A case-study frontmatter declares `related_prs:` as a YAML list of bare integers:

```yaml
related_prs:
  - 623
  - 621
```

The Q6 gate at [`scripts/check-state-schema.py:1215`](../../scripts/check-state-schema.py#L1215) `_collect_case_study_pr_numbers()` calls `_parse_case_study_frontmatter()` (a hand-rolled minimal YAML parser at line 1125) which stores every list item as a **string** (line 1149: `fm[current_list_key].append(line[4:].strip().strip('"').strip("'"))`). Then the PR-number extractor at line 1224 does:

```python
if isinstance(r, str):
    m = re.search(r'#(\d+)', r)  # ← requires the `#` prefix
    if m:
        prs.add(int(m.group(1)))
elif isinstance(r, int):
    prs.add(r)
```

Bare `- 623` becomes the string `"623"` (no `#`), the regex doesn't match, and the PR is silently dropped from the case-study side of the parity check. The gate then reports "In state.json but missing from case study: [623]" even though `related_prs` clearly lists it.

**Why expected:** the parser was designed for the historically-common `related_prs: ["FT2 #234 (foo)", "fitme-story #88"]` mixed-string form (which IS used in some older case studies). The integer branch (`isinstance(r, int)`) handles the inline `[1, 2, 3]` shape (parsed correctly by the bracket-detection at line 1160), but the line-by-line list-item branch (line 1149) hardcodes a string conversion with no integer fallback.

**Silence paths (in order of preference):**

1. **Use the `"PR #NNN"` string form** in YAML list items: `- "PR #623"`. Matches the regex.
2. **Use the inline `[N, ...]` form** instead of dashed list: `related_prs: [621, 623]`. The bracket branch preserves int types.
3. **Patch the parser** at line 1149 to attempt `int()` conversion of trimmed list items before storing as string. Filed as durable-fix candidate at the v7.9.1+ docket (see "When to lift this into a docket entry" below).

**Durable fix SHIPPED 2026-06-05** — `_collect_case_study_pr_numbers` at [`scripts/check-state-schema.py:1218`](../../scripts/check-state-schema.py#L1218) now accepts bare-digit strings via `str.isdigit()` fallback after the `#N` regex fails. Operator's natural first attempt (`related_prs:\n  - 623`) now works without retries. Test coverage: `scripts/tests/test_w30_w31_w32_durable_fixes.py::TestW30BareIntFallback` (6 tests). Shipped via feature [`framework-w30-w31-w32-durable-fixes`](../features/framework-w30-w31-w32-durable-fixes/state.json).

**Same silent-pass class as W11.b:** a parsing/validation step that returns 0 findings can mean either "all good" OR "the parser couldn't see the data." The W11.b pattern was launchd-cron context producing an empty PR cache; this is a YAML list shape producing an empty PR set. Both required reading the producer code to diagnose, not the consumer's error message.

**When to lift this into a docket entry:** when another operator hits the same 4-retry loop. The current frontend (`"PR #NNN"` form) is documented in the v7.9.1 case-study template at the top of this file's git history, but the empirical evidence is that the gate's error message ("Add the missing PRs to whichever side or list them in case study frontmatter") leads operators to add bare integers first, then bracket-form, then string-form — exactly the order I tried today. Worth a parser patch.

**Sibling patterns:**

- W11.b — empty/stale parser-side data that produces phantom or empty results without any error
- W18/W19 — silent string-vs-typed-value bugs at I/O boundaries (env-var `\n` corruption; URL hardcode at a 404 path)

---

### W31 — Workflow delivery anomaly: initial `pull_request:opened` event sometimes fires only the dynamic/skip-path workflows; rebase + force-push triggers the full set (2026-06-04)

**Surfaced by:** FT2 PR #623 (F-LAUNCHD-DRIFT-EXTENSION sub-fix (a)). The initial `git push -u origin feature/<name>` + `gh pr create` fired **only** CodeQL (dynamic event) + GitGuardian (external app) — exactly 5 checks. The 7 expected `pull_request`-triggered workflows (CI, Lint, PR Integrity Check, try-repo-harness, …) never started. A close+reopen of the PR did NOT re-trigger them. A subsequent **rebase + force-push** DID trigger the full 12-check set immediately.

**Trigger:** specific sequence of mutations on the PR's HEAD between open and merge-ready states. Empirically observed once (2026-06-04 ~15:50 UTC); not yet reproduced. Possible causes:

- GitHub Actions webhook delivery glitch — transient, retried later, but the retry didn't visibly re-deliver to the path-filtered workflows
- `concurrency:` group race — both `ci.yml` and `ci-docs-skip.yml` have `name: CI`; if the post-merge `push: main` run of `ci.yml` for the predecessor PR (#621/#622) was still in-progress when #623 opened, the dispatch of `ci-docs-skip.yml` for #623 may have been cancelled. (Documented prevention via per-file hardcoded `concurrency.group:` prefix already in place — see W26 — so this would mean the cancellation crossed groups.)
- Path-filter evaluation under a particular base-branch state — `ci-docs-skip.yml` uses `paths-ignore`; if the PR's diff base briefly showed an iOS-touching file, the inverse filter would have skipped this workflow

**Why expected:** GitHub Actions webhooks are at-least-once-best-effort, not strictly guaranteed. The PR header's status-check-rollup shows whatever's been delivered, not whatever the workflow definitions theoretically *would* run.

**Silence paths (in order of preference):**

1. **Rebase + force-push.** Empirically forces the `synchronize` event with a clean lineage. The full workflow set fired within 10s on PR #623.
2. **Manual `gh workflow run <name>.yml --ref <branch>`** dispatches workflows individually via `workflow_dispatch`, but those runs do NOT post check-runs to the PR's status rollup — they confirm code health but don't unblock the merge button.
3. **Close+reopen the PR.** Should fire `pull_request:reopened` for any workflow listening on that event. Did NOT work in the 2026-06-04 incident; unclear why. May be partially-reliable.

**Same silent-pass class as W26:** workflow non-execution looks identical to workflow-pass at the PR-header level — both produce no failing check. The operator's signal is "the expected check count is lower than usual," which is invisible unless they know what to expect.

**Prevention action item:** add a CI smoke-test or pre-merge sanity check that asserts the expected workflow set has run. The pm-framework PR-integrity bot already does this for its own check; could extend to a "required workflows present" assertion.

**Durable fix SHIPPED 2026-06-05 (operator-side detection, not CI enforcement)** — [`scripts/check-pr-workflow-coverage.py`](../../scripts/check-pr-workflow-coverage.py) compares a curated `ALWAYS_EXPECTED_PATTERNS` list against the PR HEAD SHA's actual check-runs + commit statuses. Surfaces missing always-expected checks with the rebase + force-push remediation hint inline. Validated against PR #636 (14/14 ✓ no false positives) + PR #623 (the W31 incident PR — correctly flags 2 historical missing checks). Test coverage: `scripts/tests/test_w30_w31_w32_durable_fixes.py::TestW31CoverageScriptExists` (3 tests). Operator invocation: `python3 scripts/check-pr-workflow-coverage.py <PR_NUMBER>`. Choice of operator-side detection vs CI enforcement is intentional — the rebase workaround is bounded + reliable; the value is detection + nudge, not a blocking gate.

**Sibling patterns:**

- W26 — Two workflows sharing `name:` clash in `${{ github.workflow }}` concurrency groups → cross-workflow cancellation
- W11.b — invisible silent-pass at the cron context level (different layer; same "empty result looks like success" failure mode)

---

### W32 — `scripts/close-feature.py` requires `--force-incomplete` when the merged PR was the only phase (implementation → complete directly, no testing phase) (2026-06-04)

**Surfaced by:** FT2 PR #624 closing `f-launchd-drift-extension-sub-a`. The feature ran as a single-phase `Feature` (work_subtype `framework_feature`) that ships its own unit tests during implementation. At merge time `current_phase` was `implementation`, NOT `testing`. `make close-feature FEATURE=...` aborted with:

```text
⚠ 'f-launchd-drift-extension-sub-a' is at current_phase=implementation —
  earlier than 'testing'. This usually means PR #623 was a partial-phase
  landing and the feature isn't actually done. Closing now would skip the
  remaining phases. If you still want to close (the PR was the final
  landing), re-run with --force-incomplete.
```

**Trigger:** any feature where:

- The work is small enough that implementation + tests ship in one PR (no separate testing phase)
- The gate ships as ADVISORY so no calibration window applies (no separate "complete" phase needed before the soak)
- OR the feature is a sub-fix follow-on to a parent that already covered the testing phase

**Why expected:** the script's heuristic protects against the common mistake of "operator merged a partial-phase PR and forgot the remaining phases exist." It assumes `testing` is always between implementation and complete. For framework-internal sub-fixes that are tested in-phase, this is wrong.

**Silence paths (in order of preference):**

1. **Use `python3 scripts/close-feature.py <feature> --force-incomplete`** to bypass. (The `make close-feature` target does NOT pass through this flag — must call the script directly.)
2. **Pre-set `current_phase` to `testing`** in state.json before merging, then close-feature accepts it. Only correct if a testing phase actually happened.
3. **Patch `scripts/close-feature.py`** to recognize a state.json field like `single_phase: true` or `work_subtype: framework_feature` + ADVISORY-mode gates as a structural skip. Filed as durable-fix candidate.

**Durable fix SHIPPED 2026-06-05** — `close_feature()` at [`scripts/close-feature.py:138`](../../scripts/close-feature.py#L138) auto-skips the `--force-incomplete` requirement when state.json declares a single-phase work shape: `work_subtype=framework_feature` OR `work_type in {Chore, Fix}` OR explicit `single_phase: true`. Operator still gets an audit-trail log line (`ℹ W32 auto-skip: ...`) so the bypass is visible. Regular `Feature` work_type still requires `--force-incomplete` for safety (test `test_regular_feature_still_requires_force_incomplete` enforces). Test coverage: `scripts/tests/test_w30_w31_w32_durable_fixes.py::TestW32SinglePhaseAutoSkip` (7 tests). Same-session retrospective: the 5 v7.9.1 features closed earlier today (PR #633 + PR #636) would have closed cleanly without the `--force-incomplete` flag.

**When to lift this into a docket entry:** when another framework feature ships as single-phase. The pattern showed up today on a v7.9.1 sub-fix; will likely show up again on every sub-fix that's mechanical enough to ship in one phase.

**Sibling patterns:**

- W27 — `make preflight` enhancement_parent false-positive: similar shape (heuristic gate firing on a legitimate-but-uncommon work shape)
- W30 — Q6 PR-list parity gate's YAML parser quirk (same session): both are "framework gate misinterprets a valid input"
---

### W33 — Pattern↔skill preflight overlay: catalog patterns mapped per skill + probed at activation (2026-06-04)

**Surfaced by:** the `pattern-skill-preflight-overlay` framework feature (this entry is the mandatory self-doc per the §v7.8.5 append-on-novel rule). Not a failure mode — a tooling addition that operationalizes THIS catalog. Originally numbered W29 in the feature branch (opened 2026-06-04 10:29 UTC); renumbered W33 during rebase because PRs #620/#621/#623/#625 landed W29-W32 the same afternoon with non-overlay content.

**What it is:** before the overlay, each of the 12 skills referenced the catalog generically ("23 gate + 28 workflow patterns; here are a few highest-leverage ones") and operators discovered blockers reactively, mid-work, when a gate fired. The overlay makes the catalog↔skill relationship explicit and proactive:

1. **Source of truth** — [`.claude/shared/pattern-skill-map.json`](../../shared/pattern-skill-map.json) maps each of the **58** work-blocking catalog patterns (25 gate `#1`–`#25` + 33 workflow `W1`–`W32`, `W34`–`W37`) to the skill(s) whose work it can block, plus `{detector, blocker, autoheal, remediation}`. Many-to-many — a pattern can block several skills.
2. **HYBRID probing** — `make skill-preflight SKILL=<name>` (→ [`scripts/skill-preflight.py`](../../../scripts/skill-preflight.py)) selects the skill's mapped patterns, *probes* the mechanized ones (`integrity-check`, `ensure-pr-cache-fresh`, `check-ssh-agent`, `check-branch-drift`, workflow-name collision), and emits an *awareness checklist* for the manual/compile/discipline ones. Writes an additive `skill_overlay.<skill>` block to `.claude/shared/preflight-cache.json`.
3. **Self-generating docs** — [`scripts/generate-skill-preflight-sections.py`](../../../scripts/generate-skill-preflight-sections.py) (`make gen-skill-preflight`) regenerates the table inside each SKILL.md's preflight section between `<!-- BEGIN pattern-preflight (generated) -->` / `<!-- END pattern-preflight -->` delimiters. Idempotent.
4. **Self-auditing** — `integrity-check.py`'s `PATTERN_SKILL_UNMAPPED` advisory flags any catalog ID absent from the map (or mapped to zero skills), so the map can't silently fall behind the append-only catalog.

**Why expected:** this is the catalog graduating from a passive reference into an active preflight surface. As the catalog grows, the map + the `PATTERN_SKILL_UNMAPPED` advisory keep them in lockstep.

**Operator obligation:** when you append a NEW catalog pattern, also (a) add it to `pattern-skill-map.json` with ≥1 skill, then (b) run `make gen-skill-preflight`. The `PATTERN_SKILL_UNMAPPED` advisory reminds you if you forget (a).

**Note on this entry's own mapping:** W33 documents the overlay *tool*, not a work-blocking pattern, so it is intentionally NOT in `pattern-skill-map.json` and is exempted from `PATTERN_SKILL_UNMAPPED` (via the `SELF_DOC_EXEMPT` set in `integrity-check.py`). The map tracks the 58 work-blocking patterns only.

**Silence path:** none needed — informational tooling surface.

**First observed:** 2026-06-04 (`feature/pattern-skill-preflight-overlay`). Full how-to: [`docs/skills/pattern-skill-overlay.md`](../../../docs/skills/pattern-skill-overlay.md).

**Sibling patterns:** [W20 — Stale-session-state inventory drift](#w20--stale-session-state-inventory-drift-2026-05-28) (both are "surface the right context BEFORE work, not reactively"); the `make preflight` unified entry point (v7.8.6) — the overlay is its per-skill, pattern-aware companion.

### W34 — PR cache window truncation past the 500-PR limit (2026-06-05)

**Surfaced by:** the 2026-06-05 data-integrity health check. The SessionStart regression flag reported **39 integrity findings** (52 total at the 2026-06-04 daily checkpoint) where the prior day had 0. Every finding was a `BROKEN_PR_CITATION` or `PR_NUMBER_UNRESOLVED` citing an *old, legitimately-merged* low-numbered PR (#12, #59, #61, #65, #67, #74, #76, #78, #80–#92).

**Root cause:** [`scripts/refresh-pr-cache.py`](../../../scripts/refresh-pr-cache.py) fetched each state bucket with `gh pr list --limit 500`. FT2 crossed **500 merged PRs**, so the merged window's floor rose to **#93** and the closed window's to **#116**. Every citation below the floor fell out of the cache and read as "does not resolve." This is the THIRD variant of the PR-cache failure class, distinct from its siblings:

- **#12 `PR_CACHE_STALE`** — cache empty / missing / >24h old.
- **W11** — cache present + fresh but one expected *repo* absent.
- **W34 (this)** — cache present, fresh, both repos populated, but the *most-recent-N window* no longer reaches old PR numbers because the repo grew past the per-state `--limit`.

**Why the freshness gate missed it:** `ensure-pr-cache-fresh.py` checks emptiness, repo-presence, and age — NOT whether the numeric window still covers historically-cited PRs. The cache was 10h old, non-empty, both repos present → freshness check passed → truncated window served stale-floor lookups.

**Detection / artifact (skip):** ALL false findings cite PR numbers *below a sharp floor* (here #93) while every citation above resolves fine. Confirm with:
```bash
python3 -c "import json; v=json.load(open('.cache/gh-pr-cache.json'))['repos']['Regevba/FitTracker2']; \
ns=sorted({x['number'] for b in('open','merged','closed') for x in v[b]}); print('floor',ns[0],'ceil',ns[-1],'count',len(ns))"
# floor far above 1 (e.g. 93) while the repo's true min PR is 1 ⇒ window truncation
```

**Remediation:** raised the per-state limit to `--limit 2000` (covers FT2's 571 PRs + headroom; re-refresh writes 1465 PRs across both repos). After refresh, `make integrity-check` returned to **0 findings + 5 advisory**. The cap should be revisited if either repo approaches 2000 PRs.

**Silence path:** none — the fix removes the false floor. Going forward the limit must exceed each repo's total PR count.

**First observed:** 2026-06-05 (data-integrity health check). **Sibling patterns:** [#12 `PR_CACHE_STALE`](#12-pr_cache_stale-v784--emptystale-cache--cascading-false-positives), [W11 — Incomplete PR cache](#w11--incomplete-pr-cache-one-of-two-expected-repos-absent).



### W35 — Hook session-id keyed on a never-set env var → constant `"default"` → cross-session marker suppresses the gate forever (2026-06-14)

**Surfaced by:** a pre-promotion W9 audit (2026-06-14) before flipping `CLAUDE_W9_CONCURRENCY_ENFORCE` default-on. The Phase-2 concurrency calibration window (2026-06-07 → 2026-06-20) had collected **zero** valid telemetry; every `w9.auto_isolate` row in the window came from Phase-1 drift, not the Phase-2 path under calibration.

**The pattern (generalizes beyond W9):** a hook script derives a per-session key from `os.environ.get("CLAUDE_SESSION_ID", "default")`. But Claude Code delivers the session id on the hook's **stdin JSON** (`session_id` field), NOT as an environment variable — so the env read always returns the fallback. Every session shares the constant `"default"` key. Two failure shapes follow:

1. **Once-per-session marker becomes once-ever.** `w9_concurrency_check.py` wrote `.claude/_session-state/default-w9-concurrency.done` on first edit, then `_already_fired()` short-circuited every subsequent session. The gate ran exactly once (2026-06-07) and was silent thereafter — its calibration gathered no data.
2. **Per-session baseline becomes a shared baseline.** `check-branch-drift.py` compared against one shared `default-branch.txt`, so it could not tell "this session deliberately ran `git checkout`" from "another session flipped HEAD." 45 logged "drift" rows were near-100% false positives from intentional branch switches.

**Why no gate caught it:** the two W9 phases shared the gate name `w9.auto_isolate`. Phase-1 drift kept `candidates > 0`, so the v7.10 `GATE_COVERAGE_ZERO` 0-candidate mis-wire detector saw a "healthy" gate and never flagged the dead Phase-2 path. **A shared gate name masks a dead sibling check.** (Sibling of `#24` field-rename-reader: one producer/consumer updated, the other silently disjoint.)

**Detection:**
```bash
# A gate whose telemetry all carries one outcome from one code path, while a
# second documented code path for the same gate name emits nothing:
grep '"w9.auto_isolate"' .claude/logs/gate-coverage.jsonl | \
  python3 -c "import json,sys,collections; c=collections.Counter(json.loads(l).get('outcome') for l in sys.stdin); print(c)"
# Constant 'default' markers piling up across sessions:
ls .claude/_session-state/default-*.done .claude/_session-state/default-*.txt 2>/dev/null
```

**Remediation (feature `fix/w9-session-id-keying`):**
1. Centralized session-id resolution in [`scripts/w9_session.py`](../../scripts/w9_session.py): env override → hook-stdin `session_id` payload → `"default"` last resort (read non-blocking so tests/manual runs don't hang).
2. Phase 2 emits a **distinct gate `w9.concurrency`** so `GATE_COVERAGE_ZERO` observes it independently.
3. Phase-1 drift suppresses intentional checkouts via `evaluate_drift(expected, current, command)` (reads `tool_input.command` from the payload; `git checkout`/`switch`/`worktree add` ⇒ `intentional`, no alert).
4. Reaped the 38-day-stale lease from `agent-leases.json`; cleared the broken `default-*` markers.
5. Calibration window **reset** — re-evaluate against `w9.concurrency` rows at fix-merge + 14d.

**Silence path:** none needed — the fix is correct-by-construction; tests in [`scripts/tests/test_w9_session.py`](../../../scripts/tests/test_w9_session.py) + the new cases in `test_w9_auto_isolate.py` lock the behavior.

**General lesson:** when a hook needs the session id, read it from the **hook payload (stdin)**, never from an env var the platform doesn't set. When one gate name has two producers, give each its own name so the silent-pass detectors can see each independently.

**First observed:** 2026-06-14. **Sibling patterns:** [#24 field-rename reader/index mismatch](#24--field-rename-readerindex-mismatch-the-createdcreated_at-class-generalized-to-the-measurement-layer), W9 (the feature this lives in).

### W36 — A plan/seat-gated external capability documented as "operational" while it never once succeeded (2026-06-15)

**Surfaced by:** a full design-system audit (2026-06-15). The Figma Code Connect bridge was presented across CLAUDE.md + `figma-code-sync-status.md` as "Synced (auto-built)" / "operator setup complete (2026-05-10)", but the `figma-code-connect-publish.yml` workflow had **failed on every real run since 2026-05-10** in both repos, and the live Figma files were empty/partial.

**The pattern (generalizes beyond Figma):** a capability gated by an **account plan or seat entitlement** gets full scaffolding — a CI workflow, a repo secret, generated mapping/config files, and docs — and the scaffolding's *presence* is mistaken for the capability *working*. Here Code Connect requires a Figma Org/Enterprise plan; the account is Pro, so:
- iOS publish → HTTP **403 "Invalid scope(s): need File Read + Code Connect Write"** (scope not grantable on Pro).
- web publish → **W14**: page-frame mappings (`31-3`/`31-106`) abort validation.

Every signal an operator usually trusts was green-ish: the workflow file existed, the `FIGMA_ACCESS_TOKEN` secret existed, `.figma.{swift,tsx}` files existed, and the docs said "Synced." Only the *run history* (all red) and the *live Figma state* (empty) told the truth. One state.json (`code-connect-automation`) had honestly recorded the blocker, but the high-visibility surfaces had not.

**Detection:**
```bash
# A publish/deploy workflow that is "set up" but has never actually succeeded on a real run:
gh run list --workflow=<name>.yml --limit 20 | grep -c success   # scaffold runs only?
gh run view "$(gh run list --workflow=<name>.yml --status failure --limit 1 --json databaseId -q '.[0].databaseId')" --log-failed | grep -iE '403|invalid scope|not a component|plan|enterprise'
# For Figma specifically — does the live file actually contain the claimed nodes?
#   MCP get_metadata (no nodeId) → if only a "Cover" page exists, the library is empty.
#   MCP get_code_connect_map → "need a Developer seat in an Organization or Enterprise plan" = plan-gated.
```

**Remediation (2026-06-15):** disabled both publish workflows to manual-only stubs (no more red runs); reconciled CLAUDE.md + `figma-code-sync-status.md` + `ios-code-connect-workflow.md` to state code-is-source-of-truth + Code Connect unavailable on Pro; recorded honesty-ledger [FT2-FH-005]; wrote the rebuild plan `docs/design-system/figma-source-of-truth-plan-2026-06-15.md` (make Figma a visual mirror via the MCP plugin API, which *does* work on Pro).

**General lesson:** treat a plan/seat-gated capability as an **external dependency** and verify it end-to-end (did it actually publish/deploy?) before any doc says "operational" or "setup complete." Scaffolding present ≠ pipeline working. A workflow's *run history*, not its *existence*, is the source of truth.

**First observed:** 2026-06-15. **Sibling patterns:** [W14 — Code Connect rejects page frames](#w14), FT2-FH-005 (honesty ledger), #24 (reader/producer disjoint).

### W37 — Bot-authored (GITHUB_TOKEN) PR can never satisfy required checks under `strict` branch protection → permanent "expected" deadlock (2026-06-15)

**Surfaced by:** the 2026-06-14 docs-quirk root-cause analysis across the last 200 PRs (since `ci-docs-skip.yml`, #558). Empirically: human docs-only PRs merge cleanly (104/108), but **all 13 GITHUB_TOKEN-authored PRs needed an operator web-UI admin-merge, and 3 were abandoned (#614, #676, #706)**. Distinct from W35 (which was a session-id keying bug); this is a CI/branch-protection interaction.

**The pattern:** a workflow opens (or updates) a PR using the default `GITHUB_TOKEN`, on a repo whose `main` has classic branch protection with `required_status_checks.strict = true` + `enforce_admins = true`. Two compounding failures:

1. **GITHUB_TOKEN recursion-prevention:** commits/PRs created with `GITHUB_TOKEN` do **not** trigger `pull_request` workflows. So `ci-docs-skip`/`pr-integrity` never run on the bot head → a required context can be entirely **absent** (proven: #614's head had `integrity` ×2 + CodeQL etc. but **no `Build and Test` check-run at all**) → unsatisfiable → hard deadlock.
2. **`strict` (require-up-to-date):** even when checks DID run and succeed (#676/#706), once `main` advances the bot PR goes BEHIND; `update-branch` makes a new bot-authored head that again won't trigger CI → required contexts revert to "expected." The API `--admin` merge is refused ("N of N required status checks are expected"); only the **web-UI admin bypass** works (hence every bot-PR merge shows `mergedBy=<operator>`).

`ci-docs-skip` fixed the human case but architecturally **cannot** help bots — the bot's `pull_request` event never reaches it.

**Detection:**
```bash
# Bot PRs that deadlocked: author is app/github-actions, BEHIND, required checks absent on head
gh pr list --repo <repo> --state open --json number,author,mergeStateStatus \
  --jq '.[]|select(.author.login=="app/github-actions" and .mergeStateStatus=="BEHIND")|.number'
# Confirm an absent required context on the head SHA:
gh api repos/<repo>/commits/<sha>/check-runs --jq '[.check_runs[]|select(.name=="Build and Test")]|length'  # 0 = absent
```

**Remediation (option B, shipped 2026-06-15):** the three ledger/snapshot workflows (`integrity-cycle.yml`, `framework-status-weekly.yml`, `ucc-audit-log-sync.yml`) write **append-only** machine ledgers, so they no longer open a PR — they **commit + push straight to `main`** (primary path), falling back to the legacy create-PR path only if the push is rejected (graceful, no-regression before the bypass is configured). Activation requires a one-time operator step: add the `github-actions` app to `main`'s `bypass_pull_request_allowances` (classic protection) so the bot push skips the PR requirement. Reversible by removing it.
**Alternative (option A, not chosen):** mint a GitHub App token (`actions/create-github-app-token`) for the PR so it triggers CI + `enable-auto-merge`.

**Silence path:** none — the fix removes the bot PR entirely. Until the bypass is added the workflows self-heal to the old PR path (operator still hand-merges, as before).

**Manual unblock recipe — VERIFIED 2026-06-16 (corrects the "only the web-UI admin bypass works" claim in failure #2):** the API `gh pr merge --admin` **does** work, and a deadlocked bot PR **can** be made to fire its required checks — as long as the *operator's user token* (not the bot) drives the update:

1. `gh pr update-branch <N>` run by the operator creates a merge commit authored by the **user**, which **does** trigger `pull_request` CI. The recursion-prevention only suppresses `GITHUB_TOKEN`-authored events, so `integrity` + `Build and Test` run and pass even on `.claude/shared/*`-only changes — there is no real path-filter exclusion for these ledger paths.
2. Poll until the required contexts are green on the **new** head, then `gh pr merge <N> --squash --admin --delete-branch`. The `--admin` API merge **succeeds** for a repo admin despite `enforce_admins=true`, once the up-to-date head carries the green required contexts. It is refused only while the branch is `BEHIND` ("N of N required status checks are expected") — which step 1 resolves.

Applied 2026-06-16 to clear #741 (already up-to-date → direct `--admin`) and #716 (`BEHIND` → operator `update-branch` → CI re-ran green → `--admin`). Both merged via the API (`mergedBy=Regevba`), no web UI needed. This is the fast manual path until the option-B operator bypass is configured; option B remains the durable fix that removes the bot PR entirely.

**First observed:** recurring since 2026-06-04 (#614). Root-caused 2026-06-14; fixed 2026-06-15. **Sibling patterns:** W35 (W9 session-id), [#12 PR_CACHE_STALE], W11/W34 (cache window). **Note:** numbered W37 because W36 was concurrently claimed by the Figma plan-gating pattern (2026-06-15).

### W38 — Figma read tools (`get_metadata`/`get_screenshot`/`get_design_context`) reflect the DESKTOP-APP context, not the `fileKey` you pass → false "empty file" reads (2026-06-18)

**Surfaced by:** the `figma-design-architecture` T1 audit. Auditing the iOS design-system library (`0Ai7s3fCFqR5JXDW8JvgmD`), `get_metadata` (no nodeId) returned **only a single "Cover" page**, `get_variable_defs(985:2)` returned **"invalid node"**, and `get_design_context` showed a placeholder frame — together reading as **0% fidelity**, which tripped the PRD kill criterion and led the operator to approve a full mirror **rebuild**. Before any write, an authoritative `use_figma` plugin-API read of the **same fileKey** showed the file is actually **comprehensive**: 28 pages (Foundations `10:3`, Components `10:5` with 18 variant-matrix component sets), 198 variables across 8 collections incl. the 80-var code-mirror collection `985:2` whose values match `tokens.json` exactly. The rebuild was cancelled (no Figma mutation performed) and the finding retracted.

**The pattern:** the MCP read tools `get_metadata`, `get_screenshot`, and `get_design_context` operate against the **Figma desktop app's currently-open file / selection context**, NOT necessarily the file addressed by the `fileKey` argument. When the desktop app is showing a different, stale, or near-empty view (here: a "Cover-only" state), these tools return data for *that* view and silently disagree with the file you think you're inspecting. `use_figma` runs the Plugin API against the `fileKey` directly and is authoritative. A `VariableCollectionId` (e.g. `985:2`) is also **not** a scene-node ID, so `get_variable_defs`/`get_metadata` correctly reject it as "invalid node" even when the collection exists — a second false-negative trap.

**Detection / remediation:**
- For a **specific `fileKey`**, trust `use_figma` plugin-API reads (`getLocalVariableCollectionsAsync`, `figma.root.children`, `findAll`). Treat `get_metadata`/`get_screenshot`/`get_design_context` as desktop-context-dependent — confirm with `use_figma` before acting on an "empty / missing / invalid" result.
- Never trip a kill criterion or approve a destructive rebuild on a single read-tool result that says "empty." Cross-check with the authoritative tool first (cost: one `use_figma` call).
- Variable collections aren't scene nodes — don't pass a `VariableCollectionId` to node-addressed read tools.

**Silence path:** none needed — this is a read-discipline pattern, not a gate. The lesson is encoded in [`ios-design-system-architecture.md`](../../docs/design-system/ios-design-system-architecture.md) §6 (verification via `use_figma`) and the fidelity-audit report's Tooling Note.

**First observed:** 2026-06-18 (`figma-design-architecture` T1). **Sibling patterns:** none direct; conceptually adjacent to W36 (a capability's *claimed* state diverging from its *real* state) — here the divergence was in the audit tool, not the artifact.

### W39 — A breaking-change major-version Dependabot bump cannot auto-merge; it churns as repeated closed-unmerged PRs until a human ships a golden-verified manual migration (2026-06-18)

**Surfaced by:** the 2026-06-18 closed-vs-merged PR-corpus scan (Group B = 43 closed-unmerged PRs). The `style-dictionary` 3.9.2 → 5.x upgrade produced a four-PR sequence, three of them closed-unmerged:

| PR | What | Outcome |
|---|---|---|
| #440 | Dependabot auto-bump → 5.4.1 | closed unmerged (66h) |
| #668 | Dependabot auto-bump → 5.4.3 | closed unmerged (4.7h) |
| #596 | manual `style-dictionary-v3-to-v5-migration` | **CI Failed / "No logs captured"**, closed |
| **#677** | `build(tokens): migrate v3 → v5 (golden-verified, closes #668)` | **MERGED 2026-06-08** |

**The pattern:** a major-version bump of a build-time dependency whose new major *removed the API the config depended on* (here: Style Dictionary v5 dropped the v3-era format/transform API that `sd.config` used) is **not a version-string change** — it is a code migration. Dependabot can only edit the version, so its PR builds against the old config and either fails CI or (worse) passes a thin CI that doesn't exercise the broken path. Each auto-bump PR is closed, Dependabot re-proposes the next patch of the same major, and the cycle repeats until a human writes the migration. The *successful* PR is hand-authored, **golden-file-verified** (output diffed against a pinned expected artifact), and explicitly closes the Dependabot PR. This was flagged as a "W29 candidate" on 2026-06-02 but never catalogued — catalog W29 became the MDX-import pattern instead, leaving this gap open until the corpus scan re-surfaced it.

**Detection / remediation:**

- Treat a major-version Dependabot PR on a *build-time* dep (bundler, token compiler, codegen, lint engine) as a **migration ticket, not a merge** — close the auto-bump, open a hand-authored migration branch.
- Gate the migration on a **golden-file diff** (regenerate the committed artifact, assert byte-identical to a pinned expected) so "CI green" actually means "output unchanged," not "version string parses." See the `tokens:android:check` / `tokens-check` drift-gate pattern.
- Watch for the repeat-bump tell: ≥2 closed Dependabot PRs for the *same package's same major* is the signal that a manual migration is overdue.
- Distinct from W29 (Dependabot major-bump that passes CI but breaks `main` post-merge) — W39 is the case where the PRs **never merge at all** and churn as closed-unmerged exhaust.

**Silence path:** none — this is a triage-discipline pattern, not a gate. Optionally add the package to `.github/dependabot.yml` `ignore: [{ update-types: ["version-update:semver-major"] }]` once a manual-migration policy is adopted for it, so the auto-bump churn stops.

**First observed:** 2026-06-18 (closed-PR-corpus scan; root incident 2026-05-29 → 2026-06-08, style-dictionary v3→v5). **Sibling patterns:** W29 (post-merge break vs this never-merges), W16/`tokens-check` (golden/canonical-sample verification as the real gate).
