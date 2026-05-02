---
title: Framework v7.8 (Honesty + Auto-Instrumentation) and v7.9 (Inter-Agent Membrane) — Bridge Design
date_written: 2026-05-02
work_type: Feature
dispatch_pattern: serial
predecessor_specs:
  - docs/superpowers/specs/2026-04-27-framework-v7-7-validity-closure-design.md
  - docs/research/2026-05-01-framework-v7-8-branch-isolation-survey.md
input_research_notes:
  - docs/research/2026-05-02-framework-v7-9-implementation-safety-research.md
  - docs/research/2026-05-02-framework-mechanism-c-cache-hits-auto-instrumentation-research.md
predecessor_audit:
  - .claude/projects/-Volumes-DevSSD-FitTracker2/memory/project_framework_gaps_audit_2026_04_30.md
status: draft_for_review
---

# Framework v7.8 + v7.9 — Bridge Design Spec

## 0. One-line summary

**v7.8 closes the v7.7 silent-pass and ships every schema, script, and registry that v7.9 will need to enforce — landing all v7.9 mechanisms in *advisory* mode so the v7.9 transition is mostly an enforcement-flip, not a fresh migration.**

The two phases are specified and connected: every v7.8 mechanism has a named v7.9 successor, every v7.9 enforcement point has a v7.8 schema bridge, and the bridge table in §6 makes the mapping mechanical.

## 1. Genesis & Why Now

Three converging incidents trigger v7.8:

### 1.1 The v7.7 silent-pass (caught 2026-04-30)

The v7.7 case study claimed `cache_hits[]` post-v6 went from `33.3% → gated to 100% on next write (#140 closed)`. The 2026-04-30 audit (memory `project_framework_gaps_audit_2026_04_30.md`) found `CACHE_HITS_EMPTY_POST_V6` cannot fire on **0 of 46 features**:

- 43/46 (93%) use legacy `created` field; gate reads `state.get("created_at", "")` (line 247 of `scripts/check-state-schema.py`) → returns `""` → escapes the post-v6 check → silent pass.
- 2/46 use `created_at`; neither has `current_phase: complete`.
- 1/46 missing both.

Issue #140 is closed in spec, open in practice. Effective gate coverage: **0%**. This is the exact failure mode v7.5 was created to prevent.

### 1.2 The HADF Phase 2 worktree-collision incident (2026-05-01)

The HADF Phase 2 campaign ran an unattended fingerprint-collection job in `/Volumes/DevSSD/FitTracker2-hadf-campaign/` while parallel feature work continued on `main` and feature branches. Observed collisions: `.claude/settings.local.json` drift, `.claude/shared/hadf/*` clobbering, launchd plist working-directory aliasing. Per the existing branch-isolation survey (`docs/research/2026-05-01-framework-v7-8-branch-isolation-survey.md`).

### 1.3 The PR #169 silent-break (2026-05-01)

Today's `created` → `created_at` rename across 43 state.json files broke `scripts/measurement-adoption-report.py` because the consumer read the legacy field. The break was silent: report ran without errors but returned `post-v6: 0` instead of `post-v6: 11`. Caught only by the user's mid-session instruction. Would have shipped to main otherwise.

The pattern: a schema change on a path many consumers read crossed agent-task boundaries that nothing in our framework currently models.

### 1.4 What v7.8 + v7.9 jointly fix

The three incidents share a root: **the framework cannot observe its own runtime.** v7.7 wrote gates that asserted properties about state.json; it never asserted that the gates were actually firing. The HADF + PR #169 incidents show the same gap from another angle: agents writing concurrently to shared paths produce silent collisions that the framework has no surface to detect at write-time.

The bridge from v7.8 to v7.9 is "ship the schemas + scripts + registries needed for runtime self-observation in v7.8 (advisory), then flip enforcement bits in v7.9." This trajectory deliberately mirrors v7.5 → v7.6 (write-time gates, advisory then enforced) at a different layer.

## 2. Scope

### 2.1 In scope for v7.8 (Phase 1, advisory)

| ID | Mechanism | Closes |
|---|---|---|
| A | Coverage-asserting gates: every write-time gate emits `I checked N records of class C` stat; meta-check fails when a gate that should have records found 0 | The v7.7 failure mode itself |
| B | Schema field-rename detection + dual-read parser (`created` ∪ `created_at`); `deprecated_fields` registry | Audit Gap A (`created` vs `created_at` drift) |
| C | `PostToolUse:Read` hook auto-collects cache events to a session-level ledger (no state.json write yet, no pre-commit gate change) | Audit Gap C (cache_hits writer-path) — moves from Class B "agent must remember" to Class A "auto-captured" |
| D | Pre-commit hook header self-audit: hook claims must match implemented gates in `scripts/check-state-schema.py` | Audit Gap D (header documentation drift) |
| E | Custom git merge driver `union-dedup-by-key` for `measurement-adoption-history.json` + `documentation-debt.json` | HADF Phase 2 / PR #169 ledger-collision risk |
| F | Membrane status advisory script (`scripts/membrane-status.py`) — read-only smartlog over `.claude/features/*/state.json` + `agent-leases.json` | Branch-isolation survey Phase 1 (advisory awareness) |
| Bridge | Schema bridge fields (advisory): `agent_manifest`, `_meta.deprecation_warnings[]`, `path-reducers.json` populated with `mode: "advisory"`, `agent-leases.json` populated, every reducer/gate has `mode` field, `fcntl.flock` + `epoch` scaffolding | Foundation that v7.9 flips |

