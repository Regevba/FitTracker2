# PRD — ops-digest-skill (F23 / FIT-205)

- **Owner:** operator (Regev) · **Skill:** `/ops`
- **Work type:** feature (run through full lifecycle) · **work_subtype:** framework_feature
- **framework_version:** v7.10 · **Linear:** FIT-205 (parent FIT-74)
- **has_ui:** false · **requires_analytics:** false

## 1. Problem

After a merge-to-main → Vercel deploy, there is no single command that tells an
operator "the ship was clean." The four relevant producers
(`integrity-sweep`, `bot-pr-health`, `measurement-adoption`, cadence-followups)
must be run and read separately, so the post-deploy verification is skipped or
done inconsistently — reintroducing the "shipped but unverified" risk the
integrity framework exists to prevent.

## 2. Goal / non-goals

**Goal:** one fail-soft command (`make ops-digest` / `/ops digest`) that composes
the existing producers into a single PASS/WARN/FAIL post-deploy readout + a
machine-readable snapshot a hook can gate on.

**Non-goals (this cycle):**
- Sentry error-trend fold-in (gated on Sentry MCP auth — tracked as a follow-up).
- Re-implementing any producer's logic (compose only, never recompute).
- A UI surface (CLI + JSON only).
- Real-time streaming (snapshot-at-invocation, like the rest of `/ops`).

## 3. Solution

`scripts/ops-digest.py` composes four **fail-soft** sections — Deploy/CI,
Integrity, Telemetry, Cadence — into an overall verdict = worst section
(`ok < unknown < warn < fail`). Exit 1 only on a hard integrity `fail`. Writes
`.claude/shared/ops-digest.json`. Surfaced via `make ops-digest` and the
`/ops digest` sub-command.

## 4. Success metrics (NON-NEGOTIABLE)

### Primary
| | |
|---|---|
| **Metric** | Post-deploy digest coverage — deploy-days with a fresh `ops-digest.json` ÷ deploy-days |
| **Baseline** | 0% (feature did not exist) — **T1 (Instrumented)** via snapshot mtime |
| **Target** | ≥ 70% of deploy-days within 30 days of any post-deploy hook wiring |
| **Instrumentation** | `ops-digest.json.generated_at` freshness vs merge-commit dates |

### Secondary
- **False-alarm rate** = 0 (a digest `fail` always maps to a real integrity FAIL). **T2 (Declared)** at ship; **T1** once a hook runs it in CI.
- **Wall-time** < 3s typical (composes cached producers). **T1** — measurable via `time make ops-digest`.
- **Section-degradation correctness** — a down producer degrades exactly ONE section to `unknown`, never aborts. **T1** (unit-tested).

### Guardrail (must not degrade)
- Fail-soft invariant: the digest **never aborts** and **never blocks** a legitimate post-deploy flow. Non-zero exit ONLY on a hard integrity `fail`.
- No new computation: every number traces to an existing producer/ledger (no drift-prone re-derivation).

### Leading indicator (≤1 week)
- `make ops-digest` runs green locally + in a smoke CI step; 10/10 unit tests pass.

### Lagging indicator (30/60/90d)
- Post-deploy digest becomes the habitual "all-clear" check; adoption ≥70% deploy-days once wired into a post-deploy hook.

### Review cadence
- +7d (2026-07-26): confirm CI smoke + adoption of `make ops-digest` in the post-merge habit.
- +30d (2026-08-18): evaluate primary metric + the Sentry-section follow-up decision.

## 5. Kill criteria

Kill / roll back the digest if ANY holds at the +30d review:
1. **False alarms > 0** — a digest `fail` fired that did not map to a real integrity FAIL (erodes trust in the readout → worse than no digest).
2. **Fail-soft violated** — the digest ever aborted or blocked a post-deploy flow due to a down producer (guardrail breach).
3. **Drift** — any section reports a value that contradicts its authoritative producer (the recompute-vs-compose invariant broke).

**kill_criteria_resolution:** none fired as of ship (2026-07-19). Unit tests pin
the fail-soft + dual-read invariants; live run matched every producer. Re-evaluated
at the +30d review.

## 6. Test & eval requirements

Non-AI feature → eval gate auto-passes. Test coverage: 10 unit tests
(`scripts/tests/test_ops_digest.py`) covering verdict-severity ordering, cadence
window incl. struck-through/past rows, ISO-date parse, telemetry dual-read (both
top-level and `summary.*` schemas — pattern #24), text rendering (ok + fail), and
fail-soft assembly when every producer errors.

## 7. Rollout / reversibility

Additive, low-risk: a new script + make target + skill sub-command. Reversible by
reverting PR #916 (no product surface, no schema/gate changes). No calibration
window needed (not an enforcement gate).

## 8. Alternatives considered

See `research.md` §3 — Approach A (compose) chosen over B (monolith re-impl),
C (overload integrity-sweep), D (do nothing).
