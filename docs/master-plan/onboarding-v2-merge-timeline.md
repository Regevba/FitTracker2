> ⚠️ Historical document. References to `docs/project/` paths are from before the April 2026 reorganization. See `docs/master-plan/`, `docs/setup/`, and `docs/case-studies/` for current locations.

# Onboarding v2 + Branch Consolidation — Merge Timeline

> **Date prepared:** 2026-04-07
> **Branch:** `feature/onboarding-ux-align` (renamed from `claude/review-code-changes-E7RH7`)
> **Target:** `main`
> **PR strategy:** Option A — single consolidated PR
> **Commits ahead of main:** 64 across 4 days
> **Files changed:** 181 (+26,194 / -526)
> **CI status:** ✅ build clean · ✅ tokens-check clean · ✅ all tests pass on iPhone 17 sim

## Why one PR

This branch is the de-facto baseline for everything that has accumulated since 2026-04-04. It contains 16 features in `state.json=complete` plus all the design system, UX foundations, and tooling work. The "feature by feature" rule starts AFTER this baseline merges. Onboarding v2 is the most recent layer; the rest is groundwork that future features depend on.

## Timeline (chronological)

### 2026-04-04 — GDPR + Marketing + Android (T-3 days)
- `f861cfa..2acd1d9` GDPR compliance feature: services, views, analytics, taxonomy validation, Settings wiring (Phase 9/9 complete)
- `f033e5d..f6564d2` Android Design System: full token mapping + Style Dictionary config (Phase 9/9 complete)
- `0c56589..79efc81` Marketing website: Astro + Tailwind static site, 66 files
- `75b77a9..a6d89d8` 18 standalone PRDs for all features + Auth/Settings/Data PRD enrichment, README/roadmap/CHANGELOG updates
- `ad25b36` Fix: missing dismiss buttons on 2 sheet presentations

### 2026-04-05 — Skills ecosystem + Onboarding v1 PM workflow (T-2 days)
- `2ee105c` Remove duplicate Info.plist + branch review report
- `56266d4` Add 9 skills + 8 shared data files (skills ecosystem v1)
- `a13f3d6` Onboarding PM workflow Phase 0-1: research + PRD complete
- `52d9e74` Onboarding PM workflow Phase 2: 10-task breakdown

### 2026-04-06 — Stabilization + Onboarding v1 implementation + UX foundations start (T-1 day)
- `f1b5c94` Stabilize build, sync, privacy flows
- `b13bf01` Harden local verification + config fallbacks
- `17781e6` Align git author for Vercel deployments
- `9081834` Runtime checkpoint before SSD move
- `9f06be7` Eliminate force unwraps, update shared data for SSD home
- `2879e0c` Backfill state.json for all features, fix PM compliance gaps
- `12ef0a3` Parallel task hub with skill routing, priority queue, SSD storage
- `f6af3d3` Skill routing table, lifecycle definitions, reconciliation alerts
- `3f456f6` PM hub evolution docs + master plan Sprint 1
- **`33eddd5` Onboarding v1: 5-screen flow with GA4 analytics (T1-T10)** ⚠️ never compiled successfully
- `ce9e653` Align ConsentView + Welcome with Figma
- `d017a30` Integrate consent screen as step 5 of onboarding (PRD never updated)
- `9fa3fab` FitMeBrandIcon from Figma app icon ⚠️ never added to Xcode target
- `370ddc5` Claude Console prompt for Figma onboarding v2 screens
- `25b8a3e` Design system closure audit: 35 open items cataloged
- `8b16774` Sprint A complete: eliminate all raw font/spacing literals
- `1ba198a` /ux skill + hub evolution: UX planning layer for PM workflow

