# FitTracker2 — Master Backlog & Roadmap (RICE Prioritized)

## Context
Complete project roadmap with 18 tasks across 6 phases. Prioritized using the RICE framework (Reach × Impact × Confidence / Effort). Each phase completion is a **gateway** — no coding for the next phase begins until the current phase is approved.

**Added 2026-04-02:** Task 18 — Create PRD for every existing shipped feature before building new ones.

> **2026-04-27 — framework v7.7 freeze:** RICE-prioritized product work below is **paused** for ~2-3 weeks while v7.7 (Validity Closure) lands. v7.7 is framework-infrastructure work (data integrity gates), not a RICE-tracked product feature. Resume of paused features (`app-store-assets`, `auth-polish-v2`, `import-training-plan`, `onboarding-v2-retroactive`, `push-notifications`, `stats-v2`) is gated on v7.7 phase=complete. See [`docs/master-plan/master-plan-2026-04-15.md`](master-plan-2026-04-15.md) for the v7.7 banner and [`docs/superpowers/specs/2026-04-27-framework-v7-7-validity-closure-design.md`](../superpowers/specs/2026-04-27-framework-v7-7-validity-closure-design.md) for scope.

---

## RICE Scoring Legend

| Factor | Scale | Description |
|--------|-------|-------------|
| **Reach** | 1-10 | How many users/stakeholders does this impact? |
| **Impact** | 0.25 / 0.5 / 1 / 2 / 3 | Minimal / Low / Medium / High / Massive |
| **Confidence** | 50% / 80% / 100% | Low / Medium / High certainty |
| **Effort** | Person-weeks | How long to complete |
| **RICE Score** | R × I × C / E | Higher = do first |

---

## RICE PRIORITIZATION MATRIX

| # | Task | Reach | Impact | Confidence | Effort (wks) | RICE Score | Priority |
|---|------|-------|--------|------------|-------------|------------|----------|
| 18 | PRD per existing feature | 10 | 3 | 100% | 2 | **15.0** | CRITICAL |
| 12 | PRD — Business objectives | 10 | 3 | 100% | 2 | **15.0** | CRITICAL |
| 13 | Metrics definition | 10 | 2 | 100% | 1 | **20.0** | CRITICAL |
| 6 | Full backlog dump | 10 | 2 | 100% | 1 | **20.0** | CRITICAL |
| 4 | Google Analytics integration | 10 | 2 | 80% | 2 | **8.0** | HIGH |
| 1 | Figma working prototype | 8 | 2 | 80% | 3 | **4.3** | HIGH |
| 17 | Public README | 8 | 1 | 100% | 0.5 | **16.0** | HIGH |
| 15 | CX system | 8 | 2 | 80% | 4 | **3.2** | HIGH |
| 14 | Skills operating system | 6 | 2 | 80% | 3 | **3.2** | HIGH |
| 16 | Comprehensive marketing website | 8 | 2 | 80% | 3 | **4.3** | HIGH |
| 2 | Android design system investigation | 6 | 2 | 80% | 2 | **4.8** | MEDIUM |
| 3 | Android full app build research | 6 | 2 | 60% | 2 | **3.6** | MEDIUM |
| 10 | Health app API connections | 7 | 2 | 60% | 4 | **2.1** | MEDIUM |
| 11 | DEXA + body composition layers | 5 | 1 | 80% | 2 | **2.0** | MEDIUM |
| 5 | Skills feature (in-app) | 5 | 1 | 60% | 3 | **1.0** | LOW |
| 9 | Blood test reader | 7 | 3 | 50% | 8 | **1.3** | LOW |
| 7 | Notion MCP integration | 3 | 1 | 50% | 0.5 | **3.0** | LOW |
| 8 | Marketing mini-site | — | — | — | — | — | SUPERSEDED by Task 16 |
| 19 | Marketing & Growth Strategy | 10 | 2 | 60% | 6 | **2.0** | HIGH |

---

## PHASE 0 — Foundation (CRITICAL)
**Gateway:** All Phase 0 tasks must be approved before any coding begins.

### Task 18: PRD for Every Existing Feature [RICE: 15.0]
**NEW — Phase gate requirement**

Create a viable PRD for each of the 11 shipped feature areas. Each PRD defines:
- **What it is**: Feature description and current implementation
- **Why it exists**: Business objective, user problem solved
- **For whom**: Target persona(s)
- **Success metrics**: How we measure if it's working
- **Current state**: What's built, what's missing, what needs improvement

