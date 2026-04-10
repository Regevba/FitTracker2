# Nutrition v2 — PRD (UX Foundations Alignment)

> **Type:** Feature (v2_refactor)
> **Phase:** 1 (PRD)
> **Parent:** NutritionView.swift (1,106 lines)
> **Audit:** 23 findings (6 P0, 5 P1, 12 P2)

---

## 1. Problem Statement

NutritionView.swift is the 2nd highest-priority screen for UX Foundations alignment (after Training Plan v2, now complete). The view has excellent token compliance for fonts (97%) and spacing (98%) but fails on motion tokens (0% compliance), accessibility (47% element coverage), and lacks explicit loading/error states.

**User impact:** Missing accessibility labels exclude VoiceOver users from supplement tracking. Raw animations create inconsistent motion language across the app. No loading/error states leave users without feedback during data operations.

## 2. Solution

Apply UX Foundations alignment via the v2 refactor convention:
- Build `Views/Nutrition/v2/NutritionView.swift` bottom-up from design system foundations
- Fix all 23 audit findings (6 P0, 5 P1, 12 P2)
- Introduce 4 new design system tokens (AppSpring.progress, AppColor.Accent.nutrition, AppOpacity enum, AppSpacing.supplementDetailIndent)
- Extract 1 new reusable component (ProgressBar)
- Extract 2 nested types to separate files (SupplementStackCard, SupplementItemRow)
- Add full AsyncState loading/error/success state coverage
- Achieve 90%+ accessibility label coverage (from 47%)

## 3. Success Metrics

### Primary Metric
- **Name:** Nutrition screen VoiceOver element coverage
- **Baseline:** 47% (7/15 interactive elements labeled)
- **Target:** 90%+ (14/15+)
- **Kill criteria:** If accessibility coverage drops below 80% after merge

### Secondary Metrics
- Design system token compliance: 0% motion → 100%, 92% color → 100%, 97% font → 100%
- Component extraction: 1,106 lines → container ~400 lines + 3 extracted components
- State coverage: 3/5 states → 5/5 (add loading + error)

### Guardrails (must not degrade)
- Crash-free rate > 99.5%
- Cold start < 2s
- Existing nutrition_meal_logged and nutrition_supplement_logged events continue firing
- No regression in existing analytics tests

### Instrumentation Plan
- 5 new analytics events with `nutrition_` prefix
- Consent gating verified for all new events
- Review cadence: 7 days post-merge

## 4. Analytics Spec (GA4 Event Definitions)

### New Events

| Event Name | Category | GA4 Type | Screen | Param 1 | Param 2 | Param 3 | Conversion | Notes |
|-----------|----------|----------|--------|---------|---------|---------|-----------|-------|
| nutrition_meal_logged | Nutrition | Custom | Meal Entry | meal_type (breakfast/lunch/dinner/snack) | entry_method (manual/template) | calories (int) | Yes | Replaces `meal_log` with screen prefix |
| nutrition_supplement_logged | Nutrition | Custom | Supplement Tracker | time_of_day (morning/evening) | supplement_count (int) | | No | Replaces `supplement_log` with screen prefix |
| nutrition_hydration_updated | Nutrition | Custom | Hydration Section | water_ml (int) | target_ml (int) | | No | New — tracks water logging |
| nutrition_date_changed | Nutrition | Custom | Date Picker | direction (forward/backward) | | | No | New — tracks date navigation |
| nutrition_empty_state_shown | Nutrition | Custom | Empty State | section (meals/supplements/hydration) | | | No | New — tracks empty state visibility |

### Event Migration

| Old Event | New Event | Strategy |
|-----------|-----------|----------|
| meal_log | nutrition_meal_logged | GA4 event alias preserves old dashboards. New code fires new name. |
| supplement_log | nutrition_supplement_logged | Same strategy. |

### Naming Validation Checklist

- [x] All events use snake_case, lowercase only
- [x] All events ≤ 40 characters
- [x] No reserved prefixes (ga_, firebase_, google_)
- [x] No duplicates against existing AnalyticsProvider.swift enums
- [x] No PII in any parameter
- [x] All parameter values ≤ 100 characters
- [x] All events ≤ 25 parameters
- [x] Total custom user properties still ≤ 25
- [x] Screen-scoped events use `nutrition_` prefix per CLAUDE.md rule
- [x] GA4 recommended events keep their dictated names (none applicable here)

## 5. Design System Evolution (from audit decisions)

### New Tokens
| Token | Value | Reason |
|-------|-------|--------|
| `AppSpring.progress` | `Animation.spring(response: 0.55, dampingFraction: 0.80)` | Progress bar animations need a softer, slower spring than UI interactions |
| `AppColor.Accent.nutrition` | Cyan-tinted accent (TBD in Phase 3) | Nutrition-specific accent distinct from recovery |
| `AppOpacity.disabled` | `0.15` | Semantic opacity for disabled/inactive states |
| `AppOpacity.subtle` | `0.12` | Semantic opacity for subtle backgrounds |
| `AppOpacity.hover` | `0.08` | Semantic opacity for hover/focus states |
| `AppSpacing.supplementDetailIndent` | `54` | Semantic indent for supplement detail rows |

### New Components
| Component | Location | Reusability |
|-----------|----------|-------------|
| `ProgressBar` | `DesignSystem/ProgressBar.swift` | Used by Nutrition (3x), potential use in Training, Stats |
| `SupplementPillButton` | `Views/Nutrition/Components/` | Nutrition-specific |

### Extracted Types
| Type | From | To |
|------|------|-----|
| SupplementStackCard | NutritionView.swift L928-1005 | Views/Nutrition/Components/SupplementStackCard.swift |
| SupplementItemRow | NutritionView.swift L1011-1092 | Views/Nutrition/Components/SupplementItemRow.swift |
| HapticFeedback | NutritionView.swift L1098-1106 | Services/HapticFeedback.swift |

## 6. Scope

### In Scope
- All 23 audit findings
- 4 new DS tokens + 2 new components
- 3 type extractions
- 5 new analytics events (screen-prefixed)
- Full AsyncState loading/error/success
- VoiceOver label coverage from 47% → 90%+

### Out of Scope
- Food database integration (OpenFoodFacts) — separate feature
- Barcode scanning — separate feature
- Photo-based food logging — separate feature
- Meal timing analysis — separate feature
