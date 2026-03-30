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

- Primary source: [AuthHubView.swift](/Users/regevbarak/Downloads/FitTracker2/FitTracker/Views/Auth/AuthHubView.swift)
- Purpose: first-time setup and secure account guidance

### Login

- Primary source: [SignInView.swift](/Users/regevbarak/Downloads/FitTracker2/FitTracker/Views/Auth/SignInView.swift)
- Purpose: direct sign-in and account creation entry

### Greeting

- Primary source: [WelcomeView.swift](/Users/regevbarak/Downloads/FitTracker2/FitTracker/Views/Auth/WelcomeView.swift)
- Purpose: brand and trust introduction before sign-in

### Main Screen

- Primary sources:
  - [MainScreenView.swift](/Users/regevbarak/Downloads/FitTracker2/FitTracker/Views/Main/MainScreenView.swift)
  - [RootTabView.swift](/Users/regevbarak/Downloads/FitTracker2/FitTracker/Views/RootTabView.swift)
  - [ReadinessCard.swift](/Users/regevbarak/Downloads/FitTracker2/FitTracker/Views/Shared/ReadinessCard.swift)
- Purpose: daily command center

### Settings

- Primary sources:
  - [SettingsView.swift](/Users/regevbarak/Downloads/FitTracker2/FitTracker/Views/Settings/SettingsView.swift)
  - [DesignSystemCatalogView.swift](/Users/regevbarak/Downloads/FitTracker2/FitTracker/Views/Settings/DesignSystemCatalogView.swift)
  - [AppSettings.swift](/Users/regevbarak/Downloads/FitTracker2/FitTracker/Services/AppSettings.swift)
- Purpose: preferences, appearance, and app lock behavior

### Nutrition

- Primary sources:
  - [NutritionView.swift](/Users/regevbarak/Downloads/FitTracker2/FitTracker/Views/Nutrition/NutritionView.swift)
  - [MealEntrySheet.swift](/Users/regevbarak/Downloads/FitTracker2/FitTracker/Views/Nutrition/MealEntrySheet.swift)
  - [MealSectionView.swift](/Users/regevbarak/Downloads/FitTracker2/FitTracker/Views/Nutrition/MealSectionView.swift)
  - [MacroTargetBar.swift](/Users/regevbarak/Downloads/FitTracker2/FitTracker/Views/Nutrition/MacroTargetBar.swift)
- Purpose: meal logging, supplements, hydration, and macro tracking

### Stats

- Primary sources:
  - [StatsView.swift](/Users/regevbarak/Downloads/FitTracker2/FitTracker/Views/Stats/StatsView.swift)
  - [StatsDataHelpers.swift](/Users/regevbarak/Downloads/FitTracker2/FitTracker/Views/Stats/StatsDataHelpers.swift)
  - [MetricCard.swift](/Users/regevbarak/Downloads/FitTracker2/FitTracker/Views/Shared/MetricCard.swift)
  - [ChartCard.swift](/Users/regevbarak/Downloads/FitTracker2/FitTracker/Views/Shared/ChartCard.swift)
- Purpose: progress, charts, and trend review

### Training

- Primary sources:
  - [TrainingPlanView.swift](/Users/regevbarak/Downloads/FitTracker2/FitTracker/Views/Training/TrainingPlanView.swift)
  - [RecoverySupport.swift](/Users/regevbarak/Downloads/FitTracker2/FitTracker/Views/Shared/RecoverySupport.swift)
- Purpose: workout execution, session flow, timers, and completion

### Account + Security

- Primary sources:
  - [AccountPanelView.swift](/Users/regevbarak/Downloads/FitTracker2/FitTracker/Views/Auth/AccountPanelView.swift)
  - [AuthManager.swift](/Users/regevbarak/Downloads/FitTracker2/FitTracker/Services/AuthManager.swift)
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
