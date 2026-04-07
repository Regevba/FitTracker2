# Onboarding v2 — UX + Design Audit Report

> Date: 2026-04-07
> Branch: feature/onboarding-ux-align
> Auditor: in-session audit (pm-workflow Phase 3a)
> Status: v1 shipped, v2 alignment in progress

## Executive Summary

- **Files audited:** 8 Swift views (907 lines total)
- **Overall state:** Significantly better than expected. Most tokens are applied; architecture is consistent in 90%+ of the code.
- **Total findings:** 24 (P0: 6, P1: 11, P2: 7)
- **Recommended action:** PATCH (no rebuilds needed). All findings are tractable targeted edits.
- **High-risk files touched:** 0 beyond the existing FitTrackerApp.swift

## Files Audited

| File | Lines | Status |
|------|-------|--------|
| OnboardingView.swift | 110 | 6-step container with Consent as step 4 |
| OnboardingWelcomeView.swift | 62 | Brand gradient hero |
| OnboardingGoalsView.swift | 134 | 2x2 goal grid |
| OnboardingProfileView.swift | 173 | Experience + frequency |
| OnboardingHealthKitView.swift | 131 | Permission priming |
| OnboardingConsentView.swift | 115 | GDPR analytics consent |
| OnboardingFirstActionView.swift | 116 | Workout or meal choice |
| OnboardingProgressBar.swift | 66 | 6-segment bar |

## Part A — UX Foundations Compliance

### Part 1: Design Philosophy & Principles

| Principle | Status | Finding | Priority |
|-----------|--------|---------|----------|
| Fitts's Law | Pass | 52pt CTAs, 48pt frequency circles | — |
| Hick's Law | Pass | 4 goals, 3 experience, 5 frequency | — |
| Jakob's Law | Warn | No back navigation violates expectation | P1 |
| Progressive Disclosure | Pass | One decision per screen | — |
| Recognition over Recall | **Fail** | No back navigation means users can't verify earlier selections | **P0** |
| Consistency | Warn | Screen tracking uses enum in 2 files, strings in 4 | P1 |
| Feedback | **Fail** | No haptic feedback on any selection | **P0** |
| Error Prevention | **Fail** | Skip silently applies defaults; HealthKit result swallowed | **P0** |

### Part 2: Information Architecture — Pass (flat 6-screen sequence)

### Part 3: Interaction Patterns

| Check | Status | Finding |
|-------|--------|---------|
| Navigation | Pass | TabView paging, swipe disabled |
| Input patterns | Pass | Tappable cards + circles |
| Feedback — visual | Pass | Selection state via border + color |
| Feedback — haptic | **Fail** | No sensoryFeedback anywhere — P0 |
| Animation | Warn | Raw `.easeInOut(duration: 0.3)` literals — P1 |

### Part 5: Permission & Trust

| Check | Status | Finding |
|-------|--------|---------|
| HealthKit 3-step priming | Pass | Explanation → data types → prompt |
| Consent trust signals | Pass | Clear yes/no list, change-anytime footer |
| HealthKit result handling | **Fail** | `try?` discards result; no telemetry — P0 |
| `permission_result` analytics | **Fail** | PRD spec requires event; code never fires — P0 |

### Part 6: State Patterns

| Check | Status | Finding |
|-------|--------|---------|
| Loading states | Warn | HealthKit request async but no button loader — P1 |
| Error states | Fail | HealthKit denial has no user feedback — P1 |

### Part 7: Accessibility

| Check | Status | Finding |
|-------|--------|---------|
| Tap targets ≥44pt | Pass | All CTAs 52pt, circles 48pt |
| Dynamic Type | **Fail** | No ScrollView on 5 screens — content overflows at large text — P1 |
| VoiceOver labels | Pass | Present on selection cards |
| VoiceOver traits | Pass | isSelected applied |
| VoiceOver grouping | Pass | container uses accessibilityElement(children: .contain) |

### Part 8: Motion

