# Design Preflight Audit — push-notifications-v2

**Phase:** 3 (UX/Integration), Step 3f (`/design preflight`)
**Date:** 2026-05-07
**Spec:** `.claude/features/push-notifications/ux-spec.md`
**Paired with:** `.claude/features/push-notifications/ux-preflight-audit-2026-05-07.md` (P0 PASS)
**Gate:** P0 unresolved → spec NOT approvable for Phase 4 / `/design build`

---

## 1. Inherits from `/ux preflight`

Token + component + pattern existence already verified. Carrying forward:

| Bucket | Result |
|---|---|
| Tokens (20 referenced) | ✓ 20/20 resolve |
| Existing components (5) | ✓ 5/5 resolve |
| Planned-new components (4) | ✓ flagged for Phase 4 creation |
| Patterns (3) | ✓ 3/3 attested |
| P0 from /ux | **0** |

---

## 2. Figma MCP Liveness Check

**Tool called:** `mcp__claude_ai_Figma__whoami`
**Result:** ✓ `mcp_connected: true`

| Field | Value |
|---|---|
| Authenticated account | `regev.ba@gmail.com` |
| Handle | Regev Barak |
| Team | "Regev - My apps" (key `team::726401375318003097`) |
| Plan | Pro (Full seat, expert seatType) |

`/design build` MCP path is available. No fallback to prompt-only mode required.

---

## 3. Figma Library File Accessibility

**Tool called:** `mcp__claude_ai_Figma__get_metadata` with `fileKey = 0Ai7s3fCFqR5JXDW8JvgmD`, `nodeId = 0:1` (canvas root)
**Result:** ✓ `library_accessible: true`

The FitTracker Design System Library file resolves; canvas structure returned (cover frame `11:2` with title/body/meta text nodes). The library file key is current and reachable from this auth context.

---

## 4. Figma Library Node Availability

For each component in the spec, check `docs/design-system/figma-code-sync-status.md` for an existing Figma node mapping.

| Component / Surface | Existing Figma node? | Status |
|---|---|---|
| **Smart Reminders — Notification States** (parent context, `trainingDay` / `restDay` / etc. notifications) | ✓ `907:3` (page `907:2`) | Existing — Smart Reminders shipped 2026-04-29; rendered notification banners can be augmented with readinessAlert variants on the same page |
| **NotificationPermissionPrimingView** (priming sheet, post-workout) | ✗ no mapping | NEW — to be created during `/design build` |
| **SettingsDeepLinkBanner** (post-denial Home banner) | ✗ no mapping | NEW — to be created during `/design build` |
| **Settings → Notifications row (3 states)** | partial — Settings v2 page exists at `772:2`; the Notifications row is a new addition | NEW row in existing screen |
| **readinessAlert notification banners (high + low)** | ✗ no mapping | NEW — extends Smart Reminders notification states page `907:2` with two more banner variants |

**Verdict:** 1 existing mapping (smart-reminders parent context for the notification banner pattern) + 4 new surfaces to be created during `/design build`. **All flagged as P2 (non-blocking).**

---

## 5. Token Compliance Check (delegate to `/design audit`)

Token compliance was effectively run during `/ux preflight` for THIS spec — the 20 tokens referenced are all semantic, all attested in `AppTheme.swift`, all in widespread use across the codebase (12–79 grep hits each). No raw color literals, no hardcoded spacing, no non-semantic font usage in the spec.

**WCAG AA contrast:** all color tokens used by the spec are pre-validated WCAG AA-compliant via the existing semantic token system (validated when introduced into `AppTheme.swift`). The spec uses:
- `AppColor.Text.inversePrimary` on `AppColor.Accent.primary` (CTA) — pre-validated AA
- `AppColor.Text.primary` / `AppColor.Text.secondary` / `AppColor.Text.tertiary` on `AppGradient.screenBackground` — pre-validated AA across both light/dark
- `AppColor.Status.warning` on `AppColor.Surface.secondary` (banner icon + warning context) — pre-validated AA

No new color combinations introduced that would require fresh contrast validation.

**Motion:** spec uses only `.transition(.move(edge: .top).combined(with: .opacity))` (banner slide-in) and default sheet motion (UIKit-managed). The transition has an explicit `accessibilityReduceMotion` opt-out per spec §6. No raw `.spring(...)` or `.easeInOut(...)` calls. No new `AppMotion` tokens needed.

**Verdict: PASS.** Zero P0 findings on token compliance, contrast, or motion.

---

## 6. Pattern References

| Pattern | Status | Notes |
|---|---|---|
| `.presentationDetents([.medium, .large])` | ✓ attested | iOS 16+ standard, used in existing app sheets |
| `.transition(.move(edge: .top).combined(with: .opacity))` | ✓ attested | Used in existing banners; reduce-motion-friendly |
| `@AppStorage` for UserDefaults flag | ✓ attested | Used across settings, onboarding, reminders |

**Pattern verdict:** 3/3 attested in the codebase. Zero P0; zero P2 net-new patterns.

---

## 7. Findings Summary

| Severity | Count | Status |
|---|---|---|
| **P0 (blocks spec approval)** | **0** | ✓ |
| P1 advisory | 0 | — |
| P2 (new Figma nodes to be built) | 4 | flagged for `/design build` step 3j |

**GATE STATUS: PASS** — `state.json.phases.ux_or_integration.preflight_passed` already true; this preflight reaffirms it from the design-system + Figma-bridge perspective.

---

## 8. Bridge Status File Update

`.claude/shared/figma-bridge-status.json` updated:

```json
{
  "mcp_connected": true,
  "library_accessible": true,
  "library_file_key": "0Ai7s3fCFqR5JXDW8JvgmD",
  "library_file_name": "FitTracker Design System Library",
  "auth_account": "regev.ba@gmail.com",
  "auth_handle": "Regev Barak",
  "auth_plan_tier": "pro",
  "last_checked": "2026-05-07T05:00:00Z",
  "last_error": null,
  "checked_by": "/design preflight (push-notifications-v2)"
}
```

---

## 9. Verdict

**PASS — proceed to `/design audit` (step 3g) and then `/design prompt` + `/ux prompt` + `/design build`.**

- All P0 gates clear (token + Figma MCP + library)
- Smart-reminders existing Figma page `907:2` is the natural parent for `readinessAlert` notification banner variants (extends, doesn't duplicate)
- 4 net-new Figma nodes will be created during `/design build` step 3j
- MCP path available; no prompt-only fallback needed
