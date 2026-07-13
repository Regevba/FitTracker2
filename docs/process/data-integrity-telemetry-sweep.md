# Data-Integrity + Telemetry Sweep

> **The codified answer to "is every layer healthy right now?"** One command,
> one verdict per layer. Replaces running the checks from memory.

```bash
make integrity-sweep
```

Producer: [`scripts/integrity-telemetry-sweep.py`](../../scripts/integrity-telemetry-sweep.py).
Exit code **0** if no layer FAILs (WARN/INFO don't fail the run), **1** if any
layer FAILs — so a human, a cron, or an agent all get the same answer, and it can
gate a pipeline. `--no-refresh` reads the existing ledgers instead of re-running
each producer; `--json` emits machine-readable output.

## Why this exists

The cross-layer sweep was previously performed ad-hoc — a sequence of `make`
targets and manual reads that lived only in whoever ran it. That is fragile: a
layer gets forgotten, thresholds drift, and "healthy" means different things to
different runs. This script pins the layer list, the producer for each, and the
PASS/WARN/FAIL threshold, so the check is repeatable and auditable.

It is **read-only** and **aggregating** — it does not fix anything; it runs each
layer's existing producer and reports. Every layer degrades gracefully (a missing
`gh`, an unreachable endpoint, or an absent ledger yields WARN/INFO, never a
crash).

## The layers

| # | Layer | Producer | PASS means | Fails on |
|---|---|---|---|---|
| 1 | Framework integrity | `integrity-check.py` | 0 findings | any finding → **FAIL** |
| 2 | Regression vs anchor | `integrity-diff.py` | no regression vs the 2026-05-14 anchor | `REAL_REGRESSION` → **FAIL**; baseline missing → WARN |
| 3 | Adoption telemetry | `refresh-gate-last-fired.py` + `measurement-adoption-report.py` | gate index has 0 malformed rows | malformed rows / empty index → WARN |
| 4 | Gate calibration | `gate-last-fired.json` | no gate with 0 candidates (the `GATE_COVERAGE_ZERO` 0-candidate mis-wire class) | a registered gate that never reaches a candidate → WARN |
| 5 | Documentation debt | `documentation-debt-report.py` | open items ≤ baseline (1) | above baseline → WARN |
| 6 | Cross-repo sync | R17 state-sync-health endpoint | deployed fitme-story mirror fresh (<6h) + state count matches | stale / unreachable → WARN |
| 7 | CI automation (bot PRs) | `check-bot-pr-health.py` | no deadlocked automated PRs | a deadlocked snapshot PR → **FAIL** |
| 8 | Analytics / GA4 | — | (INFO) | needs the GA4 MCP — run the B3 check separately |
| 9 | Backup checkpoint | `integrity-checkpoint-ledger.jsonl` | (INFO) reports the last daily-checkpoint date | — |
| 10 | Upcoming cadence | `must-have-cadence-followups.md` | (INFO) calendar items ≤14 days | — |

### Notes on the INFO layers

- **Analytics / GA4 (layer 8)** cannot run in a plain script — it needs the GA4
  MCP (an agent/interactive context). The sweep prints a pointer; run the anomaly
  check per [`docs/setup/ga4-funnels-and-conversions-runbook.md`](../setup/ga4-funnels-and-conversions-runbook.md)
  (cadence **B3**). Look for: events flowing through today, the onboarding + auth
  funnels intact, screen-prefix convention held, no >30% day-over-day anomaly.
- **Upcoming cadence (layer 10)** reuses the daily checkpoint's
  `upcoming_followups()` parser. **Known limitation:** that parser matches
  `**YYYY-MM-DD**` dates but not `~`-prefixed *approximate* dates
  (e.g. `**~2026-07-23**`), so an approximate-dated follow-up may not surface here
  until its date is firmed up. Cross-check
  [`must-have-cadence-followups.md`](../../.claude/shared/must-have-cadence-followups.md)
  directly for the authoritative list.

## Relationship to the other sweeps

- **`make preflight`** (v7.8.6) — *before* starting work; aggregates pre-work
  gates (ssh-agent, PR-cache, branch isolation, …). Different intent.
- **`scripts/daily-integrity-checkpoint.py`** — the scheduled daily snapshot:
  runs the 6 core `make` targets, writes off-disk backups, appends the ledger,
  and probes cross-repo sync. It *persists* state; `integrity-sweep` *reads* the
  current state into a single verdict. The checkpoint is the historian; the sweep
  is the dashboard.
- **`make membrane-status`** — active-feature + recent-gate-firing readout, not a
  cross-layer health verdict.

Run `integrity-sweep` any time you want the current answer (start of a session, a
"is everything green?" spot check, before a release). Wire it into a cron or the
daily checkpoint if you want the verdict recorded over time.
