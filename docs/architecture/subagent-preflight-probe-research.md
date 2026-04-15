# Subagent Pre-Flight Capability Probe — Research

> **Origin:** v5.1 parallel stress test, phase 4 observation
> **Status:** Research idea — to be prototyped after experiment completes

## Problem

When dispatching 4 parallel subagents, 100% of `.claude/` writes fail. The controller wastes subagent compute on tasks that will hit permission walls, then must redo the work centrally. This is a ~30% overhead tax on every parallel batch.

## Proposed Solution: Pre-Flight Probe

Before dispatching the real task, send a **compressed capability probe** — a miniature version of the task that tests whether the subagent can handle it. The probe mirrors the task's complexity signature (file paths, tool requirements, resource needs) but completes in seconds.

### Probe Design

```
Controller → Subagent (probe):
  "Can you complete this task? Verify by attempting these micro-operations:
   1. Write a 1-line file to {target_path} → confirms write permission
   2. Run `echo test` via Bash → confirms bash access
   3. Read {dependency_file} → confirms read access
   Return: { canWrite: bool, canBash: bool, canRead: bool }"
```

If the probe fails, the controller:
- Handles that file path directly (no subagent)
- Or re-routes the task to a different execution strategy
- Or adjusts the task scope to avoid the blocked operation

### Complexity-Weighted Priority System

Extend the probe with a **task complexity classifier** that determines subagent allocation:

```
Task Complexity = f(files_touched, tool_requirements, domain_knowledge_needed)

Tiers:
  LIGHTWEIGHT (score 1-3): file creation, config edits, metadata
    → Dispatch to cheapest model (haiku)
    → Can run many in parallel
    
  STANDARD (score 4-6): PRD writing, UX specs, task breakdowns
    → Dispatch to standard model (sonnet)
    → Run 2-4 in parallel
    
  HEAVYWEIGHT (score 7-10): Swift code generation, architecture decisions, multi-file refactors
    → Dispatch to strongest model (opus)
    → Run 1-2 max, with review gates
```

### Adaptive Workload Balancing

When running N parallel tasks under resource pressure:

1. **Score each task** by complexity + priority
2. **Heavy tasks get full resources** (opus model, detailed prompt, review)
3. **Light tasks get reduced resources** (haiku model, compressed prompt, skip review)
4. **Medium tasks adapt** — start with sonnet, escalate to opus if blocked

This means the overall workload continues at full speed, but resource allocation is proportional to task importance. A metadata file and a Swift architecture decision don't deserve equal compute.

### Implementation in v5.2

```python
# Pseudocode for adaptive dispatch
for task in batch:
    probe_result = probe(task.target_paths, task.tool_needs)
    complexity = score(task)
    
    if not probe_result.can_complete:
        controller_queue.append(task)  # Handle centrally
        continue
    
    if complexity <= 3:
        dispatch(task, model="haiku", review=False)
    elif complexity <= 6:
        dispatch(task, model="sonnet", review=True)
    else:
        dispatch(task, model="opus", review=True, checkpoint=True)
```

## Expected Impact

- **30% reduction** in wasted subagent compute (eliminate permission-blocked work)
- **2x throughput** for mixed-complexity batches (light tasks don't consume opus capacity)
- **Better quality** for heavy tasks (more resources allocated where they matter)

## Relationship to v5.1 SoC Principles

This maps directly to the **big.LITTLE hybrid dispatch** principle (Item 8):
- Lightweight tasks → E-core (haiku, parallel, no review)
- Heavyweight tasks → P-core (opus, serial, with review)

The pre-flight probe is the **branch prediction** analog (Item 6) — predict whether a task will succeed before committing resources.
