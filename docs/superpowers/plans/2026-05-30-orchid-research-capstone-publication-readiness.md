# Orchid Research Capstone — Publication-Readiness Plan

**Status:** staged / not published. **Created:** 2026-05-30. **Framework version:** v7.9 (Phase E soak).

This is the deterministic publish-day runbook for the dormant capstone draft at
`fitme-story/content/04-case-studies/37-orchid-research-arc.mdx.draft`. It exists
so that publishing — once HADF Sub-exps 2 & 3 close and the Phase 2-bis synthesis
verdict resolves — is a **mechanical flip**, not a fresh authoring pass.

**Do not execute any step here until the gate checklist (§5) is fully green.**

## Inputs (single sources of truth)

- **Research anchor:** [`docs/research/2026-05-29-hadf-activation-orchid-validation-analysis.md`](../../research/2026-05-29-hadf-activation-orchid-validation-analysis.md) — all numbers + verdicts pull from here.
- **Prep spec:** [`docs/superpowers/specs/2026-05-30-orchid-research-capstone-design.md`](../specs/2026-05-30-orchid-research-capstone-design.md).
- **The draft:** `fitme-story/content/04-case-studies/37-orchid-research-arc.mdx.draft`.
- **Schema:** `fitme-story/src/lib/content-schema.ts` (Zod gate: `visual_aid` OR non-empty `key_numbers`, plus `tldr`).

## 1 — Fill matrix (3 marker types → verdict → anchor cell → capstone section)

Each marker type appears in the draft as `<!-- FILL ON ... -->` paired with a
pre-written both-outcomes stub. At closure, **select one branch and delete the
stub comment**, then add the matching `key_numbers` row in frontmatter.

| Marker | Closes from (ETA) | Threshold | Anchor cell it resolves | Capstone section(s) | Branch to select |
|---|---|---|---|---|---|
| `FILL ON SUB-EXP 2` | Sub-exp 2 (~2026-05-30) | KS p < 0.01 | §1.3 device_modifier readiness; §2.2 U7/U3 rows | §5, §6 | (a) SEPARABLE → device_modifier eligible >0.7; U7 8×8 compute-bound / (b) NOT SEPARABLE → device advisory; U7/U3 forks open |
| `FILL ON SUB-EXP 3` | Sub-exp 3 (~2026-05-31) | delta_ratio (**< 1.0 REFUTES**) | §1.3 routing-layer readiness; §2.2 U2/U6 rows | §5, §6 | (a) CONFIRM >2.0 → build U2/U6 / (b) INCONCLUSIVE 1.0–2.0 → hold / (c) REFUTE <1.0 → do NOT build; record negative result |
| `FILL ON SYNTHESIS VERDICT` | Phase 2-bis synthesis (~2026-06-04) | combination of 1/2/3 | replaces `PARTIALLY SUPPORTED` disposition; recomputes activation posture | §6, §7 | Mirror the 22c verdict-logic table; do not soften a refutation |

**Symmetry invariant:** exactly **3** marker types in the draft ↔ **3** rows here
↔ **3** rows in the anchor's "Capstone fill-in map". Verify before and after fill-in
(`grep -oE 'FILL ON (SUB-EXP 2|SUB-EXP 3|SYNTHESIS VERDICT)' <draft> | sort -u | wc -l` → `3`).

## 2 — Slot / order / version / date decisions

- **Slot / order:** `37` (filename prefix `37-`, `timeline_position.order: 37`). Highest live numeric slot at staging time is **36** — no collision. (Verify again at publish: `ls fitme-story/content/04-case-studies/ | sort`.)
- **Version:** `timeline_position.version: '7.9'` — the capstone *ships* at v7.9 and looks back across the arc (v5–v6 Orchid v1 → v7.7 v1.5 → v7.9 HADF activation). Chronologically legitimate per the publish-verbatim + slot-order rule: a v7.9 piece slots after the v7.8.3 work at 22.x and at the current frontier (37).
- **Date:** the `date:` key is **omitted** while dormant. On publish, set `date:` to the actual publication date (NOT the synthesis date unless they coincide).
- **Tier:** `standard` (already set as the live value; dormancy is via the extension, not the tier).

## 3 — Dormancy → live flip (exact ordered steps)

