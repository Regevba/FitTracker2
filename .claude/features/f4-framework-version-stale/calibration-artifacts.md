# F4 — `FRAMEWORK_VERSION_STALE` — Phase A Calibration Artifacts

> **Authored BEFORE code** per infra master plan §3.5 (Calibration Protocol for new layers).
> v8.x docket item **F4** (RICE 32.0, Theme C — Schema drift). Source:
> [`docs/master-plan/v8-x-build-docket-2026-06-15.md`](../../../docs/master-plan/v8-x-build-docket-2026-06-15.md) §0.B +
> [`docs/master-plan/v8-0-ready-now-workplan-2026-06-15.md`](../../../docs/master-plan/v8-0-ready-now-workplan-2026-06-15.md) Batch 2.

## Problem (the gap F4 closes)

The original F4 motivation (roadmap stress-test 2026-05-07, [case study §99]): **9 features
advanced through phases post-v7.6 while their `framework_version` field stayed stale** — they
were actively built under a newer framework but never recorded it. Existing coverage:

- `FRAMEWORK_VERSION_FORMAT` (check-state-schema.py:703) — validates the *format* (`vX.Y`) when
  the field is present. Says nothing about staleness.
- `tracking-drift-check.py` — detects open-but-shipped *planning rows*. Unrelated.

Nothing detects a feature being actively advanced under framework version N while still recording
version M < N. F4 closes that gap with an **advisory** drift detector (not silent auto-mutation —
the user's chosen scope; mutating operator state.json from a hook is higher-risk and departs from
advisory-first discipline).

## Gate design

| Field | Value |
|---|---|
| **Gate id / emission key** | `FRAMEWORK_VERSION_STALE` |
| **Function** | `check_framework_version_stale(state, path, *, coverage, enforce_transition)` |
| **File** | `scripts/check-state-schema.py` |
| **Dispatch site** | `validate_file()` loop, immediately after the `FRAMEWORK_VERSION_FORMAT` block; advisory findings printed to stderr in the main loop (same pattern as `PLATFORMS_TESTED`) |
| **Mode flag** | `FRAMEWORK_VERSION_STALE_ADVISORY_MODE = True` (independent flip, like `PLATFORMS_TESTED_ADVISORY_MODE`) |
| **Class** | Write-time gate, advisory → enforced after 14-day calibration |
| **Severity at ship** | advisory (prints to stderr, rc stays 0) |

### Fire condition

Fires when **all** hold (staged mode only):
1. `framework_version` is present and canonical-formatted (`vX.Y[.Z]` / `pre-vX.Y`).
2. The canonical current framework version is resolvable (see below).
3. A `current_phase` transition is detected (`old_phase != new_phase` via committed-HEAD diff) —
   i.e. the feature is being actively advanced.
4. The recorded `framework_version` is **strictly older** than the canonical current version.

### Canonical-version resolution (priority order)

1. `FRAMEWORK_VERSION_CANONICAL_OVERRIDE` env var (tests + operator escape hatch).
2. Parse `docs/FRAMEWORK-FACTS.md` under `REPO_ROOT` — the declared machine-derived SoT row
   `| **Framework version** | **vX.Y** ... |`.
3. Neither available → skip `canonical_version_unknown` (fail-open; never blocks a commit).

### Skip reasons (every candidate ends checked or skipped)

| Reason | Meaning |
|---|---|
| `not_staged_mode` | full-corpus scan (`enforce_transition=False`); transition undetectable |
| `field_absent` | no `framework_version` (FRAMEWORK_VERSION_FORMAT owns absence) |
| `malformed_version` | fails the canonical regex (FRAMEWORK_VERSION_FORMAT owns format) |
| `canonical_version_unknown` | FRAMEWORK-FACTS.md unreadable AND no override |
| `no_phase_change` | `current_phase` unchanged — feature not being advanced |
| `reverse_sync_mirror` | `state_owner_sync_origin` ends in `-reverse` (D-1 reverse-sync) |
| `explicit_exempt` | `framework_version_stale_exempt: true` (deliberate historical retention) |

When the comparison actually runs, `coverage.checked()` is recorded. A recorded version
≥ canonical is the **healthy** case (checked, no finding) — analogous to `STATE_OWNER_MISSING`
having candidates but 0 violations.

## Exemptions (false-positive guards)

- **Reverse-sync mirrors** — features whose `state_owner_sync_origin` ends in `-reverse` legitimately
  carry the origin repo's historical version (mirrors the `STATE_OWNER_LOCATION_MISMATCH` exemption).
- **Explicit retention** — `framework_version_stale_exempt: true` for deliberate cases (e.g. a
  retroactively-reconciled historical feature being touched without re-versioning).

## Try-repo fixtures (F16 discipline)

`tests/fixtures/FRAMEWORK_VERSION_STALE/{positive,negative}/state.overrides.json`:

- **positive** — `framework_version: "v7.5"` on the baseline (current_phase=implementation → None→impl
  transition); test injects `FRAMEWORK_VERSION_CANONICAL_OVERRIDE=v7.10`. Stale → advisory fires
  (asserted via **stderr advisory text**, since rc stays 0 in advisory mode — the advisory-gate
  analog of the rc!=0 assertion, per the `PLATFORMS_TESTED` precedent).
- **negative** — `framework_version: "v7.10"` (== injected canonical) → not stale → no advisory.

## Test plan (3 layers, per F16)

1. **Unit** (`scripts/tests/test_framework_version_stale.py`) — version-tuple parsing
   (`pre-v` ordering, patch defaulting), each skip reason, the stale/healthy comparison, exemptions,
   canonical resolution priority (override > FRAMEWORK-FACTS > None).
2. **Dispatch** (same file or `test_check_state_schema.py`) — monkeypatched `validate_file()` asserts
   the gate emits a Mechanism A `candidate` + `checked`/`skip`, and that a stale fixture produces an
   advisory finding (not an error).
3. **Try-repo** (`scripts/tests/test_try_repo_schema_gates.py` extension) — positive fixture →
   advisory string in stderr; negative → absent; both rc==0.

**Regression-proof:** the dispatch test asserts coverage *fires* (candidate≥1) so a future mis-wire
that stops the gate reaching a candidate is caught by `GATE_COVERAGE_ZERO`'s 0-candidate detector.

## Calibration ladder

| Phase | What | When |
|---|---|---|
| A | These artifacts | 2026-06-16 (this doc) |
| B | Advisory ship + measure 7d Mechanism A telemetry | 2026-06-16 → ~06-23 |
| C | Calibration review (skip-reason legitimacy, 0 false positives) | ~06-23 → ~06-30 |
| D | Promote decision (flip `FRAMEWORK_VERSION_STALE_ADVISORY_MODE = False`) | ~06-30 |
| E | Validate 7d enforced | ~06-30 → ~07-07 |

**Min 22 days advisory→enforced.** Reversibility: single-line flip of the mode flag.

## Kill criteria

1. **>0 false positives** in the advisory window (a fire that maps to a legitimately-stale-by-design
   feature) → narrow exemptions before promoting; do NOT flip.
2. **Canonical resolution unreliable** (FRAMEWORK-FACTS parse breaks on a reformat) → pin a
   machine-readable source before enforcing.
3. **Zero candidates across the window** (gate never reaches a transition) → mis-wire; investigate
   via `GATE_COVERAGE_ZERO`.

## Calibration outcome — PROMOTED 2026-07-08

Phase C/D review executed 2026-07-08 (8 days past the ~06-30 target; the flag stayed advisory in
the interim, no harm). **Verdict: PROMOTE.** `FRAMEWORK_VERSION_STALE_ADVISORY_MODE = True → False`
at [`scripts/check-state-schema.py`](../../../scripts/check-state-schema.py).

| §2.2 criterion | Result |
|---|---|
| 1. Coverage — ≥7d `{candidates, checked, skipped}` | ✓ **8 emission days** (2026-06-17 → 07-01), 40 fires / 387 candidates |
| 2. No false positives — every fire maps to a legitimate violation | ✓ 40 fires all true-positive; the two legit-stale classes route to **skips** (`reverse_sync_mirror` ×3, `explicit_exempt` ×5), never fires |
| 3. No silent skips — skip counts track real reasons | ✓ skip reasons: `no_phase_change` ×210, `not_staged_mode` ×129 (+ the 2 exempt classes) — all legit |
| 4. Reversibility — advisory restorable in <5 min | ✓ single-line flag flip |

**Kill criteria at review:** KC1 (>0 false positives) — none; KC2 (canonical resolution) — resolves
to **v7.10** from `docs/FRAMEWORK-FACTS.md`; KC3 (zero candidates) — 387 candidates, not zero. All clear.

**Corpus-scan safety:** 99 features carry a stale `framework_version` but 97 are `complete` and never
re-transition (cannot fire — mirrors the `PLATFORMS_TESTED` precedent). The 2 non-complete stale
features (`app-store-assets` v5.0, `orchid-v1-5` v7.7) are legitimate future catches: enforced mode
will require a `framework_version` bump the next time either advances a phase — the intended behavior,
not a false positive. `make integrity-check` post-flip: **0 findings** (full-corpus scans skip
`not_staged_mode`).

**Tests updated for enforced mode** (mirrors the PLATFORMS_TESTED flip): `test_framework_version_stale.py`
now asserts `advisory is False`; `test_try_repo_framework_version_stale.py` positive fixture now asserts
rc!=0 + gate-code marker (was `[ADVISORY]` + rc==0). 28/28 F4 tests + 24/24 schema-gate tests pass.

**Reversibility runbook:** flip back on `chore/f4-rollback` (`FRAMEWORK_VERSION_STALE_ADVISORY_MODE = True`),
revert the two test assertions, merge. <5 min.
