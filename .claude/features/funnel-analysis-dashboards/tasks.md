# Tasks — funnel-analysis-dashboards (Enhancement of analytics-observability)

> **Scope reality (Phase 0.1 check):** the 5 canonical funnel definitions + 8 conversion
> events + Looker templates already shipped 2026-06-01 in
> [`docs/setup/ga4-funnels-and-conversions-runbook.md`](../../../docs/setup/ga4-funnels-and-conversions-runbook.md).
> This enhancement does NOT redefine them. It runs them against **live GA4 data**, makes the
> defs **machine-readable**, and maps each funnel to the **kill-criteria** it unblocks.
> Operator-only GA4-console / Looker wiring stays out of scope (already documented).

## Deliverables

1. `docs/product/funnel-definitions.json` — machine-readable extraction of the 5 funnels (steps = ordered event names, owner, evaluable-now flag, kill-criteria linkage).
2. `docs/setup/ga4-funnel-analysis-2026-06-23.md` — live drop-off report computed via GA4 MCP, with a per-funnel evaluable-now vs TestFlight-blocked verdict.
3. `scripts/tests/test_funnel_definitions.py` — schema + cross-reference validation for `funnel-definitions.json` (steps reference real taxonomy events; ids unique; kill-criteria links present).
4. Runbook + backlog reconciliation (point the runbook at the new machine-readable defs + analysis; move backlog row to Done).

## Task list

| ID | Title | Type | Skill | Effort (d) | Depends on | Complexity |
|----|-------|------|-------|-----------|-----------|-----------|
| T1 | Pull live GA4 event volumes (28d) + per-step counts for all 5 funnels | analytics | analytics | 0.25 | — | lightweight |
| T2 | Author `docs/product/funnel-definitions.json` (machine-readable, 5 funnels, kill-criteria linkage) | data | analytics | 0.25 | T1 | lightweight |
| T3 | Author `docs/setup/ga4-funnel-analysis-2026-06-23.md` — live drop-off %, evaluable-now verdicts | docs | analytics | 0.5 | T1, T2 | standard |
| T4 | Add `scripts/tests/test_funnel_definitions.py` — JSON schema + taxonomy cross-ref validation | test | qa | 0.25 | T2 | lightweight |
| T5 | Reconcile runbook (link new defs+analysis) + backlog row → Done | docs | dev | 0.1 | T3 | lightweight |

**Total estimated effort:** ~1.35 day (analysis-only; no app/platform code).

## Notes

- **No new analytics events** — guardrail. Pure read/analysis + data extraction.
- **T1 uses GA4 MCP** (`mcp__ga4__getEvents` / `runReport`) in-session; the report records the query window + run timestamp for reproducibility (it is not an automated cron — that needs GA4 Data API creds = operator setup, out of scope).
- **platforms_tested:** the only automated test (T4) validates the JSON data contract; this is a data/docs enhancement with no iOS/web/backend product code. Will set `backend:false/ios:false/web:false/ai:false` is invalid for the enforced gate on complete — so T4's data-contract test is the platform-test surface; classify under `backend` (analytics data layer) OR apply the framework-meta-style exemption. Decided at Phase 5.
