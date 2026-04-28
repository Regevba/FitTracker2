# FitMe — Complete Backlog

> Compiled from: README, CHANGELOG, feature-memory, gap-review, resume-handoff, master plan, PRD gaps, session work.  
> Last updated: 2026-04-28 (added: framework glossary + non-dev dev-process primer)

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
| 50 | HADF Hardware-Aware Dispatch | PR #82 | 2026-04-16 | 5-layer hardware-aware dispatch extension: device detection, static profiles (17 chips), cloud fingerprinting (7 signatures), dynamic adaptation, evolutionary learning. Confidence-gated (0.4/0.7), zero regression. Spec: `docs/superpowers/specs/2026-04-16-hadf-hardware-aware-dispatch-design.md` |
| 51 | v6.0 Framework Measurement | PR #81 | 2026-04-16 | Deterministic instrumentation: phase timing, cache-hit tracking, eval coverage gates, CU v2 continuous factors. 7/9 DVs measured. Meta-analysis folder `docs/case-studies/meta-analysis/`. |
| 52 | Push Notifications (v5.2 lifecycle) | v5.2 stress test | 2026-04-16 | NotificationService + PreferencesStore + ContentBuilder + DeepLinkHandler + PermissionPrimingView. 12 tasks, 10 tests, review-approved. **First full v5.2 lifecycle.** Further implementation paused under v7.7 freeze. |
| 53 | App Store Assets (v5.2 lifecycle) | v5.2 stress test | 2026-04-16 | Icon pipeline (xcassets + Makefile), screenshot guide, metadata, privacy policy, support page, submission checklist. 10 tasks. Further implementation paused under v7.7 freeze. |
| 54 | Import Training Plan (v5.2 lifecycle) | v5.2 stress test | 2026-04-16 | ImportParser protocol (CSV + JSON + Markdown), ExerciseMapper (37 aliases), ImportOrchestrator, ImportSourcePickerView, ImportPreviewView. 13 tasks, 15 tests. Further implementation paused under v7.7 freeze. |
| 55 | Smart Reminders | v5.2 stress test | 2026-04-16 | ReminderScheduler + ReminderType (6 types) + ReminderTriggerEvaluator (5 triggers) + LockedFeatureOverlay. 14 tasks, 10 tests. |
| 56 | Dispatch Intelligence v5.2 | framework | 2026-04-16 | dispatch-intelligence.json, skill-routing v5.0, framework-manifest v1.3, SKILL.md dispatch protocol. 3-stage pipeline: score → probe → dispatch. |
| 57 | Audit v2 Stress Test (Wave-2) | framework | 2026-04-18 | F1-F7 framework findings documented. F1 worktree perm gap aborted Wave 1; serial dispatch confirmed as working pattern until upstream fixes for F6-F9. |
| 58 | M-3 Design System Completion + Dark Mode | PRs #118-#121 | 2026-04-19 | DS-004 + DS-009 + DS-010. Token pipeline 60% → 100%. Dark-mode 29 → 38 of 41 colorsets. First feature with concurrent case study tracking. Audit total 180/185 (97.3%). |
| 59 | M-1 SettingsView Decomposition | PRs #122-#125 | 2026-04-19 | UI-002. SettingsView.swift 1170 → 294 lines (~75%). 8 new files (5 Screens/ + 3 Components/). Audit total 181/185 (97.8%). |
| 60 | M-2 MealEntrySheet Decomposition | PRs #126-#130 | 2026-04-19 | UI-004. MealEntrySheet.swift 1104 → 140 lines (~87%). 9 new files. 17 @State vars → 0. Audit total 182/185 (98.4%). Surfaced "stacked PR misfire" methodology lesson. |
| 61 | Audit Path A (BE/DEEP-AUTH/DEEP-SYNC) | PRs #106-#108 | 2026-04-19 | BE-016/021/029, DEEP-AUTH-011, BE-023, DEEP-SYNC-014 closed. BE-024 (Edge Function) + DEEP-SYNC-010 (CK→Supabase image bridge) deferred — genuine external/multi-PR blockers. |
| 62 | Post-Stress-Test Audit Remediation | PR #117 | 2026-04-19 | 412-line synthesis covering 21 PRs (#96-#116), 50 audit findings closed (127 → 177 of 185), 9 framework bugs F1-F9 documented, F2/F3/F4 contracts validated 10/10. |
| 63 | M-4 XCUITest Infra | PRs #131-#133 | 2026-04-20 | TEST-025. New FitTrackerUITests target + 6 test files. 2 passing, 3 graceful skip, 0 failing. Audit total 183/185 (98.9%) — **100% in-project closure**. Attempt 1 aborted on XCTWaiter bug; recovered via plan addendum + retry. |
| 64 | Audit Remediation Program (185 findings) | program-level | 2026-04-20 | Top-level synthesis covering 6 sprints (post-stress-test + M-3 + M-1 + M-2 + M-4 + Path A). 183/185 closed in-project (98.9%) + 2 external-blocker deferrals = 100% accounted. |
| 65 | Framework v7.1 Integrity Cycle | framework | 2026-04-21 | 72h recurring state.json audit via GitHub Actions. First framework capability whose trigger is wall-clock elapsed. Baseline 40/45/0. |
| 66 | Gemini 2.5 Pro Independent Audit | external | 2026-04-21 | First external audit. 7/9 Tier 1/2/3 items shipped. Source trigger for v7.5/v7.6/v7.7 framework bumps. T1/T2/T3 data-quality tier convention introduced. |
| 67 | Framework Story Site (fitme-story.vercel.app) | external repo | 2026-04-21 | 53+ commits, 39 routes, Lighthouse 95+/100/100/100. GA4 wired (`@next/third-parties` + `NEXT_PUBLIC_GA_ID=G-XE4E1JGWRZ`). 3 flagship visuals + DispatchReplay live-demo with 2 traces. |
| 68 | Showcase Repo (fitme-showcase) | external repo | 2026-04-21 | 5-act, **24 case studies** (13 timeline + 11 deep-dives through #24). Zero unlinked features in main repo state.json. Different repo from fitme-story. |
| 69 | UI-Audit Baseline Burndown | PR #139 | 2026-04-24 | UI-audit hard gate live in main. 27 P0 baseline → 0. Direct merge of orphan-cleanup branch (e892ce3). State.json retroactively closed 2026-04-27 per v7.6 schema. |
| 70 | Data Integrity Framework v7.5 | framework | 2026-04-24 | v7.1 → v7.5 bump. 8 cooperating defenses (write-time + cycle-time + readout-time) from Gemini audit. 7/9 tiers fully or effectively shipped. Case study `data-integrity-framework-v7.5-case-study.md`. |
| 71 | Framework Mechanical Enforcement v7.6 | PR #141 | 2026-04-25 | 7 Class B → A promotions; 5 documented Class B gaps. Per-PR review bot, weekly framework-status cron, append-only adoption history. DEV guide live at fitme-story `/framework/dev-guide`; case study at `/case-studies/mechanical-enforcement-v7-6`. |
| 72 | PM Artifacts Audit (full sync) | sync | 2026-04-26 | Linear (5 backfill FIT-44/45/46/47/48 + FIT-22/FIT-6 Done) + Notion (v7.5+v7.6 sub-page + Project Context & Status v5.1→v7.6) synced live via MCP. 19 PRDs remediated for rule #2 + readiness-score-v2.md created. |
| 73 | Post-v6 Measurement Backfill | commit a0deb3a | 2026-04-27 | Lifted 1/9 → 2/9 fully-adopted post-v6. 3 zero-adopted features intentionally left untouched (no source data; impartiality rule). `cache_hits` Class B gap unchanged. |
| 74 | Framework v7.7 Validity Closure | shipped | 2026-04-28 | Closes A1-A5+B1-B2+C1 from post-v7.6 gap inventory. 5 new gates: 4 write-time pre-commit hooks (`CACHE_HITS_EMPTY_POST_V6`, `CU_V2_INVALID`, `STATE_NO_CASE_STUDY_LINK`, `CASE_STUDY_MISSING_FIELDS`) + 1 cycle-time check + 1 advisory (`TIER_TAG_LIKELY_INCORRECT`). Framework reaches **25 mechanical gates + 1 advisory**. state↔case-study linkage 95.5% → 100%. Pause on 6 dependent features lifted. |

---

## In Progress

| Item | Phase | Notes |
|------|-------|-------|
| Unified Control Center | implementation | Astro→Next.js `/control-room/*` in fitme-story. T1-T17 done; T18+ blocked on T2 baseline. T43-T54 framework-health enhancement designed (spec 5f1775f). |
| Auth runtime polish v2 (resumed post-v7.7) | implementation | Phase 3 UX research/spec/build prompt delivered. E2E runtime validation pending. Branch `feature/auth-polish-v2`. |
| Push notifications (resumed post-v7.7) | implementation | Linear FIT-23. Pause lifted 2026-04-28. |
| App Store assets (resumed post-v7.7) | implementation | Linear FIT-17. Pause lifted 2026-04-28. |
| Import training plan (resumed post-v7.7) | implementation | Linear FIT-24. Pause lifted 2026-04-28. |
| Onboarding v2 retroactive (resumed post-v7.7) | tasks | v2/ subdirectory convention validation pilot. Pause lifted 2026-04-28. |
| Stats v2 (resumed post-v7.7) | tasks | Pause lifted 2026-04-28. |
| Case-study presentation refactor (NEW 2026-04-28) | enhancement / **design locked** | **Alternative A locked 2026-04-28.** Component order: SummaryCard → DataKey → KeyNumbersChart (visual aid, **required**) → KillCriterionBanner → DeferredItemsList → narrative. New project rule: every case study must include at least one visual aid (graph or indicator). Default = `<KeyNumbersChart />` (auto from frontmatter); `visual_aid:` frontmatter field overrides with named component. Branch `feature/case-study-presentation` (FitTracker2). Preview: fitme-story `preview/case-study-presentation`. Production rollout pending /pm-workflow Tasks. |

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
- [x] **Smart Reminders System** — SHIPPED 2026-04-16 (item #55). ReminderScheduler + ReminderType (6 types) + ReminderTriggerEvaluator (5 triggers) + LockedFeatureOverlay. 14 tasks, 10 tests.
- [ ] Push notifications — implementation in progress (resumed post-v7.7), Linear `FIT-23`. State at `.claude/features/push-notifications/`.
- [ ] App icon + App Store assets — implementation in progress (resumed post-v7.7), Linear `FIT-17`. State at `.claude/features/app-store-assets/`.
- [x] Password reset flow — reset action is available from email login when Supabase runtime credentials are configured ✅
- [ ] **Import Training Plan from External Sources** — implementation in progress (resumed post-v7.7), Linear `FIT-24`. Allow users to bring existing training plans from other apps (Hevy, Strong, Fitbod, Jefit), spreadsheets (Google Sheets, Excel, Numbers), PDFs (coach programs, published programs like 531, PPL, nSuns), photos (gym whiteboard, handwritten plan), **or AI-generated plans from other assistants (ChatGPT, Claude, Gemini, Perplexity, custom GPTs, coach bots)**. Must parse exercises, sets, reps, rest periods, RPE targets, and program structure (day splits, phases, progression rules). Key challenge: map external exercise names to FitMe's 87-exercise library with a confirmation/mapping UI for ambiguous matches. Supports: (1) CSV/JSON import, (2) PDF text extraction (already have OCR for nutrition), (3) photo OCR for handwritten/printed plans, (4) direct app-to-app share extension, (5) paste-to-parse from chat/email, (6) **AI conversation paste** — user pastes a full ChatGPT/Claude conversation or just the training plan section, and the parser extracts the structured plan (handles markdown tables, numbered lists, prose descriptions, code blocks). Also supports importing the original **prompt** used to generate the plan so users can regenerate/iterate with FitMe's AI engine using their preferred structure. Mapping must be progressive — easy matches auto-accept, ambiguous ones prompt the user. Once imported, plan replaces or supplements the default 6-day PPL split. Feature work type with full 10-phase lifecycle (0-9) required.
- [x] **Onboarding flow** — shipped 2026-04-07 (v2 UX alignment per ux-foundations.md, 6 screens including Consent, full GA4 instrumentation, PR #59)

### High Priority (Architecture & Framework)

- [x] **v5.1 Adaptive Batch Execution** — IMPLEMENTED 2026-04-14. 8/8 SoC items shipped in skill-routing.json v4.1 + pm-workflow/SKILL.md: batch dispatch (TPU weight-stationary), model tiering (ANE mixed-precision), result forwarding (UMA zero-copy), speculative preload (branch prediction), systolic chains (TPU systolic array), task complexity gate (big.LITTLE hybrid). ~63% framework overhead reduction.
- [x] **HADF Hardware-Aware Dispatch** (PR #82, 2026-04-16) — 5-layer hardware-aware dispatch extension: device detection, static profiles (17 chips), cloud fingerprinting (7 signatures), dynamic adaptation, evolutionary learning. Confidence-gated (0.4/0.7), zero regression. Spec: `docs/superpowers/specs/2026-04-16-hadf-hardware-aware-dispatch-design.md`
- [ ] **Sentry Error Tracking Integration** — No crash reporting wired. High priority before App Store launch. Sentry adapter at `.claude/integrations/sentry/` exists but no MCP connected. Unlocks real crash-free rate for `/ops health`, crash correlation for `/cx analyze`, and live data for Phase 0 health check `shared_layer_consistency`.
- [ ] **Funnel Analysis Dashboards** — GA4 event taxonomy is in place and `/analytics funnel` can define funnels, but no GA4 dashboards have been built. Blocks PRD kill criteria evaluation and Phase 9 (Learn) with real conversion data.
- [ ] **`/ops digest` — Stakeholder Updates** — Weekly project health summary aggregating health-status.json, cx-signals.json, metric-status.json, and change-log.json. Automates Phase 9 monitoring cadence instead of manual `/cx analyze` + `/analytics report`.
- [ ] **Refine case-study presentation/readability (added 2026-04-28)** — The case-study corpus is 47+ documents and growing. Latest entries (v7.5, v7.6, v7.7) trend toward dense, multi-section, paragraph-heavy formats with deeply-nested headings (Section 99.1 through 99.8 in v7.7). The CONTENT is solid but the PRESENTATION is dense. Goals: (1) standardize a top-of-document summary card that reads in <60s and captures version + outcome + 3 key numbers + 2 honest disclosures; (2) extract a cross-case-study comparison table (every case study at a glance — version, work_type, wall_time, CU, primary_outcome — auto-generated from frontmatter); (3) consolidate the dual outlet (FitTracker2 long-form + fitme-story slot MDX) into a clear short/long pattern with a one-paragraph diff between the two; (4) introduce visual hierarchy markers (callout boxes for outlier-flag, kill-criterion-fired, deferred-items) so readers can skim by skimming structure not text; (5) audit the v2.0–v7.0 timeline studies for the same readability standard (currently they're inconsistent). NOT a content rewrite — purely a presentation/readability refactor. Coordinate with `/design` skill for the visual-hierarchy markers in the fitme-story rendering layer.
- [ ] **Framework glossary + non-dev "how the dev process works" primer (added 2026-04-28)** — There is currently no single glossary covering the vocabulary the framework has accumulated across v1.0 → v7.7 (e.g. `current_phase`, `cu_v2`, T1/T2/T3 tiers, Class A/B/C gates, write-time vs cycle-time vs readout-time, dispatch intelligence, systolic chain, big.LITTLE hybrid, integrity check codes like `SCHEMA_DRIFT` / `PR_NUMBER_UNRESOLVED` / `CACHE_HITS_EMPTY_POST_V6`, the 8 cooperating defenses, "25 gates + 1 advisory", DV measurement, CU formula, etc.). New readers — both human and agent — currently have to derive these from CLAUDE.md + scattered case studies + framework specs. Two deliverables in one task: (1) **Framework glossary** at `docs/glossary.md` (or `docs/framework/glossary.md`) — alphabetical, term + 1-line plain definition + canonical link to the doc that defines it. Each entry tagged with the framework version it was introduced in, and which mechanism it belongs to (gate / cache / dispatch / measurement / data-quality). Auto-extractable from CLAUDE.md, `framework-manifest.json`, and the case-study series. (2) **Non-dev dev-process primer** at `docs/glossary-dev-basics.md` — clear, plain-English working definitions for non-developers who want to follow what's happening when the framework runs `git`/CI/PR operations. Cover at minimum: `commit`, `push`, `pull`, `branch`, `merge`, `PR (pull request)`, `CI (continuous integration)`, `worktree`, `rebase`, `grep`, `echo`, `make`, `xcodebuild`, `pre-commit hook`, plus a one-paragraph "how a feature gets from `state.json: phase=tasks` to `Done` in the table above" walkthrough. Audience is the non-dev reader (e.g. PMs, stakeholders, students learning the workflow). NOT a tutorial on becoming a developer — purely working definitions sufficient to read along. Both files cross-link from `docs/skills/README.md` and the fitme-story site so external readers land on them naturally. Maintenance contract: glossary entries are added in the same PR that introduces the term (similar to how new tokens require a `tokens.json` + `.colorset` + `DesignTokens.swift` co-commit) — codify in CLAUDE.md once shipped.

### High Priority (Architecture → AI Engine)
- [x] **AI Engine v2 — Adapt PM v4.0 Architecture for AIOrchestrator** — SHIPPED 2026-04-15 (PR #79). 4-phase implementation: input adapters, confidence gate + goal-aware intelligence, learning cache, feedback UI + analytics. 17 files, 986 insertions, 197 tests pass. Case study: `docs/case-studies/ai-engine-architecture-v5.1-case-study.md` — research active in `.claude/features/ai-engine-architecture-adaptation/` and Linear `FIT-25`. Study how the reactive data mesh (adapter layer → validation gate → shared layer → cache), pattern recognition (L1/L2/L3 learning cache), and cross-domain data flow architecture built for the PM skill ecosystem can enhance the in-app AI engine (AIOrchestrator). Investigate: (1) micro-analysis on-device (pattern recognition from local HealthKit/training/nutrition data using the same cache + validation principles), (2) macro-analysis via cloud (foundation model calls enriched by cached user patterns, similar to how skills use cached patterns to skip derivation), (3) adapter-style integration for health data sources (Garmin, Whoop, Oura → normalize → validate → feed AI), (4) validation gate concept for AI recommendations (confidence scoring before surfacing to user), (5) learning cache for AI — store what recommendations worked per user profile to improve over time. Goal: make the AI engine as data-driven and self-improving as the PM workflow.

### Medium Priority (UX Improvements)
- [ ] Chart goal target lines — weight/BF goals not overlaid on stats charts
- [ ] Chart tap-to-tooltip interaction — mentioned in v2 spec, unclear status
- [x] Readiness score formula — shipped as v2 weighted scoring on 2026-04-10 ✅
- [ ] Trend alerts — no notification when HRV drops below threshold for 3+ days
- [ ] Exercise search/filter — 87 exercises in fixed order, no search
- [ ] Training program customization — fixed 6-day PPL split (partially addressed by "Import Training Plan from External Sources" above)
- [ ] Notification settings — backend `NotificationPreferencesStore` exists but no user-facing Settings screen to edit preferences
- [ ] Data export from Settings — JSON export UI exists (`ExportDataView`); CSV format not yet implemented
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

<!-- 2026-04-02 session log removed during 2026-04-28 refresh; entries already represented in main Done table (items 7-10) and v5.2 stress-test rows (items 52-56). -->

