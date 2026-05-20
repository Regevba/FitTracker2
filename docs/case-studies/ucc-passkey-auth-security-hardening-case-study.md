---
title: UCC Passkey Auth Security Hardening
slug: ucc-passkey-auth-security-hardening
date_written: 2026-05-20
date: 2026-05-20
work_type: enhancement
work_subtype: parent_gap_closure
parent_feature: ucc-passkey-auth
framework_version: v7.8.6
state_owner: ft2
dispatch_pattern: serial
primary_metric: auth_lockout_blocked_attempt_count_for_operator_ip
success_metrics:
  - zero_auth_lockout_blocked_attempts_for_operator_ip_in_t_plus_7d_window
  - zero_email_not_allowlisted_events_for_regvash21_at_gmail
  - signin_latency_p50_increase_less_than_5ms
  - redis_quota_stays_within_free_tier
kill_criteria: |
  Any of the 3 success metrics fail at T+7d (2026-05-27):
  (1) >0 auth_lockout_blocked_attempt for operator's own IP class →
      false positive → tune EMAIL_LOCK_THRESHOLD up;
  (2) >0 email_not_allowlisted for regvash21@gmail.com →
      env-var misconfiguration → fix UCC_ALLOWED_EMAILS;
  (3) sign-in latency p50 increase > 5ms →
      investigate Redis round-trip overhead.
kill_criteria_resolution: ""  # populated at T+7d (2026-05-27)
tier_tags_present: true
status: in_progress
related_prs:
  - "FT2 #410"
  - "FT2 #411"
  - "FT2 #412"
  - "fitme-story #127"
spec: docs/superpowers/specs/2026-05-19-ucc-passkey-security-hardening-design.md
risk_assessment: docs/master-plan/ucc-passkey-security-hardening-risk-assessment-2026-05-19.md
infra_overlay: docs/master-plan/ucc-hardening-infra-overlay-2026-05-19.md
---

# UCC Passkey Auth Security Hardening — Case Study

> **Status:** Draft placeholder · §99 outcome populated at T+7d kill-criteria checkpoint (2026-05-27).
>
> **Parent feature:** [`ucc-passkey-auth`](./ucc-passkey-auth-case-study.md) (shipped 2026-05-07; cutover 2026-05-16).
>
> **Authoritative spec:** [`docs/superpowers/specs/2026-05-19-ucc-passkey-security-hardening-design.md`](../superpowers/specs/2026-05-19-ucc-passkey-security-hardening-design.md) — the full requirements, threat model, acceptance criteria, and test plan live there. This case study captures the lifecycle narrative + post-hoc outcome.

## 1. What shipped

Closes 4 explicitly-deferred gaps from the parent `ucc-passkey-auth` PRD §7 Q1 + Q2:

| Gap | Closure | T1 / T2 / T3 tag |
|---|---|---|
| **G1+G2** | Email allowlist gate (`UCC_ALLOWED_EMAILS` env var) | T1 (instrumented via `auth_passkey_register_failed reason:email_not_allowlisted`) |
| **G3** | Hybrid Redis lockout (per-email 10/15-min + per-IP 20/30-min) | T1 (instrumented via `auth_lockout_triggered` / `_blocked_attempt`) |
| **G4** | Bootstrap-token issuance audit event | T1 (instrumented via `auth_bootstrap_token_issued` event) |
| **CLI** | `scripts/clear-lockout.ts` operator unlock | T2 (declared; logged via `auth_lockout_cleared reason:manual_clear`) |

**Net code:** 5 new modules + 5 route wirings + 1 CLI + 2 enum extensions. **+~2ms auth-path latency** (one extra Redis GET in `checkLockout`).

## 2. PR chain of custody

| PR | Repo | Purpose | Merge date | Commits |
|---|---|---|---|---|
| #410 | FT2 | Phase 0/1/2 prep (spec + risk + audit + delta-PRD + tasks + infra overlay) | 2026-05-19T23:54Z | b40bc59 → c382f1f (squashed) |
| #412 | FT2 | Phase 2→3 state advance (state.json + Tier 2.2 log) | 2026-05-20T03:54Z | dcb8cb6 (squashed) |
| #127 | fitme-story | **The actual hardening code** (12 files, +~1,400 LoC, 17 new tests) | 2026-05-20T03:53Z | 9ec248b (squashed) |
| #411 | FT2 | Operability sibling: UCC audit-log workflow PR-pattern fix | 2026-05-20 (pending CI) | TBD |
| **TBD** | FT2 | **This PR** — phase advance to docs + case study placeholder | 2026-05-20 | — |

