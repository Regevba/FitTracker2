# Case Studies

> Real examples of the `/pm-workflow` skill running a feature through its full lifecycle. Each case study is a narrative showcase — it shows how the 10-phase lifecycle + the 11-skill ecosystem actually played out on a live feature, what worked, what was deferred, and what the end state looked like.

---

## What goes here

This folder collects **concrete case studies** of features that have been shipped through the PM workflow. Each one should answer:

1. **What feature?** — name, scope, work type
2. **Why this case study?** — what made it worth documenting (first of its kind, pilot, teaching example, etc.)
3. **Which phases ran and in what order?** — the 10-phase lifecycle in practice, including any skipped or deferred phases
4. **Which skills were dispatched at which phase?** — the hub-and-spoke flow in action
5. **What got produced at each phase?** — the artifacts (research.md, prd.md, ux-spec.md, patches, tests, etc.)
6. **What decisions were made?** — especially compliance gateway outcomes (fix / evolve DS / override)
7. **What shipped vs what was deferred?** — and why
8. **What would I do differently next time?** — lessons for future features

## What doesn't go here

- Skill definitions — those live in `docs/skills/`
- Feature PRDs — those live in `docs/product/prd/`
- Session handoffs / resume docs — those live in `docs/master-plan/`
- Per-feature state — that lives in `.claude/features/{name}/`

A case study is a **story about a completed (or in-flight) feature**, not the feature's specification. The PRD is the spec; the case study is the narrative of what happened when the PM workflow met the spec.

## Current contents

