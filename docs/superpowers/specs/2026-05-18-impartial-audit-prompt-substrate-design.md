# Impartial Audit Prompt Substrate — Design

**Date written:** 2026-05-18
**Status:** Spec (awaiting user review → writing-plans)
**Author scope:** Framework infrastructure
**Successor of:** [`trust/audits/2026-04-21-gemini/`](../../../trust/audits/2026-04-21-gemini/) (precedent run)
**Plugs into:** [`docs/master-plan/infra-master-plan-2026-05-12.md`](../../master-plan/infra-master-plan-2026-05-12.md) §5 calendar

---

## 1. Problem

The infra master plan books **4 External Audits** and **4 Data Freshness Audits** through 2027-05-12, but each audit currently runs as a one-off — the operator hand-assembles the bundle, hand-writes the auditor prompt, and prior runs are not reproducible. The 2026-04-21 Gemini audit produced excellent findings (it triggered the v7.5 → v7.7 framework arc) but its inputs cannot be replayed. Two consequences:

1. **No drift detection across audits.** Audit #2 cannot detect that Audit #1's findings have regressed because the bundle hashes are not comparable.
2. **No determinism guarantee.** If two operators run "the audit" on the same date, they may ship different bundles and get different findings — which means the framework cannot use external audits as a trust anchor.

The 5th unclosable gap from CLAUDE.md ("Tier 3.3 external replication — requires an external operator") becomes a recurring operational obligation. This spec is the substrate that makes that obligation cheap and replicable.

---

## 2. Goals & non-goals

### Goals

- Produce a **reproducible bundle** (same inputs → same SHA256) so audits across dates are comparable.
- Constrain the external auditor to **mechanical, data-driven output** (inventory + discrepancy log + corrections) — no editorializing, no interpretation of intent.
- Apply **deterministic redaction** of secrets and PII before the bundle leaves the repo. The prompts are the contract; a small Python helper script (`scripts/audit/build-bundle.py`) is the receipt.
- Parameterize over **scope profile** so the same prompt pair serves all 8 planned audits with different file sets.

### Non-goals

