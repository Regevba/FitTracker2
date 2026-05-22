# L2 File A Extraction Prompt (Meta-Analysis Phase 1 — Prompt of Record)

> **Spec:** [`docs/superpowers/specs/2026-05-22-meta-analysis-refresh-phase-1-design.md`](../superpowers/specs/2026-05-22-meta-analysis-refresh-phase-1-design.md) §6.5
>
> This prompt generates the AUDITOR-FACING file `2026-05-22-l2-audit-prep-claims-v7-9-1.md`. Reproducible by any operator (human or Claude).

---

## Inputs you have

1. The L0 extraction bundle at `docs/audits/runs/<timestamp>/bundle.md` (SHA256 stamped, deterministic)
2. The L0 delta doc at `docs/case-studies/meta-analysis/2026-05-22-l0-delta-vs-anchor.md`
3. The L1 cohort analysis at `docs/case-studies/meta-analysis/2026-05-22-l1-extended-cohort-analysis.md`
4. The L2 internal sidecar (File B) at `docs/case-studies/meta-analysis/2026-05-22-l2-internal-sidecar.md`

---

## Hard rules (NEVER violate)

### Rule 1: Pure data

Every claim is a **STATEMENT OF FACT** extractable from cited evidence paths. Forbidden words in `claim_text`:

- `we believe`, `we expect`, `we think`, `we hope`
- `unfortunately`, `concerning`, `promising`, `surprisingly`
- `good`, `bad`, `better than`, `worse than`, `improved`

No first-person framing. No editorializing. No subjective evaluations disguised as data.

**Test:** If a reader can find the exact statement in one of the evidence files, the claim passes. If the claim requires inference, interpretation, or editorial judgment to extract, it fails.

### Rule 2: Resolved evidence

Every `evidence_paths` value **MUST** be a real file path in the bundle. Test each path before writing it:

- Does the file exist in the redacted corpus bundle?
- Can the claim text be extracted verbatim from that file?
- If the evidence file is removed/redacted before ship day, does the claim become unsupported?

**Failure mode:** A claim with evidence path `docs/case-studies/phantom-feature-case-study.md` (if that file is not in the bundle) is a blocker.

### Rule 3: Schema-only

The ONLY allowed fields in the YAML are:

```
- id
- audit_profile_section
- claim_text
- evidence_paths
```

Forbidden fields (go in File B instead):

- `internal_confidence`
- `expected_auditor_finding`
- `notes`
- `caveat`
- `confidence_level`
- `any other field`

**Enforcement:** Before shipping, run a grep to verify no forbidden fields appear in the output.

### Rule 4: No prose between claims

The output doc body contains ONLY:

1. A single intro line citing the L0 bundle SHA256
2. The YAML list of claims
3. A single closing line noting File B's location

NO narrative paragraphs. NO editorializing. NO "this is important because...". If you need to explain context, it goes in File B (internal sidecar), not File A.

### Rule 5: One-way data flow

L0 → L1 → L2 File A → staged bundle. Never the reverse.

- If a claim turns out to be wrong during auditor review, the fix is applied to L1 or the corpus, NOT to File A retroactively.
- File A is the immutable record of what was claimed on ship day (2026-06-08).

---

## Impartiality contract (verbatim from spec §6.4)

The L2 File A auditor-facing claim ledger MUST satisfy all five rules:

1. **Pure data.** Every claim is a STATEMENT OF FACT extractable from the cited evidence paths. No editorializing words ("good", "bad", "concerning", "promising", "surprisingly", "unfortunately"). No first-person framing ("we believe", "we expect", "we think"). No comparative judgments without evidence ("better than", "improved over").

2. **Resolved evidence.** Every `evidence_paths` value MUST resolve to a real file in the redacted corpus bundle. CI check: `python3 scripts/audit/check_prompts.py` extended to validate L2 evidence paths.

3. **Redaction pass.** Before File A is staged into `docs/audits/external/02-2026-06-12-v7-9-1-f16-plus-hadf/claude-bundle/`, it MUST be run through `scripts/audit/redaction.py` (the same 9-rule redactor used by `build_bundle.py`). **Zero new redactions = pass; ≥1 new redaction = STOP and fix corpus extraction first** (a leak in L2 means a leak in the L0/L1 inputs that fed it).

