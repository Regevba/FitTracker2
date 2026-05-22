# Meta-Analysis Refresh — Phase 1 Design

> **Date:** 2026-05-22
> **Type:** Spec for a chore (meta-analysis) — not a product feature
> **Framework version at design time:** v7.9 (Phase E day 2)
> **Anchor #1 (longitudinal):** [`docs/case-studies/meta-analysis/meta-analysis-2026-04-21.md`](../../case-studies/meta-analysis/meta-analysis-2026-04-21.md)
> **Anchor #2 (impartial):** External Audits #1 (today, v7-9-promotion) + #2 (2026-06-12, v7-9-1-f16-plus-hadf) — produced by the substrate at [`docs/audits/prompts/`](../../audits/prompts/) per [substrate spec](2026-05-18-impartial-audit-prompt-substrate-design.md)
> **Pairing constraint:** Phase 1 ships **≥4 days before audit #2** (2026-06-08 target) so L2's claim ledger is staged into the audit #2 claude-bundle

---

## 0. TL;DR

A new meta-analysis on the full corpus of 83 case studies (~2× the n=41 anchor), structured to feed the external audit calendar. Phase 1 (this spec) replicates the 2026-04-21 anchor methodology + 2 new cohort dimensions + a forward-facing claim ledger for audit #2. Phases 2 + 3 (out of scope) handle strategic synthesis, public narrative, and cross-anchor reconciliation.

Three deliverables: L0 delta vs anchor (~80 lines) · L1 extended cohort analysis (~400 lines) · L2 audit-prep claim ledger (~250 lines). 17-day timeline, ships 2026-06-08.

## 1. Why this spec exists

The prior meta-analysis ([`meta-analysis-2026-04-21.md`](../../case-studies/meta-analysis/meta-analysis-2026-04-21.md)) ran on n=41 case studies right before the Gemini independent audit triggered the v7.5 → v7.9 framework arc. In the 31 days since, the corpus has ~doubled (n=83), the framework has shipped ~10 patches (v7.5 → v7.6 → v7.7 → v7.8 → v7.8.1 → v7.8.2 → v7.8.3 → v7.8.4 → v7.8.5 → v7.8.6 → v7.9), and the external audit substrate has shipped + booked an 8-audit calendar through 2027-05-12.

There has been no holistic meta-analysis on the post-anchor corpus. The framework version arc has not been measured. The cross-repo split FT2↔fitme-story has never been quantified. And the external audit substrate currently has no internal "claims of record" to anchor against.

This spec defines Phase 1 of a 3-phase program to close those gaps, sequenced against the external audit calendar so the inside-view ships before each paired outside-view.

## 2. Scope

### 2.1 In scope (Phase 1)