#### Features requiring PRDs:

| # | Feature Area | Key Files | Status |
|---|-------------|-----------|--------|
| 18.1 | Training Tracking | `TrainingPlanView.swift`, `TrainingProgramStore.swift` | Shipped — 87 exercises, RPE, PRs |
| 18.2 | Nutrition Logging | `NutritionView.swift`, `MealEntrySheet.swift` | Shipped — meals, macros, supplements |
| 18.3 | Recovery & Biometrics | `HealthKitService.swift`, biometric entry | Shipped — HRV, RHR, sleep, weight |
| 18.4 | Home / Today Screen | `MainScreenView.swift`, `ReadinessCard.swift` | Shipped — readiness, goals, status |
| 18.5 | Stats / Progress Hub | `StatsView.swift`, `ChartCard.swift` | Shipped — charts, trends, periods |
| 18.6 | Authentication | `SignInService.swift`, `AuthManager.swift` | Shipped — Apple, email, passkey, biometric lock |
| 18.7 | Settings | `SettingsView.swift` | Shipped — 5 category groups |
| 18.8 | Data & Sync | `EncryptedDataStore`, `SupabaseSyncService` | Shipped — encrypted, CloudKit + Supabase |
| 18.9 | AI / Cohort Intelligence | `AIOrchestrator.swift`, `AIEngineClient.swift` | Shipped — federated, on-device + cloud |
| 18.10 | Design System | `AppTheme.swift`, `DesignSystem/` | Shipped — 92 tokens, 13 components |
| 18.11 | Onboarding | (not yet built) | Planned — PRD defines scope |

Output: `docs/product/prd/` directory with one PRD per feature

---

### Task 12: PRD — Business Objectives & Purpose [RICE: 15.0]
- Product definition, positioning, elevator pitch
- Target personas (primary, secondary, tertiary)
- Problem statement and value proposition
- Business objectives: revenue model, growth targets, retention goals
- Competitive analysis: Fitbod, Strong, MyFitnessPal, Hevy, MacroFactor
- Go-to-market and monetization strategy
- Output: `docs/product/PRD.md`

### Task 13: Metrics Definition [RICE: 20.0]
- Product: DAU/MAU/WAU, retention D1/D7/D30, session length
- Health engagement: workouts/week, meals logged/day, supplement adherence
- AI: recommendation acceptance, confidence, escalation rate
- Technical: crash rate, cold start time, sync latency
- Business: conversion, churn, LTV, CAC
- CX: NPS, CSAT, app store rating, response time
- Output: `docs/product/metrics-framework.md`

### Task 6: Full Memory & Backlog Dump [RICE: 20.0]
- Compile from: README, CHANGELOG, feature-memory, gap-review, handoff, specs
- Output: structured backlog (Done / In Progress / Planned / Backlog)

---

## PHASE 1 — Design & Prototype (HIGH)
**Gateway:** Phase 0 approved → Phase 1 unlocked.

### Task 1: Figma Working Prototype [RICE: 4.3]
- Figma file: `0Ai7s3fCFqR5JXDW8JvgmD`
- Wire all 22+ screens into interactive prototype
- Onboarding flow (3-5 slides, hand-drawn sketching, brand colors)
- Live animations (FitMeLogoLoader, transitions)
- Logo from FitMeLogoLoader.swift
- Loading/empty/error states
- Full flow: Onboarding → Auth → Home → Training → Nutrition → Stats → Settings → Account

### Task 17: Public README [RICE: 16.0]
- Polished public-facing README with badges
- Sections: About, Features, Screenshots, Tech Stack, Architecture
- Links to website and design system docs

---

## PHASE 2 — Measurement & CX (HIGH)
**Gateway:** Phase 1 approved → Phase 2 unlocked.

### Task 4: Google Analytics Integration [RICE: 8.0]
- Event taxonomy, screen mapping (25 views), user properties
- Conversion funnels: onboarding → first workout → first meal → weekly streak
- Firebase Analytics SDK (iOS + Android)
- GDPR consent, data retention, opt-out

### Task 14: Skills Operating System [RICE: 3.2]
- API connections: App Store Connect, Play Console, Firebase, GA4, Supabase, Railway, GitHub Actions
- Review cycles: daily (crashes), weekly (adoption), monthly (cohorts)
- Live dashboard: real-time users, demographics, app health

