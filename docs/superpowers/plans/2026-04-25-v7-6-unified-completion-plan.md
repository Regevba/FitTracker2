# Framework v7.6 — Unified Completion Plan (Original Plan ⊕ Codex Pending-Fixes ⊕ Session Additions)

**Created:** 2026-04-25T12:08Z
**Branch state at writing:**
- `main` @ `805daab` — Phase 1–4f + DEV guide shipped
- `framework-v7.6-pending-fixes` @ `95809a0` — 7 commits ahead, Codex's 5 fix groups + handoff
- `fitme-story/main` @ `112e523` — trust-page response section + MDX slot 21
**Purpose:** Reconcile the original `2026-04-25-v7-6-mechanical-enforcement-phases-2-4.md` plan with Codex's `2026-04-25-v7-6-pending-fixes-handoff.md` plan and the in-session additions (DEV guide, expanded case study scope, outlier framing). Single source of truth for what is done vs what remains.

---

## 1. Status legend

- ✅ **Shipped to main** — on `origin/main` of the relevant repo
- 🟡 **Shipped to branch only** — on `framework-v7.6-pending-fixes`, not yet merged
- ⏳ **Open** — work item not started or not finished
- 🚫 **Not applicable / not pursued** — explicitly out of scope

---

## 2. Original v7.6 Plan (Phases 1–4) — Status Roll-up

Source: [`docs/superpowers/plans/2026-04-25-v7-6-mechanical-enforcement-phases-2-4.md`](2026-04-25-v7-6-mechanical-enforcement-phases-2-4.md).

