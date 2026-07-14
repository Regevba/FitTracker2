---
title: Framework Honesty Ledger
date_created: 2026-05-03
case_study_type: roundup
work_type: chore
description: Append-only ledger of "we got this wrong + here's how" entries about the framework itself. Pattern from curl monthly reports + Postgres release notes ("broken in N.M, fixed in N.M+1") + Tailscale release notes' explicit "we got this wrong" sections. Each entry is FT2-FH-NNN, immutable once published, augmented only by appending new entries.
tier_tags_required: false
status: live
success_metrics: N/A — this is an append-only ledger, not a measurable feature. Per-entry success criteria live inside each FT2-FH-NNN entry.
kill_criteria: N/A — ledger format precludes a single closure criterion. Each entry's individual closure path is recorded inline.
dispatch_pattern: serial (chore; ledger entries appended one at a time)
---

# Framework Honesty Ledger

> An append-only public record of framework claims that were later
> falsified by data, plus the closure path. **Original entries are
> never silently edited.** Corrections accrete as new entries with
> back-references. The ledger exists because trust is a track record,
> not a slogan: continuing to publish corrections IS the trust signal.
> (Closure rule: publish verbatim, then remediate.)
>
> Format inspiration: curl monthly reports, Postgres release notes
> "broken in N.M, fixed in N.M+1" pattern, Tailscale release notes'
> explicit "we got this wrong" sections, the CVE coordinated-disclosure
> protocol.

---

## FT2-FH-001 — v7.7 silent-pass on `CACHE_HITS_EMPTY_POST_V6`

