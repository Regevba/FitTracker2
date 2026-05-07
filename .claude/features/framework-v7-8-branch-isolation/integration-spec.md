# Integration Spec — framework-v7-8-branch-isolation

> **Phase 3 (Integration) deliverable.** `has_ui: false` → no UX spec; this is the technical contract layer.
> **Companion to:** [`prd.md`](prd.md) §3-§7 (schema + gates + skills) and [`tasks.md`](tasks.md) (Block A-H decomposition).
> **Authored:** 2026-05-07.
>
> **Purpose:** define exact integration points where this feature plugs into the existing v7.8 framework, the API contracts for skill extensions, the backward-compatibility guarantees for existing gates, error-handling protocols, and the advisory → enforced migration plan.

---

## 1. Pre-commit hook integration order

### 1.1 Current state (v7.8 baseline, 4 layers)

[`.githooks/pre-commit`](../../../.githooks/pre-commit) at `main` HEAD `96c9069` runs in this order:

```bash
set -euo pipefail
repo_root="$(git rev-parse --show-toplevel)"

# Layer 1: state.json schema + transition gates (12 write-time codes)
"$repo_root/scripts/check-state-schema.py" --staged

# Layer 2: case-study preflight (3 write-time codes)
"$repo_root/scripts/check-case-study-preflight.py" --staged

# (Failure: print summary, exit 1)
```

12 + 3 = 15 write-time gate codes total at v7.8 baseline.

### 1.2 Post-this-feature state (v7.8 advisory → v7.9 enforced)

The hook gains 2 NEW logical gate IDs **inside the existing 2 scripts** (no new top-level scripts; reduces hook orchestration overhead per PRD §5):

```bash
set -euo pipefail
repo_root="$(git rev-parse --show-toplevel)"

# Layer 1 (extended): state.json schema + transition + branch-isolation
# Codes: SCHEMA_DRIFT, SCHEMA_DRIFT_LEGACY_CREATED, NO_PHASE, INVALID_JSON,
#        PR_NUMBER_UNRESOLVED, PHASE_TRANSITION_NO_LOG, PHASE_TRANSITION_NO_TIMING,
#        CACHE_HITS_EMPTY_POST_V6, CU_V2_INVALID, STATE_NO_CASE_STUDY_LINK,
#        FRAMEWORK_VERSION_FORMAT,
#   NEW: BRANCH_ISOLATION_VIOLATION,
#   NEW: FEATURE_CLOSURE_COMPLETENESS    (closure-time half: 7-field check + Q7)
"$repo_root/scripts/check-state-schema.py" --staged

# Layer 2 (extended): case-study preflight + closure parity
# Codes: BROKEN_PR_CITATION, CASE_STUDY_MISSING_TIER_TAGS, CASE_STUDY_MISSING_FIELDS,
#   NEW: FEATURE_CLOSURE_COMPLETENESS    (case-study half: bidirectional PR parity)
"$repo_root/scripts/check-case-study-preflight.py" --staged

# (Failure: print aggregated summary, exit 1)
```

12 → **14 write-time codes** in `check-state-schema.py`. 3 → **4 codes** (counting `FEATURE_CLOSURE_COMPLETENESS` as one shared code with two sides) in `check-case-study-preflight.py`. **Total: 18 logical write-time codes** (was 15). **Cycle-time: 13 → 16** (adds `BRANCH_ISOLATION_HISTORICAL`, `BRANCH_ISOLATION_LAUNCHD_DRIFT`, `FEATURE_CLOSURE_COMPLETENESS` mirror).

### 1.3 Single hook header self-audit (Mechanism D)

The hook header docstring (the leading `#` comment block in `.githooks/pre-commit`) lists every gate code the hook runs. `make pre-commit-self-test` (per [`scripts/pre-commit-self-test.py`](../../../scripts/pre-commit-self-test.py)) parses the header, scans the actual implementations of `check-state-schema.py` + `check-case-study-preflight.py`, and asserts every code claimed in the header is implemented.

