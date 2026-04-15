# Prototype V2 — Setup Guide

> **Figma file:** `0Ai7s3fCFqR5JXDW8JvgmD`
> **Page:** Prototype V2 (2026-04-15)
> **Screens:** 22
> **Connections:** ~35
> **Last updated:** 2026-04-15

---

## Screen Inventory

### Row 1 — Onboarding Flow (9 screens, linear progression)

| # | Screen | Node ID | Size |
|---|---|---|---|
| 1 | Welcome | `870:2` | 393×852 |
| 2 | Goals | `870:29` | 393×852 |
| 3 | Profile | `870:62` | 393×852 |
| 4 | HealthKit (idle) | `870:100` | 393×852 |
| 4a | HealthKit (loading) | `870:130` | 393×852 |
| 4b | HealthKit (denied) | `870:161` | 393×852 |
| 4c | HealthKit (iPad) | `870:194` | 393×852 |
| 5 | Consent | `870:227` | 393×852 |
| 6 | First Action | `870:254` | 393×852 |

### Row 2 — Main App Tabs (4 screens, tab switching)

| # | Screen | Node ID | Size |
|---|---|---|---|
| 1 | Home v3 | `871:27` | 393×852 |
| 2 | Training v2 (Rest Day) | `871:129` | 393×852 |
| 3 | Nutrition v2 | `871:202` | 393×825 |
| 4 | Stats v2 | `871:291` | 393×722 |

### Row 3 — Profile Flow (4 screens, sheet presentations)

| # | Screen | Node ID | Size |
|---|---|---|---|
| 1 | Profile | `872:2` | 393×820 |
| 2 | GoalEditorSheet | `872:44` | 393×852 |
| 3 | Settings dashboard | `872:103` | 393×700 |
| 4 | AppearanceUnitsSheet | `872:138` | 393×380 |

### Row 4 — Settings Detail Screens (5 screens, push navigation)

| # | Screen | Node ID | Size |
|---|---|---|---|
| 1 | Account & Security | `872:160` | 280×500 |
| 2 | Health & Devices | `872:189` | 280×500 |
| 3 | Goals & Preferences | `872:210` | 280×500 |
| 4 | Training & Nutrition | `872:247` | 280×500 |
| 5 | Data & Sync | `872:268` | 280×500 |

---

## Connection Map

### Onboarding Flow

All transitions use **Push Right** (forward) and **Push Left** (back).

| From | Trigger | → To | Transition |
|---|---|---|---|
| Welcome | Tap "Get Started" | → Goals | Push right |
| Goals | Tap "Continue" | → Profile | Push right |
| Goals | Tap "Skip" | → Profile | Push right |
| Goals | Tap "‹" back | → Welcome | Push left |
| Profile | Tap "Continue" | → HealthKit (idle) | Push right |
| Profile | Tap "‹" back | → Goals | Push left |
| HealthKit (idle) | Tap "Connect Apple Health" | → HealthKit (loading) | Overlay |
| HealthKit (idle) | Tap "Skip for now" | → Consent | Push right |
| HealthKit (idle) | Tap "‹" back | → Profile | Push left |
| HealthKit (loading) | After delay (auto) | → Consent | Push right |
| HealthKit (denied) | Tap "Continue without" | → Consent | Push right |
| HealthKit (denied) | Tap "Open Settings" | → (external) | — |
| Consent | Tap "Accept & Continue" | → First Action | Push right |
| Consent | Tap "Continue without" | → First Action | Push right |
| Consent | Tap "‹" back | → HealthKit (idle) | Push left |
| First Action | Tap "Start Your First Workout" | → Home v3 | Replace (enter app) |
| First Action | Tap "Log Your First Meal" | → Home v3 | Replace (enter app) |

### Tab Navigation

All transitions use **Instant** (no animation).

| Trigger | → To |
|---|---|
| Tap Home icon (any tab bar) | → Home v3 |
| Tap Training icon | → Training v2 |
| Tap Nutrition icon | → Nutrition v2 |
| Tap Stats icon | → Stats v2 |

