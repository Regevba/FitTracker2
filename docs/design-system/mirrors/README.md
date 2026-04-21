# UI-Audit Mirror Workflow

Before/after simulator screenshots captured during the UI-audit
baseline burndown (Phases 1–2 of the burndown plan). Mirrors live at
`.build/mirrors/` — gitignored — and are local verification artifacts
only.

## Naming

`<FileStem>-<before|after>-<light|dark>.png`

Examples:
- `OnboardingAuthView-before-light.png`
- `OnboardingAuthView-after-dark.png`

## Tooling

```bash
./scripts/ui-mirror.sh <label>
```

Wraps `xcrun simctl io booted screenshot` with `.build/mirrors/`
as the output directory. Boot the simulator and navigate to the
target screen before running.

For animations: capture a video instead:

```bash
xcrun simctl io booted recordVideo .build/mirrors/<label>.mov
# trigger the animation in the simulator
# Ctrl-C to stop
```

## Diff procedure

Preview.app supports side-by-side comparison: open both files, then
`Cmd+Option+Return` splits the window. Compare:

- Text contrast on colored backgrounds (inverse-token swaps should
  visually match `.white` on brand-orange; any shift is a regression).
- Dark mode — v2 screens must flip surfaces correctly. Both modes
  must be verified per file.
- Animation timing and feel — if the file touched an animation, play
  before/after videos side-by-side.

If any unintended change, STOP, revert the file, re-examine the
mapping. Do not commit until diffs are clean.

## Retention

Mirrors are retained for the duration of the burndown only. Once
`ui-audit` is promoted to a hard gate in `verify-local` (Phase 3.2),
clear `.build/mirrors/`. Long-term visual-regression safety is
handled by snapshot tests (deferred — see
`docs/design-system/figma-code-sync-status.md` Gap-C).

## Why manual instead of snapshot tests

Snapshot tests require a test target setup, a per-screen rendering
harness, and a commit-tolerable pixel-diff threshold. The cost/
benefit for this one-shot 27-finding burndown does not justify that
infrastructure today. Snapshot tests are the long-term answer and
are tracked as a separate item in the Figma-code sync status doc.
