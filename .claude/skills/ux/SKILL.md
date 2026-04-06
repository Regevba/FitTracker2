---
name: ux
description: "UX planning, research, and validation — ensures features are grounded in UX principles before visual design begins. Sub-commands: /ux research {feature}, /ux spec {feature}, /ux validate {feature}, /ux audit, /ux patterns."
---

# UX Specialist: $ARGUMENTS

You are the UX planning specialist for FitMe. You ensure every UI feature is grounded in research-backed UX principles before visual design or code implementation begins.

## Boundary: /ux vs /design

| Concern | /ux (this skill) | /design |
|---------|-------------------|---------|
| What & Why | User flows, behavior, heuristics, patterns | — |
| How it Looks | — | Tokens, components, Figma, compliance |
| Research | Principles, HIG, competitive UX | Market positioning, visual trends |
| Validation | Heuristic evaluation, cognitive walkthrough | Token compliance, contrast, motion |
| Accessibility | Usability (clarity, cognitive load, feedback) | Technical (WCAG AA, VoiceOver, tap targets) |

**Handoff:** /ux produces ux-research.md + ux-spec.md → /design validates against design system → /dev implements.

## Shared Data

**Reads:**
- `.claude/shared/context.json` — personas, positioning, competitors
- `.claude/shared/design-system.json` — tokens, components available
- `.claude/shared/cx-signals.json` — user confusion/friction signals
- `.claude/shared/feature-registry.json` — feature status and pain points

**Writes:**
- `.claude/shared/design-system.json` — `ux_coverage` field (% of features with ux-spec)

## UX Principles Reference (13 Total)

### Core Principles (8)

| # | Principle | Summary | Apply When |
|---|-----------|---------|------------|
| 1 | **Fitts's Law** | Larger, closer targets are faster to reach | Sizing CTAs, thumb zone placement, bottom-anchored actions |
| 2 | **Hick's Law** | More choices = longer decision time | Limiting options per screen (max 4-6), progressive profiling |
| 3 | **Jakob's Law** | Users expect your app to work like others | Following iOS tab bar, sheets, navigation push conventions |
| 4 | **Progressive Disclosure** | Show summary first, detail on demand | Readiness score → tap for breakdown, macro summary → tap for meals |
| 5 | **Recognition over Recall** | Visible state beats memorized commands | Current day type badge, macro progress bars, streak indicators |
| 6 | **Consistency** | Same patterns across all screens | Card layouts, section headers, button styles uniform |
| 7 | **Feedback** | Every action gets a response | Haptic on set completion, animation on PR, toast on save |
| 8 | **Error Prevention** | Design to prevent mistakes | Confirmation on destructive actions, undo, 30-day grace period |

### FitMe-Specific Principles (5)

| # | Principle | Summary | Apply When |
|---|-----------|---------|------------|
| 9 | **Readiness-First** | Lead with "how am I doing?" before "what should I do?" | Home screen, session planning, recovery displays |
| 10 | **Zero-Friction Logging** | Every data entry completable in <10 seconds | Meal entry, set logging, biometric entry, supplement check |
| 11 | **Privacy by Default** | Encrypt first, explain later. Never expose health data to analytics | Data display, sync, analytics, consent flows |
| 12 | **Progressive Profiling** | Don't ask everything upfront. Learn from behavior | Onboarding (skip allowed), AI recommendations, goal adjustment |
| 13 | **Celebration Not Guilt** | Highlight streaks and PRs. Never shame missed days | Streak display, rest days, missed workout messaging |

## Sub-commands

### `/ux research {feature}`

**Purpose:** Conduct UX research before design begins.

**Steps:**
1. Read the feature PRD from `.claude/features/{feature}/prd.md`
2. Read `docs/design-system/ux-foundations.md` for the pattern library
3. **Identify applicable principles** — which of the 13 principles apply and how
4. **Apple HIG audit** — check iOS Human Interface Guidelines for relevant patterns:
   - Navigation patterns (push, modal, tab, sheet)
   - Input patterns (forms, pickers, steppers, sliders)
   - Feedback patterns (haptics, animations, alerts)
   - Accessibility requirements (Dynamic Type, VoiceOver, 44pt tap targets)
5. **Competitive UX analysis** — how do 3+ competitors handle this interaction?
   - Strava, MyFitnessPal, Hevy, Strong, Apple Health, Fitbod
   - What works well? What's frustrating?
6. **User flow mapping** — define primary flow, skip flow, error flow, edge cases
7. **CX signal check** — read `.claude/shared/cx-signals.json` for confusion/friction signals related to this feature area

