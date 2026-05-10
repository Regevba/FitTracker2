# iOS Code Connect Workflow

**Created:** 2026-05-09
**Closes:** [ios-code-connect](../../.claude/features/ios-code-connect/state.json) T5
**Source-of-truth Figma file:** [`FitTracker-Design-System-Library`](https://www.figma.com/design/0Ai7s3fCFqR5JXDW8JvgmD/FitTracker-Design-System-Library) (key `0Ai7s3fCFqR5JXDW8JvgmD`)
**Companion doc:** [`fitme-story-design-architecture.md`](./fitme-story-design-architecture.md) (the web-side design system; uses [`@figma/code-connect`](https://github.com/figma/code-connect) JS package against fitme-story file `fsjHfFLAHELACZHku8Rfcl`)
**Config:** [`Figma.toml`](../../Figma.toml) at FT2 repo root

---

## §1 What this doc is

A reference for how the iOS app maps Figma design library frames to SwiftUI Views via Figma Code Connect. Lives alongside [`fitme-story-design-architecture.md`](./fitme-story-design-architecture.md) so both surfaces (web + iOS) document their Code Connect plumbing in one place.

**This doc is NOT a tutorial on SwiftUI or Code Connect.** It documents the contracts, the existing mappings, the publish procedure, and the maintenance rule — assuming readers know SwiftUI + are familiar with Figma Dev Mode.

---

## §2 The big picture

The iOS app uses **screen-level Figma → Swift mapping** instead of component-level. The Figma library `0Ai7s3fCFqR5JXDW8JvgmD` is feature-page-driven (one page per shipped feature, e.g. page `916:2` for import-training-plan, `936:2` for push-notifications). There is no central Components page with reusable atoms like `AppPickerChip` or `AppSegmentedControl`.

```
FitTracker-Design-System-Library  (file 0Ai7s3fCFqR5JXDW8JvgmD)
├── 0:1 Cover
├── 25:6 Onboarding
│   └── 469:2 v1 (preserved unchanged)
│   └── 688:2 v2 (current — built 2026-04-07)
├── 907:2 Smart Reminders
├── 916:2 Import Training Plan
│   ├── 919:2 Imported Plans List · Populated
│   ├── 920:2 Imported Plans List · Empty
│   ├── 921:2 Day Assignment Editor
│   └── 922:2 Training Tab · Active-plan Badge
└── 936:2 Push Notifications
    ├── 937:6 Priming Sheet
    ├── 937:46 Settings Row States
    ├── 938:2 Denial Banner
    └── 938:50 Readiness Alert Banners
```

Each page corresponds to a shipped feature; sub-frames are individual screens within that feature. The `.figma.swift` mapping files in this repo connect those Figma frames to their SwiftUI View counterparts.

---

## §3 Existing mappings (5 files, 6 distinct nodes)

Authored 2026-05-09 via PR #277 as the v7.8.1 chore feature `ios-code-connect`:

| `.figma.swift` file | Figma node | SwiftUI View | Source feature |
|---|---|---|---|
| [`ImportedPlansListScreen.figma.swift`](../../FitTracker/Views/Settings/v2/Screens/ImportedPlansListScreen.figma.swift) | 919:2 (populated) + 920:2 (empty) | `ImportedPlansListScreen` | import-training-plan |
| [`ImportPreviewView.figma.swift`](../../FitTracker/Views/Import/ImportPreviewView.figma.swift) | 921:2 | `ImportPreviewView` | import-training-plan |
| [`TrainingPlanView.figma.swift`](../../FitTracker/Views/Training/v2/TrainingPlanView.figma.swift) | 922:2 | `TrainingPlanView` (v2) | import-training-plan |
| [`NotificationPermissionRow.figma.swift`](../../FitTracker/Views/Notifications/NotificationPermissionRow.figma.swift) | 937:46 | `NotificationPermissionRow` | push-notifications |
| [`OnboardingWelcomeView.figma.swift`](../../FitTracker/Views/Onboarding/v2/OnboardingWelcomeView.figma.swift) | 688:2 | `OnboardingWelcomeView` (v2) | onboarding |

All node IDs are **real** — sourced from the corresponding feature's `state.json::figma_node_ids` block at PR-time.

---

## §4 Build-safety contract

Every `.figma.swift` file in this repo follows the build-safety pattern:

```swift
#if canImport(Figma)
import Figma
import SwiftUI

struct MyView_FrameNameConnect: FigmaConnect {
    let component = MyView.self
    let figmaNodeUrl: String =
        "https://www.figma.com/design/0Ai7s3fCFqR5JXDW8JvgmD/FitTracker-Design-System-Library?node-id=N-N"

    var body: some View {
        MyView()
    }
}
#endif
```

The `#if canImport(Figma)` wrapper means:

- When the `@figma/code-connect` Swift package **is** installed via SPM, Xcode compiles the FigmaConnect struct
- When the package is **not** installed, the entire body becomes inert — Xcode compiles the file to a no-op

**Implication:** `.figma.swift` files do NOT need to be excluded from the Xcode build target. They live alongside their View counterparts and travel with regular code reviews. The figma CLI parses them separately at publish time.

---

## ⚠️ Known external blocker — Code Connect Write scope (added 2026-05-10)

**Status:** parser + auth pipeline works end-to-end, but the actual `POST /v1/code_connect` API call returns **HTTP 403 "Invalid scope(s)"** on this Figma account.

**Root cause:** the `code_connect:write` scope (per [Figma's quickstart docs](https://developers.figma.com/docs/code-connect/quickstart-guide/)) is required to publish mappings. We confirmed this scope is **not available** on the operator's account:

- **PAT scope UI** (figma.com/settings → Security → Personal access tokens → Generate new token): scrolling the entire scope list (Users / Files / Design systems / Development / Projects / Webhooks) shows no `code_connect:*` checkbox
- **OAuth flow:** requesting `code_connect:write` in the authorization URL returns `{"error":true,"status":400,"message":"Invalid scopes for app"}`

**Operator account context (per `mcp__claude_ai_Figma__whoami`, 2026-05-09):**
- Tier: `pro` (Professional plan)
- Seat: `Full`, seatType: `expert`
- Team: "Regev - My apps"

**Why it matters:** Figma's pricing page lists Code Connect under Professional plan and above, but empirically the scope is gated behind something more specific (likely Dev seat or an Org/Enterprise add-on). Figma's docs don't clarify the exact entitlement matrix.

**What works without the scope:**

- `npx figma connect publish` parses all 6 `.figma.swift` mappings cleanly ("Successfully connected component × 6")
- Validation step PASSES (after the 2026-05-10 frame→component conversion fix)
- Only the final upload to `https://api.figma.com/v1/code_connect` returns 403
- The `.figma.swift` files remain valuable as: design intent documentation, future-publish ready, auto-scaffold target for new features

**What's needed to unblock:**

1. Operator obtains a Figma seat/plan that includes the `code_connect:write` scope:
   - **Option A:** swap a Full seat for a Dev seat on the same Pro plan (free swap if available)
   - **Option B:** upgrade Pro → Organization plan (~$15-25/seat/mo)
   - **Option C:** contact Figma support to clarify which exact entitlement unlocks the scope
2. Generate a new PAT (or OAuth token) with `code_connect:write` checked
3. Update `FIGMA_ACCESS_TOKEN` repo secret in BOTH `Regevba/FitTracker2` and `Regevba/fitme-story`
4. Trigger either repo's `figma-code-connect-publish` workflow manually (`gh workflow run`)

**No code changes needed** to re-activate. The existing infrastructure (Figma.toml + `figma.config.json` + `.figma.swift` files + scaffold scripts + skill extension + CI workflows) all remain in place and will fire automatically once the scope is granted.

**Tracking:** [`code-connect-automation`](../../.claude/features/code-connect-automation/state.json) — feature closed `current_phase: complete` with T5 (end-to-end test) marked `deferred` for this blocker. Re-open + re-run T5 when the scope unblocks.

---

## §5 Publish procedure (operator playbook)

These steps require operator action — they are NOT automated:

### One-time setup (per machine)

1. **Add the Figma Code Connect Swift package** to FitTracker.xcodeproj:
   - Open `FitTracker.xcodeproj` in Xcode
   - File → Add Package Dependencies…
   - Enter URL: `https://github.com/figma/code-connect`
   - Pin to latest release (per the [Figma docs](https://github.com/figma/code-connect))
   - Verify the package adds the `Figma` module to the build

2. **Capture a Figma access token** at <https://www.figma.com/developers/api#access-tokens>:
   - Required scopes: **File Content** + **Code Connect Write**
   - Save to a local `~/.zshrc` (or equivalent) export: `export FIGMA_ACCESS_TOKEN="figd_..."`
   - Do NOT commit the token to the repo

### Per-publish cycle

3. **Publish**:
   ```bash
   cd /Volumes/DevSSD/FitTracker2
   figma-swift connect publish --token "$FIGMA_ACCESS_TOKEN"
   ```
   The CLI parses every `.figma.swift` file under `FitTracker/**` (per [`Figma.toml`](../../Figma.toml)) and pushes the mappings to the Figma library.

4. **Verify**:
   - Open the Figma file in Dev Mode
   - Click any of the 6 mapped frames (919:2, 920:2, 921:2, 922:2, 937:46, 688:2)
   - Confirm the right-pane code snippet shows the SwiftUI body example from the corresponding `.figma.swift` file

### Unpublish (if needed)

5. **Remove a mapping**:
   - Delete the `.figma.swift` file (or its FigmaConnect struct)
   - Run `figma-swift connect unpublish --node <node-url> --token "$FIGMA_ACCESS_TOKEN"`
   - Verify the snippet no longer appears in Dev Mode

---

## §6 Maintenance rule

When adding a new SwiftUI View that has a counterpart in the Figma library:

1. **Capture the Figma node ID** when building the screen (the `/design build` skill auto-populates `state.json::figma_node_ids` for new features)
2. **Author a `.figma.swift` mapping file** alongside the View (e.g. `MyNewView.swift` → `MyNewView.figma.swift` in the same directory)
3. **Use the build-safety wrapper** (`#if canImport(Figma)`) so the file compiles regardless of whether the Swift package is installed
4. **Run `figma-swift connect publish`** after merging to push the new mapping (operator step; not automated in CI today)

The `Figma.toml` `include` glob (`FitTracker/**/*.figma.swift`) means new files are auto-discovered; no config change needed.

---

## §7 What this workflow does NOT cover

- **Component-level mapping** for atomic Swift components like `AppPickerChip`, `AppSegmentedControl`, `AppProgressRing` — the Figma library currently has no central Components page with these atoms. If/when a Components page is built, this doc gets updated and component-level `.figma.swift` files get added under `FitTracker/DesignSystem/`.
- **CI-side automated publish** — `figma-swift connect publish` is operator-driven today. A future GitHub Actions workflow could automate publishing on merge to main, gated on a `FIGMA_ACCESS_TOKEN` repo secret. Not yet built.
- **Unmapped surfaces** — many shipped iOS Views do not yet have `.figma.swift` mappings. The 5 files in §3 are the seed batch; coverage expands as features ship `.figma.swift` mappings via the `/design build` integration.
- **Web-side Code Connect** — that's documented in [`fitme-story-design-architecture.md`](./fitme-story-design-architecture.md) and uses the JS [`@figma/code-connect`](https://github.com/figma/code-connect) package against Figma file `fsjHfFLAHELACZHku8Rfcl`.

---

## §8 Cross-references

- **Companion web doc:** [`fitme-story-design-architecture.md`](./fitme-story-design-architecture.md) (parallel deliverable; uses JS Code Connect)
- **Backlog item:** [`docs/product/backlog.md`](../product/backlog.md) → "fitme-story website design system — ongoing build-out" (the web-side ongoing evolution; iOS-side parallel evolution lives implicitly in this doc + the rolling `.figma.swift` mappings)
- **Feature state:** [`.claude/features/ios-code-connect/state.json`](../../.claude/features/ios-code-connect/state.json) (5 tasks T1–T5; T1+T2+T3 shipped via PR #277, T5 shipped via this doc, T4 publish-step deferred to operator)
- **Source figma file:** [FitTracker-Design-System-Library](https://www.figma.com/design/0Ai7s3fCFqR5JXDW8JvgmD/FitTracker-Design-System-Library)
- **Figma Code Connect repo:** <https://github.com/figma/code-connect>
