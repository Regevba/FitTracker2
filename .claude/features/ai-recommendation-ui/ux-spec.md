# AI Recommendation UI — UX Specification

**Feature:** ai-recommendation-ui
**Phase:** 3 (UX/Integration)
**Date:** 2026-04-10
**Status:** Draft — pending Phase 3 approval before view code is written

---

## Screens

### 1. AIInsightCard (Home tab, inline below ReadinessCard)

**Purpose:** Surface the AI's most important current insight in a compact card.

**Layout:**
- Full width, card style (AppColor.Surface.primary background, AppRadius.card corners, AppShadow.card)
- Left: FitMeLogoLoader (size .small, mode .breathe when idle, .pulse when new insight)
- Right: Text content area
  - Title: one-line insight summary (AppText.subheadline, AppColor.Text.primary)
  - Subtitle: supporting detail (AppText.caption, AppColor.Text.secondary)
- Bottom: Horizontal scroll of segment chips (Training, Recovery, Nutrition, Stats) using AppPickerChip
- Tap anywhere on card opens AIIntelligenceSheet

**States:**

| State | FitMeLogoLoader mode | Text | Action |
|-------|---------------------|------|--------|
| Loading | .shimmer | "Analyzing your data..." | None |
| Ready | .breathe | Insight title + subtitle | Tap to open sheet |
| New insight | .pulse (one-shot, then reverts to .breathe) | Insight title + subtitle | Tap to open sheet |
| No data | Static (no animation) | "Connect Apple Health to unlock AI insights" | Connect button |
| Error | Static | "Couldn't reach the AI engine" | Retry button (AppColor.Status.warning) |

**Accessibility:**
- VoiceOver label: "AI insight: [title]. [subtitle]. Double tap to see all recommendations."
- Reduce motion: FitMeLogoLoader uses static opacity fallback — no additional handling needed in the card
- Dynamic Type: text wraps; card height expands to fit content; no truncation at any size class

---

### 2. AIIntelligenceSheet (modal sheet, presented from AIInsightCard)

**Purpose:** Full recommendation surface — browse all AI insights organized by segment.

**Layout:**
- Presented as .sheet with medium detent initially, expandable to large
- Header: FitMeLogoLoader (size .large, mode .breathe), centered, "Here's what I see today" caption below
- Scrollable body:
  - One section per segment (Training, Recovery, Nutrition, Stats)
  - Each section: SectionHeader + one or more AIRecommendationCard(s)
  - After all segments: "Your Readiness Breakdown" section with 5 component bars (reuse componentBar pattern from ReadinessCard)
  - Footer: AIFeedbackView

**States:**

| State | FitMeLogoLoader mode | Content |
|-------|---------------------|---------|
| Loading | .shimmer (large) | "Thinking..." message, no cards shown |
| Ready | .breathe | All recommendation cards populated |
| Partial | .breathe | Segments with data show cards; segments without data show "Not enough data for [segment] insights yet" |
| Empty | Static | "Log a few workouts and meals to unlock personalized insights" |

**Accessibility:**
- VoiceOver: each section is announced with its segment name before cards within it
- Each card reads its full recommendation text and confidence level
- Reduce motion: no parallax, no staggered card entrance animations
- Dynamic Type: cards stack vertically; no horizontal truncation at any size class

---

### 3. AIRecommendationCard (reusable component, used inside AIIntelligenceSheet)

**Purpose:** Display a single AI recommendation with metadata and feedback controls.

**Layout:**
- Card style (AppColor.Surface.secondary background, AppRadius.card corners)
- Top row: segment icon (SF Symbol via AppIcon) + segment name (AppText.caption, AppColor.Text.secondary)
- Middle: recommendation text (AppText.body, AppColor.Text.primary), 2–4 lines max before truncation
- Bottom row left: confidence badge (Capsule shape, AppText.caption) + source tier badge ("Local" / "Cloud" / "AI", AppText.caption)
- Bottom row right: thumbs up button + thumbs down button (AppIcon.checkmark / AppIcon.close, minimum 44pt tap targets)

**Confidence badge colors:**

| Level | Background token |
|-------|-----------------|
| High | AppColor.Status.success |
| Medium | AppColor.Brand.primary |
| Low | AppColor.Status.warning |

**Interaction:**
- Thumbs up/down buttons fire a feedback event immediately on tap
- Buttons are mutually exclusive — tapping one deselects the other
- Selected state: filled icon; unselected state: outlined icon
- No sheet dismissal on feedback tap; feedback is inline

