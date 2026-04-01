# FitTracker Design System — Process Retrospective & Current State

**Date:** 2026-04-01
**Figma file:** `0Ai7s3fCFqR5JXDW8JvgmD`
**Branch:** `claude/implement-mcp-server-AVtFa`

---

## What Was Accomplished

### Phase Summary

| Phase | What | Duration | Result |
|---|---|---|---|
| P0 | Code deduplication | Prior work | AppComponents.swift deleted, types consolidated |
| P0.5 | Unified PR #14 + #15 into single branch | ~2h | 131 files merged, 6 cleanup fixes applied |
| P1 | Token pipeline (CI gates) | Prior work | `make tokens-check` + `make lint-ds` in CI |
| P2 | Figma foundations | ~1h | 7 collections (118 vars), 22 text styles, 2 effect styles |
| P3 | Component library | ~30m | 22 component sets (65 variants) |
| P4 | Screen builds | ~3h | 15 screens built via figma-console-mcp Desktop Bridge |
| P5 | QA audits | ~30m | Token binding + accessibility audits passed |
| R1-R6 | Design revisions | ~1h | Auth gradient, home readiness, nutrition UX, training polish, account tokens |

### Code Changes (Total)

| Metric | Count |
|---|---|
| Files modified | 131+ |
| Raw Color literals migrated | ~200+ |
| Raw Font.system(size:) migrated | ~40 |
| AppType.* → AppText.* migrations | ~93 |
| Remaining raw Font.system(size:) | 16 (all responsive ternaries or intentional oversized, documented) |
| Remaining raw Color references | 0 |
| New design system files | 6 (DesignSystem/ directory) |
| New asset catalog colorsets | 53 (Light + Dark mode) |
| New documentation files | 12+ |
| Backend docs updated | Yes (README, migrations, deployment prereqs) |

### Figma Design System (Current State)

| Layer | Count | Status |
|---|---|---|
| Variable collections | 7 | ✅ All synced to code |
| Color / Primitives | 19 variables | ✅ Created fresh |
| Color / Semantic | 46 variables (Light+Dark) | ✅ Consolidated from dual collections |
| Spacing | 9 variables | ✅ Verified (4pt grid) |
| Radius | 9 variables | ✅ Verified |
| Elevation | 6 variables | ✅ Verified |
| Motion | 7 variables | ✅ Names fixed to match code |
| Text / Roles | 22 variables | ✅ Verified |
| Text styles | 22 | ✅ Verified against AppText.* |
| Effect styles | 2 | ✅ Verified against AppShadow.* |
| Component sets | 22 (65 variants) | ✅ Built |
| Screen frames | 15 | ✅ Built via figma-console-mcp |

### Screens Built (Current Figma State)

| # | Screen | Page | Status |
|---|---|---|---|
| 1 | Auth Entry / Register | Login | ✅ Built — blue gradient, dark text |
| 2 | Auth Entry / Login | Login | ✅ Built — blue gradient |
| 3 | Email Login | Login | ✅ Built |
| 4 | Email Registration | Login | ✅ Built |
| 5 | Lock Screen | Login | ✅ Built |
| 6 | Home / Today Summary | Main Screen | ✅ Built — greeting, status, goal, training, metrics |
| 7 | Manual Biometric Entry | Main Screen | ✅ Built — sheet with 5 fields |
| 8 | Training / Active Session | Training | ✅ Built — week strip, exercise cards, RPE indicators |
| 9 | Session Completion | Training | ✅ Built — stats grid sheet |
| 10 | Rest Timer | Training | ✅ Built — floating circle overlay |
| 11 | Nutrition / Meals Logged | Nutrition | ✅ Built — meal slots, no Log Meal button |
| 12 | MealEntry / Manual Tab | Nutrition | ✅ Built — 4-tab sheet |
| 13 | Stats / Weight Chart | Stats | ✅ Built — charts, Track More, chip carousel |
| 14 | Account Panel | Account + Security | ✅ Built — avatar, settings, sign out |
| 15 | Settings / Dashboard | Settings | ✅ Built — 5 category cards |

---

## Design Decisions Made

### 1. Auth Background: Blue Gradient (not dark forest)
The dark forest gradient (`#0A140F → #102419 → #05100A`) was off-brand. Changed to use the same blue gradient as all other screens. `AppGradient.authBackground = screenBackground`.

### 2. Home Screen: Animated Greeting → Readiness
Readiness score is not a standalone card. It replaces the greeting text after 10 seconds via crossfade animation, saving screen real estate. HRV/Sleep/RHR metrics are NOT duplicated in the greeting — they live in the metrics section below.

### 3. Nutrition: No Standalone "Log Meal" Button
Meal slots (Breakfast/Lunch/Dinner/Snacks) ARE the logging entry points. Each slot is tappable → opens MealEntrySheet. "Repeat Last" shortcut kept for recently logged meals. Standalone "Add Meal" button removed.

### 4. Stats: "Track More" with User-Toggleable Metrics
Default visible: Weight, Body Fat. "Track More" section shows user's selected additional metrics in a horizontal chip carousel. Users toggle metrics on/off from Settings > Stats Carousel.

### 5. Color Architecture: Asset Catalog with Light + Dark
All 43 semantic colors use `Color("named")` references → asset catalog colorsets with Light and Dark appearances. This enables dark mode when ready. `AppPalette.swift` remains as the primitive reference but is only used by `AppShadow.cardColor`.

