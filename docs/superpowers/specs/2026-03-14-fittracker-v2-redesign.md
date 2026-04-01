# FitTracker v2.0 — Full Redesign Spec

**Date:** 2026-03-14
**Goal:** Polish for daily personal use. No App Store scope — focus on making every daily workflow faster, clearer, and more satisfying.
**Approach:** Design system first, then features. 5 sequential passes.

---

## Design System Gate

Effective from 2026-03-27, any new feature or redesign work should reference the active design-system artifacts before implementation:

- `docs/design-system/feature-design-checklist.md`
- `docs/design-system/design-system-governance.md`
- `docs/design-system/component-contracts.md`
- `docs/design-system/design-tokens.json`
- `docs/design-system/responsive-handoff-rules.md`
- `docs/design-system/feature-development-gateway.md`
- `docs/design-system/feature-memory.md`
- `docs/superpowers/templates/feature-spec-template.md`
- `docs/superpowers/templates/wireframe-brief-template.md`
- `FitTracker/Views/Settings/DesignSystemCatalogView.swift`

No new feature spec is complete unless it identifies:

- the problem and purpose
- how the feature should behave
- wireframes before final UI
- primary platform and adaptation scope
- reused components and semantic tokens
- required default, loading, empty, error, success, and disabled states
- accessibility notes
- motion or haptic notes
- whether it extends an existing primitive or introduces a governed new one

---

## Context

FitTracker is a personal iOS/iPadOS/macOS fitness app (SwiftUI, iOS 17+) tracking body composition, training, nutrition, and recovery. The foundation is solid — CloudKit sync, biometric encryption, HealthKit, 87 exercises, supplement tracking, cardio photo capture. The gaps are: Stats is a placeholder, Nutrition has no food/macro tracking, Training scheduling is rigid (weekday-locked), and the design system is minimal (4 colours, no shared components).

---

## Pass 1 — Design System

### Colour tokens (additions to `AppTheme.swift`)

| Token | Hex | Usage |
|-------|-----|-------|
| `.status.success` | `#34C759` | Positive deltas, completed states |
| `.status.warning` | `#FF9500` | Below-target metrics, caution |
| `.status.error` | `#FF3B30` | Missed sessions, critical alerts |
| `.accent.cyan` | `#5AC8FA` | Cardio, HRV, training cards |
| `.accent.purple` | `#BF5AF2` | Evening supplements, sleep |
| `.accent.gold` | `#FFD60A` | PRs, achievements, streaks |

Existing `appOrange1/2` and `appBlue1/2` kept unchanged.

### Type scale (replace all ad-hoc `.font(.system(size:))` calls)

| Level | Size | Weight | Usage |
|-------|------|--------|-------|
| Display | 34pt | Bold | Key metrics on Home (weight, BF) |
| Headline | 20pt | Semibold | Section titles, card headers |
| Body | 15pt | Medium | Exercise names, meal entries |
| Subheading | 13pt | Regular | Supporting info, descriptions |
| Caption | 11pt | Regular/Uppercase | Section labels, unit badges |

### Shared components (`Views/Shared/`)

- **`MetricCard`** — label, value, unit, trend delta, status dot. Replaces `QuickStatPill`.
- **`TrendIndicator`** — coloured pill: `↑ 12%` / `↓ 4%`. Used in Stats, Home, tooltips.
- **`ReadinessCard`** — rotating swipeable card (5 states, see Pass 5).
- **`SectionHeader`** — consistent label + optional action button pattern.
- **`EmptyStateView`** — icon, title, subtitle, optional CTA. Used in Stats, Training.
- **`ChartCard`** — wraps Swift Charts with consistent header, period label, trend chip.
- **`StatusBadge`** — pill with colour + text. Used for day type, phase, sync status.

### What changes in existing views (Pass 1 only)

