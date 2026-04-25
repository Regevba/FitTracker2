# Implementation Plan — v7.6 Mechanical Enforcement (Phases 2, 3, 4)

> **Generated:** 2026-04-25 by Plan agent (`ad35ac45cd41efaea`)
> **Sister plan:** Phase 1 was executed in the same session; this plan covers everything after.
> **Final step (LAST):** Phase 3c — file the Tier 3.3 public GitHub external-review issue. Only after every other deliverable is on main.

---

## 1. Executive summary

Phase 1 (in flight by the main agent) ships the four write-time mechanical defenses (`PHASE_TRANSITION_NO_LOG`, `PHASE_TRANSITION_NO_TIMING`, write-time tier-tag check, and case-study preflight). This plan covers Phases 2–4: per-PR enforcement layer (PR review bot + append-only measurement-adoption history + weekly framework-status cron), explicit labeling of mechanically unclosable gaps, and the v7.5 → v7.6 framework version bump with full case-study, manifest, mirror, and cross-repo updates. Total estimated effort: ~5.5 hours, ~12 commits across 2 repos.

---

## 2. Phase 2 — Per-PR enforcement (~3 hours)

### 2a. PR review bot via GitHub Actions

**New file:** `.github/workflows/pr-integrity-check.yml`

**Pattern source:** `.github/workflows/integrity-cycle.yml` — reuse `actions/checkout@v4` + `actions/setup-python@v5` + `actions/github-script@v7`. PR-bot adds `pull_request` trigger and sticky-comment update.

**Trigger config:**
```yaml
on:
  pull_request:
    types: [opened, synchronize, reopened]
permissions:
  contents: read
  pull-requests: write
  statuses: write
  issues: write
concurrency:
  group: pr-integrity-${{ github.event.pull_request.number }}
  cancel-in-progress: true
```

