# FitMe Continuous Data Integrity & Rollback Plan — 2026-05-14

> **Status:** CURRENT · Opened 2026-05-14 as a sub-doc of [`infra-master-plan-2026-05-12.md`](infra-master-plan-2026-05-12.md)
> **Scope:** The continuous-observability layer that sits *between* the existing 4 enforcement checkpoints (write-time / cycle-time / per-PR / weekly cron), and the platform-baseline rollback mechanism that restores known-good state when integrity degrades.
> **Purpose:** Answer two questions the infra master plan does NOT answer:
> (1) "Between scheduled gate fires, how do we know the framework is still in spec?" — the *continuous* part of data integrity, not the discrete pre-commit / 72h / weekly cadence.
> (2) "When something goes wrong, how do we restore?" — the *rollback* mechanism.
> **Parent docs:**
> [`infra-master-plan-2026-05-12.md`](infra-master-plan-2026-05-12.md) (enforcement docket + v7.9 promotion calendar) ·
> [`test-coverage-master-plan-2026-05-13.md`](test-coverage-master-plan-2026-05-13.md) (per-layer test surface) ·
> [`analytics-master-plan-2026-05-13.md`](analytics-master-plan-2026-05-13.md) (instrumentation observability)
> **Anchor baseline:** `~/Documents/FitTracker2-backups/2026-05-14-analytics-observability-platform-integrity-baseline-2026-05-14/` — frozen 2026-05-14T04:46Z, FT2 commit `2269077`
>
> **⏱️ Refreshed 2026-06-07:** The continuous-observability surfaces this plan specs SHIPPED in the **v7.8.6 cadence batch** (`make integrity-diff` vs anchor, unified `make preflight`, weekly gate-coverage zero-drift scan, daily checkpoint) — closing the 96h drift window. v7.9.1 added **F17 `gate-last-fired.json`** (derived per-gate index → enables the planned v7.10 `GATE_COVERAGE_ZERO` meta-check at O(1)) + the **F-LAUNCHD-DRIFT-EXTENSION** cron-context phantom-finding suppression. Quarterly **Data Freshness Audit #1 = 2026-08-12** (uses the F17 index). Rollback mechanism (`make snapshot-phase` + off-SSD baselines) exercised at the B2 post-v7.9 baseline (2026-05-28) + the v7.9.1 Phase-E-exit baseline.

---

## 0. TL;DR

Today's framework has 4 discrete integrity checkpoints: pre-commit (write-time), 72h cycle (`integrity-cycle.yml`), per-PR (`pr-integrity-check.yml`), and weekly cron (`framework-status-weekly.yml`). Between any two checkpoints there is no mechanical guarantee the framework remains in spec — silent drift can accumulate for up to 168 hours before the weekly cron catches it, and the empirical record (the v7.7 silent-pass, the v7.8.3 PR-cache false-positive incident, the PR #317 Mode B silent-pass) shows that *between-checkpoint drift is the dominant failure mode*.

This plan adds two complementary surfaces:

1. **§2 Continuous Data Integrity** — codify the 3 always-on telemetry streams that already exist (Mechanism A `gate-coverage.jsonl`, Mechanism C session ledgers, Mechanism F membrane-status) as a *continuous integrity contract*. Specify what each stream guarantees, what it doesn't, and the drift-detection protocol that compares live state against the **2026-05-14 platform baseline**.
2. **§3 Platform-Baseline Rollback Mechanism** — codify the saved-snapshot protocol (`make snapshot-phase`) into a *platform-baseline rollback* with explicit decision criteria, step-by-step procedure, and post-rollback verification. The 2026-05-14 baseline is the inaugural anchor; the doc specifies the cadence at which future baselines are taken and when they may be invoked to restore the framework surface.

**Operational consequence:** the v7.9 promotion decision (2026-05-21) gains a documented escape hatch — if the flip causes a regression undetectable by the standard 4 checkpoints, the platform-baseline rollback restores the entire framework surface to the 2026-05-14 anchor in a documented, sha256-verified procedure.

---

## 1. Scope + Relationship to Infra Master Plan

### 1.1 What this plan covers

| Surface | This plan owns? | Owned by |
|---|---|---|
| Pre-commit gates (write-time) | No | [`infra-master-plan-2026-05-12.md`](infra-master-plan-2026-05-12.md) §2 |
| Cycle-time gates (72h) | No | [`infra-master-plan-2026-05-12.md`](infra-master-plan-2026-05-12.md) §2 |
| Per-PR `pr-integrity-check.yml` | No | CLAUDE.md "Per-PR + weekly defenses" |
| Weekly cron `framework-status-weekly.yml` | No | CLAUDE.md "Per-PR + weekly defenses" |
| Mechanism A `gate-coverage.jsonl` emission | No (lives in `check-state-schema.py`) | [`infra-master-plan-2026-05-12.md`](infra-master-plan-2026-05-12.md) §2.4 |
| **Mechanism A *interpretation* + drift detection between cycles** | **Yes** (§2.2 + §2.3) | This plan |
| Mechanism C session-ledger emission | No (lives in `observe-cache-hit.py`) | v7.8 bridge spec |
| **Mechanism C *coverage gap surfacing* (Reads without state.json updates)** | **Yes** (§2.2) | This plan |
| Mechanism F membrane-status emission | No (lives in `membrane-status.py`) | v7.8 bridge spec |
| **Continuous integrity targets per layer** | **Yes** (§2.4) | This plan |
| `make snapshot-phase` mechanism | No (lives in `snapshot-phase-completion.sh`) | v7.8.3 Phase 0 |
| **Platform-baseline rollback protocol** | **Yes** (§3) | This plan |
| Per-gate flip rollback (advisory ↔ enforced) | No | [`infra-master-plan-2026-05-12.md`](infra-master-plan-2026-05-12.md) §2.2 criterion 4 |
| Per-feature state.json restore | No (mechanism exists in `make snapshot-phase`) | Operator's manual choice; §3.6 covers brief invocation |
| Framework version rollback (v7.9 → v7.8) | No | [`infra-master-plan-2026-05-12.md`](infra-master-plan-2026-05-12.md) §2.2 criterion 4 |

