# Task Breakdown — w9-drift-triggered-auto-isolation

Derived from [prd.md](prd.md). Phased: **Phase 1 = drift-reactive (ships now, advisory→enforced T+7d)**, **Phase 2 = concurrency-proactive (ships advisory, enforced T+14d)**. All tasks are `infra` work-type → isolated worktree (this one). No UI, no analytics.

## Phase 1 — drift-reactive auto-isolation

| ID | Title | Type | Skill | Effort (d) | Depends on |
|---|---|---|---|---|---|
| **T1** | Atomic isolation primitive: `stash → worktree-add → pop` guarded by a lock file; aborts + warns on contention; **never drops uncommitted work** (GR4/KC3). New helper in/near `scripts/create-isolated-worktree.py`. | infra | dev | 1.0 | — |
| **T2** | Extend [`scripts/check-branch-drift.py`](../../../scripts/check-branch-drift.py): on detected HEAD-flip + uncommitted/about-to-commit work, escalate from warn → offer isolation; auto-dispatch the primitive when `CLAUDE_W9_AUTO_ISOLATE=1` (advisory-first). Honor `isolation_opt_out` + `CLAUDE_W9_DISABLE_DRIFT_CHECK`. | infra | dev | 1.0 | T1 |
| **T3** | Mechanism A telemetry: emit `w9.auto_isolate` `{candidates, checked, skipped, skip_reasons}` to `.claude/logs/gate-coverage.jsonl` on every W9 fire; record drift-event + isolation outcome. | infra | dev | 0.5 | T2 |
| **T4** | Tests: unit + try-repo-style harness — drift→offer path, dirty-tree **no-data-loss** safety, false-trigger/no-op cases, lock contention abort, env kill-switch + opt-out honored. | test | qa | 1.0 | T1, T2, T3 |
| **T5** | `make w9-isolation-status` readout: recent auto-isolations + false-trigger rate (S2) from `gate-coverage.jsonl`. | infra | dev | 0.5 | T3 |

## Phase 2 — concurrency-proactive auto-isolation (advisory at ship)

| ID | Title | Type | Skill | Effort (d) | Depends on |
|---|---|---|---|---|---|
| **T6** | Lease-freshness reader (TTL) over `.claude/shared/agent-leases.json` — "is another session live on this checkout?" signal; stale (> TTL) → treated as absent. | infra | dev | 1.0 | — |
| **T7** | Extend the `BRANCH_ISOLATION_VIOLATION` auto-isolation flow to all work-types **gated on concurrency** (T6 signal), behind an **advisory-mode flag** (no enforced behavior change at ship). Reuses T1 primitive. | infra | dev | 1.5 | T1, T6 |
| **T8** | First-edit trigger: detect first Edit/Write to non-infra feature code in a session and run the concurrency check (T7). | infra | dev | 1.0 | T7 |
| **T9** | Tests: concurrency simulation (live vs stale lease), advisory-mode telemetry emission, no-isolation-when-solo. | test | qa | 1.0 | T7, T8 |
| **T10** | Calibration wiring: advisory→enforced promotion criteria (v7.9 4-criteria) doc + telemetry key; T+14d review hook. | docs | dev | 0.5 | T7 |

## Cross-cutting / closure

| ID | Title | Type | Skill | Effort (d) | Depends on |
|---|---|---|---|---|---|
| **T11** | (Open-Q2, only if cheap) cleanup-on-merge hook to remove the auto-created worktree when its branch merges; else defer to the worktree-GC track (N2). | infra | dev | 0.5 | T1 |
| **T12** | Docs + §v7.8.5 mandatory: append the W9 auto-isolation behavior to [`observed-patterns.md`](../../integrity/observed-patterns.md) (extend W9) + add to `pattern-skill-map.json`; run `make gen-skill-preflight`. Update dev-guide gate catalog. | docs | dev | 0.5 | T2, T7 |

**Total effort:** ~10.5 d nominal (Phase 1 ≈ 4.0 d, Phase 2 ≈ 5.0 d, cross-cutting ≈ 1.0 d). Phase 1 is independently shippable.

**Critical path:** T1 → T2 → T3 → T4 (Phase 1 ship) ; then T6 → T7 → T8 → T9 (Phase 2 advisory ship).

**Suggested first slice to implement now:** T1 + T2 + T3 + T4 + T5 (Phase 1 end-to-end, advisory-first). Phase 2 (T6–T10) can be a second implementation slice after Phase 1's T+7d calibration, or built behind the advisory flag in the same branch — operator's call at the next gate.
