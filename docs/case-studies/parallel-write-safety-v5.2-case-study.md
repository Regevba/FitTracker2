# Case Study: Parallel Write Safety — Framework v5.2 Sub-Project B

**Date written:** 2026-04-16

> **Core question:** Can deterministic file-level isolation (snapshot/rollback + region-based mirror pattern) eliminate the luck dependency from parallel multi-agent writes to shared files?

## 1. Summary Card

| Field | Value |
|---|---|
| Feature | Parallel Write Safety (v5.2 Sub-Project B) |
| Framework version | v5.2 |
| Work type | Feature (framework infrastructure) |
| Complexity | Files created: 1 (tasks.md), Files modified: 3 (dispatch-intelligence.json, SKILL.md, research doc), Tasks: 6 |
| Wall time | ~20 min (design through deployment) |
| Tests passing | 3 validation checks (all pass) |
| Headline | 2-layer safety system (snapshot/rollback + mirror pattern) deployed to dispatch-intelligence.json in 20 min. 3-tier region detection with progressive marker learning. Zero new Swift code — pure framework infrastructure. |

## 2. Experiment Design

**Independent variable:** Framework architecture (v5.1 luck-dependent parallel writes → v5.2 deterministic isolation).

| Dependent variable | v5.1 (before) | v5.2 target |
|---|---|---|
| Same-file conflict rate | 0 by luck | 0 by design |
| Token savings per agent | 0 | 50% (region-scoped context) |
| Rollback success rate | N/A | 100% |
| Dispatch overhead | 0 | <5% increase |

**Complexity proxy:** 6 tasks, framework infrastructure (no UI, no Swift app code), config + protocol + docs.

**Controls:** Same PM workflow, same developer, same codebase. Only framework dispatch infrastructure changed.

## 3. Raw Data

### Phase Timing

| Phase | Duration | Notes |
|---|---|---|
| Research | ~5 min | Prior session (v5.1 stress test, phases 5+7 identified the need) |
| PRD/Design | ~10 min | Brainstorming → spec (2026-04-16) |
| Tasks/Plan | ~5 min | Writing-plans skill |
| Implementation | ~10 min | T1-T3 inline (controller-scoped .claude/ paths) |
| Validation | <1 min | T5: 3 checks |
| Deploy | <1 min | T6: commit + push |

### Task Completion

| Task | Type | Status |
|---|---|---|
| T1: Add mirror_pattern config to dispatch-intelligence.json | config | complete |
| T2: Add mirror pattern protocol to SKILL.md | docs | complete |
| T3: Update research doc status | docs | complete |
| T4: Create tasks.md + advance state | config | complete |
| T5: Validation (3 checks) | test | complete |
| T6: Push + case study update | config | complete |

### Key Technical Details

**mirror_pattern config:**

| Field | Value |
|---|---|
| enabled | true |
| snapshot_dir | .build/snapshots |
| marker_prefix | agent-region |
| detection_order | [markers, mark_sections, full_file] |
| auto_add_markers | true |
| max_region_lines | 200 |
| include_read_only_context | true |

**3-tier region detection:**

| Tier | Method | Speed | When used |
|---|---|---|---|
| Tier 1 | `// BEGIN:agent-region:{name}` markers | Instant | Files with existing markers |
| Tier 2 | `mark_sections` (structural analysis) | Fast | Files with clear section boundaries |
| Tier 3 | `full_file` (snapshot entire file) | Baseline | First-time files, no markers |

**Progressive marker learning:** Tier 3 dispatches add `// BEGIN:agent-region:{name}` markers to the file. The next dispatch targeting the same file uses Tier 1 (instant region extraction). The framework gets faster with every dispatch cycle.

**Protocol (added to SKILL.md):**
- Pre-dispatch: snapshot original → extract agent region → dispatch with region context
- Post-return: reconstruct full file from region edits → build check → rollback on failure or commit on success

**Execution note:** All tasks executed inline by controller (not subagents) because all paths are `.claude/` which subagents cannot write to.

## 4. Analysis

### 4.1 Micro (Per-Task)

Config change (T1) was purely additive — a new JSON section appended to `dispatch-intelligence.json`. Protocol addition (T2) was ~30 lines of markdown in SKILL.md describing the pre-dispatch/post-return flow. Zero breaking changes to existing configuration. The validation checks (T5) confirmed structural integrity of the modified files without requiring a full build cycle.

### 4.2 Meso (Cross-Project)

Sub-Project B complements Sub-Project A (Dispatch Intelligence). A routes tasks to the right agent based on complexity, file ownership, and skill affinity. B ensures agents can safely edit shared files by isolating their write regions and providing snapshot-based rollback. Together they form the complete v5.2 dispatch system: A decides *who* works on *what*, B ensures they can do so *safely in parallel*.

