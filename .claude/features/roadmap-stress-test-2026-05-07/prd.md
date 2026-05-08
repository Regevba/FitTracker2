# PRD — `roadmap-stress-test-2026-05-07`

**Work type:** Feature (experiment)
**Work subtype:** `experiment` — `protocol_stress_test`
**Framework version:** v7.8.1
**Predecessor chain:** `framework-v7-8-branch-isolation` → `ucc-passkey-auth` → `roadmap-stress-test-2026-05-07`
**Date opened:** 2026-05-07T21:33:00Z
**Author:** Regev (with Claude Opus 4.7)

---

## 1. What this PRD is for

This PRD formalizes a **session-bounded experiment**: take a 9-step / ~10-week roadmap and run the v7.8.1 protocol over it as a single meta-feature. The roadmap was synthesized in chat just before this PRD opened; the canonical version lives at `research.md`.

Most of what a normal PRD covers (problem, scope, user stories, architecture, migration plan) doesn't cleanly apply to an experiment. This PRD instead specifies:

1. The hypotheses being tested
2. The dependent variables being measured
3. The success metrics + kill criteria for the experiment
4. The post-experiment comparison that closes the loop

When the experiment ends, the case study at `docs/case-studies/roadmap-stress-test-2026-05-07-case-study.md` and the data-collection ledger at `data-collection.json` together provide the actual ship narrative. **This PRD is preserved as the start-state document for a START-vs-FINISH comparison**, per user directive (the comparison surfaces gaps the protocol should formalize differently in v7.9).

## 2. Why a "PRD as backup baseline" matters

Per the user's framing: "write them as backup — when we are finished let's compare between start and finish and see for additional gaps that might help us learn more."

The PRD here is a **frozen snapshot of intent**. The case study is a **live append-only journal of execution**. The diff between them is the meta-learning artifact.

If at session end the case study reports outcomes that this PRD didn't predict, those gaps are protocol-improvement candidates for v7.9. If the case study confirms the PRD's predictions, those are protocol stability signals.

## 3. Hypotheses (pre-registered)

> Locked here at experiment open. Not edited later. Verdicts go in §99 of the case study.

### H1 — Throughput scaling

> **Claim:** the v7.8.1 protocol scales with sub-feature count without proportional overhead increase.
>
> **Operationalization:** if 1 feature took ~125 min in the precedent baseline (`ucc-passkey-auth` shipped 2026-05-07 afternoon), 3 sub-features through Phase 8 closure should fit within a 4-hour session — averaging ~80 min/feature with shared protocol setup.
>
> **Tier:** T1 (instrumented via `state.json::timing.phases.*.duration_minutes`)
>
> **Falsifiable by:** any 3-of-3 attempted sub-features taking > 240 min combined → H1 refuted.

### H2 — Protocol overhead bounded

> **Claim:** Tier 2.2 logging + pre-commit gates contribute < 25% overhead per step.
>
> **Operationalization:** Σ(time spent on Tier 2.2 emission + state.json mutations + pre-commit fixup retries) / total step duration. Measured per sub-feature.
>
> **Tier:** T1 (overhead spans are wall-clock observable)
>
> **Falsifiable by:** any sub-feature crossing 0.25 → H2 partially refuted; if 2+ sub-features cross → H2 refuted.

### H3 — Mechanism A coverage telemetry generality

> **Claim:** `gate-coverage.jsonl` records every gate firing across the 9 sub-features without per-feature configuration.
>
> **Operationalization:** count of unique features in `gate-coverage.jsonl` after experiment end ≥ count of sub-features that reached commit stage.
>
> **Tier:** T1 (jsonl is machine-grepable)
>
> **Falsifiable by:** any sub-feature that reached commit but produced 0 entries in `gate-coverage.jsonl` → H3 refuted.

## 4. In scope

The 9 sub-features in sequence (see `research.md` for the canonical list):

S1 app-store-assets · S2 onboarding-v2-retroactive · S3 case-study presentation · S4 Code Connect · S5 Figma research · S6 Readiness-Aware Training Alert · S7 Smart Reminders ↔ PN v2 · S8 Medium Priority UX · S9 Low Priority sweep

Plus the 4 Design System Residuals woven into the steps where they fit naturally.

## 5. Out of scope

- Actually completing all 10 calendar weeks of work in one session (impossible; experiment measures throughput, not completion)
- Modifying the v7.8.1 protocol mid-experiment (any protocol changes are recommendations for v7.9)
- Touching any high-risk Swift file (`DomainModels.swift`, `EncryptionService.swift`, any `*SyncService.swift`, `AuthManager.swift`, `AIOrchestrator.swift`) outside of the explicit scope of a sub-feature that requires it (none in S1–S9)
- Mid-session changes to backup, isolation, or kill-criteria policy (locked at open)

## 6. Success metrics

### Primary metric (T1, instrumented)

| Metric | Baseline | Target | Source |
|---|---|---|---|
| `subfeatures_completed_in_session` | 1 (ucc-passkey-auth precedent) | 3 | Count of sub-features whose `state.json.current_phase = complete` at session end |

### Secondary metrics (T1)

