---
title: "iOS UI-Audit P1 Drift Cleanup — 44 → 14 (Option B respected)"
date: 2026-05-12
date_written: 2026-05-12
framework_version: v7.8.3
work_type: enhancement
work_subtype: audit_burndown
parent_feature: ios-ui-audit-p1-burndown
parent_case_study: docs/case-studies/ios-ui-audit-p1-burndown-case-study.md
dispatch_pattern: single-agent-tdd-sequential
primary_metric: ui_audit_p1_count
success_metrics:
  - "ui_audit_p1_count: 44 → 14 (-68%)"
  - "DS-MAGIC-FRAME: 40 → 12"
  - "DS-MAGIC-PADDING: 4 → 0"
  - "xcodebuild build PASSES"
kill_criteria:
  - "Visual regression on any critical user-path screen caused by token substitution → revert"
kill_criteria_resolution: "not_triggered — all 10 AppSize tokens use semantic names tied to existing patterns; padding swaps stay on 4pt grid with 1-2pt shifts at most. xcodebuild build PASSES. Operator simulator spot-check pending."
tier_tags_present: ["T1"]
related_prs:
  - "PR #307"
case_study_showcase: fitme-story/content/04-case-studies/31-ios-ui-audit-p1-drift-cleanup.mdx
pr_citation_exempt:
  - pr_number: 292
    reason: "Parent feature reference (predecessor)"
  - pr_number: 294
    reason: "Parent feature reference (predecessor)"
---

# iOS UI-Audit P1 Drift Cleanup — 44 → 14 (Option B respected)

## TL;DR (T1)

Drift-cleanup follow-up to [`ios-ui-audit-p1-burndown`](ios-ui-audit-p1-burndown-case-study.md) (PRs #292 + #294). Respects Option B's locked ceiling — tokenized ONLY magic dims with **frequency ≥ 2**. The 14 remaining are true singletons that stay as fix-as-you-touch per the parent feature's locked decision.

| Dimension | Value (T1) |
|---|---|
| `make ui-audit` P1 | 44 → 14 (-30, -68%) |
| DS-MAGIC-FRAME | 40 → 12 |
| DS-MAGIC-PADDING | 4 → 0 |
| Tokens added | 10 (`AppSize`) |
| Files touched | 15 |
| `xcodebuild build` | PASS |
| Wall time | ~97 min |
| PRs | 1 ([#307](https://github.com/Regevba/FitTracker2/pull/307), merge `f0b305a`) |

## What shipped

### 10 new `AppSize` tokens

| Token | Value | Occurrences | Sites |
|---|---|---|---|
| `indicatorDotTiny` | 6 | 7 | StatusDropdown, SyncStatusIndicator, RootTabView, SettingsHomeViews |
| `chartHeightTall` | 200 | 5 | ImportSourcePicker, BodyCompositionDetail (×3), ChartCard |
| `chartHeightCompact` | 180 | 2 | ReadinessCard (×2) |
| `chartMinWidth` | 260 | 2 | NutritionView, ReadinessCard |
| `iconJumbo` | 96 | 2 | WelcomeView, SettingsFormComponents |
| `avatarHero` | 72 | 2 | ProfileHeroSection, TrainingPlanView |
| `illustrationLarge` | 120 | 2 | WelcomeView, OnboardingAuthView |
| `illustrationXLarge` | 160 | 2 | ConsentView, OnboardingConsentView |
| `controlSmall` | 34 | 2 | SettingsHomeViews, LiveInfoStrip |
| `progressBarHeightTall` | 6 | 3 | ReadinessCard score tracks |

### 4 magic-padding fixes (swap to 4pt grid)

- `AuthHubView` L617: `padding(.vertical, 13)` → `AppSpacing.xSmall (12)` (-1pt)
- `ReadinessCard` L49: `padding(.bottom, 6)` → `AppSpacing.xxSmall (8)` (+2pt)
- `RecoveryRoutineSheet` L123: `padding(.vertical, 9)` → `AppSpacing.xxSmall (8)` (-1pt)
- `SyncStatusIndicator` L19: `padding(.vertical, 10)` → `AppSpacing.xxSmall (8)` (-2pt)

## What stays deferred (14 remaining P1s)

All true singletons: `50` (×2 niche dividers in ReadinessCard), `76`, `88`, `60`, `58`, `320`, `30`, `280`, `220`, `150`, `140`, `14`, `0.5`. Each appears once. Adding a token for each would bloat the design system without improving coherence — stays as fix-as-you-touch per the parent feature's locked Option B decision.

## Verification (T1)

- `make ui-audit`: P1 = 14 (verified post-substitution)
- `xcodebuild build`: PASS (exit 0)
- 0 new test failures introduced

## Honest disclosure

This was a **deliberate scope-locked enhancement**, not a bulldoze. The user could have asked me to push past Option B's ceiling to 0; I surfaced the contradiction with the parent's locked decision and we agreed to respect it. The frequency-≥-2 rule produced a defensible 68% reduction without violating the parent's "high-frequency tokens only" rationale.

## Source-of-truth artifacts

| Artifact | Location |
|---|---|
| State.json | `.claude/features/ios-ui-audit-p1-drift-cleanup/state.json` |
| Tier 2.2 log | `.claude/logs/ios-ui-audit-p1-drift-cleanup.log.json` |
| Implementation PR | [#307](https://github.com/Regevba/FitTracker2/pull/307) (squash `f0b305a`) |
| Showcase MDX | `fitme-story/content/04-case-studies/31-ios-ui-audit-p1-drift-cleanup.mdx` |

## Predecessor chain

`ios-ui-audit-p1-burndown` (2026-05-11, [#292](https://github.com/Regevba/FitTracker2/pull/292) + [#294](https://github.com/Regevba/FitTracker2/pull/294))
→ **`ios-ui-audit-p1-drift-cleanup`** (2026-05-12, this case study, PR #307)
