# UI/UX Inventory — FitTracker2 + fitme-story (2026-05-08)

> Agent-produced inventory. Source: Explore subagent dispatch on 2026-05-08T18:50Z.
> Use this as the read-only canonical inventory of every UI/UX surface across both repos at this date.

---

## 1. iOS App Screens (`FitTracker/Views/`)

113+ Swift view files across 11 feature folders + shared components.

### Auth (9 screens, all v1)
| File | Lines | Role |
|------|-------|------|
| [AuthHubView.swift](FitTracker/Views/Auth/AuthHubView.swift) | 717 | Primary auth entry; sign-in/sign-up/forgot-password tab hub |
| [SignInView.swift](FitTracker/Views/Auth/SignInView.swift) | 336 | Email/password + Google OAuth |
| [BiometricActivationSheet.swift](FitTracker/Views/Auth/BiometricActivationSheet.swift) | 158 | FaceID/TouchID enrollment modal |
| [BiometricUnlockView.swift](FitTracker/Views/Auth/BiometricUnlockView.swift) | 127 | FaceID/TouchID unlock |
| [ForgotPasswordRequestView.swift](FitTracker/Views/Auth/ForgotPasswordRequestView.swift) | 113 | Reset code request |
| [ForgotPasswordCooldownView.swift](FitTracker/Views/Auth/ForgotPasswordCooldownView.swift) | 112 | Rate-limit cooldown |
| [SetNewPasswordView.swift](FitTracker/Views/Auth/SetNewPasswordView.swift) | 138 | Password reset form |
| [AccountPanelView.swift](FitTracker/Views/Auth/AccountPanelView.swift) | 295 | Logged-in user profile summary |
| [WelcomeView.swift](FitTracker/Views/Auth/WelcomeView.swift) | 176 | Splash/entry |

### Onboarding (18 screens: 9 v1 HISTORICAL + 9 v2 canonical)
| v1 | Lines | v2 | Lines | Role |
|----|-------|----|------|------|
| [OnboardingView.swift](FitTracker/Views/Onboarding/OnboardingView.swift) | 159 | [v2/OnboardingView.swift](FitTracker/Views/Onboarding/v2/OnboardingView.swift) | 187 | Step container |
| [OnboardingWelcomeView.swift](FitTracker/Views/Onboarding/OnboardingWelcomeView.swift) | 83 | [v2/OnboardingWelcomeView.swift](FitTracker/Views/Onboarding/v2/OnboardingWelcomeView.swift) | 77 | Step 1: brand intro |
| — | — | [v2/OnboardingAuthView.swift](FitTracker/Views/Onboarding/v2/OnboardingAuthView.swift) | 434 | Step 2 (v2 only): embedded auth |
| [OnboardingProfileView.swift](FitTracker/Views/Onboarding/OnboardingProfileView.swift) | 198 | [v2/OnboardingProfileView.swift](FitTracker/Views/Onboarding/v2/OnboardingProfileView.swift) | 208 | Bio input |
| [OnboardingGoalsView.swift](FitTracker/Views/Onboarding/OnboardingGoalsView.swift) | 159 | [v2/OnboardingGoalsView.swift](FitTracker/Views/Onboarding/v2/OnboardingGoalsView.swift) | 164 | Goal selection |
| [OnboardingHealthKitView.swift](FitTracker/Views/Onboarding/OnboardingHealthKitView.swift) | 209 | [v2/OnboardingHealthKitView.swift](FitTracker/Views/Onboarding/v2/OnboardingHealthKitView.swift) | 205 | HealthKit priming |
| [OnboardingConsentView.swift](FitTracker/Views/Onboarding/OnboardingConsentView.swift) | 131 | [v2/OnboardingConsentView.swift](FitTracker/Views/Onboarding/v2/OnboardingConsentView.swift) | 120 | Privacy consent |
| [OnboardingFirstActionView.swift](FitTracker/Views/Onboarding/OnboardingFirstActionView.swift) | 137 | [v2/OnboardingFirstActionView.swift](FitTracker/Views/Onboarding/v2/OnboardingFirstActionView.swift) | 163 | First-action prompt |
| [OnboardingProgressBar.swift](FitTracker/Views/Onboarding/OnboardingProgressBar.swift) | 75 | [v2/OnboardingProgressBar.swift](FitTracker/Views/Onboarding/v2/OnboardingProgressBar.swift) | 70 | Progress bar |

