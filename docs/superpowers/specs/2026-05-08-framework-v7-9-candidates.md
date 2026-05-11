# Framework v7.9 — Candidate Mechanisms (Input from 2026-05-07 Roadmap Stress-Test)

**Status:** input doc · not yet a PRD
**Created:** 2026-05-08
**Promotion decision date:** 2026-05-21 (T+14d after v7.8.1 ship)
**Authors:** stress-test session 2026-05-07 + closure-session 2026-05-07 (memory-captured F9/F10)
**Source experiment:** `docs/case-studies/roadmap-stress-test-2026-05-07-case-study.md`
**Predecessor specs:**
- `docs/superpowers/specs/2026-05-02-framework-v7-8-and-v7-9-bridge-design.md` (joint design where v7.8 was advisory and v7.9 was scheduled to flip enforcement)
- `docs/superpowers/specs/2026-05-07-branch-isolation-out-of-scope.md` (7 v8 candidates queued from the framework-v7-8-branch-isolation feature)

---

## §1 Why this doc exists

v7.8 + v7.8.1 shipped in advisory mode with a pre-registered promotion decision on **2026-05-21** to flip the new gates to enforced once measurement-window data accumulates. Two streams feed that decision:

1. **Per-gate adoption telemetry** from `gate-coverage.jsonl` (Mechanism A) — quantitative, unlocks ≥7 days post-ship.
2. **Protocol gaps surfaced by real use** — qualitative, this doc.

The 2026-05-07 roadmap stress-test was the first multi-feature meta-experiment run under the v7.8.1 protocol. It produced 8 formal candidates in the case study (F1–F8) plus 2 closure-session observations (F9, F10) captured in agent memory but not promoted into the case study before merge.

This doc consolidates all 10 with current source-of-truth provenance so the 2026-05-21 promotion decision has them in one place.

---

## §2 Candidate inventory

### Formally promoted in case study §99 (canonical, 8 items)

| ID | Gap observed | Proposed v7.9 mechanism | Class |
|---|---|---|---|
| **F1** | `state.json::tasks[]` empty for pre-v7.6 features that DID ship; manual filesystem inspection caught all 5 already-shipped S1 tasks | New advisory check `STATE_TASKS_FILESYSTEM_DRIFT` — compares `tasks.md` IDs against `state.json::tasks[]` AND scans for filesystem evidence (e.g., `make app-store-check`-style probes per feature class) | Cycle-time advisory → enforced after calibration |
| **F2** | Roadmap research phase doesn't reality-check completed work against current state | New `/pm-workflow` Phase 0 sub-step: **"Reality-check sub-features against state.json + filesystem before scheduling."** Would have caught S2 already-complete before scheduling 3 days of work; would have re-scoped S3 to its actually-open subgoals | Workflow gate at Phase 0 |
| **F3** | Cross-feature dependency graph in multi-feature roadmaps was wrong (S4 needs S5 but roadmap put S4 first) | New `/pm-workflow` Phase 2 validation: when a roadmap is meta, run a dependency-graph cycle/mismatch check against the dependencies declared in sub-feature task lists | Workflow gate at Phase 2 |
| **F4** | Pre-v7.6 features have permanent `framework_version` drift (app-store-assets still shows v5.0 though framework is v7.8.1) | (a) update `state.json::framework_version` on every protocol-touching write, OR (b) explicit migration pass when framework versions advance | Write-time gate or one-shot migration |
| **F5** | "Roadmap reordering when reality differs" has no protocol shape; the S3 → S3-G2 narrowing was done manually | Formalize a `scope_change` event type in Tier 2.2 vocabulary; lets you re-scope a sub-feature mid-experiment without losing the original roadmap's audit trail | Vocabulary extension |
| **F6** | Phases-skipped reasons (`phases.{prd,tasks,ux_or_integration}.reason`) are unwritten LATITUDE not formalized in CLAUDE.md | Document the **B_medium tier** explicitly: "PRD/tasks/UX optional when `research.md` adequately covers them; skip with documented reason." Currently the protocol implicitly tolerates this | CLAUDE.md doc + state.json schema field |
| ~~**F7**~~ ✅ | Tier 2.2 per-phase emission was ZERO on S3-G2 because gates only fire on FT2 state.json mutations; S3-G2's commits were on fitme-story | **RESOLVED 2026-05-08 in v7.8.2 via documented exemption** — see [`2026-05-08-cross-repo-gate-asymmetry.md`](./2026-05-08-cross-repo-gate-asymmetry.md). NOT promoted to v7.9. | Documented exemption (was: cross-repo gate parity) |
| ~~**F8**~~ ✅ | Mechanism A telemetry (`gate-coverage.jsonl`) is FT2-only; cross-repo features show no telemetry on the fitme-story side | **RESOLVED 2026-05-08 in v7.8.2 via documented exemption + hook cwd-guard fix** — see [`2026-05-08-cross-repo-gate-asymmetry.md`](./2026-05-08-cross-repo-gate-asymmetry.md). NOT promoted to v7.9. | Documented exemption (was: cross-repo telemetry parity) |

