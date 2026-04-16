# App Store Screenshots — FitMe

**Device:** iPhone 17 Pro — 6.7 inch, 1290x2796 px  
**Format:** PNG, RGB, no transparency  
**Count:** 5 canonical screenshots (required: minimum 3, max 10)

---

## Capture Command

```bash
# Boot simulator and capture
xcrun simctl boot {DEVICE_ID}
xcrun simctl io {DEVICE_ID} screenshot {output_path}.png

# Recommended output directory
mkdir -p docs/release/screenshots/
xcrun simctl io {DEVICE_ID} screenshot docs/release/screenshots/01-home.png
```

Get `DEVICE_ID` via: `xcrun simctl list devices | grep "iPhone 17 Pro"`

---

## Screenshot 1 — Home (Today Screen)

**File:** `01-home.png`  
**Simulator state:** Logged-in user, morning context (08:30), data populated  
**Data to show:**
- Readiness score: 82 (green ring, "Good to train")
- Today's metrics: Sleep 7h 45m, HRV 58ms, Steps 3,200
- Active workout card: "Upper Body Strength — 45 min"
- Streak badge: 12-day streak visible

**Caption:** "Your daily readiness score — know exactly how hard to push today."

---

## Screenshot 2 — Training

**File:** `02-training.png`  
**Simulator state:** Active workout in progress, mid-session  
**Data to show:**
- Exercise: Bench Press, Set 3 of 4
- Weight: 80 kg, Reps: 8
- Rest timer counting down: 0:45
- Volume progress bar: 65% of planned volume done
- Previous set logged in history below

**Caption:** "Smart workout tracking — log sets, rest timers, and volume in one tap."

---

## Screenshot 3 — Nutrition

**File:** `03-nutrition.png`  
**Simulator state:** Afternoon (13:00), lunch logged  
**Data to show:**
- Macro ring: Protein 95g/160g, Carbs 180g/250g, Fat 42g/70g
- Calorie bar: 1,420 / 2,200 kcal
- Logged meals: Breakfast + Lunch visible
- "Add Meal" CTA prominent

**Caption:** "Hit your macros every day — track meals in seconds, see the full picture."

---

## Screenshot 4 — Stats

**File:** `04-stats.png`  
**Simulator state:** Weekly view, 4 weeks of data populated  
**Data to show:**
- HRV trend chart: upward trend over 4 weeks
- Volume chart: weekly training load bars
- Period selector: "4W" tab active
- Key stat callout: "+12% HRV improvement"

**Caption:** "See your progress over time — HRV, volume, and recovery trends at a glance."

---

## Screenshot 5 — Onboarding

**File:** `05-onboarding.png`  
**Simulator state:** Onboarding welcome screen (first launch)  
**Data to show:**
- Blue background, FitMe orange icon centered
- Headline: "Train Smarter, Recover Better"
- Subtext: "Personalized readiness scores powered by your biometrics"
- "Get Started" CTA pinned to bottom
- "Sign In" secondary link below

**Caption:** "Built around your biology — personalized fitness that adapts to how you feel."

---

## Localization Notes

- Screenshots are English (en-US) for initial submission
- Localized sets (if added): same 5 shots with translated captions per locale
- Store captions max length: 170 characters per Apple guidelines
