# FitMe — Metrics Framework

> Defines what to measure, how to measure it, and when to review it.  
> Each metric links to a PRD feature section and indicates instrumentation status.  
> Last updated: 2026-04-02

---

## 1. Product Engagement

| Metric | Definition | Target | Instrumentation | PRD Section |
|--------|-----------|--------|-----------------|-------------|
| DAU | Unique users opening app per day | — | Requires GA4 (Task 4) | 1.8 |
| WAU | Unique users with ≥1 session per week | — | Requires GA4 | 1.8 |
| MAU | Unique users with ≥1 session per month | — | Requires GA4 | 1.8 |
| Cross-feature WAU (North Star) | Users who train + log meal in same week | 40% of installs | Requires GA4 | 1.2 |
| D1 Retention | % returning Day 1 | >60% | Requires Firebase | 1.5 |
| D7 Retention | % returning Day 7 | >30% | Requires Firebase | 1.5 |
| D30 Retention | % returning Day 30 | >20% | Requires Firebase | 1.5 |
| Avg session length | Time per app open | >3 min | Requires GA4 | — |
| Sessions per day | App opens per active user | 1.5+ | Requires GA4 | 2.4 |

## 2. Health & Fitness Engagement

| Metric | Definition | Target | Instrumentation | PRD Section |
|--------|-----------|--------|-----------------|-------------|
| Training sessions/week | Sessions logged per user per week | 3+ | Available now (DailyLog count) | 2.1 |
| Avg sets per session | Sets logged per completed session | 15+ | Available now (ExerciseLog) | 2.1 |
| PR frequency | New personal records per user per month | 2+ | Available now (StatsDataHelpers.prRecords) | 2.1 |
| Session completion rate | % of started sessions fully completed | >80% | Available now (completionPct) | 2.1 |
| Meals logged/day | Meals logged per active user per day | 2+ | Available now (NutritionLog.meals.count) | 2.2 |
| Supplement adherence | % of days with both AM+PM completed | >70% | Available now (SupplementLog) | 2.2 |
| Protein target hit rate | % of days within ±10% of protein target | >60% | Available now (computed) | 2.2 |
| Template usage rate | % of meals from templates vs manual | >30% | Available now (MealEntrySource) | 2.2 |
| Daily biometric entry rate | % of active days with ≥1 metric logged | >50% | Available now (DailyBiometrics) | 2.3 |
| HealthKit connection rate | % of users with HealthKit authorized | >70% | Available now (HealthKitService) | 2.3 |
| Readiness check-in rate | % of users who view readiness daily | >40% | Requires GA4 (screen_view) | 2.4 |

## 3. AI & Intelligence

| Metric | Definition | Target | Instrumentation | PRD Section |
|--------|-----------|--------|-----------------|-------------|
| Recommendation acceptance rate | % of AI recommendations acted upon | >30% | Requires Task 14 (Skills OS) | 2.9 |
| Avg confidence score | Mean confidence across all recommendations | >0.6 | Available now (AIRecommendation.confidence) | 2.9 |
| Cloud vs fallback ratio | % served by cloud vs local rules | >70% cloud | Available now (AIOrchestrator logs) | 2.9 |
| Escalation rate | % of recommendations escalating to LLM | <20% | Available now (escalateToLLM flag) | 2.9 |
| AI Engine latency (p50) | Median cloud response time | <500ms | Requires Railway metrics | 2.9 |
| AI Engine latency (p95) | 95th percentile response time | <2s | Requires Railway metrics | 2.9 |

## 4. Technical Health

| Metric | Definition | Target | Instrumentation | PRD Section |
|--------|-----------|--------|-----------------|-------------|
| Crash-free rate | % of sessions without crashes | >99.5% | Requires Crashlytics/Sentry | 3.2 |
| Cold start time | Time from tap to interactive | <2s | Requires instrumentation | 3.2 |
| Sync success rate | % of push/pull without errors | >99% | Available now (SupabaseSyncService.status) | 2.8 |
| Sync latency (p50) | Median incremental pull time | <3s | Requires instrumentation | 2.8 |
| Encryption overhead | ms added per read/write | <50ms | Requires instrumentation | 2.8 |
| Token pipeline sync | tokens-check CI gate pass rate | 100% | Available now (CI) | 2.10 |
| Build success rate | CI build pass rate | >95% | Available now (GitHub Actions) | — |

## 5. Business & Growth

| Metric | Definition | Target | Instrumentation | PRD Section |
|--------|-----------|--------|-----------------|-------------|
| Total installs | Cumulative app installs | 50K Y1 | App Store Connect | 1.5 |
| Premium conversion | % of users on paid tier | >5% | Requires revenue tracking | 1.5 |
| Monthly churn | % of premium subscribers who cancel | <8% | Requires subscription analytics | 1.5 |
| LTV (Lifetime Value) | Average revenue per user over lifetime | TBD | Requires revenue + retention data | 1.5 |
| CAC (Customer Acquisition Cost) | Cost to acquire one user | TBD | Requires marketing spend data | 1.7 |
| Organic vs paid ratio | % of installs from organic vs campaigns | >70% organic | Requires attribution | 1.7 |

## 6. Customer Experience

| Metric | Definition | Target | Instrumentation | PRD Section |
|--------|-----------|--------|-----------------|-------------|
| App Store rating | Average rating on App Store | >4.5 | App Store Connect API | 1.8 |
| NPS | Net Promoter Score (0-100) | >50 | Requires in-app survey (Task 15) | 1.8 |
| CSAT | Customer Satisfaction Score | >80% | Requires in-app survey (Task 15) | 1.8 |
| Review response time | Time to respond to negative reviews | <24h | Requires CX system (Task 15) | — |
| Support resolution time | Time to resolve support tickets | <48h | Requires support email setup | — |
| Written review sentiment | % positive vs negative keywords | >80% positive | Requires AI analysis (Task 15.8) | — |

---

## Dashboard Cadence

### Daily Checks
- Crash-free rate
- Critical reviews (1-2 stars)
- AI engine health (latency, errors)
- Sync success rate
- Active users (if GA4 live)

### Weekly Reviews
- Retention curves (D1/D7)
- Feature adoption (training sessions, meals logged)
- NPS movement
- App Store rating trend
- PR frequency

### Monthly Cohort Analysis
- D30 retention by cohort
- Revenue trends (premium conversion, churn)
- Competitive positioning check
- Feature usage distribution
- AI recommendation effectiveness

---

## Instrumentation Readiness

| Status | Count | Details |
|--------|-------|---------|
| **Available now** | 14 | Metrics computable from existing data models (DailyLog, ExerciseLog, etc.) |
| **Requires GA4 (Task 4)** | 11 | Screen views, session length, retention, DAU/WAU/MAU |
| **Requires Firebase** | 3 | Retention curves, crash-free rate |
| **Requires Task 14 (Skills OS)** | 3 | Recommendation acceptance, review analysis |
| **Requires Task 15 (CX)** | 4 | NPS, CSAT, review response time, sentiment |
| **Requires external** | 5 | App Store Connect, Railway metrics, revenue tracking |
| **Total** | 40 | |
