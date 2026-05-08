# fitme-story Public Site Audit — Consolidated Synthesis

**Synthesis date:** 2026-05-08
**Source audits (read-only):**
- [`2026-05-08-fitme-story-public-site-audit.md`](./2026-05-08-fitme-story-public-site-audit.md) — broad audit (54 findings: 12 V + 24 A + 18 R)
- [`2026-05-08-case-study-readability-deep-dive.md`](./2026-05-08-case-study-readability-deep-dive.md) — narrow audit (28 CS findings, 6 case studies sampled)
- Combined raw: ~82 findings; **after dedup: ~30 unique action items**

---

## §1 Executive Summary

The fitme-story public site is **structurally sound but under-instrumented for long-form reading**. The 2026-04-28 case-study chrome refactor gave entries a strong above-the-fold contract; six weeks later that contract has silently regressed on the 5 newest case studies (CS-008), and the empty 280px desktop sidebar slot in 2 of 3 templates is a literal void where readers expect navigation to live. Across both audits, the highest-leverage architectural move (populate the empty sidebar with `<ArticleNav>`) closes 8+ findings in one PR.

| Dimension | Health | Verdict |
|---|---|---|
| Visibility | Moderate | Catalog narrative thoughtful; cross-CS linking sparse; per-page social/OG metadata almost absent |
| Accessibility | Moderate-low | Strong groundwork (semantic HTML, prefers-reduced-motion, dark-mode contrast overrides) undermined by 3 P0 violations |
| Readability — page chrome | **Strong** | Editorial type system well-tuned (clamp scale, 65ch measure, 1.7 line-height) |
| Readability — long-form scaffolding | **Weak** | No TOC, no scroll progress, no prev/next, no related-cases on 26 case studies |

---

## §2 Six P0 findings (combined, must-fix)

