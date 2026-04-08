# `/ops` — Operations

> **Role in the ecosystem:** The infrastructure layer. Owns infrastructure health, incident response, cost tracking, and monitoring alerts. Runs continuously rather than dispatched by specific phases.

**Agent-facing prompt:** [`.claude/skills/ops/SKILL.md`](../../.claude/skills/ops/SKILL.md)

---

## What it does

Monitors infrastructure health across all services (Railway, Supabase, CloudKit, Firebase, Vercel, GitHub Actions), manages incident response with severity classification and runbooks, tracks costs, and configures monitoring alerts.

## Sub-commands

| Command | Purpose | Standalone Example | Hub Context |
|---|---|---|---|
| `/ops health` | Full infrastructure check | "Is everything running?" | Continuous |
| `/ops incident {desc}` | Start incident response | "The AI engine is returning 500s" | Continuous |
| `/ops cost` | Cost report | "What are our monthly cloud costs?" | Continuous |
| `/ops alerts` | Configure monitoring | "Set up alerts for our guardrail metrics" | Continuous |

## Shared data

**Reads:** `metric-status.json` (guardrail thresholds), `health-status.json` (current status).

**Writes:** `health-status.json` (ALL fields — services, CI, quality gates, incidents, cost).

## Incident severity

| Level | Criteria | Examples |
|---|---|---|
| **P0** | App crashes, data loss, auth broken | Encryption failure, sync corruption |
| **P1** | Feature broken, perf degraded >50% | AI engine down, HealthKit observer stuck |
| **P2** | Feature partially broken, minor perf | Slow dashboard load, stale metrics |
| **P3** | UI glitch, minor inconsistency | Wrong icon, alignment issue |

`/ops incident` classifies automatically based on the description, generates a runbook, and creates a GitHub Issue with the correct priority label.

## PM workflow integration

`/ops` is primarily standalone/continuous — not dispatched by specific phases. Exceptions:

- **Phase 7 (Merge):** `/release` reads `/ops` health before sign-off
- **Phase 9 (Learn):** `/cx` reads infrastructure context when classifying bug reports

## Upstream / Downstream

- Reads guardrail thresholds from `/analytics` (via `metric-status.json`)
- Writes health status consumed by `/qa`, `/release`, and `/dev` (via `health-status.json`)
- Receives technical-failure dispatches from `/cx` when root cause = infra

## Standalone usage examples

1. **Health check:** `/ops health` → checks Railway, Supabase, CloudKit, Firebase, Vercel, GitHub Actions
2. **Incident response:** `/ops incident "sync failures spiking"` → classifies severity, generates runbook, creates GitHub Issue
3. **Cost planning:** `/ops cost` → projects costs at 100, 1K, 10K, 100K users

## Key references

- [`.claude/shared/health-status.json`](../../.claude/shared/health-status.json) — the primary data store
- [`docs/setup/`](../setup/) — one-time setup guides for each service

## Related documents

- [README.md](README.md) · [architecture.md](architecture.md) — §14
- [release.md](release.md), [qa.md](qa.md) — consumers of health status
- [pm-workflow.md](pm-workflow.md)
- [`.claude/skills/ops/SKILL.md`](../../.claude/skills/ops/SKILL.md)