### 2.2 In scope for v7.9 (Phase 2, enforced)

| ID | Mechanism | Builds on |
|---|---|---|
| C′ | `CACHE_HITS_EMPTY_POST_V6` promoted from "key-presence" to "≥N hits where N is calibrated"; new `CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT` gate | v7.8 Mechanism C session ledger |
| G | Action manifests enforced: pre-commit hook subset-checks `staged_paths ⊆ manifest.writes`; lease acquisition required for shared-path writes | v7.8 advisory `agent_manifest` + `agent-leases.json` |
| H | CRDT layer (Automerge) for ledgers — only if a collision is observed during v7.8 | v7.8 merge-driver pattern (drop-in replacement) |
| I | Epoch fencing tokens: every shared-write reducer rejects writes with stale epoch (per Kleppmann Redlock critique) | v7.8 epoch counter scaffolding |
| Reducer flips | Each `mode: "advisory"` reducer with ≥7 days zero false-positives → `mode: "enforced"` | v7.8 advisory ledger (`.claude/logs/reducer-misses.json`) |
| Schema flip | `_meta.deprecation_warnings[]` promoted to `SCHEMA_LEGACY_FIELD` failure code; dual-read removed | v7.8 deprecation envelope |

### 2.3 Out of scope (deferred beyond v7.9)

- **Anthropic Agent SDK migration.** The Mechanism C deep research (`docs/research/2026-05-02-framework-mechanism-c-...`) §5 documents the strictly-better in-process hook surface but quantifies the migration cost as multi-week. Re-evaluate when F6–F9 (concurrent dispatch hygiene) force it independently.
- **MRDTs for state.json.** Single-writer `fcntl.flock` is the correct shape; CRDT-class merging on invariant-bearing documents produces semantically-broken outcomes (`current_phase = ["implementation", "complete"]` from concurrent advances).
- **EndpointSecurity / fs_usage / DTrace OS-level auditing.** Wrong abstraction layer + privilege escalation; documented in the Mechanism C research §3 only for paranoid cross-checking.
- **Server-CPU bucket in HADF schema** (separate Track 2 follow-up).

## 3. Two conceptual surfaces

The 8 audit gaps + the 7 research topics decompose cleanly into two surfaces:

**Surface 1 — Silent-pass prevention.** Mechanisms A, B, C, D. The framework asserts that its gates actually exercise data + that schema renames don't strand consumers. Closes audit gaps A, B, C, D, E.

**Surface 2 — Inter-agent awareness.** Mechanisms E, F (v7.8) + G, H, I (v7.9). The framework observes that agents writing concurrently to shared paths don't silently collide. Closes the HADF Phase 2 + PR #169 incident class.

The two surfaces are independent (you could ship Surface 1 alone), but they share three pieces of infrastructure that v7.8 lands once and both surfaces consume:

1. **Session events ledger** (`.claude/logs/_session-<id>.events.jsonl`) — Mechanism C writes it; Mechanism F reads it.
2. **Mode-flagged registry pattern** (`mode: "advisory" | "enforced"` on every gate / reducer / manifest field) — applies to both surfaces uniformly.
3. **Coverage-asserting gates** (Mechanism A) — proves Surface 1 gates fire AND proves Surface 2 reducers run.

## 4. Phase 1 — v7.8 Mechanisms (advisory, ships now)

### 4.1 Mechanism A — Coverage-asserting gates

**Problem:** v7.7's `CACHE_HITS_EMPTY_POST_V6` ran on every commit but exercised data on 0/46. We never knew.

**Design:** Every write-time gate in `scripts/check-state-schema.py` emits a structured stat to `.claude/logs/gate-coverage.jsonl`:

```json
{"timestamp": "2026-05-02T...", "gate": "CACHE_HITS_EMPTY_POST_V6",
 "checked": 0, "candidates": 0, "skipped": 46, "skip_reasons": {"no_created_at": 43, "not_complete": 3}}
```

A new meta-check `GATE_COVERAGE_ZERO` fires (advisory in v7.8) when `checked == 0` for ≥3 consecutive cycle audits. The weekly cron's framework-status report surfaces low-coverage gates.

**Prior art:** Postgres `pg_stat_statements` (per-statement execution count); Bazel build event protocol (every action emits structured events automatically). See research note `2026-05-02-framework-v7-9-implementation-safety-research.md` Part 1, Risk 1.

