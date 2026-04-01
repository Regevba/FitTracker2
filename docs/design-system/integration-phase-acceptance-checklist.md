# Integration Phase Acceptance Checklist

Date: 2026-03-29
Branch: `codex/ui-integration`

## Goal

This checklist defines what must be true before the integrated Apple-first UI phase is considered complete, locked, and approved.

## Required code state

- [ ] Unified branch builds successfully from `codex/ui-integration`
- [ ] Approved screens are present together in one runtime:
  - [ ] Auth
  - [ ] Home
  - [ ] Training
  - [ ] Nutrition
  - [ ] Stats
  - [ ] Settings
- [ ] Shared shell is visually consistent:
  - [ ] tab bar treatment
  - [ ] toolbar/menu treatment
  - [ ] background mood
  - [ ] card contrast
  - [ ] typography hierarchy
- [ ] No screen-specific branch contains approved UI not yet merged into the integrated branch

## Required Figma state

- [ ] Each approved screen page contains an integrated runtime board
- [ ] Each integrated runtime board contains a real editable screen frame, not a flat screenshot
- [ ] Approved screen pages include:
  - [ ] `Integrated Runtime / Login / Mar 29`
  - [ ] `Integrated Runtime / Home / Mar 29`
  - [ ] `Integrated Runtime / Training / Mar 29`
  - [ ] `Integrated Runtime / Nutrition / Mar 29`
  - [ ] `Integrated Runtime / Stats / Mar 29`
  - [ ] `Integrated Runtime / Settings / Mar 29`
- [ ] Platform spec boards exist in Figma:
  - [ ] `iPhone Runtime Layout Spec`
  - [ ] `Element Size + Icon Spec`

## Required responsive review

- [ ] Compact iPhone width reviewed
- [ ] iPhone 14 Pro baseline reviewed
- [ ] Large iPhone width reviewed
- [ ] No clipped titles, controls, helper text, or bottom-shell elements
- [ ] Primary tap targets remain at or above minimum usable size

## Required reverse-sync proof

- [ ] Figma board matches approved integrated runtime for each screen
- [ ] Any runtime divergence found during unified testing is reflected back into the matching Figma board
- [ ] Repo docs were updated after the Figma sync

## Remaining blockers before closing this phase

As of this checkpoint, the main remaining items are:

1. Run and capture a true unified simulator pass from `codex/ui-integration`
2. Compare integrated runtime against the Figma boards screen by screen
3. Refine any remaining shell-level inconsistencies
4. Re-lock the integrated app shell after those runtime checks pass

## Exit condition

Do not move to the next major phase until every box above is checked.
