# PM-Flow Hub Showcase — Onboarding v2 UX Alignment

> **Purpose:** Exemplar walkthrough of the enhanced `/pm-workflow` skill running a **retroactive UX alignment** on a feature whose UX phase was skipped. Documents every phase, gate, decision, and hook invocation so future alignment runs have a reference.
>
> **Companion to:** `.claude/skills/pm-workflow/SKILL.md`, `docs/design-system/ux-foundations.md`, `docs/project/figma-onboarding-v2-prompt.md`
>
> **Feature under showcase:** `onboarding`
> **Initiative:** UX Alignment v2 (feature-by-feature sequential pass)
> **Started:** 2026-04-07
> **Branch:** `feature/onboarding-ux-align` (renamed from `claude/review-code-changes-E7RH7`)
> **GitHub issue:** regevba/fittracker2#51

---

## Why onboarding is the pilot

1. **Mid-flight:** phase was `testing` (CI not yet green) — rollback doesn't affect shipped users
2. **Known gap:** v1 `ux_or_integration` phase was **skipped** with reason *"UX defined inline in PRD and task descriptions"* — no `ux-spec.md`, no Figma screens, no design compliance gate
3. **First impression:** onboarding is the user's first contact with FitMe — highest leverage surface for design system alignment
4. **Prior art available:** `docs/project/figma-onboarding-v2-prompt.md` already specifies 6 v2 screens with token mappings — accelerates Phase 3

---

## Governing rules (locked for this run)

