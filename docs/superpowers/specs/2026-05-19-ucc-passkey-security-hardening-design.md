# UCC Passkey Auth Security Hardening — Design Spec — 2026-05-19

> **Status:** DRAFT · Opened 2026-05-19 · Target ship 2026-05-19 → 2026-05-20 (pre-v7.9-freeze)
> **Work type:** Enhancement to shipped feature `ucc-passkey-auth`
> **State.json:** [`.claude/features/ucc-passkey-auth-security-hardening/state.json`](../../../.claude/features/ucc-passkey-auth-security-hardening/state.json)
> **Parent PRD:** [`ucc-passkey-auth/prd.md`](../../../.claude/features/ucc-passkey-auth/prd.md) §7 Q1 + Q2
> **Companion sub-plan:** [`../../master-plan/ucc-passkey-security-hardening-risk-assessment-2026-05-19.md`](../../master-plan/ucc-passkey-security-hardening-risk-assessment-2026-05-19.md)
> **Calendar overlay:** infra master plan [`../../master-plan/infra-master-plan-2026-05-12.md`](../../master-plan/infra-master-plan-2026-05-12.md) — pre-v7.9-freeze window (must merge ≤ 2026-05-20 EOD, before 2026-05-21 promotion decision)

---

## 0. TL;DR

`ucc-passkey-auth` shipped 2026-05-07 and cut over to `UCC_AUTH_MODE=both` on 2026-05-16. Production state at 2026-05-19 (verified via Upstash SCAN): 1 operator, 1 credential, 0 outstanding bootstrap tokens, 0 active sessions. The cutover left four parent-PRD gaps that this enhancement closes:

| Gap | Parent PRD reference | Closed by |
|---|---|---|
| **G1** No code lock against registering a 2nd operator email | §7 Q1 | Email allowlist gate in `/api/auth/register/options` |
| **G2** No env-var allowlist of permitted operator emails | §7 Q1 (implicit) | `UCC_ALLOWED_EMAILS` env var (subsumes G1) |
| **G3** No lockout after N failed authentications | §7 Q2 (deferred to T+7d) | Hybrid per-email (10/15-min) + per-IP (20/30-min) lockout |
| **G4** No audit trail at bootstrap-token *issuance* (only at *consumption*) | not in parent PRD — surfaced by 2026-05-19 audit | New `auth_bootstrap_token_issued` event emitted by `scripts/issue-bootstrap-token.ts` |

**Net delta:** 1 new env var (`UCC_ALLOWED_EMAILS`), 1 new module (`src/lib/auth/redis-lockout.ts`), 1 modified API route, 2 modified verify handlers, 1 modified CLI script, 1 new CLI utility (`scripts/clear-lockout.ts`), 3 new audit event types, 5 new Redis key namespaces. Auth-path latency added: ≤ 2 ms per request (one extra Redis GET).

**Why now:** the 2026-05-23 T+7d kill-criteria checkpoint evaluates whether the cutover was successful. Hardening MUST be live before T+7d so that the checkpoint reflects production posture, not cutover-day posture. The v7.9 promotion freeze 2026-05-21 EOD forces the merge to land by 2026-05-20.

---

## 1. Scope + Relationship to Parent PRD

### 1.1 What this enhancement covers

| Surface | Owned by parent PRD | Owned by this enhancement |
|---|---|---|
| WebAuthn ceremony (registration + authentication) | Yes — `ucc-passkey-auth` | No (no change) |
| Operator + credential storage in Upstash | Yes — `ucc-passkey-auth` | No (no change) |
| Audit log writer (`src/lib/auth/audit-log.ts`) | Yes — `ucc-passkey-auth-audit-log-redis-fix` | No structural change; 3 new event types added to the enum |
| Bootstrap token TTL store | Yes — `ucc-passkey-auth` | No (no change) |
| Session iron-session cookie | Yes — `ucc-passkey-auth` | No (no change) |
| **Email allowlist gate at registration** | No | **Yes** (§3) |
| **Hybrid failure lockout** | Deferred per PRD §7 Q2 | **Yes** (§4) |
| **Bootstrap-token issuance audit event** | No | **Yes** (§5) |
| **Operator clear-lockout CLI** | No | **Yes** (§6) |
| Production env-var rollout sequencing | Operational | **Yes** (§7) |

### 1.2 Why a separate enhancement, not a patch to the parent

