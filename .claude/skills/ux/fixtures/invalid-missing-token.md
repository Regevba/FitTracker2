# Sample UX Spec (FIXTURE — invalid-missing-token)

> Fixture for `/ux preflight` self-test. This file deliberately cites a token that does NOT exist in the codebase. `make preflight-fixture-test` expects preflight to report at least one P0 finding on this file. If preflight passes this file silently, the regression has shipped.

## Tokens used

- `AppColor.Brand.primary` — real token, should pass
- `AppColor.fixtureSentinelDoesNotExist` — **deliberately fake**; preflight MUST flag this as P0
- `AppSpacing.small` — real token, should pass

## Components used

None.

## Patterns used

None.

## Expected preflight outcome

FAIL — `AppColor.fixtureSentinelDoesNotExist` does not resolve in `AppTheme.swift` or `DesignSystem/`. Preflight must report it as a P0 finding.
