# Design Build Prompt — `ucc-passkey-auth` — 2026-05-07

**Phase 3 sub-step 3i + 3j (portable fallback)** · auto-generated handoff prompt for Figma rebuild
**Companion prompt:** [`docs/prompts/ux/2026-05-07-ucc-passkey-auth-ux-build.md`](../ux/2026-05-07-ucc-passkey-auth-ux-build.md)
**Status:** **Portable** — `state.json.figma_build_status = "deferred_to_prompt"` because the fitme-story dashboard has no current Figma-file mapping (built code-first during the UCC Astro→Next.js migration). This prompt is the artifact that lets a future operator reconstruct Figma fidelity for the dashboard at any time.

> Hand this prompt to a designer (human or agent) who will build Figma frames for the 5 screens declared in `ux-spec.md`. The visual language matches the existing fitme-story `/control-room` Editorial design — Tailwind v4 + Tailwind defaults + the FitMe brand palette in `globals.css`.

---

## Visual language

- **Type:** `--font-sans` (Inter via next/font) for body, `--font-serif` (a serif we use editorially) for display headings
- **Type scale:** body `1.0625rem` (17px) at line-height `1.7`; display-md `clamp(1.5rem, 3vw, 2.25rem)`
- **Brand palette:**
  - Indigo `#4F46E5` (primary CTA, focus rings, links)
  - Indigo-hover `#4338CA`
  - Coral `#F97066` (success/celebration accent — not used in this feature, reserved)
- **Editorial neutrals (warm grays):**
  - `--color-neutral-50` `#FAFAF9` (light bg)
  - `--color-neutral-100` `#F5F5F4`
  - `--color-neutral-500` `#78716C` (muted text light) → `#A8A29E` dark
  - `--color-neutral-700` `#44403C` (body text light) → `#D6D3D1` dark
  - `--color-neutral-900` `#1C1917` (dark bg)
