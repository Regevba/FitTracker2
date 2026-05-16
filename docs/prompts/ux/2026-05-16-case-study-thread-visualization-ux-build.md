# UX Build Prompt — case-study-thread-visualization

> **Generated:** 2026-05-16 by /pm-workflow Phase 3 (auto-handoff prompt)
> **Companion design prompt:** [`docs/prompts/ui/2026-05-16-case-study-thread-visualization-design-build.md`](../ui/2026-05-16-case-study-thread-visualization-design-build.md)
> **Source spec:** [`.claude/features/case-study-thread-visualization/ux-spec.md`](../../../.claude/features/case-study-thread-visualization/ux-spec.md)
> **Hard-pause:** Phase 4 starts 2026-05-22 (after v7.9 promotion decision 2026-05-21)

---

## What you're building

A horizontal **timeline component** for the **fitme-story public site** that connects multi-part case studies into visible threads. Today readers see ~63 case studies as a flat list; threading exposes the ~10 multi-part series (UCC, HADF, framework-integrity-v7, ui-audit, design-system-sweep, framework-history, smart-reminders, training-plan, onboarding-v2, push-notifications) as connected progressions.

The user's intent is **discoverability before click** — when a reader hits the listing page, they should immediately see "this is a 6-part series" without clicking into any individual study.

## Why this matters

Current state: invisible threads. UCC is 4 case studies (cleanup-control-room v4.3 → control-center-alignment v4.3 → unified-control-center v7.6/v7.8 → ucc-passkey-auth v7.8.1) but renders as 4 isolated slots on the listing. Same for framework-integrity-v7 (12 parts), ui-audit (8 parts), design-system-sweep (7 parts). Readers must manually piece together version numbers + prose mentions to discover the progression.

Threading = the framework's story becomes legible at a glance.

## Locked decisions (the user already approved these — don't re-litigate)

1. **Visual approach:** Option 2 — horizontal timeline (prominent), NOT compact series-bucket cards
2. **Scope:** ≥3-member clusters only (10 series). The 13 two-member clusters defer to v1.1 pending engagement metric
3. **Framework chain split:** `hadf` (4 parts) and `framework-integrity-v7` (12 parts) are SEPARATE series, not one mega-cluster
4. **Backfill:** 4 new MDX showcases needed (`12a-hadf-hardware-aware-dispatch`, `08b-onboarding-v2-retroactive`, `23d-push-notifications-v1`, `27a-fitme-story-website-design-system-orig`)
5. **Naming:** kebab-case series IDs, hybrid (short for projects: `ucc`, `hadf`; longer for framework version: `framework-integrity-v7`)
6. **Listing layout:** new Series section ABOVE the existing v7-category accordions; all 10 timelines expanded by default
7. **Detail page:** timeline at top of every MDX with `series_id`; current part has "you are here" marker

## What's already verified

- **All tokens cited in ux-spec exist** in fitme-story DS (`globals.css`) — see [`ux-preflight-audit-2026-05-16.md`](../../../.claude/features/case-study-thread-visualization/ux-preflight-audit-2026-05-16.md)
- **fitme-story has no existing horizontal-timeline component** — you're building novel UI (`TimelineNav` is a footer prev/next, NOT a timeline visualizer; don't be misled by the name)
- **`<Tag tone="subtle">`** is the right primitive for version markers
- **Detail page wraps MDX in 3 templates** (StandardTemplate / FlagshipTemplate / LightTemplate) — modify all three to accept an optional `seriesTimeline?: ReactNode` prop

## Implementation order (per tasks.md T9-T24)

1. **T9** — Add `series_id: z.string().optional()` to `src/lib/content-schema.ts` (next to unused `related[]` at L77)
2. **T10** — Create typed `src/lib/series-catalog.ts` with the 10 locked series (use the table in [`research.md` §13](../../../.claude/features/case-study-thread-visualization/research.md))
3. **T11** — Create `src/lib/series.ts` helpers: `getSeriesById(id)`, `getStudiesBySeries(id)`, `getSeriesPosition(slug)` returning `{series, index, total, prev, next}`
4. **T12** — Build `SeriesTimeline` listing variant (server-rendered base)
5. **T13** — Build `SeriesTimeline` detail variant with "you are here" marker (extends T12)
6. **T14** — Integrate into `src/app/case-studies/page.tsx` (new Series section above v7 accordions)
7. **T15** — Modify 3 templates + detail page to pass `seriesTimeline` between `<header>` and `{children}`
8. **T16-T19** — Author 4 backfill MDXs (use `26-ucc-passkey-auth.mdx` as frontmatter template)
9. **T20** — Mechanical frontmatter sweep: add `series_id` to ~46 existing MDX files
10. **T21** — GA4 events: `case_study_series_view`, `case_study_series_node_click`, `case_study_series_keyboard_nav` (skip `case_study_series_nav_click` — reserved for v1.1)
11. **T22** — Responsive: vertical stack on `<640px`, horizontal scroll w/ snap on `640-1023px`, full layout on `≥1024px` with label compression for ≥8-node series
12. **T23** — A11y: keyboard nav (Tab/Arrow/Enter/Home/End), ARIA (`role="navigation"`, `aria-current="page"`, `aria-label` per node), focus ring (reuse Button pattern)

## Success criteria (per PRD §"Acceptance Criteria")

- All 10 series render on listing page; each shows series title + version range + part count
- Every detail page in a series has the timeline at top with "you are here" marker
- 4 backfill MDXs published with 7 required frontmatter fields each
- Keyboard nav works end-to-end (Tab → focus, Arrow → traverse, Enter → activate)
- AXE-core baseline maintained; no new violations
- LCP ≤ baseline + 100ms

## Pitfalls to avoid

1. **Don't introduce new DS tokens** — every color/spacing/motion value should map to an existing `--color-*` / `--motion-*` / Tailwind default. If you reach for a custom number, stop and check the token list in [`ux-spec.md` §3](../../../.claude/features/case-study-thread-visualization/ux-spec.md)
2. **Don't render `<SeriesTimeline>` when `series_id` is null/unresolved** — return null silently. CI drift check covers unresolved IDs at PR time
3. **Don't push to Figma DS library mid-implementation** — the `code-connect-automation` workflow auto-scaffolds `.figma.tsx` mappings from the FINISHED component code. Premature Figma push creates spec/build drift
4. **Don't skip the reduced-motion case** — fitme-story has a global `@media (prefers-reduced-motion: reduce)` rule that disables transitions. Your hover-translateY effect will be silently disabled for motion-sensitive readers; that's correct, just be aware
5. **Don't include the `case_study_series_nav_click` event in v1** — there's no prev/next nav supplement; the timeline IS the navigation
6. **Don't backfill UCC MDXs (parts 1-2) before 2026-05-23** — that's the B8 UCC kill-criteria checkpoint; touching UCC source case studies before it resolves risks polluting the resolution data
7. **Don't edit `CLAUDE.md` from the canonical worktree** — `BRANCH_ISOLATION_VIOLATION` Mode B fires; use `scripts/create-isolated-worktree.py` first
8. **Don't run Phase 4 work before 2026-05-22** — `state.json.scheduled_after.signal` documents the hard-pause; jumping early contaminates v7.9 calibration data

## Calibration window reminder

The 2026-05-15 → 2026-05-21 v7.9 calibration window is OPEN. Phase 4 (Implementation) gate fires from MDX edits + state.json phase transitions would dilute the criterion #2 "no false positives" signal. Wait until 2026-05-22.
