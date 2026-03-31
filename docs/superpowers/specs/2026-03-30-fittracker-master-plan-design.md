# FitTracker Master Plan Design

**Date:** 2026-03-30
**Author:** Regev Barak + Claude
**Status:** Approved for implementation planning
**Scope:** Phase A (Cleanup) → Phase B (Design System v2) → Phase C (Phase 6 Backend) → Phase D (Skills Repo) → Phase E (Android/Pixel — deferred)

---

## Context

Phase 5 (iOS stability + Supabase integration) merged to `main` on 2026-03-30 (commit `85743c3`). The `codex/ui-integration` branch holds 14 commits of design system work (75 files, +7,149/-2,007 lines) built across 7 worktree branches — none yet merged to `main`. A comprehensive design system audit against Spotify Encore, Apple HIG, Material 3, IBM Carbon, Atlassian, GitHub Primer, Airbnb, and Linear reveals critical gaps (dark mode missing, WCAG contrast failures, no motion tokens, irregular spacing grid) alongside a strong foundation (semantic tokens, 9 components, 680+ usages, governance docs).

---

## Phase A — Repository Cleanup

**Goal:** Clean repo state before starting design system work. Zero noise in branch list, zero stale PRs.

### A1. Close stale PRs
- PR#8 (DRAFT full code review) — superseded by Phase 5, close without merge
- PR#11 (codex/auth-merge-ready, 1 file) — superseded by Phase 5 auth work, close without merge

### A2. Delete stale remote branches
Branches whose content is fully absorbed into `main` via Phase 5 squash:
- `fix/phase5-ios-stability`
- `fix/phase4-ios-auth-security`
- `feat/supabase-backend`
- `ci-check-test`
- `codex/supabase-auth-rollout-plan`

### A3. Local working directory sync
- Sync local `main` from `origin/main`
- Current branch `claude/verify-ai-plan-execution-BJHHC` has 7 old commits now absorbed into main + 24 uncommitted files (design system work). This uncommitted work is superseded by the ui-integration branch content — discard the local diffs, they are already better in `codex/ui-integration`.

### A4. Create integration branch
- Create `feat/design-system-v2` from current `main`
- Squash all 14 commits from `codex/ui-integration` into one clean commit on `feat/design-system-v2` (approach B: single conflict-resolution pass against Phase 5 changes)
- Conflict zones: `AuthManager.swift`, `SignInService.swift`, `AccountPanelView.swift`, `AppTheme.swift` — Phase 5 rewrote auth logic; ui-integration redesigned auth UI. Resolution strategy: keep Phase 5 auth logic, apply ui-integration visual layer on top.

### A5. Archive worktrees
- Once `feat/design-system-v2` absorbs `codex/ui-integration`, remove all 10 worktrees from `.worktrees/`
- Delete worktree branches after archiving: `codex/ui-foundation`, `codex/ui-auth`, `codex/ui-home`, `codex/ui-nutrition`, `codex/ui-stats`, `codex/ui-training`, `codex/ui-settings`, `codex/ui-integration`

**Gate:** `main` is clean, `feat/design-system-v2` exists with `codex/ui-integration` content squash-merged, CI green.

---

## Phase B — Design System v2

**Goal:** Pixel-perfect Figma ↔ Swift token pipeline. Complete system covering every component, screen, state, spacing, typography, color, icon. Accessible, dark-mode capable, Dynamic Type compliant. Simplified and readable for solo-developer maintenance.

### B1 — Token Pipeline

**Architecture:**
```
Figma Variables (source of truth for design decisions)
        ↓  Tokens Studio plugin → Export
design-tokens/tokens.json  (committed to repo, human-readable)
        ↓  Style Dictionary + Swift transform template
DesignTokens.swift  (auto-generated, never hand-edited, git-committed)
        ↑  AppTheme.swift references DesignTokens.*  (hand-authored semantics)
        ↑  AppDesignSystemComponents.swift  (hand-authored, references AppTheme.* only)
        ↑  Figma Code Connect  (maps Swift component API to Figma Inspect panel)
```

