# Analytics Observability — Decisions Log & Turnover Document

**Created:** 2026-05-13
**Purpose:** Complete, self-contained record of every decision, finding, and rationale from the 2026-05-13 analytics audit + brainstorm session. This document exists so any future operator or agent can resume the work without depending on conversation context, agent memory files, or session transcripts.
**Author:** Claude Opus 4.7 (1M context)
**Operator:** Regev (FitMe project)
**Companion:** [`analytics-master-plan-2026-05-13.md`](analytics-master-plan-2026-05-13.md) (the spec/PRD)
**Parent:** [`infra-master-plan-2026-05-12.md`](infra-master-plan-2026-05-12.md)

> **If you are picking this up cold:** read this doc top-to-bottom first. Then read the master plan spec. Then check `.claude/features/analytics-observability/state.json` for current phase. Then check `.claude/logs/analytics-observability.log.json` for last event.

---

## §1 Origin

The work began when the operator asked: *"let's have a full analytics review for all features both ios and web and let's check and all events are connected and firing to GA4."*

This triggered the `/analytics validate` skill protocol. The audit ran over ~2 hours and produced findings significant enough that the operator extended the scope to a new feature: `analytics-observability`.

---

## §2 Audit Findings (the empirical baseline)

### §2.1 iOS (FitTracker2)

| Metric | Value | Source |
|---|---|---|
| Total events declared in `AnalyticsEvent` enum | **114** | [`FitTracker/Services/Analytics/AnalyticsProvider.swift`](../../FitTracker/Services/Analytics/AnalyticsProvider.swift) |
| Total screens in `AnalyticsScreen` enum | 42 | same file |
| Total user properties in `AnalyticsUserProperty` enum | 7 | same file |
| Events referenced from app code (not tests) | **112 / 114** (98%) | grep `AnalyticsEvent.<const>` across `FitTracker/` |
| Events covered by analytics tests | **93 / 114** (81%) | 11 test files in `FitTrackerTests/*Analytics*.swift` |
| Screen-prefix naming violations | **0** | per CLAUDE.md Analytics Naming Convention |
| Events declared but never fired in app code | **2** | `ai_recommendation_accepted`, `ai_recommendation_dismissed` |
| Events declared but never tested | **21** | notable clusters: 5 notification platform events, 4 onboarding_auth events |
| CSV taxonomy rows | **58** (out of 114 declared events = 56 missing rows) | [`docs/product/analytics-taxonomy.csv`](../product/analytics-taxonomy.csv) |
| Screens missing CSV rows | **7** | `delete_account`, `export_data`, `imported_plan_detail`, `imported_plans_list`, `onboarding_auth`, `onboarding_success`, `training_session` |
| User properties missing CSV rows | **1** | `onboarding_completed` |

**Production wiring:** Firebase plist present at [`FitTracker/GoogleService-Info.plist`](../../FitTracker/GoogleService-Info.plist); FirebaseAnalytics SDK linked in project.pbxproj; [`FirebaseAnalyticsAdapter`](../../FitTracker/Services/Analytics/FirebaseAnalyticsAdapter.swift) wired by `AnalyticsService.makeDefault()` when not under XCTest and plist present. **iOS events ARE firing to GA4 in production builds.** Connectivity verified at the code level; runtime firing not mechanically verifiable without GA4 MCP connection.

### §2.2 Web (fitme-story)

| Metric | Value | Source |
|---|---|---|
| GA4 integration | `@next/third-parties/google` in `src/app/layout.tsx` via `NEXT_PUBLIC_GA_ID` env | fitme-story repo |
| `.env.example` for GA_ID | **Missing** — operator must know to set in Vercel dashboard | — |
| `dashboard_*` events declared | 8 | `src/lib/control-room/analytics.ts` |
| `dashboard_*` events wired | 7 (1 intentional stub: `kanban_drag` — Wave 1 Kanban is read-only) | call-site grep |
| `design_system_*` events declared | 4 | `src/components/design-system/analytics.ts` |
| `design_system_*` events wired | **2** (`section_view`, `figma_link_click`) — `component_expand` + `code_copy` declared but no call site | — |
| Test coverage | 13 unit tests in `src/lib/control-room/analytics.test.ts` (node:test) | — |
| Vercel Analytics product | **NOT installed**; only `@vercel/speed-insights` (separate product) | `package.json` |
| `/control-room/framework` live GA4 read | **None** — purely repo-side telemetry | direct inspection |

