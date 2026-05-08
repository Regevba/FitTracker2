# Push Notifications — Research

> Status: Phase 0 research
> Framework: PM-flow v4.3
> Date: 2026-04-12

## 1. What is this solution?

Add a notification system for the moments where FitMe can help without creating noise:

- planned workout reminders
- readiness / recovery alerts
- streak or habit nudges
- granular notification preferences in Settings

## 2. Why this approach?

The product already has strong daily data, but no proactive surface. That means:

- users must remember to open the app
- readiness intelligence cannot reach the user at the right moment
- trend alerts and recovery guidance stop at the app boundary

## 3. Why this over alternatives?

| Approach | Pros | Cons | Chosen? |
|---|---|---|---|
| Local notifications first | simplest, privacy-friendly, fast to ship | limited remote intelligence | yes for phase 1 |
| Full remote push from day one | flexible, server-driven | more infra, consent, ops, content risk | later |
| No notifications, only in-app alerts | no permission friction | weak re-engagement | no |

## 4. External and product references

- Apple Human Interface Guidelines: notification permission should be contextual, not front-loaded
- Onboarding research in this repo already recommends deferring notification permission until user value is clear
- Existing analytics taxonomy already anticipates notification permission and settings surfaces

## 5. Competitive examples

- Whoop: daily readiness-style nudges, strong value framing
- Oura: recovery and sleep insight reminders
- Hevy / Strong: workout reminders and habit-based prompts

The lesson: high-value notifications are specific, sparse, and tied to a clear user benefit.

## 6. UX implications

- Ask for permission only after a value moment:
  - after first completed workout
  - or from Settings when the user explicitly enables reminders
- Start with small, understandable categories:
  - workout reminders
  - readiness alerts
  - trend alerts
- Provide an in-app preferences screen before expanding notification volume

## 7. Technical feasibility

Phase 1 is feasible with local notifications:

- `UNUserNotificationCenter`
- permission request flow
- local scheduling
- notification preferences storage
- analytics for permission and open-rate proxies

Phase 2 can evaluate remote orchestration if the local system proves valuable.

## 8. Risks

- permission prompt too early harms opt-in
- noisy alerts damage trust
- readiness messaging needs confidence thresholds to avoid false urgency
- analytics can under-measure impact if open attribution is weak

## 9. Draft success metrics

- notification opt-in rate > 40%
- workout reminder engagement lift > 10%
- readiness alert acknowledgement rate > 20%
- notification disable rate stays low enough to show trust is intact

## 10. Recommended approach

Phase 1 should be a focused local-notification feature:

1. notification preferences and permission timing design
2. workout reminders
3. readiness/trend alerts only where confidence is high
4. analytics instrumentation for permission, scheduling, and user response

This is a real PM-flow feature and should move to PRD once the user approves the scope.
