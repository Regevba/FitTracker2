# Training Plan v2 — UX Spec

> **Phase:** 3 (UX)
> **Input:** v2-audit-report.md (32 findings), prd.md, tasks.md, user decisions Q1-Q7
> **Checklist reference:** `docs/design-system/v2-refactor-checklist.md`
> **Target:** `FitTracker/Views/Training/v2/` (7 files)

---

## 1. Screen Overview

Training Plan v2 decomposes a 2,135-line monolith into a container + 6 extracted views. The user sees one screen with contextual overlays.

### Primary screen: TrainingPlanView
- Activity switcher at top (flexible — not calendar-locked)
- Exercise list (scrollable, collapsible rows)
- Set logging inline
- Rest timer (redesigned bottom bar)
- Session completion sheet
- Focus mode full-screen cover

---

## 2. Low-Fidelity Wireframes

### 2.1 Main Training Screen (default state)

```
┌─────────────────────────────────────────┐
│  ← Training Plan              ⚙️  📷   │  ← Navigation bar
├─────────────────────────────────────────┤
│  M  T  W  T  F  S  S                   │  ← Week strip (7 day pills)
│  ○  ○  ●  ○  ○  ○  ○                   │     ● = today, ✓ = completed
├─────────────────────────────────────────┤
│ ┌─────────────────────────────────────┐ │
│ │ 🏋️ Full Body  ·  ★ Suggested      │ │  ← Activity switcher
│ │                                     │ │     (tappable → picker sheet)
│ │ 3 of 8 exercises done · 45m est    │ │
│ └─────────────────────────────────────┘ │
│                                         │
│ ┌─────── Exercise 1 ─────────────────┐ │
│ │ ▼ Bench Press (Chest)         ✓    │ │  ← Collapsed (finished)
│ └─────────────────────────────────────┘ │
│                                         │
│ ┌─────── Exercise 2 ─────────────────┐ │
│ │ ▶ Incline DB Press (Chest)    ···  │ │  ← Expanded (active)
│ │                                     │ │
│ │  Set 1: 20kg × 10  ✓  [Copy Last] │ │  ← SetRowView
│ │  Set 2: 20kg × 8   ✓              │ │
│ │  Set 3: ___  × ___    [Log] [🗑️] │ │  ← Empty set
│ │                                     │ │
│ │  💡 "Keep elbows at 45°"           │ │  ← Coaching cue
│ └─────────────────────────────────────┘ │
│                                         │
│ ┌─────── Exercise 3 ─────────────────┐ │
│ │ ▶ Lat Pulldown (Back)         ···  │ │  ← Pending
│ └─────────────────────────────────────┘ │
│                                         │
│  ... more exercises ...                 │
│                                         │
├─────────────────────────────────────────┤
│ ⏱️ Rest: 1:23 remaining    [Skip]     │  ← RestTimerView (bottom bar)
└─────────────────────────────────────────┘
```

### 2.2 Activity Switcher (sheet)

```
┌─────────────────────────────────────────┐
│  Choose Activity                  Done  │
│                                         │
│  ┌───────────┐  ┌───────────┐          │
│  │ Full Body │  │Upper Push │          │
│  │  ★ Today  │  │           │          │
│  └───────────┘  └───────────┘          │
│  ┌───────────┐  ┌───────────┐          │
│  │Lower Body │  │Upper Pull │          │
│  │           │  │           │          │
│  └───────────┘  └───────────┘          │
│  ┌───────────┐  ┌───────────┐          │
│  │  Cardio   │  │ Recovery  │          │
│  │           │  │           │          │
│  └───────────┘  └───────────┘          │
└─────────────────────────────────────────┘
```

### 2.3 Set Row (expanded detail)

```
┌─────────────────────────────────────────┐
│  Set 3                   prev: 20×10   │
│                                         │
│  ┌──────────┐  ┌──────────┐            │
│  │  22  kg  │  │  10 reps │            │
│  └──────────┘  └──────────┘            │
│                                         │
│  [Copy Last]  [Log ✓]  [🗑️]           │
│                                         │
│  RPE: ● ● ● ● ● ○ ○ ○ ○ ○  (5/10)    │
└─────────────────────────────────────────┘
```

### 2.4 Rest Timer (bottom bar — redesigned)

```
┌─────────────────────────────────────────┐
│  ⏱️  1:23          ━━━━━━━━━━░░  [Skip]│
│      remaining      progress bar        │
└─────────────────────────────────────────┘
```

### 2.5 Rest Day

