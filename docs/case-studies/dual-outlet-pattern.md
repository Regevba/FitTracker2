# Dual-Outlet Case-Study Pattern

**Created:** 2026-05-08
**Closes:** [fitme-story-public-enhancements](../../.claude/features/fitme-story-public-enhancements/state.json) T8 (audit ID **G3** — "consolidate the dual outlet (FitTracker2 long-form + fitme-story slot MDX) into a clear short/long pattern with a one-paragraph diff between the two")
**Source audit:** [`docs/research/2026-05-08-fitme-story-audit-synthesis.md`](../research/2026-05-08-fitme-story-audit-synthesis.md), [`docs/research/2026-05-08-case-study-readability-deep-dive.md`](../research/2026-05-08-case-study-readability-deep-dive.md)
**Unblocks:** T9 (G5 timeline frontmatter audit) — gives the audit a concrete contract to check against.

---

## §1 Why two outlets exist

Every shipped feature (per CLAUDE.md "every feature gets a case study" rule, est. 2026-04-13) reaches readers through **two parallel surfaces**:

| Surface | Who reads it | Tone | Length | Update cadence |
|---|---|---|---|---|
| **FT2 source case study** at `docs/case-studies/{slug}-case-study.md` | The framework's own bookkeeping + auditors + Claude in future sessions | Technical, append-only journal style | 5–26 KB (median ~6 KB) | Live during the feature's lifecycle; freezes at `current_phase: complete`; corrections appended (never silent edits) per the [verbatim-then-remediate rule](../../README.md) |
| **fitme-story slot MDX** at `fitme-story/content/04-case-studies/{slot}-{slug}.mdx` | Public site readers at https://fitme-story.vercel.app/case-studies/{slug} | Editorial, summary-first | 800–5,400 words (median ~1,470) | Written at Phase 8 (Documentation); only update for substantive corrections; chronological slot number reflects framework version under which the feature shipped (per [chronological-order rule](../../CLAUDE.md#case-studies)) |

The two outlets exist because **the framework's audit needs are not the public reader's reading needs**. The FT2 source is the "show your work" surface — every honest disclosure, every kill-criteria check, every cache hit, every retroactive correction. The fitme-story slot is the "tell the story" surface — what readers click through, share, and remember.

---

## §2 The one-paragraph diff

> The **FT2 source case study** is a live, append-only technical journal that captures every honest disclosure, every retroactive correction, every cache hit, every Tier 2.2 event, and the full §99 resolution log — written contemporaneously with the work, primarily for the framework's own bookkeeping (and external auditors who want to see the full work). The **fitme-story slot MDX** is a frozen-at-merge editorial summary written at Phase 8 — a short, scannable narrative with the [Alternative A chrome](../design-system/case-study-visual-aid-catalog.md) (`tldr` + `key_numbers` + `honest_disclosures` + `kill_criteria` + `deferred_items` + `visual_aid`) that lives at `fitme-story.vercel.app/case-studies/{slug}` for the public reader. When they conflict, **the FT2 source wins** (and the slot MDX gets updated to reflect the FT2 truth, not the other way around).

---

## §3 Frontmatter contract — per outlet

### FT2 source case study

Lives at `docs/case-studies/{slug}-case-study.md`. Markdown frontmatter is **optional**, but **at least these fields** when present (gated by the v7.8.1 `FEATURE_CLOSURE_COMPLETENESS` gate when `state.json::current_phase` transitions to `complete`):

