# Readiness-Aware Training Alert — Tasks

**Work type:** Enhancement (4-phase: Tasks → Implement → Test → Merge)
**Parent feature:** smart-reminders (PRD: `docs/product/prd/smart-reminders.md`)
**RICE:** 13.0 (top of refreshed Planned table 2026-05-31)
**Effort estimate:** 3-5 days (0.6 person-weeks)

## Scope summary

Proactive pre-training readiness alert that fires BEFORE the user starts today's planned session. Integrates yesterday's HealthKit signals (HRV trend, RHR, sleep) + nutrition logged vs target + recovery flags from ReadinessEngine v2 with today's training plan (DayType + scheduled volume/intensity from training-plan-v2).

## Three smart recommendation outputs

| Condition | Output |
|---|---|
| Readiness ≥ session-intensity threshold | **Continue as planned** — "You're ready — your {Push/Pull/Legs} session is fueled and your body is recovered." |
| Readiness < 40 OR critical recovery flags (poor sleep + elevated RHR + low HRV trend) | **Rest day swap** — "Your body needs recovery today. Rest is part of the plan, not a setback." Marks today as rest in the program; suppresses related reminders |
| Readiness 40–60 OR mixed signals | **Adapt to easier load** — "Today is fine to train but lighten the load — drop one set per exercise, lighter top-set, or swap heavy compounds for accessory volume." Actionable plan adjustment stages directly into TrainingDayView |

## Three surface points

1. **Home `AIInsightCard`** on app-open when today is a training day
2. **Local notification** at the user's learned typical training start time minus 1 hour (fallback 18:00 local)
3. **AI avatar state machine** — `.pulse` for advisory (continue/adapt), `.shimmer` for urgent (rest swap)

## "Why?" affordance

Every recommendation surface includes a "Why?" action that opens `AIIntelligenceSheet` with the readiness component breakdown that drove the recommendation (HRV trend value, RHR delta, sleep hours, nutrition gap, training plan intensity).

---

## Tasks

### Task 1 — Data model + recommendation enum

**File:** `FitTracker/Models/ReadinessAlertRecommendation.swift` (new)

Define:
```swift
enum ReadinessAlertRecommendation: String, Codable, Equatable {
    case continueAsPlanned    // readiness >= sessionIntensityThreshold
    case adaptEasierLoad      // 40 <= readiness <= 60 OR mixed signals
    case restDaySwap          // readiness < 40 OR critical recovery flags
}

struct ReadinessAlertContext: Equatable {
    let recommendation: ReadinessAlertRecommendation
    let readinessScore: Double  // 0-100 from ReadinessEngine v2
    let plannedDayType: DayType
    let hrvTrendDirection: TrendDirection  // .up / .stable / .down
    let restingHRDelta: Int  // bpm above 7-day avg
    let sleepHours: Double
    let nutritionGapKcal: Int  // negative = under-eating
    let bodyText: String  // pre-rendered for AIInsightCard + notification body
    let avatarState: AIAvatarState  // .pulse or .shimmer
}
```

**Acceptance:** unit test verifies enum exhaustiveness + Equatable.

---

### Task 2 — Trigger logic (readiness + plan → recommendation)

**File:** `FitTracker/Services/Reminders/ReadinessAwareTrainingTrigger.swift` (new)

Pure function `evaluate(readinessResult: ReadinessResult, plan: TrainingDay, signals: BiometricSnapshot) -> ReadinessAlertContext?`

Returns `nil` when today is not a training day OR readiness data is stale (>24h old).

Decision rules (ordered):
1. **Rest-day swap** (highest priority) if `readinessScore < 40` OR any 2 of: `sleepHours < 6.0`, `restingHRDelta > 8`, `hrvTrendDirection == .down for 3+ days`
2. **Continue as planned** if `readinessScore >= sessionIntensityThreshold(plan.dayType)`
   - threshold by DayType: easy=50, moderate=60, heavy=70, deload=40
3. **Adapt easier load** otherwise (40 <= readiness < threshold)

**Acceptance:** unit tests cover each decision rule + boundary conditions (readiness exactly at threshold) + rest-day case + critical-recovery-flag combinations.

---

### Task 3 — Notification time learning + schedule

**File:** `FitTracker/Services/Reminders/TrainingStartTimeLearner.swift` (new)

