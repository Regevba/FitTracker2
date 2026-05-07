# PRD — framework-v7-8-branch-isolation

> **Feature:** `framework-v7-8-branch-isolation`
> **Framework version:** v7.8 (advisory ship) → v7.9 (enforced promotion candidate)
> **Work type:** Feature · `cu_v2.tier_class: A_high` (2.55) · `work_subtype: framework_feature`
> **Author date:** 2026-05-07
> **Phase:** PRD (Phase 1)
> **Predecessors:** v7.5 → v7.6 → v7.7 → v7.8 bridge → hadf-infrastructure
> **Inputs:** [`research.md`](research.md) §8.3 (7 locked decisions), 3 prior research notes, [`feature-lifecycle-event-catalog.md`](../../../docs/architecture/feature-lifecycle-event-catalog.md) §11
>
> **Scope:** Two cooperating gates extending the v7.8 enforcement layer — `BRANCH_ISOLATION_VIOLATION` (cross-worktree write protection + auto-isolation) and `FEATURE_CLOSURE_COMPLETENESS` (state.json ↔ case-study cross-reference completeness on `current_phase=complete` transitions). Plus 6 supporting deliverables.

---

## 1. Summary

Two pre-commit gates closing two empirically-witnessed silent-pass failure modes:

1. **`BRANCH_ISOLATION_VIOLATION`** — prevents agents from mutating a feature's state from a worktree whose `branch + cwd + WorkingDirectory` doesn't match the expected isolation. Two firing modes: aggressive (every commit) for infra/framework work; conservative (current_phase mutations only) for user-facing features. Auto-triggers `superpowers:using-git-worktrees` to create the missing worktree on fire. Per-feature opt-out via `state.json::isolation_opt_out: true` (overridden for infra work).
2. **`FEATURE_CLOSURE_COMPLETENESS`** — fires on `current_phase → complete` commits. Validates the case study has all required frontmatter fields, all numeric claims carry T1/T2/T3 tier tags, and the state.json ↔ case study PR-list parity is bidirectional. `kill_criteria_resolution` is required when `kill_criteria` is set, with secondary verification in `/ux + /design pre-merge-review`.

Both gates ship in **v7.8 advisory mode** (telemetry only, no blocks) until ≥7 days of Mechanism A coverage data confirms low false-positive rate; then promote to **v7.9 enforced**.

---

## 2. Goals & success metrics

