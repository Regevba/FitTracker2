# FitMe (FitTracker2) — Project Rules

> **Canonical repo location:** `/Volumes/DevSSD/FitTracker2`
>
> The project lives on an external SSD at `/Volumes/DevSSD/FitTracker2`, not
> on the Mac's internal storage. All build artifacts (Xcode DerivedData, SPM
> cache, npm cache, Python venvs, clang module cache, simulator data) are
> kept under `.build/` inside the repo, which is already on the SSD. Any
> absolute paths in documentation, commit messages, handoffs, or scripts
> should reference `/Volumes/DevSSD/FitTracker2` when pointing at the local
> repo — never `/Users/{name}/` or `/tmp/`. Setup details live in
> `docs/setup/ssd-setup-guide.md`.
>
> Agents running in sandboxed environments may see a different working
> directory path (e.g. `/home/user/FitTracker2`). That's the sandbox mount
> of the repo, not the real location. Files written inside the sandbox are
> the user's real files, but human-readable paths in docs should always
> point at the SSD.

## Product Management Lifecycle

Every new feature MUST follow the PM workflow. Invoke with `/pm-workflow {feature-name}`.

**Phases:** Research → PRD → Tasks → UX/Integration → Implement → Test → Review → Merge → Docs

**Non-negotiable rules:**
1. No phase is skipped. Every phase requires explicit user approval.
2. No PRD without success metrics. Every feature defines: primary metric, baseline, target, kill criteria.
3. No merge without CI. Both feature branch AND main must be green.
4. Data drives decisions. Research, metrics, and kill criteria guide the lifecycle.
5. Post-launch metrics review is mandatory at the cadence defined in the PRD.
6. Phase transitions auto-sync to GitHub Issue labels (dashboard updates automatically).
7. Manual overrides allowed — user can move features forward (skip) or backward (rollback) at any time. Skipped phases are recorded in the audit trail.
8. Conflicts between state.json and GitHub Issues are resolved by asking the user.

## Work Item Types

Not everything needs the full 9-phase funnel:
- **Feature** — Full lifecycle (Research → PRD → Tasks → UX → Implement → Test → Review → Merge → Docs). New capabilities requiring research, PRD, design.
- **Enhancement** — 4-phase (Tasks → Implement → Test → Merge). Improvements to shipped features. Parent feature must already have a PRD.
- **Fix** — 2-phase (Implement → Test). Bug fixes, error handling, security patches.
- **Chore** — 1-phase (Implement). Docs, config, refactoring, dependency updates.

Use `/pm-workflow {name}` and select the work type. Skipped phases are recorded in the audit trail with reason `work_type:{type}`.

## Branching Strategy

- **Large features** (>5 files changed OR new models/services) → `feature/{name}` branch
- **Small fixes** (<5 files, no new models) → direct task branch
- **Before merge:** parallel code review — diff feature vs main, identify risk areas
- **CI requirement:** both branches must pass before merge is approved
- **High-risk areas** that require extra review: DomainModels.swift, EncryptionService.swift, SupabaseSyncService.swift, CloudKitSyncService.swift, SignInService.swift, AuthManager.swift, AIOrchestrator.swift

## Data Integrity Framework (v7.5 → v7.6 → v7.7 → v7.8, shipped 2026-04-24 → 2026-04-25 → 2026-04-27 → 2026-05-04)

The 72h Integrity Cycle shipped at v7.1 is now one of **eight cooperating defenses** in the v7.5 Data Integrity Framework — triggered by the 2026-04-21 Google Gemini 2.5 Pro independent audit. v7.6 (Mechanical Enforcement, shipped 2026-04-25) closes the remaining Class B → Class A gap by promoting four silent agent-attention checks into pre-commit failures and adding two recurring CI defenses (per-PR review bot, weekly framework-status cron).

**Write-time gates (fire on `git commit`):**
- `SCHEMA_DRIFT` — pre-commit hook rejects legacy `phase` key; canonical is `current_phase`. Install via `make install-hooks`.
- `PR_NUMBER_UNRESOLVED` — pre-commit hook verifies `phases.merge.pr_number` against a cached `gh pr list` result before state.json can record it; skipped gracefully when `gh` is unavailable.
- `PHASE_TRANSITION_NO_LOG` (v7.6) — pre-commit hook rejects a `current_phase` change in a state.json without a corresponding event in `.claude/logs/<feature>.log.json` within the last 15 minutes.
- `PHASE_TRANSITION_NO_TIMING` (v7.6) — pre-commit hook rejects a `current_phase` change without `timing.phases.<new_phase>.started_at` and, when there was a previous phase, `timing.phases.<old_phase>.ended_at`. **T16 note (v7.7):** this hook means the timing-backfill scenario resolved by v7.7 T15 (push-notifications, import-training-plan, stats-v2 had zero timing coverage because they predated mechanical enforcement) will not recur for any feature created post-v7.6. The v7.7 T15 pass addresses pre-existing data debt only — no further backfill is required for features that advanced phases after 2026-04-25.
- `BROKEN_PR_CITATION` (v7.6, write-time) — pre-commit hook rejects case-study commits that cite `PR #N` or `pull/N` if the number does not resolve in the cached `gh pr list` result; skipped gracefully when `gh` is unavailable. Cycle-level `BROKEN_PR_CITATION` still runs as a safety net.
- `CASE_STUDY_MISSING_TIER_TAGS` (v7.6) — pre-commit hook rejects scoped case-study commits (forward-only, dated ≥ 2026-04-21) when the file has no T1/T2/T3 tier tag at all. It checks tag presence, not every quantitative claim.

