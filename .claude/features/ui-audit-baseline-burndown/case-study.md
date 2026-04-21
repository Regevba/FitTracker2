# UI-Audit Baseline Burndown — Case Study

**Status:** In progress
**Started:** 2026-04-21
**Parent feature:** design-system-v2
**Plan:** [docs/superpowers/plans/2026-04-20-ui-audit-baseline-burndown.md](../../../docs/superpowers/plans/2026-04-20-ui-audit-baseline-burndown.md)
**PRs:** TBD

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

1. **Mirror layer** — every file-task captures before/after simulator
   screenshots in `.build/mirrors/` (gitignored) and requires manual
   diff before commit. Catches silent pixel changes from token swaps.
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

### Phase 2 — animation cluster

_Not yet started._

## Metrics

- Baseline P0: 27 → 0 (target)
- Baseline P1: 103 → ≤ 20 (stretch, deferred to follow-on plan)
- Visual regressions post-merge: 0 (target; 7-day review)
- Mirror diffs captured: 24 (2 modes × 12 files)
- AppMotion tokens added: 5
- Scanner rules added in Phase 4.1: TBD

## Framework lessons

_Populated at Phase 5 close-out._

