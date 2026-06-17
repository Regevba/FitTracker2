# Research & Discovery — figma-design-architecture

**Feature:** figma-design-architecture
**Phase:** 0 (Research)
**Work type:** Feature (but see §10 — scope reframed by research; likely abbreviated)
**Date:** 2026-06-17

---

## 1. What is this solution?

Establish a single, honest **design-system source-of-truth + per-surface architecture** for FitMe across both surfaces — iOS (FitTracker2) and web (fitme-story) — in the steady state where **code is the source of truth and Figma is a manually-maintained mirror** (Code Connect was permanently disabled 2026-06-15; the Figma account is Pro, which cannot grant the `code_connect:write` scope).

Concretely it closes the three gaps the 2026-06-15 Figma-mirror rebuild left open (master-plan sub-tasks B + C + D):

- **(B) iOS Figma↔code fidelity audit** — verify the rebuilt iOS Figma library (Foundations page `10:3`, Components catalog `10:5`, 80 token variables `985:2`) actually matches `AppTheme.swift` / `AppComponents.swift` / `tokens.json`.
- **(C) Per-surface architecture docs** — write the missing unified `ios-design-system-architecture.md` (parallel to the existing web `fitme-story-design-architecture.md`), and update the web doc to reflect the rebuilt mirror + strip inert Code Connect references.
- **(D) Mirror-maintenance protocol** — define who maintains the Figma mirrors, on what cadence, and how token/component changes flow code → Figma going forward.

## 2. Why this approach?

**The problem it solves.** Right now the design-system "source of truth" story is *scattered and partly false*:
- The Figma mirror was rebuilt 2026-06-15 (real, verified node IDs for both surfaces) — but **nobody has audited whether the mirror matches the code**, and there's **no protocol for keeping it matched**.
- iOS has **no single architecture doc** — the token→component→screen story is implicit across CLAUDE.md, `AppTheme.swift`, and `v2-refactor-checklist.md`. Web has a good one (`fitme-story-design-architecture.md`) but it still references the pre-rebuild Figma state + inert Code Connect.
- The honesty ledger (FT2-FH-005) records that docs *claimed* "Code Connect setup complete / Synced" while the publish workflows failed on **every** run since 2026-05-10. This feature is the honest closure of that thread.

**User/operator pain.** A developer onboarding to the design system can't answer "where is the source of truth, and how do I keep Figma in sync?" from one doc. A future "add a token" change has no defined code→Figma propagation step.

## 3. Why this over alternatives?

| Approach | Pros | Cons | Effort | Chosen? |
|---|---|---|---|---|
| **A — Close B+C+D (audit + both arch docs + maintenance protocol)** | Coherent, honest closure of the whole initiative; the expensive Figma rebuild is already done so this is now cheap; leaves a maintainable steady state | Touches several docs; the iOS Figma audit needs Figma MCP read access | **~2–3 days** | **✓ Recommended** |
| B — Docs-only (C) | Cheapest; delivers the missing architecture narrative | Leaves mirror fidelity unverified (B) and no governance (D) — the mirror silently drifts again | ~1 day | ✗ |
| C — Audit + docs (B+C), defer governance (D) | Verifies + documents | Without (D) the audit is a one-time snapshot that rots; reintroduces the exact drift that caused FT2-FH-005 | ~1.5 days | ✗ |
| D — Re-mock all screens in Figma too | "Complete" Figma in the literal sense | The rebuild plan **deliberately** kept screens code-sourced to avoid drift; re-mocking reintroduces the drift Code Connect was supposed to prevent — directly re-opens FT2-FH-005 | ~2–3 weeks | ✗ (rejected by design) |

**Why A.** The 2026-06-15 rebuild already did the load-bearing, expensive work (Phases A/B/C of `figma-source-of-truth-plan-2026-06-15.md` — both Figma files rebuilt with verified node IDs). What remains is verification + documentation + governance — and doing all three together is what turns "we rebuilt the Figma mirror once" into "we have a maintained per-surface design-system source of truth."

## 4. External sources

- `docs/design-system/figma-source-of-truth-plan-2026-06-15.md` — the rebuild decision + executed Phases A/B/C.
- `docs/case-studies/framework-honesty-ledger.md` → **FT2-FH-005** — the Code-Connect-was-never-working disclosure; this feature is its remediation.
- Figma MCP plugin API (Pro-compatible) — the mechanism the mirror is built/maintained with (read for the audit via `mcp__claude_ai_Figma__get_*`).
- Design-system architecture-doc conventions: the existing `fitme-story-design-architecture.md` is the template to mirror for iOS.

