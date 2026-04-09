# home-status-goal-card — Research

> **Phase:** 0 (Research)
> **Parent:** home-today-screen v2 (PR #61)
> **Deferred from:** F11 (goal drill-down), F13 (macro strip), OQ-3 (merged card), OQ-4 (macro placement), OQ-7-folded (drill-down folds in)

---

## 1. What is this?

Merge the separate Status card (weight + body fat) and Goal card (progress ring + bars) on Home v2 into a single unified **body-composition card**. Add a goal drill-down view (tap → detail), and place the compact macro strip semantically within the card.

Currently Home v2 has two adjacent cards:
- **Status card** — two `AppMetricColumn` instances (weight + body fat) with "Log" CTA when empty
- **Goal card** — `AppProgressRing` (overall progress %) + two `progressLine` bars (weight/BF progress) + essentials summary

These occupy ~250pt of vertical space. A merged card reduces to ~180pt while showing more meaningful context (the relationship between current values and goals).

## 2. Why merge?

- **Hick's Law**: Two cards for related data creates unnecessary visual fragmentation. Weight/BF and goals are the same conceptual unit — "where am I vs where I want to be"
- **Progressive disclosure**: The merged card shows the summary; drill-down reveals the full picture
- **Consistency**: Apple Health, Withings, and Noom all present body metrics + goal in one unified view
- **Scroll real estate**: Saves ~70pt vertical space, pushing metrics row higher

## 3. Competitive patterns

| App | Pattern | Hero metric | Goal viz | Drill-down? | Secondary data |
|---|---|---|---|---|---|
| **Withings Health Mate** | Single dashboard card | Weight (large) | Horizontal progress bar + "X kg to go" | Yes → full chart with overlays | Body fat %, muscle mass, water % stacked below |
| **MyFitnessPal** | Weight progress card | Weight | Linear bar (start → current → goal) + % complete | Yes → weight log chart | None in card (separate nutrition view) |
| **Noom** | Weight graph hero | Trend line | Goal line overlaid on chart + badge | Yes → annotated full chart | Daily dots + smoothed trend |
| **Lose It!** | Circular progress | Weight | Progress ring + "X lbs to goal" | Yes → detailed chart | Calorie budget |
| **Apple Health** | Separate metric cards | Each metric individual | No goal ring (just trend sparklines) | Yes → day/week/month chart | Sparkline per card |

**Key insight**: The Withings model (hero weight + stacked secondary metrics + goal progress bar) is the strongest pattern for a single unified card in a fitness context.

## 4. Approach comparison

| Approach | Pros | Cons | Effort | Chosen? |
|---|---|---|---|---|
| **A: Withings-style unified card** — Hero weight + BF below + progress bar + drill-down | Dense info, clear hierarchy, industry-proven | New card layout (not just combining existing) | 3-4 days | **Yes** |
| **B: Tab-based card** — Two tabs (Status / Goal) in one card container | Saves space, familiar pattern | Hides half the data behind a tap; violates Recognition over Recall | 2-3 days | No |
| **C: Accordion card** — Status visible, Goal expands on tap | Compact default, progressive | Non-standard on iOS; unexpected behavior | 3 days | No |
| **D: Keep separate, add drill-down only** — Two cards stay, goal ring becomes tappable | Minimal change | Doesn't address the fragmentation problem | 1 day | No |

## 5. Proposed design: Unified Body Composition Card

```
┌─────────────────────────────────────────────────┐
│  BODY COMPOSITION                          ▸    │  ← eyebrow + drill-down chevron
│                                                  │
│  67.2 kg        14.8%                           │  ← hero values (AppText.metric)
│  Weight          Body Fat                        │  ← labels (AppText.caption)
│  Target: 65-68   Target: 13-15%                 │  ← target ranges (AppText.footnote)
│                                                  │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 72%  │  ← overall progress bar
│                                                  │
│  🥩 142g / 180g protein                         │  ← compact macro strip (optional)
│                                                  │
│  You're on track — keep going! 💪               │  ← recommendation line
└─────────────────────────────────────────────────┘
```

### Drill-down view (new sheet)

Tapping the card (or the chevron) opens a detail sheet:
- Full-height chart showing weight + BF trends over time (7d / 30d / 90d / all)
- Goal lines overlaid
- Per-metric progress bars (weight and BF separately)
- "Log" CTA at bottom
- Milestone history

## 6. Technical feasibility

**Low risk:**
- Reuses existing `AppMetricColumn` (or adapts it for inline layout)
- Reuses `AppProgressRing` (or replaces with linear progress bar)
- `HomeRecommendationProvider` already provides the recommendation text
- `profile.overallProgress()`, `profile.weightProgress()`, `profile.bfProgress()` already exist
- Macro data available via `todayLog?.nutritionLog`

**New work:**
- `BodyCompositionCard` view (replaces both statusCard + goalCard in v2 MainScreenView)
- `BodyCompositionDetailView` (new sheet for drill-down) — **new file**
- Compact macro strip sub-view (optional, can defer to v2.1)
- Analytics event: `home_body_comp_tap` (drill-down)

**Dependencies:**
- None external. All data sources exist.

## 7. Proposed success metrics

| Metric | Baseline | Target |
|---|---|---|
| **Primary:** Body comp card drill-down rate | N/A (new) | >20% of sessions include a drill-down |
| **Secondary:** Biometric logging frequency | Current manual log rate | +15% increase in weight/BF logs from the drill-down CTA |
| **Secondary:** Home scroll depth | Current (unknown) | Card is higher in stack → more visible |
| **Guardrail:** Crash-free rate | >99.5% | Must not degrade |
| **Guardrail:** Cold start time | <2s | Must not degrade |

## 8. Macro strip decision

Per OQ-4, placement is decided semantically (not arbitrary). Two options:

**Option A:** Inside the body-composition card (shown above) — protein progress line contextualizes the body comp data. "You're eating toward your goal."

**Option B:** Separate compact row below the card — cleaner separation, but loses the contextual link.

**Recommendation:** Option A (inside the card). The macro strip is most meaningful next to the body metrics it's driving. If it feels too dense, defer to v2.1 as originally planned in Home v2.

## 9. Decision

**Recommended: Approach A (Withings-style unified card)** with drill-down sheet. Macro strip included as P1 (can ship without it, add in follow-up if the card feels too dense).

Estimated effort: ~3-4 days implementation + 1 day testing.
