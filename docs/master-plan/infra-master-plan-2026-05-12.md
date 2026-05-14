# FitMe Infra Master Plan & Roadmap — 2026-05-12

> **Status:** CURRENT · Opened 2026-05-12 (one day after v7.8.3 cross-repo state-sync shipped)
> **Scope:** Framework infrastructure only — write-time gates, cycle-time checks, branch-isolation tooling, cross-repo sync, measurement infrastructure, and the HADF/ORCHID research substrate that depends on it. Product features tracked separately in [`master-plan-2026-04-15.md`](master-plan-2026-04-15.md) + [`master-backlog-roadmap.md`](master-backlog-roadmap.md).
> **Purpose:** Single forward-looking source of truth for framework v7.9 promotion, v8.x candidate ranking, HADF Phase 2-bis pre-launch dependencies, and the measurement / promotion calendar through Q3 2026.
> **Supersedes:** ad-hoc v7.9 candidate lists in [`docs/superpowers/specs/2026-05-07-branch-isolation-out-of-scope.md`](../superpowers/specs/2026-05-07-branch-isolation-out-of-scope.md), [`docs/case-studies/cross-repo-state-sync-impl-case-study.md`](../case-studies/cross-repo-state-sync-impl-case-study.md), and the stress-test case study Section 99 — all are referenced and folded in here.

---

## 0. TL;DR

