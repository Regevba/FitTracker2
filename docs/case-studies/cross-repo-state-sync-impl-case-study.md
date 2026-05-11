---
title: "Cross-Repo State Sync (v7.8.3) Implementation"
date_written: "2026-05-11"
work_type: "Feature"
framework_version: "v7.8.3"
dispatch_pattern: "subagent-driven-tdd-sequential-phased"
success_metrics:
  - "100% of state.json files in either repo have state_owner field within 14 days of Phase 2 ship"
  - "V2 (CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT) firing on at least one production commit before HADF Phase 2-bis Sub-exp 1 launch"
  - "All 4 framework calibration targets achieved before HADF Phase 2-bis Sub-exp 1 launch"
  - "Phase 4 cutover round-trip succeeds end-to-end"
primary_metric: "Cutover round-trip end-to-end completion (binary: succeeded/failed)"
kill_criteria:
  - "Reverse-sync PRs create gate-firing storm (>10 false-positive failures in first week of Phase 3 production) → halt Phase 3"
  - "state_owner backfill triggers integrity-cycle regression on >5 features within 72h post-merge → roll back schema"
  - "V2 enforcement fires on >3 already-shipped features (false positives) → revert to advisory + 7-day calibration"
  - "HADF Phase 2-bis Sub-exp 1 launch BLOCKED until all 5 phases ship AND each phase's calibration targets are met"
kill_criteria_resolution:
  - "Reverse-sync gate-firing storm: NOT TRIGGERED. Single reverse-sync PR (#301) merged cleanly with 7/8 CI checks green; framework integrity gates all pass."
  - "62-feature backfill: NO integrity-cycle regression. PR #300 merged with 0 new findings; pm-framework/pr-integrity bot reports same baseline as main."
  - "V2 enforcement false positives: 0 fires on shipped features. Gate runs on all 63 state.json files post-Phase-2 with no false positives."
  - "HADF Phase 2-bis blocking criterion: ACTIVELY ENFORCED. Phase 4 cutover certifies framework end-to-end; HADF unblocks once Task 4.11 verification confirms."
tier_tags_present: true
case_study_link: docs/case-studies/cross-repo-state-sync-impl-case-study.md
related_prs:
  - "PR #298"
  - "PR #299"
  - "PR #300"
  - "PR #301"
  - "PR #302"
  - "[fitme-story#86]"
  - "[fitme-story#87]"
  - "[fitme-story#88]"
  - "[fitme-story#89]"
  - "[fitme-story#90]"
---

# Cross-Repo State Sync (v7.8.3) — Implementation

## TL;DR

v7.8.3 is the first release in the FitMe PM framework that spans two git repositories as a single coordinated PM-workflow Feature. It shipped 2026-05-11 via **5 PRs across 2 repos** [T1] in a single session, delivering a complete cross-repo state synchronization layer: forward-sync extensions, reverse-sync infrastructure, a `state_owner` schema marker backfilled across **62 features** [T1], and two framework gate promotions (V2 enforced, V9 extended).

The most significant deliverable is not the infrastructure — it is the Phase 4 **cutover ceremony**, which ran end-to-end certification of the full round-trip and required **3 attempts** [T1] to complete. Each attempt exposed a latent framework bug at a different layer: pre-commit (missing log + timing fields), workflow-load (invalid `secrets.*` in job-level expression), and workflow-trigger (HEAD~1 diff window broken after a hotfix lands between cutover and dispatch). All three are now documented as F11, F12, F13 in `docs/superpowers/specs/2026-05-08-framework-v7-9-candidates.md`. The framework certified itself by breaking itself first.

## Framework version progression

v7.8.3 sits between v7.8.2 and the upcoming v7.9 promotion decision (2026-05-21):

| Version | Ship date | Theme |
|---|---|---|
| v7.8 | 2026-05-04 | Advisory bridges (Mechanisms A-F) |
| v7.8.1 | 2026-05-07 | Branch isolation + feature closure gates (advisory) |
| v7.8.2 | 2026-05-08 | Cross-repo gate asymmetry — documented disposition |
| **v7.8.3** | **2026-05-11** | **Cross-repo state-sync impl + V2 enforced + V9 extended** |
| v7.9 | ~2026-05-21 | Advisory-to-enforced promotion; F11/F12/F13 remediation |

v7.8.3 reverses the v7.8.2 "no-port" disposition for fitme-story-native features. Where v7.8.2 documented that fitme-story would not get gate parity (F7/F8 closed via exemption), v7.8.3 delivers the actual reverse-sync infrastructure that makes fitme-story-native features first-class citizens in the framework.

## The 5-phase rollout