1. `cd /Volumes/DevSSD/fitme-story && git mv content/04-case-studies/37-orchid-research-arc.mdx.draft content/04-case-studies/37-orchid-research-arc.mdx`
2. Confirm frontmatter `tier: standard` (already set).
3. Add `date: '<PUBLISH-DATE>'` to frontmatter.
4. For each of the 3 marker types: replace the `<!-- FILL ON ... -->` line + its `<!-- STUB ... -->` comment with the selected branch prose; add the matching `key_numbers` row (the `# FILL ON ...` YAML-comment placeholders in `key_numbers` mark where).
5. Remove the top-of-file dormancy header comment block (the `# ===` banner) — it is no longer accurate once the file is live.
6. Apply the hub diff (§4).

## 4 — Site research-hub diff (APPLY ON PUBLISH DAY ONLY — not applied during prep)

**(a) `fitme-story/src/app/research/page.tsx`** — add the capstone to the `RESEARCH[]` array (match the existing entry object shape in that file at publish time):

```diff
   const RESEARCH = [
+    {
+      // Orchid research-arc capstone
+      href: '/case-studies/orchid-research-arc',
+      title: 'Orchid — From Dispatch Patterns to Silicon, Validated by Measurement',
+      blurb: 'The capstone of the Orchid arc: PM-framework dispatch intelligence as a RISC-V accelerator, validated by the HADF measurement program.',
+    },
     // ...existing entries...
   ];
```

**(b) `fitme-story/content/05-research/orchid-accelerator.mdx`** — add a pointer line near the top of the body:

```diff
+ > **Capstone:** the full Orchid research arc — v1 → v1.5 → framework-v7 silicon
+ > mapping → HADF empirical validation — is collected in
+ > [Orchid — From Dispatch Patterns to Silicon](/case-studies/orchid-research-arc).
```

> Both edits reference the `orchid-research-arc` slug, which only routes once the
> `.mdx.draft` → `.mdx` rename (§3 step 1) lands. Applying them earlier would
> create a dead link — hence "publish day only".

## 5 — Gate checklist (ALL must be green before §3)

- [ ] HADF Sub-exp 2 verdict closed; branch selected for `FILL ON SUB-EXP 2`.
- [ ] HADF Sub-exp 3 verdict closed; branch selected for `FILL ON SUB-EXP 3` (incl. the **refutation** branch if delta_ratio < 1.0).
- [ ] Phase 2-bis synthesis verdict resolved; `FILL ON SYNTHESIS VERDICT` branch selected.
- [ ] External **Audit #2 (2026-06-12)** has covered the raw HADF `.jsonl` + verdict scripts + anchor-drift (the anchor's §1.4 audit-chain claim).
- [ ] `kill_criterion_fired` re-evaluated against all closed sub-exps and set correctly.
- [ ] Anchor doc's PENDING cells resolved consistently with the draft (single-source-of-truth check).
- [ ] Q6 PR-list parity: any PRs cited in the capstone are reflected in the relevant state.json `related_prs` (and vice versa).

## 6 — Publish-day sequence (after §5 green, §3 done)

1. `cd /Volumes/DevSSD/fitme-story && npm run build` — expect SUCCESS and a generated route for `/case-studies/orchid-research-arc` (Zod gate passes: `visual_aid` OR non-empty `key_numbers`; `tldr` present).
2. Local route check: `npm run dev`, visit `http://localhost:3000/case-studies/orchid-research-arc`, confirm it renders (LightTemplate/StandardTemplate per tier `standard`) and prev/next siblings resolve.
3. Chronological-order check: confirm slot 37 / `order: 37` sits correctly relative to neighbors in the `/case-studies` listing (sorted by `timeline_position.order`).
4. Marker-residue check: `grep -c 'FILL ON' content/04-case-studies/37-orchid-research-arc.mdx` → `0` (no fill markers left live).
5. Open the PR honoring PR-citation norms (and Figma-node norms only if any UI component changed — this is content-only, so n/a). Per repo rule, branch + commit + push only on operator authorization.

## 7 — Reversibility

If a verdict arrives that contraindicates publication (e.g. Sub-exp 3 refutes and
the operator wants to hold), revert is trivial: `git mv` the file back to
`.mdx.draft` (or simply never run §3). The dormant state is the safe default; the
flip is the only action that publishes.
