# UI-Audit Baseline Burndown Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Drive `make ui-audit` baseline from 27 P0 + 103 P1 → 0 P0 + ≤20 P1, then promote the scanner from advisory to a hard CI gate — without introducing visual regressions.

**Architecture:** Three-layer safety model. (1) **Mirror layer** — before/after simulator screenshots per file, stored in `.build/mirrors/` and diffed before each commit. (2) **Rollback layer** — one file per commit with semantic-tagged baseline, enabling surgical `git revert` or mass revert to `v-ui-audit-baseline-2026-04-20`. (3) **Token layer** — missing AppMotion presets are added BEFORE migration so mappings are 1:1 semantic, not approximation. Burndown proceeds in two clusters (color P0, animation P0) with a hard stop after each phase for review.

**Tech Stack:** SwiftUI, Xcode 16 simulator, Python 3.12 stdlib (scanner), `xcrun simctl io booted screenshot` (mirror tool), `xcodebuild`, `make`.

**PM Workflow framing:** Enhancement to `design-system-v2` feature. Work item type: Enhancement (Tasks → Implement → Test → Merge). Case study tracking: concurrent per the 2026-04-13 rule. Feature state: `.claude/features/ui-audit-baseline-burndown/`.

**Parent branch:** `claude/review-ui-consistency-zSkvJ` (verification layer, 3 commits ahead of main, pushed). This plan extends that branch — verification layer and burndown ship as one logical unit so the gate arrives with P0=0 already satisfied.

**Scope boundary:** This plan covers P0 burndown (27 → 0) + scanner hardening + gate promotion + pbxproj orphan cleanup. **P1 burndown (103 → ≤20) is explicitly deferred to a follow-on plan** — the P1 class (magic padding, missing a11y labels on icon buttons) needs its own token-grid audit and a11y audit that dilute the P0 story. Folding them in triples scope and blurs the rollback story.

---

## Risk mitigation summary

Maps to the 6 risks identified in the prior assessment:

| Risk | Mitigation | Task(s) |
|---|---|---|
| **R1. Silent visual regressions from token swaps** | Mirror harness captures before/after screenshots per file; manual diff gate before each commit; dark-mode pass explicitly checked | 0.3, every file task |
| **R2. Animation token gaps** | Phase 0.1 audits AppMotion coverage against all 6 raw animation call sites; new tokens added to AppMotion.swift BEFORE any file is migrated | 0.1 |
| **R3. Advisory-only enforcement** | Phase 3.2 promotes `ui-audit` to `verify-local` once baseline P0 = 0, making it a hard gate going forward | 3.2 |
| **R4. Scanner false negatives** | Phase 4.1 adds regex coverage for computed Color properties, interpolated names, nested modifier chains | 4.1 |
| **R5. Baseline drift** | Phase 4.2 adds a CI check that re-runs `--baseline --no-fail` on PR and fails if the committed doc differs | 4.2 |
| **R6. pbxproj orphan cleanup volatility** | Phase 4.3 cleans orphans in a separate PR gated on no-Xcode-UI-opens between diagnosis and merge | 4.3 |

---

## File Structure

### Files created
- `.claude/features/ui-audit-baseline-burndown/state.json` — PM workflow state
- `.claude/features/ui-audit-baseline-burndown/case-study.md` — concurrent living case study
- `scripts/ui-mirror.sh` — wraps `xcrun simctl io booted screenshot` with a named-screen convention
- `.build/mirrors/` — gitignored directory for before/after PNGs (do NOT commit binaries)
- `docs/design-system/mirrors/README.md` — documents the mirror workflow and retention policy

### Files modified
- `scripts/ui-audit.py` — add `--file PATH` flag (Phase 0.2); add new regex rules (Phase 4.1)
- `FitTracker/DesignSystem/AppMotion.swift` — add new spring/easing/loading tokens identified in Phase 0.1
- `Makefile` — add `ui-audit` to `verify-local` dependencies (Phase 3.2); add `ui-audit-drift` target (Phase 4.2)
- `.gitignore` — add `.build/mirrors/` entry
- `docs/design-system/ui-audit-baseline.md` — regenerated at every P0 fix + final sweep
- `docs/design-system/feature-memory.md` — one entry per file-task; consolidation entry at end
- `FitTracker.xcodeproj/project.pbxproj` — Phase 4.3 orphan removal at lines 34 + 40
- Twelve view files listed in Phase 1 + Phase 2

### Files not modified (guardrails)
- `CLAUDE.md` — no changes; the Verification Layer section added in commit `573fe8a` already encodes the rules
- `FitTracker/Services/AppTheme.swift` — token surface is frozen for this plan; new tokens go in `AppMotion.swift` only (color tokens are complete per the chart-color fix in `cf3cf56`)
- Any v1 `// HISTORICAL` file — read-only; scanner already skips

---

## Burndown procedure (template applied in Phases 1 + 2)

Every file-task in Phase 1 and Phase 2 follows this exact procedure. Defined once here so the per-file tasks stay compact.

- [ ] **P.1 — Capture before-mirror**

Launch Simulator (iPhone 16 Pro, booted). Navigate to the screen this file renders. Run:

```bash
./scripts/ui-mirror.sh <file-stem>-before-light  # light mode
# Toggle dark mode in Simulator: Cmd+Shift+A
./scripts/ui-mirror.sh <file-stem>-before-dark   # dark mode
```

