# AI Recommendation UI — Child PRD

| Field | Value |
|---|---|
| **ID** | ai-recommendation-ui |
| **Status** | PRD |
| **Priority** | P1 |
| **Parent** | adaptive-intelligence-initiative |
| **Work Type** | Feature (full 9-phase lifecycle — new UI surface) |
| **GitHub Issue** | #46 |
| **Last Updated** | 2026-04-10 |

---

## Purpose

Create the user-facing surface for AI-generated recommendations, using the FitMe brand icon as a living, communicative AI avatar. This is where the intelligence layer becomes visible — the brand icon breathes, pulses, and shimmers as the AI works, and delivers personalized insights across training, nutrition, recovery, and stats.

---

## Business Objective

The AI engine (AIOrchestrator) currently generates recommendations across 4 segments but has zero user-facing display. The feature is architecturally complete (cloud engine, local fallback, Foundation Model stub) but orphaned from the UI. This PRD creates the surface that makes the intelligence visible and actionable.

---

## Design Philosophy — Brand Icon as AI Avatar

The FitMe brand icon (4 intertwined circles: pink #F5B8E8, yellow #FFBD12, blue #85D6FF, teal #33E0C2 with gradient "FitMe" text) is the AI's visual persona. Existing components:

- `FitMeBrandIcon` (`FitMeBrandIcon.swift`) — static icon, 4 sizes (small 44pt, medium 72pt, large 120pt, hero 180pt)
- `FitMeLogoLoader` (`FitMeLogoLoader.swift`) — animated icon with 4 modes + 3 sizes + reduce-motion support

### Animation Mode to AI State Mapping

| Mode | AI State | Description |
|------|----------|-------------|
| `.breathe` | Idle / ambient awareness | Slow scale 0.92–1.08, continuous. AI is present, listening. |
| `.rotate` | Syncing data | 360-degree rotation. HealthKit pull, scale import, cloud sync. |
| `.pulse` | New insight ready | Scale burst 1.0–1.15, single pulse. AI has something to share. |
| `.shimmer` | Computing / thinking | Opacity oscillation 0.4–1.0. Readiness calculation, pattern analysis. |

The AI never speaks as text-only. Every AI surface includes the animated brand icon as the "speaker" — creating a conversational presence analogous to Siri's orb.

---

## Screens to Create

### 1. AI Insight Card (Home screen — inline)

A compact card that appears on the Home tab below the ReadinessCard. Displays the brand icon (animated) alongside the most important current insight.

Structure:

```
┌─────────────────────────────────────────┐
│  [FitMeLogoLoader .breathe]             │
│  "Your sleep quality drove today's      │
│   readiness to 82. Full intensity       │
│   recommended — your ACWR is in the     │
│   sweet spot."                          │
│                                         │
│  [Training >]  [Recovery >]  [More >]   │
└─────────────────────────────────────────┘
```

The card shows one insight at a time. Tap segment chips to filter. Tap "More" to open the full AI screen.

---

### 2. AI Intelligence Sheet (full screen — modal or navigation push)

Dedicated surface for browsing all AI recommendations. The brand icon is the hero element at the top, animating based on current state.

Structure:

```
┌─────────────────────────────────────────┐
│  [FitMeLogoLoader .breathe (large)]     │
│  "Here's what I see today"              │
│                                         │
│  ── Training ──────────────────────     │
│  [Recommendation card]                  │
│  "Zone 2 cardio, 45min. Your HRV is    │
│   12% above baseline and sleep quality  │
│   was excellent."                       │
│  [Confidence: High] [Source: Local+Cloud]│
│                                         │
│  ── Recovery ──────────────────────     │
│  [Recommendation card]                  │
│  "Watch your hydration — overnight      │
│   weight dropped 1.2%. Consider an      │
│   extra 500ml before training."         │
│  [Confidence: Medium] [Flag: Hydration] │
│                                         │
│  ── Nutrition ─────────────────────     │
│  [Recommendation card]                  │
│  "Protein target: 140g. You've been     │
│   averaging 128g this week."            │
│  [Confidence: High]                     │
│                                         │
│  ── Your Readiness Breakdown ──────     │
│  [HRV: 85] [Sleep: 72] [Load: 90]      │
│  [RHR: 78] [Body: ! Hydration]         │
│  [Overall: 82 — Push Hard]             │
│                                         │
│  ── Was this helpful? ─────────────     │
│  [Yes]  [Not quite]                    │
└─────────────────────────────────────────┘
```

---

### 3. Enhanced ReadinessCard (Page 0 update)

The existing ReadinessCard Page 0 gets the brand icon avatar and component mini-bars:

- Brand icon (small, `.shimmer`) while computing; transitions to `.breathe` when score is ready
- 5 mini progress bars below the score (HRV, Sleep, Training, RHR, Body)
- Confidence badge (Low / Med / High)
- Tap any mini-bar to open the AI Intelligence Sheet filtered to that component

---

## Key Files

| File | Action |
|------|--------|
| `FitTracker/Views/AI/AIInsightCard.swift` | Create — compact home screen card |
| `FitTracker/Views/AI/AIIntelligenceSheet.swift` | Create — full recommendation surface |
| `FitTracker/Views/AI/AIRecommendationCard.swift` | Create — per-segment recommendation card |
| `FitTracker/Views/AI/AIFeedbackView.swift` | Create — thumbs up/down feedback |
| `FitTracker/Views/Shared/ReadinessCard.swift` | Modify — add component mini-bars + avatar |
| `FitTracker/Views/Main/v2/MainScreenView.swift` | Modify — add AIInsightCard below ReadinessCard |
| `FitTracker/DesignSystem/FitMeLogoLoader.swift` | Modify — add new animation modes if needed (e.g., `.speaking` for active recommendation delivery) |

---

## Navigation

- Home tab → AIInsightCard (inline) → tap → AIIntelligenceSheet (push or sheet)
- ReadinessCard tap on component → AIIntelligenceSheet filtered to that component
- No new tab — AI surfaces within existing navigation. The brand icon is the entry point.

---

## Analytics Events

| Event | Parameters | Screen |
|-------|-----------|--------|
| `home_ai_insight_shown` | `segment`, `confidence`, `source_tier` (local/cloud/foundation) | Home |
| `home_ai_insight_tap` | `segment`, `action` (expand/dismiss) | Home |
| `ai_sheet_opened` | `entry_point` (insight_card/readiness_tap/more_button) | AI Sheet |
| `ai_recommendation_viewed` | `segment`, `confidence` | AI Sheet |
| `ai_feedback_submitted` | `segment`, `rating` (positive/negative), `recommendation_id` | AI Sheet |
| `ai_avatar_state_changed` | `from_state`, `to_state` | Any |

---

## Success Metrics

| Metric | Baseline | Target |
|--------|----------|--------|
| AI insight card impressions per session | 0 | >70% of home loads |
| AI sheet open rate | 0 | >25% of sessions |
| Feedback submission rate | 0 | >15% of viewed recommendations |
| Positive feedback rate | N/A | >60% of submitted feedback |
| Avatar animation frame rate | N/A | 60fps consistently |

---

## Kill Criteria

- Feedback positive rate <40% after 2 weeks
- AI sheet open rate <5% after 2 weeks (users ignore it)
- Avatar animations cause frame drops below 55fps
- Home screen load time increases by more than 100ms

---

## Acceptance Criteria

- [ ] AIInsightCard appears on home screen below ReadinessCard
- [ ] Brand icon animates through states (breathe → shimmer → pulse → breathe)
- [ ] Tapping insight card opens AIIntelligenceSheet
- [ ] 4 segment sections in AIIntelligenceSheet (training, recovery, nutrition, stats)
- [ ] Each recommendation shows confidence level and source tier
- [ ] Readiness component breakdown with mini progress bars
- [ ] Feedback mechanism (thumbs up/down) per recommendation
- [ ] Accessibility: VoiceOver labels for all AI states, reduce-motion respected
- [ ] 6 analytics events instrumented and tested
- [ ] Reads from AIOrchestrator — no direct AI computation in views
- [ ] CI green

---

## Non-Scope

- Chat/conversational AI interface (this is card-based, not chat)
- Push notifications for AI insights (future — tied to notifications feature)
- Historical recommendation archive ("insights this week")
- Apple Watch AI surface
- Dedicated AI tab (insights surface within existing tabs)

---

## Dependencies

- Requires Child 1 (Readiness Score v2) — component breakdown data
- Requires Child 2 (AI Engine v2) — readiness-aware recommendations

---

## UX Foundations Compliance

This is new UI — requires full Phase 3 (UX spec + design compliance gateway) before implementation.

| Principle | Application |
|---|---|
| Principle 1 (Fitts's Law) | Tap targets >=44pt on all insight cards |
| Principle 4 (Data Viz) | Component mini-bars use Chart.* tokens |
| Principle 5 (Feedback) | Avatar animation is the system status feedback |
| Principle 8 (Motion Safety) | FitMeLogoLoader already respects `.accessibilityReduceMotion` |
| Principle 13 (Celebration Not Guilt) | AI tone is encouraging, never judgmental. "Your sleep was short" not "You failed to sleep enough." |
