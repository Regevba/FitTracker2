---
# === FRONTMATTER (source of truth — drives the rendered card) ===
title: "Data Integrity Framework — v7.5"
date_written: 2026-04-24
ship_date: 2026-04-24
work_type: framework_infrastructure
dispatch_pattern: mostly_serial_with_one_parallel_session
framework_version: v7.1 → v7.5
status: shipped
trigger: "Google Gemini 2.5 Pro independent audit (2026-04-21)"
predecessor_case_studies:
  - integrity-cycle-v7.1-case-study.md
  - meta-analysis/meta-analysis-2026-04-21.md

# --- New v7.5 fields the SummaryCard reads ---
tldr: "An independent audit surfaced eight cooperating defenses that now catch broken data at write-time, cycle-time, and readout-time. Seven shipped; one is external-blocked; honest-status labels are the new default."

key_numbers:
  - label: "Tier recommendations shipped"
    value: "7 of 8"
    tier: T1
  - label: "Auditor check codes"
    value: "8 → 11"
    tier: T1
  - label: "Integrity findings (corpus baseline)"
    value: "0 across 40 features + 46 case studies"
    tier: T1

honest_disclosures:
  - "`cache_hits[]` populated in 0/40 features — v6.0 schema exists, writer path not exercised. Tracked at issue #140."
  - "Tier 3.2 trend mode awaits 3 scheduled cycle snapshots (~9 days wall-clock); baseline mode usable now."
  - "Tier 3.3 (external replication) cannot be self-executed; remains backlog."

success_metrics:
  primary: "Integrity cycle findings: 0 across 40 features + 46 case studies (preserved through 20+ commits)"
  secondary:
    - "Schema drift gated at write-time: 0 violations"
    - "PR citations gated at write-time: 0 false-resolutions"
    - "5 contemporaneous feature logs active (was 0)"

kill_criteria:
  - "Any integrity-cycle regression that can't be resolved in-repo triggers an on-demand external audit"
kill_criterion_fired: false
---

{/* === CARD HEADER (rendered by fitme-story; degrades to readable text in raw .md) === */}

<SummaryCard />

<KillCriterionFired status="none" />

<DeferredItem
  title="cache_hits writer path"
  ledger="issue #140"
  reason="v6.0 schema exists; no session writer appends" />

<DeferredItem
  title="Tier 3.2 trend mode"
  ledger=".claude/integrity/snapshots/"
  reason="wall-clock — needs 3 scheduled 72h snapshots" />

<DeferredItem
  title="Tier 3.3 external replication"
  ledger="backlog"
  reason="cannot be self-executed; needs independent operator" />

---

{/* === EVERYTHING BELOW IS THE EXISTING 276-LINE BODY, UNCHANGED === */}

# Data Integrity Framework — v7.5 Case Study

## 1. Why This Case Study Exists

The v7.1 Integrity Cycle (2026-04-21) shipped self-observation: a 72h GitHub Actions job that audits every `state.json` for drift...

[... full existing body remains exactly as written ...]

## 2. Summary Card

[The legacy in-body summary section can either stay (read by humans browsing the .md
directly) or be deleted in favor of the rendered <SummaryCard /> above. Recommended:
keep for the first wave; remove on a later pass once the rendered card is trusted.]

## 3. The Gemini audit — inputs, process, and one learning-loop discovery

[... unchanged ...]

## 4. The eight defenses of v7.5

[... unchanged ...]

## 5. How a new feature is now measured (end-to-end data flow)

[... unchanged ...]

## 6. What earned the bump from v7.1 to v7.5

[... unchanged ...]

## 7. What did NOT ship in v7.5

[... unchanged ...]

## 8. Lessons

[... unchanged ...]

## 9. Links

[... unchanged ...]

{/*
=== ALTERNATIVE A — DESIGN NOTES ===

What changed:
  1. Frontmatter expanded with: tldr, key_numbers, honest_disclosures, kill_criterion_fired.
     These are the inputs the rendered <SummaryCard /> reads.
  2. Three MDX components rendered above the body: <SummaryCard />, <KillCriterionFired />,
     <DeferredItem /> (one per honest disclosure).
  3. Body untouched. Section 1-9 reads identically to the v7.5 ship.

What stays the same:
  - The 276-line narrative body.
  - The case-study URL (still data-integrity-framework-v7.5-case-study).
  - Reading order: card first, then narrative.

Cost to migrate v2.0–v7.0 case studies:
  - Add ~6 frontmatter fields + 0–3 MDX component lines per file.
  - No body editing required.
  - One new MDX component to build (SummaryCard + KillCriterionFired + DeferredItem
    is one component bundle in fitme-story).

Comparison table at /control-room/case-studies:
  - Auto-built at compile time from frontmatter across all 47+ files.
  - Sortable by version / work_type / kill_criterion_fired / ship_date.
  - Read-only roll-up of what each card already declares.
*/}