Compute the user's learned typical training start time per DayType from the rolling 30-day history of `TrainingDayView` open events (or DailyLog persistence timestamps as proxy).

Returns:
- `learnedStartHour: Int` (0-23 local time) — median across the window
- Fallback: 18:00 if fewer than 5 sessions in the window

**Acceptance:** unit tests with synthetic 30-day history fixture (one weekend-heavy user, one weekday-evening user, one cold-start user).

---

### Task 4 — Smart Reminders consumer wiring

**File:** `FitTracker/Services/Reminders/ReadinessAwareTrainingObserver.swift` (new)

Subscribes to the daily app-open event. When today is a training day:
1. Call `ReadinessAwareTrainingTrigger.evaluate(...)` with the latest readiness + plan
2. If recommendation is non-nil:
   - Dispatch via `NotificationGateway.dispatch(...)` at the learned-start-minus-1h time
   - Use `tag: .standard` (smart-reminders convention; never `.critical` even for rest swap — the rest swap is a recommendation, not an emergency)
   - `consumerID: SmartRemindersConsumerRegistration.consumerID`
   - userInfo: `{recommendation: rec.rawValue, deepLink: "fitme://nav/home"}`
3. Cache the rendered `ReadinessAlertContext` in `@Published` state so `AIInsightCard` can read it on Home open without re-evaluating

**Acceptance:** unit tests verify the gateway dispatch is called with the correct parameters; rest-swap variant also clears the workout reminder for today via `ReminderScheduler.cancel(type: .trainingDay)`.

---

### Task 5 — Home AIInsightCard integration

**File:** `FitTracker/Views/AI/AIInsightCard.swift` (modify existing)

Add a new render branch when `ReadinessAwareTrainingObserver.todayContext` is non-nil:
- Title: recommendation enum's user-facing label
- Body: pre-rendered `bodyText`
- Primary CTA: "Train now" (continue) / "Lighten today's session" (adapt) / "Swap to rest day" (rest swap)
- Secondary CTA: "Why?" → opens `AIIntelligenceSheet(context: readinessAlertContext)`
- Tint: `AppColor.Accent.recovery` for rest swap, `AppColor.Accent.achievement` for continue, `AppColor.Accent.energy` for adapt

The card respects the existing AIInsightCard pattern (taps log an analytics event, can be dismissed with swipe).

**Acceptance:** ui-audit P0=0; manual smoke (operator) verifies the card renders with each of the 3 recommendations + Why? sheet opens AIIntelligenceSheet with the right component breakdown.

---

### Task 6 — AIIntelligenceSheet "Why?" component breakdown

**File:** `FitTracker/Views/AI/AIIntelligenceSheet.swift` (modify existing)

Add a `init(readinessAlertContext: ReadinessAlertContext)` initializer that renders:
- 5 component bars showing each input (HRV trend, RHR delta, sleep, nutrition, plan intensity)
- A summary sentence explaining how the components combined to produce the recommendation
- A "Learn more about readiness scoring" link to the existing readiness explainer

**Acceptance:** sheet renders with all 5 rows + summary sentence; existing AIIntelligenceSheet flows (readiness drill-down, AI recommendation explanation) remain unaffected.

---

### Task 7 — AI avatar state machine

**File:** `FitTracker/Services/AIAvatarStateMachine.swift` (modify existing)

Wire the avatar to read `ReadinessAwareTrainingObserver.todayContext.avatarState`:
- `.shimmer` for rest swap (urgent)
- `.pulse` for continue and adapt (advisory)

The avatar should auto-clear back to default after the user taps the AIInsightCard or dismisses the day's recommendation.

**Acceptance:** avatar visibly shimmers on rest-swap days at app-open; pulses on continue/adapt days; default on non-training days.

---

### Task 8 — DeepLinkRouter integration

The notification body's userInfo carries `deepLink: "fitme://nav/home"` (Task 4). DeepLinkRouter already handles `fitme://nav/home` → `.navigateToTab(.home)` via the existing resolver. No new mapping needed — verify the existing path lands correctly when the notification is tapped from background.

**Acceptance:** notification tap from cold start lands on Home tab with the AIInsightCard visible (smoke test via operator).

---

### Task 9 — Analytics events

**File:** `FitTracker/Services/Analytics/AnalyticsService.swift` (modify existing)

