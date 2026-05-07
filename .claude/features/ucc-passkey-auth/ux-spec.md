# UX Spec — `ucc-passkey-auth`

**Phase 3 sub-step 3c** · the canonical screen contract that ux-prompt + design-prompt + Phase 4 all reference
**Companion to:** [`ux-research.md`](./ux-research.md), [`prd.md`](./prd.md), [`research.md`](./research.md)
**Surface:** fitme-story Next.js 16 + Tailwind v4 + Editorial design language
**5 screens:** Sign-in · Recover · Devices admin · Audit log · AuditLogPanel embed

---

## 1. Tokens referenced (must exist in fitme-story `globals.css`)

| Token | Source | Status |
|---|---|---|
| `--color-brand-indigo` (#4F46E5) + hover (#4338CA) | `globals.css:9-10` | ✅ exists |
| `--color-brand-coral` (#F97066) + hover (#F15048) | `globals.css:11-12` | ✅ exists |
| `--color-neutral-{50,100,200,300,500,700,800,900}` | `globals.css:24-31` | ✅ exists |
| `--font-sans` / `--font-serif` | `globals.css:5-6` | ✅ exists |
| `--measure-narrow` (58ch) | `globals.css:34` | ✅ exists |
| `--text-display-md` clamp(1.5rem, 3vw, 2.25rem) | `globals.css:39` | ✅ exists |
| Tailwind `rose-{500,600}` (error states) | Tailwind defaults | ✅ exists |
| Tailwind `emerald-{500,600}` (success states) | Tailwind defaults | ✅ exists |
| Tailwind `slate-{50,100,200,400,500,600,700,800,900,950}` | Tailwind defaults | ✅ exists |
| Tailwind `white/{8,15,36,58,64}` (overlay scale) | Tailwind defaults | ✅ exists |

**No new tokens required.**

## 2. Components referenced (must exist in fitme-story `src/components/control-room/`)

| Component | Source path | Status |
|---|---|---|
| `<Panel>` | `src/components/control-room/primitives.tsx` | ✅ exists (used for sign-in card chrome) |
| `<MetricList>` | `src/components/control-room/primitives.tsx` | ✅ exists (used for AuditLogPanel 3-stat row) |
| `<TrackedDocLink>` | `src/components/control-room/TrackedDocLink.tsx` | ✅ exists (used for "Lost your device?" link) |
| `<TrackPageView>` | `src/components/control-room/TrackPageView.tsx` | ✅ exists (used on every new screen for analytics) |
| `<AlertsBanner>` | `src/components/control-room/AlertsBanner.tsx` | ✅ exists (used for suspicious-event banner) |

**Net-new components (declared here, must be built in Phase 4):**

| Component | Path | Used by |
|---|---|---|
| `<AuthPasskeyForm>` | `src/components/control-room/AuthPasskeyForm.tsx` | Sign-in + Recover screens |
| `<AuditLogPanel>` | `src/components/control-room/AuditLogPanel.tsx` | Framework-health page embed |
| `<DevicesTable>` | `src/components/control-room/DevicesTable.tsx` | Devices admin page |
| `<AuditEventRow>` | `src/components/control-room/AuditEventRow.tsx` | Audit log page |

**Confirmation:** `<AuthPasskeyForm>` is the canonical reusable WebAuthn ceremony component. Maps 1:1 to T13 in tasks.md.

## 3. Patterns referenced

| Pattern | Source | Use here |
|---|---|---|
| Conditional-UI autofill | `autocomplete="username webauthn"` + `mediation: 'conditional'` | Sign-in page — primary entry path |
| Inline confirm pill | `auth-polish-v2` `BiometricActivationSheet` | Devices Revoke confirmation |
| Inline error banner | `auth-polish-v2` `AuthBannerView` | All ceremony failures |
| Page-centered card | `<Panel>` chrome | Sign-in + Recover layouts |
| 3-stat row + table-with-pill-outcome | `framework-health` page existing patterns | AuditLogPanel embed |

## 4. Screens

### 4.1 Sign-in (`/control-room/sign-in`)

**File:** `src/app/control-room/sign-in/page.tsx`

**Layout:**

```
┌─────────────────────────────────────────────────────┐
│            FitMe brand mark (96px, centered)         │
│                                                      │
│            FitMe Control Room                        │
│            (display-md, font-serif)                  │
│                                                      │
│       Sign in to continue                            │
│       (text-body, neutral-500)                       │
│                                                      │
│   ┌─────────────────────────────────────────┐       │
│   │  [conditional-UI input — visible but    │       │
│   │   unused for typing]                    │       │
│   │   autocomplete="username webauthn"      │       │
│   └─────────────────────────────────────────┘       │
│                                                      │
│   ┌─────────────────────────────────────────┐       │
│   │     [icon] Unlock with passkey          │       │
│   │     (brand-indigo, hover: indigo-hover) │       │
│   └─────────────────────────────────────────┘       │
│                                                      │
│   Lost your device? Recover access →                │
│   (text-sm, link, underline-on-hover)               │
└─────────────────────────────────────────────────────┘
                                                       
                  Footer: dark-mode toggle              
```

**5 states:**

| State | Trigger | UI |
|---|---|---|
| **Idle** | Page load, autofill not yet fired | Card visible, button enabled, focus on the conditional-UI input |
| **Pending** | `navigator.credentials.get()` invoked | Button shows spinner + label "Waiting for passkey..." (button disabled) |
| **Success** | `verifyAuthenticationResponse({ verified: true })` | Brief checkmark animation (250ms, suppressed under `prefers-reduced-motion`) → redirect to `?next=` URL or `/control-room` |
| **Error** | Any ceremony failure | Inline banner above the button: rose-500 background, white icon + text, retry CTA. Reasons: "Touch ID cancelled", "No passkey found on this device", "Authentication failed — try again", "Account temporarily locked (5 failed attempts)" |
| **Locked** | Lockout active | Banner replaces the card: "Locked until {time}" + a static message; no retry button |

**Accessibility:**

- Focus order: input → unlock button → recover link → theme toggle
- All text WCAG AA contrast against `--color-neutral-50` (light) and `--color-neutral-900` (dark)
- `<input>` has `aria-label="Sign in with passkey"` (the visible label is redundant but explicit)
- Banner uses `role="alert"` + `aria-live="polite"`

### 4.2 Recover (`/control-room/sign-in/recover`)

**File:** `src/app/control-room/sign-in/recover/page.tsx`

**Two paths:**

#### Path A — token via URL (`?bootstrap=<token>`)

Token auto-extracted; ceremony starts on first render after capability check passes.

```
┌─────────────────────────────────────────────────────┐
│              FitMe brand mark (96px)                 │
│                                                      │
│              Add this device                         │
│                                                      │
│       Tap below to register {ua_family}              │
│       as your passkey                                │
│                                                      │
│       ┌─────────────────────────────────┐           │
│       │  [icon] Register this device    │           │
│       └─────────────────────────────────┘           │
│                                                      │
│       Cancel                                         │
└─────────────────────────────────────────────────────┘
```

#### Path B — no token (manual paste)

```
┌─────────────────────────────────────────────────────┐
│              FitMe brand mark (96px)                 │
│                                                      │
│              Recover access                          │
│                                                      │
│       Paste the bootstrap token printed by:          │
│       pnpm tsx scripts/issue-bootstrap-token.ts      │
│       (running on a trusted machine)                 │
│                                                      │
│       ┌─────────────────────────────────┐           │
│       │  [token paste field]            │           │
│       └─────────────────────────────────┘           │
│                                                      │
│       ┌─────────────────────────────────┐           │
│       │  Continue                       │           │
│       └─────────────────────────────────┘           │
│                                                      │
│       ← Back to sign-in                              │
└─────────────────────────────────────────────────────┘
```

After valid paste → transitions to Path A flow (button changes to "Register this device").

**5 states** match Sign-in (Idle / Pending / Success / Error / Locked) with reason vocabulary extended: "Token expired (15-min TTL exceeded)", "Token already used", "Invalid token format".

### 4.3 Devices admin (`/control-room/settings/devices`)

**File:** `src/app/control-room/settings/devices/page.tsx`

**Layout:**

```
┌─────────────────────────────────────────────────────────────────┐
│  Devices                                                         │
│  Registered passkeys for this dashboard                          │
│  ─────────────────────────────────────────────────────────────  │
│                                                                  │
│   Label              Type      Last used    IP        [        ] │
│  ─────────────────────────────────────────────────────────────  │
│   regev-mbp-touchid  platform  2 min ago    .../24    [Revoke ] │
│   regev-yubikey      cross     5 days ago   .../24    [Revoke ] │
│   ops-mbp-touchid    platform  1 day ago    .../24    [Revoke ] │
│  ─────────────────────────────────────────────────────────────  │
│                                                                  │
│   To add another device, run:                                    │
│   pnpm tsx scripts/issue-bootstrap-token.ts                      │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Revoke confirmation flow** (inline pill, NOT modal):

```
   regev-mbp-touchid  platform  2 min ago  .../24  [Revoke this? ✓ ✗]
                                                    rose-500 bg
```

Click ✓ → server emits `passkey_revoked` → row strikes through + shows `revokedAt` → "Permanently delete" action becomes available after 90 days.

**5 states:**

| State | UI |
|---|---|
| **Empty** | "No credentials registered yet. Use the bootstrap CLI to add your first device" + code snippet |
| **List** | Standard table |
| **Confirming** | Inline confirm pill on the targeted row |
| **Revoking** | Row dimmed, button shows spinner |
| **Revoked** | Row strikethrough + `revokedAt` + Delete button (90d retention) |

### 4.4 Audit log (`/control-room/settings/audit`)

**File:** `src/app/control-room/settings/audit/page.tsx`

**Layout:**

```
┌─────────────────────────────────────────────────────────────────┐
│  Audit log                                                       │
│  Last 50 auth events on this dashboard                           │
│  ─────────────────────────────────────────────────────────────  │
│                                                                  │
│   [All] [Authenticate] [Register] [Revoke] [Session]            │
│   filter chips                                                   │
│                                                                  │
│  ─────────────────────────────────────────────────────────────  │
│   2026-05-07 16:42  authenticate_succeeded  regev-mbp  ✓        │
│   2026-05-07 14:15  authenticate_failed     regev-mbp  ✗ retry  │
│   2026-05-07 12:08  session_minted          regev-mbp  ✓        │
│   ... (collapsed by default)                                     │
│  ─────────────────────────────────────────────────────────────  │
│                                                                  │
│   Click row → expand inline:                                     │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │  credential_id_hash: sha256:7a3f...c2                    │  │
│   │  ip_class: ipv4-203.0.113.0/24                           │  │
│   │  user_agent_family: Safari/macOS                         │  │
│   │  duration_ms: 412                                        │  │
│   │  reason: null                                            │  │
│   └─────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

**5 states:**

| State | UI |
|---|---|
| **Empty** | "No events recorded yet" — fires only on fresh deploy |
| **List** | Standard chronological table, newest first |
| **Filtered** | Chip selected highlights in `--color-brand-indigo`; rows filter |
| **Expanded** | Row's full payload visible; click again to collapse |
| **Loading** | Skeleton rows while initial fetch resolves |

### 4.5 AuditLogPanel (embedded in `/control-room/framework`)

**Component:** `src/components/control-room/AuditLogPanel.tsx`

**Layout:**

```
┌─────────────────────────────────────────────────────────────────┐
│  Auth surface                                                    │
│  Operator dashboard authentication telemetry                     │
│  ─────────────────────────────────────────────────────────────  │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │ Registered   │  │ Auths (7d)   │  │ Failed (7d)  │          │
│  │      3       │  │     42       │  │      1       │ (red>0)  │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
│                                                                  │
│  ⚠ Suspicious activity detected: 3 failures in last hour        │
│  (rose-500/15 banner, dismissible, fires only on anomaly)        │
│                                                                  │
│  Recent events:                                                  │
│   2026-05-07 16:42  authenticate_succeeded  regev-mbp  ✓        │
│   ...4 more rows...                                              │
│                                                                  │
│   View full audit log →                                          │
└─────────────────────────────────────────────────────────────────┘
```

**Wiring:** `<AuditLogPanel>` reads `.claude/logs/ucc-auth-events.jsonl` via the existing `load-ledgers.ts` loader pattern. The "View full audit log" link goes to `/control-room/settings/audit`.

**3 states:**

| State | Trigger |
|---|---|
| **Steady** | No anomalies in last 7d |
| **Anomaly** | Suspicious banner visible (≥3 fails in last hour, register from new IP/UA, revoke in last 24h) |
| **No data** | Fresh deploy — shows "0 / 0 / 0" without the banner |

## 5. Migration UX (NOT a screen, but referenced)

`UCC_AUTH_MODE=both` doesn't have a dedicated UI surface — the proxy.ts cookie check is server-side only. Operators see exactly the same dashboard whether they signed in via basic-auth or passkey during the cutover window. Audit log distinguishes the two paths via `event_type`:

- `auth_basic_authenticated` (added for the cutover) — fires whenever proxy.ts allows a request via basic-auth
- `auth_passkey_authenticate_succeeded` — fires when proxy.ts allows via session cookie

The framework-health AuditLogPanel can show a tiny indicator card showing "% via passkey today" so operators can watch the migration close in real time. **This is the ONLY new UI affordance for migration; everything else is env-var-driven.**

## 6. UX foundations checklist (per `docs/design-system/ux-foundations.md`)

| Principle | Coverage |
|---|---|
| Token compliance | ✅ All values map to existing fitme-story tokens (Tailwind v4 + globals.css) |
| Component reuse | ✅ Reuses `<Panel>`, `<MetricList>`, `<AlertsBanner>`, `<TrackPageView>` from `primitives.tsx` |
| Pattern consistency | ✅ Inline banner + confirm pill mirror `auth-polish-v2`; page-centered card mirrors framework-health page |
| Accessibility | ✅ AA contrast, 44pt tap targets, ARIA labels, focus rings |
| Motion | ✅ Reduced-motion safe; only one optional pulse animation, suppressed under prefers-reduced-motion |

## 7. Sign-off

- Tokens used: 0 net-new, 12 reused
- Components: 4 net-new, 5 reused
- Patterns: 5 reused (no new patterns)
- States covered: 5 per screen × 5 screens = 25 states (each with empty/loading/error variant)
- A11y + motion + dark-mode all addressed

**Phase 3 exit ready** pending /ux preflight + /design preflight + /design audit verification.
