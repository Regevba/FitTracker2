---
title: Orchid Research Capstone — Publication Prep (staged, not published)
date: 2026-05-30
status: draft_for_review
framework_version: v7.9
work_type: chore
work_subtype: research_publication_prep
author: session synthesis (FT2)
related_research:
  - docs/research/2026-05-29-hadf-activation-orchid-validation-analysis.md
  - docs/research/2026-04-28-orchid-framework-v7-mapping.md
  - docs/research/2026-04-28-hadf-signature-expansion.md
  - docs/research/2026-05-01-modular-chip-architecture-survey.md
  - docs/research/2026-05-01-chip-security-zero-day-survey.md
  - docs/research/2026-05-12-hadf-phase2bis-orchid-integration.md
related_case_studies:
  - docs/case-studies/orchid-ai-accelerator-case-study.md
  - docs/case-studies/orchid-v1-5-additive-units-case-study.md
  - docs/case-studies/hadf-hardware-aware-dispatch-case-study.md
  - docs/case-studies/hadf-phase2-cloud-fingerprinting-case-study.md
  - docs/case-studies/hadf-phase2bis-cross-sub-exp-synthesis-case-study.md
related_specs:
  - docs/superpowers/specs/2026-05-03-orchid-v1-5-design.md
  - docs/superpowers/specs/2026-05-11-hadf-phase2bis-replication-design.md
---

# Orchid Research Capstone — Publication Prep (staged, not published)

## §0 — One-line summary

Stage a publish-ready capstone case study spanning the entire Orchid research
arc — empirically validated by the HADF measurement program — together with its
supporting artifacts (anchor-doc polish, publication-readiness plan, staged hub
diff), such that **publish-day is a mechanical flip** and **nothing goes live
during this work**.

## §1 — Why this, why now

The Orchid research program now has enough closed evidence to *frame* a capstone,
but not enough to *publish* one:

- **Orchid v1** (behavioral, Layer A) is complete — 25,305 benchmark runs, 0
  invariant violations, 7 units modeled
  ([orchid-ai-accelerator-case-study.md](../../case-studies/orchid-ai-accelerator-case-study.md)).
