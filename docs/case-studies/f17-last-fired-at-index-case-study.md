---
slug: f17-last-fired-at-index
title: "F17 per-gate last_fired_at index — derived telemetry materialization"
date_written: 2026-06-04
framework_version: v7.9.1
work_type: Feature
work_subtype: framework_feature
case_study_type: shipped
tier_tags_required: true
status: shipped
case_study: docs/case-studies/f17-last-fired-at-index-case-study.md
case_study_showcase: fitme-story/content/04-case-studies/45-f17-last-fired-at-index.mdx
related_prs:
  - 617
dispatch_pattern: serial
success_metrics:
  - name: gate_count_indexed
    baseline: 0
    target: 100
    significance: descriptive
    review_at: 2026-06-04
    tier: T1
    note: "100% of gates that emitted to gate-coverage.jsonl appear in gate-last-fired.json after refresh. Measured baseline: 16 gates indexed from 1828 rows; this matches the active-gates set inventory."
  - name: refresh_wall_clock_seconds
    baseline: 2.0
    target: 2.0
    significance: descriptive
    review_at: 2026-06-04
    tier: T1
    note: "PRD budget <2s. Empirical: <1s (0.04s for the unit-test corpus; ~0.5s for the 1828-row canonical ledger)."
  - name: integration_callsites
    baseline: 0
    target: 4
    significance: descriptive
    review_at: 2026-06-04
    tier: T1
    note: "make gate-last-fired (direct) + make integrity-check (chained) + scripts/daily-integrity-checkpoint.py (inherits via integrity-check) + .github/workflows/framework-status-weekly.yml (nightly)."
  - name: enables_v710_gate_coverage_zero_check
    baseline: 0
    target: 1
    significance: descriptive
    review_at: 2026-08-12
    tier: T2
    note: "v7.10 GATE_COVERAGE_ZERO meta-check can now read O(1) per gate from gate-last-fired.json instead of scanning O(records × gates). Reviewed at the 2026-08-12 quarterly Data Freshness Audit (B4 cadence followup)."
kill_criteria:
  - condition: "Refresh wall-clock >10s on the canonical ledger — operators won't tolerate the lag in interactive sessions"
  - condition: "Index loses an event class (e.g., advisory-only firings drop from input) — readers get false-positive 'gate never fired' signals"
  - condition: "Schema drift between refresh script's expected input and gate_coverage.py output — silent stale index"
kill_criterion_fired: false
kill_criteria_resolution: "K1 (wall-clock) measured at <1s — well under threshold. K2 + K3 require sustained operation to evaluate; reviewed at quarterly audits."
---

# F17 Per-Gate `last_fired_at` Index — Case Study

> **Status:** Shipped 2026-06-04.
> **Framework version:** v7.9.1 (second substantive v7.9.1 work after F16/F6).
> **Showcase:** `fitme-story/content/04-case-studies/45-f17-last-fired-at-index.mdx`.

## TL;DR

`.claude/shared/gate-last-fired.json` is now a derived per-gate index over Mechanism A telemetry. Producers stream rows into `.claude/logs/gate-coverage.jsonl` (append-only); the F17 refresh script aggregates per-gate `last_fired_at` + `last_checked_at` + `last_skipped_at` + `first_seen_at` + totals. Readers query "when did this gate last fire?" in O(1) instead of scanning O(records × gates). Wall-clock <1s for the 1828-row canonical ledger at ship.

## Problem

By v7.9, Mechanism A had accumulated ~1800 rows in `gate-coverage.jsonl`. The planned v7.10 `GATE_COVERAGE_ZERO` meta-check (catch gates that have stopped firing despite producing prior telemetry) would need to scan that stream for every "is this gate alive?" query — O(records × gates). The 2026-08-12 quarterly Data Freshness Audit (per cadence followup B4) requires the same per-gate "last fired" answer. Without materialization, the query becomes more expensive on every successive run.

T1 [infra-master-plan §3.1 Theme G F17]: RICE-est 66.7 — highest of all v7.9.1 candidates. Spec already concrete (`scripts/refresh-gate-last-fired.py` + `.claude/shared/gate-last-fired.json`). Independent of F16 (no calibration window needed — read-only derived artifact).

## Approach

Direct implementation, no Phase 0/1/2 needed. The spec is one script + one JSON file + four wiring points:

1. `scripts/refresh-gate-last-fired.py` — reads ledger line-by-line, aggregates per-gate, writes index.
2. `make gate-last-fired` — on-demand target.
3. `make integrity-check` — chained refresh before integrity scan (every operator + every CI run benefits).
4. `scripts/daily-integrity-checkpoint.py` — inherits via integrity-check (no separate edit needed).
5. `.github/workflows/framework-status-weekly.yml` — nightly refresh, snapshot included in weekly history.

The index schema captures three distinct timestamps per gate so future consumers can tell apart "gate ran and fired" vs "gate ran but skipped everything" vs "gate hasn't been touched in N days":

- `last_fired_at` — most recent timestamp where `checked >= 1` (strict "the gate actually evaluated")
- `last_checked_at` — most recent timestamp of any candidate row (gate's dispatcher ran)
- `last_skipped_at` — most recent timestamp where `skipped >= 1` (diagnostic signal)

Plus totals (`total_firings`, `total_skips`, `total_candidates`) and `first_seen_at` for longitudinal questions.

## Decisions log

- **Pattern reference:** AWS Config Rules `LastSuccessfulInvocationTime`. The derived index lets the v7.10 meta-check stay O(1) per gate.
- **Schema versioning:** index has top-level `schema_version: 1` so future readers can detect format drift. Bump-and-migrate pattern.
- **Resilience:** malformed JSON rows are counted (`source_rows_malformed`) and skipped — not crashed on. Operators can audit corruption via the counter without losing the index.
- **Blank-line + whitespace tolerance:** blank input lines are not counted as malformed (common case in append-only streams that flush periodically).
- **Idempotent re-runs:** same input → same output (verified by `test_idempotent_re_runs`). Daily checkpoint + weekly cron can both refresh without interaction effects.
- **Independent of F16:** the calibration window concept (advisory→enforced flip) does not apply — this is a derived artifact, not a gate. No state to promote, no false-positive risk surface.

## Outcomes

| Dimension | Value |
|---|---|
| Producer script | `scripts/refresh-gate-last-fired.py` (~230 LOC) |
| Test suite | `scripts/tests/test_refresh_gate_last_fired.py` — **14/14 pass in 0.04s** |
| Index output | `.claude/shared/gate-last-fired.json` — 5.5KB at ship for 16 gates |
| Wall-clock | <1s for 1828-row canonical ledger |
| Integration points | 4 (make target + make integrity-check + daily checkpoint via inheritance + weekly cron) |
| Documentation | CLAUDE.md v7.9.1 F17 section + dev-guide v7.9.1 timeline row + this case study + fitme-story showcase MDX slot 45 |

T1/T2 tier discipline applied throughout. The 14-test count + 0.04s wall-clock + 16 gates indexed + 1828 rows are T1 (instrumented via pytest output + script counter). The `enables_v710_gate_coverage_zero_check` metric is T2 (declared design intent, validated at 2026-08-12 audit).

## Phase E discipline note

F17 ships during the v7.9.1 build window post-Phase-E exit (2026-06-04 → ~2026-06-11). The work is read-only on `gate-coverage.jsonl` (no new gate code, no schema drift) and writes only to a new derived file. No advisory/enforcement window required. Branch isolation: all work on `feature/f17-last-fired-at-index`.

## Cross-references

- **Spec:** [`docs/master-plan/infra-master-plan-2026-05-12.md`](../master-plan/infra-master-plan-2026-05-12.md) §3.1 Theme G F17 (RICE 66.7)
- **Predecessor F16:** [`docs/case-studies/f16-try-repo-harness-case-study.md`](f16-try-repo-harness-case-study.md) (shipped same day)
- **CLAUDE.md discipline:** [`CLAUDE.md`](../../CLAUDE.md) "v7.9.1 F17 — Per-gate `last_fired_at` Index"
- **Dev-guide timeline:** [`docs/architecture/dev-guide-v1-to-v7-7.md`](../architecture/dev-guide-v1-to-v7-7.md) §12 v7.9.1 row
- **Linear:** FIT-89
- **Tier 2.2 log:** [`.claude/logs/f17-last-fired-at-index.log.json`](../../.claude/logs/f17-last-fired-at-index.log.json)
- **Quarterly audit consumer:** B4 cadence followup 2026-08-12 (Data Freshness Audit)
- **v7.10 consumer:** planned `GATE_COVERAGE_ZERO` meta-check
