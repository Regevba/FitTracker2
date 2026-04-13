# User Profile Settings — Task Breakdown

## Task Layers (dependency-aware)

### Layer 1: Foundation (all parallel — no dependencies)

**T1: Add FitnessGoal + ExperienceLevel enums to DomainModels**
- Type: data | Skill: dev | Priority: high | Effort: 0.25d
- Add `FitnessGoal` enum (buildMuscle, loseFat, maintain, generalFitness)
- Add `ExperienceLevel` enum (beginner, intermediate, advanced)
- Add `fitnessGoal: FitnessGoal?`, `experienceLevel: ExperienceLevel?`, `trainingDaysPerWeek: Int?`, `displayName: String?` to UserProfile
- All optional for backward compatibility
- Depends on: nothing

**T2: Add 6 analytics events + parameters to AnalyticsProvider**
- Type: analytics | Skill: analytics | Priority: high | Effort: 0.25d
- Add: profile_tab_viewed, profile_goal_changed, profile_settings_section_opened, profile_readiness_tap, profile_body_comp_tap, profile_avatar_tap
- Add parameters: source, field, old_value, new_value, section
- Add logging methods to AnalyticsService
- Depends on: nothing

**T3: Create ProfileHeroSection view**
- Type: ui | Skill: dev | Priority: high | Effort: 0.5d
- Avatar circle (initials from auth displayName, AppColor.Brand.primary bg)
- Name + email row
- Goal badge (tappable) + Phase badge (read-only)
- Stat row: day count, streak, workout count
- All design system tokens
- Depends on: nothing (uses existing data types)

**T4: Create BodyCompositionCard view**
- Type: ui | Skill: dev | Priority: medium | Effort: 0.5d
- Current weight, BF%, lean mass from latest DailyBiometrics
- Target ranges from UserProfile
- Progress bar (current vs target midpoint)
- Tap action (navigate to Stats)
- Depends on: nothing

**T5: Create GoalEditorSheet view**
- Type: ui | Skill: dev | Priority: high | Effort: 0.5d
- FitnessGoal picker
- ExperienceLevel picker
- Training days per week stepper (2-7)
- Name, age, height fields
- Target weight/BF range editors
- Save → persist to UserProfile via dataStore
- Depends on: T1 (needs FitnessGoal + ExperienceLevel enums)

### Layer 2: Main Assembly (depends on Layer 1)

**T6: Create ProfileView (main tab view)**
- Type: ui | Skill: dev | Priority: high | Effort: 1.0d
- ScrollView composing: ProfileHeroSection, ReadinessSnapshot (reuse from ReadinessCard), BodyCompositionCard, Settings sections (embed SettingsView v2 categories), AI coaching card (reuse AIInsightCard)
- Readiness snapshot: reuse component bar pattern from ReadinessCard
- Settings sections: embed existing v2 category views
- Wire analytics: profile_tab_viewed on appear, profile_readiness_tap, profile_body_comp_tap
- Depends on: T1, T3, T4, T5

**T7: Wire ProfileView into RootTabView as 5th tab**
- Type: ui | Skill: dev | Priority: high | Effort: 0.25d
- Add Tab("Profile", systemImage: "person.circle.fill") { ProfileView() }
- Pass all environment objects (dataStore, healthService, analytics, signIn, aiOrchestrator)
- Depends on: T6

**T8: Refactor SettingsView v2 for embedding**
- Type: ui | Skill: dev | Priority: medium | Effort: 0.5d
- Extract each settings category (Account, Health, Goals, Training, Data) as standalone section views
- Make embeddable in a parent ScrollView (remove outer NavigationStack if present)
- Goals section gains: FitnessGoal picker, ExperienceLevel picker, training days, name/age/height editors
- Wire profile_settings_section_opened analytics event on expand
- Depends on: T1, T2

### Layer 3: Onboarding Integration

**T9: Persist onboarding selections to UserProfile**
- Type: data | Skill: dev | Priority: medium | Effort: 0.25d
- OnboardingGoalsView: on goal selection, write to dataStore.userProfile.fitnessGoal
- OnboardingProfileView: on experience selection, write to dataStore.userProfile.experienceLevel + trainingDaysPerWeek
- Depends on: T1

### Layer 4: Testing + Verification

**T10: Write analytics tests for 6 profile events**
- Type: test | Skill: qa | Priority: high | Effort: 0.5d
- ProfileAnalyticsTests.swift: 6 event tests + consent gating + naming convention
- Depends on: T2

**T11: Write eval tests (5 golden I/O + 4 quality heuristics)**
- Type: test | Skill: qa | Priority: high | Effort: 0.5d
- ProfileEvals.swift: renders with minimal data, renders with full data, goal edit persists, settings match v2, 5 tabs exist
- Quality: all events prefixed, no raw literals, tap targets, VoiceOver labels
- Depends on: T6, T7

**T12: Accessibility pass**
- Type: ui | Skill: dev | Priority: medium | Effort: 0.25d
- VoiceOver labels on all interactive elements
- Dynamic Type: verify hero, cards, settings all scale
- Minimum 44pt tap targets
- Depends on: T6

**T13: pbxproj + build verification**
- Type: infra | Skill: dev | Priority: high | Effort: 0.25d
- Add all new files to Xcode project
- Run xcodebuild build + test
- Depends on: T6, T7, T10, T11

## Dependency Graph

```
T1 (enums) ──┬──→ T5 (goal editor) ──→ T6 (ProfileView) ──→ T7 (wire tab)
              ├──→ T8 (settings refactor) ──→ T6              ├──→ T11 (evals)
              └──→ T9 (onboarding)                            ├──→ T12 (a11y)
T2 (analytics) ──→ T8                                        └──→ T13 (build)
               └──→ T10 (analytics tests)
T3 (hero) ────→ T6
T4 (body comp) ──→ T6
```

## Critical Path

T1 → T5 → T6 → T7 → T13 (build verification)

## Effort Summary

| Layer | Tasks | Total Effort |
|-------|-------|-------------|
| Layer 1: Foundation | T1-T5 | 2.0 days |
| Layer 2: Assembly | T6-T8 | 1.75 days |
| Layer 3: Onboarding | T9 | 0.25 days |
| Layer 4: Testing | T10-T13 | 1.5 days |
| **Total** | **13 tasks** | **5.5 days** |
