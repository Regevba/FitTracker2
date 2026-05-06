# Claude Console Prompt: Build Onboarding v2 Screens in Figma

> **Purpose:** Copy-paste this prompt into Claude Console (with Figma MCP connected) to build the v2 onboarding screens in the FitMe Figma design system library.
> **Prerequisites:** Figma MCP server connected, file key `0Ai7s3fCFqR5JXDW8JvgmD` accessible.
> **Output:** 6 new screen frames under a "v2 — PRD-Aligned Onboarding" section on the Onboarding page.

---

## THE PROMPT

```
You are building v2 onboarding screens for the FitMe fitness app in Figma.

## Context

File key: 0Ai7s3fCFqR5JXDW8JvgmD
Target page: "Onboarding" (page ID: 25:6)
The existing "I3.1 — Onboarding Slides" section (node 469:2) contains v1 screens (5 feature-showcase slides). DO NOT modify them.

Create a NEW section called "I3.2 — Onboarding v2 (PRD-Aligned)" on the same Onboarding page, positioned below the existing section (y offset +1100 from current content). This is the PRD-aligned version with goal collection, profile setup, consent, and HealthKit auth.

## Design System Tokens (from AppTheme.swift)

Colors:
- Brand primary: #FA8F40 (orange)
- Brand secondary: #8AC7FF (blue)
- Brand warm: #FCA659, warm-soft: #FFC78A
- Brand cool: #DFF3FF, cool-soft: #F0FAFF
- Background tint: #E8F2FA (light blue — used on feature/consent screens)
- Text primary: rgba(0,0,0,0.84)
- Text secondary: rgba(0,0,0,0.62) / #59616B
- Text tertiary: rgba(0,0,0,0.42) / #737A85
- Text inverse primary: #FFFFFF
- Text inverse secondary: rgba(255,255,255,0.85)
- Text inverse tertiary: rgba(255,255,255,0.65)
- Status success: #34C759 (green)
- Status error: #FF3B30 (red)
- Surface primary: #FFFFFF
- Surface secondary: rgba(0,0,0,0.04)

Typography (use Inter as Figma fallback for SF Pro Rounded):
- Hero: Inter Bold, 34px, line-height 41px
- Title Strong: Inter Bold, 28px
- Subheading: Inter Semi Bold, 20px
- Body: Inter Regular, 17px, line-height 24px
- Button: Inter Semi Bold, 17px
- Caption: Inter Regular, 13px

Spacing: xxxSmall=2, xxSmall=4, xSmall=8, small=12, medium=16, large=24, xLarge=32, xxLarge=40
Radius: button=20, card=16, small=8
Shadows: card: y=4, blur=12, color=rgba(0,0,0,0.08); CTA: y=4, blur=16, color=rgba(0,0,0,0.12)

## Icon Colors (from Figma App Icon page, node 635:2)
- Pink: #F5B8E8
- Yellow: #FFBD12
- Blue: #85D6FF
- Teal: #33E0C2
- FitMe text gradient: left-to-right Orange→Yellow→Teal→Blue

## Screen Specifications (6 screens, iPhone 16 Pro: 393×852)

### Screen 1: Welcome (Orange Gradient Background)
- Background: linear gradient top-to-bottom #FA8F40 → #FCA659 → #FFC785
- Center: FitMe brand icon (4 intertwined circles: Pink, Yellow, Blue, Teal — reproduce from App Icon page node 635:2, scaled to 180×180)
- Below icon: "FitMe" text in gradient (Orange→Yellow→Teal→Blue), Inter Bold 44px
- Below title: "Your fitness command center" in white 85% opacity, Inter Semi Bold 20px
- Below subtitle: "Training · Nutrition · Recovery · AI" in white 65% opacity, Inter Regular 15px
- Bottom: "Get Started" button — white background, #FA8F40 text, full width (329px), 52px height, 20px radius, shadow
- No progress bar on this screen
- Page dots: 6 dots at very bottom, first dot active (white), rest semi-transparent

### Screen 2: Goals (Light Blue Background)
- Background: #E8F2FA
- Progress bar at top: 6 segments, segment 2 active (brand gradient fill)
- Title: "What's your goal?" — Inter Bold 28px, #1F2429
- 4 goal cards in 2×2 grid (each ~155×140px):
  - "Build Muscle" — SF Symbol figure.strengthtraining.traditional, #FA8F40 accent
  - "Lose Fat" — SF Symbol flame.fill, #FF6B6B accent
  - "Maintain" — SF Symbol heart.fill, #34C759 accent
  - "General Fitness" — SF Symbol figure.run, #8AC7FF accent
- Each card: white bg, 16px radius, card shadow, icon 32px, title Inter Semi Bold 15px
- Selected state: 2px border in brand primary #FA8F40
- Bottom: "Continue" button (brand orange bg, white text, full width, 52px, 20px radius) — disabled until selection
- Below button: "Skip" text in #737A85, Inter Medium 15px

### Screen 3: Profile (Light Blue Background)
- Background: #E8F2FA
- Progress bar: segment 3 active
- Title: "Tell us about you" — Inter Bold 28px
- Section 1 — "Experience Level":
  - 3 horizontal cards: "Beginner" / "Intermediate" / "Advanced"
  - Each: white bg, 16px radius, icon + label, selected = brand border
- Section 2 — "How often do you train?":
  - 5 tappable circles (2-6) in a row, 44×44pt each
  - Selected circle: brand orange fill, white number
  - Unselected: white bg, gray border, gray number
- "Continue" + "Skip" buttons same as Screen 2

### Screen 4: HealthKit (Light Blue Background)
- Background: #E8F2FA
- Progress bar: segment 4 active
- Center: circle illustration (160px) — light blue fill with heart.text.square SF Symbol in #8AC7FF
- Title: "Sync your health data" — Inter Bold 28px
- Description: "Connect Apple Health to track recovery metrics and get personalized insights." — Inter Regular 17px, #59616B
- 4 data rows with SF Symbol icons:
  - Heart Rate (heart.fill, #FF3B30)
  - HRV (waveform.path.ecg, #8AC7FF)
  - Steps (figure.walk, #FA8F40)
  - Sleep (moon.fill, #6366F1)
- "Connect Health" button — brand orange, white text, 52px, 20px radius
- "Skip for now" quiet text button

### Screen 5: Consent (Light Blue Background)
- Background: #E8F2FA
- NO progress bar (consent is a standalone decision screen)
- Center: circle illustration (160px) — light blue fill with lock.shield.fill SF Symbol in #8AC7FF + checkmark.circle.fill badge in #34C759 at top-right of circle
- Title: "Help Us Improve FitMe" — Inter Bold 28px
- Description: "We use anonymous analytics to understand how the app is used. Your health data is never shared." — Inter Regular 17px, #59616B
- Card (white bg, 16px radius, card shadow):
  - ✅ "App usage patterns" (checkmark.circle.fill green)
  - ✅ "Screen views & feature adoption" (checkmark.circle.fill green)
  - Divider line
  - ❌ "Health data values" (xmark.circle.fill red)
  - ❌ "Personal information" (xmark.circle.fill red)
- "Accept & Continue" button — brand orange, white text, 52px, 20px radius
- "Continue Without" quiet text button — #737A85
- Footer: "You can change this anytime in Settings." — Inter Regular 13px, #737A85

### Screen 6: First Action (Light Blue Background)
- Background: #E8F2FA
- Progress bar: segment 6 active (all previous filled)
- Celebration icon at top: party.popper or hands.sparkles.fill emoji/icon
- Title: "You're all set!" — Inter Bold 28px
- Subtitle: personalized text based on goal, e.g., "Ready to build muscle?" — Inter Regular 17px, #59616B
- Two large CTA cards side by side:
  - Left: "Start Your First Workout" — dumbbell icon, brand orange accent, white bg, 16px radius
  - Right: "Log Your First Meal" — fork.knife icon, green accent, white bg, 16px radius
- Each card: ~165×180px, icon 40px centered, title Inter Semi Bold 15px below, card shadow

## Build Instructions

1. Use `use_figma` tool with file key `0Ai7s3fCFqR5JXDW8JvgmD`
2. Navigate to the Onboarding page (ID: 25:6)
3. Create a new SECTION frame named "I3.2 — Onboarding v2 (PRD-Aligned)" positioned below existing content
4. Build all 6 screens as child frames (393×852 each), spaced 60px apart horizontally
5. Use the exact colors, fonts, and spacing from the design tokens above
6. For the FitMe brand icon on Screen 1, reproduce the 4-circle pattern from the App Icon page (node 635:2) at 180×180 scale
7. Add a descriptive text frame below the section explaining: "v2: PRD-aligned onboarding with goal collection, profile setup, analytics consent, and HealthKit auth. Replaces v1 feature-showcase slides."

## After Building

Report back:
1. The node ID for each screen frame
2. A screenshot of each screen
3. Any design token mismatches or issues found
4. Confirmation that v1 screens were NOT modified

## IMPORTANT

- DO NOT modify any existing content on the Onboarding page
- DO NOT modify the v1 "I3.1 — Onboarding Slides" section
- All new content goes in the new "I3.2" section only
- Use Inter font family (Figma fallback for SF Pro Rounded)
- Test each screen at 393×852 (iPhone 16 Pro viewport)
```

