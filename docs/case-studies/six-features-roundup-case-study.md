# Six Features Roundup — Honest Backlog Accounting

**Date written:** 2026-04-20

> **Subtitle:** Six features that shipped before the "every feature gets a case study" rule landed, or slipped through it — consolidated into one roundup so the record is honest rather than padded with six thin fabrications.

## Why This Roundup Exists

The project rule from 2026-04-13 says every feature gets a case study. Six features pre-date that rule or slipped through the net:

- **ai-cohort-intelligence** — retroactively backfilled from a pre-PM-workflow era.
- **android-design-system** — a research-only deliverable with no app surface.
- **development-dashboard** — a full PM lifecycle on a web app, not the iOS app.
- **gdpr-compliance** — a legal-blocker feature shipped through full lifecycle.
- **google-analytics** — the analytics foundation itself.
- **stats-v2** — a UX Foundations alignment pass on the Stats screen.

The temptation was to write six dedicated case studies. The honest answer is that three of them don't warrant one — the material is thin, the rule post-dates the work, and fabricating narrative around a three-line state.json would violate the same "data drives decisions" principle the rule is trying to enforce. So: one roundup, ~30-50 lines per feature, grounded in state.json, commits, and the PRD/research/tasks files that actually exist.

---

## Summary Matrix

| Feature | Phase | Branch | Supporting docs | PR / commits | Why no dedicated case study |
|---|---|---|---|---|---|
| ai-cohort-intelligence | complete (backfilled) | none | none | PR #12 (`32f27bf`) | Shipped pre-PM-workflow. Backfill record only. |
| android-design-system | complete | `feature/android-design-system` | prd + research + tasks | `f033e5d` + `f6564d2` | Research-only deliverable. No shipped app UI. |
| development-dashboard | complete | `feature/development-dashboard` | none (state.json only) | merge `7f69d07`, 10+ follow-up commits | Web app, not iOS. Full lifecycle recorded in state.json but no rich narrative to extract beyond "it shipped and kept getting fixed". |
| gdpr-compliance | complete | `feature/gdpr-compliance` | prd + research + tasks + ux-spec | merge `2acd1d9` (8 files, +711) | Legal-blocker feature. Dense material, but shipped pre-rule — worth narrating here. |
| google-analytics | complete | `feature/google-analytics` | prd + research + tasks + ux-spec | merge `ac85c73` (22 files, +1970) | The foundation everything else measures against. Shipped pre-rule — worth narrating here. |
| stats-v2 | complete | `feature/stats-v2` | prd + tasks + v2-audit-report | PR #76 (`e93d6e8`, +1308 lines) | v2 refactor pass — worth narrating here. |

**The honest stratification:** GDPR, Google Analytics, and Stats v2 have enough material for proper treatment. AI Cohort, Android DS, and Development Dashboard do not. Everything below reflects that.

---

## 1. ai-cohort-intelligence — The Backfill

**One-line headline:** A federated learning engine that shipped before the PM workflow existed, captured retroactively with a single state transition.

| Field | Value |
|---|---|
| Scope | AI engine (Python FastAPI backend) + iOS AI orchestration layer |
| PR / commits | PR #12 (`32f27bf`) — "Federated cohort intelligence: AI engine, backend, iOS AI layer" |
| Files (approx) | ~30+ new files: `ai-engine/app/` tree (auth, middleware, models, config), `FitTracker/AI/` (`AIEngineClient.swift`, `AIOrchestrator.swift`, `AITypes.swift` 385 lines, `FoundationModelService.swift`) |
| Work type | Feature (backfilled) |
| Transitions | 1 — `init → complete` on 2026-04-06T14:00:00Z |
| Backfill note | "Retroactive backfill — feature was shipped pre-PM workflow." |

**What shipped.** A client/server AI stack: the Python `ai-engine` has JWT validation, rate limiting, Dockerfile, GitHub CI; the iOS side has `AIOrchestrator`, `AIEngineClient`, `FoundationModelService`, and a typed `AITypes.swift`. The backfilled PRD lives at `docs/product/prd/18.9-ai-cohort-intelligence.md`. Metrics: primary `recommendation_acceptance_rate` (baseline 0, target 30%), kill criteria "<10% acceptance after 6 months → simplify to rules".

