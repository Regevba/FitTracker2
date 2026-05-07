# Design Pre-Merge Review — `ucc-passkey-auth` — 2026-05-07

**Phase 6 sub-step 6c** · gate per v4.X skill-layer protocol
**Companion:** [`ux-pre-merge-review-2026-05-07.md`](./ux-pre-merge-review-2026-05-07.md)

---

## v4.X gate checklist

| Gate | Standard verification | This feature |
|---|---|---|
| `make ui-audit` P0 = 0 | iOS-side scanner | **N/A** — feature is fitme-story-only (web). iOS scanner doesn't apply. fitme-story has no equivalent P0 audit; tsc + next build clean is the structural equivalent. ✓ |
| `state.json.figma_node_ids` populated | every screen has a node ID | **N/A by design** — `figma_build_status: "deferred_to_prompt"` per [`design-preflight-2026-05-07.md`](./design-preflight-2026-05-07.md). Dashboard has no Figma mapping. |
| PR description references Figma node IDs | UI-touching PRs | **Adapted** — PR description will reference the portable design build prompt at [`docs/prompts/ui/2026-05-07-ucc-passkey-auth-design-build.md`](../../../docs/prompts/ui/2026-05-07-ucc-passkey-auth-design-build.md), the documented v4.X escape hatch (operator can reconstruct Figma at any time). |

## Design system compliance (re-verified at merge)

| Check | Result |
|---|---|
| 0 raw hex literals in feature code | ✓ verified via grep (no `#` followed by 6 hex chars in `src/lib/auth/`, `src/app/api/auth/`, `src/components/control-room/Auth*`, `src/app/control-room/sign-in/`, `src/app/control-room/settings/{devices,audit}/`) |
| Every color = Tailwind utility OR `var(--*)` ref | ✓ |
| Every font = `--font-sans` / `--font-serif` token | ✓ |
| Every spacing = Tailwind scale (no `style={{ padding: '13px' }}`) | ✓ |
| Every radius = Tailwind utility (`rounded-xl` / `rounded-3xl` / `rounded-full`) OR `rounded-[28px]` matching the `<Panel>` primitive | ✓ |
| Dark-mode coverage on every screen | ✓ — all components use `dark:` variants for borders, bg, text |
| Reduced-motion safe | ✓ — global rule in `globals.css` covers all animations |

## Visual language match (against design build prompt)

| Element | Spec | Code |
|---|---|---|
| Sign-in panel: 28px radius, 58ch max-width, gradient-bg shadowed in light | spec §4.1 | ✓ matches `<section>` chrome in `page.tsx` |
| Brand mark: 96 px tall, brand-coral bg, white "F" serif | spec §4.1 | ✓ matches |
| Primary button: brand-indigo bg, full-width, h-12, white text | spec §4.1 | ✓ matches `<AuthPasskeyForm>` |
| Inline error banner: rose-500/15 bg, AlertTriangle icon, retry CTA | spec §4.1 | ✓ matches |
| Devices table: 5-column, type pill, inline-pill revoke | spec §4.3 | ✓ matches `<DevicesTable>` |
| Audit log: filter chips + click-to-expand row | spec §4.4 | ✓ matches `<AuditTable>` + `<AuditEventRow>` |
| AuditLogPanel: 3-stat + suspicious banner + recent-5 + link | spec §4.5 | ✓ matches |

## v7.8.1 sub-step 6f — kill_criteria_resolution check

PRD §6 declares `kill_criteria`:

> "If passkey registration ceremony fails on > 5% of attempted devices in week 1, fall back to UCC_AUTH_MODE=both and reopen scope."

`state.json.metrics.kill_criteria` is non-empty — therefore `kill_criteria_resolution` MUST be populated at Phase 8 closure (Q7 of `FEATURE_CLOSURE_COMPLETENESS` gate). **Flagged as a Phase 8 deliverable; not a Phase 6 blocker** since the kill criterion has a deferred resolution window (T+7d post-cutover).

Phase 8 acceptance: `kill_criteria_resolution` = "Pending — week-1 telemetry gate. Resolution recorded at T+7d post-`UCC_AUTH_MODE=both` ship in case-study Section 99."

## Verdict

✅ **PASS_WITH_NOTES** — all gates pass; the Figma node IDs check is N/A by documented design (web dashboard has no Figma mapping; portable prompt is the escape hatch). `kill_criteria_resolution` flagged for Phase 8 follow-through.

## State.json mutation

```json
"pre_merge_review": {
  "design": "passed_with_notes",
  "design_review_artifact": ".claude/features/ucc-passkey-auth/design-pre-merge-review-2026-05-07.md",
  "design_findings": { "p0": 0, "p1": 0, "p2": 0 },
  "design_notes": [
    "Figma node IDs not applicable — dashboard has no Figma mapping. Portable prompt is the v4.X escape hatch (figma_build_status: deferred_to_prompt).",
    "PR description references docs/prompts/ui/2026-05-07-ucc-passkey-auth-design-build.md instead of node IDs.",
    "kill_criteria_resolution flagged for Phase 8 closure (Q7 v7.8.1 FEATURE_CLOSURE_COMPLETENESS gate)."
  ]
}
```
