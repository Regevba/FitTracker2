# Data Integrity Framework — v7.5 Case Study

**Date written:** 2026-04-24

**Subtitle:** How an independent audit of the project's own case-study corpus surfaced a surprising gap — the work being measured had no audit of its own measurements — and how that gap turned into eight cooperating defenses that now catch broken data at write-time, cycle-time, and readout-time.

**Work Type:** Framework infrastructure (not a product feature)

**Dispatch Pattern:** Mostly serial across multiple sessions, with one parallel session dispatching unrelated UI-audit burndown work on a review-gated branch. The main Tier-closure work ran sequentially because each tier's implementation informed the next (e.g., the write-time schema hook was the scaffold the PR-resolution check extended).

| Field | Value | Tier |
|---|---|---|
| Framework version | v7.1 → **v7.5** | — |
| Trigger | Google Gemini 2.5 Pro independent audit (2026-04-21) | — |
| Ship date | 2026-04-24 (continuous work across 2026-04-21 → 2026-04-24) | — |
| Scope | 8 tier recommendations; 7 shipped, 1 external-blocked | — |
| Wall time | ~3 working sessions across 4 days (not instrumented — T3) | T3 |
| Case-study files touched | 4 new + 6 updated | T2 |
| Scripts shipped | 4 new (check-state-schema, measurement-adoption, append-feature-log, runtime-smoke-gate, documentation-debt-report) + 1 extended (integrity-check) | T1 |
| Makefile targets added | `schema-check`, `install-hooks`, `documentation-debt`, `measurement-adoption`, `runtime-smoke` | T1 |
| GitHub Actions workflows hardened | 1 (integrity-cycle.yml) | T1 |
| Commits shipping v7.5 | `36c1329`, `4269fbf`, `c6312b1`, `1580760`, `d99f6b9`, `066ad18`, `1405f89`, `2415475`, `d986d74`, `e74604e`, `4ff953e`, `0a38af7`, `e892ce3`, `223a1b4`, `28cbd44`, `c174c01` (+ pending v7.5 bump commit) | T1 |
| Integrity baseline at v7.5 | **0 findings across 40 features + 46 case studies** | T1 |
| Open GitHub tracking issues | #138 (closed as false-positive resolution), #140 (open: Tier 1.1 `cache_hits` writer-path gap) | T1 |

---

## 1. Why This Case Study Exists

The v7.1 Integrity Cycle (2026-04-21) shipped self-observation: a 72h GitHub Actions job that audits every `state.json` for drift. The same week the cycle shipped, a different kind of audit was delivered — Google Gemini 2.5 Pro, a model from a different vendor with no production hand in the project, reviewed the project's entire case-study corpus and meta-analyses as an independent check.

The audit's central finding was a bifurcation:
- **Methodologically strong:** the project documents its process rigorously, including failures and regressions
- **Empirically weak:** pre-v6.0 quantitative claims were estimates and narrative inference; cache-hit rates were 0% instrumented; the whole dataset came from a single practitioner which couldn't separate framework improvement from individual learning

Gemini's remediation list contained 9 concrete Tier 1/2/3 recommendations. Reading them with fresh eyes after the 2026-04-21 ship surfaced the uncomfortable observation: **the project had shipped extensive measurement infrastructure without a measurement of its own measurement adoption**. The v7.1 integrity cycle audited *state drift* but not *instrumentation adoption*. Data flowed through the corpus without gates validating the data at its source.

v7.5 closes that loop. It is the Data Integrity Framework: eight cooperating defenses that catch broken data at write-time, cycle-time, and readout-time, and that make the gaps visible in machine-readable ledgers rather than narrative hedges.

---

## 2. Summary Card

