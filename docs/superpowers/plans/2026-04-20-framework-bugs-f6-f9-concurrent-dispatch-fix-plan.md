# Framework Bugs F6–F9 — Concurrent-Dispatch Remediation Plan

**Plan date:** 2026-04-20
**Owner:** framework-bugs
**Status:** open · ready for execution
**Related case studies:** [`audit-remediation-program-185-findings-case-study.md`](../../case-studies/audit-remediation-program-185-findings-case-study.md) §6, [`post-stress-test-audit-remediation-case-study.md`](../../case-studies/post-stress-test-audit-remediation-case-study.md) §Framework Bugs
**Depends on:** none — self-contained research + fix + validation loop

---

## Context

The 185-finding audit remediation program surfaced nine framework bugs F1–F9 during execution. F1–F5 were patched in-line (contracts re-validated at 10/10 agents). **F6–F9 are all concurrent-dispatch permission-propagation bugs and remain open.** Concurrent dispatch is blocked at the framework layer until all four are resolved — the program pivoted to serial execution and completed successfully, but parallel dispatch has been dark since 2026-04-18.

| Bug | Summary | First observed |
|---|---|---|
| F6 | Concurrent-dispatch: `additionalDirectories` permission drift between parent and child subagent | Wave 1 of audit-v2 stress test (2026-04-18) |
| F7 | Edit / Write gated separately from the parent's permission grant; each child re-prompts | Same wave |
| F8 | Permissions do not propagate to parallel subagents — each subagent starts with default perms instead of the parent's | Wave 2 of audit-v2 stress test (2026-04-18) |
| F9 | Parent's `Read` permission does not cover subagent `Read` — each child re-prompts on first read | Same wave |

**Why it matters:** the framework's largest performance lever (parallel subagent dispatch) is currently un-usable. Serial execution works but throws away the 2x–6x throughput gain that parallel was designed for. Fixing these four bugs unblocks the feature that the HADF, Orchid, and v6.2 work assumes.

---

## Goal

Close F6, F7, F8, F9 with:
- A reproducer for each.
- A root-cause classification (upstream / config / skill contract).
- A fix applied or a documented workaround with a tracking ticket upstream.
- A regression test that would have caught the bug pre-pivot.
- A small concurrent dispatch (2 agents, different domains) that completes end-to-end without manual intervention, as the exit criterion.