### 1.2 Why this is a sub-doc, not a section in the infra plan

The infra master plan is *forward-looking* — it ranks v8.x candidates and calendars v7.9 promotion. This plan is *operational* — it documents a contract on the *current* system (the 4 enforcement checkpoints + 3 telemetry streams + the snapshot protocol) and the rollback procedure for when that contract is violated. The two have different shelf lives: the infra plan is rewritten every quarter; this plan is updated when the contract changes (e.g., when v7.9 promotes a gate or when a new telemetry stream is added).

### 1.3 What this plan does NOT cover

- **Application-layer test discipline** — sub-doc'd in [`test-coverage-master-plan-2026-05-13.md`](test-coverage-master-plan-2026-05-13.md)
- **Analytics instrumentation drift** — sub-doc'd in [`analytics-master-plan-2026-05-13.md`](analytics-master-plan-2026-05-13.md)
- **Per-feature state.json forensics** — handled ad-hoc by `/pm-workflow` resume + per-feature snapshots
- **CI infrastructure failure recovery** (GitHub Actions queue drops, runner outages) — Ops domain, not framework
- **Repository corruption** (`.git` damage) — handled by git mechanics, not framework

---

## 2. Continuous Data Integrity

### 2.1 The 4-checkpoint enforcement model — what exists today

| Checkpoint | Cadence | Coverage | Source |
|---|---|---|---|
| Write-time pre-commit hook | Every commit | 26 gates (see CLAUDE.md "Data Integrity Framework") | `.githooks/pre-commit` |
| 72h cycle-time | Every 72h via `integrity-cycle.yml` | 16 cycle-time check codes against all 70 features + 79 case studies | `.github/workflows/integrity-cycle.yml` |
| Per-PR integrity bot | Every PR HEAD | schema-check + integrity-check + measurement-adoption vs `origin/main` baseline | `.github/workflows/pr-integrity-check.yml` |
| Weekly framework status | Mondays 05:00 UTC | Appends measurement-adoption snapshot; opens issue on regression | `.github/workflows/framework-status-weekly.yml` |

**The gap:** between a Monday weekly snapshot and the next 72h cycle, up to **96 hours** can elapse with no full-platform sweep. Pre-commit covers individual writes; per-PR covers individual PRs. Drift that crosses commits (e.g., a state.json edit that bypasses `--no-verify`, a session-ledger key drift like the v7.7 silent-pass) is invisible until one of the periodic checks fires.

### 2.2 The continuous observability layer — 3 always-on telemetry streams

These streams emit on every relevant event (not on a schedule). Together they constitute the *continuous* surface that backs §2.3's drift-detection protocol.

#### 2.2.1 Mechanism A — `gate-coverage.jsonl`

**Source:** [`scripts/check-state-schema.py`](../../scripts/check-state-schema.py) emits `{timestamp, mode, gate, candidates, checked, skipped, skip_reasons}` for every gate evaluation. At 2026-05-14T04:46Z baseline: **2,085 rows / 17 distinct gates**.

**Continuous integrity contract:**
- Every write-time gate emits a row on every fire (success OR failure).
- `candidates > 0 && checked == 0 && skipped == candidates` signals **silent-pass** (the v7.7 incident pattern).
- `candidates == 0` over a 72h window for a gate that should be firing signals **coverage gap** (e.g., a rename drifted the key — the v7.8.5 cache_hits keying patch).

