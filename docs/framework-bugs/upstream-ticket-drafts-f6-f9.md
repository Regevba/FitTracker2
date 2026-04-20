# Upstream Ticket Drafts — F6, F7, F8, F9

**Date:** 2026-04-20
**Target repo:** [github.com/anthropics/claude-code](https://github.com/anthropics/claude-code)
**Status:** DRAFT — awaiting user approval before posting

These 4 drafts will be posted as separate GitHub issues once approved. Each ticket is grounded in the Phase 0 classification at `docs/superpowers/plans/f6-f9-reproducer/classification-template.md` and the wave-2 case-study evidence in `docs/case-studies/post-stress-test-audit-remediation-case-study.md` § "Framework Bug Saga".

The bugs are likely related (possibly F7/F9 are specializations of F8) — the drafts cross-reference each other so upstream triage can consolidate if needed.

---

## Ticket 1 of 4 — F6

**Title:** Concurrent subagent dispatch: `additionalDirectories` glob doesn't propagate from parent to child

**Body:**

## Summary

When a parent agent dispatches a subagent (via the `Agent` / `Task` tool), the child subagent's permission resolver does not consistently honor glob-based entries in the parent's `additionalDirectories`. The child gets denied (or re-prompted) on paths that the parent has explicit permission to read via its own `additionalDirectories` globs.

## Setup

- Claude Code CLI running with `.claude/settings.json` + `.claude/settings.local.json`
- Parent session has `additionalDirectories: ["/repo/worktrees/*/.claude/features", "/repo/worktrees/*/.claude/shared"]` (glob entries)
- Parent successfully reads files matching those globs
- Parent dispatches a child subagent with a prompt that asks the child to read a file matching the same glob

## Expected

Child can read the file without prompting — it's within the parent's declared `additionalDirectories` surface.

## Actual

Child is denied or prompted on first read, as if the glob entries weren't honored.

## Reproducer

Minimal reproducer harness: https://github.com/Regevba/FitTracker2/tree/main/docs/superpowers/plans/f6-f9-reproducer (see `child-agent-task-template.md` § F6 and `classification-template.md` § F6).

## Why we think it's not a config issue

We added the worktree glob entries to `settings.local.json` in wave-2 of a stress test. The wave still failed with per-child permission denials, ruling out the "missing declaration" hypothesis. See the "Framework Bug Saga" section of [our post-stress-test case study](https://github.com/Regevba/FitTracker2/blob/main/docs/case-studies/post-stress-test-audit-remediation-case-study.md) for the full timeline.

## Related

Possibly related to F7 (Edit/Write re-prompt) and F8 (parallel dispatch state drift) — filing separate issues in case the root causes differ; feel free to consolidate at triage if they're the same bug.

## Workaround

Serial dispatch works fine. We've pivoted our remediation program (183/185 findings closed across 30+ PRs) to serial execution. Parallel dispatch has been blocked since 2026-04-18.

---

## Ticket 2 of 4 — F7

**Title:** Concurrent subagent dispatch: child re-prompts on Edit / Write even when parent has explicit allow entries

**Body:**

## Summary

When a child subagent attempts an Edit or Write on a path where the parent has explicit `Edit(/path/**)` and `Write(/path/**)` allow-entries in `.claude/settings.json`, the child re-prompts the user for each tool invocation as if the parent grants weren't visible.

## Setup

- Parent `settings.json` declares both:
  - `Edit(/Volumes/DevSSD/repo/.claude/worktrees/**)`
  - `Write(/Volumes/DevSSD/repo/.claude/worktrees/**)`
- Parent successfully uses Edit + Write on paths matching these globs
- Parent dispatches a child subagent that also needs to Edit/Write on paths matching these globs

## Expected

Child inherits the parent's Edit + Write grants and completes without re-prompting.

## Actual

Child is prompted for approval on its first Edit and its first Write, regardless of the parent's declared grants.

## Reproducer

https://github.com/Regevba/FitTracker2/tree/main/docs/superpowers/plans/f6-f9-reproducer § F7

## Why we think it's not a config issue

We have explicit allow-list entries for both tool classes covering the exact paths the child needs. Adding them didn't fix the behavior. We suspect Read and Edit/Write use different code paths in the child's permission resolver, and the Edit/Write path doesn't consult the parent's allow-list.

## Related

Possibly a specialization of F8 (parallel dispatch state drift). Filing separately for visibility; consolidate at triage if appropriate.

## Workaround

Serial dispatch OR pre-declare every tool class in settings.json AND accept that each child re-prompts on first tool call.

---

## Ticket 3 of 4 — F8

**Title:** Concurrent subagent dispatch: parent's permission state does not propagate to parallel subagents

**Body:**

## Summary

When a parent dispatches 2+ subagents in parallel, the subagents behave asymmetrically even when given identical permission surfaces. One may succeed while another re-prompts or fails, or they fail with different error text. A single subagent dispatched serially with the same permission surface works correctly.

This is the umbrella bug — likely F6, F7, and F9 are all symptoms of this deeper parent→child permission-state handoff gap.

## Setup

- Parent session with a complete permission surface declared in `settings.json` + `settings.local.json`
- Parent dispatches **2+ subagents simultaneously** (via multiple `Agent` tool calls in a single message)
- Each subagent is given an identical prompt + identical permission requirements

## Expected

All subagents see the same permission state and behave identically.

## Actual

Subagents get different permission snapshots depending on dispatch timing. Observed in our wave-2 stress test: 5 concurrent agents, all with identical perm surfaces, all 5 failed with per-agent denials — but a single serial dispatch of the same task succeeded.

## Reproducer

https://github.com/Regevba/FitTracker2/tree/main/docs/superpowers/plans/f6-f9-reproducer § F8

## Why we think this is a runtime bug

No consumer-side config controls the order in which the runtime serializes permission state into a child-dispatch payload. The asymmetry across otherwise-identical concurrent children is only explainable by a race condition in the snapshot mechanism.

## Impact

**Parallel dispatch is effectively unusable.** Our remediation program (30+ PRs) ran entirely serial after wave-2 aborted. This is the single biggest performance regression we have open.

## Workaround

Serial dispatch.

## Related

F6, F7, F9 likely specializations of this bug.

---

## Ticket 4 of 4 — F9

**Title:** Subagent dispatch: mid-session UI-accepted permission grants don't propagate to child subagents

**Body:**

## Summary

When the user accepts a permission prompt in the parent session (via the UI / --dangerously flag / etc.) and then the parent immediately dispatches a subagent, the child hits the same permission check and re-prompts as if the grant never happened.

## Setup

- Parent session running
- User is prompted for permission `X` in the parent and accepts it
- Without restarting the session, parent dispatches a child subagent that needs permission `X`

## Expected

Child inherits the just-granted permission.

## Actual

Child re-prompts for permission `X`. The only consumer-side workaround is to restart the session so `settings.json` is re-read.

## Reproducer

https://github.com/Regevba/FitTracker2/tree/main/docs/superpowers/plans/f6-f9-reproducer § F9

## Analysis

"Restart the session is the only workaround" is the signature of this being a runtime bug, not a config issue. There appear to be two code paths for permissions:

1. **Persistent grants** (read from `settings.json` at session start) → propagated to children correctly
2. **Session-state grants** (accepted at runtime via UI/prompt) → NOT propagated to children

The fix is either: persist UI-accepted grants to `settings.local.json` in real time, OR include session-state grants in the child-dispatch payload.

## Workaround

Declare every required permission in `settings.json` before dispatching children. Never rely on mid-session UI grants for a child's permission surface.

## Related

Likely the same root cause as F8, just exposed by a different mutation-timing pattern.

---

## Audit trail

| Date | Author | Action |
|---|---|---|
| 2026-04-20 | Phase 0 agent + this session | Drafts composed from `classification-template.md` + case-study evidence. Awaiting user approval to post. |
| (future) | — | Post each ticket, record URL, update `docs/framework-bugs/concurrent-dispatch-blockers.md` with live issue links. |
