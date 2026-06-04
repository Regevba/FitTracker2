# `_baseline/` — F16 try-repo harness baseline

> Canonical minimally-valid `state.json` consumed by `make_state_json(overrides, dest)` in `scripts/tests/_try_repo_fixtures.py`.

## What this is

A state.json that is **deliberately constructed to satisfy every write-time gate** at v7.9.1. Per-gate fixtures under `tests/fixtures/<gate-id>/{positive,negative}/state.json.yaml` carry **only the overrides** — partial-record YAML — that the builder merges with this baseline.

## Why this matters

- **Maintenance:** schema additions update this file only; per-gate fixtures don't need re-touching.
- **Drift protection:** Phase 5 round-trip test loads this file → feeds through builder with empty overrides → asserts byte-identity. If drift, fail loud.
- **Readability:** per-gate fixture YAML only mentions the field(s) under test, not the surrounding boilerplate.

## When to mutate

- New required state.json field at the framework level (v7.9.2+ schema bump). Add the field here AND to the builder's known-keys list.
- Gate semantics change (e.g., a gate now also fires on field X being non-empty). May require baseline tweaks if the baseline accidentally trips a new condition.
- **NEVER** mutate this baseline to fix a fixture-specific issue. Per-fixture YAML overrides are the right tool.

## What this does NOT cover

- `case-study.md` content — fixtures supply their own (canonical, not partial)
- `.log.json` content — fixtures supply their own (canonical)
- `.githooks/pre-commit` script — exercised end-to-end by the try-repo harness

## Cross-references

- Builder: `scripts/tests/_try_repo_fixtures.py::make_state_json`
- Round-trip test: `scripts/tests/test_try_repo_baseline.py::test_baseline_round_trip_byte_identity`
- PRD: `.claude/features/f16-try-repo-harness/prd.md` Q2 (LOCKED hybrid fixture format)
- Tasks: `.claude/features/f16-try-repo-harness/tasks.md` T2
