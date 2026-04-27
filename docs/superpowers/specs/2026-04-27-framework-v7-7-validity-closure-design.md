---
title: Framework v7.7 — Validity Closure
date_written: 2026-04-27
work_type: Feature
dispatch_pattern: serial
predecessor_case_studies:
  - docs/case-studies/data-integrity-framework-v7.5-case-study.md
  - docs/case-studies/mechanical-enforcement-v7-6 (showcase entry)
  - trust/audits/2026-04-21-gemini/remediation-plan-2026-04-23.md
  - docs/case-studies/meta-analysis-full-system-audit-v7.0-case-study.md
related_specs:
  - docs/superpowers/specs/2026-04-27-framework-health-dashboard-design.md  # absorbed as M4
status: approved
---

# Framework v7.7 — Validity Closure (Design Spec)

## 0. One-line summary

v7.7 closes every gap in the data-integrity framework that is **mechanically or heuristically closable**, and produces an honest, dashboard-surfaced inventory of the remaining human-required gaps for separate follow-up.

## 1. Genesis & Why Now

The 2026-04-21 Gemini independent audit drove v7.5; v7.6 (Mechanical Enforcement, shipped 2026-04-25) closed seven Class B → Class A gaps and explicitly documented five remaining unclosable items in CLAUDE.md "Known Mechanical Limits".

Live ledger state on 2026-04-27 (frozen as v7.7 baseline):

