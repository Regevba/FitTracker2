# Push Notifications v2 — UX Specification

**Phase:** 3 (UX/Integration), Step 3c (`/ux spec`)
**Started:** 2026-05-07
**Inputs:** PRD, ux-research.md, ux-foundations.md (Part 5 priming, Part 3 interaction patterns)
**Output:** This document → next step `/ux validate`, then `/ux preflight` (P0 gate)

---

## 1. User Flows

### 1.1 Primary flow — first-workout-completed → grant → tap

```
SessionCompletionSheet dismiss
    ↓
NotificationPermissionPrimingView sheet (medium detent, iOS 16+)
    ↓
[user taps "Enable Notifications"]
    ↓
OS dialog (UNUserNotificationCenter.requestAuthorization)
    ↓
[user taps "Allow"]
    ↓
NotificationGateway.isAuthorized = true
Sheet auto-dismisses, brief success haptic (.success)
    ↓
User lands at Home
    ↓
[next morning, scheduled workout reminder fires]
    ↓
User taps banner
    ↓
ReminderNotificationDelegate.didReceive
    ↓
DeepLinkRouter.handle(url: "fitme://nav/training", source: .notification)
    ↓
DeepLinkRouter.pendingDeepLink = .navigateToTab(.training)
    ↓
RootTabView observes, switches to Training tab
```

### 1.2 Skip flow — user not ready

```
SessionCompletionSheet dismiss → priming sheet → [user taps "Not now"]
    ↓
Sheet dismisses (no OS dialog fired — preserves the one-shot privilege)
    ↓
Settings → Notifications row remains as permanent re-entry point
```

Equivalent gesture: swipe-down on sheet handle = "Not now" (defensive — even an accidental dismiss preserves the OS dialog privilege).

### 1.3 Denial flow — user explicitly declines

```
Priming sheet → [Enable] → OS dialog → [user taps "Don't Allow"]
    ↓
NotificationGateway.isAuthorized = false
Sheet dismisses (no banner shown yet — the user is still in the workout-completion moment)
    ↓
On next Home view appear (returning to app):
SettingsDeepLinkBanner appears at top of Home, one-time
    ↓
[user taps "Open Settings"] → UIApplication.shared.open(UIApplication.openSettingsURLString)
    ↓
OR [user taps dismiss "X"] → banner sets UserDefaults flag → never shows again
    ↓
Settings → Notifications row swaps CTA to "Open iOS Settings"
```

### 1.4 Edge cases

| Edge case | Behavior |
|---|---|
| Permission already granted via iOS Settings before priming reaches user | Priming view's `requestAuthorization()` short-circuits — system reports `.authorized` → priming auto-dismisses with brief success state; copy: "Notifications already enabled — you're all set." |
| Permission revoked in iOS Settings after granted | Detected on next app foreground via `NotificationGateway.refreshAuthorizationStatus()`. Banner UserDefaults flag reset on revocation; banner reappears once. |
| Cold-start from notification tap | App launches → `didReceive` fires before main content renders → `DeepLinkRouter` holds `pendingDeepLink` until SwiftUI root subscribes → on subscribe, action emits, navigation lands. T14 case 3 covers this. |
| Dual-source race (notification tap + `.onOpenURL` near-simultaneously) | `DeepLinkRouter.handle(...)` is idempotent per (URL, source, ≤200ms window). Second call within window = no-op. |
| Notification tap while in Onboarding/Lock | `pendingDeepLink` is queued but only emits when user reaches an interactive Home/tab state. Same pattern as `signIn.pendingPasswordResetURL`. |

---

## 2. Screen Inventory + Schematics

### 2.1 NotificationPermissionPrimingView (sheet)

**Purpose:** App-branded explanation of notification benefit before the OS dialog. Step 1 of the 3-step priming pattern (per `ux-foundations.md` §5.2).

**Entry points:**
- Post-first-workout-completed (primary, sheet from SessionCompletionSheet dismiss)
- Settings → Notifications row (secondary)

**Primary action:** "Enable Notifications" → triggers OS dialog
**Secondary action:** "Not now" → dismisses without OS dialog
**Exit:** sheet dismiss (auto on grant/deny + manual on "Not now"/swipe-down)

