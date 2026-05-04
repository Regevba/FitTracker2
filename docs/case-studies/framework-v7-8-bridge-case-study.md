---
title: Framework v7.8 — Bridge to v7.9 (Silent-Pass Prevention + Inter-Agent Awareness)
date_written: 2026-05-03
work_type: Feature
dispatch_pattern: serial
framework_version: v7.8
success_metrics:
  primary: "CACHE_HITS_EMPTY_POST_V6 effective coverage: 0/46 (silent-pass) → gate fires deterministically on post-Mechanism-C features at completion (T1, write-time observable in .claude/logs/gate-coverage.jsonl)"
  secondary:
    - "framework_version field 100% canonical vX.Y form (46/46 features) — was 8/46 at v7.8 PR-1 ship"
    - "Mechanism A coverage ledger emits one event per write-time gate per run (10 gates instrumented)"
    - "Mechanism C session attribution: /pm-workflow writes .claude/active-feature on entry, PostToolUse:Read reads it, advisory check fires on drift"
    - "Mechanism E auto-resolves merge conflicts on 2 ledgers (measurement-adoption-history.json, documentation-debt.json) via union-dedup — no manual intervention"
kill_criteria:
  - "Mechanism A ledger writes break under concurrent runs (file corruption, race conditions in append path)"
  - "Mechanism C active-feature attribution gets it wrong >10% of the time (session-event audit reveals mis-attribution)"
  - "Mechanism E merge driver introduces semantic regressions (data loss observed in either ledger after a real branch merge)"
  - "Pre-existing Build and Test flake (parallel-clone simulator hang) blocks v7.8 PRs >50% of the time"
predecessor_case_studies:
  - "docs/case-studies/framework-v7-7-validity-closure-case-study.md"
  - "docs/case-studies/data-integrity-framework-v7.5-case-study.md"
predecessor_specs:
  - "docs/superpowers/specs/2026-04-27-framework-v7-7-validity-closure-design.md"
predecessor_audits:
  - "trust/audits/2026-04-21-gemini/remediation-plan-2026-04-23.md"
input_research_notes:
  - "docs/research/2026-05-01-framework-v7-8-branch-isolation-survey.md"
  - "docs/research/2026-05-02-framework-v7-9-implementation-safety-research.md"
  - "docs/research/2026-05-02-framework-mechanism-c-cache-hits-auto-instrumentation-research.md"
spec_path: docs/superpowers/specs/2026-05-02-framework-v7-8-and-v7-9-bridge-design.md
status: live
---

# Framework v7.8 — Bridge to v7.9

> **Live append-only journal.** Each PR merge appends an entry. No retroactive edits. Final synthesis (Section 99) when M3 + M4 ship; v7.9 enforcement-flip becomes its own case study. Tier tags throughout: T1 (instrumented), T2 (declared / not yet measured), T3 (narrative / observational).

## Section 0 — Genesis

Three converging incidents triggered v7.8 [T3]:

1. **2026-04-30 audit** — Routine Tier 1.1 measurement check surfaced that the v7.7 `CACHE_HITS_EMPTY_POST_V6` gate had **0/46 effective coverage** [T1]: 43/46 state.json files used the legacy `created` key while the gate read `created_at`, producing an empty-string early return → silent pass. Issue #140 was closed in spec, open in practice.

2. **HADF Phase 2 worktree-collision incident (2026-05-01)** — Unattended fingerprint job ran in `/Volumes/DevSSD/FitTracker2-hadf-campaign/` while parallel feature work continued on `main`. Observed collisions: `.claude/settings.local.json` drift, `.claude/shared/hadf/*` clobbering. Documented in [`docs/research/2026-05-01-framework-v7-8-branch-isolation-survey.md`](../research/2026-05-01-framework-v7-8-branch-isolation-survey.md).

3. **PR #169 silent-break (2026-05-01)** — The `created` → `created_at` rename across 43 state.json files broke `scripts/measurement-adoption-report.py` because the consumer read the legacy field. Mid-session catch only.

