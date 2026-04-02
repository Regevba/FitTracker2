# FitMe — Complete Backlog

> Compiled from: README, CHANGELOG, feature-memory, gap-review, resume-handoff, master plan, PRD gaps, session work.  
> Last updated: 2026-04-02

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

---

## In Progress

| # | Item | Owner | Branch | Status |
|---|------|-------|--------|--------|
| 1 | Phase 0 foundation docs (PRD, metrics, backlog) | Claude | `phase-0/foundation-docs` | Writing |
| 2 | Notion MCP integration | User | — | Needs OAuth setup in claude.ai/code Settings |

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
- [ ] Account deletion (GDPR Article 17 — right to erasure)
- [ ] Data export (GDPR Article 20 — right to portability)

### High Priority (Product Gaps)
- [ ] AI recommendation UI — signals exist but no dedicated surface for users
- [ ] Food database search — OpenFoodFacts stub exists, needs full integration
- [ ] Barcode scanning — camera capture exists, macro extraction not connected
- [ ] Google Sign In activation — mock provider exists, needs GoogleSignIn-iOS SDK
- [ ] Push notifications — no notification system (training reminders, readiness alerts)
- [ ] App icon + App Store assets — no 1024×1024 master icon, no screenshot templates
- [ ] Password reset flow — protocol exists, not wired in UI
- [ ] Onboarding flow — PRD defined (2.11), no code yet

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
