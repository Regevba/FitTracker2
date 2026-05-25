# Must-have cadence follow-ups

> Created 2026-05-15 from the prioritization cross-reference of [`docs/master-plan/infra-master-plan-2026-05-12.md`](../../docs/master-plan/infra-master-plan-2026-05-12.md), [`docs/master-plan/data-integrity-and-rollback-2026-05-14.md`](../../docs/master-plan/data-integrity-and-rollback-2026-05-14.md), and [`docs/master-plan/test-coverage-master-plan-2026-05-13.md`](../../docs/master-plan/test-coverage-master-plan-2026-05-13.md).
>
> This file tracks the MUST-HAVE items that are NOT yet wired as code (calendar-anchored verifications + feature-scope coding work). Streams A (data-health/integrity infra) and D (preflight entry points) shipped in the same batch and are NOT listed here.

## Calendar-anchored verifications

Surfaced daily by `scripts/daily-integrity-checkpoint.py` when the target date is ≤14 days away.

| ID | Date | Event | Owner | Source |
|---|---|---|---|---|
| B1 | **2026-05-21** | v7.9 promotion-decision data freeze | operator | infra-plan §4.1, master-plan §2.2 |
| B2 | **2026-05-28** | Post-v7.9 T+7d baseline snapshot | operator | data-integrity §3.2 trigger (2) |
| B3 | **daily, starting now** | GA4 anomaly check (event volume + funnel breaks) | operator + GA4 MCP | analytics-observability epic |
| B4 | **2026-08-13** | Quarterly cross-layer test-discipline audit (initial run) | operator | test-coverage §6.2 |
| B5 | **2026-11-13** | Quarterly cross-layer test-discipline audit (recurring) | operator | test-coverage §6.2 |
| ~~B6~~ | ~~2026-05-22~~ | ~~C1 start — F14/F15 dispatch-test coverage push (deferred from 2026-05-21)~~ **Closed 2026-05-23 via PR #451 (squash `86084c4`); 9/9 dispatch tests + Phase 8 docs landed together.** | operator | followups §C1 |
| ~~B7~~ | ~~2026-05-18~~ | ~~UCC Part 9 — wire `UCC_AUDIT_BLOB_URL` repo variable in FT2~~ **Closed 2026-05-17 via FT2 PR #387** (preemptive wire; Part 9 shipped) | operator | ucc-passkey-auth case study §99 |
| ~~B8~~ | ~~2026-05-23~~ | ~~UCC T+7d kill-criteria checkpoint~~ **EXECUTED 2026-05-23**: K2 `not_fired` [T1 — 0 `counter_replay` events in 3-day Vercel log scan]; K1+K3 `not_yet_observed` [T1 — 0 registrations + 0 sign-ins in cohort window, operator routed via `gh`/CLI not `/control-room/*`]. No fall-back. `UCC_AUTH_MODE=both` remains live. Re-eval at B12 (2026-05-27) or first organic sign-in. Resolution in [`ucc-passkey-auth-case-study.md`](../../docs/case-studies/ucc-passkey-auth-case-study.md) frontmatter + §99 row. | operator | ucc-passkey-auth PRD §6 |
| B9 | **2026-05-28+** | UCC Part 8 — flip `UCC_AUTH_MODE=passkey` + drop `DASHBOARD_USER`/`DASHBOARD_PASS` (irreversible direction) | operator | infra-plan §4.1 + ucc-passkey-auth case study §99 |
| ~~B10~~ | ~~2026-05-21~~ | ~~Audit substrate spec §12 OQ #1 — decide `docs/audits/runs/<date>/bundle.md` commit policy~~ **Closed 2026-05-19: commit per-run artifacts (bundle.md + manifest + redaction-log) for public reproducibility; shipped via PR #405 update** | operator | [`docs/superpowers/specs/2026-05-18-impartial-audit-prompt-substrate-design.md`](../../docs/superpowers/specs/2026-05-18-impartial-audit-prompt-substrate-design.md) §12 OQ #1 |
| B11 | **2026-05-22** | UCC hardening T+3d calibration window check — `auth_lockout_*` counts should be 0, no `email_not_allowlisted` for `regvash21@gmail.com`, sign-in p50 latency Δ ≤+5ms | operator | [`docs/superpowers/specs/2026-05-19-ucc-passkey-security-hardening-design.md`](../../docs/superpowers/specs/2026-05-19-ucc-passkey-security-hardening-design.md) §11 |
| B12 | **2026-05-27** | UCC hardening T+7d kill-criteria evaluation — populate `kill_criteria_resolution` in case study §4 + frontmatter; decide PROMOTE / RECALIBRATE / ROLLBACK | operator | [`docs/case-studies/ucc-passkey-auth-security-hardening-case-study.md`](../../docs/case-studies/ucc-passkey-auth-security-hardening-case-study.md) §4 + §99 |

### B1 — v7.9 promotion-decision data freeze (2026-05-21)

Required actions on the day:

1. `make integrity-check` — must report 0 findings
2. `make integrity-diff` — must report no regression vs 2026-05-14 anchor
3. `make documentation-debt` — must report ≤ baseline open count
4. `make measurement-adoption` — capture for the promotion record
5. `python3 scripts/membrane-status.py` — capture
6. Review last 14 days of `.claude/logs/gate-coverage.jsonl` — verify no `GATE_COVERAGE_ZERO` for any gate that previously fired
7. Decision: flip v7.8.x advisory gates to enforced (specific list in infra-plan §4.1)

### B2 — Post-v7.9 T+7d baseline (2026-05-28)

```bash
make snapshot-phase PHASE=post-v7-9-baseline FEATURE=framework-v7-8-branch-isolation
```

Compare against the 2026-05-14 pre-v7.9 baseline. Document deltas in a meta-analysis case study.

### B3 — Daily GA4 anomaly check

Possible since 2026-05-14 GA4 MCP connection (FIT-142, PR #362). Suggested daily query set:

```
mcp__ga4__getEvents period=last_24h
mcp__ga4__runReport metric=screen_view dimension=date period=last_7d
mcp__ga4__runReport metric=conversions period=last_24h
```

Flag day-over-day deltas > 30% as anomalies. No automation yet — operator runs in a session.

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
| C4 | UCC Part 7 — break-glass registration (YubiKey OR 2nd platform passkey) | ucc-passkey-auth case study §99 | (gates B9) | operator action | before **2026-05-28** |
| C5 | UCC Part 10 — verify framework-health passkey panel renders w/ real audit data | ucc-passkey-auth case study §99 | (depends on B7 + 1 daily sync) | operator action | **2026-05-18** earliest |
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

## How this file gets updated

- **Adding an item:** drop a row in the right table + a short section. Keep the doc under 200 lines.
- **Closing an item:** strike through the row + add `**Closed YYYY-MM-DD** via <PR or commit ref>`. Do NOT delete — historical visibility matters.
- **Cron link:** daily-checkpoint surfaces upcoming dates from this file (≤14 days). Update [`scripts/daily-integrity-checkpoint.py`](../../scripts/daily-integrity-checkpoint.py) if you add new date fields not following the table schema.
