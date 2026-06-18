---
name: design
description: "Use when running a design-system audit, validating semantic tokens, running an accessibility pass, gating Phase 3 UI spec preflight (DS + Figma MCP liveness + Code Connect write-access), gating Phase 6 pre-merge UI review (ui-audit P0=0 + figma_node_ids populated + spec ↔ build parity), generating a Figma build prompt, or pushing screens into the FitMe Design System Library via Figma MCP with .figma.tsx / .figma.swift Code Connect auto-scaffold. Sub-commands: /design audit, /design tokens, /design accessibility, /design preflight {feature}, /design pre-merge-review {feature}, /design prompt {feature}, /design build {feature}. (DEPRECATED: /design figma → /design build; /design ux-spec → /ux spec.)"
last_updated: 2026-05-15
framework_version: v7.8.6
status: active
adapters_used: [axe]
---

# Design & UX Skill: $ARGUMENTS

You are the Design & UX specialist for FitMe. You manage the design system, create UX specs, generate Figma prompts, and enforce accessibility compliance.

> ⛔ **Code Connect DISABLED 2026-06-15.** Figma Code Connect requires an Org/Enterprise plan; this account is Pro, so it is non-operational. In `/design preflight`, **skip** the Step 3.5 Code-Connect-write-access gate (record `cc_publish_authorized: null, cc_publish_error: "code_connect_disabled_pro_plan"` and move on — do NOT block). In `/design pre-merge-review`, **skip** the Step 3.5 spec↔build parity check that depends on `.figma.{swift,tsx}` mappings (do NOT block on `mapping_only`/`figma_only`). `/design build` may still push frames via the Figma MCP plugin API (that works on Pro) and capture node IDs, but must NOT scaffold/expect Code Connect publish. Code is the source of truth. See [`docs/design-system/figma-source-of-truth-plan-2026-06-15.md`](../../../docs/design-system/figma-source-of-truth-plan-2026-06-15.md) + honesty ledger FT2-FH-005.

## Observed patterns preflight

<!-- BEGIN pattern-preflight (generated) -->
The [pattern↔skill map](../../shared/pattern-skill-map.json) tracks **51 work-blocking patterns** (23 gate-firing patterns + 28 workflow patterns) drawn from the [Observed Patterns Catalog](../../integrity/observed-patterns.md) (`make observed-patterns`). The patterns below are the ones mapped to `/design` work — probe the mechanized ones, checklist the rest:

| ID | Pattern | Blocker | Remediation |
|---|---|---|---|
| `#6` | FEATURE_CLOSURE_COMPLETENESS — missing frontmatter on current_phase=complete *(probed)* | yes | Populate the 7 required case-study frontmatter fields + kill_criteria_resolution before the complete-transition commit. |
| `#8` | TIER_TAG_LIKELY_INCORRECT — heuristic T1/T2/T3 mismatch (advisory permanent) *(probed)* | no | Verify the T1/T2/T3 tag; pin correct T1 values in case-study-t1-references.json or set tier_tags_present:false. |
| `#14` | CASE_STUDY_MISSING_TIER_TAGS — forward-only on case studies dated >=2026-04-21 *(probed)* | no | Add at least one T1/T2/T3 tier tag to the case study (dated on or after 2026-04-21). |
| `W14` | Code Connect figma.connect() rejects page frames as targets | yes | Code Connect targets must be components/component-sets; convert page frames or map leaf components only. |
| `W29` | Inline import in case-study MDX is a no-op under compileMDX; JSX components must be registered in useMDXComponents | yes | Register MDX components in src/mdx-components.tsx useMDXComponents map. Inline `import` lines inside MDX bodies are inert under compileMDX. See observed-patterns.md W29 for silence paths. |
| `W36` | Plan/seat-gated external capability documented as operational while it never once succeeded | yes | Treat a plan/seat-gated capability as an external dependency and verify it end-to-end: check the workflow run history (not existence) for successes. Scaffolding present ≠ pipeline working. Detection: `gh run list --workflow=<name>.yml --limit 20 \| grep -c success` (scaffold-only runs?); for Figma Code Connect: MCP get_code_connect_map returns plan-gate error on Pro. Remediation: (1) disable the scaffold CI if the plan is not available; (2) reconcile all docs to reflect the actual state; (3) add a honesty-ledger entry; (4) write a rebuild plan that uses capabilities actually available on the current plan. See observed-patterns.md W36, FT2-FH-005. |
| `W38` | Figma read tools (get_metadata/get_screenshot/get_design_context) reflect the DESKTOP-APP context, not the fileKey → false 'empty file' reads | no | get_metadata/get_screenshot/get_design_context operate against the Figma desktop app's currently-open file/selection, NOT necessarily the fileKey argument. Before tripping a kill criterion or approving a destructive rebuild on an 'empty/missing/invalid' result, confirm with an authoritative use_figma plugin-API read of the same fileKey (getLocalVariableCollectionsAsync, figma.root.children, findAll). Note a VariableCollectionId (e.g. 985:2) is not a scene-node id, so get_variable_defs/get_metadata correctly reject it. See observed-patterns.md W38. |