### Main / Home (4 screens)
| File | Lines | Status | Role |
|------|-------|--------|------|
| [MainScreenView.swift](FitTracker/Views/Main/MainScreenView.swift) | 1035 | v1 HISTORICAL | Legacy home |
| [v2/MainScreenView.swift](FitTracker/Views/Main/v2/MainScreenView.swift) | 653 | v2 | Today-first home (ReadinessCard hero, metric tiles, AI feed) |
| [BodyCompositionCard.swift](FitTracker/Views/Main/BodyCompositionCard.swift) | 288 | v1 | Body comp card |
| [BodyCompositionDetailView.swift](FitTracker/Views/Main/BodyCompositionDetailView.swift) | 476 | v1 | Detail drill-down |

### Training (7 screens: 1 v1 + 6 v2)
| File | Lines | Status | Role |
|------|-------|--------|------|
| [TrainingPlanView.swift](FitTracker/Views/Training/TrainingPlanView.swift) | 2141 | v1 HISTORICAL | Monolithic 6-day PPL |
| [v2/TrainingPlanView.swift](FitTracker/Views/Training/v2/TrainingPlanView.swift) | 556 | v2 | Container |
| [v2/ExerciseRowView.swift](FitTracker/Views/Training/v2/ExerciseRowView.swift) | 275 | v2 | Exercise + set expansion |
| [v2/SetRowView.swift](FitTracker/Views/Training/v2/SetRowView.swift) | 302 | v2 | Set logging |
| [v2/FocusModeView.swift](FitTracker/Views/Training/v2/FocusModeView.swift) | 263 | v2 | Distraction-free entry |
| [v2/RestTimerView.swift](FitTracker/Views/Training/v2/RestTimerView.swift) | 154 | v2 | Rest countdown |
| [v2/SessionCompletionSheet.swift](FitTracker/Views/Training/v2/SessionCompletionSheet.swift) | 294 | v2 | Wrap-up modal |

### Nutrition (11 screens)
| File | Lines | Status | Role |
|------|-------|--------|------|
| [NutritionView.swift](FitTracker/Views/Nutrition/NutritionView.swift) | 1119 | v1 HISTORICAL | Legacy container |
| [v2/NutritionView.swift](FitTracker/Views/Nutrition/v2/NutritionView.swift) | 952 | v2 | Redesigned (meal sections, tabs) |
| [Tabs/ManualTabView.swift](FitTracker/Views/Nutrition/Tabs/ManualTabView.swift) | 65 | v1 | Manual entry |
| [Tabs/SearchTabView.swift](FitTracker/Views/Nutrition/Tabs/SearchTabView.swift) | 108 | v1 | OpenFoodFacts search |
| [Tabs/SmartTabView.swift](FitTracker/Views/Nutrition/Tabs/SmartTabView.swift) | 121 | v1 | AI suggestions |
| [Tabs/TemplateTabView.swift](FitTracker/Views/Nutrition/Tabs/TemplateTabView.swift) | 54 | v1 | Saved templates |
| [MealEntrySheet.swift](FitTracker/Views/Nutrition/MealEntrySheet.swift) | 140 | v1 | Add-meal modal (refactored from 1104→140 in M-2) |
| [MealSectionView.swift](FitTracker/Views/Nutrition/MealSectionView.swift) | 154 | v1 | Per-meal section |
| [Camera/NutritionCameraSheet.swift](FitTracker/Views/Nutrition/Camera/NutritionCameraSheet.swift) | 46 | v1 | Camera launcher |
| [Camera/BarcodeScanner.swift](FitTracker/Views/Nutrition/Camera/BarcodeScanner.swift) | 169 | v1 | Vision-framework barcode |
| [MacroTargetBar.swift](FitTracker/Views/Nutrition/MacroTargetBar.swift) | 103 | v1 | Macro progress |