**Developer workflow (design change in Figma):**
1. Update Figma Variable
2. Tokens Studio → Export → overwrites `design-tokens/tokens.json`
3. `make tokens` → runs Style Dictionary → regenerates `DesignTokens.swift`
4. Commit both files together
5. CI validates generated file matches source JSON

**CI gate:** `make tokens` output must match committed `DesignTokens.swift`. Fails PR if drift detected.

**Files:**
- `design-tokens/tokens.json` — Tokens Studio export (replaces `docs/design-system/design-tokens.json`)
- `FitTracker/DesignSystem/DesignTokens.swift` — auto-generated
- `FitTracker/DesignSystem/AppTheme.swift` — semantic layer (existing, refactored)
- `FitTracker/DesignSystem/AppDesignSystemComponents.swift` — component library (existing, extended)
- `FitTracker/DesignSystem/AppDesignSystemCatalog.swift` — renamed from DesignSystemCatalogView
- `Makefile` — `tokens` target invoking Style Dictionary

### B2 — Three-Tier Token Architecture

Current system places raw RGB triples directly in semantic tokens (one brand color change = 40 lines of edits). New structure follows Spotify Encore's three-tier model:

**Tier 1 — Primitives** (`AppPalette.swift`, private):
```swift
// Raw values only. No semantic meaning. Never used directly in views.
private enum AppPalette {
    static let orange500 = Color(red: 0.98, green: 0.56, blue: 0.25)
    static let blue300   = Color(red: 0.54, green: 0.78, blue: 1.0)
    static let neutral0  = Color.white
    static let neutral100 = Color.black
    // … full tonal ramp per brand hue
}
```

**Tier 2 — Semantics** (`AppTheme.swift`, public):
```swift
// References primitives. Defines intent. Views always use this tier.
enum AppColor {
    enum Accent {
        static let primary = Color("accent-primary")  // asset catalog → dark mode aware
    }
}
```

**Tier 3 — Components** (`AppDesignSystemComponents.swift`):
```swift
// References semantics only. Never touches primitives or raw values.
struct AppButton: View {
    // uses AppColor.Accent.primary, AppText.button, AppSpacing.medium
}
```

### B3 — Foundation Hardening (pre-dark-mode pass)

Dark mode is intentionally deferred to B8 — added only after the entire light-mode system is confirmed and stable. Reason: dark mode requires understanding the full semantic intent of every token across every surface. Building dark mode before the system is complete leads to piecemeal decisions that create technical debt. Once the complete light-mode system is locked (B1–B7), the full token inventory is known, and adding dark variants becomes a systematic one-pass exercise rather than an iterative guess.

**What B3 does instead:**

- Extract `AppPalette.swift` (primitive tier) from `AppTheme.swift` — raw RGB triples move here, semantics reference primitives
- Fix `Text.tertiary` light-mode contrast: raise from `black.opacity(0.42)` (2.8:1, fails WCAG AA) to `black.opacity(0.55)` (≥4.6:1)
- Add `DEBUG`-only `ColorContrastValidator` — checks every text+background pairing against WCAG 4.5:1 on app launch so regressions are caught immediately
- Confirm all surface tokens are semantically named (no appearance-descriptive names like `materialStrong` that will break when dark mode assigns different raw values)

### B4 — Spacing & Radius Alignment

**Current spacing scale** violates 4pt grid at steps 6, 10, 14, 22.

**New spacing scale** (strict 4pt grid):
```
xxxSmall:  4     xxSmall:  8    xSmall: 12    small:  16
medium:   20     large:   24    xLarge: 32    xxLarge: 40
```

**New radius scale** (more differentiated for visual hierarchy):
```
xSmall:   8    small:  12    medium:  16
large:   24    xLarge: 32    sheet:   32    authSheet: 36
```

**Migration:** automated find-replace mapping old token names → new. Views that bypass tokens with inline literals get flagged in the same pass.

### B5 — Motion, Dynamic Type, Accessibility

**Motion tokens** (`AppMotion` enum, new):
```swift
enum AppMotion {
    enum Duration {
        static let fast:        Double = 0.15
        static let standard:    Double = 0.22
        static let slow:        Double = 0.38
        static let pageTransit: Double = 0.30
    }
    enum Easing {
        static let enter   = Animation.easeOut(duration: Duration.standard)
        static let exit    = Animation.easeIn(duration: Duration.fast)
        static let interactive = Animation.spring(response: 0.28, dampingFraction: 0.72)
    }
}
```

