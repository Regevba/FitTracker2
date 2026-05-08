# Phase 0 Research — `ucc-passkey-auth`

**Feature slug:** `ucc-passkey-auth`
**Work type:** Feature (cross-repo)
**Framework version:** v7.8.1
**Predecessor chain:** `unified-control-center` → `auth-polish-v2`
**Source backlog entry:** [`docs/product/backlog.md:162`](../../../docs/product/backlog.md) (UCC T2.5 deferral)
**Trigger:** UCC migration shipped 2026-05-06 with basic-auth as the operator gate; T2.5 (passkey replacement) was explicitly deferred. Backlog item carries the full scope statement.
**Date:** 2026-05-07

---

## 1. Problem framing

The Unified Control Center (UCC) at [`fitme-story.vercel.app/control-room/*`](https://fitme-story.vercel.app/control-room/) is currently gated by HTTP basic-auth in [`fitme-story/src/proxy.ts:30-78`](../../../../fitme-story/src/proxy.ts). One shared `DASHBOARD_USER` + `DASHBOARD_PASS` env-var pair for every operator. No per-operator identity, no audit trail of who signed in when, no way to revoke a single device without rotating the whole credential.

The asymmetry is the core problem: the **iOS app** (`auth-polish-v2`, FT2 PR #163, shipped 2026-05-01) ships passkeys for end users, yet the **operator surface** that has access to every framework readout, ship event, and case study is gated by a phishable shared password. The operator gate is the weaker link below the user gate — exactly inverted from how a security posture should be shaped.

Replacing basic-auth with WebAuthn passkeys gives:

- **Per-operator identity** — every event in the audit log is attributable.
- **Per-device credentials** — losing one device revokes one credential, not the whole gate.
- **Phishing resistance by default** — WebAuthn binds assertions to RP-ID (`fitme-story.vercel.app`); a phished prompt at a look-alike domain refuses to sign.
- **No password to rotate** — the credential is hardware-backed (Touch ID / Face ID / Windows Hello / TPM / YubiKey).

## 2. WebAuthn ceremony fundamentals (working notes)

**Two ceremonies:**

- **Registration (`navigator.credentials.create`)** — server issues a challenge + RP info; authenticator generates a keypair + signs an attestation; server verifies attestation, stores `credentialID + COSE public key + signCounter + transports + AAGUID`.
- **Authentication (`navigator.credentials.get`)** — server issues a challenge + (optional) `allowCredentials` list; authenticator signs the challenge with the private key; server verifies signature against stored public key + checks the new sign-counter is strictly greater than the stored one (replay defense).

**Resident keys (a.k.a. discoverable credentials):** when supported (iOS 16+, macOS 13+, Win 11, Chrome on Android 14+), the authenticator stores the credential metadata locally so the user doesn't need to type a username — the sign-in page shows a single "Unlock with passkey" button. With 1–3 operators, this is the right default (`residentKey: 'preferred'` → fallback for older platforms).

**RP ID = `fitme-story.vercel.app`.** Custom-domain pinning blocks cross-origin attacks. Preview deploys at `*-fitme-story.vercel.app` cannot reuse the same passkeys (RP-ID mismatch is a feature) — previews must run with `UCC_AUTH_MODE=basic`.

## 3. Library landscape — recommended: `@simplewebauthn/{server,browser}` v13

| Option | Maint. signal | Coverage | Bundle (browser) | Runtime | License | Verdict |
|---|---|---|---|---|---|---|
| **`@simplewebauthn/server` v13.3.0** + `@simplewebauthn/browser` | ~803 K weekly DLs · last release ~30 d ago · active CHANGELOG ([npm](https://www.npmjs.com/package/@simplewebauthn/server)) | Registration, assertion, signature-counter replay check, attestation, revoke-by-credentialID, registration hints (v13) ([SimpleWebAuthn docs](https://simplewebauthn.dev/docs/packages/server)) | ~7 KB min+gz | **Node.js only** (server pkg uses `node:crypto` — must NOT use Edge runtime) | MIT | **Pick.** |
| `@github/webauthn-json` | Maintained, lower velocity | **Client-side only** — base64url ⇄ ArrayBuffer wrapper. No server verification. ~1 KB min+gz ([npm](https://www.npmjs.com/package/@github/webauthn-json)) | ~1 KB | Any | MIT | Doesn't solve the server problem. |
| Clerk / Descope (full provider) | Production-grade | Full IdP + UI, but pulls in user mgmt, billing, org features the dashboard doesn't need ([Clerk passkeys](https://clerk.com/blog/how-do-i-implement-passkeys-in-nextjs)) | 50–150 KB | Node + Edge | Proprietary | Overkill for 3 operators on one route prefix. |

**Pick: `@simplewebauthn/{server,browser}` v13.** Maturity, license, exact-feature scope, no vendor lock-in, mirrors what the iOS `auth-polish-v2` Block B already validates. Webauthn-json is a complementary client transport at best — it solves none of the server problem. Clerk/Descope re-introduce a third-party identity surface we just moved away from on iOS.

**Runtime constraint:** put `/api/auth/*` route handlers under `export const runtime = 'nodejs'`. `proxy.ts` itself only reads a signed cookie, so it stays on Node.js (Next 16 default) ([Next.js 16 — `proxy.js` file convention](https://nextjs.org/docs/app/api-reference/file-conventions/proxy)).

## 4. Credential storage — Upstash Redis via Vercel Marketplace

Already provisioned for `fitme-story`; HTTP REST means it works from Node + Edge. Read latency ~10–20 ms p50 on Vercel Functions ([Upstash benchmark](https://edge-benchmark.vercel.app/)). **Edge Config is read-optimized** — wrong fit for a write-heavy registration path. **Postgres is overkill** for ≤30 rows.

**Schema (Redis key/value):**

| Key | Value | TTL |
|---|---|---|
| `ucc:operator:<email>` | `{ id, email, label, role, createdAt }` | none |
| `ucc:credential:<credentialID>` | `{ ownerEmail, publicKey (COSE base64url), counter, deviceType, transports[], aaguid, label, createdAt, lastUsedAt, revokedAt|null }` | none |
| `ucc:operator:<email>:credentials` | `Set<credentialID>` (reverse index for listing/revoke) | none |
| `ucc:challenge:<email>` | `{ challenge, expiresAt }` (registration + assertion ceremonies) | 60 s |
| `ucc:bootstrap:<sha256(token)>` | `{ email, expiresAt, used: bool }` | 15 min |
| `ucc:session:<sid>` | `{ email, mintedAt, expiresAt, lastSeenAt }` (allowlist for instant revoke) | 24 h |

**Counter MUST be CAS-updated** after every successful assertion. SimpleWebAuthn's `verifyAuthenticationResponse` returns `authenticationInfo.newCounter`; reject if `newCounter <= stored.counter` (replay).

## 5. Session strategy — `iron-session` signed cookie

Mint after `verifyAuthenticationResponse({ verified: true })`:

- `HttpOnly` + `Secure` + `SameSite=Strict`
- `Path=/control-room`
- 24 h hard cap, sliding-refresh if cookie age > 12 h on each authenticated request
- 32-byte secret in `UCC_SESSION_SECRET`
- Sealed via `iron-session` AES-GCM ([next-iron-session](https://github.com/Volubyl/next-iron-session))
- Cookie payload: `{ email, sid (random), iat, exp }`

`proxy.ts` flow per `/control-room/*` request:

1. Read `UCC_AUTH_MODE` ∈ {`basic`, `passkey`, `both`}.
2. `basic` → existing path, untouched.
3. `passkey` → unseal cookie → verify `sid` exists in `ucc:session:<sid>` (server-side allowlist enables instant revoke) → allow.
4. `both` → accept either; log which path was used in `ucc-auth-events.jsonl`.
5. On miss → 302 to `/control-room/sign-in?next=<path>`. **Not a 401 challenge** — closes the basic-auth dialog UX.

`UCC_AUTH_MODE=both` is the migration safety-valve: register every authorized device while both paths work; flip to `passkey` once registration coverage is confirmed; drop `basic` and the env vars.

**JWT vs `iron-session`:** `iron-session` wins because we need server-side revocation (lost device) and we already have Redis. **OAuth-style is the wrong shape** — there's no third-party IdP.

## 6. Bootstrap-token registration UX — pick (a), CLI-issued, paste into sign-in

**Recommendation:** operator runs `pnpm dlx tsx scripts/issue-bootstrap-token.ts <email>` locally (gated by `vercel env pull` of an admin secret). Script writes `ucc:bootstrap:<sha256(token)>` to Redis (15-min TTL, single-use) and prints the raw token. Operator pastes it into `/control-room/sign-in` "Add device" field; server verifies + marks `used=true` + starts WebAuthn `generateRegistrationOptions`.

| Option | Reject reason |
|---|---|
| (a) **CLI script + paste** | **Pick.** No URL leakage, server-validated, single-use, 15-min TTL. |
| (b) Magic-link URL with embedded token | Token leaks to browser history, referer headers, Vercel access logs. |
| (c) Vercel-CLI-issued env-var token | Env vars are global, not per-operator; rotating requires redeploy. |

**Token spec:** 32 bytes (256 bits) from `crypto.randomBytes`, base64url-encoded, TTL 15 min, single-use. Stored as SHA-256 hash so the raw token never sits in Redis at rest. Same flow re-used for "add another device" (operator already authenticated requests a fresh bootstrap from their Devices admin screen).

## 7. Threat model

| Threat | Mitigation |
|---|---|
| **Phishing** | WebAuthn binds assertion to RP ID (`fitme-story.vercel.app`); browser refuses to sign for a different origin. Native phishing-resistance ([W3C WebAuthn L3](https://www.w3.org/TR/webauthn-3/)). |
| **Replay** | Per-ceremony challenge in `ucc:challenge:*` (60 s TTL, single-use) + signature-counter monotonic check via `verifyAuthenticationResponse`. |
| **Session theft** | HttpOnly + Secure + SameSite=Strict; server-side `ucc:session:<sid>` allowlist enables instant revoke; 24 h hard cap. |
| **RP-ID spoofing** | RP ID locked to `fitme-story.vercel.app`; preview deploys can't reuse passkeys (RP-ID mismatch). |
| **Credential stuffing** | No passwords exist. N/A. |
| **Lost device** | Operator-2 revokes Operator-1's `credentialID` via Devices admin (sets `revokedAt`); `verifyAuthenticationResponse` lookup excludes revoked. Recovery path = bootstrap-token issued from another operator. |
| **Hardware-key fallback (break-glass)** | YubiKey 5/Bio works out-of-box — `authenticatorAttachment: undefined` allows both platform + cross-platform; register at least one as a "break-glass" credential per operator. |

## 8. Cross-platform passkey UX

| Platform | Status (2026-03 measurements) | Notes |
|---|---|---|
| **Apple** (iOS 17+, macOS 14+) | Touch ID / Face ID, end-to-end-encrypted iCloud Keychain sync — passkey on iPhone is usable on Mac Safari + Mac Chrome. 100% sync rate iOS, 99% macOS ([state-of-passkeys 2026](https://state-of-passkeys.io/macos)). Safari supports resident keys. |
| **Google** (Android + Chrome) | Google Password Manager syncs across the user's Google account; Chrome on Windows/Linux can use Android phone via QR + BLE hybrid transport. |
| **Microsoft** (Windows 11) | Windows Hello (PIN/fingerprint/face) via TPM. Edge + Chrome both work. |
| **Hardware keys** | YubiKey 5 / Bio over USB-C or NFC. Allow `transports: ['usb', 'nfc']` in registration options. |

**Gotchas:**

- Preview deploys at `*-fitme-story.vercel.app` cannot use production passkeys (different RP ID) → previews stay on `UCC_AUTH_MODE=basic`.
- Safari < 16 lacks conditional UI but operators are on current macOS — non-issue.
- iCloud Keychain disabled accounts cannot create syncing passkeys → must register a YubiKey as fallback.

## 9. Audit-log shape — `.claude/logs/ucc-auth-events.jsonl`

Append-only JSONL, one event per line. **Common fields on every event:**

```json
{
  "timestamp": "2026-05-07T16:42:01.000Z",
  "event_type": "passkey_authenticate_succeeded",
  "schema_version": 1,
  "credential_id_hash": "sha256:7a3f...c2",
  "operator_label": "regev-mbp-touchid",
  "ip": "203.0.113.0/24",
  "user_agent_family": "Safari/macOS",
  "outcome": "success",
  "reason": null,
  "session_id_hash": "sha256:1b8e...a4",
  "rp_id": "fitme-story.vercel.app",
  "duration_ms": 412
}
```

**9 event types:** `passkey_register_started/_completed/_failed`, `passkey_authenticate_started/_succeeded/_failed`, `passkey_revoked`, `session_minted`, `session_expired`.

**Per-event-type extras:**

- `_failed` events MUST set `reason` ∈ {`user_cancelled`, `no_authenticator`, `assertion_invalid`, `counter_replay`, `unknown_credential`, `timeout`, `server_error`}.
- `passkey_revoked` adds `revoked_by_credential_id_hash`.
- `session_minted` / `session_expired` add `session_ttl_seconds`.

**Privacy:** never log raw `credential_id` (use SHA-256 hash for cross-event correlation without enabling tracking). Truncate IPv4 to /24, IPv6 to /48. Strip user-agent down to a family string.

## 10. Cross-repo audit-log sync

**Recommend Option A — Reverse-mode sync.**

Extend [`fitme-story/scripts/sync-from-fittracker2.ts`](../../../../fitme-story/scripts/sync-from-fittracker2.ts) with a sibling `scripts/sync-to-fittracker2.ts` (or a `--reverse` flag — same module gated by env). Reverse mode runs as a **post-write hook** on the WebAuthn API routes (not pre-build): every successful append to `ucc-auth-events.jsonl` POSTs to a Vercel Function that writes the line into a Vercel Blob; a daily GitHub Action in FT2 pulls the Blob into [`FitTracker2/.claude/logs/ucc-auth-events.jsonl`](../../../.claude/logs/) and commits.

Why reverse rather than write-through HTTPS into FT2:

- Option B (live writes) requires FT2 to expose an authenticated write endpoint and ties auth liveness to FT2's deploy state. Hard nope.
- Option A keeps fitme-story self-contained, reuses the JSONL primitive the framework already understands (Tier 2.2 contemporaneous logs), degrades gracefully — if sync stalls the live log in Blob is still authoritative.

**Fallback if pre-build sync can't run mid-deploy:** local file at `fitme-story/.local/ucc-auth-events.jsonl` is the live source; daily action is best-effort. Framework-health page shows `last_synced_at` so the operator can spot drift.

## 11. Lessons from `auth-polish-v2`

Four patterns to lift directly from FT2:

| # | Pattern | Source path | Web port |
|---|---|---|---|
| (a) | Capability detection — "is biometric available" gate | [`FitTracker/Services/AuthManager.swift:103-110`](../../../FitTracker/Services/AuthManager.swift) (`var biometricType: LABiometryType?`) wraps `LAContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics)`, exposes a typed enum the UI binds against. | `await PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable()` — same shape (returns capability, never throws), same place in the flow. Gates whether the "Register this device" CTA renders. |
| (b) | Consent + permission UX — sheet-style activation | [`FitTracker/Views/Auth/BiometricActivationSheet.swift`](../../../FitTracker/Views/Auth/BiometricActivationSheet.swift) — medium detent, single primary CTA ("Enable Face ID"), "Not now" secondary, brand icon, single-sentence reassurance. | Port verbatim to the bootstrap screen — same tone, same hierarchy. The brand icon is the same. |
| (c) | Error states — inline banner, not alert | [`FitTracker/Views/Auth/BiometricActivationSheet.swift:55-63`](../../../FitTracker/Views/Auth/BiometricActivationSheet.swift) renders an inline `AuthBannerView` for failures rather than alerts. | Mirror for the three WebAuthn states: no platform authenticator (`isUserVerifyingPlatformAuthenticatorAvailable() === false`), authenticator unavailable mid-ceremony (`NotAllowedError`), user cancelled (`AbortError`). One inline banner, one retry CTA. |
| (d) | Test-fixture pattern for analytics events | [`FitTracker/Services/Analytics/AnalyticsService.swift:920-954`](../../../FitTracker/Services/Analytics/AnalyticsService.swift) — five typed `logAuthBiometric*` methods; tests in [`FitTrackerTests/AuthPolishV2Tests.swift`](../../../FitTrackerTests/AuthPolishV2Tests.swift) assert on `MockAnalyticsService` capturing event names + params. | `MockAuditLogger` writes JSONL into a tmpfile in tests; assertions read the file and check `event_type` + key params. **Do not reinvent** — directly mirror the iOS contract. |

## 12. Surface in framework-health (`/control-room/framework`)

Add a single new section to [`fitme-story/src/app/control-room/framework/page.tsx`](../../../../fitme-story/src/app/control-room/framework/page.tsx): **`AuditLogPanel`**, sourced from FT2-synced `.claude/logs/ucc-auth-events.jsonl` via the existing loader pattern at [`fitme-story/src/lib/framework-health/load-ledgers.ts`](../../../../fitme-story/src/lib/framework-health/load-ledgers.ts).

Component sketch (3 small parts in one card, no SOC-console maximalism):

1. **Stat row** — `<StatRow>` × 3:
   - registered credentials count
   - authentications (last 7 d)
   - failed attempts (last 7 d, red if > 0)
2. **Recent events table** — last 5 events, columns: timestamp · event_type · operator_label · outcome. Outcome cell uses success/error pill from the existing token set.
3. **Suspicious-event highlight** — banner appears if any of:
   - ≥ 3 `passkey_authenticate_failed` in the last hour
   - `passkey_register_completed` from an IP/UA family not seen in the prior 30 days
   - `passkey_revoked` event in the last 24 h

   One banner, dismissible on the page (state local — log stays).

## 13. Open questions for PRD

1. **Multi-operator policy** — first-operator self-bootstraps via env-var-gated CLI script. Do subsequent operators (#2, #3) require an existing operator to issue their bootstrap token, OR is the CLI script always allowed? **Default proposal:** existing-operator-required after the first device is registered.
2. **Lockout** — after N consecutive failed assertions on the same `email`, lock for M minutes? **Default proposal:** N=5, M=15. Surfaced in `ucc-auth-events.jsonl`. Confirm.
3. **Session lifetime** — 24 h hard + sliding 12 h refresh, OR shorter (4 h) for an ops dashboard with sensitive data? **Default proposal:** 24 h + 12 h sliding (matches the iOS pattern). Confirm.
4. **Mobile dashboard access** — do we need the dashboard usable on iOS Safari (control-room responsive)? **Default proposal:** out of scope; operator surface is desktop-first. Confirm.
5. **Audit logging granularity** — log every auth event (success + failure + revoke + bootstrap-token issuance) to `.claude/logs/ucc-auth-events.jsonl`, or only failures + admin actions? **Default proposal:** every event (we already accept Tier 2.2 cost). Confirm.
6. **Vercel Blob vs daily-GHA-pull cadence** — daily ok, or hourly for tighter audit-trail freshness? **Default proposal:** daily, with `last_synced_at` shown in framework-health for drift visibility. Confirm.
7. **Conditional UI / autofill** — do we want resident-key sign-in via the conditional-UI autofill prompt (`mediation: 'conditional'`)? **Default proposal:** yes — single-tap sign-in is the whole point. Confirm.

## 14. Recommended approach (decision)

**Stack:**

- **Library:** `@simplewebauthn/server` v13 + `@simplewebauthn/browser` v13. Node.js runtime for the API routes. MIT license.
- **Storage:** Upstash Redis via Vercel Marketplace (already provisioned). 6 key shapes per §4.
- **Sessions:** `iron-session` signed cookie (`HttpOnly` + `Secure` + `SameSite=Strict` + `Path=/control-room`), 24 h hard / 12 h sliding, server-side `ucc:session:<sid>` allowlist for instant revoke.
- **Bootstrap:** CLI-issued one-time token (32 bytes, 15-min TTL, single-use, SHA-256 hash at rest); pasted into `/control-room/sign-in` "Add device" field.
- **Migration:** `UCC_AUTH_MODE` env var ∈ {`basic`, `passkey`, `both`}; ship in `both`; flip to `passkey` once all operators are registered.
- **Cross-repo audit:** post-write to Vercel Blob from fitme-story API routes; daily GHA in FT2 pulls into `.claude/logs/ucc-auth-events.jsonl` and commits.
- **Surface:** 5 screens (bootstrap, sign-in, recovery, devices admin, audit log) in fitme-story + 1 framework-health panel in FT2 sync.
- **Patterns reused from `auth-polish-v2`:** capability detection, consent sheet, error-banner UX, mock-fixture analytics test pattern.

**Why this beats the alternatives:**

- Phishing-resistant by construction (RP-ID binding) — closes the strongest attack class against an ops dashboard.
- Reuses every primitive we already have (Vercel Marketplace KV, iron-session ecosystem, Tier 2.2 logging, framework-health loader pattern, auth-polish-v2 UX library).
- Zero third-party identity provider — operator data stays in our own KV.
- `UCC_AUTH_MODE=both` migration path is reversible at every step. Kill-criterion compatible.
- Single-operator-friendly today (1–3 people) but scales linearly to ~30 operators without re-architecture.

**Effort estimate:** 1.5 person-weeks (5 screens + 4 API routes + KV plumbing + cross-repo sync + tests + docs). Cross-repo so two PRs (one per repo).

---

## Sources

- [@simplewebauthn/server — npm](https://www.npmjs.com/package/@simplewebauthn/server)
- [SimpleWebAuthn docs — server package](https://simplewebauthn.dev/docs/packages/server)
- [SimpleWebAuthn CHANGELOG](https://github.com/MasterKale/SimpleWebAuthn/blob/master/CHANGELOG.md)
- [@github/webauthn-json — npm](https://www.npmjs.com/package/@github/webauthn-json)
- [Clerk: passkeys in Next.js](https://clerk.com/blog/how-do-i-implement-passkeys-in-nextjs)
- [Auth.js WebAuthn / Passkey](https://authjs.dev/getting-started/authentication/webauthn)
- [Next.js 16 — `proxy.js` file convention](https://nextjs.org/docs/app/api-reference/file-conventions/proxy)
- [Next.js 16 — Authentication guide](https://nextjs.org/docs/app/guides/authentication)
- [Vercel Marketplace — Upstash Redis](https://vercel.com/marketplace/upstash)
- [Upstash global edge benchmark](https://edge-benchmark.vercel.app/)
- [Upstash Redis on Vercel — Marketplace integration docs](https://upstash.com/docs/redis/howto/vercelintegration)
- [iron-session for Next.js](https://github.com/Volubyl/next-iron-session)
- [Apple — passkey security & iCloud Keychain sync](https://support.apple.com/en-us/102195)
- [Apple developer — passkeys overview](https://developer.apple.com/passkeys/)
- [State of Passkeys — iOS 2026](https://state-of-passkeys.io/ios)
- [State of Passkeys — macOS 2026](https://state-of-passkeys.io/macos)
- [Chrome supports passkeys via iCloud Keychain on macOS](https://developer.chrome.com/blog/passkeys-on-icloud-keychain)
- [W3C WebAuthn Level 3](https://www.w3.org/TR/webauthn-3/)

**Internal references:**

- [`docs/product/backlog.md:162`](../../../docs/product/backlog.md) — backlog scope
- [`fitme-story/src/proxy.ts`](../../../../fitme-story/src/proxy.ts) — current basic-auth gate to replace
- [`fitme-story/scripts/sync-from-fittracker2.ts`](../../../../fitme-story/scripts/sync-from-fittracker2.ts) — sync skeleton to extend with reverse mode
- [`fitme-story/src/lib/framework-health/load-ledgers.ts`](../../../../fitme-story/src/lib/framework-health/load-ledgers.ts) — loader pattern for `AuditLogPanel`
- [`FitTracker/Views/Auth/BiometricActivationSheet.swift`](../../../FitTracker/Views/Auth/BiometricActivationSheet.swift) — UX cadence reference
- [`FitTracker/Services/AuthManager.swift:99-141`](../../../FitTracker/Services/AuthManager.swift) — capability + label helpers
- [`FitTracker/Services/Analytics/AnalyticsService.swift:920-954`](../../../FitTracker/Services/Analytics/AnalyticsService.swift) — event signature contract
- [`FitTrackerTests/AuthPolishV2Tests.swift`](../../../FitTrackerTests/AuthPolishV2Tests.swift) — mock-fixture test pattern
