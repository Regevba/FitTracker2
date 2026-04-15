# Session Summary — 2026-04-15

> **Duration:** ~6 hours (extended session)
> **Framework Version:** v5.1
> **Commits:** 20+ commits to main
> **PRs:** #79 (AI Engine Arch), #80 (Onboarding Auth Flow)

---

## What Shipped This Session

### 1. Architecture Framework Tasks
- **v5.1 Adaptive Batch** — confirmed IMPLEMENTED (was stale "design approved" in memory)
- **AI Engine Architecture Adaptation** (PR #79) — full PM lifecycle: research → PRD → tasks → implement → merge. 13 tasks, 17 files, 986 insertions. GoalProfile, ValidatedRecommendation, RecommendationMemory, AIInputAdapter protocol, 4 concrete adapters.
- **Sentry Setup Guide** — `docs/setup/sentry-setup-guide.md` + health-status.json wiring
- **Funnel Definitions** — 6 funnels + dashboard templates for shipped features
- **Architecture One-Pager** — `docs/skills/architecture-one-pager.md`
- **Normalization Framework** — CU formula for cross-feature velocity comparison, retroactive analysis of 12 features

### 2. Onboarding v2 Auth Flow (PR #80 + post-merge fixes)
- 7-step onboarding: Welcome → Goals → Profile → HealthKit → Consent → Auth/Skip → First Action → Home
- Session restore freeze fixed (detached task + 5s timeout)
- AuthHubView removed from rootView
- Figma PDF icon asset (replaces SwiftUI approximation)
- Blue gradient bg + orange template icon on Welcome
- Pinned CTAs on all onboarding screens
- Email verification inline (was navigating to removed view)
- "Skip for now" guest mode
- HomeEmptyStateView removed from flow
- Tab navigation freeze fixed (restoreSession only runs once)

### 3. Supabase Consolidation
- Consolidated to single project `hwbbdzwaismlajtfsbed` (FitmeBe&AI engine15042026)
- Tables: cohort_stats, sync_records, cardio_assets, user_profiles
- RPC: increment_cohort_frequency
- Storage: cardio-images bucket
- Auth: Email + Google enabled
- Region: Tokyo (migration to Ireland deferred)

### 4. Documentation Sync
- All skills docs cross-linked (pm-workflow, README, agent README, architecture, evolution)
- Architecture.md bumped to v5.1 with §12-16 (SoC deep-dives, AI engine cross-domain, timeline with case studies)
- Evolution.md updated with consolidated timeline + cumulative metrics
- Backlog updated with 44 shipped items

### 5. Case Studies
- AI Engine Architecture v5.1 — CU 17.7, min/CU 5.1 (+66% vs baseline)
- Onboarding Auth Flow v5.1 — CU 47.7, min/CU 2.1 (+86% vs baseline, best ever)

---

## Open Work Snapshot (as of end of session)

### Active (need implementation)

| # | Item | Phase | Est. | Priority |
|---|---|---|---|---|
| 1 | User Profile Settings (5th tab) | Implementation pending | 3-4d | High |
| 2 | Smart Reminders System | Planned (spec in memory) | 5d | High |
| 3 | Home Status+Goal Card | Implementation pending | 2d | High |

### Pending Research / PRD

| # | Item | Phase | Est. | Priority |
|---|---|---|---|---|
| 4 | Push Notifications | PRD pending | 3-5d | High |
| 5 | App Store Assets | PRD pending | 5-7d | High (launch) |
| 6 | Import Training Plan | Research pending | 10-15d | High |

### Infrastructure (pre-launch)

| # | Item | Status | Priority |
|---|---|---|---|
| 7 | Sentry Error Tracking | Guide done, needs account | High |
| 8 | Funnel Dashboards | Funnels defined, needs GA4 | High |
| 9 | Apple Sign In | Needs Apple Dev Services ID | Medium |
| 10 | Supabase region migration | Deferred | Low |
| 11 | Face ID registration | Backlogged | Low |
| 12 | `/ops digest` | Not started | Medium |

### UX Polish (deferred)

| # | Item | Priority |
|---|---|---|
| 13 | Dark Mode e2e testing | Medium |
| 14 | Dynamic Type full compliance | Medium |
| 15 | Exercise search/filter | Medium |
| 16-18 | Chart improvements, trend alerts | Low |

---

## Key Decisions Made

1. **Supabase canonical project:** `hwbbdzwaismlajtfsbed` (Tokyo region, will migrate to Ireland pre-launch)
2. **Auth in onboarding:** Embedded at step 5, not post-onboarding. Follows Duolingo/Headspace pattern.
3. **Guest mode allowed:** Users can skip auth and enter the app. Locked features + reminders will nudge registration.
4. **App icon:** Figma-exported PDF used everywhere. Template mode (orange gradient) on Welcome screen.
5. **Welcome screen:** Blue gradient bg (not orange). Icon visible as orange silhouette.
6. **CTA pinning:** All onboarding screens use VStack + pinned bottom pattern.
7. **Session restore:** Runs once at launch only (not on every .active phase).
8. **HomeEmptyStateView:** Removed from flow — confused with onboarding.
9. **Normalization framework:** CU formula mandatory in all future case studies.
10. **Smart Reminders:** AI-powered, goal-gap-aware, wired to AIOrchestrator + ReadinessEngine. AI avatar is the notification voice.

---

## Normalized Performance (cumulative)

| FW Version | Avg min/CU | vs v2.0 Baseline |
|---|---|---|
| v2.0 | 15.2 | Baseline |
| v4.0 | 16.0 | -5% |
| v4.1 | 7.9 | +48% |
| v4.2 | 10.4 | +32% |
| v4.4 | 7.1 | +53% |
| **v5.1** | **3.6** | **+76%** |

Power law: `T = 15.2 × N^(-0.68)`, R² = 0.82