All 12+ inline animation literals replaced with `AppMotion.*` references.

**Reduce Motion:** `@Environment(\.accessibilityReduceMotion)` added to:
- `AppButton` (scale press animation)
- `AppSelectionTile` (bounce)
- All chart draw-on animations
- Any `withAnimation` call outside a component

Pattern:
```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion
.animation(reduceMotion ? .none : AppMotion.Easing.interactive, value: isPressed)
```

**Dynamic Type:**
- `metricDisplay` (currently hard-coded 48pt) → `@ScaledMetric(relativeTo: .largeTitle) var size: CGFloat = 48`
- `metricDisplayMono` (currently 42pt) → same pattern
- All data-dense metric views get `.minimumScaleFactor(0.6).lineLimit(1)`
- Test pass at `xxxLarge` Dynamic Type size before shipping

**VoiceOver:** `accessibilityLabel` added as standard parameter on all 9+ components. `AppCard` gets `semanticRole` parameter for automatic VoiceOver role assignment.

### B6 — Component Completions & New Primitives

**Existing components to extend:**
- `AppCard` — add `AppCardDensity` enum (`.compact/.default/.spacious`) replacing `contentPadding: CGFloat`
- `AppButton` — add `AppButtonWidth` enum (`.fill/.hug`) replacing `isFullWidth: Bool`
- `AppMenuRow` — add `accessibilityLabel` parameter
- All components — add `accessibilityLabel` standard parameter (IBM Carbon pattern)

**New components needed:**

| Component | Usage | API sketch |
|---|---|---|
| `AppPickerChip` | Stats filters, Training day selector | `label, isSelected, action` |
| `AppFilterBar` | Stats, Nutrition history | `options: [String], selection: Binding` |
| `AppSheetShell` | Standard bottom-sheet container | `title, content, primaryAction` |
| `AppStatRow` | Settings detail rows, profile stats | `label, value, icon?` |
| `AppSegmentedControl` | Chart period, training view toggle | `options, selection: Binding` |
| `AppProgressRing` | Goal completion, readiness | `value: Double, color, label` |

**New ViewModifiers:**
- `.appEyebrowStyle()` — consolidates 4+ repeating `.captionStrong + .uppercase + .tracking(1)` sites
- `.appReducedMotion(_ animation:)` — wraps reduce motion check
- `.appTextRole(_ role: AppTextRole)` — applies full text style (font + color) in one call

**AppIcon enum** (new, wraps all SF Symbol names used in app):
```swift
enum AppIcon {
    static let training    = "figure.strengthtraining.traditional"
    static let cardio      = "figure.run"
    static let nutrition   = "fork.knife"
    static let sleep       = "bed.double.fill"
    static let recovery    = "figure.walk"
    static let heart       = "heart.fill"
    static let weight      = "scalemass.fill"
    static let steps       = "figure.walk.motion"
    static let calories    = "flame.fill"
    static let progress    = "chart.line.uptrend.xyaxis"
    static let readiness   = "gauge.with.dots.needle.50percent"
    static let settings    = "gearshape.fill"
    // … complete inventory
}
```

**SF Symbol rendering upgrades:**
- Use `.symbolRenderingMode(.hierarchical)` for depth symbols (fitness figures, charts)
- Use `.symbolEffect(.bounce, value:)` for achievement moments (iOS 17+)
- Use `variableValue:` on `chart.bar.fill` for progress indicators

### B7 — Pixel-Perfect Figma Coverage

**What "pixel-perfect" means for iOS:** not identical to web pixel-perfect. Goal is **intent-perfect** — every visual property in code is driven by a token that maps 1:1 to a Figma Variable, so any Figma change propagates to code through the pipeline without ambiguity.

**Figma requirements for complete app mirroring:**

