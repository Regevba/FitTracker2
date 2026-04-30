---
# === FRONTMATTER (drives BOTH the per-case card AND the cross-case anthology table) ===
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

# --- Anthology table-row fields (these appear as columns at /control-room/case-studies) ---
anthology_row:
  primary_outcome: "Eight cooperating defenses for data at write/cycle/readout time; 7 of 8 shipped"
  cu: ~                       # not instrumented for this work type
  wall_time: ~3 working sessions across 4 days (T3)
  outlier: false
  kill_criterion_fired: false
  external_blocker: true       # one tier needs an independent operator

# --- Card fields (rendered on this page; ALSO surfaced in anthology hover/preview) ---
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

# --- Long-form body lives separately (one click deeper) ---
detailed_methodology_path: ./long-form/data-integrity-framework-v7.5-detailed.md
short_tier: true
---

{/* === RENDERED PER-CASE PAGE (THE WHOLE THING — TARGET: <60s READ) === */}

<SummaryCard />

<KillCriteriaPanel
  fired={false}
  threshold="any in-repo-unresolvable integrity-cycle regression triggers an external audit"
  evidence="None triggered to date" />

<KeyNumbersPanel />

<HonestDisclosuresPanel />

<DeferredItemsPanel>
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
</DeferredItemsPanel>

<PredecessorChain />

---

<DetailsToggle href={frontmatter.detailed_methodology_path}>
  View full methodology — Gemini audit deep-dive, all 8 defenses, end-to-end data
  flow, lessons (~270 lines, ~15 min read)
</DetailsToggle>

---

{/* === ALL THAT'S LEFT ON THIS PAGE IS LINKS === */}

<RelatedCaseStudies />
<AnthologyBackLink to="/control-room/case-studies" />

{/*
=== ALTERNATIVE B — DESIGN NOTES ===

What changed:
  1. The per-case page IS the card. ~80 lines of declarative MDX components.
     Renders in <60s. Long-form body moved to a sibling file under long-form/.
  2. Frontmatter expanded with tldr, key_numbers, honest_disclosures, kill_criteria,
     anthology_row block. The anthology_row drives the cross-case comparison table.
  3. Long body untouched in content — just relocated to:
     docs/case-studies/long-form/data-integrity-framework-v7.5-detailed.md
     (One click deeper via <DetailsToggle />.)

The primary surface is now the anthology:
  /control-room/case-studies — auto-built sortable table of all 47+ entries.
  Columns: version, work_type, ship_date, primary_outcome, kill_criterion_fired,
           external_blocker, wall_time, CU, outlier_flag, link.
  Each row links to this short page. Long-form is one click further.
  Hover preview = the SummaryCard (tldr + 3 key numbers + 2 disclosures).

Cost to migrate v2.0–v7.0 case studies:
  - Add ~10 frontmatter fields per file (about 2x more than Alternative A — the
    anthology_row block is the extra).
  - Move the existing body to docs/case-studies/long-form/{name}-detailed.md
    (rename + move, no content edits).
  - Build 6 MDX components in fitme-story (vs Alternative A's 3).

What this buys you that Alternative A doesn't:
  - One URL is the whole framework story (the anthology page).
  - First-time readers see the corpus AS one body of evidence.
  - Cross-case patterns are visually obvious (sortable column on
    kill_criterion_fired = which features killed what; sortable on outlier_flag =
    which features were the surprises).

What this costs that Alternative A doesn't:
  - Bigger IA shift. The "primary URL" of a case study is no longer its own
    deeply-narrative page; it's a card. People who linked to the long page from
    external sites need a redirect.
  - The anthology table puts numbers next to numbers across heterogeneous
    features. Easy to mislead a reader into apples-to-oranges comparisons.
    Mitigated by the T1/T2/T3 tier labels in every key_number AND by the
    explicit `outlier: true` flag in anthology_row.
*/}
