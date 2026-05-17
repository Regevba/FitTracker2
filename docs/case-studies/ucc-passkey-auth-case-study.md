---
title: "UCC Passkey Auth — Replacing basic-auth on /control-room/* with WebAuthn"
slug: ucc-passkey-auth
date: 2026-05-07
date_written: 2026-05-07
framework_version: v7.8.1
work_type: feature
work_subtype: cross_repo
parent_feature: unified-control-center
predecessor_chain:
  - unified-control-center
  - auth-polish-v2
case_study_type: feature
dispatch_pattern: serial_full_pm_cycle_with_isolation
related_prs:
  - repo: fitme-story
    number: 55
    squash_sha: 5362f8f
    title: "feat(ucc-passkey-auth): WebAuthn passkeys replace basic-auth on /control-room/*"
  - repo: FitTracker2
    number: 248
    squash_sha: e5a7c45
    title: "feat(ucc-passkey-auth): cross-repo audit-log sync + state + protocol artifacts"
tier_tags_present: true
primary_metric:
  name: unauthenticated_dashboard_reads_per_day
  target: 0
  baseline_pending_post_cutover: true
  tier: T1
success_metrics:
  - metric: time_to_dashboard_p50_seconds
    target: 2.5
    tier: T1
  - metric: registered_passkey_devices
    target: ">=1 per active operator"
    tier: T1
  - metric: bootstrap_token_redemption_rate
    target: ">=95%"
    tier: T1
guardrails:
  - vercel_function_p50_latency_ms: 200
  - failed_assertion_ratio_pct: 5
  - control_room_page_load_p50_no_degradation: true
kill_criteria: "If passkey registration ceremony fails on >5% of attempted devices in week 1, fall back to UCC_AUTH_MODE=both and reopen scope. K2 (any counter_replay event) is a hard stop. K3 (function p50 >500ms sustained 24h) → fall back."
kill_criteria_resolution: "Pending — week-1 telemetry gate. Cutover Parts 1-6 SHIPPED 2026-05-16; UCC_AUTH_MODE=both flipped in production same day; T+7d checkpoint 2026-05-23 (see §99). Default state = `not_yet_observed` (T2 declared); flip to `not_fired` (T1 instrumented) once 7 days of audit-log telemetry show the first cohort cleanly."
case_study_showcase: fitme-story/content/04-case-studies/26-ucc-passkey-auth.mdx
external_audit_status: pending
pr_citation_exempt:
  - pr_number: 55
    reason: "Cross-repo PR on Regevba/fitme-story, not Regevba/FitTracker2. The FT2 BROKEN_PR_CITATION gate scans only FT2's gh pr list; fitme-story PRs are documented as exempt per the v7.8.1 protocol convention for cross-repo features."
  - pr_number: 163
    reason: "Cross-reference to auth-polish-v2 case study (FT2 PR #163 shipped 2026-05-01) — sibling feature that established the iOS-side passkey patterns ported here. Not a PR shipping this feature."
---

# UCC Passkey Auth — Replacing basic-auth on /control-room/* with WebAuthn

> **Status:** SHIPPED 2026-05-07 via fitme-story#55 (squash `5362f8f`) + FT2 PR #248 (squash `e5a7c45`). **Cutover Parts 1-6 EXECUTED 2026-05-16** — `UCC_AUTH_MODE=both` live in production; 1 platform passkey registered for the first operator; legacy basic-auth still active as fallback. Parts 7-10 + T+7d kill-criteria checkpoint deferred — see §99 for current rollout state.
>
> **One-line outcome:** the operator dashboard at `fitme-story.vercel.app/control-room/*` is now passkey-gated (both basic-auth AND passkey accepted in `both` mode). The shared HTTP basic-auth credential it ran on for ~30 days is preserved as a reversible fallback, but the path forward is per-operator passkeys with hardware-backed identity, server-side session revocation, and a daily-synced audit log surfaced on the framework-health page.

## TL;DR

