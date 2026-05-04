# Framework v7.8 Bridge — cold-start entrypoint

> One-page summary of v7.8 for any agent or developer arriving cold.
> If you only read one document about v7.8, read this. Then follow the
> "Canonical sources" section to drill in.

**Shipped:** 2026-05-02 → 2026-05-03 across 8 PRs (#173, #185, #186, #187, #188, #189, #192, #193).
**Predecessor:** v7.7 Validity Closure (shipped 2026-04-27, [PR #144](https://github.com/Regevba/FitTracker2/pull/144)).
**Successor:** v7.9 Promotion (planned ≥ 2026-05-10, after a 7-day measurement window).

## Why v7.8 exists

v7.7 shipped with a headline claim that `cache_hits[]` post-v6 was "gated to 100% on next write (issue #140 closed)." A 2026-04-30 audit found the gate's effective coverage was **0 / 46 features**: it read `state.get("created_at", "")` while 43 of 46 features stored the field as legacy `created`. The gate compiled, was wired into pre-commit, and silently passed every commit. v7.8 closes that loop and adds the meta-mechanism that prevents future silent-passes from going undetected.

Full history of the failure + closure path: [Framework Honesty Ledger entry **FT2-FH-001**](../../docs/case-studies/framework-honesty-ledger.md#ft2-fh-001--v77-silent-pass-on-cache_hits_empty_post_v6).

## What v7.8 ships (advisory mode — v7.9 promotes to enforced)

| Mechanism | What it does | PR | Mode in v7.8 |
|---|---|---|---|
| **A** Coverage-asserting gates | Every write-time gate emits `{candidates, checked, skipped, skip_reasons}` per run to `.claude/logs/gate-coverage.jsonl`. New `GATE_COVERAGE_ZERO` advisory fires when a gate has candidates ≥ 1 but checked = 0. | [#187](https://github.com/Regevba/FitTracker2/pull/187) | Advisory |
| **B** Schema bridge fields | `state.json::agent_manifest` + `_meta.deprecation_warnings` + new `.claude/shared/path-reducers.json` + `.claude/shared/agent-leases.json` registries. Every existing feature has a populated empty manifest. | [#192](https://github.com/Regevba/FitTracker2/pull/192) | Populated, un-validated |
| **C** Auto-instrumented cache attribution | `PostToolUse:Read` hook → `scripts/observe-cache-hit.py` → `.claude/logs/_session-<id>.events.jsonl`. `/pm-workflow` writes `.claude/active-feature` for attribution. New `CACHE_HITS_AUTO_INSTRUMENTATION_INACTIVE` advisory fires when ledger captures Reads but state.json drifts. | [#173, #188](https://github.com/Regevba/FitTracker2/pull/173) | Advisory (capture only) |
| **D** Pre-commit self-test | `scripts/pre-commit-self-test.py` asserts every gate declared in `.githooks/pre-commit` header is implemented in the checker scripts. Catches header-vs-code drift on both sides. | [#193](https://github.com/Regevba/FitTracker2/pull/193) | Run via `make pre-commit-self-test` + per-PR CI |
| **E** Append-only ledger merge driver | `union-dedup-by-key` git merge driver auto-resolves `.claude/logs/*.jsonl` and `.claude/shared/*-history.json` conflicts in append-only files. | [#189](https://github.com/Regevba/FitTracker2/pull/189) | Active |
| **F** Membrane status (smartlog) | `scripts/membrane-status.py` joins state.json + agent-leases.json + open-branch reflog into one ASCII or JSON view. Pattern: Sapling smartlog. | [#193](https://github.com/Regevba/FitTracker2/pull/193) | Read-only advisory |

## What v7.8 explicitly does NOT do

- **No new pre-commit failures.** Every v7.8 mechanism ships advisory. v7.9 promotes A + C from advisory → enforced once 7+ days of measurement-window data calibrate the false-positive thresholds.
- **No agent-lease enforcement.** `agent-leases.json` is populated but no gate consumes it yet. v7.9 adds the lease-enforcement check at `/pm-workflow` startup.
- **No path-reducer enforcement.** `path-reducers.json` is populated as `mode: advisory` for every entry. v7.9 flips entries to enforced after demonstrating zero false-positives over 7 days.

## How to verify v7.8 is working

```bash
make pre-commit-self-test       # Mechanism D: header drift detection
make membrane-status            # Mechanism F: smartlog
make schema-check               # 47/47 should pass (1 expected violation on hadf-infrastructure proves Mechanism A's silent-pass closure)
make integrity-check            # 0 findings + 2 known advisories
cat .claude/logs/gate-coverage.jsonl | tail -1 | python3 -m json.tool   # Mechanism A: see the silent-pass evidence
```

## Canonical sources

| Source | Path |
|---|---|
| **v7.8 case study (live append-only journal + final synthesis)** | [`docs/case-studies/framework-v7-8-bridge-case-study.md`](../../docs/case-studies/framework-v7-8-bridge-case-study.md) |
| **v7.7 silent-pass + v7.8 closure ledger entry FT2-FH-001** | [`docs/case-studies/framework-honesty-ledger.md`](../../docs/case-studies/framework-honesty-ledger.md) |
| **Bridge design spec (v7.8 + v7.9 sequence)** | [`docs/superpowers/specs/2026-05-02-framework-v7-8-and-v7-9-bridge-design.md`](../../docs/superpowers/specs/2026-05-02-framework-v7-8-and-v7-9-bridge-design.md) |
| **v7.7 case study (with Section 99B correction note)** | [`docs/case-studies/framework-v7-7-validity-closure-case-study.md`](../../docs/case-studies/framework-v7-7-validity-closure-case-study.md) |
| **DEV onboarding guide** | [`docs/architecture/dev-guide-v1-to-v7-7.md`](../../docs/architecture/dev-guide-v1-to-v7-7.md) |
| **Pre-commit hook (self-audited via Mechanism D)** | [`.githooks/pre-commit`](../../.githooks/pre-commit) |
| **Audit memo that surfaced the silent-pass** | agent memory `project_framework_gaps_audit_2026_04_30.md` |

## v7.9 anchor points (do not commit to specifics yet)

The +7 day measurement window samples three data sources:

1. `.claude/logs/reducer-misses.json` — false-positive count per reducer entry (v7.9 promotes only those at zero).
2. `.claude/logs/gate-coverage.jsonl` — which gates fired vs which silently skipped (v7.9 enforces `GATE_COVERAGE_ZERO`).
3. `.claude/logs/_session-*.events.jsonl` — Mechanism C session-ledger attribution accuracy (v7.9 enforces the writer-path).

If any data source shows non-zero false positives, the corresponding promotion is held until the next 7-day window.

## Relationship to v7.6 + v7.7

- **v7.6** added per-PR review bot + weekly framework-status cron + 4 new pre-commit gates (mechanical enforcement).
- **v7.7** added 4 more write-time gates + 1 cycle-time check + 1 advisory + bulk frontmatter + state.json backfill (validity closure). Shipped with the silent-pass.
- **v7.8** (this) adds the meta-layer: gates that observe gate execution, schema bridges that observe schema drift, the honesty ledger that documents what we got wrong. The pattern from this point is "trust through track record" — corrections accrete; original claims stay visible.
