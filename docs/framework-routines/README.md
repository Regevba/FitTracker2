# Framework Routines, Crons, Hooks, and Telemetry — Navigation Index

> Single point of entry for "where is the file that does X?" across the framework's
> data-integrity + telemetry layer (v7.5 → v7.8.6).
>
> This doc is the **live navigation layer**. It points at canonical repo paths.
> For the **offline backup + comprehensive developer manual**, see:
> [`~/Documents/FitTracker2-backups/2026-05-15-framework-routines-source-of-truth/`](../../../../../Users/regevbarak/Documents/FitTracker2-backups/2026-05-15-framework-routines-source-of-truth/)
>
> **Quick start:** `cat ~/Documents/FitTracker2-backups/2026-05-15-framework-routines-source-of-truth/MANUAL.md` for the in-depth dev manual covering every mechanism.

---

## Cadence at a glance

| When | Mechanism | Source file |
|---|---|---|
| Every commit | Pre-commit hook (11 Class A gates + 2 advisory) | [.githooks/pre-commit](../../.githooks/pre-commit) → [scripts/check-state-schema.py](../../scripts/check-state-schema.py) |
| Every PR push | PR-integrity GitHub Action | [.github/workflows/pr-integrity-check.yml](../../.github/workflows/pr-integrity-check.yml) |
| Every Read tool call | Mechanism C session capture | [.claude/settings.json](../../.claude/settings.json) → [scripts/observe-cache-hit.py](../../scripts/observe-cache-hit.py) |
| Every Bash tool call | W9 branch-drift alert | [.claude/settings.json](../../.claude/settings.json) → [scripts/check-branch-drift.py](../../scripts/check-branch-drift.py) |
| Every SessionStart | Daily checkpoint (idempotent) + W1 ssh-agent preflight | [.claude/settings.json](../../.claude/settings.json) → [scripts/session-start-checkpoint.sh](../../scripts/session-start-checkpoint.sh) + [scripts/check-ssh-agent.sh](../../scripts/check-ssh-agent.sh) |
| Daily (06:00 + 13:00 + 18:00 local) | launchd → daily-integrity-checkpoint | [infrastructure/launchd/com.fittracker.daily-integrity-checkpoint.plist.template](../../infrastructure/launchd/com.fittracker.daily-integrity-checkpoint.plist.template) → [scripts/daily-integrity-checkpoint.py](../../scripts/daily-integrity-checkpoint.py) |
| Every 72h | Integrity-cycle GitHub Action (16 checks) | [.github/workflows/integrity-cycle.yml](../../.github/workflows/integrity-cycle.yml) → [scripts/integrity-check.py](../../scripts/integrity-check.py) |
| Weekly Monday 05:00 UTC | Framework-status snapshot + zero-drift + per-dim trend | [.github/workflows/framework-status-weekly.yml](../../.github/workflows/framework-status-weekly.yml) → [scripts/weekly-trend-scan.py](../../scripts/weekly-trend-scan.py) |
| Weekly Monday 06:00 UTC | Dependency audit | [.github/workflows/dependency-audit-weekly.yml](../../.github/workflows/dependency-audit-weekly.yml) → [scripts/aggregate-dependency-audit.py](../../scripts/aggregate-dependency-audit.py) |
| On-demand | `make` targets | [Makefile](../../Makefile) |

---

## Operator entry points (Make targets)

```bash
make preflight WORK_TYPE=<feature|enhancement|fix|chore> [FEATURE=<name>]
make integrity-check
make integrity-sweep
make integrity-diff
make integrity-multi-anchor
make integrity-data-lake
make documentation-debt
make measurement-adoption
make membrane-status
make verify-isolation
make feature-completeness-audit
make observed-patterns
make refresh-pr-cache
make install-hooks
make install-merge-drivers
make install-daily-cron
make snapshot-phase PHASE=<name> FEATURE=<name>
```