### 4.3 Macro (Framework)

The v5.1 stress test proved parallel writes WORK — 0 conflicts across 15 same-file edits by 3 parallel agents. But that result was probabilistic, not guaranteed. Sub-Project B makes the guarantee structural: even if two agents target the same file, marker-based region isolation ensures their edits are non-overlapping, and snapshot/rollback provides a safety net when they are not.

The progressive marker system is a self-improving optimization. Every Tier 3 dispatch (full-file snapshot) upgrades the file with region markers, promoting all future dispatches to Tier 1 (instant). Over N dispatch cycles, the framework converges toward Tier 1 for all frequently-edited files — an analog of branch prediction warming up a cache.

## 5. Normalized Velocity

**CU calculation:**

```
Tasks = 6
Work_Type_Weight = 0.3 (chore — framework infrastructure, no user-facing functionality)
Complexity_Factors = Cross-Feature (+0.2) — affects all future dispatches
CU = 6 * 0.3 * (1 + 0.2) = 2.16
```

**Wall time:** ~20 min

**Velocity:** 20 / 2.16 = **9.26 min/CU**

### Cross-Version Comparison

| Version | Feature | min/CU | vs baseline |
|---|---|---|---|
| v2.0 | Onboarding v2 (baseline) | 15.2 | -- |
| v4.4 → v5.0 | SoC v5.0 only | 2.98 | +80% |
| v4.4 → v5.1 | SoC full suite | 7.14 | +53% |
| v5.1 | AI Engine Architecture | 5.1 | +66% |
| v5.1 | Onboarding Auth (best) | 2.1 | +86% |
| **v5.2** | **Parallel Write Safety** | **9.26** | **+39%** |

The v5.2 velocity (9.26 min/CU) is slower than v5.0/v5.1 infrastructure work because the design phase included brainstorming the 3-tier detection model from scratch rather than executing against a pre-existing spec. The +39% improvement over baseline reflects that framework infrastructure tasks — even novel ones — benefit from the accumulated tooling and workflow optimizations of prior versions.

## 6. Success & Failure Cases

### Success

1. **All 6 tasks completed in a single session with zero failures.** Config, protocol, docs, validation, and deployment all landed without rework or rollback.
2. **3-tier detection design allows progressive optimization.** The system learns from usage — Tier 3 dispatches auto-promote files to Tier 1 by injecting region markers. This means the cost of the safety system decreases over time.
3. **Inline execution for .claude/ paths applied correctly.** The discovery from Sub-Project A (subagents cannot write to `.claude/` paths) was immediately reused, avoiding wasted subagent dispatches.
4. **Combined with Sub-Project A, v5.2 is a complete dispatch safety system.** Dispatch Intelligence (routing) + Parallel Write Safety (isolation) cover both dimensions of multi-agent coordination.

### Failure

1. **No runtime validation yet.** The mirror pattern config is deployed but untested with actual parallel agents editing the same file simultaneously. The v5.1 stress test proved the NEED for this system, but Sub-Project B is infrastructure-only. A stress test rerun with 3+ agents targeting the same marked file would validate the system end-to-end. Until then, the safety guarantees are design-level, not empirically verified.

## 7. Framework Improvement Signals

- **Mirror pattern needs stress test validation.** Run 3+ agents editing the same file with region markers to validate snapshot/rollback under real contention. Design guarantees are necessary but not sufficient.
- **Progressive marker coverage should be tracked.** How many files have `agent-region` markers after N dispatch cycles? A coverage metric would show whether the self-improving property is working in practice.
- **Snapshot cleanup protocol should be automated.** `.build/snapshots/` could accumulate stale snapshots if builds timeout or agents crash mid-dispatch. A cleanup hook (e.g., delete snapshots older than 1 hour) would prevent disk bloat on the SSD.

## 8. Methodology Notes

- Wall time is estimated from session activity, not stopwatch-measured. The ~20 min figure spans brainstorming through deployment.
- The 3 validation checks confirmed: (1) dispatch-intelligence.json parses as valid JSON with the new mirror_pattern section, (2) SKILL.md contains the pre-dispatch/post-return protocol, (3) research doc status is updated.
- CU uses Chore weight (0.3) because this work adds no user-facing functionality. Using Feature weight (1.0) would give CU = 7.2 and velocity = 2.78 min/CU, which would overstate the comparison against user-facing features.
- The cross-version comparison table reuses velocities from prior case studies. All CU calculations use the same formula and weight definitions for consistency.
- "Zero new Swift code" is literal — every file touched was markdown, JSON, or SKILL.md. The safety system is a framework protocol enforced by the dispatch controller, not compiled application code.