**Status:** **CLOSED** in v7.8 (2026-05-02 → 2026-05-03 across PRs #173, #185, #186, #187, #188, #189, #192, #193).

**Original claim** (v7.7 case study, Section 99 / "Outcome at synthesis time" table, published 2026-04-27):

> | `cache_hits[]` post-v6 | 33.3% | **gated to 100% on next write (issue #140 closed)** |

**What the data showed** (T1, instrumented via Python sweep against `.claude/features/*/state.json`, captured 2026-04-30):

- The v7.7 `CACHE_HITS_EMPTY_POST_V6` gate read `state.get("created_at", "")` for its post-v6 cutoff comparison.
- **43 of 46 features (93%)** stored the timestamp under the legacy key `created` instead.
- The gate's first conditional (`created_at < V6_SHIP_DATE`) evaluated `"" < "2026-04-16"` → `True` → early return without finding for those 43.
- The remaining 3 features either had `created_at` set but were not yet at `current_phase=complete`, or had no `cache_hits` key at all (gated by `if cache_hits is None`).
- **Effective gate coverage at the time the v7.7 case study claimed "100% gated" was 0 / 46 features.**

Issue #140 was closed in spec, open in practice.

**Why this matters:** the v7.7 case study was written, peer-reviewed, and shipped while the headline gate had **0% effective coverage**. The framework asserted gate *implementation*; it never asserted gate *execution*. This is the exact failure mode v7.5 was created to prevent.

**Closure path** (v7.8):

1. **PR #169** (2026-05-01) — bulk migration: 43 state.json files renamed `created` → `created_at`. Gate's read path now sees the canonical field.
2. **PR #173** (2026-05-02, by Regev) — Mechanism C scaffolding (`PostToolUse:Read` hook + `scripts/observe-cache-hit.py`) + defensive dual-read `created` ∪ `created_at` + Mechanism-C exemption (`MECHANISM_C_SHIP_DATE`). v7.7 case study Section 99B correction note appended.
3. **PRs #185 + #186** (2026-05-03) — `framework_version` backfill: 39 missing + 6 unprefixed-numeric + 1 misspecified → 46/46 canonical `vX.Y` form. Validation criterion 3 from spec §9 hit.
4. **PR #187** (2026-05-03) — **Mechanism A** (the meta-fix): every write-time gate now emits `{candidates, checked, skipped, skip_reasons}` per run to `.claude/logs/gate-coverage.jsonl`. The first event captured on real corpus shows `CACHE_HITS_EMPTY_POST_V6: candidates=47, checked=0, skipped=47` — **the silent-pass evidence captured at the source.** v7.9 promotes `GATE_COVERAGE_ZERO` to enforced.
5. **PR #188** (2026-05-03) — Mechanism C wiring (T9 + T10 + T11): `/pm-workflow` writes `.claude/active-feature`, SessionStart surfaces it, `observe-cache-hit.py` reads it for attribution, new `CACHE_HITS_AUTO_INSTRUMENTATION_INACTIVE` advisory fires when session ledger captures Reads but state.json drifts.
6. **PR #189** (2026-05-03) — Mechanism E git merge driver (`union-dedup-by-key`) auto-resolves append-only ledger conflicts.
7. **PR #192** (2026-05-03) — Schema bridge fields populated on all 47 features; new `path-reducers.json` + `agent-leases.json` registries.
8. **PR #193** (2026-05-03) — Mechanism D (`pre-commit-self-test`) asserts no header drift; Mechanism F (`membrane-status.py`) advisory smartlog.

**Tier tags:** all numerical claims in this entry are T1 (live Python sweep against the corpus, gate-coverage.jsonl captured at v7.8 ship). The 2026-04-30 audit memo + this ledger entry are the source.

**Lessons recorded:**

1. **Don't claim "100% gated" without verifying the gate can fire.** v7.8 Mechanism A makes this structurally observable; v7.9 promotes the meta-check to enforced.
2. **Don't add a gate that depends on a field most features don't use.** v7.8 Mechanism B (dual-read + canonical schema) gives field-rename drift a detection surface.
3. **Memory drift is itself a silent-pass surface.** The 2026-04-30 audit memo was 2 days stale at the start of the v7.8 work session. Several "open" items had already been closed by predecessor PRs. Verifying memory against current code BEFORE starting work is now a documented anti-pattern check.
4. **Continuing to publish IS the trust signal.** Per the publish-then-remediate rule: original v7.7 case study is unchanged on `main`; corrections accrete via Section 99B + this ledger entry. Pattern: curl monthly reports, Postgres release notes, Tailscale.

**Predecessor: none** (this is the first ledger entry).

**Successor:** FT2-FH-002 (v7.8.3 PR-cache-staleness silent-pass).

**Cross-references:**

- v7.7 case study Section 99B correction note: [`docs/case-studies/framework-v7-7-validity-closure-case-study.md`](framework-v7-7-validity-closure-case-study.md)
- v7.8 case study (live journal): [`docs/case-studies/framework-v7-8-bridge-case-study.md`](framework-v7-8-bridge-case-study.md)
- Bridge design spec: [`docs/superpowers/specs/2026-05-02-framework-v7-8-and-v7-9-bridge-design.md`](../superpowers/specs/2026-05-02-framework-v7-8-and-v7-9-bridge-design.md)
- Audit memo (memory): `project_framework_gaps_audit_2026_04_30.md`
- Cold-start entrypoint: [`.claude/entrypoints/framework-v7-8.md`](../../.claude/entrypoints/framework-v7-8.md)

---

## FT2-FH-002 — v7.8.3 PR-cache-staleness silent-pass

**Filed:** 2026-05-12 (single-session patch v7.8.4)
**Framework version at incident:** v7.8.3
**Framework version at resolution:** v7.8.4

**What we got wrong:** During the 2026-05-12 session-open status check, `make integrity-check` reported **35 findings** (32× BROKEN_PR_CITATION + 2× PR_NUMBER_UNRESOLVED + 1× PHASE_LIE). Every cited PR (#307, #311 in FT2; #93, #95, #97, #98 in fitme-story) was live-verified via `gh pr view` to be MERGED on GitHub. The findings were **100% false positives** caused by an empty `.cache/gh-pr-cache.json` (schema present, `last_refreshed_at: 2026-05-11T17:58Z`, but **0 PRs in both `Regevba/FitTracker2` and `Regevba/fitme-story`** in the cached arrays).

**Root cause:** The v7.8.3 D-3 PR-cite cache (`scripts/refresh-pr-cache.py`) was a deliberate caching layer to avoid hitting the `gh` CLI on every integrity-check run. But the contract was "cache exists" — NOT "cache is fresh AND non-empty." A cache file written with malformed/empty `repos.*.{open,merged,closed}` payloads would still pass `load_pr_cache()`'s existence check, and downstream callers (`audit_case_study_citations`, `_resolve_pr_cite_integrity`) would lookup every cited PR number against an empty array → universal-not-found → BROKEN_PR_CITATION fires for everything.

**Why the silent-pass class repeats v7.7's lesson:** FT2-FH-001 was "gate that depends on a field most features don't use silently passes." This is the same shape with a different victim: a *gate that depends on a cache layer assumed populated silently false-positives when the cache is empty.* In both cases, the gate has full implementation but lacks a coverage-assertion on its own dependency.

**Why this matters:** v7.9's 2026-05-21 promotion decision evaluates criterion #2 ("no false positives") per the [infra master plan](../master-plan/infra-master-plan-2026-05-12.md) §2.2. If `make integrity-check` is reporting 33 BROKEN_PR_CITATION false-positives on the morning of 2026-05-21, the criterion becomes ambiguous to evaluate. v7.8.4 closes the door before the data freezes.

**Closure (v7.8.4):**

1. **New script `scripts/ensure-pr-cache-fresh.py`** — checks `last_refreshed_at` timestamp AND non-empty payload (`cache_is_empty()` returns True when all `repos[*].{open,merged,closed}` arrays are empty). Refreshes if stale (>24h), missing, or empty. Fail-soft on `gh` unavailability (logs warning, lets downstream proceed).
2. **`Makefile::integrity-check` extended** — auto-invokes `ensure-pr-cache-fresh.py --quiet` before `integrity-check.py`.
3. **`.github/workflows/integrity-cycle.yml` extended** — new `Refresh PR cache (v7.8.4)` step before the integrity-check step. `secrets.GITHUB_TOKEN` provides API auth; failure logs via `::warning::` annotation but does not abort the cycle.

**Companion v7.8.4 hygiene (in the same patch, NOT separate honesty entries):**

- 5 LOW doc-debt items closed (dual-outlet frontmatter + branch-isolation success_metrics + ios-code-connect case_study_type)
- 6 TIER_TAG_LIKELY_INCORRECT advisories cleared (3 heuristic narrowings + 1 case-study re-tag + 1 reference-ledger pinning)
- 2 CACHE_HITS_AUTO_INSTRUMENTATION_INACTIVE advisories cleared (cache_hits[] backfill from Mechanism C attribution data)
- Stale `.claude/active-feature` lockfile reset
- First-ever `make snapshot-phase` invocation (sha256-verified backup off-SSD)

**Outcome:** `make integrity-check` baseline went from 35+9 (session open) → **0 findings + 0 advisory** (v7.8.4 ship).

**Tier tags:** T1 (live `make integrity-check` runs across the v7.8.4 session, before/after snapshots captured to `.claude/integrity/snapshots/2026-05-12T07-22-35Z.json`).

**Lessons recorded:**

1. **A cache layer needs a "cache is meaningful" predicate, not just "cache exists."** Empty/stale caches silently false-positive every dependent gate. Future cache-dependent gates should ship with an `is_cache_usable()` check beside the cache-load.
2. **The v7.7 silent-pass class is recurrent.** Different victim (PR cache vs. `created_at` field), same shape (gate depends on something it doesn't assert). The Mechanism A coverage-emission pattern (v7.8) should extend to cache-layer gates next: emit `{cache_age_seconds, entries_loaded}` alongside `{candidates, checked, skipped}`.
3. **Patch-level hygiene releases pay for themselves before promotion windows.** v7.9 makes the 2026-05-21 promotion decision with a 0+0 baseline — every advisory at that moment is real, not noise. Cost: ~2h of work in this session. Cost saved: ambiguity-cost on the promotion criterion #2 evaluation.

**Predecessor:** [`FT2-FH-001`](#ft2-fh-001--v77-silent-pass-on-cache_hits_empty_post_v6) — v7.7 silent-pass on `CACHE_HITS_EMPTY_POST_V6`.

**Successor:** FT2-FH-003 (v7.9 promotion — no silent-pass; discipline pattern).

**Cross-references:**

- v7.8.4 CLAUDE.md section: [`CLAUDE.md`](../../CLAUDE.md) — "v7.8.4" section
- v7.8.4 cold-start entrypoint: [`.claude/entrypoints/framework-v7-8-4.md`](../../.claude/entrypoints/framework-v7-8-4.md)
- PR cache freshness script: [`scripts/ensure-pr-cache-fresh.py`](../../scripts/ensure-pr-cache-fresh.py)
- Infra master plan: [`docs/master-plan/infra-master-plan-2026-05-12.md`](../master-plan/infra-master-plan-2026-05-12.md) §2.2

---

## FT2-FH-003 — v7.9 promotion succeeded with no silent-pass; calibration discipline pattern codified

**Status:** **CLOSED** at v7.9 ship (2026-05-21, single-session enforcement-flip on `feature/v7-9-promotion`).

This entry is **not a correction.** It is a recorded discipline: the v7.9 promotion is the first framework-version flip to land with the 4-criterion Mechanism A calibration gate from infra-master-plan §2.2 already met for every candidate. v7.7 shipped a headline claim that turned out to be wrong (FT2-FH-001). v7.8.3 shipped a PR-cache assumption that turned out to be wrong (FT2-FH-002). v7.9 shipped only after the gates being promoted had emitted observed telemetry against the criteria they were going to enforce.

**Decision context** (T1, captured 2026-05-21 from `.claude/logs/gate-coverage.jsonl`):

| Gate | 14d rows (2026-05-07 → 2026-05-21) | candidates=0 rows | Skip reasons (all legitimate) |
|---|---|---|---|
| `BRANCH_ISOLATION_VIOLATION` Mode B | 18 | 0 | `not_infra_commit_level` × 13 |
| `BRANCH_ISOLATION_VIOLATION` Mode C | 13 | 0 | (separate emission key) |
| `FEATURE_CLOSURE_COMPLETENESS` write-time | 13 | 0 | `not_complete_transition` × 11, `no_phase_change` × 1 |

**The 4-criterion checklist** (per infra-master-plan §2.2; the discipline being codified):

1. **Coverage emitted** — ≥7 days of `{candidates, checked, skipped}` rows in `gate-coverage.jsonl` per candidate. Met: 14 days, 0 zero-candidate rows across all 3 gates.
2. **No false positives** — every `failure` row maps to a legitimate violation in the staged diff (operator review). Met: 0 false-positive findings across the 14d window.
3. **No silent skips** — `skipped` count tracks real reasons (out-of-scope files, exempt tags), not bugs. Met: all `skip_reasons` map to documented legitimate cases.
4. **Reversibility** — advisory mode restorable in <5 min via single-line `BRANCH_ISOLATION_ADVISORY_MODE = True` revert + commit + merge. Verified locally.

**What changed at v7.9 ship:**

| File | Change | LoC |
|---|---|---|
| `scripts/check-state-schema.py:132` | `BRANCH_ISOLATION_ADVISORY_MODE = True → False` (single flag drives all 3 gates) | 1 |
| `CLAUDE.md` | New "v7.9 Promotion Release" section + version-chain header update + 2 advisory→enforced annotations | ~50 |
| `.claude/entrypoints/framework-v7-9.md` | New cold-start entrypoint | new file |
| `docs/architecture/dev-guide-v1-to-v7-7.md` | §2.4.1 promoted sub-section | ~30 |
| `docs/case-studies/framework-honesty-ledger.md` | This entry | ~70 |
| `docs/case-studies/framework-v7-9-promotion-case-study.md` | New case study with B1 outcomes + Phase E calendar | new file |
| `.claude/features/framework-v7-9-promotion/state.json` | Phase research → implement + skip prd + tasks_phase + timing | small |
| `.claude/logs/framework-v7-9-promotion.log.json` | 2 Tier 2.2 log entries (phase_approved + phase_started) | small |

**Discipline being codified** (T2, declarative — verifiable on next promotion):

Every future advisory → enforced promotion must execute the B1-style freeze-day checklist before the flip lands:

1. `make integrity-check` → must report 0 findings
2. `make integrity-diff` → must report no regression vs the pre-window baseline anchor
3. `make documentation-debt` → must report ≤ baseline open count
4. `make measurement-adoption` → capture for the promotion record (snapshot of {features_total, fully_adopted, per-dimension coverage})
5. `python3 scripts/membrane-status.py` → capture
6. Last 14 days of `.claude/logs/gate-coverage.jsonl` analyzed — per candidate gate, verify (a) ≥7 days of emission, (b) zero candidates=0 rows, (c) all skip_reasons map to documented legitimate cases
7. Per-gate decision recorded in the new framework version's case study + state.json `phases.research.decision` field
8. Single-line flip + side-effects PR opened only after all 6 above are GREEN

Any gate that fails any of the 4 §2.2 criteria stays advisory. Re-evaluation defaults to T+14d after the next attempted promotion window.

**Why this matters** (T3, narrative):

The 2026-04-21 Gemini independent audit's most consequential finding wasn't a specific bug — it was that the framework was shipping mechanisms (gates, advisories, scripts) faster than it was measuring whether those mechanisms actually fired. The v7.5 → v7.8 arc built the measurement infrastructure (Mechanism A coverage ledger, Mechanism C session attribution, Mechanism E merge driver, Mechanism F membrane status). v7.9 is the first promotion that *used* that infrastructure as a gate on its own promotion decision. The next promotion (v7.10 or whenever) will inherit the pattern: no flip without telemetry that the flip is needed and won't break the existing fleet.

The framework now follows the same closure rule as the case-study layer: publish verbatim, then remediate. Mechanism A measures gates the same way case studies measure features. A future framework version that promotes a gate without 7d of Mechanism A data + 0-false-positive evidence + reversibility verified should be treated as a regression in framework discipline — flag it, roll it back, and document the decision in this ledger.

**Tier tags:**

- T1 — the 14d telemetry counts (`{18, 13, 13}` rows from `gate-coverage.jsonl`), the file-change LoC tally, the integrity-check baseline (0 findings, 1 advisory before commit), the per-feature B1 verification outputs.
- T2 — the 4-criterion checklist becoming the canonical discipline for future promotions (declarative; verifiable on the next promotion's adherence).
- T3 — the framework-discipline narrative about why this matters (interpretive synthesis).

**Predecessors:**

- [`FT2-FH-001`](#ft2-fh-001--v77-silent-pass-on-cache_hits_empty_post_v6) — v7.7 silent-pass on `CACHE_HITS_EMPTY_POST_V6` (0/46 effective coverage shipped under a "100% gated" headline).
- [`FT2-FH-002`](#ft2-fh-002--v783-pr-cache-staleness-silent-pass) — v7.8.3 PR-cache-staleness silent-pass (33 false-positive findings on empty cache; closed at v7.8.4 with `PR_CACHE_STALE` auto-refresh).

**Successor:** TBD — depends on Phase E soak outcome. The next entry will be created either (a) at v7.10 promotion (logging that the discipline held), or (b) if Phase E surfaces a regression requiring rollback, an immediate entry capturing what went wrong with the calibration interpretation.

**Cross-references:**

- v7.9 case study: [`docs/case-studies/framework-v7-9-promotion-case-study.md`](framework-v7-9-promotion-case-study.md)
- v7.9 cold-start entrypoint: [`.claude/entrypoints/framework-v7-9.md`](../../.claude/entrypoints/framework-v7-9.md)
- CLAUDE.md v7.9 section: [`CLAUDE.md`](../../CLAUDE.md) — "v7.9 Promotion Release" section
- Dev-guide §2.4.1: [`docs/architecture/dev-guide-v1-to-v7-7.md`](../architecture/dev-guide-v1-to-v7-7.md)
- B1 freeze checklist: [`.claude/shared/must-have-cadence-followups.md`](../../.claude/shared/must-have-cadence-followups.md) §B1
- Infra master plan promotion criteria: [`docs/master-plan/infra-master-plan-2026-05-12.md`](../master-plan/infra-master-plan-2026-05-12.md) §2.2
- Pre-drafted day plan: [`docs/master-plan/post-v7-9-candidate-plan-2026-05-20.md`](../master-plan/post-v7-9-candidate-plan-2026-05-20.md)
- Predecessor v7.8.1 (the gates being promoted): [`docs/case-studies/framework-v7-8-branch-isolation-case-study.md`](framework-v7-8-branch-isolation-case-study.md)

---

## FT2-FH-004 — 2026-06-10 dilution-blind regression definition (phantom integrity-diff alerts)

**Status:** **CLOSED** in the 2026-06-10 telemetry-normalization pass (`chore/telemetry-backfill-multianchor`).

**Original behavior** (data-integrity sub-plan §2.3/§2.5 + `integrity-diff.py` + `daily-integrity-checkpoint.py::detect_regression`, as written 2026-05-14):

> A measurement target **degrading vs the 2026-05-14 baseline column** is a HIGH/CRITICAL drift signal.

This compared **raw percentages** against the canonical anchor with no rule for "the % fell purely because the corpus grew."

**What the data showed** (T1, instrumented via `make integrity-diff` + the new cohort comparison, captured 2026-06-10):

- `make integrity-diff` reported `timing_wall_time_pct_post_v6` −23.3pp and `cache_hits_pct_post_v6` −13.4pp vs the 2026-05-14 anchor.
- Both were **denominator dilution**: 34–36 features were added to the corpus since the anchor, entering the percentage denominators with empty metrics.
- On the cohort-intersection (features present at both anchors), **every dimension was flat-or-up**: `cache_hits` cohort 28.6%→31.4%, numerator 20→29. Zero real adoption was lost.
- The same blindness existed in the daily checkpoint: a day-over-day `adoption_pct_post_v6` drop flagged a regression even when the absolute `fully_adopted_post_v6` numerator was unchanged.

**Why this matters:** the regression *detector itself* was manufacturing false positives — the inverse of the silent-pass class, but the same root failure (a check whose definition doesn't match reality). Acting on a phantom regression wastes triage and erodes trust in the signal; left unfixed, every soak window with corpus growth would repeat it.

**Closure path** (2026-06-10):

1. **Honest backfill** — `total_wall_time_minutes` derived (from summed phase durations) for 19 clean same-session features; 29 multi-day/dirty features transparently tagged `wall_time_backfill: excluded-*` (NOT fabricated); all derived values carry `total_wall_time_minutes_provenance`. `cache_hits` deliberately NOT mass-backfilled (no honest source). This produced a one-time **+27pp `timing_wall_time` step-change** (23.9%→51.4% post-v6) — the trend-chart discontinuity on 2026-06-10 is this corrective backfill, NOT a measurement bug.
2. **Dilution-aware regression definition** — `classify_delta()` (`scripts/integrity-multi-anchor.py`) single-sources the verdict: `REAL_REGRESSION` only when cohort Δ<0 OR numerator Δ<0; a raw drop otherwise classifies `dilution`. `integrity-diff` + `daily-integrity-checkpoint` consume it; raw deltas still printed for transparency.
3. **Provenance split** — `make measurement-adoption` reports `instrumented + derived` per dimension; `--instrumented-only` gives the strict T1 view. The derived backfill cannot masquerade as contemporaneous instrumentation.
4. **Canonical anchor retained** — the 2026-05-14 baseline stays the regression reference (§3.2 authorizes new baselines only at daily/promotion/pre-research triggers). The earlier same-session bump of `integrity-diff` DEFAULT_BASELINE to a 2026-06-10 anchor was **reverted**; the 2026-06-10 snapshot is retained as evidence-only, not a regression anchor.
5. **Codified** — data-integrity sub-plan §2.6 (normalization overlay) + §2.7 (unified data-layer `make integrity-data-lake`) + §2.3/§2.5 amendments; CLAUDE.md Soak-window section; infra-master-plan pointer.
6. **Tests** — `test_integrity_multi_anchor.py` (classify_delta verdicts), `test_backfill_timing_wall_time.py` (clean/multiday/dirty), `test_integrity_data_lake.py` (R1/R5 reconciliation), provenance cases in `test_measurement_adoption_report.py`.

**Operator note:** the same `make integrity-data-lake` reconciliation pass surfaced a *separate* open anomaly — the weekly gate-coverage trend reports `distinct_gate_count=0` for 2026-05-18 / 06-01 / 06-08 while the F17 index has 25 gates. Flagged for a follow-up investigation (cron-context emptiness, F-LAUNCHD-DRIFT class); not part of this entry's closure.

**Cross-references:**

- Normalizer + classifier: [`scripts/integrity-multi-anchor.py`](../../scripts/integrity-multi-anchor.py)
- Unified data-layer: [`scripts/integrity-data-lake.py`](../../scripts/integrity-data-lake.py)
- Honest backfill: [`scripts/backfill-timing-wall-time.py`](../../scripts/backfill-timing-wall-time.py)
- Codification: [`docs/master-plan/data-integrity-and-rollback-2026-05-14.md`](../master-plan/data-integrity-and-rollback-2026-05-14.md) §2.6/§2.7
- Related field-rename class: FT2-FH-001

---

## FT2-FH-005 — Figma Code Connect bridge claimed "Synced" / "operator setup complete" while it never once published (2026-06-15)

**Surfaced by:** a full design-system audit (iOS + web) requested 2026-06-15. The audit compared the live Figma files (via the Figma MCP) against what the repo + docs claimed.

**The claim vs reality.**
- `docs/design-system/figma-code-sync-status.md` marked screens **"Synced (auto-built)"** with Figma node IDs (Smart Reminders `907:2`, Import `916:2`, Push Notifications `936:2`, plus iOS Code Connect targets `973:x`/`974:x`).
- `CLAUDE.md` (v4.X+CC) stated **"Manual steps per new UI feature: 2 → 0 once operator setup completes (which it has, as of 2026-05-10)."**
- **Reality:** the live iOS Figma library `0Ai7s3fCFqR5JXDW8JvgmD` is a single "Cover" placeholder page (0 published components/variables/styles); the web file `fsjHfFLAHELACZHku8Rfcl` contains only the UCC sign-in auth surface. Almost every cited node ID does not exist. The `figma-code-connect-publish.yml` workflow **failed on every real run since 2026-05-10** in both repos.

**Root cause.** Figma Code Connect requires an **Organization/Enterprise** plan; this account is **Pro**. MCP `get_code_connect_map` returns *"You need a Developer seat in an Organization or Enterprise plan."* iOS publish → 403 *"Invalid scope(s): need File Read + Code Connect Write"* (not grantable on Pro). Web publish → **W14**: the sign-in/recover mappings target page **frames** (`31-3`/`31-106`), not components, so `figma connect publish` validation aborts the entire publish. The `code-connect-automation` state.json had *honestly* recorded the T5 plan-tier blocker — but the higher-visibility surfaces (CLAUDE.md, the sync matrix, public pages) presented the bridge as operational. Classic silent-pass: workflow file + repo secret + `.figma.*` mappings + green-looking docs masking a pipeline at 0% success.

**Resolution (this change).**
1. **Disabled** both `figma-code-connect-publish.yml` workflows (auto-trigger removed → no more red runs; manual-only stubs documenting the reason).
2. **Reconciled** the authoritative docs (CLAUDE.md v4.X+CC section, `figma-code-sync-status.md` banner, `ios-code-connect-workflow.md` SUPERSEDED banner) to state plainly: code is the source of truth; Code Connect is unavailable on this plan.
3. **Plan** to make Figma an honest visual mirror without Code Connect (Figma MCP plugin API, which works on Pro): [`docs/design-system/figma-source-of-truth-plan-2026-06-15.md`](../design-system/figma-source-of-truth-plan-2026-06-15.md).
4. **Pattern** recorded as observed-pattern W36.

**General lesson.** A capability gated by an account plan/seat is an *external* dependency — verify it end-to-end (does it actually publish?) before any doc says "operational" or "setup complete." Scaffolding existing ≠ pipeline working. Grep every surface that asserts a status when the underlying capability turns out to be unavailable.

**Cross-references:**
- Disabled workflows: `.github/workflows/figma-code-connect-publish.yml` (both repos)
- Plan: [`docs/design-system/figma-source-of-truth-plan-2026-06-15.md`](../design-system/figma-source-of-truth-plan-2026-06-15.md)
- Observed pattern: W36 ([`.claude/integrity/observed-patterns.md`](../../.claude/integrity/observed-patterns.md))
- Honestly-recorded predecessor: `.claude/features/code-connect-automation/state.json` (T5 deferred, `final_status: partial_success_external_blocker`)

**Addendum — 2026-06-18 (feature `figma-design-architecture`; appended, not a silent edit).** Two clarifications to the snapshot above, neither of which changes the core disclosure (Code Connect *publishing* is unavailable on Pro — still true):

1. **The "iOS library = single Cover placeholder, 0 components/variables" reading was a point-in-time PRE-rebuild snapshot.** The same-day rebuild ([`figma-source-of-truth-plan-2026-06-15.md`](../design-system/figma-source-of-truth-plan-2026-06-15.md) Phases A/B) then **populated both mirrors**. Verified live 2026-06-18 via authoritative `use_figma` plugin-API reads: iOS `0Ai7s3fCFqR5JXDW8JvgmD` has Foundations `10:3`, Components `10:5` (18 variant-matrix component sets), and the 80-var code-mirror collection `985:2` whose values match `tokens.json`; web `fsjHfFLAHELACZHku8Rfcl` has 56 components + the 12-var code-mirror collection `34:62`. The mirrors are real and ~95% faithful — now a manually-maintained mirror governed by [`figma-mirror-maintenance-protocol.md`](../design-system/figma-mirror-maintenance-protocol.md) + the `figma-mirror-staleness` advisory.
2. **A re-audit on 2026-06-18 initially re-reported "0% / empty Cover" using `get_metadata`/`get_variable_defs`/`get_design_context` — that was a FALSE negative** (those tools read the Figma *desktop-app* context, not the `fileKey`). Recorded as **observed-pattern W38**. The lesson: verify "empty/missing" Figma reads with `use_figma` before acting. (This re-audit briefly tripped this feature's kill criterion and led to an approved rebuild that was cancelled before any write once the authoritative read corrected it.)

Fidelity audit of record: [`.claude/features/figma-design-architecture/mirror-fidelity-audit-2026-06-18.md`](../../.claude/features/figma-design-architecture/mirror-fidelity-audit-2026-06-18.md).

---

> _Next entry will be appended below this line when needed. Format
> is FT2-FH-NNN with immutable monotonic numbering. Entries are never
> silently edited; revisions are themselves new entries that
> back-reference the prior entry._