When this feature ships, the hook header gains 2 new code references; `pre-commit-self-test.py` MUST pass before the feature merges. Mechanism D is the safety net against documentation drift.

### 1.4 Order invariant

The 4 layers MUST run sequentially (not parallel). Reason: layer 1 mutates nothing; it reads + emits. Layer 2 reads the same staged files. Race conditions on shared coverage ledger writes (Mechanism A) are avoided by the layers running in series within a single hook invocation.

---

## 2. Skill API contracts

### 2.1 `superpowers:using-git-worktrees` extension (T20)

**New invocation form:**

```bash
superpowers:using-git-worktrees \
  --feature {feature-slug} \
  --create-if-missing \
  [--worktree-name-override {custom-name}]
```

**Contract:**

| Behavior | Spec |
|----------|------|
| Pre-condition | `feature-slug` matches an entry in `.claude/features/` AND that feature's `state.json::branch` is set |
| Naming convention | If `state.json::work_subtype == "framework_feature"` OR `state.json::work_type == "chore"`: prefix `FitTracker2-infra-{shortname}` (shortname = feature slug shortened heuristically). Else: prefix `FitTracker2-{feature-slug}`. Override via `--worktree-name-override`. |
| Pre-existing worktree | If `state.json::worktree_path` already populated AND that path exists: skill exits `0` with `already_exists` reason. Idempotent. |
| Worktree creation | `git worktree add {expected_path} -b {expected_branch}` from `state.json::branch_base` (defaults to `main` HEAD). |
| State updates | Updates `state.json::worktree_path = {expected_path}`. Atomic write via `flock_writer.py`. |
| Lease registration | Appends entry to `.claude/shared/agent-leases.json` with `{feature, worktree_path, leased_paths: [], started_at: now, last_heartbeat: now}`. |
| Output | Prints created worktree path on stdout. Exit `0` on success or `already_exists`; `1` on actual failure. |
| Loop guard | Reads `state.json::auto_isolation_attempted` flag. If `true`, refuses to re-create + asks user (prevents infinite loops where gate fires inside an already-created worktree). Resets to `false` on successful creation. |

**Error modes:**

| Error | Behavior |
|-------|----------|
| Feature slug not found | Exit `2` with stderr `feature-not-found: {slug}` |
| `state.json::branch` not set | Exit `3` with stderr `feature-has-no-branch: {slug}` |
| Worktree path exists but doesn't match expected | Exit `4` with stderr `worktree-mismatch: expected={expected_path} found={existing_path}` |
| Disk full / git error | Exit `5` with stderr `git-error: {message}` |

**Integration point with `BRANCH_ISOLATION_VIOLATION` gate (T9):**

The gate, when it fires, dispatches the skill via subprocess:

```python
# In scripts/check-state-schema.py, gate violation path:
import subprocess
result = subprocess.run([
    "claude-cli-or-direct-bash",  # placeholder — actual mechanism TBD in T9 implementation
    "superpowers:using-git-worktrees",
    "--feature", feature_slug,
    "--create-if-missing",
], capture_output=True, text=True, timeout=30)

if result.returncode == 0:
    # Worktree created. Print user-facing message + exit 1 (block this commit).
    print_isolation_violation_with_worktree_created(result.stdout)
    sys.exit(1)
elif result.returncode == 2:  # already_exists
    # Just block this commit; user is in wrong worktree.
    print_isolation_violation_in_wrong_worktree()
    sys.exit(1)
else:
    # Skill error; surface raw to user, block commit, do NOT loop.
    print(f"Auto-isolation failed: {result.stderr}", file=sys.stderr)
    sys.exit(1)
```

**Contract for T9 implementer:** the dispatch mechanism (subprocess vs hub-mediated vs other) is left to T9 design. The contract on the skill side is fixed by this section.

