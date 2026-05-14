# Analytics Dashboard — Metric Definitions

**Audience:** dashboard maintainer + operator · **Created:** 2026-05-14 · **Phase:** analytics-observability 3 (scaffold)

> Companion to [`analytics-master-plan-2026-05-13.md`](analytics-master-plan-2026-05-13.md) §7.1 Sub-system A. Defines what each tile on `/control-room/analytics` shows, the formula behind it, the source ledger, and the refresh cadence. Also acts as the contract for [`looker-studio-template.json`](../analytics/looker-studio-template.json) cross-walk.

---

## How to read this doc

Each tile section is structured:

- **Question it answers** — one sentence the tile lets the operator answer at a glance
- **Formula** — numerator / denominator OR aggregation + filters
- **Source ledger** — file path or external API; what authoritative data feeds the tile
- **Refresh cadence** — how often the underlying data updates; how often the tile re-fetches
- **Calibration impact** — whether reading or rendering this tile risks contaminating the Phase 1.B Calibration Protocol soak window (see master plan §7.5)

A tile flagged "calibration-impact: yellow" must not ship live data binding before **2026-06-04** — only the fixture-rendered scaffold ships before that date.

---

## Tile 1 — `EventVolumeTile`

### Question it answers

"Are events firing today at the rate they fired yesterday / last week?"

### Formula

```
events_24h        = count(GA4 events where timestamp >= now() - 24h)
events_24h_prior  = count(GA4 events where now() - 48h <= timestamp < now() - 24h)
events_7d_avg     = sum(events per day for last 7 days) / 7
```

Renders 3 numbers + sparkline of the last 14 days. Color band:
- green if `events_24h >= 0.85 * events_7d_avg`
- amber if `0.5 * events_7d_avg <= events_24h < 0.85 * events_7d_avg`
- red if `events_24h < 0.5 * events_7d_avg`

### Source ledger

GA4 Reporting API via `mcp-server-ga4`, dimension `eventName`, metric `eventCount`. Property: FitMe (`GA4_PROPERTY_ID` env var on the dashboard server).

### Refresh cadence

GA4 Reporting API: 24h aggregation lag (per Google docs). Tile re-fetches every 5 minutes (`use cache; cacheLife('minutes')`).

### Calibration impact

🟡 **yellow** — live binding contaminates `GA4_MCP_DISCONNECTED` baseline (each tile load = 1 MCP query × success/fail × N tiles per page-load). Scaffold ships with fixtures; live binding ships post-2026-06-04.

---

## Tile 2 — `DriftTrendTile`

### Question it answers

"Has CSV taxonomy drift increased since the last `analytics_taxonomy_status` snapshot?"

### Formula

```
current_drift   = .claude/shared/external-sync-status.json::sources.analytics.analytics_taxonomy_status.drift_count
prior_snapshot  = git show HEAD~1:.claude/shared/external-sync-status.json | jq '.sources.analytics.analytics_taxonomy_status.drift_count'
delta           = current_drift - prior_snapshot
```

Renders current drift count + sparkline of last 14 daily snapshots. Color band:
- green if `current_drift == 0`
- amber if `1 <= current_drift <= 5`
- red if `current_drift > 5`

### Source ledger

`/Volumes/DevSSD/FitTracker2/.claude/shared/external-sync-status.json` — `sources.analytics.analytics_taxonomy_status` block. Per-day history reconstructed from `git log --follow` of this file.

### Refresh cadence

`external-sync-status.json` updates: when `python3 scripts/refresh-external-sync-status.py --section analytics` runs (manual, or weekly cron). Tile re-fetches every page-load (server-component fetch; no client polling).

### Calibration impact

🟡 **yellow if dashboard triggers refresh-on-load.** 🟢 green if dashboard reads the file as-is without triggering refresh. Scaffold ships green (read-only); any future refresh-on-load button is yellow until 2026-06-04.

---

## Tile 3 — `TaxonomyHealthTile`

### Question it answers

"Are all events declared in the iOS enum + web event helpers also documented in the canonical CSV?"

### Formula

