---
title: "figma-design-architecture — honest closure of the design-system source-of-truth story"
date: 2026-06-18
date_written: 2026-06-18
framework_version: v7.10
work_type: feature
work_subtype: abbreviated_feature_docs_governance
dispatch_pattern: single-agent-serial
primary_metric: "2/2 surfaces have a current, linked, no-false-claim design-system architecture doc"
success_metrics:
  - "Primary (binary): 2/2 surfaces documented + linked from CLAUDE.md with no false 'Synced/auto-built' claims (baseline 0/2 → 2/2)"
  - "iOS mirror fidelity ~95% (T1 measured): 80-var code-mirror 985:2 matches tokens.json; 22 component sets; codeSyntax gap fixed"
  - "Maintenance protocol exists + linked; figma-mirror-staleness advisory emits ≥1 coverage row (7/7 unit tests pass)"
kill_criteria: "If the iOS Figma mirror is <50% faithful (rebuild never landed), STOP and re-scope as 're-rebuild the mirror' (a larger, separate Feature)."
kill_criteria_resolution: "Kill criterion was briefly tripped by a FALSE read (get_metadata reported 0% / empty). Authoritative use_figma plugin-API read showed the mirror is ~95% faithful — criterion NOT actually met. False finding retracted before any rebuild write; reverted to original audit+docs+governance scope. Resolution: kept (mirror is healthy)."
tier_tags_present: true
platforms_tested:
  ios: false
  web: false
  backend: false
  ai: false
related_prs: []
case_study_type: standard
---

# figma-design-architecture — honest closure of the design-system source-of-truth story

> **One-line:** turned a scattered, partly-false "where is the design-system source of truth?" story into one architecture doc per surface + a maintenance protocol + a drift advisory — and along the way caught (and retracted) a false kill-criterion trigger caused by a Figma read tool reading the wrong context.

## Context

After the 2026-06-15 Figma-mirror rebuild (which closed honesty-ledger [FT2-FH-005](framework-honesty-ledger.md)'s Code-Connect-never-worked thread by pivoting to "code is canonical; Figma is a manually-maintained mirror"), three gaps remained: **(B)** nobody had audited whether the rebuilt mirror matched code, **(C)** iOS had no architecture doc and the web doc was stale, **(D)** there was no maintenance protocol or drift detection. This feature closed B+C+D.

It ran as an **abbreviated Feature** (`has_ui=false`, `requires_analytics=false`): full Research → PRD → Tasks → Implement lifecycle, but the Phase 3 UX gateway and Analytics Spec gate were skipped (no product UI, no new events).

## The arc (what actually happened)

1. **Research → PRD → Tasks** locked Approach A (close B+C+D) + a Gap-D staleness advisory, per two operator decisions.
2. **T1 audit fired the kill criterion — falsely.** `get_metadata` / `get_variable_defs` / `get_design_context` reported the iOS library `0Ai7s3fCFqR5JXDW8JvgmD` as a single empty "Cover" page (node `985:2` "invalid"). That read as **0% fidelity** → kill criterion tripped. Surfaced to the operator, who chose to **rebuild the mirror**.
3. **Before any write, the authoritative read contradicted the finding.** A `use_figma` plugin-API read of the *same fileKey* showed 28 pages, 198 variables across 8 collections, the 80-var code-mirror collection `985:2` matching `tokens.json` exactly, and 18 variant-matrix component sets on Components page `10:5`. **The mirror was comprehensive.** Root cause: the read tools reflect the Figma *desktop-app* context (a stale Cover-only view), not the `fileKey`. Recorded as observed-pattern **W38**.
4. **Retraction + revert.** The rebuild was cancelled before any Figma mutation; the false finding was retracted in state.json + the contemporaneous log; scope reverted to the original audit+docs+governance.
5. **Real work shipped** (below).

## What shipped

| Gap | Deliverable |
|---|---|
| B | Live fidelity audit (both surfaces) → [`mirror-fidelity-audit-2026-06-18.md`](../../.claude/features/figma-design-architecture/mirror-fidelity-audit-2026-06-18.md). iOS ~95%, web ~90%. |
| B (fix) | The one real gap: populated iOS `codeSyntax` (`AppColor.*` / `AppSpacing.*` / …) on all **80** code-mirror variables via MCP write. |
| C | New [`ios-design-system-architecture.md`](../design-system/ios-design-system-architecture.md) with verified node IDs; corrected [`fitme-story-design-architecture.md`](../design-system/fitme-story-design-architecture.md) (its "file is empty/partial" + "doesn't exist yet" claims were false — fixed per publish-verbatim-then-correct). |
| C | Both docs linked from CLAUDE.md. |
| D | [`figma-mirror-maintenance-protocol.md`](../design-system/figma-mirror-maintenance-protocol.md) (owner + cadence + code→Figma propagation step). |
| D | `figma-mirror-staleness` advisory (`scripts/figma-mirror-staleness.py`, `make figma-mirror-staleness`) — Mechanism A coverage, advisory-only, 7/7 unit tests pass, snapshot at `.claude/shared/figma-mirror-snapshot.json`. |
| — (operator add) | fitme-story `/design-system` site page corrected to reflect the real verified mirror (separate branch `feature/figma-design-architecture-site`). |

## Metrics (tiered)

- **Primary (T2/T3, binary):** 0/2 → **2/2** surfaces have a current, linked, no-false-claim architecture doc. ✅
- **iOS fidelity (T1 measured):** ~95–100% (80/80 token values match; codeSyntax gap closed). ✅
- **Web fidelity (T1 measured):** ~90% (genuine; minor empty-Foundations-page + cruft-page gaps logged, not blocking). ✅
- **Advisory live (T1):** `FIGMA_MIRROR_STALENESS` emitted a `checked=1` coverage row on first run. ✅
- **Guardrails:** no new false-provenance claims (corrected two); `make integrity-check` unaffected; zero app/CI code touched.

## Lessons

1. **W38 — Figma read tools reflect desktop context, not `fileKey`.** Never trip a kill criterion or approve a destructive rebuild on a single "empty" read; cross-check with `use_figma` (one call). A `VariableCollectionId` is not a scene-node ID — node-addressed read tools reject it even when it exists.
2. **The kill criterion did its job — and so did not-barreling-ahead.** The PRD's <50%-fidelity STOP gate forced a surface-to-operator moment; the discipline of verifying before the destructive rebuild caught the false alarm before any damage. A rebuild would have duplicated/corrupted a rich existing library.
3. **A real mirror is cheaper to govern than to rebuild.** Because the mirror existed, the feature collapsed back to its intended lightweight docs+governance scope.

## Cross-references

- iOS / web architecture docs · maintenance protocol · staleness advisory (links above)
- Honesty ledger: [FT2-FH-005](framework-honesty-ledger.md) + its 2026-06-18 addendum
- Observed pattern: [W38](../../.claude/integrity/observed-patterns.md)
- Rebuild predecessor: [`figma-source-of-truth-plan-2026-06-15.md`](../design-system/figma-source-of-truth-plan-2026-06-15.md)
