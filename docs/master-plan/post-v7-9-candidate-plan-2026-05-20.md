# Post-v7.9 Candidate Plan — Drafted 2026-05-20 (Eve of Promotion)

> **Status:** DRAFT · saved for tomorrow's resume after v7.9 promotion decision lands
> **Drafted:** 2026-05-20 (operator + Claude session)
> **First action tomorrow:** master plan + backlog + sub-plan refresh BEFORE any feature work
> **Resume from:** read this doc top-to-bottom, then proceed in the order below

## 0. CRITICAL PRIORITY ORDER (per operator direction 2026-05-20)

**Before any chore / task / enhancement / feature is advanced, complete the following refresh:**

1. **Master plan §1 / §3.6 / §5 / §10** — `docs/master-plan/infra-master-plan-2026-05-12.md`
2. **Backlog "Done (Shipped)" + "In Progress"** — `docs/product/backlog.md` (~30 entries missing since 2026-04-09; 6 weeks of drift)
3. **Sub-plan refresh** — every spec/plan referenced in this doc must be reviewed for staleness; explicit list in §6 below
4. **MEMORY.md "Latest" entry fix** — D1 drift correction (says #411 OPEN; it's MERGED)
5. **New cold-start entrypoint** — `.claude/entrypoints/framework-v7-9.md` (per master plan §2.3 side-effects)

Estimated effort for prerequisite refresh: **~4-5 hours focused work**.

**Do NOT start any work below until §0 lands.**

---

## 1. v7.9 Promotion Side-Effects (TOMORROW's freeze-day work)

Per infra-master-plan §2.3 — these MUST ship as part of (or immediately after) the v7.9 promotion PR:

| # | Action | File | Effort |
|---|---|---|---|
| C-1 | Drop 2 enforced gate IDs from CLAUDE.md "Known Mechanical Limits" advisory list | `CLAUDE.md` | 10 min |
| C-2 | Flip `BRANCH_ISOLATION_ADVISORY_MODE = False` in `scripts/check-state-schema.py` | `scripts/check-state-schema.py` | 5 min |
| C-3 | Create cold-start entrypoint `framework-v7-9.md` | `.claude/entrypoints/framework-v7-9.md` (new) | 20 min |
| C-4 | Update dev-guide §2.4 "promoted" sub-section | `docs/architecture/dev-guide-v1-to-v7-7.md` | 10 min |
| C-5 | Add honesty ledger entry FT2-FH-002 | `trust/honesty-ledger.md` | 10 min |
| C-6 | Open Linear epic FIT-72 v7.9-promotion + sub-issues per flipped gate | (Linear) | 10 min |
| C-7 | Author v7.9 promotion case study | `docs/case-studies/v7-9-promotion-case-study.md` (new) | 1-1.5h |

**Total v7.9-day side-effects: ~2h 10min**. Bundle into a single FT2 PR with `[DO NOT MERGE pre-v7.9]` removed.

---

## 2. Open PRs to Merge Tomorrow Post-Promotion (in order)

| PR | Title | Status | Action |
|---|---|---|---|
| FT2 #413 | UCC hardening Phase 8 docs | MERGEABLE, BEHIND main, CI green | Rebase → push → merge |
| FT2 #415 | ucc-sign-in reconcile + W14 | MERGEABLE, BEHIND main, CI green | Rebase → push → merge |
| FT2 #416 | fitme-story discoverability plan | MERGEABLE, CI flake on `EncryptionServiceTests -34018` (known) | Re-run CI → drop `[DO NOT MERGE pre-v7.9]` prefix → merge |
| **NEW** TBD | This post-v7.9 candidate plan doc | Draft (see §6 commit instructions) | Commit on new branch after master plan refresh |
| **NEW** TBD | v7.9 promotion side-effects (per §1 above) | Pending tomorrow's authoring | Open + merge after promotion |
| **NEW** TBD | Master plan + backlog refresh (per §0 above) | Pending tomorrow's authoring | Open + merge first |

---

## 3. Tasks (Within Existing Features; Calendar-Gated)

| # | Title | Owner | When | Effort |
|---|---|---|---|---|
| T-1 | **B11** UCC hardening T+3d calibration check | Operator | **2026-05-22** | 15 min |
| T-2 | **B8** Parent UCC T+7d kill-criteria (K1/K2/K3) | Operator | **2026-05-23** | 30 min |
| T-3 | **B12** UCC hardening T+7d kill-criteria → advance to complete | Operator + bot | **2026-05-27** | 1.5h |
| T-4 | **B2** Post-v7.9 baseline snapshot | Operator | **2026-05-28** | 10 min |
| T-5 | **B9** UCC Part 8 — passkey-only flip decision | Operator | **2026-05-28+** | 30 min |
| T-6 | **B3** Daily GA4 anomaly check (recurring) | Operator + GA4 MCP | Daily | 5 min/day |
| T-7 | `ucc-passkey-auth-audit-log-redis-fix` — finish last 1 of 9 tasks | Auto | 2026-05-22 | 30 min |
| T-8 | `fitme-story-public-enhancements` T13 — mirror v7.9 outcome to /framework/dev-guide | Auto | **2026-05-22** (UNBLOCKS post-v7.9) | 1h |
| T-9 | UCC Part 7 — break-glass YubiKey / 2nd device | Operator | Before **2026-05-28** | 30-60 min |
| T-10 | `ucc-sign-in-figma-mapping` T4 — Build AuthPasskeyForm 10 component variants in Figma | Auto (figma-use skill) | 2026-05-23+ | 2-3h dedicated session |
| T-11 | `ucc-sign-in-figma-mapping` T10 — figma-code-connect-publish CI green | Auto | Post-T4 | Validation only |
| ~~T-12~~ | ~~Sentry DSN paste + iOS SDK init~~ | — | **PAUSED 2026-05-21 → pre-launch** | — |
| ~~T-13~~ | ~~`/mcp` Sentry OAuth connection~~ | — | **PAUSED 2026-05-21 → pre-launch** | — |
| **T-14** | **[AI]** HADF Phase 2-bis pre-Sub-exp-1 safety verification ceremony (6-item) | Operator + auto | **2026-05-23** morning | 1h |
| **T-15** | **[AI]** HADF Sub-exp 1 verdict + kill-criteria evaluation | Operator + auto | ~**2026-05-26** | 1h |
| **T-16** | **[AI]** HADF Sub-exp 2 verdict | Same | ~2026-05-30 | 1h |
| **T-17** | **[AI]** HADF Sub-exp 3 verdict + anchor-drift trip-wire | Same | ~2026-06-03 | 1h |

**Total task time over 7-day calibration window: ~10-12 hours** spread across calendar gates.

---

## 4. Chores

| # | Title | Effort | Notes |
|---|---|---|---|
| C-8 | backlog.md "Done (Shipped)" backfill — ~30 entries since 2026-04-09 (D2) | 30-45 min | Non-infra |
| C-9 | backlog.md "In Progress" refresh (D3) | 10 min | Non-infra |
| C-10 | infra-master-plan §10 change log (2026-05-20 + 2026-05-21 entries) (D5) | 15 min | Non-infra |
| C-11 | MEMORY.md "Latest" entry stale-correction (D1) | 2 min | Local memory; no PR |
| C-12 | Open Linear FIT-63 sub-issue for UCC hardening (T26 from tasks.md) | 5 min | Operator action |
| **C-13** | **[Backend]** Document `ai-engine/` deployment status (Railway? Vercel? local-only?) | 1h | Currently no clear record |
| ~~C-14~~ | ~~**[AI]** Verify Orchid v1.5 Track L+D preserved + Track R unblock conditions~~ **CLOSED 2026-05-24** — ✅ Paused state intact. Tracks L + D-partial(D1+D2) shipped; D-D3 + R blocked per documented resume signal (v1 SoC Phase 5 + Orchid v1 toolchain install). All `paused.*` invariants present. No drift detected. Report: [`docs/audits/runs/2026-05-24-c14-orchid-v1-5-status/audit-report.md`](../audits/runs/2026-05-24-c14-orchid-v1-5-status/audit-report.md). | ~~30 min~~ done | Per memory `project_orchid_v1_5_paused_at_track_l_d.md` |
| ~~C-15~~ | ~~Master plan §3.1 — add funnel-dashboards + `/ops digest` as F-22 / F-23 candidates~~ **CLOSED 2026-05-24** — F-22 (Funnel Analysis Dashboards) + F-23 (`/ops digest` skill) confirmed present at `infra-master-plan-2026-05-12.md:178-179`. Sentry F-21 PAUSED row at line 177. Both candidates ready for v8.0 docket. | ~~20 min~~ done | ~~Required before §5 features can be scheduled~~ done |

---

## 5. Enhancements (4-Phase: Tasks → Implement → Test → Merge)

| # | Title | Parent | Scope | Effort | Gate-trip risk |
|---|---|---|---|---|---|
| E-1 | **W11 durable fix** — `scripts/preflight.py` resolve `state.json::parent_feature` | preflight (v7.8.6) | scripts/ infra-path | 2-3h | 🔴 Isolated worktree |
| ~~E-2~~ | ~~**W13 durable fix** — `redis-client.ts` dual-name fallback (KV_* + UPSTASH_REDIS_REST_*)~~ **CLOSED — already shipped 2026-05-21** via fitme-story `src/lib/auth/redis-client.ts:21-22` (`process.env.UPSTASH_REDIS_REST_URL ?? process.env.KV_REST_API_URL`). Verified during session 2026-05-24. | fitme-story auth | Pure code | ~~1h~~ done | 🟢 Low |
| E-3 | **OQ-4** — elevate `auth_lockout_blocked_attempt` to weekly digest | ucc-passkey-auth-security-hardening | scripts/+workflow | 2-3h | 🔴 Isolated worktree |
| ~~E-4~~ | ~~**Phase 3.B** — wire `dashboard_*` event call-sites in `/control-room/*` pages~~ **CLOSED 2026-05-25 (verification, not new work).** 2026-05-25 survey: 7 of 8 `dashboard_*` events already have working call-sites; the candidate-plan entry was inherited from a pre-2026-05-23 audit and is stale. Wiring breakdown: `trackDashboardLoad` → [`TrackPageView.tsx:69`](https://github.com/Regevba/fitme-story/blob/main/src/components/control-room/TrackPageView.tsx#L69); `trackBlockerAcknowledged` → [`InstrumentedAlertsBanner.tsx:44`](https://github.com/Regevba/fitme-story/blob/main/src/components/control-room/InstrumentedAlertsBanner.tsx#L44); `trackViewChange` → [`TrackedNavLink.tsx:70`](https://github.com/Regevba/fitme-story/blob/main/src/components/control-room/TrackedNavLink.tsx#L70); `trackFilterApply` → [`TableViewClient.tsx:253`](https://github.com/Regevba/fitme-story/blob/main/src/app/control-room/table/TableViewClient.tsx#L253) (+2 more); `trackKnowledgeOpen` → [`TrackedDocLink.tsx:38`](https://github.com/Regevba/fitme-story/blob/main/src/components/control-room/TrackedDocLink.tsx#L38); `trackExternalLink` → [`TrackedExternalLink.tsx:36`](https://github.com/Regevba/fitme-story/blob/main/src/components/control-room/TrackedExternalLink.tsx#L36) (+1); `trackSyncWarningShown` → [`TrackPageView.tsx:82`](https://github.com/Regevba/fitme-story/blob/main/src/components/control-room/TrackPageView.tsx#L82). The 8th event (`trackKanbanDrag`) has 0 call-sites — **intentional STUB** per analytics-taxonomy line "UCC T36 — STUB. Helper shipped for future drag-to-update; current Wave 1 Kanban port is read-only." | analytics-observability | fitme-story product code | ~~4-6h~~ done | 🟢 Low |
| ~~E-5~~ | ~~Smart Reminders ↔ Push Notifications v2 deep-link integration~~ **CLOSED 2026-05-24 via PR #466** — wired `.fitMeReminderTapped` NotificationCenter broadcast → `DeepLinkRouter.handle(url:source:.notification)`. ~30 LOC (scaffold was already in place: ReminderNotificationDelegate posts, DeepLinkRouter handles URLs — missing observer was the bridge). +2 XCTests. Tapping smart-reminder notification now actually navigates instead of opening to last-active screen. | smart-reminders + push-notifications-v2 | iOS-side | ~~1-2 days~~ done in ~1h | 🟢 Low |
| E-6 | **C-2** Web PR JS test gate (fitme-story CI) — RICE 200 | test-coverage T6 | fitme-story workflow | 2-3h | 🟡 Workflow file |
| ~~E-7~~ | ~~**C-3** Sentry reachability test (iOS) — RICE 80~~ — **PAUSED 2026-05-21 → pre-launch** (rides Sentry pause; resume when SDK init lands) | test-coverage T2 | iOS code | 2-3h | 🟢 Low |
| ~~E-8~~ | ~~**F14/F15** dispatch-test coverage push (per cadence B6)~~ **CLOSED 2026-05-23 via PR #451 squash `86084c4` + backfill #452 + closure #455.** 161/161 pytest pass; combined dispatch-test coverage 1/19 → 10/19 = 53%. | preflight + state-schema | scripts/+tests/ | ~~3-4h~~ done | 🔴 Isolated worktree |
| ~~E-9~~ | ~~**[AI]** Smart Reminders Behavioral Learning PR-2~~ **RE-DEFERRED 2026-05-25 → app_store_launch trigger.** Pre-flight gate (per [PR-2 plan](../superpowers/plans/2026-05-04-smart-reminders-behavioral-learning-pr2.md) "DO NOT START Task 1") requires `cohort_stats.reminders.*` rows ≥ ~10 per cell across `nutrition_gap` / `training_day` / `rest_day` segments. 2026-05-25 verification: Supabase project `hwbbdzwaismlajtfsbed` reactivated (was paused on free-tier inactivity), BUT the underlying data-accumulation blocker is structural — the app is pre-launch (TestFlight only), no real users producing reminder observations. Bayesian per-user posterior + Supabase server-cohort prior cannot calibrate against operator-only TestFlight traffic. Same disposition class as **D-2** (GA4 conversions config re-deferred today to `app_store_launch`): zero meaningful signal in pre-launch traffic = vanity numbers, not measurement. Reactivate when App Store launch is scheduled + first 5-10 days of real-user data accumulate. | smart-reminders + ai-engine | iOS + backend code (Phase E safe) | ~~1-2 days~~ deferred | 🟡 iOS+backend; isolated worktree |
| ~~E-10~~ | ~~Sentry SDK init in iOS app + 1 test event~~ — **PAUSED 2026-05-21 → pre-launch** | sentry-integration | — | — | — |
| ~~E-11~~ | ~~`/ops health` reads Sentry crash-free rate~~ — **PAUSED 2026-05-21 → pre-launch** | sentry-integration | — | — | — |
| ~~E-12~~ | ~~**[AI]** `ai-engine/` Dockerfile audit + deployment-target reconfirm~~ **CLOSED 2026-05-24** — ✅ Healthy. Railway target confirmed; `python:3.12-slim` pinned base; 14-line clean Dockerfile; no layer bloat; deps floor-pinned identical to last verified state (2026-04-20). Report: [`docs/audits/runs/2026-05-24-e12-e13-ai-engine-cohort/audit-report.md`](../audits/runs/2026-05-24-e12-e13-ai-engine-cohort/audit-report.md). | ai-engine-architecture-adaptation | Backend deploy | ~~1-2h~~ done | 🟢 Low (config) |
| ~~E-13~~ | ~~**[AI]** Cohort intelligence telemetry audit — verify federated learning loop still emitting~~ **CLOSED 2026-05-24** — ✅ Healthy. Loop emits via 5 endpoints (`asyncio.create_task` fire-and-forget). Schema stable since initial migration. iOS read/write loop closed via `/reminder-cohort-priors`. Zero `cohort_stats` rows at TestFlight stage expected, not breakage. Report: [`docs/audits/runs/2026-05-24-e12-e13-ai-engine-cohort/audit-report.md`](../audits/runs/2026-05-24-e12-e13-ai-engine-cohort/audit-report.md). | ai-cohort-intelligence | Backend + iOS | ~~1h~~ done | 🟢 Low (audit) |
| **E-14** | **F-LAUNCHD-DRIFT-EXTENSION** — extend `BRANCH_ISOLATION_LAUNCHD_DRIFT` advisory + `ensure-pr-cache-fresh.py` for launchd-cron context: (a) advisory checks plist path existence + canonical form (would have caught 2026-05-19 SSD-migration drift on day 1, not day 5); (b) W11.b mitigation — `ensure-pr-cache-fresh.py` must propagate refresh subprocess failure instead of `--quiet \|\| true` swallow; OR `daily-integrity-checkpoint.py` re-validates `gh auth status` before trusting cron-captured integrity-check output; OR pre-warm cache from interactive shell daily. **Trigger:** 2026-05-19 SSD migration silently broke cron 5 days + 2026-05-24 launchd cron produced 319 phantom BROKEN_PR_CITATION findings (per observed-patterns.md W11.b). | framework integrity / observability (`BRANCH_ISOLATION_LAUNCHD_DRIFT` + cron freshness wrapper) | infra (`scripts/` + plist) | 3-4h | 🔴 Isolated worktree |
| **E-15** | **F-CONTRACT-FIXTURE-SAMPLING** — `make sample-contract-fixtures` target in FT2 that copies one production row per cross-repo data feed (`gate-coverage.jsonl`, `measurement-adoption.json`, `documentation-debt.json`, `integrity-cycle/snapshots/*.json`) into `tests/fixtures/cross-repo-contracts/`. fitme-story prebuild step asserts live data file's keys are a superset of fixture keys. Closes the silent-pass class where consumer tests use hand-written fixtures that match the consumer's wrong assumption instead of the canonical producer schema. **Trigger:** 2026-05-24 — `/control-room/framework` returned a 200 OK error boundary for 13 days because `gate-coverage-aggregator.ts` expected `event.ts` but FT2 `scripts/gate_coverage.py` emits `event.timestamp`. Hotfix: fitme-story PR #146 (defensive normalization + alias accept). Catalog entry: observed-patterns.md W16. Stacks with F16 try-repo harness — F16 covers *intra-repo* gate fixtures, F-CONTRACT-FIXTURE-SAMPLING covers *cross-repo* data contracts. | observability (no new gate; tests + sampling target) | infra (`scripts/` + `Makefile` + cross-repo fixture dir) + fitme-story prebuild | 4-6h | 🔴 Isolated worktree (Makefile + scripts/) |

**Total enhancement time: ~37-45 hours** (was ~33-39h pre-E-15) spread across sprints. Most needing infra-path worktrees should wait until Phase E exit (~2026-06-04).

---

## 6. Features (Full 10-Phase)

| # | Title | Status | When | Effort |
|---|---|---|---|---|
| F-1 | **[AI]** HADF Phase 2-bis Sub-experiment 1 — cloud generalization (9 endpoints incl. Vercel AI Gateway) | tasks_phase | **2026-05-23** | ~$3-5 / ~3 days wall-clock |
| F-2 | **[AI]** HADF Sub-exp 2 — cloud-vs-local separability (Ollama M2) | Gated on Sub-exp 1 verdict | **~2026-05-27** | $0 / ~3 days |
| F-3 | **[AI]** HADF Sub-exp 3 — decisive same-model routing | Gated on Sub-exp 2 | **~2026-05-31** | ~$1 / ~3 days |
| F-4 | **[AI]** HADF cross-sub-exp synthesis case study + Track 6 gate activation | Gated on Sub-exp 3 | **~2026-06-07** | 4-6h synthesis + N hours gate work |
| F-5 | `3d-interactive-framework-flow-diagram` | prd phase | scheduled_after v7.9.1 (~**2026-06-11**+) | Multi-week |
| F-6 | `analytics-observability` Phase 1.B / 2 / 3.B remaining | implementation (12/15 done) | Post-Phase-E (~**2026-06-04**+) | 4-6h Phase 3.B + 5-8h other |
| F-7 | **v8.0 docket prioritization T29** | Phase 9 pass | **2026-05-21** | 2-3h RICE |
| F-8 | **fitme-story discoverability plan execution** | PR #416 to merge tomorrow | Phases 1-4 over **2026-05-21 → 06-30** | ~11-13h spread |
| F-9 | **v7.9.1 build** — F16 try-repo harness + F17 last_fired_at + F2/F6 | Window ~**2026-06-04** | F16 ~3 days; rest ~1 day each | ~6-10 days total |
| F-10 | **v8.0 build** — top-per-theme docket from F1-F18 + V8-I + test-coverage T1-T16 | Build kickoff ~**2026-06-18** | Multi-week | Ship target 2026-07-31 |
| ~~F-11~~ | ~~Sentry full integration (full PM cycle: Phase 0 → 9)~~ — **PAUSED 2026-05-21 → pre-launch.** Operator decision: app is pre-launch (TestFlight beta only); crash-free-rate observability is not actionable until App Store launch. Adapter + SDK wiring preserved. Resume preconditions: App Store submission ≤2 weeks + consent toggle decision finalized + pre-public-launch checklist opens this. | Adapter exists; no PM-workflow opened | — | — |
| **F-12** | **[Backend]** Funnel Analysis Dashboards (GA4 + /control-room/analytics + per-funnel metric definitions) | Not started; depends on Phase 3.B (E-4) | Post-Phase-E (~**2026-06-04**+) | ~5-7 days |
| **F-13** | **[Backend]** `/ops digest` skill — weekly stakeholder summary | Adapter scaffold exists | Depends on F-11 + F-12 | ~3-4 days |
| **F-14** | **[AI]** Orchid v1.5 Track R — research orchestration on real cohort | Paused 2026-05-03; Track R blocked | Unblock TBD | ~10+ days |

---

## 7. Sub-Plan Refresh List (per §0 prerequisite)

These specs/plans need explicit review before any related work advances:

| Plan | What to verify | Effort |
|---|---|---|
| `infra-master-plan-2026-05-12.md` §1 anchor + §3.6 + §5 + §10 | Add v7.9 outcome; sequence v7.9.1 candidates concretely | 1h |
| `docs/superpowers/plans/2026-05-12-framework-v7-8-5-to-v8-2-implementation-plan.md` | Confirm F2/F6 are spec-defined (not placeholders) | 30 min |
| `docs/superpowers/specs/2026-05-11-hadf-phase2bis-replication-design.md` | Pre-Sub-exp-1 verification ceremony refresh; confirm 4 architectural fixes in place | 15 min |
| `docs/superpowers/specs/2026-05-08-framework-v7-9-candidates.md` | Mark F-candidates as PROMOTED / DEFERRED / RESOLVED based on tomorrow's decision | 20 min |
| `docs/master-plan/must-have-cadence-followups.md` (post-merge of PR #413) | Verify B11+B12 on main; add any new follow-ups discovered during v7.9 freeze | 15 min |
| `docs/case-studies/data-quality-tiers.md` | Confirm T1/T2/T3 tier vocabulary still current after v7.9 promotion | 10 min |
| `trust/honesty-ledger.md` | Add FT2-FH-002 v7.9 promotion entry | 15 min |
| **NEW** `docs/case-studies/ai-engine-deployment-snapshot-2026-05-21.md` | One-page narrative: where ai-engine/ runs, what's wired, what's stale | 1h |
| `docs/architecture/dev-guide-v1-to-v7-7.md` | §2.4 promoted sub-section per v7.9 side-effects | 10 min |

**Total sub-plan refresh: ~3.5-4h** (in addition to master plan §0 work).

---

## 8. Suggested Sequencing — First 2 Days Post-v7.9

```
2026-05-21 FREEZE DAY:
  Morning (1h)    — v7.9 promotion decision + B1.1-B1.7 checklist
  Mid-day (3h)    — Master plan refresh (§0 prereq) +
                    Sub-plan refresh (§7) +
                    MEMORY.md fix (D1)
  Afternoon (2h)  — v7.9 promotion side-effects PR (§1)
  Evening (30 min) — Merge yesterday's queued PRs: #413 (rebase), #415 (rebase),
                    #416 (drop prefix + re-CI), this candidate-plan PR

2026-05-22 (Calibration day 1):
  Morning (1h)    — Backlog.md backfill (C-8) +
                    Backlog "In Progress" refresh (C-9) +
                    Master plan §10 change log entries (C-10)
  Mid-day (2h)    — T-1 B11 check + T-7 audit-log-redis-fix close +
                    T-8 fitme-story T13 mirror
  Afternoon            — (Sentry block PAUSED 2026-05-21 → pre-launch;
                          T-12/T-13/E-10 dropped from today's plan)
```

**~9-10h focused work over 2 days**. Then HADF launches 2026-05-23, calibration week proceeds per the schedule in §3.

---

## 9. Aggregate Time Estimates

| Bucket | Items | Estimated effort |
|---|---|---|
| §0 Master plan + sub-plan + backlog prereq | C-8, C-9, C-10, C-11, sub-plan refresh, ai-engine snapshot, FT2-FH-002 | **~4-5 hours** |
| §1 v7.9 promotion side-effects | C-1 → C-7 | ~2h 10min |
| §3 Calendar-gated tasks | T-1 → T-17 | ~10-12 hours over 7 days |
| §4 Other chores | C-13, C-14, C-15 | ~2 hours |
| §5 Enhancements | E-1 → E-13 | ~30-35 hours (post-Phase-E) |
| §6 Features | F-1 → F-14 | ~3-5 weeks active + 10+ weeks long-tail |
| **Calibration week TOTAL** | (prereq + side-effects + tasks + some enhancements) | **~24-27 hours over 7 days** |
| **Phase E to v8.0 build** | (enhancements + new features + v7.9.1 + v8.0) | **~3-5 months wall-clock** |

---

## 10. Resume Instructions for Tomorrow

1. **Read this doc top-to-bottom** (you're here)
2. **Open today's session entries:** [[project-session-2026-05-20-v7-9-eve-ga4-audit]] for state of telemetry + GA4 audit + UCC hardening
3. **First action:** open the v7.9 promotion PR (or run the decision via tomorrow's freeze-day checklist)
4. **Second action:** master plan refresh per §0 prerequisite
5. **Third action:** merge queued PRs (#413, #415, #416, this doc's PR)
6. **Fourth action:** begin calibration-week tasks per §8 schedule
7. **Throughout:** consult [`fitme-story-discoverability-plan-2026-05-20.md`](./fitme-story-discoverability-plan-2026-05-20.md) for the showcase site work

## 11. Cross-References

- v7.9 promotion plan: `docs/master-plan/infra-master-plan-2026-05-12.md` §2
- Discoverability plan: `docs/master-plan/fitme-story-discoverability-plan-2026-05-20.md`
- HADF Phase 2-bis design: `docs/superpowers/specs/2026-05-11-hadf-phase2bis-replication-design.md`
- v7.9 candidates: `docs/superpowers/specs/2026-05-08-framework-v7-9-candidates.md`
- Cadence followups: `.claude/shared/must-have-cadence-followups.md`
- Observed patterns: `.claude/integrity/observed-patterns.md`
- Today's session memory: `~/.claude/projects/-Volumes-DevSSD-FitTracker2/memory/project_session_2026_05_20_v7_9_eve_ga4_audit.md`
- UCC hardening shipped: `~/.claude/projects/-Volumes-DevSSD-FitTracker2/memory/project_ucc_passkey_security_hardening_2026_05_19.md`

## 12. Status as of 2026-05-20 22:00Z

- ✅ v7.9 pre-freeze health: GREEN
- ✅ UCC hardening: SHIPPED + production-validated (4/6 T20 LIVE)
- ✅ Audit-log pipeline: RESTORED (CRON_SECRET fix at 12:14Z)
- ✅ 6 PRs merged today: FT2 #410/#411/#412/#414 + fitme-story #127/#128
- 🔵 3 PRs open: FT2 #413 (Phase 8 docs), #415 (reconcile), #416 (discoverability — DO-NOT-MERGE prefix)
- 🆕 This candidate plan: drafted; NOT YET committed
- ⏳ Tomorrow: v7.9 promotion + master plan refresh + this plan committed

**Save your rest. v7.9 is tomorrow.** 🌙