## 3. Process narrative

Single-day execution against the 2026-05-20 EOD hard deadline (v7.9 freeze 2026-05-21). Pause-resume cycle across two sessions on 2026-05-19 (Phase 0/1/2 prep) and 2026-05-20 (Phase 3 implementation + T20 partial verify + merge).

### 3.1 Pre-work (Phase 0/1, 2026-05-19)

- Design spec authored after operator-flagged 4-gap audit of parent UCC PRD
- Risk assessment + rollback procedures sub-plan
- Companion dev-env audit (24 recs) bundled with prep work
- Delta PRD stub written to satisfy v7.8.6 preflight (W11 false-positive caught + documented)
- Mid-session SSD migration to X10 Pro complicated the chain-of-custody; preservation branch `chore/ssd-migration-preserve-2026-05-19` ensured nothing was lost

### 3.2 Phase 2 (Tasks)

- 26-task breakdown organized into 9 streams (refactor → taxonomy → 4 gaps → CLI → env/docs → verify → merge → post-merge)
- ARM big.LITTLE lane classification: 8 P-core + 13 E-core + 5 operator-only
- Critical path: T1 → T8 → T9 → T12 → T20 → T22 (~3.4h serial)
- Infra master plan overlay surfaced 9 risks; none blocking, 3 timing-sensitive

### 3.3 Phase 3 (Implementation, 2026-05-20)

- 12 files / +1,400 LoC committed to `feat/ucc-passkey-security-hardening` (fitme-story)
- 17 new unit tests (7 allowlist + 10 redis-lockout) — all passing
- Full suite 148/149 (1 pre-existing failure in `timeline.test.ts`, unrelated to auth — verified on main)
- CI green on PR #127

### 3.4 Phase 5+6 (Test + Review)

- T20 manual verification executed in **partial-live mode** (S1+S2+S3 confirmed live on production)
- S4-S6 covered by unit tests (same-code-path inference for S4; mocked Redis for S5+S6)
- Friction discovered during T20: `UCC_BOOTSTRAP_ADMIN_TOKEN` marked Sensitive in Vercel production env, blocking local CLI use (documented as W12)
- KV_REST_API_* vs UPSTASH_REDIS_REST_* naming asymmetry surfaced (documented in §6 below)

### 3.5 Phase 7 (Merge, 2026-05-20)

- fitme-story #127 squash-merged at 03:53Z → Vercel auto-deployed in ~3min
- Production smoke-tested post-deploy
- FT2 PRs #410 + #412 merged
- FT2 #411 (workflow operability fix) pending rebase-then-CI as of case-study draft

## 4. Outcome (populated at T+7d, 2026-05-27)

> Sections 4.1–4.5 are blank-by-design. The T+7d kill-criteria evaluation (cadence followup B11) populates these.

### 4.1 Primary metric outcome

TBD (2026-05-27)

### 4.2 Secondary metrics

TBD (2026-05-27)

### 4.3 Kill-criteria resolution

TBD (2026-05-27) — fills frontmatter `kill_criteria_resolution` field.

### 4.4 Hardening verdict

TBD (PROMOTE / RECALIBRATE / ROLLBACK)

### 4.5 Latency impact (measured)

TBD (2026-05-27 — measured p50 delta vs pre-hardening baseline)

## 5. Telemetry signals to monitor (2026-05-20 → 2026-05-27)

Per spec §11:

| Signal | Healthy steady state | Concerning |
|---|---|---|
| `auth_lockout_triggered` / day | 0 | >0 (false positive OR real attack) |
| `auth_lockout_blocked_attempt` / day | 0 | >0 for operator's IP class |
| `auth_passkey_register_failed reason:email_not_allowlisted` / day | 0 | >0 (env-var misconfigured) |
| Sign-in latency p50 increase | ≤5ms | >5ms |
| Redis quota usage | within free tier | over quota |

## 6. Operational findings (worth recording)

### 6.1 W11 — Preflight `enhancement_parent` false-positive

