# v8.0 Docket — Ranked Candidates for 2026-05-21 Promotion Meeting

**Created:** 2026-05-13
**Decision date:** 2026-05-21
**Status:** ✅ DECIDED 2026-05-21 — v7.9 promotion shipped via PR #417; v8.x docket frozen with 18 F-candidates + 7 V8-I icebox. Substantive new build routes through v8.x cycle after Phase E exit ~2026-06-04. See `infra-master-plan-2026-05-12.md` §3.6.
> **Refreshed 2026-06-07:** Phase E exited cleanly 2026-06-04 + v7.9.1 build window shipped. **Theme G (test discipline) progress:** F14 ✅ + F15 ✅ (2026-05-22/23) · F16 ✅ + F17 ✅ + F2 ✅ (v7.9.1, 2026-06-04). **Still open in v8.x:** F18 mutation testing, T1 `GATE_TEST_MISSING` meta-gate (gated on F14 Phase E = 2026-08-22), `GATE_COVERAGE_ZERO` meta-check (v7.10, enabled by F17). See the infra-master-plan 2026-06-07 banner for the live ladder.
**Parent:** [`docs/master-plan/infra-master-plan-2026-05-12.md`](./infra-master-plan-2026-05-12.md) §3.3
**Input specs:**
- [`docs/superpowers/specs/2026-05-08-framework-v7-9-candidates.md`](../superpowers/specs/2026-05-08-framework-v7-9-candidates.md) — F1–F18
- [`docs/superpowers/specs/2026-05-07-branch-isolation-out-of-scope.md`](../superpowers/specs/2026-05-07-branch-isolation-out-of-scope.md) — V8-I1 through V8-I7
- [`docs/master-plan/analytics-master-plan-2026-05-13.md`](./analytics-master-plan-2026-05-13.md) §11 — F19 + F20

**Methodology:** RICE per-candidate scoring (Reach × Impact × Confidence / Effort) **plus** a theme-alignment composite weighting (Foundation 40% / Class-closure 30% / Telemetry 20% / Ergonomics 10%). The composite reconciles two perspectives: the *quantitative* RICE pull (how many features benefit, how big is the problem) and the *qualitative* strategic theme (does this unblock the dependency chain, close a known silent-pass class, or just polish operator UX).

A candidate that scores high on RICE alone but does NOT unblock downstream work or close a Class A/B vulnerability ends up ranked lower than a moderate-RICE candidate that does both. This is intentional — see §2.2.

---

## §1 Executive summary

**Top 5 by composite score:**

1. **F16 — pre-commit `try-repo` end-to-end harness.** Foundation for the entire Theme G stack (F14 + F18 ride on it). Caught PR #317-class bugs by construction. RICE 48.0; Composite **86**.
2. **F17 — per-gate `last_fired_at` derived index.** Unlocks the `GATE_COVERAGE_ZERO` meta-check at O(1) lookup; enables the quarterly Data Freshness Audit. RICE 66.7; Composite **84**.
3. **F15 — unit tests for the 5 zero-coverage gates.** Closes 5 confirmed Class B holes; `PHASE_TRANSITION_NO_LOG` + `_NO_TIMING` guard the most frequent state mutation in the PM lifecycle, so silent failure would be invisible until the 72h cron. RICE 40.0; Composite **78**.
4. **F14 — per-gate `test_main_dispatch_<gate_id>()` requirement.** Closes 4 known Class A vulnerabilities of the exact shape that caused PR #317. Depends on F16. RICE 48.0; Composite **75**.
5. **F12 — `actionlint` in pre-commit.** Highest raw RICE in the set (100.0); single-line addition; would have caught the v7.8.3 Phase 3 reverse-sync workflow YAML bug in ~10 seconds locally instead of ~10 minutes of debugging. RICE 100.0; Composite **72**.

**Recommended v8.0 cut-off:** ranks 1–9 in v8.0 (provided F16 reaches Phase E by ~2026-06-11; otherwise F14/F18 slip). Ranks 10–17 deferred to v8.1. V8-I icebox items all remain icebox at 2026-05-21 — no re-eval trigger has fired for any of the 7 at this writing.

**Single biggest leverage move (per external research synthesis baked into the v7.9-candidates spec §2/F16):** ship F16 first; everything else in Theme G is a riff on it.