**Accessibility:**
- VoiceOver label for confidence badge: "[High/Medium/Low] confidence"
- VoiceOver label for source badge: "Source: [Local/Cloud/AI]"
- Thumbs up button: "Mark as helpful"
- Thumbs down button: "Mark as not helpful"
- Minimum 44pt tap targets enforced for all interactive elements

---

### 4. AIFeedbackView (footer inside AIIntelligenceSheet)

**Purpose:** Collect aggregate user feedback on overall recommendation quality for the session.

**Layout:**
- Horizontal row: "Was this helpful?" label (AppText.caption, AppColor.Text.secondary) + thumbs up button + thumbs down button
- Spacing: AppSpacing.small between elements
- After tap: inline replacement with "Thanks for the feedback!" + checkmark icon; auto-dismisses after 2 seconds, view returns to initial state

**Feedback payload:**
- segment (string — the segment in view when feedback was submitted, or "all" if at sheet footer)
- rating ("positive" or "negative")
- recommendation_id (string — ID of the last-viewed recommendation, or null if session-level)
- timestamp (ISO 8601)

---

## UX Principles Compliance

| Principle | Application |
|-----------|-------------|
| Fitts's Law | All tap targets >= 44pt. AIInsightCard is full-width (maximum tap area on home). Segment chips meet minimum touch size. |
| Hick's Law | Home surfaces one insight at a time. Sheet groups by segment — user scans a known category, not an unordered list. |
| Progressive Disclosure | Home shows one insight. Tap reveals the full sheet. Sheet organizes detail by segment. No information is forced upfront. |
| Recognition over Recall | Segment icons paired with text labels. Confidence communicated via color badge, not a numeric score. Source tier uses plain language ("Local", "Cloud", "AI"). |
| Feedback and System Status | FitMeLogoLoader animation mode is the primary status indicator. Each state (Loading/Ready/Error) has a distinct visual and textual signal. |
| Error Prevention | No-data state provides a clear recovery action ("Connect Apple Health"). Error state provides a retry action. No dead ends. |
| Celebration Not Guilt | AI copy uses encouraging framing. Shortfalls are described constructively ("Your sleep was shorter than usual" not "You failed to sleep enough"). |
| Motion Safety | FitMeLogoLoader already respects `.accessibilityReduceMotion`. No other forced animations are introduced in this feature. |

---

## Navigation Flow

```
Home tab
  └── ReadinessCard (existing, enhanced with component bars)
  └── AIInsightCard (new, positioned below ReadinessCard)
        └── tap anywhere on card
              └── AIIntelligenceSheet (modal .sheet)
                    └── per-segment SectionHeaders + AIRecommendationCards
                    └── "Your Readiness Breakdown" component bars
                    └── AIFeedbackView (footer)
```

---

## Design System Tokens

All values must resolve to tokens from `FitTracker/Services/AppTheme.swift`. No raw literals.

**Colors:**
- `AppColor.Surface.primary` — AIInsightCard background
- `AppColor.Surface.secondary` — AIRecommendationCard background
- `AppColor.Text.primary` — primary body and title text
- `AppColor.Text.secondary` — supporting text, segment labels, feedback label
- `AppColor.Text.tertiary` — reserved for de-emphasized metadata if needed
- `AppColor.Status.success` — high-confidence badge background
- `AppColor.Status.warning` — low-confidence badge background; error state retry button
- `AppColor.Brand.primary` — medium-confidence badge background

**Typography:**
- `AppText.headline` — sheet header title
- `AppText.subheadline` — AIInsightCard insight title
- `AppText.body` — AIRecommendationCard recommendation text
- `AppText.caption` — AIInsightCard subtitle, segment labels, badge text, feedback label
- `AppText.monoCaption` — source tier badge text (monospaced for badge alignment consistency)

**Spacing:**
- `AppSpacing.xSmall` — badge internal padding
- `AppSpacing.small` — between icon and label; AIFeedbackView button gap
- `AppSpacing.medium` — card internal padding
- `AppSpacing.large` — between sheet sections

**Shape and elevation:**
- `AppRadius.card` — all card corner radii
- `AppShadow.card` — AIInsightCard elevation (home surface)

**Reused components:**
- `FitMeLogoLoader` — status indicator and visual anchor across all states
- `AppPickerChip` — segment filter chips in AIInsightCard bottom row
- `SectionHeader` — segment section titles in AIIntelligenceSheet

---

## Out of Scope for Phase 3

The following are deferred to Phase 4 (Implement) or later:

- AIOrchestrator integration details (data binding, async fetch, recommendation model)
- Exact copy for each recommendation segment (handled by AI engine output)
- A/B test variants for card layout
- Push notification entry point into AIIntelligenceSheet
