---
title: Framework v7.5 — Data Integrity Framework
date_written: 2026-05-05  # RETROACTIVE BACKFILL — original framework version shipped 2026-04-24
ship_date: 2026-04-24
backfill_type: framework_meta_retroactive
backfill_source:
  - docs/case-studies/data-integrity-framework-v7.5-case-study.md  # primary narrative source
  - trust/audits/2026-04-21-gemini/remediation-plan-2026-04-23.md  # original trigger
  - .claude/integrity/README.md  # mechanism documentation
  - git log --grep="v7.5\|data-integrity" between 2026-04-21 and 2026-04-25
work_type: Feature
dispatch_pattern: serial
predecessor_case_studies:
  - docs/case-studies/integrity-cycle-v7.1-case-study.md  # 72h integrity cycle (v7.1 baseline)
  - docs/case-studies/meta-analysis-full-system-audit-v7.0-case-study.md  # v7.0 audit infrastructure
status: shipped_pre_spec_discipline
---

# Framework v7.5 — Data Integrity Framework (Retroactive Spec)

> **THIS IS A RETROACTIVE SPEC.** v7.5 shipped on 2026-04-24, before the project established formal spec discipline at v7.7 (2026-04-27). This document was authored 2026-05-05 as part of the chain-of-custody initiative (full-repair-mode plan PR-H) and is sourced entirely from existing artifacts — the v7.5 case study, the Gemini audit remediation plan, the integrity README, and git log. Nothing in this spec is fabricated; every claim is traceable to a pre-2026-05-05 source file.

## 0. One-line summary

v7.5 introduces an **eight-defense data-integrity framework** triggered by the 2026-04-21 Gemini independent audit, converting silent state.json drift from a Class C agent-attention problem into a write-time + cycle-time + readout-time gated discipline.

## 1. Genesis & Why Now

The 2026-04-21 Gemini 2.5 Pro independent audit (`trust/audits/2026-04-21-gemini/`) identified that the project had shipped extensive measurement infrastructure (v6.0 measurement framework, v7.1 integrity cycle, v7.0 meta-analysis) without measuring its own measurement adoption. The audit surfaced two patterns:

1. **State.json drift:** 7+ features had been sitting in "shipped but state.json unreconciled" limbo for 3-14 days before the 2026-04-20 audit caught them.
2. **Measurement-without-self-measurement:** the project tracked feature DVs (wall time, cache hits, cu_v2) but had no rollup of "how many features actually adopted the measurement framework."

v7.5 closes both loops by introducing eight cooperating defenses across three temporal tiers (write-time, cycle-time, readout-time).

## 2. Scope (as shipped)

**In scope (closed by v7.5):**

- **W1** `SCHEMA_DRIFT` write-time gate — pre-commit hook rejects legacy `phase` key (canonical: `current_phase`).
- **W2** `PR_NUMBER_UNRESOLVED` write-time gate — pre-commit hook verifies `phases.merge.pr_number` against cached `gh pr list`.
- **C1** `PHASE_LIE` cycle-time check — flags terminal phase with non-terminal sub-phases.
- **C2** `TASK_LIE` cycle-time check — flags terminal phase with open tasks.
- **C3** `NO_CS_LINK` cycle-time check — flags terminal phase without case_study or exempt tag.
- **C4** `V2_FILE_MISSING` cycle-time check — flags `v2_file_path` claim without disk file.
- **C5** `PARTIAL_SHIP_TERMINAL` cycle-time check — flags `partial_ship: true` with terminal phase.
- **R1-R3** Readout dashboards — `make integrity-check`, `make integrity-snapshot`, `make documentation-debt`, `make measurement-adoption`.

**Tier 2.3 data-quality convention introduced in same window** (forward-only from 2026-04-21): every quantitative metric in case studies, PRDs, and meta-analyses must carry T1 (Instrumented), T2 (Declared), or T3 (Narrative) tags.

**Out of scope (deferred to v7.6+):**
- Mechanical promotion of agent-attention checks to write-time (closed by v7.6 Mechanical Enforcement).
- Per-PR review bot (closed by v7.6).
- Weekly framework-status cron (closed by v7.6).
- Five Class B unclosable-by-design gaps documented at `docs/case-studies/meta-analysis/unclosable-gaps.md`.

## 3. Architecture

### 3.1 Three temporal tiers

```
Write-time          ┃ Cycle-time           ┃ Readout-time
(pre-commit hook)   ┃ (72h GitHub Actions) ┃ (any-time make targets)
─────────────────── ┃ ─────────────────── ┃ ────────────────────
SCHEMA_DRIFT        ┃ PHASE_LIE           ┃ make integrity-check
PR_NUMBER_UNRESOLVED┃ TASK_LIE            ┃ make integrity-snapshot
                    ┃ NO_CS_LINK          ┃ make documentation-debt
                    ┃ V2_FILE_MISSING     ┃ make measurement-adoption
                    ┃ PARTIAL_SHIP_TERMINAL┃ make framework-status
                    ┃ NO_STATE / INVALID_JSON ┃
                    ┃ NO_PHASE              ┃
```