- The auditor's prompt does not direct the auditor toward *which* discrepancies matter. The framework owns interpretation; the auditor only counts and compares.
- This substrate does not replace the human-at-simulator Tier 2.1 auth checklist, nor the judgment-based `cu_v2` correctness check (unclosable-gaps #2 + #4). It addresses unclosable-gap #5 only.
- No new pre-commit gate ships with v0 of this substrate. (`AUDIT_BUNDLE_HASH_DRIFT` is listed as an advisory cycle-time check in §10 but stays advisory.)

---

## 3. Audit calendar overlay

From [`infra-master-plan-2026-05-12.md`](../../master-plan/infra-master-plan-2026-05-12.md) §5 + [`2026-05-12-consolidated-review-linear-notion-prep.md`](../../master-plan/2026-05-12-consolidated-review-linear-notion-prep.md):

| Date | Audit | Profile | Validates |
|---|---|---|---|
| **2026-05-22** | External Audit #1 | `v7-9-promotion` | v7.9 promotion data + HADF Sub-exp 1 prereg |
| **2026-06-12** | External Audit #2 | `v7-9-1-f16-plus-hadf` | F16 try-repo fixture corpus + HADF Sub-exps 1-3 raw data integrity |
| **2026-08-05** | External Audit #3 | `v8-0-gates-plus-hadf-closure` | 6 new v8.0 gates' calibration data honesty + Block C synthesis + ORCHID v2 |
| **2026-08-12** | Data Freshness Audit #1 (T+90d) | `freshness` | Gate emission keys ↔ function names ↔ test names canonicality |
| **2026-10-08** | External Audit #4 | TBD (defaults to `base`) | Scope decided closer to date |
| **2026-11-12** | Data Freshness Audit #2 (T+180d) | `freshness` | Same as Freshness #1 |
| **2027-02-12** | Data Freshness Audit #3 (T+270d) | `freshness` | Same |
| **2027-05-12** | Data Freshness Audit #4 (T+365d) | `freshness` | Closes year 1 forward plan |

The prompts are stable across all 8 audits; only the profile and the per-run output folder change.

---

## 4. Architecture

Three artifacts, two of which are operator-facing prompts:

```
docs/audits/
├── prompts/
│   ├── 01-extraction-prompt.md      ← Product 1 — operator runs in Claude Code
│   └── 02-auditor-prompt.md         ← Product 2 — operator pastes in fresh chat
└── runs/                             (gitignored except for final reports)
    └── YYYY-MM-DD-<auditor-model>/
        ├── bundle.md                ← Concatenated, redacted, hash-stamped
        ├── manifest.json            ← Per-file: path, sha256, byte count, redactions
        ├── redaction-log.json       ← Per-rule counts, never values
        └── (auditor's report.md committed back into trust/audits/ on completion)

scripts/audit/
├── build-bundle.py                  ← Deterministic backbone; pure stdlib
├── profiles/
│   ├── base.json                    ← case-studies + measurement only (Q1 answer)
│   ├── v7-9-promotion.json          ← Audit #1
│   ├── v7-9-1-f16-plus-hadf.json    ← Audit #2
│   ├── v8-0-gates-plus-hadf-closure.json  ← Audit #3
│   └── freshness.json               ← Data Freshness Audits #1-#4
└── redaction-rules.py               ← Single source of truth for regexes

trust/audits/YYYY-MM-DD-<model>/      ← Where the auditor's final report lands
                                        (precedent: 2026-04-21-gemini/)
```

**Why three layers:** the prompts (committed, reviewable) are the contract with the auditor; the helper script (committed, deterministic) is the receipt that the contract was honored on the bundle side; the per-run output folder is the audit artifact stream.

---

## 5. Scope decisions (locked during brainstorming 2026-05-18)

These four decisions are load-bearing — the rest of the design derives from them. Listed here so the spec is self-contained.

| Decision | Value | Implication |
|---|---|---|
| **Bundle scope** | Case studies + measurement ledgers + prior audits (narrow) | Profile `base.json` includes `docs/case-studies/**`, three `.claude/shared/*.json` ledgers, `trust/audits/**`, one generated `_state-snapshot.json` |
| **Auditor runtime** | Fresh-chat LLM, single concatenated bundle | Bundle format = one `bundle.md` markdown file with TOC + per-file headers + final hash. No file-tree mode in v0 |
| **Redaction depth** | Standard (PII + secrets + DSNs + absolute paths + GCP/GA4 IDs) | Keeps GitHub usernames, PR numbers, commit SHAs, branch names (all public on GitHub anyway) |
| **Report shape** | 3-phase (Inventory → Discrepancies → Corrections) | Phase 1 = tables only; Phase 2 = JSON schema; Phase 3 = concrete edits |

---

## 6. Extraction prompt contract (Product 1)

`docs/audits/prompts/01-extraction-prompt.md` is operator-facing. The operator runs it inside Claude Code (or an equivalent agentic CLI) with one argument: the profile name.

**Files included** (assembled by `build-bundle.py` from `profiles/<name>.json` glob list, alphabetically ordered for determinism):

For `base` profile:
- `docs/case-studies/**/*.md` (recursive; includes `meta-analysis/`)
- `.claude/shared/measurement-adoption.json`
- `.claude/shared/measurement-adoption-history.json`
- `.claude/shared/documentation-debt.json`
- `.claude/shared/case-study-monitoring.json`
- `.claude/shared/case-study-t1-references.json`
- `trust/audits/**/*.md`
- Generated: `_state-snapshot.json` — for each `.claude/features/*/state.json`, the subset `{current_phase, framework_version, success_metrics, kill_criteria, kill_criteria_resolution, case_study_link}`

Other profiles extend the base set; they never subtract from it (so the discrepancy schema stays portable).

**Redaction rules** (single source: `scripts/audit/redaction-rules.py`):

| Pattern | Replacement |
|---|---|
| `[\w.+-]+@[\w.-]+\.\w+` | `[REDACTED_EMAIL]` |
| `fitme-490515` | `[REDACTED_GCP_PROJECT]` |
| `531124395` | `[REDACTED_GA4_PROPERTY]` |
| Firebase config blocks, Sentry DSN, Vercel bypass tokens (regex list) | `[REDACTED_DSN]` etc. |
| `/Volumes/DevSSD/FitTracker2` | `<repo>` |
| `/Users/regevbarak` | `<home>` |
| `ya29\.[A-Za-z0-9_-]{60,}` | `[REDACTED_OAUTH_TOKEN]` |
| `*@*\.iam\.gserviceaccount\.com` | `[REDACTED_SERVICE_ACCOUNT]` |

Kept intact (deliberately): `Regevba`, `Regevba/FitTracker2`, `Regevba/fitme-story`, `PR #N`, commit SHAs, branch names, pseudonym "the operator."

**Bundle format** (`bundle.md`):

```
# FitTracker2 Impartial Audit Bundle
# Generated: <ISO-8601 UTC>
# Profile: <profile-name>
# Bundle SHA256: <hash of all post-redaction content concatenated>
# build-bundle.py SHA256: <hash of the script itself, for reproducibility>
# File count: N
# Redaction count: M

## Table of Contents
- §1 Case studies (X files)
- §2 Meta-analyses (Y files)
- §3 Measurement ledgers (3 files)
- §4 Prior audits (Z files)
- §5 Framework state snapshot (1 generated file)

---

### FILE: docs/case-studies/<name>.md
<post-redaction content>

---

### FILE: <next path>
...
```

**Sidecar artifacts** (same `runs/<date>/` folder):
- `manifest.json` — `[{path, sha256_pre_redaction, sha256_post_redaction, bytes, redactions_applied}]`
- `redaction-log.json` — `{rule_name: count}` only, never values

**Size guardrail:** if bundle exceeds 500K tokens (rough Claude.ai context limit), `build-bundle.py` emits a warning + auto-suggests `--split-by-section` mode that produces 4 separate bundles (case-studies / meta-analyses / ledgers / audits) + a master manifest.

**Reproducibility check:** the helper records its own file's SHA256 in the manifest. Same inputs + same script version → identical bundle hash.

---

## 7. Auditor prompt contract (Product 2)

`docs/audits/prompts/02-auditor-prompt.md` is what the operator pastes into the fresh chat ABOVE the bundle.

### Role block

> You are an impartial data auditor. You will receive a single concatenated bundle of files from an external project. Your job is to produce a three-phase audit report with strict separation of observation from interpretation. You are not a consultant, advisor, or collaborator. You do not infer intent. You do not assess "quality" qualitatively. You count, compare, and report deltas.

### Hard constraints

1. Every numeric claim in your report MUST cite a bundle location as `<path>:<line-range>`. Uncited numbers are forbidden.
2. Phase 1 OUTPUT MUST be tables only. No prose paragraphs. No adjectives. No words like "impressive," "concerning," "robust."
3. Phase 2 discrepancies MUST follow the schema below. If you cannot fit a finding into the schema, log it under `unstructured_observations[]` — do not paraphrase it into the schema.
4. When data is ambiguous, log `INSUFFICIENT_DATA` with the specific ambiguity. Do not guess. Do not "interpret in light of context."
5. Phase 3 corrections MUST be concrete (line-level edits, file deletions, ledger field additions). No corrections of the form "consider reviewing X" or "the team might want to."
6. You may not access external tools (web, code execution). The bundle is the only ground truth.
7. If the operator asks you to elaborate beyond the report or speculate, refuse and cite constraint §7 of this prompt.

### Phase 1 — INVENTORY (table-only)

| Metric | Count | Source paths |
|---|---|---|
| `case_studies_total` | | |
| `case_studies_with_yaml_frontmatter` | | |
| `case_studies_missing_required_field` (per the 7 fields per CLAUDE.md: `date_written`/`date`, `dispatch_pattern`, `success_metrics`/`primary_metric`, `kill_criteria`, `framework_version`, `work_type`, `tier_tags_present`) | | |
| `quantitative_claims_total` (regex `\b\d+(\.\d+)?%?\b`, exclude dates / PR numbers / commit SHAs / file paths / version strings) | | |
| `quantitative_claims_tagged_T1` | | |
| `quantitative_claims_tagged_T2` | | |
| `quantitative_claims_tagged_T3` | | |
| `quantitative_claims_untagged` | | |
| `T1_claims_with_ledger_reference` (cross-check `case-study-t1-references.json` + `measurement-adoption.json`) | | |
| `T1_claims_without_ledger_reference` | | |
| `kill_criteria_declared_total` | | |
| `kill_criteria_with_resolution_field` | | |
| `kill_criteria_missing_resolution` | | |
| `framework_versions_referenced` (unique set) | | |
| `prior_audits_in_bundle` | | |

### Phase 2 — DISCREPANCY schema

```json
{
  "id": "D-001",
  "claim_location": "docs/case-studies/foo.md:42",
  "claim_value": "92min stress-test wall time",
  "claim_tier_tag": "T1",
  "evidence_location": ".claude/shared/case-study-t1-references.json:18",
  "evidence_value": "92",
  "delta_type": "match | numeric_mismatch | missing_evidence | tier_label_mismatch | orphan_citation | broken_pr_reference | date_inconsistency",
  "delta_magnitude_if_numeric": null
}
```

Plus an `unstructured_observations[]` array for findings that do not fit. No `severity` field — the auditor does not rank.

### Phase 3 — CORRECTION schema

```json
{
  "id": "C-001",
  "type": "edit | delete | add_ledger_entry | retract_claim",
  "target_location": "docs/case-studies/foo.md:42",
  "current_text": "92min wall time",
  "proposed_text": "92min wall time [T1]",
  "rationale": "Tier tag missing; numeric value matches ledger at .claude/shared/case-study-t1-references.json:18. Adding [T1] makes the existing match explicit."
}
```

The `rationale` field is the only place interpretation is allowed, and is limited to "what mechanical evidence supports this correction."

### Refusal template

> Refused per prompt constraint §7. Auditor scope is bounded to inventory, discrepancy logging, and mechanical corrections. The original bundle is the ground truth; the operator's project owns interpretation.

---

## 8. Profile system

`scripts/audit/profiles/<name>.json` schema:

```json
{
  "profile_name": "v7-9-promotion",
  "description": "External Audit #1 — v7.9 promotion data + HADF Sub-exp 1 prereg",
  "inherits_from": "base",
  "additional_globs": [
    ".claude/shared/gate-coverage-weekly.jsonl",
    "docs/case-studies/meta-analysis/v7-9-measurement-window-2026-05-11.md",
    "docs/superpowers/specs/2026-05-11-hadf-phase2bis-replication-design.md"
  ],
  "additional_state_snapshot_features": ["hadf-phase2bis-replication"]
}
```

`inherits_from: base` means the profile pulls everything from `base.json` plus its `additional_globs`. Profiles never subtract — the discrepancy schema must stay portable across audits.

The five v0 profiles ship with this spec; new profiles can be added without changing the prompts.

---

## 9. Lifecycle integration

**Makefile additions:**

```make
audit-bundle:
	@if [ -z "$(PROFILE)" ]; then echo "Usage: make audit-bundle PROFILE=<name>"; exit 1; fi
	python3 scripts/audit/build-bundle.py --profile=$(PROFILE)

audit-prompts-self-check:
	python3 scripts/audit/check-prompts.py
```

`make audit-prompts-self-check` lints `01-extraction-prompt.md` and `02-auditor-prompt.md` for: placeholder strings (`TBD`, `TODO`), broken cross-refs to `scripts/audit/`, schema drift between the prompt's stated Phase 2 schema and `02-auditor-prompt.md`'s actual JSON block.

**CI integration:**

- `.github/workflows/audit-prompts-weekly.yml` runs `make audit-prompts-self-check` every Monday at 06:00 UTC (alongside the existing weekly framework-status cron). Opens an issue on failure.
- `.github/workflows/audit-bundle-on-tag.yml` runs `make audit-bundle PROFILE=<inferred>` whenever a tag matching `external-audit-*` is pushed. Uploads the bundle + manifest as a workflow artifact (90-day retention) so the operator does not have to manually re-extract for retrospective reproducibility.

**State.json integration:**

Add optional field `external_audit_schedule` to the schema (advisory; not gated in v0):

```json
"external_audit_schedule": [
  {"audit_date": "2026-05-22", "audit_label": "External Audit #1", "profile": "v7-9-promotion"},
  {"audit_date": "2026-06-12", "audit_label": "External Audit #2", "profile": "v7-9-1-f16-plus-hadf"}
]
```

Features tagged this way auto-include their case study + state.json in the relevant profile's bundle.

**Advisory cycle-time check** (new, advisory in v0):

`AUDIT_BUNDLE_HASH_DRIFT` — for each profile, compare current bundle hash against the hash recorded at the most recent audit run in `trust/audits/`. If the hash has changed, log an advisory pointing at the diff. This is expected (the corpus moves), but it gives the operator a single number to record per audit cycle.

---

## 10. Post-audit flow

When the auditor returns the 3-phase report:

1. Operator saves the report to `trust/audits/YYYY-MM-DD-<model>/report.md`.
2. Operator commits ALL per-run artifacts — `bundle.md`, `manifest.json`, `redaction-log.json`, plus the auditor's report. Only ad-hoc scratch (`runs/*/scratch/`, `runs/*/.cache/`, `runs/*/*.tmp`) stays gitignored. See §10 OQ #1 (RESOLVED 2026-05-19 as B10) for the rationale — the bundle is the canonical record of "what the auditor saw," and the audit findings reference specific text from it; without it, future readers can only trust the audit summary rather than verify the input. Repo growth is bounded to ~5-10 MB/year (8 audits/year × ≤500K-token bundles).
3. Operator opens a remediation issue/PR for each Phase 3 correction the team accepts. Each accepted correction is mechanical (a line edit, a ledger field addition, a retraction). No judgment calls deferred to "later."
4. A summary entry lands in `docs/audits/external-audit-stream.md` (new file, created with this spec — relocated from `docs/case-studies/meta-analysis/` per verification Patch A 2026-05-18 to avoid ambiguous interaction with the `CASE_STUDY_MISSING_TIER_TAGS` gate) — a single append-only log of "audit ran on date X with profile P; produced N discrepancies; M corrections accepted; K rejected with rationale."
5. The infra master plan §5 calendar is updated only if dates slip. The substrate itself does not need re-spec'ing per audit.

---

## 11. Cross-references back into the master plan

This spec adds the following backlinks (to be applied via a follow-up doc-sync PR after spec approval):

- `docs/master-plan/infra-master-plan-2026-05-12.md` — new §3.8 "External Audit Substrate" pointing here
- `docs/master-plan/infra-master-plan-2026-05-12.md` §5 calendar — annotate each external audit row with `(profile: <name>)`
- `docs/master-plan/infra-master-plan-2026-05-12.md` §6.1 unclosable-gap #5 — note that this substrate is the operational handle for the Tier 3.3 external replication gap
- `docs/master-plan/2026-05-12-consolidated-review-linear-notion-prep.md` — add a row to the Theme G test-discipline table pointing at Audit #2 (validates F16 fixture corpus)
- `CLAUDE.md` — add a one-line pointer under "Key Paths → Case studies": `External audit substrate: docs/audits/prompts/`
- `docs/case-studies/meta-analysis/unclosable-gaps.md` — annotate gap #5 with "operational handle: external audit substrate (this spec)"

---

## 12. Open questions

1. ~~**Bundle visibility in main repo.** Should `runs/YYYY-MM-DD-<model>/bundle.md` be committed to git, or stay gitignored with only the manifest committed?~~ **RESOLVED 2026-05-19 (B10):** commit per-run artifacts — `bundle.md`, `manifest.json`, `redaction-log.json`, plus the auditor's report — for public reproducibility. Rationale: the bundle is the canonical record of "what the auditor saw," and the audit findings reference specific text from it; without it, future readers can only trust the audit summary rather than verify the input. Repo growth is bounded: 8 audits/year (4 External + 4 Freshness) × ≤500K-token bundles ≈ 5-10 MB/year, fine for an audit-of-record. `redaction-log.json` contains only rule_counts (no un-redacted PII), so it's safe to commit. Only ad-hoc scratch (`runs/*/scratch/`, `runs/*/.cache/`, `runs/*/*.tmp`) stays gitignored. Implemented in `.gitignore` same-day.
2. **Auditor model rotation.** Should we always rotate auditor across External Audits (#1=Claude, #2=Gemini, #3=GPT, #4=Claude again) for cross-model triangulation, or stick with one model for cross-audit drift comparison? Recommend rotation, but flag for explicit operator decision.
3. **Profile inheritance depth.** Spec assumes `inherits_from` is a flat single-parent reference. If we later want compound profiles (e.g., `v8-0-gates-plus-hadf-closure` extending both `v7-9-promotion` AND `freshness`), schema needs a list. Defer until a profile actually needs it.
4. **Auditor failure mode.** What if the auditor returns a non-conforming report (skips the schema, adds prose to Phase 1)? Operator-side check script + a "re-prompt with constraint reminder" template? Sketch in v1; defer enforcement to v1.1.
5. **PII regex completeness.** The redaction regex set is exhaustive for known patterns in the current corpus, but a new case study might introduce a new PII pattern (e.g., a phone number, a new operator's email). `redaction-rules.py` includes a `--strict` mode that fails the build on any token matching a generic PII heuristic (email-shape, phone-shape, GUID-shape). Operator must explicitly allowlist or strengthen the rule.
6. **Run folder retention.** Should `runs/` purge after N audit cycles? Default proposal: keep forever, since per-run output is small (a manifest + redaction log + the auditor's report). Bundle.md may be the only large artifact and is regenerable from manifest hash + repo state at the time.

---

## 13. Success criteria

The substrate is successful if:

1. **2026-05-22 External Audit #1 runs through these prompts end-to-end** without operator-side hand-editing of bundle content or auditor prompt. (Primary T1 success metric — measurable: did the prompts work or didn't they?)
2. **Audit #2 (2026-06-12) bundle hash differs from Audit #1's** by exactly the diff explainable by intervening commits to the in-scope file set. (Measured via `git diff` between bundle generation timestamps.) Validates determinism.
3. **At least 80% of the auditor's Phase 3 corrections are mechanically applicable** (line-level edit, ledger addition, retraction) without further negotiation. (Measured by counting `current_text` / `proposed_text` pairs that resolve cleanly via `git apply` or equivalent.)

Kill criteria:

- If the first audit's auditor produces prose in Phase 1 despite the table-only constraint, the prompt has failed its mechanical guard. Revise constraint §2 with a stronger refusal template before audit #2.
- If the bundle exceeds 500K tokens on `base` profile and `--split-by-section` mode produces incoherent splits (auditor cannot cross-reference across splits), the architecture is wrong. Reconsider as a multi-bundle / agent-with-filesystem hybrid.

Resolution: tracked in `trust/audits/YYYY-MM-DD-<model>/post-audit-substrate-review.md` after each run.

---

## 14. Implementation plan handoff

Next step: invoke the `writing-plans` skill to produce the task list. Estimated scope: ~10-14 tasks across (a) `build-bundle.py` implementation, (b) 5 profile JSON files, (c) two prompt markdown files, (d) Makefile + CI workflows, (e) cross-reference doc-sync.

Target ship date: **2026-05-20 EOD** (two days before the first audit on 2026-05-22; keeps 1-day clear slack from the v7.9 promotion ceremony on 2026-05-21 — per verification Patch B 2026-05-18). If ship slips past 2026-05-21, the first audit reverts to hand-assembled bundle + best-effort prompt (matching the Gemini 2026-04-21 precedent), and the substrate ships for Audit #2.

**Off-docket classification:** v7.8.7 operability patch — no framework version bump, no new pre-commit gates, no calibration window required. Precedent: v7.8.5 observability layer + v7.8.6 cadence batch both shipped patch-level outside the F-docket. Confirmed by operator 2026-05-18.