**Job structure (8 steps; none short-circuit):**
1. Checkout PR HEAD with `fetch-depth: 0`.
2. Set up Python 3.11.
3. Run all four checks against PR HEAD, capturing exit + stdout per step (`set +e` so single failure doesn't kill the job before commenting):
   - `python3 scripts/check-state-schema.py` → `/tmp/pr-schema.txt`
   - `python3 scripts/integrity-check.py --findings-only` → `/tmp/pr-integrity.txt`
   - `python3 scripts/measurement-adoption-report.py --output /tmp/pr-adoption.json --snapshot-trigger pr_bot`
   - `bash scripts/framework-status.sh` → `/tmp/pr-status.txt`
4. Capture PR-HEAD finding count as `pr_findings`.
5. Capture main baseline via `git worktree add /tmp/main-tree origin/main` → run integrity-check there → capture `main_findings` → `git worktree remove /tmp/main-tree`.
6. Compute `delta = pr_findings - main_findings`. Status = `success` if delta ≤ 0, else `failure`.
7. Set commit status check: name `pm-framework/pr-integrity`. Use `actions/github-script@v7` to call `repos.createCommitStatus`.
8. Sticky-comment behavior:
   - Search PR comments for marker `<!-- pm-framework-pr-integrity-bot -->`.
   - If found AND content unchanged → skip.
   - If found AND content changed → `issues.updateComment`.
   - If not found → create new with marker.

**Comment template:** see Plan agent §2a (full template at `/private/tmp/.../ad35ac45cd41efaea.output`).

**Status check name:** `pm-framework/pr-integrity` — required for branch protection. Document in CLAUDE.md "## CI Pipeline".

**Graceful degradation:**
- Forks lack write tokens → no-op gracefully (skip comment + status, exit 0).
- Main checkout fails → set `main_findings=0` + footnote.

**Effort:** ~75 min.

### 2b. Append-only measurement-adoption history

**File extended:** `scripts/measurement-adoption-report.py`
**New file written by script:** `.claude/shared/measurement-adoption-history.json`

**Schema:**
```json
{
  "version": "1.0",
  "description": "Append-only daily snapshots of Tier 1.1 measurement adoption.",
  "snapshots": [
    {
      "date": "2026-04-25",
      "generated_at": "<ISO>",
      "trigger": "manual|scheduled_cycle|pr_bot|weekly_status",
      "summary": {...},
      "dimension_coverage": {...}
    }
  ]
}
```

**Implementation:**
1. New CLI flags: `--history-output PATH`, `--snapshot-trigger {manual,scheduled_cycle,pr_bot,weekly_status}`.
2. New function `append_snapshot(history_path, report, trigger)`:
   - Load existing or initialize.
   - Compute `today = report["updated"][:10]`.
   - **Dedup:** if any existing snapshot has `date == today`, skip.
   - Else append + atomic rename.
3. Print `History: appended snapshot for <date> (<trigger>)` or `... already exists, skipped`.

**Plumbing:**
- PR bot calls with `--snapshot-trigger pr_bot`.
- Weekly cron with `--snapshot-trigger weekly_status`.
- `make measurement-adoption` defaults to `manual`.

**Effort:** ~30 min.

### 2c. Weekly framework-status cron

**New file:** `.github/workflows/framework-status-weekly.yml`
**New directory:** `.claude/integrity/weekly-status/`

**Snapshot file format:** `.claude/integrity/weekly-status/<YYYY-MM-DD>.json`
```json
{
  "date": "...",
  "generated_at": "...",
  "framework_version": "7.6",
  "metrics": {
    "integrity_findings": 0,
    "features_scanned": 41,
    "case_studies_count": 47,
    "fully_adopted": 0,
    "cache_hits_present": 1,
    "cu_v2_present": 4,
    "documentation_debt_open": 7,
    "active_feature_logs": 5,
    "pre_commit_hook_installed": true
  },
  "raw_status_output": "..."
}
```

**Trigger:**
```yaml
on:
  schedule:
    - cron: "0 9 * * 1"
  workflow_dispatch: {}
```

**Job structure:**
1. Checkout (full history).
2. Python 3.11.
3. `bash scripts/framework-status.sh` → `/tmp/status.txt`.
4. Re-run underlying Python helpers for parseable JSON (do NOT parse TTY output).
5. Build snapshot JSON.
6. Compare to last week:
   ```bash
   prev=$(ls -1 .claude/integrity/weekly-status/*.json 2>/dev/null | grep -v "$(date -u +%Y-%m-%d)" | tail -1 || true)
   ```
7. **Regression rules** (open issue if any):
   - `integrity_findings` increased
   - `cache_hits_present` decreased
   - `cu_v2_present` decreased
   - `fully_adopted` decreased
   - `active_feature_logs` decreased
   - `documentation_debt_open` increased by > 2
   - `pre_commit_hook_installed` flipped true → false
8. Duplicate-issue guard via `gh issue list --label framework-status-weekly`.
9. Commit snapshot to main: `chore(framework-status): weekly snapshot <date>`.

**Issue title:** `Weekly framework-status: regression {YYYY-MM-DD}`
**Issue labels:** `framework-status-weekly`, `regression`, `auto-filed`.

**Effort:** ~75 min.

---

## 3. Phase 3 — Explicit labeling of unclosable gaps (~1 hour)

### 3a. `docs/case-studies/meta-analysis/unclosable-gaps.md`

**Format:** match `data-quality-tiers.md` + `v7-5-advancement-report.md`. Front-matter, H2 per gap, H3 sub-sections.

**5 gaps to enumerate:**
1. `cache_hits[]` writer-path adoption (Tier 1.1 sub-gap)
2. `cu_v2` complexity factor declarations (Tier 2.3/1.1)
3. T1/T2/T3 tier label correctness (Tier 2.3)
4. Tier 2.1 manual real-provider auth checklist
5. Tier 3.3 external replication

**Per gap, 4 sub-sections:**
- **Why it cannot be mechanically closed** (technical reason)
- **What we observe instead** (observability path: ledgers, dashboards)
- **What a human can do to close it** (manual action)
- **Tracking** (issue #, doc reference)

**Closing section: Class A vs Class B table** showing v7.5 → v7.6 promotions.

**Length target:** ~280 lines.

**Effort:** ~30 min.

### 3b. CLAUDE.md "Known Mechanical Limits" section

**Insert after the "## Data Integrity Framework" section** (~10 lines max).

Section content:
```markdown
## Known Mechanical Limits

The v7.6 Mechanical Enforcement work promoted 4 silent gaps to write-time pre-commit failures and 3 silent gaps to per-PR / weekly checks. Five gaps remain mechanically unclosable by physical or policy necessity:

1. `cache_hits[]` writer-path adoption — agent must remember to log it (issue #140)
2. `cu_v2` factor *correctness* — judgment-based; we check presence, not magnitude
3. T1/T2/T3 tag *correctness* — we check presence on post-2026-04-21 case studies, not whether the tag is right
4. Tier 2.1 real-provider auth checklist — requires a human at a simulator
5. Tier 3.3 external replication — requires an external operator

Authoritative reference: [`docs/case-studies/meta-analysis/unclosable-gaps.md`](docs/case-studies/meta-analysis/unclosable-gaps.md).
```

Also update the v7.5 section header to include v7.6 and append a one-line v7.6 note.

**Effort:** ~10 min.

### 3c. Tier 3.3 public GitHub issue (FILED LAST — only after Phase 4 ships)

**Command:**
```bash
gh issue create \
  --title "Tier 3.3: external replication invitation — run /pm-workflow on an unrelated product" \
  --label "tier-3-3,external-replication,help-wanted" \
  --body-file /tmp/issue-body.md
```

**Issue body:** see full template in Plan agent §3c. Key sections:
- What this issue is + why we're asking
- What evidence to return (4 items)
- How we'll use the response (publish-verbatim policy)
- Statement of independence requirement

After filing: pin via `gh issue pin <num>`, update `unclosable-gaps.md` Gap 5 "Tracking" with the issue number.

**Effort:** ~10 min.

---

## 4. Phase 4 — v7.6 framework bump (~1.75 hours)

### 4a. `framework-manifest.json` bump

- `version`: `1.7` → `1.8`
- `framework_version`: `7.5` → `7.6`
- `updated`: <ship time>
- New `description` (see Plan agent §4a)
- 5 new capability flags: `pr_review_bot`, `weekly_status_cron`, `unclosable_gaps_documented`, `mechanical_phase_transition_enforcement`, `mechanical_case_study_preflight`
- New top-level block `v7_6_mechanical_enforcement` with `write_time_defenses` (4 entries: 1a, 1b, 1c, 1d), `per_pr_and_weekly_defenses` (3 entries: 2a, 2b, 2c), `unclosable_gaps_class_b` (5 gaps), `aggregate`, `policy_decisions_continued`.

**Effort:** ~20 min.

### 4b. New case study `mechanical-enforcement-v7-6-case-study.md`

**Format:** match `data-integrity-framework-v7.5-case-study.md` structure exactly.

**T1 SOURCING RULE:** Every numeric claim MUST be:
- Sourced from `.claude/features/data-integrity-framework-v7-6/state.json` (T1)
- OR sourced from a deterministic command output (T1)
- OR (T2) declared with explicit "(T2 — declared from manifest)" annotation

NO T3 narrative for v7.6's own work.

**Required sections:** Header, Why This Case Study Exists, Summary Card with T1 numbers, 4 write-time defenses (one per section), 3 per-PR/weekly defenses, before/after table, end-to-end data flow, What earned the bump, What's still in Class B (link to unclosable-gaps.md), Policy decisions continued, Lessons, Links.

**Length target:** ~450 lines (parity with v7.5).

**Effort:** ~45 min.

### 4c. `docs/skills/evolution.md` header update

Replace v7.5 status block with v7.6 status. Preserve all sections below.

**Effort:** ~5 min.

### 4d. `.claude/integrity/README.md` update

Insert v7.6 context block at top. Update v7.5 line to read "v7.5 → v7.6".

**Effort:** ~5 min.

### 4e. Repo-root mirrors + memory updates

Files: `project_gemini_audit_2026_04_21.md`, `project_framework_v7_1_integrity_cycle.md`, `project_data_integrity_framework_v7_5.md` (memory).

New memory file: `project_mechanical_enforcement_v7_6.md`.

**Effort:** ~15 min.

### 4f. fitme-story `/trust` page

File: `/Volumes/DevSSD/fitme-story/src/app/trust/page.tsx`

Add "Mechanical enforcement (2026-04-25)" `<dt>/<dd>` block to the existing `<dl>`. Update "Remediation progress" date + body. Update page subtitle.

**Effort:** ~15 min.

---

## 5. Sequencing notes

**Strict ordering:**
1. Phase 1 ships first (already in flight).
2. Phase 2a → 2b → 2c (2c depends on 2b's flag).
3. Phase 3a → 3b → 3a-link-update (CLAUDE.md links to `unclosable-gaps.md`).
4. Phase 3a + 3b → 4b (case study links to both).
5. Phase 4a → 4b (case study cites manifest).
6. Phase 4b → 4c → 4d → 4e (mirrors + memory cross-link).
7. Phase 4f after FitTracker2 main contains v7.6.
8. **Phase 3c (Tier 3.3 issue) is THE LAST STEP.**

**Total expected commits:** ~12

**Total effort:** ~5.9 hours.

---

## 6. Risk register

10 risks identified — see Plan agent's full risk register at `/private/tmp/.../ad35ac45cd41efaea.output`. Highlights:
- R1: PR bot recursion → marker comment + commit-SHA check
- R3: Weekly cron duplicate issues → `gh issue list` pre-check
- R4: PR bot leaves dirty tree → use `git worktree add /tmp/main-tree`
- R6: `unclosable-gaps.md` drifts from manifest → reconciliation step in Phase 4b
- R9: `framework-status.sh` parsing in cron → re-run Python helpers, don't parse TTY output

---

## 7. Verification plan

Per phase verification commands documented in Plan agent's full output. End-to-end after every commit:
- `make framework-status` outputs `Framework version: 7.6`
- `bash scripts/test-v7-5-pipeline.sh` passes (15+ assertions after Phase 1 extensions)
- `python3 scripts/integrity-check.py --findings-only` → 0 findings
- `gh workflow list` → 3 active workflows

---

## Plan source

Full Plan agent output (with comment templates, exact JSON schemas, all command-line invocations) archived at:
`/private/tmp/claude-501/-Volumes-DevSSD-FitTracker2/58886f72-390a-499e-a534-adb7e2e44a15/tasks/ad35ac45cd41efaea.output`

The above is a structural summary; consult the full transcript for verbatim YAML, JSON, and shell snippets.
