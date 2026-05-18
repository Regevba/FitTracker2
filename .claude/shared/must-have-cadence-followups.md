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
| B6 | **2026-05-22** | C1 start — F14/F15 dispatch-test coverage push (deferred from 2026-05-21) | operator | followups §C1 |
| ~~B7~~ | ~~2026-05-18~~ | ~~UCC Part 9 — wire `UCC_AUDIT_BLOB_URL` repo variable in FT2~~ **Closed 2026-05-17 via FT2 PR #387** (preemptive wire; Part 9 shipped) | operator | ucc-passkey-auth case study §99 |
| B8 | **2026-05-23** | UCC T+7d kill-criteria checkpoint (K1/K2/K3 resolution; replaces `kill_criteria_resolution` frontmatter) | operator | ucc-passkey-auth PRD §6 |
| B9 | **2026-05-28+** | UCC Part 8 — flip `UCC_AUTH_MODE=passkey` + drop `DASHBOARD_USER`/`DASHBOARD_PASS` (irreversible direction) | operator | infra-plan §4.1 + ucc-passkey-auth case study §99 |
| B10 | **2026-05-21 EOD** | Audit substrate spec §12 OQ #1 — decide `docs/audits/runs/<date>/bundle.md` commit policy before External Audit #1 fires on 2026-05-22 | operator | [`docs/superpowers/specs/2026-05-18-impartial-audit-prompt-substrate-design.md`](../../docs/superpowers/specs/2026-05-18-impartial-audit-prompt-substrate-design.md) §12 OQ #1 |

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

### B10 — Audit substrate bundle.md commit policy (2026-05-21 EOD)

