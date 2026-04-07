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

- **Rollback overhead:** Rolling back mid-flight cost ~10 minutes (state.json rewrite + GitHub sync + branch rename). Prevention: run `/ux` phase properly on first pass for all future features.
- **Skipped phase detection:** `state.json.phases.ux_or_integration.status == "skipped"` is the primary audit signal for retroactive alignment candidates.
- **Prior art discovery:** Always grep `docs/project/` for `figma-{feature}-*` before Phase 3 — hand-crafted prompts may already exist. (Saved ~1 session for this run.)
- **Audit agent failure mode:** Background `/ux audit` agent hit `max_tokens` loop trying to write a 8000-token report in one Write call. Fix: take over in main session OR instruct agent to write report in chunks.
- **Latent bug discovery via alignment:** v1 onboarding had **5 latent compile bugs** that prevented the build from ever succeeding (analytics.logEvent privacy, missing screenClass overload, missing AppRadius.card, FitMeBrandIcon not in Xcode target, Onboarding folder not in Xcode target). The audit + patching surfaced ALL of them. This is unexpected high value beyond the alignment scope itself.
- **Xcode target membership trap:** Files created by Claude in /Volumes/DevSSD/.../FitTracker/ are not automatically added to project.pbxproj target membership. Going forward, every new Swift file must be added to the Xcode target via the project.pbxproj OR via Xcode UI manually. The CI build is the only signal that catches this.
- **pbxproj merge friction:** When user added files via Xcode then we rebased/branch-switched, Xcode duplicated file references at unexpected paths (Settings/Onboarding, Shared/Onboarding). Manual cleanup required 3 commits. Future fix: tell user to add files to a stable canonical group BEFORE branching.
- **Manual confirm gate efficiency:** User pre-approved all 4 batches of 24 audit findings in one shot ("approve all"). Real-world PM workflow gates often collapse if findings are well-categorized and the user trusts the audit. Save manual gates for genuinely contested decisions, not P0 mechanical fixes.

## Phase outcomes (filled post-execution)

| Phase | Started | Ended | Outcome |
|-------|---------|-------|---------|
| 0 — Research | (v1) 2026-04-05 | (v1) 2026-04-05 | Retained from v1; no v2 changes |
| 1 — PRD v2 | 2026-04-07 11:30 | 2026-04-07 12:00 | Appended `# v2 — UX Alignment` section to `prd.md`, approved as drafted |
| 2 — Tasks v2 | 2026-04-07 12:00 | 2026-04-07 12:10 | 12 V2-T* tasks added to `tasks.md`, approved |
| 3 — UX (audit + spec) | 2026-04-07 12:10 | 2026-04-07 13:00 | 24-finding audit report, ux-research.md, ux-spec.md created. User approved all 4 batches in single round. Figma v2 build deferred. |
| 4 — Implementation | 2026-04-07 13:00 | 2026-04-07 13:30 | 20 patches in commit `e46788a`. Plus 4 follow-up build-fix commits resolving v1 latent bugs. |
| 5 — Testing | 2026-04-07 13:30 | 2026-04-07 17:10 | Build green, tokens-check green, all tests pass on iPhone 17 sim. Multi-iteration debugging of Xcode target membership consumed most of this phase. |
| 6 — Review | 2026-04-07 17:10 | (in progress) | Risk review + merge timeline doc created (`docs/project/onboarding-v2-merge-timeline.md`). |
| 7 — Merge | pending | pending | Single PR planned (Option A — full branch consolidation). |
| 8 — Documentation | pending | pending | Post-merge: feature-memory, CHANGELOG, backlog, state.json complete. |

## Findings summary (Phase 3 audit)

**Total findings:** 24 (P0: 6, P1: 11, P2: 7)

**By category:**
| Category | Count | Examples |
|----------|-------|----------|
| Analytics gaps | 4 | permission_result never fired, onboarding_skipped never fired, screen tracking used string literals |
| Token compliance | 7 | raw shadow values, raw `.frame(height: 52)`, raw `.white`, raw `.easeInOut(duration: 0.3)` |
| UX behavior | 5 | no back navigation, no haptic feedback, no Dynamic Type scroll wrappers, silent HealthKit denial, no loading state |
| Copy + content | 4 | "Apple Health" terminology, "Ready to maintain?" weak copy, skip transparency footers, iPad fallback copy |
| Deferred to follow-up | 4 | component consolidation, additional a11y hints, contrast bump, pillar text size |

**Overall:** Patch (not rebuild). v1 structure was sound; only mechanical alignment was needed.

## Manual confirm rounds

| Round | Items | Decision |
|-------|-------|----------|
| 1 | All 24 findings (4 batches: analytics, tokens, UX behaviors, copy) | User: "approve all" |