**Cycle-time gates (fire every 72h via GitHub Actions):**
Runs [`scripts/integrity-check.py`](scripts/integrity-check.py) against every `.claude/features/*/state.json` and every `docs/case-studies/*.md`. 13 cycle-time check codes: `PHASE_LIE`, `TASK_LIE`, `NO_CS_LINK`, `V2_FILE_MISSING`, `PARTIAL_SHIP_TERMINAL`, `NO_STATE`, `INVALID_JSON`, `NO_PHASE`, `SCHEMA_DRIFT`, `PR_NUMBER_UNRESOLVED`, `BROKEN_PR_CITATION`, `CASE_STUDY_MISSING_TIER_TAGS`, `CU_V2_INVALID` (v7.7).

- **Backfill exemption:** features tagged `case_study_type: "pre_pm_workflow_backfill"`, `"roundup"`, `"no_case_study_required"`, or `"framework_meta_retroactive"` bypass the sub-phase vocabulary check. The `framework_meta_retroactive` tag (added v7.8) is for framework-version meta features whose framework version itself shipped before spec discipline was established (v5.0 SoC, v5.2 dispatch intelligence, v6.0 measurement, v7.0 meta-analysis, v7.1 integrity cycle); the case study + git history are the source of truth — no spec/plan/PRD chain to backfill. Going forward (v7.9+), all new framework versions carry full chain-of-custody and CANNOT use this exemption.
- **Local usage:** `make integrity-check` (findings only) or `make integrity-snapshot` (write + diff vs previous).
- **Full docs:** [`.claude/integrity/README.md`](.claude/integrity/README.md).