### Task 15: CX System [RICE: 3.2]
- **15.1** Review monitoring (App Store + Play Store, AI sentiment)
- **15.2** "Rate Me" (SKStoreReviewController, smart timing)
- **15.3** NPS/CSAT (in-app surveys, dashboard, alert below 4.5)
- **15.4** High-rating pipeline → email → approve → post to website
- **15.5** Low-rating follow-up → dynamic email with embedded text box
- **15.6** Public roadmap ("What we fixed", auto-update from GitHub Issues)
- **15.7** Live user dashboard (GA4 Realtime)
- **15.8** Keyword analysis (positive/negative sentiment from reviews)
- **15.9** Follow-through dashboard (public: fixed vs working on, time to fix)

---

## PHASE 3 — Platform Expansion (MEDIUM)
**Gateway:** Phase 2 approved → Phase 3 unlocked.

### Task 2: Android Design System Investigation [RICE: 4.8]
- Map 92 iOS tokens to MD3 equivalents
- Gaps: typography, motion, navigation, icons
- Add Android platform to Style Dictionary
- Asset conversion research

### Task 3: Android Full App Build Research [RICE: 3.6]
- Native Kotlin+Compose vs React Native vs KMP — pros/cons
- Architecture mapping, platform API mapping
- Supabase Android SDK, Health Connect, on-device ML
- Effort estimate: 8-12 weeks

### Task 10: Health App API Connections [RICE: 2.1]
- Expand HealthKit scope (glucose, BP, respiratory)
- Google Health Connect (Android)
- Third-party: Garmin, Whoop, Oura, Samsung Health, Fitbit, MyFitnessPal
- Bidirectional sync

### Task 11: DEXA + Body Composition [RICE: 2.0]
- DEXA scan import (manual/photo)
- Regional breakdown, visceral fat, waist-hip ratio
- New "Body Comp" tab in Stats

---

## PHASE 4 — Advanced Features (LOW)
**Gateway:** Phase 3 approved → Phase 4 unlocked.

### Task 9: Blood Test Reader [RICE: 1.3]
- Input: photo/PDF → OCR (Apple Vision / ML Kit)
- Process: parse biomarkers (CBC, lipid, metabolic, hormones, vitamins)
- Display: reference ranges, trends, AI interpretation
- Delete: GDPR Article 17 full erasure
- Security: AES-256-GCM, zero-knowledge, on-device OCR only, audit trail
- Regulatory: FDA wellness vs medical device, EU MDR, GDPR Article 9

### Task 5: Skills Feature (In-App) [RICE: 1.0]
- Define categories, progression model, data model, UI
- Integrate with training + stats

---

## PHASE 5 — Marketing & Growth (HIGH — after product stable)
**Gateway:** Phase 2+ approved → Phase 5 can run in parallel.

### Task 16: Comprehensive Marketing Website [RICE: 4.3]
- Hero, features (6-8 cards), screenshots, testimonials (from CX pipeline)
- Live rating badge, download CTAs, Q&A/FAQ
- Customer success email: `support@fitme.app`
- Public roadmap link, privacy policy, terms
- Stack: Astro/Next.js + Tailwind, Vercel
- SEO, Open Graph, GA4

### Task 19: Marketing & Growth Strategy [RICE: 2.0]

**SEO & Content Marketing:**
- Marketing website SEO (metadata, structured data, sitemap, OG tags, robots.txt)
- Landing pages with keyword targeting (fitness tracker, workout log, nutrition tracker)
- Blog/content hub for organic search (workout guides, nutrition tips)
- Link building (fitness communities, app review sites)

**Paid Acquisition — Google:**
- Google Ads Search campaigns (branded + category keywords)
- Google App campaigns (UAC — automated install campaigns)
- YouTube pre-roll ads (short-form demo targeting fitness audiences)

**Paid Acquisition — Meta (Facebook + Instagram):**
- Facebook App Install campaigns (lookalike audiences)
- Instagram Stories/Reels ads (visual workout tracking demos)
- Retargeting campaigns (website visitors, app abandoners)