Full list with descriptions: see backup [MANUAL.md §11](../../../../../Users/regevbarak/Documents/FitTracker2-backups/2026-05-15-framework-routines-source-of-truth/MANUAL.md#11-make-targets).

---

## Where to find what

### Executable code

| Need | Path |
|---|---|
| Pre-commit gate dispatcher | [scripts/check-state-schema.py](../../scripts/check-state-schema.py) |
| 72h cycle-time check | [scripts/integrity-check.py](../../scripts/integrity-check.py) |
| Daily snapshot writer | [scripts/daily-integrity-checkpoint.py](../../scripts/daily-integrity-checkpoint.py) |
| Tier 1.1 measurement | [scripts/measurement-adoption-report.py](../../scripts/measurement-adoption-report.py) |
| Tier 3.2 doc-debt | [scripts/documentation-debt-report.py](../../scripts/documentation-debt-report.py) |
| Membrane status (Mechanism F) | [scripts/membrane-status.py](../../scripts/membrane-status.py) |
| Branch isolation audit | [scripts/verify-isolation.py](../../scripts/verify-isolation.py) |
| Feature closure completeness | [scripts/feature-completeness-audit.py](../../scripts/feature-completeness-audit.py) |
| Diff vs baseline (raw-%) | [scripts/integrity-diff.py](../../scripts/integrity-diff.py) |
| Dilution normalization (multi-anchor) | [scripts/integrity-multi-anchor.py](../../scripts/integrity-multi-anchor.py) |
| Telemetry data-lake | [scripts/integrity-data-lake.py](../../scripts/integrity-data-lake.py) |
| Unified preflight (v7.8.6) | [scripts/preflight.py](../../scripts/preflight.py) |
| Mechanism C session capture | [scripts/observe-cache-hit.py](../../scripts/observe-cache-hit.py) |
| Mechanism E merge driver | [scripts/merge-driver-dedup.py](../../scripts/merge-driver-dedup.py) |
| W1 ssh-agent preflight | [scripts/check-ssh-agent.sh](../../scripts/check-ssh-agent.sh) |
| W9 branch-drift detector | [scripts/check-branch-drift.py](../../scripts/check-branch-drift.py) |
| Tier 2.1 runtime smoke | [scripts/runtime-smoke-gate.py](../../scripts/runtime-smoke-gate.py) |
| Tier 2.2 contemporaneous log | [scripts/append-feature-log.py](../../scripts/append-feature-log.py) |
| UI audit gate | [scripts/ui-audit.py](../../scripts/ui-audit.py) |
| Weekly trend scan | [scripts/weekly-trend-scan.py](../../scripts/weekly-trend-scan.py) |
| Dependency audit | [scripts/aggregate-dependency-audit.py](../../scripts/aggregate-dependency-audit.py) |
| Auto-isolation worktree | [scripts/create-isolated-worktree.py](../../scripts/create-isolated-worktree.py) |
| Per-phase backup | [scripts/snapshot-phase-completion.sh](../../scripts/snapshot-phase-completion.sh) |

### Configuration

| Need | Path |
|---|---|
| Claude Code hook config | [.claude/settings.json](../../.claude/settings.json) |
| Make targets | [Makefile](../../Makefile) |
| Git merge driver opt-in | [.gitattributes](../../.gitattributes) |
| Branch isolation allowlist | [.claude/shared/branch-isolation-exempt.json](../../.claude/shared/branch-isolation-exempt.json) |
| Framework manifest (gates catalog) | [.claude/shared/framework-manifest.json](../../.claude/shared/framework-manifest.json) |
| Path reducers (gate-coverage agg) | [.claude/shared/path-reducers.json](../../.claude/shared/path-reducers.json) |
| Launchd plist (template) | [infrastructure/launchd/com.fittracker.daily-integrity-checkpoint.plist.template](../../infrastructure/launchd/com.fittracker.daily-integrity-checkpoint.plist.template) |
| HADF launchd templates | [.claude/features/hadf-phase2bis-replication/launchd-templates/](../../.claude/features/hadf-phase2bis-replication/launchd-templates/) |

### Telemetry streams

| Need | Path |
|---|---|
| Daily ledger | [.claude/shared/integrity-checkpoint-ledger.jsonl](../../.claude/shared/integrity-checkpoint-ledger.jsonl) |
| Daily ledger (human) | [.claude/shared/integrity-checkpoint-ledger.md](../../.claude/shared/integrity-checkpoint-ledger.md) |
| Current Tier 1.1 state | [.claude/shared/measurement-adoption.json](../../.claude/shared/measurement-adoption.json) |
| Tier 1.1 history | [.claude/shared/measurement-adoption-history.json](../../.claude/shared/measurement-adoption-history.json) |
| Tier 3.2 doc-debt | [.claude/shared/documentation-debt.json](../../.claude/shared/documentation-debt.json) |
| Mechanism A gate coverage | [.claude/logs/gate-coverage.jsonl](../../.claude/logs/gate-coverage.jsonl) |
| Mechanism C session events | [.claude/logs/](../../.claude/logs/) (files matching `_session-*.events.jsonl`) |
| Per-feature Tier 2.2 logs | [.claude/logs/](../../.claude/logs/) (files matching `<feature>.log.json`) |
| 72h cycle snapshots | [.claude/integrity/snapshots/](../../.claude/integrity/snapshots/) |
| Active-feature lockfile | [.claude/active-feature](../../.claude/active-feature) |
| MUST-have follow-ups | [.claude/shared/must-have-cadence-followups.md](../../.claude/shared/must-have-cadence-followups.md) |

### Documentation

| Need | Path |
|---|---|
| Framework dev guide (v1 → v7.8) | [docs/architecture/dev-guide-v1-to-v7-7.md](../architecture/dev-guide-v1-to-v7-7.md) |
| Feature lifecycle event catalog | [docs/architecture/feature-lifecycle-event-catalog.md](../architecture/feature-lifecycle-event-catalog.md) |
| Infra master plan | [docs/master-plan/infra-master-plan-2026-05-12.md](../master-plan/infra-master-plan-2026-05-12.md) |
| Data integrity & rollback plan | [docs/master-plan/data-integrity-and-rollback-2026-05-14.md](../master-plan/data-integrity-and-rollback-2026-05-14.md) |
| Test coverage master plan | [docs/master-plan/test-coverage-master-plan-2026-05-13.md](../master-plan/test-coverage-master-plan-2026-05-13.md) |
| Observed patterns catalog | [.claude/integrity/observed-patterns.md](../../.claude/integrity/observed-patterns.md) |
| Integrity check codes README | [.claude/integrity/README.md](../../.claude/integrity/README.md) |
| Tier 2.1 runtime smoke gates | [docs/process/runtime-smoke-gates.md](../process/runtime-smoke-gates.md) |
| Tier 2.2 contemporaneous logging | [docs/process/contemporaneous-logging.md](../process/contemporaneous-logging.md) |
| Tier 3.2 doc-debt dashboard | [docs/process/documentation-debt-dashboard.md](../process/documentation-debt-dashboard.md) |
| Data quality tiers | [docs/case-studies/data-quality-tiers.md](../case-studies/data-quality-tiers.md) |
| Unclosable gaps | [docs/case-studies/meta-analysis/unclosable-gaps.md](../case-studies/meta-analysis/unclosable-gaps.md) |

### Framework version specs

| Version | Path |
|---|---|
| v6 measurement | [docs/superpowers/specs/2026-04-16-framework-measurement-v6-design.md](../superpowers/specs/2026-04-16-framework-measurement-v6-design.md) |
| v7.5 data integrity | [docs/superpowers/specs/2026-04-24-framework-v7-5-data-integrity-design.md](../superpowers/specs/2026-04-24-framework-v7-5-data-integrity-design.md) |
| v7.6 mechanical enforcement | [docs/superpowers/specs/2026-04-25-framework-v7-6-mechanical-enforcement-design.md](../superpowers/specs/2026-04-25-framework-v7-6-mechanical-enforcement-design.md) |
| v7.7 validity closure | [docs/superpowers/specs/2026-04-27-framework-v7-7-validity-closure-design.md](../superpowers/specs/2026-04-27-framework-v7-7-validity-closure-design.md) |
| v7.8 bridge | [docs/superpowers/specs/2026-05-02-framework-v7-8-and-v7-9-bridge-design.md](../superpowers/specs/2026-05-02-framework-v7-8-and-v7-9-bridge-design.md) |
| Cross-repo asymmetry | [docs/superpowers/specs/2026-05-08-cross-repo-gate-asymmetry.md](../superpowers/specs/2026-05-08-cross-repo-gate-asymmetry.md) |
| v7.9 candidates | [docs/superpowers/specs/2026-05-08-framework-v7-9-candidates.md](../superpowers/specs/2026-05-08-framework-v7-9-candidates.md) |
| Cross-repo state sync | [docs/superpowers/specs/2026-05-09-cross-repo-state-sync.md](../superpowers/specs/2026-05-09-cross-repo-state-sync.md) |

---

## Backup snapshot

Full offline backup including comprehensive dev manual:
**`~/Documents/FitTracker2-backups/2026-05-15-framework-routines-source-of-truth/`**

| File | Purpose |
|---|---|
| `README.md` | Top-level index of the backup |
| `MANUAL.md` | Comprehensive developer manual (15 sections) — read this for in-depth coverage |
| `CHECKSUMS.sha256` | SHA-256 of every file (verify with `shasum -c CHECKSUMS.sha256`) |

Contains 4,832 files across 12 numbered subfolders covering scripts, workflows, hooks, launchd plists, ledgers, snapshots, docs, config, logs, active state, and feature state.

Next scheduled snapshot opportunity: **2026-05-21** (v7.9 promotion-decision data freeze, per MUST-have item B1 in [`.claude/shared/must-have-cadence-followups.md`](../../.claude/shared/must-have-cadence-followups.md)).

---

*Established 2026-05-15 as the navigation entry point for the framework infrastructure layer.*
