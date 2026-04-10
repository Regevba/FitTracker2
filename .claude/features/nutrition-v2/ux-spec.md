# Nutrition v2 — UX Spec

> **Phase:** 3 (UX)
> **Input:** v2-audit-report.md (23 findings), prd.md, tasks.md
> **Checklist reference:** `docs/design-system/v2-refactor-checklist.md`
> **Target:** `FitTracker/Views/Nutrition/v2/NutritionView.swift` + 3 extracted components

---

## 1. Screen Overview

Nutrition v2 preserves the v1 information architecture (which is solid) while fixing token compliance, adding motion tokens, extracting components, and achieving 90%+ accessibility coverage. This is a **compliance refactor**, not a redesign.

### Sections (preserved from v1)
1. Date header (with day navigation)
2. Macro bar (calorie + protein + carbs + fat progress)
3. Nutrition command deck (Log First Meal + Quick Protein buttons)
4. Logged items feed (chronological meal list)
5. Quick log section (favorites + remembered meals)
6. Supplement row (morning/evening toggle pills)
7. Hydration card (water tracking + progress bar)
8. Adherence row (supplement adherence summary)
9. Disclaimer note

### States (v2 addition)
| State | Trigger | UI |
|-------|---------|-----|
| **Loading** | Initial data fetch / date change | SkeletonLoadingView (shimmer placeholders for macro bar + 3 meal rows) |
| **Success** | Data loaded | Normal content |
| **Empty** | No meals logged for date | Empty state: fork.knife.circle icon + "No meals logged yet" + "Log First Meal" CTA |
| **Error** | Data load failure | Error banner + retry button |
| **Default** | Active editing | Normal with editable fields |

---

## 2. Low-Fidelity Wireframes

### 2.1 Main Nutrition Screen (success state)

```
┌─────────────────────────────────────────┐
│  ← Nutrition                             │  ← NavigationStack inline title
├─────────────────────────────────────────┤
│  ◀  Wednesday, Apr 10  ▶               │  ← Date header (chevron buttons)
├─────────────────────────────────────────┤
│  ┌─────────────────────────────────────┐│
│  │ 1,850 / 2,200 kcal                 ││  ← Macro bar (CalorieRingView)
│  │ P: 142/180g  C: 210/250g  F: 62/70g││     Protein · Carbs · Fat progress
│  └─────────────────────────────────────┘│
│                                         │
│  ┌─────────────┐  ┌─────────────┐      │
│  │ 🍽 Log Meal │  │ ⚡ Protein  │      │  ← Command deck (2 CTAs)
│  └─────────────┘  └─────────────┘      │
│                                         │
│  MEALS TODAY                            │  ← Section header (eyebrow)
│  ┌─────────────────────────────────────┐│
│  │ Meal 1 · Breakfast                  ││  ← Meal row (tappable)
│  │ 520 kcal · 35g protein              ││
│  └─────────────────────────────────────┘│
│  ┌─────────────────────────────────────┐│
│  │ Meal 2 · Lunch                      ││
│  │ 680 kcal · 48g protein              ││
│  └─────────────────────────────────────┘│
│                                         │
│  SUPPLEMENTS                            │
│  ┌─────────────────────────────────────┐│
│  │ ☀ Morning [✓]    🌙 Evening [ ]   ││  ← Pill buttons
│  │ Adherence: 85%  ━━━━━━━━━░░         ││  ← ProgressBar component
│  │ ℹ                                   ││
│  └─────────────────────────────────────┘│
│                                         │
│  HYDRATION                              │
│  ┌─────────────────────────────────────┐│
│  │ 💧 1,500 / 2,000 ml                ││  ← Hydration card
│  │ ━━━━━━━━━━━━░░░░                    ││  ← ProgressBar component
│  │ [+250ml] [+500ml] [Custom]          ││
│  └─────────────────────────────────────┘│
│                                         │
│  * Nutritional data is approximate      │  ← Disclaimer
└─────────────────────────────────────────┘
```

### 2.2 Loading State

```
┌─────────────────────────────────────────┐
│  ← Nutrition                             │
├─────────────────────────────────────────┤
│  ◀  Wednesday, Apr 10  ▶               │
├─────────────────────────────────────────┤
│  ┌─────────────────────────────────────┐│
│  │ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░     ││  ← Shimmer macro bar
│  │ ░░░░░░░  ░░░░░░░  ░░░░░░░         ││
│  └─────────────────────────────────────┘│
│  ░░░░░░░░░░░░░  ░░░░░░░░░░░░░         │  ← Shimmer buttons
│  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░      │  ← Shimmer meal row 1
│  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░      │  ← Shimmer meal row 2
│  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░      │  ← Shimmer meal row 3
└─────────────────────────────────────────┘
```

---

## 3. Token Mapping (High-Fidelity Schematics)

### 3.1 Date Header
```
HStack(spacing: AppSpacing.small)
├─ Button (chevron.left)
│    .frame(width: AppSize.touchTargetLarge, height: AppSize.touchTargetLarge)  ← F3 fix
│    .accessibilityLabel("Previous day")
│    fires: nutrition_date_changed(direction: "backward")
├─ Text(dateString)
│    .font(AppText.sectionTitle)
│    .foregroundStyle(AppColor.Text.primary)
├─ Button (chevron.right)
│    .frame(width: AppSize.touchTargetLarge, height: AppSize.touchTargetLarge)  ← F3 fix
│    .accessibilityLabel("Next day")
│    fires: nutrition_date_changed(direction: "forward")
```

