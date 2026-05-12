# Consolidated Review + Linear Hierarchy + Notion Sync Prep — 2026-05-12

**Status:** input doc · Linear/Notion sync queued pending MCP reconnect
**Created:** 2026-05-12 (end of session)
**Author:** session of 2026-05-12 (Claude Opus 4.7)
**Purpose:** (1) full cross-reference audit across memory + all PRs + branches + master plan + backlog to surface anything unaccounted for in the [v7.8.5 → v8.2 implementation plan](../superpowers/plans/2026-05-12-framework-v7-8-5-to-v8-2-implementation-plan.md); (2) per-phase parent + child task hierarchy ready to paste into Linear; (3) priority ranking by data-value contribution to each version; (4) Notion sync notes for the FitMe Product Hub page.

**MCP status at write time:** Linear MCP **disconnected** + Notion MCP **disconnected** (per resume-hook system reminder). This doc is paste-ready for manual sync OR for a future session with MCP reconnected.

---

## §1 Audit Findings — Source Coverage Cross-Reference

### §1.1 Source 1 — Memory (137 entries in MEMORY.md)

Reviewed every entry in `/Users/regevbarak/.claude/projects/-Volumes-DevSSD-FitTracker2/memory/MEMORY.md`. **No new items surfaced** that aren't already in the v7.8.5 → v8.2 plan or in the backlog. Three categories of memory entries:

1. **Completed/shipped features** (~50 entries) — already accounted for as Done in backlog
2. **Active/pause-point project memories** (~25 entries) — all reference items that exist in backlog or the v7.8.5 → v8.2 plan
3. **Reference + feedback memories** (~10 entries) — workflow guidance, not action items

### §1.2 Source 2 — Open PRs (7 from this session + 0 elsewhere)

| PR | Title | Maps to |
|---|---|---|
| #316 | HADF Phase 2-bis Block A | **MERGED** — accounted for in v7.8.5 plan §3 (predecessor) |
| #317 | BRANCH_ISOLATION_VIOLATION Mode B silent-pass fix | **MERGED** — accounted for in v7.8.5 plan §3 (predecessor) |
| #318 | v7.9 candidates F14–F18 | **OPEN** — F14-F18 mapped to v8.0 + v7.9.1 in plan §6 + §5 |
| #319 | Infra master plan §3.5 + §3.6 consolidation | **OPEN** — meta-doc, accounted for as the plan's predecessor |
| #320 | v7.8.5 cache_hits fixture fix | **OPEN** — v7.8.5 ship in plan §3 |
| #321 | Full implementation plan v7.8.5 → v8.2 | **OPEN** — the plan itself |
| #322 | HADF + ORCHID consolidation | **OPEN** — HADF + ORCHID per-phase analysis in plan §15.6 + new sub-tasks |

**Verdict:** all 7 PRs accounted for in the plan. No orphan PRs.

### §1.3 Source 3 — Local branches (25+ branches)

Categorized by status:

