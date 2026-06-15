# Design Build Prompt — foundation-models-tier3 (summary surface)

**Goal.** Represent the new on-device `summary` headline on the two AI cards as Figma frames for the
spec↔design record. These are additive states on existing app cards (NOT new design-system components),
so build them in a dedicated feature file — do NOT add components to the FitMe Design System Library
(`0Ai7s3fCFqR5JXDW8JvgmD`).

**Frames to build (2):**

1. **S1 — AIRecommendationCard / summary present** (full card, in-sheet):
   - Card container: `AppColor.Surface.secondary`, corner radius `AppRadius.card`, padding `AppSpacing.medium`.
   - VStack (leading, spacing `AppSpacing.small`):
     - Segment header: icon + "Recovery" (`AppText.caption`, `AppColor.Text.secondary`)
     - **Summary headline (NEW):** e.g. "Your sleep's run short this week — keep today's session light and prioritise protein." (`AppText.subheading`, `AppColor.Text.primary`, wraps)
     - Signal body: "local_sleep_debt_flag. cohort_optimal_sleep_recovery_profile" (`AppText.body`, `AppColor.Text.primary`)
     - Badges row: "High" capsule (`AppColor.Status.success`) + "AI" capsule (`AppColor.Surface.tertiary`)

2. **S2 — AIInsightCard / summary present** (compact Home card):
   - HStack (spacing `AppSpacing.medium`): brand logo avatar (small) + VStack:
     - Title = summary, `AppText.subheading`, `AppColor.Text.primary`, `.lineLimit(2)`
     - Subtitle = "Tap to see all AI recommendations", `AppText.caption`, `AppColor.Text.secondary`, `.lineLimit(1)`
   - Trailing: thumbs-up / thumbs-down feedback buttons.

**Reference kit:** iOS and iPadOS 26 (libraryKey in figma-bridge-status). Match FitMe semantic tokens.

**Output:** capture each frame's node ID → write to `state.json.figma_node_ids` and a row in
`docs/design-system/figma-code-sync-status.md`. If MCP build is not performed, set
`state.json.figma_build_status = "deferred_to_prompt"` and this prompt is the handoff artifact.
