# Dispatch Intelligence (v5.2 Sub-Project A) — Design Spec

> **Date:** 2026-04-16
> **Origin:** v5.1 parallel stress test findings (case study: `docs/case-studies/v5.1-parallel-stress-test-case-study.md`)
> **Goal:** Smarter subagent dispatch — score tasks, probe capabilities, route to the right model, cap tool usage. Eliminate 100% permission failure rate and normalize 23x execution time variance.
> **Scope:** Framework infrastructure. No UI, no Swift code, no user-facing changes.

---

## Problem

The v5.1 stress test (4 features × 8 phases × 54 minutes) revealed:

1. **100% permission failure rate** — 16/31 subagent dispatches couldn't write to `.claude/` paths. Controller batched all state updates manually, adding ~10 min overhead.
2. **23x execution time variance** — agents ranged from 43s to 987s for similar tasks. More tool uses ≠ better quality.
3. **No model differentiation** — all agents used Sonnet regardless of task complexity. Config tasks and architecture decisions got equal compute.
4. **No capability verification** — controller discovered permission failures only after the agent wasted time trying.

## Solution: 3-Stage Dispatch Pipeline

```
Task arrives → [1] Score complexity → [2] Probe capability → [3] Dispatch with budget
```

Each stage is independent, composable, and configured via a single JSON file.

---

## Component 1: Static Complexity Scoring

### Task Schema Extension

Every task in `tasks.md` gets a `complexity` field:

```markdown
| ID | Title | Type | Skill | Effort | Depends On | Complexity | Status |
| T1 | NotificationService | service | dev | 1.0d | — | standard | pending |
| T2 | PreferencesStore | model | dev | 0.5d | — | lightweight | pending |
| T3 | PermissionPrimingView | ui | dev | 0.5d | T1 | standard | pending |
```

### Scoring Rules

| Tier | Score | Criteria | Examples |
| --- | --- | --- | --- |
| `lightweight` | 1-3 | Single file, config/metadata, no architecture | xcassets, Makefile target, metadata doc, analytics events |
| `standard` | 4-6 | 1-2 Swift files, clear spec, follows existing patterns | New service class, SwiftUI view, parser implementation |
| `heavyweight` | 7-10 | Multi-file, shared file edits, architecture decisions, new protocols | Orchestrator + UI + model, refactors touching 5+ files |

### Who Assigns Complexity

The task author (human or agent writing `tasks.md`) assigns complexity at task creation time. This is a conscious decision, not an automated inference.

### Validation Flag (Measure Before Optimizing)

Static scoring is an assumption. To validate it, every dispatch logs:

```json
{
  "dispatch_id": "uuid",
  "task_id": "T1",
  "predicted_complexity": "standard",
  "actual_tool_uses": 15,
  "actual_duration_seconds": 102,
  "result": "DONE",
  "quality": "no_rework"
}
```

At the end of each stress test, compute correlation between `predicted_complexity` tier and `actual_tool_uses`. If the correlation coefficient drops below 0.6 across 20+ dispatches, the system flags: `"RECOMMENDATION: Switch to dynamic complexity scoring. Static prediction accuracy: {rate}%"`.

This flag lives in `dispatch-intelligence.json` under `validation`:

```json
{
  "validation": {
    "mode": "measure",
    "switch_threshold": 0.6,
    "min_sample_size": 20,
    "flag_key": "complexity_prediction_needs_review"
  }
}
```

---

## Component 2: Capability Probe (Hybrid)

### Stage 1: Permission Table Lookup (instant, ~10ms)

Controller reads `.claude/settings.json` and builds a permission map:

```json
{
  "permission_table": {
    "known_writable": [
      "FitTracker/**",
      "FitTrackerTests/**",
      "docs/**",
      "dashboard/**",
      "website/**",
      "scripts/**",
      ".claude/features/**",
      ".claude/shared/**"
    ],
    "known_readonly": [
      ".claude/skills/**",
      ".claude/integrations/**",
      ".claude/cache/**"
    ],
    "requires_probe": []
  }
}
```

For each file the task will touch:
- Path matches `known_writable` → `canWrite: true`
- Path matches `known_readonly` → `canWrite: false`, route to controller
- Path matches nothing → proceed to Stage 2

### Stage 2: Real Micro-Probe (only for ambiguous paths)

Dispatch a minimal agent:

```
"Test these operations and return results immediately:
 1. Write 'probe' to {target_path}/.probe-test — report canWrite
 2. Run 'echo probe' via Bash — report canBash
 3. Read {dependency_path} — report canRead
 Delete the probe file if created. Do nothing else.
 Return: { canWrite: bool, canBash: bool, canRead: bool }"
```

- Model: haiku (cheapest)
- Timeout: 15 seconds
- Tool budget: 5

If probe fails or times out → route that path to controller.

### Decision Matrix

| Table Lookup | Probe Result | Action |
| --- | --- | --- |
| writable | — (skip probe) | Dispatch to subagent |
| readonly | — (skip probe) | Controller handles directly |
| ambiguous | canWrite: true | Dispatch to subagent |
| ambiguous | canWrite: false | Controller handles directly |
| ambiguous | timeout | Controller handles directly |

---

## Component 3: Model Routing

### Tier Configuration

```json
{
  "model_routing": {
    "lightweight": {
      "model": "haiku",
      "tool_budget": 10,
      "timeout_seconds": 60,
      "review_required": false,
      "escalation_on_budget": "DONE_WITH_CONCERNS"
    },
    "standard": {
      "model": "sonnet",
      "tool_budget": 25,
      "timeout_seconds": 180,
      "review_required": true,
      "escalation_on_budget": "DONE_WITH_CONCERNS"
    },
    "heavyweight": {
      "model": "opus",
      "tool_budget": 50,
      "timeout_seconds": 600,
      "review_required": true,
      "escalation_on_budget": "BLOCKED"
    }
  }
}
```

