# App Store Assets — UX/Integration Spec

## Icon Specifications

### Master Icon (1024×1024)
- Source: Figma node `635:2` (App Icon — 1024×1024 Master)
- Design: 4 intertwined circles (Pink, Yellow, Blue, Teal) + "FitMe" gradient text
- Safe area: Content within 820×820 centered (80% of canvas) — iOS rounds corners automatically
- Export: PNG, sRGB, no transparency, no layers
- Validation: Icon visible at 29pt (58px @2x) — smallest rendered size

### Required iOS Sizes
| Size (pt) | @2x | @3x | Usage |
|---|---|---|---|
| 20 | 40px | 60px | Notifications |
| 29 | 58px | 87px | Settings |
| 40 | 80px | 120px | Spotlight |
| 60 | 120px | 180px | iPhone Home |
| 76 | 152px | — | iPad Home |
| 83.5 | 167px | — | iPad Pro |
| 1024 | — | — | App Store |

## Screenshot Specifications

### 5-Screen Story (canonical order)
1. **Home / Today** — readiness score 78, body comp (71.5 kg / 18.2%), dual CTAs
2. **Training** — live set log (Bench Press), exercise cards, rest timer overlay
3. **Nutrition** — macro rings (142/180g protein), meal log, supplement streak 🔥7
4. **Stats** — weight + body fat charts with trend arrows, period picker
5. **Onboarding** — Welcome screen with FitMe brand icon on blue gradient

### Device Frames
- Primary: iPhone 17 Pro (6.7", 1290×2796)
- Secondary: iPhone 16 (6.5", 1242×2688)
- All screenshots use the app's blue gradient background (AppGradient.screenBackground)

### Caption Style
- Font: Nunito Bold 28pt (title) + Nunito Regular 18pt (subtitle)
- Color: White on dark overlay bar at top of each screenshot
- Examples:
  - "Know what to do today" (Home)
  - "Track every set and rep" (Training)
  - "Smart nutrition that adapts" (Nutrition)
  - "See your progress over time" (Stats)
  - "Your fitness command center" (Onboarding)

### Seed Data
- Name: "Alex" (gender-neutral)
- Readiness: 78 (Full Intensity)
- Body: 71.5 kg, 18.2% BF
- Training: Upper Push, Bench Press 80kg × 8
- Nutrition: 1,850/2,200 kcal, 142/180g protein
- Stats: Weight trending down -0.3 kg/week

## App Store Metadata

### Title (30 chars max)
**"FitMe — Fitness Command Center"** (30 chars)

### Subtitle (30 chars max)
**"Training · Nutrition · Recovery"** (30 chars)

### Keywords (100 chars max)
**"fitness tracker,workout log,macro tracker,nutrition,recovery,AI coaching,HRV,body composition,gym"** (96 chars)

### Description (first 3 lines visible)
> FitMe replaces your training log, meal tracker, and recovery dashboard with one app that knows what you should do today — without ever seeing your private health data.
>
> FEATURES:
> • 87 exercises with progressive overload tracking and automatic PR detection
> • Dynamic macro targets that adapt to your training day and goals
> • Readiness scoring powered by HRV, sleep, and heart rate
> • AI coaching that learns your patterns while keeping data on-device
> • Zero-knowledge encryption — your health data never leaves unencrypted
>
> PRIVACY FIRST:
> AES-256 encryption, Secure Enclave key storage, federated AI. No data sold. Ever.

### Categories
- Primary: Health & Fitness
- Secondary: Lifestyle

### Age Rating: 4+
- No objectionable content, no purchases, no user-generated content

## Visual Consistency Rules
1. All screenshots use AppGradient.screenBackground (blue gradient)
2. All text uses Nunito font family
3. Same device frame across all screenshots
4. Sample data is consistent across screens (same user, same day)
5. No empty states — all screens populated with realistic data
6. Design system tokens used for all UI elements