### §2.3 GA4 read-side / verification capability

- GA4 MCP adapter is **defined** at [`.claude/integrations/ga4/adapter.md`](../../.claude/integrations/ga4/adapter.md) (mcp-server-ga4 by harshfolio, needs `GA4_PROPERTY_ID` + `GOOGLE_APPLICATION_CREDENTIALS`).
- GA4 MCP is **NOT connected.** [`.claude/shared/external-sync-status.json`](../../.claude/shared/external-sync-status.json) (stale 2026-04-30) reports `firebase: "unknown"`, `crash_free_rate: "unknown"`, `instrumented_percentage: 14/40 = 35%`. No `mcp.connected: true` for GA4 (Linear + Notion are live; GA4 isn't).
- Practical consequence: **firing cannot be mechanically verified** without (a) connecting the GA4 MCP, OR (b) the operator opening GA4 Realtime/DebugView manually.

### §2.4 Single biggest finding

The CSV taxonomy is **48% out of date** (58 rows vs 114 enum events). The `/analytics validate` gate exists to catch this exact drift but evidently has not been running mechanically — its cross-reference check is a manual sub-command, not a pre-commit hook. This is the centerpiece bug Phase 1.A + 1.B target.

---

## §3 User Directive (the extended scope)

After the audit, the operator said:

> *"add to the plan: add to skills GA4 MCP check and remote live debugger of the events when analytic events are created — also let's add the creation of the dashboard task to this and create this plan as a sub document for master plan analytics under the current master plan and execute plan after creating the proper document in notion and connect all sub tasks in linear"*

And then added:

> *"also add to analytics skills CSV checkup to make sure that what is written and should appear in the csv is indeed part of the doc so no debt is created like we have right now"*

**Six deliverables in scope:**

1. Spec doc as sub-document of the master plan
2. Skill enhancement: GA4 MCP connectivity check (new `/analytics validate` capability)
3. Skill enhancement: CSV-completeness gate (mechanical, pre-commit)
4. Skill enhancement: live event debugger (local mirror + remote GA4 Realtime poll)
5. Dashboard build (operator route + Looker template)
6. Notion sub-page + Linear epic + child issues
7. Execute after the docs land

---

## §4 Brainstorm Output (the 4 decisions locked)

The brainstorm walked the `superpowers:brainstorming` skill protocol. Decisions captured via `AskUserQuestion`:

### §4.1 Live debugger surface

**Decision:** "Both — local mirror + GA4 Realtime poll" (1 of 4 options shown)

**Rationale:** Two complementary tools. Local mirror for dev iteration (websocket sink + `/analytics watch` CLI tails events while iOS Simulator or local Next.js dev server runs); GA4 Realtime poll via MCP for staging/prod observation against any deployed build firing into the prod GA4 property. Covers every lifecycle stage.

### §4.2 Dashboard surface

**Decision:** "Both — control-room route + Looker Studio template" (1 of 4 options shown)

**Rationale:** Control-room route for operator workflow (live tile KPIs, fed by GA4 MCP at request time, basic-auth/passkey-gated like rest of control-room); Looker Studio template for deep-dive ad-hoc exploration. Belt-and-braces. Reuses existing `gate-coverage-aggregator.ts` + passkey-auth + control-room layout.

### §4.3 Active feature handling (initial brainstorm — superseded by §6.1)

**Initial decision:** "Park 3D framework, make analytics the new active feature"

This was answered before the operator knew that PR #329 (3D PRD draft) had merged earlier the same day. The decision was honored but at a NEW natural waypoint (PRD authored, awaiting Phase 2 approval) rather than mid-research.

### §4.4 CSV checkup gate (added mid-brainstorm)

**Decision:** "Yes — add to `/analytics validate` as mechanical gate"

**Rationale:** Operator surfaced this after seeing the audit's 56-row CSV drift. The drift wouldn't have happened if `/analytics validate` ran on every commit. New write-time gate `CSV_TAXONOMY_DRIFT` (Phase 1.B) prevents recurrence.

---

## §5 Overlay Against Infra Master Plan

After the brainstorm proposed Approach B (phased single feature), the operator asked for an overlay against [`infra-master-plan-2026-05-12.md`](infra-master-plan-2026-05-12.md). Findings:

### §5.1 Five hard conflicts identified

1. **Phase E freeze conflict.** §3.6.2 forbids new gates 2026-05-21 → 06-04. The proposed Phase 1 shipped gates during that window. **Resolution:** split Phase 1 into 1.A (hygiene, non-gate) + 1.B (gates, post Phase E).
2. **22-day Calibration Protocol.** §3.5 mandates A → B → C → D → E minimum 22 days for every new gate. Original proposal said T+7d. **Resolution:** extend to 22 days for Phase 1.B gates.
3. **Layer Stacking Rule.** §3.5.2 forbids new layers on un-validated foundations. CSV/MCP gates piggyback on Mechanism A, which hits Phase E only 2026-06-04. **Resolution:** earliest Phase 1.B start = 2026-06-04.
4. **v7.8.5 patch competition (now resolved).** v7.8.5 cache_hits keying remediation was on the 2026-05-13/14 critical path. **Resolution:** waited for v7.8.5 (PR #320, shipped 2026-05-12) + v7.8.5.1 (PR #331, shipped 2026-05-13) before starting analytics work.
5. **Active feature collision.** v7.8.5 + HADF Phase 2-bis Sub-exp 1 (2026-05-23) + 3D Framework PRD all in flight. **Resolution:** sequential ordering — v7.8.5.1 first, analytics-observability second, 3D parked, HADF Sub-exp 1 runs in parallel (research track, low contention with Python ops).

### §5.2 Five overlaps (where analytics work consumes / extends master plan items)

1. **F14 + F16 test infrastructure.** CSV/MCP gate dispatch tests ride on F16 try-repo harness (v7.9.1 target). Phase 1.B gates become **F19 and F20** in the v7.9 candidates spec.
2. **Mechanism A coverage gates.** New gates emit `{candidates, checked, skipped, skip_reasons}` per existing pattern. No new mechanism needed.
3. **Cross-repo gate asymmetry (v7.8.2).** Mechanism A telemetry is FT2-only; CSV-completeness gate runs in FT2, scans both repos' enums. Matches documented exemption.
4. **Existing control-room aggregator.** `src/lib/control-room/gate-coverage-aggregator.ts` already reads both repos' streams. `/control-room/analytics` route adds one route + one MCP integration.
5. **Linear epic numbering drift.** Master plan §9 says FIT-72 to be created 2026-05-21; memory shows FIT-72→77 + FIT-78→137 already exist (created 2026-05-12). New analytics epic = ~FIT-138+. Trust Linear MCP at issue-creation time.

### §5.3 Four patterns inherited from master plan

1. **Reversibility contract** (§3.5.4): every new gate ships with advisory rollback <2 min, enforced rollback <5 min, rehearsed at Phase D.
2. **Quarterly Data Freshness Audit** (§3.5.3): auto-enroll new gates at next quarterly cycle (2026-08-12).
3. **Q7 dependency** (master plan Open Q #7): if `GATE_SPEC_INCOMPLETE` lands at v7.9.1, Phase 1.B gates must produce Phase A artifacts (spec + fixture + dispatch test) pre-merge.
4. **Risk register additions:** GA4 MCP setup failure, local mirror websocket port collision, Looker Studio OAuth (operator-bound), CSV ownership disputes (resolved via §6.2 below).

---

## §6 Locked Operator Decisions (the 4 Qs)

### §6.1 Q1 — Sequencing — **APPROVED revised 3-window plan**

| Window | Phase | Effort | What ships | Gates? |
|---|---|---|---|---|
| 2026-05-15 → 22 | 1.A Hygiene | ~6h | CSV backfill (56 missing rows), wire 4 unfired events, 21 iOS tests, fitme-story `.env.example`, fix 2 unwired web events | None |
| 2026-05-15 → 22 | 2 Live Debugger | ~8h | Local mirror sink + `/analytics watch` CLI; GA4 Realtime poll via MCP | None |
| 2026-05-21 → 06-04 | 3 Dashboards | ~10h | `/control-room/analytics` route + Looker Studio template | None |
| 2026-06-04 → 06-26 | 1.B Gates | ~6h | `CSV_TAXONOMY_DRIFT` + `GA4_MCP_DISCONNECTED` via 22d A→E Calibration Protocol; ride on F16 harness | 2 new advisory → enforced |

### §6.2 Q2 — CSV ownership — **APPROVED single canonical CSV in FT2**

The CSV at [`docs/product/analytics-taxonomy.csv`](../product/analytics-taxonomy.csv) stays canonical in FT2. The v7.8.3 D-1 reverse-sync GitHub Action extends to mirror this file to fitme-story (forward sync since state_owner == "ft2" for the CSV). Web events (dashboard_*, design_system_*) get rows in the FT2 CSV under appropriate categories. Mechanism A telemetry stays FT2-only per v7.8.2 cross-repo asymmetry policy.

### §6.3 Q3 — Wait for v7.8.5 — **APPROVED + RESOLVED**

v7.8.5 shipped via PR #320 (commit `0af007d`, merged 2026-05-12 18:43Z). v7.8.5.1 (PR #331, this session's residual test fixture rot fix) shipped at commit `8f34d76`, merged 2026-05-13 15:01Z. **Test baseline is clean (133/133 passing).** Analytics work begins on a clean baseline.

### §6.4 Q4 — Infra-plan fold-in — **APPROVED Option A**

Analytics-observability becomes a true sub-document of the infra master plan. New §3.6.X in the infra plan links to the analytics master plan. Phase 1.B candidates F19 + F20 added to the v8.0 docket (§3.6.4). Single forward-looking roadmap; no parallel-track confusion.

### §6.5 3D Framework Universe — **PARK (3D-A)**

State.json at [`/.claude/features/3d-interactive-framework-flow-diagram/state.json`](../../.claude/features/3d-interactive-framework-flow-diagram/state.json) updated this session:
- `paused: true`
- `paused_at: "2026-05-13T15:30:00Z"`
- `paused_reason` (verbatim): "Deliberate park at Phase 1 PRD natural waypoint (PRD authored, awaiting approval). Operator decision 2026-05-13: ship analytics-observability feature first to clear measurement debt (56 missing CSV rows + 4 unfired events + GA4 MCP disconnected) before 2026-05-21 v7.9 promotion decision."
- `scheduled_after.signal: "analytics-observability phase=complete"`

The 3D PRD remains authored at `.claude/features/3d-interactive-framework-flow-diagram/prd.md` (600 lines, shipped via PR #329). Phase 2 (Tasks) gate is not approved; auto-resumes when analytics-observability ships.

**Cross-repo TODO:** the canonical 3D state.json lives in fitme-story (state_owner). A companion fitme-story PR needs to mirror these pause fields to fitme-story's `.claude/features/3d-interactive-framework-flow-diagram/state.json`. Tracked as a follow-up — see §9.

---

## §7 PR History This Session

| PR | Repo | Status | Purpose |
|---|---|---|---|
| #320 | FT2 | Merged 2026-05-12 18:43Z | v7.8.5 cache_hits keying remediation (3 cases diagnosed; case 2 = fixture rot only) |
| #321 | FT2 | Merged 2026-05-12 18:44Z | v7.8.5 → v8.2 implementation plan doc |
| #329 | FT2 | Merged 2026-05-13 (today, before analytics session began) | 3D Framework Universe Phase 0 → Phase 1 PRD draft (600 lines) |
| #101 | fitme-story | Merged 2026-05-13 14:03Z | Mirror of #329 state.json for fitme-story canonical |
| #331 | FT2 | Merged 2026-05-13 15:01Z | v7.8.5.1 residual test fixture rot — 4 failing tests fixed (PR #320 caught test_gate_coverage; PR #331 catches test_check_state_schema + test_validate_tier_tags) |

---

## §8 Calendar Constraints (the dates that bound everything)

| Date | Event | Analytics-relevance |
|---|---|---|
| 2026-05-13 (today) | Brainstorm + park 3D + start analytics PRD | — |
| 2026-05-15 → 22 | Phase 1.A hygiene + Phase 2 live debugger ship window | Primary execution window |
| 2026-05-18 | v7.9 promotion window opens | Phase 1.A should be merged by here for clean signal |
| 2026-05-21 | **v7.9 PROMOTION DECISION** + T29 v8.0 docket ranking | Adds F19/F20 candidates to docket |
| 2026-05-21 → 06-04 | v7.9 Phase E (no new gates ship) | Phase 3 dashboards ship here (non-gate work) |
| 2026-05-22 | External Audit #1 (per memory) | Analytics work should be coherent enough to discuss |
| 2026-05-23 | HADF Phase 2-bis Sub-exp 1 launches | Parallel research track; minimal contention |
| ~2026-05-30 | HADF Sub-exp 2 verdict | — |
| ~2026-06-03 | HADF Sub-exp 3 verdict | — |
| 2026-06-04 | v7.9 Phase E exit + v7.9.1 build window opens | Phase 1.B gates begin advisory ship |
| ~2026-06-11 | F16 try-repo harness ships (v7.9.1) | Phase 1.B test infrastructure depends on F16 |
| 2026-06-25 | Phase 1.B enforced (earliest, per 22d Calibration Protocol) | — |
| 2026-06-26 | analytics-observability `current_phase: complete` target | Triggers 3D Framework Universe auto-resume |
| 2026-08-12 | First Data Freshness Audit (T+90d) | New F19/F20 gates auto-enroll |

---

## §9 Cross-Repo Sync Follow-up

Modified this session in FT2:
- `.claude/features/3d-interactive-framework-flow-diagram/state.json` (FT2 mirror)
- `.claude/features/analytics-observability/state.json` (FT2 canonical — new)
- `.claude/active-feature` (FT2 only — not synced)
- `.claude/logs/analytics-observability.log.json` (FT2 canonical — new)

**Sync needed:**
- fitme-story `state.json` for 3D Framework Universe MUST receive the same `paused: true` + `paused_reason` + `scheduled_after` fields. Either (a) D-1 reverse-sync GitHub Action auto-propagates when this PR merges to FT2 main, OR (b) operator opens a companion fitme-story PR. Verify which after PR merge.

---

## §10 Resume Protocol (the critical contingency)

If you are resuming this work and the agent memory is stale or another agent inherits the work:

1. **Read this entire document first.** Then read the spec at [`analytics-master-plan-2026-05-13.md`](analytics-master-plan-2026-05-13.md).
2. **Check feature state:** `cat .claude/features/analytics-observability/state.json | jq '.current_phase, .paused'`. If `paused: true`, read `paused_reason`.
3. **Check log:** `cat .claude/logs/analytics-observability.log.json | jq '.events[-1]'` to see last event.
4. **Check parent infra plan:** [`infra-master-plan-2026-05-12.md`](infra-master-plan-2026-05-12.md) §3.6.X (added by this work) for current v7.9.1/v8.0 docket inclusion status.
5. **Check 3D feature:** `cat .claude/features/3d-interactive-framework-flow-diagram/state.json | jq '.paused, .scheduled_after'`. If still paused, analytics is ongoing; if `paused: false` or absent, analytics shipped and 3D resumed.
6. **Check Linear epic** for analytics-observability (likely ~FIT-138+). Status of child issues indicates progress.
7. **Check Notion sub-page** under FitMe Product Hub.
8. **Run `make integrity-check`** to see if any new gate drift accumulated since.
9. **Run `pytest scripts/tests/`** — must be 133+ passing (regression check on v7.8.5.1 baseline).

If resuming mid-Phase 1.A: pick up from highest-numbered uncompleted task in `state.json.tasks[]`.
If resuming mid-Phase 1.B: check calibration window status; do NOT promote to enforced until Phase C exit criteria met (≥N=5 gate fires, 0 false positives across 7d).

---

## §11 Anti-Patterns the Operator Has Pushed Back On (Honesty Ledger Entries to Preserve)

Codified during the brainstorm + overlay:

- **Don't ship gates during Phase E.** Phase E is "no new gates" by design — violating it would re-introduce the v7.8.5-class silent-pass risk.
- **Don't violate the 22-day Calibration Protocol.** "Just one fast advisory → enforced in T+7d" is the same shortcut that produced the cache_hits keying drift.
- **Don't run multiple `.claude/active-feature` tracks in parallel.** Mechanism C session attribution is single-valued; ambiguous attribution = silent telemetry drift.
- **Don't trust the master plan docs over current state.** §2.4 of the infra master plan said v7.8.5 was a future target; it had already shipped. Always re-verify dates against `git log` before acting.

---

## §12 Document Provenance

- **Conversation transcript:** Claude Code session 2026-05-13 (Opus 4.7 1M context)
- **Audit method:** `/analytics validate` skill invocation; iOS enum parse; CSV parse; pytest scripts/tests/; fitme-story call-site grep
- **Brainstorm method:** `superpowers:brainstorming` skill (paused mid-flow, resumed; 5 user questions answered)
- **Overlay method:** Read [`infra-master-plan-2026-05-12.md`](infra-master-plan-2026-05-12.md) full + cross-reference manually
- **Memory artifacts referenced (transient, may rot):**
  - `/Users/regevbarak/.claude/projects/-Volumes-DevSSD-FitTracker2/memory/MEMORY.md`
  - `/Users/regevbarak/.claude/projects/-Volumes-DevSSD-FitTracker2/memory/project_session_2026_05_13_analytics_audit_paused.md`
- **Durable artifacts (this document + companions):**
  - This file (locked decisions, full audit baseline, resume protocol)
  - [`analytics-master-plan-2026-05-13.md`](analytics-master-plan-2026-05-13.md) (spec/PRD)
  - [`.claude/features/analytics-observability/state.json`](../../.claude/features/analytics-observability/state.json) (canonical feature state)
  - [`.claude/logs/analytics-observability.log.json`](../../.claude/logs/analytics-observability.log.json) (contemporaneous event log)

---

## §13 Post-iOS-firehose follow-ups (added 2026-05-17, gated to v7.9.1)

**Context:** FT2 PR [#388](https://github.com/Regevba/FitTracker2/pull/388) (2026-05-17) closed FIT-142 by lighting up the iOS firehose to GA4. Root cause: `GoogleService-Info.plist` was on disk but missing from the FitTracker target's Copy Bundle Resources phase. iOS analytics had been dark since project inception; events now verified streaming via Firebase DebugView. See: `memory/project_session_2026_05_17_ga4_binding_resolved_ios_dark.md`, FIT-142 closure comment `f42751ed-24cc-4e59-95ba-15683a19874b`.

3 follow-up items surfaced during the closure. **All deferred to the v7.9.1 window (earliest 2026-06-04)** per [`infra-master-plan-2026-05-12.md`](infra-master-plan-2026-05-12.md) §3.6.3 cadence — none are gate-additive at the framework layer, but D-2 (conversion config) and D-3 (screen-view tracking) change GA4 data shape and must respect the §7.5 yellow window.

### §13.1 Items

| ID | Effort | Calibration class (analytics MP §7.5) | Earliest start | Primary home |
|---|---|---|---|---|
| **D-2** Configure GA4 conversions (`workout_complete` + `nutrition_meal_logged`) | 5 min | 🟡 yellow | 2026-06-04 | Infra MP §3.6.3 v7.9.1 row |
| **D-3** Wire `AnalyticsScreenModifier` to 5 main tabs (Home / Training / Stats / Nutrition / Settings) | 1-2h | 🟡 yellow | 2026-06-04 | Analytics MP §5.6 (new) + V8 docket F21 |
| **D-4** Delete old `com.regevba.FitTracker` Firebase iOS app entry | 1 min | 🟢 green | 2026-06-04 | Infra MP §3.6.3 v7.9.1 row |

### §13.2 Why deferred (not done in PR #388)

PR #388 had to land **before** the v7.9 promotion calibration window closes (2026-05-21 decision per infra §2.2). Any work in #388 that changed gate behavior or GA4 data shape would have polluted the calibration data. The strict scope of #388 was:

1. ✅ Add plist to target (one-time fix; restores never-working state — no telemetry impact since the state was broken)
2. ✅ Add `Analytics.setAnalyticsCollectionEnabled(true)` override (defensive; doesn't alter what events fire)
3. ✅ Document Path 4 in `ga4-access-binding-setup-guide.md` (operational guidance; no code)
4. ✅ Refresh `external-sync-status.json` + Tier 2.2 log (telemetry-truth restoration)

D-2 / D-3 / D-4 deliberately excluded because they:

- **D-2**: Changes the shape of GA4 conversion data → step-change in `mcp__ga4__runReport` with `isConversionEvent` mid-calibration
- **D-3**: Adds new explicit `screen_view` events that override Firebase's auto-collection signal → screen-class distribution shift mid-calibration
- **D-4**: Pure cleanup, would be safe to do now, but kept with D-2 / D-3 to amortize operator cost (one Firebase Console visit)

### §13.3 Sequence post-v7.9 ship (2026-06-04+)

Recommended order (lowest-friction first):

1. **D-4 first** (1 min, GREEN) — operator opens Firebase Console anyway for D-2; while there, click Remove on the orphan
2. **D-2 next** (5 min, YELLOW) — toggle conversions in GA4 → wait 30 min → run `mcp__ga4__runReport` with `isConversionEvent` dimension to verify the flip
3. **D-3 last** (1-2h, YELLOW) — wire `AnalyticsScreenModifier` to 5 tabs in iOS code; pair with screen-prefix funnel validation in `/analytics validate` skill

If v7.9 promotion is deferred past 2026-05-21 (rare but possible per infra §2.2 criteria), this entire block waits until v7.9 actually ships. The earliest-start dates in `state.json` are tied to `blocked_until: "v7.9 ships"`, not the calendar 2026-06-04.

### §13.4 Cross-references

- [`.claude/features/analytics-observability/state.json`](../../.claude/features/analytics-observability/state.json) tasks D-2, D-3, D-4 (status `deferred`)
- [`docs/master-plan/infra-master-plan-2026-05-12.md`](infra-master-plan-2026-05-12.md) §3.6.3 v7.9.1 cadence (D-2 + D-4 rows added)
- [`docs/master-plan/analytics-master-plan-2026-05-13.md`](analytics-master-plan-2026-05-13.md) §5.6 (D-3 detailed spec — to be added)
- v8 docket: **F21 = D-3** (analytics-observability state.json `v8_docket_candidates`)
- FIT-142 closure: Linear comment `f42751ed-24cc-4e59-95ba-15683a19874b`
- PR [#388](https://github.com/Regevba/FitTracker2/pull/388)
