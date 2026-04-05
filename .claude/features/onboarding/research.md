# Onboarding — Phase 0: Research & Discovery

> **Date:** 2026-04-05
> **Feature:** onboarding
> **Researcher:** Claude Opus 4.6

---

## 1. What is this solution?

A 5-screen progressive onboarding flow that guides new FitMe users through goal selection, profile setup, and HealthKit permissions — maximizing D1 retention and enabling AI-powered personalization from the first session.

## 2. Why this approach?

**Problem:** New users currently land on the auth screen, then drop into the full app with no guidance. They don't set goals (AI can't personalize), don't grant HealthKit access (readiness scoring breaks), and don't understand the app's value proposition. Industry benchmarks show users who complete onboarding have 2-3x higher D7 retention.

**User pain points:**
- No orientation — "what do I do first?"
- No goal context — AI recommendations are generic
- HealthKit not connected — readiness scoring is empty
- No path to first meaningful action

## 3. Alternatives Comparison

| Approach | Pros | Cons | Effort | Chosen? |
|----------|------|------|--------|---------|
| **Progressive 5-screen flow** | Proven pattern, collects essential data, contextual permissions | Adds friction before first use | 1 week | **Yes** |
| **Zero onboarding (Strong/Hevy style)** | Fastest time-to-value, minimal friction | No personalization data, cold-start AI problem, lower HealthKit auth rate | 0 | No — FitMe needs goal/profile data for AI |
| **Extended questionnaire (Fitbod/MacroFactor style)** | Deep personalization from day 1 | 8-10 screens, ~10% completion drop per screen beyond 5 | 1.5 weeks | No — overkill for MVP |
| **Progressive profiling (defer everything)** | Zero friction, collect over first week | Delayed personalization, users may never complete setup | 0.5 week | No — HealthKit auth needs to happen early |

**Decision:** Progressive 5-screen flow. FitMe's AI and readiness features depend on goal + profile + HealthKit data — a minimal upfront flow is justified. Strong/Hevy can skip onboarding because they're pure logging tools. FitMe's intelligence layer needs input.

## 4. Competitor Analysis

| App | Screens | Key Asks | Notable Pattern |
|-----|---------|----------|-----------------|
| **MyFitnessPal** | 8-10 | Goal, weight, target, activity level, calorie preview | Shows calorie goal before signup — demonstrates value early |
| **Hevy** | 3-4 | Account, optional gym, straight to logging | Minimal friction, defers personalization |
| **Strong** | 2-3 | Near-zero; account optional | Fastest to value but risks feeling "empty" |
| **Strava** | 5-6 | Account, sports, social graph, permissions, first activity | Contextual permission requests ("to track your run, we need location") |
| **Fitbod** | 6-8 | Experience, equipment, muscle groups, goals, body metrics | Deep upfront profiling — justified because AI workout generation depends on it |
| **MacroFactor** | 7-9 | Goal, body metrics, diet history, macro philosophy | Longest flow but explains WHY each screen matters — high perceived value |

