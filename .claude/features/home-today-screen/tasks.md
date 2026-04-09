# Home Today Screen v2 — Task Breakdown

> **Phase:** 2 (Tasks)
> **Source:** `.claude/features/home-today-screen/prd.md` (22 P0+P1 findings)
> **Branch:** `feature/home-today-screen-v2`

---

## Dependency graph

```
T1 (new tokens) ─────────────────────────┐
T2 (new motion tokens) ──────────────────┤
T3 (new chart colors) ───────────────────┤
                                          ├──→ T8 (v2 MainScreenView) ──→ T12 (pbxproj swap)
T4 (AppMetricColumn component) ──────────┤                                      │
T5 (AppMetricTile component) ────────────┤                                      ├──→ T14 (v2 refactor checklist)
T6 (HomeRecommendationProvider) ─────────┤                                      │
T7 (analytics enums) ────────────────────┘                                      ├──→ T15 (behavior tests)
                                                                                ├──→ T16 (snapshot tests)
T9 (LiveInfoStrip static) ── independent ──→ consumed by T8                     ├──→ T17 (analytics tests)
T10 (empty state view) ── independent ──→ consumed by T8                        │
T11 (a11y pass) ── depends on T8 ──────────────────────────────────────────────┘
T13 (v1 HISTORICAL header) ── depends on T12
```

---

## Tasks

### Foundation layer (no dependencies — can run in parallel)

#### T1 — Add new AppText + AppSize tokens to AppTheme.swift
- **Type:** design
- **Skill:** design
- **Priority:** critical
- **Effort:** 0.25 days
- **Depends on:** —
- **Details:**
  - Verify existing `metricHero`/`metricDisplay` vs proposed `metricL`/`metricM` — if they match the audit's size requirements, alias or reuse; if not, add new tokens
  - Add `AppText.iconXL` (~32pt medium) if not covered by existing `iconHero`/`iconDisplay`
  - Add `AppSize.indicatorDot` (8pt CGFloat)
  - All new font tokens must use `Font.custom("SF Pro Rounded", size: N, relativeTo: .largeTitle)` for Dynamic Type scaling
  - **Findings addressed:** F5, F7, F19

