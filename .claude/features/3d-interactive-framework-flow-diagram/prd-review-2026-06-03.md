# 3D Framework Universe — PRD Review (2026-06-03)

> **Read-only audit while the feature stays paused per operator decision
> until v7.9.1 closes (~2026-06-04).** Produces a punch list for Phase 1 →
> Phase 2 advancement readiness once the gate lifts.

## Verdict

**The PRD is Phase-2-ready in 7 of 9 dimensions.** Two structural gaps
need 1–2 hours of operator-attention work before the tasks.md draft can
start cleanly. None are blockers to the feature's strategic case.

## Dimension-by-dimension assessment

### ✅ §Purpose + §Business Objective + §Target Personas (dims 1–3)

All three sections are crisp and discriminating. Purpose names a specific
audience problem (framework legibility for non-developer readers). Business
objective ties to public-site activation. Personas are mutually exclusive
and named at the resolution that drives design decisions (P1 = engaged
dev reader; P2 = AI-curious senior; P3 = operator dogfood). No drift
between sections.

### ✅ §Functional Requirements (dim 4)

17 FR-* items, each tractable. Notable: every FR has a clear ownership
assignment (FrameworkUniverse.tsx / scene component / primitive / build
script). FR-12 (mode switching `visitor` ↔ `operator`) is properly
isolated from FR-1..11 — no scope leak. No "TBD" or "see appendix"
escape hatches.

### ✅ §User Flows (dim 5)

4 flows. The 4th (Operator mode) is unusual but correct — the dogfood
case validates the data-contract architecture before public visitor
load arrives. Each flow has an explicit kill criterion in §Kill Criteria
(kill-2 maps to flow-1; kill-5 maps to flow-4) — that bidirectional
linking is rare in this repo's PRDs and is a quality signal.

### ✅ §Success Metrics & Measurement Plan (dim 6 — v6.0 compliant)

