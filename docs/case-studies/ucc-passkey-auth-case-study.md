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
kill_criteria_resolution: "Pending — week-1 telemetry gate. Resolution recorded in §99 at T+7d post UCC_AUTH_MODE=both flip. Default state = `not_yet_observed` (T2 declared); flip to `not_fired` (T1 instrumented) once GA4 + audit-log show the first cohort cleanly."
case_study_showcase: fitme-story/content/04-case-studies/26-ucc-passkey-auth.mdx
external_audit_status: pending
pr_citation_exempt:
  - pr_number: 55
    reason: "Cross-repo PR on Regevba/fitme-story, not Regevba/FitTracker2. The FT2 BROKEN_PR_CITATION gate scans only FT2's gh pr list; fitme-story PRs are documented as exempt per the v7.8.1 protocol convention for cross-repo features."
  - pr_number: 163
    reason: "Cross-reference to auth-polish-v2 case study (FT2 PR #163 shipped 2026-05-01) — sibling feature that established the iOS-side passkey patterns ported here. Not a PR shipping this feature."
---

# UCC Passkey Auth — Replacing basic-auth on /control-room/* with WebAuthn

> **Status:** SHIPPED 2026-05-07 via fitme-story#55 (squash `5362f8f`) + FT2 PR #248 (squash `e5a7c45`).
>
> **One-line outcome:** the operator dashboard at `fitme-story.vercel.app/control-room/*` is now passkey-gated. The shared HTTP basic-auth credential it ran on for ~30 days has been preserved as a reversible fallback (`UCC_AUTH_MODE=basic`), but the path forward is per-operator passkeys with hardware-backed identity, server-side session revocation, and a daily-synced audit log surfaced on the framework-health page.

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

1. **Pre-ship:** `UCC_AUTH_MODE=basic` (current) — no behavior change.
2. **Cutover-T0:** Operator runs `pnpm tsx scripts/issue-bootstrap-token.ts <email>` locally. Token TTL = 15 min, single-use, SHA-256 hash at rest. Operator pastes into `/control-room/sign-in/recover` to register first device. Flip env to `UCC_AUTH_MODE=both`. Each operator does the same.
3. **Cutover-T+7d:** Each operator registers a YubiKey or second device as **break-glass** (mandatory before `passkey`-only flip).
4. **Cutover-T+14d:** Flip env to `UCC_AUTH_MODE=passkey`. Drop `DASHBOARD_USER` + `DASHBOARD_PASS` env vars.

Reversal at any phase = single env-var change.

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

> Reserved for the T+7d kill-criteria resolution + T+30/60/90d secondary-metric reviews. Update at the cadence specified in the PRD §6 Review Cadence section.
