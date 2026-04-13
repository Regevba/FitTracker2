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
| Food database search | Medium | Text search is wired through OpenFoodFacts; remaining work is result quality, fallback behavior, and broader validation coverage |
| Barcode scanning | Medium | Camera scanning is wired to OpenFoodFacts lookup; remaining work is validation depth and UX hardening |
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

---

### 2.5 Stats / Progress Hub

**Purpose:** Comprehensive historical analytics across 18 metrics with multi-period views, trend analysis, PR detection, and data source attribution.

**Business objective:** Stats create long-term stickiness. Users who review weekly trends are 2x more likely to sustain training habits. Stats also validate the product's value proposition — "your data, your insights."

**Functional requirements:**

| Requirement | Status | Details |
|-------------|--------|---------|
| Period picker | Shipped | Daily, Weekly, Monthly, 3-Month, 6-Month |
| 18 metrics | Shipped | Body (6), Recovery (4), Training (5), Nutrition (3) |
| Chart types | Shipped | Line/area, bar, stacked area, discrete points, dual-axis |
| Delta indicators | Shipped | Period-over-period change with color coding |
| Data source badges | Shipped | Apple Health, Watch, Smart Scale, Manual, HealthKit Off |
| Coverage summary | Shipped | X/Y days logged with category breakdown |
| PR records | Shipped | All-time max per exercise (Epley 1RM estimation) |
| Weekly bucketing | Shipped | Auto-aggregation for longer periods |
| Live fallback | Shipped | Today's data from Watch/HealthKit when no log exists |

**18 Tracked Metrics:**

| Category | Metrics |
|----------|---------|
| Body | Weight, Body Fat %, Lean Mass, Muscle Mass, Body Water, Visceral Fat |
| Recovery | Readiness Score, Sleep Hours, HRV, Resting HR |
| Training | Volume (kg), Zone 2 Minutes, Steps, Active Calories, VO2 Max |
| Nutrition | Protein (g), Calories, Supplement Adherence (%) |

**Current state & gaps:**

| Gap | Priority | Notes |
|-----|----------|-------|
| No goal target lines on charts | Medium | Weight/BF goals exist in UserProfile but not overlaid on charts |
| No chart interaction (tap-to-tooltip) | Medium | Mentioned in v2 spec but implementation status unclear |
| No export/share | Low | No chart screenshot or CSV export |
| No comparison mode | Low | Can't overlay two metrics on same chart |

**Success metrics:**
- Stats views per user per week (target: 2+)
- Most-viewed metric (identifies user priorities)
- Period distribution (which timeframes are most popular)
- Coverage rate (% of days with at least 1 metric logged)

**Key files:**
- `FitTracker/Views/Stats/StatsView.swift`
- `FitTracker/Views/Stats/StatsDataHelpers.swift`
- `FitTracker/Views/Shared/ChartCard.swift`
- `FitTracker/Views/Shared/MetricCard.swift`
- `FitTracker/Views/Shared/TrendIndicator.swift`

---

### 2.6 Authentication & Account

**Purpose:** Secure, trust-first authentication supporting Apple Sign In, passkeys, email/password, and post-login biometric lock. Session management with Supabase backend JWT tokens.

**Business objective:** Auth is the front door — friction here kills conversion. Apple-first auth (one-tap Sign In with Apple) minimizes friction while biometric lock protects sensitive health data.

**Functional requirements:**

| Requirement | Status | Details |
|-------------|--------|---------|
| Apple Sign In | Shipped | Primary auth via Supabase OAuth |
| Passkey/WebAuthn | Shipped | Challenge-response biometric auth |
| Email registration | Shipped | Name, birthday, email, password with OTP verification |
| Email login | Shipped | Email + password |
| Google Sign In | In Progress | Project wiring, package resolution, Info.plist scaffolding, and compile verification are complete; real credentials and end-to-end runtime verification are still pending |
| Facebook Sign In | Planned | Enum case exists, no implementation |
| Biometric lock | Shipped | Face ID / Touch ID post-sign-in lock |
| Auto-lock on background | Shipped | Configurable; clears crypto session |
| Session persistence | Shipped | Keychain storage, JWT refresh on foreground |
| Simulator bypass | Shipped | Auto-login in DEBUG + Simulator builds |

