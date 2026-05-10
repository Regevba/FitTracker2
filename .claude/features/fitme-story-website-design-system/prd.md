# PRD — fitme-story-website-design-system

**Phase:** 1 (PRD)
**Framework:** v7.8.2
**Work type:** Feature
**Created:** 2026-05-10
**Companion:** [`research.md`](./research.md)
**Backlog item:** `docs/product/backlog.md` line ~169

---

## §1 Problem statement

The fitme-story website's design system has a strong foundation (33 Figma token variables + 17 component node IDs + 12 Code Connect mappings + the `/glossary` typed-manifest pattern), but it is **not yet operationally living**:

- Coverage is partial: ~57% of React components map to Figma (17 of ~30)
- No public surface lets designers, contributors, or external readers see what exists
- Code-to-Figma drift has no detection mechanism
- Dark-mode parity has not been audited per component
- Motion + elevation tokens live in code only — not in Figma
- Component contribution practice is implicit

Without these closures, every new UI feature shipped on the site adds entropy faster than it adds documentation. This PRD ships the 6 closures simultaneously.

---

## §2 Goals & non-goals

### Goals

1. Bring **`design_system_figma_parity_coverage`** from ~57% → ≥95%
2. Make the design system **publicly observable** via `/design-system` route on `fitme-story.vercel.app`
3. Make **drift detectable** within 24h of introduction (not 6 months)
4. Make **dark-mode parity verifiable** per component (matrix doc)
5. Make **motion + elevation tokens** as first-class as color/spacing/type are today
6. Make **contribution patterns** explicit so non-author contributors can add components correctly

### Non-goals

- Do NOT adopt Storybook (rejected per research §3 — adds tooling complexity without solving Figma drift)
- Do NOT block on Code Connect publish unblock (publish is separately gated by Figma plan-tier scope per `code-connect-automation` closure; the showcase route works WITHOUT publish)
- Do NOT build visual regression / Chromatic-style infra in v1 (deferred; revisit if drift reports surface visual-only drift not caught by node ID checks)
- Do NOT translate the showcase page to other languages (matches existing `/glossary`, `/case-studies` English-only convention)
- Do NOT build a `npx fitme-story add-component` CLI (overkill for current contributor base)

---

## §3 User stories

### Designer
> **As a designer**, when I open the FitMe Story Web design library in Figma, I want to know which components are in production code and which are stale or unmapped, so I can avoid spending time iterating on unused mockups.

→ Drift detection report + showcase route surface this.

### Developer (new contributor)
> **As a developer adding a new UI feature**, I want to know whether a primitive (Button, Tag, Card variant) exists before I author a fresh one, and how to add a new primitive correctly if not, so I don't fragment the system.

→ Showcase route + contribution doc surface this.

### Maintainer
> **As a maintainer**, I want a single CLI command (`make figma-drift` or equivalent) that tells me whether the live Figma file is in sync with `figma_node_ids` declared across all features, so I can catch drift before it becomes invisible debt.

→ Drift detection script delivers this.

### External observer
> **As an external reader of the framework story site**, I want to see the design system at the same level of polish as `/glossary` and `/case-studies`, so I can evaluate whether this project is a serious operation or a hobby site.

→ Public `/design-system` route delivers this.

### Mode-aware reviewer
> **As a reviewer of dark-mode behavior**, I want to verify per component that someone has DESIGNED the dark variant (not just relied on automatic token swap), so I can catch contrast/legibility issues before users see them.

→ Dark-mode parity matrix delivers this.

---

## §4 Solution overview

### 6 deliverables (sequenced)