## 5. Market / prior-art examples

- **Code-as-source-of-truth + Figma-mirror** is the standard fallback when Code Connect isn't available (e.g. teams on Figma Pro): maintain a hand-curated Figma library that documents tokens/components, and treat code as canonical. Shopify Polaris, GitHub Primer, and Material all publish a Figma kit that mirrors code rather than generating code from Figma.
- The **per-surface architecture doc** pattern (one doc per platform explaining token→component→screen layering) mirrors how multi-platform design systems (Material's Android/Web/Flutter docs) document each surface separately while sharing a token core.

## 6. UI / design considerations

This feature ships **no new app screens** — it produces architecture docs, an audit report, a maintenance protocol, and (if drift is found) corrective edits to the Figma mirror via MCP. `has_ui` is therefore expected to be **false** (proposed; confirmed in PRD). The "design" work is design-*system* governance, not product UI. No `ux-spec.md` / Phase 3 UI gateway is expected to apply — the relevant gate is the design-system compliance + Figma-mirror fidelity, not new-screen UX.

## 7. Data & demand signals

- **FT2-FH-005** is a logged, dated honesty-ledger entry — concrete evidence the source-of-truth story is currently dishonest/incomplete.
- The master plan (`ui-ux-master-plan-2026-05-24.md` line 204) lists this as a tracked 2–3 week Feature with sub-tasks A(done)/B/C explicitly enumerated — pre-existing demand.
- The 2026-06-15 rebuild PRs (#723 + fitme-story #222) shipped A but left B+C+D open — measurable unfinished scope.

## 8. Technical feasibility

- **Risk: Figma MCP read access** — the iOS audit (B) needs `mcp__claude_ai_Figma__get_variable_defs` / `get_metadata` / `get_screenshot` against file `0Ai7s3fCFqR5JXDW8JvgmD`. Feasibility depends on MCP liveness (the `/design preflight` Figma-liveness check covers this). Fallback: audit from the rebuild plan's recorded node IDs + a manual operator screenshot if MCP is down.
- **Low risk: docs** — (C) is pure authoring against known files; no build/runtime risk.
- **Low risk: governance** — (D) is a written protocol + optionally a lightweight CI/cadence hook (e.g. a checklist item in the contribution guides; a `figma-mirror-staleness` advisory is a possible stretch, not required).
- **No code/app changes**, so no iOS build or CI-test risk; `make ui-audit` / `tokens-check` unaffected.

## 9. Proposed success metrics (draft — finalized in PRD)

- **Primary:** A developer can answer "where is the design-system source of truth, and how is the Figma mirror kept in sync?" from **one doc per surface** — `ios-design-system-architecture.md` + updated `fitme-story-design-architecture.md`, both linked from CLAUDE.md (T2/T3, binary: docs exist + linked).
- **Secondary 1:** iOS Figma↔code fidelity audit produces a findings table (token/component coverage % of the rebuilt mirror vs code) — T1 measured.
- **Secondary 2:** A written, dated mirror-maintenance protocol (cadence + code→Figma propagation step) exists and is referenced from both contribution guides — binary.
- **Guardrail:** No new false "Synced/auto-built" claims (FT2-FH-005 class); every Figma claim is verified-live or explicitly marked "mirror, manually maintained."
- **Kill criteria (draft):** if the iOS Figma audit reveals the rebuilt mirror is <50% faithful (i.e. the 2026-06-15 rebuild didn't actually land), escalate — the feature becomes "re-rebuild the mirror" not "document it," which is a different, larger scope to re-plan.

## 10. Decision

**Recommended: Approach A — close gaps B + C + D.** Research reframed this from a 2–3 week design marathon into a **~2–3 day docs + audit + governance feature**, because the expensive Figma-mirror rebuild already shipped 2026-06-15.

**Scope reframe to flag for the user:** because the load-bearing build is done and the remaining work is documentation + audit + a protocol (no new product UI, no new screens), this may be better run as an **abbreviated Feature** (skip Phase 3 UX — `has_ui=false`) or even an **Enhancement** of the existing design-system line. Recommendation: run as a **Feature with `has_ui=false`**, skipping the Phase 3 UI gateway, so it still gets a PRD with success metrics + kill criteria (the source-of-truth honesty story deserves measurable closure) but doesn't carry UI-screen ceremony it has no use for.

**Open question for PRD:** confirm whether (D) maintenance protocol stays doc-only or also ships a lightweight `figma-mirror-staleness` advisory (stretch).
