# UX Foundations — FitMe

> **Purpose:** The grounding reference for every UI decision in FitMe. This document defines _how_ the app should behave, not just _what_ it should look like. Visual tokens (`AppTheme.swift`) describe appearance; this document describes experience.
>
> **Audience:** Designers, developers, PM workflow agents, anyone making UX decisions.
>
> **When to consult:** Before writing any new screen, before validating any feature, before resolving any UX disagreement.
>
> **Related documents:**
> - `docs/design-system/ux-copy-guidelines.md` — tone, voice, copy patterns
> - `docs/design-system/component-contracts.md` — per-component interaction behavior
> - `docs/design-system/feature-design-checklist.md` — pre-implementation validation
> - `docs/design-system/feature-development-gateway.md` — 7-stage workflow
> - `docs/design-system/responsive-handoff-rules.md` — responsive design contract
> - `.claude/skills/ux/SKILL.md` — UX planning skill that consults this document

---

## Table of Contents

1. [Design Philosophy & Principles](#part-1-design-philosophy--principles)
2. [Information Architecture](#part-2-information-architecture)
3. [Interaction Patterns](#part-3-interaction-patterns)
4. [Data Visualization Patterns](#part-4-data-visualization-patterns)
5. [Permission & Trust Patterns](#part-5-permission--trust-patterns)
6. [State Patterns](#part-6-state-patterns)
7. [Accessibility Standards](#part-7-accessibility-standards)
8. [Micro-Interactions & Motion](#part-8-micro-interactions--motion)
9. [Content Strategy](#part-9-content-strategy)
10. [Platform-Specific Patterns](#part-10-platform-specific-patterns)

---

## Part 1: Design Philosophy & Principles

### Core Principles (8) — Universal UX Heuristics Applied to Fitness

#### 1.1 Fitts's Law

**Definition:** The time to acquire a target is a function of the distance to and size of the target. Larger and closer targets are faster to reach.

**Why it matters for fitness:** Users log data with sweaty hands, sometimes wearing gloves, often mid-workout. Touch precision is degraded. Primary actions must be impossible to miss.

**FitMe application:**
- Set logging buttons in `TrainingPlanView` are full-row tappable (not just the small checkmark icon)
- Primary CTAs (Get Started, Continue, Save) anchor to bottom of screen for thumb reach, 52pt height with 20px corner radius
- Tab bar uses iOS standard 49pt height with 44pt minimum tap target per tab

**Do:**
```swift
// ✅ Full-width button, easy to hit
Button("Save Workout") { ... }
    .frame(maxWidth: .infinity)
    .frame(height: 52)
```

**Don't:**
```swift
// ❌ Small button in awkward position
Button("Save") { ... }
    .frame(width: 60, height: 28)
    .padding(.top, 200)
```

---

#### 1.2 Hick's Law

**Definition:** The time it takes to make a decision increases with the number and complexity of choices.

**Why it matters for fitness:** Users opening the app mid-rest-break have 30-60 seconds to make a decision before their next set. Decision paralysis kills momentum.

**FitMe application:**
- Onboarding goal selection: exactly 4 options (Build Muscle, Lose Fat, Maintain, General Fitness) — not 10
- Home screen surfaces ONE primary action: today's workout or today's meal log
- Settings groups 19 options into 9 categories — never a flat list of 19

**Do:** Limit to max 4-6 options per screen. Group related items. Use progressive disclosure for advanced features.

**Don't:** Show every available action on the home screen. Force users to scan a long list to find the common case.

---

#### 1.3 Jakob's Law

**Definition:** Users spend most of their time on other apps. They expect your app to work the same way.

**Why it matters for fitness:** FitMe competes with Strava, Apple Health, MyFitnessPal, Hevy. Users have muscle memory for tab bars at the bottom, swipe-back navigation, sheets with grab handles, search at the top of lists.

**FitMe application:**
- Bottom tab bar (iOS standard) — not custom hamburger menu
- Push navigation with swipe-back gesture
- Sheets dismiss with swipe-down (matches iOS modal pattern)
- Settings looks like the iOS Settings app (grouped categories with chevrons)

**Do:** Follow iOS Human Interface Guidelines. Use SwiftUI's native components when possible.

**Don't:** Invent custom navigation patterns. Don't put the back button in the bottom-right because it "feels modern."

---

#### 1.4 Progressive Disclosure

**Definition:** Show only what's necessary in the moment. Reveal complexity on demand.

**Why it matters for fitness:** Health data is dense. A complete biometric panel has 10+ values (HR, HRV, sleep duration, sleep quality, RHR, weight, body fat, hydration, mood, soreness). Showing all of them upfront overwhelms users.

**FitMe application:**
- `ReadinessCard` shows ONE number (readiness score) by default. Tap to reveal the 6-page breakdown (HRV, sleep, RHR, recovery trend, training load, stress).
- `MetricCard` shows headline value + trend arrow. Tap to drill into chart with full history.
- Onboarding asks ONE question per screen, not 10 fields on a single form.

**Real-world example:** Apple Health summary cards show one metric + sparkline + trend arrow. Tapping reveals a full chart. Tapping the chart reveals individual data points.

**Do:** Lead with the headline. Make detail one tap away.

**Don't:** Cram every available field into the first view. Don't make users learn the app to use it.

---

#### 1.5 Recognition Over Recall

**Definition:** Visible options are easier than memorized commands. Show users what they can do; don't make them remember.

**Why it matters for fitness:** Users open the app once a day for ~3 minutes during a workout. They forget where features live. Hidden gestures and memorized commands fail.

**FitMe application:**
- Day-type badge always visible on home (Push / Pull / Legs / Rest) — users don't need to remember today's split
- Macro progress bars on `NutritionView` show current vs. target — users don't need to remember their daily protein goal
- Streak counter on home — users see their consistency without checking history

**Do:** Make state visible. Use badges, indicators, progress bars.

**Don't:** Hide critical state behind tabs or modals. Don't require users to "go check" their goal.

---

#### 1.6 Consistency

**Definition:** Internal consistency (FitMe's own patterns) and external consistency (iOS conventions).

**Why it matters for fitness:** Users build muscle memory. If the "save" button is bottom-right on one screen and top-right on another, every tap becomes a hesitation.

**FitMe application:**
- Card layout consistent: `AppCard` always has 16px radius, card shadow, 16pt internal padding
- Section headers consistent: `SectionHeader` component, never raw `Text` with custom styling
- Button styles consistent: `AppButton` with 4 hierarchies (primary, secondary, tertiary, destructive)

**Do:** Use shared components. Reference `docs/design-system/component-contracts.md` before creating new patterns.

**Don't:** Style each screen differently because "this one is special."

---

#### 1.7 Feedback

**Definition:** Every user action gets an immediate response (visual, haptic, or audio) within 100ms.

**Why it matters for fitness:** During a workout, users don't have time to wonder "did that save?" They need instant confirmation.

**FitMe application:**
- Set completion: `.medium` haptic + checkmark animation + row slides to "completed" state
- PR achieved: `.success` haptic + brief glow animation on the metric
- Save action: bottom toast confirmation ("Workout saved")
- Sync in progress: `FitMeLogoLoader` with `.breathe` mode
- Button press: `.light` haptic, brief opacity fade

**Do:** Pair every action with feedback. Use `AppMotion` and `UIFeedbackGenerator`.

**Don't:** Leave users wondering. Don't queue feedback for after a network round-trip.

---

#### 1.8 Error Prevention

**Definition:** Design to prevent mistakes, not just handle them after the fact.

**Why it matters for fitness:** Health data is precious. A user who accidentally deletes 3 months of workout history will never trust the app again.

**FitMe application:**
- Account deletion has 30-day grace period (`AccountDeletionService`) — users can recover within the window
- Destructive actions require confirmation modal with explicit "I understand" toggle
- Form validation happens inline as user types, not on submit
- Sync conflicts surface a diff view, not a "your data was overwritten" message

**Do:** Make destructive actions reversible. Confirm before deleting. Validate as you type.

**Don't:** Show a generic error after the user tapped "Delete." Don't validate only on submit.

---

### FitMe-Specific Principles (5) — Domain Heuristics

#### 1.9 Readiness-First

**Definition:** Always lead with "how am I doing today?" before "what should I do?"

**Why this principle exists:** Recovery and readiness are FitMe's competitive moat. Strava shows distance. MyFitnessPal shows calories. Hevy shows volume. FitMe leads with how the user feels, then guides what they should do based on that signal.

**FitMe application:**
- Home screen layout: `ReadinessCard` is the first card, before today's workout
- Training plan adapts to readiness: low readiness → suggest deload; high readiness → suggest PR attempt
- Stats default view: recovery metrics (HRV, sleep) above performance metrics (volume, PRs)

**Do:** Open with the user's state. Let the data inform what comes next.

**Don't:** Force users into "today's workout" without acknowledging fatigue. Don't bury readiness behind a tab.

---

#### 1.10 Zero-Friction Logging

**Definition:** Every data entry should be completable in under 10 seconds.

**Why this principle exists:** Fitness apps fail when logging becomes a chore. The best workout log is the one that's actually used. Strava wins on simplicity (start workout → done). Hevy wins on tap-to-log with smart defaults.

**FitMe application:**
- Set logging: previous values auto-populate (weight, reps from last session)
- Meal entry: 4 entry methods (smart capture, manual, template, search) — pick the fastest for the situation
- Biometric entry: HealthKit auto-syncs HR/HRV/sleep — manual entry only for things HealthKit doesn't capture (weight, mood)
- Quick actions: home screen has one-tap access to "Log meal" and "Start workout"

**Do:** Pre-fill everything you can. Default to the user's most common case. Make the happy path one tap.

**Don't:** Make users re-enter values they entered last week. Don't show empty forms.

---

#### 1.11 Privacy by Default

**Definition:** Encrypt first, explain later. Health data never leaves the device unencrypted. Analytics never see raw values.

**Why this principle exists:** Health data is the most sensitive personal data category. Users trust FitMe with workout history, weight, body fat, sleep patterns, mood. A single leak destroys the trust.

**FitMe application:**
- All sync uses AES-256-GCM + ChaCha20-Poly1305 (`EncryptionService`)
- Analytics events never include raw health values — only categorical bands ("logged_workout", not "logged 200lb bench press")
- ATT and GDPR consent are explicit, granular, and reversible
- "Privacy" and "Encryption" are visible labels in Settings, not buried in legal text

**Do:** Encrypt by default. Surface privacy as a feature, not a disclosure.

**Don't:** Send raw health data to analytics. Don't request permissions in batches at launch.

---

#### 1.12 Progressive Profiling

**Definition:** Don't ask everything upfront. Learn from behavior over time.

**Why this principle exists:** Onboarding completion rates die after 5 questions. Users who answer fewer questions during onboarding stay longer and engage more (see onboarding research in `.claude/features/onboarding/research.md`).

**FitMe application:**
- Onboarding asks 4 things: goal, experience level, frequency, HealthKit access. Skip is allowed on 3 of 4.
- Body weight, body fat, training history are NOT collected upfront — they appear naturally in the flow when first needed
- Diet preferences, allergies, supplements: deferred to Settings, user adds when ready
- AI recommendations improve as the user logs more — the system learns rather than asking

**Do:** Collect minimum viable data upfront. Learn the rest from behavior.

**Don't:** Force users through a 10-question profiling form before they can use the app.

---

#### 1.13 Celebration Not Guilt

**Definition:** Highlight streaks, PRs, and effort. Never shame missed days or unmet goals.

**Why this principle exists:** Fitness apps that punish users for missing days lose users. Fitness apps that celebrate consistency keep users. Strava's kudos system, Apple's activity rings, and Duolingo's streak savers all use positive reinforcement.

**FitMe application:**
- Missed workout: silent. No "you skipped Tuesday" notification.
- Streak indicator shows consecutive days, never "longest broken streak"
- PR detection: animation + haptic + temporary celebration card on home
- Rest days are explicitly "Recovery Day" — not "Day Off" or "No Workout"
- Macro under-target: shows remaining, not "you missed your goal"

**Do:** Celebrate effort. Treat rest as part of training.

**Don't:** Use red text for "missed." Don't send guilt-trip notifications. Don't compare users to other users.

---

### How to Apply These Principles

When designing any new feature, the `/ux research` skill walks through this checklist:

1. **Which principles apply?** Not all 13 apply to every feature. Identify the relevant ones.
2. **How does each apply?** Concrete design decision per principle.
3. **Where could violations happen?** Pre-emptively flag risks.
4. **What's the test?** How will you verify the principle is honored in the final implementation?

This produces the "Principle Application Table" in every `ux-spec.md` (see `.claude/features/gdpr-compliance/ux-spec.md` for an example).

---
