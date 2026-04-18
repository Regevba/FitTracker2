# Audit v2 — Concurrent 6-Group Stress Test (Case Study)

> Framework v6.1 | Stress Test | Started 2026-04-18 | In Progress

---

## What This Tests

After 11 serial remediation PRs (#84–#94) closed 123 of 170 audit findings, the remaining ~47 findings are bundled into 6 homogeneous groups. Instead of running them serially, the framework dispatches all 6 as **concurrent worktree-isolated agents** in 3 waves of 2.

**The question:** Does the framework actually scale laterally, or does concurrency at this size just produce serialized execution with extra overhead?

---

## Methodology — 2×3 Wave Dispatch

| Wave | Pair | Risk | Hypothesis |
|---|---|---|---|
| 1 | G6 (Config) + G2 (Tests) | LOW conflict | Validates the worktree dispatch pattern works |
| 2 | G1 (UI) + G5 (DS) | HIGH cross-group conflict (both touch `AppTheme.swift`) | Tests merge resolution under deliberate contention |
| 3 | G3 (AI) + G4 (Backend) | HIGH internal complexity | Tests when agents internally serialize but dispatch in parallel |

Each agent runs in its own git worktree, makes commits, opens a PR, and reports timing + token + conflict metrics back.

## Six Groups

| # | Group | Files Touched | Inner Parallelism | Cross-Group Conflict |
|---|---|---|---|---|
| 1 | UI Refactor & Token Cleanup | SwiftUI views, `AppText` migrations | HIGH | Medium (G5) |
| 2 | Test Coverage Expansion | New test files only | MEDIUM | LOW |
| 3 | AI Pipeline Correctness | `FitTracker/AI/` | MEDIUM | LOW |
| 4 | Backend & Sync Hardening | Auth/Sync/Encryption services | LOW (high internal conflict) | HIGH (G6) |
| 5 | Design System Pipeline | `AppTheme.swift`, `tokens.json` | LOW (single file) | HIGH (G1) |
| 6 | Framework Config & Docs | `.claude/shared/*.json`, docstrings | HIGH | LOW |

---

## Per-Wave Results

### Wave 1 — G6 + G2 (in flight)

_Will be filled when wave completes._

### Wave 2 — G1 + G5

_Pending wave 1._

### Wave 3 — G3 + G4

_Pending wave 2._

---

## Per-Group Outcomes

_Will be filled per group as PRs land._

---

## Cross-Group Analysis

_Will be filled at the end._

---

## Honest Limitations

- Not a controlled experiment. No statistical pre-registration, no causal isolation between waves.
- Wall-clock measurements include my own coordination overhead, not just framework dispatch time.
- Token budget includes the parent monitoring agent (this conversation) + 6 worker agents.
- Build concurrency may serialize at the OS level even when agents dispatch in parallel.

---

## Linked
- Plan: memory `project_audit_v2_stress_test_plan.md`
- Source audit case study: `docs/case-studies/meta-analysis-audit-and-remediation-case-study.md`
- Source findings: `.claude/shared/audit-findings.json`
