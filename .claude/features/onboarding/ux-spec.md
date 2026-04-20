# Onboarding — UX Spec (v2)

> **Date:** 2026-04-07
> **Phase:** Phase 3 — UX (v2 alignment)
> **Status:** Spec for v2 implementation deltas
> **Companion:** v2-audit-report.md, ux-research.md, prd.md (v2 section)

## Purpose

This document specifies the v2 onboarding UX after audit findings are applied. It is the canonical reference for what `feature/onboarding-ux-align` ships.

## Screen List (6)

| # | Screen | Container | Progress bar | Skip | Notes |
|---|--------|-----------|--------------|------|-------|
| 0 | Welcome | OnboardingWelcomeView | hidden | no | Brand gradient hero, "Get Started" CTA |
| 1 | Goals | OnboardingGoalsView | shown (1/6) | yes | 4 goal cards, single select |
| 2 | Profile | OnboardingProfileView | shown (2/6) | yes | Experience + frequency |
| 3 | HealthKit | OnboardingHealthKitView | shown (3/6) | yes | 3-step permission priming |
| 4 | Consent | OnboardingConsentView | hidden | no (Decline) | GDPR analytics consent |
| 5 | First Action | OnboardingFirstActionView | shown (5/6) | no | Workout or Meal CTA |

## Per-screen specifications

### Screen 0: Welcome

**Layout:**
- Full-screen orange brand gradient background
- Centered: FitMeBrandIcon (hero variant)
- Tagline: "Your fitness command center" — `AppText.subheading`, `AppColor.Text.inverseSecondary`
- Pillars: "Training · Nutrition · Recovery · AI" — `AppText.caption` (v2 may bump to 15px)
- White CTA "Get Started" — `AppSize.ctaHeight` (52pt), `AppColor.Brand.primary` text, white bg, `AppRadius.button`, `AppShadow.cta*`

**States:** static (only `.onAppear` analytics)

**Analytics:**
- `tutorialBegin` (fired by parent OnboardingView container)
- `screen_view` → `AnalyticsScreen.onboardingWelcome`
- `onboarding_step_viewed` { step_index: 0, step_name: "welcome" } [v2 P0-02]

**A11y:**
- Container `accessibilityElement(children: .contain)` — inherited from parent
- "Get Started" button has default label
- ScrollView wrapper [v2 P1-06]

### Screen 1: Goals

**Layout:**
- Title: "What's your goal?" — `AppText.pageTitle`, leading aligned
- 2x2 grid of GoalCard: Build Muscle, Lose Fat, Maintain, General Fitness
- Bottom: gradient "Continue" button (disabled until selection) + quiet "Skip"

**Selection behavior:**
- Tap card → `selectedGoal` updated → border animates to brand primary 2pt → haptic [v2 P0-05]
- Continue enabled when `selectedGoal != nil`

**States:** unselected (default), selected (border + color), disabled (Continue grayed when no selection)

**Analytics:**
- `screen_view` → `AnalyticsScreen.onboardingGoals` [v2 P1-01]
- `onboarding_step_viewed` { step_index: 1, step_name: "goals" } [v2 P0-02]
- `onboarding_goal_selected` { goal_value } [v2 P0-04]
- `onboarding_step_completed` on Continue (existing)
- `onboarding_skipped` on Skip { step_index: 1, step_name: "goals" } [v2 P0-03]
- Skip transparency footer: "You can set this later in Settings." [v2 P1-11]

**A11y:**
- Each card: label = goal text, trait `.isSelected` when active
- ScrollView wrapper for Dynamic Type [v2 P1-06]

### Screen 2: Profile

**Layout:**
- Title: "Tell us about you"
- Section 1: "Training experience" — 3 horizontal ExperienceCards
- Section 2: "Days per week" — 5 FrequencyCircles (2-6) horizontal
- Continue (always enabled — defaults to Intermediate, 3) + Skip

**States:** unselected, selected (orange fill, white text)

**Analytics:**
- `screen_view` → `AnalyticsScreen.onboardingProfile` [v2 P1-01]
- `onboarding_step_viewed` [v2 P0-02]
- `onboarding_step_completed` on Continue
- `onboarding_skipped` on Skip [v2 P0-03]

**A11y:**
- ScrollView wrapper [v2 P1-06]
- Frequency circle label includes "X days per week" (already done)

### Screen 3: HealthKit

**Layout:**
- Hero icon: `heart.text.square`, brand primary
- Title: "Sync your health data"
- Description: "FitMe uses Apple Health to track your recovery and training readiness." [v2 P2-03 unifies "Apple Health" terminology]
- 4 data type rows (HR, HRV, Steps, Sleep)
- "Connect Health" CTA (with loading state during async [v2 P1-07])
- Skip

**States:** idle, loading (during HK request), granted (advance), denied (toast/footer "You can enable Apple Health in Settings later" [v2 P1-08])

**iPad adaptation:** if HealthKit unavailable, show fallback copy "Apple Health is not available on iPad. You can connect it later from your iPhone." [v2 P1-10]

**Analytics:**
- `screen_view` → `AnalyticsScreen.onboardingHealthKit` [v2 P1-01]
- `onboarding_step_viewed` [v2 P0-02]
- `permission_result` { permission_type: "healthkit", granted: bool } [v2 P0-01]
- `onboarding_step_completed` on Continue
- `onboarding_skipped` on Skip [v2 P0-03]

