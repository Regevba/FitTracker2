# FitTracker AI Engine

Source of truth for the cloud cohort-insight service. This code is intended to be extracted into the future `fittracker-ai-engine` repo; until then, edit this directory for AI service behavior.

## What It Does

- Serves population-level cohort insight endpoints for `training`, `nutrition`, `recovery`, and `stats`
- Accepts only banded categorical payloads
- Requires a real backend JWT in `Authorization: Bearer <token>`
- Returns rule-based cohort signals that the app can combine with on-device personalisation
- Sets `escalate_to_llm` (when `confidence < 0.40`) as a hint the app may act on — **not** a server-side LLM call

## On-device Tier 3 (iOS) — relationship to this service

This service is **Tier 2** (cloud cohort). The iOS app layers two on-device tiers on top, in
`FitTracker/AI/` (see `AIOrchestrator`):

- **Tier 3a — on-device personalization** (`FoundationModelService`): real `LanguageModelSession` +
  `@Generable` guided generation turns this service's signals into a curated set + a natural-language
  coaching `summary`. PII never leaves the device. *In flight: PR #724 (foundation-models-tier3), not
  yet merged.*
- **Tier 3b — PCC escalation** (`PCCEscalationService`): consumes `escalate_to_llm` **on-device** via
  Apple Private Cloud Compute — so this service needs **no `LLM_API_KEY` and no DPA**. *Architecture
  shipped behind the `FOUNDATION_MODELS_PCC` flag; dormant until the WWDC26 PCC API lands in the iOS SDK.*

`escalate_to_llm` is therefore a transport-only hint; this service never makes an LLM call itself.

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