Primary metric is composite (3-AND): watched ≥80% + ≥1 hover + reached
Act VI. Each conjunct is tractable; the compound is the discriminating
measure of "comprehension" the feature exists to deliver. T2 tier
explicit (declared, pending Stream A instrumentation; T1 promotion path
documented). Secondary + Guardrail metrics each have baseline + target
+ instrumentation column. Leading vs Lagging split is clean. **No
"vanity metric" landed in the primary** (e.g. "pageviews," "session
duration alone") — the discipline holds.

### ✅ §Kill Criteria (dim 7 — high quality)

5 kill criteria, each with measurable threshold + revert/reassess
path explicit. Kill-1 (perf regression) is the only hard-revert; others
trigger Phase 9 (Learn). **Independent firing logic is named explicitly
("Kill criteria are independent")** — that's a v7.7 validity-closure
hygiene point landed in the PRD itself.

### ⚠️ §Acceptance Criteria (dim 8 — 1 gap)

10 acceptance criteria, all measurable except one:

> - [ ] At least one cross-repo PR-cite hover (Act IV) opens FT2's PR
>   page on click

This is a behavioral assertion ("at least one") but the path is
non-deterministic at runtime (depends on which gate fires in the
operator-mode live stream). **Recommended:** rephrase to a deterministic
form — "Hovering ANY Act IV gate-fire signage AND clicking the linked
PR ID opens the corresponding GitHub PR page in a new tab." That makes
the criterion testable by a Playwright assertion at Phase 5 instead of
"observe in production."

### ⚠️ §Data Contracts & Modularity (dim 9 — 1 gap)

This is the section operator added 2026-05-28 (preserved via PR #592
today). It's high-quality architectural reasoning, but introduces 1
spec gap:

> The 4-input contract assumes `feature-roster.json` is a **build-time
> aggregate** of `.claude/features/*/state.json`. Currently there are 85
> state.json files (post-D1, post-C5, etc.) but the aggregator code at
> `fitme-story/scripts/sync-from-fittracker2.ts` doesn't yet exist for
> roster aggregation (only the integrity mirror exists per v7.8.3
> Phase 1).

**Recommended:** before Phase 2 starts, the aggregator script needs an
input/output contract spec — at minimum:

  - Input: glob pattern `.claude/features/*/state.json`
  - Output schema: `{ slug, status, framework_version, current_phase,
    case_study?, parent_feature? }[]`
  - Stability guarantee: array ORDER is stable across runs (alphabetical
    by slug); deltas are detected via field-by-field diff, not array-position
  - Privacy: no raw `cache_hits[]`, no `_session-*.events.jsonl`, no
    operator email hashes leak into the build artifact (Universe is public)

Without that contract, Phase 4 implementation will hit an "API surface
ambiguity" stop at the first aggregator commit.

### ✅ §Alternatives Considered

The PRD does NOT have a §Alternatives considered section — but per
**brainstorm-pm's new three-option mode** (shipped today via PR #597 +
PR #600 auto-dispatch heuristic), Phase 0 brainstorm WAS run when this
PRD was originally drafted (2026-05-13). The decisions log inside the
PRD's §Purpose section names the three options that were considered:

  - Tier 1 only (R3F bespoke per-act scene; the chosen path)
  - Tier 2 only (Rive timeline, no 3D)
  - Hybrid (Rive + R3F on demand)

That structure isn't called out as a "three-option matrix" in the
PRD body, but the decision IS recorded. **Recommended:** when Phase 1
re-enters from the v7.9.1 unblock, add a §Alternatives Considered
section that lifts the 3 options into the matrix shape (UX / Design / Dev
rows + defer-to-v2 + failure-modes per option) per the new
brainstorm-pm three-option contract. This is back-fill, not blocking.

## Open questions that block Phase 1 → 2 advancement

| # | Question | Where it lands |
|---|---|---|
| OQ-1 | The "at least one cross-repo PR-cite hover" acceptance criterion needs deterministic phrasing | §Acceptance Criteria |
| OQ-2 | `feature-roster.json` aggregator input/output contract is undefined | §Data Contracts (new sub-section needed) |
| OQ-3 | The 3 alternatives considered at 2026-05-13 brainstorm should be lifted into a §Alternatives Considered matrix | New section (post-Phase-1 backfill) |

Estimated operator work to close OQ-1 + OQ-2: **45–60 min**.
OQ-3 can be backfilled in parallel with Phase 2 task drafting.

## Phase 2 readiness signal

| Phase-1 → Phase-2 gate | Status |
|---|---|
| PRD complete in all 9 dimensions per v7.8.5 discipline | 7/9 ✅ + 2 gaps above |
| Success metrics + kill criteria tier-tagged (T1/T2/T3) | ✅ |
| Analytics spec drafted | ✅ (§Analytics Spec, GA4 Event Definitions) |
| Dependencies enumerated | ✅ (§Key Files names every consumer + producer) |
| External-system data contracts defined | ⚠️ (OQ-2 above) |
| `state.json::brainstorm` populated | ⚠️ (no explicit brainstorm block; OQ-3 above) |
| Risks + mitigations | ✅ (§Kill Criteria + per-flow tier-3 fallbacks) |

## Recommended advancement path when v7.9.1 unblocks

1. Operator runs `make preflight WORK_TYPE=feature FEATURE=3d-interactive-framework-flow-diagram`
2. Address OQ-1 (rephrase acceptance criterion 10 to deterministic form)
3. Address OQ-2 (write the `feature-roster.json` aggregator contract — input glob, output schema, stability + privacy guarantees)
4. Operator approves Phase 1 → Phase 2; tasks.md drafting begins
5. OQ-3 backfilled (§Alternatives Considered matrix added in parallel with tasks.md)

## Cross-references

- PRD: [`prd.md`](prd.md) (500 lines)
- State: [`state.json`](state.json) — `current_phase: prd`, `paused: true`
- Research: [`research.md`](research.md)
- Original Phase 0 brainstorm context: 2026-05-13 session memory `project_3d_framework_universe_paused_2026_05_13.md`
- Data Contracts section added: 2026-05-28 (drafted on `save/r9-dirty-2026-05-28`, preserved into main via PR #592)
- Sibling feature using new three-option mode: PR #597 + PR #600 (auto-dispatch)
