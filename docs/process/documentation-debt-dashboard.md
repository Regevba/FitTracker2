# Documentation Debt Dashboard

> Groundwork for Gemini audit Tier 3.2.
> Status: **baseline dashboard shipped; trend view waits on scheduled cycle history**.

## Purpose

Track the parts of the documentation corpus that are still structurally weak:

- missing case-study metadata
- missing explicit dispatch-pattern declarations
- missing kill-criteria restatement
- feature state without case-study linkage
- too little integrity-cycle history to show trend lines yet

## Source of truth

Generated report:

- `.claude/shared/documentation-debt.json`

Generator:

```bash
python3 scripts/documentation-debt-report.py \
  --output .claude/shared/documentation-debt.json
```

Convenience target:

```bash
make documentation-debt
```

## Current shape

The report is intentionally split into:

- `summary` — counts and readiness state
- `coverage` — raw numerator/denominator metrics
- `debt_items` — actionable debt buckets with examples
- `integrity_cycle` — whether trend data is actually mature enough to trust

## Why it is only a baseline today

Trend readiness is intentionally conservative. As of **2026-04-23**, the report
only counts snapshots that were explicitly marked as scheduled 72-hour cycle
artifacts. Ad hoc local/manual snapshots remain useful evidence, but they do
not unlock trend mode.

The Integrity Cycle began on **2026-04-21** and the repo currently has only its
baseline snapshot file, with zero scheduled cycle snapshots carrying the new
trend-readiness marker. That means:

- point-in-time debt metrics are valid
- trend charts are **not** yet valid
- the first meaningful trend window appears after three scheduled cycle snapshots

Until then, the dashboard should be read as "baseline debt inventory", not
"documentation trend analysis".