**Auth flow:**
```
Welcome → AuthHub → [Apple / Passkey / Email] → Authenticated
                                                       ↓
                              Background → LockScreen → Biometric → Authenticated
```

**Session model:**
- `UserSession`: provider, userID, displayName, email, phone, sessionToken, backendAccessToken (JWT), credentialID
- Stored in Keychain (encrypted)
- JWT for AI Engine API calls

**Current state & gaps:**

| Gap | Priority | Notes |
|-----|----------|-------|
| Google Sign In runtime verification | High | Repo wiring and compile verification are complete, but local credentials and end-to-end validation are still pending |
| Facebook Sign In not implemented | Low | Enum case only |
| Session refresh and recovery validation | Medium | Broader runtime auth QA is still required before auth can be called production-ready |
| No passcode fallback | Low | Only biometric — no PIN/pattern alternative |
| Phone OTP deferred | Low | Documented in `deferred-phone-otp-task.md` |

**Success metrics:**
- Sign-up completion rate (start → authenticated)
- Auth method distribution (Apple vs email vs passkey)
- Biometric unlock success rate
- Session restore success rate (JWT refresh)

**Key files:**
- `FitTracker/Views/Auth/AuthHubView.swift`
- `FitTracker/Views/Auth/SignInView.swift`
- `FitTracker/Views/Auth/WelcomeView.swift`
- `FitTracker/Views/Auth/AccountPanelView.swift`
- `FitTracker/Services/Auth/SignInService.swift`
- `FitTracker/Services/AuthManager.swift`

---

### 2.7 Settings

**Purpose:** Organized preferences dashboard with 5 category groups, each opening a focused detail surface. Controls app behavior, health integrations, goals, training configuration, and data management.

**Business objective:** Settings reduce friction (unit preferences, appearance) and enable power users to customize the experience. Well-organized settings also reduce support requests.

**Functional requirements:**

| Requirement | Status | Details |
|-------------|--------|---------|
| 5 category groups | Shipped | Account & Security, Health & Devices, Goals & Preferences, Training & Nutrition, Data & Sync |
| Category cards | Shipped | Icon, title, subtitle, optional badge |
| Detail screens | Shipped | Each category opens dedicated sub-screen |
| Unit system | Shipped | Metric (kg/cm) or Imperial (lbs/in) with auto-conversion |
| Appearance | Shipped | System / Light / Dark mode |
| Biometric toggle | Shipped | Enable/disable lock-on-reopen |
| HealthKit toggle | Shipped | Connect/disconnect Apple Health |
| Sync status | Shipped | Real-time CloudKit/Supabase status (idle/syncing/failed/offline) |
| Data reset | Shipped | Destructive action with confirmation dialog |
| Nutrition mode | Shipped | Fat loss / Maintain / Gain selector |
| Meal slot names | Shipped | Customizable (default: Breakfast, Lunch, Dinner, Snacks) |
| Readiness thresholds | Shipped | Configurable HR and HRV targets |
| Zone 2 HR range | Shipped | Configurable lower/upper bounds (default 106-124) |

**Current state & gaps:**

| Gap | Priority | Notes |
|-----|----------|-------|
| No notification settings | Medium | No push notification preferences |
| No data export | Medium | No CSV/JSON export of health data |
| No Apple Watch settings | Low | WatchConnectivityService exists but no settings UI |

**Success metrics:**
- Settings visit rate (% of users who visit settings in first 7 days)
- Customization rate (% who change at least 1 default)
- Most-changed setting (identifies UX friction points)

**Key files:**
- `FitTracker/Views/Settings/SettingsView.swift`
- `FitTracker/Services/AppSettings.swift`

---

### 2.8 Data & Sync (Encrypted)

**Purpose:** Secure local storage with AES-256-GCM encryption, multi-backend sync (CloudKit + Supabase), and zero-knowledge architecture where servers never see raw health data.

**Business objective:** Data security is a key differentiator. Users trust FitMe with sensitive biometrics because encryption is end-to-end. Multi-backend sync enables device migration and web dashboard (future).

**Functional requirements:**

