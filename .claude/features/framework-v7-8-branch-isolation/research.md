# Phase 0 Research — framework-v7-8-branch-isolation

> **Feature scope (expanded 2026-05-07):** two cooperating gates shipped as one feature.
> - **Gate A:** `BRANCH_ISOLATION_VIOLATION` — write-time + cycle-time gate that prevents agents from operating on a feature's files outside its declared worktree, plus a recoverable membrane for inter-agent awareness.
> - **Gate B:** `FEATURE_CLOSURE_COMPLETENESS` — write-time gate firing on `current_phase → complete` commits. Validates state.json ↔ case-study cross-reference completeness (every required frontmatter field present + numeric claims tier-tagged + state.json PR list cited).
>
> **Status:** Research synthesis complete. Awaiting user approval to advance to Phase 1 (PRD).
> **Inputs:** 3 prior research notes + 2026-05-07 reconcile session findings + new lifecycle event catalog.
> **Decision-ready.** No new market research required — this is framework-internal mechanics extending the existing v7.5 → v7.6 → v7.7 → v7.8 gate stack.

---

## 1. What is this solution?

A coordinated pair of write-time gates extending the v7.8 framework's enforcement layer:

**Gate A — Branch isolation membrane:**
- Pre-commit gate that rejects mutations to a feature's `state.json` / `<feature>.log.json` / declared file paths from a worktree whose branch + cwd + WorkingDirectory don't match the expected `feature/{name}` checkout (or sibling `/Volumes/DevSSD/FitTracker2-*` worktree, or main with documented exemption).
- Cycle-time mirror that audits whether each shipped feature's git history is consistent with a single isolated worktree, OR if the feature's entire lifecycle ran on `main` (a flag for retroactive exemption review).
- Pre-state.json-mutation guard for scheduled jobs (launchd plists, cron scripts) verifying they resolve to the expected worktree before any write.
- Companion: `make verify-isolation` readout listing every active feature with expected branch + worktree path + actual git/launchd state.
- Companion: extension to `superpowers:using-git-worktrees` skill that auto-detects when a feature with an active branch is being touched from main and prompts/auto-creates the worktree.
- Documentation: which jobs/skills are exempt from isolation (framework-level meta-work that legitimately runs on main: integrity-check.py edits, framework-version bumps, CLAUDE.md edits, etc.).

**Gate B — Feature-closure completeness:**
- Pre-commit gate firing on `current_phase → complete` commits. Validates that:
  - Every required case study frontmatter field is present and non-empty: `date_written` (or `date`), `dispatch_pattern`, `success_metrics` (or `primary_metric`), `kill_criteria`, `framework_version`, `work_type`, `tier_tags_present: true`
  - State.json's PR list (`tasks[].pr_number`, `phases.merge.pr_number`) is cited in the case study body or `related_prs` frontmatter
  - Numeric claims in the case study carry T1/T2/T3 tier tags inline or in `key_numbers`
- Companion readout: `make feature-completeness-audit` — system-wide scan across every state.json + case study, terminal AND in-progress, output punch list grouped by feature.
- Authoritative spec source: [`docs/architecture/feature-lifecycle-event-catalog.md`](../../../docs/architecture/feature-lifecycle-event-catalog.md) §11 (the 6th gap that Closure Completeness closes).

