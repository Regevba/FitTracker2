# PRD: User Profile as Unified Control Center

> **ID:** user-profile-settings | **Status:** PRD | **Priority:** P1
> **Work Type:** Feature (full 10-phase lifecycle)
> **GitHub Issue:** TBD
> **Last Updated:** 2026-04-13

---

## Purpose

Replace the fragmented profile/settings experience (Account Panel modal + Settings v2 sheet + lost onboarding data) with a unified Profile tab that serves as the user's personal control center — showing who they are, where they stand, and letting them configure everything about themselves and the app in one place.

## Business Objective

The Profile tab answers: "Who am I in this app, and am I making progress?" Currently that question requires navigating through a hamburger menu → modal → sheet chain. A dedicated 5th tab makes the user's identity, goals, health snapshot, and settings immediately accessible. This drives:

1. **Engagement:** Profile tab creates a daily check-in ritual (readiness + body comp at a glance)
2. **Retention:** Goal progress visualization reinforces motivation
3. **Feature discovery:** Settings embedded in profile increases configuration engagement
4. **Data quality:** Editable goal/experience fields improve AI personalization accuracy

## Target Persona(s)

- **Primary:** The Data-Driven Optimizer — wants to see their full profile at a glance with health metrics
- **Secondary:** The Consistent Lifter — wants easy access to goal progress and settings
- **Tertiary:** New user — wants to understand what the app knows about them and edit it

## Current State & Problem

### Fragmented Profile Data

| Surface | What It Shows | How to Access |
|---------|--------------|---------------|
| AccountPanelView | Auth identity (name, email, provider badge) | Hamburger → modal |
| SettingsView v2 | 5 category cards (account, health, goals, training, data) | Account panel → "Open Full Settings" → sheet |
| Onboarding | Goal + experience level | Only during onboarding — data not persisted |
| UserProfile struct | name, age, height, targets | Not directly visible anywhere as a complete profile |

### What's Wrong

1. **No "me" screen** — user can't see their profile at a glance
2. **3-tap settings** — hamburger → account panel → settings sheet is too deep
3. **Lost onboarding data** — goal type (Build Muscle, Lose Fat, etc.) and experience level collected but not saved to UserProfile
4. **No goal progress** — target weight/BF ranges exist but no progress visualization
5. **No profile editing** — name, age, height are read-only post-onboarding

## Solution — 5th Tab: Profile

### Architecture

```
RootTabView (5 tabs)
├── Home (house.fill)
├── Training (dumbbell.fill)
├── Nutrition (fork.knife)
├── Stats (chart.bar.fill)
└── Profile (person.circle.fill)  ← NEW
```

### Profile Tab Layout

```
ProfileView (ScrollView)
│
├── Hero Section
│   ├── Avatar circle (initials from auth displayName, AppColor.Brand.primary bg)
│   ├── Name + email (from auth session)
│   ├── Goal badge (e.g., "Fat Loss") — tappable to edit
│   ├── Phase badge (e.g., "Stage 1 Cardio") — read-only
│   └── Stat row: "Day 72" + "5-day streak" + "43 workouts"
│
├── Readiness Snapshot Card
│   ├── Today's readiness score (0-100) from ReadinessEngine
│   ├── Training recommendation badge
│   ├── Component mini-bars (HRV, Sleep, Training, RHR)
│   └── Tap → Home tab focused on ReadinessCard
│
├── Body Composition Card
│   ├── Current: weight, BF%, lean mass (latest from DailyBiometrics)
│   ├── Target: weight range, BF% range (from UserProfile)
│   ├── Progress bar (current vs target)
│   └── Tap → Stats tab filtered to body comp
│
├── Settings Sections (embedded, not modal)
│   ├── Account & Security (existing SettingsView v2 section)
│   ├── Health & Devices (existing)
│   ├── Goals & Preferences (ENHANCED — now editable)
│   │   ├── Fitness goal picker (Build Muscle / Lose Fat / Maintain / General)
│   │   ├── Experience level picker (Beginner / Intermediate / Advanced)
│   │   ├── Training days per week stepper (2-7)
│   │   ├── Name text field
│   │   ├── Age stepper
│   │   ├── Height field
│   │   ├── Target weight range
│   │   └── Target BF% range
│   ├── Training & Nutrition (existing)
│   └── Data & Sync (existing)
│
└── AI Coaching Card (from AIOrchestrator, if available)
    └── Latest insight with FitMeLogoLoader avatar (.breathe)
```

### Navigation Changes

| Before | After |
|--------|-------|
| 4 tabs | 5 tabs (+Profile) |
| Hamburger → AccountPanelView → SettingsView | Profile tab (1 tap) |
| Settings as sheet modal | Settings embedded in Profile scroll |
| No goal editing post-onboarding | Full goal/experience editing in Profile |
| AccountPanelView has sign-out | Sign-out moves to bottom of Profile |

