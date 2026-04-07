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

## Part 2: Information Architecture

### 2.1 The Fundamental Axis: Today vs. History

FitMe organizes around **temporal context** — the same axis used by every successful fitness app:

- **Today** (the active state): What should I do? How am I doing? What's my readiness?
- **History** (the archive): How did I do? What patterns are emerging? What progressed?

Every screen is on one side of this axis. The home screen, training plan, nutrition tracker, and biometric entry are **today** surfaces. The stats hub, workout history, and progress charts are **history** surfaces.

### 2.2 Tab Bar Structure

FitMe uses a 4-tab bottom bar — iOS standard, matches Strava (Feed/Maps/Record/Groups/You) and Hevy (Log/Routines/History/Profile).

| Tab | Purpose | Side of Axis |
|-----|---------|--------------|
| **Home** | Readiness, today's plan, quick actions, 7-day trends | Today |
| **Training** | Today's session, exercise logging, program view | Today |
| **Nutrition** | Today's macros, meal log, supplement tracking | Today |
| **Stats** | Charts, metrics, trends, history | History |

**Settings & Account** are accessed via an **account avatar button in the top-right toolbar of every screen** (see `RootTabView.swift` line 141, `accountButton`). Tapping it presents `AccountPanelView` as a sheet, which contains profile, settings, and account actions. This is not a 5th tab — it's a global toolbar action available from any context, keeping the tab bar focused on daily use surfaces.

**Why 4 tabs, not 5?**
- Hick's Law: 4 options is the cognitive sweet spot
- Thumb reach: 4 tabs at 393pt screen width = 98pt per tab, comfortable thumb zone
- Apple HIG recommends 3-5 tabs

### 2.3 Content Hierarchy Per Tab

#### Home Tab
```
Home
├─ Greeting + date strip (LiveInfoStrip)
├─ Readiness card (ReadinessCard — 6 rotating pages)
├─ Today's plan card (workout type + suggested exercises)
├─ Quick actions row (Log meal, Start workout, Log biometric)
└─ 7-day trend strip (mini metric cards)
```

#### Training Tab
```
Training
├─ Today's session header (day type badge + readiness adjusted suggestion)
├─ Exercise list (AppCard per exercise)
│   └─ Tap to enter active workout
├─ Active Workout (full-screen modal)
│   ├─ Set entry (auto-populated from previous session)
│   ├─ Rest timer overlay
│   └─ Completion sheet (volume delta + PRs)
└─ Workout history (push, secondary path)
```

#### Nutrition Tab
```
Nutrition
├─ Macro target bars (protein, carbs, fat, calories)
├─ Meal sections (breakfast, lunch, dinner, snacks)
│   └─ Tap "+" to open meal entry sheet
├─ Meal Entry Sheet (4 tabs: Smart, Manual, Template, Search)
└─ Supplements row (daily checklist)
```

#### Stats Tab
```
Stats
├─ Period selector (week, month, quarter, year, all-time)
├─ Recovery metrics section (HRV, sleep, RHR — Readiness-First principle)
├─ Body composition section (weight, body fat, lean mass)
├─ Performance section (volume, PRs by exercise)
├─ Nutrition section (macro adherence, calorie trend)
└─ Tap any metric → push to ChartCard detail view
```

### 2.4 Depth Limit Rule

**Maximum navigation depth: 3 levels from any tab.**

```
Tab → Section → Detail   (3 levels — OK)
Tab → Section → Sub      (3 levels — OK)
Tab → Section → Detail → Sub-detail   (4 levels — NOT OK)
```

**Why:** Beyond 3 levels, users lose context and the back button becomes a chore. If a feature needs more depth, it belongs in its own modal or sheet, not pushed deeper.

**Examples:**
- ✅ Stats → Body Composition → Weight Chart (3 levels)
- ✅ Training → Active Workout → Exercise Detail (3 levels via push, modal-style)
- ❌ Settings → Account → Email → Verification → Confirmation (5 levels — collapse into modal flow)

### 2.5 Modal vs. Push Navigation

**Push navigation** is for **reading flows** — drilling into existing content:
- Stats → metric chart (push)
- Training → exercise detail (push)
- Settings → category detail (push)

**Sheets / modals** are for **creation and editing flows** — creating new content:
- Add meal → Meal Entry Sheet (sheet)
- Add biometric → Biometrics Entry (sheet)
- Edit profile → Account Panel (full-screen sheet)
- Delete account → Confirmation modal (modal — destructive)

