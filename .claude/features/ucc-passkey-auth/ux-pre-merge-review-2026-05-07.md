# UX Pre-Merge Review — `ucc-passkey-auth` — 2026-05-07

**Phase 6 sub-step 6b** · heuristic re-check of shipped code vs approved [`ux-spec.md`](./ux-spec.md)

---

## Spec → code coverage matrix

| Screen | Spec section | Implementation file(s) | States covered | Notes |
|---|---|---|---|---|
| Sign-in | §4.1 | `src/app/control-room/sign-in/page.tsx` + `SignInShell.tsx` + `<AuthPasskeyForm mode="authenticate">` | Idle / Pending / Success / Error / Locked | conditional-UI autofill wired; visible button is manual fallback |
| Recover | §4.2 | `src/app/control-room/sign-in/recover/page.tsx` + `RecoverShell.tsx` | Path A (token in URL) + Path B (paste field) | both subflows render; same `<AuthPasskeyForm mode="register">` core |
| Devices admin | §4.3 | `src/app/control-room/settings/devices/page.tsx` + `<DevicesTable>` | Empty / List / Confirming / Revoking / Revoked | inline confirm pill (NOT modal); strikethrough on revoked rows |
| Audit log | §4.4 | `src/app/control-room/settings/audit/page.tsx` + `<AuditTable>` + `<AuditEventRow>` | Empty / List / Filtered / Expanded / Loading | filter chips; inline expansion; chronological |
| AuditLogPanel | §4.5 | `src/components/control-room/AuditLogPanel.tsx` (server component) + wired to framework page (T19) | Steady / Anomaly / No data | 3-stat row + suspicious-event banner + recent-5 + link to full log |

## Token compliance

| Token | Used in code? |
|---|---|
| `--color-brand-indigo` | ✓ via `style={{ backgroundColor: 'var(--color-brand-indigo)' }}` on primary buttons |
| `--color-brand-coral` | ✓ on the brand-mark circle in sign-in + recover hero |
| `--color-neutral-{50,100,300,500,700,900}` | ✓ via Tailwind utility classes |
| Tailwind `rose-{100,500,600}` | ✓ on error banners |
| Tailwind `emerald-{100,500}` | ✓ on success outcome pill |
| Tailwind `amber-{100,500}` | ✓ on revoke event-type pill |
| Tailwind `slate-{*}` | ✓ on neutral event-type pill |
| `--font-serif` for display | ✓ on h1 + 3xl stat numbers |
| `--measure-narrow` (58ch) | ✓ via `style={{ maxWidth: '58ch' }}` on sign-in/recover panels |
| `--text-display-md` | ✓ via `text-[length:var(--text-display-md)]` |

**Token findings: 0 raw hex literals in feature code.**

## Component reuse

| Reused from existing primitives | Used in |
|---|---|
| `<Panel>` from `primitives.tsx` | AuditLogPanel |
| `<TrackPageView>` | All 4 new pages |
| Existing dark-mode pattern (`.dark` overrides on `<html>`) | All new components |

| Net-new components (declared in spec, built per spec) |
|---|
| `<AuthPasskeyForm>` (T13) — capability detection + ceremony orchestration |
| `<DevicesTable>` (T16) — inline confirm pill |
| `<AuditEventRow>` (T17) — click-to-expand |
| `<AuditLogPanel>` (T18) — 3-stat + recent + banner |

## Accessibility

| Check | Result |
|---|---|
| Tap targets ≥ 44 pt | ✓ — primary buttons `h-12` (48 px); revoke buttons in inline pill have padding to clear 44 pt |
| WCAG AA contrast | ✓ — uses tokens already AA-validated in `globals.css`'s dark overrides |
| `aria-label` on every input + interactive button | ✓ — `aria-label="Sign in with passkey"`, `aria-label={Confirm revoke ${row.label}}`, etc. |
| `role="alert" + aria-live="polite"` on error banners | ✓ — `<AuthPasskeyForm>` error banner; `<AuditLogPanel>` suspicious banner |
| Focus rings | ✓ — `focus-visible:ring-2 focus-visible:ring-brand-indigo focus-visible:ring-offset-2` on every CTA/input |
| Reduced-motion safe | ✓ — `prefers-reduced-motion: reduce` already kills animations globally; no opt-in animations bypass it |
| Dynamic Type / 200% zoom | ✓ — fluid type via `--text-display-md`, no fixed pixel sizes on text |

## Spec drift findings

| Finding | Severity | Resolution |
|---|---|---|
| Conditional-UI autofill input renders even on the manual sign-in path | none | spec §4.1 explicitly requires the input to be visible (browsers anchor autofill to it); current code matches |
| Inline confirm pill uses ✓ ✗ symbols rather than text labels | none | matches spec §4.3 exactly; visible to AT via `aria-label` siblings |
| Brand-coral pulse animation NOT shipped (spec §6 mentions optional 800ms-after-load nudge) | low | optional; deferred — not blocking. Note added to Phase 8 follow-ups list. |

## Verdict

✅ **PASS** — every screen + state + token + component + a11y check from the spec is present in code. `state.json.pre_merge_review.ux = "passed"`.

## State.json mutation

```json
"pre_merge_review": {
  "ux": "passed",
  "ux_review_artifact": ".claude/features/ucc-passkey-auth/ux-pre-merge-review-2026-05-07.md",
  "ux_findings": { "p0": 0, "p1": 0, "p2": 1 }
}
```
