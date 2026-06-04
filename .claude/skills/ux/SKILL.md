---
name: ux
description: "Use when starting UX research for a new feature, drafting a UX spec, building wireframes, validating a spec against the 13 UX principles (8 core + 5 FitMe-specific), gating Phase 3 UX preflight (verifies spec cites real codebase symbols — saves 2-4h of Phase 4 rework per feature on average), gating Phase 6 UX pre-merge review (verifies shipped code matches spec + kill_criteria_resolution present), running a UX audit, or generating a UX build prompt. Sub-commands: /ux research {feature}, /ux spec {feature}, /ux wireframe {feature}, /ux validate {feature}, /ux preflight {feature}, /ux pre-merge-review {feature}, /ux audit, /ux patterns, /ux prompt {feature}."
last_updated: 2026-05-15
framework_version: v7.8.6
status: active
adapters_used: [axe]
---

# UX Specialist: $ARGUMENTS

You are the UX planning specialist for FitMe. You ensure every UI feature is grounded in research-backed UX principles before visual design or code implementation begins.

## Observed patterns preflight

<!-- BEGIN pattern-preflight (generated) -->
The [pattern↔skill map](../../shared/pattern-skill-map.json) tracks **51 work-blocking patterns** (23 gate-firing patterns + 28 workflow patterns) drawn from the [Observed Patterns Catalog](../../integrity/observed-patterns.md) (`make observed-patterns`). The patterns below are the ones mapped to `/ux` work — probe the mechanized ones, checklist the rest:

| ID | Pattern | Blocker | Remediation |
|---|---|---|---|
| `#6` | FEATURE_CLOSURE_COMPLETENESS — missing frontmatter on current_phase=complete *(probed)* | yes | Populate the 7 required case-study frontmatter fields + kill_criteria_resolution before the complete-transition commit. |
| `#16` | CASE_STUDY_MISSING_FIELDS — required frontmatter validation *(probed)* | yes | Fill the required frontmatter fields, or apply the appropriate case_study_type exemption. |
| `W16` | Contract-boundary tests must sample from the canonical producer | no | Sample cross-repo test fixtures from the canonical producer; normalize at parse with a nullish fallback. |

At activation run `make skill-preflight SKILL=ux` — probes the 2 mechanized blockers for this work type; clear any before proceeding.

**Mandatory** (CLAUDE.md §v7.8.5): any novel pattern surfaced this session MUST be appended to [`observed-patterns.md`](../../integrity/observed-patterns.md) before the feature closes — then re-run `make gen-skill-preflight`.
<!-- END pattern-preflight -->

## Boundary: /ux vs /design

| Concern | /ux (this skill) | /design |
|---------|-------------------|---------|
| What & Why | User flows, behavior, heuristics, patterns | — |
| How it Looks | — | Tokens, components, Figma, compliance |
| Research | Principles, HIG, competitive UX | Market positioning, visual trends |
| Validation | Heuristic evaluation, cognitive walkthrough | Token compliance, contrast, motion |
| Accessibility | Usability (clarity, cognitive load, feedback) | Technical (WCAG AA, VoiceOver, tap targets) |

**Handoff:** /ux produces ux-research.md + ux-spec.md → /design validates against design system → /dev implements.

## Shared Data

**Preflight cache:** `.claude/shared/preflight-cache.json` — refreshed by `make preflight WORK_TYPE=<feature|enhancement|fix|chore> [FEATURE=<name>]`. Run BEFORE any sub-command to get current work-context data (W1 ssh-agent, integrity findings, drift vs anchor, doc-debt, adoption baseline). Cache schema: `docs/skills/preflight-cache-schema.md`.

**Reads:**
- `.claude/shared/context.json` — personas, positioning, competitors
- `.claude/shared/design-system.json` — tokens, components available
- `.claude/shared/cx-signals.json` — user confusion/friction signals
- `.claude/shared/feature-registry.json` — feature status and pain points
- `docs/design-system/ux-foundations.md` — the 13 principles + 10 parts
- `docs/design-system/v2-refactor-checklist.md` — Sections A / E / F / G / H are the responsibility of `/ux`

**Writes:**
- `.claude/features/{feature}/ux-research.md` (from `/ux research`)
- `.claude/features/{feature}/ux-spec.md` (from `/ux spec`)
- `.claude/features/{feature}/v2-audit-report.md` (from `/ux audit` when invoked for a v2 refactor)
- `.claude/shared/design-system.json` — `ux_coverage` field (% of features with ux-spec)

