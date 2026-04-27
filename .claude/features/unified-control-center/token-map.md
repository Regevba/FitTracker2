# Token Map — Astro dashboard → fitme-story

> **Task T15** of the unified-control-center migration (PRD §6 + Block D).
> Maps every color/typography/radius/shadow token from
> `dashboard/tailwind.config.mjs` to its fitme-story equivalent in
> `src/app/globals.css @theme`. Used by T16 (WCAG axe audit) and T17
> (resolve contrast failures), then drives T18+ component port.

## Mapping principle

The dashboard is being absorbed into the fitme-story showcase as the
operator's private `/control-room/*` route. **Visual identity converges
to fitme-story's palette** — the dashboard adopts indigo + coral + warm
neutrals, dropping the legacy orange/blue/cool-gray scheme. This is a
deliberate re-skin, not a 1:1 color preservation.

Three mapping flavors:

- **Direct match** — semantic and hex are close enough; use the fitme-story token.
- **Re-skin** — semantic stays, hex changes (the dashboard adopts fitme-story's identity).
- **Scoped addition** — no clean equivalent in fitme-story; add a `--cr-*` (control-room-scoped) token in the dashboard's own CSS, declared inside `[data-cr-root]` so it doesn't leak into the showcase.

## Brand colors

| Dashboard token | Hex | → fitme-story token | Hex | Mapping kind | Notes |
|---|---|---|---|---|---|
| `brand.primary` | `#FA8F40` (orange) | `--color-brand-coral` | `#F97066` (light) / `#FDA29B` (dark) | Re-skin | Coral is fitme-story's accent; closest to "warm primary" semantic. |
| `brand.secondary` | `#8AC7FF` (light blue) | `--color-brand-indigo` | `#4F46E5` (light) / `#818CF8` (dark) | Re-skin | fitme-story's primary brand; serves "structural accent" role. |
| `brand.warm` | `#FFC78A` | drop → `--color-neutral-200` | `#E7E5E4` | Re-skin | Decorative; not load-bearing in dashboard usage. |
| `brand.cool` | `#DFF3FF` | drop → `--color-neutral-100` | `#F5F5F4` | Re-skin | Decorative; subtle background tint. |

## Surface colors

fitme-story uses warm-gray (stone family) neutrals; the dashboard uses
cool-gray (slate family). After migration, surfaces will look slightly
warmer. Acceptable per the re-skin direction.

| Dashboard token | Hex | → fitme-story token | Hex | Notes |
|---|---|---|---|---|
| `surface.primary` (light) | `#FFFFFF` | `#FFFFFF` (raw) | `#FFFFFF` | No fitme-story token for pure white; use raw value. |
| `surface.primary` (dark) | `#0F1419` | `--color-neutral-900` | `#1C1917` | Close; warmer dark. |
| `surface.secondary` (light) | `#F8F9FA` | `--color-neutral-50` | `#FAFAF9` | Direct match. |
| `surface.secondary` (dark) | `#1A1F2E` | `--color-neutral-800` | `#292524` | Close; warmer mid-dark. |
| `surface.tertiary` (light) | `#F1F3F5` | `--color-neutral-100` | `#F5F5F4` | Direct match. |
| `surface.tertiary` (dark) | `#242938` | between `--color-neutral-700` and `--color-neutral-800` | `#44403C`–`#292524` | T16 may flag; if so, add scoped `--cr-surface-tertiary-dark`. |

## Status colors (PM phase semantic)

The dashboard's status palette divides phases into 4 visual buckets:
gray (not started), blue (in motion), purple (validating), green (done).
fitme-story's skill palette aligns surprisingly well — same buckets,
slightly different hues.

| Dashboard token (phases covered) | Hex | → fitme-story token | Hex | Notes |
|---|---|---|---|---|
| `status.backlog`, `status.research`, `status.prd` | `#9CA3AF` (gray) | `--color-neutral-500` | `#78716C` (light) / `#A8A29E` (dark) | "Not started" semantic; warm gray replaces cool gray. |
| `status.ux`, `status.integration`, `status.implement` | `#3B82F6` (blue) | `--skill-dev` | `#0EA5E9` (sky) | Both blue; "in motion" semantic preserved. |
| `status.testing`, `status.review`, `status.merge` | `#A855F7` (purple) | `--skill-ux` | `#D946EF` (fuchsia) | Both magenta-purple; "validating" semantic preserved. |
| `status.docs`, `status.done` | `#10B981` (green) | `--skill-release` | `#10B981` (emerald) | **Exact hex match.** Done = green = release. |

## Priority colors

fitme-story does not have a dedicated priority palette. The skill
palette covers most priorities by semantic accident. Where it doesn't,
a `--cr-priority-*` scoped token fills the gap.

| Dashboard token | Hex | → fitme-story token | Hex | Notes |
|---|---|---|---|---|
| `priority.critical` | `#DC2626` (red) | `--skill-cx` | `#F43F5E` (rose) | Slight hue shift (red → rose); both signal urgency. |
| `priority.high` | `#F59E0B` (amber) | `--skill-research` | `#F59E0B` (amber) | **Exact hex match.** |
| `priority.medium` | `#FBBF24` (light amber) | scoped `--cr-priority-medium` | `#FBBF24` | No fitme-story equivalent; preserve. Warmer amber than `--skill-research`. |
| `priority.low` | `#D1D5DB` (light gray) | `--color-neutral-300` | `#D6D3D1` | Direct match. |

## Typography

| Dashboard token | Value | → fitme-story token | Value | Notes |
|---|---|---|---|---|
| `fontFamily.sans` | `'Inter', system-ui, ...` | `--font-sans` | `var(--font-sans), ui-sans-serif, system-ui, sans-serif` | Inter loaded via next/font in fitme-story; same family, better loading. |
| `fontFamily.mono` | `'SF Mono', Menlo, monospace` | (none) | — | Add scoped `--cr-font-mono` for code blocks in feature cards. |

## Border radius

fitme-story uses Tailwind's default radii (`rounded-md`, `rounded-lg`, etc.).
The dashboard's named radii don't have semantic-token equivalents.

| Dashboard token | Value | → fitme-story | Notes |
|---|---|---|---|
| `borderRadius.card` | `12px` | scoped `--cr-radius-card: 12px` | Used by Panel/MetricCard primitives. |
| `borderRadius.badge` | `6px` | scoped `--cr-radius-badge: 6px` | Used by status pills + priority chips. |

## Box shadows

Same story as radii — no fitme-story semantic tokens; scoped to control-room.

| Dashboard token | Value | → fitme-story | Notes |
|---|---|---|---|
| `boxShadow.card` | `0 4px 10px rgba(0, 0, 0, 0.08)` | scoped `--cr-shadow-card` | Resting state. |
| `boxShadow.card-hover` | `0 8px 20px rgba(0, 0, 0, 0.12)` | scoped `--cr-shadow-card-hover` | Hover state. |
| `boxShadow.card-drag` | `0 12px 28px rgba(0, 0, 0, 0.18)` | scoped `--cr-shadow-card-drag` | KanbanBoard drag state. |

## Scoped tokens (added in dashboard CSS only)

The control-room route declares these in a `[data-cr-root]` selector at
the top of `src/app/control-room/layout.tsx`'s CSS, so they're invisible
to the showcase. Pattern keeps fitme-story's `@theme` block clean and
preserves the dashboard's specific UX details that don't generalize.

The `*-on-light` text-grade variants (added per T17 contrast audit
resolutions) exist because the shared `--skill-*` tokens are -500
saturation chosen for the orbital diagram FILL use case. When a chip
uses the skill color as TEXT on a light background (no fill), the -500
shade fails AA-large 3:1. The -700 / -800 variants below pass AA or
AAA. Background-fill chip use (skill color background + white text)
keeps using the shared `--skill-*` tokens unchanged.

```css
[data-cr-root] {
  /* Decorative + structural */
  --cr-priority-medium: #FBBF24;          /* chip BACKGROUND fill only */
  --cr-font-mono: 'SF Mono', Menlo, monospace;
  --cr-radius-card: 12px;
  --cr-radius-badge: 6px;
  --cr-shadow-card: 0 4px 10px rgba(0, 0, 0, 0.08);
  --cr-shadow-card-hover: 0 8px 20px rgba(0, 0, 0, 0.12);
  --cr-shadow-card-drag: 0 12px 28px rgba(0, 0, 0, 0.18);

  /* Text-grade variants (T17 resolutions for Pattern A failures).
     Use these when a status/priority value renders as TEXT or ICON
     on a light background, NOT as a filled chip. Dark mode keeps the
     shared --skill-* tokens — they pass on dark surfaces. */
  --cr-status-implementing-text-light: #0369A1; /* sky-700  (was --skill-dev #0EA5E9) */
  --cr-status-done-text-light:         #047857; /* emerald-700 (was --skill-release #10B981) */
  --cr-priority-high-text-light:       #B45309; /* amber-700 (was --skill-research #F59E0B) */
  --cr-priority-medium-text-light:     #92400E; /* amber-800 (was --cr-priority-medium #FBBF24) */
}
```

### Usage constraints (T17 resolution Pattern B)

- **`--color-brand-coral` is reserved for buttons, headlines, and
  decorative graphics — NEVER body or paragraph text.** Coral has a
  2.67:1 ratio against `--color-neutral-50`, well below AA's 4.5:1 for
  text. Use `--color-brand-indigo` for inline links and text accents
  in the control-room. (For coral-on-coral white text, use `bg-brand-coral text-white` — that pair passes.)

- **`--color-neutral-500` for muted text:** the showcase's existing
  pair `--color-neutral-500` on `--color-neutral-100` misses AA by
  0.10 (4.40:1 vs 4.50:1). For the control-room, prefer
  `--color-neutral-700` (~10:1) for muted secondary text. The
  showcase-wide bump is tracked separately and out of scope here.

## Open questions for T16 (WCAG audit)

The following pairs are flagged for explicit contrast verification because
the hex shift is meaningful (warm vs cool gray, red vs rose, etc.):

1. `--skill-cx` (#F43F5E rose) on `--color-neutral-50` (#FAFAF9 warm white) — verify ≥4.5:1 for body text containing `priority.critical` chips.
2. `--skill-cx` (#F43F5E) on `--color-neutral-900` (#1C1917 warm black) — same check, dark mode.
3. `--skill-dev` (#0EA5E9 sky) on `--color-neutral-50` — body text. Sky is a thin color; previous dashboard blue (#3B82F6) was darker.
4. `--skill-dev` (#0EA5E9) in dark mode — `#0EA5E9` may need lift for AA.
5. `--cr-priority-medium` (#FBBF24) on white — previously failing in source; verify after re-skin.
6. `--color-neutral-500` (#78716C) on `--color-neutral-100` (#F5F5F4) for muted text — already AA in fitme-story showcase, but verify in dashboard's denser layouts.

If any pair fails, T17 resolves by either picking a darker shade in the
fitme-story palette OR defining a one-off `--cr-*` override scoped to
`[data-cr-root]`. Per PRD §6, no fitme-story token is modified for
dashboard needs alone — that would risk affecting the public showcase.

## Migration checklist for T18+ component port

When porting each dashboard component (T18–T30), apply this token map:

1. Replace every `bg-brand-primary` / `text-brand-primary` etc. → `bg-brand-coral` / `text-brand-coral`.
2. Replace `text-status-{phase}` → `text-skill-dev` / `text-skill-ux` / `text-skill-release` per the bucket mapping above.
3. Replace `text-priority-{level}` → `text-skill-cx` / `text-skill-research` / `text-cr-priority-medium` / `text-neutral-300`.
4. Replace surface utility classes per surface table.
5. For radii/shadows, use the scoped `--cr-*` CSS variables via `style={{ borderRadius: 'var(--cr-radius-card)' }}` or a Tailwind plugin if needed.
6. Wrap the dashboard's outermost JSX in `<div data-cr-root>` so the scoped tokens resolve.

## Provenance

- Source: `dashboard/tailwind.config.mjs` (5 token groups, 27 tokens)
- Target: `fitme-story/src/app/globals.css @theme` block
- Authored: 2026-04-27 by claude_opus_4_7 during Phase 4 implementation
- Next: T16 runs axe-core against this map; T17 resolves any AA failures.
