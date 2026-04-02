# FitMe — Product Requirements Document

> **Living document** — updated as features evolve.  
> Last updated: 2026-04-02 | Author: Regev Barak | Version: 2.0

---

## Part 1: Product Strategy

### 1.1 Problem Statement

**Problem:** Serious fitness enthusiasts use 3-5 separate apps to track their training, nutrition, recovery, and body composition. This fragmentation creates:

- **Data silos** — workout data in one app, nutrition in another, sleep in a third. No unified picture of readiness or progress.
- **Decision fatigue** — users check multiple dashboards to answer a simple question: "What should I do today?"
- **Privacy erosion** — each app collects health data independently, often uploading raw biometrics to separate cloud services with varying security practices.
- **Inconsistent UX** — switching between apps with different design languages, interaction patterns, and data entry flows wastes time and breaks flow.

**Who is affected:** Health-conscious individuals who train consistently (3-6 days/week), track macros, and want to understand how their body responds over time. These users are underserved by generic fitness apps that treat training, nutrition, and recovery as unrelated activities.

**Why now:** Apple's ecosystem (HealthKit, Foundation Models, Secure Enclave) enables a privacy-first approach where sensitive health data never leaves the device unencrypted. No competitor combines federated AI intelligence with zero-knowledge encryption in a single native app.

### 1.2 Product Vision & Elevator Pitch

**Vision:** FitMe is the iPhone-first fitness command center that unifies training, nutrition, recovery, and body composition into a single privacy-first experience — powered by federated AI that learns from population patterns while keeping your data encrypted on your device.

**Elevator pitch:** "FitMe replaces your training log, meal tracker, and recovery dashboard with one app that knows what you should do today — without ever seeing your private health data."

**North star metric:** Weekly Active Users who complete at least one training session AND log at least one meal (cross-feature engagement).

### 1.3 Target Personas

#### Primary: The Consistent Lifter
- **Demographics:** 25-40 years old, trains 4-6 days/week, has 1-5 years of structured training experience
- **Goals:** Build muscle, track progressive overload, optimize nutrition for body composition
- **Pain points:** Logging workouts is tedious, can't see how nutrition affects recovery, uses 3+ apps
- **Jobs to be done:** Know what to train today, log sets efficiently, hit macro targets, see if they're recovering
- **Devices:** iPhone (primary), Apple Watch (secondary)

#### Secondary: The Health-Conscious Professional
- **Demographics:** 30-50 years old, trains 3-4 days/week, values efficiency and simplicity
- **Goals:** Maintain fitness, manage weight, improve sleep and recovery
- **Pain points:** Too many screens, too much data entry, wants actionable guidance not raw numbers
- **Jobs to be done:** Quick daily check-in, simple meal logging, understand readiness
- **Devices:** iPhone only

#### Tertiary: The Data-Driven Optimizer
- **Demographics:** 25-45, deep interest in biomarkers, body composition, and performance trends
- **Goals:** Optimize every variable — sleep, HRV, nutrition timing, training periodization
- **Pain points:** Existing apps don't cross-reference enough data, wants DEXA integration, blood work trends
- **Jobs to be done:** Deep stats analysis, export data, overlay multiple metrics over time
- **Devices:** iPhone, Apple Watch, potentially Android (future)

### 1.4 Value Proposition

**Key differentiators:**

| FitMe | Competitors |
|-------|-------------|
| One app for training + nutrition + recovery + stats | Separate apps for each |
| Privacy-first: AES-256 encryption, zero-knowledge sync | Cloud storage of raw health data |
| Federated AI: population insights without exposing PII | No AI or cloud-dependent AI |
| Apple-first design: native SwiftUI, SF Symbols, HealthKit | Cross-platform compromises |
| On-device intelligence (iOS 26+ Foundation Models) | Server-side processing only |
| Semantic design system with 92 tokens | Inconsistent UI |

**Unique positioning:** "Privacy-first fitness intelligence" — the only app that combines federated cohort AI with zero-knowledge encryption, giving users population-level insights without ever exposing their personal health data to any server.

### 1.5 Business Objectives

