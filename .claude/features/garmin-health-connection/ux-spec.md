# UX Spec — Data Sources Screen (Garmin + Fitbit, Tier 1)

> Feature: `garmin-health-connection` (lead; shared with `fitbit-health-connection`)
> Phase 3 (UX/Integration) · 2026-06-10 · scope = Tier 1 (HealthKit relay).
> **All cited symbols verified to exist** (per `/ux preflight` grounding scan 2026-06-10).
> This spec covers the SHARED multi-source surface both features ship against.

---

## 0. Placement decision (resolved)

FitMe Settings v2 already has a **Health & Devices** category
(`SettingsCategory.healthDevices` → `HealthDevicesSettingsScreen`). Rather than add a
new top-level Settings category (navigation bloat), **Data Sources is a row inside
`HealthDevicesSettingsScreen`** that pushes a dedicated `DataSourcesScreen`. The
dedicated screen (per PRD T1) keeps the multi-source design room for Whoop/Oura/Samsung
later, while living in the logical place. **Alternative considered + rejected:** a new
top-level `SettingsCategory.dataSources` — rejected because wearables *are* health
devices and the existing category already frames this.

- **Entry point:** a `SettingsActionLabel` row ("Data Sources", icon
  `"dot.radiowaves.left.and.right"`, subtitle "Garmin, Fitbit & Apple Health") inside
  `HealthDevicesSettingsScreen`, wrapped in a `NavigationLink(value:)`.
