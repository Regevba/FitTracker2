# Nutrition v2 — UX Foundations Audit Report

> **Date:** 2026-04-10
> **File:** `FitTracker/Views/Nutrition/NutritionView.swift` (1,106 lines)
> **Audited against:** `docs/design-system/ux-foundations.md` (13 principles)
> **Phase:** 0 (Research — v2 refactor audit)

---

## Audit Summary

| Severity | Count | Category |
|----------|-------|----------|
| P0 | 6 | Raw animations (5 instances), hardcoded touch targets, magic padding |
| P1 | 5 | Raw colors, raw fonts, opacity drift, component extraction |
| P2 | 12 | Accessibility gaps (7), state coverage (1), nested type extraction (3), duplicate a11y label (1) |
| **Total** | **23** | |

### Compliance Scorecard

| Dimension | Score | Notes |
|-----------|-------|-------|
| Font tokens | 97% | 3 raw fonts out of ~80+ font usages — excellent baseline |
| Spacing tokens | 98% | 2 raw padding values (54pt magic number) — near-perfect |
| Color tokens | 92% | 6 raw color usages (Color.status.success, Color.orange, Color.accent.cyan) |
| Radius tokens | 100% | All corner radii use design system tokens |
| Motion tokens | 0% | 7 raw animations — worst dimension |
| Accessibility | 47% | 7 of 15 interactive elements have labels |
| State coverage | Partial | No explicit loading/error states |
| Component reuse | Good | Uses AppText, AppColor, AppSpacing extensively |

---

## P0 Findings (6)

### F1. Raw Animations — easeInOut literals (5 instances)
- **Lines:** 583, 750, 767, 958, 1060
- **Violation:** `withAnimation(.easeInOut(duration: 0.25))` and `.animation(.easeInOut(duration: 0.2))` used instead of AppMotion/AppEasing tokens
- **Principle:** #8 (Micro-Interactions & Motion)
- **Tractability:** auto
- **Fix:** Replace with `AppMotion.quickInteraction` or `AppEasing.short`

### F2. Raw Spring Animations (2 instances)
- **Lines:** 374, 979
- **Violation:** `.animation(.spring(response: 0.6))` and `.spring(response: 0.5)` — custom spring without AppSpring token
- **Principle:** #8 (Micro-Interactions & Motion)
- **Tractability:** decision — use `AppSpring.smooth` or define new `AppSpring.progress` token?
- **Fix:** Map to AppSpring preset or propose new token

### F3. Hardcoded Touch Targets (44pt instead of 48pt)
- **Lines:** 224, 250
- **Violation:** `.frame(width: 44, height: 44)` for date navigation chevrons. AppSize.touchTargetLarge = 48pt
- **Principle:** #1 (Fitts's Law)
- **Tractability:** auto
- **Fix:** `.frame(width: AppSize.touchTargetLarge, height: AppSize.touchTargetLarge)`

### F4. Hardcoded Checkbox Size
- **Line:** 1031
- **Violation:** `.frame(width: 26, height: 26)` — correct size but not tokenized
- **Tractability:** auto
- **Fix:** Use `AppSize.iconBadge` (26pt)

### F5. Magic Number Padding (54pt)
- **Lines:** 994, 1085
- **Violation:** `.padding(.horizontal, 54)` — undocumented indent calculation
- **Tractability:** auto — create `AppSpacing.supplementDetailIndent`
- **Fix:** Extract to semantic spacing token

### F6. GeometryReader Without Responsive Contract
- **Lines:** 367, 523, 971
- **Violation:** Three GeometryReader usages for progress bars without documented responsive contracts
- **Principle:** #10 (Platform-Specific Patterns)
- **Tractability:** decision — document the responsive contract inline

---

## P1 Findings (5)

### F7. Raw Color Literals (6 instances)
- **Lines:** 275, 314, 560, 673, 716, 743
- **Violation:** `Color.status.success` (5x) and `Color.orange` (1x) instead of `AppColor.Status.success` and semantic orange
- **Tractability:** auto
- **Fix:** Replace with AppColor.Status.success and AppColor.Chart.achievement

