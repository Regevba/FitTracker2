# Design Build Prompt — Push Notifications v2

**Feature:** push-notifications (v2 platform-layer rebuild)
**Target agent:** Figma MCP agent (primary) + SwiftUI implementation agent (consumer of token contract)
**Date:** 2026-05-07
**Linear:** FIT-23
**Paired with:** `docs/prompts/ux/2026-05-07-push-notifications-ux-build.md`

---

## Visual Target

- **Figma file key:** `0Ai7s3fCFqR5JXDW8JvgmD` (FitTracker Design System Library)
- **Existing parent page:** `907:2` (Smart Reminders — Notification States) → readinessAlert banner variants extend this page
- **Existing Settings v2 frame:** `772:2` → Notifications row is a new addition to this screen
- **Net-new frames to create (4):**
  1. NotificationPermissionPrimingView — sheet (medium detent, iOS 16+)
  2. SettingsDeepLinkBanner — in-Home, post-denial banner
  3. Settings → Notifications row — 3 state variants
  4. readinessAlert banner variants — extends page `907:2` with high + low banners

---

## Screen Inventory

### A. NotificationPermissionPrimingView (sheet)
- **Detents:** medium + large (iOS 16+)
- **Layout:** vertical stack — drag handle → bell icon → title → body → 3-category list → primary CTA → secondary CTA
- **Background:** `AppGradient.screenBackground` (full bleed, ignoresSafeArea)
- **Primary CTA:** full-width, height = `AppSize.ctaHeight` (48pt), bg `AppColor.Accent.primary`, fg `AppColor.Text.inversePrimary`, radius `AppRadius.button` (20pt continuous)
- **Secondary CTA:** text-only, font `AppText.caption`, fg `AppColor.Text.tertiary`

### B. SettingsDeepLinkBanner (Home top)
- **Layout:** horizontal — warning triangle → text stack (title + subtitle) → spacer → "Open Settings" link → dismiss X
- **Background:** `AppColor.Surface.secondary`, radius `AppRadius.medium`
- **Padding:** `AppSpacing.small` interior; `AppSpacing.medium` horizontal margin
- **Transition:** `.move(edge: .top).combined(with: .opacity)` (reduce-motion-gated)

### C. Settings → Notifications row (3 variants)
- **Container:** existing Settings v2 row pattern (`SettingsActionLabel` or equivalent)
- **State 1 (not asked):** "Enable Notifications" label + chevron trailing
- **State 2 (denied):** "Open iOS Settings" label + chevron trailing
- **State 3 (authorized):** "Notifications enabled" label + checkmark trailing

### D. readinessAlert banner frames (extends Smart Reminders page `907:2`)
- **High variant:** title "You're ready"; body "Readiness {X}/100. Good conditions for a hard session today." Match existing reminder banner pattern (title + body, default sound icon, deep-link target)
- **Low variant:** title "Take it easy today"; body "Readiness {X}/100. Consider a light session or rest." Same banner pattern

---

## Token Contract (use ONLY these — no raw literals)

### Typography (`AppText.*`)
| Token | Use |
|---|---|
| `titleStrong` (`.title3` rounded bold) | Priming sheet title |
| `body` (`.body` rounded medium) | Priming sheet body copy |
| `button` (`.body` rounded semibold) | Primary CTA label |
| `caption` (`.caption` rounded) | Secondary CTA, banner subtitle, Settings row tertiary text |
| `captionStrong` (`.caption` rounded semibold) | Banner title, category list label |

### Colors (`AppColor.*`)
| Token | Use |
|---|---|
| `Accent.primary` | Primary CTA bg, hero icon, "Open Settings" link in banner |
| `Text.primary` | Priming sheet title, banner title |
| `Text.secondary` | Priming sheet body, banner subtitle |
| `Text.tertiary` | "Not now" CTA, dismiss X icon |
| `Text.inversePrimary` | Primary CTA label (on Accent.primary bg) |
| `Status.warning` | Banner warning triangle |
| `Surface.secondary` | Banner background |