### Stats (2 screens)
| File | Lines | Status | Role |
|------|-------|--------|------|
| [StatsView.swift](FitTracker/Views/Stats/StatsView.swift) | 893 | v1 HISTORICAL | Legacy chart tabs |
| [v2/StatsView.swift](FitTracker/Views/Stats/v2/StatsView.swift) | 673 | v2 | Metric selection + chart views |

### Settings (refactored M-1: 1170 → 294 lines + 6 v2 screens)
| File | Lines | Status | Role |
|------|-------|--------|------|
| [SettingsView.swift](FitTracker/Views/Settings/SettingsView.swift) | 1196 | v1 HISTORICAL | Monolithic |
| [v2/SettingsView.swift](FitTracker/Views/Settings/v2/SettingsView.swift) | 300 | v2 | Settings home (6 group menu) |
| [v2/Screens/AccountSecuritySettingsScreen.swift](FitTracker/Views/Settings/v2/Screens/AccountSecuritySettingsScreen.swift) | — | v2 | Sign-out, password, biometric, passkeys |
| [v2/Screens/DataSyncSettingsScreen.swift](FitTracker/Views/Settings/v2/Screens/DataSyncSettingsScreen.swift) | — | v2 | Sync, imported plans, export |
| [v2/Screens/HealthDevicesSettingsScreen.swift](FitTracker/Views/Settings/v2/Screens/HealthDevicesSettingsScreen.swift) | — | v2 | HealthKit + wearables |
| [v2/Screens/GoalsPreferencesSettingsScreen.swift](FitTracker/Views/Settings/v2/Screens/GoalsPreferencesSettingsScreen.swift) | — | v2 | Targets, units, body comp method |
| [v2/Screens/TrainingNutritionSettingsScreen.swift](FitTracker/Views/Settings/v2/Screens/TrainingNutritionSettingsScreen.swift) | — | v2 | Training, nutrition, calorie targets |
| [v2/Screens/ImportedPlansListScreen.swift](FitTracker/Views/Settings/v2/Screens/ImportedPlansListScreen.swift) | — | v2 | Imported training plan library |
| [ExportDataView.swift](FitTracker/Views/Settings/ExportDataView.swift) | 76 | v1 | GDPR export |
| [DeleteAccountView.swift](FitTracker/Views/Settings/DeleteAccountView.swift) | 157 | v1 | GDPR deletion (30-day grace) |
| [DesignSystemCatalogView.swift](FitTracker/Views/Settings/DesignSystemCatalogView.swift) | 260 | v1 | DS browser (dev tool) |
| [BehavioralLearningSettingsView.swift](FitTracker/Views/Settings/BehavioralLearningSettingsView.swift) | 41 | v1 | AI learning prefs |

### Profile (7 components)
| File | Lines | Role |
|------|-------|------|
| [ProfileView.swift](FitTracker/Views/Profile/ProfileView.swift) | 202 | Profile tab (hero + cards) |
| [ProfileHeroSection.swift](FitTracker/Views/Profile/ProfileHeroSection.swift) | 92 | Avatar + name + metrics header |
| [GoalsTrainingCard.swift](FitTracker/Views/Profile/GoalsTrainingCard.swift) | 51 | Training goal summary |
| [ProfileBodyCompCard.swift](FitTracker/Views/Profile/ProfileBodyCompCard.swift) | 110 | Body comp metric card |
| [AccountDataCard.swift](FitTracker/Views/Profile/AccountDataCard.swift) | 50 | Account email + sign-out |
| [GoalEditorSheet.swift](FitTracker/Views/Profile/GoalEditorSheet.swift) | 297 | Goal create/edit modal |
| [AppearanceUnitsSheet.swift](FitTracker/Views/Profile/AppearanceUnitsSheet.swift) | 41 | Unit + appearance toggle |

### Notifications (3 screens)
- [NotificationPermissionPrimingView.swift](FitTracker/Views/Notifications/NotificationPermissionPrimingView.swift) (205) — permission request
- [NotificationPermissionRow.swift](FitTracker/Views/Notifications/NotificationPermissionRow.swift) (143) — permission row
- [SettingsDeepLinkBanner.swift](FitTracker/Views/Notifications/SettingsDeepLinkBanner.swift) (79) — deep-link to Settings