**Why no dedicated case study.** There is no research.md, no tasks.md, no UX spec, and no phase-by-phase transition log — state.json explicitly marks Research/Tasks/UX/Testing/Review as `pre-pm-workflow`. The only historical artifact that would anchor a case study is PR #12 itself and the file diff. A dedicated case study would have to either fabricate a PM narrative around the retroactive fill (bad) or effectively be a file-tree tour (thin).

**What a full case study would have recorded (if the workflow had existed at the time).** The scope split between Python backend and Swift client, the choice to use FastAPI + JWT + rate limiting for the cohort service, the design of `AITypes.swift` as the typed contract, and the decision to have `AIOrchestrator` mediate between `FoundationModelService` (on-device) and `AIEngineClient` (server). All of this is legible in the code, none of it is documented as PM decisions.

---

## 2. android-design-system — The Research-Only Deliverable

**One-line headline:** A 92-token iOS → Material Design 3 mapping exercise that never ships a line of Android code, because it explicitly wasn't meant to.

| Field | Value |
|---|---|
| Scope | Token mapping documentation + Style Dictionary Android config |
| PR / commits | `f033e5d` (feat — 6 files, +763 lines), `f6564d2` (docs — Phase 9/9 completion) |
| Work type | Feature (research-only) |
| RICE score | 4.8 (MEDIUM priority) |
| Transitions | 3 — `init → research → prd → complete` on 2026-04-04 |
| Phases skipped | Tasks / UX / Implementation / Testing / Review (all marked `skipped`, rationale: "Research-only deliverable") |

**What shipped.** Three files drive the deliverable: `design-tokens/config-android.json` (47 lines) configures Style Dictionary's Android output, `docs/design-system/android-token-mapping.md` (310 lines) is the comprehensive iOS → MD3 mapping reference, and the feature's own `research.md` (201 lines) is the decision record. Metrics: `tokens_mapped` 92/92, `component_parity_audit` 13/13, `style_dictionary_config_ready` true.

**The research findings worth preserving.** Per the PRD: 46 colors → MD3 role mapping with hex, 22 typography styles → MD3 type scale, 8 spacing tokens (4pt grid → dp grid, 1:1), 6+ radius values → MD3 shape categories, 2 shadow presets → MD3 tonal elevation, and 4 motion categories → MD3 motion specs. Dark mode: how FitMe's opacity-based system would map to MD3 dark theme. Style Dictionary generates `.kt` files from `tokens.json` alongside the existing Swift output.

**Why no dedicated case study.** The feature's deliverable is documentation. A case study of a documentation deliverable would effectively be a summary of the documentation — a doc about a doc. The feature exists to de-risk *future* Android work, and nothing about the research is novel to the PM workflow itself. Kill criterion on the feature ("Defer Android expansion if iOS core not stable") confirms: nothing shipped to users, nothing to narrate about user impact.

**What a full case study would have recorded.** The four-hour research → prd → complete compression — the whole cycle ran inside 30 minutes on 2026-04-04 — as an example of the PM workflow handling a documentation deliverable cleanly (skip Phases 3-8 explicitly, not implicitly, with a rationale recorded on every skipped phase).

---

## 3. development-dashboard — The Off-Platform Full Lifecycle

**One-line headline:** The only feature in the project that's a standalone Astro/React web app rather than iOS code, with a full 10-transition PM lifecycle recorded and a long tail of follow-up fixes.

| Field | Value |
|---|---|
| Scope | `dashboard/` — Astro + React + Tailwind v4 web app deployed on Vercel |
| PR / commits | Merge `7f69d07` (feature branch merged via `--no-ff`). Implementation: `4aff49f`, `7acf610`, `494e814`, `969c1f9`. Post-merge fixes: `78c8bf6`, `5aed329`, `be8807d`, `c2c38fa`, `28dffcb`, `eb9d9f3`, `6cf7ca8`, `9ef0493`, `8c5e27d`, `9d53815` |
| Work type | Feature |
| Transitions | 10 — full `init → research → prd → tasks → ux → implement → testing → review → merge → docs → complete` across 2026-04-02 to 2026-04-03 |
| Wall time | ~6 hours (18:00 → 00:05 the next day) |
| Tests | 9/9 reconcile tests pass |
| Compliance | Design system check passed with one scoped extension: "4 web-only status/priority colors extending FitMe palette" |
| Deferrals | T14 (GitHub Issues live sync) — deferred because MCP auth unavailable at build time |
| Metrics | Primary: "Dashboard page views per week" (target 10). Kill criteria: <5 unique visitors/week after 60 days AND developer stops using it |

