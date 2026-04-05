# PRD: Onboarding Flow

> **Owner:** Regev
> **Date:** 2026-04-05
> **Phase:** Phase 1 — PRD
> **Status:** In Review

---

## Purpose

Guide new FitMe users through goal selection, profile setup, and HealthKit authorization in a 5-screen progressive flow — maximizing D1 retention and enabling AI-powered personalization from the first session.

## Business Objective

Onboarding is the highest-leverage retention intervention. Industry benchmarks show users who complete onboarding have 2-3x higher D7 retention. FitMe's AI engine and readiness scoring depend on user goal, training level, and HealthKit data — without onboarding, these features start cold. A well-designed flow also drives HealthKit authorization (critical for readiness) and goal setting (critical for macro targets and AI recommendations).

## Target Persona(s)

| Persona | Relevance |
|---------|-----------|
| The Consistent Lifter | Needs to set training goal + experience level for progressive overload tracking |
| Health-Conscious Professional | Needs HealthKit connected for readiness scoring (HRV, sleep, HR) |
| Data-Driven Optimizer | Needs goal + profile for AI recommendations and cohort banding |

## Has UI?

Yes — 5 new screens in a dedicated onboarding flow.

## Functional Requirements

| # | Requirement | Priority | Status | Details |
|---|-------------|----------|--------|---------|
| 1 | Welcome screen with FitMe branding | P0 | Planned | Logo animation (FitMeLogoLoader), tagline, "Get Started" CTA |
| 2 | Goal selection screen | P0 | Planned | 4 cards: Build Muscle / Lose Fat / Maintain / General Fitness |
| 3 | Profile screen | P1 | Planned | Training experience (3 levels) + weekly frequency (2-6 days) |
| 4 | HealthKit permission screen | P0 | Planned | Contextual explanation → system HealthKit auth prompt |
| 5 | First Action screen | P0 | Planned | Personalized dashboard preview + CTA to first workout or meal |
| 6 | Segmented progress bar | P1 | Planned | 5-segment bar at top of each screen showing position |
| 7 | Skip option on non-critical screens | P1 | Planned | "Skip" on Goals, Profile, HealthKit; not on Welcome/First Action |
| 8 | Persist user selections | P0 | Planned | Save goal + experience to UserProfile, set hasCompletedOnboarding flag |
| 9 | Guard against re-showing | P0 | Planned | `UserDefaults.hasCompletedOnboarding` — show only on first launch |
| 10 | Handle returning users | P1 | Planned | If already onboarded, skip directly to auth/home |
| 11 | GA4 analytics events | P0 | Planned | Track each step, completion, skips, permissions |
| 12 | Defer notification permission | P1 | Planned | Request after first completed workout, not during onboarding |

## User Flows

### Primary Flow (Happy Path)
1. User opens app for the first time
2. **Welcome** → sees FitMe logo animation + tagline → taps "Get Started"
3. **Goals** → selects one of 4 goal cards → taps "Continue"
4. **Profile** → selects experience level + weekly frequency → taps "Continue"
5. **HealthKit** → reads explanation → taps "Connect" → approves HealthKit prompt
6. **First Action** → sees personalized dashboard preview → taps "Start Your First Workout" or "Log Your First Meal"
7. Lands on Home screen with readiness data populating

### Skip Flow
1. User can tap "Skip" on Goals (defaults to General Fitness), Profile (defaults to Intermediate/3 days), or HealthKit (skips auth)
2. Skipped data can be set later in Settings
3. Skipped screens are tracked via `onboarding_skipped` event

### Returning User Flow
1. User who has `hasCompletedOnboarding = true` bypasses onboarding entirely
2. Goes directly to auth/home screen

## Current State & Gaps

| Gap | Priority | Notes |
|-----|----------|-------|
| No onboarding exists | P0 | New users land on auth screen with no guidance |
| Goal not collected | P0 | AI recommendations and macro targets are generic |
| HealthKit auth not prompted | P0 | ~70% auth rate vs target >85% |
| No first-action guidance | P1 | Users don't know what to do first |
| No progressive profiling | P2 | Body weight, diet prefs deferred to later |

## Acceptance Criteria

