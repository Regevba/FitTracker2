# FitTracker Component Contracts

These are the minimum contracts shared components must document and preserve.

## Shared responsive contract

- Every shared component must document its min, ideal, and max width behavior when content or screen width changes.
- Every shared component with imagery, charts, or icons must document content mode, crop behavior, and what happens when the asset cannot fit.
- Text-bearing components must document line limits, scaling behavior, and what happens on compact iPhones before any platform-specific visual polish.
- Components should prefer flexible frames and semantic spacing over fixed pixel widths unless the geometry is intentionally rigid, such as a badge dot or circular icon target.

## `AppButton`

- Purpose: primary, secondary, tertiary, or destructive calls to action
- Required states: default, pressed, disabled, loading if applicable
- Accessibility: clear label, full-width option, icon should not be the only cue
- Responsive contract: label should wrap or compress gracefully before the button drops below a safe tap target
- Platform note: keep hierarchy intent constant even if layout changes on iPad/macOS or Android

## `AppCard`

- Purpose: canonical container for elevated, standard, quiet, and inverse content blocks
- Required states: default plus optional selected/highlighted variant at composition level
- Accessibility: preserve readable contrast and predictable padding
- Responsive contract: card content should stretch vertically before horizontal clipping is introduced
- Platform note: surface role should remain semantic even when materials or elevation differ

## `AppMenuRow`

- Purpose: list/detail row with optional subtitle and one clear trailing affordance
- Required states: default, pressed, destructive tint when needed, disabled when relevant
- Accessibility: full row should behave as one tap target
- Responsive contract: subtitle and metadata must wrap without breaking the tap target
- Platform note: maps to settings/list rows on Apple and list items/settings rows on Android

## `AppSelectionTile`

- Purpose: selectable option for compact pickers, segmented controls, and mode switches
- Required states: unselected, selected, pressed, disabled
- Accessibility: selected state must be communicated by more than color alone
- Responsive contract: tile width should use min, ideal, and max sizing instead of one fixed width when used in horizontal carousels
- Platform note: can map to Material 3 segmented buttons or filter chips depending on context

## `AppInputShell`

- Purpose: canonical container for text entry, secure entry, search, and compact numeric input
- Required states: default, focused, disabled, error when composed with an inline message
- Accessibility: field label should be explicit and placeholders should not be the only cue
- Responsive contract: compact numeric fields may define an ideal width, but should still permit safe compression on smaller iPhones
- Platform note: maps to Apple form inputs first and Material text field containers by role, not by exact styling

## `AppFieldLabel`

- Purpose: shared field label plus optional helper line above an input or grouped control
- Required states: default and helper-text variant
- Accessibility: label should remain visible even after input has content
- Platform note: usable across forms, sheets, and compact control clusters

## `AppQuietButton`

- Purpose: secondary utility action with lower visual weight than a primary CTA
- Required states: default, pressed, disabled
- Accessibility: label and icon should still clearly communicate action
- Platform note: maps to secondary actions, utility rows, or quiet buttons across Apple and Material

## `MetricCard`

- Purpose: single high-signal metric with value, unit, optional trend, and status
- Required states: data present, missing data, neutral trend
- Accessibility: expose a readable summary string for VoiceOver
- Platform note: hierarchy and density can adjust, but metric/value relationship should stay consistent

## `ReadinessCard`

- Purpose: compact rotating summary of readiness, recovery, nutrition, and weekly health context
- Required states: baseline-building, populated metrics, missing sub-metrics, and time-based rotation/manual page changes
- Accessibility: each page should preserve readable summaries without relying only on color or animation
- Platform note: stays Apple-first in composition, but maps conceptually to a high-signal overview card on Android/Pixel rather than a platform-identical clone

## `ChartCard`

- Purpose: chart shell with title, period label, trend indicator, and chart body
- Required states: populated, empty, loading, error
- Accessibility: chart should have a textual summary or accessible fallback
- Responsive contract: chart header and legends should collapse or wrap before the chart body becomes unreadable
- Platform note: chart interaction may differ by platform, but header semantics remain the same

## `StatusBadge`

- Purpose: compact semantic status or taxonomy label
- Required states: default plus semantic color variants
- Accessibility: do not rely on color alone; text must remain visible and concise
- Platform note: can map to chips/badges across Apple and Material 3

## `EmptyStateView`

- Purpose: consistent explanation plus optional next action when there is no content yet
- Required states: empty informational, empty actionable, transient no-results
- Accessibility: title and action should communicate what to do next
- Platform note: stays conceptually the same across Apple, Android, and larger layouts
