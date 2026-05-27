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

**Trigger:** `scripts/tests/test-v7-5-pipeline.sh` fixtures fail because new gates require fields the fixtures don't have.

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

**First observed:** 2026-05-13 across three separate sessions today (analytics spec completion → spec planning batch → this very session creating W9). Hit the same pattern three times in one day. Detection script + real-time alert hook shipped this session to ensure it never costs investigative time again.

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

---

## Source provenance

- Gate-firing patterns mined from: case studies, framework honesty ledger, master plans, integrity-cycle snapshots, PR descriptions, Mechanism A coverage telemetry
- Workflow patterns mined from: `~/.claude/projects/-Volumes-DevSSD-FitTracker2/memory/feedback_*.md`
- Cross-referenced against: `scripts/check-state-schema.py`, `scripts/integrity-check.py`, `.claude/integrity/README.md`

Last refreshed: 2026-05-25 (added W17 — stale-base branch detection, v7.9.1 candidate F-STALE-BASE-DETECTION).

---

### W11 — `make preflight` enhancement_parent false-positive (2026-05-19)

**Trigger:** Running `make preflight WORK_TYPE=enhancement FEATURE=<name>` blocks with `enhancement_parent: parent='<feature>' phase=tasks, prd.md present=False` even when the actual parent feature (referenced by `state.json::parent_feature`) IS complete with a PRD.

**Why expected:** `scripts/preflight.py::enhancement_parent_state()` checks the ENHANCEMENT FEATURE'S own `prd.md` and `current_phase`, instead of resolving `state.json::parent_feature` and checking THAT feature. Pure heuristic bug — the check is mis-aimed.

**Signal vs noise rule:** Always noise when the enhancement is legitimately scoped (state.json has `parent_feature` set + parent is `complete`). Signal only if no `parent_feature` field exists in state.json (real misconfiguration).

**Silence path (Option A, workaround):** Write a thin "delta PRD" stub at `.claude/features/<enhancement>/prd.md` listing primary/secondary/guardrail metrics + kill criteria. Re-run preflight; the `prd.md present=True` check passes (but `phase=tasks` still trips the blocker — accept this as known-noise OR run preflight with `FEATURE=<parent>` for verification only).

**Silence path (Option B, durable fix):** Patch `scripts/preflight.py::enhancement_parent_state()` to read `state.json::parent_feature` and resolve the check against THAT feature. Queue as a v7.9.1 candidate; tracked in [`docs/master-plan/ucc-hardening-infra-overlay-2026-05-19.md`](../../docs/master-plan/ucc-hardening-infra-overlay-2026-05-19.md) R7.

**First surfaced by:** `ucc-passkey-auth-security-hardening` enhancement work, 2026-05-19. The work proceeded with Option A.

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
