# Case-Study Reading Experience — Narrow Audit (2026-05-08)

> Scope: rendered showcase MDX at `fitme-story.vercel.app/case-studies/<slug>` only. Excludes index page (already strong), homepage, glossary, dev-guide, and the FT2 long-form source case studies (the broader site audit owns those).

## Executive Summary (≤200 words)

- **Per-case-study scannability — Yellow.** The 2026-04-28 chrome refactor (SummaryCard / DataKey / VisualAidResolver / KillCriterionBanner / DeferredItemsList) gives newer entries a strong above-the-fold, but there is no in-page TOC, no scroll progress, no anchor-link affordance on headings, and no sub-TOC for the 7–10 h2 sections that dense v7.x entries carry. Reading-time estimate is present.
- **Cross-case-study consistency — Yellow.** Frontmatter chrome adoption is bimodal: 5 newest entries (`23a`, `23b`, `23c`, `25`, `26`) silently drop `honest_disclosures`/`visual_aid` while still using the `light` template, so readers get a different above-the-fold contract on entries published one week apart. No version drift in heading depth (good) but § convention only present in 6 of 47 files (no consistency rule).
- **Reading-aid affordances — Red.** Zero prev/next nav (`TimelineNav` exists, never imported), zero back-to-index link inside an article, zero anchor links on headings, zero share-link affordance, zero "related case studies", zero print stylesheet, no jump-to-§99 link, empty desktop sidebar `<aside>` slot.
- **Mobile long-form — Yellow.** Body 17px (good), warm-gray on warm-cream contrast OK, but tables have no horizontal-scroll wrapper and `prose-lg` on Standard/Flagship templates exceeds 65ch on tablet portrait.

**Top 5 highest-impact findings:** CS-001 (no in-article navigation), CS-003 (chrome adoption bimodal), CS-007 (table mobile overflow), CS-002 (TimelineNav imported but unused), CS-010 (empty sidebar slot wastes 280px).

---

## Methodology

Sampled 6 showcase MDX files spanning every framework era plus the longest entry plus the most recent:

| Slot | File | Version | Words | Rationale |
|---|---|---|---|---|
| `05` | `05-soc-on-software.mdx` | v5.0 | ~1,250 | Pre-refactor era; flagship tier; uses BlueprintOverlay + DispatchReplay |
| `08` | `08-parallel-stress-test.mdx` | v5.1 | 1,519 | Pre-refactor flagship; rich custom visual aids (Gantt + RankedBars + DurationStack) |
| `11` | `11-measurement-v6.mdx` | v6.0 | 1,470 | Bridge-era flagship; first to use BeforeAfter visual_aid via frontmatter |
| `22` | `22-validity-closure-v7-7.mdx` | v7.7 | 1,938 | Post-refactor light; full chrome (tldr + key_numbers + honest_disclosures + kill_criteria + deferred_items + visual_aid) |
| `23` | `23-bridge-v7-8.mdx` | v7.8 | 1,970 | Densest narrative; richest frontmatter (10 key_numbers, 4 deferred_items) |
| `25` | `25-framework-v7-8-1-branch-isolation.mdx` | v7.8.1 | 1,886 | Frontmatter regression (no honest_disclosures, no visual_aid) |
| `26` | `26-ucc-passkey-auth.mdx` | v7.8.1 | (latest) | Most recent shipped; bare frontmatter + 5 h2 sections |
| `14` | `14-framework-story-site.mdx` | v6.x | 5,381 | Outlier (3.5× corpus median); 10 h2 + 28 h3 + ample subsections |

Cross-corpus structural metrics scanned across all 47 MDX files (excluding `README.mdx`).

---

## Findings

### 1. Within-case-study scannability

**[CS-001] No in-page TOC, no scroll progress, no jump-to-section affordance** · severity: P1 · effort: M · location: `src/components/case-study/{Light,Standard,Flagship}Template.tsx` · sample: slot 22 has 9 h2 + 5 h3; slot 23 has 7 h2 + 2 h3 + visible 10-item key-numbers grid. Readers scrolling past the SummaryCard land on long prose with no overview of what's coming and no way to jump back. The empty desktop sidebar slot (`<aside aria-label="Sidebar" className="hidden md:block" />` in `StandardTemplate.tsx:57` and `FlagshipTemplate.tsx:63`) is the natural home for this. Without it, the longer entries (slots 14, 22, 23, 25) read as undifferentiated walls.

