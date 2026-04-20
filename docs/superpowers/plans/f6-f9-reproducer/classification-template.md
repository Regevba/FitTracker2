# F6-F9 Classification Template

**Companion to:** [`README.md`](./README.md), [`child-agent-task-template.md`](./child-agent-task-template.md)
**Purpose:** per-bug classification into bucket (a) upstream / (b) config / (c) skill contract, with evidence cited from `.claude/settings.json` + `.claude/settings.local.json` + case study forensics.

---

## Bucket definitions (from parent plan § Phase 1)

- **(a) Upstream framework bug** — the Claude Code / agent runtime does not propagate the parent's permission state on subagent spawn. Fix path: upstream issue + document workaround + warning banner in skill dispatcher.
- **(b) Config issue in `.claude/settings.json`** — our permission declarations are in the wrong scope / nesting. Fix path: patch settings.json, document pattern in CLAUDE.md.
- **(c) Skill contract issue** — the skill defines its permission surface in a way that doesn't survive parent→child handoff. Fix path: update `SKILL.md` to declare perm surface explicitly.

---

## F6 — `additionalDirectories` drift

### Symptom
Child subagent's permission resolver does not honor the glob entries from parent's `additionalDirectories` at dispatch time. Child gets denied / re-prompted on paths that the parent could read.

### Settings.json evidence

- **Project scope** (`.claude/settings.json`) has `Read(//Volumes/DevSSD/FitTracker2/**)` in `allow` and `/Volumes/DevSSD/FitTracker2` in `additionalDirectories`. Parent reads anything under repo root.
- **Local scope** (`.claude/settings.local.json`) has `worktrees/*/.claude/features` and `worktrees/*/.claude/shared` in `additionalDirectories`. Parent reads anything under the worktree-expanded globs.
- Config declares the right directories. **The bug is not "missing permission".**

### Case study evidence (wave-2)

Post-stress-test case study § "Framework Bug Saga" row F1/F8: "F1 fix only covers Read; Edit/Write tool grants are checked separately and aren't unblocked by `additionalDirectories` globs." Wave-2 retry after the glob was added still failed — child subagents don't see the glob-expanded list at their own permission check.

### Classification (hypothesis)

**(a) Upstream framework bug.**

**Reasoning:** If this were (b), adding the glob entries would have fixed it — they were added, and wave-2 still failed. If this were (c), a SKILL.md change to `dispatching-parallel-agents` would have fixed it — the skill already declares worktree isolation intent; the runtime isn't honoring it. The remaining root is the runtime's child-spawn permission snapshot.

**Confidence:** HIGH.

**Phase 1 verification:** run F6 reproducer. If child returns `F6-READ-OK` on first try, classification is wrong and this is actually (b) — something about the session at harness-execution time propagates the glob. If child returns `F6-READ-PROMPTED`, confirmed (a).

### Proposed fix path (if (a) confirmed)
1. File upstream issue with reproducer + settings.json snippet + wave-2 evidence link.
2. Add warning banner to `dispatching-parallel-agents` SKILL.md: "Child permission state is not a deep-copy of parent. Glob entries in `additionalDirectories` may drift. Use serial dispatch until upstream lands a fix."
3. Keep the worktree-glob entries in settings.json as defense-in-depth.

---

## F7 — Edit/Write gated separately

### Symptom
Child subagent re-prompts on Edit or Write even though parent holds `Edit(/...)` and `Write(/...)` allow-entries for the target path.

### Settings.json evidence

- **Project scope** declares: `Edit(/.claude/features/**)`, `Write(/.claude/features/**)`, `Edit(/.claude/skills/{various}/**)`.
- **Local scope** declares: `Edit(/Volumes/DevSSD/FitTracker2/.claude/worktrees/**)`, `Write(/Volumes/DevSSD/FitTracker2/.claude/worktrees/**)`.
- Both tool classes have explicit allow-list entries covering the worktree paths. **The bug is not "missing Edit/Write declaration".**

### Case study evidence (wave-2)

§ "Framework Bug Saga" F8: "All 5 got `Edit/Write` denied identically to the pre-F1 attempt. The F1 fix had only covered the directory-level Read access; Edit/Write tool grants are gated separately." This is a clear signal that the child's permission resolver uses a different code path for Edit/Write than for Read, and that code path doesn't consult the parent's allow-list at all.

### Classification (hypothesis)

**(a) Upstream framework bug.**

**Reasoning:** Parent has Edit + Write grants declared. Child still re-prompts. No settings.json key selects which tool classes propagate. The re-prompt behavior is a runtime decision in the child's permission resolver. That's an upstream code path, not a consumer-configurable one.

**Confidence:** HIGH. The settings.json has explicit Edit/Write allow-entries for the worktree paths and the wave-2 retry still hit per-child prompts. No consumer-side config or SKILL.md change can bypass a runtime re-prompt decision.

**Phase 1 verification:** run F7 reproducer. If child returns `F7-EDIT-OK` and `F7-WRITE-OK`, classification is wrong (possibly (b)). If either returns `PROMPTED`, confirmed (a).

### Proposed fix path (if (a) confirmed)
1. File upstream — same ticket as F6 if both are symptoms of the same deep-copy gap, or separate ticket if they have different root causes per the upstream triage.
2. Add warning banner to `dispatching-parallel-agents` SKILL.md: "Edit/Write re-prompts on child subagents are not avoidable via settings.json. Expect manual intervention or serial dispatch."
3. Keep the `Edit(/...worktrees/**)` + `Write(/...worktrees/**)` allow entries as defense-in-depth — they minimize the post-prompt resolution time.

---

## F8 — Perm state doesn't propagate to parallel subagents

