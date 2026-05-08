---
title: "Framework Honesty Fixes (2026-05-01)"
slug: framework-honesty-fixes-2026-05-01
date: 2026-05-01
type: framework
framework_version: v7.7
work_type: chore
work_subtype: framework_correction
case_study_type: live_pm_workflow
parent_case_study: docs/case-studies/framework-v7-7-validity-closure-case-study.md
tldr: >-
  Closed the v7.7 silent-pass surface by renaming `created` → `created_at`
  across 43 state.json files, added a SCHEMA_DRIFT gate to block regression,
  added a FRAMEWORK_VERSION_FORMAT gate, and fixed a downstream consumer that
  was silently broken by the rename. Three near-misses caught by user-requested
  end-to-end verification: (1) initial migration corrupted Unicode em-dashes
  via `json.dumps()` defaults, (2) measurement-adoption-report.py read the
  legacy field and reported 0 post-v6 features after the rename, (3) the v7.5
  pipeline regression test had been broken since v7.7 shipped (pre-existing,
  not introduced).
key_numbers:
  - label: state.json files migrated
    value: "43"
    tier: T1
  - label: gate effective coverage (pre-fix → post-fix)
    value: "0/46 → 1/8 firing on post-v6 complete features"
    tier: T1
  - label: schema check tests
    value: "19/19 pass (12 existing + 7 new)"
    tier: T1
  - label: v7.5 pipeline defenses
    value: "15/15 pass (was 14/15 on main pre-fix; pre-existing test-fixture bug)"
    tier: T1
visual_aid: KeyNumbersChart
kill_criteria:
  - The migration corrupts content beyond the intended `created` rename (semantic-equivalence check fails on any of 46 files)
  - The new schema gates produce a false-positive on any current state.json (would block legitimate commits)
  - A downstream consumer of state.json data silently breaks and is missed by the verification sweep
success_metrics:
  - name: state_json_field_drift_rate
    baseline: 0.93  # 43/46 files used legacy `created` key
    target: 0.0
    tier: T1
  - name: cache_hits_gate_effective_coverage
    baseline: 0.0   # 0/46 features pre-fix
    target: 1.0
    tier: T1
dispatch_pattern: serial (framework correction; F6-F9 concurrent-dispatch hygiene block)
---

# Framework Honesty Fixes (2026-05-01)

> **Source:** [`memory: project_bug_retrospective_2026_05_01.md`](../../.claude/projects/-Volumes-DevSSD-FitTracker2/memory/project_bug_retrospective_2026_05_01.md), built on the [`2026-04-30 framework gaps audit`](../../.claude/projects/-Volumes-DevSSD-FitTracker2/memory/project_framework_gaps_audit_2026_04_30.md).
> **Parent:** [`framework-v7-7-validity-closure-case-study.md`](framework-v7-7-validity-closure-case-study.md) §99B (correction note)

## 1. The premise

The v7.7 case study claimed `cache_hits[]` post-v6 adoption was "gated to 100% on next write." A 2026-04-30 Python sweep against `.claude/features/*/state.json` found that the gate's `state.get("created_at", "")` read returned `""` on **43 of 46 features (93%)** because those files used the legacy `created` field name. The gate's first conditional (`created_at < V6_SHIP_DATE`) evaluated `"" < "2026-04-16"` → `True`, returning early without ever reaching the `cache_hits` check. **Effective coverage: 0/46 features**.

This PR closes that gap and three adjacent ones, and surfaces the gate's first real finding.

## 2. What shipped

| Gap (per retrospective) | Closure | File |
|---|---|---|
| **F-4a** — 43/46 state.json used legacy `created` key | Regex-preserving migration to `created_at` (whitespace, Unicode, inline-array formatting all preserved) | `.claude/features/*/state.json` (45 files) |
| **F-4b** — no gate blocking regression to legacy key | New `SCHEMA_DRIFT` check parallel to the existing legacy-`phase` check | `scripts/check-state-schema.py:367` |
| **F-5** — 6/46 had unprefixed `framework_version`; 39/46 missing | New `FRAMEWORK_VERSION_FORMAT` check (when set, requires `(pre-)?vX.Y`); 6 unprefixed values backfilled to canonical form. **Presence-required deferred** to a separate backfill PR — closing without timeline-research data on 39 features would manufacture history. | `scripts/check-state-schema.py:382` + 6 state.json files |
| **F-3** — v7.7 case study claim contradicted by data | Section 99B "Correction Note" appended (publish-verbatim discipline; original claim untouched) | `docs/case-studies/framework-v7-7-validity-closure-case-study.md` |
| **D-4** — pre-commit hook header listed v7.5/v7.6 only | Header rewritten to declare v7.7 + 2026-05-01 gates | `.githooks/pre-commit` |

