# v7.8 Branch-Isolation Membrane — Research Note + Design Analysis

**Status:** Research-only. The user's instruction (2026-05-01) was to document this idea and the analysis regardless of whether we move forward. This note is the input to the eventual v7.8 design doc, not the design doc itself.

**Trigger:** HADF Phase 2 experiment + the 2026-05-01 PR #169 fallout both surfaced that parallel agents working on separate branches in this repo are NOT actually isolated from each other in practice. The user's framing (verbatim, 2026-05-01):

> can we create or mimic an agent or branch dedicated partial sandbox membrane, that agents are aware to the work of other agents and any feature work that is being done doesn't interfere with the work of other agents

**Source memos:**
- `memory: project_framework_gaps_audit_2026_04_30.md`
- `memory: project_bug_retrospective_2026_05_01.md`
- `memory: project_framework_v7_8_research_plan.md` (Topic 7)
- `memory: project_framework_honesty_fixes_shipped_2026_05_01.md` (the empirical case)
- `memory: project_unified_control_center.md` (architectural neighbor)

---

## 1. The problem (specific to this codebase)

Two recent incidents are the empirical input. They reveal that "isolation" is failing in two distinct ways.

### 1.1 HADF Phase 2 — concurrent shared-state writes

The HADF campaign runs an unattended fingerprint-collection job in a worktree at `/Volumes/DevSSD/FitTracker2-hadf-campaign/`, while parallel feature work continues on `main` and on feature branches in the primary worktree. Observed collisions:

- `.claude/settings.local.json` drifts on every commit; both worktrees' working copies disagree
- `.claude/shared/hadf/*` lives on disk and gets clobbered by whichever worktree commits last
- The launchd plist for the HADF wrapper writes to a relative path that resolves to whichever `WorkingDirectory` is current — required pinning to a specific worktree path to avoid orphaning data

### 1.2 PR #169 — schema migration breaks downstream consumer silently

Today's `created` → `created_at` rename across 43 state.json files broke `scripts/measurement-adoption-report.py` because the consumer read the legacy field name. The break was silent: report ran without errors but returned `post-v6: 0` instead of `post-v6: 11`. Caught by the user's mid-session instruction to "run against the entire gating system" — would have shipped to main otherwise.

The deeper pattern: a schema change on a path many consumers read crossed agent-task boundaries that nothing in our framework currently models. Agent A (the migration agent) had no way to discover Agent B (the report-builder agent) and vice versa.

### 1.3 What "isolation" should mean

The user's framing decomposes into four properties:

| Property | What it gives | What today's setup does |
|---|---|---|
| **Read-shared, write-isolated** | Agents see each other's work; writes are scoped to declared paths | Worktrees give file-tree isolation but shared dirs (`.claude/shared/*`, `.claude/settings.local.json`) are race-able |
| **Awareness without blocking** | Agent B can see "Agent A is mid-flight on path X" without locking X | No mechanism. Discovery is at PR-merge time, after-the-fact |
| **Conflict detection at write-time** | First overlapping write triggers a coordination event, not a merge conflict | Merge-conflict detection is the current mechanism; runs at PR-rebase or PR-merge — too late |
| **Recoverable state** | Abandoned/rolled-back agent work cleans up automatically | Stashes pile up; orphan worktrees survive; settings.local.json drifts persist |

---

## 2. Prior art surveyed

(Compressed from the research agent's full survey — see memory `project_framework_v7_8_research_plan.md` Topic 7 for the working list. The agent's report is reproduced verbatim in §99 below for the next-session design doc to cite.)

### 2.1 Five clusters of prior art

