# W40 System Reconcile — 2026-07-23

> **Status:** CURRENT · A full W40 pass (verify-first against repo truth) across
> **every layer**: all master + sub plans, the backlog, Linear, GitHub, the gate
> catalog, and the feature corpus. Canonical counts:
> [`../FRAMEWORK-FACTS.md`](../FRAMEWORK-FACTS.md). Live per-item status:
> [`../../.claude/shared/item-registry.json`](../../.claude/shared/item-registry.json).
>
> Companion to the [v8.x overlay](v8-x-overlay-2026-07-20.md), which stays the
> docket-level view. This file records **what was found and corrected**, so the
> next sweep can tell drift from work.

---

## 0. TL;DR

**The trackers were in good shape; the plan documents were not.**

- **Linear ↔ repo: 0 tracker lag.** All 66 features carrying a `linear_id` join
  cleanly to a Linear issue whose state matches `state.json`. The FIT-200
  crosswalk is doing its job.
- **`backlog.md`: accurate.** Every item spot-checked carried a dated
  reconciliation note and matched the code.
- **Plan docs: 12 stale-open claims** across 4 plans, the oldest ~7 weeks.
- **One finding is not documentation at all** — it is a live gap in the
  enforcement layer (§2).

---

## 1. The shape of the drift

Every stale claim found this sweep fell into one of three kinds. The third is
the expensive one.

| Kind | What it is | Cost to fix | Cost of leaving it |
|---|---|---|---|
| **Stale status** | Item shipped, doc still says open | Minutes | Someone re-does shipped work |
| **Stale *cause*** | Item genuinely open, but the doc names the wrong reason | Minutes | A full investigation cycle to disprove the wrong theory |
| **Unmet requirement** | Doc states a condition that was never met, and nothing enforced it | Real work | The condition silently stops being a condition |

The 2026-07-23 batch produced one of each: the ui-ux mirror (stale status), the
WelcomeView `NavigationStack` theory (stale cause — cost a full record cycle to
disprove), and the try-repo fixture gap (unmet requirement).

---

## 2. Headline finding — 5 write-time gates lack a try-repo fixture, 3 of them enforced

**This is the one item from this sweep that is not a doc fix.**

`.claude/shared/gate-catalog.json::summary.write_time_without_try_repo` —
machine-derived, not estimated:

| Gate | Enforced? | Test tier it actually has |
|---|---|---|
| `CSV_TAXONOMY_DRIFT` | **yes** — 2026-07-13 (B16) | unit / dispatch |
| `PLATFORMS_TESTED` | **yes** — 2026-06-21 (B15) | unit |
| `SCHEMA_DIFF` | **yes** — 2026-07-20 (B17) | has `test_try_repo_schema_diff.py`, but **no fixture dir**, so the catalog cannot derive try-repo tier |
| `GA4_MCP_DISCONNECTED` | no — advisory by design | unit |
| `PR_NUMBER_UNRESOLVED` | yes — pre-dates F16 | unit |

**Why it matters.** Try-repo is the only tier that runs the real
`.githooks/pre-commit` end-to-end in a throwaway git repo. F16 exists precisely
because that tier caught two architectural bugs (`GATE_COVERAGE_LEDGER` being a
module constant, `REPO_ROOT` being hardcoded) that the monkey-patched dispatch
tier is structurally incapable of seeing. Three gates that **block commits
today** rest on tiers that cannot see that class of bug.

**Why it went unnoticed.** The rule is stated plainly in CLAUDE.md (v7.9.1 F16)
and was additionally a **pre-merge** condition in
[analytics master plan §8.4](analytics-master-plan-2026-05-13.md). Nothing
enforced it — the meta-gate that would (**T1 `GATE_TEST_MISSING`**, FIT-149) is
itself the thing still unbuilt, date-gated to **2026-08-22**. A requirement with
no enforcement decays into a preference.

**Disposition.** Not fixed here (authoring 3–5 fixture pairs is its own task,
not a doc sweep). Filed in [`backlog.md`](../product/backlog.md) under *High
Priority (Architecture & Framework)*. Doing the backfill **before** 2026-08-22
means T1's calibration window starts from a clean baseline rather than 5
pre-existing violations — otherwise T1's first act is to fire on the framework
that built it.

---

## 3. Corrections applied, by source

### 3.1 `ui-ux-master-plan-2026-05-24.md` — §2.5 mirror **deleted**

§2.5 was a hand-copied mirror of the backlog's Medium / Low / DS-Residual lists,
taken 2026-05-24 and never re-synced. By this sweep it carried **9 rows the
backlog had already marked shipped**: chart goal target-lines, chart tap-tooltip,
trend alerts (HRV), exercise search/filter, training-program customization, the
notification-settings screen, CSV export, the AI feedback loop, and 3 of 4
DS-residual rows.

**The backlog was right the entire time.** Only the copy was wrong. So the
mirror is **deleted, not refreshed** — re-syncing restarts the same clock, and a
second copy of a list is a second thing that can go stale. This is W40
reproduced inside the documentation.

Also corrected in the same file: the **PERF / Lighthouse-CI row**, stale-open for
~7 weeks (shipped as FIT-193 — `lighthouse-ci.yml` + `.lighthouserc.cjs`, driven
by Vercel `deployment_status`), and the Figma-architecture row (part (C) is done;
(A)+(B) are constrained by the same Pro-plan limit that disabled Code Connect).

Open markers in that file: **27 → 2**.

### 3.2 `post-v7-9-candidate-plan-2026-05-20.md` — E-14 + E-15 struck

