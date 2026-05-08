# fitme-story Website Enhancement Queue (split: UCC vs Public Site vs Shared)

**Status:** input doc · not yet a PRD per item
**Created:** 2026-05-08
**Companion to:** [2026-05-08-framework-v7-9-candidates.md](./2026-05-08-framework-v7-9-candidates.md) (v7.9 input from stress-test)
**Source threads:**
- 2026-05-07 roadmap stress-test S3 outcome (G3 + G5 deferred)
- 2026-05-08 cross-reference session (this conversation)
- backlog.md "Refine case-study presentation/readability" (added 2026-04-28)
- backlog.md "Complete Figma design + architecture for both surfaces" (added 2026-05-07)
- ucc-passkey-auth case-study Pending follow-ups (4 cutover items)
- unified-control-center T2.5 deferred at ship
- branch-isolation out-of-scope spec §1 + §6 (v8 candidates with `/control-room/*` routes)
- v7.9 candidates F7 + F8 (cross-repo gate parity)

---

## §1 Why split UCC from public site

The `fitme-story.vercel.app` deployment serves two distinct surfaces with different audiences, auth models, and risk envelopes:

- **🔒 UCC (Unified Control Center)** at `/control-room/*` — operator-only dashboard, currently HTTP-basic-auth (cutover to passkeys pending), 4 routes, internal observability + audit
- **🌐 Public site** at `/`, `/case-studies/*`, `/timeline/*`, `/glossary`, `/trust`, `/framework/*` — public showcase + dev guide + framework story, ~35 routes, broad audience
- **🔁 Shared infrastructure** — Tailwind v4 tokens, Figma design system, repo-level pre-commit gates, Code Connect

Splitting them clarifies sequencing: public-site work is fully Claude-doable today (no operator dependencies, no trigger-gating, broadest visibility). UCC work is mostly operator-blocked (cutover sequence) or trigger-gated (v8 routes wait for empirical signals).

---

## §2 🔒 UCC track (operator dashboard at `/control-room/*`)

| ID | Task | Class | Source |
|---|---|---|---|
| **UPA-1** | Run `pnpm tsx scripts/issue-bootstrap-token.ts <email>` + flip `UCC_AUTH_MODE` to `both` | Operator-blocked | ucc-passkey-auth case study Pending follow-ups |
| **UPA-2** | Set `UCC_AUDIT_BLOB_URL` repo variable on FT2 (otherwise daily GHA is no-op) | Operator-blocked | ucc-passkey-auth case study |
| **UPA-3** | Register break-glass YubiKey + flip `UCC_AUTH_MODE` to `passkey` | Operator-blocked, T+7d | ucc-passkey-auth case study |
| **UPA-4** | Drop `DASHBOARD_USER` + `DASHBOARD_PASS` env vars + populate case-study `kill_criteria_resolution` | Operator + Claude, T+14d | ucc-passkey-auth case study |
| **T2.5** | Upgrade `/control-room/framework`'s `baseline-ttc.json` from T2 (Declared placeholder) to T1 (Instrumented from GA4) | Data-window-blocked, ~7 days of GA4 | UCC state.json `tasks[]` |
| **V8-1** | New route `/control-room/agents` — Sapling-smartlog-style live awareness UI (per-agent card: branch + worktree + declared paths + last-heartbeat with path-overlap detection) | Trigger-gated: ≥5 concurrent active features for 7+ days | branch-isolation out-of-scope §1 |
| **V8-6** | New route `/control-room/dependencies` — cross-feature dependency graph viz (depends on V8-1) | Trigger-gated: `path-reducers.json` ≥20 entries + ≥3 merge semantics + ≥2 organic conflicts | branch-isolation out-of-scope §6 |
| **FIG-U3** | Figma component frames for `src/components/control-room/` (Panel, MetricList, AlertsBanner, TrackedDocLink, AuthPasskeyForm, DevicesTable, AuditEventRow, AuditLogPanel) | Claude-doable (after FIG-W1 + FIG-W2) | "Complete Figma" backlog item |
| **FIG-U4** | Figma screen frames for the 4 control-room routes (framework, agents-when-built, settings/devices, settings/audit) | Claude-doable (after FIG-W1 + FIG-W2) | "Complete Figma" backlog item |

**UCC totals:** 9 items · 4 operator-blocked · 1 data-blocked · 2 trigger-gated · 2 Claude-doable now

---

## §3 🌐 Public site track (showcase + marketing + dev-guide)

