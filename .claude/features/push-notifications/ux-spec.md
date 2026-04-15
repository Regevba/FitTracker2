# Push Notifications — UX Spec

## Permission Priming Flow (3-Step Pattern)

### Step 1: Pre-Primer Screen (`NotificationPermissionPrimingView`)
- Full-screen view with illustration (bell icon + phone mockup)
- Title: "Stay on track with smart reminders" (AppText.titleStrong)
- Body: "FitMe can remind you about training, nutrition, and recovery — only when it matters." (AppText.body)
- CTA: "Enable Notifications" (52pt height, AppColor.Accent.primary, full width)
- Secondary: "Not now" (AppText.caption, AppColor.Text.tertiary, tap dismisses)
- Shown once after first workout completion (not during onboarding — too early)

### Step 2: System Dialog
- Triggered immediately after user taps "Enable Notifications"
- iOS system alert: "FitMe Would Like to Send You Notifications"
- Options: Allow / Don't Allow

### Step 3: Graceful Degradation (if denied)
- No error message, no repeated prompts
- Banner in Settings: "Notifications are off. Enable in Settings to get training and nutrition reminders."
- "Open Settings" button deep-links to iOS Settings > FitMe > Notifications

## Notification Content Design

### Workout Reminder
- **Title:** "Time to train 💪"
- **Body:** "{dayType} · {exerciseCount} exercises · ~{duration}m"
- **Category:** `workout` (actionable)
- **Action:** "Start" → deep link to Training tab
- **Timing:** 10 AM on training days, only if no workout logged yet
- **Tone:** Encouraging, not pushy

### Readiness Alert
- **Title:** "Your readiness is low today"
- **Body:** "Score: {score}/100. Consider a lighter session or rest day."
- **Category:** `readiness` (informational)
- **Action:** "View Details" → deep link to Home (readiness card)
- **Timing:** 8 AM when readinessScore < 40 AND confidence >= .medium
- **Tone:** Caring, supportive — "rest is part of progress"

### Recovery Nudge
- **Title:** "Recovery check-in 🧘"
- **Body:** "You've trained {consecutiveDays} days straight. Your body may need a break."
- **Category:** `recovery` (informational)
- **Action:** "View Recovery" → deep link to Home
- **Timing:** Evening (7 PM) after 4+ consecutive training days
- **Tone:** Celebration first, then gentle suggestion

## Timing Rules
- **Quiet hours:** 10 PM — 7 AM (no notifications)
- **Frequency cap:** Max 2 notifications/day across all types
- **Cooldown:** Min 4 hours between notifications
- **Workout reminder:** 1/day max, skip if workout already logged
- **Readiness alert:** 1/day max, skip if readiness >= 40
- **Recovery nudge:** 1/week max

## Token Mapping
- Priming view background: AppGradient.screenBackground
- CTA: AppSize.ctaHeight (52pt), AppColor.Accent.primary, AppRadius.button
- Title: AppText.titleStrong, AppColor.Text.primary
- Body: AppText.body, AppColor.Text.secondary
- "Not now": AppText.caption, AppColor.Text.tertiary

## DS Compliance
- [x] Fitts's law: CTA is 52pt (above 44pt minimum)
- [x] Progressive disclosure: priming before system dialog
- [x] "Celebration Not Guilt": all copy is encouraging
- [x] Accessibility: VoiceOver labels on priming view
- [x] Reduce motion: no animations in priming view