### Spacing (`AppSpacing.*`)
| Token | Use |
|---|---|
| `large` (24pt) | Priming sheet vertical rhythm; horizontal padding |
| `medium` (16pt) | Priming sheet horizontal padding; banner horizontal margin |
| `small` (12pt) | Banner interior padding; HStack gap in banner |
| `xSmall` (8pt) | Tight gaps within banner text stack |

### Radius (`AppRadius.*`)
| Token | Use |
|---|---|
| `button` (20pt) | Primary CTA rounded rectangle |
| `medium` | Banner rounded rectangle |

### Sizes (`AppSize.*`)
| Token | Use |
|---|---|
| `ctaHeight` (48pt) | Primary CTA height |

### Gradients (`AppGradient.*`)
| Token | Use |
|---|---|
| `screenBackground` | Priming sheet full-bleed background |

### Motion
- **Sheet:** default UIKit-managed (`.presentationDetents([.medium, .large])` + `.presentationDragIndicator(.visible)`)
- **Banner slide-in:** `.transition(.move(edge: .top).combined(with: .opacity))` — gated on `accessibilityReduceMotion`
- **Haptics:** `Haptics.notification(.success)` on permission grant; `.light` on banner dismiss
- **No raw `.spring(...)` or `.easeInOut(...)` allowed**

---

## Component Contract

### Reused (existing)
| Component | Source | Reuse status |
|---|---|---|
| `NotificationPermissionPrimingView` | `FitTracker/Views/Notifications/NotificationPermissionPrimingView.swift` | Revival — un-mark HISTORICAL banner |
| Settings v2 row pattern (`SettingsActionLabel` or equivalent) | `FitTracker/Views/Settings/v2/` | Edit existing screen |
| `Haptics.notification(.success)` | existing pattern | Use directly |
| SF Symbols: `bell.badge.fill` (56pt hero), `exclamationmark.triangle.fill` (banner), `xmark` (12pt dismiss) | system icons | Use directly |

### New
| Component | Justification |
|---|---|
| `NotificationGateway` (singleton, `@MainActor`) | Single auth + dispatch + cap audit surface for all consumers (smart-reminders + future) |
| `DeepLinkRouter` (singleton, `@MainActor`, `@Published pendingDeepLink: DeepLinkAction?`) | Single URL → action surface; observable by SwiftUI root |
| `DeepLinkAction` enum (`navigateToTab`, `presentSheet`, `authFlow`, `settingsSection`) | Strongly-typed action variants for nested verb-noun grammar |
| `NotificationConsumerRegistry` | Per-consumer types + URL patterns + cap contributions |
| `SettingsDeepLinkBanner` (`@AppStorage`-backed dismiss flag, `@ObservedObject NotificationGateway`) | Post-denial recovery surface; no existing equivalent |
| `CategoryListView` (private to PrimingView) | 3-bullet category list with `.accessibilityElement(children: .combine)` |
| `DenialHintRow` (private to PrimingView) | Inline hint shown when `primingState == .denied` |
| `ReadinessAlertObserver` | Combine subscription bridging ReadinessEngine.latestScore to NotificationGateway.dispatch |

---

## State Variants — Visual specs

### NotificationPermissionPrimingView

| State | Visual diff from default |
|---|---|
| `.initial` | Default — bell icon + full content + "Enable Notifications" CTA |
| `.denied` | DenialHintRow visible above CTA (warning triangle + "Notifications are off. Enable in Settings to get reminders."); CTA copy → "Open Settings"; `accessibilityLabel` swaps to "Open notification settings" |
| `.granted` | Sheet auto-dismisses (no terminal visual state shown) |

### SettingsDeepLinkBanner

| State | Visibility |
|---|---|
| `!authorized && !dismissed` | Visible at top of Home |
| `authorized` | Hidden |
| `dismissed` (UserDefaults flag) | Hidden permanently |

### Settings → Notifications row

| State | Visual |
|---|---|
| Not asked | Plain row, "Enable Notifications" label, chevron right |
| Denied | Plain row, "Open iOS Settings" label, chevron right |
| Authorized | Plain row, "Notifications enabled" label, checkmark + chevron right |

