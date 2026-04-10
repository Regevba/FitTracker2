# Nutrition v2 — Task Breakdown

> **Phase:** 2 (Tasks)
> **Total tasks:** 14
> **Estimated effort:** 2.5 days
> **Dependencies:** Linear (T1 unlocks T2-T7, T8 unlocks T9-T10)

---

## Design System Evolution (T1-T2)

### T1. Add new DS tokens to AppTheme.swift
- **Type:** design | **Skill:** design | **Priority:** critical | **Effort:** 0.25d
- **Depends on:** —
- Add `AppSpring.progress` (spring response: 0.55, damping: 0.80)
- Add `AppColor.Accent.nutrition` (cyan-tinted accent)
- Add `AppOpacity` enum (disabled: 0.15, subtle: 0.12, hover: 0.08)
- Add `AppSpacing.supplementDetailIndent` (54pt)
- Run `make tokens-check` to verify pipeline

### T2. Create ProgressBar reusable component
- **Type:** design | **Skill:** design | **Priority:** high | **Effort:** 0.25d
- **Depends on:** T1
- Create `FitTracker/DesignSystem/ProgressBar.swift`
- Props: progress (0-1), color, height, animated
- Uses AppSpring.progress for animation
- Uses AppRadius.micro for corners
- Accessibility: .accessibilityValue with percentage
- Replace GeometryReader progress bars in v2

## Type Extraction (T3-T5)

### T3. Extract SupplementStackCard
- **Type:** ui | **Skill:** dev | **Priority:** high | **Effort:** 0.25d
- **Depends on:** T1
- Extract lines 928-1005 to `Views/Nutrition/Components/SupplementStackCard.swift`
- Replace inline GeometryReader with ProgressBar (T2)
- Apply AppSpring.progress, AppOpacity tokens
- Add accessibility labels

### T4. Extract SupplementItemRow
- **Type:** ui | **Skill:** dev | **Priority:** high | **Effort:** 0.25d
- **Depends on:** T1
- Extract lines 1011-1092 to `Views/Nutrition/Components/SupplementItemRow.swift`
- Replace magic padding (54pt) with AppSpacing.supplementDetailIndent
- Apply AppColor, AppText tokens
- Add accessibility labels

### T5. Extract HapticFeedback to shared service
- **Type:** backend | **Skill:** dev | **Priority:** medium | **Effort:** 0.1d
- **Depends on:** —
- Move lines 1098-1106 to `FitTracker/Services/HapticFeedback.swift`
- Update imports in NutritionView and any other consumers

## V2 Container Build (T6-T7)

### T6. Build v2/NutritionView.swift container
- **Type:** ui | **Skill:** dev | **Priority:** critical | **Effort:** 0.5d
- **Depends on:** T1, T2, T3, T4, T5
- Create `FitTracker/Views/Nutrition/v2/NutritionView.swift`
- Build bottom-up from design system foundations
- Fix all P0 findings: motion tokens, touch targets, magic padding
- Fix all P1 findings: color tokens, font tokens, opacity tokens
- Add AsyncState enum (loading/error/success) with SkeletonLoadingView
- Wire extracted components (SupplementStackCard, SupplementItemRow, ProgressBar)
- Use SupplementPillButton for morning/evening toggle

### T7. Update project.pbxproj (v2 swap)
- **Type:** infra | **Skill:** dev | **Priority:** critical | **Effort:** 0.1d
- **Depends on:** T6
- Add PBXGroup for `Views/Nutrition/v2/`
- Add PBXGroup for `Views/Nutrition/Components/`
- Add PBXFileReference + PBXBuildFile for v2/NutritionView.swift
- Add PBXFileReference + PBXBuildFile for Components/{SupplementStackCard,SupplementItemRow}.swift
- Add PBXFileReference + PBXBuildFile for DesignSystem/ProgressBar.swift
- Add PBXFileReference + PBXBuildFile for Services/HapticFeedback.swift
- REMOVE v1 NutritionView.swift from Sources build phase
- Mark v1 with HISTORICAL header comment

