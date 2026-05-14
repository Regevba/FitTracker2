# `/design preflight` self-test fixtures

Closes P1.3 from [`docs/skills/skills-review-2026-05-13.md`](../../../../docs/skills/skills-review-2026-05-13.md) §5 (companion to [`.claude/skills/ux/fixtures/`](../../ux/fixtures/)).

## Purpose

`/design preflight` extends `/ux preflight` with Figma MCP liveness + Figma library accessibility + Code Connect write-access checks. This fixture corpus tests **only the spec-side symbol-existence check** (the part that delegates to `/ux preflight`). The Figma MCP / Code Connect parts cannot be fixture-tested mechanically — they require live MCP authentication + token presence, which are environment-dependent operability concerns rather than spec-correctness concerns.

The spec-side check is the most regression-prone surface (the Figma checks fail loudly via MCP errors; the spec check is the silent-pass class). Per `/design preflight` SKILL.md Step 1, it reads the same `ux-spec.md` and inherits the same token detection.

## Fixtures

| File | Expected outcome |
|---|---|
| `valid-spec.md` | All cited tokens exist → spec-side preflight passes |
| `invalid-missing-token.md` | Cites a fake symbol → spec-side preflight reports P0 |

The fixtures are deliberately distinct from `/ux preflight`'s — they cite a slightly different namespace mix so the test catches a regression in either skill independently.

## Driver

Same as `/ux preflight` — [`scripts/preflight-fixture-test.py`](../../../../scripts/preflight-fixture-test.py) globs all `.claude/skills/{ux,design}/fixtures/*-spec.md` files and applies the same outcome contract (filename prefix `valid-` must pass, `invalid-` must fail with at least one P0).

## Out of scope (no fixture coverage)

- Figma MCP `whoami` liveness check — requires authenticated MCP session
- Figma library `get_metadata` accessibility — requires Figma read access
- Code Connect token presence / publish dry-run — requires `FIGMA_ACCESS_TOKEN` env + npm + network
- `/design audit` token compliance check — covered by `make ui-audit` not preflight

Those checks have other safeguards: MCP failure surfaces as P1 advisory in `figma-bridge-status.json`; absent tokens surface as P2 in the same file. Both already fire loudly when broken.
