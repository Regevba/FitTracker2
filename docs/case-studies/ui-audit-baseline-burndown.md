# UI-Audit Baseline Burndown — Case Study

**Status:** **Shipped — merged to main 2026-04-24.** Hard gate live in `verify-local`. State.json retroactively closed 2026-04-27 (commit `a8e3f2f`).
**Started:** 2026-04-21
**Code completed:** 2026-04-21
**Merged:** 2026-04-24
**Parent feature:** design-system-v2
**Plan:** [docs/superpowers/plans/2026-04-20-ui-audit-baseline-burndown.md](../superpowers/plans/2026-04-20-ui-audit-baseline-burndown.md)
**Merges:**
- PR #139 (`claude/review-ui-consistency-zSkvJ` → `main`) merged 2026-04-24T09:09:11Z via merge commit `c4b78931a52b92afb413b65340bc32fbabbcf98d`. 21 commits: AppMotion tokens, scanner `--file` flag, Phase 0 infra, 12 file migrations, baseline regenerations, gate promotion, scanner hardening, drift check, case study publication.
- `chore/pbxproj-orphan-cleanup` merged via direct commit `e892ce3` on 2026-04-24T04:00:09Z (no PR; 2-line surgical cleanup).

## Context

The `make ui-audit` scanner shipped on branch `claude/review-ui-consistency-zSkvJ`
(commits `cf3cf56` / `bc4ddfe` / `573fe8a`) established a per-view
design-system compliance contract: raw Color literals, raw animations,
raw fonts, magic numbers, missing a11y, and — crucially — the silent
fallback bug where `Color("name")` references a non-existent colorset.
At rest, 27 P0 + 103 P1 across 44 files. Because baseline P0 ≠ 0, the
scanner could only run as an advisory step, not as a `verify-local`
gate. This case study documents the burndown to P0=0 and the
promotion to a hard gate.

## The gap

Verification layer without a gate is observation without enforcement.
Any PR could introduce a new P0 and the scanner would report it — but
nothing stopped the merge. Historical drift produced 27 findings that
had never been rejected; the DS-MISSING-ASSET rule (the one that
closed the chart-color Gap-A bug in commit `cf3cf56`) could not yet
enforce because the baseline was not clean.

## Approach

Three-layer safety model:

1. **Mirror layer (design)** — every file-task was designed to capture
   before/after simulator screenshots in `.build/mirrors/` (gitignored)
   and require manual diff before commit. Catches silent pixel changes
   from token swaps. _Execution note: this run's mirrors are deferred
   to the user because the execution environment didn't have a booted
   simulator. Each commit annotates "Mirror diff: PENDING user
   verification" and the atomic per-file-commit structure lets any
   regression be reverted surgically once mirrors are reviewed._
2. **Rollback layer** — one file per commit + semantic-tagged baseline.
   Any file can be reverted surgically; the whole burndown can be
   reset to `573fe8a` without losing the verification layer.
3. **Motion-tokens-first** — raw animations in P0 scope required new
   AppMotion presets (`hero`, `stepAdvance`, `dialPulse`, `heroEntry`,
   `fastShimmer`). These were added in Task 0.1 BEFORE any file was
   migrated, so every mapping is 1:1 semantic, not approximation.

## Per-file burndown log

### Phase 1 — color cluster (8 files, 21 P0 closed)

| Commit | File | P0 | Key mappings |
|---|---|---:|---|
| `748de4c` | — | — | (Phase 0.1) 3 new AppSpring + AppEasing + AppLoadingAnimation tokens |
| `82112b3` | OnboardingAuthView.swift | 8 | `.blue` → `Brand.secondary`; `Color.white` → `AppPalette.white` (Google brand); 5× `.foregroundStyle(.white)` → `Text.inversePrimary` |
| `3b6102d` | AuthHubView.swift | 3 | `.fill(Color.white)` → `AppPalette.white`; 2× `.white` → `Text.inversePrimary` |
| `41baab3` | SignInView.swift | 2 | `Color(.systemBackground)` → `Background.appPrimary`; Apple labelColor → `Text.inversePrimary` (fixes latent dark-mode contrast bug) |
| `141b13c` | ConsentView.swift | 2 | `Color.white` → `AppPalette.white`; `.white` → `Text.inversePrimary` |
| `9954381` | ProfileHeroSection.swift | 2 | 2× `.white` → `Text.inversePrimary` |
| `80ab383` | MilestoneModal.swift | 2 | 2× `.white` → `Text.inversePrimary` |
| `67fb3c8` | AccountPanelView.swift | 1 | `.white` → `Text.inversePrimary` |
| `834d91b` | BodyCompositionCard.swift | 1 | `.white` → `Text.inversePrimary` |

**Three distinct patterns emerged:**