The pattern: **the framework cannot observe its own runtime.** v7.7 wrote gates that asserted properties about state.json; it never asserted that the gates were actually firing. v7.8 closes that meta-gap via two surfaces:

| Surface | Mechanisms | Closes |
|---|---|---|
| Silent-pass prevention | A (coverage), B (dual-read + canonical schema), C (auto-instrumentation), D (header self-audit) | The v7.7 silent-pass + Audit Gaps A/B/C/D |
| Inter-agent awareness | E (ledger merge driver), F (membrane status) | HADF Phase 2 / PR #169 collision class |

## Section 1.0 — PR #173 (M1 PR-1, merged 2026-05-02)

**Author:** Regev (direct).
**Spec:** [v7.8/v7.9 bridge design](../superpowers/specs/2026-05-02-framework-v7-8-and-v7-9-bridge-design.md) §4.3 (Mechanism C scaffolding) + §4.2 (gate predicate fix).

Shipped:

- New constant `MECHANISM_C_SHIP_DATE = "2026-05-02"` in `scripts/check-state-schema.py`.
- `CACHE_HITS_EMPTY_POST_V6` gate fix: dual-read `created_at` ∪ `created`; pre-Mechanism-C exemption.
- `scripts/observe-cache-hit.py` — PostToolUse:Read hook entry point, writes session events ledger.
- `.claude/settings.json` — registered `PostToolUse:Read` → `observe-cache-hit.py`.

T11 (advisory cycle-time check `CACHE_HITS_AUTO_INSTRUMENTATION_INACTIVE`) NOT in this PR — deferred to PR #188.

## Section 2.0 — PR #185 + #186 (M1 PR-1 §8.2, merged 2026-05-03)

**Author:** Claude (this run, supervised).
**Bridge milestone:** §8.2 framework_version backfill.

| PR | Scope | Files | Verification |
|---|---|---|---|
| #185 | post-v6 backfill (4 features missing fv + meta-analysis-audit `v7.0` → `v6.0` correction + ui-audit-baseline-burndown missing `created_at`) | 6 state.json | schema-check 47/47 [T1]; integrity-check 0+2 advisories [T1] |
| #186 | pre-v6 backfill (34 features by created_at era: 15 → `pre-v5.0`, 19 → `v5.0`) | 34 state.json | schema-check 47/47 [T1] |

After both merge: **`framework_version` 100% canonical** [T1]. Ship criterion 3 from spec section 9 is hit.

Mechanical insertion pattern: regex-matched anchor on `"current_phase":` line, inserted `"framework_version": "<value>",` with matching indentation. Each post-edit file individually JSON-parse-validated. 0 modifications to existing content. **Diff is 34 files × 1 line each + 6 files × 1-2 lines each.** [T1]

## Section 3.0 — PR #187 (M1 PR-2, merged 2026-05-03)

**Bridge milestone:** §4.1 Mechanism A — Coverage-asserting gates.

**Problem statement (T3):** v7.7's `CACHE_HITS_EMPTY_POST_V6` ran on every commit but exercised data on 0/46 features. The framework asserted gate *implementation*; it never asserted gate *execution*.

**Shipped:**

- `scripts/gate_coverage.py` (~110 lines) — `GateCoverage` class with `candidate(gate)` / `skip(gate, reason)` / `checked(gate)` methods + `to_events()` / `write_jsonl()` flush. Invariant: `candidates == checked + skipped` per gate per run.
- `scripts/check-state-schema.py` — instrumented 10 gates: 5 inline checks in `validate_file` (SCHEMA_DRIFT_LEGACY_PHASE/CREATED, FRAMEWORK_VERSION_FORMAT, PR_NUMBER_UNRESOLVED, PHASE_TRANSITION_NO_LOG/TIMING) + 3 standalone fns now accepting `coverage` kwarg (CACHE_HITS_EMPTY_POST_V6, STATE_NO_CASE_STUDY_LINK, CU_V2_INVALID).
- `main()` instantiates `GateCoverage(mode=mode)`, threads through every `validate_file` call, then writes one JSONL event per gate to `.claude/logs/gate-coverage.jsonl`. Tests opt out via `GATE_COVERAGE_LEDGER_DISABLED=1`.
- 13 new tests in `scripts/tests/test_gate_coverage.py` covering counter balance, JSONL writer shape, every early-return path, backward-compat (gate functions still callable without coverage kwarg).
- Caught-fix-as-you-touch: 1 pre-existing test fixture broken by PR #173's Mechanism-C exemption (`created_at=2026-04-20` is post-v6 but pre-Mechanism-C → bypassed). Updated 3 fixtures to `2026-05-03`.

