---
title: "Google Analytics — Case Study"
date_written: 2026-05-05
work_type: Feature
dispatch_pattern: serial
success_metrics:
  primary: "Analytics events landing in GA4 with screen-prefix taxonomy compliance ≥ 95% [T1 once dashboards live]. The substrate every other feature's success metrics depend on."
  secondary:
    - "Consent rate > 50% after ATT prompt [T1 once instrumented]"
    - "Event coverage of declared metrics 14/40 at merge growing toward 40/40 as downstream features land [T1]"
    - "Zero PII leakage in event payloads [T1 — schema-validated]"
kill_criteria:
  - "Data-driven foundation — cannot be killed. If consent rate < 5%, simplify consent flow rather than removing analytics."
case_study_type: pre_pm_workflow_backfill
parent_case_study: "docs/case-studies/six-features-roundup-case-study.md"
predecessor_case_studies: []
status: shipped
framework_version: pre-v5.0
ship_date: 2026-04-04
pr_merge_commit: ac85c73
---

# Case Study: google-analytics

> **Status:** Shipped 2026-04-04 (pre-PM-workflow rule, backfilled 2026-05-05)
> **Framework version:** pre-v5.0
> **Case study type:** `pre_pm_workflow_backfill` — written retroactively from the existing PRD + research + tasks + ux-spec; no fabrication
> **Parent (until split 2026-05-05):** [`six-features-roundup-case-study.md`](six-features-roundup-case-study.md)

## 1. One-line headline

The feature that went from "11 shipped features, 40 defined metrics, zero analytics instrumentation" to a working GA4 pipeline with protocol abstraction, consent gating, and screen tracking — and unblocked every metric target in the project [T2].

## 2. Summary card

| Field | Value |
|---|---|
| Scope | Firebase Analytics SDK integration, protocol-based AnalyticsService, ConsentManager (ATT + GDPR), 24 screen tracks, 15 custom events, Settings opt-out, GA4 2025 naming conventions |
| PR / commits | Merge `ac85c73` (22 files, +1970 −39) [T1]. Ordered chain: `7b320bc` (PM phases 0-3), `e09b58f` (core infrastructure), `48d1dd3` (GA4 2025 naming), `05d34d8` (Firebase + GA4 setup guide, 20 steps), `ea7364a` (wire Firebase into FitTrackerApp), `9f4a29c` (FirebaseAdapter in DEBUG), `1421a23` (screenView → AnalyticsEventScreenView), `0bd8c35` (T8 screen tracking), `35d770a` (T10 settings toggle), `f404ed1` (T11 — 17 unit tests), `05ef79d` (T12 metrics framework update), `c4be39d` (review), `16ed42d` (docs 9/9) |
| Work type | Feature |
| RICE | 8.0 (highest remaining at the time) |
| Transitions | 10 — full lifecycle 2026-04-02T19:30Z → 2026-04-04T10:45Z [T1] |
| Wall time | ~39 hours calendar, ~19 hours active [T2 declared, derived from transition timestamps] |
| Tests | 17 unit tests (`AnalyticsTests.swift` +297 lines) [T1] |
| High-risk files touched | Zero [T1 manual audit at review] |

## 3. What shipped

The infrastructure layer:
- `AnalyticsProvider.swift` (195 lines) defines the protocol
- `AnalyticsService.swift` (243 lines) is the singleton façade
- `ConsentManager.swift` (106 lines) handles ATT + GDPR consent
- `FirebaseAnalyticsAdapter.swift` (40 lines) is the production adapter
- `MockAnalyticsAdapter.swift` (47 lines) is the test double
- `AnalyticsScreenModifier.swift` (23 lines) is the SwiftUI view modifier for per-screen tracking
- `ConsentView.swift` (113 lines) is the user-facing consent screen

Plus the 361-line `docs/project/firebase-setup-guide.md`, a 65-line `docs/product/analytics-taxonomy.csv`, and 22 lines of `metrics-framework.md` updates.

## 4. Architectural decisions

Research picked "GA4 + Firebase over TelemetryDeck, Mixpanel, Amplitude, PostHog" with the protocol abstraction explicitly framed as "swap providers without code changes." The protocol layer isn't over-engineering — it's the mechanism that lets `MockAnalyticsAdapter` exist for tests, and the reason the `c4be39d` code review was clean (every event flows through one well-typed surface).

