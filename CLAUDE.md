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

## Data Integrity Framework (v7.5 → v7.6, shipped 2026-04-24 → 2026-04-25)

The 72h Integrity Cycle shipped at v7.1 is now one of **eight cooperating defenses** in the v7.5 Data Integrity Framework — triggered by the 2026-04-21 Google Gemini 2.5 Pro independent audit. v7.6 (Mechanical Enforcement, shipped 2026-04-25) closes the remaining Class B → Class A gap by promoting four silent agent-attention checks into pre-commit failures and adding two recurring CI defenses (per-PR review bot, weekly framework-status cron).

**Write-time gates (fire on `git commit`):**
- `SCHEMA_DRIFT` — pre-commit hook rejects legacy `phase` key; canonical is `current_phase`. Install via `make install-hooks`.
- `PR_NUMBER_UNRESOLVED` — pre-commit hook verifies `phases.merge.pr_number` resolves via `gh pr view` before state.json can record it.
- `PHASE_TRANSITION_NO_LOG` (v7.6) — pre-commit hook rejects a `current_phase` change in a state.json without a corresponding event in `.claude/logs/<feature>.log.json` within the last 15 minutes.
- `PHASE_TRANSITION_NO_TIMING` (v7.6) — pre-commit hook rejects a `current_phase` change without a `phases.<new_phase>.started_at` update in the same commit.
- `BROKEN_PR_CITATION` (v7.6, write-time) — pre-commit hook rejects case-study commits that cite `PR #N` or `pull/N` if the number does not resolve via `gh pr view`. Cycle-level `BROKEN_PR_CITATION` still runs as a safety net.
- `CASE_STUDY_MISSING_TIER_TAGS` (v7.6) — pre-commit hook rejects case-study commits (forward-only, dated ≥ 2026-04-21) that contain quantitative claims without a T1/T2/T3 tier tag.

**Cycle-time gates (fire every 72h via GitHub Actions):**
Runs [`scripts/integrity-check.py`](scripts/integrity-check.py) against every `.claude/features/*/state.json` and every `docs/case-studies/*.md`. 11 check codes (10 feature-level + 1 case-study-level): `PHASE_LIE`, `TASK_LIE`, `NO_CS_LINK`, `V2_FILE_MISSING`, `PARTIAL_SHIP_TERMINAL`, `NO_STATE`, `INVALID_JSON`, `NO_PHASE`, `SCHEMA_DRIFT`, `PR_NUMBER_UNRESOLVED`, `BROKEN_PR_CITATION`.

- **Backfill exemption:** features tagged `case_study_type: "pre_pm_workflow_backfill"` or `"roundup"` bypass the sub-phase vocabulary check.
- **Local usage:** `make integrity-check` (findings only) or `make integrity-snapshot` (write + diff vs previous).
- **Full docs:** [`.claude/integrity/README.md`](.claude/integrity/README.md).

