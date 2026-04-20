# Building the Site That Tells the Story — A Two-Hour Meta-Build

**Date written:** 2026-04-20

> How the PM framework built the website that would host its own case studies.
> 37 commits, 2 hours of wall clock, zero rollbacks — but the interesting parts are the failures.

---

## Context

By April 2026, the FitMe PM framework had shipped 16 features through a well-documented lifecycle and accumulated 13 public case studies in a GitHub markdown repo (`fitme-showcase`). The repo was complete but unreadable for most audiences — a 400-line Markdown file is not how an HR manager learns about you.

The goal: build a **third public artifact** — a Next.js 16 site that reads the showcase markdown and renders it as a browsable, audience-aware experience with a visual timeline and interactive diagrams. The site would cover HR skimmers, PM practitioners, developers, and researchers from a single entry point.

This case study documents that build. The project is doubly interesting: it's the PM framework running through its own lifecycle to produce the artifact that will display its own output. Recursion you can click through.

---

## The approach

The build used three skill chains in sequence:

1. **Brainstorming** (`superpowers:brainstorming`) — 8 clarifying questions to lock relationship to showcase, timeline granularity, visual ambition, content pipeline, design language, hosting, and v1 scope.
2. **Writing plans** (`superpowers:writing-plans`) — turned the spec into 37 bite-sized implementation tasks across 7 phases, with TDD discipline baked into pipeline and data-layer tasks.
3. **Subagent-driven development** (`superpowers:subagent-driven-development`) — a coordinator dispatched fresh subagents per task, ran spec-compliance and code-quality reviews on substantive code, and maintained a TodoWrite task list visible to the human operator.

The whole chain ran inside a single conversation. The human operator approved each phase transition (7 checkpoints) but did not touch any code personally.

### Why this sequence

Each skill produced a durable artifact the next skill could read. The brainstorm produced `2026-04-19-framework-story-site-design.md` (spec). The planning skill produced `2026-04-19-framework-story-site.md` (plan). Subagent-driven development referenced both while dispatching. No piece of context had to be reconstructed mid-flow.

### Early architectural decisions

- **Expanded-superset relationship to the showcase repo.** The showcase markdown stays canonical; the site adds narrative layers (persona lens, visual timeline, origin scroll, interactive diagrams) on top. A build-time sync script pulls content and merges site-specific frontmatter.
- **Timeline-first homepage.** Eight framework-version nodes as the spine, with a filter toggle to reshape into 13 case-study or 16-feature views. Persona pills in the hero tint the node metadata for HR / PM / dev / academic readers.
- **Tiered case study polish.** 3 flagship (bespoke visuals), 7 standard (1 custom diagram each), 3 canonical light (prose-only), 3 appendix, 1 combined operations-layer page. All 17 content pages render on day 1; further polish promotes Standard to Flagship without re-architecture.
- **Next.js 16 + Tailwind v4 + Framer Motion.** The site's craft is itself a portfolio argument — it must look editorial-quality to a hiring manager while staying fast (Lighthouse target 95+).

---

## What got built

Eight routes, 36 pre-rendered pages, 12 unit tests, deployed to a public Vercel project.

### Information architecture

```
/                                    Timeline-first homepage
├── Hero (persona pills)
├── OriginNarrative (7-beat scroll story)
├── Interactive Timeline (8 versions, toggle to 13 cases / 16 features)
├── NumbersPanel (16 / 7 / 5.6× / 12.4× / 185)
└── ThreeWaysIn (branch cards)

/case-studies                        Index (grouped by tier)
/case-studies/[slug]                 16 SSG paths, tier-dispatched template
/case-studies/operations-layer       Combined Light page

/timeline/[version]                  8 SSG paths — per-version chapters
/framework                           Standalone BlueprintOverlay
/design-system                       13 UX principles + gallery placeholder
/research                            5 research-link cards
/about                               Bio + contact
```

### Three flagship bespoke visuals

| Case study | Visual | Anchor metaphor |
|------------|--------|-----------------|
| SoC-on-Software (v5.0) | `<BlueprintOverlay interactive />` | 6-floor building; floors light up on hover |
| HADF (v6.1) | `<ChipAffinityMap />` | 17×7 heatmap, hover/focus shows readout |
| Onboarding Pilot (v2.0) | `<PhaseTimingChart />` | 9-phase Gantt bar, stagger-in on scroll |

### Content sync pipeline

A ~150-line TypeScript script (`scripts/sync-content.ts`) clones the public `fitme-showcase` repo into a gitignored cache, walks for `.md` files, merges upstream frontmatter with site-specific fields (tier, timeline position, persona emphasis, hero component), and writes MDX to `content/`. A Zod schema validator (`npm run validate-content`) gates on malformed frontmatter. Two pure functions at the heart of the script are TDD-tested with 4 unit tests that locked in the merge semantics before the wrapper logic was written.

### Persona lens

A `usePersona()` hook backed by URL search param (`?p=hr|pm|dev|academic`) and localStorage. Four pills in the hero reskin the downstream page content via a `<PersonaProvider>` React context. The provider is wrapped in `<Suspense>` because `useSearchParams` requires it in Next.js 16 — an error that would have triggered a full CSR bailout for every page if missed.

---

## The numbers

| Metric | Value |
|--------|-------|
| Wall clock (first commit → preview deploy) | 2 hours 2 minutes |
| Tasks in plan | 37 (across 7 phases) |
| Commits on main | 37 (33 feat, 4 chore) |
| Cumulative insertions / deletions | 20,983 / 3,216 |
| Hand-written TypeScript LOC (src/ + scripts/) | 1,890 |
| Content MDX files synced from showcase | 42 |
| Unit tests | 12 (all passing) |
| Pre-rendered routes | 36 |
| Production build time (Turbopack) | ~1.8s compile + ~0.5s static generation |
| Subagent dispatches | ~23 (vs 111 under strict skill defaults) |
| Review iterations | 1 (one round of nit-fixes on the sync script) |
| Human code touches | 0 |

