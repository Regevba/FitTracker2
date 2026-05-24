# FitMe Design Rules

> **Living catalog of cross-cutting design rules** that don't fit cleanly into the token system, component library, or per-feature spec but are nonetheless authoritative for any UI work on either surface (iOS app or fitme-story website).
>
> **Scope:** rules that apply to BOTH surfaces, OR rules that govern a primitive used across many features. Per-feature design decisions stay in [`docs/design-system/feature-memory.md`](feature-memory.md). UX foundations (the 13 principles) stay in [`docs/design-system/ux-foundations.md`](ux-foundations.md).
>
> **Companion:** [`docs/master-plan/ui-ux-master-plan-2026-05-24.md`](../master-plan/ui-ux-master-plan-2026-05-24.md) tracks the open / shipped UI/UX work itself; this doc holds the *rules* that work has to respect.
>
> **How rules land here:** any design rule surfaced in a session that's (a) load-bearing for >1 feature, (b) not derivable from existing tokens / components / ux-foundations, AND (c) currently undocumented OR only in agent memory — should get a section in this file. Source memory entries SHOULD be linked but the rule body lives here, not in memory (which decays).

---

## Rule index

1. [AI avatar = brand icon (living, communicative)](#1-ai-avatar--brand-icon-living-communicative)

---

## 1. AI avatar = brand icon (living, communicative)

**The FitMe brand icon is not a static logo. It IS the AI's visual persona. When AI syncs, thinks, adapts, or gives feedback, the icon animates — like Siri's orb but with the FitMe identity.**

### Why this rule exists

The user (Regev) decided the AI should feel like a *living part of the app*, not a hidden backend. The brand identity should be the face of the intelligence layer. The same icon that marks the FitMe brand in marketing should pulse on the home screen when the readiness engine computes today's score, rotate on the sync banner when HealthKit data is pulling, and shimmer next to a fresh AI recommendation card.

### Surfaces this rule applies to

- **iOS app** — every AI-related surface: AI Recommendation UI cards, ReadinessCard while computing, sync overlays, insight notifications, AIOrchestrator dispatch indicators
- **Website (fitme-story)** — wherever the brand icon appears in motion (e.g., loading states, sync indicators on `/control-room/*` operator dashboard) — same identity, same animation vocabulary
- **App Store assets** — the static brand icon stands in as the AI's identity even where motion isn't possible (App Store screenshots, marketing materials)

### Animation vocabulary

| State | Animation mode | When it fires |
|---|---|---|
| Idle / ambient awareness | `.breathe` | AI is listening but not actively working (default state on screens that surface AI output) |
| Syncing data | `.rotate` | HealthKit pull, scale sync, cloud upload, CloudKit reconciliation |
| New insight to share | `.pulse` | Fresh AI recommendation card appears, readiness score has changed materially, behavioral-learning fired |
| Computing / thinking | `.shimmer` | Readiness calculation running, pattern analysis in progress, AIOrchestrator dispatching |

Transitions between states should feel organic, not mechanical (e.g., `.shimmer → .pulse` when computation completes and a new insight emerges; `.rotate → .breathe` when sync finishes cleanly).

### Existing implementation components

Already in the codebase (per [`docs/design-system/feature-memory.md`](feature-memory.md) and `FitTracker/DesignSystem/`):

- `FitMeBrandIcon` — static icon, 4 sizes (small / medium / large / hero)
- `FitMeLogoLoader` — animated icon, 4 modes (`.breathe` / `.rotate` / `.pulse` / `.shimmer`), 3 sizes, respects `accessibilityReduceMotion`

Both use design system tokens (no raw color literals) and respect accessibility (Reduce Motion downgrades to the static icon).

### How to apply when building a new AI-touching surface

1. Use `FitMeBrandIcon` (static) OR `FitMeLogoLoader` (animated) — never substitute a generic spinner, generic AI sparkle, or third-party loader
2. Pick the animation mode from the table above based on what the AI is doing
3. Surface the icon at the moment AI activity is meaningful to the user (not always — over-animation reads as noise)
4. Respect `accessibilityReduceMotion` (the loader component already does; if you fork it, preserve that behavior)
5. When the AI surface is text-heavy (e.g., AI Recommendation card body), pair the animated icon with the text like a chat avatar pairing with a message — visually, the icon "speaks" the recommendation

### What this rule does NOT mean

- Not every spinner becomes the brand icon. Only AI-surface spinners (where the user should know "this is the AI working") get the brand-icon treatment. Generic data-loading (e.g., a list refreshing) stays a generic spinner per the design system.
- Not every animation. Static instances of `FitMeBrandIcon` are still correct in many places (logo header, splash, About screen).
- Not exclusive to AI features. The brand icon CAN appear as decoration elsewhere — but when AI work is happening, the brand icon is the *required* visual.

### Cross-references

- Source: memory `feedback_ai_avatar_brand_icon.md` (originSessionId: `4b5a092e-56f2-4b20-9d50-47f440778fcc`)
- Component spec: `FitTracker/DesignSystem/FitMeBrandIcon.swift` + `FitTracker/DesignSystem/FitMeLogoLoader.swift`
- Feature memory: [`docs/design-system/feature-memory.md`](feature-memory.md) AI-recommendation-ui entry
- Tracked in: [`docs/master-plan/ui-ux-master-plan-2026-05-24.md`](../master-plan/ui-ux-master-plan-2026-05-24.md) §4 cross-cutting tracks

---

## Change log

| Date | Change |
|---|---|
| 2026-05-24 | Initial creation. Codifies Rule #1 (AI avatar = brand icon) — was previously memory-only at `feedback_ai_avatar_brand_icon.md`, now durable surface per UX-R3 from ui-ux sub-plan. |
