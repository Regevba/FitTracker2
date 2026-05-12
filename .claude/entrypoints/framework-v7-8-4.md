# Framework v7.8.4 Pre-v7.9 Calibration & Doc-Debt Cleanup — cold-start entrypoint

> One-page summary of v7.8.4 for any agent or developer arriving cold.
> If you only read one document about v7.8.4, read this. Then follow the
> "Canonical sources" section to drill in.

**Shipped:** 2026-05-12, single-session patch.
**Predecessor:** [v7.8.3 Cross-Repo State-Sync](framework-v7-8-3.md) (shipped 2026-05-11).
**Successor:** v7.9 Promotion (decision date 2026-05-21; ship ~2026-06-01 per [infra master plan](../../docs/master-plan/infra-master-plan-2026-05-12.md) §2.2).

## Why v7.8.4 exists

The 2026-05-12 session-open status check surfaced:

1. **33 BROKEN_PR_CITATION false positives** from an empty `.cache/gh-pr-cache.json` — every PR citation flagged as broken until `make refresh-pr-cache` ran.
2. **6 advisory findings** cluttering the v7.9 promotion-decision telemetry (4 TIER_TAG_LIKELY_INCORRECT + 2 CACHE_HITS_AUTO_INSTRUMENTATION_INACTIVE).
3. **5 LOW doc-debt items** predating the v7.8.3 schema (`dual-outlet-pattern.md` had no frontmatter; `framework-v7-8-branch-isolation-case-study.md` had `primary_metric` but not the canonical `success_metrics`; `ios-code-connect/state.json` had no case-study linkage).
4. **Stale `.claude/active-feature` lockfile** pointing at a closed feature (`ios-ui-audit-p1-burndown`).
5. **Zero phase snapshots ever captured** despite the `make snapshot-phase` protocol shipping in v7.8.3 Phase 0.

The v7.9 promotion decision on **2026-05-21** evaluates 4 advisory gates against criterion #2 ("no false positives"). A noisy baseline ambiguates that criterion. v7.8.4 is the calibration pass that gives v7.9 a clean comparison floor.

## What v7.8.4 ships (single-session patch)

| Item | What it does | File(s) | Mode |
|---|---|---|---|
| **PR cache freshness gate** | `scripts/ensure-pr-cache-fresh.py` auto-refreshes `.cache/gh-pr-cache.json` when empty, missing, or >24h old. Wired into `make integrity-check` + `.github/workflows/integrity-cycle.yml`. | new script + `Makefile` + workflow | Active (operability) |
| **TIER_TAG heuristic narrowed** | 3 fixes in `scripts/validate-tier-tags.py`: (a) skip target/kill/threshold claims (forward-looking declarations), (b) `\b` word-boundary on unit regex (eliminates `h↔hook`, `s↔schema`, `d↔declared` false matches), (c) skip claims whose context contains another tier marker (number likely belongs to the second tier). | `scripts/validate-tier-tags.py` | Heuristic improvement |
| **T1 reference ledger** | New `.claude/shared/case-study-t1-references.json`. Pins 3 known-correct T1 measurements whose values are derived/computed and not naturally in `measurement-adoption.json` or `documentation-debt.json` (57% ui-audit P1 reduction, 92min stress-test wall time, 2/9 post-v6 adoption snapshot). | new ledger | Active |
| **cache_hits[] backfills** | `framework-v7-8-branch-isolation` (33 reads) + `import-training-plan` (95 reads) populated from Mechanism C session-ledger attributions. | 2 state.json files | Backfill |
| **Doc-debt closures (5/5 LOW)** | `dual-outlet-pattern.md` gets full YAML frontmatter; `framework-v7-8-branch-isolation-case-study.md` gets `success_metrics`; `ios-code-connect/state.json` gets `case_study_type: no_case_study_required` + exemption reason. | 3 files | Schema completion |
| **Lockfile reset** | `.claude/active-feature` cleared (was: stale `ios-ui-audit-p1-burndown`). | 1 file | Hygiene |
| **Pre-v7.9 snapshot baseline** | `make snapshot-phase PHASE=pre-v7-9-baseline FEATURE=framework-v7-8-branch-isolation` writes 12 files to `~/Documents/FitTracker2-backups/2026-05-12-framework-v7-8-branch-isolation-pre-v7-9-baseline/` with sha256-verified MANIFEST. | backup dir (off-SSD) | Captured |
| **CLAUDE.md v7.8.4 section** | New section between v7.8.3 and "Known Mechanical Limits" documenting all of the above. | `CLAUDE.md` | Documentation |
| **Honesty ledger entry FT2-FH-002** | Records v7.8.4 calibration rationale + the false-positive incident that motivated `PR_CACHE_STALE`. | honesty ledger | Documentation |