- **E-14 F-LAUNCHD-DRIFT-EXTENSION** — all three sub-fixes shipped 2026-06-04
  (#621 for (b)+(c), #623 for (a)). Both feature dirs `complete`; 30 tests.
- **E-15 F-CONTRACT-FIXTURE-SAMPLING** — shipped as
  `scripts/sample-contract-fixtures.py` + `make sample-contract-fixtures` +
  `--check`, with the consumer half as `contract-fixture-consumer-adoption`
  (`complete`). Its weekly drift cron is what raised #816.

### 3.3 `analytics-master-plan-2026-05-13.md` — §8.4 marked NOT MET

See §2. §15.1 (the Phase-1 PRD approval checklist) was deliberately **left
unchecked** — it is a one-time, point-in-time approval artifact, not tracked
work, and per the FRAMEWORK-FACTS convention dated plan docs keep the state of
their era.

### 3.4 `backlog.md` — Code Connect reclassified

`- [ ] Code Connect (Figma ↔ code mapping)` read as ordinary open work. It is
**blocked by plan tier**: disabled 2026-06-15 after an audit found it had failed
on every real run since 2026-05-10, because Code Connect needs an
Organization/Enterprise plan and this account is **Pro**. Reclassified to
blocked, pointing at the ⛔ banner in CLAUDE.md and honesty ledger FT2-FH-005.

### 3.5 `FRAMEWORK-FACTS.md` — count corrected

The `write_time_without_try_repo` line said **4** and omitted `SCHEMA_DIFF`
(added 07-09, enforced 07-20). Corrected to **5**. Feature counts refreshed to
**128 complete / 4 in-flight** after `t9-backend-chaos-tests` closed.

### 3.6 Linear — 3 issues closed as already-satisfied

| Issue | Why |
|---|---|
| **FIT-137** stale-branch cleanup | 0 `[gone]` branches in both repos; the 5 in fitme-story were pruned this session, each PR-verified MERGED first |
| **FIT-147** Phase 1.B.3 calibration monitoring | Superseded — each gate got its own calibration; `CSV_TAXONOMY_DRIFT` promoted under B16, `GA4_MCP_DISCONNECTED` is advisory-permanent by design |
| **FIT-148** Phase 1.B.4 promotion decision | The decision was made and executed; analytics Phase 1.B is complete. The operator half (**FIT-203**) stays open and gates **FIT-159** |

FIT-147 is notable: the v8.x overlay had **already** recommended closing it in
Linear, and that recommendation was never executed. A reconcile that only writes
docs does not reconcile anything.

### 3.7 GitHub

- **#833** closed — the `-24 distinct gates` regression was an artifact of the
  worktree telemetry loss fixed in #934; the index now reads 34 gates / 8,874
  rows.
- **#717** annotated, **left open** — 9 high → 8 high, root now clean, remainder
  entirely in `website` + `dashboard`, held because the resolving `astro` 6→7
  bumps are known-broken for those apps (W29) and iOS CI cannot catch it.
- **#816**, **#922** auto-closed by #953.

---

## 4. What is genuinely open (verified, not copied)

**Dev, no external dependency**
- Try-repo fixture backfill for 5 gates (§2) — do before 2026-08-22
- **T4/FIT-152** — Home + Welcome snapshot recipes DONE 2026-07-24 (PR #961):
  injectable `now` clock on `MainScreenView` + `WelcomeView(snapshotSettled:)`;
  baselines recorded/committed (13 total), T3 complete. Remaining: flip suite to
  `SNAPSHOT_MODE=verify` gating + a case study. See catalog **W46**
- **FIT-135** — 23 `slate-*` across 4 control-room files after the #270 slice
- Notification-store-consolidation; Dark-Mode e2e; Dynamic Type (`@ScaledMetric`
  appears in **0** files); Figma old-frame cleanup

**Operator-gated** — FIT-202 (Supabase RLS), FIT-203 (GA4 conversions → gates
FIT-159), FIT-204 (Search Console), FIT-17/18/134 (App Store), MCP connector
auth, DevSSD replacement, **`FITTRACKER2_DEPLOY_TOKEN` expiry 2026-07-25**

**Calendar-gated** — B19 (08-10), N6 audit + B4 (08-12/13), **T1
`GATE_TEST_MISSING` (08-22 — the last v8.0 gate)**, B20 (~10-11), W9 (event-gated)

**Blocked by plan/hardware** — Code Connect (Pro tier), Orchid v1.5, F21 Sentry
(launch-gated), Icebox V8-I1–I7 (no trigger fired)

---

## 5. Recommendation for the next sweep

Two of this sweep's findings were only visible because something *machine-derived*
disagreed with prose: the gate catalog's `write_time_without_try_repo` (5 vs the
doc's 4), and the `linear_id` crosswalk (which proved the trackers clean and let
the sweep skip them). Both are cheap to re-run.

The mirror in §3.1 had no such signal, which is why it rotted for 8 weeks.
**Prefer a pointer to a second source of truth over a copy of it** — and where a
copy is unavoidable, give it a derived freshness signal, per **W44**.

---

## 99. Provenance

Sweep run 2026-07-23 against `main` @ `211df9e8`, after PRs **#953** (advanceable
batch), **#954** (T4), and fitme-story **#270** (FIT-135) merged. New catalog
patterns from the same session: **W46** (a screen that renders is not yet
snapshotable) and **W47** (gate vs log-writer event vocabularies diverge).
Verification at ship: `make integrity-check` 0 findings + 0 advisory / 132
features; 771 framework tests.
