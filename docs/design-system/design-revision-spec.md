# Design Revision Spec — Screen-by-Screen

**Date:** 2026-03-31
**Figma file:** `0Ai7s3fCFqR5JXDW8JvgmD`

---

## Screen Approval Status

| # | Screen | Status | Notes |
|---|--------|--------|-------|
| 1 | Settings Dashboard | ✅ Approved | — |
| 2 | Account & Security | ✅ Approved | Fix spacing/padding/alignment per screenshot feedback |
| 3 | Login / Auth | 🔄 Polish needed | Use prototype version as basis — maintain brand tone |
| 4 | Home / Main Screen | 🔄 Redesign needed | See detailed notes below |
| 5 | Nutrition | 🔄 Redesign needed | See detailed notes below |
| 6 | Stats | 🔄 Redesign needed | Restore former design with Track More toggle |
| 7 | Training | 🔄 Polish needed | Solid foundation, needs refinement |

---

## 1. Settings Dashboard — ✅ APPROVED

No changes needed.

---

## 2. Account & Security — ✅ APPROVED (with fix)

**Issue:** Spacing/padding/alignment inconsistency in the sign-in methods card.

**Fix needed:**
- Ensure consistent vertical padding between rows (Email, Apple ID, Google)
- Align status dots, labels, and chevrons to a consistent grid
- Match the spacing adjustments the user made manually in Figma

---

## 3. Login / Auth Screen — 🔄 POLISH

**Direction:** Use the existing prototype screen as the design basis. The dark forest gradient background with the floating-control layout is correct.

**What to keep:**
- Dark forest gradient background (`authBackground`)
- Brand tone and visual weight
- Register / Log In primary flow
- Biometric quick-return and passkey actions
- Apple sign-in, Google sign-in, email sign-in method selection

**What to polish:**
- Text color contrast on dark background — verify all text uses `text/inverse-*` tokens
- Button hierarchy clarity — primary (Register) vs secondary (Log In) vs tertiary (biometric/passkey)
- Trust badges positioning (bottom-anchored)
- Sub-screens: email registration, OTP verification, email login — all should match the parent auth tone

**Code reference:** `AuthHubView.swift` — `AuthEntryScreen`, `AuthMethodSelectionView`, `EmailRegistrationView`, `EmailVerificationView`, `EmailLoginView`

---

## 4. Home / Main Screen — 🔄 REDESIGN

### 4.1 Readiness Score → Animated Strip Overlay

**Current:** Readiness score is a large standalone card taking significant vertical space, with HRV/Sleep/RHR metrics duplicated from the live metrics section.

**New design:** The readiness score should be an **animated overlay that replaces the greeting strip** after ~10 seconds:

```
State 1 (0-10s):  "Good morning, Regev"     [greeting]
State 2 (10s+):   "Readiness: 78 — Ready"   [score with color band]
```

This saves screen real estate while keeping the readiness information prominent. The transition should be a smooth crossfade using `AppMotion` tokens.

**Remove:** The standalone HRV/Sleep/RHR row from the readiness card — that data already exists in the live metrics section below.

### 4.2 Stable Element Positioning

**Requirement:** All elements must maintain their position regardless of state changes. When the user starts a training session from the home screen (press play), the active training box must NOT shift or displace other elements.

**Implementation:** Use fixed-height containers for state-dependent sections. An "idle" state and "active training" state should occupy the same frame height.

### 4.3 Core Home Elements (in order, top to bottom)

1. **Greeting strip** (animates to readiness score after 10s)
2. **Goal progress bar** (weight/BF target)
3. **Start Training button** (fixed position, changes to "Active Session" during training)
4. **Live metrics cards** (Weight, BF, HRV, Sleep, Steps — from HealthKit)
5. **Recovery recommendation** (contextual, based on readiness)

---

## 5. Nutrition — 🔄 REDESIGN

### 5.1 Remove "Log a Meal" Button

**Rationale:** The log-a-meal functionality already exists within each meal slot (Breakfast, Lunch, Dinner, Snacks). A separate button is redundant.

**New flow:** Each meal slot is tappable:
- Empty state: "Tap to log" → opens MealEntrySheet
- Logged state: Shows meal name + kcal, tappable to edit

### 5.2 Meal Logging UX

The core logging flow should emphasize the **daily course of eating**:
1. User taps a meal slot (e.g., "Lunch")
2. MealEntrySheet opens with 4 tabs:
   - **Smart:** AI label parsing from text/photo
   - **Manual:** Name + macros entry
   - **Template:** Saved meals
   - **Search/Scan:** Food database search + barcode scanner
3. For barcode/photo: app calculates kcal/protein/carbs/fat based on portion consumed

### 5.3 Screen Layout (top to bottom)

1. **Date header** with navigation arrows (← Today →)
2. **Macro progress bar** (protein/carbs/fat stacked, with calorie total)
3. **Meal sections** × 4 (Breakfast/Lunch/Dinner/Snacks) — each tappable to log
4. **Supplement stack** (Morning/Evening toggles with streak)
5. **Hydration tracker** (optional)

---

## 6. Stats — 🔄 REDESIGN (Restore Former Design)

### 6.1 Restore "Track More" Toggle Functionality

**What disappeared:** The former design had a curated default set of visible metrics, with a "Track More" row at the bottom that let users toggle additional metric categories on/off from Settings.

**Restore:**
- Default visible metrics: Weight, Body Fat, HRV, Sleep, Training Volume
- "Track More" row at the bottom → links to Settings > Stats Carousel metric picker
- User can toggle on/off: Lean Mass, Muscle Mass, Body Water, Visceral Fat, Resting HR, VO2 Max, Steps, Active Calories, Zone 2 Minutes, Protein, Supplement Adherence

### 6.2 Screen Layout

1. **Period picker** (segmented: W / M / 3M / 6M / Y)
2. **Permanent charts:** Weight + Body Fat (always visible, side by side or stacked)
3. **Selected metric chart** (larger, with tooltip on tap)
4. **Metric chip carousel** (horizontal scroll, only showing toggled-on metrics)
5. **"Track More"** row → Settings deep link

**Code reference:** `StatsView.swift` — `StatsFocusMetric` enum, `UserPreferences.visibleStatsMetrics`

---

## 7. Training — 🔄 POLISH

**Foundation is solid.** Polish areas:
- Exercise card spacing and alignment
- Set/rep/weight display using mono font (`text/mono-label`)
- RPE tap bar visual weight
- Rest timer floating overlay positioning (bottom-right, safe-area aware)
- Session completion sheet stats grid formatting
- Focus mode view (full-screen, distraction-free)

---

## 8. Other Screens Not Yet Reviewed

| Screen | Status | Notes |
|--------|--------|-------|
| MealEntrySheet (4 tabs) | Needs build | Smart/Manual/Template/Search tabs with barcode scanner |
| ManualBiometricEntry | Needs build | Weight, BF, HR, HRV, Sleep fields |
| SessionCompletionSheet | Needs polish | Stats grid: volume, exercises, duration, PRs |
| FocusModeView | Needs build | Full-screen exercise focus, raw Color.white intentional |
| LockScreenView | Needs build | Biometric unlock prompt |
| RootTabView (tab bar) | Needs verification | 4-tab layout with active/inactive states |
| Onboarding flow | Not started | Welcome, profile setup, permissions |
| MilestoneModal | Needs build | Streak/PR celebration overlay |

---

## Figma Cleanup Required

Before further design work, clean up all pages:
- **Delete** duplicate/overlapping screen frames from prior agent passes
- **Keep** only the latest approved version per screen
- **Organize** remaining frames with consistent naming: `ScreenName / State`
