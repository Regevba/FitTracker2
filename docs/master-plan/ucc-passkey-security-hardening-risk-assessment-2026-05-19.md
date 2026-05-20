# UCC Passkey Auth Security Hardening — Risk Assessment & Rollback Plan — 2026-05-19

> **Status:** DRAFT · Opened 2026-05-19 as a sub-plan of [`infra-master-plan-2026-05-12.md`](infra-master-plan-2026-05-12.md) and a companion to [`../superpowers/specs/2026-05-19-ucc-passkey-security-hardening-design.md`](../superpowers/specs/2026-05-19-ucc-passkey-security-hardening-design.md)
> **Scope:** Operational doc — threat model, blast radius, rollback procedures, calibration window for the four hardening changes (G1+G2 email allowlist gate, G3 hybrid failure lockout, G4 bootstrap-token issuance audit event).
> **Purpose:** Answer two questions the design spec does not answer in operational terms:
> (1) "What goes wrong if each gap-closer mis-fires? How would we know?" — the *threat-model + observability* part.
> (2) "When something does go wrong, how exactly do we restore?" — the *rollback procedures* part.
> **Parent docs:**
> [`infra-master-plan-2026-05-12.md`](infra-master-plan-2026-05-12.md) §5 calendar + §7 risk register ·
> [`data-integrity-and-rollback-2026-05-14.md`](data-integrity-and-rollback-2026-05-14.md) (template — this plan mirrors its structure for security)
> **Anchor baseline:** Upstash production SCAN at 2026-05-19T14:00Z — 1 operator (`regvash21@gmail.com`), 1 credential, 0 outstanding bootstrap tokens, 0 active sessions. Recorded in §3.4.

---

## 0. TL;DR

The UCC passkey auth system is currently protected by 2 controls — bootstrap token + WebAuthn RP-ID anchor. The hardening adds 4 more — fail-closed allowlist gate, per-email lockout, per-IP lockout, issuance audit trail. The blast radius of each is bounded: every change has a single env-var or CLI lever that reverses it in ≤ 60 s. Authentication is *unaffected* by 3 of the 4 changes (allowlist + lockout-clear-on-success + audit), so the worst-case "I shipped a bug" outcome cannot lock the operator out of the dashboard — only registration is gated.

**Operational consequence:** the v7.9 promotion freeze (2026-05-21 EOD) gains an additional pre-decision risk surface, but the surface is small, the levers are well-defined, and the 2026-05-23 T+7d kill-criteria checkpoint is the natural verification point. The 3-day calibration window between merge (≤ 2026-05-20) and T+7d (2026-05-23) is the documented holding pattern for "no false positives" verification.

---

## 1. Scope + Relationship to Infra Master Plan

### 1.1 What this plan covers

| Surface | This plan owns? | Owned by |
|---|---|---|
| WebAuthn ceremony hardening | No | [`spec §3, §4`](../superpowers/specs/2026-05-19-ucc-passkey-security-hardening-design.md) |
| Code design (modules, route wiring) | No | spec §3 + §4 + §5 + §6 |
| Test surface | No | spec §8 |
| **Threat model — which attacks each gate defends** | **Yes** (§2) | This plan |
| **Blast radius per gap-closer** | **Yes** (§3) | This plan |
| **Continuous observability — what locked state looks like in production** | **Yes** (§3.4 + §3.5) | This plan |
| **Rollback decision criteria + step-by-step procedures** | **Yes** (§4) | This plan |
| **Post-rollback verification probes** | **Yes** (§4.5) | This plan |
| **Calibration window protocol** | **Yes** (§5) | This plan |
| **T+7d kill-criteria checkpoint criteria** | **Yes** (§5.3) | This plan |
| v7.9 promotion freeze coordination | No (referenced) | [`infra-master-plan-2026-05-12.md`](infra-master-plan-2026-05-12.md) §2 |
| Existing UCC cutover follow-ups (B8 T+7d, B9 Part 8) | No (referenced) | [`.claude/shared/must-have-cadence-followups.md`](../../.claude/shared/must-have-cadence-followups.md) |

