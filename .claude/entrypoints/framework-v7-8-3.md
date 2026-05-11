# Framework v7.8.3 Cross-Repo State-Sync — cold-start entrypoint

> One-page summary of v7.8.3 for any agent or developer arriving cold.
> If you only read one document about v7.8.3, read this. Then follow the
> "Canonical sources" section to drill in.

**Shipped:** 2026-05-11 across 10 PRs in 2 repos.
**Predecessor:** v7.8.2 Cross-Repo Telemetry Asymmetry (shipped 2026-05-08).
**Successor:** v7.9 Promotion (decision date 2026-05-21; ship ~2026-06-01).

## Why v7.8.3 exists

The 2026-05-08 fitme-story public-site audit + HADF Phase 2-bis brainstorm surfaced an inflection point: the framework had grown a real cross-repo problem (state.json files in two repos, BROKEN_PR_CITATION dropping `[fitme-story#N]` cites, `gate-coverage.jsonl` only emitting in FT2). v7.8.2 documented the disposition; v7.8.3 implements the bidirectional contract. Without v7.8.3, the next major experiment campaign (HADF Phase 2-bis, ~2 weeks wall-clock, 9,750 records) would re-encounter Phase 2's "in-flight infra change collides with running campaign" anti-pattern.

## What v7.8.3 ships (5 phases × 10 PRs in one day)

| Mechanism | What it does | Phase | PRs | Mode |
|---|---|---|---|---|
| **V2 promotion** | `CACHE_HITS_EMPTY_POST_V6` (advisory in v7.8) → `CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT` (ENFORCED). Closes the v7.7 silent-pass motivating gap. | 0 | FT2 #298 | Enforced |
| **V9 extension** | Mechanism E custom git merge driver (`scripts/merge-driver-dedup.py`) extended to cover `.claude/logs/<feature>.log.json` (was: 2 ledgers only). Removes the per-feature contemporaneous-log conflict-resolution friction. | 0 | FT2 #298 | Active |
| **Snapshot protocol** | `scripts/snapshot-phase-completion.sh` + `make snapshot-phase PHASE=<id>` writes per-phase off-SSD backup with sha256-verified MANIFEST. | 0 | FT2 #298 | Active |
| **D-3 unified PR cite cache** | `scripts/refresh-pr-cache.py` populates `.cache/gh-pr-cache.json` for both repos. `_load_pr_cache()` morphed from `set[int]` to multi-repo `dict`. New `resolve_pr_cite()` routes match groups to correct repo. Closes BROKEN_PR_CITATION's silent-skip on `[fitme-story#N]` + URL-form cites. 63/63 retroactive cite validation passes. | 1 | FT2 #299 | Enforced |
| **C-4 telemetry aggregator** | `fitme-story/scripts/sync-from-fittracker2.ts` extended to mirror FT2 `gate-coverage.jsonl` → `src/data/integrity/gate-coverage-ft2.jsonl`. New `gate-coverage-aggregator.ts` time-sorts both repos' streams. `/control-room/framework` page renders aggregated counts. | 1 | fitme-story #86 | Active |
| **C-5 morphed + 2 new state_owner gates** | 3 new write-time gates: `STATE_OWNER_MISSING` (required field), `STATE_OWNER_INVALID` (must be `{"ft2", "fitme-story"}`), `STATE_OWNER_LOCATION_MISMATCH` (file location must match `state_owner`; sync mirrors with `state_owner_sync_origin: "fitme-story-reverse"` are exempted). 62 features backfilled with `state_owner: "ft2"` in single mechanical commit. | 2 | FT2 #300 | Enforced |
| **D-1 reverse-sync GitHub Action** | `fitme-story/.github/workflows/reverse-sync-fitme-story-to-ft2.yml`. Path-filter trigger on `.claude/features/**/state.json`. Filters for `state_owner: "fitme-story"`, mirrors into FT2 with `state_owner_sync_origin: "fitme-story-reverse"` marker, opens auto-PR. Manual operator merge required per `feedback_no_auto_merge_without_approval.md`. | 3 | fitme-story #87 (+ #89 hotfix moving `secrets.*` check from job-level to step-level env-var indirection) | Active |
| **Cutover ceremony** | `3d-interactive-framework-flow-diagram` becomes the inaugural fitme-story-native feature (state.json in fitme-story repo, mirrored to FT2 via D-1). End-to-end validates the bidirectional contract. | 4 | fitme-story #88 + #90 + FT2 #301 | Validated |

## Cycle-time gate count: 13 → 16

The 3 new state_owner gates raise the cycle-time check-code count from 13 to 16. Total framework mechanism count reaches **33 mechanical gates + 5 advisories** post-v7.8.3.

