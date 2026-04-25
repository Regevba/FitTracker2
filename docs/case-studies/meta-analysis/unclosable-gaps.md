# Mechanically Unclosable Gaps — v7.6 Class B Inventory

> **Generated:** 2026-04-25
> **Framework version at publication:** 7.6 (Mechanical Enforcement)
> **Authoritative companion:** [docs/case-studies/mechanical-enforcement-v7-6-case-study.md](/docs/case-studies/mechanical-enforcement-v7-6-case-study.md)
> **Policy precedent:** [`feedback_publish_verbatim_then_remediate.md`](../../.claude/feedback/) — gaps stay visible; we do not collapse them silently.

The v7.6 work promoted **4 silent gaps** (Class B → Class A) into write-time pre-commit failures and added **3 recurring per-PR / weekly checks**. After that promotion, **5 gaps remain mechanically unclosable** by physical or policy necessity. This document enumerates them so the gap is visible in the audit trail rather than buried in agent behavior.

A gap is "Class A" when a deterministic check (pre-commit, CI, status check) blocks the failing state from reaching `main`. A gap is "Class B" when only narrative discipline, agent attention, or post-hoc human review can catch it. **Class B is not a bug per se** — some gaps cannot be Class A without lying about what the system can verify. The purpose of this document is to make Class B status explicit and tracked.

---

## Gap 1 — `cache_hits[]` writer-path adoption