4. **No internal-sidecar leakage.** File B (`2026-05-22-l2-internal-sidecar.md`) MUST NOT be copied, referenced, or linked from File A. Hard separation enforced by file naming + a CI grep check.

5. **One-way data flow.** L0 → L1 → L2 File A → staged bundle. Never the reverse. If a claim in L2 File A turns out to be wrong, the fix lives in L1 first (or the corpus itself), then propagates forward.

---

## Output structure

```markdown
# L2 — Audit-Prep Claim Ledger (File A, auditor-facing)

> Generated from L0 extraction bundle SHA256: `<paste the bundle SHA256 from L0 §1>`
> Companion internal sidecar: see [`2026-05-22-l2-internal-sidecar.md`](2026-05-22-l2-internal-sidecar.md) (NOT staged to external auditor)

~~~yaml
- id: C-001
  audit_profile_section: <section name from v7-9-1-f16-plus-hadf audit profile>
  claim_text: <statement of fact>
  evidence_paths:
    - <path>
    - <path>
- id: C-002
  audit_profile_section: <section name>
  claim_text: <statement of fact>
  evidence_paths:
    - <path>
~~~
```

**Notes on this structure:**
- Use triple-tilde `~~~yaml` for the inner YAML block (markdown supports tilde fences). This keeps the backtick nesting clean.
- The intro line naming the bundle SHA256 is required — include it verbatim.
- The companion sidecar reference is informational (for the internal team reading the audit output); it does NOT link to anything external.

---

## Minimum count

≥30 claims. Cover at least these domains:

- **Gate promotions:** `BRANCH_ISOLATION_VIOLATION` (Mode B + C) and `FEATURE_CLOSURE_COMPLETENESS` v7.9 promotion (2026-05-21)
- **Post-v7.9 telemetry:** Phase E measurement window (2026-05-21 → 2026-06-04), Mechanism A coverage data
- **HADF Phase 2 closure:** Success metrics (silhouette ≥0.55), Path B green-lit, showcase (22b data)
- **UCC passkey-auth cutover:** Parts 1–6 shipped, Part 7 break-glass deferred, Part 8 gated
- **Framework versions:** v7.9 adoption rates across the corpus, framework-version cohort split (L1 §17)
- **Cross-repo split:** fitme-story vs FT2 doc-debt comparison (L1 §18), state_owner field rollout
- **Framework-honesty-ledger:** Entries FT2-FH-001, FT2-FH-002, FT2-FH-003 claims
- **Mechanism coverage:** Mechanism A (coverage-asserting gates), Mechanism C (session-attribution), Mechanism E (merge driver)

---

## Refusal template

If asked by the operator to add interpretation, internal confidence, expected findings, or any other non-data content:

```
REFUSED — File A is auditor-facing and must remain pure data per spec §6.4. 
Commentary, confidence assessments, and predicted findings belong in File B 
(internal sidecar). To add interpretation, edit File B at 
`docs/case-studies/meta-analysis/2026-05-22-l2-internal-sidecar.md`.
```

Return this verbatim. Do not negotiate or simplify.

---

## Sourcing tips for ≥30 claims

### Scan L1 findings (existing corpus data)

- L1 §3 "Corpus aggregates" — find specific n counts for feature categories
- L1 §4 "Work-type distribution" — claim on distribution ratios
- L1 §6 "Phase-documentation coverage" — gaps in case-study frontmatters
- L1 §10 "state.json reconciliation" — broken links or missing citations
- L1 §17 "Framework-version cohort" — adoption rates per cohort (NEW)
- L1 §18 "Cross-repo split" — doc-debt deltas per repo (NEW)

### Scan post-v7.9 §3.1 Source E candidates (F19/F20/F22/F23)

- Source E is the outcome of framework-gate promotion telemetry
- Mechanism A `gate-coverage.jsonl` shows what fired + when
- Extract claims on: gate-promotion timing, skip-reason distributions, false-positive counts

### Scan framework-honesty-ledger entries

File: `docs/case-studies/framework-honesty-ledger.md`

- FT2-FH-001 — what claim was made, what was the oversight
- FT2-FH-002 — same
- FT2-FH-003 — same

Extract claims on timing, remediation status, impact.

### Scan case-study PR citations

File: `.claude/shared/gh-pr-cache.json` (the unified cross-repo PR cache)