| Requirement | Status | Details |
|-------------|--------|---------|
| AES-256-GCM encryption | Shipped | Primary cipher via CryptoKit |
| ChaCha20-Poly1305 | Shipped | Backup cipher |
| Secure Enclave keys | Shipped | P-256 keys with biometric ACL |
| Keychain fallback | Shipped | When Secure Enclave unavailable |
| HKDF-SHA512 key derivation | Shipped | Standard NIST key derivation |
| CloudKit sync | Shipped | iCloud Private Database, incremental push/pull |
| Supabase sync | Shipped | PostgreSQL + Realtime subscriptions |
| Realtime subscriptions | Shipped | RealtimeChannelV2 for live updates |
| Encrypted payloads | Shipped | `.ftenc` opaque blobs — server stores ciphertext only |
| First-login full pull | Shipped | New device gets complete history |
| Background push | Shipped | Pending changes pushed on app background |
| Conflict resolution | Shipped | Last-write-wins (timestamp-based) |
| File protection | Shipped | `NSFileProtectionCompleteUnlessOpen` |
| Cardio image upload | Shipped | Encrypted image → Supabase Storage |

**Sync record types:**
- `daily_log` — daily training/nutrition/biometric data
- `weekly_snapshot` — aggregated weekly summary
- `user_profile` — goals, phase, demographics
- `user_preferences` — settings, thresholds
- `meal_templates` — saved meal blueprints

**Current state & gaps:**

| Gap | Priority | Notes |
|-----|----------|-------|
| Data export UX from Settings | Medium | GDPR export exists, but there is still no dedicated Settings surface for initiating or tracking exports |
| Account deletion UX polish | Medium | GDPR deletion exists, but the destructive flow still needs broader UX and runtime validation |
| CloudKit unavailable on Simulator | Low | Known iOS limitation, Supabase covers sync |
| No offline conflict UI | Low | Conflicts resolved silently (last-write-wins) |
| No sync health indicator in UI | Low | Settings shows status but no persistent badge |

**Success metrics:**
- Sync success rate (% of push/pull operations without errors)
- Sync latency (p50/p95 time for incremental pull)
- Encryption overhead (ms added per read/write operation)
- Multi-device adoption (% of users syncing across 2+ devices)

**Key files:**
- `FitTracker/Services/Encryption/EncryptionService.swift`
- `FitTracker/Services/Supabase/SupabaseSyncService.swift`
- `FitTracker/Services/Supabase/SupabaseClient.swift`
- `FitTracker/Services/CloudKit/CloudKitSyncService.swift`
- `FitTracker/Models/UserSession+Supabase.swift`

---

### 2.9 AI / Cohort Intelligence

**Purpose:** Federated AI recommendation engine that combines population-level cohort signals (cloud) with private on-device personalization — without ever exposing individual PII to any server.

**Business objective:** AI recommendations are the premium differentiator. Users who receive actionable insights (e.g., "your cohort's data suggests reducing volume this week") have higher engagement and willingness to pay for premium tier.

**Functional requirements:**

| Requirement | Status | Details |
|-------------|--------|---------|
| AIOrchestrator | Shipped | Dual-path: cloud baseline + on-device personalization |
| 4 recommendation segments | Shipped | Training, Nutrition, Recovery, Stats |
| Privacy-preserving bands | Shipped | Age → "25-34", sleep → "7-8", BMI → "25-29.9" (no raw PII sent) |
| Cloud AI Engine | Shipped | FastAPI on Railway, JWT-authenticated, JWKS validation |
| On-device Foundation Model | Shipped | iOS 26+ Apple Intelligence with FallbackFoundationModel for older devices |
| Confidence scoring | Shipped | 0.0-1.0 scale; ≥0.4 threshold for acceptance |
| k-anonymity floor | Shipped | k=50 minimum cohort size before returning population signals |
| Rate limiting | Shipped | Per-user request throttling on cloud endpoint |
| Offline fallback | Shipped | Local rule-based recommendations when cloud unavailable |

**Data flow:**
```
LocalUserSnapshot (on-device)
  → Band extraction (age_band, bmi_band, etc.)
    → Cloud POST /v1/{segment}/insight (only bands + JWT)
      → AIRecommendation (signals, confidence)
        → FoundationModel.adapt() (on-device, uses private data)
          → Final personalized recommendation
```

