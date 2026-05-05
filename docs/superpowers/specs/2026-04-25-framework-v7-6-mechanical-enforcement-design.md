---
title: Framework v7.6 — Mechanical Enforcement
date_written: 2026-05-05  # RETROACTIVE BACKFILL — original framework version shipped 2026-04-25
ship_date: 2026-04-25
backfill_type: framework_meta_retroactive
backfill_source:
  - docs/case-studies/mechanical-enforcement-v7-6-case-study.md  # primary narrative source
  - docs/superpowers/plans/2026-04-25-v7-6-mechanical-enforcement-phases-2-4.md  # original plan (existed pre-spec)
  - docs/superpowers/plans/2026-04-25-v7-6-pending-fixes-handoff.md
  - docs/superpowers/plans/2026-04-25-v7-6-unified-completion-plan.md
  - PR #141 diff (v7.6 ship PR)
  - .github/workflows/{pr-integrity-check,framework-status-weekly}.yml
work_type: Feature
dispatch_pattern: serial
predecessor_case_studies:
  - docs/case-studies/data-integrity-framework-v7.5-case-study.md  # v7.5 baseline
status: shipped_pre_spec_discipline
---

# Framework v7.6 — Mechanical Enforcement (Retroactive Spec)

> **THIS IS A RETROACTIVE SPEC.** v7.6 shipped on 2026-04-25, before the project established formal spec discipline at v7.7 (2026-04-27). v7.6 had a **plan** (3 plan documents, listed above), but no spec. This spec was authored 2026-05-05 as part of the chain-of-custody initiative (full-repair-mode plan PR-H) and is sourced entirely from existing artifacts. Nothing fabricated; every claim traceable to pre-2026-05-05 sources.

## 0. One-line summary

v7.6 promotes seven Class B (silent gap, agent-attention required) integrity checks to Class A (mechanically enforced) via four new write-time pre-commit hooks plus two recurring CI defenses, and explicitly documents five remaining Class B gaps as known limitations.

## 1. Genesis & Why Now

v7.5 (2026-04-24) shipped the eight-defense data integrity framework triggered by the Gemini audit. Within 24 hours the project surfaced four new silent-gap categories that v7.5 left agent-attention-dependent:

1. Phase transitions in state.json with no matching log event (Tier 2.2 contemporaneous logging not gated)
2. Phase transitions with no per-phase timing (Tier 1.1 measurement not gated)
3. Broken PR citations in case studies (cycle-time only, not write-time)
4. Tier-tag presence on case studies (no enforcement)

v7.6 promotes these four to write-time gates. In the same release: per-PR review bot + weekly framework-status cron close two operational gaps.

## 2. Scope (as shipped 2026-04-25 via PR #141)

**In scope (closed by v7.6) — 4 new write-time gates:**

- **W3** `PHASE_TRANSITION_NO_LOG` — pre-commit rejects `current_phase` change in state.json without a matching `phase_started`/`phase_approved`/`phase_transition`/etc. event in the feature's log within 15-min freshness window.
- **W4** `PHASE_TRANSITION_NO_TIMING` — pre-commit rejects `current_phase` change without `timing.phases.<old>.ended_at` + `timing.phases.<new>.started_at`.
- **W5** `BROKEN_PR_CITATION` (write-time) — pre-commit rejects case-study commits citing `PR #N` or `pull/N` numbers that don't resolve via cached `gh pr list`. Skipped gracefully when `gh` unavailable.
- **W6** `CASE_STUDY_MISSING_TIER_TAGS` — pre-commit rejects scoped case-study commits (forward-only, dated ≥ 2026-04-21) when the file has no T1/T2/T3 tier tag at all.

**In scope — 2 recurring CI defenses:**

- **C9** Per-PR review bot — `.github/workflows/pr-integrity-check.yml` runs schema-check + integrity-check + measurement-adoption against every PR HEAD; sets `pm-framework/pr-integrity` commit status; sticky comment with marker `<!-- pm-framework-pr-integrity-bot -->`.
- **C10** Weekly framework-status cron — `.github/workflows/framework-status-weekly.yml` fires Mondays 05:00 UTC; appends snapshot to `.claude/shared/measurement-adoption-history.json`; opens regression issue if `fully_adopted` or `any_adopted` decreases.