- [ ] 5-screen onboarding flow renders correctly on iPhone SE through iPhone 15 Pro Max
- [ ] Goal selection persists to UserProfile and feeds AIOrchestrator
- [ ] Experience level + frequency persist to UserProfile
- [ ] HealthKit authorization flow triggers correctly with contextual explanation
- [ ] Onboarding only shows on first app launch (UserDefaults guard)
- [ ] "Skip" buttons work on screens 2-4 with sensible defaults
- [ ] Progress bar shows correct position on each screen
- [ ] All 7 GA4 events fire correctly with consent gating
- [ ] FitMeLogoLoader animation renders on Welcome screen
- [ ] Under 60 seconds total flow time
- [ ] Notification permission NOT requested during onboarding

---

## Success Metrics & Measurement Plan

### Primary Metric
- **Metric:** Onboarding completion rate (% of users who reach First Action screen)
- **Baseline:** N/A (no onboarding exists)
- **Target:** >80%
- **Timeframe:** Within 30 days of launch

### Secondary Metrics
| Metric | Baseline | Target | Instrumentation |
|--------|----------|--------|-----------------|
| HealthKit authorization rate | ~70% | >85% | HealthKitService + GA4 `permission_granted` |
| D1 retention (post-onboarding users) | — | >60% | Firebase cohort analysis |
| Time to first training session | — | <24 hours | GA4 `workout_start` timestamp delta |
| Goal selection rate | N/A | >70% (not skipped) | GA4 `onboarding_goal_selected` |
| Average onboarding duration | N/A | <60 seconds | GA4 `tutorial_begin` → `tutorial_complete` delta |

### Guardrail Metrics
| Metric | Current Value | Acceptable Range |
|--------|--------------|-----------------|
| Crash-free rate | >99.5% | Must stay >99.5% |
| Cold start time | <2s | Must stay <2s (onboarding adds no cold start cost) |
| Sync success rate | >99% | Must stay >99% |
| Auth flow reliability | >99% | Must not break existing auth |

### Leading Indicators
- >50% of new installs complete onboarding within first 7 days
- >60% of onboarding completers grant HealthKit access
- Onboarding skip rate <20% per screen (average across screens 2-4)

### Lagging Indicators
- D7 retention improves by 10%+ for onboarding completers vs historical baseline
- D30 retention improves by 5%+ for onboarding completers
- HealthKit-connected WAU increases by 15%

### Instrumentation Plan
| Event/Metric | Method | Status |
|-------------|--------|--------|
| Onboarding start | GA4 `tutorial_begin` | Ready (event exists) |
| Step tracking | GA4 `onboarding_step_viewed` | New — define below |
| Step completion | GA4 `onboarding_step_completed` | New — define below |
| Step skipped | GA4 `onboarding_skipped` | New — define below |
| Goal selected | GA4 `onboarding_goal_selected` | New — define below |
| Permission result | GA4 `permission_result` | New — define below |
| Onboarding complete | GA4 `tutorial_complete` | Ready (event exists) |
| HealthKit auth rate | HealthKitService | Available now |
| D1/D7/D30 retention | Firebase cohort | Available now |

### Analytics Spec (GA4 Event Definitions)

#### New Events
| Event Name | Category | GA4 Type | Screen/Trigger | Parameters | Conversion? | Notes |
|------------|----------|----------|----------------|------------|-------------|-------|
| `onboarding_step_viewed` | Engagement | Custom | Each onboarding screen | `step_name`, `step_index` | No | Tracks funnel drop-off per step |
| `onboarding_step_completed` | Engagement | Custom | User taps Continue | `step_name`, `step_index` | No | Completion per step |
| `onboarding_skipped` | Engagement | Custom | User taps Skip | `step_name`, `step_index` | No | Skip rate per step |
| `onboarding_goal_selected` | Engagement | Custom | Goal screen selection | `goal_value` | No | Which goal is most popular |
| `permission_result` | Engagement | Custom | HealthKit auth response | `permission_type`, `granted` | No | Auth grant/deny rate |

#### New Parameters
| Parameter Name | Type | Allowed Values | Used By Events | Notes |
|---------------|------|----------------|----------------|-------|
| `step_name` | string | `welcome`, `goals`, `profile`, `healthkit`, `first_action` | `onboarding_step_viewed`, `onboarding_step_completed`, `onboarding_skipped` | Max 20 chars |
| `step_index` | int | 0-4 | `onboarding_step_viewed`, `onboarding_step_completed`, `onboarding_skipped` | 0-based screen index |
| `goal_value` | string | `build_muscle`, `lose_fat`, `maintain`, `general_fitness` | `onboarding_goal_selected` | Matches UserProfile goal enum |
| `permission_type` | string | `healthkit`, `notifications` | `permission_result` | Type of system permission |
| `granted` | string | `true`, `false` | `permission_result` | Whether user granted permission |