| ID | Finding | Effort | Source |
|---|---|---|---|
| **A-001** | No skip-to-content link · `<main>` has no `id` (WCAG 2.4.1) | S | Site audit |
| **A-002 + A-018** | Light-mode `--color-neutral-500` (#78716C) on neutral-50 = 4.16:1 (AA needs 4.5:1). Affects footer, catalog secondary text, all uppercase tracking-wider labels, DevDive header | S | Site audit |
| **V-004** | Mobile nav (<768px) has NO fallback — all 7 nav items disappear, no hamburger | M | Site audit |
| **CS-008** | Bimodal frontmatter chrome adoption — 5 newest entries (slots 23a, 23b, 23c, 25, 26) silently drop `honest_disclosures` + `visual_aid`. Same template, different reader contract | M | Case-study deep-dive |
| **CS-016** | `TimelineNav` component exists, registered, but **never used** in 47 MDX files. ~30-min fix wires prev/next from `getAllCaseStudies()` — converts isolated articles into a navigable timeline | S | Case-study deep-dive |
| **CS-020** | Tables inside `prose-lg` overflow body container at 375px mobile. Single CSS rule fixes corpus-wide | S | Case-study deep-dive |

---

## §3 Quick wins — ship-this-week pile (12 items, all P0/P1 with effort=S)

| # | ID(s) | Action | Closes |
|---|---|---|---|
| 1 | A-001 | Add skip-to-content link in `layout.tsx`, give `<main>` `id="main"` | 1 P0 |
| 2 | A-002 + A-018 | Bump light-mode `--color-neutral-500` to `#5C5754` (≥ 4.7:1) | 2 P0 |
| 3 | A-003 + V-003 | Add `aria-current="page"` + 2px underline on nav via `usePathname()` | 2 P1 |
| 4 | A-008 | Global `.focus-ring` utility on header/footer/cards | 1 P1 |
| 5 | A-014 | Rewrite design-system screenshot `alt` text to describe content | 1 P1 |
| 6 | A-019 | Move `<h1>` out of SummaryCard back into `<header>` always | 1 P1 |
| 7 | V-007 + CS-015 | Add "← Case studies" back-link to all 3 templates (with copy-link affordance) | 2 P1 |
| 8 | R-003 + CS-002 + CS-016 | **Wire `<TimelineNav>` at template level**, derive prev/next from sorted `getAllCaseStudies()` | 1 P0 + 2 P1 |
| 9 | CS-006 + CS-020 + R-009 | Add `.prose table { display: block; overflow-x: auto; }` corpus-wide | 1 P0 + 2 P1 |
| 10 | CS-007 | Add `rehype-slug` + `rehype-autolink-headings` to `compileMDX` | 1 P1 |
| 11 | CS-019 | On Standard/Flagship: drop empty aside until populated by ArticleNav | 1 P1 |
| 12 | CS-008 | Add `chrome_minimal: true` opt-out signal OR backfill 5 recent entries | 1 P0 |

**Estimated total effort:** ~1 focused day. Closes **6 P0s + 11 P1s**.

---

## §4 Five strategic recommendations

| # | Recommendation | Closes | Source |
|---|---|---|---|
| **S1** | **Build `<ArticleNav>` to populate empty `<aside>` slot** — sticky in-page TOC + scroll progress + prev/next + back-to-index + copy-link button | 8+ findings: CS-001, CS-002, CS-010, CS-013, CS-015, CS-016, CS-017, CS-019, V-001, V-007, R-001, R-002, R-003, A-020 | Both audits agreed |
| **S2** | **Build `buildMetadata()` helper for per-page OG + Twitter + JSON-LD** | V-002, V-012, V-014 | Site audit |
| **S3** | **Introduce a callout component family** — `<HonestDisclosure>`, `<TriggerIncident>`, `<MemoryRef>`, `<PredecessorChain>`, `<KillCriterionResolution>` | CS-014, CS-024, partial CS-008 | Case-study deep-dive |
| **S4** | **Wire `rehype-pretty-code` (or shiki) into MDX pipeline** | A-024, R-008, CS-004 | Both audits |
| **S5** | **Build `<MobileNav>` as a separate component** — hamburger opens focus-trapped Dialog with full nav + theme toggle | V-004, partial V-005, V-009, A-001 | Site audit |

---

## §5 Updated public-site enhancement queue (was 6 → now 16 items)

The audits surfaced 10 net-new public-site items. Slotting into the existing queue:

### Net-new (10 from audit)

| ID | Item | Class | Effort |
|---|---|---|---|
| **P-A11Y-1** | Skip-to-content + WCAG contrast bundle (A-001 + A-002 + A-018) | P0 quick-wins | S |
| **P-NAV-CHROME** | Current-page indicator + focus-visible ring + back-to-catalog (Quick wins #3, #4, #7) | P1 quick-wins | S |
| **P-MDX-HEADINGS** | rehype-slug + rehype-autolink-headings (CS-007) | P1 quick-win | S |
| **P-MDX-TABLE** | Mobile table overflow CSS rule (CS-020) | P0 quick-win | S |
| **P-CHROME-BACKFILL** | Frontmatter chrome backfill on 5 recent entries OR explicit opt-out signal (CS-008) | P0 | S |
| **P-TIMELINENAV** | Wire TimelineNav at template level (CS-016) | P0 quick-win | S |
| **P-ARTICLENAV** | Sidebar `<ArticleNav>` component (S1) — **single highest leverage** | Strategic | M |
| **P-SEO-META** | `buildMetadata()` helper + JSON-LD + OG cards (S2) | Strategic | M |
| **P-CALLOUTS** | Callout component family (S3) | Strategic | L |
| **P-MDX-CODE** | rehype-pretty-code + CopyButton (S4) | Strategic | M |
| **P-MOBNAV** | Mobile hamburger nav (S5) | Strategic | M |

### Pre-existing (6, with audit input)

| ID | Item | Audit input |
|---|---|---|
| **G3** | Dual-outlet pattern doc | CS-014, CS-008, CS-027 confirm what's worth standardizing |
| **G5** | Timeline frontmatter audit | Audit corpus-wide grep: 5 of 47 missing `honest_disclosures`, 6 missing `visual_aid`, 27 missing `kill_criteria` |
| **SEARCH-1** | Site-wide keyword search | V-008/V-016/V-018 confirm discoverability gap |
| **SEO-1** | Marketing/showcase SEO | Reinforced by P-SEO-META above (could be merged) |
| **FIG-P4** | Figma screen frames for 35 public routes | No audit overlap |
| **V79-DOC** | v7.9 dev-guide mirror | No audit overlap |

---

## §6 Suggested execution sequence (Claude-doable subset)

The audit findings naturally cluster into 3 ship vehicles:

### Vehicle 1 — Quick wins bundle (1 PR, ~1 day)
12 items above. Closes 6 P0s + 11 P1s. No design risk, no architectural commitment. **Best first ship.**

### Vehicle 2 — `<ArticleNav>` feature (1 PR, ~1 day)
Single high-leverage component populating empty sidebar slot. Closes 8+ findings. After Vehicle 1 lands so the back-link work doesn't conflict.

### Vehicle 3 — Strategic infrastructure (3 PRs, multi-week)
P-SEO-META + P-CALLOUTS + P-MOBNAV + P-MDX-CODE — each a dedicated feature-folder with PRD.

---

## §7 Strong existing patterns flagged as exemplars (don't break these)

- `Disclosure.tsx` — proper `aria-expanded`, `aria-controls`, `useId`
- `PersonaIndicator.tsx` — `role="status" aria-live="polite"`
- `Term.tsx` — keyboard-accessible tooltip with `aria-describedby`
- Dark-mode contrast overrides at `globals.css:58-68` — tuned to 4.5:1
- `prefers-reduced-motion` global rule at `globals.css:70-77`
- `<html lang="en">` correctly set
- Heading hierarchy clean h1→h2→h3 corpus-wide (zero h4 in any sampled article)
- `--text-body 1.0625rem` (≥17px) — passes iOS no-zoom-on-focus threshold

---

## §8 Cross-references

- **Source audits:** [public-site](./2026-05-08-fitme-story-public-site-audit.md) · [case-study deep-dive](./2026-05-08-case-study-readability-deep-dive.md)
- **Existing queue spec:** [`docs/superpowers/specs/2026-05-08-fitme-story-website-enhancement-queue.md`](../superpowers/specs/2026-05-08-fitme-story-website-enhancement-queue.md)
- **v7.9 candidates spec:** [`docs/superpowers/specs/2026-05-08-framework-v7-9-candidates.md`](../superpowers/specs/2026-05-08-framework-v7-9-candidates.md)
- **Backlog umbrella items extended by this synthesis:** "Refine case-study presentation" (line 165) + "Site-wide search on fitme-story" (line 166) + "Complete Figma design + architecture" (line 167)
