# User Profile Settings — UX Specification

## Screen: ProfileView (5th tab)

### Layout (ScrollView, vertical stack)

```
┌─────────────────────────────────────────────────┐
│  [Avatar]  Name                                 │
│            email@example.com                    │
│            [Fat Loss]  [Stage 1 Cardio]         │
│            Day 72 · 5-day streak · 43 workouts  │
├─────────────────────────────────────────────────┤
│  ┌─ Readiness Snapshot ───────────────────────┐ │
│  │  Score: 78        Full Intensity            │ │
│  │  [HRV ████████░░] [Sleep ██████░░░░]       │ │
│  │  [Load ███████░░░] [RHR ████████░░]        │ │
│  └────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────┤
│  ┌─ Body Composition ────────────────────────┐  │
│  │  71.5 kg    21.3% BF    56.2 kg lean      │  │
│  │  Target: 65-68 kg · 13-15% BF             │  │
│  │  [████████████░░░░░░░░] 62% to goal       │  │
│  └────────────────────────────────────────────┘  │
├─────────────────────────────────────────────────┤
│  ▸ Account & Security                           │
│  ▸ Health & Devices                             │
│  ▸ Goals & Preferences                          │
│  ▸ Training & Nutrition                         │
│  ▸ Data & Sync                                  │
├─────────────────────────────────────────────────┤
│  [Sign Out]                                     │
└─────────────────────────────────────────────────┘
```

### Hero Section

- **Avatar:** 64pt circle, AppColor.Brand.primary background, white initials from auth displayName (first letter of first + last name). No photo for v1.
- **Name:** AppText.sectionTitle, AppColor.Text.primary. From `signIn.activeSession?.displayName` with fallback to UserProfile.displayName or "FitMe User".
- **Email:** AppText.caption, AppColor.Text.secondary. From auth session.
- **Goal badge:** Capsule, AppColor.Accent.primary background, AppText.caption. Shows FitnessGoal rawValue. Tap → GoalEditorSheet.
- **Phase badge:** Capsule, AppColor.Surface.secondary background. Shows ProgramPhase display name. Read-only.
- **Stat row:** HStack of 3 items separated by `·`. AppText.caption, AppColor.Text.tertiary.
  - "Day N" — from `userProfile.daysSinceStart`
  - "N-day streak" — from supplement/workout streak logic
  - "N workouts" — count of DailyLogs with exercise data

### Readiness Snapshot Card

- AppColor.Surface.primary background, AppRadius.card corners, AppShadow.card
- Reuse the component bar pattern from ReadinessCard.swift (already built)
- Score number: AppText.sectionTitle + recommendation label: AppText.subheading
- 4 mini-bars: HRV, Sleep, Training Load, RHR (same colors as ReadinessCard)
- Tap → navigate to Home tab (or no-op for v1)
- If ReadinessResult is nil: show "Log biometrics to see your readiness score"

### Body Composition Card

- AppColor.Surface.primary background, AppRadius.card corners
- 3 inline metrics: weight (kg), BF% (%), lean mass (kg) — AppText.monoCaption
- Target row: "Target: 65-68 kg · 13-15% BF" — AppText.caption, AppColor.Text.secondary
- Progress bar: linear, AppColor.Brand.primary fill. Progress = (startBF - currentBF) / (startBF - targetBFMidpoint)
- Percentage label: "N% to goal" — AppText.caption
- Tap → navigate to Stats tab filtered to body comp
- If no biometrics: "Log your first weigh-in to track progress"

### Settings Sections (Expandable)

- 5 disclosure groups using `DisclosureGroup` with AppColor.Surface.primary background
- Each group label: icon (from AppIcon) + section name + chevron
- Expanded content: exact same fields as SettingsView v2 sections
- Goals & Preferences section adds: FitnessGoal picker, ExperienceLevel picker, training days stepper, name/age/height editors
- Wire `profile_settings_section_opened` event on expand

### GoalEditorSheet

- Presented as `.sheet` from hero goal badge tap
- Form with sections:
  - Fitness Goal: segmented picker (4 options)
  - Experience Level: segmented picker (3 options)
  - Training Days: stepper (2-7)
  - Divider
  - Name: TextField
  - Age: Stepper (15-99)
  - Height: TextField with "cm" unit label
  - Divider
  - Target Weight Range: two TextFields (min, max) with "kg"
  - Target BF% Range: two TextFields (min, max) with "%"
- Save button → persist all to dataStore.userProfile
- Fire `profile_goal_changed` with field + old_value + new_value for each changed field

### Sign Out

- Positioned at bottom of scroll, below all settings sections
- Destructive style: AppColor.Status.error tint
- Confirmation alert before executing
- Existing sign-out logic from AccountPanelView

## States

| State | What Shows |
|-------|-----------|
| **Full data** | All sections populated with real data |
| **New user (post-onboarding)** | Hero with name + goal. Readiness: "Log biometrics..." Body comp: "Log your first weigh-in..." Settings: all accessible. |
| **No auth session** | Shouldn't happen (Profile tab only visible when signed in). If reached: show sign-in CTA. |
| **Loading** | FitMeLogoLoader .breathe while readiness computes |

## UX Principles Applied

| Principle | Application |
|-----------|------------|
| Fitts's Law | Avatar 64pt, all tap targets >=44pt, goal badge prominent |
| Hick's Law | 5 settings sections collapsed by default — user opens only what they need |
| Progressive Disclosure | Hero → snapshot → body comp → settings. Most important first. |
| Recognition over Recall | Goal badge visible on hero — user sees their goal without navigating |
| Consistency | Card style matches ReadinessCard + AIInsightCard patterns |
| Feedback | Goal badge tap → sheet. Settings expand → analytics event. Sign out → confirmation. |
| Celebration Not Guilt | Progress bar says "62% to goal" not "38% remaining" |
| Motion Safety | No custom animations beyond system defaults. DisclosureGroup uses system animation. |

## Design System Tokens

All tokens from AppTheme.swift:
- Colors: AppColor.Brand.primary (avatar), Surface.primary (cards), Text.primary/secondary/tertiary, Status.error (sign out), Accent.primary (goal badge)
- Fonts: AppText.sectionTitle, .subheading, .body, .caption, .monoCaption
- Spacing: AppSpacing.small, .medium, .large, .xSmall
- Radius: AppRadius.card
- Icons: AppIcon.person (profile tab), .settings, .heart, .hrv, .sleep, .weight

## Accessibility

- VoiceOver: Avatar label "Profile picture, [name]". Goal badge: "[goal], double tap to edit". Each settings section: "[section name], double tap to expand".
- Dynamic Type: All text scales. Hero section wraps on large text. Cards expand vertically.
- Reduce Motion: No custom animations to disable.
- Minimum tap targets: 44pt on avatar, goal badge, each settings section header, sign out button.
