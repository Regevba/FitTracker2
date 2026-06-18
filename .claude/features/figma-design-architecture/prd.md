# PRD — figma-design-architecture

**Feature:** figma-design-architecture
**Work type:** Feature (abbreviated — `has_ui=false`, Phase 3 UI gateway skipped)
**Phase:** 1 (PRD)
**Date:** 2026-06-17
**Framework version:** v7.10
**Honesty-ledger thread:** [FT2-FH-005](../../../docs/case-studies/framework-honesty-ledger.md) (Code Connect never operational; closure)

---

## 1. Summary

Establish a single, honest **design-system source-of-truth + per-surface architecture** for FitMe across iOS (FitTracker2) and web (fitme-story), in the steady state where **code is the source of truth and Figma is a manually-maintained mirror** (Code Connect permanently disabled 2026-06-15 — Figma Pro plan cannot grant `code_connect:write`).

This closes the three gaps the 2026-06-15 Figma-mirror rebuild left open:

- **(B) iOS Figma↔code fidelity audit** — verify the rebuilt iOS Figma library (Foundations `10:3`, Components `10:5`, 80 token variables `985:2`) actually matches `AppTheme.swift` / `AppComponents.swift` / `tokens.json`.
- **(C) Per-surface architecture docs** — author the missing `ios-design-system-architecture.md` (parallel to web's existing `fitme-story-design-architecture.md`) and update the web doc to reflect the rebuilt mirror + strip inert Code Connect references.
- **(D) Mirror-maintenance protocol** — define who maintains the Figma mirrors, on what cadence, and how token/component changes flow code → Figma. **Per operator decision (2026-06-17): D ships doc protocol PLUS a lightweight `figma-mirror-staleness` advisory** (a cycle-time / CI advisory that flags when code tokens/components drift from the last-audited mirror snapshot).

## 2. Problem & motivation

The design-system "source of truth" story is currently scattered and partly false:
- The Figma mirror was rebuilt 2026-06-15 with real verified node IDs for both surfaces — but **nobody has audited whether the mirror matches the code**, and there is **no protocol to keep it matched**.
- iOS has **no single architecture doc** — the token→component→screen story is implicit across CLAUDE.md, `AppTheme.swift`, and `v2-refactor-checklist.md`. Web has a good doc but it still references the pre-rebuild Figma state + inert Code Connect.
- FT2-FH-005 records that docs *claimed* "Code Connect setup complete / Synced" while publish workflows failed on every run since 2026-05-10. This feature is the honest closure of that thread.

**Operator pain:** a developer onboarding to the design system cannot answer "where is the source of truth, and how do I keep Figma in sync?" from one doc per surface. A future "add a token" change has no defined code→Figma propagation step.

## 3. Scope

### In scope
- (B) iOS Figma↔code fidelity audit → findings table (token + component coverage % of rebuilt mirror vs code).
- (C) `docs/design-system/ios-design-system-architecture.md` (new) + update `docs/design-system/fitme-story-design-architecture.md` (web) + both linked from CLAUDE.md.
- (D) `docs/design-system/figma-mirror-maintenance-protocol.md` (new) — cadence + code→Figma propagation step, referenced from both contribution guides.
- (D-advisory) lightweight `figma-mirror-staleness` advisory — flags drift between code tokens/components and the last-audited mirror snapshot. Ships **advisory-only** (no enforcement, no calibration-window flip planned at ship).
- Corrective edits to the Figma mirror via MCP **only if** the audit finds ≤ minor drift that is cheap to fix in-place.

### Out of scope
- Re-mocking app screens in Figma (rejected by design — reintroduces the drift the rebuild deliberately avoided; would re-open FT2-FH-005).
- Re-enabling Code Connect (impossible on Figma Pro).
- New product UI / new app screens (`has_ui=false`).
- Any iOS app code, build, or runtime change (`make ui-audit` / `tokens-check` unaffected).

## 4. Success metrics

> All metrics tier-tagged per `docs/case-studies/data-quality-tiers.md`.

**Primary metric** — Source-of-truth answerability (binary, T2/T3).
- **Definition:** a developer can answer "where is the design-system source of truth, and how is the Figma mirror kept in sync?" from **one doc per surface**, both linked from CLAUDE.md.
- **Baseline:** 0 of 2 surfaces have a complete, current architecture doc (iOS doc absent; web doc stale + references inert Code Connect).
- **Target:** 2 of 2 surfaces — `ios-design-system-architecture.md` exists + `fitme-story-design-architecture.md` updated, both linked from CLAUDE.md, neither containing a false "Synced/auto-built" claim.

**Secondary metrics**
1. **iOS mirror fidelity** (T1 measured) — token + component coverage % of the rebuilt iOS Figma mirror vs `tokens.json` / `AppComponents.swift`, reported as a findings table. Target: ≥ 90% faithful (below 90% but ≥ 50% → corrective edits in-scope; < 50% → kill, see below).
2. **Maintenance protocol exists** (binary, T2) — dated `figma-mirror-maintenance-protocol.md` with cadence + code→Figma propagation step, referenced from both contribution guides. Target: exists + linked.
3. **Staleness advisory live** (binary, T1) — `figma-mirror-staleness` advisory emits Mechanism A coverage telemetry on a real run. Target: ≥ 1 emitted row.

**Guardrail metrics** (must not degrade)
- **No new false provenance claims** — every Figma claim in any doc is either verified-live or explicitly labelled "mirror, manually maintained." (FT2-FH-005 class regression = guardrail breach.)
- **Framework integrity** — `make integrity-check` stays at 0 findings; no new enforcement gate ships without a calibration window.
- **No app/CI regression** — `make ui-audit` P0=0 and `make tokens-check` unchanged (this feature touches no app code).

**Leading indicators (≤ 1 week):** both docs merged + linked; audit findings table published; advisory emits its first coverage row.
**Lagging indicators (30/60/90d):** next token/component change uses the documented code→Figma propagation step; staleness advisory catches (or stays silent on) real drift; no new FT2-FH-005-class honesty-ledger entry.

**Instrumentation plan:** (1) doc existence + CLAUDE.md links — `make integrity-check` STATE_NO_CASE_STUDY_LINK + manual grep; (2) fidelity % — the audit script/table itself (T1); (3) advisory — `gate-coverage.jsonl` Mechanism A row + `gate-last-fired.json` index.

**Review cadence:** single post-merge review at T+14d (advisory soak check — did it emit/catch anything?). No recurring cadence (docs feature).

**Kill criteria:** if the iOS Figma audit reveals the rebuilt mirror is **< 50% faithful** (i.e. the 2026-06-15 rebuild did not actually land), STOP — the feature becomes "re-rebuild the mirror," a different and larger scope that must be re-planned as its own Feature. Record resolution in `kill_criteria_resolution`.

## 5. `has_ui` / `requires_analytics`

- **`has_ui = false`** — produces architecture docs, an audit report, a maintenance protocol + advisory, and (conditionally) corrective Figma-mirror edits. No new app screens; Phase 3 UI gateway does not apply. The relevant gate is design-system-mirror fidelity, not new-screen UX.
- **`requires_analytics = false`** — no new measurable user interactions; no GA4 events. Analytics Spec gate skipped.

## 6. Alternatives considered

| Approach | Effort | Decision |
|---|---|---|
| **A — Close B+C+D + staleness advisory** | ~2–3 days | **✓ Chosen** (operator-confirmed 2026-06-17) |
| B — Docs-only (C) | ~1 day | ✗ leaves mirror fidelity unverified + no governance → silent re-drift |
| C — Audit + docs (B+C), defer D | ~1.5 days | ✗ one-time snapshot rots; reintroduces FT2-FH-005 drift |
| D — Re-mock all screens in Figma | ~2–3 weeks | ✗ rejected by design — reintroduces drift the rebuild avoided |

**Gap D depth (operator decision 2026-06-17):** doc-only protocol *plus* lightweight staleness advisory (chosen over doc-only). The advisory makes drift *measured*, not just disciplined-against — consistent with the framework's "mechanical complement to discipline" posture.

## 7. Risks & feasibility

- **Figma MCP read access (medium)** — iOS audit (B) needs `mcp__claude_ai_Figma__get_variable_defs` / `get_metadata` / `get_screenshot` against file `0Ai7s3fCFqR5JXDW8JvgmD`. Mitigation: `/design preflight` Figma-liveness check; fallback to the rebuild plan's recorded node IDs + an operator screenshot if MCP is down.
- **Docs authoring (low)** — pure authoring against known files.
- **Advisory (low)** — additive, advisory-only; false positives don't break anything.
- **No code/app changes** — no iOS build or CI-test risk.

## 8. Rollout & reversibility

- All deliverables are docs + one advisory script — merge via standard PR, no app deploy.
- Advisory is reversible by removing/disabling the check (single-line); ships advisory so no rollback drama.