| Check | Status | Finding |
|-------|--------|---------|
| AppMotion presets | Fail | Raw `.easeInOut(duration: 0.3)` in OnboardingView:56,70 — P1 |
| Reduce Motion | Partial | ProgressBar respects it; OnboardingView does not — P1 |

### Part 9: Content — Warn (terminology drift; "Ready to maintain?" weak)

### Part 10: Platform — Warn (no iPad fallback on HealthKit screen)

## Part B — Design System Compliance

### B1: Token Violations

| File:Line | Violation | Current | Should Be |
|-----------|-----------|---------|-----------|
| WelcomeView:39 | Raw height | `.frame(height: 52)` | `AppSize.ctaHeight` (new) |
| WelcomeView:42 | Raw shadow | `.shadow(color: .black.opacity(0.12), radius: 8, y: 4)` | `AppShadow.cta*` |
| ConsentView:31 | Raw frame | `.frame(width: 26, height: 26)` | `AppSize.iconBadge` (new) |
| ConsentView:73 | Raw color | `.foregroundStyle(.white)` | `AppColor.Text.inversePrimary` |
| ConsentView:75 | Raw height | `.frame(height: 52)` | `AppSize.ctaHeight` |
| OnboardingView:56 | Raw anim | `.easeInOut(duration: 0.3)` | `AppMotion.stepTransition` |
| OnboardingView:70 | Raw anim | same | same |
| ProfileView:145 | Raw frame | `.frame(width: 48, height: 48)` | `AppSize.touchTargetLarge` |
| ProgressBar:27 | Raw height | `.frame(height: 4)` | `AppSize.progressBarHeight` |

**New tokens proposed:** AppSize.ctaHeight (52), touchTargetLarge (48), iconBadge (26), progressBarHeight (4), AppMotion.stepTransition (easeInOut 0.3). Per CLAUDE.md evolution rules.

### B2: Component Reuse Gaps

| Screen | Private struct | Could use |
|--------|-----------------|-----------|
| Goals | GoalCard | AppSelectionTile (exists) |
| Profile | ExperienceCard | AppSelectionTile variant |
| Profile | FrequencyCircle | new AppSelectionCircle |
| FirstAction | FirstActionCard | AppSelectionTile (large variant) |
| HealthKit | HealthDataRow | AppMenuRow or new AppDataRow |

All P2. Don't block v2 merge.

### B3: Pattern Consistency

- CTA buttons: Good (all use AppGradient.brand + AppRadius.button + shadow tokens)
- Skip buttons: Good (quiet pattern consistent)
- Card surfaces: Good
- Screen tracking: **Poor** — 2 files use enum, 4 use string literals — P1

## Analytics Gaps vs PRD v1 Spec

**Events PRD specified but v1 code never fires:**

| Event | File | Priority |
|-------|------|----------|
| `permission_result` | HealthKitView:52 — result discarded | **P0** |
| `onboarding_step_viewed` | No screen fires it | **P0** |
| `onboarding_skipped` | Skip callbacks don't log | **P0** |
| `onboarding_goal_selected` | GoalCard action only updates state | P1 |

These are the critical findings — PRD spec gaps hidden by the "UX phase skipped" bucket.

## Recommended Actions (delta plan seeds for V2-T7)

### P0 (blocks v2 merge — 6 items)

- **P0-01** Fire `permission_result` in HealthKitView after HK authorization with `granted` bool
- **P0-02** Fire `onboarding_step_viewed` on each screen's `.onAppear`
- **P0-03** Fire `onboarding_skipped` in Skip callbacks (move wrapping to OnboardingView)
- **P0-04** Fire `onboarding_goal_selected` in GoalCard action
- **P0-05** Add `.sensoryFeedback(.selection, trigger: ...)` to Goals/Profile/HealthKit/FirstAction [MANUAL GATE]
- **P0-06** Add Back button to OnboardingView on steps 1-5 [MANUAL GATE]

### P1 (must fix before ship — 11 items)