### Import (2 screens)
- [ImportSourcePickerView.swift](FitTracker/Views/Import/ImportSourcePickerView.swift) (171) — format selection (CSV/JSON/Markdown)
- [ImportPreviewView.swift](FitTracker/Views/Import/ImportPreviewView.swift) (496) — exercise mapping + preview

### AI (4 components)
- [AIInsightCard.swift](FitTracker/Views/AI/AIInsightCard.swift) (201) — home feed AI recommendation
- [AIIntelligenceSheet.swift](FitTracker/Views/AI/AIIntelligenceSheet.swift) (158) — recommendation detail modal
- [AIRecommendationCard.swift](FitTracker/Views/AI/AIRecommendationCard.swift) (87) — compact recommendation cell
- [AIFeedbackView.swift](FitTracker/Views/AI/AIFeedbackView.swift) (52) — AI quality feedback form

### Shared Components (30+ reusable)
| File | Lines | Role |
|------|-------|------|
| [AppDesignSystemComponents.swift](FitTracker/Views/Shared/AppDesignSystemComponents.swift) | 369 | Button, badge, label, text primitives |
| [ReadinessCard.swift](FitTracker/Views/Shared/ReadinessCard.swift) | 623 | 5-component readiness hero card |
| [MetricCard.swift](FitTracker/Views/Shared/MetricCard.swift) | 107 | Metric tile + trend indicator |
| [ChartCard.swift](FitTracker/Views/Shared/ChartCard.swift) | 60 | Chart container |
| [StatusBadge.swift](FitTracker/Views/Shared/StatusBadge.swift) | 45 | Status indicator |
| [StatusDropdown.swift](FitTracker/Views/Shared/StatusDropdown.swift) | 38 | Status selector |
| [TrendIndicator.swift](FitTracker/Views/Shared/TrendIndicator.swift) | 74 | Up/down/flat arrow + color |
| [SyncStatusIndicator.swift](FitTracker/Views/Shared/SyncStatusIndicator.swift) | 31 | Sync state |
| [EmptyStateView.swift](FitTracker/Views/Shared/EmptyStateView.swift) | 45 | Empty placeholder |
| [SectionHeader.swift](FitTracker/Views/Shared/SectionHeader.swift) | 49 | Section divider |
| [LiveInfoStrip.swift](FitTracker/Views/Shared/LiveInfoStrip.swift) | 71 | Info banner |
| [ManualBiometricEntry.swift](FitTracker/Views/Shared/ManualBiometricEntry.swift) | 83 | HRV/RHR manual entry |
| [LockedFeatureOverlay.swift](FitTracker/Views/Shared/LockedFeatureOverlay.swift) | 60 | "Coming soon" overlay |
| [RecoverySupport.swift](FitTracker/Views/Shared/RecoverySupport.swift) | 122 | Recovery summary |
| [RecoveryRoutineSheet.swift](FitTracker/Views/Shared/RecoveryRoutineSheet.swift) | 126 | Recovery modal |
| [MilestoneModal.swift](FitTracker/Views/Shared/MilestoneModal.swift) | 54 | Milestone celebration |
| [RootTabView.swift](FitTracker/Views/RootTabView.swift) | — | Root tab bar |
| [ConsentView.swift](FitTracker/Views/ConsentView.swift) | — | Privacy consent |

---

## 2. iOS Design System

### Tokens — `design-tokens/tokens.json` → Style Dictionary → [`AppTheme.swift`](FitTracker/Services/AppTheme.swift)

**~125 semantic tokens** across 5 categories:
- **`AppColor`** — 40+ named colors (brand, neutral, semantic feedback)
- **`AppText`** — 20+ text styles (heading, body, caption, label)
- **`AppSpacing`** — 12 scales (xs, sm, md, lg, xl, 2xl, …)
- **`AppRadius`** — 5 scales (sm, md, pill, lg, full)
- **`AppMotion`** — 2 easing curves, 3 durations