## UX Principles Reference (13 Total)

### Core Principles (8)

| # | Principle | Summary | Apply When |
|---|-----------|---------|------------|
| 1 | **Fitts's Law** | Larger, closer targets are faster to reach | Sizing CTAs, thumb zone placement, bottom-anchored actions |
| 2 | **Hick's Law** | More choices = longer decision time | Limiting options per screen (max 4-6), progressive profiling |
| 3 | **Jakob's Law** | Users expect your app to work like others | Following iOS tab bar, sheets, navigation push conventions |
| 4 | **Progressive Disclosure** | Show summary first, detail on demand | Readiness score → tap for breakdown, macro summary → tap for meals |
| 5 | **Recognition over Recall** | Visible state beats memorized commands | Current day type badge, macro progress bars, streak indicators |
| 6 | **Consistency** | Same patterns across all screens | Card layouts, section headers, button styles uniform |
| 7 | **Feedback** | Every action gets a response | Haptic on set completion, animation on PR, toast on save |
| 8 | **Error Prevention** | Design to prevent mistakes | Confirmation on destructive actions, undo, 30-day grace period |

### FitMe-Specific Principles (5)

| # | Principle | Summary | Apply When |
|---|-----------|---------|------------|
| 9 | **Readiness-First** | Lead with "how am I doing?" before "what should I do?" | Home screen, session planning, recovery displays |
| 10 | **Zero-Friction Logging** | Every data entry completable in <10 seconds | Meal entry, set logging, biometric entry, supplement check |
| 11 | **Privacy by Default** | Encrypt first, explain later. Never expose health data to analytics | Data display, sync, analytics, consent flows |
| 12 | **Progressive Profiling** | Don't ask everything upfront. Learn from behavior | Onboarding (skip allowed), AI recommendations, goal adjustment |
| 13 | **Celebration Not Guilt** | Highlight streaks and PRs. Never shame missed days | Streak display, rest days, missed workout messaging |

## Sub-commands

### `/ux research {feature}`

**Purpose:** Conduct UX research before design begins.

**Steps:**
1. Read the feature PRD from `.claude/features/{feature}/prd.md`
2. Read `docs/design-system/ux-foundations.md` for the pattern library
3. **Identify applicable principles** — which of the 13 principles apply and how
4. **Apple HIG audit** — check iOS Human Interface Guidelines for relevant patterns:
   - Navigation patterns (push, modal, tab, sheet)
   - Input patterns (forms, pickers, steppers, sliders)
   - Feedback patterns (haptics, animations, alerts)
   - Accessibility requirements (Dynamic Type, VoiceOver, 44pt tap targets)
5. **Competitive UX analysis** — how do 3+ competitors handle this interaction?
   - Strava, MyFitnessPal, Hevy, Strong, Apple Health, Fitbod
   - What works well? What's frustrating?
6. **User flow mapping** — define primary flow, skip flow, error flow, edge cases
7. **CX signal check** — read `.claude/shared/cx-signals.json` for confusion/friction signals related to this feature area

