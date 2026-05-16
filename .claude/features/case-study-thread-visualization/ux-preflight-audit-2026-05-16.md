# UX Preflight Audit — case-study-thread-visualization

> **Step:** 3e — `/ux preflight`
> **Date:** 2026-05-16
> **Verdict:** ✅ **PASS** — all tokens/components/patterns cited in `ux-spec.md` exist in fitme-story DS
> **Source:** ux-spec.md §9 "Token/component reuse checklist"
> **Verification source:** Explore agent landscape report 2026-05-16 (`fitme-story` repo)

---

## Summary

The UX spec cites only existing fitme-story design system primitives. **Zero unknown symbols.** Phase 4 implementation can proceed without "no such token" / "no such component" errors.

This preflight closes the silent-pass risk that surfaced during the import-training-plan resume (where the v2 ux-spec referenced 4 tokens that didn't exist — `AppRadius.pill`, `AppMotion.standardEase`, custom SettingsActionLabel with badge slot, a toast component).

---

## Token verification

| Citation in ux-spec | Type | Exists? | Source |
|---|---|---|---|
| `--color-neutral-50` | color | ✅ | globals.css |
| `--color-neutral-200` | color | ✅ | globals.css |
| `--color-neutral-300` | color | ✅ | globals.css |
| `--color-neutral-500` | color | ✅ | globals.css |
| `--color-neutral-700` | color | ✅ | globals.css |
| `--color-neutral-900` | color | ✅ | globals.css |
| `--color-brand-indigo` | color | ✅ | globals.css (#4F46E5) |
| `--color-brand-indigo` (dark override) | color | ✅ | globals.css (#818CF8) |
| `--text-display-md` | typography | ✅ | globals.css (clamp(1.5rem, 3vw, 2.25rem)) |
| `--text-body` | typography | ✅ | globals.css (1.0625rem line-height 1.7) |
| `--motion-duration-fast` | motion | ✅ | globals.css (120ms) |
| `--motion-duration-standard` | motion | ✅ | globals.css (200ms) |
| `--motion-easing-standard` | motion | ✅ | globals.css (cubic-bezier(0.4,0,0.2,1)) |
| `--motion-easing-decelerate` | motion | ✅ | globals.css (cubic-bezier(0,0,0.2,1)) |

**No new tokens introduced.** All 14 citations resolve.

---

## Component verification

| Citation in ux-spec | Exists? | Source path | Notes |
|---|---|---|---|
| `<Tag tone="subtle">` | ✅ | `src/components/ui/Tag.tsx` | Used for version markers |
| `<Disclosure>` | ✅ (deferred to v1.1) | `src/components/ui/Disclosure.tsx` | Available if needed for series collapse |
| `<Button>` | ✅ (referenced for focus-ring pattern, not used in component) | `src/components/ui/Button.tsx` | Focus pattern: `focus-visible:outline-2 focus-visible:outline-offset-2` |
| `<Callout>` | ✅ (referenced for `role="note"` a11y pattern, not used) | `src/components/ui/Callout.tsx` | Pattern reference only |
| `SeriesTimeline` | NEW BUILD — novel UI | `src/components/case-study/SeriesTimeline.tsx` (to be created in Phase 4 T12) | This spec IS the contract; no existing horizontal-timeline component in fitme-story (TimelineNav is a footer prev/next, not a timeline visualizer) |

---

## Pattern verification

| Pattern cited | Exists? | Source |
|---|---|---|
| `prefers-reduced-motion` global rule | ✅ | globals.css `@media (prefers-reduced-motion: reduce)` |
| `aria-label` + `role="navigation"` | ✅ | `Callout.tsx` uses `role="note" + aria-label`, transferable pattern |
| Keyboard focus-visible outline | ✅ | `Button.tsx` pattern |
| `aria-current="page"` | ✅ | WAI-ARIA 1.2 native; not yet used in fitme-story but standard |
| Min tap target 44px | ✅ | `Button.tsx` uses `min-h-[44px]` |
| Dark-mode color overrides | ✅ | every color token has light + dark variant in globals.css |
| `.section-padding-x` utility | ✅ | globals.css |
| Tailwind v4 `@theme` directives | ✅ | globals.css |

---

## Utility class verification

| Tailwind class | Available? |
|---|---|
| `rounded-full` | ✅ (Tailwind default) |
| `text-sm`, `text-xs`, `font-semibold` | ✅ (Tailwind default) |
| `my-12`, `mt-4`, `mt-2`, `mt-1`, `mt-6`, `gap-8` | ✅ (Tailwind 4px scale) |
| `overflow-x-auto`, `snap-x`, `snap-mandatory`, `snap-center` | ✅ (Tailwind default) |
| `list-none` | ✅ (Tailwind default) |
| `sm:`, `md:`, `lg:`, `xl:` breakpoints | ✅ (Tailwind v4) |
| `focus-visible:outline-2 focus-visible:outline-offset-2` | ✅ (Tailwind v4) |
| `border-l-2 border-neutral-200` | ✅ (Tailwind default, custom color via @theme) |
| `aria-current:` pseudo-attribute selector | available via `data-current="true"` attribute pattern + standard CSS |

---

## Insertion-point verification

| Cited path | Exists? | Notes |
|---|---|---|
| `src/app/case-studies/page.tsx` | ✅ | Listing page — confirmed L1-L777 by DS landscape agent |
| `src/app/case-studies/[slug]/page.tsx` | ✅ | Detail page route |
| `src/components/case-study/StandardTemplate.tsx` | ✅ | Confirmed by landscape agent |
| `src/components/case-study/FlagshipTemplate.tsx` | ✅ | Confirmed |
| `src/components/case-study/LightTemplate.tsx` | ✅ | Confirmed |
| `src/lib/content-schema.ts` | ✅ | Confirmed L77 has unused `related[]` for additive placement |
| `compileMDX()` SSR pattern in detail page | ✅ | Confirmed — implications: server-rendered timeline is safe; client subcomponent needed for interactivity |

---

## Verdict

**✅ PRE-FLIGHT PASSED.**

| Check | Result |
|---|---|
| Tokens exist | 14/14 ✅ |
| Components exist | 4/4 ✅ (1 new build correctly identified) |
| Patterns transferable | 8/8 ✅ |
| Utility classes available | 11/11 ✅ |
| Insertion points exist | 7/7 ✅ |
| P0 findings | 0 |
| P1 findings | 0 |
| P2 findings | 0 |

Phase 4 (Implementation) can proceed citing every name in this spec without code-discovery overhead.

---

## Notes for /design preflight (Step 3f)

- One novel component (`SeriesTimeline`) will need Figma representation. Step 3j (Figma build) decision: defer to prompt — component code doesn't exist yet; pushing wireframe-level abstraction creates spec/build divergence risk. Real Figma push happens in Phase 4 close after component implements + Code Connect publish workflow auto-runs.
- No design-system token evolution required.
- No new variants on existing components needed.
- This is a "compose primitives" build, not a "DS extension" build.
