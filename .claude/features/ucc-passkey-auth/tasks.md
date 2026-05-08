# Task Breakdown — `ucc-passkey-auth`

**PRD:** [`prd.md`](./prd.md) (approved 2026-05-07T16:48Z)
**Total tasks:** 28
**Estimated effort:** 1.5–2 person-weeks
**Lane allocation:** 16 E-core (parallel sonnet) · 12 P-core (serial opus)

> **Classification key:** task complexity scored per CLAUDE.md task-complexity gate. Score ≥ 4 → P-core (serial, opus). Score < 4 → E-core (parallel, sonnet).

---

## Block A — Auth-server library (fitme-story)

| ID | Task | Files | Indicators (score) | Lane | Effort |
|---|---|---|---|---|---|
| **T1** | Wrap `@simplewebauthn/server` v13: `generateRegistrationOptions`, `verifyRegistrationResponse`, `generateAuthenticationOptions`, `verifyAuthenticationResponse` | `src/lib/auth/webauthn-server.ts` (new) | new_service(3) + token_high(2) + judgment(3) = 8 | **P-core** | 0.75d |
| **T2** | iron-session config + helpers (seal/unseal session cookie) | `src/lib/auth/iron-session-config.ts` (new) | new_service(3) = 3 | E-core | 0.25d |
| **T3** | Audit-log writer (JSONL append + PII redaction + Vercel Blob POST hook) | `src/lib/auth/audit-log.ts` (new) | new_service(3) + judgment(3) = 6 | **P-core** | 0.5d |

## Block B — KV store (fitme-story)

| ID | Task | Files | Indicators (score) | Lane | Effort |
|---|---|---|---|---|---|
| **T4** | Upstash Redis client setup + region pinning | `src/lib/auth/redis-client.ts` (new) | new_service(3) = 3 | E-core | 0.25d |
| **T5** | KV CRUD: operator + credential + reverse-index with CAS counter update | `src/lib/auth/redis-store.ts` (new) | new_service(3) + token_high(2) = 5 | **P-core** | 0.5d |
| **T6** | KV CRUD: challenge (60s TTL) + bootstrap (15min TTL) + session (24h TTL) | `src/lib/auth/redis-ttl-store.ts` (new) | new_service(3) = 3 | E-core | 0.25d |

## Block C — API routes (fitme-story)

| ID | Task | Files | Indicators (score) | Lane | Effort |
|---|---|---|---|---|---|
| **T7** | `POST /api/auth/register/options` route | `src/app/api/auth/register/options/route.ts` (new) | files(0) = 0 | E-core | 0.25d |
| **T8** | `POST /api/auth/register/verify` route | `src/app/api/auth/register/verify/route.ts` (new) | judgment(3) = 3 | E-core | 0.25d |
| **T9** | `POST /api/auth/authenticate/options` route | `src/app/api/auth/authenticate/options/route.ts` (new) | files(0) = 0 | E-core | 0.25d |
| **T10** | `POST /api/auth/authenticate/verify` route (mints session cookie) | `src/app/api/auth/authenticate/verify/route.ts` (new) | new_service(3) + judgment(3) = 6 | **P-core** | 0.5d |
| **T11** | `POST /api/auth/revoke` route | `src/app/api/auth/revoke/route.ts` (new) | files(0) = 0 | E-core | 0.25d |
| **T12** | Edit `src/proxy.ts`: add `UCC_AUTH_MODE` switch + iron-session cookie check | `src/proxy.ts` (edit) | judgment(3) + cross_feature(2) = 5 | **P-core** | 0.5d |

## Block D — Sign-in + Recover UI (fitme-story)

| ID | Task | Files | Indicators (score) | Lane | Effort |
|---|---|---|---|---|---|
| **T13** | `<AuthPasskeyForm />` reusable component (capability detection + ceremony + error states) | `src/components/control-room/AuthPasskeyForm.tsx` (new) | judgment(3) + token_high(2) = 5 | **P-core** | 0.5d |
| **T14** | `/control-room/sign-in/page.tsx` — sign-in screen with conditional-UI autofill | `src/app/control-room/sign-in/page.tsx` (new) | judgment(3) = 3 | E-core | 0.5d |
| **T15** | `/control-room/sign-in/recover/page.tsx` — bootstrap-token paste flow | `src/app/control-room/sign-in/recover/page.tsx` (new) | files(0) = 0 | E-core | 0.25d |

## Block E — Devices + Audit admin UI (fitme-story)

| ID | Task | Files | Indicators (score) | Lane | Effort |
|---|---|---|---|---|---|
| **T16** | `/control-room/settings/devices/page.tsx` — credentials table + Revoke button | `src/app/control-room/settings/devices/page.tsx` (new) | files(0) = 0 | E-core | 0.5d |
| **T17** | `/control-room/settings/audit/page.tsx` — last 50 events viewer | `src/app/control-room/settings/audit/page.tsx` (new) | files(0) = 0 | E-core | 0.5d |

## Block F — Framework-health panel + cross-repo sync + bootstrap CLI