At activation run `make skill-preflight SKILL=design` — probes the 3 mechanized blockers for this work type; clear any before proceeding.

**Mandatory** (CLAUDE.md §v7.8.5): any novel pattern surfaced this session MUST be appended to [`observed-patterns.md`](../../integrity/observed-patterns.md) before the feature closes — then re-run `make gen-skill-preflight`.
<!-- END pattern-preflight -->

## Shared Data

**Preflight cache:** `.claude/shared/preflight-cache.json` — refreshed by `make preflight WORK_TYPE=<feature|enhancement|fix|chore> [FEATURE=<name>]`. Run BEFORE any sub-command to get current work-context data (W1 ssh-agent, integrity findings, drift vs anchor, doc-debt, adoption baseline). Cache schema: `docs/skills/preflight-cache-schema.md`.

**Reads:** `.claude/shared/context.json` (brand, personas), `.claude/shared/design-system.json` (tokens, components), `.claude/shared/cx-signals.json` (UX confusion signals)

**Writes:** `.claude/shared/design-system.json` (new tokens/components proposed)

## Sub-commands

### `/design audit`

Run a full design system compliance check on the current feature or specified views.

1. Read `.claude/shared/design-system.json` for current token/component inventory
2. Scan specified Swift files for raw color literals, hardcoded spacing, non-semantic font usage
3. Check component reuse — are existing `AppComponents.swift` components used where applicable?
4. Run WCAG AA contrast check on any new colors
5. Verify motion tokens use `AppMotion` presets with `isReduceMotionEnabled` support

Generate compliance report:

| Check | Status | Details |
|-------|--------|---------|
| Token compliance | Pass/Fail | {violations} |
| Component reuse | Pass/Fail | {new components needed?} |
| Pattern consistency | Pass/Fail | {deviations} |
| Accessibility | Pass/Fail | {issues} |
| Motion | Pass/Fail | {non-standard animations?} |

Reference: `docs/design-system/feature-development-gateway.md`, `docs/design-system/approval-process.md`

### `/design ux-spec {feature}` (DEPRECATED — use `/ux spec`)

`/ux spec` is the canonical sub-command for UX spec authoring. Both used to overlap — `/ux spec` won the consolidation in the v4.X skill upgrade (2026-05-06). This sub-command remains as a forwarder that emits a deprecation note and dispatches to `/ux spec {feature}`.

### `/design figma {feature}` (DEPRECATED — use `/design build`)

`/design build` supersedes this sub-command. `/design build` does both the prompt generation (legacy `/design figma` behavior) AND the Figma MCP build attempt with prompt fallback. Kept as a forwarder for backwards compatibility with old PR descriptions and external docs.

### `/design tokens`

Validate the token pipeline.

1. Run `make tokens-check` to verify DesignTokens.swift matches tokens.json
2. Compare token count in code vs `.claude/shared/design-system.json`
3. Report any drift, new tokens needed, or deprecated tokens

### `/design accessibility`

Run WCAG AA accessibility audit.