Spec [§12 OQ #1](../../docs/superpowers/specs/2026-05-18-impartial-audit-prompt-substrate-design.md): should `docs/audits/runs/<date>/bundle.md` be committed to git, or stay gitignored?

**Default state shipped via PR #405:** gitignored (per `.gitignore`'s `docs/audits/runs/*/` rule). Only the auditor's report + manifest.json + redaction-log.json land in `trust/audits/<date>-<model>/`.

**The question:**
- **Argument for committing bundle.md:** public reproducibility — anyone can replay the audit prompts against the exact bundle the auditor saw.
- **Argument against:** 1.6MB+ bundles bloat the repo (1 per audit × 8 audits × N re-runs over time); the bundle is regenerable from the manifest hash + repo state at that moment via `git checkout <commit>; make audit-bundle PROFILE=<name>`.

**Decision needed by:** 2026-05-21 EOD (before the operator runs the first audit-bundle command on 2026-05-22 for External Audit #1).

**Recommendation:** keep gitignored. Commit the report + manifest + redaction-log to `trust/audits/`; the manifest's `bundle_sha256` + `build_bundle_py_sha256` + commit SHA at audit time are a 3-tuple reproducibility receipt that's tiny and committable.

**If decision flips to "commit bundle.md":** remove the `docs/audits/runs/*/` line from `.gitignore`; expect repo size growth of ~2MB per audit run.

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
| C1 | F14/F15 dispatch-test coverage push | test-coverage-master-plan §2.1 + §4.1 | (gates v7.9 promotion) | feature | **2026-05-22** (deferred 2026-05-15) |
| C2 | T6 — Web PR JS test gate (fitme-story CI) | test-coverage-master-plan T6 | **200.0** | enhancement (on analytics-observability) | 2026-05-21 |
| C3 | T2 — Sentry reachability test (iOS) | test-coverage-master-plan T2 | 80.0 | enhancement (test-coverage) | 2026-05-28 |
| C4 | UCC Part 7 — break-glass registration (YubiKey OR 2nd platform passkey) | ucc-passkey-auth case study §99 | (gates B9) | operator action | before **2026-05-28** |
| C5 | UCC Part 10 — verify framework-health passkey panel renders w/ real audit data | ucc-passkey-auth case study §99 | (depends on B7 + 1 daily sync) | operator action | **2026-05-18** earliest |
| C6 | Bootstrap CLI — add `KV_REST_API_*` fallback in `scripts/issue-bootstrap-token.ts` | ucc-passkey-auth case study §99 quirk 2 | low (operability) | fix (fitme-story) | **2026-05-22** (defer past v7.9 calibration window — `scripts/*` is infra-glob) |
| C7 | Vercel CLI env-add wrapper — REST API helper to bypass headless bug | ucc-passkey-auth case study §99 quirk 1 | low (operability) | chore (fitme-story OR FT2 helper) | **2026-05-22** (`scripts/*` infra-glob defer) |
| C8 | SessionStart preflight — detect stale `.vercel/project.json` pointing to legacy `fit-tracker2` | ucc-passkey-auth case study §99 quirk 4 | low (operability) | chore (FT2 + fitme-story `.claude/settings.json`) | **2026-05-22** (`.claude/shared/*` infra-glob defer) |
| C9 | UCC coral-pulse animation on `/control-room/sign-in` (800ms-after-load nudge) | ucc-passkey-auth ux-spec §6 + ux-pre-merge-review (1 P2) | P2 | enhancement (fitme-story) | when convenient (no calendar gate) |
| C10 | UCC 4 control-room dark-mode contrast verifications — `AuthPasskeyForm` / `DevicesTable` / `AuditEventRow` / `AuditLogPanel` | fitme-story-dark-mode-coverage.md TODOs | P2 | enhancement (fitme-story) | when convenient (no calendar gate) |
| C11 | MEMORY.md staleness check — `scripts/check-memory-staleness.py` + `make memory-check` + `.claude/settings.json` Stop hook (Option C from 2026-05-17 session) | session-end checklist formalization | low (operability) | chore (FT2) | **2026-05-22** (defer past v7.9 calibration — `scripts/*` + `Makefile` infra-glob) |
| C12 | Preflight bug fix — `scripts/preflight.py:264` `enhancement_parent_state()` should read `parent_feature` from current state.json + check THAT parent's prd.md, not the current feature's. Today's UU4 setup hit a false-positive blocker; manual override used. | 2026-05-17 UU4 setup | low (preflight reliability) | fix (FT2) | **2026-05-22** (defer past v7.9 calibration — `scripts/*` infra-glob) |

### C1 — F14/F15 dispatch-test coverage push

**Problem:** Mechanism A coverage telemetry is unreliable for 4 gates with zero dispatch tests + 5 zero-coverage gates. Without dispatch tests asserting each gate function fires, a keying drift (like the `created` vs `created_at` v7.8 incident) can silently zero out coverage.

**Suggested approach:** Each of the 9 gates needs a 5-line unit test in `tests/test_gate_dispatch.py` asserting (a) the gate function is called for matching inputs, (b) `gate-coverage.jsonl` receives a row, (c) the row has expected `gate=` and non-zero `candidates`.

**Why MUST:** v7.9 promotion criterion #1 in master plan §2.2 ("Mechanism A coverage validated for all gates"). Without these tests, v7.9 promotion proceeds with unverified coverage on those 9 gates.

**Deferral note (decision 2026-05-15):** Original target was "before 2026-05-21". Operator decision deferred to **2026-05-22 (the day after v7.9 promotion decision)** to preserve the v7.9 calibration baseline (criterion #2 — "no false positives"). Adding 9 new test fixtures during 2026-05-15→05-21 would write ≥9 new `candidate` rows into `.claude/logs/gate-coverage.jsonl` during the calibration window — contaminating the data the promotion decision evaluates. The trade-off: v7.9 ships on 2026-05-21 WITHOUT F14/F15 coverage validated, then C1 lands 2026-05-22 + the v7.9.1 cycle re-evaluates whether the 9 gates promoted with or without these tests should be re-flipped. The auditor flagged this as the right read because the dispatch tests are themselves the Mechanism A validation work — excluding them from the calibration baseline is correct, not a hack.

**Open `/pm-workflow framework-f14-f15-dispatch-test-coverage`** on 2026-05-22 to start.

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
