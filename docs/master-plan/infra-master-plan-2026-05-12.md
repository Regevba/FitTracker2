# FitMe Infra Master Plan & Roadmap — 2026-05-12

> **Status:** CURRENT · Opened 2026-05-12 (one day after v7.8.3 cross-repo state-sync shipped)
> **Scope:** Framework infrastructure only — write-time gates, cycle-time checks, branch-isolation tooling, cross-repo sync, measurement infrastructure, and the HADF/ORCHID research substrate that depends on it. Product features tracked separately in [`master-plan-2026-04-15.md`](master-plan-2026-04-15.md) + [`master-backlog-roadmap.md`](master-backlog-roadmap.md).
> **Purpose:** Single forward-looking source of truth for framework v7.9 promotion, v8.x candidate ranking, HADF Phase 2-bis pre-launch dependencies, and the measurement / promotion calendar through Q3 2026.
> **Supersedes:** ad-hoc v7.9 candidate lists in [`docs/superpowers/specs/2026-05-07-branch-isolation-out-of-scope.md`](../superpowers/specs/2026-05-07-branch-isolation-out-of-scope.md), [`docs/case-studies/cross-repo-state-sync-impl-case-study.md`](../case-studies/cross-repo-state-sync-impl-case-study.md), and the stress-test case study Section 99 — all are referenced and folded in here.

---

## 0. TL;DR

Three things are happening at once on the infra surface as of 2026-05-12:

1. **v7.9 is a *promotion* release, not a feature release.** The decision date is **2026-05-21**. At that gate, three currently-advisory mechanisms (`BRANCH_ISOLATION_VIOLATION`, `FEATURE_CLOSURE_COMPLETENESS`, the v7.8 mechanism A/B/C/D coverage gates) flip to enforced if 7+ days of `gate-coverage.jsonl` telemetry support the flip. No new gates are being written for v7.9 — the substantive new build work routes through v8.x.
2. **v8.x is a *feature* release with 13 candidates queued.** F1–F13 from three source sessions (roadmap stress-test 2026-05-07, branch-isolation closure 2026-05-07, v7.8.3 cutover dogfood 2026-05-11) plus 7 v8 icebox items from `branch-isolation-out-of-scope.md`. Ranking pass at 2026-05-21 Phase 9 of `framework-v7-8-branch-isolation` produces the v8.0 docket.
3. **HADF Phase 2-bis is the only active infra-adjacent research build right now.** Its 5 phases of cross-repo state-sync infrastructure dependencies are met by v7.8.3 (shipped yesterday). Sub-experiment 1 unblocks on **2026-05-23** (T+12d soak); 3 sub-experiments + cross-synthesis case study run through approximately **2026-06-07**. Spec at [`docs/superpowers/specs/2026-05-11-hadf-phase2bis-replication-design.md`](../superpowers/specs/2026-05-11-hadf-phase2bis-replication-design.md), open as **FT2 PR #306** on the current branch.

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

---

## 3. Build Docket (v8.x — 13 candidates + 7 icebox = 20 items)

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

1. **Ranking** F1–F6 + F9–F13 + V8-I1 through V8-I7 by RICE × 7-day telemetry signal strength
2. **Top-3 rule** — only top 3 by RICE enter v8.0; rest defer to v8.1
3. **Companion case study** — Phase 9 produces `framework-v7-8-branch-isolation-case-study.md` with the prioritization decision recorded in Section 99 + ranked output to `docs/superpowers/specs/2026-05-21-v8-0-docket.md` (new file)
4. **Sub-experiment with hold-out** — if telemetry suggests *zero* F-items warrant promotion (rare but possible), v8.0 ships as a pure protocol patch and v8.x deferred to v8.1

