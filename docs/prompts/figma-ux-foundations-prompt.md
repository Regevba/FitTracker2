# Claude Console Prompt — Add UX Foundations Layer to Figma

> **Purpose:** Copy-paste this prompt into Claude Console (with Figma MCP connected) to create the UX Foundations layer in the FitMe Figma design system library.
> **Prerequisites:** Figma MCP server connected, file key `0Ai7s3fCFqR5JXDW8JvgmD` accessible.
> **Output:** New "UX Foundations" page in Figma with 10 documentation frames mirroring `docs/design-system/ux-foundations.md`.

---

## CONTEXT

**Verified 2026-04-06:** The FitMe Figma file has these pages:
- Cover, Getting Started, Foundations, Icon Repository, Typography Repository, App Icon + App Store, Components, Patterns, Platform Adaptations, Onboarding, Login, Main Screen, Settings, Nutrition, Stats, Training, Account + Security, Prototype / iPhone App, Prototype / Flow Map, App Icon

**Missing:** A dedicated "UX Foundations" page that documents the behavioral layer of the design system (principles, IA, interaction patterns, state patterns, accessibility, content strategy).

The repo has a complete reference document at `docs/design-system/ux-foundations.md` (1,533 lines, 10 parts). This Figma layer must mirror it as a single source of truth across code and design.

**Token scope (already in Figma):** 125 tokens — 45 colors, 9 spacing, 9 radius, 22 typography, 8 motion, 2 shadow + 32 other.
**Components scope (already in Figma):** 9 published families on Components page (`AppButton`, `AppCard`, `AppMenuRow`, `AppSelectionTile`, `AppInputShell`, `AppFieldLabel`, `AppQuietButton`, `StatusBadge`, `EmptyStateView`) + 6 atomic components in code only (`AppPickerChip`, `AppFilterBar`, `AppSheetShell`, `AppStatRow`, `AppSegmentedControl`, `AppProgressRing`).

---

## THE PROMPT

