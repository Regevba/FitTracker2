# FitMe Infra Master Plan & Roadmap — 2026-05-12

> **Item-tracking convention (FIT-200, est. 2026-06-29):** items here are tracked under the
> [cross-layer naming convention](../process/cross-layer-item-naming-convention.md) — **slug** (canonical) + **`FIT-NNN`**
> (`state.json.linear_id`) + **scheme-prefixed code**: this plan uses `FW-` (framework infrastructure & gates).
> Status vocabulary (all layers): **Backlog → Planned → In Progress → Blocked → Done → Won't-Do**.
> Live per-item status: [`.claude/shared/item-registry.json`](../../.claude/shared/item-registry.json)
> (`make crosswalk`) + the Linear "Fitme project" board. Repo (`state.json.current_phase`) is
> the source of truth; this doc is a planning view. Bare thematic codes (`F4`/`T14`/`R14`) are
> retired in favor of prefixed codes to prevent the cross-scheme collisions reconciled 2026-06-29.

> **Status:** CURRENT · Opened 2026-05-12 (one day after v7.8.3 cross-repo state-sync shipped)
> **Scope:** Framework infrastructure only — write-time gates, cycle-time checks, branch-isolation tooling, cross-repo sync, measurement infrastructure, and the HADF/ORCHID research substrate that depends on it. Product features tracked separately in [`master-plan-2026-04-15.md`](master-plan-2026-04-15.md) + [`master-backlog-roadmap.md`](master-backlog-roadmap.md).
> **Purpose:** Single forward-looking source of truth for framework v7.9 promotion, v8.x candidate ranking, HADF Phase 2-bis pre-launch dependencies, and the measurement / promotion calendar through Q3 2026.
> **Supersedes:** ad-hoc v7.9 candidate lists in [`docs/superpowers/specs/2026-05-07-branch-isolation-out-of-scope.md`](../superpowers/specs/2026-05-07-branch-isolation-out-of-scope.md), [`docs/case-studies/cross-repo-state-sync-impl-case-study.md`](../case-studies/cross-repo-state-sync-impl-case-study.md), and the stress-test case study Section 99 — all are referenced and folded in here.

---

## ⏱️ STATUS UPDATE — 2026-06-15 (v7.10 shipped + doc-review refresh)

> **Supersedes the 2026-06-07 banner below** for current reality. v7.10 SHIPPED 2026-06-10; cross-repo doc-review alignment 2026-06-15. Reconciled v8.0 docket (shipped vs open vs icebox) now lives at **§3.0** below.

