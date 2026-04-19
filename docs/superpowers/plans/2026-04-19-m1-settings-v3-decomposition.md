# M-1 — SettingsView (v2) Decomposition

> **Audit finding**: UI-002 — SettingsView.swift (v2) is 1170 lines, actively compiled
> **Type**: Multi-session feature — case study tracking ON from start (per the rule + M-3 precedent)
> **Predecessor plan**: `docs/superpowers/plans/2026-04-19-audit-completion-plan.md` (M-1 row)
> **Date**: 2026-04-19

## Goal

Decompose `FitTracker/Views/Settings/v2/SettingsView.swift` (1170 lines) into focused per-screen files. After M-1, `SettingsView.swift` becomes a thin coordinator (~225 lines) and each detail screen lives in its own file alongside the shared component library.

## Source structure (read-only inventory)

The file is already well-organized into clearly-bounded sections:

| Lines | Section | Type | Decomposition target |
|---|---|---|---|
| 1-69 | Enums + types (SettingsCategory, SettingsSummaryBadge, SettingsReviewDestination) | private | Stay (small, view-internal) |
| 70-293 | `SettingsView` (main coordinator) | struct | Stay (this IS the entry point) |
| 294-400 | `AccountSecuritySettingsScreen` | private struct | **Extract → AccountSecuritySettingsScreen.swift** |
| 401-454 | `HealthDevicesSettingsScreen` | private struct | **Extract → HealthDevicesSettingsScreen.swift** |
| 455-609 | `GoalsPreferencesSettingsScreen` | private struct | **Extract → GoalsPreferencesSettingsScreen.swift** |
| 610-687 | `TrainingNutritionSettingsScreen` | private struct | **Extract → TrainingNutritionSettingsScreen.swift** |
| 688-814 | `DataSyncSettingsScreen` | private struct | **Extract → DataSyncSettingsScreen.swift** |
| 815-922 | Home header + category card + badge views | private struct | Stay (used by main coordinator only) |
| 923-1011 | Shared scaffolds (SettingsDetailScaffold, SettingsSectionCard, SettingsValueRow, SettingsSupportingText) | struct (already internal) | **Extract → SettingsScaffolds.swift** |
| 1012-1170 | Shared form components (SettingsActionLabel, SettingsSelectionTile, SettingsChoiceGrid, SettingsNumericFieldRow, SettingsSliderRow) | private struct | **Extract → SettingsFormComponents.swift** |

After full M-1: SettingsView.swift = ~225 lines (main coordinator + home view sub-components only).

## Phases

### Phase M-1a — Extract 5 detail screens (this sprint)

Move each of the 5 `*SettingsScreen` private structs to its own file under `FitTracker/Views/Settings/v2/Screens/`. Bump visibility from `private` to `internal` (file-private to module-internal) so the main coordinator can reference them. Detail screens currently take their dependencies via `@EnvironmentObject` so no init signature changes needed.

| New file | Lines moved | Original location |
|---|---|---|
| `Screens/AccountSecuritySettingsScreen.swift` | ~107 | 294-400 |
| `Screens/HealthDevicesSettingsScreen.swift` | ~54 | 401-454 |
| `Screens/GoalsPreferencesSettingsScreen.swift` | ~155 | 455-609 |
| `Screens/TrainingNutritionSettingsScreen.swift` | ~78 | 610-687 |
| `Screens/DataSyncSettingsScreen.swift` | ~127 | 688-814 |
| **Total moved** | **~521 lines** | |

After M-1a: SettingsView.swift = ~649 lines.

**Risk**: medium. Each screen has its own dependencies (services via `@EnvironmentObject`, helper components via direct call). All references stay module-internal so compilation should succeed once visibility is bumped.

**Pbxproj updates**: 5 new file references + Sources entries + a new "Screens" PBXGroup under `Settings/v2/`.

### Phase M-1b — Extract shared components (next sprint)

Move the shared scaffolds + form components to their own files under `FitTracker/Views/Settings/v2/Components/`. These are used by the main coordinator AND the 5 detail screens.

| New file | Lines moved | Original location |
|---|---|---|
| `Components/SettingsScaffolds.swift` | ~89 | 923-1011 (SettingsDetailScaffold, SettingsSectionCard, SettingsValueRow, SettingsSupportingText) |
| `Components/SettingsFormComponents.swift` | ~158 | 1012-1170 (SettingsActionLabel, SettingsSelectionTile, SettingsChoiceGrid, SettingsNumericFieldRow, SettingsSliderRow + SettingsActionTrailing enum) |
| **Total moved** | **~247 lines** | |

After M-1b: SettingsView.swift = ~402 lines.

### Phase M-1c — Final SettingsView trim (if needed)

If SettingsView.swift is still > 400 lines after M-1b, evaluate whether the home view sub-components (lines 815-922 — SettingsHomeHeader, SettingsCategoryCard, FlexibleBadgeRow, SettingsBadgeView) deserve their own `Components/SettingsHomeViews.swift`. May or may not be needed depending on actual line count after the prior phases.

### Phase M-1d — Case study + monitoring entry

Per the rule, M-1 gets its own case study. Following M-3's "concurrent tracking" pattern, this happens in the same session as M-1a/b/c (not retroactive).

## Out of scope

- **Behavior changes** — pure structural decomposition. Every screen renders identically before and after.
- **Renaming or API changes** — keep all type names (`AccountSecuritySettingsScreen`, etc.) so call sites in SettingsView don't change.
- **New tests** — settings view doesn't have unit tests; XCUITest infrastructure (M-4) is the right vehicle for coverage here.
- **Visual changes** — no spacing/color/font changes.

## Success criteria

- After Phase M-1a: SettingsView.swift drops from 1170 → ~649 lines, build green, all 5 detail screens render correctly
- After Phase M-1b: SettingsView.swift drops to ~402 lines
- After Phase M-1c: SettingsView.swift ≤ 400 lines OR explicitly documented as "this is the right size for the coordinator"
- After Phase M-1d: case study + monitoring entry shipped per the rule

## Estimated effort

| Phase | Effort | Risk |
|---|---|---|
| M-1a (this PR) | 60-90 min | medium (5 file extractions + pbxproj updates) |
| M-1b | 45-60 min | low (component library extraction) |
| M-1c | 15-30 min if needed | low |
| M-1d | 60-90 min | low |
| **Total** | **~3-4 hours** | |

## Rollback plan

Each phase ships as its own PR. If a phase introduces a regression (visual or behavioral), revert the PR. The shared component library + screen files were carved out of the same module, so undoing is git-revert-clean.