**v7.8 → v7.9:** v7.9 promotes the meta-check to enforced once every gate has emitted ≥7 days of stats. Same script, same JSONL ledger, one config flip.

### 4.2 Mechanism B — Schema field-rename detection + dual-read

**Problem:** Audit Gap A. The `created` → `created_at` rename in PR #169 stranded 43 state.json files (the gate reads `created_at`, files have `created`).

**Design:**

1. **Dual-read parser.** `scripts/check-state-schema.py` reads `state.get("created_at") or state.get("created", "")` for the next 90 days, then drops the fallback in v7.9. Pattern from Kubernetes CRD versioning (storage version != API version).
2. **`deprecated_fields` registry.** New file `.claude/shared/deprecated-fields.json`:
   ```json
   {"version": "1.0", "fields": [
     {"path": "state.created", "deprecated_in": "v7.7", "removed_in": "v7.9",
      "replaced_by": "state.created_at", "last_seen_count": 43}]}
   ```
3. **Migration script.** `scripts/migrate-state-vN-vM.py` is idempotent (Postgres `ALTER EXTENSION` pattern); running twice is a no-op. v7.8 ships `migrate-state-v7-7-to-v7-8.py` covering the `created` → `created_at` sweep.
4. **In-band deprecation envelope.** State.json gets `_meta.deprecation_warnings: []` populated by the schema-checker on read (OpenAPI Sunset / RFC 8594 pattern). Empty in v7.8, populated in v7.9.

**Prior art:** Postgres `ALTER EXTENSION ... UPDATE`, Kubernetes CRD versioning + conversion webhooks, Pydantic v1→v2 `bump-pydantic`, Protobuf reserved fields. See research note `2026-05-02-framework-v7-9-implementation-safety-research.md` Part 2.

**v7.8 → v7.9:** v7.9 drops the dual-read fallback; the deprecation envelope's contents become a `SCHEMA_LEGACY_FIELD` failure code on read. The migration script is the same script, just rerun.

### 4.3 Mechanism C — PostToolUse hook for cache_hits (advisory)

**Problem:** Audit Gap C. The `cache_hits[]` writer-path is the unclosable Class B gap because the agent must remember to call `scripts/log-cache-hit.py`. Effective adoption: 5/11 post-v6 features have any cache_hits entries.

**Design** (per Mechanism C research note §8):

1. **Add `PostToolUse:Read` hook** to `.claude/settings.json` (committed; project-level):
   ```json
   {
     "PostToolUse": [{
       "matcher": "Read",
       "hooks": [{"type": "command",
                  "command": "python3 scripts/observe-cache-hit.py"}]
     }]
   }
   ```
2. **New script `scripts/observe-cache-hit.py`** (~120 lines):
   - Reads tool-payload JSON from stdin (per Claude Code hook contract: `tool_input.file_path`, `session_id`, `cwd`).
   - Resolves active feature from `$FT2_ACTIVE_FEATURE` env var; falls back to `.claude/active-feature` lockfile.
   - Appends every Read to `.claude/logs/_session-<session_id>.events.jsonl` (line-delimited, append-only).
   - **v7.8 only writes the session ledger.** Does NOT write to `state.json::cache_hits[]`. Does NOT change the existing `CACHE_HITS_EMPTY_POST_V6` gate.
3. **Update `SessionStart` hook** to read `.claude/active-feature` and export `FT2_ACTIVE_FEATURE` for the session.
4. **Update `/pm-workflow` slash command** to write `.claude/active-feature` on entry.
5. **Schema bug fix on `CACHE_HITS_EMPTY_POST_V6`** ships in the same v7.8 commit (read both `created` ∪ `created_at`). The fix lands but the gate remains effectively un-firing because no post-v6 feature has reached `complete` yet — that's the bridge point for v7.9.
6. **New advisory cycle-time check `CACHE_HITS_AUTO_INSTRUMENTATION_INACTIVE`** fires when a feature's session events show Read events but `state.json::cache_hits[]` is empty for the period. Advisory only — early warning that the hook isn't firing.

**Hit definition for v7.8** (per Mechanism C research §7): "Read of a path already read this session." Mechanically computable from the session ledger; matches ccache's "preprocessed source SHA matches" pattern. No agent attention required.

**Prior art:** Claude Code 27-event hook system, real-world deployments at `disler/claude-code-hooks-multi-agent-observability` (5.4k★) + `TechNickAI/claude_telemetry`. W3C Baggage / Sentry Scope / Datadog UST attribution patterns. See research note `2026-05-02-framework-mechanism-c-...` §1, §6.

**v7.8 → v7.9:** v7.9 promotes `observe-cache-hit.py` to also call the existing `scripts/log-cache-hit.py` — the dual-write contract activates. The `CACHE_HITS_EMPTY_POST_V6` gate is promoted from "key-presence" to "≥N hits where N is calibrated from the v7.8 measurement window." A new `CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT` gate compares `state.json` count vs session-Read count and fails if state.json count < 50%.