#### Revenue Model
- **Freemium** with premium subscription tiers
- **Free tier:** Core training tracking, basic nutrition logging, 7-day stats
- **Premium ($9.99/month or $79.99/year):**
  - Full stats history (all periods)
  - AI recommendations
  - Advanced body composition (DEXA integration)
  - Blood test reader (future)
  - Cloud sync across devices
  - Priority support

`[OWNER INPUT NEEDED: Confirm pricing strategy and feature gates]`

#### Growth Targets
- **Month 1:** 1,000 installs (beta/TestFlight)
- **Month 3:** 5,000 installs, 30% D7 retention
- **Month 6:** 15,000 installs, 25% D30 retention
- **Year 1:** 50,000 installs, 5% premium conversion

`[OWNER INPUT NEEDED: Confirm growth targets are realistic for resources available]`

#### Retention Goals
- **D1 retention:** >60% (first day return)
- **D7 retention:** >30% (weekly habit formed)
- **D30 retention:** >20% (monthly sustained use)
- **Churn target:** <8% monthly for premium subscribers

### 1.6 Competitive Landscape

| App | Training | Nutrition | Recovery | AI | Privacy | Price |
|-----|----------|-----------|----------|-----|---------|-------|
| **FitMe** | Full (87 exercises, RPE, PRs) | Full (meals, macros, supplements) | Full (HRV, RHR, sleep, readiness) | Federated cohort + on-device | Zero-knowledge encryption | Freemium |
| **Fitbod** | AI-generated workouts | No | No | Cloud AI (workout only) | Standard cloud | $12.99/mo |
| **Strong** | Excellent logging | No | No | No | Standard cloud | $4.99/mo |
| **MyFitnessPal** | Basic | Excellent (food database) | No | No | Data sold to third parties | $19.99/mo |
| **Hevy** | Good logging, social | No | No | No | Standard cloud | $8.99/mo |
| **MacroFactor** | No | Excellent (adaptive) | No | Adaptive algorithm | Standard cloud | $11.99/mo |

**Where FitMe wins:**
1. **Only app** combining training + nutrition + recovery + AI in one native experience
2. **Only app** with zero-knowledge encryption for health data
3. **Only app** with federated AI (population insights, private data stays on device)
4. **Only app** with on-device Foundation Model integration (iOS 26+)

### 1.7 Go-to-Market Strategy

**Phase 1 — Beta (TestFlight)**
- Invite-only beta with 100-500 users
- Focus: core training + nutrition loop validation
- Collect NPS and feature requests
- Iterate on onboarding flow

**Phase 2 — App Store Launch**
- App Store Optimization (ASO): screenshots, keywords, description
- Landing page (fitme.app) with download CTA
- Social proof: beta user testimonials
- Reddit/fitness community presence

**Phase 3 — Growth**
- Influencer partnerships (fitness YouTubers/Instagrammers)
- Content marketing (training tips, nutrition guides)
- Referral program (free premium month for referrals)
- Android launch (expand TAM)

`[OWNER INPUT NEEDED: Confirm marketing budget and channel priorities]`

### 1.8 Success Metrics (Summary)

| Metric | Target | Measurement |
|--------|--------|-------------|
| **North Star:** Cross-feature WAU | 40% of installs | GA4 custom event |
| D1 Retention | >60% | Firebase |
| D7 Retention | >30% | Firebase |
| D30 Retention | >20% | Firebase |
| NPS | >50 | In-app survey |
| App Store Rating | >4.5 | App Store Connect |
| Premium Conversion | >5% | Revenue analytics |
| Crash-free Rate | >99.5% | Crashlytics |

Detailed metrics framework: see `docs/product/metrics-framework.md`

### 1.9 Assumptions, Constraints & Risks

**Assumptions:**
- Users are willing to consolidate 3+ apps into one
- Privacy-first messaging resonates with fitness-conscious users
- Apple HealthKit provides sufficient biometric data for readiness scoring
- Federated AI provides meaningful recommendations with anonymized data

**Constraints:**
- iOS-only at launch (Android Phase E, 8-12 week build)
- No food database API yet (OpenFoodFacts planned)
- On-device AI requires iOS 26+ (fallback for older devices)
- Solo developer / small team resources

