---
title: HADF Phase 2-bis — Hardened Cloud Replication (design spec)
date_written: 2026-05-11
authors: [regev]
predecessor: docs/case-studies/hadf-phase2-cloud-fingerprinting-case-study.md
successor: TBD (post-Sub-exp-3 synthesis case study)
linear: FIT-71
framework_version: v7.8.3
work_type: Feature
status: design_draft
estimated_wall_clock: 15 days (3 sub-exps × ~5 days each)
estimated_cost_usd: 5_expected_20_ceiling
estimated_records: 9750_nominal_5600_valid_at_50pct_yield
soak_window: 12 days post-v7.8.3 ship; earliest Sub-exp 1 launch 2026-05-23
---

# HADF Phase 2-bis — Hardened Cloud Replication

## §1 Goal + 3 Research Questions

Replicate the HADF Phase 2 cloud fingerprinting result (silhouette 0.5566 at k=5, n=700 valid records via OpenAI gpt-4o-mini, single-day ship, case study at [`docs/case-studies/hadf-phase2-cloud-fingerprinting-case-study.md`](../../case-studies/hadf-phase2-cloud-fingerprinting-case-study.md)) under a hardened harness that closes the 6 incidents catalogued in the Phase 2 retro. Phase 2 answered "can we fingerprint a single cloud endpoint via TTFT/TPS streaming distributions?" — answer YES. Phase 2-bis tests the **generalization** of that result, the **separability** of cloud-vs-local, and the **decisive routing claim** (does the same model identifier behind two providers fingerprint differently?).

| RQ | Question | Sub-exp |
|---|---|---|
| RQ1 | Does the silhouette signature reproduce on cloud endpoints beyond OpenAI direct? | Sub-exp 1 |
| RQ2 | Can we distinguish Ollama-on-M2 from cloud endpoints by signature alone? | Sub-exp 2 |
| RQ3 | Does AWS Bedrock haiku-4-5 fingerprint differently from Anthropic-direct haiku-4-5? (the central HADF claim — same model, different provider, must yield different signatures or the entire HADF dispatch premise fails) | Sub-exp 3 |

**Each sub-experiment ships an independent verdict.** No "wait for all three then synthesize" — Sub-exp 1's verdict stands alone. Sub-exp 2 and 3 launch only if their predecessor passed (kill criteria + verdict gate per §7).

## §2 Endpoint matrix

11 unique endpoints across 8 providers. Sub-exp 3's "anchor" endpoints (openai gpt-4o-mini + anthropic haiku-4-5) re-use Sub-exp 1's endpoints under H1 (anchored carry-forward) for drift detection.

### Sub-exp 1 — Cloud generalization + halfway routing test (9 endpoints, 6 providers)

| Provider | Endpoint | API | Notes |
|---|---|---|---|
| OpenAI | `gpt-4o-mini` | direct | Phase 2 baseline; carries forward as Sub-exp 3 anchor |
| OpenAI | `gpt-4o` | direct | Larger model; tests whether signature scales with model size |
| Anthropic | `claude-haiku-4-5` | direct | Carries forward as Sub-exp 3 anchor (routing test target) |
| Anthropic | `claude-sonnet-4-6` | direct | Larger model |
| Google | `gemini-2-flash` | direct | First non-OpenAI/Anthropic provider |
| Google | `gemini-2-pro` | direct | Larger Google model |
| Vercel AI Gateway | `gpt-4o-mini` | gateway-routed | **Halfway routing test** — same model id, different infrastructure layer |
| Mistral | `mistral-large-latest` | direct | Independent provider |
| xAI | `grok-4-1` | direct | Independent provider |