### Phase 0 — Gate promotions + test infrastructure (FT2 PR #298)

**Deliverables:**
- V2: `CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT` promoted from advisory to enforced in `scripts/check-state-schema.py` + `.githooks/pre-commit` header parity (Mechanism D)
- V9: Mechanism E custom git merge driver extended to cover `.claude/logs/<feature>.log.json` via glob pattern in `scripts/merge-driver-dedup.py` + `.gitattributes` registration
- Snapshot protocol: `scripts/snapshot-phase-completion.sh` + `make snapshot-phase` Makefile target (addresses SanDisk Extreme disconnect risk)
- Test infrastructure: new `tests/framework/` pytest package with **6 tests passing** [T1]

**Calibration target (per spec §3.5.2):**
- V2: at least 1 production fire without false positive within 7 days; soft target 10 fires across 5 features
- V9: auto-resolves at least 1 real merge-conflict on `<feature>.log.json` (synthetic test if no natural conflict in 7 days)

Phase 0 was implemented via **9 commits** [T1] on `feat/cross-repo-state-sync-phase-0` using TDD (red → green per task), then squash-merged. The V2 promotion was directly enabled by the 7-day calibration window that opened at v7.8 ship (2026-05-04): `CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT` had been advisory for 7 days with no false positives before enforcement here.

### Phase 1 — Telemetry foundations (FT2 PR #299 + fitme-story PR #86)

**Deliverables:**
- D-3: Unified cross-repo PR cite cache (`scripts/refresh-pr-cache.py`) resolving two known bugs in `BROKEN_PR_CITATION`: (B1) silent skip on cross-repo `[fitme-story#N]` short-form cites; (B2) URL-form mis-routing
- `make refresh-pr-cache` + `make validate-existing-cites` Makefile targets
- C-4: control-room cross-repo gate-coverage aggregator (`src/lib/control-room/gate-coverage-aggregator.ts`) combining both repos' Mechanism A telemetry into a time-sorted, source-tagged list
- Forward-sync extension mirroring FT2's `gate-coverage.jsonl` into fitme-story as `src/data/integrity/gate-coverage-ft2.jsonl`
- `/control-room/framework` page extended with aggregated gate-coverage count section

**Calibration achieved:** All **63 cross-repo `fitme-story#N` cite occurrences** in `docs/case-studies/` validate cleanly via `make validate-existing-cites` [T1]. The plan's original estimate of 35 occurrences was corrected to 63 via plan-adjustment A1 based on actual codebase state at Phase 1 ship time.

**Tests:** **12/12 framework tests pass** [T1] at Phase 1 completion (6 Phase 0 + 6 Phase 1 D-3 tests).

### Phase 2 — state_owner schema + 62-feature backfill (FT2 PR #300)

**Deliverables:**
- `state_owner` enum field (`"ft2"` | `"fitme-story"`) added to state.json schema
- 3 new gates: `STATE_OWNER_MISSING`, `STATE_OWNER_INVALID`, `STATE_OWNER_LOCATION_MISMATCH`
- Morphed C-5 gate exempts files carrying `state_owner_sync_origin: "fitme-story-reverse"` from `STATE_OWNER_LOCATION_MISMATCH`
- `scripts/backfill-state-owner.py` one-shot mechanical backfill script
- **62 features** backfilled to `state_owner: "ft2"` [T1]

**Calibration achieved:**
- 0 `STATE_OWNER_MISSING` findings post-backfill [T1]
- 0 `STATE_OWNER_LOCATION_MISMATCH` false positives [T1]
- **20/20 framework tests pass** [T1] (3 V2 + 2 V9 + 1 snapshot + 6 D-3 + 5 state_owner + 3 backfill)

The plan originally said 47 features; the actual count at Phase 2 ship time was 62. The backfill script auto-detected all features; the count discrepancy reflects new features shipped during the v7.8.3 execution window.

A notable self-catch during Phase 2: the first implementation of `STATE_OWNER_LOCATION_MISMATCH` used `re.search(r'/fitme-story\b', abs_path)` — the word boundary `\b` falsely matched 3 feature names that begin with `fitme-story-` (e.g., `fitme-story-design-system-p2-cleanup`). These are FT2-canonical features, not fitme-story-canonical. The pre-commit gate fired on its own Task 2.4 commit attempt and caught the bug before merge. Fixed by requiring a trailing slash `/fitme-story/` for the fitme-story-path check.

### Phase 3 — D-1 reverse-sync GitHub Action (fitme-story PR #87)

