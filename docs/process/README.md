# Process Documentation

Operational playbooks and groundwork tied to the 2026-04-21 Google Gemini 2.5 Pro independent audit. Each doc describes the **status** and **current limits** of the named Tier recommendation from that audit, not just what's aspirational.

> **State at v7.6 (Mechanical Enforcement, shipped 2026-04-25):** five of the original Tier recommendations are now formalized as **mechanically unclosable Class B gaps** — their status will not "complete" because they cannot be mechanized without lying about what the framework can verify. See [`docs/case-studies/meta-analysis/unclosable-gaps.md`](../case-studies/meta-analysis/unclosable-gaps.md). The remaining four were promoted to Class A (write-time / per-PR / weekly enforcement) in v7.6.

## Contents

| File | Gemini Tier | Status (2026-04-25 at v7.6 ship) | Primary tooling |
|---|---|---|---|
| [runtime-smoke-gates.md](./runtime-smoke-gates.md) | **2.1** — Gated phase transitions with runtime smoke tests | Groundwork shipped; staging `app_launch` + `sign_in_surface` passing. **Real-provider checklist is now Class B Gap 4** — physical-device necessity, manual quarterly cadence | `make runtime-smoke PROFILE=<id> MODE=<local\|staging>` + `scripts/runtime-smoke-gate.py` |
| [contemporaneous-logging.md](./contemporaneous-logging.md) | **2.2** — Contemporaneous logging replacing retroactive case studies | Used end-to-end during v7.6's own session (9+ events). Cache-hits writer-path closed via `--cache-hit` flag (issue #140 resolved at writer-path). **Adoption stays Class B Gap 1** | `scripts/append-feature-log.py` writing to `.claude/logs/<feature>.log.json` |
| [documentation-debt-dashboard.md](./documentation-debt-dashboard.md) | **3.2** — Documentation debt dashboard | Baseline dashboard shipped; weekly cron (v7.6 Phase 2c) appends history snapshots; trend mode unlocks after 3 scheduled cycle snapshots | `make documentation-debt` + `.claude/shared/documentation-debt.json` |
| [product-management-lifecycle.md](./product-management-lifecycle.md) | — (pre-existing) | Canonical 10-phase PM lifecycle definition | `/pm-workflow <feature>` skill |

## Related canonical artifacts

- **Developer guide (v1.0 → v7.6 technical reference):** [`docs/architecture/dev-guide-v1-to-v7-6.md`](../architecture/dev-guide-v1-to-v7-6.md)
- **v7.5 case study (8 cooperating defenses, audit policy response):** [`docs/case-studies/data-integrity-framework-v7.5-case-study.md`](../case-studies/data-integrity-framework-v7.5-case-study.md)
- **v7.6 case study (mechanical enforcement layer):** [`docs/case-studies/mechanical-enforcement-v7-6-case-study.md`](../case-studies/mechanical-enforcement-v7-6-case-study.md)
- **Class B unclosable-gaps inventory:** [`docs/case-studies/meta-analysis/unclosable-gaps.md`](../case-studies/meta-analysis/unclosable-gaps.md)
- **v7.6 unified completion plan:** [`docs/superpowers/plans/2026-04-25-v7-6-unified-completion-plan.md`](../superpowers/plans/2026-04-25-v7-6-unified-completion-plan.md)
- **Tier 3.3 public invitation (Phase 3c, pinned):** [GitHub issue #142](https://github.com/Regevba/FitTracker2/issues/142)
- **Remediation plan (authoritative status):** [`trust/audits/2026-04-21-gemini/remediation-plan-2026-04-23.md`](../../trust/audits/2026-04-21-gemini/remediation-plan-2026-04-23.md)
- **Integrity cycle (Tier 3.1) source-of-truth:** [`.claude/integrity/README.md`](../../.claude/integrity/README.md) + [`scripts/integrity-check.py`](../../scripts/integrity-check.py)
- **Per-PR enforcement (v7.6 Phase 2a):** [`.github/workflows/pr-integrity-check.yml`](../../.github/workflows/pr-integrity-check.yml) — sets `pm-framework/pr-integrity` commit status
- **Weekly framework-status cron (v7.6 Phase 2c):** [`.github/workflows/framework-status-weekly.yml`](../../.github/workflows/framework-status-weekly.yml)
- **Pre-commit enforcement (Tier 1.3 + v7.6 transition checks + case-study preflight):** [`.githooks/pre-commit`](../../.githooks/pre-commit) + [`scripts/check-state-schema.py`](../../scripts/check-state-schema.py) + [`scripts/check-case-study-preflight.py`](../../scripts/check-case-study-preflight.py) — install with `make install-hooks`
- **Auth verification playbook (Tier 2.1 last-mile, Class B Gap 4):** [`docs/setup/auth-runtime-verification-playbook.md`](../setup/auth-runtime-verification-playbook.md)
- **Data quality tiers convention (Tier 2.3):** [`docs/case-studies/data-quality-tiers.md`](../case-studies/data-quality-tiers.md)
- **Independent audit archive (Tier 3.1 input):** [`docs/case-studies/meta-analysis/independent-audit-2026-04-21-gemini.md`](../case-studies/meta-analysis/independent-audit-2026-04-21-gemini.md)

## Status reading guide

The audit's 9 Tier 1/2/3 items carry honest state labels so a reader never sees "done" when the recommendation is only partially implemented:

- **Shipped** — the recommendation is fully implemented and enforced
- **Subset shipped** — a narrower version of the recommendation is implemented; the broader form is explicitly deferred
- **Groundwork shipped** — infrastructure is ready but a manual or wall-clock blocker prevents full adoption
- **Pilot active** — convention is in use but not yet repo-wide
- **Baseline-only** — single-point measurement exists; trend analysis requires more data
- **Partial** — a component shipped but system-wide adoption is incomplete
- **Backlog** — deferred; typically external or multi-session work

## Adding a new process doc

If a new Tier recommendation surfaces a process change, add the doc here and:

1. Open with a one-line status line so readers know what to expect
2. Declare the current blocker openly — don't round up partial work to "shipped"
3. Cross-link to tooling (Makefile targets, scripts, config) by absolute path
4. Update this README's contents table in the same commit