### 3.2 Supplement Pill Buttons (extracted: SupplementPillButton)
```
SupplementPillButton(title: "Morning", isComplete: morningStatus == .completed)
├─ HStack(spacing: AppSpacing.xxxSmall)
│    ├─ Text(title).font(AppText.captionStrong)  ← F9 fix
│    ├─ if isComplete: Image(systemName: "checkmark").font(AppText.captionStrong)  ← F9 fix
├─ .foregroundStyle(isComplete ? AppColor.Status.success : AppColor.Text.secondary)  ← F7 fix
├─ .background(isComplete ? AppColor.Status.success.opacity(AppOpacity.disabled) : AppColor.Surface.elevated.opacity(AppOpacity.subtle))  ← F10 fix
├─ .clipShape(Capsule())
├─ .accessibilityLabel(isComplete ? "\(title) supplements taken" : "\(title) supplements pending")  ← F12/F13 fix
├─ .accessibilityHint("Toggle to mark \(title.lowercased()) supplements")
├─ fires: nutrition_supplement_logged(time_of_day: title.lowercased())
├─ withAnimation(AppMotion.quickInteraction)  ← F1 fix
```

### 3.3 Progress Bars (extracted: ProgressBar component)
```
ProgressBar(progress: fraction, color: tintColor, height: 6)
├─ ZStack(alignment: .leading)
│    ├─ RoundedRectangle(cornerRadius: AppRadius.micro)
│    │    .fill(AppColor.Surface.tertiary)
│    │    .frame(height: height)
│    ├─ RoundedRectangle(cornerRadius: AppRadius.micro)
│    │    .fill(color)
│    │    .frame(width: totalWidth * progress, height: height)
│    │    .animation(AppSpring.progress, value: progress)  ← F2 fix (new token)
├─ .accessibilityElement(children: .ignore)
├─ .accessibilityLabel(accessibilityLabel)  ← F16/F17/F18 fix
├─ .accessibilityValue(accessibilityValue)
```

### 3.4 AsyncState Integration
```swift
enum NutritionLoadState {
    case loading
    case success
    case error(String)
}

@State private var loadState: NutritionLoadState = .loading

// In body:
switch loadState {
case .loading:
    SkeletonLoadingView(rows: 5)  // Reuse from Training v2 pattern
case .error(let message):
    ErrorBannerView(message: message, retryAction: { loadLog(for: activeDate) })
case .success:
    // existing content
}
```

---

## 4. Principle Application Table

| Principle | How Applied | Finding Fixed |
|-----------|------------|---------------|
| §1.1 Fitts's Law | Chevron buttons → AppSize.touchTargetLarge (48pt, was 44pt) | F3 |
| §1.2 Hick's Law | Preserved — command deck already limits choices to 2 CTAs | — |
| §1.4 Progressive Disclosure | Supplements expand/collapse preserved | — |
| §2.x Content Hierarchy | All fonts → AppText tokens | F9, F10 |
| §6.x State Patterns | AsyncState enum: loading + error + empty + success + default | F19 |
| §7.x Accessibility | 90%+ VoiceOver coverage, .accessibilityValue on progress bars | F12-F18, F23 |
| §8.x Motion | All animations → AppMotion/AppSpring/AppEasing tokens | F1, F2 |
| §9.x Color Semantics | All colors → AppColor namespace | F7, F8 |
| §10.x Platform Patterns | GeometryReader replaced by ProgressBar component | F6 |
| §13 Celebration Not Guilt | Preserved — no guilt copy in nutrition tracking | — |

---

## 5. Accessibility Specification

### VoiceOver Labels (target: 15/15 = 100%)

| Element | Label | Value | Hint |
|---------|-------|-------|------|
| Previous day button | "Previous day" | — | "Navigate to previous day" |
| Next day button | "Next day" | — | "Navigate to next day" |
| Macro bar | "Daily nutrition" | "1850 of 2200 calories" | — |
| Log Meal button | "Log meal" | — | "Open meal entry form" |
| Quick Protein button | "Quick protein" | — | "Add quick protein entry" |
| Meal row | "Meal: {name}" | "{calories} kcal, {protein}g protein" | "Double tap to edit" |
| Morning pill | "Morning supplements {taken/pending}" | — | "Toggle morning supplements" |
| Evening pill | "Evening supplements {taken/pending}" | — | "Toggle evening supplements" |
| Supplement info | "Supplement adherence info" | — | "Show adherence details" |
| Adherence bar | "Supplement adherence" | "{percentage}% adherence" | — |
| Hydration bar | "Hydration progress" | "{current} of {target} ml" | — |
| +250ml button | "Add 250 milliliters" | — | — |
| +500ml button | "Add 500 milliliters" | — | — |
| Custom water button | "Add custom amount" | — | "Enter water amount" |
| Empty state icon | "No meals logged" | — | — |

### Dynamic Type
- All text uses AppText tokens (already @ScaledMetric-compatible)
- ProgressBar height uses fixed value (6pt) — intentional, progress bars don't scale

### Reduce Motion
- All animations guarded by `@Environment(\.accessibilityReduceMotion)`
- When reduce motion on: instant state changes, no spring animations

---

## 6. Design System Compliance Report

| Check | Status | Details |
|-------|--------|---------|
| Token compliance | Pass | All 23 findings addressed — fonts, colors, spacing, motion all mapped to tokens |
| Component reuse | Pass | ProgressBar (new, reusable), SupplementPillButton (new), SkeletonLoadingView (reuse from Training v2) |
| Pattern consistency | Pass | Same v2 refactor pattern as Home + Training |
| Accessibility | Pass | 15/15 elements labeled, 3 progress bars with .accessibilityValue |
| Motion | Pass | All 7 raw animations replaced with AppMotion/AppSpring/AppEasing tokens |

**All checks pass. No compliance violations.**