| Field | Required for closure? | Type | Notes |
|---|---|---|---|
| `date` or `date_written` | Yes | ISO 8601 (YYYY-MM-DD) | Either field name accepted |
| `dispatch_pattern` | Yes | string | "serial", "parallel", "stacked_prs", "serial_per_sub_task", etc. |
| `success_metrics` or `primary_metric` | Yes | array of strings or single object | Either accepted |
| `kill_criteria` | Yes | array of strings | Even when no kill criteria fire — required for closure |
| `kill_criteria_resolution` | Yes when `kill_criteria` set | string | Q7 of v7.8.1: documents what happened (e.g., "0 kill criteria breached") |
| `framework_version` | Yes | string `vN.N.N` | Auto-populated by feature folder; `framework_version: vX.Y` canonical form |
| `work_type` | Yes | enum: feature \| enhancement \| fix \| chore | Per CLAUDE.md "Work Item Types" |
| `tier_tags_present` | Yes (post-2026-04-21) | boolean | True if body has at least one T1/T2/T3 tag near a quantitative claim |
| `case_study_type` | No (only for backfills) | enum: pre_pm_workflow_backfill \| roundup \| no_case_study_required \| framework_meta_retroactive | Bypasses sub-phase vocabulary check |
| `pr_citation_exempt` | No | array of `{pr_number, reason}` | Override for Q6 PR-list parity check |

Body conventions:

- **§1 Why this exists** — motivation, predecessor chain, trigger incidents
- **§2 What was done** — approach summary
- **§3 Method / hypothesis** (experiment-type only) — pre-registered hypotheses
- **§4 Observation log** — append-only contemporaneous events
- **§99 Resolution log / synthesis** — outcome + verdicts + sub-feature ledger + v7.X candidates surfaced (the heaviest section; can have 8+ sub-sections)
- T1/T2/T3 tier tags inline near every quantitative claim (per [data-quality-tiers.md](./data-quality-tiers.md))
- "Honest Disclosure" callouts where appropriate (current — promoted to standardized component in T15 P-CALLOUTS)

### fitme-story slot MDX

Lives at `fitme-story/content/04-case-studies/{slot}-{slug}.mdx`. Frontmatter is **enforced by Zod schema** at `fitme-story/src/lib/content-schema.ts`. Required fields:

| Field | Required? | Type | Notes |
|---|---|---|---|
| `title` | Yes | string | Heading shown above the SummaryCard |
| `slug` | Yes | string | URL slug (must match the file path's `{slug}`) |
| `tier` | Yes | enum: flagship \| standard \| light \| appendix \| ops-combined \| unassigned | Determines which template renders |
| `tldr` | Yes (gated by Zod) | string | 1–3 sentences; rendered as the SummaryCard hook |
| `visual_aid` OR `key_numbers` | Yes (gated by Zod) | object \| array | Either a `<VisualAidResolver>` component spec OR a non-empty `key_numbers[]` array (renders the fallback `<KeyNumbersChart>`) |
| `timeline_position` | Optional but strongly recommended | `{ version, order }` | Drives chronological ordering on `/case-studies` catalog + `/timeline/{version}` pages |
| `date` | Optional | ISO 8601 | Rendered in SummaryCard |
| `key_numbers` | Optional (when `visual_aid` present) | array of `{label, value, tier}` | Each carries T1/T2/T3 tier badge |
| `honest_disclosures` | Optional but **strongly recommended** | array of strings | Rendered as a separate section in SummaryCard |
| `kill_criteria` | Optional | array of strings | Rendered with green/coral KillCriterionBanner depending on `kill_criterion_fired` |
| `kill_criterion_fired` | Optional | boolean | Drives banner color |
| `deferred_items` | Optional | array of `{title, ledger, reason}` | Rendered as DeferredItemsList |
| `chrome_minimal` | Optional | boolean | T5 ship 2026-05-08; explicit opt-out signal when frontmatter is intentionally bare |
| `chrome_minimal_reason` | Required when `chrome_minimal: true` | string | Documents why bare chrome is intentional |
| `upstream_path` | Optional | string | Path to the FT2 source case study (enables the "see upstream Section 99" bridge convention §4) |
| `upstream_sha` | Optional | string | Last-known FT2 commit SHA the slot MDX was synced against |

Body conventions:

- **Short and editorial** — abbreviates §99 sub-trees with "see upstream Section 99" pointers (per §4)
- **Heading hierarchy stays h2 → h3** (no h4); §99.1–§99.8 lives ONLY in FT2 source
- **§ symbol notation** is consistent in v7.5+ entries; absent from earlier
- **Tables** wrapped via `.prose table { display: block; overflow-x: auto; }` (T4 ship 2026-05-08)
- **Code blocks** rendered via Tailwind typography defaults; T17 P-MDX-CODE will add `rehype-pretty-code` + `<CopyButton>` 

---

## §4 The "see upstream Section 99" bridging convention

When the FT2 source case study has a heavy §99 resolution log (typical for v7.5+ entries with 8+ sub-sections), the fitme-story slot MDX should:

1. **NOT replicate** the §99 sub-tree
2. Replace it with a brief paragraph + a pointer:
   > "The full resolution log — sub-feature ledger, hypothesis verdicts, v7.X candidates surfaced, PRD-vs-execution gap analysis — lives in the [upstream Section 99](https://github.com/Regevba/FitTracker2/blob/main/docs/case-studies/{slug}-case-study.md#99-resolution-log)."
3. Use `upstream_path` frontmatter to make the link discoverable + machine-checkable

**Why:** the showcase MDX is the "story" surface; the FT2 source is the "audit trail" surface. Readers who want the audit click through; readers who want the story stay on fitme-story.

---

## §5 When to write where

| Scenario | FT2 source | fitme-story slot | Notes |
|---|---|---|---|
| Feature reaches `current_phase: complete` | **REQUIRED** (gated by FEATURE_CLOSURE_COMPLETENESS) | **REQUIRED** (per chronological-order rule) | Both at Phase 8 (Documentation) |
| Feature shipped pre-2026-04-13 (when "every feature gets a case study" rule landed) | Backfilled with `case_study_type: pre_pm_workflow_backfill` (sub-phase vocab check bypassed) | Optional — slot MDX can be `tier: unassigned` to opt out of the visual-aid Zod requirement | These are historical; don't force-fit modern chrome |
| Framework version meta feature (v5.0 SoC, v5.2 dispatch, v6.0 measurement, v7.0 meta-analysis, v7.1 integrity) | Backfilled with `case_study_type: framework_meta_retroactive` | Slot MDX optional | These predate spec discipline |
| Roundup / multi-feature roll-up (e.g., M-1 SettingsView Decomposition aggregating PRs #122–#125) | `case_study_type: roundup` | Single slot MDX is fine; doesn't need to mirror every constituent PR | The FT2 roundup case study is the place for per-PR detail |
| Patch-level framework bump (e.g., this v7.8.2 ship) | Optional — usually inline in the spec doc + CLAUDE.md is enough | Optional — the dev-guide page already mirrors via T13 V79-DOC | Patch bumps don't always warrant a dedicated case study |
| Pre-launch experiment / hypothesis-refuted | Required if shipped to main; mark `experiment: true` and use `experiment_outcome` enum (T10 v7.9 candidate F10) | Optional — only if the experiment merits a public showcase | The roadmap stress-test 2026-05-07 is an example: shipped both a FT2 source and a fitme-story slot |

---

## §6 Sync & drift

The fitme-story slot MDX is **NOT auto-synced** from the FT2 source. They are separate documents that get written at different times.

**At Phase 8 (Documentation):**
1. Write the FT2 source case study first (it's the canonical record)
2. Then write the fitme-story slot MDX, summarizing the FT2 source for the public reader
3. Both ship via separate PRs (FT2 PR for source, fitme-story PR for slot)

**Post-merge corrections:**
- FT2 source: append to the §99 resolution log (never silent-edit) per the [verbatim-then-remediate rule](../../README.md)
- fitme-story slot: update only for substantive corrections (factual errors, broken links, security issues); minor copy edits should batch into a quarterly cleanup pass

**When in doubt: the FT2 source wins.** If the slot MDX says X but the FT2 source says Y, the slot MDX gets updated to match Y (not the other way around).

---

## §7 Audit checklist for G5 (T9 — timeline frontmatter audit)

This contract enables T9 (G5 timeline frontmatter audit) to walk all 47 fitme-story slot MDX files and check each against the §3 frontmatter contract above. The G5 audit should:

1. Parse each `fitme-story/content/04-case-studies/*.mdx` frontmatter
2. For each file, check:
   - Required fields per §3 (`title`, `slug`, `tier`, `tldr`, `visual_aid` OR `key_numbers`)
   - Strongly-recommended fields (`honest_disclosures`, `timeline_position`)
   - Optional but high-value fields (`kill_criteria`, `kill_criterion_fired`, `deferred_items`, `upstream_path`)
3. Bucket each file:
   - **Compliant** (all required + most recommended)
   - **Bare-but-intentional** (`chrome_minimal: true` + `chrome_minimal_reason` set; opt-out from T5)
   - **Bare-without-reason** (missing chrome AND no opt-out signal — these need either backfill or `chrome_minimal: true` retro-applied)
   - **Pre-PM-workflow backfill** (case_study_type set; sub-phase vocab bypassed)
4. Report counts + per-file disposition recommendations
5. Optionally: for "bare-without-reason" files, propose backfill text or recommend the opt-out signal

The audit synthesis already shows the corpus-wide numbers from the 2026-05-08 deep-dive: **5 missing `honest_disclosures`, 6 missing `visual_aid`, 27 missing `kill_criteria`** out of 47 files.

T9 will add per-file dispositions on top of those counts and produce a backfill plan.

---

## §8 Cross-references

- **Audit synthesis** that surfaced G3 + G5: [`docs/research/2026-05-08-fitme-story-audit-synthesis.md`](../research/2026-05-08-fitme-story-audit-synthesis.md)
- **Audit deep-dive** that quantified the corpus-wide gaps: [`docs/research/2026-05-08-case-study-readability-deep-dive.md`](../research/2026-05-08-case-study-readability-deep-dive.md)
- **Visual-aid catalog** referenced in fitme-story Zod schema: [`docs/design-system/case-study-visual-aid-catalog.md`](../design-system/case-study-visual-aid-catalog.md)
- **Data-quality tiers convention** (T1/T2/T3 inline tags): [`docs/case-studies/data-quality-tiers.md`](./data-quality-tiers.md)
- **Chronological-order rule** for showcase slot numbering: CLAUDE.md "Case studies" section
- **FEATURE_CLOSURE_COMPLETENESS gate** that enforces FT2 source at closure: CLAUDE.md "Data Integrity Framework" section
- **fitme-story Zod schema:** `fitme-story/src/lib/content-schema.ts`
- **chrome_minimal opt-out signal** (added 2026-05-08 in T5): `fitme-story/src/lib/content-schema.ts` `FrontmatterShape` + `chrome_minimal_reason` validator
- **rollup feature tracking T8 + T9:** `.claude/features/fitme-story-public-enhancements/state.json`

---

## §9 What this doc is NOT

- **Not a templating engine.** It's a contract document — humans (and Claude) write to the contract; no code auto-generates either outlet from the other.
- **Not a sync tool.** The fitme-story `prebuild` script syncs `src/data/*` from FT2 main, but it does NOT touch `content/04-case-studies/*.mdx`. Slot MDX files are hand-authored at Phase 8.
- **Not a closure gate.** The FEATURE_CLOSURE_COMPLETENESS gate validates the FT2 source case-study fields per §3. Slot MDX presence is verified per the chronological-order rule but is not a hard gate today.
- **Not an immutable spec.** When new audit findings produce new conventions (e.g., the T5 `chrome_minimal` opt-out signal), this doc gets updated. Last update: 2026-05-08.
