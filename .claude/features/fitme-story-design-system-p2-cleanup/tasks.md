# Tasks — fitme-story-design-system-p2-cleanup

**Phase:** 2 (Tasks)
**Framework:** v7.8.2
**Work type:** Enhancement (4-phase: Tasks → Implement → Test → Merge)
**Parent:** fitme-story-website-design-system
**Audit source:** [`docs/research/2026-05-10-fitme-story-design-system-lens-audit.md`](../../../docs/research/2026-05-10-fitme-story-design-system-lens-audit.md)

**Scope:** burn down the 16 remaining P2 audit items (3 P0/4 P1 already shipped via PRs #82+#289 in parent feature). All work on fitme-story repo only; no FT2-side code changes.

**Sequencing:** group tasks by component family so each commit is reviewable. Use existing primitives (Card, Stat, Tag) — no new components.

---

## Bucket A — Card<interactive> migrations (T1, P2-022 + parent-feature follow-ups)

| # | Task | Files | Complexity | Notes |
|---|---|---|---|---|
| **T1** | Migrate 5 inline `rounded-lg border` interactive nav cards to `<Card interactive>` | `src/app/pm-flow/page.tsx:157,163,169` (3 cards) + `src/app/framework/page.tsx:35,53` (2 cards) | S | Each is wrapped in `<Link>`; pattern matches /research migration in parent feature commit `8ddc555`. Preserve hover-shadow-lg where present. |

---

## Bucket B — Stat migrations (T2, P2-003 + P2-029 + parent-feature follow-ups)

| # | Task | Files | Complexity | Notes |
|---|---|---|---|---|
| **T2** | Migrate 3 inline `text-{4,5}xl font-semibold text-brand-indigo` metric displays to `<Stat>` | `src/components/home/NumbersPanel.tsx:89` (text-5xl → Stat<lg, accent>), `src/components/home/OriginNarrative.tsx:35` (text-4xl → Stat<md, accent>), `src/app/timeline/[version]/page.tsx:42` (text-4xl → Stat<md, accent>) | S | Each is a single inline div; use `<Stat value={...} label={...} size="lg|md" accent />`. |

---

## Bucket C — Tag migration (T3, P2-044)

| # | Task | Files | Complexity | Notes |
|---|---|---|---|---|
| **T3** | Migrate 4 inline `rounded-full bg-neutral-100` category badges in /search to `<Tag>` | `src/app/search/page.tsx:233,237,242` (3 explicit) + 1 more identified during inspection | L | Tag already exists with `flagship/standard/tier_t1` variants; choose `standard`. |

---

## Bucket D — External link icon (T4, P2-027)

| # | Task | Files | Complexity | Notes |
|---|---|---|---|---|
| **T4** | Add `<ExternalLink>` icon (lucide-react) to /research entries when `external: true` | `src/app/research/page.tsx:67-70` | L | Match the pattern used in `/control-room/framework` PredecessorFooter — small `size={14}` icon next to link text. |

---

## Bucket E — Divider class extraction (T5, P2-040)

| # | Task | Files | Complexity | Notes |
|---|---|---|---|---|
| **T5** | Reduce repeated `border-b border-[var(--color-neutral-200)] dark:border-[var(--color-neutral-700)] pb-2` pattern. Extract a `divider-row` Tailwind utility class OR a small `<DividerRow>` wrapper. | `src/app/design-system/page.tsx` Type scale + Reading measures sections (~6 instances) | S | Decide: utility class (preferred — no new component) vs component. Add to globals.css as `@layer utilities` rule if going utility-class route. |

---

## Bucket F — Heading scale alignment (T6, P2-012 + P2-037)

| # | Task | Files | Complexity | Notes |
|---|---|---|---|---|
| **T6** | Replace raw `text-2xl` / `text-3xl` headings with `text-[length:var(--text-display-{md,lg})]` where the section is intended as a primary section header | `src/app/case-studies/page.tsx` Methodology + Meta-analysis sections + 5 `text-3xl` instances flagged in the audit (lines 23, 53, 61, 69, 77 — verify against current file) | S | Some `text-2xl` are intentional for sub-headers (h3 vs h2). Spot-check each before changing. Goal: every h2 uses display-md or display-lg; every h3 uses text-2xl or smaller. |

---

## Bucket G — Hero elevation (T7, P2-002)

| # | Task | Files | Complexity | Notes |
|---|---|---|---|---|
| **T7** | Replace inline gradient with elevation tokens on Hero | `src/components/home/Hero.tsx` | S | Inspect first — may already use semantic tokens. If gradient is intentional brand chrome, leave + document why. |

---

## Bucket H — Minor polish (T8 — bundle 5 small items, P2-006/013/019/033/034)

| # | Task | Files | Complexity | Notes |
|---|---|---|---|---|
| **T8** | Bundle 5 minor polish items into one commit. Each is small enough that splitting adds review overhead; keeping bundled keeps the feature scoped. | Various — see audit doc | S | (a) P2-006 contact link consistency · (b) P2-013 Wrench icon DS-fy · (c) P2-019 glossary `<dt>` term-label class · (d) P2-033 audit metadata link consistency · (e) P2-034 padding breakpoint stack — for each, decide ship-as-is OR fix; if neither is obvious, defer to "won't fix unless triggered" and document |

---

## Bucket I — Verification (T9-T10)

| # | Task | Files | Complexity | Notes |
|---|---|---|---|---|
| **T9** | Run `npm run figma-drift` — expect 0 findings (no manifest changes) | (verification) | L | |
| **T10** | Run `npm run build` — expect green | (verification) | L | |
| **T11** | Spot-check on Vercel preview: `/pm-flow`, `/framework`, `/research`, `/search`, `/case-studies` for visual regressions vs pre-migration baseline | (manual operator step post-deploy) | L | Document in PR description; operator verifies in browser |

---

## Bucket J — Closure (T12)

| # | Task | Files | Complexity | Notes |
|---|---|---|---|---|
| **T12** | Case study at `FT2/docs/case-studies/fitme-story-design-system-p2-cleanup-case-study.md` summarizing the burndown, decisions made (especially T8 ship-vs-defer per item), and remaining "won't fix" notes | (case study) | S | Frontmatter must satisfy FEATURE_CLOSURE_COMPLETENESS gate (7 fields + kill_criteria_resolution). Parent-case-study cross-link required. |

---

## Summary

- **Total tasks:** 12 across 10 buckets (A-J)
- **Critical path:** T1-T8 in parallel (each touches different files); T9-T10 verify; T11 operator post-deploy; T12 closure
- **Estimated effort:** ~3-4h for T1-T8 (mechanical migrations), <30 min for T9-T10, ~30 min for T12
- **Repo:** fitme-story only (no FT2 code changes; just state.json + log + case study FT2-side)
- **Branch strategy:** isolated worktree at `/Volumes/DevSSD/fitme-story-p2-cleanup` (per v7.8.1)

**Awaiting user approval to advance to Phase 4 (Implementation).**