**App Store Optimization — Apple:**
- Listing optimization (title, subtitle, keywords, description)
- Screenshot templates (6.7" + 6.5" + 12.9" iPad)
- App Preview video (15-30s core workflow demo)
- Apple Search Ads (basic + advanced keyword bidding)
- App Store feature nomination
- In-app review prompt strategy (timing, frequency)

**App Store Optimization — Google Play:**
- Play Store listing optimization (title, descriptions, tags)
- Screenshots + feature graphic
- Pre-registration campaign (before Android launch)
- LiveOps cards and promotional content

**Product Marketing:**
- Positioning & messaging framework (ICP, value props per persona)
- Competitive comparison pages (vs MyFitnessPal, Strong, Hevy, Strava)
- Feature launch announcements (in-app + email + social)
- Referral program design
- Email automation (onboarding drip, re-engagement, milestones)
- Social media presence (Instagram, Twitter/X, Reddit r/fitness)

**Analytics & Attribution:**
- UTM parameter strategy for all campaigns
- Firebase Dynamic Links for deep linking
- Attribution tracking (campaign → install → active → retained)
- ROAS dashboard per channel
- GA4 conversion events linked to marketing funnels

### Task 7: Notion MCP Integration [RICE: 3.0]
- Requires OAuth via claude.ai/code Settings
- Once connected: create Roadmap DB, Backlog DB, transfer all tasks

---

## PHASE GATE RULES

1. **No coding for Phase N+1 until Phase N is reviewed and approved**
2. Each phase produces specific deliverables (docs, prototypes, research)
3. Approval = user explicitly confirms "phase complete, proceed to next"
4. Tasks within a phase can run in parallel
5. Phase 5 (Marketing) can run in parallel with Phases 3-4 once Phase 2 is done

---

## CURRENT STATUS

| Phase | Status | Blocker |
|-------|--------|---------|
| Phase 0 | **COMPLETE** | Tasks 6, 12, 13, 18 all shipped |
| Phase 1 | **ACTIVE** | Task 17 (README) in progress, Task 1 (Figma) next |
| Phase 2 | Partially shipped | Task 4 (GA4) shipped; Tasks 14, 15 remaining |
| Phase 3 | Partially shipped | Task 2 (Android DS) shipped; Tasks 3, 10, 11 remaining |
| Phase 4 | Locked | Waiting for Phase 3 |
| Phase 5 | Partially shipped | Task 16 (Marketing Website) shipped; Task 19 remaining |

---

## SHIPPED FEATURES (for reference)

### Core iOS Features
| # | Feature | Files | Token Coverage | Tests |
|---|---------|-------|---------------|-------|
| 1 | Training (49 exercises, RPE, PRs) | TrainingPlanView, TrainingProgramStore | 100% | Yes |
| 2 | Nutrition (meals, macros, supplements) | NutritionView, MealEntrySheet, MealSectionView | 95% | Yes |
| 3 | Recovery (HRV, RHR, sleep, weight, BF%) | HealthKitService, biometric entry | 100% | Yes |
| 4 | Home / Today (readiness, goals, status) | MainScreenView, ReadinessCard | 95% | Yes |
| 5 | Stats (charts, trends, periods) | StatsView, ChartCard, MetricCard | 100% | Yes |
| 6 | Auth (Apple, email, passkey, biometric) | SignInService, AuthManager | 100% | Yes |
| 7 | Settings (9 categories) | SettingsView | 100% | Yes |
| 8 | Data & Sync (AES-256 + ChaCha20, dual backend) | EncryptedDataStore, SupabaseSyncService | N/A | Yes |
| 9 | AI / Cohort Intelligence | AIOrchestrator, AIEngineClient | N/A | Yes |
| 10 | Design System v2 | AppTheme, DesignSystem/ | 95% | Yes |
| 11 | CI Pipeline | ci.yml, token pipeline | N/A | Green |

### Features Built via PM Workflow
| # | Feature | Branch | Status |
|---|---------|--------|--------|
| 12 | Google Analytics (GA4) | feature/google-analytics | Merged to main |
| 13 | GDPR Compliance | feature/gdpr-compliance | Merged to main |
| 14 | Development Dashboard | feature/development-dashboard | Merged to main |
| 15 | Android Design System | feature/android-design-system (on main) | Complete |
| 16 | Marketing Website | feature/marketing-website | Merged to main |

### Individual Feature PRDs
All 18 features documented in `docs/product/prd/` (Task 18 complete)

---

## Verification
- Phase 0: PRD docs reviewed, metrics doc reviewed, backlog compiled
- Phase 1: Figma prototype interactive and complete, README published
- Phase 2: Firebase events firing, CX dashboard live, NPS baseline
- Phase 3: Android research doc with effort estimates, token export working
- Phase 4: Blood test OCR demo, regulatory assessment doc
- Phase 5: Website deployed, support email active, SEO indexed