Single round was sufficient because findings were well-categorized and patches were mechanical.

## Audit trail integrity

State.json `transitions[]` array contains 11 transitions documenting every phase change with timestamp + approver + reason. Manual rollback (`testing → prd`) is recorded with `approved_by: "user-manual"` per skill spec.

GitHub issue regevba/fittracker2#51 has phase labels updated at every transition (`phase:research → phase:prd → ... → phase:done`).

---

## Phase 7+8 closure (post-merge)

### Merge details
- **PR:** [regevba/fittracker2#59](https://github.com/Regevba/FitTracker2/pull/59)
- **Squash commit on main:** `66e42cf` "feat: onboarding v2 UX alignment + 4-day branch consolidation (#59)"
- **Method:** `gh pr merge 59 --squash --delete-branch`
- **Date:** 2026-04-07 18:06
- **Branch:** `feature/onboarding-ux-align` deleted from local + remote
- **Build sanity post-merge:** ✅ `xcodebuild build` clean on main (iPhone 17 sim)

### Phase 8 doc updates committed in single follow-up commit on main
| File | Change |
|------|--------|
| `CHANGELOG.md` | Prepended "2026-04-07 — Onboarding v2 UX Alignment + 4-Day Branch Consolidation" entry covering shipped features, fixed latent bugs, verification, backwards compat, deferred items, first metrics review |
| `docs/design-system/feature-memory.md` | Prepended full feature memory entry per repo template (date, problem, tokens, components, new primitives, wireframe, UI decisions, a11y, Android, follow-ups, latent bugs fixed, references) |
| `docs/product/backlog.md` | Marked "Onboarding flow" as shipped (was unchecked since v1 PRD) with PR #59 reference |
| `.claude/features/onboarding/state.json` | `current_phase = complete`, all phases approved, branch=main, 4 final transitions added, first_review_date set to 2026-04-14 |
| `docs/project/pm-workflow-showcase-onboarding.md` | This closure section appended |

### First metrics review
- **Date:** 2026-04-14 (1 week post-merge)
- **Primary metric:** onboarding completion rate, target >80%
- **Secondary metrics:** HealthKit auth rate >85%, D1 retention >60%, time-to-first-session <24h
- **Kill criteria:** redesign if completion rate <50% after 30 days
- **Owner:** Regev (per PRD)

### Change broadcast (per pm-workflow skill)
On merge to main, the following downstream skills should be notified per the change broadcast protocol:
- `/qa` — new code merged. Run regression check on next cycle. Onboarding flow + 4 days of consolidation work need full smoke pass.
- `/cx` — onboarding shipped to user-facing flow. Monitor user feedback for confusion or completion drop-off in first week.
- `/analytics` — verify 5 new GA4 events fire correctly in production: `permission_result`, `onboarding_step_viewed`, `onboarding_step_completed`, `onboarding_skipped`, `onboarding_goal_selected`. Verify in Firebase debug view.
- `/ops` — deployment pending. Monitor crash-free rate post-launch (guardrail >99.5%).
- `/design` — design system gained 4 new token groups (AppSize, AppMotion, AppShadow.ctaInverse*, AppRadius.card). Verify Figma library catches up via the runner prompt at `docs/project/figma-runner-prompt.md`.
- `/marketing` — first launchable build of FitMe with full onboarding. Coordinate with marketing-website launch and TestFlight submission.

### What this run proved about the enhanced /pm-workflow skill
1. **Manual rollback works as designed** — `testing → prd` rollback preserved v1 phase audit trail under `v1_*` fields and produced a coherent v2 lane without losing state.
2. **PRD versioning via append (not separate file) works** — single `prd.md` with `# v2 — UX Alignment` section keeps v1 + v2 history together and maintains a single approval gate.
3. **Audit-driven implementation works** — Phase 3 audit produced concrete file:line findings that mapped 1:1 to Phase 4 patches with no scope creep.
4. **Feature-by-feature alignment is feasible** — onboarding completed end-to-end in a single multi-session push. Sequence is now ready for the next feature.
5. **Latent bug discovery is a bonus** — running an alignment audit on a "complete" feature surfaced 5 compile-blocking bugs that had been latent for days.
6. **Manual confirm gates can be batched** — single "approve all" round was sufficient for 24 well-categorized findings. Save micro-gates for genuinely contested decisions.
7. **GitHub issue label sync stays in lockstep** — every phase transition updated #51 labels automatically; the dashboard view stayed honest the whole time.

### Next feature in alignment sequence
Per user directive ("feature by feature"), the next target is **`home-today-screen`** — highest user-impact surface (Home tab is the launch screen), densest interaction, sets the tone for the rest of the alignment pass. Invoke with `/pm-workflow home-today-screen` to begin.

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
