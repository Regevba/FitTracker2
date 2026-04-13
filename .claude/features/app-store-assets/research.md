# App Store Assets — Research

> Status: Phase 0 research
> Framework: PM-flow v4.3
> Date: 2026-04-12

## 1. What is this solution?

Create the missing release-visual package for FitMe:

- master app icon
- platform icon outputs
- App Store screenshot system
- visual capture workflow tied to the live app truth

## 2. Why this approach?

The app cannot be considered release-ready while the visual store package is missing. This is not marketing polish; it is core release readiness.

## 3. Why this over alternatives?

| Approach | Pros | Cons | Chosen? |
|---|---|---|---|
| Build icon + screenshot system from real app screens | truthful, reusable, launch-ready | more setup work | yes |
| Ad hoc one-off screenshots | fast | drifts quickly, hard to maintain | no |
| Marketing mockups first | visually attractive | risks fake product representation | no |

## 4. Current repo reality

- no production app icon asset set is checked in
- App Store screenshot pipeline is still missing
- the v2 app surfaces are now strong enough to support truthful screenshot capture

## 5. Design constraints

- icon must reflect the actual FitMe brand system, not a generic fitness mark
- screenshots must come from the real app, with only light framing and annotation
- visuals should emphasize the current v2 strengths:
  - Today screen
  - Training plan
  - Nutrition
  - Stats
  - Settings
  - Onboarding

## 6. Technical and workflow implications

- capture needs a repeatable simulator/device flow
- likely pairing of:
  - simulator screenshots
  - Figma framing/template work
  - export targets for App Store sizes
- app icon generation should end with a checked-in `AppIcon.appiconset`

## 7. Risks

- using stale or inconsistent screen states
- creating screenshot art that overpromises missing runtime features
- shipping visuals before auth/runtime verification and remaining high-priority gaps are closed

## 8. Draft success metrics

- complete icon pipeline checked into repo
- complete screenshot template system for key device sizes
- asset refresh time for a new release stays low and repeatable

## 9. Recommended approach

Do this as a release-readiness feature after auth verification but before any real launch push:

1. define canonical screenshot story
2. capture polished real app states
3. build reusable Figma framing/templates
4. generate final App Store asset outputs

## 10. Notes

This remains high priority, but it is still downstream of auth runtime verification because launch visuals should reflect a truthfully working product.