- **P1-01** Replace string literals with AnalyticsScreen enum in 4 files
- **P1-02** Introduce AppMotion.stepTransition token + apply
- **P1-03** Introduce AppSize.ctaHeight token + apply
- **P1-04** Use AppShadow.cta tokens on Welcome CTA shadow
- **P1-05** Replace `.white` with `AppColor.Text.inversePrimary` in Consent
- **P1-06** Wrap 5 screens in ScrollView for Dynamic Type [MANUAL GATE]
- **P1-07** Loading indicator on HealthKit "Connect Health" while awaiting [MANUAL GATE]
- **P1-08** HealthKit denial feedback (toast/alert) [MANUAL GATE]
- **P1-09** Reduce Motion check in OnboardingView animation
- **P1-10** iPad fallback copy on HealthKit screen [MANUAL GATE]
- **P1-11** Skip transparency — "You can set this later in Settings." [MANUAL GATE]

### P2 (defer to follow-up — 7 items)

- **P2-01** Consolidate private card structs into AppSelectionTile variants
- **P2-02** New size tokens (touchTargetLarge, iconBadge, progressBarHeight)
- **P2-03** Terminology: pick "Apple Health" everywhere [MANUAL GATE]
- **P2-04** "Ready to maintain?" → "Ready to stay on track?" [MANUAL GATE]
- **P2-05** Add accessibilityHint to selection cards
- **P2-06** Contrast check on Welcome caption [MANUAL GATE]
- **P2-07** Welcome pillars text size 13→15 [MANUAL GATE]

## Manual Confirm Gate Rounds

Items requiring manual approval (11):
P0-05, P0-06, P1-06, P1-07, P1-08, P1-10, P1-11, P2-03, P2-04, P2-06, P2-07

Items auto-applicable (13 — token cleanups + analytics gap fixes).

## Recommendation

**PATCH, not rebuild.** Budget: ~0.75 day mechanical edits + 0.25 day manual confirm UI changes = 1 day total.

**Execution order:**
1. Round 1 (auto): Analytics gap fixes P0-01 through P0-04
2. Round 2 (auto): Token cleanups P1-01 through P1-05, P1-09, P2-02
3. Round 3 (manual): P0-05, P0-06, P1-06, P1-07, P1-08 batch
4. Round 4 (manual): P1-10, P1-11, P2-03, P2-04 batch
5. Defer: P2-01, P2-05, P2-06, P2-07 to follow-up enhancement (out of v2 scope)

## Post-build addendum — 2026-04-07

Figma v2 build (V2-T5) executed in file `0Ai7s3fCFqR5JXDW8JvgmD` against the merged main code (PR #59). All 6 screens built under section `688:2` "I3.2 — Onboarding v2 (PRD-Aligned)" with per-screen user approval. v1 section `469:2` verified untouched.

**Audit findings reflected in Figma:**
- P0-06 (back button on screens 2-6): present on Goals, Profile, HealthKit, Consent, First Action
- "Apple Health" terminology unification: applied throughout HealthKit screen + variants
- HealthKit state expansion: idle (`698:2`), loading (`698:32`), denied (`698:63`), iPad fallback (`698:96`)
- Consent screen has NO progress bar (standalone decision, integrated as step 5/6 since v1 commit `d017a30`)
- Consent CTA bound to `text/inverse-primary` semantic variable (was raw `.white` in v1)
- First Action subtitle for Maintain goal: "Ready to stay on track?" (NOT "Ready to maintain?") — annotated
- Selection haptic notes added to Goals card and Profile (ExperienceCard + FrequencyCircle)

**Follow-up gaps surfaced during build:**
- SF Symbol glyphs are emoji approximations in Figma (Plugin API can't load Apple SF Symbols)
- Layout-property tokens (padding/radius/spacing) use raw float values matching token canon, not bound `setBoundVariable` references
- HealthKit data-row icon colors are raw hex; could be promoted to `accent/{heart-rate, hrv, steps, sleep}` semantic tokens

See `ux-spec.md` for the full node ID table.
