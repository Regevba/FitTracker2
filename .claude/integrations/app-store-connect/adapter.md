# App Store Connect — Integration Adapter

## Service Info

- **Service:** Apple App Store Connect
- **Type:** MCP
- **MCP Server:** `asc-mcp` (by zelentsov-dev, 208 tools)
- **Auth:** `ASC_KEY_ID` + `ASC_ISSUER_ID` + `ASC_PRIVATE_KEY_PATH` (path to .p8 private key file)
- **Consuming Skills:** /cx, /release, /marketing

## How to Call

1. Ensure `ASC_KEY_ID`, `ASC_ISSUER_ID`, and `ASC_PRIVATE_KEY_PATH` env vars are set.
2. The MCP server handles JWT generation automatically using the above credentials.
3. Invoke tools as needed:
   - **Reviews & Ratings:** `list_customer_reviews` with `appId`, `sort: "MOST_RECENT"`, `limit: 100`
   - **App Versions:** `list_app_store_versions` with `appId`, `platform: "IOS"`
   - **TestFlight Builds:** `list_builds` with `appId`, `sort: "-uploadedDate"`, `limit: 10`
   - **Download Stats:** `get_sales_and_trends` with `appId`, `reportType: "SALES"`, `frequency: "DAILY"`, `reportDate`
   - **Ratings Summary:** `get_app_ratings_summary` with `appId`
4. Pass raw responses through `schema.json` for shape validation, then `mapping.json` for normalization.

## Data Flow

```
App Store Connect MCP (asc-mcp) → raw API response → schema.json (validate shape) → mapping.json (normalize fields) → shared layer
```

Writes to:
- `/Volumes/DevSSD/FitTracker2/.claude/shared/cx-signals.json` — reviews, ratings, sentiment data
- `/Volumes/DevSSD/FitTracker2/.claude/shared/feature-registry.json` — version status per feature
- `/Volumes/DevSSD/FitTracker2/.claude/shared/health-status.json` — build status, latest version

## Validation Gate

All data entering the shared layer passes through the automatic validation gate:

1. Adapter normalizes the response using `mapping.json`
2. Normalized data is cross-referenced against ALL existing shared layer state
3. Validation score = consistent fields / total comparable fields
4. Alert level determined:
   - **>= 95% GREEN:** Write to shared layer. Notify /cx + /pm-workflow (info).
   - **90–95% ORANGE:** Write to shared layer. Notify /cx + /pm-workflow (advisory).
   - **< 90% RED:** DO NOT write. Notify /cx + /pm-workflow (alert). User must resolve.
5. Every ingestion logged to `/Volumes/DevSSD/FitTracker2/.claude/shared/change-log.json`

> Validation is automatic. Resolution is always manual — the user decides how to address RED or ORANGE alerts.

## Fallback

If the MCP is unavailable (not configured, auth expired, ASC API down):
- Skills continue operating with existing shared layer data
- No error thrown — graceful degradation
- Unavailability is logged to `change-log.json` with reason and timestamp for awareness

## Schema Notes

- `schema.json` defines the expected response shape after the MCP call
- `mapping.json` maps ASC field names → shared layer field names
- If Apple changes its API response format, update `schema.json` and `mapping.json` here — no skill changes needed
- All mapped fields carry `data_type: "measured"` — these are real App Store data, not estimates
