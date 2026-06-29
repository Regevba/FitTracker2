# AN-1B.2 — `GA4_MCP_DISCONNECTED` — Design Notes

> v8.x docket **F20** (Theme C). Tracked: Linear **FIT-146**, thematic code
> **AN-1B.2**. Spec: [analytics-master-plan §8.3](../../../docs/master-plan/analytics-master-plan-2026-05-13.md).
> Convention: [`docs/process/cross-layer-item-naming-convention.md`](../../../docs/process/cross-layer-item-naming-convention.md).

## What it does

Commit-level connectivity **advisory**. When a commit stages analytics-affecting
code (`FitTracker/Services/Analytics/*`, `fitme-story/src/lib/control-room/analytics.ts`,
or `docs/product/analytics-taxonomy.csv`) and GA4 MCP is **not reachable via env**
— `GA4_PROPERTY_ID` set **and** `GOOGLE_APPLICATION_CREDENTIALS` pointing at an
existing file — it prints a `[ADVISORY] GA4_MCP_DISCONNECTED` line to stderr.

## Advisory-only by design (no calibration ladder)

Unlike AN-1B.1, this gate has **no advisory→enforced flip**. Per §8.3 it is
*"advisory only — never blocks commits, even when promoted. The gate exists to
surface drift, not to gate analytics work behind operator GA4 setup."* It always
routes to stderr, never to `errors[]`. Therefore there is **no promotion criteria,
no 14-day window, and no cadence-ledger entry** — nothing to flip.

## Operator dependency (expected pre-launch state)

Pre-launch the GA4 env is typically unset, so the advisory is **expected** to fire
on analytics commits until the operator wires GA4 (register item A1 + set the two
env vars). That is the intended signal — it reminds whoever touches analytics code
that GA4 ingest isn't connected yet. It is not a blocker and not a bug.

## Implementation

- `check_ga4_mcp_connectivity(staged_files, *, coverage, repo_root)` in
  [`scripts/check-state-schema.py`](../../../scripts/check-state-schema.py).
- Path match via `_matches_any_glob` against `ANALYTICS_AFFECTING_GLOBS`.
- Mechanism A coverage: `candidate` always; `skip("no_analytics_files_staged")`
  when not relevant; `checked` when a connectivity check runs.
- Commit-level dispatch in `main()` (staged mode), after CSV_TAXONOMY_DRIFT.
- Tests: [`scripts/tests/test_ga4_mcp_disconnected.py`](../../../scripts/tests/test_ga4_mcp_disconnected.py) — 6 (skip / disconnected / csv-affecting / connected / creds-missing / always-advisory).

## Reversibility

Remove the dispatch block in `main()` (or early-return the function). <2 min.
No flag — advisory-only means there's nothing to demote.
