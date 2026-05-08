---
title: "Auth Polish v2 — Case Study"
date_written: 2026-04-28
work_type: Feature
dispatch_pattern: serial
success_metrics:
  primary: "Auth recovery success rate ≥ 70% by day 60, ≥ 75% by day 90 [T1]. Composite of password-reset completion + biometric-unlock completion + Google sign-in completion / their respective starts."
  secondary:
    - "Password-reset completion / requested ≥ 60% by day 60 [T1]"
    - "Biometric activation rate (activated / offered) ≥ 35% by day 60 [T1]"
    - "Google Sign-In adoption ≥ 20% of total sign-ins by day 60 [T1]"
    - "Biometric unlock latency P95 < 1500ms [T1]"
kill_criteria:
  - "Biometric activation rate < 5% by day 14 → iterate copy/timing once; second miss → kill activation sheet, Settings-only"
  - "Google Sign-In > 0.5% crash/hang rate → flip GoogleRuntimeConfiguration.isConfigured to false via remote-config"
  - "Forgot-password deep-link return < 90% success → regress to inline status-banner-only mode"
  - "Overall auth_signin_completed rate drops > 5% week-over-week → halt rollout; investigate SDK conflict"
case_study_type: live_pm_workflow
predecessor_case_studies:
  - "docs/case-studies/onboarding-v2-auth-flow-v5.1-case-study.md"
status: live_phase_2
---

# Case Study: auth-polish-v2
<!-- doc-debt-backfill: original fields from scripts/backfill-case-study-fields.py;
     2026-04-28: enriched with YAML frontmatter at PRD approval per Appendix B + v7.7 hooks. -->

