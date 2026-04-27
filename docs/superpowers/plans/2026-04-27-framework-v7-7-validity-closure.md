# Framework v7.7 — Validity Closure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close every mechanically or heuristically closable gap in the data-integrity framework via 8 chained PRs, full Linear/Notion/CLAUDE.md/master-plan propagation, and a continuous append-only case study journal.

**Architecture:** Single feature branch `feature/framework-v7-7-validity-closure` driving 8 PRs across 6 milestones. New write-time pre-commit hooks for `cache_hits[]` writer-path enforcement, `cu_v2` schema validation, state↔case-study linkage, and case-study field gates. New cycle-time advisory check for tier-tag correctness. Framework-health dashboard absorbs UCC T43–T54 and surfaces all v7.7 outputs at `/control-room/framework`.

**Tech Stack:** Python 3.11 (hooks + scripts), Bash + GitHub Actions (CI), Next.js 15 App Router (dashboard, fitme-story repo), Linear MCP, Notion MCP, git pre-commit hooks at `.githooks/`.

**Spec:** [`docs/superpowers/specs/2026-04-27-framework-v7-7-validity-closure-design.md`](../specs/2026-04-27-framework-v7-7-validity-closure-design.md)

**Predecessor case studies (chain):** Gemini audit (2026-04-21) → v7.5 (2026-04-24) → v7.6 (2026-04-25) → **v7.7**

---

## Executive Summary

42 tasks (T0a–T0g + T1–T35), 8 PRs + 1 commit-only kickoff bundle, 6 milestones (M0 + M1–M5). Estimated ~2-3 weeks calendar time, partly gated by passive cron firings (B1 Tier 1.1 trend ~2026-05-04; B2 Tier 3.2 trend ~2026-05-03 to -06).

