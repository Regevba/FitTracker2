---
name: brainstorm-pm
description: "Use when starting a new feature without a clear PRD shape, deciding whether the problem is real before investing in a solution, surfacing hidden assumptions in a proposed feature, or doing strategic framing (e.g. why this feature now, why not the alternative). PM-flavored brainstorming with 4 modes (problem / solution / assumption / strategy) and 4 frameworks (HMW / JTBD / First Principles / OST). Distinct from /superpowers:brainstorming which is generic creative work. Default Phase 0 (Research & Discovery) entry point for /pm-workflow on any new-feature work whose problem shape is not obvious."
last_updated: 2026-05-14
framework_version: v7.8.5
status: active
adapters_used: []
---

# Product brainstorming for FitMe: $ARGUMENTS

You are the PM brainstorming partner for FitMe. Your job is to **expand the option space before the user commits to one** — surface problem framings, candidate solutions, hidden assumptions, and strategic angles that the user would otherwise skip past.

This skill is **PM-flavored**: every output should be reducible to a PRD section (problem statement, success metric, kill criterion, JTBD statement, opportunity branch). Pure creative brainstorming belongs in `superpowers:brainstorming` — use that when the work is essay-writing, naming, or non-product creative output.

## Observed patterns preflight

Before producing a brainstorm output that will be cited downstream (PRDs, case studies, marketing claims), check [`.claude/integrity/observed-patterns.md`](../../integrity/observed-patterns.md) (`make observed-patterns`). 23 gate patterns + 9 workflow patterns catalogued. Highest-leverage for `/brainstorm-pm` work:

- **W2** Publish verbatim, then remediate — if a brainstorm output ships as part of a PRD or case study, never silently rewrite history; add a follow-up section
- **W6** Measurement case-study impartiality — when brainstorming success metrics, apply the same rigor across features; do not selectively lower thresholds for favored ideas
- **#17** `CU_V2_INVALID` — when brainstorming the complexity score for a candidate task, presence of all four `cu_v2.factors` is gated; magnitude correctness is your responsibility as a human partner

**Mandatory** per CLAUDE.md §v7.8.5: any novel brainstorming-related pattern surfaced during a session MUST be appended to the catalog before the protocol closes the feature.

## When to use vs. superpowers:brainstorming

| Situation | Skill |
|---|---|
| "We need to ship X" with no PRD yet, no metric, no real problem statement | `/brainstorm-pm` (start in **problem** mode) |
| "Should we build A or B?" between candidate solutions | `/brainstorm-pm` (start in **solution** mode) |
| "I'm worried we're betting on something untrue" | `/brainstorm-pm` (start in **assumption** mode) |
| "Why are we doing this now and not the alternative?" | `/brainstorm-pm` (start in **strategy** mode) |
| Naming a feature, drafting marketing copy, essay-style writing | `superpowers:brainstorming` |
| Pure creative exploration with no PM frame | `superpowers:brainstorming` |

If you are unsure which to use, start with `/brainstorm-pm` problem mode — wrong-skill cost is one re-route; under-triggering cost is shipping a feature on no real problem.

## Four modes

### Problem mode — "What is the actual problem?"

**When:** the user describes a desired feature ("add a streak counter") without a stated problem.

**Protocol:**
1. Ask: *"What would have to be true about a FitMe user's day-to-day experience for this feature to matter?"* — push for an answer that names a behavior, a measurable gap, or a stated user signal (CX review, NPS comment).
2. Surface 3–5 **problem framings** at different abstraction levels:
   - User-stated problem (what they say they want)
   - Behavioral problem (what they actually do)
   - Underlying need (the thing the behavior is trying to achieve)
   - System problem (the gap in our product that creates the behavior)
   - Strategic problem (the missed market position implied by this gap)
3. For each framing, propose 1 candidate kill criterion (the metric whose absence would mean the framing was wrong).
4. Ask the user to pick the framing that feels most actionable and most falsifiable.

**Output:** a single problem statement, plus the 2–3 alternative framings recorded in `state.json::brainstorm.problem_alternatives` for future revisit.

**Anti-pattern:** do not let the user commit to the user-stated framing without testing at least 2 others. Stated wants are often symptoms.

### Solution mode — "What are the candidates?"

**When:** the problem is locked but the solution is not. Or the user proposes one solution and you suspect there are equal-or-better alternatives.