#### Low-fi wireframe

```
┌─────────────────────────────────────────────────┐
│         (drag handle — sheet detent)             │
├─────────────────────────────────────────────────┤
│                                                  │
│              [bell.badge.fill icon]              │
│                                                  │
│       Stay on track with smart reminders         │  ← title
│                                                  │
│   FitMe can remind you about training, recovery, │  ← body (benefit, not mechanism)
│   and readiness — only when it matters.          │
│                                                  │
│   ──────────────────────────────────────────     │
│   You'll receive (3 categories):                 │  ← progressive disclosure
│   • Training reminders — when you've scheduled   │
│     a session                                    │
│   • Readiness alerts — when your recovery is     │
│     low before a workout                         │
│   • Recovery nudges — when your body needs rest  │
│   ──────────────────────────────────────────     │
│                                                  │
│   ┌────────────────────────────────────────┐     │
│   │     Enable Notifications               │     │  ← primary CTA, full-width
│   └────────────────────────────────────────┘     │
│                                                  │
│             Not now                              │  ← secondary, text-only
│                                                  │
└─────────────────────────────────────────────────┘
```

#### Hi-fi schematic

```swift
struct NotificationPermissionPrimingView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var gateway = NotificationGateway.shared
    @State private var primingState: PrimingState = .initial  // initial | requested | granted | denied

    enum TriggerContext: String { case postWorkout = "post_workout"; case settings = "settings" }
    let triggerContext: TriggerContext

    var body: some View {
        VStack(spacing: AppSpacing.large) {                       // 24pt rhythm
            Spacer()

            Image(systemName: "bell.badge.fill")
                .font(.system(size: 56))
                .foregroundStyle(AppColor.Accent.primary)
                .accessibilityHidden(true)

            Text("Stay on track with smart reminders")
                .font(AppText.titleStrong)                         // .title3, rounded, bold
                .foregroundStyle(AppColor.Text.primary)
                .multilineTextAlignment(.center)

            Text("FitMe can remind you about training, recovery, and readiness — only when it matters.")
                .font(AppText.body)
                .foregroundStyle(AppColor.Text.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.large)

            CategoryListView()                                     // sub-component, 3 bullets
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Notification categories: training reminders, readiness alerts, recovery nudges")

            Spacer()

            if primingState == .denied {
                DenialHintRow()                                    // "Notifications are off."
            }

            Button {
                Task { await requestPermission() }
            } label: {
                Text(primingState == .denied ? "Open Settings" : "Enable Notifications")
                    .font(AppText.button)
                    .foregroundStyle(AppColor.Text.inversePrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: AppSize.ctaHeight)              // 48pt — Fitts compliance
                    .background(AppColor.Accent.primary,
                                in: RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous))
            }
            .accessibilityLabel(primingState == .denied ? "Open notification settings" : "Enable notifications")
            .accessibilityHint("Opens the system permission dialog")

            Button("Not now") {
                analytics.log(AnalyticsEvent.notificationPrimingSkipped, params: [.triggerContext: triggerContext.rawValue])
                dismiss()
            }
            .font(AppText.caption)
            .foregroundStyle(AppColor.Text.tertiary)
            .accessibilityLabel("Skip enabling notifications")
        }
        .padding(.horizontal, AppSpacing.medium)
        .padding(.bottom, AppSpacing.large)
        .background(AppGradient.screenBackground.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            analytics.log(AnalyticsEvent.notificationPrimingShown, params: [.triggerContext: triggerContext.rawValue])
        }
    }

    private func requestPermission() async {
        analytics.log(AnalyticsEvent.notificationPermissionRequested)
        if primingState == .denied {
            if let url = URL(string: UIApplication.openSettingsURLString) { await UIApplication.shared.open(url) }
            return
        }
        await gateway.requestAuthorization()
        await MainActor.run {
            if gateway.isAuthorized {
                analytics.log(AnalyticsEvent.notificationPermissionGranted)
                Haptics.notification(.success)
                primingState = .granted
                dismiss()
            } else {
                analytics.log(AnalyticsEvent.notificationPermissionDenied)
                primingState = .denied
            }
        }
    }
}
```