GA4 automatic events (`first_open`, `app_open`, `session_start`) stay unprefixed. Custom events get screen prefixes. This is the feature that implicitly set the stage for the **2026-04-08 screen-prefixed-analytics rule** that Home v2 later codified ([CLAUDE.md "Analytics Naming Convention"](../../CLAUDE.md)).

## 5. Known limitations at ship

Three risks logged at review:
- "GoogleService-Info.plist contains API key (not committed to git — local only)"
- "Firebase adapter stubbed until SPM added in Xcode" — runtime gate, not a regression
- "Xcode build requires paid Apple Developer account for device testing"

Metrics: **14/40 instrumented at merge** (35%) [T1] — not the full set, by design — the remaining events get instrumented as the features that emit them land.

## 6. Chain of custody

Source artifacts (all present pre-2026-04-13 rule, retained verbatim):

| Artifact | Path | Lines |
|---|---|---|
| PRD | [`.claude/features/google-analytics/prd.md`](../../.claude/features/google-analytics/prd.md) | 355 |
| Research | [`.claude/features/google-analytics/research.md`](../../.claude/features/google-analytics/research.md) | 146 |
| Tasks | [`.claude/features/google-analytics/tasks.md`](../../.claude/features/google-analytics/tasks.md) | 150 |
| UX spec | [`.claude/features/google-analytics/ux-spec.md`](../../.claude/features/google-analytics/ux-spec.md) | 188 |
| State | [`.claude/features/google-analytics/state.json`](../../.claude/features/google-analytics/state.json) | — |
| Merge | `ac85c73` (22 files, +1970 −39) | — |
| Setup guide | [`docs/project/firebase-setup-guide.md`](../../docs/project/firebase-setup-guide.md) | 361 |
| Taxonomy | [`docs/product/analytics-taxonomy.csv`](../../docs/product/analytics-taxonomy.csv) | 65+ |

## 7. Why this wasn't a dedicated case study at ship time

Same reason as [gdpr-compliance](gdpr-compliance-case-study.md): merged 2026-04-04, "every feature gets a case study" rule landed 2026-04-13. But GA is arguably the most consequential feature in the project's first two weeks because every subsequent feature's kill criteria, funnel metrics, and post-launch reviews depend on it.

This dedicated case study was split out 2026-05-05 as part of the chain-of-custody initiative (full-repair-mode plan, Decision 3 + Q1 = Option 3 hybrid split). If one of the six features in the original roundup deserved its own case study at ship time, it was this one.

## 8. What a full live-pm-workflow case study would have additionally recorded

**The "integrate the measurement substrate first" pattern** — GA shipped before most of the features that emit events against it, and the shape of those features' PRDs (every feature now has an analytics spec gate in Phase 1) is downstream of GA existing.

**The `48d1dd3` naming-convention refactor mid-sprint** is the clearest single signal that the project's analytics taxonomy was still being shaped during the feature itself, not just the tooling.

## 9. Cross-feature lesson

A measurement substrate built early sets the constraint envelope every downstream feature operates inside. GA's protocol abstraction is the reason features 2026-04-04 onward could test analytics without firing real events, the reason `MockAnalyticsAdapter` is a real type, and the reason the 2026-04-08 screen-prefix rule was technically possible (the protocol's strict event-name contract enabled it). Substrate features have outsized leverage; if the measurement layer is missing or weak, downstream features inherit the weakness.

## Links

- **State:** `.claude/features/google-analytics/state.json`
- **Source PRD/research/tasks/UX:** `.claude/features/google-analytics/`
- **Companion case studies (split out same day from same roundup):** [`gdpr-compliance-case-study.md`](gdpr-compliance-case-study.md), [`android-design-system-case-study.md`](android-design-system-case-study.md)
- **Original roundup parent:** [`six-features-roundup-case-study.md`](six-features-roundup-case-study.md)
- **Downstream rule:** [CLAUDE.md "Analytics Naming Convention"](../../CLAUDE.md) (2026-04-08, codified by Home v2)
- **Showcase:** to be published as part of full-repair-mode plan PR-F
