# Meta-Analysis Refresh — Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce Phase 1 of a 3-phase meta-analysis program — 4 docs + 1 prompt + 1 profile + 1 staged copy — paired with External Audit #2 (2026-06-12).

**Architecture:** Build a deterministic extraction profile to snapshot the n=83 corpus, then write 3 internal docs (L0 delta, L1 extended cohort analysis, L2 File B internal sidecar) and 1 auditor-facing doc (L2 File A) that passes the §6.4 impartiality + redaction contract.

**Tech Stack:** Python 3 stdlib (`scripts/audit/build_bundle.py` + `scripts/audit/redaction.py` already exist) · Markdown docs · `make integrity-check` for pre-ship validation · git for commits.

**Spec:** [`docs/superpowers/specs/2026-05-22-meta-analysis-refresh-phase-1-design.md`](../specs/2026-05-22-meta-analysis-refresh-phase-1-design.md).

**Timeline:** 17 days · today=Day 0=2026-05-22 · ships 2026-06-08.

---

## File Map

**Files to create:**
- `scripts/audit/profiles/meta-analysis-2026-05-22.json` — extraction profile for the L0/L1 corpus snapshot
- `docs/audits/prompts/03-meta-analysis-l2-extraction-prompt.md` — prompt of record for L2 File A generation (§6.5)
- `docs/case-studies/meta-analysis/2026-05-22-l0-delta-vs-anchor.md` — ~80 lines, internal
- `docs/case-studies/meta-analysis/2026-05-22-l1-extended-cohort-analysis.md` — ~400 lines, internal
- `docs/case-studies/meta-analysis/2026-05-22-l2-audit-prep-claims-v7-9-1.md` — ~200 lines, File A auditor-facing
- `docs/case-studies/meta-analysis/2026-05-22-l2-internal-sidecar.md` — ~80 lines, File B internal only
- `docs/audits/external/02-2026-06-12-v7-9-1-f16-plus-hadf/claude-bundle/2026-05-22-l2-audit-prep-claims-v7-9-1.md` — copy of File A staged into Audit #2 bundle

**Files to modify:**
- `docs/case-studies/meta-analysis/README.md:1-200` — append 3 new index rows under the existing Reports table

---

## Day-by-day timeline

| Day | Tasks | Output |
|---|---|---|
| 0-1 (05-22→05-23) | Spec written + this plan written | (already done) |
| 2-3 (05-24→05-25) | Tasks 1-2 | Extraction profile + L2 prompt of record |
| 3-4 (05-25→05-26) | Tasks 3-5 | L0 complete |
| 5-12 (05-27→06-03) | Tasks 6-12 | L1 complete |
| 13-15 (06-04→06-06) | Tasks 13-17 | L2 File B + File A + impartiality + redaction validated |
| 16 (06-07) | Tasks 18-19 | README index + pre-ship integrity-check |
| 17 (06-08) | Task 20 | Stage L2 File A into Audit #2 bundle + final ship commit + push |

---

### Task 1: Create extraction profile JSON

**Files:**
- Create: `scripts/audit/profiles/meta-analysis-2026-05-22.json`

- [ ] **Step 1: Write the profile JSON**

```json
{
  "profile_name": "meta-analysis-2026-05-22",
  "description": "Internal corpus snapshot for Phase 1 meta-analysis refresh — L0/L1 inputs only. NOT for external auditor.",
  "inherits_from": "base",
  "globs": [
    ".claude/features/*/state.json",
    ".claude/shared/integrity-checkpoint-ledger.jsonl",
    ".claude/shared/integrity-checkpoint-ledger.md",
    ".claude/shared/gate-coverage-weekly.jsonl",
    ".claude/logs/gate-coverage.jsonl"
  ],
  "additional_state_snapshot_features": []
}
```

- [ ] **Step 2: Verify profile loads without error**

Run: `python3 -c "from scripts.audit.profile import load_profile; print(load_profile('meta-analysis-2026-05-22').profile_name)"`
Expected: `meta-analysis-2026-05-22`

- [ ] **Step 3: Generate the extraction bundle**

Run: `make audit-bundle PROFILE=meta-analysis-2026-05-22`
Expected: bundle.md + manifest.json + redaction-log.json written to `docs/audits/runs/<timestamp>/`; SHA256 emitted.

- [ ] **Step 4: Record the bundle SHA256 + file count for L0/L1 use**

Run: `ls -lh docs/audits/runs/ | tail -1 && python3 -c "import json; m=json.load(open('$(ls -td docs/audits/runs/*/ | head -1)manifest.json')); print('files:', len(m['files']))"`
Note the SHA256 and file count — these go into L0 §1 + L1 §2.

- [ ] **Step 5: Commit the profile**

```bash
git add scripts/audit/profiles/meta-analysis-2026-05-22.json
git commit -m "feat(audit): meta-analysis-2026-05-22 extraction profile

Profile for Phase 1 meta-analysis L0/L1 corpus snapshot. Inherits
from base, adds state.json + integrity ledgers + gate-coverage logs.
Internal-only — never staged to external auditor.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Write L2 prompt of record (§6.5)

**Files:**
- Create: `docs/audits/prompts/03-meta-analysis-l2-extraction-prompt.md`

- [ ] **Step 1: Write the prompt file**

```markdown
# L2 File A Extraction Prompt (Meta-Analysis Phase 1 — Prompt of Record)

> Spec: [`docs/superpowers/specs/2026-05-22-meta-analysis-refresh-phase-1-design.md`](../superpowers/specs/2026-05-22-meta-analysis-refresh-phase-1-design.md) §6.5
> This prompt generates the AUDITOR-FACING file `2026-05-22-l2-audit-prep-claims-v7-9-1.md`. Reproducible by any operator (human or Claude).

## Inputs you have

1. The L0 extraction bundle at `docs/audits/runs/<timestamp>/bundle.md` (SHA256 stamped, deterministic)
2. The L0 delta doc at `docs/case-studies/meta-analysis/2026-05-22-l0-delta-vs-anchor.md`
3. The L1 cohort analysis at `docs/case-studies/meta-analysis/2026-05-22-l1-extended-cohort-analysis.md`
4. The L2 internal sidecar (File B) at `docs/case-studies/meta-analysis/2026-05-22-l2-internal-sidecar.md`

## Hard rules (NEVER violate)

