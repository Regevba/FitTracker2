---
title: HADF Phase 2 — Cloud Fingerprinting Measurement
date_written: 2026-05-01
work_type: Feature
dispatch_pattern: serial
case_study_type: measurement_study
framework_version: v7.7
external_audit_status: pending
success_metrics:
  primary: "max_silhouette_score_across_k > 0.5 → clusters_found = true → Path B green-lit"
  secondary:
    - "minimum 600 valid data points across endpoints (validity floor from pre-registration)"
    - "minimum 150 valid data points per endpoint included in clustering"
    - "cluster_endpoint_purity > 0.8 supports hardware-class hypothesis"
kill_criteria:
  - "fewer than 600 total data points across all endpoints after the 3-day window"
  - "all endpoints simultaneously rate-limited (cannot collect)"
  - "any endpoint changes streaming protocol or model id mid-collection (invalidates control)"
kill_criterion_fired: false
predecessor_case_studies:
  - "docs/case-studies/hadf-hardware-aware-dispatch-case-study.md"
spec_path: docs/superpowers/specs/2026-04-16-hadf-hardware-aware-dispatch-design.md
plan_path: ~/.claude/plans/floofy-finding-boole.md
preregistration_path: .claude/shared/hadf/phase2-preregistration.json
summary_artifact_path: .claude/shared/hadf/phase2-fingerprint-summary.json
case_study_link: docs/case-studies/hadf-phase2-cloud-fingerprinting-case-study.md
status: complete
---

# HADF Phase 2 — Cloud Fingerprinting Measurement