Documented in [`.claude/integrity/observed-patterns.md`](../../.claude/integrity/observed-patterns.md) as W11. The v7.8.6 `make preflight` script checks the enhancement feature's own `prd.md` instead of resolving `state.json::parent_feature`. Workaround was a thin delta-PRD; durable fix queued as v7.9.1 candidate.

### 6.2 W12 — Sensitive env-vars don't pull via `vercel env pull` (new — added 2026-05-20)

When running CLI scripts that need production env vars (e.g., `scripts/issue-bootstrap-token.ts` needing `UCC_BOOTSTRAP_ADMIN_TOKEN`), `vercel env pull .env.local --environment=production --yes` will include the var name in the file but with an EMPTY value because the var is marked Sensitive in Vercel. Symptom: script fails with "env var not set (or too short)" even though `vercel env ls production` shows the var exists.

**Workarounds:**

1. **Issue via Vercel CLI proxy:** run the script in a Vercel-context shell that has the Sensitive vars (not generally feasible from local)
2. **Use DEV-env variant:** if the var ALSO exists in the Development environment AND is NOT marked Sensitive there, `vercel env pull .env.local --environment=development` retrieves the value. For UCC, this works because the operator separately set a dev-env admin token.
3. **Toggle Sensitive off temporarily** in Vercel dashboard, pull, then re-mark Sensitive (operationally fragile; not recommended)
4. **Provision a separate "CLI admin token" env-var that's NOT marked Sensitive** for local-dev workflows (security trade-off — but the CLI is only useful with Redis WRITE access anyway, so a separate token doesn't add risk)

**Recommended:** Option 2 (use dev env-var for CLI workflows). Already in use for this enhancement.

### 6.3 KV_* vs UPSTASH_REDIS_REST_* naming asymmetry

The Upstash Marketplace integration on Vercel auto-provisions env vars under both naming conventions:
- `KV_REST_API_URL` / `KV_REST_API_TOKEN` (legacy Vercel KV naming)
- `UPSTASH_REDIS_REST_URL` / `UPSTASH_REDIS_REST_TOKEN` (Upstash native naming)

In some Vercel projects (including fitme-story as of 2026-05-20), only the `KV_*` set gets provisioned to production env. `@upstash/redis`'s `Redis.fromEnv()` reads `UPSTASH_REDIS_REST_*`. Production deploys work because Vercel's serverless runtime sees BOTH names; CLI scripts running locally see only `KV_*` after `vercel env pull`.

**Workaround used during T20:** shell aliasing
```bash
export UPSTASH_REDIS_REST_URL="$KV_REST_API_URL"
export UPSTASH_REDIS_REST_TOKEN="$KV_REST_API_TOKEN"
```

**Durable fix candidate:** update `src/lib/auth/redis-client.ts` to read EITHER name (`process.env.UPSTASH_REDIS_REST_URL ?? process.env.KV_REST_API_URL`) and similarly for token. Queued as a v7.9.1+ follow-up.

## 7. References

- Spec: [`docs/superpowers/specs/2026-05-19-ucc-passkey-security-hardening-design.md`](../superpowers/specs/2026-05-19-ucc-passkey-security-hardening-design.md)
- Risk + rollback: [`docs/master-plan/ucc-passkey-security-hardening-risk-assessment-2026-05-19.md`](../master-plan/ucc-passkey-security-hardening-risk-assessment-2026-05-19.md)
- Infra overlay: [`docs/master-plan/ucc-hardening-infra-overlay-2026-05-19.md`](../master-plan/ucc-hardening-infra-overlay-2026-05-19.md)
- Parent feature case study: [`./ucc-passkey-auth-case-study.md`](./ucc-passkey-auth-case-study.md)
- Parent PRD: [`.claude/features/ucc-passkey-auth/prd.md`](../../.claude/features/ucc-passkey-auth/prd.md) §7 Q1 + Q2
- Cadence followup B11: [`.claude/shared/must-have-cadence-followups.md`](../../.claude/shared/must-have-cadence-followups.md)
- Observed patterns W11 + W12: [`.claude/integrity/observed-patterns.md`](../../.claude/integrity/observed-patterns.md)

## §99 Outcome (T+7d evaluation — 2026-05-27)

To be populated by the operator + meta-analysis pass on 2026-05-27. Updates `kill_criteria_resolution` in the frontmatter + §4 above.
