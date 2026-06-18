# Figma Mirror Fidelity Audit — 2026-06-18

**Feature:** figma-design-architecture (T1e + T1w)
**Method:** authoritative `use_figma` plugin-API reads addressed by `fileKey` (NOT `get_metadata`/`get_screenshot`, which reflect the Figma *desktop-app* context — see Tooling Note).
**Verdict:** both mirrors are **genuine and substantially faithful**. The 2026-06-15 rebuild landed on both surfaces. No re-rebuild required.

---

## Tooling Note (why the first read was wrong)

The initial T1 pass used `get_metadata` / `get_variable_defs` / `get_design_context` and reported the iOS file as "1 Cover page, 0 variables, node 985:2 invalid" → a false 0% fidelity that tripped the PRD kill criterion. **Root cause:** those three MCP tools read the **Figma desktop app's currently-open file/selection context** (which was showing a stale Cover-only view), not the file addressed by the `fileKey` argument. `use_figma` runs the Plugin API against the `fileKey` directly and is authoritative. **Lesson (observed-pattern W38):** for a specific `fileKey`, trust `use_figma` plugin-API reads; treat `get_metadata`/`get_screenshot`/`get_design_context` as desktop-context-dependent.

---

## iOS — `0Ai7s3fCFqR5JXDW8JvgmD` (FitTracker Design System Library)

| Layer | Code source of truth | Figma mirror | Fidelity |
|---|---|---|---|
| Token variables | `design-tokens/tokens.json` (color 47, spacing 8, radius 10, opacity 3, size 6, layout 6) | "FitTracker Tokens (code mirror)" collection `985:2` — **80 vars**, values match exactly (e.g. `brand/primary` = rgba(250,143,64) = `#FA8F40`) | ✅ ~100% values |
| iOS code syntax | `AppColor.*` / `AppSpacing.*` / `AppRadius.*` / `AppOpacity.*` / `AppSize.*` / `AppLayout.*` | **Was empty `{}` → FIXED 2026-06-18**: all 80 vars now carry iOS codeSyntax | ✅ fixed this session |
| Components | `AppComponents.swift` (+ DS files) | Components page `10:5` — **22 component sets, full variant matrices** (AppButton 8, AppCard 4, StatusBadge 6, AppInputShell 4, AppProgressRing 3, MetricCard, ReadinessCard, ChartCard, MacroTargetBar, …) | ✅ exceeds the 10 audited Swift structs (mirror also covers composed cards) |
| Foundations | tokens | Foundations page `10:3` (Overview + Color Tokens frames) | ✅ present |
| Typography | `AppTheme.swift` type ramp | 22 text styles (`text/hero` → `text/button`) | ✅ present |
| Shadows | `shadow.card` / `shadow.cta` | 2 effect styles (`effect/elevation-card`, `effect/elevation-cta`) | ✅ present |

**Additional collections present:** Color/Semantic (Light/Dark, 46), Color/Primitives (19), Text/Roles (22), Spacing (9), Radius (9), Elevation (6), Motion (7). **28 pages, 198 vars total.**

**iOS fidelity: ~95–100%.** Residual gap (codeSyntax) closed this session.

---

## Web — `fsjHfFLAHELACZHku8Rfcl` (FitMe Story Web — Design System)

| Layer | Code source of truth | Figma mirror | Fidelity |
|---|---|---|---|
| Token variables | `src/app/globals.css` (12 vars) | "FitMe Web Tokens (code mirror)" collection `34:62` — 12 vars | ✅ |
| Semantic tokens | — | "FitMe Tokens" collection (Light/Dark, 51 vars) | ✅ |
| Components | `src/components/ui/` primitives | Components page `2:2` — 56 components (Button/Primary·Secondary·Ghost, Tag, Callout, Card/CaseStudy·FrameworkVersion, Search, Layout/Header·Footer·MobileNav, Persona, …) + AuthPasskeyForm set `30:61` | ✅ |
| Foundations page | tokens | **`34:75` "Foundations (code mirror)" — EMPTY (0 children)** | ⚠ stub |
| Cruft | — | `test-page-creation` empty page | ⚠ remove |

**Web fidelity: ~90%.** "✅ Phase B" claim holds. Minor gaps (empty Foundations page, cruft page) documented; not blocking.

---

## Disposition

- **iOS:** codeSyntax fixed; no further Figma work required.
- **Web:** empty Foundations page `34:75` + `test-page-creation` cruft → logged as low-priority follow-ups (out of scope for this docs/governance feature; not worth a rebuild).
- **Both surfaces** are documented as "Mirror — manually maintained" in the architecture docs (T2/T3) and governed by the maintenance protocol + staleness advisory (T5/T6).
- **No honesty-ledger violation** in the rebuild plan: its Phase A/B "✅ built" claims were **true**. The corrected lesson is about *audit tooling*, captured as W38.