- **States:**
  - Error: `rose-500` (#F43F5E) bg, white text
  - Success: `emerald-500` (#10B981) accent
  - Locked: `slate-500` (#64748B) muted
- **Measures:** `--measure-narrow` 58ch (sign-in card width), `--measure-wide` 72ch (admin tables)
- **Radii:**
  - Panel chrome: 28px (matches `<Panel>` primitive)
  - Buttons: 12px
  - Pills (revoke confirm, status badges): full-rounded (`rounded-full`)
- **Shadows:**
  - Light Panel: `0 18px 50px rgba(15,23,42,0.08)`
  - Dark Panel: none (just border `border-white/8`)
  - Cards on framework-health page: same Panel shadow

## Component inventory

| Existing primitive (reuse) | Source |
|---|---|
| `<Panel>` (28px radius, eyebrow + title + description + children) | `primitives.tsx` |
| `<MetricList>` (3-stat row inside dark Panel) | `primitives.tsx` |
| `<AlertsBanner>` (suspicious-event banner) | `AlertsBanner.tsx` |

| New (must be designed) | Used by |
|---|---|
| `<AuthPasskeyForm>` | Sign-in + Recover |
| `<DevicesTable>` | Devices admin |
| `<AuditEventRow>` | Audit log |
| `<AuditLogPanel>` | framework-health embed |

## Screen-by-screen specs

### 1. Sign-in (`/control-room/sign-in`)

**Container:** centered `<Panel>`, max-width `--measure-narrow` (58ch), vertical-centered in viewport (min-height 80vh).

**Hero:** brand mark (96px tall, orange Fit:Me logo SVG, centered).

**Title:** "FitMe Control Room" (display-md, font-serif).

**Subtitle:** "Sign in to continue" (text-body, neutral-500).

**Input:** full-width visible input, `autocomplete="username webauthn"` (browser shows the autofill prompt on focus; we do NOT type into it normally).
- Border: `border-neutral-300` light / `border-white/15` dark
- Focus: `ring-2 ring-brand-indigo ring-offset-2`
- Padding: 12px vertical, 16px horizontal
- Radius: 12px

**Primary button:** "Unlock with passkey"
- Background: `--color-brand-indigo`, hover: `--color-brand-indigo-hover`
- Text: white, font-semibold, text-sm
- Padding: 12px vertical, 24px horizontal
- Radius: 12px
- Height: 48px (44pt+ tap target)
- Width: full-width within the panel
- Optional 800 ms-after-load `pulse` animation (suppressed under reduce-motion)

**Lost device link:** below the panel, small text-link, indigo color, underline-on-hover.

**Footer:** dark-mode toggle (existing `<ThemeToggle>` primitive), centered, smaller variant.

**5 states (visual treatment):**

- **Idle:** as above
- **Pending:** button label changes to "Waiting for passkey..." with a 16px spinner (rotating, suppressed under reduce-motion); button background dims to `bg-brand-indigo/60`; button disabled
- **Success:** button background flashes emerald-500 for 250ms with a checkmark icon; then page fades to white and redirects
- **Error:** banner appears above the button (rose-500 bg, white text, 12px padding, 8px radius, AlertTriangle icon) — examples: "Touch ID cancelled", "No passkey found on this device", "Account temporarily locked"; retry button below the banner
- **Locked:** banner replaces the entire card (slate-500 bg, white text), shows "Locked until {time}"; no retry button

### 2. Recover (`/control-room/sign-in/recover`)

**Path A (token via URL):** Same Panel chrome as Sign-in. Title "Add this device". Subtitle "Tap below to register {ua_family} as your passkey". Single primary button "Register this device". Cancel link below.

**Path B (no token, manual paste):** Same Panel chrome. Title "Recover access". Subtitle text + code block (`bg-neutral-100` light / `bg-white/8` dark, monospace, 8px padding, 6px radius) showing the CLI command. Token-paste textarea (3 rows, monospace). "Continue" primary button. "← Back to sign-in" secondary link.

### 3. Devices admin (`/control-room/settings/devices`)

**Container:** `<Panel>` with eyebrow "Operator dashboard / Settings", title "Devices", description "Registered passkeys for this dashboard".

**Table:** standard 5-column layout
- Column headers (uppercase, tracking-wider, text-xs, neutral-500): Label · Type · Last used · IP · (action)
- Row: 14px padding vertical
- Type cell: pill (`rounded-full`, `bg-neutral-100` light / `bg-white/8` dark, `text-xs`, `font-semibold`); platform = "Platform", cross_platform = "Hardware key"
- Last used cell: relative time format ("2 min ago"); `text-neutral-500`
- IP cell: monospace, text-xs, neutral-500 (e.g. `203.0.113.0/24`)
- Action cell: right-aligned "Revoke" button (rose-500 bg, white text, small)

**Revoke confirm flow (inline pill):** Click Revoke → row's action cell transforms into an inline pill ("Revoke this credential? ✓ ✗"), rose-500 bg, white text, 8px radius. Click ✓ → row dims + spinner; on success → row strikethrough + greyed.

**Empty state:** centered text "No credentials registered yet" + code snippet for the bootstrap CLI.

**Below the table:** instruction line "To add another device, run: `pnpm tsx scripts/issue-bootstrap-token.ts`" (monospace, neutral-500).

### 4. Audit log (`/control-room/settings/audit`)

**Container:** `<Panel>` with eyebrow "Operator dashboard / Settings", title "Audit log", description "Last 50 auth events on this dashboard".

**Filter chips:** horizontal row at top, 5 chips ([All] [Authenticate] [Register] [Revoke] [Session]).
- Chip: `rounded-full`, `bg-neutral-100` light / `bg-white/8` dark, `text-xs`, `font-semibold`, 8px vertical / 12px horizontal padding
- Selected: `bg-brand-indigo` + white text (replaces neutral)

**Event row:**
- 4 columns: timestamp · event_type · operator_label · outcome
- Timestamp cell: `font-mono`, `text-xs`, `text-neutral-500`
- Event type cell: badge (rounded, color varies by type — see palette below)
- Operator cell: `text-sm`, `text-neutral-700`
- Outcome cell: pill (✓ in `emerald-500` for success, ✗ in `rose-500` for failed, neutral for other)
- Hover: row gets `bg-neutral-50` light / `bg-white/4` dark
- Click: row expands inline (smooth height transition, suppressed under reduce-motion); shows credential_id_hash, ip_class, ua_family, duration_ms, reason in a 2-column key-value list

**Event-type palette:**
- `*_succeeded` / `_minted`: emerald-500
- `*_failed`: rose-500
- `*_started`: indigo-500 (informational)
- `_revoked`: amber-500
- `_expired`: slate-500

### 5. AuditLogPanel (embedded in `/control-room/framework`)

**Container:** `<Panel>` (matches the other framework-health page panels), eyebrow "Auth surface", title "Operator dashboard authentication telemetry".

**3-stat row:** Reuses `<MetricList>` primitive in horizontal-flex mode. Each stat: large number on top, label below, optional red color when "Failed (7d)" > 0.

**Suspicious banner:** Reuses `<AlertsBanner>` (rose-500/15 bg, rose-700 text light / rose-300 text dark). Renders only when anomaly conditions trigger. Dismissible via local state.

**Recent events:** 5-row condensed table (same shape as full audit log but only 5 rows, no filter chips, no expansion).

**Footer link:** "View full audit log →" (small, indigo, right-aligned).

## Visual examples to reference

- **Existing `<Panel>` chrome on framework-health page:** [fitme-story.vercel.app/control-room/framework](https://fitme-story.vercel.app/control-room/framework) — match this exactly for the new screens
- **iOS BiometricActivationSheet:** `FitTracker/Views/Auth/BiometricActivationSheet.swift` — port the cadence (brand icon, single CTA, Not now secondary, inline banner) to web
- **iOS ReadinessAlert (for inline banner pattern):** `FitTracker/Views/Auth/AuthBannerView.swift` — same color treatment

## Light + dark mode

Every artifact MUST be designed for both modes. Use the existing fitme-story `globals.css` dark overrides:

- `.dark` body bg: `--color-neutral-900` (#1C1917)
- `.dark` body text: `--color-neutral-100` (#F5F5F4)
- `.dark` `--color-neutral-500`: `#A8A29E` (raises AA contrast)
- `.dark` `--color-brand-indigo`: `#818CF8` (same)

## Spacing scale

Tailwind defaults (4px base): use `space-y-3` (12px), `space-y-4` (16px), `space-y-6` (24px), `space-y-8` (32px). Page-level vertical rhythm uses `space-y-6` between Panels.

## Out of scope

- Marketing-style hero illustrations (this is operator surface, no brand storytelling)
- Custom icon set (use `lucide-react` for icon needs — already a dependency)
- Custom animations beyond the 250 ms success checkmark (reduce-motion-safe via globals.css)

## Optional: Figma file rebuild

If a designer wants to recreate these screens in Figma:

1. Create a new Figma file under team `Regev - My apps` (`team::726401375318003097`)
2. Import the FitMe brand mark + the brand palette swatches (colors above)
3. Build the 5 screens as separate frames at 1440 × 1024 desktop viewport
4. Tag each frame with its file-path-of-origin in the Description (e.g. "Sign-in — `src/app/control-room/sign-in/page.tsx`")
5. Update `state.json.figma_node_ids` with the resulting node IDs
6. Update `state.json.figma_build_status` from `"deferred_to_prompt"` to `"completed"`
7. Add a row to `docs/design-system/figma-code-sync-status.md`

---

**Acceptance criteria (Phase 6 `/design pre-merge-review` will gate):**

- [ ] All 5 screens render with the visual language above
- [ ] Dark mode coverage on all 5 screens
- [ ] All states (idle / pending / success / error / locked) visible per screen
- [ ] No raw color literals in code — every value maps to a Tailwind token or `globals.css` variable
- [ ] No P0 in `make ui-audit` (this is FT2-side; fitme-story has its own ESLint/Tailwind audit)
- [ ] AA contrast verified for all text on all backgrounds
