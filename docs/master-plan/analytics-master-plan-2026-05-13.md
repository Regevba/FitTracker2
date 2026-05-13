# Analytics Observability — Master Plan (Sub-doc of Infra Master Plan)

**Status:** Phase 1 PRD draft · awaiting operator approval
**Created:** 2026-05-13
**Parent:** [`infra-master-plan-2026-05-12.md`](infra-master-plan-2026-05-12.md) §3.6.X
**Decisions log:** [`analytics-observability-decisions-log-2026-05-13.md`](analytics-observability-decisions-log-2026-05-13.md) (read first if resuming)
**State.json:** [`/.claude/features/analytics-observability/state.json`](../../.claude/features/analytics-observability/state.json)
**Log:** [`/.claude/logs/analytics-observability.log.json`](../../.claude/logs/analytics-observability.log.json)
**State_owner:** `ft2` · **Framework version:** `v7.8.5` · **Work type:** Feature

---

## §1 TL;DR

A 3-phase, 4-window analytics framework upgrade that closes 56-row CSV drift + 4 unfired iOS events + 21 untested events + disconnected GA4 MCP + 2 unwired web events, then adds a live event debugger and operator dashboards. Phase 1.A (hygiene) + Phase 2 (debugger) ship next week as non-gate work; Phase 3 (dashboards) ships during v7.9 Phase E; Phase 1.B (gates) ships via 22-day Calibration Protocol post-Phase-E.

| Phase | Window | Effort | Gate-additive? | Surface |
|---|---|---|---|---|
| 1.A Hygiene | 2026-05-15 → 22 | 6h | No | Backfill + wire + test |
| 2 Live debugger | 2026-05-15 → 22 (parallel 1.A) | 8h | No | Local mirror + `/analytics watch` + GA4 Realtime poll |
| 3 Dashboards | 2026-05-21 → 06-04 (parallel v7.9 Phase E) | 10h | No | `/control-room/analytics` + Looker template |
| 1.B Gates | 2026-06-04 → 06-26 | 6h | **Yes** (2 new) | `CSV_TAXONOMY_DRIFT` + `GA4_MCP_DISCONNECTED` |

**Total effort:** ~30 hours over 6 weeks. **Total ship:** 2026-06-26.

---

## §2 Background & Motivation

