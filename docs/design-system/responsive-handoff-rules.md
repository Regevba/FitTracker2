# FitTracker Responsive Handoff Rules

This document is the shared contract between Figma and code whenever a component, asset, screen, or App Store deliverable is created.

## Current validation baseline

- Baseline runtime device: iPhone 14 Pro simulator
- Validation date: March 27, 2026
- Result: build, install, launch, and screenshot capture succeeded for the current auth entry surface without clipped assets or broken controls

This baseline does not replace compact-width QA. It is the minimum runtime check for any new system-level feature work.

## Core rules

1. Design iPhone compact first, then scale up.
2. Prefer semantic spacing and flexible frames over hard pixel widths.
3. When a width needs guidance, define a min, ideal, and max width instead of one rigid number.
4. Every asset handoff must specify content mode: fit, fill, crop, or preserve-original-ratio.
5. Every image-bearing component must specify its fallback when no asset is present.
6. Every text-bearing component must specify line limits, truncation, and narrow-width behavior.
7. Every chart or illustration must specify how labels collapse or move when width is constrained.
8. Every exportable asset must stay vector-first when possible. Prefer SF Symbols or SVG-like vector sources before raster exports.

## Asset-to-code handoff checklist

- Semantic token roles are mapped
- Min, ideal, and max dimensions are documented
- Aspect ratio is documented when applicable
- Content mode is documented
- Crop-safe area is documented for images or artwork
- Empty or missing-asset fallback is documented
- Light and dark contrast behavior is documented if the asset sits on multiple surfaces
- Export format and ownership are documented

## Component rules

### Buttons and CTAs

- Preserve a safe tap target before visual tightening.
- Allow label wrapping or horizontal compression before shrinking below touch-safe bounds.

### Input fields

- Numeric entry may use compact ideal widths, but should still compress on smaller iPhones.
- Labels stay visible outside the field.

### Selection tiles and carousels

- Horizontal option cards should use min, ideal, and max width ranges.
- If content cannot fit at the ideal width, card height may grow before text is clipped.

### Cards and summary panels

- Content should reflow vertically before hard clipping is introduced.
- Fixed-height cards are allowed only when the content is intentionally constrained and tested.

### Images, charts, and illustrations

- Define aspect ratio first.
- Define whether the asset is decorative, supportive, or essential to task completion.
- Define whether the asset may crop, and which edges are crop-safe.

## Figma requirements

- Every component page should include a short responsive note.
- Product-area pages should call out narrow-width behavior before final visual polish.
- App icon and App Store pages should keep source artwork, export sizes, and crop-safe guidance together.

## Runtime validation expectations

- Required: iPhone 14 Pro runtime check for new or materially changed feature surfaces
- Required: compact-width review in design before approval
- Recommended: one additional smaller-width simulator pass for dense new flows before release

## Known follow-up work

- Finish replacing remaining rigid widths in older screens as they are touched
- Add app icon source artwork and `AppIcon.appiconset`
- Add screenshot production templates for App Store upload
