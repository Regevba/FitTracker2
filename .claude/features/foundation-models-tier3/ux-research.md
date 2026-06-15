# UX Research — foundation-models-tier3 (summary surface)

Scope: the on-device-generated natural-language `summary` rendered on two existing AI surfaces —
the compact **AIInsightCard** (Home tab) and the full **AIRecommendationCard** (AIIntelligenceSheet).
No new screens. This is an additive content layer on shipped cards.

## Applicable UX principles (from docs/design-system/ux-foundations.md + iOS HIG)

| Principle | How it applies |
|---|---|
| **Progressive disclosure** | Home card shows a 1-line summary preview (`lineLimit(1)` slot already exists at `AIInsightCard.insightSubtitle`); the full multi-line summary lives in the sheet's `AIRecommendationCard`. Don't dump prose on Home. |
| **Recognition over recall** | The summary is plain language ("Your sleep's been short — keep today's session light") vs. raw signal keys. Reduces the cognitive translation the user does today. |
| **Feedback** | Summary presence is itself feedback that the AI personalized for *this* user; pairs with the existing confidence badge + thumbs feedback. |
| **Celebration not guilt** (FitMe-specific) | Summary copy must follow the same encouraging tone enforced in `humanReadableSignal` — never judgmental, no medical claims. Enforced at generation via `@Guide` description + the manual-eval kill criterion KC2. |
| **Consistency** | Reuse the exact typography/spacing/color tokens already on these cards. No new tokens. |
| **Accessibility (HIG)** | Summary must fold into the existing `accessibilityLabel` (combined element) so VoiceOver reads it; Dynamic Type via existing `AppText` tokens; respect `lineLimit` to avoid layout breakage. |

## iOS HIG references
- Cards/list content: keep primary text scannable; secondary text truncates gracefully.
- VoiceOver: the cards already use `.accessibilityElement(children: .combine)` / explicit `accessibilityLabel` — summary must be woven in, not added as a separate unreadable node.
- Dynamic Type: all text uses semantic `AppText` ramps → summary inherits scaling for free.

## Decision
Render summary as: (a) the **title source** on `AIInsightCard` when present (replaces the signal-derived `insightTitle`), keeping the 1-line subtitle as the call-to-action; (b) a **headline `Text` above** the signal body on `AIRecommendationCard`. Both gated on `summary != nil` so non-personalized (cloud/local) recommendations render exactly as today. No new tokens, no new components.
