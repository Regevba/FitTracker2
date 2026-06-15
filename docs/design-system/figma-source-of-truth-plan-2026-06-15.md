# Figma ↔ Code Source-of-Truth Reconciliation & Fix Plan

**Created:** 2026-06-15
**Trigger:** Full design-system audit (iOS + web) found the Figma mirror + Code Connect bridge non-operational while docs claimed it was "Synced" / "operator setup complete."
**Decision:** Code Connect is **not possible** on the current Figma plan → disable it, reconcile docs to reality, and rebuild the Figma files as an honest visual mirror of code using the Figma MCP plugin API (which *does* work on Pro).
**Honesty ledger:** [FT2-FH-005](../case-studies/framework-honesty-ledger.md) · **Observed pattern:** W36.

---

## 1. What the audit found (evidence)

**Code-side design systems → OPERATIONAL ✅** (these ship to users):
- iOS: `design-tokens/tokens.json` (12 categories) → `DesignTokens.swift` (Style Dictionary v5, golden-verified PR #677); `AppTheme.swift` 177 semantic tokens; `AppComponents.swift` + DS files; `make ui-audit` 0 P0 / 0 P1; `tokens-check` CI gate.
- Web (fitme-story): `src/app/globals.css` 57 token vars; `src/components/ui/` 8 primitives; `figma-drift-weekly.yml` green.

**Figma mirror + Code Connect bridge → NON-OPERATIONAL ❌:**
- `figma-code-connect-publish.yml` has **failed on every real run since 2026-05-10** in both repos (only empty scaffold runs were green).
- **Root cause 1 (fatal):** Figma account is **Pro**. Code Connect requires **Organization/Enterprise**. MCP `get_code_connect_map` → *"You need a Developer seat in an Organization or Enterprise plan to access Code Connect."*
- **Root cause 2 (iOS):** publish 403 *"Invalid scope(s): need File Read + Code Connect Write"* — scope not grantable on Pro.
- **Root cause 3 (web):** W14 — `sign-in/page.figma.tsx` + `recover/page.figma.tsx` map page **frames** (`31-3`/`31-106`), not components → `figma connect publish` validation aborts the whole publish.
- **Figma files are empty/partial:** iOS lib `0Ai7s3fCFqR5JXDW8JvgmD` = 1 "Cover" page + placeholder frame only (0 components/variables/styles). Web `fsjHfFLAHELACZHku8Rfcl` = Cover + `AuthPasskeyForm` component-set (`30:61`) + 12 sign-in/recover frames only. All ~23 web primitive node IDs + ~6 iOS Code Connect nodes + the sync-matrix screen nodes **do not exist** (dangling).

---

## 2. Decommission Code Connect (THIS change)

- [x] FT2 `.github/workflows/figma-code-connect-publish.yml` → disabled stub (no auto-trigger; manual dispatch prints the reason).
- [x] fitme-story `.github/workflows/figma-code-connect-publish.yml` → disabled stub.
- [ ] Reconcile docs (§3).
- [ ] Honesty-ledger entry FT2-FH-005 + observed-pattern W36.

`.figma.swift` / `.figma.tsx` mapping files, `figma.config.json`, `.figma-cc-tools/` are left **in place but inert** (no publish consumes them). Removing them is a separate, approval-gated cleanup (§5, open question OQ-1).

---

## 3. Doc reconciliation checklist (authoritative forward-looking docs)

Historical records are **not** rewritten (case studies, audit bundles, integrity snapshots, `.claude/features/*` histories, `src/data/docs/**` mirror — regenerates from FT2 source). The honesty-ledger entry is the record of the correction.

| Doc | Change | Status |
|---|---|---|
| `CLAUDE.md` — v4.X+CC + design-system sections | Add "Code Connect DISABLED (Pro plan)" note; correct "setup complete / 2→0" claim | ☐ |
| `docs/design-system/figma-code-sync-status.md` | Top banner: Code Connect disabled + Figma files empty/partial; downgrade false "Synced (auto-built)" rows to "Code-only (Figma frame not present)"; rewrite Code Connect Verification Contract | ☐ |
| `docs/design-system/ios-code-connect-workflow.md` | Mark SUPERSEDED/disabled; point here | ☐ |
| `docs/design-system/fitme-story-design-architecture.md` | Reconcile Code Connect architecture section | ☐ |
| `docs/skills/design.md` + `.claude/skills/design/SKILL.md` | Mark Code Connect preflight/publish steps disabled (skip cleanly) | ☐ |
| `docs/design-system/figma-coverage-guide.md`, `figma-library-progress.md` | Reconcile if they assert Code Connect operational | ☐ |
| fitme-story `docs/CONTRIBUTING-design-system.md` | Code Connect references → disabled note | ☐ |
| fitme-story `src/app/design-system/page.tsx`, `src/app/pm-flow/page.tsx` | Public pages — reword/remove "Code Connect bridge" claims | ☐ (confirm w/ operator) |
| `.claude/features/code-connect-automation/state.json` | Add disposition note (bridge decommissioned, plan-gated) | ☐ |

---

## 4. Make Figma reflect code (what CAN be fixed, without Code Connect)

Mechanism: **Figma MCP plugin API** (`use_figma` / `figma-generate-library` / `figma-generate-design`) — works on Pro. Code stays source of truth; Figma becomes an accurate **visual mirror**.

- **Phase A — iOS library rebuild** (`0Ai7s3fCFqR5JXDW8JvgmD`): Foundations page (color/spacing/radius/typography/motion from `tokens.json`), Components page (the AppComponents set), Screens pages (Home/Training/Nutrition/Stats/Settings/Onboarding/Login reference frames). Capture **real** node IDs.
- **Phase B — Web file rebuild** (`fsjHfFLAHELACZHku8Rfcl`): the 8 `ui/` primitives + tokens from `globals.css`; keep existing auth/sign-in frames.
- **Phase C — New verification contract:** "Synced" = Figma frame visually matches rendered code + real node ID recorded + recent date. Drift = manual matrix + web `figma-drift-weekly.yml` (manifest-based, already green). **No** Code Connect.
- **Rewrite the sync matrix** with the real node IDs from Phases A/B and status "Mirror (MCP-built)".

## 5. Open questions
- **OQ-1:** delete the now-inert `.figma.{swift,tsx}` + `.figma-cc-tools/` + `figma.config.json`, or keep for a future Org/Enterprise upgrade? (deletion is approval-gated)
- **OQ-2:** reword the public `/design-system` + `/pm-flow` pages now, or after the Figma rebuild lands?
- **OQ-3:** execute the Figma rebuild (§4 A/B) this session or schedule it?

## 6. Re-enablement trigger
If the Figma account upgrades to **Organization/Enterprise**: revert the workflow stubs, regenerate `FIGMA_ACCESS_TOKEN` with *File Read + Code Connect Write*, convert the two web page-frame mappings (`31-3`/`31-106`) to components (fix W14), and re-run publish.
