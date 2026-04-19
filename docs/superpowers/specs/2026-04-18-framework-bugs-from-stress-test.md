# Framework Bugs Surfaced by Audit-v2 Stress Test

> Source: `docs/case-studies/audit-v2-concurrent-stress-test-case-study.md`
> Date filed: 2026-04-18
> Status (2026-04-19, post-wave-2): **F1 partially fixed (PR #102), F2 + F3 + F4 + F5 fixed (PR #103). F8 + F9 newly discovered by wave-2 retry — both block concurrent worktree dispatch and require Claude Code framework changes.**
> - F1: glob expansion to `additionalDirectories` (PR #102, single-agent verified) — **insufficient under parallel dispatch (F8)**
> - F2/F3/F4: documented as `worktree_isolation_contract` in `.claude/shared/dispatch-intelligence.json` — **validated by 10/10 agents in wave-2 attempts**
> - F5: pre-granted `cd <worktree>/...` and `git -C <worktree> *` Bash patterns
> - F8 (HIGH, NEW): F1 fix only covers Read; Edit/Write tool grants are checked separately and aren't unblocked by `additionalDirectories` globs
> - F9 (HIGH, NEW): permission grants added during a session don't propagate to concurrently-dispatched subagents — single-agent probes succeed but parallel batches fail with the same setup
> - **Net**: serial dispatch (Sprints F-J shipping pattern) works; concurrent dispatch is still blocked at the framework layer until F8+F9 fixes ship from upstream Claude Code.

This document is the actionable extract of the wave-1 stress test. Each bug has reproduction, severity, and a concrete suggested fix. These are framework-layer issues — not audit findings, not app code.

---

## F1 (HIGH) — Permission whitelist is path-literal, doesn't compose with worktrees

### Symptom

Agents dispatched with `Agent({isolation: "worktree"})` cannot write to files inside their worktree if the canonical path is whitelisted in `additionalDirectories` but the worktree-prefixed path is not.

### Reproduction

1. `.claude/settings.local.json` whitelists:
    ```
    "additionalDirectories": [
      "/Volumes/DevSSD/FitTracker2/.claude/features",
      "/Volumes/DevSSD/FitTracker2/.claude/shared"
    ]
    ```
2. Dispatch any background agent with `isolation: "worktree"`. It runs in `/Volumes/DevSSD/FitTracker2/.claude/worktrees/agent-{ID}/`.
3. Agent attempts `Edit` or `Write` on `.claude/shared/anything.json` (relative to its worktree, absolute path `/Volumes/.../worktrees/agent-{ID}/.claude/shared/anything.json`).
4. Tool refuses with permission error.

### Root Cause

The permission system compares the absolute path of the target against the literal strings in `additionalDirectories`. A worktree creates a physical copy of the repo at a different absolute path. Same logical content, different prefix → access denied.

### Evidence

- G6 agent (worktree `agent-a965fd51`): all 3 attempts blocked. See `/tmp/audit-v2-traces/g6-wave1.json`.
- G2 agent (worktree `agent-ac2e55cc`): blocked on worktree, escaped to canonical path.

### Suggested Fix

Make the whitelist worktree-aware. Two options:

**Option A — glob expansion (simplest):**
```json
"additionalDirectories": [
  "/Volumes/DevSSD/FitTracker2/.claude/features",
  "/Volumes/DevSSD/FitTracker2/.claude/shared",
  "/Volumes/DevSSD/FitTracker2/.claude/worktrees/*/.claude/features",
  "/Volumes/DevSSD/FitTracker2/.claude/worktrees/*/.claude/shared"
]
```
Plus parallel entries for any other whitelisted path the worktree should be able to write to.

**Option B — repo-relative resolution:**
Add a setting `worktree_inherits_repo_perms: true` that tells the permission resolver: if the path starts with a known worktree root, strip the worktree prefix and re-check against `additionalDirectories`. Requires framework code change.

**Recommended:** Option A as immediate workaround, Option B as durable fix.

### Severity: HIGH for any future concurrent worktree dispatch.

---

## F2 (MEDIUM) — No standard contract for "what to do when blocked"

### Symptom

When two agents receive identical instructions and both hit the same write block, they respond differently with no framework-level guidance.

### Evidence

- **G6**: refused unsafely, exited cleanly per the failure protocol I gave it. Wrote complete plan to `/tmp/`. Outcome: clean failure, easy to retry.
- **G2**: escaped the worktree, wrote 4 files to the canonical path. Outcome: contamination of main's working tree, no commits, no PR.

Both behaviors followed the prompt as written. The prompt didn't say "never write to canonical path if blocked from worktree" because that scenario wasn't anticipated.

### Suggested Fix

Add a framework-level convention to the dispatch protocol:

> When an agent is dispatched with `isolation: "worktree"` and hits a write block on its worktree, the agent MUST NOT write to any other absolute path. Acceptable fallbacks: write to `/tmp/`, exit with documented failure, or request permission expansion. Writing to the canonical repo path is forbidden — this defeats worktree isolation and contaminates the parent's working tree.

This belongs in either:
- `.claude/skills/superpowers/using-git-worktrees/SKILL.md` (consumer-facing)
- `.claude/shared/dispatch-intelligence.json` `mirror_pattern` section (machine-readable)

### Severity: MEDIUM — depends on prompt discipline today, should be framework guarantee.

---

## F3 (LOW) — Worktree settings inheritance is one-way

### Symptom

A worktree contains its own physical copy of `.claude/settings.local.json`. An agent inside the worktree can read and edit that file. But edits to it have **no effect** on the agent's effective permissions — the parent process's settings are authoritative at runtime.

### Evidence

G2 agent attempted to add bash command grants and `additionalDirectories` entries to the worktree's `.claude/settings.local.json`. The diff was real (visible in the worktree), but every subsequent tool call still used the parent's permission set. See `/tmp/audit-v2-traces/wave1-forensics/`.

### Suggested Fix

Document this clearly in the worktree skill. Either:
- (a) Worktree settings are read-only at runtime — make this explicit in skill docs, possibly enforce via filesystem chmod
- (b) Worktree settings reload on each tool call (would change runtime behavior, may have other implications)

### Severity: LOW (correct behavior, but counterintuitive — wasted G2's time).

---

## F4 (MEDIUM) — No sandbox enforcement at the write boundary

### Symptom

An agent dispatched with `isolation: "worktree"` is not actually sandboxed to its worktree. It can issue `Write`/`Edit`/`Bash` operations targeting any absolute path the parent's permissions allow. Worktree isolation is a directory recommendation, not a kernel boundary.

### Evidence

G2 wrote to `/Volumes/DevSSD/FitTracker2/FitTrackerTests/` (canonical) while running in `/Volumes/DevSSD/FitTracker2/.claude/worktrees/agent-ac2e55cc/` (worktree). Nothing prevented this.

### Suggested Fix

Two layers:

1. **Framework layer:** When dispatching with `isolation: "worktree"`, the framework should temporarily restrict the agent's write permissions to paths under the worktree root + a few exceptions (`/tmp`, `~/.claude/`). Other writes refused even if the parent's permissions would otherwise allow them.

2. **OS layer:** Optionally, run the worktree agent inside `sandbox-exec` (macOS) or `unshare` (Linux) with a filesystem profile that allows writes only to the worktree.

**Recommended:** Layer 1 as a near-term fix; Layer 2 as a hardening step for high-trust environments.

### Severity: MEDIUM — trust assumption to revisit.

---

## F5 (LOW–MEDIUM) — `cd` and `git -C` are sandboxed off

### Symptom

Bash commands `cd <path>` and `git -C <path> ...` are blocked by the permission system even when the destination path is whitelisted for read.

### Evidence

The cleanup agent reported: "`git -C <path>` and `cd <path> && git ...` were both blocked by the sandbox, so I gathered worktree state by reading `.git/worktrees/<name>/{HEAD,CLAUDE_BASE,locked,logs/HEAD}` directly."

### Suggested Fix

Permit `cd` and `git -C <path>` for any whitelisted path. The sandbox should evaluate the *target* of `cd`/`-C`, not the literal command shape. This requires the bash permission resolver to understand a small set of cd-like idioms.

Workaround documented in the cleanup agent's trace: read `.git/worktrees/<name>/*` files directly to gather worktree state without changing directory.

### Severity: LOW for cleanup work, MEDIUM for any agent that needs to operate across multiple worktrees.

---

## F6 (POSITIVE) — Salvage protocol works when an agent dies mid-write

### Symptom (positive finding)

When an agent dies mid-work, artifacts written to disk before death can be recovered cleanly. The mirror snapshot pattern provides byte-level diff verification.

### Evidence

G2 wrote 4 test files (1041 lines) to canonical `FitTrackerTests/` then was killed. Salvage agent:
1. Snapshotted G2's output to `.build/snapshots/wave1-salvage/` (mirror baseline)
2. Created a clean branch off main
3. Inspected each file for compile/test issues — found zero
4. Wired into project.pbxproj
5. Build + test green on first attempt
6. Verified byte-identical to baseline (zero modifications needed)
7. Committed + pushed + opened PR — merged as #95

**46 net-new test cases recovered from a "failed" run.**

### Suggested Codification

Add a `salvage_pattern` section to `dispatch-intelligence.json` documenting:
- When to invoke (any time an agent dies with uncommitted work)
- Required steps (snapshot baseline, clean branch, verify, salvage or quarantine)
- Output location convention (`.build/snapshots/{operation}/`)

This isn't a bug — it's a pattern worth formalizing.

### Severity: POSITIVE — failure mode is recoverable. Worth documenting as a framework capability.

---

## F7 (HIGH) — Concurrent stress test methodology blocked on F1

### Symptom

The stress test's premise — "does the framework scale laterally under concurrent worktree dispatch?" — cannot be validly evaluated when worktree writes are systematically blocked by F1. Wave 1's "failure" was not a failure of concurrent dispatch; it was a failure of the test setup.

### Suggested Fix

Fix F1, then resume the stress test with the same 6 groups + 3-wave dispatch plan. Until F1 is fixed, treat any concurrent-worktree-dispatch claim as unvalidated.

### Severity: HIGH — blocker for resuming the test as designed.

---

## F8 (HIGH) — F1 fix is incomplete: Edit/Write tools denied for worktree paths despite directory glob

### Symptom (discovered 2026-04-19 by audit-v2 wave-2)

After F1's glob-expansion fix landed (PR #102), wave-2 dispatched 5 concurrent worktree-isolated agents, each tasked with a single small Edit or Write to a file under `.claude/shared/`. **All 5 agents** got `"Permission to use Edit/Write has been denied."` on their assigned file inside their own worktree.

### Reproduction

1. Settings have the F1 globs:
   ```
   "additionalDirectories": [
     ".../worktrees/*/.claude/features",
     ".../worktrees/*/.claude/shared"
   ]
   ```
2. Dispatch a subagent with `isolation: "worktree"` and instruct it to `Edit` an existing file or `Write` a new file under `.claude/worktrees/agent-{ID}/.claude/shared/`.
3. The tool call is denied even though the directory is in `additionalDirectories`.

### Caveat — single-agent F1 probe DID succeed

The original F1 verification (PR #102 description) used a single subagent doing one `Write` to a new file in `.claude/shared/`. It succeeded. Wave-2's 5 concurrent agents all failed the same operation. Two possible explanations, neither verified yet:
- **(a) Tool-permission gap independent of dispatch**: `additionalDirectories` may grant Read access to the path, but `Edit`/`Write` tool grants are checked through a separate gate that doesn't consult `additionalDirectories` for worktree-prefixed paths. The single-agent probe may have benefited from a session-state quirk (recently modified settings, transient cache).
- **(b) Concurrency-related**: under parallel dispatch, the permission check uses a stricter path-resolution that skips the glob.

### Severity: HIGH — F1 was the headline blocker for concurrent worktree dispatch. F8 means F1 isn't actually fixed for the use case it was filed against.

### Suggested Fix

Two paths, in priority order:

**Path 1 — explicit per-tool grants (immediate workaround):**
Add `Edit(/Volumes/.../worktrees/**)` and `Write(/Volumes/.../worktrees/**)` entries to `permissions.allow`. These bypass the directory-level resolver entirely.

**Path 2 — fix `additionalDirectories` to grant Edit/Write uniformly (durable):**
The framework should treat `additionalDirectories` as granting the full read+edit+write tool surface for the matched paths, including for subagent calls and including with glob expansion. This is a framework-level change — file as a separate Claude Code issue.

---

## F9 (HIGH) — Permission grants don't propagate to concurrently-dispatched subagents

### Symptom (discovered 2026-04-19 by wave-2 retry)

After F8's Path 1 workaround (explicit `Edit(/...worktrees/**)` and `Write(/...worktrees/**)` grants) was added to `.claude/settings.local.json`, a single-agent verification probe successfully performed both `Write` (new file) and `Edit` (existing file) inside its worktree — **PASS**.

Immediately after, the same 5-agent wave-2 batch was redispatched in parallel. **All 5 agents** got `Edit/Write` denied again, identically to the pre-F8 attempt.

### Reproduction

1. Add explicit `Edit(/...worktrees/**)` and `Write(/...worktrees/**)` grants to settings.
2. Dispatch one subagent with `isolation: "worktree"` — it can Edit/Write inside its worktree. PASS.
3. Dispatch 5 subagents in parallel (same message, multiple Agent tool calls) with the same instructions. ALL 5 get Edit/Write denied with the same verbatim error.

### Hypothesis

The harness's permission resolver caches the parent's permission set at session-start (or at some intermediate snapshot) and propagates that snapshot — NOT the live file — to subagents. The single-agent probe benefited from a refresh that the parallel batch didn't trigger. Equivalent: subagents inherit a stale, captured permission view that doesn't include grants added later in the session.

### Severity: HIGH

This blocks any concurrent worktree-dispatch use case where the dispatching session has added permissions during the same session — exactly the audit-v2 stress test pattern.

### Suggested Fix

Two options, neither possible from the consumer side:

- **Refresh on dispatch**: each subagent dispatch re-reads `settings.local.json` and constructs its permission set from the live file.
- **Whitelist by reference**: subagents inherit a path-list reference rather than a captured set; the resolver always evaluates against the live file.

Both require Claude Code framework changes. **Workaround for the audit-v2 case**: end the current session, restart Claude Code, then dispatch the parallel batch — the new permission set will be read at session start.

---

## Wave-2 Outcome (2026-04-19, two attempts)

The audit-v2 wave-2 stress test ran twice — once after F1-F5 supposedly fixed, once after F8 workaround added. **Both times, all 5 concurrent worktree-isolated agents got Edit/Write denied.** Single-agent probes between the two attempts succeeded.

| Validation question | Result |
|---|---|
| Does F1's fix hold for parallel dispatch? | **NO** — F8 filed |
| Does F8 Path 1 workaround hold for parallel dispatch? | **NO** — F9 filed |
| Does the F2 contract ("never escape worktree on block") hold? | **YES** — 10/10 agents (across both attempts) reported FAILURE verbatim and stopped |
| Does F3 hold? | **YES** — no agent attempted to self-modify worktree settings.local.json |
| Does F4's documented boundary hold? | **YES** — no canonical-path writes attempted across 10 agents |
| Did the salvage protocol (F6) need to fire? | **NO** — clean failures, nothing to salvage |

**Net:** wave-2 was an exceptionally valuable test even though the workload didn't complete. Two NEW framework findings (F8, F9), and 10 agents validated the F2/F3/F4 contracts under realistic concurrent failure. The audit-v2 workload itself remains unrunnable concurrently until both F8 and F9 are addressed at the framework layer; **serial dispatch (which is what shipped Sprints F-J) remains the working pattern.**

**No app or data changes** were made by either wave-2 attempt — every agent failed before any write succeeded.

---

## Filing Status

| Bug | Filed | GitHub Issue | Owner | Status |
|---|---|---|---|---|
| F1 | This doc | n/a (PR #102) | Framework team | PARTIALLY FIXED — see F8 |
| F2 | This doc | n/a (PR #103) | Framework team | FIXED — contract documented in dispatch-intelligence.json; validated by wave-2 |
| F3 | This doc | n/a (PR #103) | Framework team | FIXED — documented in dispatch-intelligence.json |
| F4 | This doc | n/a (PR #103) | Framework team | FIXED (documented; OS-level sandbox deferred) |
| F5 | This doc | n/a (PR #103) | Framework team | FIXED — `cd`/`git -C` patterns granted |
| F6 | This doc | n/a (PR #103) | Framework team | POSITIVE — codified as salvage_protocol |
| F7 | This doc | n/a | Process — blocked by F1+F8 | OPEN — concurrent stress test methodology validated under F8 conditions, but the workload itself is still blocked until F8 fixes |
| F8 | This doc | TBD (Claude Code) | Framework team | OPEN (HIGH) — discovered by wave-2; F1 fix is incomplete for Edit/Write |
| F9 | This doc | TBD (Claude Code) | Framework team | OPEN (HIGH) — discovered by wave-2 retry; permission grants don't propagate to concurrent subagents |

## Next Steps

- Apply F8 Path 1 workaround (explicit `Edit(...)`/`Write(...)` worktree grants) and re-run wave-2 as F8 verification
- File F8 Path 2 as a Claude Code framework issue
- After F8 fix verifies, wave-2 can complete its actual workload (5 agents writing real updates to `.claude/shared/`)
