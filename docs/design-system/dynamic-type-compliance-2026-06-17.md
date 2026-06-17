# Dynamic Type Compliance Pass — 2026-06-17

> Closes the UI/UX Master Plan §2.5 accessibility line item "Dynamic Type full
> compliance — `@ScaledMetric` not on all text tokens." Companion to the
> [VoiceOver audit](voiceover-audit-2026-05-26.md). Branch:
> `chore/ios-dynamic-type-scaling`.

## Posture before this pass (the reality vs the line item)

The master-plan line implied broad non-compliance. Hands-on audit of
`FitTracker/Services/AppTheme.swift` found the opposite — the typography system is
**mostly already Dynamic-Type-compliant**:

- **~30 of 33 `AppText.*` text tokens** use *semantic* text styles
  (`Font.system(.body, …)`, `.title2`, `.caption`, …). These **scale automatically**
  with the user's preferred content size. ✅ No change needed.
- **Icon tokens** (`iconSmall`…`iconDisplay`) use fixed `Font.system(size:)` —
  **intentionally fixed** (SF Symbol illustrations in onboarding/empty-states). Left
  as-is; documented in the token comments.

The genuine gaps were narrow:

| Token | Issue | Verdict |
|---|---|---|
| `metricM` (25pt) | Fixed point size; comment **falsely claimed** it "scales relative to .title" | Real — Home/Body-comp status metric value text |
| `displayHeadline` (32pt) | Fixed point size; `OnboardingWelcomeView` comment also wrongly claimed it scales | Real — onboarding hero text |
| `displayLarge` (36pt) | Fixed point size | **Not text** — its only call site is a checkmark **icon** in a fixed 80×80 circle (`OnboardingFirstActionView`). Scaling would overflow the container. Correctly left fixed. |
| 22× `.frame(height: AppSize.ctaHeight)` | Fixed 52pt CTA height wrapping scaling button text → clips at large sizes | Real — layout clipping |

## Changes shipped

All changes render **identically at the default content size** and only affect
behaviour at large/accessibility text sizes — so regression risk is low even without a
per-size visual pass (the simulator visual surface is env-flaky per CLAUDE.md "CI
Pipeline" UI-test strategy).

1. **`ScaledFontModifier` + `View.scaledFont(size:weight:design:relativeTo:)`**
   (`AppTheme.swift`). Wraps `@ScaledMetric` so a specific point size scales relative to
   a reference text style while rendering at exactly the base size at default Dynamic
   Type. This is the "`@ScaledMetric` on text tokens" mechanism the line item asked for.
2. **`metricM` → `.scaledFont(size: 25, …, relativeTo: .title)`** at its 2 call sites
   (`BodyCompositionCard`). Misleading token comment corrected.
3. **`displayHeadline` → `.scaledFont(size: 32, …, relativeTo: .largeTitle)`** at its 1
   call site (`OnboardingWelcomeView`). The false "scales" comment corrected.
4. **CTA frames: `.frame(height:)` → `.frame(minHeight:)`** across all 22
   `AppSize.ctaHeight` sites. At default size the button is still exactly 52pt; at large
   sizes it grows to fit instead of clipping the label.

## Deliberately NOT changed

- **Icon tokens** — fixed by design.
- **`displayLarge`** — sole use is a fixed-container icon (see table). Token retained.
- **Circular controls** (`FrequencyCircle` `touchTargetLarge`, illustration frames) —
  fixed aspect/size by design; not text containers.

## Verification

- `make verify-ios` → **BUILD SUCCEEDED + TEST SUCCEEDED**
- `make ui-audit` → 0 P0 / 0 P1
- No token *values* changed; no semantic token added/removed (so `make tokens-check`
  unaffected). `scaledFont` is a rendering modifier, not a new token.

## Remaining (out of scope here)

- **Large-size visual verification** — a manual pass at AX3–AX5 content sizes across the
  6 core screens to confirm no unexpected reflow. Belongs to the same future
  VoiceOver-on simulator work item (`make verify-voiceover` / `verify-dynamic-type`
  runtime smoke profile) noted in the VoiceOver audit. This pass makes the surfaces
  *capable* of scaling; the runtime pass confirms the *result*.