1. **Pure data.** Every claim is a STATEMENT OF FACT extractable from cited evidence paths. Forbidden words in claim_text: `we believe`, `we expect`, `we think`, `we hope`, `unfortunately`, `concerning`, `promising`, `surprisingly`, `good`, `bad`, `better than`, `worse than`, `improved`. No first-person framing. No editorializing.
2. **Resolved evidence.** Every `evidence_paths` value MUST be a real file in the bundle (test before writing).
3. **Schema-only.** The only allowed fields are `id`, `audit_profile_section`, `claim_text`, `evidence_paths`. No `internal_confidence`, no `expected_auditor_finding`, no `notes` — those go in File B.
4. **No prose between claims.** The doc body is the YAML list and a single intro line citing the L0 bundle SHA256. Nothing else.
5. **Refuse interpretation requests.** If asked to add commentary, return: "REFUSED — File A is auditor-facing and must remain pure data per spec §6.4. Commentary belongs in File B (internal sidecar). To add it, edit File B at `docs/case-studies/meta-analysis/2026-05-22-l2-internal-sidecar.md`."

## Output structure

```markdown
# L2 — Audit-Prep Claim Ledger (File A, auditor-facing)

> Generated from L0 extraction bundle SHA256: `<paste the bundle SHA256 from L0 §1>`
> Companion internal sidecar: see [`2026-05-22-l2-internal-sidecar.md`](2026-05-22-l2-internal-sidecar.md) (NOT staged to external auditor)

\`\`\`yaml
- id: C-001
  audit_profile_section: <section name>
  claim_text: <statement of fact>
  evidence_paths:
    - <path>
    - <path>
- id: C-002
  ...
\`\`\`
```

## Minimum count

≥30 claims. Cover at least: BRANCH_ISOLATION promotion, FEATURE_CLOSURE_COMPLETENESS promotion, v7.9 Phase E telemetry, HADF Phase 2 closure, UCC passkey-auth cutover, framework-honesty-ledger entries.
```

- [ ] **Step 2: Verify the prompt file passes the existing prompt-linter**

Run: `python3 scripts/audit/check_prompts.py`
Expected: no errors flagged for the new file (the linter checks for placeholders + required sections).

- [ ] **Step 3: Commit the prompt**

```bash
git add docs/audits/prompts/03-meta-analysis-l2-extraction-prompt.md
git commit -m "feat(audit): L2 File A prompt of record (spec §6.5)

Documents the 5 impartiality rules + refusal template for the L2
auditor-facing claim ledger. Reproducible by any operator.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Draft L0 §1-§2 (corpus growth + framework arc)

**Files:**
- Create: `docs/case-studies/meta-analysis/2026-05-22-l0-delta-vs-anchor.md`

- [ ] **Step 1: Write the doc header + §1 corpus growth**

```markdown
# L0 — Delta vs 2026-04-21 Anchor

> **Date:** 2026-05-22
> **Phase:** 1 of 3 (meta-analysis refresh)
> **Spec:** [`docs/superpowers/specs/2026-05-22-meta-analysis-refresh-phase-1-design.md`](../../superpowers/specs/2026-05-22-meta-analysis-refresh-phase-1-design.md)
> **Anchor:** [`meta-analysis-2026-04-21.md`](meta-analysis-2026-04-21.md)
> **Extraction bundle SHA256:** `<paste from Task 1 Step 4>`

## 1. Corpus growth

| Metric | 2026-04-21 anchor | 2026-05-22 (today) | Δ |
|---|---:|---:|---:|
| Case studies in `docs/case-studies/*.md` | 41 (T1) | 83 (T1) | +42 |
| Meta-analysis sub-docs in `docs/case-studies/meta-analysis/` | 4 (T1) | 11 (T1) | +7 |
| Features in `.claude/features/*/` | ~24 (T1) | <measure via `ls .claude/features/ \| wc -l`> (T1) | <compute> |
| Published showcase MDX in `fitme-story/content/04-case-studies/` | 24 (T2) | 25 (T1) | +1 |
```

- [ ] **Step 2: Measure the actual n=features and add the row**

Run: `ls .claude/features/ | wc -l`
Replace the `<measure>` and `<compute>` placeholders with the real values.

- [ ] **Step 3: Write §2 framework arc**

```markdown
## 2. Framework version arc since anchor

| Version | Ship date | What shipped (one-liner) | PR |
|---|---|---|---|
| v7.5 | 2026-04-24 | 8 cooperating defenses post-Gemini audit | PR #139 |
| v7.6 | 2026-04-25 | Mechanical enforcement (4 Class B→A) + per-PR + weekly | PR #141 |
| v7.7 | 2026-04-27 | Validity closure (5 new gates + framework-health dashboard) | PR #144 |
| v7.8 (bridge) | 2026-05-04 | Mechanisms A-F (advisory) | PR #173/#185-189/#193-195 |
| v7.8.1 | 2026-05-07 | Branch isolation + feature closure (advisory) | PR #244 |
| v7.8.2 | 2026-05-08 | Cross-repo gate asymmetry documented disposition | PR #258 |
| v7.8.3 | 2026-05-11 | Cross-repo state sync impl Phase 0 (V2+V9 enforced) | PR #298 |
| v7.8.4 | 2026-05-12 | Calibration patch + PR cache freshness gate | PR #314 |
| v7.8.5 | 2026-05-13 | Observed Patterns Catalog + W9 branch drift alert | PR #328+#341 |
| v7.8.6 | 2026-05-15 | Cadence batch (preflight + integrity-diff + weekly Mech A) | PR #363+#365 |
| v7.9 | 2026-05-21 | 3 gates flipped advisory→enforced | PR #417 |
```

- [ ] **Step 4: Commit progress (incremental, partial L0 is OK)**

```bash
git add docs/case-studies/meta-analysis/2026-05-22-l0-delta-vs-anchor.md
git commit -m "wip(meta-analysis): L0 §1-§2 (corpus growth + framework arc)

Phase 1 Task 3 partial commit.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Draft L0 §3-§4 (new gates + anchor limitations status)

**Files:**
- Modify: `docs/case-studies/meta-analysis/2026-05-22-l0-delta-vs-anchor.md` (append §3 + §4)

- [ ] **Step 1: Compute gate count delta**

Run: `grep -c "^def check_" scripts/check-state-schema.py 2>/dev/null; grep -cE "^(CHECK_|check_)" scripts/integrity-check.py 2>/dev/null`
Use the counts to populate §3.

- [ ] **Step 2: Append §3 new gates inventory**

```markdown
## 3. New gates inventory since anchor