**Tier:** 1.1 sub-gap
**Class:** B (agent-attention)
**Tracked by:** [GitHub issue #140](https://github.com/Regevba/FitTracker2/issues/140)

### Why it cannot be mechanically closed

A `cache_hits` event records that an agent reused a piece of prior knowledge — a skill output, a doc snippet, a prior plan, a memory entry — instead of re-deriving it. The decision to *recognize* something as a cache hit is itself a judgment call: the agent has to notice "I am now applying a pattern I have seen before" while it is producing new code. No pre-commit hook can detect that a line of generated code "felt like" reuse without actually reading the agent's reasoning trace, which is not present in the diff.

What we *can* check: the file exists, the schema is valid, and the writer-path API works end-to-end. We added all three in v7.5/v7.6:
- `scripts/append-feature-log.py` accepts `--cache-hit {L1,L2,L3}` + `--cache-key` + `--cache-hit-type {adapted,exact,miss}` + `--cache-skill`.
- `state.json.cache_hits[]` is written atomically when those flags fire.
- Schema check rejects malformed entries.

What we *cannot* check: whether the agent *should have* logged a cache hit on commit X but didn't.

### What we observe instead

- **Per-feature:** `.claude/features/<feature>/state.json.cache_hits[]` length.
- **Aggregate:** `make measurement-adoption` reports `cache_hits: N/M post-v6 (X%)`. As of 2026-04-25 the count is **2/7 post-v6 (28.6%)**.
- **Trend:** weekly cron snapshots accumulate in `.claude/shared/measurement-adoption-history.json`; once 3+ snapshots accumulate the regression watcher will flag any decrease in `any_adopted` count.

### What a human can do to close it

1. Audit a sample of recent commits and ask: "did this look like a cache hit that wasn't logged?"
2. If yes, append a retroactive log entry via `python3 scripts/append-feature-log.py --feature <name> --retroactive --retroactive-reason "audit-found unlogged cache hit on commit <sha>" --cache-hit L2 --cache-key "<key>" --cache-skill "<source>"`.
3. The retroactive flag flips the entry's `provenance` so it does not pretend to be contemporaneous.

### Tracking

- Issue: [#140](https://github.com/Regevba/FitTracker2/issues/140) — open until writer-path adoption climbs to ≥80% post-v6 features.
- Manifest field: `framework-manifest.json` → `tier_1_1_status.cache_hits_post_v6`.
- Closes when: not closeable mechanically. Best long-term mitigation is making `--cache-hit` so easy that agents reach for it reflexively (already partially achieved by adding it to the `append-feature-log.py` invocation in the standard PM workflow).

---

## Gap 2 — `cu_v2` complexity factor *correctness*

**Tier:** 2.3 / 1.1 sub-gap
**Class:** B (judgment-based)
**Tracked by:** measurement-adoption-report.py dimension `cu_v2`

### Why it cannot be mechanically closed

`complexity.cu_version=2` declares that a feature carries continuous-factor complexity scores: cross-feature coupling, novelty, blast radius, etc. We can check **presence** (`cu_version == 2`) and that the factors are inside `[0.0, 1.0]`. We cannot check that "novelty: 0.2" is *the right number* for this feature — that is a judgment call about how new the work is relative to prior features.

A pre-commit hook that asserted "novelty must be ≥ 0.5 if the feature touches a new top-level subsystem" would itself need to know what counts as a new subsystem, which is the same judgment call one layer up.

### What we observe instead

- **Presence:** `make measurement-adoption` reports `cu_v2: N/M post-v6 (X%)` — currently **4/7 post-v6 (57.1%)**.
- **Magnitude:** none. We do not aggregate the factor values themselves.

### What a human can do to close it

1. Periodically sample `state.json.complexity.factors` across recent features.
2. Compare the declared values against the post-hoc reality (did the cross-feature coupling actually bite? did the novelty produce surprises?).
3. Calibrate future declarations against the observed reality. This is the same loop as estimation calibration — it cannot be automated without first building a ground-truth dataset, which we do not have at FitTracker2's scale.

### Tracking

- No issue — accepted as Class B by design. Documented here as the canonical "we know this is judgment-based" record.

---

## Gap 3 — T1 / T2 / T3 tier label *correctness*

**Tier:** 2.3
**Class:** B (semantic-correctness)
**Tracked by:** v7.6 case-study preflight (`scripts/check-case-study-preflight.py` — `CASE_STUDY_MISSING_TIER_TAGS`)

### Why it cannot be mechanically closed

The Data Quality Tiers convention (T1=Instrumented, T2=Declared, T3=Narrative; see [`docs/case-studies/data-quality-tiers.md`](../data-quality-tiers.md)) requires every quantitative metric in case studies, PRDs, and meta-analyses to carry a tier tag. v7.6's preflight check (forward-only, dates ≥ 2026-04-21) verifies that the tag *exists*. It cannot verify that the tag is *right*.

Example: a case study might write "**5 features adopted v6.0** (T1 — Instrumented)" when in fact the number was hand-counted from a `git log | grep` command and not pulled from `measurement-adoption.json`. The tag says T1 but the provenance is T2 (Declared from a one-off command).

Distinguishing "T1 (from JSON file)" from "T2 (from a transient command)" requires reading the prose in context.

### What we observe instead

- **Presence:** preflight check fires at write-time on every staged case study; refuses to commit any post-2026-04-21 case study that contains a quantitative claim without a tier tag.
- **Date scope:** forward-only — case studies authored before 2026-04-21 are exempt (the convention did not exist).
- **Exemption list:** README, template, normalization-framework, plus `meta-analysis/` subfolder (audit history is read-only).

### What a human can do to close it

1. During code review, spot-check 1–2 quantitative claims per case study and verify the tag matches the actual provenance.
2. If a tag is wrong, prefer **append a correction** over silent edit (per `feedback_publish_verbatim_then_remediate`). Add an "Updated 2026-MM-DD" footnote with the corrected tag and reason.

### Tracking

- Convention doc: [`docs/case-studies/data-quality-tiers.md`](../data-quality-tiers.md).
- Preflight code: [`scripts/check-case-study-preflight.py`](../../../scripts/check-case-study-preflight.py).

---

## Gap 4 — Tier 2.1 manual real-provider auth checklist

**Tier:** 2.1
**Class:** B (requires-physical-device)
**Tracked by:** [`docs/setup/auth-runtime-verification-playbook.md`](../../setup/auth-runtime-verification-playbook.md)

### Why it cannot be mechanically closed

The Tier 2.1 runtime smoke gate (`make runtime-smoke PROFILE=sign_in_surface`) covers everything that can be verified from a Python test runner: which view renders, what view-tree shape, which tokens are referenced, which AuthService methods are wired. It cannot cover the actual Apple/Google sign-in handshake on a real iPhone simulator with a real Apple ID, because:

1. Apple's sign-in flow opens a system sheet that the test runner cannot drive.
2. Google's OAuth flow opens an in-app webview which is sandboxed from XCUITest in ways that would require fragile workarounds.
3. The handshake produces tokens whose validity must be verified against live Supabase + CloudKit endpoints — a test could mock them, but mocking is exactly the failure mode the v7.5 framework was built to avoid.

So the closing step is a human running the playbook on a real device.

### What we observe instead

- **Mechanical:** `make runtime-smoke PROFILE=sign_in_surface MODE=local` validates view-tree, AuthService wiring, dispatch.
- **Manual:** the playbook documents 6 manual checklist items (Apple sign-in, Google sign-in, sign-out, account deletion, error states, network-loss). Each item names the expected observation and how to record the result.

### What a human can do to close it

1. Run the playbook on a real iPhone simulator + real Apple/Google credentials.
2. Append a dated entry to `.claude/features/authentication/state.json.runtime_verifications[]`.
3. Re-run quarterly (Apple/Google drift their flows) — a calendar check, not a CI check.

### Tracking

- Playbook: [`docs/setup/auth-runtime-verification-playbook.md`](../../setup/auth-runtime-verification-playbook.md).
- No issue — accepted as Class B by physical necessity.

---

## Gap 5 — Tier 3.3 external replication

**Tier:** 3.3
**Class:** B (requires-external-operator)
**Tracked by:** Public GitHub issue (filed as the **last** v7.6 deliverable)

### Why it cannot be mechanically closed

Every other v7.5 / v7.6 measurement runs against this repo by this author. That is the definition of a self-referential audit: the framework is grading its own homework with the same judgment that produced the homework. The mitigation Gemini called for (Tier 3.3) is to invite an **independent operator on an unrelated product** to run `/pm-workflow` start-to-finish and report whether the framework is reproducible without our hand-holding.

No pre-commit hook can simulate "did an external operator succeed with this." We have to ship a public invitation and wait.

### What we observe instead

- **Local:** every framework capability used internally; case studies published.
- **External:** zero independent operators have run the framework. This is the load-bearing limitation of every measurement we publish — including v7.6's own case study (see "Outlier Limitations" section there).

### What a human can do to close it

1. (We:) file the public GitHub issue inviting external operators (this is the explicit final v7.6 step, sequenced after every other deliverable per user instruction 2026-04-25).
2. (External operator:) clone the framework, run `/pm-workflow` on an unrelated product, post results.
3. (We:) publish their results verbatim per the publish-verbatim policy. If the framework misbehaves on their workload, we own the gap publicly.

### Tracking

- Public issue: **[#142](https://github.com/Regevba/FitTracker2/issues/142)** — filed and pinned 2026-04-25 as the explicit final v7.6 deliverable, per [Phase 3c sequencing](../../superpowers/plans/2026-04-25-v7-6-mechanical-enforcement-phases-2-4.md). Labels: `tier-3-3`, `external-replication`, `help wanted`.
- Closes when: at least one external case study lands in [`docs/case-studies/external/`](../external/) (directory does not exist yet — created on first external submission).

---

## Class A vs Class B — v7.5 → v7.6 promotions

| Concern | v7.5 status | v7.6 status | Promoted? |
|---|---|---|---|
| Schema drift (legacy `phase` key) | Class A (pre-commit) | Class A | — already A in v7.5 |
| PR number unresolved | Class A (pre-commit) | Class A | — already A in v7.5 |
| Phase transition w/ no log entry | Class B (agent-attention) | **Class A (pre-commit)** | ✅ v7.6 Phase 1 |
| Phase transition w/ no timing update | Class B (agent-attention) | **Class A (pre-commit)** | ✅ v7.6 Phase 1 |
| Broken PR citation in case study | Class B (post-hoc audit) | **Class A (pre-commit, write-time)** | ✅ v7.6 Phase 1 |
| Case study missing tier tags | Class B (post-hoc audit) | **Class A (pre-commit, write-time)** | ✅ v7.6 Phase 1 |
| New findings vs main on a PR | Class B (manual review) | **Class A (per-PR status check)** | ✅ v7.6 Phase 2a |
| Measurement-adoption regression (week-over-week) | Class B (no signal) | **Class A (weekly cron + issue)** | ✅ v7.6 Phase 2c |
| Append-only adoption history | Class B (no record) | **Class A (per-snapshot dedup)** | ✅ v7.6 Phase 2b |
| `cache_hits[]` writer-path adoption | Class B | Class B | — Gap 1 |
| `cu_v2` factor magnitudes | Class B | Class B | — Gap 2 |
| T1/T2/T3 tag *correctness* | Class B | Class B | — Gap 3 (we promoted *presence* to Class A; correctness stays Class B) |
| Tier 2.1 real-provider auth | Class B | Class B | — Gap 4 |
| Tier 3.3 external replication | Class B | Class B | — Gap 5 |

**Aggregate:** v7.6 promoted 7 concerns from Class B to Class A (4 write-time pre-commit, 1 per-PR status check, 1 weekly regression watcher, 1 append-only history). 5 concerns remain genuinely Class B. The Class B set is now exhaustively documented and individually justified, which is itself a v7.6 deliverable: a system that knows what it cannot check is more trustworthy than one that pretends every check is a check.

---

## How to read this document

If a future audit (or external review per Gap 5) finds a *new* silent gap that should have been caught earlier:

1. Add it as Gap N here with the same 4-section format.
2. If it is mechanically closeable, file the work to close it, then move it from Gap N → the promotion table once shipped.
3. If it is not mechanically closeable, leave it as Gap N. The point of this document is to avoid the v7.5-era pattern where unmeasured failure modes hid behind narrative discipline.

This document is updated when a Class B gap moves to Class A (delete the gap section, add a row to the promotion table) or when a new Class B gap is discovered (add a gap section). All changes are commit-tracked; the audit history lives in `git log -- docs/case-studies/meta-analysis/unclosable-gaps.md`.
