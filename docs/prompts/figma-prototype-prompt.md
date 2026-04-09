# Prompt: Build FitMe Figma Prototype (22+ Screens)

Copy and paste into Claude console (claude.ai/code) with Figma MCP connected and the FitTracker Design System Library file open.

---

## Prompt

```
I need you to help me complete the interactive Figma prototype for my app "FitMe" (FitTracker).

## File Info
- Figma file: FitTracker Design System Library
- File key: 0Ai7s3fCFqR5JXDW8JvgmD
- URL: https://www.figma.com/design/0Ai7s3fCFqR5JXDW8JvgmD

## What Already Exists
The file already has these pages with approved runtime boards:
- Cover, Getting Started, Foundations, Components, Patterns, Platform Adaptations
- Icon Repository, Typography Repository, App Icon + App Store
- Login (auth screens), Main Screen (Home/Today), Training, Nutrition, Stats, Settings
- Account & Security (partial), Onboarding (placeholder), Prototype / iPhone App, Prototype / Flow Map

Design system foundations are complete: 92 variables (46 color, 22 text, 8 spacing, 6 radius, 6 elevation, 4 motion), 9 component families.

## What Needs to Be Built

### Priority 1: Missing screens to complete core flows

1. **Email Verification Screen**
   - Header: "Check your email"
   - 6-digit code input field (AppInputShell component)
   - "Resend code" quiet button
   - "Verify" primary button (AppButton)
   - Error state: invalid code banner
   - Add to Login page

2. **Meal Entry Sheet** (4-tab modal)
   - Tab bar: Smart | Manual | Template | Search
   - Smart tab: text area for pasting nutrition label, parsed preview
   - Manual tab: name, calories, protein, carbs, fat fields (AppInputShell)
   - Template tab: scrollable list of saved meals (AppCard)
   - Search tab: search bar + results list + barcode scanner button
   - "Save Meal" button at bottom (AppButton)
   - Add to Nutrition page

3. **Active Training Session**
   - Exercise name header with set counter ("Set 2 of 4")
   - Weight input (kg) + Reps input + RPE tap bar (6-10)
   - Previous session ghost row for comparison
   - "Log Set" primary button
   - Floating rest timer (bottom-right, countdown circle)
   - Exercise queue strip at top (dots showing completion)
   - Add to Training page

4. **Training Completion Sheet**
   - "Session Complete" header with checkmark
   - Volume summary: total kg, delta vs last session (green/red arrow)
   - Exercises completed: X/Y with ring progress
   - New PRs section (if any)
   - Session duration
   - Notes text area
   - "Done" button
   - Add to Training page

### Priority 2: Onboarding slides (hand-drawn aesthetic)

Style: Warm, approachable hand-drawn sketching with brand colors (#FA8F40 orange, #8AC7FF blue).

5. **Slide 1 — Welcome**
   - FitMe logo (large, centered)
   - "Your fitness command center" tagline
   - Warm orange gradient background
   - "Get Started" button

6. **Slide 2 — Training**
   - Illustration: dumbbells/barbell sketch
   - "Track every set, rep, and PR"
   - "87 exercises with progressive overload tracking"
   - Page dots (2 of 5)

7. **Slide 3 — Nutrition**
   - Illustration: meal plate/fork sketch
   - "Smart nutrition that adapts to your goals"
   - "Dynamic macro targets, 4 ways to log meals"
   - Page dots (3 of 5)

8. **Slide 4 — Recovery & AI**
   - Illustration: heart rate / sleep sketch
   - "Know when to push and when to rest"
   - "HealthKit integration + AI-powered insights"
   - Page dots (4 of 5)

9. **Slide 5 — Privacy + Permissions**
   - Illustration: lock/shield sketch
   - "Your data stays on your device"
   - "We need HealthKit access to track your recovery"
   - "Allow HealthKit" primary button + "Skip" quiet button
   - Page dots (5 of 5)

Add all slides to the Onboarding page.

### Priority 3: Settings detail screens

All use the same pattern: navigation bar with back chevron + title, then content sections using AppCard and AppMenuRow.

10. **Health & Devices**
    - HealthKit toggle (connected/disconnected)
    - Apple Watch status
    - Smart Scale (Xiaomi S400) pairing status
    - "Data Sources" section

11. **Goals & Preferences**
    - Unit system picker: Metric / Imperial (AppSelectionTile)
    - Appearance: System / Light / Dark
    - Target weight, target body fat fields
    - Stats carousel metric order

12. **Training & Nutrition**
    - Nutrition mode picker: Fat Loss / Maintain / Gain
    - Meal slot names (Breakfast, Lunch, Dinner, Snacks)
    - Zone 2 HR range: lower/upper inputs
    - Readiness thresholds: RHR target, HRV target

13. **Data & Sync**
    - Sync status indicator (idle/syncing/failed/offline)
    - Local data counts (X logs, Y snapshots)
    - "Export Data" button (disabled, coming soon)
    - "Reset All Data" destructive button (red)
    - Confirmation dialog for reset

Add all to Settings page or as separate linked frames.

### Priority 4: State variants

14-16. **Empty states** (one each for Training rest day, Nutrition no meals, Stats no data)
    - EmptyStateView component
    - Illustration placeholder
    - Actionable message + button

17-19. **Loading states** (Training, Nutrition, Stats)
    - Skeleton screen with shimmer placeholders
    - FitMeLogoLoader breathe animation indicator

20-22. **Error states** (Network error, Auth failure, Sync failed)
    - Error banner (red/amber)
    - Retry button
    - Helpful message

## Prototype Wiring

After creating screens, wire these flows with Figma prototype connections:

1. **Onboarding → Auth**: Slide 5 "Allow HealthKit" → Login page
2. **Auth → Home**: Login success → Main Screen (Home)
3. **Email verification**: AuthHub email path → Email Verification → Home
4. **Tab navigation**: Home ↔ Training ↔ Nutrition ↔ Stats (tab bar hotspots)
5. **Training session**: Training scheduled → Active Session → Completion → Training
6. **Meal logging**: Nutrition → "Log Meal" button → Meal Entry Sheet → Save → Nutrition
7. **Settings**: Settings home → each detail screen → back button → Settings

## Design Token Reference

Use these exact tokens from the existing Figma variables:

**Colors:**
- Brand primary: `color/brand/primary` (#FA8F40)
- Background: `color/background/app-primary`
- Surface: `color/surface/primary`, `secondary`, `tertiary`
- Text: `color/text/primary`, `secondary`, `tertiary`
- Accent: `color/accent/primary`
- Status: `color/status/success`, `warning`, `error`

**Typography:**
- Hero: text/hero (34pt bold)
- Page title: text/page-title (28pt bold)
- Section title: text/section-title (20pt semibold)
- Body: text/body (17pt medium)
- Caption: text/caption (13pt regular)
- Button: text/button (17pt semibold)

**Spacing:** 4pt grid — micro(2), xxxSmall(4), xxSmall(8), xSmall(12), small(16), medium(20), large(24)

**Radius:** micro(4), xSmall(8), small(12), medium(16), button(20), large(24), sheet(32)

## Important Notes
- iPhone 14 Pro frame size: 393 × 852
- Use existing components (AppButton, AppCard, AppMenuRow, etc.) wherever possible
- Maintain WCAG AA contrast (4.5:1 minimum for text)
- Include page dots (bottom) on all prototype navigation pages
- FitMeLogoLoader: circular orange gradient icon, 44pt for loading states
```

---

## Usage Notes
- Requires Figma MCP connected in Claude console
- The prompt references the existing design system — all tokens and components are already in the file
- Some operations (prototype wiring) may need manual Figma interaction if MCP limitations apply
- Review each created screen against the existing runtime boards for visual consistency
