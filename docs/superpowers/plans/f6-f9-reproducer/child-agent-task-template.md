# Child Agent Task Templates — F6/F7/F8/F9 Reproducers

**Companion to:** [`README.md`](./README.md)
**Purpose:** minimum permission surface + dispatch prompt per bug. Phase 1 executor uses these verbatim.

---

## Conventions

- **Parent session:** a fresh Claude Code session in `/Volumes/DevSSD/FitTracker2` with the baseline `.claude/settings.json` + `.claude/settings.local.json` described in README § "Baseline observations".
- **Worktree base:** `/Volumes/DevSSD/FitTracker2/.claude/worktrees/f6-f9-probe-{N}/` where `{N}` is `01`, `02`, etc. Create fresh for each reproducer run; tear down after.
- **Probe file targets:** do NOT use real feature state files. Use throwaway probe files under `.claude/features/_f6f9_probe/` that can be deleted after each run.

### Setup once before any reproducer

```bash
mkdir -p /Volumes/DevSSD/FitTracker2/.claude/features/_f6f9_probe
echo '{"probe": "f6f9", "created": "2026-04-20"}' \
  > /Volumes/DevSSD/FitTracker2/.claude/features/_f6f9_probe/state.json
git -C /Volumes/DevSSD/FitTracker2 worktree add \
  /Volumes/DevSSD/FitTracker2/.claude/worktrees/f6-f9-probe-01 main
git -C /Volumes/DevSSD/FitTracker2 worktree add \
  /Volumes/DevSSD/FitTracker2/.claude/worktrees/f6-f9-probe-02 main
```

### Teardown after all reproducers

```bash
git -C /Volumes/DevSSD/FitTracker2 worktree remove \
  /Volumes/DevSSD/FitTracker2/.claude/worktrees/f6-f9-probe-01 --force
git -C /Volumes/DevSSD/FitTracker2 worktree remove \
  /Volumes/DevSSD/FitTracker2/.claude/worktrees/f6-f9-probe-02 --force
rm -rf /Volumes/DevSSD/FitTracker2/.claude/features/_f6f9_probe
```

---

## F6 Reproducer — `additionalDirectories` drift on single child

### Minimum permission surface

Parent has in `additionalDirectories`:
```
/Volumes/DevSSD/FitTracker2/.claude/worktrees/*/.claude/features
/Volumes/DevSSD/FitTracker2/.claude/worktrees/*/.claude/shared
```
(Already present in `.claude/settings.local.json` — verify before dispatch.)

### Dispatch prompt (parent → child)

> Dispatch one subagent via `superpowers:dispatching-parallel-agents` with `isolation: "worktree"` pointing at `f6-f9-probe-01`. Child prompt:
>
> ```
> You are a perm-probe agent. Do ONLY these steps, in order:
>
> 1. Run `pwd` (Bash). Report the result.
> 2. Use the Read tool on `./.claude/features/_f6f9_probe/state.json` (relative to your cwd,
>    which should be the worktree root).
> 3. If step 2 succeeded without any permission re-prompt, report "F6-READ-OK".
>    If step 2 fired a permission re-prompt, report "F6-READ-PROMPTED: <exact prompt text>".
>    If step 2 was denied, report "F6-READ-DENIED: <error>".
> 4. Exit. Do not attempt any other tool call.
> ```

### Expected observation (before fix)

Child reports `F6-READ-PROMPTED` or `F6-READ-DENIED` even though parent has both `Read(//Volumes/DevSSD/FitTracker2/**)` and the worktree glob in `additionalDirectories`. This is the F6 drift: parent's resolved perm state is not propagated to child at spawn.

### Expected observation (after fix)

Child reports `F6-READ-OK` on first try.

---

## F7 Reproducer — Edit/Write gated separately

### Minimum permission surface

Parent has in `allow`:
- `Edit(/Volumes/DevSSD/FitTracker2/.claude/worktrees/**)`
- `Write(/Volumes/DevSSD/FitTracker2/.claude/worktrees/**)`

Both already present in `.claude/settings.local.json` — verify.

### Dispatch prompt (parent → child)

> Dispatch one subagent via `superpowers:dispatching-parallel-agents` with `isolation: "worktree"` pointing at `f6-f9-probe-01`. Child prompt:
>
> ```
> You are a perm-probe agent. Do ONLY these steps, in order:
>
> 1. Run `pwd` (Bash). Report.
> 2. Use the Edit tool on `./.claude/features/_f6f9_probe/state.json`. Change the
>    value of "probe" from "f6f9" to "f6f9-edited".
> 3. If step 2 succeeded without a permission re-prompt, report "F7-EDIT-OK".
>    If step 2 fired a re-prompt, report "F7-EDIT-PROMPTED: <prompt text>".
>    If step 2 was denied, report "F7-EDIT-DENIED: <error>".
> 4. Use the Write tool to create `./.claude/features/_f6f9_probe/probe_{your_agent_id}.txt`
>    containing the literal string "f7 probe wrote this".
> 5. Report the same shape: "F7-WRITE-OK" / "F7-WRITE-PROMPTED" / "F7-WRITE-DENIED".
> 6. Exit.
> ```

