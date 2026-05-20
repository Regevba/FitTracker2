# UCC Passkey Auth Security Hardening — Delta PRD

> **Status:** Approved (delta on parent PRD)
> **Work type:** Enhancement to shipped feature `ucc-passkey-auth`
> **Parent PRD:** [`.claude/features/ucc-passkey-auth/prd.md`](../ucc-passkey-auth/prd.md) §7 Q1 + Q2
> **Design spec (authoritative):** [`docs/superpowers/specs/2026-05-19-ucc-passkey-security-hardening-design.md`](../../../docs/superpowers/specs/2026-05-19-ucc-passkey-security-hardening-design.md)
> **Risk + rollback:** [`docs/master-plan/ucc-passkey-security-hardening-risk-assessment-2026-05-19.md`](../../../docs/master-plan/ucc-passkey-security-hardening-risk-assessment-2026-05-19.md)

## Why this is a "delta PRD"

This enhancement closes four explicitly-deferred gaps in the parent `ucc-passkey-auth` PRD (§7 Q1 + §7 Q2). The full requirements, threat model, acceptance criteria, and test plan live in the design spec — this file is the PM-workflow contract artifact that lets the preflight + the audit trail recognize the enhancement as in-scope.

## Scope

Closes 4 gaps surfaced during the 2026-05-19 UCC audit:

| Gap | Closure | Spec section |
|---|---|---|
| **G1+G2** No code lock + env-var allowlist for permitted operator emails | `UCC_ALLOWED_EMAILS` env var + `isEmailAllowed()` gate in `/api/auth/register/options` | §3 |
| **G3** No lockout after N failed authentications | Hybrid per-email (10/15-min) + per-IP (20/30-min) Redis-backed lockout | §4 |
| **G4** No audit trail at bootstrap-token *issuance* (only at consumption) | New `auth_bootstrap_token_issued` event from `scripts/issue-bootstrap-token.ts` + renamed consumption event | §5 |
| **Operability** Manual lockout-clear lever | New `scripts/clear-lockout.ts` CLI utility | §6 |

## Success Metrics

Per spec §11 (Calibration Window + T+7d Checkpoint):

- **Primary:** Zero `auth_lockout_blocked_attempt` events for the operator's own IP class in the 2026-05-20 → 2026-05-23 window (baseline: N/A, target: 0)
- **Secondary 1:** Zero `email_not_allowlisted` events for `regvash21@gmail.com` (target: 0)
- **Secondary 2:** Sign-in latency p50 increase < 5 ms vs pre-hardening baseline (target: ≤ +5 ms)
- **Guardrail:** Redis quota stays within free tier (target: no quota alerts)

**Kill criteria:** if any of the 3 above fail at T+7d (2026-05-23), hardening is rolled back per spec §7.4 (Rollback Procedures); a meta-analysis case study is filed; the kill criteria are documented as resolved in `state.json::kill_criteria_resolution`.

## Out of Scope

Mirrors design spec §9. Notable exclusions: edge-layer rate limiting (Vercel Firewall), per-environment lockout tuning, audit-log forwarding to Sentry/Logflare, 2FA, account-recovery flow, cross-environment session revocation.

## Timeline

| Date | Event |
|---|---|
| 2026-05-19 | Phase 0 (design + risk-assess) shipped via FT2 PR #410 |
| 2026-05-20 EOD | Target merge of fitme-story implementation PR (gate: before 2026-05-21 v7.9 freeze) |
| 2026-05-22 | T+3d calibration checkpoint (cadence followup B11) |
| 2026-05-23 | T+7d kill-criteria checkpoint (cadence followup B8 from parent UCC) |

## Phase Plan (Enhancement = 4-phase)

| Phase | Deliverable |
|---|---|
| **Tasks** (current) | tasks.md + `state.json::tasks[]` |
| **Implementation** | fitme-story code: allowlist + redis-lockout + audit event + CLI + 5 wirings + 5 test files |
| **Test** | All 34 new unit tests pass + manual verification matrix (spec §8.2) |
| **Merge** | fitme-story PR open + merge + post-merge verifications (spec §7.3) |

## References

- Authoritative design: design spec linked above
- Parent feature state: [`.claude/features/ucc-passkey-auth/state.json`](../ucc-passkey-auth/state.json) (`current_phase: complete`)
- Sibling enhancement: [`.claude/features/ucc-passkey-auth-audit-log-redis-fix/`](../ucc-passkey-auth-audit-log-redis-fix/)
