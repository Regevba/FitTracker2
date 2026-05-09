# Tasks — fitme-story-public-enhancements

**Created:** 2026-05-08
**Last reconciled:** 2026-05-08T21:30Z
**Source:** [audit synthesis](../../../docs/research/2026-05-08-fitme-story-audit-synthesis.md) §5 (10 net-new audit items + 6 pre-existing queue items)
**Total:** 23 tasks · **17 done** · 6 pending
**Effort estimate (pending only):** ~10 days (T10 search 2d + T18 0.25d + T19 1d + T12 5d + T20 1.5d + T13 0.5d)

Each task carries `audit_id` linking to its row in [`docs/superpowers/specs/2026-05-08-fitme-story-website-enhancement-queue.md`](../../../docs/superpowers/specs/2026-05-08-fitme-story-website-enhancement-queue.md) and `closes_findings` listing the underlying audit IDs (V-/A-/R-/CS-).

---

## ✅ Done (17 tasks)

### Shipped 2026-05-08 morning (T1-T7 quick-wins + ArticleNav)

| ID | audit_id | Title | PR | Merge | Closes |
|---|---|---|---|---|---|
| T1 | P-A11Y-1 | Skip-link + WCAG contrast bump | fitme-story #59 | `95cb4d1` 05:09:55Z | A-001 P0, A-002 P0, A-018 P0 |
| T2 | P-NAV-CHROME | aria-current + 2px underline + focus-visible ring + back-link toolbar | fitme-story #59 | `95cb4d1` | A-003 P1, V-003 P1, A-008 P1, V-007 P1, CS-015 P1 |
| T3 | P-MDX-HEADINGS | rehype-slug + rehype-autolink-headings | fitme-story #59 | `95cb4d1` | CS-007 P1 |
| T4 | P-MDX-TABLE | .prose table mobile overflow fix | fitme-story #59 | `95cb4d1` | CS-006 P1, CS-020 P0, R-009 P2 |
| T5 | P-CHROME-BACKFILL | chrome_minimal frontmatter schema | fitme-story #59 | `95cb4d1` | CS-008 P0 |
| T6 | P-TIMELINENAV | TimelineNav prev/next at template level | fitme-story #59 | `95cb4d1` | R-003 P1, CS-002 P1, CS-016 P0 |
| T7 | P-ARTICLENAV | ArticleNav sticky sidebar | fitme-story #61 | `a548e5f` 05:31:20Z | CS-001 P1, CS-010 P2, CS-013 P1, R-001 P1, R-002 P3, A-020 P2 |

### Shipped 2026-05-08 mid-day (P-* polish series + frontmatter audit)

| ID | audit_id | Title | PR | Merge | Closes |
|---|---|---|---|---|---|
| T16 | P-MOBNAV | MobileNav hamburger drawer | fitme-story #62 | `d560500` 08:16:40Z | **V-004 P0** (last open P0) |
| T17 | P-MDX-CODE | rehype-pretty-code + CopyButton MDX | fitme-story #65 | `ef1077f` 08:16:52Z | A-024, R-008, CS-004 |
| T9 | G5 | Frontmatter audit + backfill across 47 MDX files | fitme-story #67 | `e79bc8c` 09:33:35Z | corpus consistency |
| T15 | P-CALLOUTS | 5 callout components | fitme-story #66 | `3da5591` 13:02:54Z | CS-014, CS-024, partial CS-008 |
| T8 | G3 | Dual-outlet pattern doc (FT2↔fitme-story contract) | FT2 #260 | `2975e74` 08:15:33Z | foundational; unblocks G5 |
| T21 | FIG-W6 | fitme-story design architecture doc | FT2 #261 | `3176038` 13:04:45Z | architecture clarity |
| T22 | F7 | Cross-repo Tier 2.2 emission parity (documented exemption) | FT2 #258 | `02e3d8d` 13:02:49Z | v7.9 candidate F7 closed via [v7.8.2 spec](../../../docs/superpowers/specs/2026-05-08-cross-repo-gate-asymmetry.md) |
| T23 | F8 | Cross-repo Mechanism A gate-coverage parity (documented exemption) | FT2 #258 | `02e3d8d` | v7.9 candidate F8 closed via same spec |