The parent feature is closed (`current_phase: complete`). Re-opening it would require a phase-rollback per CLAUDE.md and obscure the chain-of-custody for the hardening work. An enhancement work-type (4-phase: Tasks → Implement → Test → Merge) is the right size for the 4-gap delta, and its own state.json + case study mean the hardening choices are visible in the historical record.

### 1.3 What this enhancement does NOT cover

- **Rate limiting in front of `/api/auth/register/options`** at the edge (Vercel Firewall). Considered, deferred — the bootstrap-token requirement + new allowlist gate already short-circuit attackers without a valid token. Firewall rate limits add edge cost without changing the threat surface.
- **WebAuthn RP-ID rotation.** The current `fitme-story.vercel.app` anchor is correct; rotation is a deploy-time concern outside auth code.
- **Supabase row-level security parity.** UCC auth is independent of Supabase user auth (different system).
- **iOS app passkey support.** This enhancement is UCC-dashboard-only.

---

## 2. Architecture Diagram

```
                    ┌──────────────────────────────────────────────────────┐
                    │                  Vercel function host                │
                    │                                                      │
   POST             │   ┌────────────────────┐  ┌────────────────────┐    │
   /api/auth/   ───►│──►│ register/options   │─►│ AllowlistGate (new)│    │
   register/        │   │  route.ts          │  │ §3.1               │    │
   options          │   └────────────────────┘  └─────────┬──────────┘    │
                    │                                     │  ALLOW         │
                    │   ┌────────────────────┐            ▼                │
                    │   │ consumeBootstrap   │─────► generateRegistration  │
                    │   │ (existing)         │       Options (existing)    │
                    │   └────────────────────┘                             │
                    │                                                      │
                    │   ┌────────────────────┐  ┌────────────────────┐    │
   POST             │   │ authenticate/      │─►│ LockoutGate (new)  │    │
   /api/auth/   ───►│──►│ verify  route.ts   │  │ §4.2               │    │
   authenticate/    │   └─────┬──────────────┘  └─────────┬──────────┘    │
   verify           │         │                            │ NOT_LOCKED    │
                    │         │                            ▼                │
                    │         └────────►  verifyAuthenticationResponse     │
                    │                     (existing)                       │
                    │                                                      │
                    │   ┌────────────────────┐  ┌────────────────────┐    │
                    │   │ register/verify    │─►│ LockoutGate.record │    │
                    │   │ route.ts           │  │ Failure on bad TX  │    │
                    │   └────────────────────┘  └────────────────────┘    │
                    └──────────────────────────────────────────────────────┘

                    Upstash Redis (existing instance, new key namespaces)
                    ┌──────────────────────────────────────────────────────┐
                    │ ucc:operator:<email>                  (existing)     │
                    │ ucc:credential:<id>                   (existing)     │
                    │ ucc:operator:<email>:credentials      (existing)     │
                    │ ucc:bootstrap:<hash>                  (existing)     │
                    │ ucc:session:<sid>                     (existing)     │
                    │ ucc:lockout:email:<email>:fails       (NEW, TTL 900) │
                    │ ucc:lockout:email:<email>:locked      (NEW, TTL 900) │
                    │ ucc:lockout:ip:<class>:fails          (NEW, TTL 1800)│
                    │ ucc:lockout:ip:<class>:locked         (NEW, TTL 1800)│
                    │ ucc:audit-log:events                  (existing)     │
                    └──────────────────────────────────────────────────────┘

                    Local operator machine (CLI)
                    ┌──────────────────────────────────────────────────────┐
                    │ scripts/issue-bootstrap-token.ts                     │
                    │   → writes ucc:bootstrap:<hash>      (existing)      │
                    │   → emits auth_bootstrap_token_issued audit event    │
                    │     to ucc:audit-log:events          (NEW §5)        │
                    │                                                      │
                    │ scripts/clear-lockout.ts             (NEW §6)        │
                    │   → unsets ucc:lockout:* keys for {email,ip}         │
                    │   → emits auth_lockout_cleared audit event           │
                    └──────────────────────────────────────────────────────┘
```

---

## 3. G1 + G2 — Email Allowlist Gate

### 3.1 Module: `src/lib/auth/allowlist.ts` (new)

