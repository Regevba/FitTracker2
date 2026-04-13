# User Profile as Unified Control Center — Research

## What is this solution?

Replace the fragmented profile/settings experience (Account Panel + Settings v2 sheet + lost onboarding data) with a unified Profile tab that serves as the user's personal control center — showing who they are, where they stand, and letting them configure everything in one place.

## Why this approach?

**Problem:** Profile data is scattered across 3 surfaces. Users can't see "me" at a glance. Onboarding collects goal + experience level but doesn't persist them. Settings are hidden behind a hamburger menu → modal → sheet chain.

**Solution:** 5th tab in RootTabView. Profile hero (avatar, name, goal, phase, key stats) + readiness snapshot + body comp progress + embedded settings categories + AI coaching card.

## Why this over alternatives?

| Approach | Pros | Cons | Effort | Chosen? |
|----------|------|------|--------|---------|
| **5th tab (Profile)** | Most discoverable. Industry standard (Whoop, MFP, Oura). Settings fold in naturally. Hero gives the tab identity. | Adds 1 tab (5 total). | Medium | Yes |
| Avatar overlay (sheet) | Keeps 4 tabs. Social-app pattern. | Less discoverable. Users miss it. Settings still feel hidden. | Medium | No |
| Enhance existing Settings | Minimal nav change. | Doesn't solve the "me" problem. Still a modal sheet. No hero, no identity. | Low | No |

## Competitive analysis

| App | Profile Pattern | What FitMe Should Learn |
|-----|----------------|------------------------|
| Whoop | Profile tab with recovery metrics, strain, sleep. Settings nested. | Unified "me" with health data front-and-center |
| Oura | Profile ring with readiness + sleep + activity. Gear for settings. | Visual health summary as profile hero |
| MyFitnessPal | "Me" tab: goals, weight chart, streaks, settings nested | Goal progress visible at profile level |
| Strong | Profile with PRs, workout history, body measurements | Training identity visible |
| Apple Health | Profile with medical ID, health records, sharing | Medical/health identity |

**Key pattern:** All top fitness apps show health metrics IN the profile, not just account settings.

## Proposed architecture

```
Profile Tab (5th tab in RootTabView)
├── Hero Section
│   ├── Avatar (initials-based, from auth display name)
│   ├── Name + email (from auth session)
│   ├── Goal badge ("Fat Loss" / "Muscle Gain" / "Maintain" / "General")
│   ├── Program phase badge ("Stage 1 Cardio" / "Stage 2")
│   └── Key stat: days since start, current streak
│
├── Readiness Snapshot Card
│   ├── Today's readiness score (from ReadinessEngine)
│   ├── Training recommendation
│   └── Component mini-bars (HRV, Sleep, Training, RHR)
│
├── Body Composition Card
│   ├── Current weight, BF%, lean mass
│   ├── Target ranges (from UserProfile)
│   ├── Progress ring or bar
│   └── Tap → Stats filtered to body comp
│
├── Settings Categories (existing v2, embedded not modal)
│   ├── Account & Security
│   ├── Health & Devices
│   ├── Goals & Preferences (NOW EDITABLE: goal type, experience, name, age, height)
│   ├── Training & Nutrition
│   └── Data & Sync
│
└── AI Coaching Card (optional, from AIOrchestrator)
    └── Latest personalized insight
```

## Navigation change

- RootTabView: 4 tabs → 5 tabs
- New tab: Profile (person.circle.fill icon)
- AccountPanelView: deprecated or simplified to just sign-out
- Settings sheet: no longer needed as separate modal — embedded in Profile tab
- Hamburger menu: replaced by Profile tab

## Data model changes needed

1. **UserProfile additions:**
   - `fitnessGoal: FitnessGoal?` (enum: buildMuscle, loseFat, maintain, generalFitness)
   - `experienceLevel: ExperienceLevel?` (enum: beginner, intermediate, advanced)
   - `trainingDaysPerWeek: Int?`
   - All three collected during onboarding but currently not persisted

2. **Onboarding update:**
   - OnboardingGoalsView and OnboardingProfileView need to write to UserProfile on completion

3. **SettingsView v2:**
   - Refactored from standalone sheet to embeddable section within ProfileView
   - Goals & Preferences section gains editable fields for goal, experience, name, age, height

## Technical feasibility

- UserProfile struct is Codable — adding optional fields is backward compatible
- EncryptedDataStore already persists UserProfile — no new persistence needed
- RootTabView is simple — adding a 5th tab is trivial
- Settings v2 cards are self-contained views — can be embedded in a ScrollView
- ReadinessEngine is already computed — just display it
- Body comp data exists in DailyBiometrics — just display latest

## Success metrics (draft)

- **Primary:** Profile tab visit rate >50% of sessions
- **Secondary:** Goal edit rate, settings engagement from profile, readiness check from profile
- **Kill:** Profile tab visit <10% after 2 weeks (users ignore it)

## Decision

Build the 5th tab Profile as a unified control center. Settings v2 folds in. Onboarding data persists to UserProfile. Hero section with health-forward identity.