**A. Version-control isolation:** Git worktrees + sparse-checkout (current de-facto, leaky on shared dirs); Pijul (patch-based, explicit deps between changes); Sapling smartlog (Meta's stacked-diff awareness UX); Jujutsu (op-log per workspace, replayable rollback).

**B. Concurrent-edit / merge models:** CRDTs — Yjs/Automerge (commutative ops, deterministic merge); MRDTs — invariant-preserving CRDTs (Microsoft Research India); append-only logs — Hypercore/multifeed (per-author log, merged-on-read view); OT (centralized, dominated by CRDTs for offline-first cases).

**C. Hermetic build / action models:** Bazel remote execution (declared inputs/outputs, content-addressed); Nix profiles + overlays (declarative path isolation); Vercel Sandbox / Firecracker microVMs (process-level isolation — overkill for cooperative agents).

**D. Filesystem-level sandboxing:** Linux Landlock / macOS App Sandbox (kernel-enforced declarative scopes); inotify/fsevents mediator (detect-and-broadcast pattern, lightweight, OS-portable).

**E. Multi-agent coordination:** LangGraph reducers (per-key merge-semantics declared at graph-build time); AutoGen GroupChat (serialized turn-taking — coordinator pattern, not isolation); AI agent tool-call sandboxing (host-mediated tool layer is the natural enforcement point).

### 2.2 Top-3 primitives ranked for our problem

1. **LangGraph-style per-key reducers + Bazel-style action manifests.** Each shared path declares its merge semantics (append, replace, max, exclusive-write, …). Each agent task declares `reads:[paths]` and `writes:[paths]`. A pre-dispatch coordinator detects overlapping writes and either schedules them serially or rejects the second writer with a clear "Agent X holds path Y" message. Highest leverage, lightest infrastructure.

2. **MRDTs for shared append-mostly ledgers.** `measurement-adoption-history.json`, `documentation-debt.json`, per-feature logs. Every entry carries causal metadata; merges become deterministic and concurrent appends never conflict. State.json itself stays a normal file because its invariants (current_phase ∈ enum, timing.phases monotonic) are too sharp for a generic CRDT — they need invariant-preserving merge functions.

3. **Sapling-smartlog awareness view + jj op-log recovery.** A live, non-blocking view of every active agent's branch + which paths it has declared as in-flight + how many minutes since its last write. Agents query this view before deciding to proceed. Op-log gives cheap, replayable rollback when an agent abandons work.

### 2.3 The pivotal open question

Before any v7.8 design can be drafted, one classification question needs an answer:

> Are shared-path conflicts in this project predominantly on **append-mostly ledgers** (which CRDTs solve cleanly) or on **invariant-bearing documents** (which require either a coordinator or invariant-preserving merges)?

Inputs to classify:
- The HADF Phase 2 incident (which class of file collided?)
- The PR #169 fallout (which class of file caused the silent break?)
- The 2026-04-30 merge-marathon stashes (9 stashes still around — what paths do they touch?)

Until that classification is in, choosing between Primitive 1 (action manifests) and Primitive 2 (CRDTs) is premature.

---

## 3. What would change in the framework

This section assumes — for the sake of analysis — that we adopt a hybrid of Primitives 1 + 2 + 3 (action manifests + CRDTs for ledgers + smartlog view). Section 4 then asks whether we *should*. Section 6 gives the honest call.

### 3.1 Schema additions

**Per-feature `state.json`:**

```json
{
  "feature_name": "...",
  "current_phase": "implementation",
  "agent_manifest": {
    "reads": [
      ".claude/shared/skill-routing.json",
      ".claude/shared/measurement-adoption.json"
    ],
    "writes": [
      ".claude/features/auth-polish-v2/state.json",
      ".claude/logs/auth-polish-v2.log.json"
    ],
    "shared_writes": [
      {
        "path": ".claude/shared/measurement-adoption-history.json",
        "merge_strategy": "append",
        "reducer": "snapshot_dedup_by_date"
      }
    ]
  }
}
```

**New `.claude/shared/agent-leases.json`** — the live coordinator state:

```json
{
  "version": "1.0",
  "leases": [
    {
      "agent": "auth-polish-v2",
      "branch": "feature/auth-polish-v2",
      "worktree": "/Volumes/DevSSD/FitTracker2",
      "started_at": "2026-05-01T04:00:00Z",
      "last_heartbeat": "2026-05-01T04:42:00Z",
      "writes": ["..."]
    }
  ]
}
```

**New `.claude/shared/path-reducers.json`** — the merge-semantics registry:

```json
{
  "version": "1.0",
  "paths": {
    ".claude/shared/measurement-adoption-history.json": {
      "merge_strategy": "append_dedup",
      "dedup_key": "date"
    },
    ".claude/shared/skill-routing.json": {
      "merge_strategy": "exclusive_write",
      "owner_features": ["framework-v*"]
    },
    ".claude/features/*/state.json": {
      "merge_strategy": "exclusive_write_per_path",
      "owner": "the feature directory's name"
    }
  }
}
```

### 3.2 Tooling additions

**1. `scripts/membrane-acquire.py <feature> --writes <paths> --reads <paths>`** — registers a lease in `agent-leases.json`. Refuses if any declared write conflicts with a live lease whose path-reducer is `exclusive_write`. Emits a "see also: agent X mid-flight on Y" message when conflicts are detected so agents have awareness before action.

**2. Pre-commit hook extension** — already-staged files must match the lease's declared writes. A commit that touches `.claude/shared/measurement-adoption-history.json` without that path being in the lease is rejected. Closes the case where Agent A "just edits the shared file because it's there."

**3. CRDT layer for ledgers.** `scripts/append-cache-hit.py`, `scripts/append-feature-log.py`, and the measurement-adoption history writer rewrite their underlying file via a CRDT-aware library (e.g., Automerge bindings) instead of `json.load → mutate → json.dump`. Concurrent appends stop racing.

**4. `scripts/membrane-status.py`** — text-mode smartlog. Lists all live leases, their declared write sets, last heartbeat, and any overlapping in-flight changes on PRs not yet merged. Surfaces the "Agent B knows Agent A is mid-flight" property.

**5. Heartbeat / cleanup daemon (optional, OS-portable).** A `launchd` (macOS) / `systemd-user` (Linux) job that prunes stale leases (no heartbeat for >2h) and removes orphan worktrees. Without this, leases accumulate.

### 3.3 Workflow additions

**Per agent session start** (`/pm-workflow {feature}`):
1. Lease acquisition — `membrane-acquire` is called automatically
2. Schema check verifies the manifest declares paths the work will actually touch
3. Lease emits a notification (today: stdout; tomorrow: control-room dashboard event)

**Per commit** (pre-commit hook):
1. Verify all staged paths are in the lease's `writes`
2. Verify no path's reducer is violated (e.g., not appending to an `append_dedup` ledger via `>` overwrite)
3. Refresh lease heartbeat

**Per PR open** (PR-integrity bot):
1. Render the `membrane-status` of the PR's feature branch + 5 most-recently-active others into the PR description
2. Flag any "PR's writes overlap with live leases on other branches" with the specific paths

**Per session end:**
1. Lease release — explicit `membrane-release` OR auto-cleanup on no-heartbeat-for-2h

### 3.4 Integration with the existing v7.7 mechanical gates

| Existing gate | How v7.8 membrane augments it |
|---|---|
| `SCHEMA_DRIFT` (legacy `phase` / `created`) | Unchanged. Membrane is orthogonal — schema gates check intra-file invariants, membrane checks inter-agent conflicts. |
| `PHASE_TRANSITION_NO_LOG` | The lease acquisition records a `phase_started` log event automatically — closes the same gap from a different angle. |
| `PHASE_TRANSITION_NO_TIMING` | Lease records `started_at`; release records `ended_at`. Reduces agent-attention burden. |
| `CACHE_HITS_EMPTY_POST_V6` | Membrane writer-path manifests are the *prerequisite* for the unclosable Class B gap (issue #140). When a manifest declares "I read `.claude/shared/skill-routing.json`," wrapping that read with `log-cache-hit.py` becomes mechanical, not agent-attention-dependent. |
| `CU_V2_INVALID` | Unchanged. |
| `STATE_NO_CASE_STUDY_LINK` | Unchanged. |
| `BROKEN_PR_CITATION` | Unchanged. |
| `CASE_STUDY_MISSING_TIER_TAGS` | Unchanged. |
| `CASE_STUDY_MISSING_FIELDS` | Unchanged. |
| `FRAMEWORK_VERSION_FORMAT` (today's PR) | Unchanged. |
| `BROKEN_PR_CITATION` (write-time) | Unchanged. |
| 13 cycle-time codes | A 14th could be added: `ORPHAN_LEASE` — a lease whose feature has no `current_phase` change in 7 days. |

The membrane sits *above* the existing gates conceptually: "before you commit, your write set must be a subset of your declared lease," and the existing gates fire on whatever does pass that subset check.

### 3.5 Integration with the UCC + control-room dashboard

`/control-room/framework` is the natural surface for the lease/smartlog view. New section: **§7 Active leases** — live table of every agent's branch, declared writes, last heartbeat, conflict count. Updates via the same sync pipeline that already feeds the framework-health page.

This means the membrane is *visible to the operator at a glance*. The user can see, in admin-only mode at the control-room URL, "Agent A is on PR #169 with writes {schema, 45 state.json}; Agent B is on `feat/ucc-t31-builder-port` with writes {dashboard sync}; no conflicts" — a property that doesn't exist in any other multi-agent framework I know of, because they don't have a published-status-page model.

---

## 4. Tradeoffs

### 4.1 What it costs

**Engineering cost (one-time):**
- Schema migration to add `agent_manifest` + `shared_writes` to all 46 state.json files
- 5 new scripts (acquire/release/status + heartbeat daemon + CRDT writer wrappers)
- Pre-commit hook extension + 1 new cycle-time check code
- CRDT library (Automerge) added as project dependency
- Documentation: agent-onboarding guide, reducer authoring guide
- PR-integrity bot rendering changes
- Control-room dashboard §7 view

Estimated: **5-8 dev days for the minimum viable version, 12-15 for the full hybrid.**

**Engineering cost (recurring):**
- Every new feature needs its manifest authored (similar weight to authoring `success_metrics`)
- Every new shared path needs a reducer registered
- The path-reducer registry needs a review process so reducer-authoring doesn't drift

**Runtime cost:**
- ~50ms per pre-commit (lease check + reducer validation against staged files)
- ~100KB-1MB on-disk for the leases + history files
- Heartbeat daemon: negligible (one wakeup per 5 min)

**Cognitive cost:**
- Authors must learn what reducers are, which one applies to their writes
- Mental model shift: "I'm not just writing files, I'm operating under a lease"
- Failure mode: agents routed around the lease via `--no-verify` and the membrane silently degrades to current state

### 4.2 What it prevents

| Failure mode caught today only at merge | Caught by membrane at write-time |
|---|---|
| HADF-style worktree shared-path collision | Yes — second worktree's `.claude/shared/hadf/*` write rejected |
| PR #169-style downstream consumer silent break | Partially — the consumer's `reads` declaration would have flagged that the schema change touched a path the consumer reads. Not a perfect check (read-set declarations are coarse) but creates a discovery surface. |
| Stale settings.local.json drift | Partially — if `.claude/settings.local.json` reducer is `local_only_no_commit`, commits touching it are rejected. Doesn't prevent disk drift, only commit drift. |
| Two agents both editing the same state.json | Yes — exclusive_write reducer per-path means second agent's lease acquisition fails. |
| Append-only ledger race (measurement-adoption history) | Yes — CRDT writer makes concurrent appends commutative; no overwrites. |
| Orphan worktrees from abandoned agent runs | Yes — heartbeat cleanup. |

### 4.3 Where it would be overkill

If the project's parallel-agent volume stayed at the current level (1-3 active branches at any time, mostly serial dispatch because F6-F9 framework bugs block parallel), the membrane is overkill. The existing process — careful merging, occasional manual janitorial work — is cheaper per-incident than 5-8 dev-days upfront + per-feature manifest authoring.

If the project's shared paths stayed at the current count (~5 ledger files, ~46 state.json files, all owned by a clear feature directory), reducer registration is mostly mechanical and the registry stays small.

But if either of those scales — say, 5+ concurrent agents with overlapping write sets, or 20+ shared mutable paths — the merge-time conflict resolution cost grows super-linearly while the membrane's cost grows linearly.

### 4.4 Where it would create system overload

**Risk: bureaucracy without value.** A lease per agent task means every `/pm-workflow` invocation grows ~10 seconds of acquire/check overhead. If most tasks don't actually conflict with anything, the overhead is dead weight. Mitigation: skip lease acquisition for chore work-type tasks (smaller blast radius, fewer shared writes).

**Risk: reducer-registry rot.** New shared paths get added without reducer registration. The registry becomes incomplete; agents work around the gap with `--no-verify`. Mitigation: the registry itself is a state.json-style auditable file; missing entries become a cycle-time finding.

**Risk: false positives.** Two agents legitimately need to append to the same history file. If the reducer is wrong (`exclusive_write` instead of `append_dedup`), legit work is blocked. Mitigation: reducer authoring needs a 1-2 person review like a schema migration.

**Risk: opacity.** Agents fail with "lease conflict on path X" without enough context to resolve. Mitigation: every lease conflict message must include "see PR #N for the in-flight work" + "to take over, contact Agent A" + "to coordinate, see /control-room/framework §7."

---

## 5. Recommendation

**Honest read:** the membrane is a real solution to a real problem we genuinely have, but the problem is currently 5-10x smaller than the membrane's full scope. A phased thin-slice approach — primitive 2 first, then primitive 1 if usage stays high — is what I'd recommend.

### 5.1 Conditions under which I'd recommend implementing now (vs. deferring)

- The classification question in §2.3 resolves toward append-mostly ledgers (Primitive 2 is cheap; ship the CRDT layer for `measurement-adoption-history.json` first)
- F6-F9 (parallel-dispatch framework bugs) get fixed AND parallel agent dispatch becomes routine — at which point Primitive 1 (action manifests) earns its keep within weeks
- A second HADF-style incident lands (worktree collision pattern recurs), proving the failure mode is not a one-off

### 5.2 Conditions under which I'd recommend NOT implementing

- Parallel dispatch stays blocked indefinitely → the current serial pattern means the lease layer adds cost without preventing failures we have
- The shared-path inventory stays at ~5 ledgers + state.jsons → reducer registry is overhead
- The team's tolerance for one merge-time conflict per month is high → the membrane's per-task overhead exceeds the per-incident cost

### 5.3 Open questions still

| Q# | Question | Why it matters |
|---|---|---|
| Q1 | Are conflicts dominantly on append-mostly ledgers or invariant-bearing docs? | Determines whether to ship Primitive 2 (CRDT) or Primitive 1 (action manifests) first |
| Q2 | What's the actual rate of HADF-style collisions across the past 6 months? | If it's ≤2 incidents, the membrane is over-engineering. If it's ≥6, it's underdue. |
| Q3 | Does the user want enforcement (reject commits violating leases) or advisory (annotate but allow)? | Strict enforcement is the v7.5 pattern; advisory is the F1-F9 lesson (don't bite hand that feeds you in early bug-shake-out) |
| Q4 | Where does the membrane's authority live — in the same pre-commit hook, or in a separate orchestrator? | Pre-commit hook = simple but agent-local; orchestrator = systemic but a single point of failure |
| Q5 | What's the recovery path when the lease registry itself gets corrupted? | Membrane that protects everything except itself = bootstrap problem |

---

## 6. If we choose to implement: phased thin-slice path

**Phase 1 (1-2 days, advisory only):**
- Ship `scripts/membrane-status.py` as a read-only smartlog over current state — no enforcement, no schema changes. Just a view.
- Surface in `/control-room/framework` §7 as a static summary.
- Run for 2 weeks. Count how many times "Agent A would have hit B" actually happens.

**Phase 2 (2-3 days, append-only ledger CRDT):**
- Convert `measurement-adoption-history.json`, `documentation-debt.json` to Automerge-backed reads (file-on-disk stays JSON for human inspection; the writer wraps an Automerge document).
- Test: can two simulated agents append concurrently without overwriting each other?
- This is the single highest-value primitive because it directly fixes the Hobby-tier auto-deploy committer race + the HADF write collisions.

**Phase 3 (3-5 days, action manifests + lease enforcement):**
- Add `agent_manifest` to state.json schema.
- Pre-commit hook extension: staged files must be subset of `manifest.writes`.
- Lease acquisition at `/pm-workflow` start.
- Heartbeat daemon.

**Phase 4 (1-2 days, polish):**
- PR-integrity bot renders membrane status into PR descriptions.
- New cycle-time code `ORPHAN_LEASE`.
- Documentation: agent-onboarding guide, reducer authoring guide.

**Total:** 7-12 dev days for the full membrane, fronted by the lowest-risk highest-value piece (Phase 2).

**Off-ramp signal:** if Phase 1's 2-week observation finds ≤1 conflict, halt. Membrane is over-engineering.

---

## 7. Closing observation

The strongest evidence for the membrane is not the HADF incident or the PR #169 fallout — those are recoverable. The strongest evidence is what *almost happened today*: my v1 migration script silently corrupted Unicode em-dashes across 45 files, and the only thing that caught it was the user's mid-session instruction. A membrane with a manifest declaring "this agent writes 45 state.json files" + a per-file diff-size sanity-check (Bazel-style action contract: "expected diff is ≤2 lines per file; 96 lines is a contract violation") would have caught that *mechanically* before the diff ever staged.

So the question is whether the framework wants to extend its v7.5/v7.6/v7.7 trajectory ("write-time gates over post-hoc audit") into the inter-agent coordination layer. The pattern is the same; the surface area is wider. The cost is real but bounded; the failure mode it prevents is precisely the class that has eluded every gate we've shipped so far.

My honest one-line: **build Phase 2 (CRDT for ledgers) when issue #140 closure becomes necessary; build Phase 3 (action manifests) only after F6-F9 unblock parallel dispatch and the empirical conflict rate justifies it.**

---

## §99 — Appendix: research-agent verbatim survey

(Inlined for the v7.8 design-doc to cite without re-running the survey.)

> # Branch-Isolation Membrane for Parallel Agents — Prior Art Survey
>
> **Version Control / Branch Isolation:** Git worktrees + sparse-checkout (already in use; sparse-checkout is a *visibility* filter, not a *write* gate; HADF Phase 2 hit untracked-and-shared-path collisions); Pijul (patches with explicit deps; conflicts as set-union); Sapling smartlog (live tree of in-flight stacks — UX for "who's touching this file"); Jujutsu (op-log per workspace, replayable rollback).
>
> **Concurrent-Edit / Merge Models:** CRDTs Yjs/Automerge (commutative ops with vector clocks; cleanly fits append-mostly ledgers); MRDTs (invariant-preserving CRDTs from MSR India — relevant to state.json invariants); Hypercore/multifeed (per-author log + cross-feed indexer); Operational Transform (server-mediated; dominated by CRDTs for offline-first cases — skip).
>
> **Build/Execution Isolation:** Bazel remote execution (declared inputs/outputs + content-addressed); Nix profiles + overlays (declarative path isolation; macOS overlay-FS support is weaker); Vercel Sandbox / Firecracker (process-level — overkill for cooperative agents — skip).
>
> **Filesystem Sandboxing:** macOS App Sandbox / Linux Landlock (kernel-enforced declarative scopes; declarative-scope-schema is the right contract shape even if cooperative-only enforcement); fsevents/inotify mediator (detect-and-broadcast; OS-portable).
>
> **Multi-Agent Coordination:** LangGraph reducers (`Annotated[list, add]` declares merge semantics — closest direct analog); AutoGen GroupChat (serialization, not parallelism); CrewAI (sequential — skip); Anthropic Agent SDK / OpenAI Assistants (host-mediated tool layer is the natural enforcement point); MRDT literature (invariant-preserving CRDTs — directly addresses the state.json gap).
>
> **Top-3 ranked:** (1) LangGraph-style reducers + Bazel-style action manifests; (2) MRDTs for shared ledgers; (3) Sapling-smartlog awareness + jj op-log recovery.
>
> **Pivotal open question:** Are conflicts dominantly on append-mostly ledgers (CRDT-solvable) or on invariant-bearing documents (need coordinator or invariant-preserving merges)?

---

**Tier tags:** §1 (problem statement) is T1 for the empirical incidents (PR #169 today's session diff stats; HADF Phase 2 docs in memory); T2 for the inferred patterns. §2 (prior art) is T2 — research agent's review, not first-hand verification. §3-§5 (design + tradeoffs + recommendation) is T3 (analysis + judgment), with quantitative claims (5-8 dev-days, ~50ms overhead, etc.) marked T3 as estimates rather than measurements.