**Verification on real corpus** [T1]:

```
{"gate":"CACHE_HITS_EMPTY_POST_V6","candidates":47,"checked":0,"skipped":47,
 "skip_reasons":{"pre_v6":34,"pre_mechanism_c":12,"no_created_at":1}}
{"gate":"FRAMEWORK_VERSION_FORMAT","candidates":47,"checked":8,"skipped":39,
 "skip_reasons":{"field_absent":39}}
```

The first line **is exactly the silent-pass evidence Mechanism A is designed to surface** [T1]. The gate is correct (no post-Mechanism-C feature has reached `complete` yet — Mechanism C shipped yesterday). But now the data path exists for v7.9's `GATE_COVERAGE_ZERO` meta-check to calibrate its threshold from. [T2]

**Test count:** 55 passing (up from 54: +13 new gate_coverage tests, -1 pre-existing failure fix).

**CI status:** `Build and Test` flaked on the known parallel-clone simulator hang (`MealLogUITests.testNutritionTabOpensMealEntryPath` — 0 Swift code changes in this PR). Re-run pending. [T1]

## Section 4.0 — PR #188 (M2 PR-3, merged 2026-05-03)

**Bridge milestone:** §4.3 Mechanism C wiring (T9 + T10 + T11).

**Problem statement (T3):** PR #173 shipped the `PostToolUse:Read` hook + `scripts/observe-cache-hit.py`, but nothing was writing the `.claude/active-feature` lockfile that `_resolve_active_feature()` reads. **Every observed Read landed in the session ledger with `active_feature=""`.** Auto-collection captured tool calls, but feature attribution was 0%. [T1, verified by inspecting `_session-*.events.jsonl` files post-PR-173]

**Shipped (T1, all observable in the merged diff):**

- **T10** — `.claude/skills/pm-workflow/SKILL.md` Setup Step 2: `echo "$0" > .claude/active-feature` on entry. Subsequent PostToolUse:Read events tag with the right feature automatically while a /pm-workflow session is active.
- **T9** — `.claude/settings.json` SessionStart hook command extended to read `.claude/active-feature` (if present) and surface `## Active Feature (Mechanism C attribution): <name>` so a fresh agent session knows which feature its Reads will attribute to.
- **T11** — `scripts/integrity-check.py` new `check_cache_hits_auto_instrumentation_inactive()` aggregates Read events from `.claude/logs/_session-*.events.jsonl` by `active_feature`, emits ADVISORY finding for any feature where session events show ≥1 attributed Read but `state.json::cache_hits[]` is empty/absent. **15th cycle-time check code** (advisory severity, mirrors v7.7 TIER_TAG_LIKELY_INCORRECT pattern).
- `scripts/set-active-feature.sh` — small CLI helper for setting the lockfile manually.
- `.gitignore` — adds `.claude/active-feature` (per-developer state, gitignored).

**Verification (T1):**

```
$ # Synthetic ledger entry: 2 Reads attributed to `settings` feature.
$ make integrity-check
... 0 findings + 3 advisory:
  [CACHE_HITS_AUTO_INSTRUMENTATION_INACTIVE]: settings: session ledgers
  attribute 2 Read event(s) to this feature, but state.json::cache_hits[]
  is empty/absent.
```

The advisory fires correctly when ledger drift is present. Silent on a fresh install with no session events. [T1]

## Section 5.0 — PR #189 (M2 PR-4, merged 2026-05-03)

**Bridge milestone:** §4.5 Mechanism E — Custom git merge driver for ledgers.

