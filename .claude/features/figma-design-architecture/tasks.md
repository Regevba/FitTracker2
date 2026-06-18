# Tasks — figma-design-architecture

**Work type:** Feature (abbreviated, `has_ui=false`). Phase 3 UX gateway skipped.
**Total estimate:** ~2.5 days
**Dependency-ordered.** Gap mapping: (B) audit · (C) docs · (D) protocol + advisory.

| ID | Title | Type | Skill | Effort (d) | Depends on | Gap |
|----|-------|------|-------|-----------|------------|-----|
| T1 | iOS Figma↔code fidelity audit → findings table (token + component coverage % of rebuilt iOS mirror vs `tokens.json`/`AppComponents.swift`/`AppTheme.swift`) | audit | design | 0.75 | — | B |
| T2 | Author `docs/design-system/ios-design-system-architecture.md` (token→component→screen layering, mirror status, parallel to web doc) | docs | design | 0.5 | T1 | C |
| T3 | Update `docs/design-system/fitme-story-design-architecture.md` — reflect rebuilt mirror + strip inert Code Connect references | docs | design | 0.25 | — | C |
| T4 | Link both architecture docs from CLAUDE.md (Design System section) + verify no false "Synced/auto-built" claims remain | docs | docs | 0.25 | T2, T3 | C |
| T5 | Author `docs/design-system/figma-mirror-maintenance-protocol.md` (owner + cadence + code→Figma propagation step) + reference from both contribution guides | docs | docs | 0.5 | T1 | D |
| T6 | Implement `figma-mirror-staleness` advisory — detects drift between code tokens/components and last-audited mirror snapshot; emits Mechanism A coverage to `gate-coverage.jsonl`; advisory-only | infra | dev | 0.5 | T1 | D |
| T7 | Unit test for T6 advisory (drift-detected fires / no-drift passes; coverage row emitted) | test | qa | 0.25 | T6 | D |
| T8 | (Conditional) corrective Figma-mirror edits via MCP — only if T1 finds minor drift (≥50%, ≤ cheap-to-fix); else mark skipped | audit | design | 0.25 | T1 | B |
| T9 | Closeout docs: case study + honesty-ledger FT2-FH-005 closure note + FRAMEWORK-FACTS advisory-count bump | docs | docs | 0.25 | T2,T3,T4,T5,T6 | — |

## Notes
- **T1 is the gate.** Its fidelity % drives kill-criteria (<50% → STOP + re-scope) and seeds the mirror-snapshot baseline that T6's advisory diffs against.
- **T6 ships advisory-only** — no calibration-window flip planned at ship (operator decision). It still ships with a unit test (T7) per new-check discipline; a try-repo fixture is optional since it's not an enforced pre-commit gate.
- **T8 is conditional** — resolves to `done` (edits made) or `skipped` (no drift / drift too large → folded into kill-criteria escalation).
- No iOS app code changes anywhere → no `xcodebuild` / `ui-audit` / `tokens-check` impact.