### Components — [`FitTracker/DesignSystem/`](FitTracker/DesignSystem/)
| Component | Role |
|-----------|------|
| [AppComponents.swift](FitTracker/DesignSystem/AppComponents.swift) | 13 reusable primitives |
| [AppPalette.swift](FitTracker/DesignSystem/AppPalette.swift) | Color system (light + dark) |
| [DesignTokens.swift](FitTracker/DesignSystem/DesignTokens.swift) | Auto-generated token defs |
| [AppViewModifiers.swift](FitTracker/DesignSystem/AppViewModifiers.swift) | Custom modifiers (shadows, borders, animations) |
| [AppMotion.swift](FitTracker/DesignSystem/AppMotion.swift) | Animation curves + durations |
| [AuthSharedComponents.swift](FitTracker/DesignSystem/AuthSharedComponents.swift) | Auth-specific (forms, inputs) |
| [ProgressBar.swift](FitTracker/DesignSystem/ProgressBar.swift) | Macro progress |
| [AppIcon.swift](FitTracker/DesignSystem/AppIcon.swift) | App icon assets |
| [FitMeBrandIcon.swift](FitTracker/DesignSystem/FitMeBrandIcon.swift) | Brand logo SVG |
| [FitMeLogoLoader.swift](FitTracker/DesignSystem/FitMeLogoLoader.swift) | Animated logo loading |

### Health
- **UI audit baseline:** 0 P0 (since 2026-05-05)
- **Current P1 drift:** +5 from 103 baseline → 108 (fix-as-you-touch active)
- **Dark mode coverage:** 38 of 41 colorsets (93%)
- **CI gates:** `make tokens-check` (drift) + `make ui-audit` (raw literals + magic numbers)

---

## 3. fitme-story Public Routes (`src/app/`)

Next.js 16 + App Router + MDX + Tailwind + Vercel.

| Path | Role |
|------|------|
| `/` | Landing (Hero, Numbers, OriginNarrative, ThreeWaysIn, Timeline) |
| `/about` | Company story + mission |
| `/glossary` | 46 framework terms (TypeScript enum) |
| `/design-system` | Component showcase |
| `/research` | Research findings + whitepapers |
| `/pm-flow` | PM workflow viz (LifecycleLoop, CacheTiers, LegoBrick wall) |
| `/trust` | Trust + transparency hub |
| `/trust/audits/2026-04-21-gemini` | Gemini audit findings + remediation |
| `/framework` | Framework overview + version timeline |
| `/framework/dev-guide` | Dev quick-start |
| `/framework/dispatch` | Dispatch intelligence deep-dive |
| `/case-studies` | Case study index (24+ studies, comparison table) |
| `/case-studies/[slug]` | Individual case study (dynamic) |
| `/case-studies/compare` | Side-by-side comparison |
| `/case-studies/operations-layer` | UCC case study |
| `/timeline` | Framework version timeline index |
| `/timeline/[version]` | Version-specific timeline |

---

## 4. fitme-story Control Room (`/control-room/*`)

Basic-auth gated (passkey upgrade tracked in `ucc-passkey-auth` feature).

### Routes
| Path | Role |
|------|------|
| `/control-room` | Dashboard overview, phase activity |
| `/control-room/sign-in` | Auth sign-in (basic-auth form) |
| `/control-room/sign-in/recover` | Password recovery |
| `/control-room/board` | Kanban (features by phase) |
| `/control-room/framework` | Framework health (27+ gates, adoption trends) |
| `/control-room/knowledge` | Knowledge graph + doc search |
| `/control-room/tasks` | Active task tree with deps |
| `/control-room/table` | Raw feature state table |
| `/control-room/settings/audit` | Audit log view |
| `/control-room/settings/devices` | Connected device management |

