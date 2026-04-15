# Smart Reminders — Research

## Problem Statement

FitMe users miss optimal nutrition, training, and recovery windows because the app is passive — it only provides value when opened. Guest users who skipped auth during onboarding have no reason to return. The app needs a proactive outreach layer that delivers timely, personalized nudges without becoming annoying.

## Competitive Analysis

| App | Reminder Types | Personalization | Frequency |
|---|---|---|---|
| **Whoop** | Recovery coach, strain alerts, sleep wind-down | HRV-based, fully personalized | 2-3/day |
| **Oura** | Readiness alerts, bedtime reminders, activity goals | Ring data-driven | 1-2/day |
| **MyFitnessPal** | Meal logging reminders, water intake | Time-based, minimal personalization | 3-4/day (aggressive) |
| **Noom** | Behavioral nudges, coach messages, weight logging | AI-personalized psychology-based | 3-5/day |
| **Apple Health** | Stand reminders, mindfulness | Activity-ring based | Hourly stand |

**Key insight:** Whoop and Oura succeed because reminders are data-driven (HRV, readiness), not time-based. MFP over-notifies. FitMe should follow the Whoop/Oura model — **state-aware, not schedule-based**.

## 5 Reminder Types

### Type 1: HealthKit Connect
- **Trigger:** `!healthService.isAuthorized && daysSinceOnboarding >= 2`
- **Timing:** Day 2, 5, 10 after onboarding (max 3 attempts)
- **Message:** "FitMe works better with Apple Health. Connect now to see your readiness score and recovery data."
- **Frequency cap:** 3 total, then stop permanently
- **Analytics:** `reminder_healthkit_shown`, `reminder_healthkit_tapped`

### Type 2: Account Registration
- **Trigger:** `!signIn.hasStoredSession && daysSinceOnboarding >= 3`
- **Timing:** Day 3, 7, 14 (max 3 attempts)
- **Message:** "Create your FitMe account to sync data across devices and unlock AI coaching."
- **Frequency cap:** 3 total
- **Analytics:** `reminder_registration_shown`, `reminder_registration_tapped`

### Type 3: Goal-Gap Nutrition
- **Trigger:** `currentProtein < targetProtein * 0.5 && hour >= 16` (afternoon, less than half protein target met)
- **Timing:** 4 PM if condition met, max 1/day
- **Message:** "You're at {current}g / {target}g protein today. A quick meal could close the gap."
- **Frequency cap:** 1/day, 5/week
- **Analytics:** `reminder_nutrition_gap_shown`, `reminder_nutrition_gap_tapped`

### Type 4: Training/Rest Day
- **Trigger:** `isTrainingDay && !hasLoggedWorkout && hour >= 10` OR `isRestDay && readinessScore < 40`
- **Timing:** 10 AM for training reminder, anytime for low-readiness alert
- **Message (training):** "Today's plan: {dayType}. {exerciseCount} exercises, ~{duration}m."
- **Message (rest):** "Your readiness is {score}. Take it easy — rest is part of progress."
- **Frequency cap:** 1/day
- **Analytics:** `reminder_training_shown`, `reminder_rest_day_shown`

### Type 5: Engagement
- **Trigger:** `daysSinceLastOpen >= 3`
- **Timing:** Day 3, 5, 7 of inactivity
- **Message (day 3):** "Haven't seen you in a bit. Your streak is waiting."
- **Message (day 7):** "Your body composition goals need consistency. Quick check-in?"
- **Frequency cap:** 3 total per lapse period, reset on open
- **Analytics:** `reminder_engagement_shown`, `reminder_engagement_tapped`

## Locked Feature Overlays

When guest users tap locked features (AI coaching, sync, data export), show an overlay:
- Semi-transparent backdrop
- Card: feature icon + "Unlock {feature}" title + benefit description + "Create Account" CTA
- "Maybe later" dismiss link
- Analytics: `locked_feature_shown`, `locked_feature_cta_tapped`

## Technical Approach

- **Delivery:** `UNUserNotificationCenter` for local notifications (no server needed)
- **Scheduling:** `NotificationScheduler` service that runs on app launch and significant events
- **Personalization:** Read from `AIOrchestrator` (readiness), `EncryptedDataStore` (nutrition progress, workout logs), `GoalProfile` (targets)
- **Permission:** Follow UX Foundations 3-step priming pattern (pre-primer → system dialog → graceful degradation)
- **Dependency:** Push Notifications feature must ship first (handles permission flow)

## Recommended Approach

**Phase 1:** Ship types 3 + 4 (nutrition gap + training/rest) — highest user value, data already available
**Phase 2:** Add types 1 + 2 (HealthKit + registration) — conversion-focused
**Phase 3:** Add type 5 (engagement) + locked overlays — retention-focused

## Risks

| Risk | Mitigation |
|---|---|
| Notification fatigue | Hard cap: max 3 reminders/day across all types |
| Irrelevant without HealthKit | Type 3 (nutrition) works without HealthKit, type 4 degrades gracefully |
| Guest users ignore registration nudges | Max 3 attempts, then permanent stop |
| Privacy concerns | All computation local, no PII in notification content |
