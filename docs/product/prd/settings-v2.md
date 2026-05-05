# PRD: Settings v2 — UX Foundations Alignment + Decomposition

> **ID:** v2-refactor of 18.7 (settings) | **Status:** Shipped | **Priority:** P1 (final v2 alignment in the 6-screen series)
> **Last Updated:** 2026-05-05 (retroactive PRD via iOS audit Tier 2 finding C-1)
> **Branches:** `feature/settings-v2` (PR #77, original alignment) + `feature/m-1-settings-decomposition` (PRs #122-#125, decomposition)
> **Parent PRD:** [`18.7-settings.md`](18.7-settings.md)
> **State:** [`.claude/features/settings-v2/state.json`](../../.claude/features/settings-v2/state.json) (`current_phase: complete`)
> **Audit Report:** [`.claude/features/settings-v2/v2-audit-report.md`](../../.claude/features/settings-v2/v2-audit-report.md)

> **Retroactive note (2026-05-05):** This PRD was authored after the feature shipped, as part of the iOS audit Tier 2 finding C-1. Settings-v2 was the LAST screen in the 6-screen v2 alignment series (Home, Onboarding, Stats, Training, Nutrition, Settings) and shipped at v5.0. A `v2-audit-report.md` exists with the full compliance scorecard; this PRD formalizes the WHAT/WHY of the v2 refactor itself for the PRD chain. All claims sourced from PR #77 body, PR #122-#125 bodies, the audit report, the M-1 case study (`docs/case-studies/m-1-settings-decomposition-case-study.md`), and the shipped code in `FitTracker/Views/Settings/v2/`. Nothing is fabricated.

---

## Purpose

Bring the Settings screen into UX Foundations compliance (the project-wide design rule established 2026-04-09 via Home v2) and decompose its 1,170-line monolith into a maintainable `v2/` structure with extracted sub-screens and components.

## Business Objective

Two business drivers:

1. **UX consistency.** Settings was the last screen still using v1 patterns after Home v2, Stats v2, Training v2, and Nutrition v2 had landed. Inconsistency on a screen as routinely-used as Settings would erode the design-system credibility built by the other v2 ships.

2. **Architectural maintainability.** Settings v1 (`SettingsView.swift`, 1,170 lines, 14 nested types) was the second-largest file in the app after `TrainingPlanView.swift`. Decomposition was needed before adding new settings (Sentry opt-in, biometric activation, push-notification preferences) without compounding the file size.

## Target Persona(s)

- **All personas** — every user touches Settings (account management, sync controls, consent toggles, debug surfaces)

## What Shipped

This feature shipped in **TWO waves**, both required for "complete":

### Wave 1: UX Foundations Alignment — PR #77 (2026-04-10, commit `31ff8736`)

Per the audit report `.claude/features/settings-v2/v2-audit-report.md`:

| Dimension | v1 score | v2 score |
|---|---|---|
| Font tokens | 99% (2 raw) | 100% |
| Color tokens | 85% (8 raw) | 100% |
| Spacing tokens | 100% | 100% |
| Radius tokens | 100% | 100% |
| Motion tokens | 100% (0 raw) | 100% |
| Accessibility | 13% (1/8 elements labeled) | High (target ≥ 80%; a11y for destructive actions, sync controls, consent toggles all added) |
| Component architecture | "Best of any v1 — 14 well-extracted nested types" | maintained |

**Per PR #77 body:**
- 4 findings closed (0 P0, 2 P1, 2 P2 — the lightest of the 6 v2 screen audits)
- 8 raw colors → `AppColor.Accent.*` and `AppColor.Status.*` tokens
- 2 raw fonts → `AppText.captionStrong`
- Key accessibility: destructive `Delete All Local Data` button, sync actions, consent toggles
- 3 new analytics events with `settings_` prefix (per project Analytics Naming Convention rule from 2026-04-08)
- 5 analytics tests (event firing + consent gating + naming-convention compliance)

**Settings v2 directly entered the build** via the v2/ subdirectory pattern (V2 Rule, codified 2026-04-09):
- v1 file `FitTracker/Views/Settings/SettingsView.swift` annotated `HISTORICAL —`
- v2 file `FitTracker/Views/Settings/v2/SettingsView.swift` added to build target
- `project.pbxproj` swap

### Wave 2: M-1 Decomposition — PRs #122 + #123 + #124 + #125 (2026-04-19, framework v7.x)

Per state.json reconciliation note + M-1 case study:

> "SettingsView 1170 → 294 lines. PRs #122-#125. Tasks reconciled 2026-04-20."

The original v2 SettingsView still sat at ~1,170 lines after the alignment pass (alignment changed tokens, not structure). M-1 (a follow-on track tracked separately as `docs/case-studies/m-1-settings-decomposition-case-study.md`) decomposed it:

**Final file structure under `FitTracker/Views/Settings/v2/`:**
- `SettingsView.swift` (294 lines) — top-level scaffold
- `Components/` — 3 files
  - `SettingsFormComponents.swift` — reusable form rows
  - `SettingsHomeViews.swift` — home-section partials
  - `SettingsScaffolds.swift` — section containers
- `Screens/` — 5 sub-screen files
  - `AccountSecuritySettingsScreen.swift` — auth + biometric + Apple Sign-In + passkeys
  - `DataSyncSettingsScreen.swift` — CloudKit + Supabase sync controls + manual sync
  - `GoalsPreferencesSettingsScreen.swift` — weight/body-comp goals + units + appearance
  - `HealthDevicesSettingsScreen.swift` — HealthKit permissions + paired devices
  - `TrainingNutritionSettingsScreen.swift` — exercise prefs + meal logging defaults

**Net delta:** SettingsView root went from 1,170 → 294 lines (75% reduction at the entry point). Logic redistributed across 8 files with clear responsibilities.

## Success Metrics

| Metric | Tier | Target | Verified |
|---|---|---|---|
| ui-audit P0 findings on Settings v2 files | T1 | 0 | ✓ Confirmed via `make ui-audit` (2026-05-05) — Settings has 0 P0 |
| ui-audit P1 findings | T1 | < v1 baseline | ✓ Audit report shipped with 4 findings, all closed in PR #77 |
| Token compliance (font/color/spacing/radius/motion) | T1 | 100% all 5 dimensions | ✓ Per audit report post-PR #77 |
| `settings_*` analytics event coverage | T1 | All 3 declared events firing | ✓ Per `AnalyticsTests.swift` (5 tests) |
| Lines per file (decomposition target) | T1 | Root ≤ 500 lines | ✓ 294 lines post-M-1 |

## Kill Criteria

- ui-audit P0 finding introduced on any Settings v2 file → revert + fix-as-you-touch
- Token compliance regresses below 100% on any of font/color/spacing/radius/motion → revert
- Accessibility regression detected via Accessibility Inspector or VoiceOver smoke test on the Delete All Local Data flow

No growth-threshold kill criterion. Settings is a "floor-only" feature (must work, must be accessible, must be discoverable); growth metrics don't apply.

## Tests

Per state.json + PR #77 + M-1 PRs:
- 5 analytics tests in `FitTrackerTests/AnalyticsTests.swift` (settings_ prefix coverage)
- v2 sub-screens have unit tests inherited from `FitTrackerTests/AppSettingsAndGoalProfileTests.swift`
- `xcodebuild build` BUILD SUCCEEDED at every PR merge in the M-1 series
- ui-audit gate: 0 P0 maintained throughout

## Predecessor / Successor Linkage

- **Parent PRD:** [`18.7-settings.md`](18.7-settings.md)
- **Sibling v2 features (in the 6-screen alignment series):** home-today-screen (Home v2), nutrition-v2, stats-v2, training-plan-v2, onboarding-v2-auth-flow + onboarding-v2-retroactive
- **Children (additive features that landed AFTER Settings v2):**
  - `auth-polish-v2` (biometric activation sheet, password reset, Google sign-in) — PRD at `.claude/features/auth-polish-v2/prd.md`
  - `gdpr-compliance` (Account Deletion + Data Export) — surfaces in Account Security screen via PR #44
  - `smart-reminders-behavioral-learning` (BehavioralLearningSettingsView) — wires into Settings via the `BehavioralLearningSettingsView.swift` referenced in pbxproj
- **Audit input:** [`v2-audit-report.md`](../../.claude/features/settings-v2/v2-audit-report.md) drove PR #77's scope
- **Decomposition tracker:** [`m-1-settings-decomposition-case-study.md`](../../case-studies/m-1-settings-decomposition-case-study.md) covers the M-1 wave

## Why this PRD was retroactive

- The v2 alignment shipped 2026-04-10 (PR #77) before the project's PRD-required-for-v2-refactors rule was crystallized
- The decomposition shipped 2026-04-19 (PRs #122-#125) as the M-1 work track, which used the case-study + v2-audit-report path rather than a dedicated PRD
- 2026-05-05 iOS audit (finding C-1) flagged the absence of a discoverable PRD for the v2 work itself
- Decision: rather than mark `case_study_type: pre_pm_workflow_backfill` (the exempt path), write a real PRD documenting WHAT/WHY of the v2 refactor — per the user's "formalize older work that must be documented properly" directive

The PRD is forward-looking: future readers (human or agent) can find this v2 refactor's intent + scope via `docs/product/prd/settings-v2.md`, follow links to the audit report, and trace the chain of custody to the M-1 case study.

## Cross-references

- **Parent PRD:** [`18.7-settings.md`](18.7-settings.md)
- **Audit report:** [`v2-audit-report.md`](../../.claude/features/settings-v2/v2-audit-report.md)
- **State:** `.claude/features/settings-v2/state.json`
- **Original alignment PR:** #77 (2026-04-10, commit `31ff8736`)
- **Decomposition PR series:** #122 + #123 + #124 + #125 (2026-04-19)
- **M-1 case study:** [`m-1-settings-decomposition-case-study.md`](../../case-studies/m-1-settings-decomposition-case-study.md)
- **V2 Rule reference:** [CLAUDE.md "UI Refactoring & V2 Rule"](../../../CLAUDE.md)