### Expected observation (before fix)

Child reports `F7-EDIT-PROMPTED` and/or `F7-WRITE-PROMPTED` even though parent's allow list explicitly names both tools with the correct path glob. This is F7: the child's Edit/Write permission resolver does not read the parent's inherited allow entries for these tool classes.

### Expected observation (after fix)

Child reports `F7-EDIT-OK` and `F7-WRITE-OK` with no re-prompts.

---

## F8 Reproducer — Parallel children, perm-state snapshot race

### Minimum permission surface

Same as F6 + F7 baseline. No additional grants required — F8 manifests with the same perm surface that makes F6/F7 manifest; the additional signal is **two parallel children with identical surfaces behave differently**.

### Dispatch prompt (parent → two children)

> Dispatch TWO subagents **in parallel** (single message, two Task tool calls) via `superpowers:dispatching-parallel-agents` with:
> - Child A: `isolation: "worktree"` pointing at `f6-f9-probe-01`
> - Child B: `isolation: "worktree"` pointing at `f6-f9-probe-02`
>
> Give both children the **same** prompt:
>
> ```
> You are parallel perm-probe agent {A or B}. Do ONLY these steps:
>
> 1. Run `pwd` (Bash). Report.
> 2. Read `./.claude/features/_f6f9_probe/state.json`.
>    Report "F8-A-READ-OK" or "F8-A-READ-PROMPTED" or "F8-A-READ-DENIED".
>    (Substitute B if you are agent B.)
> 3. Exit.
> ```

### Expected observation (before fix)

At least one of the two children reports `F8-*-READ-PROMPTED` or `F8-*-READ-DENIED` while the other may succeed, OR both fail identically. The **asymmetry between two identically-configured children** is F8's signature. The wave-2 evidence showed 5/5 denied identically; a 2-child variant should show either 2/2 denied or 1/2 asymmetric.

### Expected observation (after fix)

Both children report `F8-A-READ-OK` / `F8-B-READ-OK` deterministically with zero re-prompts.

---

## F9 Reproducer — Interactive grant doesn't propagate to child

### Minimum permission surface

**Deliberately minimal.** Start with a parent session whose settings.json does NOT list the target path. The test is whether a mid-session grant (via the Claude Code UI prompt accepting a permission) propagates to a child dispatched AFTER the grant.

### Dispatch prompt (parent → child)

> In a fresh Claude Code session:
>
> 1. Parent attempts Read on `/Volumes/DevSSD/FitTracker2/.claude/features/_f6f9_probe/state.json`. UI will fire a permission prompt. **Accept the grant.** Parent read succeeds.
>
> 2. IMMEDIATELY (no other tool calls in between) dispatch one child subagent via `superpowers:dispatching-parallel-agents`. Child prompt:
>
> ```
> You are perm-probe agent F9. Do ONLY these steps:
>
> 1. Read `/Volumes/DevSSD/FitTracker2/.claude/features/_f6f9_probe/state.json`.
> 2. If step 1 succeeded without a re-prompt, report "F9-READ-OK".
>    If step 1 fired a re-prompt, report "F9-READ-PROMPTED: <prompt text>".
> 3. Exit.
> ```

### Expected observation (before fix)

Child reports `F9-READ-PROMPTED` even though parent was just granted Read on that exact path seconds before child dispatch. The wave-2 case-study workaround ("restart the session") only makes sense if the mid-session grant isn't serialized into the child-dispatch context.

### Expected observation (after fix)

Child reports `F9-READ-OK`. No restart required.

---

## Observation log template

For each reproducer run, append to `proof-of-fix-tests.md` § "Observation log":

```
| Run ID | Bug | Timestamp | Parent perm declared? | Child behavior | Re-prompt text | Classification confirmed? |
|---|---|---|---|---|---|---|
| 001 | F6 | 2026-04-20T{time}Z | YES (glob + Read) | PROMPTED | "Allow Read on ..." | (a) upstream — confirmed |
```

---

## Safety notes

- **Never** dispatch more than 2 children in Phase 0 harness runs. F8 manifests at N=2; going higher just burns tool-call budget.
- **Never** run reproducers against real feature state files. The `_f6f9_probe` directory is the only acceptable target.
- If any reproducer escapes the worktree (F4-style behavior, writing to canonical path), STOP. That's a separate contract violation that the F2 contract in `dispatch-intelligence.json` should catch — if it doesn't, it's a new bug and needs its own filing before Phase 0 proceeds.
