# AI Engine — Deployment Status & Architecture

> **Closes C13** from [`post-v7-9-candidate-plan-2026-05-20.md`](../master-plan/post-v7-9-candidate-plan-2026-05-20.md) §4 ("Document `ai-engine/` deployment status (Railway? Vercel? local-only?)"). Also unblocks **E-13** cohort-intelligence telemetry runtime verification ([`must-have-cadence-followups.md`](../../.claude/shared/must-have-cadence-followups.md)).
>
> **Last verified:** 2026-05-24 by cross-referencing source files. Production URL confirmed live in [`Config/Base.xcconfig:7`](../../Config/Base.xcconfig) + [`FitTracker/FitTrackerApp.swift:11`](../../FitTracker/FitTrackerApp.swift) fallback. Per [`ai-engine/README.md`](../../ai-engine/README.md) `## Deployment Notes`: "Current deployment target: Railway."

## TL;DR

- **Production:** `https://fittracker-ai-production.up.railway.app` — live; iOS app calls it via `AIEngineClient`
- **Staging:** NOT configured (placeholder `https://staging-config-required.invalid` in [`Config/Staging.xcconfig:8`](../../Config/Staging.xcconfig))
- **CI/CD:** No GitHub Actions workflow auto-deploys `ai-engine/` — Railway picks up changes via its own Git integration (operator-configured outside this repo's `.github/workflows/`)
- **Runtime:** FastAPI on Python 3.12, single uvicorn process, port 8000
- **Telemetry surface:** 5 endpoints write to Supabase `cohort_stats` via fire-and-forget `asyncio.create_task()` — failures are logged via `logger.error()`, never block HTTP response

## 1. Service identity

| Field | Value | Source |
|---|---|---|
| Service name | `fittracker-ai` | [`ai-engine/pyproject.toml:6`](../../ai-engine/pyproject.toml) |
| Description | "FitTracker federated cohort intelligence engine" | Same |
| Production URL | `https://fittracker-ai-production.up.railway.app` | [`Config/Base.xcconfig:7`](../../Config/Base.xcconfig) + [`FitTracker/FitTrackerApp.swift:11`](../../FitTracker/FitTrackerApp.swift) |
| Deployment platform | Railway | [`ai-engine/README.md`](../../ai-engine/README.md) `## Deployment Notes` |
| Runtime | Python 3.12 + FastAPI + uvicorn | [`ai-engine/Dockerfile`](../../ai-engine/Dockerfile) |
| Port | 8000 (exposed) | Same |
| Build manager | hatchling | [`ai-engine/pyproject.toml`](../../ai-engine/pyproject.toml) |

## 2. iOS client wiring

```
Config/Base.xcconfig (production)
  FITTRACKER_AI_ENGINE_BASE_URL = "https://fittracker-ai-production.up.railway.app"
        ↓ (xcconfig substitution at build time)
FitTracker/Info.plist:8
  <key>FITTRACKER_AI_ENGINE_BASE_URL</key>
  <string>$(FITTRACKER_AI_ENGINE_BASE_URL)</string>
        ↓ (read at app launch)
FitTracker/FitTrackerApp.swift:11
  let urlString = plistValue.isEmpty
    ? "https://fittracker-ai-production.up.railway.app"  // hardcoded fallback
    : plistValue
        ↓ (DI into AIEngineClient)
FitTracker/AI/AIEngineClient.swift
  init(baseURL: URL, session: URLSession = .shared)
```

**Hardcoded fallback** at [`FitTracker/FitTrackerApp.swift:11`](../../FitTracker/FitTrackerApp.swift) means the iOS app always points at production-Railway even when the xcconfig substitution fails silently. This is intentional (no silent local-only mode) but means staging is not currently a separate target — see §6 known gaps.

## 3. Endpoints

Base path: `/v1`. Health check: `GET /health`. Insight endpoints (all `POST`):

| Endpoint | Segment written to `cohort_stats` | Router file |
|---|---|---|
| `POST /v1/training/insight` | `training` | [`ai-engine/app/routers/training.py:31`](../../ai-engine/app/routers/training.py) |
| `POST /v1/nutrition/insight` | `nutrition` | [`ai-engine/app/routers/nutrition.py:30`](../../ai-engine/app/routers/nutrition.py) |
| `POST /v1/recovery/insight` | `recovery` | [`ai-engine/app/routers/recovery.py:30`](../../ai-engine/app/routers/recovery.py) |
| `POST /v1/stats/insight` | `stats` | [`ai-engine/app/routers/stats.py:30`](../../ai-engine/app/routers/stats.py) |
| `POST /v1/reminders/cohort/event` | `reminders.<sub>` (multi-segment) | [`ai-engine/app/routers/reminder_cohort.py:96`](../../ai-engine/app/routers/reminder_cohort.py) |

Auth: Supabase JWT (`Authorization: Bearer <token>`) validated against Supabase JWKS by [`ai-engine/app/auth/jwt_validator.py`](../../ai-engine/app/auth/jwt_validator.py). Required env vars: `SUPABASE_URL` + `SUPABASE_SERVICE_KEY` + `SUPABASE_JWKS_URL` + `SUPABASE_JWT_AUDIENCE`.

## 4. Federated cohort intelligence loop (telemetry surface)

```
iOS app                ai-engine                    Supabase
  │                       │                            │
  │ POST /v1/.../insight  │                            │
  │ ────────────────────► │                            │
  │                       │ async (fire-and-forget):   │
  │                       │ cohort.increment_fields()  │
  │                       │ ─────────────────────────► │
  │                       │   RPC                      │
  │                       │   increment_cohort_frequency
  │  HTTP response        │                            │
  │ ◄──────────────────── │                            │
  │  (does not block on   │                            │
  │   cohort write)       │                            │
```

**Implementation:** [`ai-engine/app/services/cohort_service.py::CohortService.increment_fields`](../../ai-engine/app/services/cohort_service.py)

- Each insight call fires `asyncio.create_task(cohort.increment_fields("<segment>", fields))`
- `increment_fields` POSTs to `{SUPABASE_URL}/rest/v1/rpc/increment_cohort_frequency` per (segment, field_name, field_value) tuple
- Failure mode: HTTP non-2xx → `logger.error("cohort write failed segment=... field=... error=...")` → loop continues with next field
- Success mode: silent (no `logger.info` for happy path)

**Read path** ([`get_cohort_totals`](../../ai-engine/app/services/cohort_service.py) + [`list_rows_by_segment_pattern`](../../ai-engine/app/services/cohort_service.py)):

- Gated by k-anonymity floor (`Settings.k_anonymity_floor`); buckets below floor return 0
- Both methods degrade gracefully to empty/zero on Supabase error

## 5. How to verify the loop is emitting (runtime check)

Per E-13 ([cadence-followups](../../.claude/shared/must-have-cadence-followups.md)) the question is: **is the federated learning loop still emitting?**

Run on the operator's machine with Supabase credentials:

```bash
# Last-N-hours freshness check on cohort_stats
curl -s "${SUPABASE_URL}/rest/v1/cohort_stats?select=segment,last_updated_at&order=last_updated_at.desc&limit=10" \
  -H "apikey: ${SUPABASE_SERVICE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_SERVICE_KEY}" | jq '.[] | "\(.segment) \(.last_updated_at)"'

# Per-segment emission rate over last 24h
curl -s "${SUPABASE_URL}/rest/v1/cohort_stats?select=segment,frequency,last_updated_at&last_updated_at=gte.$(date -u -v-24H +%Y-%m-%dT%H:%M:%SZ)" \
  -H "apikey: ${SUPABASE_SERVICE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_SERVICE_KEY}" | jq 'group_by(.segment) | map({segment: .[0].segment, rows: length})'
```

**Expected health signal (iOS pre-launch, 35 TestFlight testers per 2026-05-20 GA4 audit):**

- `last_updated_at` should advance for at least `training` + `nutrition` + `recovery` + `stats` segments within 24h windows when testers actively use the app
- `reminders.*` segments should advance whenever Smart Reminders v2 fires a reminder
- Zero advancement across ALL segments for >7 days = either the Railway service is down OR iOS testers aren't using the app

**Note on iOS pre-launch context:** Per [project memory `feedback_ios_app_not_in_production`](.../memory/feedback_ios_app_not_in_production.md), iOS app is TestFlight beta only. Empty `cohort_stats` rows are NOT a production-signal issue until App Store launch — they're verification-only.

## 6. Known gaps

| # | Gap | Impact | Path forward |
|---|---|---|---|
| 1 | **No CI/CD workflow** auto-deploys `ai-engine/` — Railway picks up changes via its own Git integration (operator-configured outside this repo) | Manual deploy step; no PR-level deploy preview | Add `.github/workflows/ai-engine-deploy.yml` calling Railway CLI on push to `main` when `ai-engine/**` changes — queued as v7.9.1+ candidate |
| 2 | **Staging URL not configured** — [`Config/Staging.xcconfig:8`](../../Config/Staging.xcconfig) is `https://staging-config-required.invalid` | Cannot run iOS app against a non-production ai-engine instance | Spin up `fittracker-ai-staging` Railway service + populate xcconfig (queued post-launch) |
| 3 | **No health-check ping monitor** | Service-down detection is reactive (iOS error logs) not proactive | Add a daily cron that hits `/health` and writes to `.claude/shared/ai-engine-uptime.jsonl` — queued as a Phase E+ chore |
| 4 | **Cohort write happy-path is silent** — only failures logged | No "I am emitting" signal at logger level | Either keep as-is (low-noise) OR add a `logger.debug("cohort write OK")` (verbose) — operator decision |
| 5 | **No PR test coverage on ai-engine routes** | Per [`test-coverage-master-plan-2026-05-13.md`](../master-plan/test-coverage-master-plan-2026-05-13.md) T5, ai-engine has unit tests in [`ai-engine/tests/`](../../ai-engine/tests/) but they don't run in CI on PR. T5 RICE 40.0; queued for v8.0 docket | Mid-priority drift class | Add ai-engine test job to [`.github/workflows/integrity.yml`](../../.github/workflows/integrity.yml) or new dedicated workflow |
| 6 | **Sentry integration paused** ([project memory `project_sentry_integration_in_progress`](.../memory/project_sentry_integration_in_progress.md)) | No error tracking on ai-engine production | Resume Sentry stack post-App-Store launch; ai-engine ingestion is straightforward FastAPI middleware |

## 7. Decisions / Conventions

- **Service is transport-only:** ai-engine must NOT assume app-internal storage or app-only session formats (per [`ai-engine/README.md`](../../ai-engine/README.md))
- **Cohort writes are best-effort:** if Supabase is unreachable, insight calls still succeed; cohort `cohort_stats` row is the SoT for population-level data
- **k-anonymity floor:** read path returns 0 for buckets below `Settings.k_anonymity_floor`; protects against re-identification attacks at low cohort sizes
- **Future extraction:** ai-engine is intended to be extracted into a standalone `fittracker-ai-engine` repo per [`ai-engine/README.md`](../../ai-engine/README.md) "Source of truth for the cloud cohort-insight service. This code is intended to be extracted..."

## 8. Cross-references

- Cadence followups: [`.claude/shared/must-have-cadence-followups.md`](../../.claude/shared/must-have-cadence-followups.md) C13 + E-13
- Test coverage plan: [`docs/master-plan/test-coverage-master-plan-2026-05-13.md`](../master-plan/test-coverage-master-plan-2026-05-13.md) T5
- Sentry pause: [`docs/case-studies/framework-honesty-ledger.md`](../case-studies/framework-honesty-ledger.md)
- iOS analytics context: [project memory `project_session_2026_05_20_v7_9_eve_ga4_audit.md`](../../.claude/projects/-Volumes-DevSSD-FitTracker2/memory/project_session_2026_05_20_v7_9_eve_ga4_audit.md) (35 TestFlight users, 0 fitme-story web users)
