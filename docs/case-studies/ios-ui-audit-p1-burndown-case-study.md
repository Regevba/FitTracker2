---
title: iOS UI Audit P1 Burndown — 2-PR Token Substitution + Audit Hardening
date_written: 2026-05-11
date: 2026-05-11
work_type: enhancement
work_subtype: audit_burndown
parent_case_study: docs/case-studies/ui-audit-baseline-burndown.md
parent_feature: ui-audit-baseline-burndown
framework_version: v7.8.2
dispatch_pattern: serial
primary_metric:
  name: ui_audit_p1_count
  baseline: 103
  target: 30
  achieved: 44
  achieved_pct: 57
  tier: T1
success_metrics:
  - name: ui_audit_p1_count
    baseline: 103
    achieved: 44
    pct_reduction: 57
    tier: T1
  - name: files_with_findings
    baseline: 42
    achieved: 26
    tier: T1
  - name: DS-MAGIC-FRAME_occurrences
    baseline: 62
    achieved: 40
    tier: T1
  - name: DS-RAW-FONT-SHORTHAND_occurrences
    baseline: 26
    achieved: 0
    tier: T1
  - name: DS-A11Y-BUTTON_occurrences
    baseline: 6
    achieved: 0
    tier: T1
  - name: DS-MAGIC-PADDING_occurrences
    baseline: 6
    achieved: 4
    tier: T1
kill_criteria: |
  Net visual regression on a critical user-path screen (Home / Training / Nutrition / Auth / Settings)
  caused by a token substitution → revert the PR; investigate token definition; consider whether the
  audit rule's recommended token is actually wrong for that context.
kill_criteria_resolution: |
  not_triggered_no_visual_regression_post_spot_check. Operator iOS simulator spot-check on each PR
  pre-merge (Option B strict-risk path locked via /AskUserQuestion 2026-05-11) confirmed zero visual
  drift on touched screens (Training tab + Auth + Nutrition + AI + Profile + Shared cards).
tier_tags_present: true
related_prs:
  - 292
  - 294
shipped_window: '2026-05-11 (single session, ~3 hours wall time across 2 PRs)'
case_study_type: scoped
---

# iOS UI Audit P1 Burndown — Case Study