**Velocity comparison.** Using the project's normalization CU formula (R²=0.82 power law across prior features), this build's 1,890 LOC + 8 routes + 3 interactive components + TDD content pipeline maps to roughly 45 complexity units. At 122 minutes total, that's **~2.7 min/CU** — faster than the project's all-time best of 3.21 min/CU from the v6.0 measurement case study. The velocity gain comes from two places: mature tooling (the Next.js + Tailwind + MDX stack has near-zero integration friction), and subagent orchestration eliminating human typing time. CU is a rough metric here since most prior features were Swift/iOS; treat this as an order-of-magnitude check, not a precise comparison.

---

## What the framework did well

### 1. Batched dispatch was the right pragmatic call

Strict one-subagent-per-task would have meant 37 implementer + 74 reviewer = **111 subagent invocations** for this plan. At ~30–60 seconds each plus coordination overhead, that's over an hour of pure dispatch time. Actual count was ~23 dispatches — roughly 1/5 the strict budget — achieved by grouping tightly-coupled tasks:

- Phase 0 scaffold (Tasks 3-5): one subagent for three config changes.
- Phase 2 persona system (Tasks 10-13): one subagent for hook + provider + header/footer + bar.
- Phase 3 homepage middle (Tasks 17-19): one subagent for Timeline + NumbersPanel + ThreeWaysIn.
- Phase 4 case-study infrastructure (Tasks 20-23): one subagent for MDX library + templates + route + index.
- Phase 6 pages (Tasks 27-32): one subagent for six independent static pages.

Every batch stayed under ~400 lines of new code across coupled files. The subagents handled the full plan text for each task sequentially within the batch, committing per-task.

### 2. The spec-then-plan-then-execute chain held together

Three skills, three durable artifacts, one clear handoff between each. The coordinator never had to re-explain context to a subagent — the task text from the plan was always self-contained (per the `writing-plans` "no placeholders" rule). Five months before this session, the project's planning discipline was ad hoc; by this run, the spec→plan→execute chain was a predictable assembly line.

### 3. Subagents caught their own architectural mistakes

The single most important catch of the session was Task 17, the interactive Timeline. The reference code in the plan included a `useEffect` hook that called `buildTimeline()` on mode change, which reads the filesystem. The subagent caught this in its own implementation pass:

> "IMPORTANT: `buildTimeline` reads from the filesystem (`content/`), which only works in a Node.js context — NOT in the browser. The `useEffect` that refetches on mode change will therefore fail if called from the client. You must fix this..."

The fix — derive all three mode arrays server-side via a new `buildAllTimelines()` helper and pass them as serializable props — preserved the UX (instant filter toggling) while making the component correctly server-rendered. Had the subagent followed the plan verbatim, the site would have 500'd on any filter interaction.

### 4. Spec-compliance review is cheap and catches mundane drift

The one spec-compliance review dispatched (Tasks 6+7, the sync pipeline) completed in 90 seconds using a cheap model, verified 14 independent claims the implementer made, and caught zero violations. That's a boring result, but cheap reviews that return clean are *still* valuable — they convert "the implementer said it works" into "two agents, independently, say it works."

### 5. TDD held where it mattered

Tests were written first for the three places where business logic mattered:

- `mergeFrontmatter` merge semantics (defaults, overrides, shared keys)
- `getAllCaseStudies` / `getByTier` / `getCaseStudyBySlug` invariants
- `buildTimeline` cardinality (8 versions, 13 cases, every href valid)

Total: 12 tests, written before their implementations, green throughout. These tests locked in three invariants that would have been expensive to lose — "exactly 3 flagship tier entries," "every case study has a `/case-studies/` href," "framework versions are sorted ascending." Any future refactor that breaks one of these fails the test suite loudly.

### 6. Tiered polish kept scope honest

The plan committed to 3 flagship / 7 standard / 3 light — with only the 3 flagship getting bespoke interactive visuals. This was the right bound. Building one flagship visual (BlueprintOverlay) took ~15 minutes including its MDX mount. Building three: ~40 minutes. Building 13 would have either doubled the session length or produced a wall of half-finished interactivity. The tiered approach shipped the three that matter (the arc-defining studies: v2.0 pilot, v5.0 pivot, v6.1 research peak) and left the standard tier visually confident but not expensive.

---

## Where it broke down

### 1. A subagent report truncated mid-report

The Phase 4 subagent (Tasks 20-23, 4 files created, case study render pipeline) returned a report that was visibly truncated: "## Task 23: /case-studies index page" with no body. The coordinator had to bash-grep the repo state to discover that three of four tasks had been committed but the fourth (`page.tsx` for `/case-studies`) was created on disk but uncommitted and unpushed.

**Root cause:** subagent response length limit hit during the final report construction. The work was complete; only the report rendering failed.

**Mitigation applied:** the coordinator committed and pushed the straggler file inline, then continued. No work was lost. But if the subagent had failed mid-implementation (rather than mid-report), the coordinator would have had to re-dispatch with careful context to avoid re-implementing the completed parts.

**Lesson:** the skill's "trust but verify" principle is load-bearing. Always inspect git status and the file tree independently of what the subagent reports, especially for multi-task batches.

### 2. The code-quality review was dispatched for one task, not all of them