**Risks:**
| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Low adoption due to crowded market | Medium | High | Differentiate on privacy + AI |
| Apple changes HealthKit/Foundation Model APIs | Low | Medium | Protocol-driven architecture, easy to adapt |
| Supabase pricing at scale | Low | Medium | Self-host PostgreSQL if needed |
| Regulatory issues with health data features | Low | High | GDPR compliance from day 1, no medical claims |

### 1.10 Platform Strategy

| Platform | Priority | Timeline | Status |
|----------|----------|----------|--------|
| **iPhone (iOS 17+)** | P0 | Now | Shipped |
| **Android (Pixel-first)** | P1 | Phase E (post-Apple closure) | Research done, 8-12 week estimate |
| **Apple Watch** | P2 | Post-Android | WatchConnectivityService exists |
| **iPad / macOS** | P3 | Future | Layout support partial |
| **Web Dashboard** | P4 | Future | Not started |

---

## Part 2: Feature Requirements

Each feature section follows a consistent structure: purpose, business objective, functional requirements, user flows, current state & gaps, acceptance criteria, and success metrics.

---

### 2.1 Training Tracking

**Purpose:** Enable users to log structured strength and cardio training sessions with progressive overload tracking, session-by-session comparison, and completion analytics.

**Business objective:** Core engagement driver — training sessions are the highest-value user action. Users who log 3+ sessions/week have 4x higher D30 retention than those who don't.

**Functional requirements:**

| Requirement | Status | Details |
|-------------|--------|---------|
| Exercise library | Shipped | 87 exercises across 5 day types (Upper Push, Lower Body, Upper Pull, Full Body, Cardio Only) |
| Set-based logging | Shipped | Weight (kg), reps, RPE (6-10 tap bar), warmup flag, per-set notes |
| Progressive overload | Shipped | Previous session ghost rows for same day type comparison |
| Copy last session | Shipped | One-tap to pre-fill from most recent same-type session |
| Session completion | Shipped | Summary sheet: volume delta, exercises completed, new PRs, duration, notes |
| PR detection | Shipped | Automatic detection of personal records (heaviest set, excluding warmups) |
| Rest timer | Shipped | Floating countdown with customizable presets, haptic at 10s and 0s |
| Cardio tracking | Shipped | Duration, avg HR, zone 2 detection (106-124 bpm), elliptical/rowing metrics |
| Photo capture | Shipped | Camera + photo library for cardio machine summary screens (encrypted JPEG) |
| Week strip | Shipped | Mon-Sat day selector with completion dots and TODAY badge |
| Focus mode | Shipped | Single-exercise drill-down view |
| Exercise categories | Shipped | Machine, free weight, calisthenics, cardio, core |
| Equipment types | Shipped | Machine, barbell, dumbbell, cable, bodyweight, resistance band, elliptical, rowing |
| Muscle groups | Shipped | 14 groups: chest, shoulders, triceps, back, biceps, rear delt, quads, hamstrings, glutes, calves, core, full body, posterior chain, cardiovascular |

**Key user flows:**
1. Open Training tab → see today's day type with exercise count
2. Select day (or use auto-detected) → see exercise queue
3. For each exercise: view previous performance → log sets → auto-advance
4. Start rest timer between sets → haptic countdown
5. Log cardio: duration + HR + optional photo of machine screen
6. Complete all exercises → session completion summary with volume delta

**Current state & gaps:**

| Gap | Priority | Notes |
|-----|----------|-------|
| No exercise search/filter | Medium | 87 exercises shown in fixed order; no search by name or muscle group |
| No custom exercise creation | Low | Users can't add exercises beyond the 87 defined |
| No supersets/circuits | Low | Sets are logged linearly, no grouping for supersets |
| No training program customization | Medium | Fixed 6-day PPL split; users can't create custom programs |
| No rep max calculator | Low | 1RM estimation not implemented |

**Acceptance criteria:**
- User can complete a full training session logging all sets with weight/reps
- Previous session data appears correctly for comparison
- PR detection fires accurately (excludes warmup sets)
- Rest timer provides haptic feedback at 10s and 0s
- Session completion summary shows correct volume delta

**Success metrics:**
- Sessions logged per user per week (target: 3+)
- Avg sets logged per session
- PR frequency (PRs per user per month)
- Session completion rate (% of sessions where all exercises are marked done)

