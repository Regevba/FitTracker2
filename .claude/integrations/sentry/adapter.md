# Sentry Error Tracking — Integration Adapter

## Service Info

- **Service:** Sentry Error & Crash Tracking
- **Type:** MCP
- **MCP Server:** `https://mcp.sentry.dev` (official hosted Sentry MCP)
- **Auth:** `SENTRY_AUTH_TOKEN` (user auth token from Sentry account settings)
- **Consuming Skills:** /ops, /cx, /qa

## How to Call

1. Ensure `SENTRY_AUTH_TOKEN` env var is set.
2. Connect to the hosted MCP at `https://mcp.sentry.dev`.
3. Invoke tools as needed:
   - **Issues list:** `list_issues` with `organization_slug`, `project_slug`, `query: "is:unresolved"`, `limit: 25`
   - **Issue detail:** `get_issue` with `issue_id`
   - **Error rates:** `get_project_stats` with `organization_slug`, `project_slug`, `stat: "events"`, `resolution: "1h"`
   - **Crash-free rate:** `get_project_stats` with `stat: "sessions"` — derive crash-free rate from `crashed` vs. total sessions
   - **Top issues:** `list_issues` sorted by `events` descending
   - **Affected users:** included in issue payload as `userCount`
4. Pass raw responses through `schema.json` for shape validation, then `mapping.json` for normalization.

## Data Flow

```
Sentry MCP (https://mcp.sentry.dev) → raw API response → schema.json (validate shape) → mapping.json (normalize fields) → shared layer
```

Writes to:
- `/Volumes/DevSSD/FitTracker2/.claude/shared/health-status.json` — `crash_free_rate`, `error_count`, `top_issues`
- `/Volumes/DevSSD/FitTracker2/.claude/shared/cx-signals.json` — crash-related user impact signals

## Validation Gate

All data entering the shared layer passes through the automatic validation gate:

1. Adapter normalizes the response using `mapping.json`
2. Normalized data is cross-referenced against ALL existing shared layer state
3. Validation score = consistent fields / total comparable fields
4. Alert level determined:
   - **>= 95% GREEN:** Write to shared layer. Notify /ops + /pm-workflow (info).
   - **90–95% ORANGE:** Write to shared layer. Notify /ops + /pm-workflow (advisory).
   - **< 90% RED:** DO NOT write. Notify /ops + /pm-workflow (alert). User must resolve.
5. Every ingestion logged to `/Volumes/DevSSD/FitTracker2/.claude/shared/change-log.json`

> Validation is automatic. Resolution is always manual — the user decides how to address RED or ORANGE alerts.

## Fallback

If the MCP is unavailable (auth token expired, hosted endpoint unreachable, Sentry outage):
- Skills continue operating with existing shared layer data
- No error thrown — graceful degradation
- Unavailability is logged to `change-log.json` with reason and timestamp for awareness

## Schema Notes

- `schema.json` defines the expected response shape after the MCP call
- `mapping.json` maps Sentry field names → shared layer field names
- If Sentry changes its MCP response format, update `schema.json` and `mapping.json` here — no skill changes needed
- All mapped fields carry `data_type: "measured"` — these are real crash and error data, not estimates