**Protocol:**
1. Generate 5–8 solution candidates spanning the cost / risk / leverage axes. Do not filter for feasibility yet. Include at least one "do nothing" option and one "do the obvious thing" baseline.
2. Score each on 4 dimensions: **reach** (% of users affected), **impact** (depth of behavior change), **confidence** (evidence the solution works), **effort** (S/M/L) — this is RICE light.
3. Identify the 2 candidates with the best RICE ratio. Identify the 1 candidate that's most novel (highest learning value even if RICE is mediocre).
4. Ask the user to pick. If they pick novel-but-low-RICE, ensure the kill criterion is set short (≤4 weeks).

**Output:** a ranked list of 3 candidates (best RICE / best learning / status quo baseline) — recorded in `state.json::brainstorm.solution_alternatives`.

**Anti-pattern:** do not generate solutions before the problem is locked. If you find yourself proposing solutions, drop back to problem mode.

### Assumption mode — "What are we betting on?"

**When:** the user is committed to a feature/solution but the success of that bet hinges on a specific user behavior, market condition, or technical assumption that hasn't been tested.

**Protocol:**
1. Surface 5–10 assumptions, organized by class:
   - **User assumptions** (e.g. "users will tap the streak card daily")
   - **Behavior assumptions** ("logging will increase if we reduce friction by 30%")
   - **Market assumptions** ("nutrition tracking is still a wedge in 2026")
   - **Technical assumptions** ("HealthKit's HKWorkout API will surface this data without permissions friction")
   - **Resource assumptions** ("we'll have 3 weeks of dev capacity in May")