**Key files:**
- `FitTracker/Views/Training/TrainingPlanView.swift` (~1500 lines)
- `FitTracker/Services/TrainingProgramStore.swift` (42 lines)
- `FitTracker/Models/TrainingProgramData.swift` (120 lines — 87 exercises, 10 supplements)

---

### 2.2 Nutrition Logging

**Purpose:** Enable users to track daily macro intake (protein, carbs, fat), log meals from multiple sources, monitor supplement adherence, and see adaptive calorie targets based on training day and body composition goals.

**Business objective:** Second-highest engagement driver after training. Users who log meals AND train have the highest retention. Nutrition data feeds the AI recommendation engine for cohort analysis.

**Functional requirements:**

| Requirement | Status | Details |
|-------------|--------|---------|
| Macro target bar | Shipped | Stacked P/C/F progress with calorie totals, always pinned |
| Dynamic targets | Shipped | Calories/macros vary by phase, training day, weight gap, BF gap |
| Manual meal entry | Shipped | Name, kcal, protein, carbs, fat, serving size |
| Smart label parsing | Shipped | Paste nutrition label text → auto-extract macros |
| Meal templates | Shipped | Save any meal as reusable template |
| Food search | Partial | OpenFoodFacts integration stub exists |
| Barcode scanner | Partial | AVFoundation camera + photo picker exist; parsing stub |
| Supplement tracking | Shipped | Morning (7) + evening (3) supplements with bulk toggle + individual overrides |
| Supplement streak | Shipped | Both morning + evening must be completed for streak day |
| Quick-log favorites | Shipped | Recent + frequent meals for fast re-logging |
| Hydration tracking | Shipped | Water intake (mL) with quick-adjust |
| Date navigation | Shipped | View/edit past days' nutrition |
| Adherence badges | Shipped | Protein %, calorie %, macro compliance summary |
| Allulose tracking | Shipped | Optional allulose intake flag |

**Nutrition planning logic:**
- Phase-based: Recovery (1800/1600 cal), Stage 1 (2000/1800), Stage 2 (variable)
- Training day calories > rest day calories
- Protein target: 2.0 × lean body mass (fallback 125-135g)
- Mode-aware: fat loss / maintain / gain adjusts macro ratios

**Key user flows:**
1. Open Nutrition tab → see today's macro progress (bar always visible)
2. Tap "Log Meal" → 4-tab sheet (Smart, Manual, Template, Search)
3. Enter or select meal → macros update in real-time
4. Toggle morning/evening supplement status → streak updates
5. Quick-log from recent meals → one-tap re-logging

**Current state & gaps:**

| Gap | Priority | Notes |
|-----|----------|-------|
| Food database search | High | OpenFoodFacts stub exists but not fully integrated |
| Barcode scanning | High | Camera capture exists but macro extraction not connected |
| Meal timing analysis | Low | Meals have timestamps but no timing recommendations |
| Photo-based logging | Medium | No image recognition for food (could use Vision/ML) |
| Meal planning / suggestions | Low | No AI-driven meal suggestions based on remaining macros |

**Success metrics:**
- Meals logged per user per day (target: 2+)
- Supplement adherence rate (% of days both morning + evening completed)
- Protein target hit rate (% of days within ±10% of target)
- Template usage rate (% of meals from templates vs manual)

**Key files:**
- `FitTracker/Views/Nutrition/NutritionView.swift` (~900 lines)
- `FitTracker/Views/Nutrition/MealEntrySheet.swift` (~400 lines)
- `FitTracker/Views/Nutrition/MealSectionView.swift`
- `FitTracker/Views/Nutrition/MacroTargetBar.swift` (104 lines)

---

### 2.3 Recovery & Biometrics

**Purpose:** Capture and display daily health metrics (weight, body fat, HRV, resting HR, sleep) from HealthKit and manual entry, computing a readiness score that guides training decisions.

**Business objective:** Recovery data enables the "intelligent" layer — without biometrics, the app is just a logging tool. Readiness scoring differentiates FitMe from competitors and drives daily check-in habits.

**Functional requirements:**