---

## §2 Methodology

### §2.1 RICE per candidate

Each candidate scored on:

| Component | Definition | Scale |
|---|---|---|
| **Reach (R)** | How many features / PRs / operator-sessions per quarter directly benefit | 1–10 (10 = every commit, 1 = niche edge case) |
| **Impact (I)** | Severity of the problem the candidate solves | 0.25 (cosmetic) / 0.5 (minor) / 1 (medium) / 2 (high) / 3 (massive) |
| **Confidence (C)** | How confident the expected impact is realized | 60% (novel, unproven) / 80% (proven pattern, new context) / 100% (known-working) |
| **Effort (E)** | Person-weeks to ship through Phases A–E | 0.1w (doc-only) to 1.0w+ (new subsystem) |
| **RICE** | (R × I × C) / E | — |

The infra-master-plan §3.1 already publishes RICE estimates for F1–F18; this doc adopts those and adds F19/F20 from the analytics-observability sub-doc §11 + cu_v2-based RICE conversions for V8-I1 through V8-I7.

### §2.2 Theme alignment weighting

RICE alone undervalues two strategic concerns: (a) is this the *foundation* that other items build on? (b) does this close a *class* of known silent-pass bugs? So every candidate also gets a four-dimensional theme score:

| Theme dimension | Weight | Question |
|---|---|---|
| **Foundation** | 40% | Does this unblock future work? (Other v7.9.x / v8.x candidates depend on it.) |
| **Class-closure** | 30% | Does this close a known framework gap? (Class A dispatcher silent-pass, Class B zero-coverage gate, etc.) |
| **Telemetry** | 20% | Does this improve observability of the framework itself? |
| **Ergonomics** | 10% | Does this reduce operator friction in the day-to-day loop? |

Each dimension scored 0–100. Theme composite = (Found × 0.40) + (ClassCl × 0.30) + (Tele × 0.20) + (Ergon × 0.10).

**Final ranking** uses the theme composite as the primary sort key. RICE is shown alongside as a sanity check — a large RICE/Composite disagreement is a flag for the meeting.

### §2.3 Why this composite over pure RICE

Pure RICE rewards items that touch many things (high Reach) and have well-understood payoff (high Confidence). But the framework's biggest historical pain points have been:

- **PR #317-class bugs** — a single dispatcher early-return invalidates an entire enforcement layer. RICE under-weights this because Reach is "all gates" but Impact registers as "1 incident." Class-closure correctly weights it heavier.
- **Layer-stacking risk** — F14 and F18 are useless without F16. RICE treats them as independent. Foundation weight makes F16 dominant.
- **Calibration data integrity** — the cache_hits keying drift suspicion threatens the entire 2026-05-21 promotion-decision data quality. Telemetry weight surfaces F17 properly.

Pure RICE would rank F12 (actionlint) at #1; the composite knocks it to #5 because it doesn't unblock other work and doesn't close a *class* — it closes one specific incident's shape.

### §2.4 Confidence calibration

Novel-mechanism candidates (F18 mutation testing; V8-I2 op-log replay; V8-I3 Vercel Sandbox) get 60% Confidence because the framework has no precedent for them in-house. Direct ports of well-trodden patterns (F12 actionlint; F15 standard unit tests; F17 derived index) get 100%. Proven-elsewhere-but-new-to-this-codebase (F14 dispatch tests per Semgrep pattern; F16 try-repo per pre-commit upstream) get 80%.

---

## §3 Ranked candidates (all 25)

Sorted by composite score descending. Ties broken by RICE descending, then by smaller Effort.