| ID | Task | Files | Indicators (score) | Lane | Effort |
|---|---|---|---|---|---|
| **T18** | `<AuditLogPanel />` component (3-stat row + recent events table + suspicious banner) | `src/components/control-room/AuditLogPanel.tsx` (new) | judgment(3) = 3 | E-core | 0.5d |
| **T19** | Wire `<AuditLogPanel />` into `/control-room/framework/page.tsx` | `src/app/control-room/framework/page.tsx` (edit) | files(0) = 0 | E-core | 0.25d |
| **T20** | CLI: `scripts/issue-bootstrap-token.ts` (32B token + SHA-256 hash + admin-token gate) | `fitme-story/scripts/issue-bootstrap-token.ts` (new) | new_service(3) + judgment(3) = 6 | **P-core** | 0.5d |
| **T21** | Reverse-mode for `scripts/sync-from-fittracker2.ts` (fetch JSONL from Vercel Blob) | `fitme-story/scripts/sync-from-fittracker2.ts` (edit) + new sibling `scripts/sync-to-fittracker2.ts` (new) | cross_feature(2) + judgment(3) = 5 | **P-core** | 0.5d |
| **T22** | Daily GHA workflow in FT2 to pull Vercel Blob → commit `.claude/logs/ucc-auth-events.jsonl` | `.github/workflows/ucc-audit-log-sync.yml` (new) | new_service(3) + cross_feature(2) = 5 | **P-core** | 0.25d |
| **T23** | FT2 placeholder `.claude/logs/ucc-auth-events.jsonl` (empty file with schema header comment) | `.claude/logs/ucc-auth-events.jsonl` (new) | files(0) = 0 | E-core | 0.1d |

## Block G — Tests

| ID | Task | Files | Indicators (score) | Lane | Effort |
|---|---|---|---|---|---|
| **T24** | Unit tests for `webauthn-server`, `redis-store`, `audit-log`, `iron-session-config`, `proxy.ts` | 5 test files | token_high(2) + judgment(3) = 5 | **P-core** | 1.0d |
| **T25** | Unit tests for 5 API routes + `AuthPasskeyForm` + `AuditLogPanel` | 7 test files | files_changed_gt_5(2) + token_high(2) = 4 | **P-core** | 1.0d |
| **T26** | Integration test: round-trip registration + authentication ceremony with stub authenticator | `src/lib/auth/round-trip.test.ts` (new) | judgment(3) + token_high(2) = 5 | **P-core** | 0.5d |
| **T27** | New `runtime-smoke` profile `passkey_signin_surface` in FT2 | `scripts/runtime-smoke/profiles/passkey-signin.sh` (new) + `Makefile` (edit) | cross_feature(2) = 2 | E-core | 0.25d |

## Block H — Documentation + glossary

| ID | Task | Files | Indicators (score) | Lane | Effort |
|---|---|---|---|---|---|
| **T28** | Add glossary entries: passkey, WebAuthn, RP-ID, conditional UI, bootstrap token, iron-session, FIDO2 | `fitme-story/src/lib/glossary.ts` (edit) | files(0) = 0 | E-core | 0.25d |

---

## Dependency graph

```
                                      Block A (auth-server)
                                       T1 → T3
                                       T2 (independent)
                                          ↓
                                     Block B (KV store)
                                       T4 → T5 → T6
                                          ↓
                                  Block C (API routes)
                                       T7,T8,T9,T10,T11
                                       T12 (proxy edit)
                                          ↓
                  ┌──────────────────────┼──────────────────────┐
                  ↓                      ↓                      ↓
            Block D (sign-in UI)  Block E (admin UI)    Block F (sync + CLI + panel)
              T13 → T14, T15        T16, T17              T18 → T19
                                                           T20, T21, T22, T23
                                                              ↓
                                  Block G (tests)
                                    T24 → T25 → T26
                                       T27
                                          ↓
                                  Block H (docs)
                                    T28
```

## Phase 4 dispatch order (lane execution)

**Wave 1** — E-core parallel (max 5 concurrent, sonnet):
- T2 (iron-session config) · T4 (Redis client) · T6 (TTL store) · T7 (register/options route) · T11 (revoke route)
- T23 (FT2 JSONL placeholder) · T28 (glossary)

**Wave 2** — P-core serial (opus):
- T1 (WebAuthn wrapper) → T3 (audit-log writer) → T5 (KV CRUD CAS) → T10 (auth/verify mints session) → T12 (proxy edit) → T13 (AuthPasskeyForm) → T20 (bootstrap CLI) → T21 (reverse sync) → T22 (GHA)

**Wave 3** — E-core parallel after deps unblock (sonnet):
- T8, T9 (auth options + register verify routes) · T14, T15 (sign-in + recover screens) · T16, T17 (devices + audit pages) · T18, T19 (AuditLogPanel + wire-in)

**Wave 4** — Tests (P-core serial):
- T24 (lib tests) → T25 (route + UI tests) → T26 (integration test) → T27 (runtime-smoke profile, E-core)

## Phase 4 exit criteria

- All 28 tasks have `status: "done"` in `state.json::tasks[]`
- `xcodebuild test` (FT2 side) passes with new runtime-smoke profile
- `pnpm test` (fitme-story side) passes with all new test files
- `pnpm build` (fitme-story side) passes
- No P0 in `make ui-audit` (FT2-side gate, but the changes are fitme-story-only — should be a no-op pass)
- Both branches CI-green