[Audit findings preserved in companion decisions-log §2.](analytics-observability-decisions-log-2026-05-13.md#2-audit-findings-the-empirical-baseline). Headlines:

- iOS: **114 events declared**, only 58 in CSV (**56 missing rows**); 4 events declared but never fired; 21 events untested.
- Web (fitme-story): 12/14 events wired (2 declared but unwired); no `.env.example` for `NEXT_PUBLIC_GA_ID`.
- GA4 MCP: **defined but disconnected** — cannot mechanically verify firing.
- Existing `/analytics validate` skill knew how to detect taxonomy drift but only ran as a manual sub-command, not a gate.

**Trigger event:** Operator audit 2026-05-13 surfaced the drift. Without a gate, drift accumulates every time a new feature adds events. Phase 1.B exists to prevent recurrence.

---

## §3 Approach

**Approach B (phased single feature)** — one feature, one Linear epic, one Notion page, three sequential phases each merging independently. Rejected alternatives:

- **Approach A (monolithic)** — one big-bang PR. ✗ Long time-to-value, hard to review.
- **Approach C (three separate features)** — 3× PM-workflow ceremony for one workstream. ✗ Excessive overhead.

---

## §4 Architecture

```
iOS app (FirebaseAnalytics)              fitme-story (web, @next/third-parties/google)
      │                                            │
      │ DEBUG_ANALYTICS=1 only                     │ NEXT_PUBLIC_DEBUG_ANALYTICS=1 only
      ▼                                            ▼
   ┌──────────────────────────────────────────────────┐
   │  Local Mirror Sink  (ws://localhost:8765/events) │  ← Phase 2 (local-mirror tee)
   │  Tees events; production path still goes to GA4. │
   └──────┬───────────────────────────────────────────┘
          │
          ▼
   /analytics watch  ← CLI tails the websocket (dev iteration)
   /analytics poll   ← GA4 Realtime API via mcp-server-ga4 (staging/prod observation)

   ┌──────────────────────────────────────────────────┐
   │  /analytics validate  (Phase 1.A + Phase 1.B)    │
   │  ─ enum ↔ CSV cross-reference                    │
   │  ─ screen-prefix compliance                      │
   │  ─ test coverage                                 │
   │  ─ GA4 MCP connectivity check                    │
   │  ─ CSV completeness (Phase 1.B gate)             │
   └──────────────────────────────────────────────────┘

   Phase 3 dashboards:
   ┌──────────────────────────────────────────────────┐
   │ fitme-story /control-room/analytics              │  ← live, MCP-fed, passkey-gated
   │   ─ event firing rate tiles                      │
   │   ─ funnel completion graphs                     │
   │   ─ taxonomy compliance summary                  │
   └──────────────────────────────────────────────────┘
   ┌──────────────────────────────────────────────────┐
   │ docs/analytics/looker-studio-template.json       │  ← deep-dive ad-hoc exploration
   │   Operator imports into Looker workspace once.   │
   └──────────────────────────────────────────────────┘
```

**Key design constraints:**

- Local mirror is **off by default**; activates only when `DEBUG_ANALYTICS=1` (iOS scheme env var) or `NEXT_PUBLIC_DEBUG_ANALYTICS=1` (web). No production overhead, no PII risk.
- The mirror is a **passive duplicate** — events still go to Firebase/GA4 as today.
- Phase 1.B gates ship **advisory first**, walk 22-day A → B → C → D → E protocol before enforcement.
- `/control-room/analytics` reuses existing UCC passkey auth (`ucc-passkey-auth` shipped 2026-05-07).
- Looker Studio template is an operator-imported JSON; no runtime infra cost.

---

## §5 Phase 1.A — Hygiene (window 2026-05-15 → 22, ~6h, non-gate)

### §5.1 Tasks

| ID | Task | Effort | Owner | Verification |
|---|---|---|---|---|
| 1.A.1 | Backfill 56 missing CSV rows from iOS enum (auto-generate from AnalyticsProvider.swift) | 2h | dev | `python3 scripts/cross-reference-analytics-enum-csv.py` reports 0 missing |
| 1.A.2 | Add 7 missing screens + 1 user property to CSV | 30m | dev | grep check |
| 1.A.3 | Wire iOS `ai_recommendation_accepted` + `ai_recommendation_dismissed` to the thumbs-up/down handler (or delete if not wanted) | 30m | dev | grep `AnalyticsEvent.aiRecommendationAccepted` shows ≥1 production call site |
| 1.A.4 | Wire fitme-story `design_system_component_expand` + `design_system_code_copy` (or delete) | 30m | dev | call-site grep |
| 1.A.5 | Add tests for 21 untested iOS events (per-domain test files) | 2h | dev | `pytest` → coverage 100% |
| 1.A.6 | Add fitme-story `.env.example` with `NEXT_PUBLIC_GA_ID=G-xxxxxxx` placeholder | 5m | dev | file present |
| 1.A.7 | Refresh stale `.claude/shared/external-sync-status.json` analytics block | 15m | dev | `updated` field is today |

### §5.2 Success criteria

- `python3 scripts/cross-reference-analytics-enum-csv.py` exits 0 with "0 missing rows"
- `pytest FitTrackerTests/` analytics test coverage = 100% (114/114)
- No production code references `AnalyticsEvent.aiRecommendation*` that aren't actually firing
- `external-sync-status.json::analytics.instrumented_percentage` recomputed and current

### §5.3 Tests added (Phase 1.A)

- 21 new iOS analytics tests, one per untested event, in matching `*AnalyticsTests.swift` files
- 1 fitme-story unit test for `design_system_component_expand` call site (once wired)
- 1 fitme-story unit test for `design_system_code_copy` call site (once wired)

---

## §6 Phase 2 — Live Debugger (window 2026-05-15 → 22, ~8h, non-gate, parallel with Phase 1.A)

### §6.1 Sub-system A: Local mirror sink

**Architecture:** websocket server on `localhost:8765`. iOS DebugSinkAdapter (when `DEBUG_ANALYTICS=1`) tees every `logEvent` payload to the websocket; web mirror function (when `NEXT_PUBLIC_DEBUG_ANALYTICS=1`) tees every `sendGAEvent`.

**Files:**
- New: `scripts/analytics-watch-server.py` (websocket server, optional `--port`, `--no-color`, `--filter` args)
- New: `FitTracker/Services/Analytics/DebugSinkAdapter.swift` (wraps existing FirebaseAnalyticsAdapter; tees events when env flag set)
- New: `fitme-story/src/lib/analytics-debug-mirror.ts` (wraps `sendGAEvent`; tees when env flag set)

**`/analytics watch` CLI:** new sub-command added to `.claude/skills/analytics/SKILL.md`. Connects to `ws://localhost:8765/events`, prints each event as it arrives with timestamp + event name + parameters. Supports `--filter <name>` and `--funnel <step1,step2,...>`.

### §6.2 Sub-system B: GA4 Realtime poll

**Architecture:** new sub-command `/analytics poll` queries GA4 Realtime API via `mcp-server-ga4`. Polls every 30 seconds (configurable). Prints active event counts.

**Files:**
- New: `.claude/skills/analytics/SKILL.md` adds `/analytics poll` sub-command
- Update: `.claude/integrations/ga4/adapter.md` adds "Realtime poll" mode (currently only describes `run_report`)
- Operator: connect GA4 MCP (one-time): export `GA4_PROPERTY_ID`, install `mcp-server-ga4`, configure `GOOGLE_APPLICATION_CREDENTIALS`. Operator runbook in `docs/setup/ga4-mcp-setup-guide.md` (new).

### §6.3 Success criteria

- Run `python3 scripts/analytics-watch-server.py &`; launch iOS app with `DEBUG_ANALYTICS=1` scheme; fire test event; see event in CLI within 100ms.
- Run `/analytics poll` against connected GA4 MCP; see event counts within 30s of firing.

### §6.4 Tests added (Phase 2)

- `scripts/tests/test_analytics_watch_server.py` — 5 tests (connect/disconnect, filter, malformed payload, port collision detection)
- `FitTrackerTests/DebugSinkAdapterTests.swift` — 3 tests (no-op without env flag, tees when flag set, fails open on websocket disconnect)
- fitme-story `src/lib/__tests__/analytics-debug-mirror.test.ts` — 3 tests (same shape as iOS)

---

## §7 Phase 3 — Dashboards (window 2026-05-21 → 06-04, ~10h, non-gate, parallel with v7.9 Phase E monitoring)

### §7.1 Sub-system A: `/control-room/analytics` route (fitme-story)

**Architecture:** new Next.js App Router route. Server component fetches GA4 data via MCP at request time; client islands render tiles. Reuses existing passkey auth + control-room layout.

**Cache strategy** (per `next-cache-components` skill):
- Static shell: header + navigation (auto-prerendered)
- Cached: 5-minute event firing rate tiles (`use cache; cacheLife('minutes')`)
- Dynamic: live "last 10 events" stream (Suspense + Streaming)

**Files:**
- New: `fitme-story/src/app/control-room/analytics/page.tsx`
- New: `fitme-story/src/components/control-room/AnalyticsTiles.tsx`
- New: `fitme-story/src/components/control-room/EventFiringRateChart.tsx`
- New: `fitme-story/src/components/control-room/TaxonomyComplianceSummary.tsx`
- New: `fitme-story/src/lib/control-room/ga4-mcp-client.ts` (wraps mcp-server-ga4 read calls)

**Optional (deferred to v8.x):** Workflow DevKit for long-running funnel re-aggregation jobs. Phase 3 ships with simpler poll-based data; Workflow integration in v8.0 if usage demands it.

### §7.2 Sub-system B: Looker Studio template

**Files:**
- New: `docs/analytics/looker-studio-template.json` — exportable Looker dashboard definition
- New: `docs/analytics/looker-studio-template.md` — operator import guide (1 page)
- Defines: funnel exploration, event-name distribution, cohort retention, conversion-event tracking

### §7.3 Success criteria

- Operator authenticates to `/control-room/analytics` via passkey
- Page loads in <3s including GA4 MCP roundtrip
- Tiles update on F5 refresh
- Looker template imports cleanly into a fresh Looker workspace; charts populate from GA4

### §7.4 Tests added (Phase 3)

- `fitme-story/src/lib/control-room/__tests__/ga4-mcp-client.test.ts` — 5 tests (response shape, error fallback, retry, cache hit)
- Vercel verification skill protocol: open route in browser, verify GA4 round-trip end-to-end

---

## §8 Phase 1.B — Gates (window 2026-06-04 → 06-26, ~6h, **2 new gates**)

### §8.1 Calibration Protocol mapping (per infra plan §3.5)

| Date | Phase | Activity |
|---|---|---|
| 2026-06-04 | A → B transition | Ship advisory; both gates emit `gate-coverage.jsonl` rows |
| 2026-06-04 → 06-11 | B (advisory + measure) | ≥7 days telemetry collection; operator T+3d checkpoint on 2026-06-07 |
| 2026-06-11 → 06-18 | C (calibration gate) | ≥N=5 fires per gate; 0 false positives confirmed by operator review; all skip reasons documented |
| 2026-06-18 | D (promotion decision) | Flip to enforced OR stay advisory; rollback path rehearsed |
| 2026-06-18 → 06-25 | E (post-promotion validation) | Continuous monitoring; rollback if false positive incident |
| 2026-06-26 | analytics-observability `current_phase: complete` | Triggers 3D Framework Universe auto-resume |

### §8.2 Gate 1: `CSV_TAXONOMY_DRIFT`

**Fires:** pre-commit, when staged files include `FitTracker/Services/Analytics/AnalyticsProvider.swift` modifications.

**Rule:** every event constant added to the `AnalyticsEvent` enum must have a corresponding row in [`docs/product/analytics-taxonomy.csv`](../product/analytics-taxonomy.csv) within the same commit (or a documented exemption tag).

**Exemption:** state.json `csv_taxonomy_exempt: [{constant: "name", reason: "..."}]` array on feature state.json bypasses for justified cases (e.g., a constant temporarily defined during a refactor).

**Files:**
- Update: `scripts/check-state-schema.py` adds `check_csv_taxonomy_drift()` function emitting `coverage.candidate("CSV_TAXONOMY_DRIFT")`
- Update: `.githooks/pre-commit` header bumped to mention new gate
- New: `scripts/tests/test_csv_taxonomy_drift.py` (positive + negative fixtures + dispatch test per F14 pattern)

**Reversibility contract:**
- Advisory rollback: <2 min (set function early-return)
- Enforced rollback: <5 min (single-line flag flip + hook header bump)
- Rehearsed at Phase D before flip

### §8.3 Gate 2: `GA4_MCP_DISCONNECTED`

**Fires:** pre-commit, when staged files include analytics-affecting code (`FitTracker/Services/Analytics/*` OR `fitme-story/src/lib/control-room/analytics.ts` OR taxonomy CSV).

**Rule:** check that GA4 MCP is reachable via env vars (`GA4_PROPERTY_ID` set + `GOOGLE_APPLICATION_CREDENTIALS` file exists). If disconnected, advisory finding (not blocking).

**Note:** advisory only — never blocks commits, even when promoted to "enforced" status. The gate exists to surface drift, not to gate analytics work behind operator GA4 setup. Promoted means it emits a clear finding visible in `make integrity-check`, not that it returns non-zero exit.

**Files:**
- Update: `scripts/check-state-schema.py` adds `check_ga4_mcp_connectivity()` function
- Update: `.githooks/pre-commit` header bumped
- New: `scripts/tests/test_ga4_mcp_disconnected.py`

### §8.4 Phase A artifacts (pre-merge requirements per §3.5.1)

For both gates, before merging Phase 1.B PR:

- [ ] Gate spec section in this doc (§8.2 + §8.3) — ✅ written
- [ ] 1 positive fixture per gate (`tests/fixtures/gate-fixtures/CSV_TAXONOMY_DRIFT/positive/`)
- [ ] 1 negative fixture per gate (`tests/fixtures/gate-fixtures/CSV_TAXONOMY_DRIFT/negative/`)
- [ ] Dispatch regression test: asserts `coverage.candidate(GATE)` fires under expected input partition

These ride on F16 try-repo harness when it ships v7.9.1 (~2026-06-11). Phase 1.B fixture authoring CAN start before F16 ships; harness integration finalizes after.

---

## §9 Success Metrics

| Metric | Baseline (2026-05-13) | Phase 1.A target | Phase 1.B target | Source |
|---|---|---|---|---|
| **PRIMARY:** CSV taxonomy drift (missing rows) | 56 | 0 | 0 (gated) | `cross-reference-analytics-enum-csv.py` |
| iOS event test coverage | 81% (93/114) | 100% (114/114) | 100% (gated) | `pytest FitTrackerTests/` |
| Declared-but-unfired iOS events | 4 | 0 | 0 | `grep AnalyticsEvent.X across FitTracker/` |
| Declared-but-unwired web events | 2 | 0 | 0 | call-site grep |
| GA4 MCP connectivity | disconnected | (Phase 2: operator setup) | connected | `gh api ... GA4_PROPERTY_ID secret` |
| `external-sync-status.json::analytics.instrumented_percentage` | 35% (stale) | recomputed | ≥80% | `make analytics-instrumentation-summary` |

### §9.1 Kill criteria

**Phase 1.B kill condition:** if either gate produces >5% false positive rate during 7-day Phase C calibration window (2026-06-11 → 06-18), defer enforcement to v7.10. analytics-observability still ships as "Phase 1.A + 2 + 3 complete; gates advisory permanent".

**Phase 2 kill condition:** if local mirror sink causes any production crash, performance regression, or PII leak in 7-day soak post-merge, revert immediately and ship Phase 2 as "GA4 Realtime poll only".

**Phase 3 kill condition:** if `/control-room/analytics` page load exceeds 5s P95, scope down to "tiles only" (no live event stream).

---

## §10 Risk Register (additions beyond infra master plan §7)

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| GA4 MCP setup failure (auth/propertyId/service account) | Medium | Medium | Operator runbook in `docs/setup/ga4-mcp-setup-guide.md` covers all 3 failure modes; advisory `GA4_MCP_DISCONNECTED` gate makes drift visible |
| Local mirror websocket port (8765) collision with dev tool | Low | Low | `--port` CLI arg; clear "port in use" error |
| Looker Studio template auth (operator OAuth) | Low | Low | Template instruction in MD; not automatable |
| CSV ownership dispute (FT2 vs fitme-story) | Resolved | — | §6.2 of decisions log: single canonical in FT2 + D-1 reverse-sync to fitme-story |
| Phase 1.B gate enforcement during Phase E freeze window | Resolved | — | Phase 1.B starts 2026-06-04 (after Phase E exit); enforcement at earliest 2026-06-18 |
| Phase 2 debugger leaks PII to local sink | Low | High | Mirror is OFF by default; activates only under `DEBUG_ANALYTICS=1` env flag; documented in dev guide |
| F16 try-repo harness slips past 2026-06-11 | Medium | Low | Phase 1.B fixtures can be authored without harness; integration deferred if F16 slips; gates ship advisory regardless |

---

## §11 v7.9 Candidate Mapping (F19 + F20)

These map into the infra master plan's v7.9 candidate spec at [`docs/superpowers/specs/2026-05-08-framework-v7-9-candidates.md`](../superpowers/specs/2026-05-08-framework-v7-9-candidates.md):

### F19 — `CSV_TAXONOMY_DRIFT` write-time gate

**Theme:** G (Test discipline)
**RICE-est:** R=10 I=2 C=80% E=0.2w → **80.0**
**Earliest start:** 2026-06-04 (Phase E exit)
**Dependencies:** F16 try-repo harness (recommended, not blocking)
**Spec:** §8.2 above

### F20 — `GA4_MCP_DISCONNECTED` advisory + coverage instrumentation

**Theme:** G (Test discipline) + new theme H (External integration awareness)
**RICE-est:** R=6 I=1 C=100% E=0.2w → **30.0**
**Earliest start:** 2026-06-04
**Dependencies:** Operator GA4 MCP setup (one-time, not blocking advisory ship)
**Spec:** §8.3 above

Both added to **§3.6.4 v8.0 docket — Theme G test discipline** in [`infra-master-plan-2026-05-12.md`](infra-master-plan-2026-05-12.md) via this PR.

---

## §12 Linear Mapping

**Parent epic:** to be created on Phase 1 PRD approval. Likely ~FIT-138+ (Linear MCP at issue-creation time; do not trust documentation for numbering).

**Proposed child issues (one per sub-track):**

| # | Title | Phase | Effort | Window |
|---|---|---|---|---|
| 1 | Phase 1.A.1-2 — CSV taxonomy backfill (56 rows + 7 screens + 1 user prop) | 1.A | 2.5h | 2026-05-15 → 17 |
| 2 | Phase 1.A.3 — Wire iOS ai_recommendation events | 1.A | 30m | 2026-05-18 |
| 3 | Phase 1.A.4 — Wire fitme-story design_system events | 1.A | 30m | 2026-05-18 |
| 4 | Phase 1.A.5 — Add 21 iOS analytics tests | 1.A | 2h | 2026-05-19 → 20 |
| 5 | Phase 1.A.6-7 — fitme-story .env.example + refresh sync status | 1.A | 20m | 2026-05-20 |
| 6 | Phase 2.A — Local mirror sink + DebugSinkAdapter (iOS) + web mirror + /analytics watch CLI | 2 | 5h | 2026-05-19 → 21 |
| 7 | Phase 2.B — GA4 Realtime poll via MCP + /analytics poll sub-command | 2 | 3h | 2026-05-22 |
| 8 | Phase 3.A — /control-room/analytics route + GA4-MCP-fed components | 3 | 6h | 2026-05-23 → 30 |
| 9 | Phase 3.B — Looker Studio template + operator import guide | 3 | 4h | 2026-05-29 → 06-04 |
| 10 | Phase 1.B.1 — CSV_TAXONOMY_DRIFT gate + Phase A artifacts | 1.B | 3h | 2026-06-04 → 06-07 |
| 11 | Phase 1.B.2 — GA4_MCP_DISCONNECTED gate + Phase A artifacts | 1.B | 2h | 2026-06-08 → 06-10 |
| 12 | Phase 1.B.3 — Calibration window monitoring (T+3d + T+7d checkpoints) | 1.B | 1h ops | 2026-06-11 → 06-18 |
| 13 | Phase 1.B.4 — Promotion decision + Phase E validation | 1.B | 1h ops | 2026-06-18 → 06-25 |

**Total child issues:** 13 (was 9 in initial brainstorm; expanded into per-task granularity for Phase 1.B observability).

---

## §13 Notion Mapping

**Page:** to be created under FitMe Product Hub on Phase 1 PRD approval.
**Title:** "Analytics Observability — Phase 1 PRD + Roadmap"
**Sections:** mirror this doc's table of contents at depth 2.
**Cross-links:** to Linear epic, to FT2 PR (this commit), to companion fitme-story PR (Phase 3).

---

## §14 Cross-References

### Source documents
- Decisions log: [`analytics-observability-decisions-log-2026-05-13.md`](analytics-observability-decisions-log-2026-05-13.md)
- Parent: [`infra-master-plan-2026-05-12.md`](infra-master-plan-2026-05-12.md) §3.6.X
- Audit baseline: in-conversation 2026-05-13 (captured in decisions log §2)

### Live state
- Feature state.json: [`/.claude/features/analytics-observability/state.json`](../../.claude/features/analytics-observability/state.json)
- Feature log: [`/.claude/logs/analytics-observability.log.json`](../../.claude/logs/analytics-observability.log.json)
- Active feature lockfile: [`/.claude/active-feature`](../../.claude/active-feature) → `analytics-observability`
- Parked dependency: [`/.claude/features/3d-interactive-framework-flow-diagram/state.json`](../../.claude/features/3d-interactive-framework-flow-diagram/state.json) (paused, scheduled_after this feature's completion)

### Skills consumed
- `/analytics validate` (existing)
- `superpowers:brainstorming` (used 2026-05-13 to lock 4 decisions)
- `superpowers:writing-plans` (next step — generate implementation plan for Phase 1.A)
- `vercel-plugin:next-cache-components` (Phase 3 caching strategy)
- `vercel-plugin:workflow` (Phase 3 optional, deferred to v8.x)

### Infra primitives extended
- Mechanism A coverage gates (Phase 1.B emits)
- Mechanism C session attribution (Phase 2 attribution to `analytics-observability` feature)
- Mechanism E custom git merge driver (extends to `gate-coverage.jsonl` for new gates)
- v7.8.2 cross-repo asymmetry policy (FT2-only Mechanism A)
- v7.8.3 D-1 reverse-sync (extends to CSV mirror to fitme-story build)

---

## §15 Approval

**Phase 1 PRD complete when:** operator explicitly approves this spec + decisions log. Transition to Phase 2 (Tasks) on approval. Linear epic + Notion page created on Phase 2 entry.

**Phase 2 (Tasks) deliverable:** detailed implementation plan via `superpowers:writing-plans` skill — task IDs, code paths, fixtures.

**Phase 3 (UX/Integration) deliverable:** integration spec for `/control-room/analytics` route (component contracts, data shapes).

**Phase 4 (Implementation) start:** 2026-05-15 earliest (after this PR merges + Linear/Notion setup).