### Profile Flow

Profile opens as **Overlay / Sheet** (slide up from bottom).

| From | Trigger | → To | Transition |
|---|---|---|---|
| Any tab screen | Tap profile icon (top-left) | → Profile | Open overlay |
| Profile | Tap ✕ close button | → (dismiss) | Close overlay |
| Profile | Swipe down | → (dismiss) | Close overlay |
| Profile | Tap "Goals & Training" card | → GoalEditorSheet | Open overlay |
| Profile | Tap "Account & Data" card | → Settings | Open overlay |
| Profile | Tap "Appearance & Units" row | → AppearanceUnitsSheet | Open overlay |
| Profile | Tap "Sign Out" | → (alert) | Overlay (confirm dialog) |
| GoalEditorSheet | Tap "Cancel" | → Profile | Close overlay |
| GoalEditorSheet | Tap "Save" | → Profile | Close overlay |
| GoalEditorSheet | Swipe down | → Profile | Close overlay |
| Settings | Swipe down | → Profile | Close overlay |
| AppearanceUnitsSheet | Tap "Done" | → Profile | Close overlay |
| AppearanceUnitsSheet | Swipe down | → Profile | Close overlay |

### Settings Detail Navigation

All transitions use **Push Right** (forward) and **Push Left** (back). These happen inside the Settings sheet's NavigationStack.

| From | Trigger | → To | Transition |
|---|---|---|---|
| Settings | Tap "Account & Security" card | → Account & Security detail | Push right |
| Settings | Tap "Health & Devices" card | → Health & Devices detail | Push right |
| Settings | Tap "Goals & Preferences" card | → Goals & Preferences detail | Push right |
| Settings | Tap "Training & Nutrition" card | → Training & Nutrition detail | Push right |
| Settings | Tap "Data & Sync" card | → Data & Sync detail | Push right |
| Any detail screen | Tap "‹" back | → Settings dashboard | Push left |
| Any detail screen | Swipe from left edge | → Settings dashboard | Push left |

---

## Universal Back Behavior

These behaviors are system-provided in SwiftUI and should be mirrored in the prototype:

| Context | Gesture | Behavior |
|---|---|---|
| Sheet / Overlay | Swipe down | Dismiss to caller |
| Pushed screen | Swipe from left edge | Pop to previous screen |
| Pushed screen | Tap "‹" back button | Pop to previous screen |
| Tab bar | Tap current tab icon | Scroll to top (no navigation) |

---

## How to Wire in Figma

1. Open the **Prototype V2 (2026-04-15)** page in Figma
2. Switch to **Prototype** mode (top-right toggle)
3. For each connection in the tables above:
   - Select the trigger element (button, card, icon)
   - Drag the blue connection handle to the target frame
   - Set the interaction type:
     - **On Tap** for all button/card taps
     - **Navigate to** for push transitions
     - **Open overlay** for sheet presentations
     - **Close overlay** for dismiss actions
   - Set the animation:
     - **Push right/left** = Smart animate, 300ms, ease out
     - **Sheet slide up** = Move in, bottom, 350ms, ease out
     - **Close sheet** = Move out, bottom, 300ms, ease in
     - **Tab switch** = Instant (0ms)
     - **Replace** = Dissolve, 200ms

4. Set the **starting frame** to Welcome (`870:2`) for the full onboarding flow, or Home v3 (`871:27`) for the in-app flow.

---

## Transition Specs (for code reference)

| Transition | iOS SwiftUI Equivalent | Duration | Curve |
|---|---|---|---|
| Push right | `NavigationStack` push | ~350ms | `.easeInOut` |
| Push left (back) | System back navigation | ~350ms | `.easeInOut` |
| Sheet slide up | `.sheet(isPresented:)` | ~350ms | `.spring(response: 0.35)` |
| Sheet dismiss | Swipe down / `dismiss()` | ~300ms | `.easeIn` |
| Tab switch | `TabView(selection:)` | Instant | — |
| Overlay (alert) | `.alert(isPresented:)` | ~200ms | `.easeOut` |
