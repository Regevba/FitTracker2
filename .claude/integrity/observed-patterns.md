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

---

## Source provenance

- Gate-firing patterns mined from: case studies, framework honesty ledger, master plans, integrity-cycle snapshots, PR descriptions, Mechanism A coverage telemetry
- Workflow patterns mined from: `~/.claude/projects/-Volumes-DevSSD-FitTracker2/memory/feedback_*.md`
- Cross-referenced against: `scripts/check-state-schema.py`, `scripts/integrity-check.py`, `.claude/integrity/README.md`

Last refreshed: 2026-05-13.
