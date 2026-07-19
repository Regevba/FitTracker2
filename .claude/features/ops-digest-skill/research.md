# Research — ops-digest-skill (F23 / FIT-205)

> **Lifecycle note:** this feature shipped its implementation first (PR #916) as a
> framework chore, then the operator asked to run the full PM cycle. This research
> doc is a faithful backfill of the discovery that motivated the build — the
> alternatives were genuinely weighed during implementation, not invented after.

## 1. What is this solution?

A `/ops digest` sub-command (+ `scripts/ops-digest.py` + `make ops-digest`) that
produces a **post-deploy operator digest**: one command that answers *"is
everything OK after that ship?"* by composing the framework's existing
authoritative health/telemetry producers into a single verdict.

## 2. Why this approach?

**Problem.** After a merge-to-main triggers a Vercel deploy, an operator today has
to run **four separate commands** to know if the ship was clean:
`make integrity-sweep`, `make bot-pr-health`, `make measurement-adoption`, and a
manual scan of `must-have-cadence-followups.md`. Each has its own output shape and
exit convention. There is no single "post-deploy all-clear" readout, so the check
is either skipped or done inconsistently — the exact conditions under which the
2026-04-20 "shipped but unreconciled" limbo (the origin of the whole integrity
framework) recurs.

**Pain points addressed:**
- No single-command post-deploy health answer → checks get skipped.
- Four producers with four output formats → cognitive load, easy to miss a FAIL.
- No machine-readable post-deploy artifact a GH Action could gate on.

## 3. Why this over alternatives?

| Approach | Pros | Cons | Effort | Chosen? |
|---|---|---|---|---|
| **A. Compose existing producers into one digest** | Zero new computation; single source of truth stays each producer; fail-soft; testable | Digest is only as fresh as its producers | ~0.7d | ✅ **Yes** |
| B. New monolithic health script re-implementing each check | One file | Duplicates + drifts from the authoritative producers (classic field-rename silent-pass risk); violates DRY | ~2d | No |
| C. Extend `integrity-sweep` with a "post-deploy" mode | Reuses the sweep | Overloads a layer-integrity tool with CI/PR/cadence concerns; wrong home | ~1d | No |
| D. Do nothing (keep 4 manual commands) | No work | The skip-prone status quo the integrity framework exists to prevent | 0 | No |

**Decision: Approach A.** A composer that *aggregates* the authoritative producers
(never re-computes) keeps each check's single source of truth intact and makes the
digest a thin, fail-soft, testable layer. This mirrors the framework's own
`integrity-data-lake` philosophy (layer telemetry, don't duplicate it).

## 4. External sources / prior art (in-repo)

- `scripts/integrity-telemetry-sweep.py` — the 10-layer integrity verdict (composed).
- `scripts/check-bot-pr-health.py` — bot-PR deadlock detector (composed).
- `scripts/membrane-status.py` — the v7.8 Mechanism F "single readout" precedent.
- `weekly-digest-silent-gate-enrichment` (FIT-185) — the *weekly cron* digest;
  F23 is its **on-demand, post-deploy** sibling (explicitly distinct per the FIT-205
  ticket).
- Pattern **#24** (field-rename silent-pass) — informed the dual-read of
  `measurement-adoption.json::summary.*`.

## 5. Market examples

Post-deploy "smoke digest" is a standard SRE pattern — e.g. a deploy pipeline's
post-step that rolls health checks + error-rate + recent-change list into one
Slack message (Datadog/PagerDuty deploy events, GitHub deployment status
summaries). F23 is the local, framework-native equivalent.

## 6. UI

None — CLI + JSON artifact only. `has_ui = false`.

## 7. Data & demand signals

- The integrity framework exists *because* "shipped but unverified" happened 7+
  times before 2026-04-20. A one-command post-deploy readout directly lowers the
  cost of the verification step, which raises the odds it actually happens.
- FIT-205 is an operator-requested docket item (v8.x build docket §0.C / FIT-74).

## 8. Technical feasibility

Trivial — stdlib-only Python composing subprocess calls to existing scripts +
reading two shared ledgers. Main risk is a producer changing its output shape;
mitigated by fail-soft per-section degradation + a text-contract parse (verdict
regex) rather than brittle full-output coupling.

**Known scope boundary (documented gate):** the FIT-205 ticket notes F23 is
*"gated on Sentry MCP resume — the digest is meant to fold in Sentry error
trends."* Sentry MCP is currently unauthenticated. The fail-soft, per-section
design means a **Sentry error-trend section is an additive follow-up** (another
best-effort producer) with zero rework — it is explicitly out of scope for this
cycle and tracked as a follow-up.

## 9. Proposed success metrics

- **Primary:** post-deploy digest adoption — # of deploy-days where `ops-digest.json`
  was regenerated ÷ deploy-days (proxy: snapshot mtime freshness).
- **Secondary:** false-alarm rate (digest FAIL that wasn't a real issue) = 0;
  digest wall-time < 3s typical.
- **Guardrail:** never aborts / never blocks a legitimate post-deploy flow
  (fail-soft invariant).

## 10. Decision

**Build Approach A** — a fail-soft composer. Ship the deploy/CI + integrity +
telemetry + cadence sections now; defer the Sentry error-trend section to a
follow-up gated on Sentry MCP auth. Recommended and implemented (PR #916).
