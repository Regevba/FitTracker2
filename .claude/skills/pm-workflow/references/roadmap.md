# `/pm-workflow roadmap` — on-demand reference

> Loaded on demand when `/pm-workflow roadmap <verb>` is invoked. Not loaded
> for normal feature work. Per Anthropic's `skill-creator` progressive-
> disclosure pattern (thin orchestrator + on-demand reference files).

## Purpose

Brings roadmap-management into the skills layer. Today the roadmap lives at
[`docs/master-plan/master-backlog-roadmap.md`](../../../../docs/master-plan/master-backlog-roadmap.md) and is hand-edited.
This reference codifies the prioritization frameworks + decision-memo
template so every change to that file has a uniform shape.

Closes §3A Gap #2 from `docs/skills/skills-review-2026-05-13.md`.

## Verbs

- `/pm-workflow roadmap review` — read + summarize current roadmap state
- `/pm-workflow roadmap prioritize` — run RICE / MoSCoW / Now-Next-Later on the backlog
- `/pm-workflow roadmap decide {item}` — produce a decision memo on one item

## Frameworks

### RICE (project-canonical)

Reach × Impact × Confidence / Effort. Already in use at the project level
([`docs/master-plan/master-backlog-roadmap.md`](../../../../docs/master-plan/master-backlog-roadmap.md) §RICE Scoring Legend).

| Factor | Scale | Notes |
|---|---|---|
| Reach | 1–10 | How many users/stakeholders does this impact? |
| Impact | 0.25 / 0.5 / 1 / 2 / 3 | Minimal / Low / Medium / High / Massive |
| Confidence | 50% / 80% / 100% | Low / Medium / High certainty |
| Effort | Person-weeks | How long to complete |
| **RICE** | R × I × C ÷ E | Higher = do first |

**Use when:** the backlog has more candidates than capacity AND the candidates
span a wide range of effort (S/M/L). RICE is the project's default.

### MoSCoW

Must / Should / Could / Won't (this cycle).

**Use when:** a fixed-scope release window is approaching and you need to
defend "what's in" vs "what's out". Often used inside RICE — after RICE
ranks the candidates, MoSCoW decides where the cut-line falls.

| Bucket | Rule |
|---|---|
| Must | Without it the release ships broken; non-negotiable |
| Should | High value, included if capacity remains after Must |
| Could | Nice-to-have, included only if Must + Should ship under budget |
| Won't (this cycle) | Explicitly deferred; record the reason in the decision memo |

**Anti-pattern:** treating MoSCoW as a feature wishlist. Every Must must have
a hard requirement — release date, kill criterion, regulatory deadline, etc.

### Now / Next / Later

Time-bucketed planning. Loose substitute for RICE when the backlog is small
and confidence in dates is low.

| Bucket | Window | Commitment level |
|---|---|---|
| Now | Currently in flight (Phase 0–7) | Approved + resourced |
| Next | 1–4 weeks out | Researched + tentatively scoped |
| Later | >4 weeks out | Identified; not researched |

**Use when:** the team is small AND backlog churn is high AND RICE inputs
would be guesses. Especially good for solo-builder context (FitMe).

### Comparison

| Question | Use |
|---|---|
| How do I rank N items with comparable shape? | RICE |
| Which items make this release vs. drop? | MoSCoW |
| What am I working on this week / next week / later? | Now-Next-Later |
| All three? Sequence them | RICE → MoSCoW → Now-Next-Later |

## Decision-memo template

Use for any roadmap decision worth recording (delete, defer, re-rank ≥3 positions,
change scope of an in-flight item, change framework version under which it ships).

```markdown
# Decision: {one-line summary}

**Date:** YYYY-MM-DD
**Decider:** {person}
**Item(s):** {feature-name(s) — link to .claude/features/<name>/state.json}
**Framework:** RICE / MoSCoW / Now-Next-Later
**Status:** approved / rejected / deferred

## Context
One paragraph. What changed since the last roadmap snapshot? What surfaced
this decision? Link to evidence (incident, audit, user signal).

## Considered options
1. **{Option A}** — pros / cons / RICE
2. **{Option B}** — pros / cons / RICE
3. **{Status quo}** — pros / cons (always include status quo)

## Chosen option
{Option N}. Justification:
- {primary reason}
- {secondary reason}
- {risk acknowledged}

## Trade-off accepted
What are we losing by NOT picking the alternatives? Name the cost explicitly.

## Reversal trigger
Future-state observation that would mean "we should have picked differently."
Include a date by which the reversal trigger should be evaluated.

## Action items
- [ ] {action 1}
- [ ] {action 2}

---
*Logged via `/pm-workflow roadmap decide`. Append to `docs/master-plan/decisions/YYYY-MM-DD-{slug}.md`.*
```

## Sub-command protocols

### `/pm-workflow roadmap review`

**Goal:** summarize current roadmap state without proposing changes.

1. Read [`docs/master-plan/master-backlog-roadmap.md`](../../../../docs/master-plan/master-backlog-roadmap.md)
2. Read [`docs/master-plan/infra-master-plan-2026-05-12.md`](../../../../docs/master-plan/infra-master-plan-2026-05-12.md) for forward-looking framework infra
3. Cross-reference with `.claude/features/*/state.json` (`current_phase`) to find drift:
   - Items in roadmap with `current_phase: complete` not yet marked done in roadmap
   - Items in roadmap with no matching state.json (untracked)
   - In-flight items (`current_phase` ∉ {complete, closed}) not in roadmap "Now" bucket
4. Output a single readout to stdout. Do NOT edit the roadmap doc — that's `prioritize`'s job.

### `/pm-workflow roadmap prioritize`

**Goal:** propose a re-ranking using a named framework.

1. Run `review` first (above) to surface drift
2. Ask the user which framework: RICE / MoSCoW / Now-Next-Later (default RICE)
3. Score every backlog candidate per the chosen framework. Surface the existing scores from the roadmap doc; do not silently recompute unless the user requests it.
4. Propose 3 reorderings:
   - **A** — strict score order (purely mechanical)
   - **B** — score order with manual overrides for strategic items the user flags
   - **C** — status quo (do nothing — always include for comparison)
5. Ask the user to pick. On selection, propose the diff against the current roadmap doc but DO NOT apply it — the user applies the diff manually after review.

### `/pm-workflow roadmap decide {item}`

**Goal:** produce a single decision memo for one backlog item.

1. Look up `{item}` in `.claude/features/<item>/state.json` (if exists) and in the roadmap doc
2. Generate a decision memo per the template above
3. Ask the user 6 clarifying questions (one per template section that requires a human judgment call)
4. Write the completed memo to `docs/master-plan/decisions/YYYY-MM-DD-<item-slug>.md`
5. Update the roadmap doc with a one-line reference to the new decision memo

## Anti-patterns

- Do not silently rewrite the roadmap doc — every change goes through a decision memo + user approval
- Do not score with RICE without making the Confidence factor explicit — 80%-vs-50% confidence often flips the ranking
- Do not skip the "status quo" option in a decision memo — defending against doing nothing is itself a useful exercise
- Do not collapse RICE inputs to a single "score" without showing the four factors — the inputs let the user audit the score
- Do not run `prioritize` without first running `review` — drift in the doc invalidates the score baseline
- Do not file a decision memo without a reversal trigger — un-trigger-able decisions are unaccountable
