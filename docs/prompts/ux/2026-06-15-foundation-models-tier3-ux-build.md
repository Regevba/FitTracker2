# UX Build Prompt — foundation-models-tier3 (on-device summary surface)

**What & why.** The on-device Foundation Model (Tier 3a) now produces a short natural-language
coaching `summary` for each AI recommendation. Surface it on the two existing AI cards. Summary is
`nil` for cloud/local recommendations — those must render exactly as today.

**Surfaces (existing files, additive):**
1. `FitTracker/Views/AI/AIRecommendationCard.swift` (full card in AIIntelligenceSheet) — summary as a
   headline `Text` (`AppText.subheading`, `AppColor.Text.primary`) between the segment header and the
   joined-signals body. Multi-line OK (`.fixedSize(horizontal:false, vertical:true)`).
2. `FitTracker/Views/AI/AIInsightCard.swift` (compact Home card) — when `primaryRecommendation?.summary`
   is non-nil, it becomes `insightTitle` (keep `.lineLimit(2)`); subtitle stays as the CTA.

**States:** see ux-spec.md §States — the critical one is *summary-absent success* (cloud/local) which
must be byte-identical to today's rendering.

**Accessibility:** fold summary into the existing combined `accessibilityLabel` on both cards. Dynamic
Type inherited via `AppText`. No new focusable nodes, no new tap targets.

**Tone:** summary copy follows "Celebration not guilt" — encouraging, no medical claims (enforced at
generation via `@Guide` + manual-eval kill criterion KC2).

**Do NOT:** add new tokens/components, change layout when summary is nil, add animation.