| Metric | Target | Source |
|---|---|---|
| `phase_transitions_per_subfeature` | 9 (full protocol per sub-feature) | `state.json::transitions[]` length |
| `tier_2_2_log_emit_compliance` | 1.0 | Tier 2.2 events / (2 × phase transitions) — perfect compliance = 1 phase_started + 1 phase_approved per phase |
| `feature_closure_completeness_pass_rate` | 1.0 | Sub-features that pass `FEATURE_CLOSURE_COMPLETENESS` at Phase 8 / sub-features that reached Phase 8 |

### Guardrails

| Guardrail | Kill threshold |
|---|---|
| `high_risk_swift_files_touched` | 1 (any) |
| `main_ci_red_at_session_end` | 1 (any) |
| `BROKEN_PR_CITATION_after_merge` | 1 (any) |

## 7. Kill criteria

- **K1** — any high-risk Swift file modified outside explicit scope → halt + revert from backup at `~/Documents/FitTracker2-backups/2026-05-07-pre-roadmap-stress-test/`
- **K2** — main CI red at session end with no path to green within 30 min → halt + open revert PRs for any merged sub-features that introduced the breakage
- **K3** — protocol overhead > 25% of step duration → declare protocol-breaking; report findings; experiment continues but verdict is captured

## 8. Review cadence

- **Live** — case study `§4 Observation log` updated at every notable event during the session (5–15 min cadence)
- **Phase boundaries** — data-collection ledger `subfeatures[]` updated when a sub-feature crosses into a new phase
- **Session end** — `§99 Resolution log` written; H1/H2/H3 verdicts; kill-criteria status; PRD-vs-case-study diff for v7.9 recommendations

## 9. The post-experiment comparison (start ↔ finish gap analysis)

Per user directive, after the experiment halts the comparison artifact gets written. Specifically:

| Field at experiment open | Field at experiment end | Gap analysis question |
|---|---|---|
| Hypotheses (this PRD §3) | Verdicts (case study §99) | Were the operationalizations correct? Did any hypothesis become unfalsifiable mid-flight? |
| Sub-feature list (research.md) | Sub-features actually attempted (case study §4) | Where did dependencies surface that the roadmap didn't predict? |
| Time estimate per step (research.md) | Wall time per step (data-collection.json) | Where were the largest variance bands? |
| DS Residuals woven in (research.md) | DS Residuals actually cleared (data-collection.json) | Did the bundling save time, add overhead, or wash? |
| `cu_v2` complexity score = 3.1 (state.json) | Empirical complexity at session end | Calibration check for future cu_v2 estimates |

The diff is the v7.9 protocol-improvement input.

## 10. Phase plan for the meta-feature itself

| Phase | What it produces | When complete |
|---|---|---|
| 0 Research | `research.md` (the roadmap) | At experiment open ✓ |
| 1 PRD | This document | At experiment open ✓ |
| 2 Tasks | `tasks.md` + `state.json::tasks[]` (9 sub-features) | At experiment open ✓ (state.json populated; tasks.md follows) |
| 3 UX | N/A — no meta-feature UI | Skipped |
| 4 Implementation | The serial execution of S1 → S9 | When session ends |
| 5 Testing | The data-collection ledger + case study journal serve as evidence | Continuous during 4 |
| 6 Review | Self-review at session end against PRD §3 + §6 + §7 | At session end |
| 7 Merge | Per-sub-feature PRs opened; **MERGE GATED on user per-PR approval** (no auto-merge per session feedback rule) | Sub-features merge as user approves |
| 8 Documentation | This PRD + research.md + case study + data-collection.json + per-sub-feature case studies | All in flight |
| 9 Complete | Meta-feature `current_phase: complete` at session end | At session end |

## 11. Risks

| Risk | Mitigation |
|---|---|
| Session timeout mid-sub-feature | Kill conditions documented; session-natural stop captures partial state; case study logs the boundary precisely |
| Pre-commit gates block routine commits because of meta-feature state.json drift | Backup at `~/Documents/FitTracker2-backups/` enables clean revert; gates fire as advisory in v7.8.1 (not enforced) so non-blocking |
| Sub-feature opens its own isolated worktree but the meta-feature isn't isolated | Documented Q3 override on meta-feature; sub-features auto-isolate per existing protocol |
| User changes direction mid-experiment | The pre-registered hypotheses + this PRD become read-only at experiment end regardless; comparison happens against what was predicted at open |
| Case study + data-collection ledger drift | Every measurement carries a `captured_at` timestamp; the journal is append-only |

## 12. Phase 1 exit checklist

- [x] Hypotheses pre-registered + operationalized
- [x] Success metrics + guardrails locked
- [x] Kill criteria documented
- [x] Out-of-scope items explicit
- [x] Backup snapshotted before any work
- [x] Q3 isolation opt-out documented for the meta-feature only
- [x] User feedback rule "no auto-merge without explicit approval" applied
- [x] Comparison framework defined (§9)
- [ ] **User approval to advance to Phase 4 (start S1)** — granted via "go" 2026-05-07T21:48Z

---

**This PRD is read-only after experiment open.** Any updates that emerge during execution land in the case study `§4` (live observation log), not here.