### 2.2 SettingsDeepLinkBanner (in-Home, post-denial)

**Purpose:** One-time recovery surface for users who declined at the OS dialog. Reaffirms the value, makes Settings reachable in one tap, then disappears forever.

**Entry point:** Top of Home, conditional on `!authorized && !UserDefaults.notificationBannerDismissed`
**Primary action:** "Open Settings" → opens iOS Settings via `UIApplication.openSettingsURLString`
**Secondary action:** dismiss "X" → sets `UserDefaults.notificationBannerDismissed = true`
**Exit:** dismissal (manual or implicit on Open Settings tap)

#### Low-fi wireframe

```
┌─────────────────────────────────────────────────┐
│  ⚠  Notifications are off                  [×]  │
│     Enable in Settings to get reminders.        │
│                                  [Open Settings]│
└─────────────────────────────────────────────────┘
```

#### Hi-fi schematic

```swift
struct SettingsDeepLinkBanner: View {
    @AppStorage("notification.banner.dismissed") private var dismissed = false
    @ObservedObject var gateway = NotificationGateway.shared

    var body: some View {
        if !dismissed && !gateway.isAuthorized {
            HStack(spacing: AppSpacing.small) {                        // 12pt
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(AppColor.Status.warning)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Notifications are off")
                        .font(AppText.captionStrong)
                        .foregroundStyle(AppColor.Text.primary)
                    Text("Enable in Settings to get reminders.")
                        .font(AppText.caption)
                        .foregroundStyle(AppColor.Text.secondary)
                }

                Spacer()

                Button("Open Settings") {
                    analytics.log(AnalyticsEvent.notificationSettingsDeeplinkShown)
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(AppText.caption)
                .foregroundStyle(AppColor.Accent.primary)

                Button { dismissed = true } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                        .foregroundStyle(AppColor.Text.tertiary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Dismiss notification banner")
            }
            .padding(AppSpacing.small)
            .background(AppColor.Surface.secondary,
                        in: RoundedRectangle(cornerRadius: AppRadius.medium))
            .padding(.horizontal, AppSpacing.medium)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
```

### 2.3 Settings → Notifications row