**What shipped.** A 7-component React/Astro dashboard (`Dashboard.jsx`, `KanbanBoard.jsx`, `FeatureCard.jsx`, `TableView.jsx`, `SourceHealth.jsx`, `AlertsBanner.jsx`, `ThemeToggle.jsx`, `PipelineOverview.jsx`), a 6-parser ingestion pipeline (`backlog.js`, `metrics.js`, `prd.js`, `roadmap.js`, `state.js`, `unified.js`), a reconciliation engine (`reconcile.js`, 133 lines) with 9 passing tests, drag-drop via dnd-kit, dark mode, Vercel deploy config, and server-only guard on `github.js` to keep GitHub tokens server-side.

**The decision trail in state.json.** Research picked "Astro + Tailwind + GitHub API over GitHub Projects, Notion, markdown" after evaluating nine sources (linear, jira, monday, lemonade, plus docs). UX approved 12 components with the design system extended rather than violated. Review logged 3 risks explicitly: post-deploy metrics instrumentation, deferred GitHub Issues integration, server-only token enforcement.

**Why no dedicated case study.** The feature is off-platform — a web dashboard, not an iOS feature. The case study library centers on the iOS app and framework evolution; a dashboard case study would orbit in a different gravitational field (Astro SSG, Vercel, JS tooling) than the rest of the library. More importantly: the rich material is *post-merge*. The follow-up commit sequence (`78c8bf6` → `9d53815`) is the actual story — data-source wiring, drag-drop on all columns, dark mode toggle, case study link fixes, operations control room, client-side tab nav, 22 shared-layer conflicts resolved, 53 reconcile alerts resolved, schema normalization, null-guards. That's where the dashboard became useful. But each of those is a small fix, and a "many small fixes stabilized the dashboard" narrative is thin.

**What a full case study would have recorded.** The fastest-to-complete full lifecycle in project history (6 hours end-to-end). The pattern where the initial 10-transition cycle produced a shipping artifact, and a second, uncounted wave of ~10 post-merge commits produced a *useful* artifact — which is the shape most projects actually look like, and which the PM workflow currently doesn't have a name for. ("Post-launch stabilization" would be the natural term; the dashboard is Exhibit A.)

---

## 4. gdpr-compliance — The Legal-Blocker Feature

**One-line headline:** The first feature in the project where kill criteria read "Legal requirement — cannot be killed," shipped end-to-end in two hours.

| Field | Value |
|---|---|
| Scope | In-app account deletion (GDPR Art 17) + JSON data export (Art 20) + 30-day grace period + Settings integration |
| PR / commits | Merge `2acd1d9` (8 files, +711 lines). Implementation: `a416b4a` (PM phases), `13f4cfe` (core services + views + analytics), `470ee94` (settings wiring), `ff1c737` (6 analytics tests + taxonomy validation), `40131ee` (docs) |
| Work type | Feature |
| Transitions | 10 — full lifecycle 2026-04-04T11:00Z → 13:00Z |
| Wall time | 2 hours end-to-end |
| Tests | 6 GDPR analytics tests (total AnalyticsTests now +23 events covered), tokens-check green |
| High-risk files touched | Zero |
| Priority | CRITICAL (legal + App Store requirement) |

**What shipped.** `AccountDeletionService.swift` (162 lines), `DataExportService.swift` (170 lines), `DeleteAccountView.swift` (154 lines), `ExportDataView.swift` (76 lines), 28-line `SettingsView.swift` integration, 22 lines in `AnalyticsProvider.swift` + 31 lines in `AnalyticsService.swift` for the 5 GDPR events, and 69 lines of `AnalyticsTests.swift` additions. The PRD enumerates 9 data stores that must be cleared on deletion: device, Keychain, UserDefaults, CloudKit, Supabase (sync_records, cardio_assets, auth.users), AI cohort (anonymize), Firebase Analytics.

**The scope decisions.** Research picked "full in-app deletion + JSON export + 30-day grace period" over the two alternatives (web portal, email-request workflow). The grace period is architectural: account is marked for deletion, user can cancel within 30 days, and a background job does the actual destructive work after expiry. Re-authentication (biometric or password) is required before deletion proceeds. Export is JSON via iOS share sheet — not PDF, not CSV, not email.

