# Sample Design Spec (FIXTURE — invalid-missing-token)

> Fixture for `/design preflight` self-test (spec-side check). Cites a deliberately fake token. Preflight must flag it as P0.

## Tokens used

- `AppText.body` — real token
- `AppRadius.fixtureSentinelDoesNotExist` — **deliberately fake**; preflight MUST flag this as P0
- `AppSpacing.small` — real token

## Components used

None.

## Figma node IDs

(out of scope for fixture testing)

## Expected preflight outcome

FAIL — `AppRadius.fixtureSentinelDoesNotExist` does not resolve. Preflight must report it as a P0 finding.
