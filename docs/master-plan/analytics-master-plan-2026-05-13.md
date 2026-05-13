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
| 1.A.1 | ~~Backfill 56 missing CSV rows from iOS enum~~ **DONE** 2026-05-13 (PR #334) — flat-scan picked up all 49 events + 7 screens + 1 user prop in a single pass; 1.A.2 absorbed into this task. CSV now 112/112 aligned. | 2h | dev | ✅ `python3 scripts/cross-reference-analytics-enum-csv.py` reports 0 missing |
| 1.A.2 | ~~Add 7 missing screens + 1 user property to CSV~~ **ROLLED INTO 1.A.1** — see above outcome. | 30m | dev | ✅ |
| 1.A.3 | ~~Wire iOS `ai_recommendation_accepted` + `ai_recommendation_dismissed` to the thumbs-up/down handler (or delete if not wanted)~~ **DELETED** 2026-05-13 — both events were duplicates of `home_ai_feedback_submitted` (which already carries `rating: positive/negative`). Enum 114 → 112; CSV stays aligned at 112/112. | 30m | dev | enum constants removed + CSV rows removed; cross-reference clean |
| 1.A.4 | ~~Wire fitme-story `design_system_component_expand` + `design_system_code_copy` (or delete)~~ **RE-CLASSIFIED as forward-declared** 2026-05-13 — helpers exist in fitme-story `src/lib/design-system-analytics.ts` awaiting UI; tagged `[FORWARD-DECLARED]` in CSV Notes per §5.4 convention. Phase 1.B gate honors this tag. | 30m | dev | `[FORWARD-DECLARED]` prefix in 2 CSV Notes + JSDoc `@forward-declared` on 2 helpers + master plan §5.4 convention added |
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
- (Forward-declared events `design_system_component_expand` + `design_system_code_copy` do not get tests in Phase 1.A — tests will be added when the UI ships; see §5.4 below)

### §5.4 Forward-Declared Events Convention (added 2026-05-13, Phase 1.A.4 resolution)

**Rule:** Analytics event constants + CSV rows may exist for events whose UI has not yet shipped, provided the CSV `Notes` column starts with the literal tag `[FORWARD-DECLARED]`.

**Rationale:** Forward-declaring an event helps the team agree on parameter names + GA4 routing **before** the UI lands. Deleting forward-declared events on every audit forces re-creation work when the UI ships, which is worse than maintaining the placeholder.

**Honored by:**
- `/analytics validate` skill: ignores `[FORWARD-DECLARED]`-tagged rows when computing "declared-but-unwired" metric
- Phase 1.B `CSV_TAXONOMY_DRIFT` gate: passes when an enum constant has a CSV row, regardless of wiring status, as long as the row exists
- (Future) Phase 1.B alternative gate `EVENT_UNWIRED_AND_NOT_FORWARD_DECLARED`: would fire if enum constant has 0 call sites AND CSV `Notes` lacks `[FORWARD-DECLARED]` prefix. (Considered for v8.0 — not in Phase 1.B initial scope to keep gate count minimal.)

**Current forward-declared events (2):**
- `design_system_component_expand` — helper at fitme-story `src/lib/design-system-analytics.ts:trackDesignSystemComponentExpand`; awaits ComponentCard expand UI
- `design_system_code_copy` — helper at fitme-story `src/lib/design-system-analytics.ts:trackDesignSystemCodeCopy`; awaits Copy snippet button UI

**When the UI ships:**
1. Wire the helper call from the new UI component
2. Remove the `[FORWARD-DECLARED]` tag from the CSV `Notes` column
3. Add 1+ unit test confirming the helper fires on the expected interaction
4. Update the implementing feature's state.json to record that the wiring took place

**Why this convention is safe:** the forward-declared tag is a STRUCTURED, machine-grep-able prefix. Phase 1.B `CSV_TAXONOMY_DRIFT` gate logic can branch on its presence/absence. Free-text "RESERVED" or "STUB" notes (which the previous CSV used) are unstructured and don't permit mechanical enforcement.

### §5.5 Phase 1.A current status (snapshot 2026-05-13 evening)

**Shipped (3 tasks, 5 sub-deliverables):**

| Task | PR | SHA | Outcome |
|---|---|---|---|
| 1.A.1 + 1.A.2 | [#334](https://github.com/Regevba/FitTracker2/pull/334) | merged | CSV 58 → 112 rows; 0 missing events / screens / user props |
| 1.A.3 | [#335](https://github.com/Regevba/FitTracker2/pull/335) | merged | `aiRecommendationAccepted/Dismissed` removed (duplicates); enum 114 → 112; CSV stays aligned 112/112 |
| 1.A.4 | [#336](https://github.com/Regevba/FitTracker2/pull/336) | merged | 2 web events re-classified `[FORWARD-DECLARED]`; new convention §5.4 added; metric re-baselined |

Plus the parent feature scaffolding PR ([#332](https://github.com/Regevba/FitTracker2/pull/332), merged 2026-05-13T15:34Z) which carried the initial spec + decisions log + state.json.

**Remaining (3 tasks before Phase 1.A closure):**

| Task | Effort | Earliest | Blocker check |
|---|---|---|---|
| 1.A.5 — Add tests for 21 untested iOS events | 2h | 2026-05-14 | None — pure additive test work |
| 1.A.6 — Add fitme-story `.env.example` with `NEXT_PUBLIC_GA_ID=G-xxxxxxx` placeholder | 5m | 2026-05-14 | None |
| 1.A.7 — Refresh stale `.claude/shared/external-sync-status.json` analytics block | 15m | 2026-05-14 | None — value already auto-computable |

**Phase 1.A close trigger:** all 3 remaining tasks shipped + `python3 scripts/cross-reference-analytics-enum-csv.py` clean + test-coverage 100%.

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

### §14.5 Observed Patterns Catalog applicability

This feature both **consumes** existing entries in [`.claude/integrity/observed-patterns.md`](../../.claude/integrity/observed-patterns.md) and **adds** new entries when its gates ship. Cross-references:

| Catalog entry | How analytics-observability uses it |
|---|---|
| **#2** `CACHE_HITS_AUTO_INSTRUMENTATION_INACTIVE` | This feature's own state.json is currently flagged (9 Read events attributed via Mechanism C, no `cache_hits[]`). Expected per pattern — v7.8.x advisory, auto-resolves when v7.9 promotes Mechanism C dual-write. No action. |
| **#1** `BRANCH_ISOLATION_HISTORICAL` | Will fire on this feature if its branches get squash-merged + cleanup-deleted before the catalog's signal-vs-noise check is run. Per pattern: cleanup-artifact, confirmed via PR `head_ref`. |
| **#3** `BRANCH_ISOLATION_VIOLATION` Mode B | Phase 1.B gate work (2026-06-04+) is infra-path (`scripts/check-state-schema.py`, `.githooks/pre-commit`); Mode B WILL fire correctly on commits to those files. Mandatory: ship on a `chore/*` or `feat/*` branch. |
| **#5** `ISOLATION_OPT_OUT_REASON_MISSING` | This feature has `isolation_opt_out: false` in state.json (sub-branches per phase), so this gate should not fire. If a sub-task needs metadata-only commits to main, opt out + document reason. |
| **#6** `FEATURE_CLOSURE_COMPLETENESS` | Fires at `current_phase=complete`. Spec mandates filling all 7 frontmatter fields in `analytics-observability-case-study.md` before closing (incl. `kill_criteria_resolution` per Q7). |
| **#14** `CASE_STUDY_MISSING_TIER_TAGS` | Case study dated post-2026-04-21 → must carry T1/T2/T3 tier tags on every quantitative claim. Mandatory at closure. |
| **#21** `case_study_type` exemption tags | This feature is NOT exempt — `case_study_type` is absent in state.json by design; must produce a real case study. |
| **NEW (post-1.B ship)** `CSV_TAXONOMY_DRIFT` | Will be added as catalog entry #24 the moment Phase 1.B gate ships. Document the trigger, the `[FORWARD-DECLARED]` exemption (per §5.4), and the silence path. |
| **NEW (post-1.B ship)** `GA4_MCP_DISCONNECTED` | Will be added as catalog entry #25. Document that it is always advisory (never blocks), as a clear "GA4 reachability unknown" signal. |

**Operator obligation:** when Phase 1.B ships, the closing PR MUST append entries #24 and #25 to `.claude/integrity/observed-patterns.md` — the catalog's mandatory-update rule (per [PR #328](https://github.com/Regevba/FitTracker2/pull/328)) makes this non-optional.

---

## §15 Approval

**Phase 1 PRD complete when:** operator explicitly approves this spec + decisions log. Transition to Phase 2 (Tasks) on approval. Linear epic + Notion page created on Phase 2 entry.

**Phase 2 (Tasks) deliverable:** detailed implementation plan via `superpowers:writing-plans` skill — task IDs, code paths, fixtures.

**Phase 3 (UX/Integration) deliverable:** integration spec for `/control-room/analytics` route (component contracts, data shapes).

**Phase 4 (Implementation) start:** 2026-05-15 earliest (after this PR merges + Linear/Notion setup).

### §15.1 Phase 1 PRD approval checklist

Operator confirms each item before transition from PRD → Tasks:

- [ ] **§2** baseline numbers (56 missing rows / 4 unfired / 21 untested / 2 unwired / GA4 MCP disconnected) match the in-conversation audit findings of 2026-05-13
- [ ] **§3** Approach B accepted; A (monolithic) + C (3 separate features) explicitly rejected
- [ ] **§4** Architecture diagram covers all 5 surfaces (iOS app, web app, local mirror sink, MCP poll, control-room route)
- [ ] **§5.1** task table accurate against `state.json::tasks` (1.A.1+1.A.2 / 1.A.3 / 1.A.4 done; 1.A.5–7 pending)
- [ ] **§5.4** forward-declared events convention accepted; `[FORWARD-DECLARED]` Notes prefix is the canonical structured tag
- [ ] **§5.5** Phase 1.A status snapshot accurate against PR history (#332, #334, #335, #336 all merged)
- [ ] **§6–§7** Phase 2 + Phase 3 scope, files, and tests reviewed
- [ ] **§8** Phase 1.B gate specs reviewed; 22-day Calibration Protocol mapping accepted; advisory-only nature of `GA4_MCP_DISCONNECTED` accepted
- [ ] **§9** primary + 4 secondary metrics + 3 kill criteria reviewed
- [ ] **§10** risk register reviewed; 7 risks classified
- [ ] **§11** F19 + F20 candidate mapping aligned with `2026-05-08-framework-v7-9-candidates.md`
- [ ] **§12** Linear epic + 13 child issues planned (actual numbers captured on creation)
- [ ] **§13** Notion sub-page placement confirmed under FitMe Product Hub
- [ ] **§14.5** Observed Patterns Catalog cross-references reviewed; obligation to add #24 + #25 at Phase 1.B ship accepted
- [ ] **§16** Operational runbook reviewed (esp. mirror-OFF-by-default + passkey-gated dashboard)
- [ ] **§17** Cross-phase dependencies + sequencing diagram accepted
- [ ] **Calendar conflicts**: Phase 1.A + 2 → 2026-05-15→22 (post v7.8.5, before v7.9 Phase E start); Phase 3 → 2026-05-21→06-04 (parallel v7.9 Phase E); Phase 1.B → 2026-06-04→06-26 (post Phase E exit) — all 4 windows align with [`infra-master-plan-2026-05-12.md`](infra-master-plan-2026-05-12.md) §3.5/§3.6

Approval recorded as `transitions[].approved_at` in state.json (timestamp + `approved_by: "user"` + free-text `note`).

---

## §16 Operational Runbook

How to operate each phase post-ship. Each subsection is the survival kit for an operator (you or me) coming in cold to maintain the feature.

### §16.1 Phase 1.A — Hygiene maintenance

**Regular operation:** none. The CSV is authored manually; the cross-reference script is the safety net.

**On regression:** if `python3 scripts/cross-reference-analytics-enum-csv.py` flags drift (after Phase 1.B gate enforces it should be impossible without bypass), pull the offending feature branch, add the missing row(s), recommit. Pattern #24 (post-Phase-1.B) will document the exact remediation.

**Adding a new analytics event:** define in `AnalyticsEvent` enum → add CSV row (with `Notes` field; use `[FORWARD-DECLARED]` if UI not wired yet) → add 1+ test in matching `*AnalyticsTests.swift` file → commit on a feature branch. Mode B will fire because pre-commit hooks live in `.githooks/`; that's expected per pattern #3.

**Refresh stale `external-sync-status.json`:** `make analytics-instrumentation-summary` (added during 1.A.7); writes today's date + percentage to the analytics block.

### §16.2 Phase 2 — Live debugger operation

**Local mirror (DEBUG_ANALYTICS=1) — daily dev use:**

```bash
# Terminal 1: start the mirror server
python3 scripts/analytics-watch-server.py --port 8765

# Terminal 2: tail events
/analytics watch                     # all events
/analytics watch --filter onboarding # only onboarding_*
/analytics watch --funnel sign_in,onboarding_step_viewed,onboarding_step_completed

# Then run the app:
#   iOS: set DEBUG_ANALYTICS=1 in scheme env → launch Simulator
#   Web: NEXT_PUBLIC_DEBUG_ANALYTICS=1 npm run dev
```

**Port collision:** server exits with "port 8765 in use". Pass `--port 8766` and override the iOS/web env var to match.

**PII safety:** mirror is **off by default**. The DebugSinkAdapter is a pass-through wrapper; if the env flag isn't set, it returns the underlying FirebaseAnalyticsAdapter unchanged. No code path writes to the websocket unless the env flag is set. Confirm in code review at every Phase 2 PR.

**GA4 Realtime poll (`/analytics poll`):**

```bash
# One-time: connect GA4 MCP
export GA4_PROPERTY_ID=<your-property-id>
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
# (see docs/setup/ga4-mcp-setup-guide.md for the full setup)

/analytics poll                    # default 30s interval
/analytics poll --interval 10s     # faster for active dev
/analytics poll --event app_open   # single-event focus
```

**On auth failure:** advisory `GA4_MCP_DISCONNECTED` will surface; resolve service-account JSON file path + IAM role (`roles/analytics.viewer` on the property), retry. Never log credentials.

### §16.3 Phase 3 — Dashboard operation

**`/control-room/analytics` (fitme-story):**

- Auth: passkey (reuses `ucc-passkey-auth` from 2026-05-07; same operator credentials)
- Page load: <3s target including GA4 MCP roundtrip
- Cache: 5-minute tiles via `use cache; cacheLife('minutes')` (per `next-cache-components` skill)
- Live "last 10 events" stream: Suspense + Streaming, no cache

**On GA4 MCP timeout:** the route degrades to "tiles only" with a banner explaining the live stream is unavailable. The 5-minute cached tiles continue to serve.

**On stale data:** force-refresh with F5 invalidates the `cacheTag` set on the GA4 fetch. If cache is wrong for >10 minutes, check the cache tag invalidation in `ga4-mcp-client.ts`.

**Looker Studio template:**

- Operator imports `docs/analytics/looker-studio-template.json` into Looker once
- Charts auto-populate from the configured GA4 property
- No runtime cost; template is operator-owned post-import

### §16.4 Phase 1.B — Gate operation

**Once `CSV_TAXONOMY_DRIFT` is enforced (~2026-06-18):**

- Pre-commit hook rejects commits where an `AnalyticsEvent` enum constant is added without a matching CSV row
- Operator hits this → add the CSV row, restage, recommit
- Legit forward-declared events: pre-add the CSV row tagged `[FORWARD-DECLARED]` BEFORE the enum constant. Gate honors the tag.
- Emergency bypass: `git commit --no-verify` (logged; 72h cycle catches the resulting drift)

**`GA4_MCP_DISCONNECTED` (always advisory):**

- Emits to `gate-coverage.jsonl` + `make integrity-check` finding when env vars unset
- Never blocks
- Resolves naturally when operator runs `gcloud auth application-default login` + sets `GA4_PROPERTY_ID`

**Reversibility:**

- Rollback CSV gate to advisory: edit `scripts/check-state-schema.py` → set function early-return → push patch (<2 min)
- Rollback GA4 advisory off entirely: same path (<5 min)
- Both rehearsed at Phase D before Phase 1.B promotion (~2026-06-18)

---

## §17 Cross-Phase Dependencies & Sequencing

### §17.1 Dependency graph

```text
Phase 1.A (hygiene, 1.A.1-7) ──────┐
                                   │ (1.A.1+1.A.4 inform §5.4 convention)
                                   ▼
            Phase 1.B (gates, 2026-06-04+)
                  ▲
                  │ (gate predicates depend on Phase 1.A landing
                  │  + F16 try-repo harness landing v7.9.1 ~2026-06-11)
                  │
Phase 2 (debugger, parallel 1.A) ──┤
                                   │ (Phase 2 mirror surfaces drift early;
                                   │  Phase 1.B gate codifies it)
                                   │
Phase 3 (dashboards, parallel v7.9 ┤
         Phase E ~2026-05-21+) ────┘
         │
         │ (Phase 3 dashboard reuses Mechanism A coverage
         │  ledger; needs gates to have shipped first
         │  for "taxonomy compliance summary" tile to be useful)
         ▼
   Closure 2026-06-26 → triggers 3D Framework Universe auto-resume
```

### §17.2 Earliest start preconditions

| Phase | Earliest start | Preconditions |
|---|---|---|
| 1.A.5 (iOS tests) | 2026-05-14 | None — purely additive |
| 1.A.6 (.env.example) | 2026-05-14 | None |
| 1.A.7 (sync status refresh) | 2026-05-14 | None |
| 2.A (local mirror) | 2026-05-15 | v7.8.5 must be merged (avoid CI/SSD competition); v7.9 promotion calendar unaffected |
| 2.B (GA4 MCP poll) | 2026-05-15 | Operator-set `GA4_PROPERTY_ID` + service-account JSON (one-time) |
| 3.A (control-room route) | 2026-05-21 | v7.9 Phase E entered (parallel monitoring); passkey auth from `ucc-passkey-auth` still operational |
| 3.B (Looker template) | 2026-05-21 | None |
| 1.B.1 (CSV gate) | 2026-06-04 | v7.9 Phase E EXITED (Layer Stacking Rule per infra plan §3.5.2); F16 try-repo harness optional but recommended |
| 1.B.2 (GA4 advisory gate) | 2026-06-04 | Same |
| 1.B.3 (calibration) | 2026-06-11 | 1.B.1 + 1.B.2 in Phase B (advisory mode) for ≥7 days |
| 1.B.4 (promotion decision) | 2026-06-18 | 1.B.3 calibration shows ≤5% FP rate per gate |

### §17.3 Calendar conflicts already resolved

| Conflict | Resolution | Captured in |
|---|---|---|
| v7.8.5 cache_hits keying patch competing for CI/SSD | Phase 1.A starts 2026-05-15 (after v7.8.5 ship) | `state.json::launch_window` |
| v7.9 Phase E freeze (no new gates 2026-05-21→06-04) | Phase 1.B starts 2026-06-04 (post Phase E exit) | `state.json::launch_window` + §8.1 |
| 22-day Calibration Protocol (infra plan §3.5) | Phase 1.B follows A→B→C→D→E with explicit per-stage dates | §8.1 |
| Layer Stacking Rule (infra plan §3.5.2) | Phase 1.B gates ride on Mechanism A, which exits Phase E ~2026-06-04 if v7.9 promotes 2026-05-21 | §17.2 |
| Active feature collision (3D vs analytics) | 3D parked (`scheduled_after: analytics-observability.complete`); analytics-observability is the live `.claude/active-feature` | state.json + §14.4 |
| HADF Phase 2-bis Sub-exp 1 (2026-05-23) | Different team-track; no shared resources | None — independent track |
| v7.8.5 + #336 + #335 + #334 + #332 already shipped | §5.5 snapshot table | §5.5 |

---
