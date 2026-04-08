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
  "work_type": "feature",
  "has_ui": null,
  "requires_analytics": null,
  "phases": {
    "research": { "status": "in_progress", "approved_at": null, "sources": [] },
    "prd": { "status": "pending", "approved_at": null, "analytics_spec_complete": false },
    "tasks": { "status": "pending", "count": 0 },
    "ux_or_integration": { "status": "pending", "type": null },
    "implementation": { "status": "pending", "commits": [] },
    "testing": { "status": "pending", "ci_passed": false, "tests_added": 0, "instrumentation_verified": false, "analytics_tests_added": 0, "analytics_verification_passed": false },
    "review": { "status": "pending", "risks": [], "ci_main": false, "ci_feature": false },
    "merge": { "status": "pending", "pr_number": null, "analytics_regression_passed": null },
    "documentation": { "status": "pending" },
    "metrics": {
      "primary": { "name": "", "baseline": null, "target": null, "current": null },
      "secondary": [],
      "guardrails": [],
      "instrumentation_ready": false,
      "first_review_date": null,
      "kill_criteria": ""
    }
  },
  "tasks": []
}
```

---

## Work Item Type Selection

Before starting Phase 0, determine the work item type:

Ask: **"Is this a Feature, Enhancement, Fix, or Chore?"**

| Type | Phases | When to Use |
|------|--------|-------------|
| **Feature** | All 9 phases | New capabilities, new screens, new services |
| **Enhancement** | Tasks → Implement → Test → Merge (4 phases) | Improvements to shipped features with existing PRDs |
| **Fix** | Implement → Test (2 phases) | Bug fixes, error handling, security patches |
| **Chore** | Implement only (1 phase) | Docs, config, refactoring, dependency updates |

Set `work_type` in state.json. For non-Feature types:
- **Enhancement:** Skip Research, PRD, UX. Start at Phase 2 (Tasks). Set `parent_feature` to the existing feature being enhanced.
- **Fix:** Skip to Phase 4 (Implement). Auto-set first task with `skill: "dev"`. **Test + Review are still required** (Phase 5 + 6).
- **Chore:** Skip to Phase 4 (Implement). Test gate is optional, but **review gate is still required** for any code change.

All skipped phases get `status: "skipped"` with `reason: "work_type:{type}"` in the audit trail.

### Review Gates (Non-Negotiable)

**Every work item type that changes code MUST pass through Test + Review before merge.** The fast-track reduces _planning_ overhead, not _quality_ gates:

| Type | Planning | Test | Review | Merge | Feedback |
|------|----------|------|--------|-------|----------|
| Feature | Full | Required | Required | Required | Full loop |
| Enhancement | Partial | Required | Required | Required | Full loop |
| Fix | None | Required | Required | Required | Full loop |
| Chore (docs only) | None | Optional | Required | Required | Notify only |

### Change Broadcast (Awareness Protocol)

When ANY work item completes (merge to main), broadcast a change notification to ALL skills so the entire system stays aware:

1. **Update `.claude/shared/feature-registry.json`** — record what changed, when, and why
2. **Notify downstream skills:**
   - `/qa` — "New code merged. Run regression check on next cycle."
   - `/cx` — "Change shipped: {description}. Monitor user feedback for impact."
   - `/analytics` — "Verify instrumentation still intact after merge."
   - `/ops` — "Deployment pending. Check health after deploy."
   - `/design` — "If UI changed, verify design system compliance."
3. **Write a change event to `.claude/shared/change-log.json`:**
   ```json
   {
     "timestamp": "ISO-8601",
     "feature": "feature-name",
     "work_type": "fix",
     "description": "Eliminated force unwraps in production code",
     "files_changed": 4,
     "skills_notified": ["qa", "cx", "ops"],
     "review_status": "approved",
     "test_status": "passed"
   }
   ```

### Upstream Feedback Loop

When `/cx analyze` or `/qa regression` detects an issue post-merge:

1. **Classify the signal:**
   - Customer confusion → `/marketing` (messaging) + `/design` (UX)
   - Regression → `/dev` (fix) + `/qa` (test gap)
   - Performance degradation → `/ops` (infra) + `/dev` (optimization)
   - Expectation mismatch → `/pm-workflow` (re-scope)

2. **Create a new work item** (typically Fix or Enhancement) that links back to the original change
3. **The new work item inherits context** from the original — no information is lost
4. **Close the loop:** When the fix ships, `/cx` re-monitors to verify the issue is resolved

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

Ask the user: "Does this feature introduce new measurable interactions (screens, user actions, badges, achievements)?" → Set `requires_analytics` in state.json.

### Analytics Spec Gate (if requires_analytics = true)

Before the PRD can be approved, define and validate the GA4 analytics instrumentation for this feature:

1. **Read existing taxonomy** — Read `FitTracker/Services/Analytics/AnalyticsProvider.swift` (all enums: `AnalyticsEvent`, `AnalyticsParam`, `AnalyticsScreen`, `AnalyticsUserProperty`) and `docs/product/analytics-taxonomy.csv` to understand the current event landscape.

2. **Draft Analytics Spec** — For each measurable action in the PRD, fill in the "Analytics Spec (GA4 Event Definitions)" section of the PRD template:
   - New events (name, category, GA4 type, trigger screen, parameters, conversion flag)
   - New parameters (name, type, allowed values, which events use them)
   - New screens (snake_case name, SwiftUI view class, category)
   - New user properties (if any — remember max 25 total custom)

3. **Validate naming conventions** against GA4 rules documented in `AnalyticsProvider.swift`:
   - snake_case format, lowercase only
   - Max 40 characters for event and parameter names
   - No reserved prefixes (`ga_`, `firebase_`, `google_`)
   - No duplicate names against existing enums in `AnalyticsProvider.swift`
   - No PII in any parameter (no emails, names, phone numbers, user IDs)
   - Parameter values max 100 characters
   - Max 25 parameters per event
   - Total custom user properties still ≤25 after additions
   - Use GA4 recommended events where available (`login`, `sign_up`, `share`, `select_content`, `tutorial_begin`, `tutorial_complete`)

4. **Complete the Naming Validation Checklist** in the PRD (all boxes must be checked).

5. **Update state.json:** Set `phases.prd.analytics_spec_complete = true`.

**The PRD is NOT approvable until the Analytics Spec passes validation** (when `requires_analytics = true`). If `requires_analytics = false`, the Analytics Spec section is skipped.

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
6. Assign each task a `skill` from: `dev`, `qa`, `design`, `analytics`, `ops`, `marketing`, `cx`, `research`, `release`
7. Identify task dependencies — which tasks must complete before others can start
8. Estimate effort in days for each task

**Structured Task State:** After creating tasks.md, also write the tasks to `state.json.tasks[]`:

```json
{
  "tasks": [
    {
      "id": "T1",
      "title": "Task title from tasks.md",
      "type": "ui|backend|analytics|test|design|docs|infra|research|marketing",
      "skill": "dev|qa|design|analytics|ops|marketing|cx|research|release",
      "status": "pending",
      "priority": "critical|high|medium|low",
      "effort_days": 0.5,
      "depends_on": [],
      "completed_at": null
    }
  ]
}
```

Task status lifecycle: `pending` → `ready` (all depends_on are done) → `in_progress` → `done`

If a task's dependencies cannot be met, set status to `blocked`.

Present task list and ask for approval. **On approval, execute the Phase Transition Procedure.**

---

## Phase 3: UX/UI Definition (if has_ui = true)

**Goal:** Define screens, components, and design requirements before coding — grounded in UX research and validated against the design system.

### V1 vs V2 — refactor or new feature?

Before starting Phase 3, classify the work:

| Classification | Trigger | Phase 3 expectation | Phase 4 file convention |
|---|---|---|---|
| **New UI feature** | No existing v1 file for this surface | Phase 3 is non-skippable. Must produce `ux-spec.md` and pass the design system compliance gateway before any view code is written. | Single Swift file at the canonical path (e.g. `Views/Home/HomeView.swift`). Bottom-up from foundations. |
| **V2 refactor (UX Foundations alignment)** | An existing v1 Swift file for this surface needs alignment with `ux-foundations.md` | Phase 3 starts with a `v2-audit-report.md` walking the existing v1 file against `ux-foundations.md`, THEN produces `ux-spec.md` for the v2 file. | New sibling file `{ScreenName}V2.swift`. v1 file is **not** patched in place — it stays as a historical reference per the V2 Rule in CLAUDE.md. |

Set `state.json.work_subtype` to either `"new_ui"` or `"v2_refactor"`. For `v2_refactor`, populate `state.json.v2_file_path` with the planned V2 file path before Phase 3 advances.

### Step 1: UX Research & Principles

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

### V2 Refactor — file convention (per CLAUDE.md V2 Rule)

If `state.json.work_subtype == "v2_refactor"`:

1. **Do not modify the v1 file in place.** v1 stays read-only during the
   refactor. The audit (`v2-audit-report.md` from Phase 3) is the gap
   analysis; the v2 file is built bottom-up from the design system
   foundations.
2. **Create the V2 Swift file** at `state.json.v2_file_path` (typically
   `{original_dir}/{ScreenName}V2.swift`).
3. **Mark v1 as historical** with a header comment when v2 is functionally
   complete:
   ```swift
   // HISTORICAL — superseded by {ScreenName}V2.swift on {date} per
   // UX Foundations alignment pass. See .claude/features/{name}/v2-audit-report.md
   // for the gap analysis. Kept compiled in the build target as a
   // reviewable historical reference.
   ```
4. **Switch the parent view** to wire the new V2 file (typically
   `RootTabView.swift` or whatever instantiates the screen). This is
   the "go-live" moment for v2.
5. v1 remains in the Xcode build target as compiled-but-unreferenced
   reference code. If v1 fails to compile after a foundational change
   later, the choice at that moment is to either fix v1 or remove it
   from the target — record the decision in `feature-memory.md`.

### Parallel Task Dispatch

When tasks exist in state.json, Phase 4 uses dependency-aware parallel execution instead of sequential implementation:

1. **Compute the ready set** — tasks where ALL entries in `depends_on` have status `done`
2. **Group by skill** — organize ready tasks by their `skill` field
3. **Present to user:**
   ```
   Ready to run in parallel:
     /dev:       T1 (container view), T2 (welcome screen), T3 (goals screen)
     /design:    T9 (progress bar component)
   Blocked (waiting on dependencies):
     /analytics: T8 (GA4 events) — needs T1, T2
     /qa:        T10 (unit tests) — needs T1-T9
   ```
4. **Execute ready tasks** — work on ready tasks, potentially across skills
5. **On each task completion:**
   - Set task `status: "done"` and `completed_at: timestamp`
   - Recompute the ready set (completed task may unblock others)
   - Present newly unblocked tasks
6. **Rebuild cross-feature queue** — update `.claude/shared/task-queue.json`
7. **Phase 4 is complete** when ALL tasks have status `done`

### Cross-Feature Priority Queue

After any task state change, rebuild `.claude/shared/task-queue.json`:

```json
{
  "version": "1.0",
  "updated": "{timestamp}",
  "queue": [
    {
      "feature": "feature-name",
      "task_id": "T1",
      "title": "Task title",
      "skill": "dev",
      "work_type": "feature",
      "priority_score": 8,
      "status": "ready",
      "effort_days": 0.5
    }
  ],
  "scoring": {
    "base": { "critical": 10, "high": 7, "medium": 4, "low": 1 },
    "work_type_boost": { "fix": 3, "enhancement": 1, "feature": 0, "chore": -1 }
  }
}
```

Priority score = `base[priority] + work_type_boost[work_type]`. Fixes automatically jump the queue.

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

### Analytics Verification (if requires_analytics = true)

After general tests pass, run dedicated analytics verification:

1. **Unit test event firing** — For each event defined in the PRD's Analytics Spec:
   - Create a test in `FitTrackerTests/AnalyticsTests.swift` (create the file if it doesn't exist — first feature bootstraps it)
   - Construct a `MockAnalyticsAdapter` and inject it via `AnalyticsService(provider: mockAdapter, consent: consentManager)`
   - Trigger the action that should fire the event
   - Assert `mockAdapter.capturedEvents` contains the event with the correct name
   - Assert all expected parameters are present with correct types and values
   - Assert no unexpected parameters leak through

2. **Screen tracking verification** — For each new screen in the Analytics Spec:
   - Call the screen tracking method (or trigger `.analyticsScreen()` modifier)
   - Assert `mockAdapter.capturedScreens` contains the expected screen name

3. **Consent gating verification** — For at least one representative event per feature:
   - Set consent to denied → trigger the action → assert event is NOT in `capturedEvents`
   - Set consent to granted → trigger the action → assert event IS in `capturedEvents`
   - This validates the consent gate works end-to-end

4. **Taxonomy sync check** — Verify code and documentation are in sync:
   - Every event in the Analytics Spec has a corresponding constant in `AnalyticsEvent` enum (`AnalyticsProvider.swift`)
   - Every event has a row in `docs/product/analytics-taxonomy.csv`
   - Every new screen has entries in both `AnalyticsScreen` enum and the CSV screens section
   - Every new parameter has a constant in `AnalyticsParam` enum

5. **Update state.json:** Set `analytics_tests_added` (count of tests written) and `analytics_verification_passed = true`

**The phase is NOT approvable if `analytics_verification_passed = false`** (when `requires_analytics = true`).

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

### Post-Merge Analytics Regression (if requires_analytics = true)

After the merge to main is complete, verify analytics integrity on the merged branch:

1. **Switch to main** — `git checkout main && git pull origin main`

2. **Run analytics test suite on main** — Execute all tests in `FitTrackerTests/AnalyticsTests.swift`:
   - All pre-existing analytics events still fire correctly (no regressions from the merge)
   - All new events from this feature work on the main branch
   - Screen tracking for both existing and new screens works
   - Consent gating still functions

3. **Taxonomy completeness check** — Programmatically verify code ↔ documentation sync:
   - Every constant in `AnalyticsEvent` enum has a corresponding row in the events section of `analytics-taxonomy.csv`
   - Every constant in `AnalyticsScreen` enum has a row in the screens section
   - Every constant in `AnalyticsUserProperty` enum has a row in the user properties section
   - Report any orphaned constants (in code but not CSV) or missing rows (in CSV but not code)

4. **Update state.json:** Set `phases.merge.analytics_regression_passed = true/false`

**If regression fails:** Alert the user with the specific failures. Recommend either:
- Fix on main directly (if trivial — e.g., missing CSV row)
- Create a hotfix branch for non-trivial issues

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
