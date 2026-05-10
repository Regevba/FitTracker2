# Tasks — fitme-story-website-design-system

**Phase:** 2 (Tasks)
**Framework:** v7.8.2
**Created:** 2026-05-10
**Companion:** [`prd.md`](./prd.md)

**Sequencing principle:** ship value early (Bucket A motion tokens unblock Bucket B showcase route which surfaces the value of Bucket C coverage; Bucket D drift detection completes the observability loop; Buckets E/F/G are completeness work that can land in any order).

**Complexity legend:** L = lightweight (haiku, ≤10 tool uses), S = standard (sonnet, ≤25), H = heavyweight (opus, ≤50).

**Repo legend:** `[FS]` = fitme-story repo, `[FT2]` = FitTracker2 repo, `[BOTH]` = touches both.

---

## Bucket A — Motion / elevation / z-index tokens (3 tasks)

| # | Task | Repo | Files touched | Complexity | Depends on |
|---|---|---|---|---|---|
| **T1** | Add motion + elevation + z-index tokens to Figma file `fsjHfFLAHELACZHku8Rfcl` via Figma MCP. Create new variable collection or extend existing. Tokens: `motion-duration-fast/standard/slow`, `motion-easing-standard/decelerate/emphasized`, `elevation-1..4`, `z-base/header/modal/toast`. | [FS] | Figma file (via MCP) | S | none |
| **T2** | Mirror tokens in Tailwind `@theme` block + `globals.css`: add `--motion-*`, `--elevation-*`, `--z-*` CSS variables matching T1's Figma values. Verify dark-mode overrides where needed (elevations may differ). | [FS] | `src/app/globals.css` | S | T1 |
| **T3** | Add tokens to `src/lib/design-system.ts` typed manifest (creating the file if not present): export `motionTokens`, `elevationTokens`, `zIndexTokens` arrays with `{ name, value, figmaNodeId? }` shape. Include light + dark values where they differ. | [FS] | `src/lib/design-system.ts` (new) | S | T2 |

---

## Bucket B — Public `/design-system` showcase route (6 tasks)

| # | Task | Repo | Files touched | Complexity | Depends on |
|---|---|---|---|---|---|
| **T4** | Build `src/lib/design-system.ts` typed manifest schema: `Component { name, status (Stable/Experimental/Deprecated/Internal), category (Token/Primitive/Layout/Card/Callout/Bespoke), figmaNodeId, githubPath, codeSnippet, dark_mode_status (Designed/AutoDerived/NotApplicable), variants[]? }`. Populate with the 17 already-mapped components + 4 primitives. | [FS] | `src/lib/design-system.ts` | H | T3 |
| **T5** | Build the showcase-only components: `ComponentCard.tsx`, `TokenSwatch.tsx`, `VariantGrid.tsx`, `StatusBadge.tsx` under `src/components/design-system/`. Each is server-render-safe (no client-only hooks at module top level). Include copy-to-clipboard via `'use client'` boundary. | [FS] | `src/components/design-system/*` (new) | H | T4 |
| **T6** | Create `/design-system` route: `src/app/design-system/page.tsx` rendering hero + sticky section nav (anchor links per category) + each section iterating over `design-system.ts` entries. Light + Dark side-by-side preview per component. Match `/glossary` page structure conventions. | [FS] | `src/app/design-system/page.tsx` (new), `src/app/design-system/layout.tsx` (if needed) | H | T5 |
| **T7** | Add showcase route to `SiteHeader` navigation (or appropriate primary nav surface). Verify it appears correctly on desktop + mobile. | [FS] | `src/components/SiteHeader.tsx` (or equivalent) | L | T6 |
| **T8** | Add showcase route link to `/control-room/framework` health dashboard so operators can jump from framework health to design-system observability. | [FS] | `src/app/control-room/framework/page.tsx` (or equivalent) | L | T6 |
| **T9** | Add `metadata` (Next.js metadata API) for SEO: title, description, og-image. Keep the og-image consistent with site-wide branding. | [FS] | `src/app/design-system/page.tsx` | L | T6 |

---