**Bundled because:** both gates extend the same pre-commit infrastructure (`scripts/check-state-schema.py` + `check-case-study-preflight.py`), share the v7.8 Mechanism A coverage telemetry, and both emerged from the same root cause class (silent gaps in state.json ↔ codebase ↔ case study cross-references that the existing gate stack doesn't see).

---

## 2. Why this approach?

Two distinct empirical incidents demanded two gates that share infrastructure:

### 2.1 Branch isolation — HADF Phase 2 incident (2026-04-30 → 2026-05-01)

A long-running launchd-driven fingerprint-collection job was anchored to the canonical repo path instead of an isolated `feature/` worktree. The wrapper's relative writes resolved against launchd's `WorkingDirectory`, canonical `.jsonl` data landed in the wrong tree, and the campaign required mid-flight isolation + restart + remerge.

Beyond the launchd specifics, the incident revealed **four distinct isolation failure modes** that the existing worktree pattern doesn't address (per `docs/research/2026-05-01-framework-v7-8-branch-isolation-survey.md` §1.3):

| Property | What it should give | What v7.7 gives |
|----------|--------------------|--------------------|
| Read-shared, write-isolated | Agents see each other's work; writes scoped to declared paths | Worktrees give file-tree isolation but `.claude/shared/*` and `.claude/settings.local.json` are race-able |
| Awareness without blocking | Agent B can see "Agent A is mid-flight on path X" without locking X | No mechanism. Discovery is at PR-merge time, after-the-fact |
| Conflict detection at write-time | First overlapping write triggers a coordination event, not a merge conflict | Merge-conflict detection only — runs at PR-rebase or merge — too late |
| Recoverable state | Abandoned/rolled-back work cleans up automatically | Stashes pile up; orphan worktrees survive; settings.local.json drifts persist |

PR #169's silent-pass on `created → created_at` schema migration (43 state.json files, 0% effective gate coverage) is the secondary witness: a schema change crossed agent-task boundaries that nothing in the framework currently models. Mechanism A (coverage gates) caught the same class of failure post-hoc; Mechanism C (PostToolUse:Read attribution) closes the writer-path silent-pass; Mechanism E (merge driver dedup) handles append-only ledger merges. **Branch isolation is the missing fourth mechanism for the same gap class.**

### 2.2 Closure completeness — 2026-05-07 reconcile session (today)

After v7.7's `STATE_NO_CASE_STUDY_LINK` and `CASE_STUDY_MISSING_FIELDS` gates shipped, a reconcile pass against shipped features surfaced **5 documentation-debt items detectable only post-hoc via `make documentation-debt`**:

| Feature | Missing field | Detection cost | Resolution cost |
|---------|---------------|----------------|-------------------|
| UCC | `date_written` | Post-ship readout | 30 sec edit |
| UCC | `dispatch_pattern` | Post-ship readout | 30 sec edit |
| UCC | `kill_criteria` | Post-ship readout | 5 min sourcing from PRD §13 |
| import-training-plan | `dispatch_pattern` | Post-ship readout | 30 sec edit |
| import-training-plan | `success_metrics` | Post-ship readout | 10 min sourcing from PRD §Success Metrics |
| framework-story-site | `case_study_showcase` typo | Post-ship readout | 30 sec edit |
| push-notifications-v2 | `kill_criteria` | Post-ship readout | 30 sec rename |

Total cost of post-hoc reconcile across 4 features: ~30 minutes. **Cost would be 0 if a write-time gate had blocked the closure commit.**

The v7.7 gate stack catches presence of the case-study link but NOT field completeness. Closure-completeness is the natural promotion: from advisory/readout → write-time gate.

---

## 3. Why this over alternatives?

### 3.1 Branch isolation — alternatives considered

(Compressed from `docs/research/2026-05-01-framework-v7-8-branch-isolation-survey.md` §2.1. Five clusters of prior art surveyed; top-3 primitives ranked.)

| Approach | Pros | Cons | Effort | Chosen? |
|----------|------|------|--------|---------|
| **A. LangGraph-style per-key reducers + Bazel-style action manifests** | Each shared path declares merge semantics (append/replace/max/exclusive); each agent task declares `reads:[paths]` + `writes:[paths]`; pre-dispatch coordinator detects overlapping writes | Requires path-reducer config + agent_manifest schema (already shipping in v7.8 advisory) | Medium (extends existing v7.8 schema bridges) | **YES — primary mechanism** |
| **B. MRDTs for shared append-mostly ledgers** | `measurement-adoption-history.json` + `documentation-debt.json` + per-feature logs already merge cleanly via Mechanism E (union-dedup) | State.json itself has invariants too sharp for generic CRDT (current_phase ∈ enum, timing.phases monotonic) | Already shipped (Mechanism E, v7.8 PR #189) | **YES — already shipped, extends to all append-only ledgers** |
| **C. Sapling-smartlog awareness view + jj op-log** | Live, non-blocking view of every active agent's branch + in-flight paths + minutes since last write | Requires new UI surface + op-log infrastructure | High (would be a new framework subsystem) | **NO — defer to v8.0+** |
| **D. Vercel Sandbox / Firecracker microVMs** | Process-level isolation; kernel-enforced | Overkill for cooperative agents on the same machine; adds infra complexity | Very high | NO |
| **E. Linux Landlock / macOS App Sandbox** | Kernel-enforced declarative scopes | OS-specific; doesn't translate across dev/CI environments | High | NO |
| **F. inotify/fsevents mediator** | Detect-and-broadcast pattern, lightweight, OS-portable | Detection-only; doesn't prevent the write | Low (could complement the chosen approach) | DEFER (post-MVP enhancement) |

**Chosen:** A + B (with B already shipped). Adds a `path-reducers.json` registry + extends `agent_manifest` (already a v7.8 schema bridge) to declare reads/writes. Pre-dispatch coordinator gates concurrent overlapping writes. The pre-commit hook becomes the enforcement point.

### 3.2 Closure completeness — alternatives considered

| Approach | Pros | Cons | Effort | Chosen? |
|----------|------|------|--------|---------|
| **A. Promote `make documentation-debt` from readout-time → write-time gate** | Reuses existing detection logic; field list is already canonical | Need to gate on `current_phase → complete` transition only (not every commit) | Low (one new write-time check code in `check-state-schema.py`) | **YES** |
| **B. Inline frontmatter validator in `check-case-study-preflight.py`** | Closer to the file being validated | Duplicates `documentation-debt-report.py` logic; two sources of truth for required-field list | Low | NO — share the canonical detector |
| **C. Cycle-time only (extend `integrity-check.py`)** | Lower friction during commit | Catches the gap days after ship; defeats the "write-time block" intent | Very low | NO (write-time is the point) |
| **D. CI-only (per-PR check)** | Fires on PR rather than commit | PR review is too late; the goal is to block the closure commit before push | Medium | NO |

**Chosen:** A. The detection logic in `documentation-debt-report.py` is already canonical (the dashboard uses it). Wrap it as a write-time gate in `check-state-schema.py` that fires when staged state.json sets `current_phase=complete`.

---

## 4. External sources

Three substantive research notes already exist in the repo:

| Note | Date | Scope | Pages |
|------|------|-------|-------|
| [`docs/research/2026-05-01-framework-v7-8-branch-isolation-survey.md`](../../../docs/research/2026-05-01-framework-v7-8-branch-isolation-survey.md) | 2026-05-01 | Branch-isolation membrane: 5 clusters of prior art, top-3 primitives ranked, classification question for path-reducer types | ~250 lines |
| [`docs/research/2026-05-02-framework-v7-9-implementation-safety-research.md`](../../../docs/research/2026-05-02-framework-v7-9-implementation-safety-research.md) | 2026-05-02 | v7.9 enforcement-flip safety: rollback patterns, calibration windows, kill criteria for promotion | ~200 lines |
| [`docs/research/2026-05-02-framework-mechanism-c-cache-hits-auto-instrumentation-research.md`](../../../docs/research/2026-05-02-framework-mechanism-c-cache-hits-auto-instrumentation-research.md) | 2026-05-02 | Mechanism C session-attribution design: PostToolUse:Read hook architecture, active-feature lockfile semantics | ~180 lines |

Cross-platform survey from `project_framework_v7_8_research_plan.md` (memory): GitHub/GitLab/Bazel/Nix/OpenTelemetry/Sentry isolation patterns reviewed.

**v7.8 design spec** (parent doc): [`docs/superpowers/specs/2026-05-02-framework-v7-8-and-v7-9-bridge-design.md`](../../../docs/superpowers/specs/2026-05-02-framework-v7-8-and-v7-9-bridge-design.md) — branch-isolation mentioned as v7.9 deferred; this feature pulls it forward into v7.8 advisory mode.

**Lifecycle event catalog** (today's deliverable): [`docs/architecture/feature-lifecycle-event-catalog.md`](../../../docs/architecture/feature-lifecycle-event-catalog.md) §11 explicitly identifies state↔case-study cross-reference completeness as the 6th unclosed gap and names this feature's closure-completeness gate as the closer.

---

## 5. Market examples

**N/A — framework-internal feature.** No market research required. The closest analogue across other PM frameworks:

| Framework | Closest equivalent | Note |
|-----------|--------------------|------|
| Bazel | `BUILD` action manifests + remote execution | Declared inputs/outputs; content-addressed |
| Nix | Profile + overlay | Declarative path isolation |
| Sapling (Meta) | Smartlog + stacked diffs | Awareness UX for stacked work |
| Jujutsu (jj) | Op-log per workspace | Replayable rollback |
| LangGraph | Per-key reducers | Declared merge semantics |

We are NOT adopting any of these wholesale — see §3.1 for the analysis. We extract the per-key-reducer + action-manifest pattern (LangGraph + Bazel) and graft it onto our pre-commit hook stack.

---

## 6. UI design

**N/A — `has_ui: false`.** This feature has no SwiftUI views, no Figma frames, no user-visible surface. The "user" is the developer + agent + CI pipeline. Phase 3 will be **Integration** (Phase 3b), not UX.

---

## 7. Data & demand signals

**Quantitative trigger data:**

| Signal | Date | Value | Tier |
|--------|------|-------|------|
| HADF Phase 2 worktree drift incidents | 2026-04-30 → 2026-05-01 | 1 (mid-campaign restart required) | T1 (instrumented via campaign log) |
| PR #169 silent-pass effective coverage | 2026-05-01 | 0/46 features (43 used legacy `created` key) | T1 (instrumented via Mechanism A retroactive) |
| Doc-debt items detectable only post-hoc | 2026-05-07 | 5 items across 4 features | T1 (`make documentation-debt` open count) |
| Manual reconcile cost | 2026-05-07 | ~30 min for 4 features | T2 (declared, single session) |
| Features that would have been blocked at write-time | 2026-05-07 | 4 of 4 (UCC, import-training-plan, push-notifications-v2, framework-story-site) | T1 (audit ledger) |

**Qualitative signals:**
- User-recurring pattern: "make sure that everything is updated and up to speed" → reconcile session discovers gaps post-hoc → manual fix → repeat. The closure-completeness gate eliminates the cycle.
- Inter-agent awareness gap: parallel sessions on `chore/push-notifications-v2-*` and `docs/dev-guide-v7-8-*` worked simultaneously today without conflict, but only because they touched disjoint paths. The pattern is fragile.

---

## 8. Technical feasibility

### 8.1 Dependencies

All ALREADY IN PLACE:
- ✅ Pre-commit hook orchestrator (`.githooks/pre-commit`)
- ✅ Schema-check script (`scripts/check-state-schema.py`)
- ✅ Case-study preflight script (`scripts/check-case-study-preflight.py`)
- ✅ Documentation-debt detector (`scripts/documentation-debt-report.py`) — canonical field list
- ✅ Mechanism A coverage ledger (`scripts/gate_coverage.py` + `.claude/logs/gate-coverage.jsonl`)
- ✅ Mechanism C session attribution (`scripts/observe-cache-hit.py` + `.claude/active-feature` lockfile)
- ✅ v7.8 schema bridges (`agent_manifest`, `_meta.deprecation_warnings`, `path-reducers.json`, `agent-leases.json` — all populated, awaiting v7.9 enforcement)
- ✅ `superpowers:using-git-worktrees` skill (target for the awareness-flow extension)

### 8.2 Risks

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| **Closure-completeness gate too strict; legitimate completes get blocked** | Medium | Forward-only enforcement: gate fires only on features `created_at >= ship_date`; existing terminal features grandfathered. Bypass available via `--no-verify` (cycle catches it) |
| **Branch-isolation gate breaks legitimate-on-main work (CLAUDE.md edits, framework-version bumps)** | Medium | `BRANCH_ISOLATION_EXEMPT` allowlist for known meta-paths (CLAUDE.md, scripts/integrity-check.py, .githooks/, .github/workflows/, docs/architecture/dev-guide-v1-to-v7-7.md, framework-meta state.json files) |
| **launchd plist inspection adds platform-specific code (macOS-only)** | Low | Make plist inspection optional/conditional. Linux/CI use process cwd inspection only |
| **Path-reducer config bloat (every shared file needs an entry)** | Medium | Start with the 4 known shared ledgers (measurement-adoption-history, documentation-debt, gate-coverage, _session-*.events) — these are all union-append. Add others on demand |
| **False positive on `make feature-completeness-audit` for in-progress features** | High | Phase-appropriate field list: research phase requires only schema basics; PRD phase requires cu_v2 + success_metrics; complete phase requires all closure fields |
| **Composability risk: gate fires before Mechanism A telemetry is written** | Low | Mechanism A wrapper writes telemetry AFTER gate verdict — order is `evaluate gate → record candidates/checked/skipped → return verdict`. Existing pattern in `gate_coverage.py` |

### 8.3 Locked decisions (closed 2026-05-07 by user)

All 7 open questions have locked answers. PRD authors against these directly:

**Q1 — When does `BRANCH_ISOLATION_VIOLATION` fire?** Two modes by work classification:

- **Infra/framework/hub work** → **Mode B (every commit).** The gate fires on every `git commit` whose staged files include framework-internal paths (`.githooks/*`, `.github/workflows/*`, `scripts/*`, `.claude/skills/*`, `.claude/shared/*`, `CLAUDE.md`, `docs/architecture/*`, `Makefile`, or any `.claude/features/*/state.json` whose `work_subtype` is `framework_feature` or `chore`). Auto-isolation triggered (Q2).
- **Non-infra features (user-facing UI/backend)** → **Mode C (current_phase mutations only).** The gate fires only on staged `state.json` diffs that mutate `current_phase` for that feature. Per-feature opt-out available via `state.json::isolation_opt_out: true` (Q3).

**Rationale:** infra changes have higher blast radius (they affect every feature's gates and tooling); aggressive isolation prevents parallel agents from racing on shared framework files. User features are lower-blast-radius — only the phase-transition commit matters because it's the moment the closure-completeness invariants need to hold.

**Q2 — Auto-create flow on gate fire?** **Option A — auto-invoke for both modes.**

When the gate fires (in either mode), it automatically dispatches the `superpowers:using-git-worktrees` skill to create the missing worktree using its built-in smart-directory selection (`/Volumes/DevSSD/FitTracker2-{feature}` for feature work, `/Volumes/DevSSD/FitTracker2-infra-{shortname}` for infra work). The commit is blocked. Message: "Worktree created at `{path}`. Re-stage from inside that tree." User re-stages from the new worktree; subsequent commit passes.

**Rationale:** writing the same instruction every time is friction; the skill exists for this exact purpose; smart-directory selection means the gate doesn't need to encode placement logic.

**Q3 — Exemption mechanism?** **Per-feature opt-out via `state.json::isolation_opt_out: true`.**

Default is `false` (gate fires). For features that legitimately need to operate on main (e.g., a hotfix that must touch the canonical tree directly), the user can set the flag in state.json to bypass the gate. Bypass is recorded in `state.json::isolation_opt_out_reason` (mandatory when opt-out is `true`) and audited at cycle-time.

**Override:** for infra/framework/hub work (per Q1 classification), `isolation_opt_out: true` is **ignored** — the gate fires anyway. Rationale: opting the framework out of its own enforcement defeats the gate; if framework work truly needs main, the operator can `git commit --no-verify` (recorded in Mechanism A coverage as a `manual_bypass`).

**Q4 — Detection point for launchd / scheduled-job misconfiguration?** **Primary: process cwd at write-time. Secondary: optional macOS-only plist scan as cycle-time advisory.**

- **Primary (mandatory, cross-platform):** when any script attempts to write to `.claude/features/<feature>/state.json` or `.claude/logs/<feature>.log.json`, check `os.getcwd()` against the expected worktree path (resolved from `state.json::branch` + the worktree registry). Reject on mismatch. Implemented as a Python wrapper around the write call (or via `flock_writer.py` extension).
- **Secondary (optional, macOS-only, cycle-time only):** scan `~/Library/LaunchAgents/*.plist` files. For each plist whose `ProgramArguments` references a script that writes to `.claude/features/`, verify its `WorkingDirectory` matches the expected worktree. Flagged as advisory `BRANCH_ISOLATION_LAUNCHD_DRIFT` (does not block). Skipped on Linux/CI.

**Q5 — Cycle-time audit for "all on main" history?** **Both — defense in depth.**

- **Write-time mirror (Q4 primary):** process cwd check on every state.json/log write.
- **Cycle-time scan:** every 72h, audit `.claude/features/*/state.json` against `git log --all --oneline -- path/to/feature/` to detect features whose entire git history happened on main (no `feature/{name}` branch ever existed). Flagged as advisory `BRANCH_ISOLATION_HISTORICAL` (forward-only — applies only to features with `created_at >= ship_date` of this gate; pre-existing features are grandfathered).

**Q6 — PR-list parity direction (`FEATURE_CLOSURE_COMPLETENESS`)?** **Bidirectional.**

On `current_phase=complete` transition, the gate verifies both directions:
- **state.json → case study:** every PR cited in state.json (`tasks[].pr_number`, `phases.merge.pr_number`, `tasks[].related_prs`) appears in the case study body (regex match `PR #N` / `pull/N`) OR in `related_prs` frontmatter.
- **case study → state.json:** every PR referenced in the case study (via the same regex) appears in state.json's PR list.

Mismatches block the closure commit. Override: add `pr_citation_exempt` field listing exempted PR numbers with a `reason` for each (e.g., chore PRs that the case study doesn't need to cite individually).

**Q7 — `kill_criteria_resolution` required when `kill_criteria` set?** **Yes, required, plus pre-merge-review verification.**

- **Pre-commit gate:** if `kill_criteria` is non-empty in case study frontmatter on a `current_phase=complete` commit, then `kill_criteria_resolution` must also be non-empty. Empty resolution → block.
- **Pre-merge-review check:** `/ux pre-merge-review` and `/design pre-merge-review` skills extended with a final check: if `kill_criteria` is non-empty, verify `kill_criteria_resolution` is non-empty AND substantively addresses each kill threshold (heuristic: resolution mentions at least 1 of the kill thresholds OR contains words like "not tripped" / "deferred" / "superseded"). Failure → `state.json::pre_merge_review.{ux,design}: blocked`. Phase 7 (Merge) cannot advance.

**Rationale:** kill criteria without resolution are dishonest — they signal a feature was kill-aware but never reconciled. Requiring resolution forces honest disclosure: either "thresholds passed" or "thresholds tripped, here's what we did" or "deferred to T+30d review window".

---

## 9. Proposed success metrics

**Primary metric:** Effective coverage of both gates on commits that should fire them.

| Metric | Tier | Baseline | Target | Kill criteria |
|--------|------|----------|--------|---------------|
| `BRANCH_ISOLATION_VIOLATION` effective coverage | T1 (Mechanism A ledger) | 0% (gate doesn't exist) | ≥ 95% of mutation commits sampled | < 50% after 7 days |
| `FEATURE_CLOSURE_COMPLETENESS` effective coverage | T1 (Mechanism A ledger) | 0% | 100% of `current_phase=complete` transitions | < 90% after 7 days |
| Doc-debt items detected at write-time vs cycle-time | T1 (delta in `make documentation-debt` open count) | 5 items at session start (post-hoc) | 0 items reach cycle-time gate (all caught at write) | > 1 item reaches cycle-time gate after 30 days |
| False-positive rate on closure-completeness gate | T1 (override events in pre-commit log) | N/A (gate doesn't exist) | < 5% of fires | > 20% of fires |
| `make feature-completeness-audit` runtime | T1 (wall time) | N/A | < 10s for 53 features | > 60s |

**Secondary metrics:**
- HADF-Phase-2-class incidents prevented (T2 declared, narrative — count of "would have caught this" events)
- Operator perceived friction (T3 narrative, captured in case study Phase 9)
- v7.9 promotion eligibility: gate's coverage ledger shows `checked > 0` for ≥ 7 days continuously

**Guardrail metrics (must not degrade):**
- Pre-commit hook total runtime: stays under 5s per commit (current: ~3s)
- Existing 12 write-time gates: 0 regressions (Mechanism A coverage stays ≥ current values)
- `make verify-local` total runtime: stays under 30s

**Leading indicators (week 1 post-ship):**
- At least 1 feature transitioned `current_phase → complete` and was BLOCKED then RECOVERED via the gate
- `.claude/logs/gate-coverage.jsonl` shows both new gates firing
- 0 reports of false positives blocking legitimate work

**Lagging indicators (30 / 60 / 90 day):**
- 30d: `make documentation-debt` open items stays at ≤ 2 (only cron-blocked + advisory) — no regression to 5
- 60d: 0 HADF-class incidents recurring
- 90d: v7.9 promotes both gates from advisory → enforced based on calibration data

**Review cadence:** First review 2026-05-14 (T+7d). Then weekly to 30d, then monthly to 90d.

**Kill criteria (drop the feature, roll back):**
- `BRANCH_ISOLATION_VIOLATION` blocks > 20% of legitimate-on-main commits in week 1 → revert + redesign exemption logic
- `FEATURE_CLOSURE_COMPLETENESS` blocks completes that the user explicitly authorized → revert + add per-feature opt-out
- Pre-commit hook total runtime exceeds 10s → revert (degrades dev velocity)
- Mechanism A coverage ledger shows new gates at `checked=0` for 7 consecutive days → revert (gate not effectively firing)

---

## 10. Decision

**Build both gates as one feature, ship in v7.8 advisory mode, promote to v7.9 enforced after 7+ days of Mechanism A coverage data.**

### 10.1 Rationale

- **Bundled because** the two gates share infrastructure (pre-commit hooks, Mechanism A coverage tracking, `documentation-debt-report.py` detection logic) and emerged from the same root cause class (silent gaps in cross-references the existing stack doesn't see).
- **v7.8 advisory mode first** because we just learned the v7.7 silent-pass lesson (`CACHE_HITS_EMPTY_POST_V6` shipped at 0/46 effective coverage). Mechanism A coverage telemetry calibrates promotion: don't trust a gate until its ledger says it's actually firing.
- **Closure-completeness shipped now** because the canonical detection logic already exists (`documentation-debt-report.py`); we're just promoting it from readout → write-time. Low effort, high value.
- **Branch isolation shipped now** because the v7.8 schema bridges (`agent_manifest`, `path-reducers.json`, `agent-leases.json`) already populate the necessary state; we're just adding the enforcement pre-commit logic on top.

### 10.2 Out of scope (deferred to v8.0+)

- Sapling-smartlog-style live awareness view (UI surface — too large)
- Op-log-based recoverable rollback (jj-style — needs new framework subsystem)
- Vercel Sandbox / Firecracker microVM isolation (overkill for cooperative agents)
- Filesystem-level kernel sandboxing (Landlock / macOS App Sandbox — OS-specific, doesn't translate to CI)
- Inotify/fsevents broadcast mediator (post-MVP enhancement)

### 10.3 Recommended approach

Proceed to **Phase 1 (PRD)**. The PRD will:
1. Lock the 7 open questions to specific design decisions.
2. Define exact pre-commit gate semantics (what triggers, what blocks, what allows bypass).
3. Define `BRANCH_ISOLATION_EXEMPT` allowlist initial entries.
4. Define `path-reducers.json` initial entries for the 4 known shared ledgers.
5. Define exact required-field list for `FEATURE_CLOSURE_COMPLETENESS` (sourced from `documentation-debt-report.py` constants).
6. Define cycle-time mirror semantics for both gates.
7. Define rollback procedure if kill criteria fire.

**Estimated effort:** ~3-4 hours PRD authoring + ~1 day for full PM workflow through ship.

---

## Inputs to PRD

When advancing to Phase 1, the PRD will reference:
- This research.md (synthesis)
- 3 prior research notes (deep technical analysis)
- v7.8 + v7.9 bridge spec (parent design doc)
- Lifecycle event catalog §11 (canonical statement of the 6th gap)
- 7 open questions from state.json (each gets a locked decision in the PRD)
- 8 deliverables from state.json (each gets a section in the PRD)

**No new external research required.** This is a framework-internal extension grounded in 4 weeks of empirical incident data + already-shipped infrastructure.
