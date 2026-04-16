# Parallel Code Write Safety — Research

> **Origin:** v5.1 parallel stress test, phase 5 — 3 agents edited project.pbxproj simultaneously
> **Status:** Implemented in v5.2B — see `.claude/shared/dispatch-intelligence.json` (mirror_pattern section) and `.claude/skills/pm-workflow/SKILL.md` (Mirror Pattern protocol)
> **Related:** `subagent-preflight-probe-research.md` (capability detection)

## Problem

When multiple subagents write Swift code in parallel, they risk:
1. **Overwriting each other's changes** if targeting the same file
2. **Corrupting file state** if a write fails mid-operation
3. **Type conflicts** if two agents define incompatible interfaces
4. **No rollback** if a merged result doesn't compile

Phase 5 of the stress test got lucky — agents wrote to different files. But as features mature, multiple agents WILL need to modify the same file (e.g., `AppTheme.swift` for new tokens, `AnalyticsProvider.swift` for new events, `DomainModels.swift` for new types).

## Solution 1: Snapshot / Rollback

**Before** any agent writes to a code file, the controller creates a snapshot of the target file. If the write fails or the build breaks, the controller restores the snapshot.

### Implementation

```
Controller (before dispatch):
  1. For each file the agent will touch:
     - Copy file to .build/snapshots/{agent_id}/{filename}
     - Record SHA256 hash
  2. Dispatch agent with file list

Controller (after agent returns):
  3. Build check:
     - If BUILD SUCCEEDED → delete snapshots, commit
     - If BUILD FAILED → restore all snapshots, log failure, redispatch

Controller (on agent error/timeout):
  4. Restore snapshots automatically
  5. Report which files were rolled back
```

### Pseudocode

```python
def safe_dispatch(agent, files_to_modify):
    # Snapshot
    snapshots = {}
    for file in files_to_modify:
        snapshots[file] = {
            'content': read(file),
            'hash': sha256(file)
        }
    
    # Dispatch
    result = dispatch(agent)
    
    # Verify
    if not build_succeeds():
        for file, snapshot in snapshots.items():
            write(file, snapshot['content'])
        log(f"Rolled back {len(snapshots)} files for {agent.id}")
        return FAILED
    
    return SUCCESS
```

### Cost
- Storage: negligible (few KB per Swift file)
- Time: ~100ms for snapshot + hash per file
- Benefit: **100% safe rollback** on any failure

## Solution 2: Code Region Isolation (Mirror Pattern)

Instead of agents writing directly to shared files, the controller **extracts the specific code region** each agent needs and gives them an isolated mirror. When the agent finishes, the controller **merges the result back** into the original file.

### The Pattern

```
Original file (AnalyticsProvider.swift):
  ┌─────────────────────────────────────┐
  │ Line 1-100: existing events          │
  │ Line 101-120: // MARK: - Profile     │ ← Agent A needs this region
  │ Line 121-200: existing events        │
  │ Line 201-220: // MARK: - Nutrition   │ ← Agent B needs this region
  │ Line 221-300: existing events        │
  └─────────────────────────────────────┘

Controller extracts:
  Agent A mirror: lines 101-120 (profile events)
  Agent B mirror: lines 201-220 (nutrition events)

Agents work on isolated snippets:
  Agent A: adds `profileGoalChanged` event to their mirror
  Agent B: adds `nutritionMealLogged` event to their mirror

Controller reconstructs:
  Original[101-120] = Agent A result
  Original[201-220] = Agent B result
  → Single write, no conflicts
```

### Implementation

```python
def isolated_dispatch(agents_with_regions):
    original = read(target_file)
    
    mirrors = {}
    for agent, region in agents_with_regions:
        # Extract region (by MARK comment or line range)
        mirror = extract_region(original, region.start_marker, region.end_marker)
        mirrors[agent.id] = {
            'content': mirror,
            'start_line': region.start_line,
            'end_line': region.end_line,
            'original_hash': sha256(mirror)
        }
        
        # Dispatch with mirror only (agent sees just their region)
        dispatch(agent, context=mirror, instruction="modify only this code region")
    
    # Wait for all agents
    results = await_all(agents)
    
    # Reconstruct
    reconstructed = original
    for agent_id, result in sorted(results.items(), key=lambda x: mirrors[x[0]]['start_line'], reverse=True):
        # Replace region (bottom-up to preserve line numbers)
        m = mirrors[agent_id]
        reconstructed = replace_lines(reconstructed, m['start_line'], m['end_line'], result.code)
    
    write(target_file, reconstructed)
    
    if not build_succeeds():
        write(target_file, original)  # rollback
        return FAILED
    
    return SUCCESS
```

### Region Detection Strategies

1. **MARK comments** — `// MARK: - Profile Events` ... next MARK
2. **Function boundaries** — extract a specific function by name
3. **Extension blocks** — `extension AnalyticsService { ... }`  
4. **Line range** — explicit (fragile, avoid)
5. **Semantic markers** — `// BEGIN:agent-region:profile` ... `// END:agent-region:profile`

### Advantages Over Direct Write

| Aspect | Direct Write | Mirror Pattern |
|---|---|---|
| Conflict risk | High (same file) | **Zero** (isolated regions) |
| Agent context | Entire file (wastes tokens) | **Just their region** (lean) |
| Merge quality | Git-style (may fail) | **Deterministic** (controller reconstructs) |
| Rollback | Manual | **Automatic** (original preserved) |
| Parallelism | Limited by file locks | **Unlimited** (different regions) |

## Combined System: Snapshot + Mirror

The two solutions are complementary:

```
1. SNAPSHOT the target file (Solution 1)
2. EXTRACT regions for each agent (Solution 2)  
3. DISPATCH agents with isolated mirrors
4. COLLECT results
5. RECONSTRUCT file from mirrors
6. BUILD CHECK
7. If PASS → commit, delete snapshot
8. If FAIL → ROLLBACK to snapshot, report error
```

This gives:
- **Isolation** during parallel writes (mirror pattern)
- **Safety net** if reconstruction fails (snapshot rollback)
- **Token efficiency** — agents only see their code region, not the entire file
- **Deterministic merging** — no git conflict resolution needed

## Relationship to v5.1 Principles

| Principle | Application |
|---|---|
| **Skill-on-demand** (Item 1) | Mirror pattern loads only the code region needed, not the entire file |
| **Cache compression** (Item 2) | Mirrors are compressed views of the full file |
| **Result forwarding** (Item 4) | Agent result forwarded to controller for reconstruction |
| **Systolic chains** (Item 7) | Agents see only their upstream input (mirror), not global state |

## Expected Impact

- **Unlock true parallel code writes** to shared files
- **~50% token reduction** per agent (mirror vs full file)
- **Zero merge conflicts** by design (not by luck)
- **Automatic rollback** on any failure

## Open Questions

1. How to handle agents that need to ADD new code (not modify existing regions)?
   - Controller pre-creates a placeholder region: `// MARK: - {feature} (agent will fill)`
2. How to handle cross-region dependencies (Agent A's type used in Agent B's region)?
   - Include type signatures in both mirrors as read-only context
3. What granularity for regions — function-level, section-level, or file-level?
   - Start with MARK-section level, refine based on experiment data