| Tier | Status | Specific gap |
|---|---|---|
| 1.1 measurement adoption | partial | `cache_hits[]` writer-path stuck at 33% post-v6 (issue #140); cu_v2 schema unchecked |
| 1.3 schema | gated ✅ | nothing to do |
| 2.1 runtime smoke | pilot | real-provider auth checklist (human-required, deferred) |
| 2.2 contemporaneous logs | gated forward ✅ | nothing to do |
| 2.3 tier tags | presence-gated | correctness check missing (heuristic-closable) |
| 3.1 cycle audit | shipped ✅ | nothing to do |
| 3.2 documentation debt | baseline only | 4 fields under-populated; trend mode unlocks passively |
| 3.3 external replication | 0 audits | structural (deferred) |

v7.7 closes Tier 1.1, 2.3 (correctness), and 3.2 — the closable subset.

## 2. Scope

**In scope (closed by v7.7):**
- A1 — `cache_hits[]` writer-path instrumentation + pre-commit gate (closes issue #140)
- A2 — `cu_v2` schema validator (presence + range + total)
- A3 — Documentation-debt field gates + bulk backfill
- A4 — State↔case-study linkage to 100% (mechanical gate)
- A5 — Active-feature timing backfill
- B1 — Tier 1.1 trend-mode unlock (passive, cron-driven)
- B2 — Tier 3.2 cycle-snapshot trend-mode unlock (passive, cron-driven)
- C1 — Tier-tag correctness heuristic checker (advisory → gated if FP < 10%)
- Framework-health dashboard at `/control-room/framework` (absorbs UCC T43–T54)

**Out of scope (handed to post-v7.7 follow-on track, surfaced as a human-action checklist at v7.7 merge):**
- D1 — Tier 2.1 real-provider auth playbook (human + simulator)
- D2 — Tier 3.3 external replication (structural; issue #142 already filed)
- The 5 documented unclosable gaps in CLAUDE.md "Known Mechanical Limits"

## 3. Architecture

### 3.1 Feature spine

- **Feature name:** `framework-v7-7-validity-closure`
- **State:** `.claude/features/framework-v7-7-validity-closure/state.json`
- **Branch:** `feature/framework-v7-7-validity-closure`
- **PM cycle:** Full 9-phase. No skips.
- **Case study:** `docs/case-studies/framework-v7-7-validity-closure-case-study.md` — live append-only journal + final synthesis. Tier 2.2 contemporaneous logging artifact.
- **Dual-surface case study:** mirrored to fitme-story at `/case-studies/framework-v7-7-validity-closure` during M4.
- **Version positioning:** CLAUDE.md banner becomes "v7.5 → v7.6 → v7.7"; new check codes appended to existing list.

### 3.2 Milestone breakdown

| M | PR | Tasks | Closes | Gated by |
|---|---|---|---|---|
| M0 | commit-only | T0a–T0g | Kickoff propagation (no PR) | manual + MCP |
| M1 | PR-1 | T1–T5 | A1 (cache_hits writer-path + #140) | code change + new pre-commit |
| M1 | PR-2 | T6–T8 | A2 (cu_v2 schema validator) | new pre-commit + integrity-check code |
| M2 | PR-3 | T9–T11 | A4 (linkage 100%) | new pre-commit |
| M2 | PR-4 | T12–T14 | A3 (doc-debt gates + backfill) | new pre-commit + bulk PR |
| M2 | PR-5 | T15–T16 | A5 (active backfill) | manual edits |
| M3 | PR-6 | T17–T20 | C1 (tier-tag checker) | advisory → conditional gate |
| M4 | PR-7 | T21–T28 | UCC T43–T54 absorbed (dashboard) | Next.js page in fitme-story |
| M5 | PR-8 | T29–T35 | B1, B2 verify + synthesis + CLAUDE.md update + human-action checklist + closure propagation | passive cron firings + MCP |

**Total: 42 tasks (T0a–T0g + T1–T35), 8 PRs + 1 commit-only kickoff bundle, 6 milestones (M0 + M1–M5).**

### 3.2.1 M0 — Kickoff propagation (executed at PRD approval, before M1 starts)

This milestone is commit-only (no PR) — it fans out the v7.7 decision to every system that needs to know. Order matters; dependencies between sub-tasks are linear.

- **T0a** Pause-protocol commit — single atomic commit annotates 6 paused state.json files + writes `MEMORY.md` index update (see §5.3)
- **T0b** UCC absorption commit — annotates UCC state.json with `tasks_migrated_to` (see §5.2)
- **T0c** Memory entries — write `paused_<feature>.md` × 6 to `~/.claude/projects/-Volumes-DevSSD-FitTracker2/memory/`
- **T0d** CLAUDE.md banner update — version line becomes "v7.5 → v7.6 → v7.7 (in progress)"; `Data Integrity Framework` section gets a v7.7 stub linking to the case study (committed as part of v7.7 feature branch, not main, until merge)
- **T0e** Master plan update — `docs/master-plan/master-plan-2026-04-06.md` and `docs/master-plan/master-backlog-roadmap.md` get a v7.7 entry; v7.7 added at top of active priorities
- **T0f** Linear sync via MCP — create v7.7 epic in Linear (FIT-XX), create sub-issues for M1–M5 (8 issues), link to PRDs, set status `In Progress`. Mirrors the v7.5/v7.6 pattern from the 2026-04-26 PM artifacts audit
- **T0g** Notion sync via MCP — create v7.7 sub-page under the Data Integrity Framework parent page, mirror the case-study skeleton, link bidirectionally to v7.5 + v7.6 sub-pages. Update "Project Context & Status" page with v7.7 entry

Validation: after M0, `make measurement-adoption` and `make documentation-debt` MUST still pass with no new findings. Linear epic must show 8 sub-issues. Notion sub-page must resolve. Six paused-feature memories must list in `MEMORY.md`.

### 3.3 New check codes

| Code | Layer | Severity at ship | Promotion path |
|---|---|---|---|
| `CACHE_HITS_EMPTY_POST_V6` | pre-commit | failure | – |
| `CU_V2_INVALID` | pre-commit + cycle | failure | – |
| `STATE_NO_CASE_STUDY_LINK` | pre-commit | failure | – |
| `CASE_STUDY_MISSING_FIELDS` | pre-commit | failure (forward-only ≥ 2026-04-28) | – |
| `TIER_TAG_LIKELY_INCORRECT` | cycle | advisory (warning) | promote to failure if FP < 10% after 7 days |

Integrity-check code count: 12 → 16 (with one staying advisory).

### 3.4 Cache-read-site instrumentation strategy (M1 / PR-1)

- **Phase 1: audit** — `T1` produces `docs/architecture/cache-read-paths.md` enumerating every cache read site (skill loader, pm-workflow resolver, project-context loader, `_shared/`, `_project/` layers).
- **Phase 2: shared helper** — `scripts/log-cache-hit.py` accepts `(key, layer)` and appends `{key, layer, ts}` to the active feature's `cache_hits[]`. Active feature determined by reading the most recently-modified state.json under `.claude/features/*/`.
- **Phase 3: instrument call sites** — each read site gets one line invoking the helper (synchronous, fail-soft so a logging error doesn't break cache reads).
- **Phase 4: gate** — pre-commit hook `CACHE_HITS_EMPTY_POST_V6` rejects `current_phase: complete` when `cache_hits.length == 0` for any feature created on or after `v6_ship_date` (2026-04-16).

**Kill criterion 1 trigger:** if Phase 1 audit reveals >5 distinct call sites with no shared loader, pause M1 and escalate before instrumenting.

### 3.5 Doc-debt backfill strategy (M2 / PR-4)

- `scripts/backfill-case-study-fields.py` reads each case-study file's frontmatter + the linked PRD (if present) + git log for the case study itself, infers:
  - `work_type` from PRD scope or commit pattern
  - `success_metrics` / `kill_criteria` from PRD body (regex: "Primary Metric", "Kill Criteria")
  - `dispatch_pattern` from a heuristic over the PR train (single PR → "serial"; >1 parallel agent invocation in commits → "parallel")
- Where inference fails, the script emits a TODO comment in frontmatter for human decision rather than guessing.
- One bulk PR for the 32 case studies missing fields. Reviewable in chunks.

### 3.5.1 M5 closure propagation (PR-8 final commits)

PR-8 includes T29–T35:

- **T29** Verify B1 (Tier 1.1 trend mode unlocked, ≥3 snapshots) — observe + document in case study
- **T30** Verify B2 (Tier 3.2 cycle-snapshot trend mode unlocked) — observe + document
- **T31** Write Section 99 Synthesis in `framework-v7-7-validity-closure-case-study.md`
- **T32** CLAUDE.md update — append v7.7 section, bump version banner from "(in progress)" to "shipped YYYY-MM-DD"
- **T33** Master plan + RICE roadmap update — mark v7.7 Shipped, append v7.7 line to active priorities → completed
- **T34** Linear MCP closure — close v7.7 epic, mark all 8 sub-issues Done, add closing comment linking to case study + merge PR
- **T35** Notion MCP closure — update v7.7 sub-page status to `Shipped`, append synthesis summary, update "Project Context & Status" page (v7.6 → v7.7), add cross-link from v7.6 sub-page footer ("→ extended by v7.7")

Validation at M5 complete: all 4 external systems (CLAUDE.md / master plan / Linear / Notion) read consistent — same version, same status, same case-study link.

### 3.6 Tier-tag heuristic checker (M3 / PR-6)

- **Claim extractor:** regex sweep for quantitative claims (`\d+%`, `\d+\.\d+x`, `\d+ms`) within case-study body, plus tier tag co-occurrence (T1/T2/T3 within same paragraph).
- **Ledger cross-reference:** for T1-tagged claims, check whether the metric exists in `measurement-adoption.json` or `documentation-debt.json`. If it doesn't, flag as `TIER_TAG_LIKELY_INCORRECT` with confidence score.
- **Promotion gate:** advisory for first 7 days. After 7 days, run baseline scan; if false-positive rate < 10%, promote to gating in v7.8 (not in v7.7 itself, to avoid late-stage rule changes). If FP > 25% after 14 days, ship as advisory permanently.

## 4. Continuous Case Study Protocol

### 4.1 File and structure

`docs/case-studies/framework-v7-7-validity-closure-case-study.md`

```
---
<frontmatter — date_written, work_type, dispatch_pattern, success_metrics, kill_criteria, predecessors>
---

# Section 0 — Genesis            (kickoff)
# Section 1 — Pre-state baseline (kickoff, frozen)
# Section 2 — Live journal       (append-only, every PR + every cycle)
# Section 99 — Synthesis         (at v7.7 merge)
# Section 100 — 90-day retro    (at +90 days)
```

### 4.2 Append protocol

Every PR merge AND every measurement-adoption / documentation-debt cycle snapshot triggers an append. Each entry:

```
### YYYY-MM-DD HH:MM UTC — <event title>
- Trigger: <PR #N merged | cycle snapshot | hook fired | manual checkpoint>
- What changed: <files, codes, values>
- Ledger delta: <pre/post numbers>
- Surprises / discoveries: <not predicted in PRD>
- Tier tags: <T1/T2/T3 for any quantitative claim>
```

In parallel, `scripts/append-feature-log.py` writes a structured entry to `.claude/logs/framework-v7-7-validity-closure.log.json` (Tier 2.2 enforcement).

### 4.3 Final synthesis (Section 99)

Written at v7.7 merge. Contents:
- Pre/post metric deltas across all 5 tiers (table form)
- Honest accounting of what got gated, what stayed advisory, what stayed human-only
- Carry-forward of the 5 unclosable gaps from CLAUDE.md
- Cross-link chain diagram: Gemini audit → v7.5 → v7.6 → v7.7
- T1/T2/T3 tag audit on the case study itself

## 5. In-Flight Feature Pause Protocol

### 5.1 Hard-paused (6 features)

`app-store-assets`, `auth-polish-v2`, `import-training-plan`, `onboarding-v2-retroactive`, `push-notifications`, `stats-v2`

Each gets:

**State.json annotation:**
```json
{
  "paused": {
    "at": "2026-04-27",
    "reason": "v7.7 Validity Closure full-priority freeze",
    "resume_signal": "framework-v7-7-validity-closure phase=complete",
    "snapshot": {
      "current_phase": "<phase at pause>",
      "next_action_when_resumed": "<one-line>",
      "blockers": [],
      "context_links": ["<paths>"]
    }
  }
}
```

**Memory entry** at `~/.claude/projects/-Volumes-DevSSD-FitTracker2/memory/paused_<feature>.md` with frontmatter `type: project`, body listing pause reason, phase at pause, next action on resume, resume signal, blockers, and context links.

**MEMORY.md** gets a new section `## Paused (v7.7 freeze)` listing all 6.

### 5.2 Continuing naturally (2 features)

- **meta-analysis-audit** (phase=documentation): NO pause annotation. Allowed to complete its docs phase. Outputs feed v7.7 Phase 1 Research as inputs.
- **unified-control-center T43–T54**: migrated into v7.7 task list as M4 (T21–T28). UCC state.json gets a `tasks_migrated_to` annotation pointing at v7.7 M4. UCC is NOT paused — its other tasks remain as-is.

### 5.3 Pause execution order

1. Single commit `chore(framework): pause 6 features for v7.7 priority freeze` annotates 6 state.json files atomically
2. Memory entries written/updated (parallel — outside git, in `~/.claude/...`)
3. `MEMORY.md` index updated with new "Paused (v7.7 freeze)" section
4. Separate commit annotates UCC state.json with `tasks_migrated_to` field

### 5.4 Resume protocol

After v7.7 Phase 9 (Docs) closes:
1. Each paused feature's `resume_signal` is satisfied
2. Run `/pm-workflow <feature>` for each — it reads the snapshot, restores phase, continues from `next_action_when_resumed`
3. `paused` field stays in state.json as audit trail

## 6. Success Metrics

### 6.1 Primary metric

Post-v6 fully-adopted feature ratio on Tier 1.1 dimensions.

| Field | Value |
|---|---|
| Baseline (2026-04-27) | 2/9 = 22.2% |
| Target | ≥ 8/11 = 72.7% |
| Stretch | 100% post-v6 fully-adopted on the 4 gated dimensions for any feature shipping during the v7.7 window |
| Source | `make measurement-adoption` → `summary.fully_adopted_post_v6` |

### 6.2 Secondary (gated) metrics

| Metric | Baseline | Target | Mechanism |
|---|---|---|---|
| `cache_hits[]` writer-path | 33% post-v6 | 100% | M1 hook `CACHE_HITS_EMPTY_POST_V6` |
| `cu_v2` schema validity | unchecked | 100% | M1 hook `CU_V2_INVALID` |
| State↔case-study linkage | 95.5% | 100% | M2 hook `STATE_NO_CASE_STUDY_LINK` |
| Doc-debt fields populated | 4–61% | 100% on case studies dated ≥ 2026-04-28 | M2 hook `CASE_STUDY_MISSING_FIELDS` + bulk backfill |
| Tier 1.1 trend mode | locked | unlocked | passive cron unlock ~2026-05-04 |
| Tier 3.2 cycle-snapshot trend | locked | unlocked | passive cron unlock ~2026-05-03 to -06 |
| Tier-tag heuristic checker | nonexistent | shipped advisory; gated if FP < 10% | M3 |
| Framework-health dashboard | nonexistent | live at `/control-room/framework` | M4 |

### 6.3 Tertiary metrics (qualitative)

- Case-study journal ≥ 1 entry per PR merge (verified by audit at synthesis)
- 5 unclosable gaps documented honestly in synthesis
- All predecessor case-study cross-links resolve

## 7. Done Criteria

All must hold:

1. All 42 tasks (T0a–T0g + T1–T35) closed
2. All 8 PRs merged to main
3. Primary metric ≥ target
4. All secondary metrics meet target OR documented exception in case study
5. **External system propagation complete:**
   - CLAUDE.md updated with v7.7 section + version banner moved to "v7.5 → v7.6 → v7.7"
   - Master plan + RICE roadmap updated (v7.7 marked Shipped)
   - Linear epic closed; all sub-issues Done
   - Notion v7.7 sub-page status `Shipped`; "Project Context & Status" page reflects v7.7
6. Case-study Section 99 (Synthesis) written with full metrics audit
7. Human-action checklist surfaced for D1+D2
8. All 6 paused features have intact `paused` annotations and resume-ready memory entries

## 8. Kill Criteria

Any one triggers pause + decision point:

1. Cache-hits writer-path proves un-instrumentable (>5 distinct call sites with no shared loader)
2. Tier-tag checker FP rate stays >25% after 2 weeks → ship advisory-only
3. PR-1 instrumentation introduces >100ms latency to skill loading
4. Pre-commit hook FP rate >10% on legitimate commits in week-1 dogfooding → roll back hook
5. Framework-health dashboard reveals contradictions in ledgers → pause for ground-truth reconciliation

## 9. Post-Launch Metrics Review

- **Daily** for week 1: `make measurement-adoption` + `make documentation-debt` + dashboard
- **Weekly** for weeks 2–4: same, plus log new check-code firings
- **Monthly** thereafter: included in framework-health cron output
- **+90 days**: full retrospective appended as Section 100

## 10. Risks & Rollback

### 10.1 Top risks

- **Cache-hit instrumentation breaks skill loading** — mitigated by fail-soft helper + perf benchmark in PR-1
- **Bulk doc-debt backfill produces incorrect metadata** — mitigated by per-file TODO comments where inference fails; human review of bulk PR
- **Tier-tag heuristic checker fires excessive false positives** — mitigated by 7-day advisory window + FP-rate gate before promotion
- **Paused features drift out of resumability** — mitigated by snapshot capture in state.json + redundant memory entry

### 10.2 Rollback

Every PR is independently revertible. Pre-commit hooks are file-scoped and can be removed by reverting `.githooks/pre-commit`. No production data is modified — only state.json files, hook scripts, and case-study text. Worst case: revert all 8 PRs, paused features resume in current state.

## 11. Pre-Mortem Honesty Statement

> v7.7 closes every gap that is mechanically or heuristically closable. It will NOT close the 5 documented unclosable gaps. Anyone reading post-v7.7 metrics should expect 100% on gated dimensions and acknowledged gaps on judgment dimensions. A framework that knows what it cannot check is more trustworthy than one that pretends every check is a check.

## 12. References

- CLAUDE.md "Data Integrity Framework" + "Known Mechanical Limits"
- `docs/case-studies/data-integrity-framework-v7.5-case-study.md`
- `docs/case-studies/meta-analysis/unclosable-gaps.md`
- `trust/audits/2026-04-21-gemini/remediation-plan-2026-04-23.md`
- `.claude/integrity/README.md`
- `docs/superpowers/specs/2026-04-27-framework-health-dashboard-design.md` (absorbed as M4)
