# PRD: AI Engine Backend

> **ID:** Backend | **Status:** Shipped | **Priority:** P1
> **Last Updated:** 2026-04-04

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

| Metric | Target | Instrumentation |
|--------|--------|-----------------|
| API latency (p50) | <500ms | Railway metrics |
| API latency (p95) | <2s | Railway metrics |
| Uptime | >99.5% | Railway monitoring |
| k-anonymity compliance | 100% | Server-side validation |

## Gaps & Improvements

| Gap | Priority | Notes |
|-----|----------|-------|
| No monitoring/alerting setup | Medium | Railway metrics not configured |
| No load testing | Medium | Unknown capacity limits |
| Backend code not in this repo | Info | Hosted separately |
| No A/B testing for recommendation quality | Low | All users get same cohort logic |
