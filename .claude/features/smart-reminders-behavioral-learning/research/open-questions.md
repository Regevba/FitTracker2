# Smart Reminders — Behavioral Learning Layer (research / open questions)

> **Status:** Research phase started 2026-04-29. No design decisions locked.
> Brainstorming with user required before PRD.

## Context

The parent feature `smart-reminders` (shipped 2026-04-16, PR #98) ships six reminder types with hardcoded frequency caps, fixed quiet hours (22:00–07:00), and a fixed minimum interval (4h). The case study explicitly defers a behavioral-learning sub-feature: *"Future sub-task: behavioral learning layer"*. PR #158 (currently in flight) adds the six lifecycle events that are the input signal this feature would consume.

This file captures the scope decisions that must be made before a PRD can be written. Each section is an open question — no decisions are pre-baked here.

## OQ-1 — What does "behavioral learning" actually adapt?

Three candidates, ordered by ambition:

1. **Per-user quiet hours.** Today the window is 22:00–07:00 for everyone. A user who logs meals at 23:30 every night is treated as if they're asleep. The feature could shift the window per-user based on observed app-open / log-event distribution.
2. **Per-type frequency caps.** Today the per-type daily cap is 1 across all types. A user who taps every nutrition reminder but never taps engagement reminders would benefit from more nutrition pings and fewer (or zero) engagement pings.
3. **Per-type send time.** Today nutrition gap fires at 4 PM and training reminder at 10 AM. A user whose lunch tap-through rate is 80% at 12:30 and 5% at 14:00 would benefit from a per-user send time, not a global one.

Lock at least one. Ambition can stack but each adds verification difficulty.

## OQ-2 — What's the minimum signal volume before adapting?

The per-type tap-through events from PR #158 land in GA4. The behavioral layer needs a copy on-device (no network round-trip per send decision). Question: how many shown/tapped/dismissed events per type before we trust the per-user signal?

- Industry baseline: most adaptive notification systems wait for 7–14 days of observations before personalizing.
- FitMe-specific: nutrition gap fires at most 5/week per the cap, so 14 days = at most 10 observations. That's very thin.
- Decision: stick with the population default until the per-user posterior has N observations? Or weight a Bayesian update that always has the population as the prior?

Lock the threshold (or the model), and lock how it's stored (UserDefaults? On-device CoreData? Encrypted blob?).

## OQ-3 — Is this on-device, server-side, or hybrid?

Three architectural shapes:

1. **Pure on-device.** Everything runs in `ReminderTriggers.swift` extensions; observations stay on the device. No network. Privacy-clean. Slower learning (single user signal).
2. **Server-side cohort intelligence.** Aggregate observations across users via `AIOrchestrator` cohort intelligence. Per-user pulls a "people like you tap nutrition gap at 12:00" suggestion. Faster learning. Requires backend work + privacy review.
3. **Hybrid.** Population prior comes from server, posterior updates happen on-device. Best of both. More complex.

Lock the shape before any code lands.

## OQ-4 — What's the disable / opt-out path?

Today the user can disable a reminder type entirely from Settings (writes to `NotificationPreferencesStore`). The behavioral layer adds a new dimension: the timing / frequency. Should the user see "Smart timing on/off" in Settings? Or is it always-on with the population default + per-user adjustment, no UI surface?

Lock UI footprint (if any) before design.

## OQ-5 — How do we measure success?

The parent feature's PRD primary metric is `tap-through ≥ 25% across all types`. The behavioral layer's hypothesis is *adaptive timing lifts the rate further*. Success means an A/B test where:

- Control group keeps the static timing.
- Treatment group gets adaptive timing.
- After 30 days, treatment's tap-through rate is X% higher than control's at p < 0.05.

Lock the X (5%? 10%? 20%?) and the kill criterion (e.g. *treatment tap-through is statistically lower or equal at 30 days* → kill).

## OQ-6 — What's the dependency on PR #158?

PR #158 adds the six lifecycle events. The behavioral layer needs:

- `reminder_shown` per type (denominator)
- `reminder_tapped` per type (numerator → tap-through rate)
- `reminder_dismissed` per type (signal of annoyance)
- Optional: `reminder_suppressed` reasons (signal that the user "would have wanted" but the cap/quiet-hour blocked)

These have to land first. Mark this feature as blocked-on-PR-#158 in state.json.

## Research deliverables (to produce after brainstorming)

1. **PRD** at `docs/product/prd/smart-reminders-behavioral-learning.md` with the OQ-1..5 decisions locked.
2. **Tasks list** at `.claude/features/smart-reminders-behavioral-learning/tasks.md`.
3. **UX spec** if OQ-4 lands a Settings surface.
4. **Success metrics** populated in `state.json` per the v7.7 forward-only doc-debt rule.
5. **Kill criteria** populated in `state.json`.
6. **Dispatch pattern** chosen (likely `serial` for a single-author sub-feature).

Until these are filled in, the feature stays in `current_phase: research`.

## Recommended next step

Bring OQ-1 through OQ-5 to the user via brainstorming (`/superpowers:brainstorming` or equivalent) and lock decisions before any code lands.

---

## Decisions locked 2026-04-30 (brainstorm session — paused mid-flow)

> Session paused after OQ-5 lock; sequencing approach (A/B/C), design sections, spec doc, and writing-plans
> all still pending. Resume by re-loading the brainstorming skill and picking up at "Approach A / B / C".

### OQ-1 → β (SR-17 + SR-18)

V1 scope: data-collection layer (SR-17, already in parent PRD P2) **plus** timing-automation layer
(SR-18, also in parent PRD P2). Matches parent PRD's Phase 3 rollout sequence: ship data collection,
then automation. Picked over α (SR-17 alone) and γ (SR-17 + non-PRD automation) because β ships visible
behaviour change and can be A/B-measured immediately, while α requires a follow-up release for the
visible win.

**Constraint surfaced during brainstorm:** Of the six ReminderTypes, only **three are realistic
personalisation targets**:

| Type | Lifetime cap | Verdict |
|---|---|---|
| HealthKit Connect | 3 lifetime | ❌ never enough data |
| Account Registration | 3 lifetime | ❌ never enough data |
| Engagement | 3 per lapse, sparse | ❌ bursty + thin |
| **Nutrition Gap** | 5/week | ✅ ~20+ obs in 30 days |
| **Training Day** | 1/day | ✅ ~12 obs in 30 days |
| **Rest Day** | 1/day | ✅ ~10 obs in 30 days |

The other three keep their static defaults. SR-18 in v1 = adaptive timing for {Nutrition Gap,
Training Day, Rest Day} only.

### OQ-2 → (b) Bayesian update with static-default prior

Always personalise; no count-threshold cliff. The per-user posterior is weighted by observation count
vs the population prior. The "prior" is the existing static fire time per type (4 PM nutrition,
10 AM training, etc.) — already in code, no bootstrap needed. Below ~5 observations, posterior is
indistinguishable from the static default; behaviour drifts smoothly toward personal as observations
accumulate. Picked over (a) hard count threshold (cliff effect) and (c) time + count hybrid (defeats
the purpose for users with fast data accumulation).

### OQ-3 → (3) Hybrid (cohort prior server-side + posterior on-device) + backend implementation task

Server-side prior comes from existing Supabase `cohort_stats` table + `increment_cohort_frequency` RPC
(migrations 000001-000003), which AI engine already writes to via service-key. On-device posterior
update lives in a new Swift store (likely `BehavioralLearningStore` next to `ReminderScheduler`).
**No new Supabase table needed** — the existing schema (`segment` / `field_name` / `field_value` /
`frequency`) is generic enough to fit the new reminder cohort signal. Backend scope:

- Reuse existing `cohort_stats` table with new segment values like `reminders.tap_through.<type>`,
  field_name = hour-of-day bucket (00–23).
- Add a **read RPC** (read path doesn't exist today; existing infrastructure is write-only on the
  client side via service-key).
- Add an **AI-engine writer hook** so each `reminder_shown` / `reminder_tapped` event also emits an
  anonymised cohort write (via the existing `increment_cohort_frequency` path).
- Extend the existing pg_cron retention job (migration 000004) to cover the new segment values.

Picked over (1) pure on-device (slower learning, no cross-user signal benefit) and (2) pure server-side
(violates parent PRD's existing GDPR commitment "all trigger evaluation and scheduling is fully
local"). Hybrid splits the responsibilities cleanly: prior is shared, posterior + decision-making
stays local.

### OQ-4 → (d) Global toggle + per-type "Why?" affordance

In Settings → Notifications, one global "Smart timing" toggle alongside the existing per-type
enable/disable toggles. **On by default.** Off = revert to static fire times for all three
personalisable types. **Plus** a per-type "Why this time?" affordance (per-type row shows the
current send time; tap opens an `AIIntelligenceSheet`-style explanation panel: "Currently sending
around 17:30. Shifted from 16:00 because you tap more often after 17:00."). Reuses the existing
AI-Coaching `AIIntelligenceSheet` pattern. Picked over (a) no UI (fails GDPR Article 22 on automated
decision-making), (b) no transparency (toggle without explanation), and (c) per-type toggles
(over-promises since 3 of 6 types don't personalise).

### OQ-5 → (c) Aggregate-primary + per-type kill, with flexible readout window

| Metric | Target | Kill threshold |
|---|---|---|
| Aggregate tap-through lift (treatment − control) | **≥ +5 pp** at p < 0.05 | < +0 pp at end of window |
| Per-type regression (treatment − control, per personalised type) | (n/a — composite kill) | **< −3 pp** on any single personalised type → per-type rollback to static |
| Dismiss-rate change | flat or down | > +5 pp from baseline (advisory) |
| Disable-rate change | flat or down | > +3 pp (advisory; parent PRD already kills at +25 pp/month) |

**Readout window: 14 ± 4 days** (10–18 day floor / ceiling) per user, flexible to absorb non-uniform
sample accumulation rates. Earliest readout: day 10 (when per-user observation count crosses Bayesian
saturation point). Latest readout: day 18 (cap to prevent indefinite waiting). **Plus a post-population
aggregation later** — once corpus volume supports stable per-segment baselines, run a meta-analysis
across users to produce robust per-cohort priors. Picked over (a) aggregate-only (per-type regressions
hidden by average), (b) per-type lift (slower readout, higher sample-size requirement per type), and
(d) full composite (rigorous but likely under-calls wins).

### OQ-6 → resolved by PR #158 merge

PR #158 (the six lifecycle analytics events) merged 2026-04-30. The signal feeding this feature is
live on main. No remaining dependency.

---

## Still open at session pause

1. **Sequencing approach (A / B / C)** — proposed in last brainstorm message:
   - **A: Big-bang** — single PR ships everything (SR-17 + SR-18 + Settings UI + "Why?" sheet +
     Supabase migration + AI-engine writer hook + retention extension), ~15-20 files / ~1,500 LOC.
   - **B: Staged (recommended)** — three PRs:
     - PR 1: SR-17 data layer + Settings toggle (defaults off) + Supabase + AI-engine hook (zero
       user impact, validates write path).
     - PR 2: SR-18 timing automation (toggle defaults on, A/B begins).
     - PR 3: "Why?" sheet + per-type transparency UI.
   - **C: Vertical slice** — full stack but Nutrition Gap only in v1; expand in follow-up PR.
2. **Design sections** — architecture / components / data flow / error handling / testing — to be
   presented and approved one section at a time.
3. **Spec doc** at `docs/superpowers/specs/2026-04-30-smart-reminders-behavioral-learning-design.md`
   — not yet drafted.
4. **Spec self-review** + user review.
5. **Writing-plans skill invocation** — terminal step of brainstorming, produces the implementation
   plan.

## How to resume

Re-load the brainstorming skill (`/superpowers:brainstorming` or `Skill superpowers:brainstorming`),
re-read this section, and pick a sequencing approach (A / B / C). After that, the design sections,
spec doc, and plan can proceed without re-asking the locked questions.
