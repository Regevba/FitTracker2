# P4 — Screen Build Manual

**Purpose:** Step-by-step guide for manually building each app screen in Figma using the synced design system components and tokens.

**Prerequisites:**
- All 7 variable collections synced (118 variables)
- All 22 text styles created
- All 2 effect styles created
- All 22 component sets available on the Components page

**Canvas:** iPhone 16 Pro — 393 × 852pt per screen frame

---

## General Rules

1. **Every screen** is a Frame: 393×852, clipped, with auto-layout vertical
2. **Background:** Use `Color / Semantic` variable `background/app-primary` for gradient screens, or raw dark fill for auth screens
3. **Padding:** horizontal = `Spacing/small` (16), top varies per screen
4. **Item spacing:** `Spacing/small` (16) default between sections
5. **All colors** must come from `Color / Semantic` variables — never hardcode hex
6. **All fonts** must use the 22 text styles (`text/*`) — never set size manually
7. **All spacing** values must use `Spacing/*` variables
8. **All radii** must use `Radius/*` variables
9. **Shadows:** Use the `effect/elevation-card` or `effect/elevation-cta` effect styles

---

## Screen 1: Auth Entry / Register

**Page:** Login
**Background:** Dark — `background/auth-top` (#0A140F)
**Padding top:** 120

| # | Element | Component/Style | Token Bindings |
|---|---------|----------------|----------------|
| 1 | App icon | Frame 72×72, fill `brand/primary`, radius `Radius/medium` | — |
| 2 | Title "FitTracker" | Text style `text/hero` | Color: `text/inverse-primary` |
| 3 | Subtitle "Create your account" | Text style `text/body` | Color: `text/inverse-secondary` |
| 4 | Spacer | Frame height 32 | — |
| 5 | Apple button | Frame 345×52, radius `Radius/large`, fill `surface/elevated` | Label: `text/button`, color `text/primary` |
| 6 | Passkey button | Frame 345×52, radius `Radius/large`, fill `surface/secondary` | Label: `text/button`, color `text/primary` |
| 7 | Email link | Text style `text/subheading` | Color: `text/inverse-secondary` |
| 8 | Toggle text | Text style `text/subheading` | Color: `text/inverse-tertiary` |

---

## Screen 2: Auth Entry / Login

**Page:** Login
**Background:** Dark — same as Screen 1
**Layout:** Identical to Screen 1 except:
- Subtitle: "Welcome back"
- Apple button label: "Continue with Apple"
- Email link: "Sign in with email"
- Toggle: "Don't have an account? Register"

---

## Screen 3: Email Login

**Page:** Login
**Background:** Dark
**Padding top:** 120

| # | Element | Component/Style | Token Bindings |
|---|---------|----------------|----------------|
| 1 | Title "Sign in with Email" | `text/page-title` | Color: `text/inverse-primary` |
| 2 | Subtitle | `text/subheading` | Color: `text/inverse-secondary` |
| 3 | Spacer | Frame height 16 | — |
| 4 | Email field | `AppInputShell` (State=Default) | Fill: `surface/primary`, radius `Radius/medium` |
| 5 | Password field | `AppInputShell` (State=Default) | Same as above |
| 6 | "Forgot password?" | `text/chip` | Color: `text/inverse-secondary` |
| 7 | Sign In button | `AppButton` (Hierarchy=Primary) | Fill: `surface/inverse`, label color: `text/inverse-primary` |

---

## Screen 4: Email Registration

**Page:** Login
**Background:** Dark
**Layout:** Same as Email Login except:
- Title: "Create Account"
- 3 fields: Email, Password, Confirm password
- Button: "Create Account" with `brand/primary` fill

---

## Screen 5: Lock Screen

**Page:** Login
**Background:** Dark
**Padding top:** 280 (vertically centered feel)

| # | Element | Component/Style | Token Bindings |
|---|---------|----------------|----------------|
| 1 | Lock icon | SF Symbol `lock.fill`, size 48pt | Color: `text/inverse-primary` |
| 2 | Title "FitTracker is Locked" | `text/page-title` | Color: `text/inverse-primary` |
| 3 | Subtitle "Use Face ID to unlock" | `text/subheading` | Color: `text/inverse-secondary` |
| 4 | Unlock button | `AppButton` (Primary), width 200 | Fill: `brand/primary` |

---

## Screen 6: Home / Today Summary

**Page:** Main Screen
**Background:** Gradient — `background/app-secondary` → `background/app-primary` → `brand/cool`
**Padding top:** 60

| # | Element | Component/Style | Token Bindings |
|---|---------|----------------|----------------|
| 1 | Greeting "Good morning, Regev" | `text/page-title` | Color: `text/primary` |
| 2 | Readiness Card | `ReadinessCard` (Level=High) | Score: `text/metric-display`, bg: `surface/inverse` |
| 3 | Goal section header | `SectionHeader` (Default) | "WEIGHT GOAL" |
| 4 | Progress bar | Frame 361×8, radius `Radius/micro` | Track: `surface/tertiary`, fill: gradient `brand/primary` → `brand/warm` |
| 5 | Quick actions (2×2) | 4× Frame 176×44 each | Fill: `surface/material-light`, stroke: `border/strong` @35%, radius `Radius/medium`, label: `text/chip` |
| 6 | Recovery header | `SectionHeader` (Default) | "RECOVERY" |
| 7 | Recovery card | `AppCard` (tone=Standard) | Title: `text/section-title`, subtitle: `text/subheading` color `text/tertiary` |
| 8 | Tab bar | Frame 393×49, fill `surface/elevated` | 4 labels: Home(active)/Training/Nutrition/Stats, active: `brand/primary`, inactive: `text/tertiary` |

---

## Screen 7: Training / Active Session

**Page:** Training
**Background:** Same gradient as Home
**Padding top:** 60

| # | Element | Component/Style | Token Bindings |
|---|---------|----------------|----------------|
| 1 | Session title "Upper Push · 4 exercises" | `text/page-title` | Color: `text/primary` |
| 2 | Week strip | HStack of 7 day frames (44×44) | Active day: fill `brand/primary`, label `text/inverse-primary`. Inactive: fill `surface/material-light`, label `text/secondary`. Radius `Radius/x-small` |
| 3 | Exercise card × N | `AppCard` (Standard) | Title: `text/section-title`, sets: `text/mono-label` color `text/secondary` |
| 4 | Tab bar | Same as Home, Training tab active | — |

**Floating element:** Rest Timer — Circle 160×160, fill `surface/inverse` @85%, timer: `text/metric-display-mono` color `brand/warm`, label: `text/mono-label` color `text/inverse-tertiary`

---

## Screen 8: Session Completion Sheet

**Page:** Training (sheet overlay)
**Style:** Sheet — `AppSheetShell` pattern, radius `Radius/sheet` (32)
**Width:** 393, Height: ~400

| # | Element | Component/Style | Token Bindings |
|---|---------|----------------|----------------|
| 1 | Title "Session Complete!" | `text/page-title` | Color: `text/primary` |
| 2 | Stats grid (2×2) | 4× `AppStatRow` or custom frames 176×56 | Label: `text/caption` color `text/secondary`, value: `text/title-strong` |
| 3 | Done button | `AppButton` (Primary) | Fill: `brand/primary` |

**Stats:** Volume, Exercises, Duration, New PRs

---

## Screen 9: Nutrition / Meals Logged

**Page:** Nutrition
**Background:** Same gradient
**Padding top:** 60

| # | Element | Component/Style | Token Bindings |
|---|---------|----------------|----------------|
| 1 | Title "Nutrition · Today" | `text/page-title` | Color: `text/primary` |
| 2 | Macro bar | `MacroTargetBar` | Protein: `brand/primary`, Carbs: `brand/secondary`, Fat: `chart/nutrition-fat` |
| 3 | Meal sections × 4 | `MealSectionView` (WithMeals or Empty) | Title: `text/section-title`, meal: `text/body`, "Tap to log": `text/subheading` color `text/tertiary` |
| 4 | Supplement row | `AppCard` (Standard) | Checkboxes for AM/PM pills |
| 5 | Tab bar | Nutrition tab active | — |

---

## Screen 10: Meal Entry Sheet

**Page:** Nutrition (sheet overlay)
**Style:** Sheet, radius `Radius/sheet`
**Width:** 393, Height: ~580

| # | Element | Component/Style | Token Bindings |
|---|---------|----------------|----------------|
| 1 | Drag indicator | Capsule 36×4 | Fill: `border/hairline` |
| 2 | Title "Log Meal" | `text/page-title` | Color: `text/primary` |
| 3 | Tab selector | `AppSegmentedControl` (Options=4) | Smart / Manual / Template / Search |
| 4 | Fields × 5 | `AppInputShell` | Meal name, Calories, Protein, Carbs, Fat |
| 5 | Save button | `AppButton` (Primary) | "Save Meal" |

---

## Screen 11: Stats / Weight Chart

**Page:** Stats
**Background:** Same gradient
**Padding top:** 60

| # | Element | Component/Style | Token Bindings |
|---|---------|----------------|----------------|
| 1 | Title "Stats" | `text/page-title` | Color: `text/primary` |
| 2 | Period picker | `AppSegmentedControl` (Options=5) | W / M / 3M / 6M / Y |
| 3 | Weight chart | `ChartCard` (WithData) | Title: `text/section-title` |
| 4 | Body fat chart | `ChartCard` (WithData) | — |
| 5 | Metric chips | HStack of `AppPickerChip` | Weight(selected), Body Fat, HRV, Sleep, Steps... |
| 6 | Tab bar | Stats tab active | — |

---

## Screen 12: Account Panel

**Page:** Account + Security
**Style:** Sheet, radius `Radius/sheet`
**Width:** 393, Height: ~500

| # | Element | Component/Style | Token Bindings |
|---|---------|----------------|----------------|
| 1 | Drag indicator | Capsule 36×4 | Fill: `border/hairline` |
| 2 | Avatar | Circle 64×64 | Gradient fill `brand/primary` → `brand/warm` |
| 3 | Name "Regev Barak" | `text/title-strong` | Color: `text/primary` |
| 4 | Email | `text/subheading` | Color: `text/secondary` |
| 5 | Settings button | `AppQuietButton` | "Settings" |
| 6 | Sign Out button | `AppButton` (Destructive) | "Sign Out" |

---

## Screen 13: Settings / Dashboard

**Page:** Settings
**Background:** Same gradient
**Padding top:** 60

| # | Element | Component/Style | Token Bindings |
|---|---------|----------------|----------------|
| 1 | Title "Settings" | `text/hero` | Color: `text/primary` |
| 2 | Category cards × 5 | `AppMenuRow` or custom cards 361×72 | Each card: fill `surface/elevated`, radius `Radius/large`, stroke `border/hairline` |

**Categories:**
- Account & Security — "Apple sign-in · Biometric lock"
- Health & Devices — "HealthKit · Apple Watch"
- Goals & Preferences — "Weight target · Units · Appearance"
- Training & Nutrition — "Program · Meal slots · Supplements"
- Data & Sync — "iCloud · Export · Encryption"

---

## Screen 14: Manual Biometric Entry

**Page:** Main Screen (sheet overlay)
**Style:** Sheet, radius `Radius/sheet`
**Width:** 393, Height: ~440

| # | Element | Component/Style | Token Bindings |
|---|---------|----------------|----------------|
| 1 | Drag indicator | Capsule 36×4 | Fill: `border/hairline` |
| 2 | Title "Log Biometrics" | `text/page-title` | Color: `text/primary` |
| 3 | Fields × 5 | `AppInputShell` | Weight (kg), Body Fat (%), Resting HR, HRV, Sleep (hours) |
| 4 | Save button | `AppButton` (Primary) | "Save" |

---

## Screen 15: Rest Timer Overlay

**Page:** Training (floating overlay)
**Style:** Circle 160×160, no auto-layout

| # | Element | Component/Style | Token Bindings |
|---|---------|----------------|----------------|
| 1 | Circle background | 160×160 | Fill: `surface/inverse` @85% |
| 2 | Timer "1:23" | `text/metric-display-mono` | Color: `brand/warm` |
| 3 | Label "REST" | `text/mono-label` | Color: `text/inverse-tertiary` |

---

## Checklist Per Screen

After building each screen, verify:

- [ ] All colors come from `Color / Semantic` variables (check in Figma's variable picker)
- [ ] All text uses one of the 22 `text/*` styles (check in text style dropdown)
- [ ] All spacing values match `Spacing/*` variables
- [ ] All corner radii match `Radius/*` variables
- [ ] Shadows use `effect/elevation-card` or `effect/elevation-cta` styles
- [ ] Frame is exactly 393×852 (full screens) or correct sheet dimensions
- [ ] Auto-layout is set correctly (Vertical, center-aligned, proper padding)
- [ ] Screen name follows convention: "ScreenName / State"

---

## Token Quick Reference

### Spacing Scale
| Token | Value |
|---|---|
| micro | 2 |
| xxx-small | 4 |
| xx-small | 8 |
| x-small | 12 |
| small | 16 |
| medium | 20 |
| large | 24 |
| x-large | 32 |
| xx-large | 40 |

### Radius Scale
| Token | Value | Usage |
|---|---|---|
| micro | 4 | Progress bars, chart segments |
| x-small | 8 | Small UI elements |
| small | 12 | Cards, inputs |
| medium | 16 | Buttons, inputs |
| button | 20 | Pill-style CTAs |
| large | 24 | Cards |
| x-large | 28 | Large cards |
| sheet | 32 | Bottom sheets |
| auth-sheet | 36 | Auth bottom sheets |

### Key Color Tokens
| Token | Usage |
|---|---|
| `text/primary` | Main body text |
| `text/secondary` | Supporting text |
| `text/tertiary` | Hints, placeholders |
| `text/inverse-primary` | Text on dark backgrounds |
| `brand/primary` | Orange accent (#FA8F40) |
| `brand/secondary` | Blue accent (#8AC7FF) |
| `surface/material-light` | Glass-morphism cards |
| `surface/elevated` | Elevated card surfaces |
| `surface/inverse` | Dark surfaces |
| `border/hairline` | Thin dividers |
| `border/subtle` | Card strokes |
| `status/success` | Green |
| `status/warning` | Amber |
| `status/error` | Red |