**Full-screen modals** are reserved for:
- Active workout (immersive, requires focus)
- Onboarding (first-run experience)
- Destructive confirmations (account deletion)

### 2.6 Search & Discovery

As the app grows, search becomes critical for content discovery:

- **Exercise library:** inline search bar at top of `TrainingPlanView` exercise list with real-time filtering
- **Food database:** search tab in `MealEntrySheet` with debounced query (300ms)
- **Settings:** no search (only 9 categories — Hick's Law allows direct scan)

**No global search** — FitMe has tab-scoped search only. A global search bar would be a Jakob's Law violation (iOS apps don't have global search except for system-level features).

### 2.7 Cross-Domain Connections

Some content lives in multiple places. The **canonical location** owns the data; other locations **reference** it:

| Content | Canonical Location | Referenced From |
|---------|-------------------|------------------|
| Today's readiness | Home (`ReadinessCard`) | Training (adjusts session), Stats (recovery section) |
| Macros today | Nutrition (`MacroTargetBar`) | Home (quick action), Stats (nutrition section) |
| Training program | Training (`TrainingPlanView`) | Home (today's plan), Settings (program selection) |
| HealthKit data | HealthKit (`HealthKitService`) | Home (HRV/sleep), Stats (charts), Training (readiness adjustment) |

**Rule:** Edit in canonical, view from references. Never duplicate edit surfaces.

### 2.8 IA Decision Log

Decisions made about IA that aren't immediately obvious:

| Decision | Rationale |
|----------|-----------|
| Settings is profile-icon, not 5th tab | Frequency-based: tabs are for daily use, settings is infrequent |
| No "Recovery" tab — recovery lives in Home + Stats | Avoids fragmentation; readiness is contextual to today's session |
| Exercise library is inside Training, not standalone | Discovery happens in the context of programming a workout |
| Stats period selector uses segmented control, not picker | Segmented = visible options (recognition over recall); picker = hidden |
| Onboarding bypasses tabs entirely | First-run is an immersive flow, not part of normal navigation |

---

## Part 3: Interaction Patterns

### 3.1 Navigation Patterns

| Pattern | When to Use | Example | Implementation |
|---------|-------------|---------|----------------|
| **Tab switch** | Top-level destination change | Home → Training | `TabView` with bottom bar |
| **Push** | Drilling into existing content | Stats → Chart Detail | `NavigationLink` |
| **Sheet** | Creating/editing content | Add meal | `.sheet(isPresented:)` |
| **Full-screen modal** | Immersive flow, requires focus | Active workout, onboarding | `.fullScreenCover(isPresented:)` |
| **Confirmation modal** | Destructive action verification | Delete account | `.alert(...)` or custom modal |

**Transition timing:**
- Tab switch: instant (no animation — Apple HIG)
- Push: standard iOS push animation (~300ms)
- Sheet: standard iOS sheet animation (~400ms)
- Full-screen: standard iOS modal animation (~400ms)

### 3.2 Input Patterns

#### Numeric Entry

| Use Case | Input Method | Example |
|----------|--------------|---------|
| Small range (1-30) | Stepper | Reps per set |
| Large range with precision | Text field with `.decimalPad` | Weight (kg) |
| Bounded continuous | Slider | Body fat % during onboarding |
| Discrete options | Picker wheel or segmented | Workout duration estimate |

**Auto-population is mandatory:** Set logging always pre-fills weight and reps from the most recent session for the same exercise. Users adjust if needed.

#### Selection

| # of Options | Pattern | Example |
|--------------|---------|---------|
| 2 | Toggle (`Toggle`) or 2 buttons | Imperial vs Metric |
| 2-3 | Segmented control (`AppSegmentedControl`) | Beginner / Intermediate / Advanced |
| 4-6 | Cards in grid (2x2 or 2x3) | Onboarding goal selection |
| 7+ | Searchable list | Exercise picker, food database |

**Hick's Law applied:** Never use a flat picker for 7+ options without search.

#### Date & Time

- **Native iOS pickers** for all date/time input (Jakob's Law)
- Default to "today" for new entries
- Show relative dates in display ("Today", "Yesterday", "3 days ago") for the past 7 days

#### Search

- Inline search bar at top of list (`.searchable(text:)`)
- 300ms debounce on remote queries
- Real-time filtering for local data
- Show loading state during async search
- Empty state with "No results for '{query}'" + clear filter CTA

#### Barcode Scan

- Camera sheet with overlay frame
- Single barcode → fetch product → present pre-filled meal entry
- Multiple barcodes detected → user picks one
- Camera permission handled gracefully (Permission patterns, Part 5)

### 3.3 Feedback Patterns

#### Haptic Feedback Taxonomy

| Event | Haptic Type | Intensity | API |
|-------|-------------|-----------|-----|
| Button press | `.impact(.light)` | Light | `UIImpactFeedbackGenerator(style: .light)` |
| Selection change | `.selection` | Light | `UISelectionFeedbackGenerator()` |
| Set completed | `.impact(.medium)` | Standard | `UIImpactFeedbackGenerator(style: .medium)` |
| Workout finished | `.notification(.success)` | Standard + double tap | `UINotificationFeedbackGenerator()` |
| Personal record | `.notification(.success)` + custom pattern | Strong | Custom sequence |
| Rest timer complete | `.notification(.default)` | Standard | `UINotificationFeedbackGenerator()` |
| Validation error | `.notification(.error)` | Standard | `UINotificationFeedbackGenerator()` |
| Destructive confirmation | `.notification(.warning)` | Standard | `UINotificationFeedbackGenerator()` |

**Rules:**
- Haptics are **opt-out**, not opt-in (default: enabled in Settings)
- Sound is **always off by default** (gym etiquette)
- All haptics respect `UIAccessibility.isReduceMotionEnabled` (skip non-essential)

#### Animation Feedback

- **Button press:** brief opacity fade (0.1s, `AppDuration.instant`)
- **Card tap:** scale down to 0.97 then back (0.2s, `AppSpring.snappy`)
- **Save success:** checkmark fade-in over 0.3s, then toast slides up
- **PR celebration:** brief glow + scale pulse on the metric, ~0.5s
- **Streak increment:** number ticks up with spring (`AppSpring.bouncy`)

#### Toast Notifications (Non-Blocking)

Use for non-critical confirmations that shouldn't interrupt flow:

- "Workout saved" (after completion)
- "Meal added" (after meal entry)
- "Synced" (after manual sync trigger)

Toast spec:
- Position: bottom-center, above tab bar
- Duration: 2.0s default, 3.5s for actionable toasts (with undo)
- Style: `AppCard` with `AppSpacing.medium` padding, slide up + fade
- Single line, max 40 characters

#### Alerts (Blocking)

Use only for:
- Destructive confirmations ("Delete this workout? This cannot be undone.")
- Critical errors that require user decision
- Permission denials with clear next steps

Alert copy follows the format: **State the issue. State the consequence. State the next action.**

### 3.4 Gesture Patterns

| Gesture | Action | Example | Alternative |
|---------|--------|---------|-------------|
| Tap | Primary action | Log a set | — |
| Long press | Context menu | Reorder exercises | Menu button |
| Swipe left | Reveal destructive action | Delete a meal | Long-press menu |
| Swipe right | Reveal positive action | Mark complete | Tap |
| Swipe down (sheet) | Dismiss sheet | Close meal entry | Cancel button |
| Pull down (list) | Pull to refresh | Refresh stats | Manual sync button |
| Pinch | Zoom chart time range | Stats chart | Period selector |
| Drag | Reorder list items | Reorder routine exercises | Long-press menu |

**Rule (Motor Accessibility):** Every gesture must have a non-gesture alternative. Switch Control users and motor-impaired users cannot perform swipes or long-presses reliably.

---

## Part 4: Data Visualization Patterns

### 4.1 Chart Type Selection Guide

| Data Type | Chart Type | Component | FitMe Example |
|-----------|------------|-----------|---------------|
| Time-series trend | Line chart | `ChartCard` | Body weight over 30 days |
| Discrete comparison | Bar chart | `ChartCard` | Weekly volume per muscle group |
| Progress to goal | Ring/donut | `AppProgressRing` | Today's protein target (75/150g) |
| Compact trend | Sparkline | inline in `MetricCard` | 7-day HRV trend next to current value |
| Consistency over time | Heat calendar | (custom) | Workout frequency calendar (GitHub-style) |
| Body region targeting | Body map overlay | (custom) | Volume distribution by muscle group |

### 4.2 Metric Display Hierarchy

Every metric has 4 levels of presentation. Use the right one for the context:

| Level | Token | Use Case | Example |
|-------|-------|----------|---------|
| **Hero** | `AppText.metricHero` (largeTitle, bold, rounded) | Single dominant metric on a screen | Readiness score on `ReadinessCard` |
| **Display** | `AppText.metricDisplay` (largeTitle, bold) | Standalone metric in detail view | Body weight on Stats page |
| **Standard** | `AppText.metric` (title, bold, rounded) | Card metric with label | "75g" protein in macro card |
| **Compact** | `AppText.metricCompact` (title2, bold) | Inline metric in dense lists | Set count in workout summary |

**Always include the unit** with the value: "75g" not "75". Exception: hero metrics with separate unit label below ("75" / "grams of protein").

### 4.3 Color Semantics in Data

| Color | Token | Meaning in Data | Example |
|-------|-------|-----------------|---------|
| Brand orange | `AppColor.Brand.primary` (#FA8F40) | Active, in-progress, brand accent | Today's progress, current workout |
| Success green | `AppColor.Status.success` (#34C759) | On target, positive trend, completed | Hit macro target, streak active |
| Warning amber | `AppColor.Status.warning` | Approaching limit, attention needed | 90% of calorie target |
| Error red | `AppColor.Status.error` (#FF3B30) | Over limit, missed, error | Exceeded sodium target |
| Info blue | `AppColor.Brand.secondary` (#8AC7FF) | Informational, neutral, recovery | HRV reading, sleep duration |
| Chart muted | `AppColor.Chart.*` | Multi-series chart colors | Volume by muscle group |

**Trend direction colors:**
- Up + good (strength gain) → green
- Up + bad (body fat increase during cut) → red
- Down + good (body fat decrease during cut) → green
- Down + bad (HRV decline) → red

**Rule:** Direction is contextual. Same value going up can be good or bad depending on the metric type and the user's goal.

### 4.4 Chart Interaction Patterns

- **Tap a data point:** show value tooltip + date
- **Tap chart background:** show closest data point
- **Drag horizontally on chart:** scrub through time, value updates
- **Pinch:** zoom time range (week → month → year)
- **Tap segment in bar chart:** filter detail view to that segment
- **Long press on chart:** show full data table (accessibility)

### 4.5 Empty Chart States

When there's not enough data for a meaningful chart:

```
┌─────────────────────────┐
│                         │
│       📊                │
│                         │
│  Log a few more sessions│
│  to see trends          │
│                         │
│  [Log Workout]          │
│                         │
└─────────────────────────┘
```

**Threshold rule:**
- < 3 data points: show empty state with CTA to log more
- 3-6 data points: show data with "More data = better insights" hint
- 7+ data points: show normal chart

### 4.6 Chart Accessibility

Every chart MUST have a text alternative:

- VoiceOver users hear a summary: "Bench press 1RM, increased 5% over the last 4 weeks, current value 100 kilograms"
- The full data table is available via long-press or VoiceOver custom action
- Color is never the only indicator — always paired with shape, label, or position

This is non-negotiable. A chart that VoiceOver users can't understand is broken.

---

## Part 5: Permission & Trust Patterns

### 5.1 Core Principle (Apple HIG)

> Request permission at the moment of relevance, not during onboarding. Explain _why_ before showing the system dialog.

System permission dialogs are **one-shot**. If a user denies, you cannot ask again — you can only deep-link them to Settings. This makes the **first request** critical.

### 5.2 Permission Priming Pattern (3 Steps)

Every permission follows this flow:

```
Step 1: Pre-Primer Screen
  ↓ (app-branded explanation of benefit)
Step 2: System Dialog
  ↓ (iOS native permission prompt)
Step 3: Graceful Degradation
  ↓ (if denied, feature works in degraded mode with re-enable banner)
```

**Pre-primer rules:**
- App-branded screen, NOT a system alert
- Explains the benefit ("get reminded when rest is over") not the mechanism ("we need notification access")
- Has two clear options: "Allow" (proceeds to system dialog) and "Not Now" (skips, can re-prompt later)
- Uses real screenshots or illustrations of the benefit when possible

### 5.3 FitMe Permission Matrix

| Permission | When to Request | Pre-Primer Copy | Degraded State |
|------------|----------------|-----------------|----------------|
| **HealthKit (read)** | Onboarding step 4 OR first time user opens Stats | "Connect to Apple Health to import workouts and recovery metrics — your data stays encrypted on device" | Manual entry only, no auto-sync |
| **HealthKit (write)** | After first completed workout | "Save workouts to Apple Health so all your apps stay in sync" | Workouts stay in FitMe only |
| **Notifications** | After user sets first rest timer or schedules a workout | "Get reminded when rest is over and when it's time to train" | No reminders, manual timer only |
| **Camera** | When user taps barcode scan or progress photo | "Scan barcodes to log meals instantly" | Manual entry only |
| **Photo Library** | When user taps "Add progress photo" | "Track your transformation with progress photos — they stay encrypted on your device" | No photo feature |
| **ATT (App Tracking Transparency)** | During GDPR consent flow (onboarding step 5) | "Help us improve FitMe with anonymous usage data — your health values are never tracked" | No analytics, app fully functional |
| **Location** | Only if outdoor tracking is added | "Track your route during outdoor workouts" | No route map |

**Critical: NEVER request multiple permissions at once.** Each permission has its own contextual moment. Batching destroys trust.

### 5.4 Onboarding Permission Strategy

The onboarding flow has 6 steps. Permissions appear in step 4 (HealthKit) and step 5 (consent/ATT) — NOT in batch at the start.

```
1. Welcome (no permission)
2. Goals (no permission)
3. Profile (no permission)
4. HealthKit (one permission, in context, with clear benefit)
5. Consent / ATT (analytics permission, with full transparency)
6. First Action (no permission)
```

Notifications, Camera, Photos are deferred until the user encounters those features naturally.

### 5.5 Trust Signals

Visible markers that reinforce FitMe's privacy commitment:

| Signal | Where | What It Says |
|--------|-------|--------------|
| Encryption badge | Settings → Account & Security | "AES-256 encrypted, end-to-end" |
| "Stays on device" label | HealthKit permission screen | "Your health data never leaves your phone unencrypted" |
| Privacy summary | Consent screen tracking list | Clear list of what's tracked / not tracked |
| Sync status indicator | Top of `RootTabView` (sidebar mode) | Shows "Synced" with checkmark |
| Privacy policy link | Every data screen footer | One tap to full policy |

**Rule:** Privacy is a feature, not a disclosure. Surface it as a benefit, not a legal requirement.

### 5.6 GDPR Consent Integration

Consent is integrated into onboarding (step 5 of 6) — not a post-auth gate. This:
- Gives users context before asking
- Bundles ATT request with analytics consent (one ask, not two)
- Allows skip ("Continue Without") with full app functionality
- Sets `analytics.consent.gdprConsent` immediately on choice
- Records the choice in the audit trail

The standalone `ConsentView` exists as a fallback for users who completed onboarding before consent was added to the flow.

### 5.7 Re-Permission Strategy

When a user denies a permission, you cannot re-prompt. Instead:

1. Show a non-intrusive banner explaining the missed feature
2. Provide a "Open Settings" button that deep-links to the FitMe permission page
3. Detect on app foreground when the permission has been granted
4. Remove the banner and enable the feature without further interruption

**Example banner:**
```
┌──────────────────────────────────────┐
│ ⓘ HealthKit access denied            │
│ Connect Health to auto-sync recovery │
│ [ Open Settings ]      [ Dismiss ]   │
└──────────────────────────────────────┘
```

---

## Part 6: State Patterns

Every screen has 5 possible states. The default state is the easy one. The other 4 are where most apps fail.

### 6.1 The 5 States

| State | When | Required? |
|-------|------|-----------|
| **Default** | Normal content present | Always |
| **Loading** | Async operation in progress | Required if any async work |
| **Empty** | No content yet (first use, no data) | Required for any list/chart |
| **Error** | Operation failed | Required for any async work |
| **Success** | Operation succeeded (transient) | Recommended for save/submit |

### 6.2 Loading States

| Context | Pattern | Component | Duration Threshold |
|---------|---------|-----------|---------------------|
| Initial data load | Skeleton shimmer matching content shape | Custom skeleton | > 200ms |
| Sync in progress | `FitMeLogoLoader` with `.breathe` mode + "Syncing..." | `FitMeLogoLoader` | Always |
| AI computation | `FitMeLogoLoader` with `.breathe` + contextual message ("Building your plan...") | `FitMeLogoLoader` | Always |
| Pull to refresh | Standard iOS pull-to-refresh spinner | System component | Always |
| Button action | Inline spinner replacing button label | Custom | > 500ms |

**Rules:**
- Operations under 200ms: no loading state (instant feels better)
- Operations 200ms-500ms: skeleton or fade
- Operations 500ms+: explicit loading with progress or message
- Operations > 5s: progress percentage if possible, cancel option if appropriate

### 6.3 Empty States

Empty states are the most-seen screen for new users. Treat them as primary onboarding surfaces, not error pages.

| Context | Message Pattern | CTA | Component |
|---------|----------------|-----|-----------|
| First use, no workouts | "Your workout history will appear here" | "Start your first workout" | `EmptyStateView` |
| First use, no meals today | "Log your first meal to track macros" | "Add Meal" | `EmptyStateView` |
| No data for selected period | "No workouts in this period. Try a wider range." | Period selector | inline |
| No exercises in routine | "Add exercises to build your routine" | "Browse exercises" | `EmptyStateView` |
| Search returned nothing | "No exercises match '{query}'" | "Clear search" | inline |
| HealthKit not connected | "Connect Health to see your recovery metrics" | "Connect" | `EmptyStateView` |

**Empty state copy formula:**
1. **What is missing** (factual, no judgment)
2. **What to do next** (specific action)
3. **Optional: why it matters** (benefit, not pressure)

**Don't:**
- ❌ "You haven't logged anything yet" (sounds judgmental)
- ❌ "No data" (factual but unhelpful)
- ❌ Show a blank screen (violates Recognition over Recall)

**Do:**
- ✅ "Your workout history will appear here. Log your first session to start tracking."
- ✅ Pair with an illustration or icon
- ✅ Make the CTA the obvious next action

### 6.4 Error States

Error states are a trust test. They reveal whether FitMe is forgiving or punishing.

| Error Type | Message Pattern | Recovery |
|------------|----------------|----------|
| Network failure | "Couldn't connect. Your data is saved locally and will sync when you're back online." | Auto-retry, manual retry button |
| Sync conflict | "This workout was edited on another device. Choose which version to keep." | Show diff view, user picks |
| HealthKit denied | "FitMe can't access Health data. Connect in Settings to enable recovery tracking." | "Open Settings" deep link |
| Invalid input | Inline field-level error in red below the field | Highlight field, explain expected format |
| Server error (5xx) | "Something went wrong on our end. Try again in a moment." | Manual retry button |
| Auth expired | "Sign in to continue syncing your data." | Re-auth flow |

**Error copy formula (from `ux-copy-guidelines.md`):**
1. **State the issue** clearly, no jargon
2. **State the consequence** ("Your data is safe locally")
3. **State the next action** (what to tap)

**Never:**
- ❌ Show raw error messages: "Error: NSURLErrorDomain code -1009"
- ❌ Blame the user: "You entered invalid data"
- ❌ Lose user data without explanation: "Sync failed."

**Always:**
- ✅ Reassure the user their work is safe
- ✅ Offer a clear recovery path
- ✅ Sanitize technical details before display

### 6.5 Success States

Success feedback prevents anxiety and builds confidence.

| Action | Success Pattern | Duration |
|--------|----------------|----------|
| Save workout | Toast: "Workout saved" + checkmark animation | 2.0s |
| Log meal | Toast: "Meal added" + macro bars update | 2.0s |
| Sync complete | Status indicator updates to "Synced" | Persistent |
| Achievement | Celebration animation (PR, streak) + persistent card | Until dismissed |
| Onboarding complete | Transition animation → home screen | 0.5s |
| Account deleted | Full-screen confirmation → exit to welcome | Persistent until tap |

**Rules:**
- Success states are **transient** (2-3s) for routine actions — they shouldn't block flow
- Success states are **celebratory** for achievements (PRs, streaks) — they should feel earned
- Success states are **persistent** for state changes (sync status, account state) — they're informational, not transient

### 6.6 State Coverage Checklist

Before any screen ships, verify all 5 states are defined:

```
[ ] Default state — primary content rendering
[ ] Loading state — what shows while data loads?
[ ] Empty state — what shows if there's no data yet?
[ ] Error state — what shows if loading fails?
[ ] Success state — what shows after a save/submit?
```

This is enforced by `/ux validate {feature}` and `feature-design-checklist.md`.

---