Expected output: `.build/mirrors/<file-stem>-before-light.png` and `-dark.png` written. If the screen needs preconditions (signed-in state, filled form), use the dev-mode shortcut in `RootTabView` (`AppConfig.devMode`). If a screen cannot be reached from the current simulator state, note the blocker in the task comment and skip mirror — do NOT migrate without a mirror reference.

- [ ] **P.2 — Run scanner on target file, record findings**

```bash
python3 scripts/ui-audit.py --file FitTracker/Views/<path>/<File>.swift
```

Expected: N P0 findings matching the Phase table below. If count differs, STOP and surface the discrepancy — the baseline has drifted and the plan needs a re-audit.

- [ ] **P.3 — Apply semantic token migrations**

Read the Mappings subsection for this file. Apply each replacement with the `Edit` tool. Keep edits surgical — no adjacent refactors, no import reorganization, no whitespace churn.

- [ ] **P.4 — Re-run scanner on target file, confirm 0 findings**

```bash
python3 scripts/ui-audit.py --file FitTracker/Views/<path>/<File>.swift
```

Expected: `0 P0, 0 P1` for this file (P1 count for this file should also reach 0 as a side-effect; if it doesn't, note remaining P1s — they belong to the deferred P1 plan).

- [ ] **P.5 — Build with `make verify-ios`**

```bash
make verify-ios 2>&1 | tail -20
```

Expected: `** BUILD SUCCEEDED **`. If compile fails, the token name is wrong — check against `FitTracker/Services/AppTheme.swift` + `AppMotion.swift`.

- [ ] **P.6 — Capture after-mirror + manual diff**

```bash
./scripts/ui-mirror.sh <file-stem>-after-light
# Toggle dark mode
./scripts/ui-mirror.sh <file-stem>-after-dark
```

Then manually open before/after pairs side-by-side (Preview.app, Cmd+Option+Return splits the window). Compare:
- Text contrast on colored backgrounds — inverse tokens should look identical to pure white on brand-orange
- Dark mode behavior — v2 screens should flip surfaces correctly
- Animation timing and feel — if migrated an animation, trigger it and watch for perceptible feel change

If any unintended change, STOP, revert the file, re-examine the mapping. Do not commit until diffs are clean.

- [ ] **P.7 — Update feature memory log**

Append one line to `docs/design-system/feature-memory.md`:

```markdown
### 2026-MM-DD — UI-Audit P0 burndown: <FileName>.swift
- Replaced N raw literals with semantic tokens (list key ones)
- Mirror diff: clean (light + dark)
- Scanner: 0 P0, 0 P1 for file
```

- [ ] **P.8 — Commit (one file per commit)**

```bash
git add FitTracker/Views/<path>/<File>.swift docs/design-system/feature-memory.md
git commit -m "ui-audit: migrate <FileName> raw literals to semantic tokens

N P0 eliminated. Mappings: <summary>.
Mirror diff verified clean in light + dark.
Scanner: 0 P0, 0 P1 for file."
```

- [ ] **P.9 — Regenerate baseline (every 3-4 files or at end of phase)**

Running this per-commit creates excessive churn in `docs/design-system/ui-audit-baseline.md`. Regenerate at natural batch boundaries:

```bash
python3 scripts/ui-audit.py --baseline --no-fail
git add docs/design-system/ui-audit-baseline.md
git commit -m "ui-audit: regenerate baseline after <phase/cluster> completion"
```

---

## Phase 0: Safety infrastructure

### Task 0.1: Audit AppMotion coverage + add missing tokens

**Goal:** Every raw animation call site in the P0 list has a semantic AppMotion equivalent BEFORE any file is migrated. No approximations.

**Files:**
- Modify: `FitTracker/DesignSystem/AppMotion.swift`

**Background — raw animation sites in P0 scope:**

| File | Site | Current |
|---|---|---|
| `WelcomeView.swift:137` | Hero spring entry | `.spring(response: 0.8, dampingFraction: 0.7).delay(0.1)` |
| `WelcomeView.swift:140` | Caption fade-in | `.easeOut(duration: 0.6).delay(0.4)` |
| `WelcomeView.swift:143` | CTA fade-in | `.easeOut(duration: 0.6).delay(0.7)` |
| `OnboardingFirstActionView.swift:103` | Step advance | `.spring(response: 0.5, dampingFraction: 0.7).delay(0.2)` |
| `ReadinessCard.swift:22` | Score update | `.easeInOut` (no explicit duration, SwiftUI default ~0.35s) |
| `ReadinessCard.swift:159` | Dial pulse | `.interpolatingSpring(stiffness: 40, damping: 8)` |
| `TrainingPlanView.swift:524` | Shimmer loop | `.linear(duration: 1.2).repeatForever(autoreverses: false)` |

**Existing tokens that cover these:**
- `AppEasing.short` (easeInOut 0.20s) — close to ReadinessCard:22 but slower default may be intentional
- `AppLoadingAnimation.rotate` (linear 2.0s repeatForever) — close to TrainingPlanView:524 but 1.2s was likely tuned for a specific shimmer

**Tokens to add (proposed):**

```swift
// MARK: - Duration (extend)
static let hero: Double = 0.80  // Welcome hero entry

// MARK: - Spring presets (extend)
/// Hero entry: welcome screen title + brand icon (slow, gentle)
static let hero       = Animation.spring(response: 0.80, dampingFraction: 0.70)
/// Step advance: onboarding step transitions
static let stepAdvance = Animation.spring(response: 0.50, dampingFraction: 0.70)
/// Dial pulse: readiness dial physics — interpolating spring for continuous physics feel
static let dialPulse  = Animation.interpolatingSpring(stiffness: 40, damping: 8)

// MARK: - Easing (extend)
/// Hero caption: slow easeOut for staggered text entry
static let hero       = Animation.easeOut(duration: AppDuration.hero.map { 0.6 } ?? 0.6)  // actually: .easeOut(0.6)
static let heroEntry  = Animation.easeOut(duration: 0.60)

// MARK: - Loading animation presets (extend)
/// Fast shimmer: UI scrolling gradient — linear 1.2s repeatForever.
/// Use for: progress bar indeterminate states.
static let fastShimmer = Animation.linear(duration: 1.2).repeatForever(autoreverses: false)
```

- [ ] **Step 1: Read current AppMotion.swift top-to-bottom**

```bash
cat FitTracker/DesignSystem/AppMotion.swift
```

Confirm `AppDuration`, `AppSpring`, `AppEasing`, `AppLoadingAnimation` are the four extension points. Verify nothing I'm about to add already exists under a different name.

- [ ] **Step 2: Add `AppDuration.hero = 0.80`**

Use `Edit` on `FitTracker/DesignSystem/AppMotion.swift`, after the `xLong` line inside `enum AppDuration`:

```swift
    /// Hero: welcome title entry, celebration lead — 800 ms
    static let hero: Double = 0.80
```

- [ ] **Step 3: Add three new springs to `enum AppSpring`**

```swift
    /// Hero entry: welcome screen title + brand icon (slow, gentle)
    static let hero        = Animation.spring(response: 0.80, dampingFraction: 0.70)
    /// Step advance: onboarding step transitions
    static let stepAdvance = Animation.spring(response: 0.50, dampingFraction: 0.70)
    /// Dial pulse: readiness physics — interpolating for continuous physics feel
    static let dialPulse   = Animation.interpolatingSpring(stiffness: 40, damping: 8)
```

- [ ] **Step 4: Add `AppEasing.heroEntry`**

Inside `enum AppEasing`:

```swift
    /// Hero caption: slow easeOut for staggered hero text entry
    static let heroEntry = Animation.easeOut(duration: AppDuration.xLong)  // 0.60
```

- [ ] **Step 5: Add `AppLoadingAnimation.fastShimmer`**

Inside `enum AppLoadingAnimation`:

```swift
    /// Fast shimmer: progress bar indeterminate gradient, 1.2s linear loop.
    /// Use for: progress bar scrolling gradient, skeleton shimmer.
    static let fastShimmer = Animation.linear(duration: 1.2).repeatForever(autoreverses: false)
```

- [ ] **Step 6: Build**

```bash
make verify-ios 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`. If fail, syntax error in new declarations.

- [ ] **Step 7: Sanity check — tokens file references grep clean**

```bash
grep -c "AppSpring\.\|AppEasing\.\|AppLoadingAnimation\." FitTracker/DesignSystem/AppMotion.swift
```

Expected: multiple hits (definitions themselves). Just a smoke test — the compile above was the real check.

- [ ] **Step 8: Commit**

```bash
git add FitTracker/DesignSystem/AppMotion.swift
git commit -m "design-tokens: add AppSpring.hero/stepAdvance/dialPulse, AppEasing.heroEntry, AppLoadingAnimation.fastShimmer

Closes AppMotion coverage gaps for the 7 raw animation call sites
flagged by ui-audit Phase 1 P0 cluster. No call sites migrated yet —
tokens land first so Phase 1/2 migrations are 1:1 semantic, not
approximation."
```

---

### Task 0.2: Extend scanner with `--file PATH` flag

**Goal:** Enable per-file invocation during burndown so P.2 + P.4 of the procedure run fast and produce per-file reports.

**Files:**
- Modify: `scripts/ui-audit.py`

- [ ] **Step 1: Read scanner source**

```bash
wc -l scripts/ui-audit.py
head -60 scripts/ui-audit.py
```

Note the argparse setup and the main walk loop.

- [ ] **Step 2: Add `--file PATH` argument**

Locate the argparse block. Add:

```python
parser.add_argument(
    "--file",
    action="append",
    default=None,
    help="Scan only specific file(s). Can be repeated. Skips SKIP_FILES check since you opted in.",
)
```

- [ ] **Step 3: Branch in main walk**

Locate where the walk starts (likely `for root, _, files in os.walk(...)`). Wrap it:

```python
if args.file:
    targets = [Path(p) for p in args.file]
    violations = []
    for path in targets:
        if not path.exists():
            print(f"ERROR: {path} not found", file=sys.stderr)
            sys.exit(2)
        violations.extend(scan_file(path))
else:
    # existing walk logic
```

- [ ] **Step 4: Test on a clean file**

```bash
python3 scripts/ui-audit.py --file FitTracker/Views/Main/v2/MainScreenView.swift
```

Expected: low or 0 P0 count (MainScreenView is not in the P0 table). Output format matches the existing report.

- [ ] **Step 5: Test on a dirty file**

```bash
python3 scripts/ui-audit.py --file FitTracker/Views/Onboarding/v2/OnboardingAuthView.swift
```

Expected: 8 P0 findings (matches the P0 table in handoff).

- [ ] **Step 6: Test error path**

```bash
python3 scripts/ui-audit.py --file does/not/exist.swift
```

Expected: exit code 2, error message on stderr.

- [ ] **Step 7: Commit**

```bash
git add scripts/ui-audit.py
git commit -m "ui-audit: add --file flag for per-file invocation

Enables per-file scanning during burndown procedure (P.2, P.4). Bypasses
SKIP_FILES for explicit opt-in. Existing full-walk behavior unchanged
when --file is omitted."
```

---

### Task 0.3: Mirror harness + feature state scaffolding

**Goal:** Before/after screenshot workflow + PM workflow state + case-study skeleton.

**Files:**
- Create: `scripts/ui-mirror.sh`
- Create: `.gitignore` append for `.build/mirrors/`
- Create: `.claude/features/ui-audit-baseline-burndown/state.json`
- Create: `.claude/features/ui-audit-baseline-burndown/case-study.md`
- Create: `docs/design-system/mirrors/README.md`

- [ ] **Step 1: Create `scripts/ui-mirror.sh`**

```bash
#!/usr/bin/env bash
# scripts/ui-mirror.sh <label>
# Captures booted-simulator screenshot to .build/mirrors/<label>.png
# for before/after visual verification during UI-audit burndown.
set -euo pipefail

LABEL="${1:-}"
if [ -z "$LABEL" ]; then
  echo "Usage: $0 <label>" >&2
  echo "Example: $0 OnboardingAuthView-before-light" >&2
  exit 1
fi

MIRROR_DIR=".build/mirrors"
mkdir -p "$MIRROR_DIR"

OUT="$MIRROR_DIR/$LABEL.png"
xcrun simctl io booted screenshot "$OUT"
echo "Captured: $OUT"
```

- [ ] **Step 2: chmod +x the script**

```bash
chmod +x scripts/ui-mirror.sh
```

- [ ] **Step 3: Smoke-test the harness**

Boot simulator manually (Xcode → Simulator), then:

```bash
./scripts/ui-mirror.sh smoke-test
ls -lh .build/mirrors/smoke-test.png
rm .build/mirrors/smoke-test.png
```

Expected: a valid PNG file written and removed.

- [ ] **Step 4: Gitignore the mirror directory**

Append to `.gitignore` (confirm `.build/` isn't already covered — if it is, this is a no-op). If `.build/` is already ignored wholesale, skip this step and note in case study.

```
# UI-audit before/after screenshots — local verification only
.build/mirrors/
```

- [ ] **Step 5: Create feature state**

Write `.claude/features/ui-audit-baseline-burndown/state.json`:

```json
{
  "feature": "ui-audit-baseline-burndown",
  "type": "enhancement",
  "parent_feature": "design-system-v2",
  "phase": "implement",
  "phases": {
    "research": { "skipped": true, "reason": "covered by handoff doc + baseline" },
    "prd":      { "skipped": true, "reason": "enhancement; parent PRD covers scope" },
    "tasks":    { "completed": true, "plan": "docs/superpowers/plans/2026-04-20-ui-audit-baseline-burndown.md" },
    "ux_or_integration": { "skipped": true, "reason": "no new UI; token migration only; v2-refactor checklist N/A" },
    "implement": { "phase": "in_progress" },
    "test":      { "phase": "pending" },
    "review":    { "phase": "pending" },
    "merge":     { "phase": "pending" },
    "docs":      { "phase": "pending" }
  },
  "metrics": {
    "primary": "baseline_p0_count",
    "baseline": 27,
    "target": 0,
    "kill_criteria": "visual regressions reported post-merge > 2"
  },
  "case_study": ".claude/features/ui-audit-baseline-burndown/case-study.md"
}
```

- [ ] **Step 6: Create case-study skeleton**

Write `.claude/features/ui-audit-baseline-burndown/case-study.md` with section headers only (content fills as phases ship):

```markdown
# UI-Audit Baseline Burndown — Case Study

**Status:** In progress
**Started:** 2026-04-20
**Parent feature:** design-system-v2
**PRs:** TBD

## Context
[Filled after Phase 0]

## The gap
[Why verification layer existed but gate couldn't turn on]

## Approach
[Three-layer safety model: mirror / rollback / motion tokens first]

## Per-file burndown log
[One entry per commit in Phases 1 + 2]

## Metrics
- Baseline P0: 27
- Target P0: 0
- Visual regressions: 0 (target)
- Mirror diffs captured: TBD
- AppMotion tokens added: TBD

## Framework lessons
[Filled at Phase 5 close-out]
```

- [ ] **Step 7: Mirror workflow doc**

Write `docs/design-system/mirrors/README.md`:

```markdown
# UI-Audit Mirror Workflow

Before/after simulator screenshots captured during the UI-audit
baseline burndown (Phase 1 + 2). Mirrors live at `.build/mirrors/`
and are gitignored — they are local verification artifacts only.

## Naming
`<FileStem>-<before|after>-<light|dark>.png`

Example: `OnboardingAuthView-before-light.png`

## Retention
Mirrors are retained for the duration of the burndown only. Delete
`.build/mirrors/` after the gate promotes to hard CI (Phase 3.2).
Long-term visual regression safety is handled by snapshot tests
(deferred — see `figma-code-sync-status.md` Gap-C).

## Workflow
See burndown procedure in the implementation plan.
```

- [ ] **Step 8: Commit infrastructure**

```bash
git add scripts/ui-mirror.sh .gitignore .claude/features/ui-audit-baseline-burndown/ docs/design-system/mirrors/
git commit -m "ui-audit: mirror harness + feature state + case-study skeleton

Phase 0 safety infra for the P0 burndown. Mirror harness wraps
xcrun simctl screenshot with a naming convention; gitignored. Feature
state scaffolds PM workflow tracking. Case study skeleton ready for
per-file entries in Phase 1/2."
```

---

## Phase 1: P0 burndown — color cluster (8 files, 22 P0)

Each file follows the burndown procedure (P.1 → P.9) defined above.
Tasks are ordered by P0 count descending so the biggest wins land first.

### Task 1.1: OnboardingAuthView.swift — 8 P0

**File:** `FitTracker/Views/Onboarding/v2/OnboardingAuthView.swift`

**Mappings:**

| Line pattern | Before | After |
|---|---|---|
| `.foregroundStyle(.white)` × 5 | `.foregroundStyle(.white)` | `.foregroundStyle(AppColor.Text.inversePrimary)` |
| `Color.white` × 2 | `Color.white` | `AppColor.Text.inversePrimary` |
| `.foregroundStyle(.blue)` × 1 | `.foregroundStyle(.blue)` | `.foregroundStyle(AppColor.Brand.primary)` |

**Dark-mode check:** The auth screens intentionally use a brand-gradient background in both modes (per memory `feedback_welcome_screen_design.md`). Inverse-primary must remain readable on that gradient in both modes. If the after-dark mirror shows contrast regression, escalate — a new `AppColor.Text.onBrand` token may be needed.

Apply procedure P.1 – P.9. Skip P.9 here (batch at end of cluster).

### Task 1.2: AuthHubView.swift — 3 P0

**File:** `FitTracker/Views/Auth/AuthHubView.swift`

**Mappings:**
- `.foregroundStyle(.white)` × 2 → `.foregroundStyle(AppColor.Text.inversePrimary)`
- `Color.white` × 1 → `AppColor.Text.inversePrimary` OR `AppColor.Surface.elevated` — READ CONTEXT: if used as a fill/background it's surface, if text it's inverse. Do not guess.

Apply procedure P.1 – P.8.

### Task 1.3: SignInView.swift — 2 P0

**File:** `FitTracker/Views/Auth/SignInView.swift`

**Mappings:**
- `Color(.systemBackground)` × 2 → `AppColor.Surface.primary`

**Note:** `.systemBackground` is UIKit bridging. `AppColor.Surface.primary` maps to the colorset that matches system background in light + dark. Verify at P.6.

Apply procedure P.1 – P.8.

### Task 1.4: ConsentView.swift — 2 P0

**File:** `FitTracker/Views/ConsentView.swift`

**Mappings:**
- `Color.white` × 1 → context-dependent (surface vs inverse text) — read first
- `.foregroundStyle(.white)` × 1 → `.foregroundStyle(AppColor.Text.inversePrimary)`

Apply procedure P.1 – P.8.

### Task 1.5: ProfileHeroSection.swift — 2 P0

**File:** `FitTracker/Views/Profile/ProfileHeroSection.swift`

**Mappings:**
- `.foregroundStyle(.white)` × 2 → `.foregroundStyle(AppColor.Text.inversePrimary)`

Apply procedure P.1 – P.8.

### Task 1.6: MilestoneModal.swift — 2 P0

**File:** `FitTracker/Views/Shared/MilestoneModal.swift`

**Mappings:**
- `.foregroundStyle(.white)` × 2 → `.foregroundStyle(AppColor.Text.inversePrimary)`

**Animation note:** Milestones use `AppSpring.bouncy` historically. If a raw spring is ALSO flagged here (cross-check P.2 output) it's in-cluster and can be fixed at the same time; if it's not flagged, leave animation untouched (out of scope).

Apply procedure P.1 – P.8.

### Task 1.7: AccountPanelView.swift — 1 P0

**File:** `FitTracker/Views/Auth/AccountPanelView.swift`

**Mappings:**
- `.foregroundStyle(.white)` × 1 → `.foregroundStyle(AppColor.Text.inversePrimary)`

Apply procedure P.1 – P.8.

### Task 1.8: BodyCompositionCard.swift — 1 P0

**File:** `FitTracker/Views/Main/BodyCompositionCard.swift`

**Mappings:**
- `.foregroundStyle(.white)` × 1 → `.foregroundStyle(AppColor.Text.inversePrimary)`

Apply procedure P.1 – P.8. At P.9, regenerate baseline for Phase 1 cluster.

### Task 1.9: Phase 1 baseline regeneration + review checkpoint

- [ ] **Step 1: Regenerate baseline**

```bash
python3 scripts/ui-audit.py --baseline --no-fail
```

- [ ] **Step 2: Verify color-cluster P0 = 0**

```bash
python3 scripts/ui-audit.py --summary | grep -E "P0|total"
```

Expected: 8 P0 remaining (all from Phase 2 animation cluster). If higher, the burndown missed a file — diff the fresh baseline against the original.

- [ ] **Step 3: Commit baseline regeneration**

```bash
git add docs/design-system/ui-audit-baseline.md
git commit -m "ui-audit: regenerate baseline after Phase 1 color cluster (22 P0 closed)"
```

- [ ] **Step 4: Append case-study Phase 1 section**

Edit `.claude/features/ui-audit-baseline-burndown/case-study.md` — fill "Per-file burndown log" with 8 entries. Commit.

- [ ] **Step 5: HARD STOP — request review before Phase 2**

Surface to the user: "Phase 1 complete. 22 P0 closed across 8 files. Mirror diffs clean in light + dark. Ready for Phase 2 (animation cluster). Approve?"

---

## Phase 2: P0 burndown — animation cluster (4 files, 6 P0)

### Task 2.1: WelcomeView.swift — 3 P0

**File:** `FitTracker/Views/Auth/WelcomeView.swift`

**Mappings (using tokens added in Task 0.1):**

| Line | Before | After |
|---|---|---|
| 137 | `withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.1))` | `withAnimation(AppSpring.hero.delay(0.1))` |
| 140 | `withAnimation(.easeOut(duration: 0.6).delay(0.4))` | `withAnimation(AppEasing.heroEntry.delay(0.4))` |
| 143 | `withAnimation(.easeOut(duration: 0.6).delay(0.7))` | `withAnimation(AppEasing.heroEntry.delay(0.7))` |

Apply procedure P.1 – P.8. Mirror must capture the welcome animation — capture a short video instead of a still if possible (`xcrun simctl io booted recordVideo`); otherwise a still at mid-animation frame is acceptable.

### Task 2.2: OnboardingFirstActionView.swift — 1 P0

**File:** `FitTracker/Views/Onboarding/v2/OnboardingFirstActionView.swift`

**Mappings:**
- Line 103: `.spring(response: 0.5, dampingFraction: 0.7).delay(0.2)` → `AppSpring.stepAdvance.delay(0.2)`

Apply procedure P.1 – P.8.

### Task 2.3: ReadinessCard.swift — 1 P0 (+ easeInOut is P1, check scope)

**File:** `FitTracker/Views/Shared/ReadinessCard.swift`

**Mappings:**
- Line 22: `withAnimation(.easeInOut)` — confirm this is flagged as P0 at P.2. If yes: `withAnimation(AppEasing.standard)`.
- Line 159: `.interpolatingSpring(stiffness: 40, damping: 8)` → `AppSpring.dialPulse`

Apply procedure P.1 – P.8.

### Task 2.4: TrainingPlanView.swift — 1 P0

**File:** `FitTracker/Views/Training/v2/TrainingPlanView.swift`

**Mappings:**
- Line 524: `.linear(duration: 1.2).repeatForever(autoreverses: false)` → `AppLoadingAnimation.fastShimmer`

Apply procedure P.1 – P.8. At P.9, regenerate baseline for Phase 2 cluster.

### Task 2.5: Phase 2 baseline regeneration + hard stop

- [ ] **Step 1: Regenerate baseline**

```bash
python3 scripts/ui-audit.py --baseline --no-fail
```

- [ ] **Step 2: Confirm P0 = 0**

```bash
python3 scripts/ui-audit.py --summary
```

Expected: `0 P0, ~103 P1`. P1 is out of scope for this plan — if the count drifted significantly from 103 (e.g., >115 or <85), investigate.

- [ ] **Step 3: Commit + celebrate + HARD STOP**

```bash
git add docs/design-system/ui-audit-baseline.md
git commit -m "ui-audit: baseline P0 → 0 after Phase 2 animation cluster closed"
```

Surface to user: "Baseline P0 = 0. All 27 original findings closed. Ready to promote `ui-audit` to hard gate in `verify-local`. Approve Phase 3?"

---

## Phase 3: Gate the gate

### Task 3.1: Freeze verification — full-tree scan confirms P0 = 0

**Files:** none modified. Verification only.

- [ ] **Step 1: Full scan from clean checkout**

```bash
git status --short  # should be clean
python3 scripts/ui-audit.py --summary
```

Expected: `0 P0, <count> P1`.

- [ ] **Step 2: Run `make tokens-check`**

```bash
make tokens-check 2>&1 | tail -5
```

Expected: `tokens check passed`.

- [ ] **Step 3: Run `make verify-ios`**

```bash
make verify-ios 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Run full test suite**

```bash
make test 2>&1 | tail -20
```

Expected: all tests pass. If any regression, investigate immediately — could indicate a token migration broke a snapshot or behavioral test.

No commit — this is a checkpoint.

---

### Task 3.2: Promote `ui-audit` to `verify-local`

**File:** `Makefile`

- [ ] **Step 1: Read the verify-local target**

```bash
grep -nA 5 "^verify-local:" Makefile
```

- [ ] **Step 2: Add `ui-audit` as a dependency**

Use `Edit` to change:

```makefile
verify-local: tokens-check build test
```

to:

```makefile
verify-local: tokens-check ui-audit build test
```

(Position `ui-audit` before `build` so it fails fast on source-level issues before incurring the build cost.)

- [ ] **Step 3: Run verify-local end-to-end**

```bash
make verify-local 2>&1 | tail -20
```

Expected: all four stages pass.

- [ ] **Step 4: Commit**

```bash
git add Makefile
git commit -m "ui-audit: promote to hard gate in verify-local

Baseline P0 reached 0 after Phase 1+2 burndown. ui-audit now runs
as part of verify-local alongside tokens-check, build, and test.
Any PR introducing a new P0 (raw Color literal, raw animation, raw
font, missing colorset) now fails the local gate before CI."
```

---

## Phase 4: Scanner hardening + orphan cleanup

### Task 4.1: Close known false-negative gaps

**Rationale:** The scanner uses line-level regex. It misses:
1. Computed color properties: `var tint: Color { .blue }`
2. String-interpolated asset names: `Color("chart-\(metric)")`
3. Color inside ternary: `condition ? .white : .black`

**File:** `scripts/ui-audit.py`

- [ ] **Step 1: Add rule for ternary-embedded raw colors**

Add regex under `# Rule matchers`:

```python
RE_TERNARY_RAW_COLOR = re.compile(r"\?\s*Color\.(white|black|red|blue|green|yellow|orange|purple|pink|gray|clear)\b")
```

Check in `scan_file()` under the color-literal block. Report as `DS-RAW-COLOR-TERNARY`, severity P0.

- [ ] **Step 2: Add rule for interpolated Color("...") lookups**

```python
RE_INTERP_ASSET = re.compile(r'Color\(\s*"[^"]*\\\([^)]+\)[^"]*"\s*\)')
```

Report as `DS-INTERP-ASSET`, severity P1 (warning only — these may be legitimate dynamic lookups but should have a manual comment).

- [ ] **Step 3: Add rule for computed Color properties with raw returns**

Multiline regex:

```python
RE_COMPUTED_RAW_COLOR = re.compile(
    r"var\s+\w+:\s*Color\s*\{[^}]*\.(white|black|red|blue|green|yellow|orange|purple|pink|gray|clear)\b[^}]*\}",
    re.DOTALL,
)
```

Report as `DS-COMPUTED-RAW-COLOR`, severity P0.

- [ ] **Step 4: Re-run full scan**

```bash
python3 scripts/ui-audit.py --summary
```

Expected: P0 count MAY rise from 0 if these rules surface previously-hidden violations. If so:
  a) Fix each new finding file-by-file using the procedure in Phase 1/2.
  b) Regenerate baseline.
  c) Do NOT re-promote verify-local until P0 is back to 0 — but since the gate is already active, the commit that adds the rules must also fix any new findings OR the commit will fail locally.