| Rule | Value |
|------|-------|
| Rollback target | `prd` (Option A — full re-flow, PRD v2 section approved through the skill's gate) |
| Branch strategy | Rename current branch to `feature/onboarding-ux-align`; keep v1 code as baseline on the branch |
| PRD v2 location | Append v2 section to existing `.claude/features/onboarding/prd.md` (single continuous PRD, not a separate file) |
| Figma master file | `0Ai7s3fCFqR5JXDW8JvgmD` — preserve existing "I3.1 — Onboarding Slides" as history, create new "I3.2 — Onboarding v2 (PRD-Aligned)" section |
| UI change gate | For every visual/flow delta from current code, pause → present before/after + rationale tied to `ux-foundations.md` principle → user approves manually before landing |
| Approval mode | **Option A** — strict phase-by-phase user approval (per CLAUDE.md default) |
| Kill criteria | Abandon v2 alignment if >4 high-risk code files need touching beyond v1 footprint |

---

## Phase log

### Phase 0 — Research (APPROVED from v1, not re-executed)
- **v1 file:** `.claude/features/onboarding/research.md` (127 lines)
- **Status:** Retained. v1 research into onboarding patterns, competitive analysis, and GA4 event taxonomy remains valid. v2 does not change the problem — only how the solution aligns with foundations.

### Phase 1 — PRD v2 (IN PROGRESS — current)
- **v1 file:** `.claude/features/onboarding/prd.md` (231 lines)
- **v2 action:** append `## v2 — UX Alignment` section to same file
- **Inputs:**
  - `docs/design-system/ux-foundations.md` (1,533 lines, 10 parts) — compliance target
  - `docs/project/figma-onboarding-v2-prompt.md` (209 lines) — Figma target state
  - v1 shipped code on feature branch — drift baseline
- **Outputs for approval:**
  - Changelog (v1 → v2)
  - Compliance matrix (dimensions to be validated in Phase 3)
  - Scope of changes (flow, screens, copy, a11y, motion)
  - Metrics delta (if any)
  - Migration notes
  - Risk register (v1 + v2 cumulative)

### Phase 2 — Tasks v2 (PENDING)
- Will produce a revised task list tied to gaps discovered in Phase 3 audit
- v1 tasks (T1-T10) retained as `version: v1` with `status: done`
- v2 tasks will be prefixed `V2-T*`

### Phase 3 — UX / Design Compliance Gate (PENDING)
- This is the phase that was SKIPPED in v1 — the root cause of the alignment gap
- Sub-steps:
  1. **UX Research** — `.claude/features/onboarding/ux-research.md` (new file): applicable ux-foundations principles, iOS HIG references, external research
  2. **UX Audit** — `/ux audit onboarding` against `ux-foundations.md`: compliance matrix per principle
  3. **Design Audit** — `/design audit onboarding`: token + component compliance per view
  4. **UX Spec** — `.claude/features/onboarding/ux-spec.md` (new file): screen list, flows, states, copy, a11y, motion per feature-development-gateway.md
  5. **Figma v2 screens** — execute `figma-onboarding-v2-prompt.md` via Figma MCP in this session, creating 6 screens under new "I3.2" section. **Manual confirm gate:** any delta from current code presented to user for approval before Figma is populated.
  6. **Design System Compliance Gateway** — run the 5 compliance checks (token / component / pattern / a11y / motion). Must pass before Phase 4.

### Phase 4 — Implementation (PENDING)
- On `feature/onboarding-ux-align` branch
- Applies approved deltas as patches to v1 code (not rewrites)
- Each patch is a discrete commit referencing the Figma node ID it aligns to

### Phase 5 — Testing (PENDING)
- Re-run `make tokens-check && xcodebuild build && xcodebuild test`
- Re-verify analytics events still fire (v1 analytics tests + any new v2 events)
- Visual regression if possible

### Phase 6 — Review (PENDING)
- Diff vs `main` — assess risk on high-risk files
- Verify CI green on branch AND main

### Phase 7 — Merge (PENDING)
- PR title: `feat(onboarding): v2 UX alignment per ux-foundations.md`
- Squash-merge to `main`
- Change broadcast (per PM skill)

### Phase 8 — Documentation (PENDING)
- Update `docs/design-system/feature-memory.md` with any token/component evolution
- Close feature lifecycle

---

## Transitions recorded

See `.claude/features/onboarding/state.json` → `transitions` array.

Key entry (rollback):
```json
{
  "from": "testing",
  "to": "prd",
  "timestamp": "2026-04-07T11:30:00Z",
  "approved_by": "user-manual",
  "note": "Manual rollback for v2 UX alignment initiative. v1 UX phase was skipped; re-entering PRD phase to append v2 section aligning to ux-foundations.md. v1 code preserved. First feature in sequential alignment effort. Branch renamed from claude/review-code-changes-E7RH7 to feature/onboarding-ux-align."
}
```

---

## Decision log

| # | Decision | Rationale | Date |
|---|----------|-----------|------|
| 1 | Rollback to `prd` (not just `ux_or_integration`) | PRD v2 needs a real approval gate through the skill; can't just add content without re-running PRD phase | 2026-04-07 |
| 2 | Rename branch (don't create new from main) | v1 onboarding code lives only on current branch; a fresh branch from main would lose it | 2026-04-07 |
| 3 | Append v2 to same `prd.md` (not separate file) | User directive: "documented within the respected PRD as v2 — continuous effort" | 2026-04-07 |
| 4 | Preserve Figma v1 section, create v2 section alongside | User directive: "don't override the current pages and keep them for history" | 2026-04-07 |
| 5 | Manual confirm gate on every UI delta | User directive: "for any UI change from the current design alert and confirm manually before proceeding" | 2026-04-07 |
| 6 | Sequential feature-by-feature (not umbrella) | User directive: "work and build feature by feature" | 2026-04-07 |
| 7 | Reuse existing `figma-onboarding-v2-prompt.md` as Phase 3 starting point | Reduces Phase 3 effort; prompt was hand-crafted with full token mappings | 2026-04-07 |

---

## Lessons captured (for future alignment runs)

_To be filled as phases complete._

- **Rollback overhead:** Rolling back mid-flight costs ~10 minutes (state.json rewrite + GitHub sync + branch rename). Prevention: run `/ux` phase properly on first pass for all future features.
- **Skipped phase detection:** `state.json.phases.ux_or_integration.status == "skipped"` is the primary audit signal for retroactive alignment candidates.
- **Prior art discovery:** Always grep `docs/project/` for `figma-{feature}-*` before Phase 3 — hand-crafted prompts may already exist.

---

## Cross-links

- PM skill definition: `.claude/skills/pm-workflow/SKILL.md`
- UX skill: `.claude/skills/ux/SKILL.md`
- Design skill: `.claude/skills/design/SKILL.md`
- UX foundations doc: `docs/design-system/ux-foundations.md`
- Figma v2 prompt: `docs/project/figma-onboarding-v2-prompt.md`
- Feature PRD: `.claude/features/onboarding/prd.md`
- Feature state: `.claude/features/onboarding/state.json`
- GitHub issue: regevba/fittracker2#51
- Branch: `feature/onboarding-ux-align`
