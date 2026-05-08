# Tasks — fitme-story-public-enhancements

**Created:** 2026-05-08
**Source:** [audit synthesis](../../../docs/research/2026-05-08-fitme-story-audit-synthesis.md) §5 (10 net-new audit items + 6 pre-existing queue items)
**Total:** 23 tasks · 7 done · 16 pending
**Effort estimate (pending only):** ~21 days

Each task carries `audit_id` linking to its row in [`docs/superpowers/specs/2026-05-08-fitme-story-website-enhancement-queue.md`](../../../docs/superpowers/specs/2026-05-08-fitme-story-website-enhancement-queue.md) and `closes_findings` listing the underlying audit IDs (V-/A-/R-/CS-).

---

## ✅ Done (7 tasks, shipped 2026-05-08)

| ID | audit_id | Title | PR | Merge | Closes |
|---|---|---|---|---|---|
| T1 | P-A11Y-1 | Skip-link + WCAG contrast bump (light-mode --color-neutral-500) | fitme-story #59 | `95cb4d1` 05:09:55Z | A-001 P0, A-002 P0, A-018 P0 |
| T2 | P-NAV-CHROME | aria-current + 2px underline + focus-visible ring + back-link toolbar | fitme-story #59 | `95cb4d1` | A-003 P1, V-003 P1, A-008 P1, V-007 P1, CS-015 P1 |
| T3 | P-MDX-HEADINGS | rehype-slug + rehype-autolink-headings (deep-link any heading) | fitme-story #59 | `95cb4d1` | CS-007 P1 |
| T4 | P-MDX-TABLE | .prose table display:block + overflow-x:auto (mobile fix corpus-wide) | fitme-story #59 | `95cb4d1` | CS-006 P1, CS-020 P0, R-009 P2 |
| T5 | P-CHROME-BACKFILL | chrome_minimal opt-out signal in frontmatter schema | fitme-story #59 | `95cb4d1` | CS-008 P0 |
| T6 | P-TIMELINENAV | Wire TimelineNav prev/next at template level | fitme-story #59 | `95cb4d1` | R-003 P1, CS-002 P1, CS-016 P0 |
| T7 | P-ARTICLENAV | ArticleNav sticky sidebar (TOC + scroll progress + IntersectionObserver) | fitme-story #61 | `a548e5f` 05:31:20Z | CS-001 P1, CS-010 P2, CS-013 P1, R-001 P1, R-002 P3, A-020 P2 |

**Done count:** 7 tasks closing **17 audit findings** (6 P0 + 11 P1+P2+P3).

---

## 🔜 Ready to start (Claude-doable now, 11 tasks)

### Public-site track

| ID | audit_id | Title | Effort | Closes | Dependencies |
|---|---|---|---|---|---|
| T8 | G3 | Dual-outlet pattern doc (FT2 long-form vs fitme-story slot MDX contract) | 0.5d | (foundational; blocks T9) | none |
| T10 | SEARCH-1 | Site-wide keyword search (Pagefind + faceted filters) | 2.0d | discoverability gap | T8 + T9 |
| T11 | SEO-1 | Marketing/showcase SEO (metadata + JSON-LD + sitemap + OG) | 1.0d | SEO/social-share | T14 |
| T14 | P-SEO-META | buildMetadata() helper (per-page openGraph + Twitter + JSON-LD) | 1.0d | V-002, V-012, V-014 | none |
| T15 | P-CALLOUTS | Callout component family (HonestDisclosure / TriggerIncident / MemoryRef / PredecessorChain / KillCriterionResolution) | 2.0d | CS-014, CS-024, partial CS-008 | none |
| **T16** | **P-MOBNAV** | **Mobile hamburger nav (focus-trapped Dialog) — closes the only remaining P0** | **1.0d** | **V-004 P0** | **none** |
| T17 | P-MDX-CODE | rehype-pretty-code + CopyButton MDX component | 1.0d | A-024, R-008, CS-004 | none |

### Shared infrastructure track

