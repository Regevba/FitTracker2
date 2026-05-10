# code-connect-automation — Tasks

> **Status:** Implementation. ~2.0d total effort across 5 tasks.
>
> Closes the loop on `ios-code-connect` (PR #277) + fitme-story T20 (PR #75): both shipped Code Connect foundation, but neither auto-scaffolds mapping files for new UI features and neither auto-publishes on merge. This feature builds the 3 missing layers.

## Tasks

- [ ] **T1** — Layer A: build `scripts/scaffold-figma-mapping.py` (FT2/iOS) + `scripts/scaffold-figma-mapping.mjs` (fitme-story/web). Reads `<feature>/state.json::figma_node_ids`; for each node ID, scaffolds matching `.figma.swift` (iOS) or `.figma.tsx` (web) template file with the URL pre-filled + a placeholder example body. Idempotent — skips if file already exists. (~1d)
- [ ] **T2** — Layer A docs + first PR. README section + usage example. PR ships Layer A as foundation. (~0.25d, blocked on T1)
- [ ] **T3** — Layer B: extend `/design build` skill to invoke scaffold script after node ID capture. Modify `.claude/skills/design/SKILL.md` so when `/design build` populates `state.json::figma_node_ids`, it also runs `scripts/scaffold-figma-mapping.{py|mjs}` (auto-detects which repo). (~0.5d, blocked on T1)
- [ ] **T4** — Layer C: CI publish workflows (one per repo). FT2: `.github/workflows/figma-code-connect-publish.yml` runs `figma-swift connect publish` on merge to main when `*.figma.swift` files change. fitme-story: equivalent runs `npx figma connect publish`. Both gated on `FIGMA_ACCESS_TOKEN` repo secret (operator adds via GitHub UI). (~0.5d, blocked on T1)
- [ ] **T5** — End-to-end test on a real new UI feature. Verify `/design build` → state.json::figma_node_ids capture → scaffold auto-runs → mapping files appear → CI publish fires → mappings show in Figma Dev Mode. Documents rough edges. (~0.25d, blocked on T2+T3+T4)

## Sequencing

T1 is the foundation — T2/T3/T4 all depend on it. T5 is the integration test, depends on the other layers. Open as separate PRs:

- **PR 1:** T1 + T2 (scaffold scripts in both repos + docs)
- **PR 2:** T3 (skill extension in FT2)
- **PR 3a:** T4 in FT2 (CI workflow + GitHub secret setup instructions for operator)
- **PR 3b:** T4 in fitme-story (parallel CI workflow)
- **PR 4:** T5 reconciliation after first end-to-end test

## Success metric

`manual_steps_per_new_ui_feature: 2 → 0`. Today operator hand-authors mapping files + manually runs publish; after Layer C operator does nothing.
