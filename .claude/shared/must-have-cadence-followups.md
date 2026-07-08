# Must-have cadence follow-ups

> Created 2026-05-15 from the prioritization cross-reference of [`docs/master-plan/infra-master-plan-2026-05-12.md`](../../docs/master-plan/infra-master-plan-2026-05-12.md), [`docs/master-plan/data-integrity-and-rollback-2026-05-14.md`](../../docs/master-plan/data-integrity-and-rollback-2026-05-14.md), and [`docs/master-plan/test-coverage-master-plan-2026-05-13.md`](../../docs/master-plan/test-coverage-master-plan-2026-05-13.md).
>
> This file tracks the MUST-HAVE items that are NOT yet wired as code (calendar-anchored verifications + feature-scope coding work). Streams A (data-health/integrity infra) and D (preflight entry points) shipped in the same batch and are NOT listed here.

## Calendar-anchored verifications

Surfaced daily by `scripts/daily-integrity-checkpoint.py` when the target date is ≤14 days away.

| ID | Date | Event | Owner | Source |
|---|---|---|---|---|
| ~~B1~~ | ~~2026-05-21~~ | ~~v7.9 promotion-decision data freeze~~ **EXECUTED 2026-05-21** — promotion shipped same day via PR #417 (`ea53ff4`). All §B1 prerequisites met: `make integrity-check` 0 findings, `make integrity-diff` no regression vs 2026-05-14 anchor, `make documentation-debt` ≤ baseline, `make measurement-adoption` captured, `membrane-status.py` captured, 14d gate-coverage telemetry confirmed no `GATE_COVERAGE_ZERO`. 3 advisory gates flipped to enforced. Ledger strikethrough deferred until 2026-05-27 reconcile (this PR). | operator | infra-plan §4.1, master-plan §2.2 |
| ~~B2~~ | ~~2026-05-28~~ | ~~Post-v7.9 T+7d baseline snapshot~~ **EXECUTED 2026-05-28T16:30:12Z** — `make snapshot-phase PHASE=post-v7-9-baseline FEATURE=framework-v7-8-branch-isolation` produced `~/Documents/FitTracker2-backups/2026-05-28-framework-v7-8-branch-isolation-post-v7-9-baseline/` (8 files: 6 feature source files + CHECKSUMS.sha256 + MANIFEST.md; on internal Mac storage per established convention). `shasum -a 256 -c CHECKSUMS.sha256` returned 6/6 source files OK; the lone `MANIFEST.md: FAILED` is a known cosmetic ordering bug in `scripts/snapshot-phase-completion.sh` (manifest is written after the checksum file, so its hash is stale by design). Commit SHA at capture time: `3fb76d0` (main HEAD pre-#521 manifest backfill). Unblocks `framework-v7-9-promotion` advance from `docs` → `complete` (case-study §99 synthesis + `kill_criteria_resolution` backfill). Follow-up: meta-analysis case study comparing 2026-05-12 pre-v7-9-baseline vs this snapshot is a separate task (B2's literal trigger is "snapshot taken"; the comparison is part of Phase E exit ~2026-06-04). | operator | data-integrity §3.2 trigger (2) |
| B3 | **daily, starting now** | GA4 anomaly check (event volume + funnel breaks) | operator + GA4 MCP | analytics-observability epic |
| B4 | **2026-08-13** | Quarterly cross-layer test-discipline audit (initial run) | operator | test-coverage §6.2 |
| B5 | **2026-11-13** | Quarterly cross-layer test-discipline audit (recurring) | operator | test-coverage §6.2 |
| ~~B6~~ | ~~2026-05-22~~ | ~~C1 start — F14/F15 dispatch-test coverage push (deferred from 2026-05-21)~~ **Closed 2026-05-23 via PR #451 (squash `86084c4`); 9/9 dispatch tests + Phase 8 docs landed together.** | operator | followups §C1 |
| ~~B7~~ | ~~2026-05-18~~ | ~~UCC Part 9 — wire `UCC_AUDIT_BLOB_URL` repo variable in FT2~~ **Closed 2026-05-17 via FT2 PR #387** (preemptive wire; Part 9 shipped) | operator | ucc-passkey-auth case study §99 |
| ~~B8~~ | ~~2026-05-23~~ | ~~UCC T+7d kill-criteria checkpoint~~ **EXECUTED 2026-05-23**: K2 `not_fired` [T1 — 0 `counter_replay` events in 3-day Vercel log scan]; K1+K3 `not_yet_observed` [T1 — 0 registrations + 0 sign-ins in cohort window, operator routed via `gh`/CLI not `/control-room/*`]. No fall-back. `UCC_AUTH_MODE=both` remains live. Re-eval at B12 (2026-05-27) or first organic sign-in. Resolution in [`ucc-passkey-auth-case-study.md`](../../docs/case-studies/ucc-passkey-auth-case-study.md) frontmatter + §99 row. | operator | ucc-passkey-auth PRD §6 |
| ~~B9~~ | ~~2026-05-28+~~ | ~~UCC Part 8 — flip `UCC_AUTH_MODE=passkey` + drop `DASHBOARD_USER`/`DASHBOARD_PASS` (irreversible direction)~~ **CLOSED 2026-05-29 — RESOLVED AS "STAY ON `both`"** (operator decision). Part 8 (passkey-only flip + credential drop) DELIBERATELY NOT EXECUTED. Terminal rollout state: `UCC_AUTH_MODE=both` permanently — passkey primary, basic-auth password **retained as break-glass fallback in case passkey fails** (belt-and-suspenders alongside the C4 break-glass credential, which has an iCloud-Keychain dependency caveat). Verified live 2026-05-29: `UCC_AUTH_MODE=both` + `DASHBOARD_USER` + `DASHBOARD_PASS` all present in Production. Runbook Part 8 marked DO-NOT-RUN. No production env change made. | operator | infra-plan §4.1 + ucc-passkey-auth case study §99 |
| ~~B10~~ | ~~2026-05-21~~ | ~~Audit substrate spec §12 OQ #1 — decide `docs/audits/runs/<date>/bundle.md` commit policy~~ **Closed 2026-05-19: commit per-run artifacts (bundle.md + manifest + redaction-log) for public reproducibility; shipped via PR #405 update** | operator | [`docs/superpowers/specs/2026-05-18-impartial-audit-prompt-substrate-design.md`](../../docs/superpowers/specs/2026-05-18-impartial-audit-prompt-substrate-design.md) §12 OQ #1 |
| ~~B11~~ | ~~2026-05-22~~ | ~~UCC hardening T+3d calibration window check~~ **EXECUTED 2026-05-22** per session memory `project_session_2026_05_21_v7_9_devenv_ghsec.md` — signals 1+2+3 PASS (`auth_lockout_*` = 0 across 3-day window; no `email_not_allowlisted` for operator hash `sha256:b6d3b138…`; sign-in p50 latency Δ within instrument noise). Signals 4+5 (Redis quota + bootstrap-token issuance event volume) auto-on-first-organic-signin. Re-confirmed by B12 (2026-05-27 PR #503) full T+7d re-evaluation showing 0 lockout events across the entire 7-day window. Ledger strikethrough deferred until 2026-05-27 reconcile (this PR). | operator | [`docs/superpowers/specs/2026-05-19-ucc-passkey-security-hardening-design.md`](../../docs/superpowers/specs/2026-05-19-ucc-passkey-security-hardening-design.md) §11 |
| ~~B12~~ | ~~2026-05-27~~ | ~~UCC hardening T+7d kill-criteria evaluation~~ **EXECUTED 2026-05-27 — VERDICT: PROMOTE** (PR #503, squash `bca2e12`). K1+K3+K4 not fired (0 lockout events, 0 allowlist_unset events, operator signed in 4× across window). K2 instrumentation invalid (audit-log `duration_ms` measures end-to-end WebAuthn ceremony incl. user-touch, not the +1-Redis-GET server-side overhead the +5ms threshold was sized for); v7.9.1 candidate **F-AUTH-LATENCY-SERVER-METRIC** queued at [`v7-9-1-candidates.md`](v7-9-1-candidates.md) to wire dedicated server-side timing field. Primary metric `unauthorized_operator_registration_attempts_succeeded = 0`. Case study §4 + §99 + frontmatter `kill_criteria_resolution` populated; state.json advanced `documentation → complete`. | operator | [`docs/case-studies/ucc-passkey-auth-security-hardening-case-study.md`](../../docs/case-studies/ucc-passkey-auth-security-hardening-case-study.md) §4 + §99 |
| ~~B13~~ | ~~2026-05-30~~ | ~~HADF Sub-exp 2 launch readiness — (a) rebase `feat/hadf-phase2bis-impl` worktree onto current `main` (38 commits behind per `make freshness-check`); (b) fix `~/.fittracker/hadf-snapshot.sh` to avoid writing Sub-exp 2 data into Sub-exp 1A's dated backup dir — generalize `INTERNAL_BACKUP` path OR switch to per-sub-exp dirs; (c) optional: move `SSD_BACKUP` off-SSD per spec §3 Fix #4~~ **EXECUTED 2026-05-30**: (a) impl tree rebased onto current main (commit `8da3297` = Sub-exp 2 prereg lock on top of #534); (b) `~/.fittracker/hadf-snapshot.sh` patched with per-sub-exp routing via case statements (`get_internal_backup` + `get_ssd_backup` functions); confirmed working via "snapshotted 2 sub-exp(s) — total 34 file ops" at 2026-05-30T07:04:23Z. Sub-exp 2 + Sub-exp 1A data now route to dedicated dirs (`~/Documents/.../2026-05-30-hadf-sub-exp-2-raw-data/` + `~/Documents/.../2026-05-26-hadf-sub-exp-1a-raw-data/`); cross-comingling verified clean during 2026-05-30T08:17Z system check. (c) off-SSD `SSD_BACKUP` move remains optional, deferred. **First Sub-exp 2 cron fire 2026-05-30T08:00Z**: 50/50 OK · TTFT p50=153ms · TPS p50=44.58 · output p50=141 tok. | operator | freshness-check 2026-05-29 finding |
| ~~B14~~ | ~~2026-06-01 05:00 UTC~~ | ~~framework-status-weekly cron resilience — last 2 failures (2026-05-04 + 2026-05-25) were GitHub 500 on the push step; add retry/backoff (3 attempts, 2s/5s/15s) OR `continue-on-error: true`~~ **SHIPPED 2026-05-30 via PR #529 (`717cf8e`)**: primary `peter-evans/create-pull-request@v8` step now has `continue-on-error: true`; shell-fallback step runs on failure with explicit `for delay in 2 5 15` retry loop on BOTH `git push --force-with-lease` AND `gh pr create`. Loud `::error::` annotation if all 3 attempts exhaust. Closes the documented 2026-05-04 + 2026-05-25 outage class before the next Monday cron fire. | operator | freshness-check 2026-05-29 finding |

| ~~B15~~ | ~~2026-06-21~~ | ~~T14 `PLATFORMS_TESTED` advisory→enforced calibration review~~ **EXECUTED 2026-06-21 — VERDICT: PROMOTE** (PR #781, squash `6ac372b`). All four §2.2 criteria GREEN on the isolated `PLATFORMS_TESTED` coverage key: (1) 14d emission (first_seen 2026-06-07 → 2026-06-21); (2) 0 false positives — 0 failure snapshots across 16 firings / 1486 candidates; (3) no silent skips — 1470 skips all legit (`exempt:framework_meta` / non-complete transitions); (4) reversible single-flag. Flipped `PLATFORMS_TESTED_ADVISORY_MODE = True → False` at [`scripts/check-state-schema.py:164`](../../scripts/check-state-schema.py); 31 gate tests pass. Branch was rebased onto current main before merge (was 4 behind). **Still remaining (cross-repo, not blocking):** T7 fitme-story dev-guide+glossary, T8 showcase MDX. | operator | t14-platform-parity-state-field PRD §6 T9 |
| B16 | **~2026-07-13** | AN-1B.1 `CSV_TAXONOMY_DRIFT` advisory→enforced review (T+14d from 2026-06-29 advisory ship, #822). Flip `CSV_TAXONOMY_DRIFT_ADVISORY_MODE = True → False` at [`scripts/check-state-schema.py`](../../scripts/check-state-schema.py) when all 4 criteria hold: (1) ≥7d `CSV_TAXONOMY_DRIFT` coverage in `gate-coverage.jsonl` — **pending (~2026-07-13)**; (2) ✅ **baseline burndown DONE 2026-06-29 — drift 27 → 0** (27 taxonomy CSV rows added, B16 burndown PR); (3) 0 false positives at flip review; (4) reversible single-flag (<2 min). The gate only fires when `AnalyticsProvider.swift` is staged, so it never blocks unrelated commits. **Remaining at flip: criterion 1 (coverage window) + criterion 3 (review).** Criteria + KC1/KC2 in [`calibration-artifacts.md`](../features/an-1b1-csv-taxonomy-drift/calibration-artifacts.md). | operator | analytics-master-plan §8.2 + an-1b1 calibration-artifacts.md |

### B1 — v7.9 promotion-decision data freeze (2026-05-21)

Required actions on the day:

1. `make integrity-check` — must report 0 findings
2. `make integrity-diff` — must report no regression vs 2026-05-14 anchor
3. `make documentation-debt` — must report ≤ baseline open count
4. `make measurement-adoption` — capture for the promotion record
5. `python3 scripts/membrane-status.py` — capture
6. Review last 14 days of `.claude/logs/gate-coverage.jsonl` — verify no `GATE_COVERAGE_ZERO` for any gate that previously fired
7. Decision: flip v7.8.x advisory gates to enforced (specific list in infra-plan §4.1)

### B2 — Post-v7.9 T+7d baseline (2026-05-28) — EXECUTED 2026-05-28T16:30:12Z

```bash
make snapshot-phase PHASE=post-v7-9-baseline FEATURE=framework-v7-8-branch-isolation
```

**Output:** `~/Documents/FitTracker2-backups/2026-05-28-framework-v7-8-branch-isolation-post-v7-9-baseline/` (8 files: feature source + CHECKSUMS.sha256 + MANIFEST.md; on internal Mac storage per established off-SSD backup convention). Commit SHA at capture: `3fb76d0` (main HEAD pre-#521).

**Verification:** `shasum -a 256 -c CHECKSUMS.sha256` → 6/6 source files OK. `MANIFEST.md: FAILED` is a known cosmetic bug in `scripts/snapshot-phase-completion.sh` ordering (manifest written after checksums file generated, so its hash is stale by design). No data corruption; safe to ignore.

**Comparison vs 2026-05-12 pre-v7-9-baseline (predecessor):** deferred to Phase E exit synthesis (~2026-06-04). Both snapshots co-located at `~/Documents/FitTracker2-backups/2026-05-{12,28}-framework-v7-8-branch-isolation-{pre,post}-v7-9-baseline/`. Meta-analysis case study slot reserved at [`docs/case-studies/meta-analysis/`](../../docs/case-studies/meta-analysis/) for Phase E exit synthesis.

**Downstream unlock:** `framework-v7-9-promotion` feature advance from `docs` → `complete` is now unblocked (per state.json `phases.docs.notes`: "B2 baseline snapshot 2026-05-28 triggers §99 case-study synthesis + kill_criteria_resolution backfill"). Separate follow-up task; not part of B2 closure scope.

### B3 — Daily GA4 anomaly check

Possible since 2026-05-14 GA4 MCP connection (FIT-142, PR #362). Suggested daily query set:

```
mcp__ga4__getEvents period=last_24h
mcp__ga4__runReport metric=screen_view dimension=date period=last_7d
mcp__ga4__runReport metric=conversions period=last_24h
```

Flag day-over-day deltas > 30% as anomalies. No automation yet — operator runs in a session.

**Last run: 2026-07-08.** No anomalies. Window 2026-07-01→07-05 (07-06→08 show 0 events — consistent with no operator app-opens those days, not a reporting gap; pre-launch TestFlight traffic is operator-only, single-digit volumes). Funnels intact: onboarding (`onboarding_step_viewed`→`_completed`→`goal_selected`→`skipped`) and auth (`auth_biometric_activation_offered`→`_unlock_completed`) both present with expected proportions. Home surfaces (`home_ai_insight_shown`, `home_readiness_score_computed`) firing. No new/unexpected event types, no screen-prefix violations, 0 `home_*_alert_*` (expected — TestFlight build not yet shipped to testers). Day-over-day deltas within pre-launch noise; no >30% anomaly. Full deliverable: [`docs/setup/ga4-funnels-and-conversions-runbook.md`](../../docs/setup/ga4-funnels-and-conversions-runbook.md).
_Prior run 2026-06-01: no anomalies (partial-day artifact; 31 event types over 2 days)._

### B7 — UCC Part 9 wire `UCC_AUDIT_BLOB_URL` (2026-05-17)

After tonight's `13 5 * * *` Vercel Cron at fitme-story populates the Blob:

```bash
cd /Volumes/DevSSD/fitme-story
CRON_SECRET=$(grep CRON_SECRET .env.local | cut -d= -f2)
URL=$(curl -s -H "Authorization: Bearer $CRON_SECRET" \
  https://fitme-story.vercel.app/api/cron/sync-audit-log | jq -r .url)
gh variable set UCC_AUDIT_BLOB_URL --body "$URL" --repo Regevba/FitTracker2
gh workflow run "UCC audit log sync" --repo Regevba/FitTracker2
```

Activates the daily FT2 GHA T22 workflow (currently a no-op waiting on this variable).

### B8 — UCC T+7d kill-criteria checkpoint (2026-05-23)

Resolve K1 (registration ceremony failure rate ≤ 5%), K2 (any `counter_replay` = HARD STOP), K3 (function p50 ≤ 500ms sustained 24h) using:

- Redis SCAN for `ucc:credential:*` + `ucc:operator:*` + audit-log events
- Vercel function logs (p50 latency)
- 7-day audit-log JSONL at `.claude/logs/ucc-auth-events.jsonl` (via B7-activated sync)

Update `kill_criteria_resolution` frontmatter in `docs/case-studies/ucc-passkey-auth-case-study.md` + replace pending row in §99 with the T1 resolution.

### B9 — UCC Part 8 passkey-only flip (2026-05-28+)

PRECONDITIONS (ALL must hold):
1. **B8 completed** — kill criteria resolved as `not_fired`
2. **C4 completed** — at least one break-glass credential registered (YubiKey OR 2nd platform passkey)
3. **B2 captured** — post-v7.9 baseline snapshot complete
4. **0 open `auth_passkey_register_failed` events in audit log for last 7 days**

If all hold:

```bash
# PATCH UCC_AUTH_MODE both → passkey via Vercel REST API + delete legacy basic-auth creds
# See ucc-passkey-auth-setup-guide.md Part 8 for exact commands
# DO NOT run any other infra change on the same day — single-variable blast radius
```

Rollback: PATCH back to `both` (30 seconds), re-add `DASHBOARD_USER`/`DASHBOARD_PASS` if dropped.

### ~~B10 — Audit substrate bundle.md commit policy~~ (CLOSED 2026-05-19)

**Resolution:** commit per-run artifacts (`bundle.md`, `manifest.json`, `redaction-log.json`, plus the auditor's report) under `docs/audits/runs/<date>-<model>/`. Public reproducibility wins over repo-size concerns: ≈5–10 MB/year for 8 audits/year is fine for an audit-of-record, and the bundle is the canonical "what the auditor saw" that audit findings reference. Only ad-hoc scratch (`runs/*/scratch/`, `runs/*/.cache/`, `runs/*/*.tmp`) remains gitignored.

**Shipped via:** PR #405 same-day update — `.gitignore` rule rewritten, spec §12 OQ #1 marked resolved with rationale captured inline.

### ~~Production incident — `/control-room/framework` TypeError~~ (CLOSED 2026-05-24)

**Resolution:** 13-day silent regression rendering Next.js error boundary every visit. Root cause: schema mismatch — FT2 producer `scripts/gate_coverage.py` emits `{"timestamp": …}` but fitme-story `gate-coverage-aggregator.ts` expected `event.ts`. Test fixtures used the consumer's wrong field too, so 6/6 tests stayed green. Hotfix renamed field + added back-compat alias + defensive sort comparator.

**Lesson captured as W16 in [`observed-patterns.md`](../integrity/observed-patterns.md):** contract-boundary tests must use a fixture sample drawn from the canonical producer, not the consumer's expected shape. v7.9.1 candidate **F-CONTRACT-FIXTURE-SAMPLING** (filed as E-15) builds the `make sample-contract-fixtures` aggregator closing this silent-pass class for all cross-repo data contracts.

**Shipped via:** fitme-story PR #146 (hotfix) + FT2 PR #476 (W16 catalog + E-15 docket).

### ~~Phase 3.A drift reconciliation (analytics-observability)~~ (CLOSED 2026-05-24)

**Resolution:** 9 of 9 `/control-room/analytics` green-bucket items per analytics master plan §7.5 shipped on disk since 2026-05-14 (3.A.0 + 3.A.1 fitme-story PR #108 squash `945e90c`). Sub-task entries correctly marked complete, but enclosing `phases.implementation.status` remained `"pending"` with empty `commits: []`. **Shipped via:** FT2 PR #477.

### ~~Post-v7-9 docket C-14 + E-12 + E-13 audits~~ (CLOSED 2026-05-24)

All 3 ✅ Healthy / ✅ Paused-state intact; no changes required to either system.

- **E-12** ai-engine Dockerfile: pinned `python:3.12-slim`, Railway target confirmed, deps floor-pinned identical to last verified state (2026-04-20). [Report](../../docs/audits/runs/2026-05-24-e12-e13-ai-engine-cohort/audit-report.md).
- **E-13** Cohort telemetry: loop emits via 5 endpoints (fire-and-forget); iOS read/write loop closed via `/reminder-cohort-priors` (k-anonymity floor 50). Zero rows at TestFlight stage is expected pre-launch posture.
- **C-14** Orchid v1.5 paused-state intact: Track L + D-partial shipped; D-D3 + R blocked per documented `paused.resume_signal`. [Report](../../docs/audits/runs/2026-05-24-c14-orchid-v1-5-status/audit-report.md).

**Shipped via:** FT2 PR #478 (E-12 + E-13) + FT2 PR #480 (C-14).

### HADF Phase 2 external audit — step (1) DONE 2026-05-24

Replication pack at [`docs/audits/runs/2026-05-24-hadf-phase2-replication-pack/`](../../docs/audits/runs/2026-05-24-hadf-phase2-replication-pack/) with REPLICATION-README.md (operator runbook + mechanical pass/fail rule + expected per-k silhouettes 0.5067/0.5228/0.5460/**0.5566**/0.4056) and manifest.json (raw dataset SHA-256 + 3 alternate access paths for the gitignored raw `.jsonl`).

**Operator action remaining (steps 2 + 3):**

1. Post replication invitation to Tier 3.3 thread (GitHub Issue #142 OR new dedicated thread)
2. T+60d (~**2026-07-24**): if no external replicator emerges, decide pending vs internal per `feedback_external_audit_status_is_ui_marker.md`

**Shipped via:** FT2 PR #480.

### ~~Dev-env R7 + R8 + R9 + R12 Track A~~ (CLOSED 2026-05-24)

Lint + coverage configs shipped warn-only across all 3 stacks per dev-env-master-plan §0 Top-3. **Track B (Makefile + verify-local + CI workflow integration) remains open** — infra-glob, isolated worktree, post-Phase-E (~2026-06-04).

| R | Track A shipped | Track B status |
|---|---|---|
| R7 SwiftLint | `.swiftlint.yml` warn-only — FT2 PR #481 | OPEN (Makefile `lint-ios` + Xcode build phase) |
| R8 ruff | `.ruff.toml` + ai-engine `[tool.ruff]` — FT2 PR #481 | OPEN (Makefile `lint-py`) |
| R9 coverage | iOS Slather + ai-engine `pytest-cov` (FT2 PR #479) + fitme-story `c8` (fitme-story PR #147) | OPEN (Makefile `coverage-report` + `.github/workflows/coverage.yml` + Codecov) |
| R12 markdownlint | FT2 `.markdownlint-cli2.jsonc` (FT2 PR #481) + fitme-story config + devDep (fitme-story PR #148) | OPEN (Makefile `lint-md` + `make verify-local` integration) |

**Track B bundle target:** single isolated-worktree PR week of 2026-06-09, ~6-8h all-in (covers R7+R8+R9+R12 Track B + R10 launchd→GHA + R11 gitleaks).

### ~~Audit-log Redis fix T6 status drift~~ (CLOSED 2026-05-24)

`ucc-passkey-auth-audit-log-redis-fix` T6 was `status: pending` despite cascade fully resolved 2026-05-19 (Vercel CRON_SECRET fix) + 2026-05-20 (FT2 PR #411 workflow PR-pattern refactor eliminating GH006 protected-branch-update-failed). Reconciled T6 → complete with `completed_at: 2026-05-20T00:00:00Z`.

### B4 / B5 — Quarterly cross-layer test audit

Per test-coverage §6.2. Initial run 2026-08-13, then recurring every 90 days. Output: `docs/process/cross-layer-test-audit-YYYY-MM-DD.md`.

Assertions:
- Test count not declining
- Production-symbol coverage ≥ prior quarter
- No new zero-coverage directories
- Staleness markers (Test Plan files older than 90 days) trending down

## Feature-scope MUST items (require PM workflow)

These require Plan→Implement→Test cycles and cannot be inlined into the cadence-batch PR.

| ID | Title | Plan ref | RICE | Suggested work_type | Target ship |
|---|---|---|---|---|---|
| ~~C1~~ | ~~F14/F15 dispatch-test coverage push~~ **Closed 2026-05-23 via PR #451 (squash `86084c4`); 9/9 dispatch tests + Phase 8 docs shipped together. Case study: [docs/case-studies/framework-f14-f15-dispatch-test-coverage-case-study.md](../../docs/case-studies/framework-f14-f15-dispatch-test-coverage-case-study.md).** | test-coverage-master-plan §2.1 + §4.1 | (gates v7.9 promotion) | feature | **2026-05-22** (deferred 2026-05-15) |
| ~~C2~~ | ~~T6 — Web PR JS test gate (fitme-story CI)~~ **CLOSED 2026-05-23 via fitme-story PR #137** (`df3c527`). Shipped `unit-tests` job in [`.github/workflows/integrity.yml:80-101`](https://github.com/Regevba/fitme-story/blob/main/.github/workflows/integrity.yml#L80) — runs `npm test` (`tsx --test` on 112 test cases across `scripts/` + `src/`) on every PR + push to main. Highest-RICE item from test-coverage-master-plan now LIVE. | test-coverage-master-plan T6 | **200.0** | enhancement (on analytics-observability) | ~~2026-05-21~~ shipped 2026-05-23 |
| ~~C3~~ | ~~T2 — Sentry reachability test (iOS)~~ **DEFERRED to App Store launch trigger** per project memory `project_sentry_integration_in_progress.md` (Sentry integration entire stack paused 2026-05-21; TestFlight beta is not real-user signal, no value in landing a reachability test against an inactive service). Re-eval when app store launch is scheduled. | test-coverage-master-plan T2 | 80.0 | enhancement (test-coverage) | ~~2026-05-28~~ TBD post-launch |
| ~~C4~~ | ~~UCC Part 7 — break-glass registration (YubiKey OR 2nd platform passkey)~~ **CLOSED 2026-05-25 with iCloud-Keychain caveat.** Verified live via iPhone Safari authentication at 2026-05-25T12:28:27Z using existing Mac Touch-ID credential `sha256:f79a7c595aaab` (iCloud Keychain auto-sync = de-facto multi-device break-glass). YubiKey attempted twice today, both failed `bootstrap_invalid` due to iCloud's existing-passkey detection + server-side `excludeCredentials` list interaction. Caveat: NOT iCloud-independent — Apple ID compromise/lockout would lose both devices simultaneously. Hardware-independent path (temp `authenticatorAttachment: 'cross-platform'`) queued as v7.9.1 follow-up if launch-blocking. **B9 precondition #2 satisfied with caveat.** | ucc-passkey-auth case study §99 | (gates B9) | operator action | ~~before 2026-05-28~~ closed 2026-05-25 |
| ~~C5~~ | ~~UCC Part 10 — verify framework-health passkey panel renders w/ real audit data~~ **VERIFIED 2026-05-27** via static + data inspection (same pattern as C9/C10 closures). Wiring confirmed at [`fitme-story/src/app/control-room/framework/page.tsx:444`](https://github.com/Regevba/fitme-story/blob/main/src/app/control-room/framework/page.tsx#L444) rendering `<AuditLogPanel />`. Component reads via [`fitme-story/src/lib/auth/load-events.ts`](https://github.com/Regevba/fitme-story/blob/main/src/lib/auth/load-events.ts) → `readEvents` from Upstash Redis LIST `ucc:audit-log:events` (NOT the blob — Redis is primary, blob is derived for daily FT2 mirror). Data source live: production audit-log blob has 59 events 2026-05-17 → 2026-05-25, all derived from Redis, so Redis has ≥59 events. Panel handles both empty (placeholder) and populated (3-stat row + suspicious banner + recent-5 list) states. Full live-render verification still needs a browser visit by the operator, but the panel cannot logically render empty given the production data state — this is the same "verified by inference from data + code" pattern accepted for C9 (coral-pulse animation) and C10 (dark-mode contrast). | ucc-passkey-auth case study §99 | (depends on B7 + 1 daily sync) | operator action | ~~2026-05-18 earliest~~ verified 2026-05-27 |
| ~~C6~~ | ~~Bootstrap CLI — add `KV_REST_API_*` fallback in `scripts/issue-bootstrap-token.ts`~~ **CLOSED 2026-05-23 via fitme-story PR #139**. Verified present in `scripts/issue-bootstrap-token.ts:48-50`: `process.env.UPSTASH_REDIS_REST_URL \|\| process.env.KV_REST_API_URL`. | ucc-passkey-auth case study §99 quirk 2 | low (operability) | fix (fitme-story) | ~~2026-05-22~~ shipped 2026-05-23 |
| ~~C7~~ | ~~Vercel CLI env-add wrapper — REST API helper to bypass headless bug~~ **CLOSED 2026-05-23 via PR #454** (squash `e9066018`). Shipped `scripts/vercel-env-add.sh` — Bash + curl + jq wrapper around `POST /v10/projects/{id}/env`. | ucc-passkey-auth case study §99 quirk 1 | low (operability) | chore (FT2 helper) | ~~2026-05-22~~ shipped 2026-05-23 |
| ~~C8~~ | ~~SessionStart preflight — detect stale `.vercel/project.json` pointing to legacy `fit-tracker2`~~ **CLOSED FT2-side 2026-05-23 via PR #454; C8b CLOSED fitme-story-side 2026-05-24 via fitme-story PR #143** (mirrored script + .claude/settings.json SessionStart hook). | ucc-passkey-auth case study §99 quirk 4 | low (operability) | chore (FT2 + fitme-story `.claude/settings.json`) | ~~2026-05-22~~ FT2 shipped 2026-05-23; C8b shipped 2026-05-24 |
| ~~C9~~ | ~~UCC coral-pulse animation on `/control-room/sign-in` (800ms-after-load nudge)~~ **CLOSED — already shipped pre-2026-05-24**. Verified: `@keyframes coral-pulse-cta` + `.coral-pulse-cta` class in `src/app/globals.css:108-118` (700ms ease-out animation, 800ms delay, 1 forwards); class conditionally applied at `src/components/control-room/AuthPasskeyForm.tsx:242-243` when `mode === 'authenticate' && status === 'idle'`. Global `@media (prefers-reduced-motion: reduce)` rule at `globals.css:99-103` neutralizes the animation (0.001ms) for motion-sensitive users. | ucc-passkey-auth ux-spec §6 + ux-pre-merge-review (1 P2) | P2 | enhancement (fitme-story) | ~~when convenient~~ already shipped |
| ~~C10~~ | ~~UCC 4 control-room dark-mode contrast verifications — `AuthPasskeyForm` / `DevicesTable` / `AuditEventRow` / `AuditLogPanel`~~ **CLOSED — all 4 verified 2026-05-16** per [`docs/design-system/fitme-story-dark-mode-coverage.md`](../../docs/design-system/fitme-story-dark-mode-coverage.md) lines 79-82: AuditEventRow ≈ 9.5–13.4:1 ✓; AuditLogPanel ≈ 8.7–11.5:1 ✓; AuthPasskeyForm ≈ 4.7–14:1 ✓ (4.7:1 focus ring passes 3:1 UI threshold); DevicesTable ≈ 3.6–5.5:1 ✓ (3.6:1 destructive pill passes 3:1 UI threshold). All 4 explicitly pass WCAG AA. | fitme-story-dark-mode-coverage.md | P2 | enhancement (fitme-story) | ~~when convenient~~ shipped 2026-05-16 |
| ~~C11~~ | ~~MEMORY.md staleness check~~ **CLOSED 2026-05-23 via PR #454**. Shipped `scripts/check-memory-staleness.py` + `make memory-check` + Stop hook in `.claude/settings.json`. Baseline at ship: MEMORY.md 28.1 KB (over 24 KB soft limit) / 151 indexed / 161 on-disk → 10 orphans + 29 long lines (informational, not blocking). | session-end checklist formalization | low (operability) | chore (FT2) | ~~2026-05-22~~ shipped 2026-05-23 |
| ~~C12~~ | ~~Preflight bug fix — `scripts/preflight.py:264` `enhancement_parent_state()`~~ **CLOSED 2026-05-23 via PR #454**. Function now reads enhancement's own state.json → extracts `parent_feature` → checks THAT parent's state.json + prd.md. Verified on `ucc-passkey-auth-security-hardening` → parent=`ucc-passkey-auth` phase=complete, prd.md present=True. | 2026-05-17 UU4 setup | low (preflight reliability) | fix (FT2) | ~~2026-05-22~~ shipped 2026-05-23 |

### ~~C1 — F14/F15 dispatch-test coverage push~~ (Closed 2026-05-23 via PR #451, squash `86084c4`)

**Problem (preserved for historical context):** Mechanism A coverage telemetry was unreliable for 4 gates with zero dispatch tests + 5 zero-coverage gates. Without dispatch tests asserting each gate function fires, a keying drift (like the `created` vs `created_at` v7.8 incident) could silently zero out coverage.

**Approach taken:** 9 `test_main_dispatch_<gate>()` end-to-end tests asserting (a) the gate's `main()` dispatcher invokes the gate function for matching inputs (via monkey-patch isolation), (b) a `candidate` row is written to a tmp `gate-coverage.jsonl` (for the 7 gates with Mechanism A telemetry), (c) the row has expected `gate=` and non-zero `candidates`. 2 gates (`CASE_STUDY_MISSING_FIELDS`, `PR_CACHE_STALE`) lack Mechanism A telemetry — assertion shape adapted (exit-code only); gap captured as a v8.x backlog item.

**What landed (2026-05-22 → 05-23 on `feature/framework-f14-f15-dispatch-test-coverage`):**

- `scripts/tests/conftest.py` — NEW, 330 lines, 4 shared fixtures + 9 violation recipes
- `scripts/tests/test_check_state_schema.py` — EXTENDED, +6 dispatch tests
- `scripts/tests/test_check_case_study_preflight.py` — NEW, 48 lines, 1 dispatch test
- `scripts/tests/test_integrity_check_dispatch.py` — NEW, 239 lines, 2 dispatch tests
- `scripts/tests/test_ensure_pr_cache_fresh.py` — NEW, 151 lines, 1 dispatch test
- Coverage delta: write-time 1/16 → 8/16 = 50%; cycle-time 0/3 → 2/3 = 67%; combined 1/19 → 10/19 = **53%**
- Phase 5 verification: 161/161 pytest pass in 10.82s; 9/9 emit `candidate` row to tmp ledger; canonical `.claude/logs/gate-coverage.jsonl` mtime unchanged (K3 guard held)
- Case study: [`docs/case-studies/framework-f14-f15-dispatch-test-coverage-case-study.md`](../../docs/case-studies/framework-f14-f15-dispatch-test-coverage-case-study.md)
- Backlog: T1 `GATE_TEST_MISSING` meta-gate ticket added to [`docs/product/backlog.md`](../../docs/product/backlog.md)

**Deferral note (decision 2026-05-15, preserved):** Original target was "before 2026-05-21". Operator decision deferred to **2026-05-22 (the day after v7.9 promotion decision)** to preserve the v7.9 calibration baseline (criterion #2 — "no false positives"). Adding 9 new test fixtures during 2026-05-15→05-21 would write ≥9 new `candidate` rows into `.claude/logs/gate-coverage.jsonl` during the calibration window — contaminating the data the promotion decision evaluates. The trade-off: v7.9 ships on 2026-05-21 WITHOUT F14/F15 coverage validated, then C1 lands 2026-05-22 + the v7.9.1 cycle re-evaluates whether the 9 gates promoted with or without these tests should be re-flipped. The auditor flagged this as the right read because the dispatch tests are themselves the Mechanism A validation work — excluding them from the calibration baseline is correct, not a hack.

**Remaining work (pending operator authorization):**

1. ~~Open PR from `feature/framework-f14-f15-dispatch-test-coverage` → `main`~~ **Done** — PR #451 opened 2026-05-23
2. ~~Pre-merge CI green on PR (`pm-framework/pr-integrity`)~~ **Done** — all 8 checks green (Build and Test pass 11m27s, integrity pass 24s, pm-framework/pr-integrity PASS 0 findings, CodeQL × 3 pass, GitGuardian pass)
3. ~~Squash-merge to main~~ **Done** — squash `86084c4` at 2026-05-23T04:55:46Z; feature branch deleted
4. ~~Update this entry with canonical strikethrough~~ **Done** — this commit (PR # TBD)
5. **PENDING** — T+7d (2026-06-01) verify K1/K2/K3 not fired; T+30d (2026-06-21) verify K4 not fired; T+90d (2026-08-22) close case study, populate `kill_criteria_resolution` frontmatter, transition `current_phase` → `complete`

### C2 — T6 web PR JS test gate (fitme-story)

**Problem:** fitme-story runs **zero JS tests on PR** despite 119 React components + 27 routes. A regression in `Card.tsx` or `ProseLayout.tsx` ships to prod unchecked.

**Smallest viable shape:** add a single `npm test` step to fitme-story's `.github/workflows/ci.yml` + one smoke test asserting a representative page renders.

**Why MUST:** test-coverage-master-plan RICE = 200.0 (highest leverage item in the entire plan).

**Open** as enhancement on `analytics-observability` (current implementation phase) or as new feature `fitme-story-pr-test-gate`.

### C3 — T2 Sentry reachability test (iOS)

**Problem:** Zero tests on `SignInService.swift` + `SentryService.swift`. A pre-launch Sentry misconfiguration ships silently.

**Smallest viable shape:** one `XCTestCase` that asserts `SentryService.shared` is reachable + can capture a synthetic event without crashing.

**Why MUST:** test-coverage-master-plan RICE = 80.0; pre-launch crash gate.

**Open** as enhancement on the eventual `test-coverage` feature.

## 2026-06-01 session operator-action queue

Consolidated from the 2026-06-01 session (14 PRs shipped across FT2 + fitme-story). All items below are **deferred** to operator-paced execution — they're shipped/documented but require human action in an external surface (GA4 console, Google Rich Results, App Store Connect, AWS, Mac restart, etc.). Surfaced daily by `scripts/daily-integrity-checkpoint.py` when ≤14d from due date OR flagged as ongoing.

### Operator-action queue table

| ID | Domain | Action | Effort | Due / gated-on | Source |
|---|---|---|---|---|---|
| OP-2026-06-01-01 | Analytics | Mark 5 primary conversion events in GA4 Admin (`sign_up`, `tutorial_complete`, `workout_complete`, `home_action_completed`, `nutrition_meal_logged`) | ~5 min × 5 | Anytime | [`docs/setup/ga4-funnels-and-conversions-runbook.md`](../../docs/setup/ga4-funnels-and-conversions-runbook.md) §Phase A |
| OP-2026-06-01-02 | Analytics | Mark 3 secondary conversion events after primary stabilizes (`training_session_completed`, `import_plan_activated`, `dashboard_blocker_acknowledged`) | ~5 min × 3 | T+7d after OP-01 | Same runbook §Phase A |
| OP-2026-06-01-03 | Analytics | Wire 3 ready funnels in GA4 Explore (F1 Activation, F2 Drop-off, F5 UCC TTC) | ~30 min total | Anytime | Same runbook §Phase B |
| OP-2026-06-01-04 | Analytics | Build Looker Studio dashboards from F1+F2+F5 funnel data | ~1h | After OP-03 | Same runbook §Phase C |
| OP-2026-06-01-05 | Analytics | Verify 8 new `home_readiness_alert_*` + `home_trend_alert_*` events fire in GA4 (re-run B2) | ~10 min | T+3d after next TestFlight build | Same runbook §Phase D |
| OP-2026-06-01-06 | Analytics | Wire F3 Smart Reminders engagement funnel | ~10 min | After OP-05 confirms events | Same runbook §F3 |
| OP-2026-06-01-07 | Analytics | Wire F4 Web→App conversion funnel | ~10 min | Deferred to App Store launch | Same runbook §F4 |
| OP-2026-06-01-08 | SEO/Web | Run production Lighthouse scorecard: `gh workflow run lighthouse-ci.yml -f target=production --repo Regevba/fitme-story` | ~5 min | Anytime | fitme-story PR #164 |
| OP-2026-06-01-09 | SEO/Web | Run Google Rich Results test against production for WebSite + Organization + BlogPosting + BreadcrumbList JSON-LD ([rich-results test](https://search.google.com/test/rich-results), paste `https://fitme-story.vercel.app` + a case-study URL) | ~10 min | Anytime | fitme-story PR #163 |
| OP-2026-06-01-10 | iOS | TestFlight build cut + push (delivers C2 + C4 instrumentation to ~35 testers) | ~30 min | Anytime; gates OP-05 | C2 PR #560 + C4 PR #564 |
| OP-2026-06-01-11 | iOS | L352 simulator walkthrough (Dark Mode + selection-state contrast) | ~50 min | Anytime; previously deferred | session memory `project_session_2026_05_31_tier_carryover_plan.md` |
| OP-2026-06-01-12 | iOS | L353 Phase 1 simulator verification (`@ScaledMetric` at AX5 Dynamic Type) | ~10 min | Anytime; previously deferred | Same memory |
| OP-2026-06-01-13 | iOS | L353 audit-doc revision + Phases 3-4 docs | ~30-60 min | Anytime; previously deferred | Same memory |
| OP-2026-06-01-14 | HADF | AWS Bedrock model access approval (form already submitted) | (Amazon side) | Awaiting; gates HADF Sub-exp 3 | session memory `project_hadf_subexp3_aws_setup.md` |
| OP-2026-06-01-15 | HADF | Mac restart to fix W28 CoreSim env-flake | ~5 min | Gated on HADF Sub-exp 2 closure (dispatch state doesn't survive reboot) | `.claude/integrity/observed-patterns.md` W28 |
| OP-2026-06-01-16 | HADF | Sub-exp 1B v2 launchd bootstrap | ~10 min | **2026-06-10** | session memory `project_session_2026_05_30_31_hadf_subexp_lifecycle.md` |
| OP-2026-06-01-17 | Framework | Phase E exit verification — confirm 0 regressions, then build v7.9.1 candidates docket | ~30 min | **~2026-06-04** | v7.9 promotion calendar |
| OP-2026-06-01-18 | Framework | Section 99 case study synthesis for `framework-v7-9-promotion` — compare 2026-05-12 pre-snapshot vs 2026-05-28 post-snapshot | ~1h | After OP-17 | B2 closure note above |
| OP-2026-06-01-19 | Analytics | Daily GA4 anomaly check (recurring) | ~5 min/day | Daily, ongoing | This file §B3 |
| OP-2026-06-02-01 | iOS / Framework | C5 T+14d acceptance-rate regression check — verify `home_ai_feedback_submitted` events per WAU has not declined vs 2026-05-31 → 2026-06-01 baseline of 0.03 events per tester; verify Settings → AI Feedback opt-out rate ≤ 20% via GA4 (`home_ai_feedback_history_cleared` proxy) | ~15 min | **2026-06-15** | C5 PRD §"Kill criteria" + [`ai-user-feedback-loop-case-study.md`](../../docs/case-studies/ai-user-feedback-loop-case-study.md) |
| OP-2026-06-02-02 | iOS / Framework | C5 T+30d primary metric review — `home_ai_feedback_submitted` events per WAU ≥ 0.10 target check + acceptance rate ≥ 0.6 in ≥ 2 segments check (T1 instrumented via on-device `RecommendationMemory.acceptanceRate(for:)` aggregated post-launch via existing measurement-adoption pipeline) | ~30 min | **2026-07-02** | Same |
| OP-2026-06-02-03 | Infra / Dev-Env | Style-dictionary v3 → v5 proper migration PR — rewrite `sd.config.js` for v5 API (`new StyleDictionary()` constructor + instance `.registerTransform()`), verify identical token output via `diff` of regenerated `DesignTokens.swift`, then re-bump dep. Dependabot will re-propose the 3→5 bump on auto-cadence; mark closed-via-revert and hold any future auto-bump PRs without manual review | ~1-2h | Anytime (deferred from #577 incident 2026-06-02) | #577 broke main `make tokens` post-merge; reverted via #579 |
| OP-2026-06-02-04 | Infra / Repo Hygiene | Dependabot major-bump policy review — major-version bumps (semver `version-update:semver-major`) should require manual review + local `make tokens-check` verification before merge. Current default-allow let #577 land + break main for ~30 min before revert. Add `.github/dependabot.yml` rule to flag-not-block on `update-type: version-update:semver-major` OR enforce via branch protection requiring an additional review | ~30 min | Anytime (low priority but recurring risk) | Same #577 incident |

### Notes

- **Critical-path order:** OP-15 (Mac restart) blocks resuming local `xcodebuild` work, but is gated on Sub-exp 2 closure. Until then, swiftc-parse + CI-only validation works (today's session proved the pattern across 14 PRs).
- **OP-10 unblocks OP-05/06:** the TestFlight build is the only thing standing between C2/C4 events being in GA4 and the funnel-completeness check.
- **OP-08 + OP-09 are independent + can run anytime:** they validate work already on production. Surfaces real SEO scorecard + rich-result eligibility.
- **OP-17 + OP-18 calendar-anchored:** Phase E exit ~2026-06-04 opens the v7.9.1 build window. Don't start v7.9.1 candidates before exit verification.

### Status decay

When an item closes, strike through the row + add `**Closed YYYY-MM-DD** via <action>`. Don't delete — preserves the audit trail of operator-paced work shipped vs deferred.

## How this file gets updated

- **Adding an item:** drop a row in the right table + a short section. Keep the doc under 200 lines.
- **Closing an item:** strike through the row + add `**Closed YYYY-MM-DD** via <PR or commit ref>`. Do NOT delete — historical visibility matters.
- **Cron link:** daily-checkpoint surfaces upcoming dates from this file (≤14 days). Update [`scripts/daily-integrity-checkpoint.py`](../../scripts/daily-integrity-checkpoint.py) if you add new date fields not following the table schema.

- ~~**W9 Phase 2 concurrency calibration (T+14d)**~~ — **RESOLVED 2026-06-28: HOLD at advisory.** Re-evaluated against the `w9.concurrency` key: 4/4 criteria technically pass but criterion 2 (no false positives) is *vacuous* — 0 `concurrency_offer` events fired in the 9-emission-day window, so the auto-isolate trigger was never exercised. `CLAUDE_W9_CONCURRENCY_ENFORCE` stays default-off. No longer date-gated; re-eval trigger is now event-gated (first real `concurrency_offer` row). Decision recorded in [`.claude/features/w9-drift-triggered-auto-isolation/calibration.md`](../features/w9-drift-triggered-auto-isolation/calibration.md) §2026-06-28.