- **Destination:** `DataSourcesScreen` at
  `FitTracker/Views/Settings/v2/Screens/DataSourcesScreen.swift` (new file, canonical
  path — net-new UI, no `v2/` sub-dir needed since there's no v1 to refactor).

## 1. Screen anatomy

`DataSourcesScreen` wraps content in **`SettingsDetailScaffold`** (gradient background +
`SettingsHomeHeader` + scroll). Header: title "Data Sources", subtitle "Bring your
wearable's recovery data into FitMe through Apple Health." Body is two
`SettingsSectionCard`s:

### Card A — "Connected sources" (eyebrow: "SOURCES")
One row per source (Garmin, Fitbit). Each row is a custom `DataSourceRow` built from
existing primitives:
- **Leading:** SF Symbol in a 26pt tinted container (`AppSize.iconBadge`), color
  `AppColor.Accent.recovery` for an active source / `AppColor.Text.tertiary` for an
  inactive one.
- **Title:** source name in `AppText.button`.
- **Status line:** `AppText.subheading`, `AppColor.Text.secondary` — e.g. "Syncing HRV,
  resting HR, sleep" (connected) / "Connected — waiting for first sync" / "Not detected
  in Apple Health".
- **Trailing:** a `SettingsBadgeView` status pill — green dot + "Active"
  (`AppColor.Status.success`), amber dot + "Pending" (`AppColor.Status.warning`), or grey
  dot + "Set up" (`AppColor.Text.tertiary`). Tapping a non-active row opens the guided
  flow (§3).
- **Signal chips (when active):** a `FlexibleBadgeRow` of the detected signals
  (HRV / RHR / Sleep) so the user sees exactly what's flowing.

### Card B — "How this works" (eyebrow: "ABOUT")
`SettingsSupportingText`: "FitMe reads recovery data your Garmin or Fitbit already shares
with Apple Health — no separate login. Turn on Apple Health sync in the Garmin Connect or
Fitbit app and your readiness score updates automatically." A `SettingsValueRow` shows
"Apple Health" → an `isAuthorized`-driven value ("Connected" / "Not granted") sourced from
`HealthKitService.isAuthorized`. If not granted, a CTA routes to
`HealthKitService.requestAuthorization()`.

## 2. States (per source)

| State | Trigger (Tier-1 detection) | Row presentation |
|---|---|---|
| **Active** | Source-origin samples present for ≥1 readiness type (via `HealthKitSourceProbe`) | recovery-tinted icon, "Active" pill, signal chips |
| **Pending** | Source detected in Apple Health but no readiness sample yet | warning-tinted, "Pending" pill, "waiting for first sync" |
| **Not detected** | No source-origin samples found | tertiary icon, "Set up" pill, taps → guided flow |
| **HK not granted** | `HealthKitService.isAuthorized == false` | whole screen shows an `EmptyStateView` (icon `"heart.text.square"`, title "Connect Apple Health", subtitle, CTA "Allow Access" → `requestAuthorization()`) |

**Fitbit-specific (from the sibling feature):** an additional sub-state — "Connected, but
your Fitbit model doesn't export HRV/RHR" — uses the same row with a distinct status line
and emits `settings_data_source_empty_state_shown{source:fitbit, reason:device_or_setting}`.
Spec'd here for surface consistency; built in the Fitbit feature's T2.

## 3. Guided connection flow

Tapping a non-active source row presents a sheet (`ConnectGuidanceView`, new, reuses
`SettingsDetailScaffold` styling within a sheet, `AppRadius.sheet` corners):
- Icon `AppText.iconHero`, title "Connect {Garmin|Fitbit}".
- Numbered steps (3): open the vendor app → enable Apple Health permissions → return to
  FitMe. Each step is a row with a number chip (`AppText.chip` in an
  `AppSize.controlSmall` circle) + `AppText.body` instruction.
- Primary CTA "Open Health App" (`AppSize.ctaHeight`, `AppRadius.button`,
  `AppColor.Accent.primary`) deep-links to the Health app where the OS allows; secondary
  "Done" dismisses.
- On dismiss, the screen re-probes; if data now present, the row animates to Active with
  `AppMotion.selectionChange`.

## 4. Motion

- Row status transitions: `AppMotion.selectionChange` (0.18s easeOut).
- Sheet present/dismiss: system default; content fades with `AppMotion.pageTransition`.
- No gratuitous animation — the screen is informational.

## 5. Accessibility

- Every source row is one accessibility element: label "{Source}, {status}, signals:
  {list}"; the status pill is **not** a separate focus stop (combined).
- Status is **never color-only** — the pill always pairs a dot color with a text label
  ("Active"/"Pending"/"Set up"), satisfying the non-color-dependent principle.
- Dynamic Type: all text uses `AppText.*` tokens (auto-scaling); the 26pt icon container
  uses `AppSize.iconBadge` (fixed — icon containers are not text, per the L353 audit).
- Tap targets ≥ `AppSize.tapTarget` (44pt); rows meet `AppSize.rowHeightCompact` (76pt).
- VoiceOver order: header → Card A rows top-to-bottom → Card B.

## 6. Analytics hooks (wired in T7; events from PRD §5)

| Event | UI trigger |
|---|---|
| `settings_data_sources_viewed` | `DataSourcesScreen.onAppear` |
| `settings_data_source_detected` | a row resolves to Active (per source) |
| `settings_data_source_connect_started` | guided sheet opened |
| `settings_data_source_connect_completed` | row transitions to Active after a connect sheet |
| `settings_data_source_empty_state_shown` | a row resolves to Not-detected / Fitbit no-signal |

All `settings_`-prefixed; `source` dimension distinguishes Garmin/Fitbit.

## 7. 13 UX Principles check (8 core + 5 FitMe)

| Principle | How this spec satisfies it |
|---|---|
| **Clarity** | Each source's state + flowing signals are explicit; no hidden status |
| **Feedback** | Live status pills + animated Active transition on successful connect |
| **Consistency** | Reuses `SettingsDetailScaffold`/`SettingsSectionCard`/`SettingsActionLabel`/`SettingsBadgeView` — identical to every other Settings v2 screen |
| **Forgiveness** | Non-destructive; guided flow is dismissible; no data is changed |
| **Hierarchy** | Connected sources (Card A) above explanatory copy (Card B); active sources visually lead |
| **Accessibility** | §5 — non-color status, Dynamic Type, 44pt targets, combined VO elements |
| **Efficiency** | One screen for all sources; one tap to the guided flow |
| **Aesthetic integrity** | Token-only styling; matches Settings v2 visual language |
| **FitMe: recovery-first** | Frames sources by the *readiness signals* they provide (HRV/RHR/Sleep), not generic "steps" |
| **FitMe: zero-knowledge honesty** | Card B states plainly that data comes via Apple Health on-device; nothing leaves the device |
| **FitMe: calm, not gamified** | Informational, no streaks/badges; respects the recovery-first identity |
| **FitMe: progressive disclosure** | Detail (signal chips, guided steps) revealed on demand, not upfront |
| **FitMe: trust through transparency** | Shows exactly which signals are detected + their source |

## 8. Symbols this spec depends on (all verified to exist)

- **Scaffolds/components:** `SettingsDetailScaffold`, `SettingsSectionCard`,
  `SettingsActionLabel`, `SettingsValueRow`, `SettingsSupportingText`,
  `SettingsBadgeView`, `FlexibleBadgeRow`, `SettingsHomeHeader`, `EmptyStateView`.
- **Navigation:** `SettingsCategory.healthDevices`, `HealthDevicesSettingsScreen`,
  `NavigationLink(value:)`, `navigationDestination`.
- **Services/contracts:** `HealthKitService` (`isAuthorized`,
  `requestAuthorization()`), `AIInputAdapter`, `HealthKitAdapter`.
- **Tokens:** `AppColor.Accent.recovery/.primary`, `AppColor.Status.success/.warning`,
  `AppColor.Text.secondary/.tertiary`, `AppText.button/.subheading/.body/.chip/.iconHero`,
  `AppSpacing.*`, `AppRadius.sheet/.button`, `AppSize.iconBadge/.controlSmall/.tapTarget/
  .rowHeightCompact/.ctaHeight`, `AppMotion.selectionChange/.pageTransition`.

## 9. New symbols this feature introduces (built in Phase 4)

- `DataSourcesScreen` (T1), `DataSourceRow` (T1), `ConnectGuidanceView` (T5),
  `HealthKitSourceProbe` (T3), `GarminAdapter` (T4). `SettingsCategory` gains no new case
  (Data Sources is a row under healthDevices, not a category).

## 10. Out of scope (Tier 2)

OAuth screens, a vendor-login web sheet, backend-sync status, proprietary-metric tiles.
The screen is designed so a future Tier-2 "Connect directly" affordance could be added to
a source row without restructuring.