- [ ] **Step 5: Commit rule additions + any resulting fixes**

```bash
git add scripts/ui-audit.py [any view files touched] docs/design-system/ui-audit-baseline.md
git commit -m "ui-audit: close false-negative gaps (ternary, interpolation, computed properties)"
```

---

### Task 4.2: Baseline drift CI check

**Goal:** PRs that touch view files must regenerate `ui-audit-baseline.md` — or the baseline becomes misleading.

**File:** `Makefile`

- [ ] **Step 1: Add `ui-audit-drift` target**

Append to Makefile:

```makefile
.PHONY: ui-audit-drift
ui-audit-drift:
	@python3 scripts/ui-audit.py --baseline --no-fail
	@git diff --quiet docs/design-system/ui-audit-baseline.md || \
		(echo "ERROR: ui-audit-baseline.md is stale. Run 'make ui-audit-baseline' and commit." && \
		 git diff docs/design-system/ui-audit-baseline.md && exit 1)
```

- [ ] **Step 2: Add to verify-local**

```makefile
verify-local: tokens-check ui-audit ui-audit-drift build test
```

- [ ] **Step 3: Test — clean state**

```bash
make ui-audit-drift
```

Expected: passes silently.

- [ ] **Step 4: Test — dirty state (simulated)**

```bash
# intentionally modify baseline doc
echo "drift" >> docs/design-system/ui-audit-baseline.md
make ui-audit-drift
# Expected: exit 1 with diff output
# Reset:
git checkout -- docs/design-system/ui-audit-baseline.md
```

