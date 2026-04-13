# Axe Accessibility Audit — Integration Adapter

## Service Info

- **Service:** Axe Accessibility Auditing (by Deque)
- **Type:** MCP
- **MCP Server:** `@anthropic-ai/mcp-axe` (by Deque)
- **Auth:** None required
- **Consuming Skills:** /ux, /qa, /design

## How to Call

1. No auth setup needed — the MCP runs locally.
2. Invoke tools as needed:
   - **Audit a URL:** `axe_audit` with `url` (for web views / SwiftUI previews served locally)
   - **Audit HTML string:** `axe_audit_html` with `html` content string
   - **Get violations:** results are returned inline in the audit response — no separate tool needed
   - **Filter by impact:** use `options: { runOnly: { type: "tag", values: ["wcag2a", "wcag2aa"] } }` to scope to WCAG 2 AA
3. Common use cases:
   - Run against SwiftUI web previews or HTML exports during Phase 3 (UX) gateway review
   - Validate specific components exported as HTML for a11y compliance
   - Capture WCAG violation counts before and after a remediation pass
4. Pass raw responses through `schema.json` for shape validation, then `mapping.json` for normalization.

## Data Flow

```
Axe MCP (@anthropic-ai/mcp-axe) → audit results → schema.json (validate shape) → mapping.json (normalize fields) → shared layer
```

Writes to:
- `/Volumes/DevSSD/FitTracker2/.claude/shared/design-system.json` — a11y compliance status per screen/component
- `/Volumes/DevSSD/FitTracker2/.claude/shared/test-coverage.json` — a11y test results, violation counts, WCAG level

## Validation Gate

All data entering the shared layer passes through the automatic validation gate:

1. Adapter normalizes the response using `mapping.json`
2. Normalized data is cross-referenced against ALL existing shared layer state
3. Validation score = consistent fields / total comparable fields
4. Alert level determined:
   - **>= 95% GREEN:** Write to shared layer. Notify /ux + /pm-workflow (info).
   - **90–95% ORANGE:** Write to shared layer. Notify /ux + /pm-workflow (advisory).
   - **< 90% RED:** DO NOT write. Notify /ux + /pm-workflow (alert). User must resolve.
5. Every ingestion logged to `/Volumes/DevSSD/FitTracker2/.claude/shared/change-log.json`

> Validation is automatic. Resolution is always manual — the user decides how to address RED or ORANGE alerts.

## Fallback

If the MCP is unavailable (package not installed, tool invocation fails):
- Skills continue operating with existing shared layer data
- No error thrown — graceful degradation
- Unavailability is logged to `change-log.json` with reason and timestamp for awareness

## Schema Notes

- `schema.json` defines the expected response shape after the MCP call
- `mapping.json` maps axe field names → shared layer field names
- If Deque updates the axe MCP response format, update `schema.json` and `mapping.json` here — no skill changes needed
- All mapped fields carry `data_type: "measured"` — these are real audit results, not estimates
- `violations` array severity levels: `critical`, `serious`, `moderate`, `minor` — each maps to `impactSeverity` in the shared layer