1. Check contrast ratios for all text/background combinations using `ColorContrastValidator`
2. Verify minimum 44pt tap targets on interactive elements
3. Check Dynamic Type support
4. Verify VoiceOver labels exist on all interactive elements
5. Verify `AppMotion` respects `isReduceMotionEnabled`

### `/design preflight {feature}`

**Purpose:** Pre-Phase-4 gate — extends `/ux preflight` with design-system-specific checks AND verifies the Figma MCP bridge is live before any `/design build` attempt. Combines:
- Token / component / pattern existence (delegates to `/ux preflight` if not yet run; idempotent)
- Figma MCP server connection check
- Figma library file accessibility check (read-only call against `0Ai7s3fCFqR5JXDW8JvgmD`)
- Figma library node availability check (every component referenced in `ux-spec.md` must have either an existing Figma node mapping in `figma-code-sync-status.md` OR be flagged as a new component to be created during `/design build`)

**Trigger:** Auto-dispatched by `/pm-workflow` Phase 3, after `/ux preflight` lands, before `/design audit`. Also invokable standalone.

**Steps:**
1. Read `.claude/cache/_shared/ux-spec-preflight.json` to get the token/component/pattern lists from `/ux preflight`. If the entry doesn't exist, call `/ux preflight {feature}` first.
2. **Figma MCP liveness check:**
   - Call `mcp__claude_ai_Figma__whoami` (read-only, no side effects)
   - On success: record `mcp_connected: true`
   - On failure (timeout / error / not authenticated): record `mcp_connected: false, mcp_error: "{error_message}"`
3. **Figma library file accessibility check:**
   - Call `mcp__claude_ai_Figma__get_metadata` with `fileKey = "0Ai7s3fCFqR5JXDW8JvgmD"`
   - On success: record `library_accessible: true`, capture `node_count` and `last_modified`
   - On failure: record `library_accessible: false, library_error: "{error}"`
3.5. **Code Connect write-access gate (added 2026-05-10):** verify the publish path will work end-to-end, not just the read path checked above. Two sub-checks:
   - **Token presence check:**
     - Local invocation: check `$FIGMA_ACCESS_TOKEN` env var. Record `cc_token_present_local: bool`.
     - CI invocation: check that `secrets.FIGMA_ACCESS_TOKEN` is set in BOTH `Regevba/FitTracker2` and `Regevba/fitme-story` repos via `gh api repos/{owner}/{repo}/actions/secrets/FIGMA_ACCESS_TOKEN` (returns 200 if exists, 404 if not). Record `cc_token_present_ci: { ft2: bool, fitme_story: bool }`.
   - **Publish dry-run probe (only if token is present locally):**
     - Run `npx --yes --package=@figma/code-connect figma connect publish --dry-run --token "$FIGMA_ACCESS_TOKEN" --skip-update-check` from the active repo root
     - On success: record `cc_publish_authorized: true`
     - On 401 / 403: record `cc_publish_authorized: false, cc_publish_error: "auth failed — token likely missing Code Connect Write scope"`
     - On other error: record `cc_publish_authorized: null, cc_publish_error: "{error}"` (network / unrelated)
   - **Output:** add `code_connect_access` block to `figma-bridge-status.json`:
     ```json
     "code_connect_access": {
       "cc_token_present_local": bool,
       "cc_token_present_ci": { "ft2": bool, "fitme_story": bool },
       "cc_publish_authorized": bool | null,
       "cc_publish_error": string | null,
       "last_checked": "ISO 8601"
     }
     ```
4. **Figma library node availability check:**
   - Read `docs/design-system/figma-code-sync-status.md` for existing node mappings
   - For each component in the spec, look up its mapping. Components without a mapping are flagged as "to be created during `/design build`" (P2, not blocking)
5. **Token compliance check (delegates to existing `/design audit`):**
   - Run `/design audit` against the spec
   - Aggregate findings by severity
6. Write a combined preflight report to `.claude/features/{feature}/design-preflight-{date}.md`
7. Write the bridge status to `.claude/shared/figma-bridge-status.json`:
   ```json
   {
     "mcp_connected": bool,
     "library_accessible": bool,
     "library_file_key": "0Ai7s3fCFqR5JXDW8JvgmD",
     "node_count": int | null,
     "last_checked": "ISO 8601",
     "last_error": string | null
   }
   ```