```
You are adding a new "UX Foundations" page to the FitMe Figma design system library.

## Context
File key: 0Ai7s3fCFqR5JXDW8JvgmD
Reference document (in repo): docs/design-system/ux-foundations.md (1,533 lines, 10 parts)

The repo already contains the complete UX foundations content. Your job is to mirror it as a Figma documentation page so designers and developers see the same source of truth in both places.

## Step 1: Verify and Position the Page

1. Use `use_figma` to list all pages and confirm there is no existing "UX Foundations" page.
2. If one exists, abort and report. Do NOT modify any other page.
3. Otherwise, create a new page called "UX Foundations" positioned AFTER "Patterns" and BEFORE "Platform Adaptations" in the page order. This places it logically: Foundations (tokens) → Components → Patterns → UX Foundations → Platform Adaptations.

## Step 2: Read Brand Tokens for Consistent Styling

Use `get_design_context` on the existing Foundations page (id 10:3) to extract the actual variable references for these tokens. You will use them for ALL frames you create:

- Color: #FA8F40 (Brand.primary), #8AC7FF (Brand.secondary), #FCA659 (Brand.warm), #DFF3FF (Brand.cool), text #1F2429 (Text.primary), #59616B (Text.secondary), #737A85 (Text.tertiary), surface #FFFFFF (Surface.primary), background tint #E8F2FA
- Typography: Inter Bold for hero/titles, Inter Medium for body, Inter Semi Bold for buttons, IBM Plex Mono for monospace labels
- Spacing: micro=2, xxxSmall=4, xxSmall=8, xSmall=12, small=16, medium=24, large=32, xLarge=48, xxLarge=64
- Radius: small=8, medium=12, large=16, sheet=32, card=16
- Shadow: card (y=4 blur=12 #00000014)

## Step 3: Create the Page Layout

The "UX Foundations" page should contain ONE master overview frame at top and TEN section frames below it (one per Part of the reference document).

### Master Overview Frame (top of page, 1260×420)

Position: x=0, y=0
Layout: AppCard style — white background, 24px radius, card shadow, 40px internal padding

Content (top to bottom):
- Title: "UX Foundations" — Inter Bold 48px, Text.primary
- Subtitle: "The behavioral layer of the FitMe design system" — Inter Medium 18px, Text.secondary
- Body paragraph (Inter Regular 16px, Text.primary, 840px width):
  "This page mirrors `docs/design-system/ux-foundations.md`. It defines how FitMe should behave, not just how it should look. Visual tokens (Foundations page) describe appearance; this page describes experience. Every UI decision references these patterns. Updated when the document is updated."
- Meta strip (Inter Regular 12px, Text.tertiary):
  "Source of truth: docs/design-system/ux-foundations.md · 1,533 lines · 10 parts · Updated 2026-04-06"
- A row of 10 numbered chips representing the parts (1 through 10), each linking visually to the section frame below

### Section Frames (one per Part, stacked vertically with 80px gaps)

Each section frame is 1260px wide, white background, 24px radius, card shadow, 40px internal padding.

For each Part, create a frame with:
1. Eyebrow text: "Part N" — Inter Semi Bold 13px, Brand.primary, uppercase letterspacing
2. Section title: see list below — Inter Bold 32px, Text.primary
3. One-line summary: see list below — Inter Medium 17px, Text.secondary
4. Key content blocks: see content per section below
5. Footer link: "Read full section in `docs/design-system/ux-foundations.md` Part N" — Inter Regular 12px, Text.tertiary

### Content per Section

**Part 1 — Design Philosophy & Principles**
Summary: "13 UX principles (8 core + 5 FitMe-specific) that ground every design decision."

Content:
- Subhead "8 Core Principles" with a 4-column grid of 8 principle cards:
  | Principle | One-line summary |
  | Fitts's Law | Larger, closer targets are faster |
  | Hick's Law | Fewer choices = faster decisions |
  | Jakob's Law | Match iOS conventions |
  | Progressive Disclosure | Show summary, reveal detail on demand |
  | Recognition over Recall | Visible state beats memorized commands |
  | Consistency | Same patterns across all screens |
  | Feedback | Every action gets a response within 100ms |
  | Error Prevention | Design to prevent mistakes |

- Subhead "5 FitMe-Specific Principles" with a 5-column row of cards in Brand.primary tint:
  | Principle | One-line summary |
  | Readiness-First | Lead with "how am I doing?" before "what should I do?" |
  | Zero-Friction Logging | Every entry completable in <10 seconds |
  | Privacy by Default | Encrypt first, explain later |
  | Progressive Profiling | Don't ask everything upfront |
  | Celebration Not Guilt | Highlight effort, never shame |

**Part 2 — Information Architecture**
Summary: "Today vs History axis. 4-tab structure with max 3-level depth."

Content:
- Two-column layout:
  - LEFT: "Tab Bar Structure" diagram showing 4 tabs (Home, Training, Nutrition, Stats) with the account avatar in top-right toolbar
  - RIGHT: "Today vs History" axis explanation
- Below: "Depth Limit Rule" callout in Surface.tertiary background — "Maximum 3 levels from any tab"

**Part 3 — Interaction Patterns**
Summary: "Navigation, input, feedback, and gesture patterns with non-gesture alternatives."

Content:
- 4 sub-sections in 2x2 grid:
  - Navigation Patterns (5 patterns table: tab/push/sheet/full-screen/confirmation)
  - Input Patterns (numeric, selection, date, search, barcode)
  - Feedback Patterns (haptic taxonomy table — 8 events)
  - Gesture Patterns (with non-gesture alternatives note)

**Part 4 — Data Visualization Patterns**
Summary: "Chart types, metric hierarchy, color semantics."

Content:
- "Chart Type Selection Guide" table (line/bar/ring/sparkline/heat/body map)
- "Metric Display Hierarchy" 4-tier visual (Hero → Display → Standard → Compact)
- "Color Semantics in Data" callout — green=on track, orange=warning, red=over, blue=info
- "Empty Chart States" — thresholds (<3 / 3-6 / 7+ data points)

**Part 5 — Permission & Trust Patterns**
Summary: "3-step priming pattern. Contextual permission requests, never batched."

Content:
- 3-step flow diagram: Pre-Primer Screen → System Dialog → Graceful Degradation
- "FitMe Permission Matrix" table (HealthKit read/write, Notifications, Camera, Photos, ATT, Location)
- "Trust Signals" list (encryption badge, stays-on-device, privacy summary)
- Callout: "NEVER request multiple permissions at once"

**Part 6 — State Patterns**
Summary: "5 states: default, loading, empty, error, success."

Content:
- 5 example mini-frames showing each state with FitMe styling:
  - Default: workout list with content
  - Loading: skeleton + breathing logo
  - Empty: EmptyStateView with first-use copy
  - Error: forgiving message with recovery action
  - Success: toast with checkmark
- "Loading Threshold Rule": <200ms = no state, 200ms-500ms = skeleton, 500ms+ = explicit, >5s = progress
- "Empty State Copy Formula": What's missing → What to do next → (optional) why it matters

**Part 7 — Accessibility Standards**
Summary: "WCAG AA + Dynamic Type + 44pt targets + VoiceOver + cognitive accessibility."

Content:
- 4 columns (Visual, Motor, Cognitive, Screen Reader)
- Visual: contrast ratios per token (Text.primary 9.2:1 AAA, Text.secondary 5.4:1 AA, Text.tertiary 4.6:1 AA)
- Motor: 44pt minimum, 52pt FitMe primary, 8pt spacing, no time limits
- Cognitive: max 5-7 actionable items, consistent placement, undo support
- Screen reader: every interactive element has accessibilityLabel, charts have text summaries
- Footer note: "Sprint B (2026-04-06) added 17 manual labels to icon-only buttons. ~30+ buttons already had implicit labels via Label(). Coverage now 100% on flagged elements."

**Part 8 — Micro-Interactions & Motion**
Summary: "Purpose-driven motion. Reduce-motion compliance. Haptic taxonomy."

Content:
- "Animation Purpose Categories" (5): state change, spatial transition, feedback, attention, celebration
- Duration tokens table (instant 0.1s through xLong 0.6s)
- Spring tokens table (snappy/bouncy/smooth/stiff)
- "Reduce Motion" callout: all animations must check `accessibilityReduceMotion`
- Haptic patterns table (single impact, notification, selection, custom sequences)
- "Sound: OFF by default" callout with gym etiquette note

**Part 9 — Content Strategy**
Summary: "Tone, terminology glossary, number formatting, health data sensitivity."

Content:
- "Voice attributes" callout: Calm, direct, secure, supportive, non-hype
- "What we don't say" vs "What we do say" two-column table (4 examples each)
- Terminology glossary (Readiness, PR, Set, Rep, Rest, Session, Volume, Macros, HRV, RHR, Day type)
- Number formatting rules table (weight, calories, macros, %, duration, time, date)
- "Health Data Sensitivity" rules box: never compare users, never frame missing as failure, show context, respect rest, never trigger body image

**Part 10 — Platform-Specific Patterns**
Summary: "iPhone primary, iPad secondary, Apple Watch future, Android deferred."

Content:
- 5 platform sections (iPhone / iPad / Apple Watch / macOS / Android)
- For each: status (primary / secondary / future / implemented / deferred), key patterns, known gaps
- iPhone: thumb zones, safe area, Dynamic Island, size class variants (375/393/430)
- iPad: adaptive layout via horizontalSizeClass, sidebar nav, split view
- Apple Watch: planned complications, rest timer, quick log
- macOS: Mac Catalyst implemented, known gaps
- Android: mapped via Style Dictionary, deferred to Gate D

## Step 4: Add Cross-References

Each section frame should have a "Related" footer with links to:
- The corresponding code file (e.g., AppTheme.swift for Part 1, AppMotion.swift for Part 8)
- The corresponding Figma page (e.g., Foundations for tokens, Components for components)

## Step 5: Validate

After building:
1. Take a screenshot of the full UX Foundations page
2. List the node IDs of:
   - The page itself
   - The master overview frame
   - Each of the 10 section frames
3. Confirm no other pages were modified

## Step 6: Report

Reply with:
1. Page node ID
2. Master overview frame node ID
3. 10 section frame node IDs (one per Part)
4. Screenshot URLs
5. Any deviations from the spec (with justification)

## Constraints

- DO NOT modify any existing page
- DO NOT publish new components — this is a documentation page only
- DO NOT add prototype connections
- USE existing color/text/spacing variables from the Foundations page (id 10:3)
- USE Inter font family (Figma fallback for SF Pro Rounded)
- ALL text and spacing values must come from existing variables, not raw values
- KEEP frames editable (not flat screenshots)
```

---

## Post-Build Verification Checklist

After running the prompt, verify:

- [ ] New "UX Foundations" page exists in the file
- [ ] Page is positioned between "Patterns" and "Platform Adaptations"
- [ ] Master overview frame contains all 10 part chips
- [ ] All 10 section frames present (one per Part of `ux-foundations.md`)
- [ ] All frames use existing variables (no raw hex/spacing/font values)
- [ ] All frames are editable (not flat screenshots)
- [ ] No other pages were modified
- [ ] Each section has a "Related" footer linking to code + Figma

## Maintenance Note

When `docs/design-system/ux-foundations.md` is updated, this Figma page must be updated too. The `/ux` skill should call out this dependency in its `/ux audit` sub-command.

## Document Reference

The full UX foundations content lives in `docs/design-system/ux-foundations.md` — 1,533 lines, committed to `claude/review-code-changes-E7RH7` at commit `f59faa5`.
