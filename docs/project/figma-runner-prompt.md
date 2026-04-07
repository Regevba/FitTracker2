# Claude Code Runner — Build UX Foundations Layer + Onboarding v2 in Figma

> **Purpose:** A single copy-paste prompt for Claude Code (terminal) with Figma MCP connected. Runs both Figma jobs sequentially in one session: (1) add the UX Foundations layer to the design system library, (2) build the onboarding v2 screens. Both jobs enforce alignment with the merged code state and the v2 audit findings.
>
> **Prerequisites:**
> - Claude Code session with Figma MCP server connected
> - Access to Figma file key `0Ai7s3fCFqR5JXDW8JvgmD`
> - This repo checked out (any branch — prompts are read-only against the codebase)
> - PR #59 either merged or visible locally — the v2 onboarding code is the source of truth for screen specs
>
> **Estimated runtime:** 1-2 sessions (UX Foundations alone ~30 min; onboarding screens ~45-60 min including manual confirm gates)

---

## THE PROMPT — copy everything below this line into Claude Code

```
You are running TWO sequential Figma jobs against the FitMe design system library
via the Figma MCP server. Do NOT modify any existing pages. Both jobs append new
content alongside existing content as history is preserved.

# Context

- Figma file key: 0Ai7s3fCFqR5JXDW8JvgmD
- Repo cwd: /Volumes/DevSSD/FitTracker2 (or wherever the repo is on this machine)
- Source of truth for screen specs: the v2 onboarding code on the main branch
  after PR #59 merges. If main has not been updated yet, use the
  feature/onboarding-ux-align branch.

# Reference documents (READ FIRST, before touching Figma)

1. docs/design-system/ux-foundations.md (1,533 lines, 10 parts)
   This is the canonical UX + behavioral layer. Job 1 mirrors it into Figma.

2. docs/project/figma-ux-foundations-prompt.md (255 lines)
   Detailed Figma build instructions for Job 1. Layout, colors, frame structure,
   page positioning rules, semantic variable usage. Follow it precisely.

3. docs/project/figma-onboarding-v2-prompt.md (208 lines)
   Detailed Figma build instructions for Job 2. 6 screens, exact tokens, SF Symbol
   icons, layout dimensions, gradient backgrounds. Follow it precisely.

4. .claude/features/onboarding/v2-audit-report.md
   The 24 audit findings that produced the v2 patches. Every screen you build in
   Job 2 must reflect the APPLIED patches (P0 + P1 + select P2), not the v1 state.

5. .claude/features/onboarding/ux-spec.md
   Per-screen v2 spec with state matrix, copy, a11y notes. Use this as the
   ground-truth wireframe description for each screen in Job 2.

6. FitTracker/Services/AppTheme.swift
   Token source of truth. NEW token groups added in v2 that you must reference:
   - AppSize.ctaHeight (52pt) — all primary CTAs
   - AppSize.touchTargetLarge (48pt) — selection circles
   - AppSize.iconBadge (26pt) — overlay icon backgrounds
   - AppSize.progressBarHeight (4pt)
   - AppMotion.stepTransition — annotate animations on prototypes
   - AppRadius.card (16) — alias for card surfaces
   - AppShadow.ctaInverse* — white-CTA-on-orange shadow

7. FitTracker/Views/Onboarding/*.swift (8 files)
   The v2-aligned source. When in doubt about screen content, READ THE ACTUAL
   SwiftUI VIEW for that screen.

# Execution order (gated)

## STEP 0 — Verify state (no Figma writes)

1. Use `use_figma` to list pages in file 0Ai7s3fCFqR5JXDW8JvgmD
2. Confirm the existing pages match what figma-ux-foundations-prompt.md expects
   (Cover, Getting Started, Foundations, ..., Onboarding, ..., App Icon)
3. Confirm there is NO existing "UX Foundations" page yet
4. Confirm the Onboarding page (id 25:6) exists and contains "I3.1 — Onboarding
   Slides" section (node 469:2) — this is the v1 history that MUST stay untouched
5. Report findings as a checklist before proceeding to Step 1

## STEP 1 — Job 1: Add UX Foundations page (per figma-ux-foundations-prompt.md)

Follow figma-ux-foundations-prompt.md EXACTLY. Key checkpoints:

- Position the new "UX Foundations" page AFTER "Patterns" and BEFORE "Platform
  Adaptations" in the page order
- Use semantic variable references from the existing Foundations page (id 10:3) —
  do NOT use raw hex. If the Foundations page has variables for Brand.primary,
  Text.primary, etc., bind your frames to them.
- Master Overview frame at top (1260×420) with the 10-part summary
- 10 section frames below it, one per Part. Each section frame mirrors the
  corresponding Part in ux-foundations.md.
- Use Inter for all text (Figma fallback for SF Pro Rounded)
- Card-style frames: white bg, AppRadius.card (16) corner radius, card shadow
- After building, take a screenshot of the new page and report node IDs for:
  - The page itself
  - Master Overview frame
  - Each of the 10 section frames

Then PAUSE and report Job 1 status to user. Wait for user "ok continue" before
moving to Step 2.

## STEP 2 — Job 2: Build Onboarding v2 screens (per figma-onboarding-v2-prompt.md)

Follow figma-onboarding-v2-prompt.md as the layout baseline, BUT cross-reference
the actual v2 SwiftUI code for each screen. Where the prompt and code disagree,
the CODE is canonical (because v2 has applied audit patches the prompt may
predate). Specifically:

- Welcome screen now uses AppSize.ctaHeight (52pt) and AppShadow.ctaInverse
  shadow tokens — annotate accordingly
- Onboarding flow has 6 screens: Welcome, Goals, Profile, HealthKit, Consent,
  First Action (Consent is screen 5 of 6, integrated since v1 commit d017a30)
- Progress bar: 6 segments, hidden on Welcome AND Consent
- Goals screen: now fires haptic on selection (annotate with a "haptic: selection"
  note)
- Profile screen: same haptic note for both ExperienceCard and FrequencyCircle
- HealthKit screen: now has a LOADING state during async authorization
  (annotate as a state variant) AND a DENIAL state with footer message AND an
  iPad fallback variant
- HealthKit copy is "Apple Health" (not "Health") — terminology unified in v2
- Consent screen: button uses AppColor.Text.inversePrimary (not raw .white)
- First Action screen: title for "Maintain" goal is "Ready to stay on track?"
  (NOT "Ready to maintain?")
- Every screen except Welcome has a Back button in the top-left (P0-06 from v2
  audit). Add a back-arrow icon at top-left on screens 2-6.

CRITICAL: DO NOT modify the existing "I3.1 — Onboarding Slides" section.
Create a NEW section "I3.2 — Onboarding v2 (PRD-Aligned)" positioned BELOW
the existing section (y offset +1100 or wherever there's clear space).

For each of the 6 screens:
1. Build the frame with token-bound colors, fonts, spacings, radii
2. Add state variants where applicable (HealthKit: idle/loading/denied)
3. Take a screenshot
4. Report the node ID
5. PAUSE and present the screenshot to the user with: "Screen N of 6: {name}.
   Diff vs current v1 Figma section: {summary}. Approve or request changes?"

Wait for user approval per screen before moving to the next. This honors the
manual confirm gate from the v2 audit.

## STEP 3 — Reporting

After both jobs complete, report:
1. New page "UX Foundations" — node ID, page index in the file
2. New section "I3.2 — Onboarding v2 (PRD-Aligned)" — node ID, parent page
3. List of all 6 screen node IDs with their canonical names
4. Confirmation that NO existing pages, sections, or nodes were modified
5. Any token mismatches or design system gaps discovered during the build (these
   become follow-up enhancement candidates for AppTheme.swift)

# Constraints

- DO NOT modify FitTracker source code in any way during this run
- DO NOT modify any existing Figma pages, frames, or nodes
- DO NOT skip the manual confirm gate per onboarding screen — it's mandatory
- If Figma MCP rate limits or errors, pause and report — do not retry blindly
- If the codebase state contradicts a prompt instruction, prefer the codebase
  and note the divergence for the user

# Success criteria

- [ ] New "UX Foundations" page exists with master overview + 10 section frames
- [ ] All frames use semantic variables, not raw hex
- [ ] New "I3.2 — Onboarding v2" section exists on Onboarding page
- [ ] 6 onboarding v2 screens built, each approved by user
- [ ] V1 "I3.1 — Onboarding Slides" section UNCHANGED
- [ ] All node IDs reported back for follow-up Code Connect mapping
```