### 2.2 `/ux pre-merge-review` and `/design pre-merge-review` extension (T21)

**New sub-step at end of skill invocation (sub-step 6f):**

```
6f. kill_criteria_resolution check
    INPUT: feature state.json + case-study path
    LOGIC:
        case_study = parse_frontmatter(case_study_path)
        if not case_study.get("kill_criteria"):
            return PASS  # no kill criteria, skip
        resolution = case_study.get("kill_criteria_resolution")
        if not resolution:
            return BLOCK with reason "kill_criteria set but kill_criteria_resolution is empty"
        # Heuristic substantive check
        substantive = (
            mentions_at_least_one_kill_threshold(resolution, case_study["kill_criteria"]) or
            contains_keyword(resolution, ["not tripped", "deferred", "superseded", "passed"])
        )
        if not substantive:
            return BLOCK with reason "kill_criteria_resolution non-substantive (no threshold reference + no acceptance keyword)"
        return PASS
    OUTPUT: state.json::pre_merge_review.{ux|design} = "passed" | "passed_with_notes" | "blocked"
```

**Contract for T21 implementer:**

| Aspect | Spec |
|--------|------|
| Hook into existing review | Sub-step 6f runs AFTER existing 6a-6e (per `docs/skills/ux.md` and `docs/skills/design.md` current Phase 6 chain) |
| State.json write | Atomic via `flock_writer.py`; updates `pre_merge_review.{ux|design}` field only |
| BLOCK behavior | Phase 7 (Merge) cannot advance until BLOCK is resolved (either fix kill_criteria_resolution or override with state.json::pre_merge_review.override_reason) |
| Heuristic tuning | First-week telemetry expected to surface false-positives. v7.9 promotion may tighten/loosen the keyword list based on data |
| Test coverage | T21 implementation MUST include synthetic test cases in `scripts/tests/test_pre_merge_review.py` (or skill-specific test file): empty resolution, substantive-with-threshold, substantive-with-keyword, non-substantive |

**Skill doc updates required:**

- [`docs/skills/ux.md`](../../../docs/skills/ux.md) — append §6f to "Phase 6 dispatch chain" table
- [`docs/skills/design.md`](../../../docs/skills/design.md) — same
- [`.claude/skills/ux/SKILL.md`](../../../.claude/skills/ux/SKILL.md) — agent-facing prompt update
- [`.claude/skills/design/SKILL.md`](../../../.claude/skills/design/SKILL.md) — agent-facing prompt update

---

## 3. Backward compatibility

### 3.1 Existing 12 write-time gates: zero regression contract

All 12 existing write-time gates (`SCHEMA_DRIFT`, `SCHEMA_DRIFT_LEGACY_CREATED`, `NO_PHASE`, `INVALID_JSON`, `PR_NUMBER_UNRESOLVED`, `PHASE_TRANSITION_NO_LOG`, `PHASE_TRANSITION_NO_TIMING`, `CACHE_HITS_EMPTY_POST_V6`, `CU_V2_INVALID`, `STATE_NO_CASE_STUDY_LINK`, `CASE_STUDY_MISSING_FIELDS`, `FRAMEWORK_VERSION_FORMAT`) MUST:

1. Continue to fire on the same trigger conditions
2. Continue to emit Mechanism A coverage telemetry to `gate-coverage.jsonl`
3. Continue to print the same error messages
4. Continue to exit with the same non-zero codes on failure

**Verification:** T27 (integration test) extends `scripts/test-v7-5-pipeline.sh` with assertions that all 12 existing gates still fire + report unchanged coverage on synthetic violations.

### 3.2 Existing 13 cycle-time codes: zero regression

