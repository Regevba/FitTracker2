# Feature Design Checklist

Use this checklist before implementing or approving any new feature.

## Research first

- Problem statement is explicit
- User goal is explicit
- Target user or job to be done is explicit
- Current friction or failure is documented
- Reason for solving now is documented

## Purpose and behavior

- Main purpose of the feature is written in one sentence
- Primary user action or decision is clear
- Entry points and return-user behavior are defined
- Data dependencies and failure points are identified

## Wireframes before final UI

- Low-fidelity wireframe exists for the main screen or flow
- Empty or first-run wireframe exists
- Error or interruption wireframe exists
- Regular-width adaptation wireframe exists if relevant
- Asset behavior is wireframed when imagery, charts, or illustrations can crop, stretch, or overflow
- UX review happened before high-fidelity UI

## Product intent

- What user problem is this feature solving?
- Which core platform is primary: iPhone, iPad, macOS, watch rules, or Android adaptation?
- What is the main action or decision the user should make?

## Design system fit

- Which existing shared components are being reused?
- Which semantic tokens are being used?
- If a new primitive is proposed, why can an existing one not be extended instead?

## States and behavior

- Default
- Loading
- Empty
- Error
- Success
- Disabled
- Long content / localization overflow
- Narrow-width overflow behavior for compact iPhones

## Accessibility

- Contrast checked
- Tap targets checked
- Dynamic Type checked
- Reduced motion considered if animation exists
- VoiceOver labels or accessible summaries considered for interactive elements

## Platform adaptations

- iPhone compact layout
- Baseline runtime check on iPhone 14 Pro
- iPad/macOS regular-width behavior
- watch rules if relevant
- Android / Pixel mapping note if the feature is expected to ship cross-platform

## Motion and haptics

- Any animation has a clear product purpose
- Haptics reinforce success, warning, or completion rather than decorate

## Documentation and rollout

- Feature spec created from the template when this is a new feature or major redesign
- Wireframe brief created before final UI
- `docs/design-system/responsive-handoff-rules.md` reviewed and followed
- Catalog updated if a shared component changed
- Docs updated if a new token, component, or pattern was introduced
- Roadmap/spec references the chosen system primitives
- Feature outcome captured in `docs/design-system/feature-memory.md`
