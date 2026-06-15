# UX Spec — foundation-models-tier3 (on-device summary surface)

Work subtype: `new_ui` (additive content on existing cards). Research: [ux-research.md](ux-research.md).
**No new tokens, no new components.** All symbols below are verified to exist (see `/ux preflight`).

## Surfaces

### S1 — AIRecommendationCard (full card in AIIntelligenceSheet)
File: `FitTracker/Views/AI/AIRecommendationCard.swift`. Add a summary headline **between** the segment
header (line ~20) and the `recommendationText` body (line ~23):

```
[segment header: icon + "Recovery"]            ← existing
[summary headline]   ← NEW, only when recommendation.summary != nil
[recommendationText: joined signals]           ← existing
[badges: confidence + sourceTier]              ← existing
```

- Typography: `AppText.subheading` (matches the card's most prominent text ramp).
- Color: `AppColor.Text.primary`.
- Layout: same `VStack(alignment:.leading, spacing: AppSpacing.small)`; `.fixedSize(horizontal:false, vertical:true)` so it wraps (full card = multi-line OK).
- When `summary == nil`: render nothing (no empty spacing) — card is byte-identical to today.

### S2 — AIInsightCard (compact Home card)
File: `FitTracker/Views/AI/AIInsightCard.swift`. When `primaryRecommendation?.summary` is non-nil, it
becomes the **title source** (`insightTitle`), keeping `.lineLimit(2)`; the existing `insightSubtitle`
("Tap to see all AI recommendations") stays as the 1-line CTA. When summary is nil → today's
`humanReadableSignal(...)` mapping is used unchanged.

## States (all 5)

| State | S1 (full card) | S2 (Home card) |
|---|---|---|
| **Empty** (no recommendation) | card not rendered | "Analyzing your data..." (unchanged) |
| **Loading** (`isProcessing`) | n/a (sheet shows existing spinner) | existing avatar `.shimmer`/`.breathe` (unchanged) |
| **Error** (FM failed / unavailable) | summary nil → signal body only (today's behavior) | summary nil → `humanReadableSignal` (today's behavior) |
| **Success, summary present** (on_device/pcc) | summary headline + signals + badges | summary as title + CTA subtitle |
| **Success, summary absent** (cloud/local) | signals + badges (unchanged) | `humanReadableSignal` title (unchanged) |

The **summary-absent success** state is the critical compatibility state: cloud/local recommendations
have `summary == nil`, so the cards must look exactly as they do today.

## Accessibility
- S1: fold summary into the existing combined `accessibilityLabel` → `"\(segment) recommendation: \(summary ?? recommendationText). Confidence: \(confidenceLabel)"`.
- S2: existing label already reads `insightTitle` (which becomes the summary when present) + subtitle — no structural change; summary is spoken via `insightTitle`.
- Dynamic Type: inherited via `AppText` ramps. VoiceOver: no new focusable nodes.
- Tap targets unchanged (≥44pt — existing button surfaces).

## Motion
None added. Summary appears on the normal recommendation-refresh render; no bespoke animation.

## Design-system compliance (self-check)
| Check | Status | Detail |
|---|---|---|
| Token compliance | PASS | Reuses `AppText.subheading/.body/.caption`, `AppColor.Text.primary/.secondary/.tertiary`, `AppSpacing.small/.medium`, `AppRadius.card` — all already on these files |
| Component reuse | PASS | No new components; plain `Text` in existing `VStack` |
| Pattern consistency | PASS | Same card layout pattern; summary slots into existing hierarchy |
| Accessibility | PASS | Folds into existing combined labels; Dynamic Type inherited |
| Motion | PASS | None added |

## Symbols cited (for /ux preflight)
`AppText.subheading`, `AppText.body`, `AppText.caption`, `AppColor.Text.primary`, `AppColor.Text.secondary`,
`AppColor.Text.tertiary`, `AppSpacing.small`, `AppSpacing.medium`, `AppRadius.card`,
`AIRecommendation.summary` (NEW field, T1), `AIRecommendation.signals`, `AIInsightCard.insightTitle`,
`AIRecommendationCard.recommendationText`.

## v2-refactor-checklist
N/A — `work_subtype: new_ui`, additive to existing cards (not a v1→v2 refactor).