Nominal: 5 fires/day × 3 days × 9 endpoints × 50 calls = 6,750 records. Expected effective: ~3,375 valid (at Phase 2's 50% yield). Cost: ~$3-4.

### Sub-exp 2 — Cloud-vs-local separability (1 endpoint, 1 provider)

| Provider | Endpoint | API | Notes |
|---|---|---|---|
| Ollama | `llama3.2:3b` | local on M2 | No anchor; local execution doesn't drift across runs (per H1 = Ollama no-anchor decision) |

Nominal: 5 fires/day × 3 days × 1 endpoint × 50 calls = 750 records. Expected: ~375 valid. Cost: $0. Per-call timeout override: 600s (Ollama on M2 has streaming TPS variance the 60s cloud default doesn't accommodate).

### Sub-exp 3 — Decisive same-model routing test (3 endpoints, 3 providers)

| Provider | Endpoint | API | Role |
|---|---|---|---|
| OpenAI | `gpt-4o-mini` | direct | **Anchor** — drift detection vs Sub-exp 1 |
| Anthropic | `claude-haiku-4-5` | direct | **Anchor** — drift detection vs Sub-exp 1 |
| AWS Bedrock | `anthropic.claude-haiku-4-5` | Bedrock | **Routing target** — same model id as Anthropic-direct anchor; if signature differs, HADF claim holds |

Nominal: 5 fires/day × 3 days × 3 endpoints × 50 calls = 2,250 records. Expected: ~1,125 valid. Cost: ~$1.

**Total across all 3 sub-exps:** 9,750 nominal records / ~5,600 valid / ~$5 expected / $20 ceiling / ~15 days wall-clock.

## §3 Architectural fixes — 4 mandatory pre-conditions

All 4 fixes ship before Sub-exp 1 launches. Verification: §9 go/no-go ceremony. The 3 originals close the Phase 2 incident catalog (Fire-1 plist hardcoded path, Fire-8 broken venv, Fire-9 missing keys); Fix #4 closes the 2026-05-08 backup-discovery gap (raw .jsonl was untracked + ungitignored).

| # | Fix | Closes |
|---|---|---|
| 1 | **Worktree-local venv** (real directory at `.venv/` per worktree, NOT a symlink to shared venv) | Fire-8 broken venv — silent fallback to system python led to 100 contaminated records |
| 2 | **Copy `.env.local`** (NOT symlink) into each worktree | Fire-9 missing keys — silent dangling symlink led to 100 contaminated records |
| 3 | **Wrapper preflight self-check** at top of `scripts/hadf-phase2bis-collect.sh` — validates: venv binary executable + every required Python import succeeds + `.env.local` exists as regular file + every required API key non-empty after sourcing. On any failure: log to ledger + `launchctl bootout` + `exit 78` (EX_CONFIG). | Same root incidents as #1 + #2 — gate stops corrupted run before any record lands |
| 4 | **Raw-data preservation** — wrapper writes `.claude/shared/hadf/phase2bis-raw-<subexp>-<run-id>.jsonl` atomically per fire (not per call). `.gitattributes` registers as Mechanism E `union-dedup-by-key` (auto-merge driver). Nightly cron rsync to `~/Documents/FitTracker2-backups/hadf-phase2bis-raw/` (off-SSD). | 2026-05-08 backup-discovery gap — Phase 2's 244 KB n=700 dataset was untracked + ungitignored; only preserved post-hoc |

## §4 Per-call controls + per-sub-exp campaign schedule

### Per-call defaults (T1 lock — same as Phase 2)

| Control | Value | Reason |
|---|---|---|
| Calls per fire | 50 | Phase 2 baseline |
| `max_output_tokens` | 200 | Phase 2 baseline; bounds streaming TPS variance |
| `temperature` | 0.7 | Phase 2 baseline |
| Per-call timeout | 60s (cloud) / **600s (Ollama)** | Cloud rarely exceeds 60s; Ollama on M2 has long streaming runs |
| Streaming required | `true` | Required to measure TTFT + per-token TPS |
| System prompt | none | Eliminates system-prompt variance |
| Tools | none | Eliminates tool-routing variance |
| Prompt | identical seed prompt set (50 prompts, frozen pre-launch) | Eliminates prompt variance |

### Per-sub-exp campaign schedule

5 fires/day at UTC times **02:00, 08:00, 14:00, 18:00, 22:00**. Each fire dispatches all sub-exp endpoints once (50 calls/endpoint). Driven by `launchctl` plist with `StartCalendarInterval` array. 3 days per sub-exp = 15 fires per endpoint per sub-exp.

**Sequencing:** Sub-exp 1 (3 days) → kill-criteria check → verdict → Sub-exp 2 (3 days) → check → verdict → Sub-exp 3 (3 days) → check → cross-sub-exp synthesis case study. Total: 9 collection days + ~6 buffer days = 15 days.

## §5 Pre-registration discipline

Three separate pre-registration JSON files (one per sub-exp). Hash-locked + immutable post-author. Authors before Sub-exp N launches; cannot be edited after the lock fires.

**File paths:**
- `.claude/shared/hadf/preregistration-phase2bis-subexp1.json`
- `.claude/shared/hadf/preregistration-phase2bis-subexp2.json`
- `.claude/shared/hadf/preregistration-phase2bis-subexp3.json`

**Locking flow:** `scripts/hadf-phase2bis-lock-prereg.sh <subexp-id>` (NEW per T1-C):
1. Compute sha256 of preregistration JSON
2. Write sibling `.lock` file with `{sha256, timestamp, locker_user, locker_commit}`
3. `git tag -s prereg-phase2bis-subexp<N>-locked-<YYYY-MM-DD>` (signed tag if GPG configured)
4. Push tag to origin
5. Pre-commit hook (NEW lightweight check): rejects edits to a locked preregistration file unless the lock file is also removed (which requires explicit operator override + audit-log entry)

**Required pre-registration content per sub-exp:**

```json
{
  "subexp_id": "phase2bis-subexp{N}",
  "rq": "RQ{N} statement verbatim",
  "endpoints": [/* per §2 */],
  "per_call_controls": {/* per §4 */},
  "campaign_schedule": {/* per §4 */},
  "primary_metric": "silhouette score at k=5",
  "expected_yield_threshold": 600,
  "kill_criteria": [/* per §7, including criterion #4 */],
  "trip_wires": [/* per §7 */],
  "verdict_thresholds": {
    "pass_silhouette_min": 0.5,
    "pass_yield_min": 600,
    "fail_silhouette_max_or_clusters_lt_3": "explicit"
  },
  "harness_hardening_proof": {
    "env_local_sha256_at_deploy": "<computed at launch>",
    "fix1_commit_hash": "<sha that introduced worktree-local venv>",
    "preflight_test_log_path": ".claude/shared/hadf/phase2bis-deploy-verification/subexp{N}-deliberate-break.log",
    "state_owner_at_creation": "ft2"
  }
}
```

The `harness_hardening_proof` block cryptographically certifies §3 fixes are in place at deploy time. Specifically:
- `env_local_sha256_at_deploy` — sha256 of the COPIED `.env.local` (proves Fix #2 — file is regular, not symlink, contents frozen)
- `fix1_commit_hash` — git SHA where worktree-local venv pattern was introduced (proves Fix #1)
- `preflight_test_log_path` — path to a log artifact from a deliberate-break test run (proves Fix #3 wrapper preflight actually fires `exit 78` when venv binary is broken — this is the test artifact, not the production run log)
- `state_owner_at_creation` — must be `"ft2"` per v7.8.3 schema requirement (proves the v7.8.3 STATE_OWNER_MISSING gate passes)

## §6 Verdict comparison protocol + case study structure

**One case study per sub-exp** + **one cross-sub-exp synthesis case study** after Sub-exp 3.

**Required sections (per Phase 2 case study template, retained verbatim):**

1. **Summary Card** — date, RQ, endpoints, n_valid, primary_metric value, verdict (PASS/FAIL/INCONCLUSIVE), Tier 1/2/3 tag for primary metric
2. **Experiment Design** — pre-registration cite + lock SHA + lock timestamp; T1 controls; campaign schedule
3. **Raw Data** — yield table per endpoint per fire; ledger preservation paths (in-repo + off-SSD backup)
4. **Analysis** — silhouette computation + per-cluster summaries + per-endpoint signature plots
5. **Success or Failure** — verdict with explicit reference to pre-registered thresholds
6. **Framework Signal** — what this sub-exp says about the HADF dispatch claim
7. **Methodology Notes** — anchor drift if Sub-exp 3, missed-fire reconciliation, any incidents

**Banned phrases + practices** (carried over from Phase 2 case study):
- ❌ "promising" / "encouraging" / "trending toward" — verdict is binary per pre-reg thresholds
- ❌ Post-hoc threshold adjustment — thresholds are pre-registered; results are reported against them
- ❌ Claiming generalization beyond the endpoint matrix actually tested
- ❌ Citing the silhouette score without n_valid + cluster count + per-cluster sizes

**Cross-sub-exp synthesis case study** (after Sub-exp 3): 1 doc covering: (a) consistency of the OpenAI/Anthropic anchor signatures across Sub-exp 1 and Sub-exp 3 (drift); (b) Sub-exp 1 cloud generalization verdict; (c) Sub-exp 2 cloud-vs-local separability verdict; (d) Sub-exp 3 routing test verdict — does same model behind different providers fingerprint differently?; (e) overall HADF dispatch claim status: confirmed / refuted / inconclusive.

## §7 Kill criteria + trip-wires + non-scope

### Kill criteria — per sub-exp (any one trips → halt sub-exp)

1. `n_valid < 600` — yield too low to compute silhouette (Phase 2 had n=700)
2. All endpoints simultaneously rate-limited for >2 fires consecutively
3. ANY endpoint changes streaming protocol or model id mid-collection (vendor change invalidates the run)
4. **NEW:** Wrapper preflight fails 3+ times consecutively (suggests deploy-time corruption — halt before contaminating records)

**`kill_criteria_resolution` field on state.json** (per v7.8.3 FEATURE_CLOSURE_COMPLETENESS Q7) — must be non-null at each sub-exp closure. Acceptable values: `"none_tripped"`, `"<criterion_id>_tripped_<resolution_action>"`, e.g., `"criterion_1_tripped_run_extended_to_6_days_yield_recovered"`.

### Trip-wires (don't abort, do flag)

- **Anchor drift between Sub-exp 1 and Sub-exp 3** — `scripts/hadf-phase2bis-anchor-drift-check.py` (NEW per T2-E) computes KS-test p-value comparing Sub-exp 1's openai+anthropic distributions vs Sub-exp 3's anchor distributions. If p<0.01, append methodology note to Sub-exp 3 case study; do NOT abort.
- **Cost overrun >3x extrapolation** — pause for operator review.

### Non-scope (explicitly excluded — do not creep)

- Track 6 HADF gate activation in dispatch code (post-Sub-exp-3 verdict work item, separate Feature)
- HADF UI surfacing in fitme-story `/control-room/hadf` route (separate work item)
- Provider-side latency baseline establishment (assumes Phase 2's measurement protocol is sufficient)
- Anything requiring API key rotation (use existing `.env.local` keys; if any expire mid-campaign, halt + restart with refreshed keys + new pre-registration)

## §8 Per-sub-exp dedicated worktree (resolved)

**Decision:** dedicated per-sub-exp worktree at sibling paths. Resolved per Q1=S1 (isolation principle from cross-repo Phase C decision) + T1-E (recommendation explicit) + v7.8.1 BRANCH_ISOLATION_VIOLATION norm.

| Worktree path | Branch | Records `state.json::worktree_path` |
|---|---|---|
| `/Volumes/DevSSD/FitTracker2-hadf-phase2bis-subexp1` | `feat/hadf-phase2bis-subexp1` | yes |
| `/Volumes/DevSSD/FitTracker2-hadf-phase2bis-subexp2` | `feat/hadf-phase2bis-subexp2` | yes |
| `/Volumes/DevSSD/FitTracker2-hadf-phase2bis-subexp3` | `feat/hadf-phase2bis-subexp3` | yes |

Disk cost: ~15 GB total acceptable on the SanDisk Extreme. **`worktree_path` field** (T2-B) ensures v7.8.1 `BRANCH_ISOLATION_LAUNCHD_DRIFT` cycle gate engages — plist `WorkingDirectory` must match `worktree_path`.

**Why dedicated, not shared:** Phase 2's incident #1 (launchd plist anchored to canonical repo path) re-emerges if a single shared worktree is reused across sub-exps. Per-sub-exp isolation also lets each sub-exp commit independently without rebase friction (V9 driver covers feature logs, but case study + state.json mutations don't share that auto-merge).

## §9 Pre-experiment safety verification + go/no-go ceremony

Before any sub-exp's launchctl plist is bootstrapped, the following must be satisfied + recorded:

| Check | Action | Pass condition |
|---|---|---|
| Pre-flight smoke-fire (T2-D) | 1 call/endpoint shake-out under same wrapper | All endpoints return non-error response within 60s (600s for Ollama) |
| Cost ceiling enforcement (T2-C) | Verify daily cron + per-fire cost log table populated | `scripts/hadf-cost-cron.py --check` exits 0 |
| Heartbeat ledger initialized (T2-A) | Verify `.claude/shared/hadf/phase2bis-fire-heartbeat.jsonl` exists + writable | File exists; wrapper-test write succeeds |
| Pre-registration hash-locked (§5) | Verify `.lock` file + git tag exist | Both present; git tag pushed to origin |
| Harness hardening proof (§5) | 4 sub-fields populated in pre-reg | All 4 non-empty + verifiable |
| Operator go/no-go | Manual sign-off recorded in state.json `phases.research.gnogo_recorded_at` | Field set + matches operator user id |

**No sub-exp launches until all 6 pass.** A failure on any line is a hold; operator must remediate before re-running the ceremony.

## §10 Sub-experiment orchestration (NEW)

### Heartbeat ledger (T2-A)

Wrapper writes to `.claude/shared/hadf/phase2bis-fire-heartbeat.jsonl` (one line per event):

```jsonl
{"timestamp":"2026-05-23T08:00:00Z","subexp":"subexp1","fire_id":"subexp1-2026-05-23-fire-2","event":"fire_started","plist_invocation_id":"<launchd id>"}
{"timestamp":"2026-05-23T08:11:23Z","subexp":"subexp1","fire_id":"subexp1-2026-05-23-fire-2","event":"fire_ended","records_landed":423,"endpoints_succeeded":9,"endpoints_failed":0}
```

`scripts/hadf-phase2bis-heartbeat-audit.py` reconciles plist's `StartCalendarInterval` against ledger entries. Catches missed fires within 24h (closes Phase 2 incident #2 — missed fires whose root cause was never identified).

### Cost ceiling (T2-C)

Per-fire wrapper writes estimated cost to `.claude/shared/hadf/phase2bis-cost-log.jsonl` using per-provider rate table at `.claude/shared/hadf/provider-rates.json`. Daily cron at UTC 23:55 sums recent-fire costs for current sub-exp; if cumulative > $15, `launchctl bootout` of the sub-exp plist + post issue to Linear FIT-71.

### Pre-flight smoke-fire (T2-D)

Operator-invoked: `scripts/hadf-phase2bis-smoke-fire.sh <subexp-id>` runs 1 call against each endpoint in the sub-exp matrix. Aborts on any error response. Catches: API key has no quota, model id rejected, endpoint URL changed, streaming protocol changed.

### Anchor-drift trip-wire (T2-E, Sub-exp 3 only)

`scripts/hadf-phase2bis-anchor-drift-check.py` runs at Sub-exp 3 close-out. Loads Sub-exp 1 raw .jsonl + Sub-exp 3 anchor raw .jsonl. Computes 2-sample KS-test p-value on TTFT + TPS distributions per anchor endpoint. If p<0.01, append explicit methodology note to Sub-exp 3 case study; do NOT abort the verdict.

### Per-sub-exp closure ceremony

At end of each sub-exp's collection window (3 days × 5 fires):

1. Run `scripts/hadf-phase2bis-verdict.py <subexp-id>` — computes silhouette + cluster count + yield + checks against pre-registered thresholds → emits PASS / FAIL / INCONCLUSIVE
2. Write per-sub-exp case study at `docs/case-studies/hadf-phase2bis-subexp{N}-case-study.md` (7 required sections per §6)
3. State.json closure: `current_phase=complete` for the sub-exp's Tasks-block entry → must pass v7.8.3 FEATURE_CLOSURE_COMPLETENESS gate (7 required frontmatter fields + Q6 PR-list parity + Q7 `kill_criteria_resolution` non-null)
4. `make snapshot-phase PHASE=hadf-phase2bis-subexp{N}-complete` writes off-SSD backup with sha256-verified MANIFEST + CHECKSUMS to `~/Documents/FitTracker2-backups/2026-05-XX-hadf-phase2bis-subexp{N}-complete/`
5. Cross-sub-exp synthesis case study after Sub-exp 3 closes (separate doc covering all 3 verdicts + HADF claim status)

## §11 v7.8.3 framework compliance checklist

Every Phase 2-bis state.json mutation MUST satisfy these. Mechanically validated by pre-commit gates (no manual discipline required):

| Item | Mechanism | Gate code |
|---|---|---|
| `state_owner: "ft2"` at stub creation | v7.8.3 Phase 2 | STATE_OWNER_MISSING + STATE_OWNER_INVALID + STATE_OWNER_LOCATION_MISMATCH (morphed C-5) |
| `framework_version: "v7.8.3"` at stub creation | v7.8.x convention | (advisory; will be enforced as v7.9 candidate V3) |
| `worktree_path: "/Volumes/DevSSD/FitTracker2-hadf-phase2bis-subexp{N}"` per sub-exp | v7.8.1 T2-B | BRANCH_ISOLATION_LAUNCHD_DRIFT (cycle-time advisory) |
| All Tier 2.2 phase transitions logged via `scripts/append-feature-log.py` | v7.6 | PHASE_TRANSITION_NO_LOG + PHASE_TRANSITION_NO_TIMING |
| `cache_hits[]` populated post-Mechanism-C-ship-date | v7.8.3 V2 promotion | CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT (enforced) |
| `kill_criteria_resolution` non-null at each sub-exp closure | v7.8.1 Q7 | FEATURE_CLOSURE_COMPLETENESS Q7 |
| Bidirectional PR-list parity (state.json ↔ case study) | v7.8.1 Q6 | FEATURE_CLOSURE_COMPLETENESS Q6 |
| 7 required case-study frontmatter fields populated | v7.8.1 | FEATURE_CLOSURE_COMPLETENESS |
| Snapshot artifact at `~/Documents/FitTracker2-backups/...` per sub-exp closure | v7.8.3 Phase 0 | (manual readout, no gate yet) |
| Cross-repo PR cite cache available if cited | v7.8.3 D-3 | BROKEN_PR_CITATION (D-3 morphed) — NOT used by P2-bis (Q3=OUT, no cross-repo cites expected) |
| V9 driver covers `<feature>.log.json` for parallel collection windows | v7.8.3 Phase 0 | (auto-merge, no gate) |

## Out-of-scope reminders

- **Q1=S1 (Cross-repo Phase C ships first)** — MET via v7.8.3 ship 2026-05-11.
- **Q2=V2-only** — V3/V4/V5 promotion candidates remain deferred to v7.9 (decision date 2026-05-21). P2-bis does NOT block on those promotions.
- **Q3=OUT (Track 6 HADF gate activation)** — separate work item triggered by Sub-exp 3's verdict. P2-bis does NOT include code changes to dispatch routing.

## Predecessor + dependency chain

| Item | Reference |
|---|---|
| Predecessor case study | [`docs/case-studies/hadf-phase2-cloud-fingerprinting-case-study.md`](../../case-studies/hadf-phase2-cloud-fingerprinting-case-study.md) |
| Brainstorm memory | `memory/project_phase2bis_brainstorm_paused_2026_05_11.md` |
| Phase 2 incident catalog | `memory/project_hadf_phase2_in_progress.md` |
| 3-fix original spec (Track 5) | `memory/project_post_hadf_phase2_followup_tracks.md` |
| Backup gap discovery | `memory/project_hadf_preservation_backup_2026_05_08.md` |
| Off-SSD backup of Phase 2 dataset | `~/Documents/FitTracker2-backups/2026-05-08-hadf-preservation/` (sha256-verified, 244 KB n=700 + 200 contaminated) |
| Unblocking framework version | v7.8.3 (shipped 2026-05-11 via Linear FIT-70 + cross-repo-state-sync-impl Feature) |
| Linear stub | [FIT-71](https://linear.app/fitme-project/issue/FIT-71) |
| Triggers (post-completion) | Track 6 HADF gate activation work item (separate; Q3=OUT here) |

## Calendar gate

v7.8.3 SHIPPED 2026-05-11. **Earliest Sub-exp 1 launch: 2026-05-23** (T+12 days; soak window to verify no v7.8.3 regressions before starting a 15-day campaign that depends on the new state_owner schema, V9 driver coverage, snapshot protocol, and FEATURE_CLOSURE_COMPLETENESS gate). Spec writing + plan + PRD + implementation tasks 1-N (everything except actual collection) can happen during the soak window without violating the gate.