**Readout-time dashboards (any time):**
- `make documentation-debt` — Tier 3.2 baseline ledger (7 open items); trend mode unlocks after 3 scheduled cycle snapshots.
- `make measurement-adoption` — Tier 1.1 ledger; surfaces `cache_hits 0/40` known delta tracked at [issue #140](https://github.com/Regevba/FitTracker2/issues/140).
- `make runtime-smoke PROFILE=<id> MODE=<local|staging>` — Tier 2.1 smoke-gate runner; 5 profiles incl. `sign_in_surface`.
- `.claude/logs/<feature>.log.json` — Tier 2.2 contemporaneous feature logs; append via `scripts/append-feature-log.py`.

**Data quality tiers (Tier 2.3):** every quantitative metric in a case study, PRD, or meta-analysis must carry a T1 (Instrumented) / T2 (Declared) / T3 (Narrative) label. See [`docs/case-studies/data-quality-tiers.md`](docs/case-studies/data-quality-tiers.md).

**v7.5 case study:** [`docs/case-studies/data-integrity-framework-v7.5-case-study.md`](docs/case-studies/data-integrity-framework-v7.5-case-study.md). **Remediation status:** [`trust/audits/2026-04-21-gemini/remediation-plan-2026-04-23.md`](trust/audits/2026-04-21-gemini/remediation-plan-2026-04-23.md).

This framework exists because we empirically observed 7+ features sit in "shipped but state.json unreconciled" limbo for 3–14 days before the 2026-04-20 audit caught them, and because the 2026-04-21 Gemini audit surfaced that the project had shipped extensive measurement infrastructure without a measurement of its own measurement adoption. v7.5 closes both loops: data is gated at write, audited on cycle, and surfaced on demand.

**Per-PR + weekly defenses (v7.6, shipped 2026-04-25):**
- **Per-PR review bot** — [`.github/workflows/pr-integrity-check.yml`](.github/workflows/pr-integrity-check.yml) runs schema-check + integrity-check + measurement-adoption against every PR HEAD, captures the `origin/main` baseline via worktree, and sets the `pm-framework/pr-integrity` commit status. `failure` if the PR introduces NEW findings vs main. Sticky comment with marker `<!-- pm-framework-pr-integrity-bot -->` updates in place.
- **Weekly framework-status cron** — [`.github/workflows/framework-status-weekly.yml`](.github/workflows/framework-status-weekly.yml) fires Mondays 05:00 UTC. Appends a snapshot to [`.claude/shared/measurement-adoption-history.json`](.claude/shared/measurement-adoption-history.json) (dedup by date). Opens `framework-status` issue on regression (decrease in `fully_adopted` or `any_adopted`).
- **Append-only adoption history** — `make measurement-adoption` now writes a dated snapshot to the history ledger; trend mode unlocks after 3 snapshots accumulate.

## Known Mechanical Limits

v7.6 promoted 4 silent gaps to pre-commit failures and added 3 recurring CI defenses. Five gaps remain mechanically unclosable:

1. `cache_hits[]` writer-path adoption — agent must remember to log it (issue #140).
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
- All four must pass before any merge to main once the UI-audit baseline reaches 0 P0. Today `ui-audit` runs separately; the existing 27 P0 baseline is being burned down "fix-as-you-touch" per `docs/design-system/ui-audit-baseline.md`.

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
  with `make ui-audit-baseline`). Current snapshot: 27 P0 + 103 P1.
- **Fix-as-you-touch rule:** any PR touching a file with findings should
  clear that file's findings as part of the change. Once baseline P0
  reaches 0, add `ui-audit` to `verify-local` to make it a hard gate.
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
- **DEV-only framework guide (v1.0 → v7.6):** [`docs/architecture/dev-guide-v1-to-v7-6.md`](docs/architecture/dev-guide-v1-to-v7-6.md) — start here if you are a developer onboarding to the framework. Covers the 4 enforcement layers, `state.json` schema, phase lifecycle, dispatch model, cache architecture, measurement protocol, integrity check codes, and operational walkthroughs (adding a feature, extending a check code, bumping the framework version).
- Skills one-pager: `docs/skills/README.md`
- Skills architecture deep-dive: `docs/skills/architecture.md` (merged from former skills-ecosystem.md + skills-ecosystem-analysis.md)
- Ecosystem evolution history: `docs/skills/evolution.md` (v1.0 → v1.2 → v2.0 → v3.0 → v4.0 → v4.1)
- Per-skill docs: `docs/skills/{name}.md` (pm-workflow, ux, design, dev, qa, analytics, cx, marketing, research, ops, release)
- Agent-facing prompts: `.claude/skills/{name}/SKILL.md`
- Integration adapters: `.claude/integrations/{service}/` (ga4, app-store-connect, sentry, firecrawl, axe, security-audit)
- Learning cache: `.claude/cache/` (L1 per-skill, L2 `_shared/`, L3 `_project/`)
- Validation gate config: `.claude/shared/skill-routing.json` (`validation_gate` section)

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