**Why this is the bridge piece worth the most attention:** Mechanism C is the Class B → Class A transition for the gap that broke v7.7. Getting the v7.8 advisory shape right means v7.9 ships with calibrated thresholds rather than guesses.

### 4.4 Mechanism D — Pre-commit hook header self-audit

**Problem:** Audit Gap D. The `.githooks/pre-commit` header lists v7.5 + v7.6 gates only; the 4 v7.7 gates are wired functionally via `state_schema_checker --staged` but undeclared in the header.

**Design:** New `make pre-commit-self-test` target + a pre-commit step that asserts every gate the hook *claims* to enforce is implemented in `scripts/check-state-schema.py`. Test fails on header drift.

```python
# scripts/pre-commit-self-test.py
DECLARED_GATES = parse_hook_header(".githooks/pre-commit")
IMPLEMENTED_GATES = parse_check_codes("scripts/check-state-schema.py")
assert DECLARED_GATES == IMPLEMENTED_GATES, f"Header drift: {DECLARED_GATES ^ IMPLEMENTED_GATES}"
```

**Prior art:** gitleaks self-test, pre-commit.com `repo-rev` validation. Trivial to ship.

**v7.8 → v7.9:** No change. Self-test stays the same.

### 4.5 Mechanism E — Custom git merge driver for ledgers

**Problem:** `measurement-adoption-history.json` and `documentation-debt.json` accumulate dated snapshots. Concurrent appends from different worktrees / branches produce git conflict markers; resolving by hand is the current process and was the source of HADF Phase 2 worktree-collision risk.

**Design** (per v7.9-safety research Part 4):

1. **`scripts/merge-driver-dedup.py`** (~80 lines): loads `%O %A %B`, computes union of `snapshots` / `entries` arrays, dedups by configured key (`date` for adoption-history, `id` for debt entries), sorts by timestamp, writes to `%A`.
2. **`.gitattributes` registers the driver:**
   ```
   .claude/shared/measurement-adoption-history.json merge=union-dedup-by-key
   .claude/shared/documentation-debt.json merge=union-dedup-by-key
   ```
3. **Per-repo setup script** `scripts/install-merge-drivers.sh` runs `git config merge.union-dedup-by-key.driver "scripts/merge-driver-dedup.py %O %A %B %P"`. Documented in `make install-hooks`.

**Why not Automerge / CRDT?** Per Mechanism C research note Part 4: for files with natural deduplication keys (date-based snapshots, ID-based entries), git's 3-way merge with a custom driver is sufficient and adds zero new dependencies. Automerge is held in reserve for v7.9 if a collision is observed in v7.8's measurement window.

**v7.8 → v7.9:** No change required. Merge driver is structurally correct on day one. CRDT (Automerge) becomes Mechanism H if needed.

### 4.6 Mechanism F — Membrane status advisory

**Problem:** Branch-isolation survey Phase 1: agents have no awareness of each other's in-flight work until PR-merge time.

**Design:**

1. **`scripts/membrane-status.py`** (~100 lines): reads `.claude/features/*/state.json` (current phase, last-touched mtime), `.claude/shared/agent-leases.json` (declared writes, last heartbeat), and `git for-each-ref refs/heads/` (open branches with feature prefix). Renders a smartlog table.
2. **No enforcement.** Read-only. v7.8 ships the script + a UCC dashboard panel reading the same data; that's it.
3. **`agent-leases.json` populated** with whichever features have an open `state.json` — but no lease acquisition is invoked by `/pm-workflow` yet.

**Prior art:** Sapling smartlog (Meta), Jujutsu op-log, branch-isolation survey §6 Phase 1.

**v7.8 → v7.9:** v7.9 wires `/pm-workflow` to call `scripts/membrane-acquire.py` at session start; the lease registry becomes write-active. Same data shape, same UI.

### 4.7 Schema bridge fields (advisory in v7.8)

These ship in v7.8 in their final shape, populated by their owning mechanisms, but **no enforcement gate consumes them yet.** v7.9 flips enforcement on.

#### 4.7.1 `state.json::agent_manifest`

```json
{
  "feature_name": "...",
  "current_phase": "implementation",
  "agent_manifest": {
    "reads": [".claude/shared/skill-routing.json", ".claude/shared/measurement-adoption.json"],
    "writes": [".claude/features/<self>/state.json", ".claude/logs/<self>.log.json"],
    "shared_writes": [
      {"path": ".claude/shared/measurement-adoption-history.json",
       "merge_strategy": "append_dedup", "reducer": "snapshot_dedup_by_date"}
    ]
  },
  "_meta": {"deprecation_warnings": []}
}
```

Populated by `/pm-workflow {feature}` on entry. Pre-commit hook does **not** validate staged paths against `manifest.writes` in v7.8.

#### 4.7.2 `.claude/shared/path-reducers.json`

