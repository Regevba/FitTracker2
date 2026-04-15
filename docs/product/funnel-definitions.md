# FitMe — Funnel Definitions & Dashboard Templates

> **Updated:** 2026-04-15
> **Source events:** `FitTracker/Services/Analytics/AnalyticsProvider.swift`
> **GA4 property:** configured via `docs/setup/firebase-setup-guide.md`
> **Skill:** `/analytics funnel {name}` and `/analytics dashboard {feature}`

---

## 1. Onboarding Completion Funnel

**Purpose:** Measure new user activation — from first app open to first meaningful action.

| Step | GA4 Event | Expected Drop-off |
|---|---|---|
| 1. App opened | `session_start` (auto) | — |
| 2. Onboarding begins | `tutorial_begin` | 5-10% |
| 3. Goal selected | `onboarding_goal_selected` | 10-15% |
| 4. HealthKit permission | `permission_result` (type=healthkit) | 20-30% |
| 5. Consent granted | `consent_granted` | 5-10% |
| 6. Onboarding complete | `tutorial_complete` | 5% |
| 7. First workout started | `training_session_viewed` | 30-40% |

**Kill criteria:** If step 6 completion < 60%, revisit onboarding flow.
**GA4 config:** Exploration → Funnel Analysis → closed funnel (sequential steps).

---

## 2. Training Session Funnel

**Purpose:** Track training engagement depth — from session start to completion.

| Step | GA4 Event | Expected Drop-off |
|---|---|---|
| 1. Home action tap (train) | `home_action_tap` (action=start_workout) | — |
| 2. Session viewed | `training_session_viewed` | 5% |
| 3. First exercise started | `training_exercise_started` | 10% |
| 4. First set logged | `training_set_logged` | 5% |
| 5. Exercise completed | `training_exercise_completed` | 15% |
| 6. Session completed | `training_session_completed` | 20% |

**Key metric:** Session completion rate (step 6 / step 1). Target: >70%.
**Kill criteria:** If completion rate < 50%, investigate UX friction points.
**GA4 config:** Exploration → Funnel Analysis → open funnel (users may skip steps).

---

## 3. Nutrition Logging Funnel

**Purpose:** Track meal logging activation from home CTA to completed log.

| Step | GA4 Event | Expected Drop-off |
|---|---|---|
| 1. Home action tap (meal) | `home_action_tap` (action=log_meal) | — |
| 2. Meal entry opened | (screen_view: MealEntrySheet) | 5% |
| 3. Meal logged | `nutrition_meal_logged` | 30-40% |
| 4. Cross-feature engagement | `cross_feature_engagement` | 50%+ |

**Key metric:** Meal log rate (step 3 / step 1). Target: >60%.
**GA4 config:** Exploration → Funnel Analysis → closed funnel.

---

## 4. Home → Deep Engagement Funnel

**Purpose:** Track whether the home screen drives deeper engagement (North Star: train + log meal in same week).

| Step | GA4 Event | Expected Drop-off |
|---|---|---|
| 1. Home screen loaded | `screen_view` (screen=home) | — |
| 2. Any action tapped | `home_action_tap` | 40% |
| 3. Action completed | `home_action_completed` | 20% |
| 4. Cross-feature in same day | `cross_feature_engagement` | 60% |

**Key metric:** Cross-feature engagement rate. This is the North Star proxy.
**GA4 config:** Exploration → Funnel Analysis → open funnel, 1-day window.

---

## 5. AI Recommendation Engagement Funnel

**Purpose:** Track AI recommendation acceptance — from shown to acted on.

| Step | GA4 Event | Expected Drop-off |
|---|---|---|
| 1. AI insight shown | `home_ai_insight_shown` | — |
| 2. User taps to expand | `home_ai_insight_tap` | 60% |
| 3. Intelligence sheet opened | `home_ai_sheet_opened` | 10% |
| 4. User acts on recommendation | `home_action_tap` (within 5min of step 3) | 50% |

**Key metric:** Tap-through rate (step 2 / step 1). Target: >15%.
**GA4 config:** Exploration → Funnel Analysis → open funnel, 30-min window.
**Note:** When AI Engine adaptation Phase 4 (feedback UI) ships, add `ai_recommendation_accepted` / `ai_recommendation_dismissed` events here.

---

## 6. Readiness → Training Decision Funnel

**Purpose:** Track whether readiness scores influence training decisions.

| Step | GA4 Event | Expected Drop-off |
|---|---|---|
| 1. Readiness score computed | `home_readiness_score_computed` | — |
| 2. Recommendation shown | `home_readiness_recommendation_shown` | 5% |
| 3. Component detail tapped | `home_readiness_component_tap` | 70% |
| 4. Training started | `training_session_viewed` | varies by readiness |

**Segmentation:** Split step 4 by readiness level (high/moderate/low) to see if low-readiness users train less.
**GA4 config:** Exploration → Funnel Analysis + User segment by readiness score.

---

## Dashboard Templates

### Feature Dashboard Template

Every shipped feature should have a GA4 dashboard with these cards:

| Card | Metric | Source |
|---|---|---|
| Primary metric card | Feature's primary success metric from PRD | metric-status.json |
| Funnel visualization | Relevant funnel from above | GA4 funnel exploration |
| Daily active users (feature) | Users who triggered any feature event | GA4 event count by user |
| Engagement trend (7d/30d) | Feature events over time | GA4 event count time series |
| Drop-off analysis | Highest drop-off step in funnel | GA4 funnel exploration |
| Error correlation | Errors during feature use (requires Sentry) | Sentry integration |

### Guardrail Dashboard

System-wide health, not per-feature:

| Card | Metric | Source | Alert |
|---|---|---|---|
| Crash-free rate | % sessions without crash | Sentry | < 99.0% |
| Cold start time | p50/p95 app launch | GA4 custom metric | > 3000ms |
| Sync success rate | % sync operations succeeded | Custom event | < 95% |
| CI pass rate | % CI runs passing | GitHub Actions | < 85% |
| WAU (North Star) | Users who train + log meal in same week | `cross_feature_engagement` | Declining 3+ weeks |

---

## GA4 Setup Checklist

- [ ] Mark `training_session_completed` as conversion event in GA4
- [ ] Mark `nutrition_meal_logged` as conversion event in GA4
- [ ] Mark `tutorial_complete` as conversion event in GA4
- [ ] Mark `cross_feature_engagement` as conversion event in GA4
- [ ] Create Onboarding Completion funnel exploration
- [ ] Create Training Session funnel exploration
- [ ] Create Nutrition Logging funnel exploration
- [ ] Create Home Deep Engagement funnel exploration
- [ ] Create AI Recommendation funnel exploration
- [ ] Create Readiness Decision funnel exploration
- [ ] Create per-feature dashboard (Home, Training, Nutrition, Stats, Settings)
- [ ] Create Guardrail dashboard
- [ ] Set up audience: "Activated Users" (completed tutorial + 1 workout)
- [ ] Set up audience: "Power Users" (3+ workouts/week + meal logging)

---

## Relationship to PM Workflow

- **Phase 1 (PRD):** `/analytics funnel` defines funnels from acceptance criteria
- **Phase 5 (Test):** `/analytics validate` checks events are firing correctly
- **Phase 8 (Docs):** `/analytics dashboard` creates the GA4 dashboard from this template
- **Phase 9 (Learn):** `/analytics report` reads funnel data to evaluate kill criteria
