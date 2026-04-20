# F6-F9 Reproducer Harness — Phase 0

**Plan:** [`/Volumes/DevSSD/FitTracker2/docs/superpowers/plans/2026-04-20-framework-bugs-f6-f9-concurrent-dispatch-fix-plan.md`](../2026-04-20-framework-bugs-f6-f9-concurrent-dispatch-fix-plan.md)
**Phase:** 0 — Reproducer Harness + Classification
**Date:** 2026-04-20
**Owner:** framework-bugs
**Status:** docs-only scaffold (no agents dispatched — dispatch happens in Phase 1-2)

---

## What this directory is

A minimal, self-contained harness that lets a Phase 1 executor:

1. Reproduce each of F6, F7, F8, F9 in isolation, with the smallest possible permission surface that will trigger each bug.
2. Classify each bug into one of three root-cause buckets (upstream framework / config / skill contract) based on evidence from `.claude/settings.json` and the wave-1 / wave-2 forensics in the post-stress-test case study.
3. Flag any bug that looks like a 1-line settings fix — those become Phase 2 quick wins.
4. Name the minimum proof-of-fix test for each bug so Phase 3 validation has a clear target.

**Scope constraint:** This Phase-0 deliverable is documentation + templates. No concurrent agents are dispatched here — that would immediately hit F8/F9 and block the harness before it was finished. Dispatch happens in Phase 1 under controlled conditions.

---

## The four bugs, at a glance