### Symptom
Two concurrently-dispatched children with identical permission surfaces exhibit different behavior — one may succeed, the other re-prompts, or both fail but with different timing / different re-prompt text.

### Settings.json evidence

- No settings.json key is labeled `propagate_to_subagents`, `child_inherits_parent_perms`, `parallel_dispatch_snapshot`, or similar. The schema exposes no knob for this.
- The `superpowers:dispatching-parallel-agents` skill declares intent to run children in parallel but cannot modify the runtime's snapshot behavior.

### Case study evidence (wave-2)

§ "Framework Bug Saga" F9 discovery row: "Permission grants added during session don't propagate to concurrently-dispatched subagents." This is the F9 observation but it's caused by the same F8 snapshot-timing mechanism. The canonical F8 evidence: wave-2 retry, 5 concurrent agents, all 5 denied even though single-agent probe worked. That asymmetry (5 parallel fail, 1 serial pass, same config) IS F8.

### Classification (hypothesis)

**(a) Upstream framework bug.**

**Reasoning:** No consumer-side mechanism exists to fix snapshot timing in a parent→child handoff. Settings.json is static declarative config; it cannot influence the order in which the runtime serializes perm state into a child-dispatch payload. SKILL.md can advise on dispatch pattern but cannot fix the race.

**Confidence:** HIGH. This is a pure runtime bug.

**Phase 1 verification:** run F8 reproducer (2 parallel children). If both return `F8-*-READ-OK` deterministically across 3 consecutive runs, classification is wrong. If any run shows asymmetry or double-denial, confirmed (a).

### Proposed fix path (if (a) confirmed)
1. File upstream — this is the umbrella parallel-dispatch bug. F6 + F7 + F9 may all be specializations of F8.
2. Add a HARD banner to `dispatching-parallel-agents` SKILL.md: "Parallel dispatch is framework-blocked since 2026-04-18. Use serial dispatch until upstream fix lands."
3. Consider adding a pre-flight check in the skill that refuses to dispatch >1 child until the blocker is cleared (e.g., a `dispatch-intelligence.json` flag like `concurrent_dispatch.blocked_until_upstream_fix: true`).

---

## F9 — Mid-session grant doesn't propagate to child

### Symptom
Parent accepts a permission prompt (via the UI), then immediately dispatches a child. Child hits the same permission check and re-prompts, as if the grant never happened.

### Settings.json evidence

- Settings.json is read at session start. Mid-session grants are stored in session state, not written back to settings.json.
- No schema field toggles "write mid-session grants to local settings" or "include session-state grants in child dispatch payload".

### Case study evidence (wave-2)

§ "Framework Bug Saga" F9 row: "Permission grants added during session don't propagate to concurrently-dispatched subagents. Restart the session is the only consumer-side workaround."

The "restart the session" workaround is diagnostic: restarting forces settings.json to be re-read and any persisted grant to enter the normal child-dispatch path. That tells us the runtime has two code paths for permissions (persistent = propagated, session-state = not propagated) and the bug is that the second path exists at all.

### Classification (hypothesis)

**(a) Upstream framework bug.**

**Reasoning:** "Restart the session is the only workaround" IS an upstream-bug signature. Consumer-side, the fix would be to persist every UI-accepted grant to `.claude/settings.local.json` in real time — but that's a runtime responsibility, not a config knob.

**Confidence:** HIGH.

**Phase 1 verification:** run F9 reproducer. Accept grant in parent, dispatch child, observe child. If child returns `F9-READ-OK`, classification is wrong. If `F9-READ-PROMPTED`, confirmed (a).

### Proposed fix path (if (a) confirmed)
1. File upstream ticket: "persist UI-accepted grants to settings.local.json immediately, OR include session-state grants in child dispatch payload."
2. Add to `dispatching-parallel-agents` SKILL.md: "Before dispatching children, ensure all required permissions are declared in settings.json — UI-accepted mid-session grants will NOT be visible to children."
3. Add to CLAUDE.md § "Branching Strategy" or a new § "Concurrent dispatch hygiene": "Add all required permissions to `.claude/settings.json` or `.claude/settings.local.json` BEFORE dispatching parallel work. Mid-session UI grants don't propagate."

---

## Summary table (Phase 0 hypothesis)

| Bug | Hypothesis | Confidence | Phase 2 action if confirmed | Quick-win candidate? |
|---|---|---|---|---|
| F6 | (a) Upstream | HIGH | File upstream, banner in skill, keep glob entries | No — glob already in place, bug persists |
| F7 | (a) Upstream | HIGH | File upstream (possibly same ticket as F6), banner in skill | No — explicit Edit/Write entries already in place |
| F8 | (a) Upstream | HIGH | File upstream (umbrella), hard-block parallel dispatch in skill | No — snapshot timing not consumer-configurable |
| F9 | (a) Upstream | HIGH | File upstream, document "settings.json before dispatch" rule in CLAUDE.md | No — but see quick-mitigation 4 in README |

**Net:** all four classifications converge on bucket (a). Phase 2's output will be documentation + upstream tickets + SKILL.md warning banners rather than code fixes. This matches the risk scenario named in the parent plan.

**One concrete config candidate from Phase 0** (see README § "Quick wins"): migrate worktree-glob entries from `settings.local.json` to `settings.json` to ensure they're in the committed baseline. This does not fix any of F6-F9 directly; it only removes one variable from the Phase 1 diagnostic search space.

---

## Audit trail

| Date | Author | Action |
|---|---|---|
| 2026-04-20 | Phase 0 harness build | Initial hypotheses recorded based on config inspection + case-study forensics. No reproducers run. |
| (future) | Phase 1 executor | Update each row with "CONFIRMED" or "REVISED TO (X): <evidence>" after running reproducers. |
