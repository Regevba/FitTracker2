# T14 — Platform-Parity `platforms_tested` State Field — Research

**Feature:** `t14-platform-parity-state-field` · **Phase:** Research → PRD
**Linear:** FIT-162 · **Spec:** `docs/master-plan/test-coverage-master-plan-2026-05-13.md` §4 T14
**Predecessor:** `framework-v7-9-promotion` (gate-extension precedent)
**Researched:** 2026-06-07

## Problem

At `current_phase=complete`, the framework records *that* a feature shipped and
*that* it has a case study, but not *which platforms its tests actually exercised*.
A feature can touch iOS + web + the ai-engine and ship with tests on only one
surface; nothing records or flags the gap. T14 adds a structured
`platforms_tested` field so platform-test parity becomes a queryable, gate-able
property of every completed feature.

Scope is **the field + an advisory closure check + backfill** — explicitly NOT
per-platform coverage *percentages* (that is T15+, separate work).

## Field shape (locked)

```jsonc
"platforms_tested": { "ios": false, "web": false, "backend": false, "ai": false }
```

Platform semantics (locked, mirrored to the dev-guide + fitme-story glossary in T5/T7):

| Key | Means "tests exercised…" | Canonical code surface |
|---|---|---|
| `ios` | the SwiftUI app | `FitTracker/**`, `FitTrackerTests/**` (`*.swift`) |
| `web` | the public site / control-room / dashboard | `fitme-story/**`, `website/**`, `dashboard/**` (`*.ts(x)`) |
| `backend` | sync / persistence / Supabase-Railway server paths | Supabase functions, `*SyncService.swift`, edge functions |
| `ai` | the cohort AI engine | `ai-engine/**` (FastAPI) |

A feature that ran tests on a surface sets that key `true`. A surface it does
not touch stays `false`. "Non-empty" for the gate means **≥1 key is `true`**.

## Research questions — resolutions

### Q1 — Backfill heuristic for the (now 94) existing complete features

**Options weighed:** (a) derive from PR-diff file globs; (b) parse case-study
text for platform keywords; (c) mark all `TBD` and require operator review.

**Decision: (a) deterministic file-glob heuristic, with a provenance flag and a
conservative fallback — never a blocking manual review of all 94.**

`scripts/backfill-platforms-tested.py` derives each complete feature's
`platforms_tested` from the union of evidence it *can* reconstruct without
network calls:

1. The feature's `state.json` signals — `has_ui`, `work_subtype`,
   `scope_summary` / `case_study` text scanned for the platform keywords above.
2. The feature's changed paths where reconstructable from `related_prs` +
   `tasks[].pr_number` against the local `gh-pr-cache.json` (offline-safe; skips
   cleanly when a PR isn't cached).

Each backfilled field carries a sibling provenance marker:

```jsonc
"platforms_tested": { "ios": true, "web": false, "backend": false, "ai": false },
"platforms_tested_provenance": "backfill-heuristic-2026-06-07"
```

Confidence is recorded, not hidden: when the heuristic finds **zero** platform
signal for a *platform-bearing* feature (work_type Feature/Enhancement/Fix with
`has_ui` or platform paths), it writes `"backfill-heuristic-low-confidence"` so
an operator can spot-check just those — not all 94. This directly answers the
kill criterion "operator burden": the default path requires **0** manual review.

### Q2 — Framework-meta features (touch no product platform)

**Decision: EXEMPT, via the existing exemption mechanism — not a forced
all-false.**

Framework-meta / chore features (e.g. `framework-v7-9-promotion`,
`f17-last-fired-at-index`, this feature) touch only `scripts/`, `.claude/`,
`docs/`. Forcing an all-`false` `platforms_tested` on them would be a meaningless
"tested no platform" record and would inflate the empty-array rate the gate
watches. Instead the closure check **skips** a feature when any of:

- `work_type == "chore"`, OR
- `work_subtype == "framework_feature"`, OR
- `case_study_type` ∈ the existing backfill-exemption set
  (`framework_meta_retroactive`, `roundup`, `no_case_study_required`, …).

This mirrors how `FEATURE_CLOSURE_COMPLETENESS` and the sub-phase-vocabulary
check already exempt framework-meta work — no new exemption vocabulary invented.
Backfill writes `platforms_tested: {}` + `platforms_tested_provenance: "exempt:framework_meta"`
for these so the skip reason is self-documenting in Mechanism A telemetry.

### Q3 — Advisory-window length

**Decision: 14 days, per the v7.9 calibration precedent + infra-master-plan
§3.5 calibration protocol.**

Although the *field* is additive/non-breaking, T14 extends an **enforced** gate
(`FEATURE_CLOSURE_COMPLETENESS`), so the A_high calibration discipline applies:
ship the new sub-check in **advisory** mode emitting `{candidates, checked,
skipped, skip_reasons}` to `gate-coverage.jsonl`, measure ≥14 days, then flip
advisory→enforced at the next promotion window (~v7.10) only if all four §2.2
criteria hold (coverage emitted, 0 false positives, no silent skips,
reversibility). Shorter would break consistency with every prior gate
promotion and give too little signal on the Q2 exemption predicate.

## Out of scope (forward pointers)

- Per-platform **coverage %** (lines/branches) — T15+ (depends on R9 Track B
  coverage data, 30-day window opens 2026-07-04).
- Cross-repo parity for fitme-story-native features — handled by the existing
  `state_owner` + reverse-sync contract; `platforms_tested` rides along.

## Risks / kill-criteria mapping (carried into PRD)

| Kill criterion (state.json) | Mitigation from this research |
|---|---|
| False-positive >5% in calibration | Q2 exemption removes the framework-meta false-positive class up front |
| Operator burden / empty arrays | Q1 backfill is automatic; 0 mandatory manual review; low-confidence flag scopes any spot-check |
| Field semantics unclear | Locked 4-key table + dev-guide §3 + fitme-story glossary entry (T5/T7) |
