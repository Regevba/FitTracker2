# PRD — `ucc-passkey-auth`

**Feature slug:** `ucc-passkey-auth`
**Work type:** Feature (cross-repo: fitme-story + FitTracker2)
**Framework version:** v7.8.1
**Parent feature:** [`unified-control-center`](../unified-control-center/) (T2.5 deferral)
**Predecessor chain:** `unified-control-center` → `auth-polish-v2` → `ucc-passkey-auth`
**Research:** [`research.md`](./research.md) (approved 2026-05-07T16:38Z)
**Source backlog entry:** [`docs/product/backlog.md:162`](../../../docs/product/backlog.md)
**Author:** Regev (with Claude Opus 4.7)
**Date:** 2026-05-07
**Status:** Draft — pending Phase 1 approval

---

## 1. What we're building

Replace HTTP basic-auth on the operator dashboard at [`fitme-story.vercel.app/control-room/*`](https://fitme-story.vercel.app/control-room/) with WebAuthn passkeys. Per-operator identity, per-device credentials, server-side session allowlist, append-only audit log synced into the FT2 framework-health page.

**Why now:** the iOS app already ships passkeys for end users (`auth-polish-v2`, PR #163). The operator gate — which sees every framework readout and ship event — is currently a shared, phishable, unrotatable basic-auth credential. The asymmetry is inverted: the operator surface is weaker than the user surface. This feature corrects that.

**Scale:** 1–3 operators today, scales linearly to ~30. Single-operator-friendly UX (no admin team, no role hierarchy, no email-reset flow).

## 2. Goals

| # | Goal | Why it matters |
|---|---|---|
| G1 | Replace shared basic-auth with per-operator passkeys on `/control-room/*` | Phishing-resistant, unique per-operator, revocable per-device |
| G2 | Ship append-only audit log of every auth event | Operator-attribution + suspicious-activity surfacing |
| G3 | Cross-repo sync into FT2 framework-health page | Single pane of glass for who's signing in to the dashboard |
| G4 | Migration via `UCC_AUTH_MODE` env var (`basic` / `passkey` / `both`) | Zero-downtime cutover; reversible at every step |
| G5 | Reuse `auth-polish-v2` UX patterns where applicable | Single auth UX vocabulary across FitMe (iOS + dashboard) |

## 3. Non-goals (v1)

- Multi-tenant identity provider (Clerk/Descope/Auth0).
- Email-reset / password-recovery flows. Recovery is via a fresh bootstrap token from another operator's CLI.
- Mobile-responsive `/control-room/*` UI on iOS Safari (desktop-first per Q4 default).
- SSO with Google Workspace / Apple ID (operator dashboard is not an end-user surface).
- Audit-log alerting / paging via PagerDuty (the framework-health "suspicious activity" banner is the only escalation channel for v1).
- Automatic rotation of bootstrap-token issuance scripts (manual env-var check is the gate).

## 4. User personas

**Operator (sole persona, 1–3 instances).** Has admin access to Vercel project + FT2 repo. Signs in to `/control-room/*` daily for ship triage, integrity-check readouts, ledger reviews. Currently types one shared password. Wants their device's biometric to unlock the dashboard, wants visibility into who else has registered, wants a revoke button when a device gets lost or replaced.

## 5. User stories

| # | Story | Acceptance |
|---|---|---|
| US-1 | As an operator, I want to register my device's passkey on first sign-in so I can use Touch ID/Face ID/Windows Hello to unlock the dashboard | Operator runs `pnpm dlx tsx scripts/issue-bootstrap-token.ts <email>` locally → pastes the printed token into `/control-room/sign-in` → device prompts for platform authenticator → success → redirected to `/control-room` |
| US-2 | As an operator, I want one-tap sign-in on subsequent visits so I never type a password | Visit `/control-room/*` without session cookie → redirect to `/control-room/sign-in` → conditional-UI autofill prompt fires automatically → biometric → redirect back to original URL |
| US-3 | As an operator, I want to see who has registered devices and revoke a stolen one | `/control-room/settings/devices` lists every active credential with `label`, `lastUsedAt`, `ip_class`. Revoke button writes `revokedAt` to the credential record + emits `passkey_revoked` event |
| US-4 | As an operator, I want to recover access on a new device when my old device is gone | Other operator runs the bootstrap-token CLI for the affected operator → pastes the new token into `/control-room/sign-in/recover` → re-runs registration ceremony on the new device |
| US-5 | As an operator, I want to see suspicious auth activity at a glance | Framework-health page (`/control-room/framework`) shows `AuditLogPanel` with last 7d stats, last 5 events, and a banner for anomalies (≥3 fails in last hour, register from new IP/UA, revoke in last 24h) |
| US-6 | As an operator, I want the migration to be reversible | `UCC_AUTH_MODE=both` accepts both auth methods during cutover; flipping back to `basic` is one env-var change |

## 6. Success metrics

### Primary

| Metric | Tier | Baseline | Target | Measurement |
|---|---|---|---|---|
| **Unauthenticated `/control-room/*` reads in production logs** | T1 (Instrumented) | TBD post-deploy (current basic-auth blocks all unauth requests at the proxy) | **0 per day** in `passkey` mode after cutover | Vercel access logs filtered by 401/302-to-sign-in counts |

### Secondary

| Metric | Tier | Target | Measurement |
|---|---|---|---|
| `time_to_dashboard_p50_seconds` (sign-in click → `/control-room` rendered) | T1 (Instrumented) | ≤ 2.5 s including WebAuthn ceremony | `passkey_authenticate_succeeded.duration_ms` from `ucc-auth-events.jsonl` |
| `registered_passkey_devices` (count of non-revoked credentials) | T1 (Instrumented) | ≥ 1 per active operator | Redis `SCARD ucc:operator:<email>:credentials` minus revoked |
| `bootstrap_token_redemption_rate` | T1 (Instrumented) | ≥ 95% of issued tokens get redeemed within 15-min TTL | Count `ucc:bootstrap:*` keys with `used: true` / total issued |

### Guardrails (must not degrade)

| Metric | Tier | Threshold |
|---|---|---|
| Vercel function p50 latency on `/api/auth/*` | T1 | ≤ 200 ms (Upstash Redis read budget) |
| Failed-assertion ratio (`passkey_authenticate_failed` / total) | T1 | ≤ 5% in steady state (excludes the cutover week) |
| Existing `/control-room/*` page load p50 | T1 | No degradation vs pre-feature baseline (proxy.ts cookie-check overhead < 10 ms) |

### Leading indicators (1 week)

- All authorized operators have ≥ 1 registered passkey within 7 days of `UCC_AUTH_MODE=both` ship.
- ≥ 95% of `passkey_register_started` events lead to a `passkey_register_completed` event (kill criterion 1 below).
- 0 `unknown_credential` failures (would indicate KV write/read drift).

### Lagging indicators (30 / 60 / 90 days)

- 30d: 100% of dashboard sessions originate from `passkey_authenticate_succeeded` (i.e. `UCC_AUTH_MODE=passkey` flipped).
- 60d: 0 unauthenticated reads (matches primary).
- 90d: ≤ 1 device-loss-recovery event per quarter (sanity check on operator workflow).

### Instrumentation plan

Every event in §8 (analytics spec) maps to:

1. A line in `.claude/logs/ucc-auth-events.jsonl` (cross-repo synced)
2. A row in `docs/product/analytics-taxonomy.csv` (if GA4-instrumented)
3. A test fixture in `fitme-story/src/lib/control-room/audit-log.test.ts`

### Review cadence

- **T+7d** post-`UCC_AUTH_MODE=both` ship: registration coverage check, lockout-tuning check.
- **T+14d**: ready-for-`passkey`-mode flip review (kill criterion 1 below).
- **T+30d / T+60d / T+90d**: standard PRD cadence reviews.

### Kill criteria

| # | Trigger | Action |
|---|---|---|
| K1 | Registration ceremony fails on > 5% of attempted devices in week 1 (week-1 cohort = first 7 days post `UCC_AUTH_MODE=both` ship) | Fall back to `UCC_AUTH_MODE=basic`. Reopen scope. |
| K2 | `passkey_authenticate_failed.reason: counter_replay` fires ≥ 1 time | **Hard stop.** Indicates KV counter desync or cloned authenticator. Investigate before any further sign-in attempts. |
| K3 | Vercel function p50 latency on `/api/auth/*` > 500 ms sustained for 24 h | Investigate Upstash Redis region misalignment. Fall back to `basic` if not resolved within 1 week. |

## 7. Locked decisions (carried from research §13)

| Q | Decision | Rationale |
|---|---|---|
| Q1 | **Multi-operator policy:** first operator self-bootstraps via env-var-gated CLI script. Subsequent operators (#2, #3, …) require an existing operator to run the CLI on their behalf and share the printed token. | Closes the "anyone with FT2 repo access can register a passkey" gap once we have at least one operator. CLI script reads an admin env var that is rotated independently. |
| Q2 | **Lockout:** N=5 consecutive `passkey_authenticate_failed` events on the same `email` → 15-minute lockout. Surfaced in `ucc-auth-events.jsonl` and the framework-health banner. | Standard rate-limit defaults; tuneable post-launch. |
| Q3 | **Session lifetime:** 24 h hard cap, sliding refresh if cookie age > 12 h on each authenticated request. | Matches the iOS pattern; balances re-auth friction vs token-theft window. |
| Q4 | **Mobile dashboard access:** out of scope. Operator surface is desktop-first. Sign-in page renders a "Use a desktop browser to access this dashboard" message on mobile UA (with a sign-out link). | Removes responsive-design burden from v1. Re-evaluate if multi-operator scale > 5. |
| Q5 | **Audit logging granularity:** every auth event (success + failure + revoke + bootstrap-issuance + session_minted/_expired) is logged. | We already accept Tier 2.2 cost across the framework; no reason to undercount here. |
| Q6 | **Vercel Blob → FT2 sync cadence:** daily GHA, with `last_synced_at` shown in framework-health for drift visibility. | Daily is sufficient for an operator dashboard with ≤ 30 events/day in steady state. Hourly if usage grows. |
| Q7 | **Conditional-UI autofill (`mediation: 'conditional'`):** enabled. | Single-tap sign-in is the whole point. |

## 8. Analytics Spec — GA4 event definitions

> **Convention:** events are scoped to the `auth` screen group (per [CLAUDE.md → Analytics Naming Convention](../../../CLAUDE.md)). All event names are snake_case, ≤ 40 chars, no GA4 reserved prefixes, no PII.

> **Note:** these events ALSO write to `.claude/logs/ucc-auth-events.jsonl` (the audit log). GA4 is for usage analytics; the JSONL is for the audit trail. The two writers fan out from the same call site.

### Events (all `category: auth`, `screen_scope: auth`)

| Event name | Trigger | Parameters | Conversion? |
|---|---|---|---|
| `auth_passkey_register_started` | `navigator.credentials.create()` invoked | `bootstrap_token_used: bool`, `device_type: "platform" \| "cross_platform"` | No |
| `auth_passkey_register_completed` | `verifyRegistrationResponse({ verified: true })` | `device_type`, `aaguid_truncated` (first 4 chars), `transports[]` (e.g. `["internal"]`, `["usb"]`) | **Yes** |
| `auth_passkey_register_failed` | Any error during registration ceremony | `reason: "user_cancelled" \| "no_authenticator" \| "attestation_invalid" \| "bootstrap_invalid" \| "timeout" \| "server_error"` | No |
| `auth_passkey_authenticate_started` | `navigator.credentials.get()` invoked | `mediation: "conditional" \| "required"` | No |
| `auth_passkey_authenticate_succeeded` | `verifyAuthenticationResponse({ verified: true })` | `duration_ms: number`, `mediation`, `device_type` | **Yes** |
| `auth_passkey_authenticate_failed` | Any error during authentication ceremony | `reason: "user_cancelled" \| "no_authenticator" \| "assertion_invalid" \| "counter_replay" \| "unknown_credential" \| "timeout" \| "server_error"`, `duration_ms` | No |
| `auth_passkey_revoked` | Operator clicks Revoke on `/control-room/settings/devices` | `revoked_self: bool` (true if revoking own credential, false if revoking someone else's) | No |
| `auth_session_minted` | After `_authenticate_succeeded`, before redirect | `session_ttl_seconds: 86400` | No |
| `auth_session_expired` | Cookie unseal fails or `expires_at` < now during proxy.ts check | `reason: "ttl" \| "revoked" \| "tamper"` | No |
| `auth_bootstrap_token_issued` | CLI script writes a `ucc:bootstrap:*` key | `issuer_self: bool` (always true today; placeholder for future "issuer ≠ self" multi-operator UX) | No |

### Screens (new)

| Screen name | View component | Category |
|---|---|---|
| `auth_passkey_signin` | `<SignInPage />` at `/control-room/sign-in` | auth |
| `auth_passkey_recover` | `<RecoverPage />` at `/control-room/sign-in/recover` | auth |
| `auth_passkey_devices` | `<DevicesPanel />` at `/control-room/settings/devices` | auth |
| `auth_passkey_audit` | `<AuditLogPanel />` at `/control-room/settings/audit` | auth |

### Naming validation checklist

- [x] All event names use snake_case
- [x] All event names ≤ 40 characters
- [x] No reserved prefixes (`ga_`, `firebase_`, `google_`)
- [x] No duplicates against existing `AnalyticsEvent` enum (would conflict only if an iOS event used the same name; cross-checked against `FitTracker/Services/Analytics/AnalyticsProvider.swift`)
- [x] No PII in any parameter (no email, raw credential ID, raw IP, full user agent)
- [x] All parameter values ≤ 100 chars
- [x] All events have ≤ 25 parameters
- [x] No new user properties added (operator identity is logged in JSONL, not GA4)
- [x] `auth_` screen-scope prefix on every event
- [x] GA4 recommended events not duplicated (no `login` event — `auth_passkey_authenticate_succeeded` covers it; `login` would be ambiguous between iOS app login and dashboard sign-in)

## 9. Audit-log schema (`.claude/logs/ucc-auth-events.jsonl`)

Append-only JSONL, one event per line. **Common fields on every event:**

```json
{
  "timestamp": "2026-05-07T16:42:01.000Z",
  "event_type": "auth_passkey_authenticate_succeeded",
  "schema_version": 1,
  "credential_id_hash": "sha256:7a3f...c2",
  "operator_label": "regev-mbp-touchid",
  "ip_class": "ipv4-203.0.113.0/24",
  "user_agent_family": "Safari/macOS",
  "outcome": "success",
  "reason": null,
  "session_id_hash": "sha256:1b8e...a4",
  "rp_id": "fitme-story.vercel.app",
  "duration_ms": 412
}
```

**Per-event-type extras** (already specified in research §9). Privacy guarantees: never log raw `credential_id` (use SHA-256 hash); IPv4 truncated to /24, IPv6 to /48; user agent stripped to family string; raw token never written.

## 10. Architecture

### Data flow

```
                                 ┌──────────────────────────────┐
                                 │  Operator's browser          │
                                 │  (Safari / Chrome / Edge)    │
                                 └─────────────┬────────────────┘
                                               │
                                               │ /control-room/sign-in
                                               ▼
            ┌────────────────────────────────────────────────────┐
            │  fitme-story (Next.js 16 on Vercel)                │
            │                                                    │
            │  ┌───────────────────────────────────────────┐     │
            │  │ proxy.ts (Node.js runtime)                │     │
            │  │   ├─ if UCC_AUTH_MODE=basic → existing    │     │
            │  │   ├─ if UCC_AUTH_MODE=passkey → check     │     │
            │  │   │     iron-session cookie               │     │
            │  │   └─ if UCC_AUTH_MODE=both → accept       │     │
            │  │         either                            │     │
            │  └───────────────────────────────────────────┘     │
            │                                                    │
            │  ┌───────────────────────────────────────────┐     │
            │  │ /api/auth/* route handlers                │     │
            │  │   (Node.js runtime)                       │     │
            │  │   ├─ POST /register/options               │     │
            │  │   ├─ POST /register/verify                │     │
            │  │   ├─ POST /authenticate/options           │     │
            │  │   ├─ POST /authenticate/verify            │     │
            │  │   └─ POST /revoke                         │     │
            │  │                                           │     │
            │  │   Uses @simplewebauthn/server v13         │     │
            │  └─────────────┬─────────────────────────────┘     │
            │                │                                   │
            │                │ Read/write                        │
            │                ▼                                   │
            │  ┌────────────────────────────────────────────┐    │
            │  │ Upstash Redis (Vercel Marketplace)         │    │
            │  │   ucc:operator:*                           │    │
            │  │   ucc:credential:*                         │    │
            │  │   ucc:operator:<email>:credentials         │    │
            │  │   ucc:challenge:* (TTL 60s)                │    │
            │  │   ucc:bootstrap:* (TTL 15min)              │    │
            │  │   ucc:session:* (TTL 24h)                  │    │
            │  └────────────────────────────────────────────┘    │
            │                                                    │
            │  ┌────────────────────────────────────────────┐    │
            │  │ Audit log writer                           │    │
            │  │   → .local/ucc-auth-events.jsonl (live)    │    │
            │  │   → POST to Vercel Blob (post-write hook)  │    │
            │  └────────────────────────────────────────────┘    │
            └────────────────────────────────────────────────────┘

                                                                  │
                                                                  │ Daily GHA
                                                                  ▼
            ┌────────────────────────────────────────────────────┐
            │  FitTracker2 (canonical repo)                      │
            │                                                    │
            │  .claude/logs/ucc-auth-events.jsonl                │
            │     (synced from Vercel Blob, one commit per day)  │
            │                                                    │
            │  fitme-story/src/lib/framework-health/             │
            │     load-ledgers.ts → reads above JSONL            │
            │     → renders AuditLogPanel on /control-room/      │
            │       framework                                    │
            └────────────────────────────────────────────────────┘
```

### Files touched

#### fitme-story (~14 files)

| Path | Action | Purpose |
|---|---|---|
| `src/proxy.ts` | Edit | Add `UCC_AUTH_MODE` switch + iron-session cookie check |
| `src/lib/auth/webauthn-server.ts` | New | Wraps `@simplewebauthn/server` v13 |
| `src/lib/auth/redis-store.ts` | New | Upstash KV CRUD for operator/credential/challenge/bootstrap/session |
| `src/lib/auth/audit-log.ts` | New | Writes JSONL + POSTs to Vercel Blob |
| `src/lib/auth/iron-session-config.ts` | New | Cookie config + secret loading |
| `src/app/api/auth/register/options/route.ts` | New | Generates `PublicKeyCredentialCreationOptions` |
| `src/app/api/auth/register/verify/route.ts` | New | Verifies attestation + persists credential |
| `src/app/api/auth/authenticate/options/route.ts` | New | Generates `PublicKeyCredentialRequestOptions` |
| `src/app/api/auth/authenticate/verify/route.ts` | New | Verifies assertion + mints session |
| `src/app/api/auth/revoke/route.ts` | New | Marks credential revoked |
| `src/app/control-room/sign-in/page.tsx` | New | Sign-in screen with conditional-UI autofill |
| `src/app/control-room/sign-in/recover/page.tsx` | New | Recovery screen with bootstrap-token paste |
| `src/app/control-room/settings/devices/page.tsx` | New | Devices admin |
| `src/app/control-room/settings/audit/page.tsx` | New | Audit log viewer |
| `src/components/control-room/AuthPasskeyForm.tsx` | New | Reusable WebAuthn ceremony component |
| `src/components/control-room/AuditLogPanel.tsx` | New | Embedded in framework-health page |
| `scripts/issue-bootstrap-token.ts` | New | CLI for issuing bootstrap tokens |
| `scripts/sync-from-fittracker2.ts` | Edit | Add `--reverse` mode for audit-log sync |
| `package.json` | Edit | Add `@simplewebauthn/{server,browser}` v13 + `iron-session` + `@upstash/redis` |

#### FitTracker2 (~3 files)

| Path | Action | Purpose |
|---|---|---|
| `.claude/logs/ucc-auth-events.jsonl` | New (placeholder) | Synced target file (daily commits) |
| `.github/workflows/ucc-audit-log-sync.yml` | New | Daily GHA: pull Vercel Blob → commit JSONL |
| `fitme-story/src/lib/glossary.ts` | Edit | Add entries: passkey, WebAuthn, RP-ID, conditional UI, bootstrap token |

### Environment variables

| Var | Where | Purpose |
|---|---|---|
| `UCC_AUTH_MODE` | Vercel project (production) | `basic` \| `passkey` \| `both` |
| `UCC_SESSION_SECRET` | Vercel project (production) | 32-byte secret for iron-session AES-GCM |
| `UPSTASH_REDIS_REST_URL` | Vercel Marketplace integration | Already provisioned |
| `UPSTASH_REDIS_REST_TOKEN` | Vercel Marketplace integration | Already provisioned |
| `UCC_BOOTSTRAP_ADMIN_TOKEN` | Vercel project + local `.env.local` | Gate for `scripts/issue-bootstrap-token.ts` |
| `UCC_AUDIT_BLOB_TOKEN` | Vercel project | Auth for the `.local/ucc-auth-events.jsonl` → Vercel Blob POST |
| `DASHBOARD_USER` | Vercel (preserve until cutover) | Existing basic-auth user |
| `DASHBOARD_PASS` | Vercel (preserve until cutover) | Existing basic-auth pass |

## 11. Migration plan

| Phase | `UCC_AUTH_MODE` | Action | Exit criterion |
|---|---|---|---|
| **Pre-ship** | `basic` (current) | Deploy v1 code with both paths wired; `passkey` path is dead-code in the proxy | CI green on both repos |
| **Cutover-T0** | `basic` → `both` | Flip env var. Existing basic-auth keeps working. Each operator runs the bootstrap CLI for themselves (Q1 default) and registers their primary device | All authorized operators have ≥ 1 registered passkey |
| **Cutover-T+7d** | `both` (still) | Each operator registers a YubiKey or second device as break-glass | ≥ 2 credentials per operator (primary + break-glass) |
| **Cutover-T+14d** | `both` → `passkey` | Flip env var. Drop `DASHBOARD_USER` + `DASHBOARD_PASS` env vars | 0 `auth_basic` events in last 24h on framework-health AuditLogPanel; review the K1 kill criterion |
| **Steady state** | `passkey` | Continuous operation | Quarterly review against secondary metrics |

**Rollback at any phase:** flip `UCC_AUTH_MODE` back to `basic` (or `both`). No data migration is destructive — credential records stay in Redis even if unused.

## 12. Test & Eval Requirements

> **Eval gate (v6.0):** This feature has **no AI behaviors** (no AIOrchestrator, no recommendation logic). `requires_analytics = true` triggers the analytics gate (§8 above), but `min_eval_coverage_met` auto-passes.

### Unit tests (fitme-story)

| Test file | Coverage |
|---|---|
| `src/lib/auth/webauthn-server.test.ts` | `generateRegistrationOptions`, `verifyRegistrationResponse`, `generateAuthenticationOptions`, `verifyAuthenticationResponse` happy + error paths; replay-counter check |
| `src/lib/auth/redis-store.test.ts` | KV CRUD with mocked Upstash client; TTL behavior; CAS counter update |
| `src/lib/auth/audit-log.test.ts` | JSONL append + Vercel Blob POST; PII redaction (raw credential ID, full IP, full UA all masked) |
| `src/lib/auth/iron-session-config.test.ts` | Cookie seal/unseal; tamper detection; expiry |
| `src/proxy.test.ts` | All three `UCC_AUTH_MODE` branches; redirect-to-sign-in (not 401); cookie-presence check |
| `src/app/api/auth/*/route.test.ts` (5 files) | API route happy + error paths; SimpleWebAuthn integration mocked |
| `src/components/control-room/AuthPasskeyForm.test.tsx` | Capability detection, error states, retry UX (mirrors `auth-polish-v2` patterns) |
| `src/components/control-room/AuditLogPanel.test.tsx` | Stat row counts; recent-events table render; suspicious-event banner triggers |
| `scripts/issue-bootstrap-token.test.ts` | Token entropy + format; admin-token gating; SHA-256 hash storage |

### Integration tests

| Test | Description |
|---|---|
| **Round-trip registration + authentication (Vitest + jsdom)** | Stub authenticator, run full registration ceremony, then full authentication ceremony; assert KV state at each step |
| **Cross-repo sync** | Stub Vercel Blob; run `scripts/sync-from-fittracker2.ts --reverse`; assert FT2-side JSONL contains the events |

### Manual smoke tests (recorded in `runtime-smoke` profile)

A new profile `passkey_signin_surface` added to `make runtime-smoke`:

1. Operator runs `pnpm dlx tsx scripts/issue-bootstrap-token.ts ops@example.com`
2. Operator pastes token into `/control-room/sign-in?bootstrap=<token>` (URL contains the token only on the very first device)
3. Touch ID prompt → success → redirect to `/control-room`
4. Sign out → return to sign-in → conditional-UI autofill prompt → biometric → redirected back
5. Open `/control-room/settings/devices` → verify entry exists with `lastUsedAt` updated
6. Revoke entry → next sign-in attempt fails with `unknown_credential`
7. Re-register via fresh bootstrap token

### Analytics verification (Phase 5 §gate)

Per CLAUDE.md Phase 1 Analytics Spec gate, every event in §8 needs a unit test in `src/lib/control-room/analytics.test.ts` (or equivalent) asserting:

- Event fires with correct name + parameters
- Consent gate (if applicable) blocks event when denied
- No PII leaks in parameter values

## 13. Risks + mitigations

| # | Risk | Mitigation |
|---|---|---|
| R1 | iCloud Keychain / Google Password Manager passkey sync failures lock an operator out | Each operator MUST register a YubiKey as break-glass (enforced via Cutover-T+7d gate above); revocable per-device |
| R2 | Vercel Blob outage breaks audit-log sync | Live JSONL at `fitme-story/.local/ucc-auth-events.jsonl` is the authoritative source; daily GHA is best-effort; `last_synced_at` in framework-health surfaces drift |
| R3 | Upstash Redis region misalignment with Vercel function region adds latency | Region-pin both at deployment time; monitor p50 latency guardrail (§6) |
| R4 | Bootstrap token leaked via shoulder-surf at the operator's terminal | 15-min TTL + single-use + SHA-256 hash at rest minimizes exposure window; operator responsibility to not screen-share the issuance step |
| R5 | Preview deploys at `*-fitme-story.vercel.app` can't use production passkeys (RP-ID mismatch) | `UCC_AUTH_MODE=basic` is the default for non-production deploys; documented in deployment guide |
| R6 | iron-session secret rotation requires invalidating all sessions | Document the rotation procedure; Q1 default = single operator can reset by clearing Redis + re-bootstrapping |
| R7 | `passkey_authenticate_failed.reason: counter_replay` indicates a real attack OR a benign authenticator quirk (some hardware keys don't increment the counter) | K2 kill criterion = hard stop. Investigate before resuming. Document fallback if the cause is an authenticator quirk (allowlist by `aaguid`). |

## 14. Open questions for v2 / future work

- **Multi-tenant identity:** when operator count > 5, evaluate Clerk/Descope for the operator surface. Out of v1.
- **Mobile dashboard:** if responsive `/control-room/*` becomes a need, the WebAuthn ceremony works on iOS Safari ≥ 16; only the layout work is missing.
- **Session refresh strategy:** could move to JWT with rotating refresh tokens at scale. iron-session is correct for ≤ 30 operators.
- **PagerDuty / alerting:** v1 surfaces suspicious activity in the dashboard banner. v2 could fire to PagerDuty or Slack.
- **Per-operator FIDO MDS attestation policy:** today we accept any platform authenticator; v2 could require attested authenticators (cert-pinned to known vendors).

## 15. Phase 1 exit checklist

- [x] Goals + non-goals defined
- [x] User stories with acceptance criteria
- [x] Primary metric with baseline + target + measurement
- [x] Secondary + guardrail metrics
- [x] Leading + lagging indicators
- [x] Instrumentation plan
- [x] Review cadence
- [x] Kill criteria
- [x] All 7 locked decisions documented
- [x] Analytics Spec passes naming validation checklist
- [x] Architecture diagram + files-touched list
- [x] Migration plan with rollback at every phase
- [x] Test plan + eval-gate auto-pass (no AI behaviors)
- [x] Risks + mitigations
- [ ] **User approval to advance to Phase 2 (Tasks)**

---

**Author note:** This PRD is intentionally exhaustive on the architecture + migration sides because the cross-repo + reversibility requirements are where most of the complexity lives. Phase 2 will turn this into a task graph; expect ~24 tasks across 6 blocks (auth-server, KV-store, API-routes, sign-in-UI, devices-admin-UI, framework-health-panel, sync, docs).