#### T2 — Add motion tokens (AppSpring, AppEasing)
- **Type:** design
- **Skill:** design
- **Priority:** high
- **Effort:** 0.25 days
- **Depends on:** —
- **Details:**
  - Current state: only `AppMotion.stepTransition` and `AppMotion.quickInteraction` exist
  - Add `AppSpring.snappy` (maps to v1's `.spring(response: 0.32, ...)`)
  - Add `AppEasing.short` (maps to v1's `.easeOut(duration: 0.22)`)
  - Add a `motionSafe` ViewModifier or environment wrapper for reduce-motion checks
  - **Findings addressed:** F21, F22

#### T3 — Add AppColor.Chart tokens
- **Type:** design
- **Skill:** design
- **Priority:** high
- **Effort:** 0.15 days
- **Depends on:** —
- **Details:**
  - Existing: `Chart.body`, `Chart.cardio`, `Chart.sleep`, `Chart.achievement`, `Chart.progress`, `Chart.nutritionFat`
  - Add: `Chart.weight`, `Chart.hrv`, `Chart.heartRate` (verify if already exists under different name), `Chart.activity`
  - Values TBD — use semantic color names mapping to asset catalog or AppTheme computed properties
  - **Findings addressed:** F8

#### T4 — Create AppMetricColumn component
- **Type:** ui
- **Skill:** design
- **Priority:** high
- **Effort:** 0.5 days
- **Depends on:** —
- **Details:**
  - Promote from `MainScreenView:468-512` (`statusValueColumn` private helper)
  - Pattern: icon + title, value + unit, target line, missing-state capsule
  - Add to `FitTracker/DesignSystem/AppComponents.swift`
  - Support empty state variant (tappable "Log" CTA instead of `—` dash)
  - Use `AppText.*`, `AppSpacing.*`, `AppColor.*` tokens throughout
  - Accessibility: `.accessibilityLabel`, `.accessibilityValue` with units
  - **Findings addressed:** F26, F16 (empty state)

#### T5 — Create AppMetricTile component
- **Type:** ui
- **Skill:** design
- **Priority:** high
- **Effort:** 0.5 days
- **Depends on:** —
- **Details:**
  - Promote from `MainScreenView:538-555` (`metricTile` private helper)
  - Pattern: icon + value + label (generic metric display)
  - Add to `FitTracker/DesignSystem/AppComponents.swift`
  - Support empty state variant (tappable "Log" CTA)
  - Support chart color tinting via the new `AppColor.Chart.*` tokens
  - Read-only in Home v2 (no tap handler — deep-link deferred)
  - Accessibility: `.accessibilityLabel`, `.accessibilityValue`, `.accessibilityHint`
  - **Findings addressed:** F26, F16 (empty state)

#### T6 — Create HomeRecommendationProvider service
- **Type:** backend
- **Skill:** dev
- **Priority:** high
- **Effort:** 0.75 days
- **Depends on:** —
- **Details:**
  - New file: `FitTracker/Services/HomeRecommendationProvider.swift`
  - Extract recommendation logic from `MainScreenView.swift` (~50 lines)
  - Input: readiness data (HRV, RHR, sleep quality, recovery score)
  - Output: `HomeRecommendation` struct with: `tone` (encouraging/cautious/celebratory), `title` (string), `subtitle` (string), `accentColor` (Color)
  - Copy follows Celebration Not Guilt principle (ux-foundations §1.13)
  - Pure function, easily testable
  - **Findings addressed:** F27, F14 (guilt-adjacent copy)

#### T7 — Add analytics event/param/screen enums
- **Type:** analytics
- **Skill:** analytics
- **Priority:** high
- **Effort:** 0.25 days
- **Depends on:** —
- **Details:**
  - Add to `AnalyticsEvent`: `homeActionTap`, `homeActionCompleted`, `homeEmptyStateShown`
  - Add to `AnalyticsParam`: `actionType`, `hasRecommendation`, `emptyReason`, `ctaShown`
  - Verify `AnalyticsScreen.home` already exists (it does)
  - Add typed convenience methods to `AnalyticsService.swift`
  - Update `docs/product/analytics-taxonomy.csv` with new event rows
  - **Findings addressed:** F24, F25 (partial)

### Parallel independent tasks

#### T9 — Make LiveInfoStrip static (no auto-rotation)
- **Type:** ui
- **Skill:** dev
- **Priority:** high
- **Effort:** 0.5 days
- **Depends on:** —
- **Details:**
  - Modify `FitTracker/Views/Shared/LiveInfoStrip.swift`
  - Remove 5-second auto-cycling timer
  - Implement priority resolution: greeting + streak (concat) > greeting alone > streak alone
  - Format: `"Good morning, Regev · 3-day streak 🔥"`
  - Streak threshold stays at `≥3 days`
  - Graceful truncation on smaller widths
  - Add proper `.accessibilityLabel` for the static content
  - **Findings addressed:** F20

#### T10 — Create empty state view for Home
- **Type:** ui
- **Skill:** dev
- **Priority:** critical
- **Effort:** 0.5 days
- **Depends on:** —
- **Details:**
  - New view or ViewModifier for Home's empty state
  - Single message with two buttons: "Connect Health" + "Log manually"
  - When HealthKit denied: "Connect Health" deep-links to Settings → Privacy → Health → FitMe
  - Use `AppCard` for container, `AppButton` for CTAs
  - Fire `home_empty_state_shown` event (needs T7 for enum, but view can be built independently)
  - **Findings addressed:** F15, F16

### Main assembly (depends on foundation layer)

#### T8 — Build v2 MainScreenView.swift
- **Type:** ui
- **Skill:** dev
- **Priority:** critical
- **Effort:** 3 days
- **Depends on:** T1, T2, T3, T4, T5, T6, T7, T9, T10
- **Details:**
  - Create `FitTracker/Views/Main/v2/MainScreenView.swift`
  - Build bottom-up from design system — DO NOT patch v1
  - Stack order: Toolbar → Greeting (LiveInfoStrip) → ReadinessCard → Training & Nutrition → Status → Goal → Metrics
  - `ScrollView` with `scrollBounceBehavior(.basedOnSize)` — no GeometryReader
  - No `compact`/`tight` props — Dynamic Type + AppSpacing handles sizing
  - Use `@Environment(\.horizontalSizeClass)` + `@Environment(\.verticalSizeClass)` for device class
  - Training & Nutrition card: side-by-side equal CTAs (Start Workout + Log Meal), single context line
  - ReadinessCard promoted to first card (existing component)
  - Status + Goal as separate cards (v1 layout ported with new tokens + a11y)
  - Metrics row: 4 `AppMetricTile` instances (HRV, RHR, Sleep, Steps), read-only
  - Use `AppCard` instead of `BlendedSectionStyle`
  - Consume `HomeRecommendationProvider` for recommendation display
  - All animations via `AppSpring.*`/`AppEasing.*` + reduce-motion wrapped
  - 5 explicit states: default, loading, empty (T10), error, success
  - `.analyticsScreen(AnalyticsScreen.home)` in view body
  - Fire `home_action_tap` on CTA taps, `home_empty_state_shown` on empty state
  - **Findings addressed:** F1, F2, F3, F4, F5, F6, F7, F8, F9, F10, F11, F12, F15, F22, F24

#### T11 — Accessibility pass on v2 view
- **Type:** ui
- **Skill:** dev
- **Priority:** critical
- **Effort:** 0.75 days
- **Depends on:** T8
- **Details:**
  - Add `.accessibilityLabel` to every interactive element (~30+)
  - Add `.accessibilityHint` to every non-trivial action
  - Add `.accessibilityValue` with units to every metric tile
  - Add `.accessibilityAddTraits(.isHeader)` to every section eyebrow
  - Ensure all tap targets ≥44pt (edit button was 34pt in v1)
  - Test with VoiceOver mentally (actual VoiceOver test in Phase 5)
  - **Findings addressed:** F17, F18

### Project file surgery (depends on T8)

#### T12 — Update project.pbxproj (v2 swap)
- **Type:** infra
- **Skill:** dev
- **Priority:** critical
- **Effort:** 0.25 days
- **Depends on:** T8
- **Details:**
  - Add PBXGroup for `FitTracker/Views/Main/v2/`
  - Add PBXFileReference for `v2/MainScreenView.swift`
  - Add PBXBuildFile referencing the v2 file
  - Add PBXBuildFile to Sources build phase
  - Remove v1 `MainScreenView.swift` PBXBuildFile from Sources build phase
  - Keep v1 PBXFileReference (shows in navigator, reviewable in git)
  - Remove `.analyticsScreen` for Home from `RootTabView.swift` (moved into v2)
  - Verify build: `xcodebuild build`

#### T13 — Mark v1 as HISTORICAL
- **Type:** docs
- **Skill:** dev
- **Priority:** medium
- **Effort:** 0.1 days
- **Depends on:** T12
- **Details:**
  - Add header comment to `FitTracker/Views/Main/MainScreenView.swift`:
    ```swift
    // HISTORICAL — superseded by v2/MainScreenView.swift on {date} per
    // UX Foundations alignment pass. See
    // .claude/features/home-today-screen/v2-audit-report.md for the gap analysis.
    // This file is no longer in the build target; it stays in the repo
    // as a reviewable reference for the v1 → v2 diff.
    ```

### Verification layer (depends on T8 + T12)

#### T14 — Walk v2 refactor checklist
- **Type:** test
- **Skill:** qa
- **Priority:** critical
- **Effort:** 0.5 days
- **Depends on:** T8, T11, T12
- **Details:**
  - Walk through `docs/design-system/v2-refactor-checklist.md` Sections A-K
  - Verify: token compliance, component reuse, state coverage, a11y, motion, analytics, pbxproj hygiene
  - Set `state.json.phases.ux_or_integration.checklist_completed = true`
  - Document any gaps found

#### T15 — Write behavior tests for HomeRecommendationProvider
- **Type:** test
- **Skill:** qa
- **Priority:** high
- **Effort:** 0.5 days
- **Depends on:** T6
- **Details:**
  - New test file or add to existing test target
  - Test all readiness levels → recommendation mapping
  - Test edge cases: nil readiness data, extreme values
  - Test copy output matches Celebration Not Guilt principle
  - Verify pure function behavior (no side effects)

#### T16 — Write snapshot tests for v2 view states
- **Type:** test
- **Skill:** qa
- **Priority:** high
- **Effort:** 0.75 days
- **Depends on:** T8, T12
- **Details:**
  - 5 state snapshots: default, loading, empty, error, success
  - Test across device sizes: iPhone SE, iPhone 15, iPhone 15 Pro Max
  - Test Dynamic Type at default and AX5
  - Test reduce-motion variant

#### T17 — Write analytics tests
- **Type:** test
- **Skill:** analytics
- **Priority:** high
- **Effort:** 0.5 days
- **Depends on:** T7, T8
- **Details:**
  - Per PRD Analytics Spec:
    - `home_action_tap` fires with correct `action_type`, `day_type`, `has_recommendation`
    - `home_action_completed` fires with `action_type`, `duration_seconds`, `source`
    - `home_empty_state_shown` fires with `empty_reason`, `cta_shown`
  - Screen tracking: `.analyticsScreen(.home)` fires in v2 view
  - Consent gating: events blocked when consent denied
  - Taxonomy sync: all enums have CSV rows

---

## Summary

| Category | Tasks | Effort |
|----------|-------|--------|
| Foundation (parallel) | T1-T7, T9, T10 | 3.65 days |
| Assembly | T8 | 3 days |
| A11y + project surgery | T11, T12, T13 | 1.1 days |
| Verification | T14, T15, T16, T17 | 2.25 days |
| **Total** | **17 tasks** | **~10 days** |

**Critical path:** T1+T2+T3+T4+T5+T6+T7 (parallel, 0.75d) → T8 (3d) → T11+T12 (parallel, 0.75d) → T14 (0.5d)
**Effective duration with parallelism:** ~5 days

**Parallel execution opportunities:**
- T1, T2, T3, T4, T5, T6, T7, T9, T10 can ALL run in parallel (foundation layer)
- T11 and T12 can run in parallel after T8
- T15 can start as soon as T6 is done (before T8)
- T16 and T17 can run in parallel after T8+T12
