# Iteration 2 — Master Figma Build Prompt (Full Reference)

**Date:** 2026-04-01
**Purpose:** Complete prompt for building ALL 20 screens across 6 pages. Saved as reference for verification — each section is executed separately via gateway approval.

**File key:** `0Ai7s3fCFqR5JXDW8JvgmD`

---

## GLOBAL DESIGN RULES

- ALL screens: light blue gradient background #F0FAFF → #DFF3FF → #BAE3FF → #8AC7FF@90%. NO dark theme.
- Text: primary black@84%, secondary black@62%, tertiary black@55%.
- Font: Nunito (rounded), IBM Plex Mono (monospaced).
- iPhone 16 Pro: 393×852 full screens. Sheets: variable height.
- Brand orange: #FA8F40. Brand blue: #8AC7FF. Cyan: #5AC8FA. Purple: #BF5AF2. Green: #34C759. Red: #FF3B30. Brown: #995926.
- Card: white@22% fill, white@35% 1px stroke, radius 24.
- Sheet: white@92% fill, radius 32.
- Spacing: micro=2, xxxSmall=4, xxSmall=8, xSmall=12, small=16, medium=20, large=24, xLarge=32, xxLarge=40.
- Radius: micro=4, xSmall=8, small=12, medium=16, button=20, large=24, xLarge=28, sheet=32.

---

## SECTION 1: LOGIN PAGE — 5 SCREENS

### Screen 1: "Face ID Auto-Unlock" 393×852
Blue gradient bg, content centered vertically.
- App logo: #FA8F40 rounded rect 72×72, radius 16, centered
- "FitTracker" Nunito Bold 34pt, black@84%, centered below logo
- Spacer 40px
- Face ID icon (faceid SF symbol) 36pt, black@55%
- "Authenticating..." Nunito Regular 15pt, black@55%, centered
- Bottom: "Use password instead" link, Nunito Regular 13pt, black@42%

### Screen 2: "Login — Returning User (N26 style)" 393×852
Blue gradient bg.
- App logo: #FA8F40 rounded rect 48×48, radius 12, centered, top area
- Spacer 24px
- "Good morning, Regev" Nunito Bold 22pt, black@84%, centered
- "regev.barak@icloud.com" Nunito Regular 15pt, black@62%, centered
- Spacer 24px
- Password field: 345px wide, 52px tall, white@72% fill, radius 16. Left: "Password" placeholder black@42%. Right: "Forgot?" link #FA8F40 14pt
- Spacer 16px
- "Log in" button: 345px wide, 52px tall, black@82% fill, white text Nunito SemiBold 17pt, radius 20
- Spacer 24px
- "Log in with Face ID" link with faceid icon, Nunito Regular 15pt, black@62%, centered
- Spacer 12px
- "Create or activate account" link, Nunito Regular 15pt, black@42%, centered