## Bucket C — Component coverage expansion (~13 components) (8 tasks)

> Each task creates the `.figma.tsx` mapping file + adds the component to `design-system.ts` manifest + captures Figma node ID. Tasks are bundled by component family for efficiency.

| # | Task | Repo | Files touched | Complexity | Depends on |
|---|---|---|---|---|---|
| **T10** | Map control-room layout primitives: `Panel` + `MetricList` + `AlertsBanner`. Build Figma frames + COMPONENT conversion + `.figma.tsx` files + manifest entries. | [FS] | `src/components/control-room/Panel.figma.tsx`, etc. | H | T4 |
| **T11** | Map control-room data components: `TrackedDocLink` + `AuthPasskeyForm`. (`AuthPasskeyForm` may need variants for `loading` / `success` / `error` states.) | [FS] | `src/components/control-room/*.figma.tsx` | H | T4 |
| **T12** | Map control-room audit components: `DevicesTable` + `AuditEventRow` + `AuditLogPanel`. | [FS] | `src/components/control-room/*.figma.tsx` | H | T4 |
| **T13** | Map home/case-study card components: `MetricsCard` + `TaskCard` + `FeatureCard`. | [FS] | `src/components/*.figma.tsx` | S | T4 |
| **T14** | Map persona components: `PersonaBar` + `PersonaIndicator` + `PersonaLens`. | [FS] | `src/components/*.figma.tsx` | S | T4 |
| **T15** | Sweep all `.figma.tsx` files (existing 12 + 13 new = 25 total) — verify each has correct Figma node URL, no template-literal URLs (per PR #80 lesson), and matching manifest entry. Smoke-run `npx figma connect publish --dry-run`. | [FS] | All `.figma.tsx` files | S | T10-T14 |
| **T16** | Update existing 4 primitive `.figma.tsx` files (Button, Tag, CaseStudyCard, FrameworkVersionCard) with status field if the manifest schema now exposes status to Code Connect. | [FS] | `src/components/Button.figma.tsx`, etc. | L | T4 |
| **T17** | Verify `design_system_figma_parity_coverage` ≥ 95% by running `figma-drift.mjs` (after T18-T20 land) and recording the result in state.json `metrics.primary.current`. | [FS] | (no file change) | L | T15, T20 |

---

## Bucket D — Drift detection (5 tasks)

| # | Task | Repo | Files touched | Complexity | Depends on |
|---|---|---|---|---|---|
| **T18** | Build `fitme-story/src/lib/figma-drift.ts` (importable logic) and `fitme-story/scripts/figma-drift.mjs` (CLI). Logic reads `design-system.ts` + scans `.figma.tsx` files + queries Figma file via Figma MCP / REST API. Output: total components, mapped count, parity %, list of unresolved Figma node IDs (in code but not in Figma file), list of orphan Figma nodes (in Figma but not in code). | [FS] | `src/lib/figma-drift.ts`, `scripts/figma-drift.mjs` (new) | H | T15 |
| **T19** | Add 5 unit tests for `figma-drift.ts` covering: full-parity input, missing node IDs, orphan Figma nodes, malformed manifest entries, rate-limit fallback path. Use Vitest (matching fitme-story's existing test setup). | [FS] | `src/lib/__tests__/figma-drift.test.ts` (new) | S | T18 |
| **T20** | Add `npm run figma-drift` script to `fitme-story/package.json` + `make figma-drift` Makefile target in FT2 that delegates (via cd to fitme-story checkout or a documented script call). Add documentation block at the top of the Makefile. | [BOTH] | `fitme-story/package.json`, FT2 `Makefile` | L | T18 |
| **T21** | Build CI workflow `.github/workflows/figma-drift-weekly.yml` (in fitme-story): runs Mondays 06:00 UTC, runs the script, opens a `framework-status` issue if drift > 5%. Skips cleanly if `FIGMA_ACCESS_TOKEN` repo secret is absent. | [FS] | `.github/workflows/figma-drift-weekly.yml` (new) | S | T18 |
| **T22** | Append drift report section to `docs/design-system/figma-code-sync-status.md` (FT2): each script run appends a dated entry. Helper logic in `figma-drift.mjs` writes the file. | [BOTH] | FT2 `docs/design-system/figma-code-sync-status.md`, FS `scripts/figma-drift.mjs` | S | T18 |

---

## Bucket E — Dark-mode parity audit + matrix (2 tasks)

| # | Task | Repo | Files touched | Complexity | Depends on |
|---|---|---|---|---|---|
| **T23** | Manual audit pass: walk every component in `design-system.ts`, verify Light + Dark Figma frames exist, record contrast ratio, last-audited date, status (Designed / AutoDerived / NotApplicable / TODO). For components without explicit Dark Figma frames, mark "AutoDerived" if token swap is sufficient or "TODO" if needs designer attention. | [FS] | `src/lib/design-system.ts` (`dark_mode_status` per entry) | H | T4 |
| **T24** | Generate the matrix doc `docs/design-system/fitme-story-dark-mode-coverage.md` from the manifest data (could be hand-authored or auto-generated by a small script). Include summary stats at the top: total components, % with Dark designed, % AutoDerived, % TODO. | [FS] | `fitme-story/docs/design-system/fitme-story-dark-mode-coverage.md` (new) | S | T23 |

---

## Bucket F — Contribution guidelines (1 task)

| # | Task | Repo | Files touched | Complexity | Depends on |
|---|---|---|---|---|---|
| **T25** | Author `fitme-story/docs/CONTRIBUTING-design-system.md` covering: (a) when to add a new primitive vs. reuse, (b) naming convention + file location, (c) Code Connect mapping checklist (web side), (d) deprecation/migration without breaking case-study MDX, (e) dark-mode design checklist, (f) motion/elevation token usage, (g) status transitions (Experimental → Stable → Deprecated). Add a linked summary section to the showcase route footer. Link from CLAUDE.md key-paths in FT2. | [BOTH] | `fitme-story/docs/CONTRIBUTING-design-system.md` (new), `fitme-story/src/app/design-system/page.tsx` (footer), FT2 `CLAUDE.md` | S | T6 |

---

## Bucket G — Analytics + verification + case study (5 tasks)

> **Scope expansion 2026-05-10** — Per user directive, the showcase route MUST surface "all of the data and ux/design decisions made on the site so far". Implication: the manifest carries `auditNotes` per token/component referencing past audit-finding fixes (A-002, A-018, T24, CS-006, CS-020, R-009). A dedicated `src/lib/design-system-heritage.ts` file holds the design-decisions log (locked case-study Alt A chrome, frontmatter audit results, ArticleNav addition, etc.). Showcase Part 2 includes a "Design heritage" subsection that walks the past audit decisions. See `cross-references.md` §1 for the full inventory.



| # | Task | Repo | Files touched | Complexity | Depends on |
|---|---|---|---|---|---|
| **T26** | Implement the 4 GA4 events: `design_system_section_view` (intersection observer), `design_system_component_expand` (click handler on cards), `design_system_code_copy` (copy-to-clipboard handler), `design_system_figma_link_click` (anchor click). Use `'use client'` wrappers as needed. Add to `src/lib/analytics.ts` (or equivalent). | [FS] | `src/lib/analytics.ts`, `src/components/design-system/*` | S | T6 |
| **T27** | Add the 4 events to `docs/product/analytics-taxonomy.csv` with `screen_scope: design_system` + required/optional params per PRD §9. Run `/analytics validate` (or equivalent) to confirm compliance with screen-prefix naming rule. | [FT2] | `docs/product/analytics-taxonomy.csv` | L | T26 |
| **T28** | Verify all 4 events fire correctly via GA4 Real-Time DebugView on Vercel preview deployment. Capture screenshot evidence + add to state.json `phases.testing.instrumentation_verified: true`. | [FS] | (no file change; verification only) | L | T26 |
| **T29** | Lighthouse run on staging preview of `/design-system`: a11y ≥ 95, performance ≥ 80, LCP ≤ 2.0s p75. Capture report; if any guardrail fails, file fix-task before merge. | [FS] | (verification only) | S | T6, T26 |
| **T30** | Author case study at `FT2/docs/case-studies/fitme-story-website-design-system-case-study.md` + showcase MDX in `fitme-story/content/04-case-studies/` (slot number reflects v7.8.2 chronological position; intercalating filename prefix if needed). Frontmatter includes 7 required fields (`date_written`, `dispatch_pattern`, `success_metrics`, `kill_criteria`, `framework_version`, `work_type`, `tier_tags_present`). | [BOTH] | `FT2/docs/case-studies/...md` (new), `fitme-story/content/04-case-studies/...mdx` (new) | H | T28, T29 |

---

---

## Bucket H — Post-feature holistic site audit (3 tasks; QUEUED, not in scope for THIS feature's PR)

> **Triggered by user directive 2026-05-10:** "when design system is finished let's review the entire site under the design system lens and see what other enhancements needs to be made". DEFERRED until after Buckets A-G ship. See `cross-references.md` §4 for context.

| # | Task | Repo | Files touched | Complexity | Depends on |
|---|---|---|---|---|---|
| **T31** | Walk every fitme-story route through the now-completed design system lens. Routes: `/`, `/case-studies`, `/case-studies/[slug]`, `/glossary`, `/framework`, `/framework/dispatch`, `/framework/dev-guide`, `/timeline/[version]`, `/research`, `/trust`, `/about`, `/pm-flow`, `/control-room/*`. Capture findings (component drift, missing tokens, dark-mode gaps, contribution-doc-violating patterns) as `docs/research/{date}-fitme-story-design-system-lens-audit.md`. | [BOTH] | New research doc | H | Buckets A-G complete |
| **T32** | Triage findings by P0 / P1 / P2. File P0/P1 as targeted backlog items or open fix-PRs against fitme-story; document P2s as "won't fix unless triggered" notes. | [FT2] | `docs/product/backlog.md` | S | T31 |
| **T33** | Update `MEMORY.md` index + create `project_fitme_story_website_design_system_shipped.md` capturing: showcase URL, parity coverage achieved, drift findings count, audit synthesis link, follow-up tracker. | [FT2] | `~/.claude/.../memory/*` | L | T32 |

---

## Summary

- **Total tasks (in scope for this feature):** 30 (Buckets A-G; matches §13 estimate of 28-32)
- **Queued post-feature tasks:** 3 (Bucket H, T31-T33)
- **Critical path:** T1 → T2 → T3 → T4 → T5 → T6 → (T15 ← T10-T14) → T18 → T20 → T21 → T26 → T29 → T30
- **Parallelizable groups:** T10/T11/T12/T13/T14 (component mapping); T7/T8/T9 (route polish); T19/T21/T22 (drift detection peripherals); T23/T24 + T25 (audit + contrib doc) can run alongside Bucket C
- **Repo distribution:** [FS] only: 25 tasks. [FT2] only: 1 task (T27). [BOTH]: 4 tasks (T20, T22, T25, T30)
- **Complexity distribution:** H = 8 (T4, T5, T6, T10, T11, T12, T18, T23, T30) ; S = 13 ; L = 9
- **External dependencies:** Figma MCP for T1 + T10-T14 + T18 + T23 ; GA4 DebugView access for T28 ; Vercel preview deployment for T29
- **Branch strategy:** All tasks land on `feature/fitme-story-website-design-system` branch in fitme-story (and FT2-side companions on FT2 main via small targeted PRs that do not need feature-branch isolation since they're docs/Makefile only)

**Awaiting user approval to advance to Phase 3 (UX/Integration).**

Phase 3 will produce:
- `/ux preflight` to verify every token/component named in tasks exists in fitme-story codebase (or is being created in this feature)
- `ux-spec.md` for the `/design-system` route covering: page structure, section composition, component card layout, dark-mode preview pattern, accessibility (keyboard nav, screen reader landmarks, focus management), responsive breakpoints, motion handling
- `/design preflight` to verify Figma MCP liveness + Figma library accessibility + Code Connect write access (advisory; we know publish is blocked but write-access probe still runs)
- `/design build` (post-spec approval) to push the showcase + new component frames into Figma library