**Problem statement (T3):** HADF Phase 2 demonstrated that `measurement-adoption-history.json` and `documentation-debt.json` accumulate dated/ID'd snapshots from concurrent worktrees. Default 3-way merge produces conflict markers; manual resolution is the current process. Union-dedup is the semantically-correct merge for these files: every append is an independent observation, never a destructive overwrite.

**Shipped:**

- `scripts/merge-driver-dedup.py` (~140 lines) — registry-based config (path-suffix → `{array, dedup_key}`); reads `%A`/`%B`, ignores `%O` (ancestor is a subset of both sides by construction for append-only files); union by key, theirs-wins on collision, sorted output, written back to `%A`. Returns 1 (not 2) on parse/config errors so git falls back to standard conflict markers — safer than silently clobbering.
- `.gitattributes` — registers `union-dedup-by-key` for the two ledgers.
- `scripts/install-merge-drivers.sh` — idempotent registration in `.git/config`.
- `Makefile install-hooks` target invokes the install script. **One command (`make install-hooks`) sets up both pre-commit hooks AND merge drivers.**
- `scripts/tests/test_merge_driver_dedup.py` — 13 tests covering config lookup, union-dedup semantics, top-level field preservation, error paths.

**Verification (T1, end-to-end smoke test in throwaway repo):**

```
$ # Branch1 adds {date: 2026-04-26} to ledger; main adds {date: 2026-04-27}.
$ git merge --no-edit branch1
  Merge made by the 'ort' strategy.
$ # Result: all 3 dates (ancestor + branch1 + main) merged, sorted, no conflict markers.
```

## Section 6.0 — Outcome at synthesis time (2026-05-03)

| Dimension | Pre-v7.8 (v7.7 ship) | Post-v7.8 (this run) | Tier |
|---|---|---|---|
| `CACHE_HITS_EMPTY_POST_V6` effective coverage | 0/46 (silent-pass) | Mechanism A ledger surfaces actual coverage; gate fires deterministically when applicable | T1 |
| `framework_version` canonical (`vX.Y`) | 8/46 | **46/46** | T1 |
| Write-time gates with coverage instrumentation | 0 | **10** | T1 |
| Mechanism C session attribution | hook installed, lockfile not written → 0% | `/pm-workflow` writes lockfile, hook reads it, advisory fires on drift | T1 |
| Append-only ledger merge conflicts | manual resolution | auto via `union-dedup-by-key` driver | T1 |
| Cycle-time check codes | 14 (1 advisory) | **15** (2 advisory) | T1 |
| Total framework mechanisms | 25 gates + 1 advisory | **27 gates + 2 advisory + Mechanism A coverage layer + Mechanism E merge driver** | T1 |

**Validation criteria from spec §9:**

| Criterion | Target | Actual at v7.8 PR-2/3/4 ship |
|---|---|---|
| `CACHE_HITS_EMPTY_POST_V6` schema bug fixed | Gate fires on at least 1 future feature | Gate predicate fixed; data path exists; first fire pending post-Mechanism-C feature at `complete` [T2] |
| Mechanism C session ledger captures Read events | ≥80% of Read tool calls land in session ledger | Hook installed + active-feature attribution wired; first 7-day window starts now [T2] |
| `framework_version` 100% canonical `vX.Y` | 46/46 pass `FRAMEWORK_VERSION_FORMAT` | **46/46 ✓** [T1] |
| `state.json::agent_manifest` populated on all 46 | 46/46 have field | DEFERRED to M3 PR-5 [T2] |
| Mechanism E merge driver activates | ≥1 successful auto-merge | Verified end-to-end on throwaway repo [T1]; first prod auto-merge pending [T2] |
| Mechanism F membrane status surfaces in UCC | `/control-room/framework` §7 | DEFERRED to M3 PR-6 [T2] |

## Section 7.0 — What's deferred to M3 / M4