**Non-goal:** re-running the full concurrent-audit experiment (that's a follow-up case study, not part of this plan).

---

## Phase 0 — Research (Reproducer Harness)

**Deliverable:** a minimal test directory under `/tmp/f6-f9-repro/` containing:

- A parent agent prompt that dispatches one child subagent with a defined permission surface (Read, Edit, additionalDirectories).
- A scripted observation of whether the child inherits: (a) the parent's `allowedDirectories`, (b) the parent's tool grants (Read / Edit / Write), (c) the parent's MCP permissions.
- A second variant that dispatches two parallel children with identical perm surface — observes whether the second child sees different behavior than the first (F8's signature).

**Output:** a structured observation log that maps each of F6, F7, F8, F9 to a reproduced failure mode with an exact tool call and expected-vs-actual diff.

**Time estimate:** 1 hour.

---

## Phase 1 — Classification

For each bug, assign one of three root-cause buckets:

**(a) Upstream framework bug** — the Claude Code / agent runtime does not propagate the parent's permission state on subagent spawn. Fix path: file upstream issue + document a workaround + add a warning banner to our skill dispatcher.

**(b) Config issue in `.claude/settings.json`** — our permission declarations are in the wrong scope (e.g. per-skill instead of global, or at the wrong nesting level). Fix path: patch `settings.json`, document the pattern in CLAUDE.md.

**(c) Skill contract issue** — the skill defines its permission surface in a way that doesn't survive the parent→child handoff. Fix path: update the skill's `SKILL.md` to declare its perm surface explicitly, not implicitly via inheritance.

**Heuristic for initial classification** (to be validated in Phase 0):

| Bug | Suspected bucket | Why |
|---|---|---|
| F6 | (a) upstream | `additionalDirectories` is a well-defined permission field — drift implies the runtime isn't deep-copying it |
| F7 | (b) config | Edit/Write prompting separately suggests they're not grouped in our permission declaration |
| F8 | (a) upstream | Full perm-state not propagating on subagent spawn is a runtime-level issue |
| F9 | (b) config | Read is the safest permission — if the parent has it, the child should inherit; suggests the inheritance mechanism exists but our config doesn't opt in |

---

## Phase 2 — Fix Implementation

For each bug classified in Phase 1:

### If upstream (a):

1. File a minimal-reproducer upstream issue via whatever channel is active (Claude Code GitHub repo, internal feedback tool).
2. Add a workaround comment in the affected skill's `SKILL.md` explaining the limitation.
3. Add a banner to the concurrent-dispatch skill (`superpowers:dispatching-parallel-agents`) stating that permission re-prompts may fire on child agents until upstream fix.
4. **Exit condition:** documented, not fixed — parallel dispatch remains degraded until upstream lands.

### If config (b):

1. Patch `.claude/settings.json` (or `settings.local.json` for per-user defaults).
2. Add a regression test: a skill that dispatches a child and asserts the child's tool-grant surface matches the parent's, without user interaction.
3. Re-run the Phase 0 reproducer. If the bug no longer fires, mark as fixed.
4. **Exit condition:** fixed + regression test added.

### If skill contract (c):

1. Update the affected skill's `SKILL.md` to declare its permission surface explicitly.
2. Add the same regression test from (b).
3. **Exit condition:** fixed + regression test added.

---

## Phase 3 — Validation

After each bug is addressed:

1. Run the reproducer from Phase 0 — assert no re-prompts fire.
2. Dispatch **two parallel agents** on independent tasks (one reads files in one directory, one reads files in another). Both should complete end-to-end without intervention.
3. If any re-prompt fires or any agent fails, the bug is NOT fixed — re-open the classification.

**Exit criteria for the plan:**

- All four bugs have a Phase 1 classification on file.
- All (b) and (c) bugs are fixed with regression tests.
- All (a) bugs are documented with upstream tickets + workaround banners.
- Two parallel agents complete a small-but-real task (e.g. each writing a 50-line case study section) without user intervention.

---

## Phase 4 — Case Study

After validation:

1. Write `docs/case-studies/concurrent-dispatch-revival-case-study.md` documenting each bug's root cause + fix (or workaround).
2. Add a showcase entry at `04-case-studies/25-concurrent-dispatch-revival.md`.
3. Update the 185-program case study's §6 to link to the revival case study.
4. Update memory (`project_audit_v2_wave_2_outcome.md` — mark F8/F9 resolved if applicable).

---

## Dependencies + Risks

- **Dependency:** need to know whether Claude Code runtime supports hot-reload of `settings.json` mid-session. If not, validation Phase 3 requires a session restart, which makes iteration slow.
- **Risk:** if all four bugs are (a) upstream, this plan's output is documentation + tickets rather than code fixes. That's still valuable (maintains honest accounting of what's broken vs deferred) but does not unblock parallel dispatch until upstream responds.
- **Risk:** F6 may reveal additional edge cases (e.g. `ignoreDirectories`, MCP-provided permissions) that weren't in the original classification. Keep the reproducer harness extensible so new cases fold in cleanly.

---

## Estimated effort

| Phase | Effort |
|---|---|
| 0 — reproducer harness | ~1h |
| 1 — classification | ~1h |
| 2 — fixes (config/skill bugs) | ~2-4h depending on classification distribution |
| 2 — fixes (upstream bugs) | ~1h (tickets + banner docs) |
| 3 — validation | ~1h |
| 4 — case study | ~1-2h |

**Total:** 1 day of focused work, OR 2-3 half-days interleaved with other work.

---

## Success metric

Before fix: concurrent dispatch dark since 2026-04-18 (zero successful parallel runs since F1 aborted).

After fix: two parallel agents complete a task without user intervention. Validation case study shipped. Framework can return to using parallel dispatch for multi-domain work (audit waves, stress tests, parallel feature development).