**Why shipped pre-rule, not narrated yet.** The "every feature gets a case study" rule landed 2026-04-13, nine days after GDPR merged. The feature has the densest PRD of the six in this roundup (12 requirements, 5 events, 2 screens, 9 data stores audited) and the cleanest paper trail (research + prd + tasks + ux-spec all present). It could have been a dedicated case study; it's in the roundup because three of the six don't warrant one, and consolidating was cleaner than mixing formats.

**Risks logged at review.** Two explicit: "Real Supabase/CloudKit runtime verification requires credentials" and "Atomic rollback not yet implemented for partial deletion failures." Both are honest — the service composes 9 store-clears and if the 7th fails, the first 6 don't roll back. That's a known gap rather than an undiscovered one. The kill criteria entry ("Legal requirement — cannot be killed") is the project's first explicit acknowledgment that some features have floor-only, never-ceiling success conditions.

**What a full case study would have recorded.** The 2-hour wall time as the shape of "well-scoped legal feature with no design ambiguity." The pattern where research consumed 30 min, PRD consumed 15 min, tasks + UX consumed 30 min, implementation consumed 45 min, and review/merge/docs consumed 15 min — roughly an hour each for "decide" and "build" on a feature with zero high-risk files. Compare against Google Analytics below (19-hour wall time, +1970 lines, cross-cutting).

---

## 5. google-analytics — The Measurement Foundation

**One-line headline:** The feature that went from "11 shipped features, 40 defined metrics, zero analytics instrumentation" to a working GA4 pipeline with protocol abstraction, consent gating, and screen tracking — and unblocked every metric target in the project.

| Field | Value |
|---|---|
| Scope | Firebase Analytics SDK integration, protocol-based AnalyticsService, ConsentManager (ATT + GDPR), 24 screen tracks, 15 custom events, Settings opt-out, GA4 2025 naming conventions |
| PR / commits | Merge `ac85c73` (22 files, +1970 −39). Ordered implementation chain: `7b320bc` (PM phases 0-3), `e09b58f` (core infrastructure), `48d1dd3` (GA4 2025 naming), `05d34d8` (Firebase + GA4 setup guide, 20 steps), `ea7364a` (wire Firebase into FitTrackerApp), `9f4a29c` (FirebaseAdapter in DEBUG), `1421a23` (screenView → AnalyticsEventScreenView), `0bd8c35` (T8 screen tracking), `35d770a` (T10 settings toggle), `f404ed1` (T11 — 17 unit tests), `05ef79d` (T12 metrics framework update), `c4be39d` (review), `16ed42d` (docs 9/9) |
| Work type | Feature |
| RICE | 8.0 (highest remaining at the time) |
| Transitions | 10 — full lifecycle 2026-04-02T19:30Z → 2026-04-04T10:45Z |
| Wall time | ~39 hours calendar, ~19 hours active |
| Tests | 17 unit tests (AnalyticsTests.swift +297 lines) |
| High-risk files touched | Zero |

**What shipped.** The infrastructure layer: `AnalyticsProvider.swift` (195 lines) defines the protocol, `AnalyticsService.swift` (243 lines) is the singleton façade, `ConsentManager.swift` (106 lines) handles ATT + GDPR consent, `FirebaseAnalyticsAdapter.swift` (40 lines) is the production adapter, `MockAnalyticsAdapter.swift` (47 lines) is the test double, `AnalyticsScreenModifier.swift` (23 lines) is the SwiftUI view modifier for per-screen tracking, and `ConsentView.swift` (113 lines) is the user-facing consent screen. Plus the 361-line `docs/project/firebase-setup-guide.md`, a 65-line `docs/product/analytics-taxonomy.csv`, and 22 lines of metrics-framework.md updates.

**The architectural decisions.** Research picked "GA4 + Firebase over TelemetryDeck, Mixpanel, Amplitude, PostHog" with the protocol abstraction explicitly framed as "swap providers without code changes." The protocol layer isn't over-engineering — it's the mechanism that lets MockAnalyticsAdapter exist for tests, and the reason the `c4be39d` code review was clean (every event flows through one well-typed surface). GA4 automatic events (`first_open`, `app_open`, `session_start`) stay unprefixed. Custom events get screen prefixes. This is the feature that implicitly set the stage for the 2026-04-08 screen-prefixed-analytics rule that Home v2 later codified.