**Failure modes detected:**
- Silent-pass class — every gate skipping every candidate (the bug PR #317 fixed)
- Coverage-zero class — the cache_hits keying drift that triggered v7.8.5

#### 2.2.2 Mechanism C — `.claude/logs/_session-<id>.events.jsonl`

**Source:** `PostToolUse:Read` hook in [`.claude/settings.json`](../../.claude/settings.json) → [`scripts/observe-cache-hit.py`](../../scripts/observe-cache-hit.py). Per-session Read attribution. At 2026-05-14T04:46Z baseline: **1,258 events across 27+ session files**.

**Continuous integrity contract:**
- Every `Read` tool call against a file under `/Volumes/DevSSD/FitTracker2/` attributes to the active feature (from `.claude/active-feature`).
- Sessions attributing ≥50 Reads to a feature whose `state.json::cache_hits[]` is empty fire `CACHE_HITS_AUTO_INSTRUMENTATION_INACTIVE` advisory.

**Today's advisory backlog:** 2 features tripping this — `3d-interactive-framework-flow-diagram` (73 attributed Reads) + `analytics-observability` (114 attributed Reads). Both expected at advisory phase; v7.9 promotion will determine whether to enforce.

#### 2.2.3 Mechanism F — `make membrane-status`

**Source:** [`scripts/membrane-status.py`](../../scripts/membrane-status.py). On-demand readout of active feature, recent gate firings, lease state, branch context. **Surfaced via SessionStart hook** — every new session sees the membrane state automatically.

**Continuous integrity contract:**
- A session that opens with `Active leases: 0` while `.claude/active-feature` is non-empty signals **stale lockfile** (the pattern memory addressed in v7.8.4 cleanup).
- A session that opens with multiple leases on the same feature signals **concurrent-dispatch lease drift** (an F6–F9 reproducer condition).

### 2.3 Drift Detection Protocol — baseline-vs-current comparison

**The core protocol:** at any moment, an operator can run `make integrity-diff` (proposed, see §5 Open Questions) to compare the current platform telemetry surface against the **2026-05-14 baseline snapshot**. Until that target ships, the manual procedure is:

```bash
# 1. Diff today's integrity output vs the baseline
BASELINE=~/Documents/FitTracker2-backups/2026-05-14-analytics-observability-platform-integrity-baseline-2026-05-14
diff <(make -C /Volumes/DevSSD/FitTracker2 integrity-check 2>&1) \
     $BASELINE/platform-baseline/integrity-check-output.txt

# 2. Diff today's measurement-adoption vs the baseline
diff <(make -C /Volumes/DevSSD/FitTracker2 measurement-adoption 2>&1) \
     $BASELINE/platform-baseline/measurement-adoption-output.txt

# 3. Diff today's documentation-debt vs the baseline
diff <(make -C /Volumes/DevSSD/FitTracker2 documentation-debt 2>&1) \
     $BASELINE/platform-baseline/documentation-debt-output.txt

# 4. Diff a specific feature's state.json vs the baseline
tar -xzOf $BASELINE/platform-baseline/all-features-state-json.tar.gz \
    .claude/features/<feature>/state.json | \
  diff /Volumes/DevSSD/FitTracker2/.claude/features/<feature>/state.json -
```

**Drift classification:**

| Diff signal | Severity | Disposition |
|---|---|---|
| `Findings: 0 + 4 advisory` → `Findings: 0 + N advisory` where N > 4 | LOW | Investigate new advisory; usually expected as features advance phases. |
| `Findings: 0 + ... advisory` → `Findings: ≥1 + ...` | **HIGH** | A previously-passing gate is now firing as enforced. Investigate immediately. |
| `fully_adopted: 3` decreases | **HIGH** | Measurement regression. Open `framework-status` issue. |
| `post_v6_features` total decreases | **HIGH** | A feature was deleted or framework_version regressed. |
| Mechanism A: gate count drops to 0 for a previously-emitting gate | **CRITICAL** | Silent-pass or coverage drift (v7.7 / v7.8.5 pattern). Triage in <24h. |
| `state_owner` field disappears on any feature | **CRITICAL** | v7.8.3 schema regression. |

### 2.4 Daily Integrity Checkpoint — automated continuous protocol

§2.3 is the *manual* drift-detection protocol. The automated counterpart is `scripts/daily-integrity-checkpoint.py`, which runs the full §2.3 telemetry capture daily and appends one row to `.claude/shared/integrity-checkpoint-ledger.jsonl` with auto-detected regression vs the previous row.

**Three trigger mechanisms (all idempotent; safe to overlap):**

| Trigger | Cadence | Install | Notes |
|---|---|---|---|
| SessionStart hook | First session of each calendar day | Already wired into [`.claude/settings.json`](../../.claude/settings.json) via [`scripts/session-start-checkpoint.sh`](../../scripts/session-start-checkpoint.sh) | Runs detached in background; session start is not blocked. Disable with `CLAUDE_DISABLE_DAILY_CHECKPOINT=1`. |
| launchd cron | Daily 06:00 local time | `make install-daily-cron` (operator-driven; modifies `~/Library/LaunchAgents/`) | Fires even when no Claude Code session is open. Template at [`infrastructure/launchd/com.fittracker.daily-integrity-checkpoint.plist.template`](../../infrastructure/launchd/com.fittracker.daily-integrity-checkpoint.plist.template). |
| Manual | On demand | `make daily-checkpoint` (idempotent) or `make daily-checkpoint-force` (overwrite) | For post-rollback verification, post-merge sanity checks, ad-hoc forensics. |

**What each fire captures (identical to the 2026-05-14 platform baseline structure, §3.1):** all 6 `make` readouts, all shared ledgers, all 70 features' state.json (tarball), Mechanism A summary (17 gates × N rows), Mechanism C event count, git context for both repos, sha256 manifest. Written to BOTH locations:

- **Local internal:** `~/Documents/FitTracker2-backups/daily/YYYY-MM-DD/`
- **SSD sibling:** `/Volumes/DevSSD/FitTracker2-snapshots/YYYY-MM-DD/` (outside the repo, sibling to it)

**Dual-write trade-off:** the SSD copy lives on the hardware-flaky DevSSD per documented [drive-risk convention](../../trust/audits/devssd-disconnect-remediation.md) (memory: DevSSD remediation 2026-05-02). Local is the **authoritative** copy; SSD is the secondary (faster access from anywhere, but may be missing if DevSSD was unmounted at checkpoint time). The script handles SSD-write failure gracefully — logs warning, sets `snapshot_ssd_ok: false` in the ledger row, continues with local-only.

**Ledger structure:**

- **Machine-readable:** [`.claude/shared/integrity-checkpoint-ledger.jsonl`](../../.claude/shared/integrity-checkpoint-ledger.jsonl) — append-only; one JSON row per daily checkpoint with `{date, ft2_commit, fitme_story_commit, metrics{...}, regression, deltas_vs_prev, snapshot_local, snapshot_ssd, snapshot_local_ok, snapshot_ssd_ok}`.
- **Human-readable:** [`.claude/shared/integrity-checkpoint-ledger.md`](../../.claude/shared/integrity-checkpoint-ledger.md) — auto-regenerated on every checkpoint; most-recent-first 16-column comparison table (Date · FT2 commit · Findings · Advisory · Debt · Blocking · Adopt% · Per-phase% · Cache% · CU% · Gates · M-C events · Regression · Local · SSD).

**Regression detection logic** (`detect_regression()`):

- Higher-is-worse delta on `integrity_findings`, `completeness_blocking`, `doc_debt_open` → regression
- Lower-is-worse delta on `fully_adopted_post_v6`, `adoption_pct_post_v6` → regression
- `gate_coverage_distinct_gates` dropping → regression (silent-pass class, the v7.7 / v7.8.5 pattern)

On regression, the script writes `.claude/shared/integrity-checkpoint-regression.flag` containing the deltas + previous-date pointer. The SessionStart hook surfaces this flag at every session start until cleared (cleared automatically when the next checkpoint shows no regression).

**Inspection commands:**

```bash
make daily-checkpoint                  # Idempotent: skip if today's already done
make daily-checkpoint-force            # Overwrite today's row + snapshot
make ledger                            # `less` the rendered .md ledger
make install-daily-cron                # One-shot opt-in: install launchd plist
make uninstall-daily-cron              # Reverse the above
```

### 2.5 Continuous integrity targets per layer

| Layer | Target | Measurement | Baseline (2026-05-14) |
|---|---|---|---|
| Write-time gate firings | ≥95% of post-v6 features hit ≥1 gate per phase transition | Mechanism A coverage stream | 17 distinct gates emit; 8 universal gates at 196 fires |
| Cycle-time advisory count | ≤6 advisory; 0 enforced findings | `make integrity-check` | 0 enforced + 4 advisory |
| Documentation-debt items | ≤1 open advisory; 0 enforced | `make documentation-debt` | 1 advisory (grandfathered `kill_criteria_resolution × 61`) |
| Measurement adoption (post-v6) | `per_phase_timing ≥80%` | `make measurement-adoption` | 80.6% ✅ |
| Measurement adoption (post-v6) | `cache_hits ≥50%` | `make measurement-adoption` | 52.8% ✅ |
| Measurement adoption (post-v6) | `cu_v2 ≥50%` | `make measurement-adoption` | 19.4% ❌ chronic |
| Measurement adoption (fully) | `fully_adopted_post_v6 / post_v6 ≥10%` | `make measurement-adoption` | 8.3% ❌ degraded from 27.3% on 2026-04-30 |
| Branch-isolation gate | 70/70 features clean | `make verify-isolation` | 70/70 ✅ |
| Mechanism C session events | ≥0 (no minimum; capture-only) | session-ledger row count | 1,258 ✅ |
| Mechanism F membrane | 1 active lease per active feature | `make membrane-status` | 1 ✅ |

**Regression definition:** a target degrading vs the 2026-05-14 baseline column by more than the natural noise floor is a §2.3 HIGH/CRITICAL drift signal — **measured on the cohort-normalized / numerator basis, NOT the raw percentage** (§2.6). A *percentage* target (`per_phase_timing`, `cache_hits`, `cu_v2`, `fully_adopted_post_v6 / post_v6`) falling purely because the corpus grew is **denominator dilution, not a regression**; it gates only when the cohort-intersection delta is negative OR the absolute numerator decreased. Adoption targets are evaluated on *presence* but reported with an **instrumented-vs-derived split** (§2.6); a value backfill-*derived* after the fact is not counted as instrumented.

---

## 2.6 Dilution-Normalized Drift Comparison (the normalization overlay)

**Added 2026-06-10** (honesty ledger [FT2-FH-004](../../docs/case-studies/framework-honesty-ledger.md)). The §2.3 drift table and §2.5 regression definition were originally **dilution-blind**: they compared raw counts/percentages against the 2026-05-14 column with no rule for "the % fell purely because the corpus grew." When 34–36 features were added between captures, every percentage target diluted and `make integrity-diff` raised **phantom regressions** (`timing_wall_time` −23.3pp, `cache_hits` −13.4pp on 2026-06-10) even though the underlying numerators were flat-or-up.

**The overlay (non-superseding).** The 2026-05-14 anchor **stays canonical** (§3.2 authorizes new baselines only at daily / framework-promotion / pre-research triggers; this is none of those). Instead of moving the anchor, a normalization layer *attunes to the difference*:

- **`make integrity-multi-anchor`** ([`scripts/integrity-multi-anchor.py`](../../scripts/integrity-multi-anchor.py)) reports, per dimension, three views vs the canonical anchor: **RAW %** (dilution-sensitive), **COHORT %** (features present at both anchors — apples-to-apples), and **absolute NUMERATOR**, plus explicit dilution attribution (how many new features carry each metric).
- The single-sourced classifier `classify_delta()` returns a **verdict**: `REAL_REGRESSION` (cohort Δ<0 OR numerator Δ<0) · `dilution` (raw Δ<0 but cohort Δ≥0 and numerator Δ≥0) · `improved` · `flat`.
- **`make integrity-diff`** still prints raw deltas vs 2026-05-14 (transparent — hides nothing) but its **regression verdict / `EXIT_ON_REGRESSION`** now consumes `classify_delta`, so CI trips only on `REAL_REGRESSION`; dilution deltas are annotated inline. `scripts/daily-integrity-checkpoint.py::detect_regression()` is likewise dilution-aware (a `%`-drop gates only when the absolute `fully_adopted_post_v6` numerator also fell).
- **Provenance split.** `make measurement-adoption` reports each dimension as `present (instrumented + derived)`; `make integrity-multi-anchor --instrumented-only` gives the strict T1 view (derived backfills dropped) so a corrective backfill can never masquerade as contemporaneous instrumentation.

**Worked example (2026-06-10):** vs the 2026-05-14 canonical anchor, `cache_hits` raw fell 28.6%→27.9% but cohort rose 28.6%→31.4% with numerator 20→29 → verdict `dilution`, **not** a regression. All four dimensions: zero `REAL_REGRESSION`.

**§2.3 drift-table addendum:**

| Diff signal | Severity | Disposition |
|---|---|---|
| A percentage target drops, but `classify_delta` verdict is `dilution` (cohort Δ≥0 ∧ numerator Δ≥0) | LOW / expected | Denominator dilution from corpus growth. Not a regression; record the dilution note. |
| A percentage/numerator target drops with verdict `REAL_REGRESSION` (cohort Δ<0 ∨ numerator Δ<0) | **HIGH/CRITICAL** | Real adoption loss on the shared cohort. Investigate immediately. |

## 2.7 Unified Telemetry Data-Layer (read-only OLAP)

**Added 2026-06-10.** [`scripts/integrity-data-lake.py`](../../scripts/integrity-data-lake.py) (`make integrity-data-lake`) is the single read-only entry point that **layers ALL telemetry** — state corpus, Mechanism A `gate-coverage.jsonl`, daily/weekly crons, F17 `gate-last-fired.json`, adoption history, anchors, and daily snapshots (local + SSD) — normalizes each to tabular rows, joins on time / feature / gate axes, and emits:

1. **Source inventory** — row counts per source (drift in any count is itself a signal).
2. **Cross-source reconciliation** — consistency checks that auto-surface drift: e.g. **R1** weekly `distinct_gate_count` vs F17 index vs `gate-coverage.jsonl` (catches the 2026-05/06 *weekly-reports-0-gates-while-index-has-25* anomaly as HIGH); **R3** corpus-growth dilution attribution; **R4** snapshot local-vs-SSD parity; **R5** F17 zero-candidate gates (mis-wire class, cross-ref `GATE_COVERAGE_ZERO`).
3. **Dilution-normalized adoption** vs the canonical anchor (reuses §2.6 `classify_delta`).
4. **Forward-decision digest** — calibration ladder + ranked anomalies.

**Engine:** stdlib-first (zero deps). Optional **DuckDB** backend (`--sql`) registers the normalized tables as SQL views — a *local* analytical layer (SQL-over-files, zero data egress). It is deliberately **not** cloud BigQuery: the ledgers are framework-internal and uploading them to GCP would be needless external egress. Read-only / observability — no enforcement, no writes to any source (non-superseding). CI: `make integrity-data-lake EXIT_ON_ANOMALY=1` exits 2 on a HIGH/CRITICAL finding.

---

## 3. Platform-Baseline Rollback Mechanism

### 3.1 What a platform baseline contains

A platform baseline is a frozen point-in-time copy of the *entire framework surface*. It is created via `make snapshot-phase PHASE=<id> FEATURE=<active-feature>` plus the platform-baseline augmentation procedure documented in `~/Documents/FitTracker2-backups/2026-05-14-.../MANIFEST.md`. The 2026-05-14 baseline contents:

```
2026-05-14-analytics-observability-platform-integrity-baseline-2026-05-14/
├── CHECKSUMS.sha256                          # sha256 of every file below
├── MANIFEST.md                               # operator-facing description + restore guidance
├── analytics-observability.log.json          # per-feature default: active-feature log
├── state.json                                # per-feature default: active-feature state
└── platform-baseline/                        # system-wide augmentation
    ├── active-feature                        # lockfile at snapshot time
    ├── agent-leases.json                     # Mechanism F lease registry
    ├── all-features-state-json.tar.gz        # all 70 .claude/features/*/state.json
    ├── documentation-debt.json               # Tier 3.2 ledger
    ├── documentation-debt-output.txt         # verbatim `make documentation-debt`
    ├── feature-completeness-audit-output.txt # verbatim `make feature-completeness-audit`
    ├── fitme-story-git-log-last-20.txt       # cross-repo git context
    ├── ft2-git-log-last-20.txt               # repo git context
    ├── gate-coverage-last-200.jsonl          # last 200 Mechanism A telemetry rows
    ├── gate-coverage-summary.json            # 17-gate aggregated fire counts
    ├── integrity-check-output.txt            # verbatim `make integrity-check`
    ├── measurement-adoption.json             # Tier 1.1 ledger (current)
    ├── measurement-adoption-history.json     # 10 trend snapshots
    ├── measurement-adoption-output.txt       # verbatim `make measurement-adoption`
    ├── membrane-status-output.txt            # verbatim `make membrane-status`
    └── verify-isolation-output.txt           # verbatim `make verify-isolation`
```

**Size:** 320 KB compressed. **Verification:** `shasum -a 256 -c CHECKSUMS.sha256` from the snapshot directory.

### 3.2 Baseline cadence — when to snapshot

A platform baseline is taken at any of these triggers:

1. **Daily (automated)** — `scripts/daily-integrity-checkpoint.py` fires via SessionStart hook (first session of the day) AND optionally via launchd cron at 06:00 local. Writes to local + SSD with full sha256 + metrics row in the ledger. See §2.4.
2. **Framework version promotion** (mandatory) — every v7.x → v7.y or v7.x → v8.0 promotion takes a baseline at T+0 (just before the flip) AND T+7d (post-flip soak). The 2026-05-14 baseline is the **pre-v7.9 anchor**; a corresponding post-v7.9 baseline will be taken on 2026-05-28 (T+7d after 2026-05-21).
3. **Pre-research-build start** (mandatory) — every HADF, ORCHID, or similar multi-week research campaign takes a baseline before Phase A start. Pre-v7.9 baseline (2026-05-14) doubles as the pre-HADF-Phase-2-bis-Block-B anchor (Block B starts 2026-05-23).
4. **Manual operator trigger** (advisory) — any operator who anticipates a high-risk session can take an ad-hoc baseline via `make daily-checkpoint-force`.
5. **Auto-trigger on regression** (future, §5) — proposed: a regression detector that auto-takes a baseline on the FIRST detected §2.3 HIGH/CRITICAL signal. Partial implementation already exists — the daily-checkpoint writes a `regression.flag` file when deltas exceed thresholds; full auto-baseline-on-regression remains future work.

**Retention:** baselines accumulate at `~/Documents/FitTracker2-backups/` (internal Mac storage, NOT DevSSD per drive-risk convention). No automatic pruning — the operator decides when to delete an old baseline. Today's set:

```
~/Documents/FitTracker2-backups/
├── 2026-05-07-pre-roadmap-stress-test/           # pre-stress-test anchor
├── 2026-05-08-hadf-preservation/                  # n=700 raw HADF dataset preservation
├── 2026-05-11-v7.8.3-execution-pause-task-0.2-complete/
├── 2026-05-11-v7.8.3-pause-phase-0-pr-open/
├── 2026-05-12-framework-v7-8-branch-isolation-pre-v7-9-baseline/  # earlier baseline; superseded
├── 2026-05-13-ssd-migration/                      # cross-machine handoff prep
└── 2026-05-14-analytics-observability-platform-integrity-baseline-2026-05-14/  # CURRENT anchor
```

### 3.3 Rollback decision criteria — when to invoke

A platform-baseline rollback is invoked only when ALL of these hold:

1. **Multiple §2.3 HIGH/CRITICAL drift signals** fire simultaneously OR
2. **A single §2.3 CRITICAL signal** fires AND the root cause is not isolable to a single feature/PR within 1 hour of investigation
3. The drift is **not reversible by a simple `git revert`** (e.g., the framework version itself promoted, multiple PRs landed, schema changes accumulated)
4. The operator confirms the baseline being rolled back to is **still semantically valid** (e.g., not so stale that 50% of features didn't exist yet)

**Rollback IS NOT invoked for:**
- Single-feature corruption — use a per-feature snapshot or `git checkout <feature-file>`
- A failed promotion — flip the gate back to advisory (5-min reversibility, infra plan §2.2 criterion 4)
- A failed PR — use `gh pr close` + `git revert`
- A failed test — fix the test
- Documentation drift — fix the doc

**Rollback IS invoked for:**
- Compound framework regression where multiple gates simultaneously emit incorrectly
- Schema drift across many features (the v7.8.3 `created` → `created_at` migration failure would have qualified pre-merge)
- Mechanism A telemetry corruption that invalidates the calibration data feeding a promotion decision
- Catastrophic concurrent-dispatch state.json corruption (the F6–F9 reproducer pattern)

### 3.4 Rollback procedure — step-by-step

**Estimated wall time: 15–30 minutes.** Procedure assumes operator authorization is obtained beforehand.

```bash
# === Pre-rollback ===

# 1. Verify the baseline checksums first — do not roll back to a corrupted baseline.
BASELINE=~/Documents/FitTracker2-backups/2026-05-14-analytics-observability-platform-integrity-baseline-2026-05-14
cd "$BASELINE"
shasum -a 256 -c CHECKSUMS.sha256
# All files must report "OK". If any report "FAILED", STOP and investigate.

# 2. Take a "pre-rollback evidence" snapshot of the current corrupted state — for forensics.
cd /Volumes/DevSSD/FitTracker2
make snapshot-phase PHASE=pre-rollback-evidence-$(date -u +%Y-%m-%dT%H%MZ) FEATURE=$(cat .claude/active-feature)

# 3. Confirm no uncommitted changes the operator wants to keep.
git status --porcelain
# If any of these are intentional work-in-progress, stash or commit them first.

# === Rollback ===

# 4. Restore all 70 state.json files from the baseline.
cd /Volumes/DevSSD/FitTracker2
tar -xzf "$BASELINE/platform-baseline/all-features-state-json.tar.gz"
# This overwrites .claude/features/*/state.json from the tarball.

# 5. Restore the shared ledgers from the baseline.
cp "$BASELINE/platform-baseline/measurement-adoption.json"         .claude/shared/measurement-adoption.json
cp "$BASELINE/platform-baseline/measurement-adoption-history.json" .claude/shared/measurement-adoption-history.json
cp "$BASELINE/platform-baseline/documentation-debt.json"           .claude/shared/documentation-debt.json
cp "$BASELINE/platform-baseline/agent-leases.json"                 .claude/shared/agent-leases.json

# 6. Restore the active-feature lockfile.
cp "$BASELINE/platform-baseline/active-feature" .claude/active-feature

# 7. Mechanism A gate-coverage.jsonl is append-only by design — do NOT truncate.
#    The baseline preserved the last 200 rows for forensics only; live stream stays intact.

# === Post-rollback verification ===

# 8. Run the full integrity sweep.
make integrity-check 2>&1 | tee /tmp/post-rollback-integrity.txt
make documentation-debt
make measurement-adoption
make verify-isolation
make membrane-status

# 9. Diff each output against the baseline to confirm restoration.
diff /tmp/post-rollback-integrity.txt "$BASELINE/platform-baseline/integrity-check-output.txt"
# Expected: empty diff. Any difference is a residual issue requiring investigation.

# 10. Commit the rollback on a dedicated branch.
git checkout -b chore/platform-baseline-rollback-$(date -u +%Y-%m-%d)
git add .claude/features .claude/shared .claude/active-feature
git commit -m "chore(framework): platform-baseline rollback to 2026-05-14 baseline

Rollback rationale: <fill in>
Triggering drift signal(s): <fill in §2.3 row(s)>
Pre-rollback evidence snapshot: ~/Documents/FitTracker2-backups/pre-rollback-evidence-...
"
git push -u origin HEAD
gh pr create --title "chore: platform-baseline rollback to 2026-05-14" --body "..."
```

### 3.5 Post-rollback verification

A rollback is **only complete** when all of these report identical to the baseline:

| Check | Command | Expected |
|---|---|---|
| Integrity findings | `make integrity-check` | Same finding count + same advisory IDs as `integrity-check-output.txt` |
| Doc-debt items | `make documentation-debt` | Same `open_debt_items` count + same `coverage` percentages |
| Measurement adoption | `make measurement-adoption` | Same `fully_adopted` + same per-dimension counts |
| Branch isolation | `make verify-isolation` | "All 70 features clean" |
| Membrane status | `make membrane-status` | Same `active features` count + same active-feature value |
| Per-feature state.json | `diff` against tar contents | Empty diff for all 70 features |

If any check diverges, the rollback is **incomplete** — investigate before treating the framework as restored.

### 3.6 Other rollback flavors (brief)

This plan focuses on platform-baseline rollback (per scope decision). The three narrower flavors are documented elsewhere; cross-references for completeness:

| Flavor | When | Procedure source |
|---|---|---|
| **Per-gate flip rollback** | A v7.9-promoted gate causes false positives | [`infra-master-plan-2026-05-12.md`](infra-master-plan-2026-05-12.md) §2.2 criterion 4 (<5-min reversibility) |
| **Per-feature state.json restore** | One feature's state.json is corrupted | `tar -xzOf <baseline>/platform-baseline/all-features-state-json.tar.gz .claude/features/<name>/state.json > .claude/features/<name>/state.json` |
| **Framework version rollback** | v7.9 → v7.8.5 promotion-level regression | Combine per-gate flip rollback (every promoted gate) + CLAUDE.md edit + dev-guide reversion + new cold-start entrypoint. Mentioned in [`infra-master-plan-2026-05-12.md`](infra-master-plan-2026-05-12.md) §2.3 "Side-effects of v7.9 promotion" — reversed |

---

## 4. Operational Calendar + Ownership

### 4.1 Calendar (next 6 weeks)

| Date | Action | Owner | Notes |
|---|---|---|---|
| **2026-05-14** ✅ | Baseline taken (this plan's anchor) | this session | At `~/Documents/FitTracker2-backups/2026-05-14-analytics-observability-platform-integrity-baseline-2026-05-14/` |
| 2026-05-21 | v7.9 promotion decision — pre-flip baseline | operator | Run `make snapshot-phase PHASE=pre-v7-9-flip FEATURE=<active>` + augment per §3.1 |
| 2026-05-23 | HADF Phase 2-bis Block B start — Block-B start baseline | operator | Pre-research-build trigger per §3.2 (2) |
| 2026-05-28 | v7.9 T+7d post-soak baseline | operator | Post-promotion verification anchor per §3.2 (1) |
| 2026-06-04 | v7.10 promotion window opens | (calendar) | Next promotion decision per infra plan §2.2 |
| 2026-06-07 | HADF Phase 2-bis closure baseline | operator | Post-research-build anchor |

### 4.2 Ownership

- **Continuous integrity monitoring (§2):** session operator + automated CI. Mechanism A/C/F emissions need no human; drift detection (§2.3) is on-demand by the operator OR triggered by per-PR / weekly bots.
- **Baseline taking (§3.1–§3.2):** session operator at each calendared trigger; ad-hoc on operator discretion.
- **Rollback invocation (§3.3–§3.5):** **REQUIRES user authorization** — the operator MUST confirm with the human user before invoking. Rollback is destructive to in-flight work and visible to other agents.
- **Rollback procedure execution (§3.4):** assistant agent under operator supervision once authorized.

---

## 5. Open Questions & Future Work

1. ~~**`make integrity-diff` target.**~~ **SHIPPED 2026-05-14** as `make daily-checkpoint` + `.claude/shared/integrity-checkpoint-ledger.jsonl` with auto-detected regression deltas vs prev. The ledger row IS the diff. ~~Remaining gap: a `make integrity-diff <date>` target that compares the live state against an arbitrary historical row.~~ **CLOSED 2026-06-10:** the dilution-normalized multi-anchor comparison (`make integrity-multi-anchor`, §2.6) compares the live state against ALL registered anchors with cohort + numerator views, and `make integrity-data-lake` (§2.7) layers every source into one analysis. Both ship dilution-immune by construction.
2. **Auto-baseline on regression (partial).** §3.2 trigger (5) — auto-snapshot when a §2.3 HIGH/CRITICAL signal first fires. The daily-checkpoint already writes `integrity-checkpoint-regression.flag` on detected deltas (per §2.4); what remains is *augmenting* that flag write with an immediate second snapshot stamped `post-regression-evidence-...` so the corrupt state is forensically preserved before the next day's overwrite. Estimated effort: 30min.
3. **Off-SSD verification (not yet automated).** Daily checkpoints live on internal Mac storage + DevSSD. No scheduled check verifies BOTH directories exist + checksums are valid since the last write. Proposed: weekly cron in `framework-status-weekly.yml` that runs `shasum -c` against the 7 most recent daily snapshots in both locations. Surfaces silent corruption.
4. **Cross-repo baseline scope.** This plan covers FT2 framework state. The fitme-story repo has its own integrity surface (PR-integrity CI + verify-blind-switch). The daily-checkpoint already captures fitme-story's git head context; a future revision should also capture its shared state (any UCC mirror data, the cross-repo gate-coverage stream). Tracked as a v8.x candidate.
5. **State.json schema versioning.** The baseline assumes state.json schema at 2026-05-14 (v7.8.5). Rolling back across a schema migration (e.g., post v8.0) requires either backward-compat in the live code OR a migration script in the rollback procedure. Proposed: tag each baseline with its `state_schema_version` (currently implicit in `framework_version` field).
6. **Pruning policy for daily snapshots.** At 1 daily snapshot per location × 365 days × ~500 KB = ~180 MB/year per location. Acceptable indefinitely on local. On DevSSD (already drive-risk-flagged), accumulation is more concerning. Proposed: keep all dailies for 30 days, then keep weekly-cadence dailies for 90 days, then monthly-cadence dailies forever. Implementation: cron pruner. Estimated effort: 1h.

---

## 6. References

### Parent / sibling docs
- [`infra-master-plan-2026-05-12.md`](infra-master-plan-2026-05-12.md) — Forward-looking framework infra plan; enforcement docket + v7.9 promotion calendar
- [`test-coverage-master-plan-2026-05-13.md`](test-coverage-master-plan-2026-05-13.md) — Per-layer test surface (iOS / web / AI / backend / analytics)
- [`analytics-master-plan-2026-05-13.md`](analytics-master-plan-2026-05-13.md) — Instrumentation observability

### Framework spec sources
- v7.8 bridge: [`docs/superpowers/specs/2026-05-02-framework-v7-8-and-v7-9-bridge-design.md`](../superpowers/specs/2026-05-02-framework-v7-8-and-v7-9-bridge-design.md)
- v7.8.1 branch isolation + closure completeness: [`docs/superpowers/specs/2026-05-07-branch-isolation-out-of-scope.md`](../superpowers/specs/2026-05-07-branch-isolation-out-of-scope.md)
- v7.8.3 cross-repo state sync: [`docs/superpowers/specs/2026-05-11-cross-repo-state-sync-impl-design.md`](../superpowers/specs/2026-05-11-cross-repo-state-sync-impl-design.md)
- v7.8.5 observability layer: [`.claude/integrity/observed-patterns.md`](../../.claude/integrity/observed-patterns.md) + [`.claude/entrypoints/framework-v7-8-4.md`](../../.claude/entrypoints/framework-v7-8-4.md)

### Telemetry sources (live)
- Mechanism A: [`scripts/check-state-schema.py`](../../scripts/check-state-schema.py) → `.claude/logs/gate-coverage.jsonl`
- Mechanism C: [`scripts/observe-cache-hit.py`](../../scripts/observe-cache-hit.py) → `.claude/logs/_session-*.events.jsonl`
- Mechanism F: [`scripts/membrane-status.py`](../../scripts/membrane-status.py) → `make membrane-status`
- Snapshot protocol: [`scripts/snapshot-phase-completion.sh`](../../scripts/snapshot-phase-completion.sh) → `make snapshot-phase`

### Today's report + baseline
- 2026-05-14 platform integrity readout: this session's transcript (not separately persisted)
- 2026-05-14 baseline snapshot: `~/Documents/FitTracker2-backups/2026-05-14-analytics-observability-platform-integrity-baseline-2026-05-14/` (sha256-verified)

### CLAUDE.md anchors
- `## Data Integrity Framework` — Write-time + cycle-time gate inventory
- `## Concurrent Dispatch Hygiene` — F6–F9 blocker context (relevant to §3.3 invocation criteria)
- `## Known Mechanical Limits` — Unclosable gaps doctrine (relevant to §2.4 target setting)
