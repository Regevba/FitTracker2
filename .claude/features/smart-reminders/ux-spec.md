# Smart Reminders — UX Spec

## Notification Content Design

### Type 1: HealthKit Connect
- **Title:** "Unlock your readiness score ❤️"
- **Body:** "Connect Apple Health to see how ready you are to train today."
- **Action:** "Connect" → deep link to HealthKit authorization
- **Tone:** Inviting, benefit-focused

### Type 2: Account Registration
- **Title:** "Your data deserves a backup ☁️"
- **Body:** "Create an account to sync across devices and unlock AI coaching."
- **Action:** "Sign Up" → deep link to auth flow
- **Tone:** Value proposition, no pressure

### Type 3: Goal-Gap Nutrition
- **Title:** "Protein check-in 🥩"
- **Body:** "You're at {current}g / {target}g protein. A quick meal could close the gap."
- **Action:** "Log Meal" → deep link to Nutrition tab
- **Tone:** Helpful, data-driven

### Type 4: Training/Rest Day
- **Title (training):** "Today's plan: {dayType} 💪"
- **Body:** "{exerciseCount} exercises · ~{duration}m. Ready when you are."
- **Title (rest):** "Rest day — recover well 🧘"
- **Body:** "Your readiness is {score}. Rest is part of progress."
- **Action:** "Start" / "View" → deep link to Training tab / Home
- **Tone:** Encouraging, never guilt-inducing

### Type 5: Engagement
- **Title (day 3):** "Miss you! 👋"
- **Body:** "Your streak is waiting. Quick check-in?"
- **Title (day 7):** "Still here for you 🌱"
- **Body:** "Consistency builds results. Ready to jump back in?"
- **Action:** "Open FitMe" → app launch
- **Tone:** Warm, zero guilt

## Locked Feature Overlay (Guest Users)

```
┌─────────────────────────────┐
│  (semi-transparent backdrop) │
│                              │
│   ┌──────────────────────┐  │
│   │  🔒  brain.head       │  │
│   │                       │  │
│   │  Unlock AI Coaching   │  │
│   │                       │  │
│   │  Get personalized     │  │
│   │  training and         │  │
│   │  nutrition advice     │  │
│   │  powered by your      │  │
│   │  health data.         │  │
│   │                       │  │
│   │  [Create Account]     │  │
│   │                       │  │
│   │  Maybe later           │  │
│   └──────────────────────┘  │
└─────────────────────────────┘
```

- Backdrop: AppColor.Background.appPrimary.opacity(0.85)
- Card: 300pt wide, AppRadius.card, AppColor.Surface.primary
- Icon: SF Symbol for the locked feature, 40pt, AppColor.Accent.primary
- Title: AppText.sectionTitle
- Body: AppText.body, AppColor.Text.secondary
- CTA: AppSize.ctaHeight, AppColor.Accent.primary, full-width
- Dismiss: AppText.caption, AppColor.Text.tertiary, centered

## Timing Visual (Typical Day)

```
7 AM  ─── quiet hours end ───
8 AM  ── readiness alert (if score < 40)
9 AM  
10 AM ── training reminder (if training day, no workout yet)
...
4 PM  ── nutrition gap reminder (if protein < 50% target)
...
7 PM  ── recovery nudge (if 4+ consecutive training days)
...
10 PM ─── quiet hours start ───
```

Global cap: 3/day max, 4h minimum between notifications.

## DS Compliance
- [x] Fitts's law: all action buttons ≥ 44pt
- [x] "Celebration Not Guilt": all copy is encouraging, warm
- [x] Progressive disclosure: reminders surface summary, tap for detail
- [x] Accessibility: notification content readable by VoiceOver
- [x] Quiet hours respected (10 PM - 7 AM)
