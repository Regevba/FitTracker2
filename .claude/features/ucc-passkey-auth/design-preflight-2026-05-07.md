# Design Preflight — `ucc-passkey-auth` — 2026-05-07

**Phase 3 sub-step 3f** (v4.X gate, mandatory before spec is approvable)
**Scope:** verify Figma MCP liveness + library accessibility + decide whether `/design build` runs against Figma OR falls back to portable prompt

---

## Figma MCP liveness

| Check | Result |
|---|---|
| `mcp__claude_ai_Figma__whoami` returns 200 | ✓ |
| Authenticated user | regev.ba@gmail.com (`Regev Barak`) |
| Plan tier | pro · expert seat · `Regev - My apps` team |
| Seat key | `team::726401375318003097` |

**MCP status: ✓ live + authenticated.**

## FitMe Design System Library accessibility

The canonical FitMe Design System Library is `figma:0Ai7s3fCFqR5JXDW8JvgmD` (iOS-aligned tokens + components). It is the source of truth for **the iOS app** (FitTracker, AppTheme.swift, AppComponents.swift).

**This feature ships entirely in fitme-story (web).** The fitme-story dashboard:

- Uses Tailwind v4 + CSS variables in `src/app/globals.css` as its design system
- Has no current Figma-file mapping (the dashboard was built code-first during the UCC Astro→Next.js migration)
- Reuses 5 existing components from `src/components/control-room/primitives.tsx` + 4 net-new ones (declared in [`ux-spec.md`](./ux-spec.md) §2)

The iOS Figma library would not be the right target for these screens — its component vocabulary (SwiftUI `AppCard`, `AppPrimaryButton`, etc.) doesn't apply to the React/Tailwind dashboard.

## Decision: defer `/design build` to portable prompt

Per the v4.X skill-layer protocol, `/design build` falls back to a portable prompt when:

- (a) MCP is unreachable, OR
- (b) the library that would be the build target doesn't apply to the surface being designed (this case)

**Action:** write the portable build prompt at [`docs/prompts/ui/2026-05-07-ucc-passkey-auth-design-build.md`](../../../docs/prompts/ui/2026-05-07-ucc-passkey-auth-design-build.md) and set `state.json.figma_build_status = "deferred_to_prompt"` with reason `"web_dashboard_no_figma_mapping"`.

The portable prompt captures: tokens (Tailwind classes), components (referenced by file path), state matrix (5 states × 5 screens), and visual references (existing framework-health screenshots). A future operator who wants Figma fidelity for the dashboard can run the prompt against a fresh Figma file at any time — the dashboard codebase remains the canonical source.

## Coverage

`figma-bridge-status.json` will record:

```json
{
  "feature": "ucc-passkey-auth",
  "preflight_at": "2026-05-07T17:00:00Z",
  "mcp_live": true,
  "library_accessible": true,
  "build_target_applicable": false,
  "build_decision": "deferred_to_prompt",
  "deferral_reason": "web_dashboard_no_figma_mapping",
  "portable_prompt": "docs/prompts/ui/2026-05-07-ucc-passkey-auth-design-build.md"
}
```

## Result

✅ **PASS** — MCP live + decision recorded + portable prompt path reserved. Phase 3 progresses to design audit (3g) + handoff prompts (3h, 3i) + portable build (3j fallback).