### 2026-04-07 — UX Foundations + a11y + onboarding v2 alignment (today)
**UX Foundations doc (10 parts, 1,533 lines):**
- `4876cb7` Part 1 — Design Philosophy & Principles
- `9d7c7bb` Part 2 — Information Architecture
- `4880ef2` Part 2 fix — verify Settings access against actual code
- `3a2ebd8` Part 3 (Interaction Patterns) + Part 4 (Data Viz)
- `dc77d80` Part 5 (Permission & Trust) + Part 6 (State Patterns)
- `2fe90ca` Part 7 (Accessibility) + Part 8 (Motion)
- `f59faa5` Part 9 (Content) + Part 10 (Platform) + Sources — COMPLETE

**Accessibility hardening:**
- `531bb81` Accessibility labels on icon-only and custom buttons across views
- `b27afbf` #Preview blocks on 5 AppComponents
- `be82301` #Preview block on ReadinessCard

**Design system v2 closure + tooling:**
- `37b0671` Sprint C — documentation alignment + closure summary
- `5f3ba86` Claude Console prompt to add UX Foundations layer to Figma
- `1b081eb` Session summary + SSD-only setup guide + README path fixes
- `814da07` SSD setup audit script

**Onboarding v2 (UX alignment per ux-foundations.md):**
- `bf6745d` PM workflow showcase doc scaffolding
- `e816c09` PRD v2 section + task list + state transitions (Phase 1+2)
- `1bcffb4` State transition for Phase 3
- `7971e5a` Phase 3 deliverables: v2-audit-report.md, ux-research.md, ux-spec.md
- **`e46788a` Phase 4: 20 UX alignment patches across 8 onboarding views + AppTheme + Analytics**
- `b323f6a` State transition to phase=testing
- `e2df271` Fix: AppRadius.card alias (preexisting v1 gap)
- `1fd52ba` Build: add FitMeBrandIcon to Xcode target (preexisting v1 bug)
- `b915915` Build: re-add Onboarding folder to Xcode target (preexisting v1 bug)
- `853050d` Build: clean up phantom Onboarding paths from misplaced Xcode add
- `8ce1066` State: phase=review (CI green)

## Risk Assessment

### High-risk files touched (per CLAUDE.md)

| File | Lines changed | Risk | Mitigation |
|------|---------------|------|-----------|
| `FitTracker/FitTrackerApp.swift` | +40/-12 | Routes onboarding before auth/home, adds `@AppStorage("hasCompletedOnboarding")` | Minimal change, behavior gated by flag, build + tests pass |
| `FitTracker/Services/Analytics/AnalyticsService.swift` | +110/-1 | New methods + screen tracking overload | Additive only, no removed APIs, all callers compile |
| `FitTracker/Services/Analytics/AnalyticsProvider.swift` | +48/-0 | New event constants | Additive only, no removed constants |
| `FitTracker/Services/AppTheme.swift` | +38/-0 | New token groups: AppSize, AppMotion, AppShadow.ctaInverse*, AppRadius.card | Additive only, tokens-check passes |

### High-risk files NOT touched ✅

- `DomainModels.swift`
- `EncryptionService.swift`
- `SupabaseSyncService.swift`
- `CloudKitSyncService.swift`
- `SignInService.swift`
- `AuthManager.swift`
- `AIOrchestrator.swift`

### Latent v1 bugs discovered + fixed during v2 alignment

These bugs prevented v1 onboarding from ever building:

1. **`analytics.logEvent()` called as public** — actually private. Replaced with typed `logTutorialBegin()` / `logTutorialComplete()` methods.
2. **`analytics.logScreenView(_:screenClass:)` overload missing** — only single-arg variant existed. Added 2-arg overload to AnalyticsService.
3. **`AppRadius.card` referenced but undefined** — added as alias for `medium=16`.
4. **`FitMeBrandIcon.swift` not in Xcode target** — file existed on disk since `9fa3fab` but was never added to project.pbxproj target membership.
5. **`Onboarding/*.swift` files not in Xcode target** — same root cause. Files existed since `33eddd5` but were never added.

Conclusion: v1 onboarding was a non-buildable artifact since 2026-04-06. v2 alignment surfaced and fixed all 5 latent bugs as a side effect of running the audit + applying patches.

### Test coverage

