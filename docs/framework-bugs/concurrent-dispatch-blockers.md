# Concurrent-Dispatch Framework Blockers — Active

**Last updated:** 2026-04-20
**Status:** ACTIVE — parallel subagent dispatch is blocked at the runtime layer.
**Workaround:** serial dispatch (works fine — every sprint of our 185-finding audit remediation program ran serial and closed 183 findings).

---

## Summary

Four upstream bugs in the Claude Code runtime prevent parallel subagent dispatch from working reliably. Until upstream patches land, all dispatching-parallel-agents skill invocations must default to **serial execution**.

| Bug | Symptom | Upstream ticket |
|---|---|---|
| F6 | `additionalDirectories` glob doesn't propagate to child | (pending — ticket draft at `docs/framework-bugs/upstream-ticket-drafts-f6-f9.md`) |
| F7 | Edit/Write re-prompts on child despite parent allow-entries | (pending) |
| F8 | Parallel subagents get asymmetric permission snapshots | (pending — umbrella bug) |
| F9 | Mid-session UI grants don't propagate to children | (pending) |

Issue URLs will be filled in once the tickets are posted to `anthropics/claude-code`.

## What this blocks

- Parallel audit waves (wave 1 aborted on F1; wave 2 aborted on F5 after workarounds for F1 were added)
- Parallel feature development (e.g., HADF T1/T2/T3 could have run in parallel)
- Any future stress test that relies on dispatching >1 subagent concurrently

## What this does NOT block

- Serial subagent dispatch — works fine
- All 9-phase PM lifecycle work (post-stress-test + M-1/2/3/4 + Path A all shipped serial)
- HADF T1–T9 in serial (the first v6.0-instrumented feature after this blocker was documented)

## Recovery path

Phase 0 — classification complete (hypothesis: all 4 bugs are upstream runtime). See [reproducer harness](../superpowers/plans/f6-f9-reproducer/).

Phase 1 — run reproducers to confirm or revise classifications. Requires careful test dispatches that will themselves hit the bugs being tested. Likely single-day work.

Phase 2 — for confirmed upstream bugs: file tickets, add skill warning banners, document the "declare perms in settings.json before dispatching children" rule.

Phase 3 — validate parallel dispatch revival once upstream patches land. 2 parallel agents on independent tasks as the exit gate.

Phase 4 — concurrent-dispatch-revival case study. Remove warning banners. Add the bug saga to the framework evolution narrative.

## Policy for agents

**If the dispatching-parallel-agents skill is being invoked:** check this file first. If F6–F9 remain active, default to serial dispatch. Explicit user override ("run this in parallel anyway") is the only path around the blocker — and expect re-prompts.

**If the dispatching-parallel-agents skill is being authored / modified:** add a link to this file in the skill's "When not to use" or "Known limitations" section.

## Related

- [F6-F9 reproducer harness](../superpowers/plans/f6-f9-reproducer/)
- [F6-F9 remediation plan](../superpowers/plans/2026-04-20-framework-bugs-f6-f9-concurrent-dispatch-fix-plan.md)
- [185-finding audit remediation program case study](../case-studies/audit-remediation-program-185-findings-case-study.md) § 6 "Framework Bugs Surfaced DURING Remediation"
- [Post-stress-test case study](../case-studies/post-stress-test-audit-remediation-case-study.md) § "Framework Bug Saga"
