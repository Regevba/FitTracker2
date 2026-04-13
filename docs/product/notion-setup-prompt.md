# Prompt: Set Up FitMe PRD & Backlog in Notion

Copy and paste the following prompt into Claude console (claude.ai) with Notion MCP connected:

---

## Prompt

```
I need you to create a complete product management workspace in Notion for my app "FitMe" (FitTracker). Create the following structure under a top-level page called "FitMe — Product Hub":

## 1. PRD Page

Create a page called "FitMe PRD v2.0" with these sections:

### Part 1: Product Strategy
- **Problem Statement:** Serious fitness enthusiasts use 3-5 separate apps for training, nutrition, recovery, and body composition. This creates data silos, decision fatigue, privacy erosion, and inconsistent UX.
- **Vision:** "FitMe is the iPhone-first fitness command center that unifies training, nutrition, recovery, and body composition into a single privacy-first experience — powered by federated AI."
- **North Star Metric:** Weekly Active Users who complete at least one training session AND log at least one meal.
- **Personas:**
  1. The Consistent Lifter (25-40, trains 4-6x/week, wants progressive overload tracking)
  2. The Health-Conscious Professional (30-50, trains 3-4x/week, wants simplicity)
  3. The Data-Driven Optimizer (25-45, wants DEXA, blood work, deep stats)
- **Business Objectives:** Freemium model — Free tier (core tracking) + Premium ($9.99/mo) with AI, advanced stats, cloud sync
- **Competitive Landscape:** Fitbod, Strong, MyFitnessPal, Hevy, MacroFactor — FitMe wins on privacy (zero-knowledge encryption), unified experience (one app for all), and federated AI
- **Go-to-Market:** TestFlight beta → App Store launch → Influencer growth → Android expansion

### Part 2: Feature Requirements
Create 11 sub-pages, one per feature, each with: Purpose, Business Objective, Functional Requirements (table), User Flows, Current State & Gaps (table), Acceptance Criteria, Success Metrics, Key Files.

Features:
1. **Training Tracking** — 87 exercises, set×rep×weight, RPE, PRs, rest timer, cardio, photo capture
2. **Nutrition Logging** — Dynamic macro targets, 4-tab meal entry (smart label, manual, template, search), supplement tracking, hydration
3. **Recovery & Biometrics** — HealthKit, manual entry, readiness scoring, HRV zones, status dots
4. **Home / Today Screen** — LiveInfoStrip, ReadinessCard (5 pages auto-cycling), progress orb, training button
5. **Stats / Progress Hub** — 18 metrics, 5 periods, charts with delta indicators, PR records, data source badges
6. **Authentication** — Apple Sign In, passkeys, email/OTP, biometric lock (Face ID/Touch ID)
7. **Settings** — 5 category groups (Account, Health, Goals, Training, Data), detail screens
8. **Data & Sync** — AES-256-GCM encryption, CloudKit + Supabase, zero-knowledge, realtime subscriptions
9. **AI / Cohort Intelligence** — Federated: cloud baseline + on-device Foundation Model, privacy-preserving bands, 4 segments
10. **Design System v2** — 92 tokens, 43 colorsets, 13 components, token pipeline, CI gate, 95% adoption
11. **Onboarding** (planned) — Welcome, feature highlights, HealthKit permission, goal setup, first action CTA

### Part 3: Non-Functional Requirements
Security (AES-256, zero-knowledge, GDPR gaps), Performance targets, Accessibility (WCAG AA), Scalability

### Part 4: Prioritization
MoSCoW table: Must Have / Should Have / Could Have / Won't Have

---

## 2. Metrics Database

Create a Notion database called "Metrics Framework" with columns: Metric Name, Category (select: Product/Health/AI/Technical/Business/CX), Target, Instrumentation Status (select: Available Now/Requires GA4/Requires Firebase/Requires Skills OS/Requires CX/Requires External), PRD Section (text), Cadence (select: Daily/Weekly/Monthly).

Add these 40 metrics:

**Product:** DAU, WAU, MAU, Cross-feature WAU (North Star), D1/D7/D30 Retention, Avg session length, Sessions/day
**Health:** Training sessions/week (target: 3+), Sets/session (15+), PR frequency (2+/mo), Session completion (>80%), Meals/day (2+), Supplement adherence (>70%), Protein hit rate (>60%), Template usage (>30%), Biometric entry rate (>50%), HealthKit connection (>70%), Readiness check-in (>40%)
**AI:** Recommendation acceptance (>30%), Avg confidence (>0.6), Cloud vs fallback (>70% cloud), Escalation rate (<20%), AI latency p50 (<500ms), p95 (<2s)
**Technical:** Crash-free (>99.5%), Cold start (<2s), Sync success (>99%), Sync latency p50 (<3s), Encryption overhead (<50ms), Token pipeline (100%), Build success (>95%)
**Business:** Total installs (50K Y1), Premium conversion (>5%), Monthly churn (<8%), LTV (TBD), CAC (TBD), Organic ratio (>70%)
**CX:** App Store rating (>4.5), NPS (>50), CSAT (>80%), Review response (<24h), Support resolution (<48h), Sentiment (>80% positive)

---

## 3. Backlog Database

Create a Notion database called "Product Backlog" with columns: Title, Status (select: Done/In Progress/Planned/Backlog/Icebox), Priority (select: Critical/High/Medium/Low), RICE Score (number), Phase (select: 0/1/2/3/4/5), Category (select: GDPR/Product/UX/Design System/Platform/Feature), Assignee (person), Due Date, Notes.

Add these items:

**Done (10 items):** Core app foundation, Today-first redesign, Auth overhaul, Federated AI, iOS stability, Design System v2, CI fixes, Simulator auto-login, RICE roadmap, Phase 0 PRD

**Planned (16 RICE-ordered tasks):** Metrics framework (20.0), Backlog dump (20.0), Public README (16.0), Unified PRD (15.0), Google Analytics (8.0), Android design system (4.8), Figma prototype (4.3), Marketing website (4.3), Android build research (3.6), Skills OS (3.2), CX system (3.2), Notion integration (3.0), Health APIs (2.1), DEXA/body comp (2.0), Blood test reader (1.3), Skills feature (1.0)

**Backlog (current high-signal set):** Account deletion (GDPR Critical), Data export (GDPR Critical), Auth runtime verification (High), Push notifications (High), App Store assets (High), Import training plan (High), Chart goal lines (Medium), Chart tooltips (Medium), Trend alerts (Medium), Exercise search (Medium), Program customization (Medium), Notification settings (Medium), Data export UI (Medium), AI feedback loop (Medium), Dark Mode testing (Medium), Dynamic Type (Medium), Code Connect (Medium), 1RM calculator (Low), Supersets (Low), Custom exercises (Low), Meal timing (Low), Photo food logging (Low), AI meal suggestions (Low), Chart export (Low), Chart comparison (Low), Watch complication (Low), Widgets (Low), iPad layouts (Low), Passcode fallback (Low), Phone OTP (Low)

**Icebox:** Wear OS app, Web dashboard, Social features, Meal photo recognition, Blood pressure, Respiratory rate, Sleep stages, Multi-language, Offline conflict UI

---

## 4. Roadmap Timeline

Create a Notion database called "Roadmap" with columns: Phase, Phase Name, Status (select: Active/Locked/Complete), Tasks (relation to Backlog), Start Date, Target End Date, Gate Criteria.

Phases:
- Phase 0: Foundation (Active) — PRD, metrics, backlog
- Phase 1: Design & Prototype (Locked) — Figma prototype, public README
- Phase 2: Measurement & CX (Locked) — Analytics, Skills OS, CX system
- Phase 3: Platform Expansion (Locked) — Android research, health APIs, DEXA
- Phase 4: Advanced Features (Locked) — Blood test reader, skills feature
- Phase 5: Marketing & Launch (Locked) — Website, App Store assets

Gate rule: Phase N must be approved before Phase N+1 unlocks.
```

---

## Usage Notes
- Paste this prompt into Claude console (claude.ai/code or claude.ai) with Notion MCP connected
- Claude will create the pages, databases, and entries automatically
- Review and adjust targets/priorities after creation
- The PRD is a living document — update as features evolve