### Closure-session observations (not in case study, captured 2026-05-07 evening, 2 items)

These were observed while closing the meta-feature itself, **after** the case study was finalized. They're orthogonal to F1–F8. Worth promoting if they hold up under scrutiny on 2026-05-21.

| ID | Gap observed | Proposed v7.9 mechanism | Class |
|---|---|---|---|
| **F9** | Closing the meta-feature triggered **12 violations on first commit attempt** — gate-cascade effect when many gates fire simultaneously on a single state.json transition | (a) "gate-batch" mode that runs gates in dependency order with one consolidated report instead of N sequential failures, OR (b) `phase=complete` pre-flight `make complete-feature <name>` that runs all gates in dry-run before the actual commit | Workflow ergonomics |
| **F10** | Experiment-style features have no clean way to satisfy `TASK_LIE` when tasks are intentionally deferred (not shipped). Workaround used: `status='done'` + `experiment_outcome='deferred_session_capacity'` per task | Formalize an `experiment_outcome` enum on `tasks[]`: `shipped`, `deferred_session_capacity`, `deferred_external_blocker`, `cancelled_hypothesis_refuted`, `cancelled_scope_change` — satisfies `TASK_LIE` without requiring `status: shipped` | Schema extension |

### v7.8.3 Phase 4 cutover-surfaced (added 2026-05-11, 3 items)

