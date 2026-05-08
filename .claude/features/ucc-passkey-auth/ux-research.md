# UX Research — `ucc-passkey-auth`

**Phase 3 sub-step 3b** · written before ux-spec to ground design decisions in named principles
**Companion to:** [`research.md`](./research.md) (technical brief) and [`prd.md`](./prd.md) §5
**Surface:** fitme-story Next.js 16 (Tailwind v4, dark-mode `.dark` class, Editorial design language)

---

## 1. Applicable UX principles

| Principle | How it applies here |
|---|---|
| **Recognition over recall** | The sign-in screen surfaces "Unlock with passkey" + brand mark + (when conditional-UI fires) the platform's autofill suggesting the right credential. The operator never types or remembers anything. |
| **Fitts's Law** | Primary CTA at the page-center, large hit-target (≥ 48 px tall × ≥ 240 px wide), clear focus ring. Devices admin Revoke buttons inline-aligned with row text — same 44-pt minimum. |
| **Hick's Law** | Sign-in screen has ONE primary action ("Unlock with passkey"), ONE secondary ("Lost your device?"). Devices admin shows ONE row per credential, ONE Revoke per row. No "register another" / "manage" / "settings" detour. |
| **Progressive disclosure** | Bootstrap-token entry only appears via the Recover screen URL — never on the main sign-in page. Audit log is separate from Devices admin. The framework-health embed shows summary stats; clicking through reveals the full event log. |
| **Feedback** | Every WebAuthn ceremony state has a visible response: idle (button), pending ("Waiting for Touch ID..."), success (checkmark + brief animation before redirect), error (inline banner + retry CTA). No silent failures. |
| **Error prevention** | Bootstrap tokens are single-use + 15-min TTL — even if pasted to the wrong field they're scoped. Revoke is a one-click action with a toast-confirm; mistakes are recoverable since the credential record stays in Redis (just `revokedAt` is set, can be unset by an operator-2 if needed within minutes). |
| **Consistency (internal)** | Reuses the iOS `auth-polish-v2` UX cadence: brand icon, single-sentence reassurance, primary CTA, "Not now" secondary, inline error banner (not modal). Single auth UX vocabulary across FitMe surfaces. |
| **Consistency (external)** | Follows the Apple HIG passkey pattern (iOS 17+ Settings → Passkeys flow): autofill on focus, biometric confirmation, no password fallback. Operators on Mac have already seen this pattern in their iCloud Keychain. |

## 2. iOS HIG / WebAuthn UX references

- **Apple HIG — Passkeys overview:** https://developer.apple.com/passkeys/ — sign-in flow follows the autofill-on-focus pattern; passkeys are strictly biometric/PIN, never typed.
- **W3C WebAuthn UX best practices:** https://www.w3.org/TR/webauthn-3/#sctn-user-verification — present the platform-authenticator prompt as the single moment of friction; everything else should be ambient.
- **`navigator.credentials.get()` with `mediation: 'conditional'`:** https://web.dev/passkey-form-autofill/ — the conditional-UI pattern triggers the autofill prompt automatically when the sign-in form is rendered with the right autocomplete attributes (`autocomplete="username webauthn"`).
- **FIDO Alliance — Passkey UX guidelines:** https://fidoalliance.org/ux-guidelines/ — single-tap, no password fallback, clear recovery path, never block on lost-device.

## 3. Patterns from `auth-polish-v2` (iOS) — port verbatim

The iOS app's biometric activation flow is the canonical precedent. Four port-verbatim elements:

1. **Brand icon** (orange Fit:Me dot on the canvas; same SVG used on the iOS welcome screen)
2. **Single-sentence reassurance** ("Your data stays encrypted on this device" → web equivalent: "Your passkey never leaves this device")
3. **Inline `AuthBannerView` for failures** (not modal alerts) → web equivalent: a `<div role="alert">` styled with the existing rose/coral error pill from `primitives.tsx`
4. **Sheet-style activation cadence** — bootstrap registration uses a centered card (not a full-page modal), focus on the primary CTA, "Not now" secondary that navigates back

## 4. Screen-by-screen UX intent

### Sign-in (`/control-room/sign-in`)

**Intent:** zero-cognitive-load entry to the dashboard. The conditional-UI autofill prompt should fire automatically on page load; the "Unlock with passkey" button is the manual fallback.

- **Above the fold:** brand mark, page title ("FitMe Control Room — Sign in"), single-sentence reassurance, `<input type="text" autocomplete="username webauthn">` + "Unlock" button.
- **Conditional UI:** focus on the input → autofill prompt → biometric → redirect.
- **Manual flow:** click button → `navigator.credentials.get({ mediation: 'required' })` → biometric → redirect.
- **Lost device link:** below the primary card, small text-link "Lost your device? Recover access" → `/control-room/sign-in/recover`.

### Recover (`/control-room/sign-in/recover`)

**Intent:** explicit, intentional flow for first-device registration AND recovery. Never reachable from the main dashboard navigation — only via the lost-device link or by URL with a `?bootstrap=<token>` query param.