- [ ] **Step 5: Commit**

```bash
git add Makefile
git commit -m "ui-audit: add ui-audit-drift check to detect stale baseline in PRs"
```

---

### Task 4.3: pbxproj orphan cleanup (separate PR)

**Goal:** Remove dead PBXBuildFile entries for v1 MainScreenView + v1 TrainingPlanView.

**File:** `FitTracker.xcodeproj/project.pbxproj`

**CRITICAL safety rule:** Xcode must not be open on this project during this task. Xcode regenerates project.pbxproj on save.

- [ ] **Step 1: Confirm Xcode is not running**

```bash
pgrep -x Xcode || echo "clear"
```

Expected: `clear`. If pgrep returns a PID, quit Xcode first.

- [ ] **Step 2: Read lines 30-50 of pbxproj**

```bash
sed -n '30,50p' FitTracker.xcodeproj/project.pbxproj
```

Confirm lines 34 and 40 are the orphan entries (`A1000001000000000000000B` and `A1000001000000000000000D`).

- [ ] **Step 3: Remove both lines with Edit tool**

Edit once for each line. Grep after to confirm removal:

```bash
grep -c "A1000001000000000000000B\|A1000001000000000000000D" FitTracker.xcodeproj/project.pbxproj
```

Expected: 0.

- [ ] **Step 4: Run make verify-ios**

