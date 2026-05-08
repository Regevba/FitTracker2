# UX Build Prompt — `ucc-passkey-auth` — 2026-05-07

**Phase 3 sub-step 3h** · auto-generated handoff prompt for downstream UX/dev agents
**Companion prompt:** [`docs/prompts/ui/2026-05-07-ucc-passkey-auth-design-build.md`](../ui/2026-05-07-ucc-passkey-auth-design-build.md)

> Hand this prompt to a downstream agent (or a fresh Claude session) that will implement the **UX behaviour** of the 5 screens in the `ucc-passkey-auth` feature. The companion `/design` prompt covers the visual styling.

---

## Context

You are implementing the operator-facing screens for FitMe's Unified Control Center passkey-auth migration. The dashboard at `fitme-story.vercel.app/control-room/*` is moving from HTTP basic-auth to WebAuthn passkeys. You own the UX behaviour: ceremony orchestration, state machines, error UX, accessibility.

- **Surface:** fitme-story (Next.js 16, Tailwind v4, React 19, App Router, server components by default)
- **Library:** `@simplewebauthn/browser` v13 (client) + `@simplewebauthn/server` v13 (server, Node.js runtime only)
- **Auth state machine:** matches the iOS `auth-polish-v2` Block B pattern verbatim — capability detection → consent UX → ceremony → success | error inline banner
- **5 screens (full specs in the linked ux-spec.md):**

| Screen | Path | Component file (new) |
|---|---|---|
| Sign-in | `/control-room/sign-in` | `src/app/control-room/sign-in/page.tsx` |
| Recover | `/control-room/sign-in/recover` | `src/app/control-room/sign-in/recover/page.tsx` |
| Devices admin | `/control-room/settings/devices` | `src/app/control-room/settings/devices/page.tsx` |
| Audit log | `/control-room/settings/audit` | `src/app/control-room/settings/audit/page.tsx` |
| AuditLogPanel | embed in `/control-room/framework` | `src/components/control-room/AuditLogPanel.tsx` |

## Required reading (in order)

1. [`ux-research.md`](../../.claude/features/ucc-passkey-auth/ux-research.md) — UX principles + iOS HIG references + decisions log
2. [`ux-spec.md`](../../.claude/features/ucc-passkey-auth/ux-spec.md) — canonical screen contract: tokens, components, states, accessibility
3. [`prd.md`](../../.claude/features/ucc-passkey-auth/prd.md) §5 (user stories), §8 (analytics events), §10 (architecture)
4. [`research.md`](../../.claude/features/ucc-passkey-auth/research.md) §1-§5 (library + storage + session decisions)
5. **iOS reference for the activation cadence:** `FitTracker/Views/Auth/BiometricActivationSheet.swift` (port the structure: brand icon, single CTA, "Not now" secondary, inline banner)

## What to build

### 1. `<AuthPasskeyForm>` (T13 — heavyweight, build first)

A reusable client component that orchestrates the WebAuthn ceremony. Two modes:

```tsx
<AuthPasskeyForm mode="authenticate" onSuccess={() => router.push(next)} />
<AuthPasskeyForm mode="register" bootstrapToken={token} onSuccess={() => router.push('/control-room/sign-in')} />
```

State machine (5 states, matches ux-spec §4.1):
- `idle` → user presses "Unlock" → POST `/api/auth/{authenticate|register}/options` → call `navigator.credentials.{get|create}` → POST `/.../verify` → success | error
- `pending` → button disabled with spinner + "Waiting for passkey..."
- `success` → 250 ms checkmark animation (suppressed under reduce-motion) → call `onSuccess`
- `error` → inline `<div role="alert">` banner above the button + retry CTA. Error message must come from a fixed vocabulary (matches PRD §6 K1/K2/K3 reasons).
- `locked` → banner replaces card; no retry; show unlock-time

Capability detection on mount: `await PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable()` — if false, render only the YubiKey/cross-platform path (button label switches to "Use a security key").

Conditional-UI autofill when `mode="authenticate"`:
- Render the input with `autocomplete="username webauthn"`
- On mount call `navigator.credentials.get({ mediation: 'conditional', publicKey })` — if it resolves the page transitions straight to `success` without requiring a button press

Analytics: every state transition emits a `auth_passkey_*` event per PRD §8. Use the existing `<TrackPageView>` pattern + a new `useAuthAnalytics()` hook (see companion T25 test fixtures for the mock contract).

### 2. Sign-in page (T14)