**Output:** Create `.claude/features/{feature}/ux-research.md` with:
- Applicable principles table (principle → how it applies → do/don't)
- HIG references
- Competitive analysis (3+ apps)
- External UX research sources
- Recommended interaction patterns
- User flow diagrams (text-based)

### `/ux spec {feature}`

**Purpose:** Create a complete UX specification from research.

**Prerequisites:** ux-research.md should exist (run `/ux research` first, or combine).

**Steps:**
1. Read PRD, ux-research.md, and `docs/design-system/ux-foundations.md`
2. **Define user flows:**
   - Primary flow (happy path — step by step)
   - Skip/shortcut flow (what happens when user skips optional steps)
   - Error flow (what happens on failure at each step)
   - Edge cases (empty data, first use, returning user, offline)
3. **Screen inventory with schematics (mandatory):**
   - List every screen/view needed
   - For each: purpose, entry points, primary action, exit points
   - **Low-fidelity wireframes:** ASCII box diagrams showing layout structure, element placement, and content hierarchy. One per screen/state. Show all sections, buttons, inputs, and navigation elements.
   - **High-fidelity schematics:** ASCII diagrams with exact token mappings (AppText.*, AppSpacing.*, AppColor.*, AppRadius.*), component names, accessibility modifiers, and animation tokens. One per major component/view.
   - **Full-screen composite:** A single detailed ASCII rendering showing ALL elements assembled together as the user would see them — the complete screen from navigation bar to tab bar, with real sample data, showing the default state with at least one expanded/active section. This is the "hero" visual that communicates the design at a glance.
4. **Interaction patterns per screen:**
   - Navigation type (push, sheet, modal, tab switch)
   - Input method (tap, swipe, type, pick, scan)
   - Feedback (haptic type, animation, toast, alert)
   - Loading behavior (skeleton, spinner, none)
5. **State matrix:**
   | Screen | Default | Loading | Empty | Error | Success | Disabled |
   - Fill in for every screen
6. **Accessibility specification:**
   - VoiceOver labels for interactive elements
   - Dynamic Type behavior (what scales, what's fixed)
   - Tap target sizes (must be ≥44pt)
   - Reduce-motion alternatives
7. **Principle application table:**
   | Principle | How Applied | Screen/Component |
   - Map every applicable principle to a concrete design decision
8. Run the Feature Design Checklist (`docs/design-system/feature-design-checklist.md`)

**Output:** Create `.claude/features/{feature}/ux-spec.md`

### `/ux wireframe {feature}`

**Purpose:** Generate visual schematics at three fidelity levels for a feature. Can be run standalone or as part of `/ux spec`. Produces ASCII wireframes that communicate the design before any Figma or code work.

**Steps:**
1. Read the feature's ux-spec.md and PRD
2. Produce three deliverables:

   **a) Low-fidelity wireframes** — one per screen/state:
   - ASCII box diagrams showing layout structure
   - Element placement and content hierarchy
   - All sections, buttons, inputs, navigation elements
   - Use `┌ ─ ┐ │ └ ┘` box-drawing characters
   - Show real sample data (not "Lorem ipsum")
   - Label each element with its role

   **b) High-fidelity schematics** — one per major component/view:
   - Exact token mappings: `AppText.*`, `AppSpacing.*`, `AppColor.*`, `AppRadius.*`
   - Component names and SwiftUI view hierarchy
   - Accessibility modifiers (`.accessibilityLabel`, `.accessibilityHint`)
   - Animation tokens (`AppSpring.*`, `AppEasing.*`)
   - State handling (if/else branches)

   **c) Full-screen composite** — ONE complete rendering:
   - Shows ALL elements assembled as the user sees them
   - From navigation bar to tab bar
   - Real sample data throughout
   - Default state with at least one expanded/active section
   - Legend explaining visual conventions (icons, stripes, indicators)
   - This is the "hero" visual — the design at a glance

3. Present all three to the user for approval

**Output:** Wireframes embedded in ux-spec.md (Sections 2 and 3), or presented inline in chat if run standalone.

### `/ux validate {feature}`

**Purpose:** Validate an existing UX spec or implementation against principles.

**Steps:**
1. Read the feature's ux-spec.md (or code if already implemented)
2. **Heuristic evaluation** — score against Nielsen's 10 usability heuristics (0-4 scale):
   - Visibility of system status
   - Match between system and real world
   - User control and freedom
   - Consistency and standards
   - Error prevention
   - Recognition rather than recall
   - Flexibility and efficiency of use
   - Aesthetic and minimalist design
   - Help users recognize, diagnose, recover from errors
   - Help and documentation
3. **Principle compliance** — check all 13 principles, flag violations
4. **State coverage** — are all states defined? (empty, loading, error, success)
5. **Accessibility check** — labels, tap targets, Dynamic Type, VoiceOver
6. **CX signal cross-reference** — do any cx-signals.json entries indicate UX problems in this area?

**Output:** Validation report with pass/fail per heuristic and principle, severity ratings, fix recommendations.

### `/ux preflight {feature}`

