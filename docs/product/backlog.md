# FitMe — Complete Backlog

> Compiled from: README, CHANGELOG, feature-memory, gap-review, resume-handoff, master plan, PRD gaps, session work.  
> Last updated: 2026-04-15

---

## Done (Shipped)

| # | Feature | PR/Commit | Date | Notes |
|---|---------|-----------|------|-------|
| 1 | Core app foundation (SwiftUI shell, encrypted data, HealthKit) | Initial commits | 2026-02-28 | Base product |
| 2 | Today-first product redesign (Home, Training, Nutrition, Stats) | Redesign phase | 2026-03-14 | 5-pass redesign |
| 3 | Auth & settings overhaul (Apple Sign In, passkeys, grouped settings) | PR #10, #13 | 2026-03-25 | Auth hub + 5 settings groups |
| 4 | Federated cohort intelligence (AI engine, backend, iOS AI layer) | PR #12 | 2026-03-26 | FastAPI + AIOrchestrator |
| 5 | iOS stability, Supabase sync, auth security hardening | PR #13 | 2026-03-29 | Phase 5a+5b |
| 6 | Design System v2 (three-tier tokens, 13 components, WCAG AA, CI pipeline) | PR #17 | 2026-04-01 | 173 files, 92 tokens |
| 7 | CI fixes (Supabase API, switch exhaustiveness, smart quotes, test brace) | PR #17 | 2026-04-01 | 5 compile errors fixed |
| 8 | Simulator auto-login + token cleanup | PR #18 | 2026-04-02 | DEBUG bypass, LiveInfoStrip/NutritionView tokens |
| 9 | RICE-prioritized 18-task roadmap with phase gates | PR #19 | 2026-04-02 | Master backlog doc |
| 10 | Phase 0 PRD + metrics + backlog | Current branch | 2026-04-02 | This document |
| 11 | Development Dashboard (Astro + React + Tailwind v4) | feature/development-dashboard | 2026-04-02 | Kanban, table, reconciliation, dark mode |
| 12 | PM Workflow Skill (/pm-workflow) | PR #21 | 2026-04-02 | 10-phase lifecycle (0-9), dashboard sync |
| 13 | Google Analytics (GA4) Integration | feature/google-analytics | 2026-04-04 | Firebase SDK, 20 events, consent flow, 17 tests |
| 14 | PM Skill v1.2 (Analytics Gate) | feature/google-analytics | 2026-04-04 | Pre-code spec, testing verification, post-merge regression |
| 15 | Figma Interactive Prototype (28 screens) | Figma file | 2026-04-04 | Full flows wired: onboarding, auth, tabs, training, nutrition, settings |
| 16 | GDPR Compliance (Account Deletion + Data Export) | feature/gdpr-compliance | 2026-04-04 | Articles 15/17/20, 30-day grace period, 9-store cascade, JSON export |
| 17 | Android Design System (Token Mapping) | main | 2026-04-04 | 92 iOS tokens → MD3, Style Dictionary config, component parity audit |
| 18 | Onboarding v2 UX Alignment (6 screens) | PR #59 | 2026-04-06 | First UX Foundations alignment pass, Figma v2, 13 principles validated |
| 19 | Home Today Screen v2 UX Alignment | PR #61 | 2026-04-09 | 723-line rewrite, 27 findings fixed, ReadinessCard hero, dual CTAs, 21 tests |
| 20 | Onboarding v2 Retroactive (v2/ subdirectory) | PR #63 | 2026-04-09 | 8 files moved to v2/ convention, validates multi-screen pattern |
| 21 | Status+Goal Merged Card (Body Composition) | PR #65 | 2026-04-09 | Unified card + drill-down with SwiftUI Charts, 3 analytics events |
| 22 | Metric Tile Deep Linking | PR #67 | 2026-04-09 | Tap HRV/RHR/Sleep/Steps → Stats filtered, 1 analytics event |
| 23 | Figma v2 Home Screen | Figma node 741:2 | 2026-04-09 | 7 sections using design system components + variables |
| 24 | Training Plan v2 UX Alignment | PR #74 | 2026-04-10 | 533-line container + 6 extracted views, 12 analytics events, 16 tests |
| 25 | Nutrition v2 UX Alignment | PR #75 | 2026-04-10 | 580-line container + ProgressBar component + 4 new DS tokens, 5 analytics events, 7 tests |
| 26 | Stats v2 UX Alignment | PR #76 | 2026-04-10 | AppLayout enum, chart accessibility, 4 analytics events, 6 tests |
| 27 | Settings v2 UX Alignment | PR #77 | 2026-04-10 | 8 color tokens fixed, a11y on destructive actions, 3 analytics events, 5 tests |
| 28 | Skills Ecosystem v4.1 | commit 32fe312 | 2026-04-10 | Reactive data mesh, 6 integration adapters, L1/L2/L3 learning cache, skill internal lifecycle |
| 29 | Skills Ecosystem v4.2 (health check + cache seeding) | commit 82f10a7 | 2026-04-10 | Phase 0 health check, 5 L1 + 5 L2/L3 cache entries seeded, 11 SKILL.md wired |
| 30 | PM Evolution Case Study (v1→v4.3) | repo state | 2026-04-11 | 751-line 3-level analysis extended through the v4.3 operational-layer promotion, with measurable efficiency data across 6 refactors |
| 31 | Readiness Score Formula v2 | commit 3852ef8 | 2026-04-10 | 5-component evidence-based formula, goal-aware, 4-layer personalization, 9 tests |
| 32 | AI Engine v2 (ReadinessResult integration) | commit 3f2151b | 2026-04-10 | AIOrchestrator consumes ReadinessResult, 8 new snapshot fields, recoveryBands + trainingBands |
| 33 | AI Recommendation UI | commit bde97c0 | 2026-04-10 | Brand icon as AI avatar, 4 new views, AIInsightCard on Home, AIIntelligenceSheet modal |
| 34 | Skills Ecosystem v4.3 (operations layer) | repo state | 2026-04-11 | Operations control room, case-study monitoring, and maintenance-program orchestration formalized on top of the self-healing hub |
| 35 | Framework Manifest (canonical source of truth) | repo state | 2026-04-11 | Added framework-manifest.json to centralize framework version, counts, structure, and source-of-truth metadata |
| 36 | External Sync Snapshot (Notion + Linear) | repo state | 2026-04-11 | Added external-sync-status.json and dashboard wiring so workspace drift is visible in source health and planning sync |
| 37 | Framework v5.0 SoC (skill-on-demand + cache compression) | commit 7288faa | 2026-04-14 | 54K tokens reclaimed (27% of context). Chip architecture principles applied to software framework. |
| 38 | Framework v5.1 SoC (complete 8/8 items) | commits | 2026-04-14 | Model tiering, batch dispatch, result forwarding, speculative preload, systolic chains, task complexity gate. 63% overhead reduction. |
| 39 | AI Engine Architecture Adaptation | PR #79 | 2026-04-15 | Input adapters, confidence gate, goal-aware intelligence (GoalProfile), learning cache, feedback UI. 17 files, 986 insertions. [Case study](../case-studies/ai-engine-architecture-v5.1-case-study.md) |
| 40 | Sentry Setup Guide + Health Wiring | commit 6a2843f | 2026-04-15 | Setup guide at docs/setup/sentry-setup-guide.md, error_tracking section in health-status.json |
| 41 | Funnel Definitions (6 funnels + templates) | commit 6a2843f | 2026-04-15 | Onboarding, training, nutrition, home engagement, AI recommendation, readiness funnels. GA4 setup checklist. |
| 42 | Supabase Consolidation | commit 873ac3d | 2026-04-15 | Consolidated to single project `hwbbdzwaismlajtfsbed` (FitmeBe&AI engine15042026). Tokyo region. Email+Google auth. All tables + RPC + storage. |
| 43 | Onboarding v2 Auth Flow | PR #80 + fixes | 2026-04-15 | 7-step onboarding with embedded auth, success animation, session restore fix, Figma PDF icon, pinned CTAs, skip-for-now. [Case study](../case-studies/onboarding-v2-auth-flow-v5.1-case-study.md) |
| 44 | Normalization Framework | commit 8a8db72 | 2026-04-15 | CU formula for cross-feature velocity comparison. Retroactive analysis of all 12 features. Power law fit R²=0.82. |
| 45 | Profile v3 Redesign | commits 8e71f12–c59b79d | 2026-04-15 | Simplified hybrid: hero (centered avatar, age/height/exp) + GoalsTrainingCard + AccountDataCard + AppearanceUnitsSheet. 5→4 tabs, profile via hamburger menu. Close button for a11y. Figma page "Profile & Settings" with all inner screens. |
| 46 | Home Screen Polish | commit dc80578–0d07913 | 2026-04-15 | Frosted glass removed, section dividers, HealthKit-aware body comp empty state, sample data (71.5 kg, 18.2%), AI avatar shimmer restored, profile icon replaces hamburger, sync indicator removed. |
| 47 | Dashboard Tab Navigation Fix | commit 28dffcb | 2026-04-15 | Client-side React tab nav (was broken in static Astro build). Case study links fixed. All 22 shared-layer conflicts resolved. |
| 48 | Full Documentation Sync | commits b6636cd–dddb3d3 | 2026-04-15 | Master plan 2026-04-15, README updates, dashboard + website READMEs, PRD v3.0, 2 missing case studies, Figma sync status doc, Prototype V2 page (22 screens). |
| 49 | External Sync (Linear + Notion) | 2026-04-15 | 2026-04-15 | Linear: 42→44 issues, FIT-41 done, FIT-43 created+done. Notion: Project Context updated, Roadmap updated. All sources healthy, 0 alerts, truth score 100. |