| Bug | Summary | First observed | Status (pre-Phase-0) |
|---|---|---|---|
| **F6** | `additionalDirectories` permission drift between parent and child subagent (parent has access, child doesn't) | Wave 1 (2026-04-18) | OPEN — concurrent dispatch dark |
| **F7** | `Edit` / `Write` gated separately from the parent's permission grant; each child re-prompts even when parent is fully authorized | Wave 1 (2026-04-18) | OPEN — concurrent dispatch dark |
| **F8** | Full permission state doesn't propagate to parallel subagents — each subagent starts with default perms instead of parent's current perm snapshot | Wave 2 (2026-04-18) | OPEN — concurrent dispatch dark |
| **F9** | Parent's `Read` permission does not cover subagent `Read` — child re-prompts on first read even though parent has already been granted | Wave 2 (2026-04-18) | OPEN — concurrent dispatch dark |

> **Note on naming:** In the post-stress-test case study § "Framework Bugs", F6 is listed as "POSITIVE / CODIFIED" (the salvage-protocol case). The plan dated 2026-04-20 re-scopes F6, F7, F8, F9 as four distinct concurrent-dispatch permission-propagation bugs per the current plan's taxonomy. This harness uses the **plan-taxonomy** definitions above (per the Phase 0 brief). Whichever way the numbering lands, the four reproducers below cover the full failure surface.

---

## Files in this harness

| File | Purpose |
|---|---|
| `README.md` | This file — harness overview, Phase-0 report (below), classifications, quick wins |
| `child-agent-task-template.md` | Minimum permission surface + prompt skeleton per bug. What the Phase 1 executor dispatches. |
| `classification-template.md` | Per-bug classification with evidence cited from `settings.json` + case study |
| `proof-of-fix-tests.md` | Minimum tests to confirm each bug is fixed in Phase 3 |

---

## How to run each reproducer (Phase 1 executor instructions)

Each reproducer follows the same shape:

1. Open a fresh Claude Code session in `/Volumes/DevSSD/FitTracker2`.
2. Verify `.claude/settings.json` + `.claude/settings.local.json` match the baseline documented in `classification-template.md` (Phase 0 snapshot).
3. Dispatch ONE child subagent using the exact prompt in `child-agent-task-template.md` for the target bug.
4. For F8 specifically: dispatch TWO children in parallel with identical perm surface (that's what F8 requires to manifest).
5. Observe which tool call fires a permission re-prompt. That re-prompt IS the bug.
6. Log: timestamp, child agent ID, tool name, path, parent's declared perm (yes/no), child's actual behavior (allowed / re-prompt / denied).
7. Record result in `proof-of-fix-tests.md` as the baseline "before-fix" observation.

**Do NOT proceed past Phase 0** until each bug has a documented reproduction AND a classification.

---

## Baseline `.claude/settings.json` observations (Phase 0 evidence)

Taken from `/Volumes/DevSSD/FitTracker2/.claude/settings.json` on 2026-04-20:

**`permissions.additionalDirectories` (project-scope):**
```
/Users/regevbarak/.claude/projects/-Volumes-DevSSD-FitTracker2
/Volumes/DevSSD/FitTracker2/.claude/features
/Volumes/DevSSD/FitTracker2/.claude/features/training-plan-v2
/Volumes/DevSSD/FitTracker2
```

**`permissions.additionalDirectories` (local-scope, `.claude/settings.local.json`):**
```
/Volumes/DevSSD/FitTracker2/.claude/features
/Volumes/DevSSD/FitTracker2/.claude/shared
/Volumes/DevSSD/FitTracker2/.claude/worktrees/*/.claude/features
/Volumes/DevSSD/FitTracker2/.claude/worktrees/*/.claude/shared
/Volumes/DevSSD/dev-home/dotfiles/.claude/projects/-Volumes-DevSSD-FitTracker2/memory
/Volumes/DevSSD/fitme-story
/Volumes/DevSSD/fitme-showcase/04-case-studies
```

**Key observations relevant to classification:**

1. `Read(//Volumes/DevSSD/FitTracker2/**)` is present in project-scope `allow`. This is the parent's Read grant. F9 asks whether this grant propagates — the wave-2 evidence says NO for concurrently-dispatched children.

2. `Edit(/.claude/features/**)`, `Write(/.claude/features/**)`, `Edit(/Volumes/DevSSD/FitTracker2/.claude/worktrees/**)`, `Write(/Volumes/DevSSD/FitTracker2/.claude/worktrees/**)` are all declared. These are the parent's Edit/Write grants. F7 asks whether they propagate — wave-2 evidence says NO.

3. `additionalDirectories` uses a glob (`worktrees/*/...`) — this is F1's Path-A workaround. F6 asks whether a child subagent inherits this glob-expanded list at dispatch time. Per wave-2 forensics, the child receives a snapshot that does not include post-parent-start additions, and concurrent children can receive different snapshots (F8).

4. **There is no `inheritPermissions` or `propagateToSubagents` flag** in either settings file. If such a flag exists in Claude Code's schema but is unset, F9 (and possibly F6) would be a config bug; if no such flag exists, they're upstream bugs.

---

## Phase 0 Report — Classifications + Quick Wins

### Classifications (hypothesized from config evidence)

| Bug | Classification (hypothesis) | Evidence | Confidence |
|---|---|---|---|
| **F6** | **(a) Upstream framework bug** — likely with a (b) config-layer mitigation | The glob in `additionalDirectories` (`worktrees/*/.claude/...`) IS present. Wave-2 evidence shows children still drift despite the glob being declared. That rules out "missing config" and points to the runtime not deep-copying the parent's resolved permission state at child-spawn time. A config-layer mitigation exists (see Quick Win 1 below) but the root is upstream. | HIGH — directly supported by wave-2 retry failure with the glob already in place. |
| **F7** | **(a) Upstream framework bug** — with NO known config-layer mitigation | `Edit(/...worktrees/**)` and `Write(/...worktrees/**)` are already declared explicitly and the parent holds them. Wave-2 still hit per-child re-prompts on Edit/Write. That means the re-prompt is fired by the *child's permission resolver*, which is treating Edit/Write as a separately-gated tool class that doesn't read from the parent's inherited `allow` list. No settings.json key controls this — it's a runtime decision. | HIGH — the explicit Edit/Write grants rule out "missing permission"; the bug is in how child resolvers read parent state. |
| **F8** | **(a) Upstream framework bug** — fundamentally | F8 is the umbrella failure: permission state is not snapshotted deterministically at subagent spawn. Two concurrent children with identical perm surfaces can see different resolved states. Nothing in settings.json or any SKILL.md can fix a snapshot-timing bug in the dispatcher. Only an upstream runtime fix can address it. | HIGH — no consumer-side config or contract can fix a runtime snapshot race. |
| **F9** | **(a) Upstream framework bug** — with a session-restart consumer workaround | Parent holds `Read(//Volumes/DevSSD/FitTracker2/**)`. Children re-prompt on first read. The case study explicitly documents: "Restart the session is the only consumer-side workaround." That phrase only makes sense if the bug is in how in-session permission grants are serialized into child-dispatch context — a runtime issue, not a config or contract issue. | HIGH — the restart-workaround signature IS an upstream bug signature. |

**Summary:** all four classifications land in bucket **(a) Upstream framework bug**. This matches the "Risk" noted in the parent plan § Dependencies + Risks: "if all four bugs are (a) upstream, this plan's output is documentation + tickets rather than code fixes." Phase 0 evidence converges on that risk scenario.

### Quick wins (1-line settings.json fixes the config inspection surfaces)

**None identified as true 1-line fixes that resolve the bug.** All four bugs are runtime-snapshot / child-spawn issues that settings.json cannot fully repair.

However, the following **partial mitigations** are already on main and should remain in place as the best-effort config layer:

- **Quick-mitigation 1 (in place):** `additionalDirectories` glob includes `/Volumes/DevSSD/FitTracker2/.claude/worktrees/*/.claude/features` and `...shared`. This partially mitigates F6 by ensuring the child's default perm list at least names the worktree-prefixed paths. It does NOT fix F6 when the child's permission resolver runs before this list is read.

- **Quick-mitigation 2 (in place):** explicit `Edit(/...worktrees/**)` and `Write(/...worktrees/**)` allow-entries. This ensures F7 re-prompts, when accepted, at least resolve immediately. It does NOT prevent the re-prompt.

- **Potential quick-mitigation 3 (not yet tried):** add a global `Read(//**)` to `permissions.allow` as a blanket child-inheritance signal. **NOT RECOMMENDED** — this broadens the security surface unacceptably and is unlikely to fix the snapshot-timing bug at F8's root. Flagged here only so Phase 2 doesn't re-invent it.

- **Potential quick-mitigation 4 (worth testing in Phase 1):** move the worktree-glob entries from `settings.local.json` to `settings.json` (project-scope) so they are part of the committed baseline and cannot be missed by a fresh child process that doesn't load local settings. Cost: one file move, one commit. Benefit: eliminates any "child doesn't load local settings" failure mode from the search space, isolating the remaining bugs more cleanly. This is the **one concrete Phase-2 candidate quick win** from Phase 0.

### Minimum proof-of-fix tests

See [`proof-of-fix-tests.md`](./proof-of-fix-tests.md) for full detail. Summary:

| Bug | Minimum proof-of-fix test |
|---|---|
| **F6** | Dispatch one child subagent with `isolation: "worktree"`. Child attempts `Read` on `{worktree}/.claude/shared/skill-routing.json`. Expected after fix: no re-prompt, read succeeds. |
| **F7** | Same child as F6. After successful Read, child attempts `Edit` on `{worktree}/.claude/features/probe/state.json`. Expected after fix: no re-prompt, edit succeeds. |
| **F8** | Dispatch TWO children in parallel, both with `isolation: "worktree"`. Both attempt `Read` simultaneously. Expected after fix: both succeed with zero re-prompts. |
| **F9** | In a fresh session, grant parent a Read permission via UI prompt (not settings.json). Immediately dispatch a child. Child attempts Read on that granted path. Expected after fix: no re-prompt (grant propagates to child). |

---

## What Phase 1 should do with this harness

1. Load the Phase 0 baseline as documented in `classification-template.md`.
2. Run each of the four reproducers in the minimum configuration from `child-agent-task-template.md`.
3. Update each bug's **Classification** row with "CONFIRMED (a)" or "REVISED TO (b) / (c) with evidence X" based on what actually happens in the reproducer run.
4. For any bug still in bucket (a), file an upstream ticket as specified in the parent plan § Phase 2 (a).
5. For any bug that Phase 1 reclassifies as (b) or (c), update `.claude/settings.json` or the affected SKILL.md and re-run the reproducer as the regression test.

---

## Exit criteria for Phase 0 (this deliverable)

- [x] Reproducer harness directory exists at `docs/superpowers/plans/f6-f9-reproducer/`
- [x] `README.md` (this file) with Phase 0 report, classifications, and quick-win analysis
- [x] `child-agent-task-template.md` with minimum permission surface per bug
- [x] `classification-template.md` with a/b/c bucket assignment + evidence
- [x] `proof-of-fix-tests.md` with minimum validation test per bug
- [x] No concurrent agents dispatched (Phase 0 constraint respected)
- [x] Committed to main via docs-only commit

Phase 0 is complete when all six items above are checked. Phase 1 begins with running the reproducers.