### F8. Unmapped Accent Color
- **Line:** 323
- **Violation:** `Color.accent.cyan` — no direct AppColor equivalent
- **Tractability:** decision — map to `AppColor.Accent.recovery` or define new token?

### F9. Raw Font Literals (3 instances)
- **Lines:** 670, 713, 742
- **Violation:** `.caption2.weight(.bold)` and `.caption.weight(.semibold)` instead of AppText tokens
- **Tractability:** auto
- **Fix:** Replace with `AppText.captionStrong`

### F10. Magic Opacity Values (6 instances)
- **Lines:** 370, 526, 546, 678, 722, 746
- **Violation:** `.opacity(0.15)`, `.opacity(0.14)`, `.opacity(0.12)` — no semantic meaning
- **Tractability:** new-token — propose `AppOpacity.disabled`, `AppOpacity.subtle`

### F11. Duplicate Status Button Logic
- **Lines:** 650-734
- **Violation:** Morning/Evening supplement pill buttons share identical structure — extract to component
- **Tractability:** new-component — `SupplementPillButton`

---

## P2 Findings (12)

### F12-F18. Accessibility Gaps (7 findings)
| # | Lines | Issue | Fix |
|---|-------|-------|-----|
| F12 | 664-691 | Missing a11y on Morning pill button | Add .accessibilityLabel/.accessibilityHint |
| F13 | 707-734 | Missing a11y on Evening pill button | Same |
| F14 | 422 | Missing a11y on empty state icon | Add .accessibilityLabel("No meals logged") |
| F15 | 350, 352 | Duplicate .accessibilityLabel (conflict) | Remove duplicate |
| F16 | 523-533 | Missing .accessibilityValue on hydration bar | Add value with ml progress |
| F17 | 367-377 | Missing .accessibilityValue on adherence bar | Add value with percentage |
| F18 | 971-981 | Missing .accessibilityValue on stack progress | Add value with taken/total |

### F19. Missing Loading/Error States
- **Lines:** 810-818 (loadLog function)
- **Violation:** No explicit loading spinner or error state when data loads
- **Principle:** #6 (State Patterns)
- **Tractability:** decision — add AsyncState enum with loading/error/success

### F20-F22. Nested Type Extraction (3 findings)
| # | Lines | Type | Extract To |
|---|-------|------|-----------|
| F20 | 928-1005 | SupplementStackCard | Views/Nutrition/Components/ |
| F21 | 1011-1092 | SupplementItemRow | Views/Nutrition/Components/ |
| F22 | 1098-1106 | HapticFeedback | Services/HapticFeedback.swift |

### F23. Missing Meal Entry Accessibility
- **Lines:** 436-469
- **Violation:** Meal row buttons lack grouped a11y element
- **Fix:** Add .accessibilityElement(children: .combine) with label + value

---

## Decisions Required (User)

| # | Finding | Question | Options |
|---|---------|----------|---------|
| Q1 | F2 | Spring animation tokens for progress bars | **B) Create `AppSpring.progress`** — new DS token |
| Q2 | F6 | GeometryReader documentation | **B) Extract to reusable `ProgressBar` component** |
| Q3 | F8 | Color.accent.cyan mapping | **B) Create `AppColor.Accent.nutrition`** — new DS token |
| Q4 | F10 | Opacity tokens | **A) Create `AppOpacity` enum** (disabled/subtle/hover) |
| Q5 | F19 | Loading/error states | **A) Full `AsyncState` enum** with loading/error/success |

---

## Cross-Screen Patterns (from cache)

From L2 cache `_shared/ux-foundations-map.json`:
- Token mapping: reuse Home v2 + Training v2 patterns for AppColor, AppSpacing, AppText
- Component reuse: AppCard, SectionHeader already available
- Anti-patterns: avoid raw color literals (P0 in Home v2 audit F1), avoid GeometryReader at root (not present here)
- Speedup: font + spacing compliance is already excellent — focus effort on motion tokens + a11y
