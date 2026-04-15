# Import Training Plan — UX Spec

## Import Source Picker (Sheet)

4 options in a 2×2 grid:
- **Paste Text** (doc.text icon) — "Paste from AI chat, notes, or coach email"
- **Choose File** (folder icon) — "CSV, JSON, or text file"
- **Scan Document** (doc.viewfinder icon, P1) — "PDF or photo of a program"
- **Share from App** (square.and.arrow.down icon, P2) — "Hevy, Strong, Fitbod export"

Each option: 44pt icon in tinted circle + title (AppText.callout) + subtitle (AppText.caption). Tappable card with AppRadius.card corners.

## Paste Field View

- Large TextEditor (min 200pt height) with placeholder: "Paste your training plan here..."
- Supports: markdown tables, numbered lists, JSON, CSV, prose
- "Parse & Import" CTA at bottom (AppSize.ctaHeight, AppColor.Accent.primary)
- Example format hint below field (AppText.caption, collapsed by default)

## Import Preview View

After parsing:
- **Plan name** field (editable, pre-filled from source)
- **Day cards** in vertical scroll:
  - Header: "Day 1 — Push" (AppText.sectionTitle)
  - Exercise rows:
    - Green checkmark (✓) = auto-matched (confidence ≥ 0.95)
    - Orange pencil (✎) = needs review (0.70-0.94)
    - Red warning (⚠) = unmatched (< 0.70)
    - Each row: exercise name, mapped FitMe name, sets × reps, rest
- **Summary bar**: "{n} exercises, {matched} auto-matched, {review} need review"
- "Confirm & Import" CTA (green, full width)

## Exercise Mapping Review (Sheet)

When tapping orange/red exercise:
- Search field at top (searches 87-exercise library)
- Top 5 suggested matches ranked by string similarity
- Each suggestion: exercise name + muscle groups + confidence %
- Tap to select → returns to preview with green check
- "Skip" option (keeps original name, creates note)

## States
- **Success:** "Plan imported! 🎉" + confetti animation + "{n} exercises mapped" + "Start Training" CTA
- **Error:** "Couldn't parse this format" + suggestions for reformatting + "Try Again" button
- **Partial:** "Imported with {n} unmatched exercises" + option to review or skip

## Token Mapping
- Cards: AppColor.Surface.primary, AppRadius.card
- Match indicators: AppColor.Status.success (green), AppColor.Status.warning (orange), AppColor.Status.error (red)
- CTAs: AppSize.ctaHeight, AppColor.Accent.primary
- All text: AppText tokens (sectionTitle, body, caption, button)
