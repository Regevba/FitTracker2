# Must-have cadence follow-ups

> Created 2026-05-15 from the prioritization cross-reference of [`docs/master-plan/infra-master-plan-2026-05-12.md`](../../docs/master-plan/infra-master-plan-2026-05-12.md), [`docs/master-plan/data-integrity-and-rollback-2026-05-14.md`](../../docs/master-plan/data-integrity-and-rollback-2026-05-14.md), and [`docs/master-plan/test-coverage-master-plan-2026-05-13.md`](../../docs/master-plan/test-coverage-master-plan-2026-05-13.md).
>
> This file tracks the MUST-HAVE items that are NOT yet wired as code (calendar-anchored verifications + feature-scope coding work). Streams A (data-health/integrity infra) and D (preflight entry points) shipped in the same batch and are NOT listed here.

## Calendar-anchored verifications

Surfaced daily by `scripts/daily-integrity-checkpoint.py` when the target date is ≤14 days away.

| ID | Date | Event | Owner | Source |
|---|---|---|---|---|
| B1 | **2026-05-21** | v7.9 promotion-decision data freeze | operator | infra-plan §4.1, master-plan §2.2 |
| B2 | **2026-05-28** | Post-v7.9 T+7d baseline snapshot | operator | data-integrity §3.2 trigger (2) |
| B3 | **daily, starting now** | GA4 anomaly check (event volume + funnel breaks) | operator + GA4 MCP | analytics-observability epic |
| B4 | **2026-08-13** | Quarterly cross-layer test-discipline audit (initial run) | operator | test-coverage §6.2 |
| B5 | **2026-11-13** | Quarterly cross-layer test-discipline audit (recurring) | operator | test-coverage §6.2 |

### B1 — v7.9 promotion-decision data freeze (2026-05-21)

Required actions on the day:

1. `make integrity-check` — must report 0 findings
2. `make integrity-diff` — must report no regression vs 2026-05-14 anchor
3. `make documentation-debt` — must report ≤ baseline open count
4. `make measurement-adoption` — capture for the promotion record
5. `python3 scripts/membrane-status.py` — capture
6. Review last 14 days of `.claude/logs/gate-coverage.jsonl` — verify no `GATE_COVERAGE_ZERO` for any gate that previously fired
7. Decision: flip v7.8.x advisory gates to enforced (specific list in infra-plan §4.1)

### B2 — Post-v7.9 T+7d baseline (2026-05-28)

```bash
make snapshot-phase PHASE=post-v7-9-baseline FEATURE=framework-v7-8-branch-isolation
```

Compare against the 2026-05-14 pre-v7.9 baseline. Document deltas in a meta-analysis case study.

### B3 — Daily GA4 anomaly check

Possible since 2026-05-14 GA4 MCP connection (FIT-142, PR #362). Suggested daily query set:

```
mcp__ga4__getEvents period=last_24h
mcp__ga4__runReport metric=screen_view dimension=date period=last_7d
mcp__ga4__runReport metric=conversions period=last_24h
```

Flag day-over-day deltas > 30% as anomalies. No automation yet — operator runs in a session.

### B4 / B5 — Quarterly cross-layer test audit

Per test-coverage §6.2. Initial run 2026-08-13, then recurring every 90 days. Output: `docs/process/cross-layer-test-audit-YYYY-MM-DD.md`.

Assertions:
- Test count not declining
- Production-symbol coverage ≥ prior quarter
- No new zero-coverage directories
- Staleness markers (Test Plan files older than 90 days) trending down

## Feature-scope MUST items (require PM workflow)

These require Plan→Implement→Test cycles and cannot be inlined into the cadence-batch PR.

| ID | Title | Plan ref | RICE | Suggested work_type | Target ship |
|---|---|---|---|---|---|
| C1 | F14/F15 dispatch-test coverage push | test-coverage-master-plan §2.1 + §4.1 | (gates v7.9 promotion) | feature | **before 2026-05-21** |
| C2 | T6 — Web PR JS test gate (fitme-story CI) | test-coverage-master-plan T6 | **200.0** | enhancement (on analytics-observability) | 2026-05-21 |
| C3 | T2 — Sentry reachability test (iOS) | test-coverage-master-plan T2 | 80.0 | enhancement (test-coverage) | 2026-05-28 |

### C1 — F14/F15 dispatch-test coverage push

**Problem:** Mechanism A coverage telemetry is unreliable for 4 gates with zero dispatch tests + 5 zero-coverage gates. Without dispatch tests asserting each gate function fires, a keying drift (like the `created` vs `created_at` v7.8 incident) can silently zero out coverage.

**Suggested approach:** Each of the 9 gates needs a 5-line unit test in `tests/test_gate_dispatch.py` asserting (a) the gate function is called for matching inputs, (b) `gate-coverage.jsonl` receives a row, (c) the row has expected `gate=` and non-zero `candidates`.

**Why MUST:** v7.9 promotion criterion #1 in master plan §2.2 ("Mechanism A coverage validated for all gates"). Cannot promote on 2026-05-21 if these 9 gates remain unverified.

**Open `/pm-workflow framework-f14-f15-dispatch-test-coverage`** to start.

### C2 — T6 web PR JS test gate (fitme-story)

**Problem:** fitme-story runs **zero JS tests on PR** despite 119 React components + 27 routes. A regression in `Card.tsx` or `ProseLayout.tsx` ships to prod unchecked.

**Smallest viable shape:** add a single `npm test` step to fitme-story's `.github/workflows/ci.yml` + one smoke test asserting a representative page renders.

**Why MUST:** test-coverage-master-plan RICE = 200.0 (highest leverage item in the entire plan).

**Open** as enhancement on `analytics-observability` (current implementation phase) or as new feature `fitme-story-pr-test-gate`.

### C3 — T2 Sentry reachability test (iOS)

**Problem:** Zero tests on `SignInService.swift` + `SentryService.swift`. A pre-launch Sentry misconfiguration ships silently.

**Smallest viable shape:** one `XCTestCase` that asserts `SentryService.shared` is reachable + can capture a synthetic event without crashing.

**Why MUST:** test-coverage-master-plan RICE = 80.0; pre-launch crash gate.

**Open** as enhancement on the eventual `test-coverage` feature.

## How this file gets updated

- **Adding an item:** drop a row in the right table + a short section. Keep the doc under 200 lines.
- **Closing an item:** strike through the row + add `**Closed YYYY-MM-DD** via <PR or commit ref>`. Do NOT delete — historical visibility matters.
- **Cron link:** daily-checkpoint surfaces upcoming dates from this file (≤14 days). Update [`scripts/daily-integrity-checkpoint.py`](../../scripts/daily-integrity-checkpoint.py) if you add new date fields not following the table schema.
