# ios-code-connect — Tasks

> **Status:** Placeholder. No work started. Waiting on `scheduled_after.signal: fitme-story-public-enhancements T20 phase=complete`.
>
> Once T20 ships in the rollup feature, this feature replays the same Code Connect pattern for iOS — pointing at the FitMe Design System Library Figma file (`0Ai7s3fCFqR5JXDW8JvgmD`) instead of the FitMe Story Web file (`fsjHfFLAHELACZHku8Rfcl`).

## Tasks

- [ ] **T1** — Install `@figma/code-connect` Swift toolchain + author `Figma.toml` at FT2 repo root pointing at FitMe Design System Library `0Ai7s3fCFqR5JXDW8JvgmD`. (~0.25d)
- [ ] **T2** — Capture per-component node IDs from FitMe Design System Library. Cover every reusable component in `FitTracker/DesignSystem/AppComponents.swift` (~13 components per CLAUDE.md design system reference). (~0.25d, blocked on T1)
- [ ] **T3** — Author `.figma.swift` template files — one per component mapping Figma component → SwiftUI view in `FitTracker/DesignSystem/`. (~1d, blocked on T2)
- [ ] **T4** — Run `figma connect publish` — push iOS mappings to FitMe Design System Library; verify Code Connect snippets appear in Figma Dev Mode. (~0.25d, blocked on T3)
- [ ] **T5** — Document iOS Code Connect workflow in `docs/design-system/` as a companion to `fitme-story-design-architecture.md` (from T21 of the rollup feature). (~0.25d, blocked on T4)

**Total estimated effort:** ~2.0 days once unblocked.

## Resume signal

Watch for: `fitme-story-public-enhancements/state.json::tasks[id=T20].status == "done"`. When it fires, advance this feature out of placeholder mode.
