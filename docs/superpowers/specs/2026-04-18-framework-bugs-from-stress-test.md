# Framework Bugs Surfaced by Audit-v2 Stress Test

> Source: `docs/case-studies/audit-v2-concurrent-stress-test-case-study.md`
> Date filed: 2026-04-18
> Status (2026-04-19): **F1 + F2 + F3 + F4 + F5 fixed.** F6 positive (no action). F7 unblocked by F1 — concurrent stress test methodology can resume.
> - F1: glob expansion to `additionalDirectories` (PR #102, end-to-end verified)
> - F2/F3/F4: documented as `worktree_isolation_contract` in `.claude/shared/dispatch-intelligence.json`
> - F5: pre-granted `cd <worktree>/...` and `git -C <worktree> *` Bash patterns in `.claude/settings.local.json`

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

## Filing Status

| Bug | Filed | GitHub Issue | Owner | Status |
|---|---|---|---|---|
| F1 | This doc | TBD | Framework team | OPEN — blocks any concurrent worktree dispatch |
| F2 | This doc | TBD | Framework team | OPEN — protocol gap |
| F3 | This doc | TBD | Framework team | OPEN — documentation gap |
| F4 | This doc | TBD | Framework team | OPEN — trust assumption |
| F5 | This doc | TBD | Framework team | OPEN — sandbox over-restriction |
| F6 | This doc | n/a | Framework team | POSITIVE — pattern to codify |
| F7 | This doc | n/a | Process — blocked by F1 | OPEN until F1 closes |

## Next Steps

- Decide which of F1–F5 to file as GitHub issues
- F1 is the only one that blocks future concurrent work; the others are quality-of-life
- F6 should be codified into `dispatch-intelligence.json` `salvage_pattern` section