**Purpose:** Pre-Phase-4 gate — verify the spec's named tokens, components, and patterns actually exist in the codebase BEFORE any code is written. Catches the silent-pass error where a spec invokes `AppRadius.pill` (doesn't exist) or `SettingsActionLabel` with a custom badge slot (component doesn't accept it). Pairs with `/design preflight` (which adds the Figma MCP + library check).

**Trigger:** Auto-dispatched by `/pm-workflow` after `/ux spec` lands but before Phase 3 approval. Also invokable standalone.

**Steps:**
1. Read `.claude/features/{feature}/ux-spec.md`
2. Extract every token reference (`AppColor.*`, `AppText.*`, `AppSpacing.*`, `AppRadius.*`, `AppMotion.*`, `AppEasing.*`, `AppDuration.*`, `AppSpring.*`, `AppShadow.*`, `AppSize.*`, `AppGradient.*`)
3. Extract every component reference (`Settings*`, `App*Card`, custom-named SwiftUI structs)
4. Extract every interaction pattern (`.swipeActions`, `.contextMenu`, `.alert`, `.confirmationDialog`, custom toast/snackbar names)
5. **For each token:** grep `FitTracker/Services/AppTheme.swift` and `FitTracker/DesignSystem/`. If absent → P0 finding.
6. **For each component:** grep `FitTracker/Views/` and `FitTracker/DesignSystem/`. If absent OR signature doesn't accept what the spec asks for → P0 finding.
7. **For each pattern:** grep the codebase for any usage. If absent → P2 finding (new-to-codebase, document as design-system evolution; not blocking).
8. Append a record to `.claude/cache/_shared/ux-spec-preflight.json`:
   ```json
   {
     "feature": "{feature}",
     "spec_path": "...",
     "checked_at": "{ISO 8601}",
     "tokens_referenced": [...],
     "components_referenced": [...],
     "patterns_referenced": [...],
     "findings": { "p0": [...], "p1": [...], "p2": [...] }
   }
   ```
9. Write a human-readable audit at `.claude/features/{feature}/ux-preflight-audit-{date}.md`
10. Return findings to the user.

**Gate behavior:**
- **P0 unresolved → spec is NOT approvable.** User must fix the spec OR add the missing token/component to the design system on this feature's branch (per CLAUDE.md design-system evolution rule).
- **P2 net-new patterns** are surfaced for documentation in `docs/design-system/feature-memory.md` but don't block.

**Output:** `.claude/features/{feature}/ux-preflight-audit-{date}.md` + `.claude/cache/_shared/ux-spec-preflight.json` entry.

**Self-test fixtures (P1.3, shipped 2026-05-14):** [`.claude/skills/ux/fixtures/`](fixtures/) holds canonical regression test cases for the symbol-existence check. Driver: [`scripts/preflight-fixture-test.py`](../../../scripts/preflight-fixture-test.py); invocation: `make preflight-fixture-test`. The `valid-*.md` fixtures cite only real codebase tokens (expected: 0 P0); the `invalid-*.md` fixtures cite a known-missing sentinel (expected: ≥1 P0). When the token-extraction regex or grep-target paths in this section change, update the fixtures + golden alignment to match. Wired into `make integrity-check` as an advisory tail-check.

### `/ux pre-merge-review {feature}`

**Purpose:** Phase 6 (Review) UI-specific layer — heuristic re-check of the SHIPPED implementation against the original `ux-spec.md`. Catches drift where the code mostly matches the spec but key UX decisions silently shifted during implementation. Pairs with `/design pre-merge-review` (token compliance + Figma node ID validation).

**Trigger:** Auto-dispatched by `/pm-workflow` Phase 6, after Phase 5 (Testing) approval but before Phase 7 (Merge). Also invokable standalone.

**Prerequisites:**
- `state.json.phases.testing.status == "approved"`
- `ux-spec.md` exists and was approved
- A feature branch exists with the implementation

**Steps:**
1. Read `.claude/features/{feature}/ux-spec.md` (the approved contract)
2. For each surface in the spec, locate the corresponding view file via `state.json.v2_file_path` or grep for the Swift type name
3. Walk the spec's UX heuristic checklist (13 ux-foundations principles) against the actual implementation
4. **Spot-check the persistence claims** — if the spec names a file:line touch point ("`EncryptionService.swift:779`"), open that line and verify the change matches
5. **Spot-check the analytics events** — for each event listed in the spec, grep the implementation to confirm `analytics.log{Event}(...)` is wired
6. Heuristic re-check:
   - Fitts/Hick/Jakob compliance still holds
   - All 5 states (default/loading/empty/error/success) covered in code
   - VoiceOver labels present where spec required
   - Reduce-motion alternatives present
7. Write a review at `.claude/features/{feature}/ux-pre-merge-review-{date}.md` with: spec-vs-code matrix; drift findings; verdict (PASS / PASS_WITH_NOTES / BLOCK)
8. **Sub-step 6f (T21, framework-v7-8-branch-isolation, advisory in v7.8 → enforced in v7.9):** kill_criteria_resolution check. Read the linked case study at `state.json.case_study`. Parse its frontmatter. If `kill_criteria` is non-empty, verify `kill_criteria_resolution` is non-empty AND substantively addresses each kill threshold (heuristic: mentions at least one of the listed kill thresholds verbatim OR contains acceptance keywords like "not tripped", "deferred", "superseded", "passed"). If kill_criteria is empty, skip. Failure → set `state.json.pre_merge_review.ux = "blocked"` with `block_reason: "kill_criteria_resolution missing or non-substantive"`. Per `framework-v7-8-branch-isolation/integration-spec.md` §2.2.
9. Set `state.json.pre_merge_review.ux = "passed"` (or "blocked")

**Gate behavior:**
- **BLOCK verdict → Phase 7 (Merge) is NOT approvable.** User must fix the drift OR re-approve the spec to match shipped code (the latter requires PRD addendum).
- **PASS_WITH_NOTES** is allowed; notes appear in PR description.

**Output:** `.claude/features/{feature}/ux-pre-merge-review-{date}.md` + `state.json.pre_merge_review.ux` field.

### `/ux audit`

**Purpose:** Walk a v1 surface (or the whole app) against `ux-foundations.md` and produce a severity-graded findings list. This is the primary Phase 0 output for v2 refactors per the V2 Rule in `CLAUDE.md`.

**Two invocation modes:**

| Mode | Trigger | Input | Output |
|---|---|---|---|
| **V2 refactor audit** | PM workflow Phase 0 with `state.json.work_subtype == "v2_refactor"` | One v1 Swift file (e.g. `FitTracker/Views/Main/MainScreenView.swift`) | `.claude/features/{feature}/v2-audit-report.md` with numbered findings |
| **App-wide audit** | Standalone `/ux audit` | All view files under `FitTracker/Views/` | Audit report (no file written unless user asks) |

**Steps (v2 refactor mode):**

1. Read the target v1 Swift file end-to-end. Note line counts, private
   functions, private types, modifiers, and state.
2. Read the feature's PRD from `docs/product/prd/` if it exists.
3. Read `docs/design-system/ux-foundations.md` in full (Parts 1-8 are all
   relevant to a UI audit).
4. Read `docs/design-system/v2-refactor-checklist.md` — Sections A / C / E
   / F / G / H are the finding framework.
5. **Walk the 13 UX Foundations principles** (8 core + 5 FitMe-specific).
   For each principle that applies, document whether the v1 file honors
   it, partially honors it, or violates it.
6. **Walk the 5 states** (default / loading / empty / error / success) for
   every screen in scope. Missing states are findings.
7. **Count raw literals:**
   - `.font(.system(size: ...))` outside `// DS-exception:` comments
   - `.padding(...)` with numeric literals
   - `.frame(width:/height:)` with numeric literals
   - Raw `.spring(...)` / `.easeInOut(...)` / `.easeOut(...)` calls
   - Hardcoded `Color(...)` literals
   - Every count becomes a finding under Section C (token compliance).
8. **Count accessibility labels:** grep `accessibilityLabel` and
   `accessibilityHint`. If the count is << the number of interactive
   elements, that's a P0 finding under Section G.
9. **Check layout architecture** — root-level `GeometryReader`, inline
   responsive sizing via `compact`/`tight` props, unused existing
   components, private types that should live in `DesignSystem/`.
10. **Cross-reference `.claude/shared/cx-signals.json`** for any
    user-reported confusion about this surface.

**Finding format:**

Each finding in `v2-audit-report.md` gets:

```
### F{n} — {short title}
- Severity: P0 | P1 | P2
- Tractability: auto-applicable | needs-decision | needs-new-token | needs-new-component
- Principle / checklist section: {e.g. "1.9 Readiness-First" or "Section G1"}
- Location: {file:line}
- Description: {what the v1 code does and why it's wrong}
- Recommendation: {what the v2 code should do}
```

**Severity definitions:**
- **P0** — blocks v2 ship (foundational principle violation, missing
  critical state, broken accessibility baseline)
- **P1** — should fix in v2 (token drift, minor principle miss,
  inconsistent pattern with other screens)
- **P2** — nice-to-have, can defer to follow-up (polish, edge cases,
  optional enhancements)

**Tractability definitions:**
- **auto-applicable** — can be fixed mechanically without a product
  decision (raw literal → token, missing accessibility label, wrong
  animation easing)
- **needs-decision** — requires the user to choose between options
  (remove a feature vs evolve it, which pattern to use)
- **needs-new-token** — the fix requires a new semantic token in
  `AppTheme.swift`
- **needs-new-component** — the fix requires a new shared component in
  `DesignSystem/`

**Output (v2 mode):** `.claude/features/{feature}/v2-audit-report.md`

**Steps (app-wide mode):** Same process but across all view files, without writing a per-feature file. Output goes to the session chat as a summary.

### `/ux patterns`

**Purpose:** Quick reference to the UX pattern library.

**Steps:**
1. Read `docs/design-system/ux-foundations.md`
2. Present a summary organized by category:
   - Navigation patterns
   - Input patterns
   - Feedback patterns
   - Data visualization patterns
   - Permission patterns
   - State patterns
   - Accessibility patterns
3. For each pattern: when to use, FitMe example, reference to ux-foundations.md section

**Output:** Formatted pattern reference.

### `/ux prompt {feature}`

**Purpose:** Auto-generate a handoff prompt for another agent (typically a Figma MCP agent or an implementation agent) once Phase 3 UX work is approved. The prompt bundles everything the receiving agent needs: user flows, principle application, state coverage, accessibility requirements, and references to the design system. No manual prompt writing.

**Prerequisites:**
- `.claude/features/{feature}/ux-research.md` exists and is approved
- `.claude/features/{feature}/ux-spec.md` exists and is approved
- Phase 3 design system compliance gateway passed
- For v2 refactors: `.claude/features/{feature}/v2-audit-report.md` exists

**Steps:**
1. Read `ux-research.md`, `ux-spec.md`, and (if v2) `v2-audit-report.md`
2. Read `state.json` to pull `work_subtype`, `v1_file_path`, `v2_file_path`, Figma node IDs, and acceptance criteria
3. Read the relevant sections of `ux-foundations.md` cited in the spec
4. Assemble a single prompt file with:
   - **Header** — feature name, work subtype, target agent (Figma MCP / SwiftUI implementation / etc.), date, related GitHub issue
   - **Context** — one-paragraph product framing from PRD
   - **What to build** — screen inventory with wireframes or Figma node references
   - **UX principles applied** — the Principle Application Table from the spec, copied verbatim
   - **State coverage** — default / loading / empty / error / success for each screen
   - **Accessibility requirements** — VoiceOver labels, tap targets, Dynamic Type, reduce-motion
   - **Handoff checklist** — what the receiving agent should produce and return
   - **References** — paths to ux-spec, ux-research, audit report, ux-foundations, design-system.json
5. **Write the prompt** to `docs/prompts/ux/{YYYY-MM-DD}-{feature}-ux-build.md` (folder split established 2026-05-06: UX prompts land in `docs/prompts/ux/`, design/UI prompts land in `docs/prompts/ui/`, legacy flat files migrated to `docs/prompts/_legacy/`)
6. Announce: "UX handoff prompt written to `docs/prompts/ux/…`. Ready to transfer to the receiving agent."

**Output:** `docs/prompts/ux/{YYYY-MM-DD}-{feature}-ux-build.md`

**When to run:** Automatically dispatched by `/pm-workflow` after Phase 3 approval when `state.json.phases.ux_or_integration.status == "approved"`. Also invokable standalone when the spec is done but the hub wasn't running it.

**Paired with:** `/design prompt {feature}` — `/ux` writes the what-and-why prompt, `/design` writes the how-it-looks prompt. Both land in `docs/prompts/` with matching filename prefixes so the receiving agent can read them together.

## PM Workflow Integration

| PM Phase | Sub-command | When | Work subtype |
|---|---|---|---|
| **Phase 0 (Research)** — v2 refactor only | `/ux audit {feature}` | First step of a v2 refactor — produces `v2-audit-report.md` as the gap-analysis driver | `v2_refactor` |
| **Phase 0 (Research)** — new feature | `/ux research {feature}` | After competitive research, before PRD | `new_ui` |
| **Phase 3 (UX Definition)** | `/ux research {feature}` → `/ux spec {feature}` → `/ux validate {feature}` → **`/ux preflight {feature}` (P0 gate)** → `/ux prompt {feature}` | After PRD approved, before Phase 4 code | both |
| **Phase 5 (Testing)** | `/ux validate {feature}` | Post-implementation verification | both |
| **Phase 6 (Review)** | **`/ux pre-merge-review {feature}` (gate)** | Heuristic re-check of shipped code vs spec; runs alongside `/design pre-merge-review` | both |
| **Post-Launch** | `/ux audit` (app-wide) | When CX signals indicate UX issues | — |

### Phase 3 Choreography

The full Phase 3 handoff differs by work subtype:

**New UI feature (`new_ui`):**
1. `/ux research {feature}` → produces `ux-research.md`
2. `/ux spec {feature}` → produces `ux-spec.md` (with Principle Application Table and all 5 states covered)
3. `/ux validate {feature}` → heuristic evaluation, flags violations
4. **`/ux preflight {feature}` → P0 gate: token/component/pattern existence check. Spec is NOT approvable with unresolved P0**
5. **`/design preflight {feature}` → P0 gate: DS compliance + Figma MCP liveness + Figma library accessibility check**
6. `/design audit` → validates against design system (tokens, components, motion)
7. `/ux prompt {feature}` → handoff prompt to `docs/prompts/ux/`
8. `/design prompt {feature}` → handoff prompt to `docs/prompts/ui/`
9. **`/design build {feature}` → builds Figma screens via MCP (or persists prompt for manual handoff if MCP unreachable). Writes Figma node IDs back to `state.json.figma_node_ids` and `figma-code-sync-status.md`**
10. User approval → proceed to Phase 4 (Implementation)

**V2 refactor (`v2_refactor`):**
1. `/ux audit {feature}` (from Phase 0) → `v2-audit-report.md` is already in place
2. `/ux research {feature}` → consolidates audit findings into the 13 ux-foundations principles (`ux-research.md`)
3. `/ux spec {feature}` → `ux-spec.md` is written **for the v2 file**, using the audit findings as the gap list. Every P0/P1 finding must have a resolution in the spec (fix / evolve DS / override with justification)
4. `/ux validate {feature}` → heuristic re-check of the v2 spec
5. **`/ux preflight {feature}` → P0 gate (same as new_ui)**
6. **`/design preflight {feature}` → P0 gate (same as new_ui)**
7. `/design audit` → design system compliance gateway
8. Tick Section A of `docs/design-system/v2-refactor-checklist.md`
9. `/ux prompt {feature}` → `docs/prompts/ux/`
10. `/design prompt {feature}` → `docs/prompts/ui/`
11. `/design build {feature}` → Figma update reflecting v2 file changes
12. User approval → proceed to Phase 4 (build the v2 file in the `v2/` subdirectory per the V2 Rule in `CLAUDE.md`)

### Phase 6 Choreography (UI-specific layer added v4.X)

Phase 6 was a generic code-review step before the v4.X skill upgrade. It now adds a UI-specific layer that runs in parallel with the generic review:

1. **`/dev review`** (existing) — diff main…feature, risk surface, high-risk areas
2. **`/ux pre-merge-review {feature}`** (new) — heuristic re-check of shipped code vs `ux-spec.md`; spot-checks file:line touch points named in the spec; verifies all 5 states covered; verdict PASS / PASS_WITH_NOTES / BLOCK
3. **`/design pre-merge-review {feature}`** (new) — `make ui-audit` clean (P0=0); Figma node IDs present in `state.json.figma_node_ids`; PR description references those node IDs; screenshot diff Figma↔code (manual or auto via MCP)
4. Phase 7 (Merge) is NOT approvable until `state.json.pre_merge_review.ux == "passed"` AND `state.json.pre_merge_review.design == "passed"` (or "passed_with_notes")

## Key References

| Document | Purpose |
|----------|---------|
| `docs/design-system/ux-foundations.md` | Complete UX pattern library (13 principles + 10 parts) |
| `docs/design-system/v2-refactor-checklist.md` | Phase 3-5 checklist — `/ux` owns Sections A, E, F, G, H |
| `docs/design-system/ux-copy-guidelines.md` | Tone, voice, terminology |
| `docs/design-system/feature-development-gateway.md` | 7-stage development workflow |
| `docs/design-system/feature-design-checklist.md` | Pre-implementation validation |
| `docs/design-system/component-contracts.md` | Component interaction behavior |
| `docs/design-system/responsive-handoff-rules.md` | Responsive design contract |
| `CLAUDE.md` — "UI Refactoring & V2 Rule" | V2 file convention (`v2/` subdirectory + pbxproj surgery) |
| `.claude/features/{feature}/ux-research.md` | Per-feature UX research (from `/ux research`) |
| `.claude/features/{feature}/ux-spec.md` | Per-feature UX specification (from `/ux spec`) |
| `.claude/features/{feature}/v2-audit-report.md` | Per-feature v2 gap analysis (from `/ux audit` in v2 mode) |

---

## External Data Sources

| Adapter | Type | What It Provides |
|---------|------|-----------------|
| axe | MCP | Live accessibility audits, WCAG compliance scores, violation details |

**Adapter location:** `.claude/integrations/axe/`
**Shared layer writes:** `design-system.json`

### Validation Gate

All incoming a11y data passes through automatic validation before entering the shared layer:
- Score >= 95% GREEN: Data is clean. Write to shared layer. Notify /ux + /pm-workflow.
- Score 90-95% ORANGE: Minor discrepancies. Write + advisory. Review when convenient.
- Score < 90% RED: DO NOT write. Alert /ux + /pm-workflow. User must resolve.

Validation is automatic. Resolution is always manual.

## Research Scope (Phase 2)

When the cache doesn't have an answer for a UX task, research:

1. **UX principles** — which of the 13 ux-foundations.md principles apply, how they've been applied before
2. **Accessibility** — WCAG AA requirements, VoiceOver patterns, Dynamic Type compliance, axe audit results
3. **Spec patterns** — how similar features were specced, wireframe conventions, principle application tables
4. **Tools & APIs** — Axe MCP for live a11y audits, Figma MCP for design context, platform HIG references
5. **Interaction patterns** — gesture conventions, navigation patterns, state coverage (5 states), motion tokens

Sources checked in order: L1 cache → L2 shared (ux-foundations-map) → shared layer (design-system.json, context.json) → integration adapters (axe) → codebase (ux-foundations.md) → external docs

## Cache Protocol

**Phase 1 (Cache Check):** Read `.claude/cache/ux/_index.json`. Check for cached UX spec patterns, wireframe templates, a11y audit outcomes from prior features. Also read `.claude/cache/_shared/ux-foundations-map.json` for the cross-skill UX foundations application playbook.

**Phase 4 (Learn):** Extract new patterns (spec structure, principle application, a11y findings). Write/update L1 cache. UX foundations patterns shared with /design should be promoted to L2.

**Cache location:** `.claude/cache/ux/`

---

## Cache Protocol

### Phase 1 — Cache Check (on skill start)
Read `.claude/cache/ux/_index.json`, match `v2_screen_audit`, check L2 `ux-foundations-map.json`. If hit: load patterns, skip principle derivation. If miss: Phase 2.

### Phase 4 — Learn (on skill complete)
Extract new principle mappings, anti-patterns. Write L1. If pattern applies to /design or /qa, flag L2.

### Health Check (Phase 0 — random trigger)
On skill start, before cache check:
1. Read `.claude/shared/framework-health.json`
2. If `random() < 0.25` AND `hours_since(last_check) > 2`: run 5 health checks, compute weighted score, append to history
3. If score < 0.90: STOP and alert user with failing checks and rollback options
4. Proceed to Phase 1 (Cache Check)

## External Data Sources

| Adapter | Location | Shared Layer Target | When to Pull |
|---------|----------|-------------------|--------------|
| axe | `.claude/integrations/axe/` | design-system.json, test-coverage.json | On `/ux validate` or `/ux audit` |

**Fallback:** If adapter unavailable, continue with existing shared data. Log to change-log.json.

## Research Scope (Phase 2 — when cache misses)

1. UX principles from ux-foundations.md
2. Apple HIG patterns
3. Competitor UX from /research cache
4. Accessibility heuristics (WCAG AA + cognitive)
5. State coverage (empty/loading/error/success)

**Source priority:** L2 cache > L1 cache > shared layer (cx-signals.json, design-system.json) > axe adapter > manual derivation


## Anti-patterns

Hard-won mistakes for `/ux` work. Every bullet encodes a real or near-miss failure mode.

- Do not advance Phase 3 without `/ux preflight` passing — it verifies every token/component/pattern named in `ux-spec.md` exists in the codebase (saves 2-4h of 'no such symbol' Phase 4 rework per feature on average)
- Do not approve a UX spec that doesn't reference real codebase symbols — fictional symbols are the #1 source of Phase 4 rework
- Do not skip the 13 UX principle validation (8 core + 5 FitMe-specific) on a UX spec — they are the foundation for every Phase 4 decision
- Do not advance Phase 6 without `/ux pre-merge-review` recording `kill_criteria_resolution` when `kill_criteria` is set in state.json (pattern #6 `FEATURE_CLOSURE_COMPLETENESS`)
- Do not treat `/ux preflight` as final approval — it is one of several Phase 3 gates (multi-part approval — pattern W7)