```ts
// src/lib/auth/allowlist.ts
//
// Email allowlist gate. UCC_ALLOWED_EMAILS env var is the single source
// of truth for "which emails may register an operator credential".
// Fail-closed: if the env var is unset, registration is blocked entirely.

const ENV_VAR = 'UCC_ALLOWED_EMAILS';

function parseAllowlist(): Set<string> {
  const raw = process.env[ENV_VAR];
  if (!raw) return new Set();
  return new Set(
    raw
      .split(',')
      .map((s) => s.trim().toLowerCase())
      .filter((s) => s.length > 0),
  );
}

export function isEmailAllowed(email: string): boolean {
  if (!email) return false;
  return parseAllowlist().has(email.trim().toLowerCase());
}

export function allowlistSize(): number {
  return parseAllowlist().size;
}

export function allowlistIsConfigured(): boolean {
  return allowlistSize() > 0;
}
```

### 3.2 Wiring in `src/app/api/auth/register/options/route.ts`

Inserted between `consumeBootstrap()` and `getOperator()`:

```ts
const consumed = await consumeBootstrap(tokenHash);
if (!consumed) { /* existing bootstrap_invalid branch */ }

// NEW: allowlist gate. Distinguish "unset" (operator misconfigured)
// from "not in list" (potential leaked-token attack) so the calibration
// window §11 can tell the two failure modes apart.
if (!allowlistIsConfigured()) {
  await logAuthEvent({
    event_type: 'auth_passkey_register_failed',
    operator_label: consumed.email,
    reason: 'allowlist_unset',
    outcome: 'error',
  });
  return NextResponse.json({ error: 'allowlist_unset' }, { status: 403 });
}
if (!isEmailAllowed(consumed.email)) {
  await logAuthEvent({
    event_type: 'auth_passkey_register_failed',
    operator_label: consumed.email,
    reason: 'email_not_allowlisted',
    outcome: 'error',
  });
  return NextResponse.json({ error: 'email_not_allowlisted' }, { status: 403 });
}
```

### 3.3 Env-var contract

| Env | Production value (2026-05-19) | Semantics |
|---|---|---|
| `UCC_ALLOWED_EMAILS` | `regvash21@gmail.com` | Comma-separated, case-insensitive, whitespace-trimmed |

**Rollout sequencing** (§7.2): the env var must be set in Vercel BEFORE the code deploys, otherwise the first deploy fails-closed and locks out future registration. Authentication is unaffected (the gate only fires on registration).

### 3.4 Audit-event taxonomy delta

Adds to `AuthEventReason` enum in `src/lib/auth/audit-log.ts`:
- `email_not_allowlisted` — bootstrap token consumed for an email not in the allowlist
- `allowlist_unset` — registration attempted while `UCC_ALLOWED_EMAILS` is empty/unset (fail-closed)

### 3.5 Acceptance criteria for G1 + G2

| Scenario | Expected behavior |
|---|---|
| `UCC_ALLOWED_EMAILS=regvash21@gmail.com`, bootstrap token for `regvash21@gmail.com` | Registration proceeds |
| `UCC_ALLOWED_EMAILS=regvash21@gmail.com`, bootstrap token for `Regvash21@Gmail.com` (mixed case) | Registration proceeds (case-insensitive match) |
| `UCC_ALLOWED_EMAILS=regvash21@gmail.com`, bootstrap token for `evil@attacker.com` | 403 `email_not_allowlisted` + audit event |
| `UCC_ALLOWED_EMAILS` unset, bootstrap token for `regvash21@gmail.com` | 403 `email_not_allowlisted` + audit event (fail-closed; reason emitted is `allowlist_unset` for telemetry separation) |
| `UCC_ALLOWED_EMAILS=` (empty string) | Same as unset |
| `UCC_ALLOWED_EMAILS=" regvash21@gmail.com , other@example.com "` (whitespace + multi) | Both accepted |

---

## 4. G3 — Hybrid Failure Lockout

### 4.1 Module: `src/lib/auth/redis-lockout.ts` (new)

Sliding-window counter + lockout flag in Redis, per-email AND per-IP.

| Key | TTL | Purpose |
|---|---|---|
| `ucc:lockout:email:<lc-email>:fails` | 900s (15m) | Counter, INCR on failure |
| `ucc:lockout:email:<lc-email>:locked` | 900s | Sentinel; presence = locked |
| `ucc:lockout:ip:<ip_class>:fails` | 1800s (30m) | Counter, INCR on failure |
| `ucc:lockout:ip:<ip_class>:locked` | 1800s | Sentinel; presence = locked |

Where `<ip_class>` is the same truncation function the audit log already uses (`ipv4-X.Y.Z.0/24` or `ipv6-XXXX:XXXX:XXXX::/48`).