- Replace all inline `.green`, `.orange`, `.red` → semantic tokens
- Replace all `.font(.system(size:))` → type scale
- `QuickStatPill` in `MainScreenView` → becomes canonical `MetricCard`
- Remove Google/Facebook stub buttons from `WelcomeView` and `SignInView`
- Remove "Create Account (coming soon)" button from `WelcomeView`
- Remove `NSMicrophoneUsageDescription` entry from `Info.plist`
- Remove YubiKey info chip from `SignInView` → move detail to Settings/Security section

---

## Pass 2 — Stats (built from scratch)

**File:** `Views/Stats/StatsView.swift` (full replacement of placeholder)

### Layout

- Period picker (segmented): **7D · 30D · 90D · All** — all charts update together
- Category tabs: **Body · Training · Recovery · Nutrition**
- Each category: summary card (avg + trend chip) + one or more `ChartCard` line charts

### Chart type: line charts throughout

All metrics displayed as **continuous line charts** (Swift Charts `LineMark` + `AreaMark` fill):
- Gradient fill under the line (colour matches category accent)
- Last data point highlighted (larger circle, white stroke)
- Dashed goal target line on body composition charts
- Tap any point → tooltip: date, value, delta vs previous point, delta vs period start
- Drag to scrub timeline

### Body Composition tab

| Chart | Data source | Accent |
|-------|-------------|--------|
| Weight (kg) | `DailyLog.biometrics.weightKg` | `.appOrange1` |
| Body Fat % | `DailyLog.biometrics.bodyFatPercent` | `.status.warning` |
| Lean Mass (kg) | `DailyLog.biometrics.leanBodyMassKg` | `.accent.cyan` |

Goal target lines: `UserProfile.targetWeightMax` (68 kg) and `UserProfile.targetBFMax` (15%) — the phase-achievable upper bounds, matching the bounds used in `UserProfile.weightProgress` and `bfProgress`. Rendered as dashed horizontal lines.
7-day rolling average overlay on weight chart.

### Training Performance tab

| Chart | Data source | Accent |
|-------|-------------|--------|
| Volume per session (kg) | Sum of `SetLog.weightKg × repsCompleted` across all `ExerciseLog.sets` per `DailyLog` | `.accent.cyan` |
| Per-exercise best set | Select exercise from picker → `max(SetLog.weightKg)` per `DailyLog` containing that `exerciseID`, `isWarmup == false` only | `.appOrange1` |
| Zone 2 minutes | `CardioLog.durationMinutes` where `CardioLog.avgHeartRate` is in 106–124 bpm | `.status.success` |

**PR definition:** Personal record = heaviest single `SetLog.weightKg` ever recorded for an `ExerciseDefinition.id`, excluding warmup sets (`SetLog.isWarmup == false`).
**PR detection:** For each exercise, scan all `DailyLog.exerciseLogs` → collect `max(SetLog.weightKg)` per session → annotate the data point where the all-time max was first reached with a gold `★`.
**PR annotation interaction:** Tap `★` → shows: exercise name, `weightKg`, `repsCompleted`, date set.

### Recovery tab

| Chart | Data source | Accent |
|-------|-------------|--------|
| HRV (ms) | `DailyLog.biometrics.effectiveHRV` | `.accent.cyan` |
| Resting HR (bpm) | `DailyLog.biometrics.effectiveRestingHR` | `.status.error` |
| Sleep hours | `DailyLog.biometrics.effectiveSleep` | `.accent.purple` |
| Readiness score | `EncryptedDataStore.readinessScore(for:)` per day | `.status.success` |

HRV chart has coloured zone bands: green (≥35ms), amber (28–35ms), red (<28ms).

### Nutrition Adherence tab

| Chart | Data source | Accent |
|-------|-------------|--------|
| Calories vs target | `NutritionLog.totalCalories` vs daily calorie target (see Pass 3 rules) | `.appOrange1` |
| Protein g/day vs target | `NutritionLog.totalProteinG` vs `2 × DailyLog.biometrics.leanBodyMassKg` (fallback: `ProgramPhase.proteinTargetG.upperBound` = 135g) | `.accent.cyan` |
| Supplement adherence % | `(morningStatus == .completed ? 1 : 0 + eveningStatus == .completed ? 1 : 0) / 2.0` per day | `.accent.gold` |

