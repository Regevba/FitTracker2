# F3 — DEPENDENCY_GRAPH_CYCLE — Phase A Calibration Artifacts

> Authored BEFORE code per infra-master-plan §3.5 Calibration Protocol.
> Cycle-time advisory → unit + dispatch test layers (no try-repo fixture pair).

## 1. Identity

| Field | Value |
|---|---|
| Gate code | `DEPENDENCY_GRAPH_CYCLE` |
| Mechanism A emission key | `DEPENDENCY_GRAPH_CYCLE` |
| Function | `check_dependency_graph_cycles(coverage=None)` |
| Location | `scripts/integrity-check.py` |
| Dispatch site | `build_snapshot()` → `advisory_findings` tuple, `coverage=cycle_coverage` |
| Severity | ADVISORY (never affects `finding_count` or exit code) |
| Coverage mode | `cycle` |
| RICE / Theme | 14.4 / Theme A (roadmap realism) |

## 2. What it detects

Integrity problems in the multi-feature dependency graph: **cycles**,
**self-loops**, and **dangling references** (an edge pointing at a feature
that does not exist). Surfaced because one dependency cycle was caught
manually, post-hoc, on a multi-feature roadmap.

## 3. The graph

Nodes = features under `.claude/features/`. Directed edge `A → B` means
"A depends on / is scheduled after B", built from two **structured**
fields on `A`'s state.json:

- `scheduled_after` — `{"predecessor": "<feature>"}` (object form; a bare
  string is also accepted) → edge to `<feature>`.
- `parent_feature` — `"<feature>"` → edge to `<feature>`.

**Excluded:** `depends_on`. Empirically it holds free-text prerequisites
("PR #158 — six lifecycle analytics events…", "Existing Supabase
cohort_stats table…"), not feature names. Parsing it as an edge would
manufacture dangling-reference false positives. (smart-reminders-behavioral-learning
is the witness.)

## 4. Fire conditions (each → one ADVISORY finding)

1. **Dangling** — an edge target is not an existing feature directory.
2. **Self-loop** — `A → A`.
3. **Cycle** — a directed cycle `A → B → … → A`. Reported once per distinct
   cycle via canonical-rotation dedup (rotate the cycle so its
   lexicographically smallest node is first; dedup on that tuple) so the
   same cycle isn't emitted from every member.

## 5. Coverage semantics (Mechanism A)

- **candidate** — each feature that has ≥1 structured edge (graph participant).
- **checked** — each such feature (its out-edges validated for dangling/self-loop).
- **skip** — `features_dir_missing` only (graceful degradation). Features
  with no structured edge are simply not candidates.

Graceful degradation: missing `FEATURES_DIR`, unreadable/invalid JSON →
skip silently (no finding, no crash), consistent with sibling cycle checks.

## 6. Expected baseline at ship (snapshot — 2026-06-17)

**0 findings** — current corpus has 0 cycles, 0 self-loops, 0 dangling refs
across `scheduled_after` + `parent_feature` (28 features carry ≥1 edge).
candidates ≥ 1 → a *healthy* zero-firing guard-gate (GATE_COVERAGE_ZERO
distinguishes this from a 0-candidate mis-wire). The new
`f3-dependency-graph-cycle-check` feature itself adds one live, valid
`scheduled_after → f1-state-tasks-filesystem-drift` edge.

## 7. Calibration walk

- **Phase A** — this doc (pre-code). ✓
- **Phase B** — advisory + measure ≥7d Mechanism A coverage.
- **Phase C** — calibration review ~2026-07-01 → -08.
- **Posture** — advisory-permanent (a graph-integrity guard; promotion to
  enforced is not the goal — a future cycle/dangling ref should surface
  loudly but never block an unrelated commit).

## 8. Reversibility

Single-line removal from the `advisory_findings` tuple in `build_snapshot()`
(< 2 min). The function is pure/read-only; no schema or data migration.