- **Two states:** (a) no token in URL → display token-paste field + instructions on how to obtain one (CLI command snippet); (b) token in URL → auto-fill + start registration ceremony.
- **Same brand cadence** as sign-in.
- **Success path:** redirects back to sign-in with a confirmation toast; operator immediately uses the just-registered passkey.

### Devices admin (`/control-room/settings/devices`)

**Intent:** single-glance audit of registered credentials. Lightweight admin since 1–3 operators × 1–2 devices each = ≤ 6 rows.

- **Table layout:** label · device type (platform/cross-platform) · createdAt · lastUsedAt · IP class (most recent) · Revoke button.
- **Empty state:** "No credentials registered yet. Use the bootstrap CLI to add your first device" with a code snippet.
- **Revoke confirmation:** click Revoke → inline confirm pill ("Revoke this credential?" Yes/Cancel) — NOT a modal alert. Mirrors the inline-banner pattern from `auth-polish-v2`.
- **Empty + revoked rows:** revoked credentials show with strikethrough + `revokedAt` + a "Permanently delete" action (admin-only, last-90-days retention).

### Audit log (`/control-room/settings/audit`)

**Intent:** chronological event viewer for forensic review. Read-only.

- **List layout:** newest first, last 50 events. Columns: timestamp · event_type · operator_label · outcome (success/error pill).
- **Filter chip row:** filter by event_type (all / authenticate / register / revoke / session). Single-select.
- **Click event:** expand inline to show all fields (credential_id_hash, ip_class, ua_family, reason, duration_ms).
- **Empty state:** "No events recorded yet" — fires only on a fresh deploy.

### AuditLogPanel (embedded in `/control-room/framework`)

**Intent:** at-a-glance auth-system health visible to anyone on the framework-health page. Not a full audit viewer — just enough to flag anomalies.

- **3-stat row:** Registered devices · Authentications (7d) · Failed (7d, red if > 0)
- **Recent events table:** last 5 events, same column shape as the full audit page
- **Suspicious-event banner:** appears only on anomalies (≥ 3 fails in last hour, register from new IP/UA, revoke in last 24h). Dismissible per-page-load (state local).
- **Link to full audit log:** small text-link bottom-right.

## 5. Accessibility requirements

- **Tap targets ≥ 44 pt** on all CTAs and Revoke buttons.
- **WCAG AA contrast** for all text + icons on both light and dark backgrounds. The fitme-story `globals.css` already provides AA-passing variants in dark mode (`--color-neutral-500: #A8A29E`); we reuse those.
- **VoiceOver / NVDA labels** on every input + button: `aria-label`, `aria-describedby` for the reassurance line, `role="alert"` on error banners.
- **Dynamic Type / Browser zoom** up to 200% — no clipped text, no overflow. Tested against a 100ch viewport at 200%.
- **Reduced motion:** `globals.css` already kills animations under `prefers-reduced-motion: reduce`. We add nothing custom that bypasses this.
- **Focus rings:** Tailwind `focus-visible:ring-2 focus-visible:ring-brand-indigo focus-visible:ring-offset-2` on every interactive element.

## 6. Motion

- **Brand-coral pulse** on the unlock button (same animation used on the iOS sign-in screen) — fires only after page load if no autofill prompt appears within 800 ms (gentle nudge that the button is the alternative path).
- **Success fade-out** before redirect (~250 ms) — not configurable; suppressed under reduce-motion.
- **No mid-ceremony animation** during the `navigator.credentials.get()` call — that's the platform's own UI surface; we don't compete with it.

## 7. Decisions log

| OQ | Question | Decision | Rationale |
|---|---|---|---|
| OQ-1 | Single sign-in input or no input? | **Single `<input type="text" autocomplete="username webauthn">`** (visible but unused in conditional-UI mode) | Required by browsers to anchor the autofill prompt. Hidden input doesn't trigger the prompt. |
| OQ-2 | Modal vs page for sign-in? | **Page** at `/control-room/sign-in` | Modal would be a layered surface with no parent context (unauthenticated → no dashboard yet). Page is honest about the state. |
| OQ-3 | Where does the brand mark live? | **Top-of-page**, ~96 px tall, centered | Matches `auth-polish-v2` welcome screen. |
| OQ-4 | Sign-out destination? | **`/control-room/sign-in`** (not the marketing home) | Operator wants to re-enter, not browse the showcase. |
| OQ-5 | Show TTL countdown on bootstrap token paste field? | **No** (15-min server-enforced is sufficient) | Visual countdown adds anxiety without adding security. Server returns "expired" if too late. |
| OQ-6 | Group AuditLogPanel + Stats panel on framework page? | **Separate cards** | Already separate concerns; co-locating creates visual conflation. |
| OQ-7 | Event-row click → expand inline OR open detail page? | **Expand inline** | Page-load + back-navigation is heavier than the gain; events are leaf nodes (no further drill-down needed). |