1. **Standard inverse-primary** (17 of 21 sites) — `.white` text on any colored/inverse surface → `AppColor.Text.inversePrimary`. No ambiguity.
2. **Google-brand pure white** (4 sites) — `Color.white` discs/cards on Google auth buttons → `AppPalette.white`. Surface.elevated would shift to 20%-alpha in dark mode and break Google brand identity; palette-level pure white preserves brand compliance in both modes. Re-discovered a dormant token (`AppPalette.white` was declared but unused in views).
3. **Semantic blue** (1 site — email icon) — `.blue` → `AppColor.Brand.secondary`. Shifts iOS system blue (#007AFF) to lighter brand blue (#8AC7FF); consistent with the Google "G" letter already using Brand.secondary. Visible change; flagged for mirror verification.

**Phase 1 metrics:**
- P0 closed: 21
- P0 remaining: 6 (all animation, Phase 2)
- Commits: 8 (one per file) + 1 baseline regeneration
- Swift-parse: all clean
- Mirror diffs: **PENDING user verification**

### Phase 2 — animation cluster (4 files, 6 P0 closed)

| Commit | File | P0 | Mapping |
|---|---|---:|---|
| `ee1c15b` | WelcomeView.swift | 3 | `AppSpring.hero`, `AppEasing.heroEntry` ×2 |
| `14f7c10` | OnboardingFirstActionView.swift | 1 | `AppSpring.stepAdvance` |
| `d70c00b` | ReadinessCard.swift | 1 | `AppSpring.dialPulse` |
| `ab651ca` | TrainingPlanView.swift | 1 | `AppLoadingAnimation.fastShimmer` |

**All six animation mappings are 1:1 semantic** — the new AppMotion tokens added in Phase 0.1 were deliberately declared with values identical to the raw call sites (hero = spring 0.80/0.70, stepAdvance = spring 0.50/0.70, dialPulse = interpolatingSpring 40/8, heroEntry = easeOut 0.60, fastShimmer = linear 1.2 repeatForever). No feel change expected.

**Phase 2 metrics:**
- P0 closed: 6
- P0 remaining: **0**
- Commits: 4 (one per file)
- Swift-parse: all clean
- Mirror diffs: **PENDING user verification**

## Final baseline state (post-Phase 2)

- **P0: 0** (was 27) — scanner exits 0 with no `--no-fail` flag; gate is ready for promotion
- **P1: 103** (unchanged) — deferred to follow-on plan
  - DS-MAGIC-FRAME: 71
  - DS-RAW-FONT-SHORTHAND: 23
  - DS-A11Y-BUTTON: 5
  - DS-MAGIC-PADDING: 4

Phase 3 (gate-the-gate) is unblocked.

### Phase 3 — gate activation (2 sub-tasks)

- **3.1 Freeze verification** — full-tree `ui-audit --summary` exits 0; `tokens-check` exits 0; all 13 touched files `swift-parse` exit 0. No commit; checkpoint only.
- **3.2 Gate promotion** — commit `cf8e09c`. `verify-local` dependency chain is now `tokens-check → ui-audit → verify-web → verify-ai → verify-evals → verify-ios → verify-timing → verify-framework`. Any future PR introducing a raw `Color` literal, raw animation, raw `Font.system`, or a `Color("name")` without a backing colorset fails the local + CI gate.

### Phase 4 — scanner hardening + drift check + orphan cleanup

| Commit | Scope | Notes |
|---|---|---|
| `076d3bd` | Scanner rule `RE_RAW_ANIMATION_BARE` + 2 new fixes | `.easeInOut` / `.default.repeatCount` without parenthesized-args form now caught; scoped to `withAnimation(…)` / `.animation(…)` contexts to eliminate false-positive risk. Surfaced ReadinessCard:22 + SignInView:157, both migrated in the same commit so verify-local stays green. |
| `7bbf076` | `ui-audit-drift` Makefile target | Detects stale `ui-audit-baseline.md` via backup-regenerate-diff-restore; tree never left polluted. Wired into `verify-local` right after `ui-audit`. |
| `fa1aab4` | pbxproj orphan cleanup (on `chore/pbxproj-orphan-cleanup` — separate branch off `origin/main`) | 2-line deletion of orphan `PBXBuildFile` entries for v1 `MainScreenView` + `TrainingPlanView`. `xcodebuild -list` confirms parse. Separate PR so change class is not conflated with the burndown's code-migration review. |

**Phase 4.1 scope narrowed from the plan.** The plan proposed 3 new rules (ternary-embedded, interpolated, computed-color-properties). A grep survey showed the interpolated pattern has zero findings in-codebase and the ternary/positional patterns would false-positive on enum cases like `ASAuthorizationAppleIDButtonStyle.white`. Shipped only the bare-animation rule (safe, scoped, surfaced real findings); deferred the rest to a follow-on that ships with its own mirror sweep.

## Final metrics

- **P0: 27 → 0** (hard gate active in verify-local)
- **P1: 103** (unchanged; deferred)
- **AppMotion tokens added**: 5 (`AppSpring.hero`, `AppSpring.stepAdvance`, `AppSpring.dialPulse`, `AppEasing.heroEntry`, `AppLoadingAnimation.fastShimmer`)
- **Scanner rules added**: 1 (`RE_RAW_ANIMATION_BARE`)
- **Scanner flags added**: 1 (`--file PATH`)
- **Makefile targets added**: 1 (`ui-audit-drift`)
- **Files migrated**: 13 (12 view files + AppMotion.swift)
- **Commits**: 20 on `claude/review-ui-consistency-zSkvJ` over `573fe8a` + 1 on `chore/pbxproj-orphan-cleanup` over `origin/main`
- **Visual regressions post-merge**: **target 0** (7-day post-merge review)
- **Mirror diffs captured**: **PENDING user verification** across all 12 files (plan was 24 = 2 modes × 12 files)

## Framework lessons

1. **Tokens-first beats "best-fit mapping later."** Task 0.1 added five motion tokens with values IDENTICAL to the raw call sites before Phase 2 migrated anything. All six animation swaps were literal substitutions with zero feel change. The alternative — "migrate to the closest existing preset" — would have shifted every animation slightly (none of `AppSpring.snappy/bouncy/smooth/stiff/progress` exactly matched any of the raw sites). Pattern: when a migration requires new tokens, declare them as their own commit BEFORE migrating, so mappings are 1:1 semantic.

2. **Context-read beats mechanical replacement.** 4 of 21 Phase 1 sites were Google brand white (always pure white, even in dark mode) not standard inverse-primary. `Surface.elevated` shifts to 20%-alpha in dark mode — would have broken Google brand identity. Discovered `AppPalette.white` was declared but unused in view code; that dormant token was the right answer. Pattern: grep'ing for `.white` + mechanical swap would have silently regressed. Read each site's context.

3. **Migrations are free tests for the scanner.** The bare-animation form `.easeInOut` in `ReadinessCard:22` wasn't caught by the original regex (which required a parenthesized `duration:` arg). Surfaced during Phase 2 as I was reading every line. Pattern: track scanner gaps encountered during the migration itself — they become Phase 4 work.

4. **Grep before expanding a scanner rule.** Phase 4.1 almost grew to 3 new rules. A grep survey showed positional `.white` (like `style: .white` on an enum) would false-positive, and interpolated-asset-name had zero findings. Narrow scope shipped (bare-animation only). Pattern: if a proposed rule would flag legitimate enum cases or has zero real findings, the rule is too broad or premature.

5. **An observability layer without a gate is hope.** The `ui-audit` scanner lived as advisory-only for multiple days before this plan. No PR was rejected by it. Real enforcement happened in **one Makefile line** (3.2) once P0 reached 0. Pattern: ship the gate activation, not just the measurement tool.

6. **Env friction ≠ code blocker.** SSD-hosted `BUILD_HOME` broke `actool`/`SimDeviceSet` on both main and this branch before Phase 0 started. `verify-ios` was unreachable throughout. Used `xcrun swift-frontend -parse` as a per-file syntax substitute. Pattern: document environmental blockers, find a lighter-weight signal, don't let env friction stop code progress (but also don't claim full verification).