**AI segments and input bands:**

| Band | Values | Source |
|------|--------|--------|
| age_band | 18-24, 25-34, 35-44, 45-54, 55+ | UserProfile |
| gender_band | male, female, prefer_not_to_say | UserProfile |
| bmi_band | <18.5, 18.5-24.9, 25-29.9, 30+ | Computed |
| active_weeks_band | 0, 1-3, 4+ | DailyLog history |
| program_phase | foundation, build, peak, recovery | UserProfile |
| sleep_band | under_6, 6-7, 7-8, 8+ | HealthKit/manual |
| resting_hr_band | under_60, 60-70, 71-80, 81+ | HealthKit/manual |
| stress_level | low, moderate, high | Derived |

**Current state & gaps:**

| Gap | Priority | Notes |
|-----|----------|-------|
| Foundation Model is placeholder | Medium | Uses rule-based adjustments; real LLM pending iOS 26 SDK |
| No recommendation UI | High | Signals exist but no dedicated UI to surface them to users |
| No A/B testing | Low | Can't test recommendation effectiveness |
| No user feedback loop | Medium | Users can't rate recommendation quality |

**Success metrics:**
- Recommendation acceptance rate (% of recommendations acted upon)
- Average confidence score per segment
- Cloud vs fallback ratio (% of requests served by cloud vs local)
- Escalation rate (% of recommendations that escalate to LLM)

**Key files:**
- `FitTracker/AI/AIOrchestrator.swift` (153 lines)
- `FitTracker/AI/AIEngineClient.swift` (85 lines)
- `FitTracker/AI/AITypes.swift` — AISegment, AIRecommendation, AIRecommendationSet, LocalUserSnapshot
- `FitTracker/AI/AISnapshotBuilder.swift` — builds snapshot from live data
- `FitTracker/AI/FoundationModelService.swift` — on-device LLM adapter

---

### 2.10 Design System v2

**Purpose:** Three-tier semantic design token architecture that ensures visual consistency across all screens, enables Dark Mode, supports automated Figma sync, and provides a foundation for Android adaptation.

**Business objective:** Design system reduces development time (no ad-hoc styling decisions), ensures accessibility compliance (WCAG AA), and enables platform expansion (Android tokens from same source).

**Functional requirements:**

| Requirement | Status | Details |
|-------------|--------|---------|
| Three-tier architecture | Shipped | AppPalette (primitives) → AppTheme (semantic) → Views (consumption) |
| 57 color tokens | Shipped | Brand (6), Background (7), Surface (7), Text (6), Border (3), Accent (5), Status (3), Chart (6), Focus (1), Selection (2) |
| 43 asset catalog colorsets | Shipped | All with Light + Dark mode variants |
| 9 spacing tokens | Shipped | 4pt grid: micro(2) through xxLarge(40) |
| 9 radius tokens | Shipped | micro(4) through authSheet(36) |
| 20 typography tokens | Shipped | hero through monoLabel |
| Motion tokens | Shipped | 5 durations, 4 spring presets, 4 easing curves, 4 loading animations |
| Shadow tokens | Shipped | Card (subtle) + CTA (brand-tinted) |
| 87 icon constants | Shipped | AppIcon enum wrapping all SF Symbols |
| 6 atomic components | Shipped | AppPickerChip, AppFilterBar, AppSheetShell, AppStatRow, AppSegmentedControl, AppProgressRing |
| 7 composite components | Shipped | AppCard, AppButton, AppMenuRow, AppSelectionTile, AppFieldLabel, AppInputShell, AppQuietButton |
| Token pipeline | Shipped | tokens.json → Style Dictionary → DesignTokens.swift |
| CI gate | Shipped | `make tokens-check` verifies sync before build |
| WCAG AA contrast | Shipped | Text.tertiary at 4.6:1, validated with ColorContrastValidator |
| Reduce Motion support | Shipped | AppMotion + MotionSafe modifier |
| FitMeLogoLoader | Shipped | Branded animation (4 modes × 3 sizes) |
| 95% token adoption | Shipped | ~9 raw literals remaining across 25 views |

