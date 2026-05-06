# Iteration 2 — Full Plan + Local Claude Code Prompts

This file contains the complete Iteration 2 plan AND ready-to-paste prompts for the local Claude Code terminal (which has figma-console-mcp write access).

---

## I2.1 — LOGIN SCREENS (Figma)

### Code changes: DONE (committed)
- LockScreenView: Face ID auto-trigger + blue gradient + design tokens

### Figma prompt for local Claude Code:

```
You have figma-console MCP tools with persistent write access. File key: 0Ai7s3fCFqR5JXDW8JvgmD.

STEP 1: CLEANUP — On the Login page, delete ALL old screen frames from prior builds. Keep only the "Context / Login" overview section. Use figma_execute to list children, then figma_delete_node on each old screen frame.

STEP 2: BUILD 5 LOGIN SCREENS (N26/Openbank inspired). Blue gradient bg on ALL screens (#F0FAFF → #DFF3FF → #BAE3FF). Dark text. iPhone 16 Pro: 393x852. Place screens side-by-side with 40px spacing.

Screen 1: "Face ID Auto-Unlock" 393x852
- Blue gradient bg, content centered vertically
- App logo: orange (#FA8F40) rounded square 72x72 at top center
- "FitTracker" Nunito Bold 34pt, black@84%
- Small lock icon (faceid symbol) below, Nunito Regular 15pt "Authenticating..." black@55%
- This is the state the user sees for 0.3 seconds before Face ID triggers
- Subtle: "Use password instead" link at bottom, black@42%

Screen 2: "Login — Returning User" 393x852 (N26-style)
- Blue gradient bg
- App logo at top (smaller, 48x48)
- "Good morning, Regev" Nunito Bold 22pt, black@84% (personalized greeting)
- "regev.barak@icloud.com" Nunito Regular 15pt, black@62% (email shown)
- Password field: white@72% fill, radius 16, "Password" placeholder, "Forgot?" link right-aligned inside
- "Log in" button: full-width, black@82% fill, white text, radius 20
- "Log in with Face ID" link with faceid icon, Nunito Regular 15pt, black@62%
- "Create or activate account" link at bottom, black@42%

Screen 3: "Login — Email Entry" 393x852 (Openbank-style)
- Blue gradient bg
- App logo at top + "Back" link top-right
- "User login" Nunito Bold 22pt centered
- Tab bar: "Email address" (selected, orange underline) | "Mobile number"
- "Email" label + email input field (white@72%, radius 16)
- "Continue" button (disabled state: light gray fill)
- "Log in with Face ID" link with faceid icon
- "Create or activate account" link

Screen 4: "Registration" 393x852
- Blue gradient bg
- "Create Account" Nunito Bold 22pt
- "Your data stays encrypted on your device" Nunito Regular 15pt, black@62%
- 3 fields: Email, Password, Confirm password (white@72%, radius 16)
- Password strength indicator (colored bar below password field)
- "Create Account" button: #FA8F40 fill, black@84% text, radius 20

Screen 5: "Email Verification" 393x852
- Blue gradient bg
- "Verify Your Email" Nunito Bold 22pt
- "Enter the 5-digit code sent to your email" Nunito Regular 15pt, black@62%
- 5 OTP boxes (44x56 each, white@72% fill, radius 12, 12px spacing)
- "Didn't receive a code? Resend" link, black@42%

After building, take a screenshot of the Login page.
```

---

## I2.2 — HOME SCREEN (Figma)

### Code changes needed:
- LiveInfoStrip.swift (new component)
- MainScreenView.swift refinements

### Figma prompt for local Claude Code:

```
You have figma-console MCP tools. File key: 0Ai7s3fCFqR5JXDW8JvgmD.

CLEANUP: On the Main Screen page, delete old screen frames. Keep only context sections.

BUILD 2 SCREENS on the Main Screen page:

Screen 1: "Home / Today Summary" 393x852
This must match the FitTracker simulator screenshot exactly. Blue gradient bg.

Layout top to bottom:
1. Header bar (full width, no bg): hamburger icon (≡) left, "Home" center Nunito SemiBold 17pt, "No Watch" pill right (gray dot + text, white@58% bg, capsule)
2. Greeting: "Good evening, Regev 🌙" Nunito Bold 26pt left-aligned. Below: "Wednesday, 25 March 2026" Nunito Medium 15pt black@62%. Right: "Day 55" Nunito Bold 13pt + "Recovery" phase badge (capsule, white@38%)
3. STATUS card (white@22%, radius 24, full width):
   - "STATUS" eyebrow label + "Need more data" blue dot + label right
   - Two columns: "Weight" (blue icon + "Missing" badge blue) + "Body Fat" (orange icon + "Missing" badge orange)
   - "— kg" and "— %" large dashes
   - Target ranges: "Target: 65.0-68.0 kg" and "Target: 13-15%" in orange text
   - Recommendation: "Run the recovery yoga flow" + edit icon (pencil in circle)
4. GOAL section (white@22%, radius 24):
   - Left: "GOAL" label + circular progress ring (0%, gray track, blue progress)
   - Right: "GOAL PROGRESS" label, "Weight" bar (blue, 0%), "Body Fat" bar (orange, 0%)
   - "3 core items still need attention." text below
5. START TRAINING card (white@22%, radius 24):
   - "START TRAINING" eyebrow
   - Blue circle with training icon + "Start Recovery" bold + "24m · Baseline building"
6. METRICS row (4 equal cards, white@22%):
   - HRV (waveform icon, purple): "—"
   - Rest HR (heart icon, red): "—"
   - Sleep (moon icon, purple): "—"
   - Steps (walking icon, blue): "—"
7. Tab bar (white@92% bg, rounded corners top):
   - Home (orange, active, house icon) | Training Plan (person icon) | Nutrition (leaf icon) | Stats (chart icon)

Screen 2: "Manual Biometric Entry" 393x450 sheet
- White@92% fill, radius 32
- Drag indicator 36x4
- "Log Biometrics" Nunito Bold 22pt
- 5 fields: Weight (kg), Body Fat (%), Resting HR (bpm), HRV (ms), Sleep (hours)
- Each: black@3% fill, black@8% stroke, radius 16
- "Save" button: #FA8F40 fill, radius 16

After building, take a screenshot.
```

---

## I2.3 — NUTRITION (Figma)

### Figma prompt:

```
File key: 0Ai7s3fCFqR5JXDW8JvgmD.

CLEANUP: Delete old frames on Nutrition page.

BUILD 3 SCREENS:

Screen 1: "Nutrition / Today" 393x852
Blue gradient bg. Layout:
1. Header: "← Today →" date navigation with 7-day strip (dots for logged days)
2. MACRO TARGETS (always pinned, white@22%, radius 24):
   - "NUTRITION STRATEGY" eyebrow + "Continuous deficit" mode label
   - Calorie display: "1,850 / 2,200 kcal" large
   - Macro bars: Protein (#FA8F40) | Carbs (#8AC7FF) | Fat (#995926) stacked
   - Values below each: "142g / 180g" etc.
3. TWO BUTTONS ROW:
   - "Log First Meal" (blue-tinted bg, blue text)
   - "Quick Protein" (green-tinted bg, green text)
4. LOGGED ITEMS (chronological feed — NOT separated by Breakfast/Lunch/Dinner):
   - Each item: name + time + kcal + protein on a card row
   - Example entries: "Oatmeal with berries · 8:30 AM · 350 kcal · 12g protein"
5. SUPPLEMENTS section: "Morning" / "Evening" expandable toggles with streak badge
6. "Hydration" card: water glass icon + "Training days need a little more water"
7. Tab bar (Nutrition active)

Screen 2: "MealEntry / Smart Tab" 393x580 sheet
- White@92%, radius 32
- "Log Meal" title
- 4-tab segmented: Smart (active) | Manual | Template | Search
- TWO LARGE ICONS prominently displayed:
  - Camera icon (📷) in a 80x80 circle → "Take a photo of the nutrition label"
  - Barcode icon (⊞) in a 80x80 circle → "Scan product barcode"
- Text area below: "Or paste nutrition label text here"
- "Parse and Apply" button

Screen 3: "MealEntry / Manual Tab" 393x580 sheet
- Same header, Manual tab active
- Fields: Meal name, Calories, Protein (g), Carbs (g), Fat (g), Serving (g)
- "Save as Template" checkbox
- "Save Meal" button: #FA8F40

After building, take a screenshot.
```

---

## I2.4 — TRAINING (Figma)

### Figma prompt:

```
File key: 0Ai7s3fCFqR5JXDW8JvgmD.

CLEANUP: Delete old frames on Training page.

BUILD 4 SCREENS:

Screen 1: "Training / Rest Day" 393x852
Blue gradient bg. Must match the user's original screenshot:
1. Header: hamburger menu + "Training Plan" title
2. Week strip: Mon 23, Tue 24, Wed **25** (circled), Thu 26, Fri 27, Sat 28, Sun 29
3. 6-button grid (3x2):
   - Rest Day (bed icon, SELECTED blue highlight)
   - Upper Push (up arrow icon)
   - Lower Body (walk icon)
   - Upper Pull (down arrow icon)
   - Full Body (bolt icon)
   - Cardio Only (heart icon)
4. "Rest Day" title + timer display "--:--" with stepper (- / +)
5. "CURRENT FOCUS" section: "Recovery and movement"
   - "Use today for walking, mobility, and recovery notes."
   - Chips: "Walk or yoga" + "Recovery notes"
6. Three buttons: "Jump To Next" (cyan), "Start Rest" (neutral), "Focus Mode" (gray)
7. Tab bar (Training active)

Screen 2: "Training / Upper Push Active" 393x1200 (scrollable)
Blue gradient bg. Same header + week strip + 6-button grid (Upper Push selected).
Below the session overview:
- Exercise sections with expandable rows:
  - "Bench Press" → expanded with set log: 3 rows of [Set 1/2/3] [KG field] [REPS field] [RPE: 6 7 8 9 10]
  - "Overhead Press" → collapsed (just header)
  - "Incline DB Press" → collapsed
  - "Lateral Raises" → collapsed
- Each exercise shows: colored status stripe, muscle groups, meta pills (sets/reps/rest)
- "Copy Last" button (cyan) in expanded set log
- "Add Set" button (green)

Screen 3: "Session Completion" 393x400 sheet
- White@92%, radius 32
- Green checkmark icon (48pt)
- "Session Complete!" Nunito Bold 22pt
- "Upper Push" subtitle
- 2x2 stats: Volume (12,400 kg, +800 kg green), Exercises (4/4), Duration (48 min), PRs (1 trophy)
- "Log Notes" secondary button + "Done" green button

Screen 4: "Rest Timer" 160x160 floating circle
- Black@85%, full radius
- "1:23" IBM Plex Mono Bold 42pt, #FFC78A
- "REST" below, Nunito Regular 11pt, white@54%

After building, take screenshots.
```