**The known limitations.** Three risks logged at review: "GoogleService-Info.plist contains API key (not committed to git — local only)", "Firebase adapter stubbed until SPM added in Xcode", and "Xcode build requires paid Apple Developer account for device testing." Metrics: 14/40 instrumented at merge (35%) — not 40/40, by design — the remaining events get instrumented as the features that emit them land.

**Why shipped pre-rule, not narrated yet.** Same reason as GDPR: merged 2026-04-04, rule landed 2026-04-13. But GA is arguably the most consequential feature in the project's first two weeks because every subsequent feature's kill criteria, funnel metrics, and post-launch reviews depend on it. If one of the six in this roundup deserved its own case study, it's this one.

**What a full case study would have recorded.** The "integrate the measurement substrate first" pattern — GA shipped before most of the features that emit events against it, and the shape of those features' PRDs (every feature now has an analytics spec gate in Phase 1) is downstream of GA existing. The `48d1dd3` naming-convention refactor mid-sprint is the clearest single signal that the project's analytics taxonomy was still being shaped during the feature itself, not just the tooling.

---

## 6. stats-v2 — The Lightest v2 Audit

**One-line headline:** The Stats screen had the best token compliance of any screen (100% font/color/spacing/radius) and the worst accessibility (27% — a chart with zero VoiceOver), and v2 closed that gap with 9 findings and 4 analytics events.

| Field | Value |
|---|---|
| Scope | UX Foundations alignment on StatsView — a11y pass + `AppLayout` token enum + 4 analytics events + nested-type extraction |
| PR / commits | PR #76 `e93d6e8` (11 files, +1308 −7). Creates `FitTracker/Views/Stats/v2/StatsView.swift` (899 lines) alongside v1 (annotated HISTORICAL, −14/+14 delta from the header) |
| Work type | Feature (v2_refactor) |
| Audit findings | 9 total — 2 P0, 3 P1, 4 P2 — "lightest audit — best baseline compliance" |
| Transitions | 4 — `research → prd → tasks → ux_or_integration → implementation` between 2026-04-10T15:10Z and 15:25Z |
| Analytics events added | 4 — `stats_period_changed`, `stats_metric_selected`, `stats_chart_interaction`, `stats_empty_state_shown` |
| Design system tokens added | `AppLayout` enum: `chartHeight` (158), `emptyStateMinHeight` (128), `chipMinWidth/Ideal/Max` (128/144/168), `dotSize` (8) |
| Tests | `FitTrackerTests/StatsAnalyticsTests.swift` (93 lines, 5 tests) |

**What shipped.** PR #76 landed 11 files: the v2 StatsView rewrite, 18 lines of `project.pbxproj` swap (v2 into Sources, v1 out), 16 lines of `AppTheme.swift` (the `AppLayout` enum), 15 + 28 lines in AnalyticsProvider + AnalyticsService for the 4 new `stats_` events, the audit report, PRD, tasks, state.json, and the tests. The v1 `StatsView.swift` keeps a 14-line HISTORICAL header pointing at v2.

**The audit's findings** (from `v2-audit-report.md`):
- **P0 F1:** Raw `.easeInOut(duration: 0.2)` animation instead of AppMotion token.
- **P0 F2:** Chart (lines 524-626 of v1) renders a drag-gesture interactive chart with zero accessibility — data invisible to assistive tech.
- **P1 F3/F4/F5:** Hardcoded frame values (128, 158, 128/144/168, 8x8 dot) — the trigger for the new `AppLayout` enum.
- **P2 F6/F7:** Period picker + ChartCard missing container a11y labels.
- **P2 F8:** GeometryReader in chart overlay — kept for iOS 16 compat, documented inline.
- **P2 F9:** Nested types (`StatsPeriod`, `StatsFocusMetric`, `MetricSeriesPoint`) extracted to `Models/Stats/`.

**The compliance scorecard.** Fonts / spacing / colors / radii: 100% each. Motion: 0% (one raw animation). Accessibility: 27% — 4 out of 15 elements labeled. State coverage: 100%. This is the cleanest case for "token compliance doesn't imply UX foundations compliance" the project has produced — Stats was the most token-compliant screen and simultaneously the least accessible.