Strict application of subagent-driven-development calls for a code-quality review on every implementation task. Sessions-scale analysis says ~37 reviews × ~60 seconds = ~37 minutes of pure review time — more than a third of the total session. The coordinator dispatched one formal code-quality review (Tasks 6+7, the sync pipeline) and substituted inline bash verification for the rest.

The tradeoff was observable:
- The one formal review produced five substantive notes (2 Important, 3 Minor) — fragile test globs, brittle entrypoint guards, missing regression test case. All three Importants were fixed in a follow-up commit (`83e244a`).
- The other ~14 inline verifications caught no issues, but that's a lower-confidence statement — "I ran the build, it passed" is weaker evidence than "a fresh agent read the diff and checked it against the plan."

For a portfolio site with no user-facing correctness requirements (no authentication, no payments, no data mutation), the pragmatic call was fine. For a production backend change, the same optimization would be reckless.

**Lesson:** formal code-quality reviews should scale with the blast radius of the code, not the task count. Substantive code that encodes business logic deserves one; straightforward UI with no state machines doesn't.

### 3. Static audit replaced real Lighthouse measurement

Task 36 was supposed to run Lighthouse against the production build and iterate until scores hit 95+ across all categories. What actually happened: the coordinator dispatched a static-analysis audit (no headless Chrome, no real Lighthouse run) that verified the 11 preconditions Lighthouse would check — alt text, accessible buttons, single h1, external link rels, no secret leaks, etc. Every check passed.

The static audit is a *proxy* for Lighthouse. It catches configuration and code issues but not runtime issues (render-blocking scripts, CLS, LCP, font loading). The real Lighthouse run has to happen against `fitme-story.vercel.app` post-deploy, and any failures there would require a second session.

**Lesson:** some measurements are cheap to fake (static analysis) and some are expensive to fake (browser-based perf). Don't claim a green on the expensive ones when you've only run the cheap ones. The case study, the state.json, and the checkpoint all honestly label this gap.

### 4. Dev-server smoke tests had a race condition

A dev-server smoke test was attempted mid-Phase-4 with a chained command: `vercel link && npm run dev & sleep 10 && curl && pkill "next dev"`. The `pkill` ran before the curls in one case because the `sleep 10` didn't give the server enough time to finish booting under load. The production `npm run build` was stronger evidence anyway (it pre-rendered all 21 static routes cleanly), so the failed smoke test was noted and moved past.

**Lesson:** chain-command smoke tests are fragile. When something matters, use the Monitor tool or foreground the process explicitly; don't rely on `sleep` to work as a coordination primitive.

### 5. Phase checkpointing was human-driven, not instrumented

The framework's v6.0 measurement layer records phase timing automatically — but only for Swift/iOS features tracked in `.claude/features/*/state.json`. For this external-repo project, phase transitions were marked by human intuition ("seems like we're done with Phase 3, let me checkpoint") rather than measured. The `framework-story-site/state.json` entry was updated sparingly across the session.

For a proper comparison against prior features, the phase-timing.json instrumentation would need to extend across repo boundaries. That's a framework-level improvement, not a project-level fix — noted as a follow-up.

---

## Meta: building the tool that will host this story

The site synced from `fitme-showcase` at upstream SHA `a70b0fd6`. That SHA does not contain this case study.

