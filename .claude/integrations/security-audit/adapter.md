# Dependency Security Audit — Integration Adapter

## Service Info

- **Service:** Dependency Security Audit (CVE scanning)
- **Type:** MCP
- **MCP Server:** `mcp-security-audit`
- **Auth:** None required
- **Consuming Skills:** /dev, /ops, /qa

## How to Call

1. No auth setup needed — the MCP runs locally against the project's dependency manifests.
2. Invoke tools as needed:
   - **Full audit:** `security_audit` with `projectPath: "/Volumes/DevSSD/FitTracker2"` — scans Swift Package Manager dependencies
   - **Specific package:** `audit_package` with `packageName`, `version`
   - **CVE lookup:** `lookup_cve` with `cveId` for details on a specific advisory
   - **Generate report:** `generate_audit_report` with `projectPath`, `format: "json"` for machine-readable output
3. The MCP scans `Package.resolved` and `Package.swift` for declared dependencies and checks against the OSV (Open Source Vulnerabilities) database and GitHub Advisory Database.
4. Pass raw responses through `schema.json` for shape validation, then `mapping.json` for normalization.

## Data Flow

```
Security Audit MCP (mcp-security-audit) → audit results → schema.json (validate shape) → mapping.json (normalize fields) → shared layer
```

Writes to:
- `/Volumes/DevSSD/FitTracker2/.claude/shared/health-status.json` — security status, vulnerability counts by severity
- `/Volumes/DevSSD/FitTracker2/.claude/shared/test-coverage.json` — security scan results, last scan timestamp, fix availability

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

> Validation is automatic. Resolution is always manual — the user decides how to address RED or ORANGE alerts. Critical CVEs should be escalated immediately regardless of validation score.

## Fallback

If the MCP is unavailable (package not installed, network unreachable for CVE database):
- Skills continue operating with existing shared layer data
- No error thrown — graceful degradation
- Unavailability is logged to `change-log.json` with reason and timestamp for awareness

## Schema Notes

- `schema.json` defines the expected response shape after the MCP call
- `mapping.json` maps security audit field names → shared layer field names
- If the MCP updates its response format, update `schema.json` and `mapping.json` here — no skill changes needed
- All mapped fields carry `data_type: "measured"` — these are real CVE scan results, not estimates
- Severity levels follow CVSS: `critical` (9.0–10.0), `high` (7.0–8.9), `medium` (4.0–6.9), `low` (0.1–3.9)
