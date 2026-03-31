# FitTracker Design System — Layered Approval & Verification Plan

**Date:** 2026-03-31
**Figma file:** `0Ai7s3fCFqR5JXDW8JvgmD`
**Purpose:** Every element in the design system and every screen in the app goes through a structured approval gate before it is considered "done". Nothing advances without owner sign-off.

---

## Principles

1. **You approve every layer** — tokens, components, screens, flows. Nothing is auto-approved.
2. **Code is the source of truth** — Figma must mirror the running app, not the other way around.
3. **Evidence-based** — every approval includes a simulator screenshot or Figma screenshot proving the match.
4. **Incremental** — small batches, fast feedback. One layer at a time, not a big-bang merge.

---

## Phase Structure (Updated)

```
P0   Code cleanup                          ✅ Done
P0.5 Unify PR #14 + #15 into single branch 🔴 Next
P1   Token pipeline (CI gates)             ✅ Done (in PR #14, pending merge)
P2   Figma foundations (variables, styles)  ⏳ Blocked on P0.5
P3   Component library                     ⏳ Blocked on P2
P4   Screen builds (live assets)           ⏳ Blocked on P3
P5   QA & approval sweep                   ⏳ Blocked on P4
P6   Merge gate                            ⏳ Final
P7   Android adaptation                    ⏳ Optional
```

Each phase below has **approval gates** — explicit checkpoints where you review and approve before work continues.

---

## P0.5 — Unify PR #14 + #15 into Single Branch + Code Review

### Problem
Design system work is currently split across two open PRs:
- **PR #14** (`feat/design-system-v2`) — architecture, pipeline, components, tests, CI
- **PR #15** (`claude/continue-execution-bJN3i`) — token migration across all views

These overlap, may contain duplicated code, and create merge complexity. Before any Figma work begins, we unify into one clean branch.

### Step 1: Branch Merge
- Create a fresh unified branch from `main` (e.g. `feat/design-system-unified`)
- Cherry-pick or merge PR #14 changes first (infrastructure layer)
- Then apply PR #15 changes on top (migration layer)
- Resolve any merge conflicts

### Step 2: Full Code Review (Post-Merge)
Systematic review of the unified branch to eliminate duplication and simplify:

| Check | What to look for |
|---|---|
| **Duplicate types** | Same struct/enum defined in multiple files (e.g. `AppComponents.swift` vs `AppDesignSystemComponents.swift` vs `Shared/*.swift`) |
| **Duplicate tokens** | Same color/spacing/radius defined in both `AppPalette.swift` and `AppTheme.swift`, or token defined but never used |
| **Orphan files** | Files from old structure that are no longer referenced (dead imports, removed views still in Xcode project) |
| **Import chain** | Verify clean dependency: `AppPalette` → `AppTheme` → `Views`. No circular refs, no views importing palette directly |
| **Token coverage** | Grep for remaining raw `Color()`, `Font.system(size:)`, hardcoded `padding()` / `cornerRadius()` — flag any that survived migration |
| **Test coverage** | All design-system tests pass. No test references to deleted types |
| **CI pipeline** | `make tokens-check` and `make lint-ds` both pass on the unified branch |
| **Xcode project** | All new files added to target, no red file references, no stale groups |

### Step 3: Produce Diff Report
- List of files removed (deduplication)
- List of files renamed/moved (simplification)
- List of remaining raw literals (if any, with justification)
- Token inventory: total count per category

### Approval Gate
- **You review** the diff report and unified branch structure.
- **You approve** before any Figma work begins.
- Close PR #14 and PR #15 after approval. The unified branch becomes the single source of truth.

**P0.5 exit gate:** Single clean branch with zero duplication, all tests passing, your `✅`.

---

## P2 — Figma Foundations

### P2b — Variable Collections

Work is done **one collection at a time**. For each collection:

#### Step 1: Code Inspection
- I read the Swift source (`AppPalette.swift`, `AppTheme.swift`) and list every token with its exact value.
- I present you a **token table** showing: token name, Swift value, proposed Figma variable name.

#### Step 2: Figma Write
- I use `use_figma` to create/update the variables in the Figma file.
- I call `get_variable_defs` to verify what was written.

#### Step 3: Approval Gate
- I present you the **before/after diff** — what Figma has vs what code defines.
- **You approve or request changes** before moving to the next collection.

**Collections in order:**

