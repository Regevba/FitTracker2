# Dispatch Intelligence v5.2 — Task Breakdown

| ID | Title | Type | Complexity | Status |
|---|---|---|---|---|
| T1 | Create dispatch-intelligence.json | config | lightweight | complete |
| T2 | Update skill-routing.json v5.0 | config | lightweight | complete |
| T3 | Bump framework-manifest.json to v5.2 | config | lightweight | complete |
| T4 | Update PM workflow SKILL.md dispatch protocol | docs | standard | complete |
| T5 | Update research docs status | docs | lightweight | complete |
| T6 | Create tasks.md + update state | config | lightweight | complete |
| T7 | Validation: verify JSON configs parse correctly | test | lightweight | complete |
| T8 | Push + update case study | config | lightweight | pending |

## Key Finding During Implementation

R6 permission fix (settings.json) does NOT propagate to subagents. All 3 lightweight config tasks (T1-T3) were dispatched as subagents and ALL failed with permission denied on `.claude/shared/`. Controller executed all 3 directly.

This validates the probe system's design: the `permission_table` must route `.claude/` paths to controller regardless of what settings.json says. Added note to dispatch-intelligence.json.
