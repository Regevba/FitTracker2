# Screen Review Standard

Date: 2026-03-29
Branch baseline: `codex/ui-integration`

## Purpose

This document standardizes the review, implementation, reverse-sync, sanity, and QA workflow for every FitTracker screen.

The goal is simple: every screen should go through the same level of scrutiny and leave behind the same artifacts in code, Figma, and documentation.

## Required workflow for every screen

1. Compare the current integrated code, relevant screen history, and target UI direction before touching design or code.
2. Update or verify the editable Figma live asset in the matching product-area page.
3. Implement or adjust code only after the intended visual direction is explicit.
4. Verify on simulator in compact, baseline, and large iPhone widths.
5. Sync any runtime divergence back into the Figma live asset board.
6. Record the result in repo docs and lock the screen only when runtime and Figma match.

## Unified simulator review mode

To standardize integrated runtime review on simulator, the app now supports a lightweight review mode through launch environment values:

- `FITTRACKER_REVIEW_AUTH=authenticated`
  - bypasses the auth gate with a mock review session
- `FITTRACKER_REVIEW_AUTH=settings`
  - routes the app into the grouped Settings review baseline using the same review boot path
- `FITTRACKER_REVIEW_TAB=home`
- `FITTRACKER_REVIEW_TAB=training`
- `FITTRACKER_REVIEW_TAB=nutrition`
- `FITTRACKER_REVIEW_TAB=stats`

Use this only for design and QA review on simulator. It is intended to make the integrated runtime pass repeatable without changing the approved product flow for normal users.

## Required Figma structure for every approved screen page

Each approved product-area page should contain:

- a context/product brief area
- a source-of-truth board
- an approval-notes board
- an integrated runtime board
- an editable integrated live asset frame inside that board
- a standardized QA card on the integrated runtime board

## Required QA standard for every approved screen

Each screen must be checked for:

- visual consistency with the unified app shell
- compact iPhone behavior
- iPhone 14 Pro baseline behavior
- large iPhone behavior
- no clipped copy
- no broken tap targets
- no shell-level drift from approved navigation, background, spacing, or card treatment
- matching Figma live asset state

## Sanity rules

- If a screen is approved in code but not editable in Figma, the phase is not complete.
- If a Figma board looks correct but the integrated runtime differs, the phase is not complete.
- If the screen only works at one iPhone width, the phase is not complete.
- If the screen uses ad hoc spacing or element sizing outside the approved runtime spec, it is not ready for sign-off.

## Current standard for approved screens

The integrated runtime boards currently used as live editable assets are:

- `Integrated Runtime / Login / Mar 29`
- `Integrated Runtime / Home / Mar 29`
- `Integrated Runtime / Training / Mar 29`
- `Integrated Runtime / Nutrition / Mar 29`
- `Integrated Runtime / Stats / Mar 29`
- `Integrated Runtime / Settings / Mar 29`

## What still determines completion of this phase

This standard is in place, but the integration phase is only fully closed when:

1. the unified simulator pass is completed from `codex/ui-integration`
2. all approved screens are verified together in one runtime
3. any shell-level drift is fixed in code
4. any runtime drift is reflected back into the corresponding Figma live asset board
