# Repository Split Transition

This repository is the staged source for the future `fittracker-app` repo.

## Canonical Sources

- App/runtime truth: this repository
- AI service truth: [`ai-engine/README.md`](../ai-engine/README.md)
- Backend truth: [`backend/README.md`](../backend/README.md)
- Legal truth: separate `FitMe-GDPR-Docs` repository
- Historical plans/specs: `docs/archive/`

## Planned End State

- `fittracker-app`
- `fittracker-ai-engine`
- `fittracker-backend`
- `FitMe-GDPR-Docs`

## Staged Split Rules

- The app keeps only external service configuration such as `AIEngineBaseURL` and backend auth contracts.
- `ai-engine/` and `backend/` remain self-contained so they can be extracted with preserved history.
- App documentation should not duplicate backend or AI implementation details beyond stable public contracts.
- Legal drafts should not be edited in this repo; update the legal repo instead.

## Extraction Guidance

When the split is executed:

1. extract `ai-engine/` with preserved history
2. extract `backend/` with preserved history
3. keep this repo as the app repo
4. remove live `ai-engine/` and `backend/` source trees from the app repo after the new remotes are established