*Component pages (one per component):*
- All 15 components × all states (default / pressed / disabled / loading / error / empty)
- Light and dark variant frames side-by-side
- Token annotations on every property (shows which Figma Variable drives each value)
- Code Connect mapping so Inspect panel shows exact Swift call

*Screen pages (one per major screen):*
- Auth: WelcomeView, AuthHubView, SignInView, EmailRegistrationView, VerificationView
- Main: HomeScreen (today summary, active training state, rest day state)
- Training: TrainingPlanView (scheduled, active session, completed)
- Nutrition: NutritionView, MealEntrySheet, MacroTargetBar
- Stats: StatsView (all chart states)
- Settings: SettingsView (all sections)
- Account: AccountPanelView

Each screen frame:
- iPhone 16 Pro (393pt) as primary
- Dark mode variant
- Token annotations on key measurements
- Prototype wires to adjacent screens

*Prototype flows:*
- Auth flow (welcome → sign in → verification → home)
- Main tab navigation
- Meal logging flow (nutrition → entry sheet → confirmation)
- Training session flow (plan view → active session → completion)

*Repository pages:*
- Icon Repository: all SF Symbols used, rendered at 3 sizes, with AppIcon enum name
- Typography Repository: all 14 text roles with sample text at default and xxxLarge Dynamic Type
- Color Repository: all semantic tokens with light/dark swatches and contrast ratios
- Spacing & Radius: visual scale reference

**Gate:** every screen in the app has a corresponding locked Figma frame. Design changes start in Figma, propagate via token pipeline. No ad-hoc Swift color/spacing values added after this point.

### B8 — Dark Mode (after full light-mode system is confirmed)

**Prerequisite:** B1–B7 complete and merged to `main`. The full token inventory is known and stable.

**Rationale for deferral:** Dark mode requires mapping every semantic token to a dark-mode raw value. Doing this before the complete system is in place means making decisions without full context — which surfaces exist, which tokens are actually used vs redundant, what the visual hierarchy looks like end-to-end. A confirmed light-mode system gives a solid foundation to mirror into dark mode systematically and correctly.

**Strategy:**

- Convert all `AppColor.*` static properties from `Color(red:...)` literals to `Color("token-name")` referencing named colors in `Assets.xcassets`
- Each named color in `Assets.xcassets` has an "Any Appearance" (light) value and a "Dark" value
- Auth dark gradient (`authTop/Middle/Bottom`) already dark-native — validated and reused
- Tokens Studio export updated to include dark mode values; `DesignTokens.swift` regenerated

**Priority order:**
1. `Text.primary/secondary/tertiary` (fix tertiary to `white.opacity(0.62)` dark)
2. `Surface.primary/elevated/material/inverse`
3. `Background.appPrimary/appSecondary`
4. `Accent.primary/secondary`
5. `Status.success/warning/error`
6. `Border.hairline/subtle/strong`
7. `Chart.*` tokens

**Gate:** all screens pass in both light and dark mode. `ColorContrastValidator` passes in both modes. Figma frames have dark variants for every screen.

---

## Phase C — Phase 6 Backend

**Goal:** Complete Supabase backend, AI engine, and CI for all three repos. Runs in parallel with B7 (Figma work is design-side; backend is code-side).

### C1 — Supabase Remaining Work
- Complete RLS policies for all tables
- `program_phase` enum migration
- Realtime: wire `subscribeRealtime` and `unsubscribeRealtime` in `SupabaseSyncService` (currently stubs)
- Verify all 5 sync record types push/pull correctly end-to-end (daily_log, weekly_snapshot, user_profile, user_preferences, meal_templates)

### C2 — AI Engine (fittracker-ai repo)
- Complete remaining endpoint coverage (nutrition, recovery segments)
- Fix any outstanding test failures in `tests/test_training.py` and related
- Validate cohort frequency increment migration
- Deploy to Railway and confirm production URL is live

### C3 — Backend CI (fittracker-backend repo)
- CI green: schema migrations apply cleanly, RLS policies pass tests
- Remove any hardcoded secrets; confirm all use GitHub Actions secrets
- `pg_cron` retention job validated in staging

### C4 — iOS Integration Verification
- End-to-end test: sign in → sync pulls from Supabase → AI recommendation returns
- Verify `placeholder.supabase.co` stub client never makes network calls in tests
- Confirm GitGuardian clean on all three repos