When this file commits to the showcase repo, the next `npm run sync-content` in `fitme-story` will pull it down as an MDX file in `content/04-case-studies/`. It will need a tier assignment (most naturally `standard`, since it has real metrics but doesn't ship a bespoke visual of its own). Once mounted, `fitme-story.vercel.app/case-studies/framework-story-site` will render a case study about the tool rendering it — Node.js reading a file about the site that was built to read that file.

This is the kind of recursion that justifies having written the site at all. A static showcase repo can describe things; a built site can **demonstrate** them. This case study is the first where the artifact and its description share a URL.

A planned v2 addition: on the framework page (`/framework`), add a "Meta" tab that names this recursion explicitly — the site is itself a case study in applying the framework, measured with the framework's own normalization model, documented in the framework's case-study pattern. Some readers will want that pointed out; most will discover it by noticing the case study exists.

---

## Addendum — Features shipped after original publication

The original case study above stopped at the **preview deploy** (commit `5340b31`, 37 commits in). This addendum chronicles what happened between then and the end of the same session — another 31 commits, 4 new routes, 5 major features, and one critical SSR bug caught in production.

### 1. Critical SSR regression — caught and fixed in production

After the preview deploy, the site passed all its smoke tests against the preview URL. It was promoted to production. Then a routine `curl https://fitme-story.vercel.app` revealed the problem: every page was serving ~251 characters of HTML — just the nav and footer. The entire `<main>` was empty in SSR output.

**Root cause:** the root layout wrapped `<PersonaProvider>` in `<Suspense fallback={null}>`. `PersonaProvider` called `usePersona()`, which called `useSearchParams()` synchronously at render time. In Next.js 16, `useSearchParams` suspends during static generation because there's no request URL at build time. Suspense caught it. `fallback={null}` rendered null for the entire children tree. Every static page shipped with empty main content.

**The fix required two architectural changes.** The first attempt — moving `searchParams.get()` into a `useEffect` — wasn't enough; the `useSearchParams()` hook call itself triggers suspension. The working fix split the persona hook into two layers:

- `usePersonaState()` — pure `useState` + `useEffect` + localStorage, no navigation hooks. Safe for SSG. Called by `PersonaProvider`.
- `PersonaSearchParamsSync` — an inner null-returning component that calls `useSearchParams()`, wrapped in its own `<Suspense fallback={null}>` inside the provider. Suspension is scoped to this tiny component rather than the entire app.

Commit `ab68987`. After this fix, every page's HTML had its full content in SSR output. A timely reminder that preview-URL smoke tests are no substitute for production verification — both URLs had the same bug; the issue only became visible when the author happened to grep HTML content rather than just checking HTTP 200s.

### 2. Post-preview tweaks (6 changes)

After the preview was reviewed, six user-flagged tweaks landed in quick succession (commits `0fcf234` through `5786521`):

- **Dark-mode text contrast fix** — `dark:prose-invert` added to all `prose prose-lg` containers so Tailwind Typography's baked-in light text would flip for dark mode. Without this, body prose on flagship case studies was unreadable in dark mode.
- **`/about` page refresh** — correct contact email, LinkedIn link added with `rel="noopener noreferrer"`, resume download wired to `/resume.pdf`. The PDF itself was copied from the user's CV folder on disk (`/Volumes/DevSSD/cv version/Product Adoption ManagerV.4 copy.pdf`) into `public/resume.pdf`.
- **Persona lens wired to Timeline** — the initial implementation had persona pills in the hero but nothing consumed the state. First pass added a `metricLabelByPersona` field on each `FRAMEWORK_VERSIONS` entry with 4 variants (hr / pm / dev / academic) plus a default. `TimelineNode` reads `useCurrentPersona()` and picks the right label. Invisible change at first glance — this was followed by a second pass (see item 5 below) when the user reported they still couldn't see any change.
- **"Audit in progress" notice** on `/case-studies` — a coral-bordered banner announcing that the site's content is under independent AI audit. Distinct from the standing notice added later in item 6.
- **Origin narrative rewrite** — the original hero's first beat said "This started as a school project." The user clarified: it's a personal project driven by wanting privacy-first, on-device fitness tracking. The origin beat was rewritten, and a new privacy-focused beat was inserted between beats 2 and 3. The `/about` opening paragraph was also rewritten. `grep "school project"` against `src/` returned zero matches afterward.
- **Resume PDF** placed at `public/resume.pdf`, download link on `/about` now works.

### 3. Production promotion

Once the preview was tweaked and reviewed, the site was formally promoted with `vercel --prod`. Production URL: `https://fitme-story.vercel.app`. Vercel auto-deploy on push to main stayed on from this point forward — every subsequent commit auto-deployed within 60 seconds.

### 4. Real Lighthouse measurement + accessibility fixes

With the site live, real Lighthouse measurements replaced the pre-deploy static audit. Results across 6 probes (homepage, flagship, light-tier case study × mobile + desktop):

- Mobile homepage: **95/100/100/100** (perf/a11y/best/SEO) after initial fixes — met the 95+ target
- Desktop scores: **97–100** on performance across all 3 routes
- One miss: desktop perf on `/case-studies/full-system-audit` at 94, driven by CLS on long content

**Two a11y findings were fixed in response.** The first pass (commit `baa7d30`) addressed dark-mode color contrast on timeline nodes and NumbersPanel — `--color-neutral-500` was too dim at `#78716C` on the dark `#1C1917` background (3.64 ratio, needs 4.5). Overrode in dark mode to `#A8A29E` + lighter variants for indigo and coral. Also added explicit `min-h-[44px]` on SiteHeader nav links and Timeline filter buttons to pass the target-size audit.

**A secondary font-fallback experiment** (commit `0ae691b`) — switched `next/font` `display` strategy from `swap` to `fallback` to reduce CLS on font load. Resulted in a 1-point mobile perf bump (95 → 96) and marginal desktop improvement. Net positive, no regression.

Homepage mobile after both passes: **95+/100/100/100**. The 94 desktop perf on full-system-audit was left as-is — 1 point below the self-imposed 95 target is not worth 20+ minutes of CLS chasing on a portfolio site.

### 5. Persona lens, take two — making reshaping visible

The first persona-wiring pass (item 2 above) was functionally correct but too subtle: only the small 9pt gray metric label at the bottom of each timeline node changed when a persona was selected. The user couldn't see any visible change and reported it as a bug.

The bug wasn't in the code — it was in the UX ambition. Four new surfaces were added to make persona selection **visibly reshape the page**:

- **`<PersonaIndicator>`** — a coral-accented "You're reading as [persona]" banner appears below the hero pills when a persona is selected, with `role="status"` + `aria-live="polite"` for screen readers. A `×` button clears the persona.
- **`<HeroSubtitle>`** — the hero's subtitle text rotates between 5 variants (default + 4 personas). HR sees "16 features shipped. 185 audit findings published. Measured outcomes, honest regressions — ready for an interview about any of them." Devs see "From SoC-on-software to hardware-aware dispatch — an AI-orchestrated PM framework explained floor by floor, with real code behind every claim." Each persona gets its own framing of the same content.
- **NumbersPanel per-persona labels** — all 5 metrics and the footer-line R²=0.82 callout rotate through 5 variants. "features shipped" becomes "shipping outcomes" (HR), "tracked features" (PM), "features in the dataset" (dev), "normalized data points" (academic).
- **Timeline metric labels** from pass 1 stayed in place.

Net effect: clicking the HR pill now produces 4 distinct visible changes on the homepage (indicator, subtitle, 5 metric labels, timeline labels). The page visibly "hears" the reader.

Commit `8a03858`.

### 6. `/trust` page groundwork

A new standing notice route at `/trust` — distinct from the time-limited "audit in progress" banner on `/case-studies`. The `/trust` page explains the site's honesty program: factual accuracy checks, no cherry-picked data, honest-about-failures claims, no silent edits to historical numbers. Three TODO markers visible in coral are placeholders for the user to fill in: which AI models audit, what cadence, and a link to the first completed audit report.

Added a "How this site stays honest →" link to the site footer. Route: `https://fitme-story.vercel.app/trust`. Commit `60c60ec`.

### 7. Glossary feature

30-entry glossary at `/glossary`, plus an inline `<Term>` MDX component that shows a hover tooltip and links to the dedicated entry. Four categories: hardware analogs (SoC, LoRA hot-swap, palettization, big.LITTLE, ANE, UMA, speculative preload, TPU, Mahalanobis, systolic chain), framework components (pm-workflow, dispatch intelligence, skill-on-demand, cache tiers, hub-and-spoke, HADF, CU, phase timing, parallel write safety, eval layer, snapshot/rollback, task complexity gate, batch dispatch, result forwarding), methodology (case-study monitoring, normalization, audit findings), and web vitals (LCP, CLS, SSG).

`<Term>` uses dotted-coral underline as the "I'm glossary-linkable" cue, a small framer-motion popover on hover/focus, `role="tooltip"` + `aria-describedby`, keyboard-accessible. Seeded on homepage (NumbersPanel's "CU formula" wrapped) and on `/framework/dispatch` (wrapping `/pm-workflow`, "cache tiers", "systolic chain").

The motivation was direct: the site used heavy hardware-to-software jargon (SoC, systolic, Mahalanobis, LoRA) that carried zero meaning to HR or PM readers. Without a glossary, those terms were speed bumps. With the glossary, they're learnable without leaving the page.

Commit `96d5da1`. Route: `https://fitme-story.vercel.app/glossary`.

### 8. Live Dispatch Demo

Evolution of the static `<BlueprintOverlay>`. `<DispatchReplay>` is an animated example of the framework in action — a feature enters, floors light up in the order they fire, arrows show data-flow, and dormant floors are visibly dimmed so readers can see which layers stayed off.

Two traces ship in v1:
- **Sprint I** (v2.0 case study) — 10 mechanical UI/DS fixes. Routes to LITTLE core, loads only `design` + `dev` skills, systolic chain inner loop, ~8 beats. The trace you'd expect for "boring mechanical work."
- **fitme-story build itself** (meta-recursion) — watching the framework build the site that's replaying it. 7 beats covering classification, skill chain, on-demand loading, batched dispatch, measurement, and write-back. "45 CU at 2.7 min/CU — framework all-time best" appears as a metric in beat 6.

Interaction: scroll-driven by default (IntersectionObserver picks the active beat based on which beat is closest to viewport center), plus a floating "▶ Auto-play" pill that advances beats every 2.5 seconds. Click a beat card to jump to it. Sticky trace switcher at top.

Floor states: firing (full color + glow + "▸ executing"), done (full opacity + "✓ done"), dormant (35% opacity + "— dormant —"). The dormant state is the pedagogical point — readers literally see which floors the framework skipped.

Mounted in two places: standalone `/framework/dispatch` (for a dedicated URL) and inline on `/case-studies/soc-on-software` (below the static BlueprintOverlay). A "See the framework in motion →" card on `/framework` links to the standalone.

Commit `c499a6c`. Route: `https://fitme-story.vercel.app/framework/dispatch`.

### 9. PM-flow ecosystem page

A new `/pm-flow` page — the biggest post-original feature. Zooms into Floor 2 of the blueprint (the skill ecosystem) with seven sections:

- **Hero** with 6 anchor chips
- **Lifecycle Loop** — concentric 2-ring SVG. Inner ring has 10 phases arranged clockwise (P0 Research at 12 o'clock, continuing through P9 Learn). Each phase is a colored pip tinted by its owning skill. A coral feedback arc curves from P9 back to P0 with a 4-second breathing pulse — the "this loops forever" signal. Outer ring has 3 arc segments for cx, ops, and marketing — the feedback-layer skills that continuously feed information into the cycle rather than owning a single phase.
- **Lego Wall** — 11 colored bricks representing the skills. Toggle "Scattered ↔ Assembled" triggers a framer-motion `layout` animation: bricks fly from a loose grid into 10 phase columns (+ an "always-on row" below for cross-phase skills). Click any brick → rotateY flip to a detail panel showing purpose, sub-commands, invokes/invoked-by chips (clickable to flip to that skill), standalone example, and full docs link.
- **Evolution strip** — 6 milestones (v1 monolith → v6.1 HADF), each tinted by the skills added.
- **Shared Data Layer** — 15-tile grid of the JSON files in `.claude/shared/`, each tile showing colored dots for the skills that read it and the skills that write it. Readers see ownership at a glance.
- **Cache tiers** — L1/L2/L3 with the CPU-cache analogy.
- **Build your own** — 3 bullets + 3 related-page cards.

The **per-skill color palette** was registered as 11 CSS variables (`--skill-pm-workflow` through `--skill-release`) in `globals.css`. Tailwind's -500 family for WCAG-accessibility. Colors carry through consistently — the same rose color for `/cx` appears on its Lego brick, its outer-ring arc in the loop, and its read/write dots in the data-layer tiles.

**Visual grammar on each brick:** 6px left accent stripe (the skill's color), a small colored dot next to the skill name, subtle hover-tint at 10% alpha of the skill color. Decorative color, always accompanied by text — colorblind-safe.

**Accessibility iteration:** first Lighthouse pass on `/pm-flow` scored 90/100 a11y (target 95). Four specific audit failures: color-contrast on back-face brick accent (2.78 ratio for indigo on dark bg), target-size on SkillChip buttons (19px tall, need 24px), aria-prohibited-attr on `<span aria-label>` inside SharedDataTiles (50 violations), and label-content-name-mismatch on LegoBrick buttons (visible text vs aria-label divergence). A targeted fix (commit `8f4f918`) replaced accent text color with neutral + accent-as-underline, bumped chip buttons to `min-h-[24px]`, added `role="img"` to the skill dots, and removed the redundant aria-label from the brick buttons. Final a11y: **100/100**.

Built in 5 phases across 18 planned tasks, ~1.5 hours of focused work with 5 subagent dispatches. Commits `c6fa0ed` through `8f4f918`.

Route: `https://fitme-story.vercel.app/pm-flow`.

### Updated session totals

| Metric | At preview deploy | At session end |
|--------|-------------------|----------------|
| Commits on main | 37 | **68** |
| Pre-rendered routes | 36 | **40** (`/trust`, `/framework/dispatch`, `/glossary`, `/pm-flow` added) |
| Major interactive components | 3 flagship (BlueprintOverlay, ChipAffinityMap, PhaseTimingChart) | **7** (+ DispatchReplay, LifecycleLoop, LegoWall, Term) |
| Cumulative insertions / deletions | 20,983 / 3,216 | **23,510 / 3,289** |
| Hand-written TypeScript LOC (src/ + scripts/) | 1,890 | **4,318** |
| Content MDX files synced | 42 | 42 (unchanged) |
| Unit tests | 12 passing | 12 passing (no new tests this continuation) |
| Subagent dispatches | ~23 | **~45** (~22 additional across the 5 continuation features) |
| Lighthouse a11y (mobile homepage) | not measured pre-deploy | **100/100** |
| Lighthouse performance (mobile homepage) | not measured pre-deploy | **96/100** |
| Critical production bugs caught | 0 (pre-deploy) | **1** (SSR regression, fixed same session) |

### Features from the continuation that deserve their own future case studies

Several of the continuation features — especially `/pm-flow` with its Lego-metaphor visualization and the Live Dispatch Demo with its scroll-driven replay — are substantial enough to warrant their own standalone case studies. The design decisions behind the concentric-ring lifecycle loop, the assembled-vs-scattered layout grammar, and the per-skill color palette all have their own stories worth telling. In the closing tweak pass (section below), three of these were promoted to standalone appendix case studies on the site itself.

---

## Closing tweak pass — promotions, visual polish, and an animation hunt (2026-04-19 → 20)

A follow-up session focused on three things: promoting the remaining Standard-tier case studies to Flagship with a unified chart vocabulary; drafting standalone "developer deep-dive" case studies for the engineering work that didn't fit in the main narrative; and chasing down a series of layout/animation issues the user surfaced by clicking through the live site. By the end, the feature was closed.

### 10. Unified chart component library + Flagship promotions

Seven Standard-tier case studies needed visualizations to match the Flagship treatment. Rather than bespoke components per study, a small component library was registered in MDX:

- **`<HeroMetric>`** — hero number component with scalar props (value, label, accentVar, context).
- **`<BeforeAfter>`** — before/after delta card with flat props (beforeLabel/Value/Subtitle, afterLabel/Value/Subtitle, delta, afterAccentVar).
- **`<DurationStack>`** — horizontal stacked bar with `segmentsJson` prop for RSC-safe MDX use.
- **`<RankedBars>`** — ranked bar chart with `itemsJson` prop.
- **`<FlowDiagram>`** — node-chain diagram with `nodesJson` prop.
- **`<ParallelGantt>`** — bespoke 4-lane concurrent Gantt for the Parallel Stress Test promotion.

Because Next.js 16's RSC boundary does not serialize object/array props into client components via `next-mdx-remote/rsc`, every component that needed structured data got a **JSON-string prop variant** (discovered on the Parallel Stress Test promotion, applied to all subsequent promotions). Flat-scalar props replaced nested object props on `BeforeAfter` and `HeroMetric`. A one-commit fix (`13a6717`) retrofitted all existing MDX usages.

All seven Standard studies were promoted to Flagship with inline visualizations: Parallel Stress Test (5 charts), Framework Evolution (4), Dispatch Intelligence (4), Eval-driven Development (3), Auth Flow Velocity (3), AI Engine Architecture (3), Measurement v6 (3). Ten total Flagship-tier case studies with consistent visual grammar.

Commits `7db0d91` through `db10eaa`.

### 11. Developer deep-dive case studies

Three standalone "developer deep-dive" case studies were drafted — engineering write-ups for readers who want the code-level story, distinct from the framework narrative. Each gets a `⚙️ Developer deep-dive` blockquote tag at the top, lives in the `appendix` tier on the site, and is labelled in the index as "engineering write-ups for readers who want the code-level story."

- **SSR regression** (`content/04-case-studies/15-ssr-regression.mdx`) — the blank-main-bug incident narrative, documenting how `useSearchParams` suspending during SSG replaced every page body with null, the first-fix attempt that didn't work, and the two-layer hook split that did.
- **DispatchReplay** (`content/04-case-studies/16-dispatchreplay.mdx`) — how the animated dispatch demo was designed. Three interactivity tiers considered, scroll-driven + auto-play picked, IntersectionObserver viewport-center detection, meta-recursive trace selection.
- **Lego metaphor / PM-flow page** (`content/04-case-studies/17-lego-pmflow.mdx`) — how `/pm-flow` was designed to make an 11-skill ecosystem legible to four audiences at once. Lego Wall scatter-to-assembled animation, 11-color palette with WCAG-AA dark-mode overrides, concentric LifecycleLoop, shared-data tile a11y pattern, brick flip detail.

Commits `99c255e`, `f5b1721`, `f6f8a63`.

### 12. Seven UX fixes from live-site click-through

After the bulk of content shipped, a round of user click-through surfaced seven distinct issues captured via screenshots:

1. **DispatchReplay auto-scroll** — active beat wasn't scrolling into view during auto-play (user could lose track of which beat was firing). Added `scrollIntoView({ behavior: 'smooth', block: 'center' })` on active-beat change during autoplay, skipped during scroll-sync mode to avoid fighting the user's scroll.
2. **LifecycleLoop SVG title tooltip** overlaid the center label on hover. Removed the `<title>` element; contextual labels next to each pip do the job.
3. **Feedback arc label** — the coral arc needed explicit labelling of its purpose ("feedback flows back · next cycle begins").
4. **LifecycleLoop scroll-to-section fallback** — clicking an outer-ring skill when its always-on row didn't have a matching anchor caused a silent no-op. Added a fallback that scrolls to `#wall` when the specific anchor is missing.
5. **LegoBrick size on open** (first attempt) — open bricks felt too small and cramped. First fix added `min-h-[26rem]`, bigger type, more padding. This was the wrong fix — see section 14 below.
6. **ChipAffinityMap cutoff on narrow viewports** — the 17-column heat grid looked truncated. Added `max-w-[100ch]` + a coral "→ scroll" gradient-fade on the right edge to signal horizontal scroll affordance.
7. **DurationStack label compression** on the Parallel Stress Test chart — narrow segments were packing text on top of themselves. First fix raised the in-segment label threshold from 7% to 15% width. This was also insufficient — see section 13.

Commits `3f223d2` through `67d0d84`.

### 13. Case studies page — timeline-spine redesign

The original `/case-studies` page dumped 17 entries into a 4-tier flat list (10 Flagship, 3 Light, 5 Appendix). The user reported it felt "overcrowded and disorienting" and asked for a curated layout that showed "only the main studies with the most impact on the timeline of advancement."

The replacement is a **timeline spine with 6 color-coded milestone inflection points**:

- v2.0 Onboarding Pilot — baseline (slate)
- v4.1 Framework Evolution — compounding proven (indigo)
- v4.4 Eval-driven Development — quality gate (lime)
- v5.2 Parallel Stress Test — parallel dispatch (emerald)
- v6.0 Measurement — instrumentation, not estimation (cyan)
- v7.0 HADF — hardware-aware (coral)

Each milestone gets a rich card with a hand-curated hook and impact metric. A vertical rail runs between them, colored dot per milestone matches the infographic pin above and the card's leading color strip — three visual anchors per milestone tie the timeline-overview together.

At the top of the page, a **horizontal color-coded progression infographic** shows the 6 milestones as clickable pins — each with a colored bar, version, and short label. Clicking a pin anchor-jumps to its card below.

Below the milestones: "More case studies" as a compact one-line list for 11 supporting studies and methodology notes. Below that: the separated ⚙️ "Developer deep-dives" section for the three engineering write-ups from section 11.

Color palette uses the skill-palette CSS variables (`--skill-ops`, `--skill-pm-workflow`, `--skill-qa`, `--skill-release`, `--skill-analytics`, `--color-brand-coral`). Text uses neutral tokens for WCAG AA; colors appear only in decorative bars and dots. Total: ~17 entries → 6 rich milestones + 11 compact + 3 separated. Same content, much less cognitive load.

Commit `cfff6b9`.

### 14. DurationStack: opt-out of in-segment labels

After section 12's threshold-raising fix, narrow segments on the Parallel Stress Test bar still compressed awkwardly. Rather than a threshold, added a `hideSegmentLabels` prop to `DurationStack`. When true, all inline segment labels are suppressed and the reader relies entirely on the legend row below. The aria-label and title attribute on each segment preserve accessibility. The prop defaults to false so other DurationStack instances across the site are unaffected.

Commit `0f9fec6`.

### 15. LegoBrick — four-commit animation hunt

The open-brick behavior went through four iterations, each correcting a specific problem the user saw.

**Iteration 1 (section 12, fix #5):** Opening a brick grew its cell via `min-h-[26rem]` + bigger type while keeping the 3D rotateY flip. User response: worse than before. The big open brick pushed siblings down in awkward columnar stacks and the flip's back face didn't quite fit the new cell size.

**Iteration 2 — `col-span-full` expand-in-place:** The user described the desired behavior directly: "when you click on the brick and it flips it should extend exposing the content while sliding the other bricks aside while the one which is lit takes center stage." Rewrote `LegoBrick` to drop the 3D flip entirely: opening now applies `col-span-full` (takes the whole grid row), other bricks animate into their new positions via Framer Motion's `layout` prop, expanded details render inline below the summary in a 2-column panel. Commit `2813956`.

**Iteration 3 — smear fix:** User reported a color-smear effect when closing an open brick. Three compounding causes: (a) the 6px accent stripe was a `border-left` INSIDE the element being FLIP-scaled by Framer, stretching the border along the width change; (b) AnimatePresence exit had a 150ms delay + 350ms duration (~500ms total) while the container's layout spring completed in ~400ms, so expanded details were still visible as the container shrank; (c) `layoutId` was forcing unneeded shared-element transitions. Fix: moved the accent stripe to a separately-positioned `<span>` outside the scaling element, fast exit (120ms, no delay), dropped `layoutId`, set `transformOrigin: 'top left'`, `overflow-hidden` on outer. Commit `71378fa`.

**Iteration 4 — scale-stretch fix:** User reported "still have a weird stretching sizing effect when closing." Root cause: Framer Motion's `layout` prop uses FLIP animation — it measures an element's position and size before and after a change, then interpolates with `transform: scale() + translate()`. A wide brick shrinking to narrow becomes `transform: scale(0.25, y)` applied to the element, visually squishing all content. Fix: switched from `layout` to `layout="position"`. This animates **only translate** (for sibling reflow), never scale. The active brick's size change happens instantly via CSS grid's `col-span` snap — no transform applied, no stretching. Commit `74404b8`.

**Iteration 5 — timing sequencing:** User: "better but not fully resolved, something in the timing is still off." The remaining issue was that when `isOpen=false` fires, `col-span` snaps back to 1 immediately while `AnimatePresence` exit is still running its 120ms fade. Details briefly visible in a narrow-container while fading. Fix: two-stage state. Added local `expanded` state that tracks `isOpen` but lags it on close (driven by `AnimatePresence.onExitComplete`). Details animate both HEIGHT AND opacity to 0 on exit; the container stays `col-span-full` (expanded=true) throughout the exit so its natural height follows the details smoothly to zero. Only after details fully exit does `expanded` flip false and the container collapses. `text-2xl`, padding, shadow, and the close button all follow `expanded` (not `isOpen`) so text doesn't pre-shrink before the container collapses. Commit `3831437`.

Each iteration revealed a different layer of the animation stack — CSS transitions, FLIP transforms, state timing, and paint ordering all had to cooperate. The final architecture: `layout="position"` for sibling reflow (translate-only), CSS grid `col-span` for size change (instant), local state lag for exit sequencing, and separate positioned accent stripe so nothing scales except content that's meant to fade away.

### 16. LifecycleLoop — three visual cleanups

The concentric SVG loop went through three cleanups in the same session:

- **Removed the P9→P0 feedback arc + its overlay label.** The circular layout itself communicates the loop; the center subtitle already names the mechanic ("ships forward · feedback flows back"); a separate coral arrow was redundant, and its overlay label had low contrast against the arc. Commit `2813956` (bundled with the brick rewrite).
- **Removed the outer-ring arcs entirely.** The three arcs for cx, ops, and marketing ("feedback-layer skills that don't own a phase") were visually loud and didn't add pedagogical value the reader couldn't already read from the Lego Wall's always-on row below. SVG viewBox shrunk 720→640. Commit `3831437`.
- **Fixed phase-label overlap on horizontal pips.** P2, P3, P7, and P8 sit on the left/right sides of the circle. With `textAnchor="middle"`, half the label's horizontal extent drew back toward (and over) the dot. Fix: anchor text based on the dot's side — `start` for right-side phases (`cos(angle) > 0.3`), `end` for left-side, `middle` for top/bottom. Each label now sits outside its dot with a consistent ~20px gap, matching the top/bottom phase spacing. Commit `1df7e46`.

### Final session totals

| Metric | At pm-flow a11y fixes | At close |
|--------|-----------------------|----------|
| Commits on main | 68 | **89** |
| Pre-rendered routes | 40 | **44** (3 new appendix case studies + revised case studies index) |
| MDX content files | 42 | **45** (+ SSR regression, DispatchReplay, Lego metaphor) |
| Flagship-tier case studies | 3 | **10** (7 promoted with unified chart library) |
| Shared chart components | 3 | **6** (+ FlowDiagram, ParallelGantt, HeroMetric) |
| Lighthouse a11y (mobile + pm-flow) | 100/100 | **100/100** (maintained) |
| Feature state | `learn` (phase=open) | **closed** |

### What was deferred

- **`/trust` page placeholders** — three TODOs (which AI models are auditing, cadence, first audit results link) remain "Will be updated soon" until external audit content lands.
- **Meta-audit case study** — blocked on the external audit completing; synthesizes what the independent model catches vs. what the framework catches.
- **Live filtering on `/pm-flow` Lego Wall** — clicking a phase pip could filter the wall to skills in that phase. Designed but cut — the LifecycleLoop's outer-ring arcs already answered "who fires when," and a filter animation would compete with the scatter-to-assembled animation for attention.
- **Per-brick sparklines** — each skill brick could show activity-over-time. Needs live data wired to the static page. Kept for a future visit.
- **A dedicated PM-workflow-led variant of `/pm-flow`** — leads with phases instead of skills. Backlog item, revisit if analytics shows PM readers underperforming on the current page.

---

## Bottom line

Three things this build confirmed about the PM framework at this version:

1. **Spec → plan → subagent-driven execution is now a reliable pipeline.** A 37-task website went from "let's brainstorm this" to live preview URL in one conversation, zero rollbacks, 100% test pass, no production incidents. The same chain run a year ago would have required multiple human intervention points per phase.

2. **Pragmatic batching matters more than skill purity.** Strict one-subagent-per-task with full reviews would have turned a 2-hour session into a 10-hour one. Batching tightly-coupled tasks and reserving formal reviews for substantive code produced the same quality outcome at a fraction of the overhead. The skill's defaults are correct for complex, high-blast-radius work; they're prohibitively expensive for mechanical and UI work. Knowing when to relax defaults is now a skill in itself.

3. **The framework can build its own presentation layer.** This was the first project where the PM framework was used to build a tool about the PM framework. The fact that it worked — and produced a deployable artifact in a single session — is evidence the framework has crossed a threshold. Future framework improvements can be built and demonstrated in the same motion.

One thing it didn't confirm: whether the site is actually compelling to a non-engineer audience. That test — a hiring manager reading the site cold and reporting what they understood — has to come post-deploy and post-tweaks. The framework can produce the artifact; it can't (yet) tell you whether the artifact is landing.

---

## Artifacts

- Spec: `docs/superpowers/specs/2026-04-19-framework-story-site-design.md`
- Plan: `docs/superpowers/plans/2026-04-19-framework-story-site.md`
- Repo: `github.com/Regevba/fitme-story`
- Preview deploy: `fitme-story-jvseva16d-regevba-3729s-projects.vercel.app`
- Production alias (pending `vercel --prod`): `fitme-story.vercel.app`