### Components (19 files in `src/components/control-room/`)
- `CommandPalette.tsx` (255) — Quick command + nav
- `FeatureCard.tsx` (196) — Feature state card
- `TaskCard.tsx` (130) — Task + deps
- `TaskTree.tsx` (167) — Hierarchical task tree
- `PhaseLegendAndActivity.tsx` (216) — Phase definitions + activity
- `AuditLogPanel.tsx` (101) — Audit log reader
- `AuditEventRow.tsx` (120) — Audit event row
- `SourceHealth.tsx` (111) — External sync status (Linear, Notion, GitHub)
- `AlertsBanner.tsx` (123) — P0/P1 alerts
- `InstrumentedAlertsBanner.tsx` (52) — Instrumented tracking
- `DataFreshnessFooter.tsx` (92) — Last sync timestamp
- `DevicesTable.tsx` (153) — Connected devices
- `ThemeToggle.tsx` (92) — Dark/light toggle
- `AuthPasskeyForm.tsx` (264) — WebAuthn registration (future)
- `primitives.tsx` (304) — UI primitives
- `TrackPageView.tsx`, nav/link trackers

---

## 5. fitme-story Shared Components

### Home (7, ~366 LOC)
Hero, HeroSubtitle, NumbersPanel, OriginNarrative, ThreeWaysIn, Timeline, TimelineNode

### Case Study (27, ~2,600 LOC)
Templates: StandardTemplate, FlagshipTemplate, LightTemplate.
Comparison: CaseStudyComparisonTable, CaseStudyToolbar.
Navigation: ArticleNav.
Visualizations: BeforeAfter, HeroMetric, DurationStack, FlowDiagram, FrameworkAdvancement, ParallelGantt, RaceTimeline, RankedBars, PRStackDiagram, AuditFunnel, FullCaseStudyLink, alt-a-chrome (408+85 lines)

### Framework Health (6, ~800 LOC)
AutomationMap, AdoptionTrendChart, DocDebtTrendChart, CycleSnapshotPanel, HumanActionPanel, MembraneStatusPanel

### MDX (16, ~520 LOC)
CopyButton, Figure, FindingsTable, MetricsCard, Pre, Pullquote, Term, TimelineNav, DevDive, plus 5 callouts (HonestDisclosure, KillCriterionResolution, MemoryRef, PredecessorChain, TriggerIncident)

### PM Flow (7, ~1,300 LOC)
LifecycleLoop (718), LegoBrick (247), LegoWall (177), CacheTiers (47), EvolutionStrip (105), PmFlowHero (34), SharedDataTiles (55)

### Bespoke Visualizations (4, ~600 LOC)
DispatchReplay (252), PhaseTimingChart (67), BlueprintOverlay (64), ChipAffinityMap (62)

### Nav + Layout
SiteHeader (130), SiteFooter (31), MobileNav, PersonaBar, PersonaLens, PersonaIndicator

### UI Primitives
ui/Disclosure (75)

---

## 6. In-Flight UI/UX Work + Open PRD Tasks

### High-priority UX backlog (from `docs/product/backlog.md` + 2026-05-08 audit synthesis)