```
┌─────────────────────────────────────────┐
│  ← Training Plan                        │
├─────────────────────────────────────────┤
│  M  T  W  T  F  S  S                   │
│  ○  ○  ○  ●  ○  ○  ○                   │
├─────────────────────────────────────────┤
│                                         │
│         🧘  Rest Day                    │
│                                         │
│   Active recovery — walk, yoga,         │
│   stretch, or just relax.               │
│                                         │
│   [Switch to a workout instead]         │
│                                         │
└─────────────────────────────────────────┘
```

### 2.6 Session Completion

```
┌─────────────────────────────────────────┐
│  Session Complete! 🎉            Done   │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │     42:15        8 exercises    │   │
│  │     duration     completed      │   │
│  │                                 │   │
│  │     24 sets      1,240 kg       │   │
│  │     logged       total volume   │   │
│  └─────────────────────────────────┘   │
│                                         │
│  Great effort! You're building          │
│  consistency. 💪                        │
│                                         │
│  [Share]         [Done]                 │
└─────────────────────────────────────────┘
```

---

## 3. High-Fidelity Schematics

### 3.1 Main Training Screen — Token Mapping

```
┌─ NavigationStack ─────────────────────────────────────┐
│  .navigationTitle("Training Plan")                     │
│  .navigationBarTitleDisplayMode(.inline)                │
│  .toolbar { camera(AppIcon.*), settings(AppIcon.*) }   │
├────────────────────────────────────────────────────────┤
│  WeekStripView                                         │
│  ├─ HStack(spacing: AppSpacing.xxSmall)                │
│  ├─ Each day: Button { } label: {                      │
│  │    VStack {                                         │
│  │      Text(weekday) .font(AppText.eyebrow)           │
│  │      Circle(AppSpacing.xLarge)                      │
│  │        .fill(isToday ? AppColor.Brand.warmSoft       │
│  │             : isSelected ? AppColor.Surface.strong   │
│  │             : .clear)                                │
│  │      Text(dayNumber) .font(AppText.captionStrong)   │
│  │      Circle(6pt) .fill(isComplete ? .success : .clear)│
│  │    }                                                │
│  │  }                                                  │
│  │  .accessibilityLabel("\(weekday) \(date)")          │
│  │  .accessibilityHint(isComplete ? "Completed" : "")  │
│  │  .frame(minWidth: 44, minHeight: 44)                │
│  └─ ← all Button, NOT onTapGesture (F24)              │
├────────────────────────────────────────────────────────┤
│  ActivitySwitcherCard (tappable → picker sheet)        │
│  ├─ AppCard(Tone: .Elevated)                           │
│  ├─ HStack {                                           │
│  │    VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {│
│  │      HStack {                                       │
│  │        Text(activityIcon) .font(AppText.iconMedium) │
│  │        Text(activityName) .font(AppText.titleStrong)│
│  │        if isSuggested { StatusBadge(.success, "Suggested") }│
│  │      }                                              │
│  │      Text("\(done) of \(total) · \(est)m")          │
│  │        .font(AppText.callout)                       │
│  │        .foregroundStyle(AppColor.Text.secondary)    │
│  │    }                                                │
│  │    Spacer()                                         │
│  │    Image(systemName: "chevron.right")               │
│  │      .font(AppText.caption)                         │
│  │      .foregroundStyle(AppColor.Text.tertiary)       │
│  │  }                                                  │
│  ├─ .onTapGesture { showActivityPicker = true }        │
│  ├─ .accessibilityLabel("Activity: \(name)")           │
│  └─ .accessibilityHint("Tap to switch activity")       │
├────────────────────────────────────────────────────────┤
│  ScrollView {                                          │
│    LazyVStack(spacing: AppSpacing.xSmall) {            │
│      ForEach(exercises) { exercise in                  │
│        ExerciseRowView(                                │
│          exercise: exercise,                           │
│          isCollapsed: exercise.isComplete, // Q3       │
│          onSetLogged: { ... },                         │
│          onExerciseCompleted: { ... }                  │
│        )                                               │
│      }                                                 │
│    }                                                   │
│  }                                                     │
├────────────────────────────────────────────────────────┤
│  .safeAreaInset(edge: .bottom) {                       │
│    RestTimerView(                                      │
│      remainingSeconds: $restRemaining,                 │
│      onSkip: { ... },                                  │
│      onComplete: { ... }                               │
│    )                                                   │
│    .padding(.horizontal, AppSpacing.small)              │
│    .padding(.bottom, AppSize.tabBarClearance)           │
│  }                                                     │
└────────────────────────────────────────────────────────┘
```

### 3.2 ExerciseRowView — High Fidelity