#### New Screens
| Screen Name | View Name | SwiftUI View | Category |
|-------------|-----------|--------------|----------|
| Onboarding Welcome | `onboarding_welcome` | `OnboardingWelcomeView` | auth |
| Onboarding Goals | `onboarding_goals` | `OnboardingGoalsView` | auth |
| Onboarding Profile | `onboarding_profile` | `OnboardingProfileView` | auth |
| Onboarding HealthKit | `onboarding_healthkit` | `OnboardingHealthKitView` | auth |
| Onboarding First Action | `onboarding_first_action` | `OnboardingFirstActionView` | auth |

#### New User Properties
| Property Name | Type | Values | Notes |
|--------------|------|--------|-------|
| `onboarding_completed` | string | `true`, `false` | Whether user finished onboarding (7th user property — still under 25 limit) |

#### Naming Validation Checklist
- [x] All event names: snake_case, <40 chars
- [x] All parameter names: snake_case, <40 chars
- [x] No reserved prefixes (ga_, firebase_, google_)
- [x] No duplicate names (checked against AnalyticsProvider.swift — no conflicts)
- [x] No PII in any parameter (no emails, names, user IDs)
- [x] ≤25 parameters per event (max 3 per event)
- [x] Total custom user properties still ≤25 (currently 6, adding 1 = 7)
- [x] Parameter values spec'd to max 100 chars
- [x] Conversion events identified — `tutorial_complete` already marked as conversion

#### Files to Update During Implementation
- [ ] `AnalyticsProvider.swift` — add 5 new events, 5 new params, 5 new screens, 1 user property
- [ ] `AnalyticsService.swift` — add typed convenience methods for onboarding events
- [ ] `docs/product/analytics-taxonomy.csv` — add rows to events, screens, and properties sections

### Review Cadence
- **First review:** 1 week post-launch
- **Ongoing:** Weekly for 4 weeks, then monthly

### Kill Criteria
- If onboarding completion rate <50% after 30 days → redesign flow (reduce screens or change content)
- If D1 retention does NOT improve for onboarding completers vs non-completers after 60 days → evaluate whether the flow provides value
- Guardrail: if crash-free rate drops below 99.5% → hotfix immediately

---

## Key Files

| File | Purpose |
|------|---------|
| `FitTracker/Views/Onboarding/OnboardingView.swift` | Main onboarding container + flow navigation |
| `FitTracker/Views/Onboarding/OnboardingWelcomeView.swift` | Screen 1: Welcome with logo |
| `FitTracker/Views/Onboarding/OnboardingGoalsView.swift` | Screen 2: Goal selection cards |
| `FitTracker/Views/Onboarding/OnboardingProfileView.swift` | Screen 3: Experience + frequency |
| `FitTracker/Views/Onboarding/OnboardingHealthKitView.swift` | Screen 4: HealthKit auth |
| `FitTracker/Views/Onboarding/OnboardingFirstActionView.swift` | Screen 5: Personalized CTA |
| `FitTracker/Views/Onboarding/OnboardingProgressBar.swift` | Reusable 5-segment progress bar |
| `FitTracker/Models/UserProfile.swift` | Updated with goal + experience fields |
| `FitTracker/FitTrackerApp.swift` | Onboarding gate before auth/home |
| `FitTracker/Services/Analytics/AnalyticsProvider.swift` | New event/param/screen constants |
| `FitTracker/Services/Analytics/AnalyticsService.swift` | New convenience methods |

## Dependencies & Risks

| Dependency/Risk | Mitigation |
|----------------|------------|
| HealthKit authorization is one-time — can't re-prompt if denied | Show compelling explanation before system prompt; provide Settings deep link as fallback |
| UserProfile model changes may affect sync | Verify SupabaseSyncService handles new fields gracefully |
| FitMeLogoLoader on Welcome screen may be slow on iPhone SE | Test on oldest supported device; use `.pulse` animation mode (lightest) |
| Onboarding gate in FitTrackerApp.swift touches high-risk file | Minimal change — single `if !hasCompletedOnboarding` guard |
| Goal/experience defaults for skipped screens may not match user | Defaults chosen to be "middle of the road" (General Fitness, Intermediate, 3 days) |

## Estimated Effort

- **Total:** ~1 week
- **Breakdown:** Research: 0.5d (done), PRD: 0.5d (this), UX: 0.5d, Implementation: 3d, Testing: 1d, Review+Merge: 0.5d