| File | Feature | Why it's here |
|---|---|---|
| `pm-workflow-skill.md` | `/pm-workflow` skill itself (v1 → v2) | Original showcase of the PM skill as a self-referential case study — shows the skill being applied to its own development |
| `pm-workflow-showcase-onboarding.md` | Onboarding v2 UX Foundations alignment | **Pilot case study** for the per-screen UX alignment initiative. First feature to run through the new /ux skill's full loop (audit → research → spec → compliance → patches). Reference implementation for future v2 refactors |
| `fittracker-evolution-walkthrough.md` | FitMe product evolution (multi-release narrative) | High-level walkthrough of how the product evolved through major release cycles — broader than a single-feature case study but structurally similar |
| `original-readme-redesign-casestudy.md` | The original README redesign | Historical case study of how the public-facing README was rewritten. Shows the design + content iteration loop in action |
| `pm-workflow-evolution-v1-to-v4.md` | PM workflow evolution v1.0 → v4.3 | Comprehensive 3-level analysis (micro/meso/macro) of how the hub-and-spoke PM ecosystem evolved across 6 screen refactors — now extended with the operational-layer promotion that followed |
| `cleanup-control-room-case-study.md` | Maintenance cleanup + operations control room | First maintenance-focused case study and the launch story for v4.3: uses the PM framework to reconcile repo truth, design/UX review, planning sync, dashboard evolution, and process monitoring in one integrated cleanup cycle |
| `control-center-alignment-ia-refresh-case-study.md` | Control center alignment + IA refresh | Follow-up operational case study focused on turning the dashboard into a clearer multi-workspace operating surface with routed knowledge, research, Figma handoff, and case-study views |
| `eval-layer-v4.4-case-study.md` | Eval-Driven Development (v4.4) | First eval layer case study — shows how 20 deterministic evals (golden I/O, quality heuristics, tier behavior) were added to the framework lifecycle |
| `user-profile-v4.4-case-study.md` | User Profile Settings (v4.4) | Most comprehensive process case study — full experiment design with independent/dependent variables and complexity assessment |
| `soc-v5-framework-case-study.md` | SoC-on-Software (v4.4 → v5.0 → v5.1) | Framework infrastructure case study — shows 7 chip architecture principles applied to reclaim 63% context overhead |
| `ai-engine-architecture-v5.1-case-study.md` | AI Engine Architecture (v5.1) | First feature executed under v5.1 SoC optimizations — 13 tasks, 17 files at 5.1 min/CU (+66% vs baseline) |
| `onboarding-v2-auth-flow-v5.1-case-study.md` | Onboarding v2 Auth Flow (v5.1) | Highest velocity case study — 47.7 CU at 2.1 min/CU (+86% vs baseline). Includes real-world issues found in manual testing |
| `v5.1-parallel-stress-test-case-study.md` | v5.1 Parallel Stress Test | Flagship stress test — 4 features, 54 min, 35 tests, 0 failures. Proved parallel multi-agent PM lifecycle at scale |
| `v5.1-v5.2-framework-evolution-case-study.md` | Framework v5.1 → v5.2 Evolution | Two-part case study: Part 1 documents stress test findings, Part 2 documents Dispatch Intelligence design and validation |
| `parallel-write-safety-v5.2-case-study.md` | Parallel Write Safety (v5.2 Sub-Project B) | Framework safety infrastructure — snapshot/rollback + 3-tier mirror pattern. Deployed in 20 min, pure config/protocol (no Swift code) |
| `framework-measurement-v6-case-study.md` | Framework Measurement v6.0 | First feature with deterministic measurement instrumentation — measured (not estimated) wall time, CU v2 continuous factors, cache-hits.json, eval coverage gates. 28.0 CU at 3.21 min/CU (+79% vs baseline) |
| `meta-analysis/` | Meta-analysis reports folder | Cross-case analyses: Nvidia validation of normalization model + What-If v6.0 retrospective experiment (CU v2 recalculation, rolling baselines, AI model cost comparison, ROI analysis) |
| `hadf-hardware-aware-dispatch-case-study.md` | HADF — Hardware-Aware Dispatch Framework (v6.1) | First hardware-aware framework extension — 5-layer architecture (device detection → cloud fingerprinting → evolutionary learning), 17 chip profiles across 6 vendors, 7 cloud hardware signatures, zero-regression confidence gate. Novel contribution: cloud inference fingerprinting via Mahalanobis distance classification |
| `meta-analysis-full-system-audit-v6.1-case-study.md` | Full-System Meta-Analysis Audit (v6.1) | First self-referential full-system audit — 4-layer risk-weighted sweep, 185 findings across 6 domains (12 critical, 49 high), external validation, framework self-audit with bias acknowledgment. Key discovery: fabrication-over-nil systemic pattern in AI adapters. Health scorecard: AI 0, Backend 0, Tests 0, UI 9, Framework 42, DS 46 |
| `home-today-screen-v2-case-study.md` | Home Today Screen v2 (v3.0) | **V2 Rule pilot** — first feature to apply the `v2/` subdirectory + pbxproj-swap convention after it was codified. Also the feature where OQ-9 of the audit produced the project-wide **screen-prefixed analytics naming rule** (`home_*`, `training_*`, etc.). 27 findings, 17 tasks, 3 sub-features spawned (Onboarding retro, Status+Goal merged card, Metric Tile Deep Linking) |
| `training-plan-v2-case-study.md` | Training Plan v2 (v4.0) | Biggest surface in the app — 2,135 lines → 6 extracted views. First v2 refactor under the L1 cache; shipped in 5h with ~40% cache hit rate. Achieved the best complexity-normalized velocity (0.23 h/100 lines) of any v2 pass despite being the largest file. 32 findings, 16 tasks, 12 analytics events (highest of any screen) |
| `audit-remediation-program-185-findings-case-study.md` | **Audit Remediation Program — 185 Findings** (v6.1, program synthesis) | End-to-end synthesis of the v6.1 meta-analysis audit + 6-sprint remediation program. 185 findings surfaced → 183 closed in-project (98.9%) + 2 classified on documented external blockers = **100% in-project closure**. Covers post-stress-test bulk (50), M-3, M-1, M-2, M-4, and Path A. Surfaced 9 framework bugs (F1–F9) during remediation. First time framework was used to close findings from its own audit |
| `push-notifications-case-study.md` | Push Notifications (v5.2) | First feature to complete a full v5.2 PM lifecycle end-to-end — 12 tasks, 18 tests, 10 analytics events, 2 critical review findings caught pre-merge. Honest finding: the priming view (`NotificationPermissionPrimingView`) shipped tested + merged but was never wired into nav (UI-016). No user has seen it. Documents the shipped-without-a-door failure mode |
| `smart-reminders-case-study.md` | Smart Reminders (v5.1 stress test) | 1 of 4 features advanced simultaneously during the v5.1 Adaptive Batch parallel stress test. 14 tasks, 17 tests, 5-guard scheduler (quiet hours + global daily + per-type daily + per-type lifetime + 4h min interval). Flagged stress-test PM hygiene gap: phases testing/review/merge/documentation stayed `pending` despite feature being `complete` |
| `import-training-plan-case-study.md` | Import Training Plan (v5.1 stress test) | Parser / mapper / orchestrator stack shipped with 23 tests (CSV/JSON/Markdown parsers, 3-tier confidence mapper, @MainActor state machine). Honest finding: entry-point views annotated `HISTORICAL —` three days post-ship (UI-015) and `confirmImport()` doesn't persist — documents "phase-complete ≠ feature-live" and a concrete 3-change revival path |
| `six-features-roundup-case-study.md` | **Six-Feature Backlog Roundup** (consolidation) | Honest consolidation case study for 6 features that either pre-dated the case-study-every-feature rule (2026-04-13) or were research-only. Covers ai-cohort-intelligence, android-design-system, development-dashboard, gdpr-compliance, google-analytics, and stats-v2. Proposes a three-condition threshold for when a dedicated case study is worth writing vs when a roundup row is the honest answer |