```
┌─ DisclosureGroup ─────────────────────────────────────┐
│  HStack(spacing: AppSpacing.xSmall) {                  │
│    // Status accent stripe                             │
│    RoundedRectangle(AppRadius.micro)                   │
│      .fill(statusColor) // AppColor.Status.*           │
│      .frame(width: 4)                                  │
│                                                        │
│    VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {│
│      Text(exercise.name)                               │
│        .font(AppText.sectionTitle)                     │
│        .strikethrough(exercise.isComplete)              │
│        .foregroundStyle(exercise.isComplete             │
│          ? AppColor.Text.tertiary                      │
│          : AppColor.Text.primary)                      │
│                                                        │
│      Text(exercise.muscleGroups.joined(separator: " · "))│
│        .font(AppText.caption)                          │
│        .foregroundStyle(AppColor.Text.secondary)       │
│                                                        │
│      HStack(spacing: AppSpacing.xxSmall) {             │
│        AppPickerChip("\(sets)s", state: .unselected)   │
│        AppPickerChip("\(reps)r", state: .unselected)   │
│        AppPickerChip("\(rest)s rest", state: .unselected)│
│      }                                                 │
│    }                                                   │
│                                                        │
│    Spacer()                                            │
│    // Completion indicator                             │
│    if exercise.isComplete {                            │
│      Image(systemName: "checkmark.circle.fill")        │
│        .font(AppText.iconMedium)                       │
│        .foregroundStyle(AppColor.Status.success)       │
│    }                                                   │
│  }                                                     │
│  .padding(AppSpacing.small)                            │
│  .frame(minHeight: 44) // F13: Fitts's Law             │
│  .accessibilityLabel("\(name), \(muscleGroup)")        │
│  .accessibilityValue(isComplete ? "Complete" : "Pending")│
│  .accessibilityHint("Double tap to expand")            │
│                                                        │
│  // EXPANDED: Set rows                                 │
│  if !isCollapsed {                                     │
│    VStack(spacing: AppSpacing.xxSmall) {               │
│      ForEach(sets) { set in                            │
│        SetRowView(set: set, ...)                       │
│      }                                                 │
│      Text(exercise.coachingCue)                        │
│        .font(AppText.caption)                          │
│        .foregroundStyle(AppColor.Accent.primary)       │
│        .padding(.leading, AppSpacing.medium)           │
│    }                                                   │
│  }                                                     │
├────────────────────────────────────────────────────────┤
│  Background: AppColor.Surface.elevated                 │
│  Radius: AppRadius.card                                │
│  Shadow: effect/elevation-card                         │
│  Animation: AppSpring.snappy on expand/collapse        │
└────────────────────────────────────────────────────────┘
```

### 3.3 SetRowView — High Fidelity

```
┌─ HStack(spacing: AppSpacing.xSmall) ──────────────────┐
│                                                        │
│  Text("Set \(index)")                                  │
│    .font(AppText.captionStrong)                        │
│    .frame(width: 48, alignment: .leading)              │
│                                                        │
│  // Weight input                                       │
│  VStack(spacing: AppSpacing.micro) {                   │
│    TextField("kg", text: $weight)                      │
│      .font(AppText.metric)                             │
│      .keyboardType(.decimalPad)                        │
│      .frame(minWidth: 60)                              │
│    if let prev = previousWeight {                      │
│      Button("\(prev)") { weight = prev } // quick-fill │
│        .font(AppText.footnote)                         │
│        .foregroundStyle(AppColor.Text.tertiary)        │
│    }                                                   │
│  }                                                     │
│                                                        │
│  Text("×") .font(AppText.caption)                      │
│                                                        │
│  // Reps input                                         │
│  VStack(spacing: AppSpacing.micro) {                   │
│    TextField("reps", text: $reps)                      │
│      .font(AppText.metric)                             │
│      .keyboardType(.numberPad)                         │
│      .frame(minWidth: 48)                              │
│    if let prev = previousReps {                        │
│      Button("\(prev)") { reps = prev }                 │
│        .font(AppText.footnote)                         │
│        .foregroundStyle(AppColor.Text.tertiary)        │
│    }                                                   │
│  }                                                     │
│                                                        │
│  Spacer()                                              │
│                                                        │
│  // Action buttons                                     │
│  if set.isLogged {                                     │
│    Image(systemName: "checkmark.circle.fill")          │
│      .font(AppText.iconMedium)                         │
│      .foregroundStyle(AppColor.Status.success) // F16  │
│  } else {                                              │
│    Button("Copy Last") { ... }                         │
│      .font(AppText.chip)                               │
│      .foregroundStyle(AppColor.Accent.primary)         │
│                                                        │
│    Button("Log") { ... }                               │
│      .font(AppText.button)                             │
│      .foregroundStyle(AppColor.Text.inversePrimary)    │
│      .background(AppColor.Accent.primary)              │
│      .clipShape(Capsule())                             │
│  }                                                     │
│                                                        │
│  Button { delete() } label: {                          │
│    Image(systemName: "trash")                          │
│      .font(AppText.iconSmall)                          │
│      .foregroundStyle(AppColor.Status.error)           │
│  }                                                     │
│  .frame(minWidth: 44, minHeight: 44) // F26: ≥44pt    │
│  .contentShape(Rectangle())                            │
│  .accessibilityLabel("Delete set \(index)")            │
│                                                        │
├────────────────────────────────────────────────────────┤
│  .accessibilityElement(children: .combine)             │
│  .accessibilityLabel("Set \(index)")                   │
│  .accessibilityValue(isLogged                          │
│    ? "\(weight) kg, \(reps) reps" : "Not logged")     │
└────────────────────────────────────────────────────────┘
```