```ts
// src/lib/auth/redis-lockout.ts (sketch)
import { redis } from './redis-client';
import { logAuthEvent } from './audit-log';
import { ipClassFromRaw } from './audit-log-redactors';  // exported in §4.5

const EMAIL_FAIL_TTL = 900;
const EMAIL_LOCK_THRESHOLD = 10;
const IP_FAIL_TTL = 1800;
const IP_LOCK_THRESHOLD = 20;

interface LockoutCheckResult {
  locked: boolean;
  reason: 'email_locked' | 'ip_locked' | null;
}

export async function checkLockout(
  email: string | null,
  rawIp: string | null,
): Promise<LockoutCheckResult> {
  const emailLc = email?.trim().toLowerCase() ?? null;
  const ipClass = rawIp ? ipClassFromRaw(rawIp) : null;

  // Both checks fire in parallel — Redis MGET would be one round-trip but
  // tedious to type; two GETs is ~2ms.
  const [emailLocked, ipLocked] = await Promise.all([
    emailLc ? redis.get(`ucc:lockout:email:${emailLc}:locked`) : null,
    ipClass ? redis.get(`ucc:lockout:ip:${ipClass}:locked`) : null,
  ]);

  if (emailLocked) return { locked: true, reason: 'email_locked' };
  if (ipLocked) return { locked: true, reason: 'ip_locked' };
  return { locked: false, reason: null };
}

export async function recordFailure(
  email: string | null,
  rawIp: string | null,
): Promise<void> {
  const emailLc = email?.trim().toLowerCase() ?? null;
  const ipClass = rawIp ? ipClassFromRaw(rawIp) : null;

  if (emailLc) {
    const failKey = `ucc:lockout:email:${emailLc}:fails`;
    const fails = await redis.incr(failKey);
    if (fails === 1) await redis.expire(failKey, EMAIL_FAIL_TTL);
    if (fails >= EMAIL_LOCK_THRESHOLD) {
      const lockKey = `ucc:lockout:email:${emailLc}:locked`;
      await redis.set(lockKey, '1', { ex: EMAIL_FAIL_TTL });
      await logAuthEvent({
        event_type: 'auth_lockout_triggered',
        operator_label: emailLc,
        outcome: 'success',
        reason: 'email_threshold',
      });
    }
  }

  if (ipClass) {
    const failKey = `ucc:lockout:ip:${ipClass}:fails`;
    const fails = await redis.incr(failKey);
    if (fails === 1) await redis.expire(failKey, IP_FAIL_TTL);
    if (fails >= IP_LOCK_THRESHOLD) {
      const lockKey = `ucc:lockout:ip:${ipClass}:locked`;
      await redis.set(lockKey, '1', { ex: IP_FAIL_TTL });
      await logAuthEvent({
        event_type: 'auth_lockout_triggered',
        operator_label: emailLc ?? 'unknown',
        outcome: 'success',
        reason: 'ip_threshold',
        ip: rawIp ?? undefined,
      });
    }
  }
}

export async function clearFailures(
  email: string | null,
  rawIp: string | null,
): Promise<void> {
  const emailLc = email?.trim().toLowerCase() ?? null;
  const ipClass = rawIp ? ipClassFromRaw(rawIp) : null;
  const keys: string[] = [];
  if (emailLc) keys.push(
    `ucc:lockout:email:${emailLc}:fails`,
    `ucc:lockout:email:${emailLc}:locked`,
  );
  if (ipClass) keys.push(
    `ucc:lockout:ip:${ipClass}:fails`,
    `ucc:lockout:ip:${ipClass}:locked`,
  );
  if (keys.length > 0) await redis.del(...keys);
}
```

### 4.2 Wiring in `src/app/api/auth/authenticate/verify/route.ts`

```ts
const rawIp = req.headers.get('x-forwarded-for');
const targetEmail = body.email ?? null;

// NEW: lockout check at the TOP of the handler, before any verification work
const lockState = await checkLockout(targetEmail, rawIp);
if (lockState.locked) {
  await logAuthEvent({
    event_type: 'auth_lockout_blocked_attempt',
    operator_label: targetEmail ?? 'conditional',
    outcome: 'error',
    reason: lockState.reason ?? undefined,
    ip: rawIp ?? undefined,
  });
  return NextResponse.json({ error: 'locked_out' }, { status: 429 });
}

// ...existing verification flow...

// On every failure branch (no_pending_challenge, unknown_credential,
// assertion_invalid, counter_replay), call recordFailure() before the
// existing logAuthEvent + return. The credential.ownerEmail is preferred
// over body.email since it's verified; falls back to body.email when no
// credential row exists yet.

// On the success branch (just before mintSession), call clearFailures()
// so a legitimate sign-in resets both counters.
await clearFailures(credential.ownerEmail, rawIp);
```