| Order | Deliverable | Surface | Effort estimate |
|---|---|---|---|
| 1 | Motion + elevation + z-index tokens added to Figma variables collection | Figma file `fsjHfFLAHELACZHku8Rfcl` + Tailwind `@theme` + `src/lib/design-system.ts` | 2-4h |
| 2 | Public `/design-system` showcase route | `fitme-story/src/app/design-system/page.tsx` + `src/lib/design-system.ts` manifest | 1-2 days |
| 3 | Component coverage expansion (~13 more components mapped) | 13 new `.figma.tsx` files + Figma library updates | 1-2 days |
| 4 | Drift detection (`make figma-drift` or `npm run figma-drift`) | `fitme-story/scripts/figma-drift.mjs` + companion FT2-side make target | 0.5-1 day |
| 5 | Dark-mode parity audit + matrix | `docs/design-system/fitme-story-dark-mode-coverage.md` (live in fitme-story) | 0.5-1 day |
| 6 | Component contribution guidelines | `fitme-story/docs/CONTRIBUTING-design-system.md` (or equivalent) | 0.5 day |

**Total:** ~5-9 working days = 1.5-2 weeks concentrated, or 3-4 weeks interspersed.

### Architecture

```
fitme-story/
├── src/
│   ├── app/
│   │   └── design-system/
│   │       └── page.tsx                  ← Public showcase route
│   ├── lib/
│   │   ├── design-system.ts              ← Typed manifest (mirrors glossary.ts)
│   │   ├── design-system-figma.ts        ← Figma node ID map
│   │   └── figma-drift.ts                ← Drift detection logic (importable)
│   └── components/
│       ├── design-system/                 ← Showcase-only components
│       │   ├── ComponentCard.tsx
│       │   ├── TokenSwatch.tsx
│       │   └── VariantGrid.tsx
│       └── (existing primitives + 13 new .figma.tsx mappings)
├── scripts/
│   └── figma-drift.mjs                   ← CLI entrypoint for drift detection
├── docs/
│   ├── CONTRIBUTING-design-system.md     ← Contribution guide
│   └── design-system/
│       └── fitme-story-dark-mode-coverage.md  ← Matrix doc
└── (existing config: figma.config.json, tsconfig, etc.)

FitTracker2/
├── docs/design-system/
│   ├── fitme-story-design-architecture.md  ← Updated with new section refs
│   └── figma-code-sync-status.md           ← Drift report appended after each run
└── Makefile                                ← New target `make figma-drift` (delegates to fitme-story)
```

### Key design choices

1. **Reuse `/glossary` pattern, not Storybook**: typed `src/lib/glossary.ts` → `/glossary` page generalizes to typed `src/lib/design-system.ts` → `/design-system` page. Zero new dependencies.
2. **Manifest-driven, not auto-discovered**: components must be explicitly added to `design-system.ts` to appear in showcase. Forces intentional curation.
3. **Drift detection is on-demand, not per-PR**: respects Figma API rate limits; reports filed to `figma-code-sync-status.md` for review.
4. **Dark-mode matrix is markdown, not interactive**: shipped as plain `.md` doc; rendered in `/control-room/framework` health dashboard if it adds value later.
5. **Contribution doc lives in `fitme-story/`, not FT2**: it's a fitme-story-side process artifact (the iOS-side has its own `ios-code-connect-workflow.md` already).

---

## §5 Success metrics

> All metrics tagged with T1 (Instrumented) / T2 (Declared) / T3 (Narrative) per CLAUDE.md data quality tiers.

### Primary metric (T1 — instrumented)

**`design_system_figma_parity_coverage`** = `(components with .figma.tsx mapping + Figma node ID + design-system.ts entry) / (total React components with user-visible UI)`