---

## In Progress

| # | Item | Owner | Branch | Status |
|---|------|-------|--------|--------|
| 6 | Authentication hardening | — | main | Real email auth, Google project wiring, compile verification, and password-reset UI are in place; end-to-end runtime validation remains the critical blocker before auth can be called production-ready |
| 21 | Maintenance cleanup program | — | main | Framework v4.3 promotion, source-of-truth reconciliation, control-room sync, and documentation cleanup are actively in progress |
| 22 | Operations control room | — | main | Live on fit-tracker2.vercel.app with shared-framework hydration, knowledge hub, GitHub/Notion/Linear/Vercel sync, and observability instrumentation |

---

## Planned (Roadmap Tasks — RICE Ordered)

| RICE | Task | Phase | Description |
|------|------|-------|-------------|
| 20.0 | Task 13: Metrics framework | 0 | 40 metrics defined ✅ |
| 20.0 | Task 6: Full backlog dump | 0 | This document ✅ |
| 16.0 | Task 17: Public README | 1 | Polished repo front door |
| 15.0 | Task 12+18: Unified PRD | 0 | Complete PRD ✅ |
| 8.0 | Task 4: Google Analytics | 2 | Firebase SDK, event taxonomy, funnels |
| 4.8 | Task 2: Android design system | 3 | Token mapping, MD3 equivalents |
| 4.3 | Task 1: Figma prototype | 1 | Interactive 22+ screen demo |
| 4.3 | Task 16: Marketing website | 5 | Comprehensive site with testimonials |
| 3.6 | Task 3: Android app research | 3 | Native vs framework, effort estimate |
| 3.2 | Task 14: Skills OS | 2 | API connections, review cycles, live dashboard |
| 3.2 | Task 15: CX system | 2 | Reviews, NPS, follow-up, public roadmap |
| 3.0 | Task 7: Notion integration | 0 | Backlog/roadmap management |
| 2.1 | Task 10: Health API connections | 3 | Garmin, Whoop, Oura, Samsung, Fitbit |
| 2.0 | Task 11: DEXA + body composition | 3 | Scan import, regional breakdown |
| 1.3 | Task 9: Blood test reader | 4 | OCR, regulatory research, encryption |
| 1.0 | Task 5: Skills feature (in-app) | 4 | Categories, progression, UI |