**Current state & gaps:**

| Gap | Priority | Notes |
|-----|----------|-------|
| Dark Mode not tested end-to-end | Medium | Asset catalog has dark values but no systematic verification |
| Code Connect not started | Low | Figma ↔ code component mapping |
| 9 raw literals remaining | Low | Mostly responsive micro-adjustments in MainScreenView |
| No Android token output | Medium | Style Dictionary config needs Android platform |
| Dynamic Type partial | Medium | @ScaledMetric not applied to all text tokens |

**Success metrics:**
- Token adoption rate (% of views using semantic tokens exclusively)
- Raw literal count (target: 0 in new code)
- CI gate pass rate (tokens-check should never fail)
- Accessibility audit pass rate

**Key files:**
- `FitTracker/Services/AppTheme.swift` (267 lines — all semantic tokens)
- `FitTracker/DesignSystem/AppPalette.swift` (39 lines — raw primitives)
- `FitTracker/DesignSystem/AppComponents.swift` (267 lines — 6 atomic components)
- `FitTracker/DesignSystem/AppMotion.swift` (90 lines — motion tokens)
- `FitTracker/DesignSystem/AppIcon.swift` (86 lines — SF Symbol inventory)
- `FitTracker/DesignSystem/AppViewModifiers.swift` (187 lines — shared modifiers)
- `FitTracker/DesignSystem/DesignTokens.swift` (69 lines — auto-generated)
- `FitTracker/DesignSystem/FitMeLogoLoader.swift` (180 lines — branded loader)
- `design-tokens/tokens.json` — token source of truth
- `sd.config.js` — Style Dictionary config

---

### 2.11 Onboarding (Shipped)

**Purpose:** First-run experience that introduces users to FitMe's key features, requests necessary permissions with context, and guides them to a meaningful first action.

**Business objective:** Onboarding directly impacts D1 retention and first-run activation quality.

**Current implementation:** A shipped multi-step onboarding flow lives in the canonical repo and completed the full PM-flow lifecycle during the v2 UX alignment pass.

**Current requirements:**

| Requirement | Status | Details |
|-------------|--------|---------|
| Welcome slide | Shipped | Brand introduction with FitMe identity and value framing |
| Goal setup | Shipped | Captures user intent early |
| Profile capture | Shipped | Lightweight context for personalization |
| Consent framing | Shipped | Privacy-first context before deeper setup |
| HealthKit permission | Shipped | Guided request rather than blind system prompt |
| First action CTA | Shipped | Routes users into the product with direction |
| Skip option | Shipped | Users can continue without a hard block |

**Current state:** Shipped on main; tracked as complete in `.claude/features/onboarding/state.json`.

**Success metrics:**
- Onboarding completion rate (target: >80%)
- Permission grant rate (HealthKit, notifications)
- Time to first meaningful action (target: <5 minutes after install)
- D1 retention for users who complete vs skip onboarding

## Part 3: Non-Functional Requirements

### 3.1 Security & Privacy

| Requirement | Status | Implementation |
|-------------|--------|----------------|
| Encryption at rest | Shipped | AES-256-GCM via CryptoKit |
| Zero-knowledge sync | Shipped | Servers store only `.ftenc` ciphertext blobs |
| Biometric-gated keys | Shipped | Secure Enclave P-256 keys with biometric ACL |
| GDPR Article 5 compliance | Shipped | Data minimization — only banded values leave device |
| GDPR Article 17 (erasure) | Shipped | Account deletion flow shipped in GDPR compliance work |
| GDPR Article 20 (portability) | Shipped | Data export flow shipped in GDPR compliance work |
| Session token security | Shipped | Memory-only session token, never persisted to disk |
| File protection | Shipped | `NSFileProtectionCompleteUnlessOpen` |

### 3.2 Performance

| Metric | Target | Current |
|--------|--------|---------|
| Cold start | <2s | Not measured |
| Screen transition | <300ms | Meets target (AppMotion.standard) |
| Sync latency (incremental) | <5s | Not measured |
| Encryption overhead | <50ms per record | Not measured |
| Chart render | <500ms | Not measured |

### 3.3 Accessibility

