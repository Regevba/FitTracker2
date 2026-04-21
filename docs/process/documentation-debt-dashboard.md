# Documentation Debt Dashboard

> Groundwork for Gemini audit Tier 3.2.
> Status: **baseline dashboard shipped; trend view waits on multiple integrity cycles**.

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

The Integrity Cycle began on **2026-04-21** and the repo currently has only its
baseline snapshot. That means:

- point-in-time debt metrics are valid
- trend charts are **not** yet valid
- the first meaningful trend window appears after roughly 2-3 cycles

Until then, the dashboard should be read as "baseline debt inventory", not
"documentation trend analysis".