| Metric | Tier | Baseline | Target | Kill criteria |
|--------|------|----------|--------|---------------|
| `BRANCH_ISOLATION_VIOLATION` effective coverage on infra commits | T1 (gate-coverage.jsonl) | 0% (gate doesn't exist) | ≥ 95% of infra-path commits sampled within 7 days | < 50% after 7 days continuous |
| `FEATURE_CLOSURE_COMPLETENESS` coverage on `current_phase=complete` commits | T1 (gate-coverage.jsonl) | 0% | 100% of complete-transitions sampled | < 90% after 7 days |
| Doc-debt items detected at write-time vs cycle-time | T1 (`make documentation-debt`) | 5 items at session start (post-hoc only) | 0 items reach cycle-time gate (caught at write) | > 1 item reaches cycle-time gate after 30d |
| False-positive rate on closure-completeness gate | T1 (`manual_bypass` events) | N/A | < 5% of fires | > 20% of fires in week 1 |
| False-positive rate on branch-isolation gate (legitimate-on-main blocked) | T1 (`manual_bypass` events) | N/A | < 5% of fires | > 20% of fires in week 1 |
| `make feature-completeness-audit` runtime | T1 (wall time) | N/A | < 10s for 53 features | > 60s |
| Pre-commit hook total runtime | T1 (hook timing) | ~3s current | ≤ 5s post-ship | > 10s (degrades dev velocity, revert) |

**Secondary (qualitative + narrative):**
- HADF-Phase-2-class incidents prevented in next 60d (T2 declared, narrative count)
- Operator perceived friction (T3 narrative, captured in case study Phase 9)
- v7.9 promotion eligibility: gate's `gate-coverage.jsonl` shows `checked > 0` for ≥ 7 days continuously without any "checked=0" gap

**Guardrail metrics (must not degrade):**
- Existing 12 write-time gates: 0 regressions in their `gate-coverage.jsonl` `checked > 0` streaks
- `make verify-local` total runtime: stays under 30s
- `make integrity-check` runtime: stays under 5s

**Leading indicators (week 1 post-ship):**
- ≥ 1 feature transitioned `current_phase → complete` with `FEATURE_CLOSURE_COMPLETENESS` firing in advisory mode (telemetry recorded)
- ≥ 1 infra commit triggered `BRANCH_ISOLATION_VIOLATION` advisory and auto-invoked `superpowers:using-git-worktrees`
- 0 reports of false positives blocking legitimate work
- `.claude/logs/gate-coverage.jsonl` shows both new gates firing on every relevant commit

**Lagging indicators (30 / 60 / 90 day):**
- 30d: `make documentation-debt` open items stays at ≤ 2 (only cron-blocked + advisory) — no regression to 5
- 60d: 0 HADF-class incidents recurring
- 90d: v7.9 promotes both gates from advisory → enforced; trust page §11 published

**Kill criteria (drop the feature, roll back):**
- `BRANCH_ISOLATION_VIOLATION` blocks > 20% of legitimate-on-main commits in week 1 → revert + redesign exemption logic
- `FEATURE_CLOSURE_COMPLETENESS` blocks completes the user explicitly authorized → revert + add per-feature opt-out
- Pre-commit hook total runtime exceeds 10s → revert (degrades dev velocity)
- Mechanism A coverage ledger shows new gates at `checked=0` for 7 consecutive days → revert (gate not effectively firing — failed by silent-pass class repeat of v7.7's `CACHE_HITS_EMPTY_POST_V6` lesson)

**First post-launch metrics review:** 2026-05-14 (T+7d). Then weekly to 30d, then monthly to 90d.

---

## 3. Schema additions

### 3.1 New state.json fields (canonical)

Added to the canonical schema validated by [`scripts/check-state-schema.py`](../../../scripts/check-state-schema.py):

| Field | Type | Default | Required when | Notes |
|-------|------|---------|---------------|-------|
| `isolation_opt_out` | boolean | `false` | always present | Per Q3. When `true`, suppresses `BRANCH_ISOLATION_VIOLATION` for this feature. Overridden for infra/framework work. |
| `isolation_opt_out_reason` | string | `""` | when `isolation_opt_out: true` | Mandatory explanation. Empty when opt-out is false. Audited at cycle-time for unexplained opt-outs. |
| `worktree_path` | string \| null | `null` | optional, populated post-isolation | Absolute path to the feature's worktree (e.g. `/Volumes/DevSSD/FitTracker2-infra-branch-isolation`). Used by gate to verify cwd matches expected location. Set by `superpowers:using-git-worktrees` skill when worktree created. |

Existing fields used (no schema change, just newly checked):
- `branch` — must match `git rev-parse --abbrev-ref HEAD` at commit time when gate fires
- `work_subtype` — drives infra-path classifier (Q1)
- `work_type` — `chore` triggers infra mode regardless of subtype

### 3.2 New case-study frontmatter fields

Added to the canonical required-field list in [`scripts/documentation-debt-report.py`](../../../scripts/documentation-debt-report.py) and validated by `FEATURE_CLOSURE_COMPLETENESS`:

| Field | Type | Required when | Notes |
|-------|------|---------------|-------|
| `kill_criteria_resolution` | string \| array | `kill_criteria` is non-empty AND `current_phase=complete` | Per Q7. Substantive disclosure of whether kill thresholds were tripped, deferred, or superseded. Empty → block. |
| `pr_citation_exempt` | array of `{pr_number: int, reason: string}` | optional | Per Q6. Exempts specific PRs from bidirectional parity check. Empty array OK. |

### 3.3 New shared config files

| File | Purpose | Schema |
|------|---------|--------|
| `.claude/shared/path-reducers.json` | Already exists as v7.8 schema bridge (PR #185+#186). Extend with merge semantics for shared paths declared by features. | `{path: string, semantics: append \| replace \| max \| exclusive_write \| union_dedup, declared_by: feature-slug}` |
| `.claude/shared/agent-leases.json` | Already exists as v7.8 schema bridge. Extend with active leases (worktree → feature → declared paths). | `{feature: slug, worktree_path: string, leased_paths: [string], started_at: ISO8601, last_heartbeat: ISO8601}` |
| `.claude/shared/branch-isolation-exempt.json` | NEW. Allowlist of paths exempt from infra-mode classification (e.g. CLAUDE.md edits in main during freeze). | `{paths: [glob], reason: string, expires_at: ISO8601 \| null}` |

---

## 4. Gate specifications

### 4.1 `BRANCH_ISOLATION_VIOLATION` — write-time

**Trigger predicate:**
```python
def should_check_branch_isolation(staged_files: list[str], feature: dict) -> bool:
    """
    Returns True if the gate should evaluate this commit.
    """
    # Mode B — infra/framework work — fires on EVERY commit
    if is_infra_work(staged_files, feature):
        return True

    # Mode C — non-infra features — fires only on current_phase mutations
    if mutates_current_phase(staged_files):
        # Per-feature opt-out
        if feature.get("isolation_opt_out", False):
            return False  # opt-out honored for non-infra
        return True

    return False  # not infra, not phase mutation → skip


def is_infra_work(staged_files: list[str], feature: dict) -> bool:
    """Infra paths classifier (Mode B trigger)."""
    INFRA_GLOBS = [
        ".githooks/*",
        ".github/workflows/*",
        "scripts/*",
        ".claude/skills/*",
        ".claude/shared/*",  # except path-reducers.json + agent-leases.json which are union-dedup
        "CLAUDE.md",
        "docs/architecture/*",
        "Makefile",
    ]
    if any(glob_match(f, INFRA_GLOBS) for f in staged_files):
        return True
    # Or: feature classifies as infra
    if feature.get("work_subtype") == "framework_feature":
        return True
    if feature.get("work_type") == "chore":
        return True
    return False
```

**Violation predicate:**
```python
def is_branch_isolation_violation(feature: dict, current_branch: str, current_cwd: str) -> bool:
    expected_branch = feature.get("branch")  # e.g. "feature/framework-v7-8-branch-isolation"
    expected_worktree = feature.get("worktree_path")  # absolute path

    # Branch check
    if expected_branch and current_branch != expected_branch:
        return True

    # Worktree (cwd) check
    if expected_worktree and not current_cwd.startswith(expected_worktree):
        return True

    return False
```

**Auto-isolation flow (Q2):**
1. Gate fire → block commit with exit code 1
2. Print: `Branch isolation violation. Feature {name} expects branch={expected_branch} at cwd={expected_worktree}; got branch={current_branch} at cwd={current_cwd}.`
3. Auto-dispatch: invoke `superpowers:using-git-worktrees` with args `--feature framework-v7-8-branch-isolation --create-if-missing` (subagent or hub-controlled)
4. Skill creates worktree at smart-directory-selected path, registers it in `agent-leases.json`, updates `state.json::worktree_path`
5. User re-stages from inside the new worktree; subsequent commit passes the gate

**Mechanism A coverage emission:**
```jsonl
{"timestamp":"...","mode":"explicit","gate":"BRANCH_ISOLATION_VIOLATION","candidates":N,"checked":N,"skipped":0,"skip_reasons":{}}
```

**Bypass:** `git commit --no-verify` works (recorded as `manual_bypass` in coverage). For infra work, the `--no-verify` is the ONLY bypass — `isolation_opt_out` is ignored.

**Error message contract:**
```
✖ BRANCH_ISOLATION_VIOLATION: framework-v7-8-branch-isolation
  Expected: branch=feature/framework-v7-8-branch-isolation, cwd=/Volumes/DevSSD/FitTracker2-infra-branch-isolation
  Got:      branch=main,                                   cwd=/Volumes/DevSSD/FitTracker2

  Auto-isolation: invoking superpowers:using-git-worktrees to create the missing worktree.
  After it lands, re-stage your changes inside the new worktree and re-commit.

  Emergency bypass (audited): git commit --no-verify
```

### 4.2 `FEATURE_CLOSURE_COMPLETENESS` — write-time

**Trigger predicate:**
```python
def should_check_closure_completeness(staged_files: list[str], feature: dict) -> bool:
    # Fires only when state.json transitions to current_phase=complete
    if not is_state_json_in(staged_files, feature):
        return False
    new_phase = read_staged_state_json(feature)["current_phase"]
    if new_phase != "complete":
        return False
    return True
```

**Violation predicate:**
```python
def closure_completeness_violations(feature: dict, case_study_path: str) -> list[str]:
    """
    Returns list of violation strings; empty list means pass.
    """
    violations = []
    case_study = parse_frontmatter(case_study_path)

    # Required field presence (sourced from documentation-debt-report.py)
    REQUIRED_FIELDS = [
        "date_written",  # OR "date" — synonym accepted
        "dispatch_pattern",
        "success_metrics",  # OR "primary_metric"
        "kill_criteria",
        "framework_version",
        "work_type",
        "tier_tags_present",  # boolean must be true
    ]
    for field in REQUIRED_FIELDS:
        if not has_required_field(case_study, field):
            violations.append(f"missing frontmatter: {field}")

    # Q7 — kill_criteria_resolution required when kill_criteria set
    if case_study.get("kill_criteria") and not case_study.get("kill_criteria_resolution"):
        violations.append("kill_criteria set but kill_criteria_resolution is empty")

    # Q6 — bidirectional PR parity
    state_prs = collect_state_prs(feature)  # tasks[].pr_number + phases.merge.pr_number + tasks[].related_prs
    case_prs = collect_case_study_prs(case_study_path)  # regex `PR #N` / `pull/N` + frontmatter related_prs
    exempt = {e["pr_number"] for e in case_study.get("pr_citation_exempt", [])}

    state_only = (state_prs - case_prs) - exempt
    case_only = (case_prs - state_prs) - exempt
    if state_only:
        violations.append(f"PRs in state.json but not cited in case study: {sorted(state_only)}")
    if case_only:
        violations.append(f"PRs in case study but not in state.json: {sorted(case_only)}")

    # T1/T2/T3 tier tag presence on numeric claims (existing CASE_STUDY_MISSING_TIER_TAGS regex)
    # Already enforced by separate v7.6 gate; we just verify it ran clean

    return violations
```

**Mechanism A coverage emission:**
```jsonl
{"timestamp":"...","mode":"explicit","gate":"FEATURE_CLOSURE_COMPLETENESS","candidates":1,"checked":1,"skipped":0,"skip_reasons":{}}
```
or, when not a complete-transition:
```jsonl
{"timestamp":"...","mode":"explicit","gate":"FEATURE_CLOSURE_COMPLETENESS","candidates":1,"checked":0,"skipped":1,"skip_reasons":{"not_complete_transition":1}}
```

**Error message contract:**
```
✖ FEATURE_CLOSURE_COMPLETENESS: framework-v7-8-branch-isolation
  Closure commit blocked. Case study at docs/case-studies/framework-v7-8-branch-isolation-case-study.md is missing:
    - missing frontmatter: kill_criteria_resolution
    - PRs in state.json but not cited in case study: [241, 242]

  Fix the case study, re-stage, re-commit. Or use pr_citation_exempt frontmatter to scope-out chore PRs.

  Emergency bypass (audited): git commit --no-verify
```

### 4.3 Cycle-time mirrors

| Code | Where | What it does | Severity |
|------|-------|--------------|----------|
| `BRANCH_ISOLATION_HISTORICAL` | `integrity-check.py` | Audits `.claude/features/*/state.json` against `git log --all --oneline -- path/to/feature/`. Flags features whose entire git history happened on main (no `feature/{name}` branch ever existed). Forward-only: applies only to features with `created_at >= ship_date` of this gate. | advisory |
| `BRANCH_ISOLATION_LAUNCHD_DRIFT` | `integrity-check.py` (macOS only, skip on Linux/CI) | Scans `~/Library/LaunchAgents/*.plist` files. For each plist whose `ProgramArguments` references a script writing to `.claude/features/`, verifies its `WorkingDirectory` matches the expected worktree. | advisory |
| `FEATURE_CLOSURE_COMPLETENESS` (mirror) | `integrity-check.py` | Re-runs the same predicate on every feature with `current_phase=complete` to catch `--no-verify` bypasses. | findings (gating in v7.9) |

### 4.4 Promotion path: advisory → enforced

| Phase | Trigger | Behavior |
|-------|---------|----------|
| **Phase 1 (v7.8 advisory)** | Ship date | Both gates EMIT coverage telemetry to `gate-coverage.jsonl` but do NOT block any commits. Print warnings only. |
| **Phase 2 (v7.8 grace)** | T+7d (2026-05-14) | Review week-1 telemetry. If `checked > 0` continuously AND `false_positive_rate < 5%` → schedule promotion. If kill criteria fire → revert. |
| **Phase 3 (v7.9 enforced)** | T+14d at earliest, gated by phase-2 review | Both gates promoted to blocking mode. Pre-commit hook exits non-zero on violations. v7.9 framework version bump. |

Promotion checklist (v7.9 measurement window opens 2026-05-11 per existing v7.8 bridge): see `docs/research/2026-05-02-framework-v7-9-implementation-safety-research.md` §3.

---

## 5. Pre-commit hook integration

[`.githooks/pre-commit`](../../../.githooks/pre-commit) gains 2 new check invocations in this exact order (preserving existing 4-layer structure):

```bash
# Defense layer 1: state.json schema + transition gates (existing)
"$state_schema_checker" --staged

# Defense layer 2: case-study preflight (existing)
"$case_study_checker" --staged

# Defense layer 3: branch isolation (NEW — v7.8 advisory, v7.9 enforced)
"$branch_isolation_checker" --staged

# Defense layer 4: feature closure completeness (NEW — v7.8 advisory, v7.9 enforced)
"$closure_completeness_checker" --staged
```

Each new checker is implemented as a method in `scripts/check-state-schema.py` (extending the existing module rather than creating new top-level scripts; reduces hook orchestration overhead).

Mechanism D self-audit (`make pre-commit-self-test`) updated: hook header docstring grows 2 new gate code references; `pre-commit-self-test.py` validates header matches implementation.

---

## 6. `make` target specifications

### 6.1 `make verify-isolation`

Runs [`scripts/verify-isolation.py`](../../../scripts/verify-isolation.py) (NEW). Output format:

```
Branch isolation status — 2026-05-XX HH:MM UTC
================================================
✓ framework-v7-8-branch-isolation
    expected: feature/framework-v7-8-branch-isolation @ /Volumes/DevSSD/FitTracker2-infra-branch-isolation
    actual:   feature/framework-v7-8-branch-isolation @ /Volumes/DevSSD/FitTracker2-infra-branch-isolation
    launchd:  no plists reference this feature

✗ hadf-infrastructure
    expected: feature/hadf-infrastructure @ ?
    actual:   chore/hadf-phase2-progress-snapshot @ /Volumes/DevSSD/FitTracker2-hadf-campaign
    finding:  branch mismatch (expected feature/hadf-infrastructure)

3 of 53 features have isolation findings:
  - hadf-infrastructure (branch mismatch)
  - sentry-integration (no worktree_path declared)
  - case-study-monitoring-extension (paused, no expected branch)
```

Exit code: 0 if all features clean OR all findings have explicit opt-out reasons; 1 otherwise.

### 6.2 `make feature-completeness-audit`

Runs [`scripts/feature-completeness-audit.py`](../../../scripts/feature-completeness-audit.py) (NEW). Output format:

```
Feature completeness audit — 2026-05-XX HH:MM UTC
=================================================
Phase-appropriate field-presence check across 53 features:

✓ Research phase (12 features) — schema basics check
    [all pass]

✓ PRD phase (3 features) — cu_v2 + success_metrics required
    framework-v7-8-branch-isolation: cu_v2 + success_metrics ✓

⚠ Implementation phase (1 feature) — tasks[] populated required
    XXX-feature: tasks[] empty (use /pm-workflow tasks to populate)

✗ Complete phase (37 features) — full closure-completeness check
    framework-honesty-fixes-2026-05-01:
      missing frontmatter: kill_criteria_resolution

Total findings: 1 implementation + 1 complete = 2
Exit: 1
```

Exit code: 0 if 0 findings (or all advisory); 1 if any blocking finding.

Runtime budget: < 10s for 53 features.

---

## 7. Skill extensions

### 7.1 `superpowers:using-git-worktrees`

Extension: when invoked with args `--feature {slug} --create-if-missing`, the skill:
1. Reads `state.json::work_subtype` and `state.json::work_type`. If infra/chore, picks naming `FitTracker2-infra-{shortname}`. Else `FitTracker2-{feature}`.
2. If a worktree already exists at the expected path (per `state.json::worktree_path`), aborts with `already_exists`.
3. If not, creates: `git worktree add {expected_path} -b {expected_branch}` from current main HEAD.
4. Updates `state.json::worktree_path = {expected_path}`.
5. Updates `.claude/shared/agent-leases.json` to register the lease.
6. Returns the new worktree path to the caller.

The skill's existing smart-directory-selection logic continues to handle the path picking when the user invokes manually without args.

### 7.2 `/ux pre-merge-review` and `/design pre-merge-review` (Q7 verification)

Both skills extended in [`docs/skills/ux.md`](../../../docs/skills/ux.md) and [`docs/skills/design.md`](../../../docs/skills/design.md) with a new sub-step:

```
6f. kill_criteria_resolution check
    if state.json::case_study has kill_criteria set:
        verify state.json::case_study::kill_criteria_resolution is non-empty
        AND substantively addresses each kill threshold (heuristic: mentions
        at least 1 of the kill thresholds verbatim OR contains words "not
        tripped" / "deferred" / "superseded" / "passed")
    else:
        skip (no kill criteria, no resolution required)

    On failure: set state.json::pre_merge_review.{ux|design}: blocked
                with reason "kill_criteria_resolution missing or non-substantive"
    Phase 7 cannot advance until resolved.
```

---

## 8. Path-reducer config

[`.claude/shared/path-reducers.json`](../../../.claude/shared/path-reducers.json) gets initial entries for the 4 known shared ledgers (per research §3.1 Approach A):

```json
{
  "version": "1.0",
  "reducers": [
    {
      "path": ".claude/shared/measurement-adoption-history.json",
      "semantics": "union_dedup",
      "key": "date",
      "declared_by": "framework-v7-7-validity-closure"
    },
    {
      "path": ".claude/shared/documentation-debt.json",
      "semantics": "replace",
      "rationale": "single point-in-time snapshot, not append-only",
      "declared_by": "framework-v7-7-validity-closure"
    },
    {
      "path": ".claude/logs/gate-coverage.jsonl",
      "semantics": "append",
      "declared_by": "framework-v7-8-bridge"
    },
    {
      "path": ".claude/logs/_session-*.events.jsonl",
      "semantics": "append",
      "scope": "per-session",
      "declared_by": "framework-v7-8-bridge"
    }
  ]
}
```

Mechanism E merge driver already handles `union_dedup` and `append` semantics (PR #189). No new merge-driver code required for this PRD; only declarative config.

---

## 9. Test plan

### 9.1 Unit tests (extend `scripts/tests/test_check_state_schema.py`)

| Test | What it verifies |
|------|-----------------|
| `test_branch_isolation_fires_on_infra_path` | Mode B triggers correctly on `.githooks/*` edit from main |
| `test_branch_isolation_skips_non_infra_typo_fix` | Mode C does NOT trigger on a non-state.json edit on a non-infra feature |
| `test_branch_isolation_fires_on_phase_mutation` | Mode C triggers on `current_phase` change from main when feature has `branch: feature/foo` |
| `test_branch_isolation_honors_opt_out_for_non_infra` | `isolation_opt_out: true` suppresses for non-infra |
| `test_branch_isolation_overrides_opt_out_for_infra` | `isolation_opt_out: true` is IGNORED for infra/chore work |
| `test_closure_completeness_blocks_missing_kill_criteria_resolution` | Q7 gate fires when `kill_criteria` set but `_resolution` empty |
| `test_closure_completeness_bidirectional_pr_parity` | Q6 detects state-only and case-only PR mismatches |
| `test_closure_completeness_pr_citation_exempt_works` | Override allows PR mismatches when listed in `pr_citation_exempt` |
| `test_mechanism_a_coverage_emitted_for_both_gates` | gate-coverage.jsonl contains entries for both new gates with non-zero `candidates` |

### 9.2 Integration tests (extend `scripts/test-v7-5-pipeline.sh`)

15-assertion regression test grows by 4 assertions:
- `BRANCH_ISOLATION_VIOLATION` fires correctly on synthetic violation
- `BRANCH_ISOLATION_VIOLATION` does NOT fire when properly isolated
- `FEATURE_CLOSURE_COMPLETENESS` fires correctly on synthetic missing-field
- `FEATURE_CLOSURE_COMPLETENESS` honors `pr_citation_exempt`

### 9.3 Cycle-time tests (extend `scripts/tests/test_integrity_check.py`)

- `BRANCH_ISOLATION_HISTORICAL` advisory fires on synthetic feature-with-only-main-history
- `BRANCH_ISOLATION_LAUNCHD_DRIFT` advisory fires on synthetic plist with bad WorkingDirectory (macOS-only test)
- Cycle-time mirror of `FEATURE_CLOSURE_COMPLETENESS` catches `--no-verify` bypass

### 9.4 Test runtime budget

- Unit tests: < 5s total (extend existing pytest suite)
- Integration test: < 30s total (current `test-v7-5-pipeline.sh` is ~15s; +15s for new tests)

---

## 10. Acceptance criteria

Phase 5 (Test) cannot complete until all 5 sections below are checked.

### 10.1 `BRANCH_ISOLATION_VIOLATION` write-time gate

- [ ] Predicate implemented in `scripts/check-state-schema.py` matching §4.1 spec
- [ ] Mode B (infra) triggers on every commit when staged files match infra glob OR feature classifies as infra
- [ ] Mode C (non-infra) triggers only on `current_phase` mutation
- [ ] `isolation_opt_out: true` suppresses for non-infra
- [ ] `isolation_opt_out: true` is IGNORED for infra
- [ ] Auto-invokes `superpowers:using-git-worktrees` on fire (per §4.1 flow)
- [ ] Mechanism A coverage telemetry emitted to `gate-coverage.jsonl` on every evaluation
- [ ] Error message matches §4.1 contract verbatim
- [ ] `--no-verify` bypass works and records `manual_bypass`

### 10.2 `FEATURE_CLOSURE_COMPLETENESS` write-time gate

- [ ] Predicate implemented in `scripts/check-state-schema.py` matching §4.2 spec
- [ ] Triggers ONLY on `current_phase=complete` transitions in staged state.json
- [ ] Validates 7 required frontmatter fields per §4.2
- [ ] Q7: enforces `kill_criteria_resolution` when `kill_criteria` set
- [ ] Q6: bidirectional PR parity check both directions; `pr_citation_exempt` honored
- [ ] Mechanism A coverage telemetry emitted (with skip_reason `not_complete_transition` when not firing)
- [ ] Error message matches §4.2 contract verbatim

### 10.3 Cycle-time advisories

- [ ] `BRANCH_ISOLATION_HISTORICAL` implemented in `scripts/integrity-check.py`
- [ ] `BRANCH_ISOLATION_LAUNCHD_DRIFT` implemented (macOS-only, gracefully skipped on Linux/CI)
- [ ] `FEATURE_CLOSURE_COMPLETENESS` cycle-time mirror catches `--no-verify` bypass
- [ ] All 3 surface in `make integrity-check` output as advisory only (no blocking)

### 10.4 Readouts

- [ ] `make verify-isolation` runs in < 5s, output matches §6.1 format
- [ ] `make feature-completeness-audit` runs in < 10s for 53 features, phase-appropriate checks per §6.2

### 10.5 Skill extensions

- [ ] `superpowers:using-git-worktrees` accepts `--feature X --create-if-missing` args, picks naming convention by work_type/subtype, updates state.json::worktree_path + agent-leases.json
- [ ] `/ux pre-merge-review` extended with sub-step 6f (kill_criteria_resolution check)
- [ ] `/design pre-merge-review` extended with sub-step 6f
- [ ] `docs/skills/ux.md` and `docs/skills/design.md` documented updates
- [ ] Mechanism D self-audit passes on the updated `.githooks/pre-commit` header

### 10.6 Documentation

- [ ] `docs/architecture/feature-lifecycle-event-catalog.md` §6 updated with both new gates
- [ ] `docs/architecture/dev-guide-v1-to-v7-7.md` §10.1 table updated (12 → 14 write-time gates; 13 → 16 cycle-time codes)
- [ ] `CLAUDE.md` Data Integrity Framework section updated with the 2 new gates
- [ ] `.claude/integrity/README.md` updated with new check codes
- [ ] Path-reducer config (`.claude/shared/path-reducers.json`) populated per §8

---

## 11. Out of scope

Explicitly deferred to v8.0+ (per research §10.2):
- Sapling-smartlog-style live awareness UI (requires new framework subsystem)
- Op-log-based recoverable rollback (jj-style — needs new infrastructure)
- Vercel Sandbox / Firecracker microVM isolation (overkill for cooperative agents)
- Filesystem-level kernel sandboxing (Landlock / macOS App Sandbox — OS-specific)
- inotify/fsevents broadcast mediator (post-MVP enhancement)
- Cross-feature dependency analysis (which features touch which paths — needs path-reducer registry to mature first)
- Auto-rollback on kill criteria fire (today: human triggers revert)

---

## 12. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| `BRANCH_ISOLATION_VIOLATION` over-fires on legitimate-on-main work (CLAUDE.md edits during freeze) | Medium | High (blocks framework operators) | `BRANCH_ISOLATION_EXEMPT` allowlist + `--no-verify` always works + advisory mode for first 7d |
| Auto-isolation flow loops (gate fires, skill creates worktree, but path-reducer config rejects it, gate fires again) | Low | Medium (operator trapped in loop) | Loop detection: skill records `auto_isolation_attempted: true` flag; if gate sees this flag, blocks the loop and asks user |
| Bidirectional PR parity flags chore PRs (e.g. typo fix on case study itself) | High | Medium (annoying but not blocking thanks to override) | `pr_citation_exempt` override; default-empty so user explicitly chooses exemption |
| `kill_criteria_resolution` heuristic false-positives on substantive resolutions phrased differently | Medium | Low (override via `--no-verify`) | Heuristic is generous (any of 4 keywords or any kill threshold mention); v7.9 will calibrate from week-1 false-positive data |
| Pre-commit hook runtime budget exceeded by 2 new gates | Medium | High (degrades dev velocity → kill criteria) | Each new gate has < 200ms budget; profile in `test-v7-5-pipeline.sh`; revert if budget exceeded |
| macOS plist scan reads private user files (privacy concern) | Low | Medium (operator confusion) | Optional, off-by-default. Surfaced in `make integrity-check` only when `INTEGRITY_CHECK_LAUNCHD_SCAN=1` is set |
| Cycle-time `BRANCH_ISOLATION_HISTORICAL` flags pre-existing features (forward-only failure) | Medium | Low (advisory only, doesn't block) | Forward-only by design: only applies to features with `created_at >= ship_date` of this gate |
| `FEATURE_CLOSURE_COMPLETENESS` blocks valid completes where kill_criteria are deferred | Medium | High (operator can't ship) | `kill_criteria_resolution: "deferred to T+30d post-launch review"` is acceptable phrasing per Q7 heuristic; explicitly tested in §9.1 |

---

## 13. Review cadence

| Date | Cadence | Activity |
|------|---------|----------|
| 2026-05-14 (T+7d) | First review | Telemetry pull from `gate-coverage.jsonl`. Verify ≥7d continuous `checked > 0` for both gates. Compute false-positive rate from `manual_bypass` events. Decide v7.9 promotion eligibility. |
| 2026-05-21 (T+14d) | Promotion (if eligible) | Promote both gates to v7.9 enforced mode. Bump framework_version. Open promotion case study at `framework-v7-9-enforcement-case-study.md`. |
| Weekly to T+30d | Weekly review | Continue telemetry pull; verify no regression. |
| Monthly to T+90d | Monthly review | Verify lagging indicators. Decide if any deferred-to-v8 items unblocked by week-90 data. |

---

## 14. Rollback plan

If kill criteria fire at T+7d review:

1. Revert the `feature/framework-v7-8-branch-isolation` merge commit on main via `git revert {merge_commit} -m 1`
2. Open hot-fix PR with revert
3. Restore previous `.githooks/pre-commit` content
4. Open root-cause case study within 48h documenting which kill criterion fired and why
5. Re-open this feature for redesign; bump to v8 if redesign requires structural changes

Rollback test verified pre-ship: revert simulation in `scripts/test-v7-5-pipeline.sh` extended to verify rollback restores all 12 existing write-time gates intact.

---

## 15. Acceptance gate to advance Phase 1 → Phase 2

This PRD is approvable when:
- [x] All 7 locked decisions captured and traceable to research §8.3
- [x] Success metrics table complete with T1/T2/T3 tier tags + kill criteria
- [x] Schema additions (state.json + case-study + shared config) listed
- [x] Gate predicates specified in pseudocode with exact field references
- [x] Pre-commit hook integration order documented
- [x] `make` target output formats specified
- [x] Skill extension contracts written
- [x] Test plan with explicit assertions
- [x] Acceptance criteria checklist (5 sections)
- [x] Risks + mitigations table
- [x] Review cadence + rollback plan
- [ ] **User approval of this PRD**

On user approval, advance to Phase 2 (Tasks):
- Decompose §10 acceptance criteria into ~30-40 implementable tasks
- Classify each per the v5.1 task complexity gate (E-core / P-core)
- Order by dependency graph
- Assign skill (mostly `dev` for the gate logic; `qa` for tests; `docs` for doc updates)

---

## Inputs to Tasks (Phase 2)

When advancing, Phase 2 will reference:
- This PRD (10 sections of acceptance criteria as task seeds)
- Research §8.3 locked decisions (re-link for each task)
- Test plan §9 (becomes the QA tasks)
- Schema additions §3 (becomes infrastructure tasks)
- Each `make` target §6 (becomes its own implementation task)
- Each skill extension §7 (becomes its own task with skill-specific dispatch)
