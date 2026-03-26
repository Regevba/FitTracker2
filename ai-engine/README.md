# FitTracker AI Engine

Source of truth for the cloud cohort-insight service. This code is intended to be extracted into the future `fittracker-ai-engine` repo; until then, edit this directory for AI service behavior.

## What It Does

- Serves population-level cohort insight endpoints for `training`, `nutrition`, `recovery`, and `stats`
- Accepts only banded categorical payloads
- Requires a real backend JWT in `Authorization: Bearer <token>`
- Returns rule-based cohort signals that the app can combine with on-device personalisation

## Current Contract

- Base path: `/v1`
- Health check: `GET /health`
- Insight endpoints:
  - `POST /v1/training/insight`
  - `POST /v1/nutrition/insight`
  - `POST /v1/recovery/insight`
  - `POST /v1/stats/insight`
- Invalid token shapes are rejected before JWKS lookup
- Local app session identifiers are not valid auth tokens for this service

## Local Development

Install dependencies from this directory:

```bash
pip install ".[dev]"
pytest -v
```

Required environment variables:

- `SUPABASE_URL`
- `SUPABASE_SERVICE_KEY`
- `SUPABASE_JWKS_URL`
- `SUPABASE_JWT_AUDIENCE`

## Deployment Notes

- Runtime framework: FastAPI on Python 3.12
- Current deployment target: Railway
- JWT validation uses Supabase JWKS and requires RS256 tokens with `role == "authenticated"`
- This service should stay transport-only: it must not assume app-internal storage or app-only session formats
