# Framework v7.8.6 Cadence Batch — cold-start entrypoint

> One-page summary of v7.8.6 for any agent or developer arriving cold.
> If you only read one document about v7.8.6, read this. Then follow
> the "Canonical sources" section to drill in.

**Shipped:** 2026-05-15, single-session double-PR ship (MUST batch + nice-to-have batch).
**Predecessor:** [v7.8.5 Observability Layer](framework-v7-8.md) (shipped 2026-05-13) — see [`CLAUDE.md "v7.8.5"` section](../../CLAUDE.md).
**Successor:** v7.9 Promotion (decision date 2026-05-21; ship target ~2026-06-01 per [infra master plan](../../docs/master-plan/infra-master-plan-2026-05-12.md) §2.2).

## Why v7.8.6 exists

The 2026-05-14 daily-integrity-checkpoint shipped a per-day platform snapshot, but `docs/master-plan/data-integrity-and-rollback-2026-05-14.md` §2.1 documented an explicit gap:

> Up to 96 hours can elapse between the weekly framework-status cron (Mondays 05:00 UTC) and the next 72-hour integrity cycle, during which drift can accumulate across multiple commits invisibly. The daily checkpoint catches day-over-day deltas; what's missing is **drift detection against the calibration anchor**.

The 2026-05-21 v7.9 promotion decision evaluates advisory gates against criterion #2 ("no false positives"). To support that decision, an operator should be able to type ONE command and see "what has drifted vs the 2026-05-14 baseline?" — not manually diff 6 ledger files.

v7.8.6 ships that one command (`make integrity-diff`) plus the per-work-type unified preflight (`make preflight WORK_TYPE=<type>`) plus the nice-to-have observability extensions that reduce ongoing operator sweeps.

## What v7.8.6 ships (two-PR batch)

### MUST batch — PR #363

| Item | What it does | File(s) | Mode |
|---|---|---|---|
| **`make integrity-diff`** | Compares current platform state vs the 2026-05-14 baseline anchor. Override path via `INTEGRITY_DIFF_BASELINE=<path>`. CI mode: `EXIT_ON_REGRESSION=1` exits 1 on regression. | `scripts/integrity-diff.py` + `Makefile` | Active observability |
| **`make preflight WORK_TYPE=<type>`** | Unified pre-work data check adapted by `feature` / `enhancement` / `fix` / `chore`. Writes `.claude/shared/preflight-cache.json` consumed by all 10 downstream skills. | `scripts/preflight.py` + `Makefile` + 10 skill SKILL.md edits + `docs/skills/preflight-cache-schema.md` + `pm-workflow` Phase 0.0 | Active observability |
| **W1 ssh-agent preflight** | Warns loudly on SessionStart when `ssh-add -l` returns no identities; prevents the documented silent `ssh-keygen -Y sign` hang. Disable: `CLAUDE_W1_DISABLE_SSH_CHECK=1`. | `scripts/check-ssh-agent.sh` + `.claude/settings.json` | Active SessionStart |
| **Weekly Mechanism A zero-drift scan (A2)** | Tracks distinct gates emitting telemetry week-over-week via `.claude/shared/gate-coverage-weekly.jsonl`. Flags any gate that previously emitted but stopped. | `scripts/weekly-trend-scan.py` + `.github/workflows/framework-status-weekly.yml` | Weekly cron |
| **Per-dimension trend nudge (A4)** | Diffs `timing_wall_time`/`per_phase_timing`/`cache_hits`/`cu_v2`/`fully_adopted_post_v6` against prior weekly snapshot. Opens digest issue on any drop. | (same workflow step) | Weekly cron |
| **Calendar reminders** | Daily-checkpoint surfaces upcoming MUST-have follow-ups ≤14d (B1 v7.9 freeze 2026-05-21, B2 post-v7.9 baseline 2026-05-28, B4/B5 quarterly test audit). | `scripts/daily-integrity-checkpoint.py` + `.claude/shared/must-have-cadence-followups.md` | Active |

### Nice-to-have batch — PR #365

| Item | What it does | File(s) | Mode |
|---|---|---|---|
| **Weekly dependency audit (N1)** | `npm audit --omit=dev` across root + `website` + `dashboard` + Swift Package.resolved pin count. Opens issue on HIGH/CRITICAL. Mondays 06:00 UTC (1h after framework-status-weekly). | `.github/workflows/dependency-audit-weekly.yml` + `scripts/aggregate-dependency-audit.py` | Weekly cron |
| **Stale-branch warning (N2)** | Daily-checkpoint section listing `[gone]` local branches + orphan worktrees. Suggests `commit-commands:clean_gone`. | `scripts/daily-integrity-checkpoint.py::stale_branches()` | Active daily |
| **PR babysit sweep (N3)** | Daily-checkpoint section listing open PRs idle >24h, cross-repo (FT2 + fitme-story). | `scripts/daily-integrity-checkpoint.py::pr_babysit()` | Active daily |

## Inventory delta

| Surface | Pre-v7.8.6 | Post-v7.8.6 |
|---|---|---|
| Mechanical gates | 34 | **34** (unchanged) |
| Advisory gates | 5 | **5** (unchanged) |
| Makefile targets | (existing) | + `integrity-diff` + `preflight` |
| Append-only ledgers | (existing) | + `gate-coverage-weekly.jsonl` + `must-have-cadence-followups.md` |
| Gitignored per-session caches | (existing) | + `preflight-cache.json` |
| GH Actions workflows | (existing) | + `dependency-audit-weekly.yml` (existing `framework-status-weekly.yml` extended) |
| SessionStart hooks | 2 | **3** (+W1 ssh-agent) |
| Daily-checkpoint output sections | 5 (snapshot, ledger, regression, manifest, calendar) | **8** (+stale-branch, +PR babysit, calendar already added today) |
| Skills with preflight-cache pointer | 0 | **10/10** (all skills) |

## Outcome

`make integrity-check` post-v7.8.6 ship: **0 findings + 0 advisory** (unchanged from v7.8.4 baseline).

`make integrity-diff` post-v7.8.6 ship: **0 regressions vs 2026-05-14 anchor** (cu_v2 chronic miss at 19.4% — unchanged from baseline, not a regression).

## Canonical sources

- **CLAUDE.md** §"v7.8.6 Cadence Batch" — operational rules + cross-refs
- **`docs/architecture/dev-guide-v1-to-v7-7.md`** — header bumped to v7.8.6; old v7.8.5 line moved to baseline list
- **`docs/architecture/feature-lifecycle-event-catalog.md`** — Phase 0.0 unified preflight noted as MANDATORY first step before Phase 0/1
- **`docs/master-plan/infra-master-plan-2026-05-12.md`** §1.2 — v7.8.6 cadence-batch inventory paragraph
- **`docs/skills/preflight-cache-schema.md`** — full schema for `preflight-cache.json` consumers
- **`.claude/shared/must-have-cadence-followups.md`** — calendar + feature-scope follow-up tracker
- **PR #363** — MUST-have batch
- **PR #365** — nice-to-have batch
- **PR #364** — v7.7 trend-mode banner flip (shipped same day; preserves the v7.7 case-study journal)

## What v7.8.6 does NOT change

- No advisory→enforced flips (those happen at v7.9, decision 2026-05-21)
- No state.json schema changes
- No new write-time pre-commit gates
- No new cycle-time check codes
- No removed checks
- No `make` target removals
- No skill SKILL.md sub-command additions (only the Shared Data pointer was added)