- All case studies in [`docs/case-studies/*.md`](../../case-studies/) (n=83 at design time)
- All published showcase MDX in [`fitme-story/content/04-case-studies/`](https://github.com/Regevba/fitme-story/tree/main/content/04-case-studies)
- All 11 prior meta-analysis sub-docs in [`docs/case-studies/meta-analysis/`](../../case-studies/meta-analysis/)
- All `.claude/features/*/state.json` files (for state↔case-study reconciliation)
- The integrity ledgers `.claude/shared/measurement-adoption-history.json` + `.claude/shared/documentation-debt.json`

### 2.2 Out of scope (Phase 1 only — deferred to Phase 2 or 3)

- **L3 strategic v8.x docket synthesis** — Phase 2, by 2026-08-01, paired with audit #3
- **L4 public retrospective MDX for fitme-story** — Phase 2, by 2026-08-01
- **L5 cross-anchor reconciliation (internal vs auditors #1 + #2 + #3)** — Phase 3, by 2026-10-04, paired with audit #4
- Code review of any individual feature (this is a documentation meta-analysis, not a code audit)
- Recommending v8.x candidates (that is Phase 2's job; Phase 1 produces the data)

## 3. Anchors

### 3.1 Anchor #1 — `meta-analysis-2026-04-21.md` (longitudinal)

This is the structural backbone. Phase 1 replicates the anchor's 16 sections on the n=83 corpus so the year-over-year deltas are apples-to-apples. The 16 sections:

1. Scope · 2. Extraction method · 3. Corpus aggregates · 4. Work-type distribution · 5. Dispatch-pattern distribution · 6. Phase-documentation coverage · 7. Structural anomaly: audit-v2-gN stub group · 8. Metrics sections coverage · 9. PR citation verification · 10. state.json reconciliation · 11. Framework-version citation distribution · 12. Failure / pivot density · 13. Showcase ↔ main-repo mapping · 14. Summary of findings · 15. Comparison against prior meta-analyses · 16. Limitations

### 3.2 Anchor #2 — External audits #1 + #2 (impartial)

External Audit #1 (today, 2026-05-22) runs the v7-9-promotion profile and is the outside-view of the v7.9 gate promotion itself. External Audit #2 (2026-06-12) runs the v7-9-1-f16-plus-hadf profile and is the outside-view of v7.9.1 build window + HADF Phase 2-bis closure. Phase 1's L2 produces the claim ledger that audit #2's auditor will test.

### 3.3 How the anchors interact

```text
                        2026-04-21        2026-05-22        2026-06-12
                        anchor #1         Phase 1 ships     audit #2 fires
                            │                  │                 │
   corpus growth ─────────► n=41              n=83              n≥83
   framework arc ─────────► v7.0             v7.9             v7.9.1
   external view ─────────► (none)          audit #1         audit #2
                                                  ▲                ▲
                                                  │                │
                                                  └─ Phase 1 L2 ──┘
                                                     claim ledger
```

Phase 1 lives in the gap between Anchor #1 and Audit #2. It carries the longitudinal continuity forward (L0 + L1) and pre-stages the audit #2 inputs (L2).

## 4. Anchor §16 limitations to address

The 2026-04-21 anchor §16 listed limitations. Phase 1 closes the following 4:

| # | Anchor limitation | Phase 1 response |
|---|---|---|
| 1 | Sample size n=41 (~half of features) | n grows to 83 (full corpus at design time) |
| 2 | No framework-version cohort comparison | NEW L1 dimension #1 — adoption rates per ship-version cohort |
| 3 | No cross-repo split FT2↔fitme-story | NEW L1 dimension #2 — doc-debt comparison per repo |
| 4 | Gemini audit then-pending; analysis predates audit findings | Gemini findings now incorporated as the v7.0→v7.5 inflection in L1 dimension #1 |

Other anchor §16 limitations that **stay open** (Phase 1 does not address; documented in L0):

- Self-referential bias (same author for case studies and meta-analysis) — only an external auditor can close this; that's what Anchor #2 is for
- No statistical significance testing (n still too small per cohort for meaningful p-values)
- No reader-comprehension validation (no operator read every case study and rated quality)

## 5. Layer architecture

Three docs (L0/L1/L2) + 1 index update. Each layer has a single purpose, well-defined inputs, and a well-defined deliverable.

### 5.1 L0 — Delta vs anchor (`2026-05-22-l0-delta-vs-anchor.md`)

**Purpose:** quantify what changed between 2026-04-21 anchor and 2026-05-22 corpus, before the more expensive L1 analysis runs.

**Length target:** ~80 lines.

**Sections:**

1. Corpus growth table — n=41 → n=83 by category (work-type, framework-version cohort)
2. Framework version arc table — v7.0 → v7.9 with patch dates + lines added per scripts/check-state-schema.py
3. New gates inventory — count of new write-time gates + cycle-time gates + advisories since anchor
4. Anchor §16 limitations status — which closed (#1-#4), which stay open (#5-#7) with reasons
5. New meta-analysis sub-docs since anchor — v7-5-advancement-report, unclosable-gaps, v7-9-measurement-window-2026-05-11, etc.
6. Pointer to L1 + L2

### 5.2 L1 — Extended cohort analysis (`2026-05-22-l1-extended-cohort-analysis.md`)

**Purpose:** replicate the 2026-04-21 anchor's 16 sections on n=83 + 2 new cohort dimensions.

**Length target:** ~400 lines.

**Structure:** mirrors anchor exactly for §1-§16 (so year-over-year readers find their bearings), then appends:

- **§17 NEW — Framework-version cohort** — group features by ship-version into 5 non-overlapping buckets: `pre-v6` / `v6.0-v6.x` / `v7.0-v7.4` / `v7.5-v7.7` / `v7.8-v7.9` (n per bucket measured at execution). For each cohort, measure adoption rates of: `cache_hits[]` non-empty (post-v6.0), `kill_criteria_resolution` non-empty when `kill_criteria` is set (post-v7.8.1), `state_owner` present (post-v7.8.3), `cu_v2` schema-valid (post-v7.7), tier-tag presence in case study body (post-2026-04-21). Surfaces whether each new field actually got adopted by the cohort that shipped after it became mandatory.
- **§18 NEW — Cross-repo split** — partition features by `state_owner` (`ft2` vs `fitme-story`). Compare doc-debt field-presence rates per repo. Quantifies the v7.8.2 documented-disposition decision empirically: did the asymmetry actually cause measurable harm, or did the policy hold?
- **§19 NEW — Phase 1 limitations** — same self-referential bias caveat as anchor; explicit handoff to Audit #2 for impartial cross-check

### 5.3 L2 — Audit-prep claim ledger (split into 2 files)

**Purpose:** forward-looking claim ledger for External Audit #2 (v7-9-1-f16-plus-hadf profile). To preserve impartiality (per §6.4), the ledger is **split into two files** — the auditor-facing file contains only data and evidence paths; an internal-only sidecar file holds confidence + predicted findings + working notes.

**File A — auditor-facing (`2026-05-22-l2-audit-prep-claims-v7-9-1.md`)**

What the external auditor sees. ≥30 claims, each with this exact structure:

```yaml
- id: C-001
  audit_profile_section: <which section of the v7-9-1+F16+HADF profile this claim relates to>
  claim_text: <statement of fact extractable from the cited evidence paths — see §6.4 impartiality rules>
  evidence_paths:
    - <path to case study / state.json / log file backing the claim>
```

No `internal_confidence`, no `expected_auditor_finding`, no `notes` fields. Length target: ~200 lines.

**File B — internal-only sidecar (`2026-05-22-l2-internal-sidecar.md`)**

Working notes for the internal team. NEVER staged into `claude-bundle/`. Contains, per claim ID:

```yaml
- id: C-001
  internal_confidence: <high | medium | low>
  expected_auditor_finding: <what we predict the auditor will say>
  notes: <caveats, why we wrote the claim this way, etc.>
```

Length target: ~80 lines. Lives at `docs/case-studies/meta-analysis/2026-05-22-l2-internal-sidecar.md`. NOT staged anywhere external.

**Why this matters:** External Audit #2 fires 4 days after Phase 1 ships. If the internal team has already published a claim like "C-007: `BRANCH_ISOLATION_VIOLATION` was promoted from advisory to enforced via PR #417 on 2026-05-21" with evidence paths, the auditor either confirms (validating our self-assessment) or contradicts (high-signal finding). Without the claim ledger, the auditor's report has nothing specific to test against — its findings are diffuse and less actionable.

**Sourcing:** claims are extracted from L1 findings + the post-v7.9 §3.1 Source E candidates (F19/F20/F22/F23) + the framework-honesty-ledger entries (FT2-FH-001/FH-002/FH-003).

### 5.4 Index update (`docs/case-studies/meta-analysis/README.md`)

Append 3 rows to the existing "Reports" table:

```markdown
| [L0 — Delta vs 2026-04-21 anchor](2026-05-22-l0-delta-vs-anchor.md) | 2026-05-22 | Internal (Claude Opus 4.7) | Quantify corpus + framework + gate deltas since anchor; status of anchor §16 limitations |
| [L1 — Extended cohort analysis](2026-05-22-l1-extended-cohort-analysis.md) | 2026-05-22 | Internal (Claude Opus 4.7) | 2026-04-21 anchor replicated on n=83 corpus + 2 new cohort dimensions (framework-version + cross-repo) |
| [L2 — Audit-prep claim ledger v7-9-1](2026-05-22-l2-audit-prep-claims-v7-9-1.md) | 2026-05-22 | Internal (Claude Opus 4.7) | Forward-looking claim ledger fed into External Audit #2 (2026-06-12) claude-bundle |
```

## 6. Methodology

### 6.1 Extraction

Reuse [`scripts/audit/build_bundle.py`](../../../scripts/audit/build_bundle.py) with a new profile [`scripts/audit/profiles/meta-analysis-2026-05-22.json`](../../../scripts/audit/profiles/) that targets:

- `docs/case-studies/**/*.md` (case studies + meta-analysis sub-docs)
- `.claude/features/*/state.json`
- `.claude/shared/measurement-adoption-history.json`
- `.claude/shared/documentation-debt.json`
- `.claude/shared/integrity-checkpoint-ledger.jsonl`
- `.claude/logs/gate-coverage.jsonl` (last 30 days)

Output is a deterministic SHA256-stamped corpus snapshot. **Important:** this bundle is NOT for an external auditor. It is the working corpus for the internal meta-analysis. Phase 1 producing a bundle just means the data extraction is reproducible.

### 6.2 Statistical conventions

- Percentages reported to 1 decimal place
- All n values explicit per cohort
- Per-cohort denominators always stated (no "100% of features adopted X" without saying "of the n=8 features that shipped post-v7.8.3")
- No p-values claimed — sample sizes per cohort are too small (typically n<15)
- T1/T2/T3 tier tagging on every quantitative claim per [data-quality-tiers.md](../../case-studies/data-quality-tiers.md)

### 6.3 Validation

Every cohort number in L1 is reproducible from the L0 extraction bundle via the L1 doc's "Extraction method" section. If a future operator reruns the methodology in 6 months, they should get the same numbers (modulo corpus growth).

### 6.4 Impartiality + redaction contract (auditor-facing artifact only)

The L2 File A auditor-facing claim ledger (§5.3) is the only Phase 1 deliverable that gets handed to an external auditor. It MUST satisfy all five rules:

1. **Pure data.** Every claim is a STATEMENT OF FACT extractable from the cited evidence paths. No editorializing words ("good", "bad", "concerning", "promising", "surprisingly", "unfortunately"). No first-person framing ("we believe", "we expect", "we think"). No comparative judgments without evidence ("better than", "improved over").
2. **Resolved evidence.** Every `evidence_paths` value MUST resolve to a real file in the redacted corpus bundle. CI check: `python3 scripts/audit/check_prompts.py` extended to validate L2 evidence paths.
3. **Redaction pass.** Before File A is staged into `docs/audits/external/02-2026-06-12-v7-9-1-f16-plus-hadf/claude-bundle/`, it MUST be run through `scripts/audit/redaction.py` (the same 9-rule redactor used by `build_bundle.py`). **Zero new redactions = pass; ≥1 new redaction = STOP and fix corpus extraction first** (a leak in L2 means a leak in the L0/L1 inputs that fed it).
4. **No internal-sidecar leakage.** File B (`2026-05-22-l2-internal-sidecar.md`) MUST NOT be copied, referenced, or linked from File A. Hard separation enforced by file naming + a CI grep check.
5. **One-way data flow.** L0 → L1 → L2 File A → staged bundle. Never the reverse. If a claim in L2 File A turns out to be wrong, the fix lives in L1 first (or the corpus itself), then propagates forward.

L0 and L1 are internal documents that may contain author interpretation (they are not staged to any external auditor). The impartiality contract applies only to File A.

### 6.5 Prompt of record (L2 File A generation)

The L2 File A generator (human or Claude) follows the rules at [`docs/audits/prompts/03-meta-analysis-l2-extraction-prompt.md`](../../audits/prompts/03-meta-analysis-l2-extraction-prompt.md) — a NEW prompt file written on Phase 1 Day 1. The prompt is the **prompt of record** for L2 File A and must:

- Inline the five impartiality rules from §6.4 verbatim
- Require the operator to cite the L0 extraction bundle SHA256 before generating any claim
- Forbid the operator from writing any text outside the `id / audit_profile_section / claim_text / evidence_paths` schema
- Include a refusal template the operator returns if asked to add interpretation

The auditor-facing prompt (what the external auditor reads alongside the bundle) is unchanged: [`docs/audits/prompts/02-auditor-prompt.md`](../../audits/prompts/02-auditor-prompt.md). No Phase 1 modifications to it.

The extraction prompt (operator-side bundle builder) is also unchanged: [`docs/audits/prompts/01-extraction-prompt.md`](../../audits/prompts/01-extraction-prompt.md). Phase 1 adds prompt 03 as a sibling, not a replacement.

## 7. Deliverables & locations

```text
docs/case-studies/meta-analysis/
├── README.md                                       (updated, +3 rows for L0/L1/L2-File-A; File B is internal-only and NOT indexed)
├── 2026-05-22-l0-delta-vs-anchor.md                (NEW, ~80 lines, internal)
├── 2026-05-22-l1-extended-cohort-analysis.md       (NEW, ~400 lines, internal)
├── 2026-05-22-l2-audit-prep-claims-v7-9-1.md       (NEW, ~200 lines, File A — auditor-facing)
└── 2026-05-22-l2-internal-sidecar.md               (NEW, ~80 lines, File B — internal only, NEVER staged)

docs/audits/prompts/
└── 03-meta-analysis-l2-extraction-prompt.md        (NEW, prompt-of-record for L2 File A — see §6.5)

scripts/audit/profiles/
└── meta-analysis-2026-05-22.json                   (NEW, internal-only extraction profile for L0/L1)

docs/audits/external/02-2026-06-12-v7-9-1-f16-plus-hadf/claude-bundle/
└── (L2 File A copy staged here on Phase 1 ship day, AFTER redaction pass per §6.4 rule 3)
```

**Hard rule:** the only file that gets copied from `docs/case-studies/meta-analysis/` into `docs/audits/external/*/claude-bundle/` is L2 File A. L0, L1, and L2 File B remain internal-only.

## 8. Timeline (17 days · today = Day 0 = 2026-05-22)

| Days | Date(s) | Milestone |
|---|---|---|
| 0-1 | 05-22 → 05-23 | Spec written + user-approved (today); writing-plans dispatch creates implementation plan |
| 2-4 | 05-24 → 05-26 | Build profile JSON + extraction bundle + write L0 |
| 5-12 | 05-27 → 06-03 | Write L1 (longest block — 16 anchor sections + 3 new sections) |
| 13-15 | 06-04 → 06-06 | Write L2 (≥30 claims, each with evidence path verification) |
| 16 | 06-07 | Spec self-review on all 3 docs + commit + user review |
| **17 (=2026-06-08)** | **06-08** | **Phase 1 SHIPS** — L2 staged into Audit #2 claude-bundle; PR merged to main |

Slack budget: 4 days between Phase 1 ship (06-08) and Audit #2 fire (06-12). If Phase 1 slips, audit #2 still fires — just without the claim ledger.

## 9. Risks

| Risk | Severity | Mitigation |
|---|---|---|
| n=83 takes ≥2× the time n=41 anchor did (10 days → 20 days) | High — would miss audit #2 pairing | Hard scope to Phase 1 layers only; defer L3-L5 to Phase 2/3 (already done) |
| L1 cohort dimensions reveal embarrassingly low adoption rates | Medium | This is the point — Phase 1 surfaces what the framework actually achieved vs claimed. Per [feedback-publish-verbatim-then-remediate], publish the numbers as found |
| External Audit #1 (today) surfaces findings that invalidate Phase 1 assumptions | Medium | Phase 1 timeline includes Day 0-1 for spec; if audit #1 findings change framing, the spec can be amended before Day 2 starts |
| Cross-repo split (NEW L1 dimension #2) reveals fitme-story has worse hygiene than FT2 | Low-Medium | Document the asymmetry honestly; cross-reference the v7.8.2 documented-disposition decision |
| Phase 1 ships but L2's claims aren't load-bearing enough for the auditor | Medium | L2 sourcing is rigorous (every claim has evidence_paths); ≥30 claims ensures volume |
| Mechanism C session-attribution miscounts cache_hits for Phase 1 itself (self-referential) | Low | Run a manual cache_hits verification on Phase 1's own state.json before ship |

## 10. Success criteria

Phase 1 is successful if **all** of the following hold on ship day (2026-06-08):

1. All 4 docs (L0 + L1 + L2 File A + L2 File B) + 1 prompt (03-meta-analysis-l2-extraction-prompt.md) + 1 profile (meta-analysis-2026-05-22.json) committed to main with full content
2. README.md updated with 3 new index rows (L0 + L1 + L2 File A); L2 File B is internal-only and NOT indexed
3. L2 File A (auditor-facing, post-redaction) copied to `docs/audits/external/02-2026-06-12-v7-9-1-f16-plus-hadf/claude-bundle/`
4. Every L1 cohort number traceable to the L0 extraction bundle SHA256
5. No tier-tag violations (`make integrity-check` returns 0 findings on the new docs)
6. Ship date ≤ 2026-06-08 (4-day pairing margin preserved)
7. **L2 File A passes the §6.4 impartiality contract** — pure data, redaction clean (zero new redactions), evidence paths all resolve, no internal-sidecar leakage

Phase 1 is **not** successful (ship-blocking) if:

- L2 File A has <30 claims, OR
- Any L1 claim is contradicted by its own evidence path, OR
- L2 File A contains any first-person framing, editorializing word, or `internal_confidence` / `expected_auditor_finding` field, OR
- L2 File A introduces ≥1 new redaction when run through `scripts/audit/redaction.py` (means a leak slipped through corpus extraction), OR
- Ship date slips past 2026-06-10 (eliminates the 4-day audit pairing margin)

## 11. Out-of-scope reminder

Phase 2 + Phase 3 are NOT defined by this spec. They get their own specs at their natural breakpoints:

- **Phase 2 spec** written by ~2026-06-15 (Phase 1 ship +1 week), shipping by 2026-08-01. Layers L3 (v8.x docket) + L4 (public retrospective MDX).
- **Phase 3 spec** written by ~2026-08-10 (Phase 2 ship +1 week), shipping by 2026-10-04. Layer L5 (cross-anchor reconciliation across audits #1 + #2 + #3).

## 12. Cross-references

- Anchor #1: [`docs/case-studies/meta-analysis/meta-analysis-2026-04-21.md`](../../case-studies/meta-analysis/meta-analysis-2026-04-21.md)
- Anchor #2 substrate: [`docs/superpowers/specs/2026-05-18-impartial-audit-prompt-substrate-design.md`](2026-05-18-impartial-audit-prompt-substrate-design.md)
- External audit calendar: [`docs/master-plan/infra-master-plan-2026-05-12.md`](../../master-plan/infra-master-plan-2026-05-12.md) §5
- v7.0 full-system audit (predecessor pattern): [`docs/case-studies/meta-analysis-full-system-audit-v7.0-case-study.md`](../../case-studies/meta-analysis-full-system-audit-v7.0-case-study.md)
- v7.5 → v7.9 framework arc: CLAUDE.md "Data Integrity Framework" section
- Data quality tier convention: [`docs/case-studies/data-quality-tiers.md`](../../case-studies/data-quality-tiers.md)
- Unclosable gaps inventory: [`docs/case-studies/meta-analysis/unclosable-gaps.md`](../../case-studies/meta-analysis/unclosable-gaps.md)
- External audit folder structure: [`docs/audits/external/README.md`](../../audits/external/README.md)
