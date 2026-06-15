# Figma ↔ Code Sync Status

> ⚠️ **RECONCILED 2026-06-15 — read this first.** A full design-system audit found that the
> Figma files referenced below are **empty/partial**, the Code Connect publish bridge is
> **disabled** (requires a Figma Org/Enterprise plan; this account is Pro), and most node IDs
> in the matrix below **do not exist** in the live Figma files. **Code is the source of truth.**
> The matrix rows marked "Synced" / "Synced (auto-built)" reflect what `/design build` *intended*
> to push, **not** verified live Figma frames — treat them as historical intent, not current truth.
> Full decision + rebuild plan: [`figma-source-of-truth-plan-2026-06-15.md`](./figma-source-of-truth-plan-2026-06-15.md).
> Honesty ledger: [FT2-FH-005](../case-studies/framework-honesty-ledger.md).
>
> **Last synced:** 2026-04-29 (matrix below); **last reconciled:** 2026-06-15
> **Figma file:** `0Ai7s3fCFqR5JXDW8JvgmD`
>
> **As of 2026-05-06 (skill-layer v4.X):** rows in this matrix *were* auto-updated by `/design build` during Phase 3.j. **Superseded 2026-06-15:** `/design build`'s Figma-push + Code Connect path is no longer the source of truth — see the banner above. The status label "Synced (auto-built)" only ever meant "`/design build` ran"; it did **not** verify a live Figma frame.

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
| **Import Training Plan — Phase 1 Surfaces** | `919:2` + `920:2` + `921:2` + `922:2` (page `916:2`) | `Views/Settings/v2/Screens/ImportedPlansListScreen.swift` + `Views/Settings/v2/Components/ImportedPlanRow.swift` + `Views/Import/ImportPreviewView.swift` (`.preview` mode) + `Views/Training/v2/TrainingPlanView.swift` (badge insertion + toolbar import button) | **Synced (auto-built)** | Built 2026-05-06 by `/design build` (first v4.X auto-dispatch run after skill upgrade PR #235 landed). Four mobile frames: (01) Imported Plans List populated with one ACTIVE plan + one inactive — shows 26pt source-icon square, ACTIVE pill, green border accent on active row, source/count subtitle, chevron trailing; (02) Imported Plans List empty state — centered 88pt icon + "No imported plans yet" + subtitle + "Import a plan" CTA; (03) Day-Assignment Editor — extension to ImportPreviewView preview mode with Picker-per-imported-day rows (heuristic-suggested defaults flagged "(suggested)") + collision-warning banner when 2+ days share a DayType; (04) Training tab — `square.and.arrow.down` toolbar button on `.topBarLeading` + `📋 Following: {plan name}` active-plan badge above weekStrip. All four use the FitTracker semantic token collections — zero raw colors. Iterations: 2 (first pass clipped Frame 3 Day-Assignment Card via FIXED sizing; fixed in iteration 2). |
| **Push Notifications v2 — Platform-Layer Surfaces** | `937:6` (PrimingView sheet) + `937:46` (Settings → Notifications row 3 states) + `938:2` (SettingsDeepLinkBanner) + `938:50` (readinessAlert high+low banners) on new page **`936:2`** "Push Notifications v2" — section frame `936:3` | `Services/Notifications/{NotificationGateway,DeepLinkRouter,NotificationConsumerRegistry,ReadinessAlertObserver}.swift` (NEW) + `Views/Notifications/{NotificationPermissionPrimingView,SettingsDeepLinkBanner}.swift` (priming view revived from v1; banner NEW) + `Views/Settings/v2/SettingsView.swift` (Notifications row added) | **Synced (auto-built)** | Built 2026-05-07 by `/design build` during Phase 3.j of push-notifications-v2 PM lifecycle. Four 720-wide mobile-preview cards in 2×2 grid matching Smart Reminders (`907:2`) aesthetic: each card = header label + 280×400 iPhone backdrop showing the surface + 6–8 row meta info table (TRIGGER/CAP/ANALYTICS/DEEP LINK/etc). Surface 4 carries 2 stacked notification banners (HIGH 85/100 + LOW · CRITICAL 35/100). Smart Reminders page `907:2` NOT modified — push-notifications owns its own page; smart-reminders is the first consumer. Iterations: 2 (first pass cards rendered as 720×100 due to `resize()` resetting sizing modes to FIXED; fixed by setting `primaryAxisSizingMode = "AUTO"` on cards + `counterAxisSizingMode = "AUTO"` on inner header/meta-row frames; iPhone backdrops kept FIXED 280×400). |

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

---

## Code Connect Verification Contract (added 2026-05-10, v4.X+CC)

The Figma↔code matrix above tracks which Swift View renders which Figma frame. The Code Connect bridge (v4.X+CC) closes the loop in the OTHER direction: which Figma frame, when opened in Dev Mode, surfaces the actual SwiftUI / React snippet for the operator/designer.

### What is automatically verified now

- **Mapping file presence** — every screen-level `figma_node_ids` entry should have a matching `.figma.swift` (FT2) or `.figma.tsx` (fitme-story) mapping file. The `/design pre-merge-review` Step 3.5 (spec ↔ build parity check, v4.X+CC) BLOCKS merge if a spec'd surface has a Figma node ID but no mapping file (`mapping_only` is even worse — mapping authored but no Figma node, indicating `/design build` failed).
- **Mapping file parses** — CI publish workflow (`figma-code-connect-publish.yml`) runs `figma connect publish` on every push to main touching `.figma.{swift,tsx}`. Parse errors fail the workflow visibly. iOS uses `npx figma connect publish` with `figma.config.json::swiftPackagePath` pointing at `.figma-cc-tools/Package.swift` SPM wrapper subdir; the npm CLI subprocesses to `figma-swift` to parse Swift files.
- **Code Connect access** — `/design preflight` Step 3.5 (Code Connect write-access gate, v4.X+CC) verifies BEFORE build effort: `FIGMA_ACCESS_TOKEN` env var locally, repo secret in BOTH repos via `gh api`, plus a publish dry-run probe to catch missing `file_dev_resources:write` scope.
- **Publish success** — CI workflow logs report `Successfully connected component: <name>` for each mapping. Auth failures, scope errors, or 4xx responses surface clearly in the workflow run log.

### What is NOT yet automatically verified

- **Snippet visual fidelity** — once a mapping publishes, Figma Dev Mode shows the snippet, but no automation compares the rendered snippet against the actual rendered SwiftUI/React preview. Operator-side spot-check still required.
- **Mapping deletion sync** — if a `.figma.swift` file is deleted, the corresponding Code Connect record on Figma is NOT auto-removed. Operator runs `figma connect unpublish` manually if cleanup is needed.
- **Cross-feature mapping conflicts** — if two features' mapping files happen to point at the same Figma node ID, the second publish will overwrite the first silently. No conflict detection yet.

### Plan: closing the snippet visual fidelity gap

Future enhancement: extend `/design pre-merge-review` to fetch each mapped Figma frame's screenshot via `mcp__claude_ai_Figma__get_screenshot`, render the same Swift View via Xcode preview/snapshot tests, diff the two. Tracked in the open `code-connect-automation` follow-ups (no concrete PR yet).

### Definition of "Code Connect Synced"

A `.figma.{swift,tsx}` mapping file is **Code Connect Synced** when ALL of:

- [ ] The file parses cleanly (no `ParserError` in `figma connect publish --dry-run`)
- [ ] The Figma node URL resolves (no "node X-Y not found" in publish output)
- [ ] The corresponding component exists at the imported path (no "import for X could not be resolved")
- [ ] The mapping has been published in the last `figma-code-connect-publish` workflow run on main

Verified per-PR by the `/design pre-merge-review` Step 3.5 spec ↔ build parity check; verified per-merge-to-main by the `figma-code-connect-publish` workflow.

### Cross-references

- Skill source: [`.claude/skills/design/SKILL.md`](../../.claude/skills/design/SKILL.md) §`/design build`, §`/design preflight`, §`/design pre-merge-review`
- iOS operator runbook: [`ios-code-connect-workflow.md`](./ios-code-connect-workflow.md)
- Web architecture: [`fitme-story-design-architecture.md`](./fitme-story-design-architecture.md)
- Skill ecosystem evolution: [`docs/skills/evolution.md`](../skills/evolution.md) §27
- Dev guide: [`docs/architecture/dev-guide-v1-to-v7-7.md`](../architecture/dev-guide-v1-to-v7-7.md) §15A

---

## Drift detection — fitme-story (added 2026-05-10 — fitme-story-website-design-system Bucket D)

`figma-drift` cross-checks the fitme-story design-system manifest (`src/lib/design-system.ts`) against the `.figma.tsx` mapping files in `src/components/**`. Catches drift the publish pipeline doesn't see — e.g., manifest entry says `hasFigmaConnect: true` but no mapping file exists, or a `.figma.tsx` file references a Figma node that the manifest no longer declares.

### Run it

| Where | Command |
|---|---|
| Inside fitme-story checkout | `npm run figma-drift` |
| FT2 root (delegates to fitme-story sibling clone) | `make figma-drift` |
| FT2 root (with append) | `make figma-drift FIGMA_DRIFT_FLAGS=--append-report` |
| CI weekly | [`.github/workflows/figma-drift-weekly.yml`](https://github.com/Regevba/fitme-story/blob/main/.github/workflows/figma-drift-weekly.yml) (Mondays 06:00 UTC) |
| CI per-PR | Same workflow, runs on PRs that touch the manifest or any `.figma.tsx` file |

### Findings emitted

| Code | Severity | Triggered by |
|---|---|---|
| `MAPPING_INCONSISTENCY` | fail | Manifest says `hasFigmaConnect: true` but no `.figma.tsx` exists, or vice versa |
| `MANIFEST_ONLY` | fail | Manifest declares Figma node IDs for a component but no `.figma.tsx` mapping exists |
| `CODE_ONLY` | fail | A `.figma.tsx` file maps a component name that's missing from the manifest |
| `MISSING_COMPONENT_SOURCE` | fail | A `.figma.tsx` file imports a component path that doesn't exist on disk |
| `ORPHAN_FIGMA_NODE` | warn | Reserved for future Figma-API check (live nodes not referenced by any `.figma.tsx`) |

### Scope + design choices

- Local-only by default — does not call the Figma API. The orphan-node check (`ORPHAN_FIGMA_NODE`) is reserved for a future iteration that needs `FIGMA_ACCESS_TOKEN`.
- Public-parity is the meaningful metric. Internal-status components (control-room operator surfaces + bespoke illustrations) are excluded from the parity denominator. Rationale codified in `src/lib/design-system.ts` (above the Internal-component block).
- Tests live at fitme-story `src/lib/figma-drift.test.ts` (6 tests, all pass via `npx tsx --test`).

### Latest snapshot — 2026-05-10

```
- Manifest entries: 31 (17 Stable + 14 Internal)
- .figma.tsx files: 17 mapping 22 Figma nodes
- Public parity: 100% (17 / 17)
- Total parity: 55% (17 / 31)

✓ No drift findings.
```

Future runs append here automatically when invoked with `--append-report` (or via the FT2 Makefile target with `FIGMA_DRIFT_FLAGS=--append-report`).