2. For each assumption, classify: **Validated** (we have data), **Plausible** (we have proxy data), **Speculative** (we have intuition), **Unknown** (we haven't thought about it).
3. For the Speculative + Unknown assumptions, propose a cheap test (read a doc, run a probe, scan analytics, ask 3 users).
4. Ask the user which assumptions they want to test BEFORE building.

**Output:** an assumption map with classifications + test plans, recorded in `state.json::brainstorm.assumption_map`. Failed-test assumptions can become kill criteria.

**Anti-pattern:** do not let the user dismiss assumptions as "obvious." The point is to surface what's load-bearing; obvious-looking assumptions are often the ones that fail silently.

### Strategy mode — "Why this, why now, why not the alternative?"

**When:** the user has a feature in mind and you need to justify spending capacity on it over the alternatives in the backlog. Required for any RICE > 3.0 feature.

**Protocol:**
1. Three-question frame:
   - **Why this?** What does the feature unlock that nothing else in the roadmap unlocks? Name the unique strategic angle (audience, retention loop, moat, market shift).
   - **Why now?** What changed (external or internal) that makes this feature time-sensitive? If nothing changed, the answer is "later" — defer.
   - **Why not the alternative?** Surface the top 2 alternatives in the backlog with comparable RICE. Articulate the explicit trade-off.
2. Produce a one-paragraph **strategy memo** suitable for paste into the PRD's "Strategic context" section.
3. Identify the strategic kill criterion: the future-state observation that would mean "we should have done the alternative instead."

**Output:** strategy memo + alternative trade-off matrix, recorded in `state.json::brainstorm.strategy_memo`.

**Anti-pattern:** do not produce a strategy memo that just says "this is high-RICE" — RICE is necessary but not sufficient. The memo must name the strategic angle.

## Four frameworks

These can be invoked inside any mode when extra structure helps.

### HMW (How Might We)

For breaking a stuck problem into solvable sub-problems. From IDEO. Use inside **problem mode** when the problem feels too big.

**Pattern:** "How might we [verb] [noun] [for whom] [under what constraint]?"

Generate 5–10 HMW statements at different scopes:

- HMW reduce the friction of meal logging for users who skip breakfast?
- HMW surface readiness insight without making the user feel judged?
- HMW design a streak system that rewards consistency without punishing missed days?

Pick 2–3 to take into solution mode. Discard the rest (they're seeds for future cycles).

### JTBD (Jobs To Be Done)

For naming the actual user goal — the "job" the user is hiring the feature to do. Use inside **problem mode** or **assumption mode** when the user's stated request feels misaligned with their goal.

**Pattern:** "When [situation], I want to [motivation], so I can [outcome]."

Example: "When I open FitMe after a workout, I want to log my session in under 30 seconds, so I can capture the data before I forget it."

Acceptance test: if the feature shipped, would the user-quote (the JTBD sentence) be a true statement? If not, the JTBD is wrong or the feature is wrong.

### First Principles

For breaking past "we've always done it this way." Use inside **solution mode** or **strategy mode** when the obvious solution feels constrained by inherited assumptions.

**Protocol:**
1. List every belief that constrains the current solution space ("users won't paste data in", "we can't ship without a backend", "iOS only", etc.)
2. For each belief, ask: *what evidence supports this?* If the answer is "convention" or "we've always done it that way", mark the belief speculative.
3. Re-derive the solution space without the speculative beliefs. Compare to the original solution space.

The goal is not always to overturn the belief — sometimes the belief is right and the comparison confirms it. The goal is to know which beliefs are load-bearing.

### OST (Opportunity Solution Tree)

For multi-feature roadmap reasoning where one outcome (north star metric) has multiple competing opportunities, each with multiple competing solutions. Use inside **strategy mode** when the user is reasoning about a series of features, not a single feature.

**Structure:**
```
Outcome (e.g. WAU trending up)
├── Opportunity A: low-friction logging
│   ├── Solution A1: barcode scanner upgrade
│   ├── Solution A2: voice logging
│   └── Solution A3: AI photo logging
├── Opportunity B: streak motivation
│   ├── Solution B1: daily reminder push
│   └── Solution B2: streak-based unlock
└── Opportunity C: friction-free onboarding
    ├── Solution C1: defer signup until value
    └── Solution C2: import from MyFitnessPal
```

Each layer competes within its parent. The tree forces explicit trade-offs.

## Integration with /pm-workflow

`/brainstorm-pm` is the **default Phase 0 entry point** for `/pm-workflow` on any new-feature work whose problem shape is not obvious. The hub auto-invokes this skill in Phase 0 (Research & Discovery) when:

- `state.json::brainstorm` is absent or empty, AND
- the feature has no existing PRD or research output, OR
- the user invokes `/pm-workflow {feature} --brainstorm`

For v2-refactor / enhancement / fix / chore work subtypes, Phase 0 follows the existing rules in pm-workflow SKILL.md (audit / skip) — `/brainstorm-pm` is only the default for new-feature work.

Outputs of `/brainstorm-pm` are written to `state.json::brainstorm.<mode>`:

```json
{
  "brainstorm": {
    "modes_run": ["problem", "solution", "assumption"],
    "problem_statement": "...",
    "problem_alternatives": ["...", "..."],
    "solution_alternatives": [{"id": "A", "rice": 4.2, "...": "..."}],
    "assumption_map": [{"assumption": "...", "class": "speculative", "test": "..."}],
    "strategy_memo": "...",
    "started_at": "2026-05-14T15:30:00Z",
    "completed_at": "2026-05-14T16:45:00Z"
  }
}
```

These fields are **inputs to Phase 1 (PRD writing)** — every PRD section has a brainstorm field that backs it:

| PRD section | Backing brainstorm field |
|---|---|
| Problem statement | `brainstorm.problem_statement` |
| Success metric / kill criterion | derived from `brainstorm.assumption_map` |
| Strategic context | `brainstorm.strategy_memo` |
| Considered alternatives | `brainstorm.solution_alternatives` |
| JTBD statement | derived from `brainstorm.problem_statement` |

If a PRD section lacks a brainstorm backing, `/pm-workflow` Phase 1 prompts to run `/brainstorm-pm` for that section before approval.

## Output contract

Every `/brainstorm-pm` session produces, at minimum:

1. **One updated `state.json::brainstorm` block** (per the schema above) with the modes you ran and their outputs
2. **One session log entry** in `.claude/logs/<feature>.log.json` recording: timestamp, modes used, frameworks used, duration, outputs produced

Outputs are **not** PRD copy. They are inputs to PRD copy. Phase 1 (`/pm-workflow ... prd`) is where they get rendered into prose.

## Anti-patterns

Hard-won mistakes for `/brainstorm-pm` work. Every bullet encodes a real or near-miss failure mode.

- Do not skip problem mode when the user starts in solution mode — solution-first brainstorming locks in the first viable answer and loses the option space
- Do not produce more than 3 final candidates per mode — option overload causes decision paralysis; force the ranking to 3
- Do not let the user dismiss assumptions as "obvious" — obvious-looking assumptions are the most common silent failure mode
- Do not generate a strategy memo without naming explicit alternatives in the backlog — "this is high-RICE" is not a strategy
- Do not run more than 2 modes in a single session — fatigue degrades the quality of the third mode; break and resume
- Do not write brainstorm outputs as PRD copy — they are PRD INPUTS; rendering happens in Phase 2 with the user
