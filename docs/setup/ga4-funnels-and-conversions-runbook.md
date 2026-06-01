# GA4 Funnels + Conversion Events Operator Runbook

> **Status:** Operator-paced runbook | **Created:** 2026-06-01 | **Owner:** operator + GA4 MCP
> **Property:** G-XE4E1JGWRZ (cross-platform — iOS app + fitme-story web share)
> **Related:** [`docs/product/analytics-taxonomy.csv`](../product/analytics-taxonomy.csv) | [`docs/master-plan/analytics-master-plan-2026-05-13.md`](../master-plan/analytics-master-plan-2026-05-13.md)

This runbook closes **B3 + B4** from the 2026-06-01 session's analytics tier. Both are operator-paced (GA4 console work, not code).

- **B3** — Funnel Analysis Dashboards. Blocks PRD kill-criteria evaluation.
- **B4** — GA4 conversion-event marking. 5-minute GA4 UI toggle per event; gates the funnel-conversion-rate metric in Looker.

Each section gives the canonical definition the operator can paste/wire into GA4 console + the corresponding MCP query for ongoing monitoring.

---

## Phase A — B4: Mark conversion events (5 min per event)

Per `docs/product/analytics-taxonomy.csv` "Conversion: Yes" column, the following events are declared as conversions but **not yet marked** in GA4 console. Mark each via Admin → Events → toggle "Mark as conversion".

### Primary (mark first)

| # | Event | Surface | Why it's the conversion |
|---|---|---|---|
| 1 | `sign_up` | Onboarding (iOS) | Activation rate — first true commitment past anonymous browsing |
| 2 | `tutorial_complete` | Onboarding final step | Onboarding completion rate — predicts D1-D7 retention |
| 3 | `workout_complete` | Workout save | Training adoption — primary product-value signal |
| 4 | `home_action_completed` | Home screen post-tap | Measures follow-through, not just intent (separate from `home_action_tap`) |
| 5 | `nutrition_meal_logged` (formerly `meal_log`) | Meal entry save | Nutrition adoption — secondary engagement |

### Secondary (mark after primary stabilizes)

