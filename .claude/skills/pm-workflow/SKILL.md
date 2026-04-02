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

Present the research to the user and ask for approval. Update state.json when approved.

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

Present the PRD and ask for approval.

---

## Phase 2: Task Breakdown

**Goal:** Divide the PRD into implementable subtasks.

Create `.claude/features/$0/tasks.md` with:
1. Read the approved PRD
2. Break into subtasks, each with: title, description, estimated effort, dependencies
3. Classify each task: `ui`, `backend`, `data`, `test`, `docs`, `infra`
4. Order by dependency graph
5. Estimate total effort

Present task list and ask for approval.

---

## Phase 3: UX/UI Definition (if has_ui = true)

**Goal:** Define screens, components, and design requirements before coding.

Follow the Feature Development Gateway at `docs/design-system/feature-development-gateway.md`:
1. Problem framing (already done in PRD)
2. Behavior definition: entry points, primary task flow, edge cases, states (empty/loading/error/success)
3. Screen list with wireframe descriptions
4. Component inventory (reuse existing AppComponents where possible — check `FitTracker/DesignSystem/AppComponents.swift`)
5. Design token requirements (map to existing `AppTheme.swift` tokens; flag any new primitives needed)
6. User interaction flows
7. Accessibility requirements
8. Reference the design inspiration from Phase 0 research

Also walk through `docs/design-system/feature-design-checklist.md` for every UI decision.

Create `.claude/features/$0/ux-spec.md` with the above.

Present UX spec and ask for approval.

## Phase 3b: Integration Requirements (if has_ui = false)

**Goal:** Define technical contracts and integration points.

Create `.claude/features/$0/integration-spec.md` with:
1. API contracts (endpoints, payloads, auth)
2. Data model changes (new models, migrations)
3. Service dependencies
4. Error handling strategy
5. Backward compatibility plan

Present spec and ask for approval.

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

Present implementation summary and ask for approval.

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

Present test results and ask for approval.

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

Present review and ask for approval.

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

- **No phase is skipped.** Every phase must be completed and approved.
- **No PRD without metrics.** Every feature must define how success is measured.
- **No merge without CI.** Both feature branch and main must be green.
- **Data drives decisions.** Research, metrics, and kill criteria guide the lifecycle.
- **User approves every gate.** No autonomous phase transitions.