> **EXTERNAL AUDIT PENDING.** This case study reports the mechanical verdict from the analyzer; an independent assessment of the methodology, dataset, and conclusions has not yet been completed. The pre-registration ([`.claude/shared/hadf/phase2-preregistration.json`](../../.claude/shared/hadf/phase2-preregistration.json), authored 2026-04-29 and immutable since) and the summary artifact ([`.claude/shared/hadf/phase2-fingerprint-summary.json`](../../.claude/shared/hadf/phase2-fingerprint-summary.json), authored 2026-05-01 on branch tip `61964d3` and landed in main 2026-05-08 as squash commit `a4b357f` via PR #264) are the assessable inputs. All quantitative claims in this document trace to one of those two files per `case_study_constraints.raw_data_citation_rule`.

## Summary Card

| Field | Value | Tier |
|---|---|---|
| Pre-registration | `.claude/shared/hadf/phase2-preregistration.json` (immutable, hash-verified) | T1 |
| Summary artifact | `.claude/shared/hadf/phase2-fingerprint-summary.json` (squash commit `a4b357f` on main, originally branch tip `61964d3`) | T1 |
| Verdict threshold | `max_silhouette_score_across_k > 0.5` | T1 |
| Observed | `silhouette = 0.5566` at `best_k = 5` | T1 |
| `clusters_found` | `true` | T1 |
| `path_b_recommendation` | `green-lit` | T1 |
| Validity floor (pre-registered) | 600 valid records total, 150 per included endpoint | T1 |
| Valid records collected | 700 (350 openai + 350 anthropic) | T1 |
| Contaminated records collected | 200 (segregated, excluded by analyzer's `ok=true` filter) | T1 |
| Endpoints included | 2 of 3 (openai, anthropic; local excluded — see §Methodology Notes) | T1 |
| Calendar days collected | 2 of 3 (early closure — see §Methodology Notes) | T1 |
| Kill criterion fired | None of the three abort conditions fired | T1 |

## Experiment Design

The pre-registration ([§design](../../.claude/shared/hadf/phase2-preregistration.json)) specifies:

- **Independent variable:** natural measurement noise across (time-of-day × calendar-day × endpoint).
- **Dependent variables:** `ttft_ms` (time to first streamed token), `tps` (output tokens per second from stream timestamps), `ttft_floor_ms` (minimum observed TTFT per endpoint), `tps_cov` (per-endpoint coefficient of variation of TPS).
- **Controls:** single fixed prompt shape (`"Write one paragraph (3-5 sentences) about the word: {nonce}."`); nonce is one random English word per call to defeat provider response caching while keeping prompt structure identical; no system prompt; no tool use; streaming required; max output tokens 200; temperature 0.7.
- **Models:** `gpt-4o-mini` for openai, `claude-haiku-4-5-20251001` for anthropic, `OLLAMA_MODEL` env (default `llama3.2:3b`) for local.
- **Schedule:** 50 calls/run × 5 time-of-day windows/day × 3 calendar days × 3 endpoints. Pre-registered TOD windows in UTC: 02:00, 08:00, 14:00, 18:00, 22:00. Floor 750 data points; ceiling 2,250.
- **Validity thresholds:** minimum 600 total valid records; minimum 150 per endpoint included in clustering.

Verdict function (pre-registered, mechanical):
- `if max_silhouette_score_across_k > 0.5: clusters_found = true; Path B green-lit`
- `else: clusters_found = false; Path B not recommended; HADF stays client-device-only`
- Verdict is a pure function of (this preregistration JSON, `scripts/hadf-phase2-analyze.py` output summary JSON). Per `verdict_function.mechanical_only`: no judgment, no hedging, no Claude-authored framing.

## Raw Data

Source: [`.claude/shared/hadf/phase2-fingerprint-summary.json`](../../.claude/shared/hadf/phase2-fingerprint-summary.json) (squash commit `a4b357f` on main, originally branch tip `61964d3`).

### Totals (T1)

```
valid_records:   700
error_records:   0       # in the locked file
total_records:   700     # in the locked file
```

The locked file contains only `ok=true` records by construction. The 200 contaminated records (200 `ok=false`) reside in segregated files — see §Methodology Notes.

### Per-endpoint stats (T1, from `summary.json::per_endpoint`)

| Endpoint | n | TTFT mean (ms) | TTFT median (ms) | TTFT p95 (ms) | TTFT min (ms) | TTFT stdev (ms) | TPS mean | TPS median | TPS p95 | TPS stdev | TPS cov |
|---|---|---|---|---|---|---|---|---|---|---|---|
| openai | 350 | 949.49 | 676.32 | 2017.54 | 388.20 | 1104.95 | 55.465 | 54.853 | 79.690 | 13.789 | 0.2486 |
| anthropic | 350 | 909.43 | 840.68 | 1338.32 | 567.83 | 299.95 | 95.466 | 92.416 | 117.774 | 21.981 | 0.2302 |

## Analysis

Method (pre-registered): k-means clustering on (`ttft_ms`, `tps`) joint space with per-feature standardization (z-score). k values tested: 2, 3, 4, 5, 6. Scoring: silhouette score per k. Tooling: scikit-learn 1.8.0, `random_state=42`, `n_init=10`. No a-priori outlier removal.

### Per-k results (T1, from `summary.json::kmeans.per_k`)

| k | silhouette | inertia | passes pre-registered threshold (>0.5) |
|---|---|---|---|
| 2 | 0.5067 | 985.7344 | yes |
| 3 | 0.5228 | 598.6961 | yes |
| 4 | 0.5460 | 435.1730 | yes |
| **5** | **0.5566** | 298.2467 | **yes (max)** |
| 6 | 0.4056 | 245.9189 | no |

`best_k = 5`; `max_silhouette_score_across_k = 0.5566`.

### Cluster endpoint purity at best_k=5 (T1)

| cluster size | dominant endpoint | purity |
|---|---|---|
| 365 | anthropic | 0.9205 |
| 316 | openai | 0.9715 |
| 15 | openai | 0.8667 |
| 3 | anthropic | 1.0000 |
| 1 | openai | 1.0000 |

Pre-registered secondary reporting threshold: `cluster_endpoint_purity > 0.8 supports hardware-class hypothesis`. Two largest clusters (681 of 700 records, 97.3% of the dataset) cross this threshold.

### Cluster endpoint purity at k=2 (T1, secondary report)

| cluster size | dominant endpoint | purity |
|---|---|---|
| 327 | openai | 0.9725 |
| 373 | anthropic | 0.9142 |

## Success/Failure

The pre-registered primary threshold is `max_silhouette_score_across_k > 0.5`. Observed: `0.5566`. The threshold is met. `clusters_found = true`. `path_b_recommendation = green-lit`. The verdict is recorded mechanically in `phase2-fingerprint-summary.json::verdict`.

Pre-registered kill criteria (from `kill_criteria.abort_if`):

1. fewer than 600 total data points across all endpoints after the 3-day window — **did not fire** (700 ≥ 600).
2. all endpoints simultaneously rate-limited — **did not fire** (zero rate-limited records observed).
3. any endpoint changes streaming protocol or model id mid-collection — **did not fire** (model ids unchanged across the campaign).

## Framework Signal

Per `case_study_constraints.banned_practices` ("speculation about Path B implementation details", "next-steps lists beyond the mechanical go/no-go", "qualitative interpretation in the Framework Signal section"), this section is restricted to mechanical entries.

- Path B (dispatch-layer HADF): `green-lit` per pre-registration verdict function, conditional `if_true` branch.
- HADF Phase 1 schema (`chip-profiles.json`, `hardware-signature-table.json`, `dispatch-intelligence.json::hardware_context`): unchanged by this study; `enabled: false` remains the current value.
- Pre-registered `non_scope` items (Layer 0/1/2/4 runtime code, flipping `hardware_context.enabled`, instantiating `hadf-metrics-template.json`, edits to `cache-metrics.json::hadf_affinity` or `chip-affinity-map.json::affinity_entries`, calibration of `hardware-signature-table.json`) remain out of scope of this case study.

## Methodology Notes

### Endpoint exclusion: `local`

The pre-registered design called for three endpoints: `openai`, `anthropic`, `local` (Ollama on the campaign machine). The launchd plist's `EnvironmentVariables` was set to `HADF_ENDPOINTS=openai,anthropic` before campaign start, deliberately omitting `local`, on the grounds documented in the plist comment: `"Ollama on this MacBook Air runs llama3.2:3b at ~0.7 tps which is far below the harness's 60s urllib timeout."` The pre-registration's `validity_thresholds.endpoint_failure_handling` permits this: *"If any endpoint produces fewer than 150 valid (non-error, non-rate-limited) data points, that endpoint is excluded from clustering and reported as a methodology limitation. Study still publishable with reduced endpoint count if total >= 600 across remaining endpoints."* The local endpoint produced zero records (deliberately disabled at deploy). The two-endpoint dataset (700 total, 350 each) crosses the 600 floor.

### Calendar-day coverage: 2 of 3 days (early closure)

The campaign was scheduled for 3 calendar days (2026-04-30 through 2026-05-03). It was closed on 2026-05-01 evening, after 7 successful fires across approximately 1.5 calendar days. Pre-registration kill criterion #1 (`fewer than 600 total data points after the 3-day window`) did not fire because the validity floor (600) was already crossed at closure (700 valid). The early closure was a user decision documented in §Mid-Campaign Incident Disclosure below.

### Time-of-day window coverage

Pre-registered windows (UTC): 02:00, 08:00, 14:00, 18:00, 22:00. Records collected by window (T1, from `tag` field in raw jsonl):

| window | records |
|---|---|
| window-02utc | 200 |
| window-08utc | 100 |
| window-14utc | 200 |
| window-18utc | 100 |
| window-22utc | 100 |

5 of 5 pre-registered TOD windows are represented in the locked dataset. Coverage is uneven (window-02utc and window-14utc have 2× the rows of the others) due to the early closure.

### Mid-Campaign Incident Disclosure (full)

This section discloses every observed event between campaign start and closure that affected the dataset. Per `case_study_constraints.raw_data_citation_rule`, every mechanical claim cites the pre-registration or the summary artifact; forensic claims cite system records.

**2026-04-30 07:00 IDT (UTC 04:00) — fire 1, manual kickstart.** First fire run from the main repo working tree (pre-isolation). 100 valid records written to `phase2-fingerprint-raw.jsonl` at the main repo path.

**2026-04-30 11:00 IDT (UTC 08:00) — fire 2 (scheduled), failed.** The launchd `ProgramArguments` hardcoded the main repo wrapper path. Between fire 1 and fire 2 the user switched the main repo to a different feature branch, which removed the wrapper script from the main repo's working tree. `bash` exited 127. Zero records written.

**2026-04-30 13:31 IDT — isolation fix committed (`5c096bc`).** Wrapper script made portable (auto-detects `REPO` via `$(dirname BASH_SOURCE)/..`). Plist `ProgramArguments` and `WorkingDirectory` switched to a dedicated git worktree at `/Volumes/DevSSD/FitTracker2-hadf-campaign/` pinned to `feature/hadf-phase2-fingerprint`. `.env.local` and `.venv-hadf-phase2` symlinked from main repo into the worktree.

**2026-04-30 13:34 IDT (UTC 10:34) — fire 2-bis (window-08utc), succeeded.** First fire post-isolation. 100 valid records written to `phase2-fingerprint-raw.jsonl` at the worktree path (relative path resolved against launchd's `WorkingDirectory`).

**2026-04-30 17:11 IDT — worktree branch renamed.** Worktree checked out from `feature/hadf-phase2-fingerprint` to `chore/hadf-phase2-progress-snapshot` (same commit `5c096bc`, reflog-verified). Functionally identical for the campaign.

**2026-04-30 14:55–17:06 IDT — fires 3, 4 (window-14utc, scheduled), succeeded.** 100 records each.

**2026-04-30 21:00 IDT — fire 5 (window-18utc), succeeded.** 100 records.

**2026-05-01 01:00 IDT — fire 6 (window-22utc), succeeded.** 100 records.

**2026-05-01 05:00 IDT — fire 7 (window-02utc), succeeded.** 100 records. **Locked-700 cumulative reached at this point.**

**2026-05-01 07:17 IDT — environment incident.** The `bin/` directory under `/Volumes/DevSSD/FitTracker2/.venv-hadf-phase2/` was deleted (parent dir mtime updated). The `/Volumes/DevSSD/FitTracker2/.env.local` file was also deleted at the same timestamp window (gitignored, untracked, no commit/branch event recorded by git). Files surviving: `.venv-hadf-phase2/include/` and `.venv-hadf-phase2/lib/python3.12/site-packages/{openai,anthropic,...}/` (mtime unchanged at original creation date 2026-04-29). Process logs sufficient to identify the trigger command at the OS level are not available on macOS for user-level deletions. Forensic evidence (T2): zsh history (`~/.zsh_history`, mtime 2026-05-01 06:35 IDT) contains a multi-line venv-rebuild recipe matching the partial-deletion pattern (`rm -rf .venv-hadf-phase2\ ` + `python3 -m venv .venv-hadf-phase2\ ` + `source ...activate\ ` + `pip install ...\ `). The two affected files were both gitignored at the main repo root, so a `git clean -fdx`-class command would also produce both deletions. Definitive identification is not possible without process logs.

**2026-05-01 11:00 IDT, 17:00 IDT — fires 8 and 9 (scheduled), did not produce log files.** No per-fire log files exist for these windows. Caffeinate process (`PID 15911`, `caffeinate -i -s -t 259200`) was alive and elapsed-counting through this window per `ps`. Root cause for the missed scheduling not identified.

**2026-05-01 21:00 IDT — fire 10 (window-08utc, scheduled), wrote 100 contaminated records.** Wrapper fell back to system python (`/opt/homebrew/bin/python3`) because `.venv-hadf-phase2/bin/python3` was missing (broken venv from 07:17 IDT). System python lacked the openai and anthropic SDKs. All 100 records written with `ok=false`, `error="(openai|anthropic) SDK not installed"`. Records segregated to `phase2-fingerprint-raw.contaminated-100-fire8-broken-venv.jsonl`.

**2026-05-01 22:11–22:25 IDT — recovery executed.** Service `bootout`. 800-row pre-recovery jsonl backed up to `incident-2026-05-01-22utc-recovery/`. Broken venv (75 MB of `include/` + `lib/`) backed up to same dir. Live jsonl split: rows 1–700 (all `ok=true`) → `phase2-fingerprint-raw.locked-700-fires1to7.jsonl`; rows 701–800 (all `ok=false`) → `phase2-fingerprint-raw.contaminated-100-fire8-broken-venv.jsonl`. Live jsonl truncated to empty. Venv recreated: `python3 -m venv` → `pip install openai anthropic` (versions `openai==2.33.0`, `anthropic==0.97.0`). Service re-bootstrapped from `~/Library/LaunchAgents/`.

**2026-05-01 22:38 IDT — fire 11 (manual kickstart, recovery validation).** Wrapper used the recreated venv python (verified in fire log header). All 100 records written with `ok=false`, `error="(OPENAI|ANTHROPIC)_API_KEY not set"`. Different failure mode than fire 10. Cause: the same 07:17 IDT incident also deleted `.env.local`; the wrapper's `if [ -f "$REPO/.env.local" ]; then source ...; fi` silently skipped because the symlink dangled. Records segregated to `phase2-fingerprint-raw.contaminated-100-fire9-missing-env-keys.jsonl`.

**2026-05-01 22:43 IDT — campaign closed by user direction.** Service unloaded; `caffeinate` (PID 15911) killed; runtime plist removed from `~/Library/LaunchAgents/`; macOS Full Disk Access for `/bin/bash` revoked. Locked-700 dataset preserved. Pre-registration unmodified. Two contaminated files preserved. Pre-merge backups preserved at `/Volumes/DevSSD/FitTracker2/.claude/shared/hadf/incident-2026-05-01-22utc-recovery/` and `/Volumes/DevSSD/FitTracker2/.claude/shared/hadf/pre-merge-backup-2026-04-30/`.

### Why this disclosure does not invalidate the verdict

The pre-registration's `kill_criteria.abort_if` enumerates exactly three abort conditions. None of the three fired:
1. `fewer than 600 total data points` — 700 valid records collected.
2. `all endpoints simultaneously rate-limited` — zero rate-limited records observed.
3. `any endpoint changes streaming protocol or model id mid-collection` — model ids unchanged.

The 200 contaminated records (fires 10 and 11) are filtered by the analyzer's `ok=true` filter at line 67 of `scripts/hadf-phase2-analyze.py` (`if not r.get("ok"): continue`). They contributed zero signal to the clustering. The locked-700 dataset is identical to what the analyzer would have processed if the campaign had closed cleanly at 700 records. The verdict is computed on the locked-700 file via `--raw` flag, not on the post-incident jsonl state.

The early closure means the dataset has 700 valid records rather than the full 1,500 the original schedule would have produced. The pre-registered validity floor (600) is met; the pre-registered ceiling (2,250) is not. Per `kill_criteria.abort_action`: *"Document the abort condition in the case study Methodology Notes section and publish the partial data. Do NOT silently extend or restart collection — extension would break pre-registration and the case study's independent assessability."* The campaign was not silently extended or restarted. The dataset published is the dataset collected.

### Pending external audit

This case study has not yet been independently assessed. The pre-registration, the immutable summary artifact, and the segregated contaminated files are committed to git. The pre-recovery and pre-merge backups (raw fingerprint jsonl + broken-venv snapshot) are preserved on disk at `.claude/shared/hadf/incident-2026-05-01-22utc-recovery/` and `.claude/shared/hadf/pre-merge-backup-2026-04-30/` — both gitignored (bulky raw forensic data; available to an independent operator on request). Per the impartiality rule (`memory: feedback_measurement_case_study_impartiality.md`), the verdict reported here is mechanical and the analysis should be re-runnable by any operator with access to the locked-700 file and the analyzer script.
