# FitMe UI/UX Master Plan — 2026-05-24

> **Status:** CURRENT · Opened 2026-05-24 as the 5th sub-doc of [`infra-master-plan-2026-05-12.md`](infra-master-plan-2026-05-12.md). Platform-comprehensive revision 2026-05-24 expanded scope from "iOS + website" to "iOS + website + Android" (token + adaptation layer; Android app code not yet implemented) and reconciled 3 drift items + added missing `user-profile-settings` row.
> **Scope:** All UI/UX work across all platforms — iOS (FitTracker2), website (fitme-story), and Android (tokens + adaptation docs, no native app surface yet). Features, enhancements, and chores. Includes both shipped state and in-flight queue. Cross-references parent features (e.g., v2 alignment series under `design-system-v2`; UCC sub-features under `unified-control-center`; Android token pipeline under `android-design-system`).
> **Purpose:** Codify the surface-level UI/UX work that was previously distributed across `.claude/features/*/state.json`, `docs/product/backlog.md` rows, and memory entries. Single source of truth for "what UI/UX is shipped, in-flight, queued, or implicit." Mirrors backlog rows; lets operators answer "what should I work on next on the UI surface" without reading 60+ state.json files.
> **Why a sub-plan, not a section in the infra plan:** Same pattern as [`test-coverage-master-plan-2026-05-13.md`](test-coverage-master-plan-2026-05-13.md), [`analytics-master-plan-2026-05-13.md`](analytics-master-plan-2026-05-13.md), [`data-integrity-and-rollback-2026-05-14.md`](data-integrity-and-rollback-2026-05-14.md), and [`dev-env-master-plan-2026-05-24.md`](dev-env-master-plan-2026-05-24.md) — UI/UX has its own cadence (per-screen v2 alignment + ongoing polish + per-launch design-system evolution) that doesn't map onto the v7.x framework-version axis.
> **Authority:** Items here are work-type Feature / Enhancement / Chore. They do NOT promote into v7.9.1 / v8.x F-series. They ship in their own cadence using the standard PM workflow per work-type. Sub-features (e.g., `home-today-screen`) sit under parent features (e.g., `design-system-v2` / `ux-foundations.md`) and inherit gates from the parent's lineage.

---

## 0. TL;DR

**26 shipped, 8 in-flight, ~26 open backlog items across all three platforms (iOS + website + Android).**

### Headline counts (2026-05-24 fs + memory cross-reference; platform-comprehensive revision)

| Category | iOS | Website | Android | Cross-cutting | Total |
|---|---|---|---|---|---|
| **Shipped features** | 16 | 6 | 1 | 2 | 25 |
| **Shipped enhancements** | 5 | 3 | — | — | 8 |
| **Shipped chores** | 3 | — | — | 2 | 5 |
| **In-flight (need attention)** | 2 | 6 | — | — | 8 |
| **Open backlog items** | ~17 | ~6 | ~3 | 1 | ~27 |

### Top 5 next actions

1. **Verify + backfill `ai-recommendation-ui` case_study link** — state.json has `case_study: null`; next mutation will trip `STATE_NO_CASE_STUDY_LINK`. ~10 min fix; today-advanceable
2. **C9 + C10 fitme-story-only polish bundle** (~3h) — UCC coral-pulse animation + 4 control-room dark-mode contrast verifications; no Phase E conflict, no infra-glob
3. **Resume app-store-assets** (5/10 done per `paused_app_store_assets.md`) — needed for App Store launch surface; operator-paced
4. **Open the 3 memory-only design rules as backlog rows** — AI avatar / orbital pm-flow rollback / failure-recognition-layer currently invisible outside memory
5. **Apply fitme-story web design system to `/control-room/*`** — 14 internal components deferred per Internal-deferral policy; estimated 1-week if drift-only

> **Reconciled drift items (closed during 2026-05-24 platform-comprehensive revision):** (a) `fitme-story-public-enhancements` confirmed `phase=complete` + 24/24 tasks done in state.json (UX-R1 already satisfied — no work needed); (b) `user-profile-settings` added as missing iOS shipped feature (was absent from §2.1); (c) `android-design-system` added as new §4 Android section (was excluded from prior scope).

---

## 1. Scope + Relationship to Infra Master Plan

### 1.1 What this plan covers

| Surface | Tracking mechanism owned by this plan |
|---|---|
| **iOS app UI screens** (Views, Components, ViewModels) | Yes — feature + enhancement entries §2 |
| **iOS design system** (tokens, components, ux-foundations.md adherence) | Yes — shipped tracking + open Residual list §2 |
| **iOS UI polish chores** (ui-audit P1 drift, VoiceOver, Dynamic Type, dark-mode E2E) | Yes — backlog rows §2.5 |
| **Website public pages** (case-studies, glossary, framework, marketing) | Yes — fitme-story-public-enhancements + sub-features §3 |
| **Website operator dashboard** (`/control-room/*`) | Yes — UCC + UU items §3 |
| **Android design system** (tokens → MD3 mapping, Style Dictionary `config-android.json`, `android-adaptation.md`, `android-token-mapping.md`) | Yes — §4 (cross-platform token authoring + adaptation docs) |
| **Android app code** (Jetpack Compose views, Compose theming, Android-specific UX patterns) | **No** — Android app not yet implemented; tracked here as "intentionally deferred, token pipeline ready" |
| **Cross-repo Figma ↔ code (Code Connect)** | Yes — code-connect-automation + ios-code-connect + ucc-sign-in-figma-mapping §5 |
| **Marketing assets** (App Store screenshots, ASO copy, marketing graphics) | Yes — app-store-assets feature §2.4 |

