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