- **Orchid v1.5** (additive units U8/U9/tier-propagation/U3-PMU) shipped Tracks
  L + D (PRs #179, #180, #182, #183, #184); Track R (RTL) is blocked on toolchain
  and Track D D3 (26K sweep) is deferred. Feature `status: paused`, case study
  `draft_for_review`.
- **framework-v7 silicon mapping** ([2026-04-28-orchid-framework-v7-mapping.md](../../research/2026-04-28-orchid-framework-v7-mapping.md))
  connects v7.x software defenses to ORCHID silicon analogues.
- **HADF** supplies the empirical validation: Phase 2 (silhouette @ k=5 on n≈700)
  green-lit dispatch-layer fingerprinting; Phase 2-bis **Sub-exp 1 PASS**
  (stronger silhouette at n=2,600 / 4 endpoints). Sub-exp 2 (~2026-05-30) and
  Sub-exp 3 (~2026-05-31, a *falsification* test) are **PENDING**, and the
  Phase 2-bis synthesis verdict (~2026-06-04) is **PENDING**.
- The convergence point already exists as an operator-authored **living anchor**:
  [2026-05-29-hadf-activation-orchid-validation-analysis.md](../../research/2026-05-29-hadf-activation-orchid-validation-analysis.md),
  which states verbatim: *"LIVING ANCHOR — not for publication yet."*

The honest disposition is **"PARTIALLY SUPPORTED — cloud generalization only."**
Publishing now would run ahead of the data. So this work *prepares* publication
to the point of a one-step flip, and stops there. This respects the operator's
2026-05-29 decision and the project's pre-registration / publish-verbatim norms.

## §2 — Goals & non-goals

**Goals**
1. A capstone case study MDX, staged **dormant**, structured so HADF-dependent
   cells fill mechanically as Sub-exps 2/3 and the synthesis verdict close.
2. The 2026-05-29 anchor doc strengthened everywhere completable *now*, with all
   PENDING cells left honestly pending.
3. A publication-readiness plan that makes publish-day deterministic.
4. A staged (documented, not committed-live) diff for the site research hub.
5. A formal spec (this doc) + an implementation plan (writing-plans).

**Non-goals (YAGNI)**
- No publishing, tier-flip, deploy, or live routing.
- No new external research; integrate the existing in-repo corpus only.
- No new HADF data collection; no influence on the pending sub-exps.
- No Orchid Track R / toolchain / RTL work (still blocked).
- No new visual-aid React components — reuse the existing 18.
- No edits to closed case studies (12-hadf, 22b, 22c) beyond adding cross-ref
  back-links if strictly needed for navigation.

## §3 — Guardrails (load-bearing)

### 3.1 Dormancy (verified mechanism)

The fitme-story content loader ([src/lib/content.ts](https://github.com/Regevba/fitme-story/blob/main/src/lib/content.ts))
reads only files where `name.endsWith('.mdx')` and runs `FrontmatterSchema.parse()`
on each at build time; `generateStaticParams()`
([src/app/case-studies/[slug]/page.tsx](https://github.com/Regevba/fitme-story/blob/main/src/app/case-studies/%5Bslug%5D/page.tsx))
routes only `tier ∈ {flagship, standard, light, appendix}`. Two consequences:

- `tier: unassigned` keeps a file out of the build manifest and hub listing, but
  the loader still parses it every build (a malformed file breaks the build), and
  App Router's default `dynamicParams: true` could still render it on direct-URL
  hit. **Not bulletproof.**
- A file **not** ending in `.mdx` is invisible to the loader entirely: never
  parsed, never routed, never reachable, cannot break the build.

**Decision:** stage the capstone as
`content/04-case-studies/37-orchid-research-arc.mdx.draft`. It carries full,
publish-ready frontmatter inside. **Publish-day flip = rename `.mdx.draft → .mdx`
+ set `tier: standard` + set final `date`.** This is the single strongest
dormancy guarantee available and is self-documenting (a visibly-staged draft in
the content dir).

### 3.2 Honesty

- Sub-exp 2, Sub-exp 3, and the synthesis verdict are **PENDING**; every
  HADF-dependent claim is gated behind an explicit fill-in marker (§4.1).
- Sub-exp 3 is a **falsification** test (`delta_ratio < 1.0 → REFUTES` HADF on
  the routing axis). The draft must hold the *negative-result* branch open: a
  pre-written paragraph for the refutation outcome, not only the confirmation
  outcome.
- Every quantitative claim carries a T1/T2/T3 tier tag per
  [data-quality-tiers.md](../../case-studies/data-quality-tiers.md).
- Numeric values are **not** hard-coded into this spec; they are pulled from the
  anchor + upstream case studies at fill-in time (the spec deliberately avoids
  enshrining any figure, including a known Phase-2 endpoint-count nuance between
  the anchor table and the Phase-2 case study, which is reconciled at fill-in).

### 3.3 Branch isolation

`docs/superpowers/specs/` and `docs/superpowers/plans/` are **not** infra-glob
paths, so `BRANCH_ISOLATION_VIOLATION` Mode B does not fire. The capstone MDX and
hub diff live in the fitme-story repo. No `state.json::current_phase` mutation is
involved (Mode C n/a). Recommended branch: a fresh `docs/orchid-research-capstone-prep`
off `main` rather than the current `chore/freshness-reconcile-2026-05-29` branch,
to keep the PR clean and not entangle the operator's in-flight freshness-reconcile
changes. **Branch choice confirmed with the operator before any commit.**

## §4 — Artifact 1: Capstone MDX (staged dormant)

**Path:** `fitme-story/content/04-case-studies/37-orchid-research-arc.mdx.draft`

### 4.1 Frontmatter (publish-ready, inside the dormant file)

```yaml
title: "Orchid — From Dispatch Patterns to Silicon, Validated by Measurement"
slug: orchid-research-arc
tier: standard            # live value; dormancy is via the .mdx.draft extension
status: draft
version: '7.9'            # ships at v7.9 per the anchor's completion plan
order: 37
date_written: '2026-05-30'
# date: <SET ON PUBLISH DAY>
upstream_path: docs/research/2026-05-29-hadf-activation-orchid-validation-analysis.md
spec: docs/superpowers/specs/2026-05-30-orchid-research-capstone-design.md
plan: docs/superpowers/plans/2026-05-30-orchid-research-capstone-publication-readiness.md
predecessor_case_studies:
  - 12-hadf
  - 22b-hadf-phase2-cloud-fingerprinting
  - 22c-hadf-phase2bis-cross-sub-exp-synthesis
external_audit_status: pending     # Audit #2 (2026-06-12) covers raw HADF data
kill_criterion_fired: false
key_numbers: [ ... see §4.3 ... ]
honest_disclosures: [ ... see §4.3 ... ]
kill_criteria: [ ... see §4.3 ... ]
visual_aid:
  component: FrameworkAdvancement   # arc spine; BlueprintOverlay is the fallback
  data: { ... }
persona_emphasis:
  hr: outcomes
  pm: lifecycle
  dev: architecture
  academic: measurement
```

### 4.2 Narrative spine (7 sections)

1. **Thesis — orchestration as a silicon problem.** Why the framework's dispatch
   intelligence has a hardware analogue; what Orchid IS / IS NOT (research vehicle,
   cloud-emulated, open, parameterizable — not a product).
2. **v1 behavioral proof.** Layer-A models, 25,305 runs, 0 invariant violations,
   `prefetch_ahead` as variance leader, cache-thrash cliff. The empirical floor.
3. **v1.5 additive units.** U8 Patrol Scrubber, U9 Validation Bus, T1/T2/T3 tier
   propagation on TileLink `user[1:0]`, U3 PMU exposure — Option B (additive,
   ABI-stable) over a v2 rewrite. Tracks L + D shipped; R/D3 honestly pending.
4. **framework-v7 silicon mapping.** v7.1 cycle → U8; v7.5 defenses → U9; data
   tiers → tier bits; v7.6/7.7 → assertion_mode / split channels. The bridge from
   software discipline to RTL intent.
5. **HADF empirical validation.** Phase 2 → Phase 2-bis Sub-exp 1 silhouette
   strengthening; how the measurement validates U1 bus-width (separation, not
   dynamic range), U4/U5 stability, and the 2-bit tier ABI bet. *(HADF-dependent
   cells gated.)*
6. **Scoped-activation posture.** What the closed data licenses (cloud_modifier →
   >0.7) vs. what stays advisory (device, routing-layer) pending Sub-exps 2/3;
   the zero-regression gate. *(HADF-dependent cells gated.)*
7. **Honest close.** The PARTIALLY-SUPPORTED disposition, the two standing caveats
   (T3-over-T1 scoped to 4 endpoints; synthesis verdict PENDING), and the
   forward path (Audit #2, ORCHID v2 stub gated on toolchain).

### 4.3 Fill-in markers (1:1 with the anchor completion plan)

HADF-dependent content is wrapped in literal HTML-comment markers so fill-in is
mechanical and greppable:

| Marker | Fills from | Capstone section |
|---|---|---|
| `<!-- FILL ON SUB-EXP 2 -->` | KS p-value verdict; compute-bound-vs-I/O finding (U7/U3) | §5, §6 |
| `<!-- FILL ON SUB-EXP 3 -->` | delta_ratio verdict incl. **refutation branch** (U2/U6) | §5, §6 |
| `<!-- FILL ON SYNTHESIS VERDICT -->` | final Phase 2-bis disposition; recomputed activation posture | §6, §7 |

Each marker is paired with a pre-written **both-outcomes** stub (confirm / refute /
inconclusive) so no creative reframing happens at closure. `key_numbers`,
`honest_disclosures`, and `kill_criteria` arrays are pre-populated for the closed
evidence (v1, v1.5, Phase 2, Sub-exp 1) and carry placeholder rows tagged
`<!-- FILL -->` for the pending verdicts.

## §5 — Artifact 2: Anchor-doc polish

**Path:** [docs/research/2026-05-29-hadf-activation-orchid-validation-analysis.md](../../research/2026-05-29-hadf-activation-orchid-validation-analysis.md)

Completable-now edits only:
- Tighten Parts 1–2 prose (clarity pass; no claim changes).
- Verify every cross-reference resolves to a real file; fix any broken relative
  paths.
- Add a forward back-link to the staged capstone (`37-orchid-research-arc`,
  noted as staged/dormant).
- Append a **"fill-in cell → capstone section"** mapping table mirroring §4.3, so
  the anchor and the capstone stay in lockstep at closure.
- Leave the "Completion plan" and all PENDING cells exactly as the operator wrote
  them. No verdict invented; the `PARTIALLY SUPPORTED` disposition is preserved.

## §6 — Artifact 3: Publication-readiness plan

**Path:** `docs/superpowers/plans/2026-05-30-orchid-research-capstone-publication-readiness.md`

Contents:
- **Fill matrix** — every fill-in marker → which sub-exp/verdict closes it → which
  anchor cell + capstone section it populates → both-outcomes branch.
- **Slot/order/version/date decisions** — slot 37, `order: 37`, `version: '7.9'`,
  chronological-order rationale vs. the publish-verbatim + slot-order rule (a
  v7.9 capstone that looks *back* across the arc slots after the v7.8.3 work at
  22.x and before/at 37 — verified non-conflicting).
- **Dormancy → live flip steps** — rename `.mdx.draft → .mdx`; set `tier: standard`;
  set `date`; apply the staged hub diff (§7).
- **Publish-day sequence** — flip → `npm run build` (Zod schema gate: `visual_aid`
  OR `key_numbers`; `tldr` present) → local route check at
  `/case-studies/orchid-research-arc` → chronological-order check → PR with
  Figma/PR-citation norms as applicable.
- **Gate checklist** — external Audit #2 (2026-06-12) dependency; resolve
  `kill_criterion_fired`; Q6 PR-list parity; confirm Sub-exp 3 outcome branch
  selected.

## §7 — Artifact 4: Site research-hub refresh (staged as documented diff)

To keep "not for publish" literally true, hub edits are **described as a diff in
the readiness plan**, not committed live:
- `fitme-story/src/app/research/page.tsx` — add a `RESEARCH[]` entry pointing at
  `/case-studies/orchid-research-arc` (applied only on publish day).
- `fitme-story/content/05-research/orchid-accelerator.mdx` — add a pointer line to
  the capstone.

(If the operator prefers, these can instead be committed live alongside the
dormant `.mdx.draft` — they reference a slug that won't route until publish, so
the link would 404 until then. Default is the documented-diff approach.)

## §8 — Components & interfaces

| Unit | Purpose | Depends on | Touched? |
|---|---|---|---|
| Capstone `.mdx.draft` | The publication content, dormant | content loader (by absence) | **new** |
| Anchor doc | Research convergence point | the closed + pending HADF data | **edited (additive)** |
| Readiness plan | Deterministic publish runbook | capstone + anchor + HADF calendar | **new** |
| Hub diff (documented) | Site surface integration | capstone slug | **described, not applied** |
| This spec | Formal design of the prep | the above | **new** |

Each unit is independently understandable and testable: the capstone renders
correctly once renamed (verifiable by `npm run build`); the anchor edits are
additive and reversible; the readiness plan is a checklist; the hub diff is inert
text until applied.

## §9 — Testing / verification

- **Dormancy proof:** with the `.mdx.draft` staged, `npm run build` in fitme-story
  produces **no** new route and the build stays green (file invisible to loader).
- **Publish-rehearsal (local only, reverted):** temporarily rename to `.mdx`,
  `npm run build`, confirm the route renders and Zod passes, then revert. Done
  once during impl as a smoke check; not committed.
- **Cross-ref integrity:** every link in the anchor + spec + plan resolves.
- **No-leak check:** `git status` shows only intended staged files; no live tier,
  no `date`, no hub-code commit.

## §10 — Risks & mitigations

| Risk | Mitigation |
|---|---|
| Accidental publish (file ends in `.mdx`) | `.mdx.draft` extension + explicit publish-day rename step; no-leak check in §9 |
| Sub-exp 3 refutes HADF | Both-outcomes stubs pre-written; readiness plan selects branch at closure |
| Numbers drift between anchor & capstone | Single source of truth = anchor; capstone pulls at fill-in; mapping table keeps lockstep |
| Entangling operator's freshness-reconcile WIP | Fresh branch off main, confirmed before commit |
| Synthesis slips past Audit #2 | Readiness plan lists Audit #2 as an explicit gate, not an assumption |

## §11 — Definition of done (for the prep)

- `37-orchid-research-arc.mdx.draft` staged with complete frontmatter + 7-section
  spine + fill-in markers + both-outcomes stubs.
- Anchor doc polished (additive) with mapping table + capstone back-link.
- Readiness plan written with fill matrix + publish-day sequence + gates.
- Hub diff documented in the readiness plan.
- `npm run build` green with the draft present (dormancy proven).
- Nothing published; branch confirmed; spec + plan committed.