| # | Collection | Source | Variables |
|---|---|---|---|
| 1 | Color / Primitives | `AppPalette.swift` | ~16 raw colors |
| 2 | Color / Semantic | `AppTheme.swift` → `AppColor.*` | ~37 semantic tokens |
| 3 | Spacing | `AppTheme.swift` → `AppSpacing.*` | 9 values (4pt grid) |
| 4 | Radius | `AppTheme.swift` → `AppRadius.*` | 9 values |
| 5 | Elevation / Shadow | `AppTheme.swift` → `AppShadow.*` | 6 values |
| 6 | Motion | `AppTheme.swift` → `AppDuration/AppSpring` | 7 values |
| 7 | Typography | `AppTheme.swift` → `AppText.*` / `AppFontSize.*` | 20-22 roles |

**Approval artifact per collection:** Token table + `get_variable_defs` output confirming exact match.

---

### P2c — Text Styles

| Step | Action | Approval |
|---|---|---|
| 1 | List all `AppText.*` roles from code with font, size, weight, line height | You review the table |
| 2 | Create/update Figma text styles via `use_figma` | — |
| 3 | Screenshot the Typography Repository page | **You approve** |

### P2d — Effect Styles

| Step | Action | Approval |
|---|---|---|
| 1 | List `AppShadow.*` values from code (color, radius, x, y) | You review |
| 2 | Create/update Figma effect styles | — |
| 3 | Screenshot showing shadow applied to sample card | **You approve** |

**P2 exit gate:** All 7 variable collections approved + text styles approved + effect styles approved.

---

## P3 — Component Library

### Per-Component Process

For each component in the library (target: 15+), the process is:

#### Step 1: Code Audit
- Read the Swift component file.
- Extract: all props/parameters, all visual states, all token bindings.
- Present a **component spec card**:
  ```
  Component:    AppButton
  Source:       FitTracker/DesignSystem/AppComponents.swift:L42
  Props:        label (String), style (primary|secondary|tertiary|destructive), isDisabled (Bool), isLoading (Bool)
  States:       default, pressed, disabled, loading
  Tokens used:  AppColor.Brand.warm, AppRadius.button, AppText.button, AppSpacing.small
  A11y:         accessibilityLabel from label prop
  ```

#### Step 2: Figma Build
- Build component set in Figma with all variants using `use_figma`.
- Bind every color/spacing/radius to the approved Figma variables from P2.

#### Step 3: Inspect & Compare
- `get_screenshot` of the Figma component.
- Present side-by-side: **Figma screenshot** vs **component spec card**.

#### Step 4: Approval Gate
- **You approve** the component or request changes.
- Approved components get a `✅` in the tracking table below.

### Component Tracking Table

| # | Component | Swift Source | Figma Status | Variants | Approved |
|---|---|---|---|---|---|
| 1 | AppButton | `AppComponents.swift` | Exists (8 variants) | primary/secondary/tertiary/destructive × default/disabled | ⏳ |
| 2 | AppCard | `AppComponents.swift` | Exists (4 variants) | compact/default/spacious/elevated | ⏳ |
| 3 | AppMenuRow | `AppComponents.swift` | Exists (4 variants) | default/icon/badge/chevron | ⏳ |
| 4 | AppSelectionTile | `AppComponents.swift` | Exists (4 variants) | selected/unselected/disabled/focused | ⏳ |
| 5 | AppInputShell | `AppComponents.swift` | Exists (4 variants) | default/focused/error/disabled | ⏳ |
| 6 | AppFieldLabel | `AppComponents.swift` | Exists (2 variants) | default/required | ⏳ |
| 7 | AppQuietButton | `AppComponents.swift` | Exists (3 variants) | default/pressed/disabled | ⏳ |
| 8 | StatusBadge | `Shared/StatusBadge.swift` | Exists (6 variants) | success/warning/error/info/neutral/custom | ⏳ |
| 9 | EmptyStateView | `Shared/EmptyStateView.swift` | Exists (3 variants) | default/withCTA/minimal | ⏳ |
| 10 | AppPickerChip | `AppComponents.swift` | **Not built** | selected/unselected/disabled | ⏳ |
| 11 | AppFilterBar | `AppComponents.swift` | **Not built** | single/multi/overflow | ⏳ |
| 12 | AppSheetShell | `AppComponents.swift` | **Not built** | default/withDismiss/destructive | ⏳ |
| 13 | AppStatRow | `AppComponents.swift` | **Not built** | withIcon/plain/customColor | ⏳ |
| 14 | AppSegmentedControl | `AppComponents.swift` | **Not built** | 2/3/4 segments | ⏳ |
| 15 | AppProgressRing | `AppComponents.swift` | **Not built** | 0%/50%/100%/withLabel | ⏳ |
| 16 | ChartCard | `Shared/ChartCard.swift` | **Not built** | empty/line/bar | ⏳ |
| 17 | MetricCard | `Shared/MetricCard.swift` | **Not built** | loading/value/trend | ⏳ |
| 18 | ReadinessCard | `Shared/ReadinessCard.swift` | **Not built** | low/medium/high | ⏳ |
| 19 | TrendIndicator | `Shared/TrendIndicator.swift` | **Not built** | up/down/flat | ⏳ |
| 20 | SectionHeader | `Shared/SectionHeader.swift` | **Not built** | default/withAction | ⏳ |
| 21 | MacroTargetBar | `Nutrition/MacroTargetBar.swift` | **Not built** | empty/partial/full | ⏳ |
| 22 | MealSectionView | `Nutrition/MealSectionView.swift` | **Not built** | empty/withMeals | ⏳ |