### 1.2 What this plan does NOT cover

| Concern | Owned by |
|---|---|
| Analytics events firing in UI flows | [`analytics-master-plan-2026-05-13.md`](analytics-master-plan-2026-05-13.md) |
| Per-screen test coverage | [`test-coverage-master-plan-2026-05-13.md`](test-coverage-master-plan-2026-05-13.md) §2.2 (iOS) + §2.3 (web) |
| Pre-commit / CI gate definitions | [`infra-master-plan-2026-05-12.md`](infra-master-plan-2026-05-12.md) §2.2 + this doc references the per-PR `ui-audit` gate |
| Dev-env lint/format tooling for UI code | [`dev-env-master-plan-2026-05-24.md`](dev-env-master-plan-2026-05-24.md) R7 (SwiftLint) + R12 (markdownlint for prose) |
| Backend / API / sync logic | Out of scope — separate concerns |
| Performance / Core Web Vitals tracking | [`fitme-story-discoverability-plan-2026-05-20.md`](fitme-story-discoverability-plan-2026-05-20.md) + future R20 Lighthouse-CI |

### 1.3 Relationship to other sub-plans

| Sub-plan | Where it intersects this plan |
|---|---|
| `test-coverage-master-plan` | T2 (iOS Sentry reachability) → SignInService.swift screen; T6 (web PR JS gate) **closed via fitme-story #137** — web component tests baseline |
| `analytics-master-plan` | F19 / F20 (GA4 conversion event types + Firebase event-name cleanup) affect Settings + Onboarding analytics taxonomy |
| `dev-env-master-plan` | R6 (.editorconfig + .vscode) standardizes UI-author IDE; R7 (SwiftLint) will lint SwiftUI files; R9 (coverage) feeds UI-test discipline |
| `fitme-story-discoverability-plan` | DISCO P2 work on dashboard redirects + path preservation overlaps with this plan's website ownership |
| `ucc-hardening-infra-overlay-2026-05-19` | UCC sign-in / devices / audit-log UI surface |

### 1.4 Authority + cadence

- **Per-screen v2 alignment** is governed by [`docs/design-system/v2-refactor-checklist.md`](../design-system/v2-refactor-checklist.md) (one-time per pre-PM-workflow screen)
- **New UI features** flow through `/pm-workflow` Phase 3 UX/Integration with [`/ux preflight`](../skills/ux.md) + [`/design preflight`](../skills/design.md) gates
- **Polish + drift** flows through the `ui-audit` P1 fix-as-you-touch rule per [CLAUDE.md "CI Pipeline"](../../CLAUDE.md)
- **Design system evolution** governed by [CLAUDE.md "Design System (Living Framework)"](../../CLAUDE.md) — token additions in same commit as backing colorset; per-feature memory in [`docs/design-system/feature-memory.md`](../design-system/feature-memory.md)

---

## 2. iOS App — Current State (FitTracker2)

### 2.1 Shipped iOS UI features (16)