```bash
make verify-ios 2>&1 | tail -20
```

Expected: BUILD SUCCEEDED. If fail, restore file from git and escalate — the "orphan" status may have been wrong.

- [ ] **Step 5: Run full test suite**

```bash
make test 2>&1 | tail -10
```

Expected: all pass.

- [ ] **Step 6: Commit in a separate branch**

This is a separate PR because it touches project.pbxproj, which has higher reviewer scrutiny.

```bash
git checkout -b chore/pbxproj-orphan-cleanup
git add FitTracker.xcodeproj/project.pbxproj
git commit -m "chore: remove two orphan PBXBuildFile entries for historical v1 views

Neither A1000001000000000000000B (v1 MainScreenView) nor
A1000001000000000000000D (v1 TrainingPlanView) is referenced from
any Sources phase. Removal is inert — build + tests unchanged.

Verified: Xcode not open during edit; make verify-ios + make test pass."
git push -u origin chore/pbxproj-orphan-cleanup
```

Open PR separately. Do NOT merge into the burndown PR — this is a surgical cleanup that deserves its own history entry.

---

## Phase 5: Close out

### Task 5.1: Case study synthesis

**File:** `.claude/features/ui-audit-baseline-burndown/case-study.md`

- [ ] **Step 1: Fill all sections**