**P3 exit gate:** All components approved individually. No component advances to P4 without your `✅`.

---

## P4 — Screen Builds (Live Assets)

This is the core of the bidirectional sync. Each app screen becomes a **live editable Figma frame** that mirrors the running code pixel-for-pixel.

### Per-Screen Process

#### Step 1: Code Read
- Read the full SwiftUI view file.
- Map every element to its component + token binding.
- Produce a **screen blueprint**:
  ```
  Screen:      MainScreenView (Home tab)
  Source:      FitTracker/Views/Main/MainScreenView.swift
  Layout:      ScrollView > VStack(spacing: AppSpacing.medium)
  Elements:
    1. ReadinessCard          → tokens: AppColor.Surface.card, AppRadius.large
    2. GoalProgressRow        → tokens: AppColor.Brand.warm, AppSpacing.small
    3. QuickActionDeck (4x)   → tokens: AppColor.Surface.materialLight, AppRadius.medium
    4. RecoverySection        → tokens: AppText.sectionTitle, AppSpacing.large
  Sheets:
    - ManualBiometricEntry (triggered by quick action)
    - MilestoneModal (triggered by achievement)
  ```

#### Step 2: Figma Build
- Build the screen frame at iPhone 16 Pro width (393pt) using approved P3 components.
- Every element uses approved variable bindings — no raw values.
- Build all meaningful states (empty, populated, error, loading).

#### Step 3: Screenshot Comparison
- **Figma screenshot:** `get_screenshot` of the built screen frame.
- **Simulator screenshot:** If available, capture from Xcode simulator for the same screen/state.
- Present **side-by-side** for your review.

#### Step 4: Inspection Report
- I run `get_design_context` on the Figma frame.
- Report which tokens are bound vs any remaining raw values.
- Flag any drift: "Figma uses `#FA8F40` but code defines `AppPalette.orange500 = #FA8F40` ✅" or "⚠️ Mismatch".

#### Step 5: Approval Gate
- **You approve** the screen or request changes.
- Approved screens get `✅` and are locked.

### Screen Tracking Table

| # | Screen | Page | States | Approved |
|---|---|---|---|---|
| **Auth Flow** | | | | |
| 1 | AuthEntryScreen | Login | register mode, login mode | ⏳ |
| 2 | EmailRegistrationView | Login | default, validation error | ⏳ |
| 3 | EmailVerificationView | Login | waiting, error, success | ⏳ |
| 4 | EmailLoginView | Login | default, error | ⏳ |
| 5 | LockScreenView | Login | biometric prompt, error | ⏳ |
| **Main Tabs** | | | | |
| 6 | MainScreenView (Home) | Main Screen | today summary, rest day, active training | ⏳ |
| 7 | TrainingPlanView | Training | scheduled, active session, rest day | ⏳ |
| 8 | SessionCompletionSheet | Training | with PRs, without PRs | ⏳ |
| 9 | NutritionView | Nutrition | empty, meals logged, full macros | ⏳ |
| 10 | MealEntrySheet | Nutrition | smart tab, manual tab, template tab, search tab | ⏳ |
| 11 | StatsView | Stats | all chart tabs, empty state | ⏳ |
| **Account & Settings** | | | | |
| 12 | AccountPanelView | Account + Security | signed in, sync status | ⏳ |
| 13 | SettingsView | Settings | all 6 sections | ⏳ |
| **Sub-screens & Modals** | | | | |
| 14 | ManualBiometricEntry | Main Screen | weight, BF, HR, HRV, sleep fields | ⏳ |
| 15 | MilestoneModal | Main Screen | streak, PR, phase transition | ⏳ |
| 16 | RestTimerOverlay | Training | counting down, expired | ⏳ |
| 17 | FocusModeView | Training | active exercise, between sets | ⏳ |
| **Navigation Chrome** | | | | |
| 18 | RootTabView (tab bar) | Patterns | 4 tabs selected states | ⏳ |
| 19 | NavigationBar | Patterns | with title, with account button | ⏳ |
| **Onboarding** | | | | |
| 20 | Onboarding flow | Onboarding | welcome, profile setup, permissions | ⏳ |

