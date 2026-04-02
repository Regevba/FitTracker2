---
name: pm-workflow
description: "Start or resume a product management lifecycle for a feature. Orchestrates: Research → PRD → Tasks → UX/Integration → Code → Test → Review → Merge → Docs. Invoke with /pm-workflow {feature-name}."
---

# Product Management Lifecycle: $ARGUMENTS

You are orchestrating the feature **"$ARGUMENTS"** through the complete product management lifecycle. Every phase requires explicit user approval before proceeding to the next.

## Setup

1. Check if `.claude/features/$0/state.json` exists
   - If yes: resume from `current_phase`
   - If no: create the directory and initialize state.json from the schema below

2. Read the current state and announce: "Feature **$0** — currently in Phase {N}: {name}. Here's what needs to happen next."

3. **GitHub Issue sync check:**
   - If `github_issue_number` is set in state.json: verify the issue exists and check its `phase:*` label
   - If no `github_issue_number`: search GitHub Issues for this feature by title. If found, store the number. If not found, offer to create one.
   - If state.json `current_phase` doesn't match the GitHub Issue's `phase:*` label: ask the user which source is correct and reconcile (see Conflict Resolution in Dashboard Sync Automation)

4. If the user says "Move to {phase}" or "Roll back to {phase}": execute the Manual Override procedure (see Dashboard Sync Automation) instead of the normal phase workflow.

## State Initialization

Create `.claude/features/$0/state.json`:
```json
{
  "feature": "$0",
  "created": "{current ISO-8601 timestamp}",
  "updated": "{current ISO-8601 timestamp}",
  "branch": "feature/$0",
  "current_phase": "research",
  "has_ui": null,
  "phases": {
    "research": { "status": "in_progress", "approved_at": null, "sources": [] },
    "prd": { "status": "pending", "approved_at": null },
    "tasks": { "status": "pending", "count": 0 },
    "ux_or_integration": { "status": "pending", "type": null },
    "implementation": { "status": "pending", "commits": [] },
    "testing": { "status": "pending", "ci_passed": false, "tests_added": 0, "instrumentation_verified": false },
    "review": { "status": "pending", "risks": [], "ci_main": false, "ci_feature": false },
    "merge": { "status": "pending", "pr_number": null },
    "documentation": { "status": "pending" },
    "metrics": {
      "primary": { "name": "", "baseline": null, "target": null, "current": null },
      "secondary": [],
      "guardrails": [],
      "instrumentation_ready": false,
      "first_review_date": null,
      "kill_criteria": ""
    }
  }
}
```

---

## Phase 0: Research & Discovery

**Goal:** Understand what we're building, why, and validate the approach before committing to a PRD.

Create `.claude/features/$0/research.md` using the research template. Fill in:

1. **What is this solution?** — Plain-language description
2. **Why this approach?** — Problem it solves, user pain points addressed
3. **Why this over alternatives?** — Research 2-3 alternative approaches. Create a comparison table:
   | Approach | Pros | Cons | Effort | Chosen? |
   |----------|------|------|--------|---------|
4. **External sources** — Search for relevant articles, documentation, APIs, libraries. Include links.
5. **Market examples** — How do competitors or other apps solve this? Include app names and what they do well/poorly.
6. **If this feature has UI:**
   - Search for design inspiration — find 3-5 examples of similar UI patterns you'd recommend
   - Document design solutions that could work (with reasoning)
   - Note visual references and mood (colors, layout patterns, interaction models)
   - Link to any Figma exploration
7. **Data & demand signals** — What data justifies building this? (user feedback, analytics, market size, support requests)
8. **Technical feasibility** — Dependencies, risks, unknowns, platform constraints
9. **Proposed success metrics** — Draft the primary metric and 2-3 secondary metrics
10. **Decision** — Recommended approach with rationale

Present the research to the user and ask for approval. **On approval, execute the Phase Transition Procedure (see Dashboard Sync Automation).**

---

## Phase 1: PRD

