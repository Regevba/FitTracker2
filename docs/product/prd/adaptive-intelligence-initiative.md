# PRD: Adaptive Intelligence Initiative

> **ID:** adaptive-intelligence | **Status:** Implementation | **Priority:** P0
> **Work Type:** Feature (full 9-phase lifecycle)
> **Children:** readiness-score-v2, ai-engine-v2, ai-recommendation-ui
> **Last Updated:** 2026-04-10

---

## Purpose

Transform FitMe from a passive tracking app into an adaptive AI coaching platform. Three connected features form a compute → adapt → surface pipeline where the brand icon comes alive as the AI's visual persona.

## Business Objective

The readiness score answers "should I train today?" The AI engine adapts that answer to the user's goals and history. The recommendation UI surfaces it through a living brand avatar. Together they create the "intelligent coaching" differentiator that no single-feature competitor can match. This is the highest-leverage initiative in the roadmap — it touches every screen and every data source in the app.

## Target Persona(s)

- **Primary:** The Data-Driven Optimizer — monitors HRV, sleep stages, training load. Wants precision, explanation, and personalization.
- **Secondary:** The Consistent Lifter — wants a clear go/no-go signal with actionable guidance.
- **Tertiary:** The Health-Conscious Professional — cares about recovery quality and sleep; responds to low-friction AI nudges.

---

## System Architecture

```
Health Data Sources                    User-Facing Surface
─────────────────                      ──────────────────
Apple Watch (HealthKit)  ─┐            ┌─ AI Recommendation Cards
Xiaomi S400 Scale        ─┤            ├─ ReadinessCard (enhanced)
Training Log (RPE, vol)  ─┼──▶ ReadinessEngine ──▶ AIOrchestrator ──▶ Brand Icon Avatar
Nutrition Log            ─┤    (Child 1:         (Child 2:          (Child 3:
User Goals (onboarding)  ─┘     COMPUTE)           ADAPT)            SURFACE)
```

## Data Flow

1. ReadinessEngine computes a 5-component score from health data (Child 1).
2. AISnapshotBuilder feeds ReadinessResult into LocalUserSnapshot (Child 1 → Child 2 handoff).
3. AIOrchestrator runs a 3-tier pipeline: local fallback → cloud cohort → Foundation Model (Child 2).
4. AI Recommendation UI surfaces insights through the animated brand icon (Child 2 → Child 3 handoff).
5. User feedback feeds back into the learning cache for progressive personalization (Child 3 → Child 1 loop).

---

## Child Features

| Child | ID | Work Type | Status | PRD |
|-------|----|-----------|--------|-----|
| Readiness Score v2 | readiness-score-v2 | Enhancement | Implementation (PRD + code WIP) | `prd/readiness-score-formula-v2.md` |
| AI Engine v2 | ai-engine-v2 | Enhancement | PRD phase | `prd/ai-engine-v2.md` |
| AI Recommendation UI | ai-recommendation-ui | Feature | PRD phase | `prd/ai-recommendation-ui.md` |

**Implementation order:** Child 1 → Child 2 → Child 3 (sequential, not parallel).

- Child 1 (Readiness Score v2) must complete first — it produces `ReadinessResult`.
- Child 2 (AI Engine v2) depends on Child 1 — consumes `ReadinessResult`.
- Child 3 (AI Recommendation UI) depends on Child 2 — displays `AIRecommendation`.

---

## Brand Icon as AI Avatar

The FitMe brand icon (4 intertwined circles: pink `#F5B8E8`, yellow `#FFBD12`, blue `#85D6FF`, teal `#33E0C2`) is the AI's visual persona. Existing components:

| Component | Role |
|-----------|------|
| `FitMeBrandIcon` | Static identity — 4 sizes |
| `FitMeLogoLoader` | Animated — 4 modes mapping to AI states |

Animation mode to AI state mapping:

| Mode | AI State |
|------|----------|
| `.breathe` | Ambient awareness (idle) |
| `.rotate` | Syncing data |
| `.pulse` | New insight ready |
| `.shimmer` | Computing / thinking |

The AI never speaks as text-only. Every AI surface has the animated brand icon as the "speaker", creating a conversational feeling analogous to Siri's orb.

---

## Shared Success Metrics

| Metric | Baseline | Target | Owner |
|--------|----------|--------|-------|
| Primary: AI recommendation engagement rate | 0% (no UI exists) | >40% of home screen sessions interact with AI insight | Child 3 |
| Secondary: Readiness score viewed per session | ~30% (ReadinessCard page) | >60% | Child 1 |
| Secondary: Recommendation adherence | N/A | >50% follow the suggested intensity | Child 2 |
| Secondary: AI avatar animation seen | 0% | >80% of sessions see at least one animation state | Child 3 |
| Guardrail: Crash-free rate | >99.5% | >99.5% | All |
| Guardrail: Cold start time | <2s | <2s | All |
| Guardrail: Home screen load | <500ms | <500ms | Child 1 |

## Kill Criteria

- Readiness score correlation with self-reported outcomes is negative.
- Users consistently override AI recommendations at a rate above 80%.
- AI computation adds more than 100ms to home screen load.
- Avatar animations cause frame drops below 60 fps.

---

## Phase Plan

| Phase | Name | Status |
|-------|------|--------|
| Phase 0 | Research | COMPLETE — 20 evidence references gathered for readiness formula |
| Phase 1 | PRD | IN PROGRESS — this document + 3 child PRDs |
| Phase 2 | Tasks | Pending — task breakdown per child |
| Phase 3 | UX / Design | Pending — UX spec for AI avatar interactions, recommendation card design |
| Phase 4 | Implement | Pending — Child 1 → Child 2 → Child 3 |
| Phase 5 | Test | Pending — unit tests + integration tests + UI tests |
| Phase 6 | Review | Pending — parallel diff, high-risk file check (`AIOrchestrator` is high-risk) |
| Phase 7 | Merge | Pending — single PR or per-child PRs (user decides) |
| Phase 8 | Docs | Pending — analytics taxonomy, feature memory, case study potential |

---

## Risk Register

| Risk | Severity | Mitigation |
|------|----------|------------|
| `AIOrchestrator` is a high-risk file | High | Extra review in Phase 6. All changes must be backwards-compatible. |
| Foundation Model API not available pre-iOS 26 | Medium | `FallbackFoundationModel` already handles this (returns confidence 0, uses local rules). |
| Cloud backend (Railway) downtime | Medium | Local fallback tier produces baseline recommendations. |
| Avatar animations impact performance | Low | `FitMeLogoLoader` already respects `reduceMotion`. Frame budget: <5ms per frame. |
| Formula not validated on large population | Medium | Start with literature-backed defaults. Collect self-reported feedback for calibration. |

---

## Out of Scope

- Third-party wearable integrations (Garmin, Whoop, Oura) — deferred to a future Phase B MCP adapters milestone.
- Custom formula weight editing by the user.
- Social or competitive readiness features.
- Apple Watch complication for readiness score.