**Readout-time dashboards (any time):**
- `make documentation-debt` — Tier 3.2 baseline ledger (7 open items); trend mode unlocks after 3 scheduled cycle snapshots.
- `make measurement-adoption` — Tier 1.1 ledger; surfaces `cache_hits 0/40` known delta tracked at [issue #140](https://github.com/Regevba/FitTracker2/issues/140).
- `make runtime-smoke PROFILE=<id> MODE=<local|staging>` — Tier 2.1 smoke-gate runner; 5 profiles incl. `sign_in_surface`.
- `.claude/logs/<feature>.log.json` — Tier 2.2 contemporaneous feature logs; append via `scripts/append-feature-log.py`.

**Data quality tiers (Tier 2.3):** every quantitative metric in a case study, PRD, or meta-analysis must carry a T1 (Instrumented) / T2 (Declared) / T3 (Narrative) label. See [`docs/case-studies/data-quality-tiers.md`](docs/case-studies/data-quality-tiers.md).

**v7.5 case study:** [`docs/case-studies/data-integrity-framework-v7.5-case-study.md`](docs/case-studies/data-integrity-framework-v7.5-case-study.md). **Remediation status:** [`trust/audits/2026-04-21-gemini/remediation-plan-2026-04-23.md`](trust/audits/2026-04-21-gemini/remediation-plan-2026-04-23.md). **Cold-start entrypoints** (one-page framework-version + Gemini audit summaries): [`.claude/entrypoints/`](.claude/entrypoints/).

This framework exists because we empirically observed 7+ features sit in "shipped but state.json unreconciled" limbo for 3–14 days before the 2026-04-20 audit caught them, and because the 2026-04-21 Gemini audit surfaced that the project had shipped extensive measurement infrastructure without a measurement of its own measurement adoption. v7.5 closes both loops: data is gated at write, audited on cycle, and surfaced on demand.

**Per-PR + weekly defenses (v7.6, shipped 2026-04-25):**
- **Per-PR review bot** — [`.github/workflows/pr-integrity-check.yml`](.github/workflows/pr-integrity-check.yml) runs schema-check + integrity-check + measurement-adoption against every PR HEAD, captures the `origin/main` baseline via worktree, and sets the `pm-framework/pr-integrity` commit status. `failure` if any required command exits non-zero or if the PR introduces NEW findings vs main. Sticky comment with marker `<!-- pm-framework-pr-integrity-bot -->` updates in place.
- **Weekly framework-status cron** — [`.github/workflows/framework-status-weekly.yml`](.github/workflows/framework-status-weekly.yml) fires Mondays 05:00 UTC. Appends a snapshot to [`.claude/shared/measurement-adoption-history.json`](.claude/shared/measurement-adoption-history.json) (dedup by date). Opens `framework-status` issue on regression (decrease in `fully_adopted` or `any_adopted`).
- **Append-only adoption history** — `make measurement-adoption` now writes a dated snapshot to the history ledger; trend mode unlocks after 3 snapshots accumulate.

**v7.7 Validity Closure (shipped 2026-04-27 via PR #144 [merge `01b9e11`]; state.json reconciled in PR #158):**
Closes A1–A5 + B1–B2 + C1 from the post-v7.6 gap inventory across two PRs:

- **FitTracker2 PR #144** — 5 new gates: 4 write-time pre-commit hooks (`CACHE_HITS_EMPTY_POST_V6`, `CU_V2_INVALID`, `STATE_NO_CASE_STUDY_LINK`, `CASE_STUDY_MISSING_FIELDS`) + 1 cycle-time check code (`CU_V2_INVALID`) + 1 cycle-time advisory (`TIER_TAG_LIKELY_INCORRECT`, kill criterion 2 fired at baseline so it ships **advisory permanent**). Plus bulk-backfill of 32 case-study frontmatters and timing.phases backfill on 3 paused features.
- **fitme-story PR #7** — framework-health dashboard at `/control-room/framework` surfacing all 19 mechanical gates + 1 advisory + the D1/D2 human-action checklist + Tier 1.1/3.2 trend charts (charts unlock as cron snapshots accumulate).

**Outcome at synthesis time (2026-04-27):**

| Dimension | Pre-v7.7 | Post-v7.7 |
|---|---|---|
| state↔case-study linkage | 95.5% | **100%** (gated) |
| doc-debt: work_type | 60% | **100%** (gated forward) |
| doc-debt: success_metrics / kill_criteria / dispatch_pattern | 8.9–28.9% | **95.7%** (33 TODO markers reflect genuinely-absent pre-PRD data) |
| `cache_hits[]` post-v6 | 33.3% | gated to 100% on next write (issue #140 closed) |
| `cu_v2` schema | unchecked | 100% schema-validated |
| Total framework mechanisms | 18 (12 cycle + 6 write-time) | **25 gates + 1 advisory** |

**Cron-gated post-merge verifications (B1+B2):**
- Tier 1.1 trend mode unlocks at 3 history snapshots — earliest **2026-05-04** (Monday cron appends snapshot #3).
- Tier 3.2 trend mode unlocks at 3 cycle snapshots — earliest **~2026-05-03 to -06** (72h cycle accumulates 3rd snapshot).

A scheduled +7d agent will append the verification + journal entry once both fire.

**Known gap (2026-04-30 audit) — RESOLVED in v7.8:** the `CACHE_HITS_EMPTY_POST_V6` write-time gate had 0% effective coverage at v7.7 ship because 43/46 state.json files used the legacy `created` key while the gate read `created_at`. Closed by:

- PR #169 (2026-05-01) migrated 43 files from `created` → `created_at`.
- PR #173 (2026-05-02) added a defensive dual-read parser + Mechanism C scaffolding.
- PRs #185 + #186 (2026-05-03) backfilled `framework_version` to canonical `vX.Y` on all 46 features.
- PR #187 + #188 + #189 (2026-05-03) shipped Mechanism A coverage-asserting gates, Mechanism C session attribution wiring, and Mechanism E git merge driver. Effective gate coverage now visible in `.claude/logs/gate-coverage.jsonl`.

## v7.8 Bridge (advisory mode, shipped 2026-05-02 → 2026-05-03)

v7.8 closes the v7.7 silent-pass via two surfaces specified jointly with v7.9:

**Surface 1 — Silent-pass prevention (Mechanisms A, B, C, D):**

- **Mechanism A — Coverage-asserting gates** (PR #187): every write-time gate emits `{candidates, checked, skipped, skip_reasons}` to `.claude/logs/gate-coverage.jsonl`. v7.9 will promote a `GATE_COVERAGE_ZERO` meta-check to enforced once ≥7 days of stats accumulate.
- **Mechanism B — Schema field-rename detection + dual-read** (PR #173 + #185 + #186): `created` ∪ `created_at` dual-read for the migration window; canonical `framework_version` field on 46/46 features.
- **Mechanism C — PostToolUse:Read hook** (PR #173 + #188): `scripts/observe-cache-hit.py` auto-captures Read events → `.claude/logs/_session-<id>.events.jsonl`. `/pm-workflow` now writes `.claude/active-feature` on entry; SessionStart hook surfaces it; new advisory check `CACHE_HITS_AUTO_INSTRUMENTATION_INACTIVE` (15th cycle-time check code) flags features where session events show Reads but state.json::cache_hits[] is empty.
- **Mechanism D — Pre-commit hook header self-audit** (PR #193): pre-commit hook validates its own header on each run; mismatch raises an advisory finding instead of failing silently.

**Surface 2 — Inter-agent awareness (Mechanisms E, F):**

- **Mechanism E — Custom git merge driver** (PR #189): `scripts/merge-driver-dedup.py` auto-resolves merge conflicts on append-only ledgers (`measurement-adoption-history.json`, `documentation-debt.json`) via union-dedup-by-key. `make install-hooks` registers the driver; `.gitattributes` opts the ledgers in.
- **Mechanism F — Membrane status advisory** (PR #193): `scripts/membrane-status.py` reports active feature + recent gate firings + dispatch-blocker state in a single readout. Surfaced via SessionStart and `make membrane-status`. Closes the inter-agent context-handoff gap.

**v7.8 fully shipped 2026-05-04** via 9 PRs: #173 (M-C scaffold) + #185 (PR-2 schema bridges A) + #186 (PR-3 framework_version backfill) + #187 (PR-4 Mechanism A coverage gates) + #188 (PR-5 M-C session attribution) + #189 (PR-6 Mechanism E merge driver) + #193 (PR-6 Mechanisms D + F) + #194 (PR-7 cold-start entrypoint + honesty ledger FT2-FH-001) + #195 (CI fix). Six mechanisms (A–F) all in advisory mode; v7.9 measurement window opens **2026-05-11** (+7d). Schema bridges populated on 47/47 features.

**Spec:** [`docs/superpowers/specs/2026-05-02-framework-v7-8-and-v7-9-bridge-design.md`](docs/superpowers/specs/2026-05-02-framework-v7-8-and-v7-9-bridge-design.md).
**Predecessor v7.7 spec:** [`docs/superpowers/specs/2026-04-27-framework-v7-7-validity-closure-design.md`](docs/superpowers/specs/2026-04-27-framework-v7-7-validity-closure-design.md).
**Predecessor v7.7 plan:** [`docs/superpowers/plans/2026-04-27-framework-v7-7-validity-closure.md`](docs/superpowers/plans/2026-04-27-framework-v7-7-validity-closure.md).
**v7.7 case study:** [`docs/case-studies/framework-v7-7-validity-closure-case-study.md`](docs/case-studies/framework-v7-7-validity-closure-case-study.md).
**v7.8 case study (live append-only journal):** [`docs/case-studies/framework-v7-8-bridge-case-study.md`](docs/case-studies/framework-v7-8-bridge-case-study.md).

## Known Mechanical Limits

v7.6 promoted 4 silent gaps to pre-commit failures and added 3 recurring CI defenses. v7.8 PR-1 ships **Mechanism C** (PostToolUse:Read hook + `scripts/observe-cache-hit.py`) which moves Gap 1 from Class B → A in advisory mode (capture only); v7.9 promotes the writer-path to enforced once 7+ days of session-ledger data calibrate the threshold. Four gaps remain mechanically unclosable:

1. ~~`cache_hits[]` writer-path adoption — agent must remember to log it (issue #140).~~ **Auto-collected in v7.8 advisory** via `PostToolUse:Read` hook (`.claude/settings.json`) → `scripts/observe-cache-hit.py` → `.claude/logs/_session-<id>.events.jsonl`. v7.9 promotes to enforced. Pre-Mechanism-C features (`created_at < 2026-05-02`) are exempt from `CACHE_HITS_EMPTY_POST_V6` — the auto-instrumentation didn't exist for them.
2. `cu_v2` factor *correctness* — judgment-based; we check presence, not magnitude.
3. T1/T2/T3 tag *correctness* — preflight checks presence on post-2026-04-21 case studies, not whether the tag is right.
4. Tier 2.1 real-provider auth checklist — requires a human at a simulator.
5. Tier 3.3 external replication — requires an external operator.

Authoritative reference: [`docs/case-studies/meta-analysis/unclosable-gaps.md`](docs/case-studies/meta-analysis/unclosable-gaps.md). A system that knows what it cannot check is more trustworthy than one that pretends every check is a check.

## Concurrent Dispatch Hygiene

Parallel subagent dispatch is **currently blocked** at the framework layer (F6–F9). Serial dispatch is the working pattern until upstream patches land.

- **Before invoking `superpowers:dispatching-parallel-agents`:** check [`docs/framework-bugs/concurrent-dispatch-blockers.md`](docs/framework-bugs/concurrent-dispatch-blockers.md). If F6–F9 are still active there, default to serial.
- **Declare all required permissions in `.claude/settings.json`** (or `settings.local.json`) BEFORE dispatching any subagent — mid-session UI-accepted grants do NOT propagate to children (F9).
- **Expect re-prompts** on children for Edit/Write/Read even when parent has explicit allow entries (F6, F7). Accept them; don't try to debug as config issues.
- **Re-validation gate** for parallel dispatch: after upstream patches land, run the 2-parallel-agents test in [`docs/superpowers/plans/f6-f9-reproducer/proof-of-fix-tests.md`](docs/superpowers/plans/f6-f9-reproducer/proof-of-fix-tests.md) before resuming parallel work.

## CI Pipeline

- Token check: `make tokens-check` (design system drift detection)
- UI audit: `make ui-audit` (per-view design-system compliance scanner — see "Design System" section)
- Build: `xcodebuild build` (iOS Simulator, no code signing)
- Test: `xcodebuild test` (XCTest suite)
- All four must pass before any merge to main. The original 27-P0 baseline burndown completed (verified 2026-05-05: `make ui-audit` reports P0=0). `ui-audit` is now a hard gate within `verify-local` alongside tokens-check, build, and test. Fix-as-you-touch policy continues for P1 findings (current drift: +5 from 103 baseline → 108).
- **UI test coverage strategy (codified 2026-05-08 per iOS audit finding E-2):** UI test coverage is **intentionally thin** (~7 UI test files vs. 49 unit test files / 440 test methods total). Reason: the parallel-clone simulator hang env-flake (per `docs/case-studies/m-4-xcuitest-infrastructure-case-study.md`) makes UI tests a high-cost, high-flake surface on hosted CI. Unit + analytics tests carry the load instead. Expansion is **deferred** until the env-flake root cause is resolved (tracked in `docs/product/backlog.md` under "CI parallel-clone simulator hang"). Two surgical XCTSkipIf quarantines (`HomeReadinessUITests`, `OnboardingUITests`) remain in place as the live workaround.

## Data-Driven Development

This app is data-driven at every level:
- **System-wide guardrails** (must not degrade for any feature):
  - Crash-free rate > 99.5%
  - Cold start < 2s
  - Sync success rate > 99%
  - CI pass rate > 95%
  - Cross-feature WAU (North Star) trending up or flat
- **Every feature** has a metrics section in its PRD with kill criteria
- **Post-launch** reviews happen at the cadence defined in the PRD
- **Every quantitative metric is tiered** — T1 (Instrumented), T2 (Declared), or T3 (Narrative). Case studies, PRDs, and meta-analyses must tag each reported number with its tier. A T3 metric quoted as if it were T1 is a bug. Full convention: [`docs/case-studies/data-quality-tiers.md`](docs/case-studies/data-quality-tiers.md). Introduced 2026-04-21 per Gemini independent audit Tier 2.3.

## Design System (Living Framework)

The design system is a **living, evolving framework** — not a static constraint. It should serve the product.

- ~125 semantic tokens in `FitTracker/Services/AppTheme.swift`
- 13 reusable components in `FitTracker/DesignSystem/`
- Token pipeline: `design-tokens/tokens.json` → Style Dictionary → `DesignTokens.swift`
- CI gate: `make tokens-check` prevents token drift
- Always use semantic tokens (AppColor, AppText, AppSpacing) — never raw literals

**Evolution rules:**
- New tokens/components are proposed on feature branches, never directly on main
- Phase 3 compliance gateway validates every UI feature against the design system
- If a feature needs to deviate, the user chooses: fix, evolve the system, or override with justification
- Approved changes merge to main with the feature and become part of the system
- All changes documented in `docs/design-system/feature-memory.md`

### Verification Layer (added 2026-04-20)

Per-PR review and `tokens-check` only catch token-definition drift. The
verification layer below catches the more common failure modes — raw
literals slipped into views, magic numbers, missing accessibility, and
the silent-fallback bug where `Color("name")` references a non-existent
colorset.

- **`make ui-audit`** — runs `scripts/ui-audit.py` across every `.swift`
  file under `FitTracker/Views` and `FitTracker/DesignSystem`. Skips
  HISTORICAL v1 files and token-definition files automatically. Exits 1
  on any P0 finding.
- **Rules:** `DS-RAW-COLOR-{MEMBER,SHORTHAND,LITERAL,UIKIT}`,
  `DS-RAW-ANIMATION`, `DS-RAW-FONT-{SYSTEM,SHORTHAND}`,
  `DS-MAGIC-{PADDING,FRAME}`, `DS-A11Y-BUTTON`, `DS-MISSING-ASSET`
  (Gap-A: `Color("name")` in AppTheme without a backing colorset).
- **Baseline:** `docs/design-system/ui-audit-baseline.md` (regenerate
  with `make ui-audit-baseline`). Baseline snapshot: 0 P0 + 103 P1
  (P0 burndown completed 2026-05-05); current live: 0 P0 + 108 P1
  (P1 drift +5 since baseline, fix-as-you-touch active).
- **Fix-as-you-touch rule:** any PR touching a file with findings should
  clear that file's findings as part of the change. `ui-audit` is now a
  hard gate within `verify-local` (achieved 2026-05-05 once P0 baseline
  reached 0).
- **Verification contract:** `docs/design-system/figma-code-sync-status.md`
  Verification Contract section defines what is automatically vs
  manually verified, plus plans for closing the snapshot-test and
  Figma-API gaps.
- **Definition of "Synced"** for any screen in the Figma↔code matrix:
  no P0 findings + all assets resolve + recent verification date +
  Figma node ID referenced in the merging PR's description.

**When introducing a new `Color("name")` token in `AppTheme.swift`:**
add the matching `.colorset` directory under
`FitTracker/Assets.xcassets/Colors/...` AND a corresponding entry in
`design-tokens/tokens.json` AND the generated line in
`FitTracker/DesignSystem/DesignTokens.swift` IN THE SAME COMMIT. The
`make ui-audit` `DS-MISSING-ASSET` rule + `make tokens-check`
together enforce this; both must pass.

## UI Refactoring & V2 Rule

When a UI screen or feature needs a UX Foundations alignment pass (or any
substantial refactor against `docs/design-system/ux-foundations.md`):

1. **Create a `v2/` subdirectory next to the v1 file.** Each feature's v2
   work lives in its own `v2/` subdirectory under the same parent group.
   File names stay the same — only the directory differs:
   - `FitTracker/Views/Main/MainScreenView.swift` (v1, historical)
   - `FitTracker/Views/Main/v2/MainScreenView.swift` (v2, source of truth)
   - `FitTracker/Views/Onboarding/OnboardingWelcomeView.swift` (v1)
   - `FitTracker/Views/Onboarding/v2/OnboardingWelcomeView.swift` (v2)

   This keeps v1 and v2 next to each other for diffing while preserving
   the original file names so imports/types don't collide. Both files
   define the same Swift type (e.g. `MainScreenView`) — the build target
   only references one of them at a time.

2. **Update `FitTracker.xcodeproj/project.pbxproj`** in the same commit
   that creates the first v2 file in a new `v2/` subdirectory. The v2
   directory becomes a new PBXGroup, the v2 file becomes a PBXFileReference
   + PBXBuildFile, and the v1 file is REMOVED from the Sources build phase
   (but stays as a PBXFileReference so it shows in the file navigator and
   git history). v1 lives on as a reviewable historical artifact, not as
   compiled dead code.

3. **Build the v2 file bottom-up** from the design system foundations
   (tokens, components, ux-foundations principles) — do **not** patch the
   v1 file in place. v1 is read-only during the refactor. Use the
   `docs/design-system/v2-refactor-checklist.md` to track what's been
   verified.

4. **Wire the v2 file in** at its parent (e.g. `RootTabView.swift` keeps
   instantiating `MainScreenView()` — same type name — but the symbol now
   resolves to the v2 file because v1 has been removed from the build
   sources). No call-site change needed in parent views since the type
   name is identical; the swap happens at the project.pbxproj layer.

5. **Mark v1 as historical** with a header comment when the swap lands:
   ```swift
   // HISTORICAL — superseded by v2/{ScreenName}.swift on {date} per
   // UX Foundations alignment pass. See
   // .claude/features/{name}/v2-audit-report.md for the gap analysis.
   // This file is no longer in the build target; it stays in the repo
   // as a reviewable reference for the v1 → v2 diff.
   ```

   **Retention policy (codified 2026-05-08 per iOS audit finding F-1):** HISTORICAL v1 files are retained **indefinitely by default**. The V2 Rule's first anniversary (**2027-04-09**) is the scheduled review point for whether to introduce a year+1 prune policy (e.g., "drop HISTORICAL files older than 1 year; rely on git history"). Until then, all HISTORICAL files stay in the repo as on-disk reviewable references. As of 2026-05-05, 16 HISTORICAL files (~5K LoC) sit alongside their v2 counterparts.

6. **One v2 split per surface.** A second alignment pass on the same
   screen does not become a `v3/` directory — it patches v2 in place.
   The v1 → v2 split exists exactly to capture the *first* deliberate
   foundations-aligned rewrite of a pre-PM-workflow surface. v3+ would
   indicate the refactor methodology itself failed.

**For new UI features built from scratch** (no v1 to refactor):
- File lives at the canonical path (no `v2/` subdirectory — there's
  nothing to refactor against).
- The Phase 3 (UX) gateway is **non-skippable** — every new UI feature
  must produce a `ux-spec.md` and pass the design system compliance
  gateway before any view code is written.
- Phase 4 (Implement) starts with the `ux-foundations.md` checklist
  applied to the spec, then the view code. No "build first, audit later".

**Verification checklist:** Every v2 refactor walks through
`docs/design-system/v2-refactor-checklist.md` before requesting Phase 5
(Test) approval. The checklist covers token compliance, component reuse,
state coverage, accessibility, motion, analytics, and project.pbxproj
hygiene. State.json `phases.ux_or_integration.checklist_completed` must
be `true` before Phase 4 advances.

**Backward compatibility note:** Onboarding v2 (PR #59) was the pilot
alignment pass and shipped *before* this rule existed. It used the older
"patch v1 in place" approach. It will be retroactively refactored into
the `v2/` subdirectory convention as a follow-up to the Home v2 pass,
mostly to validate that the rule scales to a feature with multiple
screens. Tracked in the per-screen UX alignment plan in `backlog.md`.

## Analytics Naming Convention

> Established 2026-04-08 as a project-wide rule during the home-today-screen v2 audit (see `.claude/features/home-today-screen/v2-audit-report.md` Decisions Log → OQ-9).

**Every analytics event that tracks an action or interaction on a specific screen MUST include that screen name as a prefix in the event name.**

The point: when looking at an event in GA4 or any analytics dashboard, the source screen should be obvious without checking the source code. Funnel analysis, regression isolation, and per-screen metric tracking all become dramatically faster.

### Naming pattern

| Screen | Event prefix | Example events |
|---|---|---|
| Home | `home_` | `home_action_tap`, `home_metric_tile_tap`, `home_empty_state_shown` |
| Nutrition | `nutrition_` | `nutrition_meal_logged`, `nutrition_macro_viewed`, `nutrition_scanner_opened` |
| Training | `training_` | `training_workout_start`, `training_set_completed`, `training_exercise_viewed` |
| Stats | `stats_` | `stats_period_changed`, `stats_chart_interaction`, `stats_metric_drill_down` |
| Settings | `settings_` | `settings_consent_updated`, `settings_account_deleted`, `settings_export_requested` |
| Onboarding | `onboarding_` | `onboarding_step_viewed`, `onboarding_step_completed`, `onboarding_skipped` |
| Auth | `auth_` | `auth_signin_started`, `auth_signin_completed`, `auth_passkey_registered` |

### What this rule does NOT cover

- **Cross-screen lifecycle events** stay unprefixed: `app_open`, `session_start`, `sign_in`, `sign_up`. These are global, not screen-scoped.
- **GA4 recommended events** keep their dictated names: `tutorial_begin`, `tutorial_complete`, `select_content`, `share`, `login`. GA4 dashboards depend on these.

### Enforcement

1. **PM workflow Phase 1 Analytics Spec gate** validates every new event for screen-prefix compliance when the event is tied to a screen. Non-compliant events block the PRD from approval.
2. **`/analytics spec`** sub-command checks for violations and refuses to write a spec that contains them.
3. **`docs/product/analytics-taxonomy.csv`** has a `screen_scope` column. Either a screen name (`home`, `nutrition`, etc.) or `global` for cross-screen events.
4. **`/analytics validate`** sub-command runs a periodic audit of existing events. Non-conforming events get flagged and renamed via a migration plan that preserves historical dashboards.

### Backwards compatibility

The rule applies prospectively from 2026-04-08. Existing events that pre-date the rule will be renamed during the next `/analytics validate` pass, with migration handled via GA4 event aliases (so historical dashboards keep working).

## Key Paths

### Product
- PRD: `docs/product/PRD.md`
- Per-feature PRDs: `docs/product/prd/`
- Metrics: `docs/product/metrics-framework.md`
- Backlog: `docs/product/backlog.md`
- Feature state: `.claude/features/{name}/state.json`

### Master plan & handoffs
- Master plan: `docs/master-plan/master-plan-2026-04-06.md` (current)
- RICE roadmap: `docs/master-plan/master-backlog-roadmap.md`
- Handoff archive: `docs/master-plan/` (all session summaries, stabilization reports, branch reviews)

### Skills ecosystem
- **DEV-only framework guide (v1.0 → v7.7 → v7.8):** [`docs/architecture/dev-guide-v1-to-v7-7.md`](docs/architecture/dev-guide-v1-to-v7-7.md) — start here if you are a developer onboarding to the framework. Covers the 4 enforcement layers, `state.json` schema, phase lifecycle, dispatch model, cache architecture, measurement protocol, integrity check codes, and operational walkthroughs (adding a feature, extending a check code, bumping the framework version). v7.8 mechanisms (A coverage gates, C session attribution, E ledger merge driver) appended in [`framework-v7-8-bridge-case-study.md`](../case-studies/framework-v7-8-bridge-case-study.md) until the dev-guide is bumped to v7-8.
- Skills one-pager: `docs/skills/README.md`
- Skills architecture deep-dive: `docs/skills/architecture.md` (merged from former skills-ecosystem.md + skills-ecosystem-analysis.md)
- Ecosystem evolution history: `docs/skills/evolution.md` (v1.0 → v1.2 → v2.0 → v3.0 → v4.0 → v4.1)
- Per-skill docs: `docs/skills/{name}.md` (pm-workflow, ux, design, dev, qa, analytics, cx, marketing, research, ops, release)
- Agent-facing prompts: `.claude/skills/{name}/SKILL.md`
- Integration adapters: `.claude/integrations/{service}/` (ga4, app-store-connect, sentry, firecrawl, axe, security-audit)
- Learning cache: `.claude/cache/` (L1 per-skill, L2 `_shared/`, L3 `_project/`)
- Validation gate config: `.claude/shared/skill-routing.json` (`validation_gate` section)
- **Operations control room (in-flight migration, UCC):** the operator dashboard that surfaces every framework gate, every cycle snapshot, every measurement-adoption ledger, and the case-study feed. Currently lives at `dashboard/` (Astro 6 + React 19, deployed at `fit-tracker2.vercel.app`); migrating to `fitme-story/src/{app,components,lib}/control-room/` (Next.js 16, deployed at `fitme-story.vercel.app/control-room/*`, basic-auth gated). Pre-build sync at `fitme-story/scripts/sync-from-fittracker2.ts` mirrors `.claude/shared/*.json`, `.claude/features/*/state.json`, and the canonical doc tree. Migration is extraction-ready: see [`fitme-story/EXTRACTION-RECIPE.md`](https://github.com/Regevba/fitme-story/blob/main/EXTRACTION-RECIPE.md) for the 7-step playbook. Per-feature state for the migration: `.claude/features/unified-control-center/`. The framework-health page at `/control-room/framework` (PR #7, fitme-story) is the first UCC route shipped; remaining UCC tasks tracked in `state.json.tasks[]`.

### Design system
- UX foundations: `docs/design-system/ux-foundations.md` (13 principles)
- V2 refactor checklist: `docs/design-system/v2-refactor-checklist.md`
- Feature memory: `docs/design-system/feature-memory.md`
- Feature development gateway: `docs/design-system/feature-development-gateway.md`
- Tokens: `FitTracker/Services/AppTheme.swift` + `design-tokens/tokens.json`
- Components: `FitTracker/DesignSystem/AppComponents.swift`
- UI audit scanner: `scripts/ui-audit.py` (run via `make ui-audit`)
- UI audit baseline: `docs/design-system/ui-audit-baseline.md`
- Figma↔code matrix + Verification Contract: `docs/design-system/figma-code-sync-status.md`

### Handoff prompts
- UX/UI build prompts (auto-generated + hand-authored): `docs/prompts/`
- Auto-generation contracts: `/ux prompt {feature}` + `/design prompt {feature}` (see `docs/skills/ux.md` and `docs/skills/design.md`)

### Case studies
- Narrative showcases of the PM workflow running on real features: `docs/case-studies/`
- Pilot case study (Onboarding v2): `docs/case-studies/pm-workflow-showcase-onboarding.md`
- Data quality tiers convention: `docs/case-studies/data-quality-tiers.md` (T1/T2/T3 labeling, est. 2026-04-21)
- Meta-analyses + independent audits: `docs/case-studies/meta-analysis/`
- **Publication + chronological-order rule (est. 2026-04-30):** every feature that transitions to `complete` MUST have BOTH a source case study at `docs/case-studies/<feature>-case-study.md` AND a published showcase MDX at `fitme-story/content/04-case-studies/`. The showcase's slot-number filename prefix AND `timeline_position.order` MUST reflect the framework version under which the feature shipped — not the publication date. A v5.1 feature published retroactively still slots in chronologically: use a fractional `order` (e.g. `8.5`) and an intercalating filename prefix (e.g. `08a-`) so existing slots don't get renumbered. At PR review, a showcase MDX claiming `version: '5.1'` placed below a `version: '6.0'` slot is a review block. Publication is verified via the `case_study_showcase` field in `state.json` pointing at a real MDX in fitme-story (the existing `STATE_NO_CASE_STUDY_LINK` write-time gate enforces the source case study; chronological position is enforced at PR review for now).

### Process docs (Gemini audit Tier groundwork)
- Index: `docs/process/README.md`
- Runtime smoke gates (Tier 2.1): `docs/process/runtime-smoke-gates.md` + `make runtime-smoke PROFILE=<id> MODE=<local|staging>`
- Contemporaneous logging (Tier 2.2): `docs/process/contemporaneous-logging.md` + `scripts/append-feature-log.py` + `.claude/logs/<feature>.log.json`
- Documentation-debt dashboard (Tier 3.2): `docs/process/documentation-debt-dashboard.md` + `make documentation-debt` + `.claude/shared/documentation-debt.json`
- Auth-runtime verification playbook: `docs/setup/auth-runtime-verification-playbook.md`
- Pre-commit state.json schema enforcement (Tier 1.3): `.githooks/pre-commit` + `make install-hooks` + `scripts/check-state-schema.py`
- Independent-audit remediation tracker: `trust/audits/2026-04-21-gemini/remediation-plan-2026-04-23.md`

### Setup guides
- One-time environment + service setup: `docs/setup/`
- SSD layout: `docs/setup/ssd-setup-guide.md`
- Firebase Analytics: `docs/setup/firebase-setup-guide.md`
- Dashboard activation: `docs/setup/dashboard-activation.md`
- Integrations setup: `docs/setup/integrations-setup-guide.md`
- Auth runtime verification: `docs/setup/auth-runtime-verification-playbook.md`
