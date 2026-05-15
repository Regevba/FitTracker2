# GA4 Anomaly Check — Daily Operator Checklist

> **Tracked as:** B3 in [`.claude/shared/must-have-cadence-followups.md`](../shared/must-have-cadence-followups.md)
> **Cadence:** Daily, operator-run (no automation yet)
> **Owner:** Operator + GA4 MCP
> **Source:** `analytics-observability` epic (active feature, Phase 1.A shipped)

This checklist exists because there is **no scheduled GA4 anomaly job today** and GA4 only became MCP-queryable on 2026-05-14 (FIT-142). Until the automation lands (`/analytics watch` daily routine), the operator runs the queries below at the start of each working session and writes any anomaly to the `analytics-observability` feature log.

---

## Pre-flight (≤30 seconds)

1. **MCP connection check** — invoke any `mcp__ga4__*` tool with trivial args (e.g., `mcp__ga4__getActiveUsers` for the last hour). If it returns a result, GA4 MCP is reachable.
2. **Access binding check (known pending as of 2026-05-15)** — if any GA4 query returns `403 Permission denied` or `User does not have access to property 531124395`, the service-account access binding is still pending. See `project_session_2026_05_15_ga4_access_binding_blocked.md` memory entry for the OAuth Playground recovery path; queries cannot proceed until this lands.

If pre-flight fails → log "GA4 anomaly check SKIPPED — MCP access blocked" in the feature log and skip the rest of the checklist for the day.

---

## Baseline query set (≤2 minutes)

Run these three queries in order. Capture the result as scratch notes — no commit required unless an anomaly fires.

### Query 1 — Event volume, last 24h

```
mcp__ga4__getEvents period=last_24h
```

**What you're looking for:**
- Total event count vs prior-day baseline
- Any event category dropping to zero unexpectedly (e.g., `screen_view`, `sign_in`, `nutrition_meal_logged`)
- Any new event names appearing (could indicate uninstrumented release leak)

### Query 2 — Daily screen views, last 7 days

```
mcp__ga4__runReport metric=screen_view dimension=date period=last_7d
```

**What you're looking for:**
- Day-over-day deltas across the week
- Weekend-vs-weekday rhythm intact (or expected break)
- Any single day at <50% of the trailing 6-day median → potential outage or instrumentation regression

### Query 3 — Conversions, last 24h

```
mcp__ga4__runReport metric=conversions period=last_24h
```

**What you're looking for:**
- Funnel completion (onboarding → first_workout → first_meal_logged) within historic range
- Sign-in conversion rate (sign_in_completed / sign_in_started) within ±10% of trailing-7d average

---

## Anomaly criteria

Flag as an **anomaly** if any of the following:

| Signal | Threshold | Severity |
|---|---|---|
| Single event volume dropped vs prior day | **> 30%** | HIGH |
| Single screen_view dropped vs trailing-7d median | **> 30%** | HIGH |
| Event name vanished entirely (count = 0) | n/a | CRITICAL |
| New unknown event name appeared | n/a | MEDIUM (investigate, may be benign release) |
| Conversion funnel completion rate dropped | **> 15%** | HIGH |
| GA4 query returned error / timeout / partial | n/a | LOW (re-run once; if persists, file `/ops incident`) |

Single-anomaly within range (<30% / <15%) → record in feature log but do NOT escalate. Day-to-day noise is expected.

---

## When an anomaly fires

1. **Log it** — append to `.claude/logs/analytics-observability.log.json` via `python3 scripts/append-feature-log.py analytics-observability "ga4-anomaly-<YYYY-MM-DD>" "<one-line summary>"`
2. **Triage** — root-cause one level deep:
   - Schema regression? → dispatch `/analytics validate`
   - Sudden traffic drop? → dispatch `/ops health` (check Vercel + GA4 dashboard separately)
   - Funnel break? → dispatch `/cx analyze <feature>` if a specific funnel breaks
3. **Decide** — is this an operational issue, a release regression, or a measurement artifact? Document the decision in the feature log entry.

If **two consecutive days** show the same anomaly, escalate to a feature-grade investigation via `/pm-workflow analytics-observability` (resume the active feature).

---

## Cadence + retirement

| Stage | Status | Cadence | Notes |
|---|---|---|---|
| **Manual (today)** | active | daily, operator-run | This checklist |
| **Semi-automated (Phase 2.A.2)** | partially shipped | `/analytics watch` CLI sub-command (PR #345) | Live CLI; not yet wired to a daily routine |
| **Fully automated (Phase 2.B+)** | planned | scheduled remote agent (Linear routine + GA4 MCP) | Retires this manual checklist |

When the daily routine ships, this file becomes a historical reference. Until then, the operator is the routine.

---

## Reference

- GA4 property: `531124395` (FitMe app)
- GCP project: `fitme-490515`
- Service account: `ga4-mcp-reader@fitme-490515.iam.gserviceaccount.com`
- MCP setup: [`docs/setup/firebase-setup-guide.md`](../../docs/setup/firebase-setup-guide.md)
- Active feature: [`.claude/features/analytics-observability/`](../features/analytics-observability/)
- Taxonomy: [`docs/product/analytics-taxonomy.csv`](../../docs/product/analytics-taxonomy.csv)
- Naming convention: CLAUDE.md → "Analytics Naming Convention" section (screen-prefix rule, est. 2026-04-08)

Last refreshed: 2026-05-15.