**Deliverables:**
- `.github/workflows/reverse-sync-fitme-story-to-ft2.yml` (141 lines) — triggers on push to `main` with paths matching `.claude/features/**/state.json`; detects files with `state_owner: "fitme-story"`; opens auto-PR against FT2 main with `state_owner_sync_origin: "fitme-story-reverse"` marker
- `scripts/test-reverse-sync-action.sh` — local `actionlint` + `yaml.safe_load` + `act` dry-run wrapper (each tool gracefully no-ops if not installed)
- `.claude/README.md` reverse-sync flow documentation (50 lines)
- `FT2_REPO_TOKEN` secret provisioned on `Regevba/fitme-story` (operator one-time setup, 2026-05-11T15:31:18Z)

An implementation note logged during the Phase 3 commit: the implementer caught and fixed a GH Actions injection risk by routing context expressions through `env:` vars before they reach `run:` shells. This is a defense-in-depth practice that also later proved relevant when the job-level `if: secrets.*` bug surfaced.

**Phase 3 calibration:** deferred to Phase 4 cutover (the first real fitme-story-native commit triggers the actual workflow run + PR creation).

### Phase 4 — Cutover ceremony (fitme-story PRs #88, #89, #90 + FT2 PR #301)

This is the framework certification. A real fitme-story-native feature (`3d-interactive-framework-flow-diagram`) creates a state.json with `state_owner: "fitme-story"`, the reverse-sync workflow opens an auto-PR against FT2, and the operator merges it. Forward-sync then round-trips the state.json back. The cutover required 3 attempts.

## The Phase 4 cutover dogfood narrative — 3 attempts, 3 layers

The Phase 4 ceremony exposed 3 latent framework bugs in sequence. Each surfaced at a different layer of the stack.

### Attempt 1 — Pre-commit layer (fitme-story PR #88)

The first commit attempt for `3d-interactive-framework-flow-diagram/state.json` was **rejected** by the v7.6 `PHASE_TRANSITION_NO_LOG` and `PHASE_TRANSITION_NO_TIMING` gates. The new state.json had `current_phase: research` but no corresponding log event in `3d-interactive-framework-flow-diagram.log.json` and no `timing.phases.research.started_at` block.

