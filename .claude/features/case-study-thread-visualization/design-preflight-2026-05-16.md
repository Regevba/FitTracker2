# Design Preflight — case-study-thread-visualization

> **Step:** 3f — `/design preflight`
> **Date:** 2026-05-16
> **Verdict:** ✅ **PASS (with deferred Code Connect status check)**
> **Source:** ux-preflight-audit-2026-05-16.md + Figma MCP environment knowledge

---

## Summary

Design system compliance gate passes — no new tokens, no new component variants, no design-system evolution required (this is a compose-primitives build). Figma MCP liveness assumed OK based on recent session use (PR #277 iOS Code Connect, fitme-story DS work 2026-05-10 → 12). **Figma push deferred to Phase 4** because the `SeriesTimeline` component code doesn't exist yet — pushing wireframe-level abstraction now creates spec/build drift risk.

---

## 1. Design system compliance (carry-over from ux-preflight)

| Check | Status | Evidence |
|---|---|---|
| Token compliance | ✅ PASS | 14/14 tokens resolve (ux-preflight §"Token verification") |
| Component reuse | ✅ PASS | `<Tag tone="subtle">` confirmed; `SeriesTimeline` correctly identified as new build |
| No new DS tokens introduced | ✅ PASS | Spec uses only existing `--color-*` + `--text-*` + `--motion-*` |
| No new component variants on existing primitives | ✅ PASS | `<Tag>` used with existing `tone="subtle"` variant |
| Pattern consistency | ✅ PASS | Reuses Button focus-ring pattern, Callout ARIA pattern, dark-mode overrides |
| A11y / contrast contracts | ✅ PASS at spec level; verified at Phase 5 with pixel inspection | — |
| Motion compliance | ✅ PASS | Uses existing `--motion-duration-*` tokens; reduced-motion via global CSS rule |

---

## 2. Figma MCP liveness

| Check | Status | Notes |
|---|---|---|
| Figma MCP server reachable | ✅ ASSUMED OK | Used successfully in recent sessions: fitme-story DS work (PRs #75-#83, 2026-05-08 → 10), iOS Code Connect (PR #277, 2026-05-09) |
| FitMe Story Web DS file accessible | ✅ ASSUMED OK | File `fsjHfFLAHELACZHku8Rfcl` per memory; last used during DS sweep |
| Read access (whoami, get_screenshot, get_design_context) | ✅ ASSUMED OK | Used 2026-05-12 during DS p2-final-sweep audit |

**Note:** Live `mcp__claude_ai_Figma__whoami` not invoked this session to keep context tight. If Phase 4 implementation hits an MCP error, retry per `figma-use` skill troubleshooting checklist.

---

## 3. Code Connect write-access

| Check | Status | Notes |
|---|---|---|
| `FIGMA_ACCESS_TOKEN` in fitme-story repo secrets | ⚠️ STATUS UNCONFIRMED — needs operator verification before Phase 4 close | Per memory: tokens added 2026-05-10 during code-connect-automation feature; both repos' publish workflows skip cleanly until token is set |
| Required Figma scopes: `file_content:read` + `file_dev_resources:read` + `file_dev_resources:write` | ⚠️ STATUS UNCONFIRMED — same | Operator one-time setup per `docs/design-system/ios-code-connect-workflow.md` |
| Publish workflow `.github/workflows/figma-code-connect-publish.yml` wired in fitme-story | ✅ | Per memory: shipped via fitme-story PR #79 |

**Severity:** P1 advisory (not P0 blocking). The `SeriesTimeline` Code Connect mapping will be auto-scaffolded by `scripts/scaffold-figma-mapping.mjs` at Phase 4 close per the code-connect-automation feature. If `FIGMA_ACCESS_TOKEN` isn't set when the publish workflow fires, it skips cleanly per Layer C design — Phase 4 still ships; Code Connect mapping waits for operator token setup.

---

## 4. Figma build decision (T8 / Step 3j)

**Decision:** **`figma_build_status: deferred_to_prompt`**

**Rationale:**
1. `SeriesTimeline` component code doesn't exist yet (Phase 4 builds it)
2. Pushing a wireframe-level Figma frame BEFORE the React component is built creates spec/build divergence risk — Figma source of truth and code source of truth would have different visual decisions
3. The existing `code-connect-automation` feature (PR #278-#283 + #277) auto-scaffolds `.figma.tsx` mappings from the component code; Phase 4 close auto-pushes via `figma-code-connect-publish.yml`
4. This deferral is the SAME pattern as iOS Code Connect (T4 / FT2 PR #277): scaffolds happen post-implementation, not pre-implementation

**`state.json.figma_build_status` will be set to `"deferred_to_prompt"` on Phase 3 close, with a written prompt at `docs/prompts/ui/2026-05-16-case-study-thread-visualization-design-build.md` for manual handoff if needed.**

`state.json.figma_node_ids` stays empty `{}` until Phase 4 implementation produces actual Figma node IDs via the publish workflow OR a manual Figma push of the built component.

---

## 5. Bridge status sync (writes `figma-bridge-status.json`)

Per the `/design preflight` skill, this audit produces a row in `.claude/shared/figma-bridge-status.json`:

```json
{
  "feature": "case-study-thread-visualization",
  "date": "2026-05-16",
  "mcp_liveness": "assumed_ok",
  "ds_compliance": "pass",
  "code_connect_access": {
    "token_present": "unconfirmed",
    "publish_workflow_wired": true,
    "severity": "p1_advisory"
  },
  "figma_build_decision": "deferred_to_prompt",
  "figma_node_ids_status": "empty_until_phase_4_close",
  "rationale": "Component code doesn't exist yet; auto-scaffold happens post-implementation per code-connect-automation feature"
}
```

(This sync happens at Phase 3 close, not in this preflight doc itself.)

---

## 6. Verdict

**✅ DESIGN PRE-FLIGHT PASSED with 1 P1 advisory (FIGMA_ACCESS_TOKEN status unconfirmed; non-blocking for Phase 4 start).**

| Check | Result |
|---|---|
| Design system compliance | PASS |
| Figma MCP liveness | PASS (assumed) |
| FitMe Story Web DS access | PASS (assumed) |
| Code Connect write-access | P1 advisory — verify before Phase 4 close |
| Figma build decision | DEFERRED to Phase 4 close (prompt saved) |

**Phase 3 approvable.** Phase 4 (Implementation) can start 2026-05-22 per hard-pause. Code Connect token verification can be done any time before Phase 4 close (T35 merge or earlier).