**Since the 2026-06-07 banner:**
- **v7.10 SHIPPED 2026-06-10** — GATE_COVERAGE_ZERO observability hardening (#673 + #689: cycle-time Mechanism A coverage for 3 previously-blind checks + 0-candidate mis-wire detector) + measurement-layer field-rename closure (#687 `cu_v2` dual-read, #688 F17 `ts`-key). No new product-facing gates.
- **Theme H test-coverage items shipped 2026-06-10/11:** T3 SignInService passkey/WebAuthn tests (#695) · T5 mock-protocol drift registry (#698) · T10 AI golden-set evals (#691) · T13 per-gate `last_failed_at` index, extends F17 (#694) · T4 Swift snapshot testing Phase A scaffold (#700, in flight) · T14 `platforms_tested` advisory (calibration B15 2026-06-21).
- **Style-Dictionary v3→v5 migration SHIPPED 2026-06-10 (#677)** — closes the v8.x B_medium icebox item "Design-Tokens-Pipeline v5 Migration" (was backlog L417/L435 icebox).
- **Doc-review alignment 2026-06-15** (FT2 #712 + fitme-story #220, both merged) — new canonical [`docs/FRAMEWORK-FACTS.md`](../FRAMEWORK-FACTS.md); living docs + public `versions.json` aligned to v7.10; historical corpus left frozen per chronological-truth rule.

**Canonical current state (reconciled 2026-07-14):** **v7.10 · 131 features · 33 instrumented gates (21 write-time + 9 cycle-time + 2 W9 hooks + 1 standalone; 34 live), 28 firing · 0 integrity findings, 0 real regressions.** Live ref: [`docs/FRAMEWORK-FACTS.md`](../FRAMEWORK-FACTS.md).

**Calibration ladder still pending → v7.10.x / v8.0:** ~~F16 advisory→enforced 2026-06-18~~ ✅ **ENFORCED 2026-06-17** (1d early; `try-repo-harness` → main required checks; K2 0% FP / 60 runs) · ~~PLATFORMS_TESTED (T14) **2026-06-21**~~ ✅ **ENFORCED 2026-06-21** (PR #781, `6ac372b`; 0 false positives / 16 checks, ≥7d coverage) · W9 concurrency **2026-06-28** (reset from 06-20 by the 2026-06-14 session-id-keying fix; `w9.concurrency` key clock restarts at fix-merge +14d) · ~~F4 `FRAMEWORK_VERSION_STALE` advisory→enforced **~2026-06-30**~~ ✅ **ENFORCED 2026-07-08** (#858; 8 emission days / 40 fires / 0 FP) · ~~R9 30-day read → `GATE_TEST_MISSING` **2026-07-04**~~ ✅ **DONE 2026-07-04** (#849) · Data Freshness Audit #1 **2026-08-12** · F14 Phase E → T1 build **2026-08-22**.

---

## ⏱️ STATUS UPDATE — 2026-06-07 (sync refresh)

> This banner is the current-reality overlay; sections below retain their original dated framing for the audit trail. Where a section still says "v7.9.1 opens ~2026-06-04" or "Phase E runs through 2026-06-04," read it through this banner.

**Where we are:**
- **v7.9 Phase E EXITED CLEANLY 2026-06-04** — 0 regressions, 0 rollbacks across the 14-day soak. The 3 promoted gates (`BRANCH_ISOLATION_VIOLATION` Mode B/C + `FEATURE_CLOSURE_COMPLETENESS`) are stable enforced.
- **v7.9.1 build window SHIPPED 2026-06-04** — single day, 8 ships / 14 PRs, **0 new enforcement gates** (Phase E exit discipline). Synthesis case study: `framework-v7-9-1-promotion-case-study.md`.
- **Post-window additions (2026-06-07 session):** t14 `platforms_tested` field + advisory `PLATFORMS_TESTED` gate (#662/#665), `tracking-drift-check` (#659), F-LOCK-INTRODUCING-COMMIT-PERMIT (#660), F-CONTRACT-FIXTURE-SAMPLING FT2 substrate (#664) + fitme-story consumer adoption (fs #209), F-AUTH-LATENCY-SERVER-METRIC (fs #208), F-SNAPSHOT-MANIFEST-LEDGER-ORDERING (operator-local), dev-guide v7.9.1 refresh (fs #211). Enforcement total unchanged: **37 mechanical gates + 5 advisories**.

**Theme G (test discipline) status:** F14 ✅ + F15 ✅ (shipped 2026-05-22/23) · F16 try-repo harness ✅ (shipped v7.9.1; advisory→enforced flip 2026-06-18) · F17 `last_fired_at` index ✅ (shipped v7.9.1) · F2 Phase 0 reality-check ✅ · **GATE_COVERAGE_ZERO** ✅ (shipped #673 + v7.10 #689 — added cycle-time Mechanism A coverage for 3 previously-blind checks + a 0-candidate mis-wire detector) · **T10 AI golden-set evals** ✅ (shipped 2026-06-10 #691 — deterministic InsightService golden set; pulled forward from v8.1 once Phase 2-bis closed) · **F18 mutation testing** + **T1 `GATE_TEST_MISSING` meta-gate** remain open (F18 v8.0, gated on F14+F16 Phase E; T1 gated on F14 Phase E = 2026-08-22).

**Calibration ladder → next promotion window (~v7.10):** three advisory gates converge:
- ~~**2026-06-18** — F16 try-repo advisory→enforced flip~~ ✅ **DONE 2026-06-17** (enforced 1d early; `try-repo-harness` → main required status checks; all §2.2 + K1/K2/K3 met, 0% false-positive rate over 60 CI runs)
- **~2026-06-28** — W9 Phase 2 concurrency-isolation enforce review (feature `w9-drift-triggered-auto-isolation`) — reset from ~06-20: the 2026-06-14 `fix/w9-session-id-keying` invalidated the original window (zero valid Phase-2 telemetry due to the shared-`default` session marker) and restarted the 14-day clock on the new `w9.concurrency` key. HOLD at advisory until then.
- ~~**2026-06-21** — t14 `PLATFORMS_TESTED` advisory→enforced review (cadence B15)~~ ✅ **DONE 2026-06-21** — VERDICT PROMOTE (PR #781, `6ac372b`). All four §2.2 criteria GREEN; `PLATFORMS_TESTED_ADVISORY_MODE = False`. Reversible single-flag.

**Recurring audit calendar (data-gated):** R9 Track B 30-day coverage read **2026-07-04** → feeds `GATE_TEST_MISSING` calibration · Quarterly Data Freshness Audit #1 **2026-08-12** (uses F17 index) · B4 cross-layer test audit **2026-08-13** · F14 Phase E **2026-08-22** → unblocks T1 build · External Audits #2/#3/#4 = **2026-06-12 / 2026-08-05 / 2026-10-08**.

**Open v7.9.1 tails:** F-CONTRACT consumer CI-gate promotion to blocking + shared weekly re-sample cadence (cross-repo); W-MISTRAL-VERCEL-FREE-TIER-BURST (operator API-tier decision). All other docket items closed.

---

## 0. TL;DR

Four streams of work converge on the infra surface as of 2026-05-12 (updated end-of-day after PR #317 + PR #318; refreshed 2026-05-22 post-v7.9 ship):

1. **v7.9 is a *promotion* release, not a feature release. SHIPPED 2026-05-21 via PR #417 (`ea53ff4`).** Single-line flip at [`scripts/check-state-schema.py:132`](../../scripts/check-state-schema.py) (`BRANCH_ISOLATION_ADVISORY_MODE = True → False`) drove 3 promoted gates simultaneously: `BRANCH_ISOLATION_VIOLATION` Mode B + Mode C + `FEATURE_CLOSURE_COMPLETENESS`. All 4 §2.2 promotion criteria GREEN against 14d Mechanism A telemetry (18 + 13 + 13 firings, 0 zero-candidate rows, all skip-reasons legitimate). Phase E validation soak runs **2026-05-21 → 2026-06-04**; B2 post-v7.9 baseline snapshot scheduled **2026-05-28**; v7.9.1 build window opens ~**2026-06-04**. Total framework mechanisms post-promotion: **37 mechanical gates + 5 advisories** (3 advisories promoted). Substantive new build routes through v8.x.
2. **v7.8.5 — pre-promotion remediation patch (NEW, added 2026-05-12).** PR #317 fixed a silent-pass bug (`BRANCH_ISOLATION_VIOLATION` Mode B unreachable when no state.json staged) and the follow-up audit surfaced 4 currently-failing tests in `test_gate_coverage.py` whose `KeyError: 'CACHE_HITS_EMPTY_POST_V6'` may indicate a hidden silent-pass left by the v7.8.3 rename to `CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT`. If true, the v7.8 → v7.9 calibration data feeding the 2026-05-21 decision is keyed wrong. Triage + fix should ship as v7.8.5 BEFORE the promotion decision; otherwise the entire quantitative input stream is corrupted. See §2.4.
3. **v8.x is a *feature* release with 18 F-candidates + 7 V8-I icebox items = 25 total queued.** F1–F18 across four source sessions (roadmap stress-test 2026-05-07, branch-isolation closure 2026-05-07, v7.8.3 cutover dogfood 2026-05-11, PR #317 + test-suite audit 2026-05-12) plus V8-I1–V8-I7 from [`branch-isolation-out-of-scope.md`](../superpowers/specs/2026-05-07-branch-isolation-out-of-scope.md). The 2026-05-12 expansion added **Theme G — Test discipline** (F14–F18) that closes the same vulnerability class PR #317 fixed. Full forward plan v7.9 → v8.2 at §3.6.
4. **HADF Phase 2-bis is the only active infra-adjacent research build right now.** Block A scaffolding SHIPPED 2026-05-12 via PR #316 (13 tasks A0–A12, 15 commits). State.json `current_phase: tasks_phase`. Block B Sub-exp 1 collection calendar-gated 2026-05-23 (T+12d v7.8.3 soak); 3 sub-experiments + cross-synthesis case study run through approximately **2026-06-07**. Track 6 HADF gate activation (currently Q3=OUT of Phase 2-bis scope) becomes eligible post Phase 2-bis closure ~2026-06-07.

**Calibration protocol added 2026-05-12 (§3.5):** every new layer of framework infrastructure now requires a documented pre-build calibration window where telemetry from the prior layer proves it fires correctly under load. This codifies the "advisory → enforced after measurement" pattern that v7.8 introduced informally.

**Phase E Day-5 status (2026-05-26):** 7 PRs merged across both repos (FT2 #494/#495/#496/#497/#499/#500 + fitme-story #150) — **no new gates ship in Phase E**; today's batch is hygiene + reconciliation + B12 prep. Three drifted-feature closures (`ucc-passkey-auth-audit-log-redis-fix` complete; `ucc-sign-in-figma-mapping` complete with 3 Figma-seat-blocked tasks deferred; `ucc-passkey-auth-security-hardening` 24/26 task statuses reconciled — full closure awaits B12 evaluation 2026-05-27). B12 spec hardened against 3 query template bugs found via dry-run (PR #499); predicted verdict tomorrow: PROMOTE. Signing infrastructure repaired (3 silent bugs in `sign-yk`/`sign-tid` aliases + wrapper). UI/UX Tier A bundle closed AND-3 decision + VoiceOver audit doc + ui-audit P1 reconcile (live scanner P0=0 + P1=0; plan claim was stale). `make integrity-check` baseline maintained at session end: **0 findings + 3 advisory** (no regression). Phase E remains GREEN. Detail in backlog row 116; Linear FIT-192 + FIT-66 + FIT-132 + FIT-165 commented.

---

## 1. v7.8.3 Anchor — What's Already Shipped

The v7.8.3 cross-repo state-sync umbrella shipped 2026-05-11 across 10 PRs in a single-day subagent-driven build. The infra surface at end-of-day was:

- **33 mechanical gates** (write-time + cycle-time, was 30 at v7.8.1)
- **5 advisory gates** (cycle-time only; advisory pending data accumulation)
- **62 features** with `state_owner ∈ {ft2, fitme-story}` backfilled
- **47 features** with full v7.8 schema bridge fields populated
- **1 reverse-sync GitHub Action** live in fitme-story (D-1)
- **1 unified PR-cite cache** (`scripts/refresh-pr-cache.py` + multi-repo `_load_pr_cache`) — 63/63 retroactive citation validation pass
- **1 cross-repo telemetry aggregator** (`src/lib/control-room/gate-coverage-aggregator.ts` in fitme-story) for `gate-coverage.jsonl` from both repos
- **1 phase-snapshot protocol** (`make snapshot-phase` → `scripts/snapshot-phase-completion.sh`) for off-SSD per-phase backups

Detailed inventory of what shipped + how the 3-attempt cutover ceremony surfaced F11/F12/F13: [`docs/case-studies/cross-repo-state-sync-impl-case-study.md`](../case-studies/cross-repo-state-sync-impl-case-study.md).

### 1.1 v7.8.4 + PR #317 + PR #318 (2026-05-12 additions)

**v7.8.4** shipped 2026-05-12 morning via PR #314 + PR #297 + companion doc-sync. Adds the `PR_CACHE_STALE` auto-refresh gate (closes the 33-finding false-positive incident from empty PR cache) + narrows `TIER_TAG_LIKELY_INCORRECT` heuristic + introduces `.claude/shared/case-study-t1-references.json` reference ledger. Single operability gate added (`PR_CACHE_STALE`); total mechanical gates 33 → 34.

**PR #317** (`fix(framework): BRANCH_ISOLATION_VIOLATION Mode B silent-pass on infra-only commits`) shipped 2026-05-12 afternoon. Reordered `scripts/check-state-schema.py:main()` so the Mode B check + gate-coverage ledger write happen BEFORE the no-state-files early-return. Added 2 regression tests that drive `main()` end-to-end. No new mechanism; closes a 5+ day silent-pass window that affected ~9 HADF Phase 2-bis Block A commits.

**PR #318** (`docs(v7-9-candidates):` F14–F18 from PR #317 + test-suite audit + external research) shipped 2026-05-12 evening. Expanded the v7.9 candidates spec from 13 to 18 items (Theme G — Test discipline). Documented pre-promotion remediation flag for cache_hits keying.

**Inventory delta:** 33 → 34 mechanical gates; 5 advisory unchanged; F-candidate count 13 → 18.

### 1.2 v7.8.5 + v7.8.6 (2026-05-13 → 2026-05-15 additions)

**v7.8.5** shipped 2026-05-13 — observability layer with no new gates. Adds the Observed Patterns Catalog ([`.claude/integrity/observed-patterns.md`](../../.claude/integrity/observed-patterns.md), 23 gate patterns + 9 workflow patterns) and the W9 branch-drift real-time alert (PostToolUse:Bash hook). Mandatory operator rule: any novel pattern surfaced during a session must be appended to the catalog before the protocol closes the feature. Shipped via PR #328 (catalog) + PR #341 (W9 hook).

**v7.8.6** shipped 2026-05-15 — **cadence batch closing the 96-hour drift window** identified in `docs/master-plan/data-integrity-and-rollback-2026-05-14.md` §2.1+§2.3. Pure observability surfaces (no enforcement-gate changes). Two PRs:

- **PR #363 (MUST batch):** `make integrity-diff` vs 2026-05-14 anchor + `make preflight WORK_TYPE=<type>` unified entry point + W1 ssh-agent SessionStart preflight + weekly Mechanism A gate-coverage zero-drift scan + per-dimension trend nudge in `framework-status-weekly.yml`. Mandatory Phase 0.0 step added to `/pm-workflow`. All 10 skills point at `.claude/shared/preflight-cache.json` in their `## Shared Data` section. New ledger: `.claude/shared/gate-coverage-weekly.jsonl` (append-only, populated on first weekly cron). Cadence-followups tracker at `.claude/shared/must-have-cadence-followups.md` with daily ≤14d lookahead.
- **PR #365 (nice-to-have batch):** `.github/workflows/dependency-audit-weekly.yml` + `scripts/aggregate-dependency-audit.py` (Mondays 06:00 UTC, 1h after framework-status-weekly). Daily-checkpoint extension: stale-branch warning (`[gone]` local branches + orphan worktrees) + PR-babysit sweep (open PRs idle >24h, cross-repo).

**Inventory delta:** 34 mechanical gates unchanged; 5 advisory unchanged. New observability surfaces: 2 Makefile targets (`integrity-diff`, `preflight`), 1 new cache ledger (`preflight-cache.json` — gitignored, per-session), 1 new append-only ledger (`gate-coverage-weekly.jsonl`), 2 new GH Actions workflows (extension of `framework-status-weekly` + new `dependency-audit-weekly`), 3 new SessionStart / daily-checkpoint output sections (W1 ssh-agent, stale-branch, PR babysit).

**Why ship against the plan now:** master plan §2.2 promotion criterion #2 ("no false positives") + criterion #1 ("Mechanism A coverage validated") are measured against the 2026-05-14 baseline. v7.8.6 makes drift-vs-baseline a single command — operators can verify the 2026-05-21 promotion decision against fresh telemetry without manual ledger-diffing.

### 1.3 UCC passkey cutover (2026-05-16 additions)

`ucc-passkey-auth` cutover Parts 1-6 executed 2026-05-16 (feature shipped 2026-05-07, dormant at `UCC_AUTH_MODE=basic` for 9 days). The `fitme-story.vercel.app/control-room/*` operator dashboard now runs at `UCC_AUTH_MODE=both` — passkey AND legacy basic-auth both accepted; rollback is a single env-var flip. Touches no framework-gate code; no Mechanism A telemetry contamination during 2026-05-15 → 05-21 calibration window. 9 cadence-followups added to [`must-have-cadence-followups.md`](../../.claude/shared/must-have-cadence-followups.md): B7 (Part 9 audit-log GHA, 2026-05-17), B8 (T+7d kill-criteria checkpoint 2026-05-23), B9 (Part 8 passkey-only flip 2026-05-28+), C4-C8 (Part 7 break-glass + Part 10 panel verify + 3 operability fixes deferred past v7.9), C9-C10 (P2 UX polish — coral pulse animation + 4 control-room dark-mode contrast verifications). Source case study §99: [`docs/case-studies/ucc-passkey-auth-case-study.md`](../case-studies/ucc-passkey-auth-case-study.md).

**Inventory delta:** 0 mechanical gates changed; 0 advisory changed; 0 new telemetry candidates. Pure operational rollout.

---

## 2. Promotion Docket (v7.9 → enforced, decision 2026-05-21)

These items already exist as advisory gates. The v7.9 decision is *whether to flip them to enforced* — not whether to build them. Each flip is data-gated on `gate-coverage.jsonl` telemetry showing the gate fires correctly under load with zero false positives.

### 2.1 Advisory → Enforced Calendar

| Gate | Advisory ship | Telemetry window | Earliest enforce | Source |
|---|---|---|---|---|
| `BRANCH_ISOLATION_VIOLATION` (Modes B + C) | v7.8.1 (2026-05-07) | 2026-05-07 → 2026-05-21 (14d) | **2026-05-21** | [v7.8.1 spec](../superpowers/specs/2026-05-02-framework-v7-8-and-v7-9-bridge-design.md) |
| `FEATURE_CLOSURE_COMPLETENESS` | v7.8.1 (2026-05-07) | 2026-05-07 → 2026-05-21 (14d) | **2026-05-21** | [v7.8.1 spec](../superpowers/specs/2026-05-02-framework-v7-8-and-v7-9-bridge-design.md) |
| Mechanism A coverage gates | v7.8 (2026-05-04) | 2026-05-04 → 2026-05-11 (7d) | **already met** (calibration data sufficient) | [v7.8 bridge case study](../case-studies/framework-v7-8-bridge-case-study.md) |
| Mechanism C session-attribution gate | v7.8 (2026-05-04) | 2026-05-04 → 2026-05-11 (7d) | **already met** | [v7.8 bridge case study](../case-studies/framework-v7-8-bridge-case-study.md) |
| `CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT` (V2) | v7.8 (2026-05-04) | shipped enforced 2026-05-11 | **already enforced** (v7.8.3 Phase 0, PR [#298](https://github.com/Regevba/FitTracker2/pull/298)) | v7.8.3 Phase 0 |
| Mechanism E custom merge driver (V9) | v7.8 (2026-05-04) | extended to feature logs 2026-05-11 | **already enforced** (v7.8.3 Phase 0) | v7.8.3 Phase 0 |
| `BRANCH_ISOLATION_HISTORICAL` cycle-time | v7.8.1 (2026-05-07) | indefinite (advisory by design) | **stays advisory** | T17 forward-only audit |
| `BRANCH_ISOLATION_LAUNCHD_DRIFT` cycle-time | v7.8.1 (2026-05-07) | indefinite (advisory by design) | **stays advisory** | T18 macOS-only |
| `FEATURE_CLOSURE_COMPLETENESS` cycle-time mirror | v7.8.1 (2026-05-07) | indefinite (catches `--no-verify`) | **stays advisory** | T19 bypass-catcher |

### 2.2 Promotion Decision Criteria

The 2026-05-21 decision gate requires all four to be true for each candidate gate:

1. **Coverage emitted** — `gate-coverage.jsonl` shows ≥7 days of `{candidates, checked, skipped}` rows
2. **No false positives** — every `failure` row has a matching legitimate violation in the staged diff (operator review)
3. **No silent skips** — `skipped` count tracks real reasons (out-of-scope file paths, exempt feature tags), not bugs
4. **Reversibility** — if the flip causes regression, advisory mode can be restored in <5 min via single-line CLAUDE.md edit + hook header bump

If any criterion fails for a given gate, that gate stays advisory and re-evaluates at v7.10 (next promotion window, target ~2026-06-04, T+14d post-v7.9).

### 2.3 Side-effects of v7.9 promotion

- **CLAUDE.md** — Known Mechanical Limits section gains 2 enforced gate IDs + drops 2 from the "advisory" bullet list
- **Cold-start entrypoint** — new file `.claude/entrypoints/framework-v7-9.md` mirrors `framework-v7-8-3.md` with the flipped status
- **Dev-guide** — [`docs/architecture/dev-guide-v1-to-v7-7.md`](../architecture/dev-guide-v1-to-v7-7.md) §2.4 v7.8 bridge section gains "promoted" sub-section
- **Honesty ledger** — new entry FT2-FH-002 documenting the decision rationale + any deferrals
- **Linear** — new epic FIT-72 (or next) `v7.9-promotion`, sub-issues per flipped gate

### 2.4 v7.8.5 Pre-Promotion Remediation Patch (NEW, added 2026-05-12)

**Trigger:** PR #317 root-cause analysis surfaced 4 currently-failing tests in `test_gate_coverage.py::test_cache_hits_gate_records_*` all raising `KeyError: 'CACHE_HITS_EMPTY_POST_V6'`. CLAUDE.md says v7.8.3 promoted this gate to `CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT`. The tests' KeyError on the **old** name on origin/main suggests one of three possibilities:

1. **Rename incomplete** — the gate function was renamed but the coverage-instrumentation key (passed to `coverage.candidate(GATE)`) wasn't updated in lockstep. **Symptom:** Mechanism A emissions land under the wrong key (or under no key), corrupting the 2026-05-21 calibration data input.
2. **Test fixture rot only** — tests reference a constant that was deleted; gate emissions are fine. Symptom: tests fail but production telemetry is correct.
3. **Coverage instrumentation deleted entirely** — the rename was a hard cut; `CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT` records no Mechanism A telemetry at all. Symptom: gate-coverage.jsonl has zero entries for the gate; the 2026-05-21 decision has no quantitative input for this specific candidate.

**Why this MUST ship before 2026-05-21:** the entire promotion decision rests on `gate-coverage.jsonl` showing the gate fires correctly. If the gate's Mechanism A key is wrong, the data is keyed wrong, and the criterion #1 ("Coverage emitted") cannot be evaluated honestly. This is a meta-instance of the silent-pass class PR #317 fixed.

**Triage plan (v7.8.5, single PR, ~2 hours):**

1. **Read** `scripts/check-state-schema.py` for `check_cache_hits_*` function names + `coverage.candidate(...)` keys passed in.
2. **Read** `test_gate_coverage.py::test_cache_hits_gate_records_*` for what keys the tests expect.
3. **Read** `.claude/logs/gate-coverage.jsonl` (last 7 days) — count entries by gate name. If `CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT` has zero entries, the rename was incomplete.
4. **Fix** the keying so emission ↔ test ↔ documentation all agree.
5. **Backfill** if telemetry was missed — re-run `make integrity-check` to populate the ledger with current state's coverage data so the 7-day window before 2026-05-21 starts clean.
6. **Add** a regression test that asserts the gate emits to `gate-coverage.jsonl` under the canonical key (Mechanism A check), preventing future rename-drift.

**Target ship:** 2026-05-13 → 2026-05-14 (T+7d remaining before 2026-05-21 = full window for the decision).

**Cross-references:** [`scripts/check-state-schema.py`](../../scripts/check-state-schema.py); [`scripts/tests/test_gate_coverage.py`](../../scripts/tests/test_gate_coverage.py); [PR #318](https://github.com/Regevba/FitTracker2/pull/318) §"Pre-promotion remediation"; [v7.9 candidates spec](../superpowers/specs/2026-05-08-framework-v7-9-candidates.md) F18 pre-promotion remediation callout.

---

## 3. Build Docket (v8.x — 18 F-candidates + 7 V8-I icebox = 25 items)

### 3.0 v8.x Docket — Reconciled Status (2026-06-26)

> **This is the live docket.** The dated Source A–E tables in §3.1 + the icebox in §3.2 retain their original framing for the audit trail; read statuses through this table. No separate `2026-05-21-v8-0-docket.md` spec was ever produced (the §3.3 T29 plan) — **this section IS the docket**, cross-referenced to merged PRs + memory.

**A. Shipped since the docket opened — no longer v8.0 candidates:**

| ID | Item | Shipped | PR(s) |
|---|---|---|---|
| F2 | Phase 0 reality-check sub-step | v7.9.1 | #618 |
| F6 | B_medium tier documented in CLAUDE.md | done | CLAUDE.md "Impact tier labels" § + "Work Item Types" |
| F9 | `make close-feature` closure automation | shipped | #591 + #711 (sub-phase normalize) |
| F14 | Per-gate dispatch tests | 2026-05-22/23 | #451 / #452 / #455 |
| F15 | Zero-coverage gate unit tests | 2026-05-22/23 | (same feature) |
| F16 | try-repo harness | v7.9.1 | #607–#612 · **advisory→enforced 2026-06-18** |
| F17 | `last_fired_at` index (+ T13 `last_failed_at`) | v7.9.1 / v7.10 | #617 / #694 |
| — | GATE_COVERAGE_ZERO meta-check | v7.10 | #673 + #689 |
| T3 | SignInService passkey/WebAuthn tests | v7.10 | #695 |
| T5 | mock-protocol drift registry | v7.10 | #698 |
| T10 | AI golden-set evals | v7.10 | #691 |
| T14 | `platforms_tested` field + advisory gate | 2026-06-07 | #662 · calibration B15 2026-06-21 |
| V8-I | Style-Dictionary v3→v5 migration | 2026-06-10 | #677 (was icebox L417/L435) |
| F-DEPLOYED-URL-PROBE | FT2 substrate (`scripts/probe-deployed-url.sh`) | v7.9.1 | fitme-story integration still open |
| F-CONTRACT-FIXTURE-SAMPLING | FT2 substrate + producer sampling | 2026-06-07 | #664 · consumer adoption still open |
| F-LAUNCHD-DRIFT-EXTENSION | all 3 sub-fixes | v7.9.1 | #621–#624 |
| F12 | `actionlint` lint gate (warn-only; strict mode is a future calibration step) | 2026-06-15 | #719 |
| F11 | `BRANCH_ISOLATION_HISTORICAL` reverse-sync allowlist | 2026-06-15 | #722 |
| F10 | `experiment_outcome` enum on `tasks[]` | 2026-06-15 | #720 (`v8-f10-f5-schema-vocab`) |
| F5 | `scope_change` Tier 2.2 vocabulary event | 2026-06-15 | #720 (`v8-f10-f5-schema-vocab`) |
| F4 | Auto-update `framework_version` (`FRAMEWORK_VERSION_STALE`) | 2026-06-16 | #740 · **advisory→enforced review ~2026-06-30** |
| F1 | `STATE_TASKS_FILESYSTEM_DRIFT` advisory (permanent) | 2026-06-17 | #752 |
| F3 | Phase 2 dependency-graph cycle check (advisory-permanent) | 2026-06-17 | #753 |
| F13 | `source_commit` `workflow_dispatch` input (reverse-sync workflow) | 2026-06-15 | fitme-story #221 (`reverse-sync-fitme-story-to-ft2.yml`) |
| F-CONTRACT (consumer) | fitme-story consumer adoption + sampling | 2026-06-22 | #790 |
| F22 | Funnel Analysis Dashboards (live GA4, 3/5 funnels wired) | 2026-06-24 | #799 |
| F18 | Mutation testing on dispatcher files (warn-only weekly CI; mutmut, 1,857-mutant baseline) | 2026-06-26 | #809 (`f18-mutation-testing`) |

**B. Open — carried into the v8.0 build (kickoff target ~2026-06-18, after F16 enforce flip ✅ 2026-06-17):**

> Reconciled 2026-06-26: 11 of the 16 prior rows (F1/F3/F4/F5/F10/F11/F12/F13/F18/F22/F-CONTRACT-consumer) **shipped** and moved to table A. The rows below are the genuinely-remaining items.

| ID | Item | Class | RICE-est | Gating |
|---|---|---|---|---|
| T1 | `GATE_TEST_MISSING` meta-gate | Test discipline | 53.3 | F14 Phase E **2026-08-22** (F18 mutation survivor data feeds calibration) |
| F19/F20 | Analytics Phase 1.B GA4 conversions + gates (`CSV_TAXONOMY_DRIFT`, `GA4_MCP_DISCONNECTED`) | Telemetry/gates | M / L | D-2 operator (GA4 Key-event toggle, register A1) + post-launch signal |
| F23 | `/ops digest` skill | Skill extension | M | F22 ✓ + Sentry resume (launch-gated, §C) |
| T4 | Swift snapshot testing | iOS test infra | — | Phase A scaffold shipped (#700); build pending (in flight) |

**C. Paused / launch-gated:** F21 Sentry (pre-launch trigger; PR #418) · F-AUTH-LATENCY-SERVER-METRIC shipped FT2-side (fitme-story #208).

**D. Icebox (V8-I — re-eval on trigger, see §3.2):** 6 remaining branch-isolation-out-of-scope items — Agent Smartlog UI, Op-log Replay, Vercel Sandbox, Landlock/App-Sandbox, Path-Watcher Daemon, Cross-Feature Dependency Graph, Auto-Rollback. (Style-Dictionary v5, formerly the 7th, now SHIPPED — see table A.)

**E. Operator decision open:** W-MISTRAL-VERCEL-FREE-TIER-BURST (API-tier choice for multi-provider HADF experiments).

**Roll-up (reconciled 2026-06-26, post-F18):** of the original 18 F-candidates, **17 shipped** (F1, F2, F3, F4, F5, F6, F9, F10, F11, F12, F13, F14, F15, F16, F17, F18, F22 + the GATE_COVERAGE_ZERO meta-check) + 2 resolved-by-exemption (F7, F8) → **all ready-now F-items shipped; remaining open: F19/F20** (operator-gated on GA4 Key-event toggle, register item A1), **F23** (gated on Sentry resume, §C). **F21** Sentry is paused/launch-gated (§C). Theme H (test-coverage T1–T16): T3/T5/T10/T13/T14 shipped, T4 in flight, T1 gated to 2026-08-22 (now fed by F18 mutation-survivor data). **v8.0 build kickoff target ~2026-06-18 met** (F16 enforce flip ✅ 2026-06-17); ship target 2026-07-31.

---

### 3.1–3.4 v8.x Candidate Docket → extracted to dedicated sub-plan (2026-06-15)

> **The full v8.x candidate docket — F-series tables (Sources A–E), V8-I icebox, the T29 decision process, and the theme distribution — now lives in its own sub-plan: → [`v8-x-build-docket-2026-06-15.md`](v8-x-build-docket-2026-06-15.md)**
>
> This was separated 2026-06-15 to mirror how `test-coverage-master-plan`, `data-integrity-and-rollback`, and `analytics-master-plan` are standalone sub-plans under this parent. The **§3.0 reconciled roll-up above remains the at-a-glance**; the sub-plan is authoritative for per-candidate detail. The frozen T29 ranking stays at [`v8-0-docket-ranking-2026-05-13.md`](v8-0-docket-ranking-2026-05-13.md); the ready-now execution sequence is at [`v8-0-ready-now-workplan-2026-06-15.md`](v8-0-ready-now-workplan-2026-06-15.md).
>
> **§3.5 (Calibration Protocol for new layers) and §3.6 (Forward Plan v7.9 → v8.2) remain below in this parent** — they are general process/timeline content referenced by name across the doc tree, not part of the candidate docket.

---

## 3.5 Calibration Protocol for New Layers (NEW, added 2026-05-12)

The PR #317 incident + the cache_hits keying-drift suspicion (§2.4) both share the same root: **a new layer of framework infrastructure was added on top of an unmeasured prior layer.** Going forward, every new infrastructure layer must walk a 5-phase calibration protocol before becoming load-bearing.

### 3.5.1 The 5 Phases

```
Phase A — Specify         (before code is written)
Phase B — Ship advisory + measure   (T+0 → T+7d)
Phase C — Calibration gate          (T+7d → T+14d)
Phase D — Promotion decision        (T+14d)
Phase E — Post-promotion validation (T+14d → T+21d)
```

| Phase | Duration | Required artifacts | Exit criteria |
|---|---|---|---|
| **A — Specify** | Pre-code | Gate spec (`function_name`, `emission_key`, dispatch site, expected skip reasons), 1 positive fixture, 1 negative fixture, regression test that asserts "this gate's `coverage.candidate(GATE)` fires when invoked under the expected input partition" | Spec + fixture + dispatch test ALL exist before any production code lands |
| **B — Ship advisory + measure** | 7 days minimum | Gate emits to `gate-coverage.jsonl` with `{candidates, checked, skipped, skip_reasons}`; PR ships with advisory-only mode (logs, doesn't block); operator checks Mechanism A at T+3d for unexpected skip_reasons | ≥7 days elapsed AND ≥1 real-world fire OR ≥3 documented legitimate skips |
| **C — Calibration gate** | 7 days | Quantitative: ≥N gate fires (N specified per gate, default N=5 for advisory→enforced; N=10 for novel mechanisms). Zero false positives confirmed by operator review of every `failure` row. All `skipped` rows match documented expected reasons. | All quantitative checks pass AND qualitative dogfood test runs cleanly |
| **D — Promotion decision** | 1 day | Decision recorded in case study + honesty ledger + CLAUDE.md update. Reversibility path tested (single-commit rollback rehearsed). | Either: flipped to enforced AND telemetry continues OR stays advisory AND re-evaluates at next T+14d cycle |
| **E — Post-promotion validation** | 7 days | Continuous telemetry monitoring; watch for false-positive incidents; trend analysis on fire frequency vs advisory baseline | 0 false-positive incidents in 7d → layer is "stable" and may have new layers built on top |

**Total minimum time per layer: 22 days** (Phase B 7d + Phase C 7d + Phase D 1d + Phase E 7d), with Phase A done up-front.

### 3.5.2 Layer Stacking Rule

**No new layer of framework infrastructure may be BUILT on top of a layer that hasn't reached Phase E.** This is the rule that codifies the PR #317 lesson — `BRANCH_ISOLATION_VIOLATION` Mode B was built (advisory) but never reached its own post-promotion validation; meanwhile we were already planning F11/F12/F13 on top of it.

Concrete application to F14–F18 (Theme G test discipline):

- F16 (try-repo harness) is foundation. It cannot ship until v7.9 promotion (~2026-05-21) clears Phase E (~2026-06-04 if successful).
- ~~F14 (per-gate dispatch tests) requires F16 in Phase E (so the harness exists). Earliest start: ~2026-06-04.~~ **CONSTRAINT RELAXED 2026-05-22:** F14 shipped without F16 by using the in-repo monkey-patch pattern proven in PR #317 (`monkeypatch.setattr(module, 'main', wrapped_main)` to invoke gates end-to-end without spawning a sub-repo). 9 dispatch tests across 4 surface files, 161/161 pytest pass, 0 contamination of canonical telemetry. F16 remains a v7.9.1+ candidate for the BROADER integration-test surface (full pre-commit pipeline including hook composition + git interaction), but it's no longer a blocker for per-gate dispatch coverage.
- F18 (mutation testing) requires F16 in Phase E AND F14 in Phase B (so there are tests to mutate). F14 is now in Phase E (shipped 2026-05-23), so F18 earliest-start drops to F16 ship + Phase E. ~~Earliest start: ~2026-06-11.~~ Now: ~~2026-06-11.~~ **Recomputed: F16 ship + 7d Phase E**; tentatively ~late June 2026.
- ~~F15 (zero-coverage gate unit tests) is independent — can start any time but should still walk Phases B–E.~~ **F15 SHIPPED 2026-05-22 → 05-23** as joint scope with F14 (both bundled into `framework-f14-f15-dispatch-test-coverage` feature). All 5 zero-coverage gates (PHASE_TRANSITION_NO_LOG, PHASE_TRANSITION_NO_TIMING, BRANCH_ISOLATION_HISTORICAL, BRANCH_ISOLATION_LAUNCHD_DRIFT, PR_CACHE_STALE) now have ≥1 dispatch test.
- F17 (last_fired_at index) is independent — can start any time; minimal calibration needed since it's a read-only derived artifact.

### 3.5.3 Data Freshness Audit (quarterly)

Every 90 days, run an audit that asserts:

1. Each gate's `coverage.candidate(GATE)` emission key matches the gate's canonical function name (CLAUDE.md gate inventory).
2. Each gate has emitted ≥1 candidate to `gate-coverage.jsonl` in the last 30 days (using F17's `last_fired_at` index for O(1) lookup).
3. Each gate's `last_fired_at` is fresher than its introduction-date + advisory-window (else: silent-pass suspect).
4. Tests in `scripts/tests/` reference current canonical names (no `KeyError` on a renamed gate).

This audit is the meta-check that would have caught the cache_hits keying drift the moment it landed instead of weeks later via test failure. Initial run: 2026-08-12 (T+90d). Recurring: 2026-11-12, 2027-02-12, etc.

### 3.5.4 Reversibility Contract

Every gate must ship with a documented reversibility path:

- **Advisory rollback** — single-line edit to gate function returning early; no hook-header changes; rollback time <2 min.
- **Enforced rollback** — single-line edit to flip enforcement boolean OR hook-header bump from "enforced" to "advisory"; rollback time <5 min.
- **Mechanism rollback** — full mechanism (e.g., A, C, E) rollback requires reverting the original PR + a `chore/rollback-mechanism-<X>` PR; rollback time <30 min.

Rollback is rehearsed at Phase D (promotion decision) for every gate. Un-rehearsed rollback paths fail Phase D.

---

## 3.6 Forward Plan: v7.9 → v8.2 (NEW, added 2026-05-12)

Mapping all 23 open candidates to version slots. Each version has explicit calibration checkpoints from §3.5.

### 3.6.1 v7.8.5 — Pre-Promotion Remediation (target 2026-05-13 → 2026-05-14)

**Scope:** cache_hits keying drift investigation + fix (§2.4). Single PR. ~2 hours wall.

**Phase A artifacts** (must exist before fix is merged):
- Regression test asserting `CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT` emits to `gate-coverage.jsonl` under the canonical key on the next invocation
- Backfill of last 7 days of synthetic gate-coverage entries if the rename left a coverage hole (so the 2026-05-21 calibration window starts clean)

**Phases B–E:** N/A for this patch (no advisory window — it's a fix to an existing enforced gate, not a new layer).

**Why it ships at 7.8.5 not 7.9.0:** v7.9 is a *promotion* release, not a feature release. This is a fix that should ship under the patch-level cadence.

### 3.6.1.A v7.8.5 Observability Layer (SHIPPED 2026-05-13)

**Scope:** ship the **operator-facing observability layer** that closes a recurring debugging-friction gap. No new write-time or cycle-time gates; no telemetry impact on v7.9 calibration data.

**Two deliverables:**

1. **Observed Patterns Catalog** at [`.claude/integrity/observed-patterns.md`](../../.claude/integrity/observed-patterns.md) — 23 gate-firing patterns (write-time + cycle-time) + 9 workflow patterns (W1–W9) documented with trigger / why-expected / signal-vs-noise rule / silence path / first-observed. CLI: `make observed-patterns`. Auto-loaded as preflight by `/pm-workflow`. **Mandatory rule:** any novel pattern surfaced during a session MUST be appended before the protocol closes the feature. Shipped via [PR #328](https://github.com/Regevba/FitTracker2/pull/328).

2. **W9 branch-drift real-time alert** at [`scripts/check-branch-drift.py`](../../scripts/check-branch-drift.py) — `PostToolUse:Bash` hook that records the current branch per session and emits a LOUD stderr warning on unexpected branch change (typically caused by another concurrent Claude session sharing the same git working directory running `git checkout`, flipping HEAD). Warning surfaced back to the assistant via tool output for real-time operator alerting. Includes a 4-step recovery playbook in the catalog. Disable: `CLAUDE_W9_DISABLE_DRIFT_CHECK=1`. Shipped via [PR #341](https://github.com/Regevba/FitTracker2/pull/341).

**Why it ships at 7.8.5 not 7.9.0:** observability/documentation surfaces don't carry the framework-version semantics of gate additions. Patches don't affect the 22-day Calibration Protocol clock.

**v7.8.5 final mechanism inventory:** 33 mechanical gates + 5 advisories + **2 observability surfaces** (catalog + W9 hook). Effective `make integrity-check` baseline unchanged (0 findings + 4 expected advisories per pattern catalog).

### 3.6.2 v7.9 — Promotion Release (SHIPPED 2026-05-21 via PR #417 `ea53ff4`)

**Outcome (B1 freeze-day execution, 2026-05-21):** all 4 §2.2 promotion criteria met for all 3 candidate gates. Single-line flip at [`scripts/check-state-schema.py:132`](../../scripts/check-state-schema.py) (`BRANCH_ISOLATION_ADVISORY_MODE = True → False`) drives all 3 gates simultaneously. **3 gates promoted, 0 rollbacks.**

| Gate | 14d telemetry (2026-05-07 → 2026-05-21) | candidates=0 | Verdict |
|---|---|---|---|
| `BRANCH_ISOLATION_VIOLATION` Mode B (infra commit-level) | 18 rows | 0 | PROMOTED |
| `BRANCH_ISOLATION_VIOLATION` Mode C (per-state.json mutation) | 13 rows | 0 | PROMOTED |
| `FEATURE_CLOSURE_COMPLETENESS` (write-time) | 13 rows | 0 | PROMOTED |
| `ISOLATION_OPT_OUT_REASON_MISSING` | 13 rows | 0 | (already enforced at v7.8.1 — no action) |

**First real-world gate fire confirmed same-session:** the v7.9 post-merge close-out commit triggered Mode C on first attempt (state.json declared `feature/v7-9-promotion` while operator was on `chore/v7-9-promotion-close-out`). Resolved via 1-line `branch` field update. Live demonstration that enforcement works. Captured in [FT2-FH-003 honesty ledger entry](../case-studies/framework-honesty-ledger.md#ft2-fh-003).

**Side-effects shipped same-PR (per §2.3):** CLAUDE.md "v7.9 Promotion Release" section + [`docs/architecture/dev-guide-v1-to-v7-7.md`](../architecture/dev-guide-v1-to-v7-7.md) §2.4.1 + [`.claude/entrypoints/framework-v7-9.md`](../../.claude/entrypoints/framework-v7-9.md) cold-start entrypoint + [FT2-FH-003 honesty ledger](../case-studies/framework-honesty-ledger.md) + [v7.9 case study](../case-studies/framework-v7-9-promotion-case-study.md) + Linear epic FIT-72 In Progress + 9 sub-issues updated (FIT-78/79/80/81/84 Done, FIT-82/83 Canceled, FIT-85/86 In Progress).

**Case study:** [`docs/case-studies/framework-v7-9-promotion-case-study.md`](../case-studies/framework-v7-9-promotion-case-study.md) — live append-only journal; §99 synthesis deferred to 2026-05-28 post-B2 baseline snapshot.

**Phase E post-promotion validation runs 2026-05-21 → 2026-06-04 (LIVE):**

- No new gates ship
- No new test discipline work (F14, F18) starts
- Operator monitors `.claude/logs/gate-coverage.jsonl` for unexpected `failure` rows
- F17 (`last_fired_at` index) can be built in parallel since it's read-only — does not add new gates

**Original Scope** (preserved for historical reference): flip 6 currently-advisory mechanisms to enforced. **Actual scope at decision time:** 3 gates required action; 3 others were already enforced at v7.8/v7.8.3 (Mechanism A coverage + Mechanism C session-attribution + `CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT` V2 + Mechanism E V9). Scope narrowed via 2026-05-12 → 2026-05-21 patch-level work; no new measurement window required.

**Reversibility runbook:** single-line revert of `BRANCH_ISOLATION_ADVISORY_MODE = True` at [`scripts/check-state-schema.py:132`](../../scripts/check-state-schema.py) → commit + merge to main = <5min. Per [`.claude/entrypoints/framework-v7-9.md`](../../.claude/entrypoints/framework-v7-9.md) reversibility-runbook section.

### 3.6.3 v7.9.1 — Test Discipline Foundation + Low-Effort Wins (target 2026-06-04 → 2026-06-11)

**Scope:** ship the lowest-friction items that DON'T require waiting for v8.0 docket prioritization. All are non-gate-additive (no new gates) or telemetry-only.

| Item | Phase A status | Effort | Notes |
|---|---|---|---|
| **F16** — try-repo harness | Spec ready in PR #318 + §3.6.4 below | 0.5w | Foundation for F14 + F18 |
| **F17** — `last_fired_at` index | Spec at v7.9 candidates §2 F17 | 0.3w | Read-only derived artifact, no advisory window |
| **F2** — Phase 0 reality-check sub-step | Spec at v7.9 candidates §2 F2 | 0.3w | Workflow-only, no gate code |
| **F6** — B_medium tier doc | CLAUDE.md edit only | 0.1w | Doc-only |
| **D-2** — Configure GA4 conversions (`workout_complete` + `nutrition_meal_logged`) | Spec in [analytics decisions log §13](analytics-observability-decisions-log-2026-05-13.md) | 5 min | 🟡 yellow per analytics MP §7.5 — defer until 2026-06-04 to avoid contaminating v7.9 calibration. GA4 UI toggle; verify via `mcp__ga4__runReport` with `isConversionEvent` dim. Surfaced by FIT-142 closure 2026-05-17 (PR [#388](https://github.com/Regevba/FitTracker2/pull/388)) |
| **D-4** — Delete old `com.regevba.FitTracker` Firebase iOS app entry | Spec in [analytics decisions log §13](analytics-observability-decisions-log-2026-05-13.md) | 1 min | 🟢 green per analytics MP §7.5 — pure cleanup, no telemetry shape change. Operator-only Firebase Console click. Surfaced by FIT-142 closure 2026-05-17 (PR [#388](https://github.com/Regevba/FitTracker2/pull/388)) |

**Calibration windows:** F16 + F17 walk B–E since they're new infrastructure. F2 + F6 are workflow/doc changes (single-commit reversible) and skip B–C; ship directly with `verify-local` validation. D-2 + D-4 are operator-side surface changes (no code) and ride the v7.9.1 window only because they're scoped + cheap; D-4 could ship anytime post-v7.9 (green class) but is batched with D-2 to amortize the Firebase-Console operator cost.

**D-3 (screen-view tracking gap) note:** also surfaced by FIT-142 closure but excluded from v7.9.1 because it's iOS code work (1-2h) with new event volume → tracked as analytics-observability v8 docket candidate **F21**. See [analytics master plan §5.6](analytics-master-plan-2026-05-13.md#56-phase-1a-bis--screen-view-tracking-gap-deferred-to-v791-or-v80) (to be added) + state.json task D-3.

### 3.6.4 v8.0 — Top-Per-Theme Docket (target 2026-06-18 → 2026-07-31)

**Scope:** top 3 per theme by RICE × telemetry signal strength, picked at 2026-05-21 Phase 9 prioritization. Maximum docket = 18 items; realistic docket = 6–10 items per the historical v7.x cadence.

**Theme G test discipline precedence:** F14 + F18 only ship if F16 is in Phase E (post-validation stable) by ~2026-06-11 per the layer stacking rule (§3.5.2). If F16 slips, F14 + F18 also slip.

**Expected v8.0 docket composition (provisional, decided 2026-05-21):**

| Likely-in | Likely-defer-to-v8.1 |
|---|---|
| F1 (STATE_TASKS_FILESYSTEM_DRIFT) — Theme A top | F3 — workflow gate, lower telemetry pull |
| F4 (framework_version auto-update) — Theme C top | F5 — vocabulary, ergonomics-only |
| F10 (experiment_outcome enum) — Theme C #2 | F9 — make complete-feature, depends on F14/F18 |
| F11 (BRANCH_ISOLATION_HISTORICAL allowlist) — Theme F top | F12 (actionlint) — could ship v7.9.1 if it scores highest at 2026-05-21 |
| F14 (per-gate dispatch tests) — Theme G #2 (if F16 stable) | F13 — workflow_dispatch input |
| F15 (zero-coverage gate unit tests) — Theme G #3 | F18 (mutation testing) — depends on F14 + F16 |
| **F19** (CSV_TAXONOMY_DRIFT) — Theme G #4 (RICE 80.0; added 2026-05-13 via [analytics-master-plan §11](analytics-master-plan-2026-05-13.md#11-v79-candidate-mapping-f19--f20)) | — |
| **F20** (GA4_MCP_DISCONNECTED advisory) — Theme G #5 (RICE 30.0; added 2026-05-13) | — |

**Calibration:** every v8.0 item walks Phases B–E independently. v8.0 ships as a *cumulative release* — items merge to main as each individually completes Phase E.

### 3.6.5 v8.1 — Deferred F-items + First Icebox Triggers (target 2026-08 → 2026-09)

**Scope:** items deferred from v8.0 + any V8-I icebox item whose re-eval trigger fired.

**Likely V8-I triggers by ~2026-08:**
- **V8-I1** (Agent Smartlog UI) — trigger is ≥5 concurrent active features for 7+ days. Phase 2-bis + Track 6 + v8.0 builds may push concurrent count to that threshold; check at 2026-07-31.
- **V8-I2** (Op-log Replay) — trigger is ≥3 manual-cleanup incidents in 90d OR `git stash list` >5 for 30d. Currently 2 stashes on canonical (stress-test pre-skill + import-training-plan-resume); monitor.

**Likely V8-I non-triggers by ~2026-08 (defer to v8.2 or later):**
- V8-I3 (Vercel Sandbox / Firecracker microVM) — no untrusted-code use case in the queue
- V8-I4 (FS kernel sandboxing) — no regulatory mandate
- V8-I5 (inotify/fsevents broadcast mediator) — no concurrent-write incidents tracked
- V8-I6 (Cross-feature dependency analysis) — `path-reducers.json` has <5 entries; threshold is ≥20
- V8-I7 (Auto-rollback on kill-criteria fire) — needs F1 (STATE_TASKS_FILESYSTEM_DRIFT) telemetry first

### 3.6.6 v8.2+ — Long Tail (target Q4 2026 → 2027)

**Scope:** remaining V8-I icebox items whose re-eval triggers haven't fired + new candidates surfaced from v8.0/v8.1 dogfood.

**Note:** the framework explicitly does NOT pre-commit to v8.2+ contents. Per Phase E (post-promotion validation), each release writes its own docket only after the previous release stabilizes.

### 3.6.6.A Analytics Observability Sub-doc (added 2026-05-13)

Concurrent product-tier feature `analytics-observability` opened 2026-05-13 ships across the v7.9 + v7.9.1 + v8.0 windows as a sub-doc of this plan. Full spec at [`analytics-master-plan-2026-05-13.md`](analytics-master-plan-2026-05-13.md); decisions trail at [`analytics-observability-decisions-log-2026-05-13.md`](analytics-observability-decisions-log-2026-05-13.md).

**Calibration alignment with this plan:**

| Analytics phase | Date window | Calibration phase | Why |
|---|---|---|---|
| Phase 1.A (hygiene) | 2026-05-15 → 22 | N/A (non-gate) | Backfill 56 CSV rows + wire 4 events + 21 tests |
| Phase 2 (debugger) | 2026-05-15 → 22 (parallel 1.A) | N/A (non-gate) | Local mirror + GA4 Realtime MCP poll |
| Phase 3 (dashboards) | 2026-05-21 → 06-04 (parallel **v7.9 Phase E**) | N/A (non-gate) | `/control-room/analytics` route + Looker template; honors Phase E "no new gates" rule |
| Phase 1.B (gates) | 2026-06-04 → 06-26 | Full A→B→C→D→E 22d | 2 new gates: `CSV_TAXONOMY_DRIFT` (F19) + `GA4_MCP_DISCONNECTED` (F20); ship advisory 06-04, enforced earliest 06-18, Phase E exit 06-25 |

**Why this fits this plan:** the analytics work consumes Mechanism A coverage telemetry, F16 try-repo harness (ride-on, not blocker), v7.8.2 cross-repo asymmetry policy (FT2-only Mechanism A), v7.8.3 D-1 reverse-sync (CSV mirror to fitme-story build), and v8.x docket Theme G test discipline. Treating it as a separate parallel track would duplicate those interfaces; Approach A (sub-doc) keeps the forward-looking roadmap single-source.

**F19 + F20 added to §3.6.4 v8.0 docket Theme G** (see updated table below).

### 3.6.6.C fitme-story Discoverability Sub-doc (added 2026-05-20; cross-ref backfilled 2026-05-24 per D-PLAN-3)

Companion plan at [`fitme-story-discoverability-plan-2026-05-20.md`](fitme-story-discoverability-plan-2026-05-20.md) addressing the discoverability gap surfaced 2026-05-20: `fitme-story.vercel.app` was production-live with the v7.9 promotion case study but receiving 0 measurable web traffic. 4-phase plan (Foundation SEO → Crosslinking → Promotion → Measure+Iterate) with phased calendar 2026-05-21 → 2026-06-30 + kill criterion ("if <10 weekly visitors by 2026-06-30, pivot").

**Phase E safe** — Phases 1-3 are all UI/content/redirect work (no infra-path commits). Phase 4 measure window overlaps Phase E end (2026-06-04) but doesn't conflict (analytics-observability Phase 3.B wiring is independent of the v7.9 promotion gate calibration).

**Current status** (2026-05-24):

- Phase 1 (Foundation, code-side): **CODE COMPLETE** — P1.3 OpenGraph + Twitter Card meta + P1.4 OG image generator shipped 2026-05-21 (`src/app/layout.tsx` + `src/app/opengraph-image.tsx`). Operator-only items (P1.1 Search Console DNS + P1.2 sitemap + P1.5 GA Realtime verify) pending.
- Phase 2 (Crosslinking): **PARTIAL** — P2.1 FT2 README link shipped 2026-05-24 (PR #465); P2.2 fitme-story README link already present pre-plan; P2.3 dashboard 301 redirect + path preservation shipped 2026-05-24 (PR #467); P2.4 obviated by P2.3.
- Phase 3 (Promotion): operator content work (LinkedIn / HN Show / dev.to crossposts).
- Phase 4 (Measure + Iterate): 2026-06-04+ depends on analytics-observability Phase 3.B (E-4 in post-v7-9 candidate plan).

**Why this fits this plan:** discoverability is an operational follow-through on the v7.9 promotion case study (the same content the framework page surfaces). Treating it as standalone disconnects the SEO + crosslink lift from the strategic narrative the framework dev-guide + case studies tell. Cross-referencing here ties the sub-doc into the §3.6 forward plan.

### 3.6.6.B Cross-Layer Test Coverage Sub-doc (added 2026-05-13)

Concurrent test-discipline audit on 2026-05-13 surfaced that Theme G covers framework-layer tests only. The other five system layers (iOS, web, backend, AI, analytics) are under-spec'd or in some places zero-tested. Full audit + 16 T-candidates spec'd at [`test-coverage-master-plan-2026-05-13.md`](test-coverage-master-plan-2026-05-13.md).

**Headline gaps surfaced (4-agent audit):**

| Layer | Tests inventoried | Top gap |
|---|---|---|
| Framework (Python) | 133 methods / 13 files; ~30% gate coverage | cache_hits keying drift (v7.8.5 blocker — already on docket §2.4) |
| iOS (Swift) | 549 methods / 56 files | Sentry zero tests; SignInService passkey/WebAuthn zero tests; ~130-file View layer untested |
| Web (fitme-story) | 122 cases / 17 files | **Zero JS tests run on PR**; 119 React components + 27 routes untested; WebAuthn route handlers untested |
| Backend | 248 Swift methods / 22 files | SignInService zero coverage; multi-device reconciliation + key-rotation + sync cascades untested |
| AI | 75 methods / 5 files | **Zero LLM behavioral evals**; cohort prior has 3 tests; `phase2bis-prompt-set.json` has no harness |
| Analytics | 147 methods / 11 files; 81% event-count coverage | No runtime emission audit (events fired in app match CSV); ~40% parameter-combination coverage |

**T-candidate docket (Theme H) feeds 2026-05-21 prioritization pass alongside F-candidates.** Top-5 by RICE:

1. **T6** — Web PR test gate (RICE **200.0**; ~1h effort; v7.9.1 ride-along candidate or earlier)
2. **T14** — Platform-parity state.json field `platforms_tested: {ios, web, backend, ai}` (RICE **160.0**; extends FEATURE_CLOSURE_COMPLETENESS; ~1–2h)
3. ~~**T2** — Sentry integration test pass~~ ⏸ **DEFERRED to App Store launch** (Sentry integration stack paused 2026-05-21; TestFlight ≠ real-user signal; cadence §C3 deferral closed 2026-05-23). RICE **80.0**; will reopen when launch is scheduled.
4. **T13** — `last_fired_at` extension to all gates (RICE **80.0**; depends on F17 in Phase E)
5. **T1** — Per-gate dispatch test enforcement gate `GATE_TEST_MISSING` (RICE **53.3**; depends on F14 in Phase E; closes the drift class behind cache_hits keying)

**External pattern sources** (10 systems researched; 7 patterns borrowed): Next.js test stratification, AWS Config `LastSuccessfulInvocationTime`, Stripe/GitHub `oasdiff`, Linear/Lyft platform-parity, pre-commit `try-repo` + `stages:`, Semgrep rule-test pairing, promptfoo + Anthropic golden-set LLM evals, uber/pointfreeco Swift snapshot testing, ArchDrift + shipmonk orphan-test detection. Overkill-and-rejected: Pact broker, Next.js isolated-installation-per-test, Airbnb 30K-snapshot scale, Muter Swift mutation testing.

**Calibration alignment:** all T-candidates walk the same Phase A→E protocol (§3.5). T-candidates with effort ≤ XS that extend an already-enforced gate (T14, T16) may skip Phases B–C. The sub-doc also proposes a quarterly cross-layer test audit (sub-doc §6.2) recurring at T+90d (first run 2026-08-13), mirroring §3.5.3 Data Freshness Audit but covering application-layer tests.

**Why this fits this plan:** the sub-doc consumes the same calibration protocol, the same RICE convention, the same gate-coverage telemetry, and the same 2026-05-21 prioritization pass. Treating Theme H as a separate plan would duplicate those interfaces; sub-doc keeps the forward-looking roadmap single-source.

### 3.6.7 Cumulative Mechanism Inventory by Version (projected)

| Version | Mechanical gates | Advisory | Mechanisms (A–F) | Test discipline | Source |
|---|---|---|---|---|---|
| v7.8.4 (current) | 34 | 5 | A, C, D, F advisory; B, E enforced | None | shipped |
| v7.8.5 | 34 | 5 | same | None (fix only) | target 2026-05-14 |
| v7.9 | 34 | 3 | A, C → enforced; D, F stay advisory | None | target 2026-05-21 |
| v7.9.1 | 34 | 3 | same | F16 advisory; F17 enforced (read-only) | target 2026-06-11 |
| v8.0 | 37–39 | 4–6 | same + new gates per docket | F14 advisory; F15 enforced; F16 enforced | target 2026-07-31 |
| v8.1 | 40–43 | 4–6 | + deferred items | F18 advisory → enforced | target 2026-09 |

---

### 3.8 External Audit Substrate

The 4 External Audits + 4 quarterly Data Freshness Audits booked in §5 run through a single substrate: `docs/audits/prompts/01-extraction-prompt.md` (operator-side) + `docs/audits/prompts/02-auditor-prompt.md` (fresh-chat auditor) + `scripts/audit/build_bundle.py` (deterministic, redacted bundle generator). Profile JSON files at `scripts/audit/profiles/*.json` parameterize the substrate per audit date — same prompts, different file set. Spec: [`docs/superpowers/specs/2026-05-18-impartial-audit-prompt-substrate-design.md`](../superpowers/specs/2026-05-18-impartial-audit-prompt-substrate-design.md).

This addresses unclosable-gap #5 (Tier 3.3 external replication — see §6.1).

---

## 4. HADF Phase 2-bis — Active Research Build (Special Status)

HADF Phase 2-bis is the only infra-adjacent build *currently in flight* on the main branch. It's a research-tier feature whose 5 phases of cross-repo sync infrastructure dependencies are met by v7.8.3.

### 4.1 Status

- **Branch:** `feat/hadf-phase2bis-spec` (current branch as of session open)
- **Open PR:** [FT2 #306](https://github.com/Regevba/FitTracker2/pull/306) — finalized design spec
- **Spec:** [`docs/superpowers/specs/2026-05-11-hadf-phase2bis-replication-design.md`](../superpowers/specs/2026-05-11-hadf-phase2bis-replication-design.md) — 2,919 words / 14 sections after R1–R8 audit revisions
- **Phase:** Spec complete (Phase 1 of /pm-workflow). Awaiting user review on PR #306, then writing-plans → tasks → implementation.

### 4.2 Infra Dependencies (all MET by v7.8.3)

| Dependency | v7.8.3 deliverable | Status |
|---|---|---|
| `state_owner` schema with STATE_OWNER_* gates | Phase 2 of v7.8.3 | ✅ MET 2026-05-11 |
| V2 (`CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT`) enforced | Phase 0 of v7.8.3 | ✅ MET 2026-05-11 |
| V9 (Mechanism E driver) covers `.claude/logs/<feature>.log.json` | Phase 0 of v7.8.3 | ✅ MET 2026-05-11 |
| `make snapshot-phase` for per-phase backups | Phase 0 of v7.8.3 | ✅ MET 2026-05-11 |
| `FEATURE_CLOSURE_COMPLETENESS` enforced via Phase 4 cutover protocol | v7.8.1 (advisory) → v7.8.3 cutover protocol | ✅ MET 2026-05-11 |

### 4.3 Sub-Experiment Timeline (15 days wall-clock, ~$5 total)

| Window | Sub-experiment | Description | Cost |
|---|---|---|---|
| **2026-05-23 → ~2026-05-26** | Sub-exp 1 | Cloud generalization + halfway routing test (9 endpoints, 6 providers) | ~$3–4 |
| → kill-criteria check → verdict | | | |
| **~2026-05-27 → ~2026-05-30** | Sub-exp 2 | Cloud-vs-local separability (Ollama on M2, 1 endpoint) | $0 |
| → kill-criteria check → verdict | | | |
| **~2026-05-31 → ~2026-06-03** | Sub-exp 3 | Decisive same-model routing test (AWS Bedrock haiku vs Anthropic direct, 3 endpoints) | ~$1 |
| → anchor-drift trip-wire → verdict | | | |
| **~2026-06-07** | Cross-synthesis | Cross-sub-exp synthesis case study published | — |

### 4.4 Pre-Launch Gate

Sub-experiment 1 cannot start until **all 4 mandatory architectural fixes** + **3 pre-registration JSON files** + **6-item pre-experiment safety verification ceremony** complete. Spec §6–§10 enumerate.

### 4.5 Downstream Unblock

Once Sub-experiment 3 verdict lands (~2026-06-03), the deferred **Track 6 HADF gate activation** Feature becomes eligible to start. That Feature was explicitly Q3=OUT of Phase 2-bis scope; it's a separate Feature lifecycle.

---

## 5. Roadmap — Date-Gated Master Calendar

Verbatim dates from source files. All times where unspecified are end-of-day in IDT (UTC+3).

### 5.1 May 2026

| Date | Event | Source |
|---|---|---|
| **2026-05-11** | v7.8.3 SHIPPED · V2 enforced · V9 extended to feature logs · `state_owner` backfill complete | [v7.8.3 case study](../case-studies/cross-repo-state-sync-impl-case-study.md) |
| **2026-05-11** | HADF Phase 2-bis unblock criterion MET (Q1=S1 sequencing) | v7.8.3 Phase 4 cutover |
| **2026-05-12** | This document opened · v7.8.4 SHIPPED (PR #314) · HADF Phase 2-bis Block A SHIPPED (PR #316) · PR #317 (`BRANCH_ISOLATION_VIOLATION` Mode B fix) MERGED · PR #318 (F14–F18 candidates added to v7.9 spec) OPEN | — |
| **2026-05-13** | **v7.8.5 PATCH TARGET — cache_hits keying remediation** (§2.4) | This document §2.4 (added 2026-05-12) |
| **2026-05-14** | v7.8.5 latest acceptable ship to keep full 7d calibration window before 2026-05-21 | derived |
| **2026-05-18** | v7.9 promotion window opens (T+7d post-v7.8 ship) | [v7.8 bridge spec](../superpowers/specs/2026-05-02-framework-v7-8-and-v7-9-bridge-design.md) |
| **2026-05-21** | **v7.9 PROMOTION DECISION** + **T29 v8.0 docket ranking pass** (23 candidates now, up from 13 pre-PR #318) | v7.8.1 PRD §Phase 9 |
| **2026-05-23** | HADF Phase 2-bis Sub-experiment 1 earliest launch (T+12d soak post-v7.8.3) | [Phase 2-bis spec](../superpowers/specs/2026-05-11-hadf-phase2bis-replication-design.md) §11 |
| **~2026-05-26** | Sub-exp 1 verdict + kill-criteria check | spec §10 |
| **~2026-05-27** | Sub-exp 2 launch (if Sub-exp 1 passes kill-criteria) | spec §10 |
| **~2026-05-30** | Sub-exp 2 verdict + kill-criteria check | spec §10 |
| **~2026-05-31** | Sub-exp 3 launch (if Sub-exp 2 passes kill-criteria) | spec §10 |

### 5.2 June 2026

| Date | Event | Source |
|---|---|---|
| **~2026-06-03** | Sub-exp 3 verdict + anchor-drift trip-wire | spec §10 |
| **~2026-06-04** | v7.10 promotion window opens (next 14d cycle for any v7.9 gates still advisory) · **v7.9 Phase E exit** (post-promotion validation 7d clean) | calendar + §3.5 |
| **~2026-06-04** | v7.9.1 build window opens (F16 + F17 + F2 + F6 — non-gate-additive items) per §3.6.3 | §3.6 |
| **~2026-06-07** | HADF Phase 2-bis cross-sub-exp synthesis case study published | spec §10 |
| **~2026-06-07** | Track 6 HADF gate activation Feature becomes eligible | Phase 2-bis closure |
| **~2026-06-11** | v7.9.1 latest ship target · F16 try-repo harness Phase E exit (foundation for F14 + F18) | §3.5.2 layer stacking rule |
| **~2026-06-18** | v8.0 build kickoff window — earliest start if top-per-theme docket items chosen at 2026-05-21 · F14 + F18 unblock if F16 reached Phase E | §3.6.4 |

### 5.3 Q3 2026 (provisional)

| Date | Event | Source |
|---|---|---|
| **2026-07-31** | v8.0 ship target — top-per-theme docket from F1–F18 + V8-I triggers | §3.6.4 |
| **2026-08-12** | **First Data Freshness Audit** (T+90d quarterly) — assert gate emission keys ↔ function names ↔ test names all canonical, profile: `freshness` | §3.5.3 |
| **2026-08-31** | v8.1 build window opens — deferred F-items + first V8-I icebox triggers | §3.6.5 |
| **2026-09-30** | v8.1 ship target | §3.6.5 |

### 5.4 Q4 2026 + 2027 (provisional)

| Date | Event | Source |
|---|---|---|
| **2026-11-12** | Data Freshness Audit #2 (T+180d), profile: `freshness` | §3.5.3 |
| **2026-12** | v8.2 build window — long-tail V8-I icebox items per their re-eval triggers | §3.6.6 |
| **2027-02-12** | Data Freshness Audit #3 (T+270d), profile: `freshness` | §3.5.3 |
| **2027-05-08** | v7.8.2 cross-repo gate asymmetry annual re-eval (F7/F8 RESOLVED status review) | [2026-05-08 spec](../superpowers/specs/2026-05-08-cross-repo-gate-asymmetry.md) §5 |
| **2027-05-12** | Data Freshness Audit #4 (T+365d, one year of forward plan), profile: `freshness` | §3.5.3 |

---

## 6. Cross-Cutting Concerns

### 6.1 Mechanically Unclosable Gaps (carried forward from v7.6)

Recorded authoritatively in [`docs/case-studies/meta-analysis/unclosable-gaps.md`](../case-studies/meta-analysis/unclosable-gaps.md). v7.8.3 did not change this list:

1. ~~`cache_hits[]` writer-path adoption~~ — **CLOSED in v7.8.3 (V2 enforced)**
2. `cu_v2` factor *correctness* — judgment-based; presence-checked only
3. T1/T2/T3 tier-tag *correctness* — presence-checked, not value-checked
4. Tier 2.1 real-provider auth checklist — requires human-at-simulator
5. Tier 3.3 external replication — requires external operator ([GitHub issue #142](https://github.com/Regevba/FitTracker2/issues/142))

### 6.2 Cross-Repo Asymmetry (codified v7.8.2)

v7.8.2 documented that fitme-story does NOT get full FT2 gate parity. The asymmetry is intentional:

- FT2 = canonical state.json owner for product features + framework state
- fitme-story = state_owner for fitme-story-native features only (3d-interactive-framework-flow-diagram is the first)
- Mechanism A `gate-coverage.jsonl` emits in FT2 only; cross-repo aggregator (`gate-coverage-aggregator.ts`) reads both streams into the control-room UI

Re-eval annual (next 2027-05-08) or earlier if 3 signals fire. Full spec: [2026-05-08-cross-repo-gate-asymmetry.md](../superpowers/specs/2026-05-08-cross-repo-gate-asymmetry.md).

### 6.3 Concurrent Dispatch Hygiene

Parallel subagent dispatch remains **blocked at the framework layer** (F6–F9 from audit-v2 stress test). Serial dispatch is the working pattern until upstream patches land. Re-validation gate documented at [`docs/superpowers/plans/f6-f9-reproducer/proof-of-fix-tests.md`](../superpowers/plans/f6-f9-reproducer/proof-of-fix-tests.md). No v7.9 / v8.0 work depends on parallel dispatch.

### 6.4 v7.8 Mechanisms A–F — Promotion Decoupling

The six v7.8 bridge mechanisms (A coverage gates, B schema dual-read, C session attribution, D self-audit, E merge driver, F membrane status) ship/promote independently:

| Mechanism | Status as of 2026-05-12 |
|---|---|
| **A** — coverage gates | Advisory; 2026-05-21 promotion-eligible |
| **B** — schema field-rename dual-read | Already canonical (46/46 features migrated `created` → `created_at` in v7.8 PR-2) |
| **C** — PostToolUse:Read hook + session attribution | Advisory; 2026-05-21 promotion-eligible |
| **D** — pre-commit header self-audit | Advisory; stays advisory (low signal) |
| **E** — custom git merge driver | Enforced 2026-05-11 (extended to feature logs in v7.8.3) |
| **F** — membrane status advisory | Stays advisory (operator readout, not gate) |

---

## 7. Risk Register (infra-only)

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| **cache_hits keying drift corrupts 2026-05-21 calibration data** (added 2026-05-12) | Medium | High (promotion decision keyed wrong) | v7.8.5 patch ships 2026-05-13 → 14 per §2.4; full audit of gate emission ↔ function name ↔ test name alignment; regression test asserts canonical key emission |
| 2026-05-21 promotion fails on insufficient telemetry | Low | Medium | Stays advisory + re-evaluates 2026-06-04 (T+14d) |
| HADF Phase 2-bis Sub-exp 1 kill-criteria fire | Medium | High (research-track halt) | Pre-registered kill criteria + 3 independent sub-experiments; failure of one does not invalidate the others |
| F12 (actionlint) ships but catches a real CI YAML error mid-promotion week | Low | Low | Pre-commit gate fires locally before push; CI side already covered by GH Actions runtime validation |
| v8.0 prioritization pass produces an empty docket | Low | Low | v8.0 ships as protocol patch; v8.1 inherits the F-series + icebox |
| DevSSD disconnect during 2026-05-21 or 2026-05-23 windows | Medium (hardware open) | High | Pre-window: ensure backup + `pmset disksleep 0`; tracked separately in [project_devssd_disconnect_remediation_2026_05_02.md](~/.claude/projects/-Volumes-DevSSD-FitTracker2/memory/project_devssd_disconnect_remediation_2026_05_02.md) |
| Cross-repo sync workflow regression on first non-FT2 fitme-story-native feature | Medium | Medium | F11 (BRANCH_ISOLATION_HISTORICAL allowlist) ships in v8.0 — interim manual reconciliation if regression hits 2026-05-12 → 2026-05-21 |
| **Test discipline debt blocks v8.0 docket** (added 2026-05-12) | Medium | Medium | §3.5.2 layer stacking rule requires F16 (try-repo harness) at Phase E before F14 or F18 ships. If F16 slips, drop F14+F18 from v8.0 docket; don't pile on debt. |
| **Mutation testing CI cost overrun on F18 promotion** (added 2026-05-12) | Low | Low | Phase B calibration measures actual `mutmut` runtime on hosted runner; if >15min/run, scope further before flipping enforced. Defer rather than slow CI. |
| **Phase A specification rot** — gate spec exists but no fixture written, so Phase B coverage is theoretical (added 2026-05-12) | Medium | Medium | §3.5.1 Phase A exit criteria require BOTH spec AND fixture AND dispatch test. PR template + reviewer checklist added. |

---

## 8. Open Questions

1. **v7.9 cadence going forward** — Is the T+14d advisory→enforced cadence the durable rule, or should it widen to T+21d once the framework stops accumulating new gates? §3.5 codifies T+22d as the per-layer minimum (Phase B 7d + Phase C 7d + Phase D 1d + Phase E 7d) — should the project-wide cadence widen to match? Decide at 2026-05-21.
2. **F12 (actionlint) priority placement** — RICE-est is 100.0 (highest in F-series). Should it ship *outside* the v8.0 docket as a v7.9.1 patch, or wait for v8.0? §3.6.3 currently does NOT include F12 in v7.9.1 because actionlint is gate-additive (new pre-commit check) — would require full Phase B–E walk. Decide at 2026-05-21.
3. **v8.0 vs v8.1 split** — Top-per-theme rule (§3.3) may force F-items vs icebox items into the same shortlist. Tie-breaker: prefer F-items (already spec'd) over icebox (specs pending). Confirm at prioritization pass.
4. **HADF gate activation as separate Feature vs v8.0 entry** — Track 6 is explicitly separate at ~2026-06-07 launch. Should it carry its own framework version bump (v8.x = HADF gate)? Decide at Phase 2-bis Phase 9 close.
5. **(NEW 2026-05-12) v7.8.5 ship timing** — Can v7.8.5 (cache_hits keying remediation) ship 2026-05-13 OR 2026-05-14? If delayed past 2026-05-14, the gate's calibration window shrinks below 7d and that specific gate must defer to v7.10. Triage urgency on 2026-05-13 morning.
6. **(NEW 2026-05-12) F16 sequencing — ship at v7.9.1 OR bundle with v8.0?** §3.6.3 puts F16 in v7.9.1 as foundation for F14 + F18. Argument for earlier ship: harness IS the calibration tool — lets us validate F14's per-gate dispatch tests catch dispatcher bugs. Argument for bundling with v8.0: keeps v7.9 promotion atomic + reduces Phase D cycles. Decide at 2026-05-21.
7. **(NEW 2026-05-12) Phase A enforcement** — should Phase A artifacts (spec + fixture + dispatch test) be enforced via a new pre-commit gate (`GATE_SPEC_INCOMPLETE`) OR via PR-review checklist only? Mechanical enforcement matches v7.8.1 spirit; checklist-only matches v7.8.4 humility about what can be mechanically checked. Decide at 2026-06-04 v7.9.1 build start.

---

## 9. References

### Sub-docs (children of this plan)

- [`analytics-master-plan-2026-05-13.md`](analytics-master-plan-2026-05-13.md) — analytics-observability sub-doc (F19/F20 source)
- [`test-coverage-master-plan-2026-05-13.md`](test-coverage-master-plan-2026-05-13.md) — cross-layer test coverage sub-doc (T1–T16 source; Theme H)
- [`data-integrity-and-rollback-2026-05-14.md`](data-integrity-and-rollback-2026-05-14.md) — continuous-integrity observability layer + platform-baseline rollback protocol (anchored to the 2026-05-14 baseline snapshot). **2026-06-10 addition** §2.6 dilution-normalized drift comparison (`make integrity-multi-anchor`, dilution-aware regression definition, instrumented-vs-derived provenance split) + §2.7 unified telemetry data-layer (`make integrity-data-lake`); the 2026-05-14 anchor stays canonical (non-superseding) — honesty ledger FT2-FH-004
- [`dev-env-master-plan-2026-05-24.md`](dev-env-master-plan-2026-05-24.md) — dev-env stability & scale sub-doc (R1–R24 source; chore-cadence, NOT in v7.9.1 / v8.x F-series docket). Source audit at [`docs/research/2026-05-19-dev-env-audit-stability-and-scale.md`](../research/2026-05-19-dev-env-audit-stability-and-scale.md)
- [`ui-ux-master-plan-2026-05-24.md`](ui-ux-master-plan-2026-05-24.md) — UI/UX sub-doc covering both surfaces (iOS + website). 26 shipped + 9 in-flight + ~23 open backlog items cross-referenced with parent features. Drives per-screen v2 alignment, design-system evolution, ui-audit P1 drift, Code Connect bridge, and UCC operator-dashboard polish. NOT in v7.9.1 / v8.x F-series docket — items ship as feature/enhancement/chore per their own cadence.

### Addenda (one-off verification + post-mortem records)

- [`oldssd-devssd-migration-verification-addendum-2026-05-25.md`](oldssd-devssd-migration-verification-addendum-2026-05-25.md) — formal git cross-reference (recovery-mode inspection) verifying the 2026-05-19 SSD migration preserved 100% of work. Demotes oldSSD from primary canonical to redundant tertiary backup. Companion memory + raw evidence snapshot at `~/Documents/FitTracker2-backups/2026-05-25-oldssd-devssd-cross-reference-addendum/`. §6 includes a re-runnable verification methodology for future SSD migrations.

### Source documents folded into this plan

- [`master-plan-2026-04-15.md`](master-plan-2026-04-15.md) — current product master plan (v7.8.3 banner added 2026-05-11)
- [`master-backlog-roadmap.md`](master-backlog-roadmap.md) — product RICE backlog (separate from this infra plan)
- [`docs/superpowers/specs/2026-05-02-framework-v7-8-and-v7-9-bridge-design.md`](../superpowers/specs/2026-05-02-framework-v7-8-and-v7-9-bridge-design.md) — v7.8 bridge + v7.9 design
- [`docs/superpowers/specs/2026-05-07-branch-isolation-out-of-scope.md`](../superpowers/specs/2026-05-07-branch-isolation-out-of-scope.md) — 7 v8 icebox items
- [`docs/superpowers/specs/2026-05-08-cross-repo-gate-asymmetry.md`](../superpowers/specs/2026-05-08-cross-repo-gate-asymmetry.md) — F7/F8 resolution
- [`docs/superpowers/specs/2026-05-11-cross-repo-state-sync-impl-design.md`](../superpowers/specs/2026-05-11-cross-repo-state-sync-impl-design.md) — v7.8.3 spec
- [`docs/superpowers/specs/2026-05-11-hadf-phase2bis-replication-design.md`](../superpowers/specs/2026-05-11-hadf-phase2bis-replication-design.md) — HADF Phase 2-bis spec
- [`docs/superpowers/plans/2026-05-11-cross-repo-state-sync-impl.md`](../superpowers/plans/2026-05-11-cross-repo-state-sync-impl.md) — v7.8.3 plan
- [`docs/case-studies/cross-repo-state-sync-impl-case-study.md`](../case-studies/cross-repo-state-sync-impl-case-study.md) — F11/F12/F13 surface point
- [`docs/case-studies/framework-v7-8-bridge-case-study.md`](../case-studies/framework-v7-8-bridge-case-study.md) — v7.8 mechanisms A–F
- [`docs/case-studies/framework-v7-8-branch-isolation-case-study.md`](../case-studies/framework-v7-8-branch-isolation-case-study.md) — v7.8.1 gates
- [`docs/case-studies/roadmap-stress-test-2026-05-07-case-study.md`](../case-studies/roadmap-stress-test-2026-05-07-case-study.md) §99 — F1–F10
- [`docs/case-studies/meta-analysis/unclosable-gaps.md`](../case-studies/meta-analysis/unclosable-gaps.md) — carried-forward limits

### Live state
- [`.claude/features/framework-v7-8-branch-isolation/state.json`](../../.claude/features/framework-v7-8-branch-isolation/state.json) — T29 prioritization pass
- [`.claude/shared/measurement-adoption-history.json`](../../.claude/shared/measurement-adoption-history.json) — Tier 1.1 trend data
- [`.claude/shared/documentation-debt.json`](../../.claude/shared/documentation-debt.json) — Tier 3.2 trend data
- [`.claude/logs/gate-coverage.jsonl`](../../.claude/logs/gate-coverage.jsonl) — telemetry for 2026-05-21 decision
- [`.claude/entrypoints/framework-v7-8-3.md`](../../.claude/entrypoints/framework-v7-8-3.md) — cold-start entrypoint

### External
- Linear v7.9 epic — to be created 2026-05-21 (likely FIT-72 or next)
- Notion v7.9 sub-page — to be created 2026-05-21 (under FitMe Product Hub)
- GitHub issue [#142](https://github.com/Regevba/FitTracker2/issues/142) — Tier 3.3 external replication invitation

---

## 10. Change Log for This Document

| Date | Change |
|---|---|
| 2026-05-12 | Initial creation. Consolidates v7.9 / v8.x infra surface as of v7.8.3 ship. |
| 2026-05-12 (evening) | Major expansion. PR #317 + #318 + test-suite audit + external research integrated. Added: §1.1 v7.8.4 + PR #317/#318 anchor; §2.4 v7.8.5 pre-promotion remediation patch (cache_hits keying); §3.1 Source D (F14–F18 test discipline); §3.3 top-per-theme docket rule + Theme G precedence; §3.4 theme distribution table; **§3.5 Calibration Protocol for New Layers** (5 phases, layer stacking rule, quarterly Data Freshness Audit, reversibility contract); **§3.6 Forward Plan v7.8.5 → v8.2** (versioned roadmap mapping all 23 open candidates); §5.1 + §5.2 + §5.3 + §5.4 extended calendar through 2027-05-12; §7 added 4 new risks; §8 added 3 new open questions (Q5/Q6/Q7). Doc grew 320 → ~430 lines. |
| 2026-05-13 | Analytics observability sub-doc + F19/F20 expansion. v7.8.5 SHIPPED via PR #320 (2026-05-12; cache_hits fixture rot confirmed case 2); v7.8.5.1 SHIPPED via PR #331 (4 residual test fixture rot from v7.8.3 + v7.8.4 schema migrations). Added §3.6.6.A `analytics-observability` sub-doc reference + F19/F20 to §3.6.4 v8.0 docket + Theme G expanded to 7 items in §3.4 (was 5). Total open candidates 23 → 25. 3D Framework Universe parked at PRD waypoint with `scheduled_after.signal: "analytics-observability phase=complete"`. Companion docs: [`analytics-master-plan-2026-05-13.md`](analytics-master-plan-2026-05-13.md) + [`analytics-observability-decisions-log-2026-05-13.md`](analytics-observability-decisions-log-2026-05-13.md). |
| 2026-05-14 | Data-integrity-and-rollback sub-doc + cross-layer test coverage sub-doc + daily integrity checkpoint VERIFIED (launchd via `/opt/homebrew/bin/python3`; first cron 2026-05-15 06:00). Linear/Notion sync: FIT-139/140 epics + FIT-141-164 sub-tasks; Notion v7.8.5 page created. Analytics-observability Phase 2 SHIPPED via PRs #342/#345/#349/#351 (#354 + fitme-story #108 still open). |
| 2026-05-15 | **v7.8.6 Cadence Batch SHIPPED** via PRs #361/#363/#364/#365/#366 + fitme-story #112. Adds `make integrity-diff` + unified `make preflight WORK_TYPE=<>` entry point + weekly Mechanism A gate-coverage zero-drift scan + per-dimension adoption trend nudge + W1 ssh-agent preflight + weekly dependency audit + daily stale-branch/orphan-worktree warning + daily open-PRs-idle-24h babysit. MUST-have follow-up tracker at [`must-have-cadence-followups.md`](../../.claude/shared/must-have-cadence-followups.md). |
| 2026-05-16 | Daily check + W11 fix SHIPPED via PR #375. Phantom 32 BROKEN_PR_CITATION root cause = per-repo emptiness check; fixed. v7.9 calibration window clear (2088 events / 17 gates / 12 days). [`framework-v7-9-promotion/state.json`](../../.claude/features/framework-v7-9-promotion/state.json) scaffolded as tracking container. UCC passkey cutover Parts 1-6 SHIPPED via FT2 #380 + fitme-story #120. Skills review EXECUTED (16/17 shipped). Next skills review 2026-08-13. |
| 2026-05-17 | GA4 binding + iOS firehose RESOLVED. Root cause: plist missing target membership. Audit-log Redis fix + legobrick recovery via fitme-story PR #122 (live) + FT2 #383 (open). New W11 pattern (Vercel-fs ephemerality). UCC passkey Part 7 break-glass DEFERRED before 2026-05-28. |
| 2026-05-18 | v7.9 pre-decision ship: T7.9.0 COMPLETE + 5 PRs merged (#400-#404; grandfather + risk closure + cache_hits draft + UU4 spec + rollback rehearsal). Audit substrate SHIPPED via PR #405 (18 tasks done, 36/36 tests, 5 profiles); ready for external audit #1 2026-05-22. PR audit + execution (9 PRs handled; race-condition issue #397 filed). |
| 2026-05-19 | SSD migration refresh + dev-env audit + branch protection applied (both repos: `integrity` + `Build and Test` for FT2; `verify` + `gates` for fitme-story). New X10 Pro drive arrived + fresh-cloned at `/Volumes/DevSSD2/`; rename DevSSD2 → DevSSD. MEMORY.md trimmed 46KB → <24KB. UCC security hardening kickoff via FT2 PR #410. |
| 2026-05-20 | **UCC hardening shipped** via FT2 #410/#411/#412 + fitme-story #127. T20 4/6 LIVE. Audit-log cron CRON_SECRET fix unblocked Vercel Blob sync. GA4 live audit (35 iOS TestFlight users / 13 event types) — instrumentation-verification only (iOS pre-launch; not real-user signal). v7.9 pre-freeze health GREEN (0 enforced findings, 23 BRANCH_ISOLATION + 10 FEATURE_CLOSURE_COMPLETENESS 14d Mechanism A firings). |
| 2026-05-21 | **v7.9 PROMOTION SHIPPED** via PR #417 (`ea53ff4`). 3 advisory gates → enforced via single-flag flip at [`scripts/check-state-schema.py:132`](../../scripts/check-state-schema.py): `BRANCH_ISOLATION_VIOLATION` Mode B + Mode C + `FEATURE_CLOSURE_COMPLETENESS`. All 4 §2.2 criteria GREEN. Side-effects: CLAUDE.md v7.9 section + dev-guide §2.4.1 + [`.claude/entrypoints/framework-v7-9.md`](../../.claude/entrypoints/framework-v7-9.md) + [FT2-FH-003 honesty ledger](../case-studies/framework-honesty-ledger.md#ft2-fh-003) + [`docs/case-studies/framework-v7-9-promotion-case-study.md`](../case-studies/framework-v7-9-promotion-case-study.md) + Linear FIT-72 In Progress + 9 sub-issues updated. **First real-world Mode C gate fire** caught + resolved (state.json::branch update). Day shipped 4 PRs: #413 (`e05eb32`) + #415 (`424963f`) + #416 (`0178a9c`) + #417 (`ea53ff4`) + close-out #419 (`9bfb7bb`). **Sentry pause** documented (PR #418) — pre-launch trigger because iOS app is TestFlight-beta only. §3.6.2 updated with SHIPPED outcome. Phase E live 2026-05-21 → 2026-06-04. |
| 2026-05-22 | **Phase E day 1: post-promotion calibration sweep + plan refresh.** Full data-integrity + telemetry sweep `make integrity-check` returned **0 findings + 0 advisory** post-PR #442 (advisory-clear backfill: cache_hits[] + T2 tier-tag on UCC hardening case study). §0 TL;DR refreshed to reflect v7.9 SHIPPED state. §3.1 expanded with **Source E** (5 candidates from post-v7.9 plan): F19 (analytics-observability Phase 1.B GA4 conversions, v7.9.1) + F20 (Firebase event-name cleanup, v7.9.1) + ~~F21~~ (Sentry — PAUSED pre-launch) + F22 (Funnel Analysis Dashboards, post-Phase-E) + F23 (`/ops digest` skill). MEMORY.md stale "Latest" marker on 2026-05-20 row removed; v7.9 promotion entry updated to reflect all 4 PRs merged. `fitme-story-public-enhancements` T13 reconciled in state.json (shipped 2026-05-21 via fitme-story PR #129 `ad65d98`; 24/24 tasks done). Phase E day 1 telemetry healthy (Mechanism A 16 distinct gates emitting; 273 events total). |
| 2026-05-23 | **Phase E day 2: 16+ PR mega-day + comprehensive PR↔docs audit + integrity recovery.** FT2 #450-#459 + fitme-story #137-#140 merged (CLAUDE.md drift fix; **C1 F14+F15 dispatch-test coverage SHIPPED** via PR #451 squash `86084c4` — 161/161 pytest pass, combined dispatch coverage 1/19 → 10/19 = 53%; **C2 web PR JS test gate SHIPPED** via fitme-story PR #137 — `npm test` now runs on every PR/push to main, 112 cases; **B8 UCC parent T+7d kill-criteria EXECUTED** via PR #453 — K2 `not_fired`, K1+K3 not_yet_observed; C-batch C7+C8+C11+C12 infra-ops chores via PR #454; hygiene close-2-features via PR #455). **5-parallel-agent comprehensive PR↔docs audit** dispatched (FT2 #1-#456 + fitme-story #1-#140 + all master plans + sub-plans); ~80 drifts surfaced; 26+ closed across drift-close PRs #456/#457/#458/#459. **🚨 INTEGRITY RECOVERY:** daily-checkpoint launchd cron silently broken 5 days post-2026-05-19 SSD migration (plist anchored to `/Volumes/DevSSD 1/`); patched + reloaded; exit code 78 → 0. NEW v7.9.1 candidate **E-14 F-LAUNCHD-DRIFT-EXTENSION** filed. YubiKey LIVE on `/control-room` (Redis 1→2 credential count). Late-evening Tier 3 batch: retroactive feature dirs opened for hadf-phase2-cloud-fingerprinting (#461 MERGED) + orchid-v1-5 (paused state, #462 MERGED) + roadmap-stress-test-2026-05-07 (slot 35 MDX via fitme-story #141 + state.json #460 MERGED). MEMORY.md trimmed 30.8KB → 19.4KB. |
| 2026-05-24 | **Phase E day 3: 8 PRs + 22 cadence items closed.** Doc-refresh batch: 6 FT2 framework docs (PR #464) + fitme-story `/framework` page + advancement-data timeline v7.1→v7.9 (PR #142) + C8b vercel-link mirror into fitme-story (PR #143). Recommended-list 1-5 execution: **C13 ai-engine deployment doc** ([`docs/architecture/ai-engine-deployment.md`](../architecture/ai-engine-deployment.md), ~200 lines confirming Railway production URL `https://fittracker-ai-production.up.railway.app` + iOS client wiring chain + 5 endpoints + cohort loop verification protocol — unblocks E-13 cohort intelligence runtime verification) + **DISCO P2.1** FT2 README link + **DISCO P2.3** dashboard 307→301 + path preservation (PR #467) + **E-5** smart-reminders ↔ DeepLinkRouter wiring (PR #466, ~30 LOC + 2 XCTests; scaffold was already in place — missing observer was the bridge) — all in PR #465. Session-end hygiene PR #468 (A1-A5+B1-B4: 9+1 doc closeouts across cadence-followups + post-v7-9 candidate plan + master-plan-reconciled archive move to `_archive/` + D-PLAN-3/5/6/9/10 + C-15 + this §10 entry). **22 cadence items closed today** total (C6/C8b/C9/C10/C13/C15/E-2/E-5/E-8 + DISCO P1.3/P1.4/P2.1/P2.3/P2.4-obviated + D-AUDIT-22/D-PLAN-1/3/5/6/9/10 + D-RECON-12). Tier-3 C1 sub-plan refresh batch in progress this PR. Phase E day 3 telemetry healthy. |
| 2026-05-24 (later) | **Dev-env + UI/UX sub-plans codified (4th + 5th sub-docs) via PR #472 (MERGED `5542327`).** Two new sub-plans registered under §9 References: (a) [`dev-env-master-plan-2026-05-24.md`](dev-env-master-plan-2026-05-24.md) promotes the 2026-05-19 research-grade dev-env audit to a tracked plan with R1–R24 status matrix (6/24 shipped — R1+R2+R3+R4+R5+R6 verified via fs ground-truth sweep); R-items are Chore-cadence and do NOT compete for v7.9.1 / v8.x F-series slots; 18 open R-items mirrored as `docs/product/backlog.md` §"Dev-Env Stability & Scale Track". (b) [`ui-ux-master-plan-2026-05-24.md`](ui-ux-master-plan-2026-05-24.md) covers UI/UX work across both surfaces (26 shipped + 9 in-flight + ~23 open); surfaces 5 drift / reconciliation items (UX-R1 through UX-R5); open items mirrored as backlog §"UI/UX Track". Same session: **UX-R1** state.json reconciliation of `fitme-story-public-enhancements` `phase=implementation → complete` with Q6 PR-list parity backfill (T13 pr#129 → 134 + related_prs added to T7/T8/T15/T17/T21 + `pr_citation_exempt` for #75/#129) + Tier 2.2 phase_transition log; **UX-R2** verified `ai-recommendation-ui` `parent_case_study` link satisfies `STATE_NO_CASE_STUDY_LINK`; **UX-R3** new `docs/design-system/design-rules.md` codifying AI-avatar = brand-icon rule; **UX-R4** new `docs/case-studies/pm-flow-orbital-iteration-case-study.md` for orbital rollback iteration log; **UX-R5** Failure Recognition Layer filed Aspirational/v8.x candidate; **B3** daily GA4 anomaly check executed (no anomalies; 2026-05-21 119-screen-view spike correlates with v7.9 ship date, not real user signal). Integrity baseline preserved 0+0 throughout. Dev-guide v7.9 readability pass + ledger updates shipped via follow-up PRs #144 + #473 (both MERGED). |
| 2026-05-24 (afternoon-2) | **Phase E day 3 (continued): 3 PRs merged today + A+B hygiene batch.** PR #144 (fitme-story: dev-guide v7.9 readability pass + /framework card v7.9 bump; 2 files +124 / -66) MERGED. PR #473 (FT2: dev-guide v7.9 readability pass on top of PR #464's banner — TL;DR + Glossary + §15 scannable checklist + §15A → §16 promotion + §16 References → §17 renumber; 1 file +137 / -102 across 2 commits) MERGED. **Drift parity now correct:** both FT2 + fitme-story dev-guide H1 read `(v1.0 → v7.9)`. **Empirical Mode B finding:** small chore-branch commits to `docs/architecture/*` pass pre-commit without `--no-verify` — earlier session conservatism around isolated-worktree-required for that path was over-cautious. **A-batch hygiene shipped via PR #474:** A1 PHASE_LIE fix on `framework-f14-f15-dispatch-test-coverage` (documentation sub-phase `in_progress` → `complete`); A2 tracking-drift-check meta-finding promoted to backlog (4/6 items in today's plan turned out to be already-shipped-but-untracked: R6 + UU1 + UU2 + C5 — pattern worth a future `make tracking-drift-check`); A4 daily-checkpoint reality check (cron firing into `.jsonl` cleanly; `.md` table lag noted — W11.b again, not blocking); B1 companion-doc readability pass on `docs/architecture/feature-lifecycle-event-catalog.md` (§0 90-sec tour + §0.5 Glossary, 17 terms); B3 audit substrate dry-run succeeded (sha `52fffa1e...`). Phase E telemetry healthy. |
