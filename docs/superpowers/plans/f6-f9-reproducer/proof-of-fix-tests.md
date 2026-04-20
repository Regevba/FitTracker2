# F6-F9 Proof-of-Fix Tests

**Companion to:** [`README.md`](./README.md), [`child-agent-task-template.md`](./child-agent-task-template.md), [`classification-template.md`](./classification-template.md)
**Purpose:** minimum tests that confirm each bug is fixed. Phase 3 validation gate uses these.

---

## Pass criteria (common)

A proof-of-fix test passes when:
1. The child subagent completes the target tool call with zero permission re-prompts.
2. The behavior is **deterministic** across 3 consecutive independent runs (different session, same config).
3. For F8: both parallel children succeed in the same way, with no asymmetry between them.

A proof-of-fix test fails if:
- Any re-prompt fires.
- Behavior is flaky (1 of 3 runs succeeds, 2 fail, or vice versa).
- The child returns denied / error on the target tool call.

---

## F6 proof-of-fix test

**Setup:** Baseline `.claude/settings.json` + `.claude/settings.local.json` as documented in README § "Baseline observations". Worktree `f6-f9-probe-01` exists.

**Dispatch:** Single child, `isolation: "worktree"`, prompt from `child-agent-task-template.md § F6 Reproducer`.

**Observable pass signal:** Child returns `F6-READ-OK`.

**Observable fail signal:** Child returns `F6-READ-PROMPTED` or `F6-READ-DENIED`.

**Repeat:** 3 times, each in a fresh parent session.

**Fix-validated if:** 3 of 3 runs return `F6-READ-OK` and no re-prompt fires in the parent session either.

---

## F7 proof-of-fix test

**Setup:** Same as F6.

**Dispatch:** Single child, `isolation: "worktree"`, prompt from `child-agent-task-template.md § F7 Reproducer`.

**Observable pass signal:** Child returns both `F7-EDIT-OK` AND `F7-WRITE-OK`.

**Observable fail signal:** Either step returns `PROMPTED` or `DENIED`.

**Repeat:** 3 times.

**Fix-validated if:** 3 of 3 runs return both `F7-EDIT-OK` and `F7-WRITE-OK`, no re-prompts.

**Note:** F7 should be tested AFTER F6 is confirmed fixed. If F6 is still broken, F7's EDIT step may fail for F6's reason (directory not readable) rather than F7's reason (Edit class not propagated). Serializing the test order keeps the signals distinct.

---

## F8 proof-of-fix test

**Setup:** Baseline + both worktrees (`f6-f9-probe-01` and `f6-f9-probe-02`) exist.

**Dispatch:** TWO parallel children in a single message, both with the same prompt from `child-agent-task-template.md § F8 Reproducer`.

**Observable pass signal:** Child A returns `F8-A-READ-OK` AND Child B returns `F8-B-READ-OK`, with no asymmetric timing or re-prompts.

**Observable fail signals:**
- Either child returns `PROMPTED` or `DENIED`.
- Children return different outcomes (A OK, B PROMPTED) — this is the F8-specific asymmetry signature.
- Timing differs by >5 seconds between the two children's first tool call.

**Repeat:** 5 times (F8 is a timing race; 3 runs may not catch intermittent failures).

**Fix-validated if:** 5 of 5 runs return both `F8-A-READ-OK` and `F8-B-READ-OK` within 2 seconds of each other, no asymmetry.

---

## F9 proof-of-fix test

**Setup:** Fresh session. A path NOT listed in either settings.json — e.g., `/tmp/f9-probe-target.json` (create it first with `echo '{}' > /tmp/f9-probe-target.json`).

**Dispatch sequence:**
1. Parent Read on `/tmp/f9-probe-target.json`. UI fires permission prompt. **Accept** the grant.
2. Immediately (no other tool calls) dispatch one child per `child-agent-task-template.md § F9 Reproducer`.

**Observable pass signal:** Child returns `F9-READ-OK` on its first attempt.

**Observable fail signal:** Child returns `F9-READ-PROMPTED` — meaning the mid-session grant didn't propagate.

**Repeat:** 3 times, each in a fresh session, each with a different target path (`/tmp/f9-probe-{N}.json`) so no prior grant is cached.

**Fix-validated if:** 3 of 3 runs return `F9-READ-OK` with no child-side re-prompt.

**Cleanup:** `rm /tmp/f9-probe-*.json`

---

## Regression test (post-fix, combined)

Once all four are individually fix-validated, run the **combined regression**:

1. Fresh session.
2. Parent dispatches 2 parallel children, both `isolation: "worktree"` on different worktrees.
3. Each child performs: Read, Edit, Write on probe files in its worktree.
4. Expected: 6 tool calls across 2 children (3 each), zero re-prompts, zero denials, both children exit cleanly.

This combined test is the **exit criterion** named in the parent plan § Phase 3:
> "Two parallel agents complete a small-but-real task (e.g. each writing a 50-line case study section) without user intervention."

Passing this combined test unblocks parallel dispatch for all future multi-domain work.

---

## Observation log

Phase 1 executor appends per-run observations here.

| Run ID | Bug | Timestamp | Parent perm declared? | Child behavior | Re-prompt text | Classification confirmed? |
|---|---|---|---|---|---|---|
| _(empty — Phase 0 does not run dispatches)_ | | | | | | |

---

## Fix-ship checklist (per bug)

Copied from parent plan § Phase 2, adapted for this harness:

### If classified (a) — upstream bug
- [ ] Upstream issue filed with minimal reproducer attached from `child-agent-task-template.md`
- [ ] Warning banner added to `/Volumes/DevSSD/FitTracker2/.claude/skills/superpowers/dispatching-parallel-agents/SKILL.md` (if that path exists — else wherever the skill source lives)
- [ ] `dispatch-intelligence.json` updated with a `concurrent_dispatch.known_blockers` entry referencing the upstream ticket
- [ ] Phase 0 reproducer re-run, result logged as "still failing, upstream fix pending" in the audit-trail table

### If classified (b) — config bug
- [ ] `.claude/settings.json` or `.claude/settings.local.json` patched with the fix
- [ ] Patch documented in commit message with before/after diff
- [ ] Phase 0 reproducer re-run, result logged as "PASS after config fix"
- [ ] CLAUDE.md updated with the permission-declaration pattern

### If classified (c) — skill contract bug
- [ ] Affected skill's `SKILL.md` updated with explicit perm surface declaration
- [ ] Phase 0 reproducer re-run, result logged as "PASS after skill fix"
- [ ] Skill's integration test (if present) extended to cover the scenario

---

## Phase 3 exit criterion (from parent plan)

"Two parallel agents complete a task without user intervention. Validation case study shipped. Framework can return to using parallel dispatch for multi-domain work."

This harness's combined regression test IS that exit criterion. Passing it closes Phase 3.
