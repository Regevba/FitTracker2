# Watching the Framework Build the Site That's Replaying It — The DispatchReplay Component

**Date written:** 2026-04-20

> ⚙️ **Developer deep-dive.** React + Framer Motion · IntersectionObserver scroll-sync · meta-recursive trace design · Next.js 16 client components in MDX. PM/HR readers: this one is about how the animated demo on `/framework/dispatch` was designed and built — skip unless you want the motion-grammar rationale.

> Static blueprint diagrams tell you *what* a system is. They don't tell you whether it's running. Here's what changed when we made the framework visually execute in front of the reader — and why one of the two traces had to be the build of the site itself.

## Context

By the time the site shipped, it had a `<BlueprintOverlay>` — a static six-floor diagram showing the framework's layered architecture. Hover a floor, components reveal. Click doesn't do much. It was a good reference object. It was not, in any way, a demo of the framework *working*.

The question that drove the DispatchReplay build: how do you make a framework feel like it's running, without actually running it? An interactive component that plays a recorded trace of a real feature flowing through the six floors, one beat at a time — lighting up floors as they fire, dimming the ones that stay dormant, showing which data flows forward between them. Not a live simulator. A replay.

## The approach — three interactivity tiers, pick one

The initial brainstorming session debated three levels of ambition:

- **Replay mode.** Pre-recorded trace of one real feature playing through the floors. Scroll-scrubbable. Deterministic. Low cost.
- **Interactive demo.** User picks a feature type (fix / enhancement / flagship), dispatch plays out differently per type. Shows adaptive routing. Medium cost.
- **Live simulator.** Mock request drives the actual `.claude/shared/` JSON configs. Highest fidelity, highest maintenance.

Replay won on cost-to-value. The user ultimately asked for **replay with variety** — multiple traces so the viewer sees the framework react to different feature shapes. Two traces were picked:

1. **Sprint I** — the canonical overlay example from `docs/skills/framework-overlay-example-sprint-i.md`. 10 UI/DS mechanical fixes. Low risk. Routes to LITTLE core. Only 2 of 11 skills loaded. The "boring mechanical work" case.
2. **fitme-story build itself** — the site being built by the framework it describes. 45 CU at 2.7 min/CU. 23 subagent dispatches instead of 111. The meta-recursive case.

The second trace was the interesting one — watching the framework build the site that's replaying it. Not a trick; an honest trace. A hiring manager reading the page sees "it built this site that's showing you the trace" and understands that the artifact in front of them is the output of the system it depicts.

## The drive-mechanism decision

Three options considered for how a reader advances through the 7 beats of a trace:

- **Scroll-driven.** IntersectionObserver watches the beat cards; the one closest to viewport center is "active." Floors state reflects the active beat.
- **Auto-play timed.** Beats auto-advance every 2.5s. User watches without interacting.
- **User-stepped.** Next/prev buttons. User fully controls pacing.

Ship all three? No — too many affordances, too much surface to test. Ship **scroll-driven by default, auto-play as an opt-in pill.**

The floating "▶ Auto-play" button sits sticky at the top-right. Scroll as primary. Auto-play for anyone who wants to watch it run hands-free. The auto-play pill toggles to "Pause" when active; pressing it stops at the current beat. User-stepped is subsumed — clicking any beat card jumps directly to it.

Sticky trace switcher at the top lets users flip between Sprint I and fitme-story without losing scroll position. Click a pill, the trace changes, scroll position stays.

## Visual grammar — three floor states

The framework's whole pedagogy depends on **which floors stay off.** The critical insight: a lifecycle skill doesn't fire every floor on every task. Mechanical work skips the measurement overlay. Cached work skips cache-tier lookups. The replay had to make the *absence* visible.

So each floor has three states:

| State | Visual | Semantics |
|---|---|---|
| **Firing** | Full opacity + accent color glow + 1.015× scale + coral "▸ executing" badge | This floor is active in this beat |
| **Done** | Full opacity + "✓ done" label | This floor fired in a prior beat |
| **Dormant** | 35% opacity + muted "— dormant —" label | This floor was not used by this feature at all |