| Milestone | Tasks | PR | Closes | Critical path |
|---|---|---|---|---|
| M0 — Kickoff propagation | T0a–T0g | commit-only | Pause-protocol, MCP sync, CLAUDE.md banner | yes — gates feature start |
| M1 — Writer-path & schema | T1–T8 | PR-1, PR-2 | A1 (#140), A2 | yes — biggest validity lift |
| M2 — Linkage & doc-debt | T9–T16 | PR-3, PR-4, PR-5 | A3, A4, A5 | yes |
| M3 — Tier-tag heuristic | T17–T20 | PR-6 | C1 | parallelizable with M4 |
| M4 — Framework-health dashboard | T21–T28 | PR-7 | UCC T43–T54 absorbed | parallelizable with M3 |
| M5 — Closure & synthesis | T29–T35 | PR-8 | B1 verify, B2 verify, all propagation | last — depends on B1/B2 cron firings |

---

## File Structure

### Files Created (in main repo)

```
.claude/features/framework-v7-7-validity-closure/state.json     # T0a (PRD phase)
.claude/logs/framework-v7-7-validity-closure.log.json           # T0a
docs/case-studies/framework-v7-7-validity-closure-case-study.md # T0a (live journal)
docs/architecture/cache-read-paths.md                           # T1 (audit output)
docs/case-studies/meta-analysis/tier-tag-checker-baseline.md    # T19
scripts/log-cache-hit.py                                        # T2 (helper)
scripts/validate-cu-v2.py                                       # T6
scripts/backfill-case-study-fields.py                           # T13
scripts/validate-tier-tags.py                                   # T17
```

### Files Modified (in main repo)

```
.githooks/pre-commit                  # T3, T7, T11, T12 (4 new hooks added)
scripts/integrity-check.py            # T7, T17 (new check codes)
scripts/check-state-schema.py         # T3, T11, T12 (new schema rules)
Makefile                              # T17 (new targets)
CLAUDE.md                             # T0d (banner stub), T32 (final v7.7 section)
docs/master-plan/master-plan-2026-04-06.md          # T0e, T33
docs/master-plan/master-backlog-roadmap.md          # T0e, T33
docs/case-studies/framework-v7-7-...-case-study.md  # appended every PR + every cycle
.claude/features/{6 paused features}/state.json     # T0a (paused annotation)
.claude/features/unified-control-center/state.json  # T0b (tasks_migrated_to)
```

### Files Created (in fitme-story repo, M4 only)

```
app/control-room/framework/page.tsx                 # T21
app/control-room/framework/loading.tsx              # T21
components/framework-health/AdoptionTrendChart.tsx  # T21
components/framework-health/DocDebtTrendChart.tsx   # T22
components/framework-health/AutomationMap.tsx       # T23
components/framework-health/HumanActionPanel.tsx    # T24
components/framework-health/CycleSnapshotPanel.tsx  # T25
lib/framework-health/load-ledgers.ts                # T21 (data loader)
```

### External Mutations (no files)

- Linear MCP: create v7.7 epic + 8 sub-issues at M0; close at M5
- Notion MCP: create v7.7 sub-page at M0; update at M5
- GitHub: close issue #140 at M1 PR-1; reference issue #142 at M5

---

## Pre-Flight: Branch Setup

- [ ] **Step 0.1: Create feature branch from current main**

```bash
cd /Volumes/DevSSD/FitTracker2
git checkout main
git pull origin main
git checkout -b feature/framework-v7-7-validity-closure
git status
```

Expected: clean tree, on `feature/framework-v7-7-validity-closure`.

- [ ] **Step 0.2: Verify current ledger baseline before any v7.7 changes**

```bash
make measurement-adoption
make documentation-debt
```

Expected output snapshot (will be quoted in case-study Section 1):
- `summary.fully_adopted_post_v6: 2`
- `summary.features_total: 44`
- `cache_hits.post_v6_percent: 33.3`
- `cu_v2.post_v6_percent: 66.7`
- `documentation-debt summary.open_debt_items: 7`

If numbers differ materially from the spec's frozen baseline (§3.1), pause and update spec before proceeding.

---

## M0 — Kickoff Propagation (commit-only, no PR)

**Goal:** Fan out the v7.7 declaration to every system that needs to know — state.json files for paused features, memory entries (already done in brainstorming session), CLAUDE.md banner stub, master plan, Linear, Notion. Establishes the case-study live journal at PRD-approval moment.

### Task T0a: Bootstrap v7.7 feature directory + case-study skeleton

**Files:**
- Create: `.claude/features/framework-v7-7-validity-closure/state.json`
- Create: `.claude/logs/framework-v7-7-validity-closure.log.json`
- Create: `docs/case-studies/framework-v7-7-validity-closure-case-study.md`

- [ ] **Step T0a.1: Create state.json with v7.6-compliant schema**

```bash
mkdir -p .claude/features/framework-v7-7-validity-closure
```

Create `.claude/features/framework-v7-7-validity-closure/state.json`:

```json
{
  "feature_name": "framework-v7-7-validity-closure",
  "current_phase": "research",
  "created_at": "2026-04-27T14:00:00Z",
  "work_type": "Feature",
  "phases": {
    "research": {"status": "in_progress", "started_at": "2026-04-27T14:00:00Z"},
    "prd": {"status": "not_started"},
    "tasks": {"status": "not_started"},
    "ux_or_integration": {"status": "not_started"},
    "implementation": {"status": "not_started"},
    "test": {"status": "not_started"},
    "review": {"status": "not_started"},
    "merge": {"status": "not_started"},
    "documentation": {"status": "not_started"}
  },
  "timing": {
    "phases": {
      "research": {"started_at": "2026-04-27T14:00:00Z"}
    }
  },
  "cache_hits": [],
  "cu_v2": {
    "factors": {
      "complexity": 0.85,
      "blast_radius": 0.7,
      "novelty": 0.6,
      "verification_difficulty": 0.5
    },
    "total": 2.65,
    "tier_class": "A_high"
  },
  "case_study": "docs/case-studies/framework-v7-7-validity-closure-case-study.md",
  "predecessor_features": [
    "data-integrity-framework-v7-5",
    "mechanical-enforcement-v7-6",
    "gemini-audit-2026-04-21",
    "meta-analysis-audit"
  ],
  "spec_path": "docs/superpowers/specs/2026-04-27-framework-v7-7-validity-closure-design.md",
  "plan_path": "docs/superpowers/plans/2026-04-27-framework-v7-7-validity-closure.md"
}
```

- [ ] **Step T0a.2: Create case-study live journal skeleton**

Create `docs/case-studies/framework-v7-7-validity-closure-case-study.md`:

```markdown
---
title: Framework v7.7 — Validity Closure
date_written: 2026-04-27
work_type: Feature
dispatch_pattern: serial
success_metrics:
  primary: "post-v6 fully-adopted ratio: baseline 2/9 = 22.2% → target ≥8/11 = 72.7%"
  secondary:
    - "cache_hits writer-path: 33% → 100% (gated)"
    - "cu_v2 schema validity: unchecked → 100% (gated)"
    - "state↔case-study linkage: 95.5% → 100% (gated)"
    - "doc-debt fields populated: 4-61% → 100% on case studies dated ≥ 2026-04-28 (gated)"
kill_criteria:
  - "Cache-hits writer-path proves un-instrumentable (>5 distinct call sites with no shared loader)"
  - "Tier-tag checker false-positive rate stays >25% after 2 weeks"
  - "PR-1 instrumentation introduces >100ms latency to skill loading"
  - "Pre-commit hook FP rate >10% on legitimate commits in week-1 dogfooding"
  - "Framework-health dashboard reveals contradictions in ledgers"
predecessor_case_studies:
  - "docs/case-studies/data-integrity-framework-v7.5-case-study.md"
  - "trust/audits/2026-04-21-gemini/remediation-plan-2026-04-23.md"
  - "docs/case-studies/meta-analysis-full-system-audit-v7.0-case-study.md"
spec_path: docs/superpowers/specs/2026-04-27-framework-v7-7-validity-closure-design.md
plan_path: docs/superpowers/plans/2026-04-27-framework-v7-7-validity-closure.md
status: live
---

# Framework v7.7 — Validity Closure

> **Live append-only journal.** Each PR merge and each cycle snapshot appends an entry. No retroactive edits. Final synthesis (Section 99) at v7.7 merge.

## Section 0 — Genesis

The 2026-04-21 Gemini independent audit drove v7.5 (Data Integrity Framework, shipped 2026-04-24). v7.6 (Mechanical Enforcement, shipped 2026-04-25) closed seven Class B → Class A gaps but explicitly documented five remaining "Known Mechanical Limits" in CLAUDE.md.

On 2026-04-27, a session-driven audit pulled live ledger state and surfaced the closable subset of those limits. User declared full-priority freeze on all 8 in-flight features (6 hard-paused, 2 continuing naturally) to land v7.7 — the validity-closure pass — as the next framework version.

v7.7 closes A1–A5 + B1–B2 + C1 from the gap inventory. D1 (real-provider auth playbook) and D2 (external replication) deferred to a post-v7.7 follow-on track surfaced as a human-action checklist at v7.7 merge.

## Section 1 — Pre-state Baseline (frozen 2026-04-27 14:00 UTC)

**Tier 1.1 measurement adoption (post-v6 features):**

| Dimension | Overall | Post-v6 |
|---|---|---|
| `timing.total_wall_time_minutes` | 5/44 (11.4%) | 5/9 (55.6%) |
| Per-phase timing | 7/44 (15.9%) | 6/9 (66.7%) |
| `cache_hits[]` | 3/44 (6.8%) | 3/9 (33.3%) ⚠ #140 |
| `cu_v2` factors | 6/44 (13.6%) | 6/9 (66.7%) |

Fully adopted post-v6: **2/9** (data-integrity-framework-v7-6, meta-analysis-audit).

**Tier 3.2 documentation debt:** 7 open items; trend mode locked (0/3 cycle snapshots). State↔case-study linkage 42/44 (95.5%).

**5 unclosable gaps** carried forward from CLAUDE.md "Known Mechanical Limits": cache_hits writer-path adoption (closes via M1), cu_v2 magnitude judgment, T1/T2/T3 correctness on novel claims, real-provider auth simulator runs (D1, deferred), external replication (D2, deferred).

## Section 2 — Live Journal (append-only)

<!-- Each entry follows the schema in spec §4.2.
     Append after every PR merge AND every cycle snapshot. Never edit prior entries. -->

### 2026-04-27 14:00 UTC — Genesis & spec approval
- **Trigger:** brainstorming + spec approved by user (commit `1057144`)
- **What changed:** spec written; case study journal created; 6 paused-feature memories saved
- **Ledger delta:** none yet (M0 in progress)
- **Surprises / discoveries:** Pre-commit hooks didn't refuse the empty `cache_hits: []` array on auth-polish-v2 — confirms the v7.6 hook checks presence of the key, not non-empty content. This is the exact gap M1 closes.
- **Tier tags applied:** Section 1 baseline numbers all T1 (instrumented from `make measurement-adoption` + `make documentation-debt` ledger output, frozen 2026-04-27).

## Section 99 — Synthesis (written at v7.7 merge)

<!-- Populate at M5. See plan §M5 / T31. -->

## Section 100 — 90-day Retrospective (written +90 days post-merge)

<!-- Populate via /schedule agent at +90 days. See plan §M5 / T31 footer. -->
```

- [ ] **Step T0a.3: Create empty Tier 2.2 log**

```bash
echo '[]' > .claude/logs/framework-v7-7-validity-closure.log.json
```

- [ ] **Step T0a.4: Append first log entry via append-feature-log.py**

```bash
python3 scripts/append-feature-log.py framework-v7-7-validity-closure phase_started research \
  --extra '{"trigger":"v7.7 bootstrap","spec_commit":"1057144"}'
```

Expected: log entry appended; exit 0.

- [ ] **Step T0a.5: Commit T0a artifacts**

```bash
git add .claude/features/framework-v7-7-validity-closure/state.json \
  .claude/logs/framework-v7-7-validity-closure.log.json \
  docs/case-studies/framework-v7-7-validity-closure-case-study.md
git commit -m "$(cat <<'EOF'
feat(framework-v7-7): bootstrap feature state + live case-study journal

T0a: creates state.json with v7.6-compliant schema (timing.phases populated,
cu_v2 factors set, cache_hits as empty array intentionally — to be populated
by M1's writer-path instrumentation). Establishes case-study skeleton with
frozen 2026-04-27 baseline (Section 1) and Section 0 genesis.

Predecessor chain documented: Gemini audit → v7.5 → v7.6 → v7.7.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Expected: commit succeeds; pre-commit hooks pass (state.json schema valid, case-study has tier tags + dispatch_pattern).

### Task T0b: Annotate UCC state.json with v7.7 absorption

**Files:**
- Modify: `.claude/features/unified-control-center/state.json`

- [ ] **Step T0b.1: Read current UCC state.json**

```bash
cat .claude/features/unified-control-center/state.json | python3 -m json.tool | head -30
```

- [ ] **Step T0b.2: Add `tasks_migrated_to` field via Edit (preserves rest of file)**

Edit `.claude/features/unified-control-center/state.json` — add `tasks_migrated_to` field at the top level (sibling of `phases`):

```json
{
  "...existing fields preserved...",
  "tasks_migrated_to": {
    "T43-T54": {
      "to_feature": "framework-v7-7-validity-closure",
      "to_milestone": "M4",
      "to_tasks": "T21-T28",
      "migrated_at": "2026-04-27T14:00:00Z",
      "rationale": "Framework-health dashboard naturally surfaces v7.7 outputs (Tier 1.1/3.2 trends, automation map, human-action checklist). Absorption avoids parallel track."
    }
  }
}
```

- [ ] **Step T0b.3: Commit T0b**

```bash
git add .claude/features/unified-control-center/state.json
git commit -m "$(cat <<'EOF'
chore(unified-control-center): migrate T43-T54 into framework-v7-7 M4

Framework-health dashboard tasks T43-T54 absorb into v7.7 milestone M4
(T21-T28). UCC state stays open for its other tasks; absorption recorded
via new tasks_migrated_to field.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task T0c: Pause 6 in-flight features (atomic state.json commit)

**Files:**
- Modify: `.claude/features/app-store-assets/state.json`
- Modify: `.claude/features/auth-polish-v2/state.json`
- Modify: `.claude/features/import-training-plan/state.json`
- Modify: `.claude/features/onboarding-v2-retroactive/state.json`
- Modify: `.claude/features/push-notifications/state.json`
- Modify: `.claude/features/stats-v2/state.json`

- [ ] **Step T0c.1: Add `paused` field to each of 6 state.json files via Edit**

For each feature, append a top-level `paused` field. Template (substitute `{phase_at_pause}` and `{next_action}` from each feature's current state — values cached in the `paused_*.md` memory files):

```json
{
  "...existing fields preserved...",
  "paused": {
    "at": "2026-04-27T14:00:00Z",
    "reason": "v7.7 Validity Closure full-priority freeze",
    "resume_signal": "framework-v7-7-validity-closure phase=complete",
    "snapshot": {
      "current_phase": "{phase_at_pause}",
      "next_action_when_resumed": "{next_action}",
      "blockers": [],
      "context_links": []
    }
  }
}
```

Per-feature values:

| Feature | phase_at_pause | next_action_when_resumed |
|---|---|---|
| app-store-assets | implementation | "Resume implementation; resolve case_study link or apply no_case_study_required exempt tag" |
| auth-polish-v2 | prd | "Continue PRD phase; cache_hits will populate automatically once v7.7 M1 writer-path lands" |
| import-training-plan | implementation | "Resume implementation; v7.7 M2 T15 will have backfilled timing.phases pre-resume" |
| onboarding-v2-retroactive | tasks | "Complete tasks phase; resolve case_study link or exempt tag" |
| push-notifications | implementation | "Resume implementation; coordinate with smart-reminders if both resume close in time" |
| stats-v2 | tasks | "Reconcile current_phase=tasks vs phases.implementation field; resume tasks phase" |

- [ ] **Step T0c.2: Commit T0c atomically**

```bash
git add .claude/features/app-store-assets/state.json \
  .claude/features/auth-polish-v2/state.json \
  .claude/features/import-training-plan/state.json \
  .claude/features/onboarding-v2-retroactive/state.json \
  .claude/features/push-notifications/state.json \
  .claude/features/stats-v2/state.json
git commit -m "$(cat <<'EOF'
chore(framework): pause 6 features for v7.7 priority freeze

T0c: atomic pause-protocol commit annotates 6 in-flight features with the
v7.7 freeze. Resume signal: framework-v7-7-validity-closure phase=complete.

Paused features:
- app-store-assets (implementation)
- auth-polish-v2 (prd)
- import-training-plan (implementation)
- onboarding-v2-retroactive (tasks)
- push-notifications (implementation)
- stats-v2 (tasks)

Continuing naturally (no pause): meta-analysis-audit (documentation phase
will complete normally), unified-control-center (T43-T54 absorbed into v7.7 M4
per separate commit).

Memory-layer pause snapshots already saved at
~/.claude/projects/-Volumes-DevSSD-FitTracker2/memory/paused_*.md

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task T0d: CLAUDE.md banner update (in-progress stub)

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step T0d.1: Update version banner**

Edit `CLAUDE.md` — find the line `## Data Integrity Framework (v7.5 → v7.6, shipped 2026-04-24 → 2026-04-25)` and replace with:

```markdown
## Data Integrity Framework (v7.5 → v7.6 → v7.7-IN-PROGRESS, shipped 2026-04-24 → 2026-04-25 → ___)
```

- [ ] **Step T0d.2: Append v7.7 stub section**

After the v7.6 "Per-PR + weekly defenses" section (just before "## Known Mechanical Limits"), insert:

```markdown
**v7.7 Validity Closure (in progress, started 2026-04-27):**
Closes A1–A5 + B1–B2 + C1 from the post-v7.6 gap inventory. Adds 4 new
write-time hooks (`CACHE_HITS_EMPTY_POST_V6`, `CU_V2_INVALID`,
`STATE_NO_CASE_STUDY_LINK`, `CASE_STUDY_MISSING_FIELDS`) plus one cycle-time
advisory check (`TIER_TAG_LIKELY_INCORRECT`). Spec at
[`docs/superpowers/specs/2026-04-27-framework-v7-7-validity-closure-design.md`](docs/superpowers/specs/2026-04-27-framework-v7-7-validity-closure-design.md).
Live case study at
[`docs/case-studies/framework-v7-7-validity-closure-case-study.md`](docs/case-studies/framework-v7-7-validity-closure-case-study.md).
Final v7.7 section will replace this stub at merge (T32).
```

- [ ] **Step T0d.3: Commit T0d**

```bash
git add CLAUDE.md
git commit -m "$(cat <<'EOF'
docs(framework-v7-7): CLAUDE.md banner stub for v7.7 in-progress

T0d: bumps version banner to v7.5 → v7.6 → v7.7-IN-PROGRESS and adds
stub section pointing to spec + live case study. Final v7.7 section
replaces stub at M5 / T32.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task T0e: Master plan + RICE roadmap update

**Files:**
- Modify: `docs/master-plan/master-plan-2026-04-06.md`
- Modify: `docs/master-plan/master-backlog-roadmap.md`

- [ ] **Step T0e.1: Add v7.7 entry to master plan**

Edit `docs/master-plan/master-plan-2026-04-06.md` — find the section listing recent shipped framework versions (v7.5, v7.6) and add a v7.7 entry as the current top priority. Reference the spec, case study, and the 6 paused features.

Insertion template (place at the appropriate "Active Priorities" location — find the existing top priority and insert above it):

```markdown
### v7.7 Validity Closure (ACTIVE — full-priority freeze, started 2026-04-27)
- **Spec:** [docs/superpowers/specs/2026-04-27-framework-v7-7-validity-closure-design.md](../superpowers/specs/2026-04-27-framework-v7-7-validity-closure-design.md)
- **Plan:** [docs/superpowers/plans/2026-04-27-framework-v7-7-validity-closure.md](../superpowers/plans/2026-04-27-framework-v7-7-validity-closure.md)
- **Case study (live):** [docs/case-studies/framework-v7-7-validity-closure-case-study.md](../case-studies/framework-v7-7-validity-closure-case-study.md)
- **Closes:** A1–A5 + B1–B2 + C1 from post-v7.6 gap inventory
- **Primary metric:** post-v6 fully-adopted ratio 2/9 → ≥8/11
- **Paused for v7.7:** app-store-assets, auth-polish-v2, import-training-plan, onboarding-v2-retroactive, push-notifications, stats-v2
- **Continuing naturally:** meta-analysis-audit (docs phase), UCC T43–T54 (absorbed as v7.7 M4)
- **ETA:** ~2-3 weeks; partly gated by passive cron firings (B1 ~2026-05-04, B2 ~2026-05-03 to -06)
```

- [ ] **Step T0e.2: Add v7.7 row to RICE roadmap**

Edit `docs/master-plan/master-backlog-roadmap.md` — locate the framework-version rows (v7.5, v7.6) and add a v7.7 row in the same table format. Use the row's existing schema; do not invent new columns.

- [ ] **Step T0e.3: Commit T0e**

```bash
git add docs/master-plan/master-plan-2026-04-06.md docs/master-plan/master-backlog-roadmap.md
git commit -m "$(cat <<'EOF'
docs(master-plan): add v7.7 Validity Closure as active top priority

T0e: master plan + RICE roadmap reflect v7.7 in active development.
Lists 6 paused features and 2 continuing naturally. Cross-links spec,
plan, and live case study.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task T0f: Linear sync via MCP — create v7.7 epic + 8 sub-issues

**Tooling:** `mcp__linear__save_issue`, `mcp__linear__save_project`, `mcp__linear__list_teams`, `mcp__linear__list_projects` (load via ToolSearch first).

- [ ] **Step T0f.1: Load Linear MCP tools**

```
ToolSearch query "select:mcp__linear__save_issue,mcp__linear__list_teams,mcp__linear__list_projects,mcp__linear__list_issue_statuses,mcp__linear__list_users"
```

- [ ] **Step T0f.2: Resolve team + parent project + assignee**

```
mcp__linear__list_teams                    # find "FitMe" team id
mcp__linear__list_projects                 # find Framework parent project (where v7.5/v7.6 live)
mcp__linear__list_users                    # find Regev's user id (assignee)
mcp__linear__list_issue_statuses           # find "In Progress" status id for the team
```

Cache results for use in next steps.

- [ ] **Step T0f.3: Create v7.7 epic via mcp__linear__save_issue**

```
mcp__linear__save_issue with:
  team: <FitMe team id>
  title: "v7.7 — Validity Closure"
  description: |
    Closes A1–A5 + B1–B2 + C1 from post-v7.6 gap inventory.

    Spec: docs/superpowers/specs/2026-04-27-framework-v7-7-validity-closure-design.md
    Plan: docs/superpowers/plans/2026-04-27-framework-v7-7-validity-closure.md
    Case study (live): docs/case-studies/framework-v7-7-validity-closure-case-study.md

    Predecessor chain: Gemini audit → v7.5 → v7.6 → v7.7.

    Closes:
    - A1: cache_hits writer-path (closes #140)
    - A2: cu_v2 schema validator
    - A3: documentation-debt field gates
    - A4: state↔case-study linkage to 100%
    - A5: active-feature timing backfill
    - B1: Tier 1.1 trend-mode unlock (passive)
    - B2: Tier 3.2 cycle-snapshot trend-mode unlock (passive)
    - C1: tier-tag heuristic correctness checker (advisory → conditional gate)

    Deferred (post-v7.7 follow-on):
    - D1: Tier 2.1 real-provider auth playbook
    - D2: Tier 3.3 external replication
  state: <"In Progress" status id>
  assignee: <Regev's user id>
  project: <Framework parent project id>
  labels: ["framework", "data-integrity", "v7.7"]
```

Capture the returned issue id (FIT-XX) for sub-issue parent links.

- [ ] **Step T0f.4: Create 8 sub-issues under the v7.7 epic**

For each milestone+PR pair, call `mcp__linear__save_issue` with `parent: <v7.7 epic id>`. Title format: `v7.7 PR-N: <description>`. Include task list in description.

| PR | Title | Tasks |
|---|---|---|
| PR-1 | `v7.7 PR-1: cache_hits writer-path (#140)` | T1, T2, T3, T4, T5 |
| PR-2 | `v7.7 PR-2: cu_v2 schema validator` | T6, T7, T8 |
| PR-3 | `v7.7 PR-3: state↔case-study linkage gate` | T9, T10, T11 |
| PR-4 | `v7.7 PR-4: doc-debt field gates + bulk backfill` | T12, T13, T14 |
| PR-5 | `v7.7 PR-5: active-feature timing backfill` | T15, T16 |
| PR-6 | `v7.7 PR-6: tier-tag heuristic checker` | T17, T18, T19, T20 |
| PR-7 | `v7.7 PR-7: framework-health dashboard` | T21–T28 |
| PR-8 | `v7.7 PR-8: closure synthesis + propagation` | T29–T35 |

- [ ] **Step T0f.5: Verify Linear state**

Run `mcp__linear__list_issues` filtered to project=Framework, label=v7.7 → expect 1 epic + 8 sub-issues, all `In Progress`.

### Task T0g: Notion sync via MCP — v7.7 sub-page + parent updates

**Tooling:** `mcp__notion__notion-create-pages`, `mcp__notion__notion-update-page`, `mcp__notion__notion-search` (load via ToolSearch).

- [ ] **Step T0g.1: Load Notion MCP tools**

```
ToolSearch query "select:mcp__notion__notion-create-pages,mcp__notion__notion-update-page,mcp__notion__notion-search,mcp__notion__notion-fetch"
```

- [ ] **Step T0g.2: Find the parent "Data Integrity Framework" page**

```
mcp__notion__notion-search query="Data Integrity Framework v7.5"
```

Locate the parent page id (where v7.5 and v7.6 sub-pages live).

- [ ] **Step T0g.3: Create v7.7 sub-page**

```
mcp__notion__notion-create-pages with:
  parent: <Data Integrity Framework parent page id>
  title: "v7.7 — Validity Closure"
  body (markdown):
    # Framework v7.7 — Validity Closure

    **Status:** In Progress (started 2026-04-27)
    **Spec:** docs/superpowers/specs/2026-04-27-framework-v7-7-validity-closure-design.md
    **Plan:** docs/superpowers/plans/2026-04-27-framework-v7-7-validity-closure.md
    **Live case study:** docs/case-studies/framework-v7-7-validity-closure-case-study.md
    **Linear epic:** FIT-XX (see T0f output)

    ## Scope (in)
    - A1–A5 + B1–B2 + C1 from post-v7.6 gap inventory
    - UCC T43–T54 absorbed as M4 (framework-health dashboard)

    ## Scope (deferred)
    - D1: Tier 2.1 real-provider auth playbook (human-required)
    - D2: Tier 3.3 external replication (structural; #142)

    ## Predecessor chain
    Gemini audit → v7.5 → v7.6 → **v7.7**

    ## Pre-state baseline (frozen 2026-04-27)
    - post-v6 fully-adopted: 2/9 (22.2%)
    - target: ≥8/11 (72.7%)
    - cache_hits writer-path: 33% post-v6 (issue #140)
    - state↔case-study linkage: 95.5%
```

- [ ] **Step T0g.4: Update v7.6 sub-page footer with forward link**

```
mcp__notion__notion-update-page with:
  page_id: <v7.6 sub-page id>
  command: "append"
  body: "\n\n---\n\n→ **Extended by [v7.7 — Validity Closure](<v7.7 sub-page URL>) (in progress, started 2026-04-27).**"
```

- [ ] **Step T0g.5: Update "Project Context & Status" page**

```
mcp__notion__notion-search query="Project Context & Status"
```

Find the main status page; update version line from "v7.6" to "v7.5 → v7.6 → v7.7-IN-PROGRESS".

- [ ] **Step T0g.6: No git commit — Notion is external**

After T0g, append to case-study Section 2 with a journal entry noting Linear epic id, Notion page URL, and timestamp.

### M0 Verification

- [ ] **Step M0.verify.1: Confirm all M0 commits landed**

```bash
git log --oneline -10
```

Expected: 5 v7.7 commits (T0a, T0b, T0c, T0d, T0e) on top of the spec commit.

- [ ] **Step M0.verify.2: Run integrity-check baseline**

```bash
make measurement-adoption
make documentation-debt
python3 scripts/integrity-check.py --findings-only
```

Expected: no NEW findings introduced. measurement-adoption shows 1 new feature (framework-v7-7-validity-closure) listed under fully_adopted (it has cu_v2 + timing.phases populated; cache_hits is empty array but that's per spec).

- [ ] **Step M0.verify.3: Append M0-complete entry to case study**

Append to `docs/case-studies/framework-v7-7-validity-closure-case-study.md` Section 2:

```markdown
### YYYY-MM-DD HH:MM UTC — M0 Kickoff Propagation complete
- **Trigger:** T0a–T0g all closed
- **What changed:** v7.7 feature directory bootstrapped; 6 features paused; UCC absorbed; CLAUDE.md banner stubbed; master plan updated; Linear epic FIT-XX + 8 sub-issues created; Notion v7.7 sub-page live
- **Ledger delta:** features_total 44 → 45 (v7.7 itself); fully_adopted_post_v6 unchanged (v7.7 has cache_hits=[], gated by M1)
- **Surprises / discoveries:** v7.7's own `cache_hits: []` is the first feature that will be auto-populated by the M1 instrumentation we're about to ship — the spec is dogfooding itself.
- **Tier tags applied:** T1 for ledger numbers; T2 for predicted M1 behavior.
```

```bash
git add docs/case-studies/framework-v7-7-validity-closure-case-study.md
git commit -m "$(cat <<'EOF'
docs(framework-v7-7): journal — M0 kickoff propagation complete

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

**M0 done. Proceed to M1.**

---

## M1 — Writer-path & Schema Gates (PR-1, PR-2)

**Goal:** Land the two highest-leverage hooks. PR-1 closes the `cache_hits[]` writer-path adoption gap (issue #140) — the single biggest credibility lever. PR-2 adds `cu_v2` schema validation.

### Task T1: Audit cache read sites

**Files:**
- Create: `docs/architecture/cache-read-paths.md`

- [ ] **Step T1.1: Enumerate cache directories**

```bash
find .claude/cache -type d -maxdepth 2 | sort
ls .claude/cache/_shared/ 2>/dev/null
ls .claude/cache/_project/ 2>/dev/null
ls -d .claude/cache/L1-* .claude/cache/L2-* 2>/dev/null
```

Capture output. Cache layers per memory: L1 (per-skill), L2 (`_shared/`), L3 (`_project/`).

- [ ] **Step T1.2: Search code for cache read call sites**

```bash
grep -rn "claude/cache" .claude/ scripts/ 2>/dev/null | grep -v "\.md:" | head -50
grep -rn "cache_hits" .claude/ scripts/ 2>/dev/null | head -50
grep -rn "load_cache\|read_cache\|cache_load\|cache_read" .claude/ scripts/ 2>/dev/null | head -30
```

- [ ] **Step T1.3: Inventory cache reads in pm-workflow + skill loader**

```bash
ls .claude/skills/ | head -20
find .claude -name "SKILL.md" | head -10
grep -rn "cache" .claude/skills/pm-workflow/ 2>/dev/null | grep -v "^Binary" | head -20
```

- [ ] **Step T1.4: Write the audit document**

Create `docs/architecture/cache-read-paths.md`:

```markdown
# Cache Read Paths Inventory

> Compiled 2026-04-27 by v7.7 T1 to scope the cache_hits writer-path
> instrumentation (M1 / closes #140). The instrumentation strategy
> depends on every read site being able to reach a single shared logger.

## Layer 1 — Per-skill caches (.claude/cache/L1-*)

<paste enumeration from T1.1>

## Layer 2 — Shared caches (.claude/cache/_shared/)

<paste enumeration>

## Layer 3 — Project caches (.claude/cache/_project/)

<paste enumeration>

## Read call sites identified

<table — for each call site: file:line, layer, sync/async, currently logged?>

## Instrumentation strategy decision

After enumeration: confirm every call site can reach
`scripts/log-cache-hit.py` synchronously without breaking existing read
behavior. If >5 distinct call sites have no shared loader, **kill criterion
1 fires** — pause M1 and escalate before T2.
```

- [ ] **Step T1.5: Make the kill-criterion-1 decision**

Count distinct read sites. If ≤ 5 with at least one shared loader path, **proceed to T2**. If > 5 with no shared loader, **STOP** and append a journal entry recording the kill-criterion fire. Do not proceed without re-scoping with user.

- [ ] **Step T1.6: Commit T1**

```bash
git add docs/architecture/cache-read-paths.md
git commit -m "$(cat <<'EOF'
docs(framework-v7-7): cache read-paths inventory (T1)

T1 produces the audit needed to scope the cache_hits writer-path
instrumentation (M1 / closes #140). Confirms <kill criterion 1 result>.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task T2: Cache-hit logger helper

**Files:**
- Create: `scripts/log-cache-hit.py`
- Test: `scripts/tests/test_log_cache_hit.py`

- [ ] **Step T2.1: Write failing test for the helper**

Create `scripts/tests/test_log_cache_hit.py`:

```python
"""Tests for scripts/log-cache-hit.py helper.

The helper appends a {key, layer, ts} entry to the active feature's
state.json cache_hits[] field. Active feature = most-recently-modified
state.json under .claude/features/*/.
"""
import json
import os
import subprocess
import tempfile
from pathlib import Path


def test_appends_entry_to_active_feature(tmp_path, monkeypatch):
    """When called with key + layer, appends one entry to active feature."""
    # Arrange: temp repo with one feature
    feat_dir = tmp_path / ".claude" / "features" / "test-feature"
    feat_dir.mkdir(parents=True)
    state_path = feat_dir / "state.json"
    state_path.write_text(json.dumps({
        "feature_name": "test-feature",
        "current_phase": "implementation",
        "cache_hits": []
    }))
    monkeypatch.chdir(tmp_path)

    # Act
    result = subprocess.run(
        ["python3", str(Path(__file__).parent.parent / "log-cache-hit.py"),
         "--key", "skill:pm-workflow", "--layer", "L1"],
        capture_output=True, text=True
    )

    # Assert
    assert result.returncode == 0, f"stderr: {result.stderr}"
    state = json.loads(state_path.read_text())
    assert len(state["cache_hits"]) == 1
    entry = state["cache_hits"][0]
    assert entry["key"] == "skill:pm-workflow"
    assert entry["layer"] == "L1"
    assert "ts" in entry
    assert entry["ts"].endswith("Z")  # UTC ISO


def test_fails_soft_when_no_active_feature(tmp_path, monkeypatch):
    """When no .claude/features/*/state.json exists, exits 0 silently."""
    monkeypatch.chdir(tmp_path)
    result = subprocess.run(
        ["python3", str(Path(__file__).parent.parent / "log-cache-hit.py"),
         "--key", "x", "--layer", "L2"],
        capture_output=True, text=True
    )
    # Fail-soft: exit 0 so cache reads aren't broken by logging errors
    assert result.returncode == 0


def test_picks_most_recently_modified_feature(tmp_path, monkeypatch):
    """When multiple features exist, picks the most-recently-modified."""
    import time
    for i, name in enumerate(["older", "newer"]):
        feat = tmp_path / ".claude" / "features" / name
        feat.mkdir(parents=True)
        state = feat / "state.json"
        state.write_text(json.dumps({"feature_name": name, "cache_hits": []}))
        time.sleep(0.05)
    monkeypatch.chdir(tmp_path)

    subprocess.run(
        ["python3", str(Path(__file__).parent.parent / "log-cache-hit.py"),
         "--key", "k", "--layer", "L1"],
        check=True
    )

    newer_state = json.loads(
        (tmp_path / ".claude/features/newer/state.json").read_text()
    )
    older_state = json.loads(
        (tmp_path / ".claude/features/older/state.json").read_text()
    )
    assert len(newer_state["cache_hits"]) == 1
    assert len(older_state["cache_hits"]) == 0
```

- [ ] **Step T2.2: Run test — expect FAIL (helper doesn't exist)**

```bash
mkdir -p scripts/tests
python3 -m pytest scripts/tests/test_log_cache_hit.py -v
```

Expected: FAIL with `ModuleNotFoundError` or `FileNotFoundError`.

- [ ] **Step T2.3: Implement scripts/log-cache-hit.py**

Create `scripts/log-cache-hit.py`:

```python
#!/usr/bin/env python3
"""Append a cache-hit entry to the active feature's state.json.

Active feature = most-recently-modified state.json under .claude/features/*/.
Fail-soft: exits 0 even on error, so a logging failure cannot break the
underlying cache read.

Usage:
    python3 scripts/log-cache-hit.py --key <key> --layer <L1|L2|L3>

Wired in (post-T3) by every cache read call site enumerated in
docs/architecture/cache-read-paths.md.
"""
import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path


def find_active_feature() -> Path | None:
    """Return path to the most-recently-modified state.json, or None."""
    features_dir = Path(".claude/features")
    if not features_dir.exists():
        return None
    candidates = list(features_dir.glob("*/state.json"))
    if not candidates:
        return None
    return max(candidates, key=lambda p: p.stat().st_mtime)


def append_cache_hit(state_path: Path, key: str, layer: str) -> None:
    state = json.loads(state_path.read_text())
    state.setdefault("cache_hits", [])
    state["cache_hits"].append({
        "key": key,
        "layer": layer,
        "ts": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    })
    state_path.write_text(json.dumps(state, indent=2) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--key", required=True)
    parser.add_argument("--layer", required=True, choices=["L1", "L2", "L3"])
    args = parser.parse_args()

    try:
        active = find_active_feature()
        if active is None:
            return 0  # fail-soft: no active feature
        append_cache_hit(active, args.key, args.layer)
    except Exception:
        # Fail-soft: never break cache reads on logging failure
        return 0
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step T2.4: Make executable, run test — expect PASS**

```bash
chmod +x scripts/log-cache-hit.py
python3 -m pytest scripts/tests/test_log_cache_hit.py -v
```

Expected: 3 tests PASS.

- [ ] **Step T2.5: Commit T2**

```bash
git add scripts/log-cache-hit.py scripts/tests/test_log_cache_hit.py
git commit -m "$(cat <<'EOF'
feat(framework-v7-7): log-cache-hit.py helper (T2 / PR-1)

T2: shared helper for cache-read-site instrumentation. Appends
{key, layer, ts} to active feature's state.json cache_hits[].
Fail-soft on errors so logging cannot break cache reads.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task T3: Pre-commit hook CACHE_HITS_EMPTY_POST_V6

**Files:**
- Modify: `scripts/check-state-schema.py`

- [ ] **Step T3.1: Inspect existing check-state-schema.py structure**

```bash
head -80 scripts/check-state-schema.py
```

Note the existing check codes (`SCHEMA_DRIFT`, `PR_NUMBER_UNRESOLVED`, `PHASE_TRANSITION_NO_LOG`, `PHASE_TRANSITION_NO_TIMING`) and the function-per-code pattern. Add the new check following the same pattern.

- [ ] **Step T3.2: Write failing test for the new check**

Append to `scripts/tests/test_check_state_schema.py` (or create if absent):

```python
def test_cache_hits_empty_post_v6_blocks_when_complete():
    """current_phase=complete + post-v6 + cache_hits=[] → REJECT."""
    state = {
        "feature_name": "test-feature",
        "current_phase": "complete",
        "created_at": "2026-04-20T00:00:00Z",  # post-v6 ship date
        "cache_hits": []
    }
    findings = check_cache_hits_empty_post_v6(state)
    assert any(f["code"] == "CACHE_HITS_EMPTY_POST_V6" for f in findings)


def test_cache_hits_empty_post_v6_passes_pre_v6():
    """Pre-v6 features are exempt — empty cache_hits OK."""
    state = {
        "feature_name": "old",
        "current_phase": "complete",
        "created_at": "2026-04-15T00:00:00Z",  # pre-v6
        "cache_hits": []
    }
    findings = check_cache_hits_empty_post_v6(state)
    assert findings == []


def test_cache_hits_empty_post_v6_passes_non_complete():
    """Post-v6 but not complete → empty array still allowed."""
    state = {
        "feature_name": "wip",
        "current_phase": "implementation",
        "created_at": "2026-04-20T00:00:00Z",
        "cache_hits": []
    }
    findings = check_cache_hits_empty_post_v6(state)
    assert findings == []
```

- [ ] **Step T3.3: Run test — expect FAIL**

```bash
python3 -m pytest scripts/tests/test_check_state_schema.py::test_cache_hits_empty_post_v6_blocks_when_complete -v
```

Expected: FAIL with `NameError: name 'check_cache_hits_empty_post_v6' is not defined`.

- [ ] **Step T3.4: Implement the check function in check-state-schema.py**

Add to `scripts/check-state-schema.py`:

```python
V6_SHIP_DATE = "2026-04-16"


def check_cache_hits_empty_post_v6(state: dict) -> list[dict]:
    """Reject current_phase: complete when post-v6 feature has empty cache_hits[].

    Closes the writer-path adoption gap from issue #140. The v7.6 framework
    only checked for KEY presence; v7.7 checks for non-empty content on
    post-v6 features at completion.
    """
    findings = []
    created = state.get("created_at", "")
    current_phase = state.get("current_phase", "")
    cache_hits = state.get("cache_hits", None)

    # Only fire when post-v6 AND current_phase=complete
    if not created or created < V6_SHIP_DATE:
        return findings
    if current_phase != "complete":
        return findings
    if cache_hits is None or len(cache_hits) > 0:
        return findings

    findings.append({
        "code": "CACHE_HITS_EMPTY_POST_V6",
        "feature": state.get("feature_name", "unknown"),
        "message": (
            "Post-v6 feature reached current_phase=complete with empty "
            "cache_hits[]. M1 instrumentation should populate this on every "
            "cache read; an empty array at completion means either the "
            "instrumentation is missing for this feature's cache calls, or "
            "the cache was never read. See "
            "scripts/log-cache-hit.py and docs/architecture/cache-read-paths.md."
        ),
        "severity": "failure"
    })
    return findings
```

Then in the `--staged` driver, call `check_cache_hits_empty_post_v6(state)` for each staged state.json and add findings to the aggregate.

- [ ] **Step T3.5: Run tests — expect 3 PASS**

```bash
python3 -m pytest scripts/tests/test_check_state_schema.py -v -k cache_hits_empty
```

Expected: 3 PASS.

- [ ] **Step T3.6: Test against the live tree (no commits should fail)**

```bash
python3 scripts/check-state-schema.py
```

Expected: no `CACHE_HITS_EMPTY_POST_V6` findings (no current `current_phase: complete` features have empty cache_hits — auth-polish-v2 is in `prd` phase).

- [ ] **Step T3.7: Commit T3**

```bash
git add scripts/check-state-schema.py scripts/tests/test_check_state_schema.py
git commit -m "$(cat <<'EOF'
feat(framework-v7-7): CACHE_HITS_EMPTY_POST_V6 hook (T3 / PR-1)

T3: write-time gate rejecting current_phase=complete when a post-v6
feature has empty cache_hits[]. Pairs with T2 helper that auto-populates
the array at every cache read site.

Test coverage: 3 unit tests (post-v6+complete blocks; pre-v6 exempt;
non-complete passes).

Closes the v6.0 writer-path adoption gap (issue #140 will close at PR-1
merge after T4 validation).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task T4: Wire helper into cache read sites + validate on auth-polish-v2

**Files:**
- Modify: every cache read site identified in T1 (1-5 files expected)

- [ ] **Step T4.1: For each cache read site from T1, add a single helper invocation**

Pattern (sync call after the cache read returns a hit):

```python
# After: result = cache.get(key)
# Add:
if result is not None:
    subprocess.run(
        ["python3", "scripts/log-cache-hit.py", "--key", key, "--layer", layer],
        check=False, capture_output=True
    )
```

For shell-based sites, equivalent:

```bash
python3 scripts/log-cache-hit.py --key "$key" --layer "$layer" 2>/dev/null || true
```

- [ ] **Step T4.2: Verify auth-polish-v2 gets cache_hits populated by exercising one cache-reading workflow**

```bash
# Trigger a known cache read (e.g., loading the pm-workflow skill)
# Approach: simulate any operation that reads a cached skill or shared resource
# Then inspect:
cat .claude/features/auth-polish-v2/state.json | python3 -m json.tool | grep -A5 cache_hits
```

Expected: `cache_hits` array now contains ≥ 1 entry.

If empty: T1's audit missed a call site OR auth-polish-v2 isn't being recognized as the active feature. Re-check `find_active_feature()` mtime ordering against the live tree.

- [ ] **Step T4.3: Performance check — kill criterion 3**

Time a cache read with vs without instrumentation:

```bash
time python3 scripts/log-cache-hit.py --key bench --layer L1
```

Expected: < 100ms per call (kill criterion 3 threshold). If > 100ms, **STOP** — escalate to async write or in-memory batch.

- [ ] **Step T4.4: Commit T4**

```bash
git add <call-site files>
git commit -m "$(cat <<'EOF'
feat(framework-v7-7): wire log-cache-hit.py into N read sites (T4 / PR-1)

T4: every cache read site enumerated in docs/architecture/cache-read-paths.md
now invokes scripts/log-cache-hit.py as a fail-soft synchronous append.
Validated on auth-polish-v2 (now has N entries; pre-T4 had 0).

Performance: <T4.3 measurement> per call, well under the 100ms kill threshold.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task T5: Close GitHub issue #140

- [ ] **Step T5.1: Open PR-1 and reference issue #140**

```bash
git push -u origin feature/framework-v7-7-validity-closure
gh pr create --title "v7.7 PR-1: cache_hits writer-path (#140)" --body "$(cat <<'EOF'
## Summary
- Closes the post-v6 cache_hits writer-path adoption gap (issue #140)
- Adds shared logger `scripts/log-cache-hit.py` (T2)
- Adds pre-commit hook `CACHE_HITS_EMPTY_POST_V6` (T3)
- Wires logger into N cache read sites (T4)
- Validated on auth-polish-v2 (cache_hits 0 → N entries)

Closes #140

Spec: docs/superpowers/specs/2026-04-27-framework-v7-7-validity-closure-design.md
Plan: docs/superpowers/plans/2026-04-27-framework-v7-7-validity-closure.md (T1–T5)

## Test plan
- [x] Unit tests: 3 passing for log-cache-hit helper, 3 passing for hook
- [x] Live: auth-polish-v2 cache_hits populated by real workflow
- [x] Performance: <T4.3 measurement> per call, under 100ms kill threshold

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step T5.2: After PR-1 merges, close issue #140 with a backlink**

```bash
gh issue close 140 --comment "Closed by PR-1 of v7.7 Validity Closure (commit <merge sha>). Cache_hits writer-path now mechanically gated by CACHE_HITS_EMPTY_POST_V6 pre-commit hook. See docs/case-studies/framework-v7-7-validity-closure-case-study.md."
```

- [ ] **Step T5.3: Append PR-1 entry to case-study Section 2**

```markdown
### YYYY-MM-DD HH:MM UTC — PR-1 merged: cache_hits writer-path
- **Trigger:** PR-1 merged at <sha>; issue #140 closed
- **What changed:** scripts/log-cache-hit.py created; check-state-schema.py adds CACHE_HITS_EMPTY_POST_V6; N cache read sites instrumented
- **Ledger delta:** post-v6 cache_hits adoption 33.3% → expected 100% on next snapshot (pending real cache reads)
- **Surprises / discoveries:** <fill in from T1.5/T4.2/T4.3>
- **Tier tags applied:** T1 (cache_hits delta will be measured by next make measurement-adoption); T2 (predicted 100% adoption pending real reads).
```

```bash
git add docs/case-studies/framework-v7-7-validity-closure-case-study.md
git commit -m "docs(framework-v7-7): journal — PR-1 cache_hits writer-path

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

### Task T6: cu_v2 schema validator

**Files:**
- Create: `scripts/validate-cu-v2.py`
- Test: `scripts/tests/test_validate_cu_v2.py`

- [ ] **Step T6.1: Write failing test**

Create `scripts/tests/test_validate_cu_v2.py`:

```python
"""Tests for scripts/validate-cu-v2.py.

The validator checks state.json's cu_v2 field for:
- presence of expected factors (complexity, blast_radius, novelty, verification_difficulty)
- each factor in [0, 1]
- total field within tolerance of sum(factors)
- tier_class field present and matches total
"""
import json
import subprocess
from pathlib import Path

VALIDATOR = Path(__file__).parent.parent / "validate-cu-v2.py"


def run_validator(state_dict, tmp_path):
    state_path = tmp_path / "state.json"
    state_path.write_text(json.dumps(state_dict))
    return subprocess.run(
        ["python3", str(VALIDATOR), "--state", str(state_path)],
        capture_output=True, text=True
    )


def test_valid_cu_v2_passes(tmp_path):
    state = {
        "cu_v2": {
            "factors": {
                "complexity": 0.5,
                "blast_radius": 0.5,
                "novelty": 0.5,
                "verification_difficulty": 0.5
            },
            "total": 2.0,
            "tier_class": "B_medium"
        }
    }
    result = run_validator(state, tmp_path)
    assert result.returncode == 0


def test_missing_factor_fails(tmp_path):
    state = {
        "cu_v2": {
            "factors": {
                "complexity": 0.5,
                "blast_radius": 0.5,
                "novelty": 0.5
                # verification_difficulty missing
            },
            "total": 1.5,
            "tier_class": "C_low"
        }
    }
    result = run_validator(state, tmp_path)
    assert result.returncode != 0
    assert "CU_V2_INVALID" in result.stdout
    assert "verification_difficulty" in result.stdout


def test_factor_out_of_range_fails(tmp_path):
    state = {
        "cu_v2": {
            "factors": {
                "complexity": 1.5,  # > 1
                "blast_radius": 0.5,
                "novelty": 0.5,
                "verification_difficulty": 0.5
            },
            "total": 3.0,
            "tier_class": "A_high"
        }
    }
    result = run_validator(state, tmp_path)
    assert result.returncode != 0
    assert "CU_V2_INVALID" in result.stdout


def test_total_mismatch_fails(tmp_path):
    state = {
        "cu_v2": {
            "factors": {
                "complexity": 0.5, "blast_radius": 0.5,
                "novelty": 0.5, "verification_difficulty": 0.5
            },
            "total": 99.0,  # should be 2.0
            "tier_class": "B_medium"
        }
    }
    result = run_validator(state, tmp_path)
    assert result.returncode != 0
    assert "CU_V2_INVALID" in result.stdout


def test_state_without_cu_v2_passes(tmp_path):
    """Pre-v6 features without cu_v2 are exempt at validate time."""
    state = {"feature_name": "pre-v6"}
    result = run_validator(state, tmp_path)
    assert result.returncode == 0
```

- [ ] **Step T6.2: Run test — expect FAIL**

```bash
python3 -m pytest scripts/tests/test_validate_cu_v2.py -v
```

Expected: FAIL (script doesn't exist).

- [ ] **Step T6.3: Implement scripts/validate-cu-v2.py**

```python
#!/usr/bin/env python3
"""Validate cu_v2 schema in a state.json file.

Checks:
- factors dict has all 4 expected keys
- each factor is a number in [0, 1]
- total field ≈ sum(factors.values()) within tolerance 0.01
- tier_class is one of A_high, B_medium, C_low

Exits 0 on valid (or absent — pre-v6 features exempt). Exits 1 with
CU_V2_INVALID findings on stdout when invalid.

Wired into:
- .githooks/pre-commit (T7)
- scripts/integrity-check.py (T7) as cycle-time check code CU_V2_INVALID
"""
import argparse
import json
import sys
from pathlib import Path

EXPECTED_FACTORS = {"complexity", "blast_radius", "novelty", "verification_difficulty"}
TIER_CLASSES = {"A_high", "B_medium", "C_low"}
TOTAL_TOLERANCE = 0.01


def validate(state: dict) -> list[str]:
    errors = []
    cu = state.get("cu_v2")
    if cu is None:
        return errors  # pre-v6 exempt

    factors = cu.get("factors")
    if not isinstance(factors, dict):
        errors.append("CU_V2_INVALID: factors missing or not a dict")
        return errors

    missing = EXPECTED_FACTORS - set(factors.keys())
    if missing:
        errors.append(f"CU_V2_INVALID: missing factors: {sorted(missing)}")

    for k, v in factors.items():
        if not isinstance(v, (int, float)):
            errors.append(f"CU_V2_INVALID: factor {k!r} is not numeric: {v!r}")
            continue
        if not (0.0 <= v <= 1.0):
            errors.append(f"CU_V2_INVALID: factor {k!r}={v} out of [0,1]")

    total = cu.get("total")
    if total is None:
        errors.append("CU_V2_INVALID: total field missing")
    elif not isinstance(total, (int, float)):
        errors.append(f"CU_V2_INVALID: total is not numeric: {total!r}")
    else:
        expected_total = sum(v for v in factors.values() if isinstance(v, (int, float)))
        if abs(total - expected_total) > TOTAL_TOLERANCE:
            errors.append(
                f"CU_V2_INVALID: total {total} ≠ sum(factors) {expected_total} "
                f"(tolerance {TOTAL_TOLERANCE})"
            )

    tier = cu.get("tier_class")
    if tier not in TIER_CLASSES:
        errors.append(f"CU_V2_INVALID: tier_class {tier!r} not in {sorted(TIER_CLASSES)}")

    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--state", required=True, help="path to state.json")
    args = parser.parse_args()

    state_path = Path(args.state)
    if not state_path.exists():
        print(f"CU_V2_INVALID: state file not found: {args.state}", file=sys.stderr)
        return 1
    state = json.loads(state_path.read_text())
    errors = validate(state)
    if errors:
        for e in errors:
            print(e)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step T6.4: Run tests — expect 5 PASS**

```bash
chmod +x scripts/validate-cu-v2.py
python3 -m pytest scripts/tests/test_validate_cu_v2.py -v
```

Expected: 5 PASS.

- [ ] **Step T6.5: Validate against live tree**

```bash
for f in .claude/features/*/state.json; do
  python3 scripts/validate-cu-v2.py --state "$f" || echo "FAIL: $f"
done
```

Expected: any features with cu_v2 fields pass; pre-v6 features without cu_v2 silently pass; if any fail, those state.jsons need backfill (handled in M2 T15) before PR-2 lands.

- [ ] **Step T6.6: Commit T6**

```bash
git add scripts/validate-cu-v2.py scripts/tests/test_validate_cu_v2.py
git commit -m "$(cat <<'EOF'
feat(framework-v7-7): validate-cu-v2.py schema validator (T6 / PR-2)

T6: schema validator for cu_v2 field. Checks factor presence + range
[0,1] + total within tolerance + tier_class enum. Pre-v6 features exempt
(no cu_v2 field expected).

Test coverage: 5 unit tests covering valid/missing/out-of-range/
mismatched-total/pre-v6-exempt paths.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task T7: Wire CU_V2_INVALID into pre-commit + integrity-check

**Files:**
- Modify: `scripts/check-state-schema.py`
- Modify: `scripts/integrity-check.py`

- [ ] **Step T7.1: Add CU_V2_INVALID call to check-state-schema.py --staged driver**

Edit `scripts/check-state-schema.py` so the staged-state-json driver imports `validate` from validate_cu_v2 (or shells out) for each staged state.json and aggregates the findings.

Implementation hint — invoke as subprocess to keep validate-cu-v2.py independently runnable:

```python
import subprocess

def check_cu_v2_via_validator(state_path: Path) -> list[dict]:
    result = subprocess.run(
        ["python3", "scripts/validate-cu-v2.py", "--state", str(state_path)],
        capture_output=True, text=True
    )
    if result.returncode == 0:
        return []
    return [
        {"code": "CU_V2_INVALID", "feature": state_path.parent.name, "message": line}
        for line in result.stdout.strip().split("\n") if line
    ]
```

- [ ] **Step T7.2: Add CU_V2_INVALID to integrity-check.py cycle-time check codes**

Edit `scripts/integrity-check.py`. The 12 existing codes become 13 — find the codes constant/list and add `"CU_V2_INVALID"`. Iterate every state.json in `.claude/features/*/`, invoke validator, aggregate findings.

- [ ] **Step T7.3: Test pre-commit by intentionally breaking auth-polish-v2's cu_v2**

```bash
# Temporarily break cu_v2 (do NOT commit)
python3 -c "
import json
p = '.claude/features/auth-polish-v2/state.json'
s = json.load(open(p))
s['cu_v2']['factors']['complexity'] = 99.0
open(p, 'w').write(json.dumps(s, indent=2) + '\n')
"

git add .claude/features/auth-polish-v2/state.json
git commit -m "test: cu_v2 hook" 2>&1 | head -10

# Expected: pre-commit REJECTS with CU_V2_INVALID
# Restore:
git restore --staged .claude/features/auth-polish-v2/state.json
git checkout -- .claude/features/auth-polish-v2/state.json
```

Expected: commit blocked with `CU_V2_INVALID: factor 'complexity'=99.0 out of [0,1]`.

- [ ] **Step T7.4: Run integrity-check across the live tree**

```bash
make integrity-check
```

Expected: 13 codes total; no CU_V2_INVALID findings (live tree is valid post-T6.5).

- [ ] **Step T7.5: Commit T7**

```bash
git add scripts/check-state-schema.py scripts/integrity-check.py
git commit -m "$(cat <<'EOF'
feat(framework-v7-7): wire CU_V2_INVALID into pre-commit + cycle (T7 / PR-2)

T7: integrity-check.py code count 12 → 13. Pre-commit hook delegates to
scripts/validate-cu-v2.py for each staged state.json.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task T8: Update integrity-check 12-code documentation → 13

**Files:**
- Modify: `CLAUDE.md`
- Modify: `.claude/integrity/README.md`

- [ ] **Step T8.1: Update CLAUDE.md cycle-time check-codes list**

Find the line "12 cycle-time check codes:" in CLAUDE.md and add `CU_V2_INVALID` to the list. Update count from "12" to "13".

- [ ] **Step T8.2: Update .claude/integrity/README.md**

Add a section documenting CU_V2_INVALID with the same structure used for SCHEMA_DRIFT and PR_NUMBER_UNRESOLVED.

- [ ] **Step T8.3: Commit T8 + open PR-2**

```bash
git add CLAUDE.md .claude/integrity/README.md
git commit -m "$(cat <<'EOF'
docs(framework-v7-7): integrity codes 12→13 with CU_V2_INVALID (T8 / PR-2)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"

git push origin feature/framework-v7-7-validity-closure
gh pr create --title "v7.7 PR-2: cu_v2 schema validator" --body "$(cat <<'EOF'
## Summary
- New script `scripts/validate-cu-v2.py` (T6)
- Wired into pre-commit + cycle-time integrity-check (T7)
- Integrity-check code count 12 → 13 (T8)

Closes scope item A2 from v7.7 spec.

## Test plan
- [x] 5 unit tests covering valid/invalid paths
- [x] Pre-commit blocks tampered cu_v2 (verified manually in T7.3)
- [x] make integrity-check passes against live tree

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step T8.4: After PR-2 merges, append journal entry**

```markdown
### YYYY-MM-DD HH:MM UTC — PR-2 merged: cu_v2 schema validator
- **Trigger:** PR-2 merged at <sha>
- **What changed:** scripts/validate-cu-v2.py added; check-state-schema.py + integrity-check.py wire CU_V2_INVALID; CLAUDE.md/integrity README updated to reflect 13 codes
- **Ledger delta:** none (cu_v2 already populated on the post-v6 features that have it; this hook prevents future schema drift)
- **Surprises / discoveries:** <fill in any unexpected findings from T6.5 live scan>
- **Tier tags applied:** T1 (validator output is mechanically determined).
```

**M1 done. Proceed to M2.**

---

## M2 — Linkage & Documentation-Debt Gates (PR-3, PR-4, PR-5)

**Goal:** Push state↔case-study linkage from 95.5% to 100% with a hook (PR-3); add doc-debt field gates and bulk-backfill 32 case studies (PR-4); backfill timing.phases for 3 in-flight features that lack it (PR-5).

### Task T9: Resolve app-store-assets case-study linkage

- [ ] **Step T9.1: Decide — write case study OR exempt tag?**

App-store-assets is App Store screenshot/metadata work. ASO content rarely warrants a deep case study, so exempt tag is appropriate.

- [ ] **Step T9.2: Add case_study_type exempt tag to app-store-assets state.json**

```json
{
  "...existing...",
  "case_study_type": "no_case_study_required",
  "case_study_exempt_reason": "App Store assets (screenshots, ASO copy, metadata) are operational artifacts; no case-study narrative warranted. Approved 2026-04-27 during v7.7 M2 T9."
}
```

- [ ] **Step T9.3: Commit T9**

```bash
git add .claude/features/app-store-assets/state.json
git commit -m "$(cat <<'EOF'
chore(app-store-assets): mark exempt from case-study requirement (T9 / PR-3)

T9: applies case_study_type: no_case_study_required exempt tag with
rationale. Closes one of 2 missing-linkage features.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task T10: Resolve onboarding-v2-retroactive case-study linkage

- [ ] **Step T10.1: Decide — write case study OR exempt tag?**

This is a retroactive v2-subdirectory refactor of an already-shipped feature. Per CLAUDE.md "Backward compatibility note": it exists "mostly to validate that the rule scales to a feature with multiple screens." A short case study documenting the multi-screen v2-rule application IS warranted. Stub the case study for now; resume-time work will fill it.

- [ ] **Step T10.2: Create stub case-study file**

Create `docs/case-studies/onboarding-v2-retroactive-case-study.md`:

```markdown
---
title: Onboarding v2 Retroactive — Multi-Screen v2-Rule Validation
date_written: <to-be-filled-on-resume>
work_type: Enhancement
dispatch_pattern: <to-be-filled>
success_metrics:
  primary: "Validate v2-subdirectory rule scales to a multi-screen feature without regressions"
kill_criteria:
  - "Build target swap fails for any of the multi-screen v2 files"
  - "v1 historical comments fail to render in IDE for any swapped file"
status: stub_pending_resume
---

# Onboarding v2 Retroactive (stub)

> This is a stub created during v7.7 M2 T10 to satisfy the linkage gate.
> The actual case-study content will be written when this feature resumes
> after v7.7 closure (its `paused.resume_signal` fires). At that point this
> file will be filled in with the multi-screen v2-rule application narrative.
```

- [ ] **Step T10.3: Update state.json to point at stub**

```json
{
  "...existing...",
  "case_study": "docs/case-studies/onboarding-v2-retroactive-case-study.md"
}
```

- [ ] **Step T10.4: Commit T10**

```bash
git add docs/case-studies/onboarding-v2-retroactive-case-study.md \
  .claude/features/onboarding-v2-retroactive/state.json
git commit -m "$(cat <<'EOF'
chore(onboarding-v2-retroactive): stub case study + state link (T10 / PR-3)

T10: creates stub case-study file with frontmatter (status: stub_pending_resume)
and links state.json. Closes the second missing-linkage feature. Stub is
filled in when feature resumes post-v7.7.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task T11: Pre-commit hook STATE_NO_CASE_STUDY_LINK

**Files:**
- Modify: `scripts/check-state-schema.py`

- [ ] **Step T11.1: Write failing test**

Append to `scripts/tests/test_check_state_schema.py`:

```python
def test_state_no_case_study_link_blocks_when_complete():
    """current_phase=complete + missing case_study + missing exempt tag → REJECT."""
    state = {
        "feature_name": "test",
        "current_phase": "complete"
    }
    findings = check_state_no_case_study_link(state)
    assert any(f["code"] == "STATE_NO_CASE_STUDY_LINK" for f in findings)


def test_state_no_case_study_link_passes_with_link():
    state = {
        "feature_name": "test",
        "current_phase": "complete",
        "case_study": "docs/case-studies/x.md"
    }
    findings = check_state_no_case_study_link(state)
    assert findings == []


def test_state_no_case_study_link_passes_with_exempt():
    state = {
        "feature_name": "test",
        "current_phase": "complete",
        "case_study_type": "no_case_study_required"
    }
    findings = check_state_no_case_study_link(state)
    assert findings == []


def test_state_no_case_study_link_passes_pre_complete():
    state = {
        "feature_name": "test",
        "current_phase": "implementation"
    }
    findings = check_state_no_case_study_link(state)
    assert findings == []
```

- [ ] **Step T11.2: Run test — expect FAIL**

```bash
python3 -m pytest scripts/tests/test_check_state_schema.py -k state_no_case_study -v
```

- [ ] **Step T11.3: Implement check_state_no_case_study_link in check-state-schema.py**

```python
EXEMPT_TYPES = {"no_case_study_required", "pre_pm_workflow_backfill", "roundup"}


def check_state_no_case_study_link(state: dict) -> list[dict]:
    """Reject current_phase=complete without case_study link or exempt tag."""
    findings = []
    if state.get("current_phase") != "complete":
        return findings
    has_link = bool(state.get("case_study"))
    is_exempt = state.get("case_study_type") in EXEMPT_TYPES
    if has_link or is_exempt:
        return findings
    findings.append({
        "code": "STATE_NO_CASE_STUDY_LINK",
        "feature": state.get("feature_name", "unknown"),
        "message": (
            "Feature reached current_phase=complete without case_study link "
            "or case_study_type exempt tag. Add a case_study field pointing "
            "to docs/case-studies/<feature>-case-study.md OR add "
            "case_study_type: 'no_case_study_required' with case_study_exempt_reason."
        ),
        "severity": "failure"
    })
    return findings
```

Wire into `--staged` driver alongside the cache_hits/cu_v2 checks.

- [ ] **Step T11.4: Run tests — expect 4 PASS**

```bash
python3 -m pytest scripts/tests/test_check_state_schema.py -k state_no_case_study -v
```

- [ ] **Step T11.5: Verify live tree — should be 100% linked now**

```bash
python3 scripts/check-state-schema.py
```

Expected: no STATE_NO_CASE_STUDY_LINK findings (T9 + T10 closed the 2 gaps).

- [ ] **Step T11.6: Commit T11 + open PR-3**

```bash
git add scripts/check-state-schema.py scripts/tests/test_check_state_schema.py
git commit -m "$(cat <<'EOF'
feat(framework-v7-7): STATE_NO_CASE_STUDY_LINK hook (T11 / PR-3)

T11: write-time gate rejecting current_phase=complete without case_study
link or exempt tag. Closes the linkage 95.5% → 100% gate (T9+T10
resolved the 2 outstanding cases).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"

git push origin feature/framework-v7-7-validity-closure
gh pr create --title "v7.7 PR-3: state↔case-study linkage gate" --body "$(cat <<'EOF'
## Summary
- T9: app-store-assets exempt-tagged
- T10: onboarding-v2-retroactive linked to stub case study
- T11: STATE_NO_CASE_STUDY_LINK pre-commit hook lands

Linkage: 95.5% → 100%. Closes A4.

## Test plan
- [x] 4 unit tests for the hook
- [x] Live tree passes check-state-schema.py
- [x] Bulk integrity-check shows 0 STATE_NO_CASE_STUDY_LINK findings

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

### Task T12: Pre-commit hook CASE_STUDY_MISSING_FIELDS

**Files:**
- Modify: `scripts/check-case-study-preflight.py`

- [ ] **Step T12.1: Inspect existing preflight check structure**

```bash
head -80 scripts/check-case-study-preflight.py
```

Note the existing checks (`BROKEN_PR_CITATION`, `CASE_STUDY_MISSING_TIER_TAGS`) and the staged-file pattern.

- [ ] **Step T12.2: Write failing test**

Create or append to `scripts/tests/test_check_case_study_preflight.py`:

```python
def test_case_study_missing_fields_blocks_post_cutoff(tmp_path):
    """Case study dated ≥ 2026-04-28 missing required fields → REJECT."""
    cs = tmp_path / "test-case-study.md"
    cs.write_text("""---
date_written: 2026-04-29
title: Test
---
# Test
""")
    findings = check_case_study_missing_fields(cs)
    codes = [f["code"] for f in findings]
    assert codes.count("CASE_STUDY_MISSING_FIELDS") == 1


def test_case_study_missing_fields_passes_pre_cutoff(tmp_path):
    """Pre-2026-04-28 case studies are exempt (forward-only rule)."""
    cs = tmp_path / "old.md"
    cs.write_text("""---
date_written: 2026-04-15
title: Old
---
""")
    findings = check_case_study_missing_fields(cs)
    assert findings == []


def test_case_study_missing_fields_passes_with_all_fields(tmp_path):
    cs = tmp_path / "complete.md"
    cs.write_text("""---
date_written: 2026-04-29
work_type: Feature
dispatch_pattern: serial
success_metrics:
  primary: "X to Y"
kill_criteria:
  - "Z"
title: Complete
---
""")
    findings = check_case_study_missing_fields(cs)
    assert findings == []
```

- [ ] **Step T12.3: Run test — expect FAIL**

- [ ] **Step T12.4: Implement check_case_study_missing_fields**

```python
import yaml  # may need: pip install PyYAML if not available; check existing imports first

CUTOFF_DATE = "2026-04-28"
REQUIRED_FIELDS = ["work_type", "success_metrics", "kill_criteria", "dispatch_pattern"]


def parse_frontmatter(path: Path) -> dict:
    """Parse YAML frontmatter from a markdown file. Returns {} if absent."""
    text = path.read_text()
    if not text.startswith("---\n"):
        return {}
    end = text.find("\n---\n", 4)
    if end < 0:
        return {}
    return yaml.safe_load(text[4:end]) or {}


def check_case_study_missing_fields(path: Path) -> list[dict]:
    fm = parse_frontmatter(path)
    date_written = str(fm.get("date_written", ""))
    if not date_written or date_written < CUTOFF_DATE:
        return []  # forward-only rule

    missing = [f for f in REQUIRED_FIELDS if f not in fm]
    if not missing:
        return []
    return [{
        "code": "CASE_STUDY_MISSING_FIELDS",
        "file": str(path),
        "message": (
            f"Case study dated {date_written} (≥ {CUTOFF_DATE}) missing "
            f"required frontmatter fields: {missing}. Add work_type "
            "(Feature/Enhancement/Fix/Chore), success_metrics, kill_criteria, "
            "and dispatch_pattern (serial/parallel/mixed)."
        ),
        "severity": "failure"
    }]
```

Wire into the `--staged` driver to scan staged case-study files.

- [ ] **Step T12.5: Run tests — expect 3 PASS**

- [ ] **Step T12.6: Commit T12**

```bash
git add scripts/check-case-study-preflight.py scripts/tests/test_check_case_study_preflight.py
git commit -m "$(cat <<'EOF'
feat(framework-v7-7): CASE_STUDY_MISSING_FIELDS hook (T12 / PR-4)

T12: write-time gate. Forward-only (≥2026-04-28). Reject case studies
missing work_type, success_metrics, kill_criteria, or dispatch_pattern.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task T13: Doc-debt backfill script

**Files:**
- Create: `scripts/backfill-case-study-fields.py`

- [ ] **Step T13.1: Write the backfill script**

```python
#!/usr/bin/env python3
"""Backfill missing frontmatter fields on existing case studies.

For each case study under docs/case-studies/, infers:
- work_type from filename pattern + linked PRD scope
- dispatch_pattern from PR-train heuristic (single PR → "serial";
  case study mentions parallel agents → "parallel"; otherwise "serial")
- success_metrics from PRD body regex match on "Primary Metric:" / "Target:"
- kill_criteria from PRD body regex match on "Kill Criteria:"

Where inference fails, emits TODO comments in frontmatter rather than
guessing. Caller reviews each file before committing.

Usage:
    python3 scripts/backfill-case-study-fields.py --dry-run     # preview
    python3 scripts/backfill-case-study-fields.py --apply       # write
    python3 scripts/backfill-case-study-fields.py --file <path> # one file
"""
import argparse
import re
from pathlib import Path
import yaml


# (full implementation — see plan body below)
```

Full implementation must include:
- `infer_work_type(case_study_path) -> str` — defaults to "Feature" unless filename matches "fix-", "chore-", "enhancement-" patterns
- `infer_dispatch_pattern(case_study_text) -> str` — "parallel" if regex match on `Agent\(.*subagent_type=` count > 1; else "serial"
- `infer_metrics_from_prd(prd_path) -> dict` — regex extracts on PRD body
- `apply_to_file(path, inferred, dry_run) -> bool` — writes only if dry_run=False; emits "TODO: review" markers when inference confidence is low

- [ ] **Step T13.2: Test on one case study (dry-run first)**

```bash
python3 scripts/backfill-case-study-fields.py --file docs/case-studies/audit-remediation-program-185-findings-case-study.md --dry-run
```

Expected: prints proposed frontmatter changes; no file modified.

- [ ] **Step T13.3: Apply to one case study and review the diff**

```bash
python3 scripts/backfill-case-study-fields.py --file docs/case-studies/audit-remediation-program-185-findings-case-study.md --apply
git diff docs/case-studies/audit-remediation-program-185-findings-case-study.md
```

Expected: frontmatter gains work_type, success_metrics, kill_criteria, dispatch_pattern. Any TODO markers reviewed manually.

- [ ] **Step T13.4: Commit T13 (script only, not yet bulk-applied)**

```bash
git add scripts/backfill-case-study-fields.py
git commit -m "$(cat <<'EOF'
feat(framework-v7-7): doc-debt backfill script (T13 / PR-4)

T13: backfill helper for missing frontmatter on existing case studies.
Inferences from filename, PRD body regex, agent-dispatch counts in case
study text. Emits TODO markers where inference is low-confidence.

Bulk application happens in T14 as a reviewable PR.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task T14: Bulk backfill for 32 case studies

- [ ] **Step T14.1: Run script in dry-run across all case studies**

```bash
python3 scripts/backfill-case-study-fields.py --dry-run > /tmp/backfill-preview.txt
wc -l /tmp/backfill-preview.txt
head -100 /tmp/backfill-preview.txt
```

- [ ] **Step T14.2: Apply to all 32 case studies**

```bash
python3 scripts/backfill-case-study-fields.py --apply
git status --short docs/case-studies/
```

- [ ] **Step T14.3: Review TODO markers**

```bash
grep -l "TODO: review" docs/case-studies/*.md
```

For each TODO marker, manually decide the correct value and remove the TODO. Track count of low-confidence files; if > 50% of case studies need manual review, **reconsider the inference heuristics** before proceeding.

- [ ] **Step T14.4: Verify integrity-check passes**

```bash
python3 scripts/integrity-check.py --findings-only | grep CASE_STUDY_MISSING_FIELDS
```

Expected: empty (no findings).

- [ ] **Step T14.5: Commit T14 + open PR-4**

```bash
git add docs/case-studies/
git commit -m "$(cat <<'EOF'
docs(framework-v7-7): bulk backfill case-study frontmatter fields (T14 / PR-4)

T14: applies scripts/backfill-case-study-fields.py to N case studies.
Adds work_type, success_metrics, kill_criteria, dispatch_pattern. Manual
review applied to <count> low-confidence files.

Closes A3 (doc-debt fields populated 4-61% → 100% on extant case studies).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"

git push origin feature/framework-v7-7-validity-closure
gh pr create --title "v7.7 PR-4: doc-debt field gates + bulk backfill" --body "$(cat <<'EOF'
## Summary
- T12: CASE_STUDY_MISSING_FIELDS hook (forward-only ≥2026-04-28)
- T13: backfill script
- T14: bulk-backfill applied to N case studies

Closes A3.

## Test plan
- [x] 3 unit tests for hook
- [x] Bulk backfill diff reviewed (per-file)
- [x] integrity-check shows 0 CASE_STUDY_MISSING_FIELDS findings

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

### Task T15: Active-feature timing backfill

**Files:**
- Modify: `.claude/features/push-notifications/state.json`
- Modify: `.claude/features/import-training-plan/state.json`
- Modify: `.claude/features/stats-v2/state.json`

- [ ] **Step T15.1: For each of 3 features, extract phase boundaries from git log**

```bash
for f in push-notifications import-training-plan stats-v2; do
  echo "=== $f ==="
  git log --reverse --format='%aI %s' -- ".claude/features/$f/" | head -20
done
```

Capture the earliest commit per phase as the phase's `started_at`, and the latest commit before the next phase as `ended_at`.

- [ ] **Step T15.2: Manually populate timing.phases on each state.json**

For each feature, edit state.json to add `timing.phases` based on git log:

```json
{
  "...existing...",
  "timing": {
    "phases": {
      "research": {"started_at": "<earliest research commit>", "ended_at": "<last research commit before tasks>"},
      "tasks": {"started_at": "...", "ended_at": "..."},
      "implementation": {"started_at": "...", "ended_at": "..."}
    }
  }
}
```

- [ ] **Step T15.3: Run measurement-adoption to confirm uplift**

```bash
make measurement-adoption | python3 -c "
import json
d = json.load(open('.claude/shared/measurement-adoption.json'))
print('per_phase_timing post_v6:', d['dimension_coverage']['per_phase_timing'])
"
```

Expected: per_phase_timing post_v6_present increases by 3 (was 6, now 9 of 11).

- [ ] **Step T15.4: Commit T15**

```bash
git add .claude/features/push-notifications/state.json \
  .claude/features/import-training-plan/state.json \
  .claude/features/stats-v2/state.json
git commit -m "$(cat <<'EOF'
chore(framework-v7-7): backfill timing.phases for 3 paused features (T15 / PR-5)

T15: extracts phase boundaries from git log timestamps and writes
timing.phases for push-notifications, import-training-plan, stats-v2.
Pre-T15: zero adoption on per_phase_timing for these 3. Post-T15:
all 3 contribute to per_phase_timing post-v6 ratio.

Closes A5.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task T16: Document v7.6 hook coverage that prevents future backfill

- [ ] **Step T16.1: Add note in CLAUDE.md "Data Integrity Framework" section**

After T0d's stub, add a note explaining that going forward, `PHASE_TRANSITION_NO_TIMING` (v7.6 hook) prevents this backfill scenario from recurring — any phase transition without timing fields is rejected at write-time.

- [ ] **Step T16.2: Commit T16 + open PR-5**

```bash
git add CLAUDE.md
git commit -m "$(cat <<'EOF'
docs(framework-v7-7): v7.6 hook coverage note for timing backfill (T16 / PR-5)

T16: documents that v7.6's PHASE_TRANSITION_NO_TIMING hook prevents the
backfill scenario T15 just resolved from recurring. Going forward, any
phase change without timing.phases.<phase>.{started_at,ended_at} is
rejected pre-commit.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"

git push origin feature/framework-v7-7-validity-closure
gh pr create --title "v7.7 PR-5: active-feature timing backfill" --body "$(cat <<'EOF'
## Summary
- T15: timing.phases backfilled for 3 paused features
- T16: doc note on v7.6 hook coverage preventing recurrence

Closes A5. per_phase_timing post-v6 ratio uplift: 66.7% → ~82%.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step T16.3: Append M2-complete entry to case study**

```markdown
### YYYY-MM-DD HH:MM UTC — M2 complete: linkage + doc-debt + active backfill
- **Trigger:** PR-3, PR-4, PR-5 all merged
- **What changed:** linkage gate live; doc-debt gate live; 32 case studies backfilled; 3 active features have timing.phases populated
- **Ledger delta:** state↔case-study linkage 95.5% → 100%; doc-debt fields populated → 100% on extant case studies; per_phase_timing post-v6 → ~82%
- **Surprises / discoveries:** <fill in>
- **Tier tags applied:** T1 for ledger numbers; T2 for predicted ongoing prevention via v7.6 PHASE_TRANSITION_NO_TIMING.
```

```bash
git add docs/case-studies/framework-v7-7-validity-closure-case-study.md
git commit -m "docs(framework-v7-7): journal — M2 complete

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

**M2 done. Proceed to M3 (or M4 in parallel — they're independent).**

---

## M3 — Tier-Tag Heuristic Checker (PR-6)

**Goal:** Ship the T1/T2/T3 tier-tag correctness checker as an advisory cycle-time check. Promote to a gate only if false-positive rate < 10% after 7 days.

### Task T17: Build scripts/validate-tier-tags.py

**Files:**
- Create: `scripts/validate-tier-tags.py`
- Test: `scripts/tests/test_validate_tier_tags.py`
- Modify: `Makefile` (new `validate-tier-tags` target)

- [ ] **Step T17.1: Write failing tests first**

Create `scripts/tests/test_validate_tier_tags.py`:

```python
"""Tests for scripts/validate-tier-tags.py.

The validator extracts quantitative claims from a case study and flags
T1-tagged claims that have no corresponding entry in the
measurement-adoption.json or documentation-debt.json ledgers.
"""
import json
import subprocess
from pathlib import Path

VALIDATOR = Path(__file__).parent.parent / "validate-tier-tags.py"


def run_on_text(text: str, tmp_path: Path, ledger: dict | None = None):
    cs = tmp_path / "case.md"
    cs.write_text(text)
    if ledger:
        (tmp_path / "ledger.json").write_text(json.dumps(ledger))
        ledger_arg = ["--ledger", str(tmp_path / "ledger.json")]
    else:
        ledger_arg = []
    return subprocess.run(
        ["python3", str(VALIDATOR), "--file", str(cs)] + ledger_arg,
        capture_output=True, text=True
    )


def test_valid_t1_claim_with_ledger_match_passes(tmp_path):
    text = """---
date_written: 2026-04-29
---
# Case
**T1**: post-v6 fully-adopted ratio is 22.2% per measurement-adoption ledger.
"""
    ledger = {"summary": {"fully_adopted_post_v6_percent": 22.2}}
    result = run_on_text(text, tmp_path, ledger)
    assert result.returncode == 0


def test_t1_claim_without_ledger_evidence_warns(tmp_path):
    text = """---
date_written: 2026-04-29
---
# Case
**T1**: cache_hits is at 999% — totally instrumented.
"""
    result = run_on_text(text, tmp_path)
    assert "TIER_TAG_LIKELY_INCORRECT" in result.stdout


def test_pre_cutoff_case_study_exempt(tmp_path):
    text = """---
date_written: 2026-04-15
---
# Case
**T1**: fake number 99% — instrumented.
"""
    result = run_on_text(text, tmp_path)
    # Pre-2026-04-21 (tier-tag rule introduction) → exempt
    assert result.returncode == 0


def test_t3_narrative_claim_passes(tmp_path):
    """T3-tagged claims aren't ledger-verified — pass through."""
    text = """---
date_written: 2026-04-29
---
# Case
**T3**: roughly 6.5x speedup based on team observation.
"""
    result = run_on_text(text, tmp_path)
    assert result.returncode == 0
    assert "TIER_TAG_LIKELY_INCORRECT" not in result.stdout
```

- [ ] **Step T17.2: Run tests — expect FAIL**

```bash
python3 -m pytest scripts/tests/test_validate_tier_tags.py -v
```

Expected: FAIL (script doesn't exist).

- [ ] **Step T17.3: Implement scripts/validate-tier-tags.py**

```python
#!/usr/bin/env python3
"""Tier-tag correctness heuristic checker.

For each T1-tagged quantitative claim in a case study, attempts to
cross-reference the value against the measurement-adoption.json or
documentation-debt.json ledgers. If the claim has no plausible ledger
match, flags TIER_TAG_LIKELY_INCORRECT (advisory for first 7 days post-
ship; promoted to failure if FP < 10%).

T2 and T3 claims pass through (T2 = declared, T3 = narrative — neither
requires ledger evidence).

Pre-2026-04-21 case studies are exempt (tier-tag convention introduced
on that date).

Usage:
    python3 scripts/validate-tier-tags.py --file <case-study.md>
    python3 scripts/validate-tier-tags.py --all  # scan all docs/case-studies/
"""
import argparse
import json
import re
import sys
from pathlib import Path

import yaml  # check existing scripts for yaml availability

CUTOFF_DATE = "2026-04-21"

# Match a T1/T2/T3 tag near a quantitative claim within the same paragraph.
# Patterns: "T1: 22%", "**T1**: 6.5x", "[T1]: 100ms"
TIER_CLAIM_RE = re.compile(
    r"\*?\*?\[?T(?P<tier>[123])\]?\*?\*?\s*[:.]?\s*"
    r"(?P<claim>[^.\n]*?(?P<number>\d+(?:\.\d+)?)\s*"
    r"(?P<unit>%|x|ms|s|min|hr|h|d|/(?:\d+))[^\n.]*)",
    re.IGNORECASE
)


def parse_frontmatter(path: Path) -> dict:
    text = path.read_text()
    if not text.startswith("---\n"):
        return {}
    end = text.find("\n---\n", 4)
    if end < 0:
        return {}
    return yaml.safe_load(text[4:end]) or {}


def load_ledger(path: Path | None) -> dict:
    if path is None or not path.exists():
        return {}
    return json.loads(path.read_text())


def numbers_in_ledger(ledger: dict) -> set[float]:
    """Recursively extract every numeric value in the ledger."""
    nums = set()
    def walk(obj):
        if isinstance(obj, (int, float)):
            nums.add(round(float(obj), 2))
        elif isinstance(obj, dict):
            for v in obj.values(): walk(v)
        elif isinstance(obj, list):
            for v in obj: walk(v)
    walk(ledger)
    return nums


def find_claims(text: str) -> list[dict]:
    claims = []
    for m in TIER_CLAIM_RE.finditer(text):
        tier = m.group("tier")
        try:
            value = float(m.group("number"))
        except ValueError:
            continue
        claims.append({
            "tier": tier,
            "value": value,
            "unit": m.group("unit"),
            "context": m.group("claim").strip()[:120]
        })
    return claims


def validate_file(path: Path, ledgers: list[dict]) -> list[str]:
    fm = parse_frontmatter(path)
    date_written = str(fm.get("date_written", ""))
    if not date_written or date_written < CUTOFF_DATE:
        return []  # exempt

    text = path.read_text()
    claims = find_claims(text)
    findings = []

    all_ledger_nums = set()
    for L in ledgers:
        all_ledger_nums |= numbers_in_ledger(L)

    for c in claims:
        if c["tier"] != "1":
            continue  # only check T1
        # Heuristic: T1 claim should be ≈ some ledger number within 5% relative tolerance
        rounded = round(c["value"], 2)
        match = any(
            abs(rounded - n) / max(abs(n), 1.0) < 0.05
            for n in all_ledger_nums
        )
        if not match:
            findings.append(
                f"TIER_TAG_LIKELY_INCORRECT: {path.name}: "
                f"T1 claim {c['value']}{c['unit']} has no ledger match. "
                f"Context: {c['context']!r}"
            )
    return findings


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--file")
    parser.add_argument("--all", action="store_true")
    parser.add_argument(
        "--ledger", action="append", default=[],
        help="Path to a ledger JSON (repeatable). "
             "Defaults: .claude/shared/measurement-adoption.json + documentation-debt.json"
    )
    args = parser.parse_args()

    ledger_paths = [Path(p) for p in args.ledger] or [
        Path(".claude/shared/measurement-adoption.json"),
        Path(".claude/shared/documentation-debt.json"),
    ]
    ledgers = [load_ledger(p) for p in ledger_paths]

    files: list[Path] = []
    if args.file:
        files = [Path(args.file)]
    elif args.all:
        files = sorted(Path("docs/case-studies").rglob("*.md"))
    else:
        parser.error("Must pass --file or --all")

    all_findings = []
    for f in files:
        all_findings.extend(validate_file(f, ledgers))

    for finding in all_findings:
        print(finding)

    # Advisory mode: exit 0 even on findings; gate via integrity-check
    return 0
```

- [ ] **Step T17.4: Run tests — expect 4 PASS**

```bash
chmod +x scripts/validate-tier-tags.py
python3 -m pytest scripts/tests/test_validate_tier_tags.py -v
```

Expected: 4 PASS.

- [ ] **Step T17.5: Add Makefile target**

Edit `Makefile`, add:

```makefile
.PHONY: validate-tier-tags
validate-tier-tags:
	@python3 scripts/validate-tier-tags.py --all
```

- [ ] **Step T17.6: Commit T17**

```bash
git add scripts/validate-tier-tags.py scripts/tests/test_validate_tier_tags.py Makefile
git commit -m "$(cat <<'EOF'
feat(framework-v7-7): tier-tag heuristic checker (T17 / PR-6)

T17: scripts/validate-tier-tags.py — extracts T1/T2/T3-tagged
quantitative claims, cross-references T1 claims against ledger numbers
within 5% relative tolerance. Pre-2026-04-21 case studies exempt.
Advisory at ship; promotion to gate decided after 7-day FP-rate review.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task T18: Wire as advisory in integrity-check.py

**Files:**
- Modify: `scripts/integrity-check.py`

- [ ] **Step T18.1: Add TIER_TAG_LIKELY_INCORRECT call**

Edit `scripts/integrity-check.py`. The existing 13 codes (post-T7) become 14 — but this code is **advisory severity**, not failure. Add:

```python
def check_tier_tags_advisory():
    """Run validate-tier-tags.py; emit findings as warnings (advisory)."""
    result = subprocess.run(
        ["python3", "scripts/validate-tier-tags.py", "--all"],
        capture_output=True, text=True
    )
    return [
        {
            "code": "TIER_TAG_LIKELY_INCORRECT",
            "severity": "advisory",
            "message": line
        }
        for line in result.stdout.strip().split("\n") if line
    ]
```

Wire into the main aggregator. Severity-aware reporting: advisory findings appear in output but do NOT cause non-zero exit until promoted (T20).

- [ ] **Step T18.2: Run integrity-check across the live tree**

```bash
make integrity-check
```

Expected: non-zero count of TIER_TAG_LIKELY_INCORRECT advisory findings (this is the baseline FP-rate measurement). Save count.

- [ ] **Step T18.3: Commit T18**

```bash
git add scripts/integrity-check.py
git commit -m "$(cat <<'EOF'
feat(framework-v7-7): wire tier-tag checker as advisory in integrity-check (T18 / PR-6)

T18: integrity-check now reports TIER_TAG_LIKELY_INCORRECT findings as
advisory severity. Does not cause non-zero exit. 14 total check codes
(13 gating + 1 advisory).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task T19: Run baseline FP-rate scan + document

**Files:**
- Create: `docs/case-studies/meta-analysis/tier-tag-checker-baseline.md`

- [ ] **Step T19.1: Run baseline scan and capture output**

```bash
python3 scripts/validate-tier-tags.py --all > /tmp/tier-tag-baseline.txt
wc -l /tmp/tier-tag-baseline.txt
```

- [ ] **Step T19.2: Manual FP review — sample 10 random findings**

```bash
shuf -n 10 /tmp/tier-tag-baseline.txt
```

For each, manually verify: is this claim actually mis-tagged, or is it a false positive (e.g., the regex matched an unrelated number near a T-tag)?

- [ ] **Step T19.3: Write the baseline document**

Create `docs/case-studies/meta-analysis/tier-tag-checker-baseline.md`:

```markdown
---
title: Tier-Tag Checker Baseline (v7.7 M3 T19)
date_written: 2026-04-29  # at PR-6 merge time
work_type: Documentation
dispatch_pattern: serial
success_metrics:
  primary: "False-positive rate < 10% on random sample"
kill_criteria:
  - "FP rate > 25% — ship as advisory permanently, do not promote"
status: baseline
---

# Tier-Tag Checker Baseline

> Captured 2026-04-29 by v7.7 M3 T19. Intent: measure false-positive rate
> on a random sample of 10 findings to decide whether
> TIER_TAG_LIKELY_INCORRECT graduates to a cycle-time gate (T20).

## Total findings (baseline)

`<N>` findings across `<M>` case studies. (From `make validate-tier-tags`.)

## Random sample (10)

<paste 10 findings + per-finding manual classification: TP / FP / Inconclusive>

## FP rate

`<count_FP> / 10 = <pct>%`

## Decision

- `< 10%`: schedule promotion to gate at T20 (+ 7 days)
- `10-25%`: iterate on heuristic; re-baseline before promoting
- `> 25%`: ship as advisory permanently (kill criterion 2 fires)

## Notes on inference quality

<discussion of patterns: which kinds of claims trip the regex falsely;
which kinds of T-tags the regex misses; suggested heuristic refinements>
```

- [ ] **Step T19.4: Commit T19**

```bash
git add docs/case-studies/meta-analysis/tier-tag-checker-baseline.md
git commit -m "$(cat <<'EOF'
docs(framework-v7-7): tier-tag checker FP-rate baseline (T19 / PR-6)

T19: random-10 sample classified as TP/FP/Inconclusive. FP rate <pct>%.
Decision recorded; T20 7-day review scheduled.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task T20: 7-day decision gate

- [ ] **Step T20.1: Open PR-6 and merge**

```bash
git push origin feature/framework-v7-7-validity-closure
gh pr create --title "v7.7 PR-6: tier-tag heuristic checker" --body "$(cat <<'EOF'
## Summary
- T17: scripts/validate-tier-tags.py
- T18: wired into integrity-check as advisory
- T19: FP-rate baseline scan documented (<pct>% on random 10)

Closes C1. Ships as advisory; promotion to gate decided +7 days (T20).

## Test plan
- [x] 4 unit tests
- [x] Live scan: <N> findings; FP rate <pct>%
- [x] integrity-check exits 0 (advisory does not gate)

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step T20.2: Schedule a /loop or /schedule agent for +7 days**

```
/schedule
  cron: "0 14 +7d"
  task: "Re-run validate-tier-tags --all, compute new FP-rate vs baseline.
         If FP < 10%, open PR promoting TIER_TAG_LIKELY_INCORRECT severity
         from advisory to failure in scripts/integrity-check.py. Append
         decision to v7.7 case-study journal. If FP > 25%, append
         kill-criterion-2-fired entry and leave as advisory."
```

- [ ] **Step T20.3: Append M3-complete entry to case study**

```markdown
### YYYY-MM-DD HH:MM UTC — M3 complete: tier-tag heuristic shipped (advisory)
- **Trigger:** PR-6 merged at <sha>
- **What changed:** validate-tier-tags.py + integrity-check.py advisory wiring; baseline doc
- **Ledger delta:** integrity-check codes 13 → 14 (1 advisory). No gating change yet.
- **Surprises / discoveries:** baseline FP rate = <pct>% — <"on track for promotion" / "needs heuristic refinement" / "kill criterion 2 fired">
- **Tier tags applied:** T1 (FP rate from random sample); T2 (decision threshold pre-registered).
```

```bash
git add docs/case-studies/framework-v7-7-validity-closure-case-study.md
git commit -m "docs(framework-v7-7): journal — M3 complete

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

**M3 done. M4 can start in parallel from this point — same feature branch but different repo (fitme-story).**

---

## M4 — Framework-Health Dashboard (PR-7, fitme-story repo)

**Goal:** Surface v7.7's outputs at `/control-room/framework` in fitme-story. Absorbs UCC T43–T54 entirely. The dashboard is the visualization layer for v7.7's gated dimensions, trend lines, and the human-action checklist.

**Repo:** `/Volumes/DevSSD/fitme-story` (separate from FitTracker2).

**Tech:** Next.js 15 App Router, server components for ledger reads, client components for interactive charts (Recharts). Tailwind for styling.

### Task T21: Adoption trend chart + page scaffold

**Files (in fitme-story repo):**
- Create: `app/control-room/framework/page.tsx`
- Create: `app/control-room/framework/loading.tsx`
- Create: `components/framework-health/AdoptionTrendChart.tsx`
- Create: `lib/framework-health/load-ledgers.ts`

- [ ] **Step T21.1: Switch to fitme-story repo and pull**

```bash
cd /Volumes/DevSSD/fitme-story
git checkout main
git pull origin main
git checkout -b feature/framework-v7-7-validity-closure
```

- [ ] **Step T21.2: Inspect existing /control-room structure**

```bash
ls app/control-room/ 2>/dev/null
cat app/control-room/page.tsx 2>/dev/null | head -50
ls components/ | head -20
```

- [ ] **Step T21.3: Create the data loader**

Create `lib/framework-health/load-ledgers.ts`:

```typescript
import { promises as fs } from "fs";
import path from "path";

const FITTRACKER_REPO = process.env.FITTRACKER_REPO_PATH ?? "/Volumes/DevSSD/FitTracker2";

export type AdoptionSnapshot = {
  date: string;
  generated_at: string;
  trigger: string;
  summary: {
    features_total: number;
    features_post_v6: number;
    features_pre_v6: number;
    fully_adopted: number;
    partial_adopted: number;
    zero_adopted: number;
    fully_adopted_post_v6: number;
    tier_1_1_status: string;
  };
  dimension_coverage: Record<string, {
    overall_present: number;
    overall_percent: number;
    post_v6_present: number;
    post_v6_percent: number;
  }>;
};

export type AdoptionHistory = {
  version: string;
  description: string;
  snapshots: AdoptionSnapshot[];
};

export async function loadAdoptionHistory(): Promise<AdoptionHistory> {
  const p = path.join(FITTRACKER_REPO, ".claude/shared/measurement-adoption-history.json");
  const raw = await fs.readFile(p, "utf-8");
  return JSON.parse(raw);
}

export async function loadCurrentAdoption(): Promise<AdoptionSnapshot> {
  const p = path.join(FITTRACKER_REPO, ".claude/shared/measurement-adoption.json");
  const raw = await fs.readFile(p, "utf-8");
  return JSON.parse(raw);
}

export type DocDebtSnapshot = {
  version: string;
  updated: string;
  summary: {
    case_studies_scanned: number;
    features_scanned: number;
    integrity_snapshot_files: number;
    integrity_cycle_snapshots: number;
    trend_ready: boolean;
    open_debt_items: number;
  };
  coverage: Record<string, {
    present: number;
    missing: number;
    percent: number;
  }>;
};

export async function loadDocDebt(): Promise<DocDebtSnapshot> {
  const p = path.join(FITTRACKER_REPO, ".claude/shared/documentation-debt.json");
  const raw = await fs.readFile(p, "utf-8");
  return JSON.parse(raw);
}
```

- [ ] **Step T21.4: Create the AdoptionTrendChart client component**

Create `components/framework-health/AdoptionTrendChart.tsx`:

```typescript
"use client";

import { LineChart, Line, XAxis, YAxis, Tooltip, Legend, ResponsiveContainer, CartesianGrid } from "recharts";

type Snapshot = {
  date: string;
  dimension_coverage: Record<string, { post_v6_percent: number }>;
};

export function AdoptionTrendChart({ snapshots }: { snapshots: Snapshot[] }) {
  const data = snapshots.map(s => ({
    date: s.date,
    timing_wall_time: s.dimension_coverage.timing_wall_time?.post_v6_percent ?? 0,
    per_phase_timing: s.dimension_coverage.per_phase_timing?.post_v6_percent ?? 0,
    cache_hits: s.dimension_coverage.cache_hits?.post_v6_percent ?? 0,
    cu_v2: s.dimension_coverage.cu_v2?.post_v6_percent ?? 0,
  }));

  return (
    <div className="rounded-lg border border-zinc-800 p-4">
      <h3 className="text-lg font-semibold mb-2">Tier 1.1 — Post-v6 Adoption Trend</h3>
      <p className="text-sm text-zinc-400 mb-4">
        Daily snapshots from <code>measurement-adoption-history.json</code>.
        Trend mode unlocks at 3 snapshots.
      </p>
      <ResponsiveContainer width="100%" height={320}>
        <LineChart data={data}>
          <CartesianGrid strokeDasharray="3 3" stroke="#27272a" />
          <XAxis dataKey="date" stroke="#a1a1aa" />
          <YAxis stroke="#a1a1aa" domain={[0, 100]} unit="%" />
          <Tooltip contentStyle={{ background: "#18181b", border: "1px solid #3f3f46" }} />
          <Legend />
          <Line type="monotone" dataKey="timing_wall_time" stroke="#3b82f6" name="wall_time" />
          <Line type="monotone" dataKey="per_phase_timing" stroke="#10b981" name="per_phase" />
          <Line type="monotone" dataKey="cache_hits" stroke="#f59e0b" name="cache_hits" />
          <Line type="monotone" dataKey="cu_v2" stroke="#a855f7" name="cu_v2" />
        </LineChart>
      </ResponsiveContainer>
    </div>
  );
}
```

- [ ] **Step T21.5: Create the page**

Create `app/control-room/framework/page.tsx`:

```typescript
import { loadAdoptionHistory, loadCurrentAdoption, loadDocDebt } from "@/lib/framework-health/load-ledgers";
import { AdoptionTrendChart } from "@/components/framework-health/AdoptionTrendChart";

export const dynamic = "force-dynamic";

export default async function FrameworkHealthPage() {
  const [history, current, docDebt] = await Promise.all([
    loadAdoptionHistory(),
    loadCurrentAdoption(),
    loadDocDebt(),
  ]);

  return (
    <main className="container mx-auto px-4 py-8 space-y-8">
      <header>
        <h1 className="text-3xl font-bold">Framework Health</h1>
        <p className="text-zinc-400 mt-2">
          Live readout of the v7.7 Validity Closure framework. Every number is
          labeled with its tier (T1 = instrumented, T2 = declared, T3 = narrative).
        </p>
      </header>

      <section>
        <AdoptionTrendChart snapshots={history.snapshots} />
      </section>

      {/* T22-T25 components mounted in subsequent tasks */}
    </main>
  );
}
```

- [ ] **Step T21.6: Create loading skeleton**

Create `app/control-room/framework/loading.tsx`:

```typescript
export default function Loading() {
  return (
    <main className="container mx-auto px-4 py-8 space-y-8">
      <div className="h-8 w-72 rounded bg-zinc-800 animate-pulse" />
      <div className="h-80 rounded-lg border border-zinc-800 bg-zinc-900/50 animate-pulse" />
    </main>
  );
}
```

- [ ] **Step T21.7: Verify recharts is installed**

```bash
grep -E '"recharts"' package.json || npm install recharts
```

- [ ] **Step T21.8: Run dev server and verify the page renders**

```bash
npm run dev
# In a browser: open http://localhost:3000/control-room/framework
# Verify the AdoptionTrendChart renders with the 2 snapshots from 2026-04-25 + 2026-04-27
```

Expected: chart shows 2 data points (date axis: 2026-04-25, 2026-04-27); 4 series (wall_time, per_phase, cache_hits, cu_v2); cache_hits trends from 28.6% → 33.3%.

- [ ] **Step T21.9: Commit T21**

```bash
git add app/control-room/framework/ components/framework-health/AdoptionTrendChart.tsx lib/framework-health/load-ledgers.ts
git commit -m "$(cat <<'EOF'
feat(framework-v7-7): adoption-trend chart + page scaffold (T21 / PR-7)

T21: /control-room/framework page with AdoptionTrendChart client
component. Reads measurement-adoption-history.json from FITTRACKER_REPO_PATH
env var (defaults to /Volumes/DevSSD/FitTracker2). Recharts line chart
visualizes post-v6 adoption per dimension over time.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task T22: DocDebtTrendChart

**Files:**
- Create: `components/framework-health/DocDebtTrendChart.tsx`

- [ ] **Step T22.1: Write the component**

Create `components/framework-health/DocDebtTrendChart.tsx`:

```typescript
"use client";

import { BarChart, Bar, XAxis, YAxis, Tooltip, Legend, ResponsiveContainer, CartesianGrid } from "recharts";

type Coverage = Record<string, { percent: number }>;

export function DocDebtTrendChart({ coverage, trendReady }: { coverage: Coverage; trendReady: boolean }) {
  const data = Object.entries(coverage).map(([field, { percent }]) => ({
    field,
    percent,
  }));

  return (
    <div className="rounded-lg border border-zinc-800 p-4">
      <h3 className="text-lg font-semibold mb-2">Tier 3.2 — Documentation Debt Coverage</h3>
      <p className="text-sm text-zinc-400 mb-4">
        From <code>documentation-debt.json</code>. Trend mode:{" "}
        <span className={trendReady ? "text-emerald-400" : "text-amber-400"}>
          {trendReady ? "unlocked" : "locked (needs 3 cycle snapshots)"}
        </span>.
      </p>
      <ResponsiveContainer width="100%" height={320}>
        <BarChart data={data}>
          <CartesianGrid strokeDasharray="3 3" stroke="#27272a" />
          <XAxis dataKey="field" stroke="#a1a1aa" angle={-30} textAnchor="end" height={80} />
          <YAxis stroke="#a1a1aa" domain={[0, 100]} unit="%" />
          <Tooltip contentStyle={{ background: "#18181b", border: "1px solid #3f3f46" }} />
          <Legend />
          <Bar dataKey="percent" fill="#10b981" name="coverage %" />
        </BarChart>
      </ResponsiveContainer>
    </div>
  );
}
```

- [ ] **Step T22.2: Mount in page.tsx**

Edit `app/control-room/framework/page.tsx` — add after AdoptionTrendChart:

```tsx
<section>
  <DocDebtTrendChart coverage={docDebt.coverage} trendReady={docDebt.summary.trend_ready} />
</section>
```

Add the import at the top.

- [ ] **Step T22.3: Verify in browser, then commit**

```bash
npm run dev   # verify renders
git add components/framework-health/DocDebtTrendChart.tsx app/control-room/framework/page.tsx
git commit -m "$(cat <<'EOF'
feat(framework-v7-7): doc-debt coverage chart (T22 / PR-7)

T22: BarChart of documentation-debt.json coverage by field. Surfaces
trend_ready boolean prominently — unlocks when integrity_cycle_snapshots
reaches 3.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task T23: AutomationMap component

**Files:**
- Create: `components/framework-health/AutomationMap.tsx`

- [ ] **Step T23.1: Write the AutomationMap as a static lookup**

The check codes are stable enough that a hard-coded map (rather than runtime introspection) is acceptable. Create `components/framework-health/AutomationMap.tsx`:

```typescript
type CheckCode = {
  code: string;
  layer: "pre-commit" | "cycle" | "advisory";
  status: "gated" | "advisory" | "human-required";
  shipped_in: string;
  description: string;
};

const CHECKS: CheckCode[] = [
  // v7.5 (write-time)
  { code: "SCHEMA_DRIFT", layer: "pre-commit", status: "gated", shipped_in: "v7.5", description: "Legacy `phase` key (canonical: current_phase)" },
  { code: "PR_NUMBER_UNRESOLVED", layer: "pre-commit", status: "gated", shipped_in: "v7.5", description: "Unresolved PR number in state.json" },
  // v7.6 (write-time)
  { code: "PHASE_TRANSITION_NO_LOG", layer: "pre-commit", status: "gated", shipped_in: "v7.6", description: "Phase change without log event" },
  { code: "PHASE_TRANSITION_NO_TIMING", layer: "pre-commit", status: "gated", shipped_in: "v7.6", description: "Phase change without timing fields" },
  { code: "BROKEN_PR_CITATION", layer: "pre-commit", status: "gated", shipped_in: "v7.6", description: "Case study cites non-existent PR (write-time)" },
  { code: "CASE_STUDY_MISSING_TIER_TAGS", layer: "pre-commit", status: "gated", shipped_in: "v7.6", description: "Post-2026-04-21 case study without tier tags" },
  // v7.7 (write-time)
  { code: "CACHE_HITS_EMPTY_POST_V6", layer: "pre-commit", status: "gated", shipped_in: "v7.7", description: "Post-v6 feature complete with empty cache_hits[]" },
  { code: "CU_V2_INVALID", layer: "pre-commit", status: "gated", shipped_in: "v7.7", description: "cu_v2 schema invalid (factors / range / total / tier_class)" },
  { code: "STATE_NO_CASE_STUDY_LINK", layer: "pre-commit", status: "gated", shipped_in: "v7.7", description: "Complete without case_study link or exempt tag" },
  { code: "CASE_STUDY_MISSING_FIELDS", layer: "pre-commit", status: "gated", shipped_in: "v7.7", description: "Post-cutoff case study missing work_type/success_metrics/kill_criteria/dispatch_pattern" },
  // Cycle (existing)
  { code: "PHASE_LIE", layer: "cycle", status: "gated", shipped_in: "v7.5", description: "state.json phase contradicts artifacts" },
  { code: "TASK_LIE", layer: "cycle", status: "gated", shipped_in: "v7.5", description: "state.json task contradicts code/PR state" },
  { code: "NO_CS_LINK", layer: "cycle", status: "gated", shipped_in: "v7.5", description: "Complete without case-study (legacy code)" },
  { code: "V2_FILE_MISSING", layer: "cycle", status: "gated", shipped_in: "v7.5", description: "v2 refactor without v2/ subdirectory file" },
  { code: "PARTIAL_SHIP_TERMINAL", layer: "cycle", status: "gated", shipped_in: "v7.5", description: "Terminal phase partial-ship" },
  { code: "NO_STATE", layer: "cycle", status: "gated", shipped_in: "v7.5", description: "Feature directory without state.json" },
  { code: "INVALID_JSON", layer: "cycle", status: "gated", shipped_in: "v7.5", description: "state.json fails JSON parse" },
  { code: "NO_PHASE", layer: "cycle", status: "gated", shipped_in: "v7.5", description: "state.json missing current_phase" },
  // v7.7 advisory
  { code: "TIER_TAG_LIKELY_INCORRECT", layer: "cycle", status: "advisory", shipped_in: "v7.7", description: "T1 claim with no ledger match (heuristic)" },
];

export function AutomationMap() {
  const layers = ["pre-commit", "cycle", "advisory"] as const;
  const colors = {
    "pre-commit": "border-emerald-500/40 bg-emerald-950/30",
    "cycle": "border-blue-500/40 bg-blue-950/30",
    "advisory": "border-amber-500/40 bg-amber-950/30",
  };

  return (
    <div className="rounded-lg border border-zinc-800 p-4">
      <h3 className="text-lg font-semibold mb-2">Automation Map ({CHECKS.length} checks)</h3>
      <p className="text-sm text-zinc-400 mb-4">
        Every framework check, grouped by enforcement layer. v7.5 + v7.6 + v7.7 cumulative.
      </p>
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        {layers.map(layer => (
          <div key={layer} className={`rounded border p-3 ${colors[layer]}`}>
            <h4 className="font-semibold capitalize mb-2">{layer}</h4>
            <ul className="space-y-2">
              {CHECKS.filter(c => c.layer === layer).map(c => (
                <li key={c.code} className="text-xs">
                  <code className="font-mono">{c.code}</code>
                  <span className="ml-1 text-zinc-500">[{c.shipped_in}]</span>
                  <p className="text-zinc-400 mt-0.5">{c.description}</p>
                </li>
              ))}
            </ul>
          </div>
        ))}
      </div>
    </div>
  );
}
```

- [ ] **Step T23.2: Mount in page, verify, commit**

```bash
# Edit page.tsx — add <AutomationMap /> after DocDebtTrendChart
npm run dev   # verify
git add components/framework-health/AutomationMap.tsx app/control-room/framework/page.tsx
git commit -m "$(cat <<'EOF'
feat(framework-v7-7): automation-map of all 19 checks (T23 / PR-7)

T23: 3-column grid grouping every framework check by layer (pre-commit /
cycle / advisory). Static lookup — check definitions update with each
framework version.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task T24: HumanActionPanel — surfaces D1 + D2

**Files:**
- Create: `components/framework-health/HumanActionPanel.tsx`

- [ ] **Step T24.1: Write the component**

Create `components/framework-health/HumanActionPanel.tsx`:

```typescript
type HumanAction = {
  id: string;
  title: string;
  blocker_type: "human-required" | "external-required";
  description: string;
  status_doc: string;
  cta: string;
  cta_href?: string;
};

const ACTIONS: HumanAction[] = [
  {
    id: "D1",
    title: "Tier 2.1 — Real-Provider Auth Playbook",
    blocker_type: "human-required",
    description: "Run the auth-runtime verification playbook on simulator with a real Supabase project. ~1 hour. Records pass/fail evidence in trust/audits/. Cannot be self-served — requires a human at a simulator.",
    status_doc: "docs/setup/auth-runtime-verification-playbook.md",
    cta: "Run the playbook",
  },
  {
    id: "D2",
    title: "Tier 3.3 — External Replication",
    blocker_type: "external-required",
    description: "An independent researcher runs Gemini-style audit and posts findings. Cannot be self-served — by definition, external. Issue #142 invites external auditors.",
    status_doc: "https://github.com/Regevba/FitTracker2/issues/142",
    cta: "View invitation issue",
    cta_href: "https://github.com/Regevba/FitTracker2/issues/142",
  },
];

export function HumanActionPanel() {
  return (
    <div className="rounded-lg border border-amber-500/40 bg-amber-950/20 p-4">
      <h3 className="text-lg font-semibold mb-2">Human-Action Checklist</h3>
      <p className="text-sm text-zinc-400 mb-4">
        Items that v7.7 cannot mechanically close. Tracked separately, surfaced
        here so they aren't forgotten.
      </p>
      <ul className="space-y-4">
        {ACTIONS.map(a => (
          <li key={a.id} className="border-t border-amber-500/20 pt-3 first:border-0 first:pt-0">
            <div className="flex items-baseline gap-2">
              <span className="font-mono text-amber-400">{a.id}</span>
              <h4 className="font-semibold">{a.title}</h4>
              <span className="text-xs text-zinc-500 ml-auto">{a.blocker_type}</span>
            </div>
            <p className="text-sm text-zinc-300 mt-1">{a.description}</p>
            <a
              href={a.cta_href ?? `https://github.com/Regevba/FitTracker2/blob/main/${a.status_doc}`}
              target="_blank"
              rel="noopener noreferrer"
              className="text-sm text-amber-400 hover:underline inline-block mt-1"
            >
              {a.cta} →
            </a>
          </li>
        ))}
      </ul>
    </div>
  );
}
```

- [ ] **Step T24.2: Mount + commit**

```bash
# Edit page.tsx — add <HumanActionPanel /> after AutomationMap
git add components/framework-health/HumanActionPanel.tsx app/control-room/framework/page.tsx
git commit -m "$(cat <<'EOF'
feat(framework-v7-7): human-action panel for D1+D2 (T24 / PR-7)

T24: surfaces the 2 deferred items v7.7 cannot mechanically close.
Static list — items expand only on framework-version bump.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task T25: CycleSnapshotPanel — last cycle summary

**Files:**
- Create: `components/framework-health/CycleSnapshotPanel.tsx`

- [ ] **Step T25.1: Loader + component**

Extend `lib/framework-health/load-ledgers.ts`:

```typescript
export async function loadLatestIntegritySnapshot(): Promise<{
  generated_at: string;
  finding_count: number;
  by_code: Record<string, number>;
} | null> {
  const dir = path.join(FITTRACKER_REPO, ".claude/integrity/snapshots");
  try {
    const files = await fs.readdir(dir);
    const sorted = files.filter(f => f.endsWith(".json")).sort().reverse();
    if (sorted.length === 0) return null;
    const raw = await fs.readFile(path.join(dir, sorted[0]), "utf-8");
    return JSON.parse(raw);
  } catch {
    return null;
  }
}
```

Create `components/framework-health/CycleSnapshotPanel.tsx`:

```typescript
type Snap = {
  generated_at: string;
  finding_count: number;
  by_code: Record<string, number>;
} | null;

export function CycleSnapshotPanel({ snap }: { snap: Snap }) {
  if (!snap) {
    return (
      <div className="rounded-lg border border-zinc-800 p-4">
        <h3 className="text-lg font-semibold mb-2">Last Integrity Cycle</h3>
        <p className="text-sm text-zinc-400">No snapshots yet. First cycle expected within 72h of v7.5 ship date.</p>
      </div>
    );
  }
  return (
    <div className="rounded-lg border border-zinc-800 p-4">
      <h3 className="text-lg font-semibold mb-2">Last Integrity Cycle</h3>
      <p className="text-sm text-zinc-400 mb-3">
        {new Date(snap.generated_at).toLocaleString()} —{" "}
        <span className={snap.finding_count === 0 ? "text-emerald-400" : "text-amber-400"}>
          {snap.finding_count} findings
        </span>
      </p>
      <ul className="space-y-1 text-sm">
        {Object.entries(snap.by_code).map(([code, n]) => (
          <li key={code} className="flex justify-between">
            <code className="font-mono text-zinc-300">{code}</code>
            <span className="text-zinc-500">{n}</span>
          </li>
        ))}
      </ul>
    </div>
  );
}
```

- [ ] **Step T25.2: Mount in page + commit**

Edit `page.tsx` to load + render `<CycleSnapshotPanel snap={...} />`.

```bash
git add components/framework-health/CycleSnapshotPanel.tsx lib/framework-health/load-ledgers.ts app/control-room/framework/page.tsx
git commit -m "$(cat <<'EOF'
feat(framework-v7-7): cycle-snapshot panel (T25 / PR-7)

T25: surfaces last 72h integrity cycle: timestamp, finding count,
breakdown by code. Graceful empty state when no snapshots.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task T26: Cross-links to predecessor case studies

- [ ] **Step T26.1: Add a footer to the page with cross-links**

Edit `app/control-room/framework/page.tsx`, append at the bottom:

```tsx
<footer className="border-t border-zinc-800 pt-6 mt-8">
  <h3 className="font-semibold mb-3">Predecessor case studies</h3>
  <ul className="text-sm space-y-1">
    <li><a href="/case-studies/gemini-audit-2026-04-21" className="hover:underline">Gemini independent audit (2026-04-21) →</a></li>
    <li><a href="/case-studies/data-integrity-framework-v7-5" className="hover:underline">v7.5 — Data Integrity Framework →</a></li>
    <li><a href="/case-studies/mechanical-enforcement-v7-6" className="hover:underline">v7.6 — Mechanical Enforcement →</a></li>
    <li><a href="/case-studies/framework-v7-7-validity-closure" className="font-semibold text-emerald-400">v7.7 — Validity Closure (current) →</a></li>
  </ul>
</footer>
```

- [ ] **Step T26.2: Commit T26**

```bash
git add app/control-room/framework/page.tsx
git commit -m "$(cat <<'EOF'
feat(framework-v7-7): cross-links to predecessor case studies (T26 / PR-7)

T26: footer chain Gemini audit → v7.5 → v7.6 → v7.7 (current).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task T27: Add to control-room navigation

- [ ] **Step T27.1: Find the control-room nav source**

```bash
find app/control-room -name "*.tsx" | xargs grep -l "Nav\|nav-" | head
```

- [ ] **Step T27.2: Add link to /control-room/framework**

Edit the nav file, add:

```tsx
{ href: "/control-room/framework", label: "Framework Health" }
```

In the appropriate position alongside other control-room pages.

- [ ] **Step T27.3: Commit T27**

```bash
git add <nav file>
git commit -m "$(cat <<'EOF'
feat(framework-v7-7): control-room nav link to /framework (T27 / PR-7)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task T28: Lighthouse + accessibility check

- [ ] **Step T28.1: Build production bundle**

```bash
npm run build
npm run start &
SERVER_PID=$!
sleep 5
```

- [ ] **Step T28.2: Run Lighthouse**

```bash
npx lighthouse http://localhost:3000/control-room/framework --output html --output-path /tmp/lh-framework.html --chrome-flags="--headless"
grep -E '"score"' /tmp/lh-framework.html | head -10
kill $SERVER_PID
```

Expected: scores ≥ 90 in all 4 categories (performance, accessibility, best-practices, SEO). Match the rest of fitme-story baseline (95+/100/100/100 per memory).

- [ ] **Step T28.3: Run axe-core accessibility check**

```bash
npx @axe-core/cli http://localhost:3000/control-room/framework 2>&1 | tee /tmp/axe-framework.txt
```

Expected: 0 violations. If any, fix before opening PR.

- [ ] **Step T28.4: Open PR-7**

```bash
git push origin feature/framework-v7-7-validity-closure
gh pr create --title "v7.7 PR-7: framework-health dashboard" --body "$(cat <<'EOF'
## Summary
Absorbs UCC T43–T54 entirely. New page at /control-room/framework with:
- T21: AdoptionTrendChart (Recharts line; reads measurement-adoption-history)
- T22: DocDebtTrendChart (Recharts bar; reads documentation-debt)
- T23: AutomationMap (19 checks, 3 layers)
- T24: HumanActionPanel (D1+D2 surfaces)
- T25: CycleSnapshotPanel (last 72h cycle)
- T26: Cross-links to predecessor case studies
- T27: control-room nav

## Test plan
- [x] Lighthouse 4 categories ≥ 90 (perf/a11y/best-practices/SEO)
- [x] axe-core 0 violations
- [x] Charts render with current ledger data (2 snapshots)
- [x] HumanActionPanel surfaces D1+D2 with correct cross-links

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step T28.5: Append M4-complete entry to FitTracker2 case study**

Switch back to FitTracker2:

```bash
cd /Volumes/DevSSD/FitTracker2
```

Append to case study:

```markdown
### YYYY-MM-DD HH:MM UTC — M4 complete: framework-health dashboard live
- **Trigger:** PR-7 merged in fitme-story at <sha>; live at fitme-story.vercel.app/control-room/framework
- **What changed:** /control-room/framework page; 5 components (charts + automation map + human-action panel + cycle snapshot)
- **Ledger delta:** UCC T43–T54 now closed via absorption
- **Surprises / discoveries:** <fill in from Lighthouse/a11y runs>
- **Tier tags applied:** T1 (chart data is direct ledger reads); T2 (Lighthouse scores are measured but variable across runs).
```

```bash
git add docs/case-studies/framework-v7-7-validity-closure-case-study.md
git commit -m "docs(framework-v7-7): journal — M4 complete

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

**M4 done. Proceed to M5.**

---

## M5 — Closure & Synthesis (PR-8)

**Goal:** Verify B1+B2 trend modes have unlocked (passive cron firings); write Section 99 synthesis; update CLAUDE.md from in-progress stub to final v7.7 section; update master plan to "shipped"; close Linear epic; close Notion sub-page; surface human-action checklist.

### Task T29: Verify Tier 1.1 trend mode unlocked

- [ ] **Step T29.1: Confirm ≥3 daily snapshots in measurement-adoption-history.json**

```bash
python3 -c "
import json
h = json.load(open('.claude/shared/measurement-adoption-history.json'))
print(f'snapshots: {len(h[\"snapshots\"])}')
for s in h['snapshots']:
    print(f'  {s[\"date\"]}: trigger={s[\"trigger\"]}, fully_post_v6={s[\"summary\"][\"fully_adopted_post_v6\"]}')
"
```

Expected: ≥ 3 snapshots. The Monday cron at 05:00 UTC adds 1/week; the trend was at 2 snapshots on 2026-04-27, so ≥3 expected by ~2026-05-04.

- [ ] **Step T29.2: If < 3 snapshots, run a manual snapshot to top up**

```bash
make measurement-adoption  # writes today's snapshot
```

The script's append-only dedup-by-date logic ensures only one entry per day.

- [ ] **Step T29.3: Update case study with B1 verification**

Append to Section 2:

```markdown
### YYYY-MM-DD HH:MM UTC — B1 verified: Tier 1.1 trend mode unlocked
- **Trigger:** N≥3 snapshots in measurement-adoption-history.json
- **What changed:** trend mode condition met (passive)
- **Ledger delta:** trend visible on framework-health dashboard
- **Surprises / discoveries:** trend slope <number> over 7 days — <on track / behind target / ahead>
- **Tier tags applied:** T1 (snapshot count is mechanical).
```

### Task T30: Verify Tier 3.2 cycle-snapshot trend mode

- [ ] **Step T30.1: Confirm ≥3 integrity-cycle snapshot files**

```bash
ls .claude/integrity/snapshots/*.json 2>/dev/null | wc -l
```

Expected: ≥ 3 files. The 72h cron writes one per cycle; from a 2026-04-21 first cycle, ≥3 expected by ~2026-04-30.

- [ ] **Step T30.2: Run make documentation-debt to refresh trend_ready**

```bash
make documentation-debt
python3 -c "
import json
d = json.load(open('.claude/shared/documentation-debt.json'))
print('trend_ready:', d['summary']['trend_ready'])
print('integrity_cycle_snapshots:', d['summary']['integrity_cycle_snapshots'])
"
```

Expected: `trend_ready: true`.

- [ ] **Step T30.3: Append B2 verification to case study**

```markdown
### YYYY-MM-DD HH:MM UTC — B2 verified: Tier 3.2 trend mode unlocked
- **Trigger:** integrity_cycle_snapshots ≥ 3
- **What changed:** trend_ready: true; framework-health DocDebtTrendChart now shows trend lines
- **Ledger delta:** N/A (passive)
- **Tier tags applied:** T1.
```

### Task T31: Section 99 — Synthesis

- [ ] **Step T31.1: Compute final pre/post deltas**

```bash
make measurement-adoption
make documentation-debt
python3 -c "
import json
m = json.load(open('.claude/shared/measurement-adoption.json'))
d = json.load(open('.claude/shared/documentation-debt.json'))
print('=== Tier 1.1 final ===')
print(f'fully_adopted_post_v6: {m[\"summary\"][\"fully_adopted_post_v6\"]}')
print(f'cache_hits post_v6: {m[\"dimension_coverage\"][\"cache_hits\"][\"post_v6_percent\"]}%')
print(f'cu_v2 post_v6: {m[\"dimension_coverage\"][\"cu_v2\"][\"post_v6_percent\"]}%')
print(f'per_phase post_v6: {m[\"dimension_coverage\"][\"per_phase_timing\"][\"post_v6_percent\"]}%')
print('=== Tier 3.2 final ===')
print(f'open_debt_items: {d[\"summary\"][\"open_debt_items\"]}')
for f, c in d['coverage'].items():
    print(f'  {f}: {c[\"percent\"]}%')
"
```

- [ ] **Step T31.2: Write Section 99 in case study**

Edit `docs/case-studies/framework-v7-7-validity-closure-case-study.md`. Replace the `<!-- Populate at M5 -->` comment under Section 99 with:

```markdown
## Section 99 — Synthesis

> Written at v7.7 merge: <date>. All 8 PRs merged; all 42 tasks closed.

### Pre/post metrics (frozen at merge)

| Tier 1.1 dimension | Pre-v7.7 (2026-04-27) | Post-v7.7 (<merge date>) | Delta |
|---|---|---|---|
| post-v6 fully-adopted | 2/9 (22.2%) | <N>/<M> (<pct>%) | <delta> |
| cache_hits post-v6 | 33.3% | <pct>% | gated → 100% on next reads |
| cu_v2 post-v6 (presence) | 66.7% | <pct>% | gated, schema-validated |
| per_phase_timing post-v6 | 66.7% | <pct>% | gated forward |
| state↔case-study linkage | 95.5% | 100% | gated |
| documentation-debt open items | 7 | <N> | <delta> |

### What got gated, what stayed advisory, what stayed human-only

**Newly gated (5 codes):** CACHE_HITS_EMPTY_POST_V6, CU_V2_INVALID,
STATE_NO_CASE_STUDY_LINK, CASE_STUDY_MISSING_FIELDS, plus T20 promotion
of TIER_TAG_LIKELY_INCORRECT (if FP rate < 10% at +7 days).

**Stayed advisory:** TIER_TAG_LIKELY_INCORRECT (if FP rate 10-25% — see
T20 decision).

**Stayed human-only:** D1 (Tier 2.1 auth playbook), D2 (Tier 3.3 external
replication). See Section "Human-Action Checklist" below.

### The 5 unclosable gaps (carried forward from CLAUDE.md "Known Mechanical Limits")

1. cache_hits writer-path adoption — **closed by v7.7 M1** ✓
2. cu_v2 factor magnitude correctness — **schema validated, magnitude judgment unchanged**
3. T1/T2/T3 tag correctness on novel claims — **heuristic checker added (advisory or gated per T20)**
4. Tier 2.1 real-provider auth simulator runs — **deferred (D1)**
5. Tier 3.3 external replication — **deferred (D2)**

Of 5 originally documented gaps, 3 closed mechanically + heuristically;
2 require human or external action.

### Predecessor chain

```
2026-04-21: Gemini independent audit (Tier 1-3 findings)
       ↓
2026-04-24: v7.5 — Data Integrity Framework (8 cooperating defenses)
       ↓
2026-04-25: v7.6 — Mechanical Enforcement (7 Class B → A promotions)
       ↓
<merge>:    v7.7 — Validity Closure (this case study)
```

### Tier-tag audit on this case study

Quantitative claims in this synthesis: 12. Of those, 10 tagged T1, 2
tagged T2 (predicted post-merge values that won't measure until cycles
fire). 0 tagged T3.

Cross-check: every T1 number traced back to a ledger field or PR diff.

### Pre-mortem honesty re-statement

v7.7 closed every gap that was mechanically or heuristically closable.
It did NOT close the 2 documented unclosable gaps (D1, D2). Anyone
reading post-v7.7 metrics should expect 100% on gated dimensions and
acknowledged gaps on judgment + external dimensions. A framework that
knows what it cannot check is more trustworthy than one that pretends
every check is a check.
```

- [ ] **Step T31.3: Commit T31**

```bash
git add docs/case-studies/framework-v7-7-validity-closure-case-study.md
git commit -m "$(cat <<'EOF'
docs(framework-v7-7): Section 99 synthesis (T31 / PR-8)

T31: pre/post metrics deltas, gated/advisory/human-only breakdown,
5-unclosable-gaps carry-forward, predecessor chain, tier-tag audit on
this case study, pre-mortem honesty re-statement.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task T32: CLAUDE.md final v7.7 section + version banner

- [ ] **Step T32.1: Replace stub with full v7.7 section**

Edit `CLAUDE.md`:

1. Replace the in-progress banner from T0d:
   - Old: `(v7.5 → v7.6 → v7.7-IN-PROGRESS, shipped 2026-04-24 → 2026-04-25 → ___)`
   - New: `(v7.5 → v7.6 → v7.7, shipped 2026-04-24 → 2026-04-25 → <merge date>)`

2. Replace the v7.7 stub section (added in T0d) with a full v7.7 section. Pattern: mirror the v7.6 "Mechanical Enforcement" section structure.

3. Update the cycle-time check codes count in the existing list. Was 12, became 13 at PR-2 (+CU_V2_INVALID), 14 at PR-6 if T20 promoted (+TIER_TAG_LIKELY_INCORRECT). Add new write-time codes too: CACHE_HITS_EMPTY_POST_V6, STATE_NO_CASE_STUDY_LINK, CASE_STUDY_MISSING_FIELDS.

4. Update "Known Mechanical Limits" section. Before v7.7: 5 gaps. After v7.7: cache_hits gap is closed (remove from list). Tier-tag correctness: clarify heuristic-checker status (advisory or gated). Other 3 gaps unchanged.

- [ ] **Step T32.2: Commit T32**

```bash
git add CLAUDE.md
git commit -m "$(cat <<'EOF'
docs(framework-v7-7): CLAUDE.md final v7.7 section + banner update (T32 / PR-8)

T32: replaces in-progress stub. Final v7.7 section documents 4 new
write-time hooks + 1 advisory cycle check (or gated, per T20 decision).
"Known Mechanical Limits" now lists 4 items (cache_hits gap closed).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task T33: Master plan + RICE roadmap → Shipped

- [ ] **Step T33.1: Edit master plan**

Edit `docs/master-plan/master-plan-2026-04-06.md` — find the v7.7 entry from T0e and:
- Change status from "ACTIVE — full-priority freeze" to "SHIPPED <merge date>"
- Add a "Final results" sub-section pointing at Section 99 synthesis

- [ ] **Step T33.2: Edit RICE roadmap**

Edit `docs/master-plan/master-backlog-roadmap.md` — change v7.7 row's status field to "Shipped".

- [ ] **Step T33.3: Commit T33**

```bash
git add docs/master-plan/master-plan-2026-04-06.md docs/master-plan/master-backlog-roadmap.md
git commit -m "$(cat <<'EOF'
docs(master-plan): mark v7.7 shipped (T33 / PR-8)

T33: master plan + RICE roadmap reflect v7.7 merged. Final-results
sub-section cross-links Section 99 synthesis.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task T34: Linear MCP closure

- [ ] **Step T34.1: Load Linear MCP tools**

```
ToolSearch query "select:mcp__linear__save_issue,mcp__linear__list_issues,mcp__linear__list_issue_statuses,mcp__linear__save_comment"
```

- [ ] **Step T34.2: Mark all 8 sub-issues Done**

For each PR-1..PR-8 sub-issue:

```
mcp__linear__save_issue with:
  id: <sub-issue id>
  state: <"Done" status id>
```

- [ ] **Step T34.3: Add closing comment + close epic**

```
mcp__linear__save_comment with:
  issue: <epic id>
  body: |
    v7.7 merged at <commit sha>.

    Final results:
    - Primary metric: post-v6 fully-adopted <X>/<Y> (<pct>%) — vs target ≥72.7%
    - 4 new write-time hooks + 1 cycle-time check shipped
    - Issue #140 closed
    - Synthesis: docs/case-studies/framework-v7-7-validity-closure-case-study.md#section-99-synthesis

    D1 + D2 deferred to post-v7.7 follow-on (see human-action panel
    on framework-health dashboard).

mcp__linear__save_issue with:
  id: <epic id>
  state: <"Done" status id>
```

### Task T35: Notion MCP closure

- [ ] **Step T35.1: Load Notion MCP tools**

```
ToolSearch query "select:mcp__notion__notion-update-page,mcp__notion__notion-fetch"
```

- [ ] **Step T35.2: Update v7.7 sub-page status**

```
mcp__notion__notion-update-page with:
  page_id: <v7.7 sub-page id from T0g>
  command: "append"
  body: |

    ---

    ## Status: SHIPPED <merge date>

    **Final synthesis:** [docs/case-studies/framework-v7-7-validity-closure-case-study.md#section-99-synthesis](https://github.com/Regevba/FitTracker2/blob/main/docs/case-studies/framework-v7-7-validity-closure-case-study.md)

    **Final metrics:**
    - post-v6 fully-adopted: <X>/<Y> (<pct>%)
    - cache_hits post-v6: 100% (gated)
    - cu_v2 post-v6: 100% (schema-validated)
    - state↔case-study linkage: 100% (gated)

    **Linear epic:** Done — see closing comment for full breakdown.
```

- [ ] **Step T35.3: Update v7.6 sub-page footer with backlink**

```
mcp__notion__notion-update-page with:
  page_id: <v7.6 sub-page id>
  command: "append"
  body: "\n\n→ **v7.7 — Validity Closure** has shipped. The cache_hits writer-path gap (#140) and the documentation-debt + linkage gaps are now mechanically gated."
```

- [ ] **Step T35.4: Update "Project Context & Status" page**

```
mcp__notion__notion-search query="Project Context & Status"
mcp__notion__notion-update-page with:
  page_id: <main status page id>
  body: "<replace v7.5 → v7.6 → v7.7-IN-PROGRESS with v7.5 → v7.6 → v7.7>"
```

### Task T35 epilog: Open PR-8, merge, close

- [ ] **Step T35.5: Open PR-8**

```bash
git push origin feature/framework-v7-7-validity-closure
gh pr create --title "v7.7 PR-8: closure synthesis + propagation" --body "$(cat <<'EOF'
## Summary
Final v7.7 PR. Closes M5.

- T29: B1 verified (Tier 1.1 trend mode unlocked)
- T30: B2 verified (Tier 3.2 cycle-snapshot trend mode unlocked)
- T31: Section 99 Synthesis written
- T32: CLAUDE.md final v7.7 section + banner
- T33: Master plan + RICE roadmap → Shipped
- T34: Linear MCP — epic + 8 sub-issues marked Done (executed via MCP, no commit)
- T35: Notion MCP — v7.7 sub-page Shipped, v7.6 footer linked, status page updated (executed via MCP, no commit)

## Final metrics

| Metric | Pre-v7.7 | Post-v7.7 |
|---|---|---|
| post-v6 fully-adopted | 2/9 (22.2%) | <X>/<Y> (<pct>%) |
| cache_hits post-v6 | 33.3% | 100% (gated) |
| cu_v2 post-v6 (presence) | 66.7% | 100% (schema-validated) |
| state↔case-study linkage | 95.5% | 100% (gated) |
| Mechanically unclosable gaps | 5 | 2 (D1, D2 deferred) |

## Test plan
- [x] All 8 PRs merged
- [x] Linear epic Done
- [x] Notion sub-page Shipped
- [x] Section 99 synthesis written
- [x] CLAUDE.md banner reflects shipped date
- [x] Framework-health dashboard renders v7.7 final values

## Resume signals fire on merge

After this merges, the 6 paused features' resume_signal field is satisfied:
app-store-assets, auth-polish-v2, import-training-plan, onboarding-v2-retroactive,
push-notifications, stats-v2.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step T35.6: After PR-8 merges, append final journal entry**

```markdown
### YYYY-MM-DD HH:MM UTC — v7.7 SHIPPED
- **Trigger:** PR-8 merged at <sha>
- **What changed:** all 42 tasks closed; all external systems propagated; Section 99 synthesis written; CLAUDE.md/master plan/Linear/Notion all consistent
- **Ledger delta:** see Section 99 table
- **Surprises / discoveries:** <fill in any final-week observations>
- **Tier tags applied:** T1 for ledger numbers, T2 for predicted post-merge stable values.

### v7.7 IS SHIPPED. 6 paused features may now resume per their resume_signal.
```

```bash
git add docs/case-studies/framework-v7-7-validity-closure-case-study.md
git commit -m "docs(framework-v7-7): journal — v7.7 SHIPPED

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step T35.7: Schedule +90-day retrospective**

```
/schedule
  cron: "0 14 +90d"
  task: "Open Section 100 — 90-day retrospective in
         docs/case-studies/framework-v7-7-validity-closure-case-study.md.
         Run measurement-adoption + documentation-debt; compare to Section
         99 frozen values. Append observed metric drift, false-positive
         rates accumulated since merge, any new findings from cycle audits.
         If new check codes are warranted, propose v7.8 scope."
```

**M5 done. v7.7 shipped.**

---

## Self-Review Checklist

After completing this plan, audit it against the spec:

### 1. Spec coverage
- [ ] Spec §3.2 milestone table: M0/M1/M2/M3/M4/M5 each have tasks in this plan? **YES (T0a-T0g/T1-T8/T9-T16/T17-T20/T21-T28/T29-T35)**
- [ ] Spec §3.3 new check codes: 5 codes (CACHE_HITS_EMPTY_POST_V6, CU_V2_INVALID, STATE_NO_CASE_STUDY_LINK, CASE_STUDY_MISSING_FIELDS, TIER_TAG_LIKELY_INCORRECT) — all have implementing tasks? **YES (T3, T7, T11, T12, T17/T18)**
- [ ] Spec §4.1 case-study journal protocol: live append-only — referenced? **YES (T0a.2 creates skeleton; every milestone appends entries)**
- [ ] Spec §5.1 hard-paused features: 6 with state.json + memory annotations — done? **YES (memory in brainstorming session; state.json in T0c)**
- [ ] Spec §5.2 UCC absorption: explicit `tasks_migrated_to` field? **YES (T0b)**
- [ ] Spec §6 metrics: primary metric measurable? **YES — `make measurement-adoption` reads `summary.fully_adopted_post_v6`**
- [ ] Spec §7 done criteria: all 8 items have closure tasks in this plan? **YES**
- [ ] Spec §8 kill criteria: each has a check-in step? **YES (T1.5 KC1, T4.3 KC3, T7 hooks gate KC4-style, T19 baseline drives KC2)**
- [ ] Spec §3.5.1 M5 closure propagation T29-T35? **YES (mapped 1:1)**

### 2. Placeholder scan
Search the plan for these red flags:
- "TBD", "TODO" — only present inside example code blocks (the script generates them; allowed)
- "implement later" — none
- "similar to Task N" — none (every code block is repeated where used)
- Missing code blocks for code steps — none

### 3. Type consistency
- `find_active_feature()` (T2) → returns Path | None ✓ called with mtime ordering ✓
- `validate(state: dict)` (T6) → returns list[str] ✓
- `check_cache_hits_empty_post_v6(state: dict)` (T3) → returns list[dict] ✓
- `check_state_no_case_study_link(state: dict)` (T11) → returns list[dict] ✓ (matches T3 pattern)
- `check_case_study_missing_fields(path: Path)` (T12) → returns list[dict] ✓
- TypeScript: `AdoptionSnapshot` (T21) consistent across `loadAdoptionHistory` + `AdoptionTrendChart` ✓
- TypeScript: `DocDebtSnapshot.coverage` is `Record<string, {present, missing, percent}>` (T21) — `DocDebtTrendChart` reads `.percent` ✓

### 4. Cross-cutting
- Branch name `feature/framework-v7-7-validity-closure` consistent across both repos? **YES**
- Co-Authored-By line on every commit? **YES**
- Case-study journal appended at every milestone boundary? **YES (M0.verify.3, T5.3, T8.4, T16.3, T20.3, T28.5, T35.6)**
- All 8 PRs have `gh pr create` commands with title + summary + test plan? **YES**

If any check fails, fix inline above. Done.

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-04-27-framework-v7-7-validity-closure.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task; review between tasks; fast iteration. Best for code-heavy milestones (M1–M3) where TDD discipline matters.

**2. Inline Execution** — Execute tasks in this session using executing-plans; batch execution with checkpoints. Best when human review at each PR boundary is desired.

For v7.7 specifically: M0 should be inline (lots of MCP coordination + memory writes that benefit from session context); M1–M3 + M5 are good fits for subagent-driven; M4 is a separate repo and could go either way.

**Which approach?**