Based on PR + commit history, complete:
- **Context** — what the verification layer was + why the gate couldn't be hard
- **The gap** — 27 P0 at rest; silent failure mode before DS-MISSING-ASSET rule
- **Approach** — three-layer safety (mirror / rollback / tokens-first)
- **Per-file burndown log** — already filled via Phase 1/2 commits
- **Metrics** — final numbers (baseline P0 27 → 0, mirrors captured count, tokens added count, PRs opened, commits, visual regressions reported)
- **Framework lessons** — e.g., "mirror-diff-before-commit caught X ambiguities that scanner would have missed"; "tokens-first migration avoided N approximations"; "separate pbxproj PR avoided conflating cleanup with semantic changes"

- [ ] **Step 2: Promote to docs/case-studies/**

```bash
cp .claude/features/ui-audit-baseline-burndown/case-study.md \
   docs/case-studies/ui-audit-baseline-burndown.md
git add docs/case-studies/ui-audit-baseline-burndown.md
git commit -m "docs: publish UI-audit baseline burndown case study"
```

- [ ] **Step 3: Update memory index**

Write a new memory file (e.g., `project_ui_audit_burndown.md`) and add one line to `MEMORY.md` under Active.

---

### Task 5.2: PR + post-launch metrics review

- [ ] **Step 1: Push branch**

```bash
git push origin claude/review-ui-consistency-zSkvJ
```

- [ ] **Step 2: Open PR to main**

Use the existing branch. Title: `ui-audit: baseline P0 27 → 0 + gate activation`.

PR body should include:
- Commit-by-commit summary
- Mirror diff attachments (upload 2-3 representative before/after PNG pairs to the PR description)
- Risk register (this plan's Risk Mitigation table + outcome for each)
- Metrics snapshot (P0/P1 counts before/after)
- Case study link

- [ ] **Step 3: Set post-launch metric review**

Schedule: 7 days post-merge. Check:
- Any P0 regressions introduced via other PRs?
- Any user-reported visual regressions matching the files touched?
- `ui-audit-drift` check catch rate in CI (expect: non-zero — means it's working)

Update feature `state.json` phase to `closed` after review.

---

## Self-Review

**1. Spec coverage check:**

The user asked for: ✅ comprehensive plan ✅ case study monitor (Tasks 0.3 + 5.1) ✅ full framework (PM workflow integration, state.json, Enhancement type) ✅ mirror tools (Task 0.3 + procedure P.1/P.6) ✅ rollback safety (one commit per file, semantic tag, separate-PR for pbxproj) ✅ plan for approval (no execution).

**2. Risk coverage check:**

All 6 risks from prior assessment mapped to concrete tasks. R1/R2 have the most elaborate mitigation because they're the most load-bearing — visual regression is the failure mode most likely to reach users undetected.

**3. Placeholder scan:**

No "TBD" beyond the case-study skeleton (intentionally empty, fills during execution). No "implement later" phrases. Every step has exact commands, exact files, exact line numbers where known. Token names verified against existing AppMotion.swift + AppTheme.swift.

**4. Type consistency:**

`AppColor.Text.inversePrimary`, `AppColor.Surface.primary`, `AppColor.Surface.elevated`, `AppColor.Brand.primary` used consistently. New motion tokens (`AppSpring.hero`, `AppSpring.stepAdvance`, `AppSpring.dialPulse`, `AppEasing.heroEntry`, `AppLoadingAnimation.fastShimmer`) declared in Task 0.1 and referenced with the same names in Phase 2 mappings.

**5. Rollback paths:**

Every phase is revertible:
- Individual file: `git revert <sha>` — each file is one commit
- Entire phase: revert the phase-boundary baseline-regeneration commit, then the underlying file commits
- Entire burndown: branch can be reset; verification layer stays intact at `573fe8a`
- Gate promotion: revert the Makefile commit, scanner continues to run but is advisory again

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-04-20-ui-audit-baseline-burndown.md`. Awaiting user approval before starting execution. On approval, two execution options:

**1. Subagent-Driven (recommended)** — dispatch a fresh subagent per file-task, review mirror diffs between tasks, fast iteration

**2. Inline Execution** — execute tasks in this session using executing-plans, batch execution with checkpoints at Phase boundaries

Ask on approval which approach to use.