A reader watching the fitme-story trace sees floor 6 (measurement) firing once, then going dormant. They see floor 5 (dispatch intelligence) firing on the classification beat, done on subsequent beats. They see floor 2 (cache) firing only when cache was consulted. The dormant state is the pedagogy: *the framework chose not to use this floor*. The selective activation is the point.

## Interesting decisions

**1. Scroll-driven detection uses IntersectionObserver's viewport center, not top.** The naive implementation watches for "beat enters viewport." The problem: on long screens, multiple beats are visible at once. Which is active? The one at the center of the viewport. An `IntersectionObserver` with `rootMargin: "-45% 0px -45% 0px"` creates a narrow detection band in the middle of the viewport. Only the beat in that band is "active." Scrolling feels smooth because there's a clear focal point rather than an ambiguous multi-beat zone.

**2. Auto-play disables scroll-sync while running.** Auto-play advances beats on a timer. If scroll-sync were also active, scrolling would override auto-play. The auto-play handler sets a flag that disables the IntersectionObserver callback until paused. Opt-in pacing wins.

**3. Each beat can declare data-flow arrows.** Beats that emit cross-floor signals (e.g. "phase-timing tick writes to floor 6") include a `flow` array on the trace data. The component renders inline text like "Floor 4 → Floor 6 — phase-timing tick" under the beat. Not drawn as actual arrows on the floor diagram (too busy) — rendered as prose under the active beat card. Every beat can describe its own data movement without cluttering the floor visual.

**4. Reduced-motion users get instant transitions + 800ms auto-play.** `useReducedMotion()` gates every motion — no glow, no scale, no cross-fade. Auto-play still works but advances in 800ms instead of 2500ms since the dramatic-pause motivation (watch the animation) doesn't apply. Keyboard navigation works unchanged; scroll-sync still activates beats as they enter viewport.

**5. The fitme-story trace was written while the site was being built.** A real production commit could have been authored as a trace — but the meta-recursion demanded the trace be authored *during* the same session that produced the artifact. Each beat references something that was actually happening (subagent dispatches, phase timing, cache lookups). The trace was not invented post-hoc; it was a live narrative of the build in progress.

## Where it ships

Two placements:

1. **Standalone:** `/framework/dispatch`. Own URL. Dedicated page with short intro + component + "how this works" explainer at bottom. Linked from `/framework` with a "See the framework in motion →" card.
2. **Inline:** `/case-studies/soc-on-software`. The SoC-v5.0 flagship already had the static `<BlueprintOverlay>`. The DispatchReplay sits right below it with a `---` divider and "Now watch it run." lead-in. Readers see the static architecture first, then the live trace walking through it.

Both mounted from the same source component — no duplicated logic.

## What was left out

- **Live data-flow arrows drawn between floors.** The declarative flow arrays work but are prose under the beat card, not visual connectors on the diagram. Actual connector lines would need a coordinated layout state between floors and the beat column — meaningful complexity for marginal pedagogical gain. Deferred.
- **A third trace.** Two traces make the "variety" argument. A third would be gilding. If demand surfaces, adding one is trivial: push an object to the `TRACES` array with the correct beat structure, done.
- **Sharable permalinks per beat.** No URL hash per beat. A reader can't link a friend to "trace = fitme-story, beat = 4." Would require `?trace=fitme-story&beat=4` hydration on page load. Worth adding if the component gets heavy traffic. Not now.

## Bottom line

Static diagrams show you the shape of a system. Replays show you whether it moves. The DispatchReplay is the site's first honest answer to "does the framework actually work, or is it just a nice diagram?" — and the second trace, where the framework builds the site that's showing you the framework, is a receipt no static diagram can provide.

## Artifacts

- Component: `src/components/bespoke/DispatchReplay.tsx` + `src/components/bespoke/dispatch-traces.ts`
- Standalone page: [fitme-story.vercel.app/framework/dispatch](https://fitme-story.vercel.app/framework/dispatch)
- Inline mount: [fitme-story.vercel.app/case-studies/soc-on-software](https://fitme-story.vercel.app/case-studies/soc-on-software)
- Commit: `c499a6c`