---

## Post-build follow-ups

After Claude Code finishes both jobs, do the following manually or in a follow-up session:

1. **Update node IDs in repo docs**
   Add the reported node IDs to:
   - `.claude/features/onboarding/ux-spec.md` (Figma reference section)
   - `.claude/features/onboarding/v2-audit-report.md` (post-build addendum)
   - `docs/design-system/feature-memory.md` (Figma library evolution log)

2. **Update PRD v2 acceptance criteria checkboxes**
   In `.claude/features/onboarding/prd.md` → `# v2 — UX Alignment` → `## v2 Acceptance Criteria`, check the boxes for:
   - [x] Figma file `0Ai7s3fCFqR5JXDW8JvgmD` has section "I3.2 — Onboarding v2 (PRD-Aligned)" with 6 screens
   - [x] Existing Figma "I3.1 — Onboarding Slides" section is UNCHANGED

3. **Mark V2-T5 (Figma v2 build) as done**
   In `.claude/features/onboarding/state.json`, advance the deferred task tracker.

4. **Commit + push the doc updates**
   ```bash
   git add .claude/features/onboarding/ docs/design-system/feature-memory.md
   git commit -m "docs(onboarding-v2): record Figma v2 + UX Foundations layer node IDs"
   git push
   ```

5. **Begin Figma Code Connect mapping** (optional, separate session)
   Now that the components and screens exist in Figma with stable node IDs, the 13 component families can be mapped to their codebase counterparts via the framework documented in `docs/design-system/figma-coverage-guide.md`.

---

## When to run this

- **Best:** After PR #59 merges — main branch will have the v2 code that screens should match
- **OK:** Before merge, on `feature/onboarding-ux-align` — same code, just unmerged
- **Not yet:** If you're still iterating on the v2 audit findings — wait until patches are stable