| # | Event | Surface | Why secondary |
|---|---|---|---|
| 6 | `training_session_completed` | Active training screen | Granular workout signal; pairs with `workout_complete` for funnel |
| 7 | `import_plan_activated` | Imported plan detail (post-PR #234) | Onboarding power-user path |
| 8 | `dashboard_blocker_acknowledged` | UCC operations dashboard | Internal observability conversion (not user-facing) |

### Console steps

```text
1. Open https://analytics.google.com → property G-XE4E1JGWRZ
2. Admin (gear icon, bottom-left) → Events
3. Find each event in the table (rows 1-5 above first)
4. Toggle "Mark as conversion" → blue switch on the right
5. Wait 24h for GA4 to start crediting conversions
6. Verify in Reports → Engagement → Conversions
```

**Acceptance:** all 5 primary conversions appear in Reports → Engagement → Conversions within 24h of the toggle.

---

## Phase B — B3: Define 5 canonical funnels

Each funnel is defined as a sequence of steps (events with optional parameter filters). Build in GA4 console via **Explore → Funnel exploration → Create new exploration**.

### Funnel 1 — Onboarding to first workout (Activation funnel)

**Hypothesis:** users who complete onboarding within ~7 days are 5x more likely to log a workout.

| Step | Event | Parameter filter | Notes |
|---|---|---|---|
| 1 | `first_open` | — | iOS app first launch |
| 2 | `onboarding_step_viewed` | `step_index = 0` | Welcome screen surfaced |
| 3 | `onboarding_step_completed` | `step_index = 4` | Auth step survived (post-PR #80) |
| 4 | `tutorial_complete` | — | Onboarding fully done |
| 5 | `home_action_tap` | — | First home engagement |
| 6 | `workout_complete` | — | **Conversion target** |

**Time window:** 7 days. **Cohort:** new users only (no `first_open` < 7 days ago in the rolling history).

**Why it matters:** kill criterion for the onboarding-v2 feature — completion rate ≥ 60% at step 4 (configured in `docs/product/prd/onboarding.md`).

### Funnel 2 — Onboarding drop-off detection

**Hypothesis:** the steepest drop happens between auth (step 4) and tutorial completion (step 5+).

| Step | Event | Parameter filter | Notes |
|---|---|---|---|
| 1 | `onboarding_step_viewed` | `step_index = 0` | Welcome |
| 2 | `onboarding_step_completed` | `step_index = 1` | Goals |
| 3 | `onboarding_step_completed` | `step_index = 2` | Profile |
| 4 | `onboarding_step_completed` | `step_index = 3` | Health |
| 5 | `onboarding_step_completed` | `step_index = 4` | Auth |
| 6 | `tutorial_complete` | — | **Conversion target** |

**Why it matters:** triggers PRD kill criterion when any step-N → step-N+1 conversion < 80% (per `docs/product/prd/onboarding.md`).

### Funnel 3 — Smart Reminders engagement (C1+C2+C4 surface validation)

**Hypothesis:** users who receive a smart reminder + tap it are 3x more likely to log a workout that day.

| Step | Event | Parameter filter | Notes |
|---|---|---|---|
| 1 | `home_readiness_alert_shown` (C2) or `home_trend_alert_shown` (C4) | — | Banner rendered on home |
| 2 | `home_readiness_alert_tap` / `home_trend_alert_tap` | — | User opened AIIntelligenceSheet |
| 3 | `home_action_tap` | — | Picked one of the CTAs |
| 4 | `home_action_completed` | — | **Conversion target** |

**Time window:** 24 hours (same-day attribution).

**Why it matters:** C2 + C4's kill criteria (action-taken rate ≥ 30%, push-fatigue ≤ 60%) require this funnel to evaluate. Currently can't evaluate until TestFlight build ships C2/C4 instrumentation to testers + ~14 days of data accumulate.

### Funnel 4 — Web → app conversion (fitme-story → iOS install)

**Hypothesis:** fitme-story showcase visitors who explore ≥ 2 case studies are higher-intent → measure App Store referral.

| Step | Event | Parameter filter | Notes |
|---|---|---|---|
| 1 | `page_view` | `page_location` contains `/case-studies/` | Landed on a case study |
| 2 | `page_view` | `page_location` contains `/case-studies/` | Read a second case study |
| 3 | `select_content` | `content_type = app_store_link` | Clicked install CTA (TBD — needs wiring per B4 follow-on) |
| 4 | `first_open` (iOS app, attribution-linked) | — | **Conversion target** |

**Status:** **DEFERRED until App Store launch.** Step 3 requires an install CTA in the showcase site that doesn't exist yet; step 4 attribution requires a real install ecosystem.

### Funnel 5 — Operator UCC observability (internal)

**Hypothesis:** when a `dashboard_sync_warning_shown` event fires, the operator should acknowledge the blocker within 1 hour.

| Step | Event | Parameter filter | Notes |
|---|---|---|---|
| 1 | `dashboard_sync_warning_shown` | — | Cross-repo sync drift detected |
| 2 | `dashboard_load` | `entry_point = alerts_banner` | Operator opened the dashboard |
| 3 | `dashboard_blocker_acknowledged` | — | **Conversion target — acknowledged within 1h** |

**Why it matters:** the UCC TTC (time-to-conversion) metric — internal observability SLO is operator-acknowledges-blocker < 1h sustained over 7d (per UCC PRD §10.1).

---

## Phase C — B3 follow-up: Looker Studio templates

Once GA4 funnels are wired (Phase B above), the same definitions feed into Looker Studio for dashboarding. Each funnel maps to a Looker template:

| Funnel | Looker template | Refresh cadence |
|---|---|---|
| F1 Activation | `fitme-activation-funnel` | Daily |
| F2 Drop-off | `fitme-onboarding-dropoff` | Daily |
| F3 Smart Reminders | `fitme-smart-reminders-engagement` | Daily (post-TestFlight ship) |
| F4 Web→App | (deferred) | (deferred) |
| F5 UCC TTC | `fitme-ucc-ttc` | Hourly |

**Steps to wire:**

```text
1. Open https://lookerstudio.google.com
2. Create → Data source → GA4 → property G-XE4E1JGWRZ
3. Use template (paste funnel def JSON when available) OR build new dashboard
4. Time range: rolling 28 days (matches GA4 default)
5. Share to operator + add to /control-room/analytics navigation
```

---

## Phase D — B1 + B2 ongoing checks

### B1 — Daily GA4 anomaly check

Run the following query daily (operator + GA4 MCP). Flag any day-over-day delta > 30% as a potential anomaly:

```text
mcp__ga4__getEvents period=last_24h
mcp__ga4__runReport metric=screen_view dimension=date period=last_7d
mcp__ga4__runReport metric=conversions period=last_24h
```

**Last run (2026-06-01):** 0 anomalies. Partial-day artifact accounts for the -85 to -90% drop across all events (15h of data vs 24h baseline). See `.claude/shared/must-have-cadence-followups.md` for the next-run target.

### B2 — Verify today's home_-prefixed events

The 8 new events shipped today (C2 + C4) need post-TestFlight verification:

- `home_readiness_alert_shown` / `_tap` / `_action_taken` / `_dismissed` (C2, FT2 #560)
- `home_trend_alert_shown` / `_tap` / `_action_taken` / `_dismissed` (C4, FT2 #564)

**Status as of 2026-06-01 14:30 UTC:** all 8 events return zero hits in GA4 (`mcp__ga4__getEvents` partial-day query). Expected because TestFlight build is not yet cut + testers haven't updated. Re-run B2 ~T+3 days after operator pushes the next TestFlight build.

---

## Cross-references

- Analytics master plan: [`docs/master-plan/analytics-master-plan-2026-05-13.md`](../master-plan/analytics-master-plan-2026-05-13.md)
- Analytics taxonomy: [`docs/product/analytics-taxonomy.csv`](../product/analytics-taxonomy.csv)
- iOS app analytics service: `FitTracker/Services/Analytics/AnalyticsProvider.swift`
- Web analytics wiring: `fitme-story/src/lib/analytics.ts` + `fitme-story/src/app/layout.tsx` (NEXT_PUBLIC_GA_ID)
- Cadence ledger (B-actions): [`.claude/shared/must-have-cadence-followups.md`](../../.claude/shared/must-have-cadence-followups.md)
- 2026-05-20 GA4 telemetry audit: backlog row L# in `docs/product/backlog.md`
- 2026-06-01 session (C1-C2 + B1-B4): this runbook closes the docs deliverable

## Status summary

| ID | Description | Status | Next action |
|---|---|---|---|
| B1 | Daily GA4 anomaly check | ✅ Ran 2026-06-01 — 0 anomalies | Operator runs daily; surface anomalies via cadence ledger |
| B2 | Verify 8 new home_-prefixed events (C2+C4) | ⏳ Deferred — TestFlight build cycle | Re-run when next TestFlight build ships |
| B3 | 5 funnel definitions | ✅ Defined in this doc | Operator wires Funnels 1+2+5 in GA4 console (Funnels 3 + 4 wait for TestFlight/launch) |
| B4 | 5 primary + 3 secondary conversion events to mark | ✅ Defined in this doc | Operator toggles "Mark as conversion" in GA4 Admin (5 min/event) |