### Technical

- All chart data computed in `background Task` from `EncryptedDataStore.dailyLogs` — no new storage
- `ChartCard` shared component wraps each chart with consistent header/period/trend
- No new dependency — Swift Charts is available iOS 16+

---

## Pass 3 — Nutrition Overhaul

**File:** `Views/Nutrition/NutritionView.swift` (extended, not replaced)

### Screen structure (top to bottom)

1. **Date header** + overall adherence % badge (unchanged)
2. **Daily macro target bar** (new) — stacked: Protein (cyan) · Carbs (orange) · Fat (purple) · remaining (grey). Shows consumed vs target in kcal and per-macro grams.
3. **Supplements section** — compact pill row (collapsed by default, tap to expand). Keeps all existing toggle logic. Adds 🔥 streak counter badge. Morning and Evening shown side-by-side in compact mode.
4. **Meals section** (new) — 4 default slots: Breakfast · Lunch · Dinner · Snacks. "+ Add Meal" for extras.

### Daily calorie target logic

- Training day (`DailyLog.dayType.isTrainingDay == true`): use `DailyLog.phase.trainingCalories`
- Rest day (`DailyLog.dayType.isTrainingDay == false`): use `DailyLog.phase.restCalories`
- Protein target: `2.0 × DailyLog.biometrics.leanBodyMassKg` grams. Fallback: `ProgramPhase.proteinTargetG.upperBound` (135g) if lean mass unavailable.

### Meal card

Each meal card shows: name, time logged, total kcal, protein g, status (logged / empty / dashed outline).
Tap → meal entry sheet with 3 modes (tab picker at top):

| Mode | Description |
|------|-------------|
| **Manual** | Type name + kcal + P/C/F directly. Fastest for known meals. |
| **Template** | Save any manual entry as a template. Tap to log instantly next time. |
| **Search** | OpenFoodFacts API text search + AVFoundation barcode scanner. Auto-fills macros. |

### Data model additions

- `MealEntry` already exists in `DomainModels.swift` — use as-is
- `NutritionLog.meals: [MealEntry]` already exists — populate from new UI
- **New struct** (add to `DomainModels.swift`): `MealTemplate: Identifiable, Codable, Sendable` — fields: `id: UUID`, `name: String`, `calories: Double?`, `proteinG: Double?`, `carbsG: Double?`, `fatG: Double?`
- **New storage property** on `EncryptedDataStore`: `var mealTemplates: [MealTemplate] = []` — persisted to disk via `EncryptionService` alongside `dailyLogs`. **Not synced to CloudKit** (device-local in this version).

### Supplement changes

- Layout: compact pill dots row (collapsed) / expanded full list (existing logic unchanged)
- **Streak definition:** A day counts toward the streak if `SupplementLog.morningStatus == .completed` AND `SupplementLog.eveningStatus == .completed`. Partial days do not count. Today counts only if already fully completed.
- **New computed property** on `EncryptedDataStore`: `var supplementStreak: Int` — scans `dailyLogs` sorted by date descending, counts consecutive days where both statuses are `.completed`, stops at first day that doesn't qualify.

---

## Pass 4 — Training Plan Behavior

**File:** `Views/Training/TrainingPlanView.swift`

### Core scheduling logic change

**Remove:** auto-setting `DailyLog.dayType` from `TrainingProgramStore.todayDayType` on log creation.
**Replace with:** `todayDayType` used only as the pre-selected suggestion in the session picker. User can override freely.

`DailyLog.dayType` is always written by the user's explicit session picker selection.

### Day navigation — week strip

- Shows **Mon–Sun** (7 days) for the current week
- **TODAY** badge on the current calendar day (orange highlight)
- Green completion dot on days where a `DailyLog` with `completionPct > 0` exists for that calendar date
- **Rest days dimmed:** determined from `Calendar.current.component(.weekday, from: date)` — weekday `1` (Sunday) and weekday `4` (Wednesday) are rest days. These are dimmed when no session has been logged for them.
- Tap any day (past or future) → makes it the active date for logging
- View appears → active date auto-set to today