**Key insight:** Apps that use the data immediately to generate something personalized (Fitbod's workout, MacroFactor's macro plan, MFP's calorie budget) justify longer flows. FitMe should show a personalized dashboard preview after collecting goal + profile.

## 5. Best Practices

- **Optimal screen count:** 3-6 screens. Completion drops ~10% per screen beyond 5.
- **Ask vs defer:** Ask only what changes the first session. Defer body measurements, detailed diet preferences, and profile photo to post-onboarding progressive profiling.
- **Permission timing:** Request permissions in context, not in a batch. HealthKit with explanation converts 20-30% better than a cold system prompt. Defer notifications to after first completed workout.
- **Time-to-value:** Under 60 seconds to see the core screen. Under 90 seconds total onboarding.
- **Progress indicator:** Horizontal segmented bar at top — shows momentum and sets expectations.
- **Skip options:** Always offer "Skip" or "Set up later" on non-critical screens. Never on account creation.
- **Illustrations > screenshots:** Custom illustrations feel premium. Short Lottie animations (<2s) increase completion ~15%.

## 6. Design Inspiration

### UI Patterns That Work
1. **Step-by-step with progress bar** — dominant pattern (5/6 competitors use it). Carousel/swipe is falling out of favor; feels passive.
2. **Single-choice cards** — large tappable cards for goal selection (Build Muscle / Lose Fat / etc.). Better than dropdowns or small radio buttons.
3. **Contextual permission screens** — explain WHY before the system prompt. "Sync your Apple Watch data to track recovery" → then HealthKit prompt.
4. **Value preview** — after collecting goal + level, briefly show what the personalized dashboard will look like. This is the "aha moment" before any permission ask.
5. **FitMe brand animation** — use FitMeLogoLoader on welcome screen with the intertwined circles and brand colors.

### Visual References
- FitMe brand: deep purple background, neon intertwined circles (magenta, cyan, yellow, blue)
- Figma file: `0Ai7s3fCFqR5JXDW8JvgmD` — App Icon page has the brand direction
- Design tokens: `AppGradient.screenBackground`, `AppColor.Brand.*`, `AppText.*`

## 7. Data & Demand Signals

- **PRD requirement:** Onboarding is defined in PRD 18.11 as P1 priority
- **GitHub Issue:** #51 — open, priority:high
- **Industry benchmark:** 2-3x higher D7 retention with completed onboarding
- **HealthKit auth rate:** Currently ~70%, target >85% with contextual permission flow
- **AI dependency:** Goal + training level data feeds `AIOrchestrator` for personalized recommendations and `MacroTargetBar` for nutrition targets
- **Readiness scoring:** Requires HealthKit HR/HRV/sleep data — empty without authorization

## 8. Technical Feasibility

**Dependencies:**
- `HealthKitService.swift` — already supports HR, HRV, steps, sleep authorization
- `AIOrchestrator.swift` — accepts user goal and training level for banding
- `UserProfile` model — has goal and experience level fields
- `AnalyticsService` — GA4 instrumented, ready for onboarding events
- `AppTheme.swift` — full design token system available

**Risks:**
- HealthKit authorization is one-time — if user denies, can't re-prompt (must go to Settings)
- Need to handle "already onboarded" state for returning users (UserDefaults flag)
- Animation performance on older devices (iPhone SE)

**Platform constraints:**
- iOS 17+ required (already the app minimum)
- HealthKit not available on iPad — need graceful degradation

## 9. Proposed Success Metrics

| Metric | Type | Baseline | Target |
|--------|------|----------|--------|
| **Onboarding completion rate** | Primary | N/A | >80% |
| HealthKit authorization rate | Secondary | ~70% | >85% |
| D1 retention (post-onboarding) | Secondary | — | >60% |
| Time to first training session | Secondary | — | <24 hours |
| Onboarding skip rate per screen | Leading | N/A | <20% per screen |
| Average onboarding duration | Leading | N/A | <60 seconds |

**Kill criteria:** N/A — onboarding is a standard requirement. But the specific flow design should be validated. If completion rate is <50% after 30 days, redesign the flow.

## 10. Recommended Approach

**5-screen progressive flow with 3 adjustments from research:**

1. **Welcome** — FitMe logo animation (FitMeLogoLoader), tagline "Your fitness command center", "Get Started" CTA
2. **Goals** — 4 large tappable cards: Build Muscle / Lose Fat / Maintain / General Fitness. Skippable.
3. **Profile** — Training experience (Beginner/Intermediate/Advanced) + weekly frequency (2-6 days). Skippable.
4. **HealthKit** — Contextual explanation with visual ("Sync your Apple Watch to track recovery") → trigger HealthKit auth prompt. **Defer notification permission to after first workout.**
5. **First Action** — Personalized dashboard preview based on selected goal + "Start Your First Workout" or "Log Your First Meal" CTA

**Key design decisions:**
- Segmented progress bar at top of each screen
- "Skip" option on screens 2, 3, 4 (not on Welcome or First Action)
- FitMe brand animation on Welcome screen
- Single-choice cards (not dropdowns) for goal and experience
- Under 60 seconds total target
- `UserDefaults.hasCompletedOnboarding` flag to prevent re-showing