**In scope — append-only adoption history:**

- `.claude/shared/measurement-adoption-history.json` — Tier 1.1 trend ledger; trend mode unlocks after 3 snapshots accumulate. `make measurement-adoption` writes a dated snapshot.

**Out of scope (explicitly documented as Class B unclosable-by-design):**

Five gaps documented at `docs/case-studies/meta-analysis/unclosable-gaps.md`:
1. `cache_hits[]` writer-path adoption (later closed in v7.8 via Mechanism C — auto-instrumentation hook)
2. `cu_v2` factor magnitude correctness (judgment-based)
3. T1/T2/T3 tag correctness (later partially-closed in v7.7 via C1 advisory heuristic)
4. Tier 2.1 real-provider auth checklist (human-required)
5. Tier 3.3 external replication (structurally-required)

> "A system that knows what it cannot check is more trustworthy than one that pretends every check is a check."

## 3. Architecture

### 3.1 Promotion semantics

v7.6's framing is **Class B → Class A promotion**:

- **Class A** = Mechanically enforced (commit fails or PR fails or issue opens)
- **Class B** = Agent-attention dependent (silent gap; relies on the agent remembering to check)
- **Class C** = Heuristic-only (advisory; can produce false positives)

v7.6 promotes 7 items B → A:
- 4 new write-time gates (W3-W6 above)
- 2 new recurring CI defenses (C9-C10 above)  
- 1 new append-only ledger (measurement-adoption-history.json with dedup-by-date)

### 3.2 New cycle-time check codes

Total cycle-time check codes after v7.6: **13** (was 9 in v7.5):
- v7.5 baseline: PHASE_LIE, TASK_LIE, NO_CS_LINK, V2_FILE_MISSING, PARTIAL_SHIP_TERMINAL, NO_STATE, INVALID_JSON, NO_PHASE, SCHEMA_DRIFT
- v7.6 additions: PR_NUMBER_UNRESOLVED (cycle-time variant), BROKEN_PR_CITATION (cycle-time), CASE_STUDY_MISSING_TIER_TAGS (cycle-time)

### 3.3 New write-time check codes

Total write-time check codes after v7.6: **6** (was 2 in v7.5):
- v7.5 baseline: SCHEMA_DRIFT, PR_NUMBER_UNRESOLVED
- v7.6 additions: PHASE_TRANSITION_NO_LOG, PHASE_TRANSITION_NO_TIMING, BROKEN_PR_CITATION, CASE_STUDY_MISSING_TIER_TAGS

### 3.4 Two new recurring CI workflows

```yaml
# .github/workflows/pr-integrity-check.yml
on: pull_request
# Runs schema-check + integrity-check + measurement-adoption against PR HEAD
# Sets pm-framework/pr-integrity commit status
```

```yaml
# .github/workflows/framework-status-weekly.yml
on:
  schedule: [{cron: "0 5 * * 1"}]  # Mondays 05:00 UTC
# Appends snapshot to measurement-adoption-history.json
# Opens issue on regression
```

## 4. Implementation summary (as shipped 2026-04-25 via PR #141)

| File | Purpose |
|---|---|
| `scripts/check-state-schema.py` (extended) | New gates: PHASE_TRANSITION_NO_LOG, PHASE_TRANSITION_NO_TIMING |
| `scripts/integrity-check.py` (extended) | New cycle checks: BROKEN_PR_CITATION, CASE_STUDY_MISSING_TIER_TAGS |
| `.github/workflows/pr-integrity-check.yml` | NEW — per-PR review bot |
| `.github/workflows/framework-status-weekly.yml` | NEW — weekly Tier 1.1 trend |
| `.claude/shared/measurement-adoption-history.json` | NEW — append-only ledger |
| `.claude/integrity/README.md` (extended) | Documents new check codes + per-PR bot |
| `CLAUDE.md` (extended) | "Per-PR + weekly defenses" section |
| `docs/case-studies/meta-analysis/unclosable-gaps.md` | NEW — explicit B-unclosable enumeration |