### 6. Component Split: Atomic vs Composite
- `DesignSystem/AppComponents.swift` — 6 atomic/molecule components (chip, filter, sheet, stat row, segment, ring)
- `Views/Shared/AppDesignSystemComponents.swift` — 7 composite components (card, button, menu row, tile, input, label, quiet button)

---

## Architecture: Code ↔ Figma Token Mapping

```
Swift Code                          Figma
─────────────────                   ──────────────────
AppPalette.swift (primitives)  →    Color / Primitives (19 vars)
AppTheme.swift (semantic)      →    Color / Semantic (46 vars, Light+Dark)
AppSpacing.*                   →    Spacing (9 vars)
AppRadius.*                    →    Radius (9 vars)
AppShadow.*                    →    Elevation (6 vars)
AppDuration/Spring/Easing      →    Motion (7 vars)
AppText.*                      →    Text / Roles (22 vars) + Text Styles (22)
AppShadow.card/cta             →    Effect Styles (2)
```

---

## Figma MCP Toolchain (Verified Working)

### For token/style/component sync (official MCP):
```
Remote: https://mcp.figma.com/mcp
Tools: use_figma, get_design_context, get_screenshot, get_variable_defs, get_metadata
Persists: Variables ✅, Styles ✅, Component variants ✅, New frames ❌
```

### For screen building (community MCP):
```
Local: figma-console-mcp via Desktop Bridge WebSocket (port 9223)
Tools: 57+ including figma_create_child, figma_set_fills, figma_set_text, figma_instantiate_component
Persists: Everything ✅
Setup: See docs/design-system/figma-mcp-automation-guide.md
```

### Connection sequence (verified 2026-03-31):
1. `npm install -g figma-console-mcp`
2. `git clone https://github.com/southleft/figma-console-mcp.git ~/figma-console-mcp`
3. Start server: `npx figma-console-mcp`
4. Import plugin manifest from `~/figma-console-mcp/figma-desktop-bridge/manifest.json` (re-import if stale)
5. Run Desktop Bridge plugin in Figma
6. Add to Claude Code: `claude mcp add figma-console npx figma-console-mcp`

---

## Iteration Workflow (For Future Changes)

### To modify a screen design:

1. **Describe the change** in natural language to local Claude Code
2. Claude Code uses figma-console-mcp tools to modify the Figma frame
3. **Screenshot** the result using the official MCP for review
4. **Approve** or request further changes
5. If the change requires code updates, apply them on the branch

### To add a new component:

1. Define the component spec (props, states, tokens)
2. Use official MCP `use_figma` to create the component set in Figma (persists)
3. Write the SwiftUI component in `DesignSystem/AppComponents.swift` or `Shared/AppDesignSystemComponents.swift`
4. Update `tokens.json` if new tokens are needed
5. Run `make tokens-check` to verify sync

### To modify a token:

1. Update the value in `AppTheme.swift` (code is source of truth)
2. Update the corresponding Figma variable via official MCP `use_figma`
3. Update `design-tokens/tokens.json` if it's a pipeline-tracked token
4. Run `make tokens-check` in CI

---

## Known Remaining Work

### Figma Cleanup
- Delete old/duplicate screen frames on Login, Training, Nutrition pages (prior agent builds)
- Organize remaining frames with consistent naming convention

### Missing Screens
- FocusModeView (full-screen training)
- MilestoneModal (streak/PR celebration)
- Onboarding flow (welcome → profile → permissions)

### Prototype Flows
- Wire screens into clickable prototype flows:
  - Auth → Home
  - Tab navigation (Home ↔ Training ↔ Nutrition ↔ Stats)
  - Sheet presentations (MealEntry, BiometricEntry, SessionCompletion)
  - Account → Settings → back

### Code Connect
- Set up Figma Code Connect to map SwiftUI components to Figma Inspect panel
- Creates `.figma.swift` files for each component

---

## Files Created/Modified in This Session

### New documentation:
- `docs/design-system/approval-process.md` — Layered approval gates
- `docs/design-system/p4-screen-build-manual.md` — 15-screen build specs
- `docs/design-system/design-revision-spec.md` — Screen-by-screen review notes
- `docs/design-system/comprehensive-revision-plan.md` — 8-fix execution plan
- `docs/design-system/figma-mcp-automation-guide.md` — MCP setup + troubleshooting
- `docs/design-system/process-retrospective.md` — This file

### Code changes:
- `FitTracker/Services/AppTheme.swift` — Auth gradient fix, deprecated markers, typography docs
- `FitTracker/Views/Auth/AuthHubView.swift` — Full token migration + color fixes
- `FitTracker/Views/Main/MainScreenView.swift` — Animated greeting, token migration
- `FitTracker/Views/Nutrition/NutritionView.swift` — Remove redundant Log Meal button
- `FitTracker/Views/Training/TrainingPlanView.swift` — Font/spacing polish
- `FitTracker/Views/Auth/AccountPanelView.swift` — Full token migration
- `FitTracker/Views/Settings/SettingsView.swift` — AppType → AppText migration
- `FitTracker/Views/Shared/ReadinessCard.swift` — Token migration
- `FitTracker/Views/Shared/*.swift` — All shared components migrated
- `FitTracker/DesignSystem/AppComponents.swift` — Split rationale documented
- `FitTracker.xcodeproj/project.pbxproj` — SignInView + WelcomeView added
- `backend/README.md` — Full rewrite with sync_records, cardio_assets docs

### Branch: `claude/implement-mcp-server-AVtFa`
- 41 commits ahead of main
- All pushed to remote