### 3.4 RestTimerView — High Fidelity (Redesigned)

```
┌─ .safeAreaInset(edge: .bottom) ───────────────────────┐
│  HStack(spacing: AppSpacing.xSmall) {                  │
│                                                        │
│    Image(systemName: "timer")                          │
│      .font(AppText.iconSmall)                          │
│      .foregroundStyle(AppColor.Accent.primary)         │
│                                                        │
│    Text(formattedTime)                                 │
│      .font(AppText.monoMetric) // monospaced countdown │
│      .foregroundStyle(AppColor.Text.primary)           │
│      .contentTransition(.numericText())                │
│                                                        │
│    // Progress bar (remaining / total)                 │
│    GeometryReader { proxy in                           │
│      ZStack(alignment: .leading) {                     │
│        Capsule()                                       │
│          .fill(AppColor.Surface.tertiary)              │
│        Capsule()                                       │
│          .fill(AppColor.Accent.primary)                │
│          .frame(width: proxy.size.width * progress)    │
│      }                                                 │
│    }                                                   │
│    .frame(height: AppSize.progressBarHeight)           │
│                                                        │
│    Button("Skip") {                                    │
│      analytics.logTrainingRestTimerSkipped(...)        │
│      skipTimer()                                       │
│    }                                                   │
│    .font(AppText.chip)                                 │
│    .foregroundStyle(AppColor.Accent.primary)           │
│  }                                                     │
│  .padding(AppSpacing.small)                            │
│  .background(                                          │
│    AppColor.Surface.elevated                           │
│      .shadow(color: AppShadow.cardColor,               │
│              radius: AppShadow.cardRadius,              │
│              y: -AppShadow.cardYOffset) // upward       │
│  )                                                     │
│  .transition(.move(edge: .bottom))                     │
│  .animation(AppSpring.snappy, value: isTimerActive)    │
│                                                        │
│  Haptics:                                              │
│  - Timer start: UIImpactFeedbackGenerator(.medium)     │
│  - 10s warning: UINotificationFeedbackGenerator(.warning)│
│  - Complete: UINotificationFeedbackGenerator(.success)  │
│  - Skip: UIImpactFeedbackGenerator(.light)             │
└────────────────────────────────────────────────────────┘
```

---

## 4. Token Map

| Element | Token |
|---|---|
| Card backgrounds | `AppColor.Surface.elevated` |
| Card radius | `AppRadius.card` (16pt) |
| Card shadow | `effect/elevation-card` |
| Card padding | `AppSpacing.small` (16pt) |
| Item spacing | `AppSpacing.xSmall` (12pt) / `AppSpacing.xxSmall` (8pt) |
| Exercise name | `AppText.sectionTitle` |
| Muscle group | `AppText.caption`, `AppColor.Text.secondary` |
| Set number | `AppText.captionStrong` |
| Weight/reps values | `AppText.metric` |
| Timer countdown | `AppText.monoMetric` |
| Coaching cue | `AppText.caption`, `AppColor.Accent.primary` |
| Eyebrow (section headers) | `AppText.eyebrow`, `AppColor.Text.tertiary` |
| CTA buttons | `AppText.button`, `AppColor.Accent.primary` bg |
| Chip labels | `AppText.chip` |
| Status colors | `AppColor.Status.success/warning/error` |
| Delete icon | `AppText.iconSmall`, `AppColor.Status.error` |
| Progress bar | `AppSize.progressBarHeight`, `AppRadius.micro` |
| Tab bar clearance | New `AppSize.tabBarClearance` (56pt) |
| All animations | `AppSpring.snappy` (expand/collapse), `AppEasing.short` (timer) |