---

## I2.5 — SETTINGS (Figma)

### Figma prompt:

```
File key: 0Ai7s3fCFqR5JXDW8JvgmD.

On the Settings page, update the 5 category cards with colored gradient fills:
- Account & Security: orange (#FA8F40) tinted gradient
- Health & Devices: cyan (#5AC8FA) tinted gradient
- Goals & Preferences: blue (#8AC7FF) tinted gradient
- Training & Nutrition: purple (#BF5AF2) tinted gradient
- Data & Sync: green (#34C759) tinted gradient

Then BUILD 5 SUB-SCREENS (393x852 each, blue gradient bg), placed to the right of the dashboard:

Sub-screen 1: "Account & Security"
- "Account & Security" title, orange accent
- ACCOUNT section: Sign-In Method (Apple), Name (Regev Barak), Email, Phone rows
- SECURITY section: "Require Face ID on Reopen" toggle (green badge), "Add Passkey" button (purple)
- PROTECTION section: Encryption (AES-256-GCM), Key Storage (Keychain), Cloud Storage, Data Protection rows

Sub-screen 2: "Health & Devices"
- Cyan accent
- HealthKit: "Authorized" green badge
- Apple Watch: "Connected" green badge
- Summary text
- "Re-authorize HealthKit" button

Sub-screen 3: "Goals & Preferences"
- Blue accent
- Profile: Name, Recovery Start, Phase, Day
- Body Goals: Weight 65-68 kg, BF 13-15% (editable fields)
- Unit System: Metric/Imperial toggle tiles
- Appearance: System/Light/Dark tiles
- Stats Carousel: toggleable metric list + "Reset Recommended" button

Sub-screen 4: "Training & Nutrition"
- Purple accent
- Nutrition: Fat Loss / Maintain / Lean Gain segmented picker
- Meal slots: Breakfast, Lunch, Dinner, Snacks (editable)
- Zone 2 HR: lower 106 / upper 124 sliders
- Readiness: HR threshold 75, HRV threshold 28 sliders

Sub-screen 5: "Data & Sync"
- Green accent
- Status: "Idle" green badge, iCloud: Available
- "Sync Now" + "Fetch from iCloud" buttons
- Storage: 42 Daily Logs, 6 Weekly Snapshots
- DANGER ZONE: "Delete All Local Data" red button with warning text

After building, take screenshots.
```

---

## I2.6 — STATS (Figma)

### Figma prompt:

```
File key: 0Ai7s3fCFqR5JXDW8JvgmD.

On the Stats page, update the existing screen to match this exact layout:

1. Period picker: W | M (selected) | 3M | 6M | Y (segmented, white@22% bg)
2. Weight chart card (white@22%, radius 24): "Weight" title + "82.5 kg · -1.2 kg this month" + chart area placeholder
3. Body Fat chart card: "Body Fat" title + "18.4% · -0.4% this month" + chart area
4. "Track More" section: Nunito SemiBold 17pt + helper text
5. Chip carousel: Weight (orange, selected), Body Fat, HRV, Sleep, Steps (unselected white@58%)
6. Selected metric chart (larger, same card style as above)
7. Tab bar (Stats active)

Weight and Body Fat are PERMANENT — they are NOT in the Track More chips. The Track More chips are for additional toggleable metrics only.

After building, take a screenshot.
```

---

## Usage Instructions

1. Open your local Claude Code terminal (the one with figma-console-mcp connected)
2. Make sure the Desktop Bridge plugin is running in Figma
3. Pull the latest branch: `git pull origin claude/implement-mcp-server-AVtFa`
4. Copy-paste ONE section's prompt at a time (start with I2.1 Login)
5. After each section completes, come back to the cloud session to review screenshots
6. Approve or request changes before moving to the next section
