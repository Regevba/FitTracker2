# Figma Coverage Guide — FitTracker Design System v2
**Date:** 2026-03-30
**Figma file:** [FitTracker Design System Library](https://www.figma.com/design/0Ai7s3fCFqR5JXDW8JvgmD/FitTracker-Design-System-Library)
**Swift source of truth:** `AppTheme.swift`, `AppPalette.swift`, `design-tokens/tokens.json`

---

## Goal: Intent-Perfect Coverage

"Pixel-perfect" for iOS means **intent-perfect**: every visual property in Swift code is driven by a token that maps 1:1 to a Figma Variable. A Figma change propagates to Swift via the token pipeline without ambiguity.

---

## Token Pipeline Setup

### Step 1: Install Tokens Studio plugin in Figma
1. Open the FitTracker Design System Library file
2. Plugins → Search "Tokens Studio for Figma" → Install
3. Connect to the repository: GitHub → `Regevba/FitTracker2` → branch `feat/design-system-v2` → path `design-tokens/tokens.json`

### Step 2: Export after a Figma Variable change
1. Update Figma Variable value
2. Tokens Studio → Export → Overwrite `design-tokens/tokens.json`
3. Run `make tokens` → regenerates `FitTracker/DesignSystem/DesignTokens.swift`
4. Commit both files together: `git add design-tokens/tokens.json FitTracker/DesignSystem/DesignTokens.swift`

### Step 3: CI validates sync
CI runs `make tokens-check` before every build — fails PR if drift detected.

---

## Figma Variables Required

Create the following Variable collections in the FitTracker Design System Library file:

### Collection 1: Color/Primitives (maps to AppPalette.swift)
| Variable | Value | Swift |
|---|---|---|
| orange/50 | #FFE3BA | `AppPalette.orange50` |
| orange/100 | #FFC78A | `AppPalette.orange100` |
| orange/500 | #FA8F40 | `AppPalette.orange500` |
| blue/50 | #DFF3FF | `AppPalette.blue50` |
| blue/100 | #F0FAFF | `AppPalette.blue100` |
| blue/200 | #BAE3FF | `AppPalette.blue200` |
| blue/500 | #8AC7FF | `AppPalette.blue500` |
| status/green | #34C759 | `AppPalette.green` |
| status/amber | #FF9500 | `AppPalette.amber` |
| status/red | #FF3B30 | `AppPalette.red` |
| accent/cyan | #5AC8FA | `AppPalette.cyan` |
| accent/purple | #BF5AF2 | `AppPalette.purple` |
| accent/gold | #FFD60A | `AppPalette.gold` |

### Collection 2: Color/Semantic (maps to AppColor in AppTheme.swift)
All semantic tokens reference Collection 1 primitives — no raw hex values.

| Variable | Value | WCAG |
|---|---|---|
| text/primary | `rgba(0,0,0,0.84)` | 9.2:1 ✅ AAA |
| text/secondary | `rgba(0,0,0,0.62)` | 5.4:1 ✅ AA |
| text/tertiary | `rgba(0,0,0,0.55)` | 4.6:1 ✅ AA |
| text/inverse-primary | `rgba(255,255,255,0.94)` | on dark |
| text/inverse-secondary | `rgba(255,255,255,0.76)` | on dark |
| text/inverse-tertiary | `rgba(255,255,255,0.54)` | on dark |

### Collection 3: Spacing (maps to AppSpacing — strict 4pt grid)
| Variable | Value |
|---|---|
| spacing/xxx-small | 4 |
| spacing/xx-small | 8 |
| spacing/x-small | 12 |
| spacing/small | 16 |
| spacing/medium | 20 |
| spacing/large | 24 |
| spacing/x-large | 32 |
| spacing/xx-large | 40 |

### Collection 4: Radius (maps to AppRadius)
| Variable | Value | Note |
|---|---|---|
| radius/x-small | 8 | |
| radius/small | 12 | |
| radius/medium | 16 | Buttons, inputs |
| radius/large | 24 | Cards |
| radius/x-large | 28 | Intentionally ≠ sheet |
| radius/sheet | 32 | Bottom sheets |
| radius/auth-sheet | 36 | Auth bottom sheets |

---

## Required Figma Pages

### Page: Components
One frame per component, all states side-by-side:

| Component | States needed |
|---|---|
| AppButton | default, pressed, disabled, loading |
| AppCard | compact, default, spacious density |
| AppMenuRow | default, with icon, with badge, with chevron |
| AppSectionHeader | default, with accessory |
| AppPickerChip | selected, unselected, disabled |
| AppFilterBar | single selection, with scroll overflow |
| AppSheetShell | default, with dismiss, destructive action |
| AppStatRow | with icon, without icon, with custom value color |
| AppSegmentedControl | 2/3/4 options, animated selection |
| AppProgressRing | 0%, 50%, 100%, with label |
| MetricCard | loading, with value, with trend |
| ChartCard | empty state, with line chart, with bar chart |
| ReadinessCard | low/medium/high readiness |
| StatusBadge | all status types |
| TrendIndicator | up/down/flat |

Each frame:
- Light mode (default)
- Dark mode variant (once dark mode is implemented in B8)
- Token annotations on every colour/spacing/radius property

### Page: Screens
One frame per major screen at iPhone 16 Pro (393pt) width:

| Screen | States |
|---|---|
| AuthHubView | login mode, register mode |
| EmailVerificationView | waiting for code |
| MainScreenView | today summary, active training, rest day |
| TrainingPlanView | scheduled, active session, completion sheet |
| NutritionView | empty, with meals logged, with macros |
| StatsView | all chart tabs |
| SettingsView | all 7 sections |
| AccountPanelView | signed in, sync status |

### Page: Typography Repository
All 20 AppText roles with:
- Sample text at default Dynamic Type
- Sample text at xxxLarge Dynamic Type
- Font name, style, size, line height
- AppText enum name annotation

### Page: Color Repository
All AppColor tokens with:
- Light mode swatch
- Dark mode swatch (placeholder until B8)
- Hex value
- Contrast ratio against white background
- WCAG AA/AAA pass/fail badge

### Page: Spacing & Radius
Visual scale reference:
- 8 boxes showing AppSpacing.xxxSmall → xxLarge with pixel dimensions
- 7 rounded rects showing AppRadius.xSmall → authSheet

### Page: Icon Repository
All SF Symbols in AppIcon enum:
- Symbol name
- AppIcon.* enum key
- Rendered at 3 sizes (16pt, 24pt, 32pt)
- Recommended rendering mode (.hierarchical for depth symbols)

---

## Code Connect Setup

Code Connect links Swift component API to Figma Inspect panel.

### Installation
```bash
npm install --save-dev @figma/code-connect@1
```

### Example mapping (AppButton)
Create `FitTracker/DesignSystem/AppButton.figma.swift`:
```swift
import Figma

struct AppButtonCodeConnect: FigmaConnect {
    let component = URL(string: "https://www.figma.com/design/0Ai7s3fCFqR5JXDW8JvgmD?node-id=COMPONENT_NODE_ID")!

    @FigmaProp("Label") var label: String = "Button"
    @FigmaProp("Style") var style: String = "Primary"

    var body: some View {
        AppButton(label, style: style == "Primary" ? .primary : .secondary) { }
    }
}
```

### Publish mappings
```bash
npx figma connect publish
```

---

## Prototype Flows Required

### Flow 1: Auth
Welcome → AuthHubView (login) → Email verification → MainScreenView

### Flow 2: Main tab navigation
HomeScreen → Training tab → Nutrition tab → Stats tab → Settings

### Flow 3: Meal logging
NutritionView → MealEntrySheet (manual) → save → NutritionView updated

### Flow 4: Training session
TrainingPlanView (scheduled) → session type selection → active session → completion sheet

---

## Figma MCP Integration

The Figma MCP server is configured in `.mcp.json` at the repo root:
```json
{
  "mcpServers": {
    "figma": {
      "type": "http",
      "url": "https://mcp.figma.com/mcp"
    }
  }
}
```

Use `get_design_context` in Claude Code sessions to inspect any Figma node and compare against Swift implementation. Available tools:
- `get_design_context` — primary tool, returns code + screenshot + token annotations
- `get_metadata` — structure overview (node IDs, positions)
- `get_screenshot` — visual snapshot
- `get_variable_defs` — all Figma Variables in the file
- `search_design_system` — search for components by name

---

## Drift Detection Checklist

Run before every design system release:

- [ ] `make tokens-check` passes (DesignTokens.swift matches tokens.json)
- [ ] All AppSpacing values are multiples of 4 (CI test: `testSpacingScaleIsStrictly4ptGrid`)
- [ ] Text.tertiary opacity ≥ 0.55 (CI test: `testTextTertiaryOpacityMeetsWCAGAA`)
- [ ] Sheet corner radii: standard=32, auth=36 (CI test: `testSheetCornerRadiusMatchesSpec`)
- [ ] No `.font(.system(size:))` literals in view files (grep: `font(.system(size:)`)
- [ ] No raw `Color(red:green:blue:)` in view files (only allowed in AppPalette.swift)
- [ ] No raw `padding(N)` where N is not a multiple of 4 and not a special-case value
- [ ] Every new component has accessibilityLabel support
- [ ] Every animation site uses AppMotion/AppSpring/AppEasing or AppDuration constants
