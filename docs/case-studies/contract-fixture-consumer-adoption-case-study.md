---
slug: contract-fixture-consumer-adoption
title: "Contract-Fixture Consumer Adoption (E-15) — closing the W16 silent-pass cross-repo"
date_written: 2026-06-22
framework_version: v7.10
work_type: Feature
work_subtype: framework_feature
case_study_type: shipped
tier_tags_present: true
status: shipped
case_study: docs/case-studies/contract-fixture-consumer-adoption-case-study.md
case_study_showcase: ""
related_prs:
  - 790
pr_citation_exempt:
  - pr_number: 209
    reason: "Reference to the predecessor gate-coverage aggregator PR (fitme-story #209) for context, not a PR of this feature."
  - pr_number: 252
    reason: "This feature's primary PR is the cross-repo fitme-story#252 (documented throughout the body); the numeric Q6 parity matcher is same-repo-centric and cannot reconcile a fitme-story PR number against an FT2-owned state.json, so it is recorded here per the designed cross-repo-citation override."
dispatch_pattern: serial
predecessor_case_study: docs/case-studies/f-launchd-drift-extension-case-study.md
success_metrics:
  - name: w16_shape_drift_caught_at_ci
    baseline: "0 (consumer had no shape-validation gate; drift only surfaced in prod)"
    target: "100% — every required-key drift fails contract:check"
    significance: blocking
    review_at: 2026-06-29
    tier: T1
    note: "(T1) Measured by 7 checker unit tests + npm run contract:check. The 2026-05-24 W16 incident (producer emitted `timestamp`, consumer expected `event.ts`) ran 13 days in prod because both repos' tests agreed on the wrong shape; the checker now validates against the REAL producer sample + live src/data/features."
  - name: audit_log_canonical_sample_pii_safe
    baseline: "no canonical fitme-story-side sample existed"
    target: "0 raw-PII fields in the committed fixture"
    significance: blocking
    review_at: 2026-06-29
    tier: T1
    note: "(T1) 9 Redis-free sampler tests; `sanitize-strips-PII` asserts operator_label is stripped → hash before write."
  - name: fixture_staleness_days
    baseline: 15
    target: 0
    significance: high
    review_at: 2026-06-29
    tier: T2
    note: "(T2) Both repos' fixtures were sampled 2026-06-07 (15d > 7d max_age) at session start. FT2 re-sampled fresh (#790); weekly cron now maintains freshness. Verified by first scheduled cron fire."
kill_criteria:
  - "Freshness check too strict — breaks fitme-story CI when an FT2-produced fixture goes stale between syncs (the consumer cannot self-re-sample those)"
  - "audit-log sampler leaks PII into the committed, publicly-reachable fixture"
  - "Consumer tests hand-author the producer shape (the W16 anti-pattern), so drift still passes silently"
kill_criteria_resolution: >
  All 3 mitigated by design. (1) Freshness is ASYMMETRIC — WARN (not hard) for FT2-produced
  fixtures fitme-story vendors but cannot re-sample, HARD only for fitme-story-owned contracts
  (audit-log) where it controls re-sampling; test `stale FT2-produced fixture → WARN (not hard)`
  enforces. (2) The sampler runs `sanitizeForPublicExport` on every record before write; test
  `sanitize-strips-PII` asserts no raw PII survives. (3) The checker validates against the real
  producer-sampled fixture + live src/data/features data, never inline literals; tests use temp
  dirs and never hand-author the producer shape.
---

# Contract-Fixture Consumer Adoption (E-15)

## Context

F-CONTRACT-FIXTURE-SAMPLING exists because of the **2026-05-24 W16 incident**: the
`/control-room/framework` page threw a `TypeError` in production for **13 days** with green CI the
whole time. The FitTracker2 gate-coverage producer emitted a `timestamp` field; the fitme-story
control-room consumer expected `event.ts`; and **both repos' test suites agreed on the wrong
shape**, so neither caught the drift.

The fix is a contract-sampling discipline: validate the data a consumer reads against the
**producer's real sampled output**, never a hand-authored fixture. The FT2 **substrate** (`scripts/sample-contract-fixtures.py`, `make check-contract-fixtures`, warn-only in `pr-integrity-check.yml`)
shipped 2026-06-07. The cross-repo **consumer** half — fitme-story-side validation plus a shared
re-sample cadence — was filed as **E-15** and left open. This case study covers closing it.

## What shipped

Two PRs, both merged 2026-06-22:

- **fitme-story#252** — the complete consumer adoption:
  - `scripts/check-contract-fixtures.ts` — a unified checker. **Shape (required_keys) = HARD**
    fail (T1 — the incident class). **Freshness = asymmetric**: WARN for FT2-produced fixtures
    fitme-story vendors (it cannot self-re-sample them — the weekly cron re-vendors), HARD for
    fitme-story-owned contracts. Validates the vendored fixtures **and** the live
    `src/data/features/*.json` consumer (113 files).
  - `scripts/sample-audit-log-contract.ts` — the audit-log **canonical** sampler. fitme-story is
    that contract's canonical producer (the UCC auth stream lives in Upstash Redis here; FT2 only
    mirrors it). It reads recent events, **sanitizes** each via `sanitizeForPublicExport` (the
    fixture is committed and the control-room is publicly reachable), asserts required keys, and
    no-ops cleanly without Redis creds.
  - `.github/workflows/contract-resample-weekly.yml` — Mondays 07:00 UTC. Re-samples audit-log
    (Upstash secret) and re-vendors the FT2 fixtures via a fresh clone (`FITTRACKER2_DEPLOY_TOKEN`),
    each step guarded on its secret, and opens a PR on change.
  - `package.json` `contract:check` script + a **warn-only** step in `integrity.yml`.
  - 16 new tests (7 checker + 9 sampler), all temp-dir based; the gate-coverage aggregator test
    (PR #209) already validated shape against the canonical fixture and stays green.

- **PR #790** (FitTracker2) — re-sampled the 15-day-stale `gate-coverage` + `state-json-schema`
  fixtures fresh, and recorded the E-15 status in `.claude/shared/v7-9-1-candidates.md`.

## A verification-first surprise

Before writing the consumer checker, a read of `gate-coverage-aggregator.test.ts` showed that the
gate-coverage **shape** validation against the canonical fixture **already existed** (PR #209). The
plan was adjusted to add only the genuinely-missing pieces — freshness, the live
`state-json-schema` consumer, the audit-log canonical sample, the unified script, and the cadence —
rather than duplicate work. The 15-day fixture staleness across *both* repos also surfaced during
this check, confirming the missing re-sample cadence was real.

## Deferred — promotion to blocking (operator decision)

The warn-only → **blocking** flip was **deliberately not done**. Two reasons: FT2's
`contract-fixtures-weekly.yml` is intentionally **drift-only + warn-only per operator decision D2
(2026-06-18)** — making the FT2 gate blocking would override that decision; and the fitme-story
consumer gate is **day-0**, which under the §3.5 calibration discipline must soak warn-only first.
Promotion prerequisites (crons fire ≥1× cleanly, ~7–14 day soak with no false positives, explicit
D2 reconsideration) are recorded in the candidates doc; the flip date is an operator decision.

## Outcome

`npm run contract:check` → PASS; 16/16 new tests + aggregator 9/9 green; FT2 post-merge
`integrity-check` 0 findings and `check-contract-fixtures` all fresh (0.0d). The W16 silent-pass
class is now closed end-to-end: producer-shape drift fails at consumer CI time instead of in
production, and a weekly cadence keeps the fixtures honest.