Two-PR cross-repo ship. fitme-story side carries the actual passkey gate (5 screens, 5 API routes, proxy.ts switch, Vercel Cron upload). FT2 side carries the audit-log sync infrastructure (daily GHA pull from Vercel Blob → commits to `.claude/logs/`) plus the v7.8.1 protocol artifacts (state.json, research, PRD, tasks, ux-spec, preflights, pre-merge reviews, risk audit). 28 implementation tasks, ~2,650 LOC added in fitme-story, 19/19 unit tests pass, tsc clean, `next build` clean. The two PRs merged within a minute of each other; cross-repo plumbing is gated on env vars + repo variables so the GHA workflow is a no-op until `UCC_AUDIT_BLOB_URL` is set — the migration plan stays reversible at every step.

## Why this feature existed

The Unified Control Center (UCC) shipped on **2026-05-06** [T1] (parent feature `unified-control-center`, source case study `unified-control-center-case-study.md`). T2.5 — "passkey replacement for basic-auth" — was **explicitly deferred** at UCC ship because it was out of scope for the Astro→Next.js migration and would have stretched the parent feature by another week.

That deferral surfaced a structural asymmetry: the **iOS app** ships passkeys for end users via `auth-polish-v2` (FT2 PR #163, shipped 2026-05-01) [T1]. The **operator surface** that has access to every framework readout, ship event, ledger, and case study was gated by a **shared, phishable, unrotatable** HTTP basic-auth credential. The operator gate was structurally weaker than the user gate — exactly inverted from how a security posture should be shaped.

This case study covers the closure of that asymmetry, shipped one day after the v7.8.1 framework feature that introduced the protocol this ship followed.

## What got built

### fitme-story side (22 new files + 4 modified)

**Backend libraries (`src/lib/auth/`):**
- `webauthn-server.ts` — wrapper around `@simplewebauthn/server` v13 + RP_ID/EXPECTED_ORIGIN constants
- `iron-session-config.ts` — cookie seal/unseal, 24h hard / 12h sliding refresh, server-side `ucc:session:<sid>` allowlist
- `redis-client.ts` — Upstash Redis singleton via `Redis.fromEnv()` (per the vercel-storage skill's recommended pattern)
- `redis-store.ts` — Operator + Credential CRUD with **CAS counter update** as the replay defense
- `redis-ttl-store.ts` — Challenge (60s) + Bootstrap (15min) + Session (24h) TTL stores
- `audit-log.ts` — JSONL append + Vercel Blob POST + **PII redaction** (SHA-256 hashes for credential IDs + session IDs; IPv4 truncated to /24, IPv6 to /48; UA stripped to family)
- `load-events.ts` — Server-side reader for the audit log + `computeAuditStats()` helper
- `util.ts` — `sha256Hex`, `newSid`, `newBootstrapToken`, `ipClass`, `uaFamily`

**API routes (`src/app/api/auth/*` — Node.js runtime):**
- `register/options` + `register/verify` (gated by bootstrap token)
- `authenticate/options` + `authenticate/verify` (mints session cookie)
- `revoke` (server-side allowlist clear; bulk-revoke if last credential)
- `devices` (GET helper for the admin page)
- `cron/sync-audit-log` (Vercel Cron handler that uploads `.local/jsonl` → Vercel Blob)

**5 screens (`src/app/control-room/*`):**
1. `/sign-in` — conditional-UI autofill + manual button fallback
2. `/sign-in/recover` — bootstrap token via `?bootstrap=` query OR paste field
3. `/settings/devices` — credentials table with inline-pill Revoke (NOT modal)
4. `/settings/audit` — last 50 events with filter chips + click-to-expand
5. `/framework` — embedded `<AuditLogPanel>` (3-stat row + suspicious-event banner + recent-5)

**4 reusable components (`src/components/control-room/`):**
- `<AuthPasskeyForm>` — capability detection + ceremony orchestration + 5-state machine
- `<DevicesTable>` — inline confirm pill (mirrors auth-polish-v2 cadence)
- `<AuditEventRow>` — click-to-expand event details
- `<AuditLogPanel>` — server-rendered framework-health embed

**proxy.ts** gains the `UCC_AUTH_MODE` switch (basic / passkey / both) + redirect-to-sign-in on miss (not 401).

**vercel.json** gains a Vercel Cron entry pointing at `/api/cron/sync-audit-log` daily at 05:13 UTC.

**Glossary** extends 38 → 45 entries: passkey, WebAuthn, RP-ID, conditional UI, bootstrap-token, iron-session, FIDO2.

### FT2 side (2 new files)

- `.github/workflows/ucc-audit-log-sync.yml` — daily GHA (05:17 UTC) pulls fitme-story Vercel Blob → commits to `.claude/logs/ucc-auth-events.jsonl`. Repo-variable gated; absence is a no-op rather than failure. No untrusted user input consumed (no command-injection surface).
- `.claude/logs/ucc-auth-events.jsonl` — schema-headed empty placeholder. Live source is fitme-story `.local/`.

Plus the full v7.8.1 protocol artifacts at `.claude/features/ucc-passkey-auth/` (state.json, research.md, prd.md, tasks.md, ux-research.md, ux-spec.md, ux-preflight + design-preflight, ux/design pre-merge-reviews, risk-audit) and Tier 2.2 log at `.claude/logs/ucc-passkey-auth.log.json`.

### Defenses

| Threat | Mechanism |
|---|---|
| **Phishing** | WebAuthn binds assertion to RP ID (`fitme-story.vercel.app`); browser refuses to sign for any other origin. Native phishing-resistance per W3C WebAuthn L3. |
| **Replay** | Per-ceremony challenge in Redis (60s TTL, single-use) + **CAS counter check**. Hardware authenticators that always report `counter=0` explicitly handled (allowed only if stored counter is also 0; otherwise rejected as replay). |
| **Session theft** | HttpOnly + Secure + SameSite=Strict + server-side `ucc:session:<sid>` allowlist enables instant revoke. Cookie path scoped to `/control-room`. |
| **RP-ID spoofing** | RP_ID locked to `fitme-story.vercel.app`. Preview deploys at `*-fitme-story.vercel.app` cannot use production passkeys (RP-ID mismatch is a feature) — they stay on `UCC_AUTH_MODE=basic`. |
| **Lost device** | Operator-2 revokes Operator-1's credential via `/control-room/settings/devices`. If the revoked credential is the only one for that operator, all their sessions are bulk-cleared (forces re-auth on every device). Recovery path = bootstrap token issued from another operator's CLI. |
| **PII leakage in audit log** | Tests assert no raw `credential_id`, `ip`, `user_agent`, or `session_id` appears in the JSONL output. SHA-256 hashes for cross-event correlation; IPv4 truncated to /24, IPv6 to /48; UA stripped to family. |

## Migration plan (reversible at every step)

1. **Pre-ship (2026-05-07 → 2026-05-16):** `UCC_AUTH_MODE=basic` — no behavior change for ~9 days while code shipped dormant.
2. **Cutover-T0 (EXECUTED 2026-05-16):** Operator ran `pnpm tsx scripts/issue-bootstrap-token.ts regvash21@gmail.com` locally. Token TTL = 15 min, single-use, SHA-256 hash at rest. Pasted into `/control-room/sign-in/recover` to register first device (platform passkey on Touch ID Mac). Flipped env to `UCC_AUTH_MODE=both` and redeployed (`dpl_*-cp1019le3`). Redis confirms: `ucc:credential:E5jvwGr...` + `ucc:operator:regvash21@gmail.com` + active session [T1].
3. **Cutover-T+7d (2026-05-23):** Each operator registers a YubiKey or second device as **break-glass** (mandatory before `passkey`-only flip). T+7d kill-criteria K1/K2/K3 resolution recorded in §99. **Note from 2026-05-16:** the first YubiKey registration attempt was deferred because the Mac browser only surfaced the platform-authenticator path (no USB security-key option). Three workarounds documented in §99: Chrome retry, register on a 2nd Touch-ID device, or temp-force `authenticatorAttachment: 'cross-platform'` in [src/app/api/auth/register/options/route.ts:69-72](https://github.com/Regevba/fitme-story/blob/main/src/app/api/auth/register/options/route.ts#L69-L72).
4. **Cutover-T+14d (earliest 2026-05-28):** Flip env to `UCC_AUTH_MODE=passkey`. Drop `DASHBOARD_USER` + `DASHBOARD_PASS` env vars. Calendar-gated per [`infra-master-plan-2026-05-12.md`](../master-plan/infra-master-plan-2026-05-12.md) §4.1 — do not co-fire with 2026-05-21 v7.9 promotion decision.

Reversal at any phase = single env-var change. Today's `UCC_AUTH_MODE=both` flip is rollback-safe via `PATCH /v9/projects/{id}/env/{env_id}` setting value back to `basic` (under 30 seconds).

## How this got shipped — the v7.8.1 protocol

This is the **second feature** shipped via the v7.8 protocol (after framework-v7-8-branch-isolation itself, 2026-05-07 morning). The protocol mandates:

| Discipline | This ship |
|---|---|
| Isolated worktree from Phase 1 onward | ✓ `/Volumes/DevSSD/FitTracker2-ucc-passkey-auth` (Mode C of `BRANCH_ISOLATION_VIOLATION`) |
| Mechanism C session attribution | ✓ `.claude/active-feature` lockfile set at Phase 0 |
| Tier 2.2 contemporaneous logging | ✓ 14 log entries across 7 phase transitions in `.claude/logs/ucc-passkey-auth.log.json` [T1] |
| `/ux preflight` before Phase 4 | ✓ PASS · 0 P0 / 0 P1 / 0 P2 [T1] |
| `/design preflight` before Phase 4 | ✓ PASS · Figma MCP live · build deferred to portable prompt [T1] |
| `/ux pre-merge-review` Phase 6 | ✓ PASS · 0 P0 / 0 P1 / 1 P2 [T1] |
| `/design pre-merge-review` Phase 6 | ✓ PASS_WITH_NOTES (Figma N/A by design) [T1] |
| `FEATURE_CLOSURE_COMPLETENESS` gate at Phase 8 | ✓ this case study has the 7 required frontmatter fields + Q7 `kill_criteria_resolution` + Q6 PR parity [T1] |

**14 phase transitions captured in the log:**

```
Phase 0 (Research)       — 13 min · 14-section research.md
Phase 1 (PRD)            — 10 min · 15-section PRD with 7 locked decisions
Phase 2 (Tasks)          —  7 min · 28 tasks across 8 blocks, lane-classified
Phase 3 (UX/Integration) — 10 min · ux-research + ux-spec + 2 preflights + 2 prompts
Phase 4 (Implementation) — 30 min · 28/28 tasks, 22 files added in fitme-story
Phase 5 (Testing)        — 20 min · 19/19 unit tests pass, tsc clean, next build clean
Phase 6 (Review)         — 15 min · 3 review artifacts (UX, design, risk audit)
Phase 7 (Merge)          —  ~10 min · 2 PRs opened + auto-merged within seconds
Phase 8 (Docs/Closure)   —  in flight (this case study)
```

Total measured wall time: **~115 minutes** [T1] (Tier 2.2 instrumented; not a steady-state forecast).

## Tests

- ✅ **19/19 unit tests pass** [T1] across 5 test files: `util.test.ts` · `iron-session-config.test.ts` · `audit-log.test.ts` · `load-events.test.ts` · `round-trip.test.ts`
- ✅ **tsc 0 errors on feature files** (pre-existing errors in 3 unrelated test files — not introduced by this feature) [T1]
- ✅ **`next build` clean** (1 pre-existing Turbopack NFT warning, not feature-related) [T1]
- ⏳ **Manual smoke profile `passkey_signin_surface`** added to FT2 runtime-smoke-config — runs on first `UCC_AUTH_MODE=both` deploy [T2 declared, awaiting T1 telemetry]

## Honest disclosures

1. **One bug caught + fixed during Phase 5 testing.** `iron-session`'s `unsealData` returns `{}` on garbage input rather than throwing — my `unsealSession` wrapper would have returned an empty SessionPayload-shaped object. Caught by the "returns null on garbage input" test. Fix: explicit field-presence check on all 4 payload fields. Test asserts the bug stays dead.

2. **4 modules refactored to lazy env reads during Phase 5.** Static reads of `process.env.UCC_AUDIT_LIVE_PATH` at module-load time caused test isolation issues (env-var override after import had no effect because imports hoist). Refactored `audit-log.ts`, `load-events.ts`, the cron route, and the bootstrap script to read env at call-time. This is also the right production behavior — Vercel cold-start may have different env state than warm-invocation.

3. **Figma node IDs are absent.** Per `state.json.figma_build_status: "deferred_to_prompt"`. The fitme-story dashboard has no current Figma-file mapping — it was built code-first during the UCC migration. The portable build prompt at `docs/prompts/ui/2026-05-07-ucc-passkey-auth-design-build.md` is the v4.X documented escape hatch; any future operator can reconstruct Figma fidelity at any time. `/design pre-merge-review` returned `passed_with_notes` for this reason.

4. **`kill_criteria_resolution` is "pending".** The kill criteria are time-deferred (resolution at T+7d post-cutover). The frontmatter records the criteria + the resolution placeholder; the actual T+7d update will land in §99 after the cutover window.

5. **`auth-polish-v2` patterns ported, not extracted.** The capability-detection + consent-sheet + inline-error-banner + mock-fixture-test patterns are mirrored on the web side rather than extracted into a shared library. Consolidation can happen later if a third auth surface emerges.

## Cross-references

- **PRD:** [`.claude/features/ucc-passkey-auth/prd.md`](https://github.com/Regevba/FitTracker2/blob/main/.claude/features/ucc-passkey-auth/prd.md)
- **Research:** [`.claude/features/ucc-passkey-auth/research.md`](https://github.com/Regevba/FitTracker2/blob/main/.claude/features/ucc-passkey-auth/research.md)
- **UX spec:** [`.claude/features/ucc-passkey-auth/ux-spec.md`](https://github.com/Regevba/FitTracker2/blob/main/.claude/features/ucc-passkey-auth/ux-spec.md)
- **Design build prompt (portable):** [`docs/prompts/ui/2026-05-07-ucc-passkey-auth-design-build.md`](https://github.com/Regevba/FitTracker2/blob/main/docs/prompts/ui/2026-05-07-ucc-passkey-auth-design-build.md)
- **Risk audit:** [`.claude/features/ucc-passkey-auth/risk-audit-2026-05-07.md`](https://github.com/Regevba/FitTracker2/blob/main/.claude/features/ucc-passkey-auth/risk-audit-2026-05-07.md)
- **fitme-story#55** (cross-repo PR; resolves at https://github.com/Regevba/fitme-story PR list, not FT2): WebAuthn passkeys replace basic-auth — squash `5362f8f`
- **FT2 PR #248:** [cross-repo audit-log sync + state files + GHA workflow](https://github.com/Regevba/FitTracker2/pull/248) — squash `e5a7c45`
- **Predecessor:** [`unified-control-center-case-study.md`](unified-control-center-case-study.md) — UCC migration that produced the T2.5 deferral
- **Sibling:** [`auth-polish-v2-case-study.md`](auth-polish-v2-case-study.md) — iOS-side passkey patterns ported here
- **Framework:** [`framework-v7-8-branch-isolation-case-study.md`](framework-v7-8-branch-isolation-case-study.md) — v7.8.1 protocol that gated this ship

## §99 Resolution log (post-launch)

### 2026-05-16 — Cutover Parts 1-6 executed; T+7d clock starts

**Shipped on the day (chronological):**

| Setup-guide step | What landed | Verification |
|---|---|---|
| Part 1.1 | Upstash Redis `upstash-kv-coquelicot-pebble` (Vercel Marketplace, free tier) | `KV_REST_API_URL`/`KV_REST_API_TOKEN` auto-injected to all 3 envs [T1] |
| Part 1.2 | Vercel Blob store `ucc-audit-log` (`store_Wbm976bbAd3TvK2o`, public access, iad1) | `BLOB_READ_WRITE_TOKEN` auto-injected [T1] |
| Part 2 | `UCC_SESSION_SECRET` (sensitive prod+preview, 64 chars base64url) + `UCC_BOOTSTRAP_ADMIN_TOKEN` (sensitive prod, encrypted dev, 43 chars base64url) | Length-verified via dev pull comparison [T1] |
| Part 3 | `.env.local` pulled with development-scope vars (perms 600) | `UCC_BOOTSTRAP_ADMIN_TOKEN` length 43 confirmed [T1] |
| Part 4 | `UCC_AUTH_MODE=basic` set explicitly + production deploy `dpl_87pw4jwejjexjf8cV9WKc3S5moQT` | 3-URL gate passed: `/control-room/` returns 401 Basic; `/sign-in` 200; `/sign-in/recover` 200 [T1] |
| Part 5 | Bootstrap token issued for `regvash21@gmail.com` (TTL 15 min, single-use, SHA-256 hashed at rest) → opened in browser → platform passkey registered | Redis state: `ucc:credential:E5jvwGr...` + `ucc:operator:regvash21@gmail.com` + `ucc:operator:regvash21@gmail.com:credentials` + active `ucc:session:*` [T1] |
| Part 6 | `UCC_AUTH_MODE` flipped `basic` → `both` via Vercel REST API PATCH; redeploy `dpl_*-cp1019le3` | `/control-room/` now returns `307 → /control-room/sign-in?next=%2Fcontrol-room` for no-creds; `/sign-in` still 200 [T1] |

**Deferred (calendar-anchored, see [`.claude/shared/must-have-cadence-followups.md`](../../.claude/shared/must-have-cadence-followups.md)):**

| Step | Target | Blocker |
|---|---|---|
| **Part 7 — break-glass YubiKey/2nd device** | before 2026-05-28 | Browser hid USB security-key option on first attempt. Three documented workarounds (Chrome retry; 2nd platform passkey on iPhone/2nd Mac; temp-force `authenticatorAttachment: 'cross-platform'`). |
| **Part 9 — `UCC_AUDIT_BLOB_URL` repo variable in FT2** | 2026-05-17 (after first cron run 05:13 UTC) | Daily cron at `/api/cron/sync-audit-log` populates the Blob; URL extracted via authenticated curl; `gh variable set` writes the FT2 repo variable; T22 GHA workflow then activates. ~10 min. |
| **Part 10 — framework-health passkey panel populated** | 2026-05-18 onward | Dependent on Part 9 + first daily GHA sync run (next morning after Part 9 lands). |
| **Part 8 — `UCC_AUTH_MODE=passkey` + drop `DASHBOARD_USER`/`DASHBOARD_PASS`** | on/after **2026-05-28** | Calendar-gated per [`infra-master-plan-2026-05-12.md`](../master-plan/infra-master-plan-2026-05-12.md) §4.1: don't co-fire with 2026-05-21 v7.9 promotion decision. Prerequisite: Part 7 complete. |
| **T+7d kill-criteria checkpoint (K1, K2, K3)** | **2026-05-23** | Pending observation window of 7 days post `UCC_AUTH_MODE=both` flip. Resolution will replace this §99 row. |

**Operational quirks captured during cutover (worth fixing as follow-ups):**

1. **`vercel env add` silently writes empty values in headless mode** (this CLI version). Both `--value <v> --yes --non-interactive` and `< file` stdin-redirect forms fail. The Vercel REST API `POST /v10/projects/{id}/env` works reliably. Worked around for this session — followup is either a CLI bug report to Vercel OR a wrapper script that goes through the API by default. [T1]
2. **Upstash Marketplace now injects `KV_REST_API_*` not `UPSTASH_REDIS_REST_*`.** Runtime code `Redis.fromEnv()` falls back automatically (per `@upstash/redis@latest`), but the bootstrap CLI [scripts/issue-bootstrap-token.ts](https://github.com/Regevba/fitme-story/blob/main/scripts/issue-bootstrap-token.ts) hard-fails without the `UPSTASH_*` names. Worked around via inline `export UPSTASH_REDIS_REST_URL="$KV_REST_API_URL"` shell. **Followup:** patch the CLI to match runtime fallback (small code change, low risk). [T1]
3. **`sensitive` env vars are write-only by Vercel design.** `vercel env pull` returns empty strings for them — not a bug. Verification of write success requires a non-sensitive copy in another scope OR a runtime test. The session used a dev-scope `encrypted` copy of `UCC_BOOTSTRAP_ADMIN_TOKEN` to confirm the write-mechanism worked correctly. [T1]
4. **Local `.vercel/project.json` was pointing to legacy `fit-tracker2` project at session start** (the now-deprecated Astro dashboard), not `fitme-story`. The first Upstash install ran against the wrong project before the operator caught it. Re-linked mid-session via `vercel link --yes --project fitme-story`. Worth a SessionStart preflight check — if any future operator's local clone has the same stale link, this fails subtly. [T1]

### 2026-05-17 — Audit-log persistence bug discovered (10-day silent window) + Redis-backed fix shipped

**Discovery.** While executing B7 (wire `UCC_AUDIT_BLOB_URL` in FT2 after the first daily cron at 05:13 UTC), HEAD-probed the deterministic blob URL `https://wbm976bbad3tvk2o.public.blob.vercel-storage.com/ucc-auth-events.jsonl` — got **HTTP/2 404 from a real Vercel server** [T1]. That confirmed the cron has been returning `synced: 0` every run since 2026-05-07, even after the operator successfully registered a platform passkey and authenticated multiple times. The GHA workflow `ucc-audit-log-sync.yml` had run successfully 5 days in a row (2026-05-12 → 2026-05-16) — but every run short-circuited because `UCC_AUDIT_BLOB_URL` was unset; chicken-and-egg with a blob that never existed [T1].

**Root cause traced (file:line, two cooperating failures).**

1. **Stage 1 was architecturally broken on Vercel.** [`audit-log.ts:113-143`](https://github.com/Regevba/fitme-story/blob/main/src/lib/auth/audit-log.ts#L113-L143) wrote events to `cwd/.local/ucc-auth-events.jsonl` via `fs.appendFile`. Vercel function filesystem is **read-only at runtime** ([Vercel docs reference](https://vercel.com/docs/functions/runtimes#file-system-access)). The bare `try/catch` at line 122 swallowed the `EROFS` error — the inline comment literally read *"Local fs may be read-only on Vercel — that's expected; rely on Blob."* [T1] The "Blob" referenced was Stage 2.
2. **Stage 2 was never provisioned.** [`audit-log.ts:128-142`](https://github.com/Regevba/fitme-story/blob/main/src/lib/auth/audit-log.ts#L128-L142) POSTs to `UCC_AUDIT_BLOB_ENDPOINT` (an externally-managed log forwarder endpoint — Logflare, Axiom, etc.). Cutover ([§Cutover Parts 1-6 above](#2026-05-16--cutover-parts-1-6-executed-t7d-clock-starts)) provisioned `UCC_SESSION_SECRET`, `UCC_BOOTSTRAP_ADMIN_TOKEN`, `UCC_AUTH_MODE`, `BLOB_READ_WRITE_TOKEN` (auto), `KV_REST_API_*` (auto) — but **never `UCC_AUDIT_BLOB_ENDPOINT`** [T1]. `getBlobEndpoint()` returned `null` on every call; `fetch()` was never invoked.
3. **The cron read the same dead path** and dutifully reported `synced: 0` to caller logs ([`sync-audit-log/route.ts:46-51`](https://github.com/Regevba/fitme-story/blob/main/src/app/api/cron/sync-audit-log/route.ts#L46-L51) pre-fix) — a perfect silent-pass: no exception, no monitoring alert, no operator surface change (AuditLogPanel just renders empty regardless of activity) [T1].

**Why it shipped (honest answer).** Phase 5 testing wrote `process.env.UCC_AUDIT_LIVE_PATH = tmpFile` to point Stage 1 at `os.tmpdir()` — the existing tests at [`audit-log.test.ts`](https://github.com/Regevba/fitme-story/blob/main/src/lib/auth/audit-log.test.ts) verified the **happy path** (event in → event readable via `readAuthEvents()`), but no test asserted Vercel-runtime behavior with a **read-only cwd**. Phase 6 risk audit ([`.claude/features/ucc-passkey-auth/risk-audit-2026-05-07.md`](https://github.com/Regevba/FitTracker2/blob/main/.claude/features/ucc-passkey-auth/risk-audit-2026-05-07.md)) surfaced 3 risks — proxy.ts gate, CAS counter replay, PII redaction — all 3 were correctly addressed; **audit-log persistence was not on the risk surface**. Production runtime smoke profile `passkey_signin_surface` validated the auth ceremony end-to-end but did not assert that audit events landed durably. This is a generalizable lesson: tests that swap in a writable fs path silently mask a write-failure failure mode the production environment guarantees [T3].

**Fix shape (10-day-deferred enhancement, scoped as Tasks T1-T9).**

| T | Title | Status |
|---|---|---|
| T1 | Redis audit-log primitives in `src/lib/auth/redis-audit-log.ts` (`pushEvent` / `readEvents` / `readAllEvents` / `trimEvents` / `sanitizeForPublicExport`) | ✅ shipped (cbd487c) [T1] |
| T2 | `logAuthEvent` → Redis `LPUSH` + bounded `LTRIM` at 10k cap (no more dead fs write) | ✅ shipped (cbd487c) [T1] |
| T3 | `readAuthEvents` + `loadAuthEvents` → Redis `LRANGE 0..N-1` (newest-first by construction; scope expanded mid-implementation to include the actually-used UI reader `load-events.ts`) | ✅ shipped (cbd487c) [T1] |
| T4 | Cron route reads Redis, **sanitizes** (hashes `operator_label` per security amendment below), writes Blob with `addRandomSuffix:false + allowOverwrite:true` (deterministic URL preserved for B7) | ✅ shipped (cbd487c) [T1] |
| T5 | 15 unit tests with mock Redis; full auth suite **27/27 pass** | ✅ shipped (cbd487c); `npm run build` clean [T1] |
| T6 | Deploy + manual `curl` invoke cron → validate blob URL returns 200 | ⏳ post-merge of fitme-story PR #122 [T2] |
| T7 | `gh variable set UCC_AUDIT_BLOB_URL` in FT2 (= original B7 unblock) | ⏳ after T6 [T2] |
| T8 | Update parent `ucc-passkey-auth/state.json` rollout_status: Part 9 deferred → shipped | ⏳ after T7 [T2] |
| T9 | This §99 entry | ✅ this commit [T1] |

**Security amendment (pre-implementation audit, 2026-05-17).** Operator emails (`operator_label`) had been stored raw because `AuditLogPanel` needs human-readable identification. The cron's blob target uses `access: 'public'` + `addRandomSuffix: false` → URL is **deterministic AND publicly readable**. Anyone who derives `store_id_prefix.public.blob.vercel-storage.com/ucc-auth-events.jsonl` from public Vercel deployment metadata can read the file. Pre-implementation audit caught this *before* T4 went out (zero events had been written to that URL yet — the original bug masked the leak). T4 added `sanitizeForPublicExport()` which hashes `operator_label` → `operator_label_hash` at the cron-write boundary using the same `sha256Truncated(..., 12)` convention as `credential_id_hash` and `session_id_hash`. Redis (private, token-gated) keeps raw emails for the in-app panel; the publicly-exported JSONL never carries them [T1].

**Silent-pass window — what we don't know.** Between 2026-05-07 ship and 2026-05-17 discovery, every `logAuthEvent` call dropped its event. The operator's 2026-05-16 cutover (1 successful registration + 1 successful sign-in + multiple Redis-state-confirmed activities) is the **last known set of events** that didn't get persisted [T2 — declared from absence of blob, not from a counted ledger of dropped events]. There is no way to reconstruct what was logged in the 10-day window because the data never existed at rest anywhere. The cutover sequence itself is fully captured above in §99's 2026-05-16 entry from Redis state inspection (`ucc:credential:E5jvwGr...` etc.) — that's the canonical record of what happened, drawn from the OAuth/passkey state store rather than the audit log [T1].

**Net impact on rollout timeline.**

- B7 (wire `UCC_AUDIT_BLOB_URL`) — **unblocked** once T6 ships [T1].
- B8 (T+7d kill-criteria K1/K2/K3 checkpoint, 2026-05-23) — **now achievable** because real audit data starts accumulating with T2 ship + cron's first post-merge run [T1].
- C5 (Part 10 framework-health passkey panel verify) — **now meaningful** since `AuditLogPanel` reads Redis directly (no longer dependent on the broken local-fs path) [T1].

**Operational lesson encoded for v8.x infra plan** (per the v7.8.5 W-pattern catalog protocol): add a new W-pattern *"Vercel function filesystem ephemerality"* — any code reading/writing local files outside `/tmp` on a Vercel function will silently fail with the bare-catch idiom prevalent in this codebase. Future PR-review heuristic: any `fs.appendFile`/`fs.readFile` to `cwd/.local/...` paths in Vercel-deployed code is a P0 review finding unless explicitly justified [T3].

### Pending entries

- **2026-05-23** — T+7d kill-criteria K1/K2/K3 resolution
- **2026-06-16** — T+30d secondary-metric review (registration rate, time-to-dashboard p50)
- **2026-07-16** — T+60d cumulative review
- **2026-08-16** — T+90d steady-state review