**Gate:** All three repos have green CI. End-to-end flow works on a physical device.

---

## Phase D — Skills Repository (`regev-skills`)

**Goal:** A standalone public repo (`regev-skills`) containing Claude Code Superpowers skills organized into 8 categories. Built for FitTracker but designed as a reusable, project-agnostic showcase — demonstrating skill-building methodology for the Israeli hi-tech job market. Each skill is a self-contained, well-documented workflow that any team could adopt.

**Repo context:**

- General-purpose: skills are written to work beyond FitTracker
- Portfolio showcase: demonstrates systematic thinking about product development workflows
- Connected to this project: FitTracker uses the skills directly; they are battle-tested, not theoretical

### Repo Structure

```
regev-skills/
├── README.md                    — what this repo is, how to use it, skill index
├── SKILL_TEMPLATE.md            — standard template for authoring new skills
├── CONTRIBUTING.md              — how to propose, evaluate, and add a skill
├── 1-dev-pipeline/
│   └── *.md                     — CI, PR workflow, branch strategy, release cadence
├── 2-qa/
│   └── *.md                     — testing strategy, coverage, regression, accessibility
├── 3-marketing/
│   └── *.md                     — ASO, social, launch campaigns, release notes
├── 4-ui-implementation/
│   └── *.md                     — design system adoption, component dev, token pipeline
├── 5-ux-copy/
│   └── *.md                     — microcopy, onboarding, error messages, tone of voice
├── 6-cx/
│   └── *.md                     — support responses, feedback triage, review management
├── 7-data-analytics/
│   └── *.md                     — broad analytics framework; foundational to all other categories
└── 8-product-management/
    └── *.md                     — high-level research mode: market analysis, feature prioritization, competitive intelligence, roadmap reasoning
```

### Category Descriptions

**1. Dev Pipeline**
Covers the full software delivery lifecycle: feature branching, PR templates, CI configuration, release tagging, hotfix workflow, dependency updates.

**2. QA**
Test strategy (unit/integration/UI/snapshot), coverage thresholds, accessibility testing, regression suites, TestFlight distribution, crash reporting triage.

**3. Marketing**
App Store optimization (ASO), screenshot production, release notes writing, social media content, influencer/partnership outreach, paid UA strategy.

**4. UI Implementation**
Design system adoption rules, component development workflow, token pipeline operation, Figma → Swift translation, catalog maintenance, visual regression.

**5. UX Copy**
Microcopy standards, onboarding flow copy, empty state messages, error message taxonomy, push notification copy, App Store listing copy.

**6. CX (Customer Experience)**
Support response templates, user feedback triage, review response strategy, NPS follow-up, churn intervention, in-app feedback collection.

**7. Data & Analytics**
Broad framework skill that underpins categories 1–6. Covers: event taxonomy, funnel analysis, cohort analysis, A/B testing framework, KPI dashboards, AI insight interpretation. Designed to inform decisions in every other category.

**8. Product Management**
High-level research mode. Covers: market and competitive analysis, feature prioritization (RICE/ICE), user persona definition, product roadmap reasoning, stakeholder communication, OKR setting, hypothesis framing. Acts as the strategic north star that informs decisions across all other categories. Approached from a PM + Dev Lead dual perspective — always grounded in data and technical feasibility.

### Evaluation Protocol (before any skill is written)

Every skill undergoes a two-part evaluation before any file is written:

#### Part 1 — Strategic definition (PM + Dev Lead perspective)

1. **Problem statement** — what specific problem does this skill solve? Who feels the pain and when?
2. **Audience** — who is the primary user of this skill? (developer, PM, designer, Claude-as-agent)
3. **Pain points** — what is slow, error-prone, or missing in the current manual process?
4. **Success definition** — how will we know the skill is working? What outcome is better?

#### Part 2 — Research (before writing any skill logic)

**UI/UX research (if the skill touches design or frontend):**

- What UI patterns exist in the current codebase? (deep read of relevant views/components)
- What design decisions were already made? What constraints exist?
- What did previous iterations of this feature look like? (git history)

