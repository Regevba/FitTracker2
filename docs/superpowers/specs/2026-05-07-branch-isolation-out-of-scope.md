# Branch Isolation — Out-of-Scope Spec (v8.0+ candidates)

> **Companion to:** [`.claude/features/framework-v7-8-branch-isolation/prd.md`](../../../.claude/features/framework-v7-8-branch-isolation/prd.md) §11
>
> **Purpose:** explicitly list the 7 alternatives evaluated during Phase 0 research that were de-scoped for v7.8/v7.9 ship, with re-evaluation triggers and v8 prioritization criteria.
>
> **Created:** 2026-05-07 alongside Phase 1 (PRD) of `framework-v7-8-branch-isolation`.
>
> **Phase 9 deliverable:** at branch-isolation feature close (Phase 9 / Learn), produce a prioritized v8 roadmap selecting which of these 7 items advance, in what order, and against which 90-day data signal.
>
> **Evaluation criteria:** (a) does the v7.9-enforced gate stack already cover the failure mode? (b) has a re-eval trigger fired? (c) does the chosen approach extend existing infrastructure or introduce new subsystems? (d) what's the cu_v2 estimate?

---

## How to read this doc

Each item below has the same shape:

- **What it is** — concise definition + the cluster from research §3.1
- **Why it was deferred** — selection-rule justification
- **Re-evaluation trigger** — empirical signal that should reopen the discussion
- **What v8 would build** — sketch of the actual scope (NOT a PRD; that's Phase 0 of the future feature)
- **Estimated cu_v2** — best-guess complexity factors for prioritization
- **Backlog ref** — link to the corresponding entry in [`docs/product/backlog.md`](../../product/backlog.md)

---

## Item 1 — Sapling-smartlog-style live awareness UI

- **What it is:** a non-blocking, always-visible view of every active agent's branch, declared in-flight paths, and minutes-since-last-write. Agents query the view before deciding to proceed; users see at-a-glance who's working on what.
- **Cluster:** A — Version-control isolation
- **Why deferred:** requires a new UI surface (web dashboard or CLI TUI). The branch-isolation gate ships without it because pre-commit + cycle-time advisories cover the *prevention* side; a smartlog covers the *visibility* side, which is a separable concern.
- **Re-evaluation trigger:** multi-agent parallel-work patterns mature to **5+ concurrent active features** routinely (today: 1-2 concurrent). Signal: `agent-leases.json` has ≥ 5 entries with `status: active` continuously for 7+ days.
- **What v8 would build:**
  - `/control-room/agents` route on fitme-story (Next.js) reading `agent-leases.json`
  - Per-agent card: branch, worktree, declared paths (read/write), last-heartbeat
  - Path-overlap detection: highlight conflicting `writes` across agents
  - Optional CLI mirror: `make agent-status`
- **Estimated cu_v2:**
  - complexity: 0.7 (new UI surface + dashboard integration)
  - blast_radius: 0.4 (new route, doesn't touch existing gates)
  - novelty: 0.6 (Sapling pattern, not yet implemented in this codebase)
  - verification_difficulty: 0.5 (visual; needs human review)
  - **total: 2.2 · tier_class: B_medium**
- **Backlog ref:** [backlog.md "v8 Branch-Isolation Visibility — Agent Smartlog UI"](../../product/backlog.md)

---

## Item 2 — Op-log-based recoverable rollback (jj-style)

- **What it is:** every agent operation (state.json mutation, file write, gate fire) records a replayable entry in a per-workspace operation log. Abandoned/rolled-back work cleans up via op-log undo without leaving stash debris or orphan state.
- **Cluster:** A — Version-control isolation
- **Why deferred:** needs new infrastructure (op-log writer, replay engine, garbage-collection policy). The branch-isolation gate ships with `--no-verify` + `manual_bypass` ledger as the recovery primitive; that's enough for v7.8/v7.9.
- **Re-evaluation trigger:** **≥ 3 instances in 90 days** where a feature was abandoned mid-flight and required manual cleanup of stash + orphan worktrees + drifted `.claude/settings.local.json`. Signal: count of `git stash list` lines > 5 across all worktrees for 30+ consecutive days, OR ≥ 3 forensic memory entries citing "stash @{N} preserved for case-by-case audit".
- **What v8 would build:**
  - `.claude/op-log/<session-id>.jsonl` per Claude Code session (extend Mechanism C session events)
  - `make op-log replay <session-id> --to <op-id>` — rewind the session's writes
  - `make op-log gc` — prune sessions ended cleanly older than 14 days
  - State.json mutation wrapper that writes to op-log before committing
- **Estimated cu_v2:**
  - complexity: 0.8 (new write-through pipeline, replay engine)
  - blast_radius: 0.7 (touches every state.json write path)
  - novelty: 0.7 (jj pattern, not implemented)
  - verification_difficulty: 0.7 (correctness of replay is hard to test)
  - **total: 2.9 · tier_class: A_high**
- **Backlog ref:** [backlog.md "v8 Branch-Isolation Recovery — Op-log Replay"](../../product/backlog.md)

---

## Item 3 — Vercel Sandbox / Firecracker microVM isolation

- **What it is:** process-level isolation via lightweight VMs. Each agent runs in its own microVM with declared resource budgets and filesystem boundaries. Hypervisor-enforced.
- **Cluster:** C — Hermetic build / action models
- **Why deferred:** **overkill for cooperative agents** on the same machine. The threat model in v7.8 is "agents accidentally clobber each other", not "untrusted code execution". MicroVM infrastructure adds substantial complexity disproportionate to gain over branch+cwd checking.
- **Re-evaluation trigger:** untrusted-code-execution use case emerges, e.g. **user-submitted scripts** running in framework context (e.g. user provides their own analytics taxonomy validator script and we need to run it sandboxed), OR external auditor wants to replicate the framework against a foreign codebase without trusting it.
- **What v8 would build:**
  - Vercel Sandbox integration adapter at `.claude/integrations/vercel-sandbox/`
  - Per-task sandbox spawn with declared inputs/outputs (Bazel-action-like)
  - Sandbox-mediated state.json write protocol
- **Estimated cu_v2:**
  - complexity: 0.9 (new infrastructure layer)
  - blast_radius: 0.8 (changes how every agent task runs)
  - novelty: 0.8 (no precedent in this codebase)
  - verification_difficulty: 0.6 (sandbox semantics well-defined; integration is the hard part)
  - **total: 3.1 · tier_class: A_high**
- **Backlog ref:** [backlog.md "v8 Untrusted-Code Sandbox — Vercel Sandbox / Firecracker"](../../product/backlog.md)

---

## Item 4 — Filesystem-level kernel sandboxing (Linux Landlock / macOS App Sandbox)

- **What it is:** kernel-enforced declarative scopes — agent processes can only read/write paths they explicitly declared. Violations rejected at syscall level.
- **Cluster:** D — Filesystem-level sandboxing
- **Why deferred:** **OS-specific** (Landlock is Linux-only ≥ 5.13; App Sandbox is macOS-only). Doesn't translate across dev/CI environments. Heavier than what cooperative agent workflow needs — pre-commit + cwd checks achieve the same intent in userspace.
- **Re-evaluation trigger:** **regulatory / compliance requirement** mandates kernel-level enforcement (e.g. HIPAA-grade audit trail for who-touched-what), OR the framework is adopted in a multi-tenant context where agents have differing trust levels.
- **What v8 would build:**
  - Per-agent profile generators (Landlock ruleset / sandbox-exec config)
  - Pre-dispatch profile injection (agent process launched under sandbox)
  - Cross-platform fallback to userspace cwd checks where kernel isolation unavailable
- **Estimated cu_v2:**
  - complexity: 0.8 (kernel APIs, profile generation)
  - blast_radius: 0.6 (per-agent only, doesn't touch shared state)
  - novelty: 0.85 (zero kernel-isolation code in this codebase)
  - verification_difficulty: 0.8 (kernel-level testing requires integration tests on each platform)
  - **total: 3.05 · tier_class: A_high**
- **Backlog ref:** [backlog.md "v8 Kernel-Level Isolation — Landlock / App Sandbox"](../../product/backlog.md)

---

## Item 5 — inotify/fsevents broadcast mediator

- **What it is:** lightweight OS-portable file-watcher daemon that detects writes to declared shared paths and broadcasts notifications to subscribed agents. **Detects** the write but doesn't prevent it.
- **Cluster:** D — Filesystem-level sandboxing (mediator subset)
- **Why deferred:** **post-MVP enhancement.** Detection-only — the gate stack already prevents writes via pre-commit; broadcast is additive not replacing. Complementary to the chosen approach.
- **Re-evaluation trigger:** **≥ 2 separate incidents** in 60 days where two agents wrote to the same shared path within < 60 seconds (concurrent write collision), AND the resulting merge required > 30 minutes of manual reconciliation. Signal: `gate-coverage.jsonl` entries showing close-in-time mutations to overlapping paths from different sessions.
- **What v8 would build:**
  - `scripts/path-watcher.py` — long-running daemon using `watchdog` library (cross-platform)
  - Subscription protocol: agents register for paths via `agent-leases.json`
  - Broadcast: on write detection, push notification to `.claude/logs/path-events.jsonl`
  - Pre-write check: agent reads recent path-events before its own write to detect concurrency
- **Estimated cu_v2:**
  - complexity: 0.5 (existing watchdog library; integration is straightforward)
  - blast_radius: 0.3 (additive observability, doesn't change existing flows)
  - novelty: 0.5 (well-trodden pattern outside this codebase)
  - verification_difficulty: 0.6 (race-condition testing)
  - **total: 1.9 · tier_class: B_medium**
- **Backlog ref:** [backlog.md "v8 Concurrent-Write Detection — Path Watcher Daemon"](../../product/backlog.md)

---

## Item 6 — Cross-feature dependency analysis

- **What it is:** automated analysis of which features touch which paths, surfacing implicit dependencies + potential conflict risk before dispatch. Visualization layer over `path-reducers.json` + per-feature `agent_manifest.reads` / `writes` declarations.
- **Cluster:** E — Multi-agent coordination
- **Why deferred:** **needs path-reducer registry to mature first.** v7.8 ships path-reducers as a schema bridge with 4 initial entries. v8 builds the analysis layer once registry is well-populated (≥ 20 entries with diverse merge-semantics).
- **Re-evaluation trigger:** **`path-reducers.json` reaches ≥ 20 entries** with at least 3 distinct merge semantics, AND ≥ 2 cross-feature conflicts surface organically (one feature's `writes` overlap with another feature's `reads`).
- **What v8 would build:**
  - `make feature-deps` — produces a directed graph of feature ↔ path ↔ feature
  - Pre-dispatch warning when planned dispatch declares writes overlapping with another active feature's declared reads
  - Conflict-resolution suggestions (serialize dispatch, declare read-only mode, etc.)
  - Visualization route: `/control-room/dependencies` (depends on Item 1's smartlog UI)
- **Estimated cu_v2:**
  - complexity: 0.6 (graph analysis, not novel)
  - blast_radius: 0.5 (advisory layer)
  - novelty: 0.4 (well-understood graph problem)
  - verification_difficulty: 0.5
  - **total: 2.0 · tier_class: B_medium**
- **Backlog ref:** [backlog.md "v8 Multi-Agent Coordination — Cross-Feature Dependency Graph"](../../product/backlog.md)

---

## Item 7 — Auto-rollback on kill criteria fire

- **What it is:** when a feature's kill criteria fire post-launch (e.g. `Notification opt-in rate < 20% after 30 days`), the framework automatically opens a revert PR and notifies the operator. Today: human triggers revert.
- **Cluster:** Process-level (not in research clustering — this is a v7.9+ ops layer)
- **Why deferred:** **safety verification not yet established.** Auto-rollback is dangerous — wrong threshold, wrong metric, wrong attribution → unintended production revert. Need ≥ 2 manual rollback dry-runs to verify the procedure works before automating.
- **Re-evaluation trigger:** **T+7d telemetry shows kill criteria firing cleanly** (correct threshold + correct attribution + no false-positives) AND the revert procedure runs successfully ≥ 2 times manually with clean results.
- **What v8 would build:**
  - `make verify-revert <feature>` — dry-run revert simulation, verifies post-revert state
  - `scripts/auto-rollback.py` — listens to `metric-status.json` updates, triggers revert PR when kill criteria fire
  - Revert PR template referencing kill_criteria + kill_criteria_resolution
  - Operator approval gate (auto-rollback opens PR; human merges)
- **Estimated cu_v2:**
  - complexity: 0.7 (cross-cuts metric-status, PR creation, revert procedure)
  - blast_radius: 0.9 (production-affecting if wrong)
  - novelty: 0.6 (no auto-rollback infrastructure today)
  - verification_difficulty: 0.85 (proving correctness across all kill-criteria types is hard)
  - **total: 3.05 · tier_class: A_high**
- **Backlog ref:** [backlog.md "v8 Operations — Auto-Rollback on Kill Criteria"](../../product/backlog.md)

---

## Phase 9 prioritization pass — what to compute

When `framework-v7-8-branch-isolation` reaches Phase 9 (Learn) — earliest 2026-05-21 (T+14d post-ship of v7.8 advisory + 7d measurement window), produce a v8 roadmap as part of the case study.

### Inputs to the prioritization pass

- 7-day telemetry from `gate-coverage.jsonl` for both new gates
- `make documentation-debt` open count trend (week-1 vs ship-day)
- `agent-leases.json` active-lease count
- `path-reducers.json` entry count (signal for Item 6 re-eval)
- Forensic memory entries for stash/orphan-worktree drift (signal for Item 2 re-eval)
- Concurrent-write incidents (signal for Item 5 re-eval)
- Any new external requirements (signals for Items 3, 4, 7)

### Output of the prioritization pass

A ranked list of the 7 items with:
1. **Re-eval trigger status** — fired / not fired / partially fired
2. **cu_v2 re-estimate** — has the complexity changed since 2026-05-07?
3. **Dependency on this feature** — does Item N require infrastructure that v7.8 + v7.9 enforced gates establish?
4. **Recommendation** — schedule for v8.0 / v8.1 / v8.2 / defer further

The output ships as a section of the `framework-v7-8-branch-isolation` case study (Phase 9 deliverable) and a backlog reorganization PR that updates the relative ordering of the 7 entries.

### Anti-prioritization rule

**Do NOT pull items into v7.8 mid-flight.** The branch-isolation feature ships with its current scope. v8 candidates are scheduled at v8 PRD time, not retroactively scoped into v7.8.

---

## How this doc relates to backlog.md

The 7 backlog entries (one per item, dropped under "Backlog (Unscheduled — from gap reviews and PRD)" in [`docs/product/backlog.md`](../../product/backlog.md)) are short pointers — feature title + 1-line summary + cu_v2 estimate + link back to this spec for the full breakdown. This doc is the canonical source; backlog.md is the index.

When the Phase 9 prioritization pass produces the v8 roadmap, the backlog entries get reordered and may move into "Planned (Roadmap Tasks — RICE Ordered)" with explicit RICE scores. This doc stays as the historical record of "here's what we evaluated in Phase 0 of branch-isolation".

---

## Audit trail

| Date | Action | Owner |
|------|--------|-------|
| 2026-05-07 | Document created at PRD ship of `framework-v7-8-branch-isolation` (Phase 1 close) | claude-opus-4-7 (Phase 1 dispatch) |
| TBD | First prioritization pass — Phase 9 of branch-isolation | tied to feature Phase 9 |
| TBD | v8 roadmap published | post-Phase-9 |

---

## References

- [`research.md` §10.2](../../../.claude/features/framework-v7-8-branch-isolation/research.md) — original out-of-scope decision rationale
- [`prd.md` §11](../../../.claude/features/framework-v7-8-branch-isolation/prd.md) — concise list (this doc is the long form)
- [`feature-lifecycle-event-catalog.md` §11](../../architecture/feature-lifecycle-event-catalog.md) — known mechanical limits framing
- [`framework-v7-8-bridge-case-study.md`](../../case-studies/framework-v7-8-bridge-case-study.md) — v7.8 ship narrative with v7.9 measurement window pointer
- [`docs/research/2026-05-01-framework-v7-8-branch-isolation-survey.md`](../../research/2026-05-01-framework-v7-8-branch-isolation-survey.md) — full prior-art survey (cluster A-E classification)
