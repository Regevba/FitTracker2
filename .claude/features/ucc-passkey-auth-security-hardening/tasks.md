# UCC Passkey Auth Security Hardening — Task Breakdown

> **Source:** [`docs/superpowers/specs/2026-05-19-ucc-passkey-security-hardening-design.md`](../../../docs/superpowers/specs/2026-05-19-ucc-passkey-security-hardening-design.md)
> **Phase:** Tasks (current)
> **Target completion:** 2026-05-20 EOD (gate: before 2026-05-21 v7.9 freeze)
> **Total tasks:** 26 · **Total effort:** ~1.5 dev-days (single operator, with batched test writing)

## Lanes (ARM big.LITTLE classifier per /pm-workflow §Phase 4)

| Lane | Model | Tasks | Rationale |
|---|---|---|---|
| **E-core (parallel-able, sonnet)** | sonnet | T2, T3, T6, T7, T11, T12, T14, T15, T17, T18, T24 | Mechanical edits to enums + isolated test files + env example + docs |
| **P-core (serial, opus)** | opus | T1, T4, T5, T8, T9, T10, T13, T16 | Refactor + new auth modules + multi-file wiring + CLI |
| **Operator-only (no agent)** | — | T19, T20, T22, T23, T25, T26 | Manual operator actions (Vercel env-var set, manual verify matrix, PR open, post-merge checks) |

## Task Inventory

### Stream A — Refactor foundation (P-core, blocks D + E)

| ID | Title | Type | Skill | Effort | Depends on | File(s) |
|---|---|---|---|---|---|---|
| **T1** | Extract `ipClassFromRaw` + `uaFamilyFromRaw` to `src/lib/auth/audit-log-redactors.ts`, re-export from `audit-log.ts`. Pure refactor — no behavioral change. | refactor | dev | 0.3h | — | `src/lib/auth/audit-log.ts`, `src/lib/auth/audit-log-redactors.ts` (new) |

### Stream B — Audit-event taxonomy (E-core, blocks C+D+E+F wiring)

| ID | Title | Type | Skill | Effort | Depends on | File(s) |
|---|---|---|---|---|---|---|
| **T2** | Extend `AuthEventType` enum: add `auth_lockout_triggered`, `auth_lockout_blocked_attempt`, `auth_lockout_cleared`. Rename existing `auth_bootstrap_token_issued` → `auth_bootstrap_token_consumed`. Add new `auth_bootstrap_token_issued` (true issuance). Sweep call sites in `register/options/route.ts`. | enum | dev | 0.5h | — | `src/lib/auth/audit-log.ts`, `src/app/api/auth/register/options/route.ts` |
| **T3** | Extend `AuthEventReason` enum: add `email_not_allowlisted`, `allowlist_unset`, `email_threshold`, `ip_threshold`, `email_locked`, `ip_locked`, `manual_clear`. | enum | dev | 0.2h | — | `src/lib/auth/audit-log.ts` |

### Stream C — G1+G2 Allowlist gate (P-core code + E-core tests)

| ID | Title | Type | Skill | Effort | Depends on | File(s) |
|---|---|---|---|---|---|---|
| **T4** | Create `src/lib/auth/allowlist.ts` with `isEmailAllowed()`, `allowlistSize()`, `allowlistIsConfigured()`. Fail-closed on unset. | feature | dev | 0.3h | — | `src/lib/auth/allowlist.ts` (new) |
| **T5** | Wire allowlist gate in `/api/auth/register/options/route.ts` between `consumeBootstrap()` and `getOperator()`. Emit `email_not_allowlisted` (403) or `allowlist_unset` (403 fail-closed). | wiring | dev | 0.3h | T3, T4 | `src/app/api/auth/register/options/route.ts` |
| **T6** | Write `src/lib/auth/__tests__/allowlist.test.ts` — 6 cases (set+match, case-insensitive, whitespace trim, multi-email, unset = empty Set, `allowlistIsConfigured()`). Vitest, mock `process.env`. | test | qa | 0.5h | T4 | `src/lib/auth/__tests__/allowlist.test.ts` (new) |
| **T7** | Write `src/app/api/auth/register/options/__tests__/allowlist-gate.test.ts` — 5 cases (allowed→200, not-allowed→403, unset→403, audit event written, case-insensitive). | test | qa | 0.7h | T5 | `src/app/api/auth/register/options/__tests__/allowlist-gate.test.ts` (new) |