**Goal:** Define exactly what we're building with measurable success criteria.

Create `.claude/features/$0/prd.md` using the PRD template (see prd-template.md). Every field is mandatory.

**Critical:** The success metrics section is NON-NEGOTIABLE. No PRD is approved without:
- Primary metric with baseline and target
- Secondary metrics (2-3)
- Guardrail metrics (things that must not degrade)
- Leading indicators (measurable within 1 week)
- Lagging indicators (30/60/90 day impact)
- Instrumentation plan (how we measure)
- Review cadence
- Kill criteria

Ask the user: "Does this feature have a UI component?" → Set `has_ui` in state.json.

Present the PRD and ask for approval. **On approval, execute the Phase Transition Procedure.**

---

## Phase 2: Task Breakdown

**Goal:** Divide the PRD into implementable subtasks.

Create `.claude/features/$0/tasks.md` with:
1. Read the approved PRD
2. Break into subtasks, each with: title, description, estimated effort, dependencies
3. Classify each task: `ui`, `backend`, `data`, `test`, `docs`, `infra`
4. Order by dependency graph
5. Estimate total effort

Present task list and ask for approval. **On approval, execute the Phase Transition Procedure.**

---

## Phase 3: UX/UI Definition (if has_ui = true)

**Goal:** Define screens, components, and design requirements before coding — grounded in UX research and validated against the design system.

### Step 1: UX Research & Principles

Before designing screens, research and document UX best practices relevant to this feature:

