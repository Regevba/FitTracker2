# `/ux preflight` self-test fixtures

Closes P1.3 from [`docs/skills/skills-review-2026-05-13.md`](../../../../docs/skills/skills-review-2026-05-13.md) §5.

## Purpose

These fixtures are a **regression test** for the mechanical core of `/ux preflight` — the part that extracts `App{Color,Text,Spacing,Radius,Motion,Size,...}.*` token references from a `ux-spec.md` and verifies each one exists in the codebase.

The point isn't to test the SKILL.md prompt directly (it's an agent skill, not a script) — it's to provide a stable corpus that:

1. **Catches preflight prompt-drift.** If a future SKILL.md edit accidentally drops the AppRadius detection regex, the `invalid-missing-token.md` fixture will silently pass when it should fail. The driver catches that.
2. **Documents the contract.** Real example specs that pass/fail are clearer than prose-only spec descriptions.
3. **Wires into CI.** `make preflight-fixture-test` runs the driver against all fixtures; failure exits non-zero.

## Fixtures

| File | Expected outcome |
|---|---|
| `valid-spec.md` | All cited tokens exist in codebase → preflight passes |
| `invalid-missing-token.md` | Cites `AppColor.thisDoesNotExist` → preflight reports P0 finding |

## Driver

[`scripts/preflight-fixture-test.py`](../../../../scripts/preflight-fixture-test.py) — extracts tokens from each fixture, greps the codebase, asserts the outcome matches the filename prefix (`valid-*` must pass, `invalid-*` must fail with at least one P0).

Exit code: 0 if all fixtures behave as expected, 1 otherwise.

## When to update

When `/ux preflight` SKILL.md changes its token-extraction regex set OR its grep target paths:

1. Update `valid-spec.md` to cite a token from any newly-supported namespace
2. If a namespace is dropped, remove related citations from `valid-spec.md`
3. Update `invalid-missing-token.md` to cite a still-supported but truly missing symbol
4. Run `make preflight-fixture-test` — must exit 0
