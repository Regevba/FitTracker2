# Orchid Research Capstone — Publication Prep Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stage a publish-ready Orchid research-arc capstone case study plus its supporting artifacts (anchor-doc polish, publication-readiness plan, documented hub diff) such that publish-day is a one-step flip and nothing goes live.

**Architecture:** A single dormant `.mdx.draft` file (invisible to the fitme-story content loader because it does not end in `.mdx`) holds the full publication; HADF-dependent content is gated behind greppable fill-in markers with both-outcomes stubs. Supporting docs live in the FitTracker2 repo. Verification is build-based (dormancy proof) and link/no-leak checks, not unit tests.

**Tech Stack:** Markdown/MDX, YAML frontmatter, Next.js 16 (fitme-story content loader + Zod `FrontmatterSchema`), git.

**Repos & branch:** Capstone draft + hub diff target `/Volumes/DevSSD/fitme-story`; spec/plan/anchor live in `/Volumes/DevSSD/FitTracker2`. Work on a fresh `docs/orchid-research-capstone-prep` branch off `main` in each repo as needed. **All commits are batched into Task 6 and held until the operator authorizes.**

**Source of truth for numbers:** `docs/research/2026-05-29-hadf-activation-orchid-validation-analysis.md` (the anchor) + the upstream case studies. Do not invent figures; pull verbatim.

---

### Task 1: Author the dormant capstone `.mdx.draft`

**Files:**
- Read (for exact schema): `/Volumes/DevSSD/fitme-story/src/lib/content-schema.ts`
- Read (for real frontmatter shape): `/Volumes/DevSSD/fitme-story/content/04-case-studies/33c-hadf-phase2bis-cross-sub-exp-synthesis.mdx`
- Read (closed-evidence numbers): `/Volumes/DevSSD/FitTracker2/docs/research/2026-05-29-hadf-activation-orchid-validation-analysis.md`, `/Volumes/DevSSD/FitTracker2/docs/case-studies/orchid-ai-accelerator-case-study.md`
- Create: `/Volumes/DevSSD/fitme-story/content/04-case-studies/37-orchid-research-arc.mdx.draft`

- [ ] **Step 1: Resolve the real frontmatter shape.**

Read `content-schema.ts` and `33c-hadf-phase2bis-cross-sub-exp-synthesis.mdx`. Determine authoritatively whether version/order are flat (`version:` / `order:`) or nested under `timeline_position:` — `content.ts` sorts on `frontmatter.timeline_position?.order`, but the 22b/22c files may use flat keys. Match whatever 22c actually uses. Record the resolved shape in a one-line comment at the top of the draft body (HTML comment) for the next worker.

- [ ] **Step 2: Write the frontmatter block.**

Use the resolved shape. Required: `title`, `slug: orchid-research-arc`, `tier: standard`, `tldr` (one sentence). Include: `status: draft`, version `7.9` + order `37` (in the resolved shape), `date_written: '2026-05-30'`, NO `date` key (commented out: `# date: SET ON PUBLISH DAY`), `upstream_path`, `spec`, `plan`, `predecessor_case_studies: [12-hadf, 22b-hadf-phase2-cloud-fingerprinting, 33c-hadf-phase2bis-cross-sub-exp-synthesis]`, `external_audit_status: pending`, `kill_criterion_fired: false`, `persona_emphasis` (hr/pm/dev/academic), and a `visual_aid` (component `FrameworkAdvancement`; if its `data` shape is unclear from existing usages, fall back to a non-empty `key_numbers` array which the schema also accepts). Pre-populate `key_numbers`, `honest_disclosures`, `kill_criteria` for CLOSED evidence only (see Step 4).

- [ ] **Step 3: Write the 7-section narrative spine (closed-evidence prose).**