**P4 exit gate:** All 20 screens approved. Every screen has: Figma frame + screenshot comparison + inspection report + your `✅`.

---

## P5 — QA & Approval Sweep

After all screens are individually approved, run a full cross-cutting audit:

### 5a — Token Binding Audit
- Run `get_variable_defs` and cross-reference every variable against code.
- Report: total variables, bound count, unbound count, orphan variables.
- **You approve** the binding report.

### 5b — Contrast & Accessibility Audit
- Check every text token against its background for WCAG AA (4.5:1 body, 3:1 large).
- Check every interactive element for 44pt minimum touch target.
- Report pass/fail table.
- **You approve** the accessibility report.

### 5c — Screenshot Review (Full App Walkthrough)
- Capture simulator screenshots for every screen in order (auth → home → training → nutrition → stats → settings).
- Capture matching Figma screenshots for every screen.
- Present as a **side-by-side gallery**.
- **You approve** the full walkthrough or flag specific screens for revision.

### 5d — Prototype Flow Verification
- Wire all approved screen frames into Figma prototype flows.
- Test each flow: auth → home, tab navigation, sheet presentations, back navigation.
- Record flow coverage:

| Flow | Screens Connected | Status |
|---|---|---|
| Auth → Home | Entry → Method → Email → Verify → Home | ⏳ |
| Tab navigation | Home ↔ Training ↔ Nutrition ↔ Stats | ⏳ |
| Meal logging | Nutrition → MealEntry → save → Nutrition | ⏳ |
| Training session | Training → session → completion | ⏳ |
| Account & Settings | Any tab → Account → Settings → back | ⏳ |

- **You approve** each flow.

**P5 exit gate:** All 4 QA checks approved.

---

## P6 — Merge Gate

Final checklist before merging the unified branch to main:

- [ ] P0.5 unified branch approved (no duplication, clean structure)
- [ ] All P2 variable collections approved (7/7 + text styles + effect styles)
- [ ] All P3 components approved (22/22)
- [ ] All P4 screens approved (20/20)
- [ ] P5a token binding audit passed
- [ ] P5b accessibility audit passed
- [ ] P5c screenshot walkthrough approved
- [ ] P5d prototype flows approved
- [ ] `make tokens-check` passes in CI
- [ ] `make lint-ds` passes in CI
- [ ] No raw `Color()`, `Font.system(size:)`, or hardcoded padding in view files
- [ ] PR #14 and PR #15 closed (superseded by unified branch)
- [ ] Single PR from unified branch → main with full before/after evidence

**You give final merge approval.**

---

## Approval Record Template

Every approval gets logged here with date and decision:

```
## Approval Log

| Date | Phase | Item | Decision | Notes |
|------|-------|------|----------|-------|
| — | P2b.1 | Color/Primitives | ⏳ | — |
| — | P2b.2 | Color/Semantic | ⏳ | — |
| — | P2b.3 | Spacing | ⏳ | — |
| — | P2b.4 | Radius | ⏳ | — |
| — | P2b.5 | Elevation | ⏳ | — |
| — | P2b.6 | Motion | ⏳ | — |
| — | P2b.7 | Typography vars | ⏳ | — |
| — | P2c | Text styles | ⏳ | — |
| — | P2d | Effect styles | ⏳ | — |
| — | P3.1–22 | Components (each) | ⏳ | — |
| — | P4.1–20 | Screens (each) | ⏳ | — |
| — | P5a | Token binding audit | ⏳ | — |
| — | P5b | Accessibility audit | ⏳ | — |
| — | P5c | Screenshot walkthrough | ⏳ | — |
| — | P5d | Prototype flows | ⏳ | — |
| — | P6 | Final merge | ⏳ | — |
```

---

## How a Typical Approval Cycle Works

```
┌─────────────────────────────────────────────────┐
│  1. I read the code and extract the spec         │
│  2. I present the spec table to you              │
│  3. You review → approve or request changes      │
│  4. I build/update in Figma via use_figma        │
│  5. I screenshot the result (get_screenshot)     │
│  6. I inspect the result (get_design_context)    │
│  7. I present evidence: screenshot + inspection  │
│  8. You verify → approve ✅ or iterate 🔄        │
│  9. Approval logged, advance to next item        │
└─────────────────────────────────────────────────┘
```

**No batch approvals.** Each token collection, component, and screen is reviewed individually. You see exactly what was built, how it maps to code, and whether it matches the running app.