| ID | Task | Class | Source |
|---|---|---|---|
| **G3** | Dual-outlet pattern doc (FT2 long-form case study vs fitme-story slot MDX contract) — affects `/case-studies/*` | Claude-doable | stress-test S3-G3 + backlog "Refine case-study presentation" §3 |
| **G5** | Timeline frontmatter audit (v2.0–v7.0 showcase MDX consistency, ~26 files) — affects `/case-studies/*` + `/timeline/*` | Claude-doable, medium | stress-test S3-G5 + backlog "Refine case-study presentation" §5 |
| **SEARCH-1** | Site-wide keyword search with smart ranked results across case-studies + glossary + dev-guide + lifecycle-event-catalog. Persistent header search + `/search?q=` page. Tag-aware ranking: matches inside frontmatter tags (`version`, `work_type`, `tier_tags_present`, `framework_version`, era) score higher than body matches. Faceted filters by version / work_type / era / tier. Recommended stack: **Pagefind** (static, build-time index, ~80 docs ≈ tiny bundle, zero runtime cost). Fallback: Fuse.js. **Out of scope v1:** semantic/embeddings search, search analytics, multi-language | Claude-doable, medium; benefits from G3 + G5 done first | this conversation 2026-05-08 |
| **SEO-1** | Marketing/showcase SEO optimization (metadata, structured data, sitemap, OG tags) | Claude-doable, medium | backlog.md "SEO & Content Marketing" |
| **FIG-P4** | Figma screen frames for the 35 public routes (showcase home, 26 case-study pages, 4 sign-in/legal, glossary, trust, dispatch demo, dev-guide, lifecycle-catalog) | Claude-doable, large (after FIG-W1 + FIG-W2) | "Complete Figma" backlog item |
| **V79-DOC** | Mirror v7.9 promotion outcome to `/framework/dev-guide` (new gates, advisory→enforced flips, breaking changes if any) | Date-gated, post-2026-05-21 | v7.9 candidates spec |
| **P-A11Y-1** ⚡ | Skip-to-content link + light-mode `--color-neutral-500` contrast bump (#78716C → ≥#5C5754). Closes A-001 + A-002 + A-018 (3 P0 WCAG violations) | P0 quick-win, S | [audit synthesis §3](../../research/2026-05-08-fitme-story-audit-synthesis.md) |
| **P-NAV-CHROME** ⚡ | Add `aria-current="page"` + 2px underline on nav (via `usePathname()`); global `.focus-ring` utility on header/footer/cards; "← Case studies" back-link with copy-link affordance on all 3 templates. Closes A-003 + V-003 + A-008 + V-007 + CS-015 | P1 quick-win, S | audit synthesis §3 |
| **P-MDX-HEADINGS** ⚡ | Add `rehype-slug` + `rehype-autolink-headings` to `compileMDX` options at `src/app/case-studies/[slug]/page.tsx:38`. Every heading becomes a deep-link target. Closes CS-007 | P1 quick-win, S | audit synthesis §3 |
| **P-MDX-TABLE** ⚡ | Add `.prose table { display: block; overflow-x: auto; }` to globals.css. Fixes mobile table overflow corpus-wide (375px breaks slot 08 5-col throughput table). Closes CS-006 + CS-020 + R-009 | P0 quick-win, S | audit synthesis §3 |
| **P-CHROME-BACKFILL** ⚡ | Add `chrome_minimal: true` opt-out signal to frontmatter schema OR backfill `honest_disclosures` + `visual_aid` on 5 recent entries (slots 23a, 23b, 23c, 25, 26). Closes CS-008 — silent regression on most-recent ships | P0, S | audit synthesis §3 |
| **P-TIMELINENAV** ⚡ | Wire `<TimelineNav>` at template level (already registered in `mdx-components.tsx:5`, never used in 47 MDX files). Computes prev/next from sorted `getAllCaseStudies()`. ~30-min change converts isolated articles into navigable timeline. Closes R-003 + CS-002 + CS-016 | P0 quick-win, S | audit synthesis §3 |
| **P-ARTICLENAV** | Build `<ArticleNav>` to populate empty 280px `<aside>` slot in Standard + Flagship templates. Sticky in-page TOC scraped from MDX heading tree + scroll progress + prev/next + back-to-index + copy-link button. **Single highest-leverage architectural move — closes 8+ findings** (CS-001, CS-002, CS-010, CS-013, CS-015, CS-016, CS-017, CS-019, V-001, V-007, R-001, R-002, R-003, A-020) | Strategic, M | audit synthesis §4 (S1) |
| **P-SEO-META** | Build `buildMetadata()` helper in `src/lib/seo.ts` returning `openGraph` + `twitter` + JSON-LD; call from every page-level + dynamic route. Even single fallback `/og.png` is enormous improvement. Currently only `/` defines `openGraph`. Closes V-002 + V-012 + V-014 | Strategic, M | audit synthesis §4 (S2) |
| **P-CALLOUTS** | Callout component family: `<HonestDisclosure>`, `<TriggerIncident>`, `<MemoryRef>`, `<PredecessorChain>`, `<KillCriterionResolution>`. Each is a recurring narrative pattern across 4+ case studies currently inlined as ad-hoc prose. Closes CS-014 + CS-024 (partial CS-008) | Strategic, L | audit synthesis §4 (S3) |
| **P-MDX-CODE** | Wire `rehype-pretty-code` (or shiki) into MDX pipeline at `compileMDX`. Single plugin install. Optional: ship `<CopyButton>` MDX component for code blocks. Closes A-024 + R-008 + CS-004 | Strategic, M | audit synthesis §4 (S4) |
| **P-MOBNAV** | Build `<MobileNav>` as separate component — hamburger opens focus-trapped Dialog with full nav + theme toggle + skip-to-glossary + skip-to-compare. Currently `SiteHeader` `hidden md:flex`'s the entire nav with NO fallback below 768px. Closes V-004 + partial V-005 + partial V-009 + partial A-001 | Strategic, M | audit synthesis §4 (S5) |

**Public-site totals (post-audit):** 17 items · 1 date-gated · 16 Claude-doable · 6 marked ⚡ are quick-wins (P0/P1 + effort=S)

---

## §4 🔁 Shared infrastructure (both surfaces benefit equally)

| ID | Task | Class | Source |
|---|---|---|---|
| **FIG-W1** | Create Figma file under team `Regev - My apps` (`team::726401375318003097`) named "FitMe Story Web — Design System" | Claude-doable, foundational for FIG-U3, FIG-U4, FIG-P4, FIG-W5 | "Complete Figma" backlog item |
| **FIG-W2** | Extract every token from `fitme-story/src/app/globals.css` (brand-indigo/coral, neutral 50–900, skill palette × 11, editorial type scale) into Figma variables | Claude-doable, foundational | "Complete Figma" backlog item |
| **FIG-W5** | Code Connect integration so `/design build` pushes web screens via Figma MCP (eliminates `figma_build_status: deferred_to_prompt` fallback) | Claude-doable, runs after FIG-U3 + FIG-P4 | "Complete Figma" backlog item |
| **FIG-W6** | Architecture doc `docs/design-system/fitme-story-design-architecture.md` (Tailwind v4 `@theme` + globals.css variables + skill palette + editorial type scale contract) | Claude-doable, can run parallel with FIG-W2 | "Complete Figma" backlog item |
| **F7** | Tier 2.2 per-phase emission gate parity for fitme-story repo OR explicit exemption doc | Claude-doable, v7.9 candidate | v7.9 candidates spec §F7 |
| **F8** | Mechanism A `gate-coverage.jsonl` parity for fitme-story repo OR explicit exemption doc | Claude-doable, v7.9 candidate | v7.9 candidates spec §F8 |

**Shared totals:** 6 items · all Claude-doable

---

## §5 Per-track sequencing

### UCC track (operator-led, Claude assists)
1. UPA-1 → UPA-2 → UPA-3 → UPA-4 (cutover sequence)
2. T2.5 (in parallel; needs GA4 data window)
3. FIG-U3 → FIG-U4 (after FIG-W1 + FIG-W2)
4. V8-1 → V8-6 (only when triggers fire)

### Public-site track (Claude-doable, ship-this-week eligible)

**Vehicle 1 — Quick wins bundle (1 PR, ~1 day, closes 6 P0s + 11 P1s):**
1. **P-A11Y-1** ⚡ skip-link + contrast bump (3 P0s)
2. **P-MDX-TABLE** ⚡ table mobile overflow (1 P0)
3. **P-CHROME-BACKFILL** ⚡ frontmatter chrome opt-out signal (1 P0)
4. **P-TIMELINENAV** ⚡ wire TimelineNav prev/next (1 P0)
5. **P-NAV-CHROME** ⚡ aria-current + focus-ring + back-link (4 P1s)
6. **P-MDX-HEADINGS** ⚡ rehype-slug + autolink-headings (1 P1)

**Vehicle 2 — `<ArticleNav>` (1 PR, ~1 day):**
7. **P-ARTICLENAV** — populates empty aside, closes 8+ findings

**Vehicle 3 — Strategic infrastructure (each its own feature folder + PRD, multi-week):**
8. **P-SEO-META** — buildMetadata() + JSON-LD + OG cards
9. **P-CALLOUTS** — callout component family
10. **P-MOBNAV** — mobile hamburger nav
11. **P-MDX-CODE** — rehype-pretty-code + CopyButton

**Pre-existing public-site items (post-quick-wins ordering):**
12. **G3** (dual-outlet doc) — small, blocks G5
13. **G5** (timeline frontmatter audit) — medium, sharpens SEARCH-1's facets
14. **SEARCH-1** (site-wide search) — medium, benefits from clean frontmatter
15. **SEO-1** (marketing SEO) — medium, may merge with P-SEO-META
16. **FIG-P4** (public-route Figma frames) — large, after FIG-W1 + FIG-W2

### Shared track (best run first since both depend on it)
1. **FIG-W1** + **FIG-W2** + **FIG-W6** (foundational, ~1 session)
2. **F7 + F8** (cross-repo telemetry decision — likely "document the asymmetry")
3. **FIG-W5** (Code Connect — last, after FIG-U3 + FIG-P4 land)

---

## §6 Strategic observation

The **public-site track has zero external blockers** and the smallest foundational work. If the goal is "ship something visible this week", G3 → G5 → SEARCH-1 is the cleanest path — coherent narrative ("better case-study presentation + discovery"), entirely on the showcase surface, broadest audience. The UCC track is mostly waiting on operator action (UPA-1 + UPA-2 are the unblockers) or on triggers that haven't fired yet.

---

## §7 Aggregate count

**32 open items across 3 surfaces** (was 22; +10 from 2026-05-08 audit synthesis):

| Surface | Count | Operator | Data | Trigger | Date | Claude-doable |
|---|---|---|---|---|---|---|
| 🔒 UCC | 9 | 4 | 1 | 2 | 0 | 2 |
| 🌐 Public site | 17 | 0 | 0 | 0 | 1 | 16 |
| 🔁 Shared | 6 | 0 | 0 | 0 | 0 | 6 |
| **Total** | **32** | **4** | **1** | **2** | **1** | **24** (75%) |

24 of 32 items can ship today without any external unblock. 8 items are gated on operator action, data accumulation, empirical triggers, or calendar dates.

**Quick-wins subset (P0/P1 with effort=S, all on public-site):** 6 items (P-A11Y-1, P-NAV-CHROME, P-MDX-HEADINGS, P-MDX-TABLE, P-CHROME-BACKFILL, P-TIMELINENAV) — closes 6 P0s + 11 P1s in ~1 focused day.

---

## §8 Cross-references

- **2026-05-08 audit synthesis (10 net-new items source):** [`docs/research/2026-05-08-fitme-story-audit-synthesis.md`](../../research/2026-05-08-fitme-story-audit-synthesis.md)
  - Source audit 1: [`2026-05-08-fitme-story-public-site-audit.md`](../../research/2026-05-08-fitme-story-public-site-audit.md)
  - Source audit 2: [`2026-05-08-case-study-readability-deep-dive.md`](../../research/2026-05-08-case-study-readability-deep-dive.md)
- **v7.9 candidates spec:** [2026-05-08-framework-v7-9-candidates.md](./2026-05-08-framework-v7-9-candidates.md) — F7 + F8 + V79-DOC originate here
- **v8 out-of-scope spec:** [2026-05-07-branch-isolation-out-of-scope.md](./2026-05-07-branch-isolation-out-of-scope.md) — V8-1 + V8-6 originate here
- **Roadmap stress-test case study:** `docs/case-studies/roadmap-stress-test-2026-05-07-case-study.md` — G3 + G5 deferred from S3
- **UCC Passkey Auth case study:** `docs/case-studies/ucc-passkey-auth-case-study.md` — UPA-1 through UPA-4 follow-ups
- **UCC main feature state.json:** `.claude/features/unified-control-center/state.json` — T2.5 deferral
- **Backlog umbrella items:**
  - "Refine case-study presentation/readability" (line 165) → G1+G2+G4 done; G3+G5 open
  - "Complete Figma design + architecture for both surfaces" (line 166) → all 6 FIG-* items
  - "Passkey auth for UCC" (line 162) → SHIPPED via ucc-passkey-auth; UPA-1 through UPA-4 are post-ship cutover

---

## §9 Memory cross-references

- [project_ucc_passkey_auth_shipped.md](~/.claude/projects/-Volumes-DevSSD-FitTracker2/memory/project_ucc_passkey_auth_shipped.md) — Pending follow-ups section drives UPA-1 through UPA-4
- [project_ucc_followups_pending.md](~/.claude/projects/-Volumes-DevSSD-FitTracker2/memory/project_ucc_followups_pending.md) — T2.5 deferral context
- [project_roadmap_stress_test_2026_05_07.md](~/.claude/projects/-Volumes-DevSSD-FitTracker2/memory/project_roadmap_stress_test_2026_05_07.md) — G3 + G5 source

---

## §10 What this doc is NOT

- **Not a PRD per item.** Each item gets its own Phase 1 (Research) + Phase 2 (PRD) when picked up.
- **Not exhaustive of all fitme-story work.** Future v8 candidates, post-launch growth-experiment surfaces, and analytics dashboards may add items.
- **Not promising sequencing commits.** §5 sequencing is a recommendation; the user can re-prioritize at any point.
- **Not gating any current feature work.** This is queue documentation; the active features (`framework-v7-8-branch-isolation` next-inline) remain the active priority.
