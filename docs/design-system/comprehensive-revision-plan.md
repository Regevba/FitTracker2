# FitTracker — Comprehensive Revision Plan

**Date:** 2026-04-01
**Purpose:** All code fixes + Figma screen rebuilds based on screen-by-screen review feedback.

---

## Overview

This plan addresses every issue identified during the design review. Each item has:
- **What's wrong** (current state)
- **What to do** (exact fix)
- **Files affected** (code + Figma)
- **Acceptance criteria** (how to verify it's done)

---

## FIX 1 — Auth Screen Background (CRITICAL)

### What's wrong
The auth flow uses `AppGradient.authBackground` which is a dark forest gradient (`#0A140F → #102419 → #05100A`). This is completely off-brand. Every other screen in the app uses the light blue gradient.

### What to do

**Code changes:**

1. **`AppTheme.swift`** — Change `authBackground` to use the same blue gradient as `screenBackground`:
```swift
// BEFORE:
static let authBackground = LinearGradient(
    colors: [
        AppColor.Background.authTop,    // #0A140F (dark green)
        AppColor.Background.authMiddle, // #102419 (dark green)
        AppColor.Background.authBottom, // #05100A (dark green)
    ], ...
)

// AFTER:
static let authBackground = AppGradient.screenBackground
```

2. **`AuthHubView.swift`** — All text already uses `AppColor.Text.primary` (dark text) which is correct for a light background. No text color changes needed once the gradient is fixed.

3. **`AppPalette.swift`** — Keep `darkForest0/1/2` for now (don't delete — may be useful for future dark-mode-only surfaces) but they're no longer referenced by the auth gradient.

4. **Asset catalog** — Keep `bg-auth-top/middle/bottom` colorsets but they become unused by the auth flow. Can be repurposed later for dark mode.

5. **`LockScreenView`** (in `AuthManager.swift`) — Also uses the dark aesthetic. Update to match the blue gradient.

**Figma changes:**

6. All auth screen frames on the Login page → change background fill from dark to the blue gradient (same as Home/Training/Nutrition/Stats pages).

7. All text in auth screens → verify using `text/primary` (dark text), NOT `text/inverse-*`.

### Files affected
- `FitTracker/Services/AppTheme.swift` (1 line)
- `FitTracker/Views/Auth/AuthHubView.swift` (verify — may need no changes)
- Figma: Login page (all auth screens)

### Acceptance criteria
- Auth entry screen has the same blue gradient as the Home screen
- All text is readable (dark on light)
- Register/Login/Email flows all share the same background
- Brand consistency across all screens

---

## FIX 2 — Account & Security Spacing

### What's wrong
Spacing/padding/alignment inconsistency in the sign-in methods card and other elements.

### What to do
- Review `AccountPanelView.swift` spacing values
- Ensure consistent vertical padding between sign-in method rows
- Align status dots (blue=linked, black=linked, red=not linked), labels, subtitles, and chevrons
- Match the manual spacing adjustments made in Figma

### Files affected
- `FitTracker/Views/Auth/AccountPanelView.swift`
- Figma: Account + Security page

### Acceptance criteria
- Equal vertical spacing between Email, Apple ID, Google rows
- Status dots left-aligned, labels and subtitles aligned to same baseline
- Chevrons right-aligned at consistent position

---

## FIX 3 — Home Screen Redesign

### 3a. Readiness Score → Animated Greeting Overlay

**What's wrong:** Readiness card takes a large vertical block and duplicates HRV/Sleep/RHR data that's already in live metrics below.

**What to do:**

Code change in `MainScreenView.swift`:
- Replace the standalone `ReadinessCard` with an animated overlay on the greeting strip
- State 1 (0–10s): `"Good morning, Regev"` with greeting text
- State 2 (10s+): Crossfade to `"Readiness: 78 — Ready to train"` with color-banded score
- Use `AppMotion` tokens for the transition
- Remove the HRV/Sleep/RHR sub-row from the readiness display — this data is in the metrics section

```swift
// Pseudocode for the animated greeting:
@State private var showReadiness = false

VStack {
    if showReadiness {
        // Readiness score inline: "78 — Ready to train"
        HStack {
            Text("\(readinessScore)")
                .font(AppText.metric)
                .foregroundStyle(readinessColor)
            Text("Readiness — \(readinessLabel)")
                .font(AppText.body)
        }
        .transition(.opacity)
    } else {
        Text("Good morning, \(name)")
            .font(AppText.pageTitle)
            .transition(.opacity)
    }
}
.onAppear {
    withAnimation(AppEasing.standard.delay(10)) {
        showReadiness = true
    }
}
```

### 3b. Stable Element Positioning

**What's wrong:** When user starts a training session from home, UI elements shift positions.

**What to do:**
- Wrap state-dependent sections in fixed-height containers
- "Start Training" button and "Active Session" state occupy the same frame
- Use `frame(minHeight:)` to reserve space regardless of content state

### 3c. Home Screen Element Order (final)

```
1. Greeting strip (animates → readiness after 10s)
2. Goal progress bar (weight/BF target with fill animation)
3. Start Training / Active Session (fixed position, never shifts)
4. Live metrics cards (Weight, BF, HRV, Sleep, Steps)
5. Recovery recommendation (contextual)
```

### Files affected
- `FitTracker/Views/Main/MainScreenView.swift` (major refactor of top section)
- `FitTracker/Views/Shared/ReadinessCard.swift` (simplified — remove metric duplication)
- Figma: Main Screen page (rebuild)

### Acceptance criteria
- Greeting → readiness animation works with 10s delay
- No HRV/Sleep/RHR duplication
- Start Training button never moves regardless of state
- All elements use design system tokens

---

## FIX 4 — Nutrition Screen Redesign

### 4a. Remove "Log a Meal" Button

**What's wrong:** Redundant button — each meal slot already handles logging.

**What to do:**
- Remove the standalone "Log a Meal" / "Log Meal" button from `NutritionView.swift`
- Each meal slot (Breakfast/Lunch/Dinner/Snacks) is tappable:
  - Empty → shows "Tap to log" → opens `MealEntrySheet`
  - Logged → shows meal name + kcal → tappable to edit

### 4b. Meal Logging UX Flow

The MealEntrySheet has 4 tabs (this exists in code already):
1. **Smart** — AI text/photo label parsing
2. **Manual** — Name + calories + protein + carbs + fat + serving weight
3. **Template** — Saved meal templates
4. **Search/Scan** — Food database search + barcode scanner

For barcode/photo: app calculates kcal/protein/carbs/fat based on the portion consumed. This is the core daily logging UX.

### 4c. Nutrition Screen Layout (final)

```
1. Date header with ← Today → navigation
2. Macro progress bar (Protein/Carbs/Fat stacked with calorie total)
3. Meal sections × 4 (Breakfast/Lunch/Dinner/Snacks — each tappable)
4. Supplement stack (Morning/Evening toggles with streak badge)
5. Hydration tracker (optional)
```

### Files affected
- `FitTracker/Views/Nutrition/NutritionView.swift` (remove redundant button)
- Figma: Nutrition page (rebuild)

### Acceptance criteria
- No standalone "Log a Meal" button
- Each meal slot is tappable and opens MealEntrySheet
- Macro bar shows progress with correct token colors
- Supplement AM/PM toggles with streak

---

## FIX 5 — Stats Screen Redesign (Restore Former Design)

### What's wrong
The "Track More" section with user-toggleable metric categories appears to have been downplayed in the Figma design. The code still has it.

### What to do
Restore the former design pattern:

1. **Default visible metrics** (always shown): Weight, Body Fat
2. **"Track More" section** with horizontal chip carousel for additional metrics
3. User toggles metrics on/off from **Settings > Stats Carousel** (already in `UserPreferences.visibleStatsMetrics`)
4. Tapping a chip updates the chart below

### Stats Screen Layout (final)

```
1. Period picker (segmented: W / M / 3M / 6M / Y)
2. Permanent charts: Weight + Body Fat (always visible)
3. "Track More" section title with helper text
4. Metric chip carousel (horizontal scroll — only toggled-on metrics)
5. Selected metric chart (full-width, with tap tooltip)
```

Available toggleable metrics: Lean Mass, Muscle Mass, Body Water, Visceral Fat, Resting HR, VO2 Max, Steps, Active Calories, Zone 2 Minutes, Protein, Calories, Supplement Adherence

### Files affected
- `FitTracker/Views/Stats/StatsView.swift` (verify "Track More" is prominent, not hidden)
- Figma: Stats page (rebuild with Track More section visible)

### Acceptance criteria
- Weight and Body Fat charts always visible at top
- "Track More" section clearly visible with descriptive text
- Chip carousel shows user's selected metrics
- Settings link to toggle metrics on/off

---

## FIX 6 — Training Screen Polish

### What's wrong
Foundation is solid but needs refinement.

### What to do
1. Exercise card spacing — consistent padding using `AppSpacing.small`
2. Set/rep/weight display — use `AppText.monoLabel` for data, `AppText.body` for exercise names
3. RPE tap bar — 5 segments [6 7 8 9 10], consistent sizing, selected = orange
4. Rest timer — floating bottom-right, safe-area aware, `AppText.metricDisplayMono` for countdown
5. Session completion sheet — stats grid (Volume/Exercises/Duration/PRs) with proper token bindings
6. Focus mode — full-screen, raw `Color.white.opacity` intentionally kept (non-adaptive black bg)

### Files affected
- `FitTracker/Views/Training/TrainingPlanView.swift` (spacing/font adjustments)
- Figma: Training page (polish)

### Acceptance criteria
- Consistent spacing between exercise cards
- Mono fonts for numeric data
- Rest timer positioned correctly
- Completion sheet stats are readable and well-formatted

---

## FIX 7 — Figma Cleanup (All Pages)

### What's wrong
Multiple overlapping screen generations from 3+ agent passes cluttering every page.

### What to do
On each product page (Login, Main Screen, Training, Nutrition, Stats, Settings, Account+Security):
1. **Identify** the latest/best screen frame per state
2. **Delete** all older duplicate frames
3. **Rename** remaining frames with convention: `ScreenName / State`
4. **Organize** frames left-to-right by flow order with 40px spacing

### Acceptance criteria
- Each page has only the approved screen frames
- No duplicate or overlapping frames
- Clean, navigable layout

---

## FIX 8 — Screens Still Needed

| Screen | Page | Priority |
|--------|------|----------|
| MealEntrySheet (4 tabs) | Nutrition | High |
| ManualBiometricEntry | Main Screen | High |
| SessionCompletionSheet | Training | Medium |
| FocusModeView | Training | Medium |
| LockScreenView | Login | Medium |
| MilestoneModal | Main Screen | Low |
| Onboarding flow | Onboarding | Low |

---

## Execution Order

| Phase | Fixes | Scope |
|---|---|---|
| **R1** | Fix 1 (auth bg) + Fix 7 (cleanup) | Code: 1 line. Figma: page cleanup |
| **R2** | Fix 3 (home redesign) + Fix 4 (nutrition) | Code: MainScreenView + NutritionView refactor |
| **R3** | Fix 5 (stats restore) + Fix 6 (training polish) | Code: StatsView + TrainingPlanView |
| **R4** | Fix 2 (account spacing) + Fix 8 (missing screens) | Code: AccountPanelView. Figma: new screens |
| **R5** | Figma screen rebuild (all pages via figma-console-mcp) | Figma only |
| **R6** | Final QA — screenshot comparison, token audit | Verification |

---

## Code Changes Summary

| File | Fix # | Change |
|------|-------|--------|
| `AppTheme.swift` | 1 | `authBackground = screenBackground` |
| `AuthHubView.swift` | 1 | Verify text colors work on light bg (should already work) |
| `MainScreenView.swift` | 3 | Animated greeting→readiness, remove card duplication, stable positioning |
| `ReadinessCard.swift` | 3 | Remove HRV/Sleep/RHR sub-row |
| `NutritionView.swift` | 4 | Remove standalone "Log Meal" button |
| `StatsView.swift` | 5 | Verify "Track More" is prominent |
| `TrainingPlanView.swift` | 6 | Spacing/font polish |
| `AccountPanelView.swift` | 2 | Spacing alignment fix |
