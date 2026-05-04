# PRD: Smart Reminders — Behavioral Learning

> **ID:** smart-reminders-behavioral-learning | **Status:** PR-1 SHIPPED 2026-05-04 / PR-2 PLAN LANDED / PR-3 BACKLOG
> **Priority:** P2 (locked at parent's brainstorm 2026-04-30)
> **Last Updated:** 2026-05-04
> **Parent:** [smart-reminders](smart-reminders.md) (parent feature shipped 2026-04-16)
> **Branch:** feature/smart-reminders-behavioral-learning (PR-1 merged); feature/smart-reminders-behavioral-learning-pr2 (planned)
> **Spec:** [`docs/superpowers/specs/2026-05-01-smart-reminders-behavioral-learning-design.md`](../../superpowers/specs/2026-05-01-smart-reminders-behavioral-learning-design.md)
> **Plan PR-1:** [`docs/superpowers/plans/2026-05-01-smart-reminders-behavioral-learning-pr1.md`](../../superpowers/plans/2026-05-01-smart-reminders-behavioral-learning-pr1.md)
> **Plan PR-2:** [`docs/superpowers/plans/2026-05-04-smart-reminders-behavioral-learning-pr2.md`](../../superpowers/plans/2026-05-04-smart-reminders-behavioral-learning-pr2.md)

This PRD is a thin wrapper over the existing design spec — the spec is the source of truth for product decisions. This file exists to satisfy the parent-child wiring rule: every shipped feature has a PRD whose frontmatter declares its parent, and every parent's PRD lists its children.

---

## Purpose

Adapt the parent `smart-reminders` system to fire each personalisable reminder at the per-user hour with the highest tap-through probability, using a Bayesian posterior weighted against a server-side cohort prior. Closes `SR-17` (behavioral data collection) + `SR-18` (smart timing optimization) from the parent's Phase-3 backlog.

## Scope

**Personalisable types (3 of 6):** `nutritionGap`, `trainingDay`, `restDay`. The other three (`healthKitConnect`, `accountRegistration`, `engagement`) cap too low or fire too sparsely to support per-user personalisation; they keep their static fire times.

**Three staged PRs:**
| PR | What | Status |
|---|---|---|
| PR 1 | Data layer + Settings toggle (defaults OFF) | ✅ Shipped 2026-05-04 via FT2 PR #190 (iOS) + #198 (backend) |
| PR 2 | `SmartTimingResolver` + A/B test instrumentation; toggle default flips ON | 📋 Plan landed 2026-05-04 via PR #199; execution gated on cohort data window opening (earliest 2026-05-09) |
| PR 3 | "Why this time?" per-type affordance | Backlog — starts after PR-2 merge gate fires |

## Success Metrics

Inherits from spec §"OQ-5 → Aggregate-primary + per-type kill (composite metric)":

- **Aggregate tap-through lift:** ≥ +5pp at p < 0.05 over 14 ± 4 day per-user readout window
- **No per-type regression:** treatment − control ≥ −3pp per personalised type (else per-type kill via server-issued `kill_flag`)
- **Disable rate:** flat or down (advisory; parent PRD already kills at +25 pp/month)

## Kill Criteria

- Aggregate tap-through lift < +0pp at end of readout window AND post-population aggregate also fails → revert toggle default to OFF
- Any single personalised type regresses ≥ −3pp vs static baseline → per-type rollback via `cohort_stats` `reminders.kill_flag` row
- Disable rate increases ≥ +3pp from baseline OR dismiss rate increases ≥ +5pp from baseline (advisory composite)

## Architecture

See spec §4 for the full diagram. Three-component on-device data layer (`BehavioralLearningStore`, `CohortPriorClient`, `CohortPriorCache`) feeds a `SmartTimingResolver` (PR 2) that combines the prior + posterior via Bayesian update. Server-side path uses the existing Supabase `cohort_stats` table + `increment_cohort_frequency` RPC (migrations 000001-000003 + 000009 retention extension). No new tables.

## Privacy posture

Cohort writes carry only `{type, hour, tapped}` — no userId, deviceId, locale, or timestamp ever leaves the device or persists to Supabase. Cohort reads are unauthenticated. Cells with `shows < 50` are suppressed (k-anonymity floor matching migration 000004). Posterior never leaves the device. GDPR Article 17 wipe path extended in PR-1 via `EncryptedDataStore.deletePersistedData()`.

## Cross-references

- Spec sections: §1 (Summary), §3 (Locked decisions OQ-1..OQ-5), §4 (Architecture), §5 (Components), §6 (Data flow + Privacy), §7 (Error handling + opt-out), §8 (Testing + A/B instrumentation)
- Predecessor: PR #158 (six lifecycle analytics events, merged 2026-04-30) — supplies the input signal
- Backend reuse: existing Supabase `cohort_stats` table + `increment_cohort_frequency` RPC; migration 000009 documents that 000004's retention is already segment-agnostic

---

**Operational note:** This PRD is intentionally thin. The spec at [`docs/superpowers/specs/2026-05-01-smart-reminders-behavioral-learning-design.md`](../../superpowers/specs/2026-05-01-smart-reminders-behavioral-learning-design.md) is the source of truth — locked decisions OQ-1 through OQ-5 from the 2026-04-30 brainstorm session, full architecture, data flows, error handling, and A/B test instrumentation all live there. This PRD wires the feature into `docs/product/prd/`'s parent-child index.