## Accessibility Pass (T8)

### T8. Full VoiceOver accessibility pass
- **Type:** ui | **Skill:** dev | **Priority:** high | **Effort:** 0.25d
- **Depends on:** T6
- Add .accessibilityLabel to all 15+ interactive elements
- Add .accessibilityValue to all 3 progress bars
- Add .accessibilityHint to key actions
- Fix duplicate .accessibilityLabel (F15)
- Add .accessibilityElement(children: .combine) to meal rows
- Target: 90%+ coverage (14/15+ elements)

## Analytics (T9-T10)

### T9. Instrument 5 new analytics events
- **Type:** analytics | **Skill:** analytics | **Priority:** high | **Effort:** 0.25d
- **Depends on:** T6
- Add to AnalyticsProvider.swift:
  - `nutrition_meal_logged` (replaces `meal_log`)
  - `nutrition_supplement_logged` (replaces `supplement_log`)
  - `nutrition_hydration_updated`
  - `nutrition_date_changed`
  - `nutrition_empty_state_shown`
- Add new AnalyticsParam constants
- Update analytics-taxonomy.csv
- Wire events in v2 view with consent gating

### T10. Analytics tests
- **Type:** test | **Skill:** qa | **Priority:** high | **Effort:** 0.25d
- **Depends on:** T9
- Write XCTest for each new event (5 tests)
- Verify event name + parameters
- Consent gating test (1 test)
- Screen tracking test (1 test)
- Total: ~7 new tests

## Testing & Review (T11-T14)

### T11. Functional tests
- **Type:** test | **Skill:** qa | **Priority:** high | **Effort:** 0.25d
- **Depends on:** T6, T8
- Test AsyncState transitions (loading → success, loading → error)
- Test supplement toggle state management
- Test date navigation
- Test empty state rendering

### T12. V2 refactor checklist walk
- **Type:** docs | **Skill:** qa | **Priority:** medium | **Effort:** 0.1d
- **Depends on:** T6, T7, T8
- Walk `docs/design-system/v2-refactor-checklist.md` Sections A-K
- Verify all applicable boxes are ticked
- Set `state.json.phases.implementation.checklist_completed = true`

### T13. CI verification
- **Type:** test | **Skill:** dev | **Priority:** critical | **Effort:** 0.1d
- **Depends on:** T10, T11
- Run `make tokens-check` (DS drift check)
- Run `xcodebuild build` (compile)
- Run `xcodebuild test` (full test suite)
- All three must pass

### T14. Design system evolution docs
- **Type:** docs | **Skill:** design | **Priority:** low | **Effort:** 0.1d
- **Depends on:** T1, T2
- Update `docs/design-system/feature-memory.md` with new tokens + ProgressBar component
- Document AppOpacity rationale

---

## Dependency Graph

```
T1 (DS tokens) ──────┬──→ T2 (ProgressBar) ──→ T6 (v2 container) ──→ T7 (pbxproj)
                      ├──→ T3 (StackCard)   ──→ T6                 ──→ T8 (a11y)
                      ├──→ T4 (ItemRow)     ──→ T6                 ──→ T9 (analytics)
T5 (HapticFeedback) ──┘                                            ──→ T10 (tests)
                                                                     ──→ T11 (func tests)
                                                                     ──→ T12 (checklist)
                                                                     ──→ T13 (CI)
T14 (DS docs) — can run in parallel with any task after T1
```

## Parallel Execution Plan

**Wave 1** (parallel): T1, T5, T14
**Wave 2** (parallel, after T1): T2, T3, T4
**Wave 3** (after T2-T5): T6
**Wave 4** (after T6): T7, T8, T9 (parallel)
**Wave 5** (after T8-T9): T10, T11 (parallel)
**Wave 6** (after T10-T11): T12, T13