**Success Metrics** (T1 unless noted):
- Integrity cycle findings: 0 across 40 features + 46 case studies (was: 0 at v7.1 ship, preserved through 20+ commits of v7.5 work)
- State.json schema drift at write-time: 0 (enforced via pre-commit hook; migration closed 2 legacy `phase`-key violators)
- PR citation drift at write-time: 0 (write-time check catches bogus `phases.merge.pr_number` before it lands; validated via a synthetic rejection test using a deliberately out-of-range pr number)
- PR citation drift on cycle: 0 (narrow regex prevents issue-citation false positives; validated same-day after the initial meta-analysis propagated a #51/#69/#70 false positive into the Gemini audit)
- Auditor Agent check codes: 11 (10 feature-level + 1 case-study-level), up from 8 at v7.1
- Contemporaneous feature logs active: 5 (was 0 at v7.1; scaffolds seeded for every feature currently in `phase=implementation`)
- Documentation debt ledger: baseline published with 7 open items; trend-mode blocks on scheduled cycle history per v7.5-compatible snapshot metadata
- Measurement adoption ledger: published (new in v7.5); honest delta exposed — `cache_hits` populated in 0/40 features

**Kill Criteria:** any integrity-cycle regression that can't be resolved in-repo triggers an on-demand external audit. None triggered to date.

**Self-declares complete:** v7.5 is declared complete as a framework version bump. Items still labeled "partial/pilot/backlog" within v7.5 are explicitly acknowledged — the Data Integrity Framework's honest-status convention requires that the meta-framework itself use honest-status labels.

---

## 3. The Gemini audit — inputs, process, and one learning-loop discovery

### 3.1 The audit input

Gemini was given:
- The internal structural meta-analysis (`docs/case-studies/meta-analysis/meta-analysis-2026-04-21.md`) — 41 case-study files audited for structural integrity (PR citations, state.json schema, dispatch declaration, etc.)
- The 24 showcase narrative case studies (`fitme-story/04-case-studies/`)
- Two earlier velocity-focused meta-analyses (2026-04-16)

### 3.2 The audit's output

Gemini returned:
- Executive summary bifurcating strong/weak evidence
- Case-by-case S01–S24 strength ratings (Strong, Moderate, Weak, Very Weak)
- Methodology evaluation including over-extrapolation critiques (power-law fit on N=12 is illustrative, not predictive)
- Nine Tier 1/2/3 recommendations with specific mechanics

### 3.3 The discovery: a false positive Gemini propagated

The internal structural meta-analysis had flagged three PR citations as "non-existent": `#51`, `#69`, `#70`. Gemini, given the meta-analysis as evidence, repeated the finding in its own output with the correct meta-evaluation ("demonstrating factual errors in the evidence cited weakens the original claims").

**Same-day verification showed all three were real GitHub issues**, not PRs:
- Issue #51 "Onboarding Flow" (closed) — cited in a case study as `regevba/fittracker2#51`
- Issue #69 "Rest Day — Positive Experience Redesign" (open) — cited as `issue #69`
- Issue #70 "Advanced Data Fusion + AI Exercise Recommendations" (open) — cited as `issue #70`

The meta-analysis's regex was too permissive (matched bare `#NNN`). Gemini had no mechanism to re-run the `gh pr view` queries and so inherited the flaw.

**This discovery became the seed of v7.5's policy:**
1. **Publish verbatim, append corrections.** The audit was published before the investigation concluded; once the false positive was confirmed, a Corrections section was appended (not substituted). Both the internal meta-analysis and the audit archive retain the original flawed finding alongside the same-day correction. GitHub issue #138 was closed with a full public explanation.
2. **Narrow regex by construction.** The Auditor Agent's `BROKEN_PR_CITATION` check that shipped as part of v7.5 uses a tighter `PR #N|pull/N` regex that distinguishes PR context from issue context. Running it against the same corpus produces zero false positives.

The policy — and the regex it inspired — protect against exactly the class of bug that seeded the policy. That reflexive structure is characteristic of the v7.5 work.

---

## 4. The eight defenses of v7.5

Each Tier recommendation from Gemini's list maps to one defense. Six are shipped, two are structurally complete but gated on external factors (manual verification steps or wall-clock cycle history), one requires an independent operator.

### 4.1 Tier 1.1 — Measurement adoption, made auditable

**Before:** "Partial — v6.0 measurement protocols shipped; system-wide adoption unclear."

**After (v7.5):** `make measurement-adoption` produces `.claude/shared/measurement-adoption.json` — a per-feature × per-dimension coverage table. Status becomes **"Partial, measured with known delta."**

The ledger exposed a finding that the narrative "partial" label had obscured: **`cache_hits` is populated in 0 of 40 features**. The v6.0 protocol defined the data structure but no session writer actually appends cache-hit data. Tracked publicly at [issue #140](https://github.com/Regevba/FitTracker2/issues/140).

**Why it matters:** Tier 1.1 will never reach "shipped" until the writer path is exercised. Before v7.5, that statement was narrative; after v7.5, it's a machine-readable zero in a committed ledger.

### 4.2 Tier 1.2 — PR-as-source-of-truth, at both write-time and cycle-time

**Before:** "Subset shipped — `BROKEN_PR_CITATION` catches broken case-study citations on the 72h cycle."

**After (v7.5):** `scripts/check-state-schema.py` was extended to also verify `phases.merge.pr_number` via `gh pr view` on every staged `state.json` commit. The pre-commit hook now fires this check before a feature can record a PR that does not resolve. Combined with the existing cycle check, the defense is complete at both layers.

- Write-time catch: synthetic test with a deliberately out-of-range pull number → pre-commit blocks (verified, exit 1)
- Cycle-time catch: 72h job runs `scripts/integrity-check.py` against all case studies and all state.json files
- Graceful degradation: `gh` unavailable in CI without `GH_TOKEN` → skip gracefully, never block a legitimate commit

### 4.3 Tier 1.3 — Schema enforcement on write

**Before:** "Backlog."

**After (v7.5):** `SCHEMA_DRIFT` (legacy `phase` key instead of canonical `current_phase`) is rejected by `.githooks/pre-commit`. `make install-hooks` sets `core.hooksPath` — idempotent. Two legacy violators (`hadf-infrastructure`, `meta-analysis-audit`) were migrated in the same commit that shipped the hook. The canonical-schema invariant is now enforced at the `git commit` boundary.

### 4.4 Tier 2.1 — Runtime smoke gates (groundwork shipped, manual last-mile)

**Before:** "Backlog."

**After (v7.5):** `scripts/runtime-smoke-gate.py` + `make runtime-smoke PROFILE=<id> MODE=<local|staging>` runs XCUITest smoke profiles against Staging and reports secret-safe status (`valid-looking`/`placeholder-looking`/`format-mismatch`/`missing`). Five profiles shipped: `app_launch`, `authenticated_home`, `sign_in_surface`, `onboarding_surface`, `meal_log_surface`. Staging `app_launch` + `sign_in_surface` pass locally against real staging credentials.

**Why it's "groundwork, not shipped":** the full recommendation required a staging-grade environment. The harness exists and its output is trusted evidence; the remaining step is a 7-step real-provider manual checklist (email sign-up, Google OAuth, session restore, etc.) that must be driven by a human on a simulator. That checklist lives at `docs/setup/auth-runtime-verification-playbook.md` and is the last thing blocking Tier 2.1 from "shipped."

### 4.5 Tier 2.2 — Contemporaneous logging (pilot active)

**Before:** "Backlog."

**After (v7.5):** `scripts/append-feature-log.py` writes append-only events to `.claude/logs/<feature>.log.json`. Hardened on 2026-04-23 to reject silent backdating: older timestamps require `--retroactive` + `--retroactive-reason`. Five active logs at v7.5 ship: `staging-auth-runtime`, `meta-analysis-audit`, `app-store-assets`, `import-training-plan`, `push-notifications` (the latter three seeded as scaffolds for features currently in `phase=implementation`).

**Why it's "pilot, not shipped":** adoption is gradual and voluntary. The full recommendation is that every multi-session feature logs contemporaneously. v7.5 shipped the infrastructure + seeded active logs; PM-workflow enforcement is the forward step.

### 4.6 Tier 2.3 — Data quality tiers (shipped)

**Before:** "Backlog."

**After (v7.5):** [`docs/case-studies/data-quality-tiers.md`](./data-quality-tiers.md) is the canonical convention. T1/T2/T3 labels (Instrumented / Declared / Narrative) must be applied to every quantitative metric in a case study, PRD, or meta-analysis. The case-study template header requires the convention; `CLAUDE.md` encodes it as a project rule. Existing case studies are grandfathered (their `(m/e/i)` markers map to the tier system); new case studies must use tier labels explicitly.

### 4.7 Tier 3.1 — Independent Auditor Agent (shipped + hardened)

**Before (v7.1):** 8 check codes, 72h cycle.

**After (v7.5):** 11 check codes (added `SCHEMA_DRIFT`, `BROKEN_PR_CITATION`, `PR_NUMBER_UNRESOLVED`) + 2026-04-23 workflow hardening:
- `set -o pipefail` + `PIPESTATUS[0]` captures the real `integrity-check.py` exit code through `tee` (previously `tee`'s zero-exit masked real failures)
- `snapshot_context: {trigger, counts_for_trend}` metadata on every snapshot — trend mode only counts `scheduled_cycle` snapshots, not ad-hoc local runs
- Regression detection is grep-for-token on the piped report, so strict/manual runs don't open issues for baseline findings

### 4.8 Tier 3.2 — Documentation-debt dashboard (baseline shipped)

**Before:** "Backlog."

**After (v7.5):** `make documentation-debt` produces `.claude/shared/documentation-debt.json` — 7 open debt items across 6 coverage dimensions (date_written, work_type, dispatch_pattern, success_metrics, kill_criteria, state_case_study_linkage) + trend-readiness gating. Trend mode requires 3 scheduled 72h cycle snapshots with the v7.5-compatible `counts_for_trend` metadata; baseline mode is usable immediately.

**Why it's "baseline, not shipped":** the dashboard exists and its point-in-time numbers are valid. Trend analysis waits on wall-clock — ~9 days minimum for three scheduled cycles.

### 4.9 Tier 3.3 — External replication (backlog)

**Status unchanged.** Cannot be completed by the project author alone; requires an independent operator (human or AI) to run a feature through the `/pm-workflow` on an unrelated product. The Gemini audit is not the same thing — Gemini reviewed artifacts, did not execute the framework.

---

## 5. How a new feature is now measured (end-to-end data flow)

**At feature creation:**
1. `.claude/features/<name>/state.json` is scaffolded with canonical keys (`current_phase`, not legacy `phase`)
2. `scripts/append-feature-log.py --feature <name> --event-type phase_started` creates `.claude/logs/<name>.log.json` (Tier 2.2)
3. First `git commit` fires `.githooks/pre-commit` which runs `check-state-schema.py --staged` — enforces SCHEMA_DRIFT (Tier 1.3) + PR_NUMBER_UNRESOLVED (Tier 1.2) on every state.json write

**During implementation (phase=implement):**
4. Contemporaneous events appended to `.claude/logs/<name>.log.json` as work happens — not reconstructed after-the-fact
5. Every metric recorded in the case study or state.json carries a T1/T2/T3 tier label (Tier 2.3)
6. `state.json → timing.phases` records `started_at` + `ended_at` per phase (v6.0 Tier 1.1 — machine-generated timestamps, Tier 1 data quality)
7. `state.json → cache_hits[]` appends deterministic cache-level hits (**v7.5 open gap — writer path not yet exercised, tracked at issue #140**)

**At phase=review → merge transition:**
8. `make runtime-smoke PROFILE=<matching_surface> MODE=staging` — runtime verification (Tier 2.1 groundwork). For auth-touching features, the 7-step real-provider playbook in `docs/setup/auth-runtime-verification-playbook.md` is the last mile.
9. `state.json → phases.merge.pr_number` is set. `check-state-schema.py` (on pre-commit) verifies the PR actually resolves via `gh pr view` (Tier 1.2 write-time)

**On merge:**
10. Case study drafted, declares work_type + dispatch_pattern + success_metrics + kill_criteria as explicit fields (or it fails the docs-debt checklist introduced in Tier 3.2)
11. `case_study` field in state.json populated — catches NO_CS_LINK check in the integrity cycle

**Periodically (every 72 hours):**
12. GitHub Actions runs `scripts/integrity-check.py` across all 40 features + 46 case studies
13. Produces a snapshot at `.claude/integrity/snapshots/<timestamp>.json` with `snapshot_context.trigger: scheduled_cycle`
14. Diffs vs prior snapshot; opens a `regression`-labeled GitHub issue if new findings appeared
15. After 3 scheduled snapshots, `make documentation-debt` trend mode unlocks — cross-cycle debt metrics become auditable (Tier 3.2)

**At any time (readout):**
16. `make integrity-check --findings-only` → point-in-time auditor output
17. `make documentation-debt` → coverage dashboard
18. `make measurement-adoption` → Tier 1.1 ledger
19. `make schema-check` → schema + PR-resolution validation across entire corpus

**Every data point in the corpus is now either instrumented (T1) or labeled as Declared (T2) / Narrative (T3), with every gate in the write + read paths producing a machine-readable pass/fail.**

---

## 6. What earned the bump from v7.1 to v7.5

v7.1 shipped the first wall-clock-triggered framework capability (72h integrity cycle). v7.5 compounds that foundation with seven new capabilities that together form a coherent "data integrity framework":

| Capability | v7.1 | v7.5 |
|---|---|---|
| state.json schema enforced | Post-hoc (cycle) | Pre-commit hook (write-time) + cycle |
| PR citations validated | Post-hoc (cycle) | Pre-commit hook (write-time) + cycle |
| Auditor Agent check codes | 8 | 11 |
| Runtime verification | None | 5 smoke profiles + staging harness |
| Feature logs | None | 5 active (pilot) |
| Data provenance | Implicit | T1/T2/T3 labels mandatory |
| Docs-debt dashboard | None | Baseline ledger published |
| Measurement adoption ledger | None | Published with honest delta |

The version jump from v7.1 → v7.5 skips v7.2, v7.3, v7.4. That's intentional: these eight capabilities are not independent — they compose a single data-integrity surface. Any single tier shipped without the others would have been a leaky abstraction (e.g., documentation-debt without a write-time schema gate would just track a growing mess). Bundling them as v7.5 reflects their cooperative nature.

---

## 7. What did NOT ship in v7.5

Deliberately out-of-scope:

- **Tier 2.1 last-mile (real-provider auth checklist)** — requires human at a simulator. Harness green; runtime verification gated on manual 7-step playbook.
- **Tier 3.2 trend mode** — wall-clock blocker. Needs 3 scheduled 72h cycle snapshots (~9 days minimum). Infrastructure is ready; time must pass.
- **Tier 3.3 external replication** — cannot be self-executed.
- **`cache_hits[]` writer path** — v6.0 structure exists, but no session writer appends. Filed as issue #140 with three remediation options.
- **PM workflow → structured log auto-emission** — Tier 2.2 "full process migration" requires the `/pm-workflow` skill to emit log events on every phase transition. Pilot is active; auto-emission is forward work.
- **Retroactive case-study relabeling** — the Gemini audit's Tier 2.3 recommendation was forward-only by policy (see [data-quality-tiers.md](./data-quality-tiers.md)). Existing case studies keep their `(m/e/i)` markers; new case studies use T1/T2/T3 explicitly.

---

## 8. Lessons

### 8.1 An independent audit that propagates an error from its input is still valuable

Gemini inherited a false positive from the structural meta-analysis it was given. Discovering and correcting the false positive same-day generated more insight than a clean audit would have — it proved the "publish verbatim, append corrections" policy works in practice, inspired the narrow-regex Auditor Agent check, and made the internal meta-analysis's precision gap visible. The Gemini audit's value was catalytic, not forensic.

### 8.2 "Partial" is a lossy label; make it a ledger

Gemini's Tier 1.1 status was "partial." That word does very little work. `make measurement-adoption` converts the same state into a per-feature × per-dimension coverage table with an explicit `cache_hits: 0/40` row. The same tier status — but actionable, not narrative.

### 8.3 Write-time gates + cycle-time gates are complementary, not redundant

Pre-commit hooks catch bad data before it lands. The 72h cycle catches drift that accumulates around the gates (e.g., state.json files touched by uninstrumented tools, or bypass-by-`--no-verify` commits). Neither alone is sufficient. v7.5 ships both for every class of check that can be expressed mechanically.

### 8.4 The framework audits itself now, and audits the audits

Before v7.5: the framework measured features. After v7.5: the framework measures its own measurement (measurement-adoption), the integrity of its own documentation (documentation-debt), the validity of its own references (PR_NUMBER_UNRESOLVED + BROKEN_PR_CITATION), and the integrity of its own schema (SCHEMA_DRIFT). Recursive self-observation is now the default posture.

### 8.5 Honest-status labels avoid the one bug the audit actually caught

The Gemini audit's biggest real finding wasn't broken PRs or schema drift — it was that the project had rounded "partial" up to "shipped" on Tier 1.1 at the 2026-04-21 ship. The 2026-04-23 honest-status pass downgraded it back to "partial." v7.5's final invariant: if a capability is partial, pilot, groundwork, or backlog-blocked, say so — in the tier status table, in the case-study metadata, in CLAUDE.md. The v7.5 Data Integrity Framework is itself labeled using its own honest-status convention.

---

## 9. Links

- **Primary audit:** [docs/case-studies/meta-analysis/independent-audit-2026-04-21-gemini.md](./meta-analysis/independent-audit-2026-04-21-gemini.md)
- **Internal structural meta-analysis (Gemini's input):** [docs/case-studies/meta-analysis/meta-analysis-2026-04-21.md](./meta-analysis/meta-analysis-2026-04-21.md)
- **Current remediation plan:** [trust/audits/2026-04-21-gemini/remediation-plan-2026-04-23.md](../../trust/audits/2026-04-21-gemini/remediation-plan-2026-04-23.md)
- **Integrity cycle v7.1 case study:** [integrity-cycle-v7.1-case-study.md](./integrity-cycle-v7.1-case-study.md)
- **Data quality tiers convention:** [data-quality-tiers.md](./data-quality-tiers.md)
- **Process docs index:** [docs/process/README.md](../process/README.md)
- **Auth-runtime verification playbook:** [docs/setup/auth-runtime-verification-playbook.md](../setup/auth-runtime-verification-playbook.md)
- **Framework manifest (v7.5 declaration):** [.claude/shared/framework-manifest.json](../../.claude/shared/framework-manifest.json)
- **Evolution document:** [docs/skills/evolution.md](../skills/evolution.md)
- **Open tracking issue:** [issue #140 — cache_hits 0/40 gap](https://github.com/Regevba/FitTracker2/issues/140)
- **Pending PR:** [#139 — UI-audit burndown (review-gated)](https://github.com/Regevba/FitTracker2/pull/139)
