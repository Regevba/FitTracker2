# Design Pre-Merge Review — garmin-health-connection (Data Sources screen)

> Phase 6 gate · 2026-06-12 · reviewer: pm-workflow `/design pre-merge-review`
> Surface: PR #705 (`feature/garmin-health-connection` → `main`)

## Verdict: **PASS_WITH_NOTES**

## Gate checks

| Check | Result |
|---|---|
| `make ui-audit` P0 = 0 on touched view files | ✅ `DataSourcesScreen.swift` + `HealthDevicesSettingsScreen.swift` → 0 findings (the only 2 repo-wide P1s are on unrelated files: `HRVTrendChart.swift`, `AIFeedbackSettingsScreen.swift`) |
| Token-only styling (AppColor / AppText / AppSpacing / AppSize / AppRadius / AppMotion) | ✅ no raw literals |
| Component reuse vs net-new primitives | ✅ 100% existing Settings-v2 library primitives (`SettingsDetailScaffold`, `SettingsSectionCard`, `SettingsValueRow`, `SettingsSupportingText`, `EmptyStateView`, `StatusBadge`); only composition (`DataSourceRow`, `ConnectGuidanceView`) is net-new, no new visual vocabulary |
| `state.json.figma_node_ids` populated | ⚠️ empty — see disposition |
| PR description references Figma node IDs | ⚠️ N/A — see disposition |

## Figma disposition: **deferred_to_prompt**

This screen introduces **no net-new visual primitives** — every component it draws already
exists in the FitMe Design System Library (`0Ai7s3fCFqR5JXDW8JvgmD`) and in the shipped
Settings-v2 Code Connect mappings. `DataSourceRow` and `ConnectGuidanceView` are *compositions*
of those primitives, not new library components. There is therefore nothing net-new to push to
Figma via `/design build`, and `figma_node_ids` carries no design-review signal it wouldn't
already have from the existing Settings-v2 mappings.

Per the v4.X `/design build` contract, this is recorded as `figma_build_status =
"deferred_to_prompt"`: a portable build prompt is available at
[`docs/prompts/ui/2026-06-12-garmin-health-connection-design-build.md`](../../../docs/prompts/ui/2026-06-12-garmin-health-connection-design-build.md)
should a Figma frame ever be desired for documentation. This is the same disposition used for
prior library-only Settings screens. **Not a BLOCK** — the gate's intent (no unaudited net-new
visual vocabulary shipping unmapped) is satisfied because there is none.

## Gate

`state.json.pre_merge_review.design = "passed_with_notes"`. Does not block Phase 7.