**Gate behavior:**
- **`mcp_connected == false` → P1 advisory.** `/design build` will fall back to prompt-only mode; user is informed.
- **`library_accessible == false` AND `mcp_connected == true` → P0.** Either credentials are wrong or the file was moved. User must resolve before `/design build` runs.
- **`cc_publish_authorized == false` (token present but auth failed) → P1 advisory** (added 2026-05-10). Publish step in CI / via operator will fail. Surface clear remediation: regenerate token with both `File Content` + `Code Connect Write` scopes, re-add to repo secrets. `/design build` still proceeds — Layer A scaffold runs, Layer C publish is the affected stage.
- **`cc_token_present_local == false` AND `cc_token_present_ci.{repo} == false` for the active repo → P2 advisory** (added 2026-05-10). Operator hasn't set up Code Connect publishing yet. `/design build` proceeds normally; the auto-published mappings simply won't appear in Figma Dev Mode until the secret is added. Link operator runbook.
- **Token P0 from `/design audit` → P0.** Same as `/ux preflight` token gate.
- **Spec is approvable when:** all P0 findings resolved AND all required tokens/components confirmed present (or new ones explicitly approved on this feature's branch per CLAUDE.md design-system evolution rule).

**Output:** `.claude/features/{feature}/design-preflight-{date}.md` + `.claude/shared/figma-bridge-status.json`.

**Self-test fixtures (P1.3, shipped 2026-05-14):** [`.claude/skills/design/fixtures/`](fixtures/) holds canonical regression test cases for the **spec-side symbol-existence check** (the part `/design preflight` inherits from `/ux preflight`). Driver: [`scripts/preflight-fixture-test.py`](../../../scripts/preflight-fixture-test.py); invocation: `make preflight-fixture-test`. The Figma MCP liveness + Code Connect write-access checks (Steps 2, 3, 3.5 above) cannot be fixture-tested mechanically — they require live MCP authentication + token presence. Those have other safeguards: MCP failure surfaces as P1 advisory in `figma-bridge-status.json`; absent tokens surface as P2.

### `/design pre-merge-review {feature}`

**Purpose:** Phase 6 (Review) UI-specific layer — pairs with `/ux pre-merge-review`. Validates that:
1. `make ui-audit` reports P0 = 0 against the feature's view files
2. Figma node IDs for each shipped surface are present in `state.json.figma_node_ids`
3. The PR description references those Figma node IDs (CLAUDE.md "Synced" definition mandates this)
4. (Optional) Screenshot diff between Figma exports and rendered SwiftUI views — manual or auto via `mcp__claude_ai_Figma__get_screenshot`

**Trigger:** Auto-dispatched by `/pm-workflow` Phase 6, after Phase 5 (Testing) approval. Also invokable standalone.

**Prerequisites:**
- `state.json.phases.testing.status == "approved"`
- `state.json.phases.implementation.commits[]` non-empty
- A feature branch exists with the implementation

**Steps:**
1. Read `state.json` for the feature's view file paths + `figma_node_ids` field
2. Run `make ui-audit` and parse output for the feature's view files. P0 > 0 → BLOCK.
3. **Figma node ID presence check:**
   - For each surface listed in `ux-spec.md`, verify `state.json.figma_node_ids["{surface_name}"]` exists and is non-empty
   - If absent → BLOCK with "/design build {feature} must run before merge"
3.5. **Spec ↔ build parity check (added 2026-05-10):** verifies what was actually built matches what the spec said to build. Three sub-checks:
   - **Spec surface enumeration:** parse `ux-spec.md` (or `integration-spec.md` for has_ui:false features) into a canonical surface list. Sources to scan, in order: (a) explicit `## Screens` / `## Surfaces` / `## Components` sections; (b) tables with a `Surface` or `Screen` column; (c) headings of the form `### {SurfaceName}`. Normalize names to snake_case keys. Result: `spec_surfaces: [...]`.
   - **Build surface enumeration:** read `state.json.figma_node_ids` keys (excluding RESERVED_KEYS like `library_file_key`, `code_mapping`, etc.) → `built_figma_nodes: [...]`. Read repo for `.figma.{swift,tsx}` files matching this feature's view files (FT2: `FitTracker/Views/**/*.figma.swift`; fitme-story: `src/components/**/*.figma.tsx`) → `built_mappings: [...]`.
   - **Match each spec surface against built artifacts:**
     - For each `spec_surface`:
       - Has matching `figma_node_ids` key (snake_case match OR `code_mapping` override) → ✓ figma_built
       - Has matching `.figma.{swift,tsx}` mapping file → ✓ code_connect_mapped
       - Both ✓ → `parity: complete`
       - Only figma_built ✓ → `parity: figma_only` (mapping file missing — Layer A scaffold likely didn't run, or operator deleted; ADVISORY for operator-deleted-on-purpose, otherwise BLOCK)
       - Only code_connect_mapped ✓ → `parity: mapping_only` (figma_node_id missing — `/design build` likely failed; BLOCK)
       - Neither ✓ → `parity: missing` (BLOCK with "{surface} declared in spec but not built")
     - Reverse check (over-build advisory): list `built_figma_nodes` not present in `spec_surfaces`. These are NOT a block (spec may have evolved during impl), but surface as ADVISORY: "{node} built but not in spec — confirm intentional or update spec".
   - **Output:** `state.json.pre_merge_review.design_parity = { spec_surfaces, built_figma_nodes, built_mappings, parity_per_surface, advisories }`. BLOCK if any `parity: missing` or `parity: mapping_only`.
4. **PR description check (when running in CI / against a PR):**
   - Get current PR description via `gh pr view`
   - For each Figma node ID in `state.json.figma_node_ids`, verify it appears in the PR body
   - If absent → PASS_WITH_NOTES; suggest the node IDs to add
5. **Screenshot diff (optional, manual sign-off):**
   - For each Figma node ID, call `mcp__claude_ai_Figma__get_screenshot`
   - Compare visually with rendered SwiftUI (manual review by user; tool surfaces side-by-side)
6. Write the review at `.claude/features/{feature}/design-pre-merge-review-{date}.md` with the verdict
7. **Sub-step 6f (T21, framework-v7-8-branch-isolation, advisory in v7.8 → enforced in v7.9):** kill_criteria_resolution check. Read the linked case study at `state.json.case_study`. Parse its frontmatter. If `kill_criteria` is non-empty, verify `kill_criteria_resolution` is non-empty AND substantively addresses each kill threshold (heuristic: mentions at least one of the listed kill thresholds verbatim OR contains acceptance keywords like "not tripped", "deferred", "superseded", "passed"). If kill_criteria is empty, skip. Failure → set `state.json.pre_merge_review.design = "blocked"` with `block_reason: "kill_criteria_resolution missing or non-substantive"`. Per `framework-v7-8-branch-isolation/integration-spec.md` §2.2.
8. Set `state.json.pre_merge_review.design = "passed" | "passed_with_notes" | "blocked"`

**Gate behavior:**
- **BLOCK verdict → Phase 7 (Merge) is NOT approvable.** User must address findings or override with explicit justification recorded in `transitions[].note`.
- **PASS_WITH_NOTES** is allowed; notes appear in PR description.

**Output:** `.claude/features/{feature}/design-pre-merge-review-{date}.md` + `state.json.pre_merge_review.design` field.

### `/design prompt {feature}`

**Purpose:** Auto-generate a visual-build prompt for another agent (typically a Figma MCP agent) once Phase 3 design work is approved. Paired with `/ux prompt {feature}` — `/ux` writes the what-and-why prompt, `/design` writes the how-it-looks prompt. Both land in `docs/prompts/` so the receiving agent can read them together.

**Prerequisites:**
- `.claude/features/{feature}/ux-spec.md` exists and is approved
- `/design audit` passed for the ux-spec (Phase 3 compliance gateway)
- Figma library nodes identified (or flagged as "to be built")
- `.claude/shared/design-system.json` current

**Steps:**
1. Read `ux-spec.md`, `state.json`, `design-system.json`, and (if v2 refactor) `v2-audit-report.md` to pull the design requirements
2. Read relevant sections of `AppTheme.swift`, `AppComponents.swift`, `AppMotion.swift` to enumerate the exact tokens the feature will consume
3. Read the Figma file key and target section node IDs from `state.json` or `figma-library-progress.md`
4. Assemble a single prompt file with:
   - **Header** — feature name, target agent (Figma MCP / SwiftUI builder), date, related GitHub issue, paired `/ux prompt` path
   - **Visual target** — Figma file key + target section node ID + reference to v1 node IDs (for v2 refactors)
   - **Screen inventory** — for each screen: purpose, primary content, primary CTA, modals/sheets
   - **Token contract** — the exact `AppColor.*`, `AppText.*`, `AppSpacing.*`, `AppRadius.*`, `AppShadow.*`, `AppMotion.*` the agent must use. No raw literals.
   - **Component contract** — the exact `AppComponents.swift` components to reuse. Any new components flagged with justification.
   - **State coverage** — default / loading / empty / error / success, with the exact `EmptyStateView` copy and `FitMeLogoLoader` mode
   - **Accessibility contract** — tap target minimums, Dynamic Type behavior, VoiceOver label template, reduce-motion alternatives
   - **Motion contract** — the exact `AppSpring.*` / `AppEasing.*` / `AppDuration.*` tokens, with reduce-motion fallbacks
   - **Figma node plan** — for each screen, the Figma node ID (existing or new) + position in the frame hierarchy
   - **Handoff checklist** — what the receiving agent produces (PNG exports, node IDs, screenshots) and returns
   - **References** — paths to ux-spec, design-system.json, AppTheme.swift, AppComponents.swift, feature-development-gateway
5. **Write the prompt** to `docs/prompts/ui/{YYYY-MM-DD}-{feature}-design-build.md` (folder split established 2026-05-06: design/UI prompts land in `docs/prompts/ui/`, UX what-and-why prompts land in `docs/prompts/ux/`, legacy flat files migrated to `docs/prompts/_legacy/`)
6. Announce: "Design handoff prompt written to `docs/prompts/ui/…`. Pair with `/ux prompt` at the matching path under `docs/prompts/ux/`. Ready to transfer to the receiving agent."

**Output:** `docs/prompts/ui/{YYYY-MM-DD}-{feature}-design-build.md`

**When to run:** Automatically dispatched by `/pm-workflow` after Phase 3 approval when both `/ux` and `/design` gates are passed. Also invokable standalone once the spec is done.

### `/design build {feature}`

**Purpose:** Build/update the feature's screens in Figma using the Figma MCP, with automatic fallback to a saved prompt if MCP fails. Writes Figma node IDs back to `state.json.figma_node_ids` and `figma-code-sync-status.md` so subsequent `/design pre-merge-review` runs have ground truth.

**Trigger (NEW v4.X):** Auto-dispatched by `/pm-workflow` Phase 3 step 3h, after `/design prompt` lands and `/design preflight` reports MCP available. If `/design preflight` reported `mcp_connected: false`, this skill skips the MCP attempt and goes straight to the prompt-fallback announcement.

**Prerequisites:**
- `state.json.phases.ux_or_integration.status == "in_progress"` (Phase 3 still active)
- `/design preflight` has run; `figma-bridge-status.json` reflects current MCP state
- `docs/prompts/ui/{date}-{feature}-design-build.md` exists from `/design prompt` (auto-generated if missing)

**Steps:**
1. Read the feature's `ux-spec.md` for the visual specification
2. Read `.claude/shared/figma-bridge-status.json` for current MCP status
3. Read the feature's design build prompt at `docs/prompts/ui/{date}-{feature}-design-build.md` (auto-generate via `/design prompt` if missing)
4. **Attempt Figma MCP build (only if `mcp_connected == true`):**
   - Load the `figma-use` skill (mandatory prerequisite)
   - Load the `figma-generate-design` skill
   - Follow the screen-building workflow: discover design system → create wrapper → build sections → validate with screenshots
   - For each screen successfully created/updated: capture the Figma node ID
   - **Write node IDs back:**
     - Append/update `state.json.figma_node_ids[{screen_name}]` with the captured node ID
     - Append/update `docs/design-system/figma-code-sync-status.md` matrix with a row for the feature (Figma node | Code file | Status | Notes)
   - **Auto-scaffold Code Connect mappings (Layer B, added 2026-05-09 via `code-connect-automation` feature):** after `figma_node_ids` is updated, invoke the scaffold script for the current repo:
     - In FT2: `python3 scripts/scaffold-figma-mapping.py {feature}` — generates `.figma.swift` template files alongside the SwiftUI Views matched via the script's heuristic (snake_case → PascalCase + state-qualifier strip; falls back to `figma_node_ids.code_mapping` override block)
     - In fitme-story: `node scripts/scaffold-figma-mapping.mjs {feature}` — generates `.figma.tsx` template files alongside the React components
     - Coalesces multiple state variants of the same View/component into one mapping file with multiple `FigmaConnect` structs / `figma.connect` calls
     - Idempotent: skips if `.figma.{swift|tsx}` already exists. Use `--force` to overwrite if the operator deliberately re-scaffolds
     - Emits per-entry status report (scaffolded / skipped / unmapped). Unmapped entries trigger a warning — operator either adds a `code_mapping` override to `state.json::figma_node_ids` OR hand-authors the mapping file
     - Operator-only step deferred: `figma connect publish` (requires `FIGMA_ACCESS_TOKEN`); planned to fire automatically via Layer C CI workflow once `FIGMA_ACCESS_TOKEN` repo secret is added
     - Companion docs: `docs/design-system/ios-code-connect-workflow.md` (operator runbook, iOS) + `docs/design-system/fitme-story-design-architecture.md` (web architecture)
5. **On Figma MCP failure** (connection error, timeout, API error, OR `mcp_connected: false` from preflight):
   - Announce: "Figma MCP unavailable: {error/reason}. Falling back to saved prompt."
   - Verify the design build prompt exists at `docs/prompts/ui/{date}-{feature}-design-build.md`
   - Present the prompt path to the user: "Copy this prompt into Claude Console with Figma MCP access: `docs/prompts/ui/{feature}-design-build.md`"
   - Set `state.json.figma_build_status = "deferred_to_prompt"` so the gate at `/design pre-merge-review` knows to expect manual completion
6. **Always save the prompt** (even on MCP success) as a backup at `docs/prompts/ui/{date}-{feature}-design-build.md` — this ensures every feature has a portable Figma build prompt regardless of MCP availability. The prompt is the durable source of truth; Figma is the rendered output.

**Output:** Figma screens (if MCP succeeds) + saved prompt file (always) + `state.json.figma_node_ids` populated + `figma-code-sync-status.md` row added.

**Idempotency:** Safe to re-run. Subsequent runs reconcile against existing node IDs in `state.json.figma_node_ids` and update Figma frames in-place rather than duplicating.

## Key References

- `FitTracker/Services/AppTheme.swift` — semantic token layer
- `FitTracker/DesignSystem/AppComponents.swift` — reusable components
- `FitTracker/DesignSystem/AppMotion.swift` — motion tokens
- `FitTracker/DesignSystem/AppViewModifiers.swift` — view modifiers
- `docs/design-system/feature-development-gateway.md` — 7-stage workflow
- `docs/design-system/design-system-governance.md` — governance rules
- `docs/design-system/feature-design-checklist.md` — per-feature checklist

---

## External Data Sources

| Adapter | Type | What It Provides |
|---------|------|-----------------|
| figma | MCP | Design context, screenshots, component metadata, code connect mappings |

**Adapter location:** Already connected via Figma MCP in settings.
**Shared layer writes:** `design-system.json`

### Validation Gate

All incoming design data passes through automatic validation before entering the shared layer:
- Score >= 95% GREEN: Data is clean. Write to shared layer. Notify /design + /pm-workflow.
- Score 90-95% ORANGE: Minor discrepancies. Write + advisory. Review when convenient.
- Score < 90% RED: DO NOT write. Alert /design + /pm-workflow. User must resolve.

Validation is automatic. Resolution is always manual.

## Research Scope (Phase 2)

When the cache doesn't have an answer for a design task, research:

1. **Token inventory** — current AppTheme.swift tokens, which semantic token covers the use case, whether a new token is needed
2. **Component catalog** — existing AppComponents.swift components, whether to reuse or extend, Figma component parity
3. **Design foundations** — ux-foundations.md principles, feature-memory.md evolution queue, design system governance rules
4. **Tools & integrations** — Figma MCP capabilities, code connect mappings, Style Dictionary pipeline
5. **Visual patterns** — platform HIG updates, new SwiftUI APIs, accessibility compliance methods (WCAG AA)

Sources checked in order: L1 cache → L2 shared (ux-foundations-map, design-system-decisions) → shared layer (design-system.json) → Figma MCP → codebase (AppTheme.swift, AppComponents.swift) → external docs

## Cache Protocol

**Phase 1 (Cache Check):** Read `.claude/cache/design/_index.json`. Check for cached token mappings, component selections, v2 refactor patterns. Also read `.claude/cache/_shared/ux-foundations-map.json` and `.claude/cache/_shared/design-system-decisions.json` for cross-skill patterns.

**Phase 4 (Learn):** Extract new patterns (token mapping decisions, component reuse, refactor methodology). Write/update L1 cache. Design system patterns shared with /ux should be promoted to L2.

**Cache location:** `.claude/cache/design/`

---

## Cache Protocol

### Phase 1 — Cache Check (on skill start)
Read `.claude/cache/design/_index.json`, match `token_compliance_audit`, check L2 `design-system-decisions.json`. If hit: check known violation categories first. If miss: Phase 2.

### Phase 4 — Learn (on skill complete)
Extract new token/component patterns. Write L1. If cross-screen, flag L2.

### Health Check (Phase 0 — random trigger)
On skill start, before cache check:
1. Read `.claude/shared/framework-health.json`
2. If `random() < 0.25` AND `hours_since(last_check) > 2`: run 5 health checks, compute weighted score, append to history
3. If score < 0.90: STOP and alert user with failing checks and rollback options
4. Proceed to Phase 1 (Cache Check)

## External Data Sources

| Adapter | Location | Shared Layer Target | When to Pull |
|---------|----------|-------------------|--------------|
| (none directly) | — | Reads design-system.json populated by other skills | — |

**Fallback:** If adapter unavailable, continue with existing shared data. Log to change-log.json.

## Research Scope (Phase 2 — when cache misses)

1. Token inventory from AppTheme.swift
2. Component library from AppComponents.swift
3. WCAG AA compliance (contrast, tap targets)
4. Figma design context via MCP
5. Motion specs from ux-foundations.md Part 8

**Source priority:** L2 cache > L1 cache > shared layer (design-system.json) > Figma MCP > AppTheme.swift direct read


## Anti-patterns

Hard-won mistakes for `/design` work. Every bullet encodes a real or near-miss failure mode.

- Do not introduce a raw `Color(...)` literal, `#hex` string, or `.font(.system(...))` call outside `DesignTokens.swift` — always go through `AppTheme` tokens (`make ui-audit` rule `DS-RAW-COLOR-*` enforces; P0 baseline is 0)
- Do not advance Phase 3 without `/design preflight` recording Code Connect write-access status — auth-failure is a silent-pass class for the publish pipeline
- Do not advance Phase 6 while `make ui-audit` reports any P0 finding (DS-RAW-* / DS-MISSING-ASSET / DS-A11Y-BUTTON)
- Do not introduce a new `Color("name")` token without adding the matching `.colorset` directory + `design-tokens/tokens.json` entry + `DesignTokens.swift` generated line in the same commit (DS-MISSING-ASSET rule enforces)
- Do not skip the spec ↔ build parity check at `/design pre-merge-review` — every spec surface must resolve to `complete`, never `mapping_only` or `missing` (pattern #6 `FEATURE_CLOSURE_COMPLETENESS`)
