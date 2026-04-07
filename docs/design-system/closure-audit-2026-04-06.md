# Design System Closure Audit — 2026-04-06

> **Purpose:** Gate document. ALL items here must be resolved or explicitly deferred before any new UI/UX work proceeds.
> **Sources:** 13 design system docs, all backlog/roadmap/README, all git branches, Notion workspace (10 pages), full Swift codebase scan (78 files, 13,225 lines of View code).

---

## Executive Summary

**Overall Maturity: 75/100** — Architecturally sound, well-governed, but significant cleanup debt in token literals, accessibility, and documentation alignment.

| Dimension | Score | Key Finding |
|-----------|-------|-------------|
| Token Architecture | 95 | 4-layer system complete, CI-gated |
| Color Compliance | 100 | Zero raw color literals in production code |
| Radius Compliance | 100 | All use AppRadius tokens |
| Spacing Compliance | 90 | 9 raw literals remain (off 4pt grid) |
| Typography Compliance | 70 | **41 raw font literals** across 14 files |
| Accessibility | 15 | **27 annotations in 1,600+ lines** (1.6% coverage) |
| Motion/Animation | 100 | All tokenized, reduce-motion respected |
| Dark Mode Tokens | 100 | All semantic, Asset Catalog backed |
| Dark Mode UI Testing | 0 | Never verified on device |
| Dynamic Type | 70 | 27+ fixed-size fonts won't scale |
| Components | 90 | 13 complete, 0 Xcode previews |
| Figma Library | 75 | Foundations + components done, prototype 40% |
| Documentation | 75 | Comprehensive but scattered, Notion stale |

---

## P0 — MUST CLOSE (Gate Blockers)

### 1. Raw Font Literals — 41 violations across 14 files

| File | Count | Examples |
|------|-------|---------|
| TrainingPlanView.swift | 17 | `.font(.headline)`, `.font(.title3)`, `.font(.system(size: 48))` |
| MainScreenView.swift | 9 | `.font(.system(size: tight ? 14 : 16.5, ...))` responsive but raw |
| OnboardingConsentView.swift | 3 | `.font(.system(size: 64))` icon, `.font(.system(size: 18))` |
| ConsentView.swift | 3 | Same pattern as OnboardingConsentView |
| AccountPanelView.swift | 2 | `.font(.title3.weight(.bold))` |
| ReadinessCard.swift | 2 | `.font(.headline)` |
| OnboardingHealthKitView.swift | 1 | `.font(.system(size: 56))` icon |
| OnboardingGoalsView.swift | 1 | `.font(.system(size: 28))` icon |
| OnboardingFirstActionView.swift | 1 | `.font(.system(size: 32))` icon |
| FitMeLogoLoader.swift | 2 | Proportional to size param (acceptable) |

**Action:** Create 3 new AppText tokens for icon sizes + migrate all `.font(.headline)` → `AppText.sectionTitle`, `.font(.title3)` → `AppText.titleMedium`, etc.

### 2. Raw Spacing Literals — 9 violations

| File | Line | Value | Should Be |
|------|------|-------|-----------|
| AppComponents.swift | 213 | `.padding(3)` | `AppSpacing.micro` (2) |
| MainScreenView.swift | 484 | `.padding(.horizontal, 7)` | Off-grid — round to 8 (`AppSpacing.xSmall`) |
| MainScreenView.swift | 910 | `.padding(.vertical, 9)` | Off-grid — round to 8 |
| MainScreenView.swift | 931 | `.padding(.vertical, 10)` | Off-grid — round to 12 (`AppSpacing.small`) |
| AuthHubView.swift | 666 | `.padding(.vertical, 13)` | Off-grid — round to 12 |
| NutritionView.swift | 1073 | `.padding(.horizontal, 54)` | Off-grid — extract as named constant |

**Action:** Replace each with nearest AppSpacing token or add justified exception.

### 3. Token Count Alignment

| Source | Claims | Action |
|--------|--------|--------|
| Notion "Design System v2" page | 92 tokens | Update to 125 |
| Notion "Project Context" page | 92 tokens, DS v2 | Update to 125 |
| README.md | ~120 tokens | Already updated to ~125 in CLAUDE.md |
| `.claude/shared/design-system.json` | 125 tokens | Correct |
| `docs/product/prd/18.10-design-system.md` | 92 vs ~120 noted | Update |
| `CLAUDE.md` | ~125 | Correct |

**Action:** Update Notion pages + PRD to standardize on 125.

---

## P1 — SHOULD CLOSE (Important Quality)

### 4. Accessibility Labels — 1.6% coverage (27 of ~1,600+ interactive elements)

**Current state:** Only design system components (AppPickerChip, AppFilterBar, etc.) and new onboarding views have labels. ALL of these files have zero accessibility:
- TrainingPlanView.swift (50+ interactive elements)
- NutritionView.swift (30+ elements)
- StatsView.swift (20+ elements)
- SettingsView.swift (40+ elements)
- MainScreenView.swift (15+ elements)
- MealEntrySheet.swift (20+ elements)

