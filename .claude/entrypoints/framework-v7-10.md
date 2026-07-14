# Framework v7.10 — cold-start entrypoint

> One-page summary of v7.10 for any agent or developer arriving cold.
> If you only read one document about v7.10, read this. Then drill into the
> "Canonical sources" section.

**Shipped:** 2026-06-10.
**Predecessor:** [v7.9.1 Build Window](framework-v7-9.md) (shipped 2026-06-04) → [v7.9 Promotion](framework-v7-9.md) (2026-05-21).
**Current-state reference (live counts):** [`docs/FRAMEWORK-FACTS.md`](../../docs/FRAMEWORK-FACTS.md).

## Why v7.10 exists

v7.10 hardens the **observability of the gates themselves** — the meta-layer that watches whether each gate is actually running. No new product-facing gates; the change makes the silent-pass detector see checks it previously couldn't. It also closes two reader/index field-rename silent-passes of the `created`/`created_at` class (observed-patterns #24) at the measurement layer.

## What v7.10 ships

| Item | What | File | Mode |
|---|---|---|---|
| **`GATE_COVERAGE_ZERO` extension** | Reads the F17 `gate-last-fired.json` index; flags a gate gone silent vs the active corpus + a **0-candidate mis-wire detector** (a gate registered but `candidates==checked==skipped==0` runs but never reaches a candidate — distinct from a *healthy* zero-firing gate) | [`scripts/integrity-check.py`](../../scripts/integrity-check.py) (PR #689) | Advisory |
| **Cycle-time coverage emission** | `BROKEN_PR_CITATION` + `CASE_STUDY_MISSING_TIER_TAGS` + `PATTERN_SKILL_UNMAPPED` now emit `mode="cycle"` Mechanism A coverage (previously blind to the F17 index) | [`scripts/integrity-check.py`](../../scripts/integrity-check.py) (PR #689) | — |
| **Field-rename closure (#24)** | `measurement-adoption-report.py` read only legacy `complexity.cu_version` not canonical `cu_v2` (halved adoption; PR #687); `refresh-gate-last-fired.py` read only `timestamp`, dropping `w9.auto_isolate` rows keyed `ts` (PR #688) | reader scripts | — |

## Current canonical counts (reconciled 2026-07-14)

**v7.10 · 131 features · 33 instrumented gates (21 write-time + 9 cycle-time + 2 W9 hooks + 1 standalone), 28 firing · 0 integrity findings, 0 real regressions** (current as of 2026-07-14; at v7.10 ship these were 106 / 26 / 19). Full breakdown + gate list: [`docs/FRAMEWORK-FACTS.md`](../../docs/FRAMEWORK-FACTS.md).

> Earlier docs report different gate totals (25 / 27 / 30 / 33 / 34 / 37) — those are accurate records of earlier eras OR count a different denominator (mechanisms+CI+hooks ≈ 37 vs gate codes ≈ 26). Always check the date.

## Calibration ladder (date-gated)

- ~~**2026-06-18** — F16 try-repo harness advisory→enforced flip~~ ✅ **enforced 2026-06-17** (#764, 1d early)
- ~~**2026-06-20** — W9 drift-auto-isolation calibration~~ ⏸ **HELD at advisory** (reset to 06-28, then event-gated — 0 field firings)
- ~~**2026-06-21** — `PLATFORMS_TESTED` (T14) advisory→enforced review (B15)~~ ✅ **enforced 2026-06-21** (#781)
- ~~**2026-07-04** — R9 Track-B 30-day coverage read → feeds `GATE_TEST_MISSING`~~ ✅ **shipped 2026-07-04** (#849)
- ~~**~2026-06-30** — F4 `FRAMEWORK_VERSION_STALE` advisory→enforced~~ ✅ **enforced 2026-07-08** (#858)
- ~~**2026-07-13** — `CSV_TAXONOMY_DRIFT` advisory→enforced (B16)~~ ✅ **enforced 2026-07-13**
- **2026-08-12** — Data Freshness Audit #1 (uses F17 index) — *pending*

## Canonical sources

- Live current-state: [`docs/FRAMEWORK-FACTS.md`](../../docs/FRAMEWORK-FACTS.md)
- Project rules + version history: [`CLAUDE.md`](../../CLAUDE.md) "v7.10" section
- Dev guide: [`docs/architecture/dev-guide-v1-to-v7-7.md`](../../docs/architecture/dev-guide-v1-to-v7-7.md) (filename retained for ref-stability; content tracks v7.10)
- Gate definitions: [`scripts/check-state-schema.py`](../../scripts/check-state-schema.py) + [`scripts/integrity-check.py`](../../scripts/integrity-check.py)
- Self-test meta-analysis: [`docs/case-studies/meta-analysis/2026-06-10-second-what-if-self-test-all-layers.md`](../../docs/case-studies/meta-analysis/2026-06-10-second-what-if-self-test-all-layers.md)