Four streams of work converge on the infra surface as of 2026-05-12 (updated end-of-day after PR #317 + PR #318):

1. **v7.9 is a *promotion* release, not a feature release.** Decision date **2026-05-21**. Currently-advisory mechanisms (`BRANCH_ISOLATION_VIOLATION` Modes B+C, `FEATURE_CLOSURE_COMPLETENESS`, the v7.8 mechanism A/C coverage gates) flip to enforced if 7+ days of `gate-coverage.jsonl` telemetry support the flip. No new gates ship at v7.9 — substantive new build routes through v8.x.
2. **v7.8.5 — pre-promotion remediation patch (NEW, added 2026-05-12).** PR #317 fixed a silent-pass bug (`BRANCH_ISOLATION_VIOLATION` Mode B unreachable when no state.json staged) and the follow-up audit surfaced 4 currently-failing tests in `test_gate_coverage.py` whose `KeyError: 'CACHE_HITS_EMPTY_POST_V6'` may indicate a hidden silent-pass left by the v7.8.3 rename to `CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT`. If true, the v7.8 → v7.9 calibration data feeding the 2026-05-21 decision is keyed wrong. Triage + fix should ship as v7.8.5 BEFORE the promotion decision; otherwise the entire quantitative input stream is corrupted. See §2.4.
3. **v8.x is a *feature* release with 18 F-candidates + 7 V8-I icebox items = 25 total queued.** F1–F18 across four source sessions (roadmap stress-test 2026-05-07, branch-isolation closure 2026-05-07, v7.8.3 cutover dogfood 2026-05-11, PR #317 + test-suite audit 2026-05-12) plus V8-I1–V8-I7 from [`branch-isolation-out-of-scope.md`](../superpowers/specs/2026-05-07-branch-isolation-out-of-scope.md). The 2026-05-12 expansion added **Theme G — Test discipline** (F14–F18) that closes the same vulnerability class PR #317 fixed. Full forward plan v7.9 → v8.2 at §3.6.
4. **HADF Phase 2-bis is the only active infra-adjacent research build right now.** Block A scaffolding SHIPPED 2026-05-12 via PR #316 (13 tasks A0–A12, 15 commits). State.json `current_phase: tasks_phase`. Block B Sub-exp 1 collection calendar-gated 2026-05-23 (T+12d v7.8.3 soak); 3 sub-experiments + cross-synthesis case study run through approximately **2026-06-07**. Track 6 HADF gate activation (currently Q3=OUT of Phase 2-bis scope) becomes eligible post Phase 2-bis closure ~2026-06-07.

**Calibration protocol added 2026-05-12 (§3.5):** every new layer of framework infrastructure now requires a documented pre-build calibration window where telemetry from the prior layer proves it fires correctly under load. This codifies the "advisory → enforced after measurement" pattern that v7.8 introduced informally.

---

## 1. v7.8.3 Anchor — What's Already Shipped

The v7.8.3 cross-repo state-sync umbrella shipped 2026-05-11 across 10 PRs in a single-day subagent-driven build. The infra surface at end-of-day was:

- **33 mechanical gates** (write-time + cycle-time, was 30 at v7.8.1)
- **5 advisory gates** (cycle-time only; advisory pending data accumulation)
- **62 features** with `state_owner ∈ {ft2, fitme-story}` backfilled
- **47 features** with full v7.8 schema bridge fields populated
- **1 reverse-sync GitHub Action** live in fitme-story (D-1)
- **1 unified PR-cite cache** (`scripts/refresh-pr-cache.py` + multi-repo `_load_pr_cache`) — 63/63 retroactive citation validation pass
- **1 cross-repo telemetry aggregator** (`src/lib/control-room/gate-coverage-aggregator.ts` in fitme-story) for `gate-coverage.jsonl` from both repos
- **1 phase-snapshot protocol** (`make snapshot-phase` → `scripts/snapshot-phase-completion.sh`) for off-SSD per-phase backups

Detailed inventory of what shipped + how the 3-attempt cutover ceremony surfaced F11/F12/F13: [`docs/case-studies/cross-repo-state-sync-impl-case-study.md`](../case-studies/cross-repo-state-sync-impl-case-study.md).

### 1.1 v7.8.4 + PR #317 + PR #318 (2026-05-12 additions)

**v7.8.4** shipped 2026-05-12 morning via PR #314 + PR #297 + companion doc-sync. Adds the `PR_CACHE_STALE` auto-refresh gate (closes the 33-finding false-positive incident from empty PR cache) + narrows `TIER_TAG_LIKELY_INCORRECT` heuristic + introduces `.claude/shared/case-study-t1-references.json` reference ledger. Single operability gate added (`PR_CACHE_STALE`); total mechanical gates 33 → 34.

**PR #317** (`fix(framework): BRANCH_ISOLATION_VIOLATION Mode B silent-pass on infra-only commits`) shipped 2026-05-12 afternoon. Reordered `scripts/check-state-schema.py:main()` so the Mode B check + gate-coverage ledger write happen BEFORE the no-state-files early-return. Added 2 regression tests that drive `main()` end-to-end. No new mechanism; closes a 5+ day silent-pass window that affected ~9 HADF Phase 2-bis Block A commits.

**PR #318** (`docs(v7-9-candidates):` F14–F18 from PR #317 + test-suite audit + external research) shipped 2026-05-12 evening. Expanded the v7.9 candidates spec from 13 to 18 items (Theme G — Test discipline). Documented pre-promotion remediation flag for cache_hits keying.

**Inventory delta:** 33 → 34 mechanical gates; 5 advisory unchanged; F-candidate count 13 → 18.

---

## 2. Promotion Docket (v7.9 → enforced, decision 2026-05-21)

These items already exist as advisory gates. The v7.9 decision is *whether to flip them to enforced* — not whether to build them. Each flip is data-gated on `gate-coverage.jsonl` telemetry showing the gate fires correctly under load with zero false positives.

### 2.1 Advisory → Enforced Calendar

| Gate | Advisory ship | Telemetry window | Earliest enforce | Source |
|---|---|---|---|---|
| `BRANCH_ISOLATION_VIOLATION` (Modes B + C) | v7.8.1 (2026-05-07) | 2026-05-07 → 2026-05-21 (14d) | **2026-05-21** | [v7.8.1 spec](../superpowers/specs/2026-05-02-framework-v7-8-and-v7-9-bridge-design.md) |
| `FEATURE_CLOSURE_COMPLETENESS` | v7.8.1 (2026-05-07) | 2026-05-07 → 2026-05-21 (14d) | **2026-05-21** | [v7.8.1 spec](../superpowers/specs/2026-05-02-framework-v7-8-and-v7-9-bridge-design.md) |
| Mechanism A coverage gates | v7.8 (2026-05-04) | 2026-05-04 → 2026-05-11 (7d) | **already met** (calibration data sufficient) | [v7.8 bridge case study](../case-studies/framework-v7-8-bridge-case-study.md) |
| Mechanism C session-attribution gate | v7.8 (2026-05-04) | 2026-05-04 → 2026-05-11 (7d) | **already met** | [v7.8 bridge case study](../case-studies/framework-v7-8-bridge-case-study.md) |
| `CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT` (V2) | v7.8 (2026-05-04) | shipped enforced 2026-05-11 | **already enforced** (v7.8.3 Phase 0, PR [#298](https://github.com/Regevba/FitTracker2/pull/298)) | v7.8.3 Phase 0 |
| Mechanism E custom merge driver (V9) | v7.8 (2026-05-04) | extended to feature logs 2026-05-11 | **already enforced** (v7.8.3 Phase 0) | v7.8.3 Phase 0 |
| `BRANCH_ISOLATION_HISTORICAL` cycle-time | v7.8.1 (2026-05-07) | indefinite (advisory by design) | **stays advisory** | T17 forward-only audit |
| `BRANCH_ISOLATION_LAUNCHD_DRIFT` cycle-time | v7.8.1 (2026-05-07) | indefinite (advisory by design) | **stays advisory** | T18 macOS-only |
| `FEATURE_CLOSURE_COMPLETENESS` cycle-time mirror | v7.8.1 (2026-05-07) | indefinite (catches `--no-verify`) | **stays advisory** | T19 bypass-catcher |

### 2.2 Promotion Decision Criteria

The 2026-05-21 decision gate requires all four to be true for each candidate gate:

1. **Coverage emitted** — `gate-coverage.jsonl` shows ≥7 days of `{candidates, checked, skipped}` rows
2. **No false positives** — every `failure` row has a matching legitimate violation in the staged diff (operator review)
3. **No silent skips** — `skipped` count tracks real reasons (out-of-scope file paths, exempt feature tags), not bugs
4. **Reversibility** — if the flip causes regression, advisory mode can be restored in <5 min via single-line CLAUDE.md edit + hook header bump

If any criterion fails for a given gate, that gate stays advisory and re-evaluates at v7.10 (next promotion window, target ~2026-06-04, T+14d post-v7.9).

### 2.3 Side-effects of v7.9 promotion

- **CLAUDE.md** — Known Mechanical Limits section gains 2 enforced gate IDs + drops 2 from the "advisory" bullet list
- **Cold-start entrypoint** — new file `.claude/entrypoints/framework-v7-9.md` mirrors `framework-v7-8-3.md` with the flipped status
- **Dev-guide** — [`docs/architecture/dev-guide-v1-to-v7-7.md`](../architecture/dev-guide-v1-to-v7-7.md) §2.4 v7.8 bridge section gains "promoted" sub-section
- **Honesty ledger** — new entry FT2-FH-002 documenting the decision rationale + any deferrals
- **Linear** — new epic FIT-72 (or next) `v7.9-promotion`, sub-issues per flipped gate

### 2.4 v7.8.5 Pre-Promotion Remediation Patch (NEW, added 2026-05-12)

**Trigger:** PR #317 root-cause analysis surfaced 4 currently-failing tests in `test_gate_coverage.py::test_cache_hits_gate_records_*` all raising `KeyError: 'CACHE_HITS_EMPTY_POST_V6'`. CLAUDE.md says v7.8.3 promoted this gate to `CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT`. The tests' KeyError on the **old** name on origin/main suggests one of three possibilities:

1. **Rename incomplete** — the gate function was renamed but the coverage-instrumentation key (passed to `coverage.candidate(GATE)`) wasn't updated in lockstep. **Symptom:** Mechanism A emissions land under the wrong key (or under no key), corrupting the 2026-05-21 calibration data input.
2. **Test fixture rot only** — tests reference a constant that was deleted; gate emissions are fine. Symptom: tests fail but production telemetry is correct.
3. **Coverage instrumentation deleted entirely** — the rename was a hard cut; `CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT` records no Mechanism A telemetry at all. Symptom: gate-coverage.jsonl has zero entries for the gate; the 2026-05-21 decision has no quantitative input for this specific candidate.

**Why this MUST ship before 2026-05-21:** the entire promotion decision rests on `gate-coverage.jsonl` showing the gate fires correctly. If the gate's Mechanism A key is wrong, the data is keyed wrong, and the criterion #1 ("Coverage emitted") cannot be evaluated honestly. This is a meta-instance of the silent-pass class PR #317 fixed.

**Triage plan (v7.8.5, single PR, ~2 hours):**

1. **Read** `scripts/check-state-schema.py` for `check_cache_hits_*` function names + `coverage.candidate(...)` keys passed in.
2. **Read** `test_gate_coverage.py::test_cache_hits_gate_records_*` for what keys the tests expect.
3. **Read** `.claude/logs/gate-coverage.jsonl` (last 7 days) — count entries by gate name. If `CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT` has zero entries, the rename was incomplete.
4. **Fix** the keying so emission ↔ test ↔ documentation all agree.
5. **Backfill** if telemetry was missed — re-run `make integrity-check` to populate the ledger with current state's coverage data so the 7-day window before 2026-05-21 starts clean.
6. **Add** a regression test that asserts the gate emits to `gate-coverage.jsonl` under the canonical key (Mechanism A check), preventing future rename-drift.

**Target ship:** 2026-05-13 → 2026-05-14 (T+7d remaining before 2026-05-21 = full window for the decision).

**Cross-references:** [`scripts/check-state-schema.py`](../../scripts/check-state-schema.py); [`scripts/tests/test_gate_coverage.py`](../../scripts/tests/test_gate_coverage.py); [PR #318](https://github.com/Regevba/FitTracker2/pull/318) §"Pre-promotion remediation"; [v7.9 candidates spec](../superpowers/specs/2026-05-08-framework-v7-9-candidates.md) F18 pre-promotion remediation callout.

---

## 3. Build Docket (v8.x — 18 F-candidates + 7 V8-I icebox = 25 items)

### 3.1 v7.9 Candidate Features (F-series) — Surfaced from Three Sources

**Source A — Roadmap stress-test (2026-05-07 session, [case study](../case-studies/roadmap-stress-test-2026-05-07-case-study.md) §99):**

| ID | Item | Class | RICE-est | Source notes |
|---|---|---|---|---|
| **F1** | `STATE_TASKS_FILESYSTEM_DRIFT` advisory — detect pre-v7.6 features with empty `tasks[]` despite shipped work | Cycle-time gate | M (R=6 I=2 C=80% E=0.5w → 19.2) | Surfaced when 5-of-10 stress-test sub-features had this drift |
| **F2** | Phase 0 sub-step: reality-check completed work against current state before scheduling | Workflow gate | M (R=8 I=2 C=80% E=0.3w → 42.7) | Roadmap had 1 step done as "TODO" |
| **F3** | Phase 2 dependency-graph cycle/mismatch check for multi-feature roadmaps | Workflow gate | M (R=6 I=2 C=60% E=0.5w → 14.4) | 1 dep-cycle caught manually post-hoc |
| **F4** | Auto-update `framework_version` on protocol-touching writes OR explicit migration pass | Write-time gate or migration | H (R=10 I=2 C=80% E=0.5w → 32.0) | 9 features had stale `framework_version` post-v7.6 |
| **F5** | Formalize `scope_change` event in Tier 2.2 vocabulary | Vocabulary extension | L (R=4 I=1 C=100% E=0.2w → 20.0) | Currently logged as `event: "note"` |
| **F6** | Document B_medium tier in CLAUDE.md: PRD/tasks/UX optional; formalize skipped-phase reasons | CLAUDE.md doc | L (R=6 I=1 C=100% E=0.2w → 30.0) | Currently ambiguous between Feature and Enhancement |

**Source B — Stress-test closure session (2026-05-07 evening):**

| ID | Item | Class | RICE-est | Source notes |
|---|---|---|---|---|
| **F9** | `make complete-feature` pre-flight OR gate-batch mode for closure UX | Workflow ergonomics | H (R=8 I=2 C=100% E=0.4w → 40.0) | 3 closure PRs required ≥3 commit retries each |
| **F10** | Formalize `experiment_outcome` enum (`shipped`/`deferred`/`cancelled`/`superseded`) on `tasks[]` | Schema extension | M (R=6 I=2 C=80% E=0.3w → 32.0) | Deferred tasks currently distinguished only by case-study prose |

**Source C — v7.8.3 cutover ceremony (2026-05-11, [case study](../case-studies/cross-repo-state-sync-impl-case-study.md)):**

| ID | Layer | Item | Class | RICE-est |
|---|---|---|---|---|
| **F11** | Cycle-time advisory | Extend `BRANCH_ISOLATION_HISTORICAL` allowlist to `reverse-sync/*` branches OR morph to read `state_owner_sync_origin` | Cycle-time gate | M (R=6 I=2 C=100% E=0.3w → 40.0) |
| **F12** | Pre-commit gate | Add `actionlint` to pre-commit stack | Write-time gate | H (R=10 I=2 C=100% E=0.2w → 100.0) |
| **F13** | Workflow bootstrap | `source_commit` input on `workflow_dispatch` OR full-repo scan fallback for unmirrored fitme-story-native state.json files | GH Actions infra | M (R=8 I=2 C=80% E=0.4w → 32.0) |

**Source D — PR #317 + test-suite audit + external research (2026-05-12 session, [v7.9 candidates spec §2](../superpowers/specs/2026-05-08-framework-v7-9-candidates.md)):**

| ID | Layer | Item | Class | RICE-est |
|---|---|---|---|---|
| **F14** | Test infrastructure | Per-gate `test_main_dispatch_<gate_id>()` requirement — every write-time gate must have ≥1 test driving `main()` end-to-end (Semgrep `rule.yml↔rule.test.yml` enforced-pairing pattern). 4 gates currently miss this (`CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT`, `CU_V2_INVALID`, `STATE_NO_CASE_STUDY_LINK`, `CASE_STUDY_MISSING_FIELDS`). | Test discipline (write-time) | H (R=10 I=3 C=80% E=0.5w → 48.0) |
| **F15** | Test infrastructure | Unit tests for 5 zero-coverage gates — `PHASE_TRANSITION_NO_LOG` + `PHASE_TRANSITION_NO_TIMING` (highest risk, guard most frequent state mutation), `BRANCH_ISOLATION_HISTORICAL`, `BRANCH_ISOLATION_LAUNCHD_DRIFT`, `PR_CACHE_STALE`. | Test discipline (Class B closure) | H (R=10 I=2 C=100% E=0.5w → 40.0) |
| **F16** | Test infrastructure | pre-commit `try-repo`-style end-to-end harness — spawn throwaway git repo, stage fixtures from `tests/fixtures/<gate-id>/{positive,negative}/`, run real `.githooks/pre-commit` via subprocess, assert each gate fires/skips per fixture. Run in CI nightly. **Highest-leverage single change** per external research synthesis. | Test infrastructure foundation | H (R=10 I=3 C=80% E=0.5w → 48.0) |
| **F17** | Telemetry materialization | Per-gate `last_fired_at` derived nightly index — `scripts/refresh-gate-last-fired.py` writes `.claude/shared/gate-last-fired.json` from `gate-coverage.jsonl`. AWS Config Rules `LastSuccessfulInvocationTime` pattern. Enables planned `GATE_COVERAGE_ZERO` meta-check at O(1) instead of O(records × gates). | Telemetry materialization | H (R=10 I=2 C=100% E=0.3w → 66.7) |
| **F18** | Test infrastructure | Nightly mutation testing on dispatcher files (`mutmut run --paths-to-mutate scripts/check-state-schema.py,scripts/check-case-study-preflight.py,scripts/integrity-check.py`). Pitest "Remove Conditionals" + "Statement Deletion" operators surface surviving mutants on early-return patterns like PR #317's. Calibrate baseline 7d, then fail PR if surviving mutants on touched files rise vs main. | Mutation testing (advisory → enforced) | M (R=8 I=2 C=60% E=0.7w → 13.7) |

**Resolved already (no v7.9 promotion needed):**

| ID | Item | Resolution |
|---|---|---|
| **F7** | Cross-repo gate parity (Tier 2.2 per-phase emission for fitme-story) | RESOLVED v7.8.2 — documented exemption in [2026-05-08-cross-repo-gate-asymmetry.md](../superpowers/specs/2026-05-08-cross-repo-gate-asymmetry.md) |
| **F8** | Mechanism A `gate-coverage.jsonl` parity for fitme-story | RESOLVED v7.8.2 — documented exemption + hook cwd-guard fix in PR #258 |

### 3.2 v8.0 Icebox (7 items from `branch-isolation-out-of-scope.md`)

Source: [`docs/superpowers/specs/2026-05-07-branch-isolation-out-of-scope.md`](../superpowers/specs/2026-05-07-branch-isolation-out-of-scope.md). Each gated on its own re-evaluation trigger; default disposition is "not promoted to v8.0 unless trigger fires."

| ID | Item | cu_v2 | Re-eval trigger | Disposition |
|---|---|---|---|---|
| **V8-I1** | Agent Smartlog UI — `/control-room/agents` live awareness + path-overlap detection | 2.2 (B_med) | ≥5 concurrent active features for 7+ days | Visibility layer; prevention is gated already |
| **V8-I2** | Op-log Replay — jj-style per-session rollback + GC | 2.9 (A_high) | ≥3 manual-cleanup incidents in 90d OR `git stash list` >5 for 30d | Recovery primitive; v7.8.3 `--no-verify` ledger is bridge |
| **V8-I3** | Vercel Sandbox / Firecracker microVM | 3.1 (A_high) | Untrusted-code-execution use case emerges | Overkill for cooperative agents |
| **V8-I4** | FS kernel sandboxing — Linux Landlock / macOS App Sandbox | 3.05 (A_high) | Regulatory mandate (HIPAA audit trail) | OS-specific; multi-tenant context needed |
| **V8-I5** | inotify/fsevents broadcast mediator | 1.9 (B_med) | ≥2 concurrent-write collisions in 60d w/ >30min reconciliation | Detection-only; additive to existing gates |
| **V8-I6** | Cross-feature dependency analysis | 2.0 (B_med) | `path-reducers.json` ≥20 entries + ≥2 conflicts surface organically | Requires path-reducer registry to mature |
| **V8-I7** | Auto-rollback on kill-criteria fire | 3.05 (A_high) | T+7d telemetry of clean firing + ≥2 manual dry-run successes | Safety verification needed |

### 3.3 v8.0 Docket Decision (2026-05-21 — T29 Phase 9 prioritization pass)

The 2026-05-21 prioritization pass at `framework-v7-8-branch-isolation` Phase 9 closure produces the final v8.0 docket by:

1. **Ranking** F1–F6 + F9–F18 + V8-I1 through V8-I7 (23 candidates after F7/F8 resolution) by RICE × 7-day telemetry signal strength
2. **Top-3-per-theme rule** (relaxed 2026-05-12 from prior "top-3 absolute") — pick top 3 by RICE within each theme so v8.0 covers breadth, not just the highest-RICE items. With 7 themes (A roadmap, B cross-repo asymmetry RESOLVED, C schema, D vocabulary, E ergonomics, F v7.8.3 cutover, G test discipline), v8.0 max docket = 18 items. Rest defer to v8.1.
3. **Companion case study** — Phase 9 produces `framework-v7-8-branch-isolation-case-study.md` with the prioritization decision recorded in Section 99 + ranked output to `docs/superpowers/specs/2026-05-21-v8-0-docket.md` (new file)
4. **Sub-experiment with hold-out** — if telemetry suggests *zero* F-items warrant promotion (rare but possible), v8.0 ships as a pure protocol patch and v8.x deferred to v8.1
5. **Test-discipline foundation precedence (added 2026-05-12)** — Theme G items (F14, F15, F16, F17, F18) have a dependency graph among themselves: F16 (try-repo harness) is foundation; F14 (per-gate dispatch tests) and F18 (mutation testing) depend on it; F15 is independent; F17 is independent. If ANY Theme G item enters v8.0, F16 MUST also enter v8.0 OR ship earlier as v7.9.1.

The Phase 9 task is tracked as **T29** in [`.claude/features/framework-v7-8-branch-isolation/state.json`](../../.claude/features/framework-v7-8-branch-isolation/state.json).

### 3.4 Theme distribution (after 2026-05-12 expansion)

| Theme | Items | Open count | Notes |
|---|---|---|---|
| **A — Roadmap/multi-feature realism** | F1, F2, F3 | 3 | Stress-test session |
| **B — Cross-repo asymmetry** | F7, F8 | 0 (both RESOLVED v7.8.2) | Documented exemption |
| **C — Schema drift / migration** | F4, F10 | 2 | `framework_version` + `experiment_outcome` enum |
| **D — Vocabulary / latitude** | F5, F6 | 2 | `scope_change` event + B_medium tier doc |
| **E — Workflow ergonomics** | F9 | 1 | `make complete-feature` pre-flight |
| **F — v7.8.3 cutover follow-up** | F11, F12, F13 | 3 | All independent |
| **G — Test discipline** (NEW 2026-05-12; expanded 2026-05-13) | F14, F15, F16, F17, F18, F19, F20 | 7 | F16 is foundation for F14 + F18; F19/F20 from analytics-observability ride on F16 harness |
| **H — Application-layer test coverage** (NEW 2026-05-13; see [`test-coverage-master-plan-2026-05-13.md`](test-coverage-master-plan-2026-05-13.md)) | T1–T16 | 16 | iOS + web + backend + AI + analytics test discipline; T6 (Web PR gate) RICE 200; T14 (platform-parity field) RICE 160; full ranking at 2026-05-21 |
| **Icebox** | V8-I1 through V8-I7 | 7 | Each gated on own re-eval trigger |
| **TOTAL** | 43 | **41 open** | F7/F8 resolved; 41 in 2026-05-21 ranking (+16 from test-coverage sub-doc) |

---

## 3.5 Calibration Protocol for New Layers (NEW, added 2026-05-12)

The PR #317 incident + the cache_hits keying-drift suspicion (§2.4) both share the same root: **a new layer of framework infrastructure was added on top of an unmeasured prior layer.** Going forward, every new infrastructure layer must walk a 5-phase calibration protocol before becoming load-bearing.

### 3.5.1 The 5 Phases

```
Phase A — Specify         (before code is written)
Phase B — Ship advisory + measure   (T+0 → T+7d)
Phase C — Calibration gate          (T+7d → T+14d)
Phase D — Promotion decision        (T+14d)
Phase E — Post-promotion validation (T+14d → T+21d)
```

| Phase | Duration | Required artifacts | Exit criteria |
|---|---|---|---|
| **A — Specify** | Pre-code | Gate spec (`function_name`, `emission_key`, dispatch site, expected skip reasons), 1 positive fixture, 1 negative fixture, regression test that asserts "this gate's `coverage.candidate(GATE)` fires when invoked under the expected input partition" | Spec + fixture + dispatch test ALL exist before any production code lands |
| **B — Ship advisory + measure** | 7 days minimum | Gate emits to `gate-coverage.jsonl` with `{candidates, checked, skipped, skip_reasons}`; PR ships with advisory-only mode (logs, doesn't block); operator checks Mechanism A at T+3d for unexpected skip_reasons | ≥7 days elapsed AND ≥1 real-world fire OR ≥3 documented legitimate skips |
| **C — Calibration gate** | 7 days | Quantitative: ≥N gate fires (N specified per gate, default N=5 for advisory→enforced; N=10 for novel mechanisms). Zero false positives confirmed by operator review of every `failure` row. All `skipped` rows match documented expected reasons. | All quantitative checks pass AND qualitative dogfood test runs cleanly |
| **D — Promotion decision** | 1 day | Decision recorded in case study + honesty ledger + CLAUDE.md update. Reversibility path tested (single-commit rollback rehearsed). | Either: flipped to enforced AND telemetry continues OR stays advisory AND re-evaluates at next T+14d cycle |
| **E — Post-promotion validation** | 7 days | Continuous telemetry monitoring; watch for false-positive incidents; trend analysis on fire frequency vs advisory baseline | 0 false-positive incidents in 7d → layer is "stable" and may have new layers built on top |

**Total minimum time per layer: 22 days** (Phase B 7d + Phase C 7d + Phase D 1d + Phase E 7d), with Phase A done up-front.

### 3.5.2 Layer Stacking Rule

**No new layer of framework infrastructure may be BUILT on top of a layer that hasn't reached Phase E.** This is the rule that codifies the PR #317 lesson — `BRANCH_ISOLATION_VIOLATION` Mode B was built (advisory) but never reached its own post-promotion validation; meanwhile we were already planning F11/F12/F13 on top of it.

Concrete application to F14–F18 (Theme G test discipline):

- F16 (try-repo harness) is foundation. It cannot ship until v7.9 promotion (~2026-05-21) clears Phase E (~2026-06-04 if successful).
- F14 (per-gate dispatch tests) requires F16 in Phase E (so the harness exists). Earliest start: ~2026-06-04.
- F18 (mutation testing) requires F16 in Phase E AND F14 in Phase B (so there are tests to mutate). Earliest start: ~2026-06-11.
- F15 (zero-coverage gate unit tests) is independent — can start any time but should still walk Phases B–E.
- F17 (last_fired_at index) is independent — can start any time; minimal calibration needed since it's a read-only derived artifact.

### 3.5.3 Data Freshness Audit (quarterly)

Every 90 days, run an audit that asserts:

1. Each gate's `coverage.candidate(GATE)` emission key matches the gate's canonical function name (CLAUDE.md gate inventory).
2. Each gate has emitted ≥1 candidate to `gate-coverage.jsonl` in the last 30 days (using F17's `last_fired_at` index for O(1) lookup).
3. Each gate's `last_fired_at` is fresher than its introduction-date + advisory-window (else: silent-pass suspect).
4. Tests in `scripts/tests/` reference current canonical names (no `KeyError` on a renamed gate).

This audit is the meta-check that would have caught the cache_hits keying drift the moment it landed instead of weeks later via test failure. Initial run: 2026-08-12 (T+90d). Recurring: 2026-11-12, 2027-02-12, etc.

### 3.5.4 Reversibility Contract

Every gate must ship with a documented reversibility path:

- **Advisory rollback** — single-line edit to gate function returning early; no hook-header changes; rollback time <2 min.
- **Enforced rollback** — single-line edit to flip enforcement boolean OR hook-header bump from "enforced" to "advisory"; rollback time <5 min.
- **Mechanism rollback** — full mechanism (e.g., A, C, E) rollback requires reverting the original PR + a `chore/rollback-mechanism-<X>` PR; rollback time <30 min.

Rollback is rehearsed at Phase D (promotion decision) for every gate. Un-rehearsed rollback paths fail Phase D.

---

## 3.6 Forward Plan: v7.9 → v8.2 (NEW, added 2026-05-12)

Mapping all 23 open candidates to version slots. Each version has explicit calibration checkpoints from §3.5.

### 3.6.1 v7.8.5 — Pre-Promotion Remediation (target 2026-05-13 → 2026-05-14)

**Scope:** cache_hits keying drift investigation + fix (§2.4). Single PR. ~2 hours wall.

**Phase A artifacts** (must exist before fix is merged):
- Regression test asserting `CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT` emits to `gate-coverage.jsonl` under the canonical key on the next invocation
- Backfill of last 7 days of synthetic gate-coverage entries if the rename left a coverage hole (so the 2026-05-21 calibration window starts clean)

**Phases B–E:** N/A for this patch (no advisory window — it's a fix to an existing enforced gate, not a new layer).

**Why it ships at 7.8.5 not 7.9.0:** v7.9 is a *promotion* release, not a feature release. This is a fix that should ship under the patch-level cadence.

### 3.6.1.A v7.8.5 Observability Layer (SHIPPED 2026-05-13)

**Scope:** ship the **operator-facing observability layer** that closes a recurring debugging-friction gap. No new write-time or cycle-time gates; no telemetry impact on v7.9 calibration data.

**Two deliverables:**

1. **Observed Patterns Catalog** at [`.claude/integrity/observed-patterns.md`](../../.claude/integrity/observed-patterns.md) — 23 gate-firing patterns (write-time + cycle-time) + 9 workflow patterns (W1–W9) documented with trigger / why-expected / signal-vs-noise rule / silence path / first-observed. CLI: `make observed-patterns`. Auto-loaded as preflight by `/pm-workflow`. **Mandatory rule:** any novel pattern surfaced during a session MUST be appended before the protocol closes the feature. Shipped via [PR #328](https://github.com/Regevba/FitTracker2/pull/328).

2. **W9 branch-drift real-time alert** at [`scripts/check-branch-drift.py`](../../scripts/check-branch-drift.py) — `PostToolUse:Bash` hook that records the current branch per session and emits a LOUD stderr warning on unexpected branch change (typically caused by another concurrent Claude session sharing the same git working directory running `git checkout`, flipping HEAD). Warning surfaced back to the assistant via tool output for real-time operator alerting. Includes a 4-step recovery playbook in the catalog. Disable: `CLAUDE_W9_DISABLE_DRIFT_CHECK=1`. Shipped via [PR #341](https://github.com/Regevba/FitTracker2/pull/341).

**Why it ships at 7.8.5 not 7.9.0:** observability/documentation surfaces don't carry the framework-version semantics of gate additions. Patches don't affect the 22-day Calibration Protocol clock.

**v7.8.5 final mechanism inventory:** 33 mechanical gates + 5 advisories + **2 observability surfaces** (catalog + W9 hook). Effective `make integrity-check` baseline unchanged (0 findings + 4 expected advisories per pattern catalog).

### 3.6.2 v7.9 — Promotion Release (decision 2026-05-21)

**Scope:** flip 6 currently-advisory mechanisms to enforced (§2.1 table).

**Calibration data required at Phase D:**
- `gate-coverage.jsonl` shows ≥7 days of `{candidates, checked, skipped}` per gate (Phase C exit)
- Operator review of every `failure` row across the 7-day window — 0 false positives required
- v7.8.5 (cache_hits keying) shipped — input data is keyed correctly

**Risk if v7.8.5 doesn't ship before 2026-05-21:** calibration data for `CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT` may be keyed wrong. The promotion decision for that specific gate must be deferred to v7.10 (~2026-06-04) until keying is verified.

**Phase E post-promotion validation runs 2026-05-21 → 2026-06-04.** During this window:
- No new gates ship
- No new test discipline work (F14, F18) starts
- Operator monitors `.claude/logs/gate-coverage.jsonl` for unexpected `failure` rows
- F17 (`last_fired_at` index) can be built in parallel since it's read-only — does not add new gates

### 3.6.3 v7.9.1 — Test Discipline Foundation + Low-Effort Wins (target 2026-06-04 → 2026-06-11)

**Scope:** ship the lowest-friction items that DON'T require waiting for v8.0 docket prioritization. All are non-gate-additive (no new gates) or telemetry-only.

| Item | Phase A status | Effort | Notes |
|---|---|---|---|
| **F16** — try-repo harness | Spec ready in PR #318 + §3.6.4 below | 0.5w | Foundation for F14 + F18 |
| **F17** — `last_fired_at` index | Spec at v7.9 candidates §2 F17 | 0.3w | Read-only derived artifact, no advisory window |
| **F2** — Phase 0 reality-check sub-step | Spec at v7.9 candidates §2 F2 | 0.3w | Workflow-only, no gate code |
| **F6** — B_medium tier doc | CLAUDE.md edit only | 0.1w | Doc-only |

**Calibration windows:** F16 + F17 walk B–E since they're new infrastructure. F2 + F6 are workflow/doc changes (single-commit reversible) and skip B–C; ship directly with `verify-local` validation.

### 3.6.4 v8.0 — Top-Per-Theme Docket (target 2026-06-18 → 2026-07-31)

**Scope:** top 3 per theme by RICE × telemetry signal strength, picked at 2026-05-21 Phase 9 prioritization. Maximum docket = 18 items; realistic docket = 6–10 items per the historical v7.x cadence.

**Theme G test discipline precedence:** F14 + F18 only ship if F16 is in Phase E (post-validation stable) by ~2026-06-11 per the layer stacking rule (§3.5.2). If F16 slips, F14 + F18 also slip.

**Expected v8.0 docket composition (provisional, decided 2026-05-21):**

| Likely-in | Likely-defer-to-v8.1 |
|---|---|
| F1 (STATE_TASKS_FILESYSTEM_DRIFT) — Theme A top | F3 — workflow gate, lower telemetry pull |
| F4 (framework_version auto-update) — Theme C top | F5 — vocabulary, ergonomics-only |
| F10 (experiment_outcome enum) — Theme C #2 | F9 — make complete-feature, depends on F14/F18 |
| F11 (BRANCH_ISOLATION_HISTORICAL allowlist) — Theme F top | F12 (actionlint) — could ship v7.9.1 if it scores highest at 2026-05-21 |
| F14 (per-gate dispatch tests) — Theme G #2 (if F16 stable) | F13 — workflow_dispatch input |
| F15 (zero-coverage gate unit tests) — Theme G #3 | F18 (mutation testing) — depends on F14 + F16 |
| **F19** (CSV_TAXONOMY_DRIFT) — Theme G #4 (RICE 80.0; added 2026-05-13 via [analytics-master-plan §11](analytics-master-plan-2026-05-13.md#11-v79-candidate-mapping-f19--f20)) | — |
| **F20** (GA4_MCP_DISCONNECTED advisory) — Theme G #5 (RICE 30.0; added 2026-05-13) | — |

**Calibration:** every v8.0 item walks Phases B–E independently. v8.0 ships as a *cumulative release* — items merge to main as each individually completes Phase E.

### 3.6.5 v8.1 — Deferred F-items + First Icebox Triggers (target 2026-08 → 2026-09)

**Scope:** items deferred from v8.0 + any V8-I icebox item whose re-eval trigger fired.

**Likely V8-I triggers by ~2026-08:**
- **V8-I1** (Agent Smartlog UI) — trigger is ≥5 concurrent active features for 7+ days. Phase 2-bis + Track 6 + v8.0 builds may push concurrent count to that threshold; check at 2026-07-31.
- **V8-I2** (Op-log Replay) — trigger is ≥3 manual-cleanup incidents in 90d OR `git stash list` >5 for 30d. Currently 2 stashes on canonical (stress-test pre-skill + import-training-plan-resume); monitor.

**Likely V8-I non-triggers by ~2026-08 (defer to v8.2 or later):**
- V8-I3 (Vercel Sandbox / Firecracker microVM) — no untrusted-code use case in the queue
- V8-I4 (FS kernel sandboxing) — no regulatory mandate
- V8-I5 (inotify/fsevents broadcast mediator) — no concurrent-write incidents tracked
- V8-I6 (Cross-feature dependency analysis) — `path-reducers.json` has <5 entries; threshold is ≥20
- V8-I7 (Auto-rollback on kill-criteria fire) — needs F1 (STATE_TASKS_FILESYSTEM_DRIFT) telemetry first

### 3.6.6 v8.2+ — Long Tail (target Q4 2026 → 2027)

**Scope:** remaining V8-I icebox items whose re-eval triggers haven't fired + new candidates surfaced from v8.0/v8.1 dogfood.

**Note:** the framework explicitly does NOT pre-commit to v8.2+ contents. Per Phase E (post-promotion validation), each release writes its own docket only after the previous release stabilizes.

### 3.6.6.A Analytics Observability Sub-doc (added 2026-05-13)

Concurrent product-tier feature `analytics-observability` opened 2026-05-13 ships across the v7.9 + v7.9.1 + v8.0 windows as a sub-doc of this plan. Full spec at [`analytics-master-plan-2026-05-13.md`](analytics-master-plan-2026-05-13.md); decisions trail at [`analytics-observability-decisions-log-2026-05-13.md`](analytics-observability-decisions-log-2026-05-13.md).

**Calibration alignment with this plan:**

| Analytics phase | Date window | Calibration phase | Why |
|---|---|---|---|
| Phase 1.A (hygiene) | 2026-05-15 → 22 | N/A (non-gate) | Backfill 56 CSV rows + wire 4 events + 21 tests |
| Phase 2 (debugger) | 2026-05-15 → 22 (parallel 1.A) | N/A (non-gate) | Local mirror + GA4 Realtime MCP poll |
| Phase 3 (dashboards) | 2026-05-21 → 06-04 (parallel **v7.9 Phase E**) | N/A (non-gate) | `/control-room/analytics` route + Looker template; honors Phase E "no new gates" rule |
| Phase 1.B (gates) | 2026-06-04 → 06-26 | Full A→B→C→D→E 22d | 2 new gates: `CSV_TAXONOMY_DRIFT` (F19) + `GA4_MCP_DISCONNECTED` (F20); ship advisory 06-04, enforced earliest 06-18, Phase E exit 06-25 |

**Why this fits this plan:** the analytics work consumes Mechanism A coverage telemetry, F16 try-repo harness (ride-on, not blocker), v7.8.2 cross-repo asymmetry policy (FT2-only Mechanism A), v7.8.3 D-1 reverse-sync (CSV mirror to fitme-story build), and v8.x docket Theme G test discipline. Treating it as a separate parallel track would duplicate those interfaces; Approach A (sub-doc) keeps the forward-looking roadmap single-source.

**F19 + F20 added to §3.6.4 v8.0 docket Theme G** (see updated table below).

### 3.6.6.B Cross-Layer Test Coverage Sub-doc (added 2026-05-13)

Concurrent test-discipline audit on 2026-05-13 surfaced that Theme G covers framework-layer tests only. The other five system layers (iOS, web, backend, AI, analytics) are under-spec'd or in some places zero-tested. Full audit + 16 T-candidates spec'd at [`test-coverage-master-plan-2026-05-13.md`](test-coverage-master-plan-2026-05-13.md).

**Headline gaps surfaced (4-agent audit):**

| Layer | Tests inventoried | Top gap |
|---|---|---|
| Framework (Python) | 133 methods / 13 files; ~30% gate coverage | cache_hits keying drift (v7.8.5 blocker — already on docket §2.4) |
| iOS (Swift) | 549 methods / 56 files | Sentry zero tests; SignInService passkey/WebAuthn zero tests; ~130-file View layer untested |
| Web (fitme-story) | 122 cases / 17 files | **Zero JS tests run on PR**; 119 React components + 27 routes untested; WebAuthn route handlers untested |
| Backend | 248 Swift methods / 22 files | SignInService zero coverage; multi-device reconciliation + key-rotation + sync cascades untested |
| AI | 75 methods / 5 files | **Zero LLM behavioral evals**; cohort prior has 3 tests; `phase2bis-prompt-set.json` has no harness |
| Analytics | 147 methods / 11 files; 81% event-count coverage | No runtime emission audit (events fired in app match CSV); ~40% parameter-combination coverage |

**T-candidate docket (Theme H) feeds 2026-05-21 prioritization pass alongside F-candidates.** Top-5 by RICE:

1. **T6** — Web PR test gate (RICE **200.0**; ~1h effort; v7.9.1 ride-along candidate or earlier)
2. **T14** — Platform-parity state.json field `platforms_tested: {ios, web, backend, ai}` (RICE **160.0**; extends FEATURE_CLOSURE_COMPLETENESS; ~1–2h)
3. **T2** — Sentry integration test pass (RICE **80.0**; closes pre-launch crash gate; mirrors push-notifications reachability discipline)
4. **T13** — `last_fired_at` extension to all gates (RICE **80.0**; depends on F17 in Phase E)
5. **T1** — Per-gate dispatch test enforcement gate `GATE_TEST_MISSING` (RICE **53.3**; depends on F14 in Phase E; closes the drift class behind cache_hits keying)

**External pattern sources** (10 systems researched; 7 patterns borrowed): Next.js test stratification, AWS Config `LastSuccessfulInvocationTime`, Stripe/GitHub `oasdiff`, Linear/Lyft platform-parity, pre-commit `try-repo` + `stages:`, Semgrep rule-test pairing, promptfoo + Anthropic golden-set LLM evals, uber/pointfreeco Swift snapshot testing, ArchDrift + shipmonk orphan-test detection. Overkill-and-rejected: Pact broker, Next.js isolated-installation-per-test, Airbnb 30K-snapshot scale, Muter Swift mutation testing.

**Calibration alignment:** all T-candidates walk the same Phase A→E protocol (§3.5). T-candidates with effort ≤ XS that extend an already-enforced gate (T14, T16) may skip Phases B–C. The sub-doc also proposes a quarterly cross-layer test audit (sub-doc §6.2) recurring at T+90d (first run 2026-08-13), mirroring §3.5.3 Data Freshness Audit but covering application-layer tests.

**Why this fits this plan:** the sub-doc consumes the same calibration protocol, the same RICE convention, the same gate-coverage telemetry, and the same 2026-05-21 prioritization pass. Treating Theme H as a separate plan would duplicate those interfaces; sub-doc keeps the forward-looking roadmap single-source.

### 3.6.7 Cumulative Mechanism Inventory by Version (projected)

| Version | Mechanical gates | Advisory | Mechanisms (A–F) | Test discipline | Source |
|---|---|---|---|---|---|
| v7.8.4 (current) | 34 | 5 | A, C, D, F advisory; B, E enforced | None | shipped |
| v7.8.5 | 34 | 5 | same | None (fix only) | target 2026-05-14 |
| v7.9 | 34 | 3 | A, C → enforced; D, F stay advisory | None | target 2026-05-21 |
| v7.9.1 | 34 | 3 | same | F16 advisory; F17 enforced (read-only) | target 2026-06-11 |
| v8.0 | 37–39 | 4–6 | same + new gates per docket | F14 advisory; F15 enforced; F16 enforced | target 2026-07-31 |
| v8.1 | 40–43 | 4–6 | + deferred items | F18 advisory → enforced | target 2026-09 |

---

## 4. HADF Phase 2-bis — Active Research Build (Special Status)

HADF Phase 2-bis is the only infra-adjacent build *currently in flight* on the main branch. It's a research-tier feature whose 5 phases of cross-repo sync infrastructure dependencies are met by v7.8.3.

### 4.1 Status

- **Branch:** `feat/hadf-phase2bis-spec` (current branch as of session open)
- **Open PR:** [FT2 #306](https://github.com/Regevba/FitTracker2/pull/306) — finalized design spec
- **Spec:** [`docs/superpowers/specs/2026-05-11-hadf-phase2bis-replication-design.md`](../superpowers/specs/2026-05-11-hadf-phase2bis-replication-design.md) — 2,919 words / 14 sections after R1–R8 audit revisions
- **Phase:** Spec complete (Phase 1 of /pm-workflow). Awaiting user review on PR #306, then writing-plans → tasks → implementation.

### 4.2 Infra Dependencies (all MET by v7.8.3)

| Dependency | v7.8.3 deliverable | Status |
|---|---|---|
| `state_owner` schema with STATE_OWNER_* gates | Phase 2 of v7.8.3 | ✅ MET 2026-05-11 |
| V2 (`CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT`) enforced | Phase 0 of v7.8.3 | ✅ MET 2026-05-11 |
| V9 (Mechanism E driver) covers `.claude/logs/<feature>.log.json` | Phase 0 of v7.8.3 | ✅ MET 2026-05-11 |
| `make snapshot-phase` for per-phase backups | Phase 0 of v7.8.3 | ✅ MET 2026-05-11 |
| `FEATURE_CLOSURE_COMPLETENESS` enforced via Phase 4 cutover protocol | v7.8.1 (advisory) → v7.8.3 cutover protocol | ✅ MET 2026-05-11 |

### 4.3 Sub-Experiment Timeline (15 days wall-clock, ~$5 total)

| Window | Sub-experiment | Description | Cost |
|---|---|---|---|
| **2026-05-23 → ~2026-05-26** | Sub-exp 1 | Cloud generalization + halfway routing test (9 endpoints, 6 providers) | ~$3–4 |
| → kill-criteria check → verdict | | | |
| **~2026-05-27 → ~2026-05-30** | Sub-exp 2 | Cloud-vs-local separability (Ollama on M2, 1 endpoint) | $0 |
| → kill-criteria check → verdict | | | |
| **~2026-05-31 → ~2026-06-03** | Sub-exp 3 | Decisive same-model routing test (AWS Bedrock haiku vs Anthropic direct, 3 endpoints) | ~$1 |
| → anchor-drift trip-wire → verdict | | | |
| **~2026-06-07** | Cross-synthesis | Cross-sub-exp synthesis case study published | — |

### 4.4 Pre-Launch Gate

Sub-experiment 1 cannot start until **all 4 mandatory architectural fixes** + **3 pre-registration JSON files** + **6-item pre-experiment safety verification ceremony** complete. Spec §6–§10 enumerate.

### 4.5 Downstream Unblock

Once Sub-experiment 3 verdict lands (~2026-06-03), the deferred **Track 6 HADF gate activation** Feature becomes eligible to start. That Feature was explicitly Q3=OUT of Phase 2-bis scope; it's a separate Feature lifecycle.

---

## 5. Roadmap — Date-Gated Master Calendar

Verbatim dates from source files. All times where unspecified are end-of-day in IDT (UTC+3).

### 5.1 May 2026

| Date | Event | Source |
|---|---|---|
| **2026-05-11** | v7.8.3 SHIPPED · V2 enforced · V9 extended to feature logs · `state_owner` backfill complete | [v7.8.3 case study](../case-studies/cross-repo-state-sync-impl-case-study.md) |
| **2026-05-11** | HADF Phase 2-bis unblock criterion MET (Q1=S1 sequencing) | v7.8.3 Phase 4 cutover |
| **2026-05-12** | This document opened · v7.8.4 SHIPPED (PR #314) · HADF Phase 2-bis Block A SHIPPED (PR #316) · PR #317 (`BRANCH_ISOLATION_VIOLATION` Mode B fix) MERGED · PR #318 (F14–F18 candidates added to v7.9 spec) OPEN | — |
| **2026-05-13** | **v7.8.5 PATCH TARGET — cache_hits keying remediation** (§2.4) | This document §2.4 (added 2026-05-12) |
| **2026-05-14** | v7.8.5 latest acceptable ship to keep full 7d calibration window before 2026-05-21 | derived |
| **2026-05-18** | v7.9 promotion window opens (T+7d post-v7.8 ship) | [v7.8 bridge spec](../superpowers/specs/2026-05-02-framework-v7-8-and-v7-9-bridge-design.md) |
| **2026-05-21** | **v7.9 PROMOTION DECISION** + **T29 v8.0 docket ranking pass** (23 candidates now, up from 13 pre-PR #318) | v7.8.1 PRD §Phase 9 |
| **2026-05-23** | HADF Phase 2-bis Sub-experiment 1 earliest launch (T+12d soak post-v7.8.3) | [Phase 2-bis spec](../superpowers/specs/2026-05-11-hadf-phase2bis-replication-design.md) §11 |
| **~2026-05-26** | Sub-exp 1 verdict + kill-criteria check | spec §10 |
| **~2026-05-27** | Sub-exp 2 launch (if Sub-exp 1 passes kill-criteria) | spec §10 |
| **~2026-05-30** | Sub-exp 2 verdict + kill-criteria check | spec §10 |
| **~2026-05-31** | Sub-exp 3 launch (if Sub-exp 2 passes kill-criteria) | spec §10 |

### 5.2 June 2026

| Date | Event | Source |
|---|---|---|
| **~2026-06-03** | Sub-exp 3 verdict + anchor-drift trip-wire | spec §10 |
| **~2026-06-04** | v7.10 promotion window opens (next 14d cycle for any v7.9 gates still advisory) · **v7.9 Phase E exit** (post-promotion validation 7d clean) | calendar + §3.5 |
| **~2026-06-04** | v7.9.1 build window opens (F16 + F17 + F2 + F6 — non-gate-additive items) per §3.6.3 | §3.6 |
| **~2026-06-07** | HADF Phase 2-bis cross-sub-exp synthesis case study published | spec §10 |
| **~2026-06-07** | Track 6 HADF gate activation Feature becomes eligible | Phase 2-bis closure |
| **~2026-06-11** | v7.9.1 latest ship target · F16 try-repo harness Phase E exit (foundation for F14 + F18) | §3.5.2 layer stacking rule |
| **~2026-06-18** | v8.0 build kickoff window — earliest start if top-per-theme docket items chosen at 2026-05-21 · F14 + F18 unblock if F16 reached Phase E | §3.6.4 |

### 5.3 Q3 2026 (provisional)

| Date | Event | Source |
|---|---|---|
| **2026-07-31** | v8.0 ship target — top-per-theme docket from F1–F18 + V8-I triggers | §3.6.4 |
| **2026-08-12** | **First Data Freshness Audit** (T+90d quarterly) — assert gate emission keys ↔ function names ↔ test names all canonical | §3.5.3 |
| **2026-08-31** | v8.1 build window opens — deferred F-items + first V8-I icebox triggers | §3.6.5 |
| **2026-09-30** | v8.1 ship target | §3.6.5 |

### 5.4 Q4 2026 + 2027 (provisional)

| Date | Event | Source |
|---|---|---|
| **2026-11-12** | Data Freshness Audit #2 (T+180d) | §3.5.3 |
| **2026-12** | v8.2 build window — long-tail V8-I icebox items per their re-eval triggers | §3.6.6 |
| **2027-02-12** | Data Freshness Audit #3 (T+270d) | §3.5.3 |
| **2027-05-08** | v7.8.2 cross-repo gate asymmetry annual re-eval (F7/F8 RESOLVED status review) | [2026-05-08 spec](../superpowers/specs/2026-05-08-cross-repo-gate-asymmetry.md) §5 |
| **2027-05-12** | Data Freshness Audit #4 (T+365d, one year of forward plan) | §3.5.3 |

---

## 6. Cross-Cutting Concerns

### 6.1 Mechanically Unclosable Gaps (carried forward from v7.6)

Recorded authoritatively in [`docs/case-studies/meta-analysis/unclosable-gaps.md`](../case-studies/meta-analysis/unclosable-gaps.md). v7.8.3 did not change this list:

1. ~~`cache_hits[]` writer-path adoption~~ — **CLOSED in v7.8.3 (V2 enforced)**
2. `cu_v2` factor *correctness* — judgment-based; presence-checked only
3. T1/T2/T3 tier-tag *correctness* — presence-checked, not value-checked
4. Tier 2.1 real-provider auth checklist — requires human-at-simulator
5. Tier 3.3 external replication — requires external operator ([GitHub issue #142](https://github.com/Regevba/FitTracker2/issues/142))

### 6.2 Cross-Repo Asymmetry (codified v7.8.2)

v7.8.2 documented that fitme-story does NOT get full FT2 gate parity. The asymmetry is intentional:

- FT2 = canonical state.json owner for product features + framework state
- fitme-story = state_owner for fitme-story-native features only (3d-interactive-framework-flow-diagram is the first)
- Mechanism A `gate-coverage.jsonl` emits in FT2 only; cross-repo aggregator (`gate-coverage-aggregator.ts`) reads both streams into the control-room UI

Re-eval annual (next 2027-05-08) or earlier if 3 signals fire. Full spec: [2026-05-08-cross-repo-gate-asymmetry.md](../superpowers/specs/2026-05-08-cross-repo-gate-asymmetry.md).

### 6.3 Concurrent Dispatch Hygiene

Parallel subagent dispatch remains **blocked at the framework layer** (F6–F9 from audit-v2 stress test). Serial dispatch is the working pattern until upstream patches land. Re-validation gate documented at [`docs/superpowers/plans/f6-f9-reproducer/proof-of-fix-tests.md`](../superpowers/plans/f6-f9-reproducer/proof-of-fix-tests.md). No v7.9 / v8.0 work depends on parallel dispatch.

### 6.4 v7.8 Mechanisms A–F — Promotion Decoupling

The six v7.8 bridge mechanisms (A coverage gates, B schema dual-read, C session attribution, D self-audit, E merge driver, F membrane status) ship/promote independently:

| Mechanism | Status as of 2026-05-12 |
|---|---|
| **A** — coverage gates | Advisory; 2026-05-21 promotion-eligible |
| **B** — schema field-rename dual-read | Already canonical (46/46 features migrated `created` → `created_at` in v7.8 PR-2) |
| **C** — PostToolUse:Read hook + session attribution | Advisory; 2026-05-21 promotion-eligible |
| **D** — pre-commit header self-audit | Advisory; stays advisory (low signal) |
| **E** — custom git merge driver | Enforced 2026-05-11 (extended to feature logs in v7.8.3) |
| **F** — membrane status advisory | Stays advisory (operator readout, not gate) |

---

## 7. Risk Register (infra-only)

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| **cache_hits keying drift corrupts 2026-05-21 calibration data** (added 2026-05-12) | Medium | High (promotion decision keyed wrong) | v7.8.5 patch ships 2026-05-13 → 14 per §2.4; full audit of gate emission ↔ function name ↔ test name alignment; regression test asserts canonical key emission |
| 2026-05-21 promotion fails on insufficient telemetry | Low | Medium | Stays advisory + re-evaluates 2026-06-04 (T+14d) |
| HADF Phase 2-bis Sub-exp 1 kill-criteria fire | Medium | High (research-track halt) | Pre-registered kill criteria + 3 independent sub-experiments; failure of one does not invalidate the others |
| F12 (actionlint) ships but catches a real CI YAML error mid-promotion week | Low | Low | Pre-commit gate fires locally before push; CI side already covered by GH Actions runtime validation |
| v8.0 prioritization pass produces an empty docket | Low | Low | v8.0 ships as protocol patch; v8.1 inherits the F-series + icebox |
| DevSSD disconnect during 2026-05-21 or 2026-05-23 windows | Medium (hardware open) | High | Pre-window: ensure backup + `pmset disksleep 0`; tracked separately in [project_devssd_disconnect_remediation_2026_05_02.md](~/.claude/projects/-Volumes-DevSSD-FitTracker2/memory/project_devssd_disconnect_remediation_2026_05_02.md) |
| Cross-repo sync workflow regression on first non-FT2 fitme-story-native feature | Medium | Medium | F11 (BRANCH_ISOLATION_HISTORICAL allowlist) ships in v8.0 — interim manual reconciliation if regression hits 2026-05-12 → 2026-05-21 |
| **Test discipline debt blocks v8.0 docket** (added 2026-05-12) | Medium | Medium | §3.5.2 layer stacking rule requires F16 (try-repo harness) at Phase E before F14 or F18 ships. If F16 slips, drop F14+F18 from v8.0 docket; don't pile on debt. |
| **Mutation testing CI cost overrun on F18 promotion** (added 2026-05-12) | Low | Low | Phase B calibration measures actual `mutmut` runtime on hosted runner; if >15min/run, scope further before flipping enforced. Defer rather than slow CI. |
| **Phase A specification rot** — gate spec exists but no fixture written, so Phase B coverage is theoretical (added 2026-05-12) | Medium | Medium | §3.5.1 Phase A exit criteria require BOTH spec AND fixture AND dispatch test. PR template + reviewer checklist added. |

---

## 8. Open Questions

1. **v7.9 cadence going forward** — Is the T+14d advisory→enforced cadence the durable rule, or should it widen to T+21d once the framework stops accumulating new gates? §3.5 codifies T+22d as the per-layer minimum (Phase B 7d + Phase C 7d + Phase D 1d + Phase E 7d) — should the project-wide cadence widen to match? Decide at 2026-05-21.
2. **F12 (actionlint) priority placement** — RICE-est is 100.0 (highest in F-series). Should it ship *outside* the v8.0 docket as a v7.9.1 patch, or wait for v8.0? §3.6.3 currently does NOT include F12 in v7.9.1 because actionlint is gate-additive (new pre-commit check) — would require full Phase B–E walk. Decide at 2026-05-21.
3. **v8.0 vs v8.1 split** — Top-per-theme rule (§3.3) may force F-items vs icebox items into the same shortlist. Tie-breaker: prefer F-items (already spec'd) over icebox (specs pending). Confirm at prioritization pass.
4. **HADF gate activation as separate Feature vs v8.0 entry** — Track 6 is explicitly separate at ~2026-06-07 launch. Should it carry its own framework version bump (v8.x = HADF gate)? Decide at Phase 2-bis Phase 9 close.
5. **(NEW 2026-05-12) v7.8.5 ship timing** — Can v7.8.5 (cache_hits keying remediation) ship 2026-05-13 OR 2026-05-14? If delayed past 2026-05-14, the gate's calibration window shrinks below 7d and that specific gate must defer to v7.10. Triage urgency on 2026-05-13 morning.
6. **(NEW 2026-05-12) F16 sequencing — ship at v7.9.1 OR bundle with v8.0?** §3.6.3 puts F16 in v7.9.1 as foundation for F14 + F18. Argument for earlier ship: harness IS the calibration tool — lets us validate F14's per-gate dispatch tests catch dispatcher bugs. Argument for bundling with v8.0: keeps v7.9 promotion atomic + reduces Phase D cycles. Decide at 2026-05-21.
7. **(NEW 2026-05-12) Phase A enforcement** — should Phase A artifacts (spec + fixture + dispatch test) be enforced via a new pre-commit gate (`GATE_SPEC_INCOMPLETE`) OR via PR-review checklist only? Mechanical enforcement matches v7.8.1 spirit; checklist-only matches v7.8.4 humility about what can be mechanically checked. Decide at 2026-06-04 v7.9.1 build start.

---

## 9. References

### Sub-docs (children of this plan)

- [`analytics-master-plan-2026-05-13.md`](analytics-master-plan-2026-05-13.md) — analytics-observability sub-doc (F19/F20 source)
- [`test-coverage-master-plan-2026-05-13.md`](test-coverage-master-plan-2026-05-13.md) — cross-layer test coverage sub-doc (T1–T16 source; Theme H)

### Source documents folded into this plan

- [`master-plan-2026-04-15.md`](master-plan-2026-04-15.md) — current product master plan (v7.8.3 banner added 2026-05-11)
- [`master-backlog-roadmap.md`](master-backlog-roadmap.md) — product RICE backlog (separate from this infra plan)
- [`docs/superpowers/specs/2026-05-02-framework-v7-8-and-v7-9-bridge-design.md`](../superpowers/specs/2026-05-02-framework-v7-8-and-v7-9-bridge-design.md) — v7.8 bridge + v7.9 design
- [`docs/superpowers/specs/2026-05-07-branch-isolation-out-of-scope.md`](../superpowers/specs/2026-05-07-branch-isolation-out-of-scope.md) — 7 v8 icebox items
- [`docs/superpowers/specs/2026-05-08-cross-repo-gate-asymmetry.md`](../superpowers/specs/2026-05-08-cross-repo-gate-asymmetry.md) — F7/F8 resolution
- [`docs/superpowers/specs/2026-05-11-cross-repo-state-sync-impl-design.md`](../superpowers/specs/2026-05-11-cross-repo-state-sync-impl-design.md) — v7.8.3 spec
- [`docs/superpowers/specs/2026-05-11-hadf-phase2bis-replication-design.md`](../superpowers/specs/2026-05-11-hadf-phase2bis-replication-design.md) — HADF Phase 2-bis spec
- [`docs/superpowers/plans/2026-05-11-cross-repo-state-sync-impl.md`](../superpowers/plans/2026-05-11-cross-repo-state-sync-impl.md) — v7.8.3 plan
- [`docs/case-studies/cross-repo-state-sync-impl-case-study.md`](../case-studies/cross-repo-state-sync-impl-case-study.md) — F11/F12/F13 surface point
- [`docs/case-studies/framework-v7-8-bridge-case-study.md`](../case-studies/framework-v7-8-bridge-case-study.md) — v7.8 mechanisms A–F
- [`docs/case-studies/framework-v7-8-branch-isolation-case-study.md`](../case-studies/framework-v7-8-branch-isolation-case-study.md) — v7.8.1 gates
- [`docs/case-studies/roadmap-stress-test-2026-05-07-case-study.md`](../case-studies/roadmap-stress-test-2026-05-07-case-study.md) §99 — F1–F10
- [`docs/case-studies/meta-analysis/unclosable-gaps.md`](../case-studies/meta-analysis/unclosable-gaps.md) — carried-forward limits

### Live state
- [`.claude/features/framework-v7-8-branch-isolation/state.json`](../../.claude/features/framework-v7-8-branch-isolation/state.json) — T29 prioritization pass
- [`.claude/shared/measurement-adoption-history.json`](../../.claude/shared/measurement-adoption-history.json) — Tier 1.1 trend data
- [`.claude/shared/documentation-debt.json`](../../.claude/shared/documentation-debt.json) — Tier 3.2 trend data
- [`.claude/logs/gate-coverage.jsonl`](../../.claude/logs/gate-coverage.jsonl) — telemetry for 2026-05-21 decision
- [`.claude/entrypoints/framework-v7-8-3.md`](../../.claude/entrypoints/framework-v7-8-3.md) — cold-start entrypoint

### External
- Linear v7.9 epic — to be created 2026-05-21 (likely FIT-72 or next)
- Notion v7.9 sub-page — to be created 2026-05-21 (under FitMe Product Hub)
- GitHub issue [#142](https://github.com/Regevba/FitTracker2/issues/142) — Tier 3.3 external replication invitation

---

## 10. Change Log for This Document

| Date | Change |
|---|---|
| 2026-05-12 | Initial creation. Consolidates v7.9 / v8.x infra surface as of v7.8.3 ship. |
| 2026-05-12 (evening) | Major expansion. PR #317 + #318 + test-suite audit + external research integrated. Added: §1.1 v7.8.4 + PR #317/#318 anchor; §2.4 v7.8.5 pre-promotion remediation patch (cache_hits keying); §3.1 Source D (F14–F18 test discipline); §3.3 top-per-theme docket rule + Theme G precedence; §3.4 theme distribution table; **§3.5 Calibration Protocol for New Layers** (5 phases, layer stacking rule, quarterly Data Freshness Audit, reversibility contract); **§3.6 Forward Plan v7.8.5 → v8.2** (versioned roadmap mapping all 23 open candidates); §5.1 + §5.2 + §5.3 + §5.4 extended calendar through 2027-05-12; §7 added 4 new risks; §8 added 3 new open questions (Q5/Q6/Q7). Doc grew 320 → ~430 lines. |
| 2026-05-13 | Analytics observability sub-doc + F19/F20 expansion. v7.8.5 SHIPPED via PR #320 (2026-05-12; cache_hits fixture rot confirmed case 2); v7.8.5.1 SHIPPED via PR #331 (4 residual test fixture rot from v7.8.3 + v7.8.4 schema migrations). Added §3.6.6.A `analytics-observability` sub-doc reference + F19/F20 to §3.6.4 v8.0 docket + Theme G expanded to 7 items in §3.4 (was 5). Total open candidates 23 → 25. 3D Framework Universe parked at PRD waypoint with `scheduled_after.signal: "analytics-observability phase=complete"`. Companion docs: [`analytics-master-plan-2026-05-13.md`](analytics-master-plan-2026-05-13.md) + [`analytics-observability-decisions-log-2026-05-13.md`](analytics-observability-decisions-log-2026-05-13.md). |