Add 4 new events (all `home_`-prefixed per the screen-prefix rule):
- `home_readiness_alert_shown(recommendation: String, dayType: String, readinessScore: Int)`
- `home_readiness_alert_acted(recommendation: String, action: String /* train_now | lighten | rest_swap */)`
- `home_readiness_alert_why_opened(recommendation: String)`
- `home_readiness_alert_dismissed(recommendation: String)`

**Acceptance:** GA4 analytics-taxonomy.csv updated; events validate via `/analytics validate`.

---

### Task 10 — Settings toggle (per-reminder type)

**File:** `FitTracker/Services/Notifications/ReminderPreferencesStore.swift` (extend existing — shipped in PR #550)

Add a new bool `readinessAwareAlertsEnabled: Bool = true` with the same persistence pattern as the other 6 reminder type toggles.

The new toggle gets surfaced in `NotificationsSettingsScreen` (shipped in PR #550) — add the row.

**Acceptance:** master switch + per-type toggle both gate the alert (verified via unit test that the trigger short-circuits when either toggle is OFF).

---

### Task 11 — Test plan

**Files:** new
- `FitTrackerTests/ReadinessAwareTrainingTriggerTests.swift` — 12 tests covering each decision rule + boundary conditions
- `FitTrackerTests/TrainingStartTimeLearnerTests.swift` — 5 tests covering median calc + cold start + weekend-only edge case
- `FitTrackerTests/ReadinessAwareTrainingObserverTests.swift` — 8 tests covering the observer behavior (dispatch called once per day, rest-swap cancels workout reminder, no fire on non-training days, toggle off → no fire)

Plus extend:
- `FitTrackerTests/AnalyticsEventNamingTests.swift` — verify the 4 new events match the home_ prefix rule

**Acceptance:** `xcodebuild test` passes locally + on CI; coverage of `ReadinessAwareTrainingTrigger.swift` ≥ 90% (Slather report).

---

### Task 12 — Documentation

**Files:** new
- `docs/case-studies/readiness-aware-training-alert-case-study.md` — full case study following the existing template (Problem → Approach → Decisions → Outcomes + T1/T2/T3 tier labels + kill criteria)
- `docs/product/prd/readiness-aware-training-alert.md` — short PRD inheriting from `docs/product/prd/smart-reminders.md` (since this is an Enhancement)

Update:
- `docs/product/backlog.md` — strike through L206 entry (the long backlog row that describes this feature) with `[x]` + shipped date + PR link
- `state.json` — populate `case_study` + `case_study_showcase` fields when complete

**Acceptance:** `make integrity-check` clean post-merge; case study has all 7 required frontmatter fields; FEATURE_CLOSURE_COMPLETENESS write-time gate passes on the `current_phase=complete` transition.

---

## Phase transition criteria

| From | To | Criterion |
|---|---|---|
| tasks | implement | All 12 tasks above defined + operator approval |
| implement | test | All 12 tasks complete; `xcodebuild build` green; `make ui-audit` P0=0; no integrity findings |
| test | merge | `xcodebuild test` passes (existing + 25 new tests); coverage ≥ 90% on new files |
| merge | complete | PR merged to main; case study + showcase MDX shipped; backlog row struck through; FEATURE_CLOSURE_COMPLETENESS gate passes |

## Dependencies confirmed (all shipped)

- ReadinessEngine v2 (PR before #79) — supplies the score
- AIOrchestrator (PR #79) — supplies the recommendation rendering
- AIInsightCard (PR #79) — Home surface
- AIIntelligenceSheet (PR #79) — Why? affordance host
- Smart Reminders core (PR #98, 2026-04-16) — ReminderScheduler + ReminderTriggerEvaluator
- NotificationGateway routing (PR #553, 2026-05-31) — gateway dispatch path
- DeepLinkRouter registry (PR #556, 2026-05-31) — URL → action resolver
- Training Plan v2 (PR #74) — DayType + intensity source
- AI avatar state machine — `.pulse` / `.shimmer` modes already exist

## Cross-references

- L206 backlog row: `docs/product/backlog.md:234`
- Parent PRD: `docs/product/prd/smart-reminders.md`
- E1 RICE table entry: row 1 of the refreshed Planned section (RICE 13.0)
- Tier carryover plan: `~/.claude/projects/-Volumes-DevSSD-FitTracker2/memory/project_session_2026_05_31_tier_carryover_plan.md`
