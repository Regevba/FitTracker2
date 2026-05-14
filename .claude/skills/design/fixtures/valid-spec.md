# Sample Design Spec (FIXTURE — valid-spec)

> Fixture for `/design preflight` self-test (spec-side check that delegates to `/ux preflight`). All tokens cited below must exist in the codebase.

## Tokens used

- `AppColor.Brand.primary` — primary brand color
- `AppColor.Surface.primary` — primary surface background
- `AppColor.Border.hairline` — hairline border
- `AppText.body` — body text style (slightly different namespace than the ux fixture to catch independent regressions)

## Components used

None — minimal fixture focuses on token detection.

## Figma node IDs

(out of scope for fixture testing — covered by live MCP checks)

## Expected preflight outcome

PASS — every token above exists in `FitTracker/Services/AppTheme.swift` or `FitTracker/DesignSystem/`.