Captured during the v7.8.3 cross-repo-state-sync-impl Phase 4 cutover ceremony. The cutover ceremony for `3d-interactive-framework-flow-diagram` (FT2 PR #301 / fitme-story PR #88, #89, #90) required THREE attempts to fire the reverse-sync workflow end-to-end, surfacing three latent framework bugs at three different layers. Each became a v7.9 candidate.

| ID | Gap observed | Proposed v7.9 mechanism | Class |
|---|---|---|---|
| **F11** | `BRANCH_ISOLATION_HISTORICAL` cycle-time advisory flagged the reverse-sync mirror as "committed directly on main, bypassing branch isolation" — but the mirror IS legitimate (D-1 GitHub Action committed to a `reverse-sync/from-fitme-story/<sha>` branch which then merged to FT2 main via PR #301). The advisory's regex only recognizes `feature/*` and `chore/*` patterns. | Extend the advisory's branch-name allowlist to include `reverse-sync/*` (and any other v7.8.3 D-1 marker patterns). Alternative: morph the advisory to read `state_owner_sync_origin` and exempt files where the marker indicates a sync mirror. | Gate logic extension |
| **F12** | The Phase 3 reverse-sync workflow YAML had `if: ${{ secrets.FT2_REPO_TOKEN != '' }}` at the JOB level — invalid in GitHub Actions (secrets.* not allowed in job-level expressions). The workflow file failed to load with a vague "workflow file issue" error; cost ~10 min of debugging time + a hotfix PR (#89). `actionlint` would have caught this locally if it were installed. | Add `actionlint` to the pre-commit gate stack OR to `verify-local`'s CI-validation step. Catch GH Actions YAML syntax / structural / security issues before they hit `gh push`. | Pre-commit gate addition |
| **F13** | After the Phase 3 hotfix landed, `gh workflow run reverse-sync-fitme-story-to-ft2.yml` (workflow_dispatch) ran in 4s with success — but **opened no FT2 PR**. Cause: `git diff HEAD~1 HEAD -- '.claude/features/*/state.json'` doesn't see the original cutover commit (now 2 commits behind HEAD post-hotfix). Workaround: a third state.json modification (PR #90) to re-trigger via path-filter. | Add `source_commit` input to the workflow's `workflow_dispatch:` trigger so the operator can specify which commit to mirror against. OR: fall back to a full-repo scan of `state.json` files with `state_owner: "fitme-story"` that don't yet have a corresponding FT2 mirror (look up via gh API). | Workflow input + bootstrap-handling |

---

## §3 Theme grouping (for v7.9 PRD scoping)

Grouping the 10 candidates by mechanism type clarifies how many net-new code surfaces v7.9 needs:

**Theme A — Roadmap/multi-feature realism (3 items: F1, F2, F3)**
The protocol assumes roadmaps reflect current state; reality drifts. Phase 0 reality-check + Phase 2 dependency-graph check + cycle-time `STATE_TASKS_FILESYSTEM_DRIFT` advisory together close this loop.

**Theme B — Cross-repo asymmetry (2 items: F7, F8)**
Pre-commit gates and Mechanism A telemetry both live in FT2 only. Cross-repo features (UCC, ucc-passkey-auth, case-study-comparison-table) get partial coverage. Either fix or formally document.

**Theme C — Schema drift / migration (2 items: F4, F10)**
`framework_version` drift on pre-v7.6 features + missing `experiment_outcome` enum. Both are state.json schema gaps.

**Theme D — Vocabulary / latitude (2 items: F5, F6)**
`scope_change` event type for mid-experiment re-scoping + B_medium tier formalization for skipped phases. Both add to the protocol's vocabulary, no new gate code.

**Theme E — Workflow ergonomics (1 item: F9)**
Gate-cascade UX during phase transitions. Quality-of-life for closure sessions specifically.

---

## §4 Cross-references with existing v7.9 input streams

This doc is **one of three** input streams feeding the 2026-05-21 promotion decision:

1. **This doc (qualitative protocol gaps)** — 10 candidates F1–F10 from stress-test
2. **`gate-coverage.jsonl` calibration data (quantitative)** — measurement window opens 2026-05-11 (T+7d after v7.8 ship), accumulates through 2026-05-21
3. **`docs/superpowers/specs/2026-05-07-branch-isolation-out-of-scope.md`** — 7 v8 candidates queued from the framework-v7-8-branch-isolation Phase 9 prioritization

**Overlap audit:** F1, F4, F6, F7, F8 directly overlap with the 7 open questions in `framework-v7-8-branch-isolation/state.json`. The natural sequencing is: branch-isolation finishes Phase 1 research (currently `current_phase: research`), then this doc gets folded into its Phase 2 PRD as additional inputs — OR — v7.9 spawns a sibling feature `framework-v7-9` with this doc as its `research.md`. Decision deferred to user on 2026-05-21.

---

## §5 Suggested promotion classes (recommendation, not yet decided)

| Class | Candidates | Effort | Rationale |
|---|---|---|---|
| **Promote enforced in v7.9** | F2, F4, F6 | Low | F2 + F6 are workflow/doc changes; F4 is a one-shot migration. Net-new code is small. |
| **Promote advisory in v7.9 → enforced in v8.0** | F1, F3, F10 | Medium | All three need new gate code + a calibration window. Mirror the v7.8→v7.9 advisory-then-enforce cadence. |
| **Defer pending architectural decision** | F7, F8 | High | Cross-repo gate parity is a multi-week effort (fitme-story needs its own pre-commit hook layer). Worth a dedicated feature in v8.0. |
| **Quality-of-life / consider for v7.9.1** | F5, F9 | Low | F5 is a one-line vocabulary addition; F9 is a `make complete-feature` script. Both nice-to-have, neither blocking. |

---

## §6 Open questions for 2026-05-21 decision

1. **Does v7.9 spawn its own feature folder (`framework-v7-9/`)** or fold these into the existing `framework-v7-8-branch-isolation/` PRD as Phase 2 inputs?
2. **F7 + F8 (cross-repo asymmetry)** — accept the asymmetry and document, or invest in fitme-story pre-commit infrastructure?
3. **F10 (`experiment_outcome` enum)** — is this an experiment-feature-only field, or a general task-status extension that all features benefit from?
4. **Calibration data dependency** — do any of F1/F3 need the `gate-coverage.jsonl` calibration data before final scope can be set, or are they independent of the v7.8 measurement window?
5. **F9 priority** — closure-session ergonomics matter how much vs. fixing the underlying gate-cascade behavior?

---

## §7 Provenance pointers

- **Stress-test case study:** [docs/case-studies/roadmap-stress-test-2026-05-07-case-study.md](../../case-studies/roadmap-stress-test-2026-05-07-case-study.md) — F1–F8 in §99
- **Stress-test state.json:** `.claude/features/roadmap-stress-test-2026-05-07/state.json` (`current_phase: complete`)
- **Stress-test data-collection ledger:** `.claude/features/roadmap-stress-test-2026-05-07/data-collection.json` (3 hypotheses + verdicts)
- **Closure PR:** FT2 #253 squash `3cf8f71` merged 2026-05-07T19:48:35Z
- **Sub-feature shipped:** fitme-story PR #58 squash `8e595b3` (S3-G2 cross-corpus comparison table at `/case-studies/compare`)
- **F9/F10 source:** memory file `~/.claude/projects/-Volumes-DevSSD-FitTracker2/memory/project_roadmap_stress_test_2026_05_07.md` (closure-session observations not in case study)
- **v7.8.1 ship:** FT2 #244 + #245 + #246 (2026-05-07 morning)
- **v7.8 bridge ship:** FT2 #173 + #185 + #186 + #187 + #188 + #189 + #193 + #194 + #195 (2026-05-04)

---

## §8 What this doc is NOT

- **Not a PRD.** No success metrics, no kill criteria, no task breakdown. Those come after the 2026-05-21 promotion decision picks which candidates ship.
- **Not exhaustive.** Only candidates surfaced by the 2026-05-07 stress-test. Other v7.9 candidates may come from gate-coverage telemetry once it accumulates, or from the framework-v7-8-branch-isolation feature's research phase.
- **Not yet reviewed against the v7.8 bridge spec.** A few candidates (F7, F8 especially) may have been pre-empted by v7.8 design decisions worth re-checking before promotion.
