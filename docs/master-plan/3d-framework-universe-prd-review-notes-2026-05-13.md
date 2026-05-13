# 3D Framework Universe PRD — Review Notes & Parking-Status Reconciliation

**Created:** 2026-05-13 evening
**Status:** ⚠️ Operator decision required — parking-decision conflict detected
**Source PRD:** [`.claude/features/3d-interactive-framework-flow-diagram/prd.md`](../../.claude/features/3d-interactive-framework-flow-diagram/prd.md) (372 lines, shipped via FT2 PR #329 + fitme-story PR #101)
**Companion state:** [`.claude/features/3d-interactive-framework-flow-diagram/state.json`](../../.claude/features/3d-interactive-framework-flow-diagram/state.json)

---

## ⚠️ Section 0 — Parking-decision conflict (must read first)

**Decision on record:** During the 2026-05-13 analytics-observability brainstorm, the operator locked decision #3:

> *"Park 3D framework, make analytics the new active feature."*

This was captured in [[project_session_2026_05_13_analytics_audit_paused]] and locked into both:
- `.claude/features/analytics-observability/state.json::blocker_resolutions.live_debugger_flavor` (parking referenced)
- `.claude/features/3d-interactive-framework-flow-diagram/state.json::scheduled_after = "analytics-observability phase=complete"`

**Conflicting forward motion:** Despite the park, a concurrent session shipped:
- FT2 PR #329 (`feature/3d-framework-universe-prd-draft`) — 467 additions / 4 deletions across 4 files
- fitme-story PR #101 (companion state mirror)

The PRs **advanced** `current_phase: research → prd` and wrote a 372-line PRD. The `transitions[0]` entry shows `approved_by: user`, so the operator *did* approve the phase advance at some point. But the `scheduled_after` field is STILL set (it survived the merge), meaning the feature's official posture remains "auto-resume after analytics completes."

**The two states are inconsistent:**
- "current_phase: prd" + 372-line PRD on disk → looks ready to advance to Phase 2 (Tasks)
- "scheduled_after: analytics-observability phase=complete" → not yet eligible to advance

**This review will NOT recommend advancing.** Instead, it produces operator decision input for reconciliation.

---

## §1 What the operator actually decides

Three reconciliation paths:

| Path | What it means | Cost | Best when |
|---|---|---|---|
| **R1 — Honor park; freeze PRD where it is** | Leave `current_phase: prd` AND keep `scheduled_after`. The PRD is a sunk artifact; do nothing else until analytics-observability completes (`2026-06-26` earliest). | 0 (no further work) | Operator believes the park decision still represents resource priority |
| **R2 — Unpark; advance normally** | Remove `scheduled_after`; transition PRD → Tasks via `/pm-workflow`. Treat the PRD as the next active item. Phase 2 (Tasks), Phase 3 (UX), Phase 4 (Implementation) proceed. | ~3 person-weeks per PRD §Effort estimate | Operator has reconsidered — 3D explainer is now higher priority than waiting for analytics close |
| **R3 — Park harder; revert the phase advance** | Roll `current_phase: prd → research`; PRD stays on disk as reference but officially deferred. Re-evaluation at analytics-observability close. | ~5min (state.json edit + commit) | Operator wants to maintain park strictly and considers PR #329 as having jumped the queue |

**My recommendation: R1.** The PRD is a valuable artifact (372 lines of decisions captured); deleting or reverting it would lose work. But ADVANCING it now (R2) supersedes the park decision; REVERTING the phase (R3) is process-hygienic but discards the locked-in PR-level work. Holding the line — leave the PRD in place, leave `scheduled_after` in place, do nothing else — preserves both decisions cleanly. The operator can pick R2 at any time later if priorities shift.

---

## §2 Diagnostic notes on the shipped PRD (informational only)

These observations are for the operator's situational awareness — **not advancement criteria.**

### §2.1 PRD scope & quality

| Dimension | Assessment |
|---|---|
| Length | 372 lines — appropriate for a feature of this complexity |
| Functional requirements | 12 numbered (FR#1–#12), well-scoped |
| Personas | 4 distinct (visitor / returning reader / FT2 operator / marketing) — covers public + dogfood + share use cases |
| User flows | 4 scenarios (primary / secondary / tertiary reduced-motion / quaternary operator) |
| Acceptance criteria | 10 items including hard performance gate (Lighthouse ≥95) |
| Success metrics | Primary + 4 secondary + 6 guardrails + leading + lagging — comprehensive |
| Analytics spec | **9 new events + 21 new parameters + 2 user properties** — fully specified, screen-prefix compliant (`framework_*`), naming-validation checklist passes |
| Kill criteria | 5 explicit, well-distinguished |
| Effort estimate | ~3 person-weeks across 7 phases — realistic given the 3D component scope |
| Cross-references | Research dossier, Linear FIT-138, Notion page, glossary, FT2 ↔ fitme-story coupling |

**The PRD is publication-quality.** No structural defects.

### §2.2 Specific design decisions the operator should be aware of

1. **3 cascading visual tiers:** Tier 1 (R3F + Drei + Theatre.js + Three.js WebGPU/WebGL2), Tier 2 (Rive for reduced-motion + low-RAM), Tier 3 (static `next/image` poster). Reduced-motion users get a *deliberately equal-information* variant per WCAG 2.3.3.
2. **Hybrid asset pipeline:** procedural R3F primitives for architectural shell; ≤6 Blender → glTF hero pieces. New `@gltf-transform/cli` dependency for fitme-story.
3. **Live data wiring (Stream B):** build-time snapshot of `gate-coverage.jsonl` + `measurement-adoption-history.json` from FT2. Already cross-repo-mirrored via existing `sync-from-fittracker2.ts` script.
4. **Operator mode at `/control-room/framework`:** same React component, different `mode` prop. Passkey auth via existing UCC. WebSocket subscription for live event bursts.
5. **Primary metric is compound:** "engaged comprehension" = ≥80% playback × ≥1 label hover × reached Act VI. Cannot be inflated by autoplay.
6. **Launch window stated in PRD:** Track A, 2026-05-21 → 2026-06-18 (Phase 4 implementation 06-04 → 06-15, ship pre-06-18). **This collides with `scheduled_after: analytics-observability phase=complete (2026-06-26)`.** Another reason to keep R1 unless the operator wants to consciously override.

### §2.3 11 questions deferred to subsequent phases

Per the PRD's §"Open questions deferred to subsequent phases", 11 of 15 open questions remain — most material:
- Q3-route — `/framework` vs `/framework/universe` (Phase 3 UX)
- Q-extract — npm package for share-clip use case (Phase 9 Learn)

These DON'T need resolution to keep the PRD on ice (R1). They DO need resolution if the operator picks R2.

---

## §3 What I am explicitly NOT doing in this review

- **Not recommending approval** to advance PRD → Tasks
- **Not opening a "Phase 2 (Tasks) planning" PR** for the 3D feature
- **Not updating** `.claude/features/3d-interactive-framework-flow-diagram/state.json` in any way
- **Not advancing** `current_phase`
- **Not removing** the `scheduled_after` field

These are operator-only decisions. This review hands the operator the information needed to pick R1 / R2 / R3, nothing more.

---

## §4 If the operator picks R1 (honor park) — no follow-up actions

The PRD lives at `.claude/features/3d-interactive-framework-flow-diagram/prd.md` as a decision artifact. When analytics-observability transitions to `current_phase: complete` (~2026-06-26), the `scheduled_after` signal fires and the framework auto-resumes the 3D feature from `current_phase: prd` → next phase. At that point the operator re-evaluates Q3-route, Q-extract, and the remaining 9 open questions.

## §5 If the operator picks R2 (unpark + advance) — follow-up actions

1. Remove `scheduled_after` block from `.claude/features/3d-interactive-framework-flow-diagram/state.json`
2. Edit `.claude/active-feature` to swap from `analytics-observability` → `3d-interactive-framework-flow-diagram`
3. Decide what happens to in-flight analytics-observability work (Phase 1.A.5/6/7 in progress per other concurrent sessions). Two sub-paths:
   - R2a: keep analytics ALSO active (multi-feature concurrency — but lockfile is single-feature; pick one)
   - R2b: re-park analytics (would orphan Phase 1.A.5/6/7 work currently in flight)
4. Invoke `/pm-workflow 3d-interactive-framework-flow-diagram` → Phase 2 (Tasks) generation via `superpowers:writing-plans`
5. Note: launch window in PRD is Track A 2026-05-21 → 2026-06-18; if R2 happens AFTER 2026-05-21, the window is already partially consumed

**R2 is a non-trivial commitment.** It supersedes the documented park decision. If the operator picks R2, the analytics-observability spec's §3 Decisions Log should be appended with the override + rationale (so future agents don't get whiplash).

## §6 If the operator picks R3 (park harder) — follow-up actions

1. Edit `.claude/features/3d-interactive-framework-flow-diagram/state.json`:
   - Set `current_phase: research` (revert the PR #329 advance)
   - Keep `scheduled_after` intact
   - Append a new `transitions[]` entry recording the revert with `approved_by: user` + reason
2. The PRD file at `.claude/features/3d-interactive-framework-flow-diagram/prd.md` STAYS on disk (still useful when the feature legitimately resumes)
3. Mark FT2 PR #329 as "phase-jump revert" in any relevant case study (preserves the audit trail of why a merged PR was effectively backed out)
4. Operator clarifies in a note WHY PR #329 was allowed to merge in the first place if it represented a park-violation — closes the meta-loop on agent coordination

---

## §7 Operator decision needed

**Pick R1, R2, or R3.** Until decision, this review is the artifact of record.

| | R1 (honor park) | R2 (unpark) | R3 (park harder) |
|---|---|---|---|
| Effort | 0 | ~3 person-weeks | ~5 min |
| Process hygiene | ✅ Park decision preserved | ⚠️ Park decision superseded (must document) | ✅ Park decision preserved + reinforced |
| PRD survives | ✅ Yes (as reference) | ✅ Yes (becomes active spec) | ✅ Yes (as reference) |
| Concurrency cost | ✅ None | ⚠️ Forces analytics dispatch decision | ✅ None |
| When operator can choose otherwise | At analytics-observability close (~2026-06-26) — auto-resumes | Now | At analytics-observability close (auto-resumes from research) |

---

## §8 Cross-references

- The parking decision in context: [[project_session_2026_05_13_analytics_audit_paused]] §4.1 (decision #3)
- The follow-up parking-preservation memory: [[project_session_2026_05_13_evening_analytics_spec_completed]] § "Concurrent activity worth flagging" (noted the 3D branch advance mid-session)
- Observed Patterns Catalog applicability: there isn't a documented pattern yet for "feature was parked but another agent advanced it via PR." This may warrant a new entry in [`.claude/integrity/observed-patterns.md`](../../.claude/integrity/observed-patterns.md) as workflow pattern **W9 — Concurrent agent advances parked feature** if the operator picks R3 (the "this shouldn't have happened" path).