> **Status:** Live, Phase 2 (Tasks) — PRD approved 2026-04-28
> **Framework version:** v7.7 (Validity Closure)
> **Case study type:** `live_pm_workflow`
> **Started:** 2026-04-27
> **Feature directory:** [.claude/features/auth-polish-v2/](../../.claude/features/auth-polish-v2/)
> **Log file:** [.claude/logs/auth-polish-v2.log.json](../../.claude/logs/auth-polish-v2.log.json)
> **GitHub Issue:** [#143](https://github.com/Regevba/FitTracker2/issues/143)
> **Branch:** `feature/auth-polish-v2`

---

## Why this case study exists from day one

Per CLAUDE.md "Every feature gets a case study" (mandatory from 2026-04-13) and v7.6's `CASE_STUDY_MISSING_TIER_TAGS` pre-commit hook, the case study scaffold lands in **Phase 1 (PRD), not Phase 8 (Docs)**. This is one of the eight cooperating defenses in the v7.5 → v7.6 Data Integrity Framework: write-time gates, cycle-time gates, and readout-time gates all assume measurement instrumentation runs from the moment a feature has a PRD — not retroactively.

The narrative below populates as phases complete. This file is intentionally sparse during early phases. Tier tags (T1 / T2 / T3) on every quantitative claim are mandatory per the 2026-04-21 Gemini audit Tier 2.3 convention.

---

## Phase 0 — Research (closed 2026-04-27)

| Field | Value | Tier |
|---|---|---|
| Duration | 8.6 minutes | T1 |
| Sources cited | 10 external links | T1 |
| Alternatives compared | 3 per workstream (9 total) | T1 |
| New screens proposed | 5 | T1 |
| New external dependencies | 1 (`GoogleSignIn-iOS`) | T1 |
| Existing-code findings | 1 (`ColorAppColor` typos in [AuthHubView.swift:635](../../FitTracker/Views/Auth/AuthHubView.swift#L635) and [AuthHubView.swift:825](../../FitTracker/Views/Auth/AuthHubView.swift#L825)) | T1 |

**Key decision:** bundle three workstreams (forgot-password, biometric refinement, Google Sign-In SDK activation) into one feature/PRD/branch because they share files, review surface, and QA scope. Splitting into three branches multiplies merge conflicts and review overhead.

**Deferred:** Apple Sign In Services-ID setup (out-of-repo Apple Developer console action), AI smart reminder UI (separate enhancement), Sentry MCP wiring (Gate C peer).

## Phase 1 — PRD (closed 2026-04-28)

| Field | Value | Tier |
|---|---|---|
| Started | 2026-04-27T05:09:15Z | T1 |
| Approved | 2026-04-28 | T1 |
| Wall-time gap (incl. v7.7 freeze pause) | ~36 hours calendar; ~8.6 min research + draft, paused 2026-04-27 14:00 UTC for v7.7 priority freeze; resumed 2026-04-28 17:00 UTC | T1 |
| PRD size | 31KB / 473 lines / 21 sections | T1 |
| Functional requirements | 18 (prioritized P0/P1/P2) | T1 |
| User flows documented | 8 (A–H: forgot-password happy/cooldown, biometric activation/decline/unlock/fallback, Google new/returning) | T1 |
| Analytics spec events | 9 new + reused | T1 |
| Files-touched estimate | 26 (flags mandatory feature branch per CLAUDE.md) | T1 |
| OQs resolved + locked at PRD | 3 (activation timing, URL scheme, GIDClientID source) | T1 |
| Phase 1 exit-criteria checklist | 23/23 | T1 |

**Resume + cu_v2 backstory:** the PRD was substantively complete by 2026-04-27 14:00 UTC when the v7.7 freeze paused work. v7.7 (Validity Closure) shipped 2026-04-27 17:39 UTC — PR #144 + #7. On 2026-04-28 the feature resumed; cu_v2 was populated (factors 0.6 / 0.7 / 0.4 / 0.6 → total 2.3, tier_class A_high) since auth = high-risk per CLAUDE.md. Live verification: 45 state.json files pass v7.6 + v7.7 hooks before approval.

**v7.7 dogfood instrumentation activated on this commit:**
- `cache_hits[]` gated by `CACHE_HITS_EMPTY_POST_V6` — empty array OK during work; required non-empty by `current_phase=complete`
- `cu_v2` schema validated by `CU_V2_INVALID` — passes
- `case_study` link present in state.json (gates `STATE_NO_CASE_STUDY_LINK`)
- This file's frontmatter satisfies `CASE_STUDY_MISSING_FIELDS` (forward-only ≥ 2026-04-28; this is the first new case study after the cutoff)

## Phase 2 — Tasks (in progress, opened 2026-04-28)

To be populated on phase close: total tasks, parallel-block grouping, dependency graph, files touched per task.

## Phases 3–8

Pending.

---

## Live measurement instrumentation

This feature's measurement runs from day one — none of these are reconstructed retroactively:

- **Phase timing** — written to `state.json.timing.phases.*.{started_at,ended_at,duration_minutes}` on every transition. v7.6 `PHASE_TRANSITION_NO_TIMING` pre-commit hook enforces this.
- **Tier 2.2 contemporaneous log** — events appended to `.claude/logs/auth-polish-v2.log.json` via `scripts/append-feature-log.py` on every phase transition and cache hit. v7.6 `PHASE_TRANSITION_NO_LOG` pre-commit hook enforces freshness.
- **Cache hits** — appended to both the log AND `state.json.cache_hits[]` so `make measurement-adoption` counts them.
- **Analytics spec** — 9 events, 6 parameters, 5 screens defined in PRD Appendix A; will be transcribed into `docs/product/analytics-taxonomy.csv` during Phase 4.
- **Per-PR review bot** — `pm-framework/pr-integrity` status check fires automatically when the PR opens.

---

## Open questions resolved at PRD time

| OQ | Decision | Rationale (T3) |
|---|---|---|
| OQ-1: Activation-prompt timing | Immediate after first sign-in | T3 — Strava/Whoop pattern; receptiveness peaks at credential-entry moment |
| OQ-2: Forgot-password URL scheme | `fitme://reset-password` | T3 — brand prefix, future-extensible |
| OQ-3: `GIDClientID` source | `GoogleService-Info.plist` (shared with Firebase analytics) | T3 — single source for Gate C config |

## Risks (T2 — Declared)

| Risk | Severity | Likelihood | Mitigation |
|---|---|---|---|
| GoogleSignIn 8.x nonce shift breaks Supabase exchange | High | Medium | Phase 4 vertical slice gate before UI work |
| Deep-link URL scheme conflict with future deep links | Medium | Low | Reserve scheme + write `docs/architecture/deep-linking.md` |
| `ColorAppColor` typos hide a silent build break | Medium | Low | Phase 4 starts with `xcodebuild build` |
| Activation copy fails to drive ≥ 25% conversion | Medium | Medium | Day-14 review checkpoint; iterate; kill criteria documented |

## Kill criteria (T2)

| Trigger | Action |
|---|---|
| `auth_biometric_activated` < 5% by day 14 | Iterate copy/timing once. Second miss → kill activation sheet, move to Settings-only. |
| Google Sign-In > 0.5% crash/hang rate | Flip `GoogleRuntimeConfiguration.isConfigured = false` via remote config |
| Forgot-password deep-link return < 90% success | Regress to status-banner-only mode |
| Overall sign-in success rate drops > 5% week-over-week | Halt rollout, investigate SDK conflict |

---

## Where to look for live data

| What | Path |
|---|---|
| Current phase | [.claude/features/auth-polish-v2/state.json](../../.claude/features/auth-polish-v2/state.json) → `current_phase` |
| Event log | [.claude/logs/auth-polish-v2.log.json](../../.claude/logs/auth-polish-v2.log.json) |
| Cache hits | `state.json.cache_hits[]` |
| GitHub Issue | [#143](https://github.com/Regevba/FitTracker2/issues/143) |
| Latest PR | TBD (lands in Phase 7) |

---

## Closing the loop

This case study transitions from `live_pm_workflow` (active) to `complete` when:
1. `state.json.current_phase == "complete"`
2. PR is merged
3. Day-90 metrics review is recorded (target: 2026-07-26 if shipped on 2026-04-27)

Until then, this file is a living document. Every phase append corresponds to a `state.json` transition event AND a `.claude/logs/auth-polish-v2.log.json` entry — no narrative claim exists without a structured-data peer.
