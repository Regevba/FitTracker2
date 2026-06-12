# UX Pre-Merge Review — garmin-health-connection (Data Sources screen)

> Phase 6 gate · 2026-06-12 · reviewer: pm-workflow `/ux pre-merge-review`
> Surface: PR #705 (`feature/garmin-health-connection` → `main`)
> Spec: [`ux-spec.md`](ux-spec.md) · Code: `FitTracker/Views/Settings/v2/Screens/DataSourcesScreen.swift`

## Verdict: **PASS_WITH_NOTES**

The shipped implementation faithfully realizes the approved UX spec. One deliberate
Tier-1 simplification (state collapse) is documented below and accepted.

## Spec ↔ code parity

| Spec element | Shipped | Status |
|---|---|---|
| Entry: row in `HealthDevicesSettingsScreen` → `DataSourcesScreen` | `HealthDevicesSettingsScreen.swift` push | ✅ |
| `SettingsDetailScaffold` + two `SettingsSectionCard`s (Sources / About) | `connectedContent` | ✅ |
| Per-source row: icon badge, title, status line, status pill, signal chips | `DataSourceRow` | ✅ |
| HK-not-granted whole-screen `EmptyStateView` + CTA → `requestAuthorization()` | `healthNotGrantedContent` | ✅ |
| Guided connect sheet (3 numbered steps + "Open Health App" CTA + Done) | `ConnectGuidanceView` | ✅ |
| Re-probe on sheet dismiss; row animates to Active | `handleConnectDismiss` | ✅ |
| Analytics: viewed / detected / connect_started / connect_completed / empty_state_shown | all 5 wired | ✅ |
| A11y: combined element, non-color status (dot + text label), Dynamic Type tokens, ≥44pt | `.accessibilityElement(.combine)` + `AppSize.tapTarget` | ✅ |
| Token-only styling (no raw literals) | `make ui-audit` → P0=0 on this file | ✅ |

## Notes (non-blocking)

1. **State model collapsed 3 → 2.** Spec §2 defined Active / **Pending** ("detected but no
   readiness sample yet", amber) / Not-detected. The shipped `DataSourceRow` renders binary
   Active / "Set up". The amber **Pending** state is not surfaced — a source either has an
   active readiness sample or reads as "Not detected in Apple Health". This is an acceptable
   Tier-1 simplification (the Tier-1 `HealthKitSourceProbe` resolves presence as a boolean on
   readiness-sample existence; "detected-but-empty" requires source-origin enumeration that is
   Tier-2 scope). **Follow-up:** reinstate the amber Pending state when first-sync detection
   lands (tracked against the Fitbit sibling's richer probe). Logged as a spec-drift note, not
   a regression.
2. **`kill_criteria_resolution`** is forward-looking (60-day connect-rate checkpoint) — set to
   `not_yet_evaluated` at ship with the pre-registered threshold; see state.json.

## Gate

`state.json.pre_merge_review.ux = "passed_with_notes"`. Does not block Phase 7.
