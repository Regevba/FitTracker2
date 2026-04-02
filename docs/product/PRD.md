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

*Part 2 (Feature Requirements) continues below...*