### Stream D — G3 Hybrid Lockout (P-core code + E-core tests)

| ID | Title | Type | Skill | Effort | Depends on | File(s) |
|---|---|---|---|---|---|---|
| **T8** | Create `src/lib/auth/redis-lockout.ts` with `checkLockout()`, `recordFailure()`, `clearFailures()`. EMAIL: 10 fails / 15-min TTL. IP: 20 fails / 30-min TTL. Fixed-window (set EXPIRE only on first INCR). | feature | dev | 1.0h | T1 | `src/lib/auth/redis-lockout.ts` (new) |
| **T9** | Wire `checkLockout` (top of handler), `recordFailure` (every failure branch), `clearFailures` (success branch before mintSession) in `/api/auth/authenticate/verify/route.ts`. | wiring | dev | 0.5h | T2, T3, T8 | `src/app/api/auth/authenticate/verify/route.ts` |
| **T10** | Same pattern in `/api/auth/register/verify/route.ts` — keyed on `body.email` (no credential row yet for first registration). | wiring | dev | 0.3h | T2, T3, T8 | `src/app/api/auth/register/verify/route.ts` |
| **T11** | Write `src/lib/auth/__tests__/redis-lockout.test.ts` — 10 cases (counter, threshold, TTL expiry, lockout block, per-email vs per-IP independence, clearFailures isolation, IPv4+IPv6 truncation parity). Mock `@/lib/auth/redis-client`. | test | qa | 1.2h | T8 | `src/lib/auth/__tests__/redis-lockout.test.ts` (new) |
| **T12** | Write `src/app/api/auth/authenticate/verify/__tests__/lockout-gate.test.ts` — 6 cases (locked email→429, locked IP→429 even for new email, failures recorded on 3 bad-cred paths, success clears). | test | qa | 0.8h | T9 | `src/app/api/auth/authenticate/verify/__tests__/lockout-gate.test.ts` (new) |

### Stream E — G4 Bootstrap-token issuance audit (P-core code + E-core tests)

| ID | Title | Type | Skill | Effort | Depends on | File(s) |
|---|---|---|---|---|---|---|
| **T13** | Add `logAuthEvent({event_type: 'auth_bootstrap_token_issued', ...})` to `scripts/issue-bootstrap-token.ts` after the Redis write succeeds. UA family = `cli/<user>@<host>`. | feature | dev | 0.3h | T2 | `scripts/issue-bootstrap-token.ts` |
| **T14** | Extend `uaFamilyFromRaw` in `audit-log-redactors.ts` to detect `cli/` prefix and emit family `cli/<user>` (drop hostname for public blob export). | enum | dev | 0.2h | T1 | `src/lib/auth/audit-log-redactors.ts` |
| **T15** | Write `scripts/__tests__/issue-bootstrap-token-audit.test.ts` — 3 cases (happy path emits event, Redis-write fail aborts before audit, audit-write fail is swallowed). | test | qa | 0.5h | T13 | `scripts/__tests__/issue-bootstrap-token-audit.test.ts` (new) |

### Stream F — CLI utility (P-core code + E-core test)

| ID | Title | Type | Skill | Effort | Depends on | File(s) |
|---|---|---|---|---|---|---|
| **T16** | Create `scripts/clear-lockout.ts` — CLI accepts `--email` and/or `--ip`. Calls `clearFailures()`. Emits `auth_lockout_cleared` event with `reason: manual_clear`. Reads `KV_REST_API_TOKEN`. | feature | dev | 0.5h | T3, T8 | `scripts/clear-lockout.ts` (new) |
| **T17** | Write `scripts/__tests__/clear-lockout.test.ts` — 4 cases (--email only, --ip only, both, audit event with manual_clear). | test | qa | 0.5h | T16 | `scripts/__tests__/clear-lockout.test.ts` (new) |

### Stream G — Env + docs (E-core, parallel)

| ID | Title | Type | Skill | Effort | Depends on | File(s) |
|---|---|---|---|---|---|---|
| **T18** | Document `UCC_ALLOWED_EMAILS` in `fitme-story/.env.example` with operator-facing comment. | docs | dev | 0.1h | — | `fitme-story/.env.example` |
| **T19** | **OPERATOR ACTION:** Set `UCC_ALLOWED_EMAILS=regvash21@gmail.com` in Vercel production env via dashboard or `vercel env add`. Verify with `vercel env ls`. **Must precede merge of T22.** | operator | ops | 0.1h | — | (Vercel dashboard) |

