---
slug: dev-env-r11-r13-r14-r17-r18-batch
title: "Dev-env R11+R13+R14+R17+R18 batch — gitleaks + pip-audit + SBOM + commitlint + shellcheck"
date_written: 2026-06-04
framework_version: v7.9.1
work_type: Chore
work_subtype: framework_feature
case_study_type: shipped
tier_tags_required: true
status: shipped
case_study: docs/case-studies/dev-env-r11-r13-r14-r17-r18-batch-case-study.md
case_study_showcase: ""
related_prs: []
dispatch_pattern: serial
success_metrics:
  - name: r_items_shipped
    baseline: 0
    target: 5
    significance: descriptive
    review_at: 2026-06-04
    tier: T1
    note: "(T1) R11 gitleaks + R13 pip-audit + R14 SBOM + R17 commitlint + R18 shellcheck. Measured by master-plan R-table row updates."
  - name: workflows_added
    baseline: 0
    target: 5
    significance: descriptive
    review_at: 2026-06-04
    tier: T1
    note: "(T1) gitleaks.yml + pip-audit.yml + sbom.yml + commitlint.yml + shellcheck.yml in .github/workflows/. All parse as valid YAML."
  - name: warn_only_jobs
    baseline: 0
    target: 5
    significance: blocking
    review_at: 2026-06-04
    tier: T1
    note: "(T1) Every job uses continue-on-error: true so findings produce annotations but do not gate PR merges. Verified by yaml lint."
  - name: external_audit_2_artifact_set
    baseline: 0
    target: 3
    significance: descriptive
    review_at: 2026-06-12
    tier: T2
    note: "(T2) External Audit #2 on 2026-06-12 will include 3 artifacts produced by this batch: gitleaks scan + pip-audit JSON + (future) SBOM. Audit pack ships with these inline."
kill_criteria:
  - "Warn-only baseline accidentally gates PRs — verified by continue-on-error: true on every job"
  - "Workflow path filters miss legitimate changes — every workflow includes itself in its paths: filter"
  - "False-positive findings flood operator attention — bounded by gitleaks allowlist + commitlint type-enum scoped to project conventions"
kill_criteria_resolution: "All 3 mitigated by design and verified before merge. (1) Every new job uses `continue-on-error: true`; YAML lint confirmed all 5 parse. (2) Each workflow's `paths:` filter includes the workflow file itself so workflow edits auto-test. (3) `.gitleaks.toml` allowlist covers docs/case-studies/observed-patterns/test-fixtures + redacted-example regex patterns; `commitlint.config.js` `type-enum` lists exactly the 11 conventional-commit types the project actually uses."
primary_metric: "r_items_shipped = 5 (T1, present in dev-env-master-plan R-table at merge time)"
predecessor_case_study: docs/case-studies/r9-track-b-coverage-aggregator-case-study.md
spec: "docs/master-plan/dev-env-master-plan-2026-05-24.md §3 R11 + R13 + R14 + R17 + R18"
key_numbers:
  r_items_shipped: 5
  workflows_added: 5
  config_files_added: 2
  warn_only_baseline: true
  external_audit_companion_date: "2026-06-12"
  pre_commit_hook_integration_deferred: "R11 (gitleaks) + R18 (shellcheck) — separate PR per kill-criterion #2 risk-bounding"
---

## TL;DR (T1 unless tagged)

Batch ships **5 dev-env hygiene items** in a single PR, all as warn-only CI workflows that produce annotations without gating PR merges. Targets the Tier-2/Tier-3 dev-env R-items that were calendar-safe for post-Phase-E execution (2026-06-04+):

| R# | Item | Surface | Trigger |
|---|---|---|---|
| **R11** | gitleaks | `.gitleaks.toml` + `.github/workflows/gitleaks.yml` | PR + push + Sunday 03:00 UTC cron |
| **R13** | pip-audit (ai-engine) | `.github/workflows/pip-audit.yml` | PR (paths-filtered to `ai-engine/**`) + Monday 07:00 UTC cron |
| **R14** | SBOM (syft via anchore action) | `.github/workflows/sbom.yml` | `push.tags: v*` (dormant until first release tag) |
| **R17** | commitlint | `commitlint.config.js` + `.github/workflows/commitlint.yml` | PR-only |
| **R18** | shellcheck | `.github/workflows/shellcheck.yml` | PR (paths-filtered) + push + workflow_dispatch |

**Phase-E-safe** by construction — warn-only baselines, no gate flips, no telemetry impact. Every workflow uses `continue-on-error: true` so a finding produces an annotation in the run logs but the PR-level check still resolves to success.

**External Audit #2 (2026-06-12)** companion: the audit pack will include 3 artifacts produced by this batch (gitleaks scan + pip-audit JSON + future SBOM). This PR ships the producer side.

## What changed

5 net-new files + 2 net-new config files + 1 master-plan update:

**`.gitleaks.toml`** — extends the upstream-bundled default rule set (`extend.useDefault = true`) with a project-specific allowlist covering:
- `docs/setup/*.md` + `docs/case-studies/*.md` + `.claude/integrity/observed-patterns.md` (may reference example/redacted tokens for tutorial / evidence purposes)
- `scripts/tests/*` + `tests/fixtures/*` (canonical parser-test fixtures)
- Generic placeholder regexes (`your-api-key`, `<your-key>`, etc.)
- Claude model-ID pattern (`claude-(opus|sonnet|haiku)-\d+-\d+`) which looks token-shaped but isn't a secret

