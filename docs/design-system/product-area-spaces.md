# FitTracker Product Area Spaces

These are the dedicated design-system planning spaces created to map the current app into distinct product areas.

## Figma spaces

- `Onboarding`
- `Login`
- `Greeting`
- `Main Screen`
- `Settings`
- `Nutrition`
- `Stats`
- `Training`
- `Account + Security`

## Area map

### Onboarding

- Primary source: [AuthHubView.swift](FitTracker/Views/Auth/AuthHubView.swift)
- Purpose: first-time setup and secure account guidance

### Login

- Primary source: [SignInView.swift](FitTracker/Views/Auth/SignInView.swift)
- Purpose: direct sign-in and account creation entry

### Greeting

- Primary source: [WelcomeView.swift](FitTracker/Views/Auth/WelcomeView.swift)
- Purpose: brand and trust introduction before sign-in

### Main Screen

- Primary sources:
  - [MainScreenView.swift](FitTracker/Views/Main/MainScreenView.swift)
  - [RootTabView.swift](FitTracker/Views/RootTabView.swift)
  - [ReadinessCard.swift](FitTracker/Views/Shared/ReadinessCard.swift)
- Purpose: daily command center

### Settings

- Primary sources:
  - [SettingsView.swift](FitTracker/Views/Settings/SettingsView.swift)
  - [DesignSystemCatalogView.swift](FitTracker/Views/Settings/DesignSystemCatalogView.swift)
  - [AppSettings.swift](FitTracker/Services/AppSettings.swift)
- Purpose: preferences, appearance, and app lock behavior

### Nutrition

- Primary sources:
  - [NutritionView.swift](FitTracker/Views/Nutrition/NutritionView.swift)
  - [MealEntrySheet.swift](FitTracker/Views/Nutrition/MealEntrySheet.swift)
  - [MealSectionView.swift](FitTracker/Views/Nutrition/MealSectionView.swift)
  - [MacroTargetBar.swift](FitTracker/Views/Nutrition/MacroTargetBar.swift)
- Purpose: meal logging, supplements, hydration, and macro tracking

### Stats

- Primary sources:
  - [StatsView.swift](FitTracker/Views/Stats/StatsView.swift)
  - [StatsDataHelpers.swift](FitTracker/Views/Stats/StatsDataHelpers.swift)
  - [MetricCard.swift](FitTracker/Views/Shared/MetricCard.swift)
  - [ChartCard.swift](FitTracker/Views/Shared/ChartCard.swift)
- Purpose: progress, charts, and trend review

### Training

- Primary sources:
  - [TrainingPlanView.swift](FitTracker/Views/Training/TrainingPlanView.swift)
  - [RecoverySupport.swift](FitTracker/Views/Shared/RecoverySupport.swift)
- Purpose: workout execution, session flow, timers, and completion

### Account + Security

- Primary sources:
  - [AccountPanelView.swift](FitTracker/Views/Auth/AccountPanelView.swift)
  - [AuthManager.swift](FitTracker/Services/AuthManager.swift)
- Purpose: session state, providers, app lock, and quick return

## Planning rule

Each future feature should start in the relevant area space before moving to final UI. That page should capture:

- behavior
- problem solved
- states
- reused components
- reused icons
- reused typography
- platform notes
