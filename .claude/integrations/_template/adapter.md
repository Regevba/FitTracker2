# Integration Adapter Template

> Copy this directory to `.claude/integrations/{service-name}/` and fill in the blanks.

## Service Info

- **Service:** {service name}
- **Type:** MCP | REST API | CLI
- **MCP Server:** {package name or URL, if MCP}
- **Auth:** {what credentials are needed}
- **Consuming Skills:** {which skills read data from this adapter}

## How to Call

{Step-by-step instructions for the skill to invoke this integration.
For MCP: which tool to call, what parameters to pass.
For REST: endpoint URL, headers, request body.
For CLI: command to run.}

## Data Flow

```
{Service} → raw response → schema.json (validate shape) → mapping.json (normalize fields) → shared layer
```

## Validation Gate

All data entering the shared layer passes through the automatic validation gate:

1. Adapter normalizes the response using `mapping.json`
2. Normalized data is cross-referenced against ALL existing shared layer state
3. Validation score = consistent fields / total comparable fields
4. Alert level determined:
   - >= 95% GREEN: Write to shared layer. Notify receiving skill + /pm-workflow (info).
   - 90-95% ORANGE: Write to shared layer. Notify receiving skill + /pm-workflow (advisory).
   - < 90% RED: DO NOT write. Notify receiving skill + /pm-workflow (alert). User must resolve.
5. Every ingestion logged to `.claude/shared/change-log.json`

## Fallback

If the MCP/API is unavailable (not configured, auth expired, service down):
- Skill continues with existing shared layer data
- No error — graceful degradation
- Log the unavailability in change-log.json for awareness

## Schema Notes

- `schema.json` defines the expected response shape AFTER the MCP/API call
- `mapping.json` maps external field names → shared layer field names
- If the external service changes its response format, update `schema.json` and `mapping.json` here — no skill changes needed