## 5. Outcomes (verified at v7.6 ship + ongoing)

**Promotion summary at ship:**

| Item | Pre-v7.6 | Post-v7.6 |
|---|---|---|
| Phase-transition-without-log catch | Class B (silent) | Class A (commit fails) |
| Phase-transition-without-timing catch | Class B (silent) | Class A (commit fails) |
| Broken PR citations in case studies | Cycle-time only | Write-time + cycle-time |
| Case studies without tier tags | None | Class A (commit fails for post-2026-04-21 dated docs) |
| Per-PR integrity status | None | `pm-framework/pr-integrity` check |
| Weekly Tier 1.1 trend | None | Mondays 05:00 UTC |
| Total framework mechanisms | 8 (v7.5) | 18 (12 cycle + 6 write-time) |

**Cron persistence note:** the per-PR bot worked at ship. The weekly cron initially attempted direct `git push origin main` which started failing 2026-04-29 when branch protection was hardened. PR #203 (2026-05-04, v7.8 era) replaced direct push with `peter-evans/create-pull-request@v6` for both the weekly cron AND the integrity-cycle cron. As of 2026-05-05 the persistence fix is shipped but unexercised (next firings: 2026-05-06 + 2026-05-11).

## 6. What v7.6 explicitly DID NOT close

- **`cache_hits[]` writer-path adoption** (Issue #140) — explicitly Class B in the v7.6 ship. Closed in v7.7 with `CACHE_HITS_EMPTY_POST_V6` write-time gate (which itself silently failed coverage at ship — closed in v7.8 via Mechanism C auto-instrumentation hook + dual-read schema bridge).
- **`cu_v2` factor magnitude correctness** — judgment-based; presence/range check shipped in v7.7.
- **T1/T2/T3 tag correctness** — heuristic-only; advisory check shipped in v7.7 C1.
- **Tier 2.1 real-provider auth checklist** — human-required; D1 deferral.
- **Tier 3.3 external replication** — structurally-required; D2 deferral, issue #142.

## 7. Predecessor chain

v7.0 (meta-analysis) → v7.1 (integrity cycle) → v7.5 (data integrity framework) → **v7.6** (mechanical enforcement) → v7.7 (validity closure) → v7.8 (bridge to v7.9)

## 8. Known limitations of this retroactive spec

1. **Milestone structure is approximated.** v7.6 had 3 plan documents (Phases 2-4, pending fixes handoff, unified completion plan), suggesting it was structured as a multi-phase ship. This spec collapses them into a single "as shipped" view.
2. **No Linear/Notion sync trail.** v7.6 propagation was manual; the live MCP-driven sync infrastructure (formalized in v7.7) did not yet exist.
3. **Some content is reconciled across the 3 source plans + the case study.** The plans differ in detail level; this spec uses the case study's "as shipped" claims as the canonical source where they conflict with earlier plan-stage drafts.

## Links

- **Case study (primary source):** [`docs/case-studies/mechanical-enforcement-v7-6-case-study.md`](../../case-studies/mechanical-enforcement-v7-6-case-study.md)
- **Original plans (predecessor sources):** [Phases 2-4](../plans/2026-04-25-v7-6-mechanical-enforcement-phases-2-4.md), [Pending fixes handoff](../plans/2026-04-25-v7-6-pending-fixes-handoff.md), [Unified completion plan](../plans/2026-04-25-v7-6-unified-completion-plan.md)
- **PR #141** ship PR (squash-merged 2026-04-25)
- **Successor specs:** [v7.7](2026-04-27-framework-v7-7-validity-closure-design.md), [v7.8 + v7.9 bridge](2026-05-02-framework-v7-8-and-v7-9-bridge-design.md)
- **Predecessor spec (retroactive):** [v7.5](2026-04-24-framework-v7-5-data-integrity-design.md)
- **Unclosable gaps:** [`docs/case-studies/meta-analysis/unclosable-gaps.md`](../../case-studies/meta-analysis/unclosable-gaps.md)