Server component shell at `src/app/control-room/sign-in/page.tsx`:

- Read the `?next=` query param (default `/control-room`)
- Render `<TrackPageView screen="auth_passkey_signin" />`
- Center an `<AuthPasskeyForm mode="authenticate" />` inside a `<Panel eyebrow="Operator dashboard" title="Sign in to continue" />` (use the existing primitive)
- Below the panel: `<TrackedDocLink href="/control-room/sign-in/recover">Lost your device? Recover access →</TrackedDocLink>`

Use `<Suspense>` for the form (its hooks need client-side mounting).

### 3. Recover page (T15)

Two paths, same state machine:

- Path A — `?bootstrap=<token>` query param present: extract, render `<AuthPasskeyForm mode="register" bootstrapToken={token} />`
- Path B — no token: render a `<form>` with a token-paste field; on submit, redirect to the same URL with the token in the query param

Reuse the same `<Panel>` chrome as Sign-in. Brand cadence is identical.

### 4. Devices admin (T16)

Server component reads the operator's credentials from `/api/auth/devices` (GET; new in this feature) and passes to client `<DevicesTable>`:

```tsx
<DevicesTable
  credentials={creds}
  onRevoke={(credentialId) => POST('/api/auth/revoke', { credentialId })}
/>
```

Inline confirm pill on Revoke (matches ux-spec §4.3 — NOT a modal). After Revoke, optimistically update the row to `revokedAt: now`; the server response confirms.

### 5. Audit log page (T17)

Server component reads `.local/ucc-auth-events.jsonl` via the existing `load-ledgers.ts` loader pattern. Renders `<AuditEventRow>` × 50 with filter chips. `<AuditEventRow>` is a client component (handles inline expansion).

### 6. AuditLogPanel (T18, T19)

Client component embedded in `src/app/control-room/framework/page.tsx`. Reads the same JSONL via the loader. 3-stat row uses existing `<MetricList>` from `primitives.tsx`. Suspicious banner uses existing `<AlertsBanner>` (only renders when anomaly conditions trigger, see ux-spec §4.5).

## Required behaviour for ALL screens

- **Dark mode:** every component must render correctly in both light and dark (the existing `globals.css` overrides `--color-neutral-500` and `--color-brand-indigo` for AA contrast on dark background — no new tokens needed)
- **Reduced motion:** no opt-in animation that bypasses `prefers-reduced-motion: reduce`; the only animation is the 250 ms success checkmark and it's already suppressed via the global rule
- **Focus management:** every interactive element has a visible focus ring (`focus-visible:ring-2 focus-visible:ring-brand-indigo focus-visible:ring-offset-2`)
- **Keyboard:** Tab order matches the visual order; `Enter` on the unlock input triggers the ceremony; `Esc` cancels in-flight ceremonies via `AbortController`
- **Localization:** v1 ships in English only. All strings live in a single `messages.ts` constant per page so future i18n is a localized swap

## Out of scope for this prompt

- Server routes (those are `/design` + dev's responsibility, not UX)
- Redis schema (research.md §4 owns it)
- iron-session cookie sealing (research.md §5 owns it)
- Audit-log JSONL writer (research.md §9 owns it)
- Cross-repo sync GHA workflow (T22)

## Acceptance criteria (Phase 5 will gate against these)

- [ ] All 5 screens render correctly on first load (idle state)
- [ ] All 5 states render correctly per screen × 5 screens = 25 states verified
- [ ] Conditional-UI autofill fires on Sign-in within 800 ms of page load (or never; either is correct)
- [ ] All ceremonies complete in < 2.5 s p50 (PRD §6 secondary metric)
- [ ] All analytics events fire with the right parameters (PRD §8 event spec)
- [ ] All a11y checks pass (axe-core or equivalent)
- [ ] Lighthouse score on Sign-in page ≥ 95 in all 4 categories
- [ ] Tests in T24 + T25 + T26 all pass

## Risks called out for downstream agent

- Browser autofill behaviour varies between Safari and Chrome — test on both
- iCloud Keychain syncing can lag → registration on iPhone but not visible on Mac for a few minutes; this is a platform issue, not a bug
- Hardware keys (YubiKey) require a different `transports` array; the spec covers it but ensure the ceremony options include `transports: ['internal', 'usb', 'nfc']`

---

**Stop and request user approval before** writing any view code if any of the above sections are ambiguous. The PM workflow's Phase 3 → Phase 4 transition is the explicit gate.