## Outcome

`make integrity-check` baseline at v7.8.4 ship:

| Stage | Findings | Advisory |
|---|---|---|
| Session open (stale cache, pre-fix) | 35 | 9 |
| After `make refresh-pr-cache` + PHASE_LIE fix | 0 | 9 |
| After cache_hits backfill + TIER_TAG re-tags | 0 | 6 |
| After T1 reference ledger + regex tightening + intervening-tier filter | 0 | 1 |
| After 2/9 snapshot pin | **0** | **0** |

Doc-debt: 6 open items → **1 open item** (the remaining is the forward-only-grandfathered `kill_criteria_resolution_missing` ADVISORY per CLAUDE.md design).

## What v7.8.4 explicitly does NOT do

- **No v7.9 promotion.** v7.8.4 prepares the telemetry baseline; v7.9's 2026-05-21 decision evaluates the 4 advisory gates against 7+ days of `gate-coverage.jsonl` data.
- **No new write-time gates** (other than the operability `ensure-pr-cache-fresh.py`).
- **No master plan v8.x F-candidate work.** F1–F13 + V8-I1–I7 remain queued for 2026-05-21 prioritization pass per master plan §3.3.
- **No HADF Phase 2-bis activation.** Sub-exp 1 earliest launch still 2026-05-23 per spec §11.

## How to verify v7.8.4 is working

```bash
# PR cache freshness gate
ls scripts/ensure-pr-cache-fresh.py && \
  python3 scripts/ensure-pr-cache-fresh.py --max-age-hours 24

# Auto-refresh wired into Makefile target
grep -A 2 "^integrity-check:" Makefile | grep ensure-pr-cache-fresh

# Auto-refresh wired into CI workflow
grep "Refresh PR cache" .github/workflows/integrity-cycle.yml

# TIER_TAG heuristic improvements
grep "is_target_or_kill_claim\|INTERVENING_TIER_RE" scripts/validate-tier-tags.py

# T1 reference ledger present
ls .claude/shared/case-study-t1-references.json

# Clean integrity baseline
make integrity-check  # expect: 0 findings + 0 advisory
```

## Canonical sources

| Source | Path |
|---|---|
| **v7.8.4 CLAUDE.md section** | [`CLAUDE.md`](../../CLAUDE.md) — "v7.8.4" section |
| **PR cache freshness script** | [`scripts/ensure-pr-cache-fresh.py`](../../scripts/ensure-pr-cache-fresh.py) |
| **TIER_TAG validator (v7.8.4 narrowed)** | [`scripts/validate-tier-tags.py`](../../scripts/validate-tier-tags.py) |
| **T1 reference ledger** | [`.claude/shared/case-study-t1-references.json`](../case-study-t1-references.json) |
| **Pre-v7.9 snapshot** | `~/Documents/FitTracker2-backups/2026-05-12-framework-v7-8-branch-isolation-pre-v7-9-baseline/` (off-SSD) |
| **Infra master plan (umbrella)** | [`docs/master-plan/infra-master-plan-2026-05-12.md`](../../docs/master-plan/infra-master-plan-2026-05-12.md) |
| **v7.8.3 cold-start entrypoint (predecessor)** | [`framework-v7-8-3.md`](framework-v7-8-3.md) |
| **v7.8 cold-start entrypoint** | [`framework-v7-8.md`](framework-v7-8.md) |

## v7.9 anchor points unchanged from v7.8.3 cold-start

- Decision date **2026-05-21**.
- 4 advisory gates evaluated: `BRANCH_ISOLATION_VIOLATION` (Modes B+C), `FEATURE_CLOSURE_COMPLETENESS`, Mechanism A coverage gates, Mechanism C session-attribution gate.
- v7.8.4 calibration adds nothing to the v7.9 docket — purely floor-clearing for criterion #2 (no false positives).
- 13 v8.x F-candidates + 7 V8-icebox items remain queued per master plan §3.

## Forward delta

After v7.8.4 ships, the next session should:

1. Wait for v7.9 promotion decision 2026-05-21
2. Monitor `gate-coverage.jsonl` for the 4 advisory gates' coverage signals
3. Re-run `make integrity-check` daily until 2026-05-21 to confirm the 0+0 baseline holds
4. Resume HADF Phase 2-bis Sub-exp 1 launch (earliest 2026-05-23) per spec §11
