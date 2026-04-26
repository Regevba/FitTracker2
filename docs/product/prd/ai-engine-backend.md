# PRD: AI Engine Backend

> **ID:** Backend | **Status:** Shipped | **Priority:** P1
> **Last Updated:** 2026-04-04

> **Status note (2026-04-26):** No standalone `.claude/features/` directory exists for this PRD. This is intentional — the work is bundled under the `adaptive-intelligence-initiative` parent feature (specifically the `ai-engine-v2` enhancement, which is the iOS-side consumer of this Railway-hosted backend) and the AI cohort intelligence surface (`18.9-ai-cohort-intelligence.md`). State tracking happens at the parent level. The backend code itself is hosted in a separate repository.

---

## Purpose

Provide a cloud backend for FitMe's federated AI system — receiving banded categorical data from the iOS app, computing cohort-level signals, and returning anonymized recommendations.

## Business Objective

The AI Engine enables population-level insights ("users like you who train 4x/week eat 1.8g/kg protein") without exposing individual data. This creates a network effect: more users → better signals. The backend is the competitive moat for FitMe's "privacy-first intelligence" positioning.

## Current Implementation

### Architecture
| Component | Technology | Details |
|-----------|------------|---------|
| Framework | FastAPI (Python) | Async, high-performance |
| Hosting | Railway | Managed deployment |
| Auth | JWT with JWKS validation | iOS app authenticates via signed tokens |
| Privacy | Banded categorical input only | No PII received |
| Anonymity | k≥50 floor | Cohort signals require minimum 50 matching users |

### API Contract
- **Input:** Banded `LocalUserSnapshot` (age band, BMI band, sleep band, training frequency band, etc.)
- **Output:** `AIRecommendation` with segment, signals[], confidence, escalateToLLM flag
- **Auth:** JWT Bearer token, validated against JWKS endpoint

### Privacy Guarantees
- Server receives ONLY categorical bands (e.g., "25-34", "18.5-24.9")
- No raw values, names, device IDs, or PII
- k-anonymity: requires ≥50 users in cohort before returning signals
- Banding functions defined client-side (AITypes.swift)

## Key Files
| File | Purpose |
|------|---------|
| `FitTracker/AI/AIEngineClient.swift` | iOS URLSession client |
| `FitTracker/AI/AITypes.swift` | Banding functions, request/response types |

## Success Metrics

| Metric | Baseline | Target | Instrumentation |
|--------|----------|--------|-----------------|
| API latency (p50) | N/A — pre-launch (T2 — Declared, 2026-04-26) | <500ms (T2 — Declared) | Railway metrics |
| API latency (p95) | N/A — pre-launch (T2 — Declared, 2026-04-26) | <2s (T2 — Declared) | Railway metrics |
| Uptime | N/A — pre-launch (T2 — Declared, 2026-04-26) | >99.5% (T2 — Declared) | Railway monitoring |
| k-anonymity compliance | N/A — pre-launch (T2 — Declared, 2026-04-26) | 100% (T2 — Declared) | Server-side validation |
| Kill criteria | API uptime <97% sustained for 30 days OR p95 latency >5s sustained for 14 days OR ANY confirmed PII leak in transit/at-rest → backend is considered failed and the cohort tier is disabled while the API is rebuilt or replaced (T2 — Declared, 2026-04-26) | — | Railway metrics + server logs |

## Gaps & Improvements

| Gap | Priority | Notes |
|-----|----------|-------|
| No monitoring/alerting setup | Medium | Railway metrics not configured |
| No load testing | Medium | Unknown capacity limits |
| Backend code not in this repo | Info | Hosted separately |
| No A/B testing for recommendation quality | Low | All users get same cohort logic |