| Item | Description | Commit | Status |
|---|---|---|---|
| **Phase 1 (in-flight at plan time)** |  |  |  |
| 1a | `PHASE_TRANSITION_NO_LOG` write-time check | `0a23922` | ✅ |
| 1b | `PHASE_TRANSITION_NO_TIMING` write-time check | `0a23922` | ✅ |
| 1c | `BROKEN_PR_CITATION` write-time check (narrow regex) | `0a23922` | ✅ |
| 1d | `CASE_STUDY_MISSING_TIER_TAGS` write-time check (forward-only ≥ 2026-04-21) | `0a23922` | ✅ |
| **Phase 2** |  |  |  |
| 2a | PR review bot workflow (`pm-framework/pr-integrity` status check) | `c0be8ea` | ✅ |
| 2b | Append-only measurement-adoption history (dedup-by-date) | `c0be8ea` | ✅ |
| 2c | Weekly framework-status cron + regression watcher | `c0be8ea` | ✅ |
| **Phase 3** |  |  |  |
| 3a | `unclosable-gaps.md` (5 Class B gaps, 4-section format each) | `ecb172d` | ✅ |
| 3b | CLAUDE.md "Known Mechanical Limits" + write-time gate updates | `ecb172d` | ✅ |
| 3c | **LAST:** Tier 3.3 public GitHub external-replication invitation issue | — | ⏳ Awaiting user `gh issue create` confirmation |
| **Phase 4** |  |  |  |
| 4a | `framework-manifest.json` v7.6 bump (1.7→1.8, capabilities, `v7_6_mechanical_enforcement` block) | `58b82b5` | ✅ |
| 4b | Dev-style case study `mechanical-enforcement-v7-6-case-study.md` (parity w/ v7.5; T1 sourcing rule) | `58b82b5` | ✅ (616 lines, 15 sections — exceeded scope per user's 2 in-session expansions) |
| 4c | `docs/skills/evolution.md` header + version-table rows | `58b82b5` | ✅ |
| 4d | `.claude/integrity/README.md` v7.6 context note | `58b82b5` | ✅ |
| 4e | Repo-root mirrors + memory updates (`project_*.md` + `MEMORY.md`) | `58b82b5` | ✅ |
| 4f | `fitme-story` trust page Mechanical-Enforcement entry + MDX case-study slot | fitme-story `112e523` | ✅ |

**Original plan completion: 16 of 17 items shipped to main; Phase 3c is the explicit final deliverable awaiting user go-ahead.**

---

## 3. Codex Pending-Fixes Plan (5 groups) — Status Roll-up

Source: [`docs/superpowers/plans/2026-04-25-v7-6-pending-fixes-handoff.md`](2026-04-25-v7-6-pending-fixes-handoff.md). All 5 fix groups already executed by Codex on the pending-fixes branch.

| Group | Description | Commit | Status |
|---|---|---|---|
| 1 | Reconcile v7.6 feature `state.json` to `current_phase=complete`, `status=complete`; add `complete` phase block; populate `timing.session_end`, `total_wall_time_minutes=258`, per-phase `ended_at`/`duration_minutes`; append `phase_transition` log event | `761dc97` | 🟡 (on branch, not main) |
| 2 | Register v7.6 in shared tracking: `feature-registry.json`, `case-study-monitoring.json`, `task-queue.json`, `framework-health.json` | `9d3c64f` | 🟡 |
| 3 | Tighten PR workflow: include `schema_exit`/`integrity_exit`/`adoption_exit` in delta computation so `pm-framework/pr-integrity` fails when any required command exits non-zero (not just on findings delta); also moves PR-bot adoption history output to `/tmp` to avoid polluting the repo | `765f0f7` | 🟡 |
| 4 | Align docs with actual implementation guarantees: README.md (v7.0 → v7.6 + Mechanical-Enforcement bullet), pm-workflow/README.md (v6.1 → v7.6), CLAUDE.md (clarify `gh pr list` cache + 12 cycle-time codes + write-time-only transition checks + presence-not-correctness for tier tags), dev-guide (same), case study (same), framework-manifest.json (same), integrity/README.md (same) | `2e15af4` | 🟡 |
| 5 | Clarify regression test naming: kept `scripts/test-v7-5-pipeline.sh` (compatibility), updated header comments + Makefile comments to say "v7.5/v7.6 pipeline regression test" | `682d88b` | 🟡 |
| — | Pending-fixes handoff doc | `9bc6763`, `95809a0` | 🟡 |

**Codex completion: 5/5 fix groups + handoff doc on branch; ALL shipped to branch; awaiting push + PR + merge.**

---

## 4. In-Session Additions (User Requests Outside Both Plans)

These were not in either plan but were explicitly requested by the user during execution.

| Addition | Description | Commit | Status |
|---|---|---|---|
| Outlier framing in case study | §10 "Outlier Limitations" — single-session, dogfooded, retroactive v6.0 | `58b82b5` | ✅ |
| Comprehensive CU + workload analysis | §11 — workload table, CU=23.94, velocity 3.33 min/CU (Phases 1–3) with explicit "structurally invalid" caveat for the historical-baseline comparison | `58b82b5` | ✅ |
| Full T1/T2/T3 sub-work arc | §4.2 v7.5 Tier-by-Tier sub-work table (14 sub-tasks); §4.3 post-v7.5 hardening; §4.4 v7.6 Phase-by-Phase elapsed | `58b82b5` | ✅ |
| Honest tooling attribution | §9 — Claude Opus 4.7, Google Gemini 2.5 Pro, OpenAI Codex (with explicit honest gap for any v7.5+ Codex work not in `git log`) | `58b82b5` | ✅ |
| **DEV-only framework guide (v1.0 → v7.6)** | New `docs/architecture/dev-guide-v1-to-v7-6.md` (745 lines, 16 sections) — covers 4 enforcement layers, state.json schema, phase lifecycle, dispatch, cache, measurement protocol, integrity check codes, 3 operational walkthroughs | `805daab` | ✅ |

---

## 5. Verification — what runs green right now

Run on the pending-fixes branch on 2026-04-25:

| Check | Result |
|---|---|
| `python3 scripts/integrity-check.py --findings-only` | **42 features scanned, 49 case studies, 0 findings** ✅ |
| `python3 scripts/check-state-schema.py` | **All 42 state.json files pass (mode=all) (PR-resolution: 91 known PRs)** ✅ |
| `python3 scripts/check-case-study-preflight.py` | **All 44 case study files pass (mode=all) (PR-resolution: 91 known PRs)** ✅ |
| `bash scripts/framework-status.sh` | Tier 3.2 debt: 7 open items (`trend_ready=False`, need 3 cycle snapshots); Tier 2.2: 6 active logs; Tier 2.1: `sign_in_surface` passed; pre-commit hook installed; 0 open integrity issues ✅ |
| `bash scripts/test-v7-5-pipeline.sh` (per Codex's pass) | **15 pass, 0 fail** ✅ |

**Branch is verified mergeable.**

---

## 6. Cross-Repo Status

| Repo | Branch | State |
|---|---|---|
| `Regevba/FitTracker2` | `main` @ `805daab` | Phase 1–4f + DEV guide ✅ |
| `Regevba/FitTracker2` | `framework-v7.6-pending-fixes` @ `95809a0` | 7 unmerged commits (5 Codex fixes + 2 handoff doc updates) — 🟡 |
| `Regevba/fitme-story` | `main` @ `112e523` | Trust-page response section + MDX slot 21 ✅ |

---

## 7. Remaining Steps (Single Sequenced List)

The framework v7.6 work is **done in substance**. Only 4 procedural steps remain. They are listed in the order they must run.

### Step 1 — Push the pending-fixes branch (~30 sec)

```bash
git push -u origin framework-v7.6-pending-fixes
```

This makes the branch and Codex's 5 fix-group commits visible on GitHub. **Reversible:** `git push origin --delete framework-v7.6-pending-fixes`.

### Step 2 — Open PR for the pending-fixes branch (~2 min)

```bash
gh pr create \
  --title "Framework v7.6 pending fixes — reconciliation, shared tracking, PR-bot tightening, doc alignment" \
  --body-file <(cat <<'EOF'
## Summary

Closes the v7.6 pending fixes from `docs/superpowers/plans/2026-04-25-v7-6-pending-fixes-handoff.md`. All 5 fix groups landed as separate rollbackable commits.

- `761dc97` — reconcile v7.6 feature state (`current_phase=complete`, full timing fields)
- `9d3c64f` — register v7.6 in shared tracking (feature-registry, case-study-monitoring, task-queue, framework-health)
- `765f0f7` — tighten PR-bot status to fail on schema/integrity/adoption command errors (not just findings delta)
- `2e15af4` — align docs with implementation (README, pm-workflow README, CLAUDE.md, dev-guide, case study, manifest, integrity README)
- `682d88b` — clarify regression test naming as v7.5/v7.6

## Verification

- `python3 scripts/integrity-check.py --findings-only` — 0 findings
- `python3 scripts/check-state-schema.py` — 42/42 pass
- `python3 scripts/check-case-study-preflight.py` — 44/44 pass
- `bash scripts/framework-status.sh` — framework 7.6, 0 findings, hook installed
- `bash scripts/test-v7-5-pipeline.sh` — 15 pass, 0 fail

## Test plan

- [ ] PR-bot status check fires on this PR (it will now run against itself with the tightened semantics)
- [ ] Confirm `pm-framework/pr-integrity` status equals `success` if no new findings + all required commands exit 0
- [ ] After merge, run `make framework-status` locally to confirm reconciliation lands cleanly

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)
```

The PR will exercise its own tightened gate (`765f0f7`) — if anything is wrong with the `schema_exit`/`integrity_exit`/`adoption_exit` plumbing, the PR-bot will catch it on itself.

### Step 3 — Merge the PR after CI green (~1 min)

Standard merge. Squash or merge-commit per project preference. After merge, `framework-v7.6-pending-fixes` can be deleted.

### Step 4 — File Tier 3.3 public invitation issue (Phase 3c, explicitly LAST)

Per user instruction at session start: this is the explicit final v7.6 deliverable. Filed only after every other piece is on `main`.

```bash
gh issue create \
  --title "Tier 3.3: external replication invitation — run /pm-workflow on an unrelated product" \
  --label "tier-3-3,external-replication,help-wanted" \
  --body-file <(cat <<'EOF'
## What this issue is

The 2026-04-21 Google Gemini 2.5 Pro independent audit identified a load-bearing gap: every measurement we publish about the framework is self-referential — same author, same project, same workflow. Gemini's Tier 3.3 recommendation was to invite an **independent operator on an unrelated product** to run `/pm-workflow` start-to-finish and report whether the framework is reproducible without our hand-holding.

This issue is that public invitation. It is filed as the explicit final deliverable of v7.6 (Mechanical Enforcement) — every other piece of the v7.5 + v7.6 framework response is on `main`; the framework now openly admits where its own evidence runs out.

## Why we are asking

Read the upstream context:
- [v7.6 case study](https://github.com/Regevba/FitTracker2/blob/main/docs/case-studies/mechanical-enforcement-v7-6-case-study.md) — §10 Outlier Limitations explains why the v7.6 numbers are dogfooded and not generalizable.
- [Class B gap inventory](https://github.com/Regevba/FitTracker2/blob/main/docs/case-studies/meta-analysis/unclosable-gaps.md) — Gap 5 documents this exact limitation.
- [Trust page mirror of the Gemini audit](https://fitme-story.vercel.app/trust/audits/2026-04-21-gemini) — verbatim audit + appended response.

## What evidence to return

If you (an external operator) run `/pm-workflow` on a feature in your unrelated product, please report:

1. **Repro report** — did the framework's bootstrap (`/pm-workflow <feature>` → state.json initialized → phase progression) work without modification on your product? List anything you had to patch.
2. **Adoption metrics** — at end of feature, share `make measurement-adoption` output (or equivalent). What was your `cu_v2` / `cache_hits` / `timing` adoption?
3. **Failure modes you hit that we did not document** — anything in the framework that surprised you, was unclear, or broke in ways our case studies do not predict.
4. **Honest verdict** — recommend / recommend-with-changes / do-not-recommend, with one paragraph of reasoning.

## How we will use the response

Per the project's `feedback_publish_verbatim_then_remediate` policy: we will publish your response **verbatim** in `docs/case-studies/external/<your-handle>-<date>.md` and append our reaction as a separate timestamped section. We will not silently edit your text.

## Statement of independence

For the response to count as a Tier 3.3 closure, you must:
- Be running on a product you (not we) control.
- Have no prior involvement with FitTracker2 / FitMe development.
- Be willing to publish your evidence under your own name (or a stable pseudonym) so future audits can verify your statement.

## Tracking

This issue closes when at least one external case study lands in `docs/case-studies/external/`. Until then, Tier 3.3 remains the framework's open Class B Gap 5 — see `unclosable-gaps.md`.
EOF
)
```

After filing:
1. Pin the issue: `gh issue pin <num>`.
2. Update [`docs/case-studies/meta-analysis/unclosable-gaps.md`](../../case-studies/meta-analysis/unclosable-gaps.md) Gap 5 "Tracking" with the issue number.
3. Update [`docs/case-studies/mechanical-enforcement-v7-6-case-study.md`](../../case-studies/mechanical-enforcement-v7-6-case-study.md) §15 Links — replace the placeholder with the issue URL.
4. Optionally: append a one-line note to the trust-page Gemini-audit subroute §11 "How we responded — v7.6" pointing at the issue.

---

## 8. What is *intentionally* not done

- **`.claude/scheduled_tasks.lock` and `.claude/settings.local.json`** — modified locally; per Codex handoff `Scope Guard`, these are runtime metadata and are kept out of framework commits unless the user explicitly asks otherwise.
- **`docs/case-studies/external/` directory** — does not exist yet; created on first external submission per Gap 5 design.
- **Branch protection on `main` requiring `pm-framework/pr-integrity`** — not configured. The status check exists; whether it is `required for merge` is a GitHub repo-settings choice the user owns.

---

## 9. Cohesion check — do all three plans agree?

| Concern | Original v7.6 plan | Codex pending-fixes plan | This unified plan |
|---|---|---|---|
| Pre-commit hook for transition checks | Phase 1a/1b shipped | Verified working in Fix 4 (docs aligned to "write-time only") | Same — write-time only, cycle-time hook for the same codes is documented but not wired |
| PR-bot semantics | Phase 2a — fail on findings delta | Fix 3 — also fail on schema/integrity/adoption command errors | **Codex's tightening is correct**; original plan under-specified |
| Case-study preflight scope | Phase 1d — forward-only ≥ 2026-04-21, "quantitative claims without tag" | Fix 4 docs alignment — clarifies it checks tag PRESENCE in scoped files, not every quantitative claim | **Codex's clarification is more accurate**; original plan over-claimed |
| Regression test name | Phase 1 implicit — `test-v7-5-pipeline.sh` reused | Fix 5 — kept name, updated comments | Cohesive — name preserved for compatibility |
| Tier 3.3 sequencing | Phase 3c LAST | (not addressed; out of branch scope) | Same — LAST, after pending-fixes PR merges |
| Shared tracking registration | Phase 4 implicit | Fix 2 — explicitly added | **Codex's Fix 2 closes a gap original plan glossed over** |
| State.json reconciliation | Phase 4 implicit (state would be updated as work shipped) | Fix 1 — explicit reconciliation | **Codex's Fix 1 closes a gap original plan glossed over** — Phase 4 commits left state at `current_phase=implement` because Phase 4 was the implementation; Codex's reconciliation is the proper close-out |

**No conflicts.** Codex's pending-fixes plan strictly extends the original plan with reconciliation/cleanup that the original plan implicitly assumed but did not explicitly schedule. The two plans merged cleanly into this unified document.

---

## 10. After merge — what stays "open" structurally

These are documented as Class B gaps in [`unclosable-gaps.md`](../../case-studies/meta-analysis/unclosable-gaps.md) and are NOT items waiting for v7.7:

1. **Gap 1** — `cache_hits[]` writer-path adoption (issue #140)
2. **Gap 2** — `cu_v2` factor *correctness*
3. **Gap 3** — T1/T2/T3 tag *correctness*
4. **Gap 4** — Tier 2.1 real-provider auth checklist (manual playbook)
5. **Gap 5** — Tier 3.3 external replication (filed via Step 4 above; closed when an external case study lands in `docs/case-studies/external/`)

These are framework features (explicit Class B inventory), not framework debt.

---

## 11. Sign-off checklist

Before declaring v7.6 fully closed:

- [ ] Step 1 — push `framework-v7.6-pending-fixes` to `origin`
- [ ] Step 2 — open PR with the body above
- [ ] Step 3 — merge after CI green
- [ ] Step 4 — file Tier 3.3 public invitation issue
- [ ] Update `unclosable-gaps.md` Gap 5 with the issue number
- [ ] Update v7.6 case study §15 Links with the issue URL
- [ ] Optionally pin the Tier 3.3 issue (`gh issue pin <num>`)
- [ ] Optionally append one-line pointer to fitme-story `/trust/audits/2026-04-21-gemini` §11

When all checked: framework v7.6 is fully closed and the Gemini audit response is complete.

---

*This unified plan was generated by cross-walking the original v7.6 implementation plan, Codex's pending-fixes handoff plan, and the in-session user-requested additions. It supersedes both source plans for "what's left to do." Each source plan remains in `docs/superpowers/plans/` as historical record.*