**`.github/workflows/gitleaks.yml`** — runs `gitleaks/gitleaks-action@v2` on PR + push to main + Sunday 03:00 UTC cron (offset 3h from framework-status-weekly to avoid runner-pool contention). `continue-on-error: true`; full-history fetch so historical leaks surface.

**`.github/workflows/pip-audit.yml`** — installs `pip-audit` and runs it against `ai-engine/`. Two output formats: columns (for run logs) + JSON (uploaded as a 14-day-retention artifact). Triggers: PR (paths-filtered to `ai-engine/**` + the workflow file), Monday 07:00 UTC cron, workflow_dispatch.

**`.github/workflows/sbom.yml`** — fires on `push.tags: v*`. Generates both SPDX-JSON and CycloneDX-JSON via `anchore/sbom-action@v0`. Dormant until first release tag (no v* tag exists in the repo today); the workflow's first run will be operator-observable in the Actions UI.

**`commitlint.config.js`** — extends `@commitlint/config-conventional` with:
- Relaxed `header-max-length` to 150 chars (project uses verbose summaries like `feat(v7-9-1): F-LAUNCHD-DRIFT-EXTENSION sub-fixes (b)+(c)...`)
- Relaxed `body-max-line-length` to 200 chars (commit bodies use prose-style sentences)
- Lowercase-only `type-case` + `scope-case`
- Project-scoped `type-enum` (11 types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert)

**`.github/workflows/commitlint.yml`** — installs `@commitlint/cli` + `@commitlint/config-conventional`, computes merge-base vs `origin/main` via `git merge-base`, lints every commit in the PR range. `continue-on-error: true`. Security note: `BASE` and `HEAD` are computed locally via git rather than read from the event payload, so no untrusted-input interpolation.

**`.github/workflows/shellcheck.yml`** — runs `ludeeus/action-shellcheck@master` against `scripts/` (recursive) + `.githooks/pre-commit` (explicit additional file). Severity threshold `warning`. `continue-on-error: true`.

**`docs/master-plan/dev-env-master-plan-2026-05-24.md`** — R11/R13/R14/R17/R18 rows in the R-table updated from `[ ] OPEN` to either `[x] SHIPPED` (R13, R14, R17) or `[~] GH Action SHIPPED` (R11, R18 — pre-commit hook integration deferred).

## Why warn-only

The dev-env-master-plan §3 explicitly defers gate-flips: "warn-only baseline → calibrate against 30 days of CI runs → operator decides whether to promote to strict." That pattern matched R7+R8+R12 (which shipped earlier today as Track B) and matches here. Premature strict-mode produces two failure modes: (a) thresholds too aggressive → legitimate work gated → operator overrides pile up → discipline erodes, (b) thresholds too lenient → no signal value. The 30-day calibration window is the structural defense.

## Why pre-commit hook integration is deferred for R11 + R18

The `.githooks/pre-commit` script is the framework's integrity-gate substrate (12 write-time gates as of v7.9.1). Adding gitleaks or shellcheck steps to it is a kill-criterion #2 risk: a hook regression would block the operator's commit flow until the new step is debugged. The GH Action workflows for both R11 and R18 ship now in warn-only mode; the pre-commit hook integration is queued as a follow-on PR after 14 days of clean CI runs validate the toolchain.

## Verification

```bash
# All 5 workflow YAMLs parse:
for f in .github/workflows/{gitleaks,pip-audit,sbom,commitlint,shellcheck}.yml; do
  python3 -c "import yaml; yaml.safe_load(open('$f')); print('$f: OK')"
done

# commitlint.config.js parses as valid JS:
node -c commitlint.config.js

# All present and committed:
git status --short
```

All three checks pass at commit time.

## Open follow-ups

- **2026-07-04 (T+30d)** — first read of accumulated CI run data. Operator decides per-workflow whether to promote any to strict mode.
- **R11 pre-commit hook integration** — separate PR; queued after first 14 days of clean CI runs.
- **R18 pre-commit hook integration** — same disposition as R11.
- **2026-06-12 External Audit #2** — operator pulls gitleaks + pip-audit + SBOM artifacts from the most-recent run to include in the audit pack.

## Remaining dev-env open items (post-this-batch)

| R# | Item | Disposition |
|---|---|---|
| **R10** | launchd → GHA daily-checkpoint migration | Calendar-safe but interacts with the just-shipped F-LAUNCHD-DRIFT-EXTENSION; defer 14 days to avoid mid-soak contamination |
| **R15** | Playwright smoke specs for fitme-story | Out of FT2 scope (lives in fitme-story repo) |
| **R16** | `@sentry/nextjs` for fitme-story | Out of FT2 scope + gated on Sentry-integration pre-launch trigger |
| **R19** | Containerize ai-engine via devcontainer | Q3 2026 with ai-engine deployment |
| **R20–R24** | Lighthouse-CI, App Thinning, OpenTelemetry, Storybook, distributed Sentry | All post-App-Store-launch |

After this PR ships, FT2 has **0 immediately-actionable dev-env R-items remaining** — everything is either out-of-scope (FT2), deferred for the F-LAUNCHD soak, or post-launch.

## References

- **Spec:** [`dev-env-master-plan-2026-05-24.md`](../master-plan/dev-env-master-plan-2026-05-24.md) §3 R11 + R13 + R14 + R17 + R18
- **Predecessor:** [`r9-track-b-coverage-aggregator-case-study.md`](r9-track-b-coverage-aggregator-case-study.md) (same session — R9 Track B shipped first)
- **Companion downstream consumer:** External Audit #2 (2026-06-12) — audit pack will include this batch's CI artifacts
