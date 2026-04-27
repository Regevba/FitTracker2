# FitMe Master Plan — 2026-04-15

> **Status:** CURRENT · Last updated 2026-04-27 (v7.7 in progress — full-priority freeze)
> **Date opened:** 2026-04-15
> **Purpose:** Updated master plan reflecting all work since the 2026-04-06 edition. Supersedes `master-plan-2026-04-06.md`.
> **Context:** 28 additional items shipped through 2026-04-15, framework evolved v4.3 → v5.1, full external sync completed (Linear, Notion, Vercel), dashboard operational with zero alerts.
>
> **Post-2026-04-15 additions:** v5.1 → v5.2 dispatch intelligence + parallel write safety; v5.2 → v6.0 framework measurement; v6.0 → v7.0 HADF + full-system audit; M-1/M-2/M-3/M-4 decomposition sprints; case-study linkage rollout across all 40 feature directories; v7.0 → v7.1 Integrity Cycle (72h recurring state.json audit via GitHub Actions, baseline 40 features / 44 case studies / 0 findings).
>
> **Post-2026-04-21 additions (Gemini audit + v7.5 + v7.6):** 2026-04-21 Google Gemini 2.5 Pro independent audit triggered v7.5 → v7.6 framework rework. v7.5 (Data Integrity Framework, shipped 2026-04-24) introduced 8 cooperating defenses across write-time / 72h cycle / readout-time. v7.6 (Mechanical Enforcement, shipped 2026-04-25) added 4 write-time pre-commit check codes (`PHASE_TRANSITION_NO_LOG`, `PHASE_TRANSITION_NO_TIMING`, `BROKEN_PR_CITATION` write-time, `CASE_STUDY_MISSING_TIER_TAGS`), per-PR review bot (`pm-framework/pr-integrity` status check), weekly framework-status cron, and explicit Class B inventory of 5 mechanically-unclosable gaps. PR #141 (Codex pending fixes) merged 2026-04-26. Tier 3.3 public external-replication invitation filed as [GitHub issue #142](https://github.com/Regevba/FitTracker2/issues/142) (pinned). Developer guide (745 lines) published at [`docs/architecture/dev-guide-v1-to-v7-6.md`](../architecture/dev-guide-v1-to-v7-6.md) and mirrored at [/framework/dev-guide](https://fitme-story.vercel.app/framework/dev-guide). Full audit-response narrative on the trust page: https://fitme-story.vercel.app/trust/audits/2026-04-21-gemini.
>
> **Linear backfill (2026-04-26):** FIT-44 (v7.5), FIT-45 (v7.6, parent), FIT-46 (PR #141), FIT-47 (DEV guide), FIT-48 (Tier 3.3 #142). FIT-22 + FIT-6 marked Done in same pass.
> **Notion backfill (2026-04-26):** new sub-page under FitMe Product Hub: "Framework v7.5 + v7.6 — Audit Response (2026-04-21 → 2026-04-26)". Project Context & Status updated v5.1 → v7.6.
>
> **v7.7 Validity Closure (READY FOR MERGE as of 2026-04-27, single-session ship):** A 2026-04-27 ledger pull surfaced that v7.6's "Known Mechanical Limits" included three items still mechanically or heuristically closable. v7.7 closed them in one session: A1 (`cache_hits[]` writer-path, GitHub issue #140), A2 (`cu_v2` schema validator), A3 (doc-debt field gates + bulk backfill of 32 case studies), A4 (state↔case-study linkage 95.5% → 100%), A5 (active-feature timing backfill, 3 features), C1 (tier-tag heuristic checker, advisory permanent — kill criterion 2 fired at baseline as designed). B1 + B2 are time-gated and verify automatically post-merge (B1 ~2026-05-04, B2 ~2026-05-03 to -06). UCC T43–T54 absorbed as M4 — framework-health dashboard live at fitme-story `/control-room/framework` (PR #7). **Two PRs awaiting merge: FitTracker2 [#144](https://github.com/Regevba/FitTracker2/pull/144) + fitme-story [#7](https://github.com/Regevba/fitme-story/pull/7).** Total framework mechanisms post-merge: 25 gates + 1 advisory. Linear epic [FIT-49](https://linear.app/fitme-project/issue/FIT-49/v77-validity-closure-epic) + 8 sub-issues (FIT-50 … FIT-57). Notion v7.7 sub-page live. 6 features paused for the freeze: app-store-assets, auth-polish-v2, import-training-plan, onboarding-v2-retroactive, push-notifications, stats-v2 — resume on PR #144 merge. D1 (Tier 2.1 auth playbook) + D2 (Tier 3.3 external replication, [#142](https://github.com/Regevba/FitTracker2/issues/142)) surfaced as a human-action checklist on the dashboard. Spec/plan/synthesis: [`docs/superpowers/specs/2026-04-27-framework-v7-7-validity-closure-design.md`](../superpowers/specs/2026-04-27-framework-v7-7-validity-closure-design.md), [plan](../superpowers/plans/2026-04-27-framework-v7-7-validity-closure.md), [case study + Section 99 synthesis](../case-studies/framework-v7-7-validity-closure-case-study.md).

---

## Executive Summary

FitMe is a production-grade iOS fitness app with **49+ shipped features/improvements**, zero-knowledge encryption, GDPR compliance, GA4 analytics, a federated AI layer with goal-aware intelligence, and a mature PM framework (v5.1). The codebase scores **A-** on code quality with **197+ passing tests** including 29 eval tests.

**All 6 main screens** have been through UX Foundations alignment (v2 refactors), all Figma screens are built, and the development dashboard is live at `fit-tracker2.vercel.app` with zero alerts and 100% source truth score.

### What Changed Since 2026-04-06

| Category | 2026-04-06 | 2026-04-15 |
|---|---|---|
| Shipped items | 16 | 44 |
| Tests | 55 | 197+ (including 29 evals) |
| Framework | v4.3 | v6.0 (SoC suite, measurement instrumentation) |
| V2 screens | 1 (Onboarding) | 6/6 complete |
| Dashboard alerts | 22+ | 0 |
| Source truth score | ~70 | 100 |
| Linear issues | 25 | 42 (18 Done, 4 Canceled) |
| Notion pages | ~6 | 8 (0 drift) |
| Case studies | 2 | 7 (all with docs) |

### Key Deliverables (2026-04-06 → 2026-04-15)

- **6/6 v2 UX-aligned screens** — Home (#61), Training (#74), Nutrition (#75), Stats (#76), Settings (#77), Onboarding retroactive (#63)
- **AI Engine v2 + Architecture Adaptation** — Input adapters, confidence gate, GoalProfile, learning cache, feedback UI (PR #79)
- **Onboarding v2 Auth Flow** — 7-step embedded auth, success animation, session restore fix (PR #80)
- **Readiness Score v2** — 5-component evidence-based formula, goal-aware, 4-layer personalization
- **AI Recommendation UI** — Brand icon as AI avatar, AIInsightCard on Home, AIIntelligenceSheet modal
- **Framework v5.0 → v5.1** — SoC-on-Software: skill-on-demand, cache compression, batch dispatch, model tiering, result forwarding, speculative preload, systolic chains, task complexity gate
- **Supabase Consolidation** — Single canonical project (Tokyo region), email + Google auth
- **Normalization Framework** — CU formula for cross-feature velocity comparison
- **7 case studies** — All tracked, all with docs on disk
- **Full external sync** — Linear (42 issues), Notion (8 pages, 0 drift), Vercel dashboard live

---

## Current Verification Status

| Component | Status | Count |
|---|---|---|
| iOS Build | Green | Compiles clean |
| iOS Tests | Green | 197+ (Core + Sync + Eval) |
| Token Pipeline | Green | `make tokens-check` clean |
| Dashboard Build | Green | 2 pages, 35 tests |
| Marketing Website | Green | Builds clean |
| AI Engine | Green | 5/5 tests |
| Full Verification | Green | `make verify-local` |

### Runtime Verification (Still Blocked)
- Firebase analytics: needs local `GoogleService-Info.plist`
- Supabase runtime: needs real credentials in `Info.plist`
- Sentry crash reporting: needs MCP connection
- Apple Sign In: needs Apple Developer Services ID

---

## Phase Gates

### Gate A — Foundation Stability: CLOSED
All force unwraps eliminated, build green, sync schema corrected, auth/session fixed, AI tests green, dashboard tests fixed.

### Gate B — Truth Alignment: CLOSED
Docs match code, token pipeline verified, stale paths cleaned, all PRDs have state.json with metrics, features.json and feature-registry.json fully reconciled.

### Gate C — Measurement: PARTIALLY CLOSED
- GA4 instrumented (20 events, 6 funnels defined)
- Sentry setup guide written, health wiring done
- Firebase runtime blocked on `GoogleService-Info.plist`
- Crash-free rate, cold start, sync success rate: unmeasured

### Gate D — Platform Expansion: LOCKED
Requires Gate C + iOS core stable + backend green + measurement live.

---

## Feature Status Map

### Shipped (44 items)
| # | Feature | PR/Date | Key Metric |
|---|---------|---------|---|
| 1-10 | Core app (Training, Nutrition, Recovery, Home, Stats, Auth, Settings, Data Sync, AI/Cohort, Design System v2) | 2026-02 → 2026-04 | Foundation |
| 11 | PM Workflow Skill | PR #21 | 10-phase lifecycle |
| 12 | Google Analytics (GA4) | 2026-04-04 | 20 events, 17 tests |
| 13 | GDPR Compliance | 2026-04-04 | 100% deletion/export |
| 14 | Android Design System | 2026-04-04 | 92 tokens mapped |
| 15 | Development Dashboard | 2026-04-02 | Live at vercel.app |
| 16 | Marketing Website | 2026-04-04 | Built (launch blockers remain) |
| 17-18 | Onboarding v2 + Retroactive | PR #59, #63 | 6 screens, v2/ convention |
| 19 | Home Today v2 | PR #61 | 723 lines, 21 tests |
| 20 | Status+Goal Card | PR #65 | Body composition drill-down |
| 21 | Metric Tile Deep Linking | PR #67 | Tap → Stats filtered |
| 22-25 | Training v2, Nutrition v2, Stats v2, Settings v2 | PR #74-77 | 6/6 screens aligned |
| 26 | Readiness Score v2 | commit 3852ef8 | 5-component formula |
| 27 | AI Engine v2 | commit 3f2151b | ReadinessResult integration |
| 28 | AI Recommendation UI | commit bde97c0 | Brand icon avatar |
| 29-34 | Skills Ecosystem v4.1 → v4.3 | various | 11 skills, L1/L2/L3 cache |
| 35-36 | Framework v5.0 + v5.1 | commit 7288faa+ | 63% overhead reduction |
| 37 | AI Engine Architecture Adaptation | PR #79 | GoalProfile, learning cache |
| 38 | Onboarding v2 Auth Flow | PR #80 | 7-step embedded auth |
| 39-41 | Sentry Guide, Funnel Defs, Supabase Consolidation | 2026-04-15 | Infrastructure |
| 42 | Normalization Framework | commit 8a8db72 | CU formula, R²=0.82 |
| 43-44 | Dashboard bug fixes | 2026-04-15 | Tab nav, case study links |

### In Progress
| Feature | Phase | Next Step |
|---|---|---|
| User Profile Settings | Implementation (Layer 1: 4/13 tasks) | Layer 2-4 |
| Authentication hardening | Verification | Runtime credentials needed |
| Operations control room | Maintenance | Ongoing |

### Research / PRD Phase
| Feature | Phase | Linear |
|---|---|---|
| Push Notifications | PRD | FIT-23 |
| App Store Assets | PRD | FIT-17 |
| Import Training Plan | Research | FIT-24 |
| Smart Reminders System | Planned | FIT-42 |

### Planned (RICE-Prioritized)
| RICE | Feature | Phase | Dependency |
|---|---|---|---|
| 3.6 | Android App Research | Backlog | Gate D |
| 3.2 | Skills Operating System | Backlog | Gate C |
| 3.2 | CX System | Backlog | Gate C |
| 2.1 | Health API Connections | Backlog | Gate D |
| 2.0 | DEXA + Body Composition | Backlog | Gate D |
| 1.3 | Blood Test Reader | Backlog | Gate D |
| 1.0 | Skills Feature (In-App) | Backlog | Gate D |

---

## Framework Status: v6.0 (Framework Measurement)

**PM Workflow v5.1** with 8 SoC-on-Software optimizations:

| # | Optimization | Savings |
|---|---|---|
| 1 | Skill-on-Demand Loading | ~35K tokens/phase |
| 2 | Cache Compression | ~30.5K tokens |
| 3 | Template-Stationary Batch Audits | ~50% fewer reads |
| 4 | Result Forwarding (UMA zero-copy) | ~7.5K tokens/Phase 3 |
| 5 | Model Tiering (sonnet/opus) | 60% phases on cheaper model |
| 6 | Speculative Cache Pre-loading | ~7 reads eliminated/lifecycle |
| 7 | Skill Chain Pipeline Protocol | Up to 29K tokens/stage |
| 8 | Hybrid Task Dispatch (big.LITTLE) | ~2-3x throughput |

**Net: 63% framework overhead reduction. Free context doubled (78K → 155K tokens).**

---

## External Sync Status

| Source | Status | Details |
|---|---|---|
| Linear | Healthy (0 alerts) | 42 issues, 18 Done, project In Progress |
| Notion | Healthy (0 alerts) | 8 pages, 0 drift |
| Vercel | Healthy (0 alerts) | Dashboard live, Web Analytics + Speed Insights |
| GitHub | Healthy (0 alerts) | 44 shipped, main aligned with origin |
| Analytics | Healthy (0 alerts) | 40 metrics defined, 14 available, 6 funnels |

**Source truth score: 100. Aggregate alerts: 0.**

---

## Next Priorities

### Immediate (This Sprint)
1. **User Profile Settings** — Complete Layers 2-4 (9 remaining tasks)
2. **Smart Reminders System** — Define PRD, begin implementation (~5 days)
3. **Push Notifications PRD** — Advance from research to PRD approval

### Short-Term (Gate C Closure)
4. Supply `GoogleService-Info.plist` → verify Firebase analytics runtime
5. Connect Sentry MCP → establish crash-free rate baseline
6. Run auth runtime verification playbook with real Supabase credentials
7. Build GA4 funnel dashboards for the 6 defined funnels

### Medium-Term (Product Gap Closure)
8. App Store assets — icon, screenshots, preview video
9. Import Training Plan — research → PRD → implementation
10. Exercise search/filter UI
11. Chart goal target lines

### Long-Term (Gate D → Platform Expansion)
12. Android app research (RICE 3.6)
13. Health API connections — Garmin, Whoop, Oura (RICE 2.1)
14. DEXA + body composition import (RICE 2.0)

---

## Code Quality Summary

**Grade: A-**

| Category | Score | Notes |
|---|---|---|
| Architecture | A | Clean DI, actor-based encryption, adapter pattern |
| Security | A | AES-256-GCM + ChaCha20, Secure Enclave, GDPR |
| Force Unwraps | A | 0 in production code |
| Test Coverage | B+ | 232+ tests including 29 evals |
| Error Handling | B | ~47 silent `try?` calls need categorization |
| Accessibility | C | Limited `accessibilityLabel` coverage |
| Documentation | A | 25 PRDs, 7 case studies, full backlog |

---

## Normalized Velocity

Power law fit across 12 features: `Velocity(N) = 15.2 × N^(-0.68)`, R² = 0.82

| Version | Avg min/CU | Best Feature |
|---|---|---|
| v2.0 (baseline) | 15.2 | Onboarding v2 |
| v4.0 | 16.0 | (cache learning cost) |
| v4.1 | 7.9 | Nutrition v2 (5.1) |
| v5.1 | 3.6 | Onboarding Auth (2.1) |

**Current velocity: 3.6 min/CU average (+76% vs baseline).**