**Dev/coding research (all skills):**

- Current code state: read all relevant source files, understand existing APIs and patterns
- Online research: search for how similar problems have been solved in comparable projects, open-source workflows, industry-standard approaches (GitHub, blog posts, design system docs)
- Identify gaps between current state and best practice

#### Part 3 — Skill definition

1. **Goal** — what outcome does this skill produce?
2. **Trigger** — when should Claude invoke this skill? What user messages trigger it?
3. **Inputs** — what context does the skill need to do its job?
4. **Outputs** — what does the skill produce? (document / code / checklist / analysis)
5. **Scope boundaries** — what is explicitly out of scope?

This evaluation happens in conversation before any skill file is written. Phase D stops after evaluation of all skills in one category before moving to implementation.

---

## Phase E — Android / Pixel (Deferred)

**Priority:** Low. Begins only after Phases A–D are complete.

**Goal:** Build FitTracker for Android (Pixel-first), using the completed FitTracker design system as the source of truth. The semantic token foundation, component contracts, and Figma library built in Phase B make Android adaptation systematic rather than a full rebuild.

**Scope (to be spec'd in a dedicated design session):**

- Pixel-first (Google Pixel lineup as primary device target, then broader Android)
- Material 3 adaptation of FitTracker semantic tokens — `AppColor.*` maps to M3 color roles
- Kotlin + Jetpack Compose component library mirroring `AppDesignSystemComponents.swift`
- Shared business logic: explore Kotlin Multiplatform for models and sync logic already defined in Swift
- `regev-skills` Android category added once iOS skills are proven
- Figma library gains Android adaptation page (planned structure already in `docs/design-system/android-adaptation.md`)

**Why deferred:** The design system foundation (Phase B) is the critical prerequisite. Building Android before the semantic token layer is confirmed means building twice.

---

## Cross-Cutting Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Token pipeline | Tokens Studio + Style Dictionary | Figma Variables as source of truth; `make tokens` one-command sync |
| Dark mode timing | After B1–B7 confirmed | Full light-mode system needed before dark variants can be systematic |
| Dark mode strategy | Asset catalog named colors | Native iOS; supports High Contrast automatically |
| Spacing grid | 4pt grid (8 steps: 4–40) | Aligns with Carbon/HIG; exact Figma auto-layout match |
| Primitive tier | `AppPalette.swift` private enum | One file to change for brand color updates |
| Motion | `AppMotion` enum + reduce-motion guard | Consistent feel; accessibility compliant |
| Skills repo name | `regev-skills` (public, general-purpose) | Portfolio showcase for Israeli hi-tech job search; used by FitTracker but reusable |
| Phase D gate | Collaborative evaluation before writing | Avoids skills that miss the actual goal |
| ui-integration merge | Squash into `feat/design-system-v2` (approach B) | One clean conflict-resolution pass |
| Android timing | Phase E, after A–D complete | Design system foundation is the prerequisite |

---

## Dependencies & Sequencing

```
Phase A (Cleanup)
    └── Phase B1–B2 (Token pipeline + primitive tier)
            └── Phase B3 (Foundation hardening — contrast fix, no dark mode yet)
                    └── Phase B4–B6 (Spacing + motion + components + accessibility)
                            └── Phase B7 (Pixel-perfect Figma coverage)  ← parallel with Phase C
                                    └── Phase B8 (Dark mode — full system pass)
                                            └── Phase D (Skills repo, category by category)
                                                    └── Phase E (Android — deferred)

Phase C (Backend) — parallel with B7
```

---

## Open Questions (resolved)

| Question | Decision |
| --- | --- |
| Skills repo name | `regev-skills` — general-purpose, portfolio-grade |
| Dark mode timing | B8 — after full light-mode system confirmed (B1–B7) |
| Android | Phase E — deferred until A–D complete |

## Open Questions (still to resolve during implementation)

1. **Style Dictionary Swift template:** use community `swift-color-assets` transform or write a custom template matching the existing `AppTheme` namespace structure?
2. **Settings screen Figma lock:** proceed with B7 for all other screens while Settings is still being refined, or hold B7 until all screens are locked?