| Field | Value |
|---|---|
| Baseline | ~57% (17 of ~30) |
| Target | ≥ 95% (28-29 of ~30 mapped) |
| Measurement | Automated via `figma-drift.mjs` (deliverable #4); reports component count |
| Cadence | On-demand (operator runs `make figma-drift`); CI runs weekly |
| Source | `figma_node_ids` declarations across all features × `.figma.tsx` files in `fitme-story/src/` × showcase manifest |

### Secondary metrics (T2 — declared)

| Metric | Baseline | Target | Cadence |
|---|---|---|---|
| `figma_build_status_deferred_count` | TBD (track manually today) | 0 after showcase route lands | Per-PR review |
| `dark_mode_parity_coverage` | TBD (deliverable #4 produces) | 100% of stable components have verified Light + Dark Figma frames | One-time audit + per-new-component |
| `time_to_render_design_system_route` | N/A (route doesn't exist) | ≤ 2.0s p75 LCP | Lighthouse on prod after launch |
| `showcase_completeness` | N/A | All 6 deliverables shipped + linked from `/control-room/framework` (T3) | One-time at feature close |

### Guardrail metrics (T2 — must NOT degrade)

| Metric | Threshold | Why |
|---|---|---|
| Homepage `/` LCP | Must not increase by > 100ms | New shared layout could affect bundle size |
| Build time | Must not increase by > 30s | Component live-render at build time could slow static gen |
| `/glossary` LCP | Must not regress > 50ms | Sister route; should not be coupled |
| `/case-studies` LCP | Must not regress > 50ms | Sister route; should not be coupled |
| Lighthouse a11y on `/design-system` | ≥ 95 | Same standard as existing routes |

### Leading indicators (week 1 post-merge)

- `/design-system` route is live and accessible at `https://fitme-story.vercel.app/design-system`
- Drift detection script runs once successfully; produces a report
- Contribution doc published and linked from CLAUDE.md key-paths
- Motion + elevation tokens visible in Figma library

### Lagging indicators (30/60/90 day)

- **30d**: How many new components have been added since launch? Did each hit `figma_parity_coverage` threshold within the same PR? Target: 100% of new components mapped at PR-time.
- **60d**: Drift report findings count — trending up = entropy increasing → consider stricter gate; flat or down = system is self-maintaining.
- **90d**: Number of designer/contributor commits to the contribution doc OR to `design-system.ts` — proxy for whether the surface is being used.

---

## §6 Kill criteria

If any of these fire post-launch, treat as a signal to roll back, narrow, or rethink:

| Trigger | Response |
|---|---|
| Drift between Figma file and code repeatedly exceeds **10%** within 30 days of a build pass (i.e., maintenance burden outpaces value) | Narrow scope to showcase route only; treat full Figma parity as documentation-grade rather than living source of truth. Document the decision in the case study + a `kill_criteria_resolution` field on state.json. |
| Public `/design-system` route adds **> 200ms** to homepage LCP | Roll back the shared-layout coupling; isolate the design-system route into its own bundle. |
| Contribution doc adoption < **3 commits/month** from non-author contributors after 60 days | Simplify or reframe (was it the wrong format?). Document the learnings in the case study; close the deliverable as "shipped but not load-bearing". |
| Dark-mode matrix audit reveals > **50% of components** have unintentional contrast/legibility issues in Dark mode | Ship the matrix as evidence + open a follow-up feature `dark-mode-remediation` with its own scope/PRD. Do NOT block this feature on remediation. |
| Drift detection script triggers Figma API rate limits in normal operation | Add caching; reduce cadence to weekly; fall back to scheduled CI-only. If still rate-limited, replace with manual checks. |

---

## §7 Acceptance criteria

A deliverable is considered shipped when ALL of these are true:

### Deliverable #1 — Motion + elevation + z-index tokens

- [ ] Figma file `fsjHfFLAHELACZHku8Rfcl` has new variable collection(s) covering: motion-duration tokens (fast/standard/slow), motion-easing tokens (standard/decelerate/emphasized), elevation tokens (level-1 through level-4), z-index tokens (base/header/modal/toast)
- [ ] Tailwind `@theme` block in `globals.css` has matching `--motion-*`, `--elevation-*`, `--z-*` tokens
- [ ] `src/lib/design-system.ts` exposes the token list to the showcase route
- [ ] `make tokens-check` (or equivalent fitme-story-side script) passes

### Deliverable #2 — Public `/design-system` route

- [ ] Route accessible at `https://fitme-story.vercel.app/design-system`
- [ ] Section anchor nav matches research §6 page structure (Tokens / Primitives / Layout / Cards / Callouts / Bespoke)
- [ ] Each component card shows: live render (Light + Dark side-by-side), variant grid, GitHub link, Figma node link, copy-to-clipboard code snippet, status badge (Stable / Experimental / Deprecated / Internal)
- [ ] Lighthouse score ≥ 95 on a11y; LCP ≤ 2.0s p75
- [ ] Page is linked from site header AND from `/control-room/framework` health page

### Deliverable #3 — Component coverage expansion

- [ ] At least 13 additional components have `.figma.tsx` mapping files in `fitme-story/src/components/**/*.figma.tsx`
- [ ] All 13 components are added to `src/lib/design-system.ts` manifest
- [ ] All 13 components have Figma node IDs in the FitMe Story Web library
- [ ] `design_system_figma_parity_coverage` metric ≥ 95%
- [ ] `figma-drift.mjs` reports 0 unresolved-mapping findings for these components

### Deliverable #4 — Drift detection

- [ ] `fitme-story/scripts/figma-drift.mjs` exists and is invocable via `npm run figma-drift`
- [ ] Companion FT2 Makefile target `make figma-drift` exists (delegates to fitme-story or invokes the script directly)
- [ ] Script reports: total components, mapped count, parity %, list of unresolved Figma node IDs, list of orphan Figma nodes (in library but not in code)
- [ ] Output is appended to `docs/design-system/figma-code-sync-status.md`
- [ ] Script handles Figma API rate-limit gracefully (caches, exits cleanly with helpful message)
- [ ] Script handles missing `FIGMA_ACCESS_TOKEN` gracefully (skips with clear log; does not fail CI)
- [ ] CI workflow `.github/workflows/figma-drift-weekly.yml` runs the script weekly and opens a `framework-status` issue if drift exceeds 5%

### Deliverable #5 — Dark-mode parity audit + matrix

- [ ] `docs/design-system/fitme-story-dark-mode-coverage.md` exists in fitme-story repo
- [ ] Matrix lists every component in `design-system.ts`
- [ ] Each row records: component name, Light Figma frame ID, Dark Figma frame ID, contrast verification status, last-audited date
- [ ] Companion section in the showcase route surfaces the matrix data per component (✓ / ✗ for Dark mode)

### Deliverable #6 — Contribution guidelines

- [ ] `fitme-story/docs/CONTRIBUTING-design-system.md` (or equivalent canonical path) exists
- [ ] Doc covers: when to add a new primitive vs. reuse, naming convention, file location, Code Connect mapping checklist (web side), how to migrate or deprecate without breaking existing case-study MDX, dark-mode design checklist, motion/elevation token usage rules
- [ ] Doc is linked from the showcase route's footer
- [ ] Doc is linked from CLAUDE.md key-paths

### Cross-cutting

- [ ] All 4 GA4 events fire correctly (verified via real-time DebugView): `design_system_section_view`, `design_system_component_expand`, `design_system_code_copy`, `design_system_figma_link_click`
- [ ] All events appear in `docs/product/analytics-taxonomy.csv` with `screen_scope: design_system`
- [ ] No regression on existing routes (`/glossary`, `/case-studies`, homepage)
- [ ] `make tokens-check`, `make ui-audit` (FT2 side as no-op since this is fitme-story-only), and fitme-story `npm run build` all pass
- [ ] Case study published at `docs/case-studies/fitme-story-website-design-system-case-study.md` (FT2) + showcase MDX in `fitme-story/content/04-case-studies/`

---

## §8 Test & eval requirements

### Unit tests

- `figma-drift.mjs`: at least 5 unit tests covering (a) full-parity input, (b) missing node IDs, (c) orphan Figma nodes, (d) malformed manifest entries, (e) rate-limit fallback path
- `design-system.ts` typed manifest: TypeScript build pass with strict mode (zero `any`, all entries match interface)
- Showcase page rendering: snapshot test on a representative subset (5 components) verifying the rendered DOM contains expected status badges + links

### Integration tests

- Showcase route Lighthouse run on staging preview: a11y ≥ 95, performance ≥ 80, LCP ≤ 2.0s p75
- Drift detection script integration test: invoke against a fixture Figma response, assert correct report output

### Eval coverage gate

- This feature does NOT touch AI surfaces (no AIOrchestrator, ReadinessEngine, NutritionRecommender, TrainingRecommender, CohortIntelligence, ai-engine/)
- Per v6.0 Eval Coverage Gate Protocol: **non-AI feature → auto-pass**
- `state.json.phases.testing.eval_results.min_eval_coverage_met = true` from the start

### Manual verification

- Visual inspection of the showcase route on `https://fitme-story.vercel.app/design-system` (preview + prod)
- GA4 Real-Time DebugView confirms all 4 events fire on user interaction
- One non-author contributor (the user themselves can simulate by reading the doc cold) reads `CONTRIBUTING-design-system.md` and reports whether they could add a hypothetical new component without follow-up questions

---

## §9 Analytics spec

Per CLAUDE.md naming convention (every screen-scoped event prefixed with screen name), and per v6.0 Analytics Spec Gate (must be approved before PRD):

| Event | Trigger | Required params | Optional params | screen_scope |
|---|---|---|---|---|
| `design_system_section_view` | User scrolls a section anchor (Tokens, Primitives, Layout, Cards, Callouts, Bespoke) into ≥ 50% viewport for ≥ 1 second | `section_id` (string), `is_first_view_in_session` (bool) | — | `design_system` |
| `design_system_component_expand` | User clicks a component card to expand variants/details | `component_name` (string), `component_status` (Stable/Experimental/Deprecated/Internal) | — | `design_system` |
| `design_system_code_copy` | User clicks copy-to-clipboard on a code snippet | `component_name` (string), `snippet_type` (react/figma/usage) | — | `design_system` |
| `design_system_figma_link_click` | User clicks a Figma node link from a component card | `component_name` (string), `figma_node_id` (string) | `outbound_url` (string) | `design_system` |

### Cross-screen context

- `app_open`, `session_start` — inherited from existing site instrumentation; no changes
- No `tutorial_*` or `select_content` GA4 recommended events apply here

### Migration / backwards compatibility

- New events; nothing to migrate
- All names compliant with `screen_<event>` prefix rule
- Add to `docs/product/analytics-taxonomy.csv` in the same PR that ships deliverable #2

### `analytics_spec_complete: true` is reachable when

- All 4 events have implementation in `src/lib/analytics.ts` (or equivalent)
- All 4 events appear in `analytics-taxonomy.csv`
- All 4 events fire correctly in GA4 DebugView
- `screen_scope: design_system` column is populated for all 4

---

## §10 Risks & mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Drift detection finds significant pre-existing drift on first run | Medium | Low (this is actually good — surfaces real debt) | Treat as data; file findings as backlog; do not block this feature on remediation |
| Dark-mode parity audit reveals widespread gaps requiring designer time | Medium | Medium | Ship matrix doc with `TODO` entries; fill incrementally as work happens; trigger kill criteria only if > 50% of components have legibility issues |
| Showcase route LCP regresses on shared layout | Low | High | Bundle-budget check in CI; isolate design-system route into its own segment if needed |
| Code Connect publish remains blocked (Figma plan-tier scope) | Already known (closed via `code-connect-automation`) | Low | Showcase route works WITHOUT publish; drift detection works WITHOUT publish; no dependency |
| New components added during this feature creation also need mapping | Medium | Low | Run drift detection at start; capture baseline; add new components to manifest as work proceeds |
| Figma MCP / API rate limits during drift detection | Low-medium | Medium | Cache responses; limit cadence to weekly CI + on-demand; document fallback to manual check |
| User leaves session before all 6 deliverables ship | Medium | Medium | Sequence so #1, #2, #4 ship first as core value; #3, #5, #6 are completeness; can pause between |

---

## §11 Dependencies

### Tooling already available

- Figma MCP (`mcp__claude_ai_Figma__*`) — for drift detection + variable creation
- `@figma/code-connect@1.4.4` (already installed in fitme-story devDeps)
- Tailwind v4 + `@theme` block in `globals.css`
- Vercel deployment pipeline (already wired)
- GA4 instrumentation already wired on the site

### External actions required

- None for the core feature
- Code Connect publish operates on its own re-activation timeline (per `code-connect-automation` deferral)

### Documentation cross-refs to update

- CLAUDE.md "Design system" section — add `/design-system` route + drift detection commands
- `docs/skills/design.md` — extend with `/design preflight` Step 3.6 (drift detection check, advisory)
- `docs/design-system/fitme-story-design-architecture.md` — add the 6 closures to the architecture
- `docs/design-system/figma-code-sync-status.md` — add Drift Detection section
- `fitme-story/content/01-pm-flow/*` — link to `/design-system` from the relevant pm-flow page
- `fitme-story/content/04-case-studies/` — slot showcase MDX for this feature post-merge

---

## §12 Open questions — RESOLVED 2026-05-10

All 6 questions resolved by user prior to PRD approval:

1. **Drift detection cadence** → ✅ **Weekly cron + on-demand CLI**. CI workflow `.github/workflows/figma-drift-weekly.yml` fires Mondays; operators run `make figma-drift` (FT2) or `npm run figma-drift` (fitme-story) on demand. Per-PR gating intentionally NOT added (rate-limit risk + noise outweighs value at this site's velocity).
2. **Showcase route path** → ✅ **`/design-system`**. Matches industry convention (Polaris/Atlassian/Primer); pairs with `docs/design-system/`. Final URL: `https://fitme-story.vercel.app/design-system`.
3. **Component status taxonomy** → ✅ **4-tier: Stable / Experimental / Deprecated / Internal**. Mirrors GitHub Primer's labels; sufficient for current scope. Revisit if Beta/Preview becomes useful.
4. **Dark-mode matrix location** → ✅ **`fitme-story/docs/design-system/fitme-story-dark-mode-coverage.md`**. Lives in fitme-story repo (alongside the components it documents); FT2 cross-references via `docs/design-system/figma-code-sync-status.md`.
5. **Contribution doc format** → ✅ **Both surfaces**. Canonical markdown at `fitme-story/docs/CONTRIBUTING-design-system.md` + linked summary section in `/design-system` route footer. The route summary teaser links into the canonical doc.
6. **iOS scope inclusion** → ✅ **No — fitme-story only**. iOS-side parallel evolution remains tracked separately (backlog item: ongoing build-out of iOS Figma library; `/design build` skill auto-populates per-feature). Keeps this feature focused at ~1.5-2 weeks; spawn a follow-up backlog item if iOS-side parity becomes a priority.

---

## §13 Phase 2 (Tasks) preview

The PRD will produce the following task buckets (full breakdown happens in Phase 2):

| Bucket | Approx tasks | Sequence |
|---|---|---|
| T1-T3: Motion/elevation/z-index tokens (Figma + Tailwind + manifest) | 3-4 tasks | First |
| T4-T8: Showcase route (`/design-system` page + `design-system.ts` manifest + ComponentCard / TokenSwatch / VariantGrid components) | 5-7 tasks | Second |
| T9-T15: Component coverage expansion (13 new `.figma.tsx` files + Figma node IDs + manifest entries) | 7-10 tasks | Third (parallel to #4 if possible) |
| T16-T20: Drift detection script (CLI + tests + CI workflow + Makefile + report writer) | 5 tasks | Fourth |
| T21-T22: Dark-mode parity audit + matrix doc | 2 tasks | Fifth (parallel-able) |
| T23-T24: Contribution guidelines + cross-doc updates | 2 tasks | Sixth |
| T25-T28: Analytics events + GA4 verification + taxonomy update + case study | 4 tasks | Final |

**Estimated total:** ~28-32 tasks across 6 deliverables.

---

## §14 Decision

**Recommend: Approve PRD; advance to Phase 2 (Tasks).**

This PRD ships the 6 deliverables as a single Feature with full 9-phase lifecycle. Primary metric instrumented; kill criteria explicit; analytics spec complete; eval gate auto-passes (non-AI feature). Risk profile is low-to-medium with each risk mitigated.

Awaiting user approval to advance to Phase 2.
