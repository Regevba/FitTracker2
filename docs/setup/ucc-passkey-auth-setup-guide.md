# UCC Passkey Auth — Setup Guide

> Going-live runbook for the `ucc-passkey-auth` feature shipped 2026-05-07.
> Estimated time: ~30 min if storage infrastructure is ready, ~60-90 min from scratch.

> **Status note (`2026-05-07`):** the feature ships in production at `UCC_AUTH_MODE=basic` (legacy basic-auth preserved). All code is live behind the env var. This guide flips the dashboard at [`fitme-story.vercel.app/control-room/*`](https://fitme-story.vercel.app/control-room/) from shared HTTP basic-auth to per-operator WebAuthn passkeys. Reversible at every step via single env-var change.

---

## Prerequisites

- Vercel CLI installed (`npm i -g vercel`)
- `gh` CLI installed + authenticated (for the FT2 GHA setup in Step 9)
- Access to the **fitme-story** Vercel project (Owner or Admin)
- Access to the **Regevba/FitTracker2** + **Regevba/fitme-story** GitHub repos
- A device with a platform authenticator (Touch ID, Face ID, Windows Hello) AND access to a YubiKey for break-glass registration
- Source case study for context: [`docs/case-studies/ucc-passkey-auth-case-study.md`](../case-studies/ucc-passkey-auth-case-study.md)
- PRD with success metrics + kill criteria: [`.claude/features/ucc-passkey-auth/prd.md`](../../.claude/features/ucc-passkey-auth/prd.md)

---

## Architecture (one-paragraph context)

Every `/control-room/*` request flows through `fitme-story/src/proxy.ts`. Behavior is controlled by the `UCC_AUTH_MODE` env var:

- `basic` (current default) — existing HTTP basic-auth, no behavior change
- `both` (cutover window) — accept either basic-auth OR a passkey session cookie
- `passkey` (steady state) — only accept iron-session cookies; redirect to `/control-room/sign-in` on miss

Passkeys live in Upstash Redis (Vercel Marketplace). Sessions are signed cookies (`iron-session`, 24h hard cap, 12h sliding refresh). Audit log writes go to the function host's `.local/ucc-auth-events.jsonl`, get uploaded daily to a Vercel Blob via Vercel Cron, and a daily FT2 GitHub Actions workflow pulls the Blob into [`.claude/logs/ucc-auth-events.jsonl`](../../.claude/logs/) — surfaced on the framework-health page at `/control-room/framework`.

---

## Part 1: Provision storage (one-time)

### Step 1.1: Upstash Redis

```bash
cd /Volumes/DevSSD/fitme-story
vercel integration add upstash
```

Pick the **fitme-story** project. This auto-injects `UPSTASH_REDIS_REST_URL` + `UPSTASH_REDIS_REST_TOKEN` into the project's env (Production + Preview + Development).

**Verify:**

```bash
vercel env ls | grep UPSTASH
```

Both vars should be present in all three environments.

### Step 1.2: Vercel Blob

In the Vercel dashboard for the fitme-story project: **Storage** → **Create Database** → **Blob**. Name it `ucc-audit-log` (or anything descriptive). Save.

Vercel injects `BLOB_READ_WRITE_TOKEN`. The cron route reads `UCC_AUDIT_BLOB_TOKEN ?? BLOB_READ_WRITE_TOKEN`, so either name works. For clarity, alias it:

```bash
vercel env add UCC_AUDIT_BLOB_TOKEN production
# Paste the same value as BLOB_READ_WRITE_TOKEN
```

---

## Part 2: Generate secrets (one-time, ~2 min)

These are the secrets you control directly.

```bash
# UCC_SESSION_SECRET (32+ bytes, base64url) — iron-session AES-GCM
node -e "console.log(require('crypto').randomBytes(48).toString('base64url'))"

# UCC_BOOTSTRAP_ADMIN_TOKEN (32+ bytes) — gates the bootstrap CLI
node -e "console.log(require('crypto').randomBytes(32).toString('base64url'))"
```

Store them in Vercel:

```bash
cd /Volumes/DevSSD/fitme-story

vercel env add UCC_SESSION_SECRET production preview
# Paste the first value

vercel env add UCC_BOOTSTRAP_ADMIN_TOKEN production
# Paste the second value
# Note: skip preview/development for the admin token — it's only needed locally
```

**Verify:**

```bash
vercel env ls | grep -E "UCC_(SESSION|BOOTSTRAP|AUDIT)"
```

Should show all three set.

---

## Part 3: Pull env locally for the bootstrap CLI (one-time, ~1 min)

```bash
cd /Volumes/DevSSD/fitme-story
vercel env pull .env.local
```

This writes `.env.local` with all the vars. The `scripts/issue-bootstrap-token.ts` CLI reads them at runtime.

---

## Part 4: Set initial mode + deploy (~5 min)

```bash
vercel env add UCC_AUTH_MODE production
# Paste: basic
```

Trigger a production deploy:

```bash
vercel --prod
# OR: push to main and let auto-deploy handle it
```

**Verification gate (DO NOT proceed until all three pass):**

| Check | Expected |
|---|---|
| Visit `https://fitme-story.vercel.app/control-room/` | Still demands basic-auth (`DASHBOARD_USER` + `DASHBOARD_PASS`) |
| Visit `/control-room/sign-in` (no auth needed for sign-in page) | Renders the new sign-in screen |
| Visit `/control-room/sign-in/recover` (no auth needed) | Renders the recover screen |

If all three pass → **infrastructure is live; nothing has changed for end users yet.** ✅

---

## Part 5: Register your first device (~3 min per operator)

This is the moment the dashboard starts having a passkey.

```bash
cd /Volumes/DevSSD/fitme-story
pnpm tsx scripts/issue-bootstrap-token.ts ops@yourdomain.com
```

The script prints two things:

1. The raw token (32 bytes, base64url)
2. A direct URL: `https://fitme-story.vercel.app/control-room/sign-in/recover?bootstrap=<token>`

> **Security note:** the token is single-use, 15-min TTL, SHA-256 hashed at rest. The raw value never sits in Redis. Do NOT email or paste this URL in chat — open it directly on the device you want to register.

**Open the URL on the device you want to register** (Mac with Touch ID, iPhone, Windows machine with Hello, or a YubiKey-connected machine). The device will:

1. Show the FitMe brand mark + "Add this device" CTA
2. On tap → biometric prompt (Touch ID / Face ID / Hello / YubiKey tap)
3. After confirmation → redirect to `/control-room/sign-in?registered=1`

**Verify on Vercel logs:**

```bash
vercel logs --prod | grep -E "auth_passkey_register"
```

You should see `auth_passkey_register_started` followed by `auth_passkey_register_completed`. If only `_started` shows, the registration ceremony failed mid-flow — open the browser DevTools console for the WebAuthn error message.

---

## Part 6: Flip to `both` mode (~1 min)

The dashboard now accepts EITHER basic-auth OR passkey. Old credentials still work; the new passkey works. **This is the cutover window** — the safety net while every operator registers.

```bash
vercel env rm UCC_AUTH_MODE production
vercel env add UCC_AUTH_MODE production
# Paste: both
vercel --prod
```

**Verification gate:**

1. Open a fresh browser session (or incognito) → visit `/control-room/` → you should be redirected to `/control-room/sign-in`
2. Click **"Unlock with passkey"** (or rely on the conditional-UI autofill prompt) → biometric → land on `/control-room/`
3. ✅ Passkey path works
4. Open another fresh session → use the OLD basic-auth credentials → ✅ still works (because `both` accepts either)

**Repeat Part 5** for every authorized operator. Each operator runs the bootstrap CLI on a trusted machine and registers their primary device.

---

## Part 7: Register break-glass YubiKey (~3 min, MANDATORY before Part 8)

Run the bootstrap CLI again on a trusted machine. Open the URL in a browser with a YubiKey plugged in. Register the YubiKey (it'll prompt for a touch on the key). This is your fallback if your primary device's keychain syncs break or the device is lost.

```bash
pnpm tsx scripts/issue-bootstrap-token.ts ops@yourdomain.com
# → register YubiKey when the URL opens
```

**Verify** on `/control-room/settings/devices`: you should see at least 2 rows for your operator (Platform + Hardware key).

---

## Part 8: Flip to `passkey`-only + drop legacy (~2 min)

Only do this once you have:

- ≥ 1 passkey registered for every authorized operator
- ≥ 1 break-glass YubiKey registered for at least one operator

```bash
vercel env rm UCC_AUTH_MODE production
vercel env add UCC_AUTH_MODE production
# Paste: passkey

# Drop the old credentials so they can't be used as a back door
vercel env rm DASHBOARD_USER production
vercel env rm DASHBOARD_PASS production

vercel --prod
```

**Verification gate:**

1. Fresh session → visit `/control-room/` → redirect to sign-in → biometric → land on dashboard ✅
2. Try the OLD basic-auth credentials directly (e.g. `https://username:password@fitme-story.vercel.app/control-room/`) → ❌ should redirect to sign-in (basic-auth no longer honored)
3. **Passkey is now the ONLY way in.** ✅

---

## Part 9: Wire the audit-log sync (one-time, ~5 min)

Audit-log entries accumulate on the fitme-story Vercel function host (`.local/ucc-auth-events.jsonl`). They mirror to a Vercel Blob via the Vercel Cron at `/api/cron/sync-audit-log` (daily at 05:13 UTC). The FT2 GitHub Actions workflow pulls the Blob next.

### Step 9.1: Get the Blob URL (after first cron run, or trigger manually)

```bash
# Trigger the cron route manually for testing (requires CRON_SECRET from Vercel env)
cd /Volumes/DevSSD/fitme-story
CRON_SECRET=$(grep CRON_SECRET .env.local | cut -d= -f2)
curl -X GET https://fitme-story.vercel.app/api/cron/sync-audit-log \
  -H "Authorization: Bearer $CRON_SECRET"
```

The response includes `"url": "https://...vercel-storage.com/ucc-auth-events.jsonl"`. Copy that URL.

### Step 9.2: Wire the FT2 GHA

```bash
# In FT2 repo (canonical clone)
gh variable set UCC_AUDIT_BLOB_URL --body "<the URL from 9.1>" --repo Regevba/FitTracker2
```

**Verify:**

```bash
gh workflow run "UCC audit log sync" --repo Regevba/FitTracker2
sleep 30
gh run list --workflow "UCC audit log sync" --limit 1 --repo Regevba/FitTracker2
```

The workflow should run successfully. Check the latest commit on `main` — if there were new events, you'll see a `chore(ucc-auth): daily sync of audit log` commit by `github-actions[bot]`.

---

## Part 10: Verify framework-health page populates (~1 min)

Visit [`fitme-story.vercel.app/control-room/framework`](https://fitme-story.vercel.app/control-room/framework) (passkey-sign-in first). Scroll to the bottom — there's a new section **"Auth surface — passkey gate"** with:

- Stat row: Registered count · Auths (7d) · Failed (7d)
- Recent events table (last 5)
- Suspicious-event banner (only renders on anomalies)
- "View full audit log →" link

If all stats are 0 immediately after Part 5, that's expected — the daily GHA hasn't synced yet. They populate after the next sync (next morning, or after Step 9.2's manual trigger).

---

## Rollback (any step → safety, ~30 sec)

If anything goes wrong at any step:

```bash
vercel env rm UCC_AUTH_MODE production
vercel env add UCC_AUTH_MODE production
# Paste: basic
vercel --prod
```

You're back to the original behavior. **No data is lost** — credentials, sessions, and audit log all stay in Redis + Blob and resume working when you flip back to `both` or `passkey`.

If you need to fully purge state:

```bash
# Drop all UCC keys from Upstash (use carefully — irreversible for the registered passkeys)
# Best done via Upstash dashboard SQL/CLI: SCAN MATCH ucc:* | DEL
```

---

## Kill-criteria checkpoint at T+7d

Per the [PRD](../../.claude/features/ucc-passkey-auth/prd.md) §6, after `UCC_AUTH_MODE=both` has run for 7 days, evaluate:

| Kill | Trigger | Action |
|---|---|---|
| **K1** | Registration ceremony fails on > 5% of attempted devices in week 1 | Fall back to `basic`. Reopen scope. |
| **K2** | Any `auth_passkey_authenticate_failed.reason: counter_replay` event fires | **HARD STOP.** Investigate before any further sign-ins. |
| **K3** | Vercel function p50 on `/api/auth/*` > 500 ms sustained 24 h | Fall back to `basic` if not resolved within 1 week. |

Update `kill_criteria_resolution` in [`docs/case-studies/ucc-passkey-auth-case-study.md`](../case-studies/ucc-passkey-auth-case-study.md) §99 with the verdict + supporting telemetry.

---

## Quick reference — env vars

| Var | Where | Purpose |
|---|---|---|
| `UCC_AUTH_MODE` | Vercel prod | `basic` / `both` / `passkey` |
| `UCC_SESSION_SECRET` | Vercel prod + preview | iron-session AES-GCM secret (32+ B base64url) |
| `UCC_BOOTSTRAP_ADMIN_TOKEN` | Vercel prod + local `.env.local` | Gates the bootstrap CLI |
| `UPSTASH_REDIS_REST_URL` + `UPSTASH_REDIS_REST_TOKEN` | Vercel (auto from Marketplace) | KV store |
| `UCC_AUDIT_BLOB_TOKEN` (or `BLOB_READ_WRITE_TOKEN`) | Vercel | Cron upload to Blob |
| `CRON_SECRET` | Vercel (auto when `crons` is configured in `vercel.json`) | Authorizes the cron route |
| `UCC_AUDIT_BLOB_URL` | FT2 repo variable | Daily GHA pull source |
| `DASHBOARD_USER` / `DASHBOARD_PASS` | Vercel (delete at Part 8) | Legacy basic-auth |
| `DASHBOARD_PUBLIC` | Vercel (dev only) | Set to `true` to bypass ALL auth (local dev only) |

---

## Troubleshooting

**Symptom:** sign-in page renders but biometric prompt never appears
- Open browser DevTools console for the WebAuthn error
- Common cause: RP-ID mismatch on preview deploys (`*-fitme-story.vercel.app` ≠ `fitme-story.vercel.app`). **Preview deploys must use `UCC_AUTH_MODE=basic`** — set on the preview environment specifically.

**Symptom:** "This passkey is no longer valid. Use the Recover flow."
- The credential was revoked. Run the bootstrap CLI on another operator's machine to issue a fresh token, then re-register on the new device via `/control-room/sign-in/recover`.

**Symptom:** `Authentication required` 401 dialog still appears after Part 8
- `DASHBOARD_USER` or `DASHBOARD_PASS` env var still set. Confirm: `vercel env ls | grep DASHBOARD`. Drop both, redeploy.

**Symptom:** AuditLogPanel shows `0 / 0 / 0` even after several sign-ins
- The daily GHA hasn't synced yet. Manually trigger via Step 9.1 + Step 9.2's manual workflow run, or wait until 05:17 UTC tomorrow.

**Symptom:** counter_replay event fires
- **K2 hard stop.** Do NOT keep signing in. Investigate: is the affected credential a hardware key that always reports counter=0 (some YubiKey models)? Check `redis-store.ts` CAS logic — counter=0 is allowed only when stored counter is also 0. If real attack suspected, revoke the credential immediately via `/control-room/settings/devices`.

---

## Cross-references

- **Source case study:** [`docs/case-studies/ucc-passkey-auth-case-study.md`](../case-studies/ucc-passkey-auth-case-study.md)
- **PRD:** [`.claude/features/ucc-passkey-auth/prd.md`](../../.claude/features/ucc-passkey-auth/prd.md)
- **Research:** [`.claude/features/ucc-passkey-auth/research.md`](../../.claude/features/ucc-passkey-auth/research.md)
- **Risk audit:** [`.claude/features/ucc-passkey-auth/risk-audit-2026-05-07.md`](../../.claude/features/ucc-passkey-auth/risk-audit-2026-05-07.md)
- **fitme-story PR #55:** WebAuthn passkey gate code (squash `5362f8f`)
- **FT2 PR #248:** Cross-repo audit-log sync (squash `e5a7c45`)
- **Linear:** [FIT-63](https://linear.app/fitme-project/issue/FIT-63)
- **Glossary:** passkey · WebAuthn · RP-ID · conditional UI · bootstrap-token · iron-session · FIDO2 — [fitme-story.vercel.app/glossary](https://fitme-story.vercel.app/glossary)
- **Adjacent setup guides:**
  - [Auth runtime verification playbook](auth-runtime-verification-playbook.md) — iOS-side auth verification (Sign In with Apple, Google, etc.)
  - [Sentry setup guide](sentry-setup-guide.md) — error tracking integration
  - [Integrations setup guide](integrations-setup-guide.md) — broader Vercel + GitHub + service integrations