### Stream H — Verify + rollout (operator-only)

| ID | Title | Type | Skill | Effort | Depends on | File(s) |
|---|---|---|---|---|---|---|
| **T20** | **OPERATOR ACTION:** Run manual verification matrix per spec §8.2 — 6 scenarios (sign-in works, stale token, new token + allowed email, new token + disallowed email, 10 bad attempts lock, clear-lockout unlocks). | verify | ops | 0.5h | T6, T7, T11, T12, T15, T17, T18, T19 | — |
| **T21** | Run CI gates on fitme-story PR — `pnpm test/lint/typecheck`, `verify` workflow, Vercel preview deploy reachable. Run FT2 `make integrity-check` + `make documentation-debt`. | verify | qa | 0.3h | T6, T7, T11, T12, T15, T17 | — |
| **T22** | **OPERATOR ACTION:** Open fitme-story PR `feat/ucc-passkey-security-hardening` (NOT this FT2 prep PR #410, which is already open). Title: `feat(ucc-auth): security hardening — G1+G2 allowlist + G3 lockout + G4 issuance audit`. | merge | dev | 0.2h | T1-T17, T18, T19 | (GitHub) |

### Stream I — Post-merge (operator-only)

| ID | Title | Type | Skill | Effort | Depends on | File(s) |
|---|---|---|---|---|---|---|
| **T23** | **OPERATOR ACTION:** Run `make integrity-check` in FT2 — verify 0 new findings. Pull fitme-story main and verify docs-mirror picks up the change. | post-merge | ops | 0.1h | T22 | — |
| **T24** | Append cadence-followup **B11** to `.claude/shared/must-have-cadence-followups.md`: T+3d UCC hardening calibration window check (2026-05-22). | docs | dev | 0.2h | T22 | `.claude/shared/must-have-cadence-followups.md` |
| **T25** | Create `docs/case-studies/ucc-passkey-auth-security-hardening-case-study.md` placeholder with §99 outcome stub (filled at T+7d / 2026-05-23 kill-criteria checkpoint). | docs | dev | 0.3h | T22 | `docs/case-studies/ucc-passkey-auth-security-hardening-case-study.md` (new) |
| **T26** | **OPERATOR ACTION:** Open Linear sub-issue under FIT-63 (parent `ucc-passkey-auth`) for the hardening enhancement. Link FT2 PR #410 + fitme-story PR (from T22). | docs | ops | 0.1h | T22 | (Linear) |

## Critical Path

```
T1 (refactor) ─┬─→ T8 (redis-lockout) ─┬─→ T9 (auth wire)
               │                       └─→ T10 (register wire)
               └─→ T14 (uaFamily ext)  
               
T2+T3 (enums) ─┬─→ T5 (allowlist wire)
               └─→ T13 (token issued)
               
T4 (allowlist) ─→ T5

ALL CODE TASKS ─→ T18 + T19 (env setup) ─→ T20 (verify) ─→ T22 (merge PR)
                                          ↘ T21 (CI) ↗
T22 ─→ T23, T24, T25, T26 (post-merge)
```

**Earliest critical-path duration (single operator, serial):** T1 (0.3h) → T8 (1.0h) → T9 (0.5h) → T12 (0.8h) → T20 (0.5h) → T22 (0.2h) → T23 (0.1h) = **~3.4h critical path** + parallel work for non-critical tasks.

**Realistic with batching + LLM-assist:** 6–8 hours of focused work. **Fits in one dev-day if started 2026-05-20 morning.**

## Out of Scope (re-stated from spec §9)

Edge-layer rate limiting, per-env lockout tuning, audit-log forwarding to Sentry/Logflare, 2FA, account-recovery flow, cross-env session revocation.

## Approval Gate

This task list awaits operator approval before advancing to **Phase 3 (Implementation)**. On approval, the skill will set `state.json::phases.tasks.status = "approved"`, transition `current_phase → "implementation"`, and append a `phase_approved` event to `.claude/logs/ucc-passkey-auth-security-hardening.log.json`.