**[CS-002] `TimelineNav` component exists but is never used** · severity: P1 · effort: S · location: `src/components/mdx/TimelineNav.tsx` (component) + `src/mdx-components.tsx:5` (registered) · sample: zero `grep TimelineNav` hits across all 47 MDX files. Either auto-render at template level (computed prev/next from sorted `getAllCaseStudies`) or remove from the registered MDX surface to avoid the false signal that prev/next nav is supported.

**[CS-003] Heading hierarchy is clean (no h2→h4 jumps)** · severity: P3 (positive finding) · effort: — · location: corpus-wide. Sampled slots 22/23/25/26/14 all had zero h4. Hierarchy stays h1 (template-rendered) → h2 → h3 throughout. **Keep this.**

**[CS-004] No code blocks with copy buttons or syntax highlighting** · severity: P2 · effort: M · location: globals.css + MDX renderer · sample: slot 22 has 1 ASCII timeline ``` block; slot 23 has zero `pre`. Showcase MDX uses fenced blocks sparingly, but when present they render as the Tailwind typography default with no copy affordance and no syntax tokens. Not catastrophic given the sparse usage, but the framework is positioned as engineering writing — a repo path or shell command in a copyable code chip is table stakes.

**[CS-005] Inline code styling is good — uses `<code>` consistently with monospaced inline-bg** · severity: P3 (positive) · effort: — · location: prose default + `renderInlineMarkdown` in `alt-a-chrome/index.tsx:23`. SummaryCard's honest-disclosures correctly handle backtick spans. Body prose inherits Tailwind typography defaults which render fine.

**[CS-006] Tables are well styled (warm header band, hover row, semantic borders) but have no horizontal scroll wrapper** · severity: P1 · effort: S · location: `src/app/globals.css:117-158` · sample: slot 08 throughput table is 5 cols × 4 rows with `min/CU vs Baseline` header that overflows at 375px. Tailwind typography puts tables inline in the prose container; combined with `prose-lg` (default in templates) and Standard/Flagship's `max-w-[var(--measure-body)]` (65ch ≈ 720px) — a table wider than 720px just overflows the body. Add `.prose :where(table):not(:where([class~="not-prose"] *)) { display: block; overflow-x: auto; }` or wrap each table in a `<div data-scrollable>`. The `data-scrollable` selector already exists in globals.css:99 for `-webkit-overflow-scrolling`, but no MDX surface uses it.

**[CS-007] No anchor-link icon ("§" / "#") on hover for any heading** · severity: P1 · effort: S · location: `mdx-components.tsx` (no h2/h3 component override). Tailwind typography renders heading text without an `id` attribute and without an anchor affordance. Linking to "Section 4 of v7.8 case study" requires scrolling and a manual screen pointer; you cannot deep-link to a sub-section anywhere on the site. `rehype-slug` + `rehype-autolink-headings` would close this in one PR — neither is currently in `compileMDX` options at `[slug]/page.tsx:38`.

### 2. Cross-case-study consistency

**[CS-008] Frontmatter chrome adoption is bimodal across the most-recent 5 entries** · severity: P0 · effort: M · location: `content/04-case-studies/`. Coverage scan:

| Field | Files lacking it | Notable |
|---|---|---|
| `tldr` | 0 | Universal |
| `honest_disclosures` | 5 (`23a`, `23b`, `23c`, `25`, `26`) | Regressed in last week's ships |
| `kill_criteria` | 27 | Pre-refactor era OK, but 6 newest also miss |
| `visual_aid` | 6 (incl. `23a`, `23b`, `23c`, `25`, `26`) | Same regression cluster |

The same templates render all entries; readers landing on slot 22 (full chrome) versus slot 26 (only SummaryCard renders) get a *different above-the-fold contract* on entries published one week apart. Either: (a) backfill chrome on the 5 recent entries, OR (b) add a "minimal chrome" frontmatter signal that explicitly opts out, so readers know the missing chrome is intentional.

**[CS-009] § symbol convention is inconsistent** · severity: P3 · effort: S · location: 6 of 47 files use `§` (slots 21, 22, 22a, 22c, 23, 26); the rest use plain "Section N" or no marker. Either standardize (helps cross-references like "see §99.4") or document as upstream-only. Currently the showcase MDX *prose* references "Section 99.7" / "§99B" but readers can't jump there because the showcase doesn't have a §99.

**[CS-010] T1/T2/T3 tier tags surface only inside KeyNumbersChart and DataKey** · severity: P2 · effort: S · location: `alt-a-chrome/index.tsx` `KeyNumbersChart` (lines 300-345). The body prose contains many quantitative claims (table cells, sentences) that carry no visible tier badge. The DataKey panel explains the convention but unless a metric was hoisted into `key_numbers` frontmatter, no badge ever appears next to it. Mismatch between "T1/T2/T3 is a project-wide convention" and "T1/T2/T3 is visible on hoisted key numbers only".

**[CS-011] Long-form outlier (slot 14, 5,381 words) gets the same `light` template as a 800-word entry** · severity: P2 · effort: M · location: `[slug]/page.tsx:43-52`. Tier classification is `flagship/standard/light/appendix`; slot 14 is light. A 5K-word doc deserves at least an article-internal TOC + the empty sidebar populated with one. Templates currently switch on `tier` but length is not considered.

### 3. Information architecture within a single case study

**[CS-012] §99 deeply-nested resolution log lives in upstream FT2 source, NOT in showcase MDX** · severity: P3 (positive — correctly abbreviated) · effort: — · location: showcase MDX prose pointers like `"see upstream Section 99 for the full synthesis"` (slot 22). The brief flagged §99.1–§99.8 as a potential dense-wall problem, but in the showcase corpus that risk is already mitigated — the MDX abbreviates and links to the full upstream. The dense §99.x sub-tree exists only at `/Volumes/DevSSD/FitTracker2/docs/case-studies/*-case-study.md`, not on the public site. No action needed for the showcase. (The upstream-rendering case is a separate audit if/when those ever get a public surface.)

**[CS-013] No sub-TOC at the top of multi-h2 articles** · severity: P1 · effort: S · location: templates. Slot 22 has 9 h2 sections; slot 14 has 10. An MDX-injectable `<SectionList />` component (auto-derived from MDX AST or hand-authored from frontmatter `sections: []`) would let readers preview the article shape before committing.

**[CS-014] Repeated sub-section patterns are not standardized as components** · severity: P2 · effort: M · location: corpus-wide. Recurring patterns observed across 4+ case studies that should each be reusable MDX components:
- "Read this first — outlier flag" callout (slots 21, 22, 23) — shape is identical, content varies
- "Trust-page connection" block (slots 21, 22, 23) — same: 4-bullet predecessor chain + audit link
- "Tooling attribution (honest)" tri-list (slot 22) — 3-bullet humanlllm credit list
- "What still remains Class B / What's NOT yet done" deferred-list at narrative end — duplicates DeferredItemsList semantically but lives in prose

Standardizing these as `<OutlierFlag>`, `<TrustPageConnection>`, `<ToolingAttribution>` MDX components would (a) compress the body, (b) give them visual consistency, (c) make them queryable across the corpus.

### 4. Reading aids the showcase site provides (or doesn't)

| Aid | Present? | Location |
|---|---|---|
| Reading-time estimate | YES | Templates show `entry.readingTimeMin` |
| Last-updated date | Partial | `fm.date` shown in SummaryCard; not all entries have it |
| Author/contributor | NO | Not in frontmatter or templates |
| Related case studies | NO | Empty `<aside>` slot |
| Back-to-index navigation | NO | No "← All case studies" link inside article |
| Share / copy-link affordance | NO | — |
| Print stylesheet | NO | No `@media print` in globals.css |
| Bookmark / save-for-later | NO | — |
| Anchor links on headings | NO | See CS-007 |
| Progress bar at top | NO | — |
| "Time to read" badge | YES (text only, no visual) | — |
| Prev/next via TimelineNav | NO | Component exists, never wired |

**[CS-015] Add a minimal article toolbar (back-to-index + copy-link + estimated finish time)** · severity: P1 · effort: S · location: templates. Three table-stakes affordances; all three free of design risk; all three boost long-form completion rates per UX-pattern research.

**[CS-016] Wire TimelineNav at template level** · severity: P0 · effort: S · location: `[slug]/page.tsx` + templates. `getAllCaseStudies()` already returns the sorted list; computing `prev`/`next` adjacent slots and passing them into a `<TimelineNav>` rendered at the bottom of every template is a 30-min change. This single change converts the case-study collection from a list to a navigable timeline.

**[CS-017] No "Related" cluster (e.g., other v7.x entries when reading slot 22)** · severity: P1 · effort: M · location: templates + content layer. The index page already groups by milestone-era; rendering an "Also from v7.x" footer on each article would extend that signal into the article view.

### 5. Long-form mobile reading

**[CS-018] Body type at `text-body: 1.0625rem` (~17px) — passes iOS no-zoom-on-focus threshold** · severity: P3 (positive) · effort: — · location: `globals.css:48`. Good baseline.

**[CS-019] Standard/Flagship templates use grid `md:grid-cols-[1fr_280px]` with empty 280px aside** · severity: P1 · effort: S · location: `StandardTemplate.tsx:27`, `FlagshipTemplate.tsx:33`. On `md:` (≥768px) the body squeezes into 1fr next to a 280px void. Either populate the aside with TOC + share + back-to-index (preferred), or drop to single-column until the sidebar has content.

**[CS-020] Tables inside `prose-lg` overflow on mobile** · severity: P0 · effort: S · location: globals.css. See CS-006. Single CSS rule fixes it.

**[CS-021] Body line-length on Light template wider than ideal** · severity: P2 · effort: S · location: `LightTemplate.tsx:52` uses `max-w-none` for the body while the article container is `max-w-[var(--measure-wide)]` (72ch). Standard/Flagship correctly use `max-w-[var(--measure-body)]` (65ch). Light entries (most of v7.x ships) read at the wider measure — past 75ch on iPad-portrait.

**[CS-022] Touch targets on inline links are at default Tailwind typography size** · severity: P2 · effort: S · location: prose styles. Tailwind typography links inherit body size + underline; the 17px-tall hit region falls below the 44px guideline. Acceptable for desktop but tappy on mobile.

### 6. Visual hierarchy markers — the G4 component family

**[CS-023] Existing chrome components (SummaryCard, DataKey, KillCriterionBanner, DeferredItemsList) are well designed** · severity: P3 (positive) · effort: — · location: `alt-a-chrome/index.tsx`. Each renders only when its data is present (graceful degradation, line 51). Color/icon vocabulary is consistent (coral for warn, emerald for clear, indigo for neutral). Dark mode contrast overrides shipped (globals.css:55).

**[CS-024] Missing callout component family** · severity: P1 · effort: M · location: new components. Three+ recurring narrative patterns would benefit from standardized callouts (mentioned in CS-014):
- `<HonestDisclosure>` — coral border + alert-triangle, distinct from prose. Currently those disclosures live in `honest_disclosures` frontmatter (rendered inside SummaryCard) AND get rewritten in prose under "## Honest disclosures" h2 in newer entries — duplication.
- `<TriggerIncident>` — for the recurring "Incident 1 — HADF Phase 2" / "Incident 2 — 2026-05-07" pattern (slot 25) and analogous trigger-narratives in slots 22/23.
- `<MemoryRef>` — annotated cross-reference to a prior case study (currently raw markdown links lose their predecessor-chain semantics).
- `<PredecessorChain>` — the v7.5 → v7.6 → v7.7 → v7.8 chain rebuilt from prose every time.
- `<KillCriterionResolution>` — sister to KillCriterionBanner; shows the post-T+7d outcome (slot 26 has "Pending — week-1 telemetry gate"; the gate fires, resolution updates).

### 7. Dense narrative vs scannable structure

**[CS-025] Slot 23 SummaryCard renders 10 key_numbers in a 1-3 grid** · severity: P2 · effort: S · location: `KeyNumbersChart` grid is `sm:grid-cols-3` regardless of count. 10 items wrap across 4 rows; impact dilutes. Either cap KeyNumbersChart at 6 numbers and route overflow to a "+N more" expansion, or switch to a 2-col layout above 6.

**[CS-026] Paragraph blocks > 200 words rare in showcase corpus** · severity: P3 (positive — well-edited) · effort: — · location: corpus-wide. The dense-paragraph problem flagged in the brief lives in upstream FT2 source case studies; showcase MDX is well-broken with sub-sections, tables, and bullets.

**[CS-027] Tables already do good work — the "Pre-v7.7 / Post-v7.7" comparison table in slot 22 is exemplary** · severity: P3 (positive) · effort: — · location: slot 22 line ~107 (in upstream rendering). Replicate as a `<BeforeAfter>` flow more aggressively across older entries.

**[CS-028] Two recurring patterns should be promoted to structured frontmatter** · severity: P2 · effort: M · location: schema + components.
- `predecessor_chain: [{ version: 'v7.5', slug: '...', focus: '...' }, ...]` → renders as a typed predecessor breadcrumb above the SummaryCard
- `trigger_incidents: [{ date: '...', incident: '...', failure_modes: [...] }]` → renders as a dedicated TriggerIncident block

---

## Quick wins (P0+P1, effort=S)

1. **CS-016** — Wire `TimelineNav` at template level, derive prev/next from sorted `getAllCaseStudies()`. ~30 min. Converts isolated articles into a navigable corpus.
2. **CS-007** — Add `rehype-slug` + `rehype-autolink-headings` to `compileMDX` options. Single PR. Enables every heading as a deep-link target.
3. **CS-006/CS-020** — Add `.prose table { display: block; overflow-x: auto; }` (or wrap with `data-scrollable`). One CSS rule, fixes mobile table overflow corpus-wide.
4. **CS-002** — Either wire TimelineNav (preferred, see CS-016) or remove from `mdx-components.tsx:5`. No middle ground.
5. **CS-019** — On Standard/Flagship, drop the empty aside until it has content; or populate with at minimum a back-to-index + copy-link affordance.
6. **CS-008** — Re-run frontmatter sweep on slots `23a`/`23b`/`23c`/`25`/`26` and add `honest_disclosures` + `visual_aid`. Or document an explicit "minimal chrome" opt-out so the regression is intentional.

---

## Strategic recommendations (3–5 systemic patterns)

### S1. Populate the aside as a per-article navigator (`<ArticleNav>`)

The `<aside aria-label="Sidebar" className="hidden md:block" />` slot in Standard + Flagship is a 280px desktop void. Build one component that renders inside it on every article: (a) sticky in-page TOC scraped from the MDX heading tree, (b) reading-progress bar, (c) prev/next pointers, (d) "back to all case studies", (e) copy-link button. This is the single highest-leverage change — closes CS-001, CS-002, CS-010, CS-013, CS-015, CS-016, CS-017, CS-019 in one PR.

### S2. Backfill chrome to all v7.5+ entries; document opt-out for older ones (G5 territory)

The 2026-04-28 refactor never closed the gap on the most recent ~5 entries. Either backfill or formalize an opt-out signal in frontmatter (e.g. `chrome_minimal: true` with required reason). The current state — silent non-rendering — is the worst of both worlds: readers can't tell whether the chrome is missing because the case study is genuinely simpler or because nobody filled out the frontmatter.

### S3. Establish a callout component family

Promote the recurring narrative patterns (`<HonestDisclosure>`, `<TriggerIncident>`, `<MemoryRef>`, `<PredecessorChain>`, `<KillCriterionResolution>`) into MDX components. Each currently lives as ad-hoc prose; standardizing improves visual rhythm AND lets the showcase site cross-reference them programmatically (e.g., a "Trigger incidents this quarter" digest page).

### S4. Add sub-TOC component for >5 h2 articles

`<SubTOC />` rendered automatically when an article exceeds a threshold. Slots 14, 22, 23, 25 all qualify. Implement once at the template; reads the MDX heading tree at compile time.

### S5. Length-aware template selection

Tier-based routing (`flagship/standard/light/appendix` → template) ignores body length. A 5K-word "light" (slot 14) and a 800-word "light" (slot 24a) get the same chrome. Consider promoting tier semantics to include length-aware variants OR ship a single template with a length-conditional sidebar.

---

## Appendix

### A. Sampled case studies inventory

| Slot | File | Version | Words | Tier | Chrome present |
|---|---|---|---|---|---|
| 05 | soc-on-software | v5.0 | ~1,250 | flagship | tldr · key_numbers · honest_disclosures · visual_aid (BlueprintOverlay) |
| 08 | parallel-stress-test | v5.1 | 1,519 | flagship | tldr · key_numbers · honest_disclosures · visual_aid (ParallelGantt) |
| 11 | measurement-v6 | v6.0 | 1,470 | flagship | tldr · key_numbers · honest_disclosures · visual_aid (BeforeAfter) |
| 14 | framework-story-site | v6.x | 5,381 | light | (length outlier — gets same template as 800-word entries) |
| 22 | validity-closure-v7-7 | v7.7 | 1,938 | light | full: tldr · key_numbers · honest_disclosures · kill_criteria · deferred_items · visual_aid |
| 23 | bridge-v7-8 | v7.8 | 1,970 | light | full chrome + 10 key_numbers (overflow) |
| 25 | branch-isolation | v7.8.1 | 1,886 | light | partial: tldr · key_numbers · NO honest_disclosures · NO visual_aid |
| 26 | ucc-passkey-auth | v7.8.1 | (latest) | light | partial: tldr · key_numbers · kill_criteria · NO honest_disclosures · NO visual_aid |

### B. Component inventory

**Existing case-study presentation components:**
- `LightTemplate` / `StandardTemplate` / `FlagshipTemplate` — tier-routed shells
- `SummaryCard` — TL;DR + 5 fields + honest disclosures (above-the-fold)
- `DataKey` — collapsed "How to read this" panel
- `KeyNumbersChart` — fallback visual aid (T1/T2/T3 badged, parses progress/delta/all-clear/plain)
- `KillCriterionBanner` — emerald (not fired) / coral (fired)
- `DeferredItemsList` — title · ledger · reason rows
- `VisualAidResolver` — picks per `frontmatter.visual_aid.component`
- `FullCaseStudyLink` — bottom-of-article pointer to upstream FT2 markdown
- 10 visual-aid components (HeroMetric, BeforeAfter, DurationStack, RankedBars, FlowDiagram, ParallelGantt, AuditFunnel, RaceTimeline, PRStackDiagram, FrameworkAdvancement)
- 4 bespoke components (BlueprintOverlay, ChipAffinityMap, PhaseTimingChart, DispatchReplay)
- 7 generic MDX components (MetricsCard, Pullquote, Figure, TimelineNav [unused], FindingsTable, DevDive, Term)

**Suggested net-new components (5):**
- `<ArticleNav>` — sidebar TOC + scroll progress + prev/next + back-to-index + copy-link (S1)
- `<HonestDisclosure>` — promoted from prose pattern, dual-source with frontmatter array
- `<TriggerIncident>` — recurring "Incident N — DATE" pattern with failure-mode breakdown
- `<PredecessorChain>` — typed v7.5 → v7.6 → v7.7 chain (frontmatter `predecessor_chain[]`)
- `<KillCriterionResolution>` — sister to KillCriterionBanner; shows post-T+7d outcome

### C. Word-count distribution (47 case studies)

- **Median:** ~1,470 words
- **Min:** 802 (`24a-android-design-system`)
- **Max:** 5,381 (`14-framework-story-site`) — 3.5× median, single outlier
- **75th percentile:** ~1,890 words
- **Above 2,000 words:** 4 files (slots 17, 14, 22, 23)
- **Total corpus:** 69,139 words across 47 entries

### D. Methodology + scope notes

- All findings derived from read-only inspection on 2026-05-08.
- Mobile findings are CSS-derived (reading globals.css + Tailwind typography defaults at body 17px); not browser-tested. Designating CS-006/CS-020 as P0 reflects the high confidence that `prose table` without `display: block; overflow-x: auto;` will overflow at 375px width with any column count > 4.
- Did not test color contrast empirically; relied on dark-mode override comment (`globals.css:55`) which already documents AA fixes.
- Sample-evidence statements scoped to the 8 sampled MDX files (Methodology section). Corpus-wide claims (frontmatter coverage, tier mix, word distribution) derived from `grep -L` and `wc -w` across all 47 MDX files.
- Did not audit the upstream FT2 long-form case studies (60+ files at `docs/case-studies/`); that surface is private and the brief explicitly scopes the public showcase only.
