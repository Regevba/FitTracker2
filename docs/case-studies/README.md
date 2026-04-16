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

## Upcoming case studies (queued)

| Feature | When to write | What it would showcase |
|---|---|---|
| Home (Today Screen) v2 | After v2 ships on `feature/home-today-screen-v2` | First case study of the **V2 Rule** (v1/v2 file + subdirectory convention, project.pbxproj surgery) + second run of `/ux audit` |
| Training Plan v2 | After it ships | Biggest surface in the app — stress-test the per-screen alignment process |

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
