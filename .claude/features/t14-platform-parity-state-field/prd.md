# PRD — `platforms_tested` State Field (T14)

**Feature:** `t14-platform-parity-state-field` · **Work type:** Feature (`framework_feature`)
**Phase:** PRD · **Linear:** FIT-162 · **RICE:** 160.0 (R8 × I2 × C100% ÷ E0.1w)
**Spec source:** `docs/master-plan/test-coverage-master-plan-2026-05-13.md` §4 T14
**Research:** [`research.md`](research.md) (Q1/Q2/Q3 resolved 2026-06-07)

## 1. Problem & motivation

The framework records *that* a feature completed and *that* it has a case study,
but not *which platforms its tests actually exercised*. Multi-surface features
(iOS + web + ai-engine) can ship with single-surface test coverage and nothing
records or flags the asymmetry. T14 makes platform-test parity a structured,
queryable, gate-able property of every completed feature.

## 2. Goals / non-goals

**Goals**
- Add a `platforms_tested: {ios, web, backend, ai}` boolean field to the
  `state.json` schema.
- Extend `FEATURE_CLOSURE_COMPLETENESS` with an **advisory** sub-check requiring
  a non-empty `platforms_tested` (≥1 key `true`) at `current_phase=complete`,
  with framework-meta features exempt (Q2).
- Backfill all existing complete features automatically (Q1), 0 mandatory manual
  review.
- Document semantics in dev-guide §3/§4 + CLAUDE.md + fitme-story glossary.

**Non-goals**
- Per-platform coverage **percentages** (T15+, gated on R9 Track B 30-day data).
- Enforced mode at ship — advisory only; advisory→enforced flip is a future
  Enhancement at the ~v7.10 promotion window after a 14-day calibration (Q3).
- New cross-repo plumbing — rides the existing `state_owner` + reverse-sync.

## 3. Field specification

```jsonc
"platforms_tested": { "ios": false, "web": false, "backend": false, "ai": false },
"platforms_tested_provenance": "<authored | backfill-heuristic-<date> | backfill-heuristic-low-confidence | exempt:framework_meta>"
```

Semantics table is locked in [`research.md`](research.md) §"Field shape".
"Non-empty" = ≥1 key `true`. Exempt features carry `{}` + `exempt:framework_meta`.

## 4. Success metrics (from state.json — pre-registered)

- **Primary:** number of `current_phase=complete` transitions where
  `platforms_tested` is populated and non-empty.
- 100% of new post-promotion `complete` transitions carry non-empty
  `platforms_tested` (T1; measured via `gate-coverage.jsonl`).
- Zero false positives during the 14-day advisory calibration window.
- Backfill of all existing complete features done in a single mechanical PR
  (T1; measured by grep over `.claude/features/*/state.json`).

## 5. Kill criteria (pre-registered)

1. False-positive rate >5% during the advisory window (gate flags legitimately
   platformless features). — *Mitigated by Q2 exemption.*
2. Operator burden: >20% of new `complete` transitions have an empty array
   post-backfill, OR operators routinely cannot determine values. — *Mitigated
   by Q1 automatic backfill + locked semantics.*
3. Field semantics unclear in practice: operators ask >3× in a 30-day window
   what `backend`/`ai` means. — *Mitigated by the locked 4-key table + glossary.*

**Resolution cadence:** evaluated at the 14-day advisory window close before any
advisory→enforced flip; `kill_criteria_resolution` populated then.

## 6. Implementation plan (tasks)

| Task | Description |
|---|---|
| T1 | ✅ Resolve Q1/Q2/Q3 (this PRD + research.md) |
| T2 | Add `platforms_tested` + `platforms_tested_provenance` to the state.json schema in `scripts/check-state-schema.py` (additive; default `{}`) |
| T3 | Extend `FEATURE_CLOSURE_COMPLETENESS` with the **advisory** non-empty check at `complete`, with the Q2 exemption predicate; emit Mechanism A `{candidates, checked, skipped, skip_reasons}` |
| T4 | `scripts/backfill-platforms-tested.py` — single-commit backfill of all complete features per the Q1 heuristic + provenance flags; unit-tested |
| T5 | Update `docs/architecture/dev-guide-v1-to-v7-7.md` §3 schema + §4 gate catalog (+ F16 try-repo fixture pair per the new-gate discipline) |
| T6 | Update CLAUDE.md Data Integrity Framework section (new field + advisory sub-check) |
| T7 | Update fitme-story dev-guide mirror + glossary entry (cross-repo) |
| T8 | Source case study + showcase MDX (fitme-story) |
| T9 | 14-day advisory→enforced calibration window; promotion at ~v7.10 |

**Gate-test discipline (CLAUDE.md v7.9.1 F16):** T3's new sub-check ships with a
try-repo fixture pair under `tests/fixtures/PLATFORMS_TESTED_*/{positive,negative}/`
+ a dispatch test, per the "every new gate ships with a try-repo fixture" rule.

## 7. Rollout & reversibility

Advisory at ship (no commits blocked). Reversal = the same single-flag pattern
as v7.9 (`*_ADVISORY_MODE = True`), <5 min. Backfill is idempotent and
provenance-tagged, so re-running or reverting is safe.
