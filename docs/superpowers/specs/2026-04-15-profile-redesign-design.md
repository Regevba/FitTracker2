# Profile Redesign — Design Spec

> **Date:** 2026-04-15
> **Approach:** Hybrid C — hero cards at top + collapsed summary cards below
> **Goal:** Simplify aggressively. Cut duplication with Home. Merge Settings inline.

---

## Navigation Change

Profile is no longer a tab. It is accessed via the hamburger menu (top-left `line.3.horizontal` button) on every screen. The tab bar has 4 tabs: Home, Training Plan, Nutrition, Stats. Profile opens as a `.sheet(detents: [.large])`.

## Profile View Structure

A single ScrollView with these sections top-to-bottom:

### 1. Hero Section

Avatar circle (initials, gradient background), name, inline personal details, goal badge, program phase.

| Field | Source | Editable? |
|---|---|---|
| Avatar (initials) | `signIn.currentSession?.initials` | No (tap fires analytics only) |
| Display name | `userProfile.displayName ?? signIn.activeSession?.displayName` | Via Goals & Training card |
| Age, Height | `userProfile.age`, `userProfile.height` | Via Goals & Training card |
| Experience Level | `userProfile.experienceLevel` | Via Goals & Training card |
| Fitness Goal badge | `userProfile.fitnessGoal` | Tap → GoalEditorSheet |
| Program Phase + Day | `userProfile.currentPhase`, `userProfile.daysSinceStart` | Display only |

**Cut from hero:** email (moved to Account card), stat row (day count, streak, workout count — clutter).

### 2. Goals & Training Card (collapsed summary, tap to expand)

Summary line: `"{fitnessGoal} · {targetWeight} · {trainingDays} days/week"`

Tap opens `GoalEditorSheet` as a `.sheet` (reuse existing view, extended with nutrition mode + advanced section):

| Field | Type | Source |
|---|---|---|
| Fitness Goal | Picker (4 options) | `userProfile.fitnessGoal` |
| Target Weight | Range (min/max) | `userProfile.targetWeightMin/Max` |
| Target Body Fat | Range (min/max) | `userProfile.targetBFMin/Max` |
| Training Days / week | Stepper (2-7) | `userProfile.trainingDaysPerWeek` |
| Experience Level | Picker (3 options) | `userProfile.experienceLevel` |
| Nutrition Mode | Segmented (Fat Loss/Maintain/Lean Gain) | `settings.nutritionMode` |
| **Advanced** (disclosure) | | |
| Zone 2 HR Lower | Slider | `settings.zone2LowerHR` |
| Zone 2 HR Upper | Slider | `settings.zone2UpperHR` |
| Readiness HR Threshold | Slider | `settings.readinessHRThreshold` |
| Readiness HRV Threshold | Slider | `settings.readinessHRVThreshold` |

**Cut:** Meal slots (dropped), program name (display-only in hero).

### 3. Account & Data Card (collapsed summary, tap to expand)

Summary line: `"{signInMethod} · {biometricLock ? 'Face ID' : 'No lock'} · {syncStatus}"`

Tap pushes to `AccountDataDetailView` (new view, within Profile's NavigationStack):

| Field | Type | Source |
|---|---|---|
| Sign-in Method | Display | `signIn.currentSession?.provider` |
| Email | Display | `signIn.currentSession?.email` |
| Biometric Lock | Toggle | `settings.requireBiometric` |
| Connected Devices | NavigationLink → sub-screen | HealthKit, Watch, scale status |
| iCloud Sync | Display + Sync Now button | `cloudSync.status` |
| Export My Data | Button → JSON export | `ExportDataView` |
| Analytics Consent | Toggle | `consentManager.analyticsConsented` |
| Delete Account | Destructive button | `DeleteAccountView` |

**Cut:** Encryption details (nice-to-have), passkey management (advanced/rare).

### 4. Appearance & Units Row (single line, no expansion)

Displays: `"System · Metric"` with chevron. Taps to a picker sheet with:
- Theme: System / Light / Dark
- Units: Metric / Imperial

### 5. Sign Out Button

Red destructive text, centered. Tap → confirmation alert → `signIn.signOut()`.

### 6. About Footer (minimal)

- Version + build number (small text)
- Terms of Use · Privacy Policy · Contact Support (underlined links)

---

## What Was Cut

| Item | Reason |
|---|---|
| Readiness snapshot | Duplicate of Home ReadinessCard |
| Body composition card | Duplicate of Home BodyCompositionCard |
| AI insight card | Duplicate of Home AIInsightCard |
| Email in hero | Moved to Account & Data card |
| Stat row (day/streak/workouts) | Clutter |
| Meal slots | Not useful enough to surface |
| Notifications section | Deferred to Smart Reminders feature (separate PM cycle) |
| Encryption details | Nice-to-have, not needed in summary |
| Passkey management | Advanced, rare use |
| Personal Details section | Merged into Hero |
| Connected Devices section | Moved to sub-screen inside Account & Data |
| Separate Settings sheet | Settings content is now inline in Profile |

## Deferred Items

- **Notifications toggles** → add as sub-task when Smart Reminders ships (FIT-42)
- **Connected Devices detail screen** → reuse existing HealthKit/Watch status from Settings v2

## Design System Tokens

All views use existing AppColor, AppText, AppSpacing, AppRadius, AppShadow tokens. No new tokens needed. Cards use `AppColor.Surface.primary` + `AppRadius.card` + `AppShadow.card*`.

### Section Color Palette

Each collapsed card uses a distinct accent color for its icon and left-border/indicator, matching the existing Settings v2 category tints:

| Section | Icon | Accent Color Token |
| --- | --- | --- |
| Goals & Training | `target` (🎯) | `AppColor.Accent.achievement` (orange/gold) |
| Account & Data | `lock.shield.fill` | `AppColor.Accent.primary` (brand orange) |
| Appearance & Units | `paintpalette.fill` | `AppColor.Accent.sleep` (purple) |

This reuses the same differentiation strategy from Settings v2 (`SettingsCategory.tint`) so the color language is consistent when users drill into detail screens.

## Analytics Events

Existing `profile_*` events remain. No new events needed for this restructure — the same actions (goal edit, settings open, sign out) fire the same events.

## Files Changed

| File | Action |
|---|---|
| `FitTracker/Views/Profile/ProfileView.swift` | Rewrite — new structure |
| `FitTracker/Views/Profile/ProfileHeroSection.swift` | Update — add age/height/experience, remove email/stat row |
| `FitTracker/Views/Profile/ProfileBodyCompCard.swift` | Remove from Profile (stays for Home use) |
| `FitTracker/Views/Profile/GoalEditorSheet.swift` | Keep — reused for Goals & Training detail |
| `FitTracker/Views/Profile/GoalsTrainingCard.swift` | New — collapsed summary + tap to expand |
| `FitTracker/Views/Profile/AccountDataCard.swift` | New — collapsed summary + tap to expand |
| `FitTracker/Views/Profile/AppearanceUnitsRow.swift` | New — single row picker |
| `FitTracker/Views/RootTabView.swift` | Already done — 4 tabs, hamburger → ProfileView |
| `FitTrackerTests/EvalTests/ProfileEvals.swift` | Already updated — 4 tabs test |