| Gate category | 2026-04-21 | 2026-05-22 | New |
|---|---:|---:|---|
| Write-time pre-commit gates | 4 (T1) | <count from grep> (T1) | <list new gate names> |
| Cycle-time integrity check codes | 13 (T1) | 16 (T1) | BRANCH_ISOLATION_HISTORICAL, BRANCH_ISOLATION_LAUNCHD_DRIFT, FEATURE_CLOSURE_COMPLETENESS mirror |
| Mechanism A coverage telemetry | 0 (T1) | 1 (T1) | gate-coverage.jsonl emission across all gates |
| Mechanism E append-only merge driver | 0 (T1) | 2 (T1) | measurement-adoption-history.json, documentation-debt.json, gate-coverage.jsonl, .claude/logs/*.log.json |

Totals (per CLAUDE.md "Data Integrity Framework"): 18 → 37+ mechanical gates, 0 → 5 advisories.
```

- [ ] **Step 3: Append §4 anchor limitations status**

```markdown
## 4. Anchor §16 limitations — status

Per spec §4:

| # | Anchor limitation | Phase 1 response | Status |
|---|---|---|---|
| 1 | Sample size n=41 | n=83 (full corpus) | **CLOSED** |
| 2 | No framework-version cohort comparison | L1 NEW §17 | **CLOSED** |
| 3 | No cross-repo split FT2↔fitme-story | L1 NEW §18 | **CLOSED** |
| 4 | Gemini audit then-pending | Folded into L1 §17 as v7.0→v7.5 inflection | **CLOSED** |
| 5 | Self-referential bias (same author) | Anchor #2 (external auditor) is the closure | OPEN (Phase 3 reconciliation) |
| 6 | No statistical significance testing | n still too small per cohort | OPEN (will close at n=200+) |
| 7 | No reader-comprehension validation | Not in Phase 1 scope | OPEN (deferred) |
```

- [ ] **Step 4: Commit progress**

```bash
git add docs/case-studies/meta-analysis/2026-05-22-l0-delta-vs-anchor.md
git commit -m "wip(meta-analysis): L0 §3-§4 (new gates + anchor limitations status)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Finish L0 §5-§6 + commit complete L0

**Files:**
- Modify: `docs/case-studies/meta-analysis/2026-05-22-l0-delta-vs-anchor.md` (append §5 + §6)

- [ ] **Step 1: List new meta-analysis sub-docs since anchor**

Run: `git log --since='2026-04-22' --diff-filter=A --name-only docs/case-studies/meta-analysis/ | grep '\.md$' | sort -u`

- [ ] **Step 2: Append §5 new sub-docs**

```markdown
## 5. New meta-analysis sub-docs since anchor

| Doc | Date | Type |
|---|---|---|
| v7-5-advancement-report.md | 2026-04-24 | Internal |
| unclosable-gaps.md | 2026-04-27 | Internal |
| ci-env-flake-research-2026-05-05.md | 2026-05-05 | Internal research |
| v7-9-measurement-window-2026-05-11.md | 2026-05-11 | Internal |
| cache-hits-backfill-draft-2026-05-18.md | 2026-05-18 | Internal |
| kill-criteria-resolution-backfill-decision-2026-05-18.md | 2026-05-18 | Internal |
| tier-tag-checker-baseline.md | 2026-05-XX | Internal |

Plus 2 case-study-level meta-analyses (predate anchor but worth re-flagging): [`meta-analysis-full-system-audit-v7.0-case-study.md`](../meta-analysis-full-system-audit-v7.0-case-study.md), [`meta-analysis-audit-and-remediation-case-study.md`](../meta-analysis-audit-and-remediation-case-study.md).
```

- [ ] **Step 3: Append §6 pointer to L1/L2**

```markdown
## 6. Where to go next

- [L1 — Extended cohort analysis](2026-05-22-l1-extended-cohort-analysis.md) — the main analytical work, replicates anchor §1-§16 + 2 new dimensions
- [L2 File A — Audit-prep claim ledger (auditor-facing)](2026-05-22-l2-audit-prep-claims-v7-9-1.md) — staged into Audit #2 claude-bundle on 2026-06-08
- [L2 File B — Internal sidecar](2026-05-22-l2-internal-sidecar.md) — working notes, NEVER staged externally
```

- [ ] **Step 4: Verify L0 is ~80 lines**

Run: `wc -l docs/case-studies/meta-analysis/2026-05-22-l0-delta-vs-anchor.md`
Expected: 70-100 lines (target ~80).

- [ ] **Step 5: Commit L0 complete**

```bash
git add docs/case-studies/meta-analysis/2026-05-22-l0-delta-vs-anchor.md
git commit -m "feat(meta-analysis): L0 delta vs anchor (complete)

Phase 1 L0 ships. Quantifies corpus delta (n=41 → n=83), framework
version arc (v7.0 → v7.9, 10 patches), new gates (18 → 37+),
anchor §16 limitations status (4 CLOSED + 3 OPEN with reasons).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: Draft L1 §1-§5 (foundational sections, replicating anchor structure)

**Files:**
- Create: `docs/case-studies/meta-analysis/2026-05-22-l1-extended-cohort-analysis.md`

- [ ] **Step 1: Write L1 header + §1-§5 mirroring anchor**

```markdown
# L1 — Extended Cohort Analysis (n=83)

> **Date:** 2026-05-22
> **Phase:** 1 of 3 (meta-analysis refresh)
> **Anchor:** [`meta-analysis-2026-04-21.md`](meta-analysis-2026-04-21.md) (n=41)
> **Spec:** [`docs/superpowers/specs/2026-05-22-meta-analysis-refresh-phase-1-design.md`](../../superpowers/specs/2026-05-22-meta-analysis-refresh-phase-1-design.md) §5.2
> **Extraction bundle SHA256:** `<paste from L0 §1>`
> **Convention:** Every quantitative claim T1/T2/T3 tagged per [`data-quality-tiers.md`](../data-quality-tiers.md).

## 1. Scope

Corpus at extraction time (2026-05-22T06:36Z bundle):
- 83 case studies in `docs/case-studies/*.md` (T1)
- 11 meta-analysis sub-docs in `docs/case-studies/meta-analysis/` (T1)
- <N> features in `.claude/features/*/` (T1, paste count from L0 §1)
- 25 published showcase MDX in fitme-story (T1)

## 2. Extraction method

Reused [`scripts/audit/build_bundle.py`](../../../scripts/audit/build_bundle.py) with profile `meta-analysis-2026-05-22` (committed in Task 1). The profile inherits from `base.json` and adds state.json + integrity ledgers + gate-coverage logs. Bundle SHA256 is deterministic — rerunning produces an identical hash unless the corpus changes.
```

- [ ] **Step 2: Continue with §3-§5 (Corpus aggregates, Work-type, Dispatch-pattern)**

For each section, mirror anchor's structure. Pull the actual numbers from the bundle. Each section ~20-40 lines.

```markdown
## 3. Corpus aggregates

| Metric | Value | Tier |
|---|---:|---|
| Total case studies | 83 | T1 |
| Total bytes (sum) | <compute> | T1 |
| Median lines per case study | <compute> | T1 |
| Median age (days since date_written) | <compute> | T1 |

## 4. Work-type distribution

Replicate anchor §4 structure on n=83. Example shape:

| work_type | n | % |
|---|---:|---:|
| feature | <count> | <%> |
| chore | <count> | <%> |
| enhancement | <count> | <%> |
| fix | <count> | <%> |
| (missing) | <count> | <%> |

## 5. Dispatch-pattern distribution

Same pattern for `dispatch_pattern` field. Surface frequency of `serial`, `parallel`, `4-layer risk-weighted parallel sweep`, etc.
```