---

## Post-Build Approval Workflow

After the Figma screens are built, follow this process:

### Step 1: Visual Review
Screenshot each of the 6 v2 screens and compare against the PRD spec. Verify:
- [ ] All 6 screens present (Welcome, Goals, Profile, HealthKit, Consent, First Action)
- [ ] Design tokens match AppTheme.swift (colors, spacing, radius, typography)
- [ ] FitMe brand icon matches App Icon page (4 circles + gradient text)
- [ ] Progress bar visible on screens 2, 3, 4, 6 (NOT on 1 and 5)
- [ ] Button styles consistent (brand orange primary, gray quiet secondary)
- [ ] Card styles consistent (white bg, 16px radius, card shadow)

### Step 2: User Approval
Present screenshots to user. Options:
1. **Approve** — proceed to code sync
2. **Request changes** — iterate on specific screens in Figma
3. **Reject** — keep v1, discard v2

### Step 3: Code Sync (After Approval)
Once approved, run this command in Claude Code:

```
/pm-workflow onboarding
```

Then say: "Move to implementation. The Figma v2 screens have been approved. Update the existing onboarding SwiftUI views to match the approved Figma designs. Use `get_design_context` on each approved screen node to extract exact specs."

The code sync will:
1. Read each approved Figma screen via `get_design_context`
2. Update the corresponding SwiftUI view file to match pixel-perfect
3. Preserve all existing functionality (analytics, navigation, consent logic)
4. Only change visual presentation (colors, layout, spacing, typography)
5. Run `make tokens-check` to verify design system compliance
6. Commit with message referencing the Figma node IDs

### Step 4: Change Broadcast
After code merge, the PM workflow will automatically:
1. Update `.claude/shared/change-log.json`
2. Notify `/qa` (regression), `/cx` (monitor feedback), `/design` (verify compliance)