| Item | Status | Notes |
|------|--------|-------|
| **P-MOBNAV** Mobile nav improvements | BACKLOG | Chart goal target lines, tap-to-tooltip charts not wired end-to-end |
| **P-CALLOUTS** MDX callout styling | BACKLOG | 5 callout components exist; presentation readability refactor pending |
| **P-SEO-META** fitme-story SEO meta tags | BACKLOG | Page-specific OG tags, structured data; using generic defaults today |
| **P-MDX-CODE** Code block styling + copying | IN PROGRESS | CopyButton wired; Pre.tsx needs syntax highlighting upgrade |
| **Readiness-Aware Training Alert (Smart Reminders v2)** | BACKLOG ENHANCEMENT | Pre-training readiness alert via AI avatar + notification |
| **Smart Reminders ↔ Push Notifications v2 deep-link integration** | UNBLOCKED | Push v2 shipped 2026-05-07; can ship as enhancement now |
| **Passkey Auth for UCC** | SHIPPED 2026-05-07 (PR #248/#249) | Cutover pending: `UCC_AUTH_MODE=basic` → `passkey` |
| **Framework v7.8 Branch Isolation + Feature-Closure Completeness** | SHIPPED 2026-05-07 | Advisory mode; v7.9 promotion 2026-05-21 |
| **Chart goal target lines** | BACKLOG | Weight/BF goals not overlaid on stats charts |
| **Chart tap-to-tooltip** | BACKLOG | v2 spec mentions; status unclear |
| **HRV trend alerts** | BACKLOG | No notification when HRV drops below threshold for 3+ days |
| **Exercise search/filter** | BACKLOG | 87 exercises in fixed order; no search |
| **Notification settings UI** | BACKLOG | Backend prefs store exists; no user-facing screen |
| **Dark mode end-to-end test** | BACKLOG | Asset values exist; not device-verified |
| **Dynamic Type compliance** | BACKLOG | `@ScaledMetric` not applied to all text tokens |
| **Code Connect (Figma↔Swift)** | BACKLOG | Design-to-code mapping infra not active |
| **Case-study presentation refactor** | SHIPPED 2026-04-28 | fitme-story PR #8 + FT2 PR #146 |

### Active Feature PRDs with UI scope
| Feature | Phase | UI status |
|---------|-------|-----------|
| import-training-plan | complete | Phase 1 SHIPPED (PR #234, 2026-05-06): ImportedPlansListScreen + DataSyncSettings + Training-tab toolbar |
| push-notifications-v2 | complete | SHIPPED (PR #239, 2026-05-07): SettingsDeepLinkBanner, priming view revived, 3 reminder states |
| framework-v7-8-branch-isolation | complete | Shipped 2026-05-07; advisory mode |
| ucc-passkey-auth | complete | Shipped 2026-05-07; cutover pending |

### v4.X Skill-Layer Gates (live as of 2026-05-06)
- `/ux preflight` — spec → codebase token/component verification
- `/design preflight` — Figma MCP liveness + library accessibility
- `/design build` — Phase 3.j auto-dispatch, push screens → Figma library
- `/ux pre-merge-review` — Phase 6 spec ↔ code heuristic check
- `/design pre-merge-review` — `make ui-audit` P0=0 + Figma node IDs in PR

### Recent UI/UX case studies
- [`import-training-plan-case-study.md`](docs/case-studies/import-training-plan-case-study.md) (2026-05-06) — 18 tasks, 33 tests
- [`push-notifications-v2-case-study.md`](docs/case-studies/push-notifications-v2-case-study.md) (2026-05-07) — Platform layer rebuild, 16 tasks
- [`onboarding-v2-auth-flow-v5.1-case-study.md`](docs/case-studies/onboarding-v2-auth-flow-v5.1-case-study.md) (2026-04-15) — 7-step + embedded auth
- [`home-today-screen-v2-ux-alignment-case-study.md`](docs/case-studies/home-today-screen-v2-ux-alignment-case-study.md) (2026-04-09) — ReadinessCard hero, 27 findings fixed

---

## 7. Outstanding Design Debt

- **UI audit (2026-05-08):** 0 P0, 108 P1 (+5 drift from 103 baseline)
- **Documentation debt:** 7 open items (Tier 3.2 baseline)
- **Code Connect (Figma↔Swift mapping):** infrastructure not wired
- **fitme-story SEO meta tags:** page-specific OG / structured data missing
- **Dynamic Type:** incomplete rollout
- **v7.9 framework promotion window:** opens 2026-05-11 (+7d measurement calibration)

---

## Summary

**FitTracker2 (iOS):** 113+ Swift views across 11 feature folders + shared components. Dual-track v1 (HISTORICAL) ↔ v2 (canonical). Design system: ~125 semantic tokens + 13 components, full token pipeline. UI audit baseline clean; dark mode 93%.

**fitme-story (Next.js):** 17 public routes + 10 control-room routes. 70+ shared components (home, case-study, framework-health, MDX, PM-flow, bespoke viz). Control room migrated from Astro 2026-05-06; case-study presentation standardized 2026-04-28.

**In flight:** All major UI features for May 2026 SHIPPED (import, push v2, branch isolation, passkey). Next picks (4 themes):
1. **Readiness-Aware Training Alert** (Smart Reminders v2 enhancement, BACKLOG)
2. **fitme-story P-* polish series** (P-MOBNAV, P-SEO-META, P-CALLOUTS, P-MDX-CODE)
3. **UCC passkey cutover** (currently `UCC_AUTH_MODE=basic`; flip pending)
4. **Chart goal-target overlays + tooltip interaction** (UX gap on stats v2)