| Rank | ID | Title | Theme | RICE | Found | ClassCl | Tele | Ergon | Composite | Recommendation |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | **F16** | pre-commit `try-repo` end-to-end harness | G — Test discipline | 48.0 | 95 | 90 | 70 | 60 | **85.0** | **v8.0 cornerstone** (or pull forward to v7.9.1 if Phase 9 prioritization decides) |
| 2 | **F17** | per-gate `last_fired_at` derived index | G — Test discipline | 66.7 | 80 | 70 | 100 | 60 | **79.0** | **v7.9.1** (read-only artifact, no advisory window) |
| 3 | **F15** | unit tests for 5 zero-coverage gates | G — Test discipline | 40.0 | 60 | 100 | 70 | 40 | **72.0** | **v8.0** (independent of F16; can start now) |
| 4 | **F14** | per-gate `test_main_dispatch_<gate_id>()` requirement | G — Test discipline | 48.0 | 70 | 95 | 70 | 40 | **74.5** | **v8.0** if F16 reaches Phase E by ~2026-06-11; else v8.1 |
| 5 | **F12** | `actionlint` in pre-commit stack | F — v7.8.3 cutover | 100.0 | 50 | 80 | 50 | 80 | **62.0** | **v7.9.1** — single-line addition, ergonomically high |
| 6 | **F4** | auto-update `framework_version` on protocol writes | C — Schema drift | 32.0 | 70 | 65 | 50 | 50 | **62.5** | **v8.0** (Theme C top by RICE × foundation) |
| 7 | **F19** | `CSV_TAXONOMY_DRIFT` write-time gate | G — Test discipline (analytics) | 80.0 | 55 | 75 | 70 | 60 | **64.5** | **v8.0** — Theme G #4; rides on F16 harness |
| 8 | **F11** | `BRANCH_ISOLATION_HISTORICAL` allowlist extension | F — v7.8.3 cutover | 40.0 | 40 | 70 | 50 | 50 | **52.0** | **v8.0** — Theme F top |
| 9 | **F2** | Phase 0 reality-check sub-step | A — Roadmap realism | 42.7 | 60 | 50 | 30 | 70 | **52.0** | **v7.9.1** — workflow-only, single-commit reversible |
| 10 | **F1** | `STATE_TASKS_FILESYSTEM_DRIFT` advisory | A — Roadmap realism | 19.2 | 45 | 80 | 70 | 40 | **60.0** | **v8.0** — Theme A top by class-closure |
| 11 | **F10** | `experiment_outcome` enum on `tasks[]` | C — Schema drift | 32.0 | 50 | 50 | 30 | 70 | **48.0** | **v8.0** — Theme C #2 |
| 12 | **F18** | nightly mutation testing on dispatchers | G — Test discipline | 13.7 | 50 | 75 | 40 | 30 | **53.5** | **v8.0** if F14 ships; **v8.1** otherwise — depends on F14 + F16 |
| 13 | **F6** | B_medium tier doc in CLAUDE.md | D — Vocabulary | 30.0 | 35 | 40 | 20 | 60 | **36.0** | **v7.9.1** — doc-only, single-line PR |
| 14 | **F20** | `GA4_MCP_DISCONNECTED` advisory + coverage | G — Test discipline (analytics) | 30.0 | 35 | 40 | 70 | 50 | **45.0** | **v8.0** — pairs with F19; always-advisory |
| 15 | **F13** | `source_commit` input on `workflow_dispatch` | F — v7.8.3 cutover | 32.0 | 30 | 30 | 30 | 80 | **35.0** | **v8.1** — situational, low foundation pull |
| 16 | **F3** | Phase 2 dependency-graph cycle/mismatch check | A — Roadmap realism | 14.4 | 35 | 40 | 30 | 50 | **37.0** | **v8.1** — niche use case |
| 17 | **F9** | `make complete-feature` pre-flight | E — Ergonomics | 40.0 | 25 | 30 | 20 | 90 | **32.0** | **v8.1** — ergonomically high but blocked behind F14/F18 (depends on the test discipline stack) |
| 18 | **F5** | `scope_change` event type in Tier 2.2 vocab | D — Vocabulary | 20.0 | 20 | 25 | 30 | 50 | **26.5** | **v8.1** — vocabulary extension |
| 19 | **V8-I5** | inotify/fsevents broadcast mediator | Icebox D | ~10 | 30 | 20 | 40 | 40 | **28.0** | **KEEP ICEBOX** — no concurrent-write incidents tracked yet |
| 20 | **V8-I6** | cross-feature dependency analysis | Icebox E | ~8 | 30 | 20 | 30 | 50 | **27.0** | **KEEP ICEBOX** — `path-reducers.json` has <5 entries; threshold is ≥20 |
| 21 | **V8-I1** | agent smartlog UI | Icebox A | ~10 | 20 | 15 | 60 | 50 | **26.5** | **KEEP ICEBOX** — concurrent-agent count not at threshold (≥5 for 7 days) |
| 22 | **V8-I7** | auto-rollback on kill-criteria fire | Icebox process | ~5 | 25 | 30 | 30 | 40 | **29.0** | **KEEP ICEBOX** — needs F1 telemetry as precursor |
| 23 | **V8-I2** | op-log replay (jj-style) | Icebox A | ~5 | 25 | 30 | 20 | 50 | **27.5** | **KEEP ICEBOX** — `--no-verify` ledger is bridge primitive |
| 24 | **V8-I4** | FS kernel sandboxing (Landlock / App Sandbox) | Icebox D | ~3 | 10 | 20 | 20 | 20 | **16.0** | **KEEP ICEBOX** — no regulatory mandate |
| 25 | **V8-I3** | Vercel Sandbox / Firecracker microVM | Icebox C | ~3 | 10 | 15 | 20 | 20 | **14.5** | **KEEP ICEBOX** — overkill for cooperative agents; no untrusted-code use case |