| ID | audit_id | Title | Effort | Closes | Dependencies |
|---|---|---|---|---|---|
| T18 | FIG-W1 | Create new Figma file ('FitMe Story Web — Design System') | 0.25d | foundational | none |
| T21 | FIG-W6 | Architecture doc (docs/design-system/fitme-story-design-architecture.md) | 0.5d | architecture clarity | none |
| T22 | F7 | Tier 2.2 per-phase emission gate parity for fitme-story OR exemption doc | 1.0d | v7.9 candidate F7 | none |
| T23 | F8 | Mechanism A gate-coverage.jsonl parity for fitme-story OR exemption doc | 1.0d | v7.9 candidate F8 | none |

---

## ⛓ Blocked on dependencies (5 tasks)

| ID | audit_id | Title | Blocked on | Why |
|---|---|---|---|---|
| T9 | G5 | Timeline frontmatter audit (47 showcase MDX files) | T8 | needs G3's contract to know what 'complete frontmatter' means |
| T12 | FIG-P4 | Figma screen frames for 35 public routes | T18 + T19 | needs Figma file + tokens before frame work begins |
| T19 | FIG-W2 | Extract globals.css tokens to Figma variables | T18 | needs Figma file first |
| T20 | FIG-W5 | Code Connect integration (Figma MCP) | T12 | runs after public route frames land |

---

## ⏳ Date-gated (1 task)

| ID | audit_id | Title | Date | Why |
|---|---|---|---|---|
| T13 | V79-DOC | Mirror v7.9 promotion outcome to /framework/dev-guide | 2026-05-21 | Date-gated: nothing to mirror until v7.9 promotion decision happens |

---

## Sequencing recommendation

**Vehicle 1 — Mobile-nav P0 (1 PR, ~1 day):**
- T16 (P-MOBNAV) — closes the one remaining P0; biggest user-impact gap

**Vehicle 2 — SEO + metadata (1 PR, ~2 days):**
- T14 (P-SEO-META) → T11 (SEO-1) — coherent narrative; #11 builds on #14's helper

**Vehicle 3 — Case-study refinement narrative (3 PRs, ~4 days total):**
- T8 (G3) → T9 (G5) → T10 (SEARCH-1) — coherent chain; G3 unblocks G5; G5 sharpens SEARCH-1's facets

**Vehicle 4 — MDX pipeline polish (1 PR, ~1 day):**
- T17 (P-MDX-CODE) — independent, ships anytime

**Vehicle 5 — Callouts (1 PR, ~2 days):**
- T15 (P-CALLOUTS) — independent, ships anytime; high reader-experience leverage

**Vehicle 6 — Figma track (multiple PRs over weeks):**
- T18 → T19 + T21 → T12 → T20 — Figma sequencing; T21 (architecture doc) can run parallel with T19

**Vehicle 7 — Cross-repo gate parity (1 small PR or 2 doc PRs):**
- T22 + T23 — likely "document the asymmetry" rather than build; small scope

**Date-gated standalone:**
- T13 (V79-DOC) — fires post-2026-05-21

---

## Completion criteria

This rollup feature reaches `current_phase: complete` when:

1. **All 23 tasks have terminal status:** `done` (shipped) OR explicit `deferred` with `defer_reason`
2. **Case study written:** `docs/case-studies/fitme-story-public-enhancements-case-study.md`
3. **Showcase MDX published:** `fitme-story/content/04-case-studies/{slot}-fitme-story-public-enhancements.mdx`
4. **All 6 P0 audit findings closed** (currently 6/6 closed via PR #59 + #61) — already met
5. **Mobile nav P0 (V-004) closed** via T16 — only remaining P0
6. **No kill criterion fired** — Vercel JS error rate stable, CLS stable, no regression incidents

Per v7.8.1 FEATURE_CLOSURE_COMPLETENESS gate, the closing commit on `current_phase: complete` will be validated against the 7 required case-study frontmatter fields + Q7 kill_criteria_resolution + Q6 PR-list parity.