All 13 existing cycle-time codes in [`scripts/integrity-check.py`](../../../scripts/integrity-check.py) (`PHASE_LIE`, `TASK_LIE`, `NO_CS_LINK`, `V2_FILE_MISSING`, `PARTIAL_SHIP_TERMINAL`, `NO_STATE`, `INVALID_JSON`, `NO_PHASE`, `SCHEMA_DRIFT`, `PR_NUMBER_UNRESOLVED`, `BROKEN_PR_CITATION`, `CASE_STUDY_MISSING_TIER_TAGS`, `CU_V2_INVALID`) PLUS 3 advisories (`CACHE_HITS_AUTO_INSTRUMENTATION_INACTIVE`, `TIER_TAG_LIKELY_INCORRECT`, `GATE_COVERAGE_ZERO`) continue unchanged.

**Verification:** T26 + cycle-time test additions confirm these continue to fire + report unchanged on synthetic violations.

### 3.3 New schema fields default-safe

The 3 new state.json fields (`isolation_opt_out`, `isolation_opt_out_reason`, `worktree_path`) all have safe defaults:

| Field | Default | Behavior when absent |
|-------|---------|---------------------|
| `isolation_opt_out` | `false` | Gate fires for non-infra (Mode C only); no behavior change for infra (Mode B fires regardless) |
| `isolation_opt_out_reason` | `""` | Validation only checks this when `isolation_opt_out: true`; absent or empty when `false` is fine |
| `worktree_path` | `null` | Gate falls back to checking just `state.json::branch` against current branch when `worktree_path` is null. Cwd check skipped. |

**Existing 53 features:** zero migration required. They function identically with these fields absent (pre-feature-ship state) or with the defaults injected (post-feature-ship state).

### 3.4 Frontmatter additions to case studies

The 2 new case-study frontmatter fields (`kill_criteria_resolution`, `pr_citation_exempt`) are:

- `kill_criteria_resolution`: required only when `kill_criteria` is non-empty AND `current_phase=complete`. Existing case studies that DON'T set `kill_criteria` are unaffected.
- `pr_citation_exempt`: always optional. Empty array is the default.

**Existing 65 case studies:** the bidirectional PR-parity check (`FEATURE_CLOSURE_COMPLETENESS` Q6) is **forward-only** — applies only to case studies created after this feature ships. Existing case studies are grandfathered (the cycle-time mirror for closure-completeness applies to NEW closures, not retroactively to the 37 existing complete features).

### 3.5 Path-reducer config additive