Author sections 1–4 fully (no gating needed — all closed):
  1. Thesis — orchestration as a silicon problem; Orchid IS/IS NOT.
  2. v1 behavioral proof — 25,305 runs [T1], 0 invariant violations [T1], `prefetch_ahead` variance leader, cache-thrash cliff.
  3. v1.5 additive units — U8 Patrol Scrubber, U9 Validation Bus, T1/T2/T3 on TileLink `user[1:0]`, U3 PMU; Option B vs v2 rewrite; Tracks L+D shipped (PRs #179/#180/#182/#183/#184), Track R blocked, D3 deferred — stated honestly.
  4. framework-v7 silicon mapping — v7.1→U8, v7.5→U9, data tiers→tier bits, v7.6/7.7→assertion_mode/split channels.
Tier-tag every quantitative claim (T1/T2/T3). Pull numbers verbatim from the anchor + v1 case study.

- [ ] **Step 4: Pre-populate frontmatter arrays for closed evidence.**

`key_numbers`: Phase 2 silhouette + Sub-exp 1 silhouette + delta + n_valid + cost (all [T1], values from the anchor §1.1 table). `honest_disclosures`: PARTIALLY-SUPPORTED disposition; T3-over-T1 scoped to 4 endpoints; synthesis PENDING; Track R blocked. `kill_criteria`: the v1.5 spec's three (U8 patrol >5%, U9 starvation, tier critical-path >2 cycles) + the Sub-exp 3 refutation floor (`delta_ratio < 1.0`). Add placeholder rows tagged `# FILL` (YAML comment) where a pending verdict supplies the value.

- [ ] **Step 5: Write sections 5–7 with fill-in markers + both-outcomes stubs.**

Sections 5 (HADF validation) and 6 (activation posture) contain the gated content. For each gated claim, write the marker on its own line and follow it with a pre-written stub covering every outcome:

```markdown
<!-- FILL ON SUB-EXP 2 -->
<!-- STUB (select one at closure):
 (a) SEPARABLE (KS p < 0.01): local/cloud occupy distinct regions → U7 sizing leans 8×8 compute-bound; device_modifier eligible for >0.7.
 (b) NOT SEPARABLE: device branch stays advisory; revives U8 DRAM-patrol question; on-device modifier held ≤0.7.
-->

<!-- FILL ON SUB-EXP 3 -->
<!-- STUB (select one at closure):
 (a) CONFIRM (delta_ratio > 2.0): routing-layer signal real → build U2 routing-class field + U6 multi-layer coherence.
 (b) INCONCLUSIVE (1.0 ≤ ratio ≤ 2.0): hold U2/U6; advisory only.
 (c) REFUTE (delta_ratio < 1.0): HADF routing axis FALSIFIED → do NOT build U2 routing-aware mode; document the negative result prominently.
-->
```

Section 7 (honest close) carries `<!-- FILL ON SYNTHESIS VERDICT -->` with a stub for the final disposition + recomputed activation posture across confirm/refute combinations.

- [ ] **Step 6: Verify the file is dormant by construction.**

Run: `ls /Volumes/DevSSD/fitme-story/content/04-case-studies/37-orchid-research-arc.mdx.draft && basename ...mdx.draft | grep -q '\.mdx$' && echo ROUTABLE || echo DORMANT`
Expected: `DORMANT` (filename does NOT end in `.mdx`).

- [ ] **Step 7: Validate frontmatter YAML parses.**

Run: `cd /Volumes/DevSSD/fitme-story && node -e "const m=require('gray-matter');const fs=require('fs');console.log(Object.keys(m(fs.readFileSync('content/04-case-studies/37-orchid-research-arc.mdx.draft','utf8')).data))"`
Expected: prints the frontmatter keys (proves valid YAML). If `gray-matter` isn't resolvable standalone, instead copy to a temp `.mdx`, run `npm run build`, confirm Zod passes, delete the temp (this is the Task 2 rehearsal — may defer the check there).

---

### Task 2: Dormancy proof (build green, no new route)

**Files:** none modified (verification only)

- [ ] **Step 1: Build with the draft present.**

Run: `cd /Volumes/DevSSD/fitme-story && npm run build`
Expected: build SUCCEEDS; no route for `/case-studies/orchid-research-arc` appears in the route manifest output (grep the build log: `npm run build 2>&1 | grep -c orchid-research-arc` → `0`).

- [ ] **Step 2: Publish-rehearsal (local, reverted).**

Run: `cd /Volumes/DevSSD/fitme-story && cp content/04-case-studies/37-orchid-research-arc.mdx.draft content/04-case-studies/_rehearsal-orchid.mdx && npm run build 2>&1 | grep -c orchid && rm content/04-case-studies/_rehearsal-orchid.mdx`
Expected: with the temp `.mdx` present the route IS generated AND Zod passes (proves the frontmatter is publish-valid); after `rm`, re-running build returns to no-route. Confirm the temp file is deleted: `ls content/04-case-studies/_rehearsal-orchid.mdx` → no such file.

> If `npm run build` is too heavy/slow in this environment, substitute a targeted loader check: `node -e` that imports the dir listing logic and asserts the `.mdx.draft` is excluded. Note the substitution in the execution log.

---

### Task 3: Polish the research anchor doc (additive only)

**Files:**
- Modify: `/Volumes/DevSSD/FitTracker2/docs/research/2026-05-29-hadf-activation-orchid-validation-analysis.md`

- [ ] **Step 1: Cross-ref integrity pass.**

For each relative link in the anchor's "Cross-references" section, confirm the target file exists. Run: `cd /Volumes/DevSSD/FitTracker2 && for f in docs/case-studies/hadf-phase2-cloud-fingerprinting-case-study.md docs/case-studies/hadf-phase2bis-cross-sub-exp-synthesis-case-study.md docs/case-studies/hadf-hardware-aware-dispatch-case-study.md docs/research/2026-05-12-hadf-phase2bis-orchid-integration.md docs/research/2026-04-28-orchid-framework-v7-mapping.md docs/superpowers/specs/2026-05-03-orchid-v1-5-design.md .claude/shared/dispatch-intelligence.json; do test -e "$f" && echo "OK $f" || echo "MISSING $f"; done`
Expected: all `OK`. Fix any `MISSING` path in the anchor.

- [ ] **Step 2: Light prose tighten on Parts 1–2.**

Clarity edits only — NO claim changes, NO verdict invention. Preserve the Honesty preamble, the `PARTIALLY SUPPORTED` disposition, the "Completion plan" block, and every PENDING cell verbatim in meaning.

- [ ] **Step 3: Add a forward back-link.**

Under "Cross-references", add: a line noting the staged (dormant) capstone at `fitme-story/content/04-case-studies/37-orchid-research-arc.mdx.draft` and the prep spec/plan paths.

- [ ] **Step 4: Append the fill-in mapping table.**

At the end of the anchor, add a section "Capstone fill-in map" with a table mirroring the implementation plan / spec §4.3: `marker → anchor cell that closes it → capstone section it populates → both-outcomes branch`. This keeps anchor and capstone in lockstep at closure.

- [ ] **Step 5: Verify additive-only.**

Run: `cd /Volumes/DevSSD/FitTracker2 && git diff --stat docs/research/2026-05-29-hadf-activation-orchid-validation-analysis.md`
Expected: insertions dominate; spot-check `git diff` shows no PENDING cell flipped to a verdict and no number changed.

---

### Task 4: Write the publication-readiness plan

**Files:**
- Create: `/Volumes/DevSSD/FitTracker2/docs/superpowers/plans/2026-05-30-orchid-research-capstone-publication-readiness.md`

- [ ] **Step 1: Write the fill matrix.**

A table: each fill-in marker → the sub-exp/verdict that closes it (Sub-exp 2 ~05-30, Sub-exp 3 ~05-31, synthesis ~06-04) → the anchor cell + capstone section it populates → the both-outcomes branch to select. One row per marker; must match Task 1 Step 5 and Task 3 Step 4 exactly.

- [ ] **Step 2: Write the slot/order/version/date decisions.**

Record: slot 37, `order: 37`, `version: '7.9'`. Rationale vs. the publish-verbatim + chronological-slot-order rule: a v7.9 capstone that looks back across the arc legitimately slots at 37 (after the v7.8.3 work at 22.x). Confirm no existing slot ≥37 collides (`ls /Volumes/DevSSD/fitme-story/content/04-case-studies/ | sort` — highest is currently 36).

- [ ] **Step 3: Write the dormancy → live flip steps.**

Exact ordered steps: (1) `git mv 37-orchid-research-arc.mdx.draft 37-orchid-research-arc.mdx`; (2) confirm `tier: standard`; (3) set `date:` to the publish date; (4) replace each fill-in marker with the selected branch; (5) apply the documented hub diff (Step 5).

- [ ] **Step 4: Write the publish-day sequence + gate checklist.**

Sequence: flip → `npm run build` (Zod gate: `visual_aid` OR non-empty `key_numbers`; `tldr` present) → local route check at `/case-studies/orchid-research-arc` → chronological-order check → open PR honoring PR-citation + (if any UI) Figma-node norms. Gates: external Audit #2 (2026-06-12) must have covered the raw HADF data; `kill_criterion_fired` resolved; Q6 PR-list parity; Sub-exp 3 outcome branch selected.

- [ ] **Step 5: Document the hub diff (not applied).**

Write the exact intended edits as fenced diffs: (a) `fitme-story/src/app/research/page.tsx` — new `RESEARCH[]` entry pointing at `/case-studies/orchid-research-arc`; (b) `fitme-story/content/05-research/orchid-accelerator.mdx` — a pointer line to the capstone. Mark both "APPLY ON PUBLISH DAY ONLY".

---

### Task 5: Verification sweep (no-leak + cross-ref)

**Files:** none modified (verification only)

- [ ] **Step 1: No-leak check (both repos).**

Run: `cd /Volumes/DevSSD/fitme-story && git status --porcelain` and `cd /Volumes/DevSSD/FitTracker2 && git status --porcelain`
Expected: fitme-story shows ONLY `37-orchid-research-arc.mdx.draft` (untracked). FitTracker2 shows the spec, this plan, the readiness plan, and the anchor doc (+ pre-existing operator changes from the reconcile branch, which we leave untouched). Confirm: no `.mdx` (live) capstone, no `date:` set, no edit to `research/page.tsx` or `orchid-accelerator.mdx`.

- [ ] **Step 2: Cross-ref integrity across all new docs.**

Run a link check: for the spec, this plan, and the readiness plan, confirm every referenced path exists (same loop pattern as Task 3 Step 1). Expected: all `OK`.

- [ ] **Step 3: Marker symmetry check.**

Run: `grep -c 'FILL ON' /Volumes/DevSSD/fitme-story/content/04-case-studies/37-orchid-research-arc.mdx.draft` and confirm the count matches the fill-matrix row count in the readiness plan and the mapping table in the anchor. Expected: three counts equal.

---

### Task 6: Commit (batched — execute ONLY on operator authorization)

**Files:** all of the above.

- [ ] **Step 1: Confirm SSH/signing agent is live (pre-commit).**

Run: `ssh-add -l`
Expected: at least one identity. If empty, surface to operator (signing will silently hang otherwise — load YubiKey or switch to Touch ID via `git sign-tid`). Do NOT proceed to commit until resolved.

- [ ] **Step 2: Branch + commit in FitTracker2.**

```bash
cd /Volumes/DevSSD/FitTracker2
git checkout -b docs/orchid-research-capstone-prep
git add docs/superpowers/specs/2026-05-30-orchid-research-capstone-design.md \
        docs/superpowers/plans/2026-05-30-orchid-research-capstone-prep.md \
        docs/superpowers/plans/2026-05-30-orchid-research-capstone-publication-readiness.md \
        docs/research/2026-05-29-hadf-activation-orchid-validation-analysis.md
git commit -m "docs(orchid): stage research-arc capstone publication prep (not for publish)"
```

> NOTE: the anchor doc is currently untracked on `chore/freshness-reconcile-2026-05-29`. Creating the new branch off the current HEAD carries the untracked file into the new branch's working tree; that is intended (anchor lands with this prep). If the operator wants the branch strictly off `main`, stash/move the untracked anchor first.

- [ ] **Step 3: Branch + commit in fitme-story.**

```bash
cd /Volumes/DevSSD/fitme-story
git checkout -b docs/orchid-research-capstone-prep
git add content/04-case-studies/37-orchid-research-arc.mdx.draft
git commit -m "docs(orchid): stage dormant research-arc capstone draft (.mdx.draft, not for publish)"
```

- [ ] **Step 4: Report.**

Summarize: files staged, dormancy proven, nothing published, both branches local (not pushed unless operator asks). Surface the publish-day runbook location.

---

## Self-Review

**Spec coverage:**
- §4 capstone MDX → Task 1 (+ dormancy Task 2). ✓
- §5 anchor polish → Task 3. ✓
- §6 readiness plan → Task 4. ✓
- §7 hub diff (documented) → Task 4 Step 5. ✓
- §9 verification (dormancy proof, publish-rehearsal, cross-ref, no-leak) → Tasks 2 + 5. ✓
- §3.1 dormancy mechanism → Task 1 Step 6 + Task 2. ✓
- §3.2 honesty / both-outcomes / Sub-exp-3 refutation → Task 1 Steps 4–5. ✓
- §3.3 branch isolation / fresh branch / commit hold → Task 6. ✓
- §11 definition of done → Tasks 1–5 collectively; commit = Task 6. ✓

**Placeholder scan:** No "TBD/TODO/handle edge cases" in actionable steps. The `<!-- FILL -->` markers are deliberate artifact content (the whole point of the prep), not plan placeholders, and each is paired with a fully-written both-outcomes stub. ✓

**Type/name consistency:** "fill-in marker", "both-outcomes stub", slug `orchid-research-arc`, slot/order `37`, version `7.9`, `tier: standard`, `.mdx.draft` extension used identically across all tasks and the spec. The three-way marker-count symmetry (draft ↔ readiness fill-matrix ↔ anchor mapping table) is asserted in Task 5 Step 3. ✓

**Known verify-at-execution item:** flat `version:`/`order:` vs nested `timeline_position:` — resolved authoritatively in Task 1 Step 1 by reading the real 22c file before authoring.