### Data Model Changes

**UserProfile additions (DomainModels.swift):**

```swift
// New fields — all optional for backward compatibility
var fitnessGoal: FitnessGoal?           // NEW
var experienceLevel: ExperienceLevel?   // NEW
var trainingDaysPerWeek: Int?           // NEW
var displayName: String?                // NEW — editable, separate from auth name

enum FitnessGoal: String, Codable, CaseIterable, Sendable {
    case buildMuscle = "Build Muscle"
    case loseFat = "Lose Fat"
    case maintain = "Maintain"
    case generalFitness = "General Fitness"
}

enum ExperienceLevel: String, Codable, CaseIterable, Sendable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
}
```

**Onboarding update:** `OnboardingGoalsView` and `OnboardingProfileView` write to `dataStore.userProfile` on completion.

## Key Files

### Create

| File | Purpose |
|------|---------|
| `FitTracker/Views/Profile/ProfileView.swift` | Main profile tab view |
| `FitTracker/Views/Profile/ProfileHeroSection.swift` | Avatar + name + badges + stats |
| `FitTracker/Views/Profile/BodyCompositionCard.swift` | Current vs target with progress |
| `FitTracker/Views/Profile/GoalEditorSheet.swift` | Edit goal, experience, training days |

### Modify

| File | Change |
|------|--------|
| `FitTracker/Models/DomainModels.swift` | Add FitnessGoal, ExperienceLevel enums + UserProfile fields |
| `FitTracker/Views/RootTabView.swift` | Add 5th tab (Profile) |
| `FitTracker/Views/Onboarding/v2/OnboardingGoalsView.swift` | Persist goal to UserProfile |
| `FitTracker/Views/Onboarding/v2/OnboardingProfileView.swift` | Persist experience level |
| `FitTracker/Views/Settings/v2/SettingsView.swift` | Refactor to embeddable section |
| `FitTracker/Services/Analytics/AnalyticsProvider.swift` | 6 new profile events |
| `FitTracker/Services/Analytics/AnalyticsService.swift` | 6 new logging methods |

### Deprecate (not delete)

| File | Change |
|------|--------|
| `FitTracker/Views/Auth/AccountPanelView.swift` | Simplified to sign-out only, or removed if Profile covers everything |

## Success Metrics

