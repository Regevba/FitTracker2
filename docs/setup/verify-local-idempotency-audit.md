# `make verify-local` Idempotency Audit (R10, 2026-05-21)

> **R10 from dev-env audit.** Verifies that running `make verify-local` does
> not mutate tracked repo state — a property assumed by every CI workflow
> + local pre-merge check.

## Result

✅ **`make verify-local` is already idempotent.** No code changes needed.

## Audit method

Inspected every subtarget invoked by `make verify-local`:

```makefile
verify-local: tokens-check schema-check ui-audit ui-audit-drift \
              verify-web verify-ai verify-evals verify-ios \
              verify-timing verify-framework
```

For each subtarget, categorized write surfaces as:
- **🟢 read-only** — emits to stdout/stderr; no filesystem writes
- **🟡 gitignored writes** — writes to `.build/`, `dashboard/dist/`,
  `website/dist/`, or other gitignored directories (does NOT affect
  tracked repo state)
- **🔴 tracked writes** — would mutate the repo (none found in this audit)

| Subtarget | Surface | Notes |
|---|---|---|
| `tokens-check` | 🟢 read-only | Compares generated `DesignTokens.swift` vs `tokens.json`; exits 1 on drift. No writes. |
| `schema-check` | 🟢 read-only | Runs `python3 scripts/check-state-schema.py --all` (read-only inspection). |
| `ui-audit` | 🟢 read-only | Scans `FitTracker/Views/` for raw colors etc; emits findings to stdout. |
| `ui-audit-drift` | 🟢 read-only ✱ | Compares committed baseline vs regenerated; uses **backup-then-restore** pattern (`_tmp=$$(mktemp); cp $$_baseline $$_tmp; … cp $$_tmp $$_baseline`) so working tree is never left polluted. |
| `verify-web` | 🟡 gitignored writes | `npm test` + `npm run build` for `dashboard/` + `website/`. Outputs → `dist/` (gitignored). |
| `verify-ai` | 🟡 gitignored writes | `pytest` in `ai-engine/`. May create `__pycache__/` (gitignored). |
| `verify-evals` | 🟡 gitignored writes | Same as `verify-ai`; eval suite under `ai-engine/evals/`. |
| `verify-ios` | 🟡 gitignored writes | `xcodebuild build` → `.build/DerivedData/` (gitignored). No edits to `FitTracker/`. |
| `verify-timing` | 🟢 read-only | Inspects `.claude/features/*/state.json` phases + timing; emits report. |
| `verify-framework` | 🟢 read-only | Validates `.claude/shared/cache-metrics.json` exists + parses; per-feature cache audit. Emits report. |

✱ `ui-audit-drift` is the closest thing to a mutator in the chain. The
backup/restore is the right defense; we verified it works by inspecting
the recipe (lines 60-70 of `Makefile`).

## Defensive check added

`make verify-local-idempotent-check` — captures `git status --porcelain`
before + after `make verify-local`, asserts they are byte-identical.
Fails loud if any tracked file was added, modified, or deleted by
the verify run.

Use cases:
- Pre-merge sanity: `make verify-local-idempotent-check` once, ensure
  CI assumptions still hold
- Defense against future regressions: if a new subtarget gets added
  that quietly mutates tracked state, this check will catch it

## Why this audit matters

CI workflows assume `make verify-local` leaves the tree clean. If a
subtarget ever started writing into tracked files (e.g.
`measurement-adoption.json` got pulled into verify-local without a
backup/restore), pre-commit hooks + integrity-check would start flagging
"unrelated" mutations on every PR. That class of bug is hard to debug
because it's invisible until it appears in CI logs.

Today's audit confirms no such regression is present. The defensive
check is the standing guard.

## Related

- [R7 — `gh-pr-cache.json` freshness audit](#) — verified the cache is
  refreshed at 3 invocation surfaces (Makefile, CI workflow,
  preflight.py); no extension needed.
- Dev-env audit source:
  [`docs/research/2026-05-19-dev-env-audit-stability-and-scale.md`](../research/2026-05-19-dev-env-audit-stability-and-scale.md) R10
- Linear: [FIT-176](https://linear.app/fitme-project/issue/FIT-176)