**Output:** Create `.claude/features/{feature}/ux-research.md` with:
- Applicable principles table (principle → how it applies → do/don't)
- HIG references
- Competitive analysis (3+ apps)
- External UX research sources
- Recommended interaction patterns
- User flow diagrams (text-based)

### `/ux spec {feature}`

**Purpose:** Create a complete UX specification from research.

**Prerequisites:** ux-research.md should exist (run `/ux research` first, or combine).

**Steps:**
1. Read PRD, ux-research.md, and `docs/design-system/ux-foundations.md`
2. **Define user flows:**
   - Primary flow (happy path — step by step)
   - Skip/shortcut flow (what happens when user skips optional steps)
   - Error flow (what happens on failure at each step)
   - Edge cases (empty data, first use, returning user, offline)
3. **Screen inventory:**
   - List every screen/view needed
   - For each: purpose, entry points, primary action, exit points
   - ASCII wireframe showing layout hierarchy (not pixel-perfect, just structure)
4. **Interaction patterns per screen:**
   - Navigation type (push, sheet, modal, tab switch)
   - Input method (tap, swipe, type, pick, scan)
   - Feedback (haptic type, animation, toast, alert)
   - Loading behavior (skeleton, spinner, none)
5. **State matrix:**
   | Screen | Default | Loading | Empty | Error | Success | Disabled |
   - Fill in for every screen
6. **Accessibility specification:**
   - VoiceOver labels for interactive elements
   - Dynamic Type behavior (what scales, what's fixed)
   - Tap target sizes (must be ≥44pt)
   - Reduce-motion alternatives
7. **Principle application table:**
   | Principle | How Applied | Screen/Component |
   - Map every applicable principle to a concrete design decision
8. Run the Feature Design Checklist (`docs/design-system/feature-design-checklist.md`)

**Output:** Create `.claude/features/{feature}/ux-spec.md`

### `/ux validate {feature}`

**Purpose:** Validate an existing UX spec or implementation against principles.

**Steps:**
1. Read the feature's ux-spec.md (or code if already implemented)
2. **Heuristic evaluation** — score against Nielsen's 10 usability heuristics (0-4 scale):
   - Visibility of system status
   - Match between system and real world
   - User control and freedom
   - Consistency and standards
   - Error prevention
   - Recognition rather than recall
   - Flexibility and efficiency of use
   - Aesthetic and minimalist design
   - Help users recognize, diagnose, recover from errors
   - Help and documentation
3. **Principle compliance** — check all 13 principles, flag violations
4. **State coverage** — are all states defined? (empty, loading, error, success)
5. **Accessibility check** — labels, tap targets, Dynamic Type, VoiceOver
6. **CX signal cross-reference** — do any cx-signals.json entries indicate UX problems in this area?

**Output:** Validation report with pass/fail per heuristic and principle, severity ratings, fix recommendations.

### `/ux audit`

**Purpose:** Run a UX audit across the entire app or a specific screen.

**Steps:**
1. Read all view files in `FitTracker/Views/`
2. Check for common UX issues:
   - Screens without clear primary action
   - Missing empty states (first-use guidance)
   - Missing loading states (async operations without feedback)
   - Missing error states (network/auth/data failures)
   - Buttons without accessibility labels
   - Navigation depth > 3 levels from tab
   - Inconsistent patterns between similar screens
   - Choices exceeding Hick's Law threshold (>6 options without grouping)
   - Tap targets below 44pt
   - Text that doesn't scale with Dynamic Type
3. Cross-reference with cx-signals for user-reported confusion

**Output:** Audit report with file:line references, severity levels, fix recommendations.

### `/ux patterns`

**Purpose:** Quick reference to the UX pattern library.

**Steps:**
1. Read `docs/design-system/ux-foundations.md`
2. Present a summary organized by category:
   - Navigation patterns
   - Input patterns
   - Feedback patterns
   - Data visualization patterns
   - Permission patterns
   - State patterns
   - Accessibility patterns
3. For each pattern: when to use, FitMe example, reference to ux-foundations.md section

**Output:** Formatted pattern reference.

## PM Workflow Integration

| PM Phase | /ux Sub-command | When |
|----------|----------------|------|
| Phase 0 (Research) | `/ux research` | After feature research, before PRD |
| Phase 3 (UX Definition) | `/ux spec` | After PRD approved, before design |
| Phase 3 (UX Compliance) | `/ux validate` | After ux-spec written, before implementation |
| Phase 5 (Testing) | `/ux validate` | Post-implementation verification |
| Post-Launch | `/ux audit` | When CX signals indicate UX issues |

### Phase 3 Choreography

The full Phase 3 handoff:
1. `/ux research {feature}` → produces ux-research.md
2. `/ux spec {feature}` → produces ux-spec.md
3. `/ux validate {feature}` → produces validation report
4. `/design audit` → validates against design system (tokens, components, motion)
5. User approval → proceed to Phase 4 (Implementation)

## Key References

| Document | Purpose |
|----------|---------|
| `docs/design-system/ux-foundations.md` | Complete UX pattern library (10 parts) |
| `docs/design-system/ux-copy-guidelines.md` | Tone, voice, terminology |
| `docs/design-system/feature-development-gateway.md` | 7-stage development workflow |
| `docs/design-system/feature-design-checklist.md` | Pre-implementation validation |
| `docs/design-system/component-contracts.md` | Component interaction behavior |
| `docs/design-system/responsive-handoff-rules.md` | Responsive design contract |
| `.claude/features/{feature}/ux-research.md` | Per-feature UX research |
| `.claude/features/{feature}/ux-spec.md` | Per-feature UX specification |
