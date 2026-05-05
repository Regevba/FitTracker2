# Framework v7.8 — Bridge to v7.9 Implementation Plan

> **THIS IS A RETROACTIVE PLAN.** v7.8 shipped between 2026-05-02 and 2026-05-04 across 9 PRs (#173, #185-189, #191-194, #195). The **spec** existed (`2026-05-02-framework-v7-8-and-v7-9-bridge-design.md`); this **plan** was authored 2026-05-05 as part of the chain-of-custody initiative (full-repair-mode plan PR-H), reconciling the as-shipped PR sequence against the spec's intended milestone structure. Sourced from the spec, the v7.8 case study, and the merged-PR git log; nothing fabricated.
>
> **Backfill type:** framework_meta_retroactive
> **Backfill source:** `docs/superpowers/specs/2026-05-02-framework-v7-8-and-v7-9-bridge-design.md` (spec) · `docs/case-studies/framework-v7-8-bridge-case-study.md` (live journal) · `git log --grep="framework-v7.8"` (PR sequence)

**Goal:** Close the v7.7 silent-pass on `CACHE_HITS_EMPTY_POST_V6` (gate fired every commit but skipped 46/46 features due to a `created`/`created_at` schema field-name drift) and ship the meta-layer (Mechanisms A–F) that prevents future silent-pass failures.

**Architecture:** 9 PRs across 2 days. Six new framework mechanisms (A–F) all ship advisory in v7.8; v7.9 promotes the writer-path (Mechanism C) to enforced once 7+ days of session-ledger data calibrates the threshold (window opens 2026-05-11).

**Tech stack:** Python 3.11 (hooks + scripts + Mechanism C observer), Bash + GitHub Actions (CI), git custom merge driver (Mechanism E `union-dedup-by-key`), `.claude/settings.json` PostToolUse:Read hook (Mechanism C), git pre-commit hook self-test (Mechanism D), advisory smartlog (Mechanism F).

**Spec:** [`docs/superpowers/specs/2026-05-02-framework-v7-8-and-v7-9-bridge-design.md`](../specs/2026-05-02-framework-v7-8-and-v7-9-bridge-design.md)

**Predecessor case studies:** v7.5 → v7.6 → v7.7 → **v7.8 bridge**

---

## Executive Summary

**As-shipped sequence (chronological by merge date):**

| PR | Merge date | Title | Closes |
|---|---|---|---|
| #173 | 2026-05-02 | M-C scaffold + dual-read parser | Mechanism C scaffolding + Mechanism B start |
| #185 | 2026-05-03 | PR-2 schema bridges A — backfill `framework_version` on 5 post-v6 features | Mechanism B schema reconciliation |
| #186 | 2026-05-03 | PR-3 framework_version backfill on 34 pre-v6 features + ui-audit dates | Mechanism B completion (47/47 features have canonical `framework_version`) |
| #187 | 2026-05-03 | PR-4 Mechanism A coverage gates | Mechanism A — every gate emits per-run coverage stats to `gate-coverage.jsonl` |
| #188 | 2026-05-03 | PR-5 Mechanism C session attribution | Mechanism C — `/pm-workflow` writes `.claude/active-feature`; SessionStart surfaces it; advisory `CACHE_HITS_AUTO_INSTRUMENTATION_INACTIVE` flag |
| #189 | 2026-05-03 | PR-6 Mechanism E git merge driver | `scripts/merge-driver-dedup.py` + `.gitattributes` opt-in for ledger files |
| #193 | 2026-05-03 | PR-6 Mechanisms D + F | `pre-commit-self-test` + `membrane-status` advisory smartlog |
| #194 | 2026-05-04 | PR-7 cold-start entrypoint + honesty ledger | `.claude/entrypoints/framework-v7-8.md` + first FT2-FH-001 entry |
| #195 | 2026-05-04 | CI fix — disable parallel UI testing | sim-clone flake mitigation (env-flake unrelated to v7.8 mechanism work) |

**6 mechanisms (A-F) shipped advisory:**

| Mechanism | Purpose | Spec section |
|---|---|---|
| A | Coverage-asserting gates emit `{candidates, checked, skipped, skip_reasons}` to `.claude/logs/gate-coverage.jsonl` | §4.1 |
| B | Schema field-rename detection + dual-read for `created` ∪ `created_at`; canonical `framework_version` on 47/47 features | §4.2 |
| C | `PostToolUse:Read` hook + `scripts/observe-cache-hit.py` — auto-captures Read events to `.claude/logs/_session-<id>.events.jsonl` | §4.3 |
| D | `scripts/pre-commit-self-test.py` — pre-commit hook validates its own header on each run | §4.4 |
| E | `scripts/merge-driver-dedup.py` + `.gitattributes` — auto-resolves merge conflicts on append-only ledgers via union-dedup-by-key | §4.5 |
| F | `scripts/membrane-status.py` — advisory smartlog joining active feature + recent gate firings + dispatch-blocker state | §4.6 |

**Outcome at synthesis time (2026-05-04):**

| Dimension | Pre-v7.8 | Post-v7.8 |
|---|---|---|
| `framework_version` field coverage | 7/47 features had values; 40/47 missing | **47/47** with canonical `vX.Y` form |
| `CACHE_HITS_EMPTY_POST_V6` effective coverage | 0/46 (silent-pass; gate read `created_at` but 43/46 used `created`) | dual-read fix; 1 effective post-Mechanism-C feature flagged correctly |
| Per-gate coverage observability | None | `gate-coverage.jsonl` ledger, 189+ entries by 2026-05-05 |
| `cache_hits[]` writer-path adoption | Class B (agent-attention) | Class B → A advisory (auto-collected via Mechanism C) |
| Ledger merge conflicts | Manual resolution | Auto-resolved (Mechanism E driver) |
| Pre-commit hook header drift | Silent | Mechanism D self-test catches |
| Inter-agent context handoff | Stranded across sessions | Mechanism F membrane-status advisory readout |
| Total framework mechanisms | 25 gates + 1 advisory (v7.7) | **27 mechanical gates + 2 advisories + observability layer** |

---

## Milestone Breakdown (reconciled to as-shipped sequence)

### M0 — Schema reconciliation (PR #173 + #185 + #186)

**Goal:** Close the v7.7 silent-pass via the field-name drift fix.

- T1 (PR #173): Add dual-read parser for `created` ∪ `created_at` to `check-state-schema.py`. Migrate 43 of 46 state.json files from `created` → `created_at`.
- T2 (PR #185): Backfill `framework_version` to canonical `vX.Y` on 5 post-v6 features.
- T3 (PR #186): Backfill `framework_version` on 34 pre-v6 features (`pre-vX.Y` form) + ui-audit dates.

**Outcome:** 47/47 features have canonical `framework_version`. `CACHE_HITS_EMPTY_POST_V6` gate now fires correctly.

### M1 — Mechanism A coverage gates (PR #187)

**Goal:** Make silent-pass impossible to ship undetected going forward.

- T4: Add `scripts/gate_coverage.py` — emits `{candidates, checked, skipped, skip_reasons}` per gate per run.
- T5: Wire every gate function in `check-state-schema.py` to accept `coverage` kwarg.
- T6: Append per-run summary to `.claude/logs/gate-coverage.jsonl`.
- T7: Document at `.claude/integrity/README.md` "Mechanism A — coverage tracking".

**Outcome:** every commit produces a row in `gate-coverage.jsonl`; v7.9 promotion gate `GATE_COVERAGE_ZERO` becomes promotable once 7+ days of stats accumulate.

### M2 — Mechanism C auto-instrumentation (PR #188)

**Goal:** Move `cache_hits[]` writer-path from Class B (agent-attention) to Class A advisory (auto-collected).

- T8: Add `scripts/observe-cache-hit.py` (PostToolUse:Read handler).
- T9: Wire `.claude/settings.json` `hooks.PostToolUse[].Read` → `observe-cache-hit.py`.
- T10: `/pm-workflow` writes `.claude/active-feature` on entry; SessionStart surfaces it.
- T11: Add advisory check `CACHE_HITS_AUTO_INSTRUMENTATION_INACTIVE` (15th cycle-time check code) — flags features where session events show Reads but state.json::cache_hits[] is empty.

**Outcome:** auto-instrumentation captures Read events to `.claude/logs/_session-<id>.events.jsonl`; cycle check surfaces features where the writer-path didn't engage.

### M3 — Mechanism E ledger merge driver (PR #189)

**Goal:** Auto-resolve merge conflicts on append-only ledgers.

- T12: Add `scripts/merge-driver-dedup.py` (`union-dedup-by-key` implementation).
- T13: Add `scripts/install-merge-drivers.sh` registration.
- T14: `.gitattributes` opt-in: `measurement-adoption-history.json` + `documentation-debt.json` use `merge=union-dedup-by-key`.
- T15: Wire `make install-hooks` to call `install-merge-drivers.sh`.

**Outcome:** future merge conflicts on the two append-only ledgers auto-resolve via union-dedup-by-date-key. Manual resolution no longer required.

### M4 — Mechanisms D + F (PR #193)

**Goal:** Self-test the gate infrastructure + advisory inter-agent membrane status.

- T16 (Mechanism D): `scripts/pre-commit-self-test.py` validates header parity between declared gates + implemented gates.
- T17: Wire pre-commit hook to invoke self-test.
- T18 (Mechanism F): `scripts/membrane-status.py` joins active feature + recent gate firings + dispatch-blocker state.
- T19: Wire SessionStart hook to surface membrane status.
- T20: Add `make membrane-status` target.

**Outcome:** D catches header drift between hook + script; F gives a single readout for "what is the framework doing right now."

### M5 — Cold-start entrypoint + honesty ledger (PR #194)

**Goal:** Make v7.8 mechanism state legible for fresh agent sessions.

- T21: `.claude/entrypoints/framework-v7-8.md` — one-page summary of mechanisms A-F + their advisory/enforced state.
- T22: `docs/case-studies/framework-honesty-ledger.md` — ongoing record of "claim vs reality" findings.
- T23: First entry FT2-FH-001 documenting the v7.7 `CACHE_HITS_EMPTY_POST_V6` silent-pass + v7.8 closure.

**Outcome:** new agent sessions land with a v7.8-aware cold-start prompt; honesty norm institutionalized.

### M6 — CI fix (PR #195)

**Goal:** Mitigate the parallel-clone simulator flake observed during v7.8 mechanism PRs.

- T24: Disable parallel UI testing in `.github/workflows/ci.yml` (`-parallel-testing-enabled NO`).
- T25: Document the change at backlog entry "CI parallel-clone simulator hang — root cause investigation".

**Outcome:** Build-and-Test step stops failing on env-flake (different test fails each run on PRs that touch zero Swift code). Permanent root-cause investigation deferred to a separate backlog task.

---

## Gating Status as of 2026-05-05

**Mechanism A (coverage gates):** Shipped advisory. 189+ entries in `gate-coverage.jsonl`. `GATE_COVERAGE_ZERO` meta-check shipped advisory; v7.9 promotes to enforced once 7+ days of data accumulate (window opens 2026-05-11).

**Mechanism B (schema bridges):** Fully shipped. 47/47 features have canonical `framework_version`. `created` ∪ `created_at` dual-read in place for the migration window.

**Mechanism C (auto-instrumentation):** Shipped advisory. PostToolUse:Read hook captures session events. v7.9 promotes writer-path to enforced once threshold calibrated.

**Mechanism D (self-test):** Shipped enforced (pre-commit invocation).

**Mechanism E (merge driver):** Shipped enforced (auto-resolves on installed hooks).

**Mechanism F (membrane status):** Shipped advisory.

## Cross-version chain

v7.5 (data integrity framework) → v7.6 (mechanical enforcement) → v7.7 (validity closure) → **v7.8 (bridge to v7.9)** → v7.9 (measurement window opens 2026-05-11)

## Known limitations of this retroactive plan

1. **Task-level granularity is reconstructed from the spec + as-shipped PR boundaries.** The original `feature/framework-v7-8-bridge` branch did not have a per-task tracker analogous to v7.7's 42-task plan. Tasks T1-T25 above are inferred from the spec sections + PR diffs; the original ship was more fluid.
2. **No Linear/Notion sync trail recorded for individual tasks.** Propagation was at the PR level, not task level.
3. **PR #195 (CI fix) was tactically bundled but not logically part of the mechanism architecture.** It's listed as M6 here for as-shipped completeness; it's not part of the "6 mechanisms" framing.

## Links

- **Spec:** [`docs/superpowers/specs/2026-05-02-framework-v7-8-and-v7-9-bridge-design.md`](../specs/2026-05-02-framework-v7-8-and-v7-9-bridge-design.md)
- **Case study:** [`docs/case-studies/framework-v7-8-bridge-case-study.md`](../../case-studies/framework-v7-8-bridge-case-study.md)
- **Honesty ledger (FT2-FH-001 et seq.):** [`docs/case-studies/framework-honesty-ledger.md`](../../case-studies/framework-honesty-ledger.md)
- **Cold-start entrypoint:** [`.claude/entrypoints/framework-v7-8.md`](../../../.claude/entrypoints/framework-v7-8.md)
- **Predecessor specs:** [v7.7](../specs/2026-04-27-framework-v7-7-validity-closure-design.md), [v7.6 (retroactive)](../specs/2026-04-25-framework-v7-6-mechanical-enforcement-design.md), [v7.5 (retroactive)](../specs/2026-04-24-framework-v7-5-data-integrity-design.md)