**Why not a dedicated case study.** The v2 refactor cycle is well-documented across Home (`18-home-today-screen.md`), Training, Nutrition, Settings (`m-1-settings-decomposition-case-study.md`), and the broader v2-rule codification. Stats is the *lightest* pass in the series — the lowest finding count, the smallest scope ("screen architecture already solid"), and the narrowest decision space (3 decisions required: AppLayout enum, chip sizing approach, GeometryReader handling — all answered cleanly). A dedicated case study would largely replicate structure from the earlier v2 case studies without adding a new project-level lesson.

**Caveat on state.json.** The state.json for stats-v2 has an inconsistency worth flagging: `current_phase: complete` sits alongside `phases.implementation.status: in_progress` and all 10 tasks at `status: pending`. The git record shows PR #76 merged and the v2 file (899 lines) exists — so the feature did ship. The state.json was not fully reconciled during merge. This is itself a small data-integrity finding for the PM workflow: state.json's top-level phase should be derived from, or validated against, phase-by-phase statuses.

**What a full case study would have recorded.** The observation about token compliance vs. a11y compliance being orthogonal. And the state.json inconsistency noted above — useful as a concrete example of where the PM workflow's merge checklist could add an automated validation step.

---

## Cross-Feature Lessons

**When does a feature need a dedicated case study?** Based on this set, the threshold looks like: (1) was shipped after the 2026-04-13 rule, (2) has a substantive PRD and a phase-by-phase transition log, *and* (3) produces at least one project-level lesson that generalizes beyond the feature itself. Two of the three is often not enough — Android DS has (2) and partially (3) but its lesson generalizes to exactly one scenario (research-only deliverables). The dashboard has (2) fully but mostly a bespoke tech stack.

**Pre-rule features should be backfilled honestly, not narratively.** AI Cohort's state.json is a single transition and a backfill note. That's the correct record. Writing a dedicated case study for it would require either inventing PM decisions that weren't made, or producing a file-tour that's redundant with the PR. The roundup format handles this cleanly: acknowledge the feature exists, name what shipped from the PR stats, link the backfilled PRD, and stop.

**Research-only deliverables are a real work type, not a degenerate one.** Android DS explicitly skipped Phases 3-8 with a rationale on every skipped phase. This is the template for documentation-deliverable features: research and PRD execute normally, everything downstream is skipped with an explicit note, and the metrics target the deliverable (tokens_mapped 92/92) not user behavior. The PM workflow already supports this; Android DS is the reference example.

**There's a "phase-complete vs. usefully-shipped" gap.** Development Dashboard shipped on `7f69d07` with a clean 10-transition log and was then followed by ~10 post-merge fixes that made it actually useful. The PM workflow's current `phases.merge.status: done` treats both versions as the same thing. A future enhancement could add a "post-launch stabilization" phase that captures the second wave — the dashboard is the best example of why that would help.

**Kill criteria reveal feature shape.** GDPR's "Legal requirement — cannot be killed," Google Analytics' "Data-driven foundation — cannot be killed. If consent rate <5%, simplify consent flow," and Stats v2's regression-only criterion ("Accessibility coverage drops below 70% after merge") all describe features that cannot be removed on a growth threshold. Contrast with AI Cohort's growth-threshold criterion ("<10% acceptance after 6 months → simplify to rules"). The shape of a feature's kill criteria correlates strongly with whether its case study has an interesting narrative: growth-threshold features produce stories about adoption and iteration, floor-only features produce stories about compliance and risk management.

**Two hours is possible when scope is legally bounded.** GDPR's 2-hour end-to-end wall time is not a record meant to be chased — it's a marker for what "well-scoped, zero-design-ambiguity, zero-high-risk-files" actually looks like. Features with genuine design ambiguity (Home v2, Training v2) or cross-cutting surface area (Google Analytics) correctly take longer.

---

## Links

- **State files:** `.claude/features/{ai-cohort-intelligence,android-design-system,development-dashboard,gdpr-compliance,google-analytics,stats-v2}/state.json`
- **Backfilled PRD (ai-cohort):** `docs/product/prd/18.9-ai-cohort-intelligence.md`
- **Android token mapping:** `docs/design-system/android-token-mapping.md`
- **Firebase setup guide:** `docs/project/firebase-setup-guide.md`
- **Stats v2 audit:** `.claude/features/stats-v2/v2-audit-report.md`
- **Rule source:** `CLAUDE.md` — "Every feature gets a case study" (from 2026-04-13)
- **Showcase counterpart:** `/Volumes/DevSSD/fitme-showcase/04-case-studies/24-backlog-features-roundup.md`