| Metric | Baseline | Target | Instrumentation |
|--------|----------|--------|-----------------|
| **Primary:** Profile tab visit rate | 0% (doesn't exist) | >50% of sessions | `profile_tab_viewed` event |
| **Secondary:** Goal edit rate | 0% (not editable) | >15% of users edit within first week | `profile_goal_changed` event |
| **Secondary:** Settings engagement from profile | ~20% (current settings access rate) | >35% | `profile_settings_section_opened` event |
| **Secondary:** Readiness check from profile | 0% | >25% of profile visits tap readiness | `profile_readiness_tap` event |
| **Guardrail:** Crash-free rate | >99.5% | >99.5% | Sentry |
| **Guardrail:** Cold start time | <2s | <2s | App launch timer |
| **Guardrail:** Home tab engagement | Current baseline | Must not decrease >5% | `home_action_tap` event comparison |

### Kill Criteria

- Profile tab visit rate <10% after 2 weeks (users ignore it completely)
- Home tab engagement drops >10% (profile cannibalizes rather than complements)
- Settings access rate drops from profile (harder to find settings than before)

### First Metrics Review

2 weeks post-merge.

## Analytics Spec (GA4 Event Definitions)

### New Events

| Event Name | Category | GA4 Type | Trigger | Parameters | Conversion |
|-----------|----------|----------|---------|-----------|------------|
| `profile_tab_viewed` | engagement | custom | User switches to Profile tab | `source` (tab_bar / deep_link) | No |
| `profile_goal_changed` | engagement | custom | User saves a goal edit | `field` (fitness_goal / experience_level / training_days / weight_target / bf_target), `old_value`, `new_value` | No |
| `profile_settings_section_opened` | engagement | custom | User expands a settings section | `section` (account / health / goals / training / data) | No |
| `profile_readiness_tap` | engagement | custom | User taps readiness snapshot | — | No |
| `profile_body_comp_tap` | engagement | custom | User taps body composition card | — | No |
| `profile_avatar_tap` | engagement | custom | User taps their avatar | — | No |

### New Parameters

| Parameter | Type | Allowed Values | Events |
|-----------|------|----------------|--------|
| `source` | String | `tab_bar`, `deep_link` | `profile_tab_viewed` |
| `field` | String | `fitness_goal`, `experience_level`, `training_days`, `weight_target`, `bf_target`, `name`, `age`, `height` | `profile_goal_changed` |
| `old_value` | String | Previous value | `profile_goal_changed` |
| `new_value` | String | New value | `profile_goal_changed` |
| `section` | String | `account`, `health`, `goals`, `training`, `data` | `profile_settings_section_opened` |

### Naming Validation Checklist

- [x] All events use `profile_` screen prefix per CLAUDE.md convention
- [x] All names are snake_case, lowercase only
- [x] All names <40 characters
- [x] No reserved prefixes (ga_, firebase_, google_)
- [x] No duplicates against existing AnalyticsEvent enum
- [x] No PII in any parameter
- [x] Parameter values <100 characters
- [x] <25 parameters per event
- [x] Total custom user properties still <=25

## Eval Definitions (v4.4 requirement)

### Golden I/O Cases (Phase 5)

| # | Eval | Input | Expected | Quality Bar |
|---|------|-------|----------|-------------|
| 1 | Profile renders with minimal data | UserProfile with only name + age | Non-crash, hero shows name + "Day N" + default avatar | No crash, all sections render |
| 2 | Profile renders with full data | All UserProfile + UserPreferences + ReadinessResult + DailyBiometrics | All sections populated, readiness score shown, body comp progress calculated | All cards visible |
| 3 | Goal edit persists | Change fitnessGoal from .loseFat to .buildMuscle | UserProfile.fitnessGoal == .buildMuscle after save | Value persists across app restart |
| 4 | Settings sections match v2 | Expand all 5 settings sections | Same content as standalone SettingsView v2 | No missing fields |
| 5 | Tab bar has 5 items | Open RootTabView | 5 tabs: Home, Training, Nutrition, Stats, Profile | Exactly 5 |

### Quality Heuristics

| # | Eval | Quality Bar |
|---|------|-------------|
| 1 | All profile events use `profile_` prefix | 6/6 prefixed |
| 2 | No raw literals in ProfileView | Zero hardcoded colors/fonts/spacing |
| 3 | All tap targets >=44pt | Zero violations |
| 4 | VoiceOver labels on all interactive elements | Zero unlabeled buttons |

## Non-Scope

- Profile photo upload (future — no camera/photo picker needed for v1)
- Social profile / sharing / leaderboard
- Apple Watch profile complication
- Customizable profile layout
- Profile themes / colors
- Training history timeline in profile (Stats tab handles this)

## Risk Register

| Risk | Severity | Mitigation |
|------|----------|------------|
| Settings v2 refactor breaks existing functionality | Medium | Settings v2 cards are self-contained views — embed, don't rewrite |
| 5th tab clutters tab bar on small iPhones | Low | iOS handles 5 tabs well (standard pattern). Test on SE/Mini. |
| AccountPanelView deprecation breaks navigation | Medium | Keep AccountPanelView as fallback during transition. Remove after Profile ships. |
| Onboarding persistence breaks existing users | Low | New UserProfile fields are optional — nil for existing users, populated on next edit |
| ReadinessEngine call in Profile adds latency | Low | ReadinessResult is already cached from Home tab — read cached value |

## Acceptance Criteria

- [ ] Profile tab appears as 5th tab in RootTabView with person.circle.fill icon
- [ ] Hero section shows avatar, name, goal badge, phase badge, day count
- [ ] Readiness snapshot card shows today's score + recommendation + component bars
- [ ] Body composition card shows current vs target with progress indicator
- [ ] All 5 settings categories from SettingsView v2 are accessible within Profile
- [ ] Goals & Preferences section allows editing: goal, experience, training days, name, age, height
- [ ] Edited values persist to UserProfile via EncryptedDataStore
- [ ] Onboarding goal + experience selections persist to UserProfile on completion
- [ ] FitnessGoal and ExperienceLevel enums added to DomainModels.swift
- [ ] 6 analytics events instrumented and tested
- [ ] Eval cases defined and passing (5 golden I/O + 4 quality heuristics)
- [ ] VoiceOver labels on all interactive elements
- [ ] All design system tokens used (no raw literals)
- [ ] BUILD SUCCEEDED + full test suite green
- [ ] Case study snapshot captured with eval pass rate

## Dependencies

- ReadinessEngine v2 (complete — provides readiness snapshot data)
- Settings v2 (complete — provides the 5 settings categories to embed)
- AI Recommendation UI (complete — provides AIInsightCard for coaching section)

## References

- Research: `.claude/features/user-profile-settings/research.md`
- Settings v2 PRD: `docs/product/prd/18.7-settings.md` (if exists)
- UX Foundations: `docs/design-system/ux-foundations.md`
- Competitive analysis: Whoop, Oura, MyFitnessPal, Strong, Apple Health
