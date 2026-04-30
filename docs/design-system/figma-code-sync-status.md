# Figma ↔ Code Sync Status

> **Last synced:** 2026-04-29
> **Figma file:** `0Ai7s3fCFqR5JXDW8JvgmD`

## Screen Sync Matrix

| Screen | Figma Node | Code File | Status | Notes |
|---|---|---|---|---|
| **Home v3** | `859:27` (Code Truth) | `MainScreenView.swift` (v2/) | **Synced** | Built 2026-04-15. Frosted glass removed, dividers, sample data. |
| **Training v2** | `761:2` (in section `438:2135`) | `TrainingPlanView.swift` (v2/) | **Minor drift** | Figma shows hamburger icon — code uses profile icon. Figma has eye icon top-right — code has none. |
| **Nutrition v2** | `768:2` | `NutritionView.swift` (v2/) | **Minor drift** | Same toolbar icon difference. Content matches. |
| **Stats v2** | `771:2` | `StatsView.swift` (v2/) | **Minor drift** | Same toolbar icon difference. Content matches. |
| **Settings v2** | `772:2` | `SettingsView.swift` (v2/) | **Synced** | Accessed from Profile → Account & Data card. Nutrition Strategy section removed, renamed to "HR & Intervals". |
| **Profile v3 | `865:3` (page `865:2`) | `ProfileView.swift` | **Synced** | New Figma page "Profile & Settings" built 2026-04-15. Old pages archived. |
| **Onboarding v2** | `688:2` | `OnboardingView.swift` (v2/) | **Synced** | 6 screens + 3 HealthKit variants. No changes since PR #59. |
| **Login** | `25:7` | `SignInView.swift` | **Synced** | Auth screens match. |
| **Smart Reminders — Notification States** | `907:3` (page `907:2`) | `Services/Reminders/{ReminderType,ReminderScheduler,ReminderTriggers}.swift` + `Views/Shared/LockedFeatureOverlay.swift` | **Synced** | Built 2026-04-29 from PRD `docs/product/prd/smart-reminders.md`. Three sections: 6 iOS notification banners (one per reminder type with PRD-verbatim title + body + trigger / cap / suppress / deep link), 3 locked-feature overlays (AI coaching / sync / export per SR-13), 4 scheduler-guard callouts (global cap 3/day, quiet hours 22:00–07:00, min interval ≥ 4 h, permanent stop). Matches `ReminderType.swift` titles (6 cases). |

## Global Differences (apply to all screens)

These are systematic differences between Figma and code that apply across all screens:

| Element | Figma (old) | Code (current) | Priority |
|---|---|---|---|
| Toolbar left icon | Hamburger (`≡`) or missing | Profile icon (`person.circle.fill`) | Low — cosmetic |
| Toolbar right icon | Eye icon or sync indicator | None (removed) | Low — cosmetic |
| Tab bar | Some show 5 tabs (with Profile) | 4 tabs (Home, Training, Nutrition, Stats) | Low — structural |
| Card backgrounds | White opaque (`Surface.elevated`) | No containers (floating on gradient) for Home | Home only |

## What's Locked

All screens are locked as of 2026-04-15. The code is the source of truth. Figma updates for the global toolbar/tab differences are deferred — they're cosmetic and don't affect implementation.

## Next Figma Update Triggers

- When a screen gets a redesign or polish pass
- When the Profile v3 simplified design is finalized for Figma
- ~~When push notifications or smart reminders UI ships (new screens)~~ → **Smart Reminders shipped 2026-04-29 (page `907:2`)**; Push Notifications still pending

---

## Verification Contract (added 2026-04-20)

The Figma↔code matrix above is a manual snapshot. It tells you which screen
matches and which has drift, but it does not catch new drift automatically.
The verification layer below closes that loop.

### What is automatically verified (every CI run)

| Layer | Check | Tool | Failure mode |
|---|---|---|---|
| `tokens.json` ↔ `DesignTokens.swift` | Generated Swift matches the JSON source | `make tokens-check` | CI fails if codegen output differs from committed file |
| `AppColor.*` references ↔ `Assets.xcassets` colorsets | Every `Color("name")` resolves to a real asset | (planned — see "Gap A" below) | Today: silent fallback to clear at runtime |
| Every view ↔ design-system tokens | No raw colors / animations / fonts / magic spacing in any view file | `make ui-audit` (P0 = blocking) | CI fails on any P0 finding; current baseline 27 P0 + 103 P1 (see `ui-audit-baseline.md`) |
| Token-definition file integrity | `AppTheme.swift` enums mirror tokens.json categories | `make tokens-check` (color/spacing/radius/typography only) | CI fails on category drift |

### What is NOT yet automatically verified

| Layer | Why it's hard | Workaround | Owner |
|---|---|---|---|
| **Asset name ↔ AppTheme reference** | SwiftUI `Color("name")` returns transparent on miss; no compile error | Manual: `grep 'Color("' AppTheme.swift` and verify each name has a `.colorset` directory. Closed once for chart-* tokens on 2026-04-20. **Gap A** below | Design-system maintainer |
| **Figma node values ↔ tokens.json** | Requires Figma API access + Tokens Studio export with consistent token names | Manual: when designer updates Figma, they re-export Tokens Studio → tokens.json → `make tokens` → commit | Designer + maintainer pair |
| **Figma frame layout ↔ rendered SwiftUI** | Requires snapshot tests against Figma exports (no MCP/API today) | Manual: per-screen audit on a real device (the matrix above) | Per-feature owner during PM workflow Phase 3 (UX) |
| **Component prop API ↔ Figma component variants** | Requires reading Figma component definitions programmatically | Manual: when adding a new variant to a component, update Figma in same PR | Designer |

### Plan: closing Gap A (asset-name verification)

Goal: when someone writes `Color("foo-bar")` in `AppTheme.swift` and forgets
to add `Assets.xcassets/Colors/.../foo-bar.colorset`, CI fails.

Implementation sketch (~30-line addition to `scripts/ui-audit.py`):

1. Parse every `Color("…")` literal out of `AppTheme.swift`.
2. Walk `FitTracker/Assets.xcassets` for every `*.colorset` directory.
3. Diff: any name in the Swift side without a colorset → P0 finding.
4. Wire into `make ui-audit` so the existing CI gate covers it.

Tracked as a follow-up to the M-3b chart-color closure (2026-04-20).

### Plan: closing the Figma-snapshot gap

Two paths, in order of pragmatism:

1. **Per-screen UX checklist signed-off in PRD Phase 3.** Already exists in
   `docs/design-system/v2-refactor-checklist.md`. Make signature mandatory
   before Phase 4 (Implement) starts.
2. **Snapshot tests against Figma frame exports.** Designer exports a PNG
   per locked screen, committed under `docs/design-system/figma-snapshots/`.
   A Swift Snapshot Testing target diffs against rendered SwiftUI views.
   Deferred — adds CI cost and a maintenance burden (snapshots break on
   every Dynamic Type or color tweak). Only pursue if Gap-A class bugs
   keep landing despite the manual checklist.

### Definition of "synced"

A screen is **Synced** in the matrix above when ALL of:

- [ ] No P0 findings in `make ui-audit` for that screen's view files
- [ ] All `AppColor.*` tokens used by the screen exist in `Assets.xcassets`
- [ ] The screen's row in this matrix has a recent `Last verified` date
      (within 90 days, refreshed on any merged PR touching the file)
- [ ] The PR that last touched the screen referenced the matching Figma
      node ID in the description (so future readers can re-open the spec)

Anything less is **Minor drift** or **Major drift**, with the gap noted
in the Notes column.