7. **One commit per file is the rollback contract.** 12 file migrations = 12 atomic commits. If mirror verification surfaces a regression on one file, `git revert <sha>` touches only that file. If all 12 had been bundled into "fix-all-p0", rollback would be surgery vs. amputation. Pattern: for migrations where visual regression is the primary risk, atomic per-file commits are non-negotiable.

8. **Orthogonal cleanups ship on their own branch.** The pbxproj orphan cleanup touched project config, not view code. Different reviewer attention, different rollback story. Landed on `chore/pbxproj-orphan-cleanup` off `origin/main`, not bundled into the burndown branch. Pattern: if a cleanup's change class is different from the main work, the PR should be different too.

9. **Gate activation is itself a revertible one-liner.** Phase 3.2 promoted `ui-audit` into `verify-local`. If a mirror review later reveals a regression, reverting the Makefile commit drops the gate back to advisory while the underlying file-level revert is applied. Two-dimensional rollback: gate-level + file-level are independent. Pattern: design gates so they can be turned off without losing the measurement.

10. **Cache-warm verification is cheaper than cache-cold.** Re-running `ui-audit` after each file-task cost < 1s because the scanner is stdlib-only Python; `swift-frontend -parse` was also fast. The heavy `make verify-ios` would have paid a cache-cold re-resolve every time the Makefile depgraph thought something changed. Pattern: prefer fast source-level signals for per-file iteration; save the heavy build for end-of-phase batch verification.