Plus 7 new unit tests covering the two new schema checks (block legacy key, allow canonical, allow both-keys transient state, block unprefixed numeric, accept canonical formats, allow absence pending backfill, block garbage strings).

## 3. The designed finding (kept, not silently closed)

After the migration, the gate now fires on **1 feature**: `hadf-infrastructure` (post-v6, `current_phase=complete`, `cache_hits: []`). This is exactly what the gate was designed to catch — a feature that shipped post-v6 without recording a single cache hit during its lifecycle.

This finding is **kept as a violation**, not silently fixed. Manufacturing back-dated `cache_hits[]` entries to make the gate green would be the precise failure mode v7.5 was created to prevent. The PR exposes the finding; closing it is a separate decision (instrument retroactively, mark exempt with documented reason, or accept as the writer-path adoption debt issue #140 already tracks).

**Coverage profile (T1, instrumented via Python sweep):**

| Bucket | Count | Notes |
|---|---|---|
| Pre-v6 features (gate exempts) | 35 | created_at < 2026-04-16 |
| Post-v6 + not yet complete (gate waits) | 3 | framework-story-site, auth-polish-v2, unified-control-center |
| Post-v6 + complete + populated cache_hits[] (gate passes legitimately) | 4 | case-study-presentation, data-integrity-framework-v7-6, framework-v7-7-validity-closure, meta-analysis-audit |
| Post-v6 + complete + cache_hits key absent (gate skips per `if cache_hits is None`) | 3 | dispatch-intelligence-v5.2, framework-measurement-v6, parallel-write-safety-v5.2 |
| Post-v6 + complete + empty cache_hits[] (**gate fires**) | **1** | **hadf-infrastructure** |

The 3 features in the `cache_hits is None` bucket reveal a residual silent-pass surface: the v7.7 gate exempts features that never declare the field. A follow-up could close this by requiring `cache_hits: []` to be present at feature-creation time, but that's out of this PR's scope.

## 4. Three near-misses caught by user-requested verification

The user's mid-session instruction — "run the new changes against the entire gating system to make sure that all data aligns and that we are not breaking or corrupting any existing information by overriding it" — surfaced three issues that the initial implementation would have shipped silently.

### Near-miss 1: `json.dumps(d, indent=2)` corrupted formatting on 45 files

The first migration script parsed each state.json, manipulated keys in the dict, and wrote back via `json.dumps(d, indent=2)`. Observed effects on the canary file (`training-plan-v2/state.json`):

- Inline arrays `"sources": [".../foo.md"]` got expanded to multi-line.
- Literal Unicode em-dashes `—` got escaped to `—` (`json.dumps` default is `ensure_ascii=True`).
- Diff stat: file showed `+81 / −15` — **96 changed lines for what should have been 1 line**.

**Recovery:** caught by `git diff --stat` before commit; reset all state.json files to HEAD, rewrote the migration as a regex on the source text. Post-fix every changed file shows exactly `+1 / −1` (rename) or `0 / −1` (duplicate drop).

**Lesson:** when migrating one field across many JSON files, regex on the source string is safer than parse-and-reformat. Parse-and-reformat is sound only when the JSON style was already canonical — this codebase's wasn't.

### Near-miss 2: `measurement-adoption-report.py` silently broke

After the rename, `measurement-adoption-report.py` reported `Features: 46 (post-v6: 0, pre-v6: 46)` — down from `post-v6: 11` on origin/main. Cause: line 116 read `d.get("created")` (the legacy field). After the rename, that returned `None` for all 43 migrated files, and `post_v6("")` returned `False`.

**Recovery:** caught by running `make measurement-adoption` as part of the user-requested verification sweep. Fix: read `created_at` first, fall back to `created` as a transitional safety net. Post-fix the report correctly identifies 11 post-v6 features, matching the audit memo's numbers.

**Lesson:** schema migrations need a consumer-search step. A `grep -rn '\.get("created")'` across `*.py *.ts *.tsx *.js` would have caught this in seconds. Adding "search consumers before merging" to the migration playbook is a v7.8-class upgrade.

### Near-miss 3: pre-existing v7.5 pipeline test regression

The `bash scripts/test-v7-5-pipeline.sh` regression suite reported `Pass: 14  Fail: 1` after my changes. Initial reading: my new SCHEMA_DRIFT_CREATED or FRAMEWORK_VERSION_FORMAT check had a false-positive. **Wrong.**

Reproduction with the synthetic fixture showed the failure was the v7.7 `STATE_NO_CASE_STUDY_LINK` check rejecting a minimal `{"current_phase":"complete","status":"complete"}` fixture. Stash-and-rerun against origin/main: same `Pass: 14  Fail: 1`. The test had been **broken since v7.7 shipped** (the new `STATE_NO_CASE_STUDY_LINK` gate fires on a fixture that has no case_study link or exempt tag).

**Recovery:** added `case_study_type: "no_case_study_required"` + `case_study_exempt_reason` to the fixture. Post-fix: `Pass: 15  Fail: 0`.

**Lesson (T2):** the v7.5 pipeline regression test is supposed to be the framework's safety net, but the safety net itself decayed silently when v7.7 added gates without updating the fixtures. This PR catches it incidentally; a v7.8 follow-up should make `test-v7-5-pipeline.sh` part of CI so future framework expansions update fixtures in the same PR.

## 5. End-to-end verification (T1, all instrumented)

| Gate | Pre-fix (origin/main) | Post-fix (this PR) |
|---|---|---|
| `check-state-schema.py` (full corpus) | 0 findings | 1 finding (designed: hadf-infrastructure CACHE_HITS) |
| `check-state-schema.py` tests | 12 pass | 19 pass (7 new) |
| `integrity-check.py` (cycle-time) | 0 findings + 2 advisories | 0 findings + 2 advisories (unchanged) |
| `measurement-adoption-report.py` post-v6 count | 11 | 11 (broken to 0 mid-PR, then restored) |
| `test-v7-5-pipeline.sh` | 14 pass / 1 fail | 15 pass / 0 fail |
| Per-file diff scope | n/a | `+1/−1` per renamed file, `0/−1` per duplicate-drop, **0 anomalies on round-trip semantic check** |

## 6. What this case study deliberately does not claim

Per the [`measurement case studies must be impartial`](../../.claude/projects/-Volumes-DevSSD-FitTracker2/memory/feedback_measurement_case_study_impartiality.md) feedback rule:

- **Not claimed:** "the gate is now 100% effective." It fires on 1 of 8 post-v6-complete features. Three more features (`cache_hits is None`) bypass via a separate exemption surface that this PR does not close.
- **Not claimed:** "the framework_version field is now reliable." Format-only enforcement is in place; **39 of 46 features still have no value**. Presence-required is deferred until the timeline-backfill PR can map each feature to a real framework version without manufacturing history.
- **Not claimed:** "no other consumer of state.json schema is broken." A grep across `*.py *.ts *.tsx *.js` found one production consumer (fixed) and no others. Confidence is high but not 100% — third-party scripts or future consumers could surface later.

## 7. Cross-references

- Audit input: [`memory: project_framework_gaps_audit_2026_04_30.md`](../../.claude/projects/-Volumes-DevSSD-FitTracker2/memory/project_framework_gaps_audit_2026_04_30.md)
- Bug retrospective: [`memory: project_bug_retrospective_2026_05_01.md`](../../.claude/projects/-Volumes-DevSSD-FitTracker2/memory/project_bug_retrospective_2026_05_01.md)
- Next-session research plan (v7.8): [`memory: project_framework_v7_8_research_plan.md`](../../.claude/projects/-Volumes-DevSSD-FitTracker2/memory/project_framework_v7_8_research_plan.md)
- Parent case study + correction: [`framework-v7-7-validity-closure-case-study.md`](framework-v7-7-validity-closure-case-study.md) §99B
- Schema check script: [`scripts/check-state-schema.py`](../../scripts/check-state-schema.py)
- v7.5 pipeline test: [`scripts/test-v7-5-pipeline.sh`](../../scripts/test-v7-5-pipeline.sh)
- Branch: `chore/framework-honesty-fixes-2026-05-01`

**Tier tags:** all numerical claims in §3 (coverage profile), §5 (verification table), and the front-matter `key_numbers` block are T1 (instrumented sweeps captured live in this session). The narrative observations in §4 (three near-misses) are T1 for the diff stats and gate counts, T3 for the "lessons" extrapolations.
