# Session Summary — 2026-04-14 (v5.1 SoC-on-Software)

> **Branch:** `claude/load-v5.1-plan-oApRG`
> **Final commit:** `1fd849c` (+ this handoff commit)
> **Base:** `7288faa` (v5.0 — skill-on-demand + cache compression)
> **Status:** All v5.1 work committed and pushed. Item 8 (big.LITTLE) designed but not yet implemented.
> **Session theme:** Complete SoC-on-Software optimization suite (items 3-7) + design Item 8

---

## Quick Stats

| Metric | Value |
|--------|-------|
| **Commits this session** | 2 (v5.1 implementation + handoff) |
| **Files modified** | 5 |
| **Lines added** | ~515 |
| **Lines removed** | ~48 |
| **Framework version** | 5.0 → 5.1 |
| **SoC items completed** | 2/7 → 7/7 |
| **New protocol sections** | 5 (in pm-workflow/SKILL.md) |

---

## What Was Built

### v5.1 — Five SoC-on-Software Optimizations (Items 3-7)

All five items implemented in a single commit (`1fd849c`), backward-compatible with v5.0.

| Item | Name | Hardware Inspiration | What It Does |
|------|------|---------------------|-------------|
| 5 | Model Tiering | ANE mixed precision (FP16/FP32) | Sonnet for mechanical phases, opus for judgment phases. Advisory per-phase recommendation. |
| 3 | Batch Dispatch | TPU weight-stationary dataflow | Load template once, iterate N targets. 5x fewer dispatches. Supports audit, design compliance, analytics taxonomy sync. |
| 4 | Result Forwarding | M-series UMA zero-copy | Pass skill output inline to next skill. Disk write still happens (audit trail) but next skill reads from context. 5 eligible chains defined. |
| 6 | Speculative Pre-loading | CPU branch prediction | Pre-load likely-next-skill cache (compressed_view only) on skill start. 10-entry successor map with confidence scores 0.85-0.98. Misprediction cost bounded at 3K tokens. |
| 7 | Systolic Chains | TPU systolic array | Isolated pipeline execution. Hybrid model: full isolation for UX/design chains, partial isolation for implementation. 3 defined chains. |

### Files Changed

| File | Changes |
|------|---------|
| `.claude/shared/skill-routing.json` | v3.0→4.0. Added `model_tiering`, `batch_dispatch`, `result_forwarding`, `speculative_preload`, `systolic_chains`. Converted `phase_skills` from arrays to objects with `.skills` + `.model_tier`. |
| `.claude/skills/pm-workflow/SKILL.md` | v5.0→5.1 in frontmatter. Updated skill loading step 1 for array/object format. Added 5 protocol sections (~150 lines). |
| `.claude/shared/framework-manifest.json` | v1.1→1.2. Added 5 capability flags + 5 optimization entries in `v5_soc_optimizations`. |
| `docs/skills/evolution.md` | Header updated. Added section 23 documenting v5.1 with comparison table, per-item descriptions, dependency map, config summary. |
| `docs/architecture/soc-software-architecture-research.md` | All 7 items now show "Implemented". Next Steps updated. |

---

## Unsaved Item — Item 8: big.LITTLE Task Dispatch (MUST IMPLEMENT NEXT SESSION)

### Context

User described this during the session but it was NOT persisted from a previous session's conversation. The concept:

**ARM big.LITTLE applied to task dispatch** — classify tasks by complexity before dispatch, route to serial or parallel execution accordingly.

### The Concept

Modern ARM CPUs have two core types:
- **P-cores (Performance)** — high-power cores for heavy workloads
- **E-cores (Efficiency)** — low-power cores for light workloads

The OS scheduler classifies each thread and routes it to the appropriate core type.

### Hub Equivalent

Add a **task complexity classifier** that runs before the existing Parallel Task Dispatch (SKILL.md line 674). The classifier inspects each ready task and assigns it to one of two execution lanes:

- **Serial lane (P-core):** Large/complex tasks that need full attention
  - Many files changed (>5)
  - New models or services
  - High token consumption (architecture decisions, new UI screens)
  - Cross-feature dependencies
  - Judgment-intensive work (review, research synthesis)

- **Parallel lane (E-core):** Small/simple tasks that can safely run concurrently
  - Config changes, label updates, CSV syncs
  - Single-file edits
  - Low token budget (boilerplate, template application)
  - No cross-feature dependencies
  - Mechanical work (file generation, token checks)