---

## Figma Node Plan

| Surface | Existing/New | Parent | Notes |
|---|---|---|---|
| readinessAlert banners (2 variants) | NEW | page `907:2` (Smart Reminders) | Add as 7th + 8th banner in the existing Smart Reminders page; matches the 6 existing reminder banners' visual pattern |
| NotificationPermissionPrimingView | NEW | new page (suggested name "Notifications — Permission Priming" or extend page `907:2`) | Sheet frame; medium detent height ~50% of iPhone 15 Pro screen |
| SettingsDeepLinkBanner | NEW | same page as above | Banner-only frame; can pair with priming sheet as variant in same frame |
| Settings → Notifications row (3 states) | NEW row in existing Settings v2 page `772:2` | `772:2` | Add row to existing Settings screen; capture row's node ID after creation |

After build, capture all 4 node IDs back to `state.json.figma_node_ids`:
```json
{
  "priming_sheet": "{node_id}",
  "denial_banner": "{node_id}",
  "settings_row_states": "{node_id}",
  "readiness_alert_banners": "{node_id}"
}
```

And add a row to `docs/design-system/figma-code-sync-status.md`:

```
| Push Notifications v2 | priming `{node}` + banner `{node}` + settings row `{node}` + readiness banners `{node}` (page `907:2`) | Services/Notifications/{NotificationGateway,DeepLinkRouter,NotificationConsumerRegistry,ReadinessAlertObserver}.swift + Views/Notifications/{NotificationPermissionPrimingView,SettingsDeepLinkBanner}.swift + Views/Settings/v2/SettingsView.swift | Synced (auto-built) | Built 2026-05-07 by /design build during Phase 3.j of push-notifications-v2 PM lifecycle. Four mobile frames + readiness alert banner extension on Smart Reminders page. All semantic tokens, zero raw colors. |
```

---

## Accessibility Contract

- Tap targets ≥ 44pt (primary CTA 48pt; default Buttons; banner X 32pt visual + 12pt touch slop)
- WCAG AA contrast: pre-validated via semantic tokens (no new color combinations)
- VoiceOver labels: 6/6 interactive elements (per ux-spec §6)
- Dynamic Type: all text uses scaling tokens (`AppText.*`)
- Reduce Motion: banner slide-in respects `accessibilityReduceMotion`; sheet uses default UIKit motion
- Decorative icons hidden: bell icon `.accessibilityHidden(true)`

---

## Handoff Checklist (Figma MCP agent)

- [ ] Build sheet frame for NotificationPermissionPrimingView (medium detent, ~50% height)
- [ ] Build SettingsDeepLinkBanner frame (in-Home top placement)
- [ ] Add Notifications row to Settings v2 page `772:2` with 3 state variants
- [ ] Add 2 readinessAlert banner variants to Smart Reminders page `907:2`
- [ ] Capture all 4 Figma node IDs
- [ ] Write node IDs back to `state.json.figma_node_ids`
- [ ] Append row to `docs/design-system/figma-code-sync-status.md`
- [ ] Verify all frames use library variables only (no raw color literals)
- [ ] Take screenshot of each frame and attach to Phase 3 approval message

---

## References

- **PRD:** `docs/product/prd/push-notifications.md`
- **UX Spec:** `.claude/features/push-notifications/ux-spec.md`
- **UX Research:** `.claude/features/push-notifications/ux-research.md`
- **State:** `.claude/features/push-notifications/state.json`
- **AppTheme.swift:** `FitTracker/Services/AppTheme.swift`
- **AppComponents.swift:** `FitTracker/DesignSystem/AppComponents.swift`
- **figma-code-sync-status.md:** `docs/design-system/figma-code-sync-status.md`
- **figma-bridge-status.json:** `.claude/shared/figma-bridge-status.json` (mcp_connected=true verified 2026-05-07T05:00Z)
- **Paired:** `docs/prompts/ux/2026-05-07-push-notifications-ux-build.md`