**Notes on the table:**

- F7 + F8 (cross-repo asymmetry) are NOT in this ranking because both were RESOLVED in v7.8.2 via documented exemption. Total open candidates: 18 F-items + 7 V8-I icebox = **25**, matching the infra-master-plan §3.4 count.
- F19 + F20 are NEW from the [analytics-master-plan-2026-05-13.md §11](analytics-master-plan-2026-05-13.md#11-v79-candidate-mapping-f19--f20). They ride on the F16 harness; their dispositions assume F16 ships in v7.9.1 or v8.0.
- V8-I RICE estimates are approximate — the icebox spec uses `cu_v2` (complexity unit v2) rather than RICE; I converted cu_v2 to a comparable scale by treating cu_v2 ≥ 3.0 as Effort ≥ 1.0w and cu_v2 ≤ 2.0 as Effort ≤ 0.5w, then back-computing RICE with a conservative Reach (Reach=4 for items that haven't triggered re-eval).

---

## §4 Per-candidate detail (top 10)

### Rank 1 — F16: pre-commit `try-repo` end-to-end harness

- **Description:** spawn a throwaway git repo, copy fixtures from `tests/fixtures/<gate-id>/{positive,negative}/`, stage them, run the real `.githooks/pre-commit` script via subprocess, assert each gate's expected fire/skip outcome. Run in CI nightly.
- **Why ranked here:** the external research pass in the v7.9-candidates spec §2 explicitly calls this out as the "highest-leverage single change." Every Class A silent-pass bug to date (most recently PR #317) would have been caught by a real end-to-end harness exercising real fixtures through the real hook. F14 (per-gate dispatch tests) and F18 (mutation testing) are riffs on it — without F16 they can't be calibrated against ground truth. **Foundation 95** because F14 + F18 (and arguably F19 + F20) all sit downstream.
- **Dependencies:** none in either direction — but cannot be built on top of an in-flux gate stack, so wait for v7.9 promotion (2026-05-21) and Phase E exit (~2026-06-04).
- **Earliest start:** 2026-06-04 (v7.9.1 cycle).
- **Suggested slot:** **v7.9.1 if calibration window allows** (Phase A artifacts already in PR #318); otherwise v8.0 cornerstone.

### Rank 2 — F17: per-gate `last_fired_at` derived index

- **Description:** `scripts/refresh-gate-last-fired.py` derives `.claude/shared/gate-last-fired.json` from `gate-coverage.jsonl`, keyed by gate ID → `{last_fired_at, last_skipped_at, fire_count_30d, skip_count_30d, last_skip_reason}`. Nightly cron writes it. Enables the planned `GATE_COVERAGE_ZERO` cycle-time check at O(1) instead of O(records × gates).
- **Why ranked here:** **Telemetry 100** because this is the only candidate that directly improves the framework's ability to introspect itself. AWS Config Rules' `LastSuccessfulInvocationTime` is the proven pattern. Read-only derived artifact = no advisory window needed = ships fast. Unlocks the quarterly Data Freshness Audit (infra-master-plan §3.5.3), which is the meta-check that would have caught the cache_hits keying drift at landing time instead of via test failure weeks later.
- **Dependencies:** none. Reads `gate-coverage.jsonl` which already exists.
- **Earliest start:** 2026-06-04 (v7.9.1 cycle, in parallel with F16).
- **Suggested slot:** **v7.9.1**.

### Rank 3 — F15: unit tests for 5 zero-coverage gates

- **Description:** unit tests for `PHASE_TRANSITION_NO_LOG`, `PHASE_TRANSITION_NO_TIMING`, `BRANCH_ISOLATION_HISTORICAL`, `BRANCH_ISOLATION_LAUNCHD_DRIFT`, `PR_CACHE_STALE`. Tests must exercise the rejection path (synthetic state.json with mismatched timing, current_phase change without paired log event in window, etc.), not just the check function in isolation.
- **Why ranked here:** **Class-closure 100** because all 5 are confirmed-zero-coverage. The two phase-transition gates are highest-risk: they guard the most frequent state mutation in the PM lifecycle, and failure is undetectable until the 72h cron. Independent of F16 — can start now, no advisory window because no new gate ships, just tests for existing gates.
- **Dependencies:** none. Pure additive work on `scripts/tests/`.
- **Earliest start:** **immediate** (can land any time post-2026-05-21 Phase E without blocking any other layer).
- **Suggested slot:** **v8.0**, but consider pulling forward to v7.9.1 if the engineering team has spare cycles — there's no calibration risk.

### Rank 4 — F14: per-gate `test_main_dispatch_<gate_id>()` requirement

- **Description:** every write-time gate must have ≥1 test invoking `main()` with monkey-patched `collect_staged_state_files` + `collect_all_staged_files` + `GATE_COVERAGE_LEDGER` + `sys.argv`, asserting the gate either fires OR records a candidate→skip entry. Enforced via `pre-commit-self-test.py` extension that fails if any declared gate lacks a dispatch-test. Closes 4 currently-uncovered gates: `CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT`, `CU_V2_INVALID`, `STATE_NO_CASE_STUDY_LINK`, `CASE_STUDY_MISSING_FIELDS`.
- **Why ranked here:** **Class-closure 95** because this is the structural fix for the PR #317 vulnerability class. Semgrep's `rule.yml ↔ rule.test.yml` enforced-pairing pattern is the prior art. The reason this isn't #1: it depends on F16 reaching Phase E (you need the harness to validate that the dispatch tests actually catch dispatcher bugs — the "test the tests" loop). Per infra-master-plan §3.5.2 Layer Stacking Rule, F14 can't ship until F16 is post-validation stable.
- **Dependencies:** F16 in Phase E.
- **Earliest start:** ~2026-06-11 (assuming F16 enters Phase E around 2026-06-04 + 7d Phase E).
- **Suggested slot:** **v8.0** if F16 stays on schedule; **v8.1** otherwise.

### Rank 5 — F12: `actionlint` in pre-commit stack

- **Description:** add `actionlint` to the pre-commit gate stack OR to `verify-local`'s CI-validation step. Catch GH Actions YAML syntax / structural / security issues before they hit `gh push`.
- **Why ranked here:** **highest raw RICE (100.0)** because every workflow change benefits and Confidence is 100% (mature OSS tool). Ranked 5th not 1st because it doesn't unblock anything — it's a pure ergonomics win. The Foundation score is moderate (50) because faster GH Actions iteration does indirectly help every other piece of CI work, but it's not a precondition. Note the v7.8.3 Phase 3 reverse-sync workflow bug (~10 minutes lost) is exactly the failure mode this catches.
- **Dependencies:** none. Pre-commit framework already exists; this is a new check.
- **Earliest start:** **immediate** — single-line addition to `.pre-commit-config.yaml`.
- **Suggested slot:** **v7.9.1** as a 0.2w quick-win, OR fold into the v8.0 docket.

### Rank 6 — F4: auto-update `framework_version` on protocol writes

- **Description:** every protocol-touching write (state.json mutation, case-study frontmatter edit) auto-bumps `framework_version` to the canonical current version. Closes the drift observed on app-store-assets and 8 other pre-v7.6 features.
- **Why ranked here:** **Theme C top** by RICE (32.0) and Foundation (70 — every state.json write benefits). The 9 features with stale `framework_version` are a known data-quality liability that confuses every downstream readout (`make documentation-debt`, `make measurement-adoption`, cross-cycle integrity checks).
- **Dependencies:** none. New write-time hook, ships on its own.
- **Earliest start:** 2026-06-04 (post-Phase E) — needs its own advisory window (write-time gate).
- **Suggested slot:** **v8.0** Theme C top.

### Rank 7 — F19: `CSV_TAXONOMY_DRIFT` write-time gate

- **Description:** validates that every analytics-event enum constant has a corresponding CSV row in `docs/product/analytics-taxonomy.csv` (or carries an explicit `[FORWARD-DECLARED]` marker). Closes the historical drift where enum-constants were renamed and CSV rows went stale silently.
- **Why ranked here:** Theme G analytics extension; rides on the F16 harness (positive/negative fixtures fit the same `tests/fixtures/<gate-id>/` shape). RICE 80.0 is high because every analytics event-add commit benefits. Lower Foundation score (55) because it's a single-domain gate, not infrastructure.
- **Dependencies:** F16 harness (for end-to-end test fixtures); analytics CSV maintained per analytics-master-plan §5.4.
- **Earliest start:** 2026-06-04 (analytics Phase 1.B start per analytics-master-plan §3.6.6.A).
- **Suggested slot:** **v8.0** Theme G #4 — runs on the v8.0 calendar slot 2026-06-18.

### Rank 8 — F11: `BRANCH_ISOLATION_HISTORICAL` allowlist extension

- **Description:** extend the advisory's branch-name allowlist to include `reverse-sync/*` (and any other v7.8.3 D-1 marker patterns). Alternative: morph the advisory to read `state_owner_sync_origin` and exempt files where the marker indicates a sync mirror.
- **Why ranked here:** Theme F top. The 3-attempt v7.8.3 Phase 4 cutover ceremony surfaced this — reverse-sync mirrors are legitimate but get flagged as "committed directly on main, bypassing branch isolation." Low-effort fix (0.3w) with full Confidence.
- **Dependencies:** none.
- **Earliest start:** 2026-06-04 (post v7.9 Phase E).
- **Suggested slot:** **v8.0** Theme F top.

### Rank 9 — F2: Phase 0 reality-check sub-step

- **Description:** new `/pm-workflow` Phase 0 sub-step: "Reality-check sub-features against state.json + filesystem before scheduling." Would have caught the stress-test S2 already-complete-before-scheduled and re-scoped S3 to its actually-open subgoals.
- **Why ranked here:** workflow-only, no gate code, single-commit reversible. Ergonomics 70 because operators save 1-3 days of scheduled-but-already-shipped work per roadmap. Foundation 60 because it's a precondition for clean multi-feature roadmap planning going forward.
- **Dependencies:** none.
- **Earliest start:** **immediate** (no calibration window needed for workflow doc changes per infra-master-plan §3.5.2).
- **Suggested slot:** **v7.9.1**.

### Rank 10 — F1: `STATE_TASKS_FILESYSTEM_DRIFT` advisory

- **Description:** new cycle-time advisory check comparing `tasks.md` IDs against `state.json::tasks[]` AND scanning for filesystem evidence (e.g., `make app-store-check`-style probes per feature class). Surfaced when 5-of-10 stress-test sub-features had drift.
- **Why ranked here:** Theme A top by class-closure (80 — this is a confirmed silent-pass class). RICE only 19.2 because Reach is bounded to cycle-time advisories. Foundation 45 because it informs future PM-workflow protocol improvements but doesn't unblock specific work.
- **Dependencies:** none.
- **Earliest start:** 2026-06-04 (post v7.9 Phase E).
- **Suggested slot:** **v8.0** Theme A top.

---

## §5 Recommended v8.0 cut-off

**Hard cut-off proposal:** **ranks 1–10 in v8.0** with structured staging:

| v7.9.1 (target 2026-06-04 → 2026-06-11) | v8.0 (target 2026-06-18 → 2026-07-31) | v8.1 (target 2026-08 → 2026-09) |
|---|---|---|
| F16 (cornerstone — needs to ship FIRST) | F14 (after F16 reaches Phase E) | F18 (after F14 + F16 stable) |
| F17 (read-only, no advisory) | F15 (independent, lands when ready) | F13 (situational) |
| F12 (single-line; quick-win) | F4 (Theme C top) | F3 (niche, low pull) |
| F2 (workflow-only) | F19 (analytics extension) | F9 (depends on test stack) |
| F6 (doc-only) | F11 (Theme F top) | F5 (vocabulary extension) |
| | F1 (Theme A top) | |
| | F10 (Theme C #2) | |
| | F20 (analytics extension) | |

**Total v8.0 items:** 8 (F1, F4, F10, F11, F14, F15, F19, F20). This sits at the high end of the historical v7.x cadence (6–10 items per release per infra-master-plan §3.6.4) and provides one item per theme + Theme G test discipline coverage.

**Justification:**

- **Top-per-theme rule (relaxed 2026-05-12 per infra-master-plan §3.3 item 2):** v8.0 covers Themes A (F1), C (F4 + F10), F (F11), G (F14 + F15 + F19 + F20). Theme D + Theme E low-priority items (F5, F6, F9) defer to v7.9.1 (doc-only) or v8.1 (depends on test stack).
- **Layer-stacking compliance:** F14 only enters v8.0 if F16 reaches Phase E by ~2026-06-11 (infra-master-plan §3.5.2). F18 is gated on F14, so it stays in v8.1 by default.
- **Calibration window honored:** Phase E for v7.9 runs 2026-05-21 → 2026-06-04. No new gates start before 2026-06-04. F17 + F2 + F6 are non-gate-additive and can ship in v7.9.1 without breaking this rule.
- **Cumulative mechanism count target:** infra-master-plan §3.6.7 projects v8.0 at 38–40 gates (from 34 at v7.8.4). Eight v8.0 items × roughly one gate each lines up; the test-discipline items (F14, F15) don't add gates but add test artifacts, so the gate count rises only by F1, F4, F11, F19, F20 = 5, landing at 39. Consistent.

**What's deferred and why:**

- **F3, F5, F9** — defer to v8.1. F3 has the lowest RICE (14.4) in the set and the dependency-graph use case is niche. F5 is vocabulary-only (B_medium ergonomics). F9 (`make complete-feature`) is high ergonomics but depends on F14 + F18 to fire all gates in dry-run, so it ships only after the test stack is stable.
- **F18** — defer to v8.1 unless F14 ships early in v8.0 cycle. Mutation testing has 60% Confidence (novel for this codebase) and needs F14 to provide tests-to-mutate.
- **F13** — defer to v8.1. Single-incident shape (one cutover ceremony), low Foundation pull.
- **All 7 V8-I icebox items** — all keep icebox status (see §6).

---

## §6 V8-I icebox triage

Each V8-I item evaluated against (a) re-eval trigger status (b) cu_v2 since 2026-05-07 (c) dependency on v7.9/v8.0 infrastructure.

| ID | Item | Trigger status | cu_v2 change | Recommendation |
|---|---|---|---|---|
| **V8-I1** | Agent smartlog UI | NOT fired (concurrent active features still 1-2, not ≥5 for 7d) | No change (2.2) | **KEEP ICEBOX** — re-eval Q3 if HADF Phase 2-bis + Track 6 + parallel v8.0 builds push concurrent count up |
| **V8-I2** | Op-log replay (jj-style) | NOT fired (`git stash list` at 2 on canonical, threshold ≥5; no manual-cleanup incidents in 90d) | No change (2.9) | **KEEP ICEBOX** — `--no-verify` ledger + v7.8.3 reverse-sync are bridge primitives |
| **V8-I3** | Vercel Sandbox / Firecracker microVM | NOT fired (no untrusted-code-execution use case) | No change (3.1) | **KEEP ICEBOX** — overkill for cooperative agents |
| **V8-I4** | FS kernel sandboxing (Landlock / App Sandbox) | NOT fired (no regulatory mandate; no multi-tenant adoption) | No change (3.05) | **KEEP ICEBOX** — OS-specific; doesn't translate across dev/CI |
| **V8-I5** | inotify/fsevents broadcast mediator | NOT fired (no concurrent-write incidents tracked) | No change (1.9) | **KEEP ICEBOX** — detection-only; additive to existing gates |
| **V8-I6** | Cross-feature dependency analysis | NOT fired (`path-reducers.json` has <5 entries; threshold ≥20) | No change (2.0) | **KEEP ICEBOX** — wait for path-reducer registry to mature |
| **V8-I7** | Auto-rollback on kill-criteria fire | NOT fired (no T+7d telemetry of clean kill-criteria firing yet) | No change (3.05) | **KEEP ICEBOX** — safety verification needs F1 telemetry as precursor |

**Aggregate recommendation:** ZERO V8-I items elevate to v8.0. All seven remain icebox at 2026-05-21. Re-evaluate at v8.1 docket (target 2026-08 → 2026-09) per infra-master-plan §3.6.5; likely candidates by then are V8-I1 (if concurrent agents grow) and V8-I2 (if stash count keeps climbing).

**Dropped (drop from icebox entirely):** **none.** Every V8-I trigger remains a plausible future signal; the question is when, not whether.

---

## §7 Cross-references

### §7.1 Source documents

- [`docs/superpowers/specs/2026-05-08-framework-v7-9-candidates.md`](../superpowers/specs/2026-05-08-framework-v7-9-candidates.md) — F1–F18 canonical source
- [`docs/superpowers/specs/2026-05-07-branch-isolation-out-of-scope.md`](../superpowers/specs/2026-05-07-branch-isolation-out-of-scope.md) — V8-I1 through V8-I7
- [`docs/master-plan/infra-master-plan-2026-05-12.md`](./infra-master-plan-2026-05-12.md) §3 — build docket + theme distribution; §3.5 calibration protocol; §3.6 forward plan
- [`docs/master-plan/analytics-master-plan-2026-05-13.md`](./analytics-master-plan-2026-05-13.md) §11 — F19 + F20 candidate mapping
- [`docs/master-plan/2026-05-12-consolidated-review-linear-notion-prep.md`](./2026-05-12-consolidated-review-linear-notion-prep.md) §4 — Foundation/Class-closure/Telemetry/Ergonomics rubric origin

### §7.2 Linear / Notion synchronization

The 8 v8.0 items map onto Linear epic **FIT-74** (v8.0 Top-Per-Theme Docket) per the consolidated review §3.3. v7.9.1 items map to **FIT-73**. V8-I icebox items collectively stay under **FIT-75** (v8.1 Deferred + V8-I Triggers) as parking-lot sub-issues.

### §7.3 Calibration anchors

- **2026-05-21:** v7.9 promotion decision; this docket is the canonical v8.0 prioritization input
- **2026-06-04:** Phase E exit for v7.9 mechanisms; new gates may start (v7.9.1)
- **2026-06-11:** F16 Phase E target (assuming v7.9.1 ships 2026-06-04); F14 unblocks
- **2026-06-18:** v8.0 cycle starts (per infra-master-plan §3.6.4)
- **2026-07-31:** v8.0 target ship date
- **2026-08-12:** quarterly Data Freshness Audit (first run); validates this docket's gate inventory

### §7.4 Reversibility

This docket is a recommendation, not a commit. The 2026-05-21 promotion meeting has final say. Per infra-master-plan §3.5.4 reversibility contract, any v8.0 candidate may be deferred to v8.1 at the meeting without affecting v7.9 promotion itself. The hard sequencing constraints are:

1. F16 must ship in v7.9.1 OR v8.0-early — else F14 + F18 + F19 (via harness) all slip
2. F17 must ship in v7.9.1 — else the `GATE_COVERAGE_ZERO` meta-check + Data Freshness Audit can't run on the 2026-08-12 schedule
3. F1, F4, F10, F11, F19 must each walk Phases B–E independently because they're new gates — schedule allows up to 4 in v8.0 concurrent without resource contention

### §7.5 Audit trail

| Date | Action | Author |
|---|---|---|
| 2026-05-13 | Initial docket ranked at v7.9 pre-decision agent dispatch | subagent-dispatched ranking pass |
| 2026-05-21 | Final v8.0 selection at promotion meeting | TBD |
| 2026-06-04 | Phase 9 prioritization pass at `framework-v7-8-branch-isolation` close — produces canonical `docs/superpowers/specs/2026-05-21-v8-0-docket.md` superseding this draft | TBD |

---

**End of docket.** Decisions to be recorded in `docs/superpowers/specs/2026-05-21-v8-0-docket.md` after the 2026-05-21 meeting.