```json
{
  "version": "1.0",
  "paths": {
    ".claude/shared/measurement-adoption-history.json": {
      "merge_strategy": "append_dedup",
      "dedup_key": "date",
      "mode": "advisory"
    },
    ".claude/shared/skill-routing.json": {
      "merge_strategy": "exclusive_write",
      "owner_features": ["framework-v*"],
      "mode": "advisory"
    }
  }
}
```

Pre-commit hook runs reducers in advisory mode (logs misses to `.claude/logs/reducer-misses.json`); does not block the commit.

#### 4.7.3 `.claude/shared/agent-leases.json`

```json
{
  "version": "1.0",
  "epoch": 17,
  "leases": [
    {"agent": "auth-polish-v2", "branch": "feature/auth-polish-v2",
     "worktree": "/Volumes/DevSSD/FitTracker2", "started_at": "...",
     "last_heartbeat": "...", "epoch": 17, "writes": ["..."]}
  ]
}
```

`epoch` increments on every acquire. `fcntl.flock` byte-range locks protect concurrent writers. Lease scripts present (`scripts/membrane-acquire.py`, `scripts/membrane-release.py`) but **not invoked from pre-commit**.

#### 4.7.4 Mode-flagged gates + reducers

Every gate in `scripts/check-state-schema.py` carries a `mode` constant; every reducer in `path-reducers.json` carries a `mode` field. Default in v7.8: `advisory`. v7.7's existing 4 gates flip to `enforced` immediately (they were always enforced; the field is documentation). New gates ship `advisory`.

**v7.8 → v7.9:** v7.9 sweeps the advisory gates and flips to `enforced` based on the `.claude/logs/reducer-misses.json` ledger: any reducer with ≥7 days zero false-positives → `enforced`. Pattern from Postgres `ALTER TABLE ... NOT VALID` → `VALIDATE CONSTRAINT`.

## 5. Phase 2 — v7.9 Mechanisms (enforcement, builds on v7.8)

v7.9 is the ratification step. Most of the work is config flips and gate promotions; only Mechanisms G and I require new code.

### 5.1 Mechanism G — Action manifests + lease enforcement

**Becomes enforced:** Pre-commit hook adds a step that validates `staged_paths ⊆ agent_manifest.writes`. Lease acquisition becomes mandatory on `/pm-workflow` start. `scripts/membrane-acquire.py` rejects with a structured envelope:

```json
{"code": "LEASE_CONFLICT_PATH",
 "holder": {"feature": "...", "branch": "...", "started_at": "...", "last_heartbeat_age_s": 90},
 "suggestion": "wait | take-over <cmd> | coordinate <url>"}
```

(Pattern: Rust compiler `--error-format=json`, Kubernetes `metav1.Status`. Per v7.9-safety research Part 1 Risk 4.)

### 5.2 Mechanism H — CRDT for ledgers (only if needed)

**Conditional ship:** if v7.8's measurement window observes ≥1 ledger collision (concurrent appends within the same second producing genuine conflicts the merge driver couldn't resolve), upgrade `measurement-adoption-history.json` to Automerge with a JSON-snapshot mirror. Use `automerge-py`. Per Mechanism C research Part 4.

If v7.8 observes zero collisions: do not ship H; Mechanism E is sufficient.

### 5.3 Mechanism I — Epoch fencing tokens

Every shared-write reducer validates `write.epoch >= leases.epoch` and rejects writes with stale epoch. Per Kleppmann Redlock critique. The scaffolding (`epoch` field in `agent-leases.json` + every shared write recording its epoch) ships in v7.8; v7.9 adds the validation.

### 5.4 Schema enforcement flips

| v7.8 (advisory) | v7.9 (enforced) | Mechanism |
|---|---|---|
| Dual-read `created` ∪ `created_at` | Drop `created` fallback; emit `SCHEMA_LEGACY_FIELD` | B |
| `_meta.deprecation_warnings: []` populated, ignored | Promoted to failure code on read | B |
| `mode: "advisory"` reducers run, log misses | Reducers with ≥7d zero-FP → `enforced` | E + Bridge |
| `path-reducers.json` populated, no pre-commit reject | Pre-commit rejects unregistered shared-path writes | G |
| `agent-leases.json` populated, no acquire required | Lease acquire mandatory | G |
| `epoch` counter tracked | Epoch validated by every reducer | I |
| `CACHE_HITS_EMPTY_POST_V6` gate fires on `current_phase=complete && empty` | Promoted to "≥N hits where N calibrated"; new `CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT` gate added | C′ |
| `GATE_COVERAGE_ZERO` advisory | Promoted to enforced once every gate has ≥7d coverage stats | A |

## 6. The bridge — explicit map

This is the section that makes "specified and connected" concrete. **Every v7.8 ship has a named v7.9 successor; every v7.9 enforcement has a named v7.8 prerequisite.**

