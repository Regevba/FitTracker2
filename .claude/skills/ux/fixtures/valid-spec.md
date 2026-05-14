# Sample UX Spec (FIXTURE — valid-spec)

> Fixture for `/ux preflight` self-test. All tokens cited below must exist in the codebase. If `make preflight-fixture-test` fails on this file, it means either a token was removed from `AppTheme.swift` OR the preflight regex stopped detecting it.

## Tokens used

- `AppColor.Brand.primary` — primary brand color
- `AppColor.Surface.primary` — primary surface background
- `AppColor.Text.primary` — primary text color
- `AppColor.Border.hairline` — hairline border
- `AppSpacing.small` — 12pt or 16pt spacing increment

## Components used

None — minimal fixture focuses on token detection.

## Patterns used

None — minimal fixture focuses on token detection.

## Expected preflight outcome

PASS — every token above exists in `FitTracker/Services/AppTheme.swift` or `FitTracker/DesignSystem/`.
