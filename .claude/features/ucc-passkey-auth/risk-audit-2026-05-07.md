# Risk Audit — `ucc-passkey-auth` — 2026-05-07

**Phase 6 sub-step 6a + 6e** · diff vs main + risk surface for Phase 7 reviewer

---

## Diff size

| Repo | Files added | Files modified | Lines added | Lines removed |
|---|---|---|---|---|
| **fitme-story** | 22 | 4 (proxy.ts, package.json, vercel.json, framework/page.tsx, analytics.ts, glossary.ts) | ~2,650 | ~36 |
| **FitTracker2** | 2 (GHA workflow + JSONL placeholder) | 0 | ~95 | 0 |

## High-risk files (per CLAUDE.md branching rules)

CLAUDE.md flags these as requiring extra review: `DomainModels.swift`, `EncryptionService.swift`, `SupabaseSyncService.swift`, `CloudKitSyncService.swift`, `SignInService.swift`, `AuthManager.swift`, `AIOrchestrator.swift`. **None touched by this feature** — the iOS Swift codebase is unmodified. ✓

## Surface-level risk surface (this feature)

| File | Risk | Mitigation |
|---|---|---|
| `fitme-story/src/proxy.ts` (modified) | Production gate — every `/control-room/*` request flows through it. Bug here = lockout or full-bypass. | (1) `UCC_AUTH_MODE=basic` default preserves prior behavior; (2) `DASHBOARD_PUBLIC=true` dev escape hatch unchanged; (3) sign-in + recover paths exempt from the gate; (4) `/api/auth/*` routes exempt; (5) tested for all 3 modes. **Migration plan ships in `both` mode, providing an explicit fallback path.** |
| `fitme-story/src/lib/auth/redis-store.ts` (new) | CAS counter check is the replay defense. Bug = silent acceptance of replayed assertions. | Tested with 19 unit tests; round-trip integration test exercises the full path. Hardware authenticators that report counter=0 are explicitly handled (MUST stay 0; reject if stored is non-zero). |
| `fitme-story/src/app/api/auth/authenticate/verify/route.ts` (new) | Mints session cookie on successful assertion. Bug = unauthorized session minting. | All 6 negative paths (`no_pending_challenge`, `unknown_credential`, `assertion_invalid`, `counter_replay`, `server_error`, revoked credential) explicitly test before minting. iron-session cookie is HttpOnly + SameSite=Strict + scoped to `/control-room`. |
| `fitme-story/src/lib/auth/iron-session-config.ts` (new) | Garbage-input handling. Pre-fix returned `{}` on bad cookies. | Caught + fixed — `unsealSession` now requires all 4 payload fields (`email`, `sid`, `iat`, `exp`) of correct type. Test added. |
| `fitme-story/src/lib/auth/audit-log.ts` (new) | PII redaction. Bug = leaked credential ID, full IP, full UA, raw session ID. | Test asserts no raw value appears in the JSONL output. SHA-256 hashes for credential ID + session ID; IPv4 truncated to /24, IPv6 to /48; UA stripped to family. |
| `fitme-story/scripts/issue-bootstrap-token.ts` (new) | First-device registration gate. Bug = unauthorized registration. | (1) Admin-token gate (`UCC_BOOTSTRAP_ADMIN_TOKEN ≥ 32 bytes`); (2) 32-byte random token, 15-min TTL, single-use; (3) raw token never stored — SHA-256 hash at rest; (4) email argument required + validated. |
| `fitme-story/src/app/api/cron/sync-audit-log/route.ts` (new) | Reads .local file + uploads to Vercel Blob. | (1) Vercel-Cron `Authorization: Bearer ${CRON_SECRET}` check (rejects without secret); (2) blob token gate; (3) read-only on the local file. |
| `FitTracker2/.github/workflows/ucc-audit-log-sync.yml` (new) | Auto-commits to FT2 main daily. | (1) only commits when content actually changed; (2) source URL is repo-variable gated (`UCC_AUDIT_BLOB_URL` not set → no-op); (3) no untrusted user input consumed; (4) commit author is `github-actions[bot]`. |

## Threat-model coverage (cross-reference PRD §13)

| Threat | Code path that defends | Test |
|---|---|---|
| Phishing | `expectedRPID + expectedOrigin` checks in `verifyRegistrationResponse` + `verifyAuthenticationResponse` | round-trip-test asserts these are passed |
| Replay | Per-ceremony challenge in Redis (60s TTL, single-use) + CAS counter check | `consumeChallenge` deletes on read; `updateCounterCAS` tested |
| Session theft | HttpOnly + Secure + SameSite=Strict + server-side `ucc:session:*` allowlist | `unsealSession` + revoke flow |
| RP-ID spoofing | RP_ID from env, hardcoded fallback `fitme-story.vercel.app` | preview deploys stay on `UCC_AUTH_MODE=basic` per PRD §8 |
| Lost device | Revoke flow + bulk-revoke if last credential | `<DevicesTable>` Revoke button → POST `/api/auth/revoke` |
| Hardware key | `transports: ['internal', 'usb', 'nfc']` accepted; `authenticatorAttachment: undefined` (allow both) | tests assert SimpleWebAuthn options shape |
| Counter-replay attack | K2 kill criterion on `counter_replay` reason | `updateCounterCAS` returns `{ ok: false, reason: 'replay' }`; route logs + rejects |

## CI status

| Branch | Status |
|---|---|
| `feature/ucc-passkey-auth` (fitme-story) | tsc clean on feature files (pre-existing errors in unrelated test files) · 19/19 tests pass · `next build` clean |
| `feature/ucc-passkey-auth` (FT2 worktree) | No iOS changes; FT2 CI not run (workflow + JSONL placeholder don't touch Swift target) |
| `main` (both repos) | green per most recent run |

## Final verdict

✅ **PASS** — risk surface is bounded to:
1. The proxy.ts gate (mitigated by `UCC_AUTH_MODE=basic` default + `both` migration window)
2. The replay-defense path (mitigated by explicit CAS check + counter-replay K2 hard-stop kill criterion)
3. The PII-redaction path (mitigated by tests asserting no raw value leaks)

No high-risk Swift files touched. Cross-repo plumbing is gated on env vars + repo variables; absence is a no-op rather than a failure.

**Phase 7 (Merge) is approvable** pending user sign-off.