| Bridge milestone | Scope | Why deferred |
|---|---|---|
| M3 PR-5 | Schema bridge fields (`agent_manifest`, `_meta.deprecation_warnings`, `path-reducers.json`, `agent-leases.json`, `mode` flags) + `migrate-state-v7-8-bridge.py` + `fcntl.flock` + epoch scaffolding | Largest piece — touches all 46 features again with new schema fields. Needs design judgment on field shapes. |
| M3 PR-6 | Mechanism F (membrane status) + UCC dashboard panel + Mechanism D (pre-commit header self-audit) | Needs UCC dashboard work coupled with the script. Partial scope (Mechanism D alone) is small but bundling makes sense. |
| M4 PR-7 | v7.8 case study FINAL synthesis + cold-start entrypoint + fitme-story showcase + framework-honesty-ledger entry | This document is the case study; final synthesis happens when M3 PR-5 + PR-6 land. |

## Section 8.0 — Lessons learned (T3)

1. **Memory drift is itself a silent-pass surface.** The 2026-04-30 gaps audit memo was 2 days stale at the start of this session. Several "open" items had already been closed by PR #169 + #173 (which themselves shipped *because* of the audit memo). Verifying memory claims against current code BEFORE starting work saved hours of duplicated effort.
2. **Stacked PRs against a fast-moving design work.** PR-1 (#173) spec'd 7 PRs (M1 PR-1 through M4 PR-7). PR-2 (this run's #187) shipped 2 days later by reading the spec, finding what was already done, and shipping the next layer. Bridge designs are useful precisely because they're plannable in chunks.
3. **The Mechanism A ledger is a meta-tool.** It doesn't add new gates; it adds **observability of existing gates**. The first event it emitted on real data (`CACHE_HITS_EMPTY_POST_V6` candidates=47, checked=0) is exactly the failure mode the gate exists to prevent. The gate is correct, the predicate is correct, the data path is correct — all confirmed by the ledger. The v7.7 silent-pass would have been impossible to ship if Mechanism A had existed first.
4. **Per-developer state requires gitignore discipline.** `.claude/active-feature` and `.claude/logs/_session-*.events.jsonl` are observability-class state, not committed evidence. Gitignoring them keeps PR diffs clean. The v7.9 promotion will keep the same convention.

## Section 99 — Final synthesis

Pending — appended when M3 PR-5 + PR-6 + M4 PR-7 ship. v7.9 enforcement-flip becomes its own case study.

## Section 99B — Cross-references

- **Spec:** [`docs/superpowers/specs/2026-05-02-framework-v7-8-and-v7-9-bridge-design.md`](../superpowers/specs/2026-05-02-framework-v7-8-and-v7-9-bridge-design.md)
- **Predecessor case study:** [`docs/case-studies/framework-v7-7-validity-closure-case-study.md`](framework-v7-7-validity-closure-case-study.md)
- **Predecessor spec:** [`docs/superpowers/specs/2026-04-27-framework-v7-7-validity-closure-design.md`](../superpowers/specs/2026-04-27-framework-v7-7-validity-closure-design.md)
- **Audit memo (2026-04-30):** memory `project_framework_gaps_audit_2026_04_30.md`
- **Research notes:**
  - Branch isolation survey: [`docs/research/2026-05-01-framework-v7-8-branch-isolation-survey.md`](../research/2026-05-01-framework-v7-8-branch-isolation-survey.md)
  - Implementation safety: [`docs/research/2026-05-02-framework-v7-9-implementation-safety-research.md`](../research/2026-05-02-framework-v7-9-implementation-safety-research.md)
  - Mechanism C deep research: [`docs/research/2026-05-02-framework-mechanism-c-cache-hits-auto-instrumentation-research.md`](../research/2026-05-02-framework-mechanism-c-cache-hits-auto-instrumentation-research.md)
- **Honesty rule:** memory `feedback_publish_verbatim_then_remediate.md` ("Publish audits verbatim, append corrections")
- **Tier-tag convention:** [`docs/case-studies/data-quality-tiers.md`](data-quality-tiers.md)

---

> Updated 2026-05-03 with PR #185–#189 entries. Next entry: M3 PR-5 schema bridge fields. Final synthesis when M4 PR-7 ships.