## What v7.8.3 explicitly does NOT do

- **No HADF Phase 2-bis activation.** P2-bis Sub-exp 1 unblock criterion was met (Q1=S1 sequencing decision), but the 12-day soak window means earliest start is 2026-05-23.
- **No Mechanism C V3/V4/V5 promotion.** Q2=V2-only locked at brainstorm — V3 (framework_version on stub), V4 (experiment_outcome enum), V5 (`make complete-feature --dry-run`) deferred to v7.9 or later.
- **No Track 6 HADF gate activation in fitme-story UI.** Q3=OUT — that becomes a separate work item triggered post-Sub-exp-3 verdict.

## How to verify v7.8.3 is working

```bash
# V2 enforcement (gate name renamed)
grep "CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT" scripts/check-state-schema.py

# V9 extension (3 ledgers + feature logs)
grep "logs/.*log.json\|measurement-adoption-history\|documentation-debt" .gitattributes

# state_owner gates
grep "STATE_OWNER" scripts/check-state-schema.py | head

# Snapshot protocol
ls scripts/snapshot-phase-completion.sh && grep "snapshot-phase" Makefile

# D-3 cross-repo cite cache
ls scripts/refresh-pr-cache.py && python3 scripts/refresh-pr-cache.py --check

# C-4 aggregator (in fitme-story worktree)
ls /Volumes/DevSSD/fitme-story/src/lib/control-room/gate-coverage-aggregator.ts

# D-1 reverse-sync workflow (in fitme-story)
ls /Volumes/DevSSD/fitme-story/.github/workflows/reverse-sync-fitme-story-to-ft2.yml
```

## Canonical sources

| Source | Path |
|---|---|
| **v7.8.3 case study (5-phase ship + 6 dogfood catches + 3 v7.9 candidates)** | [`docs/case-studies/cross-repo-state-sync-impl-case-study.md`](../../docs/case-studies/cross-repo-state-sync-impl-case-study.md) |
| **v7.8.3 release umbrella spec** | [`docs/superpowers/specs/2026-05-11-cross-repo-state-sync-impl-design.md`](../../docs/superpowers/specs/2026-05-11-cross-repo-state-sync-impl-design.md) |
| **v7.8.3 implementation plan** | [`docs/superpowers/plans/2026-05-11-cross-repo-state-sync-impl.md`](../../docs/superpowers/plans/2026-05-11-cross-repo-state-sync-impl.md) |
| **fitme-story showcase (slot 29)** | `fitme-story/content/04-case-studies/29-cross-repo-state-sync-impl.mdx` |
| **DEV onboarding guide (v7.8.3)** | [`docs/architecture/dev-guide-v1-to-v7-7.md`](../../docs/architecture/dev-guide-v1-to-v7-7.md) |
| **v7.8 cold-start entrypoint (predecessor)** | [`framework-v7-8.md`](./framework-v7-8.md) |
| **v7.9 candidates spec (now includes F11/F12/F13 from v7.8.3 dogfood)** | [`docs/superpowers/specs/2026-05-08-framework-v7-9-candidates.md`](../../docs/superpowers/specs/2026-05-08-framework-v7-9-candidates.md) |

## v7.9 anchor points (decision date 2026-05-21)

3 new candidates surfaced from v7.8.3 cutover dogfood (added to the v7.9 candidates spec):

- **F11** — `BRANCH_ISOLATION_HISTORICAL` recognition for `reverse-sync/*` branches (auto-PR'd by D-1 workflow currently look like history violations).
- **F12** — `actionlint` pre-commit hook (would have caught the `secrets.*`-at-job-level bug pre-PR).
- **F13** — `workflow_dispatch` `source_commit` input (allow operator-driven re-run after fixes without dummy commits).

## Relationship to v7.8 / v7.8.1 / v7.8.2

- **v7.8** added the meta-layer: gates that observe gate execution (Mechanism A), schema bridges (B), auto-instrumented cache attribution (C), pre-commit self-test (D), append-only ledger merge driver (E), membrane status (F).
- **v7.8.1** added 3 new write-time gates for branch isolation + feature-closure completeness; first feature shipped via the v7.8 protocol.
- **v7.8.2** documented the cross-repo telemetry asymmetry; patch-level (no new gates).
- **v7.8.3** (this) implements the bidirectional cross-repo state-sync contract; promotes V2 to enforced; extends V9 to feature logs; adds 3 new state_owner gates; ships D-1 reverse-sync. Pattern remains: trust through track record. 6 framework dogfood catches in real-time during the v7.8.3 ship — all caught by gates, all fixed before merge.