| Feature | Phase | Parent | Type | Source |
|---|---|---|---|---|
| `authentication` | complete | — | feature | Pre-PM-workflow; supersedes earlier auth |
| `onboarding` | complete | — | feature | v1; superseded by `onboarding-v2-auth-flow` (PR #59) |
| `onboarding-v2-auth-flow` | complete | design-system-v2 | feature | SHIPPED PR #80 2026-04-15; per `feedback_welcome_screen_design` |
| `home-status-goal-card` | complete | design-system-v2 | feature | — |
| `home-today-screen` | complete | design-system-v2 | feature | 723-line v2 rewrite (PR #61) |
| `nutrition-logging` | complete | — | feature | v1 |
| `nutrition-v2` | complete | design-system-v2 | feature | v2 alignment |
| `training-tracking` | complete | — | feature | v1 |
| `training-plan-v2` | complete | design-system-v2 | feature | v2 alignment |
| `stats-progress-hub` | complete | — | feature | v1 |
| `stats-v2` | complete | design-system-v2 | feature | SHIPPED 2026-04-30 PR #164 |
| `settings` | complete | — | feature | v1 |
| `settings-v2` | complete | design-system-v2 | feature | v2 alignment |
| `user-profile-settings` | complete | settings-v2 | feature | SHIPPED 2026-04-20 (framework v5.0); case study `docs/case-studies/user-profile-v4.4-case-study.md`; showcase MDX `04-user-profile.mdx` |
| `recovery-biometrics` | complete | — | feature | HealthKit recovery surfaces |
| `smart-reminders` | complete | — | feature | Case study published 2026-04-20 |

### 2.2 Shipped iOS UI enhancements (5)

| Feature | Parent | Type | Notes |
|---|---|---|---|
| `onboarding-v2-retroactive` | onboarding-v2-auth-flow | enhancement | SHIPPED 2026-04-09 PR #63 (per `paused_onboarding_v2_retroactive.md`) |
| `readiness-score-v2` | recovery-biometrics | enhancement | SHIPPED 2026-04-10 (per backlog row #283) |
| `metric-tile-deep-linking` | home-today-screen | enhancement | Tile → detail navigation |
| `auth-polish-v2` | authentication / onboarding-v2 | feature | SHIPPED 2026-05-01 PR #163 (per `active_auth_polish_v2.md`) |
| `smart-reminders-behavioral-learning` | smart-reminders | feature | PR-1 SHIPPED 2026-05-04 (PRs #190 + #198) |

### 2.3 Shipped iOS UI chores (3)

| Feature | Type | Notes |
|---|---|---|
| `ui-audit-baseline-burndown` | chore | P0 = 0 achieved 2026-05-05 |
| `ios-ui-audit-p1-burndown` | enhancement | P1 103 → 44 (57% reduction); 7 new tokens + 73 mass-subs |
| `ios-ui-audit-p1-drift-cleanup` | enhancement | Drift maintenance pass |
| `ui-ux-final-sweep-2026-05-12` | enhancement | Final pre-v7.9 sweep |
| `ios-code-connect` | chore | Foundation 4/5 (T5 blocked on external Figma `code_connect:write` scope) |

### 2.4 In-flight iOS (2)

| Feature | Phase | Tasks | Notes |
|---|---|---|---|
| `ai-recommendation-ui` | complete | — | `state.json::case_study=null` confirmed 2026-05-24 — UX-R2 row in §3.5 + backlog; will trip `STATE_NO_CASE_STUDY_LINK` on next mutation. ~10 min fix |
| `app-store-assets` | implementation | 10 (5 done per memory) | DEFERRED 2026-05-08; resume after S3-G3 → S5 → S4 → S7 → S6 → S8 → S9 |

> `ucc-sign-in-figma-mapping` removed from this table — it's a cross-repo (Figma-side) item primarily tracked in §3.3 Website.

### 2.5 Open iOS UI/UX backlog ([`docs/product/backlog.md`](../product/backlog.md))

**§ Medium Priority — UX Improvements** (lines 280–292):

- [ ] Chart goal target lines — weight/BF goals not overlaid on stats charts
- [ ] Chart tap-to-tooltip interaction — mentioned in v2 spec, unclear status
- [ ] Trend alerts — no notification when HRV drops below threshold for 3+ days
- [ ] Exercise search/filter — 87 exercises in fixed order, no search
- [ ] Training program customization — fixed 6-day PPL split (partially addressed by Import Training Plan)
- [ ] Notification settings screen — backend `NotificationPreferencesStore` exists but no user-facing UI
- [ ] Data export from Settings — JSON export UI exists; CSV format not yet implemented
- [ ] User feedback loop for AI — can't rate recommendation quality
- [ ] Dark Mode end-to-end testing — asset catalog has values but not verified
- [ ] Dynamic Type full compliance — `@ScaledMetric` not on all text tokens
- [x] ~~Code Connect (Figma ↔ code mapping)~~ — SHIPPED via `ios-code-connect`

**§ Low Priority — Nice-to-Have** (lines 294–307):

- [ ] Rep max calculator (1RM estimation UI)
- [ ] Supersets / circuits logging
- [ ] Custom exercise creation
- [ ] Meal timing analysis
- [ ] Photo-based food logging (Vision/ML)
- [ ] AI meal suggestions based on remaining macros
- [ ] Chart export/share (screenshot or CSV)
- [ ] Chart comparison mode (overlay two metrics)
- [ ] Apple Watch complication
- [ ] iOS home screen / lock screen widgets
- [ ] iPad / macOS optimized layouts
- [ ] No passcode fallback for biometric lock
- [ ] Phone OTP registration (deferred per `docs/design-system/deferred-phone-otp-task.md`)

**§ Design System Residual** (lines 309–313):

- [x] ~~9 raw literals remaining across views (responsive micro-adjustments)~~ — **CLOSED 2026-05-26** per [`docs/design-system/ui-audit-p1-residual-2026-05-26.md`](../design-system/ui-audit-p1-residual-2026-05-26.md). Live `make ui-audit` reports P0=0 + P1=0; the "9 remaining" was a stale snapshot from the May 11 burndown window — subsequent `ios-ui-audit-p1-drift-cleanup` closed them. Separate baseline-doc regeneration PR queued
- [ ] Android token output for Style Dictionary (now tracked as AND-1 in §4.4)
- [x] ~~VoiceOver labels comprehensive audit~~ — **DONE 2026-05-26** per [`docs/design-system/voiceover-audit-2026-05-26.md`](../design-system/voiceover-audit-2026-05-26.md). 21 v2 files scanned; 7 files flagged P1 (zero or low label/tap ratio); 19 interactive elements need labels (~10 hr total fix-as-you-touch). Audit doc identifies file:line per finding
- [ ] Figma old frame cleanup

**Implicit:** ~~`make ui-audit` P1 drift +5 (baseline 103 → current 108)~~ — **STALE; CORRECTED 2026-05-26.** Live `make ui-audit` reports P1 = 0 (0 files-with-findings out of 101 scanned). `ios-ui-audit-p1-drift-cleanup` (active feature, `phase=complete`) closed the residual after the May 11 burndown. Baseline doc still reads P1=44 — pending regeneration PR. See [`ui-audit-p1-residual-2026-05-26.md`](../design-system/ui-audit-p1-residual-2026-05-26.md). Fix-as-you-touch policy remains active per [CLAUDE.md "CI Pipeline"](../../CLAUDE.md)

---

## 3. Website — Current State (fitme-story)

### 3.1 Shipped website features (6)

| Feature | Type | Notes |
|---|---|---|
| `marketing-website` | feature | Public marketing pages |
| `framework-story-site` | feature (closed) | PROD LIVE fitme-story.vercel.app; 53+ commits; 39 routes; Lighthouse 95+ |
| `case-study-presentation` | feature | fitme-story PR #8 + FT2 PR #146; 25 case studies; 51/51 MDX |
| `case-study-comparison-table` | feature | Compare-cases UI |
| `unified-control-center` (UCC) | Feature | Wave 2 SHIPPED 89%; Block E (UI) 100%; remaining T2.5, T35, T36-Phase-2, T38, T42 |
| `ucc-passkey-auth` | feature | 4 PRs SHIPPED 2026-05-07; 28/28 tasks; FIT-63 Done; Parts 1-6 ceremony SHIPPED 2026-05-16 |

### 3.2 Shipped website enhancements (3)

| Feature | Parent | Type | Notes |
|---|---|---|---|
| `fitme-story-website-design-system` | (standalone DS) | feature | Full PM-flow; 20/20 Figma parity; 45 audit findings closed; SHIPPED 2026-05-10 |
| `fitme-story-design-system-p2-cleanup` | fitme-story-website-design-system | enhancement | Bucket H follow-ups (16 P2 items) |
| `fitme-story-ds-p2-deferred` | fitme-story-website-design-system | enhancement | Deferred-items closeout |
| `fitme-story-ds-p2-final-sweep` | fitme-story-website-design-system | enhancement | Final sweep batch |

### 3.3 In-flight website (6)

| Feature | Phase | Tasks | Notes |
|---|---|---|---|
| `fitme-story-public-enhancements` | complete | 24/24 | Reconciled 2026-05-24 — state.json confirms `current_phase=complete` + all 24 tasks done. T13 shipped 2026-05-21 via fitme-story PR #134. Closure ceremony complete |
| `3d-interactive-framework-flow-diagram` | prd | — | `scheduled_after.signal: "analytics-observability phase=complete"` |
| `ucc-sign-in-figma-mapping` | implementation | 11 | Figma-side sign-in mapping (cross-repo with iOS); promoted from §2.4 |
| `ucc-passkey-auth-security-hardening` | documentation | 26 | B12 T+7d kill-criteria due 2026-05-27 |
| `ucc-passkey-auth-audit-log-redis-fix` | implementation | 9 | Redis audit-log fix |
| `analytics-observability` | implementation | 15 | Sub-plan: `analytics-master-plan-2026-05-13.md`; F19/F20 → v7.9.1 |

### 3.4 Open website UI/UX backlog

**Cadence ledger UU items** ([`.claude/shared/must-have-cadence-followups.md`](../../.claude/shared/must-have-cadence-followups.md)):

| ID | Item | Effort | Calendar | Source |
|---|---|---|---|---|
| ~~C9 / UU1~~ | ~~UCC coral-pulse animation on `/control-room/sign-in`~~ — **CLOSED** (verified 2026-05-24 PR-2B). `globals.css:112-118` keyframe + `AuthPasskeyForm.tsx:243` conditional class; global `prefers-reduced-motion` neutralizes the animation. | — | shipped | ucc-passkey-auth ux-spec §6 |
| ~~C10 / UU2~~ | ~~UCC 4 control-room dark-mode contrast verifications~~ — **CLOSED** (verified 2026-05-16 in `fitme-story-dark-mode-coverage.md` lines 79-82). All 4 WCAG AA: `AuditEventRow` 9.5:1+, `AuditLogPanel` 11.5:1+, `AuthPasskeyForm` 14:1+, `DevicesTable` 3.6:1+. | — | shipped | `fitme-story-dark-mode-coverage.md` |
| ~~C5~~ | ~~UCC Part 10 — verify framework-health passkey panel renders with real audit data~~ — **CODE-VERIFIED** 2026-05-24 PR-2B; `<AuditLogPanel />` wired in `framework/page.tsx:438-445`; `.claude/logs/ucc-auth-events.jsonl` has 27 events spanning 2026-05-17 → 2026-05-20 (6 event types). Final visual check at `fitme-story.vercel.app/control-room/framework` is operator action. | — | code/data verified; visual op-check pending | ucc-passkey-auth case study §99 |

**§ High Priority — Architecture & Framework rows** (UI/UX-relevant):

- [ ] **Apply fitme-story web design system to `/control-room/*`** (line 203) — 14 internal components deferred per Internal-deferral policy; effort ~1 week if drift-only, ~2-3 weeks with Figma stubs
- [ ] **Complete Figma design + architecture for both surfaces (iOS + website)** (line 204) — 2-3 week Feature; (A) fitme-story Figma new build + (B) iOS coverage audit + (C) architecture doc per surface
- [ ] **Site-wide search on fitme-story public site** (line 189) — Pagefind static index across 26 case-studies + 46+ glossary + dev-guide; Feature
- [ ] **fitme-story website DS — ongoing build-out** (line 191) — showcase route + drift detection + dark-mode parity audit + token additions + contribution guidelines

### 3.5 Drift / reconciliation items

| Drift | Detection method | Status / Fix scope |
|---|---|---|
| ~~`fitme-story-public-enhancements` state.json claims `phase=implementation`, 0/24 tasks done~~ | manual cross-reference | **RESOLVED 2026-05-24** — state.json verified at `current_phase=complete` + 24/24 tasks done. No drift |
| `ai-recommendation-ui` `phase=complete` but `case_study=null` | grep state.json (2026-05-24) | **CONFIRMED OPEN** — UX-R2 row in backlog; ~10 min fix |
| `feedback_ai_avatar_brand_icon.md` (FitMe brand icon = AI's live avatar) | memory only | Promote to backlog row as a design rule (UX-R3) |
| `project_pm_flow_orbital_rollback_point.md` (production at commit `e206f24` simple orbital; Alt-B hover-reveal in build) | memory only | Promote to backlog row as a rollback / iteration record (UX-R4) |
| `project_failure_recognition_layer.md` (BRAINSTORM 2026-04-17; anti-pattern detector; unbuilt) | memory only | Promote to backlog row (Aspirational / Long-term) (UX-R5) |

---

## 4. Android — Current State (cross-platform token authoring; no native app code yet)

### 4.1 Scope clarification

Android is treated as a **second platform layer built on the same FitTracker semantics**, not a second independent system. The order codified in [`docs/design-system/android-adaptation.md`](../design-system/android-adaptation.md): (1) define FitMe semantic roles → (2) validate on Apple platforms → (3) map into Material 3 roles and Android-native interaction patterns. This plan owns the token-pipeline + adaptation-docs surface; an Android app implementation (Jetpack Compose views + theming + tests) is **explicitly out-of-scope** until a separate feature kicks off.

### 4.2 Shipped Android features (1)

| Feature | Phase | Type | Source |
|---|---|---|---|
| `android-design-system` | complete | feature (research-only) | SHIPPED 2026-04-04 (framework pre-v5.0). 92 iOS tokens → MD3 mapping; Style Dictionary dual-output config. Case study `docs/case-studies/android-design-system-case-study.md`; showcase MDX `24a-android-design-system.mdx`. Parent: `six-features-roundup-case-study.md`. `has_ui: false` — no Android view code |

### 4.3 Android design-system artifacts (live, maintained)

| Artifact | Path | Purpose |
|---|---|---|
| Style Dictionary Android config | [`design-tokens/config-android.json`](../../design-tokens/config-android.json) | Dual-output: `android-compose` → `FitMeDesignTokens.kt` (Compose object) + `android-xml` → `res/values/` XML resources |
| Token mapping reference | [`docs/design-system/android-token-mapping.md`](../design-system/android-token-mapping.md) | 92 iOS → MD3 mapping table (46 colors / 22 typography / 9 spacing / 9 radius / 4 shadow / 14 motion = 104 total; 72 MD3-mapped + 32 custom) |
| Adaptation strategy | [`docs/design-system/android-adaptation.md`](../design-system/android-adaptation.md) | Strategy doc: token mapping table + component translation (direct semantic equivalents + Android-specific patterns) |

### 4.4 Open Android backlog (~3)

| ID | Item | Effort | Notes |
|---|---|---|---|
| **AND-1** | Generate Android token output and commit `android/FitMeDesignTokens.kt` + `android/res/values/*.xml` outputs as compiled artifacts | **Revised 3-4 hr** (was 1-2 hr) | Currently `config-android.json` exists but **does not run** — references Style Dictionary transforms `size/compose/dp` + `size/compose/sp` that don't exist in `style-dictionary@3.9.2`. Two paths: (1) register custom transforms in a new `sd.config.android.js` wrapper; (2) downgrade to `transformGroup: "android"` (XML-only) until Compose is needed. Decision deferred to operator. Full disposition in [`docs/design-system/android-token-mapping.md`](../design-system/android-token-mapping.md) §0 |
| ~~**AND-2**~~ | ~~Validate `android-token-mapping.md` against current `tokens.json`~~ | **DONE 2026-05-25** | Audit found substantial drift: 92 doc count → 108 actual tokens (+4 net but type taxonomy restructured: +Opacity/Layout/Size categories, Motion -8, Typography -6, Colors +3). Drift captured in [`android-token-mapping.md`](../design-system/android-token-mapping.md) §0 Audit Note. Per-row mapping refresh (sections 1-6) deferred to next quarterly pass or to `android-app-implementation` kickoff |
| ~~**AND-3**~~ | ~~Decide trigger condition for `android-app-implementation` feature kickoff~~ | **DONE 2026-05-26** | Decision: **deferred indefinitely**. iOS + web are the production surfaces; Android stays at the token + adaptation-doc layer. Re-evaluation triggers: (a) App Store launch + first 1000 iOS WAU sustained 30 days; (b) External partner request; (c) Annual review (next 2027-05-26; default = stay deferred). Codified in [`android-design-system/state.json::android_app_implementation_kickoff_trigger`](../../.claude/features/android-design-system/state.json) + this row |

### 4.5 Android — not in scope (intentionally deferred)

- **Android app codebase** — no Kotlin/Compose source tree exists; no `android/` Gradle project; no `MainActivity.kt`. The `config-android.json` builds INTO an empty `android/` directory if invoked
- **Android Code Connect (`.figma.kt` mappings)** — depends on Android app codebase existing first
- **Android UI tests** — depends on app codebase
- **Play Store assets** — listed in `app-store-assets` ASO scope but currently iOS-only (Apple App Store)
- **Android dark mode / motion / accessibility audit** — depends on app codebase

> **Re-evaluation trigger:** when an `android-app-implementation` feature kicks off (see AND-3), this section expands into full §2-parity treatment (shipped/in-flight/backlog/residual subsections). Until then, Android scope here stays scoped to "token + adaptation layer is ready and maintained; native app code is not".

---

## 5. Cross-cutting — All platforms

| Track | Source | Status |
|---|---|---|
| **Figma ↔ code Code Connect bridge** | CLAUDE.md "v4.X+CC" + memory `project_session_2026_05_09_codeconnect_caseaudit.md` | Foundation SHIPPED 2026-05-10; T5 (end-to-end test) blocked on Figma `code_connect:write` scope — see backlog row "Re-activate Code Connect publish when Figma seat/plan unblocks" (line 190) |
| **Design system evolution doc** | [`docs/design-system/feature-memory.md`](../design-system/feature-memory.md) + [`docs/design-system/v2-refactor-checklist.md`](../design-system/v2-refactor-checklist.md) | Living docs, no specific open task |
| **UX foundations 13 principles** | [`docs/design-system/ux-foundations.md`](../design-system/ux-foundations.md) | Source-of-truth for v2 alignment; enforced via `/ux preflight` |
| **UI-audit verification** | `make ui-audit` → [`docs/design-system/ui-audit-baseline.md`](../design-system/ui-audit-baseline.md) | P0 = 0 (hard gate); P1 = 0 as of 2026-05-26 (was advisory at +5; reconciled per `ui-audit-p1-residual-2026-05-26.md`); baseline doc regen PR queued |
| **Figma↔code matrix** | [`docs/design-system/figma-code-sync-status.md`](../design-system/figma-code-sync-status.md) | Tracks per-screen sync status iOS + web (Android not yet present) |
| **Style Dictionary token pipeline** | [`design-tokens/tokens.json`](../../design-tokens/tokens.json) → iOS (`DesignTokens.swift`) + Android (`config-android.json`) | Authoritative single-source for all 92+ semantic tokens across all 3 platforms; iOS output committed, Android output pending (AND-1) |
| **Cross-platform design rules** | [`docs/design-system/design-rules.md`](../design-system/design-rules.md) | Platform-agnostic rules; currently iOS-focused, candidate doc for AI-avatar / orbital / failure-recognition rules per UX-R3/R4/R5 |
| **Cross-platform governance** | [`docs/design-system/design-system-governance.md`](../design-system/design-system-governance.md) | Token-add, component-add, deprecation policy across all platforms |

---

## 6. Implementation calendar

Calendar-safe ordering. No new gates ship in Phase E (2026-05-21 → 2026-06-04); UI/UX work is feature/enhancement/chore — not gate-additive — so safe to ship at any time as long as branch-isolation rules respected.

| Window | Items | Notes |
|---|---|---|
| **today (2026-05-24)** | (1) Open the 3 memory-only design rules as backlog rows (UX-R3 / R4 / R5) · (2) Verify + backfill `ai-recommendation-ui` case-study link (UX-R2) · (3) AND-1 Android token output generation if Android touched | Pure reconciliation / quick fix, no UI code |
| **2026-05-24 → 2026-05-27** | C9 (coral-pulse) + C10 (4 dark-mode contrast checks) bundled in one PR | fitme-story only; no infra-glob; no Phase E conflict |
| **2026-05-28 → 2026-06-04** | Resume `app-store-assets` (5/10 done → ship S3-G3 → S5 → S4 → S7 → S6 → S8 → S9) | iOS-only; pre-launch hygiene |
| **2026-06-05+** (post Phase E exit) | "Apply fitme-story DS to `/control-room/*`" (line 203) OR "Complete Figma design for both surfaces" (line 204) — pick one as a Feature for v7.9.1 build window | Full PM-workflow Feature; multi-week |
| **2026-06-15 → 2026-07-15** | Site-wide search on fitme-story (Pagefind static index) | Feature; full 10-phase |
| **2026-08+** | Tackle iOS Medium Priority UX queue (chart improvements, notification settings UI, dark-mode E2E, Dynamic Type compliance) as a rolling enhancement series · AND-2 Android token mapping drift validation | Per backlog priority |
| **Post-App-Store-launch (Q4 2026+)** | Tier 4 Low Priority items — widgets, Watch complication, iPad/macOS layouts · AND-3 decision on `android-app-implementation` kickoff trigger | Coupled to launch milestone |

---

## 7. Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| `make ui-audit` P1 drift continues to grow past +5 if fix-as-you-touch policy slips | Medium | Low (advisory, not gate) | Quarterly P1 burndown sweep; promote to hard gate at +20 drift |
| `app-store-assets` resumes too late and gates App Store submission | Medium | High (launch blocker) | Operator-paced; explicit scheduled-after signal at 2026-05-28 → 2026-06-04 window |
| Dark Mode E2E never reaches "verified" status — ships untested | High | Medium (post-launch user complaints) | Quarterly audit; or fold into automated snapshot-test discipline once test-coverage T3 ships |
| Memory-only design rules (AI avatar, orbital, failure recognition) get lost when memory rotates | High | Low-Medium (rule is mostly self-evident from existing code) | Promote to backlog or to `docs/design-system/design-rules.md` (new doc, future) |
| `ai-recommendation-ui` ships with no case-study link, fails `STATE_NO_CASE_STUDY_LINK` on next mutation | High | Low (gate is enforced; will fail loudly) | Verify link today; backfill if absent |
| `ucc-passkey-auth-security-hardening` B12 kill-criteria evaluation on 2026-05-27 lands a finding | Low | Medium (would require revert) | Hardening work has been observed cleanly for 3+ days; risk is low |
| Polish bundle (C9 + C10) cross-contaminates the post-v7.9 Phase E soak | Low | Low | Items are fitme-story-only, no FT2 gate impact, no infra-glob |
| Android `tokens.json` → MD3 mapping drift as new iOS tokens land without back-propagation to `android-token-mapping.md` | Medium | Low (Android app not yet built; drift is doc-only until kickoff) | AND-2 quarterly validation; promote to a `make tokens-check-android-mapping` gate if/when Android app kicks off |
| AND-3 decision delayed indefinitely; Android token pipeline atrophies through neglect | Low-Medium | Low (current state is "deferred, ready") | Annual review during yearly architecture audit; explicit "stay deferred" decision recorded |

---

## 8. Open questions

1. **Should `fitme-story-public-enhancements` close as a single rollup or be split into per-task case studies?** ~~Pending~~ **DECIDED 2026-05-24** — already shipped as a rollup; 24/24 done; `current_phase=complete`. Single rollup case study is the format. No further action.
2. **`app-store-assets` resume preconditions** — are S3-G3 / S5 / S4 / S7 / S6 / S8 / S9 still the correct ordering given any product changes since 2026-05-08 deferral? Re-validate at resume.
3. **`/control-room/*` design-system application — drift-only vs full Figma stubs?** Drift-only is ~1 week; Figma stubs add ~2 weeks. Operator decides at scope-confirmation. Default: drift-only (Internal-deferral policy was explicit about operator-only surfaces being code-first).
4. **Should the 3 memory-only design rules become a new `docs/design-system/design-rules.md` doc OR backlog rows?** Doc has more permanence + can be linked from CLAUDE.md; backlog rows decay faster but easier to triage. Default: backlog rows now, doc later if rule count grows past ~10. Note: `design-rules.md` exists and could be the natural home.
5. **Site-wide search — Pagefind vs Fuse.js OR custom Vercel KV store?** Pagefind is the recommended default (static build-time index, ~80 docs ≈ tiny bundle, zero runtime cost). Confirm at /pm-workflow start.
6. **iOS Medium Priority UX queue — bundle as a single "v7.x polish enhancement" feature OR ship one-at-a-time?** Bundling preserves design coherence across changes (e.g., chart improvements should ship together); one-at-a-time preserves PR review focus. Recommend bundle for chart items, individual ship for accessibility + notification settings.
7. **Dark Mode E2E verification methodology** — manual visual review (operator-driven) OR snapshot tests (R9 coverage + dedicated XCSnapshot harness)? Defer until R9 coverage instrumentation lands (~2026-05-25).
8. **AND-3: when (if ever) does `android-app-implementation` kick off?** Three candidate triggers: (a) App Store launch + first 1000 iOS WAU (most common cross-platform path); (b) operator decides iOS + web are the production surfaces and Android stays "tokens-only" indefinitely; (c) external request (school project requirement, partner ask, etc.). Default: stay deferred; revisit annually.
9. **Should `make tokens-check` extend to cover Android-mapping drift?** Today `tokens-check` validates iOS-only. AND-2 covers the manual diff. Promote to automated check if/when Android app kicks off OR if the drift starts compounding.

---

## 9. References

### Parent / sibling sub-plans

- [`infra-master-plan-2026-05-12.md`](infra-master-plan-2026-05-12.md) — canonical v7.9 / v8.x docket
- [`test-coverage-master-plan-2026-05-13.md`](test-coverage-master-plan-2026-05-13.md) — sibling; T2 + T6 intersect this plan's iOS + web test surface
- [`analytics-master-plan-2026-05-13.md`](analytics-master-plan-2026-05-13.md) — sibling; F19 / F20 intersect Settings + Onboarding analytics
- [`data-integrity-and-rollback-2026-05-14.md`](data-integrity-and-rollback-2026-05-14.md) — sibling; integrity gates apply to feature state.json reconciliation
- [`dev-env-master-plan-2026-05-24.md`](dev-env-master-plan-2026-05-24.md) — sibling; R6 (.vscode) + R7 (SwiftLint) + R9 (coverage) feed UI authoring tools
- [`fitme-story-discoverability-plan-2026-05-20.md`](fitme-story-discoverability-plan-2026-05-20.md) — sibling; DISCO P2 overlaps website ownership
- [`ucc-hardening-infra-overlay-2026-05-19.md`](ucc-hardening-infra-overlay-2026-05-19.md) — UCC operator-dashboard hardening overlay

### CLAUDE.md anchors

- "Design System (Living Framework)" — ~125 tokens + 13 components + token pipeline + CI gate
- "v4.X+CC Cross-repo Code Connect bridge" — Figma ↔ code mapping for both repos
- "UI Refactoring & V2 Rule" — v2/ subdirectory convention + project.pbxproj hygiene
- "Analytics Naming Convention" — screen-prefix rule (cross-references analytics-master-plan)

### Source docs

- [`docs/design-system/ux-foundations.md`](../design-system/ux-foundations.md) — 13 principles (8 core + 5 FitMe-specific)
- [`docs/design-system/v2-refactor-checklist.md`](../design-system/v2-refactor-checklist.md) — V2 Rule operational checklist
- [`docs/design-system/feature-memory.md`](../design-system/feature-memory.md) — per-feature design memory
- [`docs/design-system/figma-code-sync-status.md`](../design-system/figma-code-sync-status.md) — Figma↔code matrix (both surfaces)
- [`docs/design-system/fitme-story-design-architecture.md`](../design-system/fitme-story-design-architecture.md) — web design architecture
- [`docs/design-system/fitme-story-dark-mode-coverage.md`](../design-system/fitme-story-dark-mode-coverage.md) — per-component dark-mode status matrix
- [`docs/design-system/ios-code-connect-workflow.md`](../design-system/ios-code-connect-workflow.md) — iOS operator runbook
- [`docs/design-system/ui-audit-baseline.md`](../design-system/ui-audit-baseline.md) — `make ui-audit` baseline
- [`docs/design-system/android-adaptation.md`](../design-system/android-adaptation.md) — Android adaptation strategy
- [`docs/design-system/android-token-mapping.md`](../design-system/android-token-mapping.md) — iOS → MD3 (Material 3) token mapping table
- [`design-tokens/tokens.json`](../../design-tokens/tokens.json) — Style Dictionary single-source for all platforms
- [`design-tokens/config-android.json`](../../design-tokens/config-android.json) — Style Dictionary Android dual-output config
- [`docs/design-system/design-rules.md`](../design-system/design-rules.md) — platform-agnostic design rules
- [`docs/design-system/design-system-governance.md`](../design-system/design-system-governance.md) — cross-platform governance policy

### Backlog tracking

- [`docs/product/backlog.md`](../product/backlog.md) §"Medium Priority — UX Improvements" + §"Low Priority — Nice-to-Have" + §"Design System Residual" + §"Dev-Env Stability & Scale Track" (cross-references) + new §"UI/UX Track" (after this sub-plan lands)

### Memory cross-references

- [`project_all_screens_complete.md`](~/.claude/projects/-Volumes-DevSSD-FitTracker2/memory/project_all_screens_complete.md) — 6/6 v2 aligned, 100% token compliance, PRs #59-#78
- [`project_fitme_story_website_design_system_shipped.md`](~/.claude/projects/-Volumes-DevSSD-FitTracker2/memory/project_fitme_story_website_design_system_shipped.md) — full PM-flow shipped 2026-05-10
- [`project_ucc_passkey_cutover_2026_05_16.md`](~/.claude/projects/-Volumes-DevSSD-FitTracker2/memory/project_ucc_passkey_cutover_2026_05_16.md) — Parts 1-6 SHIPPED
- [`project_case_study_presentation_locked.md`](~/.claude/projects/-Volumes-DevSSD-FitTracker2/memory/project_case_study_presentation_locked.md) — SHIPPED 2026-04-28
- [`feedback_welcome_screen_design.md`](~/.claude/projects/-Volumes-DevSSD-FitTracker2/memory/feedback_welcome_screen_design.md) — blue bg, orange icon, pinned CTAs (2026-04-15)
- [`feedback_ai_avatar_brand_icon.md`](~/.claude/projects/-Volumes-DevSSD-FitTracker2/memory/feedback_ai_avatar_brand_icon.md) — FitMe brand icon = AI's live avatar
- [`feedback_onboarding_auth_flow_issues.md`](~/.claude/projects/-Volumes-DevSSD-FitTracker2/memory/feedback_onboarding_auth_flow_issues.md) — 7 issues; #1-4,6 fixed; #5 Apple deferred
- [`project_pm_flow_orbital_rollback_point.md`](~/.claude/projects/-Volumes-DevSSD-FitTracker2/memory/project_pm_flow_orbital_rollback_point.md) — production at `e206f24` orbital
- [`project_failure_recognition_layer.md`](~/.claude/projects/-Volumes-DevSSD-FitTracker2/memory/project_failure_recognition_layer.md) — BRAINSTORM 2026-04-17; unbuilt

---

## 10. Change log for this document

| Date | Change |
|---|---|
| 2026-05-24 | Initial creation. Promotes UI/UX cross-reference work from session-only synthesis to durable sub-plan. Reconciles 26 shipped + 9 in-flight + ~23 open across both surfaces. Surfaces 5 drift / reconciliation items (3 memory-only design rules + 1 state.json stale + 1 case-study link risk). |
| 2026-05-24 (rev. 2) | **Platform-comprehensive revision** per user request "add all tasks, features, and any work regarding design system on all platforms". Changes: (1) scope expanded to 3 platforms (iOS + website + Android); (2) new §4 "Android — Current State" covering `android-design-system` shipped feature + 3 live artifacts (`config-android.json`, `android-token-mapping.md`, `android-adaptation.md`) + 3 open items AND-1/AND-2/AND-3 + explicit out-of-scope list; (3) §5 Cross-cutting expanded from 5 → 8 rows (added Style Dictionary pipeline, design-rules.md, governance.md); (4) `user-profile-settings` added as missing 16th iOS shipped feature; (5) `fitme-story-public-enhancements` drift item resolved (state.json verified `phase=complete` + 24/24); (6) §2.4 in-flight iOS reduced 3 → 2 (UCC Figma mapping moved to §3.3); (7) §3.3 in-flight website reduced 6 → 5 by deduplication; (8) sections renumbered §6/§7/§8/§9/§10; (9) §0 TL;DR table gains Android column + total counts updated; (10) 2 Android-specific risks added; (11) 2 Android-specific open questions added; (12) §9 References gains 5 Android + cross-platform docs. Final coverage: 25 shipped features + 8 shipped enhancements + 5 shipped chores + 8 in-flight + ~27 open backlog = ~73 tracked items across iOS + website + Android. |
