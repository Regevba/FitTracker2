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