`.claude/shared/path-reducers.json` already exists as a v7.8 schema bridge (PR #185+#186) with empty initial entries. This feature populates 4 entries (per PRD §8). No existing consumer reads this file in v7.8 advisory mode. v7.9 enforced reads will pick up the populated entries. No regression risk in the advisory window.

---

## 4. Error handling + bypass behavior

### 4.1 Pre-commit gate failure surface

When either new gate (`BRANCH_ISOLATION_VIOLATION` or `FEATURE_CLOSURE_COMPLETENESS`) fires:

1. Hook prints the error message contract from PRD §4.1 / §4.2 to stderr
2. Hook exits with code `1`
3. Mechanism A coverage entry recorded in `.claude/logs/gate-coverage.jsonl` with `mode: "explicit"` + actual `candidates` / `checked` / `skipped` counts
4. Git aborts the commit; staged files remain staged (operator can fix + re-stage + re-commit)

### 4.2 Bypass: `git commit --no-verify`

Standard git escape hatch. Skips the entire pre-commit hook (all 4 layers). Behavior:

- No coverage entry recorded directly by the hook (because the hook doesn't run)
- Mechanism A wraps a separate detector: `scripts/observe-bypass.py` (NEW, T-future) records the bypass as `manual_bypass` in `gate-coverage.jsonl` via a `prepare-commit-msg` hook → out of scope for v7.8 advisory ship; planned as v7.9 P-1
- Cycle-time check catches the drift on the next 72h run (the 13 cycle-time + 3 mirror codes still fire)

**Bypass discoverability:** the cycle-time mirror is the safety net. A developer who bypasses ships immediate dev-velocity gain at the cost of getting flagged in the next snapshot diff. This is the same contract v7.6 + v7.7 use.

### 4.3 Auto-isolation flow failures (T9)

When `BRANCH_ISOLATION_VIOLATION` fires and tries to auto-invoke `superpowers:using-git-worktrees`:

| Failure | Behavior |
|---------|----------|
| Skill returns `0` (worktree created) | Print success message + block this commit + exit `1`. User re-stages from worktree. |
| Skill returns `2` (already_exists) | Print "you're in the wrong worktree" message + exit `1`. User cd's into expected worktree. |
| Skill returns `3-5` (errors) | Print skill stderr + block commit + exit `1`. NO retry (loop guard). User must resolve manually. |
| Subprocess timeout (> 30s) | Print "auto-isolation timed out" + block commit + exit `1`. User can retry or use `--no-verify`. |

### 4.4 `pre_merge_review` BLOCK from skill extension (T21)

When sub-step 6f returns BLOCK:

1. Skill writes `state.json::pre_merge_review.{ux|design} = "blocked"` with `block_reason`
2. Phase 7 (Merge) gate refuses to advance
3. User has 3 paths:
   - **Fix:** add/update `kill_criteria_resolution` in case study frontmatter, re-run pre-merge-review
   - **Override:** set `state.json::pre_merge_review.override_reason = "..."` (explicit acknowledgment) and re-run; review now returns `passed_with_notes`
   - **Defer:** rollback Phase 6 to Phase 5 to gather more data; come back later

**No silent bypass.** All 3 paths require explicit operator action.

---

## 5. Service / file dependency map

### 5.1 Files this feature TOUCHES (writes/extends)

| File | Touch type | Block |
|------|-----------|-------|
| [`scripts/check-state-schema.py`](../../../scripts/check-state-schema.py) | Extends — adds 2 new gate codes + helpers | A, B, C |
| [`scripts/check-case-study-preflight.py`](../../../scripts/check-case-study-preflight.py) | Extends — adds new frontmatter field checks (Q7, Q6 bidirectional) | C |
| [`scripts/integrity-check.py`](../../../scripts/integrity-check.py) | Extends — adds 3 new check codes (HISTORICAL, LAUNCHD_DRIFT, closure mirror) | D |
| [`scripts/documentation-debt-report.py`](../../../scripts/documentation-debt-report.py) | Extends — adds new fields to `REQUIRED_FIELDS` constant | A |
| `scripts/verify-isolation.py` (NEW) | Creates | F |
| `scripts/feature-completeness-audit.py` (NEW) | Creates | F |
| `.claude/skills/ux/SKILL.md` | Extends — adds sub-step 6f | E |
| `.claude/skills/design/SKILL.md` | Extends — adds sub-step 6f | E |
| `.claude/shared/path-reducers.json` | Extends — adds 4 initial entries | A |
| `.claude/shared/branch-isolation-exempt.json` (NEW) | Creates | A |
| `.githooks/pre-commit` | Header-only (docstring update for Mechanism D self-audit) | H |
| `Makefile` | Extends — adds `verify-isolation` + `feature-completeness-audit` targets | F |
| `docs/skills/ux.md` | Extends — appends §6f | E |
| `docs/skills/design.md` | Extends — appends §6f | E |
| `docs/architecture/feature-lifecycle-event-catalog.md` | Extends — §6 gate-stack table grows | H |
| `docs/architecture/dev-guide-v1-to-v7-7.md` | Extends — §10.1 table grows | H |
| `CLAUDE.md` | Extends — Data Integrity Framework section | H |
| `.claude/integrity/README.md` | Extends — check codes inventory | H |

**18 files total.** ~40% are EXTENSIONS to existing files (low risk); ~25% are NEW files (medium risk); ~35% are documentation propagation (low risk).

### 5.2 Files this feature READS (no write)

| File | Read purpose |
|------|--------------|
| `.claude/features/*/state.json` | Source of truth for branch/worktree/work_type per feature |
| `.claude/logs/gate-coverage.jsonl` | Mechanism A coverage (read by feature-completeness-audit + integrity-check) |
| `.claude/logs/<feature>.log.json` | Tier 2.2 logs (read for the cycle-time HISTORICAL check) |
| `~/Library/LaunchAgents/*.plist` (macOS only, optional) | LAUNCHD_DRIFT advisory |
| `git log --all` | HISTORICAL audit |

### 5.3 External dependencies

**No new Python or system packages required.** This feature uses only:
- Python stdlib (`os`, `subprocess`, `pathlib`, `json`, `re`)
- `git` (already required by all v7.x gates)
- `gh` (already used by `PR_NUMBER_UNRESOLVED`; reused for PR parity check)
- `plistlib` (Python stdlib, used only on macOS for LAUNCHD_DRIFT)

---

## 6. Migration plan: advisory → enforced

### 6.1 Phase 1 — v7.8 advisory (this feature ships)

| Aspect | Behavior |
|--------|----------|
| Hook exit code | `0` on violations (advisory) — print warning, do NOT block commit |
| Mechanism A telemetry | Emitted on every evaluation (full coverage data) |
| User-facing message | "[ADVISORY] BRANCH_ISOLATION_VIOLATION: ... will become blocking in v7.9 (~2026-05-21)" |
| Cycle-time mirror | Findings reported (not gating) |

**Duration:** 7+ days minimum. v7.9 promotion gated on T+7d telemetry review.

### 6.2 Phase 2 — v7.8 grace (T+7d to T+14d)

| Aspect | Behavior |
|--------|----------|
| Hook exit code | Still `0` (advisory) |
| Telemetry review | Pull `gate-coverage.jsonl` for both new gates: verify `checked > 0` continuously, compute false-positive rate from any `manual_bypass` events |
| Decision point | If FP rate < 5% AND no kill criteria fired → schedule promotion. Else → revert + redesign. |

**Duration:** 7 days. Decision at end of grace period.

### 6.3 Phase 3 — v7.9 enforced (T+14d earliest)

| Aspect | Behavior |
|--------|----------|
| Hook exit code | `1` on violations (blocking) |
| Mechanism A telemetry | Continues unchanged |
| User-facing message | Drops "[ADVISORY]" prefix; updates to "blocking" wording |
| Framework version bump | `v7.8 → v7.9`; case study at `framework-v7-9-enforcement-case-study.md`; trust page §11 published |
| Schema enforcement | `isolation_opt_out_reason` becomes mandatory when opt-out is `true` (was advisory in v7.8) |

### 6.4 Migration toggle

A single config flag in `.claude/shared/framework-manifest.json` controls advisory/enforced:

```json
{
  "framework_version": "7.8",
  "gates": {
    "BRANCH_ISOLATION_VIOLATION": { "enforcement": "advisory", "since": "2026-05-07" },
    "FEATURE_CLOSURE_COMPLETENESS": { "enforcement": "advisory", "since": "2026-05-07" }
  }
}
```

At v7.9 promotion, both gate entries flip to `"enforcement": "enforced"`. Single-commit migration.

### 6.5 Rollback procedure (if kill criteria fire)

Per PRD §14:

1. Revert the merge commit on main: `git revert {merge_commit} -m 1`
2. Open hot-fix PR with revert
3. Restore previous `.githooks/pre-commit` content
4. Open root-cause case study within 48h
5. Re-open this feature for redesign; bump to v8 if structural changes needed

**Rollback test:** T27 integration test extension verifies revert restores all 12 existing write-time gates intact.

---

## 7. Inter-skill awareness

### 7.1 What other skills need to know

Each skill that interacts with state.json needs to be aware of the new fields:

| Skill | Awareness need |
|-------|----------------|
| `pm-workflow` | When initializing new state.json, include `isolation_opt_out: false` + `worktree_path: null` defaults. Skill template update in T1. |
| `superpowers:using-git-worktrees` | Direct extension (T20 contract above). |
| `/ux pre-merge-review` | Sub-step 6f extension (T21 contract above). |
| `/design pre-merge-review` | Sub-step 6f extension (T21 contract above). |
| `/dev` | No changes — but should be aware that `git commit` from main on infra files now triggers auto-isolation. Document in `docs/skills/dev.md` notes section. |
| `/qa` | Test coverage for new gates is part of T24-T27. |
| Other skills | No direct awareness needed — the gates are enforcement-layer and work below skill abstraction. |

### 7.2 What downstream consumers need to know

| Consumer | Awareness need |
|----------|----------------|
| `/control-room/framework` (fitme-story dashboard) | Adds 2 new gate codes to the gate-stack widget. Update happens via the FT2 → fitme-story sync pipeline. |
| `make verify-local` | Continues to invoke schema-check + ui-audit unchanged. The new gates fire at commit time, not via verify-local; verify-local doesn't need updates. |
| `make integrity-check` | Picks up the 3 new cycle-time codes automatically (they're added in `integrity-check.py` itself). |
| `pr-integrity-check.yml` (CI) | Picks up the new gates automatically (it runs the same pre-commit scripts). |
| Mechanism A coverage history (`measurement-adoption-history.json`) | Append-only ledger gains entries for new gates from week 1. |

---

## 8. Open integration questions (all defer to T9 + T20 implementation)

These are NOT decisions deferred — they're implementation choices left to the task that builds the actual code:

1. **T9 dispatch mechanism:** subprocess vs hub-mediated vs in-process? Implementer chooses based on what works cleanly with the existing pre-commit hook architecture. Contract is fixed; mechanism is implementer's call.
2. **T20 worktree placement:** absolute path computed by skill OR delegated to user prompt? T20 should default to absolute path (deterministic) but expose `--worktree-name-override` as documented above.
3. **T21 heuristic tuning:** initial keyword list is `["not tripped", "deferred", "superseded", "passed"]`. T21 implementer can add more (e.g. "no impact", "below threshold") if first-week telemetry shows false-positives.

These are NOT "open questions blocking the spec." They're implementation latitude for Phase 4.

---

## 9. Acceptance gate to advance Phase 3 → Phase 4

This integration spec is approvable when:

- [x] Pre-commit hook integration order documented (§1)
- [x] Both skill API contracts written (§2.1 + §2.2)
- [x] Backward compatibility guarantees explicit (§3, 5 sections)
- [x] Error handling + bypass behavior covered (§4)
- [x] File dependency map complete (§5)
- [x] Migration plan from advisory → enforced (§6)
- [x] Inter-skill awareness documented (§7)
- [x] Implementation latitude items called out as such, not as blockers (§8)
- [ ] **User approval of this integration spec**

On approval, advance to Phase 4 (Implementation):
- Begin Block A (E-core, parallel) → schema additions: T1, T2, T3, T4
- Then Block B + C (P-core, serial) → gate predicate logic
- Then Blocks D-H per the dispatch order in tasks.md

---

## References

- [`prd.md`](prd.md) §3-§7 — schema additions, gate specifications, hook integration, make targets, skill extensions
- [`tasks.md`](tasks.md) — Block A-H decomposition with dependency graph
- [`research.md`](research.md) §8.3 — 7 locked decisions feeding into this contract
- [`feature-lifecycle-event-catalog.md`](../../../docs/architecture/feature-lifecycle-event-catalog.md) §6 — current gate stack inventory (will grow when this feature ships)
- [`dev-guide-v1-to-v7-7.md`](../../../docs/architecture/dev-guide-v1-to-v7-7.md) §10.1 — current 12 + 13 + 3 code inventory
