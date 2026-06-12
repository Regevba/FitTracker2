# Design Build Prompt (deferred) — Data Sources screen

> Feature: `garmin-health-connection` · generated 2026-06-12 · status: **deferred_to_prompt**
> This screen ships with **no net-new visual primitives** — it composes existing
> Settings-v2 library components. This prompt exists only for optional documentation
> parity; no Figma frame is required for the gate.

## If a Figma frame is ever desired

Build `DataSourcesScreen` in the FitMe Design System Library
(`0Ai7s3fCFqR5JXDW8JvgmD`) by composing the already-mapped primitives:

- `SettingsDetailScaffold` (gradient bg + `SettingsHomeHeader` + scroll)
- Card A "Connected sources" — `SettingsSectionCard` containing N × `DataSourceRow`
  (icon badge `AppSize.iconBadge` · title `AppText.button` · status line
  `AppText.subheading` · trailing `StatusBadge` pill · optional signal-chip row)
- Card B "How this works" — `SettingsSectionCard` with `SettingsValueRow`
  ("Apple Health" → Connected/Not granted) + `SettingsSupportingText`
- Empty state (HK not granted): `EmptyStateView` (icon `heart.text.square`, CTA "Allow Access")
- Guided sheet `ConnectGuidanceView` — 3 numbered step rows + "Open Health App" CTA
  (`AppSize.ctaHeight`, `AppRadius.button`, `AppColor.Accent.primary`) + "Done"

All tokens already exist in the library. After building, write captured node IDs back to
`state.json.figma_node_ids` and add a row to `docs/design-system/figma-code-sync-status.md`.
