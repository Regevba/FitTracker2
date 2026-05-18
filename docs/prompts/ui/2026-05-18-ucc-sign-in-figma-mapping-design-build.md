# UCC Sign-In Figma Build Prompt — 2026-05-18 discovery + variant-build spec

> **Generated:** 2026-05-18 (during v7.9 calibration freeze; Figma writes deferred to a future dedicated session)
> **Feature:** `ucc-sign-in-figma-mapping` (UU4 enhancement on `ucc-passkey-auth`)
> **Active feature:** YES (Mechanism C attribution: `.claude/active-feature = ucc-sign-in-figma-mapping`)
> **Target Figma file:** `fsjHfFLAHELACZHku8Rfcl` — "FitMe Story Web — Design System"
> **Source TSX:** [fitme-story `src/components/control-room/AuthPasskeyForm.tsx`](https://github.com/Regevba/fitme-story/blob/main/src/components/control-room/AuthPasskeyForm.tsx) + [`src/app/control-room/sign-in/SignInShell.tsx`](https://github.com/Regevba/fitme-story/blob/main/src/app/control-room/sign-in/SignInShell.tsx)
> **Existing Code Connect mappings:** `page.figma.tsx` → 31:3, `AuthPasskeyForm.figma.tsx` → 30:61 (already shipped)

## TL;DR

State.json reported tasks T2/T3/T4 as not-started. Live Figma inspection on 2026-05-18 revealed the **scaffolding is already in place** but the AuthPasskeyForm component-set's 10 variants are empty 360×10 stubs. The page frames render incorrectly only because they instance a collapsed component. This document captures the precise gap, the existing node-ID inventory, and the per-variant build spec so a future Figma session can complete the build in one focused pass.

## Existing scaffolding (node-ID inventory)

All node IDs verified live via `get_metadata` on 2026-05-18.

### T2 — `/control-room/sign-in` page frames (6 total)

Page: **Cover** (`1:3`). Group label: `Control-Room / sign-in — Page Frames (T2)` (text node 31:2 at y=8040).

| Variant | Node ID | Position | Size |
|---|---|---|---|
| Idle (Mobile) | `31:3` | x=0, y=8100 | 360×423 |
| Idle (Desktop) | `31:19` | x=400, y=8100 | 1280×423 |
| Pending (Mobile) | `31:35` | x=1720, y=8100 | 360×? |
| Pending (Desktop) | `31:51` | x=2120, y=8100 | 1280×? |
| Error (Mobile) | `31:67` | x=3440, y=8100 | 360×? |
| Error (Desktop) | `31:86` | x=3840, y=8100 | 1280×? |

Internal structure (verified on 31:3 Idle Mobile):
```
Frame "Sign-In · Idle (Mobile)" 360×423
├── Frame "Header" 360×56
│   └── Text "FitMe" (logo)
├── Frame "Main" 360×311
│   └── Frame "Card" 312×215 at (24, 48)
│       ├── Text "Sign in to control room"
│       ├── Text "Use your registered passkey to unlock the operator dashboard."
│       ├── Instance "AuthPasskeyForm" (height=10 — COLLAPSED, root cause of all rendering issues)
│       └── Text "Don't have a passkey? Recover with bootstrap token →"
└── Frame "Footer" 360×56
    └── Text "© 2026 FitMe · Operator dashboard"
```

### T3 — `/control-room/sign-in/recover` page frames (6 total)

Group label: `Control-Room / sign-in / recover — Page Frames (T3)` (text node 31:105 at y=10140).

| Variant | Node ID | Position |
|---|---|---|
| Recover · Idle (Mobile) | `31:106` | x=0, y=10200 |
| Recover · Idle (Desktop) | `31:121` | x=400, y=10200 |
| Recover · Pending (Mobile) | `31:136` | x=1720, y=10200 |
| Recover · Pending (Desktop) | `31:151` | x=2120, y=10200 |
| Recover · Error (Mobile) | `31:166` | x=3440, y=10200 |
| Recover · Error (Desktop) | `31:184` | x=3840, y=10200 |

Internal structure assumed parallel to T2 (not yet verified by `get_metadata`).

### T4 — AuthPasskeyForm COMPONENT_SET (10 variants)

COMPONENT_SET node: `30:61` at (0, 6000). Group label: `Control-Room / Sign-In — AuthPasskeyForm (T4)` (text node 30:62 at y=5940).

| Variant name | Node ID | Position | Size | Status |
|---|---|---|---|---|
| `status=idle, mode=authenticate` | `30:2` | (0, 0) | 360×10 | **EMPTY STUB** |
| `status=idle, mode=register` | `30:8` | (420, 0) | 360×10 | EMPTY STUB |
| `status=pending, mode=authenticate` | `30:12` | (840, 0) | 360×10 | EMPTY STUB |
| `status=pending, mode=register` | `30:18` | (1260, 0) | 360×10 | EMPTY STUB |
| `status=success, mode=authenticate` | `30:22` | (1680, 0) | 360×10 | EMPTY STUB |
| `status=success, mode=register` | `30:28` | (2100, 0) | 360×10 | EMPTY STUB |
| `status=error, mode=authenticate` | `30:32` | (2520, 0) | 360×10 | EMPTY STUB |
| `status=error, mode=register` | `30:41` | (2940, 0) | 360×10 | EMPTY STUB |
| `status=locked, mode=authenticate` | `30:48` | (3360, 0) | 360×10 | EMPTY STUB |
| `status=locked, mode=register` | `30:54` | (3780, 0) | 360×10 | EMPTY STUB |

**Variant properties** (already declared on the COMPONENT_SET): `status` enum (5 values), `mode` enum (2 values). The Code Connect mapping at `src/components/control-room/AuthPasskeyForm.figma.tsx` already uses the `mode` enum.

## Per-variant build spec (source-truth match)

Source: [`AuthPasskeyForm.tsx`](https://github.com/Regevba/fitme-story/blob/main/src/components/control-room/AuthPasskeyForm.tsx). Build each variant to match what the React component would render in that `(status, mode)` combination.

### Common container

Auto-layout `space-y-3` (vertical stack, 12px gap), width 360px, hug-content height.

### Element 1 — Input field (only when `mode === 'authenticate'`)

```
<input type="text" name="username" autoComplete="username webauthn"
       placeholder="Operator email (autofill will use this)"
       aria-label="Sign in with passkey"
       className="w-full rounded-xl border border-neutral-300 bg-white
                  px-4 py-3 text-sm text-neutral-900
                  placeholder:text-neutral-400
                  focus-visible:ring-2 focus-visible:ring-brand-indigo
                  ..." />
```

Figma equivalent: 360px × 44px rectangle, `rounded-xl` (= 12px corner), 1px `--color-neutral-300` border, `--color-white` fill (or `--color-neutral-50`), inner text "Operator email (autofill will use this)" in `--color-neutral-400` italic-or-light at 14px. Padding 16px horizontal, 12px vertical.

Omit entirely for `mode === 'register'` (no email input — bootstrap token is passed via prop).

### Element 2 — Error alert (only when `status === 'error'`)

```
<div role="alert" className="flex items-start gap-3 rounded-xl
     border border-rose-300 bg-rose-50 p-3 text-sm text-rose-900 ...">
  <AlertTriangle className="mt-0.5 h-4 w-4" />
  <span>{ERROR_REASON[errorReason] ?? 'Something went wrong. Please try again.'}</span>
</div>
```

Figma equivalent: auto-layout horizontal, 360×~52px (hug-height), `rounded-xl`, 1px `--color-rose-300` border, `--color-rose-50` fill, 12px padding all sides, 12px gap. Children: 16×16 AlertTriangle icon, multi-line text in `--color-rose-900` at 14px.

Use placeholder error text: `"Authentication failed — try again."` (`assertion_invalid` from the ERROR_REASON map).

Omit entirely for non-error statuses.

### Element 3 — Primary button (always present)

Per-status content (logic from `AuthPasskeyForm.tsx` lines 247-262):

| Status | Mode | Icon | Label | Disabled | Background |
|---|---|---|---|---|---|
| idle | authenticate | Fingerprint (16×16) | "Unlock with passkey" | no | `--color-brand-indigo` |
| idle | register | Fingerprint (16×16) | "Register this device" | no | `--color-brand-indigo` |
| pending | authenticate | Fingerprint (16×16, animate-pulse) | "Waiting for passkey…" | **yes** | `--color-brand-indigo` at 60% opacity (`disabled:bg-brand-indigo/60`) |
| pending | register | Fingerprint (animate-pulse) | "Waiting for passkey…" | yes | same |
| success | authenticate | CheckCircle2 (16×16) | "Signed in" | **yes** | indigo at 60% opacity |
| success | register | CheckCircle2 | "Signed in" | yes | same |
| error | authenticate | Fingerprint | "Unlock with passkey" | no | `--color-brand-indigo` |
| error | register | Fingerprint | "Register this device" | no | `--color-brand-indigo` |
| locked | authenticate | Fingerprint | "Unlock with passkey" | **yes** | indigo at 60% opacity |
| locked | register | Fingerprint | "Register this device" | yes | same |

Common button styling:
- 360×48 (`h-12 w-full`)
- `rounded-xl` (12px corner)
- `font-semibold` text in white (14px)
- 24px horizontal padding (`px-6`)
- Horizontal auto-layout, 8px gap between icon and label, content centered
- **`coral-pulse-cta` animation** ONLY for `status=idle, mode=authenticate` — a pulsing coral-color ring around the button. In Figma, represent as an extra 4px outer stroke in `--color-brand-coral` at 30% opacity. (Static representation of the animation; documented in the spec, not visually animated.)

### Per-variant assembly summary

| Variant | Elements |
|---|---|
| `status=idle, mode=authenticate` | Input + Button (with coral-pulse-cta) |
| `status=idle, mode=register` | Button only (no input, no coral-pulse) |
| `status=pending, mode=authenticate` | Input + Disabled button "Waiting for passkey…" |
| `status=pending, mode=register` | Disabled button "Waiting for passkey…" |
| `status=success, mode=authenticate` | Input + Disabled button "Signed in" (CheckCircle2) |
| `status=success, mode=register` | Disabled button "Signed in" |
| `status=error, mode=authenticate` | Error alert + Input + Active button "Unlock with passkey" |
| `status=error, mode=register` | Error alert + Active button "Register this device" |
| `status=locked, mode=authenticate` | Input + Disabled button "Unlock with passkey" |
| `status=locked, mode=register` | Disabled button "Register this device" |

Component heights will vary roughly 48px (button-only) → 56+44 = 100px (button + input) → 100+52 = 152px (button + input + error alert).

## Token bindings to use

All names verified to exist in fitme-story `globals.css` (per CLAUDE.md design system). The Figma file should have matching variables in the Tokens collection (page `1:2`).

| CSS variable | Figma variable likely name |
|---|---|
| `--color-brand-indigo` | `Brand/Indigo/Base` |
| `--color-brand-coral` | `Brand/Coral/Base` |
| `--color-neutral-300` | `Neutral/300` |
| `--color-neutral-400` | `Neutral/400` |
| `--color-rose-300` | `Semantic/Rose/300` |
| `--color-rose-50` | `Semantic/Rose/50` |
| `--color-rose-900` | `Semantic/Rose/900` |
| `--color-white` | `Neutral/White` |

Run `search_design_system` to verify exact names before binding. Use scopes per [figma-use variable-patterns.md]: `["FRAME_FILL", "SHAPE_FILL"]` for fills, `["STROKE_COLOR"]` for borders, `["TEXT_FILL"]` for text colors.

## Build sequence for the future session

1. **`figma-use` skill load** (mandatory before `use_figma`)
2. **`search_design_system`** for the 8 token names above; capture their Figma variable IDs
3. **Build 1 reference variant** (`status=idle, mode=authenticate` = 30:2) end-to-end + screenshot validate
4. **Build remaining 9 variants** following the per-variant spec table
5. **Screenshot validate** the full COMPONENT_SET grid — verify each variant looks correct
6. **Verify page frames** (31:3 idle mobile + 1 sample of T3 recover) — the AuthPasskeyForm instances should now expand to fit the proper variant height; if page frames need height adjustment, fix in place
7. **Capture final node IDs** in `state.json::figma_node_ids` (T9 — but per [PR #400 grandfather decision](../case-studies/meta-analysis/kill-criteria-resolution-backfill-decision-2026-05-18.md), state.json writes are deferred until after 2026-05-21 v7.9 promotion)

## Why this is deferred from 2026-05-18

This session shipped 4 PRs (#400 grandfather essay, #401 risk closure, #402 cache_hits draft) and the goal was to keep the v7.9 calibration window clean. Two reasons to defer the Figma build:

1. **Substantial scope:** 10 component variants + visual validation is 1.5-2h of focused Figma work; mid-session interruption risks inconsistent state
2. **No calibration dependency:** UU4 is a UI mapping enhancement; building it has zero impact on the 2026-05-21 v7.9 promotion decision (cross-repo asymmetry: Mechanism A is FT2-only; fitme-story Figma writes don't affect FT2 telemetry)

The state.json write back (T9) is separately deferred to 2026-05-22+ per the [PR #402 calibration-window protection](../case-studies/meta-analysis/cache-hits-backfill-draft-2026-05-18.md) precedent.

## Cross-references

- Source TSX: [`AuthPasskeyForm.tsx`](https://github.com/Regevba/fitme-story/blob/main/src/components/control-room/AuthPasskeyForm.tsx) (lines 1-266)
- Existing Code Connect: [`AuthPasskeyForm.figma.tsx`](https://github.com/Regevba/fitme-story/blob/main/src/components/control-room/AuthPasskeyForm.figma.tsx) + [`page.figma.tsx`](https://github.com/Regevba/fitme-story/blob/main/src/app/control-room/sign-in/page.figma.tsx)
- Parent PRD: [`ucc-passkey-auth-case-study.md`](../case-studies/ucc-passkey-auth-case-study.md)
- Memory: [`project_ucc_passkey_cutover_2026_05_16.md`](file:///Users/regevbarak/.claude/projects/-Volumes-DevSSD-FitTracker2/memory/project_ucc_passkey_cutover_2026_05_16.md) (UU4 = "form-driven exception" enhancement)
- Calibration-protection precedent: [PR #400](https://github.com/Regevba/FitTracker2/pull/400), [PR #401](https://github.com/Regevba/FitTracker2/pull/401), [PR #402](https://github.com/Regevba/FitTracker2/pull/402)

## Decision record

| Date | Action | Author |
|---|---|---|
| 2026-05-18 | Discovery + variant-build spec authored; Figma writes deferred to a future dedicated session | Operator (Regev) + Claude Opus 4.7 |
| Future session | Build T4 (10 variants) → T2/T3 page frames auto-fix → screenshot validate → record node IDs in a draft doc | TBD |
| 2026-05-22+ | Mechanical state.json `figma_node_ids` write (T9) + case study §99 append (T11) post-v7.9 promotion | TBD |