| v7.8 ships (advisory) | v7.9 flips (enforced) | Code change at the flip |
|---|---|---|
| `state.json::agent_manifest` schema | Pre-commit `staged_paths ⊆ manifest.writes` check | Add 30-line check in `scripts/check-state-schema.py` |
| `.claude/shared/path-reducers.json` w/ `mode:"advisory"` | Reducers with ≥7d zero-FP → `mode:"enforced"`; pre-commit rejects on violation | Single sweep script + config flip |
| `.claude/shared/agent-leases.json` schema + scripts | `/pm-workflow` calls `membrane-acquire.py`; lease conflict rejects | One line in `/pm-workflow`, no schema change |
| `_meta.deprecation_warnings: []` envelope | Becomes `SCHEMA_LEGACY_FIELD` failure | Promote one-line check from warning to error |
| `epoch` counter in `agent-leases.json` | Reducers validate `write.epoch >= leases.epoch` | Add validation per reducer |
| `fcntl.flock` on state.json writes | Same — already enforced at v7.8 ship | (no change) |
| Dual-read parser `created` ∪ `created_at` | Drop fallback | One line removed in schema-checker |
| `mode: "advisory"` field on every gate | Sweep to `enforced` based on coverage stats | Config flip |
| Session events ledger `.claude/logs/_session-<id>.events.jsonl` (Mechanism C, no state.json write) | `observe-cache-hit.py` also calls `log-cache-hit.py` (state.json write activates) | One function call added |
| Hit definition B (path-already-read-this-session) | Hit definition C(b) (cross-session read history) | Replace ledger consultation logic |
| `GATE_COVERAGE_ZERO` advisory cycle-time check | Promoted to enforced | Config flip |
| `CACHE_HITS_AUTO_INSTRUMENTATION_INACTIVE` advisory | Promoted to `CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT` enforced | Threshold change |
| `CACHE_HITS_EMPTY_POST_V6` (v7.7 gate, schema-bug-fixed in v7.8) | Promoted from "key-presence" to "≥N calibrated" | Threshold change |
| Custom git merge driver for ledgers | (no change — structurally correct on day one) | (no change) |
| `membrane-status.py` advisory smartlog | Same script, becomes input to lease-acquire decisions | (no change) |
| `pre-commit-self-test` (header self-audit) | (no change) | (no change) |

**Total v7.9 work after v7.8 ships:** ~150 lines of new code (Mechanism I epoch validation), ~50 lines of config flips, ~5 days of measurement window observation before flipping reducer modes. The vast majority of v7.9 is the *measurement window* itself, not the engineering.

This is the bridge: v7.8 is a complete schema migration disguised as an advisory shipment. v7.9 is mostly a config change.

## 7. Implementation plan

### 7.1 v7.8 milestones

| M | PR | Tasks | Closes | Gated by |
|---|---|---|---|---|
| M0 | commit-only | T0 — Feature stub at `.claude/features/framework-v7-8/state.json` (work_type: Feature; framework_version: v7.8; cache_hits[] populated) | Kickoff | manual |
| M1 | PR-1 | T1 schema bug fix (created ∪ created_at); T2 `migrate-state-v7-7-to-v7-8.py` sweep; T3 v7.7 case study correction append (per `feedback_publish_verbatim_then_remediate.md`) | Audit Gap A; trust recovery | new pre-commit + bulk-edit PR |
| M1 | PR-2 | T4 Mechanism A (coverage-asserting gates); T5 `gate-coverage.jsonl` ledger; T6 `GATE_COVERAGE_ZERO` advisory check | The v7.7 silent-pass meta-fix | new code |
| M2 | PR-3 | T7 `scripts/observe-cache-hit.py`; T8 `PostToolUse:Read` hook in `.claude/settings.json`; T9 `SessionStart` hook update (FT2_ACTIVE_FEATURE export); T10 `/pm-workflow` writes `.claude/active-feature`; T11 `CACHE_HITS_AUTO_INSTRUMENTATION_INACTIVE` advisory | Audit Gap C — Mechanism C advisory | new code + hook config |
| M2 | PR-4 | T12 `scripts/merge-driver-dedup.py`; T13 `.gitattributes` registration; T14 `make install-hooks` extension | HADF / PR #169 ledger collision risk — Mechanism E | new code + git config |
| M3 | PR-5 | T15 schema bridge fields (`agent_manifest`, `_meta.deprecation_warnings`, `path-reducers.json`, `agent-leases.json`, `mode` flag); T16 `migrate-state-v7-8-bridge.py` populates advisory fields across 46 features; T17 `fcntl.flock` + `epoch` scaffolding in `log-cache-hit.py` + `append-feature-log.py` | Schema bridges (advisory) | code + bulk migration |
| M3 | PR-6 | T18 `scripts/membrane-status.py`; T19 UCC dashboard panel; T20 Mechanism D pre-commit-self-test; T21 `.githooks/pre-commit` header rewrite | Mechanism F + Audit Gap D | code + dashboard |
| M4 | PR-7 | T22 v7.8 case study `docs/case-studies/framework-v7-8-case-study.md` (live append-only journal + final synthesis); T23 cold-start entrypoint `.claude/entrypoints/framework-v7-8.md`; T24 fitme-story showcase MDX; T25 framework-honesty-ledger entry FT2-FH-001 | Trust recovery + dual-surface case study | docs only |

