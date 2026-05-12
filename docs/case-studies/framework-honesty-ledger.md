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

**Successor: TBD** (next entry will be appended when the next "we got this wrong" surfaces and is closed).

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

**Successor: TBD.**

**Cross-references:**

- v7.8.4 CLAUDE.md section: [`CLAUDE.md`](../../CLAUDE.md) — "v7.8.4" section
- v7.8.4 cold-start entrypoint: [`.claude/entrypoints/framework-v7-8-4.md`](../../.claude/entrypoints/framework-v7-8-4.md)
- PR cache freshness script: [`scripts/ensure-pr-cache-fresh.py`](../../scripts/ensure-pr-cache-fresh.py)
- Infra master plan: [`docs/master-plan/infra-master-plan-2026-05-12.md`](../master-plan/infra-master-plan-2026-05-12.md) §2.2

---

> _Next entry will be appended below this line when needed. Format
> is FT2-FH-NNN with immutable monotonic numbering. Entries are never
> silently edited; revisions are themselves new entries that
> back-reference the prior entry._
