# iOS UI-Audit P1 Residual — 2026-05-26 audit

> Tier A audit pass per UI/UX Master Plan §2.5 (Design System Residual: "9 raw literals remaining across views"). Empirically verifies the actual P1 count against the plan's claim. **Finding: the 9-literals item is stale — current P1 count is 0.** This doc records the verification + flags a separate baseline-doc drift for follow-up.

---

## Empirical state (2026-05-26)

```text
$ make ui-audit
python3 scripts/ui-audit.py
UI audit — 101 files scanned, 21 skipped
  P0 (blocking): 0
  P1 (warning):  0
  files with findings: 0
```

**Result: P0 = 0, P1 = 0.** No raw literals, no magic numbers, no missing-asset findings, no a11y-button findings across all 101 in-build SwiftUI files (21 HISTORICAL v1 files correctly skipped).

## How the plan's "9 raw literals" claim became stale

| Date | Event | P1 count |
|---|---|---|
| 2026-04-10 (PR #133) | Initial baseline | 103 |
| 2026-05-05 | P0 burndown completed (separate effort) | 0 P0; P1 unchanged 103 |
| 2026-05-11 PR #292 | PR-1 of `ios-ui-audit-p1-burndown`: 4 AppSize tokens + magic-frame mass-sub | reduced |
| 2026-05-11 PR #294 | PR-2 of same: 3 AppText tokens + 23 font subs + 5 a11y labels + widen audit window. **Baseline regenerated** → 44 | 44 |
| 2026-05-12 → 2026-05-26 | Subsequent fix-as-you-touch + `ios-ui-audit-p1-drift-cleanup` (active feature, phase=complete in current state.json) | reduced to 0 |
| 2026-05-24 | UI/UX Master Plan §2.5 authored; claimed "9 raw literals remaining" + "drift +5 from 103 baseline" | — |
| 2026-05-26 | Live scanner reports 0; plan claim is **stale by ~2 weeks** | **0** |

The plan's "9 raw literals" was a snapshot from an interim audit state during the May 11 burndown window. The subsequent `ios-ui-audit-p1-drift-cleanup` feature closed those 9 (plus any others that drifted in) without updating the master plan §2.5 row.

## Baseline doc drift (separate follow-up needed)

`docs/design-system/ui-audit-baseline.md` was last regenerated **2026-05-11 via PR #294** and reports:

- P0: 0 (matches live)
- **P1: 44** (live = 0; 44 stale)
- Files with findings: **26** (live = 0; 26 stale)

The baseline doc is 15 days behind reality. `make ui-audit-baseline` (the regenerate target) needs to be run + the doc committed to bring the on-disk baseline in line with the live scanner.

**Recommended:** open a separate ≤30-min PR titled `chore(ui-audit): regenerate baseline doc — P1 44→0` that runs `make ui-audit-baseline`, commits the regenerated file, and updates the UI/UX Master Plan §2.5 to drop the now-stale "9 raw literals" row. Keep that PR distinct from this audit because the audit and the regeneration have separate review surfaces.

## What this audit closes

| UI/UX Master Plan §2.5 row | Status after this audit |
|---|---|
| "9 raw literals remaining across views (responsive micro-adjustments)" | ✅ **CLOSED 2026-05-26** — live scanner shows 0 raw literals (all DS-RAW-* rules + DS-MAGIC-* rules clean) |
| "P1 drift +5 from 103 baseline → current 108" | ✅ **STALE** — current is 0, not 108. Real number reflects `ios-ui-audit-p1-burndown` + `ios-ui-audit-p1-drift-cleanup` shipping the full burndown |

## Recommended next actions

1. **Master plan §2.5 update** — flip the "9 raw literals" row to STRIKETHROUGH-DONE with cross-reference to this audit (included in this PR)
2. **Baseline doc regeneration** (separate PR) — `make ui-audit-baseline` + commit
3. **Optional: tighten the fix-as-you-touch rule** — now that P1 is at 0, any new finding immediately stands out. Consider promoting P1 to a hard gate (parallel to P0) in `make ui-audit` once stable for 30 days

## Cross-references

- [`docs/design-system/ui-audit-baseline.md`](ui-audit-baseline.md) — stale; needs regen
- UI/UX Master Plan §2.5 Design System Residual (this audit closes 2 of the 4 residual rows: "9 raw literals" + "P1 drift +5")
- [`scripts/ui-audit.py`](../../scripts/ui-audit.py) — the scanner that produced this 0-finding state
- CLAUDE.md "Verification Layer" — describes the 10 audit rules
- `ios-ui-audit-p1-burndown` + `ios-ui-audit-p1-drift-cleanup` features (both `phase=complete`) — the work that took P1 from 103 → 0

## Audit metadata

- **Date:** 2026-05-26
- **Method:** `python3 scripts/ui-audit.py` on `chore/ui-ux-tier-a-bundle-2026-05-26` branch off `origin/main` HEAD `66916f1`
- **Files scanned:** 101 (21 v1 HISTORICAL + token-definition files correctly skipped)
- **Findings:** 0 P0 + 0 P1 + 0 files-with-findings
- **Confidence:** High — the scanner is the source of truth per CLAUDE.md "Verification Layer"; baseline doc is documentation that lags reality