**v7.8 estimated size:** ~7 PRs, ~10-15 dev-days. Schema bridges (M3 PR-5) are the largest piece because they touch all 46 features.

### 7.2 v7.9 plan-of-plan

Drafted at v7.8 ship; not committed-to here. Anchor points:

- **+7 days post-v7.8:** first measurement-window snapshot. `.claude/logs/reducer-misses.json` shows zero false-positives on which reducers? `.claude/logs/gate-coverage.jsonl` shows which gates are firing? `.claude/logs/_session-*.events.jsonl` shows cache_hits attribution accuracy?
- **+14 days post-v7.8:** decision points. Flip reducer modes for zero-FP entries. Calibrate v7.9 cache_hits threshold N from observed data.
- **+21 days post-v7.8:** v7.9 design lock — names which gates flip when, decides Mechanism H (CRDT) ship/no-ship based on observed collision count.
- **+28 days post-v7.8:** v7.9 ships.

Alternative if v7.8 surfaces unanticipated FP rates: v7.9 holds; v7.8 patches reducers; re-measure.

## 8. Migration

### 8.1 `created` → `created_at` sweep

`scripts/migrate-state-v7-7-to-v7-8.py` walks all 46 `state.json` files, copies `created` → `created_at` (idempotent: skips if `created_at` already present), keeps `created` for the dual-read window. PR-1 lands the migration + the dual-read parser in the same commit. v7.9 PR drops `created` from all 46 files.

### 8.2 `framework_version` format normalization (Audit Gap B)

`scripts/migrate-state-framework-version.py` walks all 46 state.json:
- Missing field (39/46) → backfill from `git log --oneline` of the feature's first commit, mapped to a framework version table.
- Unprefixed (6/46: `"6.0"`, `"7.6"`, etc.) → prefix with `v` to canonical `"v6.0"`, `"v7.6"`.
- Already canonical (1/46: auth-polish-v2) → no change.

Script is idempotent. Lands in PR-1.

### 8.3 v7.7 case study correction (per "publish verbatim, append corrections" feedback)

The v7.7 case study (`docs/case-studies/framework-v7-7-validity-closure-case-study.md`) does **not** silently edit the "100% gated" claim. Instead, append a new `## §10 — 2026-05-02 correction` section citing v7.8 §1 + the framework-honesty-ledger entry FT2-FH-001. Original record stays; corrections accrete. Pattern from curl monthly reports + Postgres release notes "broken in N.M, fixed in N.M+1". Per v7.9-safety research Part 5.

### 8.4 Schema bridge field backfill

`scripts/migrate-state-v7-8-bridge.py` populates the new advisory fields on all 46 features:
- `agent_manifest: {reads: [], writes: [], shared_writes: []}` — empty arrays initially; agents populate during their next phase transition.
- `_meta: {deprecation_warnings: []}` — empty.

Idempotent. Ships in PR-5.

## 9. Validation criteria

How do we know v7.8 worked?

| Criterion | Tier | Target | Window |
|---|---|---|---|
| `CACHE_HITS_EMPTY_POST_V6` schema bug fixed (gate can fire) | T1 | Gate fires on at least 1 future feature with `current_phase=complete && cache_hits=[]` | 30 days post-ship |
| Mechanism C session ledger captures Read events | T1 | ≥80% of Read tool calls in any 7-day window land in `.claude/logs/_session-*.events.jsonl` | 7 days post-ship |
| `framework_version` field 100% canonical `vX.Y` format | T1 | 46/46 features pass `FRAMEWORK_VERSION_FORMAT` regex | At v7.8 ship |
| `state.json::agent_manifest` populated on all 46 | T1 | 46/46 have the bridge field present (empty arrays OK) | At v7.8 ship |
| Mechanism E merge driver activates | T2 | ≥1 successful auto-merge of `measurement-adoption-history.json` from concurrent worktrees | 30 days post-ship |
| Mechanism F membrane status surfaces in UCC | T2 | `/control-room/framework` §7 shows live leases + last-heartbeat age | At v7.8 ship |
| Tier 1.1 (post-v6 fully-adopted features) trend | T1 | ≥5 features (vs 3 today) | 30 days post-ship |
| 0 PR-merge-time silent-breaks of consumers from schema migrations | T1 | ledger consumers (`measurement-adoption-report.py`, dashboard) report no breaks | 30 days post-ship |
| v7.8 case study published + showcased | T2 | both `docs/case-studies/...` + `fitme-story/.../*.mdx` present | At v7.8 ship |
| Framework-honesty-ledger entry FT2-FH-001 minted | T2 | `docs/case-studies/framework-honesty-ledger.md` exists | At v7.8 ship |

How do we know v7.9 is safe to ship?