- Find claims like "Feature X was shipped in PR #N on date Y"
- Cross-check the date from the PR metadata
- State the fact: "PR #N merged on 2026-05-21 per git history"

---

## Evidence path conventions

For case studies:
- `docs/case-studies/{feature}-case-study.md` — cite by file path, optionally with section anchor if the claim appears in a specific section

For state files:
- `.claude/features/{feature}/state.json` — cite by file path, optionally with JSON-path notation if the claim is about a specific field (e.g., `state.json::phases.merge.pr_number`)

For ledgers:
- `.claude/shared/measurement-adoption-history.json` — cite by file path, note the date if the claim is about a specific snapshot
- `.claude/shared/documentation-debt.json` — same
- `.claude/shared/framework-honesty-ledger.md` — cite by file path, note the entry ID (FT2-FH-001, etc.)

For logs:
- `.claude/logs/gate-coverage.jsonl` — cite by file path, note the date range if citing a specific window

For meta-analysis:
- `docs/case-studies/meta-analysis/2026-05-22-l0-delta-vs-anchor.md` — cite by file path, note the section (§1, §2, etc.)
- `docs/case-studies/meta-analysis/2026-05-22-l1-extended-cohort-analysis.md` — same

---

## Example claims (to calibrate your output)

**Example 1 — gate promotion:**
```yaml
- id: C-001
  audit_profile_section: "Framework-Gate Promotion (v7.9 Phase A)"
  claim_text: "BRANCH_ISOLATION_VIOLATION gate promoted from advisory to enforced on 2026-05-21 via PR #417 merge commit SHA xxxxxxx."
  evidence_paths:
    - "docs/superpowers/specs/2026-05-22-meta-analysis-refresh-phase-1-design.md"
    - ".claude/features/framework-v7-8-branch-isolation/state.json"
```

**Example 2 — cohort adoption:**
```yaml
- id: C-002
  audit_profile_section: "Framework-Version Cohort (L1 §17)"
  claim_text: "Of the 8 features that shipped under v7.8, 7 of 8 (87.5%) have kill_criteria_resolution populated when kill_criteria is set."
  evidence_paths:
    - "docs/case-studies/meta-analysis/2026-05-22-l1-extended-cohort-analysis.md"
    - ".claude/features/*/state.json"
```

**Example 3 — honesty ledger:**
```yaml
- id: C-003
  audit_profile_section: "Internal-Audit Honesty (Framework Transparency)"
  claim_text: "FT2-FH-003 documents the v7.9 promotion gate telemetry window (2026-05-07 to 2026-05-21) with 14-day coverage across 3 gate categories and 0 false-positive findings."
  evidence_paths:
    - "docs/case-studies/framework-honesty-ledger.md"
    - "docs/case-studies/framework-v7-9-promotion-case-study.md"
```

---

## Workflow

1. **Load the inputs:** Open L0, L1, L2 File B, and the L0 bundle in your context.
2. **Cite the bundle SHA256:** Paste it in the output header (from L0 §1).
3. **Generate ≥30 claims:** Use the sourcing tips above to find facts across L1, post-v7.9 telemetry, and honesty ledger entries.
4. **Verify each claim:**
   - Is it a statement of fact (not interpretation)?
   - Can I find it in the evidence_paths?
   - Does it avoid forbidden words?
5. **Check the schema:** Grep the output for `internal_confidence`, `expected_auditor_finding`, `notes`, etc. All should return 0 matches.
6. **Run `python3 scripts/audit/check_prompts.py`:** Confirm no errors on the new file.
7. **Commit:** Add to git with the message specified in the task.

---

## Final checklist before shipping

- [ ] Output has ≥30 claims
- [ ] Output contains ONLY the 4 allowed fields (id, audit_profile_section, claim_text, evidence_paths)
- [ ] No forbidden words in any claim_text
- [ ] No first-person framing in any claim_text
- [ ] Every evidence_paths entry points to a file that exists in the redacted corpus bundle
- [ ] Bundle SHA256 cited in the intro line
- [ ] No links to File B (internal sidecar) except the informational reference in the preamble
- [ ] `python3 scripts/audit/check_prompts.py` returns 0 errors on the file
- [ ] The YAML parses cleanly (test with `python3 -c "import yaml; yaml.safe_load(open('file.md').read())"`)