**Tier hierarchy rationale:** write-time gates catch errors at commit; cycle-time gates catch slow drift across multiple commits; readout-time dashboards surface state to operators on demand. Each tier has a different failure mode (commit fails, cycle issue opens, dashboard reflects truth).

### 3.2 Snapshot ledger

`.claude/integrity/snapshots/<timestamp>.json` is the canonical ledger. Each 72h cycle produces one snapshot. Snapshots are append-only. Diff between consecutive snapshots is the "did anything regress" signal.

### 3.3 Backfill exemption

Features tagged `case_study_type: "pre_pm_workflow_backfill"` or `"roundup"` bypass the sub-phase vocabulary check (use legacy phase vocabulary). Documented at `.claude/integrity/README.md` "Expected false-positives".

## 4. Implementation summary (as shipped 2026-04-24)

| File | Purpose |
|---|---|
| `scripts/integrity-check.py` | Cycle-time auditor (PHASE_LIE, TASK_LIE, NO_CS_LINK, V2_FILE_MISSING, PARTIAL_SHIP_TERMINAL, SCHEMA_DRIFT, NO_STATE, INVALID_JSON, NO_PHASE) |
| `scripts/check-state-schema.py` | Write-time pre-commit hook (SCHEMA_DRIFT, PR_NUMBER_UNRESOLVED) |
| `.githooks/pre-commit` | Hook installer — `make install-hooks` wires it |
| `.github/workflows/integrity-cycle.yml` | 72h GitHub Actions cron |
| `.claude/integrity/snapshots/` | Append-only snapshot ledger |
| `scripts/measurement-adoption-report.py` | Tier 1.1 readout |
| `scripts/documentation-debt-report.py` | Tier 3.2 readout |
| `Makefile` targets | `make integrity-check`, `make integrity-snapshot`, `make documentation-debt`, `make measurement-adoption`, `make install-hooks` |

## 5. What v7.5 explicitly DID NOT close

The v7.5 case study explicitly enumerates 5 gaps it did not close, documented at `docs/case-studies/meta-analysis/unclosable-gaps.md`:

1. `cache_hits[]` writer-path adoption — agent-attention based (closed in v7.7+v7.8 via Mechanism C)
2. `cu_v2` factor magnitude correctness — judgment-based (presence-only check)
3. T1/T2/T3 tag correctness — heuristic-only (advisory check shipped v7.7 C1)
4. Tier 2.1 real-provider auth checklist — human-required
5. Tier 3.3 external replication — structurally-required

Documenting these as unclosable was itself a v7.5 deliverable — "a system that knows what it cannot check is more trustworthy than one that pretends every check is a check."

## 6. Outcomes (verified at v7.5 ship + ongoing)

| Tier | Status at ship | Status as of 2026-05-05 |
|---|---|---|
| 1.1 measurement adoption | partial (13/40 events) | partial (Tier 1.1 trend mode unlocked via v7.7 B1; cache_hits gate fixed via v7.8) |
| 1.3 schema | gated ✅ | gated ✅ (extended in v7.7 + v7.8) |
| 2.1 runtime smoke | pilot | pilot (still requires human at simulator) |
| 2.2 contemporaneous logs | gated forward ✅ | gated forward ✅ |
| 2.3 tier tags | presence-gated | presence-gated (correctness check shipped v7.7 C1 advisory) |
| 3.1 cycle audit | shipped ✅ | shipped ✅ (cron persistence fixed in PR #203) |
| 3.2 documentation debt | baseline only | trend mode unlocking via v7.7 B2 (3rd snapshot ETA 2026-05-12) |
| 3.3 external replication | 0 audits | 0 audits (issue #142 filed) |

## 7. Predecessor chain

v7.0 (meta-analysis audit infrastructure) → v7.1 (integrity cycle, 72h cron) → **v7.5** (eight-defense data integrity framework) → v7.6 (mechanical enforcement) → v7.7 (validity closure) → v7.8 (bridge to v7.9)

## 8. Known limitations of this retroactive spec

1. **The MILESTONE breakdown is approximated** — v7.5 did not have the 8-PR-across-N-milestones structure that v7.7 used. It shipped as a single coordinated push on 2026-04-24. This spec describes what shipped, not the live PM-workflow trace.
2. **No Linear/Notion sync trail** — the live propagation infrastructure (Linear MCP, Notion MCP propagation) was not yet codified.
3. **Tier 2.3 data-quality tags introduced in same window are NOT tagged in this retroactive spec.** Forward-only: every quantitative claim above is sourced from the case study or remediation plan; tier tags would themselves be retroactive and lose their meaning.

## Links

- **Case study (primary source):** [`docs/case-studies/data-integrity-framework-v7.5-case-study.md`](../../case-studies/data-integrity-framework-v7.5-case-study.md)
- **Gemini audit (trigger):** [`trust/audits/2026-04-21-gemini/remediation-plan-2026-04-23.md`](../../../trust/audits/2026-04-21-gemini/remediation-plan-2026-04-23.md)
- **Mechanism documentation:** [`.claude/integrity/README.md`](../../../.claude/integrity/README.md)
- **Successor specs:** [v7.7](2026-04-27-framework-v7-7-validity-closure-design.md), [v7.8 + v7.9 bridge](2026-05-02-framework-v7-8-and-v7-9-bridge-design.md)
