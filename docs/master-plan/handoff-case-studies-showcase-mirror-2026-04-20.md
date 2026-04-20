# Handoff prompt — Case Study Analysis + Showcase Repo Mirror

> **Purpose:** Self-contained prompt to continue the case study work in a new Claude Code session — especially to mirror the two new case studies into the `fitme-showcase` repo, which wasn't accessible from the previous session.
>
> **Source session:** `session_01YVDk1HyUbAqAMqhMuzxgUU` on branch `claude/analyze-case-studies-obJan`
> **PR opened:** FitTracker2#136
> **Date:** 2026-04-20

---

## Copy-paste prompt for the next session

```
I'm continuing case study work from a prior session. Here's the full context.

## Canonical repo & branch

- Main repo: regevba/FitTracker2 at /Volumes/DevSSD/FitTracker2
- Branch: claude/analyze-case-studies-obJan
- Open PR: https://github.com/Regevba/FitTracker2/pull/136 (title:
  "docs(case-studies): write Home v2 + Training Plan v2, sync pm-workflow
  hub to v6.1")
- Commits on branch:
  - c8a918c — pm-workflow.md hub doc synced v6.0 → v6.1 (added v5.2/v6.0/v6.1
    sections, backfilled case study links on v4.3/v4.4/v5.0/v5.2/v6.0,
    added v6.1 HADF row)
  - 8a1d553 — two new case studies + README reclassification

## What the prior session accomplished

1. Analyzed all 36 case studies in docs/case-studies/ plus 2 in
   meta-analysis/ (38 total).
2. Found that pm-workflow-evolution-v1-to-v4.md is stale — covers v1.0 →
   v4.3 but framework is at v6.1. Decided against rewriting it; it's
   accurate for its window. Individual v4.4/v5.x/v6.x case studies exist
   separately.
3. Cross-referenced open/queued case studies against .claude/features/
   state.json and PRs. Result:
   - WRITE NOW: home-today-screen (PR #61, complete), training-plan-v2
     (PR #74, complete) — both were queued in README.
   - HOLD: dispatch-intelligence-v5.2 (phase=testing),
     onboarding-v2-retroactive (phase=tasks) — not yet shipped.
   - COVERED: hadf-infrastructure (hadf-hardware-aware-dispatch CS),
     meta-analysis-audit (meta-analysis-full-system-audit-v6.1 CS).
4. Wrote two new case studies, grounded in real state.json / PRD / audit
   report data with no fabrication:
   - docs/case-studies/home-today-screen-v2-case-study.md
   - docs/case-studies/training-plan-v2-case-study.md
5. Updated docs/case-studies/README.md:
   - Moved Home v2 + Training v2 to "current contents"
   - Reclassified the other 4 as "pending ship" or "covered elsewhere"
6. Synced docs/skills/pm-workflow.md to v6.1 (title, version history,
   missing case study links).

## What still needs to happen — YOUR TASK

The user flagged that there's a separate showcase repo at
/Volumes/DevSSD/fitme-showcase where ALL case studies must also be
documented. The prior session couldn't reach it (GitHub MCP scope was
restricted to regevba/fittracker2 and the SSD wasn't mounted in that
sandbox).

You need to:

1. Verify the showcase repo exists at /Volumes/DevSSD/fitme-showcase
   (or find its real location — check git remote -v).
2. Inspect its existing case study directory structure — conventions
   may differ from the main repo (different front-matter, different
   path like content/case-studies/ for Next.js sites, etc.).
3. Mirror the two new case studies from the main repo into the showcase
   repo, adapting format as needed:
   - docs/case-studies/home-today-screen-v2-case-study.md
   - docs/case-studies/training-plan-v2-case-study.md
4. Also verify the existing 36 case studies from the main repo are all
   present in the showcase repo. The user said "make sure that these
   case studies are documented in both repo and local" — which implies
   the showcase repo may have drifted. If any are missing, mirror them.
5. If the showcase repo has any README/index that lists case studies,
   update it to include the two new entries.
6. Commit to a feature branch (mirror the main repo branch name:
   claude/analyze-case-studies-obJan) and open a PR against the
   showcase repo's main branch.

## Key facts about the two new case studies (for quick recall)

### home-today-screen-v2-case-study.md
- PR #61, framework v3.0, merged 2026-04-09 as bf3bd67
- V2 Rule pilot — first feature under codified v2/ subdirectory + pbxproj
  swap convention
- Birthplace of screen-prefixed analytics rule (home_*, training_*, etc.)
  — decided in audit Decisions Log OQ-9, now in CLAUDE.md
- 27 findings (8 P0 / 14 P1 / 4 P2 / 1 positive), 17 tasks, 21 tests
- 3 sub-features spawned: onboarding-v2-retroactive,
  home-status-goal-card, metric-tile-deep-linking
- Design tokens added: AppText.metricM, AppText.iconXL,
  AppSize.indicatorDot, AppColor.Chart.{weight,hrv,heartRate,activity}
- Components promoted: AppMetricColumn, AppMetricTile

### training-plan-v2-case-study.md
- PR #74, framework v4.0, shipped 2026-04-10 in ~5 hours
- Biggest surface: 2,135 lines → 6 extracted views + container (1,819 lines)
- First v2 refactor under v4.0 L1 cache — ~40% hit rate on first run
- Best complexity-normalized velocity of any v2 pass: 0.23 h/100 lines
- 32 findings (8 P0 / 16 P1 / 8 P2), 16 tasks, 16 tests
- 12 training_* analytics events (highest of any screen)
- Design tokens added: AppSize.tabBarClearance (56pt), AppText.monoCaption
- Components extracted (app-wide): StatusDropdown, MilestoneModal,
  SetCompletionIndicator
- Sub-features spawned: issue #69 (rest day UX), issue #70 (AI exercise
  recommendations)

## Constraints & rules

- Canonical repo path is /Volumes/DevSSD/FitTracker2 (not /home/user/...
  or /tmp/). Same SSD convention applies to the showcase repo.
- No fabrication — every metric in a case study must be traceable to
  state.json, PRD, audit report, or feature-memory.
- If the showcase repo has a different case study format (e.g. YAML
  front-matter for a Next.js / Astro / MDX site), adapt the content to
  match; don't just copy raw markdown.
- Commit message style: follow the main repo's (see `git log --format='%s'`
  on main).
- Don't skip hooks, don't force-push, don't push to main directly.
```