---

## Backlog (Unscheduled — from gap reviews and PRD)

### Critical (GDPR/Legal)
- [x] Account deletion (GDPR Article 17 — right to erasure) ✅ Shipped 2026-04-04
- [x] Data export (GDPR Article 20 — right to portability) ✅ Shipped 2026-04-04

### High Priority (Product Gaps)
- [x] AI recommendation UI — shipped 2026-04-10 (Home AIInsightCard + AIIntelligenceSheet) ✅
- [x] Food database search — OpenFoodFacts text search is wired in MealEntrySheet ✅
- [x] Barcode scanning — camera scanner is wired to OpenFoodFacts lookup in MealEntrySheet ✅
- [x] Auth runtime verification — Supabase consolidated to project `hwbbdzwaismlajtfsbed`, Google OAuth configured, email+Google auth providers enabled. Onboarding auth flow embedded (PR #80). Session restore fixed. Remaining: Apple Sign In (needs Services ID).
- [x] **Onboarding v2 Auth Flow** — SHIPPED 2026-04-15 (PR #80 + post-merge fixes). 7-step onboarding with embedded auth, success animation, session restore fix, Figma PDF icon, pinned CTAs, skip-for-now. Case study: `docs/case-studies/onboarding-v2-auth-flow-v5.1-case-study.md`
- [ ] **Smart Reminders System** — AI-powered local notification system with 5 reminder types: HealthKit connect, account registration, goal-gap nutrition (computes real-time macro gaps), training/rest day, engagement. Wired into AIOrchestrator + ReadinessEngine + GoalProfile for personalized, state-aware messaging. Locked feature overlays for guest users. Future sub-task: behavioral learning layer. ~5 days. Parent: onboarding-v2-auth-flow.
- [ ] Push notifications — research active in `.claude/features/push-notifications/` and Linear `FIT-23`
- [ ] App icon + App Store assets — research active in `.claude/features/app-store-assets/` and Linear `FIT-17`
- [x] Password reset flow — reset action is available from email login when Supabase runtime credentials are configured ✅
- [ ] **Import Training Plan from External Sources** — research active in `.claude/features/import-training-plan/` and Linear `FIT-24`. Allow users to bring existing training plans from other apps (Hevy, Strong, Fitbod, Jefit), spreadsheets (Google Sheets, Excel, Numbers), PDFs (coach programs, published programs like 531, PPL, nSuns), photos (gym whiteboard, handwritten plan), **or AI-generated plans from other assistants (ChatGPT, Claude, Gemini, Perplexity, custom GPTs, coach bots)**. Must parse exercises, sets, reps, rest periods, RPE targets, and program structure (day splits, phases, progression rules). Key challenge: map external exercise names to FitMe's 87-exercise library with a confirmation/mapping UI for ambiguous matches. Supports: (1) CSV/JSON import, (2) PDF text extraction (already have OCR for nutrition), (3) photo OCR for handwritten/printed plans, (4) direct app-to-app share extension, (5) paste-to-parse from chat/email, (6) **AI conversation paste** — user pastes a full ChatGPT/Claude conversation or just the training plan section, and the parser extracts the structured plan (handles markdown tables, numbered lists, prose descriptions, code blocks). Also supports importing the original **prompt** used to generate the plan so users can regenerate/iterate with FitMe's AI engine using their preferred structure. Mapping must be progressive — easy matches auto-accept, ambiguous ones prompt the user. Once imported, plan replaces or supplements the default 6-day PPL split. Feature work type with full 10-phase lifecycle (0-9) required.
- [x] **Onboarding flow** — shipped 2026-04-07 (v2 UX alignment per ux-foundations.md, 6 screens including Consent, full GA4 instrumentation, PR #59)

### High Priority (Architecture & Framework)

- [x] **v5.1 Adaptive Batch Execution** — IMPLEMENTED 2026-04-14. 8/8 SoC items shipped in skill-routing.json v4.1 + pm-workflow/SKILL.md: batch dispatch (TPU weight-stationary), model tiering (ANE mixed-precision), result forwarding (UMA zero-copy), speculative preload (branch prediction), systolic chains (TPU systolic array), task complexity gate (big.LITTLE hybrid). ~63% framework overhead reduction.
- [ ] **Sentry Error Tracking Integration** — No crash reporting wired. High priority before App Store launch. Sentry adapter at `.claude/integrations/sentry/` exists but no MCP connected. Unlocks real crash-free rate for `/ops health`, crash correlation for `/cx analyze`, and live data for Phase 0 health check `shared_layer_consistency`.
- [ ] **Funnel Analysis Dashboards** — GA4 event taxonomy is in place and `/analytics funnel` can define funnels, but no GA4 dashboards have been built. Blocks PRD kill criteria evaluation and Phase 9 (Learn) with real conversion data.
- [ ] **`/ops digest` — Stakeholder Updates** — Weekly project health summary aggregating health-status.json, cx-signals.json, metric-status.json, and change-log.json. Automates Phase 9 monitoring cadence instead of manual `/cx analyze` + `/analytics report`.

### High Priority (Architecture → AI Engine)
- [x] **AI Engine v2 — Adapt PM v4.0 Architecture for AIOrchestrator** — SHIPPED 2026-04-15 (PR #79). 4-phase implementation: input adapters, confidence gate + goal-aware intelligence, learning cache, feedback UI + analytics. 17 files, 986 insertions, 197 tests pass. Case study: `docs/case-studies/ai-engine-architecture-v5.1-case-study.md` — research active in `.claude/features/ai-engine-architecture-adaptation/` and Linear `FIT-25`. Study how the reactive data mesh (adapter layer → validation gate → shared layer → cache), pattern recognition (L1/L2/L3 learning cache), and cross-domain data flow architecture built for the PM skill ecosystem can enhance the in-app AI engine (AIOrchestrator). Investigate: (1) micro-analysis on-device (pattern recognition from local HealthKit/training/nutrition data using the same cache + validation principles), (2) macro-analysis via cloud (foundation model calls enriched by cached user patterns, similar to how skills use cached patterns to skip derivation), (3) adapter-style integration for health data sources (Garmin, Whoop, Oura → normalize → validate → feed AI), (4) validation gate concept for AI recommendations (confidence scoring before surfacing to user), (5) learning cache for AI — store what recommendations worked per user profile to improve over time. Goal: make the AI engine as data-driven and self-improving as the PM workflow.

### Medium Priority (UX Improvements)
- [ ] Chart goal target lines — weight/BF goals not overlaid on stats charts
- [ ] Chart tap-to-tooltip interaction — mentioned in v2 spec, unclear status
- [x] Readiness score formula — shipped as v2 weighted scoring on 2026-04-10 ✅
- [ ] Trend alerts — no notification when HRV drops below threshold for 3+ days
- [ ] Exercise search/filter — 87 exercises in fixed order, no search
- [ ] Training program customization — fixed 6-day PPL split (partially addressed by "Import Training Plan from External Sources" above)
- [ ] Notification settings — no push notification preferences in Settings
- [ ] Data export from Settings — no CSV/JSON export UI
- [ ] User feedback loop for AI — can't rate recommendation quality
- [ ] Dark Mode end-to-end testing — asset catalog has values but not verified
- [ ] Dynamic Type full compliance — @ScaledMetric not on all text tokens
- [ ] Code Connect (Figma ↔ code mapping)

### Low Priority (Nice-to-Have)
- [ ] Rep max calculator (1RM estimation UI)
- [ ] Supersets/circuits logging
- [ ] Custom exercise creation
- [ ] Meal timing analysis
- [ ] Photo-based food logging (Vision/ML)
- [ ] AI meal suggestions based on remaining macros
- [ ] Chart export/share (screenshot or CSV)
- [ ] Chart comparison mode (overlay two metrics)
- [ ] Apple Watch complication
- [ ] iOS home screen / lock screen widgets
- [ ] iPad/macOS optimized layouts
- [ ] No passcode fallback for biometric lock
- [ ] Phone OTP registration (deferred — `docs/design-system/deferred-phone-otp-task.md`)

### Design System Residual
- [ ] 9 raw literals remaining across views (responsive micro-adjustments)
- [ ] Android token output for Style Dictionary
- [ ] VoiceOver labels comprehensive audit
- [ ] Figma old frame cleanup

---

## Marketing & Product Marketing (Planned)

> High-level growth strategy. Each item will go through `/pm-workflow` when prioritized.

### SEO & Content Marketing
- [ ] Marketing website SEO optimization (Task 16 dependency — metadata, structured data, sitemap, OG tags)
- [ ] App landing pages with keyword targeting (fitness tracker, workout log, nutrition tracker)
- [ ] Blog/content hub for organic search (workout guides, nutrition tips, progress tracking articles)
- [ ] Link building strategy (fitness communities, app review sites, health blogs)

### Paid Acquisition — Google
- [ ] Google Ads campaigns (Search — branded + category keywords)
- [ ] Google Ads App campaigns (UAC — automated app install campaigns)
- [ ] Google Display Network (retargeting website visitors)
- [ ] YouTube pre-roll ads (short-form demo videos targeting fitness audiences)

### Paid Acquisition — Meta (Facebook + Instagram)
- [ ] Facebook App Install campaigns (lookalike audiences from existing users)
- [ ] Instagram Stories/Reels ads (visual workout tracking demos)
- [ ] Facebook audience segmentation (gym-goers, health-conscious, data-driven personas)
- [ ] Retargeting campaigns (website visitors, app abandoners)

### App Store Optimization (ASO) — Apple App Store
- [ ] App Store listing optimization (title, subtitle, keywords, description)
- [ ] Screenshot templates (6.7" + 6.5" + 12.9" iPad) showing key features
- [ ] App Preview video (15-30s demo of core workflow)
- [ ] App Store rating/review strategy (in-app review prompt timing)
- [ ] Apple Search Ads (basic + advanced) — keyword bidding for discovery
- [ ] App Store feature nomination (Self-Service → editorial pitch)

### App Store Optimization (ASO) — Google Play Store
- [ ] Play Store listing optimization (title, short description, full description, tags)
- [ ] Play Store screenshots + feature graphic
- [ ] Play Store pre-registration campaign (before Android launch)
- [ ] Google Play promotional content (LiveOps cards, offers)

### Product Marketing
- [ ] Product positioning & messaging framework (ICP definition, value propositions per persona)
- [ ] Competitive comparison pages (FitMe vs MyFitnessPal, Strong, Hevy, Strava)
- [ ] Feature launch announcements (in-app + email + social)
- [ ] User testimonials & case studies
- [ ] Referral program design (invite friends, earn premium features)
- [ ] Email marketing automation (onboarding drip, re-engagement, milestone celebrations)
- [ ] Social media presence (Instagram, Twitter/X, Reddit r/fitness)

### Analytics & Attribution
- [ ] UTM parameter strategy for all campaigns
- [ ] Firebase Dynamic Links for deep linking from campaigns
- [ ] Attribution tracking (which campaigns drive installs → active users → retained users)
- [ ] ROAS (Return on Ad Spend) dashboard per channel
- [ ] GA4 conversion events linked to marketing funnels (sign_up, tutorial_complete, workout_complete)

---

## Icebox (Deprioritized / Speculative)

- [ ] Wear OS app (wearable training UI)
- [ ] Web dashboard for coaches/trainers
- [ ] Social features (workout sharing, leaderboards)
- [ ] Meal photo recognition (AI-based food identification)
- [ ] Blood pressure tracking (HealthKit field available but not imported)
- [ ] Respiratory rate tracking
- [ ] Sleep stage analysis (deep/REM breakdown in stats)
- [ ] Multi-language support (String Catalog / .xcstrings)
- [ ] Offline conflict resolution UI (currently silent last-write-wins)

---

## Completed This Session (2026-04-02)

| Item | PR | Details |
|------|-----|---------|
| CI failure investigation | PR #17 | 5 compile errors: Supabase API, switch exhaustiveness, smart quotes, test brace |
| Supabase Realtime API migration | PR #17 | `RealtimeChannelV2` + `supabase.realtimeV2.channel()` |
| `@available(iOS 26, *)` fix | PR #17 | Reverted incorrect iOS 18.1 annotation |
| `__pycache__` cleanup | PR #17 | Removed from tracking, added to .gitignore |
| Hardcoded path fixes | PR #17 | All `/Users/regevbarak/` paths → relative |
| Simulator auto-login | PR #18 | `#if DEBUG && targetEnvironment(simulator)` bypass |
| LiveInfoStrip token fix | PR #18 | Raw font → `AppText.hero` |
| NutritionView cleanup | PR #18 | `RoundedRectangle(cornerRadius: 0)` → `Rectangle()`, documented 54pt indent |
| PR #14 closed | — | Superseded by PR #17 |
| PR #15 closed | — | Superseded by PR #17 |
| PR #16 closed | — | Superseded by PR #17 |
| 18-task RICE roadmap | PR #19 | Phase gates, RICE scores 1.0-20.0 |
| Unified PRD | This branch | ~620 lines, 11 features, business strategy |
| Metrics framework | This branch | 40 metrics, instrumentation status |
| This backlog | This branch | Complete compilation from all sources |
| 50 | Push Notifications | v5.2 stress test | 2026-04-16 | NotificationService + PreferencesStore + ContentBuilder + DeepLinkHandler + PermissionPrimingView. 12 tasks, 10 tests, review-approved. First full v5.2 lifecycle. |
| 51 | App Store Assets | v5.2 stress test | 2026-04-16 | Icon pipeline (xcassets + Makefile), screenshot guide, metadata, privacy policy, support page, submission checklist. 10 tasks. |
| 52 | Import Training Plan | v5.2 stress test | 2026-04-16 | ImportParser protocol (CSV + JSON + Markdown), ExerciseMapper (37 aliases), ImportOrchestrator, ImportSourcePickerView, ImportPreviewView. 13 tasks, 15 tests. |
| 53 | Smart Reminders | v5.2 stress test | 2026-04-16 | ReminderScheduler + ReminderType (6 types) + ReminderTriggerEvaluator (5 triggers) + LockedFeatureOverlay. 14 tasks, 10 tests. |
| 54 | Dispatch Intelligence v5.2 | framework | 2026-04-16 | dispatch-intelligence.json, skill-routing v5.0, framework-manifest v1.3, SKILL.md dispatch protocol. 3-stage pipeline: score → probe → dispatch. |