### How It Would Work

1. When Phase 4 computes the ready set (tasks with all deps satisfied):
2. **NEW: Complexity gate** — classify each ready task:
   - Check `files_changed_estimate` (from task definition or heuristic)
   - Check `task_type` (from task tags or skill routing)
   - Check `token_budget_estimate` (low/medium/high)
   - Check `cross_feature_deps` (boolean)
3. Route to lanes:
   - Tasks classified as "lightweight" → batch into parallel lane (E-core)
   - Tasks classified as "heavyweight" → queue in serial lane (P-core)
4. Execute parallel lane first (fast, clears backlog), then serial lane

### Implementation Plan (for next session)

**skill-routing.json** — Add `task_complexity_gate`:
```json
"task_complexity_gate": {
  "enabled": true,
  "version": "1.0",
  "description": "ARM big.LITTLE analog: classify tasks by complexity, route to serial (P-core) or parallel (E-core) execution.",
  "classification": {
    "heavyweight_indicators": [
      "files_changed > 5",
      "new_model_or_service",
      "token_budget == high",
      "cross_feature_deps == true",
      "requires_judgment == true"
    ],
    "lightweight_indicators": [
      "files_changed <= 2",
      "config_or_label_change",
      "token_budget == low",
      "no_cross_feature_deps",
      "mechanical_work == true"
    ],
    "threshold": "any 2 heavyweight indicators → serial lane"
  },
  "execution_order": "parallel_first_then_serial",
  "model_tier_override": {
    "lightweight": "sonnet",
    "heavyweight": "opus"
  }
}
```

**pm-workflow/SKILL.md** — Add "Hybrid Task Dispatch (big.LITTLE)" section before the existing "Parallel Task Dispatch" section, with the classification protocol and lane routing logic.

**evolution.md** — Add to section 23 or create section 24 for Item 8.

**soc-software-architecture-research.md** — Add Item 8 to the priority table.

### Connection to Existing v5.1 Items

Item 8 naturally composes with:
- **Item 5 (Model Tiering):** lightweight tasks → sonnet, heavyweight → opus
- **Item 3 (Batch Dispatch):** multiple lightweight tasks in parallel lane can batch
- **Item 7 (Systolic Chains):** heavyweight tasks in serial lane follow chain protocol

---

## Branch State

```
Branch: claude/load-v5.1-plan-oApRG
Commits ahead of main: 2+ (v5.0 base + v5.1 + handoff)
Working tree: clean (after this commit)
Remote: pushed to origin/claude/load-v5.1-plan-oApRG
```

## Resume Instructions

1. `git checkout claude/load-v5.1-plan-oApRG`
2. Read this file for full context
3. **FIRST TASK — Task Complexity Classifier:** Build the classification engine that inspects each ready task and assigns it to a serial (P-core) or parallel (E-core) lane. This is the core mechanism of Item 8. Deliverables:
   - Add `task_complexity_gate` to `skill-routing.json` with classification heuristics (files_changed, new_model_or_service, token_budget, cross_feature_deps, requires_judgment) and threshold rules
   - Add "Task Complexity Classifier" section to `pm-workflow/SKILL.md` that runs BEFORE the existing "Parallel Task Dispatch" section (line 674). The classifier triages each ready task, then the dispatch section executes the two lanes (parallel-first, then serial)
   - Compose with Item 5 (model tiering): lightweight→sonnet, heavyweight→opus
   - Compose with Item 3 (batch dispatch): multiple lightweight tasks in parallel lane can batch
   - Update `framework-manifest.json` capability flags + `evolution.md` status
4. **Priority 2:** Merge v5.1 branch to main when ready
5. **Priority 3:** Measure combined savings from all 8 items (Next Steps #6 in research doc)

## Key File Paths (Quick Reference)

| Purpose | Path |
|---------|------|
| Central config | `.claude/shared/skill-routing.json` (v4.0) |
| Hub skill | `.claude/skills/pm-workflow/SKILL.md` |
| Manifest | `.claude/shared/framework-manifest.json` (v1.2) |
| Evolution docs | `docs/skills/evolution.md` |
| Research | `docs/architecture/soc-software-architecture-research.md` |
| This handoff | `docs/master-plan/session-summary-2026-04-14-v5.1.md` |