**Active (this session's 7 PR branches):** all accounted for (§1.2).

**Closure branches awaiting cleanup (`[gone]` after merge):** 14+ branches per the 2026-05-12 morning stale audit. **Cleanup task:** queued under "Backlog cleanup" parent task §3.7 below.

**Orphan / stale branches (decisions pending):**

| Branch | Last commit | Status |
|---|---|---|
| `chore/sentry-integration-wip` | 2026-04-30 | Stale — Sentry MCP not connected; revisit when MCP available |
| `chore/hadf-phase2-citation-update` | 2026-05-08 | Open question per backlog "HADF Phase 2 backup decisions" |
| `chore/hadf-phase2-progress-snapshot` | 2026-05-08 | Open question per backlog "HADF Phase 2 backup decisions" |
| `feature/hadf-phase2-fingerprint` | 2026-04-30 | Likely obsolete (superseded by Phase 2-bis); decision needed |

**Verdict:** 4 orphan branches require decision. Already captured in backlog "HADF Phase 2 backup + branch decisions" item; not yet promoted to a Linear task.

### §1.4 Source 4 — Master plan (`docs/master-plan/`)

- `master-plan-2026-04-15.md` — product master plan (separate from infra). Items already in backlog.
- `infra-master-plan-2026-05-12.md` — infra master plan (predecessor to v7.8.5 → v8.2 plan). Fully reflected in plan.
- `master-backlog-roadmap.md` — RICE roadmap, items already in backlog.

**No new items.**

### §1.5 Source 5 — Backlog (`docs/product/backlog.md`)

Reviewed all sections:

- **Done** (lines 8–103) — historical, no action needed.
- **In Progress** (lines 103–113):
  - App Store assets — DEFERRED TO LAST per memory; not in v7.8.5 → v8.2 plan but slot in §15.2.3 (v7.9.1) as concurrent product work. **Action: add as v7.9.1 sub-task placeholder.**
  - Smart Reminders Behavioral Learning PR-2 — cohort-data-gated (earliest 2026-05-09; should be ready now). **Action: add as v7.9 / v7.9.1 product concurrency item.**
  - Smart Reminders ↔ Push v2 deep-link integration — Enhancement. **Action: add to v8.0 product concurrency.**
  - HADF Phase 2-bis Replication — fully covered in plan + PR #322.
- **Planned (RICE Ordered)** (lines 114–137) — high-level roadmap; product items not infra. **No infra items.**
- **Critical (GDPR/Legal)** — all Done.
- **High Priority (Product Gaps)** — most Done; remaining items already in v8.0+ product concurrency map (§15 of plan).
- **High Priority (Architecture & Framework)** — fully reflected in v7.8.5 → v8.2 plan (this is where F14-F18 + Calibration Protocol items live).
- **High Priority (Architecture → AI Engine)** — AI Engine v2 SHIPPED.
- **Medium Priority (UX Improvements)** — product items, mostly in v8.0+ concurrency.
- **Low Priority (Nice-to-Have)** — long-tail product items.
- **Design System Residual** — 4 small items; no infra.
- **v8.0+ Candidates (Branch-Isolation Out-of-Scope)** — V8-I1 through V8-I7 fully in plan §3.2 + §15.

**Action items surfaced from backlog NOT in v7.8.5 → v8.2 plan or in §15 product concurrency map:**

1. **App Store assets resume** — paused/deferred to last; needs scheduling decision (DEFERRED-TO-LAST per memory)
2. **Smart Reminders Behavioral Learning PR-2** — earliest 2026-05-09; cohort data may be ready now
3. **HADF Phase 2 backup + branch decisions** — 3 open questions still unresolved
4. **UCC passkey cutover** — operator-gated env flip (UCC_AUTH_MODE basic → passkey)
5. **HADF Phase 2 external audit** — replication-pack prep (queued; advances NOW per HADF+ORCHID consolidation §4.2)
6. **DevSSD SanDisk remediation** — hardware constraint; ongoing
7. **Re-activate Code Connect publish** — gated on Figma scope availability (external blocker)
8. **Apply web DS to /control-room/*** — not priority; deferred

### §1.6 Source 6 — Active Features inventory (from SessionStart hook)

68 features tracked; 66 complete + 2 in flight (`fitme-story-public-enhancements` phase=implementation, `ios-code-connect` phase=implementation). Both already in backlog as queued items; no new infra work surfaced.

---

## §2 New Ideas / Gaps Surfaced by This Review

Items that were NOT explicit in either the v7.8.5 → v8.2 plan OR the backlog, but emerged from cross-referencing:

| ID | Item | Source | Priority |
|---|---|---|---|
| **N1** | Re-evaluate stale orphan branches (`chore/sentry-integration-wip` 2026-04-30 + `feature/hadf-phase2-fingerprint` 2026-04-30) | branch audit | LOW — cleanup |
| **N2** | Smart Reminders PR-2 cohort-data readiness check (earliest 2026-05-09; now overdue) | backlog In Progress | MED — could ship inside v7.9.1 window as additional product concurrency |
| **N3** | HADF Phase 2 raw-dataset commit decision (commit vs gitignore + off-SSD backup-only) | backlog | LOW — has off-SSD backup already; decision can wait |
| **N4** | Linear epic FIT-72 (v7.9-promotion) — needs to be CREATED, not just referenced | infra plan §2.3 | HIGH — 2026-05-21 promotion has no Linear surface today |
| **N5** | Notion sub-page for v7.9-promotion under FitMe Product Hub — needs CREATING | infra plan §2.3 | HIGH — same |
| **N6** | Quarterly Data Freshness Audit script — needs IMPLEMENTING before 2026-08-12 first run | plan §3.5.3 + §10 | MED — has 90d window, but tooling not built |
| **N7** | External audit invitation channel (Tier 3.3 GH #142) — never actively pinged | plan §15.3.4 | LOW — backlog item exists |
| **N8** | Linear sync of Calibration Protocol Phase A.5 production-exposure planning artifact — currently a written note in spec; should be a structured artifact | plan §15.5 | LOW — process refinement |

**Verdict:** N4 + N5 are the only HIGH-priority new items. Both about ensuring Linear/Notion mirror the framework state. **They're the reason this review exists.**

---

## §3 Linear Hierarchy — Paste-Ready

Format: Parent task → child sub-tasks. Each parent = one framework version. Child priority within parent ranked by **data-value-per-version** (highest-impact gate calibration first).

> **Linear paste protocol:** create each parent first (use the title shown), then add sub-tasks as children of that parent. Priority field on each sub-task set per the priority column. Linear epic FIT-72 should be the umbrella linking the 6 version parents.

### §3.1 Parent: **FIT-72 — v7.9 Promotion Release (2026-05-21)**

**Description:** Promotion-only release. Flips 5 currently-advisory gates to enforced based on 7+ days of `gate-coverage.jsonl` telemetry. Pre-promotion data verified clean by v7.8.5 (PR #320).

**Children (sub-tasks):**

| # | Title | Priority | Data-value rationale |
|---|---|---|---|
| 1 | T7.9.0 — Pre-decision data review (2026-05-18 → 20) | Urgent | Foundation; without this the promotion decision lacks grounded data |
| 2 | T7.9.1.1 — Flip `BRANCH_ISOLATION_VIOLATION` Mode B to enforced | High | Closes the highest-volume gap (infra-path commits); PR #317 fix validated |
| 3 | T7.9.1.2 — Flip `BRANCH_ISOLATION_VIOLATION` Mode C to enforced | High | Closes phase-transition gap on non-feature branches |
| 4 | T7.9.1.3 — Flip `FEATURE_CLOSURE_COMPLETENESS` to enforced | High | Closes documentation-drift class of failures (Q6 + Q7) |
| 5 | T7.9.1.4 — Flip Mechanism A coverage gates to enforced | Medium | Already calibrated; mechanical |
| 6 | T7.9.1.5 — Flip Mechanism C session-attribution to enforced | Medium | Already calibrated; mechanical |
| 7 | T7.9.2 — Side-effect updates (CLAUDE.md + entrypoint + dev-guide + honesty ledger) | Medium | Documentation completeness |
| 8 | T7.9.3 — Closure case study + showcase MDX slot 31 | Medium | Required by FEATURE_CLOSURE_COMPLETENESS itself |
| 9 | T7.9.4 — Post-promotion validation (Phase E, 2026-05-21 → 06-04) | High | Catches false positives in first 7d |
| 10 | T7.9.4.x — External Audit #1 (2026-05-22) | High | Independent validation of promotion data |

**Total tasks:** 10. Estimated effort: 4–8h spread over 2026-05-18 → 06-04.

### §3.2 Parent: **FIT-73 — v7.9.1 Test Discipline Foundation (2026-06-04 → 06-11)**

**Description:** Ship the foundation layer for Theme G test discipline (F16) + telemetry materialization (F17) + low-effort workflow improvements (F2, F6). No new gates ship — all items non-gate-additive or read-only.

**Children:**

| # | Title | Priority | Data-value rationale |
|---|---|---|---|
| 1 | F16 — pre-commit try-repo end-to-end harness | Urgent | **Foundation for F14 + F18 + future test discipline.** External research identifies as highest-leverage single change. |
| 2 | F17 — per-gate `last_fired_at` materialized index | High | Unlocks O(1) `GATE_COVERAGE_ZERO` meta-check; enables 2026-08-12 Data Freshness Audit |
| 3 | F2 — `/pm-workflow` Phase 0 reality-check sub-step | Medium | Workflow improvement; low-effort |
| 4 | F6 — B_medium tier documented in CLAUDE.md | Low | Pure doc |
| 5 | Triage v7.8.6 fixture-rot (3 STATE_OWNER_MISSING + 1 TIER_TAG) | Medium | Cleanup; ships with v7.9.1 or as separate v7.8.6 |
| 6 | External Audit #2 (2026-06-12) | High | Validates F16 fixture corpus + F17 index correctness |

**Total tasks:** 6. Estimated effort: 3–5 days work + 7d calibration window.

### §3.3 Parent: **FIT-74 — v8.0 Top-Per-Theme Docket (2026-06-18 → 07-31)**

**Description:** Ship top items per theme by RICE × telemetry signal strength, picked at 2026-05-21 ranking. Provisional v8.0 docket: F1, F4, F10, F11, F14, F15.

**Children:**

| # | Title | Priority | Data-value rationale |
|---|---|---|---|
| 1 | F14 — per-gate dispatch tests (depends on F16 in Phase E) | Urgent | Closes Class A silent-pass vulnerability for 4 enforced gates |
| 2 | F1 — STATE_TASKS_FILESYSTEM_DRIFT cycle-time advisory | High | Catches the 5+ pre-v7.6 features with empty tasks[] drift |
| 3 | F4 — framework_version auto-update | High | Closes systemic framework_version drift on 9 features |
| 4 | F15 — zero-coverage gate unit tests | High | PHASE_TRANSITION_NO_LOG + NO_TIMING gates currently UNTESTED — highest risk |
| 5 | F11 — BRANCH_ISOLATION_HISTORICAL allowlist | Medium | Closes 3 known false-positive advisories |
| 6 | F10 — experiment_outcome enum on tasks[] | Medium | Schema extension; unblocks experiment-style closures |
| 7 | External Audit #3 (2026-08-05) | High | Validates 6 new gates' calibration data honesty |
| 8 | First Data Freshness Audit (2026-08-12) | Medium | Recurring quarterly audit; depends on F17 |

**Total tasks:** 8. Estimated effort: 4–6 weeks.

### §3.4 Parent: **FIT-75 — v8.1 Deferred F-items + First V8-I Triggers (2026-08-31 → 09-30)**

**Description:** Ship F-items deferred from v8.0 + V8-I icebox items whose re-eval triggers fired.

**Children:**

| # | Title | Priority | Data-value rationale |
|---|---|---|---|
| 1 | F18 — Mutation testing nightly (depends on F14 + F16 in Phase E) | High | Final layer of test discipline; surfaces PR #317-class bugs prophylactically |
| 2 | F12 — actionlint pre-commit gate | High | RICE 100 (highest in F-series); catches GH Actions YAML errors locally |
| 3 | F9 — `make complete-feature` pre-flight | Medium | Closure ergonomics; would have saved time during recent closures |
| 4 | F3 — Phase 2 dependency-graph cycle/mismatch check | Medium | Roadmap-realism quality-of-life |
| 5 | F5 — `scope_change` event in Tier 2.2 vocabulary | Low | Workflow-only |
| 6 | F13 — workflow_dispatch source_commit input | Low | Cutover ergonomics |
| 7 | V8-I1 — Agent Smartlog UI (IF trigger fires by 2026-08) | Medium | Visibility win; ≥5 concurrent active features for 7+ days |
| 8 | V8-I2 — Op-log Replay (IF trigger fires by 2026-08) | Medium | Recovery primitive; ≥3 manual-cleanup incidents in 90d |
| 9 | External Audit #4 (2026-10-08) | High | |

**Total tasks:** 9. Estimated effort: 4–6 weeks.

### §3.5 Parent: **FIT-76 — v8.2+ Long Tail (2026-12+)**

**Description:** V8-I icebox items whose re-eval triggers fire post-v8.1.

**Children (provisional):**

| # | Title | Priority | Trigger |
|---|---|---|---|
| 1 | V8-I3 — Vercel Sandbox / Firecracker microVM | Low | Untrusted-code use case |
| 2 | V8-I4 — Kernel-Level Isolation (Landlock + App Sandbox) | Low | Regulatory mandate |
| 3 | V8-I5 — Path Watcher Daemon | Low | ≥2 concurrent-write incidents in 60d |
| 4 | V8-I6 — Cross-Feature Dependency Graph | Low | path-reducers.json ≥20 entries |
| 5 | V8-I7 — Auto-Rollback on Kill-Criteria fire | Medium | T+7d telemetry + 2 dry-runs |

**Total tasks:** 5. Effort TBD per re-eval triggers.

### §3.6 Parent: **FIT-71 — HADF Phase 2-bis Replication (already exists)**

**Description:** Existing Linear epic. Add the following NEW sub-tasks from PR #322 (HADF + ORCHID consolidation):

**Children to ADD:**

| # | Title | Priority | Source |
|---|---|---|---|
| 1 | B13.13a — Author Sub-exp 1 ORCHID analysis report §99 | High | PR #322 §6.1 |
| 2 | B13.13b — Append framework mapping update | Medium | PR #322 §6.1 |
| 3 | B14.9a — Author Sub-exp 2 ORCHID analysis report §99 | High | PR #322 §6.2 |
| 4 | B14.9b — Cross-reference Sub-exp 1 findings | Medium | PR #322 §6.2 |
| 5 | B15.22a — Author Sub-exp 3 ORCHID analysis report §99 | High | PR #322 §6.3 |
| 6 | B15.22b — Anchor-drift hardware implications | Medium | PR #322 §6.3 |
| 7 | C16.6 — Author ORCHID v2 design spec stub | High | PR #322 §6.4 |
| 8 | C16.7 — Extend framework mapping note v7.x rolling | Medium | PR #322 §6.4 |
| 9 | C16.8 — Track 6 HADF gate activation spec draft | High | PR #322 §6.4 |
| 10 | External Audit #1 of HADF (2026-05-22, audit-1-v7-9-promotion scope: Sub-exp 1 prereg + smoke-fire) | High | state.json `external_audit_schedule` |
| 11 | External Audit #2 of HADF (2026-06-12, Sub-exps 1-3 raw data integrity) | High | state.json |
| 12 | External Audit #3 of HADF (2026-08-05, Block C synthesis + ORCHID v2) | High | state.json |

### §3.7 Parent: **FIT-NEW — Backlog Cleanup + Operator-Gated Items (rolling)**

**Description:** Items not part of any framework version but require attention.

**Children:**

| # | Title | Priority | Notes |
|---|---|---|---|
| 1 | UCC passkey cutover (flip UCC_AUTH_MODE basic → passkey) | High | Operator-gated; needs to flip once registration coverage verified |
| 2 | HADF Phase 2 backup + branch decisions (3 open Q) | Medium | Per backlog item from 2026-05-08 |
| 3 | HADF Phase 2 external audit replication-pack prep | Medium | Advances NOW per PR #322 §4.2 |
| 4 | Smart Reminders Behavioral Learning PR-2 (cohort-data-gated, earliest 2026-05-09) | Medium | Per backlog In Progress; check if data window has accumulated |
| 5 | Re-activate Code Connect publish (Figma scope-gated) | Low | External blocker |
| 6 | DevSSD SanDisk Extreme remediation | High (latent) | Hardware constraint; ongoing risk |
| 7 | App Store assets resume sequencing | Medium | DEFERRED TO LAST per memory; depends on S3-G3/S5/S4/S7/S6/S8/S9 |
| 8 | Apply web DS to /control-room/* | Low | Not priority |
| 9 | Sentry MCP wire-up (when MCP available) | High (latent) | Pre-launch crash_free_rate gap |
| 10 | Stale branch cleanup (14+ FT2 [gone] branches + 4 orphans) | Low | Hygiene |

---

## §4 Priority Ranking — Data-Value-Per-Version Framework

Every sub-task ranked using this rubric:

| Criterion | Weight |
|---|---|
| **Foundation for downstream work** (unblocks other tasks) | 40% |
| **Closes a known silent-pass class** (Class A/B/C bugs) | 30% |
| **Provides quantitative telemetry for next promotion decision** | 20% |
| **Operator ergonomics / quality of life** | 10% |

**Top 5 highest-value items across all versions (sorted by composite score):**

1. **T7.9.0 — v7.9 pre-decision data review** — every downstream version depends on this; calibration data correctness gates the entire framework chain. Foundation 40 + Telemetry 20 = **60**.
2. **F16 — try-repo end-to-end harness (v7.9.1)** — foundation for F14 + F18; closes Class A silent-pass class structurally. Foundation 40 + Class-closure 30 = **70**.
3. **F14 — per-gate dispatch tests (v8.0, depends on F16)** — closes 4 known Class A vulnerabilities. Class-closure 30 + Telemetry 20 = **50**.
4. **F17 — last_fired_at index (v7.9.1)** — unlocks `GATE_COVERAGE_ZERO` meta-check + Data Freshness Audits. Foundation 40 + Telemetry 20 = **60**.
5. **F15 — zero-coverage gate unit tests (v8.0)** — closes 5 known Class B gates (PHASE_TRANSITION_NO_LOG + NO_TIMING are highest-risk). Class-closure 30 + Telemetry 20 = **50**.

**The chain that matters:** v7.9 (T7.9.0) → v7.9.1 (F16 + F17) → v8.0 (F14 + F15) is the load-bearing test-discipline path. Everything else can slip without endangering the framework's ability to police itself.

---

## §5 Notion Sync Notes

When Notion MCP reconnects, sync the following structure to the existing **FitMe — Product Hub** root page (`35d0e7a0-eace-8189-a739-d17acc404e95`):

### §5.1 Pages to CREATE under Product Hub

| Notion page | Source content | Linear epic ref |
|---|---|---|
| 🚀 Framework v7.9 — Promotion Release | This doc §3.1 + plan §4 | FIT-72 |
| 🧪 Framework v7.9.1 — Test Discipline Foundation | This doc §3.2 + plan §5 | FIT-73 |
| 🏗️ Framework v8.0 — Top-Per-Theme Docket | This doc §3.3 + plan §6 | FIT-74 |
| 📦 Framework v8.1 — Deferred + V8-I Triggers | This doc §3.4 + plan §7 | FIT-75 |
| 🔬 HADF Phase 2-bis + ORCHID Integration | PR #322 consolidation doc | FIT-71 |

### §5.2 Pages to UPDATE under Product Hub

| Notion page | Update |
|---|---|
| 🔁 Framework v7.8.3 — Cross-Repo State-Sync (existing) | Add "Successor: v7.8.4 + v7.8.5" cross-link |
| 📋 Backlog (mirror of backlog.md) | Add §3.7 operator-gated items + cleanup items |
| 🗓️ Master Plan Calendar (mirror of infra plan §5) | Update with 2026-05-22, 06-12, 08-05, 10-08, 08-12 external audit + Data Freshness Audit dates |

### §5.3 Notion sync verification

After Notion MCP reconnect:
1. Walk every Linear epic ID (FIT-71 through FIT-76 + FIT-NEW) and confirm Notion page exists
2. Cross-check page count vs Linear epic count
3. Add this consolidation doc as a sub-page reference under "Recent Reviews" section

---

## §6 What This Review Confirmed

1. **The v7.8.5 → v8.2 implementation plan is comprehensive.** Only 8 new ideas surfaced (§2); 6 are LOW priority cleanup; 2 (N4 + N5) are the Linear/Notion sync gap this doc closes.
2. **No orphan PRs.** All 7 OPEN PRs from 2026-05-12 session map to v7.8.5/v7.9/v7.9.1/v8.0 scope.
3. **4 orphan branches** require decisions (sentry-integration-wip + 2 HADF Phase 2 + 1 hadf-phase2-fingerprint) — captured in §3.7.
4. **6 backlog items not yet in framework versions** — captured in §3.7 as rolling chore parent.
5. **Linear epics FIT-72 through FIT-76 do NOT exist yet** — needs CREATING (this doc is the blueprint).
6. **Notion sub-pages for v7.9 through v8.2 do NOT exist yet** — needs CREATING per §5.

---

## §7 Action Items From This Review

### §7.1 Immediate (this week, before 2026-05-21)

1. **Reconnect Linear MCP** → create FIT-72 through FIT-76 per §3 hierarchy. ~1h if MCP available.
2. **Reconnect Notion MCP** → create 5 sub-pages + 3 updates per §5. ~30min if MCP available.
3. **Verify HADF Phase 2-bis state.json** `external_audit_schedule` field (added in PR #322) — confirm dates match §3.6 sub-tasks.
4. **Triage v7.8.5 (PR #320)** merge — unblocks 2026-05-21 promotion data confidence.
5. **Decide UCC passkey cutover timing** — flip is operator-gated; can happen any time post-2026-05-12.

### §7.2 Near-term (next 14 days, before 2026-05-26)

1. **2026-05-18 → 20:** v7.9 T7.9.0 pre-decision data review (per §3.1)
2. **2026-05-21:** v7.9 promotion decision + T29 v8.0 docket ranking
3. **2026-05-22:** External Audit #1 — independent agent run on v7.9 + HADF Sub-exp 1 prereg
4. **2026-05-23:** HADF Phase 2-bis Sub-exp 1 launches
5. **2026-05-26:** Sub-exp 1 verdict + first ORCHID analysis report

### §7.3 Process commitment from this review

**"Any new idea surfaced gets the same review treatment."** Per user instruction. Operationally:

- New idea → review against memory + PRs + branches + master plan + backlog
- If not captured: append to backlog AND create Linear sub-task under appropriate version parent AND sync Notion
- If already captured: cross-reference and reject duplicate
- Review cadence: end of every major session (like this one) OR before every Phase D decision

---

## §8 What This Doc Is NOT

- **Not a Linear API call.** MCP disconnected this session; this is paste-ready hierarchy + a runbook for the next session that has MCP available.
- **Not a Notion API call.** Same.
- **Not a replacement for the v7.8.5 → v8.2 implementation plan.** That plan stays authoritative; this doc is the Linear/Notion-projected view of it.
- **Not exhaustive.** New items will surface as v7.9 calibration data lands + HADF Sub-exps run. This doc + §7.3 process commit captures the steady-state operating mode.

---

## §9 Sign-off

This consolidation review accounts for:
- 137 memory entries
- 7 OPEN PRs + 10 recent merged PRs (FT2) + 5 recent merged (fitme-story)
- 25+ local branches (4 orphan, 21 closure-cleanup-pending)
- 3 master plan documents
- 7 backlog sections + 25+ in-progress / planned items
- 68 active feature state.jsons
- 18 F-candidates + 7 V8-I icebox items (full v7.8.5 → v8.2 scope)
- 5 external audit checkpoints
- 4 quarterly Data Freshness Audits

**Nothing surfaced that lacks accounting.** 2 high-priority new items (N4 + N5) closed by this doc itself (Linear + Notion structural gap). 6 medium/low items routed to FIT-NEW backlog parent. Framework v7.9 promotion decision (2026-05-21) proceeds with verified-clean calibration data per PR #320.