### 1.2 Why a separate sub-plan, not a section in the design spec

The design spec is *forward-looking* — it describes the system as it will exist after the merge. This plan is *operational* — it describes the system as it runs in production, what can go wrong, and how to respond when it does. The two have different shelf lives: the spec is frozen at merge time; this plan is updated whenever a calibration signal changes or a rollback is exercised.

This mirrors the relationship between the v7.8.1 branch-isolation spec and the data-integrity-and-rollback-2026-05-14 sub-plan (which translates the framework's gate inventory into a continuous integrity contract + rollback procedures). Same pattern, different domain.

### 1.3 What this plan does NOT cover

- **Application-layer security beyond UCC.** Supabase RLS, iOS keychain, FT2 ledger crypto — out of scope.
- **Pure DDoS or volumetric attacks against the Vercel edge.** Handled by Vercel Firewall + auto-DDoS mitigation, not this layer.
- **Insider threats from operators with Vercel project access.** Mitigation is operational (2FA on the Vercel account, scoped tokens), not in-app.
- **Account-recovery flow** if the operator loses both passkey and YubiKey simultaneously. Existing break-glass is to re-issue a bootstrap token via CLI (requires `KV_REST_API_TOKEN` and `UCC_BOOTSTRAP_ADMIN_TOKEN`, both of which the operator has via `.env.local`).

---

## 2. Threat Model

### 2.1 Attacker capability matrix

| Attacker class | Can they...? | This plan's coverage |
|---|---|---|
| **Public unauth network attacker** (knows the URL, no credentials) | Hit `/api/auth/register/options` and `/api/auth/authenticate/*` endpoints | Yes — bootstrap-token requirement + new allowlist gate + lockout |
| **Phishing-redirect attacker** | Trick operator into completing a WebAuthn ceremony on a fake domain | Yes — existing WebAuthn RP-ID anchor (`fitme-story.vercel.app`) defeats this; out of scope for hardening |
| **Bootstrap-token-leak attacker** | Obtain `UCC_BOOTSTRAP_ADMIN_TOKEN` via leaked `.env`, exposed CI log, or stolen laptop | **Partial** — they can mint a bootstrap token, but the allowlist (§3) blocks registration unless their target email is in the env-var allowlist |
| **Operator-machine compromise** | Read `KV_REST_API_TOKEN` + `UCC_BOOTSTRAP_ADMIN_TOKEN` + edit Vercel env vars | No — full operator compromise is out of scope; mitigation is OS hygiene + 2FA on Vercel |
| **Brute-force script** (no token) | Cycle bad bootstrap tokens or bad WebAuthn assertions | Yes — lockout fires at 10 email-fails or 20 IP-fails |
| **Distributed brute-force** (no token, many IPs) | Same as above but rotates IP per attempt | Partial — per-email lockout fires even with rotating IPs; per-IP lockout per /24 catches non-rotating attackers |
| **Vercel-internal misconfiguration** | Operator (you) sets `UCC_ALLOWED_EMAILS` to wrong value | Yes — fail-closed semantics (§3.4); legitimate sign-in still works; only registration is blocked |
| **Upstash Redis outage** | Read/write Redis fails | Partial — registration becomes impossible (allowlist read fails closed by design); authentication may also fail because Redis stores credentials. Acceptable since UCC's other data lives in same Redis (single SPOF) |

### 2.2 Per-gap attack mapping

| Gap-closer | Primary defense against | Secondary effect |
|---|---|---|
| **G1 + G2 allowlist gate** | Bootstrap-token-leak attacker registering a 2nd operator email | Defense-in-depth against accidental misconfig (fail-closed = nothing registers without explicit env opt-in) |
| **G3 per-email lockout** | Targeted brute-force on `regvash21@gmail.com` | Caps the rate at which a leaked-token-holder can spam registration |
| **G3 per-IP lockout** | Distributed brute-force across many emails from one /24 | Protects against scanners hitting both register + authenticate paths |
| **G4 issuance audit** | Forensic detection of bootstrap-token leakage | Enables "did anyone else issue a token while I was away?" analysis from Redis audit log |

### 2.3 Attacks explicitly NOT defended

| Attack | Why out of scope |
|---|---|
| XSS-stolen session cookie | UCC has no user-generated content; CSP is strict; `httpOnly+secure+sameSite=strict` session cookie |
| Subdomain takeover of `fitme-story.vercel.app` | Vercel-internal control plane is operator's domain ownership |
| RP-ID origin spoofing via UA bug | WebAuthn ceremony binds RP-ID at attestation; reproducing this would require an OS-level CA compromise |
| Replay of valid passkey signature | CAS counter check in `redis-store.ts::updateCounterCAS()` rejects replays |
| `--no-verify` git-bypass introducing a vulnerable gate | Out of scope for product code; framework gates handle this for framework code (cycle-time `FEATURE_CLOSURE_COMPLETENESS` mirror) |
| Compromise of the WebAuthn library (`@simplewebauthn/server`) | Supply-chain mitigation: weekly `dependency-audit-weekly.yml` cron + pinned versions |

---

## 3. Blast Radius + Continuous Observability

### 3.1 G1 + G2 blast radius

**What breaks:** if the allowlist gate has a bug or the env var is misconfigured, the system *fails closed* — no registration is allowed. Existing operators (you) can still sign in with their existing passkey because authentication does not consult the allowlist.

**Worst-case operator impact:** registration is unavailable until env-var or code fix lands. Operator can still sign in, manage Redis state via CLI, and operate the dashboard.

**Bounded by:** the gate only fires AFTER `consumeBootstrap()` returns a valid email. A bootstrap token that doesn't exist still 401s at the same point as before — no new failure mode for the anonymous attacker.

**Reversibility:** unset `UCC_ALLOWED_EMAILS` in Vercel + revert merge commit + redeploy. ~60 s.

### 3.2 G3 blast radius

**What breaks:** if the lockout module mis-counts or doesn't clear on success, the operator can lock themselves out of authentication for up to 15 min (email) or 30 min (IP).

**Worst-case operator impact:** 15-30 min of no UCC sign-in. Operator can clear via `scripts/clear-lockout.ts` (requires `KV_REST_API_TOKEN` which they have locally) → unlock in seconds.

**Bounded by:** thresholds chosen for the single-operator case (10 fails is generous; passkey ceremony failures usually surface immediately as biometric/UI errors, not as 5+ consecutive submits). The lockout does NOT affect anyone else because there is no anyone else.

**Reversibility:** `npx tsx scripts/clear-lockout.ts --email regvash21@gmail.com` clears in 1 Redis round-trip. For systemic rollback, revert merge commit. ~60 s either way.

### 3.3 G4 blast radius

**What breaks:** if the issuance audit-write fails, the bootstrap token is still issued (existing behavior) but the audit trail has a gap.

**Worst-case operator impact:** zero immediate operational impact. The token still works for registration; only the forensic record is incomplete.

**Bounded by:** `logAuthEvent` already swallows errors per its design (see `audit-log.ts:128-133`) — auth must not fail because of audit delivery. The new issuance event inherits this contract.

**Reversibility:** revert the script change. The script is operator-local; no deploy needed. ~10 s.

### 3.4 Continuous observability — what locked state looks like in Redis

**Anchor baseline (2026-05-19T14:00Z, pre-hardening):**

```
ucc:operator:*                        → 2 keys (regvash21@gmail.com + index)
ucc:credential:*                      → 1 key
ucc:bootstrap:*                       → 0 keys
ucc:session:*                         → 0 keys
ucc:lockout:*                         → does not exist yet
```

**Post-hardening, steady-state target:**

```
ucc:operator:*                        → 2 keys (unchanged)
ucc:credential:*                      → 1 key (or 2 if YubiKey added per Part 7)
ucc:bootstrap:*                       → 0 keys outside an active issuance ceremony
ucc:session:*                         → 0-1 key (whether you're signed in)
ucc:lockout:email:*:fails             → 0 keys (no failures)
ucc:lockout:email:*:locked            → 0 keys (no lockouts)
ucc:lockout:ip:*:fails                → 0 keys (no failures)
ucc:lockout:ip:*:locked               → 0 keys (no lockouts)
```

**Verification command (operator):**

```bash
set -a && source .env.local && set +a && \
  AUTH="Authorization: Bearer ${KV_REST_API_READ_ONLY_TOKEN}" && \
  for prefix in operator credential bootstrap session lockout; do \
    count=$(curl -s "${KV_REST_API_URL}/scan/0/match/ucc:${prefix}:*/count/100" \
      -H "$AUTH" | jq -r '.result[1] | length'); \
    echo "ucc:${prefix}:* → $count keys"; \
  done
```

### 3.5 Continuous observability — audit-event tail

The audit log is the primary forensic surface. Operator can read the last 50 events via the dashboard at `/control-room/settings/audit`. For a Redis-direct read:

```bash
set -a && source .env.local && set +a && \
  curl -s "${KV_REST_API_URL}/lrange/ucc:audit-log:events/0/49" \
    -H "Authorization: Bearer ${KV_REST_API_READ_ONLY_TOKEN}" | \
    jq -r '.result[] | fromjson | "\(.timestamp)  \(.event_type)  \(.outcome)  \(.reason // "")"'
```

**Suspicious patterns to flag:**

| Pattern | Likely cause | Action |
|---|---|---|
| `email_not_allowlisted` events for unfamiliar emails | Bootstrap-token leak attempt; attacker has token but wrong email | Rotate `UCC_BOOTSTRAP_ADMIN_TOKEN`; check Vercel env audit log |
| `allowlist_unset` events | Misconfiguration; env var rolled back | Re-add env var in Vercel + redeploy |
| `auth_lockout_triggered` for `regvash21@gmail.com` | Brute-force on your email OR you fumbled 10+ times | Check IP class of failures; if foreign IP, treat as attack |
| `auth_lockout_blocked_attempt reason:ip_locked` from your IP | False positive — you really did fumble 20+ times | Manual `clear-lockout.ts`; consider raising threshold |
| `auth_bootstrap_token_issued` events from unfamiliar CLI runner | Bootstrap CLI access leaked | Rotate `KV_REST_API_TOKEN` immediately |
| Audit-event gap >1 hour during active session | Redis or audit-write outage | Check Upstash status page |

---

## 4. Rollback Procedures

### 4.1 Decision matrix — when to roll back

| Symptom | Most-likely cause | Action | Time |
|---|---|---|---|
| Legitimate operator (you) cannot register a new credential (e.g. YubiKey for Part 7) | Allowlist misconfig; your email not in `UCC_ALLOWED_EMAILS` | §4.2 — fix env var, no code change | 60 s |
| You cannot sign in after recent failures | Per-email lockout active | §4.3 — `clear-lockout.ts` | 10 s |
| Allowlist gate throws 500 on every register attempt | Bug in `allowlist.ts` | §4.4 — unset env var (fail-closed disables the gate) OR revert | 60 s |
| Lockout module throws 500 on every auth attempt | Bug in `redis-lockout.ts` | §4.5 — revert merge commit (auth is critical, no env-var bypass exists) | 5 min |
| Audit event writes block bootstrap issuance | Bug in `issue-bootstrap-token.ts` audit hook | §4.6 — revert the script commit | 10 s |
| Nothing works at all | Catastrophic Redis outage OR broader Vercel issue | §4.7 — flip `UCC_AUTH_MODE=basic`, restore legacy auth | 60 s |

### 4.2 Allowlist misconfiguration recovery

Symptom: `auth_passkey_register_failed reason:email_not_allowlisted` event for an email you DID expect to allow.

```bash
# 1. Check current Vercel env
vercel env ls production | grep UCC_ALLOWED_EMAILS

# 2. Update via dashboard or CLI
vercel env rm UCC_ALLOWED_EMAILS production
echo "regvash21@gmail.com,new-operator@example.com" | vercel env add UCC_ALLOWED_EMAILS production

# 3. Redeploy (or wait for next push — env-only changes need a redeploy)
vercel deploy --prod

# 4. Retry registration
```

Total: 60 s + Vercel build time (~2 min for fitme-story). Authentication is unaffected throughout.

### 4.3 Per-email lockout recovery (operator self-unlock)

Symptom: you can't sign in; Redis SCAN shows `ucc:lockout:email:regvash21@gmail.com:locked` exists.

```bash
cd /Volumes/DevSSD/fitme-story
npx tsx scripts/clear-lockout.ts --email regvash21@gmail.com
# Audit event auth_lockout_cleared reason:manual_clear emitted
```

Total: <10 s. Retry sign-in immediately afterward.

If `clear-lockout.ts` itself is broken, direct Redis DEL:

```bash
set -a && source .env.local && set +a && \
  curl -s -X DELETE "${KV_REST_API_URL}/del/ucc:lockout:email:regvash21@gmail.com:locked" \
    -H "Authorization: Bearer ${KV_REST_API_TOKEN}"
```

### 4.4 Allowlist gate bug recovery (disable gate without code revert)

Fail-closed semantics mean unsetting the env var blocks ALL registration. To temporarily DISABLE the gate while keeping registration open for a known-good email (e.g., to register a YubiKey while debugging the gate code), there is no env-var-only bypass — the gate is unconditional.

If the gate is broken and you need to register urgently:

```bash
# Revert the fitme-story PR (atomic; restores pre-merge register/options/route.ts)
cd /Volumes/DevSSD/fitme-story
gh pr view <hardening-PR> --json mergeCommit | jq -r '.mergeCommit.oid' | xargs gh pr revert
# Or, if more urgent, revert locally + push:
git revert <merge-sha> --no-edit && git push origin main
```

Vercel auto-deploys the revert. Registration restored to pre-hardening (bootstrap-token-only) state in ~2 min.

### 4.5 Lockout module bug recovery (critical — affects authentication)

Authentication is the critical path. If `redis-lockout.ts` throws on every request, the operator is locked out of UCC entirely (no env-var bypass; the `checkLockout` call is unconditional in `authenticate/verify`).

Action: revert the merge commit immediately.

```bash
cd /Volumes/DevSSD/fitme-story
git revert <merge-sha> --no-edit
git push origin main
```

Vercel auto-deploys the revert. Authentication restored in ~2 min.

**Mitigation built into the code:** `checkLockout()` returns `{locked: false}` on any internal error (uncaught Redis throw is caught at the gate level + treated as not-locked). This is a deliberate fail-open for authentication so that a Redis hiccup doesn't lock the operator out. Documented in `redis-lockout.ts` module header.

### 4.6 CLI audit-event bug recovery

The CLI is operator-local. A bug there doesn't reach production until next bootstrap token issuance.

```bash
cd /Volumes/DevSSD/fitme-story
git revert <cli-commit-sha>
# No push needed — CLI is local; no deploy involved
```

### 4.7 Nuclear option — flip `UCC_AUTH_MODE=basic`

Existing operational lever from the 2026-05-16 cutover. Restores legacy basic-auth (DASHBOARD_USER / DASHBOARD_PASS) as the sole UCC gate. Passkey path is effectively disabled.

```bash
vercel env rm UCC_AUTH_MODE production
echo "basic" | vercel env add UCC_AUTH_MODE production
vercel deploy --prod
```

Total: 60 s + build time. This is the same lever the cutover plan reserves for the T+7d kill-criteria-violated rollback. Using it here would also revert the cutover, so reserve for catastrophic-only scenarios.

### 4.5.1 Post-rollback verification probes

After any rollback above, run all four probes:

```bash
# 1. Auth path still works
curl -i https://fitme-story.vercel.app/control-room/sign-in
# Expect 200 with HTML containing the passkey sign-in UI

# 2. Anonymous register attempt still rejected
curl -i -X POST https://fitme-story.vercel.app/api/auth/register/options \
  -H 'Content-Type: application/json' \
  -d '{"bootstrapToken":"fake"}'
# Expect 401 bootstrap_invalid

# 3. Redis state is consistent
set -a && source .env.local && set +a && \
  curl -s "${KV_REST_API_URL}/scan/0/match/ucc:lockout:*/count/100" \
    -H "Authorization: Bearer ${KV_REST_API_READ_ONLY_TOKEN}" | jq '.result'
# Expect ["0", []] if no active lockouts

# 4. Operator sign-in works end-to-end
# Manual: visit /control-room/sign-in, complete passkey ceremony, verify session cookie
```

All four green = rollback successful.

---

## 5. Operational Calendar + Calibration Window

### 5.1 Ship-day calendar

| Date | Event | Owner |
|---|---|---|
| 2026-05-19 (today) | Spec + sub-plan + delta-PRD + state.json scaffold | Claude session |
| 2026-05-19 evening | Implementation: allowlist gate + lockout module + audit wiring + CLI + tests | Claude session |
| 2026-05-20 morning | PR review + manual verification matrix (spec §8.2) | Operator |
| 2026-05-20 afternoon | Merge FT2 PR (docs) → merge fitme-story PR (code) → verify Vercel deploy | Operator |
| 2026-05-20 EOD | `UCC_ALLOWED_EMAILS` env var set in Vercel; curl probes (§4.5.1) confirm | Operator |
| 2026-05-21 EOD | **v7.9 promotion freeze** — no further changes until 2026-05-22 | Framework |
| 2026-05-22 | v7.9 promotion executed OR deferred | Framework |
| 2026-05-23 | **T+7d kill-criteria checkpoint** for UCC passkey auth — this hardening's effects evaluated alongside cutover effects | Operator |
| 2026-05-28 | Latest acceptable date for Part 7 YubiKey enrollment (allowlist + lockout must accommodate) | Operator |

### 5.2 Calibration window (2026-05-20 → 2026-05-23, 3 days)

**Signals monitored:**

| Signal | Source | Healthy range | Action if outside range |
|---|---|---|---|
| `auth_lockout_triggered` per day | Redis audit log | 0 | Investigate; could be attack OR false positive on fumbled ceremony |
| `auth_lockout_blocked_attempt` per day | Redis audit log | 0 | Same as above |
| `email_not_allowlisted` events | Redis audit log | 0 | Either attack OR misconfigured Vercel env |
| `allowlist_unset` events | Redis audit log | 0 | Misconfiguration; restore env var immediately |
| Successful sign-in latency p50 | Vercel logs | +0-5 ms vs pre-hardening | Investigate Redis round-trip overhead |
| Successful sign-in latency p95 | Vercel logs | +0-15 ms vs pre-hardening | Same as above |
| Upstash Redis quota usage | Upstash dashboard | within free-tier limits | Optimize key namespace or upgrade |
| Audit-log volume | Redis LLEN ucc:audit-log:events | grows linearly with sign-ins, not exponentially | Look for runaway log loops |

### 5.3 T+7d kill-criteria checkpoint (2026-05-23)

This hardening adds 4 sub-criteria to the existing T+7d gate (which already evaluates the cutover):

| Sub-criterion | Pass | Investigate | Fail |
|---|---|---|---|
| Operator-IP lockout false-positive rate | 0 over 3 days | 1-2 over 3 days | ≥ 3 over 3 days → raise threshold |
| `email_not_allowlisted` events | 0 over 3 days | 1-2 over 3 days | ≥ 3 from non-operator emails → investigate bootstrap-token leak |
| Sign-in latency p50 increase | ≤ +5 ms | +5-15 ms | > +15 ms → investigate |
| Audit-log gap during active session | 0 gaps > 1h | 1 gap | > 1 gap → Redis health investigation |

**If all four pass:** mark hardening "verified in production" in case study §99 + close the feature.

**If any fail:** triage:
- Lockout false positive → tune threshold up (10 → 15 or 20); ship as v0.2 patch
- `email_not_allowlisted` from attacker → confirm `UCC_BOOTSTRAP_ADMIN_TOKEN` rotation; tighten Vercel env access
- Latency overhead → profile Redis client; consider pipelining
- Audit-log gap → investigate Redis client error handling + retry policy

### 5.4 Part 7 break-glass YubiKey compatibility check (≤ 2026-05-28)

Part 7 of the cutover plan registers a YubiKey for `regvash21@gmail.com` as break-glass. The hardening MUST not block this.

Compatibility:
- Allowlist: `regvash21@gmail.com` is in `UCC_ALLOWED_EMAILS` → gate passes ✓
- Lockout: registration is a fresh credential for an existing operator → no failed-auth events expected → no lockout ✓
- Audit: bootstrap-token issuance audit event will fire for the YubiKey provisioning → operator-visible forensic record ✓

Pre-flight check (run before YubiKey ceremony):
```bash
# Verify env var is set correctly
vercel env ls production | grep UCC_ALLOWED_EMAILS
# Verify no active lockout
set -a && source .env.local && set +a && \
  curl -s "${KV_REST_API_URL}/scan/0/match/ucc:lockout:email:regvash21@gmail.com:*/count/10" \
    -H "Authorization: Bearer ${KV_REST_API_READ_ONLY_TOKEN}" | jq '.result[1]'
# Expect []
```

### 5.5 Re-evaluation cadence

| Trigger | Date | Action |
|---|---|---|
| Steady-state annual review | 2027-05-19 | Reassess thresholds vs accumulated audit-log data |
| Earlier re-evaluation | If any §5.3 fail | Tune + ship patch |
| Earlier re-evaluation | If 2nd operator onboarded | Re-evaluate allowlist semantics + lockout fairness |
| Earlier re-evaluation | If `UCC_AUTH_MODE` ever flipped to `passkey` (Part 8, ≥ 2026-05-28) | Tighten lockout thresholds (no basic-auth fallback) |

---

## 6. Open Questions (operational)

| ID | Question | Disposition |
|---|---|---|
| OQ-1 | Should lockout state be visible on `/control-room/framework` panel? | YES — add to follow-up backlog as P2 polish; not blocking the merge |
| OQ-2 | Should `clear-lockout.ts` require interactive confirmation for production runs? | NO — operator already has shell access to the Redis token; confirmation adds friction without changing trust boundary |
| OQ-3 | Daily checkpoint script (`scripts/daily-integrity-checkpoint.py`) — should it check UCC Redis health? | YES — add UCC SCAN as a follow-up checkpoint; coordinate with v7.8.6 cadence pattern; not blocking the merge |
| OQ-4 | Linear epic mirroring — should this enhancement get its own FIT-XXX issue or sub-issue under FIT-63? | Sub-issue under FIT-63 (`ucc-passkey-auth`); matches the pattern used by `ucc-passkey-auth-audit-log-redis-fix` |
| OQ-5 | Should weekly framework-status-weekly.yml include UCC audit-event volume? | DEFERRED — answer at the 2026-08-19 quarterly review when 3 months of data exists |

---

## 7. References

- Design spec: [`../superpowers/specs/2026-05-19-ucc-passkey-security-hardening-design.md`](../superpowers/specs/2026-05-19-ucc-passkey-security-hardening-design.md)
- Parent infra master plan: [`infra-master-plan-2026-05-12.md`](infra-master-plan-2026-05-12.md)
- Template / structural model: [`data-integrity-and-rollback-2026-05-14.md`](data-integrity-and-rollback-2026-05-14.md)
- Parent feature PRD: [`../../.claude/features/ucc-passkey-auth/prd.md`](../../.claude/features/ucc-passkey-auth/prd.md)
- Cutover case study: [`../case-studies/ucc-passkey-auth-case-study.md`](../case-studies/ucc-passkey-auth-case-study.md)
- Going-live runbook: [`../setup/ucc-passkey-auth-setup-guide.md`](../setup/ucc-passkey-auth-setup-guide.md)
- Cadence-followups ledger: [`../../.claude/shared/must-have-cadence-followups.md`](../../.claude/shared/must-have-cadence-followups.md)

---

## 8. Change Log

| Date | Change | Author |
|---|---|---|
| 2026-05-19 | Initial draft | Claude (regvash21@gmail.com session) |