```
ios_events          = parse FitTracker/Services/Analytics/AnalyticsProvider.swift AnalyticsEvent enum
web_events          = parse fitme-story/src/lib/design-system-analytics.ts + control-room/analytics.ts gtag calls
csv_events          = parse docs/product/analytics-taxonomy.csv events column
forward_declared    = csv_events where Notes column starts with "[FORWARD-DECLARED]"

events_in_csv       = (ios_events ∪ web_events) ∩ csv_events
events_missing_csv  = (ios_events ∪ web_events) - csv_events
events_orphan_csv   = csv_events - (ios_events ∪ web_events) - forward_declared

health_pct = len(events_in_csv) / len(ios_events ∪ web_events ∪ csv_events) * 100
```

Renders health % + 3-row breakdown (in CSV / missing / orphan).

### Source ledger

Static codebase parse via `python3 scripts/cross-reference-analytics-enum-csv.py --json`. No external API.

### Refresh cadence

Re-parses on page-load (cheap; pure file reads). No caching needed.

### Calibration impact

🟢 **green** — pure static analysis. Reading the CSV does not modify it. Safe at any time.

---

## Tile 4 — `RecentEventsStream`

### Question it answers

"What events have fired in the last 30 minutes?"

### Formula

```
events_30m = GA4 Realtime API events for property GA4_PROPERTY_ID
            with timestamp >= now() - 30min
```

Renders scrolling list of (timestamp, event_name, top params). Limit: 100 most-recent events. Auto-scroll on new event arrival.

### Source ledger

GA4 Realtime API via `mcp-server-ga4` (same connection as `/analytics poll`).

### Refresh cadence

Polls every 30s (matches `/analytics poll` cadence). Suspense + Streaming for smooth UI.

### Calibration impact

🟡 **yellow** — same reason as Tile 1. Scaffold ships with fixtures; live binding ships post-2026-06-04.

---

## Tile 5 — `ForwardDeclaredEventsTile`

### Question it answers

"Which events are declared in the CSV with the `[FORWARD-DECLARED]` tag but not yet wired to a UI?"

### Formula

```
forward_declared = csv_events where Notes startswith "[FORWARD-DECLARED]"
```

Renders a list of forward-declared events with their target UI surface (parsed from the Notes field).

### Source ledger

`docs/product/analytics-taxonomy.csv`.

### Refresh cadence

Re-parses on page-load.

### Calibration impact

🟢 **green** — pure read of static CSV.

---

## Cross-walk to Looker Studio template

The Looker template at [`docs/analytics/looker-studio-template.json`](../analytics/looker-studio-template.json) defines the same metrics in Looker syntax for operators who prefer Looker over the in-app dashboard. Tile-to-Looker-chart mapping:

| Tile | Looker chart | Looker source |
|---|---|---|
| EventVolumeTile | "Daily Event Volume" line chart | GA4 connector → `eventCount` over `date` |
| DriftTrendTile | "CSV Drift Trend" line chart | Connected Sheet sourced from external-sync-status.json export |
| TaxonomyHealthTile | "Taxonomy Health %" scorecard | Connected Sheet sourced from cross-reference script JSON output |
| RecentEventsStream | "Last 30m Events" table | GA4 connector → events filtered to last 30m |
| ForwardDeclaredEventsTile | "Forward-declared Catalog" table | Connected Sheet sourced from CSV parse |

Maintainer note: when adding a new tile, also add a cross-walk row OR explicitly mark the tile as "in-app only" with a justification.

---

## Cross-references

- Master plan §7 (Phase 3 spec): [`analytics-master-plan-2026-05-13.md`](analytics-master-plan-2026-05-13.md)
- Calibration safety classification: master plan §7.5
- Phase 3 status: master plan §7.6
- Looker template: [`docs/analytics/looker-studio-template.json`](../analytics/looker-studio-template.json)
- Operator setup: [`docs/setup/control-room-analytics-setup-guide.md`](../setup/control-room-analytics-setup-guide.md)
- GA4 MCP setup: [`docs/setup/ga4-mcp-setup-guide.md`](../setup/ga4-mcp-setup-guide.md)
- Analytics taxonomy source: [`docs/product/analytics-taxonomy.csv`](../product/analytics-taxonomy.csv)
- External sync status: `.claude/shared/external-sync-status.json`