**Action:** Systematic sweep — add `accessibilityLabel` to all buttons, cards, toggles, pickers. Estimated: 150+ labels needed.

### 5. Dynamic Type — 27+ fixed-size fonts won't scale

All `.font(.system(size: N))` calls bypass Dynamic Type. Users with accessibility text sizes see no change on these elements.

**Action:** Replace fixed sizes with `@ScaledMetric` wrappers or AppText tokens with `.dynamicTypeSize()` support.

### 6. Notion Workspace Stale

Notion pages last updated 2026-04-02. Since then:
- GDPR shipped (Notion says "CRITICAL, no implementation")
- Onboarding implemented (Notion says "no code")
- GA4 shipped (Notion says Phase 2 locked)
- Development Dashboard shipped
- Android DS mapped
- Marketing website shipped
- Parallel task hub built
- 6 commits of design system work

**Action:** Update all Notion pages to match current repo state.

### 7. DesignTokens.swift Out of Sync with AppTheme.swift

- DesignTokens.swift has string representations of colors (not functional)
- AppTheme.swift is the actual source of truth (Asset Catalog references)
- DesignTokens.swift missing: `AppRadius.micro`, `AppRadius.button`, `AppRadius.authSheet`
- Not consumed by any Swift code — purely documentation/Figma sync artifact

**Action:** Regenerate via `make tokens` and verify, or clarify its role.

### 8. Component Previews — Zero Xcode Previews

All 13 design system components lack `#Preview` blocks. Developers can't validate visual correctness in Xcode canvas.

**Action:** Add preview blocks to all components in AppComponents.swift and AppDesignSystemComponents.swift.

---

## P2 — DEFER WITH JUSTIFICATION

### 9. Dark Mode UI Testing
**Status:** Tokens exist and support dark mode via Asset Catalog. UI never verified on device.
**Deferral:** Scheduled for B8 sprint. Not blocking — tokens are correct, visual verification is the gap.

### 10. Patterns Page (Figma) — Shallow
**Status:** Overview frame exists with layout guidance. Missing: component anatomy diagrams, state machines, do/don't examples, accessibility notes per pattern.
**Deferral:** Phase 5 Figma work. Not blocking code — patterns are enforced via feature-design-checklist.md and code review.

### 11. Platform Adaptations — Guidance Only
**Status:** iPhone runtime spec is detailed (375/393/430pt). iPad/macOS minimal. Android mapped but no code. Watch not addressed.
**Deferral:** Android deferred to Gate D. iPad/macOS deferred until user base warrants.

### 12. 14 Missing Figma Prototype Screens
**Status:** Requires manual Figma work (Desktop Bridge or manual). Priority 1-4 screens documented in figma-prototype-audit.md.
**Deferral:** Phase 5. v2 onboarding prompt created for Claude Console.

### 13. Code Connect Mappings
**Status:** Framework documented, zero `.figma.swift` files created.
**Deferral:** Start after component naming stabilizes. Not blocking code development.

### 14. Deprecated AppType Aliases (4 remaining)
**Status:** `AppType.display`, `AppType.headline`, `AppType.body`, `AppType.subheading` still used in older views.
**Deferral:** Migrate during raw font literal cleanup (P0 item 1).

### 15. Unused AppText Tokens (2)
**Status:** `AppText.bodyRegular` and `AppText.footnote` defined but never used.
**Deferral:** Keep for now — may be needed by new views. Remove in next cleanup pass.

---

## Execution Plan

### Sprint A — Token Cleanup (P0, before UI work)
1. Create new AppText tokens for icon sizes: `.iconLarge` (48pt), `.iconHero` (64pt), `.iconDisplay` (72pt)
2. Migrate all 41 raw font literals to AppText tokens
3. Migrate all 9 raw spacing literals to AppSpacing tokens
4. Regenerate DesignTokens.swift
5. Run `make tokens-check` — must pass

### Sprint B — Accessibility (P1, before UI work)
6. Add `accessibilityLabel` to all interactive elements (estimated 150+ labels)
7. Add `@ScaledMetric` wrappers for remaining fixed-size fonts
8. Add `#Preview` blocks to all 13 DS components

### Sprint C — Documentation Alignment (P1, parallel)
9. Update Notion "Design System v2" page (92→125 tokens, shipped status)
10. Update Notion "Project Context" page (GDPR shipped, onboarding implemented, etc.)
11. Update `docs/product/prd/18.10-design-system.md` gap section
12. Standardize token count to 125 across all docs

### Then: Resume UI/UX Work
- Onboarding review phase
- Figma v2 screens (Claude Console prompt ready)
- Product gap closure (food DB, barcode, Google auth)

---

## Verification Checklist

Before any new UI/UX work starts, ALL must be true:

- [ ] Zero raw font literals in production code (excluding FitMeLogoLoader proportional sizing)
- [ ] Zero raw spacing literals off the 4pt grid
- [ ] All interactive elements have `accessibilityLabel`
- [ ] Token count standardized to 125 across README, Notion, PRD, CLAUDE.md
- [ ] `make tokens-check` passes
- [ ] DesignTokens.swift regenerated and in sync
- [ ] Notion workspace updated to match repo state
