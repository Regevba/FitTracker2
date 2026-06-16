---
name: ops
description: "Use when running an infrastructure health check, responding to a production incident, auditing cloud cost, configuring alert thresholds, or feeding the UCC Source Health panel. Monitors Railway (FastAPI), Supabase (PostgreSQL), CloudKit, Firebase/GA4, Vercel, GitHub Actions. Sub-commands: /ops health, /ops incident {description}, /ops cost, /ops alerts."
last_updated: 2026-05-15
framework_version: v7.8.6
status: stable
adapters_used: [security-audit, sentry]
---

# Operations Skill: $ARGUMENTS

You are the Operations specialist for FitMe. You monitor infrastructure health, manage incidents, track costs, and configure alerts.

## Observed patterns preflight

<!-- BEGIN pattern-preflight (generated) -->
The [pattern↔skill map](../../shared/pattern-skill-map.json) tracks **51 work-blocking patterns** (23 gate-firing patterns + 28 workflow patterns) drawn from the [Observed Patterns Catalog](../../integrity/observed-patterns.md) (`make observed-patterns`). The patterns below are the ones mapped to `/ops` work — probe the mechanized ones, checklist the rest:

| ID | Pattern | Blocker | Remediation |
|---|---|---|---|
| `#23` | .gitignore blocks Mechanism A / Mechanism C remote-agent visibility | no | Commit periodic gate-coverage / session-ledger snapshots to non-gitignored paths so remote agents can audit. |
| `W8` | External audit status is a UI marker | no | Treat the audit-status UI marker as a signal, not a merge gate. |
| `W11` | Incomplete PR cache (one of two expected repos absent) *(probed)* | no | Run make refresh-pr-cache to repopulate all expected repos; per-repo completeness check auto-detects. |
| `W12` | vercel env pull returns empty values for Sensitive vars | no | Sensitive Vercel vars pull empty; use the Development env variant or a non-Sensitive CLI admin var. |
| `W13` | Upstash KV_* vs UPSTASH_REDIS_REST_* naming asymmetry | no | Alias UPSTASH_REDIS_REST_* to KV_REST_API_*, or read either name in code. |
| `W18` | Default-URL OG image silent-404 | no | Point the default OG image URL at the Next.js convention route; unit-test that the URL resolves. |
| `W19` | Env-var trailing newline corrupts runtime string | no | Trim string env vars at the boundary (process.env.X?.trim()) to strip trailing newlines. |
| `W31` | Workflow delivery anomaly: initial pull_request:opened sometimes fires only the dynamic/skip-path workflows; rebase + force-push triggers full set | no | If a PR open fires fewer than the usual 11-12 checks, run `git rebase origin/main` + `git push --force-with-lease`. close+reopen does NOT reliably re-trigger. Workaround documented as a PR-flow protocol; durable fix queued (CI assertion of expected workflow set). |
| `W34` | PR cache window truncation past the 500-PR limit *(probed)* | yes | Verify the cache window covers the historically-cited PR range: `python3 -c "import json; v=json.load(open('.cache/gh-pr-cache.json'))['repos']['Regevba/FitTracker2']; ns=sorted({x['number'] for b in('open','merged','closed') for x in v[b]}); print('floor',ns[0],'ceil',ns[-1],'count',len(ns))"`. If the floor is far above 1 while citations reference numbers below it, the `gh pr list --limit N` window is truncated. Fix: raise `--limit` in `scripts/refresh-pr-cache.py` (shipped 2026-06-05 PR #631 raised it to 2000 — covers FT2's 571 PRs + headroom). Sibling patterns: #12 PR_CACHE_STALE (empty cache), W11 (incomplete repo set). |
| `W36` | Plan/seat-gated external capability documented as operational while it never once succeeded | yes | Treat a plan/seat-gated capability as an external dependency and verify it end-to-end: check the workflow run history (not existence) for successes. Scaffolding present ≠ pipeline working. Detection: `gh run list --workflow=<name>.yml --limit 20 \| grep -c success` (scaffold-only runs?); for Figma Code Connect: MCP get_code_connect_map returns plan-gate error on Pro. Remediation: (1) disable the scaffold CI if the plan is not available; (2) reconcile all docs to reflect the actual state; (3) add a honesty-ledger entry; (4) write a rebuild plan that uses capabilities actually available on the current plan. See observed-patterns.md W36, FT2-FH-005. |
| `W37` | Bot-authored (GITHUB_TOKEN) PR can never satisfy required checks under strict branch protection → permanent 'expected' deadlock | yes | GITHUB_TOKEN-created PRs don't trigger pull_request CI; with strict+enforce_admins the required checks stay 'expected' and API --admin merge is refused (web-UI admin bypass only). For append-only ledger workflows: commit+push straight to main (option B, shipped 2026-06-15) with the github-actions app in main's bypass_pull_request_allowances; PR fallback if push rejected. Alternative: GitHub App token so the PR triggers CI + enable-auto-merge (option A). See observed-patterns.md W37. |

At activation run `make skill-preflight SKILL=ops` — probes the 2 mechanized blockers for this work type; clear any before proceeding.

**Mandatory** (CLAUDE.md §v7.8.5): any novel pattern surfaced this session MUST be appended to [`observed-patterns.md`](../../integrity/observed-patterns.md) before the feature closes — then re-run `make gen-skill-preflight`.
<!-- END pattern-preflight -->

## Shared Data

**Preflight cache:** `.claude/shared/preflight-cache.json` — refreshed by `make preflight WORK_TYPE=<feature|enhancement|fix|chore> [FEATURE=<name>]`. Run BEFORE any sub-command to get current work-context data (W1 ssh-agent, integrity findings, drift vs anchor, doc-debt, adoption baseline). Cache schema: `docs/skills/preflight-cache-schema.md`.

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

Sources checked in order: L1 cache → shared layer (health-status.json) → integration adapters (sentry) → codebase (.github/workflows/) → external docs

## Cache Protocol

**Phase 1 (Cache Check):** Read `.claude/cache/ops/_index.json`. Check for cached incident response patterns, threshold configurations, health check procedures from prior incidents.

**Phase 4 (Learn):** Extract new patterns (incident classification, threshold tuning, recovery procedures). Write/update L1 cache.

**Cache location:** `.claude/cache/ops/`

---

## Cache Protocol

### Phase 1 — Cache Check (on skill start)
1. Read `.claude/cache/ops/_index.json` for L1 entries
2. Match current task against `task_signature.type`
3. Check L2 `.claude/cache/_shared/` for cross-skill patterns
4. If hit: load `learned_patterns`, `anti_patterns`, `speedup_instructions`
5. Apply loaded patterns — skip derivation steps covered by cache
6. If miss: proceed to Phase 2 (Research)

### Phase 4 — Learn (on skill complete)
1. Extract new patterns and anti-patterns from this execution
2. Write or update L1 cache entry in `.claude/cache/ops/`
3. If pattern overlaps with an existing L2 entry, increment `hit_count`
4. If a new pattern applies to 2+ skills, flag for L2 promotion

### Health Check (Phase 0 — random trigger)
On skill start, before cache check:
1. Read `.claude/shared/framework-health.json`
2. If `random() < 0.25` AND `hours_since(last_check) > 2`: run 5 health checks, compute weighted score, append to history
3. If score < 0.90: STOP and alert user with failing checks and rollback options
4. Proceed to Phase 1 (Cache Check)

## External Data Sources

| Adapter | Location | Shared Layer Target | When to Pull |
|---------|----------|-------------------|--------------|
| sentry | `.claude/integrations/sentry/` | health-status.json | On `/ops health` or `/ops incident` |

**Fallback:** If adapter unavailable, continue with existing shared data. Log to change-log.json.

## Research Scope (Phase 2 — when cache misses)

1. Service health across all infrastructure
2. Incident patterns and MTTR
3. Cost trends per service
4. Alert threshold calibration
5. CI pipeline reliability

**Source priority:** L2 cache > L1 cache > shared layer (health-status.json) > sentry adapter

---

## v4.3 — Operations Control Room Integration

Since v4.3, `/ops` is the primary skill feeding the operations control room dashboard at `fit-tracker2.vercel.app`.

### How /ops feeds the control room

| /ops Output | Control Room Consumer | Shared File |
|-------------|----------------------|-------------|
| Service health checks | Source Health panel (GitHub/Linear/Notion/Vercel/Analytics) | `external-sync-status.json` |
| Incident tracking | Blockers panel (critical + high priority items) | `health-status.json` |
| CI pipeline status | System Pulse (build verification, test counts) | `health-status.json` |
| Cost data | Not yet surfaced in control room (future) | `health-status.json` |
| Alert configuration | Source Health alert counts + framework health score | `framework-health.json` |

### New shared files consumed by /ops (v4.3)

- `.claude/shared/framework-manifest.json` — canonical framework version, skill counts, capabilities. `/ops health` should verify the manifest version matches the SKILL.md version references.
- `.claude/shared/external-sync-status.json` — cross-system drift tracking. `/ops health` should check aggregate health score and alert count. When score drops below 80, flag for investigation.
- `.claude/shared/case-study-monitoring.json` — structured evidence capture for PM cycles. `/ops` does not own this file but should be aware that case-study snapshots include `build_verified` and `tests_passing` fields that reflect CI health.

### Control room deployment

The operations control room is deployed as a static Astro dashboard on Vercel. Data flows:
1. `/ops` or other skills update `.claude/shared/*.json` files
2. Changes are committed and pushed to main
3. Vercel auto-deploys, Astro SSG reads shared files at build time
4. Dashboard reflects updated data at `fit-tracker2.vercel.app`

This means `/ops health` results are not live-streamed — they are snapshotted at deploy time. For real-time monitoring, external adapters (Sentry MCP, etc.) would need to be connected.


## Anti-patterns

Hard-won mistakes for `/ops` work. Every bullet encodes a real or near-miss failure mode.

- Do not declare an incident open without an `/ops incident {description}` invocation that writes to `health-status.json` — verbal acknowledgement does not start the on-call timer
- Do not respond to a PR-cite failure cascade without first running `scripts/ensure-pr-cache-fresh.py` — most cascades are pattern #12 `PR_CACHE_STALE` false positives, not real broken citations
- Do not run destructive infrastructure operations (drop tables, kill prod processes, revoke tokens, force-restart services) without explicit user approval (pattern W5)
- Do not report 'all sources green' if any of the six monitored sources (Railway, Supabase, CloudKit, Firebase, Vercel, GitHub Actions) is missing in the latest `health-status.json` — missing ≠ healthy
- Do not silence an alert without recording the silence reason — silenced-without-record alerts become unknowable technical debt within weeks