| Requirement | Status | Details |
|-------------|--------|---------|
| HealthKit auto-import | Shipped | HR, HRV, VO2Max, steps, active calories, sleep (total/deep/REM) |
| Manual biometric entry | Shipped | Weight, body fat, LBM, muscle mass, bone mass, visceral fat, water %, BMI, metabolic age, BMR |
| Manual fallback | Shipped | Manual HR, HRV, sleep hours when HealthKit unavailable |
| Effective values | Shipped | Auto-import preferred, falls back to manual entry seamlessly |
| Readiness scoring | Shipped | Based on resting HR (<75) + HRV (≥28) thresholds |
| Status dots | Shipped | Color-coded: green (good), amber (caution), red (alert) |
| HRV zone bands | Shipped | Green ≥35ms, amber 28-35ms, red <28ms |
| Xiaomi S400 support | Shipped | Body composition via manual entry from smart scale |
| Zone 2 HR detection | Shipped | Configurable bands (default 106-124 bpm) |

**Readiness logic:**
```
isReadyForTraining = (restingHR < 75) AND (hrv >= 28)
```
Thresholds configurable via UserPreferences.

**Current state & gaps:**

| Gap | Priority | Notes |
|-----|----------|-------|
| No readiness score formula | Medium | Currently binary (ready/not ready); needs weighted 0-100 score |
| No trend alerts | Medium | No notification when HRV drops below threshold for 3+ days |
| No DEXA import | Low | Manual body comp only; no structured DEXA report parsing |
| No blood pressure tracking | Low | Field not in DailyBiometrics |
| No respiratory rate | Low | Available in HealthKit but not imported |

**Success metrics:**
- Daily biometric entry rate (% of active days with ≥1 metric logged)
- HealthKit connection rate (% of users with HealthKit authorized)
- Readiness check-in rate (% of users who view readiness daily)

**Key files:**
- `FitTracker/Services/HealthKit/HealthKitService.swift`
- `FitTracker/Views/Shared/ReadinessCard.swift`
- `FitTracker/Views/Shared/RecoverySupport.swift`
- `FitTracker/Models/DomainModels.swift` (DailyBiometrics struct)

---

### 2.4 Home / Today Screen

**Purpose:** Single-glance daily command center showing readiness, goals, today's training, nutrition progress, and recovery status. The first screen users see — designed to answer "What should I do today?"

**Business objective:** Home screen drives daily habit formation. If users open the app and immediately understand their status, they're more likely to train and log. Home is the top of the engagement funnel.

**Functional requirements:**

| Requirement | Status | Details |
|-------------|--------|---------|
| LiveInfoStrip | Shipped | Rotating animated widget: greeting → readiness → streak (auto-cycle, tap-to-pause) |
| Progress orb | Shipped | Circular progress indicator with glow shadow |
| Status dots | Shipped | Weight, BF, HRV, RHR — color-coded 7-day trend |
| Goal ring | Shipped | Gradient stroke showing daily/weekly progress |
| Training button | Shipped | Today's session type + exercise count, tap to navigate |
| Day/phase badges | Shipped | StatusBadge pills showing recovery day and program phase |
| ReadinessCard | Shipped | 5-page auto-cycling TabView (readiness, training bars, nutrition, trends, achievements) |
| Biometric entry | Shipped | Manual biometric entry sheet accessible from home |

**ReadinessCard pages:**
1. Readiness score + HRV/RHR/Sleep
2. Weekly training mini bars (Mon-Sun)
3. Nutrition snapshot (calories, protein, supplement status)
4. 7-day trends (weight, BF, HRV, sleep, volume, steps — color-coded)
5. Achievements (supplement streak, PRs, program day)

**Current state & gaps:**

| Gap | Priority | Notes |
|-----|----------|-------|
| No push notifications | Medium | No morning readiness notification or training reminder |
| No widgets | Low | No iOS home screen or lock screen widgets |
| No Apple Watch complication | Low | WatchConnectivityService exists but no watch UI |
| Responsive font micro-adjustments | Low | 5 raw font sizes for compact screen layouts |

**Success metrics:**
- Daily app opens (target: 1+ per active day)
- Time to first action from home (target: <10 seconds)
- ReadinessCard page engagement (which pages get swiped to most)
- Training button tap-through rate

**Key files:**
- `FitTracker/Views/Main/MainScreenView.swift`
- `FitTracker/Views/Shared/ReadinessCard.swift`
- `FitTracker/Views/Shared/LiveInfoStrip.swift`