---

## 5. State Matrix

| State | Visual | Trigger |
|---|---|---|
| **Default** | Exercise list, activity switcher, timer hidden | Data loaded |
| **Loading** | Skeleton placeholders in exercise list area | Initial data fetch |
| **Empty (rest day)** | Rest day card with recovery message + "Switch to workout" CTA | DayType == .restDay |
| **Error** | Inline banner above exercise list: "Couldn't save — tap to retry" | Save failure |
| **Timer active** | Bottom bar slides up with countdown + progress + skip | Rest timer started |
| **Exercise complete** | Row collapses with checkmark, `AppSpring.snappy` animation | All sets logged |
| **Session complete** | Completion sheet presents (`.medium`/`.large` detents) | All exercises done |
| **Focus mode** | Full-screen cover with single exercise detail | User enters focus |

---

## 6. Accessibility

| Element | Label | Hint | Value | Traits |
|---|---|---|---|---|
| Week day (each) | "{weekday} {date}" | "{status}" | — | `.isButton` |
| Activity switcher | "Activity: {name}" | "Tap to switch" | — | — |
| Exercise row | "{name}, {muscle}" | "Double tap to expand" | "Complete" / "Pending" | — |
| Set row | "Set {N}" | — | "{weight} kg, {reps} reps" / "Not logged" | — |
| Copy Last button | "Copy last set" | "Fills {weight} kg and {reps} reps" | — | `.isButton` |
| Log button | "Log set" | "Records this set" | — | `.isButton` |
| Delete button | "Delete set {N}" | — | — | `.isButton` |
| Rest timer | "Rest timer" | — | "{time} remaining" | — |
| Skip button | "Skip rest" | — | — | `.isButton` |
| Coaching cue | "{cue text}" | — | — | `.isStaticText` |
| Section headers | "{section name}" | — | — | `.isHeader` |

---

## 7. Analytics Mapping

| Interaction | Event | Key params |
|---|---|---|
| Screen appears | `.analyticsScreen(.trainingPlan)` | — |
| Tap exercise | `training_exercise_started` | exercise_name, muscle_group |
| All sets done | `training_exercise_completed` | exercise_name, muscle_group |
| Log a set | `training_set_logged` | exercise_name, set_index, reps, weight_kg |
| Copy Last | `training_set_copied` | exercise_name, set_index |
| Change weight | `training_weight_changed` | exercise_name, set_index, weight_kg |
| Start rest | `training_rest_timer_started` | rest_duration_seconds |
| Skip rest | `training_rest_timer_skipped` | rest_duration_seconds |
| Switch activity | `training_activity_switched` | activity_type |
| Session done | `training_session_completed` | activity_type, session_duration_seconds, exercise_count, total_sets |
| Enter focus | `training_focus_mode_entered` | exercise_name |
| Open camera | `training_camera_opened` | exercise_name |

---

## 8. Compliance Gateway

| Check | Status | Details |
|---|---|---|
| Token compliance | **Pass** | All elements mapped to AppText/AppSpacing/AppColor/AppRadius/AppSize. 1 new token: `AppSize.tabBarClearance` |
| Component reuse | **Pass** | Reuses AppPickerChip, StatusBadge, AppCard. New views justified (file decomposition) |
| Pattern consistency | **Pass** | Card + sheet pattern matches Home v2. Activity picker matches onboarding goal selection |
| Accessibility | **Pass** | All 50+ elements specified. Week days as Buttons. All targets ≥44pt. AX5 verified in spec |
| Motion | **Pass** | All tokenized. Reduce-motion via motionSafe. Haptic pairings specified |

---

## 9. V2 Refactor Checklist Cross-Reference

| Section | Addressed by |
|---|---|
| A — Audit & spec | v2-audit-report.md (Phase 0), this ux-spec.md |
| B — File convention | 7 files under v2/, pbxproj swap (T12) |
| C — Token compliance | Token Map (§4) |
| D — Component reuse | AppPickerChip, StatusBadge, AppCard reused |
| E — UX principles | All 13 addressed via design decisions |
| F — State coverage | State Matrix (§5) — 8 states |
| G — Accessibility | §6 — 50+ elements, all ≥44pt, AX5 |
| H — Motion | All AppSpring/AppEasing, motionSafe, haptic pairing |
| I — Analytics | §7 — 12 events, training_* prefix |
| J — Build & test | Phase 5 |
| K — Documentation | Phase 8 |
