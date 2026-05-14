# Looker Studio Template — Operator Import Guide

**Audience:** operator (one-time setup) · **Created:** 2026-05-14 · **Phase:** analytics-observability 3.B

> Companion to [`docs/master-plan/analytics-master-plan-2026-05-13.md`](../master-plan/analytics-master-plan-2026-05-13.md) §7.2 Sub-system B and the [`looker-studio-template.json`](looker-studio-template.json) spec. Operators who prefer Looker Studio over the in-app `/control-room/analytics` route can import this template into a fresh Looker workspace and get the same metrics.

---

## What this gets you

A 3-page Looker Studio dashboard:

1. **Overview** — daily event volume, CSV drift trend, taxonomy health scorecard
2. **Realtime** — events fired in the last 30 minutes
3. **Catalog** — forward-declared events (declared but UI not yet wired)

Same source ledgers, same metric formulas as the in-app dashboard. Cross-walk in [`docs/master-plan/analytics-dashboard-metric-definitions.md`](../master-plan/analytics-dashboard-metric-definitions.md) §"Cross-walk to Looker Studio template".

---

## Prerequisites

- A Google account with Looker Studio access (free tier sufficient)
- The same GA4 service account credentials configured in [`docs/setup/ga4-mcp-setup-guide.md`](../setup/ga4-mcp-setup-guide.md) Steps 1-3 (Looker reuses the same credential)
- Read access to the FitTracker2 repo (for the `external-sync-status.json` + CSV connected sheets)
- 20-30 minutes (mostly Looker UI clicking)

---

## Step 1 — Create the Looker workspace

1. Open [lookerstudio.google.com](https://lookerstudio.google.com)
2. Click "+ Create" → "Report"
3. Give it the name "FitMe Analytics Operator Dashboard"

---

## Step 2 — Connect data source: GA4

1. In the new report, click "Add data" (top toolbar)
2. Select the "Google Analytics" connector
3. Authenticate with the same Google account that has Viewer access to the FitMe GA4 property (same service-account or user-account that powers `mcp-server-ga4`)
4. Pick the FitMe GA4 property (Property ID = your `GA4_PROPERTY_ID`)
5. Click "Add"

---

## Step 3 — Connect data source: external-sync-status (CSV drift trend)

The `analytics_taxonomy_status` block lives in `.claude/shared/external-sync-status.json` in the FitTracker2 repo. Looker doesn't read repo files directly, so we go through a Connected Sheet:

1. Run a per-day extraction script:
   ```sh
   python3 scripts/export-external-sync-status-history.py --output ~/looker/sync-status-history.csv
   ```
   (This script does not exist yet — it's a future deliverable. Until then, manually export from `git log` of `external-sync-status.json`.)
2. Upload the CSV to Google Sheets in your operator workspace
3. In Looker, "Add data" → "Google Sheets" → select the sheet
4. Field types: `snapshot_date` (date), `drift_count` (number)

---

## Step 4 — Connect data source: taxonomy CSV

For the forward-declared catalog tile:

1. Open `docs/product/analytics-taxonomy.csv` in the repo
2. Upload to Google Sheets (or use the Sheets "Import from URL" pointing at the GitHub raw file URL)
3. Looker "Add data" → "Google Sheets" → select the sheet

---

## Step 5 — Connect data source: cross-reference output

For the taxonomy health scorecard:

1. Run:
   ```sh
   python3 scripts/cross-reference-analytics-enum-csv.py --json > ~/looker/cross-ref.json
   ```
2. Convert JSON to CSV and upload to Google Sheets (or use a small operator-side script that runs on a cron and refreshes the sheet)
3. Looker "Add data" → "Google Sheets" → select

---

## Step 6 — Add charts per the JSON template

The [`looker-studio-template.json`](looker-studio-template.json) file lists every chart with its data source binding, dimension, metric, filter, and threshold. For each chart in the JSON:

1. Click "Add a chart" in Looker
2. Pick the chart type matching `template.pages[].charts[].type`
3. Bind the data source matching `template.pages[].charts[].data_source`
4. Configure dimension + metric per the JSON
5. Apply filters + thresholds per the JSON

Estimated time: ~5 minutes per chart × 5 charts = 25 minutes.

---

## Step 7 — Share with the team

1. Click "Share" (top-right)
2. Add team members (or use a public link if appropriate for your team policy)
3. Set permissions to "Viewer" by default; "Editor" only for dashboard maintainers

---

## Maintenance

- **When adding a new tile to the in-app dashboard:** update `looker-studio-template.json` with the matching chart spec + add a row to the metric-definitions cross-walk table. Operator re-imports the new chart manually.
- **When the source CSV or sync-status format changes:** update the data source mappings + re-export the connected sheets.
- **When GA4 property changes (e.g., new property for a separate environment):** update Step 2 to point at the new property.

---

## Calibration safety reminder

This template is a **spec**. Importing it does not query GA4 or modify any source ledger. Once imported, the Looker dashboard's GA4 charts (Tile 1 EventVolumeTile, Tile 4 RecentEventsStream) DO query GA4 — those are the same yellow-bucket queries the in-app dashboard makes (see master plan §7.5). During the Phase 1.B Calibration Protocol soak window (2026-05-14 → 2026-06-04), prefer not to leave Looker open in a browser tab firing repeated GA4 queries — it adds variance to the `GA4_MCP_DISCONNECTED` baseline.

---

## Cross-references

- Spec: [`looker-studio-template.json`](looker-studio-template.json)
- Master plan §7.2: [`../master-plan/analytics-master-plan-2026-05-13.md`](../master-plan/analytics-master-plan-2026-05-13.md)
- Metric definitions: [`../master-plan/analytics-dashboard-metric-definitions.md`](../master-plan/analytics-dashboard-metric-definitions.md)
- GA4 setup (prerequisite for Step 2): [`../setup/ga4-mcp-setup-guide.md`](../setup/ga4-mcp-setup-guide.md)
- In-app dashboard runbook: [`../setup/control-room-analytics-setup-guide.md`](../setup/control-room-analytics-setup-guide.md)