1. **UX principles applicable to this feature** — identify which core principles apply:
   - Fitts's Law (target size and distance for tap targets)
   - Hick's Law (minimize choices per screen)
   - Jakob's Law (users expect your app to work like others they know)
   - Progressive disclosure (show only what's needed at each step)
   - Recognition over recall (visible options vs memorized commands)
   - Consistency (internal consistency with FitMe, external with iOS conventions)
   - Feedback (every action gets a response)
   - Error prevention (design to prevent mistakes, not just handle them)

2. **iOS Human Interface Guidelines** — check Apple's HIG for relevant patterns:
   - Navigation patterns (push, modal, tab, sheet)
   - Input patterns (forms, pickers, steppers, sliders)
   - Feedback patterns (haptics, animations, alerts)
   - Accessibility requirements (Dynamic Type, VoiceOver, minimum tap targets 44pt)

3. **UX best practices for this feature type** — search for research and articles on the specific interaction pattern (e.g., "best practices for food logging UX", "training timer UI patterns")

4. **Document findings** in `.claude/features/$0/ux-research.md`:
   - Applicable principles and how they apply
   - iOS HIG references
   - External UX research sources with links
   - Recommended patterns based on research

### Step 2: Design Definition

Follow the Feature Development Gateway at `docs/design-system/feature-development-gateway.md`:
1. Problem framing (already done in PRD)
2. Behavior definition: entry points, primary task flow, edge cases, states (empty/loading/error/success)
3. Screen list with wireframe descriptions
4. Component inventory (reuse existing AppComponents where possible — check `FitTracker/DesignSystem/AppComponents.swift`)
5. Design token requirements (map to existing `AppTheme.swift` tokens; flag any new primitives needed)
6. User interaction flows
7. Accessibility requirements (informed by UX research from Step 1)
8. Reference the design inspiration from Phase 0 research
9. Reference the UX principles from Step 1 — explain HOW each principle influenced the design

Also walk through `docs/design-system/feature-design-checklist.md` for every UI decision.

Create `.claude/features/$0/ux-spec.md` with the above.

### Step 3: Design System Compliance Gateway

**Before approval, validate the design against the design system.**

Run a compliance check on the UX spec:

1. **Token compliance** — Every color, font, spacing, and radius value maps to an existing semantic token in `AppTheme.swift`. Flag any raw/hardcoded values.
2. **Component reuse** — Every UI element maps to an existing component in `AppComponents.swift` or has a documented reason for a new component.
3. **Pattern consistency** — Navigation, layout, and interaction patterns are consistent with existing screens (check `docs/design-system/component-contracts.md`).
4. **Accessibility compliance** — Minimum 44pt tap targets, WCAG AA contrast (4.5:1 text), Dynamic Type support, VoiceOver labels defined.
5. **Motion compliance** — Animations use `AppMotion` presets, reduce-motion support via `MotionSafe` modifier.

**Generate a compliance report:**

| Check | Status | Details |
|-------|--------|---------|
| Token compliance | Pass/Fail | {list any violations} |
| Component reuse | Pass/Fail | {new components needed?} |
| Pattern consistency | Pass/Fail | {deviations from existing patterns} |
| Accessibility | Pass/Fail | {issues found} |
| Motion | Pass/Fail | {non-standard animations?} |

**If all checks pass:** Present the UX spec for approval.

**If any checks fail:** Alert the user with the compliance report and present three options:

> **Design System Compliance Alert**
>
> The UX spec has {N} design system violations:
> {list violations}
>
> Since this feature is on its own branch, you have full flexibility:
>
> 1. **Fix violations** — Update the UX spec to comply with the current design system
> 2. **Evolve the design system** — The design system is a living framework. If these changes improve it, update the tokens/components as part of this feature. Document the evolution in `docs/design-system/feature-memory.md`
> 3. **Override with justification** — Proceed with the violations, documenting why the design system doesn't apply here (edge case, experimental, etc.)
>
> The design system should serve the product, not constrain it. Choose the path that makes the best product.

Record the user's decision in state.json under `ux_or_integration.compliance_decision`.

**Design system evolution rules:**
- New tokens/components proposed by a feature are added on the feature branch
- They are reviewed alongside the feature code in Phase 6
- If approved, they become part of the design system when the feature merges to main
- Update `docs/design-system/feature-memory.md` with what changed and why
- Run `make tokens-check` to verify token pipeline still passes

Present UX spec + compliance report and ask for approval. **On approval, execute the Phase Transition Procedure.**

## Phase 3b: Integration Requirements (if has_ui = false)

**Goal:** Define technical contracts and integration points.

Create `.claude/features/$0/integration-spec.md` with:
1. API contracts (endpoints, payloads, auth)
2. Data model changes (new models, migrations)
3. Service dependencies
4. Error handling strategy
5. Backward compatibility plan

Present spec and ask for approval. **On approval, execute the Phase Transition Procedure.**

---

## Phase 4: Branch & Implement

**Goal:** Write the code on an isolated branch.

1. Create branch: `git checkout -b feature/$0 main`
2. Implement according to the approved task list
3. Commit incrementally with descriptive messages
4. Update state.json with commit hashes
5. Follow the branching rules:
   - Features touching >5 files OR adding new models/services → MUST use `feature/{name}` branch
   - Both the feature branch and main must remain CI-green

Present implementation summary and ask for approval. **On approval, execute the Phase Transition Procedure.**

---

## Phase 5: Testing & Measurement

**Goal:** Verify the implementation works and metrics are instrumented.

1. Write unit tests for new functionality
2. Run the full CI suite: `make tokens-check && xcodebuild build && xcodebuild test`
3. Run regression check (existing tests still pass)
4. **Verify metric instrumentation is in place** — can we actually measure the success metrics defined in the PRD?
5. **Record baseline values** for all metrics before the feature is live
6. Update state.json: `ci_passed`, `tests_added`, `instrumentation_verified`

If CI fails, fix and re-run. Do NOT proceed until CI is green.

Present test results and ask for approval. **On approval, execute the Phase Transition Procedure.**

---

## Phase 6: Code Review

**Goal:** Parallel review of feature branch vs main to assess risk.

1. Generate diff: `git diff main...feature/$0 --stat`
2. Identify high-risk areas:
   - Changes to models (DomainModels.swift)
   - Changes to encryption (EncryptionService.swift)
   - Changes to sync (SupabaseSyncService.swift, CloudKitSyncService.swift)
   - Changes to auth (SignInService.swift, AuthManager.swift)
   - Changes to AI (AIOrchestrator.swift)
3. Verify CI passes on BOTH branches:
   - Feature branch: green
   - Main branch: green
4. List risks and mitigations

Present review and ask for approval. **On approval, execute the Phase Transition Procedure.**

---

## Phase 7: Merge

**Goal:** Merge the feature to main cleanly.

1. Create PR with title: `feat($0): {one-line description}`
2. PR body: link to PRD, task list, test results, risk assessment
3. Squash merge to main
4. Delete feature branch
5. Update state.json: `pr_number`

---

## Phase 8: Documentation & Metrics

**Goal:** Close the loop with documentation and metric baselines.

1. Update the feature PRD with final implementation state
2. Record baseline metric values in state.json
3. Set first review date (based on review cadence from PRD)
4. Update CHANGELOG.md with the feature
5. Update docs/product/backlog.md (move from Planned → Done)
6. Archive: move state.json `current_phase` to `complete`

Announce: "Feature **$0** is complete. First metrics review scheduled for {date}."

---

## Post-Launch: Metrics Review

When the review cadence date arrives:
1. Read state.json metrics
2. Compare current values against baseline and target
3. Check kill criteria
4. Report: keep / iterate / kill recommendation

---

## Rules

- **No phase is skipped by default.** The automated workflow enforces sequential gates. Manual overrides are allowed — skipped phases are marked as "skipped" with a reason in the audit trail. The user always has final authority.
- **No PRD without metrics.** Every feature must define how success is measured.
- **No merge without CI.** Both feature branch and main must be green.
- **Data drives decisions.** Research, metrics, and kill criteria guide the lifecycle.
- **User approves every gate.** No autonomous phase transitions.

---

## Dashboard Sync Automation

### How Phase Transitions Work

When a phase is approved and the feature moves to the next phase, **three things happen automatically:**

1. **state.json updates** — `current_phase` advances, previous phase gets `status: "approved"` + timestamp
2. **GitHub Issue label updates** — the feature's GitHub Issue gets its `phase:*` label swapped (e.g., `phase:prd` → `phase:tasks`)
3. **Transition log entry** — a timestamped record is appended to the `transitions` array in state.json

### Phase Transition Procedure

On every phase approval, execute this procedure:

```
1. Read current state.json
2. Record the transition:
   - Set phases.{current_phase}.status = "approved"
   - Set phases.{current_phase}.approved_at = current timestamp
   - Determine next_phase from the phase order (see below)
   - Set current_phase = next_phase
   - Set phases.{next_phase}.status = "in_progress"
   - Set updated = current timestamp
   - Append to transitions array: { from, to, timestamp, approved_by: "user" }
3. Write updated state.json
4. Sync to GitHub Issue (if GitHub MCP tools are available):
   - Find the issue for this feature (by title match or issue number in state.json)
   - Remove old phase label (e.g., `phase:prd`)
   - Add new phase label (e.g., `phase:tasks`)
   - Add a comment: "Phase transition: {from} → {to} (approved {timestamp})"
5. Announce: "✓ Phase {from} approved. Moving to Phase {next}: {description}."
```

### Phase Order

The canonical phase sequence is:

```
research → prd → tasks → ux (if has_ui) → implement → testing → review → merge → docs → complete
                          └→ integration (if !has_ui) ─┘
```

Index mapping for ordering:
| Index | Phase | Label |
|-------|-------|-------|
| 0 | research | `phase:research` |
| 1 | prd | `phase:prd` |
| 2 | tasks | `phase:tasks` |
| 3 | ux / integration | `phase:ux` or `phase:integration` |
| 4 | implement | `phase:implement` |
| 5 | testing | `phase:testing` |
| 6 | review | `phase:review` |
| 7 | merge | `phase:merge` |
| 8 | docs | `phase:docs` |
| 9 | complete | `phase:done` |

### Manual Override: Moving Forward or Backward

The user can manually move a feature to any phase at any time. This supports:
- **Skipping ahead** (e.g., a hotfix doesn't need UX research)
- **Rolling back** (e.g., implementation revealed the PRD was wrong, go back to PRD)
- **Dashboard drag-drop** (user drags a card to a different column)

**To manually override via the skill:**
```
/pm-workflow {feature-name}
```
Then tell Claude: "Move this feature to {phase}" or "Roll back to {phase}".

**Manual override procedure:**
```
1. Read current state.json
2. Validate the target phase exists in the phase order
3. If moving BACKWARD:
   - Set all phases between target and current back to "pending"
   - Set target phase to "in_progress"
   - Log transition with approved_by: "user-manual"
   - Warn: "Rolling back to {phase}. Phases {list} have been reset to pending."
4. If moving FORWARD (skipping phases):
   - Set all skipped phases to "skipped" with reason: "manual-override"
   - Set target phase to "in_progress"
   - Log transition with approved_by: "user-manual"
   - Warn: "Skipping phases {list}. These are marked as skipped."
5. Write updated state.json
6. Sync GitHub Issue labels (same as automatic transition)
7. Announce the change
```

**Via dashboard drag-drop:**
When the dashboard writes a label change to GitHub, the next time the skill runs it will:
1. Read state.json
2. Detect that the GitHub Issue label doesn't match `current_phase`
3. Ask the user: "GitHub shows this feature in {phase} but state.json says {other_phase}. Which is correct?"
4. Reconcile based on user choice

### Transition Log (audit trail)

state.json includes a `transitions` array that records every phase change:

```json
{
  "transitions": [
    {
      "from": "research",
      "to": "prd",
      "timestamp": "2026-04-02T18:45:00Z",
      "approved_by": "user",
      "note": ""
    },
    {
      "from": "prd",
      "to": "tasks",
      "timestamp": "2026-04-02T19:30:00Z",
      "approved_by": "user",
      "note": ""
    },
    {
      "from": "tasks",
      "to": "research",
      "timestamp": "2026-04-03T10:00:00Z",
      "approved_by": "user-manual",
      "note": "PRD scope changed, need to re-research alternatives"
    }
  ]
}
```

### GitHub Label Convention

For the dashboard to read feature phases from GitHub Issues, use these labels:

| Label | Color | Meaning |
|-------|-------|---------|
| `phase:research` | #9CA3AF (gray) | Phase 0 |
| `phase:prd` | #9CA3AF (gray) | Phase 1 |
| `phase:tasks` | #9CA3AF (gray) | Phase 2 |
| `phase:ux` | #3B82F6 (blue) | Phase 3 |
| `phase:integration` | #3B82F6 (blue) | Phase 3b |
| `phase:implement` | #3B82F6 (blue) | Phase 4 |
| `phase:testing` | #A855F7 (purple) | Phase 5 |
| `phase:review` | #A855F7 (purple) | Phase 6 |
| `phase:merge` | #A855F7 (purple) | Phase 7 |
| `phase:docs` | #10B981 (green) | Phase 8 |
| `phase:done` | #10B981 (green) | Complete |
| `priority:critical` | #DC2626 (red) | P0 |
| `priority:high` | #F59E0B (amber) | P1 |
| `priority:medium` | #FBBF24 (yellow) | P2 |
| `priority:low` | #D1D5DB (gray) | P3 |

### Conflict Resolution

When state.json and GitHub Issue disagree:

| Scenario | Resolution |
|----------|-----------|
| state.json ahead of GitHub | Auto-sync: update GitHub label to match state.json |
| GitHub ahead of state.json | Ask user: "Dashboard moved this feature. Accept?" |
| Both changed since last sync | Ask user to choose which source is correct |
| state.json missing, GitHub exists | Create state.json from GitHub Issue data |
| GitHub Issue missing, state.json exists | Offer to create GitHub Issue from state.json |