### Screen 3: "Login — Email Entry (Openbank style)" 393×852
Blue gradient bg.
- Top bar: App logo 48×48 left area + "Back" link right, black@62%
- Spacer 24px
- "User login" Nunito Bold 22pt, centered
- Spacer 16px
- Tab selector: "Email address" (selected, #FA8F40 underline 3px) | "Mobile number" (unselected, black@42%)
- Spacer 24px
- "Email" label Nunito SemiBold 13pt, black@62%, left-aligned
- Email field: 345px wide, 52px, white@72% fill, radius 16, "Example: user@domain.com" placeholder
- Spacer fills
- "Continue" button: 345px, 52px, black@12% fill (disabled state), black@30% text, radius 20
- Spacer 16px
- "Log in with Face ID" link with faceid icon, centered
- "Create or activate account" link, centered

### Screen 4: "Registration" 393×852
Blue gradient bg.
- "Create Account" Nunito Bold 22pt, left-aligned
- "Your data stays encrypted on your device" Nunito Regular 15pt, black@62%
- Spacer 24px
- 3 input fields (345px wide, 52px tall each, white@72% fill, radius 16, 12px spacing):
  "Email address", "Password" (eye icon right), "Confirm password"
- Password rules: "Must include uppercase, number, and special character" Nunito Regular 12pt, black@42%
- Spacer 24px
- "Create Account" button: 345px, 52px, #FA8F40 fill, black@84% text, radius 20

### Screen 5: "Email Verification (OTP)" 393×852
Blue gradient bg, content centered.
- "Verify Your Email" Nunito Bold 22pt, centered
- "Enter the 5-digit code sent to your email" Nunito Regular 15pt, black@62%, centered
- Spacer 32px
- 5 OTP boxes (44px wide, 56px tall, white@72% fill, radius 12, 12px spacing)
  First 3: "4", "8", "2" Nunito SemiBold 24pt black@84%. Last 2: "·" black@30%
- Spacer 24px
- "Didn't receive a code? Resend" Nunito Regular 13pt, black@42%, centered

---

## SECTION 2: HOME PAGE — 2 SCREENS

### Screen 6: "Home / Today Summary" 393×852
Blue gradient bg. Exact match to FitTracker simulator screenshot.

1. HEADER BAR: hamburger icon (line.3.horizontal) in 44×44 circle white@58% fill left + "Home" Nunito SemiBold 17pt center + "No Watch" pill (gray dot 6px + text, white@58% capsule) right
2. GREETING: "Good evening, Regev 🌙" Nunito Bold 26pt left + date below Nunito Medium 15pt black@62% + right: "Day 55" Nunito Bold 13pt + "Recovery" capsule (white@38%)
3. STATUS CARD (white@22%, radius 24): "STATUS" eyebrow + blue dot "Need more data" right. Two cols: Weight (blue icon + "Missing" badge) + Body Fat (orange icon + "Missing" badge). "— kg" / "— %" large. Targets in #FA8F40. Divider. "Run the recovery yoga flow" + edit icon
4. GOAL SECTION (white@22%, radius 24): Left: "GOAL" + circular ring 86px (0%, gray track, blue stroke, "0%" center). Right: "GOAL PROGRESS" + Weight bar (blue, 0%) + Body Fat bar (orange, 0%). "3 core items still need attention."
5. START TRAINING (white@22%, radius 24): "START TRAINING" eyebrow + blue circle 48px with figure icon + "Start Recovery" bold + "24m · Baseline building"
6. METRICS ROW (4 equal cards, white@22%, radius 16, 8px spacing): HRV (purple waveform), Rest HR (red heart), Sleep (purple moon), Steps (blue walk). All "—" values.
7. TAB BAR (white@92%, 393px, top corners radius 20): Home (#FA8F40 active pill) | Training Plan | Nutrition | Stats (all black@42%)

### Screen 7: "Manual Biometric Entry" 393×450 sheet
White@92%, radius 32. Drag indicator 36×4. "Log Biometrics" Nunito Bold 22pt. 5 fields (black@3% fill, black@8% stroke, radius 16): Weight, Body Fat, Resting HR, HRV, Sleep. "Save" button #FA8F40.

---

## SECTION 3: NUTRITION PAGE — 3 SCREENS

### Screen 8: "Nutrition / Today" 393×852
Blue gradient bg.
1. DATE HEADER: "←" + "Today" + "→" + 7-day dot strip (filled=logged, empty=unlogged, today circled)
2. MACRO TARGETS (white@22%, radius 24, PINNED): "NUTRITION STRATEGY" eyebrow + "Continuous deficit" pill. "1,850 / 2,200 kcal" bold. Stacked bar: Protein(#FA8F40) | Carbs(#8AC7FF) | Fat(#995926) | Remaining. Labels below.
3. TWO BUTTONS: "Log First Meal" (#8AC7FF@15% bg, blue text) + "Quick Protein" (#34C759@15% bg, green text)
4. LOGGED ITEMS (chronological feed): "Oatmeal · 8:30 AM · 350 kcal · 12g", "Chicken salad · 12:45 PM · 520 kcal · 45g", "Salmon bowl · 7:00 PM · 680 kcal · 38g"
5. SUPPLEMENTS: "SUPPLEMENTS" eyebrow + "🔥 7" streak. Morning (5/7 taken) + Evening (0/3)
6. HYDRATION (white@22%, radius 24): water icon + text
7. Tab bar (Nutrition active)

### Screen 9: "MealEntry / Smart Tab" 393×580 sheet
White@92%, radius 32. "Log Meal" title. Tabs: Smart(active) | Manual | Template | Search. Two large icon buttons: Camera 80×80 circle (#FA8F40@15%, camera.fill 32pt) + Barcode 80×80 (#8AC7FF@15%, barcode.viewfinder 32pt). Divider "or". Text area. "Parse and Apply" button.

### Screen 10: "MealEntry / Manual Tab" 393×580 sheet
Same header, Manual active. 6 fields + "Save as Template" toggle + "Save Meal" button #FA8F40.

---

## SECTION 4: TRAINING PAGE — 4 SCREENS

### Screen 11: "Training / Rest Day" 393×852
Blue gradient bg. Header + week strip (Wed 25 circled) + 6-button grid (Rest Day selected blue). "Rest Day" title + "--:--" timer + stepper. "CURRENT FOCUS: Recovery and movement" + "Walk or yoga" / "Recovery notes" chips. Three buttons: Jump To Next (cyan), Start Rest (neutral), Focus Mode (gray disabled). Tab bar.

### Screen 12: "Training / Upper Push Active" 393×1400 (scrollable)
Same structure, Upper Push selected (warm tint). Exercise sections: Bench Press EXPANDED (green stripe, "LIVE" badge, set log with 3 rows: kg/reps/RPE, "Copy Last" + "Add Set" buttons). Overhead Press, Incline DB Press, Lateral Raises COLLAPSED.

### Screen 13: "Session Completion" 393×400 sheet
Green checkmark 48pt. "Session Complete!" + "Upper Push". 2×2 stats: Volume (+800kg green), Exercises (4/4), Duration (48 min), PRs (1 trophy). "Log Notes" + "Done" buttons.

### Screen 14: "Rest Timer Overlay" 160×160 circle
Black@85%. "1:23" IBM Plex Mono Bold 42pt #FFC78A. "REST" 11pt white@54%.

---

## SECTION 5: SETTINGS PAGE — COLORED CARDS + 5 SUB-SCREENS

Update 5 cards with colored tint fills: orange, cyan, blue, purple, green (@10% opacity).

### Sub-screen 15: "Account & Security" 393×852
Orange accent. Account rows (Sign-In, Name, Email, Phone) + Security (Face ID toggle green, Add Passkey purple) + Protection (Encryption, Key Storage, Cloud, Data Protection).

### Sub-screen 16: "Health & Devices" 393×852
Cyan accent. HealthKit Authorized green + Apple Watch Connected green + summary + Re-authorize button.

### Sub-screen 17: "Goals & Preferences" 393×852
Blue accent. Profile snapshot + Body goals (editable) + Units tiles + Appearance tiles + Stats carousel checkboxes.

### Sub-screen 18: "Training & Nutrition" 393×852
Purple accent. Nutrition mode picker + Meal slot names + Zone 2 HR sliders + Readiness sliders.

### Sub-screen 19: "Data & Sync" 393×852
Green accent. Sync status + actions + storage counts + Danger zone (red Delete button).

---

## SECTION 6: STATS PAGE — 1 SCREEN

### Screen 20: "Stats" 393×852
Blue gradient bg. Period picker (M active). Weight chart card + Body Fat chart card (PERMANENT, not in Track More). "Track More" title + helper. Chip carousel (Weight selected, Body Fat, HRV, Sleep, Steps). Selected metric chart. Tab bar.

---

## VERIFICATION CHECKLIST

After all screens built, verify:
- [ ] All 20 screens present on correct pages
- [ ] All backgrounds are blue gradient (no dark)
- [ ] All text uses dark tokens (not inverse/white on blue)
- [ ] All cards use white@22% fill with white@35% stroke
- [ ] All sheets use white@92% fill with radius 32
- [ ] Settings cards have colored tint fills
- [ ] Login screens match N26/Openbank reference style
- [ ] Home screen matches simulator screenshot exactly
- [ ] Nutrition has chronological feed (no meal slots)
- [ ] Training matches original 6-button grid screenshot
- [ ] Stats has permanent Weight/BF charts + Track More section
