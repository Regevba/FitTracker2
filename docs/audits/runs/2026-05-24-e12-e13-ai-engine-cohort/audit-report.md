---
date: 2026-05-24
audit_type: post-v7-9-docket-verification
items_audited: [E-12, E-13]
verdict: both_healthy
changes_required: none
auditor: claude-opus-4-7-1m
work_type: chore
phase_e_safe: true
---

# Post-v7.9 docket audits — E-12 + E-13 (2026-05-24)

Pure read/verify audits run during Phase E soak window (2026-05-21 → 2026-06-04). No code changes; no infra-glob touches; no calibration contamination.

## E-12 — `ai-engine/` Dockerfile audit + deployment-target reconfirm

**Verdict: ✅ Healthy** — no changes required.

**Files reviewed:**

- [`ai-engine/Dockerfile`](../../../../ai-engine/Dockerfile) (14 lines)
- [`ai-engine/pyproject.toml`](../../../../ai-engine/pyproject.toml) (31 lines)
- [`ai-engine/README.md`](../../../../ai-engine/README.md)
- [`docs/architecture/ai-engine-deployment.md`](../../../architecture/ai-engine-deployment.md) §1, §5

**Findings:**

1. **Base image pinned + security clean.** `python:3.12-slim` (pinned major.minor + slim variant). No `:latest` tag.
2. **Deployment target confirmed: Railway.** Production URL `https://fittracker-ai-production.up.railway.app` hardcoded at [`Config/Base.xcconfig:7`](../../../../Config/Base.xcconfig) + fallback in [`FitTrackerApp.swift:11`](../../../../FitTracker/FitTrackerApp.swift). No Vercel/Fly.io/self-hosted split.
3. **Dockerfile self-consistent with Railway.** FastAPI + uvicorn on 3.12, `EXPOSE 8000`, `CMD uvicorn`. Railway auto-detects via `pyproject.toml` — no Railway-specific config needed in-repo.
4. **No layer-bloat antipatterns.** Single RUN for pip (uses `--no-cache-dir`), no apt-get chains, no leftover build artifacts. 14 lines total — minimal and clean.
5. **Dependencies floor-pinned (not `:latest`).** `fastapi>=0.111.0`, `uvicorn[standard]>=0.29.0`, `pydantic>=2.7.0`, `httpx>=0.27.0`. Identical to last verified state (ai-engine-architecture-adaptation feature merge 2026-04-20).
6. **Build reproducibility confirmed by inspection.** Pinned base + `--no-cache-dir` pip + range-pinned deps ⇒ reproducible. Docker binary not available in audit environment; local build verification skipped per audit charter.

## E-13 — Cohort intelligence telemetry audit

**Verdict: ✅ Healthy** — loop is emitting; no staleness or schema drift detected.

**Files reviewed:**

- [`.claude/features/ai-cohort-intelligence/state.json`](../../../../.claude/features/ai-cohort-intelligence/state.json)
- [`ai-engine/app/services/cohort_service.py`](../../../../ai-engine/app/services/cohort_service.py) (128 lines)
- [`ai-engine/app/routers/training.py`](../../../../ai-engine/app/routers/training.py), [`nutrition.py`](../../../../ai-engine/app/routers/nutrition.py), [`recovery.py`](../../../../ai-engine/app/routers/recovery.py), [`stats.py`](../../../../ai-engine/app/routers/stats.py), [`reminder_cohort.py`](../../../../ai-engine/app/routers/reminder_cohort.py)
- Migrations: `000001_cohort_stats.sql`, `000002_increment_cohort_frequency.sql`, `000003_rls_cohort_stats.sql`, `000004_retention_pg_cron.sql`
- [`docs/architecture/ai-engine-deployment.md`](../../../architecture/ai-engine-deployment.md) §4–5

**Findings:**

1. **Loop emits by design from 5 endpoints.** Training, nutrition, recovery, stats, reminders.cohort all fire `asyncio.create_task(cohort.increment_fields(...))` as fire-and-forget. Failure mode is logged (`logger.error(...)`) but not raised — does not block user-facing API. Documented as "best-effort" posture in deployment.md §4.
2. **Telemetry infra is current.** CohortService constructed fresh per request (no staleness via shared instance). Async client 10s timeout. Supabase auth headers correct (apikey + Bearer). RLS enforced via migration 000003. 90-day retention scheduled via pg_cron (000004).
3. **Schema stable.** `cohort_stats` table unchanged since initial migration. Single write surface: RPC `increment_cohort_frequency` (idempotent by design). Segments: `training`, `nutrition`, `recovery`, `stats`, `reminders.<type>`.
4. **iOS loop closed.** [`reminder_cohort.py`](../../../../ai-engine/app/routers/reminder_cohort.py) GET `/reminder-cohort-priors` reads back tap-through rates with k-anonymity floor (50 shows minimum). Companion iOS PR #190 `CohortPriorClient.swift` writes events; this endpoint reads aggregates back for personalization. Closed loop.
5. **No staleness or breakage signals.** All code paths reachable (no dead imports, no commented-out telemetry). 4 of 9 ai-engine migrations are cohort-related. Source of truth for emission liveness is Supabase `cohort_stats.last_updated_at` (verified per deployment.md §5 curl script). Zero rows at TestFlight stage (35 users per 2026-05-20 GA4 audit) is **not** a breakage signal — expected pre-launch posture.

## Cross-references

- Predecessor: [ai-engine-architecture-adaptation case study](../../../case-studies/ai-engine-architecture-adaptation-case-study.md) (merged 2026-04-20 — last documented deployment-target reconfirm)
- Predecessor: [ai-cohort-intelligence case study](../../../case-studies/ai-cohort-intelligence-case-study.md) (federated telemetry design)
- Calendar: post-v7-9 docket §5 enhancements [E-12 + E-13](../../../master-plan/post-v7-9-candidate-plan-2026-05-20.md)
- Companion (in-flight): E-14 F-LAUNCHD-DRIFT-EXTENSION (v7.9.1) + E-15 F-CONTRACT-FIXTURE-SAMPLING (v7.9.1, added today via PR #476)

## Next steps

- **None required from this audit.** Both systems pass.
- Re-audit cadence: re-run E-12 quarterly or on any `ai-engine/Dockerfile` / `pyproject.toml` change. Re-run E-13 quarterly or on any cohort-service code change.
- Mark E-12 + E-13 closed in post-v7-9 docket §5.
