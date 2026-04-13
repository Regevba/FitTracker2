# GA4 Analytics — Integration Adapter

## Service Info

- **Service:** Google Analytics 4 (GA4)
- **Type:** MCP
- **MCP Server:** `mcp-server-ga4` (by harshfolio)
- **Auth:** `GA4_PROPERTY_ID` + `GOOGLE_APPLICATION_CREDENTIALS` (path to service account JSON)
- **Consuming Skills:** /analytics, /pm-workflow, /cx

## How to Call

1. Ensure `GA4_PROPERTY_ID` and `GOOGLE_APPLICATION_CREDENTIALS` env vars are set.
2. Invoke the MCP tool with the desired report parameters:
   - **Tool:** `run_report`
   - **Parameters:**
     - `propertyId`: value of `GA4_PROPERTY_ID`
     - `dateRanges`: e.g. `[{ "startDate": "30daysAgo", "endDate": "today" }]`
     - `dimensions`: e.g. `["eventName", "screenName"]`
     - `metrics`: e.g. `["activeUsers", "eventCount", "sessions", "screenPageViews"]`
3. For funnel data, use the `run_funnel_report` tool with the same property ID.
4. For crash-free rate, query the `crashFreeRate` custom metric or derive from `crash` event counts vs. total sessions.
5. Pass the raw response through `schema.json` for shape validation, then `mapping.json` for normalization.

## Data Flow

```
GA4 MCP (mcp-server-ga4) → raw report response → schema.json (validate shape) → mapping.json (normalize fields) → shared layer
```

Writes to:
- `/Volumes/DevSSD/FitTracker2/.claude/shared/metric-status.json` — `metrics[].current` values (activeUsers, sessions, crashFreeRate, etc.)
- `/Volumes/DevSSD/FitTracker2/.claude/shared/feature-registry.json` — per-feature event counts and conversion metrics

## Validation Gate

All data entering the shared layer passes through the automatic validation gate:

1. Adapter normalizes the response using `mapping.json`
2. Normalized data is cross-referenced against ALL existing shared layer state
3. Validation score = consistent fields / total comparable fields
4. Alert level determined:
   - **>= 95% GREEN:** Write to shared layer. Notify /analytics + /pm-workflow (info).
   - **90–95% ORANGE:** Write to shared layer. Notify /analytics + /pm-workflow (advisory).
   - **< 90% RED:** DO NOT write. Notify /analytics + /pm-workflow (alert). User must resolve.
5. Every ingestion logged to `/Volumes/DevSSD/FitTracker2/.claude/shared/change-log.json`

> Validation is automatic. Resolution is always manual — the user decides how to address RED or ORANGE alerts.

## Fallback

If the MCP is unavailable (not configured, auth expired, GA4 property unreachable):
- Skills continue operating with existing shared layer data
- No error thrown — graceful degradation
- Unavailability is logged to `change-log.json` with reason and timestamp for awareness

## Schema Notes

- `schema.json` defines the expected response shape after the MCP call
- `mapping.json` maps GA4 field names → shared layer field names
- If GA4 changes its API response format, update `schema.json` and `mapping.json` here — no skill changes needed
- All mapped fields carry `data_type: "measured"` — these are real telemetry, not estimates