### 4.3 Wiring in `src/app/api/auth/register/verify/route.ts`

Same pattern — `checkLockout()` at the top (keyed on `body.email`, no credential row exists yet for first registration). Failed verifications increment counters via `recordFailure()`. Successful registration calls `clearFailures()`.

### 4.4 Lockout policy summary

| Dimension | Threshold | Window | Rationale |
|---|---|---|---|
| Per-email | 10 fails | 15 min from first failure | Targeted brute-force defense; 10 is forgiving for fumbled passkey ceremonies (per pre-decision question — you're the only operator, lockout-yourself risk dominates) |
| Per-IP class | 20 fails | 30 min from first failure | Distributed brute-force defense; per-IP threshold higher because a single attacker IP may target multiple emails |
| Lockout sentinel TTL | Equals fail-window TTL | — | Sentinel and counter co-expire so a 16-min-old attack starts fresh |

**Window semantics:** the `EXPIRE` is set on the first `INCR` only (`if (fails === 1) await redis.expire(...)`). This produces a **fixed window** of 15 min (per-email) / 30 min (per-IP) from the *first* failure, NOT a sliding window. Trade-off: a single fixed window is simpler to reason about and clean up; sliding semantics would require resetting EXPIRE on every INCR (a TTL touch per failure) — overkill for our threat model. Successful authentication via `clearFailures()` is what resets the window early.

### 4.5 Refactor: ipClassFromRaw + uaFamilyFromRaw

These helpers currently live as private functions in `src/lib/auth/audit-log.ts:103-119`. The lockout module needs `ipClassFromRaw` for keying. Extract both into `src/lib/auth/audit-log-redactors.ts` and re-export from `audit-log.ts` to preserve existing imports. Pure refactor with no behavioral change.

### 4.6 New audit-event types

Adds to `AuthEventType` enum:
- `auth_lockout_triggered` — counter crossed threshold; lockout set
- `auth_lockout_blocked_attempt` — incoming request rejected because lockout is active
- `auth_lockout_cleared` — operator manually cleared (via CLI) OR sliding window expired naturally

Adds to `AuthEventReason` enum:
- `email_threshold` — per-email counter ≥ 10
- `ip_threshold` — per-IP counter ≥ 20
- `email_locked` — request rejected, per-email lockout active
- `ip_locked` — request rejected, per-IP lockout active
- `manual_clear` — operator ran `scripts/clear-lockout.ts`

### 4.7 Acceptance criteria for G3

| Scenario | Expected behavior |
|---|---|
| 9 sequential failed verifies for `regvash21@gmail.com` from same IP | All 9 increment counter; 10th would lock; 9th still returns the underlying error (not `locked_out`) |
| 10th failed verify | Lockout set; 10th response is the underlying error; the 11th attempt returns 429 `locked_out` |
| Successful verify after 5 failures | `clearFailures()` resets both counters; subsequent failure resets to 1, not 6 |
| 11th attempt during lockout | 429 `locked_out`, audit event `auth_lockout_blocked_attempt` with `reason: email_locked` |
| 15 minutes pass with no new failure | Lockout TTL expires; next attempt is unlocked |
| 19 failures from same /24 across different emails | Counter at 19, not locked |
| 20th failure from same /24 | Per-IP lockout fires; subsequent attempts from that /24 return 429 even for emails that haven't failed |
| Operator runs `scripts/clear-lockout.ts --email regvash21@gmail.com` | Per-email keys deleted; per-IP keys untouched; audit event `auth_lockout_cleared reason:manual_clear` |

---

## 5. G4 — Bootstrap-Token Issuance Audit Event

### 5.1 Current state

The CLI `scripts/issue-bootstrap-token.ts` writes `ucc:bootstrap:<hash>` to Redis and prints the token to stdout. No audit event is recorded. The existing `auth_bootstrap_token_issued` event in the enum is misnamed — it actually fires at *consumption* (registration), not at issuance. This is the only un-audited surface in the auth path.

### 5.2 Changes

1. Rename the existing post-consumption event from `auth_bootstrap_token_issued` to `auth_bootstrap_token_consumed` (more accurate and frees the original name for actual issuance). Sweep call sites in `register/options/route.ts`.
2. Add a NEW issuance event emitted by `scripts/issue-bootstrap-token.ts` after the Redis write succeeds:

```ts
// scripts/issue-bootstrap-token.ts (sketch of added block)
await redis.set(`ucc:bootstrap:${tokenHash}`, JSON.stringify({...}), { ex: 900 });

// NEW: audit the issuance
await logAuthEvent({
  event_type: 'auth_bootstrap_token_issued',
  operator_label: targetEmail,
  outcome: 'success',
  // No credential_id, no session_id (none exists yet)
  // No ip (CLI is operator-local)
  // user_agent_family records the CLI runner identity
  user_agent: `cli/${process.env.USER ?? 'unknown'}@${require('os').hostname()}`,
});
```

3. The CLI script gains a `logAuthEvent` import path (it currently doesn't import from `src/lib/auth/`). Use a direct import — the CLI is TypeScript via `tsx`, so the path resolves at runtime.

**No new env var needed:** the CLI already requires `KV_REST_API_TOKEN` (Redis WRITE) to write `ucc:bootstrap:<hash>`. The same client + same token writes the audit event. No additional credentials.

### 5.3 Privacy considerations

- `user_agent` is redacted to `cli/<user>@<host>` (no full env). The existing UA redactor doesn't have a CLI family — extend `uaFamilyFromRaw` to detect `cli/` prefix and emit family `cli/<user>` (drop hostname for the public blob export).
- `operator_label` carries the raw target email (which is what is being authorized). This matches the existing audit-log behavior for `auth_passkey_register_started`.
- No token material crosses the audit boundary. Only the SHA-256-truncated hash (first 12 chars) is logged via the existing `credential_id_hash` slot, repurposed for `token_hash` in this event.

### 5.4 Acceptance criteria for G4

| Scenario | Expected behavior |
|---|---|
| Operator runs `npx tsx scripts/issue-bootstrap-token.ts regvash21@gmail.com` | Token printed to stdout; `auth_bootstrap_token_issued` event in Redis audit log |
| Stdout output remains the operator-facing copyable token | Yes (no change) |
| Redis write fails (quota / network) | Audit event NOT written (script aborts before the audit-write); existing error handling preserved |
| Redis write succeeds, audit write fails (transient) | Existing `logAuthEvent` swallows the error per its design; token was issued; gap in audit trail logged to stderr |

---

## 6. CLI Utility — `scripts/clear-lockout.ts` (new)

```bash
# Usage
npx tsx scripts/clear-lockout.ts --email regvash21@gmail.com
npx tsx scripts/clear-lockout.ts --ip 1.2.3.0/24
npx tsx scripts/clear-lockout.ts --email regvash21@gmail.com --ip 1.2.3.0/24
```

Reads `KV_REST_API_TOKEN` from env (WRITE token, not read-only). Calls `clearFailures()`. Emits `auth_lockout_cleared` audit event with `reason: manual_clear`. Returns exit 0 on success.

---

## 7. Rollout

### 7.1 Pre-merge

1. Open feature branch in FT2: `feat/ucc-passkey-security-hardening` for spec + sub-plan + state.json + PRD delta + plan
2. Open feature branch in fitme-story: `feat/ucc-passkey-security-hardening` for code + tests + env example + runbook update
3. Add `UCC_ALLOWED_EMAILS=regvash21@gmail.com` to fitme-story `.env.local` (operator's local env)
4. Document the env var in `fitme-story/.env.example`

### 7.2 Env-var sequencing

The deploy gate is fail-closed for registration. Auth (sign-in) is unaffected by `UCC_ALLOWED_EMAILS`. Sequence:

1. Set `UCC_ALLOWED_EMAILS=regvash21@gmail.com` in **Vercel production env** via dashboard or `vercel env add`
2. Verify with `vercel env ls` that the var is present
3. Merge the fitme-story PR
4. Vercel auto-deploys the new code; the gate is now live
5. Curl probe: `POST /api/auth/register/options` with a fake bootstrap token — expect 401 (bootstrap_invalid, not 403 allowlist) — confirms the route still works
6. Sign in with existing passkey to confirm authentication path is unaffected

If step 1 is skipped or has a typo, step 5 returns 403 (`allowlist_unset`) and registration is dead until corrected. Authentication still works — operator is not locked out of UCC.

### 7.3 Post-merge

1. Run `make integrity-check` in FT2 — verify no new findings
2. Append the cadence-followup ledger with B11 ("UCC hardening T+3d calibration window check, 2026-05-22")
3. Open `docs/case-studies/ucc-passkey-auth-security-hardening-case-study.md` with placeholder for §99 outcome (filled at Phase 8/9 closure)
4. Linear: new sub-issue under FIT-63 (`ucc-passkey-auth`) for the hardening enhancement

### 7.4 Rollback

Covered in the companion risk-assessment sub-plan §4. Summary:
- G1+G2: unset `UCC_ALLOWED_EMAILS` in Vercel, redeploy (60s) — restores pre-merge registration behavior
- G3: per-incident, `npx tsx scripts/clear-lockout.ts` clears keys; for whole-feature rollback, revert merge commit
- G4: revert CLI script commit; no production-side rollback needed
- Nuclear: flip `UCC_AUTH_MODE` back to `basic` (existing operational lever from the cutover)

---

## 8. Testing

### 8.1 New unit tests in fitme-story

| File | Cases |
|---|---|
| `src/lib/auth/__tests__/allowlist.test.ts` | 6 — allowlist set + match, case-insensitive, whitespace trim, multi-email, unset = empty Set, `allowlistIsConfigured()` semantics |
| `src/lib/auth/__tests__/redis-lockout.test.ts` | 10 — counter increment, threshold trigger, TTL expiry, lockout block, per-email vs per-IP independence, clearFailures isolation, both-key clear, IPv4 + IPv6 truncation parity |
| `src/app/api/auth/register/options/__tests__/allowlist-gate.test.ts` | 5 — allowed email + valid token → 200; not-allowed → 403; unset env → 403 (allowlist_unset reason distinct); audit event written; case-insensitive |
| `src/app/api/auth/authenticate/verify/__tests__/lockout-gate.test.ts` | 6 — locked email → 429; locked IP → 429 even for new email; failures recorded on bad challenge / bad cred / bad assertion; success clears failures |
| `scripts/__tests__/issue-bootstrap-token-audit.test.ts` | 3 — happy path emits audit event; Redis-write failure aborts before audit; audit-write failure is swallowed |
| `scripts/__tests__/clear-lockout.test.ts` | 4 — --email only; --ip only; --email + --ip; audit event with manual_clear reason |

**Test pattern:** Vitest, mock the Upstash Redis client via `vi.mock('@/lib/auth/redis-client')`. Each test drives the public function or route handler end-to-end via `NextRequest` synthesis.

### 8.2 Manual verification matrix (run pre-merge)

| Scenario | Expected | Run by |
|---|---|---|
| Existing passkey sign-in | Succeeds; session cookie set | Operator |
| Stale bootstrap token from before merge | 401 bootstrap_invalid (single-use already consumed) | Operator |
| New bootstrap token + allowed email | 200 + registration option payload | Operator (do not complete ceremony to avoid creating a 2nd credential during test) |
| New bootstrap token + disallowed email | 403 email_not_allowlisted; audit event present in Redis SCAN | Operator + Redis SCAN |
| 10 deliberately-bad sign-in attempts | 10th locks; 11th returns 429 | Operator |
| `scripts/clear-lockout.ts --email regvash21@gmail.com` | Unlocks; next attempt allowed | Operator |

### 8.3 CI gates

| Gate | Status |
|---|---|
| `pnpm test` | All new tests pass |
| `pnpm lint` | No new violations |
| `pnpm typecheck` | Clean |
| fitme-story `verify` workflow | Green |
| Vercel Preview Deploy | URL reachable (basic-auth on preview, passkey scoped to prod RP-ID) |
| FT2 `make integrity-check` | 0 enforced findings |
| FT2 `make documentation-debt` | No new HIGH/MEDIUM debt |
| FT2 `pr-integrity-check.yml` | Green on FT2 PR |

---

## 9. Out of Scope (explicitly)

| Item | Reason for exclusion |
|---|---|
| Edge-layer rate limiting (Vercel Firewall) | Bootstrap token + allowlist already short-circuit anonymous attackers; firewall adds edge cost without changing threat surface |
| Per-environment lockout tuning (prod vs preview) | Preview deploys can't run passkey auth (RP-ID mismatch); lockout is moot on previews |
| Audit-log forwarding to Sentry / Logflare | Existing `UCC_AUDIT_BLOB_ENDPOINT` extension point covers this; not a blocker for hardening |
| 2FA / multi-factor authentication | Passkey IS the factor; UCC is operator-only, not user-facing |
| Account-recovery flow if operator loses passkey | Existing break-glass path is to re-issue a bootstrap token via CLI (operator has Vercel access) |
| Cross-environment session revocation | UCC has 1 env (prod); preview deploys can't mint sessions |

---

## 10. Open Questions

| ID | Question | Disposition |
|---|---|---|
| OQ-1 | Should the lockout TTL extend on each blocked attempt (compounding lockout)? | NO for v1 — sliding 15-min window is enough deterrent; compounding adds complexity for unclear UX benefit |
| OQ-2 | Should `UCC_ALLOWED_EMAILS` support wildcard domain (e.g. `*@regvash.com`)? | NO for v1 — explicit allowlist is intentional; revisit when adding a 2nd operator |
| OQ-3 | Should we add a `/api/auth/lockout-status` debug endpoint? | NO — operator can check via Redis SCAN; debug endpoint widens attack surface for no operational benefit |
| OQ-4 | Should `auth_lockout_blocked_attempt` events be elevated to `framework-status-weekly.yml` for trend tracking? | YES — add to the weekly digest in a follow-up PR; out-of-scope for the hardening merge itself |
| OQ-5 | IPv6 /48 truncation may merge mobile-carrier users into one class. Acceptable noise floor? | YES for v1 — UCC traffic volume is operator-only (you), so noise is theoretical. Re-evaluate at 2026-08-19 quarterly review |

---

## 11. Calibration Window + T+7d Checkpoint

Per the calibration protocol added to infra master plan §3.5 (2026-05-12), every new layer of framework infrastructure requires a documented pre-build calibration window where telemetry from the prior layer proves it fires correctly under load. This enhancement is **product** code, not framework infra, but the protocol's spirit applies.

**Calibration window:** 2026-05-20 (merge day) → 2026-05-23 (T+7d kill-criteria checkpoint).

**Signals to monitor:**

| Signal | Interpretation |
|---|---|
| `auth_lockout_triggered` events per day | Should be 0 in steady state (you're the only operator and don't fumble) |
| `auth_lockout_blocked_attempt` events per day | Should be 0 in steady state; > 0 = either attacker scanning OR false positive on you |
| `auth_passkey_register_failed reason:email_not_allowlisted` events | Should be 0 in steady state; > 0 = either bootstrap token leakage attempt OR misconfigured allowlist |
| Successful sign-in latency p50 | Should not increase by > 5 ms vs pre-hardening baseline (one extra Redis GET) |
| Redis quota usage | Should stay within free tier — new key namespaces are short-TTL'd |

**T+7d gate (2026-05-23):**
- If `auth_lockout_blocked_attempt` count for the operator's own IP class > 0 → FALSE POSITIVE → tune `EMAIL_LOCK_THRESHOLD` up
- If any `email_not_allowlisted` events for `regvash21@gmail.com` → MISCONFIGURATION → check env var
- If sign-in latency increase > 5 ms p50 → INVESTIGATE Redis round-trip overhead
- Otherwise → PROMOTE to "hardening verified" in case study §99

---

## 12. References

- Parent feature: [`.claude/features/ucc-passkey-auth/`](../../../.claude/features/ucc-passkey-auth/)
- Sibling enhancement: [`.claude/features/ucc-passkey-auth-audit-log-redis-fix/`](../../../.claude/features/ucc-passkey-auth-audit-log-redis-fix/)
- Parent PRD: [`.claude/features/ucc-passkey-auth/prd.md`](../../../.claude/features/ucc-passkey-auth/prd.md) §7 Q1 + Q2
- Cutover case study: [`docs/case-studies/ucc-passkey-auth-case-study.md`](../../case-studies/ucc-passkey-auth-case-study.md)
- Going-live runbook: [`docs/setup/ucc-passkey-auth-setup-guide.md`](../../setup/ucc-passkey-auth-setup-guide.md)
- Infra master plan: [`docs/master-plan/infra-master-plan-2026-05-12.md`](../../master-plan/infra-master-plan-2026-05-12.md)
- Companion risk-assessment sub-plan: [`docs/master-plan/ucc-passkey-security-hardening-risk-assessment-2026-05-19.md`](../../master-plan/ucc-passkey-security-hardening-risk-assessment-2026-05-19.md)

---

## 13. Change Log

| Date | Change | Author |
|---|---|---|
| 2026-05-19 | Initial draft | Claude (regvash21@gmail.com session) |
