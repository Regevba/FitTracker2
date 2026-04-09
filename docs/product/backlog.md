# FitMe — Complete Backlog

> Compiled from: README, CHANGELOG, feature-memory, gap-review, resume-handoff, master plan, PRD gaps, session work.  
> Last updated: 2026-04-09

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
| 12 | PM Workflow Skill (/pm-workflow) | PR #21 | 2026-04-02 | 9-phase lifecycle, dashboard sync |
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

---

## In Progress

| # | Item | Owner | Branch | Status |
|---|------|-------|--------|--------|
| 1 | UX Foundations Screen Audits (research-only) | Claude | main | Training Plan, Nutrition, Stats, Settings — Phase 0 audits queued |
| 2 | Training Plan v2 UX Alignment | — | — | Next full Feature lifecycle after audits complete |

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
- [ ] AI recommendation UI — signals exist but no dedicated surface for users
- [ ] Food database search — OpenFoodFacts stub exists, needs full integration
- [ ] Barcode scanning — camera capture exists, macro extraction not connected
- [ ] Google Sign In activation — mock provider exists, needs GoogleSignIn-iOS SDK
- [ ] Push notifications — no notification system (training reminders, readiness alerts)
- [ ] App icon + App Store assets — no 1024×1024 master icon, no screenshot templates
- [ ] Password reset flow — protocol exists, not wired in UI
- [x] **Onboarding flow** — shipped 2026-04-07 (v2 UX alignment per ux-foundations.md, 6 screens including Consent, full GA4 instrumentation, PR #59)

### Medium Priority (UX Improvements)
- [ ] Chart goal target lines — weight/BF goals not overlaid on stats charts
- [ ] Chart tap-to-tooltip interaction — mentioned in v2 spec, unclear status
- [ ] Readiness score formula — currently binary (ready/not), needs weighted 0-100
- [ ] Trend alerts — no notification when HRV drops below threshold for 3+ days
- [ ] Exercise search/filter — 87 exercises in fixed order, no search
- [ ] Training program customization — fixed 6-day PPL split
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
