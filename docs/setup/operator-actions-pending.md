# Operator Action Register

> **Purpose:** the single list of actions that **only the operator (Regev) can do** —
> things the agent cannot complete autonomously (external dashboards, GitHub UI
> merges, repo settings, hardware/asset work, dated decisions). Updated at the end
> of sessions that produce new operator-gated items.
>
> **Last updated:** 2026-06-08. Cross-references the calendar-anchored cadence ledger
> at [`.claude/shared/must-have-cadence-followups.md`](../../.claude/shared/must-have-cadence-followups.md).

---

## A. Immediate — open from the 2026-06-08 session

| # | Action | Where | Notes |
|---|---|---|---|
| A1 | **Configure GA4 conversions (D-2)** — mark `workout_complete` + `nutrition_meal_logged` as **Key events** | GA4 → Admin → Key events | Runbook: [`docs/setup/ga4-funnels-and-conversions-runbook.md`](ga4-funnels-and-conversions-runbook.md). Exact case-sensitive names. Needs Editor/Admin on the GA4 property; allow 24–48h to populate. After done, tell the agent to flip D-2 `deferred → complete`. |
| A2 | **Merge PR #678** (analytics-observability closure) after CI | GitHub PR #678 | UNSTABLE = mergeable (required checks green; any red is non-required). Per-PR approval required. |
| A3 | **Resolve the 3 stuck bot PRs** — #675 (weekly snapshot), #676 (UCC audit-log sync), #658 (integrity cycle snapshot) | GitHub UI | All green/low-stakes but `github-actions[bot]`-authored → GitHub holds them BLOCKED (workflows don't re-trigger for bot PRs). Either: (a) **let the next cron supersede them** (zero effort), or (b) push an empty commit to re-trigger checks as you, or (c) web-UI merge. None carry risk. |
| A4 | *(optional)* Decide whether to build **F-CONTRACT weekly re-sample cadence** | — | Low value (fixtures fresh to 2026-06-14, gate is warn-only); would add another auto-PR-on-cron. Agent recommends a drift-only cron if you want it. Say go/skip. |

## B. Repo settings — one-time (fixes recurring friction)

| # | Action | Where | Why |
|---|---|---|---|
| B1 | Enable **"Allow auto-merge"** + **"Allow updating pull request branches"** | GitHub → Settings → General → Pull Requests | `allow_update_branch` is currently **false** → the UI "Update branch / Update with rebase" button is unavailable, which is why behind/merge-commit bot PRs (#658-class) can't be rebased from the UI. Enabling restores that path. |

## C. Deferred features — operator-owned (not agent-completable)

| Feature | Gate / what's needed | State |
|---|---|---|
| **app-store-assets** | 5/10 assets done; remaining need operator design/export work (screenshots, preview, etc.) | `implementation`, deferred per 2026-05-08 |
| **3D Universe Phase 4** (`3d-interactive-framework-flow-diagram`) | Parked at prod-**404** for animation polish (operator decision 2026-06-06). Re-launch needs: hero glTF assets, Theatre.js scrub, Rive/poster, + the re-launch checklist in `src/app/framework/universe/page.tsx`. ~16 of 36 Phase-4 tasks remain, mostly asset/operator-gated. | `tasks_phase`, owner=fitme-story |
| **orchid-v1-5** | Track R blocked on orchid v1 SoC Phase 5 (upstream) | `implementation` |
| **hadf-phase3a-sensing** | Detection layer shipped; **acting** layer gated on RQ4 (operator experiment decision; Phase 3B not started) | `implementation` |
| **Sentry integration** | DSN + MCP wiring deferred until App Store launch | paused |

## D. Calendar-anchored verifications/decisions (agent runs; operator confirms)

> Full detail + strikethrough history in [`.claude/shared/must-have-cadence-followups.md`](../../.claude/shared/must-have-cadence-followups.md).

| Date | Item | Operator role |
|---|---|---|
| 2026-06-11 | F-LAUNCHD-DRIFT-EXTENSION + F-DEPLOYED-URL-PROBE T+7d verification | confirm |
| 2026-06-12 | **External Audit #2** | operator-driven (run the audit-prompt substrate) |
| 2026-06-18 | F16 try-repo advisory→enforced flip decision | approve |
| 2026-06-20 | W9 branch-drift Phase 2 | approve |
| 2026-06-21 | t14 `PLATFORMS_TESTED` advisory→enforced flip (B15) | approve |
| 2026-07-04 | R9 Track B 30-day coverage read → v8.0 `GATE_TEST_MISSING` calibration | review |

## Done this session (no action — for the record)

- **style-dictionary v3→v5 migration** — shipped & golden-verified (PR #677); Dependabot #668 auto-closed.
- **gitleaks-action v2→v3** — merged (#669); also fixed the post-June-2 Node-20 v2 failures.
- **CI token-pipeline path filter** — merged (#674); a future bare token-dep major bump now fails at PR time, not post-merge.
- **F-DEPLOYED-URL-PROBE fitme-story workflow** — merged (fitme-story #212); W18/W19 covered end-to-end in production.
- **#655 reverse-sync** — closed as superseded (3D→404 already on main via #654).