### Shipped 2026-05-08 evening (SEO meta)

| ID | audit_id | Title | PR | Merge | Closes |
|---|---|---|---|---|---|
| T11 | SEO-1 | Marketing/showcase SEO optimization | fitme-story #63 | `83b1a89` 18:16:46Z | SEO/social-share |
| T14 | P-SEO-META | buildMetadata() helper (per-page OG + Twitter + JSON-LD) | fitme-story #63 | `83b1a89` 18:16:46Z | V-002, V-012, V-014 |

**Done count:** 17 tasks closing **26 audit findings** (6 P0 + 11 P1+P2+P3) + 2 cross-repo framework concerns (F7+F8) + foundational docs.

---

## 🔜 Ready to start (2 tasks, ~2.25 days)

| ID | audit_id | Title | Effort | Closes | Dependencies |
|---|---|---|---|---|---|
| T10 | SEARCH-1 | Site-wide keyword search (Pagefind + faceted filters) | 2.0d | discoverability gap | T8 ✓ T9 ✓ (both done now) |
| T18 | FIG-W1 | Create new Figma file ('FitMe Story Web — Design System') | 0.25d | foundational | none |

---

## ⛓ Blocked on dependencies (3 tasks, ~7.5 days)

| ID | audit_id | Title | Effort | Blocked on |
|---|---|---|---|---|
| T19 | FIG-W2 | Extract globals.css tokens to Figma variables | 1.0d | T18 |
| T12 | FIG-P4 | Figma screen frames for 35 public routes | 5.0d | T18 + T19 |
| T20 | FIG-W5 | Code Connect integration (Figma MCP) | 1.5d | T12 |

---

## ⏳ Date-gated (1 task, ~0.5 day post-2026-05-21)

| ID | audit_id | Title | Date | Why |
|---|---|---|---|---|
| T13 | V79-DOC | Mirror v7.9 promotion outcome to /framework/dev-guide | 2026-05-21 | Date-gated: nothing to mirror until v7.9 promotion decision happens |

---

## Sequencing recommendation (post-2026-05-08 reconciliation)

**Vehicle A — Site-wide search (1 PR, 2 days):**
- T10 (SEARCH-1) — independent, high-value visible feature; both deps cleared today

**Vehicle B — Figma sequence (4 PRs over 1-2 weeks):**
- T18 (FIG-W1, 0.25d) → T19 (FIG-W2, 1d) → T12 (FIG-P4, 5d) → T20 (FIG-W5, 1.5d)
- Total: ~7.75 days. T18 + T19 are foundational; T12 is the bulk; T20 is the close.

**Date-gated standalone:**
- T13 (V79-DOC, 0.5d) — fires post-2026-05-21 v7.9 promotion decision

---

## Completion criteria

This rollup feature reaches `current_phase: complete` when:

1. **All 23 tasks have terminal status:** `done` (shipped) OR explicit `deferred` with `defer_reason`. Currently 17/23 done.
2. **Case study written:** `docs/case-studies/fitme-story-public-enhancements-case-study.md`
3. **Showcase MDX published:** `fitme-story/content/04-case-studies/{slot}-fitme-story-public-enhancements.mdx`
4. **All 6 P0 audit findings closed** — ACHIEVED today (V-004 closed by T16 PR #62)
5. **No kill criterion fired** — Vercel JS error rate stable, CLS stable, no regression incidents

Per v7.8.1 FEATURE_CLOSURE_COMPLETENESS gate, the closing commit on `current_phase: complete` will be validated against the 7 required case-study frontmatter fields + Q7 kill_criteria_resolution + Q6 PR-list parity.
