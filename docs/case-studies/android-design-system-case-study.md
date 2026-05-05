---
title: "Android Design System — Case Study"
date_written: 2026-05-05
work_type: Feature
dispatch_pattern: serial
success_metrics:
  primary: "Token mapping coverage 92/92 iOS tokens → MD3 equivalents [T1 — counted in research.md]. De-risks future Android port; no user-facing surface to measure."
  secondary:
    - "Component parity audit 13/13 [T1 — counted in research.md]"
    - "Style Dictionary Android config compiles end-to-end against existing tokens.json [T1 — `style_dictionary_config_ready: true`]"
kill_criteria:
  - "Defer Android expansion if iOS core not stable. The deliverable IS the kill criterion: no Android code shipped, only mapping documentation; if Android port never starts, the artifact is reference material that cost ~30 minutes."
case_study_type: pre_pm_workflow_backfill
parent_case_study: "docs/case-studies/six-features-roundup-case-study.md"
predecessor_case_studies: []
status: shipped
framework_version: pre-v5.0
ship_date: 2026-04-04
pr_merge_commit: f033e5d
---

# Case Study: android-design-system

> **Status:** Shipped 2026-04-04 (pre-PM-workflow rule, backfilled 2026-05-05)
> **Framework version:** pre-v5.0
> **Case study type:** `pre_pm_workflow_backfill` — written retroactively from the existing PRD + research + tasks; no fabrication
> **Parent (until split 2026-05-05):** [`six-features-roundup-case-study.md`](six-features-roundup-case-study.md)

## 1. One-line headline

A 92-token iOS → Material Design 3 mapping exercise that never ships a line of Android code, because it explicitly wasn't meant to.

## 2. Summary card

| Field | Value |
|---|---|
| Scope | Token mapping documentation + Style Dictionary Android config |
| PR / commits | `f033e5d` (feat — 6 files, +763 lines), `f6564d2` (docs — Phase 9/9 completion) [T1] |
| Work type | Feature (research-only) |
| RICE score | 4.8 (MEDIUM priority) |
| Transitions | 3 — `init → research → prd → complete` on 2026-04-04 [T1] |
| Phases skipped | Tasks / UX / Implementation / Testing / Review (all marked `skipped`, rationale: "Research-only deliverable") [T1] |
| Wall time | ~30 minutes [T2 declared, derived from transition timestamps] |

## 3. What shipped

Three files drive the deliverable:
- `design-tokens/config-android.json` (47 lines) — configures Style Dictionary's Android output
- `docs/design-system/android-token-mapping.md` (310 lines) — the comprehensive iOS → MD3 mapping reference
- `.claude/features/android-design-system/research.md` (201 lines) — the decision record

Metrics: `tokens_mapped` 92/92, `component_parity_audit` 13/13, `style_dictionary_config_ready` true [T1 — counted in research.md].

## 4. Research findings worth preserving

Per the PRD:
- **46 colors → MD3 role mapping** with hex
- **22 typography styles → MD3 type scale**
- **8 spacing tokens** (4pt grid → dp grid, 1:1)
- **6+ radius values → MD3 shape categories**
- **2 shadow presets → MD3 tonal elevation**
- **4 motion categories → MD3 motion specs**

Dark mode: how FitMe's opacity-based system would map to MD3 dark theme. Style Dictionary generates `.kt` files from `tokens.json` alongside the existing Swift output.

## 5. Why no dedicated case study at ship time

The feature's deliverable is documentation. A case study of a documentation deliverable would effectively be a summary of the documentation — a doc about a doc. The feature exists to de-risk *future* Android work, and nothing about the research is novel to the PM workflow itself. Kill criterion on the feature ("Defer Android expansion if iOS core not stable") confirms: nothing shipped to users, nothing to narrate about user impact.

This dedicated case study was split out 2026-05-05 as part of the chain-of-custody initiative (full-repair-mode plan, Decision 3 + Q1 = Option 3 hybrid split). It exists primarily as the PM-workflow reference example for **research-only deliverables**: PRDs that legitimately skip Phases 3–8 with a rationale recorded on every skipped phase.

## 6. Chain of custody

Source artifacts (all present pre-2026-04-13 rule, retained verbatim):

| Artifact | Path | Lines |
|---|---|---|
| PRD | [`.claude/features/android-design-system/prd.md`](../../.claude/features/android-design-system/prd.md) | 116 |
| Research | [`.claude/features/android-design-system/research.md`](../../.claude/features/android-design-system/research.md) | 201 |
| Tasks | [`.claude/features/android-design-system/tasks.md`](../../.claude/features/android-design-system/tasks.md) | 56 |
| State | [`.claude/features/android-design-system/state.json`](../../.claude/features/android-design-system/state.json) | — |
| Merge commits | `f033e5d` (feat — 6 files, +763 lines), `f6564d2` (docs — Phase 9/9 completion) | — |
| Token mapping doc | [`docs/design-system/android-token-mapping.md`](../../docs/design-system/android-token-mapping.md) | 310 |
| Android tokens config | `design-tokens/config-android.json` | 47 |

(No `ux-spec.md` exists for this feature — research-only, no UX surface.)

## 7. What a full live-pm-workflow case study would have additionally recorded

The four-hour research → prd → complete compression — the whole cycle ran inside ~30 minutes on 2026-04-04 — as an example of the PM workflow handling a documentation deliverable cleanly (skip Phases 3-8 explicitly, not implicitly, with a rationale recorded on every skipped phase).

## 8. Cross-feature lesson

**Research-only deliverables are a real work type, not a degenerate one.** Android DS explicitly skipped Phases 3-8 with a rationale on every skipped phase. This is the template for documentation-deliverable features: research and PRD execute normally, everything downstream is skipped with an explicit note, and the metrics target the deliverable (`tokens_mapped` 92/92) not user behavior. The PM workflow already supports this; Android DS is the reference example.

## Links

- **State:** `.claude/features/android-design-system/state.json`
- **Source PRD/research/tasks:** `.claude/features/android-design-system/`
- **Token mapping deliverable:** [`docs/design-system/android-token-mapping.md`](../../docs/design-system/android-token-mapping.md)
- **Companion case studies (split out same day from same roundup):** [`gdpr-compliance-case-study.md`](gdpr-compliance-case-study.md), [`google-analytics-case-study.md`](google-analytics-case-study.md)
- **Original roundup parent:** [`six-features-roundup-case-study.md`](six-features-roundup-case-study.md)
- **Showcase:** to be published as part of full-repair-mode plan PR-F
