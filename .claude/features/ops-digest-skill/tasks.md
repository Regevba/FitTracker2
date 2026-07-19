# Tasks — ops-digest-skill (F23 / FIT-205)

Derived from `prd.md` + `integration-spec.md`. All shipped in PR #916.

| ID | Title | Type | Skill | Effort | Depends | Status |
|---|---|---|---|---|---|---|
| T1 | `scripts/ops-digest.py` — fail-soft 4-section composer (Deploy/CI, Integrity, Telemetry, Cadence) + overall verdict + JSON snapshot + exit-code contract | infra | ops | 0.4d | — | done |
| T2 | `scripts/tests/test_ops_digest.py` — 10 unit tests (verdict ordering, cadence window incl. struck/past rows, ISO parse, telemetry dual-read #24, render ok+fail, fail-soft assembly) | test | qa | 0.2d | T1 | done |
| T3 | `make ops-digest` target + `.PHONY` + `/ops digest` SKILL.md section + frontmatter sub-command list | docs | ops | 0.1d | T1 | done |

**Total effort:** ~0.7d. **Dependency order:** T1 → {T2, T3}.

## Test plan (Phase 5)
- `pytest scripts/tests/test_ops_digest.py` → 10/10 green.
- Live `make ops-digest` → `OVERALL: OK`, sections populated from real producers.
- `ast.parse` clean; ruff (CI-enforced) clean.

## Out of scope (follow-ups)
- Sentry error-trend section (gated on Sentry MCP auth) — additive, zero rework.
- Post-deploy GH Action wiring (`make ops-digest` on successful Vercel deploy) → converts the primary metric from T2→T1.