| Requirement | Status |
|-------------|--------|
| WCAG AA contrast | Shipped (4.6:1+ on all text) |
| Dynamic Type | Partial (not all text tokens use @ScaledMetric) |
| VoiceOver labels | Partial (key components labeled, not comprehensive) |
| Reduce Motion | Shipped (AppMotion + MotionSafe modifier) |
| Minimum tap targets | Shipped (44pt enforced) |

### 3.4 Scalability

| Component | Strategy |
|-----------|----------|
| Supabase backend | Horizontal scaling, connection pooling |
| AI Engine (Railway) | Auto-scaling containers |
| CloudKit | Apple-managed infrastructure |
| Local storage | Encrypted JSON files, bounded by device storage |

---

## Part 4: Prioritization & Roadmap

### MoSCoW for Current Features

| Priority | Features |
|----------|----------|
| **Must Have** | Training Tracking, Nutrition Logging, Home/Today, Authentication, Data & Sync |
| **Should Have** | Stats/Progress, Recovery & Biometrics, AI Intelligence, Settings |
| **Could Have** | Onboarding polish, Design System Catalog, FitMeLogoLoader animations |
| **Won't Have (this maintenance cycle)** | Blood Test Reader, DEXA Import, Android, public marketing launch |

### RICE Roadmap Reference

Full RICE-prioritized 18-task roadmap with phase gates: see [`docs/master-plan/master-backlog-roadmap.md`](../master-plan/master-backlog-roadmap.md)

---

## Part 5: Appendices

### A. Glossary

| Term | Definition |
|------|------------|
| PRD | Product Requirements Document |
| RPE | Rate of Perceived Exertion (6-10 scale) |
| PR | Personal Record (heaviest set for an exercise) |
| HRV | Heart Rate Variability (ms) |
| RHR | Resting Heart Rate (bpm) |
| LBM | Lean Body Mass (kg) |
| BF% | Body Fat Percentage |
| Zone 2 | Aerobic training zone (106-124 bpm default) |
| RICE | Reach × Impact × Confidence / Effort scoring |
| MoSCoW | Must/Should/Could/Won't prioritization |
| WAU | Weekly Active Users |
| NPS | Net Promoter Score |

### B. API Contracts

**AI Engine endpoints:**
- `POST /v1/training/insight` — training recommendations
- `POST /v1/nutrition/insight` — nutrition recommendations
- `POST /v1/recovery/insight` — recovery recommendations
- `POST /v1/stats/insight` — stats/progress recommendations
- `GET /health` — service health check

All endpoints require `Authorization: Bearer <JWT>` (Supabase JWKS-validated).

### C. Data Model Reference

Core types defined in `FitTracker/Models/DomainModels.swift`:
- `DailyLog` — daily container (training, nutrition, biometrics, mood)
- `ExerciseLog` / `SetLog` — strength training data
- `CardioLog` — cardio session data
- `NutritionLog` / `MealEntry` / `MealTemplate` — nutrition data
- `SupplementLog` / `SupplementDefinition` — supplement tracking
- `DailyBiometrics` — health metrics (auto + manual)
- `UserProfile` — goals, phase, demographics
- `UserPreferences` — configurable thresholds
- `WeeklySnapshot` — aggregated weekly summary
- `ExportPackage` — complete data export structure

### D. Design Token Inventory

92 semantic tokens defined in `FitTracker/Services/AppTheme.swift`:
- **AppColor** — 57 color tokens across 10 namespaces
- **AppSpacing** — 9 tokens (4pt grid: 2-40pt)
- **AppRadius** — 9 tokens (4-36pt)
- **AppText** — 20 typography tokens
- **AppShadow** — card + CTA shadow definitions
- **AppSheet** — standard (32pt) + auth (36pt) corner radii
- **AppGradient** — 4 gradient definitions
- **AppMotion** — durations, springs, easing, loading animations
- **AppIcon** — 87 SF Symbol constants

Token source: `design-tokens/tokens.json`  
Pipeline: `tokens.json` → Style Dictionary (`sd.config.js`) → `DesignTokens.swift`  
CI gate: `make tokens-check`

---

*End of PRD — this is a living document. Update as features evolve.*