---

## Supporting reference — where the prior work landed

| Artifact | Path |
|---|---|
| New case study: Home v2 | `docs/case-studies/home-today-screen-v2-case-study.md` |
| New case study: Training v2 | `docs/case-studies/training-plan-v2-case-study.md` |
| Updated README | `docs/case-studies/README.md` |
| Updated hub doc | `docs/skills/pm-workflow.md` |
| Open PR | [FitTracker2#136](https://github.com/Regevba/FitTracker2/pull/136) |
| Branch | `claude/analyze-case-studies-obJan` |
| Key commits | `c8a918c` (pm-workflow sync), `8a1d553` (case studies + README) |

## Candidate state snapshot (from SessionStart hook)

Features flagged as pending/unknown in the active list:

- `dispatch-intelligence-v5.2` — `phase=testing` (case study pending ship;
  partially covered by v5.1-v5.2-framework-evolution-case-study.md Part 2)
- `hadf-infrastructure` — `phase=unknown` (covered by
  hadf-hardware-aware-dispatch-case-study.md)
- `meta-analysis-audit` — `phase=unknown` (covered by
  meta-analysis-full-system-audit-v6.1-case-study.md)
- `onboarding-v2-retroactive` — `phase=tasks` (case study pending ship)

All other 34 features in the hook are `phase=complete`.

## Why the showcase mirror couldn't run in the prior session

1. GitHub MCP tools restricted to `regevba/fittracker2` — any call to
   another owner/repo is denied at the tool layer.
2. Sandbox mount is `/home/user/FitTracker2` — the actual showcase repo
   path `/Volumes/DevSSD/fitme-showcase` is not visible from inside the
   sandbox, so even local file ops against it would fail.

To unblock: either (a) expand the new session's GitHub MCP scope to
include the showcase repo's owner/repo pair, or (b) run the new session
outside the sandbox so `/Volumes/DevSSD/*` is directly accessible, or (c)
manually copy the two files and push yourself.