## Upcoming case studies (queued)

| Feature | Status | What it would showcase |
|---|---|---|
| Dispatch Intelligence v5.2 | **pending ship** — currently `phase=testing`; partially covered by `v5.1-v5.2-framework-evolution-case-study.md` Part 2 | Dedicated post-ship narrative of the 3-stage dispatch pipeline, tool budgets, and permission routing once stress-test validation completes |
| Onboarding v2 Retroactive | **pending ship** — currently `phase=tasks`; feature still in planning | Validation that the V2 Rule scales backward to a pre-rule feature with multiple screens. Short mini-study planned after the retro refactor merges |

## Features covered elsewhere (no dedicated case study planned)

| Feature | Why not | Existing coverage |
|---|---|---|
| hadf-infrastructure | Rolls up into the HADF case study | `hadf-hardware-aware-dispatch-case-study.md` |
| meta-analysis-audit | Rolls up into the audit case study + the remediation-program synthesis | `meta-analysis-full-system-audit-v6.1-case-study.md` + `audit-remediation-program-185-findings-case-study.md` + `meta-analysis/` folder |
| ai-engine-v2, ai-recommendation-ui, readiness-score-v2 | Sub-features of adaptive-intelligence | `ai-engine-architecture-v5.1-case-study.md` |
| home-status-goal-card, metric-tile-deep-linking | Sub-features of home-today-screen | `home-today-screen-v2-case-study.md` |

## How to write a new case study

1. **Copy an existing one as a template.** `pm-workflow-showcase-onboarding.md` is the most complete example.
2. **Title format:** `{feature-slug}-case-study.md` or `pm-workflow-showcase-{feature}.md` (both conventions exist).
3. **Structure:** Context → PRD summary → Phase walkthrough → Decisions → Metrics → Lessons.
4. **Link back to artifacts.** Don't inline the whole PRD or ux-spec; link to `docs/product/prd/` and `.claude/features/` for the source files.
5. **Link forward from the feature's `state.json`.** Add the case study path to `state.json.documentation_path` so the feature row can find it.

## Related documents

- [`../skills/README.md`](../skills/README.md) — ecosystem one-pager
- [`../skills/architecture.md`](../skills/architecture.md) — deep-dive architecture
- [`../skills/pm-workflow.md`](../skills/pm-workflow.md) — the hub skill
- [`../product/backlog.md`](../product/backlog.md) — Done/In Progress/Planned tracker
- [`../../.claude/features/`](../../.claude/features/) — per-feature state.json + supporting artifacts