- [ ] **Step 3: Commit progress**

```bash
git add docs/case-studies/meta-analysis/2026-05-22-l1-extended-cohort-analysis.md
git commit -m "wip(meta-analysis): L1 §1-§5 (foundational sections)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: Draft L1 §6-§10 (coverage + reconciliation sections)

**Files:**
- Modify: `docs/case-studies/meta-analysis/2026-05-22-l1-extended-cohort-analysis.md` (append §6-§10)

- [ ] **Step 1: Write §6 (Phase-doc coverage), §7 (Structural anomalies), §8 (Metrics sections coverage)**

For each, follow anchor's structure but on n=83 data. Compute coverage as `(features with field non-empty) / (total features)`.

```markdown
## 6. Phase-documentation coverage

Per `state.json::phases.<phase>.note` presence:

| Phase | features w/ note | features total | coverage |
|---|---:|---:|---:|
| research | <count> | <N> | <%> |
| prd | <count> | <N> | <%> |
| ... (all 9 phases) | | | |

## 7. Structural anomalies

Replicate anchor §7 (audit-v2-gN stub group). Check if any new stub groups emerged since anchor.

## 8. Metrics sections coverage

| Field | features w/ non-empty | features total | coverage |
|---|---:|---:|---:|
| success_metrics | <count> | <N> | <%> |
| kill_criteria | <count> | <N> | <%> |
| kill_criteria_resolution (when KC set) | <count> | <N_KC> | <%> |
| cache_hits[] (post-v6) | <count> | <N_post_v6> | <%> |
| cu_v2 | <count> | <N> | <%> |
```

- [ ] **Step 2: Write §9 (PR citation verification) + §10 (state.json reconciliation)**

```markdown
## 9. PR citation verification

Anchor §9: every case study referencing `PR #N` was verified against `gh pr list`. Replicate using `scripts/refresh-pr-cache.py`-cached results.

| Repo | Total PR citations | Resolved | Unresolved |
|---|---:|---:|---:|
| FT2 | <count> | <count> | <count> |
| fitme-story | <count> | <count> | <count> |

## 10. state.json reconciliation

Anchor §10: ratio of features whose state.json matches the case study claim (phases, PRs, dates).

| Check | passing | total | coverage |
|---|---:|---:|---:|
| state.case_study_path resolves to existing file | <count> | <N> | <%> |
| state.tasks PR numbers match case study body | <count> | <N> | <%> |
| state.current_phase matches case study header | <count> | <N> | <%> |
```

- [ ] **Step 3: Commit progress**

```bash
git add docs/case-studies/meta-analysis/2026-05-22-l1-extended-cohort-analysis.md
git commit -m "wip(meta-analysis): L1 §6-§10 (coverage + reconciliation)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 8: Draft L1 §11-§13 (version distribution + failure density + showcase mapping)

**Files:**
- Modify: `docs/case-studies/meta-analysis/2026-05-22-l1-extended-cohort-analysis.md` (append §11-§13)

- [ ] **Step 1: Write §11 framework-version citation distribution**

```markdown
## 11. Framework-version citation distribution

| framework_version cited in state.json | count | % |
|---|---:|---:|
| v1.x | <count> | <%> |
| v2.x-v4.x | <count> | <%> |
| v5.x | <count> | <%> |
| v6.x | <count> | <%> |
| v7.0-v7.4 | <count> | <%> |
| v7.5-v7.7 | <count> | <%> |
| v7.8-v7.9 | <count> | <%> |
| (missing) | <count> | <%> |
```

- [ ] **Step 2: Write §12 failure/pivot density**

```markdown
## 12. Failure / pivot density

Count features with `phases.<phase>.status: failed` OR `phases.<phase>.pivot_reason` non-empty.

| Phase | failed | pivoted | total |
|---|---:|---:|---:|
| research | <count> | <count> | <N> |
| prd | <count> | <count> | <N> |
| ... | | | |
```

- [ ] **Step 3: Write §13 showcase↔main mapping**

```markdown
## 13. Showcase ↔ main-repo mapping (Corpus B vs A)

| Status | count |
|---|---:|
| Case study EXISTS + Showcase MDX EXISTS | <count> (T1) |
| Case study EXISTS + Showcase MDX MISSING | <count> (T1) |
| Showcase MDX EXISTS + Case study MISSING | 0 expected (T1) |
| chronological_order_violations | <count> (T2 — manual check) |
```

- [ ] **Step 4: Commit progress**

```bash
git add docs/case-studies/meta-analysis/2026-05-22-l1-extended-cohort-analysis.md
git commit -m "wip(meta-analysis): L1 §11-§13 (versions + failure + showcase mapping)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 9: Draft L1 §14-§16 (summary + prior comparison + limitations)

**Files:**
- Modify: `docs/case-studies/meta-analysis/2026-05-22-l1-extended-cohort-analysis.md` (append §14-§16)

- [ ] **Step 1: Write §14 summary of findings (pure restatement, no editorial)**

```markdown
## 14. Summary of findings (pure restatement of data above)

§3: n=83. §4: work_type distribution shows <restate top 3>. §5: dispatch_pattern shows <restate top 2>. §6: phase-documentation coverage averages <%>. §7: <0 OR list new structural anomalies>. §8: metrics-section coverage averages <%>. §9: PR citation resolution rate <%>. §10: state.json↔case-study reconciliation rate <%>. §11: framework-version distribution skews toward <which buckets>. §12: failure density <%>. §13: showcase mapping completeness <%>.

No editorializing. No "good" / "bad" / "concerning". Just restatement.
```

- [ ] **Step 2: Write §15 comparison against prior meta-analyses**

```markdown
## 15. Comparison against prior meta-analyses

