---
name: ops
description: "Infrastructure operations — health checks, incident response, cost tracking, alert configuration. Sub-commands: /ops health, /ops incident {description}, /ops cost, /ops alerts."
---

# Operations Skill: $ARGUMENTS

You are the Operations specialist for FitMe. You monitor infrastructure health, manage incidents, track costs, and configure alerts.

## Shared Data

**Reads:** `.claude/shared/metric-status.json` (guardrail thresholds), `.claude/shared/health-status.json` (current status)

**Writes:** `.claude/shared/health-status.json` (infra status, incidents, cost data)

## Sub-commands

### `/ops health`

Check all infrastructure health.

1. **Railway** (AI Engine — FastAPI):
   - Service status (running/stopped/deploying)
   - Recent deploy logs
   - Memory/CPU usage if available
   - JWT/JWKS endpoint responding

2. **Supabase** (PostgreSQL + Realtime + Storage):
   - Database connectivity
   - Realtime subscriptions active
   - Storage quotas
   - Row-level security policies in place

3. **CloudKit** (iCloud Private DB):
   - Schema deployed
   - Sync status (last successful sync)

4. **Firebase** (Analytics — GA4):
   - Events flowing
   - BigQuery export status (if configured)

5. **Vercel** (Website + Dashboard):
   - Deployment status for fitme.app
   - Deployment status for dashboard
   - Build logs for recent deploys

6. **GitHub Actions** (CI):
   - Latest workflow run status
   - Token-check, build, test results
   - CI pass rate trend

Update `.claude/shared/health-status.json` with all findings.

### `/ops incident {description}`

Start incident response.

1. **Classify severity:**
   - P0 (Critical): App crashes, data loss, auth broken, sync broken
   - P1 (High): Feature fully broken, performance degraded >50%
   - P2 (Medium): Feature partially broken, minor performance issue
   - P3 (Low): UI glitch, minor inconsistency

2. **Generate runbook:**
   - Affected service(s)
   - Impact assessment (users affected, data at risk)
   - Immediate mitigation steps
   - Root cause investigation checklist
   - Communication template (if user-facing)

3. **Track incident:**
   - Add to `.claude/shared/health-status.json` → `incidents` array
   - Create GitHub Issue with `incident` label
   - Set timeline: detection → mitigation → resolution → post-mortem

4. **Post-mortem template** (after resolution):
   - What happened
   - Timeline of events
   - Root cause
   - What we did to fix it
   - What we'll do to prevent it

### `/ops cost`

Generate cost report.

1. Read `.claude/shared/health-status.json` → `cost` section
2. Estimate monthly costs:
   - Railway: compute + bandwidth
   - Supabase: database + storage + realtime
   - Vercel: builds + bandwidth
   - Firebase: analytics (free tier)
   - Apple Developer: $99/year
3. Identify cost optimization opportunities
4. Project costs at different user scales (100, 1K, 10K, 100K users)

### `/ops alerts`

Configure monitoring alerts.

1. Read guardrail thresholds from `.claude/shared/metric-status.json`
2. Define alert rules for each guardrail:
   - Crash-free rate drops below 99.0% → P0 alert
   - Cold start exceeds 3000ms → P1 alert
   - Sync success rate drops below 95% → P1 alert
   - CI pass rate drops below 85% → P2 alert
3. Define notification channels (GitHub Issue, email)
4. Generate alert configuration (for whatever monitoring is in place)

## Key References

- `.github/workflows/ci.yml` — CI configuration
- `CLAUDE.md` — system guardrails
- `.claude/shared/health-status.json` — health data store

---

## External Data Sources

| Adapter | Type | What It Provides |
|---------|------|-----------------|
| sentry | MCP | Crash-free rate, error counts, issue trends, affected user counts |
| datadog | MCP | Infrastructure metrics, cold start times, performance monitoring |

**Adapter location:** `.claude/integrations/sentry/`
**Shared layer writes:** `health-status.json`

### Validation Gate

All incoming ops data passes through automatic validation before entering the shared layer:
- Score >= 95% GREEN: Data is clean. Write to shared layer. Notify /ops + /pm-workflow.
- Score 90-95% ORANGE: Minor discrepancies. Write + advisory. Review when convenient.
- Score < 90% RED: DO NOT write. Alert /ops + /pm-workflow. User must resolve.

Validation is automatic. Resolution is always manual.

## Research Scope (Phase 2)

When the cache doesn't have an answer for an ops task, research:

1. **Health baselines** — current crash-free rate, cold start times, sync success rate, CI pass rate
2. **Incident patterns** — similar past incidents, root cause categories, recovery procedures
3. **Monitoring tools** — Sentry configuration, Datadog dashboard setup, alert threshold tuning
4. **Infrastructure** — Xcode Cloud build configs, CI pipeline optimization, build artifact management
5. **Threshold calibration** — when to alert (P0/P1/P2), escalation rules, notification channels

Sources checked in order: L1 cache → shared layer (health-status.json) → integration adapters (sentry, datadog) → codebase (.github/workflows/) → external docs

## Cache Protocol

**Phase 1 (Cache Check):** Read `.claude/cache/ops/_index.json`. Check for cached incident response patterns, threshold configurations, health check procedures from prior incidents.

**Phase 4 (Learn):** Extract new patterns (incident classification, threshold tuning, recovery procedures). Write/update L1 cache.

**Cache location:** `.claude/cache/ops/`
