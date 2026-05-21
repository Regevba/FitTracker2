# FitMe Master Plan — 2026-04-15

> **Status:** CURRENT · Last updated 2026-05-21 (**v7.9 PROMOTION SHIPPED** via PR #417 `ea53ff4` — 3 advisory gates → enforced via single-flag flip; Phase E validation 2026-05-21 → 2026-06-04; v7.8.6 cadence batch shipped 2026-05-15; v7.8.5 observability layer shipped 2026-05-13)

> **v7.9 Promotion Release (SHIPPED 2026-05-21):** B1 freeze-day checklist GREEN. Single-line flip at [`scripts/check-state-schema.py:132`](../../scripts/check-state-schema.py) (`BRANCH_ISOLATION_ADVISORY_MODE = True → False`) drives all 3 promoted gates simultaneously: `BRANCH_ISOLATION_VIOLATION` Mode B (infra commit-level) + Mode C (per-state.json mutation) + `FEATURE_CLOSURE_COMPLETENESS` (write-time). All 4 §2.2 promotion criteria met against 14d Mechanism A telemetry (18 + 13 + 13 firings, 0 zero-candidate rows). **First real-world Mode C gate fire caught + resolved same-session** (close-out commit triggered Mode C on the merged-dead `feature/v7-9-promotion` branch declaration; resolved via 1-line `state.json::branch` field update). Total framework mechanisms post-promotion: **37 mechanical gates + 5 advisories** (3 promoted from advisory). 5 PRs landed today: [#413](https://github.com/Regevba/FitTracker2/pull/413) (`e05eb32`) UCC Phase 8 docs + [#415](https://github.com/Regevba/FitTracker2/pull/415) (`424963f`) ucc-sign-in reconcile + [#416](https://github.com/Regevba/FitTracker2/pull/416) (`0178a9c`) fitme-story discoverability + [#417](https://github.com/Regevba/FitTracker2/pull/417) (`ea53ff4`) **v7.9 promotion** + [#419](https://github.com/Regevba/FitTracker2/pull/419) (`9bfb7bb`) post-merge close-out. Sentry integration paused 2026-05-21 → pre-launch trigger (operator decision; iOS app is TestFlight beta only) — [PR #418](https://github.com/Regevba/FitTracker2/pull/418) documents the backlog update. Linear FIT-72 In Progress + 9 sub-issues updated (5 Done, 2 Canceled, 2 In Progress). Honesty ledger entry FT2-FH-003 codifies the calibration-discipline pattern (publish verbatim, then remediate). Phase E validation soak runs 2026-05-21 → 2026-06-04; B2 post-v7.9 baseline snapshot 2026-05-28. **Reversibility runbook**: single-line revert <5 min per [`.claude/entrypoints/framework-v7-9.md`](../../.claude/entrypoints/framework-v7-9.md). Source case study: [`../case-studies/framework-v7-9-promotion-case-study.md`](../case-studies/framework-v7-9-promotion-case-study.md). v7.9 cold-start entrypoint: [`.claude/entrypoints/framework-v7-9.md`](../../.claude/entrypoints/framework-v7-9.md). Infra master plan §3.6.2 + §10: [`infra-master-plan-2026-05-12.md`](infra-master-plan-2026-05-12.md).
>
> **v7.8.6 Cadence Batch (SHIPPED 2026-05-15):** Cadence-batch observability surfaces closing the 96-hour drift window between weekly framework-status cron and the 72-hour integrity cycle. MUST-have additions: `make integrity-diff` (vs 2026-05-14 anchor), `make preflight WORK_TYPE=<type>` (unified per-work-type entry point writing `.claude/shared/preflight-cache.json` consumed by all 10 skills), W1 ssh-agent SessionStart preflight, weekly Mechanism A gate-coverage zero-drift scan + per-dimension trend nudge. Nice-to-have additions: weekly dependency audit + daily stale-branch + PR-babysit. No new enforcement gates. Total framework mechanisms unchanged from v7.8.5: **34 mechanical gates + 5 advisories**. Shipped via [FT2 PR #363](https://github.com/Regevba/FitTracker2/pull/363) (MUST batch) + [FT2 PR #365](https://github.com/Regevba/FitTracker2/pull/365) (nice-to-have batch) + [FT2 PR #366](https://github.com/Regevba/FitTracker2/pull/366) (doc reconciliation) + companion fitme-story [PR #112](https://github.com/Regevba/fitme-story/pull/112).
>
> **v7.8.5 Observability Layer (SHIPPED 2026-05-13):** Operator-facing observability — both documentation + a hook. (1) Observed Patterns Catalog at [`.claude/integrity/observed-patterns.md`](../../.claude/integrity/observed-patterns.md) — canonical 23-gate + 9-workflow pattern manifest, auto-loaded as preflight by `/pm-workflow`; mandatory rule: any new pattern surfaced during a session MUST be appended before feature closure. (2) W9 branch-drift real-time alert via `PostToolUse:Bash` hook ([`scripts/check-branch-drift.py`](../../scripts/check-branch-drift.py)) — detects unexpected git HEAD changes from concurrent-session `git checkout` collisions; emits stderr warning + 4-step recovery playbook. Total framework mechanisms post-ship: **34 mechanical gates + 5 advisories** (1 new gate `PR_CACHE_STALE` from v7.8.4 batch). Shipped via [FT2 PR #328](https://github.com/Regevba/FitTracker2/pull/328) (catalog) + [FT2 PR #341](https://github.com/Regevba/FitTracker2/pull/341) (W9 hook).
>
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
> **v7.8.4 Pre-v7.9 Telemetry Calibration (SHIPPED 2026-05-12, single-session patch):** Patch-level hygiene release closing the noise floor before the 2026-05-21 v7.9 promotion decision. Master plan §2.2 promotion criterion #2 ('no false positives') needs a clean baseline. **Adds 1 operability gate (`PR_CACHE_STALE` auto-refresh) closing the 33-finding false-positive class observed when `.cache/gh-pr-cache.json` is empty/stale.** Narrows the `TIER_TAG_LIKELY_INCORRECT` heuristic via 3 fixes (target/kill claim filter + unit `\b` word-boundary + intervening-tier-marker filter). Introduces `.claude/shared/case-study-t1-references.json` reference ledger for T1 measurements not in default 2-ledger scope. Backfills 2 `cache_hits[]` from Mechanism C attributions. Closes 5 LOW doc-debt items. Resets stale `.claude/active-feature` lockfile. Captures first-ever `make snapshot-phase` invocation (off-SSD pre-v7.9 baseline). **`make integrity-check` baseline at ship: 0 findings + 0 advisory** (was 35+9 at session open). Total framework mechanisms unchanged from v7.8.3: **33 mechanical gates + 5 advisories**. Shipped via FT2 [PR #314](https://github.com/Regevba/FitTracker2/pull/314). New honesty ledger entry FT2-FH-002 documents the v7.8.3 PR-cache-staleness silent-pass class. Source: [CLAUDE.md "v7.8.4" section](../../CLAUDE.md) + [cold-start entrypoint](../../.claude/entrypoints/framework-v7-8-4.md) + [infra master plan](infra-master-plan-2026-05-12.md).
>
> **v7.8.3 Cross-Repo State-Sync (SHIPPED 2026-05-11, single-day ship via subagent-driven-development):** 5-phase release umbrella implementing the bidirectional cross-repo state.json contract. **10 PRs across 2 repos in one day:** FT2 [#298](https://github.com/Regevba/FitTracker2/pull/298) (Phase 0: V2 enforce + V9 driver extension to feature logs + snapshot script + CLAUDE.md bump), [#299](https://github.com/Regevba/FitTracker2/pull/299) (Phase 1 D-3: unified PR cite cache + 63/63 retroactive validation), [#300](https://github.com/Regevba/FitTracker2/pull/300) (Phase 2: 3 new state_owner gates + 62-feature backfill + morphed C-5), [#301](https://github.com/Regevba/FitTracker2/pull/301) (Phase 4 reverse-sync auto-PR), [#303](https://github.com/Regevba/FitTracker2/pull/303) (Phase 4 case study), [#304](https://github.com/Regevba/FitTracker2/pull/304) (Phase 4 closure: state.json complete + tasks reconciled). Companion fitme-story PRs: [#86](https://github.com/Regevba/fitme-story/pull/86) (Phase 1 C-4 telemetry aggregator), [#87](https://github.com/Regevba/fitme-story/pull/87) (Phase 3 D-1 reverse-sync workflow), [#88](https://github.com/Regevba/fitme-story/pull/88) (Phase 4 inaugural fitme-story-native feature `3d-interactive-framework-flow-diagram`), [#89](https://github.com/Regevba/fitme-story/pull/89) (Phase 3 hotfix moving `secrets.*` from job-level to step-level), [#90](https://github.com/Regevba/fitme-story/pull/90) (Phase 4 cutover re-trigger), [#91](https://github.com/Regevba/fitme-story/pull/91) (Phase 4 showcase MDX slot 29). **6 framework dogfood catches in real-time, all caught by gates, all fixed before merge** (PHASE_TRANSITION_NO_LOG/NO_TIMING; reverse-sync workflow load failure; HEAD~1 diff window mismatch; BROKEN_PR_CITATION on bare `PR #72`; STATE_OWNER_LOCATION_MISMATCH false positives on 3 features whose names start with "fitme-story-"; TASK_LIE on closure PR's self-referential task). **3 v7.9 candidates surfaced + formalized: F11** (`BRANCH_ISOLATION_HISTORICAL` recognition for `reverse-sync/*` branches), **F12** (`actionlint` pre-commit hook), **F13** (`workflow_dispatch` `source_commit` input). Cycle-time gate count: 13 → 16. **Total framework mechanisms post-ship: 33 mechanical gates + 5 advisories.** HADF Phase 2-bis Sub-exp 1 unblock criterion met (Q1=S1 sequencing); earliest start 2026-05-23 (T+12d soak). Spec: [`docs/superpowers/specs/2026-05-11-cross-repo-state-sync-impl-design.md`](../superpowers/specs/2026-05-11-cross-repo-state-sync-impl-design.md). Plan: [`docs/superpowers/plans/2026-05-11-cross-repo-state-sync-impl.md`](../superpowers/plans/2026-05-11-cross-repo-state-sync-impl.md). Source case study: [`../case-studies/cross-repo-state-sync-impl-case-study.md`](../case-studies/cross-repo-state-sync-impl-case-study.md). Showcase: [`fitme-story 04-case-studies/29-cross-repo-state-sync-impl.mdx`](https://github.com/Regevba/fitme-story/blob/main/content/04-case-studies/29-cross-repo-state-sync-impl.mdx). v7.8.3 cold-start entrypoint: [`.claude/entrypoints/framework-v7-8-3.md`](../../.claude/entrypoints/framework-v7-8-3.md).
>
> **v7.8.1 Branch Isolation + Feature-Closure Completeness (SHIPPED 2026-05-07, single-session ship):** First feature shipped via the v7.8 protocol (Mechanism C session attribution + isolated worktree from Phase 1). Three new write-time gates promoted from advisory: `ISOLATION_OPT_OUT_REASON_MISSING` (any feature whose `isolation_opt_out=true` must record a reason), `BRANCH_ISOLATION_VIOLATION` Modes B+C (every commit on infra paths + every `current_phase` mutation must come from the feature worktree), `FEATURE_CLOSURE_COMPLETENESS` (transitions to `complete` validate state↔case-study cross-reference + 7 required fields + Q7 kill-criteria-resolution + Q6 PR parity). Three new cycle-time advisories: `BRANCH_ISOLATION_HISTORICAL`, `BRANCH_ISOLATION_LAUNCHD_DRIFT`, `FEATURE_CLOSURE_COMPLETENESS` (cycle-time mirror). New tooling: `scripts/create-isolated-worktree.py` (auto-isolation CLI with idempotent + adopt-existing logic), `scripts/verify-isolation.py` (system-wide isolation status table), `scripts/feature-completeness-audit.py` (phase-appropriate forward-only check). Doc-debt fields `case_study_showcase` / `success_metrics` / `kill_criteria` / `dispatch_pattern` promoted from advisory to write-time gate. **28/28 implementation tasks done + T29 deferred. 130 unit tests, 19 pipeline assertions, all green. Framework reaches 30 mechanical gates + 5 advisories.** Three PRs merged today: [#244](https://github.com/Regevba/FitTracker2/pull/244) (gates + scripts) + [#245](https://github.com/Regevba/FitTracker2/pull/245) (Phase 8 closure + case study) + [#246](https://github.com/Regevba/FitTracker2/pull/246) (v7.8.1 docs propagation across 5 surfaces). Companion fitme-story PRs: [#52](https://github.com/Regevba/fitme-story/pull/52) (case-study showcase slot 25), [#53](https://github.com/Regevba/fitme-story/pull/53) (dev-guide bump to v7.8.1), [#54](https://github.com/Regevba/fitme-story/pull/54) (UCC resync to v7.8.1). 7 v8 candidates explicitly de-scoped at [`docs/superpowers/specs/2026-05-07-branch-isolation-out-of-scope.md`](../superpowers/specs/2026-05-07-branch-isolation-out-of-scope.md); Phase 9 prioritization at branch-isolation feature close (~2026-05-21) produces ranked v8 roadmap. Linear FIT-62 Done. Source case study: [`../case-studies/framework-v7-8-branch-isolation-case-study.md`](../case-studies/framework-v7-8-branch-isolation-case-study.md). Showcase: [`fitme-story 04-case-studies/25-framework-v7-8-1-branch-isolation.mdx`](https://github.com/Regevba/fitme-story/blob/main/content/04-case-studies/25-framework-v7-8-1-branch-isolation.mdx).
>
> **v7.8 Bridge (SHIPPED 2026-05-04 across 9 PRs):** 6 cooperating mechanisms (A coverage gates → F membrane status) all in advisory mode pending v7.9 measurement window opening 2026-05-11 (+7d). Schema bridge fields populated on 47/47 features. Cold-start entrypoint at `.claude/entrypoints/framework-v7-8.md` + first honesty-ledger entry FT2-FH-001 at `docs/case-studies/framework-honesty-ledger.md`. Case study: [`../case-studies/framework-v7-8-bridge-case-study.md`](../case-studies/framework-v7-8-bridge-case-study.md).
>
> **Other 2026-05-07 ships:** Push Notifications v2 platform-layer rebuild (PR #239) — single-day full PM cycle (Phases 0–8) after v1 UI-016 partial-ship. Platform layer = `NotificationGateway` + `NotificationConsumerRegistry` + `DeepLinkRouter` + `ReadinessAlertObserver` + `FirstWorkoutTrigger`. 16 tasks, ~1850 LOC, 36 tests including 3-case reachability gate codifying the v1 UI-016 lesson mechanically. Linear FIT-23 Done. Source case study `docs/case-studies/push-notifications-v2-case-study.md`. Smart-reminders consumer-side adaptation deferred to paired backlog enhancement.
>
> **Major 2026-05-06 ships:** UCC (Unified Control Center) — Astro→Next.js `/control-room/*` migration COMPLETE via PR #232 + #230 + 12 fitme-story PRs. 43/44 tasks done + 1 deferred (T2.5 passkey auth — moved to backlog). Daily sync routine `trig_01ThxQphvQQa8tyWMsxiyhdm` LIVE (09:04 IDT, 8 MCPs auto-attached). Source case study `docs/case-studies/unified-control-center-case-study.md`; showcase `fitme-story 04-case-studies/23a-unified-control-center.mdx`. AND Import Training Plan — Phase 1 (PR #234) — full PM rollback → Research v2 → ship after 2026-04-20 partial-ship audit (UI-015). 33 new tests + 9 import_* analytics events + GDPR Art-17/20.
>
> **v7.7 Validity Closure (SHIPPED 2026-04-27, single-session ship):** A 2026-04-27 ledger pull surfaced that v7.6's "Known Mechanical Limits" included three items still mechanically or heuristically closable. v7.7 closed them in one session: A1 (`cache_hits[]` writer-path, GitHub issue #140), A2 (`cu_v2` schema validator), A3 (doc-debt field gates + bulk backfill of 32 case studies), A4 (state↔case-study linkage 95.5% → 100%), A5 (active-feature timing backfill, 3 features), C1 (tier-tag heuristic checker, advisory permanent — kill criterion 2 fired at baseline as designed). B1 + B2 are time-gated and verify automatically post-merge (B1 ~2026-05-04, B2 ~2026-05-03 to -06). UCC T43–T54 absorbed as M4 — framework-health dashboard live at fitme-story `/control-room/framework` (PR #7). **Two PRs awaiting merge: FitTracker2 [#144](https://github.com/Regevba/FitTracker2/pull/144) + fitme-story [#7](https://github.com/Regevba/fitme-story/pull/7).** Total framework mechanisms post-merge: 25 gates + 1 advisory. Linear epic [FIT-49](https://linear.app/fitme-project/issue/FIT-49/v77-validity-closure-epic) + 8 sub-issues (FIT-50 … FIT-57). Notion v7.7 sub-page live. 6 features paused for the freeze: app-store-assets, auth-polish-v2, import-training-plan, onboarding-v2-retroactive, push-notifications, stats-v2 — resume on PR #144 merge. D1 (Tier 2.1 auth playbook) + D2 (Tier 3.3 external replication, [#142](https://github.com/Regevba/FitTracker2/issues/142)) surfaced as a human-action checklist on the dashboard. Spec/plan/synthesis: [`docs/superpowers/specs/2026-04-27-framework-v7-7-validity-closure-design.md`](../superpowers/specs/2026-04-27-framework-v7-7-validity-closure-design.md), [plan](../superpowers/plans/2026-04-27-framework-v7-7-validity-closure.md), [case study + Section 99 synthesis](../case-studies/framework-v7-7-validity-closure-case-study.md).

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

### In Progress (as of 2026-05-07)

| Feature | Phase | Next Step |
|---|---|---|
| App Store Assets | implementation (paused) | Linear FIT-17. Pipeline scaffolding shipped; resume after v7.9 enforcement window. |
| Smart Reminders Behavioral Learning PR-2 | PR-1 shipped 2026-05-04 | Linear FIT-42. PR-2 (SmartTimingResolver + A/B test, default-on flip) gated on cohort data window — earliest 2026-05-09. |
| Smart Reminders ↔ Push Notifications v2 deep-link integration | Enhancement, not yet started | Surfaced 2026-05-07 during push-notifications-v2 Phase 0. Smart-reminders consumer-side adaptation. Work type: Enhancement (4-phase). |

### Recently Shipped (2026-04-30 → 2026-05-07)

| Feature | Phase | PR | Date |
|---|---|---|---|
| Stats v2 — final ship | complete | #164 | 2026-04-30 |
| Auth Polish v2 | complete | #163 | 2026-05-01 |
| Framework Honesty Fixes | complete | #168 + #169 | 2026-05-01 |
| Framework v7.8 PR-1 (Mechanism C scaffolding) | complete | #173 | 2026-05-02 |
| State.json reconciliation pass | complete | #174 | 2026-05-02 |
| Smart Reminders Behavioral Learning PR-1 | complete | #190 + #198 | 2026-05-04 |
| Framework v7.8 Bridge | complete | 9 PRs (#185-#189, #191-#194, #195) | 2026-05-04 |
| iOS audit Tier 1+2 closure | complete | #211-#216 | 2026-05-08 |
| Unified Control Center (UCC) | complete | #232 + #230 + 12 fitme-story | 2026-05-06 |
| Import Training Plan — Phase 1 | complete | #234 + #235 + fitme-story #48 | 2026-05-06 |
| Push Notifications v2 platform-layer | complete | #239 | 2026-05-07 |
| Framework v7.8.1 Branch Isolation + Closure Completeness | complete | #244 + #245 + #246 | 2026-05-07 |

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
