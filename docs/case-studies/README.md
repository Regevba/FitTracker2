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

## Upcoming case studies (queued)

| Feature | When to write | What it would showcase |
|---|---|---|
| Home (Today Screen) v2 | After v2 ships on `feature/home-today-screen-v2` | First case study of the **V2 Rule** (v1/v2 file + subdirectory convention, project.pbxproj surgery) + second run of `/ux audit` |
| Training Plan v2 | After it ships | Biggest surface in the app — stress-test the per-screen alignment process |
| Dashboard v1.1 automation pass | After the iOS hardening PR merges | Case study of an Enhancement work type running cross-cutting infra changes (Vercel serverless + GitHub Actions + CI additions) |

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