- Every advisory reducer has ≥7 days of zero false-positives in `.claude/logs/reducer-misses.json`.
- The cache_hits threshold N has been calibrated from ≥7 days of session-ledger data.
- Mechanism H (CRDT) ship/no-ship decision based on observed collision count.

## 10. Anti-patterns from v7.7 (avoided)

From the audit memo + the failure pattern v7.7 demonstrated:

- ❌ **Don't claim "100% gated" without verifying the gate can fire.** v7.8 ships Mechanism A (coverage-asserting gates) so this is structurally prevented.
- ❌ **Don't add a gate that depends on a field most features don't use.** v7.8 ships Mechanism B (dual-read + deprecation envelope) so the `created`/`created_at`-class drift has a detection surface.
- ❌ **Don't write a case study before measuring the post-implementation state.** v7.8 case study includes a "what we measured 7 days post-ship" section, not just claims.
- ❌ **Don't bundle "schema migration" with "new gate" in the same PR.** PR-1 (schema fix + dual-read) and PR-2 (Mechanism A) ship as separate PRs even though they're related; the migration is its own ratification step.
- ❌ **Don't ship a Mechanism whose effective coverage is unmeasured.** v7.8 ships every mechanism with a `mode: "advisory"` flag and a misses ledger; v7.9 only flips after measurement.

## 11. Risk register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| `PostToolUse:Read` hook adds latency to every Read | Medium | Medium | Hook is fail-soft; performance-monitor in `.claude/logs/gate-coverage.jsonl`; off-switch via env var `FT2_DISABLE_HOOKS=1` |
| Session-ledger attribution wrong (cross-feature contamination) | Medium | Low | Two-layer attribution (env var primary + ledger reconciler); `ATTRIBUTION_AMBIGUOUS` advisory finding |
| Merge driver loses entries during git rebase | Low | High | Idempotency tests; `make merge-driver-test` in CI; git-blame-preserving union |
| `agent_manifest` schema migration corrupts state.json | Low | High | Migration script idempotent + dry-run mode; backup all 46 files before sweep; pattern from `created` → `created_at` failure |
| v7.9 enforcement flip surfaces unanticipated FPs | Medium | Low | Advisory window (7d zero-FP threshold); per-reducer rollback flag; v7.9 ratification step is reversible |
| `fcntl.flock` semantics differ across NFS / external SSD | Low | Medium | Document SSD-only requirement; refuse to operate on NFS-mounted state.json (`fstatfs(2)` check) |
| Mechanism C captures Reads but session-id isn't unique across worktrees | Low | Medium | Use `session_id ∥ worktree_path` as composite key |
| Trust recovery fails (audience reads "we got it wrong" as evidence we can't be trusted) | Low | High | Pattern from curl + Postgres + Tailscale: continuing to publish corrections IS the trust signal. Frame as "we caught our own bug, here's how" |

## 12. Out-of-scope (deferred)

- Anthropic Agent SDK migration (multi-week; defer until F6–F9 force it independently).
- MRDTs for state.json (single-writer + flock is correct shape).
- OS-level file auditing (privilege escalation; wrong abstraction layer).
- Tier 2 HADF chip profiles (separate Track 2 follow-up).
- HSTable schema extension (precision_class, bandwidth_probe_ratio, container_vs_bare_metal_variance) — gated on Phase 2-bis empirical validation.
- v7.9 implementation (this doc only specifies it; PR-by-PR plan drafts at +21 days post-v7.8).

## §99 Appendix — research notes

This design draws on two research notes saved in `docs/research/`:

1. **`2026-05-02-framework-v7-9-implementation-safety-research.md`** (~3,250 words) — broad survey covering 5 risks of full v7.9 enforcement (bureaucracy, registry rot, false positives, opacity, bootstrap), schema-evolution patterns (Postgres, K8s CRD, Protobuf, Pydantic, OpenAPI), lease/heartbeat patterns (`fcntl.flock` + epoch fencing tokens), append-only ledger CRDTs (custom git merge driver as primary, Automerge in reserve), and trust recovery techniques (curl, Postgres, Tailscale, Sentry, CVE process).

2. **`2026-05-02-framework-mechanism-c-cache-hits-auto-instrumentation-research.md`** (~3,800 words) — deep dive on Mechanism C across 7 surfaces (Claude Code hooks, Python sys.audit, OS-level auditing, OpenTelemetry auto-instrumentation, other agent-framework patterns, attribution, hit semantics) with specific real-world deployment references (`disler/claude-code-hooks-multi-agent-observability`, `TechNickAI/claude_telemetry`).

Both notes tier-tag every quantitative claim (T1 instrumented / T2 declared / T3 narrative). Both end with explicit recommendations that this design doc adopts.

The branch-isolation survey (`docs/research/2026-05-01-framework-v7-8-branch-isolation-survey.md`) is the predecessor on Surface 2; its phased recommendation (advisory → CRDT → action manifests) maps to v7.8 Mechanisms F + E and v7.9 Mechanism G.
