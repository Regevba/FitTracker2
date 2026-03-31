# FitTracker Feature Development Gateway

**Status:** Active as of 2026-03-27  
**Purpose:** This is the required path for every new feature, redesign, or major UI change.

## Why this gate exists

FitTracker should not move from idea to polished UI in one jump.

Every feature must first prove:

1. what user problem it solves
2. how the feature should behave
3. which flows and states are required
4. what the low-fidelity wireframe looks like
5. how the UX is validated before visual polish
6. how the final UI maps to the design system

This gate turns the design system into an operating model, not just a token file.

## Research-backed workflow

### Stage 1: Problem framing

Document before any UI work:

- user problem
- target user or job to be done
- failure or friction in the current experience
- primary platform first: iPhone, then iPad/macOS, then Android adaptation if relevant
- success metric or outcome

Questions to answer:

- What problem are we solving?
- Why now?
- What is the smallest meaningful improvement?
- What should the user be able to do after this ships that they cannot do well today?

### Stage 2: Behavior definition

Define how the feature behaves before styling it.

Document:

- entry points
- primary task flow
- edge cases
- empty, loading, error, success, and disabled states
- navigation consequences
- data dependencies
- accessibility expectations
- motion and haptics only if they reinforce understanding

Questions to answer:

- What is the main user decision?
- What happens if there is no data?
- What happens if data is partial, stale, or failing?
- What is the default state on first use and on return use?

### Stage 3: Low-fidelity wireframes

Create low-fidelity wireframes before visual polish.

The wireframe stage should focus on:

- layout
- hierarchy
- information density
- task flow
- screen-to-screen transitions
- not final color, effects, or decoration

Minimum outputs:

- one primary screen wireframe
- one empty or first-run state
- one failure or interruption state
- one regular-width or expanded-layout adaptation if the feature is not iPhone-only

### Stage 4: UX review

Review the wireframes before high-fidelity UI.

Review for:

- clarity of next action
- whether the most important information is above the fold
- whether choices are reversible where needed
- whether the interaction matches Apple platform expectations first
- whether the same feature has a clear Android adaptation path

### Stage 5: Final UI definition

Only after the wireframe and behavior review is approved:

- choose semantic tokens
- choose shared components
- identify any new primitive needed
- document states, copy, iconography, spacing, and platform adaptations

This is where final UI styling happens.

### Stage 6: Implementation

Implementation is complete only when:

- the chosen system primitives are used in code
- the feature appears in docs or the coded catalog when needed
- accessibility is verified
- tests or regression checks exist for critical system additions

### Stage 7: Post-implementation capture

Store the outcome for future work in repo memory:

- final decision
- chosen tokens and components
- known tradeoffs
- follow-up gaps

Use `docs/design-system/feature-memory.md` for this running project memory.

## Non-negotiable deliverables for every new feature

- problem statement
- behavior definition
- wireframe section
- UX review notes
- final UI mapping to system primitives
- platform adaptation note
- implementation notes
- memory entry after shipping

## What to do if a feature skips a stage

If a feature arrives with polished UI but no behavior definition or wireframe reasoning:

1. stop implementation
2. backfill the feature spec using the template
3. document assumptions
4. only continue when the task flow and states are explicit

## Sources that informed this gateway

- Apple HIG emphasizes hierarchy, harmony, consistency, platform conventions, and adaptive behavior across displays:
  - https://developer.apple.com/design/human-interface-guidelines/
- Spotify Encore documents the value of connected systems, semantic tokens, and automation over disconnected one-off systems:
  - https://spotify.design/article/reimagining-design-systems-at-spotify
  - https://spotify.design/article/can-i-get-an-encore-spotifys-design-system-three-years-on
- Android guidance emphasizes adaptive layouts, edge-to-edge behavior, and window size classes rather than fixed device recipes:
  - https://developer.android.com/design/ui/mobile
  - https://developer.android.com/design/ui/mobile/guides/layout-and-content/edge-to-edge
- Wear guidance reinforces that small-screen adaptations need their own hierarchy and motion rules:
  - https://developer.android.com/design/ui/wear/guides/get-started
- Figma guidance reinforces that library descriptions, variables, styles, and published libraries are part of how teams share and govern system intent:
  - https://help.figma.com/hc/en-us/articles/360039820134-Manage-and-Share-Styles