| Metric | 2026-04-16 (Nemotron) | 2026-04-16 (what-if) | 2026-04-21 (anchor) | 2026-05-22 (this doc) |
|---|---:|---:|---:|---:|
| n (case studies) | ~30 | 24 | 41 | 83 |
| Cohort dimensions | 0 | 1 (work-type) | 5 | 7 (anchor 5 + framework-version + cross-repo) |
| External validation? | partial (Nvidia) | no | no (Gemini followed 5d later) | pending (Audit #2 in 21d) |
```

- [ ] **Step 3: Write §16 limitations (anchor's §16 + Phase 1-specific)**

```markdown
## 16. Limitations

Anchor §16 status:
- L1 (sample size) — CLOSED (n=83)
- L2 (framework-version cohort) — CLOSED (NEW §17)
- L3 (cross-repo split) — CLOSED (NEW §18)
- L4 (Gemini then-pending) — CLOSED (folded into §17)
- L5 (self-referential bias) — OPEN (Audit #2 in 21d is the closure)
- L6 (no significance testing) — OPEN (n per cohort still <15)
- L7 (no reader-comprehension validation) — OPEN

New L1-2026-05-22 limitations:
- L8: §17 framework-version cohort boundaries are author-chosen (5 buckets); other groupings (e.g., by month, by major version only) would yield different rates
- L9: §18 cross-repo split treats fitme-story as a single repo, but it has multiple sub-areas (control-room, case-studies, framework pages) that could have different hygiene
- L10: §11 framework_version count assumes the state.json field is correctly populated (the field itself was backfilled in PR #185+#186; pre-backfill data is recovered, not original)
```

- [ ] **Step 4: Commit progress**

```bash
git add docs/case-studies/meta-analysis/2026-05-22-l1-extended-cohort-analysis.md
git commit -m "wip(meta-analysis): L1 §14-§16 (summary + comparison + limitations)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 10: Draft L1 NEW §17 (framework-version cohort)

**Files:**
- Modify: `docs/case-studies/meta-analysis/2026-05-22-l1-extended-cohort-analysis.md` (append §17)

- [ ] **Step 1: Write §17 framework-version cohort**

```markdown
## 17. NEW — Framework-version cohort analysis

Group features by ship-version into 5 non-overlapping buckets, then measure adoption rates of 5 framework fields per cohort.

### 17.1 Cohort definitions

| Cohort | Ship-version range | n |
|---|---|---:|
| pre-v6 | v1.x-v5.x | <count from §11> |
| v6.0-v6.x | v6.0, v6.1 | <count> |
| v7.0-v7.4 | v7.0-v7.4 | <count> |
| v7.5-v7.7 | v7.5, v7.6, v7.7 | <count> |
| v7.8-v7.9 | v7.8, v7.8.1-v7.8.6, v7.9 | <count> |
| (unknown) | missing framework_version | <count> |

### 17.2 Adoption rates per cohort

Each field becomes mandatory at a specific version. Cohorts that shipped BEFORE the mandatory version are NOT expected to comply (shown as `n/a`).

| Field | mandatory from | pre-v6 | v6.0-v6.x | v7.0-v7.4 | v7.5-v7.7 | v7.8-v7.9 |
|---|---|---:|---:|---:|---:|---:|
| cache_hits[] non-empty | v6.0 | n/a | <%> | <%> | <%> | <%> |
| kill_criteria_resolution when KC set | v7.8.1 | n/a | n/a | n/a | n/a | <%> |
| state_owner present | v7.8.3 | n/a | n/a | n/a | n/a | <%> |
| cu_v2 schema-valid | v7.7 | n/a | n/a | n/a | <%> | <%> |
| tier-tag in case study body | 2026-04-21 (post-anchor) | <%> | <%> | <%> | <%> | <%> |

### 17.3 Observations (pure restatement)

For each cell in 17.2 below 100% in the "mandatory from" cohort, list the feature names. No editorializing.
```

- [ ] **Step 2: Commit progress**

```bash
git add docs/case-studies/meta-analysis/2026-05-22-l1-extended-cohort-analysis.md
git commit -m "wip(meta-analysis): L1 NEW §17 (framework-version cohort)

Closes anchor limitation L2.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 11: Draft L1 NEW §18 (cross-repo split)

**Files:**
- Modify: `docs/case-studies/meta-analysis/2026-05-22-l1-extended-cohort-analysis.md` (append §18)

- [ ] **Step 1: Write §18 cross-repo split**

```markdown
## 18. NEW — Cross-repo split (FT2 vs fitme-story)

Partition features by `state.json::state_owner`. Compare doc-debt field-presence rates per repo. Quantifies the v7.8.2 documented-disposition decision empirically.

### 18.1 Cohort split

| state_owner | n |
|---|---:|
| ft2 | <count> |
| fitme-story | <count> |
| (missing) | <count, pre-v7.8.3 — should be 0 post-backfill> |

### 18.2 Doc-debt field-presence per repo

| Field | ft2 coverage | fitme-story coverage |
|---|---:|---:|
| success_metrics | <%> | <%> |
| kill_criteria | <%> | <%> |
| kill_criteria_resolution (when KC set) | <%> | <%> |
| cache_hits[] (post-v6) | <%> | n/a (Mechanism A is FT2-only per v7.8.2 spec) |
| cu_v2 | <%> | <%> |
| tier-tags | <%> | <%> |

### 18.3 Per-rule asymmetry call-outs

For each row in 18.2 where the gap exceeds 20 percentage points, list the FT2 features that have the field vs the fitme-story features that don't (or vice versa). No editorializing.

### 18.4 v7.8.2 disposition validation

The v7.8.2 spec (2026-05-08) documented Mechanism A's FT2-only scope. §18.2 shows whether the asymmetry caused measurable harm in adoption rates of OTHER fields (success_metrics, kill_criteria, etc.) — fields that ARE expected to be present in both repos.
```

- [ ] **Step 2: Commit progress**

```bash
git add docs/case-studies/meta-analysis/2026-05-22-l1-extended-cohort-analysis.md
git commit -m "wip(meta-analysis): L1 NEW §18 (cross-repo split FT2 vs fitme-story)

Closes anchor limitation L3.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 12: Draft L1 NEW §19 (Phase 1 limitations) + commit complete L1

**Files:**
- Modify: `docs/case-studies/meta-analysis/2026-05-22-l1-extended-cohort-analysis.md` (append §19)

- [ ] **Step 1: Write §19 Phase 1-specific limitations**

```markdown
## 19. NEW — Phase 1 limitations + handoff to Audit #2

L1 has the same self-referential bias as the anchor: same author, same project, same definitions. The closure for that bias is External Audit #2 (2026-06-12), which receives L2 File A as its claim ledger and produces an impartial finding set.

If Audit #2 finds:
- A discrepancy in L1 numbers → fix L0/L1 + open Honesty Ledger entry
- A discrepancy in L2 File A → fix File A + restage to claude-bundle (if pre-audit) OR Honesty Ledger entry (if post-audit)
- Both views agreeing on the same claim → validation; record as `confirmed_by_external_auditor_2026-06-12` in the L2 File B sidecar

Phase 1's success is NOT defined by "auditor finds nothing". Phase 1's success is defined by §10 of the spec.
```

- [ ] **Step 2: Verify L1 is ~400 lines**

Run: `wc -l docs/case-studies/meta-analysis/2026-05-22-l1-extended-cohort-analysis.md`
Expected: 350-450 lines (target ~400).

- [ ] **Step 3: Commit L1 complete**

```bash
git add docs/case-studies/meta-analysis/2026-05-22-l1-extended-cohort-analysis.md
git commit -m "feat(meta-analysis): L1 extended cohort analysis (complete)

Phase 1 L1 ships. Replicates 2026-04-21 anchor §1-§16 on n=83 corpus
+ 2 new dimensions (§17 framework-version cohort, §18 cross-repo
split) + §19 Phase 1 limitations + handoff to Audit #2.

Closes anchor §16 limitations L1-L4 (n=41→83, framework-version
cohort, cross-repo split, Gemini-then-pending folded in). L5-L7 stay
open (self-referential bias closes via Audit #2; statistical
significance + reader-comprehension out of scope).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 13: Draft L2 File B (internal sidecar) first

**Files:**
- Create: `docs/case-studies/meta-analysis/2026-05-22-l2-internal-sidecar.md`

We write File B BEFORE File A because File B contains the working notes; File A is then derived from File B by stripping the non-data fields.

- [ ] **Step 1: Write File B header + ≥30 entries**

```markdown
# L2 — Audit-Prep Claim Ledger (File B, internal sidecar)

> Generated: 2026-05-22
> Companion: [File A — auditor-facing](2026-05-22-l2-audit-prep-claims-v7-9-1.md)
> Per spec §5.3: This file is INTERNAL-ONLY. NEVER staged into `docs/audits/external/*/claude-bundle/`. Contains working notes (confidence + predicted findings + caveats) that pair with each claim_id in File A.

\`\`\`yaml
- id: C-001
  internal_confidence: high
  expected_auditor_finding: "Likely confirms; Mechanism A telemetry is published"
  notes: "Evidence-rich; bundle includes 14d gate-coverage.jsonl"

- id: C-002
  internal_confidence: high
  expected_auditor_finding: "Likely confirms via state.json + PR #417 hash"
  notes: ""

- id: C-003
  ...
\`\`\`
```

- [ ] **Step 2: Source 30+ claim IDs from L1 findings + post-v7.9 candidates**

For each claim, draft the File B entry first. Source list:
- C-001 to C-010: framework gate promotions (BRANCH_ISOLATION B+C, FEATURE_CLOSURE_COMPLETENESS, etc.)
- C-011 to C-018: HADF Phase 2 closure + Phase 2-bis Block A
- C-019 to C-024: UCC passkey-auth cutover + hardening
- C-025 to C-028: Cross-repo state sync impl Phases 0-2
- C-029 to C-032: Framework-honesty-ledger entries (FT2-FH-001, FT2-FH-002, FT2-FH-003)
- C-033+: any further claims surfaced by L1

- [ ] **Step 3: Verify File B is ~80 lines**

Run: `wc -l docs/case-studies/meta-analysis/2026-05-22-l2-internal-sidecar.md`
Expected: 70-100 lines (target ~80).

- [ ] **Step 4: Commit File B**

```bash
git add docs/case-studies/meta-analysis/2026-05-22-l2-internal-sidecar.md
git commit -m "feat(meta-analysis): L2 File B internal sidecar (≥30 entries)

Working notes + confidence + predicted findings for each claim_id.
INTERNAL ONLY — never staged externally per spec §5.3.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 14: Generate L2 File A from File B per the prompt of record

**Files:**
- Create: `docs/case-studies/meta-analysis/2026-05-22-l2-audit-prep-claims-v7-9-1.md`

- [ ] **Step 1: Read the prompt of record (Task 2 output)**

Run: `cat docs/audits/prompts/03-meta-analysis-l2-extraction-prompt.md`
This is the prompt that governs File A generation. Follow the hard rules verbatim.

- [ ] **Step 2: Write File A header (single intro line + YAML)**

```markdown
# L2 — Audit-Prep Claim Ledger (File A, auditor-facing)

> Generated from L0 extraction bundle SHA256: `<paste bundle SHA256 from L0 §1>`
> Companion internal sidecar: see [`2026-05-22-l2-internal-sidecar.md`](2026-05-22-l2-internal-sidecar.md) (NOT staged to external auditor)

\`\`\`yaml
- id: C-001
  audit_profile_section: "v7.9 gate promotion"
  claim_text: "BRANCH_ISOLATION_VIOLATION (Mode B + Mode C) and FEATURE_CLOSURE_COMPLETENESS were promoted from advisory to enforced via PR #417 on 2026-05-21"
  evidence_paths:
    - scripts/check-state-schema.py
    - docs/case-studies/framework-v7-9-promotion-case-study.md
    - .claude/logs/gate-coverage.jsonl

- id: C-002
  audit_profile_section: "v7.9 promotion criteria"
  claim_text: "14-day Mechanism A telemetry window (2026-05-07 to 2026-05-21) emitted 18 BRANCH_ISOLATION_VIOLATION Mode B rows, 13 Mode C rows, and 13 FEATURE_CLOSURE_COMPLETENESS rows"
  evidence_paths:
    - .claude/logs/gate-coverage.jsonl
    - docs/case-studies/framework-v7-9-promotion-case-study.md
\`\`\`
```

- [ ] **Step 3: Continue with claims C-003 through C-030+ derived from File B**

For each File B entry (Task 13 Step 2), write the corresponding File A entry by:
- Copy `id` from File B
- Set `audit_profile_section` (matches the audit #2 v7-9-1-f16-plus-hadf profile sections)
- Write `claim_text` as a pure statement of fact (no editorializing words per prompt rule 1)
- List `evidence_paths` (verified to resolve per prompt rule 2)

- [ ] **Step 4: Verify File A is ~200 lines**

Run: `wc -l docs/case-studies/meta-analysis/2026-05-22-l2-audit-prep-claims-v7-9-1.md`
Expected: 180-230 lines (target ~200, 30+ claims × ~6 lines each + header).

- [ ] **Step 5: Commit File A draft**

```bash
git add docs/case-studies/meta-analysis/2026-05-22-l2-audit-prep-claims-v7-9-1.md
git commit -m "feat(meta-analysis): L2 File A draft (≥30 claims, pre-validation)

Auditor-facing claim ledger generated per prompt of record
(docs/audits/prompts/03-meta-analysis-l2-extraction-prompt.md).
Pre-validation; Task 15 runs impartiality contract + redaction
checks before staging.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 15: Impartiality contract validation (spec §6.4 rules 1+3+4)

**Files:**
- Read: `docs/case-studies/meta-analysis/2026-05-22-l2-audit-prep-claims-v7-9-1.md`

- [ ] **Step 1: Rule 1 — forbidden-word grep**

Run:
```bash
grep -iE "(^|[^a-z])(we (believe|expect|think|hope|feel|suspect)|unfortunately|concerning|promising|surprisingly|good|bad|better than|worse than|improved|degraded)([^a-z]|$)" docs/case-studies/meta-analysis/2026-05-22-l2-audit-prep-claims-v7-9-1.md
```
Expected: zero output. If matches: edit File A to remove the editorializing word; rerun.

- [ ] **Step 2: Rule 1 — forbidden field check (internal_confidence + expected_auditor_finding + notes)**

Run:
```bash
grep -E "^[[:space:]]*(internal_confidence|expected_auditor_finding|notes):" docs/case-studies/meta-analysis/2026-05-22-l2-audit-prep-claims-v7-9-1.md
```
Expected: zero output. If matches: move those entries to File B + remove from File A.

- [ ] **Step 3: Rule 4 — internal-sidecar leakage check**

Run:
```bash
grep -E "2026-05-22-l2-internal-sidecar" docs/case-studies/meta-analysis/2026-05-22-l2-audit-prep-claims-v7-9-1.md
```
Expected: exactly ONE match — the intro line that says "NOT staged to external auditor". If more: a body claim is referencing the sidecar — remove it.

- [ ] **Step 4: Claim count check (≥30)**

Run:
```bash
grep -cE "^- id: C-" docs/case-studies/meta-analysis/2026-05-22-l2-audit-prep-claims-v7-9-1.md
```
Expected: ≥30. If less: add claims from File B until ≥30.

- [ ] **Step 5: Commit any fixes**

```bash
git add docs/case-studies/meta-analysis/2026-05-22-l2-audit-prep-claims-v7-9-1.md
git commit -m "fix(meta-analysis): L2 File A impartiality contract pass

§6.4 rules 1+3+4 validated:
- Zero forbidden words (we believe/expect/think/hope, etc.)
- Zero forbidden fields (internal_confidence/expected/notes)
- Zero internal-sidecar leakage in body
- ≥30 claims confirmed

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 16: Evidence path resolution check (spec §6.4 rule 2)

**Files:**
- Read: `docs/case-studies/meta-analysis/2026-05-22-l2-audit-prep-claims-v7-9-1.md`

- [ ] **Step 1: Extract every evidence path from File A**

Run:
```bash
python3 - <<'EOF'
import re, sys
text = open('docs/case-studies/meta-analysis/2026-05-22-l2-audit-prep-claims-v7-9-1.md').read()
paths = re.findall(r'^\s*-\s+([^#\s][^\s]+)$', text, re.MULTILINE)
# filter for evidence_paths context (lines after "evidence_paths:")
in_ep = False
out = []
for line in text.splitlines():
    if 'evidence_paths:' in line:
        in_ep = True
    elif re.match(r'^- id:', line):
        in_ep = False
    elif in_ep and re.match(r'^\s+-\s+\S', line):
        out.append(line.strip()[2:])
print('\n'.join(out))
EOF
```
Save output to `/tmp/l2-evidence-paths.txt`.

- [ ] **Step 2: Verify each path resolves**

Run:
```bash
missing=0
while IFS= read -r p; do
  [ -e "$p" ] || { echo "MISSING: $p"; missing=$((missing+1)); }
done < /tmp/l2-evidence-paths.txt
echo "Total missing: $missing"
```
Expected: `Total missing: 0`. If non-zero: fix each missing path in File A (correct typo, update path, or remove the claim if evidence doesn't exist).

- [ ] **Step 3: Commit any path fixes**

```bash
git add docs/case-studies/meta-analysis/2026-05-22-l2-audit-prep-claims-v7-9-1.md
git commit -m "fix(meta-analysis): L2 File A evidence paths all resolve

§6.4 rule 2 validated.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 17: Redaction pass (spec §6.4 rule 3 — STOP-the-line gate)

**Files:**
- Read: `docs/case-studies/meta-analysis/2026-05-22-l2-audit-prep-claims-v7-9-1.md`

- [ ] **Step 1: Run File A through `scripts/audit/redaction.py`**

Run:
```bash
python3 - <<'EOF'
from scripts.audit.redaction import redact_text
text = open('docs/case-studies/meta-analysis/2026-05-22-l2-audit-prep-claims-v7-9-1.md').read()
redacted, log = redact_text(text)
print(f"Input bytes: {len(text)}")
print(f"Output bytes: {len(redacted)}")
print(f"Redactions applied: {sum(e.get('count', 0) for e in log.get('rules', []))}")
if redacted != text:
    print("DIFFERENCES FOUND — secret/PII leak in File A")
    import difflib
    print(''.join(difflib.unified_diff(text.splitlines(keepends=True), redacted.splitlines(keepends=True), lineterm='', n=2)))
EOF
```
Expected: `Redactions applied: 0` AND no `DIFFERENCES FOUND`.

- [ ] **Step 2: If ≥1 redaction needed — STOP and fix upstream**

If Step 1 shows redactions: the leak originated upstream (corpus extraction, L0, or L1). DO NOT silently patch File A. Instead:
1. Identify the leak source (file in the bundle)
2. Add a new rule to `scripts/audit/redaction.py` if it's a novel pattern
3. Rerun the corpus extraction (Task 1 Step 3)
4. Regenerate L2 File B + File A
5. Rerun Task 15+16+17

- [ ] **Step 3: Commit clean-redaction verification (no diff)**

```bash
git add docs/case-studies/meta-analysis/2026-05-22-l2-audit-prep-claims-v7-9-1.md
git commit --allow-empty -m "verify(meta-analysis): L2 File A redaction pass clean

§6.4 rule 3 validated: zero redactions applied.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 18: Update meta-analysis README.md (3 new index rows)

**Files:**
- Modify: `docs/case-studies/meta-analysis/README.md`

- [ ] **Step 1: Read current README**

Run: `cat docs/case-studies/meta-analysis/README.md`

- [ ] **Step 2: Insert 3 new rows in the Reports table**

Add after the last existing row, before the "## How These Relate" section:

```markdown
| [L0 — Delta vs 2026-04-21 anchor](2026-05-22-l0-delta-vs-anchor.md) | 2026-05-22 | Internal (Claude Opus 4.7) | Quantify corpus + framework + gate deltas since anchor; status of anchor §16 limitations |
| [L1 — Extended cohort analysis (n=83)](2026-05-22-l1-extended-cohort-analysis.md) | 2026-05-22 | Internal (Claude Opus 4.7) | 2026-04-21 anchor replicated on n=83 corpus + 2 new cohort dimensions (framework-version + cross-repo) |
| [L2 — Audit-prep claim ledger v7-9-1 (File A, auditor-facing)](2026-05-22-l2-audit-prep-claims-v7-9-1.md) | 2026-05-22 | Internal (Claude Opus 4.7) | Forward-looking claim ledger fed into External Audit #2 (2026-06-12) claude-bundle. File B internal sidecar NOT indexed (per spec §5.3) |
```

- [ ] **Step 3: Commit the index update**

```bash
git add docs/case-studies/meta-analysis/README.md
git commit -m "docs(meta-analysis): index L0/L1/L2-File-A (Phase 1)

L2 File B intentionally not indexed per spec §5.3 (internal-only).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 19: Pre-ship integrity-check

**Files:** (no edits — read-only verification)

- [ ] **Step 1: Run integrity-check across the whole repo**

Run: `make integrity-check`
Expected: `0 findings + 0 advisory` (or no NEW findings vs the pre-Phase-1 baseline). The new L0/L1/L2 docs must not introduce SCHEMA_DRIFT, CASE_STUDY_MISSING_TIER_TAGS, or BROKEN_PR_CITATION findings.

- [ ] **Step 2: If new findings — fix before ship**

For each finding:
- `CASE_STUDY_MISSING_TIER_TAGS` on a new doc → add T1/T2/T3 tags to quantitative claims
- `BROKEN_PR_CITATION` → fix the PR number (likely typo) or remove the citation
- `SCHEMA_DRIFT` → not expected (we didn't touch state.json); investigate if it fires

- [ ] **Step 3: Commit any fixes**

```bash
git add docs/case-studies/meta-analysis/2026-05-22-l0-delta-vs-anchor.md docs/case-studies/meta-analysis/2026-05-22-l1-extended-cohort-analysis.md docs/case-studies/meta-analysis/2026-05-22-l2-audit-prep-claims-v7-9-1.md
git commit -m "fix(meta-analysis): clear integrity-check findings on new docs

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 20: Stage L2 File A into Audit #2 claude-bundle (final step)

**Files:**
- Create: `docs/audits/external/02-2026-06-12-v7-9-1-f16-plus-hadf/claude-bundle/2026-05-22-l2-audit-prep-claims-v7-9-1.md` (copy of File A)

- [ ] **Step 1: Verify destination directory exists**

Run: `ls -d docs/audits/external/02-2026-06-12-v7-9-1-f16-plus-hadf/claude-bundle/`
Expected: directory exists (created in earlier session commit `cbb87e5`).

- [ ] **Step 2: Copy File A (the post-validation version) into the bundle**

Run:
```bash
cp docs/case-studies/meta-analysis/2026-05-22-l2-audit-prep-claims-v7-9-1.md \
   docs/audits/external/02-2026-06-12-v7-9-1-f16-plus-hadf/claude-bundle/2026-05-22-l2-audit-prep-claims-v7-9-1.md
```

- [ ] **Step 3: Verify byte-identical copy**

Run:
```bash
diff -q docs/case-studies/meta-analysis/2026-05-22-l2-audit-prep-claims-v7-9-1.md \
        docs/audits/external/02-2026-06-12-v7-9-1-f16-plus-hadf/claude-bundle/2026-05-22-l2-audit-prep-claims-v7-9-1.md
```
Expected: zero output (files identical).

- [ ] **Step 4: Rerun redaction check on the staged copy (belt-and-suspenders)**

Same command as Task 17 Step 1 but on the staged path:
```bash
python3 -c "
from scripts.audit.redaction import redact_text
text = open('docs/audits/external/02-2026-06-12-v7-9-1-f16-plus-hadf/claude-bundle/2026-05-22-l2-audit-prep-claims-v7-9-1.md').read()
redacted, log = redact_text(text)
print('Redactions applied:', sum(e.get('count', 0) for e in log.get('rules', [])))
assert redacted == text, 'STAGED COPY HAS LEAK'
print('Staged copy clean.')
"
```
Expected: `Redactions applied: 0` + `Staged copy clean.`.

- [ ] **Step 5: Final ship commit**

```bash
git add docs/audits/external/02-2026-06-12-v7-9-1-f16-plus-hadf/claude-bundle/2026-05-22-l2-audit-prep-claims-v7-9-1.md
git commit -m "ship(meta-analysis): Phase 1 — stage L2 File A into Audit #2 bundle

Phase 1 of the 3-phase meta-analysis program ships. L2 File A
auditor-facing claim ledger (≥30 claims, impartiality-validated,
redaction-clean) now staged into Audit #2 (2026-06-12) claude-bundle.

Inside-view (Phase 1) shipped 4 days before paired outside-view
(External Audit #2, 2026-06-12) per spec §3.3 pairing rule.

Phase 2 (L3 v8.x docket + L4 public retrospective MDX) targets
2026-08-01 ship, paired with External Audit #3.

Phase 3 (L5 cross-anchor reconciliation across Audits #1+#2+#3)
targets 2026-10-04 ship, paired with External Audit #4.

Closes anchor §16 limitations L1-L4 (n=41→83, framework-version
cohort, cross-repo split, Gemini-then-pending). L5-L7 stay open.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 6: Verify final state**

Run: `git log --oneline -8`
Expected: 8 commits on Phase 1 (Tasks 1-20 ship commits) above the original `cbb87e5` audit-infra commit.

- [ ] **Step 7: Push to origin (asks operator first per CLAUDE.md push rule)**

Operator confirms; then:
```bash
git push origin main
```
Expected: branch protection PASSES (required_signatures + integrity + Build and Test). If a status fails: investigate; do not force-push.

---

## Self-Review

(Run after the plan is written, before handing off.)

**1. Spec coverage:**

| Spec section | Plan tasks |
|---|---|
| §5.1 L0 (~80 lines) | Tasks 3, 4, 5 |
| §5.2 L1 (~400 lines) | Tasks 6, 7, 8, 9, 10, 11, 12 |
| §5.3 L2 File A (~200 lines) | Tasks 14, 15, 16, 17 |
| §5.3 L2 File B (~80 lines) | Task 13 |
| §5.4 README index | Task 18 |
| §6.1 Extraction profile | Task 1 |
| §6.4 Impartiality contract (5 rules) | Tasks 15 (rules 1+4), 16 (rule 2), 17 (rule 3), 13+14 (rule 5 — one-way data flow enforced by file ordering) |
| §6.5 Prompt of record | Task 2 |
| §7 Stage to Audit #2 claude-bundle | Task 20 |
| §10 Success criteria | Task 19 (integrity-check), Task 20 (final ship) |

All spec sections covered.

**2. Placeholder scan:**
- `<paste from Task 1 Step 4>`, `<count from grep>`, `<measure>`, etc. — these are intentional "fill at execution time" markers; the value depends on running the previous step. NOT plan failures.
- No "TBD" / "TODO" / "implement later" found.
- Every code/command block contains real, runnable content.

**3. Type consistency:**
- All file paths consistent across tasks (e.g., `2026-05-22-l2-audit-prep-claims-v7-9-1.md` exact string everywhere).
- All schema field names consistent: `id`, `audit_profile_section`, `claim_text`, `evidence_paths`.
- Bundle SHA256 referenced as the same value across L0 §1, L1 §header, L2 File A intro.

Plan is complete and self-consistent.
