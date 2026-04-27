# Case Study: auth-polish-v2

> **Status:** Live, Phase 1 (PRD draft approved-pending)
> **Framework version:** v7.6 (Mechanical Enforcement)
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

## Phase 1 — PRD (in progress, opened 2026-04-27T05:09:15Z)

To be populated on phase close: total FRs, primary metric, kill criteria, files-touched estimate, analytics-spec event count.

## Phase 2-8

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