**Status:** SHIPPED — merged to main via PR #292 (`953908b`) + PR #294. State.json closed via PR #(closure).
**Started:** 2026-05-11
**Code completed:** 2026-05-11
**Merged:** 2026-05-11
**Parent feature:** ui-audit-baseline-burndown (P0 baseline shipped 2026-04-24 via PR #139)

## Context

The parent feature `ui-audit-baseline-burndown` shipped 2026-04-24 with the
`make ui-audit` scanner promoted to a hard `verify-local` gate. At that
moment the codebase sat at 0 P0 + 103 P1 across 42 files. The P0=0 gate
ensures no NEW P0 ever lands; the 103 P1 findings stayed under
"fix-as-you-touch" — addressed only when a PR happened to touch the
file.

By 2026-05-11 the P1 count had drifted to 108 (+5 from baseline) despite
the fix-as-you-touch policy. This enhancement shipped a **proactive
burndown** instead of waiting for organic touches.

## The strategy decision

Initial plan (drafted 2026-05-10 at session pause) was 5 area-bucketed
PRs assuming "lightweight token substitution." Frequency analysis of
the 62 DS-MAGIC-FRAME findings on resume morning revealed:

| Value | Occurrences | Pattern |
|---|---:|---|
| 44 | 36 | iOS HIG tap target |
| 28 | 16 | icon container (distinct from `iconBadge=26`) |
| 80 | 13 | inline numeric field width |
| 36 | 7 | compact tap target |
| 23 other | 1–4 each | unique design-specific (chart 180, modal 260, divider 50, etc.) |

Trying to tokenize every magic number forces inventing single-use tokens
which inflates the design system. The honest move: add 4 tokens for
genuinely-shared patterns, mass-substitute, and accept the long-tail 23
as documented design-specific P1s. **(T2 — declared at decision time;
the 4-token frequency cluster was empirically observed but the
"23 unique" count was the count at planning, not at ship.)**

**Decision matrix locked via `/AskUserQuestion` 2026-05-11:**
- Strategy: **Option B** (Tokens for high-frequency only, ~78% target reduction)
- PR structure: **2 PRs cross-area** (tokens-first vs area-first)
- Risk tolerance: **Strict** (operator iOS simulator spot-check per PR before merge)

This replaced the original 5-PR plan with 2 cross-cutting PRs.

## What shipped

### PR #292 — PR-1: Frame tokens + mass substitution (squash `953908b`, merged 2026-05-11)

- **4 new `AppSize` tokens** in `FitTracker/Services/AppTheme.swift`:
  - `AppSize.tapTarget = 44` (iOS HIG minimum)
  - `AppSize.tapTargetCompact = 36`
  - `AppSize.iconContainer = 28` (distinct from existing `iconBadge=26`)
  - `AppSize.fieldWidthCompact = 80`
- **`scripts/ui-audit.py`** `APP_SIZE_VALUES` allowlist extended to `{28, 36, 44, 80}`
- **50 mass-substitutions** of `.frame(width: N, height: N)` literals across 21 SwiftUI views
- HISTORICAL v1 files automatically excluded (script-level skip)

**Verification (T1):** `xcodebuild build` PASSED; `make ui-audit` P0=0 maintained; P1 baseline 103 → 72 (-31).

### PR #294 — PR-2: AppText tokens + a11y labels + audit-window widen (merged 2026-05-11)

- **3 new `AppText` tokens** in `AppTheme.swift`:
  - `AppText.subheadingStrong` (.subheadline / .rounded / .semibold)
  - `AppText.captionMicro` (.caption2 / .rounded)
  - `AppText.captionMicroMedium` (.caption2 / .rounded / .medium)
- **23 font shorthand substitutions** across 8 SwiftUI views (Auth × 2, Nutrition Tabs × 3, Onboarding × 1, Shared × 2)
- **4 explicit `.accessibilityLabel(...)` modifiers** added (AIFeedbackView ×2 thumbs, AIIntelligenceSheet dismiss, SignInView error dismiss)
- **DS-A11Y-BUTTON audit window widened 20 → 60 lines** in `scripts/ui-audit.py`. The 20-line heuristic produced false-positives on `Stats/v2/StatsView.metricChip` (a11y label sits 40 lines past Button line because of multi-element `AppSelectionTile` label block) and `Nutrition/Components/SupplementItemRow.supplementToggle` (label sits 58 lines past Button line due to comprehensive a11y modifier chain). The code IS correct in both cases; the heuristic was too tight.

**Verification (T1):** `xcodebuild build` PASSED; `make ui-audit` P0=0; combined PR-1+PR-2 P1 baseline **103 → 44 (-59, 57% reduction)**.

## Combined outcome

| Metric | Baseline (2026-04-24) | Pre-burndown drift (2026-05-11) | Post-burndown (2026-05-11) | Reduction |
|---|---:|---:|---:|---:|
| P0 ui-audit findings | 0 | 0 | 0 | maintained |
| **P1 ui-audit findings** | **103** | 108 | **44** | **-59 (57%)** |
| Files with findings | 42 | — | 26 | -16 |
| DS-MAGIC-FRAME | 62 | — | 40 | -22 |
| DS-RAW-FONT-SHORTHAND | 26 | — | 0 | **-26 (100%)** |
| DS-A11Y-BUTTON | 6 | — | 0 | **-6 (100%)** |
| DS-MAGIC-PADDING | 6 | — | 4 | -2 |

All numbers T1 (instrumented — `make ui-audit-baseline` is the source).

## The 44 long-tail P1s — by design, not omission

40 DS-MAGIC-FRAME + 4 DS-MAGIC-PADDING remaining = unique design-specific
values that don't warrant single-use tokens:

| Sample | Where | Why a token would be wrong |
|---|---|---|
| `.frame(height: 180)` | Stats chart container | Chart-specific; another chart legitimately uses 240 |
| `.frame(height: 260)` | Modal sheet | Sheet-height is design-decision, not reusable |
| `.frame(width: 50)` | Divider visual | Single-use accent geometry |
| `.frame(height: 72)` | Training plan row | Row-specific dimension |
| `.padding(.horizontal, 18)` | A specific card | Single-use horizontal inset |

These stay as honest P1s under CLAUDE.md fix-as-you-touch. Future PRs
that touch these files SHOULD clear them as part of the change — but
the audit doesn't block on them, and the design system doesn't grow
to accommodate them.

## Risk handling

**Kill criterion (locked at task approval):** Net visual regression on a
critical user-path screen → revert the PR; investigate token; consider
whether the audit rule's recommended token is actually wrong for that
context.

**Resolution (post-spot-check):** `not_triggered_no_visual_regression`.
All token substitutions are visually identical at the pixel level (same
SwiftUI value, just named via `AppSize.*` / `AppText.*`). Operator iOS
simulator spot-check on each PR before merge confirmed zero drift on
touched screens (Training tab — SetRowView, ExerciseRowView, RestTimer,
FocusMode, SessionCompletion, TrainingPlanView; Shared — ReadinessCard,
ManualBiometricEntry; AI — AIFeedbackView, AIIntelligenceSheet;
Auth — SignInView, AuthHubView, WelcomeView, Biometric*; Profile —
AccountDataCard, GoalsTrainingCard, ProfileView; Nutrition Tabs —
SmartTabView, MealEntrySharedComponents, SearchTabView,
RecoveryRoutineSheet; Onboarding — OnboardingAuthView; Stats — StatsView
metricChip; Import — ImportSourcePickerView; Shared —
SyncStatusIndicator).

## Audit-script hardening (incidental discovery)

PR-2's DS-A11Y-BUTTON closure surfaced two legitimate-but-flagged
findings in already-correct code:

1. `Stats/v2/StatsView.metricChip` — has comprehensive a11y chain
   (`.accessibilityLabel("\(metric.title) metric")`,
   `.accessibilityValue(subtitle)`, `.accessibilityAddTraits`,
   `.accessibilityHint`) at the end of the modifier chain, 40 lines
   past the `Button {` line.

2. `Nutrition/Components/SupplementItemRow.supplementToggle` — has
   `.accessibilityElement(children: .combine)` +
   `.accessibilityLabel("\(supplement.name), \(supplement.dose)")` +
   `.accessibilityValue(isTaken ? "Taken" : "Not taken")` +
   `.accessibilityHint("Double tap to toggle")` 58 lines past the
   `Button {` line.

The 20-line audit window heuristic flagged these as missing labels
because it didn't scan far enough. Widening to 60 lines fixed both
without significant cross-button false-negative risk. **Honest framing
(T2):** widening the audit window is not "the audit becoming weaker" —
the heuristic produced false-positives that would have caused authors
to add redundant inline labels (genuinely worse a11y). The widened
window improves accuracy on complex multi-line label blocks.

## Why this didn't need a 5-PR rollout

The original 5 area-bucketed PRs (Shared / Training / Nutrition / Auth /
bundled-minor) assumed each area would have independent token
substitutions. Frequency analysis revealed the opposite: the same 4
magic values (44, 28, 80, 36) recurred across every area. One token
addition + one mass-substitution closes the same finding across all
areas at once. The 2-PR cross-area structure was strictly better than 5
area-bucketed PRs:
- Less review burden (2 PRs vs 5)
- Cleaner git history (token-definition + substitution in same commit)
- Faster wall time (~3h vs estimated ~10h for 5 PRs)

## Framework hygiene

- **v7.8.1 protocol:** isolated worktree (`/Volumes/DevSSD/FitTracker2-ios-p1`) from Phase 1 onward; Mechanism C session attribution via `.claude/active-feature`; Tier 2.2 logging on every phase transition; Mechanism A coverage telemetry verification on `ui-audit` gate
- **Branch-isolation:** PR-1 was the feature work (Swift code); PR-2 also Swift; both stayed in `feature/ios-ui-audit-p1-burndown*` branches per v7.8.1 Mode C
- **FEATURE_CLOSURE_COMPLETENESS:** this case study satisfies all 7 required frontmatter fields + `kill_criteria_resolution` + bidirectional PR-list parity (state.json `tasks[].pr_number` + `phases.merge.pr_number` ↔ this body cites `PR #292`, `PR #294`)

## Cross-references

- Parent feature case study: [`docs/case-studies/ui-audit-baseline-burndown.md`](ui-audit-baseline-burndown.md)
- Source baseline: `docs/design-system/ui-audit-baseline.md` (regenerated by `make ui-audit-baseline`)
- v7.8.1 protocol case study: [`docs/case-studies/framework-v7-8-branch-isolation-case-study.md`](framework-v7-8-branch-isolation-case-study.md)
- Strategy decision artifact: session memory `project_session_2026_05_11_ios_p1_burndown_paused.md`
- Tasks: `.claude/features/ios-ui-audit-p1-burndown/tasks.md` (records the strategy revision inline)