### Session picker

Below the week strip: 6 session type buttons (Upper Push · Lower Body · Upper Pull · Full Body · Cardio Only · Rest Day).
- Orange = suggested (from `TrainingProgramStore.todayDayType` computed for the **active date's weekday**)
- Any session freely selectable regardless of calendar day
- Selection writes to `DailyLog.dayType` for the active date
- Previous session lookups use `dayType` not calendar date — "Copy last session" for Upper Push finds the most recent `DailyLog` where `dayType == .upperPush` regardless of when it occurred

### Previous session weights

In the set log table for each exercise:
- Ghost rows show last session's `weightKg`/`repsCompleted` as dimmed placeholders, sourced from the most recent `DailyLog` (same `dayType`) that has a non-empty `ExerciseLog` for this `exerciseID`
- Tap ghost row → copies values into active fields (highlights green)
- **"⚡ Copy last session"** button at exercise header → pre-fills all sets in one tap

### RPE input

Replace text field with a **5-segment tap bar** (values: 6 · 7 · 8 · 9 · 10). One tap, no keyboard. Selected segment highlighted. Tap same segment again → clears to `nil`.

### Session completion summary

Shown automatically as a sheet when the last exercise `taskStatus` transitions to `.completed`:
- Total volume (kg) + delta vs previous `DailyLog` of same `dayType`
- Exercises completed / total
- New PRs: exercises where `max(SetLog.weightKg)` this session exceeds all prior sessions for that `exerciseID` (warmups excluded)
- Session duration: `lastSet.timestamp - firstSet.timestamp`
- "Done" dismisses · "Log Notes" opens text field pre-populated with `DailyLog.notes`

---

## Pass 5 — Home Screen Polish

**File:** `Views/Main/MainScreenView.swift`

All existing elements kept in place. Changes are purely additive.

### Visual polish

| Change | Detail |
|--------|--------|
| Progress orb glow | `shadow(color: .white.opacity(0.6), radius: 4)` on vertical tracker orb |
| Weight/BF status dots | 7-day trend direction: green = improving (weight ↓ or BF ↓), amber = flat (±0.2kg / ±0.3%), red = regressing. Computed from last 7 `DailyLog` entries with non-nil `biometrics.weightKg` / `bodyFatPercent`. |
| HRV/HR status dots | From existing `HealthKitService.LiveMetrics.restingHRStatus` and `hrvStatus` enums |
| Goal ring gradient stroke | Stroke uses `appOrange1 → accent.cyan` gradient. Progress bars same gradient. |
| Training button context | Shows today's session: `"💪 \(dayType.rawValue) · \(exerciseCount) ex"` using `TrainingProgramStore.todayDayType` and `TrainingProgramData.exercises(for:).count` |
| Day + Phase badge pills | Rendered as `StatusBadge` components instead of plain secondary text |
| Delta text colour | Positive deltas rendered in `.status.success` |

### Readiness card (replaces 2×2 `QuickStatPill` grid)

`TabView` with `.page` style and visible page dots. 5 pages:

| # | Name | Content |
|---|------|---------|
| 1 | Readiness | Score 1–100 + context label + HRV / Resting HR / Sleep values inline |
| 2 | Weekly Training | Mini session bars for Mon–Sun this week + next session name |
| 3 | Nutrition Snapshot | Calories consumed vs target, protein g, supplement morning/evening status |
| 4 | 7-Day Trends | Weight, BF, HRV, Sleep, Volume, Steps deltas (coloured green/amber/red) |
| 5 | Achievements | Supplement streak 🔥, PRs this week 🏆, program day 📅 |

Card 1 always shown on open. Auto-cycles every 5 seconds via `Timer.publish`. Timer invalidated on swipe gesture, restarted after 5s idle.

### Readiness score

**New method** on `EncryptedDataStore`: `func readinessScore(for date: Date) -> Int?`
Returns `nil` if fewer than 3 days of biometric data exist (shows "— No data yet" in card).

Baseline: mean of last 30 days' `effectiveHRV` and `effectiveRestingHR` from `dailyLogs`.
Falls back to `HealthKitService.LiveMetrics` latest values if fewer than 7 historical logs.

```
hrv_signal    = clamp((todayHRV / baseline30dHRV) × 50, 0, 100)
hr_signal     = clamp(50 + (baseline30dHR - todayHR) × 10, 0, 100)
sleep_signal  = clamp((todaySleep / 8.0) × 100, 0, 100)
score         = Int((hrv_signal × 0.40) + (hr_signal × 0.30) + (sleep_signal × 0.30))
```

**Context labels by score band:**

| Score | Label |
|-------|-------|
| 80–100 | "HRV looks great today 💪" / "Fully recovered — go hard" |
| 60–79 | "Good to go today" / "Solid recovery overnight" |
| 40–59 | "Sleep was short — train lighter" / "HRV slightly suppressed" |
| <40 | "Body needs rest today" / "Light cardio or rest recommended" |

---

## Features Dropped

| Item | Reason |
|------|--------|
| Google Sign-In button | Stub only — SDK never integrated. Dead UI. |
| Facebook Sign-In button | Stub only — SDK never integrated. Dead UI. |
| "Create Account" button | Personal app — no account creation needed. |
| `NSMicrophoneUsageDescription` | App confirmed not using microphone. Remove from Info.plist. |
| YubiKey info chip on Sign-In screen | Visual noise — move detail text to Settings > Security. |

---

## Verification

### Pass 1
- Build succeeds with zero new warnings
- All views render correctly in light + dark mode
- `QuickStatPill` usages replaced by `MetricCard` everywhere
- Removed buttons absent from Welcome/SignIn screens

### Pass 2
- Stats tab shows 4 category tabs with line charts populated from existing log data
- Period picker updates all charts simultaneously
- Tapping a chart point shows tooltip with correct delta vs period start
- PR annotations (★) appear only on sessions where `max(weightKg)` all-time was first reached; warmups excluded
- Zone 2 chart reads `CardioLog.durationMinutes` and `CardioLog.avgHeartRate`
- Empty state (`EmptyStateView`) shown when no logs exist for selected period

### Pass 3
- Daily macro bar: training-day calorie target differs from rest-day target correctly
- Manual meal entry persists to `DailyLog.nutritionLog.meals` across app restart
- `MealTemplate` round-trip: create → restart app → template appears in list
- Template log: tapping template populates `MealEntry` fields correctly
- Food search returns OpenFoodFacts results
- Barcode scanner populates macros on successful scan
- Supplement streak increments only on days where both `morningStatus == .completed` AND `eveningStatus == .completed`

### Pass 4
- Session picker defaults to weekday suggestion; any session selectable
- Selecting non-default session saves correct `dayType` to `DailyLog` for active date
- Ghost weights sourced from most recent `DailyLog` of same `dayType`, not most recent calendar date
- "Copy last session" pre-fills all sets; tapping individual ghost pre-fills one set
- RPE tap bar stores correct value (6–10); tapping selected segment clears to `nil`
- Session summary appears on last-exercise completion; volume delta vs same-`dayType` prior session
- Week strip: Sun (weekday 1) and Wed (weekday 4) dimmed when no session logged

### Pass 5
- Readiness card replaces 4-pill grid; 5 pages with visible page dots
- Auto-cycles every 5s; pauses on swipe, resumes after 5s idle
- `readinessScore(for:)` returns `nil` and card shows "No data yet" when <3 biometric logs exist
- Context label matches score band
- Weight/BF dots reflect 7-day trend (not LiveMetrics)
- HRV/HR dots use `LiveMetrics` status enums
- Training button shows correct `dayType.rawValue` and exercise count