### Screen 4: Consent

**Layout:**
- Shield illustration (160pt circle, lock+shield SF symbol, success badge)
- Title: "Help Us Improve FitMe"
- Description: "We use anonymous analytics to understand how the app is used. Your health data is never shared."
- Card listing: ✅ App usage / ✅ Screen views | ❌ Health data values / ❌ Personal info
- "Accept & Continue" (brand orange) — `AppColor.Text.inversePrimary` (not `.white`) [v2 P1-05]
- "Continue Without" quiet text button
- Footer: "You can change this anytime in Settings."

**States:** idle, accepted (advance + grant), declined (advance + deny)

**Analytics:**
- `screen_view` → `AnalyticsScreen.consent`
- `consent_granted` / `consent_denied` (already wired in OnboardingView)

**A11y:**
- ScrollView wrapper [v2 P1-06]

### Screen 5: First Action

**Layout:**
- Personalized title based on goal: "Ready to build muscle?" / "Ready to lose fat?" / "Ready to stay on track?" [v2 P2-04 — replaces "Ready to maintain?"] / "Ready to get fit?"
- Subtitle: "Pick your first action to begin your journey."
- 2 large FirstActionCards: "Start Your First Workout" / "Log Your First Meal"

**Selection:** tap → analytics select_content + complete onboarding

**Analytics:**
- `screen_view` → `AnalyticsScreen.onboardingFirstAction` [v2 P1-01]
- `onboarding_step_viewed` [v2 P0-02]
- `select_content` (existing)
- `tutorialComplete` (existing)
- `setOnboardingCompleted(true)` (existing)

## Container behavior (OnboardingView)

**State:**
- `currentStep: Int` (0-5)
- `@AppStorage("hasCompletedOnboarding")`

**Navigation:**
- Forward: explicit `advance()` calls from each screen's continue/skip
- **Backward [v2 P0-06]:** Back button visible on steps 1-5, hidden on Welcome. Tapping decrements `currentStep` without firing skip events. Animation matches forward.
- No swipe (intentional)

**Animation:**
- `AppMotion.stepTransition` token (new) — easeInOut 0.3 [v2 P1-02]
- Honors Reduce Motion [v2 P1-09]

**Background:**
- Step 0: `AppGradient.brand`
- Steps 1-5: `AppColor.Background.appTint`

**A11y:**
- "Onboarding, step X of N" container label (existing)

## State patterns matrix (per-screen)

| Screen | Empty | Loading | Error | Success |
|--------|-------|---------|-------|---------|
| Welcome | N/A | N/A | N/A | Tap CTA → advance |
| Goals | "Pick a goal" hint | N/A | N/A | Selection visible |
| Profile | N/A (defaults exist) | N/A | N/A | Selection visible |
| HealthKit | N/A | Spinner on Connect button | Toast on denial | Auto-advance on grant |
| Consent | N/A | N/A | N/A | Auto-advance on either choice |
| First Action | N/A | N/A | N/A | Tap → complete |

## Motion specification

| Element | Animation | Token |
|---------|-----------|-------|
| Step transition | easeInOut 0.3s | `AppMotion.stepTransition` (new) |
| Progress bar fill | easeInOut 0.3s, respects Reduce Motion | same |
| Card selection | implicit SwiftUI, instant | — |
| CTA press | system default | — |

## Accessibility specification

- All interactive elements ≥44pt (currently 48-52pt — pass)
- Dynamic Type via ScrollView wrappers on screens 1-5
- VoiceOver: container has step context label; selection cards have label + isSelected trait; progress bar has Step X of N value
- Reduce Motion respected on all animations
- WCAG AA contrast (caption on Welcome may need bump — P2-06)

## Compliance gateway result

| Check | Status |
|-------|--------|
| Token compliance | Pass after v2 patches (P1-02 to P1-05, P2-02 introduce + apply tokens) |
| Component reuse | Acceptable — private structs are deferred to follow-up enhancement (P2-01) |
| Pattern consistency | Pass after v2 patches (P1-01 unifies analytics screen tracking) |
| Accessibility | Pass after v2 patches (P1-06 adds Dynamic Type wrappers) |
| Motion | Pass after v2 patches (P1-02, P1-09 add tokens + Reduce Motion) |

## Cross-references

- Audit: v2-audit-report.md
- Research: ux-research.md
- PRD v2: prd.md → `# v2 — UX Alignment`
- Foundations: docs/design-system/ux-foundations.md
- Figma target: docs/prompts/figma-onboarding-v2-prompt.md

## Figma v2 build — node IDs

Built 2026-04-07 in file `0Ai7s3fCFqR5JXDW8JvgmD`, page `Onboarding` (`25:6`), section `I3.2 — Onboarding v2 (PRD-Aligned)` (`688:2`). v1 section `469:2` confirmed UNCHANGED.

| Screen | Node ID |
|---|---|
| Welcome | `688:6` |
| Goals | `695:2` |
| Profile | `697:2` |
| HealthKit (idle) | `698:2` |
| HealthKit (loading variant) | `698:32` |
| HealthKit (denied variant) | `698:63` |
| HealthKit (iPad fallback variant) | `698:96` |
| Consent | `704:2` |
| First Action | `705:2` |