The Phase 9 task is tracked as **T29** in [`.claude/features/framework-v7-8-branch-isolation/state.json`](../../.claude/features/framework-v7-8-branch-isolation/state.json).

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
| **2026-05-12** | This document opened · `feat/hadf-phase2bis-spec` branch active · FT2 PR #306 open | — |
| **2026-05-18** | v7.9 promotion window opens (T+7d post-v7.8 ship) | [v7.8 bridge spec](../superpowers/specs/2026-05-02-framework-v7-8-and-v7-9-bridge-design.md) |
| **2026-05-21** | **v7.9 PROMOTION DECISION** + **T29 v8.0 docket ranking pass** | v7.8.1 PRD §Phase 9 |
| **2026-05-23** | HADF Phase 2-bis Sub-experiment 1 earliest launch (T+12d soak post-v7.8.3) | [Phase 2-bis spec](../superpowers/specs/2026-05-11-hadf-phase2bis-replication-design.md) §11 |
| **~2026-05-26** | Sub-exp 1 verdict + kill-criteria check | spec §10 |
| **~2026-05-27** | Sub-exp 2 launch (if Sub-exp 1 passes kill-criteria) | spec §10 |
| **~2026-05-30** | Sub-exp 2 verdict + kill-criteria check | spec §10 |
| **~2026-05-31** | Sub-exp 3 launch (if Sub-exp 2 passes kill-criteria) | spec §10 |

### 5.2 June 2026

| Date | Event | Source |
|---|---|---|
| **~2026-06-03** | Sub-exp 3 verdict + anchor-drift trip-wire | spec §10 |
| **~2026-06-04** | v7.10 promotion window opens (next 14d cycle for any v7.9 gates still advisory) | calendar |
| **~2026-06-07** | HADF Phase 2-bis cross-sub-exp synthesis case study published | spec §10 |
| **~2026-06-07** | Track 6 HADF gate activation Feature becomes eligible | Phase 2-bis closure |
| **~2026-06-18** | v8.0 build kickoff window — earliest start if top-3 v8.0 docket items chosen at 2026-05-21 | calendar (T+28d post-prioritization for spec → plan → build) |

### 5.3 Q3 2026 (provisional)

| Date | Event | Source |
|---|---|---|
| **2026-07** | v8.0 first build cycle — top-3 from F1–F13 + V8-I1–I7 | 2026-05-21 prioritization output |
| **2026-08** | v8.0 ship target — Phase 9 case study | depends on v8.0 scope |
| **2026-09** | Re-evaluation of un-shipped F-items + icebox triggers for v8.1 docket | calendar |

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
| 2026-05-21 promotion fails on insufficient telemetry | Low | Medium | Stays advisory + re-evaluates 2026-06-04 (T+14d) |
| HADF Phase 2-bis Sub-exp 1 kill-criteria fire | Medium | High (research-track halt) | Pre-registered kill criteria + 3 independent sub-experiments; failure of one does not invalidate the others |
| F12 (actionlint) ships but catches a real CI YAML error mid-promotion week | Low | Low | Pre-commit gate fires locally before push; CI side already covered by GH Actions runtime validation |
| v8.0 prioritization pass produces an empty docket | Low | Low | v8.0 ships as protocol patch; v8.1 inherits the F-series + icebox |
| DevSSD disconnect during 2026-05-21 or 2026-05-23 windows | Medium (hardware open) | High | Pre-window: ensure backup + `pmset disksleep 0`; tracked separately in [project_devssd_disconnect_remediation_2026_05_02.md](~/.claude/projects/-Volumes-DevSSD-FitTracker2/memory/project_devssd_disconnect_remediation_2026_05_02.md) |
| Cross-repo sync workflow regression on first non-FT2 fitme-story-native feature | Medium | Medium | F11 (BRANCH_ISOLATION_HISTORICAL allowlist) ships in v8.0 — interim manual reconciliation if regression hits 2026-05-12 → 2026-05-21 |

---

## 8. Open Questions

1. **v7.9 cadence going forward** — Is the T+14d advisory→enforced cadence the durable rule, or should it widen to T+21d once the framework stops accumulating new gates? Decide at 2026-05-21.
2. **F12 (actionlint) priority placement** — RICE-est is 100.0 (highest in F-series). Should it ship *outside* the v8.0 docket as a v7.9.1 patch, or wait for v8.0? Decide at 2026-05-21.
3. **v8.0 vs v8.1 split** — Top-3 rule may force F-items vs icebox items into the same shortlist. Tie-breaker: prefer F-items (already spec'd) over icebox (specs pending). Confirm at prioritization pass.
4. **HADF gate activation as separate Feature vs v8.0 entry** — Track 6 is explicitly separate at 2026-06-07 launch. Should it carry its own framework version bump (v8.x = HADF gate)? Decide at Phase 2-bis Phase 9 close.

---

## 9. References

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