| Category | Status | Source |
|----------|--------|--------|
| Build (xcodebuild build) | ✅ green | iPhone 17 simulator |
| Token compliance (`make tokens-check`) | ✅ green | Style Dictionary in sync |
| Unit + integration tests | ✅ all pass | xcodebuild test, full suite |
| Analytics instrumentation (manual) | ✅ verified | 6 events typed-method coverage |
| Visual regression | ⏸ not run | requires device farm or screenshot diff |
| Accessibility audit | ⏸ partial | a11y labels added (commit `531bb81`); full VoiceOver audit deferred |

### Backwards compatibility

| Concern | Status |
|---------|--------|
| New `@AppStorage("hasCompletedOnboarding")` key | New users land in onboarding; existing users default `false` → also see onboarding once. **User-visible behavior change.** |
| Analytics taxonomy changes | Additive only — 5 new events, 5 new screens, 5 new params. No removed/renamed events. |
| Design tokens | Additive only — no removed/renamed tokens. Existing references unchanged. |
| Sync (Supabase / CloudKit) | Untouched. |
| Encryption | Untouched. |
| Auth flow | Touched only via onboarding gate placement in `FitTrackerApp.swift`. |

### Known follow-ups (deferred from v2 audit)

| Item | Rationale | Tracked as |
|------|-----------|-----------|
| Figma v2 build (V2-T5) | Prompt is ready at `docs/project/figma-onboarding-v2-prompt.md`; deferred to next session for budget | Follow-up enhancement |
| P2-01 Component consolidation (extract private structs) | Low value, pure refactor | Future enhancement |
| P2-05 Additional accessibility hints | Nice-to-have | Future enhancement |
| P2-06 Welcome caption contrast bump | Cosmetic | Future enhancement |
| P2-07 Pillar text size | Cosmetic | Future enhancement |
| Figma Code Connect mappings (13 components) | Framework ready, mappings unauthored | Separate follow-up |

## Onboarding v2 — pm-workflow showcase

This feature is the exemplar run for the enhanced `/pm-workflow` skill. Documented in `docs/project/pm-workflow-showcase-onboarding.md`.

**Phases executed:**
1. ✅ Research (retained from v1)
2. ✅ PRD v2 (appended as `# v2 — UX Alignment` section to `prd.md`)
3. ✅ Tasks v2 (12 V2-T* tasks appended to `tasks.md`)
4. ✅ UX (audit report + ux-research.md + ux-spec.md — the phase v1 had skipped)
5. ✅ Implementation (20 patches in 1 commit + 4 build-fix commits)
6. ✅ Testing (build/tokens/tests all green)
7. **← Review (this PR)**
8. Merge (after approval)
9. Documentation (post-merge)

**Manual rollback executed:** v1 was at `phase=testing` with CI broken; rolled back to `phase=prd` to inject v2 work, preserving v1 phases under `v1_*` fields. Full audit trail in `state.json.transitions[]`.

## Merge plan

### Pre-merge checklist
- [x] Build green on iPhone 17 sim (Mac local)
- [x] tokens-check green
- [x] All tests pass
- [x] No high-risk files outside expected list touched
- [x] PRD v2 documented in prd.md
- [x] Showcase doc created
- [ ] PR opened with this timeline as body
- [ ] Reviewer approval
- [ ] Final CI on main after merge

### Post-merge actions
1. Run `xcodebuild test` on main to confirm regression-free merge
2. Update `docs/design-system/feature-memory.md` with new tokens (AppSize, AppMotion, AppShadow.ctaInverse*, AppRadius.card)
3. Update `CHANGELOG.md` with onboarding v2 entry
4. Update `docs/product/backlog.md` — move onboarding from "in progress" to "done"
5. Set `state.json.current_phase = complete`
6. Schedule first post-launch metrics review (1 week from merge)
7. Notify downstream skills via `/pm-workflow` change broadcast: `/qa`, `/cx`, `/analytics`, `/design`

### Next feature in alignment sequence

Per user directive ("feature by feature"), after this merges the next target is **home-today-screen** (highest user impact, sets the tone for the rest of the alignment pass).