Both gates were ported to fitme-story in Phase B ([fitme-story#72], 2026-05-09). They fired correctly on the very first fitme-story-native state.json ever created — catching a gap that would otherwise have produced an out-of-spec feature record on first commit.

**Fix:** ran `python3 scripts/append-feature-log.py` to write the `phase_started` Tier 2.2 event, then added the timing block. Commit succeeded. PR #88 merged at 2026-05-11T15:48:15Z. This catch was logged at the time as "§9 compliance in action."

### Attempt 2 — Workflow-load layer (fitme-story PR #89)

After PR #88 merged to fitme-story main, the reverse-sync GitHub Action fired immediately — and **failed in 0 seconds** with a vague "This run likely failed because of a workflow file issue" message (run 25680885503).

Root cause: the workflow YAML had `if: ${{ vars.FT2_REPO_TOKEN_PROVISIONED == 'true' || secrets.FT2_REPO_TOKEN != '' }}` at the **job level**. GitHub Actions does not allow `secrets.*` in job-level `if:` expressions — only in step-level expressions. The workflow file fails to load entirely when this is present; the error message does not point at the offending line.

The fix: move the token-presence guard into a new first step (`token_check`) using env-var indirection (`HAS_TOKEN: ${{ secrets.FT2_REPO_TOKEN != '' }}`), which IS valid at step level. All subsequent steps gated on `if: steps.token_check.outputs.skip == 'false'`. Also added a `workflow_dispatch:` trigger so the operator could manually re-trigger after the hotfix.

**Important:** `actionlint`, the standard GitHub Actions lint tool, catches this class of error statically. This is the direct empirical basis for F12.

PR #89 merged with the fix. The operator then ran `gh workflow run reverse-sync-fitme-story-to-ft2.yml --repo Regevba/fitme-story` to re-trigger.

### Attempt 3 — Workflow-trigger layer (fitme-story PR #90)

The manual `workflow_dispatch` run completed in 4 seconds with "success" — but **opened no FT2 PR**. The workflow's change-detection step uses `git diff HEAD~1 HEAD -- '.claude/features/*/state.json'` to find modified state.json files. When triggered via `workflow_dispatch`, HEAD points to the hotfix commit (PR #89), not the cutover commit (PR #88). HEAD~1 is therefore the commit before the hotfix — and `git diff HEAD~1 HEAD` sees only the workflow YAML change, not the state.json change that is now 2 commits behind HEAD.

**Fix:** a third PR (#90) that adds a real state.json field (`cutover_attempts` documentation) on a path-filter-matching commit. When this PR merges to main, the workflow triggers via the standard push trigger and `git diff HEAD~1 HEAD` correctly sees the state.json change in that commit. The workflow fires, detects `state_owner: "fitme-story"`, opens FT2 PR #301 with the `state_owner_sync_origin: "fitme-story-reverse"` marker.

Operator merges FT2 PR #301. The C-5 gate in FT2 correctly exempts the file via the sync_origin marker. **Round-trip complete.**

The `workflow_dispatch` bootstrap path is now documented as needing a `source_commit` input OR a full-repo scan of unmirrored fitme-story-native state.json files. Both are deferred to v7.9 (F13).

## F11, F12, F13 — v7.9 candidates surfaced

The 3 attempts produced 3 new entries in `docs/superpowers/specs/2026-05-08-framework-v7-9-candidates.md` §2:

| ID | Layer | Gap observed | Proposed mechanism |
|---|---|---|---|
| **F11** | Cycle-time advisory | `BRANCH_ISOLATION_HISTORICAL` flagged the reverse-sync mirror (merged via auto-PR from a `reverse-sync/*` branch) as "committed directly on main, bypassing branch isolation" — false positive | Extend advisory's branch-name allowlist to include `reverse-sync/*` OR morph the advisory to read `state_owner_sync_origin` and exempt sync-mirror files |
| **F12** | Workflow-load | Reverse-sync YAML had `if: secrets.* != ''` at job level (invalid in GH Actions); vague "workflow file issue" error cost ~10 min debugging + a hotfix PR | Add `actionlint` to pre-commit gate stack OR to `verify-local`'s CI-validation step |
| **F13** | Workflow-trigger | `workflow_dispatch` HEAD~1 diff window breaks when a hotfix lands between cutover commit and dispatch; workaround required a third state.json modification | Add `source_commit` input to `workflow_dispatch` trigger OR implement full-repo scan of unmirrored fitme-story-native state.json files |

F11/F12/F13 join the existing 10 candidates (F1-F10 from the 2026-05-07 roadmap stress-test) ahead of the 2026-05-21 v7.9 promotion decision. Theme grouping: F11 falls under Theme A (gate logic extension), F12 under Theme F (new pre-commit tool integration), F13 under Theme G (workflow bootstrap handling).

## Calibration evidence

| Metric | Value | Tier |
|---|---|---|
| PRs shipped across 2 repos | 5 FT2 (PR #298, #299, #300, #301, #302) + 5 fitme-story (PR #86, #87, #88, #89, #90) = **10 total** | T1 — git history |
| Cross-repo cite occurrences validated | **63/63** via `make validate-existing-cites` | T1 — script output |
| Features backfilled with state_owner | **62/62** via `scripts/backfill-state-owner.py` | T1 — script output |
| Framework tests passing at Phase 2 | **20/20** (3 V2 + 2 V9 + 1 snapshot + 6 D-3 + 5 state_owner + 3 backfill) | T1 — pytest output |
| Phase 4 cutover attempts | **3** (pre-commit, workflow-load, workflow-trigger) | T1 — workflow run history |
| STATE_OWNER_MISSING findings post-backfill | **0** | T1 — schema-check output |
| STATE_OWNER_LOCATION_MISMATCH false positives | **0** | T1 — schema-check output |
| V2 enforcement false positives | **0** fires on shipped features | T1 — gate-coverage.jsonl |
| Integrity-cycle regression (72h post-Phase-2) | **0** new findings | T1 — integrity-check output |
| PRs carrying state_owner_sync_origin marker | **1** (FT2 PR #301) — morphed C-5 gate exempts it correctly | T1 — git diff |
| Phase 0 commits (TDD-structured) | **9** | T1 — git log |
| Phase 1 commits | **3** FT2 + 3 fitme-story | T1 — git log |
| Phase 2 commits | **5** | T1 — git log |
| Phase 3 commits | **3** | T1 — git log |

## Methodology notes — 3 dogfooding catches at 3 layers

v7.8.3 is the first Feature in the framework's history where the delivery process itself was a test of the new infrastructure. The PRD (spec §9, "Dogfooding compliance") required that Phase 4 exercise the full round-trip. What the spec did not predict was the density of failures: 3 catches before the first successful end-to-end fire.

Each catch demonstrates a different enforcement layer working:

1. **Pre-commit layer** — The v7.6 timing + log gates ported to fitme-story via Phase B ([fitme-story#72]) fired correctly on the very first fitme-story-native state.json ever committed. A write-time gate enforced schema discipline before the file reached the remote.

2. **Workflow-load layer** — The Phase 3 workflow YAML had a structural YAML/GH-Actions issue that is invisible to `python3 yaml.safe_load` (which only checks YAML syntax, not GH Actions semantics). The failure was only detectable by a GH-Actions-aware linter (`actionlint`) or by actually running the workflow. This is a category of error the existing pre-commit stack cannot catch today.

3. **Workflow-trigger layer** — The dispatch trigger semantics bug (`git diff HEAD~1 HEAD` after a hotfix) represents a class of error that is invisible to any static analysis: it requires understanding the state of the branch at runtime relative to an intervening commit. This is inherently an integration-test problem, not a pre-commit problem.

The pattern is significant: pre-commit gates catch write-time schema errors; they cannot catch runtime workflow semantics. F12 (add `actionlint`) is achievable. F13 (fix dispatch bootstrap) requires runtime input.

## Self-catch during Phase 2

The `STATE_OWNER_LOCATION_MISMATCH` gate caught its own bug during implementation. The first attempt's regex `re.search(r'/fitme-story\b', abs_path)` used a word boundary `\b` that matched 3 FT2-canonical feature names beginning with `fitme-story-` (e.g., `fitme-story-design-system-p2-cleanup`). These are FT2 features, not fitme-story-canonical. The gate fired on its own Task 2.4 commit attempt.

This is the same class of catch that Phase 4 demonstrated at the workflow layer: the enforcement infrastructure fires on itself. A system that can surface its own mis-classifications on its own commits is operating as designed.

## What this unlocks

**HADF Phase 2-bis Sub-exp 1** — the HADF Phase 2-bis campaign has been explicitly gated on v7.8.3 completion since the 2026-05-11 brainstorm session. The gate is: all 5 phases ship AND each phase's calibration targets are met. Phase 4 cutover round-trip is the final gate. With PR #301 merged and the round-trip certified, the framework status is green for HADF resumption once Task 4.11 (post-merge verification and final state.json closure) confirms.

**Track 6 HADF gate activation** — the HADF Phase 2-bis brainstorm designated V2 enforcement (shipped in Phase 0) as a prerequisite for Track 6. With V2 enforced and zero false positives observed, Track 6 is unblocked from the framework side.

**Future fitme-story-native features** — any feature whose primary codebase is fitme-story can now follow the established pattern: create state.json with `state_owner: "fitme-story"`, push to fitme-story main, the reverse-sync workflow opens an auto-PR against FT2, operator merges, forward-sync round-trips back. The `3d-interactive-framework-flow-diagram` feature (currently at `current_phase: research`) is the first to use this path.

**v7.9 promotion decision (2026-05-21)** — F11, F12, F13 are input to the promotion decision alongside the existing F1-F10 candidates and the gate-coverage.jsonl calibration data accumulating since 2026-05-11.

## Provenance pointers

- **Implementation spec:** [`docs/superpowers/specs/2026-05-11-cross-repo-state-sync-impl-design.md`](../superpowers/specs/2026-05-11-cross-repo-state-sync-impl-design.md) (11 sections, ~6K words)
- **Phase C contract (predecessor):** [`docs/superpowers/specs/2026-05-09-cross-repo-state-sync.md`](../superpowers/specs/2026-05-09-cross-repo-state-sync.md)
- **v7.8.2 cross-repo asymmetry disposition:** [`docs/superpowers/specs/2026-05-08-cross-repo-gate-asymmetry.md`](../superpowers/specs/2026-05-08-cross-repo-gate-asymmetry.md)
- **v7.9 candidates (F11/F12/F13 added):** [`docs/superpowers/specs/2026-05-08-framework-v7-9-candidates.md`](../superpowers/specs/2026-05-08-framework-v7-9-candidates.md)
- **Brainstorm artifact (Phase C decisions):** `.claude/projects/-Volumes-DevSSD-FitTracker2/memory/project_phase_c_brainstorm_2026_05_11.md`
- **HADF Phase 2-bis brainstorm (paused pending this Feature):** `.claude/projects/-Volumes-DevSSD-FitTracker2/memory/project_phase2bis_brainstorm_paused_2026_05_11.md`
- **Off-SSD backup (pre-Phase-0 pause):** `~/Documents/FitTracker2-backups/2026-05-11-v7.8.3-execution-pause-task-0.2-complete/`
- **Predecessor case study (v7.8.1 branch isolation):** [`docs/case-studies/framework-v7-8-branch-isolation-case-study.md`](framework-v7-8-branch-isolation-case-study.md)
- **Predecessor case study (v7.8 bridge):** [`docs/case-studies/framework-v7-8-bridge-case-study.md`](framework-v7-8-bridge-case-study.md)