**Purpose:** Permanent re-entry to the priming flow. Dynamic CTA based on authorization state (Recognition over Recall #5).

| State | Display label | Tap behavior |
|---|---|---|
| `false` + never asked (pre-priming) | "Enable Notifications" + chevron | Opens priming sheet (`triggerContext: .settings`) |
| `false` + previously denied | "Open iOS Settings" + chevron | `UIApplication.shared.open(openSettingsURLString)` |
| `true` (authorized) | "Notifications enabled" + checkmark | Opens preferences sub-screen (P2 — deferred) |

#### Low-fi wireframe

```
┌─────────────────────────────────────────────────┐
│ Settings                                         │
├─────────────────────────────────────────────────┤
│ Notifications                                    │
│  ┌─────────────────────────────────────────┐    │
│  │ Enable Notifications              ›     │    │  ← state: not asked
│  └─────────────────────────────────────────┘    │
│                                                  │
│  ── OR (state: denied) ──                        │
│  ┌─────────────────────────────────────────┐    │
│  │ Open iOS Settings                 ›     │    │
│  └─────────────────────────────────────────┘    │
│                                                  │
│  ── OR (state: authorized) ──                    │
│  ┌─────────────────────────────────────────┐    │
│  │ Notifications enabled        ✓ ›        │    │
│  └─────────────────────────────────────────┘    │
└─────────────────────────────────────────────────┘
```

### 2.4 Notification content (delivered notifications — content design only)

| Type | Title | Body | Sound | Badge? | Deep link |
|---|---|---|---|---|---|
| `trainingDay` (smart-reminders, owned) | "Time to train 💪" | "{personalized hour}: ready when you are." | default | no | `fitme://nav/training` |
| `restDay` (smart-reminders, owned) | "Rest day — recover well 🧘" | "Today's a rest day. Your body needs it." | default | no | `fitme://nav/home` |
| `readinessAlert` high (v2-new) | "You're ready" | "Readiness {X}/100. Good conditions for a hard session today." | default | no | `fitme://nav/home` |
| `readinessAlert` low (v2-new) | "Take it easy today" | "Readiness {X}/100. Consider a light session or rest." | default | no | `fitme://nav/home` |
| `nutritionGap` (smart-reminders, owned) | "Protein check-in 🥩" | (per ReminderType.swift) | default | no | `fitme://nav/nutrition` |

**No badge counts.** Badge as count would imply "you're behind" — Celebration not Guilt (#13).
**Tone:** affirming for high readiness, supportive for low. NEVER guilt-trip framing.

---

## 3. Full-Screen Composite — Priming Sheet (medium detent, iOS 16+)

```
╭─────────────────────────────────────────╮  ← iPhone 15 Pro frame (390 × 844)
│ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │  ← scrim over SessionCompletionSheet (40% opacity)
│ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │
├─────────────────────────────────────────┤  ← detent boundary (medium ≈ 50% screen)
│                                          │
│              ───── (drag handle)         │  ← presentationDragIndicator(.visible)
│                                          │
│                  🔔                      │  ← bell.badge.fill, 56pt, AppColor.Accent.primary
│                                          │
│                                          │
│   Stay on track with smart reminders     │  ← AppText.titleStrong, AppColor.Text.primary
│                                          │      multilineTextAlignment(.center)
│                                          │
│   FitMe can remind you about training,   │  ← AppText.body, AppColor.Text.secondary
│   recovery, and readiness — only when    │      ≤ 2 lines target, .center
│   it matters.                            │
│                                          │
│  ──────────────────────────────────      │  ← AppSpacing divider section
│  You'll receive:                         │  ← AppText.captionStrong
│   • Training reminders                   │  ← AppText.caption · 3 bullets
│   • Readiness alerts                     │
│   • Recovery nudges                      │
│  ──────────────────────────────────      │
│                                          │
│  ╭─────────────────────────────────────╮ │
│  │   Enable Notifications              │ │  ← AppText.button, height = AppSize.ctaHeight (48pt)
│  ╰─────────────────────────────────────╯ │      bg AppColor.Accent.primary, radius AppRadius.button
│                                          │
│             Not now                      │  ← AppText.caption, AppColor.Text.tertiary
│                                          │
╰─────────────────────────────────────────╯

Legend:
  ░  scrim (presented sheet darkens underlying view)
  🔔  hero icon (SF Symbol bell.badge.fill, 56pt)
  ───  divider (drag handle + section separators)
  ╭─╮  rounded rectangle (sheet container, primary CTA, sheet handle)
```

---

## 4. State Matrix

| Surface | Default | Loading | Empty | Error | Success | Disabled |
|---|---|---|---|---|---|---|
| **PrimingView (sheet)** | `primingState: .initial` — pre-CTA, full content | n/a (no async load) | n/a | `primingState: .denied` — denial banner shown, CTA copy = "Open Settings" | `primingState: .granted` — auto-dismiss with `.success` haptic | n/a (sheet always interactive when presented) |
| **SettingsDeepLinkBanner (Home top)** | Visible when `!authorized && !dismissed` | n/a | Hidden when `authorized` | n/a | n/a | Hidden when `dismissed = true` (UserDefaults flag) |
| **Settings → Notifications row** | "Enable Notifications" (not asked yet) | n/a | n/a | "Open iOS Settings" (denied) | "Notifications enabled" (authorized) | n/a |
| **Delivered notification (system)** | Banner + sound | n/a | n/a | n/a (system handles) | Tap → DeepLinkRouter routes; foreground = `[.banner, .sound, .list]` | Notification suppressed by quiet hours / cap → `.suppressed(reason)` analytics |

**No empty state for the priming flow itself** — categories list is hardcoded for v2 (3 categories). Future consumer additions are P2; empty-state question reopens then.

---

## 5. Interaction Patterns

| Surface | Navigation | Input | Feedback | Loading | Animation |
|---|---|---|---|---|---|
| Priming sheet | `.sheet(isPresented:)` from SessionCompletionSheet | Tap CTA | `.success` haptic on grant; `.warning` haptic on denial | n/a | Sheet drag indicator visible; default sheet motion |
| Denial banner | Inline (top of Home) | Tap "Open Settings" / Tap dismiss "X" | None on Open Settings (system handles); `.light` haptic on dismiss | n/a | `.transition(.move(edge: .top).combined(with: .opacity))` |
| Settings row | Tab → row → sheet (for not-asked) OR system call (for denied) OR sub-screen (for authorized — P2) | Tap | None (settings has its own conventions) | n/a | Standard navigation push or sheet present |
| Notification tap | OS-level → DeepLinkRouter → SwiftUI subscriber | OS tap | `.light` haptic on app foreground (existing pattern) | Loading skeleton if cold-start hits destination before data resolves | Tab switch animation (existing TabView default) |

---

## 6. Accessibility Specification

| Surface | VoiceOver | Dynamic Type | Tap Target | Reduce Motion |
|---|---|---|---|---|
| Priming sheet — bell icon | `.accessibilityHidden(true)` (decorative) | n/a | n/a | n/a |
| Priming sheet — title | Default (text reads as-is) | Scales (uses `.title3` token) | n/a | n/a |
| Priming sheet — body | Default | Scales (uses `.body`) | n/a | n/a |
| Priming sheet — category list | `.accessibilityElement(children: .combine)` + label combining all 3 categories | Scales (uses `.caption`) | n/a | n/a |
| Priming sheet — primary CTA | `.accessibilityLabel("Enable notifications")` + `.accessibilityHint("Opens the system permission dialog")` | Fixed font height; button height = `AppSize.ctaHeight` (48pt) | 48pt — exceeds 44pt minimum | n/a |
| Priming sheet — Not now | `.accessibilityLabel("Skip enabling notifications")` | Scales | Default Button frame ≥ 44pt | n/a |
| Denial banner — Open Settings | `.accessibilityLabel("Open notification settings")` | Scales | Default Button frame ≥ 44pt | Disable slide-in transition; appear/disappear instantly |
| Denial banner — dismiss X | `.accessibilityLabel("Dismiss notification banner")` | n/a (icon button) | 32pt visual, 44pt with default touch slop | n/a |
| Settings row | Default row VoiceOver | Scales | Standard List row ≥ 44pt | n/a |

**Reduce Motion:** wrap banner slide-in via `@Environment(\.accessibilityReduceMotion)` to skip the transition. Other surfaces have no animations to gate.

---

## 7. Principle Application Table

| # | Principle | How applied | Surface / Component |
|---|---|---|---|
| 3 | Jakob's Law | Use the same sheet+CTA pattern users see in iOS HealthKit, Strava, Hevy. No new pattern. | PrimingView sheet structure |
| 4 | Progressive Disclosure | Title + body + category list. Default doesn't dump all 9 example bodies. | PrimingView CategoryListView |
| 5 | Recognition over Recall | Settings row label changes by authorization state. Lists 3 categories on priming, not "you'll get reminders". | Settings row + PrimingView categories |
| 7 | Feedback | Every notification tap MUST route via DeepLinkRouter to expected destination. Haptic on grant. Banner on denial. | DeepLinkRouter; PrimingView haptic; SettingsDeepLinkBanner |
| 8 | Error Prevention | One-shot OS dialog protected by client-side state machine. One-time denial banner. No repeated prompts. | PrimingView state machine; SettingsDeepLinkBanner UserDefaults flag |
| 11 | Privacy by Default | All `notification_*` + `deep_link_routed` events consent-gated. Notification *content* never logged in analytics. | Analytics layer (consent gate) |
| 12 | Progressive Profiling | Trigger is post-first-workout-completed, not first-app-open. ≥30 min invested before being asked. | FitTrackerApp wiring (T6) |
| 13 | Celebration Not Guilt | readinessAlert low-direction copy: "Consider a light session or rest" — supportive. No badge counts. | Notification content matrix §2.4 |

---

## 8. Component Inventory

| Component | Status | Source / Path |
|---|---|---|
| `NotificationPermissionPrimingView` | Existing (revived from v1; HISTORICAL banner removed) | `FitTracker/Views/Notifications/NotificationPermissionPrimingView.swift` |
| `SettingsDeepLinkBanner` | New | `FitTracker/Views/Notifications/SettingsDeepLinkBanner.swift` |
| `CategoryListView` (sub-component) | New (private struct inside PrimingView file) | inline |
| `DenialHintRow` (sub-component) | New (private struct inside PrimingView file) | inline |
| Settings → Notifications row | Edit existing Settings view | `FitTracker/Views/Settings/v2/SettingsView.swift` (current settings v2 location) |

**No new shared components in `FitTracker/DesignSystem/`.** All v2 surfaces compose from existing tokens + framework primitives.

---

## 9. Token References (for `/ux preflight` to verify)

All tokens used by this spec exist in the codebase as of 2026-05-07. Preflight should pass cleanly.

| Token family | Tokens used | Verified at |
|---|---|---|
| `AppText` | `titleStrong`, `body`, `button`, `caption`, `captionStrong` | `FitTracker/Services/AppTheme.swift:232-241` |
| `AppSpacing` | `large`, `medium`, `small`, `xSmall` | Standard spacing scale (used by v1 priming view at lines 19/39/45/52/77/78) |
| `AppRadius` | `medium`, `button` (=20) | `AppTheme.swift:164` |
| `AppColor` | `Accent.primary`, `Text.primary`, `Text.secondary`, `Text.tertiary`, `Text.inversePrimary`, `Status.warning`, `Surface.secondary` | All in use across v1 priming view + existing app surfaces |
| `AppSize` | `ctaHeight` | Used by v1 priming view line 64 |
| `AppGradient` | `screenBackground` | Used by v1 priming view line 16 |

**No new tokens needed for v2.** Preflight expected to land green (zero P0).

**Pattern references (P2 if absent — non-blocking):**
- `.presentationDetents([.medium, .large])` — iOS 16+ standard, used elsewhere in app
- `.transition(.move(edge: .top).combined(with: .opacity))` — used in existing banners
- `@AppStorage` for UserDefaults flag — existing pattern

---

## 10. Feature Design Checklist

| Item | Status |
|---|---|
| All screens covered (priming sheet, denial banner, settings row) | ✓ |
| All 5 states covered per screen | ✓ §4 state matrix |
| All interactive elements have accessibilityLabel | ✓ §6 |
| All buttons ≥ 44pt tap target | ✓ §6 (banner X is 32pt visual but 44pt with default touch slop) |
| Dynamic Type support documented | ✓ §6 — all text uses scaling tokens |
| Reduce Motion alternative documented | ✓ §6 — banner slide-in respects `accessibilityReduceMotion` |
| All applicable principles mapped to design decisions | ✓ §7 (8 of 13) |
| All tokens map to existing semantic tokens | ✓ §9 — zero new tokens needed |
| Analytics events listed and mapped to triggers | ✓ — see PRD §"Analytics Spec" + spec body inline event calls |
| User flows defined (primary, skip, error, edge) | ✓ §1 |
| Cross-references to ux-foundations.md | ✓ §1.1 (Part 5.2 priming pattern), §6 (Part 8 accessibility), §7 (Part 1 principles) |

---

## 11. v2 Refactor Checklist (`/ux` ownership — Sections A/E/F/G/H)

`new_feature` subtype, no v1 surface to refactor against. Sections A/E/F/G/H apply forward-looking only:

- **Section A — Audit-driven scope:** N/A (no v1 audit; v1 was never reachable)
- **Section E — Token coverage:** §9 verified; preflight will reconfirm
- **Section F — Component reuse:** §8 inventory; only `NotificationPermissionPrimingView` is revived, rest are new for v2 platform layer
- **Section G — Accessibility coverage:** §6 — all surfaces covered
- **Section H — Animation/motion:** §5 — only banner slide-in, with reduce-motion alternative

---

## 12. Open Questions

None new. All 8 PRD OQs remain resolved per Phase 1.

---

## 13. Next Step

→ `/ux validate push-notifications` (heuristic re-check against Nielsen's 10 + 13 ux-foundations principles)
→ `/ux preflight push-notifications` (P0 gate: token/component existence verification)