### Escalation Protocol

When an agent hits its tool budget:

1. Agent reports `DONE_WITH_CONCERNS` (lightweight/standard) or `BLOCKED` (heavyweight)
2. Controller evaluates the partial output:
   - **Usable** → accept, log `budget_constrained_success`
   - **Incomplete but close** → redispatch same tier with focused prompt
   - **Fundamentally stuck** → redispatch at next tier up
3. Maximum 1 escalation per task (prevent infinite loops)

### Escalation Path

```
lightweight (haiku) → standard (sonnet) → heavyweight (opus) → BLOCKED (report to user)
```

---

## Component 4: Tool Use Budget Enforcement

### Prompt Injection

Every subagent prompt includes this line at the end of the "Your Job" section:

```
BUDGET: You have {N} tool uses for this task. If you reach the limit,
stop and report DONE_WITH_CONCERNS with what you completed so far.
Focus on the critical path — don't explore alternatives when the
primary approach is working.
```

### Budget Values (from stress test data)

| Tier | Budget | Rationale |
| --- | --- | --- |
| Probe | 5 | Read + write + delete = 3 uses, 2 margin |
| Lightweight | 10 | F2's 7 uses succeeded; 10 gives 43% margin |
| Standard | 25 | F1's 15 uses succeeded; 25 gives 67% margin |
| Heavyweight | 50 | F1 phase 7's 34 uses for complex work; 50 gives 47% margin |

### Tracking

Controller logs actual tool uses per dispatch. Over time, this data refines budget limits:
- If >30% of agents in a tier hit the budget → increase budget by 25%
- If <5% of agents in a tier use more than half the budget → decrease budget by 25%

---

## Component 5: Full Configuration File

### `.claude/shared/dispatch-intelligence.json`

```json
{
  "version": "1.0",
  "framework_version": "5.2",
  "updated": "2026-04-16",

  "permission_table": {
    "known_writable": [
      "FitTracker/**",
      "FitTrackerTests/**",
      "docs/**",
      "dashboard/**",
      "website/**",
      "scripts/**",
      ".claude/features/**",
      ".claude/shared/**"
    ],
    "known_readonly": [
      ".claude/skills/**",
      ".claude/integrations/**",
      ".claude/cache/**"
    ]
  },

  "model_routing": {
    "lightweight": {
      "model": "haiku",
      "tool_budget": 10,
      "timeout_seconds": 60,
      "review_required": false,
      "escalation_on_budget": "DONE_WITH_CONCERNS"
    },
    "standard": {
      "model": "sonnet",
      "tool_budget": 25,
      "timeout_seconds": 180,
      "review_required": true,
      "escalation_on_budget": "DONE_WITH_CONCERNS"
    },
    "heavyweight": {
      "model": "opus",
      "tool_budget": 50,
      "timeout_seconds": 600,
      "review_required": true,
      "escalation_on_budget": "BLOCKED"
    }
  },

  "probe": {
    "model": "haiku",
    "tool_budget": 5,
    "timeout_seconds": 15,
    "trigger": "path_not_in_permission_table"
  },

  "validation": {
    "mode": "measure",
    "switch_threshold": 0.6,
    "min_sample_size": 20,
    "flag_key": "complexity_prediction_needs_review",
    "log_to": "stress-test-checkpoint.json"
  },

  "budget_tuning": {
    "increase_trigger": 0.30,
    "decrease_trigger": 0.05,
    "adjustment_factor": 0.25
  }
}
```

---

## Files Changed

| File | Action |
| --- | --- |
| `.claude/shared/dispatch-intelligence.json` | **Create** — full config above |
| `.claude/shared/skill-routing.json` | **Update** — add `dispatch_intelligence_version: "1.0"` reference |
| `.claude/skills/pm-workflow/SKILL.md` | **Update** — dispatch protocol references dispatch-intelligence.json |
| `docs/architecture/subagent-preflight-probe-research.md` | **Update** — status from "research" to "implemented in v5.2" |
| `.claude/shared/framework-manifest.json` | **Update** — bump framework version to 5.2 |

---

## What This Does NOT Include

- **Dynamic complexity scoring** — deferred behind validation flag. Ship static, measure, then decide.
- **Code Region Mirror Pattern** — Sub-Project B, separate spec.
- **Snapshot/Rollback** — Sub-Project B, separate spec.
- **Any Swift code or UI changes** — this is framework infrastructure only.

---

## Success Criteria

| Metric | Baseline (v5.1) | Target (v5.2) |
| --- | --- | --- |
| Permission failure rate | 100% (16/16) | <5% |
| Execution time variance | 23x (43s-987s) | <5x |
| Wasted compute (permission-blocked) | ~30% of subagent time | <5% |
| Model differentiation | 0% (all Sonnet) | >50% of dispatches use appropriate tier |
| Complexity prediction accuracy | unmeasured | >60% (validation flag threshold) |

---

## Testing Plan

1. **Unit validation:** Create dispatch-intelligence.json, verify permission table matches settings.json
2. **Integration test:** Dispatch 4 tasks of different complexity, verify model routing works
3. **Stress test rerun:** Repeat the 4-feature parallel test with dispatch intelligence active, compare metrics to v5.1 baseline
4. **Validation flag check:** After 20+ dispatches, check complexity prediction accuracy
